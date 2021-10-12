CREATE OR REPLACE PACKAGE BODY "XXOM_DENIED_PARTIES_PKG" AS

  --------------------------------------------------------------------
  -- name:            XXOM_DENIED_PARTIES_PKG
  -- create by:       yuval tal
  -- Revision:        1.5
  -- creation date:   19.07.12
  --------------------------------------------------------------------
  -- purpose :        support OM order process
  --------------------------------------------------------------------
  -- ver  date        name           desc
  -- 1.0  19.07.12    yuval tal       Initial Build CR465 cust 517
  -- 1.1  09.12.12    yuval tal       CR507:Denied parties - check in pick release process
  -- 1.2  13.01.13    yuval tal       bugfix : initiate_hold_pick_wf change item key format to mi instead of mm
  -- 1.3  17.01.13    yuval tal       check_denied_parties_wf :modify l_risk_country to varchar2(20) from varchar2(5)
  -- 1.4  06.03.13    yuval tal       CR689:Capture the releaser name when a release is done by Email
  --                                  add proc check_user_action_wf
  --                                  modify proc release_hold_wf : use wf new attribute CONTEXT_USER_MAIL to find user_id
  -- 1.5  22/04/2013  Dalit A. Raviv  procedure pick_release_delivery_check take out handle of
  --                                  the release of the request hold(that changed at the trigger xx_fnd_concurrent_requests_trg
  --                                  change p_err_code_and p_err_message order
  -- 1.6  10.3.14     yuval tal       CHG0031404 - modify check_denied_parties support new bpel server
  -- 1.7  23.4.14     yuval tal       CHG0032016 - add is_inventory_item ,modify is_dp_check_needed : Bug fix - Denied Parties hold - Exclude non inventory items
  -- 1.8  16-Nov-2015 Dalit A. RAviv  is_dp_check_needed  - CHG0036995 - Check denied party hold for all orders
  -- 1.9  19.4.16     yuval tal       CHG0037918 migration to 12c support redirect between 2 servers
  -- 2.0  23.11.17    Piyali Bhowmick  CHG0041843 - Add two new procedures:
  --                                   1.initiate_dp_hold_conc - Create a new program for applying hold on non-picked orders.
  --                                   2.initiate_dp_hold_wf - To initiate the DP Hold Workflow Process for a particular order line
  --  2.1 18.02.2018  roman winer  :  INC0114465 modified procedure "check_denied_parties" ' y ' to 'Y'
  --  2.2 24.10.2018  Diptasurjya     CHG0044277 - Insert audit table record and skip DP check if already checked for customer/contact/address
  --  3.0 12/01/2021  Roman W.        CHG0048579 - OIC (Jira : OIC-346)
  -- 2.3  19-AUG-2020 Diptasurjya     INC0202587 - Denied Party release comment not populated - bug fix
  --------------------------------------------------------------------
  -- C_SERVICE_NAME CONSTANT VARCHAR2(120) := 'DENIED_PARTY'; -- rem by Roman W. 27/05/2021 CHG0048579
  C_SERVICE_NAME CONSTANT VARCHAR2(120) := 'DENIED_PARTIES'; -- Added by Roman W. 27/05/2021 CHG0048579

  g_bpel_host VARCHAR2(300) := xxobjt_bpel_utils_pkg.get_bpel_host;
  -- WF ITEM type for DP
  g_item_type             VARCHAR2(20) := 'XXDPAPR';
  g_hold_workflow_process VARCHAR2(30) := 'MAIN';

  -- alert log
  --   TR (Triple Red - Name, Company,Address, and Country found),
  --   DR (Double Red - Name or Company and Address and Country found),
  --   _R (Red - Name or Company and Country found),
  --   _Y (Yellow ? Name or Company found).
  TYPE denied_arr_t IS TABLE OF VARCHAR2(500) INDEX BY VARCHAR2(30);
  g_denied_arr denied_arr_t;

  CURSOR c_delivery(c_batch_id NUMBER) IS
    SELECT d.*
      FROM wsh_picking_batches_v b, wsh_deliverables_v d /*WSH_DELIVERY_DETAILS*/
     WHERE b.delivery_id = d.delivery_id
       AND b.delivery_detail_id IS NULL
       AND b.batch_id = c_batch_id
    UNION ALL
    SELECT d.*
      FROM wsh_picking_batches_v b, wsh_deliverables_v d /*WSH_DELIVERY_DETAILS*/
     WHERE b.delivery_detail_id = d.delivery_detail_id
       AND b.batch_id = c_batch_id;
  ---------------------------------------------------------------------------
  -- init_globals
  ---------------------------------------------------------------------------
  PROCEDURE init_globals IS
  BEGIN
    g_denied_arr('TR') := 'Triple Red - Name, Company,Address, and Country found';
    g_denied_arr('DR') := 'Double Red - Name or Company and Address and Country found';
    g_denied_arr('_R') := 'Red - Name or Company and Country found';
    g_denied_arr('_Y') := 'Yellow - Name or Company found';
    g_denied_arr('') := '';
    g_denied_arr('~') := '';
    g_denied_arr('RISK_COUNTRY') := 'Risk Country';
  
  END;
  ------------------------------------------------------------------------------
  -- Ver   When         Who        Descr
  -- ----  -----------  ---------  ---------------------------------------------
  -- 1.0   14/12/2020   Roman W.   CHG0048579 - OIC
  ------------------------------------------------------------------------------
  procedure message(p_msg in varchar2) is
    l_msg varchar(32676);
  begin
  
    l_msg := substr(to_char(sysdate, 'DD/MM/YYYY HH24:MI:SS  ') || p_msg,
                    1,
                    32676);
  
    if fnd_global.CONC_REQUEST_ID > 0 then
      fnd_file.put_line(fnd_file.LOG, l_msg);
    else
      dbms_output.put_line(l_msg);
    end if;
  end message;
  -------------------------------------------
  -- get_user_name_by_email
  ------------------------------------------

  FUNCTION get_user_id_by_email(p_email VARCHAR2) RETURN VARCHAR2 IS
  
    CURSOR c IS
      SELECT u.user_id
<<<<<<< .mine
      FROM   wf_users t,
	 fnd_user u
      WHERE  upper(t.email_address) = upper(p_email)
      AND    u.user_name = t.name
      AND    t.parent_orig_system = 'PER';
  
||||||| .r4749
      FROM   wf_users t,
   fnd_user u
      WHERE  upper(t.email_address) = upper(p_email)
      AND    u.user_name = t.name
      AND    t.parent_orig_system = 'PER';

=======
        FROM wf_users t, fnd_user u
       WHERE upper(t.email_address) = upper(p_email)
         AND u.user_name = t.name
         AND t.parent_orig_system = 'PER';
  
>>>>>>> .r4768
    l_tmp VARCHAR2(150);
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN l_tmp;
  
  END;

  ------------------------------------------
  -- CHG0044277 - insert audit table record
  ---------------------------------------------
  -- ver  date        name            desc
  -- 1.0  24-OCT-2018 Diptasurjya     CHG0044277 - Insert record in Denied Party audit table
  --------------------------------------------
<<<<<<< .mine
  PROCEDURE insert_dp_audit_table(p_header_id       IN NUMBER,
		          p_cust_account_id IN NUMBER,
		          p_site_id         IN NUMBER,
		          p_contact_id      IN NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO xxom_dp_check_audit
      (header_id,
       cust_account_id,
       site_id,
       contact_id,
       dp_check_date,
       dp_check_flag)
    VALUES
      (p_header_id,
       p_cust_account_id,
       p_site_id,
       p_contact_id,
       SYSDATE,
       'Y');
    COMMIT;
  END insert_dp_audit_table;
||||||| .r4749
  procedure insert_dp_audit_table(p_header_id       IN number,
                                  p_cust_account_id IN number,
                                  p_site_id         IN number,
                                  p_contact_id      IN number) is
    pragma autonomous_transaction;
  begin
    insert into xxom_dp_check_audit (header_id,
                                     cust_account_id,
                                     site_id,
                                     contact_id,
                                     dp_check_date,
                                     dp_check_flag)
                             values (p_header_id,
                                     p_cust_account_id,
                                     p_site_id,
                                     p_contact_id,
                                     sysdate,
                                     'Y');
    commit;
  end insert_dp_audit_table;
=======
  procedure insert_dp_audit_table(p_header_id       IN number,
                                  p_cust_account_id IN number,
                                  p_site_id         IN number,
                                  p_contact_id      IN number) is
    pragma autonomous_transaction;
  begin
    insert into xxom_dp_check_audit
      (header_id,
       cust_account_id,
       site_id,
       contact_id,
       dp_check_date,
       dp_check_flag)
    values
      (p_header_id,
       p_cust_account_id,
       p_site_id,
       p_contact_id,
       sysdate,
       'Y');
    commit;
  end insert_dp_audit_table;
>>>>>>> .r4768

  ------------------------------------------
  -- CHG0044277 - purge audit table record
  ------------------------------------------
  -- ver  date        name            desc
  -- 1.0  24-OCT-2018 Diptasurjya     CHG0044277 - Purge Denied Party audit table if order is closed/cancelled
  --------------------------------------------
<<<<<<< .mine
  PROCEDURE purge_dp_audit_table(p_err_code    OUT NUMBER,
		         p_err_message OUT VARCHAR2) IS
  
  BEGIN
    DELETE FROM xxom_dp_check_audit xda
    WHERE  EXISTS
     (SELECT 1
	FROM   oe_order_headers_all oh
	WHERE  oh.header_id = xda.header_id
	AND    oh.flow_status_code IN ('CLOSED', 'CANCELLED'));
  
    p_err_message := 'SUCCESS: Deleted ' || SQL%ROWCOUNT ||
	         ' records from Denied Party Audit table';
    p_err_code    := 0;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code    := 2;
      p_err_message := 'ERROR: ' || SQLERRM;
  END purge_dp_audit_table;

||||||| .r4749
  procedure purge_dp_audit_table(p_err_code    OUT NUMBER,
              p_err_message OUT VARCHAR2) is

=======
  procedure purge_dp_audit_table(p_err_code    OUT NUMBER,
                                 p_err_message OUT VARCHAR2) is
  
>>>>>>> .r4768
<<<<<<< .mine
||||||| .r4749
  begin
    delete from xxom_dp_check_audit xda
     where exists
     (select 1
        from oe_order_headers_all oh
       where oh.header_id = xda.header_id
         and oh.flow_status_code in ('CLOSED', 'CANCELLED'));

    p_err_message := 'SUCCESS: Deleted '||sql%rowcount||' records from Denied Party Audit table';
    p_err_code := 0;

    commit;
  exception when others then
    rollback;
    p_err_code := 2;
    p_err_message := 'ERROR: '||sqlerrm;
  end purge_dp_audit_table;

=======
  begin
    delete from xxom_dp_check_audit xda
     where exists
     (select 1
              from oe_order_headers_all oh
             where oh.header_id = xda.header_id
               and oh.flow_status_code in ('CLOSED', 'CANCELLED'));
  
    p_err_message := 'SUCCESS: Deleted ' || sql%rowcount ||
                     ' records from Denied Party Audit table';
    p_err_code    := 0;
  
    commit;
  exception
    when others then
      rollback;
      p_err_code    := 2;
      p_err_message := 'ERROR: ' || sqlerrm;
  end purge_dp_audit_table;

>>>>>>> .r4768
  ---------------------------------------------------------------------
  -- Ver   When         Who           Descr
  -- ----  -----------  ------------  ---------------------------------
  -- 1.0   27/05/2021   Roman W.      CHG0048579 - OIC integration
  ---------------------------------------------------------------------
  PROCEDURE check_denied_parties(p_order_line_id    NUMBER,
<<<<<<< .mine
		         p_xml_result       OUT VARCHAR2,
		         p_err_code         OUT NUMBER,
		         p_err_message      OUT VARCHAR2,
		         p_denied_code      OUT VARCHAR2,
		         p_risk_country     OUT VARCHAR2,
		         p_bpel_instance_id OUT VARCHAR2,
		         p_hold_flag        OUT VARCHAR2) IS
  
||||||| .r4749
             p_xml_result       OUT VARCHAR2,
             p_err_code         OUT NUMBER,
             p_err_message      OUT VARCHAR2,
             p_denied_code      OUT VARCHAR2,
             p_risk_country     OUT VARCHAR2,
             p_bpel_instance_id OUT VARCHAR2,
             p_hold_flag        OUT VARCHAR2) IS

=======
                                 p_xml_result       OUT VARCHAR2,
                                 p_err_code         OUT NUMBER,
                                 p_err_message      OUT VARCHAR2,
                                 p_denied_code      OUT VARCHAR2,
                                 p_risk_country     OUT VARCHAR2,
                                 p_bpel_instance_id OUT VARCHAR2,
                                 p_hold_flag        OUT VARCHAR2) IS
  
    ------------------------
    --  Local Definition
    ------------------------
    CURSOR c(c_order_line_id NUMBER) IS
      SELECT *
        FROM xxom_dp_locations_v t
       WHERE t.line_id = c_order_line_id;
  
>>>>>>> .r4768
    l_exit_loop_exception EXCEPTION;
<<<<<<< .mine
    CURSOR c IS
      SELECT *
      FROM   xxom_dp_locations_v t
      WHERE  t.line_id = p_order_line_id;
  
||||||| .r4749
    CURSOR c IS
      SELECT *
      FROM   xxom_dp_locations_v t
      WHERE  t.line_id = p_order_line_id;

=======
    l_ship_address VARCHAR2(240);
    l_bill_address VARCHAR2(240);
    ------------------------
    --  Code Section
    ------------------------
>>>>>>> .r4768
  BEGIN
  
    init_globals;
<<<<<<< .mine
  
||||||| .r4749

=======
  
    message('START check_denied_parties(' || p_order_line_id || ')');
>>>>>>> .r4768
    -- not internal
<<<<<<< .mine
    FOR i IN c
    LOOP
    
||||||| .r4749
    FOR i IN c LOOP

=======
    FOR i IN c(p_order_line_id) LOOP
    
      l_ship_address := coalesce(i.ship_city, i.ship_state, '.');
>>>>>>> .r4768
      -- check ship_to location
<<<<<<< .mine
      check_denied_parties(p_reff_id      => p_order_line_id,
		   p_reff_name    => 'SO Line',
		   p_company_name => i.sold_to,
		   p_person_name  => nvl(i.ship_to_contact, '.'),
		   p_address      => coalesce(i.ship_city,
				      i.ship_state,
				      '.'),
		   -- i.ship_to_address2,
		   p_country          => i.ship_to_country,
		   p_xml_result       => p_xml_result,
		   p_err_code         => p_err_code,
		   p_err_message      => p_err_message,
		   p_denied_code      => p_denied_code,
		   p_risk_country     => p_risk_country,
		   p_bpel_instance_id => p_bpel_instance_id,
		   p_hold_flag        => p_hold_flag);
    
||||||| .r4749
      check_denied_parties(p_reff_id      => p_order_line_id,
                           p_reff_name    => 'SO Line',
                           p_company_name => i.sold_to,
                           p_person_name  => nvl(i.ship_to_contact, '.'),
                           p_address      => coalesce(i.ship_city,  i.ship_state, '.'),
                           -- i.ship_to_address2,
                           p_country          => i.ship_to_country,
                           p_xml_result       => p_xml_result,
                           p_err_code         => p_err_code,
                           p_err_message      => p_err_message,
                           p_denied_code      => p_denied_code,
                           p_risk_country     => p_risk_country,
                           p_bpel_instance_id => p_bpel_instance_id,
                           p_hold_flag        => p_hold_flag);

=======
      check_denied_parties(p_reff_id          => p_order_line_id,
                           p_reff_name        => 'SO Line',
                           p_company_name     => i.sold_to,
                           p_person_name      => nvl(i.ship_to_contact, '.'),
                           p_address          => l_ship_address,
                           p_country          => i.ship_to_country,
                           p_xml_result       => p_xml_result,
                           p_err_code         => p_err_code,
                           p_err_message      => p_err_message,
                           p_denied_code      => p_denied_code,
                           p_risk_country     => p_risk_country,
                           p_bpel_instance_id => p_bpel_instance_id,
                           p_hold_flag        => p_hold_flag);
    
      message('1)' || chr(10) || p_xml_result);
>>>>>>> .r4768
      -- save results
      IF p_hold_flag = 'Y' THEN
        RAISE l_exit_loop_exception;
      END IF;
    
      IF nvl(i.ship_to_contact, '.') = nvl(i.invoice_to_contact, '.') AND
         coalesce(i.ship_city, i.ship_state, '.') =
         coalesce(i.bill_city, i.bill_state, '.') AND
         i.ship_to_country = i.invoice_to_country THEN
        CONTINUE;
      ELSE
        l_bill_address := coalesce(i.bill_city, i.bill_state, '.');
        -- check invoice_to location
<<<<<<< .mine
        check_denied_parties(p_reff_id          => p_order_line_id,
		     p_reff_name        => 'SO Line',
		     p_company_name     => i.sold_to,
		     p_person_name      => nvl(i.invoice_to_contact,
				       '.'),
		     p_address          => coalesce(i.bill_city,
					i.bill_state,
					'.'),
		     p_country          => i.invoice_to_country,
		     p_xml_result       => p_xml_result,
		     p_err_code         => p_err_code,
		     p_err_message      => p_err_message,
		     p_denied_code      => p_denied_code,
		     p_risk_country     => p_risk_country,
		     p_bpel_instance_id => p_bpel_instance_id,
		     p_hold_flag        => p_hold_flag);
      
||||||| .r4749
        check_denied_parties(p_reff_id      => p_order_line_id,
                             p_reff_name    => 'SO Line',
                             p_company_name => i.sold_to,
                             p_person_name  => nvl(i.invoice_to_contact, '.'),
                             p_address      => coalesce(i.bill_city, i.bill_state, '.'),
                             p_country          => i.invoice_to_country,
                             p_xml_result       => p_xml_result,
                             p_err_code         => p_err_code,
                             p_err_message      => p_err_message,
                             p_denied_code      => p_denied_code,
                             p_risk_country     => p_risk_country,
                             p_bpel_instance_id => p_bpel_instance_id,
                             p_hold_flag        => p_hold_flag);

=======
        check_denied_parties(p_reff_id          => p_order_line_id,
                             p_reff_name        => 'SO Line',
                             p_company_name     => i.sold_to,
                             p_person_name      => nvl(i.invoice_to_contact,
                                                       '.'),
                             p_address          => l_bill_address,
                             p_country          => i.invoice_to_country,
                             p_xml_result       => p_xml_result,
                             p_err_code         => p_err_code,
                             p_err_message      => p_err_message,
                             p_denied_code      => p_denied_code,
                             p_risk_country     => p_risk_country,
                             p_bpel_instance_id => p_bpel_instance_id,
                             p_hold_flag        => p_hold_flag);
      
        message('2)' || chr(10) || p_xml_result);
      
>>>>>>> .r4768
        IF p_hold_flag = 'Y' THEN
          RAISE l_exit_loop_exception;
        END IF;
      END IF;
    END LOOP;
  EXCEPTION
    WHEN l_exit_loop_exception THEN
      message('EXCEPTION_l_exit_loop_exception xxom_denied_parties_pkg.check_denied_parties( p_order_line_id => ' ||
              p_order_line_id || ')- ' || sqlerrm);
  END check_denied_parties;
    
  ---------------------------------------------------------------------------
  -- check_denied_parties_wf
  -- call from WF for each line  under folowwing restrictions
  --  1.   exclude internal orders ,
  --  2.   only for fdm items
  --
  -- return HOLD/IGNORE

  -- 17.01.12     yuval tal  modify l_risk_country to varchar2(20) from varchar2(5)
  ---------------------------------------------------------------------------
  PROCEDURE check_denied_parties_wf(itemtype  IN VARCHAR2,
<<<<<<< .mine
			itemkey   IN VARCHAR2,
			actid     IN NUMBER,
			funcmode  IN VARCHAR2,
			resultout OUT NOCOPY VARCHAR2) IS
  
||||||| .r4749
      itemkey   IN VARCHAR2,
      actid     IN NUMBER,
      funcmode  IN VARCHAR2,
      resultout OUT NOCOPY VARCHAR2) IS

=======
                                    itemkey   IN VARCHAR2,
                                    actid     IN NUMBER,
                                    funcmode  IN VARCHAR2,
                                    resultout OUT NOCOPY VARCHAR2) IS
  
>>>>>>> .r4768
    --  err_apply_hold_exception EXCEPTION;
  
    l_err_code         NUMBER;
    l_err_message      VARCHAR2(32000);
    l_denied_code      VARCHAR2(5);
    l_risk_country     VARCHAR2(20);
    l_bpel_instance_id NUMBER;
    l_xml_result       VARCHAR2(32000);
    l_hold_flag        VARCHAR2(1);
    l_line_id          NUMBER;
  
  BEGIN
  
    init_globals;
    resultout := wf_engine.eng_completed || ':' || 'IGNORE';
  
    l_line_id := wf_engine.getitemuserkey(itemtype => itemtype,
<<<<<<< .mine
			      itemkey  => itemkey);
  
||||||| .r4749
            itemkey  => itemkey);

=======
                                          itemkey  => itemkey);
  
