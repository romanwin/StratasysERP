create or replace package body xxpo_utils_pkg IS
  --------------------------------------------------------------------
  --  name:            XXPO_UTILS_PKG
  --  create by:       XXX
  --  Revision:        1.10
  --  creation date:   31/08/2009
  --------------------------------------------------------------------
  --  purpose :        Generic package for PO
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  31/08/2009  XXX             initial build
  --  1.1  02.12.2010  yuval tal       add get_blanket_total
  --                                   change get_last_po_price
  --                                   get_last_po_entity
  --  1.2  26/12/2010  Eran Baram      add trunc at get_acceptance procedure
  --  1.3  29/4/2012   yuval tal       modify highlight_record_check : cr409
  --  1.4  04.11.12    yuval tal       add get_first_approve_date
  --  1.5  16.12.12    yuval tal       cr624:add is_quotation_exists , is_po_exists
  --  1.6  21.01.13    yuval tal       cr657 : get_default_buyer : Get Pre Buyer per Category Amount level
  --  1.7  13.03.13    yuval tal       CR-643-Shipping backlog - Add additional columns for tracing Inter SO add get_item_schedule_group_name
  --                                   get_last_po_entity : support entity promised_date
  --  1.8  22/05/2013  Dalit A. Raviv  pocedure do_linkage -> CR776 - Problem with PO linkage Receipt Match after upgrade 12.1.3
  --                                   need to add column release_num
  --  1.9  10.6.13     yuval tal       add get_last_linkage_creation
  --  1.10 12/06/2013  Dalit A. Raviv  pocedure do_linkage -> CR827 need to add column po_header_id
  --  1.11 19.06.13    yuval tal       bugfix 831:Last PO price  Currency- at notification
  --                                   get_formatted_amount add paramter  p_release_num
  --  1.12 05-SEP-2014 Sandeep Akula   Added Functions get_matching_type,get_project_number,get_task_number,get_expenditure_org (CHG0031574)
  --  1.13 16/12/2014  Dalit A. Raviv  add function get_sourcing_rule
  --  1.14 16/03/2015  Dalit A. RAviv  CHG0034192 - add function get_vs_email
  --  1.15  9.12.15     yuval tal       CHG0037199 change  Vendor Scheduler at Site level  modify get_vs_email,get_vs_name
  --                                    add new function get_vs_person_id
  --  1.16 25.08.2016  L.Sarangi       CHG0038985 - Add item cost to Blanket/ standard PO approval notification
  --                                   Added a new function & Procedure <get_item_costForPO> to show the item cost in the PO Approval Notification
  --  1.17 10/03/2017  N.Kumar         UOM Conversion logic
  --                                   CHG0040109 - Std. Material Cost in notification should be converted to PO Line UOM amount using UOM conversion
  -- 1.18 12.6.17      yuval tal       CHG0040374 - modify  get_last_po_price add  parameter p_ou_id
  -- 1.19 03-Jul-2018  dan melamed     CHG0043185 - Implement price tolarance checks for P.O vs P.R Approval.
  --                                   CHG0043332 - Eliminate the option to place P.O Without P.R
  -- 2.0  05-Nov-2018  Lingaraj        CHG0043863-CTASK0038483-New Logic for Default Buyer
  ------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_conv_rate;
  --  create by:       Dan Melamed
  --  Revision:        1.0
  --  creation date:   03-Jul-2018
  --------------------------------------------------------------------
  --  purpose :        Get conversion rate against (to) USD
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  03-Jul-2018 dan melamed     CHG0043185 - PR-PO price tolerance
  --------------------------------------------------------------------

g_conversion_Rate_missing number := 0;

function get_conv_rate(p_rate_date date, p_backup_date date, p_from_currency varchar2) return number
  is

 v_return_Rate number;

begin

 begin

   v_return_Rate := gl_currency_api.get_closest_rate(x_from_currency   => p_from_currency,
                                                     x_to_currency     => 'USD',
                                                     x_conversion_date =>  p_rate_date,
                                                     x_conversion_type => 'Corporate',
                                                     x_max_roll_days   => 0);
 exception
    when others then
         begin
           v_return_Rate := gl_currency_api.get_closest_rate(x_from_currency   => p_from_currency,
                                                             x_to_currency     => 'USD',
                                                             x_conversion_date =>  p_backup_date,
                                                             x_conversion_type => 'Corporate',
                                                             x_max_roll_days   => 0);
         exception
              when others then
                g_conversion_Rate_missing := 1;
         end;


  end;

 return v_return_Rate;

end get_conv_rate;

  --------------------------------------------------------------------
  --  name:            Validate_PO_PR_Price_Tolerance
  --  create by:       Dan Melamed
  --  Revision:        1.0
  --  creation date:   03-Jul-2018
  --------------------------------------------------------------------
  --  purpose :        Check if a line in the PO is more than the set (in proile) tolerance than PR
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  03-Jul-2018 dan melamed     CHG0043185 - PR-PO price tolerance
  --------------------------------------------------------------------


function validate_po_pr_price_tolerance(p_document_id varchar2)
    return boolean is

  -- Cursor for all PO Lines
 cursor c_expense_po_Lines is
        select
            (case when nvl(poh.currency_code, sob.currency_code) = 'USD'
                  then
                  (pol.unit_price) * pol.quantity
                   else
                  (pol.unit_price * pol.quantity) *   get_conv_rate(poh.rate_date,poh.creation_date,  nvl(poh.currency_code, sob.currency_code))
             end
            ) po_line_amount,
            pol.po_line_id,
            pol.line_num po_line_num,
            trunc(poh.creation_date) po_creation_date
        from po_lines_all pol,
             po_headers_all poh,
             gl_sets_of_books             sob,
             financials_system_params_all fsp
       where poh.po_header_id = p_document_id
         and poh.po_header_id = pol.po_header_id
         and sob.set_of_books_id = fsp.set_of_books_id
         and fsp.org_id = pol.org_id
         and nvl(pol.cancel_flag,'N') = 'N'
         and exists (select '1' from  po_distributions_all pod where pod.po_line_id = pol.po_line_id and pod.destination_type_code = 'EXPENSE');


    l_tol_amt number := fnd_profile.value('XXPO_APPROVAL_TOLERANCE_AMOUNT');
    l_tol_per number := fnd_profile.value('XXPO_APPROVAL_TOLERANCE_PERCENTAGE');
    l_return_val boolean;
    l_PR_LINE_Amount number;
    l_pr_number varchar2(255);
    l_pr_lines varchar2(255);
    l_po_line_id number;
    l_po_creation_date date;
    l_step number;
  begin
    g_conversion_Rate_missing := 0;
    l_return_val  := true;
    l_step  := 0;

    -- For all PO Lines in a single PO Header

    for rec in c_expense_po_Lines loop

      if g_conversion_Rate_missing = 1 then
        fnd_message.set_name('XXOBJT', 'XXPO_SUBMIT_PR_PO_TOL_FAIL');
        fnd_message.set_token('ERR_TEXT', 'PO Conversion Rate Missing' );
        fnd_message.set_token('PLSQL_ERR', ' ');
        fnd_msg_pub.add_detail;
        l_return_val := false;
        return l_return_val;
      end if;

       l_step  := 1;

    -- Get sum of the PR lines connected to the currently scanned PO Line.
     begin
      select
        sum
        (
        (case when nvl(prl.currency_code, sob.currency_code) = 'USD' then
                          (nvl(prl.currency_unit_price, prl.unit_price) * prl.quantity)
                          else
                             (nvl(prl.currency_unit_price, prl.unit_price) * prl.quantity) *
                                get_conv_rate(pod.rate_date,rec.po_creation_date,  nvl(prl.currency_code, sob.currency_code))

                        end
          )
        ) pr_line_sum_for_po,
        prh.segment1
        into l_pr_line_amount,
             l_pr_number
       from po_lines_all                 pol,
            po_requisition_lines_all     prl,
            po_distributions_all         pod,
            po_req_distributions_all     prd,
            gl_sets_of_books             sob,
            financials_system_params_all fsp,
            po_requisition_headers_all prh
      where pol.po_line_id = rec.po_line_id
        and pol.po_line_id = pod.po_line_id
        and pod.req_distribution_id = prd.distribution_id
        and prl.requisition_line_id = prd.requisition_line_id
        and sob.set_of_books_id = fsp.set_of_books_id
        and fsp.org_id = prl.org_id
        and prh.requisition_header_id = prl.requisition_header_id
      group by prh.segment1;

      exception
        when others then

          fnd_message.set_name('XXOBJT', 'XXPO_SUBMIT_PR_PO_TOL_FAIL');
          fnd_message.set_token('ERR_TEXT', 'No PR Lines found for PO for Tolerance comparison check');
          fnd_message.set_token('PLSQL_ERR', ' ');

         fnd_msg_pub.add_detail; -- add detailed error
         l_return_val  := false;
         return l_return_val;

      end;

     if g_conversion_Rate_missing = 1 then
        fnd_message.set_name('XXOBJT', 'XXPO_SUBMIT_PR_PO_TOL_FAIL');
        fnd_message.set_token('ERR_TEXT', 'PR Conversion Rate Missing' );
        fnd_message.set_token('PLSQL_ERR', ' ');
        fnd_msg_pub.add_detail;

        l_return_val := false;

        return l_return_val;
      end if;

     l_step  :=2;

     -- get PR Lines consisting of this PO Line being scanned

      begin
        select
            ListAgg(prl.line_num, ',')
            WITHIN GROUP (ORDER BY prl.line_num)
         into l_pr_lines
         from po_lines_all                 pol,
                po_requisition_lines_all     prl,
                po_distributions_all         pod,
                po_req_distributions_all     prd,
                GL_SETS_OF_BOOKS             SOB,
                FINANCIALS_SYSTEM_PARAMS_ALL FSP,
                po_requisition_headers_all prh
          where pol.po_line_id = rec.PO_LINE_ID
            and pol.po_line_id = pod.po_line_id
            and pod.req_distribution_id = prd.distribution_id
            and prl.requisition_line_id = prd.requisition_line_id
            AND SOB.SET_OF_BOOKS_ID = FSP.SET_OF_BOOKS_ID
            AND FSP.ORG_ID = prl.ORG_ID
            and prh.requisition_header_id = prl.requisition_header_id ;
      exception
         when no_data_found then
            l_pr_lines:= null;
      end;

      l_step  := 3;

      if rec.po_line_amount >= round((l_PR_LINE_Amount + (l_PR_LINE_Amount * (l_tol_per / 100))), 2)
         or (rec.po_line_amount - l_PR_LINE_Amount) >= l_tol_amt
         or (l_PR_LINE_Amount = 0 and rec.po_line_amount > 0) -- req line amount is 0, percentage can not be calculated on it
       then
        fnd_message.set_name('XXOBJT', 'XXPO_SUBMIT_PR_PO_TOL_ERR');
        fnd_message.set_token('PERCENTAGE', l_tol_per || '%');
        fnd_message.set_token('AMOUNT', l_tol_amt);
        fnd_message.set_token('POLINENUM', rec.po_line_num);
        fnd_message.set_token('REQNUM', l_pr_number);
       fnd_message.set_token('REQLINENUM', l_pr_lines);
        fnd_msg_pub.add_detail; -- add detailed error
        l_return_val  := false;
      end if;
    end loop;

    return l_return_val;
