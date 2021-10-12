CREATE OR REPLACE PACKAGE BODY xxcst_cogs_custom_wf_pkg IS

  g_item_key  VARCHAR2(80);
  g_item_type VARCHAR2(80);

  PROCEDURE log_debug(p_num NUMBER, p_msg VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
  BEGIN
  
    /*INSERT INTO xxobjt_debug
    VALUES
      (p_num, p_msg, g_item_key, g_item_type);
    COMMIT;*/
    NULL;
  
  END;

  FUNCTION f_get_coa_id(p_org_id IN NUMBER)
    RETURN org_organization_definitions.chart_of_accounts_id%TYPE IS
  
    l_coa_id org_organization_definitions.chart_of_accounts_id%TYPE;
  
  BEGIN
  
    SELECT gls.chart_of_accounts_id
      INTO l_coa_id
      FROM hr_operating_units hou, gl_sets_of_books gls
     WHERE hou.organization_id = p_org_id
       AND gls.set_of_books_id = hou.set_of_books_id;
  
    RETURN l_coa_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END f_get_coa_id;

  FUNCTION f_build_ryst_cogs_acct(p_order_line_id IN oe_order_lines_all.line_id%TYPE,
                                  p_inv_org_id    IN NUMBER,
                                  p_sell_org_id   IN NUMBER,
                                  p_ship_org_id   IN NUMBER) RETURN NUMBER IS
  
    -- *************************************************************************************
    -- FUNCTION: F_BUILD_ITL_COGS_ACCT
    --
    -- Purpose: Build IBER ELCO COGS Account.
    --          This program is called from the WF Engine that is calculating the COGS.
    --
    --
    -- Procedure        ESZ_COST_OF_SALES_ACCT
    -- Site             Iber
    -- Module           Oracle Inventory
    -- Date             29-Aug-2004
    -- Author           Hod Shubi, Applet LTD
    -- Version          1.00
  
    --** This procedure is called by package ECP_WSH_FLEX_PKG_COGS, which
    --   is a clone of the standard WSH_FLEX_PKG_COGS package.
  
    -- Purpose
    -------
    -- This procedure is used to build the Cost of Sales Account for Itelco.
  
    -- Source for building the custom Cost of Sales account for Itelco
    -- Segment                     Source
    --------------------------  -------------------------------------------------
    -- 1 Company                   INV, Cost_of_goods_sold (Default)
    -- 2 Legal Account             INV, Cost_of_goods_sold at Item level (Default)
    -- 3 Major Profit Center       INV, Cost_of_goods_sold at Item level (Default)
    -- 4 P     show error      Account (Department)  INV, Cost_of_goods_sold at Item level (Default) Salespersons, REVENUE account
    -- 5 Brand                     INV, Cost_of_goods_sold at Item level (Default) Salespersons, REVENUE account
    -- 6 Intercompany              Salespersons, REVENUE account
    -- 7 Area                      Salespersons, REVENUE account INV, Cost_of_goods_sold at Item level (Default)
    -- 8 Future                    INV, Cost_of_goods_sold at Item level (Default)
  
    -- IF the account in the salesperson level is empty, do nothing
  
    -- INPUT:
    --         p_order_line id IN OE_ORDER_LINES_ALL.line_id%TYPE,
    --         p_inv_org_id IN NUMBER,
    -- OUTPUT: x_return_ccid OUT NUMBER
    --
    -- Revision History
    -- Date      By             What
    -- ========  =========      ================
    --
    -- 29-AUG-04  SHAIE          Initial Version
  
    -- *************************************************************************************
  
    ccid_msii           INTEGER := NULL;
    ccid_srep           INTEGER := NULL;
    ccid_trx            INTEGER := NULL;
    ccid_cust_rec       INTEGER := NULL;
    ccid_po_org_accrual INTEGER := NULL;
  
    failure BOOLEAN := FALSE;
    ok_1    BOOLEAN := FALSE;
    ok_2    BOOLEAN := FALSE;
    ok_3    BOOLEAN := FALSE;
    ok_4    BOOLEAN := FALSE;
    ok_5    BOOLEAN := FALSE;
    ok_35   BOOLEAN := FALSE;
  
    seg_msii        fnd_flex_ext.segmentarray;
    seg_trx         fnd_flex_ext.segmentarray;
    seg_artrx       fnd_flex_ext.segmentarray;
    seg_srep        fnd_flex_ext.segmentarray;
    seg_cust_rec    fnd_flex_ext.segmentarray;
    seg_org_accrual fnd_flex_ext.segmentarray;
  
    seg_cogs     fnd_flex_ext.segmentarray;
    num_segments INTEGER;
    bad_ccid EXCEPTION;
  
    l_coa_id         org_organization_definitions.chart_of_accounts_id%TYPE;
    l_app_short_name fnd_application.application_short_name%TYPE;
    l_delimiter      fnd_id_flex_structures.concatenated_segment_delimiter%TYPE;
    l_new_ccid       NUMBER;
    l_org_id         NUMBER;
  
  BEGIN
  
    dbms_output.put_line('begin main program');
  
    /* get COA information */
    BEGIN
    
      SELECT ood.chart_of_accounts_id, ood.operating_unit
        INTO l_coa_id, l_org_id
        FROM org_organization_definitions ood
       WHERE ood.organization_id = p_inv_org_id;
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    dbms_output.put_line('found coa id: ' || l_coa_id);
  
    -- set org context
    fnd_client_info.set_org_context(l_org_id);
  
    /* 2. get init values for application short name and delimiter */
    BEGIN
    
      SELECT fap.application_short_name,
             fifs.concatenated_segment_delimiter
        INTO l_app_short_name, l_delimiter
        FROM fnd_application        fap,
             fnd_id_flexs           fif,
             fnd_id_flex_structures fifs
       WHERE fif.application_id = fap.application_id
         AND fif.id_flex_code = 'GL#'
         AND fifs.application_id = fif.application_id
         AND fifs.id_flex_code = fif.id_flex_code
         AND fifs.id_flex_num = l_coa_id;
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
      
    END;
  
    dbms_output.put_line('found short name:' || l_app_short_name);
  
    /* 3. get required information to rebuild the COGS ccid */
    BEGIN
      SELECT msi.cost_of_sales_account,
             rsp.gl_id_rev,
             tra.cost_of_goods_sold_account,
             hzcasu.gl_id_rec
        INTO ccid_msii, ccid_srep, ccid_trx, ccid_cust_rec
        FROM oe_order_lines_all       ool,
             mtl_system_items         msi,
             oe_order_headers_all     ooh,
             ra_salesreps             rsp,
             oe_transaction_types_all tra,
             hz_cust_site_uses_all    hzcasu
       WHERE ool.line_id = p_order_line_id
         AND msi.inventory_item_id = ool.inventory_item_id
         AND msi.organization_id = p_inv_org_id
         AND ooh.header_id = ool.header_id
         AND rsp.salesrep_id(+) = ooh.salesrep_id
         AND ooh.order_type_id = tra.transaction_type_id
         AND ooh.invoice_to_org_id = hzcasu.site_use_id;
    
    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('error in getting info for REV: ' || SQLERRM);
      
    END;
  
    /* ========================================== */
    /* 3.5. get the company segment from the OU */
  
    IF p_sell_org_id <> p_ship_org_id THEN
    
      SELECT posp.accrued_code_combination_id
        INTO ccid_po_org_accrual
        FROM po_system_parameters_all posp
       WHERE posp.org_id = p_sell_org_id;
    
      BEGIN
      
        -- conc seg for SALESREP
        ok_35 := fnd_flex_ext.get_segments(l_app_short_name,
                                           'GL#',
                                           l_coa_id,
                                           ccid_po_org_accrual,
                                           num_segments,
                                           seg_org_accrual);
      
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
    END IF;
  
    /* ========================================== */
    /* 4. get the conc. segments for each ccid obtained */
  
    BEGIN
      -- conc seg for ITEM
      ok_1 := fnd_flex_ext.get_segments(l_app_short_name,
                                        'GL#',
                                        l_coa_id,
                                        ccid_msii,
                                        num_segments,
                                        seg_msii);
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    dbms_output.put_line('ok_1: ' || ccid_msii);
  
    /* ========================================== */
    /* 2. get the conc. segments for each ccid obtained */
  
    BEGIN
      -- conc seg for trx type
      ok_2 := fnd_flex_ext.get_segments(l_app_short_name,
                                        'GL#',
                                        l_coa_id,
                                        ccid_trx,
                                        num_segments,
                                        seg_trx);
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    dbms_output.put_line('ok_2: ' || ccid_msii);
  
    BEGIN
    
      -- conc seg for SALESREP
      ok_3 := fnd_flex_ext.get_segments(l_app_short_name,
                                        'GL#',
                                        l_coa_id,
                                        ccid_srep,
                                        num_segments,
                                        seg_srep);
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    dbms_output.put_line('ok_3: ' || ccid_srep);
  
    BEGIN
    
      -- conc seg for SALESREP
      ok_4 := fnd_flex_ext.get_segments(l_app_short_name,
                                        'GL#',
                                        l_coa_id,
                                        ccid_cust_rec,
                                        num_segments,
                                        seg_cust_rec);
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    dbms_output.put_line('ok_4: ' || ccid_cust_rec);
  
    /* ================================== */
    /* 5. assemble new COGS ccid */
    IF ccid_srep IS NOT NULL THEN
    
      seg_cogs(1) := seg_msii(1);
      seg_cogs(2) := seg_trx(2);
      seg_cogs(3) := seg_msii(3);
      seg_cogs(4) := seg_msii(4);
      seg_cogs(5) := seg_msii(5);
      seg_cogs(6) := seg_srep(6);
      seg_cogs(7) := seg_srep(7);
      seg_cogs(8) := seg_msii(8);
    
      dbms_output.put_line('in changing ccid srep:' || ccid_srep);
    
    END IF;
  
    IF ccid_cust_rec IS NOT NULL THEN
    
      seg_cogs(1) := seg_msii(1);
      seg_cogs(2) := seg_msii(2);
      seg_cogs(3) := seg_msii(3);
      seg_cogs(4) := seg_msii(4);
      seg_cogs(5) := seg_msii(5);
      seg_cogs(6) := seg_cust_rec(6);
      seg_cogs(7) := seg_msii(7);
      seg_cogs(8) := seg_msii(8);
    
      dbms_output.put_line('in changing ccid Ccid_Cust_rec:' ||
                           ccid_cust_rec);
    
    END IF;
  
    IF p_sell_org_id <> p_ship_org_id THEN
    
      seg_cogs(1) := seg_msii(1);
      seg_cogs(2) := seg_msii(2);
      seg_cogs(3) := seg_msii(3);
      seg_cogs(4) := seg_msii(4);
      seg_cogs(5) := seg_msii(5);
      seg_cogs(6) := seg_org_accrual(1);
      seg_cogs(7) := seg_msii(7);
      seg_cogs(8) := seg_msii(8);
    
      dbms_output.put_line('in changing ccid l_po_org_accrual:' ||
                           ccid_po_org_accrual);
    
    END IF;
  
    /* validate the ccid exists */
    ok_5 := fnd_flex_ext.get_combination_id(l_app_short_name,
                                            'GL#',
                                            l_coa_id,
                                            SYSDATE,
                                            num_segments,
                                            seg_cogs,
                                            l_new_ccid);
  
    dbms_output.put_line('get ccid: ' || l_new_ccid);
  
    /* ================================== */
    /* 6. decide on return value           */
  
    IF ok_5 THEN
      -- this means the CCID is OK
      RETURN l_new_ccid;
    ELSE
      RETURN - 1;
    END IF;
  
    -- General Exception
  EXCEPTION
    WHEN OTHERS THEN
      RETURN - 1;
    
  END f_build_ryst_cogs_acct;

  PROCEDURE get_cogs_multi_sources(itemtype IN VARCHAR2,
                                   itemkey  IN VARCHAR2,
                                   actid    IN NUMBER,
                                   funcmode IN VARCHAR2,
                                   RESULT   OUT VARCHAR2) IS
    l_cost_sale_item_derived VARCHAR2(240) DEFAULT NULL;
    l_line_id                NUMBER;
    l_organization_id        NUMBER;
    l_sell_org_id            NUMBER;
    l_ship_org_id            NUMBER;
    l_inventory_item_id      NUMBER;
    fb_error_msg             VARCHAR2(240) DEFAULT NULL;
    l_error_msg              VARCHAR2(240) DEFAULT NULL;
    l_item_type_code         VARCHAR2(30);
    l_link_to_line_id        NUMBER;
  
    l_ace_cogs_ccid NUMBER;
  
  BEGIN
  
    oe_debug_pub.add('Entering OE_Flex_Cogs_Pub.GET_COST_SALE_ITEM_DERIVED');
  
    oe_debug_pub.add(' Item Type : ' || itemtype, 2);
    oe_debug_pub.add(' Item Key : ' || itemkey, 2);
    oe_debug_pub.add(' Activity Id : ' || to_char(actid), 2);
    oe_debug_pub.add(' funcmode : ' || funcmode, 2);
  
    IF (funcmode = 'RUN') THEN
      l_line_id           := wf_engine.getitemattrnumber(itemtype,
                                                         itemkey,
                                                         'LINE_ID');
      l_organization_id   := wf_engine.getitemattrnumber(itemtype,
                                                         itemkey,
                                                         'ORGANIZATION_ID');
      l_inventory_item_id := wf_engine.getitemattrnumber(itemtype,
                                                         itemkey,
                                                         'INVENTORY_ITEM_ID');
    
      SELECT link_to_line_id, item_type_code
        INTO l_link_to_line_id, l_item_type_code
        FROM oe_order_lines
       WHERE line_id = l_line_id;
    
      l_cost_sale_item_derived := NULL;
    
      IF l_line_id IS NOT NULL THEN
        BEGIN
          SELECT nvl(m.cost_of_sales_account, 0),
                 ol.sold_from_org_id,
                 to_number(hrou.org_information3)
            INTO l_cost_sale_item_derived, l_sell_org_id, l_ship_org_id
            FROM oe_order_lines              ol,
                 mtl_system_items            m,
                 hr_organization_information hrou
           WHERE ol.line_id = l_line_id
             AND m.organization_id = ol.ship_from_org_id
             AND m.inventory_item_id = ol.inventory_item_id
             AND ol.ship_from_org_id = hrou.organization_id
             AND hrou.org_information_context = 'Accounting Information';
        EXCEPTION
          WHEN no_data_found THEN
          
            IF l_item_type_code <> oe_globals.g_item_config THEN
            
              fnd_message.set_name('ONT', 'OE_COGS_CCID_GEN_FAILED');
              fnd_message.set_token('PARAM1', 'Inventory Item id');
              fnd_message.set_token('PARAM2', '/Warehouse ');
              fnd_message.set_token('VALUE1', l_inventory_item_id);
              fnd_message.set_token('VALUE2', l_organization_id);
              fnd_message.set_token('Sell_ORG', l_sell_org_id);
              fnd_message.set_token('Ship_ORG', l_ship_org_id);
              fb_error_msg := fnd_message.get_encoded;
              fnd_message.set_encoded(fb_error_msg);
              l_error_msg := fnd_message.get;
              wf_engine.setitemattrtext(itemtype,
                                        itemkey,
                                        'ERROR_MESSAGE',
                                        l_error_msg);
              RESULT := 'COMPLETE:FAILURE';
              RETURN;
            END IF;
        END;
      END IF;
    
      -- START ACE Customization
      -- GET COGS account from ACE's COGS Logic.
      -- Updated 29-Aug-04 by SHAIE
      l_ace_cogs_ccid := -1;
      l_ace_cogs_ccid := xxcst_cogs_custom_wf_pkg.f_build_ryst_cogs_acct(p_order_line_id => l_line_id,
                                                                         p_inv_org_id    => l_organization_id,
                                                                         p_sell_org_id   => l_sell_org_id,
                                                                         p_ship_org_id   => l_ship_org_id);
    
      IF nvl(l_ace_cogs_ccid, -1) <> -1 THEN
        l_cost_sale_item_derived := l_ace_cogs_ccid;
      END IF;
    
      -- END OF ACE Customization
    
      IF l_cost_sale_item_derived IS NULL THEN
        /*
        If l_Item_Type_Code = Oe_Globals.g_Item_Config Then
          Oe_Debug_Pub.Add('Going for Model line for CONFIG', 2);
        
          Begin
        
            Select Nvl(m.Cost_Of_Sales_Account, 0)
              Into l_Cost_Sale_Item_Derived
              From Oe_Order_Lines Ol, Mtl_System_Items m
             Where Ol.Line_Id = l_Link_To_Line_Id
               And m.Organization_Id = Ol.Ship_From_Org_Id
               And m.Inventory_Item_Id = Ol.Inventory_Item_Id;
          Exception
            When No_Data_Found Then
              Fnd_Message.Set_Name('ONT', 'OE_COGS_CCID_GEN_FAILED');
              Fnd_Message.Set_Token('PARAM1', 'Inventory Item id');
              Fnd_Message.Set_Token('PARAM2', '/Warehouse ');
              Fnd_Message.Set_Token('VALUE1', l_Inventory_Item_Id);
              Fnd_Message.Set_Token('VALUE2', l_Organization_Id);
              Fb_Error_Msg := Fnd_Message.Get_Encoded;
              Fnd_Message.Set_Encoded(Fb_Error_Msg);
              l_Error_Msg := Fnd_Message.Get;
              Wf_Engine.Setitemattrtext(Itemtype,
                                        Itemkey,
                                        'ERROR_MESSAGE',
                                        l_Error_Msg);
              Result := 'COMPLETE:FAILURE';
              Return;
          End;
        
        End If;*/
      
        fnd_message.set_name('ONT', 'OE_COGS_CCID_GEN_FAILED');
        fnd_message.set_token('PARAM1', 'Inventory Item id');
        fnd_message.set_token('PARAM2', '/Warehouse ');
        fnd_message.set_token('VALUE1', l_inventory_item_id);
        fnd_message.set_token('VALUE2', l_organization_id);
        fb_error_msg := fnd_message.get_encoded;
        fnd_message.set_encoded(fb_error_msg);
        l_error_msg := fnd_message.get;
        wf_engine.setitemattrtext(itemtype,
                                  itemkey,
                                  'ERROR_MESSAGE',
                                  l_error_msg);
        RESULT := 'COMPLETE:FAILURE';
      
      END IF;
    
      IF l_cost_sale_item_derived = 0 THEN
      
        fnd_message.set_name('ONT', 'OE_COGS_CCID_GEN_FAILED');
        fnd_message.set_token('PARAM1', 'Inventory Item id');
        fnd_message.set_token('PARAM2', '/Warehouse ');
        fnd_message.set_token('VALUE1', l_inventory_item_id);
        fnd_message.set_token('VALUE2', l_organization_id);
      
        fb_error_msg := fnd_message.get_encoded;
        fnd_message.set_encoded(fb_error_msg);
        l_error_msg := fnd_message.get;
      
        wf_engine.setitemattrtext(itemtype,
                                  itemkey,
                                  'ERROR_MESSAGE',
                                  l_error_msg);
        RESULT := 'COMPLETE:FAILURE';
        RETURN;
      
      END IF;
    
      wf_engine.setitemattrnumber(itemtype,
                                  itemkey,
                                  'GENERATED_CCID',
                                  to_number(l_cost_sale_item_derived));
      RESULT := 'COMPLETE:SUCCESS';
    
      oe_debug_pub.add('Input Paramerers : ');
      oe_debug_pub.add('Line id :' || to_char(l_line_id));
      oe_debug_pub.add('Organization id :' || to_char(l_organization_id));
      oe_debug_pub.add('Output : ');
      oe_debug_pub.add('Generated CCID :' || l_cost_sale_item_derived);
    
      oe_debug_pub.add('Exiting from OE_Flex_COGS_Pub.Get_Cost_Sale_Item_Derived',
                       1);
    
      RETURN;
    ELSIF (funcmode = 'CANCEL') THEN
      RESULT := wf_engine.eng_completed;
      RETURN;
    ELSE
      RESULT := '';
      RETURN;
    END IF;
  EXCEPTION
  
    WHEN OTHERS THEN
      wf_core.context('OE_FLEX_COGS_PUB',
                      'GET_COST_SALE_ITEM_DERIVED',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode);
      RESULT := 'COMPLETE:FAILURE';
      RAISE;
  END get_cogs_multi_sources;

  PROCEDURE inv_cogs_source_branch(itemtype IN VARCHAR2,
                                   itemkey  IN VARCHAR2,
                                   actid    IN NUMBER,
                                   funcmode IN VARCHAR2,
                                   RESULT   OUT VARCHAR2) IS
  
    l_line_id        NUMBER;
    l_source_id      NUMBER;
    l_item_cogs      NUMBER;
    l_ordertype_cogs NUMBER;
  
  BEGIN
  
    oe_debug_pub.add('Entering OE_Flex_Cogs_Pub.GET_COST_SALE_ITEM_DERIVED');
  
    oe_debug_pub.add(' Item Type : ' || itemtype, 2);
    oe_debug_pub.add(' Item Key : ' || itemkey, 2);
    oe_debug_pub.add(' Activity Id : ' || to_char(actid), 2);
    oe_debug_pub.add(' funcmode : ' || funcmode, 2);
  
    IF (funcmode = 'RUN') THEN
      l_line_id        := wf_engine.getitemattrnumber(itemtype,
                                                      itemkey,
                                                      'IC_ORDER_LINE_ID');
      l_item_cogs      := wf_engine.getitemattrnumber(itemtype,
                                                      itemkey,
                                                      'IC_ITEMS_COGS');
      l_ordertype_cogs := wf_engine.getitemattrnumber(itemtype,
                                                      itemkey,
                                                      'IC_ORDER_TYPE_COGS');
    
      SELECT nvl(oel.source_document_type_id, -1)
        INTO l_source_id
        FROM oe_order_lines_all oel
       WHERE line_id = l_line_id;
    
      IF l_source_id = 10 THEN
        RESULT := 'COMPLETE:TRUE';
      ELSE
      
        IF l_item_cogs IS NULL THEN
          -- l_Item_Cogs:=l_OrderType_Cogs;
          wf_engine.setitemattrnumber(itemtype => itemtype,
                                      itemkey  => itemkey,
                                      aname    => 'IC_ITEMS_COGS',
                                      avalue   => l_ordertype_cogs);
        END IF;
      
        RESULT := 'COMPLETE:FALSE';
      END IF;
    
    ELSIF (funcmode = 'CANCEL') THEN
      RESULT := wf_engine.eng_completed;
      RETURN;
    ELSE
      RESULT := '';
      RETURN;
    END IF;
  EXCEPTION
  
    WHEN OTHERS THEN
      wf_core.context('OE_FLEX_COGS_PUB',
                      'GET_COST_SALE_ITEM_DERIVED',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode);
      RESULT := 'COMPLETE:FAILURE';
      RAISE;
  END inv_cogs_source_branch;

  FUNCTION build_cogs_ccid(p_order_line_id   NUMBER,
                           p_order_type_ccid NUMBER,
                           p_line_type_ccid  NUMBER,
                           p_item_cogs_ccid  NUMBER,
                           p_cust_site_ccid  NUMBER,
                           p_inv_org_id      NUMBER,
                           p_sell_org_id     NUMBER,
                           p_source          VARCHAR2,
                           p_order_type_attr VARCHAR2,
                           p_order_dept_seg  gl_code_combinations.segment2%TYPE,
                           p_cust_location   gl_code_combinations.segment6%TYPE,
                           p_coa_id          org_organization_definitions.chart_of_accounts_id%TYPE,
                           p_return_status   OUT VARCHAR2,
                           p_error_msg       OUT VARCHAR2) RETURN NUMBER IS
    -- *************************************************************************************
    -- FUNCTION: BUILD_COGS_CCID
    --
    -- Purpose: Build Objet COGS Account.
    --          This program is called from the WF Engine that is calculating the COGS.
    --
    --
    -- Procedure        ESZ_COST_OF_SALES_ACCT
    -- Module           Oracle Inventory
    -- Date             29-Aug-2004
    -- Author           Hod Shubi, Applet LTD
    -- Version          1.00
  
    --** This procedure is called by workflows, Generate Cost of Goods Sold Account,
    --   Inventory Cost of Goods Sold Account, OM : Generate Cost of Goods Sold Account
  
    -- Purpose
    -------
    -- This procedure is used to build the Cost of Sales Account.
  
    -- Source for building the custom Cost of Sales account
    -- Segment                     Source
    --------------------------  -------------------------------------------------
    -- 1. Company
    -- 2. Department            INV, Cost_of_goods_sold at Item level (Default)
    -- 3. Account               INV, Cost_of_goods_sold at Item level (Default)/cost_of_goods_sold_account for Order Type
    -- 4. Sub Account           INV, Cost_of_goods_sold at Item level (Default)
    -- 5. Product Line          INV, Cost_of_goods_sold at Item level (Default)
    -- 6. Location              Customer Site, Revenue Account
    -- 7. Intercompany          Customer Site, Revenue Account
    -- 8. Future1               INV, Cost_of_goods_sold at Item level (Default)
    -- 9. Future2               INV, Cost_of_goods_sold at Item level (Default)
  
    -- INPUT:
    --         p_order_line id IN OE_ORDER_LINES_ALL.line_id%TYPE,
    --         p_inv_org_id IN NUMBER,
    -- OUTPUT: x_return_ccid OUT NUMBER
    --
    -- Revision History
    -- Date      By             What
    -- ========  =========      ================
    --
    -- 29-AUG-04  SHAIE          Initial Version
    -- 29-MAR-09  Ella           Objet Version
    -- 03-DEC-13  Ofer Suad      Ssys changes .
    -- 25-Jun-14  Ofer Suad      CHG0032546- Fix AP I/C  Drop shipment in US from IL
    -- 23-Jul-17  Ofer Stuad     CHG0040750 Allocate revenue to LE that own IP when item assembled in another LE
    -- *************************************************************************************
  
    l_result BOOLEAN := FALSE;
  
    seg_sell_comp fnd_flex_ext.segmentarray;
    seg_trx_type  fnd_flex_ext.segmentarray;
    seg_line_type fnd_flex_ext.segmentarray;
    seg_item_cogs fnd_flex_ext.segmentarray;
    seg_cust_site fnd_flex_ext.segmentarray;
    seg_ship_comp fnd_flex_ext.segmentarray;
  
    seg_cogs     fnd_flex_ext.segmentarray;
    num_segments INTEGER;
    bad_ccid EXCEPTION;
  
    l_coa_id      org_organization_definitions.chart_of_accounts_id%TYPE;
    l_ord_coa_id  org_organization_definitions.chart_of_accounts_id%TYPE;
    l_item_coa_id org_organization_definitions.chart_of_accounts_id%TYPE;
    -- l_ord_coa        org_organization_definitions.chart_of_accounts_id%TYPE;
    l_app_short_name fnd_application.application_short_name%TYPE;
    l_delimiter      fnd_id_flex_structures.concatenated_segment_delimiter%TYPE;
    l_new_ccid       NUMBER;
    l_ship_org_id    NUMBER;
  
    l_account  VARCHAR2(50);
    l_ip_flag  number;
    l_trans_id varchar2(25);
    l_tra_org_id  number;
  
  BEGIN
  
    p_return_status := fnd_api.g_ret_sts_success;
    --  03-DEC-13  Ofer Suad Support new chart of account
    --   if p_order_type_ccid is not null or p_line_type_ccid is not null then
    IF nvl(p_order_type_ccid, 0) != 0 OR nvl(p_line_type_ccid, 0) != 0 THEN
      SELECT gcc.chart_of_accounts_id
        INTO l_ord_coa_id
        FROM gl_code_combinations gcc
       WHERE gcc.code_combination_id =
             decode(nvl(p_order_type_ccid, 0),
                    0,
                    p_line_type_ccid,
                    p_order_type_ccid);
    
    END IF;
  
    IF p_item_cogs_ccid IS NOT NULL THEN
      SELECT gcc.chart_of_accounts_id
        INTO l_item_coa_id
        FROM gl_code_combinations gcc
       WHERE gcc.code_combination_id = p_item_cogs_ccid;
    
    END IF;
  
    l_coa_id := p_coa_id;
  
    SELECT /*ood.chart_of_accounts_id,*/
     ood.operating_unit
      INTO /*l_coa_id, */ l_ship_org_id
      FROM org_organization_definitions ood
     WHERE ood.organization_id = p_inv_org_id;
  
    /* get COMPANY SEGMENT information FOR the SELLING organization */
  
    SELECT CONSTANT
      INTO seg_sell_comp(1)
      FROM ra_account_defaults_all rad, ra_account_default_segments rads
     WHERE rad.gl_default_id = rads.gl_default_id
       AND org_id = p_sell_org_id
       AND TYPE = 'REV'
       AND segment_num = 1;
  
    /* get COMPANY SEGMENT information FOR the SHIPPING organization */
  
    SELECT CONSTANT
      INTO seg_ship_comp(1)
      FROM ra_account_defaults_all rad, ra_account_default_segments rads
     WHERE rad.gl_default_id = rads.gl_default_id
       AND org_id = l_ship_org_id
       AND TYPE = 'REV'
       AND segment_num = 1;
  
    /* 2. get init values for application short name and delimiter */
  
    SELECT fap.application_short_name, fifs.concatenated_segment_delimiter
      INTO l_app_short_name, l_delimiter
      FROM fnd_application        fap,
           fnd_id_flexs           fif,
           fnd_id_flex_structures fifs
     WHERE fif.application_id = fap.application_id
       AND fif.id_flex_code = 'GL#'
       AND fifs.application_id = fif.application_id
       AND fifs.id_flex_code = fif.id_flex_code
       AND fifs.id_flex_num = l_coa_id;
  
    /* ========================================== */
    /* 3. get the transaction_type segment from the OU */
    BEGIN
      /*  select gcc.chart_of_accounts_id
      into l_ord_coa
      from gl_code_combinations gcc
      where gcc.code_combination_id=p_order_type_ccid;*/
    
      l_result := fnd_flex_ext.get_segments(l_app_short_name,
                                            'GL#',
                                            l_ord_coa_id, ---
                                            p_order_type_ccid,
                                            num_segments,
                                            seg_trx_type);
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    /* 3. get the line_transaction_type segment from the OU */
    BEGIN
    
      l_result := fnd_flex_ext.get_segments(l_app_short_name,
                                            'GL#',
                                            l_ord_coa_id, --l_coa_id,
                                            p_line_type_ccid,
                                            num_segments,
                                            seg_line_type);
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    /* ========================================== */
    /* 4. get the conc. segments for each ccid obtained */
  
    BEGIN
      -- conc seg for ITEM
      l_result := fnd_flex_ext.get_segments(l_app_short_name,
                                            'GL#',
                                            l_item_coa_id, --l_coa_id,
                                            p_item_cogs_ccid,
                                            num_segments,
                                            seg_item_cogs);
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    /* ========================================== */
    /* 5. get the conc. segments for each ccid obtained */
  
    BEGIN
      -- conc seg for trx type
      l_result := fnd_flex_ext.get_segments(l_app_short_name,
                                            'GL#',
                                            l_coa_id,
                                            p_cust_site_ccid,
                                            num_segments,
                                            seg_cust_site);
      -- 03-DEC-13  Ofer Suad Defualt I/C and location segemnts when not set in customer accounts
      IF NOT l_result THEN
        IF l_coa_id = 50308 THEN
          seg_cust_site(6) := p_cust_location;
          seg_cust_site(7) := '00';
        ELSE
          seg_cust_site(5) := p_cust_location;
          seg_cust_site(6) := '00';
        END IF;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    /* ================================== */
    /* 5. assemble new COGS ccid */
   
   
    CASE l_coa_id
    --  03-DEC-13  Ofer Suad Support new chart of account
      WHEN 50308 THEN
      
        /* CHG0033157 -  Ofer Suad 14-sep-2014 - D-S on Drop Shipment for T&B, Show and rental fail cost accounting*/
        -- IL COA
        IF p_line_type_ccid IS NOT NULL and
           (p_sell_org_id = l_ship_org_id or p_source = 'INVFLXWF') THEN
        
          --p_line_type_ccid is NOT null MEANS COGS exist at OM line type level
          seg_cogs(1) := seg_sell_comp(1);
          seg_cogs(2) := nvl(p_order_dept_seg, seg_line_type(2));
          seg_cogs(3) := seg_line_type(3);
          seg_cogs(4) := seg_line_type(4);
          seg_cogs(5) := seg_line_type(5);
          seg_cogs(6) := seg_line_type(6);
          seg_cogs(7) := CASE
                           WHEN p_sell_org_id != l_ship_org_id THEN
                            seg_ship_comp(1)
                           ELSE
                            seg_line_type(7)
                         END;
          seg_cogs(8) := seg_line_type(8);
          seg_cogs(9) := seg_line_type(9);
        
        ELSIF nvl(p_order_type_ccid, 0) = 0 AND p_source = 'INVFLXWF' THEN
        
          seg_cogs(1) := seg_sell_comp(1);
          seg_cogs(2) := seg_item_cogs(2);
          seg_cogs(3) := seg_item_cogs(3);
          seg_cogs(4) := CASE
                           WHEN l_item_coa_id = 50308 THEN
                            seg_item_cogs(4)
                           ELSE
                            '0000000'
                         END;
          seg_cogs(5) := CASE
                           WHEN l_item_coa_id = 50308 THEN
                            seg_item_cogs(5)
                           ELSE
                            seg_item_cogs(4)
                         END;
          seg_cogs(6) := seg_cust_site(6);
          seg_cogs(7) := seg_ship_comp(1);
          seg_cogs(8) := CASE
                           WHEN l_item_coa_id = 50308 THEN
                            seg_item_cogs(8)
                           ELSE
                            '0000'
                         END;
          seg_cogs(9) := CASE
                           WHEN l_item_coa_id = 50308 THEN
                            seg_item_cogs(9)
                           ELSE
                            '000000'
                         END;
        
        ELSIF p_source = 'INVFLXWF' THEN
       

          /************************************************** 
          CHG0040750 Allocate revenue to LE that own IP when item assembled in another LE 
          ***************************************************/
          l_ip_flag := 0;
          begin
            select 1, interface_line_attribute7,interface_line_attribute4
              into l_ip_flag, l_trans_id,l_tra_org_id
              from ra_interface_lines_all ril
             where ril.interface_line_attribute6 = to_char(p_order_line_id)
               and ril.request_id in (-998, -999)
               and rownum = 1;
          
          
          
            SELECT gcc.segment1, gcc.segment3, gcc.segment5, gcc.segment7
              into seg_cogs(1), seg_cogs(3), seg_cogs(5), seg_cogs(7)
              FROM mtl_transaction_accounts mta, gl_code_combinations gcc,
              org_organization_definitions odf
             where transaction_id = l_trans_id
               and accounting_line_type = 2
               and mta.cost_element_id is null
               and gcc.code_combination_id = mta.reference_account
               and odf.ORGANIZATION_ID=mta.organization_id 
               and odf.OPERATING_UNIT=l_tra_org_id;
          
          exception
            when others then
              l_ip_flag := 0;
            
          end;
      
      
        if l_ip_flag <> 0 then
          if p_sell_org_id <> l_tra_org_id then
              seg_cogs(1) := seg_sell_comp(1); --
              seg_cogs(3) := seg_item_cogs(3);
              end if;
         else
           /* if l_ship_org_id <> l_tra_org_id then
            
              seg_cogs(1) := seg_sell_comp(1);
              seg_cogs(3) := seg_item_cogs(3);
              seg_cogs(5) := seg_item_cogs(5);
              seg_cogs(7) := seg_ship_comp(1); --seg_cogs(6);
            end if;*/
         -- else
            seg_cogs(1) := seg_trx_type(1);
            seg_cogs(3) := seg_trx_type(3);
            seg_cogs(5) := seg_trx_type(5);
            
          end if;
          /*********************************************** 
          end  CHG0040750 
          ************************************************/
          --seg_cogs(1) := seg_sell_comp(1);
          seg_cogs(2) := seg_trx_type(2); --
          seg_cogs(4) := seg_trx_type(4);
          seg_cogs(6) := seg_trx_type(6);
          seg_cogs(7) := seg_ship_comp(1);
          seg_cogs(8) := seg_trx_type(8);
          seg_cogs(9) := seg_trx_type(9);
          
           
        
        ELSE
        
          seg_cogs(1) := seg_ship_comp(1);
          seg_cogs(2) := nvl(p_order_dept_seg, seg_item_cogs(2));
          seg_cogs(3) := CASE
                         /* CHG0033157 -  Ofer Suad 14-sep-2014 - D-S on Drop Shipment for T&B, Show and rental fail cost accounting*/
                           WHEN p_order_type_attr = 'TYPE' and
                                p_sell_org_id = l_ship_org_id THEN
                            seg_trx_type(3)
                           ELSE
                            seg_item_cogs(3)
                         END;
          seg_cogs(4) := seg_item_cogs(4);
          seg_cogs(5) := seg_item_cogs(5);
          seg_cogs(6) := seg_cust_site(6);
          seg_cogs(7) := CASE
                           WHEN p_sell_org_id != l_ship_org_id THEN
                            seg_sell_comp(1)
                           ELSE
                            seg_cust_site(7)
                         END;
          seg_cogs(8) := seg_item_cogs(8);
          seg_cogs(9) := seg_item_cogs(9);
        
        END IF;
      
        IF fnd_flex_ext.get_combination_id(l_app_short_name,
                                           'GL#',
                                           l_coa_id,
                                           SYSDATE,
                                           9,
                                           seg_cogs,
                                           l_new_ccid) THEN
        
          --  l_account := to_char(seg_cogs);
          -- oe_debug_pub.add(' Account : ' || p_itemtype, 2);
           
          RETURN l_new_ccid;
        
        ELSE
        
          p_return_status := fnd_api.g_ret_sts_error;
          p_error_msg     := 'error';
          RETURN NULL;
        END IF;
      
      WHEN 50449 THEN
     
        --p_line_type_ccid is NOT null MEANS COGS exist at OM line type level
        /* CHG0033157 -  Ofer Suad 14-sep-2014 - D-S on Drop Shipment for T&B, Show and rental fail cost accounting*/
        -- SSYS COA
      
        IF p_line_type_ccid IS NOT NULL and
           (p_sell_org_id = l_ship_org_id or p_source = 'INVFLXWF') THEN
          --p_line_type_ccid is NOT null MEANS COGS exist at OM line type level
          seg_cogs(1) := seg_sell_comp(1);
          seg_cogs(2) := nvl(p_order_dept_seg, seg_line_type(2));
          seg_cogs(3) := seg_line_type(3);
        
          -- 24-APR-14 Mike Mazanet CHG0032070 When p_order_dept_seg is NOT NULL,
          -- we have an FOC order.  In these cases we want to populate segment2
          -- with this value, but we also want to set the product segment (4)
          -- to '000'
          seg_cogs(4) := CASE
                           WHEN p_order_dept_seg IS NULL THEN
                            seg_line_type(4)
                           ELSE
                            '000'
                         END;
          seg_cogs(5) := seg_line_type(5);
          seg_cogs(6) := CASE
                           WHEN p_sell_org_id != l_ship_org_id THEN
                            seg_ship_comp(1)
                           ELSE
                            seg_line_type(6)
                         END;
          seg_cogs(7) := seg_line_type(7);
          seg_cogs(8) := seg_line_type(8);
        
        ELSIF nvl(p_order_type_ccid, 0) = 0 AND p_source = 'INVFLXWF' THEN
        
          -- Begin 25-Jun-14  Ofer Suad    CHG0032546  Fix AP I/C  Drop shipment in US from IL
          seg_cogs(1) := seg_sell_comp(1);
          seg_cogs(2) := seg_item_cogs(2);
          seg_cogs(3) := seg_item_cogs(3);
          -- seg_cogs(4) := NULL;
          seg_cogs(4) := CASE
                           WHEN l_item_coa_id = 50449 THEN
                            seg_item_cogs(4)
                           ELSE
                            seg_item_cogs(5) --'0000000'
                         END; --seg_item_cogs(4);
          seg_cogs(5) := seg_cust_site(5);
          seg_cogs(6) := seg_ship_comp(1);
          --  seg_cogs(8) := NULL;
          seg_cogs(7) := CASE
                           WHEN l_item_coa_id = 50449 THEN
                            seg_item_cogs(7)
                           ELSE
                            '000'
                         END;
          seg_cogs(8) := CASE
                           WHEN l_item_coa_id = 50449 THEN
                            seg_item_cogs(8)
                           ELSE
                            '0000'
                         END;
        
          -- End 25-Jun-14  Ofer Suad     CHG0032546 Fix AP I/C  Drop shipment in US from IL
        ELSIF p_source = 'INVFLXWF' THEN
        
     
      
        
        
          l_ip_flag := 0;
          begin
            select 1, interface_line_attribute7,interface_line_attribute4
              into l_ip_flag, l_trans_id,l_tra_org_id
              from ra_interface_lines_all ril
             where ril.interface_line_attribute6 = to_char(p_order_line_id)
               and ril.request_id in (-998, -999)
               and rownum = 1;
          
            SELECT gcc.segment1, gcc.segment3, gcc.segment5, gcc.segment7
              into seg_cogs(1), seg_cogs(3), seg_cogs(4), seg_cogs(7)
              FROM mtl_transaction_accounts mta, gl_code_combinations gcc,
              org_organization_definitions odf
             where transaction_id = l_trans_id
               and accounting_line_type = 2
               and mta.cost_element_id is null
               and gcc.code_combination_id = mta.reference_account
               and odf.ORGANIZATION_ID=mta.organization_id 
               and odf.OPERATING_UNIT=l_tra_org_id;
          
          exception
            when others then
              l_ip_flag := 0;
            
          end;
            
        
          if l_ip_flag <> 0 then
            if p_sell_org_id <> l_tra_org_id then
              seg_cogs(1) := seg_sell_comp(1); --
              seg_cogs(3) := seg_item_cogs(3);
              if l_item_coa_id <> 50449 then
                seg_cogs(4) := seg_item_cogs(5);
                seg_cogs(7) := seg_item_cogs(6);
              else
                seg_cogs(4) := seg_item_cogs(4);
                seg_cogs(7) := seg_item_cogs(7);
              end if;
            end if;
          else
            seg_cogs(1) := seg_trx_type(1); --
            seg_cogs(3) := seg_trx_type(3); --
            seg_cogs(4) := seg_trx_type(4);
            seg_cogs(7) := seg_trx_type(7);
          
          end if;
          --
          --seg_cogs(1) := seg_sell_comp(1);
          seg_cogs(2) := seg_trx_type(2); --
          seg_cogs(5) := seg_trx_type(5);
          seg_cogs(6) := seg_ship_comp(1);
          seg_cogs(8) := seg_trx_type(8);
          
          
          
          
      
        ELSE
        
          seg_cogs(1) := seg_ship_comp(1);
          seg_cogs(2) := nvl(p_order_dept_seg, seg_item_cogs(2));
          seg_cogs(3) := CASE
                         /* CHG0033157 -  Ofer Suad 14-sep-2014 - D-S on Drop Shipment for T&B, Show and rental fail cost accounting*/
                           WHEN p_order_type_attr = 'TYPE' and
                                p_sell_org_id = l_ship_org_id THEN
                            seg_trx_type(3)
                           ELSE
                            seg_item_cogs(3)
                         END;
          --  seg_cogs(4) := seg_item_cogs(4);
        
          -- 24-APR-14 Mike Mazanet CHG0032070 When p_order_dept_seg is NOT NULL,
          -- we have an FOC order.  In these cases we want to populate segment2
          -- with this value, but we also want to set the product segment (4)
          -- to '000'
          seg_cogs(4) := CASE
                           WHEN p_order_dept_seg IS NULL THEN
                            seg_item_cogs(4)
                           ELSE
                            '000'
                         END;
          seg_cogs(5) := seg_item_cogs(5);
          seg_cogs(6) := CASE
                           WHEN p_sell_org_id != l_ship_org_id THEN
                            seg_sell_comp(1)
                           ELSE
                            seg_cust_site(6)
                         END;
          -- seg_cogs(8) := seg_item_cogs(8);
          seg_cogs(7) := seg_item_cogs(7);
          seg_cogs(8) := seg_item_cogs(8);
        END IF;
        
       
        
   
       
       
        IF fnd_flex_ext.get_combination_id(l_app_short_name,
                                           'GL#',
                                           l_coa_id,
                                           SYSDATE,
                                           8,
                                           seg_cogs,
                                           l_new_ccid) THEN
        
          --  l_account := to_char(seg_cogs);
          -- oe_debug_pub.add(' Account : ' || p_itemtype, 2);
         
          RETURN l_new_ccid;
        
        ELSE
        
          p_return_status := fnd_api.g_ret_sts_error;
          p_error_msg     := 'error';
          RETURN NULL;
        
        END IF;
      
    END CASE;
  
    /* validate the ccid exists */
  EXCEPTION
    WHEN OTHERS THEN
      log_debug(11, 'excep=' || SQLERRM);
    
  END build_cogs_ccid;

  -- *************************************************************************************
  -- FUNCTION: GET_COGS_CCID
  --
  -- Purpose: Get COGS info to build account
  --
  -- Revision History
  -- Date      By             What
  -- ========  =========      ================
  --
  -- 29-AUG-04  SHAIE          Initial Version
  -- 02-APR-14  Mike Mazanet   CHG0031815 (search code for CHG to see code change)
  -- 24-APR-14  Mike Mazanet   CHG0032070 Needed to define l_coa_id before using it in
  --                           SQL for CHG0031815, otherwise department segment was not
  --                           being defined correctly.
  -- *************************************************************************************

  PROCEDURE get_cogs_ccid(p_itemtype        IN VARCHAR2,
                          p_itemkey         IN VARCHAR2,
                          p_actid           IN NUMBER,
                          p_funcmode        IN VARCHAR2,
                          p_line_id         IN NUMBER,
                          p_inventory_id    IN NUMBER,
                          p_organization_id IN NUMBER,
                          p_org_id          IN NUMBER,
                          p_order_type_cogs IN NUMBER,
                          x_resultout       OUT NOCOPY VARCHAR2) IS
  
    l_order_type_cogs_id NUMBER := NULL;
    l_line_type_cogs_id  NUMBER := NULL;
    l_item_cogs_id       NUMBER := NULL;
    l_org_id             NUMBER := NULL;
    l_invoice_to_org_id  NUMBER := NULL;
    l_cust_site_rev_id   NUMBER := NULL;
    fb_error_msg         VARCHAR2(240) DEFAULT NULL;
    l_error_msg          VARCHAR2(240) DEFAULT NULL;
    l_item_type_code     VARCHAR2(30);
    l_order_type_attr    VARCHAR2(30);
    l_cogs_ccid          NUMBER;
    p_order_header_id    NUMBER;
    l_return_status      VARCHAR2(1);
    l_coa_id             org_organization_definitions.chart_of_accounts_id%TYPE;
    l_order_dept_seg     gl_code_combinations.segment2%TYPE;
    l_cust_location      gl_code_combinations.segment6%TYPE;
    
  BEGIN
  
    oe_debug_pub.add('Entering OE_Flex_Cogs_Pub.GET_COST_SALE_ITEM_DERIVED');
  
    oe_debug_pub.add(' Item Type : ' || p_itemtype, 2);
    oe_debug_pub.add(' Item Key : ' || p_itemkey, 2);
    oe_debug_pub.add(' Activity Id : ' || to_char(p_actid), 2);
    oe_debug_pub.add(' funcmode : ' || p_funcmode, 2);
  
    IF (p_funcmode = 'RUN') THEN
    
      -- 24-APR-14 Mike Mazanet CHG0032070 Definition of l_coa_id was previously defined at
      -- the end of the IF statement above, before build_cogs_ccid was called.  However, I need to use
      -- it in the SELECT statement within IF p_line_id IS NOT NULL for FOC orders, so I've moved it
      -- to here.
      l_coa_id := wf_engine.getitemattrnumber(itemtype => p_itemtype,
                                              itemkey  => p_itemkey,
                                              aname    => 'CHART_OF_ACCOUNTS_ID');
    
      
    
      -- mo_global.set_policy_context('S', p_org_id);
      IF p_line_id IS NOT NULL THEN
      
        SELECT decode(olt.attribute1,
                      'TYPE',
                      olt.attribute1,
                      ott.attribute1),
               decode(olt.attribute1,
                      'TYPE',
                      olt.cost_of_goods_sold_account,
                      ott.cost_of_goods_sold_account),
               decode(olt.attribute1,
                      'TYPE',
                      olt.cost_of_goods_sold_account,
                      NULL),
               msi.cost_of_sales_account,
               hcsu.gl_id_rev,
               -- 03-DEC-13  Ofer Suad       Get department for FOC orders.
               -- 02-APR-14  Mike Mazanet    CHG0031815 Changed to pull department flex_value rather than id, which
               --                            is stored in attribute7
               -- 29-APR-14  Mike Mazanet    CHG0032070 Pulling department off of the _dfv table because it is
               --                            context sensitive.
               DECODE(ott.attribute13,
                      'Y',
                      CASE l_coa_id
                        WHEN 50449 THEN -- us coa
                         (SELECT val.flex_value
                            FROM fnd_flex_values val
                           WHERE val.flex_value_set_id = 1020161 --XXGL_DEPARTMENT_SS
                             AND val.flex_value_id =
                                 TO_NUMBER(ohdfv.department))
                        ELSE -- other coa
                         (SELECT val.flex_value
                            FROM fnd_flex_values val
                           WHERE val.flex_value_set_id = 1013889 --  XXGL_DEPARTMENT_SEG
                             AND val.flex_value_id =
                                 TO_NUMBER(ohdfv.department))
                      END,
                      NULL)
          INTO l_order_type_attr,
               l_order_type_cogs_id,
               l_line_type_cogs_id,
               l_item_cogs_id,
               l_cust_site_rev_id,
               l_order_dept_seg
          FROM oe_order_headers_all oh,
               -- 29-APR-14  Mike Mazanet    CHG0032070
               -- Using _dfv so I don't have to figure out where Department is located for the flexfield, as it is context sensitive
               oe_order_headers_all_dfv ohdfv,
               oe_order_lines_all       ol,
               mtl_system_items_b       msi,
               oe_transaction_types_all ott,
               oe_transaction_types_all olt,
               hz_cust_site_uses_all    hcsu
         WHERE ol.line_id = p_line_id
           AND oh.header_id = ol.header_id
           AND oh.rowid = ohdfv.rowid(+)
           AND oh.order_type_id = ott.transaction_type_id
           AND ott.transaction_type_code = 'ORDER'
           AND ol.line_type_id = olt.transaction_type_id
           AND olt.transaction_type_code = 'LINE'
           AND hcsu.site_use_id = ol.invoice_to_org_id
           AND ol.inventory_item_id = msi.inventory_item_id
           AND ol.ship_from_org_id = msi.organization_id;
      
        --Hod:begin
      
        IF p_order_type_cogs IS NOT NULL THEN
          l_order_type_cogs_id := p_order_type_cogs;
        END IF;
      
      ELSE
      
        SELECT msi1.cost_of_sales_account
          INTO l_item_cogs_id
          FROM mtl_system_items_b msi1
         WHERE msi1.inventory_item_id = p_inventory_id
           AND msi1.organization_id = p_organization_id;
      
        p_order_header_id := wf_engine.getitemattrnumber(itemtype => p_itemtype,
                                                         itemkey  => p_itemkey,
                                                         aname    => 'IC_ORDER_HEADER_ID');
        SELECT hcsu.gl_id_rev
          INTO l_cust_site_rev_id
          FROM oe_order_headers_all oh, hz_cust_site_uses_all hcsu
         WHERE oh.header_id = p_order_header_id
           AND hcsu.site_use_id = oh.invoice_to_org_id;
      
      END IF;
      -- 03-DEC-13  Ofer Suad      Defualt cust location when not set in customer account.
      l_cust_location := '000';
      IF l_cust_site_rev_id IS NULL THEN
        BEGIN
          SELECT xmp.value_constant
            INTO l_cust_location
            FROM ar.hz_cust_site_uses_all hcsu,
                 hz_cust_acct_sites_all   hcs,
                 hz_party_sites           hps,
                 hz_locations             hl,
                 xla_mapping_set_values   xmp,
                 oe_order_lines_all       ol
           WHERE hcs.cust_acct_site_id = hcsu.cust_acct_site_id
             AND hps.party_site_id = hcs.party_site_id
             AND hl.location_id = hps.location_id
             AND xmp.input_value_constant = hl.state
             AND ol.line_id = p_line_id
             AND ol.ship_to_org_id = hcsu.site_use_id;
        
        EXCEPTION
          WHEN OTHERS THEN
            l_cust_location := '000';
        END;
      END IF;
      -- End Defualt cust location when not set in customer account.
      --Hod:end
    
      l_cogs_ccid := NULL;
      l_cogs_ccid := build_cogs_ccid(p_order_line_id   => p_line_id,
                                     p_order_type_ccid => l_order_type_cogs_id,
                                     p_line_type_ccid  => l_line_type_cogs_id,
                                     p_item_cogs_ccid  => l_item_cogs_id,
                                     p_cust_site_ccid  => l_cust_site_rev_id,
                                     p_inv_org_id      => p_organization_id,
                                     p_sell_org_id     => p_org_id,
                                     p_source          => p_itemtype,
                                     p_order_type_attr => l_order_type_attr,
                                     p_order_dept_seg  => l_order_dept_seg, -- 03-DEC-13  Ofer Suad      Get department for FOC orders.
                                     p_cust_location   => l_cust_location, -- 03-DEC-13  Ofer Suad      Defualt cust location when not set in customer account.
                                     p_coa_id          => l_coa_id,
                                     p_return_status   => l_return_status,
                                     p_error_msg       => l_error_msg);
    
      IF l_return_status != fnd_api.g_ret_sts_success THEN
      
        oe_debug_pub.add('Error building account: ' || l_error_msg);
      
        fnd_message.set_name('ONT', 'OE_COGS_CCID_GEN_FAILED');
        fnd_message.set_token('PARAM1', 'Inventory Item id');
        fnd_message.set_token('PARAM2', '/Warehouse ');
        fnd_message.set_token('VALUE1', p_inventory_id);
        fnd_message.set_token('VALUE2', p_organization_id);
        fb_error_msg := fnd_message.get_encoded;
        fnd_message.set_encoded(fb_error_msg);
        l_error_msg := fnd_message.get;
        wf_engine.setitemattrtext(p_itemtype,
                                  p_itemkey,
                                  'ERROR_MESSAGE',
                                  l_error_msg);
        x_resultout := 'COMPLETE:FAILURE';
      
        RETURN;
      
      END IF;
    
      wf_engine.setitemattrnumber(p_itemtype,
                                  p_itemkey,
                                  'GENERATED_CCID',
                                  to_number(l_cogs_ccid));
      x_resultout := 'COMPLETE:SUCCESS';
    
      oe_debug_pub.add('Input Paramerers : ');
      oe_debug_pub.add('Line id :' || to_char(p_line_id));
      oe_debug_pub.add('Organization id :' || to_char(p_organization_id));
      oe_debug_pub.add('Output : ');
      oe_debug_pub.add('Generated CCID :' || l_cogs_ccid);
    
      oe_debug_pub.add('Exiting from OE_Flex_COGS_Pub.Get_Cost_Sale_Item_Derived',
                       1);
    
      RETURN;
    ELSIF (p_funcmode = 'CANCEL') THEN
      x_resultout := wf_engine.eng_completed;
      RETURN;
    ELSE
      x_resultout := '';
      RETURN;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      fnd_message.set_name('ONT', 'OE_COGS_CCID_GEN_FAILED');
      fnd_message.set_token('PARAM1', 'Inventory Item id');
      fnd_message.set_token('PARAM2', '/Warehouse ');
      fnd_message.set_token('VALUE1', p_inventory_id);
      fnd_message.set_token('VALUE2', p_organization_id);
      fb_error_msg := fnd_message.get_encoded;
      fnd_message.set_encoded(fb_error_msg);
      l_error_msg := fnd_message.get;
      /*wf_engine.setitemattrtext(p_itemtype,
      p_itemkey,
      'ERROR_MESSAGE',
      l_error_msg);*/
      x_resultout := 'COMPLETE:FAILURE';
    
  END get_cogs_ccid;

  PROCEDURE get_cogs_ccid_for_shpflxwf(itemtype  IN VARCHAR2,
                                       itemkey   IN VARCHAR2,
                                       actid     IN NUMBER,
                                       funcmode  IN VARCHAR2,
                                       resultout OUT NOCOPY VARCHAR2) IS
  
    l_inventory_item_id NUMBER;
    l_organization_id   NUMBER;
    l_line_id           NUMBER;
    l_org_id            NUMBER;
  
  BEGIN
  
    l_inventory_item_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                       itemkey  => itemkey,
                                                       aname    => 'INV_ITEM_ID');
    l_organization_id   := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                       itemkey  => itemkey,
                                                       aname    => 'ORGANIZATION_ID');
    l_line_id           := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                       itemkey  => itemkey,
                                                       aname    => 'ORDER_LINE_ID');
    l_org_id            := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                       itemkey  => itemkey,
                                                       aname    => 'ORG_ID');
  
    get_cogs_ccid(p_itemtype        => itemtype,
                  p_itemkey         => itemkey,
                  p_actid           => actid,
                  p_funcmode        => funcmode,
                  p_line_id         => l_line_id,
                  p_inventory_id    => l_inventory_item_id,
                  p_organization_id => l_organization_id,
                  p_org_id          => l_org_id,
                  p_order_type_cogs => NULL,
                  x_resultout       => resultout);
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXCST_COGS_CUSTOM_WF_PKG',
                      'GET_COGS_CCID_FOR_SHPFLXWF',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode);
      RAISE;
    
  END get_cogs_ccid_for_shpflxwf;

  PROCEDURE get_cogs_ccid_for_invflxwf(itemtype  IN VARCHAR2,
                                       itemkey   IN VARCHAR2,
                                       actid     IN NUMBER,
                                       funcmode  IN VARCHAR2,
                                       resultout OUT NOCOPY VARCHAR2) IS
  
    l_inventory_item_id NUMBER;
    l_organization_id   NUMBER;
    l_line_id           NUMBER;
    l_order_header_id   NUMBER;
    l_org_id            NUMBER;
    l_default_cogs      NUMBER;
    l_order_type_cogs   NUMBER;
    l_organization_cogs NUMBER;
  
  BEGIN
  
    -- g_item_key  := itemtype;
    -- g_item_type := itemkey;
  
    l_inventory_item_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                       itemkey  => itemkey,
                                                       aname    => 'IC_ITEM_ID');
    l_line_id           := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                       itemkey  => itemkey,
                                                       aname    => 'IC_ORDER_LINE_ID');
  
    l_default_cogs := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                  itemkey  => itemkey,
                                                  aname    => 'IC_ORGANIZATION_COGS');
    --Hod:begin
    l_order_type_cogs := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                     itemkey  => itemkey,
                                                     aname    => 'IC_ORDER_TYPE_COGS');
  
    l_order_header_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                     itemkey  => itemkey,
                                                     aname    => 'IC_ORDER_HEADER_ID');
    l_org_id          := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                     itemkey  => itemkey,
                                                     aname    => 'IC_SELL_OPER_UNIT');
  
    --Hod:end
  
    IF l_line_id IS NULL THEN
    
      BEGIN
      
        SELECT ol.ship_from_org_id,
               mp.cost_of_sales_account,
               nvl(l_org_id, ol.org_id)
          INTO l_organization_id, l_organization_cogs, l_org_id
          FROM oe_order_lines_all ol, mtl_parameters mp
         WHERE ol.line_id =
               (SELECT MAX(oel.line_id)
                  FROM oe_order_lines_all oel
                 WHERE oel.header_id = l_order_header_id
                   AND oel.ordered_quantity > 0
                   AND nvl(oel.cancelled_flag, 'N') = 'N')
           AND ol.ship_from_org_id = mp.organization_id;
      
        get_cogs_ccid(p_itemtype        => itemtype,
                      p_itemkey         => itemkey,
                      p_actid           => actid,
                      p_funcmode        => funcmode,
                      p_line_id         => l_line_id,
                      p_inventory_id    => l_inventory_item_id,
                      p_organization_id => l_organization_id,
                      p_org_id          => l_org_id,
                      p_order_type_cogs => l_order_type_cogs,
                      x_resultout       => resultout);
      
      EXCEPTION
        WHEN no_data_found THEN
          resultout := 'COMPLETE:FAILURE';
          RETURN;
      END;
    
      RETURN;
    
    END IF;
  
    IF l_organization_id IS NULL THEN
      BEGIN
      
        SELECT ol.ship_from_org_id,
               mp.cost_of_sales_account,
               nvl(l_org_id, ol.org_id)
          INTO l_organization_id, l_organization_cogs, l_org_id
          FROM oe_order_lines_all ol, mtl_parameters mp
         WHERE line_id = l_line_id
           AND ol.ship_from_org_id = mp.organization_id;
      
        /*if l_default_cogs != l_organization_cogs then
          resultout := 'COMPLETE:FAILURE';
          RETURN;
        end if;*/ --Hods Remark
      
      EXCEPTION
        WHEN no_data_found THEN
          resultout := 'COMPLETE:FAILURE';
          RETURN;
      END;
    
    END IF;
  
    get_cogs_ccid(p_itemtype        => itemtype,
                  p_itemkey         => itemkey,
                  p_actid           => actid,
                  p_funcmode        => funcmode,
                  p_line_id         => l_line_id,
                  p_inventory_id    => l_inventory_item_id,
                  p_organization_id => l_organization_id,
                  p_org_id          => l_org_id,
                  p_order_type_cogs => l_order_type_cogs,
                  x_resultout       => resultout);
  
  EXCEPTION
    WHEN OTHERS THEN
      resultout := 'COMPLETE:FAILURE';
      RETURN;
    
  END get_cogs_ccid_for_invflxwf;

  PROCEDURE get_cogs_ccid_for_oecogs(itemtype  IN VARCHAR2,
                                     itemkey   IN VARCHAR2,
                                     actid     IN NUMBER,
                                     funcmode  IN VARCHAR2,
                                     resultout OUT NOCOPY VARCHAR2) IS
    l_inventory_item_id NUMBER;
    l_organization_id   NUMBER;
    l_line_id           NUMBER;
    l_org_id            NUMBER;
  BEGIN
  
    l_inventory_item_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                       itemkey  => itemkey,
                                                       aname    => 'INVENTORY_ITEM_ID');
    l_organization_id   := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                       itemkey  => itemkey,
                                                       aname    => 'ORGANIZATION_ID');
    l_line_id           := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                       itemkey  => itemkey,
                                                       aname    => 'LINE_ID');
    l_org_id            := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                       itemkey  => itemkey,
                                                       aname    => 'ORG_ID');
  
    get_cogs_ccid(p_itemtype        => itemtype,
                  p_itemkey         => itemkey,
                  p_actid           => actid,
                  p_funcmode        => funcmode,
                  p_line_id         => l_line_id,
                  p_inventory_id    => l_inventory_item_id,
                  p_organization_id => l_organization_id,
                  p_org_id          => l_org_id,
                  p_order_type_cogs => NULL,
                  x_resultout       => resultout);
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXCST_COGS_CUSTOM_WF_PKG',
                      'GET_COGS_CCID_FOR_OECOGS',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode);
      RAISE;
    
  END get_cogs_ccid_for_oecogs;

END xxcst_cogs_custom_wf_pkg;
/