>>>>>>> .r4768
    xxom_denied_parties_pkg.check_denied_parties(p_order_line_id    => l_line_id,
<<<<<<< .mine
				 p_xml_result       => l_xml_result,
				 p_err_code         => l_err_code,
				 p_err_message      => l_err_message,
				 p_denied_code      => l_denied_code,
				 p_risk_country     => l_risk_country,
				 p_bpel_instance_id => l_bpel_instance_id,
				 p_hold_flag        => l_hold_flag);
  
||||||| .r4749
         p_xml_result       => l_xml_result,
         p_err_code         => l_err_code,
         p_err_message      => l_err_message,
         p_denied_code      => l_denied_code,
         p_risk_country     => l_risk_country,
         p_bpel_instance_id => l_bpel_instance_id,
         p_hold_flag        => l_hold_flag);

=======
                                                 p_xml_result       => l_xml_result,
                                                 p_err_code         => l_err_code,
                                                 p_err_message      => l_err_message,
                                                 p_denied_code      => l_denied_code,
                                                 p_risk_country     => l_risk_country,
                                                 p_bpel_instance_id => l_bpel_instance_id,
                                                 p_hold_flag        => l_hold_flag);
  
>>>>>>> .r4768
    -- save results
    IF l_hold_flag = 'Y' THEN
      wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		        itemkey  => itemkey,
		        aname    => 'DENIED_CODE_DESC',
		        avalue   => g_denied_arr(nvl(l_denied_code,
					 l_risk_country)));
||||||| .r4749
            itemkey  => itemkey,
            aname    => 'DENIED_CODE_DESC',
            avalue   => g_denied_arr(nvl(l_denied_code,
           l_risk_country)));
=======
                                itemkey  => itemkey,
                                aname    => 'DENIED_CODE_DESC',
                                avalue   => g_denied_arr(nvl(l_denied_code,
                                                             l_risk_country)));
>>>>>>> .r4768
    END IF;
  
    wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		      itemkey  => itemkey,
		      aname    => 'RISK_COUNTRY',
		      avalue   => l_risk_country);
  
||||||| .r4749
          itemkey  => itemkey,
          aname    => 'RISK_COUNTRY',
          avalue   => l_risk_country);

=======
                              itemkey  => itemkey,
                              aname    => 'RISK_COUNTRY',
                              avalue   => l_risk_country);
  
>>>>>>> .r4768
    wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		      itemkey  => itemkey,
		      aname    => 'DENIED_CODE',
		      avalue   => l_denied_code);
  
||||||| .r4749
          itemkey  => itemkey,
          aname    => 'DENIED_CODE',
          avalue   => l_denied_code);

=======
                              itemkey  => itemkey,
                              aname    => 'DENIED_CODE',
                              avalue   => l_denied_code);
  
>>>>>>> .r4768
    wf_engine.setitemattrnumber(itemtype => itemtype,
<<<<<<< .mine
		        itemkey  => itemkey,
		        aname    => 'BPEL_ID',
		        avalue   => l_bpel_instance_id);
  
||||||| .r4749
            itemkey  => itemkey,
            aname    => 'BPEL_ID',
            avalue   => l_bpel_instance_id);

=======
                                itemkey  => itemkey,
                                aname    => 'BPEL_ID',
                                avalue   => l_bpel_instance_id);
  
>>>>>>> .r4768
    wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		      itemkey  => itemkey,
		      aname    => 'DP_MESSAGE',
		      avalue   => l_err_message);
  
||||||| .r4749
          itemkey  => itemkey,
          aname    => 'DP_MESSAGE',
          avalue   => l_err_message);

=======
                              itemkey  => itemkey,
                              aname    => 'DP_MESSAGE',
                              avalue   => l_err_message);
  
>>>>>>> .r4768
    IF l_err_code = 1 OR l_hold_flag = 'Y' THEN
      resultout := wf_engine.eng_completed || ':HOLD';
    
    END IF;
  
  EXCEPTION
  
    WHEN OTHERS THEN
      resultout := wf_engine.eng_completed || ':' || 'HOLD';
      wf_core.context('check_denied_parties_wf',
<<<<<<< .mine
	          'xxom_denied_parties_pkg',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          'Others',
	          'check_denied_parties_wf: ' ||
	          
	          SQLERRM);
||||||| .r4749
            'xxom_denied_parties_pkg',
            itemtype,
            itemkey,
            to_char(actid),
            funcmode,
            'Others',
            'check_denied_parties_wf: ' ||

            SQLERRM);
=======
                      'xxom_denied_parties_pkg',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      'Others',
                      'check_denied_parties_wf: ' ||
                      
                      SQLERRM);
>>>>>>> .r4768
      RAISE;
  END;

  ------------------------------------------------------------------------------
  -- Ver   When         Who        Descr
  -- ----  -----------  ---------  ---------------------------------------------
  -- 1.0   14/12/2020   Roman W.   CHG0048579 - OIC
  ------------------------------------------------------------------------------
  procedure check_denied_parties_oic(p_reff_id          IN VARCHAR2,
                                     p_reff_name        IN VARCHAR2,
                                     p_company_name     IN VARCHAR2,
                                     p_person_name      IN VARCHAR2,
                                     p_address          IN VARCHAR2,
                                     p_country          IN VARCHAR2,
                                     p_xml_result       OUT VARCHAR2,
                                     p_denied_code      OUT VARCHAR2,
                                     p_risk_country     OUT VARCHAR2,
                                     p_bpel_instance_id OUT VARCHAR2,
                                     p_hold_flag        OUT VARCHAR2,
                                     p_err_code         OUT NUMBER,
                                     p_err_message      OUT VARCHAR2) is
    --------------------------
    --    Local Definition
    --------------------------
    l_enable_flag VARCHAR2(10);
    l_url         VARCHAR2(500);
    l_wallet_loc  VARCHAR2(500);
    l_wallet_pwd  VARCHAR2(500);
    l_auth_user   VARCHAR2(500);
    l_auth_pwd    VARCHAR2(500);
    l_error_code  VARCHAR2(500);
    l_error_desc  VARCHAR2(500);
  
    l_body          VARCHAR2(5000);
    l_http_request  UTL_HTTP.req;
    l_http_response UTL_HTTP.resp;
    l_text          VARCHAR2(32766);
    l_out_text      VARCHAR2(32766);
    l_skip_dp_hold  VARCHAR2(1);
    --------------------------
    --     Code Section
    --------------------------
  begin
    p_err_code    := 0;
    p_err_message := 'Empty';
    p_hold_flag   := 'N';
  
    xxssys_oic_util_pkg.get_service_details(p_service     => C_SERVICE_NAME,
                                            p_enable_flag => l_enable_flag,
                                            p_url         => l_url,
                                            p_waller_loc  => l_wallet_loc,
                                            p_wallet_pwd  => l_wallet_pwd,
                                            p_auth_user   => l_auth_user,
                                            p_auth_pwd    => l_auth_pwd,
                                            p_error_code  => l_error_code,
                                            p_error_desc  => l_error_desc);
  
    if '0' != l_error_code then
      p_err_code    := 1;
      p_err_message := l_error_desc;
      return;
    end if;
  
    message('p_url : ' || l_url);
    message('p_waller_loc : ' || l_wallet_loc);
    message('p_wallet_pwd : ' || l_wallet_pwd);
    message('p_auth_user : ' || l_auth_user);
    --  message('p_auth_pwd : ' || l_auth_pwd);
  
    l_body := ('<?xml version="1.0" encoding="UTF-8"?>' || chr(10) ||
              '<deniedPartiesWSProcessRequest>' || chr(10) || '<sSecno>' ||
              fnd_profile.value('XXOM_DP_SITE_SECNO') || '</sSecno>' ||
              chr(10) || '<sPassword>' ||
              fnd_profile.value('XXOM_DP_SITE_PASSWORD') || '</sPassword>' ||
              chr(10) || '<sOptionalID />' || chr(10) || '<refID>' ||
              p_reff_id || '</refID>' || chr(10) || '<refName>' ||
              p_reff_name || '</refName>' || chr(10) || '<sName>' ||
              htf.escape_sc(p_person_name) || '</sName>' || chr(10) ||
              '<sCompany>' || htf.escape_sc(p_company_name) ||
              '</sCompany>' || chr(10) || '<sAddress>' ||
              htf.escape_sc(nvl(p_address, '.')) || '</sAddress>' ||
              chr(10) || '<sCountry>' || p_country || '</sCountry>' ||
              chr(10) || '<sModes>' ||
              fnd_profile.value('XXOM_DP_SITE_SEARCH_MODE') || '</sModes>' ||
              chr(10) || '<sRPSGroupBypass>' ||
              fnd_profile.value('XXOM_DP_SITE_GROUP_BYPASS') ||
              '</sRPSGroupBypass>' || chr(10) ||
              '</deniedPartiesWSProcessRequest>');
  
    message('BODY : ' || l_body);
  
    utl_http.set_wallet(l_wallet_loc, l_wallet_pwd);
    l_http_request := utl_http.begin_request(l_url, 'POST');
  
    ------ Set Auth -------
    utl_http.set_authentication(l_http_request, l_auth_user, l_auth_pwd);
    ------ Set HEADER -----
    utl_http.set_header(l_http_request, 'Content-Length', length(l_body));
    utl_http.set_header(l_http_request, 'Content-Type', 'application/xml');
    ------ Set Body to request -----
    UTL_HTTP.SET_BODY_CHARSET(r => l_http_request, charset => 'UTF-8');
    utl_http.write_text(r => l_http_request, data => l_body);
  
    ------ Get Response ------------
    l_http_response := UTL_HTTP.get_response(l_http_request);
  
    utl_http.read_text(l_http_response, l_text, 32766);
  
    message('RESPONSE : ' || l_text);
  
    utl_http.end_response(l_http_response);
  
    XXSSYS_OIC_UTIL_PKG.html_parser(p_in_text    => l_text,
                                    p_out_text   => l_out_text,
                                    p_error_code => l_error_code,
                                    p_error_desc => l_error_desc);
  
    p_xml_result := l_text;
  
    if instr(upper(l_out_text), 'ERROR') > 0 then
      p_hold_flag   := 'Y';
      p_err_code    := 1;
      p_err_message := 'SERVICE_RESPONSE_ERROR : ' || l_out_text;
      return;
    end if;
  
    select xt.errCode, xt.oicInstanceId, xt.webResult
      into p_err_code, p_bpel_instance_id, p_risk_country
      from XMLTABLE('/deniedPartiesWSProcessResponse' PASSING
                    XMLTYPE.createXML(l_text) COLUMNS errCode VARCHAR2(300) PATH
                    'errCode',
                    oicInstanceId VARCHAR2(300) PATH 'oicInstanceId',
                    webResult VARCHAR2(300) PATH 'webResult') xt;
  
    IF p_err_code = 0 THEN
    
      parse_result(p_risk_country,
                   p_err_code,
                   p_err_message,
                   p_denied_code,
                   p_risk_country);
    
    END IF;
  
    IF p_risk_country = 'RISK_COUNTRY' THEN
      p_err_code    := 0;
      p_err_message := p_risk_country;
    END IF;
  
    BEGIN
    
      SELECT flvd.skip_dp_hold
        INTO l_skip_dp_hold
        FROM fnd_lookup_values_dfv flvd, fnd_lookup_values flv
       WHERE flv.lookup_type = 'XXSERVICE_COUNTRIES_SECURITY'
         AND flv.lookup_code = p_country
         AND flvd.rowid = flv.rowid
            --  and   flvd.skip_dp_hold ='Y'
         AND flv.language = 'US';
    
    EXCEPTION
      WHEN no_data_found THEN
        l_skip_dp_hold := 'N';
    END;
  
    IF p_denied_code IN ('_R', 'TR', 'DR') OR
       (p_risk_country = 'RISK_COUNTRY' AND nvl(l_skip_dp_hold, 'N') = 'N') /* Added by Piyali on 23/11/17  for CHG0041843-DP Hold */
       OR p_err_code = 1 THEN
      p_hold_flag := 'Y';
    END IF;
  
  exception
    WHEN UTL_HTTP.end_of_body then
      p_err_code    := 1;
      p_err_message := 'EXCEPTION_UTL_HTTP.END_OF_BODY xxom_denied_parties_pkg.check_denied_parties_oic(' ||
                       p_reff_id || ',' || p_reff_name || ',' ||
                       p_company_name || ',' || p_person_name || ',' ||
                       p_address || ',' || p_country || ') - ' || sqlerrm;
      UTL_HTTP.end_response(l_http_response);
      message(p_err_message);
    when others then
      p_err_code    := 1;
      p_err_message := 'EXCEPTION_OTHERS xxom_denied_parties_pkg.check_denied_parties_oic(' ||
                       p_reff_id || ',' || p_reff_name || ',' ||
                       p_company_name || ',' || p_person_name || ',' ||
                       p_address || ',' || p_country || ') - ' || sqlerrm;
      message(p_err_message);
    
  end check_denied_parties_oic;
  -------------------------------------
  -- check_denied_parties
  -- callbpel xxDeniedPartiesWS
  -- parse results for alert msg and risk country
  --------------------------------------------------------------------
  --  name:            check_denied_parties
  --  create by:       yuval tal
  --------------------------------------------------------------------
  --  purpose :        support OM order process
  --------------------------------------------------------------------
  --  Ver   When        Who               Desc
  --  ----  ----------  ----------------  -------------------------------
  --  1.0   10.3.14      yuval tal        CHG0031404 - modify check_denied_parties support new bpel server
  --  1.1   19.04.16    yuval tal         CHG0037918 - support soa 12c migration
  --                                       out
  --                                           p_hold_flag : Y/N is Dp check return Hold Alert
  --                                           p_risk_country Y/N
  --                                           p_denied_code  :
  --                                                            TR (Triple Red - Name, Company,Address, and Country found),
  --                                                            DR (Double Red - Name or Company and Address and Country found),
  --                                                            _R (Red - Name or Company and Country found),
  --                                                            _Y (Yellow ? Name or Company found).
  --                                           p_bpel_instance_id : bpel reff number
  --                                           p_err_code 0 ok / 1 fail
  --                                           p_xml_result  : part of bpel xml result from WS
  --  1.2   23.11.17     Piyali Bhowmick  CHG0041843-DP Hold
  --                                         Hold will not be applied in case the DFF ?Skip DP Hold? =?Y? in XXSERVICE_COUNTRIES_SECURITY lookup.
  --                                         support host failure route to secondary server
  --                     yuval tal           support failover of soa server to route to secondary one
  --  1.3   18.02.2018   Roman W.         INC0114465 replace ' y ' to 'Y'
  --  1.4   14/12/2020   Roman W.         CHG0048579 - OIC
  -------------------------------------------------------------------------
  PROCEDURE check_denied_parties(p_reff_id          VARCHAR2,
<<<<<<< .mine
		         p_reff_name        VARCHAR2,
		         p_company_name     VARCHAR2,
		         p_person_name      VARCHAR2,
		         p_address          VARCHAR2,
		         p_country          VARCHAR2,
		         p_xml_result       OUT VARCHAR2,
		         p_err_code         OUT NUMBER,
		         p_err_message      OUT VARCHAR2,
		         p_denied_code      OUT VARCHAR2,
		         p_risk_country     OUT VARCHAR2,
		         p_bpel_instance_id OUT VARCHAR2,
		         p_hold_flag        OUT VARCHAR2) IS
  
||||||| .r4749
             p_reff_name        VARCHAR2,
             p_company_name     VARCHAR2,
             p_person_name      VARCHAR2,
             p_address          VARCHAR2,
             p_country          VARCHAR2,
             p_xml_result       OUT VARCHAR2,
             p_err_code         OUT NUMBER,
             p_err_message      OUT VARCHAR2,
             p_denied_code      OUT VARCHAR2,
             p_risk_country     OUT VARCHAR2,
             p_bpel_instance_id OUT VARCHAR2,
             p_hold_flag        OUT VARCHAR2) IS

=======
                                 p_reff_name        VARCHAR2,
                                 p_company_name     VARCHAR2,
                                 p_person_name      VARCHAR2,
                                 p_address          VARCHAR2,
                                 p_country          VARCHAR2,
                                 p_xml_result       OUT VARCHAR2,
                                 p_err_code         OUT NUMBER,
                                 p_err_message      OUT VARCHAR2,
                                 p_denied_code      OUT VARCHAR2,
                                 p_risk_country     OUT VARCHAR2,
                                 p_bpel_instance_id OUT VARCHAR2,
                                 p_hold_flag        OUT VARCHAR2) IS
  
>>>>>>> .r4768
    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.call;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    l_string_type_qname sys.utl_dbws.qname;
    l_skip_dp_hold      VARCHAR2(1); -- Added by Piyali on 23/11/17  for CHG0041843-DP Hold
  
    l_result_clob CLOB;
    TYPE t_server_host_tab IS TABLE OF VARCHAR2(200) INDEX BY BINARY_INTEGER; --CHG0041843
  
    l_server_host_tab t_server_host_tab; --CHG0041843
    l_host            VARCHAR2(250); --CHG0041843
  
    l_oic_enable_flag VARCHAR2(10);
    l_oic_url         VARCHAR2(240);
    l_oic_waller_loc  VARCHAR2(240);
    l_oic_wallet_pwd  VARCHAR2(240);
    l_oic_auth_user   VARCHAR2(240);
    l_oic_auth_pwd    VARCHAR2(240);
    l_error_code      VARCHAR2(10);
    l_error_desc      VARCHAR2(1000);
    l_body            VARCHAR2(32000);
  BEGIN
  
    p_hold_flag := 'N';
    -- init out param
  
    p_xml_result       := '';
    p_err_code         := 0;
    p_err_message      := '';
    p_denied_code      := '';
    p_risk_country     := '';
    p_bpel_instance_id := '';
<<<<<<< .mine
    --
    service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxDeniedPartiesWS',
				 'xxDeniedPartiesWS');
    l_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
				 'string');
    service_            := sys.utl_dbws.create_service(service_qname);
    call_               := sys.utl_dbws.create_call(service_);
  
    --CHG0041843
    -- set host primary and alt
    -- srv2 profile XXSSYS_BPEL_HOST_<env>_SRV2
    -- srv1 profile  XXOBJT_BPEL_HOST_<env>_11G
    l_server_host_tab(1) := CASE fnd_profile.value('XXSSYS_DP_SOA_SRV_NUM')
		      WHEN '1' THEN
		       xxobjt_bpel_utils_pkg.get_bpel_host_srv1
		      ELSE
		       xxobjt_bpel_utils_pkg.get_bpel_host_srv2
		    END;
    l_server_host_tab(2) := CASE fnd_profile.value('XXSSYS_DP_SOA_SRV_NUM')
		      WHEN '1' THEN
		       xxobjt_bpel_utils_pkg.get_bpel_host_srv2
		      ELSE
		       xxobjt_bpel_utils_pkg.get_bpel_host_srv1
		    END;
  
    FOR i IN 1 .. l_server_host_tab.count
    LOOP
      BEGIN
        l_host := l_server_host_tab(i);
      
        --        dbms_output.put_line('working with host -' || l_host);
      
        sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
        sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
        sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
        sys.utl_dbws.set_property(call_,
		          'ENCODINGSTYLE_URI',
		          'http://schemas.xmlsoap.org/soap/encoding/');
      
        sys.utl_dbws.set_return_type(call_, l_string_type_qname);
      
        -- set host
        sys.utl_dbws.set_target_endpoint_address(call_,
				 l_host ||
				 '/soa-infra/services/hz/hz_DeniedPartiesWSCmp/client');
      
        -- Set the input
        -- sSecno sPassword ,smodes, sOptionalID , sRPSGroupBypass are set in bpel process
      
        request := sys.xmltype('<ns1:hz_DeniedPartiesWSCmpProcessRequest xmlns:ns1="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp">' ||
		       '<ns1:sSecno>' ||
		       fnd_profile.value('XXOM_DP_SITE_SECNO') ||
		       '</ns1:sSecno><ns1:sPassword>' ||
		       fnd_profile.value('XXOM_DP_SITE_PASSWORD') ||
		       '</ns1:sPassword> <ns1:sOptionalID></ns1:sOptionalID><ns1:refID>' ||
		       p_reff_id || '</ns1:refID> <ns1:refName>' ||
		       p_reff_name || '</ns1:refName><ns1:sName>' ||
		       htf.escape_sc(p_person_name) ||
		       '</ns1:sName>' || '<ns1:sCompany >' ||
		       htf.escape_sc(p_company_name) ||
		       ' </ns1:sCompany><ns1:sAddress>' ||
		       htf.escape_sc(nvl(p_address, '.')) ||
		       '</ns1:sAddress><ns1:sCountry>' || p_country ||
		       '</ns1:sCountry><ns1:sModes>' ||
		       fnd_profile.value('XXOM_DP_SITE_SEARCH_MODE') ||
		       '</ns1:sModes><ns1:sRPSGroupBypass>' ||
		       fnd_profile.value('XXOM_DP_SITE_GROUP_BYPASS') ||
		       '</ns1:sRPSGroupBypass>' ||
		       '</ns1:hz_DeniedPartiesWSCmpProcessRequest>');
      
        response := sys.utl_dbws.invoke(call_, request);
        sys.utl_dbws.release_call(call_);
        sys.utl_dbws.release_service(service_);
        p_xml_result := dbms_lob.substr(response.getclobval(), 2000, 1);
      
        -- l_result_clob :=  response.getclobval();
      
        /*    SELECT extractvalue(response, '/xxDeniedPartiesWSProcessResponse/webResult/text()', 'xmlns="http://xmlns.oracle.com/xxDeniedPartiesWS"')
             .getclobval()
        INTO l_result_clob
        FROM dual;*/
      
        --hz_DeniedPartiesWSCmpProcessResponse
      
        SELECT extract(response, '/hz_DeniedPartiesWSCmpProcessResponse/webResult/text()', 'xmlns="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp"')
	   .getclobval(),
	   extract(response, '/hz_DeniedPartiesWSCmpProcessResponse/errCode/text()', 'xmlns="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp"')
	   .getstringval(),
	   extract(response, '/hz_DeniedPartiesWSCmpProcessResponse/errMessage/text()', 'xmlns="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp"')
	   .getstringval(),
	   extract(response, '/hz_DeniedPartiesWSCmpProcessResponse/bpelInstanceId/text()', 'xmlns="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp"')
	   .getstringval()
        INTO   l_result_clob,
	   p_err_code,
	   p_err_message,
	   p_bpel_instance_id
        FROM   dual;
      
        -- check bpel
      
        IF p_err_code = 0 THEN
          parse_result(l_result_clob,
	           p_err_code,
	           p_err_message,
	           p_denied_code,
	           p_risk_country);
        END IF;
      
        -- Added by Piyali on 23/11/17  for CHG0041843-DP Hold
        -- Hold will not be applied in case the DFF ?Skip DP Hold? =?Y? in XXSERVICE_COUNTRIES_SECURITY lookup.
