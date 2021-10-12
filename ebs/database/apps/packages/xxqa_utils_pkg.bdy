CREATE OR REPLACE PACKAGE BODY APPS.xxqa_utils_pkg IS
--------------------------------------------------------------------
--  name:            XXQA_UTILS_PKG
--  create by:       yuval tal
--  Revision:        1.0
--  creation date:   23/10/2012
--------------------------------------------------------------------
--  purpose :
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  23/10/2012  yuval tal       add populate_mof_cost_tables
--  1.1  17/03/2013  yuval tal       CUST655-CR701 :modify get_rfr_responsibility_from_mf
--                                   take the responsibility from MF and union by responsibility (Supplier/ SSYS).
--                                   Item Description at PO line contains: Job, Assy, Responsibility- Quantity.
-- 1.2  20/03/2013   yuval atl       CR 709 : ADD  get_rfr_responsibility_from_mf   the MF Responsibility count logic
-- 1.3  02/05/2013   yuval tal       CR751 : Change the MF Responsibility count - MRB Decision : modify function get_rfr_responsibility_from_mf
-- 1.4  25/11/2013   Vitaly          CT870 -- get_mf_cost added
-- 1.5  14/01/2014   Dalit A. Raviv  CR1246 procedure get_rfr_responsibility_from_mf modifications
-- 1.6  22/10/2014   Dalit A. Raviv  CHG0032720 - Copy Inspection results by supplier LOT
--                                   add 2 functions that will call by forms personalization
--                                   is_Insp_results_exists, get_Insp_results_per_lot
-- 1.5  15-May-2018  Hubert, Eric    CHG0042757: updated get_rfr_responsibility_from_mf to support DISPOSITION_IPK collection plan.
--------------------------------------------------------------------

  --------------------------------------------------------------
  -- Description: select mf cost
  -- Return: mf cost
  --------------------------------------------------------------
  FUNCTION get_mf_cost(p_mf_number VARCHAR2) RETURN NUMBER IS
    v_cost NUMBER;
  BEGIN
    IF p_mf_number IS NULL THEN
      RETURN NULL;
    END IF;
    SELECT SUM(decode(wip.transaction_uom,'HR',wip.transaction_quantity,
                      'MIN',wip.transaction_quantity / 60, 0) * wip.standard_resource_rate) cost
      INTO v_cost
      FROM wip_transactions_v wip, xxqa_header_malfunction_v h1
     WHERE wip.attribute1 = h1.malfunction_number
       AND h1.malfunction_number = p_mf_number; ---parameter
    RETURN(v_cost);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_mf_cost;

  --------------------------------------------------------------
  -- Description: Checks if a given plan already exists for a given MF Number.
  -- Return: 'Y' if exists, 'N' if does not exist.
  --------------------------------------------------------------
  FUNCTION is_plan_duplicate(p_mf_num VARCHAR2, p_plan_id NUMBER)
    RETURN VARCHAR2 IS
    v_ret VARCHAR2(1);

  BEGIN

    SELECT 'Y'
      INTO v_ret
      FROM qa_results
     WHERE character1 = p_mf_num
       AND plan_id = p_plan_id
       AND rownum < 2;

    RETURN v_ret;

  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_plan_duplicate;

  --------------------------------------------------------------
  -- Description: Checks if a given plan allowes multiple closing entries
  --              of the same type.
  -- Return: 'Y' if allows, 'N' if does not allow.
  --------------------------------------------------------------
  FUNCTION is_plan_allowes_duplicate(p_plan_id NUMBER) RETURN VARCHAR2 IS
    v_ret VARCHAR2(1);

  BEGIN

    SELECT attribute5
      INTO v_ret
      FROM qa_plans
     WHERE plan_id = p_plan_id
       AND rownum < 2;

    RETURN nvl(v_ret, 'N');

  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_plan_allowes_duplicate;

  -----------------------------------------------------------------------------------------------------------------

  FUNCTION get_work_hours(p_date_from     IN DATE,
                          p_date_to       IN DATE,
                          p_hours_per_day IN NUMBER) RETURN NUMBER IS

    v_num_of_work_hours NUMBER := 0;
    v_date              DATE;
    v_free_days         NUMBER := 0;
    v_count             NUMBER := 0;
    v_hours_first_day   NUMBER := 0;
    v_hours_last_day    NUMBER := 0;
    v_working_days      NUMBER := 0;
    missing_parameter EXCEPTION;
    wrong_parameter   EXCEPTION;

    l_first_work_hour CONSTANT NUMBER := 8;
    l_last_work_hour  CONSTANT NUMBER := 17;

  BEGIN

    IF p_date_from IS NULL OR p_date_to IS NULL OR p_hours_per_day IS NULL THEN
      RAISE missing_parameter;
    END IF;
    IF p_date_from > p_date_to OR p_hours_per_day <= 0 THEN
      RAISE wrong_parameter;
    END IF;

    IF trunc(p_date_from) = trunc(p_date_to) THEN

      v_hours_first_day := to_number(to_char(p_date_to, 'HH24')) -
                           to_number(to_char(p_date_from, 'HH24'));
      RETURN v_hours_first_day;

    END IF;

    SELECT l_last_work_hour - to_number(to_char(p_date_from, 'HH24'))
      INTO v_hours_first_day
      FROM dual;

    v_date := p_date_from + 1;

    LOOP

      IF trunc(v_date) >= trunc(p_date_to) THEN
        EXIT;
      END IF;

      v_count := v_count + 1;

      IF REPLACE(to_char(v_date, 'DAY'), ' ', '') IN ('FRIDAY', 'SATURDAY') THEN
        v_free_days := v_free_days + 1;

      END IF;

      IF v_count > 1000 THEN
        EXIT;
      END IF;
      v_date := v_date + 1;

    END LOOP;

    SELECT to_number(to_char(p_date_to, 'HH24')) - l_first_work_hour
      INTO v_hours_last_day
      FROM dual;

    v_working_days      := v_count - v_free_days;
    v_num_of_work_hours := (v_working_days * p_hours_per_day) +
                           v_hours_first_day + v_hours_last_day;

    RETURN(v_num_of_work_hours);

  EXCEPTION
    WHEN wrong_parameter THEN
      RETURN NULL;
    WHEN missing_parameter THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;

  END get_work_hours;

  ----------------------------------------------
  -- populate_mf_cost_tables
  ----------------------------------------------

  PROCEDURE populate_mf_cost_tables(p_err_code    OUT NUMBER,
                                    p_err_message OUT VARCHAR2) IS

    l_err_code NUMBER;

    l_err_message VARCHAR2(2000);
  BEGIN
    p_err_code := 0;
    DELETE FROM xxqa_mf_cost;
    COMMIT;
    INSERT INTO xxqa_mf_cost
      (mf_cost,
       item_cost,
       malfunction_number,
       decision,
       inventory_item_id,
       segment1,
       creation_date)
      SELECT mf_cost,
             item_cost,
             malfunction_number,
             decision,
             inventory_item_id,
             segment1,
             SYSDATE
        FROM xxqa_mf_cost_v;
    COMMIT;

    DELETE FROM xxqa_mf_system_cost;
    COMMIT;
    INSERT INTO xxqa_mf_system_cost
      (obj_serial_number,
       item_id,
       mf_cost,
       item_cost,
       malfunction_number,
       decision,
       creation_date)
      SELECT obj_serial_number,
             item_id,
             mf_cost,
             item_cost,
             malfunction_number,
             decision,
             SYSDATE
        FROM xxqa_mf_system_cost_v;
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
      xxobjt_wf_mail.send_mail_text(p_to_role => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),

                                    p_subject     => 'Error : Populate QA MF Temp Table',
                                    p_body_text   => 'Error : Populate QA MF Temp Table' ||
                                                     chr(10) ||
                                                     'xxqa_utils_pkg.populate_mf_cost_tables' ||
                                                     chr(10) || SQLERRM,
                                    p_err_code    => l_err_code,
                                    p_err_message => l_err_message);

  END;

  --------------------------------------------------------------------
  --  name:              get_rfr_responsibility_from_mf
  --  create by:         XX
  --  Revision:          1.0
  --  creation date:     XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   XX/XX/XXX     XXXX              Initial
  --  1.1   17/03/2013    yuval tal         CUST655-CR701 :modify get_rfr_responsibility_from_mf
  --                                        take the responsibility from MF and union by responsibility (Supplier/ SSYS).
  --                                        Item Description at PO line contains: Job, Assy, Responsibility- Quantity.
  --  1.2   20/03/2013    yuval atl         CR 709 : get_rfr_responsibility_from_mf  Change the MF Responsibility count logic
  --                                        concat resp
  --  1.3   02/05/2013    yuval tal         CUST655-CR751 : Change the MF Responsibility count - MRB Decision :
  --                                        modify logic function get_rfr_responsibility_from_mf
  --  1.4  14/01/2014     Dalit A. Raviv    CR1246 procedure get_rfr_responsibility_from_mf modifications
  --                                        get the responsibility from the MF for the RFR process not by dinamic sql.
  --  1.5  15-May-2018    Hubert, Eric      CHG0042757: Updated to support Disposition collection plans in any enabled org. 
  --                                        With the exception of the array, resp_arr, containing the responsibility and quantity,
  --                                        most of the function was rewritten due to the different collection plan structure used now. 
  --                                        The original function is commented-out, for reference, before the new version.
  --------------------------------------------------------------------
  --CHG0042757--  FUNCTION get_rfr_responsibility_from_mf(p_wip_entity_id NUMBER)
  --CHG0042757--    RETURN VARCHAR2 IS
  --CHG0042757--
  --CHG0042757--    CURSOR c_mf IS
  --CHG0042757--      SELECT wdj.attribute4,
  --CHG0042757--             wdj.attribute5,
  --CHG0042757--             wdj.attribute6,
  --CHG0042757--             wdj.attribute7,
  --CHG0042757--             wdj.attribute8
  --CHG0042757--        FROM wip_discrete_jobs wdj
  --CHG0042757--       WHERE wdj.wip_entity_id = p_wip_entity_id;
  --CHG0042757--
  --CHG0042757--    -- 1.4 14/01/2014 Dalit A. Raviv
  --CHG0042757--    cursor p ( p_att4 in varchar2,
  --CHG0042757--               p_att5 in varchar2,
  --CHG0042757--               p_att6 in varchar2,
  --CHG0042757--               p_att7 in varchar2,
  --CHG0042757--               p_att8 in varchar2)  is
  --CHG0042757--      SELECT t.responsibility, t.plan_id, t.collection_id, t.occurrence
  --CHG0042757--      from q_mrb_decision_v t
  --CHG0042757--      where mf_number in (p_att4,p_att5,p_att6,p_att7,p_att8)
  --CHG0042757--      union all
  --CHG0042757--      select t.responsibility, t.plan_id, t.collection_id, t.occurrence
  --CHG0042757--      from q_old_mrb_decision_v t
  --CHG0042757--      where mf_number in (p_att4,p_att5,p_att6,p_att7,p_att8);
  --CHG0042757--
  --CHG0042757--    TYPE resp_arr IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
  --CHG0042757--
  --CHG0042757--    l_resp_arr resp_arr;
  --CHG0042757--    l_resp_str VARCHAR2(2000);
  --CHG0042757--    l_key      VARCHAR2(50);
  --CHG0042757--
  --CHG0042757--  BEGIN
  --CHG0042757--    /*  dbms_output.put_line('p_wip_entity_id=' || p_wip_entity_id);
  --CHG0042757--    dbms_output.put_line('----------------------------');*/
  --CHG0042757--    l_resp_arr.delete;
  --CHG0042757--    -- get all mf_number
  --CHG0042757--    for j in c_mf loop
  --CHG0042757--      ---
  --CHG0042757--      declare
  --CHG0042757--        c_qty sys_refcursor;
  --CHG0042757--        l_responsibility       varchar2(50);
  --CHG0042757--        l_plan_id              number;
  --CHG0042757--        l_collection_id        number;
  --CHG0042757--        l_occurrence           number;
  --CHG0042757--        l_parent_plan_id       number;
  --CHG0042757--        l_parent_collection_id number;
  --CHG0042757--        l_parent_occurrence    number;
  --CHG0042757--        l_view_name            varchar2(150);
  --CHG0042757--        l_quantity             number;
  --CHG0042757--      begin
  --CHG0042757--        -- find details and responsibility  for all MF
  --CHG0042757--        -- 1.4 14/01/2014 Dalit A. Raviv
  --CHG0042757--        for p_r in p (j.attribute4, j.attribute5, j.attribute6, j.attribute7, j.attribute8) loop
  --CHG0042757--          l_responsibility := p_r.responsibility;
  --CHG0042757--          l_plan_id        := p_r.plan_id;
  --CHG0042757--          l_collection_id  := p_r.collection_id;
  --CHG0042757--          l_occurrence     := p_r.occurrence;
  --CHG0042757--          -- end 1.4 14/01/2014
  --CHG0042757--          -- set responsibility as key in array
  --CHG0042757--          if not l_resp_arr.exists(l_responsibility) then
  --CHG0042757--            l_resp_arr(l_responsibility) := 0;
  --CHG0042757--          end if;
  --CHG0042757--
  --CHG0042757--          -- get quantity  process
  --CHG0042757--          -- add quantitiy to hash table according to key(responsibility)
  --CHG0042757--          -- find parent
  --CHG0042757--          select qr.parent_plan_id,
  --CHG0042757--                 qr.parent_collection_id,
  --CHG0042757--                 qr.parent_occurrence
  --CHG0042757--            into l_parent_plan_id,
  --CHG0042757--                 l_parent_collection_id,
  --CHG0042757--                 l_parent_occurrence
  --CHG0042757--            from qa_pc_results_relationship qr
  --CHG0042757--           where qr.child_plan_id = l_plan_id
  --CHG0042757--             and qr.child_collection_id = l_collection_id
  --CHG0042757--             and qr.child_occurrence = l_occurrence;
  --CHG0042757--
  --CHG0042757--          -- get parent view
  --CHG0042757--          select p.view_name
  --CHG0042757--            into l_view_name
  --CHG0042757--            from qa_plans p
  --CHG0042757--           where p.plan_id = l_parent_plan_id;
  --CHG0042757--
  --CHG0042757--          -- get qauntity from parent
  --CHG0042757--          -- add to resp array
  --CHG0042757--          -- dynamic select qty from view
  --CHG0042757--          if l_view_name in ( 'Q_BADAS_RECEIVING_MF_V','Q_OLD_BADAS_RECEIVING_MF_V' ) then
  --CHG0042757--            l_resp_arr(l_responsibility) := l_resp_arr(l_responsibility) + 1;
  --CHG0042757--          else
  --CHG0042757--            open c_qty for 'select quantityn from ' || l_view_name || ' where collection_id = :1  AND occurrence = :2  AND plan_id = :3'
  --CHG0042757--            using l_parent_collection_id, l_parent_occurrence, l_parent_plan_id;
  --CHG0042757--
  --CHG0042757--            fetch c_qty into l_quantity;
  --CHG0042757--            l_resp_arr(l_responsibility) := l_resp_arr(l_responsibility) + l_quantity;
  --CHG0042757--            close c_qty;
  --CHG0042757--          end if;
  --CHG0042757--          ----
  --CHG0042757--        end loop;
  --CHG0042757--      end;
  --CHG0042757--    end loop; -- mf numbers
  --CHG0042757--
  --CHG0042757--    ---- concat all resp and quantity
  --CHG0042757--    l_key := l_resp_arr.first;
  --CHG0042757--
  --CHG0042757--    loop exit when l_key is null;
  --CHG0042757--      l_resp_str := l_resp_str || l_key || '=' || l_resp_arr(l_key) || '  ';
  --CHG0042757--      l_key      := l_resp_arr.next(l_key);
  --CHG0042757--    end loop;
  --CHG0042757--
  --CHG0042757--    return l_resp_str;
  --CHG0042757--  exception
  --CHG0042757--    when others then
  --CHG0042757--      return 'Failure during RFR Responsibility description generaiton';
  --CHG0042757--  end get_rfr_responsibility_from_mf;
  
  FUNCTION get_rfr_responsibility_from_mf(p_wip_entity_id NUMBER) RETURN VARCHAR2 IS
    
    TYPE resp_arr IS TABLE OF NUMBER INDEX BY VARCHAR2(50);

    c_dispositions sys_refcursor;

    /* Defined variables used for results returned by refernce cursor. */
    l_job_number VARCHAR2(240);
    l_job_dff_4 VARCHAR2(150);
    l_job_dff_5 VARCHAR2(150);
    l_job_dff_6 VARCHAR2(150);
    l_job_dff_7 VARCHAR2(150);
    l_job_dff_8 VARCHAR2(150);
    l_org_id NUMBER;
    l_disposition_number  VARCHAR2(50);
    l_quantity NUMBER;
    l_responsibility VARCHAR2(150);

    /* Variables related to the dynamic SQL to get disposition details from an arbitrary disposition collection plan. */
    l_org_code VARCHAR2(3); 
    l_view_name  VARCHAR2(150); --Results view for a collection plan
    l_dynamic_sql VARCHAR2(2000) := '/* Return all Quality Dispositions where the Disposition Number exists in one of the five related Discrete Job DFFs. */
        SELECT 
            we.wip_entity_name,
            wdj.attribute4,
            wdj.attribute5,
            wdj.attribute6,
            wdj.attribute7,
            wdj.attribute8,
            wdj.organization_id,
            div.xx_disposition_number,
            div.xx_quantity_dispositioned,
            div.xx_responsibility_general
        FROM wip_entities we
        INNER JOIN wip_discrete_jobs wdj ON (we.wip_entity_id = wdj.wip_entity_id)
        INNER JOIN {P_VIEW_NAME} div ON (div.xx_disposition_number IN (wdj.attribute4, wdj.attribute5, wdj.attribute6, wdj.attribute7, wdj.attribute8))
        WHERE wdj.wip_entity_id = :p_wip_entity_id';

    /* Variables related to storing the dispositions' responsibility and quantity values. */
    l_resp_arr resp_arr;
    l_resp_str VARCHAR2(2000);
    l_key      VARCHAR2(50);

  BEGIN
    l_resp_arr.delete;

    /* Construct the org-specific results view for the Disposition plan.
       Note for future improvement: a better way to get the vie wname is to call xxqa_nc_rpt_pkg.collection_plan_view_name.  However, this function is currently private in that package and outside the scope of CHG0042757.*/
    SELECT xxinv_utils_pkg.get_org_code(organization_id) INTO l_org_code FROM wip_entities WHERE wip_entity_id = p_wip_entity_id;
    l_view_name := 'Q_DISPOSITION_' || l_org_code || '_V'; --By Stratasys naming convention, we use the org code in each collection plan name.
    l_dynamic_sql:= REPLACE(l_dynamic_sql, '{P_VIEW_NAME}', l_view_name); --Replace the token with org-specific view name
    --dbms_output.put_line('DEBUG l_dynamic_sql: ' || l_dynamic_sql);

    /* Execute the dynamic SQL statement to return all of the dispositions for the discrete job. */
    OPEN c_dispositions FOR l_dynamic_sql USING p_wip_entity_id;  --Check for the Disposition (MF) number in each of the five DFF columns.

    LOOP
        FETCH c_dispositions INTO
            l_job_number,
            l_job_dff_4,
            l_job_dff_5,
            l_job_dff_6,
            l_job_dff_7,
            l_job_dff_8,
            l_org_id,
            l_disposition_number,
            l_quantity,
            l_responsibility;
        
        EXIT WHEN c_dispositions%NOTFOUND;

        IF NOT l_resp_arr.exists(l_responsibility) THEN
            l_resp_arr(l_responsibility) := 0;
        END IF;
        l_resp_arr(l_responsibility) := l_resp_arr(l_responsibility) + l_quantity;
    END LOOP;
    
    CLOSE c_dispositions;
 
    ---- Concatenate  all responsibilities and quantities
    l_key := l_resp_arr.first;

    LOOP EXIT WHEN l_key IS NULL;
        l_resp_str := l_resp_str || l_key || '=' || l_resp_arr(l_key) || '  ';
        l_key      := l_resp_arr.next(l_key);
    END LOOP;

    RETURN l_resp_str;
    EXCEPTION
    
    WHEN OTHERS THEN
        RETURN 'Failure during RFR Responsibility description generation';
  END get_rfr_responsibility_from_mf;

  --------------------------------------------------------------------
  --  name:              is_Insp_results_exists
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     20/10/2014
  --------------------------------------------------------------------
  --  purpose :          CHG0032720 - Copy Inspection results by supplier LOT
  --------------------------------------------------------------------
  --  ver   date         name              desc
  --  1.0   20/10/2014   Dalit A. Raviv    Initial
  --------------------------------------------------------------------
  function is_Insp_results_exists (p_plan_id          in  number,
                                   p_organization_id  in  number,
                                   p_suplier_lot      in  varchar2,
                                   p_num_of_days      in  number) return varchar2 is
    l_count number := 0;

  begin
    select count(1)
    into   l_count
    from   qa_results         qr
    where  qr.plan_id         = p_plan_id         -- 18143 INCOMING INSPECTION IRK
    and    qr.organization_id = p_organization_id -- 734 IRK
    and    qr.creation_date   >= sysdate - p_num_of_days -- Search for 2 month back
    and    qr.character1      = p_suplier_lot;    -- '20140410-14/08/2014'

    if nvl(l_count,0) > 0 then
      return 'Y';
    else
      return 'N';
    end if;
  exception
    when others then
      return 'N';
  end is_Insp_results_exists;

  --------------------------------------------------------------------
  --  name:              get_Insp_results_per_lot
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     20/10/2014
  --------------------------------------------------------------------
  --  purpose :          CHG0032720 - Copy Inspection results by supplier LOT
  --                     by the entity return different feild details.
  --------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   20/10/2014    Dalit A. Raviv    Initial
  --------------------------------------------------------------------
  function get_Insp_results_per_lot (p_plan_id          in  number,
                                     p_organization_id  in  number,
                                     p_suplier_lot      in  varchar2,
                                     p_entity           in  varchar2,
                                     p_num_of_days      in  number) return varchar2 is

    l_character2        varchar2(150);
    l_character4        varchar2(150);
    l_transaction_date  date;
    l_character5        varchar2(150);
    l_character6        varchar2(150);
    l_character7        varchar2(150);
    l_character8        varchar2(150);
    l_character9        varchar2(150);
    l_character10       varchar2(150);
    l_character11       varchar2(150);
    l_character12       varchar2(150);

  begin
    select qr.character2,     -- Expiration date
           qr.character4,     -- Inspector name
           qr.transaction_date, -- Inspection date
           qr.character5,     -- COA
           qr.character6,     -- Viscosity COA
           qr.character7,     -- Viscosity Actual
           qr.character8,     -- Polimer Content
           qr.character9,     -- MESH
           qr.character10,    -- Appearance
           qr.character11,    -- Objet Inhibitor
           qr.character12     -- Inspection Results
    into   l_character2,
           l_character4,
           l_transaction_date,
           l_character5,
           l_character6,
           l_character7,
           l_character8,
           l_character9,
           l_character10,
           l_character11,
           l_character12
    from   qa_results         qr
    where  qr.plan_id         = p_plan_id         -- 18143 INCOMING INSPECTION IRK
    and    qr.organization_id = p_organization_id -- 734 IRK
    and    qr.creation_date   >= sysdate - p_num_of_days -- Search for 2 month back
    and    qr.character1      = p_suplier_lot     -- '20140410-14/08/2014'
    and    qr.creation_date   = (select max(creation_date)
                                 from   qa_results         qr
                                 where  qr.plan_id         = p_plan_id         -- 18143 INCOMING INSPECTION IRK
                                 and    qr.organization_id = p_organization_id -- 734 IRK
                                 and    qr.creation_date   >= sysdate - p_num_of_days -- Search for 2 month back
                                 and    qr.character1      = p_suplier_lot);

    if p_entity = 'EXP_DATE' then
      return l_character2;
    elsif p_entity = 'INSP_NAME' then
      return l_character4;
    elsif p_entity = 'TRX_DATE' then
      return to_char(l_transaction_date,'DD-MON-YYYY HH24:MI:SS');
    elsif p_entity = 'COA' then
      return l_character5;
    elsif p_entity = 'VISC_COA' then
      return l_character6;
    elsif p_entity = 'VISC_ACT' then
      return l_character7;
    elsif p_entity = 'POLI_CONT' then
      return l_character8;
    elsif p_entity = 'MESH' then
      return l_character9;
    elsif p_entity = 'APPEAR' then
      return l_character10;
    elsif p_entity = 'OBJ_INHIBIT' then
      return l_character11;
    elsif p_entity = 'RESULTS' then
      return l_character12;
    end if;
  exception
    when others then
      return null;
  end get_Insp_results_per_lot;

end xxqa_utils_pkg;
/