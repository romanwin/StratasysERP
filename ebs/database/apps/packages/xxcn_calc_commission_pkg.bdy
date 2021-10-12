CREATE OR REPLACE PACKAGE BODY xxcn_calc_commission_pkg AS

g_program                     VARCHAR2(30)    := 'XXCN_CALC_COMMISSION_PKG.';
g_program_unit                VARCHAR2(30);
g_log                         VARCHAR2(1)     := fnd_profile.value('AFLOG_ENABLED');
g_log_module                  VARCHAR2(100)   := fnd_profile.value('AFLOG_MODULE');
--g_request_id                  NUMBER          := FND_GLOBAL.CONC_REQUEST_ID;

l_consumable_total_records    NUMBER      := 0;
l_consumable_record_errors    NUMBER      := 0;
l_system_count                NUMBER      := 0;

-- ---------------------------------------------------------------------------------------------
-- Name: XXOE_RESELLER_ORDER_REL_PKG
-- Created By: MMAZANET
-- Revision:   1.0
-- --------------------------------------------------------------------------------------------
-- Purpose: Master program for handling the pre-calculation step of commissions for consumable
--          items. This includes managing the relationship of systems to consumables for that
--          calculation.
-- ----------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- 1.1  03/10/2015  MMAZANET    CHG0034820. Added functionality to
--                              calculate commissions off 'special' MANUAL systems entered.
--                              Changed debugging to use Oracle standard debugging.
-- 1.2  06/23/2016  DCHATTERJEE CHG0038832 - Modify delete_pre_commission to consider null value of parameter
--                                  p_remove_all_pending as 'N'
-- 1.3  03/30/2018  DCHATTERJEE INC0117839 - OIC order not processed due to similar product family value
-- 1.4  10-JAN-20   DCHATTERJEE INC0180048 - Some Material orders not processed as IB source ORDER_DELIVERY is not
--                                           considered during calculation
-- 1.5  21-JUL-2020 Diptasurjya CHG0048261 - Add new function fetch_expense_account
-- 1.6  04-AUG-2020 Diptasurjya CHG0047808 - Modify fetch_expense_account for LATAM resellers
-- 1.7  01-OCT-2020 Diptasurjya CHG0048619 - Add new section to delete any previously calculated data if IB change is detected
-- ---------------------------------------------------------------------------------------------

   TYPE l_comm_rec_type IS RECORD(
      customer_trx_line_id    ra_customer_trx_lines.customer_trx_line_id%TYPE,
      consumable_id           xxcn_consumable_items.consumable_id%TYPE,
      trx_amount              ra_customer_trx_lines.extended_amount%TYPE,
      trx_pct                 NUMBER,
      commission_trx_amount   ra_customer_trx_lines.extended_amount%TYPE,
      calc_source             xxcn_calc_commission.calc_source%TYPE,
      message_type            VARCHAR2(30),
      message                 VARCHAR2(500)
   );

   TYPE l_system_rec_type IS RECORD(
      revenue_pct             NUMBER,
      total_revenue_pct       NUMBER,
      comm_exclude_flag       VARCHAR2(1),
      reseller_id             xxoe_reseller_order_rel_v.reseller_id%TYPE,
      business_line           xxoe_reseller_order_rel_v.business_line%TYPE,
      product                 xxoe_reseller_order_rel_v.product%TYPE,
      family                  xxoe_reseller_order_rel_v.family%TYPE
   );

   g_request_id               NUMBER   := TO_NUMBER(fnd_global.conc_request_id);
   g_user_id                  NUMBER   := TO_NUMBER(fnd_profile.value('USER_ID'));
   g_login_id                 NUMBER   := TO_NUMBER(fnd_profile.value('LOGIN_ID'));