||||||| .r4749
    --
    service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxDeniedPartiesWS',
         'xxDeniedPartiesWS');
    l_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
         'string');
    service_            := sys.utl_dbws.create_service(service_qname);
    call_               := sys.utl_dbws.create_call(service_);

    --CHG0041843
    -- set host primary and alt
    -- srv2 profile XXSSYS_BPEL_HOST_<env>_SRV2
    -- srv1 profile  XXOBJT_BPEL_HOST_<env>_11G
    l_server_host_tab(1) := CASE fnd_profile.value('XXSSYS_DP_SOA_SRV_NUM')
          WHEN '1' THEN
           xxobjt_bpel_utils_pkg.get_bpel_host_srv1
          ELSE
           xxobjt_bpel_utils_pkg.get_bpel_host_srv2
        END;
    l_server_host_tab(2) := CASE fnd_profile.value('XXSSYS_DP_SOA_SRV_NUM')
          WHEN '1' THEN
           xxobjt_bpel_utils_pkg.get_bpel_host_srv2
          ELSE
           xxobjt_bpel_utils_pkg.get_bpel_host_srv1
        END;

    FOR i IN 1 .. l_server_host_tab.count LOOP
      BEGIN
        l_host := l_server_host_tab(i);

        --        dbms_output.put_line('working with host -' || l_host);

        sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
        sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
        sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
        sys.utl_dbws.set_property(call_,
              'ENCODINGSTYLE_URI',
              'http://schemas.xmlsoap.org/soap/encoding/');

        sys.utl_dbws.set_return_type(call_, l_string_type_qname);

        -- set host
        sys.utl_dbws.set_target_endpoint_address(call_,
         l_host ||
         '/soa-infra/services/hz/hz_DeniedPartiesWSCmp/client');

        -- Set the input
        -- sSecno sPassword ,smodes, sOptionalID , sRPSGroupBypass are set in bpel process

        request := sys.xmltype('<ns1:hz_DeniedPartiesWSCmpProcessRequest xmlns:ns1="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp">' ||
                               '<ns1:sSecno>' || fnd_profile.value('XXOM_DP_SITE_SECNO') ||
                               '</ns1:sSecno><ns1:sPassword>' || fnd_profile.value('XXOM_DP_SITE_PASSWORD') ||
                               '</ns1:sPassword> <ns1:sOptionalID></ns1:sOptionalID><ns1:refID>' || p_reff_id ||
                               '</ns1:refID> <ns1:refName>' || p_reff_name ||
                               '</ns1:refName><ns1:sName>' || htf.escape_sc(p_person_name) ||
                               '</ns1:sName>' || '<ns1:sCompany >' || htf.escape_sc(p_company_name) ||
                               ' </ns1:sCompany><ns1:sAddress>' || htf.escape_sc(nvl(p_address, '.')) ||
                               '</ns1:sAddress><ns1:sCountry>' || p_country ||
                               '</ns1:sCountry><ns1:sModes>' || fnd_profile.value('XXOM_DP_SITE_SEARCH_MODE') ||
                               '</ns1:sModes><ns1:sRPSGroupBypass>' || fnd_profile.value('XXOM_DP_SITE_GROUP_BYPASS') ||
                               '</ns1:sRPSGroupBypass>' || '</ns1:hz_DeniedPartiesWSCmpProcessRequest>');

        response := sys.utl_dbws.invoke(call_, request);
        sys.utl_dbws.release_call(call_);
        sys.utl_dbws.release_service(service_);
        p_xml_result := dbms_lob.substr(response.getclobval(), 2000, 1);

        -- l_result_clob :=  response.getclobval();

        /*    SELECT extractvalue(response, '/xxDeniedPartiesWSProcessResponse/webResult/text()', 'xmlns="http://xmlns.oracle.com/xxDeniedPartiesWS"')
             .getclobval()
        INTO l_result_clob
        FROM dual;*/

        --hz_DeniedPartiesWSCmpProcessResponse

        SELECT extract(response, '/hz_DeniedPartiesWSCmpProcessResponse/webResult/text()', 'xmlns="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp"').getclobval(),
               extract(response, '/hz_DeniedPartiesWSCmpProcessResponse/errCode/text()', 'xmlns="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp"').getstringval(),
               extract(response, '/hz_DeniedPartiesWSCmpProcessResponse/errMessage/text()', 'xmlns="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp"').getstringval(),
               extract(response, '/hz_DeniedPartiesWSCmpProcessResponse/bpelInstanceId/text()', 'xmlns="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp"').getstringval()
        INTO   l_result_clob,
               p_err_code,
               p_err_message,
               p_bpel_instance_id
        FROM   dual;

        -- check bpel

        IF p_err_code = 0 THEN
          parse_result(l_result_clob,
                       p_err_code,
                       p_err_message,
                       p_denied_code,
                       p_risk_country);
        END IF;

        -- Added by Piyali on 23/11/17  for CHG0041843-DP Hold
        -- Hold will not be applied in case the DFF ?Skip DP Hold? =?Y? in XXSERVICE_COUNTRIES_SECURITY lookup.
=======
  
    -- Added By Roman W. 14/12/2020 CHG0048579
    l_oic_enable_flag := XXSSYS_OIC_UTIL_PKG.get_service_oic_enable_flag(p_service => C_SERVICE_NAME);
  
    if 0 != p_err_code then
      return;
    end if;
  
    if 'Y' = l_oic_enable_flag then
      check_denied_parties_oic(p_reff_id          => p_reff_id,
                               p_reff_name        => p_reff_name,
                               p_company_name     => p_company_name,
                               p_person_name      => p_person_name,
                               p_address          => p_address,
                               p_country          => p_country,
                               p_xml_result       => p_xml_result,
                               p_denied_code      => p_denied_code,
                               p_risk_country     => p_risk_country,
                               p_bpel_instance_id => p_bpel_instance_id,
                               p_hold_flag        => p_hold_flag,
                               p_err_code         => p_err_code,
                               p_err_message      => p_err_message);
    
    else
      service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxDeniedPartiesWS',
                                                   'xxDeniedPartiesWS');
      l_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
                                                   'string');
      service_            := sys.utl_dbws.create_service(service_qname);
      call_               := sys.utl_dbws.create_call(service_);
    
      --CHG0041843
      -- set host primary and alt
      -- srv2 profile XXSSYS_BPEL_HOST_<env>_SRV2
      -- srv1 profile  XXOBJT_BPEL_HOST_<env>_11G
      l_server_host_tab(1) := CASE
                               fnd_profile.value('XXSSYS_DP_SOA_SRV_NUM')
                                WHEN '1' THEN
                                 xxobjt_bpel_utils_pkg.get_bpel_host_srv1
                                ELSE
                                 xxobjt_bpel_utils_pkg.get_bpel_host_srv2
                              END;
      l_server_host_tab(2) := CASE
                               fnd_profile.value('XXSSYS_DP_SOA_SRV_NUM')
                                WHEN '1' THEN
                                 xxobjt_bpel_utils_pkg.get_bpel_host_srv2
                                ELSE
                                 xxobjt_bpel_utils_pkg.get_bpel_host_srv1
                              END;
    
      FOR i IN 1 .. l_server_host_tab.count LOOP
>>>>>>> .r4768
        BEGIN
<<<<<<< .mine
        
          SELECT flvd.skip_dp_hold
          INTO   l_skip_dp_hold
          FROM   fnd_lookup_values_dfv flvd,
	     fnd_lookup_values     flv
          WHERE  flv.lookup_type = 'XXSERVICE_COUNTRIES_SECURITY'
          AND    flv.lookup_code = p_country
          AND    flvd.rowid = flv.rowid
	    --  and   flvd.skip_dp_hold ='Y'
          AND    flv.language = 'US';
        
||||||| .r4749

          SELECT flvd.skip_dp_hold
          INTO   l_skip_dp_hold
          FROM   fnd_lookup_values_dfv flvd
             ,   fnd_lookup_values     flv
          WHERE  flv.lookup_type = 'XXSERVICE_COUNTRIES_SECURITY'
          AND    flv.lookup_code = p_country
          AND    flvd.rowid = flv.rowid
      --  and   flvd.skip_dp_hold ='Y'
          AND    flv.language = 'US';

=======
          l_host := l_server_host_tab(i);
        
          --        dbms_output.put_line('working with host -' || l_host);
        
          sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
          sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
          sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
          sys.utl_dbws.set_property(call_,
                                    'ENCODINGSTYLE_URI',
                                    'http://schemas.xmlsoap.org/soap/encoding/');
        
          sys.utl_dbws.set_return_type(call_, l_string_type_qname);
        
          -- set host
          sys.utl_dbws.set_target_endpoint_address(call_,
                                                   l_host ||
                                                   '/soa-infra/services/hz/hz_DeniedPartiesWSCmp/client');
        
          -- Set the input
          -- sSecno sPassword ,smodes, sOptionalID , sRPSGroupBypass are set in bpel process
        
          request := sys.xmltype('<ns1:hz_DeniedPartiesWSCmpProcessRequest xmlns:ns1="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp">' ||
                                 '<ns1:sSecno>' ||
                                 fnd_profile.value('XXOM_DP_SITE_SECNO') ||
                                 '</ns1:sSecno><ns1:sPassword>' ||
                                 fnd_profile.value('XXOM_DP_SITE_PASSWORD') ||
                                 '</ns1:sPassword> <ns1:sOptionalID></ns1:sOptionalID><ns1:refID>' ||
                                 p_reff_id || '</ns1:refID> <ns1:refName>' ||
                                 p_reff_name || '</ns1:refName><ns1:sName>' ||
                                 htf.escape_sc(p_person_name) ||
                                 '</ns1:sName>' || '<ns1:sCompany >' ||
                                 htf.escape_sc(p_company_name) ||
                                 ' </ns1:sCompany><ns1:sAddress>' ||
                                 htf.escape_sc(nvl(p_address, '.')) ||
                                 '</ns1:sAddress><ns1:sCountry>' ||
                                 p_country || '</ns1:sCountry><ns1:sModes>' ||
                                 fnd_profile.value('XXOM_DP_SITE_SEARCH_MODE') ||
                                 '</ns1:sModes><ns1:sRPSGroupBypass>' ||
                                 fnd_profile.value('XXOM_DP_SITE_GROUP_BYPASS') ||
                                 '</ns1:sRPSGroupBypass>' ||
                                 '</ns1:hz_DeniedPartiesWSCmpProcessRequest>');
        
          response := sys.utl_dbws.invoke(call_, request);
          sys.utl_dbws.release_call(call_);
          sys.utl_dbws.release_service(service_);
          p_xml_result := dbms_lob.substr(response.getclobval(), 2000, 1);
          message('--------------- p_result_clob ----------------');
          message(dbms_lob.substr(lob_loc => p_xml_result));
          message('--------------- p_result_clob ----------------');
          -- l_result_clob :=  response.getclobval();
        
          /*    SELECT extractvalue(response, '/xxDeniedPartiesWSProcessResponse/webResult/text()', 'xmlns="http://xmlns.oracle.com/xxDeniedPartiesWS"')
               .getclobval()
          INTO l_result_clob
          FROM dual;*/
        
          --hz_DeniedPartiesWSCmpProcessResponse
        
          SELECT extract(response, '/hz_DeniedPartiesWSCmpProcessResponse/webResult/text()', 'xmlns="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp"')
                 .getclobval(),
                 extract(response, '/hz_DeniedPartiesWSCmpProcessResponse/errCode/text()', 'xmlns="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp"')
                 .getstringval(),
                 extract(response, '/hz_DeniedPartiesWSCmpProcessResponse/errMessage/text()', 'xmlns="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp"')
                 .getstringval(),
                 extract(response, '/hz_DeniedPartiesWSCmpProcessResponse/bpelInstanceId/text()', 'xmlns="http://xmlns.oracle.com/hz_DeniedPartiesWSCmp"')
                 .getstringval()
            INTO l_result_clob,
                 p_err_code,
                 p_err_message,
                 p_bpel_instance_id
            FROM dual;
        
          -- check bpel
        
          IF p_err_code = 0 THEN
            message('--------------- l_result_clob ----------------');
            message(dbms_lob.substr(lob_loc => l_result_clob));
            message('--------------- l_result_clob ----------------');
          
            parse_result(l_result_clob,
                         p_err_code,
                         p_err_message,
                         p_denied_code,
                         p_risk_country);
          
            message('RW) l_result_clob : ' || l_result_clob);
            message('RW) p_err_code : ' || p_err_code);
            message('RW) p_err_message : ' || p_err_message);
            message('RW) p_denied_code : ' || p_denied_code);
            message('RW) p_risk_country : ' || p_risk_country);
          END IF;
        
          -- Added by Piyali on 23/11/17  for CHG0041843-DP Hold
          -- Hold will not be applied in case the DFF ?Skip DP Hold? =?Y? in XXSERVICE_COUNTRIES_SECURITY lookup.
          BEGIN
          
            SELECT flvd.skip_dp_hold
              INTO l_skip_dp_hold
              FROM fnd_lookup_values_dfv flvd, fnd_lookup_values flv
             WHERE flv.lookup_type = 'XXSERVICE_COUNTRIES_SECURITY'
               AND flv.lookup_code = p_country
               AND flvd.rowid = flv.rowid
                  --  and   flvd.skip_dp_hold ='Y'
               AND flv.language = 'US';
          
          EXCEPTION
            WHEN no_data_found THEN
              l_skip_dp_hold := 'N';
          END;
        
          IF p_denied_code IN ('_R', 'TR', 'DR') OR
             (p_risk_country = 'RISK_COUNTRY' AND
             nvl(l_skip_dp_hold, 'N') = 'N') /* Added by Piyali on 23/11/17  for CHG0041843-DP Hold */
             OR p_err_code = 1 THEN
            p_hold_flag := 'Y';
            --    dbms_output.put_line('BAD');
            --  ELSE
            --  dbms_output.put_line('OK');
          END IF;
          ------------------------
        
          -- chk dp
          IF p_err_code = 0 THEN
            EXIT;
          END IF;
        
>>>>>>> .r4768
        EXCEPTION
<<<<<<< .mine
          WHEN no_data_found THEN
	l_skip_dp_hold := 'N';
||||||| .r4749
          WHEN no_data_found THEN
            l_skip_dp_hold := 'N';
=======
          WHEN OTHERS THEN
            IF SQLCODE = -29532 AND i = 2 THEN
              p_hold_flag   := 'Y';
              p_err_code    := 1;
              p_err_message := 'backup server not responding  SQLCODE = ' ||
                               SQLCODE || ' ' || SQLERRM;
            
            ELSIF SQLCODE = -29532 THEN
              dbms_output.put_line('server not responding ' || l_host);
              CONTINUE;
            ELSE
              -- set flags
              -- Rem By R.W. 18-02-2018 p_hold_flag   := ' y ';
              p_hold_flag   := 'Y'; --INC0114465
              p_err_code    := 1;
              p_err_message := 'Error IN check_denied_parties SQLCODE = ' ||
                               SQLCODE || ' ' || SQLERRM;
              EXIT;
            END IF;
>>>>>>> .r4768
        END;
<<<<<<< .mine
      
        IF p_denied_code IN ('_R', 'TR', 'DR') OR
           (p_risk_country = 'RISK_COUNTRY' AND
           nvl(l_skip_dp_hold, 'N') = 'N') /* Added by Piyali on 23/11/17  for CHG0041843-DP Hold */
           OR p_err_code = 1 THEN
          p_hold_flag := 'Y';
          --    dbms_output.put_line('BAD');
          --  ELSE
          --  dbms_output.put_line('OK');
        END IF;
        ------------------------
      
        -- chk dp
        IF p_err_code = 0 THEN
          EXIT;
        END IF;
      
      EXCEPTION
        WHEN OTHERS THEN
          IF SQLCODE = -29532 AND i = 2 THEN
	p_hold_flag   := 'Y';
	p_err_code    := 1;
	p_err_message := 'backup server not responding  SQLCODE = ' ||
		     SQLCODE || ' ' || SQLERRM;
          
          ELSIF SQLCODE = -29532 THEN
	dbms_output.put_line('server not responding ' || l_host);
	CONTINUE;
          ELSE
	-- set flags
	-- Rem By R.W. 18-02-2018 p_hold_flag   := ' y ';
	p_hold_flag   := 'Y'; --INC0114465
	p_err_code    := 1;
	p_err_message := 'Error IN check_denied_parties SQLCODE = ' ||
		     SQLCODE || ' ' || SQLERRM;
	EXIT;
          END IF;
      END;
    END LOOP;
  
||||||| .r4749

        IF p_denied_code IN ('_R', 'TR', 'DR') OR (p_risk_country = 'RISK_COUNTRY'
          AND nvl(l_skip_dp_hold, 'N') = 'N') /* Added by Piyali on 23/11/17  for CHG0041843-DP Hold */ OR p_err_code = 1 THEN
          p_hold_flag := 'Y';
          --    dbms_output.put_line('BAD');
          --  ELSE
          --  dbms_output.put_line('OK');
        END IF;
        ------------------------

        -- chk dp
        IF p_err_code = 0 THEN
          EXIT;
        END IF;

      EXCEPTION
        WHEN OTHERS THEN
          IF SQLCODE = -29532 AND i = 2 THEN
            p_hold_flag   := 'Y';
            p_err_code    := 1;
            p_err_message := 'backup server not responding  SQLCODE = ' ||  SQLCODE || ' ' || SQLERRM;

          ELSIF  SQLCODE = -29532 THEN
            dbms_output.put_line('server not responding ' || l_host);
            CONTINUE;
          ELSE
            -- set flags
            -- Rem By R.W. 18-02-2018 p_hold_flag   := ' y ';
            p_hold_flag   := 'Y'; --INC0114465
            p_err_code    := 1;
            p_err_message := 'Error IN check_denied_parties SQLCODE = ' || SQLCODE || ' ' || SQLERRM;
            EXIT;
          END IF;
      END;
    END LOOP;

=======
      END LOOP;
    end if;
>>>>>>> .r4768
    -- end CHG0031404
  
  EXCEPTION
    WHEN OTHERS THEN
      -- Rem By R.W. 18-02-2018 p_hold_flag   := ' y ';
      p_hold_flag   := 'Y'; --INC0114465
      p_err_code    := 1;
<<<<<<< .mine
      p_err_message := 'error IN check_denied_parties :SQLCODE = ' ||
	           SQLCODE || ' ' || SQLERRM;
||||||| .r4749
      p_err_message := 'error IN check_denied_parties :SQLCODE = ' || SQLCODE || ' ' || SQLERRM;
=======
      p_err_message := 'error IN check_denied_parties :SQLCODE = ' ||
                       SQLCODE || ' ' || SQLERRM;
>>>>>>> .r4768
      --  dbms_output.put_line(p_err_message);
  END;

  -----------------------------------------
  -- parse_result
  --
  --   TR (Triple Red - Name, Company,Address, and Country found),
  --   DR (Double Red - Name or Company and Address and Country found),
  --   _R (Red - Name or Company and Country found),
  --   _Y (Yellow ? Name or Company found).
  ------------------------------------------

  PROCEDURE parse_result(p_result       CLOB,
<<<<<<< .mine
		 p_err_code     OUT NUMBER,
		 p_err_message  OUT VARCHAR2,
		 p_denied_code  OUT VARCHAR2,
		 p_risk_country OUT VARCHAR2) IS
  
||||||| .r4749
     p_err_code     OUT NUMBER,
     p_err_message  OUT VARCHAR2,
     p_denied_code  OUT VARCHAR2,
     p_risk_country OUT VARCHAR2) IS

