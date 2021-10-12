CREATE OR REPLACE PACKAGE BODY xxqp_utils_pkg IS
  ---------------------------------------------------------------------------
  -- $Header: http://sv-glo-tools01p.stratasys.dmn/svn/ERP/ebs/database/apps/packages/xxqp_utils_pkg.bdy 4567 2020-04-24 16:40:30Z dchatterjee $
  ---------------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               XXQP_UTILS_PKG
  --  create by:          AVIH
  --  $Revision:          1.3
  --  creation date:      05/07/2009
  --  Purpose :           QP generic functions + price list uploading
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05/07/2009    AVIH            initial build
  --  1.1   22/06/2010    Dalit A. Raviv  procedure price_list_fnd_util
  --                                      l_effective_date gets null and then do not do the update and all program.
  --                                      i changed it instead of doing select i ask on the parameter.
  --  1.2   13.2.2011     yuval Tal       procedure price_list_fnd_util - bug fix
  --  1.3   20/06/2013    Dalit A. Raviv  procedure price_list_fnd_util
  --                                      today: when users want to update items in price lists
  --                                      they prepare an excel with data and upload it from the
  --                                      shared folder the program does the following:
  --                                      1.  Closes all active lines in price lists
  --                                      2.  Add new lines with new effective date only for items in the excel
  --                                      This functionality is incorrec   t, since it closes irrelevant price list lines.
  --                                      The program should handle (close) only lines that users want to update.
  --  1.4   18.08.2013    Vitaly          CR 870 std cost - change hard-coded organization (735 /*IPK*/ instead of 90 /*WPI*/)
  --  1.5   06/07/2014    Gary Altman     CHG0032356 - Enable to close multi price list lines using PL upload file.(PROCEDURE price_list_fnd_util)
  --  1.7   19/08/2014    Yuval tal       CHG0032089 - Adjust Price List Mass Update form and program to support CS requirements
  --                                      add handle_item,get_target_price,main_process_pl
  --                                      modify update_pl,add_price_list_lines,update_item_price
  --  1.8   15/01/2015    Michal Tzvik    CHG0034284 - Fix price list upload program
  --                                      1. Modify functions/procedures:
  --                                       - price_list_fnd_util
  --                                       - plist_line_api
  --                                      2. new functions/procedures:
  --                                       - set_line_int_status
  --  1.9    3.12.15      yuval tal       CHG0036067 Add a field of precedence when uploading a file for Price Lists
  --                                      modify procedures  plist_line_api,price_list_fnd_util
  -- 2.0     28.1.16      yuval tal       INC0056947 - performence fix in
  -- 2.1     1-APR-2016   Lingaraj        CHG0038169 - Contract P/N "Unit Of Measure"  = "YR" / "MTH".
  -- 2.2   15.11.16       yuval tal       INC0080834 - modify check_simulation_done : remove simulation check on item level
  -- 4.0   13-APR-2017    Diptasurjya     CHG0040166 - Modify pricelist update and simulation functionality to incorporate
  --                                      usage of multiple rule grouping conditions (major change)
  --                                      Add new feature to close PL lines
  --                                      Also functionality to send PL update log automatically to specified email ID has been
  --                                      incorporated
  -- 4.1   31-AUG-2017    Diptasurjya     INC0100767 - Simulation process was taking longer than expected time to complete
  --                                      Cursor c_cs_pl_items_upd updated
  -- 4.2   04-OCT-2017    Diptasurjya     INC0103525 - Fix cursor c_cs_pl_items_upd to use column product_attr_val_disp
  -- 4.3   15.01.18       Yuval Tal       INC0111887 update_price

  -- 4.4   12-MAR-2018    Diptasurjya     CHG0042537 - Create PL lines with precedence value taken from
  --                                      rule header table (set from PL mass update setup form)
  -- 5.0   29/10/2017    Roman W.                     INC0135169/CHG0044317 - Performance issue for Price List Update custom program
  -- 6.0   12-JUL-2019   Diptasurjya      CHG0045880 - Handle simulation approval WF
  -- 6.1   18-NOV-2019   Diptasurjya      INC0175350 - Handle null source code values
  -- 6.2   04-DEC-2019   Diptasurjya      INC0176748 - sim not auto approved if no PL specified on sim header
  -- 6.3   01/23/2020    Diptasurjya      CHG0047324 - PL Upload program should not consider PL rule header table.
  --                                      Because PL rule header might have been changed by user between simulation and PL update
  -----------------------------------------------------------------------
  --CHG0034284 15.01.2015 Michal Tzvik: Start
  g_batch_id NUMBER := fnd_global.conc_request_id;
  -- Interface status codes:
  c_status_new     CONSTANT VARCHAR2(15) := 'NEW';
  c_status_success CONSTANT VARCHAR2(15) := 'SUCCESS';
  c_status_error   CONSTANT VARCHAR2(15) := 'ERROR';
  --CHG0034284 15.01.2015 Michal Tzvik: end

  --CHG0045880 add below constant
  --g_doc_code       CONSTANT VARCHAR2(240) := 'PL_SIM_APPROVAL';
  --g_item_type      CONSTANT VARCHAR2(100) := 'XXWFDOC';
  --   CONSTANT VARCHAR2(100) := 'xxqp_utils_pkg.';
  --c_debug_module
  --g_request_start_date DATE;

  -- lines to update
  /*CURSOR c_cs_pl_items_upd(c_rule_id        NUMBER,
     c_list_header_id NUMBER,
     c_item_code      VARCHAR2,
     c_effective_date varchar2) IS
  SELECT msi.inventory_item_id,
         msi.segment1,
         qll.list_line_id,
         h.master_list_header_id,
         qll.operand cur_price,
         qll.start_date_active,
         qll.end_date_active
  FROM   mtl_system_items_b      msi,
         xxom_pl_upd_rule_header h,
         qp_list_lines_v         qll
  WHERE  h.pl_active = 'Y'
  AND    h.list_header_id = qll.list_header_id
  AND    qll.list_header_id = c_list_header_id
  AND    h.rule_id = c_rule_id
  AND    qll.list_line_type_code = 'PLL'
  AND    h.list_header_id = c_list_header_id
  AND    msi.organization_id = 91
  AND    qll.product_attr_value = to_char(msi.inventory_item_id)
  AND    msi.segment1 = nvl(c_item_code, msi.segment1)
  AND    qll.end_date_active is null;*/
  -- CHG0045880 remove this cursor and add new cursor
  /*CURSOR c_cs_pl_items_upd(c_rule_id        NUMBER,
                           c_list_header_id NUMBER,
                           c_item_code      VARCHAR2,
                           c_effective_date VARCHAR2) IS
    SELECT --msi.inventory_item_id,            -- INC0100767 - Removed
    --msi.segment1,                     -- INC0100767 - Removed
     qll.product_id            inventory_item_id, -- INC0100767 - Added
     qll.product_attr_val_disp segment1, -- INC0100767 - Added
     qll.list_line_id,
     h.master_list_header_id,
     qll.operand               cur_price,
     qll.start_date_active,
     qll.end_date_active
      FROM --mtl_system_items_b      msi,       -- INC0100767 - Removed
           xxom_pl_upd_rule_header h,
           qp_list_lines_v         qll
     WHERE h.pl_active = 'Y'
       AND h.list_header_id = qll.list_header_id
       AND qll.list_header_id = c_list_header_id
       AND h.rule_id = c_rule_id
       AND qll.list_line_type_code = 'PLL'
       AND h.list_header_id = c_list_header_id
          --AND    msi.organization_id = 91                                      -- INC0100767 - Removed
          --AND    qll.product_attr_value = to_char(msi.inventory_item_id)       -- INC0100767 - Removed
          --AND    msi.segment1 = nvl(c_item_code, msi.segment1)                 -- INC0100767 - Removed
       AND qll.product_attr_val_disp =
           nvl(c_item_code, qll.product_attr_val_disp) -- INC0100767 - Added - INC0103525 - Fix column name
       AND qll.end_date_active IS NULL;*/
  --AND    qll.start_date_active <= nvl(fnd_date.canonical_to_date(c_effective_date),sysdate);  -- CHG0040166 - Dipta added
  --AND    trunc(SYSDATE) BETWEEN nvl(qll.start_date_active, SYSDATE - 1) AND
  --       nvl(qll.end_date_active, SYSDATE + 1);

  -- CHG0045880 add new cursor below to improve performance and fix bug where
  --            items not present in master PL were being updated
  CURSOR c_cs_pl_items_upd(c_rule_id        NUMBER,
                           c_item_code      VARCHAR2) IS
  SELECT msib.inventory_item_id,
       msib.segment1,
       QPLL.list_line_id,
       xph.master_list_header_id,
       QPLL.operand cur_price,
       QPLL.start_date_active,
       QPLL.end_date_active,
       xph.product_precedence  -- CHG0047324 add
  FROM QP_LIST_LINES           QPLL,
       QP_PRICING_ATTRIBUTES   QPPR,
       xxom_pl_upd_rule_header xph,
       mtl_system_items_b      msib
 WHERE QPPR.LIST_LINE_ID = QPLL.LIST_LINE_ID
   AND QPLL.LIST_LINE_TYPE_CODE = 'PLL'
   AND QPPR.PRICING_PHASE_ID = 1
   AND QPPR.QUALIFICATION_IND in (4, 6, 20, 22)
   AND QPLL.PRICING_PHASE_ID = 1
   AND QPLL.QUALIFICATION_IND in (4, 6, 20, 22)
   AND QPPR.LIST_HEADER_ID = QPLL.LIST_HEADER_ID
   and qppR.Product_Attribute = 'PRICING_ATTRIBUTE1'
   and qppr.product_attribute_context = 'ITEM'
   and qppr.pricing_attribute_context is null
   and to_char(msib.inventory_item_id) = qppr.product_attr_value
   and xph.pl_active = 'Y'
   and xph.list_header_id = qpll.list_header_id
   and qpll.list_header_id = qppr.list_header_id
   and xph.rule_id = c_rule_id
   AND msib.segment1 = nvl(c_item_code, msib.segment1)
   and qpll.end_date_active is null
   and msib.organization_id = xxinv_utils_pkg.get_master_organization_id
   and exists  -- to check if item from PL is present and active in master PL
       (select 1
          from QP_PRICING_ATTRIBUTES qpa,
               qp_list_lines qll
         where qll.list_header_id = xph.master_list_header_id
           and qpa.product_attribute_context = 'ITEM'
           and qpa.product_attribute = 'PRICING_ATTRIBUTE1'
           and qpa.pricing_attribute_context is null
           and qpa.product_attr_value = to_char(msib.inventory_item_id)
           and qll.list_line_id = qpa.list_line_id
           and qll.list_line_type_code = 'PLL'
           and sysdate between nvl(qll.start_date_active,sysdate-1) and nvl(qll.end_date_active,sysdate+1));

  CURSOR c_mrkt_pl_items(c_rule_id               NUMBER,
                         c_list_header_id        NUMBER,
                         c_master_list_header_id NUMBER,
                         c_item_code             VARCHAR2) IS
    SELECT qll.operand,
           qll.list_line_id,
           mtl.inventory_item_id,
           qll.list_header_id,
           l.rule_value,
           mtl.segment1,
           l.category_code,
           l.product_type
      FROM qp_list_lines_v         qll,
           mtl_system_items_b      mtl,
           mtl_cross_references_v  cr,
           xxom_pl_upd_rule_lines  l,
           xxom_pl_upd_rule_header h
     WHERE h.pl_active = 'Y'
       AND h.rule_id = c_rule_id
       AND h.rule_id = l.rule_id
       AND h.list_header_id = qll.list_header_id
       AND l.product_type = cr.cross_reference --cr.description
       AND l.category_code = cr.description --cr.cross_reference
       AND cr.cross_reference_type = 'Marketing Item Type'
       AND cr.inventory_item_id = mtl.inventory_item_id
       AND qll.list_header_id = c_list_header_id
       AND mtl.organization_id = 91
       AND nvl(mtl.enabled_flag, 'Y') = 'Y'
       AND mtl.segment1 = nvl(c_item_code, mtl.segment1)
       AND nvl(mtl.attribute24, 'Y') = 'Y'
       AND qll.product_attr_value = to_char(mtl.inventory_item_id)
       AND mtl.inventory_item_status_code IN
           ('XX_PROD', 'XX_BETA', 'Active', 'XX_PHASOUT')
       AND trunc(SYSDATE) BETWEEN nvl(qll.start_date_active, SYSDATE - 1) AND
           nvl(qll.end_date_active, SYSDATE + 1)
       AND EXISTS -- exists in master pl
     (SELECT 1
              FROM qp_list_lines_v m
             WHERE m.list_header_id = c_master_list_header_id
               AND m.product_attr_value = qll.product_attr_value
               AND SYSDATE BETWEEN nvl(m.start_date_active, SYSDATE - 1) AND
                   nvl(m.end_date_active, SYSDATE + 1));

  -------------------------------------------------
  -- get_target_price
  -------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/08/2014    Yuval tal       CHG0032089 : according to rule get target price which is
  --                                      base price for manipulation
  --                                      out params: target price
  --
  -------------------------------------------------

  FUNCTION get_target_price(p_rule_id NUMBER, p_inventory_item_id NUMBER)
    RETURN NUMBER IS

    CURSOR c_rule IS
      SELECT *
        FROM xxom_pl_upd_rule_header h
       WHERE h.rule_id = p_rule_id
         AND h.pl_active = 'Y';

    CURSOR c_master_pl IS
      SELECT qll.operand cur_price
        FROM xxom_pl_upd_rule_header h, qp_list_lines_v qll
       WHERE h.pl_active = 'Y'
         AND h.rule_id = p_rule_id
         AND qll.product_attr_value = to_char(p_inventory_item_id)
         AND h.master_list_header_id = qll.list_header_id
         AND trunc(SYSDATE) BETWEEN nvl(qll.start_date_active, SYSDATE - 1) AND
             nvl(qll.end_date_active, SYSDATE + 1);
    l_traget_price NUMBER;
  BEGIN

    FOR i IN c_rule LOOP

      CASE i.change_method
        WHEN 'MASTER' THEN
          OPEN c_master_pl;
          FETCH c_master_pl
            INTO l_traget_price;
          CLOSE c_master_pl;
        WHEN 'COST' THEN
          l_traget_price := round(xxinv_utils_pkg.get_item_cost(p_inventory_item_id => p_inventory_item_id,
                                                                p_organization_id   => 735));
        ELSE
          NULL;

      END CASE;

    END LOOP;

    RETURN l_traget_price;
  END;

  -------------------------------------------------
  -- get_master_prim_uom
  -------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05/24/2017    Diptasurjya     CHG0040166 : get the primary_uom_flag in
  --                      Chatterjee      master price list for a given rule ID
  --                                      and active price line
  --  1.1   01/23/2020    Diptasurjya     CHG0047324 - master PL ID will be passed as parameter
  --                                      Do not derive from Rule Header as rule header might have changed
  --                                      between simulation and upload
  -------------------------------------------------

  FUNCTION get_master_prim_uom(--p_rule_id           NUMBER,  -- CHG0047324 comment
                               p_master_list_header_id NUMBER,  -- CHG0047324 add
                               p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    l_master_prim_uom VARCHAR2(1);
  BEGIN

    SELECT qll.primary_uom_flag
      INTO l_master_prim_uom
      FROM /*xxom_pl_upd_rule_header h, */qp_list_lines_v qll  -- CHG0047324 comment xxom_pl_upd_rule_header
     WHERE /*h.pl_active = 'Y'
       AND h.rule_id = p_rule_id
       AND*/ qll.product_attr_value = to_char(p_inventory_item_id)  -- CHG0047324 commented joins for xxom_pl_upd_rule_header
       --AND h.master_list_header_id = qll.list_header_id  -- CHG0047324 comment
       AND p_master_list_header_id = qll.list_header_id   -- CHG0047324 add
       AND trunc(SYSDATE) BETWEEN nvl(qll.start_date_active, SYSDATE - 1) AND
           nvl(qll.end_date_active, SYSDATE + 1);

    RETURN l_master_prim_uom;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_master_prim_uom;

  -------------------------------------------------
  -- get_master_uom
  -------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05/24/2017    Diptasurjya     CHG0040166 : get the primary_uom in
  --                      Chatterjee      master price list for a given rule ID
  --                                      and active price line
  --  1.1   01/23/2020    Diptasurjya     CHG0047324 - master PL ID will be passed as parameter
  --                                      Do not derive from Rule Header as rule header might have changed
  --                                      between simulation and upload
  -------------------------------------------------

  FUNCTION get_master_uom(--p_rule_id           NUMBER,  -- CHG0047324 comment
                          p_master_list_header_id NUMBER,  -- CHG0047324 add
                          p_inventory_item_id NUMBER)
    RETURN VARCHAR2 IS
    l_master_uom VARCHAR2(3);
  BEGIN

    SELECT qll.product_uom_code
      INTO l_master_uom
      FROM /*xxom_pl_upd_rule_header h, */qp_list_lines_v qll  -- CHG0047324 comment xxom_pl_upd_rule_header
     WHERE /*h.pl_active = 'Y'
       AND h.rule_id = p_rule_id
       AND */qll.product_attr_value = to_char(p_inventory_item_id)   -- CHG0047324 commented joins for xxom_pl_upd_rule_header
       --AND h.master_list_header_id = qll.list_header_id  -- CHG0047324 comment
       AND p_master_list_header_id = qll.list_header_id   -- CHG0047324 add
       AND trunc(SYSDATE) BETWEEN nvl(qll.start_date_active, SYSDATE - 1) AND
           nvl(qll.end_date_active, SYSDATE + 1);

    RETURN l_master_uom;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_master_uom;

  -------------------------------------------------
  -- is_item_valid
  --------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/08/2014    Yuval tal       CHG0032089 : get condition sql and value for item
  --                                      execute code and return valid/invalid for manipulation
  --                                      see setup in valueset XXOM_PL_UPD_CATEGORY
  --                                      out params:
  --                                      x_out_is_valid : 1- valid  0 - not valid
  -------------------------------------------------
  PROCEDURE is_item_valid(p_err_code          OUT NUMBER,
                          p_err_message       OUT VARCHAR2,
                          x_out_is_valid      OUT NUMBER,
                          p_condition_sql     VARCHAR2,
                          p_value             VARCHAR2,
                          p_inventory_item_id NUMBER) IS
  BEGIN
    p_err_code := 0;
    IF p_condition_sql IS NULL THEN
      x_out_is_valid := 1;
      RETURN;
    END IF;
    EXECUTE IMMEDIATE p_condition_sql
      INTO x_out_is_valid
      USING p_inventory_item_id, p_value;

  EXCEPTION
    WHEN OTHERS THEN
      log('item valid error: ' || SQLERRM);
      p_err_code    := 1;
      p_err_message := 'Dynamic condition failed :' || SQLERRM;
  END;

  --------------------------------------------------------------------
  --  Name      :        handle_rounding
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     04/12/2017
  --------------------------------------------------------------------
  --  Purpose :          CHG0040166 - This procedure will be used to
  --                     handle all pricelist update rounding features
  --                     based on criteria defined on setup form
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  04/12/2017    Diptasurjya Chatterjee       Initial Build
  --------------------------------------------------------------------
  PROCEDURE handle_rounding(p_calc_price   IN NUMBER,
                            p_currency     IN VARCHAR2,
                            p_round_factor IN VARCHAR2,
                            p_round_method IN VARCHAR2,
                            x_out_price    OUT NUMBER,
                            x_err_code     OUT NUMBER,
                            x_err_msg      OUT VARCHAR2) IS
    l_digits      NUMBER := 0;
    l_final_price NUMBER := 0;

    l_round_factor NUMBER := 0;
  BEGIN
    SELECT length(trunc(p_calc_price)) INTO l_digits FROM dual;

    --log('Price length: '||l_digits);

    IF p_round_factor = -1111 THEN
      BEGIN
        SELECT ffv.attribute1
          INTO l_round_factor
          FROM fnd_flex_values_vl ffv, fnd_flex_value_sets ffvs
         WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id
           AND ffvs.flex_value_set_name = 'XXQP_ROUND_RULES'
           AND enabled_flag = 'Y'
           AND ffv.parent_flex_value_low = p_currency
           AND ffv.flex_value = l_digits;
      EXCEPTION
        WHEN no_data_found THEN
          log('no data found');
          -- x_out_price := p_calc_price;
          x_err_code := 1;
          x_err_msg  := 'ERROR: Valid round factor not set for ' ||
                        l_digits || ' digit price of curreny ' ||
                        p_currency;

          RETURN;
      END;
    ELSE
      l_round_factor := p_round_factor;
    END IF;

    --log('Round Factor: '||l_round_factor);

    x_out_price := CASE p_round_method
                     WHEN 'Normal' THEN
                      l_round_factor *
                      (round(p_calc_price / l_round_factor))
                     WHEN 'Ceil' THEN
                      l_round_factor * (ceil(p_calc_price / l_round_factor))
                     WHEN 'Floor' THEN
                      l_round_factor *
                      (floor(p_calc_price / l_round_factor))
                     ELSE
                      NULL
                   END;

    --log('Final Price: '||x_out_price);

    x_err_code := 0;
    x_err_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      x_out_price := NULL;
      x_err_code  := 1;
      x_err_msg   := 'ERROR: ' || SQLERRM;
  END handle_rounding;

  -------------------------------------------
  -- handle_item
  --------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/08/2014    Yuval tal       CHG0032089 : if item is valid for modification
  --                                      calculate item price changes according to rules
  --                                      out params:
  --                                      x_out_item_valid 1- valid  0 - not valid
  --                                      x_err_code 1 -err 0 valid
  --                                      x_out_traget_price : base price for manipulation
  --                                      x_out_actual_factor : change in percent between new price and old price
  --  1.1   25/04/2017    Diptasurjya     CHG0040166 - Make changes to logic to consider condition groups as per precedence
  --                                      and use condition value derived as per lines defined for each group
  --                                      Rounding rule changes for currency type made in logic
  -------------------------------------------

  PROCEDURE handle_item(p_inventory_item_id NUMBER,
                        p_rule_id           NUMBER,
                        p_curr_price        NUMBER,
                        x_out_item_valid    OUT NUMBER,
                        x_out_actual_factor OUT NUMBER,
                        x_out_traget_price  OUT NUMBER,
                        x_out_new_price     OUT NUMBER,
                        x_err_code          OUT NUMBER,
                        x_err_msg           OUT VARCHAR2) IS

    CURSOR c_pl_rule_details(c_rule_id NUMBER) IS
      SELECT g.precedence, -- CHG0040166
             l.category_code,
             g.group_value, -- CHG0040166
             l.product_type,
             h.change_method,
             l.category_value,
             h.change_type,
             h.master_list_header_id,
             h.round_factor,
             h.round_method,
             h.min_price,
             g.group_name,
             -- xxobjt_general_utils_pkg. get_valueset_attribute('XXOM_PL_UPD_CATEGORY', category_code, 'ATTRIBUTE2') list_sql,
             xxobjt_general_utils_pkg. get_valueset_attribute('XXOM_PL_UPD_CATEGORY', category_code, 'ATTRIBUTE3') condition_sql,
             COUNT(precedence) over(PARTITION BY precedence, l.group_id) cnt, -- CHG0040166
             COUNT(precedence) over(PARTITION BY precedence, l.group_id, l.category_code) cnt1
        FROM xxom_pl_upd_rule_lines  l,
             xxom_pl_upd_rule_header h,
             xxom_pl_upd_rule_groups g -- CHG0040166
       WHERE h.rule_id = c_rule_id
         AND h.rule_id = l.rule_id (+)  -- CHG0045880 add outer join for cases where no rule lines present
         AND h.pl_active = 'Y' -- CHG0040166
         AND g.group_id (+) = l.group_id -- CHG0040166  -- CHG0045880 add outer join for cases where no rule lines present
       ORDER BY g.precedence; -- CHG0040166

    l_item_is_valid NUMBER;
    l_note          VARCHAR2(2000);
    l_round_factor  NUMBER;
    l_round_method  VARCHAR2(50);
    l_min_price     NUMBER;
    -- CHG0040166 - Start
    l_pl_currency VARCHAR2(10);

    l_precedence_cnt NUMBER := 0;
    lx_err_code      NUMBER;
    lx_err_msg       VARCHAR2(4000);
    lx_item_is_valid NUMBER := 1;

    lx_round_err NUMBER;
    lx_round_msg VARCHAR2(4000);
    -- CHG0040166 - End
  BEGIN
    x_err_code := 0;

    x_out_traget_price := get_target_price(p_rule_id, p_inventory_item_id);
    IF x_out_traget_price IS NULL THEN
      x_err_code := 1;
      x_err_msg  := 'No Target price found';
      RETURN;
    END IF;

    -- CHG0040166 - Start
    SELECT qlh.currency_code
      INTO l_pl_currency
      FROM qp_list_headers_all qlh, xxom_pl_upd_rule_header xph
     WHERE xph.list_header_id = qlh.list_header_id
       AND xph.rule_id = p_rule_id;
    -- CHG0040166 - End

    x_out_new_price := x_out_traget_price;

    FOR i IN c_pl_rule_details(p_rule_id) LOOP

      l_precedence_cnt := l_precedence_cnt + 1; -- CHG0040166

      l_round_factor := nvl(i.round_factor, 1);
      l_round_method := nvl(i.round_method, 'Normal');
      l_min_price    := nvl(i.min_price, 0);

      --for k in 1..i.cnt1             -- CHG0040166
      --loop
      is_item_valid(lx_err_code, -- CHG0040166
                    lx_err_msg, -- CHG0040166
                    l_item_is_valid,
                    i.condition_sql,
                    i.category_value,
                    p_inventory_item_id);

      --if l_item_is_valid = 1 or lx_err_code = 1 then  -- CHG0040166
      --  exit;
      --end if;
      --end loop;                                     -- CHG0040166

      --log('Returned value: '|| i.category_value ||' '||l_item_is_valid);
      log('Item valid Error Code: ' || lx_err_code || ' ' || lx_err_msg);
      lx_err_code      := greatest(nvl(lx_err_code, 0), x_err_code); -- CHG0040166
      lx_err_msg       := lx_err_msg || x_err_msg || ','; -- CHG0040166
      lx_item_is_valid := least(nvl(lx_item_is_valid, 1), l_item_is_valid); -- CHG0040166
      log('Calculated valid: ' || lx_item_is_valid || ' ' || i.precedence);
      log('Item Valid: ' || x_err_code || ' z' || l_item_is_valid || 'z ' ||
          l_precedence_cnt || ' ' || i.cnt || ' ' || i.category_code || ' ' ||
          i.category_value);
      log('Item Status: z' || lx_err_code || 'z z' || lx_item_is_valid || 'z');

      IF lx_err_code = 1 THEN
        -- CHG0040166 - End
        x_out_item_valid    := 1;
        x_out_new_price     := NULL;
        x_out_actual_factor := NULL;
        x_err_code          := 1;
        x_err_msg           := 'ERROR: Condition: ' || i.category_code || ': ' ||
                               lx_err_msg;
        RETURN;
        --exit;
      END IF;

      -- CHG0045880 - bug fix .. if no rule lines/groups/exclusions exist item price should be same as master PL
      if i.cnt = 0 then
        x_out_item_valid := lx_item_is_valid;
      end if;
      -- CHG0045880 end bug fix

      -- CHG0040166 - Start
      IF l_precedence_cnt = i.cnt THEN
        --log('Precendence count matches');
        l_precedence_cnt := 0;

        IF lx_item_is_valid = 1 THEN
          l_note := l_note || i.group_name || ' ' || i.group_value || ','; -- CHG0040166 condition_group changed to group_name
          log('NOTE 1: ' || l_note);
          --
          CASE i.change_type
            WHEN 'Factor' THEN
              x_out_new_price := x_out_new_price * i.group_value;
            WHEN 'PCT' THEN
              x_out_new_price := x_out_new_price * i.group_value / 100;
            WHEN 'AMOUNT' THEN
              x_out_new_price := x_out_new_price + i.group_value;
            ELSE
              x_out_new_price     := NULL;
              x_err_code          := 1;
              x_out_actual_factor := NULL;
              x_err_msg           := 'Unknown change_type' || i.change_type;
          END CASE;

          --

        END IF;

        log('NOTE 2: ' || l_note);

        x_err_code := greatest(nvl(x_err_code, 0), lx_err_code);

        log('Before Final: ' || x_out_item_valid);

        x_out_item_valid := greatest(nvl(x_out_item_valid, 0),
                                     lx_item_is_valid);

        log('Final: ' || x_out_item_valid || ' ' || x_err_code);

        IF i.precedence <> 0 AND lx_item_is_valid = 1 THEN
          EXIT;
        END IF;

        lx_item_is_valid := 1;
        lx_err_code      := 0;

      END IF;

    --log('item price: '||x_out_new_price);
    END LOOP;

    x_err_msg := x_err_msg || rtrim(l_note, ',');
    log('FINAL ERR MSG: ' || x_err_msg);

    --if x_err_code = 0 and x_out_item_valid = 0 then
    --  x_out_item_valid := 1;
    --end if;

    -- CHG0040166 Start
    -- 1000*(ceil (125265.23/1000))
    /*x_out_new_price := CASE l_round_method
    WHEN 'Normal' THEN
     l_round_factor *
     (round(x_out_new_price / l_round_factor))
    WHEN 'Ceil' THEN
     l_round_factor *
     (ceil(x_out_new_price / l_round_factor))
    WHEN 'Floor' THEN
     l_round_factor *
     (floor(x_out_new_price / l_round_factor))
    ELSE
     NULL
            END;*/

    handle_rounding(x_out_new_price,
                    l_pl_currency,
                    l_round_factor,
                    l_round_method,
                    x_out_new_price,
                    lx_round_err,
                    lx_round_msg);

    -- CHG0040166 End

    IF lx_round_err = 1 THEN
      x_err_code := 1;
      x_err_msg  := x_err_msg || lx_round_msg;
    ELSE
      IF x_out_new_price > 0 THEN
        x_out_new_price := greatest(x_out_new_price, l_min_price);
      END IF;
      /* log('x_out_new_price=' || x_out_new_price || ' l_min_price=' ||
      l_min_price);*/
      IF p_curr_price != 0 THEN
        x_out_actual_factor := x_out_new_price / p_curr_price;
      ELSE
        x_out_actual_factor := 0;
      END IF;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      x_out_item_valid    := 1;
      x_out_new_price     := NULL;
      x_err_code          := 1;
      x_out_actual_factor := NULL;
      x_err_msg           := SQLERRM;
  END;

  ------------------------------------------------------------------------------------------------------------------------
  --  Name      :        handle_exclusion
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     04/12/2017
  ------------------------------------------------------------------------------------------------------------------------
  --  Purpose :          CHG0040166 - This procedure will be used to
  --                     check if the passed inventory item is valid
  --                     based on all defined exclusion conditions for the Pricelist
  ------------------------------------------------------------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  04/12/2017    Diptasurjya Chatterjee       Initial Build
  --  1.1  29/10/2017    Roman W.                     INC0135169/CHG0044317 - Performance issue for Price List Update custom program
  ------------------------------------------------------------------------------------------------------------------------
  PROCEDURE handle_exclusion(p_inventory_item_id NUMBER,
                             p_rule_id           NUMBER,
                             x_out_item_valid    OUT NUMBER,
                             x_out_actual_factor OUT NUMBER,
                             x_out_traget_price  OUT NUMBER,
                             x_out_new_price     OUT NUMBER,
                             x_excl_exists       OUT VARCHAR2,
                             x_exclude           OUT VARCHAR2,
                             x_err_code          OUT NUMBER,
                             x_err_msg           OUT VARCHAR2) IS
    -------------------------------
    --     Local Definition
    -------------------------------
    CURSOR c_pl_excl_details(c_rule_id NUMBER) IS
      SELECT e.exception_id,
             e.rule_id,
             e.condition_group,
             e.condition_value,
             e.fixed_price,
             e.exclude_flag,
             xxobjt_general_utils_pkg.get_valueset_attribute('XXOM_PL_UPD_CATEGORY',
                                                             condition_group,
                                                             'ATTRIBUTE3') condition_sql
        FROM xxom_pl_upd_rule_exception e, xxom_pl_upd_rule_header h
       WHERE h.rule_id = c_rule_id
         AND h.rule_id = e.rule_id
         AND h.pl_active = 'Y'
         AND e.condition_group != 'Item' -- Added INC0135169/CHG0044317
       ORDER BY fixed_price;

    l_item_is_valid NUMBER;
    l_note          VARCHAR2(2000);
    l_round_factor  NUMBER;
    l_round_method  VARCHAR2(50);
    l_min_price     NUMBER;

    l_exception_id    NUMBER; -- INC0135169/CHG0044317
    l_fixed_price     NUMBER; -- INC0135169/CHG0044317
    l_exclude_flag    VARCHAR2(30); -- INC0135169/CHG0044317
    l_condition_value VARCHAR2(300); -- INC0135169/CHG0044317
    -------------------------------
    --     Code Section
    -------------------------------
  BEGIN
    x_err_code       := 0;
    x_out_item_valid := 0; --INC0135169/CHG0044317;

    -- non Item group --
    FOR i IN c_pl_excl_details(p_rule_id) LOOP
      --log('In Exclusion check: '||i.condition_group||' '||i.condition_value||' '||i.condition_sql||' '||p_inventory_item_id||' '||i.condition_value);

      is_item_valid(x_err_code,
                    x_err_msg,
                    l_item_is_valid,
                    i.condition_sql,
                    i.condition_value,
                    p_inventory_item_id);

      IF x_err_code = 1 THEN
        x_out_item_valid    := 1;
        x_out_new_price     := NULL;
        x_out_actual_factor := NULL;
        x_excl_exists       := 'N';
        RETURN;
      ELSIF l_item_is_valid = 1 THEN
        l_note := l_note || i.condition_value || ' ' || ',';
        --
        --log('Exclude flag: '||i.exclude_flag||' '||p_inventory_item_id);
        x_excl_exists := 'Y';

        IF i.exclude_flag = 'Y' THEN
          x_out_item_valid    := 1;
          x_out_new_price     := NULL;
          x_out_actual_factor := NULL;
          x_exclude           := 'Y';
        ELSE
          x_out_item_valid    := 1;
          x_out_new_price     := i.fixed_price;
          x_out_actual_factor := NULL;
          x_exclude           := 'N';
        END IF;
        RETURN;
      END IF;

      x_err_msg        := x_err_msg || rtrim(l_note, ',');
      x_out_item_valid := greatest(nvl(x_out_item_valid, 0),
                                   l_item_is_valid);

    END LOOP;

    ---------------------------------------------------------------------------------------
    -- start added by Roman W. 31/10/2018 CHG0044317
    -- check item exists in exception table with no sql use
    ---------------------------------------------------------------------------------------
    BEGIN
      SELECT e.exception_id,
             e.fixed_price,
             e.exclude_flag,
             e.condition_value --,
        INTO l_exception_id,
             l_fixed_price,
             l_exclude_flag,
             l_condition_value --,
        FROM xxom_pl_upd_rule_exception e,
             xxom_pl_upd_rule_header    h,
             mtl_system_items_b         msi
       WHERE h.rule_id = p_rule_id
         AND h.rule_id = e.rule_id
         AND h.pl_active = 'Y'
         AND msi.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND msi.inventory_item_id = p_inventory_item_id
         AND msi.segment1 = e.condition_value
         AND e.condition_group = 'Item';

      IF l_exclude_flag = 'Y' THEN
        x_out_item_valid    := 1;
        x_out_new_price     := NULL;
        x_out_actual_factor := NULL;
        x_exclude           := 'Y';
        x_excl_exists       := 'Y';
      ELSE
        x_out_item_valid    := 1;
        x_out_new_price     := l_fixed_price;
        x_out_actual_factor := NULL;
        x_exclude           := 'N';
        x_excl_exists       := 'Y';
      END IF;

    EXCEPTION
      WHEN no_data_found THEN
        x_out_item_valid := 0;

      WHEN OTHERS THEN
        x_out_item_valid    := 1;
        x_out_new_price     := NULL;
        x_err_code          := 1;
        x_out_actual_factor := NULL;
        x_err_msg           := x_err_msg ||
                               ' EXCEPTION_OTHERS xxqp_utils_pkg.handle_exclusion() - ' ||
                               substr(SQLERRM, 1, 2000);

    END;
    --END IF;
    -- end added by Roman W. 31/10/2018 CHG0044317

  EXCEPTION
    WHEN OTHERS THEN
      x_out_item_valid    := 1;
      x_out_new_price     := NULL;
      x_err_code          := 1;
      x_out_actual_factor := NULL;
      x_err_msg           := substr(SQLERRM, 1, 2000);
  END handle_exclusion;
  ------------------------------------------------------------------
  -- get iten_UOM_code
  -----------------------------------------------------------------
  FUNCTION get_item_uom_code(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    l_primary_uom_code mtl_system_items_b.primary_uom_code%TYPE;
  BEGIN

    SELECT t.primary_uom_code
      INTO l_primary_uom_code
      FROM mtl_system_items_b t
     WHERE t.organization_id = 91
       AND t.inventory_item_id = p_inventory_item_id;
    RETURN l_primary_uom_code;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;

  END;

  ---------------------------------------------
  -- check_simulation_done
  -- 15.11.16 yuval tal INC0080834 - remove simulation check on item level
  ---------------------------------------------

  PROCEDURE check_simulation_done(errbuf           OUT VARCHAR2,
                                  retcode          OUT VARCHAR2,
                                  p_source         VARCHAR2,
                                  p_list_header_id NUMBER,
                                  p_item_code      VARCHAR2) IS

    CURSOR c_list_price IS
      SELECT *
        FROM xxom_pl_upd_rule_header t
       WHERE t.pl_active = 'Y'
         AND t.source_code = nvl(p_source, t.source_code)
         AND t.list_header_id = nvl(p_list_header_id, t.list_header_id);

    CURSOR c_check_simulation(c_list_header_id NUMBER,
                              c_item_code      VARCHAR2) IS
      SELECT 1
        FROM xxom_pl_upd_simulation s
       WHERE s.source_code = p_source
         AND s.list_header_id = nvl(c_list_header_id, s.list_header_id)
            --  AND s.item_code = nvl(c_item_code, s.item_code)
         AND s.creation_date > SYSDATE - 1;
    l_tmp NUMBER;
    end_check_exception EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    FOR i IN c_list_price LOOP
      l_tmp := 0;
      IF p_source IN ('CS', 'SALES') THEN
        --    FOR l IN c_cs_pl_items_upd(i.rule_id, i.list_header_id, p_item_code) LOOP -- INC0080834
        OPEN c_check_simulation(i.list_header_id, NULL /*l.segment1*/);
        FETCH c_check_simulation
          INTO l_tmp;
        CLOSE c_check_simulation;

        IF nvl(l_tmp, 0) = 0 THEN
          errbuf  := 'No simulation results found for list price:' ||
                     get_price_list_name(i.list_header_id) || /*' Item=' ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 l.segment1 ||*/
                     ' ' ||
                     ' , simulation must be done before updating price list';
          retcode := 1;
          RAISE end_check_exception;
        END IF;
        --   END LOOP; -- INC0080834

      ELSIF p_source = 'MRKT' THEN
        FOR l IN c_mrkt_pl_items(i.rule_id,
                                 i.list_header_id,
                                 i.master_list_header_id,
                                 p_item_code) LOOP
          OPEN c_check_simulation(i.list_header_id, l.segment1);
          FETCH c_check_simulation
            INTO l_tmp;
          CLOSE c_check_simulation;

          IF nvl(l_tmp, 0) = 0 THEN
            errbuf  := 'No simulation results found for list price:' ||
                       get_price_list_name(i.list_header_id) || 'Item=' ||
                       l.segment1 || ' ' ||
                       ' , simulation must be done before updating price list';
            retcode := 1;
            RAISE end_check_exception;
          END IF;
        END LOOP;
      END IF;
    END LOOP;
  EXCEPTION
    WHEN end_check_exception THEN
      NULL;

    WHEN OTHERS THEN
      errbuf  := 'Error in check_simulation_done ' || SQLERRM;
      retcode := 1;
  END;
  ---------------------------------------
  -- log
  ---------------------------------------

  PROCEDURE log(p_string VARCHAR2) IS
    pragma autonomous_transaction;
  BEGIN
    --insert into xxdctest values (p_string);
    --commit;
    fnd_file.put_line(fnd_file.log, p_string /*substr(p_string, 1, 150)*/);
    -- dbms_output.put_line(p_string);
  END;

  --------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               plist_line_api
  --  create by:          AVIH
  --  $Revision: 4567 $
  --  creation date:      05/07/2009
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05/07/2009    AVIH            initial build
  --  1.1   14/01/2015    Michal Tzvik    CHG0034248
  --                                      remove parameter p_effective_date
  --                                      Add parameters:
  --                                      - p_start_date_active
  --                                      - p_end_date_active
  --                                      - p_list_line_id
  --                                      - p_operation (enable update/create lines)
  -- 1.2    3.12.15        yuval tal      CHG0036067 Add a field of precedence when uploading a file for Price Lists
  --
  -- 1.3     1-APR-2016     Lingaraj       CHG0038169 - Contract P/N "Unit Of Measure"  = "YR" / "MTH".
  -----------------------------------------------------------------------
  PROCEDURE plist_line_api(errbuf              OUT VARCHAR2,
                           retcode             OUT VARCHAR2,
                           p_masterorganizid   IN NUMBER,
                           p_list_header_id    IN NUMBER,
                           p_inventory_item_id IN NUMBER,
                           p_primary_uom_code  IN VARCHAR2,
                           p_itemprice         IN NUMBER,
                           -- 1.1   14/01/2015    Michal Tzvik
                           -- p_effective_date    IN DATE,
                           p_start_date_active  IN DATE,
                           p_end_date_active    IN DATE,
                           p_list_line_id       IN NUMBER,
                           p_operation          IN VARCHAR2,
                           p_product_precedence IN NUMBER DEFAULT NULL,
                           p_primary_uom_flag   IN VARCHAR2 DEFAULT NULL) IS
    --Added for CHG0038169, 1-Apr-2016

    gpr_return_status  VARCHAR2(1) := NULL;
    gpr_msg_count      NUMBER := 0;
    gpr_msg_data       VARCHAR2(2000);
    gpr_price_list_rec qp_price_list_pub.price_list_rec_type;
    --gpr_price_list_val_rec      qp_price_list_pub.price_list_val_rec_type;
    gpr_price_list_line_tbl qp_price_list_pub.price_list_line_tbl_type;
    --gpr_price_list_line_val_tbl qp_price_list_pub.price_list_line_val_tbl_type;
    --gpr_qualifiers_tbl          qp_qualifier_rules_pub.qualifiers_tbl_type;
    --gpr_qualifiers_val_tbl      qp_qualifier_rules_pub.qualifiers_val_tbl_type;
    gpr_pricing_attr_tbl qp_price_list_pub.pricing_attr_tbl_type;
    --gpr_pricing_attr_val_tbl    qp_price_list_pub.pricing_attr_val_tbl_type;
    ppr_price_list_rec          qp_price_list_pub.price_list_rec_type;
    ppr_price_list_val_rec      qp_price_list_pub.price_list_val_rec_type;
    ppr_price_list_line_tbl     qp_price_list_pub.price_list_line_tbl_type;
    ppr_price_list_line_val_tbl qp_price_list_pub.price_list_line_val_tbl_type;
    ppr_qualifiers_tbl          qp_qualifier_rules_pub.qualifiers_tbl_type;
    ppr_qualifiers_val_tbl      qp_qualifier_rules_pub.qualifiers_val_tbl_type;
    ppr_pricing_attr_tbl        qp_price_list_pub.pricing_attr_tbl_type;
    ppr_pricing_attr_val_tbl    qp_price_list_pub.pricing_attr_val_tbl_type;
    k                           NUMBER := 1;
    j                           NUMBER := 1;
    --v_detail_message            VARCHAR2(2000);
    v_item_code mtl_system_items_b.segment1%TYPE;
    --v_update_status             VARCHAR2(30);
    v_pdesc           VARCHAR2(200);
    v_plist_type_code VARCHAR2(10);
    v_plist_currency  VARCHAR2(10);
    --l_error_tbl       inv_item_grp.error_tbl_type;

  BEGIN

    retcode := '0';
    errbuf  := NULL;
    -----------------------
    fnd_file.put_line(fnd_file.log, '----------------------- ');
    fnd_file.put_line(fnd_file.log,
                      'p_masterorganizid:  ' || p_masterorganizid);
    fnd_file.put_line(fnd_file.log,
                      'p_list_header_id:  ' || p_list_header_id);
    fnd_file.put_line(fnd_file.log,
                      'p_inventory_item_id:  ' || p_inventory_item_id);
    fnd_file.put_line(fnd_file.log,
                      'p_primary_uom_code:  ' || p_primary_uom_code);
    fnd_file.put_line(fnd_file.log, 'p_itemprice:  ' || p_itemprice);
    fnd_file.put_line(fnd_file.log,
                      'p_start_date_active:  ' || p_start_date_active);
    fnd_file.put_line(fnd_file.log,
                      'p_end_date_active:  ' || p_end_date_active);
    fnd_file.put_line(fnd_file.log, 'p_list_line_id:  ' || p_list_line_id);
    fnd_file.put_line(fnd_file.log, 'p_operation:  ' || p_operation);
    fnd_file.put_line(fnd_file.log, '----------------------- ');
    -----------------------
    --l_error_tbl.DELETE;

    SELECT t.description, spl.list_type_code, spl.currency_code
      INTO v_pdesc, v_plist_type_code, v_plist_currency
      FROM qp_list_headers_tl t, qp_list_headers_b spl
     WHERE t.list_header_id = spl.list_header_id
       AND spl.list_header_id = p_list_header_id
       AND t.language = userenv('LANG');

    -- QP Header Record
    gpr_price_list_rec.list_header_id := p_list_header_id;
    gpr_price_list_rec.list_type_code := v_plist_type_code;
    gpr_price_list_rec.description    := v_pdesc;
    gpr_price_list_rec.currency_code  := v_plist_currency;
    gpr_price_list_rec.operation      := qp_globals.g_opr_none;
    -- QP Line Record
    gpr_price_list_line_tbl(k).list_header_id := p_list_header_id;
    gpr_price_list_line_tbl(k).list_line_id := nvl(p_list_line_id,
                                                   fnd_api.g_miss_num); -- 1.1 Michal Tzvik 14/01/2015
    --gpr_price_list_line_tbl(k).list_line_id := fnd_api.g_miss_num;
    gpr_price_list_line_tbl(k).list_line_type_code := 'PLL';
    gpr_price_list_line_tbl(k).operation := p_operation; -- 1.1 Michal Tzvik 14/01/2015: replace qp_globals.g_opr_create;
    gpr_price_list_line_tbl(k).start_date_active := nvl(p_start_date_active,
                                                        fnd_api.g_miss_date); -- 1.1 Michal Tzvik 14/01/2015: replace p_effective_date;
    gpr_price_list_line_tbl(k).end_date_active := nvl(p_end_date_active,
                                                      fnd_api.g_miss_date); -- 1.1 Michal Tzvik 14/01/2015
    --gpr_price_list_line_tbl(K).inventory_item_id := P_inventory_item_id;
    gpr_price_list_line_tbl(k).operand := nvl(p_itemprice,
                                              fnd_api.g_miss_num); -- 1.1 Michal Tzvik 14/01/2015: add nvl
    gpr_price_list_line_tbl(k).arithmetic_operator := 'UNIT_PRICE';
    gpr_price_list_line_tbl(k).product_precedence := nvl(p_product_precedence,
                                                         220); --CHG0036067
    gpr_price_list_line_tbl(k).primary_uom_flag := p_primary_uom_flag; --Added for CHG0038169, 1-Apr-2016
    -- QP Pricing Record
    IF p_operation = qp_globals.g_opr_create THEN
      -- 1.1 Michal Tzvik 14/01/2015
      gpr_pricing_attr_tbl(j).pricing_attribute_id := fnd_api.g_miss_num;
      gpr_pricing_attr_tbl(j).list_line_id := fnd_api.g_miss_num;
      gpr_pricing_attr_tbl(j).product_attribute_context := 'ITEM';
      gpr_pricing_attr_tbl(j).product_attribute := 'PRICING_ATTRIBUTE1';
      gpr_pricing_attr_tbl(j).product_attr_value := p_inventory_item_id;
      gpr_pricing_attr_tbl(j).product_uom_code := p_primary_uom_code;
      gpr_pricing_attr_tbl(j).excluder_flag := 'N';
      gpr_pricing_attr_tbl(j).attribute_grouping_no := 1;
      gpr_pricing_attr_tbl(j).price_list_line_index := 1;
      gpr_pricing_attr_tbl(j).operation := qp_globals.g_opr_create;
    END IF;

    -- Call QP API
    qp_price_list_pub.process_price_list(p_api_version_number      => 1.0,
                                         p_init_msg_list           => fnd_api.g_true,
                                         p_return_values           => fnd_api.g_false,
                                         p_commit                  => fnd_api.g_false,
                                         x_return_status           => gpr_return_status,
                                         x_msg_count               => gpr_msg_count,
                                         x_msg_data                => gpr_msg_data,
                                         p_price_list_rec          => gpr_price_list_rec,
                                         p_price_list_line_tbl     => gpr_price_list_line_tbl,
                                         p_pricing_attr_tbl        => gpr_pricing_attr_tbl,
                                         x_price_list_rec          => ppr_price_list_rec,
                                         x_price_list_val_rec      => ppr_price_list_val_rec,
                                         x_price_list_line_tbl     => ppr_price_list_line_tbl,
                                         x_price_list_line_val_tbl => ppr_price_list_line_val_tbl,
                                         x_qualifiers_tbl          => ppr_qualifiers_tbl,
                                         x_qualifiers_val_tbl      => ppr_qualifiers_val_tbl,
                                         x_pricing_attr_tbl        => ppr_pricing_attr_tbl,
                                         x_pricing_attr_val_tbl    => ppr_pricing_attr_val_tbl);

    IF gpr_return_status <> fnd_api.g_ret_sts_success THEN
      -- get item code for viewing in log
      BEGIN
        SELECT segment1
          INTO v_item_code
          FROM mtl_system_items_b
         WHERE organization_id = p_masterorganizid
           AND inventory_item_id = p_inventory_item_id;
      EXCEPTION
        WHEN OTHERS THEN
          v_item_code := NULL;
      END;
      fnd_file.put_line(fnd_file.log, ''); ---empty line
      fnd_file.put_line(fnd_file.log,
                        '============ API ERROR --- Problem Inserting Price List For Item ''' ||
                        v_item_code || '''================');
      -- Get Message
      ---v_detail_message := ' ';
      /* for jj in 1 .. gpr_msg_count loop
         v_detail_message := ltrim(rtrim(v_detail_message))||oe_msg_pub.get( p_msg_index => jj, p_encoded => 'F');
      End loop;*/
      FOR k IN 1 .. gpr_msg_count LOOP
        gpr_msg_data := oe_msg_pub.get(p_msg_index => k, p_encoded => 'F');
        fnd_file.put_line( ---'The Error Message Due to which The Item has not been loaded to Price List '|| k ||' is: '|| gpr_msg_data);
                          fnd_file.log,
                          k || '. ' || substr(gpr_msg_data, 1, 255));
        errbuf := errbuf || ';' || substr(gpr_msg_data, 1, 255);
      END LOOP;

      --FOR i IN 1 .. l_error_tbl.COUNT LOOP
      -----l_err_msg := l_err_msg || l_error_tbl(i).message_text || chr(10);
      --     fnd_file.put_line(fnd_file.log,i||'. '||SubStr(l_error_tbl(i).message_text, 1, 255));
      --END LOOP;

      -----fnd_file.put_line(fnd_file.log, 'Problem Inserting PList For Item ' || v_item_code || ': ' || gpr_msg_data);
      -----fnd_file.put_line(fnd_file.log,'Detailed Error Message:' ||ltrim(rtrim(v_detail_message)));
      retcode := '1';
      errbuf  := 'Problem Inserting Price List For Item:' || errbuf; -- CHG0034284 Michal Tzvik 15.01.2015: concat gpr_msg_data to
    END IF;
  END plist_line_api;

  --------------------------------------------------------------------
  --  name:            set_line_int_status
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   15/01/2015
  --------------------------------------------------------------------
  --  purpose :        Update status in interface table XXQP_PRICE_LIST_LINES_INT
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    15/01/2015  Michal Tzvik     Initial Build - CHG0034248
  --------------------------------------------------------------------
  PROCEDURE set_line_int_status(p_batch_id          IN NUMBER,
                                p_interface_line_id IN NUMBER,
                                p_status            IN VARCHAR2,
                                p_err_msg           IN VARCHAR2) IS
  BEGIN
    UPDATE xxqp_price_list_lines_int xplli
       SET xplli.xx_status  = p_status,
           xplli.xx_err_msg = xplli.xx_err_msg || p_err_msg
     WHERE xplli.xx_batch_id = p_batch_id
       AND xplli.xx_interface_line_id =
           nvl(p_interface_line_id, xplli.xx_interface_line_id)
       AND xplli.xx_status != c_status_success;

  END set_line_int_status;

  --------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               price_list_fnd_util
  --  create by:          AVIH
  --  $Revision:          1.3
  --  creation date:      05/07/2009
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05/07/2009    AVIH            initial build
  --  1.1   22/06/2010    Dalit A. Raviv  l_effective_date gets null and then do not do the update and all program.
  --                                      i changed it instead of doing select i ask on the parameter.
  --  1.2   13.2.2011     yuval Tal       bug fix
  --  1.3   20/06/2013    Dalit A. Raviv  today: when users want to update items in price lists     price_list_fnd_util
  --                                      they prepare an excel with data and upload it from the
  --                                      shared folder the program does the following:
  --                                      1.  Closes all active lines in price lists
  --                                      2.  Add new lines with new effective date only for items in the excel
  --                                      This functionality is incorrect, since it closes irrelevant price list lines.
  --                                      The program should handle (close) only lines that users want to update.
  --  1.4   06/07/2014    Gary Altman     CHG0032356 - Enable to close multi price list lines using PL upload file
  --                                                     according to new parameters p_close_lines and p_end_date
  --  1.5   14/01/2015    Michal Tzvik    CHG0034284 - Fix price list upload program
  --                                      Rewrite procedure:
  --                                      1. remove parameter p_end_date, Use p_effective_date instead.
  --                                      2. Upload file by using table loader setup, so no line will be processed if file has invalid number in price
  --                                      3. Use API for closing lines instead of update statement
  --                                      4. Create output file with listed error lines.
  -- 1.6    3.12.15        yuval tal      CHG0036067 Add a field of precedence when uploading a file for Price Lists
  --                                      (need also to add setup to file loader deff to upload product_precedence XXQP_PRICE_LIST_LINES_INT/XXQP_ASCII_UPLOAD)
  -- 1.7     1-APR-2016     Lingaraj       CHG0038169 - Contract P/N "Unit Of Measure"  = "YR" / "MTH".
  -- 1.8    15.01.18        yuval tal      INC0111887 and condition qppr.pricing_attribute_context IS NULL
  -----------------------------------------------------------------------

  PROCEDURE price_list_fnd_util(errbuf            OUT VARCHAR2,
                                retcode           OUT VARCHAR2,
                                p_masterorganizid IN NUMBER,
                                p_location        IN VARCHAR2,
                                p_file_name       IN VARCHAR2,
                                p_list_header_id  IN NUMBER,
                                p_effective_date  IN VARCHAR2,
                                p_close_lines     IN VARCHAR2) IS

    l_errbuf            VARCHAR2(2000);
    l_retcode           VARCHAR2(1);
    l_error_message     VARCHAR2(2000);
    l_start_date_active DATE;
    l_end_date_active   DATE;
    l_inventory_item_id NUMBER;
    l_primary_uom_code  mtl_system_items_b.primary_uom_code%TYPE;
    l_lines_rec         qp_list_lines%ROWTYPE;
    l_cnt_s             NUMBER := 0;
    l_cnt_e             NUMBER := 0;
    v_dummy_cnt         NUMBER := 0; --Added for CHG0038169, 1-Apr-2016
    l_primary_uom_flag  VARCHAR2(1); --Added for CHG0038169, 1-Apr-2016
    stop_processing EXCEPTION;

    CURSOR c_list_lines(p_status VARCHAR2) IS
      SELECT *
        FROM xxqp_price_list_lines_int xplli
       WHERE xplli.xx_batch_id = g_batch_id
         AND xplli.xx_status = p_status;

  BEGIN
    retcode := '0';

    -- Clear interface table
    DELETE FROM xxqp_price_list_lines_int xplli
     WHERE xplli.xx_status != c_status_new
       AND xplli.creation_date <= SYSDATE - 30;

    -- 1. upload data from csv to interface table (XXQP_PRICE_LIST_LINES_INT)
    fnd_file.put_line(fnd_file.log, 'Upload data from csv...');
    xxobjt_table_loader_util_pkg.load_file(errbuf => l_errbuf,

                                           retcode => l_retcode,

                                           p_table_name => 'XXQP_PRICE_LIST_LINES_INT',

                                           p_template_name => 'XXQP_ASCII_UPLOAD',

                                           p_file_name => p_file_name,

                                           p_directory => p_location,

                                           p_expected_num_of_rows => NULL);

    IF l_retcode <> '0' THEN
      l_error_message := 'Failed to upload file: ' || l_errbuf;
      fnd_file.put_line(fnd_file.output, l_error_message);
      RAISE stop_processing;
    END IF;

    -- 2. Convert data and upload to target tables
    fnd_file.put_line(fnd_file.log, '');
    fnd_file.put_line(fnd_file.log, '');
    fnd_file.put_line(fnd_file.log, 'Process lines...');
    IF p_effective_date IS NULL THEN
      l_start_date_active := SYSDATE;
    ELSE
      l_start_date_active := to_date(p_effective_date,
                                     'YYYY/MM/DD HH24:MI:SS');
    END IF;

    FOR r_line IN c_list_lines(c_status_new) LOOP
      BEGIN
        SAVEPOINT process_line;
        BEGIN
          SELECT msi.inventory_item_id, primary_uom_code
            INTO l_inventory_item_id, l_primary_uom_code
            FROM mtl_system_items_b msi
           WHERE msi.segment1 = r_line.xx_item_number
             AND msi.organization_id = p_masterorganizid;

          --Added for CHG0038169, 1-Apr-2016
          IF r_line.base_uom_code IS NOT NULL THEN
            v_dummy_cnt := 0;
            SELECT COUNT(1)
              INTO v_dummy_cnt
              FROM mtl_units_of_measure
             WHERE uom_code = r_line.base_uom_code;
            IF v_dummy_cnt > 0 THEN
              l_primary_uom_code := r_line.base_uom_code;
            END IF;
          END IF;

        EXCEPTION
          WHEN no_data_found THEN
            l_error_message := 'Invalid item number: ' ||
                               r_line.xx_item_number;
            RAISE stop_processing;
        END;

        --Added for CHG0038169, 1-Apr-2016
        l_primary_uom_flag := NULL;
        IF r_line.primary_uom_flag IS NOT NULL THEN
          IF r_line.primary_uom_flag NOT IN ('Y', 'N') THEN
            l_error_message := 'Invalid : primary_uom_flag ' ||
                               r_line.xx_item_number;
            RAISE stop_processing;
          ELSE
            l_primary_uom_flag := CASE r_line.primary_uom_flag
                                    WHEN 'Y' THEN
                                     'Y'
                                    ELSE
                                     NULL
                                  END;

          END IF;
        END IF;

        BEGIN
          SELECT qll.*
            INTO l_lines_rec
            FROM qp_list_lines qll, qp_pricing_attributes qpa
           WHERE 1 = 1
             AND qll.list_header_id = p_list_header_id
             AND qpa.list_line_id = qll.list_line_id
             AND product_attribute_context = 'ITEM'
             AND qpa.product_attr_value = to_char(l_inventory_item_id)
             AND qpa.pricing_attribute_context IS NULL /*INC0111887*/
             AND l_start_date_active BETWEEN
                 nvl(qll.start_date_active, l_start_date_active) AND
                 nvl(qll.end_date_active, l_start_date_active);
        EXCEPTION
          WHEN no_data_found THEN
            l_lines_rec := NULL;
        END;

        IF (l_start_date_active >= l_lines_rec.start_date_active OR
           l_lines_rec.start_date_active IS NULL) THEN

          IF (l_start_date_active < l_lines_rec.end_date_active OR
             l_lines_rec.end_date_active IS NULL) THEN

            IF p_close_lines = 'N' THEN
              l_end_date_active := l_start_date_active - 1;
            ELSE
              l_end_date_active := l_start_date_active;
            END IF;

            -- Close line (update end_date_active)
            IF l_lines_rec.list_line_id IS NOT NULL THEN
              plist_line_api(l_errbuf,

                             l_retcode,

                             p_masterorganizid,

                             p_list_header_id,

                             l_inventory_item_id,

                             l_primary_uom_code,

                             NULL, -- price

                             NULL, --start_date_active

                             l_end_date_active,

                             l_lines_rec.list_line_id,

                             qp_globals.g_opr_update,
                             p_primary_uom_flag => l_primary_uom_flag);

              IF l_retcode <> '0' THEN
                l_error_message := l_errbuf;
                RAISE stop_processing;
              END IF;
            END IF;

            IF p_close_lines = 'N' THEN
              -- create new pl line
              plist_line_api(l_errbuf,

                             l_retcode,

                             p_masterorganizid,

                             p_list_header_id,

                             l_inventory_item_id,

                             l_primary_uom_code,

                             r_line.operand,

                             l_start_date_active,

                             NULL, --end_date_active

                             NULL, --list_line_id

                             qp_globals.g_opr_create,
                             r_line.product_precedence,
                             p_primary_uom_flag => l_primary_uom_flag);

              IF l_retcode <> '0' THEN
                l_error_message := l_errbuf;
                RAISE stop_processing;
              END IF;
            END IF; -- p_close_lines

          END IF;
        END IF;
        -- update interface status
        set_line_int_status(g_batch_id,
                            r_line.xx_interface_line_id,
                            c_status_success,
                            NULL);
        l_cnt_s := l_cnt_s + 1;
      EXCEPTION
        WHEN stop_processing THEN
          fnd_file.put_line(fnd_file.log, l_error_message);
          retcode := 1;
          errbuf  := 'Processing error';
          ROLLBACK TO process_line;
          l_cnt_e := l_cnt_e + 1;
          set_line_int_status(g_batch_id,
                              r_line.xx_interface_line_id,
                              c_status_error,
                              l_error_message);
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log, SQLERRM);
          retcode := 1;
          errbuf  := 'Unexpected error in line';
          ROLLBACK TO process_line;
          l_cnt_e := l_cnt_e + 1;
          set_line_int_status(g_batch_id,
                              r_line.xx_interface_line_id,
                              c_status_error,
                              SQLERRM);
      END;
    END LOOP;

    COMMIT;

    -- 3. report errors
    fnd_file.put_line(fnd_file.output,
                      l_cnt_s || ' records were successfully processed.');
    IF l_cnt_e > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_cnt_e ||
                        ' records failed. See list below for error lines details:');
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output,
                        'Item Number         | Price      | Error Message');
      fnd_file.put_line(fnd_file.output,
                        '--------------------------------------------------------------------------------');
      FOR r_line IN c_list_lines(c_status_error) LOOP
        fnd_file.put_line(fnd_file.output,
                          rpad(nvl(r_line.xx_item_number, ' '), 20, ' ') || '| ' ||
                          lpad(nvl(to_char(r_line.operand), ' '), 10, ' ') ||
                          ' | ' || r_line.xx_err_msg);

      END LOOP;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Unexpected error: ' || SQLERRM;

      set_line_int_status(g_batch_id, NULL, c_status_error, errbuf);
  END price_list_fnd_util;

  /*  PROCEDURE price_list_fnd_util(errbuf            OUT VARCHAR2,
                                    retcode           OUT VARCHAR2,
                                    p_masterorganizid IN NUMBER,
                                    p_location        IN VARCHAR2,
                                    p_file_name       IN VARCHAR2,
                                    p_list_header_id  IN NUMBER,
                                    p_effective_date  IN VARCHAR2,
                                    p_close_lines     IN VARCHAR2,
                                    p_end_date        IN VARCHAR2) IS
    v_counter          NUMBER(5) := 0;
    v_line_buf         VARCHAR2(2000);
    v_tmp_line         VARCHAR2(2000);
    v_read_code        NUMBER(5) := 1;
    plist_file         utl_file.file_type;
    v_place            NUMBER(3);
    v_delimiter        CHAR(1) := ',';
    v_item_code        mtl_system_items_b.segment1%TYPE;
    v_item_id          mtl_system_items_b.inventory_item_id%TYPE;
    v_primary_uom_code mtl_system_items_b.primary_uom_code%TYPE;
    v_itemprice        VARCHAR2(15);
    v_errbuf           VARCHAR2(500);
    v_retcode          VARCHAR2(10);
    v_update_status    VARCHAR2(30);
    l_effective_date   DATE;
    --l_err_msg          VARCHAR2(500);
    --l_err_code         number;
    --------------- Gary 1/07/2014 CHG0032356----
    l_end_date DATE;
    ---------------------------------------------

  BEGIN
    -- 1.1 22/06/2010 Dalit A. Raviv
    -- l_effective_date gets null and then do not do the update and all program.
    -- i changed it instead of doing select i ask on the parameter.
    IF p_effective_date IS NULL THEN
      l_effective_date := SYSDATE;
    ELSE
      l_effective_date := to_date(p_effective_date, 'YYYY/MM/DD HH24:MI:SS');
    END IF;

    --------------- Gary 1/07/2014 CHG0032356----
    IF p_end_date IS NULL THEN
      l_end_date := SYSDATE;
    ELSE
      l_end_date := to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS');
    END IF;
    ---------------------------------------------

    BEGIN
      SELECT '1'
      INTO   retcode
      FROM   qp_list_lines qll
      WHERE  qll.list_header_id = p_list_header_id
      AND    end_date_active = l_effective_date
      AND    rownum < 2;

      errbuf := 'Items with start effective date ' || l_effective_date ||
                ' already exists.' || chr(0);
    EXCEPTION
      WHEN OTHERS THEN
        -- 1.3 20/06/2013 Dalit A. Raviv
        \*-- first update all rows for the wanted price list with end_date_active of yesterday
        UPDATE qp_list_lines qll
           SET qll.end_date_active = l_effective_date - 1
         WHERE qll.list_header_id = p_list_header_id
           AND qll.end_date_active IS NULL; -- add by yuval 13.2.2011 bug fix

        COMMIT;*\
        -- open the file for reading
        BEGIN
          plist_file := utl_file.fopen(location => p_location, filename => p_file_name, open_mode => 'r');
          fnd_file.put_line(fnd_file.log, 'File ' || ltrim(p_file_name) ||
                             ' Is open For Reading ');
        EXCEPTION
          WHEN utl_file.invalid_path THEN
            retcode := '2';
            errbuf  := errbuf || 'Invalid Path for ' || ltrim(p_file_name) ||
                       chr(0);
          WHEN utl_file.invalid_mode THEN
            retcode := '2';
            errbuf  := errbuf || 'Invalid Mode for ' || ltrim(p_file_name) ||
                       chr(0);
          WHEN utl_file.invalid_operation THEN
            retcode := '2';
            errbuf  := errbuf || 'Invalid operation for ' ||
                       ltrim(p_file_name) || SQLERRM || chr(0);
          WHEN OTHERS THEN
            retcode := '2';
            errbuf  := errbuf || 'Other for ' || ltrim(p_file_name) ||
                       chr(0);
        END;
        -- loop for all file's lines
        WHILE v_read_code <> 0 AND nvl(retcode, 1) = 1 LOOP
          BEGIN
            utl_file.get_line(file => plist_file, buffer => v_line_buf);

          EXCEPTION
            WHEN utl_file.read_error THEN
              retcode := '2';
              errbuf  := 'Read Error' || chr(0);
            WHEN no_data_found THEN
              errbuf      := 'Read Complete' || chr(0);
              v_read_code := 0;
            WHEN OTHERS THEN
              retcode := '2';
              errbuf  := 'Other for Line Read' || SQLERRM || chr(0);
          END;
          IF v_read_code <> 0 THEN
            v_retcode := NULL;
            v_counter := v_counter + 1;
            v_place   := instr(v_line_buf, v_delimiter);
            -- Check The Delimiter
            IF nvl(v_place, 0) = 0 OR (v_place > 100) THEN
              errbuf  := 'No Delimiter In The File, Line' ||
                         to_char(v_counter) || chr(0);
              retcode := '2';
            ELSE
              v_item_code := ltrim(rtrim(substr(v_line_buf, 1, v_place - 1)));
              v_tmp_line  := ltrim(substr(v_line_buf, v_place + 1, length(v_line_buf)));

              v_place := instr(v_tmp_line, v_delimiter);
              IF v_place = 0 THEN
                v_place := length(v_tmp_line);
              END IF;
              v_itemprice := ltrim(rtrim(substr(v_tmp_line, 1, v_place - 1)));
              v_tmp_line  := ltrim(substr(v_tmp_line, v_place + 1, length(v_tmp_line)));
              --   fnd_file.put_line(fnd_file.log, 'Read Item ' || v_item_code || ' Price ' || v_itemprice);
              BEGIN
                SELECT msi.inventory_item_id,
                       primary_uom_code
                INTO   v_item_id,
                       v_primary_uom_code
                FROM   mtl_system_items_b msi
                WHERE  msi.segment1 = v_item_code
                AND    msi.organization_id = p_masterorganizid;
              EXCEPTION
                WHEN no_data_found THEN
                  v_item_id := NULL;
                  retcode   := 1;
              END;

              IF v_item_id IS NOT NULL THEN
                ------------- Gary 01/07/2014  CHG0032356 -----
                IF p_close_lines = 'Y' THEN
                  UPDATE qp_list_lines qll
                  SET    qll.end_date_active = l_end_date
                  WHERE  qll.list_line_id IN
                         (SELECT qpa.list_line_id
                          FROM   qp_pricing_attributes qpa,
                                 qp_list_lines         qll1
                          WHERE  qpa.list_header_id = p_list_header_id
                          AND    qpa.product_attr_value = to_char(v_item_id)
                          AND    qpa.list_line_id = qll1.list_line_id
                          AND    (qll1.end_date_active IS NULL OR
                                qll1.end_date_active > l_end_date));
                  COMMIT;
                ELSE
                  BEGIN
                    SELECT 'UPDATE'
                    INTO   v_update_status
                    FROM   qp_list_lines_v ql
                    WHERE  ql.list_header_id = p_list_header_id
                    AND    product_attribute_context = 'ITEM'
                    AND    l_effective_date BETWEEN ql.start_date_active AND
                           ql.end_date_active -- added by  yuval 13.2.2011 bug fix
                          --     rem by  yuval 13.2.2011 bug fix
                          -- AND nvl(ql.end_date_active, l_effective_date - 1) <  l_effective_date - 1
                    AND    product_id = v_item_id;
                  EXCEPTION
                    WHEN no_data_found THEN
                      v_update_status := 'INSERT';
                    WHEN too_many_rows THEN
                      v_update_status := 'UPDATE';
                  END;
                  IF v_update_status = 'INSERT' THEN
                    --  1.3   20/06/2013    Dalit A. Raviv
                    BEGIN
                      UPDATE qp_list_lines qll
                      SET    qll.end_date_active =
                             (l_effective_date - 1)
                      WHERE  qll.list_header_id = p_list_header_id
                      AND    qll.end_date_active IS NULL
                      AND    qll.list_line_id =
                             (SELECT qpa.list_line_id
                               FROM   qp_pricing_attributes qpa,
                                      qp_list_lines         qll1
                               WHERE  qpa.product_attr_value =
                                      to_char(v_item_id)
                               AND    qpa.list_header_id = p_list_header_id
                               AND    qll1.list_line_id = qpa.list_line_id
                               AND    (qll1.end_date_active IS NULL OR
                                     qll1.end_date_active >
                                     l_effective_date));
                      COMMIT;

                    EXCEPTION
                      WHEN OTHERS THEN
                        NULL;
                    END;
                    -- Michal Tzvik 14/01/2015
                    \*plist_line_api(v_errbuf,
                    v_retcode,
                    p_masterorganizid,
                    p_list_header_id,
                    v_item_id,
                    v_primary_uom_code,
                    v_itemprice,
                    l_effective_date);*\

                    plist_line_api(v_errbuf, v_retcode, p_masterorganizid, p_list_header_id, v_item_id, v_primary_uom_code, v_itemprice,
                                   -- 1.1   14/01/2015    Michal Tzvik
                                   -- p_effective_date    IN DATE,
                                   l_effective_date, NULL, NULL, qp_globals.g_opr_create);
                  ELSE
                    fnd_file.put_line(fnd_file.log, 'Item ' || v_item_code ||
                                       ' Already Exist in price list ');
                  END IF; -- v_update_status
                END IF; ------------- Gary 01/07/2014  CHG0032356 -----
              ELSE
                fnd_file.put_line(fnd_file.log, 'Item ' || v_item_code ||
                                   ' Not Exist In Organization: ' ||
                                   p_masterorganizid);
              END IF; -- v_item_id
            END IF; -- v_place
          END IF; -- v_read_code
        END LOOP;
    END;
  END price_list_fnd_util;*/

  --------------------------------------------------------------------
  --  customization code: CUST527
  --  name:               price_list_fnd_util2
  --  create by:          Vitaly K.
  --  $Revision: 4567 $
  --  creation date:      07/08/2012
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/08/2012    Vitaly K.       initial build
  -----------------------------------------------------------------------

  PROCEDURE price_list_fnd_util2(errbuf              OUT VARCHAR2,
                                 retcode             OUT VARCHAR2,
                                 p_master_organiz_id IN NUMBER,
                                 p_location          IN VARCHAR2,
                                 p_file_name         IN VARCHAR2,
                                 p_list_header_id    IN NUMBER,
                                 p_effective_date    IN VARCHAR2) IS
    v_counter  NUMBER(5) := 0;
    v_line_buf VARCHAR2(2000);
    --v_tmp_line         VARCHAR2(2000);
    v_read_code        NUMBER(5) := 1;
    plist_file         utl_file.file_type;
    v_place            NUMBER(3);
    v_delimiter        CHAR(1) := ',';
    v_item_code        mtl_system_items_b.segment1%TYPE;
    v_item_id          mtl_system_items_b.inventory_item_id%TYPE;
    v_primary_uom_code mtl_system_items_b.primary_uom_code%TYPE;
    v_itemprice        VARCHAR2(15);
    v_errbuf           VARCHAR2(500);
    v_retcode          VARCHAR2(10);
    v_update_status    VARCHAR2(30);
    l_effective_date   DATE;

  BEGIN
    IF p_effective_date IS NULL THEN
      l_effective_date := SYSDATE;
    ELSE
      l_effective_date := to_date(p_effective_date, 'YYYY/MM/DD HH24:MI:SS');
    END IF;

    BEGIN
      SELECT '1'
        INTO retcode
        FROM qp_list_lines qll
       WHERE qll.list_header_id = p_list_header_id
         AND end_date_active = l_effective_date
         AND rownum < 2;

      errbuf := 'Items with start effective date ' || l_effective_date ||
                ' already exists.' || chr(0);
    EXCEPTION
      WHEN OTHERS THEN
        /* -- closed by Vitaly 07/08/2012
        -- first update all rows for the wanted price list with end_date_active of yesterday
        UPDATE qp_list_lines qll
           SET qll.end_date_active = l_effective_date - 1
         WHERE qll.list_header_id = p_list_header_id
           AND qll.end_date_active IS NULL; -- add by yuval 13.2.2011 bug fix

        COMMIT;*/
        -- open the file for reading
        BEGIN
          plist_file := utl_file.fopen(location  => p_location,
                                       filename  => p_file_name,
                                       open_mode => 'r');
          fnd_file.put_line(fnd_file.log, ' '); --empty record
          fnd_file.put_line(fnd_file.log,
                            '**************************************************************************');
          fnd_file.put_line(fnd_file.log,
                            '********* FILE ' || p_location || '/' ||
                            ltrim(p_file_name) ||
                            ' Is open For Reading ********************');
          fnd_file.put_line(fnd_file.log,
                            '**************************************************************************');
          fnd_file.put_line(fnd_file.log, ' '); --empty record
        EXCEPTION
          WHEN utl_file.invalid_path THEN
            retcode := '2';
            errbuf  := errbuf || '=====ERROR: Invalid Path for ' ||
                       ltrim(p_file_name) || chr(0);
          WHEN utl_file.invalid_mode THEN
            retcode := '2';
            errbuf  := errbuf || '=====ERROR: Invalid Mode for ' ||
                       ltrim(p_file_name) || chr(0);
          WHEN utl_file.invalid_operation THEN
            retcode := '2';
            errbuf  := errbuf || '=====ERROR: Invalid operation for ' ||
                       ltrim(p_file_name) || SQLERRM || chr(0);
          WHEN OTHERS THEN
            retcode := '2';
            errbuf  := errbuf || '=====ERROR: Other for ' ||
                       ltrim(p_file_name) || chr(0);
        END;
        -- Loop For All File's Lines
        WHILE v_read_code <> 0 AND nvl(retcode, 1) = 1 LOOP
          BEGIN
            utl_file.get_line(file => plist_file, buffer => v_line_buf);

          EXCEPTION
            WHEN utl_file.read_error THEN
              retcode := '2';
              errbuf  := 'Read Error' || chr(0);
            WHEN no_data_found THEN
              errbuf      := 'Read Complete' || chr(0);
              v_read_code := 0;
            WHEN OTHERS THEN
              retcode := '2';
              errbuf  := 'Other for Line Read' || SQLERRM || chr(0);
          END;
          IF v_read_code <> 0 THEN
            v_retcode := NULL;
            v_counter := v_counter + 1;
            v_place   := instr(v_line_buf, v_delimiter);
            -- Check The Delimiter
            IF nvl(v_place, 0) = 0 OR (v_place > 100) THEN
              errbuf  := 'No Delimiter In The File, Line' ||
                         to_char(v_counter) || chr(0);
              retcode := '2';
            ELSE
              /* ---closed by Vitaly 07/08/2012
              v_item_code := ltrim(rtrim(substr(v_line_buf, 1, v_place - 1)));
              v_tmp_line  := ltrim(substr(v_line_buf,
                                          v_place + 1,
                                          length(v_line_buf)));
              --  dbms_output.put_line('v_tmp_line =' || v_tmp_line || '****');

              v_place := instr(v_tmp_line, v_delimiter);
              IF v_place = 0 THEN
                v_place := length(v_tmp_line) + 1;
              END IF;
              v_itemprice := ltrim(rtrim(substr(v_tmp_line, 1, v_place - 1)));
              v_tmp_line  := ltrim(substr(v_tmp_line,
                                          v_place + 1,
                                          length(v_tmp_line)));*/

              ----get field 1 (item segment1) from csv-file
              v_item_code := substr(v_line_buf,
                                    1,
                                    instr(v_line_buf, v_delimiter, 1, 1) - 1);
              v_item_code := upper(REPLACE(v_item_code, ' ', ''));

              ----get field 2 (item price) from csv-file-----LAST FIELD---remove "new line" character (chr(13) from last field value
              v_itemprice := substr(v_line_buf,
                                    instr(v_line_buf, v_delimiter, 1, 1) + 1);
              v_itemprice := rtrim(rtrim(ltrim(rtrim(v_itemprice, ' '), ' '),
                                         chr(13)),
                                   v_delimiter);
              --  dbms_output.put_line('Read Item =' || v_item_code ||
              --      ' Price= ' || v_itemprice);

              fnd_file.put_line(fnd_file.log,
                                '=== record ' || v_counter ||
                                ' ======= Read Item ' || v_item_code ||
                                ' Price ' || v_itemprice);

              BEGIN
                SELECT msi.inventory_item_id, primary_uom_code
                  INTO v_item_id, v_primary_uom_code
                  FROM mtl_system_items_b msi
                 WHERE msi.segment1 = v_item_code
                   AND msi.organization_id = p_master_organiz_id;
              EXCEPTION
                WHEN no_data_found THEN
                  v_item_id := NULL;
                  retcode   := 1;
              END;

              IF v_item_id IS NOT NULL THEN
                BEGIN
                  SELECT 'UPDATE'
                    INTO v_update_status
                    FROM qp_list_lines_v ql
                   WHERE ql.list_header_id = p_list_header_id
                     AND product_attribute_context = 'ITEM'
                     AND l_effective_date BETWEEN ql.start_date_active AND
                         ql.end_date_active -- added by  yuval 13.2.2011 bug fix
                        -- rem by  yuval 13.2.2011 bug fix
                        -- AND nvl(ql.end_date_active, l_effective_date - 1) <
                        --    l_effective_date - 1
                     AND product_id = v_item_id;
                EXCEPTION
                  WHEN no_data_found THEN
                    v_update_status := 'INSERT';
                  WHEN too_many_rows THEN
                    v_update_status := 'UPDATE';
                END;
                IF v_update_status = 'INSERT' THEN
                  -- Michal Tzvik 14/01/2015
                  /*plist_line_api(v_errbuf,
                  v_retcode,
                  p_master_organiz_id,
                  p_list_header_id,
                  v_item_id,
                  v_primary_uom_code,
                  v_itemprice,
                  l_effective_date);*/

                  plist_line_api(v_errbuf,
                                 v_retcode,
                                 p_master_organiz_id,
                                 p_list_header_id,
                                 v_item_id,
                                 v_primary_uom_code,
                                 v_itemprice,
                                 l_effective_date,
                                 NULL,
                                 NULL,
                                 qp_globals.g_opr_create);
                ELSE
                  fnd_file.put_line(fnd_file.log,
                                    '=== record ' || v_counter ||
                                    ' -- INVALID RECORD ... Item ' ||
                                    v_item_code ||
                                    ' Already Exist in price list ' ||
                                    ' **********************');
                END IF; -- v_update_status
              ELSE
                fnd_file.put_line(fnd_file.log,
                                  '=== record ' || v_counter ||
                                  ' -- INVALID RECORD ... Item ' ||
                                  v_item_code ||
                                  ' Not Exists In Organization: ' ||
                                  p_master_organiz_id ||
                                  ' **********************');
              END IF; -- v_item_id
            END IF; -- v_place
          END IF; -- v_read_code
        END LOOP;
    END;
  END price_list_fnd_util2;

  -----------------------------------------------------------------------
  -----------Update Price in Price List Lines and Blanket PO Lines -----
  --  customization code: CUST527
  --  name:               update_price
  --  create by:          Vitaly K.
  --  $Revision: 4567 $
  --  creation date:      17/10/2012
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/10/2012    Vitaly K.       initial build
  --  1.1   15.01.18      Yuval Tal       INC0111887 and condition qppr.pricing_attribute_context IS NULL

  -----------------------------------------------------------------------

  PROCEDURE update_price(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS

    CURSOR get_operating_units IS
      SELECT DISTINCT pl_tab.org_id,
                      pl_tab.operating_unit,
                      pl_tab.blanket_po_header_id
        FROM xxqp_update_price up,
             (SELECT ffv.flex_value ssys_price_list_name,
                     ffv.attribute1 price_list_header_id,
                     poh.org_id,
                     ffv.attribute3 blanket_po_header_id,
                     ou.name        operating_unit
                FROM fnd_flex_value_sets fvs,
                     fnd_flex_values_vl  ffv,
                     po_headers_all      poh,
                     hr_operating_units  ou
               WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
                 AND fvs.flex_value_set_name = 'XXQP_PRICELIST_UPDATES'
                 AND nvl(ffv.attribute3, '-777') = poh.po_header_id(+)
                 AND poh.org_id = ou.organization_id(+)) pl_tab
       WHERE up.status = 'N' --new
         AND rtrim(up.price_list_name) = pl_tab.ssys_price_list_name;

    CURSOR get_po_blanket_header(p_po_header_id NUMBER) IS
      SELECT poh.po_header_id,
             poh.segment1,
             poh.type_lookup_code,
             poh.vendor_id,
             v.vendor_name,
             poh.vendor_site_id,
             vs.vendor_site_code,
             poh.agent_id,
             initcap(a.agent_name) agent_name,
             poh.org_id,
             ou.name operating_unit
        FROM po_headers_all        poh,
             po_vendor_sites_all   vs,
             po_agents_v           a,
             po_vendors            v,
             hr_operating_units    ou,
             po_ga_org_assignments ga
       WHERE poh.po_header_id = p_po_header_id ---- parameter
         AND poh.global_agreement_flag = 'Y'
         AND poh.type_lookup_code = 'BLANKET'
         AND poh.vendor_id = 4472 ---  Stratasys, Inc.
         AND ou.name IN ('OBJET DE (OU)', 'OBJET HK (OU)') --- org_id in (96, 103)
         AND ga.po_header_id = poh.po_header_id
         AND nvl(ga.enabled_flag, 'N') = 'Y'
         AND ga.organization_id = poh.org_id
         AND nvl(poh.vendor_site_id, -777) = vs.vendor_site_id(+)
         AND poh.org_id = ou.organization_id
         AND nvl(poh.agent_id, -777) = a.agent_id(+)
         AND nvl(poh.vendor_id, -777) = v.vendor_id(+);

    CURSOR get_items(p_org_id NUMBER) IS
      SELECT up.line_id,
             up.item_code,
             up.item_descr,
             msi.inventory_item_id,
             msi.primary_uom_code,
             up.price new_price,
             up.uom,
             up.currency,
             up.price_list_name ssys_price_list_name,
             pl_tab.price_list_header_id,
             plh.name oracle_price_list_name,
             plh.description price_list_description,
             plh.list_type_code price_list_type_code,
             plh.currency_code price_list_currency_code,
             pl_tab.org_id,
             pl_tab.blanket_po_header_id,
             poh.segment1 blanket_po_num,
             (SELECT pla.po_line_id
                FROM po_lines_all pla, po_headers_all plh
               WHERE plh.po_header_id = pl_tab.blanket_po_header_id ---
                 AND pla.item_id = msi.inventory_item_id ---
                 AND nvl(pla.expiration_date, SYSDATE) >= SYSDATE
                 AND pla.po_header_id = plh.po_header_id
                 AND plh.type_lookup_code = 'BLANKET'
                 AND pla.item_id IS NOT NULL) existing_blanket_po_line_id,
             pl_tab.max_po_line_num,
             (SELECT qpll.list_line_id
                FROM qp_pricing_attributes qppr, qp_list_lines qpll
               WHERE qppr.product_attribute_context = 'ITEM'
                 AND qppr.product_attribute = 'PRICING_ATTRIBUTE1'
                 AND qpll.list_line_type_code IN ('PLL', 'PBH')
                 AND qppr.pricing_phase_id = 1
                 AND qppr.qualification_ind IN (4, 6, 20, 22)
                 AND qpll.pricing_phase_id = 1
                 AND qpll.qualification_ind IN (4, 6, 20, 22)
                 AND trunc(SYSDATE) BETWEEN qpll.start_date_active AND
                     nvl(qpll.end_date_active, SYSDATE)
                 AND qppr.list_line_id = qpll.list_line_id
                 AND qpll.list_header_id = pl_tab.price_list_header_id
                 AND qppr.product_attr_value = msi.inventory_item_id
                 AND qppr.pricing_attribute_context IS NULL /*INC0111887*/
              ) existing_price_list_line_id
        FROM xxqp_update_price up,
             mtl_system_items_b msi,
             po_headers_all poh,
             qp_list_headers_vl plh,
             (SELECT ffv.flex_value ssys_price_list_name,
                     ffv.attribute1 price_list_header_id,
                     poh.org_id,
                     ffv.attribute3 blanket_po_header_id,
                     (SELECT MAX(pla2.line_num)
                        FROM po_lines_all pla2
                       WHERE pla2.po_header_id = ffv.attribute3) max_po_line_num
                FROM fnd_flex_value_sets fvs,
                     fnd_flex_values_vl  ffv,
                     po_headers_all      poh
               WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
                 AND fvs.flex_value_set_name = 'XXQP_PRICELIST_UPDATES'
                 AND ffv.attribute3 = poh.po_header_id(+)) pl_tab
       WHERE nvl(pl_tab.org_id, -777) = nvl(p_org_id, -777) --parameter
         AND up.status = 'N' --new
         AND rtrim(up.item_code) = msi.segment1
         AND msi.organization_id = 91 --Master
         AND rtrim(up.price_list_name) = pl_tab.ssys_price_list_name
         AND pl_tab.blanket_po_header_id = poh.po_header_id(+)
         AND pl_tab.price_list_header_id = plh.list_header_id(+);

    v_req_id          NUMBER;
    v_step            VARCHAR2(50);
    v_error_msg       VARCHAR2(3000);
    v_numeric_dummy   NUMBER;
    l_records_updated NUMBER;
    --v_user_id                      NUMBER;
    v_interface_header_id          NUMBER;
    v_inserted_lines_counter       NUMBER;
    v_existing_po_line_unit_price  NUMBER;
    v_existing_pl_line_price       NUMBER;
    v_existing_pl_line_start_d_act DATE;
    v_existing_blanket_po_line_num NUMBER;
    v_new_blanket_po_line_will_be  VARCHAR2(1);
    v_new_price_list_line_will_be  VARCHAR2(1);
    ---v_inserted_into_open_interface  VARCHAR2(1);
    v_ins_into_open_interf_cntr NUMBER;

    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);

    l_retcode VARCHAR2(300);
    l_errbuf  VARCHAR2(300);

    stop_processing EXCEPTION;
    g_request_start_date DATE;

    ---api variables----
    ----v_error_tbl                     inv_item_grp.error_tbl_type;
    gpr_return_status  VARCHAR2(1) := NULL;
    gpr_msg_count      NUMBER := 0;
    gpr_msg_data       VARCHAR2(2000);
    gpr_price_list_rec qp_price_list_pub.price_list_rec_type;
    --gpr_price_list_val_rec      qp_price_list_pub.price_list_val_rec_type;
    gpr_price_list_line_tbl qp_price_list_pub.price_list_line_tbl_type;
    --gpr_price_list_line_val_tbl qp_price_list_pub.price_list_line_val_tbl_type;
    --gpr_qualifiers_tbl          qp_qualifier_rules_pub.qualifiers_tbl_type;
    --gpr_qualifiers_val_tbl      qp_qualifier_rules_pub.qualifiers_val_tbl_type;
    gpr_pricing_attr_tbl qp_price_list_pub.pricing_attr_tbl_type;
    --gpr_pricing_attr_val_tbl    qp_price_list_pub.pricing_attr_val_tbl_type;
    ppr_price_list_rec          qp_price_list_pub.price_list_rec_type;
    ppr_price_list_val_rec      qp_price_list_pub.price_list_val_rec_type;
    ppr_price_list_line_tbl     qp_price_list_pub.price_list_line_tbl_type;
    ppr_price_list_line_val_tbl qp_price_list_pub.price_list_line_val_tbl_type;
    ppr_qualifiers_tbl          qp_qualifier_rules_pub.qualifiers_tbl_type;
    ppr_qualifiers_val_tbl      qp_qualifier_rules_pub.qualifiers_val_tbl_type;
    ppr_pricing_attr_tbl        qp_price_list_pub.pricing_attr_tbl_type;
    ppr_pricing_attr_val_tbl    qp_price_list_pub.pricing_attr_val_tbl_type;
    k                           NUMBER := 1;
    j                           NUMBER := 1;

  BEGIN

    v_step               := 'Step 0';
    retcode              := '0';
    errbuf               := NULL;
    g_request_start_date := SYSDATE;

    /*
    -- Initialize User For Updates
    BEGIN
       SELECT user_id
         INTO v_user_id
         FROM fnd_user
        WHERE user_name = 'CONVERSION';
    EXCEPTION
       WHEN no_data_found THEN
          errbuf  := 'Invalid User CONVERSION';
          retcode := 2;
    END;

    fnd_global.apps_initialize(user_id      => v_user_id,
                               resp_id      => 50623,  ---- Implementation Manufacturing, OBJET
                               resp_appl_id => 660);*/

    ----Validations ---------------------------
    UPDATE xxqp_update_price a SET a.status = 'N' WHERE a.status IS NULL;

    v_step := 'Step 10';
    SELECT COUNT(1)
      INTO v_numeric_dummy
      FROM xxqp_update_price a
     WHERE nvl(a.status, 'N') = 'N';

    IF v_numeric_dummy = 0 THEN
      fnd_file.put_line(fnd_file.output,
                        'No new records (with Status=''N'' or Status is empty) in this batch');
    END IF;

    v_step := 'Step 12';
    UPDATE xxqp_update_price a
       SET a.error_message = NULL, a.message = NULL
     WHERE a.status = 'N';

    v_step := 'Step 15'; ----
    UPDATE xxqp_update_price a
       SET a.status           = 'E',
           a.error_message    = 'Missing Item Code',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.item_code) IS NULL;

    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Item_Code');
    END IF;

    v_step := 'Step 20';
    UPDATE xxqp_update_price a
       SET a.status           = 'E',
           a.error_message    = 'Item does not exist in Master Organization',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = 91 --Master
               AND msi.segment1 = rtrim(a.item_code));

    v_step := 'Step 25'; ----
    UPDATE xxqp_update_price a
       SET a.status           = 'E',
           a.error_message    = 'Missing Price List name',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.price_list_name) IS NULL;

    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Missing Price List name');
    END IF;

    v_step := 'Step 30'; ----
    UPDATE xxqp_update_price a
       SET a.status           = 'E',
           a.error_message    = 'Invalid SSYS Price List name (not found in Value Set XXQP_PRICELIST_UPDATES)',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND rtrim(a.price_list_name) IS NOT NULL
       AND NOT EXISTS
     (SELECT ffv.flex_value ssys_price_list_name,
                   ffv.attribute1 oracle_price_list_header_id,
                   ffv.attribute3 blanket_po_header_id
              FROM fnd_flex_value_sets fvs, fnd_flex_values_vl ffv
             WHERE fvs.flex_value_set_id = ffv.flex_value_set_id
               AND fvs.flex_value_set_name = 'XXQP_PRICELIST_UPDATES'
               AND ffv.flex_value = rtrim(a.price_list_name));

    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Invalid SSYS Price List name (not found in Value Set XXQP_PRICELIST_UPDATES)');
    END IF;

    v_step := 'Step 35'; ----
    ----Check item_code value---- may be characters like . or , or < or > or ; or : or ' or " or + .. inside
    UPDATE xxqp_update_price a
       SET a.status           = 'E',
           a.error_message    = 'There is forbidden character in your Item Code ',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND (instr(ltrim(rtrim(a.item_code)), ' ', 1) > 0 OR
           instr(a.item_code, '.', 1) > 0 OR
           instr(a.item_code, ',', 1) > 0 OR
           instr(a.item_code, '<', 1) > 0 OR
           instr(a.item_code, '>', 1) > 0 OR
           instr(a.item_code, '=', 1) > 0 OR
           instr(a.item_code, '_', 1) > 0 OR
           instr(a.item_code, ';', 1) > 0 OR
           instr(a.item_code, ':', 1) > 0 OR
           instr(a.item_code, '+', 1) > 0 OR
           instr(a.item_code, ')', 1) > 0 OR
           instr(a.item_code, '(', 1) > 0 OR
           instr(a.item_code, '*', 1) > 0 OR
           instr(a.item_code, '&', 1) > 0 OR
           instr(a.item_code, '^', 1) > 0 OR
           instr(a.item_code, '%', 1) > 0 OR
           instr(a.item_code, '$', 1) > 0 OR
           instr(a.item_code, '#', 1) > 0 OR
           instr(a.item_code, '@', 1) > 0 OR
           instr(a.item_code, '!', 1) > 0 OR
           instr(a.item_code, '?', 1) > 0 OR
           instr(a.item_code, '/', 1) > 0 OR
           instr(a.item_code, '\', 1) > 0 OR
           instr(a.item_code, '''', 1) > 0 OR
           instr(a.item_code, '"', 1) > 0 OR
           instr(a.item_code, '|', 1) > 0 OR
           instr(a.item_code, '{', 1) > 0 OR
           instr(a.item_code, '}', 1) > 0 OR
           instr(a.item_code, '[', 1) > 0 OR
           instr(a.item_code, ']', 1) > 0);

    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with forbidden character in Item_Code');
    END IF;

    ----------------------------------------------------------------
    v_step := 'Step 40'; -----
    UPDATE xxqp_update_price a
       SET a.status           = 'E',
           a.error_message    = 'There are more than 1 record for the same Item Code and Price List in this batch',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND EXISTS
     (SELECT 1
              FROM xxqp_update_price a2
             WHERE a2.batch_id = a.batch_id --parameter
               AND a2.status = 'N'
               AND a2.line_id != a.line_id
               AND rtrim(a2.item_code) = rtrim(a.item_code)
               AND rtrim(a2.price_list_name) = rtrim(a.price_list_name));

    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        'There are more than 1 record for the same Item_Code and Organization_Code in this batch');
    END IF;

    v_step := 'Step 45'; ----
    UPDATE xxqp_update_price a
       SET a.status           = 'E',
           a.error_message    = 'Missing Price',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.price IS NULL;

    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated || ' records with Missing Price');
    END IF;

    v_step := 'Step 50'; ----
    UPDATE xxqp_update_price a
       SET a.status           = 'E',
           a.error_message    = 'Invalid Price value',
           a.last_update_date = SYSDATE,
           a.last_updated_by  = fnd_global.user_id
     WHERE a.status = 'N'
       AND a.price IS NOT NULL
       AND a.price < 0;

    l_records_updated := SQL%ROWCOUNT;
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        l_records_updated ||
                        ' records with Invalid Price value');
    END IF;

    COMMIT;

    FOR operating_unit_rec IN get_operating_units LOOP
      ----------------- OPERATING UNITS LOOP ----------------------------------------------
      v_step                      := 'Step 100';
      v_interface_header_id       := NULL;
      v_ins_into_open_interf_cntr := 0;
      ----dbms_output.put_line('====================OPERATING UNIT  ='||operating_unit_rec.operating_unit||'==========================');
      ----fnd_file.put_line(fnd_file.output,'====================OPERATING UNIT  ='||operating_unit_rec.operating_unit||'==========================');
      IF operating_unit_rec.org_id IS NOT NULL THEN
        -------
        BEGIN
          mo_global.set_org_access(p_org_id_char     => operating_unit_rec.org_id,
                                   p_sp_id_char      => NULL,
                                   p_appl_short_name => 'PO');
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
        -------
      END IF;

      FOR item_rec IN get_items(operating_unit_rec.org_id) LOOP
        ------------------- DATA LOOP --------------------------------------
        BEGIN
          v_step                        := 'Step 110';
          v_new_price_list_line_will_be := 'N';
          --------- Close existing line and Add new line to Price List ---------------------------
          IF item_rec.existing_price_list_line_id IS NULL THEN
            ---no valid price list line for this item
            ---new line wil be inserted
            v_new_price_list_line_will_be := 'Y';
          ELSE
            ----- check existing valid record in qp_list_lines
            v_step := 'Step 120';
            BEGIN
              SELECT qpll.start_date_active, qpll.operand
                INTO v_existing_pl_line_start_d_act,
                     v_existing_pl_line_price
                FROM qp_list_lines qpll
               WHERE qpll.list_header_id = item_rec.price_list_header_id
                 AND qpll.list_line_id =
                     item_rec.existing_price_list_line_id;
            EXCEPTION
              WHEN no_data_found THEN
                v_existing_pl_line_price := NULL;
            END;
            IF v_existing_pl_line_price = item_rec.new_price THEN
              ---There is valid Price List line with the same price for this item
              v_new_price_list_line_will_be := 'N';
            ELSIF v_existing_pl_line_start_d_act = trunc(SYSDATE) THEN
              ---There is valid Price List line with the same start_date_active... for this item
              ---Price should be updated in this line
              v_new_price_list_line_will_be := 'N';
            ELSE
              v_step := 'Step 130';
              UPDATE qp_list_lines qll
                 SET qll.end_date_active  = trunc(SYSDATE) - 1,
                     qll.last_update_date = SYSDATE,
                     qll.last_updated_by  = fnd_global.user_id
               WHERE qll.list_header_id = item_rec.price_list_header_id
                 AND qll.list_line_id =
                     item_rec.existing_price_list_line_id;
              -----AND    qll.list_price <> item_rec.new_price;

              v_step := 'Step 140';
              UPDATE xxqp_update_price a
                 SET a.message          = ltrim(a.message || chr(10) ||
                                                'Existing PL Line was closed',
                                                chr(10)),
                     a.last_update_date = SYSDATE,
                     a.last_updated_by  = fnd_global.user_id
               WHERE ---a.batch_id=p_batch_id AND --parameter
               a.line_id = item_rec.line_id;

              v_new_price_list_line_will_be := 'Y';
            END IF;
          END IF;

          COMMIT;

          IF v_new_price_list_line_will_be = 'N' AND
             v_existing_pl_line_price = item_rec.new_price THEN
            v_step := 'Step 150';
            UPDATE xxqp_update_price a
               SET a.message          = ltrim(a.message || chr(10) ||
                                              'There is PL Line with the same price for this item',
                                              chr(10)),
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.line_id = item_rec.line_id;
          ELSIF v_new_price_list_line_will_be = 'N' AND
                v_existing_pl_line_start_d_act = trunc(SYSDATE) THEN
            v_step := 'Step 160';
            /*UPDATE XXQP_UPDATE_PRICE  a
            SET  a.message=ltrim(a.message||chr(10)||'There is PL Line with the same Start Date Active for this item - price was updated',chr(10)),
                 a.last_update_date=sysdate,
                 a.last_updated_by =fnd_global.user_id
            WHERE a.batch_id=p_batch_id --parameter
            AND   a.line_id=item_rec.line_id;*/
            v_error_msg := NULL;
            -------------------------API----------UPDATE PRICE IN EXISTING PRICE LIST LINE-------------------------------------
            -- QP Header Record
            gpr_price_list_rec.list_header_id := item_rec.price_list_header_id;
            gpr_price_list_rec.list_type_code := item_rec.price_list_type_code;
            gpr_price_list_rec.description    := item_rec.price_list_description;
            gpr_price_list_rec.currency_code  := item_rec.price_list_currency_code;
            gpr_price_list_rec.operation      := qp_globals.g_opr_none;
            -- QP Line Record
            gpr_price_list_line_tbl(k).list_header_id := item_rec.price_list_header_id;
            gpr_price_list_line_tbl(k).list_line_id := item_rec.existing_price_list_line_id;
            gpr_price_list_line_tbl(k).list_line_type_code := 'PLL';
            gpr_price_list_line_tbl(k).operation := qp_globals.g_opr_update; ---UPDATE----
            ---gpr_price_list_line_tbl(k).start_date_active   := trunc(sysdate);   ---p_effective_date;
            ----------------gpr_price_list_line_tbl(K).inventory_item_id := P_inventory_item_id;
            gpr_price_list_line_tbl(k).operand := item_rec.new_price;
            ---gpr_price_list_line_tbl(k).arithmetic_operator := 'UNIT_PRICE';
            ---gpr_price_list_line_tbl(k).product_precedence  := 220;
            -- QP Pricing Record
            ---gpr_pricing_attr_tbl(j).pricing_attribute_id := fnd_api.g_miss_num;
            ---gpr_pricing_attr_tbl(j).list_line_id         := fnd_api.g_miss_num;
            ---gpr_pricing_attr_tbl(j).product_attribute_context := 'ITEM';
            ---gpr_pricing_attr_tbl(j).product_attribute  :='PRICING_ATTRIBUTE1';
            ---gpr_pricing_attr_tbl(j).product_attr_value := item_rec.inventory_item_id;
            ---gpr_pricing_attr_tbl(j).product_uom_code   := item_rec.primary_uom_code;
            ---gpr_pricing_attr_tbl(j).excluder_flag         :='N';
            ---gpr_pricing_attr_tbl(j).attribute_grouping_no := 1;
            ---gpr_pricing_attr_tbl(j).price_list_line_index := 1;
            ---gpr_pricing_attr_tbl(j).operation := qp_globals.g_opr_update;  ---UPDATE------
          ELSE
            v_step := 'Step 170';
            ---v_error_tbl.DELETE;
            v_error_msg := NULL;
            -------------------------API-----------------------------------------------
            -- QP Header Record
            gpr_price_list_rec.list_header_id := item_rec.price_list_header_id;
            gpr_price_list_rec.list_type_code := item_rec.price_list_type_code;
            gpr_price_list_rec.description    := item_rec.price_list_description;
            gpr_price_list_rec.currency_code  := item_rec.price_list_currency_code;
            gpr_price_list_rec.operation      := qp_globals.g_opr_none;
            -- QP Line Record
            gpr_price_list_line_tbl(k).list_header_id := item_rec.price_list_header_id;
            gpr_price_list_line_tbl(k).list_line_id := fnd_api.g_miss_num;
            gpr_price_list_line_tbl(k).list_line_type_code := 'PLL';
            gpr_price_list_line_tbl(k).operation := qp_globals.g_opr_create; ---CREATE ------
            gpr_price_list_line_tbl(k).start_date_active := trunc(SYSDATE); ---p_effective_date;
            --gpr_price_list_line_tbl(K).inventory_item_id := P_inventory_item_id;
            gpr_price_list_line_tbl(k).operand := item_rec.new_price;
            gpr_price_list_line_tbl(k).arithmetic_operator := 'UNIT_PRICE';
            gpr_price_list_line_tbl(k).product_precedence := 220;
            -- QP Pricing Record
            gpr_pricing_attr_tbl(j).pricing_attribute_id := fnd_api.g_miss_num;
            gpr_pricing_attr_tbl(j).list_line_id := fnd_api.g_miss_num;
            gpr_pricing_attr_tbl(j).product_attribute_context := 'ITEM';
            gpr_pricing_attr_tbl(j).product_attribute := 'PRICING_ATTRIBUTE1';
            gpr_pricing_attr_tbl(j).product_attr_value := item_rec.inventory_item_id;
            gpr_pricing_attr_tbl(j).product_uom_code := item_rec.primary_uom_code;
            gpr_pricing_attr_tbl(j).excluder_flag := 'N';
            gpr_pricing_attr_tbl(j).attribute_grouping_no := 1;
            gpr_pricing_attr_tbl(j).price_list_line_index := 1;
            gpr_pricing_attr_tbl(j).operation := qp_globals.g_opr_create; ---CREATE ------
          END IF;

          IF v_new_price_list_line_will_be = 'Y' OR --Create new PL line
             (v_new_price_list_line_will_be = 'N' AND
             v_existing_pl_line_start_d_act = trunc(SYSDATE) AND
             v_existing_pl_line_price <> item_rec.new_price) THEN
            --Update price in existing PL line
            v_step := 'Step 180';
            -- Call QP API
            qp_price_list_pub.process_price_list(p_api_version_number      => 1.0,
                                                 p_init_msg_list           => fnd_api.g_true,
                                                 p_return_values           => fnd_api.g_false,
                                                 p_commit                  => fnd_api.g_false,
                                                 x_return_status           => gpr_return_status,
                                                 x_msg_count               => gpr_msg_count,
                                                 x_msg_data                => gpr_msg_data,
                                                 p_price_list_rec          => gpr_price_list_rec,
                                                 p_price_list_line_tbl     => gpr_price_list_line_tbl,
                                                 p_pricing_attr_tbl        => gpr_pricing_attr_tbl,
                                                 x_price_list_rec          => ppr_price_list_rec,
                                                 x_price_list_val_rec      => ppr_price_list_val_rec,
                                                 x_price_list_line_tbl     => ppr_price_list_line_tbl,
                                                 x_price_list_line_val_tbl => ppr_price_list_line_val_tbl,
                                                 x_qualifiers_tbl          => ppr_qualifiers_tbl,
                                                 x_qualifiers_val_tbl      => ppr_qualifiers_val_tbl,
                                                 x_pricing_attr_tbl        => ppr_pricing_attr_tbl,
                                                 x_pricing_attr_val_tbl    => ppr_pricing_attr_val_tbl);

            v_step := 'Step 190';
            ----fnd_file.put_line(fnd_file.log, '===== API Status qp_price_list_pub.process_price_list ='||gpr_return_status);
            ---dbms_output.put_line('===== API Status qp_price_list_pub.process_price_list ='||gpr_return_status||', gpr_msg_data='||gpr_msg_data);

            IF ppr_price_list_line_tbl(k)
             .return_status <> fnd_api.g_ret_sts_success THEN
              ----ERROR------
              ROLLBACK;

              v_step := 'Step 200';
              IF ppr_price_list_line_tbl.count > 0 THEN
                FOR k IN 1 .. ppr_price_list_line_tbl.count LOOP
                  ---dbms_output.put_line('No Of Record Got Insterted=> ' k);
                  ---dbms_output.put_line('Return Status = ' ppr_price_list_line_tbl(k).return_status);
                  NULL;
                END LOOP;
              END IF;
              v_step := 'Step 210';

              FOR k IN 1 .. gpr_msg_count LOOP
                gpr_msg_data := oe_msg_pub.get(p_msg_index => k,
                                               p_encoded   => 'F');
                v_error_msg  := v_error_msg || substr(gpr_msg_data, 1, 255) ||
                                chr(10);
              END LOOP;

              v_step := 'Step 220';
              UPDATE xxqp_update_price a
                 SET a.status           = 'E',
                     a.error_message    = decode(v_new_price_list_line_will_be,
                                                 'Y',
                                                 'Create new PL line API Error : ' ||
                                                 v_error_msg,
                                                 'Update Price in existing PL line API Error : ' ||
                                                 v_error_msg),
                     a.message          = 'Error in Price List...Did NOT proceed to BPA',
                     a.last_update_date = SYSDATE,
                     a.last_updated_by  = fnd_global.user_id
               WHERE a.line_id = item_rec.line_id;

              RAISE stop_processing;
            ELSE
              ----SUCCESS-----
              v_step := 'Step 230';
              COMMIT;

              UPDATE xxqp_update_price a
                 SET a.message          = decode(v_new_price_list_line_will_be,
                                                 'Y',
                                                 ltrim(a.message || chr(10) ||
                                                       'New Price List line was added',
                                                       chr(10)),
                                                 ltrim(a.message || chr(10) ||
                                                       'Price in existing Price List Line was updated',
                                                       chr(10))),
                     a.last_update_date = SYSDATE,
                     a.last_updated_by  = fnd_global.user_id
               WHERE a.line_id = item_rec.line_id;
            END IF;
          END IF;

          ---raise stop_processing;

          IF operating_unit_rec.blanket_po_header_id IS NOT NULL THEN
            ---------------------------------------------------------------------------
            -----Add line to Blanket PO document---------------------------------------
            ---------------------------------------------------------------------------
            v_new_blanket_po_line_will_be := 'N';
            IF item_rec.existing_blanket_po_line_id IS NULL THEN
              ---no valid po_line for this item
              v_new_blanket_po_line_will_be := 'Y';
              --------
              v_step := 'Step 240';
              IF v_interface_header_id IS NULL THEN
                SELECT apps.po_headers_interface_s.nextval
                  INTO v_interface_header_id
                  FROM dual;
              END IF;
            ELSE
              ----- check existing valid record in qp_list_lines
              ---------- if new price <> existing price then update this record
              BEGIN
                v_step := 'Step 250';
                SELECT pla.line_num, pla.unit_price
                  INTO v_existing_blanket_po_line_num,
                       v_existing_po_line_unit_price
                  FROM po_lines_all pla, po_headers_all plh
                 WHERE plh.po_header_id = item_rec.blanket_po_header_id
                   AND pla.po_header_id = plh.po_header_id
                   AND pla.po_line_id =
                       item_rec.existing_blanket_po_line_id;
              EXCEPTION
                WHEN no_data_found THEN
                  v_existing_po_line_unit_price  := NULL;
                  v_existing_blanket_po_line_num := NULL;
              END;
              --------------------------------
              IF nvl(v_existing_po_line_unit_price, 0) = item_rec.new_price THEN
                ---There is valid po_line with the same price for this item
                v_step                        := 'Step 260';
                v_new_blanket_po_line_will_be := 'N';
                UPDATE xxqp_update_price a
                   SET a.message          = ltrim(a.message || chr(10) ||
                                                  'There is Blanket PO Line with the same price for this item',
                                                  chr(10)),
                       a.last_update_date = SYSDATE,
                       a.last_updated_by  = fnd_global.user_id
                 WHERE a.line_id = item_rec.line_id;
              ELSE
                v_new_blanket_po_line_will_be := 'N';
                ---- update existing po_line --- update Unit Price-----
                v_step := 'Step 270';
                IF v_interface_header_id IS NULL THEN
                  SELECT apps.po_headers_interface_s.nextval
                    INTO v_interface_header_id
                    FROM dual;
                END IF;
                ----------------
                v_step := 'Step 280';
                INSERT INTO po_lines_interface
                  (interface_line_id,
                   interface_header_id,
                   line_num,
                   item_id,
                   action,
                   process_code,
                   unit_price,
                   ----QUANTITY,
                   ----EXPIRATION_DATE,
                   creation_date,
                   created_by,
                   last_update_date,
                   last_updated_by)
                VALUES
                  (apps.po_lines_interface_s.nextval,
                   v_interface_header_id,
                   v_existing_blanket_po_line_num,
                   item_rec.inventory_item_id,
                   'UPDATE',
                   'PENDING',
                   item_rec.new_price,
                   ----999999,
                   -----trunc(SYSDATE)-1 ,  ---close EXPIRATION_DATE
                   SYSDATE,
                   fnd_global.user_id,
                   SYSDATE,
                   fnd_global.user_id);

                v_ins_into_open_interf_cntr := v_ins_into_open_interf_cntr + 1;

                v_step := 'Step 290';
                UPDATE xxqp_update_price a
                   SET a.message          = ltrim(a.message || chr(10) ||
                                                  'Update Unit Price in Existing Blanket PO Line - inserted into Open Interface table',
                                                  chr(10)),
                       a.last_update_date = SYSDATE,
                       a.last_updated_by  = fnd_global.user_id
                 WHERE a.line_id = item_rec.line_id;

                v_inserted_lines_counter := v_inserted_lines_counter + 1;
              END IF;

            END IF;
            IF v_new_blanket_po_line_will_be = 'Y' THEN
              v_step := 'Step 300';
              INSERT INTO po_lines_interface
                (interface_line_id,
                 interface_header_id,
                 line_num,
                 item_id,
                 action,
                 process_code,
                 unit_price,
                 quantity,
                 -----EXPIRATION_DATE,
                 creation_date,
                 created_by,
                 last_update_date,
                 last_updated_by)
              VALUES
                (apps.po_lines_interface_s.nextval,
                 v_interface_header_id,
                 nvl(item_rec.max_po_line_num, 0) + 1,
                 item_rec.inventory_item_id,
                 'ADD',
                 'PENDING',
                 item_rec.new_price,
                 999999,
                 ----to_date('31-DEC-'||to_char(to_number(to_char(SYSDATE,'YYYY'))+1),'DD-MON-YYYY'),  ---EXPIRATION_DATE
                 SYSDATE,
                 fnd_global.user_id,
                 SYSDATE,
                 fnd_global.user_id);
              ---v_inserted_into_open_interface:='Y';
              v_ins_into_open_interf_cntr := v_ins_into_open_interf_cntr + 1;

              v_step := 'Step 310';
              UPDATE xxqp_update_price a
                 SET a.message          = ltrim(a.message || chr(10) ||
                                                'New Blanket PO Line - inserted into Open Interface table',
                                                chr(10)),
                     a.last_update_date = SYSDATE,
                     a.last_updated_by  = fnd_global.user_id
               WHERE a.line_id = item_rec.line_id;

              v_inserted_lines_counter := v_inserted_lines_counter + 1;

            END IF; -----if v_new_blanket_po_line_will_be='Y'
          END IF; ---IF operating_unit_rec.blanket_po_header_id IS NOT NULL THEN

          COMMIT;

        EXCEPTION
          WHEN stop_processing THEN
            NULL;
          WHEN OTHERS THEN
            v_error_msg := SQLERRM;

            UPDATE xxqp_update_price a
               SET a.status           = 'E',
                   a.error_message    = 'Unexpected Error ' || v_step || ': ' ||
                                        v_error_msg,
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.line_id = item_rec.line_id;
        END;
        ------------------- the end of DATA LOOP --------------------------------------
      END LOOP;

      COMMIT;

      IF operating_unit_rec.org_id IS NOT NULL AND
         v_ins_into_open_interf_cntr > 0 THEN
        FOR po_blanket_header_rec IN get_po_blanket_header(operating_unit_rec.blanket_po_header_id) LOOP
          v_step := 'Step 340';
          ----- 1 row only

          v_step := 'Step 350';
          INSERT INTO po_headers_interface
            (interface_header_id,
             po_header_id, --this blanket po should be updated
             batch_id,
             action,
             process_code,
             document_type_code,
             approval_status,
             org_id,
             vendor_id,
             vendor_site_code,
             vendor_site_id,
             agent_id, --optional as you can enter buyer duringimport run
             -----VENDOR_DOC_NUM, --Unique Identifier used to update Blanket
             creation_date,
             created_by,
             last_update_date,
             last_updated_by)
          VALUES
            (v_interface_header_id,
             po_blanket_header_rec.po_header_id,
             1,
             'UPDATE',
             'PENDING',
             'BLANKET',
             'APPROVED',
             po_blanket_header_rec.org_id,
             po_blanket_header_rec.vendor_id,
             po_blanket_header_rec.vendor_site_code,
             po_blanket_header_rec.vendor_site_id,
             po_blanket_header_rec.agent_id,
             ----po_blanket_header_rec.segment1,
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.user_id);
        END LOOP;
        COMMIT;
        ---END IF;
        -----------------------------------------------------------------------------------------------------------------------------------
        ---Concurrent program 'Import Price Catalogs' should be submitted from responsibility 'Implementation Manufacturing, OBJET'
        ---------------------------- creating new Blanket PO Lines will be completed ------------------------------------------------------
        -----------------------------------------------------------------------------------------------------------------------------------
        v_step   := 'Step 360';
        v_req_id := fnd_request.submit_request('PO',
                                               'POXPDOI', ---Import Price Catalogs
                                               NULL,
                                               NULL,
                                               FALSE,
                                               NULL, ---parameter  1 Default Buyer
                                               'Blanket', ---parameter  2 Document Type
                                               NULL, ---parameter  3 Document Sub Type
                                               'N', ---parameter  4 Create or Update Items
                                               'N', ---parameter  5 Create Sourcing Rules
                                               'APPROVED', ---parameter  6 Approval Status
                                               NULL, ---parameter  7 Release Generetion Method
                                               1, ---parameter  8 Batch Id
                                               operating_unit_rec.org_id, ---parameter  9 Operating Unit
                                               'Y', ---parameter 10 Global Agreement
                                               'Y', ---parameter 11 Enable Sourcing Level
                                               NULL, ---parameter 12 Sourcing Level
                                               NULL, ---parameter 13 Inv Org Enable
                                               NULL); ---parameter 14 Inventory Organization
        COMMIT;

        IF v_req_id > 0 THEN
          fnd_file.put_line(fnd_file.log,
                            '====== Concurrent ''Import Price Catalogs'' was submitted successfully (request_id=' ||
                            v_req_id || ')');
          dbms_output.put_line('Concurrent ''Import Price Catalogs'' was submitted successfully (request_id=' ||
                               v_req_id || ')');
          ---------
          v_step := 'Step 210';
          LOOP
            x_return_bool := fnd_concurrent.wait_for_request(v_req_id,
                                                             10, --- interval 10  seconds
                                                             3600, --- max wait 1 hour
                                                             x_phase,
                                                             x_status,
                                                             x_dev_phase,
                                                             x_dev_status,
                                                             x_message);
            EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';

          END LOOP;

          fnd_file.put_line(fnd_file.log,
                            '======= The ''Import Price Catalogs'' concurrent program has completed with status ' ||
                            upper(x_dev_status) || ' (request_id=' ||
                            v_req_id || ')');
          dbms_output.put_line('The ''Import Price Catalogs'' concurrent program has completed with status ' ||
                               upper(x_dev_status) || ' (request_id=' ||
                               v_req_id || ')');

          IF upper(x_dev_phase) = 'COMPLETE' AND
             upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
            fnd_file.put_line(fnd_file.log,
                              '======= The ''Import Price Catalogs'' concurrent program completed in error. See log for request_id=' ||
                              v_req_id);
            v_step := 'Step 220';
            UPDATE xxqp_update_price a
               SET a.status           = 'E',
                   a.error_message    = 'The ''Import Price Catalogs'' concurrent program was completed in error. See log for request_id=' ||
                                        v_req_id,
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.status = 'N';

          ELSIF upper(x_dev_phase) = 'COMPLETE' AND
                upper(x_dev_status) = 'NORMAL' THEN
            fnd_file.put_line(fnd_file.log,
                              '======= The ''Import Price Catalogs'' program successfully completed for request_id=' ||
                              v_req_id);
            v_step := 'Step 230';
            UPDATE xxqp_update_price a
               SET a.status           = 'S', --- Blanket PO Line SUCCESSFULLY created/updated
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.status = 'N'
               AND EXISTS
             (SELECT 1 ---ffv.flex_value    ssys_price_list_name,
                    ---ffv.attribute1    price_list_header_id,
                    ---poh.org_id,
                    ---ffv.attribute3    blanket_po_header_id
                    ---ou.name   operating_unit
                      FROM fnd_flex_value_sets fvs,
                           fnd_flex_values_vl  ffv,
                           po_headers_all      poh,
                           hr_operating_units  ou
                     WHERE ---poh.org_id = p_org_id and --parameter
                     fvs.flex_value_set_id = ffv.flex_value_set_id
                  AND fvs.flex_value_set_name = 'XXQP_PRICELIST_UPDATES'
                  AND ffv.attribute3 = poh.po_header_id
                  AND poh.org_id = ou.organization_id
                  AND ou.name = operating_unit_rec.operating_unit ---
                  AND ffv.flex_value = a.price_list_name) ---
               AND EXISTS
             (SELECT 1
                      FROM po_headers_all     poh,
                           po_lines_all       pol,
                           mtl_system_items_b msi
                     WHERE poh.po_header_id = pol.po_header_id
                       AND nvl(pol.expiration_date, SYSDATE) >= SYSDATE
                       AND pol.item_id = msi.inventory_item_id
                       AND msi.organization_id = 91 --Master
                       AND poh.po_header_id =
                           operating_unit_rec.blanket_po_header_id ---
                       AND msi.segment1 = rtrim(a.item_code) ---
                       AND pol.unit_price = a.price); ---

            v_step := 'Step 240';
            UPDATE xxqp_update_price a
               SET a.status           = 'E',
                   a.error_message    = 'Open Interface (PO_LINES_INTERFACE) ERROR: ' ||
                                        (SELECT poie.error_message
                                           FROM po_lines_interface  poli,
                                                po_interface_errors poie,
                                                mtl_system_items_b  msi
                                          WHERE poli.interface_header_id =
                                                v_interface_header_id ------
                                            AND poli.interface_header_id =
                                                poie.interface_header_id
                                            AND poli.interface_line_id =
                                                poie.interface_line_id
                                            AND poli.item_id =
                                                msi.inventory_item_id
                                            AND msi.organization_id = 91 --master
                                            AND msi.segment1 =
                                                rtrim(a.item_code) ------
                                            AND rownum = 1),
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.status = 'N'
               AND EXISTS
             (SELECT 1 ---ffv.flex_value    ssys_price_list_name,
                    ---ffv.attribute1    price_list_header_id,
                    ---poh.org_id,
                    ---ffv.attribute3    blanket_po_header_id
                    ---ou.name   operating_unit
                      FROM fnd_flex_value_sets fvs,
                           fnd_flex_values_vl  ffv,
                           po_headers_all      poh,
                           hr_operating_units  ou
                     WHERE ---poh.org_id = p_org_id and --parameter
                     fvs.flex_value_set_id = ffv.flex_value_set_id
                  AND fvs.flex_value_set_name = 'XXQP_PRICELIST_UPDATES'
                  AND ffv.attribute3 = poh.po_header_id
                  AND poh.org_id = ou.organization_id
                  AND ou.name = operating_unit_rec.operating_unit ---
                  AND ffv.flex_value = a.price_list_name) ---
               AND EXISTS
             (SELECT 1 ---poie.error_message
                      FROM po_lines_interface  poli,
                           po_interface_errors poie,
                           mtl_system_items_b  msi
                     WHERE poli.interface_header_id = v_interface_header_id ------
                       AND poli.interface_header_id =
                           poie.interface_header_id
                       AND poli.interface_line_id = poie.interface_line_id
                       AND poli.item_id = msi.inventory_item_id
                       AND msi.organization_id = 91 --master
                       AND msi.segment1 = rtrim(a.item_code) ------
                    );
            v_step := 'Step 250';
            UPDATE xxqp_update_price a
               SET a.status           = 'E',
                   a.error_message    = 'Open Interface (PO_HEADERS_INTERFACE) ERROR: ' ||
                                        (SELECT poie.error_message
                                           FROM po_interface_errors poie
                                          WHERE poie.interface_header_id =
                                                v_interface_header_id ------
                                            AND poie.interface_line_id IS NULL
                                            AND rownum = 1),
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.status = 'N'
               AND EXISTS
             (SELECT 1 ---ffv.flex_value    ssys_price_list_name,
                    ---ffv.attribute1    price_list_header_id,
                    ---poh.org_id,
                    ---ffv.attribute3    blanket_po_header_id
                    ---ou.name   operating_unit
                      FROM fnd_flex_value_sets fvs,
                           fnd_flex_values_vl  ffv,
                           po_headers_all      poh,
                           hr_operating_units  ou
                     WHERE ---poh.org_id = p_org_id and --parameter
                     fvs.flex_value_set_id = ffv.flex_value_set_id
                  AND fvs.flex_value_set_name = 'XXQP_PRICELIST_UPDATES'
                  AND ffv.attribute3 = poh.po_header_id
                  AND poh.org_id = ou.organization_id
                  AND ou.name = operating_unit_rec.operating_unit ---
                  AND ffv.flex_value = a.price_list_name) ---
               AND EXISTS
             (SELECT 1 ----poie.error_message
                      FROM po_interface_errors poie
                     WHERE poie.interface_header_id = v_interface_header_id ------
                       AND poie.interface_line_id IS NULL);

            v_step := 'Step 260';
            UPDATE xxqp_update_price a
               SET a.status           = 'E',
                   a.error_message    = 'Open Interface ERROR ',
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.status = 'N'
               AND EXISTS
             (SELECT 1 ---ffv.flex_value    ssys_price_list_name,
                    ---ffv.attribute1    price_list_header_id,
                    ---poh.org_id,
                    ---ffv.attribute3    blanket_po_header_id
                    ---ou.name   operating_unit
                      FROM fnd_flex_value_sets fvs,
                           fnd_flex_values_vl  ffv,
                           po_headers_all      poh,
                           hr_operating_units  ou
                     WHERE ---poh.org_id = p_org_id and --parameter
                     fvs.flex_value_set_id = ffv.flex_value_set_id
                  AND fvs.flex_value_set_name = 'XXQP_PRICELIST_UPDATES'
                  AND ffv.attribute3 = poh.po_header_id
                  AND poh.org_id = ou.organization_id
                  AND ou.name = operating_unit_rec.operating_unit ---
                  AND ffv.flex_value = a.price_list_name); ---

          ELSE
            fnd_file.put_line(fnd_file.log,
                              '======= The ''Import Price Catalogs'' request failed.Review log for Oracle request_id=' ||
                              v_req_id);
            v_step := 'Step 300';
            UPDATE xxqp_update_price a
               SET a.status           = 'E',
                   a.error_message    = 'The ''Import Price Catalogs'' request failed.Review log for Oracle request_id=' ||
                                        v_req_id,
                   a.last_update_date = SYSDATE,
                   a.last_updated_by  = fnd_global.user_id
             WHERE a.status = 'N';
          END IF;
        ELSE
          fnd_file.put_line(fnd_file.log,
                            '====== Concurrent ''Import Price Catalogs'' submitting PROBLEM');
          ---dbms_output.put_line('Concurrent ''Import Price Catalogs'' submitting PROBLEM');
        END IF;

      END IF; ---IF operating_unit_rec.org_id IS NOT NULL AND v_ins_into_open_interf_cntr>0 THEN

    ----------------- the end of OPERATING UNITS LOOP ----------------------------------------------
    END LOOP;

    --- send notification log----
    xxobjt_wf_mail.send_mail_body_proc(p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                       p_cc_mail     => xxobjt_general_utils_pkg.get_dist_mail_list(NULL,
                                                                                                    'SSYS_UPD_PRICE'),
                                       p_bcc_mail    => NULL,
                                       p_subject     => 'Update Price List And BPA : Alert Log',
                                       p_body_proc   => 'xxqp_upd_price_alert_pkg.prepare_notification_body/' ||
                                                        to_char(g_request_start_date,
                                                                'ddmmyyyy hh24:mi'),
                                       p_err_code    => l_retcode,
                                       p_err_message => l_errbuf);
    ---

  EXCEPTION
    WHEN OTHERS THEN
      -- send err alert
      xxobjt_wf_mail.send_mail_text(p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                    p_subject     => 'Update Price List And BPA : Failure',
                                    p_body_text   => 'xxqp_utils_pkg.update_price' ||
                                                     chr(10) ||
                                                     'Unexpected Error:' ||
                                                     SQLERRM,
                                    p_err_code    => l_retcode,
                                    p_err_message => l_errbuf);
      --
      fnd_file.put_line(fnd_file.output,
                        '=======Unexpected ERROR in XXQP_UTILS_PKG.update_price proc: ' ||
                        v_step || ' ---' || SQLERRM);

      retcode := '2';
      errbuf  := 'Unexpected ERROR in XXQP_UTILS_PKG.update_price proc: ' ||
                 v_step || ' ---' || SQLERRM;
  END update_price;
  --------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               get_custom_price
  --  create by:          AVIH
  --  $Revision: 4567 $
  --  creation date:      05/07/2009
  --  Description:        This procedure called from QP_CUSTOM package.
  --                      The Get Custom Price API is a customizable function to which the user may add
  --                      custom code.  The API is called by the pricing engine while evaluating a
  --                      formula that contains a formula line (step) of type Function.  One or more
  --                      formulas may be set up to contain a formula line of type Function and the
  --                      same API is called each time.  So the user must code the logic in the API
  --                      based on the price_formula_id that is passed as an input parameter to the API.
  --
  --  In param            p_price_formula_id the formula ID
  --                      p_list_price the list price when the formula step type is 'List Price'
  --                      p_price_effective_date the date the price is effective
  --                      p_req_line_attrs_tbl the input line attributes
  --
  --  return              the calculated price
  --
  --  rep:                displayname Get Custom Price
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05/07/2009    AVIH            initial build
  -----------------------------------------------------------------------

  FUNCTION get_custom_price(p_price_formula_id     IN NUMBER,
                            p_list_price           IN NUMBER,
                            p_price_effective_date IN DATE,
                            p_req_line_attrs_tbl   IN qp_formula_price_calc_pvt.req_line_attrs_tbl)
    RETURN NUMBER IS

  BEGIN

    /* FOR i IN 1 .. p_req_line_attrs_tbl.COUNT LOOP

       INSERT INTO xxobjt_test
       VALUES
          (p_req_line_attrs_tbl(i).line_index,
           p_req_line_attrs_tbl(i).attribute_type,
           p_req_line_attrs_tbl(i).CONTEXT,
           p_req_line_attrs_tbl(i).attribute,
           p_req_line_attrs_tbl(i).VALUE);

    END LOOP;*/
    RETURN 0;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_custom_price;
  --------------------------------------------------------------
  -- delete_item_price

  -- remove item from list price
  --------------------------------------------------------------

  PROCEDURE delete_item_price(p_err_code       OUT NUMBER,
                              p_err_message    OUT VARCHAR2,
                              p_list_header_id NUMBER,
                              p_list_line_id   NUMBER) IS
    gpr_return_status  VARCHAR2(1) := NULL;
    gpr_msg_count      NUMBER := 0;
    gpr_msg_data       VARCHAR2(2000);
    gpr_price_list_rec qp_price_list_pub.price_list_rec_type;
    --gpr_price_list_val_rec      qp_price_list_pub.price_list_val_rec_type;
    gpr_price_list_line_tbl qp_price_list_pub.price_list_line_tbl_type;
    --gpr_price_list_line_val_tbl qp_price_list_pub.price_list_line_val_tbl_type;
    --gpr_qualifiers_tbl          qp_qualifier_rules_pub.qualifiers_tbl_type;
    --gpr_qualifiers_val_tbl      qp_qualifier_rules_pub.qualifiers_val_tbl_type;
    gpr_pricing_attr_tbl qp_price_list_pub.pricing_attr_tbl_type;
    --gpr_pricing_attr_val_tbl    qp_price_list_pub.pricing_attr_val_tbl_type;
    ppr_price_list_rec          qp_price_list_pub.price_list_rec_type;
    ppr_price_list_val_rec      qp_price_list_pub.price_list_val_rec_type;
    ppr_price_list_line_tbl     qp_price_list_pub.price_list_line_tbl_type;
    ppr_price_list_line_val_tbl qp_price_list_pub.price_list_line_val_tbl_type;
    ppr_qualifiers_tbl          qp_qualifier_rules_pub.qualifiers_tbl_type;
    ppr_qualifiers_val_tbl      qp_qualifier_rules_pub.qualifiers_val_tbl_type;
    ppr_pricing_attr_tbl        qp_price_list_pub.pricing_attr_tbl_type;
    ppr_pricing_attr_val_tbl    qp_price_list_pub.pricing_attr_val_tbl_type;
    k                           NUMBER := 1;
    --j                           NUMBER := 1;

  BEGIN
    p_err_code := 0;
    -- INITIALIZATION REQUIRED FOR R12

    /* mo_global.set_policy_context('S', 308);
    mo_global.init('ONT');

    fnd_global.apps_initialize(user_id      => 3850,
                               resp_id      => 50766,
                               resp_appl_id => 660);*/

    k := 1; -- create the price list line rec

    gpr_price_list_line_tbl(k).list_header_id := p_list_header_id; -- Enter the list_header_id from qp_list_headers
    gpr_price_list_line_tbl(k).list_line_id := p_list_line_id;
    gpr_price_list_line_tbl(k).operation := qp_globals.g_opr_delete;

    --dbms_output.put_line('Calling qp_price_list_pub.process_price_list API to Enter Item Into Price List');
    --dbms_output.put_line('=============================================');

    qp_price_list_pub.process_price_list(p_api_version_number      => 1,
                                         p_init_msg_list           => fnd_api.g_true,
                                         p_return_values           => fnd_api.g_false,
                                         p_commit                  => fnd_api.g_false,
                                         x_return_status           => gpr_return_status,
                                         x_msg_count               => gpr_msg_count,
                                         x_msg_data                => gpr_msg_data,
                                         p_price_list_rec          => gpr_price_list_rec,
                                         p_price_list_line_tbl     => gpr_price_list_line_tbl,
                                         p_pricing_attr_tbl        => gpr_pricing_attr_tbl,
                                         x_price_list_rec          => ppr_price_list_rec,
                                         x_price_list_val_rec      => ppr_price_list_val_rec,
                                         x_price_list_line_tbl     => ppr_price_list_line_tbl,
                                         x_price_list_line_val_tbl => ppr_price_list_line_val_tbl,
                                         x_qualifiers_tbl          => ppr_qualifiers_tbl,
                                         x_qualifiers_val_tbl      => ppr_qualifiers_val_tbl,
                                         x_pricing_attr_tbl        => ppr_pricing_attr_tbl,
                                         x_pricing_attr_val_tbl    => ppr_pricing_attr_val_tbl);

    -- dbms_output.put_line('gpr_return_status=' || gpr_return_status);
    IF gpr_return_status = fnd_api.g_ret_sts_success THEN
      IF ppr_price_list_line_tbl.count > 0 THEN

        FOR k IN 1 .. ppr_price_list_line_tbl.count LOOP

          -- log('p_list_line_id=> ' || ppr_price_list_line_tbl(k).list_line_id);

          -- dbms_output.put_line('Return Status = ' ||
          --        ppr_price_list_line_tbl(k).return_status);

          --if gpr_return_status = fnd_api.g_ret_sts_success
          IF ppr_price_list_line_tbl(k)
           .return_status = fnd_api.g_ret_sts_success THEN
            --  COMMIT;
            log('The Item has been deleted successfully from price list');
          ELSE
            ROLLBACK;
            p_err_code := 1;
            log('The Item has not been deleted from  price list');
          END IF;
        END LOOP;
      END IF;
    ELSE
      FOR k IN 1 .. gpr_msg_count LOOP
        p_err_code    := 1;
        gpr_msg_data  := oe_msg_pub.get(p_msg_index => k, p_encoded => 'F');
        p_err_message := p_err_message || ' ' || gpr_msg_data;
        ROLLBACK;
      END LOOP;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := fnd_message.get || ' ' || SQLERRM;
  END;

  --------------------------------------------------------------------
  --  Name      :        insert_item_price
  --  Created By:
  --  Revision:          1.0
  --  Creation Date:
  --------------------------------------------------------------------
  --  Purpose :          Insert lines to pricelist
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0   --            --                          Initial Build
  --  1.0  04/12/2017    Diptasurjya Chatterjee       CHG0040166 - Add parameter effective date and
  --                                                  PL line will start from the effective date
  --  1.1  03/12/2018    Diptasurjya Chatterjee       CHG0042537 - Pass new parameter for precedence
  --                                                  if value is passed, then create PL line with the passed precedence
  --                                                  else use 220 as precedence
  --  1.2  29-JUL-2019   Diptasurjya chatterjee       CHG0045880 - Handle simulation approval process
  --  1.3  18-FEB-2020   Diptasurjya                  CHG0047324 - Remove all COMMIT and ROLLBACK statements. Calling procedure should handle commit or rollback
  --------------------------------------------------------------------
  PROCEDURE insert_item_price(p_err_code          OUT NUMBER,
                              p_err_message       OUT VARCHAR2,
                              p_list_line_id      OUT NUMBER,
                              p_list_header_id    NUMBER,
                              p_inventory_item_id NUMBER,
                              p_new_price         NUMBER,
                              p_effective_date    DATE, --VARCHAR2, -- CHG0045880 change to DATE
                              p_primary_uom_flag  VARCHAR2,
                              p_uom_code          VARCHAR2,
                              p_precedence        NUMBER, -- CHG0042537
                              p_simulation_name   VARCHAR2 -- CHG0045880
                              ) IS

    gpr_return_status  VARCHAR2(1) := NULL;
    gpr_msg_count      NUMBER := 0;
    gpr_msg_data       VARCHAR2(2000);
    gpr_price_list_rec qp_price_list_pub.price_list_rec_type;
    --gpr_price_list_val_rec      qp_price_list_pub.price_list_val_rec_type;
    gpr_price_list_line_tbl qp_price_list_pub.price_list_line_tbl_type;
    --gpr_price_list_line_val_tbl qp_price_list_pub.price_list_line_val_tbl_type;
    --gpr_qualifiers_tbl          qp_qualifier_rules_pub.qualifiers_tbl_type;
    --gpr_qualifiers_val_tbl      qp_qualifier_rules_pub.qualifiers_val_tbl_type;
    gpr_pricing_attr_tbl qp_price_list_pub.pricing_attr_tbl_type;
    --gpr_pricing_attr_val_tbl    qp_price_list_pub.pricing_attr_val_tbl_type;
    ppr_price_list_rec          qp_price_list_pub.price_list_rec_type;
    ppr_price_list_val_rec      qp_price_list_pub.price_list_val_rec_type;
    ppr_price_list_line_tbl     qp_price_list_pub.price_list_line_tbl_type;
    ppr_price_list_line_val_tbl qp_price_list_pub.price_list_line_val_tbl_type;
    ppr_qualifiers_tbl          qp_qualifier_rules_pub.qualifiers_tbl_type;
    ppr_qualifiers_val_tbl      qp_qualifier_rules_pub.qualifiers_val_tbl_type;
    ppr_pricing_attr_tbl        qp_price_list_pub.pricing_attr_tbl_type;
    ppr_pricing_attr_val_tbl    qp_price_list_pub.pricing_attr_val_tbl_type;
    k                           NUMBER := 1;
    j                           NUMBER := 1;

  BEGIN
    p_err_message := NULL;
    p_err_code    := 0;

    log('insert_item_price: Before calling insert API');
    -- INITIALIZATION REQUIRED FOR R12

    /* mo_global.set_policy_context('S', 308);
    mo_global.init('ONT');

    fnd_global.apps_initialize(user_id      => 3850,
                               resp_id      => 50766,
                               resp_appl_id => 660);*/

    --gpr_price_list_rec.list_header_id := 902011; -- Enter the list_header_id from qp_list_headers
    --gpr_price_list_rec.NAME := 'DENTAL CARE IL $'; -- Enter the price list name
    --gpr_price_list_rec.list_type_code := 'PRL';
    --gpr_price_list_rec.description := 'test add item'; --Enter the price list Description
    --gpr_price_list_rec.operation := qp_globals.g_opr_update;

    k := 1; -- create the price list line rec

    gpr_price_list_line_tbl(k).list_header_id := p_list_header_id; -- Enter the list_header_id from qp_list_headers
    gpr_price_list_line_tbl(k).list_line_id := fnd_api.g_miss_num;
    gpr_price_list_line_tbl(k).list_line_type_code := 'PLL';
    gpr_price_list_line_tbl(k).operation := qp_globals.g_opr_create;
    gpr_price_list_line_tbl(k).operand := p_new_price; --Enter the Unit Price
    gpr_price_list_line_tbl(k).arithmetic_operator := 'UNIT_PRICE';
    gpr_price_list_line_tbl(k).primary_uom_flag := p_primary_uom_flag;
    IF p_effective_date IS NOT NULL THEN
      -- CHG0040166
      --gpr_price_list_line_tbl(k).start_date_active := trunc(fnd_date.canonical_to_date(p_effective_date)); --CHG0045880 commented
      gpr_price_list_line_tbl(k).start_date_active := trunc(p_effective_date); -- CHG0045880 added
    ELSE
      gpr_price_list_line_tbl(k).start_date_active := trunc(SYSDATE);
    END IF; -- CHG0040166

    -- CHG0045880 - set simulation name into ATTRIBUTE5
    gpr_price_list_line_tbl(k).attribute5 := p_simulation_name;

    if p_precedence is null then
      gpr_price_list_line_tbl(k).product_precedence := 220;
    else
      gpr_price_list_line_tbl(k).product_precedence := p_precedence;
    end if;
    j := 1;

    gpr_pricing_attr_tbl(j).pricing_attribute_id := fnd_api.g_miss_num;
    gpr_pricing_attr_tbl(j).list_line_id := fnd_api.g_miss_num;
    gpr_pricing_attr_tbl(j).product_attribute_context := 'ITEM';
    gpr_pricing_attr_tbl(j).product_attribute := 'PRICING_ATTRIBUTE1';
    gpr_pricing_attr_tbl(j).product_attr_value := p_inventory_item_id; -- Enter the inventory_item_id
    gpr_pricing_attr_tbl(j).product_uom_code := p_uom_code; --get_item_uom_code(p_inventory_item_id); -- 'EA'; -- Enter the UOM
    gpr_pricing_attr_tbl(j).excluder_flag := 'N';

    gpr_pricing_attr_tbl(j).attribute_grouping_no := 1;
    gpr_pricing_attr_tbl(j).price_list_line_index := 1;
    gpr_pricing_attr_tbl(j).operation := qp_globals.g_opr_create;

    -- dbms_output.put_line('Calling qp_price_list_pub.process_price_list API to Enter Item Into Price List');
    -- dbms_output.put_line('=============================================');

    qp_price_list_pub.process_price_list(p_api_version_number      => 1,
                                         p_init_msg_list           => fnd_api.g_true,
                                         p_return_values           => fnd_api.g_false,
                                         p_commit                  => fnd_api.g_false,
                                         x_return_status           => gpr_return_status,
                                         x_msg_count               => gpr_msg_count,
                                         x_msg_data                => gpr_msg_data,
                                         p_price_list_rec          => gpr_price_list_rec,
                                         p_price_list_line_tbl     => gpr_price_list_line_tbl,
                                         p_pricing_attr_tbl        => gpr_pricing_attr_tbl,
                                         x_price_list_rec          => ppr_price_list_rec,
                                         x_price_list_val_rec      => ppr_price_list_val_rec,
                                         x_price_list_line_tbl     => ppr_price_list_line_tbl,
                                         x_price_list_line_val_tbl => ppr_price_list_line_val_tbl,
                                         x_qualifiers_tbl          => ppr_qualifiers_tbl,
                                         x_qualifiers_val_tbl      => ppr_qualifiers_val_tbl,
                                         x_pricing_attr_tbl        => ppr_pricing_attr_tbl,
                                         x_pricing_attr_val_tbl    => ppr_pricing_attr_val_tbl);

    -- dbms_output.put_line('gpr_return_status=' || gpr_return_status);
    IF gpr_return_status = fnd_api.g_ret_sts_success THEN
      log('insert_item_price: After calling insert API with SUCCESS');
      IF ppr_price_list_line_tbl.count > 0 THEN

        FOR k IN 1 .. ppr_price_list_line_tbl.count LOOP
          p_list_line_id := ppr_price_list_line_tbl(k).list_line_id;
          -- log('p_list_line_id=> ' || ppr_price_list_line_tbl(k).list_line_id);

          --  dbms_output.put_line('Return Status = ' ||
          --           ppr_price_list_line_tbl(k).return_status);

          --if gpr_return_status = fnd_api.g_ret_sts_success
          IF ppr_price_list_line_tbl(k).return_status = fnd_api.g_ret_sts_success THEN
            --COMMIT;  --CHG0047324 comment
            log('The Item has been successfully loaded into the price list');
            p_err_message := 'Item successfully loaded into Pricelist';
          ELSE
            --ROLLBACK;  --CHG0047324 comment
            p_err_code := 1;
            log('The Item has not been loaded into the price list');
          END IF;
        END LOOP;
      END IF;
    ELSE
      p_err_code := 1;
      FOR k IN 1 .. gpr_msg_count LOOP

        gpr_msg_data  := oe_msg_pub.get(p_msg_index => k, p_encoded => 'F');
        p_err_message := p_err_message || ' ' || gpr_msg_data;
        --ROLLBACK;  --CHG0047324 comment
      END LOOP;

      log('insert_item_price: After calling insert API with ERROR: '||p_err_message);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := p_err_message || ' ' || SQLERRM;
  END;

  --------------------------------------------------------------
  -- update_item_price
  --------------------------------------------------------------
  --  1.0   19/08/2014    Yuval tal       CHG0032089 : close current record instead of override
  --                                      and create new line in pl
  --                                      p_correction_mode N override Y close current line and create new one
  --  1.1   25/04/2017    Diptasurjya     CHG0040166 - Add new parameter effective date.
  --                                      Updated price will be effective from effective date
  --  1.2   03/14/2018    Diptasurjya     CHG0042537 - Handle precedence
  --  1.3   29-JUL-2019   Diptasurjya     CHG0045880 - Update simulation name into PL line DFF
  --  1.4   18-FEB-2020   Diptasurjya     CHG0047324 - Remove all COMMIT and ROLLBACK statements. Calling procedure should handle commit or rollback
  --------------------------------------------------------------

  PROCEDURE update_item_price(p_err_code          OUT NUMBER,
                              p_err_message       OUT VARCHAR2,
                              p_list_header_id    NUMBER,
                              p_list_line_id      NUMBER,
                              p_inventory_item_id NUMBER,
                              p_new_price         NUMBER,
                              p_end_date_active   DATE DEFAULT SYSDATE,
                              p_correction_mode   VARCHAR2,
                              p_effective_date    DATE, --VARCHAR2, -- CHG0045880 change to DATE
                              p_primary_uom_flag  VARCHAR2,
                              p_uom_code          VARCHAR2,
                              p_precedence        number, -- CHG0042537
                              p_simulation_name   varchar2, -- CHG0045880
                              x_list_line_id      OUT NUMBER) IS

    gpr_return_status  VARCHAR2(1) := NULL;
    gpr_msg_count      NUMBER := 0;
    gpr_msg_data       VARCHAR2(2000);
    gpr_price_list_rec qp_price_list_pub.price_list_rec_type;
    --gpr_price_list_val_rec      qp_price_list_pub.price_list_val_rec_type;
    gpr_price_list_line_tbl qp_price_list_pub.price_list_line_tbl_type;
    --gpr_price_list_line_val_tbl qp_price_list_pub.price_list_line_val_tbl_type;
    --gpr_qualifiers_tbl          qp_qualifier_rules_pub.qualifiers_tbl_type;
    --gpr_qualifiers_val_tbl      qp_qualifier_rules_pub.qualifiers_val_tbl_type;
    gpr_pricing_attr_tbl qp_price_list_pub.pricing_attr_tbl_type;
    --gpr_pricing_attr_val_tbl    qp_price_list_pub.pricing_attr_val_tbl_type;
    ppr_price_list_rec          qp_price_list_pub.price_list_rec_type;
    ppr_price_list_val_rec      qp_price_list_pub.price_list_val_rec_type;
    ppr_price_list_line_tbl     qp_price_list_pub.price_list_line_tbl_type;
    ppr_price_list_line_val_tbl qp_price_list_pub.price_list_line_val_tbl_type;
    ppr_qualifiers_tbl          qp_qualifier_rules_pub.qualifiers_tbl_type;
    ppr_qualifiers_val_tbl      qp_qualifier_rules_pub.qualifiers_val_tbl_type;
    ppr_pricing_attr_tbl        qp_price_list_pub.pricing_attr_tbl_type;
    ppr_pricing_attr_val_tbl    qp_price_list_pub.pricing_attr_val_tbl_type;
    k                           NUMBER := 1;

  BEGIN
    p_err_code := 0;

    --  mo_global.set_policy_context('S', 308);
    --  mo_global.init('ONT');

    /* fnd_global.apps_initialize(user_id      => 3850,
    resp_id      => 50766,
    resp_appl_id => 660);*/

    -- gpr_price_list_rec.list_header_id := p_list_header_id; -- Enter the list_header_id from qp_list_headers
    -- gpr_price_list_rec.NAME           := 'DENTAL CARE IL $'; -- Enter the price list name
    --  gpr_price_list_rec.list_type_code := 'PRL';
    --  gpr_price_list_rec.description    := 'test add item'; --Enter the price list Description
    -- gpr_price_list_rec.operation      := qp_globals.g_opr_update;

    -- close record

    k := 1; -- create the price list line rec

    gpr_price_list_line_tbl(k).list_header_id := p_list_header_id; -- Enter the list_header_id from qp_list_headers
    gpr_price_list_line_tbl(k).list_line_id := p_list_line_id; --fnd_api.g_miss_num;
    gpr_price_list_line_tbl(k).list_line_type_code := 'PLL';
    --gpr_price_list_line_tbl(k).end_date_active := p_start;
    gpr_price_list_line_tbl(k).operation := qp_globals.g_opr_update;
    IF p_correction_mode = 'N' THEN
      gpr_price_list_line_tbl(k).end_date_active := p_end_date_active;
    ELSE
      gpr_price_list_line_tbl(k).operand := p_new_price; --Enter the Unit Price CHG0032089
      gpr_price_list_line_tbl(k).primary_uom_flag := p_primary_uom_flag;
      -- CHG0045880 - set simulation name into ATTRIBUTE5
      gpr_price_list_line_tbl(k).attribute5 := p_simulation_name;
    END IF;
    --
    gpr_price_list_line_tbl(k).arithmetic_operator := 'UNIT_PRICE';

    log('update_item_price: Before calling API to update PL line');

    qp_price_list_pub.process_price_list(p_api_version_number      => 1,
                                         p_init_msg_list           => fnd_api.g_true,
                                         p_return_values           => fnd_api.g_false,
                                         p_commit                  => fnd_api.g_false,
                                         x_return_status           => gpr_return_status,
                                         x_msg_count               => gpr_msg_count,
                                         x_msg_data                => gpr_msg_data,
                                         p_price_list_rec          => gpr_price_list_rec,
                                         p_price_list_line_tbl     => gpr_price_list_line_tbl,
                                         p_pricing_attr_tbl        => gpr_pricing_attr_tbl,
                                         x_price_list_rec          => ppr_price_list_rec,
                                         x_price_list_val_rec      => ppr_price_list_val_rec,
                                         x_price_list_line_tbl     => ppr_price_list_line_tbl,
                                         x_price_list_line_val_tbl => ppr_price_list_line_val_tbl,
                                         x_qualifiers_tbl          => ppr_qualifiers_tbl,
                                         x_qualifiers_val_tbl      => ppr_qualifiers_val_tbl,
                                         x_pricing_attr_tbl        => ppr_pricing_attr_tbl,
                                         x_pricing_attr_val_tbl    => ppr_pricing_attr_val_tbl);

    IF gpr_return_status = fnd_api.g_ret_sts_success THEN
      log('update_item_price: After calling update API with SUCCESS');
      -- create new line in price list
      IF p_correction_mode = 'N' THEN
        log('update_item_price: Before calling insert API');
        insert_item_price(p_err_code,
                          p_err_message,
                          x_list_line_id,
                          p_list_header_id,
                          p_inventory_item_id,
                          p_new_price,
                          p_effective_date,
                          p_primary_uom_flag,
                          p_uom_code,
                          p_precedence, -- CHG0042537
                          p_simulation_name); -- CHG0045880 added

        log('update_item_price: After calling insert API');
        IF p_err_code = 1 THEN
          --ROLLBACK;  --CHG0047324 comment
          RETURN;
        END IF;
      END IF;
      p_err_message := 'Price List successfully updated';
      ----
    ELSE
      log('update_item_price: After calling update API with ERROR');
      p_err_code := 1;

      /*IF ppr_price_list_line_tbl.count > 0 THEN

        FOR k IN 1 .. ppr_price_list_line_tbl.count LOOP

          IF ppr_price_list_line_tbl(k)
           .return_status = fnd_api.g_ret_sts_success THEN
            COMMIT;
            --  dbms_output.put_line('The Item has been successfully loaded into the price list');
          ELSE
            ROLLBACK;
            --  dbms_output.put_line('The Item has not been loaded into the price list');
          END IF;
        END LOOP;
      END IF;*/ -- --CHG0047324 comment wrong code

      FOR k IN 1 .. gpr_msg_count LOOP

        gpr_msg_data  := oe_msg_pub.get(p_msg_index => k, p_encoded => 'F');
        p_err_message := p_err_message || ' ' || gpr_msg_data;

      END LOOP;

      log('update_item_price: Update API error: '||p_err_message);

      --ROLLBACK;  --CHG0047324 comment
    END IF;
  END;

  --------------------------------------------------------------------
  --  Name      :        close_item_price
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     04/12/2017
  --------------------------------------------------------------------
  --  Purpose :          CHG0040166 - This procedure will be used to
  --                     close pricelist lines
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  04/12/2017    Diptasurjya Chatterjee       Initial Build
  --------------------------------------------------------------------
  PROCEDURE close_item_price(p_err_code        OUT NUMBER,
                             p_err_message     OUT VARCHAR2,
                             p_list_header_id  NUMBER,
                             p_list_line_id    NUMBER,
                             p_end_date_active DATE DEFAULT SYSDATE,
                             x_list_line_id    OUT NUMBER) IS

    gpr_return_status  VARCHAR2(1) := NULL;
    gpr_msg_count      NUMBER := 0;
    gpr_msg_data       VARCHAR2(2000);
    gpr_price_list_rec qp_price_list_pub.price_list_rec_type;
    --gpr_price_list_val_rec      qp_price_list_pub.price_list_val_rec_type;
    gpr_price_list_line_tbl qp_price_list_pub.price_list_line_tbl_type;
    --gpr_price_list_line_val_tbl qp_price_list_pub.price_list_line_val_tbl_type;
    --gpr_qualifiers_tbl          qp_qualifier_rules_pub.qualifiers_tbl_type;
    --gpr_qualifiers_val_tbl      qp_qualifier_rules_pub.qualifiers_val_tbl_type;
    gpr_pricing_attr_tbl qp_price_list_pub.pricing_attr_tbl_type;
    --gpr_pricing_attr_val_tbl    qp_price_list_pub.pricing_attr_val_tbl_type;
    ppr_price_list_rec          qp_price_list_pub.price_list_rec_type;
    ppr_price_list_val_rec      qp_price_list_pub.price_list_val_rec_type;
    ppr_price_list_line_tbl     qp_price_list_pub.price_list_line_tbl_type;
    ppr_price_list_line_val_tbl qp_price_list_pub.price_list_line_val_tbl_type;
    ppr_qualifiers_tbl          qp_qualifier_rules_pub.qualifiers_tbl_type;
    ppr_qualifiers_val_tbl      qp_qualifier_rules_pub.qualifiers_val_tbl_type;
    ppr_pricing_attr_tbl        qp_price_list_pub.pricing_attr_tbl_type;
    ppr_pricing_attr_val_tbl    qp_price_list_pub.pricing_attr_val_tbl_type;
    k                           NUMBER := 1;

  BEGIN
    p_err_code := 0;

    k := 1; -- create the price list line rec

    gpr_price_list_line_tbl(k).list_header_id := p_list_header_id; -- Enter the list_header_id from qp_list_headers
    gpr_price_list_line_tbl(k).list_line_id := p_list_line_id; --fnd_api.g_miss_num;
    gpr_price_list_line_tbl(k).list_line_type_code := 'PLL';
    gpr_price_list_line_tbl(k).operation := qp_globals.g_opr_update;

    gpr_price_list_line_tbl(k).end_date_active := p_end_date_active;
    --

    qp_price_list_pub.process_price_list(p_api_version_number      => 1,
                                         p_init_msg_list           => fnd_api.g_true,
                                         p_return_values           => fnd_api.g_false,
                                         p_commit                  => fnd_api.g_false,
                                         x_return_status           => gpr_return_status,
                                         x_msg_count               => gpr_msg_count,
                                         x_msg_data                => gpr_msg_data,
                                         p_price_list_rec          => gpr_price_list_rec,
                                         p_price_list_line_tbl     => gpr_price_list_line_tbl,
                                         p_pricing_attr_tbl        => gpr_pricing_attr_tbl,
                                         x_price_list_rec          => ppr_price_list_rec,
                                         x_price_list_val_rec      => ppr_price_list_val_rec,
                                         x_price_list_line_tbl     => ppr_price_list_line_tbl,
                                         x_price_list_line_val_tbl => ppr_price_list_line_val_tbl,
                                         x_qualifiers_tbl          => ppr_qualifiers_tbl,
                                         x_qualifiers_val_tbl      => ppr_qualifiers_val_tbl,
                                         x_pricing_attr_tbl        => ppr_pricing_attr_tbl,
                                         x_pricing_attr_val_tbl    => ppr_pricing_attr_val_tbl);

    IF gpr_return_status = fnd_api.g_ret_sts_success THEN
      p_err_message := 'Price List line closed successfully';
      COMMIT;
      ----
    ELSE
      p_err_code := 1;

      IF ppr_price_list_line_tbl.count > 0 THEN

        FOR k IN 1 .. ppr_price_list_line_tbl.count LOOP
          IF ppr_price_list_line_tbl(k)
           .return_status = fnd_api.g_ret_sts_success THEN
            COMMIT;
            --  dbms_output.put_line('The Item has been successfully loaded into the price list');
          ELSE
            ROLLBACK;
            --  dbms_output.put_line('The Item has not been loaded into the price list');
          END IF;
        END LOOP;
      END IF;

      FOR k IN 1 .. gpr_msg_count LOOP

        gpr_msg_data  := oe_msg_pub.get(p_msg_index => k, p_encoded => 'F');
        p_err_message := p_err_message || ' ' || gpr_msg_data;

      END LOOP;
      --log('Close API message: '||p_err_message);
      ROLLBACK;
    END IF;
  END close_item_price;

  -------------------------------------------------------------
  -- update_pl
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19.8.14      yuval tal        CHG0032089 - change logic for supporting new price maipulation
  --  1.1   25/04/2017   Diptasurjya      CHG0040166 - Add new parameters
  --                                                   p_effective_date
  --  1.2   03/14/2018   Diptasurjya      CHG0042537 - Handle precedence
  --  1.3   16-JUL-2019  Diptasurjya      CHG0045880 - Handle simulation ID
  --  1.4   23-JAN-2020  Diptasurjya      CHG0047324 - Insert Product precedence from rule header into PL simulation table
  ---------------------------------------------------------------

  PROCEDURE update_pl(errbuf           OUT VARCHAR2,
                      retcode          OUT VARCHAR2,
                      --p_test_mode      VARCHAR2 DEFAULT 'Y', -- CHG0045880 commented
                      --p_source         VARCHAR2,  -- CHG0045880 commented
                      p_list_header_id NUMBER,
                      p_item_code      VARCHAR2,
                      --p_effective_date VARCHAR2,  -- CHG0045880 commented
                      p_simulation_id  NUMBER) IS -- CHG0045880

    -- l_err_code    NUMBER;
    --l_err_message VARCHAR2(500);

    l_request_id        NUMBER;
    l_curr_price        NUMBER;
    l_out_item_valid    NUMBER;
    l_out_actual_factor NUMBER;
    l_out_traget_price  NUMBER;
    l_out_new_price     NUMBER;

    l_exclusion_exists VARCHAR2(1); -- CHG0040166
    l_exclude          VARCHAR2(1); -- CHG0040166

    l_out_err_code    NUMBER;
    l_out_err_mesg    VARCHAR2(2000);
    l_out_upd_err_msg VARCHAR2(2000);
    l_out_new_line_id NUMBER;

    l_correction_mode VARCHAR2(1);
    l_end_date_active DATE;

    --l_primary_uom_flag VARCHAR2(1); -- CHG0040166  -- CHG0045880 commented
    --l_product_uom      VARCHAR2(3); -- CHG0040166  -- CHG0045880 commented

    l_api_eligible     varchar2(200); -- CHG0045880
    p_test_mode varchar2(1) := 'Y';  -- CHG0045880 added

    CURSOR c_pl_list(c_list_header_id NUMBER/*, c_source VARCHAR2*/) IS -- CHG0045880 comment p_source
      SELECT *
        FROM xxom_pl_upd_rule_header t
       WHERE t.pl_active = 'Y'
         --AND t.source_code = nvl(c_source, t.source_code)  -- CHG0045880 comment
         AND t.list_header_id = nvl(c_list_header_id, t.list_header_id)
         AND fnd_profile.value('XXOM_ENABLE_PL_MASS_UPDATE') = 'Y'  -- CHG0045880 added
         /*AND (fnd_profile.value('XXOM_ENABLE_PL_MASS_UPDATE') = 'ALL' OR
             t.source_code =
             fnd_profile.value('XXOM_ENABLE_PL_MASS_UPDATE'))*/ -- CHG0045880 comment
       ORDER BY t.seq_num;


  BEGIN
    log('--------------------------------------------');
    log('Update PL lines.....');
    log('--------------------------------------------');
    log('p_test_mode      : ' || 'Y');
    --log('p_source         : ' || p_source); -- CHG0045880 comment
    log('p_list_header_id : ' || to_char(p_list_header_id));
    log('p_item_code      : ' || p_item_code);

    log('Running in Test mode =' || p_test_mode);
    l_request_id := fnd_global.conc_request_id;
    retcode      := 0;

    -- If not not test mode then check simulation was done before ----------
    -- CHG0040166 - Commented by Dipta as required by Ginat
    /*IF p_test_mode = 'N' THEN
      check_simulation_done(errbuf,
        retcode,
        p_source,
        p_list_header_id,
        p_item_code);
      IF retcode = 1 THEN
        RETURN;
      END IF;

    END IF;*/

    errbuf := NULL;
    -------------- start getting list price to update --------
    -- look for all rules for update

    FOR i IN c_pl_list(p_list_header_id/*, p_source*/) LOOP  -- CHG0045880 comment p_source
      -- CHG0045880 comment below
      /*IF p_test_mode = 'Y' THEN
        INSERT INTO xxom_pl_upd_simulation_arc
          SELECT *
            FROM xxom_pl_upd_simulation sim
           WHERE sim.list_header_id = i.list_header_id
             AND sim.source_code = i.source_code
             AND sim.rule_id = i.rule_id
             AND sim.save_ind = 'N'
             AND sim.new_item_flag IS NULL
             AND sim.item_code = nvl(p_item_code, item_code);

        DELETE FROM xxom_pl_upd_simulation sim
         WHERE sim.list_header_id = i.list_header_id
           AND sim.source_code = i.source_code
           AND sim.rule_id = i.rule_id
           AND sim.save_ind = 'N'
           AND sim.new_item_flag IS NULL
           AND sim.item_code = nvl(p_item_code, item_code);

        COMMIT;
      END IF;*/

      log('----------------------------------------------------------- ');
      log('Start update price list ' ||
          get_price_list_name(i.list_header_id));
      log('Change method=' || i.change_method);
      log('Master PL=' || get_price_list_name(i.master_list_header_id));

      log('Change type=' || i.change_type);
      log('----------------------------------------------------------- ');

      log(rpad('Item Code', 20, ' ') /*|| rpad('Rule_value', 20, ' ') ||*/
          || rpad('Old Price', 20, ' ') || rpad('New Price', 20, ' ')
          /*||rpad('Category', 20, ' ') || rpad('Product', 20, ' '*/);

      -- check each item
      FOR c IN c_cs_pl_items_upd(i.rule_id,
                                 p_item_code) LOOP  -- CHG0045880 no date and master PL to be sent

        l_curr_price := c.cur_price;

        -- CHG0040166 - Start
        l_exclusion_exists  := NULL;
        l_out_actual_factor := NULL;
        l_out_err_code      := NULL;
        l_out_new_price     := NULL;
        l_out_item_valid    := NULL;
        --l_primary_uom_flag  := NULL;  -- CHG0045880 commented
        l_api_eligible      := null;  -- CHG0045880 add

        handle_exclusion(c.inventory_item_id,
                         i.rule_id,
                         l_out_item_valid,
                         l_out_actual_factor,
                         l_out_traget_price,
                         l_out_new_price,
                         l_exclusion_exists,
                         l_exclude,
                         l_out_err_code,
                         l_out_err_mesg);

        IF nvl(l_exclusion_exists, 'N') = 'N' THEN
          -- CHG0040166 - End
          handle_item(c.inventory_item_id,
                      i.rule_id, -- CHG0040166
                      l_curr_price,
                      l_out_item_valid,
                      l_out_actual_factor,
                      l_out_traget_price,
                      l_out_new_price,
                      l_out_err_code,
                      l_out_err_mesg);

          --log('Price returned: '||l_out_new_price);
          --log('Error code returned: '||l_out_err_code);
        END IF; -- CHG0040166

        log('Err Code: ' || l_out_err_code);

        -- CHG0045880 - comment below
        /*IF l_out_err_code = 0 THEN
          log('In if: ' ||
              trunc(p_effective_date) || ' ' ||
              trunc(c.start_date_active));
          IF p_test_mode = 'N' AND l_out_err_code = 0 AND
             l_out_new_price IS NOT NULL AND
             (l_out_new_price != c.cur_price OR
             trunc(c.start_date_active) <>
             trunc(p_effective_date)) AND
             l_out_item_valid = 1 THEN

            -- update price
            l_out_new_line_id := NULL;
            IF c.start_date_active = trunc(SYSDATE) AND
               p_effective_date IS NULL THEN
              l_correction_mode := 'Y';
              l_end_date_active := NULL;
            ELSE
              l_correction_mode := 'N';
              -- CHG0040166 - Start
              IF p_effective_date IS NOT NULL THEN
                l_end_date_active := trunc(p_effective_date) - 1;
              ELSE
                -- CHG0040166 - End
                l_end_date_active := greatest(nvl(c.start_date_active,
                                                  trunc(SYSDATE - 1)),
                                              trunc(SYSDATE - 1));
              END IF; -- CHG0040166

            END IF;

            l_primary_uom_flag := get_master_prim_uom(i.rule_id,
                                                      c.inventory_item_id); -- CHG0040166

            l_product_uom := get_master_uom(i.rule_id, c.inventory_item_id); -- CHG0040166


            update_item_price(l_out_err_code,
                              l_out_upd_err_msg,
                              i.list_header_id,
                              c.list_line_id,
                              c.inventory_item_id,
                              l_out_new_price,
                              l_end_date_active,
                              l_correction_mode, -- correction_mode
                              p_effective_date, -- CHG0040166
                              l_primary_uom_flag, -- CHG0040166
                              l_product_uom, -- CHG0040166
                              i.product_precedence, -- CHG0042537
                              l_out_new_line_id);

            l_out_err_mesg := l_out_err_mesg || ' ' || l_out_upd_err_msg ||
                              ' Correction Mode=' || l_correction_mode;
          END IF;
        END IF;*/

        log('all vals: '||l_out_item_valid||' '||l_out_err_code);
        -- log
        IF l_out_item_valid = 1 OR l_out_err_code = 1 THEN
          log(rpad(c.segment1, 20, ' ') || ' ' || l_out_err_code ||
              rpad(l_curr_price, 20, ' ') ||
              rpad(nvl(to_char(l_out_new_price), ' '), 20, ' ')

              );

          if l_out_err_code = 0 AND
             l_out_new_price IS NOT NULL AND
             l_out_new_price != c.cur_price
             /*(l_out_new_price != c.cur_price OR
             trunc(c.start_date_active) <> trunc(p_effective_date))*/ AND
             l_out_item_valid = 1 then
            l_api_eligible := 'UPDATE';
          end if;

          INSERT INTO xxom_pl_upd_simulation
            (--source_code, -- CHG0045880 commented
             list_header_id,
             list_header_name,
             change_method,
             change_type,
             master_list_header_id,
             master_list_header_name,
             rule_id,
             -- product_type,
             -- category_code,
             item_code,
             old_price,
             new_price,
             rule_value,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             last_update_login,
             err_msg,
             save_ind,
             request_id,
             list_line_id,
             inventory_item_id,
             master_price,
             seq_num,
             err_flag,
             excluded_flag, -- CHG0040166
             fixed_price,   -- CHG0040166
             simulation_id,  -- CHG0045880
             api_eligible,  -- CHG0045880
             product_precedence) -- CHG0047324 add
          VALUES
            (--i.source_code,  -- CHG0045880 commented
             i.list_header_id,
             get_price_list_name(i.list_header_id),
             i.change_method,
             i.change_type,
             i.master_list_header_id,
             get_price_list_name(i.master_list_header_id),
             i.rule_id,
             -- c.product_type,
             --  c.category_code, --category_code,
             c.segment1, --item_code,
             /*c.operand*/
             l_curr_price, --old_price,
             l_out_new_price, --new_price,
             round(l_out_actual_factor, 2), -- CHG0040166
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.user_id,
             fnd_global.login_id,
             l_out_err_mesg,
             decode(p_test_mode, 'Y', 'N', 'Y'),
             l_request_id,
             c.list_line_id,
             c.inventory_item_id,
             l_out_traget_price,
             i.seq_num,
             l_out_err_code,
             nvl(l_exclude, 'N'), -- CHG0040166
             decode(nvl(l_exclusion_exists, 'N'),
                    'N',
                    NULL,
                    decode(l_exclude, 'N', l_out_new_price, NULL)), -- CHG0040166
             p_simulation_id, -- CHG0045880
             l_api_eligible,  -- CHG0045880
             i.product_precedence); -- CHG0047324 add

        END IF;
        COMMIT;
      END LOOP;
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Program finished with Errors ' || SQLERRM;
  END;

  ------------------------------------------------
  -- get_price_list_name
  ------------------------------------------------

  FUNCTION get_price_list_name(p_list_header_id NUMBER) RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT t.name --, spl.list_type_code, spl.currency_code
        FROM qp_list_headers_tl t, qp_list_headers_b spl
       WHERE t.list_header_id = spl.list_header_id
         AND spl.list_header_id = p_list_header_id
         AND t.language = userenv('LANG');

    l_tmp VARCHAR2(100);
  BEGIN
    IF p_list_header_id IS NULL THEN
      RETURN NULL;
    END IF;
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;

    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ------------------------------------------------
  -- rollabck price_list
  ------------------------------------------------
  --  Ver  Date          Name            Desc
  --  1.0                                Initial Build
  --  1.1  25/04/2017    Diptasurjya     CHG0040166 - Add parameter to update_item_price call
  --  1.2  29-JUL-2019   Diptasurjya     CHG0045880 - obsoleted
  ------------------------------------------------

  /*PROCEDURE rollback_price_list(errbuf       OUT VARCHAR2,
                                retcode      OUT VARCHAR2,
                                p_request_id NUMBER) IS
    CURSOR c_req IS
      SELECT *
        FROM xxom_pl_upd_simulation t
       WHERE t.request_id = p_request_id
         AND t.save_ind = 'Y'

       ORDER BY t.seq_num DESC;

    l_err_code        NUMBER;
    l_err_message     VARCHAR2(500);
    l_request_id      NUMBER := to_number(to_char(SYSDATE, 'yyyymmddhh24mi'));
    l_out_new_line_id NUMBER;
  BEGIN

    retcode := 0;

    \* mo_global.set_policy_context('S', 308);
    mo_global.init('ONT');

    fnd_global.apps_initialize(user_id      => 3850,
                               resp_id      => 50766,
                               resp_appl_id => 660);*\

    --SELECT xxom_pl_upd_simulation_seq.NEXTVAL INTO l_request_id FROM dual;

    FOR i IN c_req LOOP
      l_err_code    := 0;
      l_err_message := NULL;
      IF nvl(i.new_item_flag, 'N') = 'N' THEN
        IF i.old_price != i.new_price THEN
          update_item_price(l_err_code,
                            l_err_message,
                            i.list_header_id,
                            i.list_line_id,
                            i.inventory_item_id,
                            i.old_price,
                            SYSDATE,
                            'Y', -- correction mode
                            NULL, -- CHG0040166
                            NULL,
                            NULL,
                            null,
                            l_out_new_line_id);
        ELSE

          l_err_message := 'Ignore : Old Price equal New Price';
        END IF;

        IF l_err_code = 1 THEN
          retcode := 1;

        END IF;

      ELSE
        -- REMOVE ITEM

        delete_item_price(l_err_code,
                          l_err_message,
                          i.list_header_id,
                          i.list_line_id);

        IF l_err_code = 1 THEN
          retcode := 1;

        END IF;

      END IF;

      INSERT INTO xxom_pl_upd_simulation
        (source_code,
         list_header_id,
         list_header_name,
         change_method,
         change_type,
         master_list_header_id,
         master_list_header_name,
         rule_id,
         product_type,
         category_code,
         item_code,
         old_price,
         new_price,
         rule_value,
         last_update_date,
         last_updated_by,
         creation_date,
         created_by,
         last_update_login,
         err_msg,
         err_flag,
         save_ind,
         request_id,
         list_line_id,
         inventory_item_id,
         new_item_flag)
      VALUES
        (i.source_code,
         i.list_header_id,
         get_price_list_name(i.list_header_id),
         NULL, --i.change_method,
         NULL, --i.change_type,
         i.master_list_header_id,
         get_price_list_name(i.master_list_header_id),
         i.rule_id,
         NULL, --c.product_type,
         NULL, --c.category_code, --category_code,
         i.item_code, --item_code,
         NULL, --c.operand, --old_price,
         i.old_price, --new_price,
         NULL, --c.rule_value, --rule_value,
         SYSDATE,
         fnd_global.user_id,
         SYSDATE,
         fnd_global.user_id,
         fnd_global.login_id,
         'Rollback  to request id=' || p_request_id || ' ' || l_err_message,
         l_err_code,
         'Y',
         l_request_id,
         i.list_line_id,
         i.inventory_item_id,
         'N');

      COMMIT;

    END LOOP;

    IF retcode = 1 THEN

      errbuf := 'Program finished with Errors , Please see Output Log , Request Id=' ||
                l_request_id;
    ELSE
      errbuf := 'Program finished, Please see Output Log , Request Id=' ||
                l_request_id;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Error: ' || SQLERRM;
      retcode := 1;
  END;*/
  --------------------------------------------------------------
  -- add_price_list_lines
  --------------------------------------------------------------
  --  ver   date          name                      desc
  --  1.0   19.8.14      yuval tal                  CHG0032089 - change logic for supporting new price maipulation
  --  1.1   28.1.16      yuval tal                  INC0056947- performence change cursor c_add ( use with )
  --  1.2   04/12/2017    Diptasurjya Chatterjee    CHG0040166 - Added new parameter p_effective_date which will add the
  --                                                PL line effective from that date
  --  1.3   03/12/2018   Diptasurjya Chatterjee     CHG0042537 - Pass precedence value if any from rule header
  --                                                during PL line creation
  --  1.4   16-JUL-2019  Diptasurjya                CHG0045880 - Handle simulation ID
  --  1.5   23-JAN-2020  Diptasurjya                CHG0047324 - Insert Product precedence from rule header into PL simulation table
  ---------------------------------------------------------------
  PROCEDURE add_price_list_lines(errbuf           OUT VARCHAR2,
                                 retcode          OUT VARCHAR2,
                                 --p_test_mode      VARCHAR2 DEFAULT 'Y',  -- CHG0045880 commented
                                 --p_source         VARCHAR2,  -- CHG0045880 comment
                                 p_list_header_id NUMBER,
                                 p_item_code      VARCHAR2,
                                 --p_effective_date VARCHAR2,  -- CHG0045880 commented
                                 p_simulation_id  number) IS  -- CHG0045880 add

    l_list_line_id NUMBER;

    l_out_item_valid NUMBER;

    l_out_actual_factor NUMBER;
    l_out_traget_price  NUMBER;
    l_out_new_price     NUMBER;
    l_out_err_code      NUMBER;
    l_out_err_mesg      VARCHAR2(2000);
    l_out_ins_err_mesg  VARCHAR2(2000);

    l_exclusion_exists VARCHAR2(1); -- CHG0040166
    l_exclude          VARCHAR2(1); -- CHG0040166
    --l_primary_uom_flag VARCHAR2(1); -- CHG0040166  -- CHG0045880 commented
    --l_product_uom      VARCHAR2(3); -- CHG0040166  -- CHG0045880 commented

    l_api_eligible     varchar2(200); -- CHG0045880
    p_test_mode varchar2(1) := 'Y';  -- CHG0045880 added

    l_curr_price NUMBER;
    CURSOR c_pl IS
      SELECT *
        FROM xxom_pl_upd_rule_header h
       WHERE /*h.source_code = p_source  -- CHG0045880 comment
         AND*/ h.list_header_id = nvl(p_list_header_id, h.list_header_id)
         AND h.pl_active = 'Y';

    CURSOR c_add(c_master_header_list_id NUMBER,
                 c_list_header_id        NUMBER,
                 c_rule_id               NUMBER,
                 l_change_method         VARCHAR2) IS
      WITH item_tab AS
       (SELECT t.product_attr_value
          FROM qp_list_lines_v t
         WHERE trunc(SYSDATE) BETWEEN nvl(t.start_date_active, SYSDATE - 1) AND
               nvl(t.end_date_active, SYSDATE + 1)
           AND t.list_header_id = c_master_header_list_id
           AND t.product_attribute = 'PRICING_ATTRIBUTE1'
        MINUS
        SELECT t.product_attr_value
          FROM qp_list_lines_v t
         WHERE /*(trunc(nvl(fnd_date.canonical_to_date(p_effective_date),sysdate)) BETWEEN nvl(t.start_date_active, to_date('01-JAN-1900','dd-MON-rrrr')) AND
                                     nvl(t.end_date_active, to_date('01-JAN-9999','dd-MON-rrrr'))
                                        or*/
         t.end_date_active IS NULL --)
      AND t.list_header_id = c_list_header_id
      AND t.product_attribute = 'PRICING_ATTRIBUTE1')
      SELECT msi.inventory_item_id,
             msi.segment1,
             qll.operand cur_price,
             h.master_list_header_id,
             h.product_precedence  -- CHG0047324
        FROM qp_list_lines_v         qll,
             xxom_pl_upd_rule_header h,
             mtl_system_items_b      msi,
             item_tab
       WHERE h.rule_id = c_rule_id
         AND trunc(SYSDATE) BETWEEN nvl(qll.start_date_active, SYSDATE - 1) AND
             nvl(qll.end_date_active, SYSDATE + 1)
         AND qll.list_header_id =
             nvl(h.master_list_header_id, qll.list_header_id)
         AND to_char(msi.inventory_item_id) = qll.product_attr_value
         AND msi.segment1 = nvl(p_item_code, msi.segment1)
         AND msi.organization_id = 91
            ---> COST - Start
         AND ((l_change_method = 'COST' AND
             xxinv_utils_pkg.get_item_cost(msi.inventory_item_id, 735) > 0 AND
             nvl(msi.attribute24, 'Y') = 'Y')

             OR (l_change_method != 'COST'))
         AND qll.product_attr_value = item_tab.product_attr_value;

  BEGIN
    errbuf  := NULL;
    retcode := 0;

    log('--------------------------------------------');
    log('Add lines.....');
    log('--------------------------------------------');
    log('Running in Test mode =' || p_test_mode);
    FOR i IN c_pl LOOP



      log('----------------------------------------------------------- ');
      log('Price List : ' || get_price_list_name(i.list_header_id));
      log('Change method=' || i.change_method);
      log('Change type=' || i.change_type);
      log('rule_id=' || i.rule_id);
      log('list_header_id=' || i.list_header_id);
      log('master_list_header_id=' || i.master_list_header_id);
      log('p_item_code      : ' || p_item_code);
      log('----------------------------------------------------------- ');

      log(rpad('Item Code', 20, ' ') || rpad('Old Price', 20, ' ') ||
          rpad('New Price', 20, ' '));

      FOR j IN c_add(i.master_list_header_id,
                     i.list_header_id,
                     i.rule_id,
                     i.change_method) LOOP

        l_curr_price := j.cur_price;

        -- CHG0040166 - Start
        l_exclusion_exists  := NULL;
        l_out_actual_factor := NULL;
        l_out_err_code      := NULL;
        l_out_new_price     := NULL;
        l_out_item_valid    := NULL;
        --l_primary_uom_flag  := NULL;  -- CHG0045880 commented
        l_api_eligible      := null; -- CHG0045880 add

        handle_exclusion(j.inventory_item_id,
                         i.rule_id,
                         l_out_item_valid,
                         l_out_actual_factor,
                         l_out_traget_price,
                         l_out_new_price,
                         l_exclusion_exists,
                         l_exclude,
                         l_out_err_code,
                         l_out_err_mesg);

        log('Exclusion exists: z' || l_exclusion_exists || 'z z' ||
            l_out_item_valid || 'z z' || l_exclude || 'z');

        IF nvl(l_exclusion_exists, 'N') = 'N' THEN
          -- CHG0040166 - End
          handle_item(j.inventory_item_id,
                      i.rule_id,
                      l_curr_price,
                      l_out_item_valid,
                      l_out_actual_factor,
                      l_out_traget_price,
                      l_out_new_price,
                      l_out_err_code,
                      l_out_err_mesg);
        END IF; -- CHG0040166

        log('Values: -' || p_test_mode || '- -' || l_out_err_code || '- -' ||
            l_out_new_price || '- -' || l_out_item_valid || '- -' ||
            l_out_err_code || '-');

        -- CHG0045880 -- comment below
        /*IF l_out_err_code = 0 THEN
          IF p_test_mode = 'N' AND l_out_err_code = 0 AND
             l_out_new_price IS NOT NULL AND l_out_item_valid = 1 THEN

            -- insert price
            l_primary_uom_flag := get_master_prim_uom(i.rule_id,
                                                      j.inventory_item_id); -- CHG0040166

            l_product_uom := get_master_uom(i.rule_id, j.inventory_item_id); -- CHG0040166

            insert_item_price(l_out_err_code,
                              l_out_ins_err_mesg,
                              l_list_line_id,
                              i.list_header_id,
                              j.inventory_item_id,
                              l_out_new_price,
                              p_effective_date, -- CHG0040166
                              l_primary_uom_flag,
                              l_product_uom,
                              i.product_precedence); -- CHG0042537

          END IF;
        END IF;*/

        -- log
        IF l_out_item_valid = 1 OR l_out_err_code = 1 THEN
          log(rpad(j.segment1, 20, ' ') || lpad(l_curr_price, 20, ' ') ||
              lpad(nvl(to_char(l_out_new_price), ' '), 20, ' '));

          if l_out_item_valid = 1 and l_out_err_code = 0 and l_out_new_price is not null then
            l_api_eligible := 'INSERT';
          else
            l_api_eligible := null;
          end if;

          INSERT INTO xxom_pl_upd_simulation
            (--source_code,  -- CHG0045880 commented
             list_header_id,
             list_header_name,
             change_method,
             change_type,
             master_list_header_id,
             master_list_header_name,
             rule_id,
             -- product_type,
             -- category_code,
             item_code,
             old_price,
             new_price,
             rule_value,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             last_update_login,
             err_msg,
             save_ind,
             request_id,
             list_line_id,
             inventory_item_id,
             master_price,
             seq_num,
             new_item_flag,
             err_flag,
             excluded_flag, -- CHG0040166
             fixed_price,   -- CHG0040166
             simulation_id, -- CHG0045880
             api_eligible,  -- CHG0045880
             product_precedence)  -- CHG0047324 add
          VALUES
            (--i.source_code, -- CHG0045880 commented
             i.list_header_id,
             get_price_list_name(i.list_header_id),
             i.change_method,
             i.change_type,
             i.master_list_header_id,
             get_price_list_name(i.master_list_header_id),
             i.rule_id,
             -- c.product_type,
             --   j.category_code, --category_code,
             j.segment1, --item_code,
             NULL, --old_price,
             l_out_new_price, --new_price,
             round(l_out_actual_factor, 2),
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.user_id,
             fnd_global.login_id,
             l_out_err_mesg || ' ' || l_out_ins_err_mesg,
             decode(p_test_mode, 'Y', 'N', 'Y'),
             fnd_global.conc_request_id,
             l_list_line_id, -- line_id
             j.inventory_item_id,
             l_out_traget_price,
             i.seq_num,
             'Y',
             l_out_err_code,
             nvl(l_exclude, 'N'), -- CHG0040166
             decode(nvl(l_exclusion_exists, 'N'),
                    'N',
                    NULL,
                    decode(l_exclude, 'N', l_out_new_price, NULL)),-- CHG0040166
             p_simulation_id, -- CHG0045880
             l_api_eligible,  -- CHG0045880
             i.product_precedence); -- CHG0047324 add
          COMMIT;
        END IF;
      END LOOP;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := SQLERRM;
      retcode := 2;
  END;

  --------------------------------------------------------------------
  --  Name      :        close_pricelist_lines
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     04/12/2017
  --------------------------------------------------------------------
  --  Purpose :          CHG0040166 - This wrapper procedure will be used to
  --                     validate all eligible items for closure and call
  --                     close_item_price to end_date the line in PL
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  04/12/2017    Diptasurjya Chatterjee       Initial Build
  --  1.1  09/10/2019    Diptasurjya                  CHG0045880 - remove p_source parameter
  --------------------------------------------------------------------
  PROCEDURE close_pricelist_lines(errbuf          OUT VARCHAR2,
                                  retcode         OUT VARCHAR2,
                                  --p_source        VARCHAR2, -- CHG0045880 comment
                                  p_pl_end_date   VARCHAR2,
                                  p_close_exclude VARCHAR2) IS

    l_api_err_code NUMBER;
    l_api_err_msg  VARCHAR2(2000);
    l_list_line_id NUMBER;

    l_out_item_valid    NUMBER;
    l_out_actual_factor NUMBER;
    l_out_traget_price  NUMBER;
    l_out_new_price     NUMBER;
    l_exclusion_exists  VARCHAR2(1);
    l_exclude           VARCHAR2(1);
    l_exc_list_line_id  NUMBER;

    l_exc_err_code NUMBER;
    l_exc_err_mesg VARCHAR2(2000);

    CURSOR c_pl IS
      SELECT *
        FROM xxom_pl_upd_rule_header h
       WHERE /*h.source_code =
             decode(p_source, 'ALL', h.source_code, p_source)
         AND*/ h.pl_active = 'Y';  -- CHG0045880 remove source code check

    CURSOR c_close_eligible(p_list_header_id        NUMBER,
                            p_master_list_header_id NUMBER) IS
      SELECT qll_chil.list_header_id,
             qll_chil.list_line_id,
             qll_mas.end_date_active,
             qll_mas.product_attr_value
        FROM (SELECT *
                FROM (SELECT list_header_id,
                             list_line_id,
                             qll.product_attr_value,
                             qll.start_date_active,
                             qll.end_date_active,
                             rank() over(PARTITION BY qll.list_header_id, qll.product_attr_value ORDER BY start_date_active DESC) rn
                        FROM qp_list_lines_v qll
                       WHERE qll.product_attribute = 'PRICING_ATTRIBUTE1'
                         AND qll.list_header_id = p_master_list_header_id)
               WHERE rn = 1
                 AND end_date_active IS NOT NULL) qll_mas,
             qp_list_lines_v qll_chil
       WHERE qll_chil.list_header_id = p_list_header_id
         AND qll_mas.product_attr_value = qll_chil.product_attr_value
         AND qll_chil.product_attribute = 'PRICING_ATTRIBUTE1'
         AND qll_chil.end_date_active IS NULL;

    CURSOR c_close_exclude(p_list_header_id NUMBER) IS
      SELECT qllc.list_header_id,
             qllc.list_line_id,
             qllc.product_attr_value
        FROM qp_list_lines_v qllc
       WHERE qllc.list_header_id = p_list_header_id
         AND qllc.end_date_active IS NULL
         AND qllc.product_attribute = 'PRICING_ATTRIBUTE1';
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    log('--------------------------------------------');
    log('Close lines.....' || p_pl_end_date);
    log('--------------------------------------------');
    --log('Running in Test mode =' || p_test_mode);

    FOR i IN c_pl LOOP
      IF p_close_exclude <> 'Y' THEN
        FOR rec_close IN c_close_eligible(i.list_header_id,
                                          i.master_list_header_id) LOOP
          l_list_line_id     := 0;
          l_exc_list_line_id := 0;

          log('Close params: ' || i.list_header_id || ' ' ||
              i.master_list_header_id);

          close_item_price(l_api_err_code,
                           l_api_err_msg,
                           rec_close.list_header_id,
                           rec_close.list_line_id,
                           p_pl_end_date,
                           l_list_line_id);

          INSERT INTO xxom_pl_upd_simulation
            (--source_code,  -- CHG0045880 comment
             list_header_id,
             list_header_name,
             change_method,
             change_type,
             master_list_header_id,
             master_list_header_name,
             rule_id,
             -- product_type,
             -- category_code,
             item_code,
             old_price,
             new_price,
             rule_value,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             last_update_login,
             err_msg,
             save_ind,
             request_id,
             list_line_id,
             inventory_item_id,
             master_price,
             seq_num,
             new_item_flag,
             err_flag,
             excluded_flag, -- CHG0040166
             fixed_price) -- CHG0040166
          VALUES
            (--i.source_code,  -- CHG0045880 commented
             rec_close.list_header_id,
             get_price_list_name(rec_close.list_header_id),
             i.change_method,
             i.change_type,
             i.master_list_header_id,
             get_price_list_name(i.master_list_header_id),
             i.rule_id,
             -- c.product_type,
             --   j.category_code, --category_code,
             xxinv_utils_pkg.get_item_segment(rec_close.product_attr_value,
                                              xxinv_utils_pkg.get_master_organization_id), --item_code,
             NULL, --old_price,
             NULL, --new_price,
             NULL,
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.user_id,
             fnd_global.login_id,
             l_api_err_msg,
             'Y',
             fnd_global.conc_request_id,
             rec_close.list_line_id, -- line_id
             rec_close.product_attr_value, --xxinv_utils_pkg.get_item_id(rec_close.product_attr_value),
             NULL,
             i.seq_num,
             'N',
             l_api_err_code,
             'N', -- CHG0040166
             NULL);

          COMMIT;
          log('Line close status Status Code: ' || l_api_err_code);
          log('Line close status Status Message: ' || l_api_err_msg);
        END LOOP;
      END IF;

      IF p_close_exclude = 'Y' AND p_pl_end_date IS NOT NULL THEN
        --log('here header: '||i.list_header_id);
        FOR rec_exclude IN c_close_exclude(i.list_header_id) LOOP
          handle_exclusion(rec_exclude.product_attr_value,
                           i.rule_id,
                           l_out_item_valid,
                           l_out_actual_factor,
                           l_out_traget_price,
                           l_out_new_price,
                           l_exclusion_exists,
                           l_exclude,
                           l_exc_err_code,
                           l_exc_err_mesg);

          IF l_exc_err_code = 0 AND l_out_item_valid = 1 AND
             l_exclude = 'Y' THEN
            --log('Exclusion pass '||rec_exclude.product_attr_value);
            close_item_price(l_api_err_code,
                             l_api_err_msg,
                             rec_exclude.list_header_id,
                             rec_exclude.list_line_id,
                             p_pl_end_date,
                             l_exc_list_line_id);
            --log('Custom close message: '||l_api_err_msg);
            INSERT INTO xxom_pl_upd_simulation
              (--source_code, -- INC0175350 comment
               list_header_id,
               list_header_name,
               change_method,
               change_type,
               master_list_header_id,
               master_list_header_name,
               rule_id,
               -- product_type,
               -- category_code,
               item_code,
               old_price,
               new_price,
               rule_value,
               last_update_date,
               last_updated_by,
               creation_date,
               created_by,
               last_update_login,
               err_msg,
               save_ind,
               request_id,
               list_line_id,
               inventory_item_id,
               master_price,
               seq_num,
               new_item_flag,
               err_flag,
               excluded_flag, -- CHG0040166
               fixed_price) -- CHG0040166
            VALUES
              (--i.source_code,  -- INC0175350 comment
               rec_exclude.list_header_id,
               get_price_list_name(rec_exclude.list_header_id),
               i.change_method,
               i.change_type,
               i.master_list_header_id,
               get_price_list_name(i.master_list_header_id),
               i.rule_id,
               -- c.product_type,
               --   j.category_code, --category_code,
               xxinv_utils_pkg.get_item_segment(rec_exclude.product_attr_value,
                                                xxinv_utils_pkg.get_master_organization_id), --item_code,
               NULL, --old_price,
               NULL, --new_price,
               NULL,
               SYSDATE,
               fnd_global.user_id,
               SYSDATE,
               fnd_global.user_id,
               fnd_global.login_id,
               l_api_err_msg,
               'Y',
               fnd_global.conc_request_id,
               rec_exclude.list_line_id, -- line_id
               rec_exclude.product_attr_value,
               NULL,
               i.seq_num,
               'N',
               l_api_err_code,
               'N', -- CHG0040166
               NULL);
            COMMIT;
          END IF;
        END LOOP;
        COMMIT;
      END IF;

    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := SQLERRM;
      retcode := 2;
  END close_pricelist_lines;

  --------------------------------------------------------------------
  --  Name      :        send_log_mail
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     04/12/2017
  --------------------------------------------------------------------
  --  Purpose :          CHG0040166 - This procedure will be used to
  --                     send the pl update process log by email
  --                     The concurrent request XXOM_PL_UPD_OUTPUT_LOG
  --                     which will generate an EXCEL output will be fired
  --                     The program XXSENDREQTOMAIL will then be used to send the
  --                     report request output by email
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  04/12/2017    Diptasurjya Chatterjee       Initial Build
  --  1.1  24-JUL-2019   Diptasurjya                  CHG0045880 - PL simulation approval changes
  --------------------------------------------------------------------
  PROCEDURE send_log_mail(errbuf       OUT VARCHAR2,
                          retcode      OUT VARCHAR2,
                          p_request_id IN NUMBER,
                          p_email      IN VARCHAR2,
                          p_simulation_id IN NUMBER,
                          p_approval_type_code IN VARCHAR2,
                          p_test_mode  IN varchar2) IS  -- CHG0045880 added new parameter
    l_out_gen_conc_id NUMBER;
    l_mail_conc_id    NUMBER;
    l_simulation_name varchar2(240);

    v_phase      VARCHAR2(80) := NULL;
    v_status     VARCHAR2(80) := NULL;
    v_dev_phase  VARCHAR2(80) := NULL;
    v_dev_status VARCHAR2(80) := NULL;
    v_message    VARCHAR2(240) := NULL;
    v_req_st     BOOLEAN;

    l_email_subject VARCHAR2(1000);
    l_email_body    VARCHAR2(2000);

    l_layout BOOLEAN;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    l_layout := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                       template_code      => 'XXOM_PL_UPD_OUTPUT_LOG',
                                       template_language  => 'en',
                                       template_territory => 'US',
                                       output_format      => 'EXCEL');

    l_layout := fnd_request.set_print_options(copies => 0);

    l_out_gen_conc_id := fnd_request.submit_request(application => 'XXOBJT',
                                                    program     => 'XXOM_PL_UPD_OUTPUT_LOG',
                                                    description => NULL,
                                                    start_time  => SYSDATE,
                                                    sub_request => FALSE,
                                                    argument1   => p_request_id,
                                                    argument2   => p_simulation_id,
                                                    argument3   => p_approval_type_code);

    IF l_out_gen_conc_id > 0 THEN
      COMMIT;

      LOOP
        v_req_st := apps.fnd_concurrent.wait_for_request(request_id => l_out_gen_conc_id,
                                                         INTERVAL   => 0,
                                                         max_wait   => 0,
                                                         phase      => v_phase,
                                                         status     => v_status,
                                                         dev_phase  => v_dev_phase,
                                                         dev_status => v_dev_status,
                                                         message    => v_message);
        EXIT WHEN v_dev_phase = 'COMPLETE';
      END LOOP;
      --x_request_id := l_conc_id;

      IF v_dev_status <> 'NORMAL' THEN
        retcode := 1;
        errbuf  := 'PL Update output generation program finished with errors';
      END IF;

      COMMIT;
    ELSE
      retcode := 1;
      errbuf  := 'PL Update output generation program finished with errors';
    END IF;

    IF v_dev_status = 'NORMAL' THEN
      begin
        select xph.simulation_name
          into l_simulation_name
          from XXOM_PL_UPD_SIMULATION_HDR xph
         where xph.simulation_id = p_simulation_id;
      exception when no_data_found then
        l_simulation_name := '';
      end;

      fnd_message.set_name('XXOBJT', 'XXOM_PL_UPD_OUTPUT_SUB');
      fnd_message.set_token('PROG_MODE', nvl(p_test_mode,''));  -- CHG0045880 add new token
      fnd_message.set_token('REQUEST_ID', p_request_id);
      fnd_message.set_token('SIMULATION_NAME', l_simulation_name);
      l_email_subject := fnd_message.get;

      fnd_message.set_name('XXOBJT', 'XXOM_PL_UPD_OUTPUT_MSG1');
      fnd_message.set_token('PROG_MODE', nvl(p_test_mode,''));   -- CHG0045880 add new token
      fnd_message.set_token('REQUEST_ID', p_request_id);
      fnd_message.set_token('SIMULATION_NAME', l_simulation_name);
      l_email_body := fnd_message.get;

      l_email_subject := REPLACE(l_email_subject, ' ', '_');
      l_email_body    := REPLACE(l_email_body, ' ', '_');

      l_mail_conc_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXSENDREQTOMAIL', --'XXSENDREQOUTPDFGEN',
                                                   argument1   => l_email_subject, -- Mail Subject
                                                   argument2   => l_email_body, -- Mail Body
                                                   argument3   => NULL, -- Mail Body1
                                                   argument4   => NULL, -- Mail Body2
                                                   argument5   => 'XXOM_PL_UPD_OUTPUT_LOG', -- Concurrent Short Name
                                                   argument6   => l_out_gen_conc_id, -- Request id
                                                   argument7   => p_email, -- Mail Recipient      --'Dalit.Raviv@Objet.com',--'saar.nagar@Objet.com',
                                                   argument8   => 'PL_'||p_test_mode||'_Output', -- Report Name (each run can get different name)
                                                   argument9   => p_request_id, -- Report Subject Number (Sr Number, SO Number...)
                                                   argument10  => 'EXCEL', -- Concurrent Output Extension - PDF, EXCEL ...
                                                   argument11  => 'xls', -- File Extension to Send - pdf, exl
                                                   argument12  => 'N', -- Delete Concurrent Output - Y/N
                                                   argument13  => NULL);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'ERROR: PL Ouput Gen: ' || SQLERRM;
      retcode := 0;
  END send_log_mail;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0045880
  --          This Procedure is used to send Mail for errors
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  31/07/2019  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE send_mail(
            p_subject         IN varchar2,
	          p_body            IN VARCHAR2,
            p_user_to         IN VARCHAR2,
            p_mail_cc         IN VARCHAR2 default NULL) IS
    l_mail_to_list VARCHAR2(240);
    l_mail_cc_list VARCHAR2(240);
    l_err_code     VARCHAR2(4000);
    l_err_msg      VARCHAR2(4000);

    l_api_phase VARCHAR2(240) := 'event processor';
    l_requester_mail  varchar2(240);
  BEGIN
    l_mail_to_list := p_user_to;

    l_mail_cc_list := p_mail_cc;

    xxobjt_wf_mail.send_mail_text(p_to_role     => l_mail_to_list,
		          p_cc_mail     => l_mail_cc_list,
		          p_subject     => p_subject,
		          p_body_text   => p_body,
		          p_err_code    => l_err_code,
		          p_err_message => l_err_msg);

  END send_mail;

  --------------------------------------------------------------------------------------------
  -- Object Name   : classify_sim_approval_type
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  procedure classify_sim_approval_type(p_simulation_id IN number,
                                       x_retcode OUT number,
                                       x_errbuf OUT varchar2) is
    l_dyn_update_sql varchar2(4000);
  begin
    x_retcode := 0;
    -- update simulation line approval code based on item type
    for identify_rec in (select ffv.FLEX_VALUE,fnm.message_text
                          from fnd_flex_value_sets ffvs,
                               fnd_flex_values ffv,
                               fnd_new_messages fnm
                         where ffvs.flex_value_set_name = 'XXQP_PL_SIM_APPROVAL_HIERARCHY'
                           and ffvs.flex_value_set_id = ffv.FLEX_VALUE_SET_ID
                           and fnm.message_name = ffv.ATTRIBUTE1
                           and ffv.ENABLED_FLAG = 'Y'
                           and sysdate between nvl(ffv.START_DATE_ACTIVE, sysdate-1) and nvl(ffv.END_DATE_ACTIVE, sysdate+1)
                         order by ffv.hierarchy_level) loop

      l_dyn_update_sql := 'update xxom_pl_upd_simulation xpu set approval_type= '''||identify_rec.flex_value||'''  where simulation_id = '||p_simulation_id||' and inventory_item_id in ('||identify_rec.message_text||')';
      l_dyn_update_sql := l_dyn_update_sql || ' and xpu.api_eligible is not null';
      l_dyn_update_sql := l_dyn_update_sql || ' and xpu.approval_type is null';
      -- add below condition to exclude approval excluded PL lines
      l_dyn_update_sql := l_dyn_update_sql || ' and not exists (select 1
                     from fnd_flex_value_sets ffvs,
                          fnd_flex_values ffv,
                          qp_list_headers_all qh
                    where ffvs.flex_value_set_name = ''XXQP_APPROVAL_EXCLUDE_PRICELISTS''
                      and ffvs.flex_value_set_id = ffv.flex_value_set_id
                      and qh.NAME = ffv.flex_value
                      and qh.LIST_HEADER_ID = xpu.list_header_id
                      and ffv.enabled_flag = ''Y''
                      and sysdate between nvl(ffv.start_date_active, sysdate-1) and nvl(ffv.end_date_active,sysdate+1))';


      execute immediate l_dyn_update_sql;

    end loop;
  exception when others then
    x_retcode := 2;
    x_errbuf := 'ERROR: While classify approval track. '||sqlerrm;
  end classify_sim_approval_type;

  /*procedure handle_api_calls(p_simulation_id IN number,
                             errbuf OUT varchar2,
                             retcode OUT number) is
    l_simulation_status varchar2(200);
    l_effective_date date;
    l_simulation_mode varchar2(1);
    l_primary_uom_flag VARCHAR2(1); -- CHG0040166
    l_product_uom      VARCHAR2(3); -- CHG0040166
  begin
    retcode := 0;
    errbuf := null;

    select xph.simulation_status, xph.effective_date, xph.simulation_mode
      into l_simulation_status, l_effective_date, l_simulation_mode
      from xxom_pl_upd_simulation_hdr xph
     where xph.simulation_id = p_simulation_id;

    if l_simulation_status <> 'APPROVED' then
      retcode := 2;
      errbuf := 'Pricelists can be updated for APPROVED simulations only';

      return;
    end if;

    if l_simulation_mode in ('I','B') then
      -- insert price
      --for rec in (select )
      l_primary_uom_flag := get_master_prim_uom(i.rule_id,
                                                j.inventory_item_id); -- CHG0040166

      l_product_uom := get_master_uom(i.rule_id, j.inventory_item_id); -- CHG0040166

      insert_item_price(l_out_err_code,
                        l_out_ins_err_mesg,
                        l_list_line_id,
                        i.list_header_id,
                        j.inventory_item_id,
                        l_out_new_price,
                        p_effective_date, -- CHG0040166
                        l_primary_uom_flag,
                        l_product_uom,
                        i.product_precedence); -- CHG0042537
    elsif l_simulation_mode in ('B','U') then
      l_out_new_line_id := NULL;
      IF c.start_date_active = trunc(SYSDATE) AND
         p_effective_date IS NULL THEN
        l_correction_mode := 'Y';
        l_end_date_active := NULL;
      ELSE
        l_correction_mode := 'N';
        -- CHG0040166 - Start
        IF p_effective_date IS NOT NULL THEN
          l_end_date_active := trunc(fnd_date.canonical_to_date(p_effective_date)) - 1;
        ELSE
          -- CHG0040166 - End
          l_end_date_active := greatest(nvl(c.start_date_active,
                                            trunc(SYSDATE - 1)),
                                        trunc(SYSDATE - 1));
        END IF; -- CHG0040166

      END IF;

      l_primary_uom_flag := get_master_prim_uom(i.rule_id,
                                                c.inventory_item_id); -- CHG0040166

      l_product_uom := get_master_uom(i.rule_id, c.inventory_item_id); -- CHG0040166

      update_item_price(l_out_err_code,
                        l_out_upd_err_msg,
                        i.list_header_id,
                        c.list_line_id,
                        c.inventory_item_id,
                        l_out_new_price,
                        l_end_date_active,
                        l_correction_mode, -- correction_mode
                        p_effective_date, -- CHG0040166
                        l_primary_uom_flag, -- CHG0040166
                        l_product_uom, -- CHG0040166
                        i.product_precedence, -- CHG0042537
                        l_out_new_line_id);
    end if;

  exception when others then
    retcode := 2;
    errbuf := 'ERROR: While calling API to insert/update prices. '||sqlerrm;
  end handle_api_calls;*/

  --------------------------------------------------------------------
  --  Name      :        handle_audit_insert
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     04/12/2017
  --------------------------------------------------------------------
  --  Purpose :          CHG0040166 - This procedure will be used to
  --                     insert audit information into custom audit table
  --                     for every change in record of the setup tables
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  04/12/2017    Diptasurjya Chatterjee       Initial Build
  --  1.1  01/23/2020    Diptasurjya Chatterjee       CHG0047324 - master PL should be determined from
  --                                                  xxom_pl_upd_simulation table and not xxom_pl_upd_rule_header
  --                                                  Do not derive from Rule Header as rule header might have changed
  --                                                  between simulation and upload
  --------------------------------------------------------------------
  PROCEDURE upload_approved_sim(errbuf OUT varchar2,
                                retcode OUT number,
                                p_simulation_id IN number) is
    --l_partial_load_allowed  varchar2(1) := fnd_profile.VALUE('XXQP_PL_SIMULATION_ALLOW_PARTIAL_UPLOAD');

    cursor insert_approved_pl is
      select xpu.list_header_id,
             xpu.inventory_item_id,
             xpu.new_price,
             --xprh.product_precedence,  -- CHG0047324 comment
             xpu.product_precedence,  -- CHG0047324 add
             get_master_prim_uom(/*xprh.rule_id*/xpu.master_list_header_id, xpu.inventory_item_id) primary_uom_flag, -- CHG0047324 change parameter
             get_master_uom(/*xprh.rule_id*/xpu.master_list_header_id, xpu.inventory_item_id) product_uom,  -- CHG0047324 change parameter
             xpu.rowid rid
        from xxom_pl_upd_simulation xpu,
             --xxom_pl_upd_rule_header xprh,  -- CHG0047324 comment
             xxqp_pl_upd_sim_approval xpa
       where xpu.api_eligible = 'INSERT'
         and nvl(xpu.api_status,'X') <> 'S'  -- CHG0047324 don't check for previously processed records
         and xpu.simulation_id = p_simulation_id
         --and xprh.rule_id = xpu.rule_id  -- CHG0047324 comment
         and xpu.generated_list_line_id is null
         and xpa.simulation_approval_id = xpu.simulation_approval_id
         and xpa.approval_status = 'APPROVED';

    cursor update_approved_pl is
      select qll.start_date_active,
             qll.list_header_id,
             qll.list_line_id,
             xpu.inventory_item_id,
             xpu.new_price,
             --xprh.product_precedence, -- CHG0047324 comment
             xpu.product_precedence, -- CHG0047324 add
             get_master_prim_uom(/*xprh.rule_id*/xpu.master_list_header_id, xpu.inventory_item_id) primary_uom_flag, -- CHG0047324 change parameter
             get_master_uom(/*xprh.rule_id*/xpu.master_list_header_id, xpu.inventory_item_id) product_uom,  -- CHG0047324 change parameter
             xpu.rowid rid
        from xxom_pl_upd_simulation xpu,
             qp_list_lines_v qll,
             --xxom_pl_upd_rule_header xprh,  -- CHG0047324 comment
             xxqp_pl_upd_sim_approval xpa
       where xpu.api_eligible = 'UPDATE'
         and nvl(xpu.api_status,'X') <> 'S'  -- CHG0047324 don't check for previously processed records
         and xpa.approval_status = 'APPROVED'
         and xpu.simulation_id = p_simulation_id
         and xpu.list_header_id = qll.list_header_id
         and xpa.simulation_approval_id = xpu.simulation_approval_id
         and qll.product_id = xpu.inventory_item_id
         and qll.end_date_active is null
         --and xprh.rule_id = xpu.rule_id  -- CHG0047324 comment
         and xpu.generated_list_line_id is null;

    cursor insert_excluded_pl is
      select xpu.list_header_id,
             xpu.inventory_item_id,
             xpu.new_price,
             --xprh.product_precedence, -- CHG0047324 comment
             xpu.product_precedence, -- CHG0047324 add
             get_master_prim_uom(/*xprh.rule_id*/xpu.master_list_header_id, xpu.inventory_item_id) primary_uom_flag, -- CHG0047324 change parameter
             get_master_uom(/*xprh.rule_id*/xpu.master_list_header_id, xpu.inventory_item_id) product_uom,  -- CHG0047324 change parameter
             xpu.rowid rid
        from xxom_pl_upd_simulation xpu
             --xxom_pl_upd_rule_header xprh,  -- CHG0047324 comment
       where xpu.simulation_approval_id is null
         and xpu.api_eligible = 'INSERT'
         and nvl(xpu.api_status,'X') <> 'S'  -- CHG0047324 don't check for previously processed records
         and xpu.simulation_id = p_simulation_id
         --and xprh.rule_id = xpu.rule_id  -- CHG0047324 comment
         and xpu.generated_list_line_id is null;

    cursor update_excluded_pl is
      select qll.start_date_active,
             qll.list_header_id,
             qll.list_line_id,
             xpu.inventory_item_id,
             xpu.new_price,
             --xprh.product_precedence, -- CHG0047324 comment
             xpu.product_precedence, -- CHG0047324 add
             get_master_prim_uom(/*xprh.rule_id*/xpu.master_list_header_id, xpu.inventory_item_id) primary_uom_flag, -- CHG0047324 change parameter
             get_master_uom(/*xprh.rule_id*/xpu.master_list_header_id, xpu.inventory_item_id) product_uom,  -- CHG0047324 change parameter
             xpu.rowid rid
        from xxom_pl_upd_simulation xpu,
             qp_list_lines_v qll
             --xxom_pl_upd_rule_header xprh,  -- CHG0047324 comment
       where xpu.api_eligible = 'UPDATE'
         and nvl(xpu.api_status,'X') <> 'S'  -- CHG0047324 don't check for previously processed records
         and xpu.simulation_approval_id is null
         and xpu.simulation_id = p_simulation_id
         and xpu.list_header_id = qll.list_header_id
         and qll.product_id = xpu.inventory_item_id
         and qll.end_date_active is null
         --and xprh.rule_id = xpu.rule_id  -- CHG0047324 comment
         and xpu.generated_list_line_id is null;


    l_count  number := 0;
    l_effective_date date;
    l_approver_emails varchar2(2000);
    l_simulation_name varchar2(240);
    l_out_new_line_id number;
    l_correction_mode varchar2(1);
    l_end_date_active date;
    l_upd_err_code number;
    l_upd_err_msg varchar2(4000);
    l_requestor_mail varchar2(240);
    l_gen_rep_status      VARCHAR2(20);
    l_gen_rep_msg         varchar2(4000);
    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
    
    l_update_status_info  xxqp_pl_upd_data_tab; -- CHG0047324 add
    l_update_status_count number := 0; -- CHG0047324 add
    l_update_global_status varchar2(1) :='S';  -- CHG0047324 add

    l_stale_insert_rc  number := 0;
    l_stale_update_rc  number := 0;

    l_usr_exception exception;
  BEGIN
    retcode := 0;
    errbuf := null;

    update xxom_pl_upd_simulation_hdr xph
       set xph.upload_request_id = fnd_global.CONC_REQUEST_ID
     where xph.simulation_id = p_simulation_id;
    commit;

    log('xxqp_utils_pkg.upload_approved_sim: In PL Upload API call program');

    begin
      select xph.effective_date, xph.simulation_name
        into l_effective_date, l_simulation_name
        from xxom_pl_upd_simulation_hdr xph
       where simulation_id = p_simulation_id;
    exception when no_data_found then
      errbuf := 'Simulation ID is not valid';
      retcode := 2;

      raise l_usr_exception;
    end;
    log('xxqp_utils_pkg.upload_approved_sim: Simultion ID validated successfully');

    log('xxqp_utils_pkg.upload_approved_sim: Start simulation stale checks');
    -- Start simulation data STALE check
    update xxom_pl_upd_simulation xps
       set xps.api_status = 'E',
           xps.api_status_message = 'STALE SIMULATION: Price already exists in PL, but no price was present during simulation. Please perform fresh simulation.'
     where xps.api_eligible = 'INSERT'
       and nvl(xps.api_status,'X') <> 'S'  -- CHG0047324 don't check for previously processed records
       and xps.simulation_id = p_simulation_id
       and exists (select 1 from qp_list_lines_v qll
                    where xps.list_header_id = qll.list_header_id
                      and xps.inventory_item_id = qll.product_id
                      and sysdate < nvl(qll.end_date_active, sysdate+1));

    l_stale_insert_rc := SQL%ROWCOUNT;
    commit;
    log('xxqp_utils_pkg.upload_approved_sim: Simulation INSERT records found stale: '||l_stale_insert_rc);

    update xxom_pl_upd_simulation xps
       set xps.api_status = 'E',
           xps.api_status_message = 'STALE SIMULATION: This item has same price in PL as in simulation. During simulation different price existed in PL. Please perform fresh simulation.'
     where xps.api_eligible = 'UPDATE'
       and nvl(xps.api_status,'X') <> 'S'  -- CHG0047324 don't check for previously processed records
       and xps.simulation_id = p_simulation_id
       and exists (select 1 from qp_list_lines_v qll
                    where xps.list_header_id = qll.list_header_id
                      and xps.inventory_item_id = qll.product_id
                      and qll.operand = xps.new_price
                      and sysdate < nvl(qll.end_date_active, sysdate+1));
    l_stale_update_rc := SQL%ROWCOUNT;
    commit;
    log('xxqp_utils_pkg.upload_approved_sim: Simulation UPDATE records found stale: '||l_stale_update_rc);
    -- End simulation data STALE check

    if l_stale_insert_rc = 0 and l_stale_update_rc = 0 then
      log('xxqp_utils_pkg.upload_approved_sim: Start - handle UPDATE of approval excluded lines');
      -- handle update of approval excluded lines
      l_end_date_active := null;
      l_correction_mode := null;
      for exclude_upd_pl_rec in update_excluded_pl loop
        l_out_new_line_id := NULL;
        l_upd_err_code := null;
        l_upd_err_msg := null;

        IF exclude_upd_pl_rec.start_date_active = trunc(SYSDATE) AND l_effective_date IS NULL THEN
          l_correction_mode := 'Y';
          l_end_date_active := NULL;
        ELSE
          l_correction_mode := 'N';
          IF l_effective_date IS NOT NULL THEN
            l_end_date_active := trunc(l_effective_date) - 1;
          ELSE
            l_end_date_active := greatest(nvl(exclude_upd_pl_rec.start_date_active,
                                              trunc(SYSDATE - 1)),
                                          trunc(SYSDATE - 1));
          END IF;

        END IF;

        update_item_price(l_upd_err_code,
                          l_upd_err_msg,
                          exclude_upd_pl_rec.list_header_id,
                          exclude_upd_pl_rec.list_line_id,
                          exclude_upd_pl_rec.inventory_item_id,
                          exclude_upd_pl_rec.new_price,
                          l_end_date_active,
                          l_correction_mode,
                          l_effective_date,
                          exclude_upd_pl_rec.primary_uom_flag,
                          exclude_upd_pl_rec.product_uom,
                          exclude_upd_pl_rec.product_precedence,
                          l_simulation_name,
                          l_out_new_line_id);


        -- update simulation records with generated line_id and status
        -- CHG0047324 start 
        -- CHG0047324 add below portion
        l_update_status_count := 1 + l_update_status_info.count;
        l_update_status_info(l_update_status_count).rid := exclude_upd_pl_rec.rid;
        l_update_status_info(l_update_status_count).list_line_id := l_out_new_line_id;
        l_update_status_info(l_update_status_count).err_code := l_upd_err_code;
        l_update_status_info(l_update_status_count).err_message := l_upd_err_msg;
        
        if l_upd_err_code = 1 then
          l_update_global_status := 'E';
        end if;
        -- CHG0047324 comment below portion
        /*update xxom_pl_upd_simulation
           set generated_list_line_id = l_out_new_line_id,
               api_status = decode (l_upd_err_code, 0, 'S', 1, 'E'),
               api_status_message=l_upd_err_msg
         where rowid = exclude_upd_pl_rec.rid;
        commit;*/
        -- CHG0047324 end
      end loop;

      log('xxqp_utils_pkg.upload_approved_sim: End - handle UPDATE of approval excluded lines. API Status: '||l_upd_err_code);
      log('xxqp_utils_pkg.upload_approved_sim: Start - handle INSERT of approval excluded lines');
      -- Handle insert of approval excluded lines
      for exclude_ins_pl_rec in  insert_excluded_pl loop
        l_out_new_line_id := null;
        l_upd_err_code := null;
        l_upd_err_msg := null;

        insert_item_price(l_upd_err_code,
                          l_upd_err_msg,
                          l_out_new_line_id,
                          exclude_ins_pl_rec.list_header_id,
                          exclude_ins_pl_rec.inventory_item_id,
                          exclude_ins_pl_rec.new_price,
                          l_effective_date,
                          exclude_ins_pl_rec.primary_uom_flag,
                          exclude_ins_pl_rec.product_uom,
                          exclude_ins_pl_rec.product_precedence,
                          l_simulation_name);

        -- update simulation records with generated line_id and status
        -- CHG0047324 start 
        -- CHG0047324 add below portion
        l_update_status_count := 1 + l_update_status_info.count;
        l_update_status_info(l_update_status_count).rid := exclude_ins_pl_rec.rid;
        l_update_status_info(l_update_status_count).list_line_id := l_out_new_line_id;
        l_update_status_info(l_update_status_count).err_code := l_upd_err_code;
        l_update_status_info(l_update_status_count).err_message := l_upd_err_msg;
        
        if l_upd_err_code = 1 then
          l_update_global_status := 'E';
        end if;
        -- CHG0047324 comment below portion
        /*update xxom_pl_upd_simulation
           set generated_list_line_id = l_out_new_line_id,
               api_status = decode (l_upd_err_code, 0, 'S', 1, 'E'),
               api_status_message=l_upd_err_msg
         where rowid = exclude_ins_pl_rec.rid;
        commit;*/
        -- CHG0047324 end
      end loop;
      log('xxqp_utils_pkg.upload_approved_sim: End - handle INSERT of approval excluded lines. API Status: '||l_upd_err_code);

      log('xxqp_utils_pkg.upload_approved_sim: Start - Handle UPDATE of approved simulation lines');
      -- Handle update of approved simulation lines
      l_end_date_active := null;
      l_correction_mode := null;
      for approved_upd_pl_rec in update_approved_pl loop
        l_out_new_line_id := NULL;
        l_upd_err_code := null;
        l_upd_err_msg := null;
        log('Effective Date: '||l_effective_date);
        IF approved_upd_pl_rec.start_date_active = trunc(SYSDATE) AND l_effective_date IS NULL THEN
          l_correction_mode := 'Y';
          l_end_date_active := NULL;
        ELSE
          l_correction_mode := 'N';
          IF l_effective_date IS NOT NULL THEN
            l_end_date_active := trunc(l_effective_date) - 1;
          ELSE
            l_end_date_active := greatest(nvl(approved_upd_pl_rec.start_date_active,
                                              trunc(SYSDATE - 1)),
                                          trunc(SYSDATE - 1));
          END IF;
        END IF;

        log('l_end_date_active: '||l_end_date_active);
        log('l_correction_mode: '||l_correction_mode);

        update_item_price(l_upd_err_code,
                          l_upd_err_msg,
                          approved_upd_pl_rec.list_header_id,
                          approved_upd_pl_rec.list_line_id,
                          approved_upd_pl_rec.inventory_item_id,
                          approved_upd_pl_rec.new_price,
                          l_end_date_active,
                          l_correction_mode,
                          l_effective_date,
                          approved_upd_pl_rec.primary_uom_flag,
                          approved_upd_pl_rec.product_uom,
                          approved_upd_pl_rec.product_precedence,
                          l_simulation_name,
                          l_out_new_line_id);

        -- update simulation records with generated line_id and status
        -- CHG0047324 start 
        -- CHG0047324 add below portion
        l_update_status_count := 1 + l_update_status_info.count;
        l_update_status_info(l_update_status_count).rid := approved_upd_pl_rec.rid;
        l_update_status_info(l_update_status_count).list_line_id := l_out_new_line_id;
        l_update_status_info(l_update_status_count).err_code := l_upd_err_code;
        l_update_status_info(l_update_status_count).err_message := l_upd_err_msg;
        
        if l_upd_err_code = 1 then
          l_update_global_status := 'E';
        end if;
        -- CHG0047324 comment below portion
        /*update xxom_pl_upd_simulation
           set generated_list_line_id = l_out_new_line_id,
               api_status = decode (l_upd_err_code, 0, 'S', 1, 'E'),
               api_status_message=l_upd_err_msg
         where rowid = approved_upd_pl_rec.rid;
        commit;*/
        -- CHG0047324 end
      end loop;
      log('xxqp_utils_pkg.upload_approved_sim: End - Handle UPDATE of approved simulation lines. API Status: '||l_upd_err_code);

      log('xxqp_utils_pkg.upload_approved_sim: Start - Handle INSERT of approved simulation lines');
      -- handle insert of approved simulation lines
      for approved_ins_pl_rec in  insert_approved_pl loop
        l_out_new_line_id := null;
        l_upd_err_code := null;
        l_upd_err_msg := null;

        insert_item_price(l_upd_err_code,
                          l_upd_err_msg,
                          l_out_new_line_id,
                          approved_ins_pl_rec.list_header_id,
                          approved_ins_pl_rec.inventory_item_id,
                          approved_ins_pl_rec.new_price,
                          l_effective_date,
                          approved_ins_pl_rec.primary_uom_flag,
                          approved_ins_pl_rec.product_uom,
                          approved_ins_pl_rec.product_precedence,
                          l_simulation_name);

        -- update simulation records with generated line_id and status
        -- CHG0047324 start 
        -- CHG0047324 add below portion
        l_update_status_count := 1 + l_update_status_info.count;
        l_update_status_info(l_update_status_count).rid := approved_ins_pl_rec.rid;
        l_update_status_info(l_update_status_count).list_line_id := l_out_new_line_id;
        l_update_status_info(l_update_status_count).err_code := l_upd_err_code;
        l_update_status_info(l_update_status_count).err_message := l_upd_err_msg;
        
        if l_upd_err_code = 1 then
          l_update_global_status := 'E';
        end if;
        -- CHG0047324 comment below portion
        /*update xxom_pl_upd_simulation
           set generated_list_line_id = l_out_new_line_id,
               api_status = decode (l_upd_err_code, 0, 'S', 1, 'E'),
               api_status_message=l_upd_err_msg
         where rowid = approved_ins_pl_rec.rid;
        commit;*/
        -- CHG0047324 end
      end loop;
      log('xxqp_utils_pkg.upload_approved_sim: End - Handle INSERT of approved simulation lines. API Status: '||l_upd_err_code);
    else
      log('xxqp_utils_pkg.upload_approved_sim: Update status of simulation to ERROR due to stale simulation data');
      update xxom_pl_upd_simulation_hdr xph
         set xph.simulation_status='ERROR',
             xph.simulation_status_message='Simulation is stale. Please perform fresh simulation.',
             xph.upload_request_id = fnd_global.CONC_REQUEST_ID,
             xph.last_updated_by = fnd_global.USER_ID,
             xph.last_update_date = sysdate,
             xph.last_update_login = fnd_global.LOGIN_ID
       where xph.simulation_id = p_simulation_id;

      commit;
    end if;
    
    -- CHG0047324 start 
    -- checking if any of update/insert operations failed
    if l_update_global_status = 'E' then
      log('xxqp_utils_pkg.upload_approved_sim: Start - At least 1 record FAILED update or insert via API. Rollback');
      rollback;  -- if any error present rollback all API changes change
      log('xxqp_utils_pkg.upload_approved_sim: End - At least 1 record FAILED update or insert via API. Rollback');
    else
      log('xxqp_utils_pkg.upload_approved_sim: Start - All update or insert via API SUCCESSFULL. Commit');
      commit;  -- if all successfull then commit API changes
      log('xxqp_utils_pkg.upload_approved_sim: End - All update or insert via API SUCCESSFULL. Commit');
    end if;
    
    -- update simulation table with status, message and list_line_id
    log('xxqp_utils_pkg.upload_approved_sim: Start - Update simulation records with API status details');
    for cn in 1..l_update_status_info.count loop
      update xxom_pl_upd_simulation
         set generated_list_line_id = l_update_status_info(cn).list_line_id,
             api_status = decode (l_update_status_info(cn).err_code, 0, 'S', 1, 'E'),
             api_status_message=l_update_status_info(cn).err_message
       where rowid = l_update_status_info(cn).rid;
    end loop;
    commit;
    log('xxqp_utils_pkg.upload_approved_sim: End - Update simulation records with API status details');
    -- CHG0047324 end


    log('xxqp_utils_pkg.upload_approved_sim: Start - Exception report sending to user - insert data');
    l_count := 0;
    for exception_rec in (select xpu.item_code, xpu.new_price, qh.NAME pl_name,xpu.api_status_message
                            from xxom_pl_upd_simulation xpu,
                                 qp_list_headers_all qh
                           where xpu.simulation_id = p_simulation_id
                             and xpu.api_eligible is not null
                             and xpu.api_status = 'E'
                             and qh.LIST_HEADER_ID = xpu.list_header_id) loop
      l_count := l_count +1;

      if l_count = 1 then
        retcode := 2;
        l_requestor_mail := xxhr_util_pkg.get_person_email(fnd_global.EMPLOYEE_ID);

        l_xxssys_generic_rpt_rec.request_id      := fnd_global.CONC_REQUEST_ID;
        l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
        l_xxssys_generic_rpt_rec.email_to        := 'EMAIL';
        l_xxssys_generic_rpt_rec.col1            := 'Simulation Name';
        l_xxssys_generic_rpt_rec.col2            := 'Pricelist Name';
        l_xxssys_generic_rpt_rec.col3            := 'Item Code';
        l_xxssys_generic_rpt_rec.col4            := 'New Price';
        l_xxssys_generic_rpt_rec.col_msg         := 'Error Message';

        xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
                                                      x_return_status          => l_gen_rep_status,
                                                      x_return_message         => l_gen_rep_msg);

        IF l_gen_rep_status <> 'S' THEN
          log('Error Report exception: ' || l_gen_rep_msg);
        END IF;
      end if;

      l_xxssys_generic_rpt_rec.request_id      := fnd_global.CONC_REQUEST_ID;
      l_xxssys_generic_rpt_rec.header_row_flag := 'N';
      l_xxssys_generic_rpt_rec.email_to        := l_requestor_mail;
      l_xxssys_generic_rpt_rec.col1            := l_simulation_name;
      l_xxssys_generic_rpt_rec.col2            := exception_rec.pl_name;
      l_xxssys_generic_rpt_rec.col3            := exception_rec.item_code;
      l_xxssys_generic_rpt_rec.col4            := exception_rec.new_price;
      l_xxssys_generic_rpt_rec.col_msg         := substr(exception_rec.api_status_message,1,499);
      xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
                                                                    x_return_status          => l_gen_rep_status,
                                                                    x_return_message         => l_gen_rep_msg);
      IF l_gen_rep_status <> 'S' THEN
        log('Error Report exception: ' || l_gen_rep_msg);
      END IF;

      commit;
    end loop;
    log('xxqp_utils_pkg.upload_approved_sim: End - Exception report sending to user - insert data');

    if l_count = 0 then
      -- SUCCESS - PL Upload
      log('xxqp_utils_pkg.upload_approved_sim: Update status of simulation to CLOSED');
      update xxom_pl_upd_simulation_hdr xph
         set xph.simulation_status='CLOSED',
             xph.simulation_status_message='Simulated prices loaded successfully',
             xph.pl_update_date = sysdate,
             xph.last_updated_by = fnd_global.USER_ID,
             xph.last_update_date = sysdate,
             xph.last_update_login = fnd_global.LOGIN_ID
       where xph.simulation_id = p_simulation_id;
      commit;

      begin
        select listagg(xxhr_util_pkg.get_person_email(xpa.approver_person_id),';') within group (order by xpa.approver_person_id)
          into l_approver_emails
          from XXQP_PL_UPD_SIM_APPROVAL_V xpa
         where xpa.simulation_id = p_simulation_id
           and xpa.approval_status = 'APPROVED';
      exception when no_data_found then
        l_approver_emails := null;
      end;

      send_mail(p_subject         => 'SUCCESS - PL simulation: '||l_simulation_name||' uploaded successfully',
                p_body            => 'Dear user, Pricelist simulation '||l_simulation_name||' has been successfully uploaded into Oracle. Thanks and Regards',
                p_user_to         => fnd_global.USER_NAME,
                p_mail_cc         => trim(BOTH ';' from l_approver_emails));
    else
      -- ERROR - PL Upload
      log('xxqp_utils_pkg.upload_approved_sim: Start Call generic report to send error report');
      xxssys_generic_rpt_pkg.submit_request(p_burst_flag         => 'Y',
                                            p_request_id         => fnd_global.CONC_REQUEST_ID,
                                            p_l_report_title     => '''' ||
                                                                            'PL Simulation - Price could not be loaded'|| '''',
                                            p_l_email_subject    => '''' ||
                                                                            'PL Simulation - Price could not be loaded' || '''',
                                            p_l_email_body1      => '''' ||
                                                                            'Please find the error report of simulation prices which could not be uploaded into Oracle' || '''',
                                            p_l_order_by         => 'col2',
                                            p_l_file_name        => '''' ||
                                                                            'PL_Simulation_Load_Issue' || '''',
                                            p_l_purge_table_flag => 'Y',
                                            x_return_status      => l_gen_rep_status,
                                            x_return_message     => l_gen_rep_msg);
      errbuf := 'ERROR: Some items on this simulation failed to be uploaded into Oracle. Please check mail for error report.';
      log('xxqp_utils_pkg.upload_approved_sim: End Call generic report to send error report');

      log('xxqp_utils_pkg.upload_approved_sim: Update status of simulation to APPROVED due to errors in simulation upload, if not in ERROR state');
      update xxom_pl_upd_simulation_hdr xph
         set xph.simulation_status='LOAD_ERROR',
             xph.simulation_status_message='Error while uploading one or more prices',
             xph.last_updated_by = fnd_global.USER_ID,
             xph.last_update_date = sysdate,
             xph.last_update_login = fnd_global.LOGIN_ID
       where xph.simulation_id = p_simulation_id
         and xph.simulation_status <> 'ERROR';
      commit;
    end if;
    log('xxqp_utils_pkg.upload_approved_sim: End - PL update process');
  exception
  when l_usr_exception then
    update xxom_pl_upd_simulation_hdr xph
       set xph.simulation_status='LOAD_ERROR',
           xph.simulation_status_message=errbuf,
           xph.last_updated_by = fnd_global.USER_ID,
           xph.last_update_date = sysdate,
           xph.last_update_login = fnd_global.LOGIN_ID
     where xph.simulation_id = p_simulation_id;
    commit;
    retcode := 2;

    send_mail(p_subject         => 'ERROR - PL simulation: '||l_simulation_name||' upload failed',
              p_body            => 'Dear user, Upload of Pricelist simulation '||l_simulation_name||' has encountered unexpected ERROR. ERROR Message: '||errbuf||' . Thanks and Regards',
              p_user_to         => fnd_global.USER_NAME);
  when others then
    retcode := 2;
    errbuf := 'UNEXPECTED ERROR: While loading simulation data into Pricelists. '||substr(sqlerrm,1,1000);

    update xxom_pl_upd_simulation_hdr xph
       set xph.simulation_status='LOAD_ERROR',
           xph.simulation_status_message=errbuf,
           xph.last_updated_by = fnd_global.USER_ID,
           xph.last_update_date = sysdate,
           xph.last_update_login = fnd_global.LOGIN_ID
     where xph.simulation_id = p_simulation_id;
    commit;
    send_mail(p_subject         => 'ERROR - PL simulation: '||l_simulation_name||' upload failed',
              p_body            => 'Dear user, Upload of Pricelist simulation '||l_simulation_name||' has encountered unexpected ERROR. ERROR Message: '||errbuf||' . Thanks and Regards',
              p_user_to         => fnd_global.USER_NAME);
  END upload_approved_sim;

  -------------------------------------------
  -- main_process_pl
  -------------------------------------------
  --  ver   date          name            desc
  --  1.0   19.8.14      yuval tal        CHG0032089 - called from concurrent XX PL Mass Update submitted by form
  --                                      XX Price List Change Rules
  --                                      p_source CS / MRKT
  --                                      p_insert_update I - Insert U Update  B both (I,U)
  --                                      p_test_mode Y/N
  --  1.1   04/12/2017   Diptasurjya      CHG0040166 - new parameters added
  --                                      p_pl_end_date - PL Line end date for close functionality
  --                                      p_close_exclude - Only excluded items will be closed
  --                                      p_send_log_to - Send output simulation log to this email
  --                                      p_effective_date - Effective start date for PL lines to be added/updated
  --
  --                                      Parameter p_insert_update can accept a value of C
  --                                      which will close a PL line. Corresponding call to procedure close_pricelist_lines
  --                                      added.
  --                                      Also procedure send_log_mail is being called if p_send_log_to is not null
  --  1.2   07/12/2019   Diptasurjya      CHG0045880 - new parameter for simulation ID
  --  1.3   12/04/2019   Diptasurjya      INC0176748 - sim not auto approved if no PL specified on sim header
  -------------------------------------------

  PROCEDURE main_process_pl(errbuf           OUT VARCHAR2,
                            retcode          OUT VARCHAR2,
                            p_test_mode      VARCHAR2 DEFAULT 'Y',
                            p_source         VARCHAR2,
                            p_insert_update  VARCHAR2,
                            p_list_header_id NUMBER,
                            p_item_code      VARCHAR2,
                            p_pl_end_date    VARCHAR2, -- CHG0040166
                            p_close_exclude  VARCHAR2, -- CHG0040166
                            p_send_log_to    VARCHAR2, -- CHG0040166
                            p_effective_date VARCHAR2,
                            p_simulation_id  number) IS   -- - CHG0045880 new parameter
    -- CHG0040166

    l_err_code    NUMBER;
    l_err_message VARCHAR2(2000);

    l_mail_err_msg  VARCHAR2(2000); -- CHG0040166
    l_mail_err_code NUMBER; -- CHG0040166

    l_request_id NUMBER; -- CHG0040166

    -- CHG0045880 add below variables
    l_insert_update  varchar2(1) := p_insert_update;
    l_list_header_id number := p_list_header_id;
    l_send_log_to varchar2(240) := p_send_log_to;
    l_item_code varchar2(40) := p_item_code;
    l_classify_retcode number;
    l_classify_errbuf varchar2(4000);
    --l_pl_excluded_cnt number; -- INC0176748 commented
    l_not_pl_excluded_cnt number; -- INC0176748 added

    l_usr_exception exception;
  BEGIN

    log('p_insert_update  : ' || p_insert_update);

    log('Parent request ID: ' || fnd_global.conc_request_id);
    l_request_id := fnd_global.conc_request_id; --  CHG0040166

    -- CHG0045880 fetch simulation parameters based on simulation ID
    if p_simulation_id is not null then
      select nvl(xph.simulation_mode,'B'),
             xph.list_header_id,
             xph.send_log_to,
             xph.item_code
        into l_insert_update,
             l_list_header_id,
             l_send_log_to,
             l_item_code
        from xxom_pl_upd_simulation_hdr xph
       where simulation_id = p_simulation_id;

    else
      if l_insert_update <> 'C' then
        retcode := 2;
        errbuf := 'ERROR';
        log('ERROR: Simulation ID is mandatory');
        return;
      end if;
    end if;

    -- CHG0045880 - call API if not test mode
    if p_test_mode = 'N' then
      upload_approved_sim(errbuf,
                          retcode,
                          p_simulation_id);

      return;
    end if;

    -- CHG0045880 insert old sim data into archive and delete sim data based on simulation ID
    IF p_test_mode = 'Y' THEN
      INSERT INTO xxom_pl_upd_simulation_arc
        SELECT *
          FROM xxom_pl_upd_simulation sim
         WHERE sim.simulation_id = p_simulation_id;

      DELETE FROM xxom_pl_upd_simulation sim
       WHERE sim.simulation_id = p_simulation_id;

      COMMIT;
    END IF;

    IF l_insert_update IN ('U', 'B') THEN
      update_pl(l_err_message,
                l_err_code,
                --p_test_mode,
                --p_source,  -- CHG0045880 comment
                l_list_header_id,
                l_item_code,
                --p_effective_date, -- CHG0040166  -- CHG0045880 commented
                p_simulation_id); -- CHG0045880

    END IF;
    errbuf  := l_err_message;
    retcode := l_err_code;
    ----

    IF l_insert_update IN ('I', 'B') THEN
      add_price_list_lines(l_err_message,
                           l_err_code,
                           --p_test_mode,
                           --p_source,  -- CHG0045880 comment
                           l_list_header_id,
                           l_item_code,
                           --p_effective_date, -- CHG0040166  -- CHG0045880 commented
                           p_simulation_id); -- CHG0045880

      errbuf  := errbuf || ' ' || l_err_message;
      retcode := greatest(l_err_code, retcode);
    END IF;

    -- CHG0040166 - Start
    IF l_insert_update IN ('U', 'B', 'I') THEN
      -- CHG0045880 update simulation status after program completion
      begin
        if retcode = 0 then
          -- INC0176748 added below query
          select count(1)
            into l_not_pl_excluded_cnt
            from xxom_pl_upd_simulation xps
           where xps.simulation_id = p_simulation_id
             and xps.api_eligible is not null
             and not exists
                 (select 1
                    from fnd_flex_value_sets ffvs,
                         fnd_flex_values     ffv,
                         qp_list_headers_all qh
                   where xps.list_header_id = qh.LIST_HEADER_ID
                     and ffvs.flex_value_set_name =
                         'XXQP_APPROVAL_EXCLUDE_PRICELISTS'
                     and ffvs.flex_value_set_id = ffv.flex_value_set_id
                     and qh.NAME = ffv.flex_value
                     and ffv.enabled_flag = 'Y'
                     and sysdate between
                         nvl(ffv.start_date_active, sysdate - 1) and
                         nvl(ffv.end_date_active, sysdate + 1));

          -- INC0176748 commented below
          /*select count(1)
            into l_pl_excluded_cnt
            from fnd_flex_value_sets ffvs,
                 fnd_flex_values ffv,
                 qp_list_headers_all qh
           where ffvs.flex_value_set_name = 'XXQP_APPROVAL_EXCLUDE_PRICELISTS'
             and ffvs.flex_value_set_id = ffv.flex_value_set_id
             and qh.NAME = ffv.flex_value
             and qh.LIST_HEADER_ID = l_list_header_id
             and ffv.enabled_flag = 'Y'
             and sysdate between nvl(ffv.start_date_active, sysdate-1) and nvl(ffv.end_date_active,sysdate+1);*/

          if l_not_pl_excluded_cnt <> 0 then  -- INC0176748 - changed variable name to l_not_pl_excluded_cnt from l_pl_excluded_cnt
            classify_sim_approval_type(p_simulation_id,
                                       l_classify_retcode,
                                       l_classify_errbuf);

            if l_classify_retcode = 0 then
              update XXOM_PL_UPD_SIMULATION_HDR xph
                 set xph.SIMULATION_STATUS = 'SIMULATED',
                     xph.simulation_status_message = 'Simulation Completed Succesfully',
                     xph.last_updated_by = fnd_global.USER_ID,
                     xph.last_update_date = sysdate,
                     xph.last_update_login = fnd_global.LOGIN_ID
               where xph.simulation_id = p_simulation_id;
              commit;
            else
              errbuf := l_classify_errbuf;
              raise l_usr_exception;
            end if;
          else
            update XXOM_PL_UPD_SIMULATION_HDR xph
               set xph.SIMULATION_STATUS = 'APPROVED',
                   xph.simulation_status_message = 'Auto-approved as PL is excluded from approval WF',
                   xph.last_updated_by = fnd_global.USER_ID,
                   xph.last_update_date = sysdate,
                   xph.last_update_login = fnd_global.LOGIN_ID
             where xph.simulation_id = p_simulation_id;
            commit;
          end if;
        else
          raise l_usr_exception;
        end if;
      exception
        when l_usr_exception then
          update XXOM_PL_UPD_SIMULATION_HDR xph
             set xph.SIMULATION_STATUS = 'ERROR',
                 xph.last_updated_by = fnd_global.USER_ID,
                 xph.last_update_date = sysdate,
                 xph.last_update_login = fnd_global.LOGIN_ID,
                 xph.simulation_status_message = 'ERROR: PL Simulation request ID '||l_request_id||' for simulation ID '||p_simulation_id||' finished with errors.'||chr(13)||errbuf||CHR(13)||' Please contact IT.'
           where xph.simulation_id = p_simulation_id;

          commit;
          errbuf  := 'ERROR: While updating simulation tables for approval type and status. '||errbuf;
          retcode := 2;
        when others then
          errbuf  := 'ERROR: While updating simulation tables for approval type and status. '||sqlerrm;
          retcode := 2;
      end;
      -- CHG0045880 end

      IF l_send_log_to IS NOT NULL THEN
        send_log_mail(l_mail_err_msg,
                      l_mail_err_code,
                      l_request_id,
                      l_send_log_to,
                      p_simulation_id,
                      null,
                      'SIMULATION');  -- CHG0045880 send value for new parameter to identify the program run mode
      END IF;
    END IF;

    IF l_insert_update = 'C' THEN
      close_pricelist_lines(l_err_message,
                            l_err_code,
                            --p_source, -- CHG0045880 comment
                            nvl(trunc(fnd_date.canonical_to_date(p_pl_end_date)),
                                trunc(SYSDATE)),
                            p_close_exclude);

      errbuf  := l_err_message;
      retcode := l_err_code;
    END IF;
    -- CHG0040166 - End
  EXCEPTION when others then
    retcode := 2;
    errbuf := 'ERROR: '||sqlerrm;
    rollback;

    update xxom_pl_upd_simulation_hdr set simulation_status = 'ERROR', simulation_status_message = errbuf
    where simulation_id = p_simulation_id;
    commit;
  END;

  --------------------------------------------------------------------
  --  Name      :        validate_excl_cat_val
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     04/12/2017
  --------------------------------------------------------------------
  --  Purpose :          CHG0040166 - This procedure will be used to
  --                     validate the values provided for condition groups
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  04/12/2017    Diptasurjya Chatterjee       Initial Build
  --  1.1  18/11/2019    Diptasurjya Chatterjee       INC0175350 - Source_code handling for null value added
  --------------------------------------------------------------------
  PROCEDURE validate_excl_cat_val(errbuf       OUT VARCHAR2,
                                  retcode      OUT VARCHAR2,
                                  p_request_id IN NUMBER) IS
    l_validation_sql VARCHAR2(2000);
    l_column_extract VARCHAR2(200);

    l_value VARCHAR2(200);

    l_no_sql NUMBER := 0;
  BEGIN
    log('Inside validation procedure');
    FOR rec IN (SELECT stg.*, ROWID rid
                  FROM xxom_pl_upd_exception_stg stg
                 WHERE request_id = p_request_id
                   AND rule_id IS NOT NULL) LOOP
      l_no_sql         := 0;
      l_validation_sql := NULL;
      --begin
      log('Inside validation procedure loop: ' || rec.condition_group);

      BEGIN
        SELECT xxobjt_general_utils_pkg.get_valueset_attribute('XXOM_PL_UPD_CATEGORY',
                                                               rec.condition_group,
                                                               'ATTRIBUTE2')
          INTO l_validation_sql
          FROM xxom_pl_upd_rule_header xrh
         WHERE nvl(xrh.source_code,'ALL') =   -- INC0175350 added nvl
               decode(xxobjt_general_utils_pkg.get_valueset_attribute('XXOM_PL_UPD_CATEGORY',
                                                                      rec.condition_group,
                                                                      'ATTRIBUTE1'),
                      'ALL',
                      nvl(xrh.source_code,'ALL'),  -- INC0175350 added nvl
                      xxobjt_general_utils_pkg.get_valueset_attribute('XXOM_PL_UPD_CATEGORY',
                                                                      rec.condition_group,
                                                                      'ATTRIBUTE1'))
           AND xrh.rule_id = rec.rule_id
           AND decode(xxobjt_general_utils_pkg.get_valueset_attribute('XXOM_PL_UPD_CATEGORY',
                                                                      rec.condition_group,
                                                                      'ATTRIBUTE4'),
                      'ALL',
                      'EXCLUSION',
                      xxobjt_general_utils_pkg.get_valueset_attribute('XXOM_PL_UPD_CATEGORY',
                                                                      rec.condition_group,
                                                                      'ATTRIBUTE4')) =
               'EXCLUSION';
      EXCEPTION
        WHEN no_data_found THEN
          UPDATE xxom_pl_upd_exception_stg
             SET status           = 'E',
                 status_message   = status_message ||
                                    'ERROR: No validation SQL was found for the condition group' ||
                                    chr(13),
                 last_update_date = SYSDATE
           WHERE ROWID = rec.rid;

          log('No query found');
          CONTINUE;
      END;

      log('Validation sql: ' || l_validation_sql);

      SELECT TRIM(ltrim(substr(upper(l_validation_sql),
                               0,
                               instr(upper(l_validation_sql), 'FROM') - 1),
                        'SELECT'))
        INTO l_column_extract
        FROM dual;

      IF instr(upper(l_validation_sql), 'WHERE') > 0 THEN
        l_validation_sql := l_validation_sql || ' AND ' || l_column_extract ||
                            ' = ''' || rec.condition_value || '''';
      ELSE
        l_validation_sql := l_validation_sql || ' WHERE ' ||
                            l_column_extract || ' = ''' ||
                            rec.condition_value || '''';
      END IF;

      log('Validation sql after modification: ' || l_validation_sql);

      BEGIN
        EXECUTE IMMEDIATE l_validation_sql
          INTO l_value;
        log('Value after execution: ' || l_value);
      EXCEPTION
        WHEN no_data_found THEN
          UPDATE xxom_pl_upd_exception_stg
             SET status           = 'E',
                 status_message   = status_message ||
                                    'ERROR: Condition value is not valid' ||
                                    chr(13),
                 last_update_date = SYSDATE
           WHERE ROWID = rec.rid;

          log('No data found after validation');
      END;

    --exception when others then
    --   update XXOM_PL_UPD_EXCEPTION_STG set status='E',status_message=status_message||'ERROR: While validation condition value.'||sqlerrm||CHR(13),
    --         last_update_date = sysdate
    --   where rowid = rec.rid;
    --
    --   log('No query found');
    --end;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 1;
      retcode := 'ERROR: While validation condition value. ' || SQLERRM;
      log('Validation error: ' || SQLERRM);
  END validate_excl_cat_val;

  --------------------------------------------------------------------
  --  Name      :        upload_exclusions_pivot
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     04/12/2017
  --------------------------------------------------------------------
  --  Purpose :          CHG0040166 - This procedure will be used to
  --                     upload pricelist upload exclusions from a flat file
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  04/12/2017    Diptasurjya Chatterjee       Initial Build
  --------------------------------------------------------------------
  PROCEDURE upload_exclusions_pivot(errbuf      OUT VARCHAR2,
                                    retcode     OUT VARCHAR2,
                                    p_directory IN VARCHAR2,
                                    p_file_name IN VARCHAR2) IS
    l_digits      NUMBER := 0;
    l_final_price NUMBER := 0;
    l_line        VARCHAR2(2000);
    --l_raw           raw(32767);
    l_line_no_blank VARCHAR2(2000);
    l_col_cnt       NUMBER := 0;
    l_file_handler  utl_file.file_type;
    l_rule_id       NUMBER;
    l_request_id    NUMBER;

    l_pl_name VARCHAR2(200);

    l_error_message VARCHAR2(2000);

    l_sql_err_msg VARCHAR2(2000);

    l_cond_group     VARCHAR2(240);
    l_cond_value     VARCHAR2(240);
    l_attr           VARCHAR2(100);
    l_attr_num_check NUMBER;
    l_attr_y_n       VARCHAR2(1) := 'Y';

    l_cat_code_valid  VARCHAR2(1);
    l_cat_value_valid VARCHAR2(1);
    l_cat_val_retcode VARCHAR2(1);
    l_cat_val_retmsg  VARCHAR2(2000);

    TYPE l_pricelists_tab IS TABLE OF VARCHAR2(240) INDEX BY BINARY_INTEGER;
    l_pricelists_arr l_pricelists_tab;

    CURSOR c_split(l_str VARCHAR2) IS
      SELECT TRIM(regexp_substr(l_str, '[^,]+', 1, LEVEL)) val
        FROM dual
      CONNECT BY regexp_substr(l_str, '[^,]+', 1, LEVEL) IS NOT NULL;

    l_round_factor NUMBER := 0;

    l_error_count     NUMBER := 0;
    l_success_count   NUMBER := 0;
    l_new_count       NUMBER := 0;
    l_total_count     NUMBER := 0;
    l_duplicate_count NUMBER := 0;

    l_exclusion_exists VARCHAR2(1);

    l_out_err_header VARCHAR2(2000) := 'Condition Group,Condition Value,';
    l_out_err_line   VARCHAR2(2000);
    l_pl_value       VARCHAR2(200);

    stop_processing EXCEPTION;
  BEGIN

    fnd_file.put_line(fnd_file.log,
                      'START xxqp_utils_pkg.upload_exclusions_pivot');
    dbms_output.put_line('START xxqp_utils_pkg.upload_exclusions_pivot');
    --fnd_file.put_line(fnd_file.log, 'REQUEST_ID = ' || l_request_id);

    l_request_id := fnd_global.conc_request_id;

    IF p_directory IS NULL THEN
      l_error_message := 'Missing parameter p_directory';
      RAISE stop_processing;
    END IF;

    l_file_handler := utl_file.fopen(location  => p_directory,
                                     filename  => p_file_name,
                                     open_mode => 'R');

    fnd_file.put_line(fnd_file.log,
                      'File ' || ltrim(p_file_name) ||
                      ' Is open For Reading ');
    dbms_output.put_line('File ' || ltrim(p_file_name) ||
                         ' Is open For Reading');

    --Get the First Line for Category Assignment from pivot excel file

    utl_file.get_line(l_file_handler, l_line, 1000);

    --utl_file.get_line(l_file_handler, l_raw, 2000);
    -- add dummy char if string start with comma
    IF instr(l_line, ',') = 1 THEN
      l_line := 'x' || l_line;
    END IF;

    fnd_file.put_line(fnd_file.log,
                      'Reading pricelists from first line ' || l_line);
    dbms_output.put_line('Reading pricelists from first line');

    -- remove comma between "
    --l_line := regexp_replace(l_line, '((\"|^).*?(\"|$))|,', '\1 ');

    IF instr(l_line, 'ERR_MESSAGE') > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        'ERROR: The datafile template is not correct. Please remove the Error Message column before submitting program again');
      l_error_message := 'ERROR: The datafile template is not correct. Please remove the Error Message column before submitting program again';
      RAISE stop_processing;
    END IF;

    FOR i IN c_split(l_line) LOOP
      IF l_col_cnt > 1 THEN
        --dbms_output.put_line('rowcount: '||c_split%ROWCOUNT-2);
        l_pricelists_arr(c_split%ROWCOUNT - 2) := rtrim(i.val, chr(13));

        fnd_file.put_line(fnd_file.log,
                          'Pricelist=' ||
                          l_pricelists_arr(c_split%ROWCOUNT - 2));
        dbms_output.put_line('Pricelist=' ||
                             l_pricelists_arr(c_split%ROWCOUNT - 2));
      END IF;

      l_col_cnt := c_split%ROWCOUNT;
    END LOOP;

    l_col_cnt := l_col_cnt - 2;

    -- read line 2 ...N  data and insert into table
    BEGIN

      LOOP
        BEGIN
          l_line_no_blank := NULL;
          utl_file.get_line(l_file_handler, l_line, 1000);
          -- remove comma between "
          --l_line := regexp_replace(l_line, '((\"|^).*?(\"|$))|,', '\1 ');

          /*dbms_output.put_line('Line: '||l_line||' '||instr(l_line,',',-1)||' '||length(l_line));

          if instr(l_line,',',-1) = length(l_line) then
            l_line_no_blank := l_line||'NULL';
          end if;

          l_line_no_blank := replace(nvl(l_line_no_blank,l_line),',,',',NULL,');

          dbms_output.put_line('Line: '||instr(l_line,','));
          --  process 2-N records
          -- split record and insert data to table
          dbms_output.put_line('Line no blank: '||l_line_no_blank);

          l_line := l_line_no_blank;*/

          l_line := REPLACE(l_line, ',', ', ');

          FOR j IN 1 .. l_pricelists_arr.count() LOOP
            --IF i = 1 THEN
            dbms_output.put_line('Count: ' || j);

            l_cond_group := TRIM(regexp_replace(l_line, '^([^,]*).*$', '\1'));

            l_cond_value := TRIM(regexp_substr(l_line, '[^,]+', 1, 2));

            l_attr := nvl(TRIM(regexp_substr(l_line, '[^,]+', 1, j + 2)),
                          'NULL');
            l_attr := nvl(REPLACE(l_attr, chr(13), ''), 'NULL');

            dbms_output.put_line('1Pricelist= Cond Group: ' ||
                                 l_cond_group || ' Cond Value: ' ||
                                 l_cond_value || ' Attribute: ' || l_attr);
            log('1Pricelist= Cond Group: ' || l_cond_group ||
                ' Cond Value: ' || l_cond_value || ' Attribute: ' ||
                l_attr);

            IF l_cond_group IS NULL AND l_cond_value IS NULL AND
               l_attr = 'NULL' THEN
              log('Line skiped: No data provided on this line');
            ELSE
              /*begin
                select xh.rule_id
                  into l_rule_id
                  from xxom_pl_upd_rule_header xh,
                       qp_list_headers_vl qlv
                 where qlv.NAME = l_pricelists_arr(j)
                   and qlv.LIST_HEADER_ID = xh.list_header_id;


              exception when no_data_found then

              end;*/

              l_attr_y_n := 'Y';
              BEGIN
                l_attr_num_check := to_number(l_attr);
              EXCEPTION
                WHEN value_error THEN
                  l_attr_num_check := NULL;
                  IF l_attr NOT IN ('Y', 'N', 'NULL', 'D') THEN
                    l_attr_y_n := 'N';
                  END IF;
              END;

              IF l_attr <> 'NULL' THEN
                INSERT INTO xxom_pl_upd_exception_stg
                  (price_list_name,
                   condition_group,
                   condition_value,
                   fixed_price,
                   excluded_flag,
                   delete_rec,
                   last_update_by,
                   last_update_date,
                   creation_date,
                   created_by,
                   last_update_login,
                   request_id,
                   status,
                   status_message)
                VALUES
                  (l_pricelists_arr(j),
                   l_cond_group,
                   l_cond_value,
                   l_attr_num_check, --decode(l_attr,'Y',null,'N',null,'NULL',null,l_attr),
                   decode(l_attr, 'Y', 'Y', 'N', 'N', NULL),
                   decode(l_attr, 'D', 'Y', 'N'),
                   fnd_global.user_id,
                   SYSDATE,
                   SYSDATE,
                   fnd_global.user_id,
                   fnd_global.login_id,
                   l_request_id,
                   decode(l_attr_y_n, 'Y', 'N', 'E'),
                   decode(l_attr_y_n,
                          'Y',
                          NULL,
                          'ERROR: Excluded flag must be Y or N. Enter D to remove existing record.' ||
                          chr(13)));
              END IF;

              COMMIT;
            END IF;
          END LOOP;
        EXCEPTION
          WHEN no_data_found THEN
            EXIT;
        END;
        COMMIT;
      END LOOP;
    END;

    -- 3 - Update ID in staging table and validate data
    --for data_rec in (select stg1.*,rowid rid from XXOM_PL_UPD_EXCEPTION_STG stg1 where request_id = l_request_id)
    --loop
    BEGIN
      UPDATE xxom_pl_upd_exception_stg stg
         SET rule_id         =
             (SELECT xh.rule_id
                FROM xxom_pl_upd_rule_header xh, qp_list_headers_vl qlv
               WHERE qlv.name = stg.price_list_name
                 AND qlv.list_header_id = xh.list_header_id),
             last_update_date = SYSDATE
       WHERE stg.request_id = l_request_id;
      /*where stg.rowid = data_rec.rid;*/

      UPDATE xxom_pl_upd_exception_stg stg
         SET status           = 'E',
             status_message   = status_message ||
                                'ERROR: Pricelist name is not valid' ||
                                chr(13),
             last_update_date = SYSDATE
       WHERE rule_id IS NULL
         AND request_id = l_request_id;

    EXCEPTION
      WHEN no_data_found THEN
        UPDATE xxom_pl_upd_exception_stg stg
           SET status           = 'E',
               status_message   = status_message || 'ERROR: Pricelist name ' ||
                                  stg.price_list_name || ' is not valid' ||
                                  chr(13),
               last_update_date = SYSDATE
         WHERE rule_id IS NULL
           AND request_id = l_request_id; --stg.rowid = data_rec.rid;
      WHEN OTHERS THEN
        l_sql_err_msg := SQLERRM;

        UPDATE xxom_pl_upd_exception_stg stg
           SET status           = 'E',
               status_message   = status_message || 'ERROR: ' ||
                                  l_sql_err_msg,
               last_update_date = SYSDATE
         WHERE rule_id IS NULL
           AND request_id = l_request_id;
    END;

    -- Validate for duplicate condition group and value in same load
    FOR rec_validate IN (SELECT DISTINCT price_list_name,
                                         condition_group,
                                         condition_value
                           FROM xxom_pl_upd_exception_stg
                          WHERE request_id = l_request_id) LOOP
      SELECT COUNT(1)
        INTO l_duplicate_count
        FROM xxom_pl_upd_exception_stg
       WHERE request_id = l_request_id
         AND price_list_name = rec_validate.price_list_name
         AND condition_group = rec_validate.condition_group
         AND condition_value = rec_validate.condition_value;

      IF l_duplicate_count > 1 THEN
        UPDATE xxom_pl_upd_exception_stg
           SET status         = 'E',
               status_message = status_message ||
                                'ERROR: The same pricelist, condition group and condition value exists multiple times in file ' ||
                                chr(13)
         WHERE request_id = l_request_id
           AND price_list_name = rec_validate.price_list_name
           AND condition_group = rec_validate.condition_group
           AND condition_value = rec_validate.condition_value;
      END IF;
    END LOOP;

    -- Validate condition group is valid
    UPDATE xxom_pl_upd_exception_stg stg
       SET stg.status         = 'E',
           stg.status_message = status_message ||
                                'ERROR: Condition group provided is not valid' ||
                                chr(13),
           last_update_date   = SYSDATE
     WHERE (SELECT COUNT(1)
              FROM fnd_flex_values_vl ffv, fnd_flex_value_sets ffvs
             WHERE ffvs.flex_value_set_name = 'XXOM_PL_UPD_CATEGORY'
               AND ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffv.enabled_flag = 'Y'
               AND ffv.flex_value = stg.condition_group) = 0
       AND stg.request_id = l_request_id;

    -- Validate condition value is valid
    validate_excl_cat_val(l_cat_val_retcode,
                          l_cat_val_retmsg,
                          l_request_id);

    IF l_cat_val_retcode = 1 THEN
      l_error_message := l_cat_val_retmsg;

      RAISE stop_processing;
    END IF;
    /*update XXOM_PL_UPD_EXCEPTION_STG stg
      set stg.status = 'E', stg.status_message = status_message||'ERROR: The exclusion condition and value already exists for this pricelist'||CHR(13),
          last_update_date = sysdate
    where stg.request_id = l_request_id
      and exists (select 1
                    from xxom_pl_upd_rule_exception xre
                   where xre.rule_id = stg.rule_id
                     and xre.condition_group = stg.condition_group
                     and xre.condition_value = stg.condition_value);*/

    --end loop;
    COMMIT;

    -- Check error records for the load
    SELECT COUNT(1)
      INTO l_error_count
      FROM xxom_pl_upd_exception_stg
     WHERE status = 'E'
       AND request_id = l_request_id;

    IF l_error_count = 0 THEN
      BEGIN
        -- Delete exclusion rules marked for removal in load file
        FOR rec_del IN (SELECT rule_id, condition_group, condition_value
                          FROM xxom_pl_upd_exception_stg stg
                         WHERE status = 'N'
                           AND request_id = l_request_id
                           AND delete_rec = 'Y') LOOP
          DELETE FROM xxom_pl_upd_rule_exception
           WHERE rule_id = rec_del.rule_id
             AND condition_group = rec_del.condition_group
             AND condition_value = rec_del.condition_value;
        END LOOP;

        -- Mark all records with remove flag as success
        UPDATE xxom_pl_upd_exception_stg
           SET status         = 'S',
               status_message = 'Record removed successfully.'
         WHERE status = 'N'
           AND request_id = l_request_id
           AND delete_rec = 'Y';

        -- Load records from staging to exclusion table
        FOR success_rec IN (SELECT stg.*, ROWID rid
                              FROM xxom_pl_upd_exception_stg stg
                             WHERE status = 'N'
                               AND request_id = l_request_id) LOOP
          l_exclusion_exists := 'N';
          BEGIN
            SELECT 'Y'
              INTO l_exclusion_exists
              FROM xxom_pl_upd_rule_exception xre
             WHERE xre.rule_id = success_rec.rule_id
               AND xre.condition_group = success_rec.condition_group
               AND xre.condition_value = success_rec.condition_value;
          EXCEPTION
            WHEN no_data_found THEN
              l_exclusion_exists := 'N';
          END;

          IF l_exclusion_exists = 'N' THEN
            INSERT INTO xxom_pl_upd_rule_exception
              (rule_id,
               condition_group,
               condition_value,
               fixed_price,
               exclude_flag,
               last_update_date,
               last_updated_by,
               creation_date,
               created_by,
               last_update_login,
               exception_id)
            VALUES
              (success_rec.rule_id,
               success_rec.condition_group,
               success_rec.condition_value,
               success_rec.fixed_price,
               nvl(success_rec.excluded_flag, 'N'),
               SYSDATE,
               fnd_global.user_id,
               SYSDATE,
               fnd_global.user_id,
               fnd_global.login_id,
               xxom_pl_upd_rule_exception_seq.nextval);
          ELSE
            UPDATE xxom_pl_upd_rule_exception
               SET fixed_price       = success_rec.fixed_price,
                   exclude_flag      = nvl(success_rec.excluded_flag, 'N'),
                   last_update_date  = SYSDATE,
                   last_updated_by   = fnd_global.user_id,
                   last_update_login = fnd_global.login_id
             WHERE rule_id = success_rec.rule_id
               AND condition_group = success_rec.condition_group
               AND condition_value = success_rec.condition_value;

          END IF;

          UPDATE xxom_pl_upd_exception_stg
             SET status         = 'S',
                 status_message = 'Record imported successfully'
           WHERE ROWID = success_rec.rid;
        END LOOP;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          l_error_message := l_error_message ||
                             ' ERROR: While inserting to base table ' ||
                             SQLERRM;
          RAISE stop_processing;
      END;
      --else
      -- update XXOM_PL_UPD_EXCEPTION_STG
    END IF;

    SELECT COUNT(1)
      INTO l_new_count
      FROM xxom_pl_upd_exception_stg
     WHERE status = 'N'
       AND request_id = l_request_id;
    SELECT COUNT(1)
      INTO l_success_count
      FROM xxom_pl_upd_exception_stg
     WHERE status = 'S'
       AND request_id = l_request_id;
    SELECT COUNT(1)
      INTO l_total_count
      FROM xxom_pl_upd_exception_stg
     WHERE request_id = l_request_id;

    IF l_error_count > 0 THEN
      fnd_file.put_line(fnd_file.output,
                        'Pricelist Name, Condition Group, Condition Value, Fixed Price, Excluded Flag, Error Message');
      FOR err_rec IN (SELECT *
                        FROM xxom_pl_upd_exception_stg stg
                       WHERE status = 'E'
                         AND request_id = l_request_id) LOOP
        fnd_file.put_line(fnd_file.output,
                          err_rec.price_list_name || ',' ||
                          err_rec.condition_group || ',' ||
                          err_rec.condition_value || ',' ||
                          err_rec.fixed_price || ',' ||
                          err_rec.excluded_flag || ',"' ||
                          rtrim(err_rec.status_message, chr(13)) || '"');
      END LOOP;
      /*for err_rec in (select distinct price_list_name
                        from XXOM_PL_UPD_EXCEPTION_STG stg
                       where stg.status = 'E' and request_id = l_request_id
                       order by price_list_name)
      loop
        --fnd_file.put_line(fnd_file.OUTPUT, 'Condition Group,Condition Value');
        l_out_err_header := l_out_err_header||err_rec.price_list_name||',';

      end loop;

      l_out_err_header := l_out_err_header||'ERR_MESSAGE';
      fnd_file.put_line(fnd_file.OUTPUT, l_out_err_header);

      for err_rec_line in (select distinct stg.condition_group, stg.condition_value
                        from XXOM_PL_UPD_EXCEPTION_STG stg
                       where stg.status = 'E' and request_id = l_request_id
                       order by stg.condition_group, stg.condition_value)
      loop

        l_out_err_line := err_rec_line.condition_group||','||err_rec_line.condition_value||',';

        for err_rec_pl_values in (select distinct price_list_name
                        from XXOM_PL_UPD_EXCEPTION_STG stg
                       where stg.status = 'E' and request_id = l_request_id
                       order by price_list_name)
        loop
          begin
            log('TEST: '||err_rec_pl_values.price_list_name);

            select coalesce(stg1.excluded_flag,to_char(stg1.fixed_price))
              into l_pl_value
              from XXOM_PL_UPD_EXCEPTION_STG stg1
             where request_id = l_request_id
               and stg1.status = 'E'
               and price_list_name = err_rec_pl_values.price_list_name
               and stg1.condition_group = err_rec_line.condition_group
               and stg1.condition_value = err_rec_line.condition_value;

          exception when no_data_found then
            l_pl_value := '';
          end;

          l_out_err_line := l_out_err_line||l_pl_value||',';
        end loop;

        fnd_file.put_line(fnd_file.OUTPUT, l_out_err_line);
      end loop;*/

    END IF;

    IF l_total_count = l_success_count THEN
      retcode := '0';
      errbuf  := 'SUCCESS';
    ELSIF l_total_count = l_error_count THEN
      retcode := '2';
      errbuf  := 'ERROR';
    ELSE
      retcode := '1';
      errbuf  := 'WARNING';
    END IF;

    -- 4 - Process staging reords

    utl_file.fclose(l_file_handler);
    fnd_file.put_line(fnd_file.log,
                      'xxqp_utils_pkg.upload_exclusions_pivot COMPLETED');
  EXCEPTION
    WHEN utl_file.invalid_path THEN
      retcode := '1';
      errbuf  := errbuf || 'Invalid Path for ' || ltrim(p_file_name) ||
                 chr(0);
    WHEN utl_file.invalid_mode THEN
      retcode := '1';
      errbuf  := errbuf || 'Invalid Mode for ' || ltrim(p_file_name) ||
                 chr(0);
    WHEN utl_file.invalid_operation THEN
      retcode := '1';
      errbuf  := errbuf || 'Invalid operation for ' || ltrim(p_file_name) ||
                 SQLERRM || chr(0);
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := '1';
      errbuf  := l_error_message;
    WHEN OTHERS THEN
      l_error_message := 'Unexpected Error in upload_exclusions_pivot):' ||
                         SQLERRM;
      fnd_file.put_line(fnd_file.log, l_error_message);
      dbms_output.put_line(l_error_message);
      errbuf  := l_error_message;
      retcode := '2';
  END upload_exclusions_pivot;



  --------------------------------------------------------------------
  --  Name      :        handle_audit_insert
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     04/12/2017
  --------------------------------------------------------------------
  --  Purpose :          CHG0040166 - This procedure will be used to
  --                     insert audit information into custom audit table
  --                     for every change in record of the setup tables
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  04/12/2017    Diptasurjya Chatterjee       Initial Build
  --  1.1  03/12/2018    Diptasurjya Chatterjee       CHG0042537 - Populate xxom_pl_upd_rule_header_b
  --                                                  with columns mentioned, as new columns added is causing issues
  --------------------------------------------------------------------
  PROCEDURE handle_audit_insert(p_table_name IN VARCHAR2, p_id IN NUMBER) AS
    PRAGMA AUTONOMOUS_TRANSACTION;

  BEGIN
    IF p_table_name = 'XXOM_PL_UPD_RULE_HEADER' THEN
      INSERT INTO xxom_pl_upd_rule_header_b
        (rule_id,
         seq_num,
         list_header_id,
         change_method,
         change_type,
         master_list_header_id,
         --source_code,  -- INC0175350 comment
         last_update_date,
         last_updated_by,
         creation_date,
         created_by,
         last_update_login,
         pl_active,
         round_factor,
         round_method,
         min_price,
         product_precedence,
         start_date_active,
         end_date_active)
        SELECT tt.rule_id,
               tt.seq_num,
               tt.list_header_id,
               tt.change_method,
               tt.change_type,
               tt.master_list_header_id,
               --tt.source_code,  -- INC0175350 comment
               tt.last_update_date,
               tt.last_updated_by,
               tt.creation_date,
               tt.created_by,
               tt.last_update_login,
               tt.pl_active,
               tt.round_factor,
               tt.round_method,
               tt.min_price,
               tt.product_precedence,
               tt.last_update_date,
               SYSDATE
          FROM xxom_pl_upd_rule_header tt
         WHERE rule_id = p_id;
    ELSIF p_table_name = 'XXOM_PL_UPD_RULE_EXCEPTION' THEN
      INSERT INTO xxom_pl_upd_rule_exception_b
        SELECT tt.*, tt.last_update_date, SYSDATE
          FROM xxom_pl_upd_rule_exception tt
         WHERE exception_id = p_id;
    ELSIF p_table_name = 'XXOM_PL_UPD_RULE_GROUPS' THEN
      INSERT INTO xxom_pl_upd_rule_groups_b
        SELECT tt.*, tt.last_update_date, SYSDATE
          FROM xxom_pl_upd_rule_groups tt
         WHERE group_id = p_id;
    ELSE
      INSERT INTO xxom_pl_upd_rule_lines_b
        SELECT tt.*, tt.last_update_date, SYSDATE
          FROM xxom_pl_upd_rule_lines tt
         WHERE line_id = p_id;
    END IF;

    COMMIT;
  END handle_audit_insert;

  --------------------------------------------------------------------------------------------
  -- Object Name   : move_output_file
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  FUNCTION move_output_file(p_source_filename IN VARCHAR2,
                            p_source_dir IN VARCHAR2,
                            p_target_filename IN VARCHAR2,
                            p_target_dir IN VARCHAR2) RETURN VARCHAR2 IS
    l_error_message    VARCHAR2(2000);
    l_dest_directory   VARCHAR2(1000);
    l_source_directory VARCHAR2(1000);
    l_request_id       NUMBER;
    l_prg_exe_counter  VARCHAR2(10);
    l_completed        BOOLEAN;
    l_phase            VARCHAR2(200);
    l_vstatus          VARCHAR2(200);
    l_dev_phase        VARCHAR2(200);
    l_dev_status       VARCHAR2(200);
    l_message          VARCHAR2(200);
    l_status_code      VARCHAR2(1);
    move_submit_excp EXCEPTION;
    move_error       EXCEPTION;
    move_warning     EXCEPTION;

  BEGIN

    l_prg_exe_counter := '1';
    l_error_message   := 'Error Occured while deriving Source Directory';
    SELECT directory_path
    INTO   l_source_directory
    FROM   all_directories
    WHERE  directory_name IN (p_source_dir);

    l_prg_exe_counter := '2';
    l_error_message   := 'Error Occured while deriving Destination Directory';
    SELECT directory_path
    INTO   l_dest_directory
    FROM   all_directories
    WHERE  directory_name IN (p_target_dir);

    l_prg_exe_counter := '3';

    log('attachment file size: '||fnd_profile.VALUE('XXQP_PL_APPROVAL_ATTACH_MAX_SIZE_BYTES'));

    l_error_message := 'Error Occured while Calling the Move Host Program';
    l_request_id    := fnd_request.submit_request(application => 'XXOBJT',
				  program     => 'XXCPFILE_ZIP',
				  argument1   => l_source_directory, -- from_dir
				  argument2   => p_source_filename, -- from_file_name
				  argument3   => l_dest_directory, -- to_dir
				  argument4   => p_target_filename, -- to_file_name
          argument5   => 'Y', -- Zip oversize file
          argument6   => fnd_profile.VALUE('XXQP_PL_APPROVAL_ATTACH_MAX_SIZE_BYTES') -- Max file size before starting to zip
				  );
    COMMIT;
    l_prg_exe_counter := '4';

    IF l_request_id = 0 THEN
      l_prg_exe_counter := '5';
      l_error_message   := 'Move Program Could not be submitted.' ||
		   ' Error Message :' || l_error_message;
      RAISE move_submit_excp;

    ELSE
      l_prg_exe_counter := '6';
      apps.fnd_file.put_line(apps.fnd_file.log,
		     'Submitted the Move concurrent program with request_id :' ||
		     l_request_id);
    END IF;

    l_prg_exe_counter := '7';
    --Wait for the completion of the concurrent request (if submitted successfully)
    l_error_message := 'Error Occured while Waiting for the completion of the Move concurrent request';
    l_completed     := apps.fnd_concurrent.wait_for_request(request_id => l_request_id,
					INTERVAL   => 10,
					max_wait   => 3600, -- 60 Minutes
					phase      => l_phase,
					status     => l_vstatus,
					dev_phase  => l_dev_phase,
					dev_status => l_dev_status,
					message    => l_message);

    l_prg_exe_counter := '8';

    /*---------------------------------------------------------------------------------------
      -- Check for the Concurrent Program status
    ------------------------------------------------------------------------------------*/
    l_error_message := 'Error Occured while deriving the status code of the submitted program';
    SELECT status_code
    INTO   l_status_code
    FROM   fnd_concurrent_requests
    WHERE  request_id = l_request_id;

    l_prg_exe_counter := '9';

    IF l_status_code = 'E' -- Error
     THEN
      l_prg_exe_counter := '10';
      l_error_message   := 'Move Program Request with Request ID :' ||
		   l_request_id || ' completed in Error';
      RAISE move_error;

    ELSIF l_status_code = 'G' -- Warning
     THEN
      l_prg_exe_counter := '11';
      l_error_message   := 'Move Program Request with Request ID :' ||
		   l_request_id || ' completed in Warning';
      RAISE move_warning;

    ELSIF l_status_code = 'C' -- Sucess
     THEN
      l_prg_exe_counter := '12';
      fnd_file.put_line(fnd_file.log, 'Move Program Completed Sucessfully');
      l_error_message := NULL;
    END IF;

    l_prg_exe_counter := '13';
    RETURN(l_error_message);

  EXCEPTION
    WHEN move_submit_excp THEN
      RETURN(l_error_message);
    WHEN move_error THEN
      RETURN(l_error_message);
    WHEN move_warning THEN
      RETURN(l_error_message);
    WHEN OTHERS THEN
      RETURN(l_error_message || '-' || l_prg_exe_counter || '-' || SQLERRM);
  END move_output_file;

  --------------------------------------------------------------------------------------------
  -- Object Name:  get_notification_body
  -- Type       :  Procedure
  -- Create By  :  Diptasurjya Chatterjee
  -- Creation Date: 18-Jul-2019
  -- Purpose    :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  PROCEDURE get_notification_body(document_id   IN VARCHAR2,
		          display_type  IN VARCHAR2,
		          document      IN OUT NOCOPY CLOB,
		          document_type IN OUT NOCOPY VARCHAR2) IS

    g_item_type VARCHAR2(100) := 'XXWFDOC';

    l_doc_instance_id NUMBER;
    l_history_clob    CLOB;
    l_mail_body  varchar2(4000);
    -- l_body_msg        VARCHAR2(32767);

    l_simulation_name  varchar2(240);
    l_approval_type_code varchar2(240);
    g_doc_code       VARCHAR2(240) := 'PL_SIM_APPROVAL';
  BEGIN

    l_doc_instance_id := to_number(document_id);

    SELECT xpa.approval_type_code, '<table cellpadding="1" cellspacing="1" border="1">
                                     <tr><td style="background-color:#cfe0f1; font-size:9pt;font-weight:bold">Simulation Name</td><td>'||xph.simulation_name||'</td></tr>
                                     <tr><td style="background-color:#cfe0f1; font-size:9pt;font-weight:bold">Simulation Date</td><td>'||xph.simulation_run_date||'</td></tr>
                                     <tr><td style="background-color:#cfe0f1; font-size:9pt;font-weight:bold">Simulated By</td><td>'||xph.simulated_by_username||'</td></tr>
                                     <tr><td style="background-color:#cfe0f1; font-size:9pt;font-weight:bold">PL Name</td><td>'||xph.price_list_name||'</td></tr>
                                     <tr><td style="background-color:#cfe0f1; font-size:9pt;font-weight:bold">Item Code</td><td>'||xph.item_code||'</td></tr>
                                     <tr><td style="background-color:#cfe0f1; font-size:9pt;font-weight:bold">Effective Date</td><td>'||xph.effective_date||'</td></tr></table>'
    INTO   l_approval_type_code, l_mail_body
    FROM   xxobjt_wf_docs           a,
           xxobjt_wf_doc_instance   b,
           xxqp_pl_upd_sim_approval xpa,
           xxom_pl_upd_simulation_hdr xph
    WHERE  a.doc_id = b.doc_id
    AND    a.doc_code = g_doc_code
    AND    b.n_attribute1 = xpa.simulation_approval_id
    AND    b.doc_instance_id = l_doc_instance_id
    AND    xpa.simulation_id = xph.simulation_id;


    document_type := 'text/html';
    document      := ' ';
    dbms_lob.append(document,
	        '<p> <font face="Verdana" style="color:darkblue" size="3">
	        <strong>PL Simulation Approval workflow - '||l_approval_type_code||'</strong> </font> </p>');
    dbms_lob.append(document,
	        '<font face="arial" style="color:black;" size="2">Pricelist simulation requires your approval. <br>Check attached file for all items whose price will be added or updated in Oracle Price List.<br>Simulation Details are:</font>');
    dbms_lob.append(document,l_mail_body);

    -- add history
    l_history_clob := NULL;
    dbms_lob.append(document,
	        '</br> </br><p> <font face="Verdana" style="color:darkblue" size="3"> <strong>Action History</strong> </font> </p>');
    xxobjt_wf_doc_rg.get_history_wf(document_id   => document_id,
			display_type  => '',
			document      => l_history_clob,
			document_type => document_type);

    dbms_lob.append(document, l_history_clob);

  END get_notification_body;

  --------------------------------------------------------------------------------------------
  -- Object Name   : get_approver
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  PROCEDURE get_approver(x_err_code        OUT NUMBER,
		 x_err_message     OUT VARCHAR2,
		 p_doc_instance_id IN NUMBER,
		 p_entity          IN VARCHAR2,
		 x_role_name       OUT VARCHAR2) IS

    g_doc_code       VARCHAR2(240) := 'PL_SIM_APPROVAL';

    CURSOR c_doc IS
      SELECT d.doc_code,
	           t.n_attribute1
      FROM   xxobjt_wf_doc_instance t,
	           xxobjt_wf_docs         d
      WHERE  t.doc_instance_id = p_doc_instance_id
      AND    d.doc_id = t.doc_id;

  BEGIN
    x_err_code := 0;

    if p_entity = 'FIRST' then
      select fu.user_name
        into x_role_name
        from fnd_flex_value_sets ffvs,
             fnd_flex_values_vl ffv,
             XXQP_PL_UPD_SIM_APPROVAL xpa,
             xxobjt_wf_doc_instance t,
             xxobjt_wf_docs         d,
             fnd_user fu
       where ffvs.flex_value_set_name = 'XXQP_PL_SIM_APPROVAL_HIERARCHY'
         and ffvs.flex_value_set_id = ffv.FLEX_VALUE_SET_ID
         and ffv.FLEX_VALUE = xpa.approval_type_code
         and t.doc_id = d.doc_id
         and n_attribute1 = xpa.simulation_approval_id
         and d.doc_code = g_doc_code
         and t.doc_instance_id = p_doc_instance_id
         and to_char(fu.user_id) = ffv.ATTRIBUTE2
         and ffv.ENABLED_FLAG = 'Y'
         and sysdate between nvl(ffv.START_DATE_ACTIVE, sysdate-1) and nvl(ffv.END_DATE_ACTIVE, sysdate+1);
    end if;

    IF x_role_name IS NULL THEN
      x_err_code    := 1;
      x_err_message := 'No Approver Found for Role ';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code    := 1;
      x_err_message := 'No Approver Found for Role ';

  END get_approver;

  --------------------------------------------------------------------------------------------
  -- Object Name   : mail_simulation_error
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  procedure mail_simulation_error(errbuf OUT varchar2,
                                  retcode OUT number,
                                  p_simulation_id IN number) is

    l_requestor_mail  varchar2(2000);
    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
    l_err_rpt_request_id  number := fnd_global.CONC_REQUEST_ID;
    l_gen_rep_status      VARCHAR2(20);
    l_gen_rep_msg         varchar2(4000);

    cursor exception_cur is
     select xpu.item_code, xph.simulation_name
       from xxom_pl_upd_simulation xpu,
            xxom_pl_upd_simulation_hdr xph
      where xpu.simulation_id = p_simulation_id
        and xpu.simulation_id = xph.simulation_id
        and xpu.api_eligible is not null
        and xpu.approval_type is null
        and not exists (select 1
                     from fnd_flex_value_sets ffvs,
                          fnd_flex_values ffv,
                          qp_list_headers_all qh
                    where ffvs.flex_value_set_name = 'XXQP_APPROVAL_EXCLUDE_PRICELISTS'
                      and ffvs.flex_value_set_id = ffv.flex_value_set_id
                      and qh.NAME = ffv.flex_value
                      and qh.LIST_HEADER_ID = xpu.list_header_id
                      and ffv.enabled_flag = 'Y'
                      and sysdate between nvl(ffv.start_date_active, sysdate-1) and nvl(ffv.end_date_active,sysdate+1));
  begin
    retcode := 0;
    errbuf := null;

    l_requestor_mail := xxhr_util_pkg.get_person_email(fnd_global.EMPLOYEE_ID);
    log('DCCNT email: '||fnd_global.EMPLOYEE_ID||l_requestor_mail);

    l_xxssys_generic_rpt_rec.request_id      := l_err_rpt_request_id;
    l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
    l_xxssys_generic_rpt_rec.email_to        := 'EMAIL';
    l_xxssys_generic_rpt_rec.col1            := 'Simulation Name';
    l_xxssys_generic_rpt_rec.col2            := 'Item Code';
    l_xxssys_generic_rpt_rec.col_msg         := 'Error Message';

    xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
                                                  x_return_status          => l_gen_rep_status,
                                                  x_return_message         => l_gen_rep_msg);

    IF l_gen_rep_status <> 'S' THEN
      fnd_file.PUT_LINE(fnd_file.LOG,'Error Report exception: ' || l_gen_rep_msg);
    END IF;
    log('DCCNT after header insert '||p_simulation_id);
    for exception_rec in exception_cur loop

      l_xxssys_generic_rpt_rec.request_id      := l_err_rpt_request_id;
      l_xxssys_generic_rpt_rec.header_row_flag := 'N';
      l_xxssys_generic_rpt_rec.email_to        := l_requestor_mail;
      l_xxssys_generic_rpt_rec.col1            := exception_rec.simulation_name;
      l_xxssys_generic_rpt_rec.col2            := exception_rec.item_code;
      l_xxssys_generic_rpt_rec.col_msg         := 'Item could not be classified into CS/SALES etc. for WF approval. Contact IT with this list.';

      xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
                                                                    x_return_status          => l_gen_rep_status,
                                                                    x_return_message         => l_gen_rep_msg);
      IF l_gen_rep_status <> 'S' THEN
        fnd_file.PUT_LINE(fnd_file.LOG,'Error Report exception: ' || l_gen_rep_msg);
      END IF;
    end loop;

    xxssys_generic_rpt_pkg.submit_request(p_burst_flag         => 'Y',
                                          p_request_id         => l_err_rpt_request_id,
                                          p_l_report_title     => '''' ||
                                                                          'PL Simulation - Item could not be classified'|| '''',
                                          p_l_email_subject    => '''' ||
                                                                          'PL Simulation - Item could not be classified' || '''',
                                          p_l_email_body1      => '''' ||
                                                                          'Please find the error report of simulation items which could not be properly classified in CS/SALES/SPARE PART etc' || '''',
                                          p_l_order_by         => 'col2',
                                          p_l_file_name        => '''' ||
                                                                          'PL_Simulation_Item_Issue' || '''',
                                          p_l_purge_table_flag => 'Y',
                                          x_return_status      => l_gen_rep_status,
                                          x_return_message     => l_gen_rep_msg);

    commit;

    IF l_gen_rep_status <> 'S' THEN
      retcode := 2;
      errbuf := 'ERROR: While submitting generic error report for Simulation Missing Approvals. '||l_gen_rep_msg;
      fnd_file.PUT_LINE(fnd_file.LOG,errbuf);
    end if;

  exception when others then
    retcode := 2;
    errbuf := 'UNEXPECTED ERROR: While submitting generic error report for Simulation Missing Approvals. Contact IT. '||sqlerrm;
    fnd_file.PUT_LINE(fnd_file.LOG,errbuf);
  end mail_simulation_error;

  --------------------------------------------------------------------------------------------
  -- Object Name   : initiate_approval
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  PROCEDURE initiate_approval(errbuf        OUT VARCHAR2,
		      retcode       OUT NUMBER,
		      p_simulation_id NUMBER) IS

    l_doc_instance_id NUMBER;

    l_err_code NUMBER;
    l_key VARCHAR2(50);

    l_chk_cnt number;

    l_approval_eligible_recs number;
    l_validated_item_id number;
    l_simulation_approval_id number;

    l_sim_no_approver_cnt number;

    l_doc_instance_header xxobjt_wf_doc_instance%ROWTYPE;

    l_classify_retcode number;
    l_classify_errbuf varchar2(4000);


    g_doc_code        VARCHAR2(240) := 'PL_SIM_APPROVAL';

    l_request_id      number;



    cursor approvals_cur is
      select distinct xph.simulation_name,xpu.approval_type
        from xxom_pl_upd_simulation xpu,
             xxom_pl_upd_simulation_hdr xph
       where xpu.simulation_id = p_simulation_id
         and approval_type is not null
         and xpu.simulation_id = xph.simulation_id
         and not exists (select 1 from xxqp_pl_upd_sim_approval xpa where xpa.simulation_id = xpu.simulation_id
         and xpa.approval_type_code = xpu.approval_type);

    gen_exception EXCEPTION;
  BEGIN
    retcode := 0;
    errbuf := null;

    select count(1) into l_approval_eligible_recs from xxom_pl_upd_simulation where simulation_id = p_simulation_id and api_eligible is not null;

    if l_approval_eligible_recs = 0 then
      retcode := 2;
      errbuf := 'No pricing changes identified during selected simulation. Approval WF is not applicable.';
      return;
    end if;

    begin
      classify_sim_approval_type(p_simulation_id,
                                 l_classify_retcode,
                                 l_classify_errbuf);
       log('DCCNT After class');
      if l_classify_retcode <> 0 then
        retcode := 2;
        errbuf := 'ERROR: While classifying simulation data into proper approval tracks. '||l_classify_errbuf;
        return;
      else
        select count(1)
          into l_sim_no_approver_cnt
          from xxom_pl_upd_simulation xpu,
               xxom_pl_upd_simulation_hdr xph
         where xpu.simulation_id = p_simulation_id
           and xpu.simulation_id = xph.simulation_id
           and xpu.api_eligible is not null
           and xpu.approval_type is null
           and not exists (select 1
                             from fnd_flex_value_sets ffvs,
                                  fnd_flex_values ffv,
                                  qp_list_headers_all qh
                            where ffvs.flex_value_set_name = 'XXQP_APPROVAL_EXCLUDE_PRICELISTS'
                              and ffvs.flex_value_set_id = ffv.flex_value_set_id
                              and qh.NAME = ffv.flex_value
                              and qh.LIST_HEADER_ID = xpu.list_header_id
                              and ffv.enabled_flag = 'Y'
                              and sysdate between nvl(ffv.start_date_active, sysdate-1) and nvl(ffv.end_date_active,sysdate+1));

        if l_sim_no_approver_cnt > 0 then
          l_request_id := fnd_request.submit_request(
                          application         => 'XXOBJT',
                          program             => 'XXQP_SIM_APPR_CLASS_ERR_MAIL',
                          description         => '',
                          start_time          => '',
                          sub_request         => FALSE,
                          argument1           => p_simulation_id
                        );
          commit;

          if l_request_id = 0 then
            retcode := 2;
            errbuf := 'ERROR: Some items on this simulation failed to be classified for WF approval. Contact IT for list of failed items.';
          else
            retcode := 2;
            errbuf := 'ERROR: Some items on this simulation failed to be classified for WF approval. Please check mail for error report. Request ID: '||l_request_id;
          end if;

          return;
        end if;
      end if;
    exception when others then
      retcode := 2;
      errbuf := 'UNEXPECTED ERROR: While classifying simulation data into proper approval tracks. '||sqlerrm;
      return;
    end;

    for approvals_rec in approvals_cur loop
      insert into XXQP_PL_UPD_SIM_APPROVAL
        (SIMULATION_APPROVAL_ID,
         SIMULATION_ID,
         APPROVAL_TYPE_CODE,
         APPROVAL_STATUS,
         CREATED_BY,
         CREATION_DATE,
         LAST_UPDATED_BY,
         LAST_UPDATE_DATE,
         LAST_UPDATE_LOGIN)
      values (XXQP_PL_UPD_SIM_APPROVAL_SEQ.Nextval,
              p_simulation_id,
              approvals_rec.approval_type,
              'NEW',
              fnd_global.USER_ID,
              sysdate,
              fnd_global.USER_ID,
              sysdate,
              fnd_global.LOGIN_ID)
      returning SIMULATION_APPROVAL_ID into l_simulation_approval_id;

      update xxom_pl_upd_simulation
         set simulation_approval_id = l_simulation_approval_id
       where simulation_id = p_simulation_id
         and approval_type = approvals_rec.approval_type;
    end loop;

    commit;




    --  Create instance
    -- Initiating Workflow Document Instance
    ----------------------------------------------
    for appr_rec in (select simulation_approval_id,APPROVAL_TYPE_CODE  from XXQP_PL_UPD_SIM_APPROVAL where simulation_id = p_simulation_id and approval_status = 'NEW') loop
      --Check if  there is already workflow in status IN_PROCESS ,SUCCESS for item
      l_doc_instance_id := null;
      l_doc_instance_header := null;

      BEGIN

        SELECT t.doc_instance_id
        INTO   l_doc_instance_id
        FROM   xxobjt_wf_doc_instance t,
               xxobjt_wf_docs         d
        WHERE  t.doc_id = d.doc_id
        AND    n_attribute1 = appr_rec.simulation_approval_id
        AND    doc_status IN ('NEW', 'IN_PROCESS', 'SUCCESS')
        AND    d.doc_code = g_doc_code;


        errbuf  := 'Unable to submit WF for simulation_id='||p_simulation_id||' and entity='||appr_rec.APPROVAL_TYPE_CODE  ||', there is already Active/Success workflow no :' ||l_doc_instance_id;

        log(errbuf);

        continue;
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;


      l_doc_instance_header.user_id             := fnd_global.user_id;
      l_doc_instance_header.resp_id             := fnd_global.resp_id;
      l_doc_instance_header.resp_appl_id        := fnd_global.resp_appl_id;
      l_doc_instance_header.requestor_person_id := fnd_global.employee_id;
      l_doc_instance_header.creator_person_id   := fnd_global.employee_id;

      l_doc_instance_header.n_attribute1 := appr_rec.simulation_approval_id;

      log('Create Instance');
      xxobjt_wf_doc_util.create_instance(p_err_code            => l_err_code,
           p_err_msg             => errbuf,
           p_doc_instance_header => l_doc_instance_header,
           p_doc_code            => g_doc_code);

      IF l_err_code != 0 THEN

        log('ERROR: in create instance for simulation_approval_id = '||appr_rec.simulation_approval_id||' Msg: ' || errbuf);
        rollback;
        update XXQP_PL_UPD_SIM_APPROVAL
           set approval_status = 'ERROR',
               status_message = substr(errbuf,1,2000)
         where simulation_approval_id = appr_rec.simulation_approval_id;
        commit;

        continue;
      END IF;

      log('Create Instance:l_doc_instance_header.doc_instance_id=' ||
             l_doc_instance_header.doc_instance_id);

      -- Initiate approval

      xxobjt_wf_doc_util.initiate_approval_process(p_err_code        => l_err_code,
           p_err_msg         => errbuf,
           p_doc_instance_id => l_doc_instance_header.doc_instance_id,
           p_wf_item_key     => l_key);

      log('WF initiated for simulation_approval_id = '||appr_rec.simulation_approval_id||'. WF Item Key: ' || l_key);

      IF l_err_code != 0 THEN

        log('ERROR: in initiate approval for simulation_approval_id = '||appr_rec.simulation_approval_id||' Msg: ' || errbuf);
        rollback;
        update XXQP_PL_UPD_SIM_APPROVAL
           set approval_status = 'ERROR',
               status_message = substr(errbuf,1,2000)
         where simulation_approval_id = appr_rec.simulation_approval_id;
        commit;
      else
        update XXQP_PL_UPD_SIM_APPROVAL set approval_status = 'INITIATED' where simulation_approval_id = appr_rec.simulation_approval_id;

        update XXOM_PL_UPD_SIMULATION_HDR set simulation_status='PENDING_APPROVAL' where simulation_id = p_simulation_id;
        commit;
      END IF;
    end loop;

    errbuf := null;

    for err_rec in (select xph.simulation_name, xpa.APPROVAL_TYPE_CODE
                      from XXQP_PL_UPD_SIM_APPROVAL xpa, XXOM_PL_UPD_SIMULATION_HDR xph
                     where xpa.simulation_id = p_simulation_id and xpa.approval_status = 'ERROR'
                     and xpa.simulation_id = xph.simulation_id)
    loop
      errbuf := errbuf||' ERROR: Approval workflow initiation failed for simulation: '||err_rec.simulation_name||' and '||err_rec.approval_type_code||' items.'||chr(13);
      retcode := 2;
    end loop;


  EXCEPTION
    WHEN gen_exception THEN
      retcode := 2;
    WHEN OTHERS THEN
      log(SQLERRM);
      retcode := 2;
  END initiate_approval;

  --------------------------------------------------------------------------------------------
  -- Object Name   : submit_not_attch_report
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  PROCEDURE submit_not_attch_report(p_doc_instance_id IN NUMBER,
		  p_err_code        OUT NUMBER,
		  p_err_message     OUT VARCHAR2) IS
    l_instance_rec            xxobjt_wf_doc_instance%ROWTYPE;
    l_simulation_id  number;
    rpt_submit_excp EXCEPTION;
    rpt_error       EXCEPTION;
    rpt_warning     EXCEPTION;
    l_approval_type_code VARCHAR2(200);
    l_layout             BOOLEAN;
    l_request_id        NUMBER;
    l_completed         BOOLEAN;
    l_phase             VARCHAR2(200);
    l_vstatus           VARCHAR2(200);
    l_dev_phase         VARCHAR2(200);
    l_dev_status        VARCHAR2(200);
    l_message           VARCHAR2(200);
    l_status_code       VARCHAR2(1);
    l_prg_exe_counter   VARCHAR2(10);
    l_error_message     VARCHAR2(2000);
    l_move_msg          VARCHAR2(32767);
    move_file_excp      EXCEPTION;
    l_source_filename         VARCHAR2(1000);
    l_target_filename         VARCHAR2(1000);

    g_doc_code          VARCHAR2(240) := 'PL_SIM_APPROVAL';
    g_item_type         VARCHAR2(100) := 'XXWFDOC';
    c_debug_module      VARCHAR2(100) := 'xxqp_utils_pkg.';
  BEGIN
    l_prg_exe_counter := '1';
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'submit_not_attch_report',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_doc_instance_id :' || p_doc_instance_id);

    l_prg_exe_counter := '2';
    l_error_message   := 'Error Occured while deriving l_instance_rec';
    l_instance_rec    := xxobjt_wf_doc_util.get_doc_instance_info(p_doc_instance_id);

    l_prg_exe_counter := '3';
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'submit_not_attch_report',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_doc_instance_id :' || p_doc_instance_id ||
		        ' l_instance_rec.user_id :' ||
		        l_instance_rec.user_id ||
		        ' l_instance_rec.resp_id :' ||
		        l_instance_rec.resp_id ||
		        ' l_instance_rec.resp_appl_id :' ||
		        l_instance_rec.resp_appl_id);

    l_prg_exe_counter         := '4';
    l_error_message           := 'Error Occured while deriving l_approval_type_code';
    SELECT xpa.simulation_id,xpa.APPROVAL_TYPE_CODE
    INTO   l_simulation_id,l_approval_type_code
    FROM   xxobjt_wf_docs           a,
           xxobjt_wf_doc_instance   b,
           xxqp_pl_upd_sim_approval xpa
    WHERE  a.doc_id = b.doc_id
    AND    a.doc_code = g_doc_code
    AND    b.n_attribute1 = xpa.simulation_approval_id
    AND    b.doc_instance_id = p_doc_instance_id;

    l_prg_exe_counter := '5';
    l_error_message   := 'Error Occured while Initializing Apps Session';
    fnd_global.apps_initialize(user_id      => l_instance_rec.user_id,
		       resp_id      => l_instance_rec.resp_id,
		       resp_appl_id => l_instance_rec.resp_appl_id);

    l_prg_exe_counter := '6';

    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'submit_not_attch_report',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id ||
		        ' p_doc_instance_id :' || p_doc_instance_id || 'l_item_key :' ||
		        l_instance_rec.wf_item_key);

    l_prg_exe_counter := '7';
    l_error_message   := 'Error Occured while submitting Payment Process Request Status Report Concurrent request';
    l_layout := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                       template_code      => 'XXOM_PL_UPD_OUTPUT_LOG',
                                       template_language  => 'en',
                                       template_territory => 'US',
                                       output_format      => 'EXCEL');
    l_layout := fnd_request.set_print_options(copies => 0);

    l_request_id      := fnd_request.submit_request(application => 'XXOBJT',
                                                    program     => 'XXOM_PL_UPD_OUTPUT_LOG',
                                                    description => NULL,
                                                    start_time  => SYSDATE,
                                                    sub_request => FALSE,
                                                    argument1   => null,
                                                    argument2   => l_simulation_id,
                                                    argument3   => l_approval_type_code);
    COMMIT;

    l_prg_exe_counter := '8';
    IF l_request_id = 0 THEN
      l_prg_exe_counter := '5';
      RAISE rpt_submit_excp;
    END IF;

    l_prg_exe_counter := '9';

    l_error_message := 'Error Occured while assigning value for attribute REQUEST_ID, Value:' ||
	           l_request_id;
    wf_engine.setitemattrnumber(itemtype => g_item_type,
		        itemkey  => l_instance_rec.wf_item_key,
		        aname    => 'REQUEST_ID',
		        avalue   => l_request_id);

    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module || 'submit_not_attch_report',
	       message   => 'l_request_id' || l_request_id);

    l_prg_exe_counter := '10';
    --Wait for the completion of the concurrent request (if submitted successfully)
    l_error_message := 'Error Occured while Waiting for the completion of the PL Simulation Log Report concurrent request';
    l_completed     := apps.fnd_concurrent.wait_for_request(request_id => l_request_id,
					INTERVAL   => 1,
					max_wait   => 3600, -- 60 Minutes
					phase      => l_phase,
					status     => l_vstatus,
					dev_phase  => l_dev_phase,
					dev_status => l_dev_status,
					message    => l_message);

    l_prg_exe_counter := '11';

    /*---------------------------------------------------------------------------------------
      -- Check for the Concurrent Program status
    ------------------------------------------------------------------------------------*/
    l_error_message := 'Error Occured while deriving the status code of the PL Simulation Log Report';
    SELECT status_code
    INTO   l_status_code
    FROM   fnd_concurrent_requests
    WHERE  request_id = l_request_id;

    l_prg_exe_counter := '12';

    IF l_status_code = 'E' -- Error
     THEN
      l_prg_exe_counter := '13';
      l_error_message   := 'PPL Simulation Log Request with Request ID :' ||
		   l_request_id || ' completed in Error';
      RAISE rpt_error;

    ELSIF l_status_code = 'G' -- Warning
     THEN
      l_prg_exe_counter := '14';
      l_error_message   := 'PL Simulation Log request with Request ID :' ||
		   l_request_id || ' completed in Warning';
      RAISE rpt_warning;

    ELSIF l_status_code = 'C' -- Sucess
     THEN
      l_prg_exe_counter := '15';
      l_source_filename       := 'XXOM_PL_UPD_OUTPUT_LOG_' || l_request_id || '_1.xls';
      l_target_filename       := 'PL_Simulation_Approval_' || l_approval_type_code || '_'||l_simulation_id||'.xls';
      l_move_msg        := '';

      l_error_message   := 'Error Occured in function move_output_file';
      l_move_msg        := move_output_file(l_source_filename,'XXFND_OUT_DIR',l_target_filename,'XXQP_PL_SIM_APPR_ATTMNT_DIR');
      l_prg_exe_counter := '16';
      IF l_move_msg IS NOT NULL THEN
        l_error_message   := l_move_msg;
        l_prg_exe_counter := '17';
        RAISE move_file_excp;
      END IF;

      p_err_code    := '0';
      p_err_message := NULL;

      l_prg_exe_counter := '18';

    END IF;

    l_prg_exe_counter := '19';

  EXCEPTION
    WHEN rpt_submit_excp THEN
      p_err_code    := '1';
      p_err_message := l_error_message || '-' || l_prg_exe_counter;
    WHEN rpt_error THEN
      p_err_code    := '1';
      p_err_message := l_error_message || '-' || l_prg_exe_counter;
    WHEN rpt_warning THEN
      p_err_code    := '1';
      p_err_message := l_error_message || '-' || l_prg_exe_counter;
    WHEN move_file_excp THEN
      p_err_code    := '1';
      p_err_message := l_error_message || '-' || l_prg_exe_counter;
    WHEN OTHERS THEN
      p_err_code    := '1';
      p_err_message := l_error_message || '-' || l_prg_exe_counter || '-' ||
	           SQLERRM;
      -- Debug Message
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module || 'submit_not_attch_report',
	         message   => 'OTHERS EXCEPTION' || ' p_err_message :' ||
		          p_err_message);
  END submit_not_attch_report;

  --------------------------------------------------------------------------------------------
  -- Object Name   : get_notification_attachment
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  PROCEDURE get_notification_attachment(document_id   IN VARCHAR2,
			    display_type  IN VARCHAR2,
			    document      IN OUT BLOB,
			    document_type IN OUT VARCHAR2) IS

    l_doc_instance_id         NUMBER;
    l_simulation_id           NUMBER;
    l_approval_type_code      VARCHAR2(200);
    source_bfile              BFILE;
    dest_lob                  BLOB := NULL; --empty_blob();
    offset                    NUMBER := 1;
    l_file_name               VARCHAR2(200);
    l_file_name_zip           VARCHAR2(200);
    l_directory               VARCHAR2(100) := 'XXQP_PL_SIM_APPR_ATTMNT_DIR';
    l_error_message           VARCHAR2(2000);
    l_request_id              NUMBER;
    l_prg_exe_counter         VARCHAR2(20);
    l_item_key                VARCHAR2(100);

    l_is_attchmnt_zip         varchar2(1) := 'N';
    g_doc_code                VARCHAR2(240) := 'PL_SIM_APPROVAL';
    g_item_type               VARCHAR2(100) := 'XXWFDOC';
    c_debug_module            VARCHAR2(100) := 'xxqp_utils_pkg.';
  BEGIN

    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'get_notification_attachment',
	       message   => 'fnd_global.user_id=' || fnd_global.user_id ||
		        ' fnd_global.resp_id=' || fnd_global.resp_id ||
		        ' fnd_global.resp_appl_id=' ||
		        fnd_global.resp_appl_id ||
		        ' fnd_global.employee_id=' ||
		        fnd_global.employee_id || 'document_id :' ||
		        document_id || 'display_type :' ||
		        display_type);

    l_prg_exe_counter := '1';

    l_error_message   := 'Error Occured while deriving l_doc_instance_id';
    l_doc_instance_id := to_number(document_id);

    l_prg_exe_counter := '2';
    l_item_key        := '';
    l_error_message   := 'get_notification_attachment: Error Occured while deriving l_item_key';
    SELECT b.wf_item_key, xpa.approval_type_code, xpa.simulation_id
    INTO   l_item_key, l_approval_type_code, l_simulation_id
    FROM   xxobjt_wf_docs         a,
           xxobjt_wf_doc_instance b,
           xxqp_pl_upd_sim_approval xpa
    WHERE  a.doc_id = b.doc_id
    AND    a.doc_code = g_doc_code
    AND    b.doc_instance_id = l_doc_instance_id
    AND    xpa.simulation_approval_id = b.n_attribute1;

    l_prg_exe_counter := '3';
    l_error_message   := 'Error Occured while deriving l_request_id';
    l_request_id      := wf_engine.getitemattrnumber(itemtype => g_item_type,
				     itemkey  => l_item_key,
				     aname    => 'REQUEST_ID');

    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
	       module    => c_debug_module ||
		        'get_notification_attachment',
	       message   => 'l_request_id' || l_request_id);

    l_prg_exe_counter := '4';
    l_file_name       := '';
    l_error_message   := 'Error Occured while deriving l_file_name';
    l_file_name       := 'PL_Simulation_Approval_' || l_approval_type_code || '_'||l_simulation_id||'.xls';
    l_file_name_zip   := 'PL_Simulation_Approval_' || l_approval_type_code || '_'||l_simulation_id||'.zip';
    l_prg_exe_counter := '5';

    while true
    loop
      begin
        /* loading data from a file into BLOB variable */
        l_error_message := 'Error Occured in dbms_lob.createtemporary';
        -- Creates a temporary BLOB or CLOB and its corresponding index in the user's default temporary tablespace
        dbms_lob.createtemporary(dest_lob, TRUE, dbms_lob.session);

        l_prg_exe_counter := '6';

        l_error_message := 'Error Occured in bfilename';
        -- BFILE Returns a BFILE locator that is associated with a physical LOB binary file on the server file system.
        source_bfile := bfilename(l_directory, l_file_name);

        l_prg_exe_counter := '7';

        l_error_message := 'Error Occured in dbms_lob.fileopen';
        -- procedure opens a BFILE for read-only access. BFILE data may not be written through the database.
        dbms_lob.fileopen(source_bfile, dbms_lob.file_readonly);

        exit; -- if file open is successful, end loop
      exception when others then
        l_file_name := l_file_name_zip;
        l_is_attchmnt_zip := 'Y';
      end;
    end loop;


    l_prg_exe_counter := '8';

    l_error_message := 'Error Occured in dbms_lob.loadblobfromfile';
    -- loads data from BFILE to internal BLOB.
    dbms_lob.loadblobfromfile(dest_lob    => dest_lob,
		      src_bfile   => source_bfile,
		      amount      => dbms_lob.getlength(source_bfile),
		      dest_offset => offset,
		      src_offset  => offset);

    l_prg_exe_counter := '9';

    l_error_message := 'Error Occured in dbms_lob.fileclose';
    -- closes a BFILE that has already been opened through the input locator.
    dbms_lob.fileclose(source_bfile);

    l_prg_exe_counter := '10';
    l_error_message   := 'Error Occured in document_type';
    if l_is_attchmnt_zip = 'Y' then
      document_type     := 'application/zip' || ';name='||l_file_name_zip; --|| filename;
    else
      document_type     := 'application/vnd.ms-excel' || ';name='||l_file_name; --|| filename;
    end if;

    l_prg_exe_counter := '11';
    l_error_message   := 'Error Occured in dbms_lob.copy';
    dbms_lob.copy(document, dest_lob, dbms_lob.getlength(dest_lob));
    l_prg_exe_counter := '12';

    l_prg_exe_counter := '13';

  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_event,
	         module    => c_debug_module ||
		          'get_notification_attachment',
	         message   => 'OTHERS Exception SQL Error :' || SQLERRM);
      wf_core.context('xxqp_utils_pkg',
	          'get_notification_attachment',
	          document_id,
	          display_type,
	          l_error_message || '-' || l_prg_exe_counter || '-' ||
	          SQLERRM);
      RAISE;
  END get_notification_attachment;

  --------------------------------------------------------------------------------------------
  -- Object Name   : abort_approval
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  procedure abort_approval(errbuf OUT varchar2,
                           retcode OUT number,
                           p_simulation_id IN number) is

    g_doc_code                VARCHAR2(240) := 'PL_SIM_APPROVAL';

    l_abort_errbuf  varchar2(2000);
    l_abort_retcode number;

    cursor cur_approvals is
	  SELECT t.doc_instance_id
      FROM   xxobjt_wf_doc_instance t,
             xxobjt_wf_docs         d,
             xxqp_pl_upd_sim_approval xpa
      WHERE  t.doc_id = d.doc_id
      AND    n_attribute1 = xpa.simulation_approval_id
      AND    d.doc_code = g_doc_code
      and    xpa.simulation_id = p_simulation_id;
  begin
    retcode := 0;
    errbuf := null;

    for rec in cur_approvals loop
      xxobjt_wf_doc_util.abort_process(p_doc_instance_id => rec.doc_instance_id,
                                       p_err_code => l_abort_retcode,
                                       p_err_msg => l_abort_errbuf);

      if l_abort_retcode <> 0 then
        errbuf := l_abort_errbuf;
        retcode := 2;

        return;
      end if;
    end loop;

    begin
      update xxom_pl_upd_simulation set approval_type=null, simulation_approval_id=null where simulation_id = p_simulation_id;
      update XXOM_PL_UPD_SIMULATION_HDR set simulation_status='SIMULATED' where simulation_id=p_simulation_id;
      delete from XXQP_PL_UPD_SIM_APPROVAL where simulation_id=p_simulation_id;

      commit;
    exception when others then
      retcode := 2;
      errbuf := 'ERROR: While removing approval records from simulation tables. Contact IT.';
      rollback;
    end;
  exception when others then
    retcode := 2;
    errbuf := 'ERROR: While aborting approval workflow. Contact IT. '||sqlerrm;
  end abort_approval;


  --------------------------------------------------------------------------------------------
  -- Object Name   : post_wf_action
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  procedure post_wf_action(p_doc_instance_id IN number,
                           p_action IN varchar2,
                           errbuf OUT varchar2,
                           retcode OUT number) is

    g_doc_code                VARCHAR2(240) := 'PL_SIM_APPROVAL';

    l_simulation_name varchar2(240);
    l_simulation_id number;
    l_simulation_approval_id number;
    l_approval_status varchar2(200);
    l_creator_user_id number;
    l_creator_user_name varchar2(240);
    l_approver_user_id number;
    l_unapproved_cnt number;
    l_abort_errbuf  varchar2(2000);
    l_abort_retcode number;
  begin
    retcode := 0;
    errbuf := null;

    if p_action not in ('A','R') then
      errbuf := 'Wrong call to WF post action program';
      retcode := 2;

      return;
    end if;

    if p_action = 'A' then
      l_approval_status := 'APPROVED';
    else
      l_approval_status := 'REJECTED';
    end if;


    SELECT xpa.simulation_approval_id,
           xpa.simulation_id,
           fu.user_id,
           t.user_id,
           xph.simulated_by_username,
           xph.simulation_name
      INTO l_simulation_approval_id,
           l_simulation_id,
           l_approver_user_id,
           l_creator_user_id,
           l_creator_user_name,
           l_simulation_name
      FROM xxobjt_wf_doc_instance t,
           xxobjt_wf_docs         d,
           xxqp_pl_upd_sim_approval xpa,
           xxom_pl_upd_simulation_hdr xph,
           fnd_user fu
     WHERE t.doc_id = d.doc_id
       AND n_attribute1 = xpa.simulation_approval_id
       AND d.doc_code = g_doc_code
       AND t.doc_instance_id = p_doc_instance_id
       and t.approver_person_id = fu.employee_id
       and xph.simulation_id = xpa.simulation_id;


    update xxqp_pl_upd_sim_approval xpa
       set xpa.approval_status = l_approval_status,
           xpa.last_updated_by = l_approver_user_id,
           xpa.last_update_date = sysdate,
           xpa.last_update_login = fnd_global.LOGIN_ID
     where xpa.simulation_approval_id = l_simulation_approval_id
       and xpa.approval_status <> l_approval_status;

    commit;

    if l_approval_status = 'REJECTED' then
      update xxom_pl_upd_simulation_hdr xph
         set xph.simulation_status=l_approval_status,
             xph.simulation_status_message = 'One or more approvers have rejected this simulation',
             xph.sim_approve_reject_date=sysdate,
             xph.last_updated_by=l_approver_user_id,
             xph.last_update_date=sysdate,
             xph.last_update_login=fnd_global.LOGIN_ID
       where xph.simulation_id = l_simulation_id
         and xph.simulation_status <> l_approval_status;

      commit;

      -- Cancel all open WF approvals for this simulation
      for cancel_rec in (SELECT t.doc_instance_id, xpa.simulation_approval_id,fu.user_name
                  FROM   xxobjt_wf_doc_instance t,
                         xxobjt_wf_docs         d,
                         xxqp_pl_upd_sim_approval xpa,
                         fnd_user fu
                  WHERE  t.doc_id = d.doc_id
                  AND    n_attribute1 = xpa.simulation_approval_id
                  AND    d.doc_code = g_doc_code
                  and    xpa.simulation_id = l_simulation_id
                  and    t.approver_person_id = fu.employee_id
                  and    sysdate between nvl(fu.start_date, sysdate-1) and nvl(fu.end_date,sysdate+1)
                  and    xpa.approval_status = 'INITIATED') loop
        l_abort_retcode := null;
        l_abort_errbuf := null;

        xxobjt_wf_doc_util.abort_process(p_doc_instance_id => cancel_rec.doc_instance_id,
                                         p_err_code => l_abort_retcode,
                                         p_err_msg => l_abort_errbuf);

        if l_abort_retcode <> 0 then
          send_mail(
            p_subject         => 'ERROR - While cancelling open approvals for : '||l_simulation_name,
	          p_body            => 'Dear user, The open approval processes for Pricelist simulation '||l_simulation_name||' could not be aborted due to unexpected errors. Please contact IT. Thanks and Regards',
            p_user_to         => l_creator_user_name);
        else
          send_mail(
            p_subject         => 'CANCELLED - No further action required for simulation: '||l_simulation_name,
	          p_body            => 'Dear user, The approval process for Pricelist simulation '||l_simulation_name||' has been aborted due to rejection by one or more approvers. Please ignore any approval notifications you have received for this simulation. Thanks and Regards',
            p_user_to         => cancel_rec.user_name);

          update XXQP_PL_UPD_SIM_APPROVAL set approval_status = 'CANCELLED' where simulation_approval_id=cancel_rec.simulation_approval_id;
          commit;
        end if;
      end loop;

    else
      select count(1)
        into l_unapproved_cnt
        from xxqp_pl_upd_sim_approval xpa
       where xpa.simulation_id = l_simulation_id
         and nvl(xpa.approval_status,'NA') <> l_approval_status;

      if l_unapproved_cnt = 0 then
        update xxom_pl_upd_simulation_hdr xph
           set xph.simulation_status=l_approval_status,
               xph.simulation_status_message = 'All approvers have approved this simulation',
               xph.sim_approve_reject_date=sysdate,
               xph.last_updated_by=l_approver_user_id,
               xph.last_update_date=sysdate,
               xph.last_update_login=fnd_global.LOGIN_ID
         where xph.simulation_id = l_simulation_id
           and xph.simulation_status <> l_approval_status;

        commit;

        send_mail(
            p_subject         => 'APPROVED - All approvers have approved simulation: '||l_simulation_name,
	          p_body            => 'Dear user, All required approvers have approved the Pricelist simulation '||l_simulation_name||' . You can now update prices to the pricelist. Please note that this simulation will expire in 7 days. Thanks and Regards',
            p_user_to         => l_creator_user_name);
      end if;
    end if;
  exception when others then
    retcode := 2;
    errbuf := 'ERROR: While performing post-WF-action activities. Contact IT. '||sqlerrm;
  end post_wf_action;



  --------------------------------------------------------------------------------------------
  -- Object Name   : simulation_expiration
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  procedure simulation_expiration(errbuf OUT varchar2,
                           retcode OUT number) is

    l_notify_req_before_days number := fnd_profile.VALUE('XXQP_PL_SIMULATION_EXPIRY_NOTIFY_DAYS');
    l_sim_expiration_days number := fnd_profile.VALUE('XXQP_PL_SIMULATION_EXPIRY_DAYS');
    l_expired_flag  varchar2(1);
    l_days_to_expire number;
    l_notice_subject  varchar2(240);
    l_body varchar2(2000);
    l_days number;
    l_hours number;
  begin
    retcode := 0;
    errbuf := null;

    for approved_rec in (select * from xxom_pl_upd_simulation_hdr where simulation_status = 'APPROVED') loop
      l_body := null;
      l_notice_subject := null;

      l_days_to_expire := trunc(approved_rec.sim_approve_reject_date + l_sim_expiration_days + 1) - sysdate;



      if l_days_to_expire <= 0 then
        update xxom_pl_upd_simulation_hdr xph
           set xph.simulation_status='EXPIRED',
               xph.simulation_status_message = 'Simulation expired',
               xph.simulation_expiration_date = sysdate,
               xph.last_updated_by=fnd_global.USER_ID,
               xph.last_update_date=sysdate,
               xph.last_update_login=fnd_global.LOGIN_ID
         where xph.simulation_id = approved_rec.simulation_id;

        l_notice_subject := 'PL Simulation expiry notice - ' ||approved_rec.simulation_name;
        l_body := 'Dear user, Approved pricelist simulation '||approved_rec.simulation_name||' has expired today.';

        send_mail(
                  p_subject         => l_notice_subject,
                  p_body            => l_body,
                  p_user_to         => approved_rec.simulated_by_username);

        continue;
      end if;



      if l_days_to_expire <= l_notify_req_before_days then
        l_days := trunc(l_days_to_expire);
        l_hours := ceil((l_days_to_expire-l_days)*24);

        l_notice_subject := 'PL Simulation expiry ADVANCE notice - ' ||approved_rec.simulation_name;
        l_body:= 'Dear user, Approved pricelist simulation '||approved_rec.simulation_name||' will expire in '||l_days||' days '||l_hours||' hours.';


        send_mail(
            p_subject         => l_notice_subject,
	          p_body            => l_body,
            p_user_to         => approved_rec.simulated_by_username);
      end if;

    end loop;

    commit;
  exception when others then
    retcode := 2;
    errbuf := 'ERROR: While checking approved PL simulations for expiration. Contact IT. '||sqlerrm;
  end simulation_expiration;

END xxqp_utils_pkg;
/