-- --------------------------------------------------------------------------------------------
-- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
-- ----------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  01/23/2015  MMAZANET    Initial Creation for CHG00XXXXX.
-- ---------------------------------------------------------------------------------------------
PROCEDURE write_log(p_msg  VARCHAR2)
IS
BEGIN
  IF g_log = 'Y' AND 'xxcn.pre_calc_commissions.xxcn_calc_commission_pkg.'||g_program_unit LIKE LOWER(g_log_module) THEN
    fnd_file.put_line(fnd_file.log,TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS')||' - '||p_msg);
  END IF;
END write_log;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Finds the consumable_id based on the values passed in.  This is a hierarchy starting
--          at the item level moving up to the business_line of an item.  As soon as a match is found
--          e_done is raised and the value is returned.
--          NOTE: Debug level must be set to 0 to see messages from this procedure
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------

   FUNCTION get_consumable_id(
      p_business_line      VARCHAR2
   ,  p_product            VARCHAR2
   ,  p_family             VARCHAR2
   ,  p_inventory_item_id  NUMBER
   ,  p_inventory_org_id   NUMBER
   )
   RETURN NUMBER
   IS l_consumable_id         xxcn_consumable_items.consumable_id%TYPE;
      e_done                  EXCEPTION;
   BEGIN
      write_log('START GET_CONSUMABLE_ID');
      write_log(
                                   'p_business_line: '||p_business_line
                                 ||' p_product: '||p_product
                                 ||' p_family: '||p_family
                                 ||' p_inventory_item_id: '||p_inventory_item_id
                                 ||' p_inventory_org_id: '||p_inventory_org_id
                                 );


      BEGIN
         SELECT consumable_id
         INTO l_consumable_id
         FROM  xxcn_consumable_items
         WHERE inventory_item_id       = p_inventory_item_id
         AND   inventory_org_id        = p_inventory_org_id;

      EXCEPTION
         WHEN OTHERS THEN
            write_log('Exception occurred while searching for item/org: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
            l_consumable_id := NULL;
      END;

      IF l_consumable_id IS NOT NULL THEN
         RAISE e_done;
      END IF;

      BEGIN
         SELECT consumable_id
         INTO l_consumable_id
         FROM  xxcn_consumable_items
         WHERE inventory_item_id = p_inventory_item_id;

      EXCEPTION
         WHEN OTHERS THEN
            write_log('Exception occurred while searching for item: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
            l_consumable_id := NULL;
      END;

      IF l_consumable_id IS NOT NULL THEN
         RAISE e_done;
      END IF;

      BEGIN
         SELECT consumable_id
         INTO l_consumable_id
         FROM  xxcn_consumable_items
         WHERE business_line     = p_business_line
         AND   product           = p_product
         AND   family            = p_family;

      EXCEPTION
         WHEN OTHERS THEN
            write_log('Exception occurred while searching for family : '||DBMS_UTILITY.FORMAT_ERROR_STACK);
            l_consumable_id := NULL;
      END;

      IF l_consumable_id IS NOT NULL THEN
         RAISE e_done;
      END IF;

      BEGIN
         SELECT consumable_id
         INTO l_consumable_id
         FROM  xxcn_consumable_items
         WHERE business_line  = p_business_line
         AND   product        = p_product
         AND   family         IS NULL;

      EXCEPTION
         WHEN OTHERS THEN
            write_log('Exception occurred while searching for product : '||DBMS_UTILITY.FORMAT_ERROR_STACK);
            l_consumable_id := NULL;
      END;

      IF l_consumable_id IS NOT NULL THEN
         RAISE e_done;
      END IF;

      BEGIN
         SELECT consumable_id
         INTO l_consumable_id
         FROM  xxcn_consumable_items
         WHERE business_line  = p_business_line
         AND   product        IS NULL
         AND   family         IS NULL;

      EXCEPTION
         WHEN OTHERS THEN
            write_log('Exception occurred while searching for business line : '||DBMS_UTILITY.FORMAT_ERROR_STACK);
            l_consumable_id := NULL;
      END;

      write_log('END GET_CONSUMABLE_ID');
      RETURN l_consumable_id;
   EXCEPTION
      WHEN e_done THEN
         write_log('No Error.  l_consumable_id: '||l_consumable_id);
         RETURN l_consumable_id;
      WHEN OTHERS THEN
         write_log('Unexpected error in get_consumable_id: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
         RETURN l_consumable_id;
   END get_consumable_id;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Finds the system_id based on the values passed in.  This is a hierarchy starting
--          at the item level moving up to the business_line of an item.  As soon as a match is found
--          e_done is raised and the value is returned.
--          NOTE: Debug level must be set to 0 to see messages from this procedure
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- 1.1  03/30/2018  DCHATTERJEE INC0117839 - OIC order not processed due to similar product family value
-- ---------------------------------------------------------------------------------------------
   FUNCTION get_system_id(
      p_business_line      VARCHAR2
   ,  p_product            VARCHAR2
   ,  p_family             VARCHAR2
   ,  p_inventory_item_id  NUMBER
   ,  p_inventory_org_id   NUMBER
   )
   RETURN NUMBER
   IS l_system_id             xxcn_system_items.system_id%TYPE;
      e_done                  EXCEPTION;
   BEGIN
      write_log('START GET_SYSTEM_ID');
      write_log('p_business_line: '||p_business_line
                                 ||' p_product: '||p_product
                                 ||' p_family: '||p_family
                                 ||' p_inventory_item_id: '||TO_CHAR(p_inventory_item_id)
                                 ||' p_inventory_org_id: '||TO_CHAR(p_inventory_org_id));

      BEGIN
         SELECT system_id
         INTO l_system_id
         FROM  xxcn_system_items
         WHERE inventory_item_id       = p_inventory_item_id
         AND   inventory_org_id        = p_inventory_org_id
         AND   SYSDATE                 BETWEEN NVL(start_date,'01-JAN-1900')
                                          AND NVL(end_date,'31-DEC-4712');

      EXCEPTION
         WHEN OTHERS THEN
            write_log('Exception occurred while searching for item/org: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
            l_system_id := NULL;
      END;

      IF l_system_id IS NOT NULL THEN
         RAISE e_done;
      END IF;

      BEGIN
         SELECT system_id
         INTO l_system_id
         FROM  xxcn_system_items
         WHERE inventory_item_id = p_inventory_item_id
         AND   SYSDATE           BETWEEN NVL(start_date,'01-JAN-1900')
                                    AND NVL(end_date,'31-DEC-4712');

      EXCEPTION
         WHEN OTHERS THEN
            write_log('Exception occurred while searching for item: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
            l_system_id := NULL;
      END;

      IF l_system_id IS NOT NULL THEN
         RAISE e_done;
      END IF;

      BEGIN
         SELECT system_id
         INTO l_system_id
         FROM  xxcn_system_items
         WHERE business_line  = p_business_line
         AND   product        = p_product   -- INC0117839 match with product instead of p_product
         AND   family         = p_family
         AND   SYSDATE        BETWEEN NVL(start_date,'01-JAN-1900')
                                 AND NVL(end_date,'31-DEC-4712');

      EXCEPTION
         WHEN OTHERS THEN
            write_log('Exception occurred while searching for family : '||DBMS_UTILITY.FORMAT_ERROR_STACK);
            l_system_id := NULL;
      END;

      IF l_system_id IS NOT NULL THEN
         RAISE e_done;
      END IF;

      BEGIN
         SELECT system_id
         INTO l_system_id
         FROM  xxcn_system_items
         WHERE business_line  = p_business_line
         AND   product        = p_product
         AND   family         IS NULL
         AND   SYSDATE        BETWEEN NVL(start_date,'01-JAN-1900')
                                 AND NVL(end_date,'31-DEC-4712');

      EXCEPTION
         WHEN OTHERS THEN
            write_log('Exception occurred while searching for product : '||DBMS_UTILITY.FORMAT_ERROR_STACK);
            l_system_id := NULL;
      END;

      IF l_system_id IS NOT NULL THEN
         RAISE e_done;
      END IF;

      BEGIN
         SELECT system_id
         INTO l_system_id
         FROM  xxcn_system_items
         WHERE business_line  = p_business_line
         AND   product        IS NULL
         AND   family         IS NULL
         AND   SYSDATE        BETWEEN NVL(start_date,'01-JAN-1900')
                                 AND NVL(end_date,'31-DEC-4712');

      EXCEPTION
         WHEN OTHERS THEN
            write_log('Exception occurred while searching for business line : '||DBMS_UTILITY.FORMAT_ERROR_STACK);
            l_system_id := NULL;
      END;

      write_log('END GET_SYSTEM_ID');
      RETURN l_system_id;
   EXCEPTION
      WHEN e_done THEN
         write_log('No error.  l_system_id: '||l_system_id);
         RETURN l_system_id;
      WHEN OTHERS THEN
         write_log('Unexpected error in get_consumable_id: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
         RETURN l_system_id;
   END get_system_id;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This procedure will check for a valid combination of segments for the Commissions
--          category.  If one row or too many rows are returned, this means the combination is
--          valid.  Any of the parameters can be NULL.  This is used for validation on form.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   FUNCTION is_category_combo_valid(
      p_business_line      IN VARCHAR2
   ,  p_product            IN VARCHAR2
   ,  p_family             IN VARCHAR2
   )
   RETURN BOOLEAN
   IS l_dummy  VARCHAR2(1);
   BEGIN
      write_log('START IS_CATEGORY_COMBO_VALID');
      write_log('p_business_line: '||p_business_line);
      write_log('p_product: '||p_product);
      write_log('p_family: '||p_family);

      IF p_business_line IS NOT NULL
         OR p_product IS NOT NULL
         OR p_family IS NOT NULL
      THEN
         SELECT 'Y'
         INTO l_dummy
         FROM
            mtl_categories_vl       mcv
         ,  MTL_CATEGORY_SETS_VL    mcsv
         WHERE mcsv.category_set_name  = 'Commissions'
         AND   mcsv.structure_id       = mcv.structure_id
         AND   mcv.segment3            = NVL(p_business_line,mcv.segment3)
         AND   mcv.segment2            = NVL(p_family,mcv.segment2)
         AND   mcv.segment1            = NVL(p_product,mcv.segment1);
      END IF;

      write_log('END IS_CATEGORY_COMBO_VALID');
      RETURN TRUE;
   EXCEPTION
      WHEN TOO_MANY_ROWS THEN
         write_log('No Error.  More than one row returned.');
         RETURN TRUE;
      WHEN NO_DATA_FOUND THEN
         write_log('No Error.  No data found.');
         RETURN FALSE;
      WHEN OTHERS THEN
         write_log('Unexpected Error: '||SQLERRM);
         RETURN FALSE;
   END is_category_combo_valid;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Counts the number of records existing where the system_id or consumable_id, depending
--          on p_record_type, is equal to p_record_id
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   FUNCTION get_count_linked_recs(
      p_record_id    NUMBER
   ,  p_record_type  VARCHAR2
   )
   RETURN NUMBER
   IS l_count NUMBER := 0;
   BEGIN
      write_log('START GET_COUNT_LINKED_RECS');
      write_log('p_record_id: '||p_record_id);
      write_log('p_record_type: '||p_record_type);

      SELECT COUNT(*)
      INTO l_count
      FROM xxcn_system_to_consumable
      WHERE DECODE(p_record_type
            ,  'SYSTEM',      system_id
            ,  'CONSUMABLE',  consumable_id
            ,  -9)         =  p_record_id;

      write_log('l_count: '||l_count);
      write_log('END GET_COUNT_LINKED_RECS');
      RETURN l_count;
   END get_count_linked_recs;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Attempts to find a matching record based on the concatenated string column of
--          either table (xxcn_system_items or xxcn_consumable_items).  The string, in both
--          tables is made up of the following fields:
--          product.family.business_line.item_id,item_org_id
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE does_rec_exist (
      p_rec_type              IN       VARCHAR2
   ,  p_consumable_item_rec   IN       xxcn_consumable_items%ROWTYPE
   ,  p_system_item_rec       IN       xxcn_system_items%ROWTYPE
   ,  x_record_id             OUT      xxcn_consumable_items.consumable_id%TYPE
   ,  x_return_status         OUT      VARCHAR2
   ,  x_return_msg            OUT      VARCHAR2
   )
   IS
   BEGIN
      write_log('START DOES_REC_EXIST');
      write_log('p_rec_type: '||p_rec_type);

      IF p_rec_type = 'CONSUMABLE' THEN
         SELECT consumable_id
         INTO x_record_id
         FROM
            xxcn_consumable_items
         WHERE concatenated_string = p_consumable_item_rec.concatenated_string;
      ELSIF p_rec_type = 'SYSTEM' THEN
         SELECT system_id
         INTO x_record_id
         FROM
            xxcn_system_items
         WHERE concatenated_string = p_system_item_rec.concatenated_string;
      END IF;

      x_return_status := 'S';
      write_log('END DOES_REC_EXIST');
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         x_record_id       := NULL;
         x_return_status   := 'S';
         write_log('No error.  No '||p_rec_type||'_id found');
      WHEN OTHERS THEN
         --add error
         x_return_msg      := 'Error in does_consumable_exist: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
         x_return_status   := 'E';
         write_log('In does_rec_exist '||x_return_msg);
   END does_rec_exist;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Inserts record into either xxcn_system_items or xxcn_consumable_items depending on
--          if p_record_type equals SYSTEM or CONSUMABLE
--
--          NOTE: This should never be called directly.  Inserts should be called from
--                insert_system_consumable
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE ins_system_or_consumable_tbl(
      p_record_type              IN       VARCHAR2
   ,  p_consumable_item_rec      IN OUT   xxcn_consumable_items%ROWTYPE
   ,  p_system_item_rec          IN OUT   xxcn_system_items%ROWTYPE
   ,  x_return_status            OUT      VARCHAR2
   ,  x_return_msg               OUT      VARCHAR2
   )
   IS
      l_existing_related_recs_count NUMBER := 0;
      l_consumable_item_rec   xxcn_consumable_items%ROWTYPE := p_consumable_item_rec;
      l_system_item_rec       xxcn_system_items%ROWTYPE     := p_system_item_rec;
   BEGIN
      write_log('START INS_SYSTEM_OR_CONSUMABLE_TBL');
      write_log('p_record_type: '||p_record_type);
      write_log('p_system_item_rec.concatenated_string: '||p_system_item_rec.concatenated_string);
      write_log('p_consumable_item_rec.concatenated_string: '||p_consumable_item_rec.concatenated_string);

      IF p_record_type = 'CONSUMABLE' THEN
         -- Consumable record does not yet exist
         SELECT xxcn_consumable_items_s.NEXTVAL
         INTO l_consumable_item_rec.consumable_id
         FROM DUAL;

         l_consumable_item_rec.created_by          := g_user_id;
         l_consumable_item_rec.creation_date       := SYSDATE;
         l_consumable_item_rec.last_updated_by     := g_user_id;
         l_consumable_item_rec.last_update_date    := SYSDATE;
         l_consumable_item_rec.last_update_login   := g_login_id;

         write_log('l_consumable_item_rec.consumable_id: '||l_consumable_item_rec.consumable_id);

         INSERT INTO xxcn_consumable_items
         VALUES l_consumable_item_rec;
      ELSIF p_record_type = 'SYSTEM' THEN
         -- Consumable record does not yet exist
         SELECT xxcn_system_items_s.NEXTVAL
         INTO l_system_item_rec.system_id
         FROM DUAL;

         l_system_item_rec.created_by           := g_user_id;
         l_system_item_rec.creation_date        := SYSDATE;
         l_system_item_rec.last_updated_by      := g_user_id;
         l_system_item_rec.last_update_date     := SYSDATE;
         l_system_item_rec.last_update_login    := g_login_id;
         l_system_item_rec.parent_system_flag   := NVL(l_system_item_rec.parent_system_flag,'Y');
         l_system_item_rec.exclude_flag         := NVL(l_system_item_rec.exclude_flag,'Y');

         write_log('l_system_item_rec.system_id: '||l_system_item_rec.system_id);

         INSERT INTO xxcn_system_items
         VALUES l_system_item_rec;
      END IF;

      p_consumable_item_rec   := l_consumable_item_rec;
      p_system_item_rec       := l_system_item_rec;

      x_return_status := 'S';
      write_log('END INS_SYSTEM_OR_CONSUMABLE_TBL');
   EXCEPTION
      WHEN OTHERS THEN
        x_return_status   := 'E';
        x_return_msg      := 'Error in ins_system_or_consumable_tbl: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
        write_log('In others '||x_return_msg);
   END ins_system_or_consumable_tbl;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Updates record on either xxcn_system_items or xxcn_consumable_items depending on
--          if p_record_type equals SYSTEM or CONSUMABLE
--
--          NOTE: This should never be called directly.  Updates should be called from
--                update_system_consumable
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE updt_system_or_consumable_tbl(
      p_record_type              IN  VARCHAR2
   ,  p_consumable_item_rec      IN  xxcn_consumable_items%ROWTYPE
   ,  p_system_item_rec          IN  xxcn_system_items%ROWTYPE
   ,  x_return_status            OUT VARCHAR2
   ,  x_return_msg               OUT VARCHAR2
   )
   IS
      CURSOR c_system
      IS
         SELECT *
         FROM xxcn_system_items
         WHERE system_id = p_system_item_rec.system_id
         FOR UPDATE OF start_date
         NOWAIT;

      CURSOR c_consumable
      IS
         SELECT *
         FROM xxcn_consumable_items
         WHERE consumable_id = p_consumable_item_rec.consumable_id
         FOR UPDATE OF product
         NOWAIT;

      e_error           EXCEPTION;
      e_resource_busy   EXCEPTION;
      PRAGMA EXCEPTION_INIT (e_resource_busy, -54);
   BEGIN
      write_log('START UPDT_SYSTEM_OR_CONSUMABLE_TBL');
      write_log('p_record_type: '||p_record_type);
      write_log('p_system_item_rec.system_id: '||p_system_item_rec.system_id);
      write_log('p_consumable_item_rec.consumable_id: '||p_consumable_item_rec.consumable_id);

      -- System Updates
      IF p_record_type = 'SYSTEM' THEN
         FOR rec IN c_system LOOP
            UPDATE xxcn_system_items
            SET
               product              = p_system_item_rec.product
            ,  family               = p_system_item_rec.family
            ,  business_line        = p_system_item_rec.business_line
            ,  inventory_item_id    = p_system_item_rec.inventory_item_id
            ,  inventory_org_id     = p_system_item_rec.inventory_org_id
            ,  start_date           = p_system_item_rec.start_date
            ,  end_date             = p_system_item_rec.end_date
            ,  concatenated_string  = p_system_item_rec.concatenated_string
            ,  last_update_date     = SYSDATE
            ,  last_updated_by      = g_user_id
            ,  last_update_login    = g_login_id
            WHERE CURRENT OF c_system;
         END LOOP;
      -- Date related updates
      ELSIF p_record_type = 'SYSTEM_DATE' THEN
         FOR rec IN c_system LOOP
            UPDATE xxcn_system_items
            SET
               start_date           = p_system_item_rec.start_date
            ,  end_date             = p_system_item_rec.end_date
            ,  last_update_date     = SYSDATE
            ,  last_updated_by      = g_user_id
            ,  last_update_login    = g_login_id
            WHERE CURRENT OF c_system;
         END LOOP;
      -- Consumable Updates
      ELSIF p_record_type = 'CONSUMABLE' THEN
         FOR rec IN c_consumable LOOP
            UPDATE xxcn_consumable_items
            SET
               product              = p_consumable_item_rec.product
            ,  family               = p_consumable_item_rec.family
            ,  business_line        = p_consumable_item_rec.business_line
            ,  inventory_item_id    = p_consumable_item_rec.inventory_item_id
            ,  inventory_org_id     = p_consumable_item_rec.inventory_org_id
            ,  concatenated_string  = p_consumable_item_rec.concatenated_string
            ,  last_update_date     = SYSDATE
            ,  last_updated_by      = g_user_id
            ,  last_update_login    = g_login_id
            WHERE CURRENT OF c_consumable;
         END LOOP;
      END IF;

      x_return_status := 'S';
      write_log('END UPDT_SYSTEM_OR_CONSUMABLE_TBL');
   EXCEPTION
      WHEN e_resource_busy THEN
         x_return_status   := 'E';
         x_return_msg      := 'Error: Record on XXCN_'||p_record_type||'_ITEMS is locked by another user.';
         write_log(x_return_msg);
      WHEN OTHERS THEN
         x_return_status   := 'E';
         x_return_msg      := 'Error in updt_system_or_consumable_tbl: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
         write_log('In others '||x_return_msg);
   END updt_system_or_consumable_tbl;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Deletes record from either xxcn_system_items or xxcn_consumable_items depending on
--          if p_record_type equals SYSTEM or CONSUMABLE
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE del_consumable_tbl(
      p_consumable_item_rec   xxcn_consumable_items%ROWTYPE
   ,  x_return_status         OUT VARCHAR2
   ,  x_return_msg            OUT VARCHAR2
   )
   IS
      CURSOR c_consumable
      IS
         SELECT *
         FROM xxcn_consumable_items
         WHERE consumable_id = p_consumable_item_rec.consumable_id
         FOR UPDATE OF product
         NOWAIT;

      e_error           EXCEPTION;
      e_resource_busy   EXCEPTION;
      PRAGMA EXCEPTION_INIT (e_resource_busy, -54);
   BEGIN
      write_log('START DEL_SYSTEM_OR_CONSUMABLE_TBL');
      write_log('p_consumable_item_rec.consumable_id: '||p_consumable_item_rec.consumable_id);

      FOR rec IN c_consumable LOOP
         DELETE FROM xxcn_consumable_items
         WHERE CURRENT OF c_consumable;
      END LOOP;

      x_return_status := 'S';
      write_log('END DEL_SYSTEM_OR_CONSUMABLE_TBL');
   EXCEPTION
      WHEN e_resource_busy THEN
         x_return_status   := 'E';
         x_return_msg      := 'Error: Record on XXCN_CONSUMABLE_ITEMS is locked by another user.';
         write_log(x_return_msg);
      WHEN OTHERS THEN
         x_return_status   := 'E';
         x_return_msg      := 'Error in del_consumable_tbl: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
         write_log('In others '||x_return_msg);
   END del_consumable_tbl;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This procedure is used to check dates for systems related to consumables or consumables
--          related to systems to ensure dates for detail records fall within their master's
--          dates.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE validate_dates(
      p_system_to_consumable_rec IN  xxcn_system_to_consumable%ROWTYPE
   ,  p_system_id                IN  xxcn_system_items.system_id%TYPE
   ,  x_return_status            OUT VARCHAR2
   ,  x_return_msg               OUT VARCHAR2
   )
   IS
      CURSOR c_get_linked_systems
      IS
         SELECT
            xsi.system_id
         ,  xsi.start_date
         ,  xsi.end_date
         FROM
            xxcn_system_items          xsi
         ,  xxcn_system_to_consumable  xsc
         WHERE xsi.system_id     = xsc.system_id
         AND   xsc.consumable_id = p_system_to_consumable_rec.consumable_id
         -- May need to look through multiple systems linked to a consumable
         AND   xsc.system_id     = NVL(p_system_id,xsc.system_id);

      e_error  EXCEPTION;
   BEGIN
      write_log('START VALIDATE_DATES');
      write_log('p_system_to_consumable_rec.start_date: '||p_system_to_consumable_rec.start_date);
      write_log('p_system_to_consumable_rec.end_date: '||p_system_to_consumable_rec.end_date);
      write_log('p_system_to_consumable_rec.consumable_id: '||p_system_to_consumable_rec.consumable_id);
      write_log('p_system_id: '||p_system_id);

      FOR rec IN c_get_linked_systems
      LOOP
         write_log('rec.system_id: '||rec.system_id);
         write_log('rec.start_date: '||rec.start_date);
         write_log('rec.end_date: '||rec.end_date);

         IF NVL(p_system_to_consumable_rec.start_date,TO_DATE('01-JAN-1900','DD-MON-YYYY')) < NVL(rec.start_date,TO_DATE('01-JAN-1900','DD-MON-YYYY')) THEN
            x_return_msg := 'Error: Consumable Start Date can not be NULL or occur before System Start Date of '||rec.start_date||' on System ID '||rec.system_id;
            RAISE e_error;
         ELSIF NVL(p_system_to_consumable_rec.end_date,TO_DATE('31-DEC-4712','DD-MON-YYYY')) > NVL(rec.end_date,TO_DATE('31-DEC-4712','DD-MON-YYYY')) THEN
            x_return_msg := 'Error: Consumable End Date can not be NULL or occur after System End Date of '||rec.end_date||' on System ID '||rec.system_id;
            RAISE e_error;
         ELSIF NVL(p_system_to_consumable_rec.end_date,TO_DATE('31-DEC-4712','DD-MON-YYYY'))
                     < NVL(p_system_to_consumable_rec.start_date,TO_DATE('01-JAN-1900','DD-MON-YYYY')) THEN
            x_return_msg := 'Error: Consumable End Date must be after Consumable Start Date';
            RAISE e_error;
         END IF;
      END LOOP;

      write_log('END VALIDATE_DATES');
   EXCEPTION
      WHEN e_error THEN
         write_log(x_return_msg);
         x_return_status := 'E';
      WHEN OTHERS THEN
         x_return_msg := 'Unexpected Error in validate_dates: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
         write_log(x_return_msg);
         x_return_status := 'E';
   END validate_dates;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Updates the xxcn_system_to_consumable table.  This holds the many-to-many relationship
--          of xxcn_system_items to xxcn_consumable_items.
--
--          NOTE: This should never be called directly.  Updates should be called from
--                update_system_consumable procedure
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE updt_system_to_consumable_tbl(
      p_record_type              IN  VARCHAR2
   ,  p_system_to_consumable_rec IN  xxcn_system_to_consumable%ROWTYPE
   ,  p_system_rec               IN  xxcn_system_items%ROWTYPE
   ,  p_new_record_id            IN  NUMBER
   ,  p_old_record_id1           IN  NUMBER
   ,  p_old_record_id2           IN  NUMBER
   ,  x_return_status            OUT VARCHAR2
   ,  x_return_msg               OUT VARCHAR2
   )
   IS
      CURSOR c_update(p_consumable_id  IN NUMBER
                     ,p_system_id      IN NUMBER)
      IS
         SELECT
            system_id
         ,  consumable_id
         ,  start_date
         ,  end_date
         ,  comm_calc_on_rel_sys_flag
         ,  comm_exclude_flag
         ,  last_update_date
         ,  last_updated_by
         ,  last_update_login
         FROM xxcn_system_to_consumable
         WHERE system_id         = NVL(p_system_id,system_id)
         AND   consumable_id     = NVL(p_consumable_id,consumable_id)
         -- Prenvents wide open table update in the event that both parameters are NULL
         -- This should never happen.
         AND  (p_system_id       IS NOT NULL
         OR    p_consumable_id   IS NOT NULL)
         FOR UPDATE OF
            system_id
         ,  start_date
         ,  end_date
         ,  comm_calc_on_rel_sys_flag
         ,  last_update_date
         ,  last_updated_by
         ,  last_update_login
         NOWAIT;

      e_error           EXCEPTION;
      e_resource_busy   EXCEPTION;
      PRAGMA EXCEPTION_INIT (e_resource_busy, -54);
   BEGIN
      write_log('START UPDT_SYSTEM_TO_CONSUMABLE_TBL');
      write_log('p_record_type: '||p_record_type);
      write_log('p_new_record_id: '||p_new_record_id);
      write_log('p_old_record_id1: '||p_old_record_id1);
      write_log('p_old_record_id2: '||p_old_record_id2);
      write_log('p_system_rec.system_id: '||p_system_rec.system_id);
      write_log('p_system_rec.start_date: '||p_system_rec.start_date);
      write_log('p_system_rec.end_date: '||p_system_rec.end_date);

      IF p_record_type = 'SYSTEM' THEN
         FOR rec IN c_update(p_old_record_id2
                            ,p_old_record_id1)
         LOOP
            write_log('Updating xxcn_system_to_consumable record system_id: '||rec.system_id||' consumable_id: '||rec.consumable_id);

            UPDATE xxcn_system_to_consumable
            SET
               system_id                  = p_new_record_id
            ,  last_update_date           = SYSDATE
            ,  last_updated_by            = TO_NUMBER(fnd_profile.value('USER_ID'))
            ,  last_update_login          = TO_NUMBER(fnd_profile.value('LOGIN_ID'))
            WHERE CURRENT OF c_update;
         END LOOP;

      ELSIF p_record_type = 'SYSTEM_DATE' THEN
         -- Updates the start/end dates on xxcn_system_to_consumable to synch with system records on xxcn_system_items in the
         -- event that a start/end date changes on the system record
         FOR rec IN c_update(NULL
                            ,p_system_rec.system_id)
         LOOP
            write_log('Updating xxcn_system_to_consumable record system_id: '||rec.system_id||' consumable_id: '||rec.consumable_id);

            UPDATE xxcn_system_to_consumable
            SET
               start_date                 =  CASE
                                             -- If the consumable start_date is less than the system start_date
                                             -- we need to update to the system_to_consumable start_date to the
                                             -- system's start_date
                                                WHEN NVL(start_date,TO_DATE('01011900','MMDDYYYY')) < NVL(p_system_rec.start_date,TO_DATE('01011900','MMDDYYYY'))
                                                   THEN p_system_rec.start_date
                                                WHEN p_system_rec.start_date IS NULL
                                                   THEN NULL
                                                ELSE start_date
                                             END
                                             -- If the consumable end_date is greater than the system end_date
                                             -- we need to update to the system_to_consumable end_date to the
                                             -- system's end_date
            ,  end_date                   =  CASE
                                                WHEN NVL(end_date,TO_DATE('12314712','MMDDYYYY')) > NVL(p_system_rec.end_date,TO_DATE('12314712','MMDDYYYY'))
                                                   THEN p_system_rec.end_date
                                                WHEN p_system_rec.end_date IS NULL
                                                   THEN NULL
                                                ELSE end_date
                                             END
            ,  last_update_date           = SYSDATE
            ,  last_updated_by            = TO_NUMBER(fnd_profile.value('USER_ID'))
            ,  last_update_login          = TO_NUMBER(fnd_profile.value('LOGIN_ID'))
            WHERE CURRENT OF c_update;
         END LOOP;
      ELSIF p_record_type = 'CONSUMABLE' THEN
         FOR rec IN c_update(p_old_record_id1
                            ,p_old_record_id2)
         LOOP
            write_log('Updating xxcn_system_to_consumable record system_id: '||rec.system_id||' consumable_id: '||rec.consumable_id);

            -- Need to check dates against all systems the consumable is tied to.
            validate_dates(
               p_system_to_consumable_rec => p_system_to_consumable_rec
            ,  p_system_id                => p_old_record_id2
            ,  x_return_status            => x_return_status
            ,  x_return_msg               => x_return_msg
            );

            IF x_return_status <> 'S' THEN
               RAISE e_error;
            END IF;

            UPDATE xxcn_system_to_consumable
            SET
               consumable_id              = p_new_record_id
            ,  start_date                 = p_system_to_consumable_rec.start_date
            ,  end_date                   = p_system_to_consumable_rec.end_date
            ,  comm_calc_on_rel_sys_flag  = p_system_to_consumable_rec.comm_calc_on_rel_sys_flag
            ,  comm_exclude_flag          = p_system_to_consumable_rec.comm_exclude_flag
            ,  last_update_date           = SYSDATE
            ,  last_updated_by            = TO_NUMBER(fnd_profile.value('USER_ID'))
            ,  last_update_login          = TO_NUMBER(fnd_profile.value('LOGIN_ID'))
            WHERE CURRENT OF c_update;
         END LOOP;
      END IF;

      x_return_status := 'S';
      write_log('END UPDT_SYSTEM_TO_CONSUMABLE_TBL');
   EXCEPTION
      WHEN e_resource_busy THEN
         x_return_status   := 'E';
         x_return_msg      := 'Error: Record on xxcn_system_to_consumables is currently locked by another user.';
         write_log(x_return_msg);
      WHEN e_error THEN
         x_return_status := 'E';
         write_log(x_return_msg);
      WHEN OTHERS THEN
         x_return_status   := 'E';
         x_return_msg      := 'Error in updt_system_to_consumable_tbl: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
         write_log('In others '||x_return_msg);
   END updt_system_to_consumable_tbl;

-- ---------------------------------------------------------------------------------------------
-- Purpose: If a date on a system is changed, that date needs to cascade across the consumables
--          linked to that system.  If a date on a consumable is changed, we need to make sure
--          it falls within the parameters of the system date
--
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE chg_date_on_linked_consumables(
      p_system_to_consumable_rec IN  xxcn_system_to_consumable%ROWTYPE
   ,  p_system_rec               IN  xxcn_system_items%ROWTYPE
   ,  p_existing_record_id       IN  xxcn_system_items.system_id%TYPE
   ,  x_return_status            OUT VARCHAR2
   ,  x_return_msg               OUT VARCHAR2
   )
   IS
      l_is_system_end_date_updated     VARCHAR2(1) := 'N';
      l_is_system_start_date_updated   VARCHAR2(1) := 'N';
      l_system_rec                     xxcn_system_items%ROWTYPE;
      e_error                          EXCEPTION;
   BEGIN
      write_log('START CHG_DATE_ON_LINKED_CONSUMABLES');
      write_log('p_existing_record_id:    '||p_existing_record_id);
      write_log('p_system_rec.start_date: '||p_system_rec.start_date);
      write_log('p_system_rec.end_date:   '||p_system_rec.end_date);

      l_system_rec := p_system_rec;

      -- If system record already exists, dates will be looked at on that system record.
      -- This would only happen if the user attempted to update another field as well as
      -- one of the date fields at the same time.
      IF p_existing_record_id IS NOT NULL THEN
         l_system_rec.system_id := p_existing_record_id;
      END IF;
      write_log('l_system_rec.system_id: '||l_system_rec.system_id);

      -- Check to see if system dates have changed
      SELECT
         CASE
            WHEN NVL(l_system_rec.start_date,'01-JAN-1900') = NVL(start_date,'01-JAN-1900')
            THEN  'N'
            ELSE 'Y'
         END
      ,  CASE
            WHEN NVL(l_system_rec.end_date,'31-DEC-4712') = NVL(end_date,'31-DEC-4712')
            THEN  'N'
            ELSE 'Y'
         END
      INTO
         l_is_system_start_date_updated
      ,  l_is_system_end_date_updated
      FROM xxcn_system_items
      WHERE system_id = l_system_rec.system_id;

      write_log('l_is_system_start_date_updated: '||l_is_system_start_date_updated);
      write_log('l_is_system_end_date_updated: '||l_is_system_end_date_updated);

      IF l_is_system_start_date_updated = 'Y'
         OR l_is_system_end_date_updated = 'Y'
      THEN
         -- If the date has not been updated, we will set it to NULL.  This will prevent
         -- updt_system_to_consumable_tbl procedure from updating the date on consumable
         -- records in the event that no date change has taken place.
         IF l_is_system_start_date_updated = 'N' THEN
            l_system_rec.start_date := NULL;
         ELSIF l_is_system_end_date_updated = 'N' THEN
            l_system_rec.end_date   := NULL;
         END IF;

         updt_system_to_consumable_tbl(
            p_record_type              => 'SYSTEM_DATE'
         ,  p_system_to_consumable_rec => NULL
         ,  p_system_rec               => l_system_rec
         ,  p_new_record_id            => TO_NUMBER(NULL)
         ,  p_old_record_id1           => TO_NUMBER(NULL)
         ,  p_old_record_id2           => TO_NUMBER(NULL)
         ,  x_return_status            => x_return_status
         ,  x_return_msg               => x_return_msg
         );

         IF x_return_status <> 'S' THEN
            RAISE e_error;
         END IF;

         updt_system_or_consumable_tbl(
            p_record_type              => 'SYSTEM'
         ,  p_consumable_item_rec      => NULL
         ,  p_system_item_rec          => l_system_rec
         ,  x_return_status            => x_return_status
         ,  x_return_msg               => x_return_msg
         );

         IF x_return_status <> 'S' THEN
            RAISE e_error;
         END IF;
      ELSE
         x_return_status := 'S';
      END IF;

      write_log('END CHG_DATE_ON_LINKED_CONSUMABLES');
   EXCEPTION
      WHEN e_error THEN
         x_return_status := 'E';
         x_return_msg    := x_return_msg;
         write_log('In others '||x_return_msg);
      WHEN NO_DATA_FOUND THEN
         x_return_status := 'S';
         xxobjt_utl_debug_pkg.log_err(NULL,'No error.  No date changes');
      WHEN OTHERS THEN
         x_return_status   := 'E';
         x_return_msg      := 'Unexpected Error in chg_date_on_linked_consumables: '||SQLERRM;
         write_log('In others '||x_return_msg);
   END chg_date_on_linked_consumables;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Shared validation routine used by update_system_consumable and insert_system_consumable
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE validate_system_consumable(
      p_consumable_item_rec      IN OUT   xxcn_consumable_items%ROWTYPE
   ,  p_system_item_rec          IN OUT   xxcn_system_items%ROWTYPE
   ,  x_return_status            OUT      VARCHAR2
   ,  x_return_msg               OUT      VARCHAR2
   )
   IS
      e_error                       EXCEPTION;
      l_consumable_item_rec
        xxcn_consumable_items%ROWTYPE;
      l_system_item_rec             xxcn_system_items%ROWTYPE;
   BEGIN
      write_log('START VALIDATE_SYSTEM_CONSUMABLE');

      write_log('Calling is_category_combo_valid for Consumable');
      IF NOT   is_category_combo_valid(
                  p_business_line   => p_consumable_item_rec.business_line
               ,  p_product         => p_consumable_item_rec.product
               ,  p_family          => p_consumable_item_rec.family
               )
      THEN
         x_return_msg := 'Error: Combination of business line/product/family is invalid for Consumable';
         RAISE e_error;
      END IF;

      write_log('Calling is_category_combo_valid for System');
      IF NOT   is_category_combo_valid(
                  p_business_line   => p_system_item_rec.business_line
               ,  p_product         => p_system_item_rec.product
               ,  p_family          => p_system_item_rec.family
               )
      THEN
         x_return_msg := 'Error: Combination of business line/product/family is invalid for System';
         RAISE e_error;
      END IF;

      l_consumable_item_rec         := p_consumable_item_rec;
      l_system_item_rec             := p_system_item_rec;

      l_consumable_item_rec.concatenated_string
                                    := p_consumable_item_rec.product||'.'
                                     ||p_consumable_item_rec.family||'.'
                                     ||p_consumable_item_rec.business_line||'.'
                                     ||p_consumable_item_rec.inventory_item_id||'.'
                                     ||p_consumable_item_rec.inventory_org_id;
      l_system_item_rec.concatenated_string
                                    := p_system_item_rec.product||'.'
                                     ||p_system_item_rec.family||'.'
                                     ||p_system_item_rec.business_line||'.'
                                     ||p_system_item_rec.inventory_item_id||'.'
                                     ||p_system_item_rec.inventory_org_id;

      write_log('l_consumable_item_rec.concatenated_string: '||l_consumable_item_rec.concatenated_string);
      write_log('l_system_item_rec.concatenated_string: '||l_system_item_rec.concatenated_string);

      p_consumable_item_rec         := l_consumable_item_rec;
      p_system_item_rec             := l_system_item_rec;

      write_log('END VALIDATE_SYSTEM_CONSUMABLE');
   EXCEPTION
      WHEN e_error THEN
         write_log('In e_errror '||x_return_msg);
         x_return_status   := 'E';
      WHEN OTHERS THEN
         x_return_status   := 'E';
         x_return_msg      := 'Error in validate_system_consumable: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
         write_log('In others '||x_return_msg);
   END validate_system_consumable;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Master procedure for checking for locking on XXOERESELLORDREL.fmb form.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE lock_system_consumable (
      p_record_type              IN    VARCHAR2
   ,  p_system_item_rec          IN    xxcn_system_items%ROWTYPE
   ,  p_consumable_item_rec      IN    xxcn_consumable_items%ROWTYPE
   ,  p_system_to_consumable_rec IN    xxcn_system_to_consumable%ROWTYPE
   ,  x_return_status            OUT   VARCHAR2
   ,  x_return_msg               OUT   VARCHAR2
   )
   IS
      CURSOR c_system
      IS
         SELECT
            business_line
         ,  product
         ,  family
         ,  inventory_item_id
         ,  start_date
         ,  end_date
         FROM xxcn_system_items
         WHERE system_id = p_system_item_rec.system_id
         FOR UPDATE OF product NOWAIT;

      CURSOR c_consumable
      IS
         SELECT
            xci.business_line
         ,  xci.product
         ,  xci.family
         ,  xci.inventory_item_id
         ,  xsc.start_date
         ,  xsc.end_date
         ,  xsc.comm_calc_on_rel_sys_flag
         FROM
            xxcn_consumable_items         xci
         ,  xxcn_system_to_consumable     xsc
         WHERE xsc.system_id     = p_system_to_consumable_rec.system_id
         AND   xsc.consumable_id = p_system_to_consumable_rec.consumable_id
         AND   xsc.consumable_id = xci.consumable_id
         FOR UPDATE OF product NOWAIT;

         l_system             c_system%ROWTYPE;
         l_consumable         c_consumable%ROWTYPE;
         l_msg                VARCHAR2(1000);
         e_error              EXCEPTION;
   BEGIN
      write_log('START LOCK_SYSTEM_CONSUMABLE');
      write_log('p_record_type: '||p_record_type);
      write_log('p_system_item_rec.system_id: '||p_system_item_rec.system_id);
      write_log('p_consumable_item_rec.consumable_id: '||p_consumable_item_rec.consumable_id);
      write_log('p_system_to_consumable_rec.system_id: '||p_system_to_consumable_rec.system_id);
      write_log('p_system_to_consumable_rec.consumable_id: '||p_system_to_consumable_rec.consumable_id);

      IF p_record_type = 'SYSTEM' THEN
         OPEN c_system;
         FETCH c_system INTO l_system;
         IF c_system%NOTFOUND THEN
               CLOSE c_system;
               x_return_msg   := 'Record Deleted';
               RAISE e_error;
         END IF;
         CLOSE c_system;

         IF    NVL(l_system.business_line,'X') <> NVL(p_system_item_rec.business_line,'X')
            OR NVL(l_system.product,'X') <> NVL(p_system_item_rec.product,'X')
            OR NVL(l_system.family,'X') <> NVL(p_system_item_rec.family,'X')
            OR NVL(l_system.inventory_item_id,-9) <> NVL(p_system_item_rec.inventory_item_id,-9)
            OR NVL(l_system.start_date,'01-JAN-1900') <> NVL(p_system_item_rec.start_date,'01-JAN-1900')
            OR NVL(l_system.end_date,'01-JAN-1900') <> NVL(p_system_item_rec.end_date,'01-JAN-1900')
         THEN
            x_return_msg   := 'Record Has Been Changed.  Please requery record.';
            RAISE e_error;
         END IF;
      END IF;

      IF p_record_type = 'CONSUMABLE' THEN
         OPEN c_consumable;
         FETCH c_consumable INTO l_consumable;
         IF c_consumable%NOTFOUND THEN
               CLOSE c_consumable;
               x_return_msg   := 'Record Deleted';
               RAISE e_error;
         END IF;
         CLOSE c_consumable;

         write_log('l_consumable.start_date: '||l_consumable.start_date||'p_system_to_consumable_rec.start_date : '||p_system_to_consumable_rec.start_date);
         write_log('l_consumable.end_date: '||l_consumable.end_date||'p_system_to_consumable_rec.end_date : '||p_system_to_consumable_rec.end_date);
         write_log('p_consumable_item_rec.product :'||p_consumable_item_rec.product);
         write_log('p_consumable_item_rec.family :'||p_consumable_item_rec.family);
         write_log('p_consumable_item_rec.business_line :'||p_consumable_item_rec.business_line);
         write_log('p_consumable_item_rec.inventory_item_id :'||p_consumable_item_rec.inventory_item_id);
         write_log('p_system_to_consumable_rec.comm_calc_on_rel_sys_flag :'||p_system_to_consumable_rec.comm_calc_on_rel_sys_flag);

         IF    NVL(l_consumable.business_line,'X') <> NVL(p_consumable_item_rec.business_line,'X')
            OR NVL(l_consumable.product,'X') <> NVL(p_consumable_item_rec.product,'X')
            OR NVL(l_consumable.family,'X') <> NVL(p_consumable_item_rec.family,'X')
            OR NVL(l_consumable.inventory_item_id,-9) <> NVL(p_consumable_item_rec.inventory_item_id,-9)
            OR NVL(l_consumable.start_date,'01-JAN-1900') <> NVL(p_system_to_consumable_rec.start_date,'01-JAN-1900')
            OR NVL(l_consumable.end_date,'01-JAN-1900') <> NVL(p_system_to_consumable_rec.end_date,'01-JAN-1900')
            OR NVL(l_consumable.comm_calc_on_rel_sys_flag,'N') <> NVL(p_system_to_consumable_rec.comm_calc_on_rel_sys_flag,'N')
         THEN
            x_return_msg   := 'Record Has Been Changed.  Please requery record.';
            RAISE e_error;
         END IF;
      END IF;

      x_return_status := 'S';
      write_log('END LOCK_SYSTEM_CONSUMABLE');
   EXCEPTION
      WHEN e_error THEN
         write_log(x_return_msg);
         x_return_status   := 'E';
      WHEN OTHERS THEN
         x_return_msg      := 'Unexpected error in lock_system: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
         write_log(x_return_msg);
         x_return_status   := 'E';
   END lock_system_consumable;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Master procedure for updating xxcn_system_items, xxcn_consumable_items, and/or
--          xxcn_system_to_consumable.  xxcn_system_items to xxcn_consumable_items is a many to
--          many relationship stored in xxcn_system_to_consumable which used effective dating
--          functionality, so updates can be quite complex.
--
-- Notes:   This is designed to be used by the XXOERESELLORDREL.fmb form, but could be used from
--          an outside calling program as well.
--
--          p_record_type should be equal to either 'CONSUMABLE' or 'SYSTEM'
--
--          p_update_all_linked_recs allows you to update records for one unique record in
--          xxcn_system_to_consumable if set to 'N'.  If set to 'Y', it allows you update
--          all recs for a paticular system_id, if p_record_type = 'SYSTEM' or a paticular
--          consumable_id, if p_record_type = 'CONSUMABLE'
--
--          See comments for large IF block to see how updates are handled.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE update_system_consumable (
      p_record_type              IN       VARCHAR2
   ,  p_update_all_linked_recs   IN       VARCHAR2
   ,  p_consumable_item_rec      IN OUT   xxcn_consumable_items%ROWTYPE
   ,  p_system_item_rec          IN OUT   xxcn_system_items%ROWTYPE
   ,  p_system_to_consumable_rec IN       xxcn_system_to_consumable%ROWTYPE
   ,  x_return_status            OUT      VARCHAR2
   ,  x_return_msg               OUT      VARCHAR2
   )
   IS
      l_consumable_id               xxcn_consumable_items.consumable_id%TYPE;
      l_system_id                   xxcn_system_items.system_id%TYPE;

      l_record_id                   xxcn_system_items.system_id%TYPE;
      l_curr_record_id1             xxcn_system_items.system_id%TYPE;
      l_curr_record_id2             xxcn_system_items.system_id%TYPE;

      l_consumable_item_rec         xxcn_consumable_items%ROWTYPE;
      l_system_item_rec             xxcn_system_items%ROWTYPE;
      e_error                       EXCEPTION;
      e_skip                        EXCEPTION;
   BEGIN
      write_log('START UPDATE_SYSTEM_TO_CONSUMABLE');
      write_log('p_record_type: '||p_record_type);
      write_log('p_update_all_linked_recs: '||p_update_all_linked_recs);

      l_consumable_item_rec   := p_consumable_item_rec;
      l_system_item_rec       := p_system_item_rec;

      validate_system_consumable(
         p_consumable_item_rec   => l_consumable_item_rec
      ,  p_system_item_rec       => l_system_item_rec
      ,  x_return_status         => x_return_status
      ,  x_return_msg            => x_return_msg
      );

      IF x_return_status <> 'S' THEN
         RAISE e_error;
      END IF;

      -- Handle system exclusions
      IF p_record_type = 'SYSTEM'
         AND l_system_item_rec.exclude_flag = 'Y'
      THEN
         updt_system_or_consumable_tbl(
            p_record_type              => 'SYSTEM'
         ,  p_consumable_item_rec      => NULL
         ,  p_system_item_rec          => l_system_item_rec
         ,  x_return_status            => x_return_status
         ,  x_return_msg               => x_return_msg
         );

         IF x_return_status <> 'S' THEN
            RAISE e_error;
         ELSE
            p_system_item_rec       := l_system_item_rec;
            -- No error, need to skip processing below this in this procedure
            RAISE e_skip;
         END IF;
      END IF;

      -- Look to see if record already exists that we are trying to update to
      does_rec_exist(
         p_rec_type              => p_record_type
      ,  p_consumable_item_rec   => l_consumable_item_rec
      ,  p_system_item_rec       => l_system_item_rec
      ,  x_record_id             => l_record_id
      ,  x_return_status         => x_return_status
      ,  x_return_msg            => x_return_msg
      );

      -- l_curr_record_ids flip-flop depending on what the p_record_type value is
      IF p_record_type = 'SYSTEM' THEN
         l_curr_record_id1  := l_system_item_rec.system_id;

         -- If p_update_all_linked_recs = 'Y' l_curr_record_id2 will be NULL, which will
         -- result in all records with a system_id = l_curr_record_id1 on xxcn_system_to_consumable
         -- being updated to the new system_id (l_record_id)
         IF p_update_all_linked_recs = 'N' THEN
            l_curr_record_id2  := l_consumable_item_rec.consumable_id;
         END IF;
      ELSIF p_record_type = 'CONSUMABLE' THEN
         l_curr_record_id1  := l_consumable_item_rec.consumable_id;

         -- If p_update_all_linked_recs = 'Y' l_curr_record_id2 will be NULL, which will
         -- result in all records with a consumable_id = l_curr_record_id1 on xxcn_system_to_consumable
         -- being updated to the new consumable_id (l_record_id)
         IF p_update_all_linked_recs = 'N' THEN
            l_curr_record_id2  := l_system_item_rec.system_id;
         END IF;
      ELSE
         x_return_msg   := 'Error: Invalid value for p_record_type '||p_record_type;
         RAISE e_error;
      END IF;

      write_log('l_record_id: '||l_record_id );
      write_log('l_'||p_record_type||'_id: '||l_curr_record_id1);
      write_log('l_curr_record_id2: '||l_curr_record_id2);

      IF p_record_type = 'SYSTEM' THEN
         chg_date_on_linked_consumables(
            p_system_to_consumable_rec => p_system_to_consumable_rec
         ,  p_existing_record_id       => l_record_id
         ,  p_system_rec               => l_system_item_rec
         ,  x_return_status            => x_return_status
         ,  x_return_msg               => x_return_msg
         );
      END IF;

      IF x_return_status <> 'S' THEN
         RAISE e_error;
      END IF;

      -- Explanation of the following large IF block:
      --    IF (l_record_id IS NOT NULL) there is an existing record that matches the record we are updating to on
      --       xxcn_consumable_items or xxcn_system_items. set l_record_id to the table's id and...
      --       1) update xxcn_system_to_consumable to l_record_id where l_curr_record_id1 AND l_curr_record_id2.
      --          This is the unique combination of system_id/consumable_id on the m:m xxcn_system_to_consumable table.
      --          Only 1 record gets updated here.
      --       2) If we are updating a consumable to a consumable that already exists in xxcn_consumable_items and
      --          no more records for that paticular consumable exist in xxcn_system_to_consumable, we
      --          can delete the record we are updating from, since it is no longer linked to any systems.  Consumables
      --          do NOT need to exist, if they are not linked to a system.  A system, however, can exist without a
      --          consumable, so we do not DELETE the system.
      --    ELSE there is not an existing record (see comments by ELSE)...
      --    END IF
         -- System or consumable record already exists
         IF l_record_id IS NOT NULL THEN
            -- Update the xxcn_system_to_consumable_records from l_curr_record_id1
            -- to l_record_id for the unique combination of l_curr_record_id1/l_curr_record2
            -- (system_id/consumable_id or visa versa depending on p_record_type)
            updt_system_to_consumable_tbl(
               p_record_type              => p_record_type
            ,  p_system_to_consumable_rec => p_system_to_consumable_rec
            ,  p_system_rec               => p_system_item_rec
            ,  p_new_record_id            => l_record_id
            ,  p_old_record_id1           => l_curr_record_id1
            ,  p_old_record_id2           => l_curr_record_id2
            ,  x_return_status            => x_return_status
            ,  x_return_msg               => x_return_msg
            );

            IF x_return_status <> 'S' THEN
               RAISE e_error;
            END IF;

            -- Need to set consumable_id to new value for when it returns value to form
            l_consumable_item_rec.consumable_id := l_record_id;

            IF p_record_type = 'CONSUMABLE'
               AND get_count_linked_recs(l_curr_record_id1,p_record_type) = 0
            THEN
               -- If there are no more consumables for this paticular record_id in
               -- xxcn_system_to_consumable, we can delete the record in xxcn_consumable_items
               -- since it is an orphaned record.
               del_consumable_tbl(
               -- p_consumable_item_rec will still have the consumable_id for the record which
               -- needs to be deleted
                  p_consumable_item_rec   => p_consumable_item_rec
               ,  x_return_status         => x_return_status
               ,  x_return_msg            => x_return_msg
               );

               IF x_return_status <> 'S' THEN
                   RAISE e_error;
               END IF;
            END IF;
         ELSE -- ELSE FOR IF l_record_id IS NOT NULL
            -- If system or consumable record does not yet exist
            -- If there are more linked records besides for the l_curr_record_id1
            -- in xxcn_system_consumable we can not simply update the existing
            -- xxcn_system_items or xxcn_consumable_items table otherwise we will
            -- essentially effect all linked records, when we only intended to affect
            -- one record.  In this case we need to insert a new record to either
            -- table then update the relationship to the new record's id on
            -- xxcn_system_to_customer
            IF get_count_linked_recs(l_curr_record_id1,p_record_type) > 1
            THEN

               ins_system_or_consumable_tbl(
                  p_record_type              => p_record_type
               ,  p_consumable_item_rec      => l_consumable_item_rec
               ,  p_system_item_rec          => l_system_item_rec
               ,  x_return_status            => x_return_status
               ,  x_return_msg               => x_return_msg
               );

               IF x_return_status <> 'S' THEN
                  RAISE e_error;
               END IF;
            -- If there are no other linked records in xxcn_system_to_consumable for this patiular xxcn_system_items
            -- or xxcn_consumable_items table, then we update the xxcn_system_items or xxcn_consumable_items table
            ELSE

               updt_system_or_consumable_tbl(
                  p_record_type              => p_record_type
               ,  p_consumable_item_rec      => l_consumable_item_rec
               ,  p_system_item_rec          => l_system_item_rec
               ,  x_return_status            => x_return_status
               ,  x_return_msg               => x_return_msg
               );

               IF x_return_status <> 'S' THEN
                  RAISE e_error;
               END IF;
            END IF;

            IF p_record_type = 'SYSTEM' THEN
               l_record_id := l_system_item_rec.system_id;
            ELSIF p_record_type = 'CONSUMABLE' THEN
               l_record_id := l_consumable_item_rec.consumable_id;
            END IF;

            write_log('Updating xxcn_sytem_to_consumables '||l_record_id);

            updt_system_to_consumable_tbl(
               p_record_type              => p_record_type
            ,  p_system_to_consumable_rec => p_system_to_consumable_rec
            ,  p_system_rec               => p_system_item_rec
            ,  p_new_record_id            => l_record_id
            ,  p_old_record_id1           => l_curr_record_id1
            ,  p_old_record_id2           => l_curr_record_id2
            ,  x_return_status            => x_return_status
            ,  x_return_msg               => x_return_msg
            );

            IF x_return_status <> 'S' THEN
               RAISE e_error;
            END IF;
         END IF; -- END IF FOR IF l_record_id IS NOT NULL
      --END IF; -- END IF FOR IF p_update_all_linked recs

      IF p_record_type = 'SYSTEM' THEN
         l_system_item_rec.system_id := l_record_id;
      END IF;

      p_consumable_item_rec         := l_consumable_item_rec;
      p_system_item_rec             := l_system_item_rec;

      write_log('END UPDATE_SYSTEM_TO_CONSUMABLE');
   EXCEPTION
      WHEN e_skip THEN
         -- This is not an error.  Used to skip processing at a certain point
         write_log('No Error: In e_skip '||x_return_msg);
         x_return_status   := 'S';
      WHEN e_error THEN
         xxobjt_utl_debug_pkg.log_err(NULL,'In e_errror '||x_return_msg);
         x_return_status   := 'E';
      WHEN OTHERS THEN
         x_return_status   := 'E';
         x_return_msg      := 'Error in update_system_consumable: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
         write_log('In others '||x_return_msg);
   END update_system_consumable;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Main calling program for inserting systems (xxcn_system_items), consumables
--          (xxcn_consumable_items), and the Many-to-Many relationship of system to consumables
--          (xxcn_system_to_consumable)
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE insert_system_consumable (
      p_record_type              IN       VARCHAR2
   ,  p_consumable_item_rec      IN OUT   xxcn_consumable_items%ROWTYPE
   ,  p_system_item_rec          IN OUT   xxcn_system_items%ROWTYPE
   ,  p_system_to_consumable_rec IN       xxcn_system_to_consumable%ROWTYPE
   ,  x_return_status            OUT      VARCHAR2
   ,  x_return_msg               OUT      VARCHAR2
   )
   IS
      l_consumable_id               xxcn_consumable_items.consumable_id%TYPE;
      l_consumable_concat_segments  VARCHAR2(500);
      l_system_id                   xxcn_system_items.system_id%TYPE;
      l_system_concat_segments      VARCHAR2(500);


      l_record_id                   xxcn_system_items.system_id%TYPE;

      l_consumable_item_rec         xxcn_consumable_items%ROWTYPE;
      l_system_item_rec             xxcn_system_items%ROWTYPE;
      l_system_to_consumable_rec    xxcn_system_to_consumable%ROWTYPE;
      e_error                       EXCEPTION;
      e_skip                        EXCEPTION;
   BEGIN
      write_log('START INSERT_SYSTEM_CONSUMABLE');

      l_consumable_item_rec         := p_consumable_item_rec;
      l_system_item_rec             := p_system_item_rec;

      validate_system_consumable(
         p_consumable_item_rec   => l_consumable_item_rec
      ,  p_system_item_rec       => l_system_item_rec
      ,  x_return_status         => x_return_status
      ,  x_return_msg            => x_return_msg
      );

      IF x_return_status <> 'S' THEN
         RAISE e_error;
      END IF;

      -- Handle system exclusions
      IF p_record_type = 'SYSTEM'
         AND l_system_item_rec.exclude_flag = 'Y'
      THEN
         ins_system_or_consumable_tbl(
            p_record_type              => p_record_type
         ,  p_consumable_item_rec      => l_consumable_item_rec
         ,  p_system_item_rec          => l_system_item_rec
         ,  x_return_status            => x_return_status
         ,  x_return_msg               => x_return_msg
         );

         IF x_return_status <> 'S' THEN
            RAISE e_error;
         ELSE
            p_system_item_rec       := l_system_item_rec;
            -- No error, need to skip processing below this in this procedure
            RAISE e_skip;
         END IF;
      END IF;

      -- Check for existing record.  In the case of consumable, the consumable record may already exist
      -- and be tied to a different system.  If so, we want to get the consumable_id and
      -- create a new record in xxcn_system_to_consumable, however, we do NOT want to create
      -- a new record in xxcn_consumable_items.  If it doesn't exist, we create the new record
      -- in xxcn_consumable_items and xxcn_system_to_consumable
      does_rec_exist(
         p_rec_type              => p_record_type
      ,  p_consumable_item_rec   => l_consumable_item_rec
      ,  p_system_item_rec       => l_system_item_rec
      ,  x_record_id             => l_record_id
      ,  x_return_status         => x_return_status
      ,  x_return_msg            => x_return_msg
      );

      write_log('x_return_status from does_consumable_exist: '||x_return_status);
      write_log('l_record_id: '||l_record_id);

      IF x_return_status <> 'S' THEN
         RAISE e_error;
      END IF;

      write_log('p_record_type: '||p_record_type);
      write_log('l_record_id: '||l_record_id);
      write_log('l_consumable_item_rec.concatenated_string: '||l_consumable_item_rec.concatenated_string);

      -- If system record without a consumable already exists, throw error
      IF p_record_type = 'SYSTEM'
         -- System already exists
         AND l_record_id IS NOT NULL
         -- No consumable record
         AND l_consumable_item_rec.concatenated_string = '....'
      THEN
         x_return_msg := 'ERROR: Duplicate system record';
         RAISE e_error;
      END IF;

      -- New system record
      IF l_record_id IS NULL THEN
         ins_system_or_consumable_tbl(
            p_record_type              => p_record_type
         ,  p_consumable_item_rec      => l_consumable_item_rec
         ,  p_system_item_rec          => l_system_item_rec
         ,  x_return_status            => x_return_status
         ,  x_return_msg               => x_return_msg
         );

         IF x_return_status <> 'S' THEN
            RAISE e_error;
         END IF;
      ELSE
         -- If record exists, then populate ids for code below here
         IF p_record_type = 'SYSTEM' THEN
            l_system_item_rec.system_id         := l_record_id;
         ELSIF p_record_type = 'CONSUMABLE' THEN
            l_consumable_item_rec.consumable_id := l_record_id;
         END IF;
      END IF;

      write_log('l_system_item_rec.system_id: '||l_system_item_rec.system_id);
      write_log('l_consumable_item_rec.consumable_id: '||l_consumable_item_rec.consumable_id);

      -- A system record can be created without a conumable record relationship, which would be the case of the IF below.
      -- However, a consumable record, must be tied to a system record.  As long as consumable_id is populated, we are
      -- creating a record in xxcn_system_to_consumable.
      IF l_consumable_item_rec.consumable_id IS NOT NULL THEN
         write_log('Inserting into xxcn_system_to_consumable for consumable_id '||l_consumable_item_rec.consumable_id
                                         ||' and system_id '||p_system_item_rec.system_id);

         l_system_to_consumable_rec                := p_system_to_consumable_rec;
         l_system_to_consumable_rec.consumable_id  := l_consumable_item_rec.consumable_id;

         INSERT INTO xxcn_system_to_consumable
         VALUES l_system_to_consumable_rec;
      END IF;

      p_consumable_item_rec   := l_consumable_item_rec;
      p_system_item_rec       := l_system_item_rec;
      x_return_status         := 'S';
      write_log('END INSERT_SYSTEM_CONSUMABLE');
   EXCEPTION
      WHEN e_skip THEN
         -- This is not an error.  Used to skip processing at a certain point
         write_log('No Error: In e_skip '||x_return_msg);
         x_return_status   := 'S';
      WHEN e_error THEN
         write_log('In e_errror '||x_return_msg);
         x_return_status   := 'E';
      WHEN OTHERS THEN
         x_return_status   := 'E';
         x_return_msg      := 'Error in insert_system: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
         write_log('In others '||x_return_msg);
   END insert_system_consumable;

------------------------------------------------------------------------------------------------
-- *********Code Below For Bulk loading system, consumables and relationships ******************
------------------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------------
-- Purpose: Get inventory_item_id based on item_number
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   FUNCTION get_inventory_item_id(
      p_item_number        IN  mtl_system_items_b.segment1%TYPE
   )
   RETURN NUMBER
   IS l_inventory_item_id  mtl_system_items_b.inventory_item_id%TYPE;
   BEGIN
      write_log('START GET_INVENTORY_ITEM_ID');
      write_log('p_item_number: '||p_item_number);

      SELECT inventory_item_id
      INTO l_inventory_item_id
      FROM
         mtl_system_items_b   msib
      ,  mtl_parameters       mp
      WHERE msib.organization_id = mp.master_organization_id
      AND   msib.segment1        = p_item_number;

      write_log('END GET_INVENTORY_ITEM_ID');
      RETURN l_inventory_item_id;
   EXCEPTION
      WHEN OTHERS THEN
         write_log('Error in get_inventory_item_id: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
         RETURN TO_NUMBER(NULL);
   END get_inventory_item_id;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Reports rows from bulk load
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE report_row_load(p_request_id NUMBER)
   IS
      CURSOR c_intf
      IS
         SELECT
            system_id
         ,  system_product
         ,  system_family
         ,  system_business_line
         ,  system_inventory_item
         ,  system_inventory_org
         ,  system_start_date
         ,  system_end_date
         ,  system_load_status
         ,  system_load_message
         ,  consumable_id
         ,  consumable_product
         ,  consumable_family
         ,  consumable_business_line
         ,  consumable_inventory_item
         ,  consumable_inventory_org
         ,  relationship_start_date
         ,  relationship_end_date
         ,  consumable_load_status
         ,  consumable_load_message
         ,  comm_calc_on_rel_sys_flag
         FROM xxcn_system_to_consumable_intf
         WHERE request_id = p_request_id
         ORDER BY
            system_load_status
         ,  consumable_load_status
         ,  system_product
         ,  system_family
         ,  system_business_line
         ,  system_inventory_item
         ,  consumable_product
         ,  consumable_family
         ,  consumable_business_line
         ,  consumable_inventory_item;

         l_system_success_total        NUMBER := 0;
         l_system_error_total          NUMBER := 0;
         l_consumable_success_total    NUMBER := 0;
         l_consumable_error_total      NUMBER := 0;
   BEGIN
      fnd_file.put_line(fnd_file.output,'System Load Status  Consumable Load Status  System ID  System Product  System Family  System Business Line  System Inventory Item  '
                                      ||'Consumable ID  Consumable Product  Consumable Family  Consumable Business Line  Consumable Inventory Item  '||RPAD('System Load Message',102,' ')||RPAD('Consumable Load Message',102,' '));
      fnd_file.put_line(fnd_file.output,'------------------  ----------------------  ---------  --------------  -------------  --------------------  ---------------------  '
                                      ||'-------------  ------------------  -----------------  ------------------------  -------------------------  '||RPAD('-',100,'-')||'  '||RPAD('-',100,'-'));

      FOR rec IN c_intf LOOP
         IF rec.system_load_status = 'ERROR' THEN
            l_system_error_total := l_system_error_total + 1;
         ELSIF rec.system_load_status = 'PROCESSED' THEN
            l_system_success_total := l_system_success_total + 1;
         END IF;

         IF rec.consumable_load_status = 'ERROR' THEN
            l_consumable_error_total := l_consumable_error_total + 1;
         ELSIF rec.consumable_load_status = 'PROCESSED' THEN
            l_consumable_success_total := l_consumable_success_total + 1;
         END IF;

         fnd_file.put_line(fnd_file.output,
                           RPAD(NVL(rec.system_load_status,'-'),18,' ')||'  '
                         ||RPAD(NVL(rec.consumable_load_status,'-'),22,' ')||'  '
                         ||LPAD(NVL(TO_CHAR(rec.system_id),'-'),9,' ')||'  '
                         ||RPAD(NVL(rec.system_product,'-'),14,' ')||'  '
                         ||RPAD(NVL(rec.system_family,'-'),13,' ')||'  '
                         ||RPAD(NVL(rec.system_business_line,'-'),20,' ')||'  '
                         ||RPAD(NVL(rec.system_inventory_item,'-'),21,' ')||'  '
                         ||LPAD(NVL(TO_CHAR(rec.consumable_id),'-'),13,' ')||'  '
                         ||RPAD(NVL(rec.consumable_product,'-'),18,' ')||'  '
                         ||RPAD(NVL(rec.consumable_family,'-'),17,' ')||'  '
                         ||RPAD(NVL(rec.consumable_business_line,'-'),24,' ')||'  '
                         ||RPAD(NVL(rec.consumable_inventory_item,'-'),25,' ')||'  '
                         ||RPAD(NVL(rec.system_load_message,'-'),100,' ')||'  '
                         ||RPAD(NVL(rec.consumable_load_message,'-'),100,' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output,' ');
      fnd_file.put_line(fnd_file.output,'Totals');
      fnd_file.put_line(fnd_file.output,'*******************************');
      fnd_file.put_line(fnd_file.output,'System Success    : '||l_system_success_total);
      fnd_file.put_line(fnd_file.output,'System Errors     : '||l_system_error_total);
      fnd_file.put_line(fnd_file.output,'Consumable Success: '||l_consumable_success_total);
      fnd_file.put_line(fnd_file.output,'Consumable Errors : '||l_consumable_error_total);
   END report_row_load;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Loadsxxcn_system_to_consumable_intf interface table from csv
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
      p_table_name            => 'XXCN_SYSTEM_TO_CONSUMABLE_INTF',
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
-- Purpose: Procedure created to bulk load systems (xxcn_system_items), consumables
--          (xxcn_consumable_items), and the relationship of system to consumables
--          (xxcn_system_to_consumable) from the xxcn_system_to_consumable_intf interface table.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- 1.1  09/25/2015  MMAZANET    CHG0034820.  Added functionality to load csv by calling
--                              load_interface_table.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE bulk_load_system_consumables(
    errbuff           OUT VARCHAR2,
    retcode           OUT NUMBER,
    p_load_type       IN  VARCHAR2,
    p_file_location   IN  VARCHAR2,
    p_file_name       IN  VARCHAR2
  )
  IS
    CURSOR c_system_intf
    IS
      SELECT DISTINCT
        system_product,
        system_family,
        system_business_line,
        system_inventory_item,
        system_inventory_org,
        system_start_date,
        system_end_date,
        exclude_flag
      FROM xxcn_system_to_consumable_intf
      WHERE NVL(system_load_status,'X') <> 'PROCESSED'
      ORDER BY
        system_product,
        system_family,
        system_business_line,
        system_inventory_item;

    CURSOR c_consume_intf
    IS
      SELECT
        system_product,
        system_family,
        system_business_line,
        system_inventory_item,
        system_inventory_org,
        system_start_date,
        system_end_date,
        consumable_product,
        consumable_family,
        consumable_business_line,
        consumable_inventory_item,
        consumable_inventory_org,
        relationship_start_date,
        relationship_end_date,
        comm_calc_on_rel_sys_flag
      FROM xxcn_system_to_consumable_intf
      WHERE NVL(consumable_load_status,'X') <> 'PROCESSED'
      ORDER BY
        consumable_product,
        consumable_family,
        consumable_business_line,
        consumable_inventory_item
      FOR UPDATE OF
        consumable_id,
        request_id,
        creation_date,
        created_by,
        consumable_load_status,
        consumable_load_message NOWAIT;

    l_record_type              VARCHAR2(25);
    l_consumable_item_rec      xxcn_consumable_items%ROWTYPE;
    l_system_item_rec          xxcn_system_items%ROWTYPE;
    l_system_to_consumable_rec xxcn_system_to_consumable%ROWTYPE;
    x_return_status            VARCHAR2(1);
    x_return_msg               VARCHAR2(500);
    l_status                   VARCHAR2(25);
    l_inventory_item_id        mtl_system_items_b.inventory_item_id%TYPE;
    l_file_location            VARCHAR2(500);

    e_error                    EXCEPTION;

  BEGIN
    write_log('START BULK_LOAD_SYSTEM_CONSUMABLES');

    write_log('Truncating xxcn_system_to_consumable_intf table');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxcn_system_to_consumable_intf';

    -- Get Oracle directory location
    BEGIN
      SELECT directory_path
      INTO l_file_location
      FROM dba_directories
      WHERE UPPER(directory_name) = p_file_location;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        x_return_msg := 'No directory set up for '||p_file_location;
        RAISE e_error;
    END;

    write_log('l_file_location: '||l_file_location);

    -- Load csv file into xxoe_reseller_order_rel_intf
    load_interface_table(
      p_load_type     => p_load_type,
      p_file_location => l_file_location,
      p_file_name     => p_file_name,
      x_return_status => x_return_status,
      x_return_msg    => x_return_msg
    );

    write_log('load_interface_table return status: '||x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- Attempt to create unique systems
    write_log('******* PROCESSING SYSTEMS *******');
    FOR rec IN c_system_intf LOOP
      BEGIN
        l_consumable_item_rec                  := NULL;
        l_system_item_rec                      := NULL;
        l_system_to_consumable_rec             := NULL;

        l_system_item_rec.business_line        := rec.system_business_line;
        l_system_item_rec.product              := rec.system_product;
        l_system_item_rec.family               := rec.system_family;
        l_system_item_rec.inventory_item_id    := get_inventory_item_id(rec.system_inventory_item);
        --l_system_item_rec.inventory_org        := rec.system_inventory_org;
        l_system_item_rec.start_date           := rec.system_start_date;
        l_system_item_rec.end_date             := rec.system_end_date;
        l_system_item_rec.exclude_flag         := NVL(rec.exclude_flag,'N');
        l_system_item_rec.parent_system_flag   := 'Y';

        write_log('l_system_item_rec.business_line: '||l_system_item_rec.business_line);
        write_log('l_system_item_rec.product: '||l_system_item_rec.product);
        write_log('l_system_item_rec.family: '||l_system_item_rec.family);
        write_log('l_system_item_rec.inventory_item_id: '||l_system_item_rec.inventory_item_id);
        write_log('l_system_item_rec.start_date: '||l_system_item_rec.start_date);
        write_log('l_system_item_rec.end_date: '||l_system_item_rec.end_date);

        -- Call insert_system_consumable master procedure
        insert_system_consumable (
          p_record_type              => 'SYSTEM',
          p_consumable_item_rec      => l_consumable_item_rec,
          p_system_item_rec          => l_system_item_rec,
          p_system_to_consumable_rec => l_system_to_consumable_rec,
          x_return_status            => x_return_status,
          x_return_msg               => x_return_msg
        );

        write_log('x_return_status: '||x_return_status);

        IF x_return_status = 'S' THEN
          l_status       := 'PROCESSED';
          x_return_msg   := 'System created.';
        ELSE
          l_status := 'ERROR';
        END IF;

      EXCEPTION
        WHEN OTHERS THEN
          x_return_msg := 'Error with record in loop '||DBMS_UTILITY.FORMAT_ERROR_STACK;
          write_log(x_return_msg);
      END;

      UPDATE xxcn_system_to_consumable_intf
      SET
        system_id            = l_system_item_rec.system_id,
        creation_date        = SYSDATE,
        created_by           = g_user_id,
        request_id           = g_request_id,
        system_load_status   = l_status,
        system_load_message  = x_return_msg
      WHERE NVL(system_business_line,'X')    = NVL(rec.system_business_line,'X')
      AND   NVL(system_family,'X')           = NVL(rec.system_family,'X')
      AND   NVL(system_product,'X')          = NVL(rec.system_product,'X')
      AND   NVL(system_inventory_item,'X')   = NVL(rec.system_inventory_item,'X');
    END LOOP;

    write_log('******* PROCESSING CONSUMABLES *******');
    FOR rec IN c_consume_intf LOOP
      BEGIN
        l_consumable_item_rec                  := NULL;
        l_system_item_rec                      := NULL;
        l_system_to_consumable_rec             := NULL;

        IF rec.consumable_inventory_item IS NOT NULL THEN
           l_inventory_item_id := get_inventory_item_id(rec.consumable_inventory_item);
        END IF;

        write_log('l_inventory_item_id: '||l_inventory_item_id);

        l_system_item_rec.business_line                   := rec.system_business_line;
        l_system_item_rec.product                         := rec.system_product;
        l_system_item_rec.family                          := rec.system_family;
        l_system_item_rec.inventory_item_id               := l_inventory_item_id;
        l_system_item_rec.concatenated_string             := rec.system_product||'.'
                                                           ||rec.system_family||'.'
                                                           ||rec.system_business_line||'.'
                                                           ||l_inventory_item_id||'.'
                                                           ||NULL;

        does_rec_exist(
          p_rec_type              => 'SYSTEM',
          p_consumable_item_rec   => l_consumable_item_rec,          p_system_item_rec       => l_system_item_rec,          x_record_id             => l_system_to_consumable_rec.system_id,
          x_return_status         => x_return_status,          x_return_msg            => x_return_msg
        );

        l_system_item_rec.system_id            := l_system_to_consumable_rec.system_id;

        write_log('l_system_item_rec.system_id: '||l_system_item_rec.system_id);

        l_consumable_item_rec.business_line                   := rec.consumable_business_line;
        l_consumable_item_rec.product                         := rec.consumable_product;
        l_consumable_item_rec.family                          := rec.consumable_family;
        l_consumable_item_rec.inventory_item_id               := l_inventory_item_id;
        --l_consumable_item_rec.inventory_org          := rec.consumable_inventory_org;
        l_system_to_consumable_rec.start_date                 := rec.relationship_start_date;
        l_system_to_consumable_rec.end_date                   := rec.relationship_end_date;
        l_system_to_consumable_rec.comm_calc_on_rel_sys_flag  := rec.comm_calc_on_rel_sys_flag;

        write_log('l_consumable_item_rec.business_line: '||l_consumable_item_rec.business_line);
        write_log('l_consumable_item_rec.product: '||l_consumable_item_rec.product);
        write_log('l_consumable_item_rec.family: '||l_consumable_item_rec.family);
        write_log('l_consumable_item_rec.inventory_item_id: '||l_consumable_item_rec.inventory_item_id);
        write_log('l_system_to_consumable_rec.start_date: '||l_system_to_consumable_rec.start_date);
        write_log('l_system_to_consumable_rec.end_date: '||l_system_to_consumable_rec.end_date);

        insert_system_consumable(
          p_record_type              => 'CONSUMABLE',
          p_consumable_item_rec      => l_consumable_item_rec,
          p_system_item_rec          => l_system_item_rec,
          p_system_to_consumable_rec => l_system_to_consumable_rec,
          x_return_status            => x_return_status,
          x_return_msg               => x_return_msg
        );

        write_log('x_return_status: '||x_return_status);

        IF x_return_status = 'S' THEN
          l_status       := 'PROCESSED';
          x_return_msg   := 'Consumable and Consumable to System Relationship created.';
        ELSE
          l_status := 'ERROR';
        END IF;

      EXCEPTION
        WHEN OTHERS THEN
           x_return_msg := 'Error with record in loop '||DBMS_UTILITY.FORMAT_ERROR_STACK;
           write_log(x_return_msg);
      END;

      UPDATE xxcn_system_to_consumable_intf
      SET
        consumable_id           = l_consumable_item_rec.consumable_id,
        creation_date           = SYSDATE,
        created_by              = g_user_id,
        request_id              = g_request_id,
        consumable_load_status  = l_status,
        consumable_load_message = x_return_msg
      WHERE CURRENT OF c_consume_intf;
    END LOOP;

    report_row_load(g_request_id);
    write_log('END BULK_LOAD_SYSTEM_CONSUMABLES');
  EXCEPTION
    WHEN e_error THEN
      fnd_file.put_line(fnd_file.output,x_return_msg);
      retcode := 2;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.output,'Unexpected error in bulk_load_system_consumables '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      retcode := 2;
  END bulk_load_system_consumables;

------------------------------------------------------------------------------------------------
-- ***************** Code Below For Calculating Consumable Records *****************************
------------------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------------
-- Purpose: Simple procedure to report output to concurrent program output
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0031576.
-- 1.1  03/10/2015  MMAZANET    CHG0034820.  Delete records with same customer_trx_line_id before
--                              inserting.  Only want 1 row per customer_trx_line_id
-- ---------------------------------------------------------------------------------------------
   PROCEDURE report_row_lcs(p_comm_rec l_comm_rec_type)
   IS
   BEGIN
      write_log('START REPORT_ROW_LCS');
      write_log('p_comm_rec.customer_trx_line_id: '||p_comm_rec.customer_trx_line_id);

      DELETE FROM xxcn_calc_commission_exception
      WHERE customer_trx_line_id = p_comm_rec.customer_trx_line_id;

      write_log('Deleted '||SQL%ROWCOUNT||' records');

      INSERT INTO xxcn_calc_commission_exception(
         customer_trx_line_id
      ,  consumable_id
      ,  request_id
      ,  processing_message_type
      ,  processing_message
      )
      VALUES(
         p_comm_rec.customer_trx_line_id
      ,  p_comm_rec.consumable_id
      ,  g_request_id
      ,  p_comm_rec.message_type
      ,  p_comm_rec.message
      );

      write_log('END REPORT_ROW_LCS');
   END report_row_lcs;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Updates lines to COMPLETE after they have been loaded into commissions.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- 1.1  03/15/2015  MMAZANET    CHG0034820.  Added handling for the Collection phase in Oracle's
--                              Incentive Compensation module.  After collecting records for
--                              commissions, Oracle provides a post-trigger to flag the records.
--                              This procedure is now called in the trigger to tag the records
--                              as COLLECTED.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE update_calc_comm_lines(
      x_return_status   OUT VARCHAR2,
      x_return_msg      OUT VARCHAR2,
      p_phase           IN  VARCHAR2 DEFAULT 'COMPLETE',
      p_batch_id        IN  NUMBER   DEFAULT TO_NUMBER(NULL)
   )
   IS
      CURSOR c_complete
      IS
        SELECT
          cch.cn_date,
          xcc.processing_status,
          xcc.processing_date
        FROM
          xxcn_calc_commission        xcc,
        /* cch... */
         (SELECT
            MAX(creation_date)      cn_date,
            source_trx_line_id
          FROM cn_commission_headers_all
          WHERE source_doc_type       = 'CON'
          GROUP BY source_trx_line_id)
                                      cch
        /* ...cch */
        WHERE xcc.processing_status     <> 'COMPLETE'
        AND   cch.source_trx_line_id    = xcc.customer_trx_line_id
        FOR UPDATE OF
          xcc.processing_status,
          xcc.processing_date NOWAIT;

      CURSOR c_collected
      IS
        SELECT
          cnt.notified_date,
          xcc.processing_status,
          xcc.processing_date
        FROM
          xxcn_calc_commission  xcc,
          cn_not_trx            cnt
        WHERE xcc.processing_status     = 'PENDING'
        AND   xcc.customer_trx_line_id  = cnt.source_trx_line_id
        AND   cnt.collected_flag        = 'Y'
        AND   cnt.batch_id              = p_batch_id
        FOR UPDATE OF
          xcc.processing_status,
          xcc.processing_date NOWAIT;
   BEGIN
      write_log('START UPDATE_CALC_COMM_LINES');

      IF p_phase = 'COMPLETE' THEN
        FOR rec IN c_complete LOOP
          UPDATE xxcn_calc_commission
          SET
            processing_status = 'COMPLETE'
          , processing_date   = rec.cn_date
          WHERE CURRENT OF c_complete;
        END LOOP;
      -- Called from collection phase in Incentive Comp module
      ELSIF p_phase = 'COLLECTED' THEN
        FOR rec IN c_collected LOOP
          UPDATE xxcn_calc_commission
          SET
            processing_status = 'COLLECTED'
          , processing_date   = rec.notified_date
          WHERE CURRENT OF c_collected;
        END LOOP;
      END IF;

      x_return_status := 'S';
      write_log('END UPDATE_CALC_COMM_LINES');
   EXCEPTION
      WHEN OTHERS THEN
         x_return_status   := 'E';
         x_return_msg      := 'update_calc_comm_lines '||SQLERRM;
         write_log(x_return_msg);
         fnd_file.put_line(fnd_file.output,x_return_msg);
   END update_calc_comm_lines;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This functionality was previously in link_consumables_to_systems.  Since we now need
--          to call this twice, I've broken it out into it's own PROCEDURE.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  03/12/2015  MMAZANET    Initial Creation for CHG0034820.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE calc_insert_calc_comm_lines(
      p_report_only           IN VARCHAR2,
      p_comm_rec              IN l_comm_rec_type,
      p_sys_rec               IN l_system_rec_type,
      x_calc_commission_id    OUT xxcn_calc_commission.calc_commission_id%TYPE,
      x_return_status         OUT VARCHAR2,
      x_return_msg            OUT VARCHAR2
   )
   IS
      l_calc_commission_id          xxcn_calc_commission.calc_commission_id%TYPE;
      l_trx_pct                     NUMBER      := 0;
      l_commission_trx_amount       NUMBER      := 0;
      l_line_amt_calc               xxcn_calc_commission.line_amount_calc%TYPE;
      l_status                      VARCHAR2(30);
   BEGIN
      write_log('START CALC_INSERT_CALC_COMM_LINES');

      write_log('Calculation for l_trx_pct = '||p_sys_rec.revenue_pct||' / '||p_sys_rec.total_revenue_pct);
      write_log('Calculation for commission_trx_amount = '||p_comm_rec.trx_amount||' * '||l_trx_pct);

      l_trx_pct               := p_sys_rec.revenue_pct/p_sys_rec.total_revenue_pct;
      l_commission_trx_amount := p_comm_rec.trx_amount * l_trx_pct;
      l_line_amt_calc         := 'revenue_pct = '||p_sys_rec.revenue_pct||' total_revenue_pct = '||p_sys_rec.total_revenue_pct||' trx_amount = '||p_comm_rec.trx_amount
                               ||' Calculation = ('||p_sys_rec.revenue_pct||' / '||p_sys_rec.total_revenue_pct||') * '||p_comm_rec.trx_amount;

      IF p_report_only = 'N' THEN
         SELECT xxcn_calc_commission_s.NEXTVAL
         INTO l_calc_commission_id
         FROM DUAL;

         IF p_sys_rec.comm_exclude_flag = 'Y' THEN
            l_status := 'NO_COMMISSION';
         ELSE
            l_status := 'PENDING';
         END IF;

         write_log('Before load of calc_commission_id: '||l_calc_commission_id);
         write_log('customer_trx_line_id: '||p_comm_rec.customer_trx_line_id);
         write_log('customer_trx_line_amount: '||l_trx_pct);
         write_log('customer_trx_line_amount: '||l_commission_trx_amount);
         write_log('reseller_id: '||p_sys_rec.reseller_id);
         write_log('business_line: '||p_sys_rec.business_line);
         write_log('business_product: '||p_sys_rec.product);
         write_log('business_family: '||p_sys_rec.family);
         write_log('request_id: '||g_request_id);

         INSERT INTO xxcn_calc_commission(
            calc_commission_id
         ,  customer_trx_line_id
         ,  customer_trx_line_split_pct
         ,  customer_trx_line_amount
         ,  line_amount_calc
         ,  reseller_id
         ,  employee_number
         ,  business_line
         ,  product
         ,  family
         ,  request_id
         ,  processing_status
         ,  processing_date
         ,  calc_source
         )
         VALUES(
            l_calc_commission_id
         ,  p_comm_rec.customer_trx_line_id
         ,  l_trx_pct
         ,  l_commission_trx_amount
         ,  l_line_amt_calc
         ,  p_sys_rec.reseller_id
         ,  NULL
         ,  p_sys_rec.business_line
         ,  p_sys_rec.product
         ,  p_sys_rec.family
         ,  g_request_id
         ,  l_status
         ,  SYSDATE
         ,  p_comm_rec.calc_source
         );
         write_log('Record successfully loaded with calc_commission_id: '||l_calc_commission_id);
         x_calc_commission_id := l_calc_commission_id;
      END IF;

      x_return_status := 'S';
      write_log('END CALC_INSERT_CALC_COMM_LINES');
   EXCEPTION
      WHEN OTHERS THEN
         x_return_status   := 'E';
         x_return_msg      := 'Error: calc_insert_calc_comm_lines '||SQLERRM;
         write_log(x_return_msg);
         fnd_file.put_line(fnd_file.output,x_return_msg);
   END calc_insert_calc_comm_lines;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This procedure ties a consumable AR transaction line to it's system records in
--          xxoe_reseller_order_rel.  It does this based on the following...
--
--          1) First, it matches the ship_to_site_use_id
--          2) Next it looks at the consumable Business Line/Product/Family/Item and attempts to
--             find all system(s) linked to that consumable in xxcn_system_to_consumable
--          3) If it finds a match, it then figures out how to factor the extended amount of the
--             consumable AR transaction line across the resellers it's linked to on the
--             xxoe_reseller_order_rel table.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- 1.1  03/12/2015  MMAZANET    CHG0034820. Chanced functionality to match systems to their consumables
--                              at the customer account level, rather than the customer site level.
-- 1.2  10-JAN-20   DCHATTERJEE INC0180048 - Add ORDER_DELIVERY source type while picking IB records
-- 1.3  01-OCT-20   Diptasurjya CHG0048619 - Add new section to delete any previously calculated data if IB change is detected
-- ---------------------------------------------------------------------------------------------
   PROCEDURE link_consumables_to_systems(
      errbuff                          OUT VARCHAR2
   ,  retcode                          OUT NUMBER
   ,  p_start_date                     IN  VARCHAR2
   ,  p_end_date                       IN  VARCHAR2
   ,  p_factor_delivery_confirm_date   IN  VARCHAR2   DEFAULT 'N'
   ,  p_reseller_id                    IN  NUMBER
   ,  p_trx_number                     IN  VARCHAR2
   ,  p_report_only                    IN  VARCHAR2
   ,  p_org_id                         IN  NUMBER
   ,  p_secondary_match_flag           IN  VARCHAR2
   )
   IS
      -- Gets consumables ra transaction lines
      CURSOR c_consumables
      IS
         SELECT
            xcccv.customer_trx_number                 customer_trx_number
         ,  xcccv.customer_trx_id                     customer_trx_id
         ,  xcccv.customer_trx_line_number            customer_trx_line_number
         ,  xcccv.customer_trx_line_id                customer_trx_line_id
         ,  xcccv.customer_trx_line_extended_amt      customer_trx_line_extended_amt
         ,  xcccv.customer_trx_date                   customer_trx_date
         -- CHG0034820 Added for calculation at account rather than site use level
         ,  xcccv.ship_to_customer_account_id         customer_account_id
         --,  xcccv.ship_to_site_use_id                 ship_to_site_use_id
         ,  xcccv.inventory_item_id                   inventory_item_id
         ,  xcccv.inventory_item_number               inventory_item_number
         ,  xcccv.inventory_item_description          inventory_item_description
         ,  xcccv.inventory_organization_id           inventory_organization_id
         ,  xcccv.inventory_organization              inventory_organization
         ,  xcccv.business_line                       business_line
         ,  xcccv.product                             product
         ,  xcccv.family                              family
         ,  xci.family                                mapped_family
         ,  xci.inventory_item_id                     mapped_inventory_item_id
         --,  xci.comm_calc_on_rel_sys_flag             comm_calc_on_rel_sys_flag
         ,  xcccv.consumable_id                       consumable_id
         FROM
            xxcn_consumables_comm_calc_v     xcccv
         ,  xxcn_consumable_items            xci
         WHERE xcccv.customer_trx_date BETWEEN fnd_date.canonical_to_date(p_start_date)
                                          AND fnd_date.canonical_to_date(p_end_date)
         AND   xcccv.customer_trx_org_id  = p_org_id
         AND   xcccv.consumable_id        = xci.consumable_id
         AND   xcccv.customer_trx_number  = NVL(p_trx_number,xcccv.customer_trx_number)
         AND   NOT EXISTS (SELECT null
                           FROM xxcn_calc_commission  xcc
                           WHERE xcc.customer_trx_line_id = xcccv.customer_trx_line_id);

      -- Gets systems tied to consumables from c_conumables.
      CURSOR c_systems_to_consumable(
         p_consumable_id               NUMBER
      ,  p_customer_account_id         NUMBER
      ,  p_mapped_consumable_family    VARCHAR2
      ,  p_mapped_inventory_item_id    NUMBER
      ,  p_consumable_business_line    VARCHAR2
      ,  p_consumable_product          VARCHAR2
      ,  p_consumable_family           VARCHAR2
      ,  p_consumable_trx_date         DATE
      )
      IS
         SELECT
            reseller_id
         ,  reseller_name
         -- Sum of revenue_pcts per reseller per item commissions category
         ,  sum_revenue_pct         revenue_pct
         ,  comm_calc_on_rel_sys_flag
         ,  comm_exclude_flag
         ,  product
         ,  family
         ,  business_line
         -- Sum of all revenue_pcts for ship to
         ,  SUM(sum_revenue_pct) OVER (PARTITION BY p_customer_account_id)
                                    total_revenue_pct
         FROM
         -- Inline view to sum all systems at the reseller level.  This PCT
         /* sum_system_to_consume... */
           (SELECT
               reseller_id
            ,  reseller_name
            ,  comm_calc_on_rel_sys_flag
            ,  comm_exclude_flag
            ,  business_line
            ,  product
            ,  family
            ,  SUM(revenue_pct)     sum_revenue_pct
            FROM
            -- Inline view to join system to it's related consumable in XXCN_SYSTEM_TO_CONSUMABLE
            -- and attempt to join systems ship_to_cust_account_id to the consumable's ship to
            -- customer ID (p_customer_id)
           /* system_to_consume... */
              (SELECT
                  xrorv.reseller_id                reseller_id
               ,  xrorv.reseller_name              reseller_name
               ,  xstc.comm_calc_on_rel_sys_flag   comm_calc_on_rel_sys_flag
               ,  xstc.comm_exclude_flag           comm_exclude_flag
               ,  DECODE(xstc.comm_calc_on_rel_sys_flag
                  ,  'Y',  xrorv.product
                  ,  p_consumable_product)         product
               ,  DECODE(xstc.comm_calc_on_rel_sys_flag
                  ,  'Y',  xrorv.family
                  ,  p_consumable_family)          family
               ,  DECODE(xstc.comm_calc_on_rel_sys_flag
                  ,  'Y',  xrorv.business_line
                  ,  p_consumable_business_line)   business_line
               ,  xrorv.revenue_pct                revenue_pct
               FROM
               -- Inline view to get all systems, including their system_ids
               /* xrorv... */
                 (SELECT
                     xrorv.*
                  -- This id is used in the commissions calc in xxcn_calc_commission_pkg.link_consumables_to_systems
                  ,  xxcn_calc_commission_pkg.get_system_id(
                        p_business_line      => xrorv.business_line
                     ,  p_product            => xrorv.product
                     ,  p_family             => xrorv.family
                     ,  p_inventory_item_id  => xrorv.inventory_item_id
                     ,  p_inventory_org_id   => TO_NUMBER(NULL)
                     )                     system_id
                  FROM
                     xxoe_reseller_order_rel_v  xrorv
                  WHERE xrorv.order_line_type_category   IN ('XXCN_SYS_ORDER_STANDARD','MANUAL_SHIP_ACCOUNT','ORDER_DELIVERY')  -- INC0180048  add ORDER_DELIVERY
                  AND   NVL(xrorv.invoice_date,'01-JAN-1900')
                                                         <= DECODE(p_factor_delivery_confirm_date
                                                            ,  'Y',  p_consumable_trx_date
                                                            ,  '31-DEC-4712')
                  )
                                             xrorv
               /* ...xrorv */
               ,  xxcn_system_to_consumable  xstc
               ,  xxcn_system_items          xsi
               WHERE xrorv.reseller_id                = NVL(p_reseller_id,xrorv.reseller_id)
               AND   SYSDATE                          BETWEEN NVL(xrorv.start_date,'01-JAN-1900')
                                                         AND NVL(xrorv.end_date,'31-DEC-4712')
               AND   xrorv.system_id                  = xstc.system_id
               AND   SYSDATE                          BETWEEN NVL(xstc.start_date,'01-JAN-1900')
                                                      AND NVL(xstc.end_date,'31-DEC-4712')
               AND   xrorv.org_id                     = p_org_id
               AND   xstc.system_id                   = xsi.system_id
               AND   xstc.consumable_id               = p_consumable_id
               -- CHG0034820 Added for calculation at account rather than site use level
               AND   xrorv.ship_to_cust_account_id    = p_customer_account_id
               --AND   xrorv.ship_to_site_use_id        = p_ship_to_site_use_id
               AND   xrorv.order_line_type_category   IN ('XXCN_SYS_ORDER_STANDARD','MANUAL_SHIP_ACCOUNT','ORDER_DELIVERY')  -- INC0180048  add ORDER_DELIVERY
               -- If no mapping occurs at the family level in our mapping tables xxcn_system_items and xxcn_consumable_items,
               -- we are essentially mapping at the product level at the lowest level.  However, the requirements dictate that
               -- we still want to attempt a match on family, in this case, even though we have not defined it. The statment
               -- below will only be meaningful if the family value is NULL on both the xxcn_system_items and xxcn_consumable_items
               -- for the consumable_id and system_id in xxcn_system_to_consumable.  Then we try to match family to family from
               -- xxoe_reseller_order_rel_v to xxcn_consumables_comm_calc_v.  If family is populated on xxcn_system_items and
               -- xxcn_consumable_items, that join will be taken care of with the xstc.consumable_id = p_consumable_id join.
               AND   CASE
                        WHEN p_mapped_consumable_family IS NULL
                        AND  p_mapped_inventory_item_id IS NULL
                        AND  xsi.family IS NULL
                     THEN xrorv.family
                     ELSE p_consumable_family
                     END                              = p_consumable_family)
                                          system_to_consume
            /* ...system_to_consume */
            GROUP BY
               reseller_id
            ,  reseller_name
            ,  comm_calc_on_rel_sys_flag
            ,  comm_exclude_flag
            ,  business_line
            ,  product
            ,  family);
         /* ...sum_system_to_consume */

         -- Essentially doing the same thing as above, but at a detail level where we can see all
         -- rows from xxoe_reseller_order_rel_v used in calculation of rows on xxcn_calc_commission
         CURSOR c_audit(
            p_calc_commission_id          xxcn_calc_commission.calc_commission_id%TYPE
         ,  p_consumable_id               NUMBER
         -- CHG0034820 Added for calculation at account rather than site use level
         ,  p_customer_account_id         NUMBER
         --,  p_ship_to_site_use_id         NUMBER
         ,  p_mapped_consumable_family    VARCHAR2
         ,  p_mapped_inventory_item_id    NUMBER
         ,  p_consumable_business_line    VARCHAR2
         ,  p_consumable_product          VARCHAR2
         ,  p_consumable_family           VARCHAR2
         ,  p_consumable_trx_date         DATE
         )
         IS
            SELECT
               p_calc_commission_id             calc_commission_id
            ,  xrorv.reseller_order_rel_id      reseller_order_rel_id
            ,  xrorv.customer_id                customer_id
            --,  xrorv.ship_to_site_use_id        ship_to_site_use_id
            ,  xrorv.ship_to_cust_account_id    ship_to_cust_account_id
            ,  xrorv.reseller_id                reseller_id
            ,  xrorv.revenue_pct                revenue_pct
            ,  xrorv.system_id                  system_id
            ,  xsi.business_line                system_business_line
            ,  xsi.product                      system_product
            ,  xsi.family                       system_family
            ,  xsi.inventory_item_id            system_inventory_item_id
            ,  xci.consumable_id                consumable_id
            ,  xci.business_line                consumable_business_line
            ,  xci.product                      consumable_product
            ,  xci.family                       consumable_family
            ,  xci.inventory_item_id            consumable_inventory_item_id
            ,  xstc.comm_calc_on_rel_sys_flag   comm_calc_on_rel_sys_flag
            ,  TO_NUMBER(NULL)                  party_site_id
            FROM
            /* xrorv... */
              (SELECT
                  xrorv.*
               -- This id is used in the commissions calc in xxcn_calc_commission_pkg.link_consumables_to_systems
               ,  xxcn_calc_commission_pkg.get_system_id(
                     p_business_line      => xrorv.business_line
                  ,  p_product            => xrorv.product
                  ,  p_family             => xrorv.family
                  ,  p_inventory_item_id  => xrorv.inventory_item_id
                  ,  p_inventory_org_id   => TO_NUMBER(NULL)
                  )                     system_id
               FROM
                  xxoe_reseller_order_rel_v  xrorv
               WHERE xrorv.order_line_type_category   IN ('XXCN_SYS_ORDER_STANDARD','MANUAL_SHIP_ACCOUNT','ORDER_DELIVERY')  -- INC0180048  add ORDER_DELIVERY
               AND   NVL(xrorv.invoice_date,'01-JAN-1900')
                                                      <= DECODE(p_factor_delivery_confirm_date
                                                         ,  'Y',  p_consumable_trx_date
                                                         ,  '31-DEC-4712')
              )
                                          xrorv
            /* ...xrorv */
            ,  xxcn_system_to_consumable  xstc
            ,  xxcn_system_items          xsi
            ,  xxcn_consumable_items      xci
            WHERE SYSDATE                          BETWEEN NVL(xrorv.start_date,'01-JAN-1900')
                                                      AND NVL(xrorv.end_date,'31-DEC-4712')
            AND   xrorv.org_id                     = p_org_id
            AND   xrorv.system_id                  = xstc.system_id
            AND   SYSDATE                          BETWEEN NVL(xstc.start_date,'01-JAN-1900')
                                                      AND NVL(xstc.end_date,'31-DEC-4712')
            AND   xstc.system_id                   = xsi.system_id
            AND   xstc.consumable_id               = p_consumable_id
            AND   xci.consumable_id                = p_consumable_id
            -- CHG0034820 Added for calculation at account rather than site use level
            AND   xrorv.ship_to_cust_account_id    = p_customer_account_id
            AND   xrorv.order_line_type_category   IN ('XXCN_SYS_ORDER_STANDARD','MANUAL_SHIP_ACCOUNT','ORDER_DELIVERY')  -- INC0180048  add ORDER_DELIVERY
            AND   CASE
                     WHEN p_mapped_consumable_family IS NULL
                     AND  p_mapped_inventory_item_id IS NULL
                     AND  xsi.family IS NULL
                  THEN xrorv.family
                  ELSE p_consumable_family
                  END                              = p_consumable_family;

      e_error                       EXCEPTION;
      e_skip                        EXCEPTION;

      l_error_flag                  VARCHAR2(1) := 'N';
      l_system_error_flag           VARCHAR2(1) := 'N';
      l_error_msg                   VARCHAR2(500);
      l_request_id                  NUMBER      := FND_GLOBAL.CONC_REQUEST_ID;
      l_request_id_post             NUMBER;
      l_return                      BOOLEAN;
      l_return_status               VARCHAR2(1);

      l_calc_commission_id          xxcn_calc_commission.calc_commission_id%TYPE;
      l_status                      VARCHAR2(15);

      l_business_line               xxcn_consumable_items.business_line%TYPE;
      l_product                     xxcn_consumable_items.product%TYPE;
      l_family                      xxcn_consumable_items.family%TYPE;

      l_comm_rec                    l_comm_rec_type;
      l_sys_rec                     l_system_rec_type;
      l_audit_rec                   xxcn_calc_commission_audit%ROWTYPE;
      
      l_start_date                  date := fnd_date.canonical_to_date(p_start_date);  -- CHG0048619 add
      l_end_date                    date := fnd_date.canonical_to_date(p_end_date);  -- CHG0048619 add
      
   BEGIN
      write_log('START LINK_CONSUMABLES_TO_SYSTEM');
      
      -- CHG0048619 add below delete statement
      -- This query is checking if any previously calculated transactions exists for which the AR Trx date 
      -- is between p_start_date and p_end_date
      -- It also checks if any IB records were created or updated after the lowest processing date for any existing previous
      -- calculations
      -- If both conditions are fulfilled then delete all records from XXCN_CALC_COMMISSION
      delete from xxcn_calc_commission xcc
       where exists
       (select 1
          from xxoe_reseller_order_rel xror
         where trunc(greatest(xror.creation_date, xror.last_update_date)) >=
               (select min(trunc(xcc1.processing_date))
                  from xxcn_calc_commission      xcc1,
                       ra_customer_trx_lines_all rctl,
                       ra_customer_trx_all       rct
                 where xcc1.customer_trx_line_id = rctl.customer_trx_line_id
                   and rctl.customer_trx_id = rct.customer_trx_id
                   and rct.trx_date between l_start_date and l_end_date
                   and xcc1.processing_status = 'PENDING'))
         and exists (select 1
        from xxcn_calc_commission      xcc2,
             ra_customer_trx_lines_all rctl,
             ra_customer_trx_all       rct
       where xcc2.customer_trx_line_id = rctl.customer_trx_line_id
         and rctl.customer_trx_id = rct.customer_trx_id
         and rct.trx_date between l_start_date and l_end_date
         and xcc2.processing_status = 'PENDING'
         and xcc2.calc_commission_id = xcc.calc_commission_id
      );
      
      -- Updates process_status for any lines that have gone through the commissions module
      update_calc_comm_lines(
         x_return_status   => l_error_flag
      ,  x_return_msg      => l_error_msg
      );

      IF l_error_flag <> 'S' THEN
         RAISE e_error;
      END IF;

      --report_row_header_lcs(p_report_only);

      -- Loop through consumable records.
      FOR c_rec IN c_consumables LOOP
         BEGIN
            write_log('*** Begin processing for customer_trx_line_id '||c_rec.customer_trx_line_id||' ***');
            -- initialize reporting variables
            l_comm_rec                          := NULL;
            l_comm_rec.consumable_id            := c_rec.consumable_id;
            l_comm_rec.customer_trx_line_id     := c_rec.customer_trx_line_id;
            l_comm_rec.trx_amount               := c_rec.customer_trx_line_extended_amt;
            l_comm_rec.calc_source              := 'LINK_CONSUMABLES_TO_SYSTEM';

            l_system_count                      := 0;
            l_system_error_flag                 := 'N';

            IF c_rec.consumable_id IS NULL THEN
               l_comm_rec.message_type  := 'NO_CONSUMABLE';
               l_comm_rec.message   := 'Could not find a mapping record on xxcn_consumable_items';
               RAISE e_skip;
            END IF;

            write_log('Before c_system_to_consumable CURSOR');
            write_log('c_rec.consumable_id: '||c_rec.consumable_id);
            write_log('c_rec.ship_to_site_use_id: '||c_rec.customer_account_id);
            write_log('c_rec.mapped_family: '||c_rec.mapped_family);
            write_log('c_rec.mapped_inventory_item_id: '||c_rec.mapped_inventory_item_id);
            write_log('c_rec.business_line: '||c_rec.business_line);
            write_log('c_rec.product: '||c_rec.product);
            write_log('c_rec.family: '||c_rec.family);
            write_log('c_rec.customer_trx_date: '||c_rec.customer_trx_date);

            -- Loop through system records looking for a match to the consumable record sent in
            FOR s_rec IN c_systems_to_consumable(
               c_rec.consumable_id
            ,  c_rec.customer_account_id
            --,  c_rec.ship_to_site_use_id
            ,  c_rec.mapped_family
            ,  c_rec.mapped_inventory_item_id
            ,  c_rec.business_line
            ,  c_rec.product
            ,  c_rec.family
            ,  c_rec.customer_trx_date
            )
            LOOP
               BEGIN
                  write_log('   *** Begin processing for system reseller_id '||s_rec.reseller_id||' ***');
                  -- initialize
                  l_sys_rec                           := NULL;
                  l_return_status                     := NULL;

                  l_system_count                      := l_system_count + 1;
                  --l_comm_rec.reseller  := s_rec.reseller_name;
                  l_sys_rec.revenue_pct               := s_rec.revenue_pct;
                  l_sys_rec.total_revenue_pct         := s_rec.total_revenue_pct;
                  l_sys_rec.comm_exclude_flag         := s_rec.comm_exclude_flag;
                  l_sys_rec.reseller_id               := s_rec.reseller_id;
                  l_sys_rec.business_line             := s_rec.business_line;
                  l_sys_rec.product                   := s_rec.product;
                  l_sys_rec.family                    := s_rec.family;

                  write_log('s_rec.comm_calc_on_rel_sys_flag: '||s_rec.comm_calc_on_rel_sys_flag);

                  IF s_rec.total_revenue_pct = 0 THEN
                     l_comm_rec.message_type := 'REVENUE_0';
                     l_comm_rec.message      := 'p_sys_rec.total_revenue_pct can not be equal to 0';
                     RAISE e_skip;
                  END IF;

                  -- Insert into pre-calc commissions table
                  calc_insert_calc_comm_lines(
                     p_report_only           => p_report_only,
                     p_comm_rec              => l_comm_rec,
                     p_sys_rec               => l_sys_rec,
                     x_calc_commission_id    => l_calc_commission_id,
                     x_return_status         => l_return_status,
                     x_return_msg            => l_error_msg
                  );

                  IF l_return_status <> 'S' THEN
                     l_comm_rec.message_type    := 'SYSTEM_OTHER';
                     l_comm_rec.message         := l_error_msg;
                     RAISE e_skip;
                  END IF;

                  IF p_report_only = 'N' THEN
                     -- Insert into audit table
                     OPEN
                        c_audit(
                           l_calc_commission_id
                        ,  c_rec.consumable_id
                        ,  c_rec.customer_account_id
                        --,  c_rec.ship_to_site_use_id
                        ,  c_rec.mapped_family
                        ,  c_rec.mapped_inventory_item_id
                        ,  c_rec.business_line
                        ,  c_rec.product
                        ,  c_rec.family
                        ,  c_rec.customer_trx_date);
                     LOOP
                        FETCH c_audit
                        INTO l_audit_rec;
                        EXIT WHEN c_audit%NOTFOUND;

                        write_log('Inserting record to audit table for reseller_order_rel_id: '||l_audit_rec.reseller_order_rel_id);

                        INSERT INTO xxcn_calc_commission_audit
                        VALUES l_audit_rec;
                     END LOOP;
                     CLOSE c_audit;

                  END IF;

                  l_consumable_total_records := l_consumable_total_records + 1;
                  --report_row_lcs(l_comm_rec);
               EXCEPTION
                  WHEN e_skip THEN
                     l_consumable_record_errors := l_consumable_record_errors + 1;
                     report_row_lcs(l_comm_rec);
                     l_system_error_flag := 'Y';
                  WHEN OTHERS THEN
                     l_consumable_record_errors := l_consumable_record_errors + 1;
                     l_comm_rec.message_type    := 'SYSTEM_OTHER';
                     l_comm_rec.message         := 'Unexpected error in s_rec LOOP: '||SQLERRM;
                     report_row_lcs(l_comm_rec);
                     l_system_error_flag := 'Y';
               END;
               write_log('   *** End processing for system reseller_id '||s_rec.reseller_id||' ***');
            END LOOP;

            IF l_system_error_flag = 'Y' THEN
               l_error_flag := 'Y';
               RAISE e_skip;
            END IF;

            IF l_system_count = 0 THEN
               l_comm_rec.message_type := 'NO_SYSTEM';
               l_comm_rec.message      := 'No system items found for this record';
               report_row_lcs(l_comm_rec);
               RAISE e_skip;
            END IF;
         EXCEPTION
            WHEN e_skip THEN
               l_consumable_record_errors := l_consumable_record_errors + 1;
               l_error_flag               := 'Y';
            WHEN OTHERS THEN
               l_consumable_record_errors := l_consumable_record_errors + 1;
               l_comm_rec.message_type    := 'CONSUMABLE_OTHER';
               l_comm_rec.message         := 'Unexpected error in c_rec LOOP: '||SQLERRM;
               l_error_flag               := 'Y';
               report_row_lcs(l_comm_rec);
         END;
         write_log('*** End processing for customer_trx_line_id '||c_rec.customer_trx_line_id||' ***');
      END LOOP;

      IF l_error_flag = 'Y' THEN

         -- Submit request for Exception report.
         l_return := fnd_request.add_layout (
                        template_appl_name   => 'XXOBJT'
                     ,  template_code        => 'XXCN_COMM_CALC_POST_EXCEPTN1'
                     ,  template_language    => 'en'
                     ,  template_territory   => 'US'
                     ,  output_format        => 'EXCEL'
                     );

         IF NOT l_return THEN
            l_error_msg := 'Error applying template for exception report.  You can run manually by passing the request id: '||l_request_id
                         ||' as a parameter.';
            RAISE e_error;
         END IF;

         l_request_id_post := fnd_request.submit_request (
                                 application          => 'XXOBJT'
                              ,  program              => 'XXCN_COMM_CALC_POST_EXCEPTN'
                              ,  argument1            => l_request_id
                              );

         IF l_request_id_post = 0 THEN
            l_error_msg := 'Error submitting exception report.  You can run manually by passing the request id: '||l_request_id
                         ||' as a parameter.';
            RAISE e_error;
         END IF;

         fnd_file.put_line(fnd_file.output,'View Request ID '||l_request_id_post||' for exception report.');
         retcode := 1;
      END IF;

      fnd_file.put_line(fnd_file.output,' ');
      fnd_file.put_line(fnd_file.output,'Record Totals');
      fnd_file.put_line(fnd_file.output,'*************************************');
      fnd_file.put_line(fnd_file.output,'Total Records Loaded :'||l_consumable_total_records);
      fnd_file.put_line(fnd_file.output,'Total Record Errors  :'||l_consumable_record_errors);

      write_log('END LINK_CONSUMABLES_TO_SYSTEM');
   EXCEPTION
      WHEN e_error THEN
         write_log(l_error_msg);
         fnd_file.put_line(fnd_file.output,l_error_msg);
         retcode := 2;
      WHEN OTHERS THEN
         write_log('Unexpected error in link_consumables_to_systems '||SQLERRM);
         fnd_file.put_line(fnd_file.output,'Unexpected error in link_consumables_to_systems '||SQLERRM);
         retcode := 2;
   END link_consumables_to_systems;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This procedure will clear the pre-commission table and associated tables:
--                xxcn_calc_commission
--                xxcn_calc_commission_audit
--                xxcn_calc_commission_exception
--
--          This will only allow you to delete records that have not interfaced to the commissions
--          module.  These records are flagged as COMPLETE.  I
--
--          If the p_clear_exception_table_only is set to 'Y', records will only be deleted from
--          the xxcn_calc_commission_exception table.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  08/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- 1.1  03/10/2015  MMAZANET    CHG0034820.  Factor in COLLECTED records for deletes from this table
-- 1.2  06/23/2016  DCHATTERJEE CHG0038832 - Modify delete_pre_commission to consider null value of parameter
--                                  p_remove_all_pending as 'N'
-- ---------------------------------------------------------------------------------------------
   PROCEDURE delete_pre_commission(
      errbuff                       OUT VARCHAR2
   ,  retcode                       OUT NUMBER
   ,  p_request_id                  IN  NUMBER
   ,  p_clear_exception_table_only  IN  VARCHAR2 DEFAULT 'N'
   ,  p_remove_all_pending          IN  VARCHAR2 DEFAULT 'N'
   )
   IS
      l_comm_audit_ct         NUMBER := 0;
      l_comm_calc_ct          NUMBER := 0;
      l_comm_exception_ct     NUMBER := 0;
      l_error_flag            VARCHAR2(2) := 'Y';
      l_error_msg             VARCHAR2(500);

      e_error                 EXCEPTION;
   BEGIN
      write_log('START DELETE_PRE_COMMISSION ');

      -- Updates process_status for any lines that have gone through the commissions module
      update_calc_comm_lines(
         x_return_status   => l_error_flag
      ,  x_return_msg      => l_error_msg
      );

      IF l_error_flag <> 'S' THEN
         RAISE e_error;
      END IF;

      IF p_clear_exception_table_only = 'N' THEN
         DELETE
         FROM xxcn_calc_commission_audit  xcca
         WHERE EXISTS  (SELECT null
                        FROM xxcn_calc_commission  xcc
                        WHERE xcc.processing_status   NOT IN  ('COMPLETE','COLLECTED')
                        AND   xcc.calc_commission_id  = xcca.calc_commission_id
                        AND   xcc.request_id          = DECODE(nvl(p_remove_all_pending,'N')  -- CHG0038832 - Dipta
                                                        ,   'N', p_request_id
                                                        ,   xcc.request_id));

         l_comm_audit_ct   := SQL%ROWCOUNT;
         write_log('Deleted records from xxcn_calc_commission_audit: '||l_comm_audit_ct);

         DELETE
         FROM xxcn_calc_commission
         WHERE processing_status NOT IN  ('COMPLETE','COLLECTED')
         AND   request_id        = DECODE(nvl(p_remove_all_pending,'N')                       -- CHG0038832 - Dipta
                                   ,   'N', p_request_id
                                   ,   request_id);

         l_comm_calc_ct   := SQL%ROWCOUNT;
         write_log('Deleted records from xxcn_calc_commission: '||l_comm_calc_ct);
      END IF;

      DELETE
      FROM xxcn_calc_commission_exception
      WHERE request_id  = DECODE(nvl(p_remove_all_pending,'N')                                -- CHG0038832 - Dipta
                          ,   'N', p_request_id
                          ,   request_id);

      l_comm_exception_ct  := SQL%ROWCOUNT;
      write_log('Deleted records from xxcn_calc_commission_exception: '||l_comm_exception_ct);

      fnd_file.put_line(fnd_file.output,' ');
      fnd_file.put_line(fnd_file.output,'Record Totals');
      fnd_file.put_line(fnd_file.output,'**********************************************');
      fnd_file.put_line(fnd_file.output,'Total Pre-Calc Audit Records Deleted :'||l_comm_audit_ct);
      fnd_file.put_line(fnd_file.output,'Total Pre-Calc Records Deleted       :'||l_comm_calc_ct);
      fnd_file.put_line(fnd_file.output,'Total Pre-Calc Exceptions Deleted    :'||l_comm_exception_ct);

      write_log('END DELETE_PRE_COMMISSION');
   EXCEPTION
       WHEN e_error THEN
         write_log('Unexpected error in delete_pre_commission '||SQLERRM);
         fnd_file.put_line(fnd_file.output,'Unexpected error in delete_pre_commission '||SQLERRM);
         retcode := 2;
      WHEN OTHERS THEN
         write_log('delete_pre_commission '||SQLERRM);
         fnd_file.put_line(fnd_file.output,'delete_pre_commission '||SQLERRM);
         retcode := 2;
   END delete_pre_commission;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0048261
  --          This function will fetch appropriate expense account based on Input payment transaction ID
  --
  --          This procedure will be called from the procedure process_oic_invoices and from XX OIC
  --          collected transaction report
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                                Description
  -- 1.0  16-JUL-2020  Diptasurjya Chatterjee              Initial Build
  -- 1.1  04-AUG-2020  Diptasurjya Chatterjee              CHG0047808 - Change expense Dept for LATAM resellers
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_expense_account (p_payment_transaction_id number,
                                  p_trx_type varchar2 default null) RETURN varchar2 IS
    l_expense_cc varchar2(500);
    l_trx_type   varchar2(30);
    l_is_latam   varchar2(1);
  BEGIN
    if p_trx_type is null then
      select cpta.trx_type
        into l_trx_type
        from cn_payment_transactions_all cpta
       where cpta.payment_transaction_id = p_payment_transaction_id;
    else
      l_trx_type := p_trx_type;
    end if;

    -- CHG0047808 start - fetch if reseller is LATAM
    begin
      select nvl(jrre.attribute6,'N')
        into l_is_latam
        from cn_payment_transactions_all cpta,
             jtf_rs_resource_extns jrre,
             JTF_RS_SALESREPS jrs
       where p_payment_transaction_id = cpta.payment_transaction_id
         and cpta.payee_salesrep_id = jrs.salesrep_id
         and jrs.resource_id = jrre.resource_id;
    exception when others then
      l_is_latam := 'N';
    end;
    -- CHG0047808 end


    -- 1. NLI Deal expense account generation
    -- Begin fetching AR revenue account for New Logo Indirect deals
    -- First check for Rev account from XLA if not found then return AR Distribution Rev account
    if l_trx_type = 'NLI' then
      begin
        select (select gck.concatenated_segments from gl_code_combinations_kfv gck
          where gck.code_combination_id = nvl((select l.code_combination_id
                      from xla_distribution_links       d,
                           xla_ae_lines                 l,
                           gl_ledgers                   gl

                     where d.application_id = 222
                       AND d.source_distribution_type = 'RA_CUST_TRX_LINE_GL_DIST_ALL'
                       AND d.ae_header_id = l.ae_header_id
                       AND d.ae_line_num = l.ae_line_num
                       AND gl.ledger_id = l.ledger_id
                       AND gl.ledger_category_code = 'PRIMARY'
                       and d.source_distribution_id_num_1 = rctld.cust_trx_line_gl_dist_id
                       and rownum=1),rctld.code_combination_id))
          into l_expense_cc
          from cn_payment_transactions_all  cpta,
               cn_commission_headers_all    ch,
               ra_cust_trx_line_gl_dist_all rctld
         where p_payment_transaction_id = cpta.payment_transaction_id
           and cpta.commission_header_id = ch.commission_header_id
           and ch.source_trx_line_id = rctld.customer_trx_line_id
           and rctld.account_class = 'REV'
           and rctld.account_set_flag = 'N'
           AND rownum=1;
      exception when others then
        fnd_file.put_line(fnd_file.log, 'ERROR: While generating expense account for NLI. '||p_payment_transaction_id||': '||sqlerrm);
        raise;
      end;
      -- if l_expense_ccid is not null, that means we have successfully gathered expense account for NLI and so return value and end process
      if l_expense_cc is not null then
        return l_expense_cc;
      end if;
    end if;

    -- 2. Non-NLI deal expense account generation
    if l_trx_type is not null then -- systems and material commissions
      begin
        select substr(glc_p.concatenated_segments,1,instr(glc_p.concatenated_segments,'.',-1))||glc_r.segment9
          into l_expense_cc
          from cn_payment_transactions_all  cpta,
               cn_quotas_all                cq,
               cn_commission_headers_all    ch,
               ra_cust_trx_line_gl_dist_all rctld,
               gl_code_combinations_kfv     glc_r,
               gl_code_combinations_kfv     glc_p
         where p_payment_transaction_id = cpta.payment_transaction_id
           and cpta.quota_id = cq.quota_id
           and cpta.commission_header_id = ch.commission_header_id
           and ch.source_trx_line_id = rctld.customer_trx_line_id
           and rctld.account_class = 'REV'
           and rctld.account_set_flag = 'N'
           and glc_r.code_combination_id = nvl((select l.code_combination_id
                                                      from xla_distribution_links       d,
                                                           xla_ae_lines                 l,
                                                           gl_ledgers                   gl
                                                      where d.application_id = 222
                                                        AND d.source_distribution_type = 'RA_CUST_TRX_LINE_GL_DIST_ALL'
                                                        AND d.ae_header_id = l.ae_header_id
                                                        AND d.ae_line_num = l.ae_line_num
                                                        AND gl.ledger_id = l.ledger_id
                                                        AND gl.ledger_category_code = 'PRIMARY'
                                                        and d.source_distribution_id_num_1 = rctld.cust_trx_line_gl_dist_id
                                                        and rownum=1),rctld.code_combination_id)
           and glc_p.code_combination_id = nvl(to_number(cq.attribute2), cpta.expense_ccid)
           AND rownum=1;
      exception when others then
        fnd_file.put_line(fnd_file.log, 'ERROR: While generating expense account based on BU for non-NLI. '||p_payment_transaction_id||': '||sqlerrm);
        raise;
      end;
    else  -- manual adjustments
      select glc_p.concatenated_segments
        into l_expense_cc
        from cn_payment_transactions_all  cpta,
             cn_quotas_all                cq,
             gl_code_combinations_kfv     glc_p
       where p_payment_transaction_id = cpta.payment_transaction_id
         and cpta.quota_id = cq.quota_id
         and glc_p.code_combination_id = nvl(to_number(cq.attribute2), cpta.expense_ccid);
    end if;

    if l_expense_cc is null then
      raise_application_error(-20111,'Expense account generation failed for Non-NLI transactions. Contact IT');
    -- CHG0047808 start - replace department segment from profile XXCN_LATAM_EXPENSE_DEPARTMENT for LATAM reseller transactions
    else
      if l_is_latam = 'Y' then
        l_expense_cc := substr(l_expense_cc,0,instr(l_expense_cc,'.'))||
                        fnd_profile.VALUE('XXCN_LATAM_EXPENSE_DEPARTMENT')||
                        substr(l_expense_cc,instr(l_expense_cc,'.',1,2));
      end if;
    -- CHG0047808 end
    end if;

    return l_expense_cc;
  END fetch_expense_account;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0048261
  --          This function will fetch new Logo type from SF for input order header ID
  --
  --          This procedure will be called from OIC collection plan
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                                Description
  -- 1.0  16-JUL-2020  Diptasurjya Chatterjee              Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_new_logo_type (p_quote_number varchar2) return varchar2 is
    l_new_logo_type varchar2(200);
  BEGIN
    select opp.type2
      into l_new_logo_type
      from opportunity@source_sf2    opp,
           sbqq__quote__c@source_sf2 qo
     where p_quote_number = qo.name
       and qo.sbqq__opportunity2__c = opp.id;

    return l_new_logo_type;
  exception when others then
    return null;
  END get_new_logo_type;
END xxcn_calc_commission_pkg;
/