=======
                         p_err_code     OUT NUMBER,
                         p_err_message  OUT VARCHAR2,
                         p_denied_code  OUT VARCHAR2,
                         p_risk_country OUT VARCHAR2) IS
  
>>>>>>> .r4768
    l_clob   CLOB;
    l_text   VARCHAR2(32767);
    l_inx1   NUMBER;
    l_inx2   NUMBER := -1;
    l_seq    NUMBER := 0;
    l_string VARCHAR2(32000);
  
    xx_exception EXCEPTION;
  
    CURSOR c(c_string VARCHAR2) IS
      SELECT *
<<<<<<< .mine
      FROM   (SELECT TRIM(substr(txt,
		         instr(txt, '|', 1, LEVEL) + 1,
		         instr(txt, '|', 1, LEVEL + 1) -
		         instr(txt, '|', 1, LEVEL) - 1)) AS token
	  FROM   (SELECT '|' || c_string || '|' AS txt
	          FROM   dual)
	  CONNECT BY LEVEL <=
		 length(txt) - length(REPLACE(txt, '|', '')) - 1);
  
||||||| .r4749
      FROM   (SELECT TRIM(substr(txt,
             instr(txt, '|', 1, LEVEL) + 1,
             instr(txt, '|', 1, LEVEL + 1) -
             instr(txt, '|', 1, LEVEL) - 1)) AS token
    FROM   (SELECT '|' || c_string || '|' AS txt
            FROM   dual)
    CONNECT BY LEVEL <=
     length(txt) - length(REPLACE(txt, '|', '')) - 1);

=======
        FROM (SELECT TRIM(substr(txt,
                                 instr(txt, '|', 1, LEVEL) + 1,
                                 instr(txt, '|', 1, LEVEL + 1) -
                                 instr(txt, '|', 1, LEVEL) - 1)) AS token
                FROM (SELECT '|' || c_string || '|' AS txt FROM dual)
              CONNECT BY LEVEL <=
                         length(txt) - length(REPLACE(txt, '|', '')) - 1);
  
>>>>>>> .r4768
    TYPE alrt_tab_t IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
    l_alrt_tab alrt_tab_t;
  
  BEGIN
  
    p_err_code     := 0;
    p_risk_country := '';
    p_denied_code  := NULL;
  
    --
    --   TR (Triple Red - Name, Company,Address, and Country found),
    --   DR (Double Red - Name or Company and Address and Country found),
    --   _R (Red - Name or Company and Country found),
    --   _Y (Yellow ? Name or Company found).
    l_alrt_tab('TR') := 4;
    l_alrt_tab('DR') := 3;
    l_alrt_tab('_R') := 2;
    l_alrt_tab('_Y') := 1;
    l_alrt_tab('x') := -1;
  
    -- Initialize the CLOB.
    dbms_lob.createtemporary(l_clob, FALSE);
  
    BEGIN
    
      -- empty
    
      IF p_result IS NULL THEN
      
        --   dbms_output.put_line('empty');
        p_err_code    := 0;
        p_err_message := 'Empty';
      
        RAISE xx_exception;
      END IF;
      -- dbms_output.put_line(' l_clob =' || dbms_lob.getlength(p_result));
      l_clob := p_result;
    
      -- error
    
      l_text := dbms_lob.substr(l_clob,
<<<<<<< .mine
		        
		        least(dbms_lob.getlength(l_clob), 32000),
		        1);
    
||||||| .r4749

            least(dbms_lob.getlength(l_clob), 32000),
            1);

=======
                                
                                least(dbms_lob.getlength(l_clob), 32000),
                                1);
    
>>>>>>> .r4768
      --  dbms_output.put_line(' l_text =' || l_text || ' ----------');
    
      IF instr(l_text, 'ERROR:') > 0 OR
         instr(l_text, 'Missing parameter') > 0 THEN
        --   dbms_output.put_line('Error exists' || l_text);
        p_err_code    := 1;
        p_err_message := l_text;
        RAISE xx_exception;
      END IF;
    
      -- no matching records with a risk country
      IF l_text = 'RISK_COUNTRY' THEN
        p_err_code     := 0;
        p_err_message  := l_text;
        p_risk_country := 'RISK_COUNTRY';
        RAISE xx_exception;
      END IF;
    
      IF instr(l_text, '^') = 0 THEN
        dbms_output.put_line('result=' ||
<<<<<<< .mine
		     substr(l_text,
			instr(l_text, '>', 1, 2),
			instr(l_text, '<', 1, 3) -
			instr(l_text, '>', 1, 2)));
      
||||||| .r4749
         substr(l_text,
      instr(l_text, '>', 1, 2),
      instr(l_text, '<', 1, 3) -
      instr(l_text, '>', 1, 2)));

=======
                             substr(l_text,
                                    instr(l_text, '>', 1, 2),
                                    instr(l_text, '<', 1, 3) -
                                    instr(l_text, '>', 1, 2)));
      
>>>>>>> .r4768
        p_err_code    := 0;
        p_err_message := substr(l_text,
<<<<<<< .mine
		        instr(l_text, '>', 1, 2),
		        instr(l_text, '<', 1, 3) -
		        instr(l_text, '>', 1, 2));
      
||||||| .r4749
            instr(l_text, '>', 1, 2),
            instr(l_text, '<', 1, 3) -
            instr(l_text, '>', 1, 2));

=======
                                instr(l_text, '>', 1, 2),
                                instr(l_text, '<', 1, 3) -
                                instr(l_text, '>', 1, 2));
      
>>>>>>> .r4768
        RAISE xx_exception;
      END IF;
    
    EXCEPTION
      WHEN xx_exception THEN
        dbms_lob.freetemporary(l_clob);
        RETURN;
      WHEN OTHERS THEN
        dbms_output.put_line('when xx :' || SQLERRM);
        dbms_lob.freetemporary(l_clob);
        RETURN;
    END;
  
    --- check lines
    WHILE l_inx2 != 0
    LOOP
      l_seq  := l_seq + 1;
      l_inx1 := dbms_lob.instr(l_clob, '^', 1, l_seq);
      l_inx2 := dbms_lob.instr(l_clob, '^', 1, l_seq + 1);
      --  dbms_output.put_line('l_inx=' || l_inx1 || '-' || l_inx2);
      l_string := dbms_lob.substr(l_clob,
<<<<<<< .mine
		          (CASE l_inx2
			WHEN 0 THEN
			 dbms_lob.getlength(l_clob)
			ELSE
			 l_inx2
		          END) - l_inx1,
		          l_inx1);
||||||| .r4749
              (CASE l_inx2
      WHEN 0 THEN
       dbms_lob.getlength(l_clob)
      ELSE
       l_inx2
              END) - l_inx1,
              l_inx1);
=======
                                  (CASE l_inx2
                                    WHEN 0 THEN
                                     dbms_lob.getlength(l_clob)
                                    ELSE
                                     l_inx2
                                  END) - l_inx1,
                                  l_inx1);
>>>>>>> .r4768
      dbms_output.put_line(l_string);
    
      ---
      FOR i IN c(l_string)
      LOOP
        /*  IF c%ROWCOUNT IN (16, 18) THEN
          dbms_output.put_line(c%ROWCOUNT || '=' || i.token);
        END IF;*/
      
        IF c%ROWCOUNT = 16 THEN
          -- risk country
          p_err_message := i.token;
          IF instr(p_err_message, 'RISK_COUNTRY') > 0 THEN
<<<<<<< .mine
	p_risk_country := 'RISK_COUNTRY';
||||||| .r4749
  p_risk_country := 'RISK_COUNTRY';
=======
            p_risk_country := 'RISK_COUNTRY';
>>>>>>> .r4768
          END IF;
        END IF;
      
        IF c%ROWCOUNT = 18 AND i.token IS NOT NULL THEN
          -- alert level
          --
          --   TR (Triple Red - Name, Company,Address, and Country found),
          --   DR (Double Red - Name or Company and Address and Country found),
          --   _R (Red - Name or Company and Country found),
          --   _Y (Yellow ? Name or Company found).
          IF l_alrt_tab(i.token) > l_alrt_tab(nvl(p_denied_code, 'x')) THEN
<<<<<<< .mine
	p_denied_code := i.token;
||||||| .r4749
  p_denied_code := i.token;
=======
            p_denied_code := i.token;
>>>>>>> .r4768
          END IF;
        
        END IF;
      
      END LOOP;
    
    --
    END LOOP;
  
    -- Relase the resources associated with the temporary LOB.
  
    dbms_lob.freetemporary(l_clob);
  
    --
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Error in parse_result ' || SQLERRM;
      dbms_lob.freetemporary(l_clob);
    
  END;

  ----------------------------------
  -- apply_dp_hold_wf
  ------------------------------------------
  -- CHG0044277 - Apply Denied Party hold
  ---------------------------------------------
  -- ver  date        name            desc
  -- 1.0  xxx         xxx             xxx
  -- 1.1  24-OCT-2018 Diptasurjya     CHG0044277 - If user is SCHEDULER then
  --                                  set order creator as WF owner user
  --------------------------------------------

  PROCEDURE apply_hold_wf(itemtype  IN VARCHAR2,
<<<<<<< .mine
		  itemkey   IN VARCHAR2,
		  actid     IN NUMBER,
		  funcmode  IN VARCHAR2,
		  resultout OUT NOCOPY VARCHAR2) IS
  
||||||| .r4749
      itemkey   IN VARCHAR2,
      actid     IN NUMBER,
      funcmode  IN VARCHAR2,
      resultout OUT NOCOPY VARCHAR2) IS

=======
                          itemkey   IN VARCHAR2,
                          actid     IN NUMBER,
                          funcmode  IN VARCHAR2,
                          resultout OUT NOCOPY VARCHAR2) IS
  
>>>>>>> .r4768
    l_header_id  NUMBER;
    l_org_id     NUMBER;
    l_dp_message VARCHAR2(2000);
<<<<<<< .mine
  
    ln_user_id          NUMBER; -- CHG0044277
    l_is_scheduler_user VARCHAR2(1) := 'N'; -- CHG0044277
||||||| .r4749
    
    ln_user_id  number; -- CHG0044277
    l_is_scheduler_user varchar2(1) := 'N';    -- CHG0044277
=======
  
    ln_user_id          number; -- CHG0044277
    l_is_scheduler_user varchar2(1) := 'N'; -- CHG0044277
>>>>>>> .r4768
    --
    l_err_code    NUMBER;
    l_err_message VARCHAR2(1000);
    my_exception EXCEPTION;
  BEGIN
  
    l_header_id := wf_engine.getitemattrnumber(itemtype => itemtype,
<<<<<<< .mine
			           itemkey  => itemkey,
			           aname    => 'HEADER_ID');
||||||| .r4749
                 itemkey  => itemkey,
                 aname    => 'HEADER_ID');
=======
                                               itemkey  => itemkey,
                                               aname    => 'HEADER_ID');
>>>>>>> .r4768
    l_org_id    := wf_engine.getitemattrnumber(itemtype => itemtype,
<<<<<<< .mine
			           itemkey  => itemkey,
			           aname    => 'ORG_ID');
  
||||||| .r4749
                 itemkey  => itemkey,
                 aname    => 'ORG_ID');

=======
                                               itemkey  => itemkey,
                                               aname    => 'ORG_ID');
  
>>>>>>> .r4768
    l_dp_message := substr(wf_engine.getitemattrtext(itemtype,
<<<<<<< .mine
				     itemkey,
				     'DENIED_CODE_DESC'),
		   1,
		   1000);
  
||||||| .r4749
             itemkey,
             'DENIED_CODE_DESC'),
       1,
       1000);
       
       
=======
                                                     itemkey,
                                                     'DENIED_CODE_DESC'),
                           1,
                           1000);
  
>>>>>>> .r4768
    -- CHG0044277 - start
<<<<<<< .mine
  
    BEGIN
      SELECT 'Y'
      INTO   l_is_scheduler_user
      FROM   fnd_user
      WHERE  user_name = 'SCHEDULER'
      AND    user_id = fnd_global.user_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_is_scheduler_user := 'N';
    END;
  
    IF l_is_scheduler_user = 'Y' THEN
      SELECT created_by
      INTO   ln_user_id
      FROM   oe_order_headers_all
      WHERE  header_id = l_header_id;
    ELSE
||||||| .r4749
    
    begin
      select 'Y'
        into l_is_scheduler_user
        from fnd_user
       where user_name='SCHEDULER'
         and user_id = fnd_global.user_id;
    exception when no_data_found then
      l_is_scheduler_user := 'N';
    end;
      
    if l_is_scheduler_user = 'Y' then
      select created_by
        into ln_user_id
        from oe_order_headers_all
       where header_id = l_header_id;
    else
=======
  
    begin
      select 'Y'
        into l_is_scheduler_user
        from fnd_user
       where user_name = 'SCHEDULER'
         and user_id = fnd_global.user_id;
    exception
      when no_data_found then
        l_is_scheduler_user := 'N';
    end;
  
    if l_is_scheduler_user = 'Y' then
      select created_by
        into ln_user_id
        from oe_order_headers_all
       where header_id = l_header_id;
    else
>>>>>>> .r4768
      ln_user_id := fnd_global.user_id;
    END IF;
    -- CHG0044277 - end
    ----
  
    apply_hold(l_header_id,
<<<<<<< .mine
	   l_org_id,
	   --fnd_global.user_id,  -- CHG0044277 commented
	   ln_user_id, -- CHG0044277
	   l_dp_message, -- p_hold_comment VARCHAR2,
	   l_err_code,
	   l_err_message);
  
||||||| .r4749
     l_org_id,
     --fnd_global.user_id,  -- CHG0044277 commented
     ln_user_id,  -- CHG0044277
     l_dp_message, -- p_hold_comment VARCHAR2,
     l_err_code,
     l_err_message);

=======
               l_org_id,
               --fnd_global.user_id,  -- CHG0044277 commented
               ln_user_id, -- CHG0044277
               l_dp_message, -- p_hold_comment VARCHAR2,
               l_err_code,
               l_err_message);
  
>>>>>>> .r4768
    IF l_err_code = 0 THEN
      resultout := wf_engine.eng_completed;
    ELSE
      wf_core.context('check_denied_parties_wf',
<<<<<<< .mine
	          'apply_hold_wf',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          'Others',
	          'apply_hold_wf: ' || l_err_message);
||||||| .r4749
            'apply_hold_wf',
            itemtype,
            itemkey,
            to_char(actid),
            funcmode,
            'Others',
            'apply_hold_wf: ' || l_err_message);
=======
                      'apply_hold_wf',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      'Others',
                      'apply_hold_wf: ' || l_err_message);
>>>>>>> .r4768
      RAISE my_exception;
    END IF;
  
  END;

  ----------------------------------
  -- apply_dp_hold
  --
  -- apply DP hold  (profile XXOM_DP_HOLD_ID ) on order
  ---------------------------------
  PROCEDURE apply_hold(p_header_id    NUMBER,
<<<<<<< .mine
	           p_org_id       NUMBER,
	           p_user_id      NUMBER,
	           p_hold_comment VARCHAR2,
	           p_err_code     OUT NUMBER,
	           p_err_message  OUT VARCHAR2) IS
  
||||||| .r4749
             p_org_id       NUMBER,
             p_user_id      NUMBER,
             p_hold_comment VARCHAR2,
             p_err_code     OUT NUMBER,
             p_err_message  OUT VARCHAR2) IS

=======
                       p_org_id       NUMBER,
                       p_user_id      NUMBER,
                       p_hold_comment VARCHAR2,
                       p_err_code     OUT NUMBER,
                       p_err_message  OUT VARCHAR2) IS
  
>>>>>>> .r4768
    l_hold_source_rec oe_holds_pvt.hold_source_rec_type;
    l_msg_count       VARCHAR2(200);
    l_msg_data        VARCHAR2(1000);
    l_return_status   VARCHAR2(200);
    l_msg_index_out   NUMBER;
    l_hold_id         NUMBER;
    --l_debug_file      VARCHAR2(50);
  BEGIN
    p_err_code := 0;
  
    mo_global.set_policy_context('S', p_org_id);
    --  oe_globals.set_context();
  
    --  l_debug_file := oe_debug_pub.set_debug_mode('FILE');
  
    /* oe_debug_pub.initialize;
    oe_debug_pub.setdebuglevel(5);
    oe_msg_pub.initialize;
    fnd_global.apps_initialize(3850, 50623, 660);
    mo_global.init('ONT');
    mo_global.set_policy_context('S', p_org_id);*/
  
    --
  
    l_hold_id := fnd_profile.value('XXOM_DP_HOLD_ID');
    --
  
    l_hold_source_rec.hold_id          := l_hold_id; --p_hold_id; -- Requested Hold
    l_hold_source_rec.hold_entity_code := 'O'; -- Order Hold
    l_hold_source_rec.hold_entity_id   := p_header_id; -- Order Header
    l_hold_source_rec.hold_comment     := 'Automatic Denied Party Hold: ' ||
<<<<<<< .mine
			      p_hold_comment;
||||||| .r4749
            p_hold_comment;
=======
                                          p_hold_comment;
>>>>>>> .r4768
    l_hold_source_rec.creation_date    := SYSDATE;
    l_hold_source_rec.created_by       := p_user_id;
  
    ----
  
    oe_holds_pub.apply_holds(p_api_version      => 1.0,
<<<<<<< .mine
		     p_init_msg_list    => fnd_api.g_false,
		     p_commit           => fnd_api.g_false,
		     p_validation_level => fnd_api.g_valid_level_full,
		     p_hold_source_rec  => l_hold_source_rec,
		     x_msg_count        => l_msg_count,
		     x_msg_data         => l_msg_data,
		     x_return_status    => l_return_status);
  
||||||| .r4749
         p_init_msg_list    => fnd_api.g_false,
         p_commit           => fnd_api.g_false,
         p_validation_level => fnd_api.g_valid_level_full,
         p_hold_source_rec  => l_hold_source_rec,
         x_msg_count        => l_msg_count,
         x_msg_data         => l_msg_data,
         x_return_status    => l_return_status);

=======
                             p_init_msg_list    => fnd_api.g_false,
                             p_commit           => fnd_api.g_false,
                             p_validation_level => fnd_api.g_valid_level_full,
                             p_hold_source_rec  => l_hold_source_rec,
                             x_msg_count        => l_msg_count,
                             x_msg_data         => l_msg_data,
                             x_return_status    => l_return_status);
  
>>>>>>> .r4768
    IF l_return_status != fnd_api.g_ret_sts_success THEN
      p_err_code := 1;
      FOR i IN 1 .. l_msg_count
      LOOP
        oe_msg_pub.get(p_msg_index     => i,
<<<<<<< .mine
	           p_encoded       => 'F',
	           p_data          => l_msg_data,
	           p_msg_index_out => l_msg_index_out);
||||||| .r4749
             p_encoded       => 'F',
             p_data          => l_msg_data,
             p_msg_index_out => l_msg_index_out);
=======
                       p_encoded       => 'F',
                       p_data          => l_msg_data,
                       p_msg_index_out => l_msg_index_out);
>>>>>>> .r4768
        --   dbms_output.put_line('x=' || l_msg_data);
        p_err_message := p_err_message || l_msg_data || chr(10);
      
      END LOOP;
    END IF;
  END;

  --------------------------------------------------------------------------
  -- release_dp_hold_wf

  ---------------------------------------------------------------------------
  -- Version  Date         Performer       Comments
  ----------  --------     --------------  -------------------------------------
  --     1.1  06.3.13      yuval tal       CR689 : find user id from email response
  --     1.2  19-AUG-2020  Diptasujya      INC0202587 - release comment is not being populated properly
  --                                       Reason - var CONTEXT_USER_MAIL normally contains ROLE name and not email
  --                                       Current checks modified to consider the variable value directly instead of try to derive name from it
  ---------------------------------------------------------------------------
  PROCEDURE release_hold_wf(itemtype  IN VARCHAR2,
<<<<<<< .mine
		    itemkey   IN VARCHAR2,
		    actid     IN NUMBER,
		    funcmode  IN VARCHAR2,
		    resultout OUT NOCOPY VARCHAR2) IS
  
||||||| .r4749
        itemkey   IN VARCHAR2,
        actid     IN NUMBER,
        funcmode  IN VARCHAR2,
        resultout OUT NOCOPY VARCHAR2) IS

=======
                            itemkey   IN VARCHAR2,
                            actid     IN NUMBER,
                            funcmode  IN VARCHAR2,
                            resultout OUT NOCOPY VARCHAR2) IS
  
>>>>>>> .r4768
    l_err_code          NUMBER;
    l_err_message       VARCHAR2(2000);
    l_header_id         NUMBER;
    l_org_id            NUMBER;
    l_line_id           NUMBER;
    l_context_user_mail VARCHAR2(150);
    l_user_id           NUMBER;
    l_release_comment   VARCHAR2(300);
    my_exception EXCEPTION;
  BEGIN
  
    l_header_id := wf_engine.getitemattrnumber(itemtype => itemtype,
<<<<<<< .mine
			           itemkey  => itemkey,
			           aname    => 'HEADER_ID');
||||||| .r4749
                 itemkey  => itemkey,
                 aname    => 'HEADER_ID');
=======
                                               itemkey  => itemkey,
                                               aname    => 'HEADER_ID');
