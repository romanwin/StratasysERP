CREATE OR REPLACE PACKAGE BODY xxpo_wf_notification_pkg AS
  /* $Header: POXWPA6B.pls 115.43 2002/09/06 23:19:26 jizhang noship $ */

  --------------------------------------------------------------------
  --  customization code: CUST004 -
  --  name:               Purchasing Approval Notification
  --  create by:          Ella Malchi
  --  $Revision:          1.2 $
  --  creation date:      xx/xx/2009
  --------------------------------------------------------------------
  --  process:
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   xx/xx/2009    Ella Malchi     initial build
  --  1.1   17/01/2010    Dalit A. Raviv  add logic changes
  --                                      show account data from the budget summary account
  --  1.2   24/01/2010    Dalit A. Raviv  get hard coded values from ledger, period
  --  1.3   8.8.2010      yuval tal       ADD po_change_api1_s.validate_acceptance
  --  1.4   2.2.11        yuval tal       fix bug in get_req_distributions : replace hard coded budget version id with dyn select
  --  1.5   12.12.11      yuval tal       set_startup_values : fix bug in release selects
  --  1.6   26.3.12       yuval tal       record_acceptance : support blanket and releases
  --  1.7   17.4.12       yuval tal       update_orig_dates_autonomous : support releases
  --  1.8   24.5.12       yuval tal       bugfix   record_acceptance : support blanket and releases
  --  1.9   15.11.12      yuval tal       modify function get_expense_type : CUST349 CR516
  --  2.0   28.11.12      yuval tal       CR606 add procedure : is_po_approval_needed Skip Approval in case of PO for Stratasys created by a drop shipped Sales order containing eligible products
  --  2.1   23.12.12      yuval tal       CR606 bugfix for cr606
  --  2.2   10.6.13       yuval tal       set_startup_values :Cust004- bugfix 821 add parameter  p_release_num
  --  2.3   31.7.13       Vitaly          CUST695 CR 932 modify is_po_approval_needed
  --  2.4   12.8.13       yuval tal       CUST695 CR 932 add is_po_approval_needed_std_cost
  --  2.5   28.5.14       yuval tal       CHG0032328 get_req_distributions : chnage application id from 202 to 101
  --  2.6   02.06.14      sanjai misra    CHG0031872 Modified following procedure so that for US OU, notification is sent for
  --                                      all changes to PO. For other OU, notification will be send only if need by date is changed.
  --                                      Procedure : set_attr_email_doc
  --  2.7   05.06.14      sandeep akula   Added Procedures is_po_created_from_requisition, set_preparer_username_attr,
  --                                      check_ou_in_prparernotf_lookup, check_ou_in_poapprv_ou_lookup, is_revision_greater_than_zero (CHG0031722)
  --  2.8   29.07.2014    sandeep akula   Added GROUP BY Clause to eliminate duplicates (CHG0032834)
  --  2.9   11/03/2015    Dalit A. Raviv  CHG0032552 procedure set_startup_values add RFR PO to warehouse
  --  3.0   08/07/2015    Michal Tzvik    CHG0035632 - Accelerating 0$ POs approval process: modify procedure is_po_approval_needed
  -- 3.1   09.12.15    yuval tal         CHG0037199 change  set_startup_values  
  --------------------------------------------------------------------

  -- Modified by Yariv Matia on 28/5/2003 - added ac_budget_table
  g_budget_amount      NUMBER := 0;
  g_encumbrance_amount NUMBER := 0;
  g_actual_amount      NUMBER := 0;
  g_funds_avail_amount NUMBER := 0;
  g_commitment_amount  NUMBER := 0;
  g_obligation_amount  NUMBER := 0;
  g_other_amount       NUMBER := 0;

  --------------------------------------------------------------------
  --  name:            get_req_distributions
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  FUNCTION get_req_distributions(p_set_of_books_id   NUMBER, -- l_sob_id
		         p_budget_account_id NUMBER, -- l_code_comb_id
		         p_gl_period_name    VARCHAR2) RETURN NUMBER IS
  
    CURSOR get_summary_budget_ccid_c IS
      SELECT h.summary_code_combination_id s_budget_account_id,
	 k.amount_type,
	 h.template_id,
	 funding_budget_version_id
      FROM   gl_account_hierarchies h,
	 gl_summary_bc_options  k
      WHERE  h.detail_code_combination_id = p_budget_account_id
      AND    k.template_id = h.template_id
      AND    h.ledger_id = p_set_of_books_id;
  
    CURSOR c_get_period_info(cp_ledger_id   NUMBER,
		     cp_period_name VARCHAR2) IS
      SELECT period_num,
	 quarter_num,
	 period_year,
	 closing_status
      FROM   gl_period_statuses
      WHERE  application_id = 101
      AND    ledger_id = cp_ledger_id
      AND    period_name = cp_period_name;
  
    CURSOR c_get_ledger_info(cp_ledger_id NUMBER) IS
      SELECT period_set_name,
	 accounted_period_type,
	 currency_code
      FROM   gl_ledgers
      WHERE  ledger_id = cp_ledger_id;
  
    CURSOR c_get_budget_ver IS
      SELECT x.budget_version_id
      FROM   gl_budgets_v x
      WHERE  x.status = 'C'
      AND    SYSDATE BETWEEN x.start_date AND x.end_date
      AND    x.ledger_id = p_set_of_books_id;
  
    l_period_set_name       gl_ledgers.period_set_name%TYPE;
    l_accounted_period_type gl_ledgers.accounted_period_type%TYPE;
    l_period_year           gl_periods.period_year%TYPE;
    l_period_num            gl_periods.period_num%TYPE;
    l_quarter_num           gl_periods.quarter_num%TYPE;
    l_amt_type              VARCHAR2(10) := NULL;
    l_amount_type           VARCHAR2(10) := NULL;
  
    l_currency_code      gl_ledgers.currency_code%TYPE;
    l_closing_status     VARCHAR2(1);
    l_budget_amount      NUMBER := 0;
    l_encumbrance_amount NUMBER := 0;
    l_actual_amount      NUMBER := 0;
    l_funds_avail_amount NUMBER := 0;
    l_commitment_amount  NUMBER := 0;
    l_obligation_amount  NUMBER := 0;
    l_other_amount       NUMBER := 0;
    l_sign               VARCHAR2(1) := 'N';
    l_count              NUMBER := 0;
  
    l_gl_period_name    VARCHAR2(15) := NULL;
    l_budget_version_id gl_budgets_v.budget_version_id%TYPE;
  BEGIN
  
    g_budget_amount      := NULL;
    g_encumbrance_amount := NULL;
    g_actual_amount      := NULL;
    g_funds_avail_amount := NULL;
    g_commitment_amount  := NULL;
    g_obligation_amount  := NULL;
    g_other_amount       := NULL;
  
    OPEN c_get_ledger_info(p_set_of_books_id);
    FETCH c_get_ledger_info
      INTO l_period_set_name,
           l_accounted_period_type,
           l_currency_code;
    CLOSE c_get_ledger_info;
  
    -- yuval  2.2.11
    OPEN c_get_budget_ver;
    FETCH c_get_budget_ver
      INTO l_budget_version_id;
    CLOSE c_get_budget_ver;
  
    -- end yuval 2.2.11
  
    -- Dalit A. Raviv 13/01/2010
    -- need to changed to the summary budget_account_id
    -- we can have several summary ccid for ccid, and several budget summary ccid
    -- thats why i check the founds return to be the lowest amount.
    FOR get_summary_budget_ccid_r IN get_summary_budget_ccid_c LOOP
      -- check if there is a summary at all
      l_sign := 'Y';
      --  count cursor rows
      l_count    := l_count + 1;
      l_amt_type := get_summary_budget_ccid_r.amount_type;
      -- the value from gl_summary_bc_options is YTD/ QTD - these values are not good the API return with ziro's
      -- there is no set up that connect the 2 values that why i do it hard code.
      IF l_amt_type = 'YTD' THEN
        l_gl_period_name := 'DEC' || substr(p_gl_period_name, 4);
      ELSIF l_amt_type = 'QTD' THEN
        l_gl_period_name := get_last_mon_in_period(p_gl_period_name);
      ELSE
        l_gl_period_name := p_gl_period_name;
      END IF;
    
      -- get periods values by the new period name
      OPEN c_get_period_info(p_set_of_books_id, l_gl_period_name);
      FETCH c_get_period_info
        INTO l_period_num,
	 l_quarter_num,
	 l_period_year,
	 l_closing_status;
      CLOSE c_get_period_info;
    
      SELECT decode(l_amt_type, 'YTD', 'YTDE', 'QTD', 'QTDE', l_amount_type)
      INTO   l_amount_type
      FROM   dual;
      dbms_output.put_line('l_gl_period_name' || l_gl_period_name ||
		   ' l_amt_type = ' || l_amt_type ||
		   ' l_amount_type =' || l_amount_type ||
		   ' l_currency_code=' || l_currency_code);
      dbms_output.put_line('get_summary_budget_ccid_r.s_budget_account_id= ' ||
		   get_summary_budget_ccid_r.s_budget_account_id || ' ' ||
		   l_accounted_period_type);
    
      gl_funds_available_pkg.calc_funds(x_amount_type              => l_amount_type,
			    x_code_combination_id      => get_summary_budget_ccid_r.s_budget_account_id,
			    x_account_type             => 'E',
			    x_template_id              => get_summary_budget_ccid_r.template_id /*NULL*/,
			    x_ledger_id                => p_set_of_books_id,
			    x_currency_code            => l_currency_code,
			    x_po_install_flag          => 'Y',
			    x_accounted_period_type    => l_accounted_period_type,
			    x_period_set_name          => l_period_set_name, --'OBJET_CALENDAR',
			    x_period_name              => l_gl_period_name /*p_gl_period_name*/,
			    x_period_num               => l_period_num,
			    x_quarter_num              => l_quarter_num,
			    x_period_year              => l_period_year,
			    x_closing_status           => l_closing_status,
			    x_budget_version_id        => l_budget_version_id, --6002 /*1000*/,
			    x_encumbrance_type_id      => -1,
			    x_req_encumbrance_id       => 1000,
			    x_po_encumbrance_id        => 1001,
			    x_budget                   => l_budget_amount,
			    x_encumbrance              => l_encumbrance_amount,
			    x_actual                   => l_actual_amount,
			    x_funds_available          => l_funds_avail_amount,
			    x_req_encumbrance_amount   => l_commitment_amount,
			    x_po_encumbrance_amount    => l_obligation_amount,
			    x_other_encumbrance_amount => l_other_amount);
    
      -- if i'm in the first row at loop
      -- enter values to globals
      IF l_count = 1 THEN
        g_budget_amount      := l_budget_amount;
        g_encumbrance_amount := l_encumbrance_amount;
        g_actual_amount      := l_actual_amount;
        g_funds_avail_amount := l_funds_avail_amount;
        g_obligation_amount  := l_obligation_amount;
        g_commitment_amount  := l_commitment_amount;
        g_other_amount       := l_other_amount;
      ELSE
        -- check if the second summary ccid has lower funds_avail_amount
        -- if yes the new lower values will be the return values
        IF l_funds_avail_amount < g_funds_avail_amount THEN
          g_budget_amount      := l_budget_amount;
          g_encumbrance_amount := l_encumbrance_amount;
          g_actual_amount      := l_actual_amount;
          g_funds_avail_amount := l_funds_avail_amount;
          g_obligation_amount  := l_obligation_amount;
          g_commitment_amount  := l_commitment_amount;
          g_other_amount       := l_other_amount;
        END IF;
      END IF;
    
      dbms_output.put_line('g_budget_amount = ' || g_budget_amount);
      dbms_output.put_line('g_encumbrance_amount = ' ||
		   g_encumbrance_amount);
      dbms_output.put_line('g_actual_amount = ' || g_actual_amount);
      dbms_output.put_line('g_funds_avail_amount = ' ||
		   g_funds_avail_amount);
      dbms_output.put_line('g_commitment_amount = ' || g_commitment_amount);
    
    END LOOP;
  
    IF l_sign = 'N' THEN
      l_gl_period_name := 'DEC' || substr(p_gl_period_name, 4);
      -- get periods values by the new period name
      -- get periods values by the new period name
      OPEN c_get_period_info(p_set_of_books_id, l_gl_period_name);
      FETCH c_get_period_info
        INTO l_period_num,
	 l_quarter_num,
	 l_period_year,
	 l_closing_status;
      CLOSE c_get_period_info;
    
      SELECT decode(l_amt_type, 'YTD', 'YTDE', 'QTD', 'QTDE', l_amount_type)
      INTO   l_amount_type
      FROM   dual;
    
      gl_funds_available_pkg.calc_funds(x_amount_type              => 'YTDE',
			    x_code_combination_id      => p_budget_account_id,
			    x_account_type             => 'E',
			    x_template_id              => NULL,
			    x_ledger_id                => p_set_of_books_id,
			    x_currency_code            => l_currency_code,
			    x_po_install_flag          => 'Y',
			    x_accounted_period_type    => l_accounted_period_type,
			    x_period_set_name          => l_period_set_name, --'OBJET_CALENDAR',
			    x_period_name              => l_gl_period_name /*p_gl_period_name*/,
			    x_period_num               => l_period_num,
			    x_quarter_num              => l_quarter_num,
			    x_period_year              => l_period_year,
			    x_closing_status           => l_closing_status,
			    x_budget_version_id        => l_budget_version_id, --1000,
			    x_encumbrance_type_id      => -1,
			    x_req_encumbrance_id       => 1000,
			    x_po_encumbrance_id        => 1001,
			    x_budget                   => g_budget_amount,
			    x_encumbrance              => g_encumbrance_amount,
			    x_actual                   => g_actual_amount,
			    x_funds_available          => g_funds_avail_amount,
			    x_req_encumbrance_amount   => g_obligation_amount,
			    x_po_encumbrance_amount    => g_commitment_amount,
			    x_other_encumbrance_amount => g_other_amount);
      dbms_output.put_line('------ ');
      dbms_output.put_line('l_amt_type = ' || l_amt_type);
      dbms_output.put_line('g_budget_amount = ' || g_budget_amount);
      dbms_output.put_line('g_encumbrance_amount = ' ||
		   g_encumbrance_amount);
      dbms_output.put_line('g_actual_amount = ' || g_actual_amount);
      dbms_output.put_line('g_funds_avail_amount = ' ||
		   g_funds_avail_amount);
      dbms_output.put_line('g_commitment_amount = ' || g_commitment_amount);
    END IF;
  
    RETURN 0;
    -- end 13/01/2010
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_req_distributions;

  --------------------------------------------------------------------
  --  name:            get_budget_amount
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  FUNCTION get_budget_amount RETURN NUMBER IS
  
  BEGIN
  
    RETURN g_budget_amount;
  
  END get_budget_amount;

  --------------------------------------------------------------------
  --  name:            get_obligation_amount
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  FUNCTION get_obligation_amount RETURN NUMBER IS
  
  BEGIN
  
    RETURN g_obligation_amount;
  
  END get_obligation_amount;

  --------------------------------------------------------------------
  --  name:            get_actual_amount
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  FUNCTION get_actual_amount RETURN NUMBER IS
  
  BEGIN
  
    RETURN g_actual_amount;
  
  END get_actual_amount;

  --------------------------------------------------------------------
  --  name:            get_funds_avail_amount
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  FUNCTION get_funds_avail_amount RETURN NUMBER IS
  
  BEGIN
  
    RETURN g_funds_avail_amount;
  
  END get_funds_avail_amount;

  --------------------------------------------------------------------
  --  name:            get_encumbrance_amount
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  FUNCTION get_encumbrance_amount RETURN NUMBER IS
  
  BEGIN
  
    RETURN g_encumbrance_amount;
  
  END get_encumbrance_amount;

  --------------------------------------------------------------------
  --  name:            get_commitment_amount
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  FUNCTION get_commitment_amount RETURN NUMBER IS
  
  BEGIN
  
    RETURN g_commitment_amount;
  
  END get_commitment_amount;

  --------------------------------------------------------------------
  --  name:            get_other_amount
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  FUNCTION get_other_amount RETURN NUMBER IS
  
  BEGIN
  
    RETURN g_other_amount;
  
  END get_other_amount;

  --------------------------------------------------------------------
  --  name:            get_po_destination
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  FUNCTION get_po_destination(p_po_header_id NUMBER) RETURN VARCHAR2 IS
    l_destination_type_code VARCHAR2(20);
  BEGIN
  
    SELECT pd.destination_type_code
    INTO   l_destination_type_code
    FROM   po_line_locations_all pll,
           po_distributions_all  pd
    WHERE  pll.line_location_id = pd.line_location_id
    AND    nvl(pll.cancel_flag, 'N') = 'N'
    AND    nvl(pll.closed_code, 'OPEN') != 'FINALLY CLOSED'
    AND    pd.po_distribution_id =
           (SELECT po_distribution_id
	 FROM   (SELECT *
	         FROM   (SELECT MAX(pll.price_override *
			    pd.quantity_ordered) amount,
			pd.po_distribution_id
		     FROM   po_line_locations_all pll,
			po_distributions_all  pd
		     WHERE  pll.line_location_id = pd.line_location_id
		     AND    nvl(pll.cancel_flag, 'N') = 'N'
		     AND    nvl(pll.closed_code, 'OPEN') !=
			'FINALLY CLOSED'
		     AND    pll.po_header_id = p_po_header_id
		     GROUP  BY po_distribution_id)
	         ORDER  BY amount DESC)
	 WHERE  rownum < 2);
  
    RETURN l_destination_type_code;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END get_po_destination;

  --------------------------------------------------------------------
  --  name:            set_startup_values
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --  1.1  11/03/2015  Dalit A. Raviv    CHG0032552 RFR PO to warehouse
  -- 1.2  09.12.15    yuval tal         CHG0037199 change  Vendor Scheduler at Site level attribute1
  --                                    use xxpo_utils_pkg.get_vs_person_id   
  --------------------------------------------------------------------
  --------------------------------------------------------------------
  PROCEDURE set_startup_values(itemtype  IN VARCHAR2,
		       itemkey   IN VARCHAR2,
		       actid     IN NUMBER,
		       funcmode  IN VARCHAR2,
		       resultout OUT NOCOPY VARCHAR2) IS
  
    x_orgid                 NUMBER;
    l_document_id           NUMBER;
    l_document_number       VARCHAR2(30);
    l_doc_subtype           VARCHAR2(30);
    l_doc_type              VARCHAR2(30);
    l_disp_amount           NUMBER;
    l_po_date               DATE;
    l_linkage_amount        NUMBER;
    l_linkage_amount_fmt    VARCHAR2(30);
    l_linkage_currency      VARCHAR2(3);
    l_position_structure_id NUMBER;
    l_destination_type      VARCHAR2(30) := NULL;
    l_sender_employee_id    NUMBER;
    l_sender_user_name      VARCHAR2(30);
    l_sender_email_address  VARCHAR2(80);
    l_preparer_id           NUMBER;
    -- 1.1 11/03/2015 Dalit A. Raviv CHG0032552 RFR PO to warehouse
    l_cc_wh_email_list VARCHAR2(1000);
    l_org_id           NUMBER;
    l_ph_att2          VARCHAR2(150);
    l_h_att2           VARCHAR2(150);
    l_value            VARCHAR2(10);
    --
  
  BEGIN
    -- xxobjt_debug_proc('funcmode', funcmode);
    -- Do nothing in cancel or timeout mode
    IF (funcmode <> wf_engine.eng_run) THEN
      resultout := wf_engine.eng_null;
      RETURN;
    END IF;
  
    l_document_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				 itemkey  => itemkey,
				 aname    => 'DOCUMENT_ID');
  
    l_doc_subtype := wf_engine.getitemattrtext(itemtype => itemtype,
			           itemkey  => itemkey,
			           aname    => 'DOCUMENT_SUBTYPE');
  
    l_doc_type := wf_engine.getitemattrtext(itemtype => itemtype,
			        itemkey  => itemkey,
			        aname    => 'DOCUMENT_TYPE');
  
    -- Set the multi-org context
  
    x_orgid := wf_engine.getitemattrnumber(itemtype => itemtype,
			       itemkey  => itemkey,
			       aname    => 'ORG_ID');
  
    IF x_orgid IS NOT NULL THEN
    
      po_moac_utils_pvt.set_org_context(x_orgid); -- <R12 MOAC>
    
    END IF;
  
    l_document_number := wf_engine.getitemattrtext(itemtype => itemtype,
				   itemkey  => itemkey,
				   aname    => 'DOCUMENT_NUMBER');
  
    IF l_doc_type = 'RELEASE' THEN
      -- 21.11.10 yuval
      l_disp_amount := po_notifications_sv3.get_doc_total(l_doc_type,
				          l_document_id);
    
      -- yuval 12.12.11
      SELECT xxpo_communication_report_pkg.get_converted_amount(l_disp_amount,
					    l_document_number,
					    rel.release_num),
	 nvl(xxpo_communication_report_pkg.get_rate_cur_for_xml(l_document_number,
					        rel.release_num),
	     ph.currency_code)
      INTO   l_linkage_amount,
	 l_linkage_currency
      FROM   po_headers_all  ph,
	 po_releases_all rel
      WHERE  ph.po_header_id = rel.po_header_id
      AND    rel.po_release_id = l_document_id;
    
      SELECT MIN(nvl(pll.promised_date, pll.need_by_date))
      INTO   l_po_date
      FROM   po_line_locations_all pll
      WHERE  pll.po_release_id = l_document_id;
    ELSE
      l_disp_amount := po_notifications_sv3.get_doc_total(l_doc_subtype,
				          l_document_id);
    
      SELECT xxpo_communication_report_pkg.get_converted_amount(l_disp_amount,
					    l_document_number,
					    0),
	 nvl(xxpo_communication_report_pkg.get_rate_cur_for_xml(l_document_number,
					        0),
	     ph.currency_code)
      INTO   l_linkage_amount,
	 l_linkage_currency
      FROM   po_headers_all ph
      WHERE  po_header_id = l_document_id;
    
      SELECT MIN(nvl(pll.promised_date, pll.need_by_date))
      INTO   l_po_date
      FROM   po_line_locations_all pll
      WHERE  po_header_id = l_document_id;
    END IF;
  
    --  xxobjt_debug_proc('xx', l_disp_amount);
    l_linkage_amount_fmt := xxgl_utils_pkg.format_mask(l_linkage_amount,
				       l_linkage_currency,
				       30,
				       'Y',
				       2);
  
    wf_engine.setitemattrtext(itemtype => itemtype,
		      itemkey  => itemkey,
		      aname    => 'XXPO_LINKAGE_AMOUNT',
		      avalue   => l_linkage_amount_fmt);
  
    wf_engine.setitemattrtext(itemtype => itemtype,
		      itemkey  => itemkey,
		      aname    => 'XXPO_LINKAGE_CURR',
		      avalue   => l_linkage_currency);
  
    wf_engine.setitemattrtext(itemtype => itemtype,
		      itemkey  => itemkey,
		      aname    => 'XXPO_NEED_BY_DATE',
		      avalue   => l_po_date);
  
    wf_engine.setitemattrtext(itemtype => itemtype,
		      itemkey  => itemkey,
		      aname    => 'XXPO_DIST_BUDGET_TBL',
		      avalue   => 'PLSQLCLOB:XXPO_NOTIFICATION_ATTR_PKG.GET_PO_DISTRIBUTIONS_DETAILS/' ||
			      itemtype || ':' || itemkey);
  
    wf_engine.setitemattrtext(itemtype => itemtype,
		      itemkey  => itemkey,
		      aname    => 'PO_LINES_DETAILS',
		      avalue   => 'PLSQLCLOB:XXPO_NOTIFICATION_ATTR_PKG.GET_PO_LINES_DETAILS/' ||
			      itemtype || ':' || itemkey);
  
    BEGIN
    
      l_destination_type := get_po_destination(l_document_id);
    
      IF l_destination_type IS NOT NULL THEN
        IF l_destination_type = 'INVENTORY' THEN
          BEGIN
	SELECT DISTINCT 'EXPENSE'
	INTO   l_destination_type
	FROM   po_distributions_all pold
	WHERE  pold.po_header_id = l_document_id
	AND    pold.code_combination_id <>
	       (SELECT mtlp.material_account
	         FROM   mtl_parameters mtlp
	         WHERE  mtlp.organization_id =
		    pold.destination_organization_id);
          EXCEPTION
	WHEN OTHERS THEN
	  NULL;
          END;
        END IF;
      
        SELECT pps.position_structure_id
        INTO   l_position_structure_id
        FROM   per_position_structures_v pps
        WHERE  nvl(attribute1, 'NO DEFINITION') = l_destination_type
        AND    nvl(attribute2, 0) = x_orgid;
      
        wf_engine.setitemattrnumber(itemtype => itemtype,
			itemkey  => itemkey,
			aname    => 'APPROVAL_PATH_ID',
			avalue   => l_position_structure_id);
      
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    BEGIN
      l_preparer_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				   itemkey  => itemkey,
				   aname    => 'PREPARER_ID');
    
      IF l_doc_type = 'RELEASE' THEN
      
        SELECT u.employee_id,
	   u.user_name,
	   u.email_address
        INTO   l_sender_employee_id,
	   l_sender_user_name,
	   l_sender_email_address
        FROM   po_releases_all ph,
	   po_headers_all  h,
	   --  ap_suppliers    s, CHG0037199
	   fnd_user u
        WHERE  ph.po_header_id = h.po_header_id
	  --  AND    h.vendor_id = s.vendor_id --
        AND    nvl(xxpo_utils_pkg.get_vs_person_id(h.vendor_site_id),
	       l_preparer_id) = u.employee_id --CHG0037199
        AND    ph.po_release_id = l_document_id;
      
      ELSE
        SELECT u.employee_id,
	   u.user_name,
	   u.email_address
        INTO   l_sender_employee_id,
	   l_sender_user_name,
	   l_sender_email_address
        FROM   po_headers_all ph,
	   --   ap_suppliers   s,CHG0037199
	   fnd_user u
        WHERE  /* ph.vendor_id = s.vendor_id --CHG0037199
                AND   */
         nvl(xxpo_utils_pkg.get_vs_person_id(ph.vendor_site_id) /*s.attribute7*/,
	 l_preparer_id) = u.employee_id --CHG0037199
         AND    ph.po_header_id = l_document_id;
      
      END IF;
    
      -- 1.1 11/03/2015 Dalit A. Raviv CHG0032552 RFR orders- PO to warehouse
      -- Handle send PO document to WahreHouse after approval.
      IF l_doc_type = 'RELEASE' THEN
        SELECT ph.org_id,
	   nvl(ph.attribute2, 'DR'),
	   nvl(h.attribute2, 'DR')
        INTO   l_org_id,
	   l_ph_att2,
	   l_h_att2
        FROM   po_releases_all ph,
	   po_headers_all  h
        WHERE  ph.po_header_id = h.po_header_id
        AND    ph.po_release_id = l_document_id;
      ELSE
        SELECT ph.org_id,
	   nvl(ph.attribute2, 'DR')
        INTO   l_org_id,
	   l_ph_att2
        FROM   po_headers_all ph
        WHERE  ph.po_header_id = l_document_id;
      END IF;
    
      -- this profile XXPO_RFR2WH_OU_PROCESS get value at organization level of Y/N
      -- if it set to YES continue.
      BEGIN
        SELECT 'Y'
        INTO   l_value
        FROM   xxobjt_profiles_v p
        WHERE  p.profile_option_name = 'XXPO_RFR2WH_OU_PROCESS'
        AND    level_id = l_org_id
        AND    profile_value = 'Y';
      EXCEPTION
        WHEN OTHERS THEN
          l_value := 'N';
      END;
    
      IF l_value = 'Y' AND
         (l_ph_att2 IN ('S', 'O') OR l_h_att2 IN ('S', 'O')) THEN
        BEGIN
          SELECT listagg(v.meaning, '; ') within GROUP(ORDER BY v.meaning) wh_email_list
          INTO   l_cc_wh_email_list
          FROM   fnd_lookup_values v
          WHERE  v.lookup_type = 'XXPO_WH_MAILLIST_RFR_PO_PDF'
          AND    v.language = 'US'
          AND    v.enabled_flag = 'Y'
          AND    trunc(SYSDATE) BETWEEN
	     nvl(v.start_date_active, SYSDATE - 1) AND
	     nvl(v.end_date_active, SYSDATE + 1)
          AND    v.tag = l_org_id
          AND    xxobjt_general_utils_pkg.is_mail_valid(v.meaning) = 'Y';
        
        EXCEPTION
          WHEN OTHERS THEN
	l_cc_wh_email_list := NULL;
        END;
      END IF;
    
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'XXCC_WAREHOUSE_APPROVAL_MAIL',
		        avalue   => l_cc_wh_email_list);
    
      -- end 1.1
      wf_engine.setitemattrnumber(itemtype => itemtype,
		          itemkey  => itemkey,
		          aname    => 'XXPO_SENDER_EMPLOYEE_ID',
		          avalue   => l_sender_employee_id);
    
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'XXPO_SENDER_ROLE',
		        avalue   => l_sender_user_name);
    
      wf_engine.setitemattrtext(itemtype => itemtype,
		        itemkey  => itemkey,
		        aname    => 'XXPO_SENDER_EMAIL',
		        avalue   => l_sender_email_address);
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    resultout := wf_engine.eng_completed || ':' || 'ACTIVITY_PERFORMED';
  
  END set_startup_values;

  --------------------------------------------------------------------
  --  name:            create_internal_requisition
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  PROCEDURE create_internal_requisition(p_po_header_id      po_headers_all.po_header_id%TYPE,
			    p_po_number         po_headers_all.segment1%TYPE,
			    p_preparer_id       po_headers_all.agent_id%TYPE,
			    p_subinventory_code mtl_secondary_inventories.secondary_inventory_name%TYPE,
			    p_location_id       hr_locations_all.location_id%TYPE,
			    p_assembly_id       mtl_system_items_b.inventory_item_id%TYPE,
			    p_po_line_id        po_lines_all.po_line_id%TYPE,
			    p_item_id           mtl_system_items_b.inventory_item_id%TYPE,
			    p_organization_id   mtl_parameters.organization_id%TYPE,
			    p_need_by_date      DATE,
			    p_quantity          NUMBER,
			    p_org_id            NUMBER,
			    p_user_id           NUMBER,
			    p_resp_id           NUMBER,
			    p_resp_appl_id      NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    l_app_short_name fnd_application.application_short_name%TYPE;
    l_request_id     NUMBER;
  
  BEGIN
  
    fnd_global.apps_initialize(user_id      => p_user_id,
		       resp_id      => p_resp_id,
		       resp_appl_id => p_resp_appl_id);
  
    SELECT a.application_short_name
    INTO   l_app_short_name
    FROM   fnd_application a
    WHERE  a.application_id = p_resp_appl_id;
  
    mo_global.set_org_context(p_org_id_char     => p_org_id,
		      p_sp_id_char      => NULL,
		      p_appl_short_name => l_app_short_name);
  
    INSERT INTO po_requisitions_interface_all
      (batch_id,
       header_description,
       item_id,
       item_revision,
       need_by_date,
       quantity,
       org_id,
       created_by,
       creation_date,
       last_updated_by,
       last_update_date,
       last_update_login,
       destination_organization_id,
       destination_subinventory,
       deliver_to_location_id,
       preparer_id,
       charge_account_id,
       source_organization_id,
       uom_code,
       deliver_to_requestor_id,
       authorization_status,
       source_type_code, -- INVENTORY
       destination_type_code, --  INVENTORY
       interface_source_code, --'FORM'
       project_accounting_context, -- N
       vmi_flag, --  N
       autosource_flag) -- P
      SELECT p_po_header_id,
	 'PO: ' || p_po_number,
	 bic.component_item_id,
	 xxinv_utils_pkg.get_current_revision(bic.component_item_id,
				  mp.organization_id),
	 p_need_by_date,
	 bic.component_quantity * p_quantity,
	 p_org_id,
	 p_user_id,
	 SYSDATE,
	 p_user_id,
	 SYSDATE,
	 fnd_global.login_id,
	 mp.organization_id,
	 p_subinventory_code,
	 p_location_id,
	 p_preparer_id,
	 mp.material_account,
	 mp.organization_id,
	 msi.primary_uom_code,
	 nvl(mpl.employee_id, p_preparer_id),
	 'INCOMPLETE',
	 'INVENTORY',
	 'INVENTORY',
	 'NJRC',
	 'N',
	 'N',
	 'P'
      FROM   bom_bill_of_materials    bbom,
	 bom_inventory_components bic,
	 mtl_system_items_b       msi,
	 mtl_parameters           mp,
	 mtl_planners             mpl
      WHERE  bbom.assembly_item_id = p_assembly_id
      AND    bbom.organization_id = mp.organization_id
      AND    bbom.bill_sequence_id = bic.bill_sequence_id
      AND    bic.component_item_id != p_item_id
      AND    bic.component_item_id = msi.inventory_item_id
      AND    bbom.organization_id = msi.organization_id
      AND    msi.planner_code = mpl.planner_code(+)
      AND    msi.organization_id = mpl.organization_id(+)
      AND    mp.organization_id = p_organization_id;
  
    COMMIT;
  
    l_request_id := fnd_request.submit_request(application => 'PO',
			           program     => 'REQIMPORT',
			           argument1   => 'NJRC',
			           argument2   => p_po_header_id,
			           argument3   => 'ALL',
			           argument4   => NULL,
			           argument5   => 'N',
			           argument6   => 'Y');
  
    COMMIT;
  END create_internal_requisition;

  --------------------------------------------------------------------
  --  name:            create_njrc_requisition
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  PROCEDURE create_njrc_requisition(itemtype  IN VARCHAR2,
			itemkey   IN VARCHAR2,
			actid     IN NUMBER,
			funcmode  IN VARCHAR2,
			resultout OUT NOCOPY VARCHAR2) IS
  
    -- all line with NJRC category in PO
    CURSOR csr_njrc_items(p_document_id po_headers_all.po_header_id%TYPE) IS
      SELECT pl.po_line_id,
	 pl.item_id,
	 pll.ship_to_organization_id,
	 nvl(pll.need_by_date, pll.promised_date) need_by_date,
	 pl.quantity,
	 pl.org_id
      FROM   po_lines_all          pl,
	 po_line_locations_all pll,
	 mtl_item_categories   mic
      WHERE  pl.po_header_id = p_document_id
      AND    pl.po_line_id = pll.po_line_id
      AND    nvl(pl.cancel_flag, 'N') = 'N'
      AND    pl.item_id = mic.inventory_item_id
      AND    mic.organization_id =
	 xxinv_utils_pkg.get_master_organization_id
      AND    mic.category_id = fnd_profile.value('XXPO_NJRC_CATEGORY');
  
    cur_line csr_njrc_items%ROWTYPE;
  
    l_po_header_id      po_headers_all.po_header_id%TYPE;
    l_po_number         po_headers_all.segment1%TYPE;
    l_preparer_id       po_headers_all.agent_id%TYPE;
    l_bom_id            mtl_system_items_b.inventory_item_id%TYPE;
    l_subinventory_code mtl_secondary_inventories.secondary_inventory_name%TYPE;
    l_location_id       mtl_secondary_inventories.location_id%TYPE;
  
    l_user_id      NUMBER;
    l_resp_id      NUMBER;
    l_resp_appl_id NUMBER;
  
  BEGIN
  
    -- Do nothing in cancel or timeout mode
    IF (funcmode <> wf_engine.eng_run) THEN
      resultout := wf_engine.eng_null;
      RETURN;
    END IF;
  
    l_po_header_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				  itemkey  => itemkey,
				  aname    => 'DOCUMENT_ID');
  
    l_po_number := wf_engine.getitemattrtext(itemtype => itemtype,
			         itemkey  => itemkey,
			         aname    => 'DOCUMENT_NUMBER');
  
    l_preparer_id := wf_engine.getitemattrtext(itemtype => itemtype,
			           itemkey  => itemkey,
			           aname    => 'PREPARER_ID');
  
    l_user_id      := wf_engine.getitemattrnumber(itemtype => itemtype,
				  itemkey  => itemkey,
				  aname    => 'USER_ID');
    l_resp_id      := wf_engine.getitemattrnumber(itemtype => itemtype,
				  itemkey  => itemkey,
				  aname    => 'RESPONSIBILITY_ID');
    l_resp_appl_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				  itemkey  => itemkey,
				  aname    => 'APPLICATION_ID');
  
    FOR cur_line IN csr_njrc_items(l_po_header_id) LOOP
      BEGIN
        SELECT si.secondary_inventory_name,
	   si.location_id
        INTO   l_subinventory_code,
	   l_location_id
        FROM   po_headers_all            poh,
	   mtl_secondary_inventories si
        WHERE  poh.vendor_site_id = si.attribute1
        AND    poh.po_header_id = l_po_header_id
        AND    si.organization_id = cur_line.ship_to_organization_id;
      
        resultout := wf_engine.eng_completed || ':SUCCESS';
      
      EXCEPTION
        WHEN OTHERS THEN
          RETURN;
      END;
    
      --find BOM, if find more that one raise error
      SELECT bill.assembly_item_id
      INTO   l_bom_id
      FROM   bom_bill_of_materials    bill,
	 bom_inventory_components comp
      WHERE  bill.organization_id = cur_line.ship_to_organization_id
      AND    bill.bill_sequence_id = comp.bill_sequence_id
      AND    comp.component_item_id = cur_line.item_id
      AND    SYSDATE BETWEEN comp.effectivity_date AND
	 nvl(comp.disable_date, SYSDATE + 1);
    
      --find all component in njrc item level and create int req
      create_internal_requisition(l_po_header_id,
		          l_po_number,
		          l_preparer_id,
		          l_subinventory_code,
		          l_location_id,
		          l_bom_id,
		          cur_line.po_line_id,
		          cur_line.item_id,
		          cur_line.ship_to_organization_id,
		          cur_line.need_by_date,
		          cur_line.quantity,
		          cur_line.org_id,
		          l_user_id,
		          l_resp_id,
		          l_resp_appl_id);
    
    END LOOP;
  
    resultout := wf_engine.eng_completed || ':SUCCESS';
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXPO_WF_NOTIFICATION_PKG',
	          'CREATE_NJRC_REQUISITION',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          'Error in assembly',
	          'PO: ' || l_po_number,
	          SQLERRM);
      RAISE;
    
  END create_njrc_requisition;

  --------------------------------------------------------------------
  --  name:            check_is_njrc_req_needed
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  PROCEDURE check_is_njrc_req_needed(itemtype  IN VARCHAR2,
			 itemkey   IN VARCHAR2,
			 actid     IN NUMBER,
			 funcmode  IN VARCHAR2,
			 resultout OUT NOCOPY VARCHAR2) IS
  
    l_req_needed        VARCHAR2(1) := 'N';
    l_document_id       NUMBER;
    l_document_type     VARCHAR2(20);
    l_document_sub_type VARCHAR2(20);
  
  BEGIN
  
    -- Do nothing in cancel or timeout mode
    IF (funcmode <> wf_engine.eng_run) THEN
    
      resultout := wf_engine.eng_null;
      RETURN;
    
    END IF;
  
    l_document_id       := wf_engine.getitemattrnumber(itemtype => itemtype,
				       itemkey  => itemkey,
				       aname    => 'DOCUMENT_ID');
    l_document_type     := wf_engine.getitemattrtext(itemtype => itemtype,
				     itemkey  => itemkey,
				     aname    => 'DOCUMENT_TYPE'); -- 'PO'
    l_document_sub_type := wf_engine.getitemattrtext(itemtype => itemtype,
				     itemkey  => itemkey,
				     aname    => 'DOCUMENT_SUBTYPE'); -- 'STANDARD'
  
    IF l_document_type = 'PO' AND l_document_sub_type = 'STANDARD' THEN
    
      BEGIN
      
        SELECT 'Y'
        INTO   l_req_needed
        FROM   po_lines_all        pl,
	   mtl_item_categories mic
        WHERE  po_header_id = l_document_id
        AND    nvl(pl.cancel_flag, 'N') = 'N'
        AND    pl.item_id = mic.inventory_item_id
        AND    mic.organization_id =
	   xxinv_utils_pkg.get_master_organization_id
        AND    mic.category_id = fnd_profile.value('XXPO_NJRC_CATEGORY')
        AND    rownum < 2;
      
      EXCEPTION
        WHEN no_data_found THEN
          l_req_needed := 'N';
      END;
    
    ELSE
      -- not l_document_type = 'PO' AND l_document_sub_type = 'STANDARD'
      l_req_needed := 'N';
    END IF;
  
    resultout := wf_engine.eng_completed || ':' || l_req_needed;
  
  END check_is_njrc_req_needed;

  --------------------------------------------------------------------
  --  name:            set_req_additional_attr
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  PROCEDURE set_req_additional_attr(itemtype  IN VARCHAR2,
			itemkey   IN VARCHAR2,
			actid     IN NUMBER,
			funcmode  IN VARCHAR2,
			resultout OUT NOCOPY VARCHAR2) IS
  
    l_addnl_attributes_text VARCHAR2(240);
    l_document_id           NUMBER;
  
  BEGIN
  
    l_document_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				 itemkey  => itemkey,
				 aname    => 'DOCUMENT_ID');
  
    SELECT rtrim(hr_general.decode_person_name(pr.to_person_id) || ', ' ||
	     pr.need_by_date,
	     ', ')
    INTO   l_addnl_attributes_text
    FROM   po_requisition_lines_all pr
    WHERE  pr.requisition_header_id = l_document_id
    AND    rownum < 2;
  
    wf_engine.setitemattrtext(itemtype => itemtype,
		      itemkey  => itemkey,
		      aname    => 'XXPO_ADDNL_MSG_ATTR',
		      avalue   => l_addnl_attributes_text);
  
    resultout := wf_engine.eng_completed || ':' || 'ACTIVITY_PERFORMED';
  
  END set_req_additional_attr;

  --------------------------------------------------------------------
  --  name:            set_dates_unchanged
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  PROCEDURE set_dates_unchanged(itemtype  IN VARCHAR2,
		        itemkey   IN VARCHAR2,
		        actid     IN NUMBER,
		        funcmode  IN VARCHAR2,
		        resultout OUT NOCOPY VARCHAR2) IS
  
  BEGIN
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_NEED_BY_DATE_DATE_CHANGE',
		           'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_PROMISED_DATE_DATE_CHANGE',
		           'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_PROMISED_DATE',
		           'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_NEED_BY_DATE',
		           'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_SHIPMENT_NUMBER',
		           'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_SHIP_TO_ORGANIZATION',
		           'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_SHIP_TO_LOCATION',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_LAST_ACCEPT_DATE',
		           'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_PAYMENT_TYPE',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_DESCRIPTION',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_WORK_APPROVER_ID',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_DAYS_LATE_RCPT_ALLOWED',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_PRICE_OVERRIDE',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_S_TAXABLE_FLAG',
		           'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype, itemkey, 'CO_D_DIST_NUM', 'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_D_DELIVER_TO_PERSON',
		           'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_D_GL_ENCUMBERED_DATE',
		           'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_D_CHARGE_ACCOUNT',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_D_RATE_DATE',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_D_DEST_SUBINVENTORY',
		           'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_H_VENDOR_CONTACT_MODIFIED',
		           'N');
  
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_H_ACCEPT_REQUIRED_MODIFIED',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_H_ACCEPT_DUE_MODIFIED',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_H_NOTE_TO_VENDOR_MODIFIED',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_H_FREIGHT_MODIFIED',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_H_AGENT_MODIFIED',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_L_ITEM_REVISION',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_L_ITEM_DESCRIPTION',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_L_NOTE_TO_VENDOR',
		           'N');
    po_wf_util_pkg.setitemattrtext(itemtype,
		           itemkey,
		           'CO_L_VENDOR_PRODUCT_NUM',
		           'N');
    resultout := wf_engine.eng_completed || ':' || 'ACTIVITY_PERFORMED';
  
  END set_dates_unchanged;

  --------------------------------------------------------------------
  --  name:            init_respond_note
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  PROCEDURE init_respond_note(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2) IS
  
  BEGIN
    -- Do nothing in cancel or timeout mode
    IF (funcmode <> wf_engine.eng_run) THEN
      resultout := wf_engine.eng_null;
      RETURN;
    END IF;
  
    po_wf_util_pkg.setitemattrtext(itemtype, itemkey, 'NOTE', NULL);
  
  END init_respond_note;

  --------------------------------------------------------------------
  -- customization code: CUST004 -
  -- name:               get_last_mon_in_period
  -- create by:          Dalit A. Raviv
  -- $Revision:          1.0 $
  -- creation date:     18/01/2010
  --------------------------------------------------------------------
  -- process:            Function return the last month in quater
  --------------------------------------------------------------------
  -- ver   date          name            desc
  --   1.0   18/01/2010    Dalit A. Raviv   initial build
  -- 1.1     1.8.10        YUVAL TAL       ADD po_change_api1_s.validate_acceptance
  --------------------------------------------------------------------
  FUNCTION get_last_mon_in_period(p_gl_period_name VARCHAR2) RETURN VARCHAR2 IS
  
    l_gl_period_name VARCHAR2(15) := NULL;
  
  BEGIN
  
    /*    IF substr(p_gl_period_name, 1, 3) IN ('JAN', 'FEB', 'MAR') THEN
          RETURN 'MAR' || substr(p_gl_period_name, 4);
        ELSIF substr(p_gl_period_name, 1, 3) IN ('APR', 'MAY', 'JUN') THEN
          RETURN 'JUN' || substr(p_gl_period_name, 4);
        ELSIF substr(p_gl_period_name, 1, 3) IN ('JUL', 'AUG', 'SEP') THEN
          RETURN 'SEP' || substr(p_gl_period_name, 4);
        ELSIF substr(p_gl_period_name, 1, 3) IN ('OCT', 'NOV', 'DEC') THEN
          RETURN 'DEC' || substr(p_gl_period_name, 4);
        END IF;
    */
    SELECT period_name
    INTO   l_gl_period_name
    FROM   gl_periods p
    WHERE  (period_num, period_year) =
           (SELECT MAX(period_num),
	       gp.period_year
	FROM   gl_periods gp
	WHERE  (gp.period_year, gp.quarter_num) =
	       (SELECT gp1.period_year,
		   gp1.quarter_num
	        FROM   gl_periods gp1
	        WHERE  period_name = p_gl_period_name
	        AND    gp1.period_set_name = gp.period_set_name)
	AND    gp.period_set_name = p.period_set_name
	AND    gp.period_type = p.period_type
	AND    gp.adjustment_period_flag = 'N'
	GROUP  BY gp.period_year)
    AND    p.period_set_name = 'OBJET_CALENDAR';
  
    RETURN l_gl_period_name;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN p_gl_period_name;
  END get_last_mon_in_period;

  --------------------------------------------------------------------
  --  name:            record_acceptance
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  PROCEDURE record_acceptance(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2) IS
  
    l_document_number po_headers_all.segment1%TYPE;
    l_document_type   VARCHAR2(15); -- 'PO'
    --l_document_sub_type VARCHAR2(30); -- 'STANDARD'
    l_revision_num      po_headers_all.revision_num%TYPE;
    l_org_id            NUMBER;
    l_buyer_employee_id NUMBER;
    l_current_revision  po_headers_all.revision_num%TYPE;
    l_document_id       NUMBER;
    l_release_id        NUMBER;
    l_release_num       NUMBER;
    acceptance_failed EXCEPTION;
  
  BEGIN
    -- Do nothing in cancel or timeout mode
    IF (funcmode <> wf_engine.eng_run) THEN
    
      resultout := wf_engine.eng_null;
      RETURN;
    
    END IF;
  
    l_document_id     := wf_engine.getitemattrnumber(itemtype => itemtype,
				     itemkey  => itemkey,
				     aname    => 'DOCUMENT_ID');
    l_document_number := wf_engine.getitemattrtext(itemtype => itemtype,
				   itemkey  => itemkey,
				   aname    => 'DOCUMENT_NUMBER');
    l_document_type   := wf_engine.getitemattrtext(itemtype => itemtype,
				   itemkey  => itemkey,
				   aname    => 'DOCUMENT_TYPE'); -- 'PO'
    /*l_document_sub_type := wf_engine.getitemattrtext(itemtype => itemtype,
                                                     itemkey  => itemkey,
                                                     aname    => 'DOCUMENT_SUBTYPE'); -- 'STANDARD'
    */
    l_release_num := wf_engine.getitemattrnumber(itemtype => itemtype,
				 itemkey  => itemkey,
				 aname    => 'RELEASE_NUM');
  
    IF l_document_type = 'RELEASE' THEN
      l_release_id  := l_document_id;
      l_document_id := NULL;
    END IF;
  
    l_revision_num      := wf_engine.getitemattrnumber(itemtype => itemtype,
				       itemkey  => itemkey,
				       aname    => 'REVISION_NUMBER');
    l_buyer_employee_id := wf_engine.getitemattrnumber(itemtype        => itemtype,
				       itemkey         => itemkey,
				       aname           => 'XXPO_SENDER_EMPLOYEE_ID',
				       ignore_notfound => TRUE);
    l_org_id            := wf_engine.getitemattrnumber(itemtype => itemtype,
				       itemkey  => itemkey,
				       aname    => 'ORG_ID');
    IF l_org_id IS NOT NULL THEN
      po_moac_utils_pvt.set_org_context(l_org_id); -- <R12 MOAC>
    END IF;
  
    IF po_change_api1_s.validate_acceptance(x_po_header_id     => l_document_id,
			        x_po_release_id    => l_release_id,
			        x_employee_id      => l_buyer_employee_id,
			        x_revision_num     => l_revision_num,
			        x_current_revision => l_current_revision,
			        x_interface_type   => NULL,
			        x_transaction_id   => NULL) = 1 THEN
    
      IF po_change_api1_s.record_acceptance(x_po_number              => l_document_number,
			        x_release_number         => l_release_num,
			        x_revision_number        => l_revision_num,
			        x_action                 => 'PO PDF to Supplier',
			        x_action_date            => SYSDATE,
			        x_employee_id            => l_buyer_employee_id,
			        x_accepted_flag          => 'N',
			        x_acceptance_lookup_code => 'SENTMAIL',
			        x_note                   => fnd_message.get_string('XXOBJT',
							           'XXPO_AUTOMAIL_TO_VENDOR'),
			        x_interface_type         => NULL,
			        x_transaction_id         => NULL,
			        version                  => '1.0',
			        p_org_id                 => l_org_id) = 0 THEN
      
        RAISE acceptance_failed;
      END IF;
    END IF;
  
  EXCEPTION
    WHEN acceptance_failed THEN
      wf_core.context('XXPO_WF_NOTIFICATION_PKG',
	          'RECORD_ACCEPTANCE',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          'Acceptance failed',
	          'PO: ' || l_document_number,
	          SQLERRM);
      RAISE;
    WHEN OTHERS THEN
      wf_core.context('XXPO_WF_NOTIFICATION_PKG',
	          'RECORD_ACCEPTANCE',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          'Others',
	          'PO: ' || l_document_number,
	          SQLERRM);
      RAISE;
    
  END record_acceptance;

  --------------------------------------------------------------------
  --  name:            update_orig_dates_autonomous
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  PROCEDURE update_orig_dates_autonomous(p_document_id   NUMBER,
			     p_document_type VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
  BEGIN
    IF p_document_type = 'PO' THEN
      UPDATE po_line_locations_all
      SET    attribute3 = nvl(attribute3,
		      to_char(need_by_date, 'YYYY/MM/DD HH24:MI:SS')),
	 attribute4 = nvl(attribute4,
		      to_char(promised_date, 'YYYY/MM/DD HH24:MI:SS'))
      WHERE  po_header_id = p_document_id
      AND    (attribute3 IS NULL OR attribute4 IS NULL);
    ELSIF p_document_type = 'RELEASE' THEN
    
      UPDATE po_line_locations_all
      SET    attribute3 = nvl(attribute3,
		      to_char(need_by_date, 'YYYY/MM/DD HH24:MI:SS')),
	 attribute4 = nvl(attribute4,
		      to_char(promised_date, 'YYYY/MM/DD HH24:MI:SS'))
      WHERE  po_release_id = p_document_id
      AND    (attribute3 IS NULL OR attribute4 IS NULL);
    END IF;
  
    COMMIT;
  
  END update_orig_dates_autonomous;

  --------------------------------------------------------------------
  --  name:            update_orig_dates
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  PROCEDURE update_orig_dates(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2) IS
  
    l_document_id       po_headers_all.po_header_id%TYPE;
    l_document_type     VARCHAR2(15); -- 'PO' -- RELEASE
    l_document_sub_type VARCHAR2(30); -- 'STANDARD'
  
  BEGIN
  
    IF (funcmode <> wf_engine.eng_run) THEN
    
      resultout := wf_engine.eng_null;
      RETURN;
    
    END IF;
  
    l_document_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				 itemkey  => itemkey,
				 aname    => 'DOCUMENT_ID');
  
    l_document_type     := wf_engine.getitemattrtext(itemtype => itemtype,
				     itemkey  => itemkey,
				     aname    => 'DOCUMENT_TYPE'); -- 'PO'
    l_document_sub_type := wf_engine.getitemattrtext(itemtype => itemtype,
				     itemkey  => itemkey,
				     aname    => 'DOCUMENT_SUBTYPE'); -- 'STANDARD'
  
    IF (l_document_type = 'PO' AND l_document_sub_type = 'STANDARD') OR
       (l_document_type = 'RELEASE' AND l_document_sub_type = 'BLANKET') THEN
    
      update_orig_dates_autonomous(l_document_id, l_document_type);
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXPO_WF_NOTIFICATION_PKG',
	          'UPDATE_ORIG_DATES',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          'Others',
	          l_document_id,
	          SQLERRM);
      RAISE;
    
  END update_orig_dates;

  --------------------------------------------------------------------
  --  name:            set_attr_email_doc
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   18/06/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver   date         name            desc
  --  1.0   18/06/2010   Ella Malchi     initial build
  --  1.1   18/07/2010   Ella Malchi     change logic
  --  2.6   02/06/2014   sanjai misra    CHG0031820
  --                                     For US OU, send email if any of the PO
  --                                     attribute is changed, for other OUs,
  --                                     email is sent only if need by date is changed.
  --------------------------------------------------------------------
  PROCEDURE set_attr_email_doc(itemtype  IN VARCHAR2,
		       itemkey   IN VARCHAR2,
		       actid     IN NUMBER,
		       funcmode  IN VARCHAR2,
		       resultout OUT NOCOPY VARCHAR2) IS
  
    --l_document_id       po_headers_all.po_header_id%TYPE;
    l_document_type     VARCHAR2(15); -- 'PO'
    l_document_sub_type VARCHAR2(30); -- 'STANDARD'
    l_source_code       VARCHAR2(25);
    l_po_changed        VARCHAR2(1);
    l_org_id            po_headers_all.org_id % TYPE;
    l_excluded_org      NUMBER;
  
    CURSOR c_excluded_org(p_org_id NUMBER) IS
      SELECT 1
      FROM   po_lookup_codes
      WHERE  lookup_type = 'XX_POAPPRV_OU'
      AND    lookup_code = to_char(p_org_id);
  BEGIN
  
    IF (funcmode <> wf_engine.eng_run) THEN
      resultout := wf_engine.eng_null;
      RETURN;
    END IF;
  
    l_po_changed := wf_engine.getitemattrtext(itemtype => itemtype,
			          itemkey  => itemkey,
			          aname    => 'EMAIL_DOCUMENT');
  
    IF l_po_changed != 'Y' THEN
      resultout := wf_engine.eng_completed || ':' || l_po_changed;
      RETURN;
    END IF;
  
    /*
      Change Request 31820
      Added this code to check if ORG_ID is excluded to perform check on attribute
      CO_S_NEED_BY_DATE. if ORG is excluded, then do not execute the logic.
      At present only StrataSys US is not required to check on the
      attribute CO_S_NEED_BY_DATE
    */
    l_org_id := wf_engine.getitemattrnumber(itemtype => itemtype,
			        itemkey  => itemkey,
			        aname    => 'ORG_ID');
    OPEN c_excluded_org(l_org_id);
    FETCH c_excluded_org
      INTO l_excluded_org;
    IF c_excluded_org % NOTFOUND THEN
      l_excluded_org := 0;
    END IF;
    CLOSE c_excluded_org;
  
    IF l_excluded_org = 0 THEN
    
      /*l_document_id := wf_engine.getitemattrnumber(itemtype => itemtype,
      itemkey  => itemkey,
      aname    => 'DOCUMENT_ID');*/
    
      l_document_type     := wf_engine.getitemattrtext(itemtype => itemtype,
				       itemkey  => itemkey,
				       aname    => 'DOCUMENT_TYPE'); -- 'PO'
      l_document_sub_type := wf_engine.getitemattrtext(itemtype => itemtype,
				       itemkey  => itemkey,
				       aname    => 'DOCUMENT_SUBTYPE'); -- 'STANDARD'
    
      l_source_code := wf_engine.getitemattrtext(itemtype => itemtype,
				 itemkey  => itemkey,
				 aname    => 'INTERFACE_SOURCE_CODE'); -- null
    
      IF l_document_type = 'PO' AND l_document_sub_type = 'STANDARD' THEN
      
        IF l_source_code IS NULL THEN
          --  PO_FORM/CANCEL
          l_po_changed := wf_engine.getitemattrtext(itemtype => itemtype,
				    itemkey  => itemkey,
				    aname    => 'CO_S_NEED_BY_DATE');
        
          IF l_po_changed = 'N' THEN
          
	wf_engine.setitemattrtext(itemtype => itemtype,
			  itemkey  => itemkey,
			  aname    => 'EMAIL_DOCUMENT',
			  avalue   => 'N');
          
	resultout := wf_engine.eng_completed || ':' || 'N';
	RETURN;
          END IF;
        END IF;
      END IF;
    END IF;
    resultout := wf_engine.eng_completed || ':' || l_po_changed;
  
  END set_attr_email_doc;

  --------------------------------------------------------------------
  --  name:            get_expense_type
  --  create by:       xx
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/20xx  xxx               initial build
  --------------------------------------------------------------------
  FUNCTION get_expense_type(p_code_combination_id NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c IS
      SELECT *
      FROM   gl_code_combinations t
      WHERE  t.code_combination_id = p_code_combination_id;
    --l_exp_type VARCHAR2(200);
  
  BEGIN
  
    FOR i IN c LOOP
    
      CASE
        WHEN i.segment3 = '203040' THEN
          RETURN 'Inter Company -' || xxobjt_general_utils_pkg.get_valueset_desc('XXGL_COMPANY_SEG',
						         i.segment7);
        WHEN i.segment3 LIKE '6%' THEN
          RETURN 'Expense';
        WHEN i.segment3 LIKE '13%' THEN
          RETURN 'Inventory';
        WHEN i.segment3 LIKE '18%' THEN
          RETURN 'Fixed Asset';
        ELSE
          RETURN NULL;
      END CASE;
    
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            is_po_approval_needed
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   28.11.2012
  --------------------------------------------------------------------
  --  purpose :        CR 606 : Skip Approval in case of PO for Stratasys created
  --                   by a drop shipped Sales order containing eligible products
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0   18/06/2010   yuval tal    initial build
  --  1.1   31/07/2013   Vitaly       added code for CUST695 CR 932 PO remaining Shipments Conversion (for Std Cost)
  --  1.2   08/07/2015   Michal Tzvik CHG0035632 - Accelerating 0$ POs approval process
  --------------------------------------------------------------------
  PROCEDURE is_po_approval_needed(itemtype  IN VARCHAR2,
		          itemkey   IN VARCHAR2,
		          actid     IN NUMBER,
		          funcmode  IN VARCHAR2,
		          resultout OUT NOCOPY VARCHAR2) IS
  
    l_po_header_id     NUMBER;
    l_tmp              VARCHAR2(1);
    l_document_subtype VARCHAR2(50);
    l_document_type    VARCHAR2(50);
    l_total_amount     NUMBER;
  BEGIN
    l_tmp := 'Y'; -- CHG0035632 Michal Tzvik
  
    l_po_header_id := wf_engine.getitemattrnumber(itemtype => itemtype, --
				  itemkey  => itemkey, --
				  aname    => 'DOCUMENT_ID');
  
    l_document_subtype := wf_engine.getitemattrtext(itemtype => itemtype, --
				    itemkey  => itemkey, --
				    aname    => 'DOCUMENT_SUBTYPE');
  
    l_document_type := wf_engine.getitemattrtext(itemtype => itemtype, --
				 itemkey  => itemkey, --
				 aname    => 'DOCUMENT_TYPE');
  
    -- CHG0035632 Michal Tzvik: Replace logic. if total amount=0 then no need for approval
    l_total_amount := to_number(REPLACE(wf_engine.getitemattrtext(itemtype => itemtype, --
					      itemkey  => itemkey, --
					      aname    => 'TOTAL_AMOUNT_DSP'),
			    ','));
  
    IF to_number(l_total_amount) = 0 THEN
      l_tmp := 'N';
    
    END IF;
  
    resultout := wf_engine.eng_completed || ':' || l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      resultout := wf_engine.eng_completed || ':' || nvl(l_tmp, 'Y');
    
  END;

  --------------------------------------------------------------------
  --  name:            is_po_approval_needed_std_cost
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   28.11.2012
  --------------------------------------------------------------------
  --  purpose :        CUST695 CR 932 PO remaining Shipments Conversion (for Std Cost)
  --                   check if po belong to po std cost conversion
  --                   used in poapprv wf  to avoid approval and  email submission to supplier
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0   12.8.13   yuval tal    initial build
  --------------------------------------------------------------------
  PROCEDURE is_po_approval_needed_std_cost(itemtype  IN VARCHAR2,
			       itemkey   IN VARCHAR2,
			       actid     IN NUMBER,
			       funcmode  IN VARCHAR2,
			       resultout OUT NOCOPY VARCHAR2) IS
  
    l_po_header_id     NUMBER;
    l_tmp              VARCHAR2(1);
    l_document_subtype VARCHAR2(50);
    l_document_type    VARCHAR2(50);
  
    CURSOR c_search_po_in_std_cost_conv(p_po_header_id NUMBER) IS
      SELECT 'Y'
      FROM   xxconv_po_log polog
      WHERE  polog.po_header_id = p_po_header_id --cursor parameter
      AND    polog.status = 'S'
      AND    rownum = 1;
  BEGIN
    IF nvl(fnd_profile.value('XXPO_CONV_STD_COST_ACTIVE'), 'N') = 'Y' THEN
      l_document_type := wf_engine.getitemattrtext(itemtype => itemtype,
				   itemkey  => itemkey,
				   aname    => 'DOCUMENT_TYPE');
    
      l_document_subtype := wf_engine.getitemattrtext(itemtype => itemtype,
				      itemkey  => itemkey,
				      aname    => 'DOCUMENT_SUBTYPE');
    
      IF l_document_subtype = 'STANDARD' AND l_document_type = 'PO' THEN
      
        l_po_header_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				      itemkey  => itemkey,
				      aname    => 'DOCUMENT_ID');
      
        IF fnd_profile.value('XXPO_CONV_AUTO_APPROVAL') = 'Y' THEN
          OPEN c_search_po_in_std_cost_conv(l_po_header_id);
          FETCH c_search_po_in_std_cost_conv
	INTO l_tmp;
          CLOSE c_search_po_in_std_cost_conv;
          IF nvl(l_tmp, 'N') = 'Y' THEN
	resultout := wf_engine.eng_completed || ':' || 'N';
	RETURN;
          END IF;
        END IF;
      END IF;
    END IF;
    resultout := wf_engine.eng_completed || ':' || 'Y';
  END;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    is_po_created_from_requisition
  Author's Name:   Sandeep Akula
  Date Written:    05-JUNE-2014
  Purpose:         Checks if PO is created from Requisition
  Program Style:   Procedure Definition
  Called From:     Called in POAPPRV Workflow (Process: XX: Notify PO Approved Subprocess)
  Workflow Usage Details:
                     Item Type: PO Approval
                     Process Internal Name: XXPO_NOTIFY_PO_APPROVED
                     Process Display Name: XX: Notify PO Approved Subprocess
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  05-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031722
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE is_po_created_from_requisition(itemtype  IN VARCHAR2,
			       itemkey   IN VARCHAR2,
			       actid     IN NUMBER,
			       funcmode  IN VARCHAR2,
			       resultout OUT NOCOPY VARCHAR2) IS
  
    l_org_id    NUMBER;
    l_po_number po_headers_all.segment1%TYPE;
    l_cnt       NUMBER;
  
  BEGIN
  
    -- Do nothing in cancel or timeout mode
    --
    IF (funcmode <> wf_engine.eng_run) THEN
      resultout := wf_engine.eng_null;
      RETURN;
    END IF;
  
    l_org_id := wf_engine.getitemattrnumber(itemtype => itemtype,
			        itemkey  => itemkey,
			        aname    => 'ORG_ID');
  
    l_po_number := wf_engine.getitemattrtext(itemtype => itemtype,
			         itemkey  => itemkey,
			         aname    => 'DOCUMENT_NUMBER');
  
    BEGIN
      SELECT COUNT(*)
      INTO   l_cnt
      FROM   po_requisition_headers_all prh,
	 po_requisition_lines_all   prl,
	 po_req_distributions_all   prd,
	 per_people_x               ppx,
	 po_headers_all             poh,
	 po_distributions_all       pda
      WHERE  prh.requisition_header_id = prl.requisition_header_id
      AND    ppx.person_id = prh.preparer_id
      AND    prh.type_lookup_code = 'PURCHASE'
      AND    prd.requisition_line_id = prl.requisition_line_id
      AND    pda.req_distribution_id = prd.distribution_id
      AND    pda.po_header_id = poh.po_header_id
      AND    poh.segment1 = l_po_number
      AND    poh.org_id = l_org_id;
    
    EXCEPTION
      WHEN OTHERS THEN
        l_cnt := '';
    END;
  
    IF l_cnt > '0' THEN
      resultout := wf_engine.eng_completed || ':' || 'Y';
    ELSE
      resultout := wf_engine.eng_completed || ':' || 'N';
    END IF;
  
  END is_po_created_from_requisition;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    set_preparer_username_attr
  Author's Name:   Sandeep Akula
  Date Written:    05-JUNE-2014
  Purpose:         Derives Preparer from the PO Requisition and sets the PREPARER_USER_NAME attribute
  Program Style:   Procedure Definition
  Called From:     Called in POAPPRV Workflow (Process: XX: Notify PO Approved Subprocess)
  Workflow Usage Details:
                     Item Type: PO Approval
                     Process Internal Name: XXPO_NOTIFY_PO_APPROVED
                     Process Display Name: XX: Notify PO Approved Subprocess
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  05-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031722
  29-JUNE-2014        1.1                  Sandeep Akula     Added GROUP BY Clause to eliminate duplicates (CHG0032834)
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE set_preparer_username_attr(itemtype  IN VARCHAR2,
			   itemkey   IN VARCHAR2,
			   actid     IN NUMBER,
			   funcmode  IN VARCHAR2,
			   resultout OUT NOCOPY VARCHAR2) IS
  
    x_username                VARCHAR2(100);
    x_user_display_name       VARCHAR2(500);
    l_preparer_id             NUMBER;
    l_buyer_id                NUMBER;
    l_org_id                  NUMBER;
    l_po_number               po_headers_all.segment1%TYPE;
    x_buyer_username          VARCHAR2(100);
    x_buyer_user_display_name VARCHAR2(500);
  
  BEGIN
  
    -- Do nothing in cancel or timeout mode
    --
    IF (funcmode <> wf_engine.eng_run) THEN
      resultout := wf_engine.eng_null;
      RETURN;
    END IF;
  
    l_org_id := wf_engine.getitemattrnumber(itemtype => itemtype,
			        itemkey  => itemkey,
			        aname    => 'ORG_ID');
  
    l_po_number := wf_engine.getitemattrtext(itemtype => itemtype,
			         itemkey  => itemkey,
			         aname    => 'DOCUMENT_NUMBER');
  
    BEGIN
      SELECT prh.preparer_id,
	 poh.agent_id
      INTO   l_preparer_id,
	 l_buyer_id
      FROM   po_requisition_headers_all prh,
	 po_requisition_lines_all   prl,
	 po_req_distributions_all   prd,
	 per_people_x               ppx,
	 po_headers_all             poh,
	 po_distributions_all       pda
      WHERE  prh.requisition_header_id = prl.requisition_header_id
      AND    ppx.person_id = prh.preparer_id
      AND    prh.type_lookup_code = 'PURCHASE'
      AND    prd.requisition_line_id = prl.requisition_line_id
      AND    pda.req_distribution_id = prd.distribution_id
      AND    pda.po_header_id = poh.po_header_id
      AND    poh.segment1 = l_po_number
      AND    poh.org_id = l_org_id
      GROUP  BY prh.preparer_id,
	    poh.agent_id; -- 07/29/2014 SAkula -- Added GROUP BY Clause to eliminate duplicates (CHG0032834)
    
    EXCEPTION
      WHEN OTHERS THEN
        l_preparer_id := '';
        l_buyer_id    := '';
    END;
  
    IF l_preparer_id IS NULL OR l_buyer_id IS NULL THEN
      resultout := wf_engine.eng_completed || ':FAIL';
    ELSE
    
      po_reqapproval_init1.get_user_name(l_preparer_id,
			     x_username,
			     x_user_display_name);
    
      po_reqapproval_init1.get_user_name(l_buyer_id,
			     x_buyer_username,
			     x_buyer_user_display_name);
    
      IF x_username = x_buyer_username THEN
        -- Buyer and Preparer are same
        resultout := wf_engine.eng_completed || ':FAIL';
      ELSE
        wf_engine.setitemattrtext(itemtype => itemtype,
		          itemkey  => itemkey,
		          aname    => 'REQ_PREPARER_USER_NAME',
		          avalue   => x_username);
        resultout := wf_engine.eng_completed || ':SUCCESS';
      END IF;
    END IF;
  END set_preparer_username_attr;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    check_ou_in_prparernotf_lookup
  Author's Name:   Sandeep Akula
  Date Written:    05-JUNE-2014
  Purpose:         Checks if the Operating Unit of the PO is listed in PO Lookup "XXPO_OU_FOR_PREPARER_NOTIF"
  Program Style:   Procedure Definition
  Called From:     Called in POAPPRV Workflow (Process: XX: Notify PO Approved Subprocess)
  Workflow Usage Details:
                     Item Type: PO Approval
                     Process Internal Name: XXPO_NOTIFY_PO_APPROVED
                     Process Display Name: XX: Notify PO Approved Subprocess
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  05-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031722
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE check_ou_in_prparernotf_lookup(itemtype  IN VARCHAR2,
			       itemkey   IN VARCHAR2,
			       actid     IN NUMBER,
			       funcmode  IN VARCHAR2,
			       resultout OUT NOCOPY VARCHAR2) IS
  
    l_excluded_org NUMBER := '';
    l_org_id       NUMBER;
  
    CURSOR c_excluded_org(p_org_id NUMBER) IS
      SELECT 1
      FROM   po_lookup_codes
      WHERE  lookup_type = 'XXPO_OU_FOR_PREPARER_NOTIF'
      AND    lookup_code = to_char(p_org_id);
  
  BEGIN
  
    -- Do nothing in cancel or timeout mode
    --
    IF (funcmode <> wf_engine.eng_run) THEN
      resultout := wf_engine.eng_null;
      RETURN;
    END IF;
  
    l_org_id := wf_engine.getitemattrnumber(itemtype => itemtype,
			        itemkey  => itemkey,
			        aname    => 'ORG_ID');
  
    OPEN c_excluded_org(l_org_id);
    FETCH c_excluded_org
      INTO l_excluded_org;
    CLOSE c_excluded_org;
  
    IF l_excluded_org = '1' THEN
      resultout := wf_engine.eng_completed || ':' || 'Y';
    ELSE
      resultout := wf_engine.eng_completed || ':' || 'N';
    END IF;
  
  END check_ou_in_prparernotf_lookup;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    check_ou_in_poapprv_ou_lookup
  Author's Name:   Sandeep Akula
  Date Written:    13-JUNE-2014
  Purpose:         Checks if the Operating Unit of the PO is listed in PO Lookup "XX_POAPPRV_OU"
  Program Style:   Procedure Definition
  Called From:     Called in POAPPRV Workflow (Process: XX: PO Approval Top Process)
  Workflow Usage Details:
                     Item Type: PO Approval
                     Process Internal Name: XXPO_POAPPRV_TOP
                     Process Display Name: XX: PO Approval Top Process
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  05-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031722
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE check_ou_in_poapprv_ou_lookup(itemtype  IN VARCHAR2,
			      itemkey   IN VARCHAR2,
			      actid     IN NUMBER,
			      funcmode  IN VARCHAR2,
			      resultout OUT NOCOPY VARCHAR2) IS
  
    l_excluded_org NUMBER := '';
    l_org_id       NUMBER;
  
    CURSOR c_excluded_org(p_org_id NUMBER) IS
      SELECT 1
      FROM   po_lookup_codes
      WHERE  lookup_type = 'XX_POAPPRV_OU'
      AND    lookup_code = to_char(p_org_id);
  
  BEGIN
  
    -- Do nothing in cancel or timeout mode
    --
    IF (funcmode <> wf_engine.eng_run) THEN
      resultout := wf_engine.eng_null;
      RETURN;
    END IF;
  
    l_org_id := wf_engine.getitemattrnumber(itemtype => itemtype,
			        itemkey  => itemkey,
			        aname    => 'ORG_ID');
  
    OPEN c_excluded_org(l_org_id);
    FETCH c_excluded_org
      INTO l_excluded_org;
    CLOSE c_excluded_org;
  
    IF l_excluded_org = '1' THEN
      resultout := wf_engine.eng_completed || ':' || 'Y';
    ELSE
      resultout := wf_engine.eng_completed || ':' || 'N';
    END IF;
  
  END check_ou_in_poapprv_ou_lookup;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    is_revision_greater_than_zero
  Author's Name:   Sandeep Akula
  Date Written:    13-JUNE-2014
  Purpose:         Checks if PO Revision is greater than zero
  Program Style:   Procedure Definition
  Called From:     Called in POAPPRV Workflow (Process: XX: Notify PO Approved Subprocess)
  Workflow Usage Details:
                     Item Type: PO Approval
                     Process Internal Name: XXPO_NOTIFY_PO_APPROVED
                     Process Display Name: XX: Notify PO Approved Subprocess
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031722
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE is_revision_greater_than_zero(itemtype  IN VARCHAR2,
			      itemkey   IN VARCHAR2,
			      actid     IN NUMBER,
			      funcmode  IN VARCHAR2,
			      resultout OUT NOCOPY VARCHAR2) IS
    l_revision_num NUMBER := '';
  BEGIN
  
    -- Do nothing in cancel or timeout mode
    --
    IF (funcmode <> wf_engine.eng_run) THEN
      resultout := wf_engine.eng_null;
      RETURN;
    END IF;
  
    l_revision_num := wf_engine.getitemattrnumber(itemtype => itemtype,
				  itemkey  => itemkey,
				  aname    => 'REVISION_NUMBER');
  
    IF l_revision_num > '0' THEN
      resultout := wf_engine.eng_completed || ':' || 'Y';
    ELSE
      resultout := wf_engine.eng_completed || ':' || 'N';
    END IF;
  
  END is_revision_greater_than_zero;
END xxpo_wf_notification_pkg;
/
