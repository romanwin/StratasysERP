CREATE OR REPLACE PACKAGE BODY xxoks_wf_util_pkg IS
  --------------------------------------------------------------------
  --  name:            XXOKS_WF_UTIL_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/12/2010 12:07:00
  --------------------------------------------------------------------
  --  purpose :        OKS WF Needs - Objet customizations
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/12/2010  Dalit A. Raviv    initial build
  --  1.1  02/01/2011  Dalit A. raviv    XXINITIALIZE - add system details to notification
  --  1.2  26.11.2019  yuval tal         CHG0045846 - add get_header_discount_info/ modify xxinitialize/ add get_line_discount_info
  --                                     Contract Manger, Aprroval notification is missing
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:          get_lines_discount
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   26.11.19
  --  cust:
  --------------------------------------------------------------------
  --  purpose :        Contract approval WF - initialize new attributes
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26.11.19    yuval tal         CHG0045846 - initial build
  ----------------------------------------------------------------------
  FUNCTION get_line_discount_info(p_contract_id NUMBER) RETURN VARCHAR2 IS
    l_info VARCHAR2(2000);
  BEGIN
  
    SELECT listagg(
                   --opa_l.operand  -- rem by Roman W. 24/08/2020 CHG0045846
                   trim(to_char(opa_l.operand, '99,999,999.99')) || ' ' ||
                   decode(opa_l.arithmetic_operator,
                          '%',
                          '%',
                          h.currency_code) || ' ' ||
                   decode(opa_l.change_reason_text, NULL, NULL, ' - ') ||
                   opa_l.change_reason_text,
                   ', ') within GROUP(ORDER BY 1)
      INTO l_info
      FROM okc_k_headers_all_b     h,
           okc_k_lines_b           l,
           oks_k_lines_b           subs,
           okc_k_lines_b           subl,
           okc_price_adjustments_v opa_l
     WHERE h.id = p_contract_id
       AND h.id = l.chr_id
       AND subs.cle_id = subl.id
       AND subl.cle_id = l.id
       AND subl.dnz_chr_id = h.id
       AND opa_l.cle_id(+) = subs.cle_id
       AND opa_l.operand IS NOT NULL;
  
    RETURN l_info;
  
  EXCEPTION
    WHEN no_data_found THEN
      NULL;
    
  END;

  --------------------------------------------------------------------
  --  name:          get_header_discount_info
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   26.11.19
  --  cust:
  --------------------------------------------------------------------
  --  purpose :        Contract approval WF - initialize new attributes
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26.11.19    yuval tal        CHG0045846 initial build
  --  1.1   18/08/2020  Roman W.         CHG0045846 added calculation currence code in case no discount in header level  
  ----------------------------------------------------------------------
  PROCEDURE get_header_discount_info(p_contract_id NUMBER,
                                     p_discount    OUT VARCHAR2,
                                     p_reason_text OUT VARCHAR2,
                                     p_curr_code   OUT VARCHAR2) IS
  
  BEGIN
  
    SELECT round(opa_h.operand, 2) || ' ' ||
           decode(opa_h.arithmetic_operator, '%', '%', h.currency_code) h_operand,
           h.currency_code,
           --opa_h.arithmetic_operator h_arithmetic_operator,
           -- opa_h.change_reason_code H_change_reason_code,
           opa_h.change_reason_text h_change_reason_text
      INTO p_discount, p_curr_code, p_reason_text
      FROM okc_k_headers_all_b h, okc_price_adjustments_v opa_h
     WHERE h.id = p_contract_id
       AND opa_h.chr_id = h.id
       AND opa_h.operand IS NOT NULL
       AND rownum = 1;
  
  EXCEPTION
    WHEN no_data_found THEN
    
      begin
        select okhab.currency_code
          into p_curr_code
          from okc_k_headers_all_b okhab
         where okhab.id = p_contract_id;
      exception
        when others then
          null;
      end;
  END get_header_discount_info;

  --------------------------------------------------------------------
  --  name:          get_list_price
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   26.11.19
  --  cust:
  --------------------------------------------------------------------
  --  purpose :        Contract approval WF - initialize new attributes
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26.11.19    yuval tal        CHG0045846 initial build
  ----------------------------------------------------------------------
  FUNCTION get_list_price(p_contract_id NUMBER) RETURN VARCHAR2 IS
    l_amount VARCHAR2(500);
  
  BEGIN
  
    SELECT to_char(SUM(nvl(subs.toplvl_operand_val, 0) *
                       nvl(subs.toplvl_quantity, 0)),
                   '99,999,999.99')
      INTO l_amount
      FROM okc_k_headers_all_b h,
           okc_k_lines_b       l,
           oks_k_lines_b       subs,
           okc_k_lines_b       subl
     WHERE h.id = p_contract_id
       AND h.id = l.chr_id
       AND subs.cle_id = subl.id
       AND subl.cle_id = l.id
       AND subl.dnz_chr_id = h.id;
  
    RETURN ltrim(l_amount);
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END;
  --------------------------------------------------------------------
  --  name:          get_adjustment_amount
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   26.11.19
  --  cust:
  --------------------------------------------------------------------
  --  purpose :        Contract approval WF - initialize new attributes
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26.11.19    yuval tal        CHG0045846 initial build
  ----------------------------------------------------------------------
  FUNCTION get_adjustment_amount(p_contract_id NUMBER) RETURN VARCHAR2 IS
    l_amount VARCHAR2(500);
  
  BEGIN
  
    SELECT to_char(-1 * (SUM(subs.toplvl_operand_val * subs.toplvl_quantity) -
                   SUM(subs.toplvl_adj_price * subs.toplvl_price_qty)),
                   '99,999,999.99')
      INTO l_amount
      FROM okc_k_headers_all_b h,
           okc_k_lines_b       l,
           oks_k_lines_b       subs,
           okc_k_lines_b       subl
     WHERE h.id = p_contract_id
       AND h.id = l.chr_id
       AND subs.cle_id = subl.id
       AND subl.cle_id = l.id
       AND subl.dnz_chr_id = h.id;
  
    RETURN ltrim(l_amount);
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    
  END;

  --------------------------------------------------------------------
  --  name:            XXINITIALIZE
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/12/2010
  --  cust:            CUSt368 - Modifications at Contract Approval work flow
  --                   add contract price information in the notification.
  --------------------------------------------------------------------
  --  purpose :        Contract approval WF - initialize new attributes
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/12/2010  Dalit A. Raviv    initial build
  --  1.1  02/01/2011  Dalit A. Raviv    add system details to notification
  --  1.2  15/04/2012  Dalit A. Raviv    add condition to the main cursor
  --  1.3  26.11.2019  yuval tal         CHG0045846 - set 3 more attributes
  --  1.4  18/08/2020  Roman W.          CHG0045846 - changed logic on XXADJ_DISCOUNT_AMT 
  --------------------------------------------------------------------
  PROCEDURE xxinitialize(itemtype  IN VARCHAR2,
                         itemkey   IN VARCHAR2,
                         actid     IN NUMBER,
                         funcmode  IN VARCHAR2,
                         resultout OUT NOCOPY VARCHAR2) IS
  
    l_id            NUMBER := NULL;
    l_price         VARCHAR2(200) := NULL;
    l_start_date    VARCHAR2(30) := NULL;
    l_end_date      VARCHAR2(30) := NULL;
    l_contract_type VARCHAR2(240) := NULL;
  
    -- Dalit A. Raviv 02/01/2011 add system details to notification
    l_system VARCHAR2(1500) := NULL;
  
    CURSOR grt_system_c(p_contract_id IN NUMBER) IS
      SELECT ('S/N: ' || cii.serial_number || '(' || msib.description || ')') system
        FROM okc_k_headers_all_b h,
             okc_k_lines_b       l1,
             okc_k_items         oki1,
             csi_item_instances  cii,
             mtl_system_items_b  msib
       WHERE l1.dnz_chr_id = h.id
         AND oki1.object1_id1 = cii.instance_id
         AND oki1.cle_id = l1.id
         AND cii.inventory_item_id = msib.inventory_item_id
         AND msib.organization_id = 91
         AND h.id = p_contract_id
            --     1.2  15/04/2012  Dalit A. Raviv
         AND l1.cle_id IS NOT NULL
         AND l1.lse_id IN (7, 8, 9, 10, 11, 18, 25, 35);
    --and    h.contract_number     = 'US200353WR'--'DE300413S'
  
  BEGIN
    --
    -- RUN mode - normal process execution
    --
    IF (funcmode = 'RUN') THEN
      -- get contract id
      l_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                          itemkey  => itemkey,
                                          aname    => 'CONTRACT_ID');
      -- get contract details
      SELECT trim(to_char(h.estimated_amount, '99,999,999.99')) || ' ' ||
             h.currency_code price, --CHG0045846
             to_char(l2.start_date, 'DD-MON-YYYY') start_date,
             to_char(l2.end_date, 'DD-MON-YYYY') end_date,
             msib.description contract_type
        INTO l_price, l_start_date, l_end_date, l_contract_type
        FROM okc_k_headers_all_b h,
             okc_k_lines_b       l2,
             okc_k_items         oki2,
             mtl_system_items_b  msib
       WHERE oki2.cle_id = l2.id
         AND l2.chr_id = h.id
         AND msib.inventory_item_id = oki2.object1_id1
         AND msib.organization_id = 91
         AND h.id = l_id --&contract_id
         AND rownum = 1;
    
      -- 1.1 Dalit A. Raviv 02/01/2011 add system details to notification
      FOR grt_system_r IN grt_system_c(l_id) LOOP
        IF l_system IS NULL THEN
          l_system := grt_system_r.system;
        ELSE
          l_system := l_system || ', ' || grt_system_r.system;
        END IF;
      END LOOP;
      -- end 1.1
    
      --CHG0045846
      DECLARE
        l_line_discount_info     VARCHAR2(2100);
        l_header_discount        VARCHAR2(200);
        l_header_discount_reason VARCHAR2(400);
        l_curr_code              VARCHAR2(5);
        l_list_price             VARCHAR2(50);
        l_adjustment_amount      VARCHAR2(50);
        ln_adjustment_amount     NUMBER;
      BEGIN
      
        get_header_discount_info(l_id,
                                 l_header_discount,
                                 l_header_discount_reason,
                                 l_curr_code);
      
        l_line_discount_info := get_line_discount_info(l_id);
      
        l_list_price        := get_list_price(l_id);
        l_adjustment_amount := get_adjustment_amount(l_id);
      
        begin
          ln_adjustment_amount := abs(to_number(l_adjustment_amount,
                                                '99,999,999.99'));
          l_adjustment_amount  := to_char(ln_adjustment_amount,
                                          '99,999,999.99');
        exception
          when others then
            null;
        end;
      
        wf_engine.setitemattrtext(itemtype => itemtype,
                                  itemkey  => itemkey,
                                  aname    => 'XXLINE_INFO',
                                  avalue   => l_line_discount_info);
      
        wf_engine.setitemattrtext(itemtype => itemtype,
                                  itemkey  => itemkey,
                                  aname    => 'XXHEADER_DISCOUNT_AMT',
                                  avalue   => l_header_discount);
      
        wf_engine.setitemattrtext(itemtype => itemtype,
                                  itemkey  => itemkey,
                                  aname    => 'XXHEADER_DISCOUNT_REASON',
                                  avalue   => l_header_discount_reason);
      
        wf_engine.setitemattrtext(itemtype => itemtype,
                                  itemkey  => itemkey,
                                  aname    => 'XXLIST_PRICE',
                                  avalue   => CASE l_list_price
                                                WHEN NULL THEN
                                                 NULL
                                                ELSE
                                                 l_list_price || ' ' ||
                                                 l_curr_code
                                              END);
      
        wf_engine.setitemattrtext(itemtype => itemtype,
                                  itemkey  => itemkey,
                                  aname    => 'XXADJ_DISCOUNT_AMT',
                                  avalue   => CASE l_adjustment_amount
                                                WHEN NULL THEN
                                                 NULL
                                                ELSE
                                                 l_adjustment_amount || ' ' ||
                                                 l_curr_code
                                              END);
      
      END;
    
      --CHG0045846 end
    
      -- set WF attributes with contract details
      wf_engine.setitemattrtext(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'XXPRICE',
                                avalue   => l_price);
      wf_engine.setitemattrtext(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'XXSTART_DATE',
                                avalue   => l_start_date);
      wf_engine.setitemattrtext(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'XXEND_DATE',
                                avalue   => l_end_date);
      wf_engine.setitemattrtext(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'XXCONTRACT_TYPE',
                                avalue   => l_contract_type);
      -- 1.1 Dalit A. Raviv 02/01/2011 add system details to notification
      wf_engine.setitemattrtext(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'XXSYSTEM',
                                avalue   => l_system);
    
      resultout := 'COMPLETE:';
      RETURN;
    END IF;
    --
    -- CANCEL mode
    --
    IF (funcmode = 'CANCEL') THEN
      resultout := 'COMPLETE:';
      RETURN;
    END IF;
    --
    -- TIMEOUT mode
    --
    IF (funcmode = 'TIMEOUT') THEN
      resultout := 'COMPLETE:';
      RETURN;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('OKC_WF_K_APPROVE',
                      'XXINITIALIZE',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode);
      RAISE;
  END xxinitialize;

/*PROCEDURE get_notification_body(document_id   IN VARCHAR2,
                                  display_type  IN VARCHAR2,
                                  document      IN OUT NOCOPY CLOB,
                                  document_type IN OUT NOCOPY VARCHAR2) IS
    l_contract_id NUMBER;
  BEGIN
    l_contract_id := to_number(document_id);

    document_type := 'text/html';
    document      := ' ';
    dbms_lob.append(document, 'XX');

  END;*/

END xxoks_wf_util_pkg;
/