>>>>>>> .r4768
    l_org_id    := wf_engine.getitemattrnumber(itemtype => itemtype,
<<<<<<< .mine
			           itemkey  => itemkey,
			           aname    => 'ORG_ID');
  
||||||| .r4749
                 itemkey  => itemkey,
                 aname    => 'ORG_ID');

=======
                                               itemkey  => itemkey,
                                               aname    => 'ORG_ID');
  
>>>>>>> .r4768
    l_line_id := wf_engine.getitemattrnumber(itemtype => itemtype,
<<<<<<< .mine
			         itemkey  => itemkey,
			         aname    => 'LINE_ID');
  
||||||| .r4749
               itemkey  => itemkey,
               aname    => 'LINE_ID');

=======
                                             itemkey  => itemkey,
                                             aname    => 'LINE_ID');
  
>>>>>>> .r4768
    IF is_open_dp_hold_exists(l_line_id) = 'Y' THEN
      -- cr689
      l_context_user_mail := wf_engine.getitemattrtext(itemtype => itemtype,
<<<<<<< .mine
				       itemkey  => itemkey,
				       aname    => 'CONTEXT_USER_MAIL');
    
      -- INC0202587 populate release comment
      IF l_context_user_mail IS NOT NULL THEN
        l_release_comment := 'Response by mail:' || l_context_user_mail;
      END IF;
    
||||||| .r4749
               itemkey  => itemkey,
               aname    => 'CONTEXT_USER_MAIL');

=======
                                                       itemkey  => itemkey,
                                                       aname    => 'CONTEXT_USER_MAIL');
    
      -- INC0202587 populate release comment
      IF l_context_user_mail is not null then
        l_release_comment := 'Response by mail:' || l_context_user_mail;
      END IF;
    
>>>>>>> .r4768
      IF instr(l_context_user_mail, '@') > 0 THEN
        l_context_user_mail := substr(l_context_user_mail, 7);
        --l_release_comment   := 'Response by mail:' || l_context_user_mail;  -- INC0202587 comment
        l_user_id := get_user_id_by_email(l_context_user_mail);
      ELSE
<<<<<<< .mine
        -- INC0202587 add begin exception block to find user ID from context user variable value
        -- In case no data found then user Global context user ID
        BEGIN
          SELECT fu.user_id
          INTO   l_user_id
          FROM   fnd_user fu
          WHERE  fu.user_name = l_context_user_mail;
        EXCEPTION
          WHEN no_data_found THEN
	l_user_id := fnd_global.user_id;
        END;
||||||| .r4749
        l_user_id := fnd_global.user_id;

=======
        -- INC0202587 add begin exception block to find user ID from context user variable value
        -- In case no data found then user Global context user ID
        BEGIN
          select fu.user_id
            into l_user_id
            from fnd_user fu
           where fu.user_name = l_context_user_mail;
        EXCEPTION
          When NO_DATA_FOUND THEN
            l_user_id := fnd_global.user_id;
        END;
>>>>>>> .r4768
      END IF;
    
      -- end 689
      release_hold(l_header_id,
<<<<<<< .mine
	       l_org_id,
	       nvl(l_user_id, fnd_global.user_id),
	       l_release_comment,
	       l_err_code,
	       l_err_message);
||||||| .r4749
         l_org_id,
         nvl(l_user_id, fnd_global.user_id),
         l_release_comment,
         l_err_code,
         l_err_message);
=======
                   l_org_id,
                   nvl(l_user_id, fnd_global.user_id),
                   l_release_comment,
                   l_err_code,
                   l_err_message);
>>>>>>> .r4768
      IF l_err_code = 0 THEN
        resultout := wf_engine.eng_completed;
      ELSE
        wf_core.context('check_denied_parties_wf',
<<<<<<< .mine
		'release_hold_wf',
		itemtype,
		itemkey,
		to_char(actid),
		funcmode,
		'Others',
		'release_hold_wf: ' || l_err_message);
||||||| .r4749
    'release_hold_wf',
    itemtype,
    itemkey,
    to_char(actid),
    funcmode,
    'Others',
    'release_hold_wf: ' || l_err_message);
=======
                        'release_hold_wf',
                        itemtype,
                        itemkey,
                        to_char(actid),
                        funcmode,
                        'Others',
                        'release_hold_wf: ' || l_err_message);
>>>>>>> .r4768
        RAISE my_exception;
      END IF;
    END IF;
  
    resultout := wf_engine.eng_completed;
  
  END;

  ---------------------------------------------------------------------------
  -- release_dp_hold
  --
  --  release DP hold  (profile XXOM_DP_HOLD_ID ) on order
  ---------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.1  06.03.13   yuval tal      CR689:add parameter p_release_comment
  ----------------------------------------------------------------------------
  PROCEDURE release_hold(p_header_id       NUMBER,
<<<<<<< .mine
		 p_org_id          NUMBER,
		 p_user_id         NUMBER,
		 p_release_comment VARCHAR2,
		 p_err_code        OUT NUMBER,
		 p_err_message     OUT VARCHAR2) IS
  
||||||| .r4749
     p_org_id          NUMBER,
     p_user_id         NUMBER,
     p_release_comment VARCHAR2,
     p_err_code        OUT NUMBER,
     p_err_message     OUT VARCHAR2) IS

=======
                         p_org_id          NUMBER,
                         p_user_id         NUMBER,
                         p_release_comment VARCHAR2,
                         p_err_code        OUT NUMBER,
                         p_err_message     OUT VARCHAR2) IS
  
>>>>>>> .r4768
    l_hold_source_rec  oe_holds_pvt.hold_source_rec_type;
    l_hold_release_rec oe_holds_pvt.hold_release_rec_type;
    l_msg_count        VARCHAR2(200);
    l_msg_data         VARCHAR2(1000);
    l_return_status    VARCHAR2(200);
    l_msg_index_out    NUMBER;
    l_err_msg          VARCHAR2(500);
    l_hold_id          NUMBER;
  BEGIN
    p_err_code := 0;
  
    mo_global.set_policy_context('S', p_org_id);
    oe_globals.set_context();
  
    --
    l_hold_id := fnd_profile.value('XXOM_DP_HOLD_ID');
  
    l_hold_source_rec.hold_id              := l_hold_id; -- Requested Hold
    l_hold_source_rec.hold_entity_code     := 'O';
    l_hold_source_rec.hold_entity_id       := p_header_id;
    l_hold_source_rec.header_id            := p_header_id;
    l_hold_release_rec.last_updated_by     := p_user_id;
    l_hold_release_rec.release_reason_code := fnd_profile.value('XXOM_DP_RELEASE_REASON');
    l_hold_release_rec.release_comment     := p_release_comment;
    l_hold_release_rec.created_by          := p_user_id;
  
    oe_msg_pub.initialize;
  
    oe_holds_pub.release_holds(p_api_version      => 1.0,
<<<<<<< .mine
		       p_init_msg_list    => 'T',
		       p_commit           => 'F',
		       p_hold_source_rec  => l_hold_source_rec,
		       p_hold_release_rec => l_hold_release_rec,
		       x_msg_count        => l_msg_count,
		       x_msg_data         => l_msg_data,
		       x_return_status    => l_return_status);
  
||||||| .r4749
           p_init_msg_list    => 'T',
           p_commit           => 'F',
           p_hold_source_rec  => l_hold_source_rec,
           p_hold_release_rec => l_hold_release_rec,
           x_msg_count        => l_msg_count,
           x_msg_data         => l_msg_data,
           x_return_status    => l_return_status);

=======
                               p_init_msg_list    => 'T',
                               p_commit           => 'F',
                               p_hold_source_rec  => l_hold_source_rec,
                               p_hold_release_rec => l_hold_release_rec,
                               x_msg_count        => l_msg_count,
                               x_msg_data         => l_msg_data,
                               x_return_status    => l_return_status);
  
>>>>>>> .r4768
    IF l_return_status != fnd_api.g_ret_sts_success THEN
      p_err_code := 1;
<<<<<<< .mine
    
      FOR i IN 1 .. l_msg_count
      LOOP
||||||| .r4749

      FOR i IN 1 .. l_msg_count LOOP
=======
    
      FOR i IN 1 .. l_msg_count LOOP
>>>>>>> .r4768
        oe_msg_pub.get(p_msg_index     => i,
<<<<<<< .mine
	           p_encoded       => 'F',
	           p_data          => l_msg_data,
	           p_msg_index_out => l_msg_index_out);
      
||||||| .r4749
             p_encoded       => 'F',
             p_data          => l_msg_data,
             p_msg_index_out => l_msg_index_out);

=======
                       p_encoded       => 'F',
                       p_data          => l_msg_data,
                       p_msg_index_out => l_msg_index_out);
      
>>>>>>> .r4768
        l_err_msg := l_err_msg || l_msg_data || chr(10);
        IF length(l_err_msg) > 500 THEN
          l_err_msg := substr(l_err_msg, 1, 500);
          EXIT;
        END IF;
      
      END LOOP;
    
    END IF;
    p_err_message := l_err_msg;
  END;

  --------------------------------------------------------------------
  -- is_inventory_item
  -- is inventory item return Y/N
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  19.07.12   yuval tal       CHG0032016 -  Bug fix - Denied Parties hold - Exclude non inventory items

  -----------------------------------------------------------------------
  FUNCTION is_inventory_item(p_item_id NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c IS
      SELECT msi.inventory_item_flag
<<<<<<< .mine
      FROM   mtl_system_items_b msi
      
      WHERE  msi.inventory_item_id = p_item_id
      AND    msi.organization_id = 91;
  
||||||| .r4749
      FROM   mtl_system_items_b msi

      WHERE  msi.inventory_item_id = p_item_id
      AND    msi.organization_id = 91;

=======
        FROM mtl_system_items_b msi
      
       WHERE msi.inventory_item_id = p_item_id
         AND msi.organization_id = 91;
  
>>>>>>> .r4768
    l_tmp VARCHAR2(1);
  
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN nvl(l_tmp, 'N');
  
  END;

  ----------------------------------
  -- is_fdm_item
  --
  -- is ssys item return Y/N
  ---------------------------------
  FUNCTION is_fdm_item(p_item_id NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c IS
      SELECT 'Y'
<<<<<<< .mine
      FROM   mtl_categories_b        c,
	 mtl_item_categories_v   icat,
	 mtl_system_items_b      msi,
	 mtl_category_sets_all_v cs
      WHERE  c.disable_date IS NULL
      AND    c.category_id = icat.category_id
      AND    c.structure_id = icat.structure_id
      AND    icat.inventory_item_id = msi.inventory_item_id
      AND    icat.organization_id = msi.organization_id
      AND    cs.structure_id = c.structure_id
      AND    cs.category_set_name = 'Main Category Set'
      AND    c.structure_id = 50328
      AND    c.attribute8 = 'FDM'
      AND    msi.inventory_item_id = p_item_id
      AND    msi.organization_id = 91;
  
||||||| .r4749
      FROM   mtl_categories_b        c,
   mtl_item_categories_v   icat,
   mtl_system_items_b      msi,
   mtl_category_sets_all_v cs
      WHERE  c.disable_date IS NULL
      AND    c.category_id = icat.category_id
      AND    c.structure_id = icat.structure_id
      AND    icat.inventory_item_id = msi.inventory_item_id
      AND    icat.organization_id = msi.organization_id
      AND    cs.structure_id = c.structure_id
      AND    cs.category_set_name = 'Main Category Set'
      AND    c.structure_id = 50328
      AND    c.attribute8 = 'FDM'
      AND    msi.inventory_item_id = p_item_id
      AND    msi.organization_id = 91;

=======
        FROM mtl_categories_b        c,
             mtl_item_categories_v   icat,
             mtl_system_items_b      msi,
             mtl_category_sets_all_v cs
       WHERE c.disable_date IS NULL
         AND c.category_id = icat.category_id
         AND c.structure_id = icat.structure_id
         AND icat.inventory_item_id = msi.inventory_item_id
         AND icat.organization_id = msi.organization_id
         AND cs.structure_id = c.structure_id
         AND cs.category_set_name = 'Main Category Set'
         AND c.structure_id = 50328
         AND c.attribute8 = 'FDM'
         AND msi.inventory_item_id = p_item_id
         AND msi.organization_id = 91;
  
>>>>>>> .r4768
    l_tmp VARCHAR2(1);
  
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN nvl(l_tmp, 'N');
  
  END;
  ---------------------------------------
  -- is_hold_released_in_interval
  --
  -- check if  hold was released in the past X days
  -- according to profile XXOM_DP_DAYS_TO_REHOLD
  ---------------------------------------
  FUNCTION is_hold_released_in_interval(p_line_id NUMBER) RETURN VARCHAR2 IS
    l_header_id NUMBER;
    l_tmp       NUMBER;
    CURSOR c IS
    
      SELECT 1
<<<<<<< .mine
      FROM   oe_order_holds_all  oh,
	 oe_hold_sources_all hs,
	 oe_hold_releases    hr,
	 oe_hold_definitions hd
      
      WHERE  oh.hold_source_id = hs.hold_source_id
      AND    hs.hold_id = hd.hold_id
      AND    oh.hold_release_id = hr.hold_release_id(+)
      AND    hs.org_id = oh.org_id
      AND    hd.hold_id = fnd_profile.value('XXOM_DP_HOLD_ID')
      AND    hs.released_flag = 'Y'
      AND    oh.header_id = l_header_id
      AND    SYSDATE - hs.last_update_date <=
	 fnd_profile.value('XXOM_DP_DAYS_TO_REHOLD');
  
||||||| .r4749
      FROM   oe_order_holds_all  oh,
   oe_hold_sources_all hs,
   oe_hold_releases    hr,
   oe_hold_definitions hd

      WHERE  oh.hold_source_id = hs.hold_source_id
      AND    hs.hold_id = hd.hold_id
      AND    oh.hold_release_id = hr.hold_release_id(+)
      AND    hs.org_id = oh.org_id
      AND    hd.hold_id = fnd_profile.value('XXOM_DP_HOLD_ID')
      AND    hs.released_flag = 'Y'
      AND    oh.header_id = l_header_id
      AND    SYSDATE - hs.last_update_date <=
   fnd_profile.value('XXOM_DP_DAYS_TO_REHOLD');

=======
        FROM oe_order_holds_all  oh,
             oe_hold_sources_all hs,
             oe_hold_releases    hr,
             oe_hold_definitions hd
      
       WHERE oh.hold_source_id = hs.hold_source_id
         AND hs.hold_id = hd.hold_id
         AND oh.hold_release_id = hr.hold_release_id(+)
         AND hs.org_id = oh.org_id
         AND hd.hold_id = fnd_profile.value('XXOM_DP_HOLD_ID')
         AND hs.released_flag = 'Y'
         AND oh.header_id = l_header_id
         AND SYSDATE - hs.last_update_date <=
             fnd_profile.value('XXOM_DP_DAYS_TO_REHOLD');
  
>>>>>>> .r4768
  BEGIN
    SELECT header_id
<<<<<<< .mine
    INTO   l_header_id
    FROM   oe_order_lines_all t
    WHERE  t.line_id = p_line_id;
  
||||||| .r4749
    INTO   l_header_id
    FROM   oe_order_lines_all t
    WHERE  t.line_id = p_line_id;

=======
      INTO l_header_id
      FROM oe_order_lines_all t
     WHERE t.line_id = p_line_id;
  
>>>>>>> .r4768
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    IF nvl(l_tmp, 0) = 0 THEN
      RETURN 'N';
    ELSE
      RETURN 'Y';
    END IF;
  
  END;

  ---------------------------------------------
  -- is_dp_check_needed
  ---------------------------------------------
  -- ver  date        name            desc
  -- 1.1  23.4.14     yuval tal       CHG0032016 - Bug fix - Denied Parties hold - Exclude non inventory items
  -- 1.2  16-Nov-2015 Dalit A. RAviv  CHG0036995 - Check denied party hold for all orders
  -- 1.3  24-OCT-2018 Diptasurjya     CHG0044277 - No not fire DP if already fired for same customer/contact/address
  --------------------------------------------
  FUNCTION is_dp_check_needed(p_line_id NUMBER) RETURN VARCHAR2 IS
  
    l_line_id         NUMBER;
    l_order_source_id NUMBER;
<<<<<<< .mine
  
    l_customer_id     NUMBER; -- CHG0044277
    l_ship_contact_id NUMBER; -- CHG0044277
    l_bill_contact_id NUMBER; -- CHG0044277
    l_ship_site_id    NUMBER; -- CHG0044277
    l_bill_site_id    NUMBER; -- CHG0044277
    l_header_id       NUMBER; -- CHG0044277
  
    l_item_id NUMBER;
  
    l_ship_dp_exist VARCHAR2(1) := 'N'; -- CHG0044277
    l_bill_dp_exist VARCHAR2(1) := 'N'; -- CHG0044277
||||||| .r4749

    l_customer_id        number;   -- CHG0044277
    l_ship_contact_id    number;   -- CHG0044277
    l_bill_contact_id    number;   -- CHG0044277
    l_ship_site_id       number;   -- CHG0044277
    l_bill_site_id       number;   -- CHG0044277
    l_header_id          number;   -- CHG0044277

    l_item_id         NUMBER;

    l_ship_dp_exist     varchar2(1) := 'N';      -- CHG0044277
    l_bill_dp_exist     varchar2(1) := 'N';      -- CHG0044277
=======
  
    l_customer_id     number; -- CHG0044277
    l_ship_contact_id number; -- CHG0044277
    l_bill_contact_id number; -- CHG0044277
    l_ship_site_id    number; -- CHG0044277
    l_bill_site_id    number; -- CHG0044277
    l_header_id       number; -- CHG0044277
  
    l_item_id NUMBER;
  
    l_ship_dp_exist varchar2(1) := 'N'; -- CHG0044277
    l_bill_dp_exist varchar2(1) := 'N'; -- CHG0044277
>>>>>>> .r4768
  BEGIN
  
    IF fnd_profile.value('XXOM_DP_ENABLE_CHECK') = 'Y' THEN
      -- get attributes
      l_line_id := p_line_id;
    
      -- CHG0044277 - commented below portion
      /*OPEN c;
         FETCH c
           INTO l_item_id,
      l_order_source_id;
         CLOSE c;*/
    
      -- CHG0044277 - add below query to fetch details corresponding to line
      SELECT t.inventory_item_id,
<<<<<<< .mine
	 t.order_source_id,
	 t.ship_to_org_id,
	 t.invoice_to_org_id,
	 nvl(t.ship_to_contact_id, -1),
	 nvl(t.invoice_to_contact_id, -1),
	 t.sold_to_org_id,
	 t.header_id
||||||| .r4749
             t.order_source_id,
             t.ship_to_org_id,
             t.invoice_to_org_id,
             nvl(t.ship_to_contact_id,-1),
             nvl(t.invoice_to_contact_id,-1),
             t.sold_to_org_id,
             t.header_id
=======
             t.order_source_id,
             t.ship_to_org_id,
             t.invoice_to_org_id,
             nvl(t.ship_to_contact_id, -1),
             nvl(t.invoice_to_contact_id, -1),
             t.sold_to_org_id,
             t.header_id
>>>>>>> .r4768
        INTO l_item_id,
	 l_order_source_id,
	 l_ship_site_id,
	 l_bill_site_id,
	 l_ship_contact_id,
	 l_bill_contact_id,
	 l_customer_id,
	 l_header_id
<<<<<<< .mine
      FROM   xxom_dp_locations_v t
      WHERE  t.line_id = l_line_id;
    
||||||| .r4749
      FROM   xxom_dp_locations_v t
      WHERE  t.line_id = l_line_id;

=======
        FROM xxom_dp_locations_v t
       WHERE t.line_id = l_line_id;
    
>>>>>>> .r4768
      -- CHG0036995 - Check denied party hold for all orders
      -- remarks is inventory item and is fdm item
      IF l_order_source_id != 10 AND
         NOT (is_open_dp_hold_exists(l_line_id) = 'Y' OR
          is_hold_released_in_interval(l_line_id) = 'Y') THEN
        -- CHG0044277 - Start check for existing DP checks
<<<<<<< .mine
        BEGIN
          SELECT xda.dp_check_flag
          INTO   l_ship_dp_exist
          FROM   xxom_dp_check_audit xda
          WHERE  xda.header_id = l_header_id
          AND    xda.cust_account_id = l_customer_id
          AND    xda.site_id = l_ship_site_id
          AND    xda.contact_id = l_ship_contact_id
          AND    xda.dp_check_date >= (SYSDATE - 5 / (24 * 60))
          AND    rownum = 1;
        EXCEPTION
          WHEN no_data_found THEN
	l_ship_dp_exist := 'N';
        END;
      
        IF l_ship_contact_id <> l_bill_contact_id OR
           l_ship_site_id <> l_bill_site_id THEN
          BEGIN
	SELECT xda.dp_check_flag
	INTO   l_bill_dp_exist
	FROM   xxom_dp_check_audit xda
	WHERE  xda.header_id = l_header_id
	AND    xda.cust_account_id = l_customer_id
	AND    xda.site_id = l_bill_site_id
	AND    xda.contact_id = l_bill_contact_id
	AND    xda.dp_check_date >= (SYSDATE - 5 / (24 * 60))
	AND    rownum = 1;
          EXCEPTION
	WHEN no_data_found THEN
	  l_bill_dp_exist := 'N';
          END;
        ELSE
||||||| .r4749
        begin
          select xda.dp_check_flag
            into l_ship_dp_exist
            from xxom_dp_check_audit xda
           where xda.header_id = l_header_id
             and xda.cust_account_id = l_customer_id
             and xda.site_id = l_ship_site_id
             and xda.contact_id = l_ship_contact_id
             and xda.dp_check_date >= (sysdate-5/(24*60))
             and rownum = 1;
        exception when no_data_found then
          l_ship_dp_exist := 'N';
        end;

        if l_ship_contact_id <> l_bill_contact_id
          or l_ship_site_id <> l_bill_site_id then
          begin
            select xda.dp_check_flag
              into l_bill_dp_exist
              from xxom_dp_check_audit xda
             where xda.header_id = l_header_id
               and xda.cust_account_id = l_customer_id
               and xda.site_id = l_bill_site_id
               and xda.contact_id = l_bill_contact_id
               and xda.dp_check_date >= (sysdate-5/(24*60))
               and rownum = 1;
          exception when no_data_found then
            l_bill_dp_exist := 'N';
          end;
        else
=======
        begin
          select xda.dp_check_flag
            into l_ship_dp_exist
            from xxom_dp_check_audit xda
           where xda.header_id = l_header_id
             and xda.cust_account_id = l_customer_id
             and xda.site_id = l_ship_site_id
             and xda.contact_id = l_ship_contact_id
             and xda.dp_check_date >= (sysdate - 5 / (24 * 60))
             and rownum = 1;
        exception
          when no_data_found then
            l_ship_dp_exist := 'N';
        end;
      
        if l_ship_contact_id <> l_bill_contact_id or
           l_ship_site_id <> l_bill_site_id then
          begin
            select xda.dp_check_flag
              into l_bill_dp_exist
              from xxom_dp_check_audit xda
             where xda.header_id = l_header_id
               and xda.cust_account_id = l_customer_id
               and xda.site_id = l_bill_site_id
               and xda.contact_id = l_bill_contact_id
               and xda.dp_check_date >= (sysdate - 5 / (24 * 60))
               and rownum = 1;
          exception
            when no_data_found then
              l_bill_dp_exist := 'N';
          end;
        else
>>>>>>> .r4768
          l_bill_dp_exist := 'Y';
<<<<<<< .mine
        END IF;
      
        IF l_ship_dp_exist = 'Y' AND l_bill_dp_exist = 'Y' THEN
          RETURN 'N';
        END IF;
||||||| .r4749
        end if;

        if l_ship_dp_exist = 'Y' and l_bill_dp_exist = 'Y' then
          return 'N';
        end if;
=======
        end if;
      
        if l_ship_dp_exist = 'Y' and l_bill_dp_exist = 'Y' then
          return 'N';
        end if;
>>>>>>> .r4768
        -- CHG0044277 - End check for existing DP checks
      
        -- CHG0044277 - insert audit table with ship details
<<<<<<< .mine
        insert_dp_audit_table(p_header_id       => l_header_id,
		      p_cust_account_id => l_customer_id,
		      p_site_id         => l_ship_site_id,
		      p_contact_id      => l_ship_contact_id);
      
||||||| .r4749
        insert_dp_audit_table(p_header_id        => l_header_id,
                              p_cust_account_id  => l_customer_id,
                              p_site_id          => l_ship_site_id,
                              p_contact_id       => l_ship_contact_id);


=======
        insert_dp_audit_table(p_header_id       => l_header_id,
                              p_cust_account_id => l_customer_id,
                              p_site_id         => l_ship_site_id,
                              p_contact_id      => l_ship_contact_id);
      
>>>>>>> .r4768
        -- CHG0044277 - insert audit table with bill details
<<<<<<< .mine
        insert_dp_audit_table(p_header_id       => l_header_id,
		      p_cust_account_id => l_customer_id,
		      p_site_id         => l_bill_site_id,
		      p_contact_id      => l_bill_contact_id);
      
||||||| .r4749
        insert_dp_audit_table(p_header_id        => l_header_id,
                              p_cust_account_id  => l_customer_id,
                              p_site_id          => l_bill_site_id,
                              p_contact_id       => l_bill_contact_id);

=======
        insert_dp_audit_table(p_header_id       => l_header_id,
                              p_cust_account_id => l_customer_id,
                              p_site_id         => l_bill_site_id,
                              p_contact_id      => l_bill_contact_id);
      
>>>>>>> .r4768
        RETURN 'Y';
      ELSE
        RETURN 'N';
      END IF;
    ELSE
      RETURN 'N';
    END IF;
  END is_dp_check_needed;

  ---------------------------------------------
  -- is_dp_check_needed
  -- check if there is need to call WS of denied parties
  -- fdm item  & not internal & hold not exists
  ---------------------------------------------
  PROCEDURE is_dp_check_needed(itemtype  IN VARCHAR2,
<<<<<<< .mine
		       itemkey   IN VARCHAR2,
		       actid     IN NUMBER,
		       funcmode  IN VARCHAR2,
		       resultout OUT NOCOPY VARCHAR2) IS
  
||||||| .r4749
           itemkey   IN VARCHAR2,
           actid     IN NUMBER,
           funcmode  IN VARCHAR2,
           resultout OUT NOCOPY VARCHAR2) IS

=======
                               itemkey   IN VARCHAR2,
                               actid     IN NUMBER,
                               funcmode  IN VARCHAR2,
                               resultout OUT NOCOPY VARCHAR2) IS
  
