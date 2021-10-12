CREATE OR REPLACE PACKAGE BODY XXINV_MATCERCON_PKG IS

--------------------------------------------------------------------
--  name:              XXINV_MATCERCON_PKG
--  create by:         Bellona(TCS)
--  Revision:          1.0
--  creation date:     08/05/2019
--------------------------------------------------------------------
--  purpose :          CHG0045445 - Called from - XX: Materials COC report
--------------------------------------------------------------------
--  ver  date          name              desc
--  1.0  08/05/2019    Bellona(TCS)    initial build
--  1.1  10/10/2019    Bellona(TCS)    CHG0046435 - added missing logic from XML Data source.
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            beforereport
  --  create by:       Bellona(TCS)
  --  Revision:        1.0
  --  creation date:   08/05/2019
  --------------------------------------------------------------------
  --  purpose :        CHG0045445 - XX: Materials COC report
  --                   Checks if report need to be print.
  --                   report will print for delivery that relate to Materials certificate of Conformance.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2019  Bellona(TCS)    initial build    
  --  1.1  10/10/2019  Bellona(TCS)    CHG0046435 - added missing logic from XML Data source.  
  --------------------------------------------------------------------
  FUNCTION beforereport(P_ORGANIZATION_ID IN NUMBER, P_DELIVERY_ID IN NUMBER, P_MOVE_ORDER_LOW IN VARCHAR2)
    RETURN BOOLEAN IS
    l_count NUMBER := 0;

  BEGIN

    if P_DELIVERY_ID is null and P_MOVE_ORDER_LOW is null then
      fnd_file.put_line(fnd_file.log,'Both Parameters are null. Please enter delivery number or move order number.');
      return FALSE;
    end if;

     select count(1)
       INTO l_count
       from WSH_NEW_DELIVERIES wnd
            ,wsh_delivery_assignments wda
            ,wsh_delivery_details wdd
            ,oe_order_headers_all ooha
            ,hz_cust_accounts hca
            ,mtl_txn_request_headers rh
            ,mtl_txn_request_lines   rl
      where wnd.DELIVERY_ID= nvl(P_DELIVERY_ID,wnd.DELIVERY_ID) --1400965
            and wnd.ORGANIZATION_ID= P_ORGANIZATION_ID--729
            and wnd.DELIVERY_ID = wda.DELIVERY_ID
            and wda.delivery_detail_id = wdd.delivery_detail_id
            and wdd.SOURCE_HEADER_ID= ooha.HEADER_ID
            and ooha.SOLD_TO_ORG_ID=hca.cust_account_id
            and wdd.source_header_id     = ooha.header_id
            and    rl.line_id                 = wdd.move_order_line_id
            and rh.header_id             = rl.header_id
            and rh.request_number         = nvl(P_MOVE_ORDER_LOW,rh.request_number)
            --CHG0046435 - added below condition from XML Data source
            and exists (select 1
                   from mtl_system_items_b t
                , MTL_ITEM_CATEGORIES_V msiv
                  where xxinv_utils_pkg.is_fdm_item(wdd.INVENTORY_ITEM_ID)='Y'
                and xxinv_utils_pkg.is_aerospace_item(wdd.INVENTORY_ITEM_ID)='N'
                and t.inventory_item_id = wdd.INVENTORY_ITEM_ID
                AND t.organization_id = wdd.ORGANIZATION_ID--91
                and t.ORGANIZATION_ID=msiv.ORGANIZATION_ID
                and t.INVENTORY_ITEM_ID = msiv.INVENTORY_ITEM_ID
                and msiv.CATEGORY_SET_NAME='Product Hierarchy'
                and msiv.SEGMENT1='Materials'  --LOB
                and msiv.SEGMENT7='FG' --Item Type
                and msiv.SEGMENT6='FDM' --Technology
                and msiv.SEGMENT4 <> 'Aerospace Certified');

    IF l_count <> 0 THEN
      RETURN TRUE;
    ELSE
      fnd_file.put_line(fnd_file.log,
                        '----------------------------------------');
      fnd_file.put_line(fnd_file.log,
                          'No lines to be printed in XX: Materials COC report '||
                          'related to this delivery - ' || P_DELIVERY_ID||
                          'or related to this move order number - '|| P_MOVE_ORDER_LOW ||
                          ' and organization id - '|| P_ORGANIZATION_ID);
      fnd_file.put_line(fnd_file.log,
                        '----------------------------------------');

      RETURN FALSE;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,'----------------------------------------');
      fnd_file.put_line(fnd_file.log,'General error - ' || substr(SQLERRM, 1, 240));
      fnd_file.put_line(fnd_file.log,'Delivery   - ' || p_delivery_id);
      fnd_file.put_line(fnd_file.log,'Organization Id   - ' || P_ORGANIZATION_ID);
      fnd_file.put_line(fnd_file.log,'Move order number - '|| P_MOVE_ORDER_LOW);
      fnd_file.put_line(fnd_file.log,'----------------------------------------');
      RETURN FALSE;
  END beforereport;

END XXINV_MATCERCON_PKG;
/