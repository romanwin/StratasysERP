CREATE OR REPLACE PACKAGE BODY xxmsc_staging_plan_pkg IS
  --------------------------------------------------------------------
  --  name:            XXMSC_UTILS_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        25/06/2012
  --  creation date:   07/01/2010
  --------------------------------------------------------------------
  --  purpose :        Handle all procedures and functions for msc staging
  --                   tables.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25/06/2012  Dalit A. Raviv    initial build
  --  1.1  22/07/2012  Dalit A. Raviv    procedure set_short_expiration_date
  --                                     correct logic.
  --  1.2  26/06/2014  yuval tal         CHG0032542 : add clear_source_org
  --  1.3   1.1.18     yuval tal         CHG0042051 : modify set_planning_time_fence
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            set_planning_time_fence
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   25/06/2012
  --------------------------------------------------------------------
  --  purpose :        CUST504 - Planning Time Fence by Date
  --                   Resin planners in Objet need to have Planning time Fence as a specific date.
  --                   The Planning time fence in Oracle is loaded to the item as number of days
  --                   thus the Planning time fence is related to the MPP/MRP running date.
  --                   The planning time fence is managed by days in the organization item
  --                   and Planning time fence is related to the running date.
  --                   Objet planners would like to have a firm Planning time fence that
  --                   is not influenced by the MRP/MPP running date.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25/06/2012  Dalit A. Raviv    initial build
  --  1.1   1.1.18     yuval tal         CHG0042051 : change logic : 
  --                                     use Quality plan instead of the Org DFF 
  --------------------------------------------------------------------
  PROCEDURE set_planning_time_fence(errbuf  OUT VARCHAR2,
			retcode OUT VARCHAR2) IS
  
    CURSOR get_org_c IS
    -- organizations that attribute1 is null it means that we do not change
    -- the value at msc_st_system_items tbl (in field planning_time_fence_days)
    -- for all items in the relevant organization.
      SELECT m.organization_id,
	 m.organization_code,
	 m.master_organization_id,
	 q.planned_start_date,
	 trunc(q.planned_start_date) - trunc(SYSDATE) time_fence,
	 eng_bis_functions.getworkdaysbetween(q.xx_org_id,
				  trunc(SYSDATE),
				  trunc(q.planned_start_date)) work_days --CHG0042051
      FROM   mtl_parameters     m,
	 q_org_time_fence_v q
      WHERE  m.organization_id = q.xx_org_id -- CHG0042051
      AND    q.planned_start_date IS NOT NULL; --CHG0042051
  
    --l_time_fence number := 0;
    l_work_days NUMBER := 0;
  BEGIN
    errbuf  := 0;
    retcode := NULL;
    -- 1) by loop on all organizations that attribute1 is not null,
    --    start to check attribute1 - sysdate if this equal 0 or smaller then 1
    --    the value will be 1 else the value will be attribute1 - sysdate
    FOR get_org_r IN get_org_c LOOP
      --l_time_fence :=  get_org_r.time_fence;
      --if l_time_fence < 1 then
      --  l_time_fence := 1;
      --end if;
      l_work_days := get_org_r.work_days;
      IF l_work_days < 1 THEN
        l_work_days := 1;
      END IF;
    
      -- 2) update msc_st_system_items tbl
      --    The calculated number (new planning time fence days) will be inserted
      --    to the table msc_st_system_items in the field planning_time_fence_days
      --    for all items in the relevant organization.
      UPDATE msc_st_system_items mssi
      SET    planning_time_fence_days = l_work_days /*l_time_fence*/
      WHERE  mssi.organization_id = get_org_r.organization_id;
    
      COMMIT;
    
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 1;
      retcode := 'Gen Exc set_planning_time_fence - ' ||
	     substr(SQLERRM, 1, 240);
  END set_planning_time_fence;
  --Planning Data Collection

  --------------------------------------------------------------------
  --  name:            set_short_expiration_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/06/2012
  --------------------------------------------------------------------
  --  purpose :        CUST504 - Planning Time Fence by Date
  --                   Resin LOT’s are controlled with Expiration date.
  --                   Each resin item have minimum selling months, this mean that it is
  --                   not allowed to sell LOT that is under the minimum selling months.
  --
  --                   Resin planners in Objet would like to short the expiration date in the
  --                   planning workbench with the minimum selling expiration months for LOT’s
  --                   that are located in all organizations.
  --
  --                   The concurrent will take the expiration date from the table msc_st_supplies in
  --                   field expiration_date for all items in organization WPI that have the order type “on hand”(18).
  --                   Then, the concurrent will take the minimum selling expiration months from item DFF in the
  --                   field attribute7 in the table mtl_system_items_b for WPI organization and the relevant
  --                   item and will short the expiration date by the minimum selling expiration months (month).
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/06/2012  Dalit A. Raviv    initial build
  --  1.1  28/07/2012  Dalit A. Raviv    change logic of new_expiration date
  --------------------------------------------------------------------
  PROCEDURE set_short_expiration_date(errbuf  OUT VARCHAR2,
			  retcode OUT VARCHAR2) IS
  
    CURSOR pop_c IS
    --  1.1  28/07/2012  Dalit A. Raviv
      SELECT mss.inventory_item_id,
	 mss.organization_id,
	 mss.lot_number,
	 mss.expiration_date,
	 --nvl(to_number(msi.attribute7),0) exp_mon_old,
	 CASE
	   WHEN mp.attribute2 = 'FE' THEN
	    nvl(to_number(msi.attribute4), 0)
	   WHEN mp.attribute2 = 'EU' THEN
	    nvl(to_number(msi.attribute5), 0)
	   WHEN mp.attribute2 = 'US' THEN
	    nvl(to_number(msi.attribute6), 0)
	   WHEN mp.attribute2 = 'EM' THEN
	    nvl(to_number(msi.attribute7), 0)
	   ELSE
	    nvl(to_number(msi.attribute7), 0)
	 END exp_mon,
	 --add_months(mss.expiration_date, (nvl(to_number(attribute7),0) * -1)) new_date_old,
	 CASE
	   WHEN mp.attribute2 = 'FE' THEN
	    add_months(mss.expiration_date,
		   (nvl(to_number(msi.attribute4), 0) * -1))
	   WHEN mp.attribute2 = 'EU' THEN
	    add_months(mss.expiration_date,
		   (nvl(to_number(msi.attribute5), 0) * -1))
	   WHEN mp.attribute2 = 'US' THEN
	    add_months(mss.expiration_date,
		   (nvl(to_number(msi.attribute6), 0) * -1))
	   WHEN mp.attribute2 = 'EM' THEN
	    add_months(mss.expiration_date,
		   (nvl(to_number(msi.attribute7), 0) * -1))
	   ELSE
	    add_months(mss.expiration_date,
		   (nvl(to_number(msi.attribute7), 0) * -1))
	 END new_date
      FROM   msc_st_supplies    mss,
	 mtl_system_items_b msi,
	 mtl_parameters     mp
      WHERE  msi.organization_id = mss.organization_id
      AND    msi.inventory_item_id = mss.inventory_item_id
      AND    mss.expiration_date IS NOT NULL
      AND    mss.order_type = 18 -- "on hand"
      AND    mp.organization_id = mss.organization_id
      ORDER  BY mss.inventory_item_id,
	    mss.organization_id,
	    mss.lot_number;
    /*select mss.inventory_item_id,mss.organization_id, mss.lot_number, mss.expiration_date,
           nvl(to_number(attribute7),0) exp_mon,
           add_months(mss.expiration_date, (nvl(to_number(attribute7),0) * -1)) new_date
    from   msc_st_supplies       mss,
           mtl_system_items_b    msi
    where  msi.organization_id   = mss.organization_id
    and    msi.inventory_item_id = mss.inventory_item_id
    and    mss.expiration_date   is not null
    and    mss.order_type        = 18
    order by mss.inventory_item_id,mss.organization_id, mss.lot_number; */
  
    l_expiration NUMBER;
    l_new_date   DATE;
  BEGIN
    errbuf  := 0;
    retcode := NULL;
    -- by loop for each item at each organization need to check the expiration date.
    FOR pop_r IN pop_c LOOP
      l_expiration := NULL;
      l_new_date   := NULL;
    
      IF pop_r.exp_mon <> 0 THEN
        BEGIN
        
          UPDATE msc_st_supplies mss
          SET    mss.expiration_date = pop_r.new_date --l_new_date
          WHERE  mss.organization_id = pop_r.organization_id
          AND    mss.inventory_item_id = pop_r.inventory_item_id
          AND    mss.order_type = 18
          AND    mss.expiration_date IS NOT NULL
          AND    mss.lot_number = pop_r.lot_number
          AND    mss.expiration_date = pop_r.expiration_date;
          COMMIT;
        
        EXCEPTION
          WHEN OTHERS THEN
	errbuf  := 1;
	retcode := 'Failed Update msc_st_supplies';
	fnd_file.put_line(fnd_file.log,
		      'Failed Update msc_st_supplies for item - ' ||
		      pop_r.inventory_item_id || ' Organization - ' ||
		      pop_r.organization_id);
        END;
      END IF;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 1;
      retcode := 'Gen Exc set_short_expiration_date - ' ||
	     substr(SQLERRM, 1, 240);
  END set_short_expiration_date;

  --------------------------------------------------------------------
  --  name:            set_short_expiration_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   02/07/2012
  --------------------------------------------------------------------
  --  purpose :        CUST505 - Average consumption Calculation
  --                   Resin item will be loaded with Forecasts for the coming year to predict the
  --                   future consumption for an item and create demand in the system.
  --                   We would like to calculate the average future consumption for an item based on
  --                   the item forecast.
  --                   Objet Planners need to know the average future consumption for their calculations.
  --                   In addition, there will be a need of this calculation in many planning reports.
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/07/2012  Dalit A. Raviv    initial build
  --  1.1  22/07/2012  Dalit A. Raviv    look only at forecust that are not the parent (set)
  --------------------------------------------------------------------
  PROCEDURE set_average_consumption_calc(errbuf          OUT VARCHAR2,
			     retcode         OUT VARCHAR2,
			     p_num_of_months IN NUMBER) IS
    CURSOR pop_c IS
      SELECT f.inventory_item_id,
	 f.organization_id,
	 trunc(AVG(f.original_forecast_quantity), 2) avg_qty
      FROM   mrp_forecast_dates       f,
	 mrp_forecast_designators b
      WHERE  f.forecast_designator = b.forecast_designator
      AND    (b.disable_date IS NULL OR b.disable_date > trunc(SYSDATE))
	--and    f.forecast_date between sysdate and add_months(sysdate, + p_num_of_months)
      AND    f.forecast_date BETWEEN
	 to_date('01' || to_char(SYSDATE, 'MON-YYYY'), 'DD-MON-YYYY') AND
	 add_months(to_date('01' || to_char(SYSDATE, 'MON-YYYY'),
		        'DD-MON-YYYY'),
		p_num_of_months) - 1
	--and    inventory_item_id in ( 14823,15045)
	--  1.1  22/07/2012  Dalit A. Raviv
      AND    b.forecast_set IS NOT NULL
      GROUP  BY f.inventory_item_id,
	    f.organization_id
      ORDER  BY 1,
	    2;
  BEGIN
    errbuf  := 0;
    retcode := NULL;
    -- clear attribute24 before put new avg cunsumption.
    BEGIN
      UPDATE mtl_system_items_b msi
      SET    attribute24 = NULL
      WHERE  attribute24 IS NOT NULL;
    
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    FOR pop_r IN pop_c LOOP
      BEGIN
        UPDATE mtl_system_items_b msi
        SET    attribute24 = pop_r.avg_qty
        WHERE  msi.organization_id = pop_r.organization_id
        AND    msi.inventory_item_id = pop_r.inventory_item_id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          errbuf  := 1;
          retcode := 'Failed Update average_consumption_Calc';
          fnd_file.put_line(fnd_file.log,
		    'Failed Update average_consumption_Calc for item - ' ||
		    pop_r.inventory_item_id || ' Organization - ' ||
		    pop_r.organization_id);
          ROLLBACK;
      END;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 1;
      retcode := 'Gen Exc set_average_consumption_Calc - ' ||
	     substr(SQLERRM, 1, 240);
  END set_average_consumption_calc;

  --------------------------------------------------------------------
  --  name:            clear_source_org
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   26.6.14
  --------------------------------------------------------------------
  --  purpose :        CHG0032542 - Clear default ISK Org source in Planning staging tables
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26.6.14     yuval tal         initial build
  --------------------------------------------------------------------
  PROCEDURE clear_source_org(errbuf  OUT VARCHAR2,
		     retcode OUT VARCHAR2) IS
    l_count NUMBER;
  BEGIN
    retcode := 0;
    UPDATE msc_st_trading_partners
    SET    source_org_id = NULL
    WHERE  organization_code IN
           (SELECT flex_value
	FROM   fnd_flex_values_vl  p,
	       fnd_flex_value_sets vs
	WHERE  p.flex_value_set_id = vs.flex_value_set_id
	AND    vs.flex_value_set_name = 'XXMSC_SOURCE_CLEAR_ORGS'
	AND    nvl(p.enabled_flag, 'N') = 'Y'
	AND    SYSDATE BETWEEN nvl(p.start_date_active, SYSDATE - 1) AND
	       nvl(p.end_date_active, SYSDATE + 1))
          --  ('OBJ:ATH', 'OBJ:ETF', 'OBJ:UTP', 'OBJ:ITA')
    AND    partner_type = 3
    AND    source_org_id IS NOT NULL;
  
    l_count := SQL%ROWCOUNT;
  
    fnd_file.put_line(fnd_file.log, '----------------------');
    fnd_file.put_line(fnd_file.log, l_count || ' records updated');
    fnd_file.put_line(fnd_file.log, '----------------------');
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := SQLERRM;
    
  END;

END xxmsc_staging_plan_pkg;
/