>>>>>>> .r4768
    l_line_id NUMBER;
  BEGIN
  
    l_line_id := wf_engine.getitemuserkey(itemtype => itemtype,
<<<<<<< .mine
			      itemkey  => itemkey);
  
||||||| .r4749
            itemkey  => itemkey);

=======
                                          itemkey  => itemkey);
  
>>>>>>> .r4768
    resultout := wf_engine.eng_completed || ':' ||
<<<<<<< .mine
	     is_dp_check_needed(l_line_id);
  
||||||| .r4749
       is_dp_check_needed(l_line_id);

=======
                 is_dp_check_needed(l_line_id);
  
>>>>>>> .r4768
  END;

  ---------------------------------
  -- initiate_dp_param
  --
  -- called from wf OEOL : init attribute for launching workflow XXDPAPR
  -- check if Dp needed
  -- return Y /N for continue to DP workflow
  ---------------------------------

  PROCEDURE initiate_dp_param(itemtype  IN VARCHAR2,
<<<<<<< .mine
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2) IS
  
||||||| .r4749
          itemkey   IN VARCHAR2,
          actid     IN NUMBER,
          funcmode  IN VARCHAR2,
          resultout OUT NOCOPY VARCHAR2) IS

=======
                              itemkey   IN VARCHAR2,
                              actid     IN NUMBER,
                              funcmode  IN VARCHAR2,
                              resultout OUT NOCOPY VARCHAR2) IS
  
>>>>>>> .r4768
    l_line_id NUMBER;
  
  BEGIN
    l_line_id := itemkey;
  
    wf_engine.setitemattrnumber(itemtype => itemtype,
<<<<<<< .mine
		        itemkey  => itemkey,
		        aname    => 'XX_DP_LINE_ID',
		        avalue   => l_line_id);
  
||||||| .r4749
            itemkey  => itemkey,
            aname    => 'XX_DP_LINE_ID',
            avalue   => l_line_id);

=======
                                itemkey  => itemkey,
                                aname    => 'XX_DP_LINE_ID',
                                avalue   => l_line_id);
  
>>>>>>> .r4768
    IF is_dp_check_needed(l_line_id) = 'Y' THEN
    
      resultout := wf_engine.eng_completed || ':Y';
    ELSE
      resultout := wf_engine.eng_completed || ':N';
    END IF;
  END;

  --------------------------------------------------------------------------
  -- initiate_dp_hold_conc

  ---------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.0  23.11.17  piyali bhowmick     CHG0041843- Create a new program for applying hold on non-picked orders

  ---------------------------------
  PROCEDURE initiate_dp_hold_conc(p_err_code    OUT NUMBER,
<<<<<<< .mine
		          p_err_message OUT VARCHAR2) IS
  
||||||| .r4749
              p_err_message OUT VARCHAR2) IS

=======
                                  p_err_message OUT VARCHAR2) IS
  
>>>>>>> .r4768
    l_line_id  NUMBER;
    l_item_key VARCHAR2(500);
    l_user_key VARCHAR2(500);
  
    CURSOR c_order_lines IS
<<<<<<< .mine
      SELECT ol.line_id,
	 oh.order_number,
	 oh.org_id
      FROM   oe_order_lines_all   ol,
	 oe_order_headers_all oh,
	 wsh_delivery_details d
      WHERE  ol.flow_status_code = 'AWAITING_SHIPPING'
      AND    ol.header_id = oh.header_id
      AND    d.source_header_id = oh.header_id
      AND    d.source_line_id = ol.line_id
      AND    d.released_status IN ('R', 'B')
      AND    oh.order_source_id <> '10';
||||||| .r4749
      SELECT ol.line_id,
   oh.order_number,
   oh.org_id
      FROM   oe_order_lines_all   ol,
   oe_order_headers_all oh,
   wsh_delivery_details d
      WHERE  ol.flow_status_code = 'AWAITING_SHIPPING'
      AND    ol.header_id = oh.header_id
      AND    d.source_header_id = oh.header_id
      AND    d.source_line_id = ol.line_id
      AND    d.released_status IN ('R', 'B')
      AND    oh.order_source_id <> '10';
=======
      SELECT ol.line_id, oh.order_number, oh.org_id
        FROM oe_order_lines_all   ol,
             oe_order_headers_all oh,
             wsh_delivery_details d
       WHERE ol.flow_status_code = 'AWAITING_SHIPPING'
         AND ol.header_id = oh.header_id
         AND d.source_header_id = oh.header_id
         AND d.source_line_id = ol.line_id
         AND d.released_status IN ('R', 'B')
         AND oh.order_source_id <> '10';
>>>>>>> .r4768
    -- AND    ol.line_id = 3547770;
  
  BEGIN
    p_err_code    := 0;
    p_err_message := NULL;
<<<<<<< .mine
  
    FOR i IN c_order_lines
    LOOP
    
||||||| .r4749

    FOR i IN c_order_lines LOOP

=======
  
    FOR i IN c_order_lines LOOP
    
>>>>>>> .r4768
      /* fnd_file.put_line(fnd_file.log,
                      'XXOM_DP_ORG_ID_CHK_FLAG=' ||
                        nvl(fnd_profile.value_specific('XXOM_DP_ORG_ID_CHK_FLAG',
                                                       i.org_id),
                            fnd_profile.value_specific('XXOM_DP_ORG_ID_CHK_FLAG')));
      fnd_file.put_line(fnd_file.log,
                        'is_dp_check_needed=' ||
                        is_dp_check_needed(i.line_id));*/
    
      IF nvl(fnd_profile.value_specific('XXOM_DP_ORG_ID_CHK_FLAG',
<<<<<<< .mine
			    NULL,
			    NULL,
			    NULL,
			    i.org_id),
	 fnd_profile.value_specific('XXOM_DP_ORG_ID_CHK_FLAG')) = 'Y' AND
||||||| .r4749
          NULL,
          NULL,
          NULL,
          i.org_id),
   fnd_profile.value_specific('XXOM_DP_ORG_ID_CHK_FLAG')) = 'Y' AND
=======
                                        NULL,
                                        NULL,
                                        NULL,
                                        i.org_id),
             fnd_profile.value_specific('XXOM_DP_ORG_ID_CHK_FLAG')) = 'Y' AND
>>>>>>> .r4768
         is_dp_check_needed(i.line_id) = 'Y' THEN
      
        initiate_dp_hold_wf(p_err_code    => p_err_code,
<<<<<<< .mine
		    p_err_message => p_err_message,
		    p_line_id     => i.line_id,
		    p_item_key    => l_item_key,
		    p_user_key    => l_user_key
		    
		    );
||||||| .r4749
        p_err_message => p_err_message,
        p_line_id     => i.line_id,
        p_item_key    => l_item_key,
        p_user_key    => l_user_key

        );
=======
                            p_err_message => p_err_message,
                            p_line_id     => i.line_id,
                            p_item_key    => l_item_key,
                            p_user_key    => l_user_key
                            
                            );
>>>>>>> .r4768
        fnd_file.put_line(fnd_file.log,
<<<<<<< .mine
		  ' Initiated  dp hold  for order no ' ||
		  i.order_number || ' line_id     =' || i.line_id ||
		  ' p_item_key=' || l_item_key || ' p_user_key=' ||
		  l_user_key);
      
||||||| .r4749
      ' Initiated  dp hold  for order no ' ||
      i.order_number || ' line_id     =' || i.line_id ||
      ' p_item_key=' || l_item_key || ' p_user_key=' ||
      l_user_key);

=======
                          ' Initiated  dp hold  for order no ' ||
                          i.order_number || ' line_id     =' || i.line_id ||
                          ' p_item_key=' || l_item_key || ' p_user_key=' ||
                          l_user_key);
      
>>>>>>> .r4768
      END IF;
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END initiate_dp_hold_conc;
  --------------------------------------------------------------------------
  -- initiate_dp_hold_wf

  ---------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.0  23.11.17  piyali bhowmick     CHG0041843- To initiate the DP Hold Workflow Process for a particular order line
  ---------------------------------
  PROCEDURE initiate_dp_hold_wf(p_err_code    OUT NUMBER,
<<<<<<< .mine
		        p_err_message OUT VARCHAR2,
		        p_line_id     NUMBER,
		        p_item_key    OUT VARCHAR2,
		        p_user_key    OUT VARCHAR2
		        
		        ) IS
  
||||||| .r4749
            p_err_message OUT VARCHAR2,
            p_line_id     NUMBER,
            p_item_key    OUT VARCHAR2,
            p_user_key    OUT VARCHAR2

            ) IS

=======
                                p_err_message OUT VARCHAR2,
                                p_line_id     NUMBER,
                                p_item_key    OUT VARCHAR2,
                                p_user_key    OUT VARCHAR2
                                
                                ) IS
  
>>>>>>> .r4768
    l_itemkey VARCHAR2(30);
  BEGIN
    p_err_code    := 0;
    p_err_message := NULL;
  
    l_itemkey := p_line_id || '-' || to_char(SYSDATE, 'ddmmyy hh24miss');
  
    p_item_key := l_itemkey;
    p_user_key := p_line_id;
  
    wf_engine.createprocess(itemtype => g_item_type,
<<<<<<< .mine
		    itemkey  => l_itemkey,
		    user_key => p_line_id,
		    process  => g_hold_workflow_process);
  
||||||| .r4749
        itemkey  => l_itemkey,
        user_key => p_line_id,
        process  => g_hold_workflow_process);

=======
                            itemkey  => l_itemkey,
                            user_key => p_line_id,
                            process  => g_hold_workflow_process);
  
>>>>>>> .r4768
    wf_engine.setitemattrnumber(itemtype => g_item_type,
<<<<<<< .mine
		        itemkey  => l_itemkey,
		        aname    => 'LINE_ID',
		        avalue   => p_line_id);
  
||||||| .r4749
            itemkey  => l_itemkey,
            aname    => 'LINE_ID',
            avalue   => p_line_id);

=======
                                itemkey  => l_itemkey,
                                aname    => 'LINE_ID',
                                avalue   => p_line_id);
  
>>>>>>> .r4768
    -- START PROCESS
    wf_engine.startprocess(itemtype => g_item_type, itemkey => l_itemkey);
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'xxom_denied_parties_pkg.initiate_hold_pick_wf: Error initiate WF  :' ||
<<<<<<< .mine
	           SQLERRM;
||||||| .r4749
             SQLERRM;
=======
                       SQLERRM;
>>>>>>> .r4768
  END initiate_dp_hold_wf;

  ---------------------------------------------------
  -- set_attributes_wf
  ---------------------------------------------------

  PROCEDURE set_attributes_wf(itemtype  IN VARCHAR2,
<<<<<<< .mine
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2) IS
||||||| .r4749
          itemkey   IN VARCHAR2,
          actid     IN NUMBER,
          funcmode  IN VARCHAR2,
          resultout OUT NOCOPY VARCHAR2) IS
=======
                              itemkey   IN VARCHAR2,
                              actid     IN NUMBER,
                              funcmode  IN VARCHAR2,
                              resultout OUT NOCOPY VARCHAR2) IS
>>>>>>> .r4768
    l_line_id NUMBER;
    CURSOR c IS
      SELECT *
        FROM xxom_dp_locations_v t
       WHERE t.line_id = l_line_id
         AND rownum = 1;
  BEGIN
  
    -- set attributes
    l_line_id := wf_engine.getitemuserkey(itemtype => itemtype,
<<<<<<< .mine
			      itemkey  => itemkey);
  
||||||| .r4749
            itemkey  => itemkey);

=======
                                          itemkey  => itemkey);
  
>>>>>>> .r4768
    wf_engine.setitemattrnumber(itemtype => itemtype,
<<<<<<< .mine
		        itemkey  => itemkey,
		        aname    => 'LINE_ID',
		        avalue   => l_line_id);
  
||||||| .r4749
            itemkey  => itemkey,
            aname    => 'LINE_ID',
            avalue   => l_line_id);

=======
                                itemkey  => itemkey,
                                aname    => 'LINE_ID',
                                avalue   => l_line_id);
  
>>>>>>> .r4768
    wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		      itemkey  => itemkey,
		      aname    => 'APPROVER_USER_NAME',
		      avalue   => fnd_profile.value('XXOM_DP_RELEASE_APPROVER_ROLE'));
||||||| .r4749
          itemkey  => itemkey,
          aname    => 'APPROVER_USER_NAME',
          avalue   => fnd_profile.value('XXOM_DP_RELEASE_APPROVER_ROLE'));
=======
                              itemkey  => itemkey,
                              aname    => 'APPROVER_USER_NAME',
                              avalue   => fnd_profile.value('XXOM_DP_RELEASE_APPROVER_ROLE'));
>>>>>>> .r4768
    -- CC for approvals - with release option ( email list)
    wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		      itemkey  => itemkey,
		      aname    => 'APPROVER_CC_MAIL_LIST',
		      avalue   => fnd_profile.value('XXOM_DP_RELEASE_APPR_CC_MAIL_LIST'));
  
||||||| .r4749
          itemkey  => itemkey,
          aname    => 'APPROVER_CC_MAIL_LIST',
          avalue   => fnd_profile.value('XXOM_DP_RELEASE_APPR_CC_MAIL_LIST'));

=======
                              itemkey  => itemkey,
                              aname    => 'APPROVER_CC_MAIL_LIST',
                              avalue   => fnd_profile.value('XXOM_DP_RELEASE_APPR_CC_MAIL_LIST'));
  
>>>>>>> .r4768
    -- FYI about new hold on order (role name)
    wf_engine.setitemattrtext(itemtype => g_item_type,
<<<<<<< .mine
		      itemkey  => itemkey,
		      aname    => 'HOLD_FYI_ROLE_ALERT',
		      avalue   => fnd_global.user_name);
  
||||||| .r4749
          itemkey  => itemkey,
          aname    => 'HOLD_FYI_ROLE_ALERT',
          avalue   => fnd_global.user_name);

=======
                              itemkey  => itemkey,
                              aname    => 'HOLD_FYI_ROLE_ALERT',
                              avalue   => fnd_global.user_name);
  
>>>>>>> .r4768
    ------ release note for users
  
    wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		      itemkey  => itemkey,
		      aname    => 'DIST_ROLES',
		      avalue   => ',' || fnd_global.user_name || ',' ||
			      fnd_profile.value('XXOM_DP_RELEASE_DIST_ROLES'));
||||||| .r4749
          itemkey  => itemkey,
          aname    => 'DIST_ROLES',
          avalue   => ',' || fnd_global.user_name || ',' ||
            fnd_profile.value('XXOM_DP_RELEASE_DIST_ROLES'));
=======
                              itemkey  => itemkey,
                              aname    => 'DIST_ROLES',
                              avalue   => ',' || fnd_global.user_name || ',' ||
                                          fnd_profile.value('XXOM_DP_RELEASE_DIST_ROLES'));
>>>>>>> .r4768
    wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		      itemkey  => itemkey,
		      aname    => 'DIST_ROLES_TMP',
		      avalue   => ',' || fnd_global.user_name || ',' ||
			      fnd_profile.value('XXOM_DP_RELEASE_DIST_ROLES'));
  
    FOR i IN c
    LOOP
    
||||||| .r4749
          itemkey  => itemkey,
          aname    => 'DIST_ROLES_TMP',
          avalue   => ',' || fnd_global.user_name || ',' ||
            fnd_profile.value('XXOM_DP_RELEASE_DIST_ROLES'));

    FOR i IN c LOOP

=======
                              itemkey  => itemkey,
                              aname    => 'DIST_ROLES_TMP',
                              avalue   => ',' || fnd_global.user_name || ',' ||
                                          fnd_profile.value('XXOM_DP_RELEASE_DIST_ROLES'));
  
    FOR i IN c LOOP
    
