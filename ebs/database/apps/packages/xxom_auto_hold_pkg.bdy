create or replace package body xxom_auto_hold_pkg IS

  --------------------------------------------------------------------
  --  name:            XXOM_AUTO_HOLD_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/04/2013 16:40:59
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/04/2013  Dalit A. Raviv    initial build
  --  1.1  24/08/2014  Dalit A. Raviv    CHG0032401 add procedures
  --                                     apply_hold_book_wf, apply_hold_book
  --  1.2  01/03/2015  Dalit A. Raviv    CHG0034541 agg_initiate_hold_process
  --                                     add #FROM_ROLE attribute
  --  1.3  19/04/2015  Dalit A. Raviv    CHG0034419 Add Customer support auto hold functionality
  --                                     new function check_CS_condition
  --                                     update get_approver_and_fyi
  --  1.4  12/07/2015  Dalit A. Raviv    CHG0035495 - Workflow for credit check Hold on SO
  --                                     New function/ Procedures:
  --                                     submit_wf, release_approval_holds, main_doc_approval_wf
  -- 1.5   7.2.16      Yuval Tal         CHG0033846 - SO Holds Change the discount calculations
  --                                     modify procedure chek_discount_condition
  --                                     add get_manual_adj4order,get_manual_adj4line
  -- 1.6  3.3.16       yuval tal         INC0059630 - add get_order_discount_pct
  -- 1.7  01/07/2016   Diptasurjya       CHG0038822 - Order owner getting changed - Hold workflow fix
  -- 1.8  02-Mar-2017  Lingaraj Sarangi  CHG0040214 - Modifying Discount Hold workflow
  --                                     get_manual_adj4order Procedure Modified to consider any Manual Modifier
  -- 1.9  28.9.17      Yuval Tal          CHG0041582 add prepay_hold_release_conc :  releasing prepayment holds automatically
  -- 2.0  04/02/2018   Diptasurjya       CHG0041892 - Change payment term hold checking for Strataforce
  -- 2.1  9-Aug-2018   Lingaraj          CHG0043573 - Adjust Discount approval process to support CA order types
  -- 2.2  30-OCT-2018  Diptasurjya       CHG0044277 - Change apply_hold_book to apply active holds only
  --                                                  Store HEADER level hold check information in audit table
  --                                                  And skip check for all subsequent lines
  --------------------------------------------------------------------

  -- global var
  g_pkg_name     VARCHAR2(50) := 'XXOM_AUTO_HOLD_PKG';
  g_item_type    VARCHAR2(50) := 'XXOMHLD';
  g_process_name VARCHAR2(50) := 'MAIN';
  g_agg_process  VARCHAR2(50) := 'AGG_APPROVAL';
  -- 04/11/2014 Dalit A. Raviv INC0025364
  gn_app_id  NUMBER := 0;
  gn_resp_id NUMBER := 0;
  gn_user_id NUMBER := 0;
  -- 19/04/2015 Dalit A. Raviv CHG0034419 add ability of debug
  c_debug_module CONSTANT VARCHAR2(100) := 'xxom.AutoHold.xxom_auto_hold_pkg.';

  /*--------------------------------------------------------------------
  --  name:            is_open_hold_exists
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   check if open hold exists
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function is_open_hold_exists(p_so_header_id in number,
                               p_hold_id      in number) return varchar2;*/

  --------------------------------------------------------------------
  --  name:            agg_initiate_hold_process
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   Handle set WF variables, and initiate the WF itself
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------

  PROCEDURE agg_initiate_hold_process(errbuf             OUT VARCHAR2,
                                      retcode            OUT NUMBER,
                                      p_auto_hold_ids    IN VARCHAR2,
                                      p_so_number        IN NUMBER,
                                      p_so_header_id     IN NUMBER,
                                      p_approver         IN VARCHAR2,
                                      p_customer_id      IN NUMBER,
                                      p_header_type_name IN VARCHAR2,
                                      p_cust_po_number   IN VARCHAR2,
                                      p_org_id           IN NUMBER,
                                      p_batch_id         IN NUMBER,
                                      p_wf_item_key      IN VARCHAR2,
                                      p_fyi_email_list   IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            get_dynamic_condition_sql
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   run the dynamic sql from setup table and return
  --                   if to put hold Yes/No (get so_header_number)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_dynamic_condition_sql(p_entity_id    IN NUMBER,
                                      p_auto_hold_id IN NUMBER,
                                      p_sql_text     IN VARCHAR2,
                                      p_apply_hold   OUT VARCHAR2,
                                      p_hold_note    OUT VARCHAR2,
                                      p_err_code     OUT NUMBER,
                                      p_err_msg      OUT VARCHAR2) IS

    --l_sql_text xxom_auto_hold.condition_sql%TYPE;
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;

    EXECUTE IMMEDIATE p_sql_text
      USING p_entity_id, OUT p_err_code, OUT p_err_msg, OUT p_apply_hold, OUT p_hold_note;

  EXCEPTION
    WHEN no_data_found THEN
      p_err_code := 1;
      p_err_msg  := 'Error: get_dynamic_condition_sql: Entity id ' ||
                    p_entity_id || ' Auto Hold id ' || p_auto_hold_id ||
                    ' no data found';
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Error:get_dynamic_condition_sql : Entity id ' ||
                    p_entity_id || ' Auto Hold id ' || p_auto_hold_id ||
                    ' - ' || p_err_msg || substr(SQLERRM, 1, 240);

  END get_dynamic_condition_sql;

  --------------------------------------------------------------------
  --  name:            get_dynamic_sql
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   run the dynamic sql from setup table. (get so_header_id)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_dynamic_sql(p_entity_id    IN VARCHAR2,
                            p_auto_hold_id IN NUMBER,
                            p_sql_text     IN VARCHAR2,
                            p_subject      IN VARCHAR2,
                            p_return       OUT VARCHAR2,
                            p_err_code     OUT NUMBER,
                            p_err_msg      OUT VARCHAR2) IS

  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
    p_return   := NULL;

    EXECUTE IMMEDIATE p_sql_text
      USING p_entity_id, OUT p_err_code, OUT p_err_msg, OUT p_return;

  EXCEPTION
    WHEN no_data_found THEN
      p_err_code := 1;
      p_err_msg  := 'Error: get_dynamic_sql: ' || p_subject || ' - ' ||
                    ' Entity id ' || p_entity_id || ' Auto Hold id ' ||
                    p_auto_hold_id || ' no data found';
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Error:get_dynamic_sql:' || p_subject || ' - ' ||
                    ' Entity id ' || p_entity_id || ' Auto Hold id ' ||
                    p_auto_hold_id || ' - ' || p_err_msg ||
                    substr(SQLERRM, 1, 240);

  END get_dynamic_sql;

  --------------------------------------------------------------------
  --  name:            get_so_customer_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013 16:40:59
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   get customer name by customer id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_so_customer_name(p_customer_id IN NUMBER) RETURN VARCHAR2 IS

    l_account_name hz_cust_accounts.account_name%TYPE := NULL;

  BEGIN
    SELECT account_name
      INTO l_account_name
      FROM hz_cust_accounts hca
     WHERE hca.cust_account_id = p_customer_id; -- 6582 <Customer_id from wsh_deliverables_v>

    RETURN l_account_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_so_customer_name;

  --------------------------------------------------------------------
  --  name:            get_order_creator
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Get the user name of the creator of a sales order
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_order_creator(p_so_header_id IN NUMBER) RETURN VARCHAR2 IS

    l_user_name fnd_user.user_name%TYPE;
  BEGIN

    SELECT fu.user_name
      INTO l_user_name
      FROM oe_order_headers_all ooha, fnd_user fu
     WHERE ooha.created_by = fu.user_id
       AND ooha.header_id = p_so_header_id;

    RETURN l_user_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_order_creator;

  --------------------------------------------------------------------
  --  name:            get_user_id_by_email
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   get_user_name_by_email
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_user_id_by_email(p_email IN VARCHAR2) RETURN VARCHAR2 IS

    CURSOR c IS
      SELECT u.user_id
        FROM wf_users t, fnd_user u
       WHERE upper(t.email_address) = upper(p_email)
         AND u.user_name = t.name
         AND t.parent_orig_system = 'PER';

    l_tmp VARCHAR2(150);
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;

    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN fnd_global.user_id;

  END get_user_id_by_email;

  --------------------------------------------------------------------
  --  name:            check_user_action_wf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   handle user action in release action
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE check_user_action_wf(itemtype  IN VARCHAR2,
                                 itemkey   IN VARCHAR2,
                                 actid     IN NUMBER,
                                 funcmode  IN VARCHAR2,
                                 resultout OUT NOCOPY VARCHAR2) IS
    l_result VARCHAR2(500);
    l_nid    NUMBER;
  BEGIN

    l_nid    := wf_engine.context_nid;
    l_result := wf_notification.getattrtext(l_nid, 'RESULT');
    IF funcmode = 'RESPOND' THEN
      wf_engine.setitemattrtext(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'CONTEXT_USER_MAIL',
                                avalue   => wf_engine.context_user);

    END IF;

    resultout := wf_engine.eng_completed || ':' || l_result;
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context(g_pkg_name,
                      'check_user_action_wf',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      'Others',
                      'apply_hold_wf: ' || substr(SQLERRM, 1, 240));
  END check_user_action_wf;

  --------------------------------------------------------------------
  --  name:            apply_hold
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Apply Hold using API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE apply_hold(errbuf         OUT VARCHAR2,
                       retcode        OUT VARCHAR2,
                       p_so_header_id IN NUMBER,
                       p_org_id       IN NUMBER,
                       p_user_id      IN NUMBER,
                       p_hold_id      IN NUMBER,
                       p_hold_notes   IN VARCHAR2) IS

    l_hold_source_rec oe_holds_pvt.hold_source_rec_type;
    l_msg_count       VARCHAR2(200);
    l_msg_data        VARCHAR2(1000);
    l_return_status   VARCHAR2(200);
    l_msg_index_out   NUMBER;

  BEGIN

    errbuf  := NULL;
    retcode := 0;
    mo_global.set_policy_context('S', p_org_id);

    l_hold_source_rec.hold_id          := p_hold_id;
    l_hold_source_rec.hold_entity_code := 'O'; -- Order Hold
    l_hold_source_rec.hold_entity_id   := p_so_header_id; -- Order Header
    l_hold_source_rec.hold_comment     := 'Automatic OM Header Hold: ' ||
                                          p_hold_notes;
    l_hold_source_rec.creation_date    := SYSDATE;
    l_hold_source_rec.created_by       := p_user_id;

    oe_holds_pub.apply_holds(p_api_version      => 1.0,
                             p_init_msg_list    => fnd_api.g_false,
                             p_commit           => fnd_api.g_false,
                             p_validation_level => fnd_api.g_valid_level_full,
                             p_hold_source_rec  => l_hold_source_rec,
                             x_msg_count        => l_msg_count,
                             x_msg_data         => l_msg_data,
                             x_return_status    => l_return_status);

    IF l_return_status != fnd_api.g_ret_sts_success THEN
      retcode := 1;
      FOR i IN 1 .. l_msg_count LOOP
        oe_msg_pub.get(p_msg_index     => i,
                       p_encoded       => 'F',
                       p_data          => l_msg_data,
                       p_msg_index_out => l_msg_index_out);
        errbuf := errbuf || l_msg_data || chr(10);
      END LOOP;
    END IF; -- l_return status
  END apply_hold;

  --------------------------------------------------------------------
  --  name:            apply_hold_wf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Procedure that called from the wf and call to apply_hiold
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE apply_hold_wf(itemtype  IN VARCHAR2,
                          itemkey   IN VARCHAR2,
                          actid     IN NUMBER,
                          funcmode  IN VARCHAR2,
                          resultout OUT NOCOPY VARCHAR2) IS

    l_header_id NUMBER;
    l_org_id    NUMBER;
    l_hold_id   NUMBER;
    l_hold_note VARCHAR2(2000);
    --
    l_err_code    NUMBER;
    l_err_message VARCHAR2(1000);
    my_exception EXCEPTION;
  BEGIN

    l_header_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                               itemkey  => itemkey,
                                               aname    => 'SO_HEADER_ID');
    l_org_id    := wf_engine.getitemattrnumber(itemtype => itemtype,
                                               itemkey  => itemkey,
                                               aname    => 'ORG_ID');

    l_hold_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                             itemkey  => itemkey,
                                             aname    => 'HOLD_ID');

    l_hold_note := substr(wf_engine.getitemattrtext(itemtype,
                                                    itemkey,
                                                    'HOLD_NOTE'),
                          1,
                          1000);

    apply_hold(errbuf         => l_err_message, -- o v
               retcode        => l_err_code, -- o v
               p_so_header_id => l_header_id, -- i n
               p_org_id       => l_org_id, -- i n
               p_user_id      => fnd_global.user_id, -- i n
               p_hold_id      => l_hold_id, -- i n
               p_hold_notes   => l_hold_note); -- i v

    IF l_err_code = 0 THEN
      resultout := wf_engine.eng_completed;
    ELSE
      wf_core.context(g_pkg_name,
                      'apply_hold_wf',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      'Others',
                      'apply_hold_wf: ' || l_err_message);
      RAISE my_exception;
    END IF;

  END apply_hold_wf;

  --------------------------------------------------------------------
  --  name:            insert_auto_hold_audit
  --  create by:       Diptasurjya
  --  Revision:        1.0
  --  creation date:   30/10/2018
  --------------------------------------------------------------------
  --  purpose :        CHG0044277 - insert hold audit data for all lines of a given SO header ID
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/10/2018  Diptasurjya       initial build
  --------------------------------------------------------------------
  procedure insert_auto_hold_audit (p_header_id in number,
                                    p_line_id in number,
                                    p_hold_id in number) is
    pragma autonomous_transaction;
    l_audit_count number;
  begin
    select count(1) into l_audit_count from xxom_auto_hold_audit where header_id = p_header_id and hold_id = p_hold_id;

    if l_audit_count = 0 then
      for l_rec in (select line_id from oe_order_lines_all where header_id = p_header_id and flow_status_code <> 'CANCELLED') loop
        insert into xxom_auto_hold_audit values (p_header_id,l_rec.line_id, p_hold_id, sysdate);
      end loop;

      commit;
    else
      insert into xxom_auto_hold_audit values (p_header_id,p_line_id, p_hold_id, sysdate);
      commit;
    end if;
  end insert_auto_hold_audit;

  --------------------------------------------------------------------
  --  name:            purge_auto_hold_audit
  --  create by:       Diptasurjya
  --  Revision:        1.0
  --  creation date:   30/10/2018
  --------------------------------------------------------------------
  --  purpose :        CHG0044277 - purge hold audit data CLOSED/CANCELLED SO header ID
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/10/2018  Diptasurjya       initial build
  --------------------------------------------------------------------
  procedure purge_auto_hold_audit (p_err_code    OUT NUMBER,
                                   p_err_message OUT VARCHAR2) is

  begin
    delete from xxom_auto_hold_audit xa
     where exists
     (select 1
        from oe_order_headers_all oh
       where oh.header_id = xa.header_id
         and oh.flow_status_code in ('CLOSED', 'CANCELLED'));

    p_err_message := 'SUCCESS: Deleted '||sql%rowcount||' records from Auto Hold Audit table';
    p_err_code := 0;

    commit;
  exception when others then
    rollback;
    p_err_code := 2;
    p_err_message := 'ERROR: '||sqlerrm;
  end purge_auto_hold_audit;

  --------------------------------------------------------------------
  --  name:            apply_hold_book
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/08/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   Apply Hold using API, for the stage of BOOK
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/08/2014  Dalit A. Raviv    initial build
  --  1.1  19/04/2015  Dalit A. Raviv    CHG0034419 add debug option
  --  1.2  30/10/2018  Diptasurjya       CHG0044277 - Apply active holds only
  --                                     Auto hold performance improvement
  --------------------------------------------------------------------
  PROCEDURE apply_hold_book(errbuf         OUT VARCHAR2,
                            retcode        OUT VARCHAR2,
                            p_so_line_id   IN NUMBER,
                            p_org_id       IN NUMBER,
                            p_user_id      IN NUMBER,
                            p_so_header_id IN NUMBER,
                            p_hold_id      IN NUMBER DEFAULT NULL) IS

    CURSOR hold_pop_c IS
      SELECT ah.auto_hold_id,
             ah.hold_id,
             od.name hold_name,
             ah.hold_stage,
             ah.release_reason_code,
             ah.fyi_order_creator,
             ah.fyi_user_creator,
             ah.active,
             ah.condition_sql,
             ah.approver_sql,
             ah.fyi_cc_mail_sql,
             ah.approver_cc_mail_sql,
             ah.approver_body_msg,
             ah.inform_body_msg,
             ah.aggregate_notifications,
             ah.check_level    --  CHG0044277
        FROM xxom_auto_hold ah, oe_hold_definitions od
       WHERE hold_stage = 'BOOK'
         AND od.hold_id = ah.hold_id
         AND (od.hold_id = p_hold_id OR p_hold_id IS NULL)
         AND ah.active = 'Y';  -- CHG0044277

    lv_apply_hold  VARCHAR2(150);
    lv_hold_note   VARCHAR2(1000);
    ln_err_code    NUMBER;
    lv_err_msg     VARCHAR2(2500);
    lv_hold_exists VARCHAR2(10);
    lv_retcode     VARCHAR2(2000);

    l_hold_check_cnt number;  -- CHG0044277
    --ln_org_id       number;
    --ln_so_header_id number;
    --ln_user_id      number := fnd_global.USER_ID;
  BEGIN
    errbuf  := NULL;
    retcode := 0;


    -- check each hold if the line need to have hold?
    FOR hold_pop_r IN hold_pop_c LOOP
      ln_err_code    := 0;
      lv_err_msg     := NULL;
      lv_apply_hold  := NULL;
      lv_hold_note   := NULL;
      lv_hold_exists := NULL;
      lv_retcode     := NULL;

      -- CHG0044277 - Start
      if hold_pop_r.check_level = 'HEADER' then
        select count(1)
          into l_hold_check_cnt
          from xxom_auto_hold_audit
         where header_id = p_so_header_id
           and line_id = p_so_line_id
           and hold_id = hold_pop_r.hold_id;

        if l_hold_check_cnt > 0 then
          continue;
        end if;
      end if;
      -- CHG0044277 - End

      -- if the hold is aggregate just need to put OM header on hold
      -- then there will run a program that will send the mail.
      get_dynamic_condition_sql(p_entity_id    => p_so_line_id, -- i n
                                p_auto_hold_id => hold_pop_r.auto_hold_id, -- i n
                                p_sql_text     => hold_pop_r.condition_sql, -- i v
                                p_apply_hold   => lv_apply_hold, -- o v
                                p_hold_note    => lv_hold_note, -- o v
                                p_err_code     => ln_err_code, -- o n
                                p_err_msg      => lv_err_msg); -- o v

      -- CHG0044277 - Start
      if hold_pop_r.check_level = 'HEADER' then
        insert_auto_hold_audit(p_so_header_id, p_so_line_id, hold_pop_r.hold_id);
      end if;
      -- CHG0044277 - End

      -- Debug Message
      fnd_log.string(log_level => fnd_log.level_event,
                     module    => c_debug_module || 'apply_hold_book',
                     message   => 'So Line id = ' || p_so_line_id ||
                                  ' So Header id = ' || p_so_header_id ||
                                  ' auto_hold_id = ' ||
                                  hold_pop_r.auto_hold_id ||
                                  ' lv_apply_hold = ' || lv_apply_hold);

      IF ln_err_code <> 0 THEN
        IF errbuf IS NOT NULL THEN
          errbuf := errbuf || ', ' || hold_pop_r.hold_name || ' - ' ||
                    lv_err_msg;
        ELSE
          errbuf := 'E Dynamic Sql. hold name - ' || hold_pop_r.hold_name ||
                    ' - ' || lv_err_msg; -- get_hold_name (p_hold_id in number)
        END IF;
        retcode := 1;
      END IF;
      -- if found that this line need to apply hold
      -- check if this hold had applyied allredy, no need to put duplicate holds
      IF lv_apply_hold = 'Y' AND ln_err_code = 0 THEN
        lv_hold_exists := is_open_hold_exists(p_so_header_id => p_so_header_id, -- i n ln_so_header_id
                                              p_hold_id      => hold_pop_r.hold_id); -- i n
        -- apply the hold
        IF lv_hold_exists = 'N' THEN
          IF hold_pop_r.aggregate_notifications = 'Y' THEN
            apply_hold(errbuf         => lv_err_msg, -- o v
                       retcode        => lv_retcode, -- o v
                       p_so_header_id => p_so_header_id, -- i n ln_so_header_id
                       p_org_id       => p_org_id, -- i n ln_org_id
                       p_user_id      => p_user_id, -- i n fnd_global.user_id
                       p_hold_id      => hold_pop_r.hold_id, -- i n
                       p_hold_notes   => lv_hold_note); -- i v

            IF lv_retcode <> 0 THEN
              IF errbuf IS NOT NULL THEN
                errbuf := errbuf || ', Header id ' || p_so_header_id ||
                          ' Hold name ' || hold_pop_r.hold_name || ' - ' ||
                          lv_err_msg;
              ELSE
                errbuf := 'E apply Hold, Header id ' || p_so_header_id ||
                          ' Hold name ' || hold_pop_r.hold_name || ' - ' ||
                          lv_err_msg;
              END IF;
              retcode := 1;
            END IF;
          ELSE
            NULL;
            -- future case to go to the auto hold wf as it work today.
          END IF; -- aggregate notification
        END IF; -- hold exists
      END IF; -- apply hold
    END LOOP;

  END apply_hold_book;

  --------------------------------------------------------------------
  --  name:            apply_hold_book
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/08/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   Apply Hold using API, for the stage of BOOK
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/08/2014  Dalit A. Raviv    initial build
  --  1.1  04/11/2014  Dalit A. Raviv    INC0025364 - add apps_initialize
  --  1.2  01/07/2016  Diptasurjya       CHG0038822 - Order owner getting changed - Hold workflow fix
  --                                     Added By Lingaraj
  --  1.3  31/10/2018  Diptasurjya       CHG0044277 - If WF user ID is SCHEDULER then reset user to order creator
  --------------------------------------------------------------------
  PROCEDURE apply_hold_book_wf(itemtype  IN VARCHAR2,
                               itemkey   IN VARCHAR2,
                               actid     IN NUMBER,
                               funcmode  IN VARCHAR2,
                               resultout OUT NOCOPY VARCHAR2) IS

    ln_org_id    NUMBER := NULL;
    ln_line_id   NUMBER := NULL;
    ln_user_id   NUMBER := NULL;
    ln_header_id NUMBER := NULL;
    lv_retcode   VARCHAR2(200);
    lv_errbuf    VARCHAR2(2000);
    -- 1.1 04/11/2014 Dalit A. Raviv INC0025364
    ln_app_id  NUMBER;
    ln_resp_id NUMBER;
    --
    hold_error EXCEPTION;

    l_line_creator_user number;  -- CHG0044277
    l_is_scheduler_user varchar2(1) := 'N';
  BEGIN
    -- Do nothing in cancel or timeout mode
    IF (funcmode <> wf_engine.eng_run) THEN
      resultout := wf_engine.eng_null;
      RETURN;
    END IF;
    ln_org_id  := wf_engine.getitemattrnumber(itemtype => itemtype,
                                              itemkey  => itemkey,
                                              aname    => 'ORG_ID');
    ln_line_id := to_number(itemkey);

    BEGIN
      SELECT header_id, ol.created_by  -- CHG0044277 - add created by
        INTO ln_header_id, l_line_creator_user  -- CHG0044277 - add created by var
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



    /* Added 1.2 CHG0038822 Yuval hold creation will  be on the person who booked */
    ln_user_id := CASE
                    WHEN fnd_global.user_id IS NULL THEN
                     ln_user_id
                    WHEN fnd_global.user_id = -1 THEN
                     ln_user_id
                    ELSE
                     fnd_global.user_id
                  END;
                  
    -- CHG0044277 - start
    begin
      select 'Y'
        into l_is_scheduler_user
        from fnd_user
       where user_name='SCHEDULER'
         and user_id = ln_user_id;
    exception when no_data_found then
      l_is_scheduler_user := 'N';
    end;
      
    if l_is_scheduler_user = 'Y' then
      ln_user_id := l_line_creator_user;
    end if;
    -- CHG0044277 - end
    
    -- 1.1 04/11/2014 Dalit A. Raviv INC0025364
    /* commented 1.2  01/07/2016  Diptasurjya       CHG0038822
    ln_app_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                             itemkey  => itemkey,
                                             aname    => 'APPLICATION_ID');

    ln_resp_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                              itemkey  => itemkey,
                                              aname    => 'RESPONSIBILITY_ID');

    IF gn_app_id <> ln_app_id OR gn_resp_id <> ln_resp_id OR
       gn_user_id <> ln_user_id THEN
      gn_app_id  := ln_app_id;
      gn_resp_id := ln_resp_id;
      gn_user_id := ln_user_id;

      fnd_global.apps_initialize(user_id      => ln_user_id,
                                 resp_id      => ln_resp_id,
                                 resp_appl_id => ln_app_id);
    END IF;*/
    -- end INC0025364
    apply_hold_book(errbuf         => lv_errbuf, -- o
                    retcode        => lv_retcode, -- o
                    p_so_line_id   => ln_line_id, -- i
                    p_org_id       => ln_org_id, -- i
                    p_user_id      => ln_user_id, -- i
                    p_so_header_id => ln_header_id,
                    p_hold_id      => NULL); -- i

    IF nvl(lv_retcode, 0) <> 0 THEN
      RAISE hold_error;
    END IF;

    -- to call apply_hold_book
    resultout := wf_engine.eng_completed; -- Normal completion 'COMPLETE'

  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXOM_AUTO_HOLD_PKG',
                      'APPLY_HOLD_BOOK_WF',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      lv_errbuf,
                      SQLERRM);
      RAISE;
  END apply_hold_book_wf;

  --------------------------------------------------------------------
  --  name:            apply_hold_book_conc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   Apply Hold using API, for the stage of BOOK
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE apply_hold_book_conc(errbuf         OUT VARCHAR2,
                                 retcode        OUT VARCHAR2,
                                 p_so_line_id   IN NUMBER,
                                 p_org_id       IN NUMBER,
                                 p_user_id      IN NUMBER,
                                 p_so_header_id IN NUMBER,
                                 p_hold_id      IN NUMBER DEFAULT NULL) IS
    lv_retcode NUMBER;
    lv_errbuf  VARCHAR2(2500);

  BEGIN
    errbuf  := NULL;
    retcode := 0;
    apply_hold_book(errbuf         => lv_errbuf, -- o
                    retcode        => lv_retcode, -- o
                    p_so_line_id   => p_so_line_id, -- i
                    p_org_id       => p_org_id, -- i
                    p_user_id      => p_user_id, -- i
                    p_so_header_id => p_so_header_id,
                    p_hold_id      => p_hold_id); -- i

    IF nvl(lv_retcode, 0) <> 0 THEN
      errbuf  := 'Problem to apply hold to order ' || p_so_header_id ||
                 ' hold id ' || p_hold_id;
      retcode := 1;
      ROLLBACK;
    ELSE
      COMMIT;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'GEN Problem to apply hold to order ' || p_so_header_id ||
                 ' hold id ' || p_hold_id || ' - ' ||
                 substr(SQLERRM, 1, 240);
      retcode := 1;
      ROLLBACK;
  END apply_hold_book_conc;

  /*
  apply_hold_book(errbuf         => lv_errbuf, -- o
                    retcode        => lv_retcode, -- o
                    p_so_line_id   => ln_line_id, -- i
                    p_org_id       => ln_org_id, -- i
                    p_user_id      => ln_user_id, -- i
                    p_so_header_id => ln_header_id,
                    p_hold_id      => null);      -- i

    if nvl(lv_retcode, 0) <> 0 then
      raise hold_error;
    end if;
  */

  --------------------------------------------------------------------
  --  name:            is_open_hold_exists
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   check if open hold exists
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_open_hold_exists(p_so_header_id IN NUMBER,
                               p_hold_id      IN NUMBER) RETURN VARCHAR2 IS

    CURSOR get_hold_exists_c IS
      SELECT 1
        FROM oe_order_holds_all  oh,
             oe_hold_sources_all hs,
             oe_hold_releases    hr,
             oe_hold_definitions hd
       WHERE oh.hold_source_id = hs.hold_source_id
         AND hs.hold_id = hd.hold_id
         AND oh.hold_release_id = hr.hold_release_id(+)
         AND hs.org_id = oh.org_id
         AND hd.hold_id = p_hold_id
         AND hs.released_flag = 'N'
         AND oh.header_id = p_so_header_id;

    l_tmp NUMBER;

  BEGIN
    OPEN get_hold_exists_c;
    FETCH get_hold_exists_c
      INTO l_tmp;
    CLOSE get_hold_exists_c;
    IF nvl(l_tmp, 0) = 0 THEN
      RETURN 'N';
    ELSE
      RETURN 'Y';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_open_hold_exists;

  --------------------------------------------------------------------
  --  name:            is_hold_released_in_interval
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   check if open hold exists or closed one from the last XX days
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_hold_released_in_interval(p_so_header_id IN NUMBER,
                                        p_hold_id      IN NUMBER)
    RETURN VARCHAR2 IS

    CURSOR get_hold_exists_c IS
      SELECT 1
        FROM oe_order_holds_all  oh,
             oe_hold_sources_all hs,
             oe_hold_releases    hr,
             oe_hold_definitions hd
       WHERE oh.hold_source_id = hs.hold_source_id
         AND hs.hold_id = hd.hold_id
         AND oh.hold_release_id = hr.hold_release_id(+)
         AND hs.org_id = oh.org_id
         AND hd.hold_id = p_hold_id
         AND hs.released_flag = 'Y'
         AND oh.header_id = p_so_header_id
         AND trunc(SYSDATE) - trunc(hs.last_update_date) <=
             fnd_profile.value('XXOM_AUTO_HOLD_DAYS_TO_REHOLD');
    l_tmp NUMBER := NULL;

  BEGIN
    OPEN get_hold_exists_c;
    FETCH get_hold_exists_c
      INTO l_tmp;
    CLOSE get_hold_exists_c;
    IF nvl(l_tmp, 0) = 0 THEN
      RETURN 'N';
    ELSE
      RETURN 'Y';
    END IF;

  END is_hold_released_in_interval;

  --------------------------------------------------------------------
  --  name:            is_hold_check_needed
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   check if need to put hold
  --                   1) if there is allready hold
  --                   2) if hold was released in the last XX dayas (hold in profile)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_hold_check_needed(p_header_id IN NUMBER, p_hold_id IN NUMBER)
    RETURN VARCHAR2 IS

  BEGIN
    IF (is_open_hold_exists(p_header_id, p_hold_id) = 'Y' OR
       is_hold_released_in_interval(p_header_id, p_hold_id) = 'Y') THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  END is_hold_check_needed;

  --------------------------------------------------------------------
  --  name:            is_open_hold_exists_wf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   check if need to put hold
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE is_open_hold_exists_wf(itemtype  IN VARCHAR2,
                                   itemkey   IN VARCHAR2,
                                   actid     IN NUMBER,
                                   funcmode  IN VARCHAR2,
                                   resultout OUT NOCOPY VARCHAR2) IS

    l_header_id NUMBER;
    l_hold_id   NUMBER;
  BEGIN

    l_header_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                               itemkey  => itemkey,
                                               aname    => 'SO_HEADER_ID');

    l_hold_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                             itemkey  => itemkey,
                                             aname    => 'HOLD_ID');

    resultout := wf_engine.eng_completed || ':' ||
                 is_hold_check_needed(l_header_id, l_hold_id);

  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context(g_pkg_name,
                      'is_hold_needed_wf',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      'Others',
                      'apply_hold_wf: ' || substr(SQLERRM, 1, 240));
  END is_open_hold_exists_wf;

  --------------------------------------------------------------------
  --  name:            is_cc_needed_wf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE is_cc_needed_wf(itemtype  IN VARCHAR2,
                            itemkey   IN VARCHAR2,
                            actid     IN NUMBER,
                            funcmode  IN VARCHAR2,
                            resultout OUT NOCOPY VARCHAR2) IS

    l_hold_id NUMBER;
    l_creator VARCHAR2(10);
    l_user    VARCHAR2(10);
  BEGIN

    l_hold_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                             itemkey  => itemkey,
                                             aname    => 'HOLD_ID');

    SELECT h.fyi_order_creator, h.fyi_user_creator
      INTO l_creator, l_user
      FROM xxom_auto_hold h
     WHERE auto_hold_id = l_hold_id;

    IF l_creator = 'Y' AND l_user = 'Y' THEN
      wf_engine.setitemattrtext(itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'CC_FYI_LIST',
                                avalue   => NULL);
    END IF;

    resultout := wf_engine.eng_completed;

  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context(g_pkg_name,
                      'is_cc_needed_wf',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      'Others',
                      'apply_hold_wf: ' || substr(SQLERRM, 1, 240));
  END is_cc_needed_wf;

  --------------------------------------------------------------------
  --  name:            release_hold
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   11/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Release Hold using API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE release_hold(errbuf            OUT VARCHAR2,
                         retcode           OUT VARCHAR2,
                         p_header_id       IN NUMBER,
                         p_org_id          IN NUMBER,
                         p_hold_id         IN NUMBER,
                         p_user_id         IN NUMBER,
                         p_release_comment IN VARCHAR2,
                         p_release_reson   IN VARCHAR2) IS

    l_hold_source_rec  oe_holds_pvt.hold_source_rec_type;
    l_hold_release_rec oe_holds_pvt.hold_release_rec_type;
    l_msg_count        VARCHAR2(200);
    l_msg_data         VARCHAR2(1000);
    l_return_status    VARCHAR2(200);
    l_msg_index_out    NUMBER;
    l_err_msg          VARCHAR2(500);

  BEGIN
    retcode := 0;
    errbuf  := NULL;

    mo_global.set_policy_context('S', p_org_id);
    oe_globals.set_context();

    l_hold_source_rec.hold_id              := p_hold_id; -- Requested Hold
    l_hold_source_rec.hold_entity_code     := 'O';
    l_hold_source_rec.hold_entity_id       := p_header_id;
    l_hold_source_rec.header_id            := p_header_id;
    l_hold_release_rec.last_updated_by     := p_user_id;
    l_hold_release_rec.release_reason_code := p_release_reson;
    l_hold_release_rec.release_comment     := p_release_comment;
    l_hold_release_rec.created_by          := p_user_id;

    oe_msg_pub.initialize;

    oe_holds_pub.release_holds(p_api_version      => 1.0,
                               p_init_msg_list    => 'T',
                               p_commit           => 'F',
                               p_hold_source_rec  => l_hold_source_rec,
                               p_hold_release_rec => l_hold_release_rec,
                               x_msg_count        => l_msg_count,
                               x_msg_data         => l_msg_data,
                               x_return_status    => l_return_status);

    dbms_output.put_line('l_return_status ' || l_return_status);

    IF l_return_status != fnd_api.g_ret_sts_success THEN
      retcode := 1;

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
    END IF;
    dbms_output.put_line('l_err_msg ' || l_err_msg);
    errbuf := l_err_msg;

  END release_hold;

  --------------------------------------------------------------------
  --  name:            release_hold_wf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   11/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Release Hold using API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/04/2013  Dalit A. Raviv    initial build
  --  1.1  25/08/2014  Dalit A. Raviv    add ability to release several holds per SO
  --  1.2  09/07/2015  Dalit A. Raviv    CHG0035495 - Workflow for credit check Hold on SO
  --                                     Hold population need to exclude hold with
  --                                     DOC_COD -> these holds will use other WF
  --                                     XX Document Approval
  --------------------------------------------------------------------
  PROCEDURE release_hold_wf(itemtype  IN VARCHAR2,
                            itemkey   IN VARCHAR2,
                            actid     IN NUMBER,
                            funcmode  IN VARCHAR2,
                            resultout OUT NOCOPY VARCHAR2) IS

    l_err_code          NUMBER;
    l_err_message       VARCHAR2(2000);
    l_header_id         NUMBER;
    l_org_id            NUMBER;
    l_hold_id           NUMBER;
    l_context_user_mail VARCHAR2(150);
    l_user_id           NUMBER;
    l_release_comment   VARCHAR2(300);
    l_release_reson     VARCHAR2(80);
    my_exception EXCEPTION;

    -- Dalit A. Raviv 25/08/2014
    -- Add ability to release all holds for SO in aggregate way.
    CURSOR auto_hold_c(p_str IN VARCHAR2) IS
      SELECT ah.auto_hold_id, -- n
             ah.hold_id, -- n
             od.name hold_name, -- v
             ah.hold_stage, -- v
             ah.release_reason_code, -- v
             ah.active, -- v
             ah.aggregate_notifications -- v
        FROM xxom_auto_hold ah,
             --fnd_lookup_values   v,
             oe_hold_definitions od,
             (SELECT regexp_substr(p_str, '[^,]+', 1, LEVEL) str
                FROM dual
              CONNECT BY regexp_substr(p_str, '[^,]+', 1, LEVEL) IS NOT NULL) ids
       WHERE od.hold_id = ah.hold_id
         AND ids.str = ah.auto_hold_id
         AND ah.doc_code IS NULL; -- 09/07/2015 Dalit A. Raviv CHG0035495

    l_hold_ids_list VARCHAR2(240);
    -- end
  BEGIN

    l_header_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                               itemkey  => itemkey,
                                               aname    => 'SO_HEADER_ID');

    l_org_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                            itemkey  => itemkey,
                                            aname    => 'ORG_ID');

    l_hold_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                             itemkey  => itemkey,
                                             aname    => 'HOLD_ID');

    l_release_reson := wf_engine.getitemattrtext(itemtype => itemtype,
                                                 itemkey  => itemkey,
                                                 aname    => 'RELEASE_REASON');

    l_context_user_mail := wf_engine.getitemattrtext(itemtype => itemtype,
                                                     itemkey  => itemkey,
                                                     aname    => 'CONTEXT_USER_MAIL');

    IF instr(l_context_user_mail, '@') > 0 THEN
      l_context_user_mail := substr(l_context_user_mail, 7);
      l_release_comment   := 'Response by mail:' || l_context_user_mail;
      l_user_id           := to_number(get_user_id_by_email(l_context_user_mail));
    ELSE
      BEGIN
        SELECT user_id
          INTO l_user_id
          FROM fnd_user
         WHERE user_name = l_context_user_mail;
      EXCEPTION
        WHEN OTHERS THEN
          l_user_id := fnd_global.user_id;
      END;
    END IF;

    -- Dalit A. Raviv 25/08/2014
    l_hold_ids_list := wf_engine.getitemattrtext(itemtype => itemtype,
                                                 itemkey  => itemkey,
                                                 aname    => 'AGG_AUTO_HOLD_IDS_LIST');
    --
    IF l_hold_id IS NOT NULL THEN
      IF is_open_hold_exists(l_header_id, l_hold_id) = 'Y' THEN

        release_hold(errbuf            => l_err_message, -- o v
                     retcode           => l_err_code, -- o v
                     p_header_id       => l_header_id, -- i n
                     p_org_id          => l_org_id, -- i n
                     p_hold_id         => l_hold_id, -- i n
                     p_user_id         => l_user_id, -- i n
                     p_release_comment => l_release_comment, -- i v
                     p_release_reson   => l_release_reson); -- i v

        IF l_err_code = 0 THEN
          resultout := wf_engine.eng_completed;
          COMMIT;
        ELSE
          wf_core.context(g_pkg_name,
                          'Release_hold_wf',
                          itemtype,
                          itemkey,
                          to_char(actid),
                          funcmode,
                          'Others',
                          'Release_hold_wf: ' || l_err_message);
          RAISE my_exception;
        END IF; -- l_err_code
      END IF; -- Open hold exists
      -- Dalit A. Raviv 25/08/2014
      -- Add ability to release all holds for SO in aggregate way.
    ELSE
      -- agg case
      FOR auto_hold_r IN auto_hold_c(l_hold_ids_list) LOOP
        l_err_message := NULL;
        l_err_code    := 0;
        IF is_open_hold_exists(l_header_id, auto_hold_r.hold_id) = 'Y' THEN
          -- put hold using API
          release_hold(errbuf            => l_err_message, -- o v
                       retcode           => l_err_code, -- o v
                       p_header_id       => l_header_id, -- i n
                       p_org_id          => l_org_id, -- i n
                       p_hold_id         => auto_hold_r.hold_id, -- i n
                       p_user_id         => l_user_id, -- i n
                       p_release_comment => l_release_comment, -- i v
                       p_release_reson   => auto_hold_r.release_reason_code); -- i v

          IF l_err_code = 0 THEN
            resultout := wf_engine.eng_completed;
            COMMIT;
          ELSE
            wf_core.context(g_pkg_name,
                            'Release_hold_wf',
                            itemtype,
                            itemkey,
                            to_char(actid),
                            funcmode,
                            'Others',
                            'Release_hold_wf: hold_id ' ||
                            auto_hold_r.hold_id || ' - ' || l_err_message);
            RAISE my_exception;
          END IF; -- l_err_code
        END IF; -- Open hold exists

      END LOOP;
    END IF; -- hold_id is null
    resultout := wf_engine.eng_completed;

  END release_hold_wf;

  --------------------------------------------------------------------
  --  name:            get_hold_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Get hold name by the hold id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_hold_name(p_hold_id IN NUMBER) RETURN VARCHAR2 IS

    l_hold_name oe_hold_definitions.name%TYPE;
  BEGIN
    SELECT h.name
      INTO l_hold_name
      FROM oe_hold_definitions h
     WHERE h.hold_id = p_hold_id;

    RETURN l_hold_name;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_hold_name;

  --------------------------------------------------------------------
  --  name:            check_sql4
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Call from set up form - check that dynamic sql is valid
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE check_sql4(p_sql_text VARCHAR2) IS

    l_return   VARCHAR2(250);
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(2000);

  BEGIN
    EXECUTE IMMEDIATE p_sql_text
      USING 1, OUT l_err_code, OUT l_err_msg, OUT l_return;

  END check_sql4;

  --------------------------------------------------------------------
  --  name:            check_sql5
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Call from set up form - check that dynamic sql is valid
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE check_sql5(p_sql_text VARCHAR2) IS

    l_apply_hold VARCHAR2(10);
    l_hold_note  VARCHAR2(2000);
    l_err_code   NUMBER;
    l_err_msg    VARCHAR2(2000);

  BEGIN
    EXECUTE IMMEDIATE p_sql_text
      USING 1, OUT l_err_code, OUT l_err_msg, OUT l_apply_hold, OUT l_hold_note;

  END check_sql5;

  --------------------------------------------------------------------
  --  name:            check_hold_exist_at_setup
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   check if hold id exists at setup
  --                   call from trigger xxoe_hold_sources_all_aur_t
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION check_hold_exist_at_setup(p_hold_id IN NUMBER) RETURN VARCHAR2 IS
    l_count NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
      INTO l_count
      FROM xxom_auto_hold h
     WHERE h.hold_id = p_hold_id;

    IF l_count > 0 THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;

  END check_hold_exist_at_setup;

  --------------------------------------------------------------------
  --  name:            release_notification
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   called from db trigger
  --                   for after hold released which is done from application (not notification)
  --                   the release will continue wf and will send release notifications
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE release_notification(p_so_header_id IN NUMBER,
                                 p_hold_id      IN NUMBER) IS

    p_print_flag BOOLEAN;
    l_request_id NUMBER;
    l_result     BOOLEAN;

    -- get the notification for the so_header and hold_id
    CURSOR c_header IS
      SELECT t.notification_id
        FROM wf_notifications         t,
             wf_item_attribute_values ta,
             wf_item_attribute_values ta1
       WHERE ta.item_type = t.message_type
         AND t.item_key = ta.item_key
         AND t.message_type = 'XXOMHLD' -- Item Type
         AND t.message_name = 'APPROVER_NOTE' -- the message that need to release
         AND t.status = 'OPEN'
         AND ta.name = 'SO_HEADER_ID' -- attribute from the wf
         AND ta.number_value = p_so_header_id
         AND ta1.item_type = t.message_type
         AND ta1.item_key = t.item_key
         AND ta1.name = 'HOLD_ID' -- attribute from the wf
         AND ta1.number_value = p_hold_id
         AND rownum = 1;

    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    FOR i IN c_header LOOP
      p_print_flag := fnd_request.set_print_options(copies => 0);

      l_result := fnd_request.set_mode(TRUE);
      -- XXOM Auto Hold - Release Notification
      -- XXOM_AUTO_HOLD_PKG.release_notification_conc
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXOM_AUTO_HOLD_RELEASE_NOTE', -- XXOM Auto Hold - Release Notification
                                                 description => NULL,
                                                 start_time  => SYSDATE +
                                                                (1 / 24 / 60),
                                                 sub_request => FALSE,
                                                 argument1   => p_so_header_id,
                                                 argument2   => p_hold_id);

      COMMIT;
    END LOOP;
  END release_notification;

  --------------------------------------------------------------------
  --  name:            release_notification_conc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   release notification concurrent
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE release_notification_conc(errbuf         OUT VARCHAR2,
                                      retcode        OUT VARCHAR2,
                                      p_so_header_id IN NUMBER,
                                      p_hold_id      IN NUMBER) IS

    CURSOR c_header IS
      SELECT t.notification_id
        FROM wf_notifications         t,
             wf_item_attribute_values ta,
             wf_item_attribute_values ta1
       WHERE ta.item_type = t.message_type
         AND t.item_key = ta.item_key
         AND t.message_type = 'XXOMHLD' -- Item Type
         AND t.message_name = 'APPROVER_NOTE' -- the message that need to release
         AND t.status = 'OPEN'
         AND ta.name = 'SO_HEADER_ID' -- attribute from the wf
         AND ta.number_value = p_so_header_id
         AND ta1.item_type = t.message_type
         AND ta1.item_key = t.item_key
         AND ta1.name = 'HOLD_ID' -- attribute from the wf
         AND ta1.number_value = p_hold_id
         AND rownum = 1;

  BEGIN
    retcode := 0;
    errbuf  := NULL;
    FOR i IN c_header LOOP
      wf_notification.setattrtext(nid    => i.notification_id,
                                  aname  => 'RESULT',
                                  avalue => 'RELEASE');
      wf_notification.respond(i.notification_id,
                              'Release by ' || fnd_global.user_name,
                              fnd_global.user_name);
      COMMIT;
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := substr(SQLERRM, 1, 240);
  END release_notification_conc;

  --------------------------------------------------------------------
  --  name:            initiate_hold_process
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --                   Handle set WF variables, and initiate the WF itself
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE initiate_hold_process(errbuf             OUT VARCHAR2,
                                  retcode            OUT VARCHAR2,
                                  p_batch_id         IN VARCHAR2,
                                  p_so_header_id     IN NUMBER,
                                  p_so_number        IN VARCHAR2,
                                  p_delivery_id      IN NUMBER,
                                  p_header_type_name IN VARCHAR2,
                                  p_cust_po_number   IN VARCHAR2,
                                  p_customer_id      IN NUMBER,
                                  p_auto_hold_id     IN NUMBER,
                                  p_hold_note        IN VARCHAR2,
                                  p_org_id           IN NUMBER,
                                  p_wf_item_key      OUT VARCHAR2) IS

    l_user_creator        fnd_user.user_name%TYPE;
    l_order_creator       fnd_user.user_name%TYPE;
    l_hold_approver       fnd_user.user_name%TYPE;
    l_customer_name       hz_cust_accounts.account_name%TYPE := NULL;
    l_hold_name           oe_hold_definitions.name%TYPE;
    l_setup_rec           xxom_auto_hold%ROWTYPE;
    l_approver_cc         VARCHAR2(240);
    l_fyi_cc              VARCHAR2(240);
    l_cc_fyi_user_list    VARCHAR2(240);
    l_cc_fyi_creator_list VARCHAR2(240);
    l_err_code            NUMBER;
    l_err_msg             VARCHAR2(1000);
  BEGIN
    -- Init Var
    errbuf                := NULL;
    retcode               := 0;
    l_user_creator        := NULL;
    l_order_creator       := NULL;
    l_hold_approver       := NULL;
    l_err_code            := 0;
    l_err_msg             := NULL;
    l_approver_cc         := NULL;
    l_fyi_cc              := NULL;
    l_cc_fyi_user_list    := NULL;
    l_cc_fyi_creator_list := NULL;

    SELECT *
      INTO l_setup_rec
      FROM xxom_auto_hold h
     WHERE h.auto_hold_id = p_auto_hold_id;

    -- get FYI CC mail
    get_dynamic_sql(p_entity_id    => p_so_header_id, -- i v
                    p_auto_hold_id => p_auto_hold_id, -- i n
                    p_sql_text     => l_setup_rec.fyi_cc_mail_sql, -- i v
                    p_subject      => 'FYI CC Mail list', -- i v
                    p_return       => l_fyi_cc, -- o v
                    p_err_code     => l_err_code, -- o n
                    p_err_msg      => l_err_msg); -- o v

    -- Get Order Creator
    IF l_setup_rec.fyi_order_creator = 'Y' THEN
      l_order_creator       := get_order_creator(p_so_header_id);
      l_cc_fyi_creator_list := l_fyi_cc;
    ELSE
      l_order_creator       := NULL;
      l_cc_fyi_creator_list := NULL;
    END IF;

    -- Get user create the process
    IF l_setup_rec.fyi_user_creator = 'Y' THEN
      l_user_creator     := fnd_global.user_name;
      l_cc_fyi_user_list := l_fyi_cc;
    ELSE
      l_user_creator     := NULL;
      l_cc_fyi_user_list := NULL;
    END IF;

    IF l_setup_rec.fyi_order_creator = 'Y' AND
       l_setup_rec.fyi_user_creator = 'Y' THEN
      l_cc_fyi_user_list := NULL;
    END IF;

    -- get hold approver
    /*get_dynamic_approver_sql ( p_entity_id     => p_so_header_id,         -- i v
    p_auto_hold_id  => p_auto_hold_id,           -- i n
    p_sql_text      => l_setup_rec.approver_sql, -- i v
    p_approver_user => l_hold_approver,          -- o v
    p_err_code      => l_err_code,               -- o n
    p_err_msg       => l_err_msg);               -- o v */
    -- get hold Approver
    get_dynamic_sql(p_entity_id    => p_so_header_id, -- i v
                    p_auto_hold_id => p_auto_hold_id, -- i n
                    p_sql_text     => l_setup_rec.approver_sql, -- i v
                    p_subject      => 'Hold Approver', -- i v
                    p_return       => l_hold_approver, -- o v
                    p_err_code     => l_err_code, -- o n
                    p_err_msg      => l_err_msg); -- o v

    -- get cc approver
    get_dynamic_sql(p_entity_id    => p_so_header_id, -- i v
                    p_auto_hold_id => p_auto_hold_id, -- i n
                    p_sql_text     => l_setup_rec.approver_cc_mail_sql, -- i v
                    p_subject      => 'Approver CC Mail list', -- i v
                    p_return       => l_approver_cc, -- o v
                    p_err_code     => l_err_code, -- o n
                    p_err_msg      => l_err_msg); -- o v

    -- get hold name
    l_hold_name := get_hold_name(l_setup_rec.hold_id);

    -- get customer name
    l_customer_name := get_so_customer_name(p_customer_id);

    -- create wf process
    p_wf_item_key := p_batch_id;
    wf_engine.createprocess(itemtype   => g_item_type,
                            itemkey    => p_wf_item_key,
                            user_key   => p_so_number,
                            owner_role => fnd_global.user_name,
                            process    => g_process_name);

    -- Set Wf attributes values
    -- text
    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'INFORM_BODY_MSG',
                              avalue   => l_setup_rec.inform_body_msg); -- replace(l_setup_rec.inform_body_msg,chr(10),'<BR>'));
    -- Please follow up customer prepayments and once paid ask the Finance Manager to release the Hold.

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'APPROVER_BODY_MSG',
                              avalue   => l_setup_rec.approver_body_msg); -- replace(l_setup_rec.approver_body_msg,chr(10),'<BR>'));
    -- Please follow up customer prepayments and once paid release the Hold.
    -- If this case is exceptional consider releasing the hold now without waiting for paid prepayment.

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'ORDER_NUMBER',
                              avalue   => p_so_number);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'DELIVERY_NOTE',
                              avalue   => p_delivery_id);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'ORDER_HEADER_TYPE_NAME',
                              avalue   => p_header_type_name);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'CUST_PO_NUMBER',
                              avalue   => p_cust_po_number);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'CUSTOMER_NAME',
                              avalue   => l_customer_name);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'ORDER_CREATOR',
                              avalue   => l_order_creator);

    IF l_order_creator IS NOT NULL THEN
      wf_engine.setitemattrtext(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'NOTE_TO_CREATOR',
                                avalue   => 'Y');
    ELSE
      wf_engine.setitemattrtext(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'NOTE_TO_CREATOR',
                                avalue   => 'N');
    END IF;

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'USER_CREATOR',
                              avalue   => l_user_creator);

    IF l_user_creator IS NOT NULL THEN
      wf_engine.setitemattrtext(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'NOTE_TO_USER',
                                avalue   => 'Y');
    ELSE
      wf_engine.setitemattrtext(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'NOTE_TO_USER',
                                avalue   => 'N');
    END IF;

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'HOLD_APPROVER',
                              avalue   => l_hold_approver);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'HOLD_NAME',
                              avalue   => l_hold_name);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'HOLD_NOTE',
                              avalue   => p_hold_note);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'RELEASE_REASON',
                              avalue   => l_setup_rec.release_reason_code);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'CC_APPROVER_LIST',
                              avalue   => l_approver_cc);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'CC_FYI_USER_LIST',
                              avalue   => l_cc_fyi_user_list);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'CC_FYI_CREATOR_LIST',
                              avalue   => l_cc_fyi_creator_list);

    -- numbers
    wf_engine.setitemattrnumber(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'CUSTOMER_ID',
                                avalue   => p_customer_id);

    wf_engine.setitemattrnumber(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'SO_HEADER_ID',
                                avalue   => p_so_header_id);

    wf_engine.setitemattrnumber(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'AUTO_HOLD_ID',
                                avalue   => p_auto_hold_id);

    wf_engine.setitemattrnumber(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'HOLD_ID',
                                avalue   => l_setup_rec.hold_id);

    wf_engine.setitemattrnumber(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'ORG_ID',
                                avalue   => p_org_id);

    -- Start wf process
    wf_engine.startprocess(itemtype => g_item_type,
                           itemkey  => p_wf_item_key);

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Error: initiate_hold_process:' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END initiate_hold_process;

  --------------------------------------------------------------------
  --  name:            main_handle_holds
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CUST671 - OM Auto Holds
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --  1.1  09/07/2015  Dalit A. Raviv    CHG0035495 - Workflow for credit check Hold on SO
  --                                     Hold population need to exclude hold with
  --                                     DOC_COD -> these holds will use other WF
  --                                     XX Document Approval
  --------------------------------------------------------------------
  PROCEDURE main_handle_holds(errbuf       OUT VARCHAR2,
                              retcode      OUT VARCHAR2,
                              p_batch_id   IN NUMBER,
                              p_hold_stage IN VARCHAR2,
                              p_request_id IN NUMBER) IS

    CURSOR get_so_pop_c(p_batch_id IN NUMBER) IS
      SELECT d.source_header_id,
             d.source_header_number,
             d.delivery_id,
             d.source_header_type_name,
             d.cust_po_number,
             d.customer_id,
             d.org_id
        FROM wsh_picking_batches_v b, wsh_deliverables_v d
       WHERE b.delivery_id = d.delivery_id
         AND b.delivery_detail_id IS NULL
         AND b.batch_id = p_batch_id -- 29844211
      UNION
      SELECT d.source_header_id,
             d.source_header_number,
             d.delivery_id,
             d.source_header_type_name,
             d.cust_po_number,
             d.customer_id,
             d.org_id
        FROM wsh_picking_batches_v b, wsh_deliverables_v d
       WHERE b.delivery_detail_id = d.delivery_detail_id
         AND b.batch_id = p_batch_id; -- 29844211;

    CURSOR get_hold_setup_c(p_hold_stage IN VARCHAR2) IS
      SELECT h.auto_hold_id,
             h.hold_stage,
             h.condition_sql,
             h.hold_id,
             h.fyi_order_creator,
             h.fyi_user_creator,
             h.approver_sql,
             h.approver_cc_mail_sql,
             h.fyi_cc_mail_sql,
             h.active,
             h.release_reason_code
        FROM xxom_auto_hold h
       WHERE h.active = 'Y'
         AND nvl(h.aggregate_notifications, 'N') = 'N' -- Dalit A. Raviv 28/08/2014
         AND h.hold_stage = p_hold_stage
         AND h.doc_code IS NULL; -- 09/07/2015 Dalit A. Raviv CHG0035495

    l_err_code    VARCHAR2(100);
    l_err_msg     VARCHAR2(1000);
    l_err_message VARCHAR2(1000);
    l_apply_hold  VARCHAR2(10);
    l_hold_note   VARCHAR2(2000);
    l_wf_item_key VARCHAR2(250);
    l_wf_status   VARCHAR2(100);
    my_exception EXCEPTION;

  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- get all So to check if need to enter Hold
    FOR get_so_pop_r IN get_so_pop_c(p_batch_id) LOOP
      fnd_file.put_line(fnd_file.log,
                        'So Number ' || get_so_pop_r.source_header_number);
      -- 1) check set up
      FOR get_hold_setup_r IN get_hold_setup_c(p_hold_stage) LOOP
        l_err_code   := 0;
        l_err_msg    := NULL;
        l_apply_hold := NULL;
        --dbms_output.put_line('header_id '||get_so_pop_r.source_header_id);
        get_dynamic_condition_sql(p_entity_id    => get_so_pop_r.source_header_id, -- i n
                                  p_auto_hold_id => get_hold_setup_r.auto_hold_id, -- i n
                                  p_sql_text     => get_hold_setup_r.condition_sql, -- i v
                                  p_apply_hold   => l_apply_hold, -- o v
                                  p_hold_note    => l_hold_note, -- o v
                                  p_err_code     => l_err_code, -- o v
                                  p_err_msg      => l_err_msg); -- o v
        IF l_err_code = 0 THEN
          dbms_output.put_line('Apply Hold ' || l_apply_hold);
          fnd_file.put_line(fnd_file.log, 'Apply Hold ' || l_apply_hold);
          fnd_file.put_line(fnd_file.log,
                            'Auto Hold id' || get_hold_setup_r.auto_hold_id);
          IF l_apply_hold = 'Y' THEN
            -- 2) according to return value if Y call WF
            -- 2.1) init Wf variable
            -- 2.2) start Wf and handle all wf issues
            BEGIN
              initiate_hold_process(errbuf  => l_err_code, -- o v
                                    retcode => l_err_msg, -- o v
                                    --p_batch_id         => p_batch_id, -- i n
                                    p_batch_id         => p_batch_id || '-' ||
                                                          get_so_pop_r.delivery_id || '-' ||
                                                          get_so_pop_c%ROWCOUNT || '.' ||
                                                          get_hold_setup_c%ROWCOUNT, -- i n
                                    p_so_header_id     => get_so_pop_r.source_header_id, -- i n
                                    p_so_number        => get_so_pop_r.source_header_number, -- i v
                                    p_delivery_id      => get_so_pop_r.delivery_id, -- i n
                                    p_header_type_name => get_so_pop_r.source_header_type_name, -- i v
                                    p_cust_po_number   => get_so_pop_r.cust_po_number, -- i v
                                    p_customer_id      => get_so_pop_r.customer_id, -- i n
                                    p_auto_hold_id     => get_hold_setup_r.auto_hold_id, -- i n
                                    p_hold_note        => l_hold_note, -- i v
                                    p_org_id           => get_so_pop_r.org_id, -- i n
                                    p_wf_item_key      => l_wf_item_key); -- o v

              IF l_err_code = 1 THEN
                RAISE my_exception;
              ELSE
                -- item_key = p_batch_id
                -- user_key = get_so_pop_r.source_header_number
                fnd_file.put_line(fnd_file.log,
                                  to_char(SYSDATE, 'hh24:mi') ||
                                  ' WF Started....item key/user key =' ||
                                  l_wf_item_key || '/' ||
                                  get_so_pop_r.source_header_number);

                --- check wf status
                SELECT wf_fwkmon.getitemstatus(workflowitemeo.item_type,
                                               workflowitemeo.item_key,
                                               workflowitemeo.end_date,
                                               workflowitemeo.root_activity,
                                               workflowitemeo.root_activity_version)
                  INTO l_wf_status
                  FROM wf_items workflowitemeo
                 WHERE item_type = g_item_type
                   AND item_key = l_wf_item_key;

                IF l_wf_status = 'ERROR' THEN
                  l_err_message := 'WF in status ERROR please call Admin';
                  RAISE my_exception;
                END IF;
              END IF;
            EXCEPTION
              WHEN my_exception THEN
                -----------------------
                retcode := 1;
                errbuf  := l_err_message;
                fnd_file.put_line(fnd_file.log,
                                  to_char(SYSDATE, 'hh24:mi') || ' Error: ' ||
                                  l_err_msg || ' ' || SQLERRM);

                xxobjt_wf_mail.send_mail_text(p_err_code    => l_err_code,
                                              p_err_message => l_err_message,
                                              p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                              p_subject     => 'OM Auto Hold Error',
                                              p_body_text   => 'Error in XXOM_AUTO_HOLD_PKG.main_handle_holds : ' ||
                                                               chr(10) ||
                                                               'When trying to submit DP WF Check' ||
                                                               chr(10) ||
                                                               'request_id = ' ||
                                                               p_request_id ||
                                                               chr(10) ||
                                                               'batch_id = ' ||
                                                               p_batch_id ||
                                                               chr(10) ||
                                                               l_err_message);

              WHEN OTHERS THEN
                retcode       := 1;
                errbuf        := substr(SQLERRM, 1, 240);
                l_err_message := substr(SQLERRM, 1, 240);
                fnd_file.put_line(fnd_file.log,
                                  to_char(SYSDATE, 'hh24:mi') || ' Error:' ||
                                  l_err_message);

                xxobjt_wf_mail.send_mail_text(p_err_code    => l_err_code,
                                              p_err_message => l_err_message,
                                              p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                              p_subject     => 'OM Auto Hold Error',
                                              p_body_text   => 'Error in XXOM_AUTO_HOLD_PKG.main_handle_holds: ' ||
                                                               chr(10) ||
                                                               'request_id=' ||
                                                               p_request_id ||
                                                               chr(10) ||
                                                               ' batch_id=' ||
                                                               p_batch_id ||
                                                               chr(10) ||
                                                               l_err_message);
                -----------------------
            END;
          END IF;
        ELSE
          errbuf        := errbuf || '  ' || l_err_msg;
          retcode       := 1;
          l_err_message := errbuf || '  ' || l_err_msg;

          fnd_file.put_line(fnd_file.log,
                            'get_dynamic_condition_sql - ' || errbuf);
          fnd_file.put_line(fnd_file.log,
                            'Auto hold id - ' ||
                            get_hold_setup_r.auto_hold_id ||
                            ' Entity Id - ' ||
                            get_so_pop_r.source_header_number);
          xxobjt_wf_mail.send_mail_text(p_err_code    => l_err_code,
                                        p_err_message => l_err_message,
                                        p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                        p_subject     => 'OM Auto Hold Error',
                                        p_body_text   => 'Error in XXOM_AUTO_HOLD_PKG.main_handle_holds: ' ||
                                                         chr(10) ||
                                                         'request_id=' ||
                                                         p_request_id ||
                                                         chr(10) ||
                                                         ' batch_id=' ||
                                                         p_batch_id ||
                                                         chr(10) ||
                                                         ' Auto hold id - ' ||
                                                         get_hold_setup_r.auto_hold_id ||
                                                         ' Entity Id - ' ||
                                                         get_so_pop_r.source_header_number ||
                                                         l_err_message);
        END IF;
        COMMIT;
      END LOOP;
    END LOOP;

  END main_handle_holds;

  --------------------------------------------------------------------
  --  name:            main_conc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013 16:40:59
  --------------------------------------------------------------------
  --  purpose :        Call from trigger xx_fnd_concurrent_requests_trg
  --                   Handle the holds for Denied Parties and Auto hold
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE main_conc(errbuf       OUT VARCHAR2,
                      retcode      OUT VARCHAR2,
                      p_batch_id   IN NUMBER,
                      p_request_id IN NUMBER,
                      p_hold_stage IN VARCHAR2) IS

    l_print_option BOOLEAN;
    l_printer_name VARCHAR2(150) := NULL;
    l_request_id   NUMBER;
    l_phase        VARCHAR2(100);
    l_status       VARCHAR2(100);
    l_dev_phase    VARCHAR2(100);
    l_dev_status   VARCHAR2(100);
    l_message      VARCHAR2(100);
    l_error_flag   BOOLEAN := FALSE;
    l_return_bool  BOOLEAN;

  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- Set print options
    IF fnd_profile.value('XXOM_DP_ENABLE_CHECK') = 'Y' OR
       fnd_profile.value('XXOM_AUTO_HOLD_ENABLE_CHECK') = 'Y' THEN
      l_printer_name := fnd_profile.value('PRINTER');
      l_print_option := fnd_request.set_print_options(l_printer_name,
                                                      '',
                                                      '0',
                                                      TRUE,
                                                      'N');
    END IF;

    -- Handle Denied party
    IF fnd_profile.value('XXOM_DP_ENABLE_CHECK') = 'Y' THEN

      -- submit xxom_denied_parties_pkg.submit_check_pick_conc
      IF l_print_option = TRUE THEN
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXOMDPPICK',
                                                   description => NULL,
                                                   start_time  => SYSDATE +
                                                                  (1 / 24 / 60),
                                                   sub_request => FALSE,
                                                   argument1   => p_batch_id, -- batch
                                                   argument2   => p_request_id); -- request

        COMMIT;
        IF l_request_id <> 0 THEN
          -- loop to wait until the request finished
          l_error_flag := FALSE;
          l_phase      := NULL;
          l_status     := NULL;
          l_dev_phase  := NULL;
          l_dev_status := NULL;
          l_message    := NULL;
          WHILE l_error_flag = FALSE LOOP
            l_return_bool := fnd_concurrent.wait_for_request(l_request_id,
                                                             5,
                                                             86400,
                                                             l_phase,
                                                             l_status,
                                                             l_dev_phase,
                                                             l_dev_status,
                                                             l_message);

            IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
              l_error_flag := TRUE;
            ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
              l_error_flag := TRUE;
              fnd_file.put_line(fnd_file.log,
                                'Denied Party request finished in error or warrning. ' ||
                                l_message);
              errbuf  := 'Denied Party request finished in error or warrning.';
              retcode := 1;
            END IF; -- dev_phase
          END LOOP; -- l_error_flag
        ELSE
          fnd_file.put_line(fnd_file.log, 'Failed to check Denied Party');
          errbuf  := SQLERRM;
          retcode := 2;
        END IF; -- l_request_id
      END IF; -- print option
      COMMIT;
    END IF; -- dp profile

    -- Handle Auto Holds
    IF fnd_profile.value('XXOM_AUTO_HOLD_ENABLE_CHECK') = 'Y' THEN
      IF l_print_option = TRUE THEN
        -- XXOM Auto Hold - Handle Holds
        -- XXOM_AUTO_HOLD_PKG.main_handle_holds
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXOM_AUTO_HOLD_PROG',
                                                   description => NULL,
                                                   start_time  => SYSDATE +
                                                                  (1 / 24 / 60),
                                                   sub_request => FALSE,
                                                   argument1   => p_batch_id,
                                                   argument2   => p_hold_stage,
                                                   argument3   => p_request_id);
        COMMIT;
        IF l_request_id <> 0 THEN
          -- loop to wait until the request finished
          l_error_flag := FALSE;
          l_phase      := NULL;
          l_status     := NULL;
          l_dev_phase  := NULL;
          l_dev_status := NULL;
          l_message    := NULL;
          WHILE l_error_flag = FALSE LOOP
            l_return_bool := fnd_concurrent.wait_for_request(l_request_id,
                                                             5,
                                                             86400,
                                                             l_phase,
                                                             l_status,
                                                             l_dev_phase,
                                                             l_dev_status,
                                                             l_message);

            IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
              l_error_flag := TRUE;
            ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
              l_error_flag := TRUE;
              fnd_file.put_line(fnd_file.log,
                                'OM Auto Hold request finished in error or warrning. ' ||
                                l_message);
              errbuf  := 'OM Auto Hold request finished in error or warrning.';
              retcode := 1;
            END IF; -- dev_phase
          END LOOP; -- l_error_flag
        ELSE
          fnd_file.put_line(fnd_file.log, 'Failed run OM Auto Hold');
          errbuf  := SQLERRM;
          retcode := 2;
        END IF; -- l_request_id
      END IF; -- print option
    END IF; -- hold profile

    -- Release seeded oracle program from hold
    IF retcode = 0 THEN
      UPDATE fnd_concurrent_requests t
         SET t.hold_flag = 'N'
       WHERE t.request_id = p_request_id;
      COMMIT;
    END IF;

  END main_conc;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013 16:40:59
  --------------------------------------------------------------------
  --  purpose :        Call from trigger xx_fnd_concurrent_requests_trg
  --                   Handle the holds for Denied Parties and Auto hold
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf       OUT VARCHAR2,
                 retcode      OUT VARCHAR2,
                 p_batch_id   IN NUMBER,
                 p_request_id IN NUMBER,
                 p_hold_stage IN VARCHAR2) IS

    l_print_option BOOLEAN;
    l_printer_name VARCHAR2(150) := NULL;
    l_request_id   NUMBER;

    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    --l_print_flag := fnd_request.set_print_options(copies => 0);
    l_printer_name := fnd_profile.value('PRINTER');
    l_print_option := fnd_request.set_print_options(l_printer_name,
                                                    '',
                                                    '0',
                                                    TRUE,
                                                    'N');
    -- XXOM Auto Hold - Handle DP and Holds
    -- XXOM_AUTO_HOLD_PKG.main_conc
    IF l_print_option = TRUE THEN
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXOM_AUTO_HOLD_MAIN_PROG', -- XXOM_AUTO_HOLD_PKG.main_conc
                                                 description => NULL,
                                                 start_time  => SYSDATE +
                                                                (1 / 24 / 60),
                                                 sub_request => FALSE,
                                                 argument1   => p_batch_id, -- Batch id
                                                 argument2   => p_request_id, -- Request id
                                                 argument3   => p_hold_stage); -- Hold stage

      COMMIT;

      IF l_request_id = 0 THEN
        errbuf  := 'Failed to Handle holds for Denied Parties and OM Auto hold ';
        retcode := 2;
      END IF;
    END IF;
  END main;

  --------------------------------------------------------------------
  --  name:            close_inprocess_hold_wf_conc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   program that will run once a week/month..
  --                   the program will locate all open WF , and will check per order
  --                   if the hold Manually released.
  --                   if all holds for this order where released so we need to close
  --                   the WF.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/09/2014  Dalit A. Raviv    initial build
  --  1.1  16/07/2015  Dalit A. Raviv    CHG0035495 - Workflow for credit check Hold on SO
  --                                     add handle to close XXWFDOC for credit check process
  --                                     if customer release Manually the hold
  --                                     but WF all readey started the flow, this prog
  --                                     will abort wf (close it).
  --------------------------------------------------------------------
  PROCEDURE close_inprocess_hold_wf_conc(errbuf  OUT VARCHAR2,
                                         retcode OUT VARCHAR2) IS
    -- get population to work on
    CURSOR so_c IS
      SELECT t.notification_id,
             t.message_name,
             ta1.name,
             ta1.text_value    auto_hold_ids_list, -- this hold list of auto_hold_id
             t.status,
             ta.number_value   order_header_id,
             ta2.number_value  org_id,
             t.item_key
        FROM wf_notifications         t,
             wf_item_attribute_values ta,
             wf_item_attribute_values ta1,
             wf_item_attribute_values ta2
       WHERE t.message_type = ta.item_type
         AND t.item_key = ta.item_key
         AND t.message_type = 'XXOMHLD' -- Item Type (WF)
         AND t.message_name = 'AGG_APPROVER_NOTE' -- the message that need to release
         AND t.status = 'OPEN'
         AND ta.name = 'SO_HEADER_ID' -- attribute from the wf
         AND ta1.item_type = t.message_type
         AND ta1.item_key = t.item_key
         AND ta1.name = 'AGG_AUTO_HOLD_IDS_LIST'
         AND ta2.item_type = t.message_type
         AND ta2.item_key = t.item_key
         AND ta2.name = 'ORG_ID'; -- attribute from the wf
    --and ta.number_value = 791743; so_header_id

    -- Get the auto hold id split . each one need to get the hold_id and to chack the hold id
    CURSOR split_c(p_str IN VARCHAR2) IS
      SELECT DISTINCT a.split_auto_hold_id
        FROM (SELECT regexp_substr(p_str, '[^, ]+', 1, rownum) split_auto_hold_id
                FROM dual
              CONNECT BY LEVEL <=
                         length(regexp_replace(p_str, '[^, ]+')) + 1) a
       WHERE split_auto_hold_id IS NOT NULL;

    -- 1.1 16/07/2015 Dalit A. Raviv CHG0035495
    -- this population bring all open notifications
    -- later in the program we check "is_open_hold_exists"
    -- only the notifications that is_open_hold_exists" = N
    -- it means that the hold released allredy manually.
    CURSOR c_doc_approval_pop IS
      SELECT t.notification_id,
             t.message_name,
             t.status,
             t.item_key,
             ah.hold_id,
             doc_ins.n_attribute2    so_header_id,
             doc_ins.n_attribute3    org_id,
             doc_ins.doc_instance_id
        FROM wf_notifications       t,
             xxom_auto_hold         ah,
             xxobjt_wf_docs         doc,
             xxobjt_wf_doc_instance doc_ins
       WHERE ah.doc_code = doc.doc_code
         AND doc.doc_id = doc_ins.doc_id
         AND t.item_key = doc_ins.wf_item_key
         AND t.message_type = 'XXWFDOC' -- Item Type (WF)
         AND t.status = 'OPEN'
         AND t.message_name = 'NEED_APPR_MSG';

    l_count_holds         NUMBER := 0;
    l_count_release_holds NUMBER := 0;
    l_hold_id             NUMBER;
    l_open_hold_exists    VARCHAR2(10);
    -- 1.1 16/07/2015 Dalit A. Raviv CHG0035495
    l_err_code VARCHAR2(100);
    l_err_msg  VARCHAR2(2000);

  BEGIN
    errbuf  := NULL;
    retcode := 0;

    FOR so_r IN so_c LOOP
      FOR split_r IN split_c(so_r.auto_hold_ids_list) LOOP
        l_count_holds := l_count_holds + 1;
        -- get hold id
        BEGIN
          SELECT hold_id
            INTO l_hold_id
            FROM xxom_auto_hold ah
           WHERE ah.auto_hold_id = split_r.split_auto_hold_id;
        EXCEPTION
          WHEN OTHERS THEN
            l_hold_id := 0;
        END;
        -- 2 check if there is hold exists
        -- this function look if there is open holds for SO_header,
        -- it return Y if found and N if not.
        -- i'm looking for the case that there are no open holds for the SO ->
        -- if there is open WF and all holds are closed -> it mean that the holds were released manually
        l_open_hold_exists := is_open_hold_exists(so_r.order_header_id, -- i n
                                                  l_hold_id); -- i n

        IF l_open_hold_exists = 'N' THEN
          l_count_release_holds := l_count_release_holds + 1;
        END IF;

      END LOOP;
      IF l_count_release_holds = l_count_holds THEN
        mo_global.set_policy_context('S', so_r.org_id);
        oe_globals.set_context();
        --release wf
        dbms_output.put_line('Release XXOMHLD notifications - ' ||
                             so_r.notification_id || ' Order id - ' ||
                             so_r.order_header_id || ' Item Key - ' ||
                             so_r.item_key);
        fnd_file.put_line(fnd_file.log,
                          'Release XXOMHLD notifications - ' ||
                          so_r.notification_id || ' Order id - ' ||
                          so_r.order_header_id || ' Item Key - ' ||
                          so_r.item_key);

        wf_engine.abortprocess(g_item_type, so_r.item_key);
        /*wf_notification.setattrtext(nid    => so_r.notification_id,
                                    aname  => 'RESULT',
                                    avalue => 'RELEASE');
        wf_notification.respond(so_r.notification_id,'Release by ' || fnd_global.user_name, fnd_global.user_name);*/
        COMMIT;
      END IF;
      l_count_holds         := 0;
      l_count_release_holds := 0;
    END LOOP;

    -- 1.1 16/07/2015 Dalit A. Raviv CHG0035495
    FOR r_doc_approval_pop IN c_doc_approval_pop LOOP
      -- 2 check if there is hold exists
      -- this function look if there is open holds for SO_header,
      -- it return Y if found and N if not.
      -- i'm looking for the case that there are no open holds for the SO (Doc approval type)->
      -- if there is open WF and all holds are closed -> it mean that the holds were released manually
      l_open_hold_exists := is_open_hold_exists(r_doc_approval_pop.so_header_id, -- i n
                                                r_doc_approval_pop.hold_id); -- i n

      IF l_open_hold_exists = 'N' THEN
        dbms_output.put_line('Release XXWFDOC notifications - ' ||
                             r_doc_approval_pop.notification_id ||
                             ' Order id - ' ||
                             r_doc_approval_pop.so_header_id ||
                             ' Item Key - ' || r_doc_approval_pop.item_key);
        fnd_file.put_line(fnd_file.log,
                          'Release XXWFDOC notifications - ' ||
                          r_doc_approval_pop.notification_id ||
                          ' Order id - ' || r_doc_approval_pop.so_header_id ||
                          ' Item Key - ' || r_doc_approval_pop.item_key);

        --wf_engine.abortprocess('XXWFDOC', r_doc_approval_pop.item_key);
        xxobjt_wf_doc_util.abort_process(p_err_code        => l_err_code,
                                         p_err_msg         => l_err_msg,
                                         p_doc_instance_id => r_doc_approval_pop.doc_instance_id);

        COMMIT;
      END IF;

    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'close_inprocess_hold_wf_conc request finished in error or warrning. ' ||
                        substr(SQLERRM, 1, 240));
      dbms_output.put_line('close_inprocess_hold_wf_conc request finished in error or warrning. ' ||
                           substr(SQLERRM, 1, 240));
      retcode := 1;
      errbuf  := substr(SQLERRM, 1, 240);
  END close_inprocess_hold_wf_conc;

  --------------------------------------------------------------------
  --  name:            get_order_source
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   04/02/2018
  --------------------------------------------------------------------
  --  purpose :        CHG0041892 - Get order source name for a given line_id or header_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/02/2018  Diptasurjya       initial build
  --  1.1  11/06/2018  Diptasurjya       CHG0044277 - Remove NVL's with header_id
  --                                     to improve performance of the query
  --------------------------------------------------------------------
  FUNCTION get_order_source(p_so_line_id   IN NUMBER/*,
                            p_so_header_id IN NUMBER*/) RETURN VARCHAR2 IS   -- CHG0044277 comment header_id input

    l_order_source varchar2(240);
  BEGIN
    select os.name
      into l_order_source
      from oe_order_lines_all   ol,
           oe_order_headers_all oh,
           oe_order_sources     os
     where ol.header_id = oh.header_id
       and ol.line_id = p_so_line_id--nvl(p_so_line_id, ol.line_id)  -- CHG0044277 - commented nvl 
       --and oh.header_id = nvl(p_so_header_id, oh.header_id)  -- CHG0044277 - header_id not to be considered
       and os.order_source_id = oh.order_source_id;

    RETURN l_order_source;
  END get_order_source;

  --------------------------------------------------------------------
  --  name:            chek_discount_condition
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   check if order have manual discount, and if the
  --                   discount threshold exists at setup tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/09/2014  Dalit A. Raviv    initial build
  --  1.1  7.2.16      Yuval Tal         CHG0033846 - SO Holds Change the discount calculations
  --                                     Take in consideration manual discounts performed by users at the header level
  --                                     Don't take discount due to Resin Credit
  --                                     add get_order_discount_pct
  --  1.2  3.3.16      yuval tal         INC0059630 - use get_order_discount_pct in DISCOUNT
  --  1.3  04/02/2018  Diptasurjya       CHG0041892 - if source is STRATAFORCE the return N
  --  1.4  14.08.2018  Lingaraj          CHG0043573 - Adjust Discount approval process to support CA order types
  --  1.5  11/07/2018  Diptasurjya       CHG0044277 - Remove header id input
  --------------------------------------------------------------------
  FUNCTION chek_discount_condition(p_so_line_id IN NUMBER,
                                   p_ref_code   IN VARCHAR2) RETURN VARCHAR2 IS
    l_header_id NUMBER;
    l_discount  VARCHAR2(240);
    --l_put_hold            varchar2(50);
    l_sum_adjusted_amount     NUMBER := 0;
    l_adj_amt_ord_curr        NUMBER; --CHG0043573
    l_transactional_curr_code oe_order_headers_all.transactional_curr_code%type; --CHG0043573
    l_min_discount_amount     NUMBER := 0;
    l_max_discount_amount     NUMBER := 0; --CHG0043573
    l_total_order_amount      NUMBER := 0;
  BEGIN
    -- check if there is manual discount in line/header

    -- CHG0033846
    /*  select v.header_id
     into l_header_id
     from oe_price_adjustments_v v
    where v.adjustment_type_code = 'DIS'
      and v.adjustment_name = 'Manual Adjustment'
      and v.adjusted_amount < 0
      and v.line_id = p_so_line_id;*/

    -- CHG0041892 - Start
    if get_order_source(p_so_line_id/*, null*/) in  -- CHG0044277 commented header_id input
       ('STRATAFORCE', 'SERVICE SFDC', 'SFDC PR FSL', 'SFDC QUOTE FSL') --CHG0043573 "SERVICE SFDC" Added to the Condition
     then
      return 'N';
    end if;
    -- CHG0041892 - End

    SELECT o.header_id, o.transactional_curr_code
      INTO l_header_id, l_transactional_curr_code
      FROM oe_order_lines_all l, oe_order_headers_all o
     WHERE l.line_id = p_so_line_id
       and o.header_id = l.header_id;
    --INC0059630
    get_order_discount_pct(l_header_id,
                           l_adj_amt_ord_curr, -- Adjusted Amount in Sales Order Currency #CHG0043573
                           --l_sum_adjusted_amount,
                           l_total_order_amount,
                           l_discount);
    l_adj_amt_ord_curr := abs(l_adj_amt_ord_curr); -- yuval 14.08.18
    --If Sales Order Currency is not USD , convert the Adjusted amount to USD
    --Begin CHG0043573
    If nvl(l_adj_amt_ord_curr, 0) != 0 Then
      If l_transactional_curr_code = 'USD' Then
        l_sum_adjusted_amount := l_adj_amt_ord_curr;
      Else
        l_sum_adjusted_amount := l_adj_amt_ord_curr *
                                 gl_currency_api.get_closest_rate(x_from_currency   => l_transactional_curr_code,
                                                                  x_to_currency     => 'USD',
                                                                  x_conversion_date => trunc(SYSDATE),
                                                                  x_conversion_type => 'Corporate',
                                                                  x_max_roll_days   => 0);
      End If;
    Else
      l_sum_adjusted_amount := l_adj_amt_ord_curr;
    End if;

    --End CHG0043573

    -- l_sum_adjusted_amount := get_manual_adj4order(l_header_id); -- CHG0033846 new logic in function

    --  l_total_order_amount := oe_totals_grp.get_order_total(p_header_id  => l_header_id,
    -- p_line_id => NULL, p_total_type => 'LINES');

    IF nvl(l_sum_adjusted_amount, 0) <= 0 OR
       l_total_order_amount + l_sum_adjusted_amount = 0 THEN
      fnd_log.string(log_level => fnd_log.level_event,
                     module    => c_debug_module ||
                                  'chek_discount_condition',
                     message   => 'So Line id = ' || p_so_line_id ||
                                  ' So Header id = ' || l_header_id ||
                                  ' l_discount = ' || l_discount ||
                                  ' l_sum_adjusted_amount = ' ||
                                  l_sum_adjusted_amount ||
                                  ' l_min_discount_amount = ' ||
                                  l_min_discount_amount);

      RETURN 'N';

    END IF;

    /*   l_discount := round(100 *
    (l_sum_adjusted_amount /
    (l_sum_adjusted_amount + l_total_order_amount)),
    2);*/

    /*  SELECT abs(SUM(v.adjusted_amount * oola.pricing_quantity))
    INTO   l_sum_adjusted_amount
    FROM   oe_price_adjustments_v v,
           ont.oe_order_lines_all oola
    WHERE  v.adjustment_type_code = 'DIS'
    AND    v.adjustment_name = 'Manual Adjustment'
    AND    v.line_id = oola.line_id
    AND    v.header_id = l_header_id;*/

    -- check at setup table
    BEGIN
      SELECT xxahs.min_discount_amount,
             nvl(xxahs.max_discount_amount, l_sum_adjusted_amount)
        INTO l_min_discount_amount, l_max_discount_amount
        FROM oe_order_headers_all ooha, xxom_approval_hold_setup xxahs
       WHERE ooha.header_id = l_header_id -- < Parameter >
         AND xxahs.order_type_id = ooha.order_type_id
         AND l_discount > xxahs.from_threshold
         AND l_discount <= xxahs.to_threshold
         AND l_sum_adjusted_amount between xxahs.min_discount_amount and
             nvl(xxahs.max_discount_amount, l_sum_adjusted_amount)
         AND xxahs.reference_code = p_ref_code; -- < Parameter >

      -- Debug Message
      fnd_log.string(log_level => fnd_log.level_event,
                     module    => c_debug_module ||
                                  'chek_discount_condition',
                     message   => 'So Line id = ' || p_so_line_id ||
                                  ' So Header id = ' || l_header_id ||
                                  ' l_discount = ' || l_discount ||
                                  ' l_sum_adjusted_amount = ' ||
                                  l_sum_adjusted_amount ||
                                  ' l_min_discount_amount = ' ||
                                  l_min_discount_amount ||
                                  ' l_max_discount_amount = ' ||
                                  l_max_discount_amount);

      IF (l_sum_adjusted_amount >= l_min_discount_amount) AND
         (l_sum_adjusted_amount <= l_max_discount_amount) --CHG0043573
         AND (l_min_discount_amount > 0) THEN
        RETURN 'Y';
      ELSE
        RETURN 'N';
      END IF;

    EXCEPTION
      WHEN no_data_found THEN
        -- Debug Message
        fnd_log.string(log_level => fnd_log.level_event,
                       module    => c_debug_module ||
                                    'chek_discount_condition',
                       message   => 'no_data_found ERR - So Line id = ' ||
                                    p_so_line_id || ' So Header id = ' ||
                                    l_header_id || ' l_discount = ' ||
                                    l_discount ||
                                    ' l_sum_adjusted_amount = ' ||
                                    l_sum_adjusted_amount ||
                                    ' l_min_discount_amount = ' ||
                                    l_min_discount_amount);
        RETURN 'N';
      WHEN too_many_rows THEN
        -- Debug Message
        fnd_log.string(log_level => fnd_log.level_event,
                       module    => c_debug_module ||
                                    'chek_discount_condition',
                       message   => 'too_many_rows ERR - So Line id = ' ||
                                    p_so_line_id || ' So Header id = ' ||
                                    l_header_id || ' l_discount = ' ||
                                    l_discount ||
                                    ' l_sum_adjusted_amount = ' ||
                                    l_sum_adjusted_amount ||
                                    ' l_min_discount_amount = ' ||
                                    l_min_discount_amount);
        RETURN 'Y';
    END;

  END chek_discount_condition;

  --------------------------------------------------------------------
  --  name:            get_fyi_email_list
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   get concatenate email list in one string by list id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_fyi_email_list(p_fyi_note_list_id IN NUMBER) RETURN VARCHAR2 IS
    l_email_list  VARCHAR2(4000);
    l_email_list2 VARCHAR2(4000);
  BEGIN
    SELECT listagg(p.email_address, '; ') within GROUP(ORDER BY l.name) email_list
      INTO l_email_list
      FROM oe_approver_lists        l,
           oe_approver_list_members lm,
           per_all_people_f         p,
           fnd_user                 u
     WHERE lm.list_id = l.list_id
       AND u.user_name = lm.role
       AND u.employee_id = p.person_id
       AND trunc(SYSDATE) BETWEEN p.effective_start_date AND
           p.effective_end_date
       AND nvl(lm.active_flag, 'Y') = 'Y'
       AND hr_person_type_usage_info.get_user_person_type(trunc(SYSDATE),
                                                          p.person_id) NOT LIKE
           'Ex%'
       AND l.list_id = p_fyi_note_list_id
     GROUP BY l.name, l.list_id;

    -- if in the string there are 2 emails the same this select take it out.
    BEGIN
      SELECT listagg(b.split, '; ') within GROUP(ORDER BY 1)
        INTO l_email_list2
        FROM (SELECT DISTINCT a.split
                FROM (SELECT regexp_substr(l_email_list, '[^; ]+', 1, rownum) split
                        FROM dual
                      CONNECT BY LEVEL <=
                                 length(regexp_replace(l_email_list, '[^; ]+')) + 1) a
               WHERE split IS NOT NULL) b;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN substr(l_email_list, 1, 2000);
    END;

    RETURN substr(l_email_list2, 1, 2000);

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_fyi_email_list;

  --------------------------------------------------------------------
  --  name:            get_approver_and_fyi
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   09/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   get the approver by so_line_id and order type
  --                   use at the Auto Hold setup - Approver Sql
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  09/09/2014  Dalit A. Raviv    initial build
  --  1.1  25/11/2014  Dalit A. Raviv    CTASK0018753 - UAT modifications
  --                                     for order type add ability of FC Reason.
  --  1.2  19/04/2015  Dalit A. Raviv    CHG0034419 - Add Customer support auto hold functionality
  --  1.3  3.3.16      yuval tal         INC0059630 - use get_order_discount_pct in DISCOUNT
  --  1.4  14.08.2018  Lingaraj          CHG0043573 - Adjust Discount approval process to support CA order types
  --------------------------------------------------------------------
  PROCEDURE get_approver_and_fyi(p_header_id     IN NUMBER,
                                 p_ref_code      IN VARCHAR2,
                                 p_approver      OUT VARCHAR2,
                                 p_fyi_mail_list OUT VARCHAR2,
                                 p_log_code      OUT VARCHAR2,
                                 p_log_msg       OUT VARCHAR2) IS

    l_fyi_note_list_id NUMBER;
    l_threshold        NUMBER;
    l_discount         NUMBER;
    l_foc_approver     VARCHAR2(150) := NULL;
    l_foc_fyi_list_id  NUMBER;
    l_foc_reason       VARCHAR2(150) := NULL;

    l_sum_adjusted_amount     NUMBER;
    l_total_order_amount      NUMBER;
    l_adj_amt_ord_curr        NUMBER; --CHG0043573
    l_transactional_curr_code VARCHAR2(5); --CHG0043573
  BEGIN
    p_log_code := 0;
    p_log_msg  := NULL;

    -- 1.2 19/04/2015 Dalit A. Raviv CHG0034419 add handle to ref_code = CS_HOLD
    IF p_ref_code IN ('ORDER_TYPE', 'TERMS_COND', 'CS_HOLD') THEN
      BEGIN
        SELECT xxahs.approver,
               xxahs.fyi_note_list_id,
               xxahs.foc_fyi_note_list_id,
               xxahs.foc_approver,
               ooha.attribute1
          INTO p_approver,
               l_fyi_note_list_id,
               l_foc_fyi_list_id,
               l_foc_approver,
               l_foc_reason
          FROM oe_order_headers_all ooha, xxom_approval_hold_setup xxahs
         WHERE ooha.header_id = p_header_id -- < Parameter >
           AND xxahs.order_type_id = ooha.order_type_id
           AND xxahs.reference_code = p_ref_code; -- < Parameter >
      EXCEPTION
        WHEN OTHERS THEN
          p_approver         := NULL;
          l_fyi_note_list_id := NULL;
          p_log_code         := 1;
          p_log_msg          := 'Can not find approver and fyi note list';
      END;
      --  1.1 25/11/2014 Dalit A. Raviv CTASK0018753
      --  if this order is from order type taht relate to FOC
      --  the approver and FYI will be the value from the FOC fields .
      --  if no data enetered the value that will return is the original approver and FYI list.
      IF p_ref_code = 'ORDER_TYPE' AND l_foc_reason = 'Customer Support' THEN
        p_approver         := nvl(l_foc_approver, p_approver);
        l_fyi_note_list_id := nvl(l_foc_fyi_list_id, l_fyi_note_list_id);
      END IF;

    END IF; -- p_ref_code

    IF p_ref_code = 'PAYMENT_TERMS' THEN
      -- in this stage there is an hold allredy on the order so there is no need to check
      -- the threshold from PT compare to with default PT.

      -- get payment terms threshold of the order
      BEGIN
        SELECT nvl(rt.attribute1, 0)
          INTO l_threshold
          FROM oe_order_headers_all ooha, ra_terms_b rt
         WHERE ooha.header_id = p_header_id -- < Parameter >
           AND ooha.payment_term_id = rt.term_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_threshold := 0;
      END;
      -- get approver and fyi_note_list from setup tbl
      BEGIN
        SELECT xxahs.approver, xxahs.fyi_note_list_id
          INTO p_approver, l_fyi_note_list_id
          FROM oe_order_headers_all ooha, xxom_approval_hold_setup xxahs
         WHERE ooha.header_id = p_header_id -- < Parameter >
           AND xxahs.order_type_id = ooha.order_type_id
           AND l_threshold >= xxahs.from_threshold
           AND l_threshold <= xxahs.to_threshold
           AND xxahs.reference_code = p_ref_code; -- < Parameter >

      EXCEPTION
        WHEN OTHERS THEN
          p_approver         := NULL;
          l_fyi_note_list_id := NULL;
          p_log_code         := 1;
          p_log_msg          := 'Can not find approver and fyi note list';
      END;
    END IF;
    IF p_ref_code = 'DISCOUNT' THEN
      -- get avg discount for the order

      --  l_discount := to_number(xxoe_utils_pkg.get_order_average_discount(p_header_id));
      -- l_discount := get_order_discount_pct(p_header_id);
      -- INC0059630
      get_order_discount_pct(p_header_id,
                             l_adj_amt_ord_curr, --CHG0043573
                             --l_sum_adjusted_amount,
                             l_total_order_amount,
                             l_discount);

      --Begin CHG0043573
      -- Get the Sales Order Currency Code
      Select transactional_curr_code
        into l_transactional_curr_code
        from oe_order_headers_all
       where header_id = p_header_id;

      --If Sales Order Currency is not USD , convert the Adjusted amount to USD
      If nvl(l_adj_amt_ord_curr, 0) != 0 Then
        If l_transactional_curr_code = 'USD' Then
          l_sum_adjusted_amount := l_adj_amt_ord_curr;
        Else
          l_sum_adjusted_amount := l_adj_amt_ord_curr *
                                   gl_currency_api.get_closest_rate(x_from_currency   => l_transactional_curr_code,
                                                                    x_to_currency     => 'USD',
                                                                    x_conversion_date => trunc(SYSDATE),
                                                                    x_conversion_type => 'Corporate',
                                                                    x_max_roll_days   => 0);
        End If;
      Else
        l_sum_adjusted_amount := l_adj_amt_ord_curr;
      End if;
      --End CHG0043573

      -- get details from setup table
      BEGIN
        SELECT xxahs.approver, xxahs.fyi_note_list_id
          INTO p_approver, l_fyi_note_list_id
          FROM oe_order_headers_all ooha, xxom_approval_hold_setup xxahs
         WHERE ooha.header_id = p_header_id -- < Parameter >
           AND xxahs.order_type_id = ooha.order_type_id
           AND l_discount > xxahs.from_threshold
           AND l_discount <= xxahs.to_threshold
           AND ABS(l_sum_adjusted_amount) >= xxahs.min_discount_amount --CHG0043573
           AND ABS(l_sum_adjusted_amount) <=
               NVL(xxahs.max_discount_amount, ABS(l_sum_adjusted_amount)) --CHG0043573
           AND xxahs.reference_code = p_ref_code; -- < Parameter >
      END;

    END IF;
    -- get email list
    IF l_fyi_note_list_id IS NOT NULL THEN
      p_fyi_mail_list := get_fyi_email_list(l_fyi_note_list_id);
    END IF; -- get email list

    -- 1.1 25/11/2014 Dalit A. Raviv CTASK0018753 add debug handling
    -- Debug Message
    fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || 'get_approver_and_fyi',
                   message   => 'p_header_id = ' || p_header_id ||
                                ' p_ref_code = ' || p_ref_code ||
                                ' p_approver = ' || p_approver ||
                                ' p_fyi_mail_list = ' || p_fyi_mail_list);

  EXCEPTION
    WHEN OTHERS THEN
      p_approver      := NULL;
      p_fyi_mail_list := NULL;
      p_log_code      := 1;
      p_log_msg       := 'Gen Exc - ' || substr(SQLERRM, 1, 240);
  END get_approver_and_fyi;

  --------------------------------------------------------------------
  --  name:            check_order_type_condition
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   get if order type exists at the setup to put hold.
  --                   use at the Auto Hold setup - condition of "SSYS Order Type Approval"
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION check_order_type_condition(p_so_line_id IN NUMBER,
                                      p_ref_code   IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_exists VARCHAR2(100);
  BEGIN
    SELECT 'Y'
      INTO l_exists
      FROM oe_order_headers_all     ooha,
           oe_order_lines_all       oola,
           xxom_approval_hold_setup xxahs
     WHERE ooha.header_id = oola.header_id
       AND oola.line_id = p_so_line_id -- < Parameter >
       AND xxahs.order_type_id = ooha.order_type_id
       AND xxahs.reference_code = p_ref_code; -- 'ORDER_TYPE';

    RETURN l_exists;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN too_many_rows THEN
      RETURN 'Y';
      --when others then
    --return 'N';
  END check_order_type_condition;

  --------------------------------------------------------------------
  --  name:            check_CS_condition
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/04/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   CHG0034419 - Add Customer support auto hold functionality
  --                   This function check if to put SO under CS hold
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/04/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION check_cs_condition(p_so_line_id IN NUMBER,
                              p_ref_code   IN VARCHAR2,
                              p_category   IN VARCHAR2) RETURN VARCHAR2 IS
    l_exists VARCHAR2(100);
  BEGIN
    SELECT 'Y'
      INTO l_exists
      FROM inv.mtl_categories_b     c,
           mtl_item_categories_v    icat,
           ont.oe_order_lines_all   oola,
           oe_order_headers_all     ooha,
           inv.mtl_parameters       o,
           xxom_approval_hold_setup xxahs
     WHERE c.category_id = icat.category_id
       AND c.structure_id = icat.structure_id
       AND icat.inventory_item_id = oola.inventory_item_id
       AND icat.organization_id = oola.ship_from_org_id
       AND o.organization_id = icat.organization_id
       AND icat.category_set_name = 'Activity Analysis' -- c.structure_id = 50509
       AND c.segment1 = p_category -- 'BDL-SC'     -- Category
       AND oola.line_id = oola.top_model_line_id -- this is the PTO Model condition
       AND oola.line_id = p_so_line_id -- < Parameter >
       AND ooha.header_id = oola.header_id
       AND xxahs.order_type_id = ooha.order_type_id
       AND xxahs.reference_code = p_ref_code; -- 'CS_HOLD';

    RETURN l_exists;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN too_many_rows THEN
      RETURN 'Y';
    WHEN OTHERS THEN
      RETURN 'N';
  END check_cs_condition;

  --------------------------------------------------------------------
  --  name:            get_pt_threshold
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   get the threshold of a payment term (attribute1)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_pt_threshold(p_term_id IN NUMBER) RETURN NUMBER IS

    l_threshold NUMBER;
  BEGIN
    SELECT nvl(attribute1, 0)
      INTO l_threshold
      FROM ra_terms_b rt
     WHERE rt.term_id = p_term_id;

    RETURN l_threshold;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_pt_threshold;

  --------------------------------------------------------------------
  --  name:            is_pt_threshold_exist
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   get if by order type and line_id there is a
  --                   setup for threshold
  --                   use at the Auto Hold setup - condition of "SSYS Payment Terms Approval"
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/09/2014  Dalit A. Raviv    initial build
  --  1.1  04/02/2018  Diptasurjya       CHG0041892 - Fetch default payment term id from quote
  --                                     if order source is STRATAFORCE
  --  1.2  11/07/2018  Diptasurjya       CHG0044277 - commented header_id in call to get_order_source
  --------------------------------------------------------------------
  FUNCTION is_pt_threshold_exist(p_so_line_id IN NUMBER,
                                 p_ref_code   IN VARCHAR2) RETURN VARCHAR IS

    l_exists            VARCHAR2(100) := 'N';
    l_header_rec        oe_ak_order_headers_v%ROWTYPE;
    l_default_pt_id     NUMBER;
    l_order_pt_id       NUMBER;
    l_default_threshold NUMBER;
    l_order_threshold   NUMBER;
  BEGIN
    -- look for the payment terms from the default, what was the threshold for this payment terms,
    -- and this value compare to to the value of the payment terms that is now at the order.
    -- if the new value is bigger then the old value, go to setup and find from there if need to
    -- put the order in hold.

    IF p_ref_code = 'PAYMENT_TERMS' THEN
      -- Get default payment terms id (pt)
      BEGIN
        SELECT ooha.header_id,
               ooha.org_id,
               ooha.order_type_id,
               ooha.agreement_id,
               ooha.invoice_to_org_id,
               ooha.ship_to_org_id,
               ooha.sold_to_org_id,
               ooha.price_list_id,
               ooha.blanket_number,
               ooha.payment_term_id
          INTO l_header_rec.header_id,
               l_header_rec.org_id,
               l_header_rec.order_type_id,
               l_header_rec.agreement_id,
               l_header_rec.invoice_to_org_id,
               l_header_rec.ship_to_org_id,
               l_header_rec.sold_to_org_id,
               l_header_rec.price_list_id,
               l_header_rec.blanket_number,
               l_order_pt_id
          FROM oe_order_headers_all ooha, oe_order_lines_all oola
         WHERE ooha.header_id = oola.header_id
           AND oola.line_id = p_so_line_id; -- parameter

        mo_global.set_policy_context('S', l_header_rec.org_id);
        oe_globals.set_context();

        if get_order_source(p_so_line_id/*, null*/) = 'STRATAFORCE' then  -- CHG0044277 commented header_id 
          -- CHG0041892
          l_default_pt_id := xxom_salesorder_api.get_quote_pterms(p_so_line_id,
                                                                  'STRATAFORCE'); -- CHG0041892
        else
          -- CHG0041892
          l_default_pt_id := ont_d1_payment_term_id.get_default_value(p_header_rec => l_header_rec);
        end if; -- CHG0041892
      EXCEPTION
        WHEN OTHERS THEN
          l_default_pt_id := NULL;
      END;
      -- if payment terms (pt) have been changed from default
      IF nvl(l_default_pt_id, 0) <> nvl(l_order_pt_id, 0) THEN
        -- get attribute1
        l_default_threshold := get_pt_threshold(l_default_pt_id);
        l_order_threshold   := get_pt_threshold(l_order_pt_id);
        -- if the today pt threshold is bigger then go and look at the setup form.
        IF nvl(l_order_threshold, 0) > nvl(l_default_threshold, 0) THEN
          -- to ask Moni what is the default for nvl
          SELECT 'Y'
            INTO l_exists
            FROM xxom_approval_hold_setup xxahs
           WHERE xxahs.order_type_id = l_header_rec.order_type_id
             AND xxahs.reference_code = 'PAYMENT_TERMS' -- < Parameter >
             AND nvl(l_order_threshold, 0) >= xxahs.from_threshold
             AND nvl(l_order_threshold, 0) <= xxahs.to_threshold;
        END IF; -- compare threshold
      END IF; -- pt today with default (pt = payment terms)
    END IF;
    RETURN l_exists;
  EXCEPTION
    WHEN too_many_rows THEN
      RETURN 'Y';
    WHEN no_data_found THEN
      RETURN 'N';
      --when others then
    --  return 'N';
  END is_pt_threshold_exist;

  --------------------------------------------------------------------
  --  name:            is_attachment_exist
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   check if specific attachment exists at header/line level
  --                   if YES put the order in Hold.
  --                   use at the Auto Hold setup - condition of "SSYS Terms & Conditions Approval"
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_attachment_exist(p_so_line_id  IN NUMBER,
                               p_attach_name IN VARCHAR2) RETURN VARCHAR2 IS

    l_exist NUMBER := 0;
  BEGIN

    SELECT header_id
      INTO l_exist
      FROM ( -- check attachment exist at header level
            SELECT ooha.header_id
              FROM oe_order_headers_all       ooha,
                    oe_order_lines_all         oola,
                    xxom_approval_hold_setup   xxahs,
                    fnd_attached_documents     fad,
                    fnd_document_categories    fdc,
                    fnd_document_categories_tl fdctl
             WHERE ooha.header_id = oola.header_id
               AND oola.line_id = p_so_line_id -- < Parameter >
               AND fad.entity_name = 'OE_ORDER_HEADERS'
               AND fad.pk1_value = ooha.header_id
               AND fad.category_id = fdc.category_id
               AND fdc.category_id = fdctl.category_id
               AND fdc.name = fdctl.name
               AND fdctl.language = 'US'
               AND fdctl.user_name = p_attach_name
               AND xxahs.order_type_id = ooha.order_type_id
               AND xxahs.reference_code = 'TERMS_COND'
            UNION
            -- check attachment exist at line level
            SELECT ooha.header_id
              FROM oe_order_headers_all       ooha,
                    oe_order_lines_all         oola,
                    xxom_approval_hold_setup   xxahs,
                    fnd_attached_documents     fad,
                    fnd_document_categories    fdc,
                    fnd_document_categories_tl fdctl
             WHERE ooha.header_id = oola.header_id
               AND oola.line_id = p_so_line_id -- < Parameter >
               AND fad.entity_name = 'OE_ORDER_LINES'
               AND fad.pk1_value = oola.line_id
               AND fad.category_id = fdc.category_id
               AND fdc.category_id = fdctl.category_id
               AND fdc.name = fdctl.name
               AND fdctl.language = 'US'
               AND fdctl.user_name = p_attach_name
               AND xxahs.order_type_id = ooha.order_type_id
               AND xxahs.reference_code = 'TERMS_COND');

    RETURN 'Y';

  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN too_many_rows THEN
      RETURN 'Y';
      --when others then
    --  return 'N';
  END is_attachment_exist;
  --------------------------------------------------------------------
  --  name:            is_discount_overlap
  --  create by:       Lingaraj
  --  Revision:        1.0
  --  creation date:   26/08/2018
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   use from the parameter form - validate that there
  --                   is no overlap of the discount and threshold
  --                   from - to numbers
  --------------------------------------------------------------------
  --  ver  when        who          desc
  --  ---  ----------  -----------  ----------------------------------
  --  1.0  26/08/2018  Roman W.     CHG0043573 - Adjust Discount approval process to support CA order types
  --------------------------------------------------------------------
  FUNCTION is_discount_overlap(p_order_type_id  IN NUMBER,
                               p_reference_code IN VARCHAR2,
                               p_approval_hold_id IN NUMBER,
                               p_from_per_dis   IN NUMBER,
                               p_to_per_dis     IN NUMBER,
                               p_min_dis        IN NUMBER,
                               p_max_dis        IN NUMBER
                               ) RETURN VARCHAR2
   is
   l_threshold_overlap VARCHAR2(1) := 'N';
   l_discount_overlap  VARCHAR2(1) := 'N';
   begin
       --Is threshold Overlapping ? If No , Return N
       Begin
         select   'Y'
         into l_threshold_overlap
         from xxom_approval_hold_setup xahs
         where xahs.order_type_id = p_order_type_id
         and xahs.REFERENCE_CODE  = 'DISCOUNT'
         and xahs.approval_hold_id != nvl(p_approval_hold_id,-1)
         and ((p_from_per_dis between
                     xahs.FROM_THRESHOLD and xahs.TO_THRESHOLD
              )
              OR
              (p_to_per_dis between
                     xahs.FROM_THRESHOLD and xahs.TO_THRESHOLD
              )
              OR
               (xahs.FROM_THRESHOLD between p_from_per_dis and p_to_per_dis)
              OR
               (xahs.TO_THRESHOLD between p_from_per_dis and p_to_per_dis)
              );
       Exception
          When no_data_found Then
             l_threshold_overlap := 'N';
          When too_many_rows Then
             l_threshold_overlap := 'Y';
       End;


       -- threshold is Overlapping
       If l_threshold_overlap = 'Y' Then
         Begin
            select   'Y'
             into l_discount_overlap
             from xxom_approval_hold_setup xahs
             where xahs.order_type_id = p_order_type_id
             and xahs.REFERENCE_CODE  = 'DISCOUNT'
             and xahs.approval_hold_id != nvl(p_approval_hold_id,-1)
             and
             (
                 p_min_dis between  xahs.MIN_DISCOUNT_AMOUNT
                              and nvl(xahs.MAX_DISCOUNT_AMOUNT,999999999999)

                 OR
                 nvl(p_max_dis,999999999999)
                     between  xahs.MIN_DISCOUNT_AMOUNT
                              and nvl(xahs.MAX_DISCOUNT_AMOUNT,999999999999)
                 OR
                 xahs.MIN_DISCOUNT_AMOUNT between
                               p_min_dis and  nvl(p_max_dis,999999999999)
                 OR
                 xahs.MAX_DISCOUNT_AMOUNT between
                               p_min_dis and  nvl(p_max_dis,999999999999)

             );

         Exception
         When no_data_found Then
             l_discount_overlap := 'N';
         When too_many_rows Then
             l_discount_overlap := 'Y';
         End;

         Return l_discount_overlap;
       Else
         -- threshold is not Overlapping
         Return 'N';
       End If;

    --   Return 'N';
   End is_discount_overlap;
  --------------------------------------------------------------------
  --  name:            is_overlap_numbers
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   use from the parameter form - validate that there
  --                   is no overlap of the discount/payment term threshold
  --                   from - to numbers
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/09/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION is_overlap_numbers(p_order_type_id  IN NUMBER,
                              p_reference_code IN VARCHAR2) RETURN VARCHAR2 IS

    l_nextbeginrange NUMBER;
  BEGIN
    SELECT nextbeginrange
      INTO l_nextbeginrange
      FROM (SELECT s.*,
                   lead(from_threshold) over(ORDER BY from_threshold, to_threshold) nextbeginrange
              FROM xxom_approval_hold_setup s
             WHERE reference_code = p_reference_code --'DISCOUNT'
               AND order_type_id = p_order_type_id --1040 --1024
            )
     WHERE to_threshold > nextbeginrange;
    -- case record found there is an overlap
    RETURN 'Y';
  EXCEPTION
    -- case no records found - no overlap
    WHEN no_data_found THEN
      RETURN 'N';
      -- case several records found there is an overlap
    WHEN too_many_rows THEN
      RETURN 'Y';
    WHEN OTHERS THEN
      RETURN 'N';

  END is_overlap_numbers;

  --------------------------------------------------------------------
  --  name:            prepare_agg_body_msg_frw
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/10/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   use at the FRW to print the region of the Hold information
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/10/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION prepare_agg_body_msg_frw(p_auto_hold_ids IN VARCHAR2)
    RETURN xxom_autohold_tab_type IS

    -- Auto holds Information
    CURSOR c(p_str IN VARCHAR2) IS
      SELECT ah.hold_stage, hd.name hold_name, ah.approver_body_msg
        FROM xxom_auto_hold ah, oe_hold_definitions hd
       WHERE ah.hold_id = hd.hold_id
         AND ah.auto_hold_id IN
             (SELECT regexp_substr(p_str, '[^,]+', 1, LEVEL) auto_hold_id
                FROM dual
              CONNECT BY regexp_substr(p_str, '[^,]+', 1, LEVEL) IS NOT NULL);

    t_xxom_ah_tab_type xxom_autohold_tab_type := xxom_autohold_tab_type();
    l_msg              VARCHAR2(1000);
  BEGIN

    FOR r IN c(p_auto_hold_ids) LOOP
      t_xxom_ah_tab_type.extend;
      t_xxom_ah_tab_type(t_xxom_ah_tab_type.last) := xxom_autohold_rec_type(r.hold_stage,
                                                                            r.hold_name,
                                                                            r.approver_body_msg);
    END LOOP;

    RETURN t_xxom_ah_tab_type;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_message.set_name('XXOBJT', 'XXOM_AUTO_HOLD_AGG_FRW_MSG');
      fnd_message.set_token('AUTO_HOLD_IDS', p_auto_hold_ids);
      l_msg := fnd_message.get;
      t_xxom_ah_tab_type.extend;
      t_xxom_ah_tab_type(t_xxom_ah_tab_type.last) := xxom_autohold_rec_type('.',
                                                                            '.',
                                                                            l_msg);

  END prepare_agg_body_msg_frw;

  --------------------------------------------------------------------
  --  name:            prepare_agg_body_msg
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/08/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   Handle prepare the approver message
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/08/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE prepare_agg_body_msg(document_id   IN VARCHAR2, -- p_so_header_id||'|'|| p_auto_hold_ids 773708|2,3
                                 display_type  IN VARCHAR2,
                                 document      IN OUT NOCOPY CLOB,
                                 document_type IN OUT NOCOPY VARCHAR2) IS

    -- Sales order information
    CURSOR so_c(p_so_header_id IN NUMBER) IS
      SELECT oh.order_number so_order_number,
             oh.header_id,
             oh.sold_to_org_id customer_id,
             oh.order_type_id,
             ot.name order_type,
             oh.payment_term_id,
             rt.name payment_term,
             nvl(attribute17, 'No Discount') discount
        FROM oe_order_headers_all    oh,
             ra_terms_tl             rt,
             oe_transaction_types_tl ot
       WHERE oh.header_id = p_so_header_id
         AND oh.payment_term_id = rt.term_id
         AND rt.language = 'US'
         AND oh.order_type_id = ot.transaction_type_id
         AND ot.language = 'US';
    /*select oh.order_number   so_order_number,
          oh.header_id,
          oh.sold_to_org_id customer_id
     from oe_order_headers_all oh
    where oh.header_id = p_so_header_id; --773708*/
    -- Auto holds Information
    CURSOR c(p_str IN VARCHAR2) IS
      SELECT regexp_substr(p_str, '[^,]+', 1, LEVEL) auto_hold_id
        FROM dual
      CONNECT BY regexp_substr(p_str, '[^,]+', 1, LEVEL) IS NOT NULL;

    l_auto_hold_ids     VARCHAR2(250);
    l_so_header_id      NUMBER;
    l_hold_stage        VARCHAR2(10);
    l_approver_body_msg VARCHAR2(1500);
    l_hold_name         VARCHAR2(240);
    l_temp_str          VARCHAR2(500);
    l_entity            VARCHAR2(100);
    l_msg               VARCHAR2(2000);
    l_order_ammount     NUMBER;
    l_order_currency    VARCHAR2(150);
    l_order_ammount_c   VARCHAR2(150);
  BEGIN
    l_temp_str      := document_id;
    l_so_header_id  := substr(l_temp_str, 1, instr(l_temp_str, '|') - 1);
    l_temp_str      := substr(l_temp_str, instr(l_temp_str, '|') + 1);
    l_auto_hold_ids := substr(l_temp_str, 1, instr(l_temp_str, '|') - 1);
    l_entity        := substr(l_temp_str, instr(l_temp_str, '|') + 1);

    document_type := 'text/html';
    document      := ' ';

    IF l_entity = 'APPROVE' THEN
      fnd_message.set_name('XXOBJT', 'XXOM_AUTO_HOLD_AGG_APPROVE_MSG');
      l_msg := fnd_message.get; --' is placed under automatic holds and cannot be progressed.';
    ELSE
      fnd_message.set_name('XXOBJT', 'XXOM_AUTO_HOLD_AGG_RELEASE_MSG');
      l_msg := fnd_message.get; --' has been released from several automatic holds ';
    END IF;

    FOR rr IN so_c(l_so_header_id) LOOP
      -- get order amount
      BEGIN
        SELECT SUM(oola.unit_selling_price + oola.tax_value)
          INTO l_order_ammount
          FROM ont.oe_order_lines_all oola
         WHERE oola.header_id = l_so_header_id
           AND oola.flow_status_code <> 'CANCELLED';
      EXCEPTION
        WHEN OTHERS THEN
          l_order_ammount := NULL;
      END;
      IF l_order_ammount IS NOT NULL THEN
        l_order_ammount_c := TRIM(to_char(l_order_ammount, '999,999,999.99'));
      END IF;
      -- get order currency code
      BEGIN
        SELECT plh.currency_code
          INTO l_order_currency
          FROM ont.oe_order_headers_all ooha, qp.qp_list_headers_b plh
         WHERE ooha.price_list_id = plh.list_header_id
           AND ooha.header_id = l_so_header_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_order_currency := NULL;
      END;
      document := 'Hi, <BR><BR>' || 'Please note that Sales Order no ' ||
                  rr.so_order_number || ', Amount: ' || l_order_ammount_c || ' (' ||
                  l_order_currency || ')' || ', for customer ' ||
                  get_so_customer_name(rr.customer_id) || ' ' || l_msg ||
                 --' is placed under automatic holds and cannot be progressed.'||
                  '<BR><BR>';
      dbms_lob.append(document,
                      '<p> <font face="Verdana" style="color:darkblue" size="3"> <strong> Additional Order Information </font> </p>');
      dbms_lob.append(document,
                      '<TABLE border=1 cellPadding=3>' ||
                      '<TR> <TD><B> Order Type</B> </TD><TD>' ||
                      rr.order_type || '</TD></TR>' ||
                      '<TR> <TD><B> Discount Percent</B> </TD><TD>' ||
                      rr.discount || '</TD></TR>' ||
                      '<TR> <TD><B> Payment Term</B> </TD><TD>' ||
                      rr.payment_term || '</TD></TR>' || '</TABLE>');

      dbms_lob.append(document,
                      '<BR><BR>' ||
                      '<p> <font style="color:darkblue" size="3"> Holds Details </font> </p>');
      dbms_lob.append(document,
                      '<TABLE border=1 cellPadding=3>
             <TR>
     <TH>Hold Stage</TH>
     <TH>Hold Name</TH>
     <TH>Message</TH>
             </TR>');

      FOR r IN c(l_auto_hold_ids) LOOP
        l_hold_stage        := NULL;
        l_approver_body_msg := NULL;
        l_hold_name         := NULL;
        BEGIN
          SELECT ah.hold_stage, ah.approver_body_msg, hd.name
            INTO l_hold_stage, l_approver_body_msg, l_hold_name
            FROM xxom_auto_hold ah, oe_hold_definitions hd
           WHERE ah.auto_hold_id = r.auto_hold_id
             AND ah.hold_id = hd.hold_id;

          dbms_lob.append(document,
                          '<TR>' || '<TD>' || l_hold_stage || '</TD>' ||
                          '<TD>' || l_hold_name || '</TD>' || '<TD>' ||
                          nvl(l_approver_body_msg, '&nbsp') || '</TD>' ||
                          '</TR>');
        END;
      END LOOP;
    END LOOP;
    ----
    /*for rr in so_c(l_so_header_id) loop

      --dbms_lob.append (document,'<BR>');
      --dbms_lob.append(document,'<p> <font face="Verdana" style="color:darkblue" size="3"> <strong>SO Holds information</strong> </font> </p>');
      dbms_lob.append(document,
                      '<BR>'||'<p> <font face="Verdana" style="color:darkblue" size="3"> <strong> Additional Order Information </font> </p>');
      dbms_lob.append(document,
                      '<TABLE border=1 cellPadding=3>'||
                      '<TR> <TD>Order Type</B> </TD><TD>'||rr.order_type||'</TD></TR>'||
                      '<TR> <TD>Discount Percent</B> </TD><TD>'||rr.discount||'</TD></TR>'||
                      '<TR> <TD>Payment Term</B> </TD><TD>'||rr.payment_term ||'</TD></TR>'||
                      '<TR> <TD>Order Amount</B> </TD><TD>'||l_order_ammount ||'</TD></TR>'||
                      '<TR> <TD>Order Currency</B> </TD><TD>'||l_order_currency ||'</TD></TR>'||
                      '</TABLE>');

    end loop;*/

    dbms_lob.append(document, '</TABLE>');
    dbms_lob.append(document, '<BR><BR>' || 'Oracle Admin');
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context(g_pkg_name,
                      'prepare_body_msg',
                      document_id,
                      display_type);
      RAISE;
  END prepare_agg_body_msg;

  --------------------------------------------------------------------
  --  name:            agg_initiate_hold_process
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/04/2013
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   Handle set WF variables, and initiate the WF itself
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --  1.1  01/03/2015  Dalit A. Raviv    CHG0034541 add #FROM_ROLE attribute agg_initiate_hold_process
  --------------------------------------------------------------------
  PROCEDURE agg_initiate_hold_process(errbuf             OUT VARCHAR2,
                                      retcode            OUT NUMBER,
                                      p_auto_hold_ids    IN VARCHAR2,
                                      p_so_number        IN NUMBER,
                                      p_so_header_id     IN NUMBER,
                                      p_approver         IN VARCHAR2,
                                      p_customer_id      IN NUMBER,
                                      p_header_type_name IN VARCHAR2,
                                      p_cust_po_number   IN VARCHAR2,
                                      p_org_id           IN NUMBER,
                                      p_batch_id         IN NUMBER,
                                      p_wf_item_key      IN VARCHAR2,
                                      p_fyi_email_list   IN VARCHAR2) IS

    l_order_creator VARCHAR2(240);
    l_customer_name VARCHAR2(240);

  BEGIN
    errbuf  := NULL;
    retcode := 0;

    -- Get Order Creator
    l_order_creator := get_order_creator(p_so_header_id);

    -- this is to prevent from the wf to finish with error
    -- because the creator is need only for FYI note.
    IF xxobjt_general_utils_pkg.is_open_user(l_order_creator, NULL) = 'N' THEN
      l_order_creator := 'SYSADMIN';
    END IF;

    -- get customer name
    l_customer_name := get_so_customer_name(p_customer_id);

    -- create wf process
    wf_engine.createprocess(itemtype   => g_item_type,
                            itemkey    => p_wf_item_key,
                            user_key   => p_so_number,
                            owner_role => fnd_global.user_name, -- p_approver
                            process    => g_agg_process); -- 'AGG_APPROVAL'

    -- Set Wf attributes values
    -- message is a document typ at WF. there for i can not set value with wf_engine.setitemattrtext
    -- instead the item attribute will get the value with this code.
    -- after / id the document_id (the variable that is pass to the procedure.
    -- it can be one value or like here several values concatenated.
    -- ||p_approver||'|'||p_so_header_id||'|'|| p_auto_hold_ids
    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'AGG_BODY_MESSGAE',
                              avalue   => 'JSP:/OA_HTML/OA.jsp?OAFunc=XXOE_ORDER_APPROVAL&HeaderId=' ||
                                          p_so_header_id || '&AutoHoldIds=' ||
                                          p_auto_hold_ids ||
                                          '&Entity=APPROVE');
    /*avalue   => 'plsqlclob:xxom_auto_hold_pkg.prepare_agg_body_msg' || '/' ||
    p_so_header_id || '|' ||
    p_auto_hold_ids || '|' ||
    'APPROVE');*/

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'AGG_REALESE_BODY_MESSGAE',
                              avalue   => 'JSP:/OA_HTML/OA.jsp?OAFunc=XXOE_ORDER_APPROVAL&HeaderId=' ||
                                          p_so_header_id || '&AutoHoldIds=' ||
                                          p_auto_hold_ids ||
                                          '&Entity=REALESE');
    /*avalue   => 'plsqlclob:xxom_auto_hold_pkg.prepare_agg_body_msg' || '/' ||
    p_so_header_id || '|' ||
    p_auto_hold_ids || '|' ||
    'REALESE'); */
    -- text
    -- 1.1 01/03/2015 Dalit A. Raviv CHG0034541
    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => '#FROM_ROLE',
                              avalue   => l_order_creator);

    -- CHG0034541
    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'CC_FYI_CREATOR_LIST',
                              avalue   => p_fyi_email_list);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'ORDER_NUMBER',
                              avalue   => p_so_number);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'ORDER_HEADER_TYPE_NAME',
                              avalue   => p_header_type_name);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'CUST_PO_NUMBER',
                              avalue   => p_cust_po_number);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'CUSTOMER_NAME',
                              avalue   => l_customer_name);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'ORDER_CREATOR',
                              avalue   => l_order_creator);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'AGG_AUTO_HOLD_IDS_LIST',
                              avalue   => p_auto_hold_ids);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => p_wf_item_key,
                              aname    => 'HOLD_APPROVER',
                              avalue   => p_approver);
    -- numbers
    wf_engine.setitemattrnumber(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'CUSTOMER_ID',
                                avalue   => p_customer_id);

    wf_engine.setitemattrnumber(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'SO_HEADER_ID',
                                avalue   => p_so_header_id);

    wf_engine.setitemattrnumber(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'ORG_ID',
                                avalue   => p_org_id);

    wf_engine.setitemattrnumber(itemtype => g_item_type,
                                itemkey  => p_wf_item_key,
                                aname    => 'AGG_BATCH_ID',
                                avalue   => p_batch_id);

    -- Start wf process
    wf_engine.startprocess(itemtype => g_item_type,
                           itemkey  => p_wf_item_key);

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Error: agg_initiate_hold_process:' ||
                 substr(SQLERRM, 1, 240);
      retcode := 1;
  END agg_initiate_hold_process;

  --------------------------------------------------------------------
  --  name:            main_send_aggregate_mail
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   25/08/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032401 - Sales Order Holds Matrix
  --                   Apply Hold using API, for the stage of BOOK
  --                   will run from concurrent program
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/04/2013  Dalit A. Raviv    initial build
  --  1.1  09/07/2015  Dalit A. Raviv    CHG0035495 - Workflow for credit check Hold on SO
  --                                     Hold population need to exclude hold with
  --                                     DOC_COD -> these holds will use other WF
  --                                     XX Document Approval
  --------------------------------------------------------------------
  PROCEDURE main_send_aggregate_mail(errbuf  OUT VARCHAR2,
                                     retcode OUT VARCHAR2) IS

    -- get holds population that need to send aggregate notification
    -- the mail will send aggregate by header, hold and approver
    CURSOR pop_c IS
      SELECT ooha.order_number,
             oh.header_id,
             ah.auto_hold_id,
             ah.hold_stage,
             ah.approver_sql,
             ah.fyi_cc_mail_sql,
             hd.hold_id,
             hd.name hold_name,
             oh.order_hold_id,
             oh.hold_source_id,
             oh.hold_release_id,
             oh.line_id,
             oh.org_id,
             oh.released_flag,
             hr.release_reason_code,
             hr.release_comment
        FROM oe_order_holds_all   oh,
             oe_hold_sources_all  hs,
             oe_hold_releases     hr,
             oe_hold_definitions  hd,
             xxom_auto_hold       ah,
             oe_order_headers_all ooha
       WHERE oh.hold_source_id = hs.hold_source_id
         AND hs.hold_id = hd.hold_id
         AND oh.hold_release_id = hr.hold_release_id(+)
         AND hs.org_id = oh.org_id
         AND hs.released_flag = 'N'
         AND hd.hold_id = ah.hold_id
         AND ah.aggregate_notifications = 'Y'
         AND oh.header_id = ooha.header_id
         AND ah.doc_code IS NULL -- 09/07/2015 Dalit A. Raviv CHG0035495
            --and    ooha.order_number    = ('1049789')--('251967') --('251973') --('251962')--,'251963');
            -- this case make sure that the wf will not send more then one time to the approver.
         AND NOT EXISTS
       (SELECT 1
                FROM wf_items workflowitemeo
               WHERE workflowitemeo.item_type = 'XXOMHLD'
                 AND workflowitemeo.item_key LIKE ooha.order_number || '%'
                 AND workflowitemeo.root_activity = 'AGG_APPROVAL'
                 AND workflowitemeo.end_date IS NULL);

    CURSOR agg_c(p_batch_id IN NUMBER) IS
      SELECT listagg(t.auto_hold_id, ',') within GROUP(ORDER BY t.auto_hold_id) auto_hold_ids,
             listagg(t.fyi_email_list, ';') within GROUP(ORDER BY t.auto_hold_id) fyi_email_list,
             so_order_number,
             approver,
             oh.header_id,
             oh.sold_to_org_id customer_id,
             oh.order_type_id,
             ot.name order_type,
             oh.cust_po_number,
             oh.org_id
        FROM xxobjt.xxom_auto_hold_temp t,
             oe_order_headers_all       oh,
             oe_transaction_types_tl    ot
       WHERE oh.header_id = t.so_header_id
         AND ot.language = 'US'
         AND ot.transaction_type_id = oh.order_type_id
         AND t.batch_id = p_batch_id
       GROUP BY so_order_number,
                approver,
                oh.header_id,
                oh.sold_to_org_id,
                oh.order_type_id,
                ot.name,
                oh.cust_po_number,
                oh.org_id
       ORDER BY approver, so_order_number;

    l_hold_approver  VARCHAR2(150);
    l_err_code       NUMBER := 0;
    l_err_msg        VARCHAR2(1000);
    l_batch_id       NUMBER;
    l_wf_item_key    VARCHAR2(240);
    l_count          NUMBER := 0;
    l_fyi_email_list VARCHAR2(2000);

  BEGIN
    -- Init Var
    errbuf  := NULL;
    retcode := 0;

    --1) locate population
    SELECT nvl(MAX(batch_id), 0) + 1
      INTO l_batch_id
      FROM xxom_auto_hold_temp;

    --fnd_file.put_line(fnd_file.log,'---- main_send_aggregate_mail ----');
    fnd_file.put_line(fnd_file.log, '---- l_batch_id ' || l_batch_id);
    --dbms_output.put_line('---- main_send_aggregate_mail ----');
    dbms_output.put_line('---- l_batch_id ' || l_batch_id);
    --2) enter records to temp table
    FOR pop_r IN pop_c LOOP
      BEGIN
        l_hold_approver := NULL;
        l_err_code      := 0;
        l_err_msg       := NULL;
        -- get hold Approver
        get_dynamic_sql(p_entity_id    => pop_r.header_id, -- i v
                        p_auto_hold_id => pop_r.auto_hold_id, -- i n
                        p_sql_text     => pop_r.approver_sql, -- i v
                        p_subject      => 'Hold Approver', -- i v
                        p_return       => l_hold_approver, -- o v
                        p_err_code     => l_err_code, -- o n
                        p_err_msg      => l_err_msg); -- o v

        l_err_code       := 0;
        l_err_msg        := NULL;
        l_fyi_email_list := NULL;
        -- get FYI email list
        get_dynamic_sql(p_entity_id    => pop_r.header_id, -- i v
                        p_auto_hold_id => pop_r.auto_hold_id, -- i n
                        p_sql_text     => pop_r.fyi_cc_mail_sql, -- i v
                        p_subject      => 'FYI Email List', -- i v
                        p_return       => l_fyi_email_list, -- o v
                        p_err_code     => l_err_code, -- o n
                        p_err_msg      => l_err_msg); -- o v

        INSERT INTO xxom_auto_hold_temp
          (so_header_id,
           so_line_id,
           so_order_number,
           org_id,
           hold_id,
           hold_name,
           auto_hold_id,
           order_hold_id,
           hold_source_id,
           hold_release_id,
           approver,
           fyi_email_list,
           send_mail,
           batch_id,
           last_update_date,
           last_updated_by,
           last_update_login,
           creation_date,
           created_by)
        VALUES
          (pop_r.header_id,
           NULL,
           pop_r.order_number,
           pop_r.org_id,
           pop_r.hold_id,
           pop_r.hold_name,
           pop_r.auto_hold_id,
           pop_r.order_hold_id,
           pop_r.hold_source_id,
           pop_r.hold_release_id,
           l_hold_approver,
           l_fyi_email_list,
           NULL,
           l_batch_id,
           SYSDATE,
           fnd_global.user_id,
           -1,
           SYSDATE,
           fnd_global.user_id);

      EXCEPTION
        WHEN OTHERS THEN
          errbuf  := 'Problem insert records to temp table' ||
                     substr(SQLERRM, 1, 240);
          retcode := 1;
          fnd_file.put_line(fnd_file.log,
                            'Problem insert records to temp table' ||
                            substr(SQLERRM, 1, 240));
          dbms_output.put_line('Problem insert records to temp table' ||
                               substr(SQLERRM, 1, 240));
      END;
    END LOOP;
    COMMIT;

    --3) on temp table get the mails to send (so_header, holds, approver)
    FOR agg_r IN agg_c(l_batch_id) LOOP
      --l_hold_ids := agg_r.hold_ids ;
      l_err_code    := 0;
      l_err_msg     := NULL;
      l_count       := l_count + 1;
      l_wf_item_key := agg_r.so_order_number || '-' || l_batch_id || '.' ||
                       l_count;

      fnd_file.put_line(fnd_file.log, 'wf_item_key: ' || l_wf_item_key);
      dbms_output.put_line('wf_item_key: ' || l_wf_item_key);

      agg_initiate_hold_process(errbuf             => l_err_msg, -- o v
                                retcode            => l_err_code, -- o n
                                p_auto_hold_ids    => agg_r.auto_hold_ids, -- i v
                                p_so_number        => agg_r.so_order_number, -- i n
                                p_so_header_id     => agg_r.header_id, -- i n
                                p_approver         => agg_r.approver, -- i v
                                p_customer_id      => agg_r.customer_id, -- i n
                                p_header_type_name => agg_r.order_type, -- i v
                                p_cust_po_number   => agg_r.cust_po_number, -- i v
                                p_org_id           => agg_r.org_id, -- i n
                                p_batch_id         => l_batch_id, -- i n
                                p_wf_item_key      => l_wf_item_key, -- i v
                                p_fyi_email_list   => agg_r.fyi_email_list); -- i v

      fnd_file.put_line(fnd_file.log,
                        'wf_item_key: ' || l_wf_item_key || ' Approver: ' ||
                        agg_r.approver || ' SO: ' || agg_r.so_order_number ||
                        ' Auto_hold_ids: ' || agg_r.auto_hold_ids);
      dbms_output.put_line('wf_item_key: ' || l_wf_item_key ||
                           ' Approver: ' || agg_r.approver || ' SO: ' ||
                           agg_r.so_order_number || ' Auto_hold_ids: ' ||
                           agg_r.auto_hold_ids);

      IF l_err_code <> 0 THEN
        fnd_file.put_line(fnd_file.log,
                          'Err - ' || substr(l_err_msg, 1, 240));
        dbms_output.put_line('Err - ' || substr(l_err_msg, 1, 240));
        retcode := 1;
      ELSE
        BEGIN
          DELETE xxom_auto_hold_temp aht
           WHERE aht.creation_date < SYSDATE - 90;
          --batch_id        = l_batch_id;

          COMMIT;
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
      END IF;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen Err main_send_aggregate_mail - ' ||
                 substr(SQLERRM, 1, 240);
      retcode := 1;
  END main_send_aggregate_mail;

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_hold_release_reason
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      13/07/2015
  --  Purpose :           get hold id and return the reason code
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   13/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  FUNCTION get_hold_release_reason(p_hold_id      IN NUMBER,
                                   p_auto_hold_id IN NUMBER) RETURN VARCHAR2 IS

    l_release_reason VARCHAR2(240);
  BEGIN
    SELECT release_reason_code release_reason
      INTO l_release_reason
      FROM xxom_auto_hold h
     WHERE hold_id = nvl(p_hold_id, hold_id)
       AND auto_hold_id = p_auto_hold_id;

    RETURN l_release_reason;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_hold_release_reason;

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               release_approval_holds
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      13/07/2015
  --  Purpose :
  --
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   13/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  PROCEDURE release_approval_holds(errbuf            OUT VARCHAR2,
                                   retcode           OUT VARCHAR2,
                                   p_doc_instance_id IN NUMBER) IS
    l_last_user_id NUMBER;
    l_so_header_id NUMBER;
    l_org_id       NUMBER;
    l_hold_id      NUMBER;
    l_auto_hold_id NUMBER;
    l_rel_reason   VARCHAR2(240);
    l_errbuf       VARCHAR2(2500);
    l_retcode      VARCHAR(100);
    l_prog_name    VARCHAR2(30) := 'release_approval_holds';
  BEGIN
    errbuf  := NULL;
    retcode := 0;

    -- get So information
    SELECT xwdi.n_attribute2,
           xwdi.n_attribute3,
           xwdi.n_attribute5,
           xwdi.attribute3
      INTO l_so_header_id, l_org_id, l_hold_id, l_auto_hold_id
      FROM xxobjt_wf_doc_instance xwdi
     WHERE xwdi.doc_instance_id = p_doc_instance_id;

    -- Get release reason. this is the reason code and not the meaning
    l_rel_reason := get_hold_release_reason(l_hold_id, l_auto_hold_id);
    -- Get last approver user id
    l_last_user_id := xxobjt_wf_doc_util.get_last_approver_user_id(p_doc_instance_id);

    release_hold(errbuf            => l_errbuf, -- o v
                 retcode           => l_retcode, -- o v
                 p_header_id       => l_so_header_id, -- i n
                 p_org_id          => l_org_id, -- i n
                 p_hold_id         => l_hold_id, -- i n
                 p_user_id         => l_last_user_id, -- i n
                 p_release_comment => NULL, -- i v
                 p_release_reson   => l_rel_reason); -- i v

    IF l_retcode <> 0 THEN
      errbuf  := 'ERR - Proc release_approval_holds: ' ||
                 substr(l_errbuf, 1, 900);
      retcode := 1;
      fnd_log.string(log_level => fnd_log.level_unexpected,
                     module    => c_debug_module || l_prog_name,
                     message   => 'XXOM_AUTO_HOLD_PKG.release_approval_holds: p_doc_instance_id: ' ||
                                  p_doc_instance_id || ' error: ' ||
                                  l_errbuf);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_log.string(log_level => fnd_log.level_unexpected,
                     module    => c_debug_module || l_prog_name,
                     message   => 'XXOM_AUTO_HOLD_PKG.release_approval_holds: p_doc_instance_id; ' ||
                                  p_doc_instance_id || ' Unexpected error: ' ||
                                  substr(SQLERRM, 1, 240));
      errbuf  := 'ERR - Proc release_approval_holds: ' ||
                 substr(SQLERRM, 1, 240);
      retcode := 1;
  END release_approval_holds;

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_approver
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      09/07/2015
  --  Purpose :           submit_wf
  --                      this procedure create wf instance and start the wf
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   09/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  PROCEDURE submit_wf(p_so_header_id      IN NUMBER,
                      p_org_id            IN NUMBER DEFAULT NULL,
                      p_so_created_by     IN NUMBER DEFAULT NULL,
                      p_invoice_to_org_id IN NUMBER DEFAULT NULL,
                      p_doc_code          IN VARCHAR2,
                      p_hold_id           IN NUMBER,
                      p_order_hold_id     IN NUMBER,
                      p_auto_hold_id      IN NUMBER,
                      p_hold_created_by   IN NUMBER,
                      x_err_code          OUT VARCHAR2,
                      x_err_msg           OUT VARCHAR2,
                      x_itemkey           OUT VARCHAR2) IS

    l_err_code NUMBER := 0;
    l_err_msg  VARCHAR2(1000) := NULL;
    --l_person_id           number          := fnd_global.employee_id;
    l_prog_name           VARCHAR2(30) := 'submit_wf';
    l_doc_instance_header xxobjt_wf_doc_instance%ROWTYPE;
    l_creator_person_id   NUMBER;

  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
    x_itemkey  := '';

    /*select employee_id
    into   l_creator_person_id
    from   fnd_user
    where  user_id  = p_so_created_by;*/

    SELECT employee_id
      INTO l_creator_person_id
      FROM fnd_user
     WHERE user_id = p_hold_created_by;

    -- debug
    fnd_log.string(log_level => fnd_log.level_event,
                   module    => c_debug_module || l_prog_name,
                   message   => 'p_so_header_id = ' || p_so_header_id);

    l_doc_instance_header.user_id             := fnd_global.user_id;
    l_doc_instance_header.resp_id             := fnd_global.resp_id;
    l_doc_instance_header.resp_appl_id        := fnd_global.resp_appl_id;
    l_doc_instance_header.requestor_person_id := l_creator_person_id;
    l_doc_instance_header.creator_person_id   := l_creator_person_id;

    l_doc_instance_header.n_attribute1 := p_order_hold_id;
    l_doc_instance_header.n_attribute2 := p_so_header_id;
    l_doc_instance_header.n_attribute3 := p_org_id;
    l_doc_instance_header.n_attribute4 := p_invoice_to_org_id;
    l_doc_instance_header.n_attribute5 := p_hold_id;
    l_doc_instance_header.attribute1   := p_so_created_by;
    l_doc_instance_header.attribute2   := p_doc_code; -- 'CREDIT_CHECK'
    l_doc_instance_header.attribute3   := p_auto_hold_id;
    l_doc_instance_header.attribute4   := p_hold_created_by;

    xxobjt_wf_doc_util.create_instance(p_err_code            => l_err_code,
                                       p_err_msg             => l_err_msg,
                                       p_doc_instance_header => l_doc_instance_header,
                                       p_doc_code            => p_doc_code); -- 'CREDIT_CHECK'

    IF l_err_code = 1 THEN
      x_err_code := 1;
      x_err_msg  := ('Error in create_instance: ' || l_err_msg);
    ELSE
      COMMIT;

      IF fnd_global.conc_request_id = -1 THEN
        dbms_output.put_line('Doc Instance Id - ' ||
                             l_doc_instance_header.doc_instance_id);
      ELSE
        fnd_file.put_line(fnd_file.log,
                          'Doc Instance Id - ' ||
                          l_doc_instance_header.doc_instance_id);
      END IF;

      xxobjt_wf_doc_util.initiate_approval_process(p_err_code        => l_err_code,
                                                   p_err_msg         => l_err_msg,
                                                   p_doc_instance_id => l_doc_instance_header.doc_instance_id,
                                                   p_wf_item_key     => x_itemkey);

      IF l_err_code = 1 THEN
        x_err_code := 1;
        x_err_msg  := ('Error in initiate_approval_process: ' || l_err_msg);
      ELSE
        x_err_msg := 'Approval was successfully submited for ' ||
                     xxobjt_wf_doc_util.get_doc_name(l_doc_instance_header.doc_id) ||
                     '. doc_instance_id = ' ||
                     l_doc_instance_header.doc_instance_id;
      END IF;
    END IF;

    fnd_log.string(log_level => fnd_log.level_unexpected,
                   module    => c_debug_module || l_prog_name,
                   message   => x_err_msg);

    --g_message := x_err_msg;

  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := ('XXOM_AUTO_HOLD_PKG.submit_wf: Unexpected error: ' ||
                    SQLERRM);
      --g_message  := x_err_msg;
      fnd_log.string(log_level => fnd_log.level_unexpected,
                     module    => c_debug_module || l_prog_name,
                     message   => x_err_msg);

  END submit_wf;

  --------------------------------------------------------------------
  --  name:            main_doc_approval_wf
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/07/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035495 - Workflow for credit check Hold on SO
  --                   this procedure will locate all SO that have hold -> Credit Check Failure
  --                   and send for approvals using WF - XX Document Approval
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/07/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE main_doc_approval_wf(errbuf         OUT VARCHAR2,
                                 retcode        OUT VARCHAR2,
                                 p_so_header_id IN NUMBER,
                                 p_date         IN VARCHAR2) IS
    CURSOR c_pop IS
    -- SO in Credit Check Failure holds that did not send for approval yet
      SELECT hd.name,
             hs.hold_release_id,
             oh.order_hold_id,
             oh.created_by hold_cretaed_by,
             ooha.order_number,
             ooha.header_id,
             ooha.org_id,
             ooha.created_by,
             ooha.invoice_to_org_id,
             hr.release_reason_code,
             hr.release_comment,
             ah.auto_hold_id,
             ah.hold_id,
             ah.hold_stage,
             ah.doc_code,
             hs.hold_comment
        FROM xxom_auto_hold       ah,
             oe_hold_definitions  hd,
             oe_hold_sources_all  hs,
             oe_order_holds_all   oh,
             oe_order_headers_all ooha,
             oe_hold_releases     hr
       WHERE active = 'Y'
         AND ah.hold_id = hd.hold_id
         AND ah.doc_code IS NOT NULL
         AND hs.hold_id = ah.hold_id
         AND hs.released_flag = 'N'
         AND hs.hold_entity_code = 'O'
         AND hs.hold_source_id = oh.hold_source_id
         AND hs.org_id = oh.org_id
         AND oh.header_id = ooha.header_id
         AND oh.org_id = ooha.org_id
         AND oh.hold_release_id = hr.hold_release_id(+)
         AND ooha.header_id = nvl(p_so_header_id, ooha.header_id) --in (283748,283859)--( 269335,1043274) 189876, 236479
         AND oh.creation_date >= fnd_date.canonical_to_date(p_date)
            -- this condition is in order to not send the same SO for approval twice
         AND NOT EXISTS
       (SELECT 1
                FROM xxobjt_wf_docs wd, xxobjt_wf_doc_instance wdi
               WHERE wd.doc_code = ah.doc_code
                 AND wdi.n_attribute1 = oh.order_hold_id
                 AND wdi.doc_status IN
                     ('APPROVED', 'IN_PROCESS', 'REJECTED'));
    --order by ah.hold_stage, ah.doc_code;

    l_err_code  VARCHAR2(100);
    l_err_msg   VARCHAR2(2500);
    l_itemkey   VARCHAR2(240);
    l_prog_name VARCHAR2(30) := 'main_doc_approval_wf';
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    FOR r_pop IN c_pop LOOP
      l_err_code := 0;
      l_err_msg  := NULL;
      l_itemkey  := NULL;
      submit_wf(p_so_header_id      => r_pop.header_id, -- i n
                p_org_id            => r_pop.org_id, -- i n
                p_so_created_by     => r_pop.created_by, -- i n
                p_invoice_to_org_id => r_pop.invoice_to_org_id, -- i n
                p_doc_code          => r_pop.doc_code, -- i v
                p_hold_id           => r_pop.hold_id, -- i n
                p_order_hold_id     => r_pop.order_hold_id, -- i n
                p_auto_hold_id      => r_pop.auto_hold_id, -- i n
                p_hold_created_by   => r_pop.hold_cretaed_by, -- i n
                x_err_code          => l_err_code, -- o v
                x_err_msg           => l_err_msg, -- o v
                x_itemkey           => l_itemkey); -- o v

      IF fnd_global.conc_request_id = -1 THEN
        dbms_output.put_line('Order Number - ' || r_pop.order_number ||
                             ' Item Key - ' || l_itemkey);
      ELSE
        fnd_file.put_line(fnd_file.log,
                          'Order Number - ' || r_pop.order_number ||
                          ' Item Key - ' || l_itemkey);
      END IF;

      IF nvl(l_err_code, 0) <> 0 THEN
        errbuf  := l_err_msg;
        retcode := l_err_code;
        fnd_log.string(log_level => fnd_log.level_unexpected,
                       module    => c_debug_module || l_prog_name,
                       message   => 'XXOM_AUTO_HOLD_PKG.main_doc_approval_wf: Unexpected error: ' ||
                                    substr(SQLERRM, 1, 240));
      END IF;
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'XXOM_AUTO_HOLD_PKG.main_doc_approval_wf: Unexpected error: ' ||
                 substr(SQLERRM, 1, 240);
      fnd_log.string(log_level => fnd_log.level_unexpected,
                     module    => c_debug_module || l_prog_name,
                     message   => 'XXOM_AUTO_HOLD_PKG.main_doc_approval_wf: Unexpected error: ' ||
                                  substr(SQLERRM, 1, 240));
  END main_doc_approval_wf;

  --------------------------------------------------------------------
  --  name:            get_manual_adj4order
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   7.2.16
  --------------------------------------------------------------------
  --  purpose :    used in chek_discount_condition and OAF order hold notification
  --
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  7.2.16        yuval tal         initial build CHG0033846
  --  1.1  02-Mar-2017    Lingaraj Sarangi  CHG0040214 - Modifying Discount Hold workflow
  --                                       get_manual_adj4order Procedure Modified to consider any Manual Modifier
  -- 1.2  9-Aug-2018   Lingaraj          CHG0043573 - Adjust Discount approval process to support CA order types
  --------------------------------------------------------------------

  FUNCTION get_manual_adj4order(p_header_id NUMBER) RETURN NUMBER IS
    l_amount NUMBER;
  BEGIN
    SELECT SUM(adjusted_amount)
      INTO l_amount
      FROM (SELECT (v.adjusted_amount * -1) adjusted_amount
              FROM oe_price_adjustments_v v
             WHERE v.adjustment_type_code = 'DIS'
                  --AND    v.adjustment_name = 'Manual Adjustment'--Modified on 2Mar2017 for CHG0040214
                  --AND    v.arithmetic_operator = '%'            --Commented on 2Mar2017 for CHG0040214
               AND v.line_id IS NULL
               AND v.header_id = p_header_id
               AND v.automatic_flag = 'N' --Added on 2Mar2017 for CHG0040214
            UNION ALL
            SELECT (v.adjusted_amount * -1) * oola.pricing_quantity
              FROM oe_price_adjustments_v v,
                   ont.oe_order_lines_all oola,
                   inv.mtl_system_items_b msi
             WHERE v.adjustment_type_code = 'DIS'
                  --AND    v.adjustment_name = 'Manual Adjustment'  --Commented on 2Mar2017 for CHG0040214
               AND oola.unit_list_price > 0
               AND nvl(oola.cancelled_flag, 'N') = 'N'
               AND msi.inventory_item_id = oola.inventory_item_id
               AND msi.organization_id =
                   xxinv_utils_pkg.get_master_organization_id
               AND msi.item_type NOT IN (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
                                         fnd_profile.value('XXAR_FREIGHT_AR_ITEM'),
                                         'RC',
                                         'COUPON')
               AND v.line_id = oola.line_id
               AND v.automatic_flag = 'N' --Added on 2Mar2017 for CHG0040214
               AND v.header_id = p_header_id);

    RETURN nvl(l_amount, 0);

  END;
  --------------------------------------------------------------------
  --  name:            get_manual_adj4order
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   7.2.16
  --------------------------------------------------------------------
  --  purpose :    used in chek_discount_condition and OAF order hold notification
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  7.2.16  yuval tal    initial build CHG0033846
  --------------------------------------------------------------------

  FUNCTION get_manual_adj4line(p_header_id NUMBER, p_line_id NUMBER)
    RETURN NUMBER IS
    l_amount  NUMBER;
    l_amount2 NUMBER;
    l_operand NUMBER;
  BEGIN
    BEGIN

      SELECT v.operand
        INTO l_operand

        FROM oe_price_adjustments_v v
       WHERE v.adjustment_type_code = 'DIS'
         AND v.adjustment_name = 'Manual Adjustment'
         AND v.arithmetic_operator = '%'
         AND v.header_id = p_header_id;

      dbms_output.put_line('l_operand=' || l_operand);
    EXCEPTION
      WHEN no_data_found THEN
        l_operand := 0;

    END;

    -- DISCOUNT ACCORRDING TO HEADER % DISCOUNT PCT
    SELECT (l_operand / 100) * oola.unit_list_price * oola.pricing_quantity
      INTO l_amount
      FROM ont.oe_order_lines_all oola, inv.mtl_system_items_b msi
     WHERE oola.unit_list_price > 0
       AND nvl(oola.cancelled_flag, 'N') = 'N'
       AND msi.inventory_item_id = oola.inventory_item_id
       AND msi.organization_id = xxinv_utils_pkg.get_master_organization_id
       AND msi.item_type NOT IN (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
                                 fnd_profile.value('XXAR_FREIGHT_AR_ITEM'),
                                 'RC',
                                 'COUPON')

       AND oola.line_id = p_line_id;

    -- DISCOUNT ACCORRDING TO LINE DISCOUNT

    SELECT SUM(nvl((v.adjusted_amount * -1) * oola.pricing_quantity, 0))
      INTO l_amount2
      FROM oe_price_adjustments_v v,
           ont.oe_order_lines_all oola,
           inv.mtl_system_items_b msi
     WHERE v.adjustment_type_code = 'DIS'
       AND v.adjustment_name = 'Manual Adjustment'
       AND oola.unit_list_price > 0
       AND nvl(oola.cancelled_flag, 'N') = 'N'
       AND msi.inventory_item_id = oola.inventory_item_id
       AND msi.organization_id = xxinv_utils_pkg.get_master_organization_id
       AND msi.item_type NOT IN (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
                                 fnd_profile.value('XXAR_FREIGHT_AR_ITEM'),
                                 'RC',
                                 'COUPON')
       AND v.line_id = oola.line_id
          -- AND    v.header_id IS NULL
       AND oola.line_id = p_line_id;

    RETURN nvl(l_amount, 0) + nvl(l_amount2, 0);

  END;

  --------------------------------------------------------------------
  --  name:            get_order_discount_pct
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   3.3.16
  --------------------------------------------------------------------
  --  purpose :    get pct discount
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  7.2.16      yuval tal         CHG0033846 called from check_discount_condition/ get_approver_and_fyi
  --  1.1  28.8.18     Yuval             CHG0043573 - Adjust Discount approval process to support CA order types
  --------------------------------------------------------------------

  PROCEDURE get_order_discount_pct(p_header_id           NUMBER,
                                   p_sum_adjusted_amount OUT NUMBER,
                                   p_total_order_amount  OUT NUMBER,
                                   p_discount            OUT NUMBER) IS

    /*l_sum_adjusted_amount NUMBER;
    l_total_order_amount  NUMBER;
    l_discount            NUMBER;*/
  BEGIN

    p_sum_adjusted_amount := get_manual_adj4order(p_header_id); -- CHG0033846 new logic in function

    p_total_order_amount := oe_totals_grp.get_order_total(p_header_id  => p_header_id,
                                                          p_line_id    => NULL,
                                                          p_total_type => 'LINES');

    IF nvl(p_sum_adjusted_amount, 0) = 0 OR -- yuval  modify <= to = 14.8.18
       p_total_order_amount + p_sum_adjusted_amount = 0 THEN

      p_discount := 0;
      RETURN;

    END IF;

    p_discount := round(100 *
                        (p_sum_adjusted_amount /
                        (p_sum_adjusted_amount + p_total_order_amount)),
                        2);

    -- RETURN l_discount;
  EXCEPTION
    WHEN OTHERS THEN
      p_discount := 0;

  END;

  --------------------------------------------------------------------
  --  name:            prepay_hold_release_conc
  --  create by:       yuval tal
  --  Revision:        1.0 CHG0041582
  --  creation date:   28.9.17
  --------------------------------------------------------------------
  --  purpose :        prepay_hold_release_conc
  --                   Release prepay Hold using API
  --                   There is a need to create a program that
  --                   will release prepayment hold automatically
  --                   once the customer paid the prepayment amount

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11/04/2013  yuval tal         CHG0041582 -Release prepay Hold using API
  --                                     send mail to order creator + profile XX: OM Org Auto Release Mail List/ XXOM_ORG_PREPAY_HOLD_RLS_MAIL_DIST
  --------------------------------------------------------------------
  PROCEDURE prepay_hold_release_conc(errbuf    OUT VARCHAR2,
                                     retcode   OUT VARCHAR2,
                                     p_hold_id NUMBER) IS

    CURSOR c_holds2check IS

      SELECT decode(u.end_date, NULL, u.user_name, 'SYSADMIN') user_name,

             oha.header_id,
             hd.hold_id,
             oha.org_id,
             oha.order_number

        FROM fnd_user             u,
             oe_order_headers_all oha,
             oe_order_holds_all   oh,
             oe_hold_sources_all  hs,
             oe_hold_releases     hr,

             oe_hold_definitions hd
       WHERE u.user_id = oha.created_by
         AND oh.hold_source_id = hs.hold_source_id
         AND hs.hold_id = hd.hold_id
         AND oh.hold_release_id = hr.hold_release_id(+)
         AND hs.org_id = oh.org_id
         AND hd.hold_id = p_hold_id
         AND hs.released_flag = 'N'
         AND oh.header_id = oha.header_id;
    --  AND    rownum < 2;

    l_errmsg                     VARCHAR2(500);
    l_retcode                    VARCHAR2(10);
    l_amount_due_remaining_found NUMBER;
    l_org_flag                   VARCHAR2(1);
    l_ar_count                   NUMBER;

    l_mail_err_code NUMBER;
    l_mail_err_msg  VARCHAR2(2000);
    -- search for holds

    CURSOR c_org IS
      SELECT organization_id FROM hr_operating_units;

    TYPE org_tab IS TABLE OF VARCHAR2(10) INDEX BY VARCHAR2(10);
    l_org_tab org_tab;
  BEGIN

    errbuf  := 'Compelted';
    retcode := 0;

    -- get hold _id

    --
    -- init org flags
    fnd_file.put_line(fnd_file.log, 'Init Org Flags');
    FOR j IN c_org LOOP
      l_org_flag := fnd_profile.value_specific(NAME => 'XXOM_ORG_PREPAY_HOLD_RLS',

                                               org_id => j.organization_id);

      l_org_tab(to_char(j.organization_id)) := l_org_flag;
      fnd_file.put_line(fnd_file.log,
                        'Org=' || j.organization_id || ' Value=' ||
                        l_org_tab(j.organization_id));
    END LOOP;

    --
    FOR i IN c_holds2check LOOP
      BEGIN
        fnd_file.put_line(fnd_file.log, '-----------------------');
        fnd_file.put_line(fnd_file.log,
                          'Check order no=' || i.order_number);
        -- check valid org
        IF l_org_tab(i.org_id) = 'Y' THEN
          -- check valid to release
          -- if at least 1 line not fulle payed then skip

          l_amount_due_remaining_found := 0;
          l_ar_count                   := 0;

          SELECT COUNT(*)
            INTO l_ar_count

            FROM ra_customer_trx_all       rth,
                 ra_customer_trx_lines_all rtl,
                 mtl_system_items_b        msi,
                 ar_payment_schedules_all  aps

           WHERE to_char(i.order_number) = rth.interface_header_attribute1
             AND rtl.line_type = 'LINE'
             AND nvl(rtl.interface_line_context, 'ORDER ENTRY') =
                 'ORDER ENTRY'
             AND rtl.customer_trx_id = rth.customer_trx_id
             AND rtl.inventory_item_id = msi.inventory_item_id
             AND msi.item_type =
                 fnd_profile.value('XXAR PREPAYMENT ITEM TYPES')
             AND msi.organization_id =
                 xxinv_utils_pkg.get_master_organization_id
             AND aps.customer_trx_id = rth.customer_trx_id
             AND aps.amount_due_remaining = 0;

          IF l_ar_count = 0 THEN
            fnd_file.put_line(fnd_file.log,
                              'Order not valid to be release');

            CONTINUE;
          END IF;

          -- release
          fnd_file.put_line(fnd_file.log,
                            'Release order no=' || i.order_number);
          xxom_auto_hold_pkg.release_hold(errbuf            => l_errmsg,
                                          retcode           => l_retcode,
                                          p_header_id       => i.header_id,
                                          p_org_id          => i.org_id,
                                          p_hold_id         => i.hold_id,
                                          p_user_id         => fnd_global.user_id,
                                          p_release_comment => 'Automatic released process request id=' ||
                                                               fnd_global.conc_request_id,
                                          p_release_reson   => 'PREPAYMENT');

          -- dbms_output.put_line('Return Code  :' || l_retcode);
          -- dbms_output.put_line('Return Error   :' || l_errmsg);

          IF l_retcode = 0 THEN
            COMMIT;
            fnd_file.put_line(fnd_file.log, 'Hold Released Successfully.');

            --mail
            fnd_file.put_line(fnd_file.log,
                              'Sending mail to user:' || i.user_name ||
                              ' cc:' ||
                              fnd_profile.value_specific(NAME => 'XXOM_ORG_PREPAY_HOLD_RLS_MAIL_DIST',

                                                         org_id => i.org_id));

            --
            -- send mail
            xxobjt_wf_mail.send_mail_text(p_to_role     => i.user_name,
                                          p_cc_mail     => fnd_profile.value_specific(NAME => 'XXOM_ORG_PREPAY_HOLD_RLS_MAIL_DIST',

                                                                                      org_id => i.org_id),
                                          p_subject     => 'Prepayment hold was released - SO# ' ||
                                                           i.order_number,
                                          p_body_text   => 'Hello' ||
                                                           chr(10) ||

                                                           'Please be advised that Prepayment hold was released for SO# ' ||
                                                           i.order_number ||
                                                           chr(10) ||
                                                           'Oracle Admin',
                                          p_err_code    => l_mail_err_code,
                                          p_err_message => l_mail_err_msg);

            IF l_mail_err_code != 0 THEN
              fnd_file.put_line(fnd_file.log,
                                'Mail failed :' || l_mail_err_msg);
            END IF;

            --
          ELSIF l_retcode = 1 THEN
            -- log maessage
            retcode := 2;
            fnd_file.put_line(fnd_file.log, 'Release failed :' || l_errmsg);
            ROLLBACK;
          END IF;

        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,
                            'Faild in processing order' || i.order_number ||
                            substr(SQLERRM, 1, 100));
          retcode := 2;
          errbuf  := 'xxom_auto_hold_pkg.prepay_hold_release_conc : Faild in processing order' ||
                     i.order_number;
      END;
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Error in xxom_auto_hold_pkg.prepay_hold_release_conc:' ||
                 SQLERRM;
      retcode := 2;

  END;

END xxom_auto_hold_pkg;
/
