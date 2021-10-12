create or replace 
PACKAGE xxinv_slow_inactive_pkg IS

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
  --------------------------------------------------------------------

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
  FUNCTION get_item_status(p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

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
    RETURN VARCHAR2;

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
    RETURN VARCHAR2;

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
    RETURN VARCHAR2;

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
    RETURN VARCHAR2;

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
  FUNCTION get_irk_minqty(p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

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
  FUNCTION get_ipk_minqty(p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

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
  FUNCTION get_irk_maxqty(p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

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
  FUNCTION get_ipk_maxqty(p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

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
                 );

END xxinv_slow_inactive_pkg;

/
SHOW ERRORS