CREATE OR REPLACE PACKAGE BODY xxoe_order_wf_pkg IS

--------------------------------------------------------------------
--  name:            XXOE_ORDER_WF_PKG
--  create by:       yuval tal
--  Revision:        1.0
--  creation date:   29.7.12
--------------------------------------------------------------------
--  purpose :        
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  29.7.12     yuval tal         initial build
--                                     check_line_2close : add source 'SERVICE SFDC' CUST515 CR459
--  1.1  24.10.12    yuval tal         CR509: initiate_approval_wf :OBJ Order approval ? modify  AVG discount in notification header
--  1.2  5.2.2013    yuval tal         CR677 Apply Purchase Release Hold for Drop Shipped Lines
--  1.3  04/11/2014  Dalit A. Raviv    INC0025364 add handle for apps_initialize
--------------------------------------------------------------------
  
  -- 1.3 04/11/2014 Dalit A. Raviv INC0025364
  gn_app_id      number       := 0;
  gn_resp_id     number       := 0;
  gn_user_id     number       := 0;

  -------------------------------
  -- is_hold_exists
  -------------------------------
  FUNCTION is_hold_exists(p_line_id oe_order_lines_all.line_id%TYPE,
                          p_hold_id oe_hold_definitions.hold_id%TYPE DEFAULT NULL)
    RETURN BOOLEAN IS
  
    ln_order_hold_id oe_order_holds_all.order_hold_id%TYPE;
  
  BEGIN
  
    SELECT order_hold_id
      INTO ln_order_hold_id
      FROM oe_order_holds_all  ooh,
           oe_hold_sources_all hs,
           oe_hold_definitions ohd
     WHERE ooh.line_id = p_line_id
       AND ooh.hold_source_id = hs.hold_source_id
       AND hs.hold_id = nvl(p_hold_id, hs.hold_id)
       AND ohd.hold_id = hs.hold_id
       AND SYSDATE BETWEEN nvl(ohd.start_date_active, SYSDATE) AND
           nvl(ohd.end_date_active, SYSDATE)
       AND round(nvl(hs.hold_until_date, SYSDATE)) >= round(SYSDATE)
       AND ooh.hold_release_id IS NULL -- yuval 27.7.10
          -- hs.released_flag = 'N' AND -- yuval 27.7.10
       AND rownum < 2;
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN FALSE;
  END is_hold_exists;

  PROCEDURE create_auto_hold(p_line_id       NUMBER,
                             p_header_id     IN NUMBER,
                             p_hold_id       NUMBER,
                             p_user_id       NUMBER,
                             x_return_status IN OUT VARCHAR2,
                             x_err_msg       IN OUT VARCHAR2) IS
  
    l_hold_source_rec oe_holds_pvt.hold_source_rec_type;
    l_msg_count       VARCHAR2(200);
    l_msg_data        NUMBER;
    l_return_status   VARCHAR2(200);
    l_msg_index_out   NUMBER;
  BEGIN
  
    l_hold_source_rec.hold_id          := p_hold_id; -- Requested Hold
    l_hold_source_rec.hold_entity_code := 'O'; -- Line Hold
    l_hold_source_rec.hold_entity_id   := p_header_id; -- Order Header
    l_hold_source_rec.line_id          := p_line_id; -- Order Line
    l_hold_source_rec.hold_comment     := 'Automatic Hold';
    l_hold_source_rec.creation_date    := SYSDATE;
    l_hold_source_rec.created_by       := p_user_id;
    l_hold_source_rec.last_update_date := SYSDATE;
    l_hold_source_rec.last_updated_by  := p_user_id;
  
    oe_msg_pub.initialize;
  
    oe_holds_pub.apply_holds(p_api_version      => 1.0,
                             p_init_msg_list    => fnd_api.g_false,
                             p_commit           => fnd_api.g_false,
                             p_validation_level => fnd_api.g_valid_level_full,
                             p_hold_source_rec  => l_hold_source_rec,
                             x_msg_count        => l_msg_count,
                             x_msg_data         => l_msg_data,
                             x_return_status    => l_return_status);
  
    IF l_return_status != fnd_api.g_ret_sts_success THEN
      x_return_status := l_return_status;
    
      FOR i IN 1 .. l_msg_count LOOP
        oe_msg_pub.get(p_msg_index     => i,
                       p_encoded       => 'F',
                       p_data          => l_msg_data,
                       p_msg_index_out => l_msg_index_out);
      
        x_err_msg := x_err_msg || l_msg_data || chr(10);
        IF length(x_err_msg) > 500 THEN
          x_err_msg := substr(x_err_msg, 1, 500);
          EXIT;
        END IF;
      
      END LOOP;
    END IF;
  
  END create_auto_hold;

  --------------------------------------------------------------------
  --  name:            apply_line_hold
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   5.2.2013
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  5.2.2013    yuval tal         initial build
  --                                     CR677 : add decode (ol.source_type_code,'EXTERNAL',ffv.attribute10 , ffv.attribute2)
  --  1.1  04/11/2014  Dalit A. Raviv    INC0025364 add handle for apps_initialize
  --------------------------------------------------------------------
  PROCEDURE apply_line_hold(itemtype  IN VARCHAR2,
                            itemkey   IN VARCHAR2,
                            actid     IN NUMBER,
                            funcmode  IN VARCHAR2,
                            resultout IN OUT VARCHAR2) IS
  
    CURSOR csr_holds_mapping(p_line_id NUMBER) IS
      SELECT ol.header_id,
             ol.line_id,
             oh.attribute1,
             decode(ol.source_type_code, 'EXTERNAL', ffv.attribute10, ffv.attribute2) hold_type_id,
             ffv.attribute6        condition_type,
             ffv.attribute7        condition_value,
             ffv.attribute8        min_price2hold,
             ol.unit_list_price
        FROM oe_order_headers_all  oh,
             oe_order_lines_all    ol,
             fnd_flex_value_sets   fvs,
             fnd_flex_values       ffv      
       WHERE oh.header_id          = ol.header_id
         AND ol.flow_status_code   NOT IN ('CANCELLED', 'CLOSED')
         AND fvs.flex_value_set_id = ffv.flex_value_set_id
         AND fvs.flex_value_set_name = 'XXOE_TYPE_HOLDS_MAPPING'
         AND ffv.attribute1          = to_char(oh.order_type_id)
         AND ffv.enabled_flag        = 'Y'
         AND SYSDATE                 BETWEEN nvl(ffv.start_date_active, SYSDATE) AND nvl(ffv.end_date_active, SYSDATE)
         AND decode(ol.source_type_code, 'EXTERNAL', ffv.attribute10, ffv.attribute2) IS NOT NULL
         AND ol.line_id              = p_line_id;
  
    cur_hold         csr_holds_mapping%ROWTYPE;
    ln_user_id       NUMBER;
    ln_org_id        NUMBER := NULL;
    lv_return_status VARCHAR2(1);
    lv_err_msg       VARCHAR2(500);
    ln_header_id     NUMBER;
    ln_line_id       NUMBER;
    hold_error       EXCEPTION;
    l_check_hold_condition_flag VARCHAR2(1);
    -- 1.1 04/11/2014 Dalit A. Raviv INC0025364
    ln_app_id        number;
    ln_resp_id       number;
    --
  BEGIN
  
    -- Do nothing in cancel or timeout mode
    IF (funcmode <> wf_engine.eng_run) THEN
    
      resultout := wf_engine.eng_null;
      RETURN;
    
    END IF;
  
    lv_return_status := fnd_api.g_ret_sts_success;
    lv_err_msg       := NULL;
    ln_org_id        := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                    itemkey  => itemkey,
                                                    aname    => 'ORG_ID');
    ln_line_id       := to_number(itemkey);
  
    BEGIN
      SELECT header_id
        INTO ln_header_id
        FROM oe_order_lines_all ol
       WHERE line_id = ln_line_id;
    
    EXCEPTION
      WHEN no_data_found THEN
      
        resultout := wf_engine.eng_completed;
        RETURN;
    END;
  
    IF ln_org_id IS NULL THEN
      ln_org_id := mo_utils.get_default_org_id;
    END IF;
  
    mo_global.set_policy_context('S', ln_org_id);
    oe_globals.set_context();
  
    ln_user_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                              itemkey  => itemkey,
                                              aname    => 'USER_ID');
  
    -- 1.1 04/11/2014 Dalit A. Raviv INC0025364                                          
    ln_app_id  := wf_engine.getitemattrnumber(itemtype => itemtype,
                                              itemkey  => itemkey,
                                              aname    => 'APPLICATION_ID');
                                              
    ln_resp_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                              itemkey  => itemkey,
                                              aname    => 'RESPONSIBILITY_ID');

    if gn_app_id <> ln_app_id or gn_resp_id <> ln_resp_id or gn_user_id <> ln_user_id then
      gn_app_id  := ln_app_id;  
      gn_resp_id := ln_resp_id;
      gn_user_id := ln_user_id; 
      
      fnd_global.APPS_INITIALIZE(user_id =>ln_user_id ,resp_id =>ln_resp_id ,resp_appl_id => ln_app_id);
    end if;
    -- end INC0025364   
    
    FOR cur_hold IN csr_holds_mapping(ln_line_id) LOOP
    
      l_check_hold_condition_flag := check_hold_condition_flag(ln_line_id,
                                                               cur_hold.condition_type,
                                                               cur_hold.condition_value,
                                                               
                                                               nvl(cur_hold.min_price2hold,
                                                                   0),
                                                               cur_hold.unit_list_price);
    
      IF NOT is_hold_exists(cur_hold.line_id, cur_hold.hold_type_id) AND
         l_check_hold_condition_flag = 'Y' THEN
      
        create_auto_hold(p_line_id       => cur_hold.line_id,
                         p_header_id     => cur_hold.header_id,
                         p_hold_id       => cur_hold.hold_type_id,
                         p_user_id       => ln_user_id,
                         x_return_status => lv_return_status,
                         x_err_msg       => lv_err_msg);
      
      END IF;
    
    END LOOP;
  
    IF lv_return_status != fnd_api.g_ret_sts_success THEN
      RAISE hold_error;
    END IF;
  
    resultout := wf_engine.eng_completed;
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXOE_ORDER_WF_PKG',
                      'APPLY_LINE_HOLD',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      lv_err_msg,
                      'Return Status=' || lv_return_status,
                      SQLERRM);
      RAISE;
  END apply_line_hold;

  PROCEDURE check_line_hold(itemtype  IN VARCHAR2,
                            itemkey   IN VARCHAR2,
                            actid     IN NUMBER,
                            funcmode  IN VARCHAR2,
                            resultout IN OUT VARCHAR2) IS
  
  BEGIN
  
    IF (funcmode = 'RUN') THEN
    
      IF is_hold_exists(to_number(itemkey)) THEN
      
        resultout := wf_engine.eng_completed || ':' || 'Y';
      
      ELSE
      
        resultout := wf_engine.eng_completed || ':' || 'N';
      
      END IF;
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXOE_ORDER_WF_PKG',
                      'CHECK_LINE_HOLD',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      SQLERRM);
    
      RETURN;
    
  END;

  PROCEDURE include_role(p_role_name IN VARCHAR2) IS
    l_index        NUMBER := xxoe_order_wf_pkg.notiflist.count;
    l_search_index NUMBER;
    l_role_name    wf_roles.name%TYPE;
  BEGIN
    -- check to see if the role is already in the list
    l_role_name := p_role_name;
  
    IF l_index > 0 THEN
      FOR l_search_index IN xxoe_order_wf_pkg.notiflist.first .. xxoe_order_wf_pkg.notiflist.last LOOP
        IF l_role_name = xxoe_order_wf_pkg.notiflist(l_search_index).name THEN
          l_role_name := NULL;
          EXIT;
        END IF;
      END LOOP;
    END IF;
  
    IF l_role_name IS NOT NULL THEN
      -- add the role to the list
      xxoe_order_wf_pkg.notiflist(l_index + 1).name := l_role_name;
    END IF;
  
  END include_role;

  PROCEDURE set_notif_params(itemtype  IN VARCHAR2,
                             itemkey   IN VARCHAR2,
                             actid     IN NUMBER,
                             funcmode  IN VARCHAR2,
                             resultout IN OUT VARCHAR2) IS
  
    CURSOR csr_notif_release_roles(p_header_id NUMBER, p_approver VARCHAR2) IS
      SELECT alm.role
        FROM oe_order_headers_all     oh,
             oe_order_lines_all       ol,
             fnd_flex_value_sets      fvs,
             fnd_flex_values          ffv,
             oe_approver_list_members alm
       WHERE oh.header_id = ol.header_id
         AND ol.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
         AND fvs.flex_value_set_id = ffv.flex_value_set_id
         AND fvs.flex_value_set_name = 'XXOE_TYPE_HOLDS_MAPPING'
         AND ffv.attribute1 = to_char(oh.order_type_id)
         AND nvl(ffv.attribute4, fnd_api.g_miss_char) =
             to_char(alm.list_id)
         AND ffv.enabled_flag = 'Y'
         AND SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE) AND
             nvl(ffv.end_date_active, SYSDATE)
         AND oh.header_id = p_header_id
         AND ffv.attribute3 = p_approver
      UNION
      SELECT alm.role
        FROM oe_order_headers_all     oh,
             oe_order_lines_all       ol,
             fnd_flex_value_sets      fvs,
             fnd_flex_values          ffv,
             oe_approver_list_members alm
       WHERE oh.header_id = ol.header_id
         AND ol.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
         AND fvs.flex_value_set_id = ffv.flex_value_set_id
         AND fvs.flex_value_set_name = 'XXOE_TYPE_HOLDS_MAPPING'
         AND ffv.attribute1 = to_char(oh.order_type_id)
         AND nvl(ffv.attribute5, fnd_api.g_miss_char) =
             to_char(alm.list_id)
         AND
            /* + Additional Conditions */
             ffv.enabled_flag = 'Y'
         AND SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE) AND
             nvl(ffv.end_date_active, SYSDATE)
         AND oh.header_id = p_header_id
         AND ffv.attribute3 = p_approver;
  
    cur_notif_role csr_notif_release_roles%ROWTYPE;
    l_counter      NUMBER;
    ln_header_id   NUMBER;
    l_approver     VARCHAR2(100);
  
  BEGIN
  
    IF funcmode != 'RUN' THEN
      resultout := wf_engine.eng_null;
      RETURN;
    END IF;
  
    xxoe_order_wf_pkg.notiflist := g_miss_notiflist;
    ln_header_id                := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                               itemkey  => itemkey,
                                                               aname    => 'HEADER_ID');
  
    l_approver := wf_engine.getitemattrtext(itemtype => itemtype,
                                            itemkey  => itemkey,
                                            aname    => 'XXOE_APPROVER');
  
    FOR cur_notif_role IN csr_notif_release_roles(ln_header_id, l_approver) LOOP
    
      include_role(cur_notif_role.role);
    
    END LOOP;
  
    IF xxoe_order_wf_pkg.notiflist.count > 0 THEN
    
      wf_engine.setitemattrtext(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'XXOE_FYI_MSG_NAME',
                                avalue   => 'XXOE_REL_NOTIF_MSG');
    
      -------------------------------------------------------------------------
      -- Set the process counters
      -------------------------------------------------------------------------
      l_counter := xxoe_order_wf_pkg.notiflist.count;
    
      wf_engine.setitemattrnumber(itemtype => itemtype,
                                  itemkey  => itemkey,
                                  aname    => 'LIST_COUNTER',
                                  avalue   => 1);
    
      wf_engine.setitemattrnumber(itemtype => itemtype,
                                  itemkey  => itemkey,
                                  aname    => 'PERFORMER_LIMIT',
                                  avalue   => l_counter);
      resultout := 'COMPLETE:Y';
    ELSE
      resultout := 'COMPLETE:N';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXOE_ORDER_WF_PKG',
                      'SET_NOTIF_PARAMS',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      SQLERRM);
      RAISE;
    
  END set_notif_params;

  PROCEDURE set_notif_performer(itemtype  IN VARCHAR2,
                                itemkey   IN VARCHAR2,
                                actid     IN NUMBER,
                                funcmode  IN VARCHAR2,
                                resultout OUT NOCOPY VARCHAR2) IS
    l_counter BINARY_INTEGER;
    l_role    wf_roles.name%TYPE;
  BEGIN
    IF funcmode = 'RUN' THEN
      l_counter := wf_engine.getitemattrnumber(itemtype => itemtype,
                                               itemkey  => itemkey,
                                               aname    => 'LIST_COUNTER');
      l_role    := xxoe_order_wf_pkg.notiflist(l_counter).name;
    
      IF l_role IS NOT NULL THEN
        wf_engine.setitemattrtext(itemtype => itemtype,
                                  itemkey  => itemkey,
                                  aname    => 'XXOE_PERFORMER',
                                  avalue   => l_role);
      END IF;
    
      l_counter := l_counter + 1;
      wf_engine.setitemattrnumber(itemtype => itemtype,
                                  itemkey  => itemkey,
                                  aname    => 'LIST_COUNTER',
                                  avalue   => l_counter);
      resultout := 'COMPLETE';
      RETURN;
    END IF;
  
    IF funcmode = 'CANCEL' THEN
      resultout := 'COMPLETE';
      RETURN;
    END IF;
  
    IF funcmode = 'TIMEOUT' THEN
      resultout := 'COMPLETE';
      RETURN;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('xxoe_order_wf_pkg',
                      'Set_Notif_Performer',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode);
      RAISE;
  END set_notif_performer;

  FUNCTION get_devisor(p_devisor NUMBER) RETURN NUMBER IS
  
  BEGIN
  
    IF p_devisor IS NULL THEN
      RETURN 1;
    ELSIF p_devisor = 0 THEN
      RETURN 1;
    ELSE
      RETURN p_devisor;
    END IF;
  
  END get_devisor;

  PROCEDURE set_attributes(itemtype  IN VARCHAR2,
                           itemkey   IN VARCHAR2,
                           actid     IN NUMBER,
                           funcmode  IN VARCHAR2,
                           resultout IN OUT VARCHAR2) IS
  
    l_header_id     NUMBER;
    l_order_number  NUMBER;
    l_adj_price     NUMBER;
    l_currency_code VARCHAR2(3);
  
  BEGIN
    IF funcmode != 'RUN' THEN
      RETURN;
    END IF;
  
    SELECT header_id
      INTO l_header_id
      FROM oe_order_lines_all ol
     WHERE line_id = itemkey;
    --- yuval 5.8.10
    /*    SELECT order_number,
             h.transactional_curr_code,
             round((1 -
                   (SUM(l.unit_selling_price * l.ordered_quantity) /
                   get_devisor(SUM(l.unit_list_price * l.ordered_quantity)))) * 100,
                   2)
        INTO l_order_number, l_currency_code, l_adj_price
        FROM oe_order_headers_all h, oe_order_lines_all l
       WHERE h.header_id = l.header_id
         AND h.header_id = l_header_id
       GROUP BY order_number;
    */
    SELECT order_number,
           transactional_curr_code,
           decode(ott.attribute5, 'Y', 100, adj_price)
      INTO l_order_number, l_currency_code, l_adj_price
      FROM (SELECT order_number,
                   transactional_curr_code,
                   ooh.order_type_id,
                   to_char((1 -
                           SUM(l.unit_selling_price * l.ordered_quantity) /
                           xxoe_order_wf_pkg.get_devisor(SUM(l.unit_list_price *
                                                              l.ordered_quantity))) * 100,
                           xxgl_utils_pkg.safe_get_format_mask('USD', 30, 'Y')) adj_price
              FROM oe_order_lines_all l, oe_order_headers_all ooh
            
             WHERE l.header_id = ooh.header_id
               AND l.header_id = l_header_id
             GROUP BY ooh.order_number,
                      ooh.transactional_curr_code,
                      ooh.order_type_id) x,
           oe_transaction_types_all ott
     WHERE x.order_type_id = ott.transaction_type_id;
  
    -- yuval 5.8.2010
  
    wf_engine.setitemattrnumber(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'HEADER_ID',
                                avalue   => l_header_id);
  
    wf_engine.setitemattrnumber(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'ORDER_NUMBER',
                                avalue   => l_order_number);
  
    wf_engine.setitemattrnumber(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'ORDER_PRICE_ADJ',
                                avalue   => l_adj_price);
  
    wf_engine.setitemattrtext(itemtype => itemtype,
                              itemkey  => itemkey,
                              aname    => 'CURRENCY_CODE',
                              avalue   => l_currency_code);
  
    --  Add to the notification layout % of average discount.
    --Possible solution ? add to the notification subject (for example: Sales Order 100097 (10% avg. discount))
    --% = 1- (Sum of Line Selling Price)/(Sum of Line List Price)
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('xxoe_order_wf_pkg',
                      'set_attributes',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode);
      RAISE;
  END set_attributes;

  -------------------------------------------------
  -- release_holds
  -------------------------------------------------
  --   Date      Performer     Comments
  --   5.2.2013   yuval tal    cr 677 : add   decode (ol.source_type_code,'EXTERNAL',ffv.attribute10 , ffv.attribute2) 
  --                                    AND  to_char(hs.hold_id) in (ffv.attribute2 ,ffv.attribute10)

  PROCEDURE release_holds(itemtype  IN VARCHAR2,
                          itemkey   IN VARCHAR2,
                          actid     IN NUMBER,
                          funcmode  IN VARCHAR2,
                          resultout IN OUT VARCHAR2) IS
  
    CURSOR csr_holds_release(p_header_id NUMBER, p_approver VARCHAR2) IS
      SELECT ol.header_id,
             ol.line_id,
             decode(ol.source_type_code,
                    'EXTERNAL',
                    ffv.attribute10,
                    ffv.attribute2) hold_type_id
        FROM oe_order_headers_all oh,
             oe_order_lines_all   ol,
             oe_order_holds_all   holds,
             oe_hold_sources_all  hs,
             fnd_flex_value_sets  fvs,
             fnd_flex_values      ffv
       WHERE oh.header_id = ol.header_id
         AND ol.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
         AND fvs.flex_value_set_id = ffv.flex_value_set_id
         AND fvs.flex_value_set_name = 'XXOE_TYPE_HOLDS_MAPPING'
         AND ffv.attribute1 = to_char(oh.order_type_id)
         AND ffv.enabled_flag = 'Y'
         AND SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE) AND
             nvl(ffv.end_date_active, SYSDATE)
         AND oh.header_id = holds.header_id
         AND ol.line_id = holds.line_id
         AND to_char(hs.hold_id) IN (ffv.attribute2, ffv.attribute10)
         AND holds.hold_source_id = hs.hold_source_id
         AND hs.released_flag = 'N'
         AND holds.hold_release_id IS NULL
         AND oh.header_id = p_header_id
         AND (ffv.attribute3 = p_approver OR ffv.attribute9 = p_approver);
  
    cur_hold csr_holds_release%ROWTYPE;
    --ln_order_type_id   oe_transaction_types_all.transaction_type_id%TYPE;
    ln_user_id         NUMBER;
    ln_org_id          NUMBER := NULL;
    lv_return_status   VARCHAR2(1);
    lv_err_msg         VARCHAR2(500);
    ln_header_id       NUMBER;
    l_approver         VARCHAR2(100);
    l_hold_source_rec  oe_holds_pvt.hold_source_rec_type;
    l_hold_release_rec oe_holds_pvt.hold_release_rec_type;
    l_msg_count        VARCHAR2(200);
    l_msg_data         NUMBER;
    l_return_status    VARCHAR2(200);
    l_msg_index_out    NUMBER;
    l_err_msg          VARCHAR2(500);
    hold_error EXCEPTION;
    l_stage VARCHAR2(3);
  
  BEGIN
  
    -- Do nothing in cancel or timeout mode
    IF (funcmode <> wf_engine.eng_run) THEN
    
      resultout := wf_engine.eng_null;
      RETURN;
    
    END IF;
  
    l_stage   := '001';
    ln_org_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                             itemkey  => itemkey,
                                             aname    => 'ORG_ID');
    IF ln_org_id IS NULL THEN
      ln_org_id := mo_utils.get_default_org_id;
    END IF;
  
    mo_global.set_policy_context('S', ln_org_id);
    oe_globals.set_context();
  
    l_stage      := '002';
    ln_header_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                itemkey  => itemkey,
                                                aname    => 'HEADER_ID');
  
    l_approver := wf_engine.getitemattrtext(itemtype => itemtype,
                                            itemkey  => itemkey,
                                            aname    => 'XXOE_APPROVER');
  
    SELECT user_id
      INTO ln_user_id
      FROM fnd_user
     WHERE user_name = l_approver;
  
    l_stage := '003';
    FOR cur_hold IN csr_holds_release(ln_header_id, l_approver) LOOP
    
      l_stage                                := '004';
      l_hold_source_rec.hold_id              := cur_hold.hold_type_id; -- Requested Hold
      l_hold_source_rec.hold_entity_code     := 'O';
      l_hold_source_rec.hold_entity_id       := cur_hold.header_id;
      l_hold_source_rec.header_id            := cur_hold.header_id;
      l_hold_source_rec.line_id              := cur_hold.line_id;
      l_hold_source_rec.created_by           := ln_user_id;
      l_hold_source_rec.last_updated_by      := ln_user_id;
      l_hold_release_rec.created_by          := ln_user_id;
      l_hold_release_rec.last_updated_by     := ln_user_id;
      l_hold_release_rec.release_reason_code := fnd_profile.value('XXOE_ORDER_APPROVAL_RELEASE_REASON');
    
      l_stage := '005';
      oe_msg_pub.initialize;
    
      oe_holds_pub.release_holds(p_api_version      => 1.0,
                                 p_init_msg_list    => 'T',
                                 p_commit           => 'F',
                                 p_hold_source_rec  => l_hold_source_rec,
                                 p_hold_release_rec => l_hold_release_rec,
                                 x_msg_count        => l_msg_count,
                                 x_msg_data         => l_msg_data,
                                 x_return_status    => l_return_status);
    
      l_stage := '006';
    
      IF l_return_status != fnd_api.g_ret_sts_success THEN
        l_stage := '007';
      
        FOR i IN 1 .. l_msg_count LOOP
          oe_msg_pub.get(p_msg_index     => i,
                         p_encoded       => 'F',
                         p_data          => l_msg_data,
                         p_msg_index_out => l_msg_index_out);
        
          l_err_msg := l_err_msg || l_msg_data || chr(10);
          IF length(l_err_msg) > 500 THEN
            l_err_msg := substr(l_err_msg, 1, 500);
            EXIT;
          END IF;
        
        END LOOP;
        l_stage := '008';
      
      END IF;
    
    END LOOP;
  
    resultout := wf_engine.eng_completed;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      wf_core.context('XXOE_ORDER_WF_PKG',
                      'RELEASE_HOLDS',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      l_stage || ', ' || lv_err_msg,
                      'Return Status=' || lv_return_status,
                      SQLERRM);
      RAISE;
    
  END release_holds;
  -----------------------------------
  -- initiate_approval_wf
  --------------------------------------------------------------------------
  --   Date      Performer       Comments
  --   24.10.12   yuval tal     CR509: initiate_approval_wf :OBJ Order approval ? modify  AVG discount in notification header
  --   5.2.2013   yuval tal    cr 677 : add to cursor to_char(hs.hold_id) IN (ffv.attribute2, ffv.attribute10)

  ------------------------------------
  PROCEDURE initiate_approval_wf(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
    CURSOR csr_approval_orders(p_item_type VARCHAR2, p_wf_process VARCHAR2) IS
      SELECT DISTINCT oh.attribute1,
                      --    ffv.attribute2             hold_type_id,
                      ffv.attribute6             condition_type,
                      ffv.attribute7             condition_value,
                      ffv.attribute9             foc_approver,
                      oh.header_id,
                      oh.order_number,
                      oh.org_id,
                      oh.created_by,
                      ffv.attribute3,
                      oh.transactional_curr_code
        FROM oe_order_headers_all oh,
             oe_order_lines_all   ol,
             oe_order_holds_all   holds,
             oe_hold_sources_all  hs,
             fnd_flex_value_sets  fvs,
             fnd_flex_values      ffv
       WHERE oh.header_id = ol.header_id
         AND ol.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
         AND fvs.flex_value_set_id = ffv.flex_value_set_id
         AND fvs.flex_value_set_name = 'XXOE_TYPE_HOLDS_MAPPING'
         AND ffv.attribute1 = to_char(oh.order_type_id)
         AND ffv.enabled_flag = 'Y'
         AND SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE) AND
             nvl(ffv.end_date_active, SYSDATE)
         AND oh.header_id = holds.header_id
         AND ol.line_id = holds.line_id
         AND to_char(hs.hold_id) IN (ffv.attribute2, ffv.attribute10)
         AND holds.hold_source_id = hs.hold_source_id
         AND hs.released_flag = 'N'
         AND holds.hold_release_id IS NULL
         AND NOT EXISTS
       (SELECT 1
                FROM wf_items workflowitemeo
               WHERE workflowitemeo.item_type = p_item_type
                 AND workflowitemeo.item_key LIKE oh.header_id || ':%'
                 AND workflowitemeo.root_activity = p_wf_process
                 AND workflowitemeo.end_date IS NULL)
       ORDER BY oh.header_id;
  
    cur_order          csr_approval_orders%ROWTYPE;
    l_itemtype         wf_items.item_type%TYPE;
    l_itemkey          wf_items.item_key%TYPE;
    l_workflow_process wf_items.root_activity%TYPE;
    l_userkey          wf_items.user_key%TYPE;
    l_adj_price        VARCHAR2(30);
    l_from_user        fnd_user.user_name%TYPE;
    l_full_name        VARCHAR2(240) := NULL;
  
  BEGIN
  
    l_itemtype         := 'XXOEOHHA';
    l_workflow_process := 'XXOE_ORDER_APPROVAL_PROCESS';
  
    FOR cur_order IN csr_approval_orders(l_itemtype, l_workflow_process) LOOP
    
      SELECT cur_order.header_id || ':' ||
             xxobjt_oe_order_approval_s.nextval
        INTO l_itemkey
        FROM dual;
    
      fnd_global.apps_initialize(user_id      => cur_order.created_by,
                                 resp_id      => fnd_global.resp_id,
                                 resp_appl_id => fnd_global.resp_appl_id);
    
      SELECT user_name
        INTO l_from_user
        FROM fnd_user
       WHERE user_id = cur_order.created_by;
    
      l_userkey := cur_order.order_number;
    
      wf_engine.createprocess(itemtype => l_itemtype,
                              itemkey  => l_itemkey,
                              process  => l_workflow_process);
    
      wf_engine.setitemuserkey(itemtype => l_itemtype,
                               itemkey  => l_itemkey,
                               userkey  => l_userkey);
    
      wf_engine.setitemattrnumber(itemtype => l_itemtype,
                                  itemkey  => l_itemkey,
                                  aname    => 'HEADER_ID',
                                  avalue   => cur_order.header_id);
      --
      wf_engine.setitemattrnumber(itemtype => l_itemtype,
                                  itemkey  => l_itemkey,
                                  aname    => 'ORG_ID',
                                  avalue   => cur_order.org_id);
    
      wf_engine.setitemattrnumber(itemtype => l_itemtype,
                                  itemkey  => l_itemkey,
                                  aname    => 'USER_ID',
                                  avalue   => cur_order.created_by);
    
      wf_engine.setitemattrtext(itemtype => l_itemtype,
                                itemkey  => l_itemkey,
                                aname    => 'FROM_USER',
                                avalue   => l_from_user);
    
      wf_engine.setitemattrnumber(itemtype => l_itemtype,
                                  itemkey  => l_itemkey,
                                  aname    => 'ORDER_NUMBER',
                                  avalue   => cur_order.order_number);
    
      -- 24.10.12 yuval tal CR 509
      SELECT decode(ott.attribute5, 'Y', 100, x.attribute17)
        INTO l_adj_price
        FROM oe_order_headers_all x, oe_transaction_types_all ott
       WHERE x.order_type_id = ott.transaction_type_id
         AND x.header_id = cur_order.header_id;
    
      -- end 24.10.12  yuval tal CR 509
    
      wf_engine.setitemattrtext(itemtype => l_itemtype,
                                itemkey  => l_itemkey,
                                aname    => 'XXOE_PRICE_ADJ',
                                avalue   => l_adj_price);
    
      wf_engine.setitemattrtext(itemtype => l_itemtype,
                                itemkey  => l_itemkey,
                                aname    => 'CURRENCY_CODE',
                                avalue   => cur_order.transactional_curr_code);
    
      -- cust 289 -- change approver for FOC
    
      IF cur_order.condition_type = 'FOC Reason' AND
         cur_order.attribute1 = cur_order.condition_value AND
         cur_order.foc_approver IS NOT NULL THEN
      
        -- change approver
        wf_engine.setitemattrtext(itemtype => l_itemtype,
                                  itemkey  => l_itemkey,
                                  aname    => 'XXOE_APPROVER',
                                  avalue   => cur_order.foc_approver);
      ELSE
      
        wf_engine.setitemattrtext(itemtype => l_itemtype,
                                  itemkey  => l_itemkey,
                                  aname    => 'XXOE_APPROVER',
                                  avalue   => cur_order.attribute3);
      
      END IF;
      --
    
      -- Dalit A. Raviv 10/01/2010 add item attribute od created by full name
      BEGIN
        SELECT pap.full_name
          INTO l_full_name
          FROM fnd_user fu, per_all_people_f pap
         WHERE fu.employee_id = pap.person_id
           AND fu.user_id = cur_order.created_by
           AND SYSDATE BETWEEN pap.effective_start_date AND
               pap.effective_end_date
           AND pap.current_employee_flag = 'Y';
      EXCEPTION
        WHEN too_many_rows THEN
          SELECT pap.full_name
            INTO l_full_name
            FROM fnd_user fu, per_all_people_f pap
           WHERE fu.employee_id = pap.person_id
             AND fu.user_id = cur_order.created_by
             AND SYSDATE BETWEEN pap.effective_start_date AND
                 pap.effective_end_date
             AND rownum = 1;
        WHEN OTHERS THEN
          l_full_name := NULL;
      END;
    
      BEGIN
        wf_engine.setitemattrtext(itemtype => l_itemtype,
                                  itemkey  => l_itemkey,
                                  aname    => 'XXOE_CREATOR',
                                  avalue   => l_full_name);
      
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      -- end Dalit A. Raviv 10/01/2010
    
      wf_engine.startprocess(itemtype => l_itemtype, itemkey => l_itemkey);
    
      fnd_file.put_line(fnd_file.log,
                        'Order ' || cur_order.order_number ||
                        ' was sent for approval with item type: ' ||
                        l_itemtype || ' and item key: ' || l_itemkey);
    
    END LOOP;
  
    wf_engine.background;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Procedure initiate_approval_wf Failed -' || SQLERRM;
      retcode := 0;
  END initiate_approval_wf;

  --------------------------------------------------------
  -- check_line_2close
  -- RanS 24/12/09
  -- Description: Check if an SO line meets the conditions
  --              for being closed without being pushed to
  --              the interface.
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.0  29.7.12   yuval tal          add source 'SERVICE SFDC' CUST 515 cr CR459

  --------------------------------------------------------
  PROCEDURE check_line_2close(itemtype  IN VARCHAR2,
                              itemkey   IN VARCHAR2,
                              actid     IN NUMBER,
                              funcmode  IN VARCHAR2,
                              resultout IN OUT VARCHAR2) IS
  
    v_price           NUMBER;
    v_attr            VARCHAR2(10);
    v_source_id       NUMBER;
    l_order_source_id NUMBER;
  BEGIN
  
    IF (funcmode = 'RUN') THEN
    
      -- CUST 515 CR CR459
      BEGIN
      
        SELECT t.order_source_id
          INTO l_order_source_id
          FROM oe_order_sources t
         WHERE t.name = 'SERVICE SFDC';
      EXCEPTION
        WHEN OTHERS THEN
        
          NULL;
      END;
      ---------------
      SELECT oola.unit_selling_price,
             nvl(otta.attribute7, 'N'),
             ooha.order_source_id
        INTO v_price, v_attr, v_source_id
        FROM oe_order_lines_all       oola,
             oe_order_headers_all     ooha,
             oe_transaction_types_all otta
       WHERE ooha.header_id = oola.header_id
         AND otta.transaction_type_id = ooha.order_type_id
            --and ooha.order_source_id = 7  -- Service Billing (seeded)
         AND line_id = to_number(itemkey); --1021;
    
      IF v_price = 0 AND v_attr = 'Y' AND
         nvl(v_source_id, 0) IN (nvl(l_order_source_id, 0), 7) THEN
        -- cust 515/cr 459
        -- 7 is: Service Billing (seeded)
      
        resultout := wf_engine.eng_completed || ':' || 'Y';
      
      ELSE
      
        resultout := wf_engine.eng_completed || ':' || 'N';
      
      END IF;
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXOE_ORDER_WF_PKG',
                      'CHECK_LINE_2CLOSE',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      SQLERRM);
    
      RETURN;
    
  END check_line_2close;

  ------------------------------------------------
  -- check_hold_condition_flag
  ------------------------------------------------
  -- check conditional param according to oreder type
  -- in value set XXOE_TYPE_HOLDS_MAPPING att6 and att7 condition type and condition value
  --
  -- if no condition is set return Y
  -- if condition exists return Y else N
  -- 3.11.11  movr min price list check under manual discount check
  ------------------------------------------------
  FUNCTION check_hold_condition_flag(p_line_id         NUMBER,
                                     p_condition_type  VARCHAR2,
                                     p_condition_value VARCHAR2,
                                     p_min_price2hold  NUMBER,
                                     p_unit_list_price NUMBER)
    RETURN VARCHAR2 IS
    l_man_adj NUMBER;
    CURSOR c IS
      SELECT * FROM oe_order_lines_all t WHERE t.line_id = p_line_id;
  BEGIN
    FOR i IN c LOOP
    
      CASE nvl(p_condition_type, '-1')
        WHEN 'Manual Discount' THEN
          IF nvl(p_min_price2hold, 0) < p_unit_list_price THEN
            l_man_adj := get_total_adj(p_line_id, 'Manual Adjustment');
          
            IF (i.unit_selling_price = 0 AND l_man_adj = 0) OR
               l_man_adj > 0 THEN
              RETURN 'N';
            ELSIF abs(l_man_adj) / (i.unit_selling_price + abs(l_man_adj)) >=
                  p_condition_value / 100 THEN
              RETURN 'Y';
            ELSE
              RETURN 'N';
            END IF;
          ELSE
            RETURN 'N';
          END IF;
        
        ELSE
          RETURN 'Y';
      END CASE;
    
      RETURN 'Y';
    
    END LOOP;
  
  END;

  --------------------------------
  -- get_total_adj
  -------------------------------

  FUNCTION get_total_adj(p_line_id NUMBER, p_adj_type VARCHAR2) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
    SELECT SUM(t.adjusted_amount)
      INTO l_tmp
      FROM oe_price_adjustments_v t
     WHERE t.line_id = p_line_id
       AND t.adjustment_name = p_adj_type;
    RETURN nvl(l_tmp, 0);
  
  END;
  -----------------------------------------------------
  -- check_Freight_reaprove_mode
  --
  -- check if  freight item is only item in hold
  -- if yes  hold approval can be ignore auto release should be done
  --
  --   Date      Performer     Comments
  ------------------------------------------------------
  --   5.2.2013   yuval tal    cr 677 : add  to cursor c_obj_hold :  to_char(hs.hold_id) in (ffv.attribute2 ,ffv.attribute10)
  -------------------------------------
  PROCEDURE check_approval_needed(itemtype  IN VARCHAR2,
                                  itemkey   IN VARCHAR2,
                                  actid     IN NUMBER,
                                  funcmode  IN VARCHAR2,
                                  resultout IN OUT VARCHAR2) IS
    l_header_id  NUMBER;
    l_fr_item_id NUMBER := fnd_profile.value('XXAR_FREIGHT_ITEM_ID');
    CURSOR c_obj_hold IS
      SELECT SUM(decode(l.inventory_item_id, l_fr_item_id, 1, 0)) fr_items_count,
             SUM(decode(l.inventory_item_id, l_fr_item_id, 0, 1)) other_items_count
        FROM oe_order_headers_all oha,
             oe_order_lines_all   l,
             oe_order_holds_all   oh,
             oe_hold_sources_all  hs,
             oe_hold_releases     hr,
             oe_hold_definitions  hd,
             fnd_user             fu,
             fnd_flex_value_sets  fvs,
             fnd_flex_values      ffv
      
       WHERE oha.header_id = l.header_id
         AND l.line_id = oh.line_id
         AND l.header_id = oh.header_id
         AND oh.hold_source_id = hs.hold_source_id
         AND hs.hold_id = hd.hold_id
         AND hs.created_by = fu.user_id
         AND oh.hold_release_id = hr.hold_release_id(+)
         AND hs.org_id = oh.org_id
         AND fvs.flex_value_set_id = ffv.flex_value_set_id
         AND fvs.flex_value_set_name = 'XXOE_TYPE_HOLDS_MAPPING'
         AND ffv.attribute1 = to_char(oha.order_type_id)
         AND ffv.enabled_flag = 'Y'
         AND SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE) AND
             nvl(ffv.end_date_active, SYSDATE)
         AND to_char(hs.hold_id) IN (ffv.attribute2, ffv.attribute10)
         AND oh.header_id = l_header_id
         AND hs.released_flag = 'N';
  
    l_approval_required VARCHAR2(1);
  
  BEGIN
    l_header_id         := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                       itemkey  => itemkey,
                                                       aname    => 'HEADER_ID');
    l_approval_required := 'Y';
  
    FOR i IN c_obj_hold LOOP
    
      IF nvl(i.fr_items_count, 0) > 0 AND nvl(i.other_items_count, 0) = 0 THEN
        l_approval_required := 'N';
      END IF;
    
    END LOOP;
  
    resultout := 'COMPLETE:' || l_approval_required;
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('xxoe_order_wf_pkg',
                      'check_approval_needed',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode);
      RAISE;
  END;

END xxoe_order_wf_pkg;
/