>>>>>>> .r4768
      wf_engine.setitemattrnumber(itemtype => itemtype,
<<<<<<< .mine
		          itemkey  => itemkey,
		          aname    => 'HEADER_ID',
		          avalue   => i.header_id);
    
||||||| .r4749
              itemkey  => itemkey,
              aname    => 'HEADER_ID',
              avalue   => i.header_id);

=======
                                  itemkey  => itemkey,
                                  aname    => 'HEADER_ID',
                                  avalue   => i.header_id);
    
>>>>>>> .r4768
      wf_engine.setitemattrnumber(itemtype => itemtype,
<<<<<<< .mine
		          itemkey  => itemkey,
		          aname    => 'ORG_ID',
		          avalue   => i.org_id);
    
||||||| .r4749
              itemkey  => itemkey,
              aname    => 'ORG_ID',
              avalue   => i.org_id);

=======
                                  itemkey  => itemkey,
                                  aname    => 'ORG_ID',
                                  avalue   => i.org_id);
    
>>>>>>> .r4768
      wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		        itemkey  => itemkey,
		        aname    => 'ORDER_NUMBER',
		        avalue   => i.order_number);
    
||||||| .r4749
            itemkey  => itemkey,
            aname    => 'ORDER_NUMBER',
            avalue   => i.order_number);

=======
                                itemkey  => itemkey,
                                aname    => 'ORDER_NUMBER',
                                avalue   => i.order_number);
    
>>>>>>> .r4768
      wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		        itemkey  => itemkey,
		        aname    => 'CUSTOMER_NAME',
		        avalue   => i.sold_to);
    
||||||| .r4749
            itemkey  => itemkey,
            aname    => 'CUSTOMER_NAME',
            avalue   => i.sold_to);

=======
                                itemkey  => itemkey,
                                aname    => 'CUSTOMER_NAME',
                                avalue   => i.sold_to);
    
>>>>>>> .r4768
    END LOOP;
  
    resultout := wf_engine.eng_completed;
  
  END;

  ---------------------------------------------
  -- get_next_dist_role
  --------------------------------------------

  PROCEDURE get_next_dist_role(itemtype  IN VARCHAR2,
<<<<<<< .mine
		       itemkey   IN VARCHAR2,
		       actid     IN NUMBER,
		       funcmode  IN VARCHAR2,
		       resultout OUT NOCOPY VARCHAR2) IS
  
||||||| .r4749
           itemkey   IN VARCHAR2,
           actid     IN NUMBER,
           funcmode  IN VARCHAR2,
           resultout OUT NOCOPY VARCHAR2) IS

=======
                               itemkey   IN VARCHAR2,
                               actid     IN NUMBER,
                               funcmode  IN VARCHAR2,
                               resultout OUT NOCOPY VARCHAR2) IS
  
>>>>>>> .r4768
    l_dist_roles VARCHAR2(1000);
    l_dist_role  VARCHAR2(50);
    CURSOR c(c_str VARCHAR2) IS
      SELECT *
<<<<<<< .mine
      FROM   (SELECT TRIM(substr(txt,
		         instr(txt, ',', 1, LEVEL) + 1,
		         instr(txt, ',', 1, LEVEL + 1) -
		         instr(txt, ',', 1, LEVEL) - 1)) AS token
	  FROM   (SELECT ',' || c_str || ',' AS txt
	          FROM   dual)
	  CONNECT BY LEVEL <=
		 length(txt) - length(REPLACE(txt, ',', '')) - 1)
      WHERE  token IS NOT NULL;
||||||| .r4749
      FROM   (SELECT TRIM(substr(txt,
             instr(txt, ',', 1, LEVEL) + 1,
             instr(txt, ',', 1, LEVEL + 1) -
             instr(txt, ',', 1, LEVEL) - 1)) AS token
    FROM   (SELECT ',' || c_str || ',' AS txt
            FROM   dual)
    CONNECT BY LEVEL <=
     length(txt) - length(REPLACE(txt, ',', '')) - 1)
      WHERE  token IS NOT NULL;
=======
        FROM (SELECT TRIM(substr(txt,
                                 instr(txt, ',', 1, LEVEL) + 1,
                                 instr(txt, ',', 1, LEVEL + 1) -
                                 instr(txt, ',', 1, LEVEL) - 1)) AS token
                FROM (SELECT ',' || c_str || ',' AS txt FROM dual)
              CONNECT BY LEVEL <=
                         length(txt) - length(REPLACE(txt, ',', '')) - 1)
       WHERE token IS NOT NULL;
>>>>>>> .r4768
  BEGIN
  
    l_dist_roles := wf_engine.getitemattrtext(itemtype => itemtype,
<<<<<<< .mine
			          itemkey  => itemkey,
			          aname    => 'DIST_ROLES_TMP');
||||||| .r4749
                itemkey  => itemkey,
                aname    => 'DIST_ROLES_TMP');
=======
                                              itemkey  => itemkey,
                                              aname    => 'DIST_ROLES_TMP');
>>>>>>> .r4768
    OPEN c(l_dist_roles);
  
    FETCH c
      INTO l_dist_role;
    IF c%FOUND THEN
      wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		        itemkey  => itemkey,
		        aname    => 'DIST_ROLE_NAME',
		        avalue   => l_dist_role);
    
||||||| .r4749
            itemkey  => itemkey,
            aname    => 'DIST_ROLE_NAME',
            avalue   => l_dist_role);

=======
                                itemkey  => itemkey,
                                aname    => 'DIST_ROLE_NAME',
                                avalue   => l_dist_role);
    
>>>>>>> .r4768
      l_dist_roles := REPLACE(l_dist_roles, l_dist_role);
    
      wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		        itemkey  => itemkey,
		        aname    => 'DIST_ROLES_TMP',
		        avalue   => l_dist_roles);
    
||||||| .r4749
            itemkey  => itemkey,
            aname    => 'DIST_ROLES_TMP',
            avalue   => l_dist_roles);

=======
                                itemkey  => itemkey,
                                aname    => 'DIST_ROLES_TMP',
                                avalue   => l_dist_roles);
    
>>>>>>> .r4768
      resultout := wf_engine.eng_completed || ':Y';
    
    ELSE
      resultout := wf_engine.eng_completed || ':N';
    
    END IF;
    CLOSE c;
  END;

  ------------------------------------------
  -- is_approve_notification_exists
  -- used in item_type xxdpapr
  ------------------------------------------
  PROCEDURE is_approve_notification_exists(itemtype  IN VARCHAR2,
<<<<<<< .mine
			       itemkey   IN VARCHAR2,
			       actid     IN NUMBER,
			       funcmode  IN VARCHAR2,
			       resultout OUT NOCOPY VARCHAR2) IS
||||||| .r4749
             itemkey   IN VARCHAR2,
             actid     IN NUMBER,
             funcmode  IN VARCHAR2,
             resultout OUT NOCOPY VARCHAR2) IS
=======
                                           itemkey   IN VARCHAR2,
                                           actid     IN NUMBER,
                                           funcmode  IN VARCHAR2,
                                           resultout OUT NOCOPY VARCHAR2) IS
>>>>>>> .r4768
    l_header_id NUMBER;
    l_tmp       VARCHAR2(1);
    CURSOR c IS
      SELECT 'Y'
<<<<<<< .mine
      FROM   wf_notifications         t,
	 wf_item_attribute_values ta
      WHERE  ta.item_type = t.message_type
      AND    t.item_key = ta.item_key
      AND    t.message_type = 'XXDPAPR'
      AND    t.message_name = 'DP_APR_RLS_MSG'
      AND    t.status = 'OPEN'
      AND    ta.name = 'HEADER_ID'
      AND    ta.number_value = l_header_id;
||||||| .r4749
      FROM   wf_notifications         t,
   wf_item_attribute_values ta
      WHERE  ta.item_type = t.message_type
      AND    t.item_key = ta.item_key
      AND    t.message_type = 'XXDPAPR'
      AND    t.message_name = 'DP_APR_RLS_MSG'
      AND    t.status = 'OPEN'
      AND    ta.name = 'HEADER_ID'
      AND    ta.number_value = l_header_id;
=======
        FROM wf_notifications t, wf_item_attribute_values ta
       WHERE ta.item_type = t.message_type
         AND t.item_key = ta.item_key
         AND t.message_type = 'XXDPAPR'
         AND t.message_name = 'DP_APR_RLS_MSG'
         AND t.status = 'OPEN'
         AND ta.name = 'HEADER_ID'
         AND ta.number_value = l_header_id;
>>>>>>> .r4768
    --  AND ta.item_key != itemkey;
  
  BEGIN
    l_header_id := wf_engine.getitemattrtext(itemtype => itemtype,
<<<<<<< .mine
			         itemkey  => itemkey,
			         aname    => 'HEADER_ID');
  
||||||| .r4749
               itemkey  => itemkey,
               aname    => 'HEADER_ID');

=======
                                             itemkey  => itemkey,
                                             aname    => 'HEADER_ID');
  
>>>>>>> .r4768
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    resultout := wf_engine.eng_completed || ':' || nvl(l_tmp, 'N');
  END;

  ------------------------------------------
  -- WAIT2DP_APPROVAL
  -- used in item_type OEOL : process XX Call DP Workflow
  -- used to avoid proceed wf when open notification exists
  ------------------------------------------
  PROCEDURE wait2dp_approval(itemtype  IN VARCHAR2,
<<<<<<< .mine
		     itemkey   IN VARCHAR2,
		     actid     IN NUMBER,
		     funcmode  IN VARCHAR2,
		     resultout OUT NOCOPY VARCHAR2) IS
  
||||||| .r4749
         itemkey   IN VARCHAR2,
         actid     IN NUMBER,
         funcmode  IN VARCHAR2,
         resultout OUT NOCOPY VARCHAR2) IS

=======
                             itemkey   IN VARCHAR2,
                             actid     IN NUMBER,
                             funcmode  IN VARCHAR2,
                             resultout OUT NOCOPY VARCHAR2) IS
  
>>>>>>> .r4768
    l_hold_exists VARCHAR2(1);
  
  BEGIN
  
    l_hold_exists := is_open_dp_hold_exists(to_number(itemkey));
  
    resultout := wf_engine.eng_completed || ':' || l_hold_exists;
  
  END;
  ------------------------------------------
  -- is_open_dp_hold_exists
  --
  -- check if open hold exists
  ------------------------------------------
  FUNCTION is_open_dp_hold_exists(p_line_id NUMBER) RETURN VARCHAR2 IS
    l_header_id NUMBER;
    l_tmp       NUMBER;
    CURSOR c IS
      SELECT 1
<<<<<<< .mine
      FROM   oe_order_holds_all  oh,
	 oe_hold_sources_all hs,
	 oe_hold_releases    hr,
	 oe_hold_definitions hd
      
      WHERE  oh.hold_source_id = hs.hold_source_id
      AND    hs.hold_id = hd.hold_id
      AND    oh.hold_release_id = hr.hold_release_id(+)
      AND    hs.org_id = oh.org_id
      AND    hd.hold_id = fnd_profile.value('XXOM_DP_HOLD_ID')
      AND    hs.released_flag = 'N'
      AND    oh.header_id = l_header_id;
||||||| .r4749
      FROM   oe_order_holds_all  oh,
   oe_hold_sources_all hs,
   oe_hold_releases    hr,
   oe_hold_definitions hd

      WHERE  oh.hold_source_id = hs.hold_source_id
      AND    hs.hold_id = hd.hold_id
      AND    oh.hold_release_id = hr.hold_release_id(+)
      AND    hs.org_id = oh.org_id
      AND    hd.hold_id = fnd_profile.value('XXOM_DP_HOLD_ID')
      AND    hs.released_flag = 'N'
      AND    oh.header_id = l_header_id;
=======
        FROM oe_order_holds_all  oh,
             oe_hold_sources_all hs,
             oe_hold_releases    hr,
             oe_hold_definitions hd
      
       WHERE oh.hold_source_id = hs.hold_source_id
         AND hs.hold_id = hd.hold_id
         AND oh.hold_release_id = hr.hold_release_id(+)
         AND hs.org_id = oh.org_id
         AND hd.hold_id = fnd_profile.value('XXOM_DP_HOLD_ID')
         AND hs.released_flag = 'N'
         AND oh.header_id = l_header_id;
>>>>>>> .r4768
    /*  UNION ALL
    SELECT 1
      FROM oe_order_holds_all  oh,
           oe_hold_sources_all hs,
           oe_hold_releases    hr,
           oe_hold_definitions hd
    
     WHERE oh.hold_source_id = hs.hold_source_id
       AND hs.hold_id = hd.hold_id
       AND oh.hold_release_id = hr.hold_release_id(+)
       AND hs.org_id = oh.org_id
       AND hd.hold_id = fnd_profile.value('XXOM_DP_HOLD_ID')
       AND hs.released_flag = 'Y'
       AND oh.header_id = l_header_id
       AND SYSDATE - hs.last_update_date <=
           fnd_profile.value('XXOM_DP_DAYS_TO_REHOLD');*/
  
  BEGIN
    SELECT header_id
<<<<<<< .mine
    INTO   l_header_id
    FROM   oe_order_lines_all t
    WHERE  t.line_id = p_line_id;
  
||||||| .r4749
    INTO   l_header_id
    FROM   oe_order_lines_all t
    WHERE  t.line_id = p_line_id;

=======
      INTO l_header_id
      FROM oe_order_lines_all t
     WHERE t.line_id = p_line_id;
  
>>>>>>> .r4768
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    IF nvl(l_tmp, 0) = 0 THEN
      RETURN 'N';
    ELSE
      RETURN 'Y';
    END IF;
  
  END;

  --
  -----------------------------------------
  -- release_notification
  --
  -- called from db trigger  for aftre dp release which is done from application (not notification)
  -- the release will continue wf and will send release notifications
  -----------------------------------------

  PROCEDURE release_notification(p_order_header_id NUMBER) IS
    p_print_flag BOOLEAN;
    --concurrent_request variables
    l_request_id NUMBER;
    l_result     BOOLEAN;
  
    CURSOR c_header IS
      SELECT t.notification_id
<<<<<<< .mine
      
      FROM   wf_notifications         t,
	 wf_item_attribute_values ta
      WHERE  ta.item_type = t.message_type
      AND    t.item_key = ta.item_key
      AND    t.message_type = 'XXDPAPR'
      AND    t.message_name = 'DP_APR_RLS_MSG'
      AND    t.status = 'OPEN'
      AND    ta.name = 'HEADER_ID'
      AND    ta.number_value = p_order_header_id
      AND    rownum = 1;
  
||||||| .r4749

      FROM   wf_notifications         t,
   wf_item_attribute_values ta
      WHERE  ta.item_type = t.message_type
      AND    t.item_key = ta.item_key
      AND    t.message_type = 'XXDPAPR'
      AND    t.message_name = 'DP_APR_RLS_MSG'
      AND    t.status = 'OPEN'
      AND    ta.name = 'HEADER_ID'
      AND    ta.number_value = p_order_header_id
      AND    rownum = 1;

=======
      
        FROM wf_notifications t, wf_item_attribute_values ta
       WHERE ta.item_type = t.message_type
         AND t.item_key = ta.item_key
         AND t.message_type = 'XXDPAPR'
         AND t.message_name = 'DP_APR_RLS_MSG'
         AND t.status = 'OPEN'
         AND ta.name = 'HEADER_ID'
         AND ta.number_value = p_order_header_id
         AND rownum = 1;
  
>>>>>>> .r4768
  BEGIN
<<<<<<< .mine
  
    FOR i IN c_header
    LOOP
    
||||||| .r4749

    FOR i IN c_header LOOP

=======
  
    FOR i IN c_header LOOP
    
>>>>>>> .r4768
      p_print_flag := fnd_request.set_print_options(copies => 0 -- copies
<<<<<<< .mine
				    );
    
||||||| .r4749
            );

=======
                                                    );
    
>>>>>>> .r4768
      l_result     := fnd_request.set_mode(TRUE);
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
<<<<<<< .mine
				 program     => 'XXOMDPRLS',
				 description => NULL,
				 start_time  => SYSDATE +
					    (1 / 24 / 60),
				 sub_request => FALSE,
				 argument1   => p_order_header_id);
    
||||||| .r4749
         program     => 'XXOMDPRLS',
         description => NULL,
         start_time  => SYSDATE +
              (1 / 24 / 60),
         sub_request => FALSE,
         argument1   => p_order_header_id);

=======
                                                 program     => 'XXOMDPRLS',
                                                 description => NULL,
                                                 start_time  => SYSDATE +
                                                                (1 / 24 / 60),
                                                 sub_request => FALSE,
                                                 argument1   => p_order_header_id);
    
>>>>>>> .r4768
    END LOOP;
  END;

  -----------------------------------------------------
  -- release_notification_conc
  -----------------------------------------------------
  PROCEDURE release_notification_conc(p_err_code        OUT NUMBER,
<<<<<<< .mine
			  p_err_message     OUT VARCHAR2,
			  p_order_header_id NUMBER) IS
  
||||||| .r4749
        p_err_message     OUT VARCHAR2,
        p_order_header_id NUMBER) IS

=======
                                      p_err_message     OUT VARCHAR2,
                                      p_order_header_id NUMBER) IS
  
>>>>>>> .r4768
    CURSOR c_header IS
      SELECT t.notification_id
<<<<<<< .mine
      
      FROM   wf_notifications         t,
	 wf_item_attribute_values ta
      WHERE  ta.item_type = t.message_type
      AND    t.item_key = ta.item_key
      AND    t.message_type = 'XXDPAPR'
      AND    t.message_name = 'DP_APR_RLS_MSG'
      AND    t.status = 'OPEN'
      AND    ta.name = 'HEADER_ID'
      AND    ta.number_value = p_order_header_id;
||||||| .r4749

      FROM   wf_notifications         t,
   wf_item_attribute_values ta
      WHERE  ta.item_type = t.message_type
      AND    t.item_key = ta.item_key
      AND    t.message_type = 'XXDPAPR'
      AND    t.message_name = 'DP_APR_RLS_MSG'
      AND    t.status = 'OPEN'
      AND    ta.name = 'HEADER_ID'
      AND    ta.number_value = p_order_header_id;
=======
      
        FROM wf_notifications t, wf_item_attribute_values ta
       WHERE ta.item_type = t.message_type
         AND t.item_key = ta.item_key
         AND t.message_type = 'XXDPAPR'
         AND t.message_name = 'DP_APR_RLS_MSG'
         AND t.status = 'OPEN'
         AND ta.name = 'HEADER_ID'
         AND ta.number_value = p_order_header_id;
>>>>>>> .r4768
  BEGIN
<<<<<<< .mine
  
    FOR i IN c_header
    LOOP
||||||| .r4749

    FOR i IN c_header LOOP
=======
  
    FOR i IN c_header LOOP
>>>>>>> .r4768
      wf_notification.setattrtext(nid    => i.notification_id,
<<<<<<< .mine
		          aname  => 'RESULT',
		          avalue => 'RELEASE');
||||||| .r4749
              aname  => 'RESULT',
              avalue => 'RELEASE');
=======
                                  aname  => 'RESULT',
                                  avalue => 'RELEASE');
>>>>>>> .r4768
      wf_notification.respond(i.notification_id,
<<<<<<< .mine
		      'Release by ' || fnd_global.user_name,
		      fnd_global.user_name);
||||||| .r4749
          'Release by ' || fnd_global.user_name,
          fnd_global.user_name);
=======
                              'Release by ' || fnd_global.user_name,
                              fnd_global.user_name);
>>>>>>> .r4768
      COMMIT;
    
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;

  ----------------------------------------------
  -- initiate_hold_Pick_wf
  ----------------------------------------------
  PROCEDURE initiate_hold_pick_wf(p_err_code     OUT NUMBER,
<<<<<<< .mine
		          p_err_message  OUT VARCHAR2,
		          p_delivery_rec c_delivery%ROWTYPE,
		          p_item_key     OUT VARCHAR2,
		          p_user_key     OUT VARCHAR2
		          
		          ) IS
  
||||||| .r4749
              p_err_message  OUT VARCHAR2,
              p_delivery_rec c_delivery%ROWTYPE,
              p_item_key     OUT VARCHAR2,
              p_user_key     OUT VARCHAR2

              ) IS

=======
                                  p_err_message  OUT VARCHAR2,
                                  p_delivery_rec c_delivery%ROWTYPE,
                                  p_item_key     OUT VARCHAR2,
                                  p_user_key     OUT VARCHAR2
                                  
                                  ) IS
  
>>>>>>> .r4768
    l_itemkey VARCHAR2(30);
  BEGIN
    p_err_code := 0;
  
    l_itemkey := p_delivery_rec.delivery_id || '-' ||
<<<<<<< .mine
	     p_delivery_rec.delivery_detail_id || '-' ||
	     to_char(SYSDATE, 'ddmmyy hh24miss');
  
||||||| .r4749
       p_delivery_rec.delivery_detail_id || '-' ||
       to_char(SYSDATE, 'ddmmyy hh24miss');

=======
                 p_delivery_rec.delivery_detail_id || '-' ||
                 to_char(SYSDATE, 'ddmmyy hh24miss');
  
