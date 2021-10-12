create or replace package body xxcst_ratam_pkg IS

  --------------------------------------------------------------------
  --  name:              XXCST_RATAM_PKG
  --  create by:         AVIH
  --  Revision:          1.0
  --  creation date:      02/07/2009 15:30:25
  --------------------------------------------------------------------
  --  purpose :          Handle Unrealized Profit Customization
  -----------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  02/07/2009   AVIH               initial build
  --  1.1  07/04/2013    Ofer Suad   Add SSYS Item
  --  1.2  04/07/2013    Ofer Suad   Fix query of FDM items
  --  1.3  26/03/2014    Ofer Suad   CHG0031726 - satndard cost changes
  --  1.4  01-Sep-2014   Ofer Suad   CHG0033161 - Add org standard cost
  --  1.5  10-Mar-2015   Ofer Suad   CHG0034713 - Seprate lines per inventory org standard cost.
  --  1.6  11-Jun-2015   Ofer Suad   CHG0035657 - Remove trancate from call to  CST_Inventory_PUB.Calculate_InventoryValue
  --  1.7  08-Sep-2015   Ofer Suad   CHG0036330-  Change RTS queryy
  --  1.8  08-Mar-2016   Ofer Suad   CHG0037762 - FDM Items with Country Of Origin
  --  1.9  06-Nov-2016               CHG0039638 - bug fix and support BI logic
  --  2.0  20-09-2018    Ofer Suad   CHG0042478 - Automtically choose time based on location Operating unit timezone
  --                                              and do not take T&B that return to NA subinv

  -- 2.1  20-Feb-2019    Ofer Suad   CHG0045166 - As of date and Ratam report as of date  not shifted by timezone
  -- 2.2  02-Sep-2019    Bellona B.  CHG0046373 - Unrealizes report does not pull correct IC invoices for IP marked items
  -- 2.3  20-jan-2020    Ofer Suad   CHG0046935 - Try and But items which system but not printer
  -- 2.4  12/03/2020     Roman W.    INC0186239 - rollback to CHG0046373
  -- 2.5  20/04/2020     Ofer Suad   CHG0047477  - Change logic of function to get MFG Org to support new technologies
  -- 2.6  09/02/2021     Ofer Suad   CHG0049395 - Ratam report does  not show T&B items and IN US there is difference from as of date report  in some items 
  ------------------------------------------------------
  v_user_id        fnd_user.user_id%TYPE;
  v_login_id       fnd_logins.login_id%TYPE;
  v_is_lookup_init number := 0;

  PROCEDURE calculatequantityforinvorg(errbuf           IN OUT VARCHAR2,
                                       retcode          IN OUT VARCHAR2,
                                       p_asofdate       IN VARCHAR2,
                                       p_subs_inv_orgid IN NUMBER,
                                       p_israel_orgid   IN NUMBER,
                                       p_item_id        IN NUMBER) IS
    v_p_asofdate DATE;

    l_return_status VARCHAR2(1000);
    l_msg_count     NUMBER(20);
    l_msg_data      VARCHAR2(1000);
    l_cst_inv_val EXCEPTION;

    v_op_name          hr_all_organization_units.name%TYPE;
    v_categsetid       mtl_category_sets_tl.category_set_id%TYPE;
    v_invorgstk        NUMBER;
    v_invorgit         NUMBER;
    v_invorgrcv        NUMBER;
    v_itemcoststk      NUMBER;
    v_itemcostit       NUMBER;
    v_itemcostrcv      NUMBER;
    v_itemcostgen      NUMBER;
    v_orgid            NUMBER;
    v_org_asofdate     DATE; --CHG0042478 - Automtically choose time based on location Operating unit timezone
    v_server_time_zone varchar2(50); --CHG0042478 - Automtically choose time based on location Operating unit timezone

    CURSOR cr_getorgid_items IS
      SELECT msi.organization_id,
             msi.inventory_item_id,
             msi.segment1,
             msi.primary_uom_code
        FROM mtl_system_items_b msi
       WHERE msi.organization_id = p_subs_inv_orgid
         AND EXISTS
       (SELECT 'X'
                FROM mtl_system_items_b isrmsi
               WHERE isrmsi.organization_id IN
                     (SELECT hoi.organization_id
                        FROM hr_organization_information hoi
                       WHERE hoi.org_information_context =
                             'Accounting Information'
                         AND hoi.org_information3 = p_israel_orgid)
                 AND isrmsi.inventory_item_id = msi.inventory_item_id)
         AND (msi.inventory_item_id = p_item_id OR p_item_id IS NULL)
       ORDER BY msi.organization_id, msi.inventory_item_id;

  BEGIN
    SELECT trunc(to_date(p_asofdate, 'YYYY/MM/DD HH24:MI:SS'))
      INTO v_p_asofdate
      FROM dual;
    -- strat CHG0042478 - Automtically choose time based on location Operating unit timezone
    v_org_asofdate := null;
    begin
      --CHG0045166 - As of date and Ratam report as of date  not shifted by timezone
      /* select v.timezone_code
       into v_server_time_zone
       FROM FND_TIMEZONES_VL v
      where v.UPGRADE_TZ_ID = fnd_profile.VALUE('SERVER_TIMEZONE_ID');*/

      select CAST(FROM_TZ(CAST((to_date(p_asofdate, 'YYYY/MM/DD HH24:MI:SS')) AS
                               TIMESTAMP),
                          hl.timezone_code) AT TIME ZONE v.timezone_code AS DATE)
        into v_org_asofdate
        from org_organization_definitions od,
             hr_locations_all             hl,
             HR_ORGANIZATION_UNITS        hu,
             FND_TIMEZONES_VL             v
       where od.ORGANIZATION_ID = p_subs_inv_orgid
         and hl.location_id = hu.location_id
         and od.OPERATING_UNIT = hu.organization_id
         and v.UPGRADE_TZ_ID = fnd_profile.VALUE('SERVER_TIMEZONE_ID');
    exception
      when others then
        v_org_asofdate := to_date(p_asofdate, 'YYYY/MM/DD HH24:MI:SS');
        fnd_file.PUT_LINE(fnd_file.LOG,
                          'Error while setting Timezone for org ' ||
                          p_subs_inv_orgid);
        retcode := '2';
        errbuf  := 'Error while setting Timezone for org ' ||
                   p_subs_inv_orgid || ' . ' || substr(sqlerrm, 1, 2000);
    end;
    -- End CHG0045166
    if v_org_asofdate is null then
      v_org_asofdate := to_date(p_asofdate, 'YYYY/MM/DD HH24:MI:SS');
    end if;

    fnd_file.PUT_LINE(fnd_file.LOG,
                      ' v_org_asofdate ' ||
                      to_char(v_org_asofdate, 'YYYY/MM/DD HH24:MI:SS'));
    -- end CHG0042478 - Automtically choose time based on location Operating unit timezone
    -- Get Objet Main Cateory, On Which All Items Will Be Included
    SELECT mcs.category_set_id
      INTO v_categsetid
      FROM mtl_category_sets_tl mcs
     WHERE mcs.category_set_name = 'Main Category Set'
       AND mcs.language = userenv('LANG');
    -- Get Operating Unit Of Given INV Organization
    SELECT ou.name, ou.organization_id
      INTO v_op_name, v_orgid
      FROM hr_organization_information hoi, hr_all_organization_units ou
     WHERE ou.organization_id = hoi.org_information3
       AND hoi.org_information_context = 'Accounting Information'
       AND hoi.organization_id = p_subs_inv_orgid;
    -- Delete Previous Running
    DELETE FROM xxobjt.xxobjt_ratam_qty_subs a
     WHERE a.organization_id = p_subs_inv_orgid
       AND (a.item_id = p_item_id OR p_item_id IS NULL)
       AND a.date_as_of = v_p_asofdate;

    fnd_profile.get(NAME => 'USER_ID', val => v_user_id);
    fnd_profile.get(NAME => 'LOGIN_ID', val => v_login_id);
    cst_inventory_pub.calculate_inventoryvalue(p_api_version     => 1.0,
                                               p_organization_id => p_subs_inv_orgid,
                                               p_onhand_value    => 1,
                                               p_intransit_value => 1,
                                               p_receiving_value => 1,
                                               p_valuation_date  => v_org_asofdate, --CHG0042478 - Automtically choose time based on location Operating unit timezone
                                               --to_date(p_asofdate,
                                               --       'YYYY/MM/DD HH24:MI:SS') + 1, --CHG0035657 - Remove trancate from call to  CST_Inventory_PUB.Calculate_InventoryValue
                                               p_cost_type_id    => fnd_profile.value('XX_COST_TYPE'), --2,
                                               p_item_from       => NULL,
                                               p_item_to         => NULL,
                                               p_category_set_id => v_categsetid,
                                               p_receipt         => 1,
                                               p_shipment        => 1,
                                               p_detail          => NULL,
                                               p_expense_item    => 2,
                                               p_expense_sub     => 2,
                                               p_own             => 1,
                                               x_return_status   => l_return_status,
                                               x_msg_count       => l_msg_count,
                                               x_msg_data        => l_msg_data);
    IF l_return_status <> cst_utility_pub.get_ret_sts_success THEN
      retcode := '2';
      fnd_msg_pub.count_and_get(p_encoded => cst_utility_pub.get_false,
                                p_count   => l_msg_count,
                                p_data    => l_msg_data);
      IF l_msg_count > 0 THEN
        FOR i IN 1 .. l_msg_count LOOP
          l_msg_data := fnd_msg_pub.get(i, cst_utility_pub.get_false);
          errbuf     := ltrim(rtrim(errbuf)) ||
                        fnd_msg_pub.get(i, cst_utility_pub.get_false);
          fnd_file.put_line(cst_utility_pub.get_log,
                            i || '-' || l_msg_data);
        END LOOP;
      END IF;
    ELSE
      -- Get ALL Inventory Items For ORG_ID
      FOR cntinvorg IN cr_getorgid_items LOOP
        -- Get Stock Quantity Data For Item In INV Organization
        SELECT nvl(round(SUM(ciqt.rollback_qty), 5), 0),
               MIN(cict.item_cost)
          INTO v_invorgstk, v_itemcoststk
          FROM cst_inv_qty_temp  ciqt,
               cst_inv_cost_temp cict,
               mtl_parameters    mp
         WHERE ciqt.qty_source IN (3, 4, 5)
           AND cict.cost_source IN (1, 2)
           AND cict.organization_id = ciqt.organization_id
           AND cict.inventory_item_id = ciqt.inventory_item_id
           AND (mp.primary_cost_method = 1 OR
               cict.cost_group_id = ciqt.cost_group_id)
           AND mp.organization_id = ciqt.organization_id
           AND ciqt.organization_id = cntinvorg.organization_id
           AND ciqt.inventory_item_id = cntinvorg.inventory_item_id;
        -- Get In Transit Data For Item In INV Organization
        SELECT nvl(round(SUM(ciqt.rollback_qty), 5), 0),
               MIN(cict.item_cost)
          INTO v_invorgit, v_itemcostit
          FROM cst_inv_qty_temp ciqt, cst_inv_cost_temp cict
         WHERE ciqt.qty_source IN (6, 7, 8)
           AND cict.cost_source IN (1, 2)
           AND cict.organization_id = ciqt.organization_id
           AND cict.inventory_item_id = ciqt.inventory_item_id
              --and cict.cost_group_id = ciqt.cost_group_id
           AND cict.organization_id = cntinvorg.organization_id
           AND cict.inventory_item_id = cntinvorg.inventory_item_id;
        -- Get In Receiving Data For Item In INV Organization
        SELECT nvl(round(SUM(ciqt.rollback_qty), 5), 0),
               MIN(cict.item_cost)
          INTO v_invorgrcv, v_itemcostrcv
          FROM cst_inv_qty_temp ciqt, cst_inv_cost_temp cict
         WHERE ciqt.qty_source IN (9, 10)
           AND cict.cost_source IN (3, 4)
           AND cict.organization_id = ciqt.organization_id
           AND cict.inventory_item_id = ciqt.inventory_item_id
           AND cict.rcv_transaction_id = ciqt.rcv_transaction_id
           AND cict.organization_id = cntinvorg.organization_id
           AND cict.inventory_item_id = cntinvorg.inventory_item_id;
        /*            -- For Israel Take Only Quantities Of Asset SubInv
        If V_OP_Name = 'OBJET IL (OU)' Then
           Select nvl(round(sum(ciqt.rollback_qty),2), 0), min(CICT.item_cost)
             Into v_InvOrgIT, v_ItemCostIT
           From   cst_inv_qty_temp ciqt,
                  cst_inv_cost_temp cict,
                  mtl_parameters mp,
                  mtl_secondary_inventories sub
           Where  ciqt.qty_source in (3,4,5)
              and cict.cost_source in (1,2)
              and cict.organization_id = ciqt.organization_id
              and cict.inventory_item_id = ciqt.inventory_item_id
              and (mp.primary_cost_method = 1 or  cict.cost_group_id = ciqt.cost_group_id)
              and mp.organization_id = ciqt.organization_id
              and sub.organization_id = ciqt.organization_id
              and sub.secondary_inventory_name = ciqt.subinventory_code
              and ciqt.organization_id = cntInvOrg.Organization_Id
              and ciqt.inventory_item_id = cntInvOrg.Inventory_Item_Id;
        End if;*/

        -- Only For Items With Any Quantity, Enter In Organizations
        IF v_invorgstk + v_invorgit + v_invorgrcv != 0 THEN
          IF v_itemcoststk IS NOT NULL THEN
            v_itemcostgen := v_itemcoststk;
          ELSIF v_itemcostit IS NOT NULL THEN
            v_itemcostgen := v_itemcostit;
          ELSIF v_itemcostrcv IS NOT NULL THEN
            v_itemcostgen := v_itemcostrcv;
          ELSE
            v_itemcostgen := NULL;
          END IF;

          INSERT INTO xxobjt.xxobjt_ratam_qty_subs
            (org_id,
             organization_id,
             item_id,
             date_as_of,
             quantity_oh,
             quantity_it,
             quantity_ir,
             quantity_total,
             item_cost,
             uom,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             last_update_login)
          VALUES
            (v_orgid,
             cntinvorg.organization_id,
             cntinvorg.inventory_item_id,
             v_p_asofdate,
             v_invorgstk,
             v_invorgit,
             v_invorgrcv,
             v_invorgstk + v_invorgit + v_invorgrcv,
             v_itemcostgen,
             cntinvorg.primary_uom_code,
             SYSDATE,
             v_user_id,
             SYSDATE,
             v_user_id,
             v_login_id);
        END IF;
      END LOOP;
    END IF;

  EXCEPTION
    WHEN l_cst_inv_val THEN
      fnd_file.put_line(fnd_file.log,
                        'CalculateQuantityForInvOrg Calculation Error');
  END calculatequantityforinvorg;

  --------------------------------------------------------------------
  --  name:            is_tryandbuy_system_item --CHG0046935
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   20/01/2020
  --------------------------------------------------------------------
  --  purpose :        Check id system tryand Buy
  --------------------------------------------------------------------
  -- ver   date         name         desc
  -- ----  -----------  -----------  ---------------------------------
  -- 1.0   20/01/2020   Ofer Suad    CHG0046935
  --------------------------------------------------------------------
  function is_tryandbuy_system_item(p_item_id number) return varchar2 is
    --------------------------
    --    Local Definitions
    --------------------------
    l_return_value varchar2(10) := 'N';
    l_count        number;
    --------------------------
    --    Code Section
    --------------------------
  begin

    l_return_value := 'N';

    select count(*)
      into l_count
      FROM xxcs_items_printers_v vv
     WHERE vv.inventory_item_id = p_item_id;

    if 0 = l_count then

      SELECT count(*)
        INTO l_count
        FROM mtl_item_categories_v mic,
             mtl_categories_b      mcb,
             mtl_system_items_b    msib
       WHERE mic.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND mcb.category_id = mic.category_id
         AND msib.inventory_item_id = mic.inventory_item_id
         AND msib.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND mic.category_set_name = 'Product Hierarchy'
         AND mic.segment1 = 'Systems'
         and msib.serial_number_control_code != 1
         AND msib.inventory_item_id = p_item_id;

      if 0 = l_count then
        l_return_value := 'N';
      else
        l_return_value := 'Y';
      end if;
    else
      l_return_value := 'Y';
    end if;

    return l_return_value;
  end is_tryandbuy_system_item;

  PROCEDURE calcrentaletcperop(errbuf       IN OUT VARCHAR2,
                               retcode      IN OUT VARCHAR2,
                               p_asofdate   IN VARCHAR2,
                               p_subs_orgid IN NUMBER,
                               p_item_id    IN NUMBER) IS

    v_p_asofdate       DATE;
    l_set_param_result NUMBER;
    --08-Sep-2015   Ofer Suad   CHG0036330-  Change RTS queryy
    CURSOR cr_calc_rentaletc /*(PC_AsOfDate in date) remarked on 26-jan-10 by daniel katz*/
    IS

      SELECT SUM(qty) qty, inventory_item_id, order_quantity_uom, org_id

        FROM (
           --  Start CHG0047477  - Change logic of function to get MFG Org to support new technologies
              select hu.name,
                       oh.order_number,
                      oll.inventory_item_id,
                      gcc.segment3,
                      oll.order_quantity_uom,
                      oll.org_id,

                      SUM(oll.ordered_quantity) qty, --CHG0042478
                      mb.segment1,
                      mb.description

                from gl_code_combinations         gcc,
                      xla_ae_lines                 xla,
                      hr_operating_units           hu,
                      xla_distribution_links       xdl,
                      fnd_lookup_values            v,
                      mtl_transaction_accounts     mta,
                      mtl_material_transactions    mmt,
                      oe_order_lines_all           oll,
                      oe_order_headers_all         oh,
                      mtl_system_items_b           mb,
                      org_organization_definitions odf
               where gcc.segment3 = v.lookup_code
                 and xla.code_combination_id = gcc.code_combination_id
                 and xla.accounting_date <= v_p_asofdate
                 and odf.ORGANIZATION_ID = mmt.organization_id
                    -- and mmt.transaction_id = mta.transaction_id
                 and hu.set_of_books_id = xla.ledger_id
                 and hu.organization_id = p_subs_orgid
                 and xla.application_id = 707
                 and xla.ledger_id = odf.SET_OF_BOOKS_ID
                 and xdl.ae_header_id = xla.ae_header_id
                 and xdl.ae_line_num = xla.ae_line_num
                 and mmt.transaction_id = mta.transaction_id
                 and v.lookup_type = 'XX_GL_TAB_ACCOUNTS'
                 and v.language = 'US'
                 and v.enabled_flag = 'Y'
                 and mta.inv_sub_ledger_id = xdl.source_distribution_id_num_1
                 and oll.line_id = mmt.trx_source_line_id
                 and oh.header_id = oll.header_id
                 AND oll.cancelled_quantity = 0
                 and mb.inventory_item_id = mta.inventory_item_id
                 and decode(oh.flow_status_code,'CLOSED',oh.last_update_date,
                 v_p_asofdate+1)>=v_p_asofdate
                 and mb.organization_id =
                     xxinv_utils_pkg.get_master_organization_id
                 AND (mb.inventory_item_id = p_item_id OR p_item_id IS NULL)
                 AND NOT EXISTS
               (SELECT 1
                        FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                       WHERE ffvs.flex_value_set_name =
                             'XXCST_UR_ORDER_LINE_EXCEPTION'
                         AND ffv.flex_value_set_id = ffvs.flex_value_set_id
                         AND ffv.enabled_flag = 'Y'
                         AND ffv.flex_value =
                             oh.order_number || ';' || oll.line_number)
                 and not exists
               (select 1
                        from mtl_material_transactions mmt1,
                             mtl_unit_transactions     mut,
                             mtl_unit_transactions     mut1,
                             mtl_material_transactions mmt2
                       where mmt1.trx_source_line_id = oll.line_id
                         and mmt1.inventory_item_id = mta.inventory_item_id
                         and mmt1.transaction_type_id = 33
                         and mut.transaction_id = mmt1.transaction_id
                         and mut1.serial_number = mut.serial_number
                         and mut1.transaction_date between
                             mut.transaction_date and v_p_asofdate
                         and mut1.transaction_id = mmt2.transaction_id
                         and mmt2.transaction_type_id = 15)
                 and oll.line_category_code != 'RETURN'
              --and xxcst_ratam_pkg.is_tryandbuy_system_item(mta.inventory_item_id) = 'Y'
               group by hu.name,
                         oh.order_number,
                         oll.inventory_item_id,
                         gcc.segment3,
                         oll.order_quantity_uom,
                         oll.org_id,
                         mb.segment1,
                         mb.description
              having sum(oll.ordered_quantity) <> 0

              /*SELECT hu.name,
                    h.order_number,
                    oel.inventory_item_id,
                    gcc.segment3,
                    oel.order_quantity_uom,
                    oel.org_id,
                    --SUM(decode(oel.line_category_code,--CHG0042478
                  --  'RETURN',
                    -- -oel.ordered_quantity,
                    --oel.ordered_quantity))
                    SUM(oel.ordered_quantity) qty, --CHG0042478
                    mb.segment1,
                    mb.description

               FROM oe_order_lines_all        oel,
                    oe_transaction_types_all  oet,
                    oe_order_headers_all      h,
                    mtl_system_items_b        mb,
                    mtl_material_transactions mmt,
                    mtl_transaction_accounts  mta,
                    gl_code_combinations      gcc,
                    hr_operating_units        hu
              WHERE oet.transaction_type_id = oel.line_type_id
                AND oet.attribute6 = 'Y'
                AND oet.org_id = hu.organization_id
                AND oel.cancelled_quantity = 0
                AND mb.inventory_item_id = oel.inventory_item_id
                AND mb.organization_id =
                    xxinv_utils_pkg.get_master_organization_id
                   -- and mb.segment1 = 'OBJ-06001' --'OBJ-07100'
                AND mmt.trx_source_line_id = oel.line_id
                AND mmt.transaction_type_id IN (10008, 15)
                AND trunc(mmt.transaction_date) <= v_p_asofdate
                AND mta.transaction_id(+) = mmt.transaction_id
                AND gcc.code_combination_id(+) = mta.reference_account
                AND (instr(fnd_profile.value('XXCST_UR_SHOW_ACCOUNTS'),
                           gcc.segment3) != 0 OR gcc.segment3 IS NULL)
                AND hu.organization_id = p_subs_orgid
                AND h.header_id = oel.header_id
                AND (mb.inventory_item_id = p_item_id OR p_item_id IS NULL)
                   -- and is_tryandbuy_system_item(mb.inventory_item_id) = 'Y' -- CHG0046935
                AND EXISTS
              (SELECT 1
                       FROM xxcs_items_printers_v vv
                      WHERE vv.inventory_item_id = mb.inventory_item_id)
                   -- CHG0042478 check if serial was returned - do not take line
                   --             to reduce items return to NA Subinv
                and not exists
              (select 1
                       from mtl_material_transactions mmt1,
                            mtl_unit_transactions     mut,
                            mtl_unit_transactions     mut1,
                            mtl_material_transactions mmt2
                      where mmt1.trx_source_line_id = oel.line_id
                        and mmt1.transaction_type_id = 33
                        and mut.transaction_id = mmt1.transaction_id
                        and mut1.serial_number = mut.serial_number
                        and mut1.transaction_date between
                            mut.transaction_date and v_p_asofdate
                        and mut1.transaction_id = mmt2.transaction_id
                        and mmt2.transaction_type_id = 15)
                and oel.line_category_code != 'RETURN' --CHG0042478
                AND NOT EXISTS
              (SELECT 1
                       FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                      WHERE ffvs.flex_value_set_name =
                            'XXCST_UR_ORDER_LINE_EXCEPTION'
                        AND ffv.flex_value_set_id = ffvs.flex_value_set_id
                        AND ffv.enabled_flag = 'Y'
                        AND ffv.flex_value =
                            h.order_number || ';' || oel.line_number)
                AND h.header_id = oel.header_id
              GROUP BY oel.inventory_item_id,
                       hu.name,
                       oel.header_id,
                       oel.order_quantity_uom,
                       oel.org_id,
                       mb.segment1,
                       mb.description,
                       gcc.segment3,
                       h.order_number*/
         --     end CHG0047477  - Change logic of function to get MFG Org to support new technologies
              UNION ALL
              -- Drop Shipment Orders
              SELECT hu.name,
                      h.order_number,
                      mmt.inventory_item_id,
                      gcc.segment3,
                      mmt.transaction_uom,
                      hu.organization_id,
                      -mmt.transaction_quantity,
                      mb.segment1,
                      mb.description
              --ail.invoice_id
                FROM ap_invoice_distributions_all aid,
                      gl_code_combinations         gcc,
                      ap_invoice_lines_all         ail,
                      mtl_material_transactions    mmt,
                      hr_operating_units           hu,
                      mtl_system_items_b           mb,
                      fnd_lookup_values            v,
                      oe_order_lines_all           oel,
                      oe_order_headers_all         h
               WHERE gcc.code_combination_id = aid.dist_code_combination_id
                    -- AND instr(fnd_profile.value('XXCST_UR_SHOW_ACCOUNTS'),
                    --           gcc.segment3) != 0
                 and gcc.segment3 = v.lookup_code
                 AND aid.org_id = hu.organization_id
                 AND aid.line_type_lookup_code = 'ITEM'
                 AND ail.invoice_id = aid.invoice_id
                 AND aid.invoice_line_number = ail.line_number
                 AND ail.reference_2 = mmt.transaction_id
                 AND aid.accounting_date <= v_p_asofdate
                 AND hu.organization_id = p_subs_orgid
                 AND mb.inventory_item_id = mmt.inventory_item_id
                 AND mb.organization_id = mmt.organization_id
                 AND mmt.trx_source_line_id = oel.line_id
                 AND (mb.inventory_item_id = p_item_id OR p_item_id IS NULL)
                 and v.lookup_type = 'XX_GL_TAB_ACCOUNTS'
                 and v.language = 'US'
                 and v.enabled_flag = 'Y'
                  and decode(h.flow_status_code,'CLOSED',h.last_update_date,
                 v_p_asofdate+1)>=v_p_asofdate
                    -- and is_tryandbuy_system_item(mb.inventory_item_id) = 'Y'
                 AND EXISTS
               (SELECT 1
                        FROM xxcs_items_printers_v vv
                       WHERE vv.inventory_item_id = mb.inventory_item_id)
                 AND NOT EXISTS
               (SELECT 1
                        FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                       WHERE ffvs.flex_value_set_name =
                             'XXCST_UR_ORDER_LINE_EXCEPTION'
                         AND ffv.flex_value_set_id = ffvs.flex_value_set_id
                         AND ffv.enabled_flag = 'Y'
                         AND ffv.flex_value =
                             h.order_number || ';' || oel.line_number)
                    -- CHG0042478 check if serial was returned - do not take line
                    --             to reduce items return to NA Subinv

                 and not exists
                 --CHG0047477  - Change logic of function to get MFG Org to support new technologies
               (select 1
                        from mtl_material_transactions mmt1,
                             mtl_unit_transactions     mut,
                             mtl_unit_transactions     mut1,
                             mtl_material_transactions mmt2
                       where mmt1.trx_source_line_id = oel.line_id
                         and mmt1.inventory_item_id = mmt.inventory_item_id
                         and mmt1.transaction_type_id = 33
                         and mut.transaction_id = mmt1.transaction_id
                         and mut1.serial_number = mut.serial_number

                         and mut1.transaction_date between
                             mut.transaction_date and v_p_asofdate
                         and mut1.transaction_id = mmt2.transaction_id
                         and mmt2.transaction_type_id = 15)
                 AND h.header_id = oel.header_id)
       GROUP BY inventory_item_id, order_quantity_uom, org_id
      HAVING SUM(qty) > 0;

    /*
       select xgu.inventory_item_id,
          xgu.UNIT_OF_MEASURE order_quantity_uom,
          xgu.org_id,
          xgu.Qty
     from xxcst_glib_unit_asofdate xgu
    where xgu.org_id = P_SubS_OrgID
      and (xgu.INVENTORY_ITEM_ID = P_Item_ID or P_Item_ID is null);*/

    ---- end 08-Sep-2015   Ofer Suad   CHG0036330-  Change RTS queryy
  BEGIN
  --  CHG0047477  -Remove trunc
    SELECT /*trunc*/(to_date(p_asofdate, 'YYYY/MM/DD HH24:MI:SS'))
      INTO v_p_asofdate
      FROM dual;

    --added by daniel katz on 26-jan-10 to initialize as of date on the view in the cursor above.
    --  l_set_param_result := XXCS_SESSION_PARAM.set_session_param_date(v_P_AsOfDate,
    --                                                                  1);

    -- Delete Previous Running
    -- added by daniel katz
    DELETE FROM xxobjt.xxobjt_ratam_qty_subs a
     WHERE a.organization_id = -99 || p_subs_orgid
       AND a.org_id = p_subs_orgid
       AND (a.item_id = p_item_id OR p_item_id IS NULL)
       AND a.date_as_of = trunc(v_p_asofdate);--CHG0049395 - Ratam report does  not show T&B items and IN US there is difference from as of date report  in some items 

    fnd_file.PUT_LINE(fnd_file.LOG, 'v_p_asofdate  ' || v_p_asofdate);

    FOR rentetc IN cr_calc_rentaletc /*(v_P_AsOfDate) remarked on 26-jan-10 by daniel katz*/
     LOOP
       --  CHG0047477  -For perfomace issue - move the if from query -to check only
       -- for Try and Buy items and not all items
      if is_tryandbuy_system_item(rentetc.inventory_item_id) = 'Y' then
        fnd_file.PUT_LINE(fnd_file.LOG,
                          'item  ' || rentetc.inventory_item_id);

        -- If RentEtc.Qty > 0 then
        BEGIN
          INSERT INTO xxobjt.xxobjt_ratam_qty_subs
            (org_id,
             organization_id,
             item_id,
             date_as_of,
             quantity_oh,
             quantity_it,
             quantity_ir,
             quantity_total,
             uom,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             last_update_login)
          VALUES
            (p_subs_orgid,
             -99 || p_subs_orgid,
             rentetc.inventory_item_id,
             trunc(v_p_asofdate),--CHG0049395 - Ratam report does  not show T&B items and IN US there is difference from as of date report  in some items 
             NULL,
             NULL,
             NULL,
             rentetc.qty,
             rentetc.order_quantity_uom,
             SYSDATE,
             v_user_id,
             SYSDATE,
             v_user_id,
             v_login_id);
        EXCEPTION
          WHEN dup_val_on_index THEN
            UPDATE xxobjt.xxobjt_ratam_qty_subs
               SET quantity_total = nvl(quantity_total, 0) + rentetc.qty
             WHERE organization_id = -99 || p_subs_orgid
               AND item_id = rentetc.inventory_item_id
               AND date_as_of = trunc(v_p_asofdate);--CHG0049395 - Ratam report does  not show T&B items and IN US there is difference from as of date report  in some items 
        END;
      End if;
    END LOOP;

  END calcrentaletcperop;

  FUNCTION calculategoliveqty(p_orgid      IN NUMBER,
                              p_golivedate IN DATE,
                              p_itemid     IN VARCHAR2) RETURN NUMBER IS
    v_actualcost mtl_material_transactions.actual_cost%TYPE;
  BEGIN
    -- Get Subsidiary / Israel Average Cost TRX Before Go-Live
    SELECT MAX(mmt.actual_cost)
      INTO v_actualcost
      FROM mtl_material_transactions mmt
     WHERE mmt.organization_id IN
           (SELECT hoi.organization_id
              FROM hr_organization_information hoi
             WHERE hoi.org_information_context = 'Accounting Information'
               AND hoi.org_information3 = p_orgid)
       AND mmt.inventory_item_id = p_itemid
       AND mmt.transaction_date <= p_golivedate
       AND mmt.transaction_type_id =
           (SELECT transaction_type_id
              FROM mtl_transaction_types
             WHERE transaction_type_name = 'Average cost update');
    RETURN(v_actualcost);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(0);
  END calculategoliveqty;

  -----------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  XX/XXX/XXXX   XXXX            initial build
  --  1.1  02-Sep-2019   Bellona B.      CHG0046373 - Unrealizes report does not pull correct IC invoices for IP marked items
  ------------------------------------------------------
  PROCEDURE calculateinternalorders(errbuf             OUT VARCHAR2,
                                    retcode            OUT VARCHAR2,
                                    p_asofdate         IN DATE,
                                    p_israel_orgid     IN NUMBER,
                                    p_ic_selling_org   IN VARCHAR2,
                                    p_subsidiary_orgid IN NUMBER,
                                    p_item_id          IN NUMBER,
                                    p_golivedate       IN DATE,
                                    p_goliveeur_rate   IN NUMBER,
                                    p_golivehkd_rate   IN NUMBER,
                                    p_masterorganizid  IN NUMBER) IS
    CURSOR cr_ohinounit IS

      SELECT qtysubs.org_id,
             qtysubs.item_id,
             hro.name,
             SUM(qtysubs.quantity_total) totqty
        FROM xxobjt.xxobjt_ratam_qty_subs qtysubs,
             hr_organization_units        hro,
             mtl_system_items_b           mb
       WHERE qtysubs.date_as_of = p_asofdate
         AND hro.organization_id = qtysubs.org_id
         AND (qtysubs.org_id = p_subsidiary_orgid OR
             p_subsidiary_orgid IS NULL)
         and (xxinv_utils_pkg.is_fdm_item(qtysubs.item_id) = 'N' or
             decode(p_subsidiary_orgid, 737, mb.attribute2, 'IL') = 'IL' or
             is_MB_Item(qtysubs.item_id) = 'Y') --CHG0039638 add Maker bote items in US
         AND (qtysubs.item_id = p_item_id OR p_item_id IS NULL)
         and mb.inventory_item_id = qtysubs.item_id
         and mb.organization_id =
             xxinv_utils_pkg.get_master_organization_id
       GROUP BY qtysubs.org_id, item_id, hro.name;

    CURSOR cr_internalorders(pc_orgid IN NUMBER, pc_itemid IN NUMBER) IS
    --06-Nov-2016              CHG0039638 - pefomance issue -add  MTL_INTERCOMPANY_PARAMETERS_V
      SELECT rctl.interface_line_attribute4 sell_to_ou,
             rctl.org_id,
             rctl.sales_order,
             rct.trx_number,
             rctl.line_number trx_line,
             msi.segment1 item,
             msi.description item_desc,
             nvl(rctl.quantity_invoiced, 0) quantity,
             rctl.uom_code,
             rctl.customer_trx_line_id,
             --replaced by daniel katz on 5-jan-10
             --           rctl.interface_line_attribute6 trx_source_line_id,
             rctl.interface_line_attribute7 trx_source_line_id,
             nvl(ol.actual_shipment_date, rctl.sales_order_date) ship_date,
             rctl.interface_line_attribute9 order_header_id,
             rctl.warehouse_id
        FROM oe_order_lines_all            ol,
             ra_customer_trx_all           rct,
             ra_customer_trx_lines_all     rctl,
             mtl_system_items_b            msi,
             MTL_INTERCOMPANY_PARAMETERS_V mipv,
             ra_cust_trx_line_gl_dist_all  gd
       WHERE rct.customer_trx_id = rctl.customer_trx_id
         AND rctl.inventory_item_id = msi.inventory_item_id
         AND rctl.warehouse_id = msi.organization_id
         AND rctl.interface_line_context = 'INTERCOMPANY'
         AND ol.line_id = rctl.interface_line_attribute6
         and mipv.SELL_ORGANIZATION_ID = pc_orgid
         and mipv.CUSTOMER_ID = rct.sold_to_customer_id
            -- and rctl.org_id in( P_Israel_OrgID,103,737)
         and rctl.org_id = mipv.SHIP_ORGANIZATION_ID
            --   and rctl.interface_line_attribute8  in(to_char(P_Israel_OrgID),'103','737') --sale order's org id=IL, i.e. Internal and not Intercompany
            --AND rctl.interface_line_attribute8 = mipv.SHIP_ORGANIZATION_ID  --commented as part of CHG0046373
         and mipv.CUST_TRX_TYPE_ID = rct.CUST_TRX_TYPE_ID
         AND nvl(rctl.quantity_invoiced, 0) > 0 -- only positive quantity without credit quantity
         AND rctl.interface_line_attribute4 = pc_orgid
         AND rctl.inventory_item_id = pc_itemid
         AND trunc(nvl(ol.actual_shipment_date, rctl.sales_order_date)) <=
             p_asofdate
         and gd.customer_trx_id = rct.customer_trx_id
         AND 'REC' = gd.account_class
         AND gd.gl_date <= p_asofdate
       ORDER BY nvl(ol.actual_shipment_date, rctl.sales_order_date) DESC;
    -- 04/07/2013    Ofer Suad   Fix query of FDM items
    CURSOR c_sysss_internal_trx(pc_orgid IN NUMBER, pc_itemid IN NUMBER) IS
      SELECT po_num,
             receipt_num,
             line_num,
             segment1,
             description,
             SUM(qty),
             uom_code,
             transaction_id,
             transaction_date,
             trans_id,
             SUM(amt),
             gl_date
        FROM (SELECT ph.segment1 po_num,
                     rsh.receipt_num,
                     rsl.line_num,
                     mb.segment1,
                     mb.description,
                     SUM(rt.quantity) qty,
                     rt.uom_code,
                     rt.transaction_id, --aid.invoice_distribution_id,
                     rt.transaction_date,
                     -- gcc.concatenated_segments,
                     rt.transaction_id trans_id,
                     SUM(rt.quantity * pll.price_override) amt,
                     trunc(rt.creation_date) gl_date
                FROM po_lines_all                 pl,
                     po_line_locations_all        pll,
                     po_distributions_all         pda,
                     ap_invoice_distributions_all aid,
                     ap_invoices_all              aia,
                     ap_invoice_lines_all         ail,
                     rcv_transactions             rt,
                     -- gl_code_combinations_kfv     gcc,
                     po_headers_all       ph,
                     mtl_system_items_b   mb,
                     rcv_shipment_headers rsh,
                     rcv_shipment_lines   rsl
               WHERE pl.item_id = pc_itemid
                 AND pda.po_line_id = pl.po_line_id
                 AND aid.po_distribution_id = pda.po_distribution_id
                 AND rt.po_distribution_id = pda.po_distribution_id
                 AND aia.invoice_id = aid.invoice_id
                 AND rt.transaction_date <= p_asofdate
                 AND aid.org_id = pc_orgid
                 AND mb.inventory_item_id = pc_itemid
                 AND mb.organization_id = pda.destination_organization_id
                 AND ph.po_header_id = pda.po_header_id
                 AND rt.transaction_type = 'DELIVER'
                 AND ail.invoice_id = aia.invoice_id
                 AND ail.line_number = aid.invoice_line_number
                 AND ail.line_type_lookup_code = 'ITEM'
                 AND rsh.shipment_header_id = rt.shipment_header_id
                 AND aid.quantity_invoiced IS NOT NULL
                 AND rsl.shipment_line_id = rt.shipment_line_id
                 AND pll.line_location_id = pda.line_location_id
              -- AND    aid.rcv_transaction_id = rt.parent_transaction_id --CHG0039638 remove match to Receipt
               GROUP BY ph.segment1,
                        rsh.receipt_num,
                        rsl.line_num,
                        mb.segment1,
                        mb.description,
                        rt.uom_code,
                        --aid.invoice_distribution_id,
                        rt.transaction_date,
                        -- gcc.concatenated_segments,
                        rt.transaction_id,
                        trunc(rt.creation_date)
              UNION ALL
              SELECT ph.segment1 po_num,
                     rsh.receipt_num,
                     rsl.line_num,
                     mb.segment1,
                     mb.description,
                     SUM(rt.quantity) qty,
                     rt.uom_code,
                     rt.transaction_id,
                     rt.transaction_date,
                     rt.transaction_id trans_id,
                     SUM(rt.quantity * pll.price_override) amt,
                     trunc(rt.creation_date) gl_date
                FROM po_lines_all          pl,
                     po_distributions_all  pda,
                     po_line_locations_all pll,
                     rcv_transactions      rt,
                     po_headers_all        ph,
                     mtl_system_items_b    mb,
                     rcv_shipment_headers  rsh,
                     rcv_shipment_lines    rsl
               WHERE pl.item_id = pc_itemid
                 AND pda.po_line_id = pl.po_line_id
                 AND rt.po_distribution_id = pda.po_distribution_id
                 AND rt.transaction_date < p_asofdate
                 AND pda.org_id = pc_orgid
                 AND mb.inventory_item_id = pc_itemid
                 AND mb.organization_id = pda.destination_organization_id
                 AND ph.po_header_id = pda.po_header_id
                 AND rt.transaction_type = 'DELIVER'
                 AND pll.line_location_id = pda.line_location_id
                 AND pda.quantity_ordered - pda.quantity_cancelled -
                     pda.quantity_billed != 0
                 AND rsh.shipment_header_id = rt.shipment_header_id
                 AND rsl.shipment_line_id = rt.shipment_line_id
               GROUP BY ph.segment1,
                        mb.segment1,
                        rsh.receipt_num,
                        rsl.line_num,
                        mb.description,
                        rt.uom_code,
                        trunc(rt.creation_date),
                        rt.transaction_date,
                        rt.transaction_id)
       GROUP BY po_num,
                receipt_num,
                line_num,
                segment1,
                description,
                uom_code,
                transaction_id,
                transaction_date,
                trans_id,
                gl_date
       ORDER BY transaction_date DESC;

    v_ohqty           NUMBER;
    v_qtytoinsert     NUMBER;
    v_sell_to_ou      ra_customer_trx_lines_all.interface_line_attribute4%TYPE;
    v_sales_order     ra_customer_trx_lines_all.sales_order%TYPE;
    v_trx_number      VARCHAR2(50); --ra_customer_trx_all.trx_number%type;
    v_unik_trx_number VARCHAR2(50);
    v_trx_line        ra_customer_trx_lines_all.line_number%TYPE;
    v_item_code       mtl_system_items_b.segment1%TYPE;
    v_item_desc       mtl_system_items_b.description%TYPE;
    v_qty_invoiced    ra_customer_trx_lines_all.quantity_invoiced%TYPE;
    v_uom_code        ra_customer_trx_lines_all.uom_code%TYPE;
    v_trx_line_id     ra_customer_trx_lines_all.customer_trx_line_id%TYPE;
    --replaced by daniel katz on 5-jan-10
    --  v_trx_src_ln_id  ra_customer_trx_lines_all.interface_line_attribute6%type;
    v_trx_src_ln_id ra_customer_trx_lines_all.interface_line_attribute7%TYPE;
    v_ship_date     oe_order_lines_all.actual_shipment_date%TYPE;
    v_oe_header_id  ra_customer_trx_lines_all.interface_line_attribute9%TYPE;
    v_warehouse_id  ra_customer_trx_lines_all.warehouse_id%TYPE;
    v_org_id        NUMBER;
    v_rctlg_sales   NUMBER;
    v_rctlg_gl_date ra_cust_trx_line_gl_dist_all.gl_date%TYPE;
    v_mmt_cogs      mtl_material_transactions.actual_cost%TYPE;
    v_mmt_std_cost  mtl_material_transactions.actual_cost%TYPE;
    --v_mmt_currncy    mtl_material_transactions.currency_code%type;
    v_mmt_tx_date            mtl_material_transactions.transaction_date%TYPE;
    v_mnt_cogs_acct          gl_code_combinations_kfv.concatenated_segments%TYPE;
    v_isr_golivecost         mtl_material_transactions.actual_cost%TYPE;
    v_sub_golivecost         mtl_material_transactions.actual_cost%TYPE;
    v_item_cogsacct          gl_code_combinations_kfv.concatenated_segments%TYPE;
    v_subsexchrate           gl_daily_rates.conversion_rate%TYPE;
    v_subscurrency           gl_sets_of_books.currency_code%TYPE;
    v_mmt_otr_id             mtl_material_transactions.organization_id%TYPE;
    lorg_qty_tbl             xxcst_ratam_pkg.org_qty_tbl;
    l_first_transaction_date date; --CHG0039638  for MB items in EMEA and APJ
    l_aggr_allocated         NUMBER;
  BEGIN

    dbms_output.put_line(a => 'CalculateInternalOrders P_AsOfDate:' ||
                              p_asofdate);
    FOR ohcnt IN cr_ohinounit LOOP

      SELECT gsb.currency_code
        INTO v_subscurrency
        FROM gl_sets_of_books gsb
       WHERE gsb.set_of_books_id =
             (SELECT hoi.org_information3
                FROM hr_organization_information hoi
               WHERE hoi.organization_id = ohcnt.org_id
                 AND hoi.org_information_context =
                     'Operating Unit Information');

      v_ohqty := ohcnt.totqty;
      dbms_output.put_line(a => 'v_OHQty:' || v_ohqty);
      -- Ofer Suad 07-Apr-2013 add SSys item
      /* if xxinv_utils_pkg.is_fdm_item(OHcnt.Item_Id,null) = 'Y' then
        Open c_sysss_internal_trx(OHcnt.Org_Id, OHcnt.Item_Id);
        Loop
          Fetch c_sysss_internal_trx
            Into v_sales_order, v_trx_number, v_trx_line, v_item_code, v_item_desc, v_qty_invoiced, v_uom_code, v_trx_line_id, v_ship_date,
          v_trx_src_ln_id, v_rctlg_sales,v_rctlg_gl_date;
          EXIT WHEN(c_sysss_internal_trx%NOTFOUND or v_OHQty <= 0);
          If v_OHQty > v_qty_invoiced then
            v_QtyToInsert := v_qty_invoiced;
            v_OHQty       := v_OHQty - v_qty_invoiced;
          Else
            v_QtyToInsert := v_OHQty;
            v_OHQty       := 0;
          End if;

          select XXCST_RATAM_PKG.get_IL_Avg_Cost(P_Israel_OrgID,P_AsOfDate,OHcnt.Item_Id)/**mmt.primary_quantity/*round(nvl(mmt.actual_cost / mmt.currency_conversion_rate,
                           0) * mmt.primary_quantity,
                       2)
                        cogs,
                 gcc.concatenated_segments cogs_code_combination
            Into v_mmt_cogs, v_mnt_cogs_acct
            from mtl_material_transactions mmt,
                 gl_code_combinations_kfv  gcc
           where mmt.distribution_account_id = gcc.code_combination_id(+)
             and mmt.rcv_transaction_id = v_trx_src_ln_id;

          Insert into xxobjt.xxobjt_ratam_intsales
            (org_id,
             item_id,
             date_as_of,
             sale_order,
             trx_number,
             trx_line,
             item_code,
             item_desc,
             quantity,
             uom,
             sales,
             cogs,
             cogs_account,
             gl_date,
             ship_date,
             operating_unit,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             last_update_login)
          Values
            (OHcnt.Org_Id,
             OHcnt.Item_Id,
             P_AsOfDate,
             v_sales_order,
             v_trx_number,
             v_trx_line,
             v_item_code,
             v_item_desc,
             v_QtyToInsert,
             v_uom_code,
             round(v_rctlg_sales * v_QtyToInsert / v_qty_invoiced, 2), --v_rctlg_sales,
             round(v_mmt_cogs * v_QtyToInsert),-- / v_qty_invoiced, 2), --v_mmt_cogs,
             v_mnt_cogs_acct,
             v_rctlg_gl_date,
             v_ship_date,
             OHcnt.name,
             sysdate,
             v_user_id,
             sysdate,
             v_user_id,
             v_login_id);
        end loop;
        close c_sysss_internal_trx;
      else*/
      l_aggr_allocated := 0;
      -- For Each Item In ORG Calculate the FIFO
      OPEN cr_internalorders(ohcnt.org_id, ohcnt.item_id);
      LOOP
        FETCH cr_internalorders
          INTO v_sell_to_ou,
               v_org_id,
               v_sales_order,
               v_trx_number,
               v_trx_line,
               v_item_code,
               v_item_desc,
               v_qty_invoiced,
               v_uom_code,
               v_trx_line_id,
               v_trx_src_ln_id,
               v_ship_date,
               v_oe_header_id,
               v_warehouse_id;
        EXIT WHEN(cr_internalorders%NOTFOUND OR v_ohqty <= 0);
        /* dbms_output.put_line(a => 'org_id:' || OHCnt.Org_Id ||
        ', Item ID: ' || OHcnt.Item_Id ||
        ', v_OHQty: ' || v_OHQty);*/
        -- Calc The Quantity To Insert The Record
        IF v_ohqty > v_qty_invoiced THEN
          v_qtytoinsert := v_qty_invoiced;
          v_ohqty       := v_ohqty - v_qty_invoiced;
        ELSE
          v_qtytoinsert := v_ohqty;
          v_ohqty       := 0;
        END IF;
        -- Get More Requested Information
        SELECT MIN(rctlgd.gl_date),
               SUM(decode(rctlgd.org_id,
                          p_israel_orgid,
                          nvl(rctlgd.acctd_amount, 0),
                          nvl(rctlgd.amount, 0)))
          INTO v_rctlg_gl_date, v_rctlg_sales
          FROM ra_cust_trx_line_gl_dist_all rctlgd, ra_customer_trx_all rt
         WHERE rctlgd.customer_trx_line_id = v_trx_line_id
           AND rctlgd.customer_trx_id = rt.customer_trx_id;

        --block replaced by daniel katz on 5-jan-10
        /*select round(sum(nvl(mmt.actual_cost, 0) * mmt.primary_quantity) * v_qty_invoiced / sum(mmt.primary_quantity), 2) cogs,
        min(gcc.concatenated_segments) cogs_code_combination*/
        SELECT /*-round(nvl(mmt.actual_cost, 0) * mmt.primary_quantity*nvl(mmt.currency_conversion_rate,1) *
                                                                                                                                                                  decode(nvl(mmt.currency_code,'USD'),
                                                                                                                                                                                      'USD',
                                                                                                                                                                                      1,
                                                                                                                                                                                      (gl_currency_api.get_closest_rate( \*from*\mmt.currency_code, \*to*\
                                                                                                                                                                                                                        'USD', \*date*\
                                                                                                                                                                                                                        mmt.transaction_date,
                                                                                                                                                                                                                        'Corporate',
                                                                                                                                                                                                                        10)))
                                                                                                                                                                  , 2)*/
         xxcst_ratam_pkg.get_il_std_cost(ohcnt.org_id,
                                         p_asofdate,
                                         ohcnt.item_id) cogs,
         gcc.concatenated_segments cogs_code_combination,
         mmt.transaction_date,
         mmt.organization_id
          INTO v_mmt_cogs, v_mnt_cogs_acct, v_mmt_tx_date, v_mmt_otr_id
          FROM mtl_material_transactions mmt, gl_code_combinations_kfv gcc
         WHERE mmt.distribution_account_id = gcc.code_combination_id(+)
              --folowing block replaced by daniel katz on 5-jan-10
              /*and mmt.source_line_id = v_trx_src_ln_id
              and mmt.inventory_item_id = ohcnt.item_id
              and mmt.transaction_reference=v_oe_header_id
              and mmt.organization_id = v_warehouse_id*/
           AND mmt.transaction_id = v_trx_src_ln_id;
        /*if v_org_id !=P_Israel_OrgID then
        v_mmt_cogs:=XXCST_RATAM_PKG.get_IL_Std_Cost(OHcnt.Org_Id,P_AsOfDate,OHcnt.Item_Id);
        --v_mmt_cogs:=XXCST_RATAM_PKG.get_IL_Avg_Cost(81,'31-dec-2013',OHcnt.Item_Id);
        end if;*/
        -- Insert Record Into Internal SO Table
        --  CHG0034713 sapreate lines per inventory org standard cost
        xxcst_ratam_pkg.get_org_and_qty(ohcnt.item_id,
                                        l_aggr_allocated,
                                        v_qtytoinsert,
                                        p_asofdate,
                                        ohcnt.org_id,
                                        lorg_qty_tbl);
        l_aggr_allocated := l_aggr_allocated + v_qtytoinsert;
        FOR k IN 1 .. lorg_qty_tbl.count LOOP
          IF lorg_qty_tbl.count > 1 THEN
            v_unik_trx_number := v_trx_number || '-' || k;
          ELSE
            v_unik_trx_number := v_trx_number;
          END IF;
          BEGIN

            SELECT qsb.item_cost
              INTO v_mmt_std_cost
              FROM xxobjt_ratam_qty_subs qsb
             WHERE qsb.item_id = ohcnt.item_id
               AND qsb.org_id = ohcnt.org_id
               AND qsb.date_as_of = p_asofdate
               AND qsb.item_cost IS NOT NULL
                  --CHG0037762 - FDM Items with Country Of Origin
               AND qsb.organization_id = lorg_qty_tbl(k).org_id
               AND rownum = 1;
          EXCEPTION
            WHEN OTHERS THEN
              v_mmt_std_cost := get_org_std_cost(NULL,
                                                 p_asofdate,
                                                 ohcnt.item_id,
                                                 ohcnt.org_id); --CHG0037762 - FDM Items with Country Of Origin
          END;

          IF v_mmt_tx_date < p_golivedate THEN
            v_mmt_std_cost := v_mmt_std_cost *
                              gl_currency_api.get_closest_rate(v_subscurrency,
                                                               'USD',
                                                               p_golivedate,
                                                               'Corporate',
                                                               10);
          ELSE
            v_mmt_std_cost := v_mmt_std_cost *
                              gl_currency_api.get_closest_rate(v_subscurrency,
                                                               'USD',
                                                               v_mmt_tx_date,
                                                               'Corporate',
                                                               10);
          END IF;

          INSERT INTO xxobjt.xxobjt_ratam_intsales
            (org_id,
             item_id,
             date_as_of,
             sale_order,
             trx_number,
             trx_line,
             item_code,
             item_desc,
             quantity,
             uom,
             sales,
             cogs,
             cogs_account,
             gl_date,
             ship_date,
             operating_unit,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             last_update_login,
             org_std_cost)
          VALUES
            (ohcnt.org_id,
             ohcnt.item_id,
             p_asofdate,
             v_sales_order,
             v_unik_trx_number,
             v_trx_line,
             v_item_code,
             v_item_desc,
             lorg_qty_tbl(k).quantity, --v_QtyToInsert,
             v_uom_code,
             round(v_rctlg_sales * lorg_qty_tbl(k).quantity /*v_QtyToInsert*/
                   / v_qty_invoiced,
                   2), --v_rctlg_sales,
             round(v_mmt_cogs * lorg_qty_tbl(k).quantity /*v_QtyToInsert*/ /*/ v_qty_invoiced*/,
                   2), --v_mmt_cogs,
             v_mnt_cogs_acct,
             v_rctlg_gl_date,
             v_ship_date,
             ohcnt.name,
             SYSDATE,
             v_user_id,
             SYSDATE,
             v_user_id,
             v_login_id,
             round(v_mmt_std_cost * lorg_qty_tbl(k).quantity /*v_QtyToInsert*/,
                   2));
        END LOOP;
      END LOOP;
      CLOSE cr_internalorders;
      -- end if;
      -- In Case Misc. Transactions Are Entered     show error     Bigger Than Internal Receiving
      IF v_ohqty > 0 THEN
        IF xxinv_utils_pkg.is_fdm_item(ohcnt.item_id, NULL) = 'Y' THEN
          OPEN c_sysss_internal_trx(ohcnt.org_id, ohcnt.item_id);
          LOOP
            FETCH c_sysss_internal_trx
              INTO v_sales_order,
                   v_trx_number,
                   v_trx_line,
                   v_item_code,
                   v_item_desc,
                   v_qty_invoiced,
                   v_uom_code,
                   v_trx_line_id,
                   v_ship_date, /*v_mnt_cogs_acct,*/
                   v_trx_src_ln_id,
                   v_rctlg_sales,
                   v_rctlg_gl_date;
            EXIT WHEN(c_sysss_internal_trx%NOTFOUND OR v_ohqty <= 0);
            IF v_ohqty > v_qty_invoiced THEN
              v_qtytoinsert := v_qty_invoiced;
              v_ohqty       := v_ohqty - v_qty_invoiced;
            ELSE
              v_qtytoinsert := v_ohqty;
              v_ohqty       := 0;
            END IF;

            SELECT xxcst_ratam_pkg.get_il_std_cost(p_israel_orgid,
                                                   p_asofdate,
                                                   ohcnt.item_id) /**mmt.primary_quantity/*round(nvl(mmt.actual_cost / mmt.currency_conversion_rate,
                                                                                                                                                                                                                                                                                                                                                                                 0) * mmt.primary_quantity,
                                                                                                                                                                                                                                                                                                                                                                             2)*/ cogs,
                   gcc.concatenated_segments cogs_code_combination,
                   mmt.transaction_date,
                   mmt.organization_id

              INTO v_mmt_cogs, v_mnt_cogs_acct, v_mmt_tx_date, v_mmt_otr_id
              FROM mtl_material_transactions mmt,
                   gl_code_combinations_kfv  gcc
             WHERE mmt.distribution_account_id = gcc.code_combination_id(+)
               AND mmt.rcv_transaction_id = v_trx_src_ln_id;
            --  CHG0034713 sapreate lines per inventory org standard cost
            xxcst_ratam_pkg.get_org_and_qty(ohcnt.item_id,
                                            l_aggr_allocated,
                                            v_qtytoinsert,
                                            p_asofdate,
                                            ohcnt.org_id,
                                            lorg_qty_tbl);
            l_aggr_allocated := l_aggr_allocated + v_qtytoinsert;
            FOR k IN 1 .. lorg_qty_tbl.count LOOP
              IF lorg_qty_tbl.count > 1 THEN
                v_unik_trx_number := v_trx_number || '-' || k;
              ELSE
                v_unik_trx_number := v_trx_number;
              END IF;
              BEGIN
                SELECT qsb.item_cost
                  INTO v_mmt_std_cost
                  FROM xxobjt_ratam_qty_subs qsb
                 WHERE qsb.item_id = ohcnt.item_id
                   AND qsb.org_id = ohcnt.org_id
                   AND qsb.date_as_of = p_asofdate
                   AND qsb.item_cost IS NOT NULL
                      -- CHG0037762 - FDM Items with Country Of Origin
                   AND qsb.organization_id = lorg_qty_tbl(k).org_id
                   AND rownum = 1;
              EXCEPTION
                WHEN OTHERS THEN
                  v_mmt_std_cost := get_org_std_cost(NULL, -- CHG0037762 - FDM Items with Country Of Origin
                                                     p_asofdate,
                                                     ohcnt.item_id,
                                                     ohcnt.org_id); -- CHG0037762 - FDM Items with Country Of Origin
              END;
              IF v_mmt_tx_date < p_golivedate THEN
                v_mmt_std_cost := v_mmt_std_cost *
                                  gl_currency_api.get_closest_rate(v_subscurrency,
                                                                   'USD',
                                                                   p_golivedate,
                                                                   'Corporate',
                                                                   10);
              ELSE
                v_mmt_std_cost := v_mmt_std_cost *
                                  gl_currency_api.get_closest_rate(v_subscurrency,
                                                                   'USD',
                                                                   v_mmt_tx_date,
                                                                   'Corporate',
                                                                   10);
              END IF;

              INSERT INTO xxobjt.xxobjt_ratam_intsales
                (org_id,
                 item_id,
                 date_as_of,
                 sale_order,
                 trx_number,
                 trx_line,
                 item_code,
                 item_desc,
                 quantity,
                 uom,
                 sales,
                 cogs,
                 cogs_account,
                 gl_date,
                 ship_date,
                 operating_unit,
                 creation_date,
                 created_by,
                 last_update_date,
                 last_updated_by,
                 last_update_login,
                 org_std_cost)
              VALUES
                (ohcnt.org_id,
                 ohcnt.item_id,
                 p_asofdate,
                 v_sales_order,
                 v_unik_trx_number,
                 v_trx_line,
                 v_item_code,
                 v_item_desc,
                 lorg_qty_tbl(k).quantity, --v_QtyToInsert,
                 v_uom_code,
                 round(v_rctlg_sales * lorg_qty_tbl(k).quantity /*v_QtyToInsert*/
                       / v_qty_invoiced,
                       2), --v_rctlg_sales,
                 round(v_mmt_cogs * lorg_qty_tbl(k).quantity /*v_QtyToInsert*/,
                       2), -- / v_qty_invoiced, 2), --v_mmt_cogs,
                 v_mnt_cogs_acct,
                 v_rctlg_gl_date,
                 v_ship_date,
                 ohcnt.name,
                 SYSDATE,
                 v_user_id,
                 SYSDATE,
                 v_user_id,
                 v_login_id,
                 round(v_mmt_std_cost * lorg_qty_tbl(k).quantity /*v_QtyToInsert*/,
                       2));
            END LOOP;
          END LOOP;
          CLOSE c_sysss_internal_trx;
        END IF;
      END IF;
      IF v_ohqty > 0 THEN

        -- Get Average Cost Update Transaction Before Go-Live In Israel
        v_isr_golivecost := xxcst_ratam_pkg.get_il_std_cost(p_israel_orgid,
                                                            p_asofdate,
                                                            ohcnt.item_id); /*CalculateGoLiveQty(P_Israel_OrgID,
                                                                                                                                                                 P_GoLiveDate + 1,
                                                                                                                                                                 OHcnt.Item_Id);*/
        -- Get Average Cost Update Transaction Before Go-Live In Subsidiary
        --  CHG0034713 sapreate lines per inventory org standard cost
        xxcst_ratam_pkg.get_org_and_qty(ohcnt.item_id,
                                        l_aggr_allocated,
                                        v_ohqty,
                                        p_asofdate,
                                        ohcnt.org_id,
                                        lorg_qty_tbl);
        l_aggr_allocated := l_aggr_allocated + v_ohqty;
        FOR k IN 1 .. lorg_qty_tbl.count LOOP

          --CHG0039638  for MB items in EMEA and APJ
          begin
            SELECT nvl(greatest(p_golivedate, min(mmt.transaction_date)),
                       p_golivedate)
              into l_first_transaction_date
              FROM mtl_material_transactions mmt
             where mmt.inventory_item_id = ohcnt.item_id
               and mmt.organization_id = lorg_qty_tbl(k).org_id;
          exception
            when others then
              l_first_transaction_date := p_golivedate;

          end;
          -- end CHG0039638  for MB items in EMEA and APJ
          BEGIN
            SELECT qsb.item_cost
              INTO v_sub_golivecost
              FROM xxobjt_ratam_qty_subs qsb
             WHERE qsb.item_id = ohcnt.item_id
               AND qsb.org_id = ohcnt.org_id
               AND qsb.date_as_of = p_asofdate
               AND qsb.item_cost IS NOT NULL
                  -- CHG0037762 - FDM Items with Country Of Origin
               AND qsb.organization_id = lorg_qty_tbl(k).org_id
               AND rownum = 1;
          EXCEPTION
            WHEN OTHERS THEN
              v_sub_golivecost := get_org_std_cost(NULL, -- CHG0037762 - FDM Items with Country Of Origin
                                                   p_asofdate,
                                                   ohcnt.item_id,
                                                   ohcnt.org_id); -- CHG0037762 - FDM Items with Country Of Origin
          END;
          /* v_Sub_GoLiveCost := CalculateGoLiveQty(OHcnt.Org_Id,
          P_GoLiveDate + 1,
          OHcnt.Item_Id);*/
          -- Get Item COGS Account
          BEGIN
            SELECT MAX(glc.concatenated_segments),
                   MAX(msi.segment1),
                   MAX(msi.description),
                   MAX(msi.primary_uom_code)
              INTO v_item_cogsacct, v_item_code, v_item_desc, v_uom_code
              FROM mtl_system_items_b msi, gl_code_combinations_kfv glc
             WHERE glc.code_combination_id = msi.cost_of_sales_account
               AND msi.organization_id = p_masterorganizid
               AND msi.inventory_item_id = ohcnt.item_id;
          EXCEPTION
            WHEN no_data_found THEN
              v_item_cogsacct := NULL;
          END;
          -- Get Subsidiary GoLive Exchange Rate
          BEGIN

            v_subsexchrate := gl_currency_api.get_closest_rate( /*from*/v_subscurrency, /*to*/
                                                               'USD', /*date*/
                                                               p_asofdate,
                                                               'Corporate',
                                                               10);
            /* If v_SubsCurrency = 'EUR' then
              v_SubsExchRate := P_GoLiveEUR_Rate;
            Elsif v_SubsCurrency = 'HKD' then
              v_SubsExchRate := P_GoLiveHKD_Rate;
            Else
              v_SubsExchRate := 1;
            End if;*/
          EXCEPTION
            WHEN no_data_found THEN
              v_subsexchrate := 1;
          END;

          -- Insert Record Into Internal SO Table
          INSERT INTO xxobjt.xxobjt_ratam_intsales
            (org_id,
             item_id,
             date_as_of,
             sale_order,
             trx_number,
             trx_line,
             item_code,
             item_desc,
             quantity,
             uom,
             sales,
             cogs,
             cogs_account,
             gl_date,
             ship_date,
             operating_unit,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             last_update_login,
             org_std_cost)
          VALUES
            (ohcnt.org_id,
             ohcnt.item_id,
             p_asofdate,
             NULL,
             NULL,
             k, -- null
             v_item_code,
             v_item_desc,
             lorg_qty_tbl(k).quantity, --v_OHQty,
             v_uom_code,
             round(v_sub_golivecost * v_subsexchrate * lorg_qty_tbl(k)
                   .quantity /*v_OHQty*/,
                   2),
             round(v_isr_golivecost * lorg_qty_tbl(k).quantity /*v_OHQty*/,
                   2),
             v_item_cogsacct,
             l_first_transaction_date, --CHG0039638  for MB items in EMEA and APJ
             l_first_transaction_date, --CHG0039638  for MB items in EMEA and APJ
             ohcnt.name,
             SYSDATE,
             v_user_id,
             SYSDATE,
             v_user_id,
             v_login_id,
             round(v_sub_golivecost * v_subsexchrate * lorg_qty_tbl(k)
                   .quantity /*v_OHQty*/,
                   2));
        END LOOP;
      END IF;

    END LOOP;

  END calculateinternalorders;

  -----------------------------------------------------
  /* Ofer Suad 07-Apr-2013  add ssys itmes          */
  -----------------------------------------------------
  FUNCTION get_il_avg_cost(pc_isrorgid IN NUMBER,
                           pc_asofdate IN DATE,
                           pc_itemid   IN NUMBER) RETURN NUMBER IS
    l_il_avg_cost   NUMBER;
    l_syss_avg_cost NUMBER;
  BEGIN

    IF xxinv_utils_pkg.is_fdm_item(pc_itemid, NULL) = 'Y' THEN
      BEGIN
        SELECT cic.item_cost
          INTO l_syss_avg_cost
          FROM cst_item_cost_type_v cic
         WHERE cic.inventory_item_id = pc_itemid
           AND cic.cost_type = 'SSYS Cost'
           AND cic.organization_id =
               fnd_profile.value('XXCST_RATAM_SSYS_COST_ORG');

        RETURN l_syss_avg_cost;
      EXCEPTION
        WHEN OTHERS THEN
          RETURN 0;
      END;
    ELSE
      SELECT nvl(round(SUM(a.quantity_total * a.item_cost) /
                       decode(SUM(a.quantity_total),
                              0,
                              1,
                              SUM(a.quantity_total)),
                       2),
                 0) AS costval
        INTO l_il_avg_cost
        FROM xxobjt.xxobjt_ratam_qty_subs a
       WHERE a.date_as_of = pc_asofdate
         AND organization_id IN
             (SELECT hoi.organization_id
                FROM hr_organization_information hoi
               WHERE hoi.org_information_context = 'Accounting Information'
                 AND hoi.org_information3 = pc_isrorgid)
         AND a.item_id = pc_itemid;
    END IF;
    RETURN l_il_avg_cost;
  END get_il_avg_cost;
  -----------------------------------------------------

  PROCEDURE calcintercoorders(errbuf           OUT VARCHAR2,
                              retcode          OUT VARCHAR2,
                              p_asofdate       IN VARCHAR2,
                              p_org_id         IN VARCHAR2, --CHG0039638 perfomance - run all OU Simultaneously
                              p_israel_orgid   IN VARCHAR2,
                              p_ic_selling_org IN VARCHAR2,
                              p_item_id        IN NUMBER,
                              p_golivedate     IN VARCHAR2,
                              p_goliveeur_rate IN NUMBER,
                              p_golivehkd_rate IN NUMBER) IS
    v_p_asofdate   DATE;
    v_p_golivedate DATE;
    v_errbuf       VARCHAR2(2000);
    v_retcode      VARCHAR2(2000);
    v_count        NUMBER;

    v_masterorganid NUMBER;

    CURSOR cr_calcintsaleavg(pc_asofdate IN DATE) IS
      SELECT a.org_id,
             a.item_id,
             round(SUM(a.sales) / SUM(a.quantity), 2) AS avgcostsales,
             round(SUM(a.cogs) / SUM(a.quantity), 2) AS avgcogscost
        FROM xxobjt.xxobjt_ratam_intsales a
       WHERE a.date_as_of = pc_asofdate
       GROUP BY a.org_id, a.item_id;

    /*Cursor cr_CalcIsrCostAVG (PC_IsrOrgID in number, PC_AsOfDate in date, PC_ItemID in number) Is
      Select nvl(round(sum(a.quantity_total * a.item_cost)/
                decode(sum(a.quantity_total), 0, 1, sum(a.quantity_total)), 2), 0) as CostVal
        From xxobjt.xxobjt_ratam_qty_subs a
       Where a.date_as_of = PC_AsOfDate
         and organization_id in (Select hoi.organization_id
                                   From hr_organization_information hoi
                                  Where hoi.Org_Information_Context = 'Accounting Information'
                                    and hoi.Org_Information3  = PC_IsrOrgID)
         and a.item_id = PC_ItemID;
    */
    CURSOR cr_operatingunits(p_israel_orgid IN NUMBER) IS
      SELECT DISTINCT a.org_information3
        FROM hr.hr_organization_information a
       WHERE a.org_information_context = 'Accounting Information'
         AND a.org_information3 != p_israel_orgid
         and nvl(to_char(p_org_id), a.org_information3) =
             a.org_information3; --CHG0039638 perfomance - run all OU Simultaneously
    --  l_IL_Avg_Cost number;
    l_il_std_cost NUMBER;
  BEGIN
    fnd_profile.get(NAME => 'USER_ID', val => v_user_id);
    fnd_profile.get(NAME => 'LOGIN_ID', val => v_login_id);
    -- Get Master Organization ID
    SELECT mp.organization_id
      INTO v_masterorganid
      FROM mtl_parameters mp
     WHERE mp.organization_code = 'OMA';
    -- Get Truncated As-Of-Date
    SELECT trunc(to_date(p_asofdate, 'YYYY/MM/DD HH24:MI:SS'))
      INTO v_p_asofdate
      FROM dual;
    SELECT trunc(to_date(p_golivedate, 'YYYY/MM/DD HH24:MI:SS'))
      INTO v_p_golivedate
      FROM dual;
    -- Delete Previous RATAM Running, If Exists

    init_org_from_lookup;
    FOR i IN cr_operatingunits(p_israel_orgid) LOOP
      DELETE FROM xxobjt.xxobjt_ratam_intsales a
       WHERE (a.item_id = p_item_id OR p_item_id IS NULL)
         AND a.date_as_of = v_p_asofdate
         and a.org_id = i.org_information3; --CHG0039638 perfomance - run all OU Simultaneously
      calculateinternalorders(v_errbuf,
                              v_retcode,
                              v_p_asofdate,
                              p_israel_orgid,
                              p_ic_selling_org,
                              i.org_information3,
                              p_item_id,
                              v_p_golivedate,
                              p_goliveeur_rate,
                              p_golivehkd_rate,
                              v_masterorganid);
    END LOOP;

    -- Calculate Average Values For Subsidiary
    /* FOR avgsubs IN cr_calcintsaleavg(v_p_asofdate) LOOP

      \*l_IL_Avg_Cost*\
      l_il_std_cost :=  \*get_IL_Avg_Cost*\
       get_il_std_cost(p_israel_orgid,
                                       v_p_asofdate,
                                       avgsubs.item_id);
      -- For avgVal in cr_CalcIsrCostAVG (P_Israel_OrgID, v_P_AsOfDate, avgSubS.Item_Id) Loop
      UPDATE xxobjt.xxobjt_ratam_intsales
         SET avg_cost_sales = avgsubs.avgcostsales,
             avg_cost_cogs  = avgsubs.avgcogscost,
             avg_cost_il    = l_il_std_cost \*l_IL_Avg_Cost*\ --avgVal.Costval
       WHERE org_id = avgsubs.org_id
         AND item_id = avgsubs.item_id
         AND date_as_of = v_p_asofdate;
      -- End loop;
    END LOOP;*/

    /*  Delete From xxobjt.xxobjt_ratam_qty_subs a
       Where a.date_as_of = v_P_AsOfDate
           and organization_id in (Select hoi.organization_id
                                     From hr_organization_information hoi
                                    Where hoi.Org_Information_Context = 'Accounting Information'
                                      and hoi.Org_Information3  = P_Israel_OrgID);
    */
    SELECT COUNT(*) INTO v_count FROM cst_inv_qty_temp;
    dbms_output.put_line(a => 'cst_inv_qty_temp: ' || v_count);
    SELECT COUNT(*) INTO v_count FROM cst_inv_cost_temp;
    dbms_output.put_line(a => 'cst_inv_cost_temp: ' || v_count);
    fnd_file.put_line(fnd_file.log, 'BEFORE COMMIT');
    COMMIT;
    fnd_file.put_line(fnd_file.log, 'AFTER COMMIT');
    /*exception
    when others then
       errbuf  := 'Error while calualating Internal Orders ';
       retcode := 1;*/

  END calcintercoorders;

  PROCEDURE calcqtyforinvorg_temp(errbuf      IN OUT VARCHAR2,
                                  retcode     IN OUT VARCHAR2,
                                  p_asofdate  IN VARCHAR2,
                                  p_inv_orgid IN NUMBER) IS

    v_p_asofdate       DATE;
    l_return_status    VARCHAR2(1000);
    l_msg_count        NUMBER(20);
    l_msg_data         VARCHAR2(1000);
    v_org_name         mtl_parameters.organization_code%TYPE;
    v_categsetid       mtl_category_sets_tl.category_set_id%TYPE;
    v_op_name          hr_all_organization_units.name%TYPE;
    v_orgid            NUMBER;
    v_org_asofdate     DATE; --CHG0042478 - Automtically choose time based on location Operating unit timezone
    v_server_time_zone varchar2(50); --CHG0042478 - Automtically choose time based on location Operating unit timezone
  BEGIN
    SELECT trunc(to_date(p_asofdate, 'YYYY/MM/DD HH24:MI:SS'))
      INTO v_p_asofdate
      FROM dual;
    -- Start CHG0042478 - Automtically choose time based on location Operating unit timezone
    v_org_asofdate := null;
    begin
      -- CHG0045166 - As of date and Ratam report as of date  not shifted by timezone
      /* select v.timezone_code
       into v_server_time_zone
       FROM FND_TIMEZONES_VL v
      where v.UPGRADE_TZ_ID = fnd_profile.VALUE('SERVER_TIMEZONE_ID');*/

      select CAST(FROM_TZ(CAST((to_date(p_asofdate, 'YYYY/MM/DD HH24:MI:SS')) AS
                               TIMESTAMP),
                          hl.timezone_code) AT TIME ZONE v.timezone_code AS DATE)
        into v_org_asofdate
        from org_organization_definitions od,
             hr_locations_all             hl,
             HR_ORGANIZATION_UNITS        hu,
             FND_TIMEZONES_VL             v
       where od.ORGANIZATION_ID = p_inv_orgid
         and hl.location_id = hu.location_id
         and od.OPERATING_UNIT = hu.organization_id
         and v.UPGRADE_TZ_ID = fnd_profile.VALUE('SERVER_TIMEZONE_ID');
    exception
      when others then
        v_org_asofdate := to_date(p_asofdate, 'YYYY/MM/DD HH24:MI:SS');
        fnd_file.PUT_LINE(fnd_file.LOG,
                          'Error while setting Timezone for org ' ||
                          p_inv_orgid);
        retcode := '2';
        retcode := 'Error while setting Timezone for org ' || p_inv_orgid || '. ' ||
                   substr(sqlerrm, 1, 2000);
    end;
    -- end CHG0045166
    if v_org_asofdate is null then
      v_org_asofdate := to_date(p_asofdate, 'YYYY/MM/DD HH24:MI:SS');
    end if;
    -- end CHG0042478 - Automtically choose time based on location Operating unit timezone
    -- Get Objet Main Cateory, On Which All Items Will Be Included
    SELECT mcs.category_set_id
      INTO v_categsetid
      FROM mtl_category_sets_tl mcs
     WHERE mcs.category_set_name = 'Main Category Set'
       AND mcs.language = userenv('LANG');
    -- Get Operating Unit Of Given INV Organization
    SELECT ou.name, ou.organization_id
      INTO v_op_name, v_orgid
      FROM hr_organization_information hoi, hr_all_organization_units ou
     WHERE ou.organization_id = hoi.org_information3
       AND hoi.org_information_context = 'Accounting Information'
       AND hoi.organization_id = p_inv_orgid;
    -- Get inv org code Of Given INV Organization
    SELECT mtlp.organization_code
      INTO v_org_name
      FROM mtl_parameters mtlp
     WHERE mtlp.organization_id = p_inv_orgid;
    -- Delete Previous Running
    DELETE FROM xxobjt.xxobj_asofdate_qty_cst a
     WHERE a.organization_code = v_org_name
       AND a.date_as_of = v_p_asofdate;

    fnd_profile.get(NAME => 'USER_ID', val => v_user_id);
    fnd_profile.get(NAME => 'LOGIN_ID', val => v_login_id);

    cst_inventory_pub.calculate_inventoryvalue(p_api_version     => 1.0,
                                               p_init_msg_list   => cst_utility_pub.get_true,
                                               p_organization_id => p_inv_orgid,
                                               p_onhand_value    => 1,
                                               p_intransit_value => 1,
                                               p_receiving_value => 1,
                                               p_valuation_date  => v_org_asofdate, --CHG0042478 - Automtically choose time based on location Operating unit timezone
                                               --to_date(p_asofdate,
                                               --        'YYYY/MM/DD HH24:MI:SS') + 1,
                                               p_cost_type_id      => fnd_profile.value('XX_COST_TYPE'), --2,
                                               p_item_from         => NULL,
                                               p_item_to           => NULL,
                                               p_category_set_id   => v_categsetid,
                                               p_category_from     => NULL,
                                               p_category_to       => NULL,
                                               p_cost_group_from   => NULL,
                                               p_cost_group_to     => NULL,
                                               p_subinventory_from => NULL,
                                               p_subinventory_to   => NULL,
                                               p_qty_by_revision   => 2,
                                               p_zero_cost_only    => 2,
                                               p_zero_qty          => 2,
                                               p_expense_item      => 2,
                                               p_expense_sub       => 1,
                                               p_unvalued_txns     => 2,
                                               p_receipt           => 1,
                                               p_shipment          => 1,
                                               x_return_status     => l_return_status,
                                               x_msg_count         => l_msg_count,
                                               x_msg_data          => l_msg_data);

    INSERT INTO xxobj_asofdate_qty_cst
      (date_as_of,
       subinventory_code,
       subinventory_description,
       asset_inventory,
       item_number,
       si_qty,
       si_defaulted,
       si_matl_cost,
       si_movh_cost,
       si_res_cost,
       si_osp_cost,
       si_ovhd_cost,
       si_total_cost,
       organization_code,
       creation_date,
       created_by,
       item_description,
       organization_id,
       inventory_item_id,
       org_name,
       org_id,
       qty_source,
       category_id)
      (SELECT trunc(v_p_asofdate),
              ciqt.subinventory_code si_subinv,
              sec.description si_description,
              sec.asset_inventory si_asset_subinv,
              msi.segment1 si_item_number,
              ciqt.rollback_qty si_qty,
              decode(cict.cost_type_id, 2, 'Average', '*') si_defaulted,
              round(ciqt.rollback_qty *
                    decode(nvl(sec.asset_inventory, 1), 1, 1, 0) *
                    nvl(cict.material_cost, 0) * 1 / 0.01) * 0.01 si_matl_cost,
              round(ciqt.rollback_qty *
                    decode(nvl(sec.asset_inventory, 1), 1, 1, 0) *
                    nvl(cict.material_overhead_cost, 0) * 1 / 0.01) * 0.01 si_movh_cost,
              round(ciqt.rollback_qty *
                    decode(nvl(sec.asset_inventory, 1), 1, 1, 0) *
                    nvl(cict.resource_cost, 0) * 1 / 0.01) * 0.01 si_res_cost,
              round(ciqt.rollback_qty *
                    decode(nvl(sec.asset_inventory, 1), 1, 1, 0) *
                    nvl(cict.outside_processing_cost, 0) * 1 / 0.01) * 0.01 si_osp_cost,
              round(ciqt.rollback_qty *
                    decode(nvl(sec.asset_inventory, 1), 1, 1, 0) *
                    nvl(cict.overhead_cost, 0) * 1 / 0.01) * 0.01 si_ovhd_cost,
              round(ciqt.rollback_qty *
                    decode(nvl(sec.asset_inventory, 1), 1, 1, 0) *
                    nvl(cict.item_cost, 0) * 1 / 0.01) * 0.01 si_total_cost,
              v_org_name,
              SYSDATE,
              fnd_profile.value('USERNAME'),
              msi.description,
              p_inv_orgid,
              msi.inventory_item_id,
              v_op_name,
              v_orgid,
              ciqt.qty_source,
              ciqt.category_id
         FROM mtl_categories_b          mc,
              mtl_system_items_b        msi,
              mtl_secondary_inventories sec,
              mtl_parameters            mp,
              cst_inv_qty_temp          ciqt,
              cst_inv_cost_temp         cict
        WHERE sec.organization_id(+) = ciqt.organization_id
          AND sec.secondary_inventory_name(+) = ciqt.subinventory_code
          AND ciqt.qty_source IN (3, 4, 5, 6, 7, 8)
          AND cict.cost_source IN (1, 2)
          AND msi.organization_id = ciqt.organization_id
          AND msi.inventory_item_id = ciqt.inventory_item_id
          AND cict.organization_id = ciqt.organization_id
          AND cict.inventory_item_id = ciqt.inventory_item_id
          AND (mp.primary_cost_method = 1 OR
               cict.cost_group_id = ciqt.cost_group_id)
          AND mp.organization_id = ciqt.organization_id
          AND mc.category_id = ciqt.category_id
          AND nvl(ciqt.rollback_qty, 0) <> 0
       UNION ALL
       SELECT trunc(v_p_asofdate),
              ciqt.subinventory_code si_subinv,
              sec.description si_description,
              sec.asset_inventory si_asset_subinv,
              msi.segment1 si_item_number,
              ciqt.rollback_qty si_qty,
              decode(cict.cost_type_id, 2, 'Average', '*') si_defaulted,
              round(ciqt.rollback_qty *
                    decode(nvl(sec.asset_inventory, 1), 1, 1, 0) *
                    nvl(cict.material_cost, 0) * 1 / 0.01) * 0.01 si_matl_cost,
              round(ciqt.rollback_qty *
                    decode(nvl(sec.asset_inventory, 1), 1, 1, 0) *
                    nvl(cict.material_overhead_cost, 0) * 1 / 0.01) * 0.01 si_movh_cost,
              round(ciqt.rollback_qty *
                    decode(nvl(sec.asset_inventory, 1), 1, 1, 0) *
                    nvl(cict.resource_cost, 0) * 1 / 0.01) * 0.01 si_res_cost,
              round(ciqt.rollback_qty *
                    decode(nvl(sec.asset_inventory, 1), 1, 1, 0) *
                    nvl(cict.outside_processing_cost, 0) * 1 / 0.01) * 0.01 si_osp_cost,
              round(ciqt.rollback_qty *
                    decode(nvl(sec.asset_inventory, 1), 1, 1, 0) *
                    nvl(cict.overhead_cost, 0) * 1 / 0.01) * 0.01 si_ovhd_cost,
              round(ciqt.rollback_qty *
                    decode(nvl(sec.asset_inventory, 1), 1, 1, 0) *
                    nvl(cict.item_cost, 0) * 1 / 0.01) * 0.01 si_total_cost,
              v_org_name,
              SYSDATE,
              fnd_profile.value('USERNAME'),
              msi.description,
              p_inv_orgid,
              msi.inventory_item_id,
              v_op_name,
              v_orgid,
              ciqt.qty_source,
              ciqt.category_id
         FROM mtl_categories_b          mc,
              mtl_system_items_b        msi,
              mtl_secondary_inventories sec,
              mtl_parameters            mp,
              cst_inv_qty_temp          ciqt,
              cst_inv_cost_temp         cict
        WHERE sec.organization_id(+) = ciqt.organization_id
          AND sec.secondary_inventory_name(+) = ciqt.subinventory_code
          AND ciqt.qty_source IN (9, 10)
          AND cict.cost_source IN (3, 4)
          AND msi.organization_id = ciqt.organization_id
          AND msi.inventory_item_id = ciqt.inventory_item_id
          AND cict.organization_id = ciqt.organization_id
          AND cict.inventory_item_id = ciqt.inventory_item_id
          AND (mp.primary_cost_method = 1 OR
               cict.cost_group_id = ciqt.cost_group_id)
          AND mp.organization_id = ciqt.organization_id
          AND cict.rcv_transaction_id = ciqt.rcv_transaction_id
          AND mc.category_id = ciqt.category_id
          AND nvl(ciqt.rollback_qty, 0) <> 0);

  END calcqtyforinvorg_temp;

  -----------------------------------------------------
  /* -- CHG0037762 - FDM Items with Country Of Origin      */
  -----------------------------------------------------
  PROCEDURE init_org_from_lookup IS
    CURSOR c_inv_orgs IS
      SELECT flv.description, flv.lookup_code
        FROM fnd_lookup_values_vl flv
       WHERE flv.lookup_type = 'XXCST_RATAM_INV_ORGS';

  BEGIN
    FOR i IN c_inv_orgs LOOP
      g_org_ids_tbl(i.lookup_code) := to_number(i.description);
    END LOOP;
    v_is_lookup_init := 1;

  END init_org_from_lookup;

  -----------------------------------------------------
  /* Ofer Suad 07-Apr-2013  add ssys itmes          */
  -----------------------------------------------------
  FUNCTION get_il_std_cost(pc_isrorgid IN NUMBER,
                           pc_asofdate IN DATE,
                           pc_itemid   IN NUMBER) RETURN NUMBER /*DETERMINISTIC*/
   IS
    l_il_cost NUMBER := 0;

    --  CHG0039638 - get cost form CST_STANDARD_COSTS based on standard_cost_revision_date
  BEGIN
    SELECT csc.standard_cost
      into l_il_cost
      FROM CST_STANDARD_COSTS csc
     where csc.inventory_item_id = pc_itemid
       and csc.organization_id =
           get_manufacturing_org(pc_itemid, pc_asofdate)
       and csc.standard_cost_revision_date =
           (select max(cscm.standard_cost_revision_date)
              from CST_STANDARD_COSTS cscm
             where cscm.inventory_item_id = pc_itemid
               and cscm.organization_id = csc.organization_id
               and trunc(cscm.standard_cost_revision_date) <= pc_asofdate);
    RETURN l_il_cost;
  EXCEPTION
    WHEN others THEN
      if xxinv_utils_pkg.is_fdm_item(pc_itemid, NULL) = 'Y' then
        begin
          SELECT cch.standard_cost
            INTO l_il_cost
            FROM CST_STANDARD_COSTS cch
           WHERE cch.inventory_item_id = pc_itemid
             AND cch.organization_id = g_org_ids_tbl('FDM_DEFUALT')
             AND cch.standard_cost_revision_date =
                 (SELECT MAX(standard_cost_revision_date)
                    FROM CST_STANDARD_COSTS cchv
                   WHERE cchv.inventory_item_id = cch.inventory_item_id
                     AND cchv.organization_id = cch.organization_id
                     AND trunc(cchv.standard_cost_revision_date) <=
                         pc_asofdate);
          RETURN l_il_cost;
        EXCEPTION
          WHEN others THEN
            RETURN 0;
        end;
      else
        RETURN 0;
      END if;

  END get_il_std_cost;
  --       01-Sep-2014   Ofer Suad   CHG0033161 - Add org standard cost
  --       06-Nov-2016              CHG0039638 - take
  FUNCTION get_org_std_cost(pc_orgid    IN NUMBER,
                            pc_asofdate IN DATE,
                            pc_itemid   IN NUMBER,
                            pc_ou_id    IN NUMBER) RETURN NUMBER IS
    l_org_cost NUMBER;
    -- CHG0037762 - FDM Items with Country Of Origin
    CURSOR c_inv_orgs IS
      SELECT odf.organization_id
        FROM org_organization_definitions odf
       WHERE odf.operating_unit = pc_ou_id;
  BEGIN
    BEGIN
      IF pc_orgid IS NOT NULL THEN
        -- CHG0037762 - FDM Items with Country Of Origin
        -- CHG0039638 - take last std cost from CST_STANDARD_COSTS based on  standard_cost_revision_date
        SELECT csc.standard_cost
          into l_org_cost
          FROM CST_STANDARD_COSTS csc
         where csc.inventory_item_id = pc_itemid
           and csc.organization_id = pc_orgid
           and csc.standard_cost_revision_date =
               (select max(cscm.standard_cost_revision_date)
                  from CST_STANDARD_COSTS cscm
                 where cscm.inventory_item_id = pc_itemid
                   and cscm.organization_id = pc_orgid
                   and trunc(cscm.standard_cost_revision_date) <=
                       pc_asofdate);

      ELSE
        l_org_cost := NULL;
        -- CHG0037762 - FDM Items with Country Of Origin
        FOR i IN c_inv_orgs LOOP
          BEGIN

            SELECT csc.standard_cost
              into l_org_cost
              FROM CST_STANDARD_COSTS csc
             where csc.inventory_item_id = pc_itemid
               and csc.organization_id = i.organization_id
               and csc.standard_cost_revision_date =
                   (select max(cscm.standard_cost_revision_date)
                      from CST_STANDARD_COSTS cscm
                     where cscm.inventory_item_id = pc_itemid
                       and cscm.organization_id = i.organization_id
                       and trunc(cscm.standard_cost_revision_date) <=
                           pc_asofdate);

          EXCEPTION
            WHEN OTHERS THEN
              l_org_cost := 0;
          END;

          EXIT WHEN nvl(l_org_cost, 0) <> 0;

        END LOOP;
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        l_org_cost := 0;
    END;
    RETURN nvl(l_org_cost, 0);

  END get_org_std_cost;

  --------------------------------------------------------------------
  --  name:            get_org_and_qty CHG0034713
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   10/03/2015
  --------------------------------------------------------------------
  --  purpose :        Get std cost per organization
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/03/2015  Ofer Suad    initial build
  --------------------------------------------------------------------
  PROCEDURE get_org_and_qty(p_item_id          IN NUMBER,
                            p_aggr_qty         IN NUMBER,
                            p_curr_qty         IN NUMBER,
                            p_asofdate         IN DATE,
                            p_subsidiary_orgid IN NUMBER,
                            p_org_qty_tbl      OUT org_qty_tbl) IS
    CURSOR c_lines IS
      SELECT t.organization_id, t.quantity_total
        FROM xxobjt.xxobjt_ratam_qty_subs t
       WHERE t.item_id = p_item_id
         AND t.org_id = p_subsidiary_orgid
         AND t.date_as_of = p_asofdate
       ORDER BY t.quantity_total DESC;
    l_org_agg_qty NUMBER;
    l_agg_qty     NUMBER := p_aggr_qty;
    l_index       NUMBER;
    l_org_qty     xxcst_ratam_pkg.org_qrty;
    l_count       NUMBER;
    l_curr_qty number:=p_curr_qty;--CHG0049395 - Ratam report does  not show T&B items and IN US there is difference from as of date report  in some items 
    -- l_org_qty_tbl XXCST_RATAM_PKG.org_qty_tbl;
  BEGIN
    SELECT COUNT(DISTINCT t.item_cost)
      INTO l_count
      FROM xxobjt.xxobjt_ratam_qty_subs t
     WHERE t.item_id = p_item_id
       AND t.org_id = p_subsidiary_orgid
       AND t.date_as_of = p_asofdate;
    IF l_count = 1 THEN
      p_org_qty_tbl.delete;
      FOR j IN c_lines LOOP
        p_org_qty_tbl(1).org_id := j.organization_id;
        p_org_qty_tbl(1).quantity := l_curr_qty;--CHG0049395 - Ratam report does  not show T&B items and IN US there is difference from as of date report  in some items 
        EXIT;
      END LOOP;
    ELSE

      l_org_agg_qty := 0;
      p_org_qty_tbl.delete;
      l_index := 1;
      FOR j IN c_lines LOOP
        l_org_agg_qty := l_org_agg_qty + j.quantity_total;
                     
         
        IF l_agg_qty < l_org_agg_qty THEN
          IF l_agg_qty + l_curr_qty <= l_org_agg_qty THEN --CHG0049395 - Ratam report does  not show T&B items and IN US there is difference from as of date report  in some items 
            p_org_qty_tbl(l_index).org_id := j.organization_id;
            p_org_qty_tbl(l_index).quantity := l_curr_qty;--CHG0049395 - Ratam report does  not show T&B items and IN US there is difference from as of date report  in some items 
            l_index := l_index + 1;
            EXIT;
          ELSE
            p_org_qty_tbl(l_index).org_id := j.organization_id;
            p_org_qty_tbl(l_index).quantity := l_org_agg_qty - l_agg_qty;
            l_curr_qty:=l_curr_qty-(l_org_agg_qty - l_agg_qty);--CHG0049395 - Ratam report does  not show T&B items and IN US there is difference from as of date report  in some items 
            l_agg_qty := l_org_agg_qty;
            l_index := l_index + 1;
          END IF;
        END IF;
      END LOOP;
    END IF;
  END get_org_and_qty;
  ----------------------------------------
  --------------------------------------------------------------------
  --  name:            Get_manufacturing_org --CHG0039638
  --  create by:
  --  Revision:        1.0
  --  creation date:   06/11/2016
  --------------------------------------------------------------------
  --  purpose :        Get std cost per organization
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/11/2016      initial build
  --  2.2  20/04/2020  CHG0047477  - Change logic of function to get MFG Org to support new technologies
  --------------------------------------------------------------------
  FUNCTION get_manufacturing_org(pc_itemid IN number, p_asofdate in date)
    RETURN NUMBER is

    l_category         mtl_categories_kfv.segment1%TYPE;
    l_coo              mtl_system_items_b.attribute2%TYPE;
    l_fam              mtl_categories_b_kfv.attribute2%TYPE;
    l_org_id           NUMBER;
    l_line_of_bus      mtl_categories_b_kfv.segment1%TYPE;
    l_TECHNOLOGy       varchar2(150);
    l_LINE_OF_BUSINESS varchar2(150);

  begin
    init_org_from_lookup;
    if is_MB_Item(pc_itemid) = 'Y' then
      l_org_id := g_org_ids_tbl('MB');
    else
      begin
        select msib.attribute2, mic.SEGMENT6, mic.SEGMENT1

          into l_coo, l_TECHNOLOGy, l_LINE_OF_BUSINESS
          FROM mtl_item_categories_v mic,
               mtl_categories_b      mcb,
               mtl_system_items_b    msib

         WHERE mic.organization_id =
               xxinv_utils_pkg.get_master_organization_id
           AND mcb.category_id = mic.category_id
           AND msib.inventory_item_id = mic.inventory_item_id
           AND msib.organization_id =
               xxinv_utils_pkg.get_master_organization_id
           AND mic.category_set_name = 'Product Hierarchy'
           and msib.inventory_item_id = pc_itemid;

        select ORGANIZATION_ID
          into l_org_id
          from (select *
                  from (select odf.ORGANIZATION_ID, 1 l_rank
                          from Q_XX_MFG_ORG_V               mfg,
                               ORG_ORGANIZATION_DEFINITIONS ODF
                         where ODF.ORGANIZATION_CODE =
                               MFG.XX_ORGANIZATION_CODE
                           and mfg.XX_TECHNOLOGY_PH = l_TECHNOLOGy
                           and mfg.XX_LINE_OF_BUSINESS_PH =
                               l_LINE_OF_BUSINESS
                           and mfg.XX_COUNTRIES = l_coo
                        union all
                        select odf.ORGANIZATION_ID, 2 l_rank
                          from Q_XX_MFG_ORG_V               mfg,
                               ORG_ORGANIZATION_DEFINITIONS ODF
                         where ODF.ORGANIZATION_CODE =
                               MFG.XX_ORGANIZATION_CODE
                           and mfg.XX_TECHNOLOGY_PH = l_TECHNOLOGy
                           and mfg.XX_LINE_OF_BUSINESS_PH =
                               l_LINE_OF_BUSINESS
                           and mfg.XX_COUNTRIES is null
                        union all
                        select odf.ORGANIZATION_ID, 3 l_rank
                          from Q_XX_MFG_ORG_V               mfg,
                               ORG_ORGANIZATION_DEFINITIONS ODF
                         where ODF.ORGANIZATION_CODE =
                               MFG.XX_ORGANIZATION_CODE
                           and mfg.XX_TECHNOLOGY_PH = l_TECHNOLOGy
                           and mfg.XX_LINE_OF_BUSINESS_PH is null
                           and mfg.XX_COUNTRIES = l_coo
                        union all

                        select odf.ORGANIZATION_ID, 4 l_rank
                          from Q_XX_MFG_ORG_V               mfg,
                               ORG_ORGANIZATION_DEFINITIONS ODF
                         where ODF.ORGANIZATION_CODE =
                               MFG.XX_ORGANIZATION_CODE
                           and mfg.XX_TECHNOLOGY_PH = l_TECHNOLOGy
                           and mfg.XX_LINE_OF_BUSINESS_PH is null
                           and mfg.XX_COUNTRIES is null

                         order by l_rank))
         where rownum = 1;

        /*
        if v_is_lookup_init = 0 then
          init_org_from_lookup;
        end if;
        sELECT decode(mb.attribute2, 'IL', 'IL', 'US'),
               mc.attribute2,
               mc.segment1
          INTO l_coo, l_fam, l_line_of_bus
          FROM mtl_system_items_b   mb,
               mtl_item_categories  mic,
               mtl_categories_b_kfv mc
         WHERE mb.inventory_item_id = pc_itemid
           AND mb.organization_id = xxinv_utils_pkg.get_master_organization_id
           and mic.organization_id = xxinv_utils_pkg.get_master_organization_id
           and mic.inventory_item_id = pc_itemid
           AND mic.category_set_id = 1100000221
           and mic.category_id = mc.category_id;
        iF xxinv_utils_pkg.is_fdm_item(pc_itemid, NULL) = 'Y' THEN
          if is_MB_Item(pc_itemid) = 'Y' then
            l_org_id := g_org_ids_tbl('MB');
          else
            IF l_coo = 'IL' THEN
              if xxinv_utils_pkg.is_fdm_system_item(pc_itemid) = 'Y' then
                l_org_id := g_org_ids_tbl('FDM_SYS_IL'); --CHG0042478 - Automtically choose time based on location Operating unit timezone
              elsif l_line_of_bus = 'Customer Support' then
                l_org_id := g_org_ids_tbl('FDM_CS_IL'); --CHG0042478 - Automtically choose time based on location Operating unit timezone
              else
                l_org_id := g_org_ids_tbl('FDM_IL');
              end if;
            ELSE
              l_org_id := g_org_ids_tbl('FDM');
            END IF;
          end if;
        else
          IF xxinv_item_classification.is_item_resin(pc_itemid) = 'Y' THEN
            l_org_id := g_org_ids_tbl('POLY_RESIN');
          ELSE
            l_org_id := g_org_ids_tbl('POLY_OTHER');
          END IF;
        end if;
        */
      exception
        when others then
          l_org_id := null;
      end;
    end if;
    return l_org_id;
  end;
  --------------------------------------------------------------------
  --  name:            is_MB_Item --CHG0039638
  --  create by:
  --  Revision:        1.0
  --  creation date:   06/11/2016
  --------------------------------------------------------------------
  --  purpose :        check if item is Makerbot
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/11/2016      initial build
  --------------------------------------------------------------------
  Function is_MB_Item(pc_itemid IN number) RETURN varchar is
    l_ret varchar2(1);
  begin
    l_ret := 'N';
    SELECT 'Y'
      INTO l_ret
      FROM mtl_item_categories mic, mtl_categories_b_kfv mc
     WHERE mic.organization_id = xxinv_utils_pkg.get_master_organization_id
       and mic.inventory_item_id = pc_itemid
       AND mic.category_set_id = 1100000248
       and mic.category_id = mc.category_id
       and mc.segment1 = 'Makerbot';
    return l_ret;
  exception
    when others then
      return 'N';
  end;

END xxcst_ratam_pkg;
/