exception
     when others then

        fnd_message.set_name('XXOBJT', 'XXPO_SUBMIT_PR_PO_TOL_FAIL');
        fnd_message.set_token('ERR_TEXT', 'Error in step ' || l_step );
        fnd_message.set_token('PLSQL_ERR', sqlerrm);


        fnd_msg_pub.add_detail; -- add detailed error
        l_return_val  := false;

  end validate_po_pr_price_tolerance;

  --------------------------------------------------------------------
  --  name:            validate_is_pr_based
  --  create by:       dan melamed
  --  revision:        1.0
  --  creation date:   03-jul-2018
  --------------------------------------------------------------------
  --  purpose :        validate if po is pr based
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  03-jul-2018 dan melamed     CHG0043332 - pr-po price tolerance
  --------------------------------------------------------------------

  function validate_is_pr_based(p_document_id varchar2) return boolean is
    l_validate varchar2(255);
    l_return_val boolean;
  begin



      select count(1)
        into l_validate
        from po_headers_all poh, po_lines_all pol, po_distributions_all pod
       where 1 = 1
         and poh.po_header_id = p_document_id
         and pol.po_header_id = poh.po_header_id
         and pod.po_line_id = pol.po_line_id
         and pod.po_header_id = poh.po_header_id
         and pod.req_distribution_id is null;

    if l_validate > 0 then
        fnd_message.set_name('XXOBJT', 'XXPO_SUBMIT_PR_MISSING_ERR');
        fnd_msg_pub.add_detail; -- add  error
        l_return_val := false;
    else
        l_return_val := true;
    end if;

    return l_return_val;

  end validate_is_pr_based;

  --------------------------------------------------------------------
  --  name:            do_pre_submission_check
  --  create by:       dan melamed
  --  revision:        1.0
  --  creation date:   03-jul-2018
  --------------------------------------------------------------------
  --  purpose :        validation called by the hook in po_custom_submission_check_pvt
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  03-jul-2018 dan melamed     chg0043185 - pr-po price tolerance
  --------------------------------------------------------------------

  procedure do_pre_submission_check(p_api_version       in number,
                                    p_document_id       in number,
                                    p_action_requested  in varchar2,
                                    p_document_type     in varchar2,
                                    p_document_subtype  in varchar2,
                                    p_document_level    in varchar2,
                                    p_document_level_id in number,
                                    p_requested_changes in po_changes_rec_type,
                                    p_check_asl         in boolean,
                                    p_req_chg_initiator in varchar2,
                                    p_origin_doc_id     in number,
                                    p_online_report_id  in number,
                                    p_user_id           in number,
                                    p_login_id          in number,
                                    p_sequence          in out nocopy number,
                                    x_return_status     out nocopy varchar2) is

    l_api_name    constant varchar2(50) := 'do_pre_submission_check';
    l_api_version constant number := 1.0;
    d_position          number := 0;
    l_pass_validation   boolean := true;
    l_profile_val_value varchar2(255);
    l_profile_defined   boolean;
    l_po_org            number;
  begin

    fnd_msg_pub.initialize;

    if p_document_type = 'PO' and p_document_subtype = 'STANDARD' and
       p_document_level = 'HEADER' then

      -- get org id

      select poh.org_id
        into l_po_org
        from po_headers_all poh
       where poh.po_header_id = p_document_id;

     -- check profile if the pr required for po in this org.

      fnd_profile.get_specific(name_z    => 'XXPO_APPROVAL_PR_REQUIRED_ORG',
                               val_z     => l_profile_val_value,
                               defined_z => l_profile_defined,
                               org_id_z  => l_po_org);

      l_profile_val_value := nvl(l_profile_val_value, 'Y'); -- the default is pr required

      -- if profile set to y, check po based on pr.
      if l_profile_val_value = 'Y' then

        l_pass_validation := validate_is_pr_based(p_document_id);
        if l_pass_validation = false then
          x_return_status := fnd_api.g_ret_sts_unexp_error;
          return;
        end if;
      end if;


     -- check profile if the approval tolerance is set for this org

      fnd_profile.get_specific(name_z    => 'XXPO_APPROVAL_TOLERANCE_ORGANIZATION',
                               val_z     => l_profile_val_value,
                               defined_z => l_profile_defined,
                               org_id_z  => l_po_org);

      l_profile_val_value := nvl(l_profile_val_value, 'N');

      -- if profile set to y, check po/pr tolerance validation
      if l_profile_val_value = 'Y' then

        l_pass_validation := validate_po_pr_price_tolerance(p_document_id);
        if l_pass_validation = false then
          x_return_status := fnd_api.g_ret_sts_unexp_error;
          return;
        end if;

      end if;


    end if;

    x_return_status := fnd_api.g_ret_sts_success;
    d_position      := 100;

  exception
    when others then
      x_return_status := fnd_api.g_ret_sts_unexp_error;

  end do_pre_submission_check;

  FUNCTION get_po_win_title(p_po_num VARCHAR2) RETURN VARCHAR2 AS

    v_func_amt NUMBER;
    v_title    VARCHAR2(150);

  BEGIN

    BEGIN
      SELECT SUM(pl.unit_price * pl.quantity * ph.rate)
        INTO v_func_amt
        FROM po_headers_all ph, po_lines_all pl
       WHERE ph.po_header_id = pl.po_header_id
         AND ph.segment1 = p_po_num;
    EXCEPTION
      WHEN OTHERS THEN
        v_title := 'Purchase Order Summary to Purchase Orders - ' ||
                   p_po_num;
        RETURN v_title;
    END;

    v_title := 'Purchase Order Summary to Purchase Orders (PO: ' ||
               p_po_num || ') Func Amount: ' ||
               to_char(to_number(v_func_amt, '999,999.99'));
    RETURN v_title;
  EXCEPTION
    WHEN OTHERS THEN
      v_title := 'Purchase Order Summary to Purchase Orders (PO: ' ||
                 p_po_num || ')';
      RETURN v_title;

  END get_po_win_title;

  ------------------------------------------------------------------------------------------------
  FUNCTION get_linkage_rate(p_po_num VARCHAR2) RETURN NUMBER AS

    v_base_rate NUMBER;
    --v_error_message VARCHAR2(150);

  BEGIN

    SELECT base_rate
      INTO v_base_rate
      FROM clef062_po_index_esc_set
     WHERE module = 'PO'
       AND document_id = p_po_num;

    RETURN v_base_rate;

  EXCEPTION
    WHEN OTHERS THEN
      v_base_rate := NULL;
      RETURN v_base_rate;
  END get_linkage_rate;
  ---------------------------------------
  FUNCTION get_linkage_date(p_po_num VARCHAR2) RETURN DATE AS

    v_base_date DATE;
    --v_error_message VARCHAR2(150);

  BEGIN

    SELECT ff.base_date
      INTO v_base_date
      FROM clef062_po_index_esc_set ff
     WHERE module = 'PO'
       AND document_id = p_po_num;

    RETURN v_base_date;

  EXCEPTION
    WHEN OTHERS THEN
      v_base_date := NULL;
      RETURN v_base_date;
  END get_linkage_date;
  ------------------------------------------------------------------------------------------------

  FUNCTION get_linkage_amount(p_po_num VARCHAR2, p_amount NUMBER)
    RETURN NUMBER AS

    l_get_linkage_rate NUMBER;

  BEGIN

    IF p_amount IS NULL THEN

      RETURN NULL;

    ELSE

      l_get_linkage_rate := xxpo_utils_pkg.get_linkage_rate(p_po_num);

      IF nvl(l_get_linkage_rate, 0) = 0 THEN

        RETURN NULL;

      ELSE

        RETURN(p_amount / l_get_linkage_rate);

      END IF;

    END IF;

  END get_linkage_amount;
  -----------------------------------------
  PROCEDURE get_po_type_num_curr(p_po_header_id po_headers_all.po_header_id%TYPE,
                                 p_type         OUT po_headers_all.type_lookup_code%TYPE,
                                 p_curr         OUT po_headers_all.currency_code%TYPE,
                                 p_num          OUT po_headers_all.segment1%TYPE,
                                 p_date         OUT po_headers_all.rate_date%TYPE) IS
    l_type po_headers_all.type_lookup_code%TYPE;
    l_curr po_headers_all.currency_code%TYPE;
    l_num  po_headers_all.segment1%TYPE;
    l_date po_headers_all.rate_date%TYPE;
  BEGIN
    SELECT pp.type_lookup_code, pp.currency_code, pp.segment1, pp.rate_date
      INTO l_type, l_curr, l_num, l_date
      FROM po_headers_all pp
     WHERE pp.po_header_id = p_po_header_id;

    p_type := l_type;
    p_curr := l_curr;
    p_num  := l_num;
    p_date := l_date;
  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        p_type := NULL;
        p_curr := NULL;
        p_num  := NULL;
        p_date := NULL;
      END;
  END;
  ------------------------------------------
  PROCEDURE should_do_linkage(p_req_distribution_id po_distributions_all.req_distribution_id%TYPE,
                              p_curr_return         OUT po_headers_all.currency_code%TYPE,
                              p_date_return         OUT DATE) IS
    l_curr_return       po_headers_all.currency_code%TYPE;
    l_date_return       DATE;
    l_encumbered_amount po_distributions_all.encumbered_amount%TYPE;
  BEGIN

    SELECT DISTINCT nvl(porl.currency_code, sob.currency_code),
                    porl.rate_date,
                    porl.unit_price * porl.quantity
      INTO l_curr_return, l_date_return, l_encumbered_amount
      FROM po_req_distributions_all     pord,
           po_requisition_lines_all     porl,
           gl_sets_of_books             sob,
           financials_system_params_all fsp
     WHERE p_req_distribution_id = pord.distribution_id
       AND pord.requisition_line_id = porl.requisition_line_id
       AND fsp.org_id = pord.org_id
       AND
          --  (porl.document_type_code = 'QUOTATION' OR porl.item_id IS NULL) AND
           (porl.document_type_code = 'QUOTATION' OR
           porl.destination_type_code = 'EXPENSE')
       AND sob.set_of_books_id = fsp.set_of_books_id
       AND porl.rate IS NOT NULL;

    p_curr_return := l_curr_return;
    p_date_return := l_date_return;

    -- p_encumbered_amount := l_encumbered_amount;

  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        p_curr_return := NULL;
        p_date_return := NULL;
        --p_encumbered_amount := null;
      END;
  END;

  /*procedure should_do_linkage_Q(p_po_line_id po_lines_all.po_line_id%type
                              ,p_curr_return out po_headers_all.currency_code%type
                              ,p_date_return out date)   is
  l_curr_return po_headers_all.currency_code%type;
  l_date_return date;
     */

  --------------------------------------------------------------------
  -- get_last_linkage_creation
  --------------------------------------------------------------------
  --  name:            get_last_linkage_creation
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   10.6.13
  --------------------------------------------------------------------
  --  purpose : cust 004 - BUGFIX 821- PO lines are tripled in the PO notification due to  change behavier in in PO linkage
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  10.6.13     yuval tal       to be use by linkage select (support oracle bug)linakge

  --------------------------------------------------------------------
  FUNCTION get_last_linkage_creation(p_po_number      VARCHAR2,
                                     p_release_number NUMBER) RETURN DATE IS
    l_tmp DATE;
  BEGIN

    SELECT creation_date
      INTO l_tmp
      FROM (SELECT tt.creation_date

              FROM clef062_po_index_esc_set tt
             WHERE module = 'PO'
               AND document_id = p_po_number
               AND nvl(tt.release_num, 0) = p_release_number
             ORDER BY tt.creation_date DESC)
     WHERE rownum = 1;
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            do_linkage
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2010  XXX             initial build
  --  1.1  22/05/2013  Dalit A. Raviv  CR776 - Problem with PO linkage Receipt Match after upgrade 12.1.3
  --                                   need to add column release_num
  --  1.2  12/06/2013  Dalit A. Raviv  add po_header_id to insert
  --------------------------------------------------------------------
  PROCEDURE do_linkage(p_po_num        po_headers_all.segment1%TYPE,
                       p_po_line_id    po_lines_all.po_line_id%TYPE,
                       p_from_currency po_headers_all.currency_code%TYPE, -- USD
                       p_to_currency   po_headers_all.currency_code%TYPE, -- ILS
                       p_base_date     DATE) IS

    l_rate       gl_daily_rates.conversion_rate%TYPE;
    l_convr_type VARCHAR2(100) := fnd_profile.value('XXPO_CURR_CONVERSION_TYPE');
    l_curr_desc  fnd_currencies_tl.description%TYPE;
    l_num        NUMBER;
    l_link_to    VARCHAR2(250) := fnd_profile.value('CLEF062_DEFAULT_CONVERSION_RATE_DATE');
    --l_po_header_id NUMBER := NULL;
  BEGIN

    --
    -- Get the rate from daily rates
    --
    BEGIN
      l_rate := gl_currency_api.get_rate(x_from_currency   => p_from_currency,
                                         x_to_currency     => p_to_currency,
                                         x_conversion_date => p_base_date,
                                         x_conversion_type => l_convr_type);
    EXCEPTION
      WHEN no_data_found THEN
        BEGIN
          l_rate := gl_currency_api.get_rate(x_from_currency   => p_to_currency,
                                             x_to_currency     => p_from_currency,
                                             x_conversion_date => p_base_date,
                                             x_conversion_type => l_convr_type);
          l_rate := 1 / l_rate;
        EXCEPTION
          WHEN no_data_found THEN
            l_rate := gl_currency_api.get_closest_rate(x_from_currency   => p_from_currency,
                                                       x_to_currency     => p_to_currency,
                                                       x_conversion_date => p_base_date,
                                                       x_conversion_type => l_convr_type,
                                                       x_max_roll_days   => 100);

        END;
    END;

    --
    -- Get currency description
    --
    BEGIN
      SELECT cc.description
        INTO l_curr_desc
        FROM fnd_currencies_vl cc
       WHERE cc.currency_code = p_from_currency;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;

    --
    -- check if no linkage
    --
    BEGIN
      SELECT 1
        INTO l_num
        FROM clef062_po_index_esc_set cc
       WHERE cc.module = 'PO'
         AND cc.document_id = p_po_num
         AND rownum = 1;
    EXCEPTION
      WHEN OTHERS THEN
        /*-- Dalit A. Raviv 13/06/2013
        BEGIN
          SELECT poh.po_header_id
            INTO l_po_header_id
            FROM po_headers_all poh
           WHERE poh.segment1 = p_po_num;
        EXCEPTION
          WHEN OTHERS THEN
            l_po_header_id := NULL;
        END;*/
        --
        -- insert into linkage table
        --
        -- Dalit A. Raviv 22/05/2013
        -- CR776 - Problem with PO linkage Receipt Match after upgrade 12.1.3
        -- need to add column release_num
        INSERT INTO clef062_po_index_esc_set
          (module,
           document_id,
           currency_code,
           conversion_type,
           linkage_to,
           base_rate,
           base_date,
           description,
           last_updated_by,
           last_update_date,
           created_by,
           creation_date,
           last_update_login,
           currency_name,
           rate_limit,
           release_num /*,
                                                                                                                                                                                                                                                                        po_header_id*/)
        VALUES
          ('PO',
           p_po_num,
           p_from_currency,
           l_convr_type,
           decode(l_link_to, 'Invoice Date', 2, 1),
           substr(to_char(l_rate), 1, 20),
           p_base_date,
           'Auto index for PO',
           fnd_global.user_id,
           SYSDATE,
           fnd_global.user_id,
           SYSDATE,
           fnd_global.login_id,
           substr(l_curr_desc, 1, 20),
           NULL,
           0 /*,
                                                                                                                                                                                                                                                                        l_po_header_id*/);

    END;

    --
    -- Update amount in original currency  - DFF
    --
    UPDATE po_lines_all ll
       SET ll.attribute3 = to_char(round(ll.unit_price * (1 / l_rate), 4)) || ' ' ||
                           p_from_currency
     WHERE ll.po_line_id = p_po_line_id;

    /*  exception
    when others then null;  */
  END;

  PROCEDURE get_linkage(p_po_num VARCHAR2,
                        p_rate   OUT NUMBER,
                        p_curr   OUT po_headers_all.currency_code%TYPE,
                        p_level  VARCHAR2 DEFAULT 'LINES') IS

    v_base_rate NUMBER;
    v_curr_code VARCHAR2(50);
  BEGIN

    SELECT base_rate, currency_code
      INTO v_base_rate, v_curr_code
      FROM clef062_po_index_esc_set
     WHERE module = 'PO'
       AND document_id = p_po_num
       AND rownum < 2;

    IF p_level = 'HEADER' THEN

      BEGIN

        SELECT DISTINCT qh.currency_code
          INTO v_curr_code
          FROM po_headers_all ph, po_lines_all pl, po_headers_all qh
         WHERE ph.po_header_id = pl.po_header_id
           AND pl.from_header_id = qh.po_header_id
           AND ph.segment1 = p_po_num;

        -- END IF;

      EXCEPTION
        WHEN too_many_rows THEN
          p_curr := NULL;
          p_rate := -1;
          RETURN;
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    p_curr := v_curr_code;
    p_rate := v_base_rate;

  EXCEPTION
    WHEN OTHERS THEN
      p_curr := NULL;
      p_rate := NULL;
  END get_linkage;

  PROCEDURE get_linkage_plus(p_po_num          VARCHAR2,
                             p_rate            OUT NUMBER,
                             p_curr            OUT po_headers_all.currency_code%TYPE,
                             p_date            OUT DATE,
                             p_conversion_type OUT clef062_po_index_esc_set.conversion_type%TYPE) IS

    v_base_rate       NUMBER;
    v_curr_code       VARCHAR2(50);
    v_date            DATE;
    v_conversion_type clef062_po_index_esc_set.conversion_type%TYPE;
  BEGIN

    SELECT base_rate, currency_code, base_date, tt.conversion_type
      INTO v_base_rate, v_curr_code, v_date, v_conversion_type
      FROM clef062_po_index_esc_set tt
     WHERE module = 'PO'
       AND document_id = p_po_num;

    p_curr            := v_curr_code;
    p_rate            := v_base_rate;
    p_date            := v_date;
    p_conversion_type := v_conversion_type;

  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        p_curr            := NULL;
        p_rate            := NULL;
        p_date            := NULL;
        p_conversion_type := NULL;
      END;
  END get_linkage_plus;

  FUNCTION get_po_destination(p_po_header_id NUMBER) RETURN VARCHAR2 IS
    l_destination_type_code VARCHAR2(20);
  BEGIN

    SELECT pd.destination_type_code
      INTO l_destination_type_code
      FROM po_line_locations_all pll, po_distributions_all pd
     WHERE pll.line_location_id = pd.line_location_id
       AND nvl(pll.cancel_flag, 'N') = 'N'
       AND nvl(pll.closed_code, 'OPEN') != 'FINALLY CLOSED'
       AND pll.po_header_id = p_po_header_id
       AND rownum < 2;
    RETURN l_destination_type_code;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_po_destination;
  ---------------------------
  FUNCTION check_inventory_destination(p_po_header_id NUMBER) RETURN VARCHAR2 IS
    v_numeric_dummy NUMBER;
  BEGIN

    IF p_po_header_id IS NULL THEN
      RETURN NULL;
    END IF;

    SELECT 1 ----'Y'     inventory_destination_exists
      INTO v_numeric_dummy
      FROM po_lines_all          pol,
           po_line_locations_all pll,
           po_distributions_all  pd
     WHERE pol.po_header_id = p_po_header_id --parameter
       AND pll.po_line_id = pol.po_line_id
       AND (pll.cancel_flag IS NULL OR pll.cancel_flag != 'Y')
       AND ((pll.closed_code IS NULL OR pll.closed_code != 'FINALLY CLOSED'))
       AND pd.line_location_id = pll.line_location_id
       AND pd.destination_type_code = 'INVENTORY'
       AND rownum = 1;

    RETURN 'Y';

  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN OTHERS THEN
      RETURN NULL;
  END check_inventory_destination;

  --------------------------------------------------------------------
  --  name:            get_vs_person_id
  --  create by:
  --  Revision:        1.0
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  9.12.15     yuval tal         CHG0037199 change  Vendor Scheduler at Site level attribute1
  --------------------------------------------------------------------

  FUNCTION get_vs_person_id(p_vendor_site_id NUMBER) RETURN NUMBER IS

    l_vs_employee_id NUMBER := NULL;
    l_vs_full_name   per_all_people_f.full_name%TYPE := NULL;

  BEGIN

    SELECT attribute1
      INTO l_vs_employee_id
      FROM ap_supplier_sites_all t
     WHERE t.vendor_site_id = p_vendor_site_id;

    RETURN l_vs_employee_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            get_vs_name
  --  create by:
  --  Revision:        1.0
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.x  9.12.15     yuval tal         CHG0037199 change  Vendor Scheduler at Site level attribute1
  --------------------------------------------------------------------

  FUNCTION get_vs_name(p_vendor_site_id NUMBER) RETURN VARCHAR2 IS

    l_vs_employee_id NUMBER := NULL;
    l_vs_full_name   per_all_people_f.full_name%TYPE := NULL;

  BEGIN
    l_vs_employee_id := get_vs_person_id(p_vendor_site_id);

    IF l_vs_employee_id IS NOT NULL THEN
      l_vs_full_name := hr_general.decode_person_name(l_vs_employee_id); --CHG0037199
    END IF;

    RETURN l_vs_full_name;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_vs_name;

  --------------------------------------------------------------------
  --  name:            get_vs_email
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/03/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034192 - get VS email address by supplier id
  --                   use in alert XX_INV_RISKY_KANBAN
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/03/2015  Dalit A. Raviv   initial build
  --  1.1  9.12.15     yuval tal        CHG0037199 change  Vendor Scheduler at Site level attribute1
  --------------------------------------------------------------------
  FUNCTION get_vs_email(p_vendor_site_id IN NUMBER) RETURN VARCHAR2 IS

    l_vs_employee_id   NUMBER := NULL;
    l_vs_email_address per_all_people_f.email_address%TYPE := NULL;

  BEGIN
    l_vs_employee_id := get_vs_person_id(p_vendor_site_id);

    IF l_vs_employee_id IS NOT NULL THEN

      SELECT pap.email_address
        INTO l_vs_email_address
        FROM per_all_people_f pap
       WHERE SYSDATE BETWEEN pap.effective_start_date AND
             pap.effective_end_date
         AND pap.person_id = l_vs_employee_id;
    END IF;

    RETURN l_vs_email_address;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_vs_email;
  -------------------------------------
  FUNCTION get_supplier_currency(p_vendor_id      NUMBER,
                                 p_vendor_site_id NUMBER) RETURN VARCHAR2 IS

    l_vendor_currency fnd_currencies.currency_code%TYPE;
  BEGIN

    SELECT nvl(ss.invoice_currency_code, s.invoice_currency_code)
      INTO l_vendor_currency
      FROM ap_suppliers s, ap_supplier_sites_all ss
     WHERE s.vendor_id = ss.vendor_id
       AND s.vendor_id = p_vendor_id
       AND ss.vendor_site_id = nvl(p_vendor_site_id, ss.vendor_site_id)
       AND rownum < 2;

    RETURN l_vendor_currency;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_supplier_currency;

  FUNCTION get_rtv_qty(p_line_location_id NUMBER) RETURN NUMBER AS

    l_ret_qty NUMBER;

  BEGIN
    SELECT SUM(rt.quantity)
      INTO l_ret_qty
      FROM rcv_transactions rt
     WHERE rt.transaction_type = 'RETURN TO VENDOR'
       AND rt.po_line_location_id = p_line_location_id; --6918

    RETURN l_ret_qty;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_rtv_qty;

  --------------------------------------------------------------------
  --  name:            get_acceptance_desc
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/2009
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  XX/XX/2009  XXX            initial build
  --  1.1  26/12/2010  Eran Baram     add trunc to action_date
  --  1.2  18.3.2012   yuval tal      support releasees
  --------------------------------------------------------------------
  FUNCTION get_acceptance_desc(p_header_id  NUMBER,
                               p_release_id NUMBER DEFAULT NULL)
    RETURN VARCHAR2 AS

    l_ret VARCHAR2(240);

  BEGIN

    IF p_release_id IS NULL THEN

      SELECT substr(polc.description, 1, 114) || ' (' || poa.action_date || ')'
        INTO l_ret
        FROM po_acceptances_v poa, po_lookup_codes polc
       WHERE polc.lookup_code = poa.acceptance_lookup_code
         AND polc.lookup_type = 'ACCEPTANCE TYPE'
         AND poa.po_header_id = p_header_id --2601
            /* AND trunc(poa.action_date) =
            (SELECT MAX(trunc(poa1.action_date))
               FROM po_acceptances_v poa1
              WHERE poa1.po_header_id = p_header_id)*/
         AND poa.last_update_date =
             (SELECT MAX(poa1.last_update_date)
                FROM po_acceptances_v poa1
               WHERE poa1.po_header_id = p_header_id)

         AND rownum = 1;
    ELSE

      SELECT substr(polc.description, 1, 114) || ' (' || poa.action_date || ')'
        INTO l_ret
        FROM po_acceptances_v poa, po_lookup_codes polc
       WHERE polc.lookup_code = poa.acceptance_lookup_code
         AND polc.lookup_type = 'ACCEPTANCE TYPE'

         AND poa.po_release_id = p_release_id
            /*  AND trunc(poa.action_date) =
            (SELECT MAX(trunc(poa1.action_date))
               FROM po_acceptances_v poa1
              WHERE poa1.po_release_id = p_release_id)*/
         AND poa.last_update_date =
             (SELECT MAX(poa1.last_update_date)
                FROM po_acceptances_v poa1
               WHERE poa1.po_release_id = p_release_id)

         AND rownum = 1;

    END IF;

    RETURN l_ret;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_acceptance_desc;

  -------------------------------------------
  -- highlight_record_check
  ------------------------------------------
  -- called by xxpocustom.pll
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  XX/XX/2009  XXX            initial build
  --  1.1  26/12/2010  YUVAL TAL      add green indicator when ...

  --  ITEM_NUMBER Field is not null
  --  DESTINATION_TYPE_CODE= ?Inventory?
  --  At least one Open Blanket Agreement Exist for this Item:
  --  1.  DOC_TYPE_NAME=?Blanket Purchase Agreement?
  --  2.  Blanket STATUS=Approved
  --  3.  Line.CANCEL_FLAG/CLOSED_FLAG != ?Y?
  --  4.  ITEM_ID (in Blanket)= ITEM_ID(in Auto Create Screen)
  --  5.  VENDOR_ID (in Blanket)= VENDOR_ID(in Auto Create Screen)
  --  6.  VENDOR_SITE_ID(in Blanket)= VENDOR_SITE_ID(in Auto Create Screen) or null
  --  7.  EXPIRATION_DATE(In Blanket) is null or >=Sysdate

  -------------------------------------------
  FUNCTION highlight_record_check(p_item_id          NUMBER,
                                  p_supplier_id      NUMBER,
                                  p_supplier_site_id NUMBER,
                                  p_req_currency     VARCHAR2)

   RETURN VARCHAR2 IS
    CURSOR c_blanket IS
      SELECT 'CUSTOM1'
        FROM po_lines_all l, po_headers_all h
       WHERE l.po_header_id = h.po_header_id
         AND h.type_lookup_code = 'BLANKET'
         AND h.authorization_status = 'APPROVED'
         AND l.item_id = p_item_id
         AND h.vendor_id = p_supplier_id
            --    AND h.vendor_site_id = nvl(p_supplier_site_id, h.vendor_site_id)
         AND nvl(l.cancel_flag, 'N') != 'Y'
         AND nvl(l.expiration_date, SYSDATE + 1) > SYSDATE
         AND rownum = 1;

    l_supplier_curr VARCHAR2(5);
    l_highlight     VARCHAR2(50);
    --l_return_check  VARCHAR2(1) := 'N';
  BEGIN

    l_supplier_curr := get_supplier_currency(p_supplier_id,
                                             p_supplier_site_id);

    -- check green highlight
    OPEN c_blanket;
    FETCH c_blanket
      INTO l_highlight;
    CLOSE c_blanket;

    IF l_highlight IS NOT NULL THEN
      RETURN l_highlight;
    END IF;
    -- check red highlight

    IF l_supplier_curr IS NULL THEN
      RETURN 'N';
    END IF;

    IF nvl(l_supplier_curr, 'USD') != nvl(p_req_currency, 'USD') THEN

      RETURN 'N';

    END IF;

    RETURN 'DATA_SPECIAL';

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';

  END highlight_record_check;

  FUNCTION get_formatted_amount(p_po_number   VARCHAR2,
                                p_po_currency VARCHAR2,
                                p_line_price  NUMBER,
                                p_release_num NUMBER) RETURN VARCHAR2 IS

    l_cle_rate         clef062_po_index_esc_set.base_rate%TYPE := NULL;
    l_linkage_currency clef062_po_index_esc_set.currency_code%TYPE := NULL;

  BEGIN

    SELECT base_rate, currency_code
      INTO l_cle_rate, l_linkage_currency
      FROM clef062_po_index_esc_set x
     WHERE module = 'PO'
       AND document_id = p_po_number
       AND x.release_num = p_release_num
       AND x.creation_date =
           xxpo_utils_pkg.get_last_linkage_creation(document_id,
                                                    nvl(release_num, 0));

    IF nvl(l_cle_rate, 0) = 0 THEN
      RETURN to_char(p_line_price,
                     xxgl_utils_pkg.safe_get_format_mask(p_po_currency,
                                                         30,
                                                         'Y',
                                                         4)) || ' ' || p_po_currency;
    ELSE
      RETURN to_char(p_line_price / l_cle_rate,
                     xxgl_utils_pkg.safe_get_format_mask(l_linkage_currency,
                                                         30,
                                                         'Y',
                                                         4)) || ' ' || l_linkage_currency;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN to_char(p_line_price,
                     xxgl_utils_pkg.safe_get_format_mask(p_po_currency,
                                                         30,
                                                         'Y',
                                                         4)) || ' ' || p_po_currency;

  END get_formatted_amount;

  -----------------------------------------------
  FUNCTION calc_po_price(p_from_cur VARCHAR2,
                         p_to_cur   VARCHAR2,
                         p_price    NUMBER) RETURN NUMBER AS

    v_ret  NUMBER;
    v_rate NUMBER;

  BEGIN
    -- get rate
    SELECT gr.conversion_rate
      INTO v_rate
      FROM gl_daily_rates gr
     WHERE gr.from_currency = p_from_cur
       AND gr.to_currency = p_to_cur
       AND gr.conversion_date = trunc(SYSDATE)
       AND gr.conversion_type = 'Corporate';

    v_ret := p_price * v_rate;
    RETURN v_ret;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END calc_po_price;

  ------------------------------------------
  FUNCTION get_line_type_basis(p_line_type_id NUMBER) RETURN VARCHAR2 AS

    v_basis VARCHAR2(100);

  BEGIN
    SELECT plt.order_type_lookup_code
      INTO v_basis
      FROM po_line_types plt
     WHERE plt.line_type_id = p_line_type_id;

    RETURN v_basis;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_line_type_basis;

  --------------------------------------------------------------------
  --  name:            get_last_po_price
  --  create by:       Yaniv Nitzan
  --  Revision:        1.0
  --  creation date:   25/04/2010
  --------------------------------------------------------------------
  --  purpose :        enable to retrieve the last PO price acording to reference
  --                   date to be provided as param for specific part number
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  25/04/2010  Yaniv Nitzan   initial build
  -- 1.1 12.6.17      yuval tal       CHG0040374 - modify  get_last_po_price add  parameter p_ou_id

  --------------------------------------------------------------------
  FUNCTION get_last_po_price(p_item_id NUMBER,
                             p_date    DATE,
                             p_ou_id   NUMBER DEFAULT 81) RETURN NUMBER IS

    l_price NUMBER;

  BEGIN
    SELECT gl_currency_api.convert_closest_amount_sql(nvl(ind.currency_code,
                                                          h.currency_code),
                                                      'USD',
                                                      nvl(ind.base_date,
                                                          nvl(h.rate_date,
                                                              h.creation_date)),
                                                      'Corporate',
                                                      nvl(ind.base_rate,
                                                          h.rate),
                                                      l.unit_price /
                                                      decode(ind.base_rate,
                                                             0,
                                                             1,
                                                             NULL,
                                                             1,
                                                             ind.base_rate),
                                                      7)
      INTO l_price
      FROM po_headers_all           h,
           po_lines_all             l,
           po_line_locations_all    pl,
           clef062_po_index_esc_set ind
     WHERE h.po_header_id = l.po_header_id
       AND h.segment1 = ind.document_id(+)
       AND l.po_line_id = pl.po_line_id
       AND h.po_header_id = pl.po_header_id
       AND ind.module(+) = 'PO'
       AND l.item_id = p_item_id
       AND pl.line_location_id =
           (SELECT MAX(pl1.line_location_id)
              FROM po_headers_all        h1,
                   po_lines_all          l1,
                   po_line_locations_all pl1
             WHERE h1.po_header_id = l1.po_header_id
               AND l1.po_line_id = pl1.po_line_id
               AND l1.item_id = p_item_id
               AND l1.org_id = p_ou_id
               AND h1.type_lookup_code IN ('BLANKET', 'STANDARD') -- yuval tal add
               AND h1.authorization_status = 'APPROVED' -- yuval tal add
               AND nvl(l1.cancel_flag, 'N') = 'N'
               AND nvl(pl1.promised_date, pl1.need_by_date) < p_date
               AND l1.unit_price > 0

            );
    RETURN l_price;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_last_po_price;
  -------------------------------------------------------------
  -- get_last_rcv_po_price
  ------------------------------------------------------------
  FUNCTION get_last_rcv_po_price(p_item_id NUMBER, p_date DATE) RETURN NUMBER IS

    l_price NUMBER;

  BEGIN

    SELECT gl_currency_api.convert_closest_amount_sql(nvl(ind.currency_code,
                                                          poh.currency_code),
                                                      'USD',
                                                      nvl(ind.base_date,
                                                          nvl(poh.rate_date,
                                                              poh.creation_date)),
                                                      'Corporate',
                                                      nvl(ind.base_rate,
                                                          poh.rate),
                                                      rcv.po_unit_price /
                                                      decode(ind.base_rate,
                                                             0,
                                                             1,
                                                             NULL,
                                                             1,
                                                             ind.base_rate),
                                                      7)
      INTO l_price
      FROM rcv_transactions         rcv,
           po_headers_all           poh,
           clef062_po_index_esc_set ind
     WHERE poh.po_header_id = rcv.po_header_id
       AND poh.segment1 = ind.document_id(+)
       AND ind.module(+) = 'PO'
       AND rcv.transaction_id =
           nvl((SELECT MAX(t.transaction_id)
                 FROM rcv_transactions   t,
                      rcv_shipment_lines s,
                      po_lines_all       l
                WHERE l.po_line_id = t.po_line_id
                  AND nvl(l.cancel_flag, 'N') = 'N'
                  AND s.shipment_line_id = t.shipment_line_id
                  AND s.item_id = p_item_id
                  AND transaction_type = 'DELIVER'
                  AND transaction_date < p_date),
               (SELECT MIN(t.transaction_id)
                  FROM rcv_transactions   t,
                       rcv_shipment_lines s,
                       po_lines_all       l
                 WHERE s.shipment_line_id = t.shipment_line_id
                   AND l.po_line_id = t.po_line_id
                   AND nvl(l.cancel_flag, 'N') = 'N'
                   AND s.item_id = p_item_id
                   AND transaction_type = 'DELIVER'
                   AND transaction_date >= p_date));

    RETURN l_price;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_last_rcv_po_price;

  -------------------------------------------------------------
  -- get_last_rcv_receipt_num
  ------------------------------------------------------------
  FUNCTION get_last_rcv_receipt_num(p_item_id NUMBER, p_date DATE)
    RETURN VARCHAR2 IS

    l_tmp VARCHAR2(50);

  BEGIN

    SELECT

     nvl((SELECT MAX(sh.receipt_num)
           FROM rcv_shipment_headers sh,
                rcv_transactions     t,
                rcv_shipment_lines   s,
                po_lines_all         l
          WHERE sh.shipment_header_id = s.shipment_header_id
            AND l.po_line_id = t.po_line_id
            AND nvl(l.cancel_flag, 'N') = 'N'
            AND s.shipment_line_id = t.shipment_line_id
            AND s.item_id = p_item_id
            AND transaction_type = 'DELIVER'
            AND transaction_date < p_date),
         (SELECT MIN(sh.receipt_num)
            FROM rcv_shipment_headers sh,
                 rcv_transactions     t,
                 rcv_shipment_lines   s,
                 po_lines_all         l
           WHERE sh.shipment_header_id = s.shipment_header_id
             AND s.shipment_line_id = t.shipment_line_id
             AND l.po_line_id = t.po_line_id
             AND nvl(l.cancel_flag, 'N') = 'N'
             AND s.item_id = p_item_id
             AND transaction_type = 'DELIVER'
             AND transaction_date >= p_date))
      INTO l_tmp
      FROM dual;

    RETURN l_tmp;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_last_rcv_receipt_num;

  --------------------------------------------------------------------
  --  name:            get_last_po_entity
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   25/05/2010
  --------------------------------------------------------------------
  --  purpose :        function that by item, date and entity return
  --                   from last po line data the detail user want to see.
  --  in param:        p_item_id
  --                   p_date
  --                   p_entity  - BUYER  - return buyer name
  --                               PO_NUM - return po number
  --                               QTY    - return last line found qty
  --                               PROMISED_DATE promise date
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  25/05/2010  Dalit A. Raviv initial build
  --  2.0  2.12.10     yuval tal      add logic
  --  2.1  13.3.13     yuval tal      support PROMISED_DATE entity
  --  2.2  16/12/2014  Dalit A. Raviv Add handle for entity = SUPLIER
  --------------------------------------------------------------------
  FUNCTION get_last_po_entity(p_item_id NUMBER,
                              p_date    DATE,
                              p_entity  VARCHAR2) RETURN VARCHAR2 IS

    l_agent_name    VARCHAR2(240) := NULL;
    l_po_number     VARCHAR2(20) := NULL;
    l_line_qty      NUMBER := NULL;
    l_promised_date DATE;
    --  2.2 16/12/2014 Dalit A. Raviv
    l_vendor_name VARCHAR2(240) := NULL;
  BEGIN
    SELECT papf.full_name,
           h.segment1,
           l.quantity,
           pl.promised_date,
           ap.vendor_name
      INTO l_agent_name,
           l_po_number,
           l_line_qty,
           l_promised_date,
           l_vendor_name
      FROM po_headers_all        h,
           po_lines_all          l,
           po_line_locations_all pl,
           per_all_people_f      papf,
           ap_suppliers          ap -- 2.2 16/12/2014 Dalit A. Raviv
     WHERE h.po_header_id = l.po_header_id
       AND l.po_line_id = pl.po_line_id
       AND h.po_header_id = pl.po_header_id
       AND h.agent_id = papf.person_id
       AND trunc(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date
       AND l.item_id = p_item_id
       AND l.po_line_id =
           (SELECT MAX(l1.po_line_id)
              FROM po_headers_all        h1,
                   po_lines_all          l1,
                   po_line_locations_all pl
             WHERE h1.po_header_id = l1.po_header_id
               AND l1.po_line_id = pl.po_line_id
               AND l1.item_id = p_item_id
               AND l1.org_id = 81
               AND h1.type_lookup_code IN ('BLANKET', 'STANDARD') -- yuval tal 2.12.10
               AND h1.authorization_status = 'APPROVED' -- yuval tal 2.12.10
               AND nvl(l1.cancel_flag, 'N') = 'N'
               AND pl.promised_date < p_date
               AND l1.unit_price > 0)
          --  2.2 16/12/2014 Dalit A. Raviv
       AND h.vendor_id = ap.vendor_id
       AND rownum = 1;

    IF p_entity = 'BUYER' THEN
      RETURN l_agent_name;
    ELSIF p_entity = 'PO_NUM' THEN
      RETURN l_po_number;
    ELSIF p_entity = 'QTY' THEN
      RETURN to_char(l_line_qty);
    ELSIF p_entity = 'PROMISED_DATE' THEN
      RETURN to_char(l_promised_date, 'DD-MON-YYYY');
    ELSIF p_entity = 'SUPPLIER' THEN
      RETURN l_vendor_name;
    ELSE
      RETURN 'NO_SUCH_ENTITY';
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_last_po_entity;

  ---------------------------------------------
  -- get_blanket_total_amt
  ---------------------------------------------
  FUNCTION get_blanket_total_amt(p_po_header_id NUMBER) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN

    SELECT SUM(t.quantity_committed * t.unit_price)
      INTO l_tmp
      FROM po_lines_all t
     WHERE t.po_header_id = p_po_header_id
       AND nvl(t.cancel_flag, 'N') = 'N';

    RETURN l_tmp;
  END;

  ------------------------------------------------------
  -- update_suggested_buyer   [obsolete - Donot Use]
  -- purpose : form personalization need
  ------------------------------------------------------
  --  ver  date        name           desc
  --  1.1  21.01.13     yuval tal     cr657 : get_default_buyer
  --  1.2  05.NOV.18    Lingaraj      CHG0043863 - Procedure obsolete
  --                                  Use Procedure update_suggested_buyer2
  ------------------------------------------------------  
  PROCEDURE update_suggested_buyer_old(p_requisition_header_id NUMBER) IS
    CURSOR c IS
      SELECT *
        FROM po_requisition_lines_all l
       WHERE nvl(l.cancel_flag, 'N') = 'N'
         AND l.suggested_buyer_id IS NULL
         AND l.requisition_header_id = p_requisition_header_id;

    l_suggested_buyer_id NUMBER;
  BEGIN
    FOR i IN c LOOP
      l_suggested_buyer_id := get_default_buyer(p_requisition_header_id,
                                                'ID',
                                                i.category_id,
                                                i.to_person_id);

      UPDATE po_requisition_lines_all l
         SET l.suggested_buyer_id = l_suggested_buyer_id
       WHERE l.requisition_line_id = i.requisition_line_id;
      COMMIT;
    END LOOP;

  END update_suggested_buyer_old;                              
  --
  Function get_main_technology_buyer(p_vendor_id number)
           return number
  is       
  l_main_technology_buyer_id NUMBER;
  Begin 
    select to_number(t.attribute1) 
    into l_main_technology_buyer_id
    from  ap_suppliers asp,
          fnd_flex_values_vl  t,
          fnd_flex_value_sets vs
    where asp.vendor_id = p_vendor_id
    and vs.flex_value_set_id = t.flex_value_set_id
    and vs.flex_value_set_name = 'XXPUR_SUPPLIER_TECH_VS'
    and t.flex_value           =  asp.attribute3   
    and t.enabled_flag         = 'Y'
    and trunc(sysdate) between nvl(t.start_date_active, trunc(sysdate)) and
           nvl(t.end_date_active, trunc(sysdate)); 
    
    Return l_main_technology_buyer_id;
  Exception
  When no_data_found Then
    Return null;
  End get_main_technology_buyer;
    --          
  --------------------------------------------------------------------
  --  name:            update_suggested_buyer
  --  create by:       Lingaraj
  --  Revision:        1.0
  --  creation date:   05-Nov-2018
  --------------------------------------------------------------------
  --  purpose :  Getting Calling from Requisition Form Personilization      
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  05-Nov-2018 Lingaraj        CHG0043863-CTASK0038483-New Logic for Default Buyer
  --------------------------------------------------------------------
  PROCEDURE update_suggested_buyer(p_requisition_header_id NUMBER,
                                    p_module                VARCHAR2 DEFAULT 'xxpo_utils_pkg.update_suggested_buyer',
                                    p_debug                 NUMBER DEFAULT 0) IS
    CURSOR pr_line_cur IS
      SELECT  prl.suggested_buyer_id,prl.requisition_line_id, 
              prl.destination_type_code,prl.category_id,prl.vendor_id,
              prv.total req_tot_value,prv.Currency_code,
              (select pa.attribute1 
               from po_agents pa
               where pa.agent_id = prl.suggested_buyer_id 
               and trunc(sysdate) between
                     nvl(pa.start_date_active, trunc(sysdate)) and
                     nvl(pa.end_date_active, trunc(sysdate))
               )Buyer_Team        
        FROM po_requisition_lines_all prl,
             po_requisition_headers_v prv
       WHERE nvl(prl.cancel_flag, 'N') = 'N'         
         AND prl.requisition_header_id = p_requisition_header_id
         AND prv.requisition_header_id = prl.requisition_header_id; 
    
    l_suggested_buyer_id NUMBER;
    l_default_direct_buyer_id NUMBER  := to_number(fnd_profile.value('XX_DEFAULT_REQUISITION_DIRECT_BUYER'));
    l_default_indirect_buyer_id NUMBER:= to_number(fnd_profile.value('XX_DEFAULT_REQUISITION_INDIRECT_BUYER'));
    l_default_poc_amt NUMBER:= to_number(fnd_profile.value('XX_DEFAULT_REQUISITION_POC_AMOUNT'));
    l_buyer_team         VARCHAR2(240);
    l_pr_line_buyer_id  NUMBER;  
    l_tot_pr_amt        NUMBER;    
    l_pr_line_cnt  NUMBER:=0; 
    l_pr_Exp_line_cnt NUMBER:= 0;     
    l_ind_src_cnt     NUMBER := 0;
  BEGIN     
    If p_debug = 1 Then
      fnd_log.string(log_level => fnd_log.level_statement,
	                 module    => p_module,
	                 message   => 
                     ('Profile Value [XX: Default Requisition Direct Buyer] ID :'||l_default_direct_buyer_id
                      ||',Profile Value [XX: Default Requisition Indirect Buyer] ID :'||l_default_indirect_buyer_id
                      ||',p_requisition_header_id :'||p_requisition_header_id
                      )                     
                    );
    End If;
    
    FOR pr_rec IN pr_line_cur LOOP
        l_suggested_buyer_id    := null;
        l_buyer_team         := '';
        l_pr_line_buyer_id   := null;   
        l_tot_pr_amt         := pr_rec.req_tot_value;            
        l_pr_line_cnt        := l_pr_line_cnt+1;
        
        If pr_rec.destination_type_code = 'EXPENSE' Then
          l_pr_Exp_line_cnt := l_pr_Exp_line_cnt + 1;                             
        End If;
        
        
         If pr_rec.suggested_buyer_id is null Then 
            If pr_rec.destination_type_code = 'EXPENSE' Then
                Begin
                  SELECT pa.agent_id   suggested_buyer_id,
                         pa.attribute1 Buyer_Team
                  into  l_suggested_buyer_id , l_buyer_team 
                  FROM fnd_flex_values_vl  t,
                       fnd_flex_value_sets vs,
                       mtl_categories_b    cat,
                       fnd_user            fu ,
                       po_agents           pa
                 WHERE fu.user_name = upper(t.description)                        
                   and vs.flex_value_set_id = t.flex_value_set_id
                   and vs.flex_value_set_name =
                       'XXPO_SUGGESTED_BUYER_GROUP_LEVEL'
                   and parent_flex_value_low = cat.attribute2
                   and nvl(t.enabled_flag, 'N') = 'Y'
                   and trunc(sysdate) between
                       nvl(t.start_date_active, trunc(sysdate)) and
                       nvl(t.end_date_active, trunc(sysdate))                    
                   and pa.agent_id = fu.employee_id
                   and trunc(sysdate) between
                       nvl(pa.start_date_active, trunc(sysdate)) and
                       nvl(pa.end_date_active, trunc(sysdate))
                   and cat.category_id = pr_rec.category_id;                    
                       
                Exception
                When no_data_found or too_many_rows Then
                   l_suggested_buyer_id := null;
                   l_buyer_team      := ''; 
                End;
                    
                If l_buyer_team = 'Indirect Sourcing' Then
                   If pr_rec.req_tot_value <= l_default_poc_amt Then
                      l_pr_line_buyer_id := l_default_indirect_buyer_id;
                   ElsIf pr_rec.vendor_id is not null Then                        
                      l_pr_line_buyer_id := 
                         nvl(get_main_technology_buyer(pr_rec.vendor_id),l_suggested_buyer_id);
                   Else 
                      l_pr_line_buyer_id := l_suggested_buyer_id;                                 
                   End If; 
                Elsif l_buyer_team = '' Then
                   l_pr_line_buyer_id := l_default_indirect_buyer_id;
                Else 
                   l_pr_line_buyer_id := l_suggested_buyer_id;       
                End If;     
                
            ElsIf pr_rec.destination_type_code in ('INVENTORY','SHOP FLOOR') Then      
                 l_pr_line_buyer_id :=  l_default_direct_buyer_id;
            Else
                 l_pr_line_buyer_id :=  l_default_indirect_buyer_id;                            
            End If;
         End If;    
        
      
        If pr_rec.suggested_buyer_id is null and
           l_pr_line_buyer_id is not null 
        Then 
          UPDATE po_requisition_lines_all prl
             SET prl.suggested_buyer_id  = l_pr_line_buyer_id
           WHERE prl.requisition_line_id = pr_rec.requisition_line_id;
          COMMIT;         
        End If;  
    END LOOP;
    
    --Logic for PR Level Suggested Buyer
    If l_tot_pr_amt <= l_default_poc_amt and       
       l_pr_line_cnt = l_pr_Exp_line_cnt   -- All PR Lines are Expense
    Then
       FOR pr_rec IN pr_line_cur LOOP
           If pr_rec.suggested_buyer_id is null OR
              pr_rec.buyer_team = 'Indirect Sourcing' 
           Then
              l_ind_src_cnt := l_ind_src_cnt + 1;
           End If;
       End Loop;
        
       -- Update All the Buyer to POC Default Buyer
       If  l_pr_line_cnt = l_ind_src_cnt Then
          UPDATE po_requisition_lines_all prl
             SET prl.suggested_buyer_id    = l_default_indirect_buyer_id
           WHERE prl.requisition_header_id = p_requisition_header_id
           and nvl(prl.cancel_flag,'N') = 'N';
          COMMIT;    
       End If;            
    End If;
  END update_suggested_buyer;  
  ----------------------------------------------------------------
  -- get_default_buyer
  -- support OU IL only
  -- p_type : ID/NAME
  -- return name or person id of buyer
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.1  21.01.13     yuval tal     cr657 : get_default_buyer :
  --                                  Get Pre Buyer per Category group Amount
  --                                  add parameter : p_requisition_header_id,
  ----------------------------------------------------------------          
  FUNCTION get_default_buyer(p_requisition_header_id NUMBER,
                             p_type                  VARCHAR2,
                             p_category_id           NUMBER,
                             p_requestor_id          NUMBER) RETURN VARCHAR2 IS

    /*CURSOR cat IS
    SELECT attribute2
      FROM mtl_categories_b
     WHERE category_id = p_category_id;*/

    CURSOR get_buyer_by_category(c_amount NUMBER, c_category_id NUMBER) IS
      SELECT emp_full_name
        FROM (SELECT hr_general.decode_person_name(u.employee_id) emp_full_name,
                     -- upper(t.description),
                     nvl(hierarchy_level, 999999999999) to_level,
                     lag(hierarchy_level, 1, 0) over(ORDER BY nvl(hierarchy_level, 999999999999)) AS from_level
                FROM fnd_flex_values_vl  t,
                     fnd_flex_value_sets vs,
                     mtl_categories_b    cat,
                     fnd_user            u
               WHERE u.user_name = upper(t.description)
                 AND cat.category_id = c_category_id
                 AND vs.flex_value_set_id = t.flex_value_set_id
                 AND vs.flex_value_set_name =
                     'XXPO_SUGGESTED_BUYER_GROUP_LEVEL'
                 AND parent_flex_value_low = cat.attribute2)
       WHERE c_amount BETWEEN from_level AND to_level; --'INDIRECT';

    CURSOR c_req_dep IS
      SELECT gl.segment2
        FROM per_all_assignments_f r, gl_code_combinations gl
       WHERE r.person_id = p_requestor_id
         AND gl.code_combination_id = r.default_code_comb_id
         AND SYSDATE BETWEEN r.effective_start_date AND
             r.effective_end_date
         AND r.assignment_type = 'E';

    CURSOR c_pos(c_pos_name VARCHAR2) IS
      SELECT per.person_id
        FROM per_all_assignments_f r,
             per_positions_v       l,
             per_all_people_f      per
       WHERE l.name = c_pos_name
         AND l.position_id = r.position_id
         AND r.person_id = per.person_id
         AND SYSDATE BETWEEN per.effective_start_date AND
             per.effective_end_date
         AND SYSDATE BETWEEN r.effective_start_date AND
             r.effective_end_date;

    l_buyer_name VARCHAR2(50);
    l_buyer_id   NUMBER;
    l_dep        VARCHAR2(50);
    l_amount     NUMBER;
  BEGIN

    --
    -- get amount for category  group
    --

    -- get req amount for group category
    -- valid for ou il only usd amount
    SELECT SUM(l.unit_price * l.quantity)
      INTO l_amount
      FROM po_requisition_lines_all l, mtl_categories_b cat
     WHERE l.category_id = cat.category_id
       AND nvl(l.cancel_flag, 'N') = 'N'
       AND l.requisition_header_id = p_requisition_header_id
       AND cat.attribute2 =
           (SELECT attribute2
              FROM mtl_categories_b cat
             WHERE cat.category_id = p_category_id);

    --

    OPEN get_buyer_by_category(l_amount, p_category_id);
    FETCH get_buyer_by_category
      INTO l_buyer_name;
    CLOSE get_buyer_by_category;

    IF l_buyer_name IS NOT NULL THEN
      IF p_type = 'NAME' THEN
        RETURN l_buyer_name;
      ELSE
        RETURN xxhr_util_pkg.get_person_id_by_fn(l_buyer_name);
      END IF;
    END IF;

    ---- get requestor dep
    OPEN c_req_dep;
    FETCH c_req_dep
      INTO l_dep;
    CLOSE c_req_dep;

    IF l_dep != '410' THEN

      OPEN c_pos('IL Indirect Buyer');
      FETCH c_pos
        INTO l_buyer_id;
      l_buyer_name := hr_general.decode_person_name(l_buyer_id);
      CLOSE c_pos;
    ELSE

      OPEN c_pos('IL R&D Buyer');
      FETCH c_pos
        INTO l_buyer_id;
      l_buyer_name := hr_general.decode_person_name(l_buyer_id);
      CLOSE c_pos;

    END IF;

    --
    IF p_type = 'NAME' THEN
      RETURN nvl(l_buyer_name,
                 fnd_profile.value('XXPO_DEFAULT_REQ_SUGGESTED_BUYER'));
    ELSE
      RETURN nvl(l_buyer_id,
                 xxhr_util_pkg.get_person_id_by_fn(fnd_profile.value('XXPO_DEFAULT_REQ_SUGGESTED_BUYER')));

    END IF;

  END get_default_buyer;                               
  -------------------------------------------
  -- get_inv_num_for_po
  -------------------------------------------
  FUNCTION get_inv_num_for_po(p_shipment_id NUMBER) RETURN VARCHAR2 IS
    l_ret_value VARCHAR2(500);
    CURSOR c_lines IS
      SELECT DISTINCT aia.invoice_num
        FROM po_distributions_all         pda,
             ap_invoice_distributions_all aid,
             ap_invoices_all              aia
       WHERE pda.line_location_id = p_shipment_id
         AND pda.po_distribution_id = aid.po_distribution_id
         AND aia.invoice_id = aid.invoice_id;
  BEGIN
    FOR i IN c_lines LOOP
      l_ret_value := l_ret_value || i.invoice_num || ',';
    END LOOP;
    RETURN rtrim(l_ret_value, ',');
  END get_inv_num_for_po;

  ----------------------------------------------
  -- get_inv_amt_for_po
  -------------------------------------------
  FUNCTION get_inv_amt_for_po(p_shipment_id NUMBER) RETURN NUMBER IS
    l_ret_value NUMBER;
  BEGIN
    SELECT nvl(SUM(aid.amount), 0)
      INTO l_ret_value
      FROM po_distributions_all pda, ap_invoice_distributions_all aid
     WHERE pda.line_location_id = p_shipment_id
       AND pda.po_distribution_id = aid.po_distribution_id;

    RETURN l_ret_value;
  END get_inv_amt_for_po;

  -------------------------------------------
  -- get_inv_USD_amt_for_po
  -----------------------------------------
  FUNCTION get_inv_usd_amt_for_po(p_shipment_id NUMBER) RETURN NUMBER IS
    l_ret_value NUMBER;
  BEGIN
    SELECT nvl(SUM(aid.base_amount), 0)
      INTO l_ret_value
      FROM po_distributions_all pda, ap_invoice_distributions_all aid
     WHERE pda.line_location_id = p_shipment_id
       AND pda.po_distribution_id = aid.po_distribution_id;

    RETURN l_ret_value;
  END get_inv_usd_amt_for_po;

  ---------------------------------------------
  -- get_first_approve_date
  ----------------------------------------------

  FUNCTION get_first_approve_date(p_po_header_id NUMBER, p_type VARCHAR2)
    RETURN DATE IS

    CURSOR c(c_object_type_code VARCHAR2, c_object_sub_type_code VARCHAR2) IS
      SELECT MIN(h.action_date)
        FROM po_action_history h
       WHERE h.object_type_code = c_object_type_code
         AND h.object_sub_type_code = c_object_sub_type_code
         AND h.object_id = p_po_header_id
         AND h.object_revision_num = 0
         AND h.action_code = 'APPROVE';

    l_tmp                  DATE;
    l_object_type_code     VARCHAR2(50);
    l_object_sub_type_code VARCHAR2(50);
  BEGIN

    CASE p_type
      WHEN 'STANDARD' THEN
        l_object_type_code     := 'PO';
        l_object_sub_type_code := 'STANDARD';
      WHEN 'BLANKET' THEN
        l_object_type_code     := 'PA';
        l_object_sub_type_code := 'BLANKET';

      WHEN 'RELEASE' THEN
        l_object_type_code     := 'RELEASE';
        l_object_sub_type_code := 'BLANKET';

    END CASE;
    OPEN c(l_object_type_code, l_object_sub_type_code);
    FETCH c
      INTO l_tmp;
    CLOSE c;

    RETURN l_tmp;

  END;

  ---------------------------------------
  -- is_po_exists
  ---------------------------------------

  FUNCTION is_po_exists(p_org_id       NUMBER,
                        p_po_header_id NUMBER,
                        p_po_line_id   NUMBER,
                        p_item_id      NUMBER,
                        p_vendor_id    NUMBER) RETURN VARCHAR2 IS

    l_tmp VARCHAR2(1);
    CURSOR c IS
      SELECT 'Y'
        FROM po_headers_all poh, po_lines_all pol
       WHERE pol.item_id = nvl(p_item_id, pol.item_id)
         AND poh.po_header_id = pol.po_header_id
         AND poh.org_id = nvl(p_org_id, poh.org_id)
         AND poh.type_lookup_code IN ('BLANKET', 'STANDARD')
         AND pol.line_type_id = 1
            --and pol.creation_date>=to_date('15-JUN-2011','DD-MON-RRRR')
         AND poh.vendor_id = nvl(p_vendor_id, poh.vendor_id)
         AND pol.po_line_id = nvl(p_po_line_id, pol.po_line_id)
         AND poh.po_header_id = nvl(p_po_header_id, poh.po_header_id);

  BEGIN

    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN nvl(l_tmp, 'N');
  END;

  ---------------------------------------
  -- is_quotation_exists
  ---------------------------------------
  FUNCTION is_quotation_exists(p_org_id    NUMBER,
                               p_item_id   NUMBER,
                               p_vendor_id NUMBER) RETURN VARCHAR2 IS

    l_tmp VARCHAR2(1);
    CURSOR c IS
      SELECT 'Y'
        FROM po_headers_all pohh, po_lines_all poll, po_headers_all poh1
       WHERE pohh.po_header_id = poll.po_header_id
         AND pohh.type_lookup_code = 'QUOTATION'
         AND pohh.vendor_id = poh1.vendor_id
         AND pohh.status_lookup_code = 'A'
         AND poll.item_id = nvl(p_item_id, poll.item_id)
         AND poh1.org_id = nvl(p_org_id, poh1.org_id)
         AND poh1.vendor_id = nvl(p_vendor_id, poh1.vendor_id);

  BEGIN

    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN nvl(l_tmp, 'N');
  END;

  --------------------------------------
  -- get_item_schedule_group_name
  --
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  05/05/2013  yuval tal      initial build : usage : CR-643-Shipping backlog - Add additional columns for tracing Inter SO
  --------------------------------------------------------------------

  FUNCTION get_item_schedule_group_name(p_item_id         NUMBER,
                                        p_organization_id NUMBER)
    RETURN VARCHAR2 IS

    CURSOR c IS
      SELECT sg.schedule_group_name
        FROM bom_operational_routings_v tt, wip_schedule_groups sg
       WHERE tt.assembly_item_id = p_item_id
         AND tt.organization_id = p_organization_id
         AND tt.alternate_routing_designator IS NULL
         AND sg.schedule_group_id = to_number(tt.attribute1);
    l_tmp VARCHAR2(100);
  BEGIN

    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN l_tmp;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  -----------------------------------------------
  -- get_req_info
  -- get info for requisition without po
  --
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  05/05/2013  yuval tal      initial build : usage : CR-643-Shipping backlog - Add additional columns for tracing Inter SO
  --------------------------------------------------------------------

  FUNCTION get_req_info(p_item_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(32000);
  BEGIN

    SELECT listagg(segment1 || '-' || l.quantity || '-' ||
                   to_char(l.need_by_date, 'DD/MM/YYYY'),
                   ';') within GROUP(ORDER BY item_id) xx
      INTO l_tmp
      FROM po_requisition_headers_all h, po_requisition_lines_all l
     WHERE h.authorization_status IN ('APPROVED', 'IN PROCESS')
       AND h.type_lookup_code = 'PURCHASE'
       AND h.requisition_header_id = l.requisition_header_id
       AND l.item_id = p_item_id
       AND nvl(l.cancel_flag, 'N') != 'Y'
       AND l.line_location_id IS NULL;

    RETURN l_tmp;

  END;

  -----------------------------------------------
  -- get_open_po_info
  --
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  05/05/2013  yuval tal      initial build : usage : CR-643-Shipping backlog - Add additional columns for tracing Inter SO
  --------------------------------------------------------------------

  FUNCTION get_open_po_info(p_item_id NUMBER) RETURN VARCHAR2

   IS
    l_tmp VARCHAR2(32000);

  BEGIN
    SELECT listagg(segment1 || '-' || quantity_left || '-' ||
                   to_char(promised_date, 'DD/MM/YYYY'),
                   ';') within GROUP(ORDER BY item_id) xx
      INTO l_tmp
      FROM (SELECT h.segment1,
                   l.item_id,
                   pll.quantity - pll.quantity_received -
                   pll.quantity_rejected quantity_left,
                   pll.promised_date promised_date
              FROM po_line_locations_all pll,
                   po_headers_all        h,
                   po_lines_all          l
             WHERE l.po_line_id = pll.po_line_id
               AND pll.po_header_id = h.po_header_id
               AND h.authorization_status = 'APPROVED'
               AND pll.po_release_id IS NULL
               AND nvl(pll.cancel_flag, 'N') = 'N'
            UNION ALL
            SELECT h.segment1 || '-' || r.release_num segment1,
                   l.item_id,
                   pll.quantity - pll.quantity_received -
                   pll.quantity_rejected quantity_left,
                   pll.promised_date promised_date
              FROM po_line_locations_all pll,
                   po_releases_all       r,
                   po_lines_all          l,
                   po_headers_all        h
             WHERE h.po_header_id = r.po_header_id
               AND l.po_line_id = pll.po_line_id
               AND pll.po_release_id = r.po_release_id
               AND r.authorization_status = 'APPROVED'
               AND nvl(pll.cancel_flag, 'N') = 'N')
     WHERE quantity_left > 0
       AND item_id = p_item_id;

    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  -----------------------------------------------
  -- get_open_po_quantity
  --
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  05/05/2013  yuval tal      initial build : usage : CR-643-Shipping backlog - Add additional columns for tracing Inter SO
  --------------------------------------------------------------------
  FUNCTION get_open_po_quantity(p_item_id NUMBER) RETURN NUMBER

   IS
    l_tmp NUMBER;

  BEGIN
    SELECT SUM(quantity_left) xx
      INTO l_tmp
      FROM (SELECT h.segment1,
                   l.item_id,
                   pll.quantity - pll.quantity_received -
                   pll.quantity_rejected quantity_left,
                   nvl(pll.promised_date, pll.need_by_date) promised_date
              FROM po_line_locations_all pll,
                   po_headers_all        h,
                   po_lines_all          l
             WHERE l.po_line_id = pll.po_line_id
               AND pll.po_header_id = h.po_header_id
               AND h.authorization_status = 'APPROVED'
               AND pll.po_release_id IS NULL
               AND nvl(pll.cancel_flag, 'N') = 'N'
            UNION ALL
            SELECT h.segment1 || '-' || r.release_num segment1,
                   l.item_id,
                   pll.quantity - pll.quantity_received -
                   pll.quantity_rejected quantity_left,
                   nvl(pll.promised_date, pll.need_by_date) promised_date
              FROM po_line_locations_all pll,
                   po_releases_all       r,
                   po_lines_all          l,
                   po_headers_all        h
             WHERE h.po_header_id = r.po_header_id
               AND l.po_line_id = pll.po_line_id
               AND pll.po_release_id = r.po_release_id
               AND r.authorization_status = 'APPROVED'
               AND nvl(pll.cancel_flag, 'N') = 'N')
     WHERE quantity_left > 0
       AND item_id = p_item_id;

    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_matching_type
  Author's Name:   Sandeep Akula
  Date Written:    29-AUGUST-2014
  Purpose:         Derives the Matching Type for the PO (This Function does not check if the PO was matched to a Invoice)
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  29-AUGUST-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031574
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_matching_type(p_header_id   IN NUMBER,
                             p_line_id     IN NUMBER,
                             p_release_num IN NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_match_cnt NUMBER := '';
  BEGIN

    l_match_cnt := '';

    BEGIN
      SELECT COUNT(*)
        INTO l_match_cnt
        FROM po_line_locations_all pll, po_releases_all pr
       WHERE pll.po_header_id = p_header_id
         AND pll.po_line_id = p_line_id
         AND pll.po_header_id = pr.po_header_id(+)
         AND pr.release_num(+) = p_release_num
         AND nvl(pll.inspection_required_flag, 'N') = 'N'
         AND nvl(pll.receipt_required_flag, 'N') = 'N';
    EXCEPTION
      WHEN OTHERS THEN
        l_match_cnt := '';
    END;

    IF l_match_cnt > '0' THEN
      RETURN('2-Way Match');
    ELSE

      l_match_cnt := '';

      BEGIN
        SELECT COUNT(*)
          INTO l_match_cnt
          FROM po_line_locations_all pll, po_releases_all pr
         WHERE pll.po_header_id = p_header_id
           AND pll.po_line_id = p_line_id
           AND pll.po_header_id = pr.po_header_id(+)
           AND pr.release_num(+) = p_release_num
           AND nvl(pll.inspection_required_flag, 'N') = 'N'
           AND nvl(pll.receipt_required_flag, 'N') = 'Y';
      EXCEPTION
        WHEN OTHERS THEN
          l_match_cnt := '';
      END;

      IF l_match_cnt > '0' THEN
        RETURN('3-Way Match');
      ELSE

        l_match_cnt := '';

        BEGIN
          SELECT COUNT(*)
            INTO l_match_cnt
            FROM po_line_locations_all pll, po_releases_all pr
           WHERE pll.po_header_id = p_header_id
             AND pll.po_line_id = p_line_id
             AND pll.po_header_id = pr.po_header_id(+)
             AND pr.release_num(+) = p_release_num
             AND nvl(pll.inspection_required_flag, 'N') = 'Y'
             AND nvl(pll.receipt_required_flag, 'N') = 'Y';
        EXCEPTION
          WHEN OTHERS THEN
            l_match_cnt := '';
        END;

        IF l_match_cnt > '0' THEN
          RETURN('4-Way Match');
        ELSE
          RETURN(NULL);
        END IF; -- 4 Way Match
      END IF; -- 3 Way Match
    END IF; -- 2 Way Match
  END get_matching_type;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_project_number
  Author's Name:   Sandeep Akula
  Date Written:    29-AUGUST-2014
  Purpose:         Derives the Project Number on the PO
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  29-AUGUST-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031574
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_project_number(p_project_id IN NUMBER) RETURN VARCHAR2 IS
    l_project_number pa_projects_all.segment1%TYPE;
  BEGIN

    BEGIN
      SELECT segment1
        INTO l_project_number
        FROM pa_projects_all
       WHERE project_id = p_project_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_project_number := '';
    END;

    RETURN(l_project_number);

  END get_project_number;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_task_number
  Author's Name:   Sandeep Akula
  Date Written:    29-AUGUST-2014
  Purpose:         Derives the Task Number on the PO
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  29-AUGUST-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031574
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_task_number(p_project_id IN NUMBER, p_task_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_task_number pa_tasks.task_number%TYPE;
  BEGIN

    BEGIN
      SELECT task_number
        INTO l_task_number
        FROM pa_tasks
       WHERE project_id = p_project_id
         AND task_id = p_task_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_task_number := '';
    END;

    RETURN(l_task_number);
  END get_task_number;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_expenditure_org
  Author's Name:   Sandeep Akula
  Date Written:    29-AUGUST-2014
  Purpose:         Derives the Expenditure Organization on the PO
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  29-AUGUST-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031574
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_expenditure_org(p_organization_id IN NUMBER) RETURN VARCHAR2 IS
    l_expd_org hr_all_organization_units.name%TYPE;
  BEGIN

    BEGIN
      SELECT NAME
        INTO l_expd_org
        FROM hr_all_organization_units
       WHERE organization_id = p_organization_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_expd_org := '';
    END;

    RETURN(l_expd_org);
  END get_expenditure_org;

  --------------------------------------------------------------------
  --  name:            get_item_sourcing_rule
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/12/2014 09:09:38
  --------------------------------------------------------------------
  --  purpose :        retrieve item sourcing rule, if null look at the item category
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  16/12/2014  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_item_sourcing_rule(p_organization_id   IN NUMBER,
                                  p_inventory_item_id IN NUMBER)
    RETURN VARCHAR2 IS

    l_sourcing_rule_name VARCHAR2(50) := NULL;
  BEGIN
    -- get item level sourcing rule
    BEGIN
      SELECT msr.sourcing_rule_name
        INTO l_sourcing_rule_name
        FROM mrp_assignment_sets mas,
             mrp_sr_assignments  msa,
             mrp_sourcing_rules  msr
       WHERE mas.assignment_set_id =
             fnd_profile.value('MRP_DEFAULT_ASSIGNMENT_SET') -- SSYS Global Assignment
         AND mas.assignment_set_id = msa.assignment_set_id
         AND msr.sourcing_rule_id = msa.sourcing_rule_id
         AND msa.organization_id = p_organization_id
         AND msa.inventory_item_id = p_inventory_item_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_sourcing_rule_name := NULL;
      WHEN OTHERS THEN
        l_sourcing_rule_name := NULL;
    END;
    -- get item category sourcing rule
    IF l_sourcing_rule_name IS NULL THEN
      BEGIN
        SELECT msr.sourcing_rule_name
          INTO l_sourcing_rule_name
          FROM mtl_item_categories mic,
               mrp_sr_assignments  msa,
               mrp_sourcing_rules  msr
         WHERE mic.inventory_item_id = p_inventory_item_id
           AND mic.organization_id = 91
           AND mic.category_set_id =
               fnd_profile.value('MRP_SRA_CATEGORY_SET') -- 1100000041
           AND mic.category_id = msa.category_id
           AND mic.category_set_id = msa.category_set_id
           AND msa.organization_id = p_organization_id
           AND msr.sourcing_rule_id = msa.sourcing_rule_id;
      EXCEPTION
        WHEN OTHERS THEN
          RETURN NULL;
      END;
    END IF; -- look for item category sourcing rule
    RETURN l_sourcing_rule_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_item_sourcing_rule;
  --------------------------------------------------------------------
  --  name:            get_item_costForPO
  --  create by:       L.Sarangi
  --  Revision:        1.0
  --  creation date:   25/08/2016
  --------------------------------------------------------------------
  --  purpose :        retrieve Item Cost for PO Notification
  --                   This Item Cost will be displayed in the PO Approval Notification
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  25/08/2016  L.Sarangi       initial build
  --                                   CHG0038985 - Add item cost to Blanket/ standard PO approval notification
  --  1.1  10/03/2017  N.Kumar         UOM Conversion logic
  --                                   CHG0040109 - Std. Material Cost in notification should be converted to PO Line UOM amount using UOM conversion
  --------------------------------------------------------------------
  PROCEDURE get_item_costforpo(p_po_line_id    IN po_lines_all.po_line_id%TYPE,
                               p_item_cost     OUT cst_item_costs.item_cost%TYPE,
                               p_currency_code OUT VARCHAR2,
                               p_error_code    OUT NUMBER,
                               p_error         OUT VARCHAR2) IS
    l_item_cost      cst_item_costs.item_cost%TYPE := NULL;
    l_item_id        po_lines_all.item_id%TYPE := NULL;
    l_ship_to_org_id po_line_locations_all.ship_to_organization_id%TYPE := NULL;
    l_po_header_id   po_headers_all.po_header_id%TYPE := NULL;
    l_po_type        po_headers_all.type_lookup_code%TYPE := NULL;
    l_po_cur_code    po_headers_all.currency_code%TYPE := NULL;
    l_fun_cur_code   po_headers_all.currency_code%TYPE := NULL;
    l_org_id         NUMBER;
    l_cur_conv_rate  NUMBER; -- Currency Conversion rate
    l_is_inv_item    VARCHAR2(1) := NULL;
    l_linked_amount  VARCHAR2(20) := NULL;
    l_from_uom       mtl_uom_conversions.uom_code%TYPE := NULL; --CHG0040109
    l_to_uom         po_lines_all.unit_meas_lookup_code%TYPE := NULL; --CHG0040109
    l_to_uom_code    mtl_uom_conversions.uom_code%TYPE := NULL; --CHG0040109
    l_uom_conv_rate  NUMBER := 1; --CHG0040109
  BEGIN
    p_error_code := 0;
    --Get Item Id
    SELECT pha.po_header_id,
           pha.type_lookup_code,
           pha.currency_code,
           pha.org_id,
           pla.item_id,
           plla.ship_to_organization_id,
           pla.attribute3, --PO Line Linked Amount
           (SELECT nvl(msi.inventory_item_flag, 'N')
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = plla.ship_to_organization_id
               AND msi.inventory_item_id = pla.item_id),
           pla.unit_meas_lookup_code --CHG0040109
      INTO l_po_header_id,
           l_po_type,
           l_po_cur_code,
           l_org_id,
           l_item_id,
           l_ship_to_org_id,
           l_linked_amount, --PO Line Linked Amount
           l_is_inv_item,
           l_to_uom --CHG0040109
      FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla
     WHERE pha.po_header_id = pla.po_header_id
       AND pla.po_line_id = plla.po_line_id
       AND pha.po_header_id = plla.po_header_id
       AND pla.po_line_id = p_po_line_id --513438
       AND rownum = 1; --If One Line Having multiple shipments, So Pick the 1st line
    --CHG0040109  Starts------------
    -------PO Line UOM code derivation----
    BEGIN
      SELECT uom_code
        INTO l_to_uom_code
        FROM mtl_uom_conversions
       WHERE unit_of_measure = l_to_uom;
    EXCEPTION
      WHEN OTHERS THEN
        l_to_uom_code := l_to_uom;
    END;
    --------Primary UOM code derive------------------
    BEGIN
      SELECT primary_uom_code
        INTO l_from_uom
        FROM mtl_system_items_b
       WHERE inventory_item_id = l_item_id
         AND organization_id = l_ship_to_org_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_from_uom := l_to_uom_code;
    END;
    -------Convert Item Cost to secondary UOM (Po Line UOM)-----
    IF l_from_uom != l_to_uom_code THEN
      l_uom_conv_rate := inv_convert.inv_um_convert(l_item_id,
                                                    l_from_uom,
                                                    l_to_uom_code);
      IF l_uom_conv_rate = -99999 THEN
        l_uom_conv_rate := 1;
      END IF;
    ELSE
      l_uom_conv_rate := 1;
    END IF;

    ------CHG0040109  Ends --------------------

    SELECT pb.currency_code
      INTO l_fun_cur_code
      FROM hr_operating_units hou, per_business_groups pb
     WHERE hou.business_group_id = pb.business_group_id
       AND hou.organization_id = l_org_id;

    /* Condition 4 in DFF
      There are cases when PO has been raised in ILS currency,
      however there is a currency linkage linked at the PO line level (DFF field),
      PO << 100053185>>. In such cases ?¿?¿¿?¿Std Material Cost?¿?¿¿?¿ field should populate the
      linked cost in USD and not the material cost (Frozen)
    */
    IF l_linked_amount IS NOT NULL THEN
      SELECT regexp_substr(l_linked_amount, '(\S*)', 1, 1)
        INTO p_item_cost
        FROM dual;

      SELECT regexp_substr(l_linked_amount, '(\S*)', 1, 3)
        INTO p_currency_code
        FROM dual;
      RETURN;
    END IF;

    --Get standard Item Cost in OU Currency
    IF l_item_id IS NOT NULL AND l_ship_to_org_id IS NOT NULL AND
       l_is_inv_item = 'Y' THEN
      l_item_cost := (xxinv_utils_pkg.get_item_material_cost(l_item_id,
                                                             l_ship_to_org_id)) /
                     l_uom_conv_rate; -- Nishant
    END IF;

    --If l_po_type in ( 'STANDARD' ,'BLANKET') Then
    /* Condition 6
    --In case the PO is of expense type, ?¿?¿¿?¿Std Material Cost?¿?¿¿?¿ value should hold the null value
     Case 01: PO line will doesn't have the item .. only description and category..
     Case 02: PO line has item.. but in the item is not inventory enabled.
    */
    IF l_item_id IS NULL OR l_is_inv_item = 'N' THEN
      p_item_cost     := NULL;
      p_currency_code := '';
      RETURN;
    END IF;

    /* Condition 3
      If the Functional Currency Code is not matching with PO Currency Code
      ?¿?¿¿?¿Std Material Cost?¿?¿¿?¿ will be shown in the PO Currency
    */
    IF l_fun_cur_code <> l_po_cur_code THEN
      --convert the Item Cost to PO Currency
      l_cur_conv_rate := gl_currency_api.get_closest_rate(x_from_currency   => l_fun_cur_code, --'ILS'
                                                          x_to_currency     => l_po_cur_code, --'USD'
                                                          x_conversion_date => SYSDATE,
                                                          x_conversion_type => 'Corporate',
                                                          x_max_roll_days   => 0);

      p_item_cost     := l_cur_conv_rate * l_item_cost;
      p_currency_code := l_po_cur_code;
      RETURN;
    END IF;

    /* Condition 2 in FDD
      In case of Standard PO, ?¿?¿¿?¿Std Material Cost?¿?¿¿?¿ value will be derived from
      the inventory ORG defined at the PO shipment level, based on the inventory
      organization, the Frozen Unit Cost will be picked and displayed under
      ?¿?¿¿?¿Std Material Cost?¿?¿¿?¿ field.
    */
    p_item_cost     := l_item_cost;
    p_currency_code := l_fun_cur_code;

  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error      := SQLERRM;
  END get_item_costforpo;
  --------------------------------------------------------------------
  --  name:            get_item_costForPO
  --  create by:       L.Sarangi
  --  Revision:        1.0
  --  creation date:   25/08/2016
  --------------------------------------------------------------------
  --  purpose :        retrieve Item Cost for PO Notification
  --                   This Item Cost will be displayed in the PO Approval Notification
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  25/08/2016  L.Sarangi       initial build
  --                                   CHG0038985 - Add item cost to Blanket/ standard PO approval notification
  --------------------------------------------------------------------
  FUNCTION get_item_costforpo(p_po_line_id po_lines_all.po_line_id%TYPE)
    RETURN VARCHAR2 IS

    l_item_cost     cst_item_costs.item_cost%TYPE := NULL;
    l_currency_code VARCHAR2(5);
    l_error_code    NUMBER;
    l_error         VARCHAR2(3000);
    l_po_line_id    po_lines_all.po_line_id%TYPE;
  BEGIN
    l_po_line_id := p_po_line_id;
    --Call get_item_costForPO Proc for Item Cost
    get_item_costforpo(p_po_line_id    => l_po_line_id, --In
                       p_item_cost     => l_item_cost, --Out
                       p_currency_code => l_currency_code, --Out
                       p_error_code    => l_error_code, --Out
                       p_error         => l_error --Out
                       );

    IF l_error_code = 0 AND l_item_cost IS NOT NULL THEN
      RETURN(to_char(l_item_cost, '999,999.99') || ' ' || l_currency_code);
    ELSIF l_item_cost IS NULL THEN
      RETURN '';
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN '';
  END;
END xxpo_utils_pkg;
/