>>>>>>> .r4768
    p_item_key := l_itemkey;
    p_user_key := p_delivery_rec.source_line_id;
  
    wf_engine.createprocess(itemtype => g_item_type,
<<<<<<< .mine
		    itemkey  => l_itemkey,
		    user_key => p_delivery_rec.source_line_id,
		    process  => g_hold_workflow_process);
  
||||||| .r4749
        itemkey  => l_itemkey,
        user_key => p_delivery_rec.source_line_id,
        process  => g_hold_workflow_process);

=======
                            itemkey  => l_itemkey,
                            user_key => p_delivery_rec.source_line_id,
                            process  => g_hold_workflow_process);
  
>>>>>>> .r4768
    wf_engine.setitemattrnumber(itemtype => g_item_type,
<<<<<<< .mine
		        itemkey  => l_itemkey,
		        aname    => 'LINE_ID',
		        avalue   => p_delivery_rec.source_line_id);
  
||||||| .r4749
            itemkey  => l_itemkey,
            aname    => 'LINE_ID',
            avalue   => p_delivery_rec.source_line_id);

=======
                                itemkey  => l_itemkey,
                                aname    => 'LINE_ID',
                                avalue   => p_delivery_rec.source_line_id);
  
>>>>>>> .r4768
    wf_engine.setitemattrtext(itemtype => g_item_type,
<<<<<<< .mine
		      itemkey  => l_itemkey,
		      aname    => 'DELIVERY_NOTE',
		      avalue   => '/ Delivery Name ' ||
			      p_delivery_rec.delivery_id);
  
||||||| .r4749
          itemkey  => l_itemkey,
          aname    => 'DELIVERY_NOTE',
          avalue   => '/ Delivery Name ' ||
            p_delivery_rec.delivery_id);

=======
                              itemkey  => l_itemkey,
                              aname    => 'DELIVERY_NOTE',
                              avalue   => '/ Delivery Name ' ||
                                          p_delivery_rec.delivery_id);
  
>>>>>>> .r4768
    -- START PROCESS
    wf_engine.startprocess(itemtype => g_item_type, itemkey => l_itemkey);
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'xxom_denied_parties_pkg.initiate_hold_pick_wf: Error initiate WF  :' ||
<<<<<<< .mine
	           SQLERRM;
||||||| .r4749
             SQLERRM;
=======
                       SQLERRM;
>>>>>>> .r4768
  END;

  --------------------------------------------------------------------
  --  name:            pick_release_delivery_check
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   xx
  --------------------------------------------------------------------
  --  purpose :        check deliveries according to batch id
  --                   called from db trigger XX_fnd_concurrent_requests_TRG
  --
  --                   if  FDM item and no open hold exists on order
  --                   call XXDPAPR WF
  --
  --                   when no errors (including wf error) , release pick release seeded program from hold
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/xxxx  Yuval Tal         initial build
  --  1.1  22/04/2013  Dalit A. Raviv    take out the handle of the release hold on the program
  --                                     and change out param order
  --------------------------------------------------------------------
  PROCEDURE pick_release_delivery_check(p_err_message OUT VARCHAR2,
<<<<<<< .mine
			    p_err_code    OUT NUMBER,
			    p_batch_id    NUMBER,
			    p_request_id  NUMBER) IS
  
||||||| .r4749
          p_err_code    OUT NUMBER,
          p_batch_id    NUMBER,
          p_request_id  NUMBER) IS

=======
                                        p_err_code    OUT NUMBER,
                                        p_batch_id    NUMBER,
                                        p_request_id  NUMBER) IS
  
>>>>>>> .r4768
    l_err_flag    NUMBER := 0;
    l_err_message VARCHAR2(32000);
    l_err_code    NUMBER;
    --
    l_item_key  VARCHAR2(50);
    l_user_key  VARCHAR2(50);
    l_wf_status VARCHAR2(50);
    --
    local_exception EXCEPTION;
    l_delivery_count NUMBER := 0;
  BEGIN
    p_err_code := 0;
  
    --  1.1  22/04/2013  Dalit A. Raviv
    /*
    IF fnd_profile.value('XXOM_DP_ENABLE_CHECK') != 'Y' THEN
      p_err_message := 'Denied Party check is disabled';
      fnd_file.put_line(fnd_file.log, p_err_message);
      -- release seeded oracle program from hold
      UPDATE fnd_concurrent_requests t
         SET t.hold_flag = 'N'
       WHERE t.request_id = p_request_id;
      COMMIT;
    
      RETURN;
    END IF;*/
    -- end 1.1
  
    fnd_file.put_line(fnd_file.log, 'Start DP Check');
  
    init_globals;
<<<<<<< .mine
  
    FOR i IN c_delivery(p_batch_id)
    LOOP
||||||| .r4749

    FOR i IN c_delivery(p_batch_id) LOOP
=======
  
    FOR i IN c_delivery(p_batch_id) LOOP
>>>>>>> .r4768
      l_delivery_count := l_delivery_count + 1;
      IF i.source_code = 'OE' THEN
        -- is FDM item
        IF is_fdm_item(i.inventory_item_id) = 'Y' THEN
          -- check dp
          fnd_file.put_line(fnd_file.log,
<<<<<<< .mine
		    to_char(SYSDATE, 'hh24:mi') ||
		    ' Check DP For FDM Item :' || 'delivery_id=' ||
		    i.delivery_id || ' delivery_detail_id=' ||
		    i.delivery_detail_id || ' order line id=' ||
		    i.source_line_id || ' inventory_item_id=' ||
		    i.inventory_item_id);
        
||||||| .r4749
        to_char(SYSDATE, 'hh24:mi') ||
        ' Check DP For FDM Item :' || 'delivery_id=' ||
        i.delivery_id || ' delivery_detail_id=' ||
        i.delivery_detail_id || ' order line id=' ||
        i.source_line_id || ' inventory_item_id=' ||
        i.inventory_item_id);

=======
                            to_char(SYSDATE, 'hh24:mi') ||
                            ' Check DP For FDM Item :' || 'delivery_id=' ||
                            i.delivery_id || ' delivery_detail_id=' ||
                            i.delivery_detail_id || ' order line id=' ||
                            i.source_line_id || ' inventory_item_id=' ||
                            i.inventory_item_id);
        
>>>>>>> .r4768
          -- Is hold exists: no need to check when
          -- 1.  if open hold exists
          -- 2.  if DP hold exists and was released in the last x DAYS
          IF is_open_dp_hold_exists(i.source_line_id) = 'N' THEN
<<<<<<< .mine
	BEGIN
	  ------------------------------------
	  -- start workflow
	  -----------------------------------
	  fnd_file.put_line(fnd_file.log,
		        'Start DP WF Approval : item_type =' ||
		        g_item_type || ' Process=' ||
		        g_hold_workflow_process);
	
	  initiate_hold_pick_wf(l_err_code,
			l_err_message,
			i,
			l_item_key,
			l_user_key);
	
	  IF l_err_code = 1 THEN
	    RAISE local_exception;
	  ELSE
	    fnd_file.put_line(fnd_file.log,
		          to_char(SYSDATE, 'hh24:mi') ||
		          ' WF Started....item key/user key =' ||
		          l_item_key || '/' || l_user_key);
	  
	    --- check wf status
	    SELECT wf_fwkmon.getitemstatus(workflowitemeo.item_type,
			           workflowitemeo.item_key,
			           workflowitemeo.end_date,
			           workflowitemeo.root_activity,
			           workflowitemeo.root_activity_version)
	    INTO   l_wf_status
	    FROM   wf_items workflowitemeo
	    WHERE  item_type = g_item_type
	    AND    item_key = l_item_key;
	  
	    IF l_wf_status = 'ERROR' THEN
	      l_err_message := 'WF in status ERROR please call Admin';
	      RAISE local_exception;
	    END IF;
	  END IF;
	  -----------------------
	EXCEPTION
	  WHEN local_exception THEN
	  
	    p_err_code    := 1;
	    l_err_flag    := 1;
	    p_err_message := l_err_message;
	  
	    fnd_file.put_line(fnd_file.log,
		          to_char(SYSDATE, 'hh24:mi') || ' Error: ' ||
		          p_err_message || ' ' || SQLERRM);
	  
	    xxobjt_wf_mail.send_mail_text(p_err_code    => l_err_code,
			          p_err_message => l_err_message,
			          p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
			          p_subject     => 'Pick Release DP Error',
			          p_body_text   => 'Error in xxom_denied_parties_pkg.pick_release_delivery_check : ' ||
					   chr(10) ||
					   'When trying to submit DP WF Check' ||
					   chr(10) ||
					   'request_id=' ||
					   p_request_id ||
					   chr(10) ||
					   'batch_id=' ||
					   p_batch_id ||
					   chr(10) ||
					   p_err_message);
	  
	  WHEN OTHERS THEN
	    p_err_code    := 1;
	    p_err_message := SQLERRM;
	    fnd_file.put_line(fnd_file.log,
		          to_char(SYSDATE, 'hh24:mi') || ' Error:' ||
		          p_err_message);
	  
	    xxobjt_wf_mail.send_mail_text(p_err_code    => l_err_code,
			          p_err_message => l_err_message,
			          p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
			          p_subject     => 'Denied Parties Check : Pick Release Error',
			          p_body_text   => 'Error in xxom_denied_parties_pkg.pick_release_delivery_check : ' ||
					   chr(10) ||
					   'request_id=' ||
					   p_request_id ||
					   chr(10) ||
					   ' batch_id=' ||
					   p_batch_id ||
					   chr(10) ||
					   p_err_message);
	  
	END;
||||||| .r4749
  BEGIN
    ------------------------------------
    -- start workflow
    -----------------------------------
    fnd_file.put_line(fnd_file.log,
            'Start DP WF Approval : item_type =' ||
            g_item_type || ' Process=' ||
            g_hold_workflow_process);

    initiate_hold_pick_wf(l_err_code,
      l_err_message,
      i,
      l_item_key,
      l_user_key);

    IF l_err_code = 1 THEN
      RAISE local_exception;
    ELSE
      fnd_file.put_line(fnd_file.log,
              to_char(SYSDATE, 'hh24:mi') ||
              ' WF Started....item key/user key =' ||
              l_item_key || '/' || l_user_key);

      --- check wf status
      SELECT wf_fwkmon.getitemstatus(workflowitemeo.item_type,
                 workflowitemeo.item_key,
                 workflowitemeo.end_date,
                 workflowitemeo.root_activity,
                 workflowitemeo.root_activity_version)
      INTO   l_wf_status
      FROM   wf_items workflowitemeo
      WHERE  item_type = g_item_type
      AND    item_key = l_item_key;

      IF l_wf_status = 'ERROR' THEN
        l_err_message := 'WF in status ERROR please call Admin';
        RAISE local_exception;
      END IF;
    END IF;
    -----------------------
  EXCEPTION
    WHEN local_exception THEN

      p_err_code    := 1;
      l_err_flag    := 1;
      p_err_message := l_err_message;

      fnd_file.put_line(fnd_file.log,
              to_char(SYSDATE, 'hh24:mi') || ' Error: ' ||
              p_err_message || ' ' || SQLERRM);

      xxobjt_wf_mail.send_mail_text(p_err_code    => l_err_code,
                p_err_message => l_err_message,
                p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                p_subject     => 'Pick Release DP Error',
                p_body_text   => 'Error in xxom_denied_parties_pkg.pick_release_delivery_check : ' ||
             chr(10) ||
             'When trying to submit DP WF Check' ||
             chr(10) ||
             'request_id=' ||
             p_request_id ||
             chr(10) ||
             'batch_id=' ||
             p_batch_id ||
             chr(10) ||
             p_err_message);

    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
      fnd_file.put_line(fnd_file.log,
              to_char(SYSDATE, 'hh24:mi') || ' Error:' ||
              p_err_message);

      xxobjt_wf_mail.send_mail_text(p_err_code    => l_err_code,
                p_err_message => l_err_message,
                p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                p_subject     => 'Denied Parties Check : Pick Release Error',
                p_body_text   => 'Error in xxom_denied_parties_pkg.pick_release_delivery_check : ' ||
             chr(10) ||
             'request_id=' ||
             p_request_id ||
             chr(10) ||
             ' batch_id=' ||
             p_batch_id ||
             chr(10) ||
             p_err_message);

  END;
=======
            BEGIN
              ------------------------------------
              -- start workflow
              -----------------------------------
              fnd_file.put_line(fnd_file.log,
                                'Start DP WF Approval : item_type =' ||
                                g_item_type || ' Process=' ||
                                g_hold_workflow_process);
            
              initiate_hold_pick_wf(l_err_code,
                                    l_err_message,
                                    i,
                                    l_item_key,
                                    l_user_key);
            
              IF l_err_code = 1 THEN
                RAISE local_exception;
              ELSE
                fnd_file.put_line(fnd_file.log,
                                  to_char(SYSDATE, 'hh24:mi') ||
                                  ' WF Started....item key/user key =' ||
                                  l_item_key || '/' || l_user_key);
              
                --- check wf status
                SELECT wf_fwkmon.getitemstatus(workflowitemeo.item_type,
                                               workflowitemeo.item_key,
                                               workflowitemeo.end_date,
                                               workflowitemeo.root_activity,
                                               workflowitemeo.root_activity_version)
                  INTO l_wf_status
                  FROM wf_items workflowitemeo
                 WHERE item_type = g_item_type
                   AND item_key = l_item_key;
              
                IF l_wf_status = 'ERROR' THEN
                  l_err_message := 'WF in status ERROR please call Admin';
                  RAISE local_exception;
                END IF;
              END IF;
              -----------------------
            EXCEPTION
              WHEN local_exception THEN
              
                p_err_code    := 1;
                l_err_flag    := 1;
                p_err_message := l_err_message;
              
                fnd_file.put_line(fnd_file.log,
                                  to_char(SYSDATE, 'hh24:mi') || ' Error: ' ||
                                  p_err_message || ' ' || SQLERRM);
              
                xxobjt_wf_mail.send_mail_text(p_err_code    => l_err_code,
                                              p_err_message => l_err_message,
                                              p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                              p_subject     => 'Pick Release DP Error',
                                              p_body_text   => 'Error in xxom_denied_parties_pkg.pick_release_delivery_check : ' ||
                                                               chr(10) ||
                                                               'When trying to submit DP WF Check' ||
                                                               chr(10) ||
                                                               'request_id=' ||
                                                               p_request_id ||
                                                               chr(10) ||
                                                               'batch_id=' ||
                                                               p_batch_id ||
                                                               chr(10) ||
                                                               p_err_message);
              
              WHEN OTHERS THEN
                p_err_code    := 1;
                p_err_message := SQLERRM;
                fnd_file.put_line(fnd_file.log,
                                  to_char(SYSDATE, 'hh24:mi') || ' Error:' ||
                                  p_err_message);
              
                xxobjt_wf_mail.send_mail_text(p_err_code    => l_err_code,
                                              p_err_message => l_err_message,
                                              p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                              p_subject     => 'Denied Parties Check : Pick Release Error',
                                              p_body_text   => 'Error in xxom_denied_parties_pkg.pick_release_delivery_check : ' ||
                                                               chr(10) ||
                                                               'request_id=' ||
                                                               p_request_id ||
                                                               chr(10) ||
                                                               ' batch_id=' ||
                                                               p_batch_id ||
                                                               chr(10) ||
                                                               p_err_message);
              
            END;
>>>>>>> .r4768
          ELSE
<<<<<<< .mine
	fnd_file.put_line(fnd_file.log,
		      to_char(SYSDATE, 'hh24:mi') ||
		      ' Open DP Hold Already Exists Or Hold was released in Last ' ||
		      fnd_profile.value('XXOM_DP_DAYS_TO_REHOLD') ||
		      ' days... No need to submit DP Workflow');
||||||| .r4749
  fnd_file.put_line(fnd_file.log,
          to_char(SYSDATE, 'hh24:mi') ||
          ' Open DP Hold Already Exists Or Hold was released in Last ' ||
          fnd_profile.value('XXOM_DP_DAYS_TO_REHOLD') ||
          ' days... No need to submit DP Workflow');
=======
            fnd_file.put_line(fnd_file.log,
                              to_char(SYSDATE, 'hh24:mi') ||
                              ' Open DP Hold Already Exists Or Hold was released in Last ' ||
                              fnd_profile.value('XXOM_DP_DAYS_TO_REHOLD') ||
                              ' days... No need to submit DP Workflow');
>>>>>>> .r4768
          END IF; -- dp hold exists
        END IF; -- fdm item
      END IF; -- i.source_code = 'OE'
    END LOOP;
  
    fnd_file.put_line(fnd_file.log,
<<<<<<< .mine
	          l_delivery_count || ' Records were checked');
  
||||||| .r4749
            l_delivery_count || ' Records were checked');

=======
                      l_delivery_count || ' Records were checked');
  
>>>>>>> .r4768
    -- release concurrent  if success
    --  1.1  22/04/2013  Dalit A. Raviv
    /*
    IF l_err_flag = 0 THEN
      p_err_code := 1;
      UPDATE fnd_concurrent_requests t
         SET t.hold_flag = 'N'
       WHERE t.request_id = p_request_id;
      COMMIT;
    END IF;*/
  END;

  ----------------------------------------------
  -- submit_check_pick_conc
  --
  -- called from db trigger XX_fnd_concurrent_requests_TRG
  -- concurrent will activate plsql program : xxom_denied_parties_pkg.pick_release_delivery_check
  -- check DP for relevant deliveries
  --------------------------------------------

<<<<<<< .mine
  PROCEDURE submit_check_pick_conc(p_request_id NUMBER,
		           p_batch_id   NUMBER) IS
  
||||||| .r4749
  PROCEDURE submit_check_pick_conc(p_request_id NUMBER,
               p_batch_id   NUMBER) IS

=======
  PROCEDURE submit_check_pick_conc(p_request_id NUMBER, p_batch_id NUMBER) IS
  
>>>>>>> .r4768
    l_print_flag BOOLEAN;
    --concurrent_request variables
    l_request_id NUMBER;
  
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
  
    --fnd_global.APPS_INITIALIZE(3850,50623,660,0,-1);
  
    l_print_flag := fnd_request.set_print_options(copies => 0);
  
    -- l_result     := fnd_request.set_mode(TRUE);
    -- xxom_denied_parties_pkg .pick_release_delivery_check
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
<<<<<<< .mine
			           program     => 'XXOMDPPICK',
			           description => NULL,
			           start_time  => SYSDATE +
					  (1 / 24 / 60),
			           sub_request => FALSE,
			           argument1   => p_batch_id, -- batch
			           argument2   => p_request_id); -- request
  
||||||| .r4749
                 program     => 'XXOMDPPICK',
                 description => NULL,
                 start_time  => SYSDATE +
            (1 / 24 / 60),
                 sub_request => FALSE,
                 argument1   => p_batch_id, -- batch
                 argument2   => p_request_id); -- request

=======
                                               program     => 'XXOMDPPICK',
                                               description => NULL,
                                               start_time  => SYSDATE +
                                                              (1 / 24 / 60),
                                               sub_request => FALSE,
                                               argument1   => p_batch_id, -- batch
                                               argument2   => p_request_id); -- request
  
>>>>>>> .r4768
    COMMIT;
  
  END;
  -----------------------------------------------
  -- check_user_action_wf
  --
  --   called from XXDPAPR Workflow
  --   handle user action in release action
  -----------------------------------------------
  PROCEDURE check_user_action_wf(itemtype  IN VARCHAR2,
<<<<<<< .mine
		         itemkey   IN VARCHAR2,
		         actid     IN NUMBER,
		         funcmode  IN VARCHAR2,
		         resultout OUT NOCOPY VARCHAR2) IS
||||||| .r4749
             itemkey   IN VARCHAR2,
             actid     IN NUMBER,
             funcmode  IN VARCHAR2,
             resultout OUT NOCOPY VARCHAR2) IS
=======
                                 itemkey   IN VARCHAR2,
                                 actid     IN NUMBER,
                                 funcmode  IN VARCHAR2,
                                 resultout OUT NOCOPY VARCHAR2) IS
>>>>>>> .r4768
    l_result VARCHAR2(500);
    l_nid    NUMBER;
  BEGIN
  
    -- context_user =email:Yuval.Tal@stratasys.com -- when answer from mail
    -- IF instr(upper(wf_engine.context_user), 'EMAIL:') > 0 THEN
  
    --  l_context_user_mail := substr(wf_engine.context_user, 7);
    --  ELSE
    --   l_context_user_mail := NULL;
  
    -- END IF;
    l_nid    := wf_engine.context_nid;
    l_result := wf_notification.getattrtext(l_nid, 'RESULT');
    IF funcmode = 'RESPOND' THEN
      wf_engine.setitemattrtext(itemtype => itemtype,
<<<<<<< .mine
		        itemkey  => itemkey,
		        aname    => 'CONTEXT_USER_MAIL',
		        avalue   => wf_engine.context_user);
    
||||||| .r4749
            itemkey  => itemkey,
            aname    => 'CONTEXT_USER_MAIL',
            avalue   => wf_engine.context_user);

=======
                                itemkey  => itemkey,
                                aname    => 'CONTEXT_USER_MAIL',
                                avalue   => wf_engine.context_user);
    
>>>>>>> .r4768
    END IF;
  
    resultout := wf_engine.eng_completed || ':' || l_result;
  END;
END xxom_denied_parties_pkg;
/