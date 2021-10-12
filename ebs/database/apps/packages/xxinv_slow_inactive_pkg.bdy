create or replace package body xxinv_slow_inactive_pkg IS
  ----------------------------------------------------------------------
  --  name:            XXINV_SLOW_INACTIVE_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/02/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/02/2014  Dalit A. Raviv    initial build
  --  1.1  28/10/2014  M. Mazanet        CHG0033075. Originally, this program was only gathering
  --                                     non-FDM items.  The program has been modified to get
  --                                     FDM items as well.  Calculations are the same, except that
  --                                     FDM does NOT have special handling for spare parts and
  --                                     resin items, which non-FDM does.  The following additional
  --                                     columns were added to xxinv_slow_inactive table, and need to
  --                                     be populated: technology, item_type, item_us_cost, and
  --                                     plan_name_fdm.  Added p_fdm_plan_name and p_fdm_cost_org_id
  --                                     parameters.
  -- 1.2  16/05/2017 Lingaraj Sarangi    INC0090114 - Item cost
  -- 1.3  11/03/2019   Roman W           CHG0047100/CHG0045289 added 'PARTIALLY RECEIVED' to in transit population   
  --------------------------------------------------------------------
  g_user_id                 NUMBER := nvl(fnd_profile.value('USER_ID'),
                                          2470);
  g_creation_date           DATE := SYSDATE;
  g_active_months           NUMBER;
  g_slow_months             NUMBER;
  g_sp_active_months        NUMBER;
  g_sp_slow_months          NUMBER;
  g_plan_name_resin         VARCHAR2(150);
  g_plan_name_none_resin    VARCHAR2(150);
  g_plan_name_fdm           VARCHAR2(150);
  g_keep_history_days       NUMBER;
  g_planning_period         NUMBER;
  g_slow_age_y_n            VARCHAR2(10);
  g_slow_cutoff_date        DATE;
  g_slow_till_cutof_qty     NUMBER;
  g_avg_demand_end_plan_qty NUMBER;
  -- CHG0033075
  g_log        VARCHAR2(10) := fnd_profile.value('AFLOG_ENABLED');
  g_log_module VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');

  TYPE t_slow_inactive_rec IS RECORD(
    inventory_item_id       NUMBER,
    technology              VARCHAR2(25),
    item_type               VARCHAR2(25),
    oh_quantity             NUMBER,
    active_demand           NUMBER,
    slow_demand             NUMBER,
    active_qty              NUMBER,
    slow_qty                NUMBER,
    slow_till_cutof_qty     NUMBER,
    avg_demand_end_plan_qty NUMBER,
    inactive_qty            NUMBER,
    item_is_sp              VARCHAR2(20),
    item_status             VARCHAR2(150),
    item_il_cost            NUMBER,
    item_us_cost            NUMBER,
    active_months           NUMBER,
    slow_months             NUMBER,
    sp_active_months        NUMBER,
    sp_slow_months          NUMBER,
    plan_name_resin         VARCHAR2(150),
    plan_name_none_resin    VARCHAR2(150),
    plan_name_fdm           VARCHAR2(150),
    keep_history_days       NUMBER,
    slow_age_y_n            VARCHAR2(10),
    planning_period         NUMBER,
    slow_cutoff_date        DATE);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  10/22/2014  MMAZANET    Initial Creation for CHG0033075.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE dbg(p_msg VARCHAR2) IS
  BEGIN
    IF g_log = 'Y' AND 'xxinv_slow_inactive.xxinv_slow_inactive_pkg' LIKE
       LOWER(g_log_module) THEN
      fnd_file.put_line(fnd_file.log, p_msg);
    END IF;
  END dbg;

  --------------------------------------------------------------------
  --  name:            delete_temp_tbl
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/03/2014 14:43:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --                   delete temp table and keep only XX days back (parameter).
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/02/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE delete_temp_tbl(errbuf              OUT VARCHAR2,
                            retcode             OUT VARCHAR2,
                            p_keep_history_days IN NUMBER) IS -- 180
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    DELETE xxobjt.xxinv_slow_inactive xsi
     WHERE xsi.creation_date < SYSDATE - p_keep_history_days;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen Exc - delete_temp_tbl ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END delete_temp_tbl;

  --------------------------------------------------------------------
  --  name:            insert_temp_tbl
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/02/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --                   populate temp table that the report will retrieve the data from.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/02/2014  Dalit A. Raviv    initial build
  --  1.1  29/10/2014  M. Mazanet        Added the following columns to the INSERT below
  --                                     technology, item_type, item_us_cost, and
  --                                     plan_name_fdm
  --------------------------------------------------------------------
  PROCEDURE insert_temp_tbl(errbuf            OUT VARCHAR2,
                            retcode           OUT VARCHAR2,
                            p_request_id      IN NUMBER,
                            p_slow_inactive_r IN t_slow_inactive_rec) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    --    slow_qty                 number,
    --  slow_till_cutof_qty      number,
    --  inactive_qty             number,
  
    INSERT INTO xxobjt.xxinv_slow_inactive
      (batch_id, --  n
       entity_id, --  n
       inventory_item_id, --  n
       technology,
       item_type,
       oh_quantity, --  n
       demand_active, --  n
       demand_slow, --  n
       active_qty, --  n
       slow_qty, --  n
       slow_till_cutof_qty, --  n
       avg_demand_end_plan_qty, -- n
       inactive_qty, --  n
       item_is_sp, --  v20
       item_status, --  v150
       item_il_cost, --  n
       item_us_cost,
       active_months, --  n
       slow_months, --  n
       sp_active_months, --  n
       sp_slow_months, --  n
       plan_name_resin, --  v150
       plan_name_none_resin, --  v150
       plan_name_fdm,
       keep_history_days, --  n
       slow_age_y_n, --  v10
       planning_period, --  n
       slow_cutoff_date, --  d
       last_update_date, --  d
       last_updated_by, --  n
       last_update_login, --  n
       creation_date, --  d
       created_by) --  n
    VALUES
      (p_request_id,
       xxinv_slow_inactive_s.nextval,
       p_slow_inactive_r.inventory_item_id,
       p_slow_inactive_r.technology,
       p_slow_inactive_r.item_type,
       p_slow_inactive_r.oh_quantity,
       p_slow_inactive_r.active_demand,
       p_slow_inactive_r.slow_demand,
       p_slow_inactive_r.active_qty,
       p_slow_inactive_r.slow_qty,
       p_slow_inactive_r.slow_till_cutof_qty,
       p_slow_inactive_r.avg_demand_end_plan_qty,
       p_slow_inactive_r.inactive_qty,
       p_slow_inactive_r.item_is_sp,
       p_slow_inactive_r.item_status,
       p_slow_inactive_r.item_il_cost,
       p_slow_inactive_r.item_us_cost,
       g_active_months,
       g_slow_months,
       g_sp_active_months,
       g_sp_slow_months,
       g_plan_name_resin,
       g_plan_name_none_resin,
       g_plan_name_fdm,
       g_keep_history_days,
       g_slow_age_y_n,
       g_planning_period,
       g_slow_cutoff_date,
       g_creation_date,
       g_user_id,
       -1,
       g_creation_date,
       g_user_id);
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Gen Exc - insert_temp_tbl ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END insert_temp_tbl;

  --------------------------------------------------------------------
  --  name:            get_total_demand_by_item
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/02/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --                   function that get the demand per item
  --                   This function return the demand only for non - spare part items
  --  in params:
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/02/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_total_demand_by_item(p_inventory_item_id IN NUMBER,
                                    p_plan_name         IN VARCHAR2,
                                    p_from_date         IN DATE,
                                    p_to_date           IN DATE,
                                    p_entity            IN VARCHAR2,
                                    p_slow_months       IN NUMBER,
                                    p_active_months     IN NUMBER,
                                    p_planning_period   IN NUMBER,
                                    p_curr_start_date   IN DATE)
    RETURN NUMBER IS
  
    l_qty_rate NUMBER := NULL;
  
  BEGIN
    IF p_entity = 'ACTIVE' THEN
      SELECT nvl(SUM(quantity_rate), 0) quantity_rate
        INTO l_qty_rate
        FROM (SELECT quantity_rate
                FROM xxinv_total_demand_by_item_v v
               WHERE v.inventory_item_id = p_inventory_item_id
                 AND compile_designator = p_plan_name
                 AND new_due_date BETWEEN p_from_date AND p_to_date -- date of active
              );
    
      RETURN abs(l_qty_rate);
    ELSE
      -- p_entity = 'SLOW'
      -- if cut of date exists between from date and to date it means that the slow qty will not calculate correct,
      -- it can return ziro (0) at most cases.
      -- in this case the slow qty will be calculate according to the cut of date
      -- cutoff_date - 6 months till cutoff date -> the qty found need to divide by 6 (qty per 1 month)
      -- and then to sprade it on all slow period (it can be several months
    
      g_slow_cutoff_date := (add_months(trunc(p_curr_start_date),
                                        p_planning_period)) + 1; -- p_curr_start_date instad of sysdate
    
      IF ( /*g_slow_cutoff_date >= p_from_date and*/
          g_slow_cutoff_date <= p_to_date) THEN
        g_slow_age_y_n := 'Y';
        SELECT nvl(SUM(quantity_rate), 0) quantity_rate
          INTO l_qty_rate
          FROM (SELECT quantity_rate
                  FROM xxinv_total_demand_by_item_v v
                 WHERE v.inventory_item_id = p_inventory_item_id
                   AND compile_designator = p_plan_name
                   AND new_due_date BETWEEN
                       add_months(g_slow_cutoff_date, -6) AND
                       g_slow_cutoff_date);
      
        --l_qty_rate := l_qty_rate * abs(p_slow_months - p_active_months );
        g_avg_demand_end_plan_qty := abs(l_qty_rate / 6);
        l_qty_rate                := abs(((l_qty_rate / 6) *
                                         (abs(p_slow_months -
                                               p_active_months))));
      
        -- Handle slow_till_cutof_qty
        -- in this case - customer want to know what is the qty between slow from datre to cutoff date
        SELECT nvl(SUM(quantity_rate), 0) quantity_rate
          INTO g_slow_till_cutof_qty
          FROM (SELECT quantity_rate
                  FROM xxinv_total_demand_by_item_v v
                 WHERE v.inventory_item_id = p_inventory_item_id
                   AND compile_designator = p_plan_name
                   AND new_due_date BETWEEN p_from_date AND
                       g_slow_cutoff_date);
      
      ELSE
        -- cutoff date is not in slow period - calculate the qty as it is in slow period.
        g_slow_age_y_n        := 'N';
        g_slow_till_cutof_qty := NULL;
        SELECT nvl(SUM(quantity_rate), 0) quantity_rate
          INTO l_qty_rate
          FROM (SELECT quantity_rate
                  FROM xxinv_total_demand_by_item_v v
                 WHERE v.inventory_item_id = p_inventory_item_id
                   AND compile_designator = p_plan_name
                   AND new_due_date BETWEEN p_from_date AND p_to_date);
      
        ---  to add g
      END IF; -- dates of calaulate slow qty
    
      RETURN abs(l_qty_rate);
    END IF; -- Active/ Slow
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
    
  END get_total_demand_by_item;

  --------------------------------------------------------------------
  --  name:            get_total_demand_by_item
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/02/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --                   function that get the demand per item
  --                   This function return the demand only for non - spare part items
  --  in params:
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/02/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_sp_demand_by_item(p_inventory_item_id IN NUMBER) RETURN NUMBER IS
    l_sp_demand_qty NUMBER;
  BEGIN
    SELECT CASE
             WHEN a_view.inventory_item_status_code_tl = 'Discontinued' THEN
              0
             WHEN a_view.inventory_item_status_code_tl = 'Phase Out' THEN
              nvl(SUM(a_view.max_minmax_quantity), 0) * 0.25
             ELSE
              nvl(SUM(a_view.max_minmax_quantity), 0)
           END sp_demand_qty
      INTO l_sp_demand_qty
      FROM (SELECT SUM(msi.max_minmax_quantity) max_minmax_quantity,
                   msi.inventory_item_id,
                   s.inventory_item_status_code_tl
              FROM mtl_system_items_b msi, mtl_item_status s
             WHERE 1 = 1
               AND xxinv_item_classification.is_item_sp(msi.inventory_item_id) = 'Y'
                  --and    xxinv_item_classification.is_spec_19(msi.inventory_item_id) = 'Y'
               AND msi.max_minmax_quantity IS NOT NULL
               AND msi.inventory_item_id = p_inventory_item_id -- 15780--14610
               AND s.inventory_item_status_code =
                   msi.inventory_item_status_code
             GROUP BY msi.inventory_item_id, s.inventory_item_status_code_tl) a_view
     WHERE inventory_item_id = p_inventory_item_id --15780
     GROUP BY inventory_item_id, inventory_item_status_code_tl;
  
    RETURN(l_sp_demand_qty);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_sp_demand_by_item;

  --------------------------------------------------------------------
  --  name:            get_item_status
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/02/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/02/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_item_status(p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS
    l_status VARCHAR2(150) := NULL;
  BEGIN
    SELECT s.inventory_item_status_code_tl
      INTO l_status
      FROM mtl_system_items_b msi, mtl_item_status s
     WHERE msi.inventory_item_id = p_inventory_item_id --14610
       AND s.inventory_item_status_code = msi.inventory_item_status_code
       AND msi.organization_id = 91;
  
    RETURN l_status;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_item_status;

  --------------------------------------------------------------------
  --  name:            get_irk_wip_supply_type
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/06/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_irk_wip_supply_type(p_inventory_item_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_wip_supply_type VARCHAR2(150) := NULL;
  BEGIN
    SELECT l.meaning
      INTO l_wip_supply_type
      FROM mtl_system_items_b msi, fnd_lookup_values l
     WHERE msi.inventory_item_id = p_inventory_item_id
       AND msi.organization_id = 734 -- IRK
       AND msi.wip_supply_type = l.lookup_code
       AND l.lookup_type = 'WIP_SUPPLY'
       AND l.language = 'US';
  
    RETURN l_wip_supply_type;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_irk_wip_supply_type;

  --------------------------------------------------------------------
  --  name:            get_ipk_wip_supply_type
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/06/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_ipk_wip_supply_type(p_inventory_item_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_wip_supply_type VARCHAR2(150) := NULL;
  BEGIN
    SELECT l.meaning
      INTO l_wip_supply_type
      FROM mtl_system_items_b msi, fnd_lookup_values l
     WHERE msi.inventory_item_id = p_inventory_item_id
       AND msi.organization_id = 735 -- IPK
       AND msi.wip_supply_type = l.lookup_code
       AND l.lookup_type = 'WIP_SUPPLY'
       AND l.language = 'US';
  
    RETURN l_wip_supply_type;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_ipk_wip_supply_type;

  --------------------------------------------------------------------
  --  name:            get_irk_safety_stock
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/06/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_irk_safety_stock(p_inventory_item_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_safety_stock_quantity VARCHAR2(150) := NULL;
  BEGIN
    SELECT mss.safety_stock_quantity
      INTO l_safety_stock_quantity
      FROM mtl_safety_stocks mss
     WHERE mss.inventory_item_id = p_inventory_item_id
       AND mss.organization_id = 734; -- IRK
  
    RETURN l_safety_stock_quantity;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_irk_safety_stock;

  --------------------------------------------------------------------
  --  name:            get_ipk_safety_stock
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/06/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_ipk_safety_stock(p_inventory_item_id IN NUMBER)
    RETURN VARCHAR2 IS
  
    l_safety_stock_quantity VARCHAR2(150) := NULL;
  BEGIN
    SELECT mss.safety_stock_quantity
      INTO l_safety_stock_quantity
      FROM mtl_safety_stocks mss
     WHERE mss.inventory_item_id = p_inventory_item_id
       AND mss.organization_id = 735; -- IPK
  
    RETURN l_safety_stock_quantity;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_ipk_safety_stock;

  --------------------------------------------------------------------
  --  name:            get_irk_minqty
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/06/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_irk_minqty(p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_minqty VARCHAR2(150) := NULL;
  BEGIN
    SELECT msi.min_minmax_quantity
      INTO l_minqty
      FROM mtl_system_items_b msi
     WHERE msi.inventory_item_id = p_inventory_item_id
       AND msi.organization_id = 734; -- IRK
  
    RETURN l_minqty;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_irk_minqty;

  --------------------------------------------------------------------
  --  name:            get_ipk_minqty
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/06/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_ipk_minqty(p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_minqty VARCHAR2(150) := NULL;
  BEGIN
    SELECT msi.min_minmax_quantity
      INTO l_minqty
      FROM mtl_system_items_b msi
     WHERE msi.inventory_item_id = p_inventory_item_id
       AND msi.organization_id = 735; -- IPK
  
    RETURN l_minqty;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_ipk_minqty;

  --------------------------------------------------------------------
  --  name:            get_irk_maxqty
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/06/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_irk_maxqty(p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_maxqty VARCHAR2(150) := NULL;
  BEGIN
    SELECT msi.max_minmax_quantity
      INTO l_maxqty
      FROM mtl_system_items_b msi
     WHERE msi.inventory_item_id = p_inventory_item_id
       AND msi.organization_id = 734; -- IRK
  
    RETURN l_maxqty;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_irk_maxqty;

  --------------------------------------------------------------------
  --  name:            get_ipk_maxqty
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/06/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   CHG0031515  Slow Inactive report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_ipk_maxqty(p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_maxqty VARCHAR2(150) := NULL;
  BEGIN
    SELECT msi.max_minmax_quantity
      INTO l_maxqty
      FROM mtl_system_items_b msi
     WHERE msi.inventory_item_id = p_inventory_item_id
       AND msi.organization_id = 735; -- IPK
  
    RETURN l_maxqty;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_ipk_maxqty;

  --------------------------------------------------------------------
  --  name:            get_us_std_cost
  --  create by:       M. Mazanet
  --  Revision:        1.0
  --  creation date:   28/10/2014
  --------------------------------------------------------------------
  --  purpose :   Calculates US standard cost based on the Frozen
  --              cost type for UME (739).  If Frozen cost can not be
  --              found, we return 0.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/02/2014  mmazanet     CHG0033075 initial build
  --------------------------------------------------------------------
  FUNCTION get_us_std_cost(p_inventory_item_id IN NUMBER,
                           p_fdm_cost_org_id   IN NUMBER) RETURN NUMBER IS
    l_us_std_cost NUMBER := 0;
  BEGIN
    SELECT item_cost
      INTO l_us_std_cost
      FROM cst_item_cost_type_v
     WHERE inventory_item_id = p_inventory_item_id
       AND organization_id = p_fdm_cost_org_id
       AND cost_type = 'Frozen';
  
    RETURN l_us_std_cost;
  EXCEPTION
    WHEN OTHERS THEN
      dbg('Error in get_us_std_cost ' || DBMS_UTILITY.FORMAT_ERROR_STACK);
      RETURN 0;
  END get_us_std_cost;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/02/2014 14:19:38
  --------------------------------------------------------------------
  --  purpose :        REP485 - INV allocation by product family\CR382- Slow_Inactive
  --                   Procedure that handel main program that calculate for all on-hand items
  --                   by the demand, if it is active, slow or inactive.
  --
  --  in params:       p_active_months    - number of months to calculate the demand for active
  --                   p_slow_months      - number of months to calculate the demand for slow
  --                   p_sp_active_months - number of months to calculate the demand for SP active
  --                   p_sp_slow_months   - number of months to calculate the demand for SP slow
  --                   retcode            - 0    success other fialed
  --                   errbuf             - null success other fialed
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/02/2014  Dalit A. Raviv    initial build
  --  1.1  10/29/2014  M. Mazanet        CHG0033075.  The program has been modified to get
  --                                     FDM items as well.  Calculations are the same, except that
  --                                     FDM does NOT have special handling for spare parts and
  --                                     resin items, which non-FDM does.  Added p_fdm_plan_name
  --                                     and p_fdm_cost_org_id parameters.
  -- 1.2  16/05/2017   Lingaraj Sarangi    INC0090114 - Item cost
  -- 1.3  11/03/2019   Roman W             CHG0047100/CHG0045289 added 'PARTIALLY RECEIVED' to in transit population 
  --------------------------------------------------------------------
  PROCEDURE main(errbuf                 OUT VARCHAR2,
                 retcode                OUT VARCHAR2,
                 p_active_months        IN NUMBER, -- 6
                 p_slow_months          IN NUMBER, -- 12
                 p_sp_active_months     IN NUMBER, -- 12
                 p_sp_slow_months       IN NUMBER, -- 24
                 p_plan_name_resin      IN VARCHAR2, -- MRP_RESNEW
                 p_plan_name_none_resin IN VARCHAR2, -- MRP_SYSNEW
                 p_plan_name_fdm        IN VARCHAR2, -- MRPplan
                 p_fdm_cost_org_id      IN NUMBER, --739
                 p_keep_history_days    IN NUMBER, -- 180
                 p_planning_period      IN NUMBER -- number of nmonths for the cut of date
                 ) IS
  
    CURSOR pop_c IS
      SELECT a_view.segment1          segment1,
             a_view.description       description,
             a_view.inventory_item_id inventory_item_id,
             item_category.tech       tech,
             item_category.item_type  item_type,
             -- CHG0033075
             -- Previous version of the program handled all non-FDM related records.  These
             -- are identified by the this flag so that non-FDM records are handled the same
             -- way they were before this change.
             DECODE(item_category.tech, 'FDM', 'Y', 'N') is_fdm_flag,
             SUM(a_view.primary_transaction_quantity) primary_transaction_quantity
        FROM ( -- population of intransit items
              SELECT msi.segment1,
                      msi.description,
                      msi.inventory_item_id,
                      SUM(a.quantity_shipped - a.quantity_received) primary_transaction_quantity
                FROM rcv_msl_v a, rcv_msh_v c, mtl_system_items_b msi
              --WHERE a.shipment_line_status_code   = 'EXPECTED' -- rem 11/03/2019 CHG0047100/CHG0045289
               WHERE a.shipment_line_status_code in
                     ('EXPECTED', 'PARTIALLY RECEIVED') -- added 11/03/2019 CHG0047100/CHG0045289
                 AND a.destination_type_code = 'INVENTORY'
                 AND msi.organization_id = a.from_organization_id
                 AND msi.inventory_item_id = a.item_id
                 AND c.shipment_header_id = a.shipment_header_id
               GROUP BY msi.segment1, msi.description, msi.inventory_item_id
              UNION ALL
              -- population of items on-hand qty from asset subinv
              SELECT msib.segment1,
                      msib.description,
                      msib.inventory_item_id,
                      SUM(moqd.primary_transaction_quantity) primary_transaction_quantity
                FROM mtl_onhand_quantities_detail moqd,
                      mtl_secondary_inventories    sub,
                      mtl_system_items_b           msib
               WHERE moqd.subinventory_code = sub.secondary_inventory_name
                 AND moqd.inventory_item_id = msib.inventory_item_id
                 AND moqd.organization_id = msib.organization_id
                 AND sub.asset_inventory = 1
                 AND sub.organization_id = msib.organization_id
               GROUP BY msib.segment1,
                         msib.description,
                         msib.inventory_item_id) a_view,
             -- CHG0033075
             -- Added to get 'Product Hierarchy' category info.
             /* item_category... */
             (SELECT micv.inventory_item_id,
                     micv.segment6          tech,
                     micv.segment7          item_type
                FROM mtl_parameters mp, mtl_item_categories_v micv
               WHERE micv.organization_id = mp.organization_id
                 AND micv.organization_id = mp.master_organization_id
                 AND 'Product Hierarchy' = micv.category_set_name) item_category
      /* ...item_category */
      -- CHG0033075
      -- Removed WHERE below because we are now looking at FDM and Polyjet
      -- WHERE xxinv_utils_pkg.is_fdm_item(a_view.inventory_item_id) = 'N'
       WHERE a_view.inventory_item_id = item_category.inventory_item_id(+)
       GROUP BY a_view.segment1,
                a_view.description,
                a_view.inventory_item_id,
                item_category.tech,
                item_category.item_type;
  
    l_sp               VARCHAR2(10) := NULL;
    l_plan_name        VARCHAR2(100) := NULL;
    l_active_demand    NUMBER := 0;
    l_slow_demand      NUMBER := 0;
    l_slow_inactive_r  t_slow_inactive_rec;
    l_err_desc         VARCHAR2(500) := NULL;
    l_err_code         VARCHAR2(100) := NULL;
    l_new_oh           NUMBER := NULL;
    l_is_resin         VARCHAR2(5) := NULL;
    l_batch_id         NUMBER := 0;
    l_planning_item_id NUMBER := 0;
    l_curr_start_date  DATE := NULL;
  
    my_exception EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    g_active_months    := p_active_months;
    g_slow_months      := p_slow_months;
    g_sp_active_months := p_sp_active_months;
    g_sp_slow_months   := p_sp_slow_months;
    g_plan_name_resin  := p_plan_name_resin;
    g_plan_name_fdm    := p_plan_name_fdm;
  
    g_plan_name_none_resin := p_plan_name_none_resin;
    g_keep_history_days    := p_keep_history_days;
    g_planning_period      := p_planning_period;
  
    IF g_creation_date IS NULL THEN
      g_creation_date := SYSDATE;
    END IF;
  
    delete_temp_tbl(l_err_desc, l_err_code, p_keep_history_days);
    -- set batch_id
    BEGIN
      SELECT xxinv_slow_inactive_batch_s.nextval INTO l_batch_id FROM dual;
    EXCEPTION
      WHEN OTHERS THEN
        errbuf  := 'Can not set batch id';
        retcode := 2;
        dbg('Can not set batch id');
        RAISE my_exception;
    END;
  
    dbg('Batch id - ' || l_batch_id);
  
    -- enter details to slow inactive table
    FOR pop_r IN pop_c LOOP
      dbg('****************** BEGIN PROCESSING FOR ITEM ' ||
          pop_r.segment1 || ' ************************');
    
      -- Initialize variables
      l_sp            := NULL;
      l_is_resin      := NULL;
      l_active_demand := NULL;
      l_slow_demand   := NULL;
      --v1.2 Added on 16thMay2017 for INC0090114
      l_slow_inactive_r := NULL;
    
      dbg('pop_r.is_fdm_flag: ' || pop_r.is_fdm_flag);
      -- CHG0033075
      -- spare parts and resin items are handled the same as all items for FDM items.  Special handling
      -- is only needed for non-FDM items.
      IF pop_r.is_fdm_flag = 'N' THEN
        -- check if this item is SP (Spare part)
        l_sp       := xxinv_item_classification.is_item_sp(pop_r.inventory_item_id);
        l_is_resin := xxinv_item_classification.is_item_resin(pop_r.inventory_item_id);
      
        dbg('l_sp: ' || l_sp);
        dbg('l_is_resin: ' || l_is_resin);
      
        IF l_is_resin = 'Y' THEN
          l_plan_name := p_plan_name_resin; -- MRP_RESNEW
        ELSE
          l_plan_name := p_plan_name_none_resin; -- MRP_SYSNEW
        END IF;
      ELSE
        -- CHG0033075
        -- Plan name is MRPPlan for ALL FDM items
        l_plan_name := p_plan_name_fdm;
      END IF;
    
      dbg('l_plan_name: ' || l_plan_name);
    
      -- Get Planning date
      BEGIN
        SELECT curr_start_date
          INTO l_curr_start_date
          FROM msc_plans
         WHERE compile_designator = l_plan_name;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_curr_start_date := SYSDATE - 14;
      END;
    
      dbg('l_curr_start_date      : ' || l_curr_start_date);
      dbg('l_plan_name            : ' || l_plan_name);
      dbg('p_active_months        : ' || p_active_months);
      dbg('p_slow_months          : ' || p_slow_months);
      dbg('p_active_months        : ' || p_active_months);
      dbg('p_planning_period      : ' || p_planning_period);
      dbg('l_sp                   : ' || l_sp);
      dbg('l_is_resin             : ' || l_is_resin);
    
      IF l_sp = 'Y' THEN
        -- the min max demand is for 2 months therefor i divide it by 2 to get the demand per 1 month.
        l_active_demand := (get_sp_demand_by_item(pop_r.inventory_item_id) / 2) *
                           p_sp_active_months;
        l_slow_demand   := (get_sp_demand_by_item(pop_r.inventory_item_id) / 2) *
                           (p_sp_slow_months - p_sp_active_months);
      
      ELSE
        BEGIN
          SELECT DISTINCT m.inventory_item_id planning_item_id
            INTO l_planning_item_id
            FROM msc_system_items m
           WHERE m.sr_inventory_item_id = pop_r.inventory_item_id;
        EXCEPTION
          WHEN OTHERS THEN
            l_planning_item_id := NULL;
        END;
      
        dbg('Calculating active demand for l_planning_item_id: ' ||
            l_planning_item_id);
      
        l_active_demand := get_total_demand_by_item(p_inventory_item_id => l_planning_item_id, -- i n
                                                    p_plan_name         => l_plan_name, -- i v
                                                    p_from_date         => trunc(l_curr_start_date), -- i d    -- (sysdate -14)
                                                    p_to_date           => add_months(trunc(l_curr_start_date),
                                                                                      p_active_months), -- i d (sysdate)
                                                    p_entity            => 'ACTIVE', -- i v
                                                    p_slow_months       => p_slow_months, -- i n
                                                    p_active_months     => p_active_months, -- i n
                                                    p_planning_period   => p_planning_period, -- i n
                                                    p_curr_start_date   => l_curr_start_date);
      
        IF l_is_resin = 'Y' THEN
        
          dbg('Calculating slow demand for resin l_planning_item_id: ' ||
              l_planning_item_id);
          l_slow_demand := get_total_demand_by_item(p_inventory_item_id => l_planning_item_id, -- i n
                                                    p_plan_name         => l_plan_name, -- i v
                                                    p_from_date         => add_months(trunc(l_curr_start_date),
                                                                                      p_active_months) + 1, -- i d (sysdate)
                                                    p_to_date           => add_months(trunc(l_curr_start_date),
                                                                                      p_slow_months), -- i d (sysdate)
                                                    p_entity            => 'SLOW', -- i v
                                                    p_slow_months       => p_slow_months, -- i n
                                                    p_active_months     => p_active_months, -- i n
                                                    p_planning_period   => p_planning_period, -- i n
                                                    p_curr_start_date   => l_curr_start_date -- i d
                                                    );
        
        ELSE
          dbg('Calculating slow demand for l_planning_item_id: ' ||
              l_planning_item_id);
          l_slow_demand := get_total_demand_by_item(p_inventory_item_id => l_planning_item_id, -- i n
                                                    p_plan_name         => l_plan_name, -- i v
                                                    p_from_date         => add_months(trunc(l_curr_start_date),
                                                                                      p_active_months) + 1, -- i d (sysdate)
                                                    p_to_date           => add_months(trunc(l_curr_start_date),
                                                                                      p_slow_months), -- i d (sysdate)
                                                    p_entity            => 'SLOW', -- i v
                                                    p_slow_months       => p_slow_months, -- i n
                                                    p_active_months     => p_active_months, -- i n
                                                    p_planning_period   => p_planning_period, -- i n
                                                    p_curr_start_date   => l_curr_start_date -- i d
                                                    );
        END IF;
      
      END IF; ---
    
      dbg('l_slow_demand  : ' || l_slow_demand);
      dbg('l_active_demand: ' || l_active_demand);
    
      IF l_slow_demand IS NULL THEN
        errbuf  := 'Slow demand is NULL ';
        retcode := 2;
        dbg('Slow demand is NULL');
        EXIT;
      END IF;
    
      l_slow_inactive_r.inventory_item_id := pop_r.inventory_item_id;
      l_slow_inactive_r.oh_quantity       := pop_r.primary_transaction_quantity;
      l_slow_inactive_r.active_demand     := l_active_demand;
      l_slow_inactive_r.slow_demand       := l_slow_demand;
      l_slow_inactive_r.active_qty        := least(pop_r.primary_transaction_quantity,
                                                   l_active_demand); --  on-hand - active demand
      l_new_oh                            := l_slow_inactive_r.oh_quantity -
                                             l_slow_inactive_r.active_qty;
      l_slow_inactive_r.slow_qty          := least(l_slow_demand, l_new_oh); --  new on-hand - slow demand
      l_slow_inactive_r.inactive_qty      := pop_r.primary_transaction_quantity -
                                             (l_slow_inactive_r.active_qty +
                                             l_slow_inactive_r.slow_qty);
      l_slow_inactive_r.item_is_sp        := l_sp;
      l_slow_inactive_r.item_status       := get_item_status(pop_r.inventory_item_id);
    
      -- CHG0033075
      -- us_cost is calculated different than il_cost
      IF pop_r.is_fdm_flag = 'N' THEN
        l_slow_inactive_r.item_il_cost := xxcst_ratam_pkg.get_il_std_cost(NULL,
                                                                          trunc(SYSDATE),
                                                                          pop_r.inventory_item_id);
      ELSE
        l_slow_inactive_r.item_us_cost := get_us_std_cost(pop_r.inventory_item_id,
                                                          p_fdm_cost_org_id);
      END IF;
    
      l_slow_inactive_r.slow_till_cutof_qty     := abs(g_slow_till_cutof_qty);
      l_slow_inactive_r.avg_demand_end_plan_qty := g_avg_demand_end_plan_qty;
      l_slow_inactive_r.technology              := pop_r.tech;
      l_slow_inactive_r.item_type               := pop_r.item_type;
      l_slow_inactive_r.plan_name_fdm           := p_plan_name_fdm;
    
      l_err_desc := NULL;
      l_err_code := 0;
      insert_temp_tbl(errbuf            => l_err_desc, -- o v
                      retcode           => l_err_code, -- o v
                      p_request_id      => l_batch_id, -- i n
                      p_slow_inactive_r => l_slow_inactive_r); -- i t_slow_inactive_rec
    
    --dbms_output.put_line('Item Id - '||pop_r.inventory_item_id);
    END LOOP;
  EXCEPTION
    WHEN my_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen err - ' || substr(SQLERRM, 1, 240);
      retcode := 2;
  END;

END xxinv_slow_inactive_pkg;
/
