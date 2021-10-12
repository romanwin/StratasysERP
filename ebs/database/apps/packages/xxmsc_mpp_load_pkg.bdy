CREATE OR REPLACE PACKAGE BODY xxmsc_mpp_load_pkg IS

--------------------------------------------------------------------
--  customization code: CUST032 - Upload MPP Planned Orders from Excel file
--  name:               xxmsc_mpp_load_pkg
--                            
--  create by:          RAN.SCHWARTZMAN
--  $Revision:          1.1 
--  creation date:      23/11/2009
--  Purpose:            load MPP from CSV file
--------------------------------------------------------------------
--  ver   date          name             desc
--  1.0   23/11/2009    RAN.SCHWARTZMAN  initial build  
--  1.1   05/07/10      yuval tal        add support for 18 months column in excel file
-------------------------------------------------------------------- 

   TYPE periods_rec_t IS RECORD(
      period_num  NUMBER,
      period_name VARCHAR2(3),
      start_date  DATE,
      next_date   DATE);
   TYPE periods_tbl_t IS TABLE OF periods_rec_t INDEX BY BINARY_INTEGER;

   g_periods_tbl periods_tbl_t;

   --------------------------------------------------
   -- get_periods
   -- populates the periods array
   --------------------------------------------------
   FUNCTION get_periods(p_start_name VARCHAR2) RETURN NUMBER IS
   
      v_start_date DATE;
      v_count      NUMBER;
   
      CURSOR periods_cur IS
        SELECT * FROM 
        ( SELECT caldt.period_name, caldt.period_start_date, caldt.next_date
           FROM msc_period_start_dates caldt
          WHERE caldt.calendar_code = 'OBJ:OB_SUN_THU' AND
                caldt.period_start_date BETWEEN  v_start_date AND   
             ADD_MONTHS(v_start_date ,19)               
          ORDER BY caldt.period_start_date)
          WHERE ROWNUM<19; -- changed 4.7.10 yuval 
   
   BEGIN
      -- get start period
      SELECT caldt.period_start_date
        INTO v_start_date
        FROM msc_period_start_dates caldt
       WHERE caldt.calendar_code = 'OBJ:OB_SUN_THU' AND
             caldt.period_name = p_start_name AND
             caldt.period_start_date >= SYSDATE - 60 AND
             caldt.period_start_date <= SYSDATE + 240;
   
      -- fill array
      v_count := 0;
      FOR periods_rec IN periods_cur LOOP
         v_count := v_count + 1;
         g_periods_tbl(v_count).period_num := v_count;
         g_periods_tbl(v_count).period_name := periods_rec.period_name;
         g_periods_tbl(v_count).start_date := periods_rec.period_start_date;
         g_periods_tbl(v_count).next_date := periods_rec.next_date;
      END LOOP;
   
      RETURN 0;
   
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 2;
   END;

   --------------------------------------------------
   -- do_update
   -- Perform the updates for one period
   --------------------------------------------------
   FUNCTION do_update(p_inventory_item_id NUMBER,
                      p_organization_id   NUMBER,
                      p_plan_id           NUMBER,
                      p_period_num        NUMBER) RETURN NUMBER IS
   
      CURSOR supp_lines_cur IS
         SELECT transaction_id,
                nvl(new_wip_start_date, new_schedule_date) new_due_date
           FROM msc_supplies
          WHERE plan_id = p_plan_id --2 --<P1>
                AND
                organization_id = p_organization_id --90 --<P2>
                AND
                order_type = 5
               --AND NVL(new_wip_start_date, new_schedule_date) <  -- changed 24/12/09 for Moni's request
                AND
                new_schedule_date < g_periods_tbl(p_period_num)
         .next_date --to_date('1/12/2009','DD/MM/YYYY')
               --AND NVL(new_wip_start_date, new_schedule_date) >= -- changed 24/12/09 for Moni's request
                AND
                new_schedule_date >= g_periods_tbl(p_period_num)
         .start_date --to_date('1/11/2009','DD/MM/YYYY')
                AND
                implement_as IS NULL AND
                inventory_item_id = p_inventory_item_id; --2529
   
   BEGIN
      fnd_file.put_line(fnd_file.log, '    in do_update');
   
      FOR supp_lines_rec IN supp_lines_cur LOOP
      
         UPDATE msc_supplies
            SET firm_quantity     = 0,
                firm_planned_type = 1,
                firm_date         = supp_lines_rec.new_due_date,
                implement_firm    = 1,
                release_status    = 2,
                applied           = 2
          WHERE transaction_id = supp_lines_rec.transaction_id;
      
         fnd_file.put_line(fnd_file.log,
                           '      perform update. period: ' || p_period_num ||
                           ', zero out transaction: ' ||
                           supp_lines_rec.transaction_id);
      
      END LOOP;
   
      RETURN 0;
   
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 2;
   END do_update;

   --------------------------------------------------
   -- do_insert
   -- Perform the insert operation for a plan, with qty=1
   --------------------------------------------------
   FUNCTION do_insert(p_inventory_item_id      NUMBER,
                      p_organization_id        NUMBER,
                      p_ins_date               DATE,
                      p_plan_id                NUMBER,
                      p_qty                    NUMBER,
                      p_firm_date              DATE,
                      p_source_organization_id NUMBER DEFAULT NULL) -- Added 22/12/09
    RETURN NUMBER IS
   
      v_transaction_id NUMBER;
      v_process_seq_id NUMBER;
      v_sr_inst_id     NUMBER;
   
   BEGIN
      fnd_file.put_line(fnd_file.log, '    in do_insert');
   
      SELECT msc_supplies_s.NEXTVAL INTO v_transaction_id FROM dual;
   
      BEGIN
         SELECT mpe.process_sequence_id, mpe.sr_instance_id
           INTO v_process_seq_id, v_sr_inst_id
           FROM msc_process_effectivity mpe
          WHERE plan_id = p_plan_id AND
                item_id = p_inventory_item_id AND
                organization_id = p_organization_id;
      EXCEPTION
         WHEN no_data_found THEN
            v_process_seq_id := NULL;
            v_sr_inst_id     := 1;
         WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log,
                              '  Error in getting process_sequence_id');
            RETURN 2;
      END;
   
      INSERT INTO msc_supplies
         (transaction_id,
          last_update_date,
          last_updated_by,
          creation_date,
          created_by,
          last_update_login,
          inventory_item_id,
          organization_id,
          sr_instance_id,
          plan_id,
          new_schedule_date,
          old_schedule_date,
          new_wip_start_date,
          --              old_wip_start_date,
          disposition_id,
          disposition_status_type,
          order_type,
          supplier_id,
          new_order_quantity,
          old_order_quantity,
          new_order_placement_date,
          firm_planned_type,
          reschedule_flag,
          new_processing_days,
          implemented_quantity,
          last_unit_completion_date,
          first_unit_start_date,
          last_unit_start_date,
          daily_rate,
          new_dock_date,
          new_ship_date,
          quantity_in_process,
          firm_quantity,
          firm_date,
          firm_ship_date,
          implement_demand_class,
          implement_date,
          implement_quantity,
          implement_firm,
          implement_wip_class_code,
          implement_job_name,
          implement_status_code,
          implement_employee_id,
          implement_location_id,
          release_status,
          load_type,
          implement_as,
          status,
          applied,
          implement_source_org_id,
          implement_supplier_id,
          implement_supplier_site_id,
          implement_sr_instance_id,
          source_organization_id,
          source_supplier_id,
          source_supplier_site_id,
          source_sr_instance_id,
          project_id,
          task_id,
          planning_group,
          implement_project_id,
          implement_task_id,
          implement_schedule_group_id,
          implement_build_sequence,
          alternate_bom_designator,
          alternate_routing_designator,
          process_seq_id,
          implement_alternate_bom,
          implement_alternate_routing,
          line_id,
          number1, ---
          release_errors,
          unit_number,
          implement_unit_number,
          shipment_id,
          ship_method,
          need_by_date,
          parent_id,
          cfm_routing_flag,
          routing_sequence_id,
          bill_sequence_id,
          implement_ship_method)
      VALUES
         (v_transaction_id, --transaction_id
          SYSDATE, --last_update_date
          fnd_global.user_id, --last_updated_by
          SYSDATE, --creation_date
          fnd_global.user_id, --created_by
          fnd_global.login_id, --last_update_login
          p_inventory_item_id, --inventory_item_id
          p_organization_id, --organization_id
          v_sr_inst_id, --sr_instance_id
          p_plan_id, --plan_id
          p_firm_date, --new_schedule_date  -- Changed 24/12/09
          NULL, --old_schedule_date
          p_ins_date, --new_wip_start_date
          NULL, --v_transaction_id,            --disposition_id
          1, --disposition_status_type
          5, --order_type
          NULL, --supplier_id
          0, --new_order_quantity
          NULL, --old_order_quantity
          NULL, --new_order_placement_date
          1, --firm_planned_type
          NULL, --reschedule_flag
          NULL, --new_processing_days
          NULL, --implemented_quantity
          NULL, --last_unit_completion_date
          NULL, --first_unit_start_date
          NULL, --last_unit_start_date
          NULL, -- (ORIG)
          p_ins_date, --new_dock_date
          NULL, --new_ship_date
          0, --quantity_in_process
          p_qty, --firm_quantity
          p_firm_date, --p_ins_date, --firm_date  ----- Changed 22/12/09
          NULL, --firm_ship_date
          NULL, --implement_demand_class
          NULL, --implement_date
          NULL, --implement_quantity
          1, --implement_firm
          NULL, --implement_wip_class_code
          NULL, --implement_job_name
          NULL, --implement_status_code
          NULL, --implement_employee_id
          NULL, --implement_location_id
          NULL, --release_status
          NULL, --load_type
          NULL, --implement_as
          0, --status  (ORIG)
          2, --applied (ORIG)
          NULL, --implement_source_org_id
          NULL, --implement_vendor_id
          NULL, --implement_vendor_site_id
          NULL, --implement_sr_instance_id
          p_source_organization_id, --source_organization_id
          NULL, --source_vendor_id
          NULL, --source_vendor_site_id
          NULL, --source_sr_instance_id
          NULL, --project_id
          NULL, --task_id
          NULL, --planning_group
          NULL, --implement_project_id
          NULL, --implement_task_id
          NULL, --implement_schedule_group_id
          NULL, --implement_build_sequence
          NULL, --alternate_bom_designator
          NULL, --alternate_routing_designator
          v_process_seq_id, --process_seq_id
          NULL, --implement_alternate_bom
          NULL, --implement_alt_rtg
          NULL, --line_id
          NULL, --number1
          NULL, --release_errors
          NULL, --unit_number
          NULL, --implement_unit_number
          NULL, --shipment_id
          NULL, --ship_method
          NULL, --need_by_date
          NULL, --parent_id
          2, --cfm_routing_flag
          NULL, --routing_seq_id
          NULL, --bill_seq_id
          NULL); --implement_ship_method
   
      RETURN 0;
   
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 2;
   END do_insert;

   --------------------------------------------------
   -- calc_insert_qty
   -- Calculated the qty for each insert and number of records to insert
   --------------------------------------------------
   FUNCTION calc_insert_qty(p_inventory_item_id NUMBER,
                            p_organization_id   NUMBER,
                            p_demand_qty        NUMBER,
                            p_plan_id           NUMBER,
                            x_ins_qty           OUT NUMBER,
                            x_times             OUT NUMBER) RETURN NUMBER IS
   
      v_fixed_order_quantity   NUMBER;
      v_fixed_lot_multiplier   NUMBER;
      v_minimum_order_quantity NUMBER;
      v_maximum_order_quantity NUMBER;
   
   BEGIN
      fnd_file.put_line(fnd_file.log, '    in calc_insert_qty');
      SELECT msi.minimum_order_quantity,
             msi.maximum_order_quantity,
             msi.fixed_order_quantity,
             msi.fixed_lot_multiplier
        INTO v_minimum_order_quantity,
             v_maximum_order_quantity,
             v_fixed_order_quantity,
             v_fixed_lot_multiplier
        FROM msc_system_items msi
       WHERE msi.inventory_item_id = p_inventory_item_id AND
             msi.organization_id = p_organization_id AND
             msi.plan_id = p_plan_id;
   
      -- currently we support only fixed order qty, not other parameters...
      IF v_fixed_order_quantity > 0 THEN
         x_ins_qty := v_fixed_order_quantity;
      ELSE
         x_ins_qty := p_demand_qty;
      END IF;
      x_times := ceil(p_demand_qty / x_ins_qty);
   
      fnd_file.put_line(fnd_file.log,
                        '      calc_insert_qty. x_ins_qty=' || x_ins_qty ||
                        ',x_times=' || x_times);
   
      RETURN 0;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 2;
   END calc_insert_qty;

   PROCEDURE insert_general_plan(p_plan_id           NUMBER,
                                 p_inventory_item_id NUMBER,
                                 p_organization_id   NUMBER,
                                 x_return_status     OUT NUMBER,
                                 x_err_msg           OUT VARCHAR2) IS
   
      v_future_plans_exist VARCHAR2(1);
      l_future_date        DATE;
   
   BEGIN
   
      -- first check no plans exist after the last period
      SELECT 'Y'
        INTO v_future_plans_exist
        FROM msc_supplies
       WHERE plan_id = p_plan_id AND
             organization_id = p_organization_id AND
             order_type = 5 AND
            -- nvl(new_wip_start_date, new_schedule_date) >= g_periods_tbl(v_month_count).next_date AND --to_date('1/11/2009','DD/MM/YYYY')             
             nvl(firm_quantity, nvl(new_order_quantity, 0)) > 0 AND
             implement_as IS NULL AND
             inventory_item_id = p_inventory_item_id;
   EXCEPTION
      WHEN no_data_found THEN
         fnd_file.put_line(fnd_file.log,
                           '  No inserts done for this item. About to perform general insert');
      
         SELECT mp.curr_cutoff_date
           INTO l_future_date
           FROM msc_plans mp
          WHERE plan_id = p_plan_id;
      
         x_return_status := do_insert(p_inventory_item_id,
                                      
                                      p_organization_id,
                                      l_future_date,
                                      p_plan_id,
                                      1,
                                      l_future_date,
                                      90); --Added 22/12/09
         IF x_return_status != 0 THEN
            fnd_file.put_line(fnd_file.log,
                              '  General Insert operation failed for the item');
            x_err_msg       := 'Error in Insert operation';
            x_return_status := '2';
            ROLLBACK;
         END IF;
      WHEN too_many_rows THEN
         NULL;
      WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.log,
                           '  General Insert operation failed for the item: ' ||
                           p_inventory_item_id || ' - ' || SQLERRM);
         x_return_status := '2';
         x_err_msg       := 'Error in Insert operation';
      
   END insert_general_plan;

   --------------------------------------------------
   -- main
   --------------------------------------------------
   PROCEDURE main(errbuf              OUT VARCHAR2,
                  retcode             OUT VARCHAR2,
                  p_location          IN VARCHAR2,
                  p_filename          IN VARCHAR2,
                  p_plan_id           IN NUMBER,
                  p_start_period_name IN VARCHAR2,
                  p_day_of_month      IN NUMBER) IS
   
      TYPE qty_t IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
      v_qty qty_t;
   
      v_ret                NUMBER;
      --v_i                  NUMBER;
      plist_file           utl_file.file_type;
      v_read_code          NUMBER(5) := 1;
      v_line_buf           VARCHAR2(2000);
      v_tmp_line           VARCHAR2(2000);
      v_delimiter          CHAR(1) := ',';
      v_place              NUMBER(4);
      v_counter            NUMBER := 0;
      v_item_code          mtl_system_items_b.segment1%TYPE;
      v_org_code           msc_system_items.organization_code%TYPE;
      v_month_count        NUMBER := 18;  -- changed 4.7.10 yuval 
      v_inventory_item_id  NUMBER;
      v_organization_id    NUMBER;
      v_ins_indicator      NUMBER;
      v_ins_date           DATE;
      --v_future_plans_exist VARCHAR2(1);
      v_ins_qty            NUMBER;
      v_ins_times          NUMBER;
   
   BEGIN
      fnd_file.put_line(fnd_file.log, 'Start MPP loading program.');
      fnd_file.put_line(fnd_file.log,
                        'p_plan_id=' || p_plan_id ||
                        ', p_start_period_name=' || p_start_period_name ||
                        ', p_day_of_month=' || p_day_of_month);
   
      -- fill periods array
      v_ret := get_periods(p_start_period_name);
      IF v_ret != 0 THEN
         errbuf  := 'Unable to get periods for starting period defined. ' ||
                    p_start_period_name;
         retcode := '2';
         RETURN;
      END IF;
   
      -- for check - COMMENT THIS
/*      FOR v_i IN 1 .. g_periods_tbl.COUNT LOOP
         fnd_file.put_line(fnd_file.log,
                           'count=' || v_i || ', value=' ||
                            g_periods_tbl(v_i)
                           .period_num || ', name=' || g_periods_tbl(v_i)
                           .period_name || ', start=' || g_periods_tbl(v_i)
                           .start_date || ', next=' || g_periods_tbl(v_i)
                           .next_date);
      END LOOP;
*/   
      -- Open the input file
      BEGIN
         plist_file := utl_file.fopen(location  => p_location,
                                      filename  => p_filename,
                                      open_mode => 'r');
         fnd_file.put_line(fnd_file.log,
                           'File ' || ltrim(rtrim(p_location)) || '/' ||
                           ltrim(rtrim(p_filename)) || ' Opened');
      EXCEPTION
         WHEN utl_file.invalid_path THEN
            errbuf  := 'Invalid Path for ' || ltrim(rtrim(p_location)) || '/' ||
                       ltrim(rtrim(p_filename)) || chr(0);
            retcode := '2';
            RETURN;
         WHEN utl_file.invalid_mode THEN
            errbuf  := 'Invalid Mode for ' || ltrim(rtrim(p_location)) || '/' ||
                       ltrim(rtrim(p_filename)) || chr(0);
            retcode := '2';
            RETURN;
         WHEN utl_file.invalid_operation THEN
            errbuf  := 'Invalid operation for ' || ltrim(rtrim(p_location)) || '/' ||
                       ltrim(rtrim(p_filename)) || chr(0);
            retcode := '2';
            RETURN;
         WHEN OTHERS THEN
            errbuf  := 'Other for ' || ltrim(rtrim(p_location)) || '/' ||
                       ltrim(rtrim(p_filename)) || chr(0);
            retcode := '2';
            RETURN;
      END;
   
      -- Loop on lines in the file
      WHILE v_read_code <> 0 AND nvl(retcode, '0') = '0' LOOP
         BEGIN
            utl_file.get_line(file => plist_file, buffer => v_line_buf);
         EXCEPTION
            WHEN utl_file.read_error THEN
               errbuf  := 'Read Error' || chr(0);
               retcode := '2';
               RETURN;
            WHEN no_data_found THEN
               fnd_file.put_line(fnd_file.log, 'Read Complete');
               v_read_code := 0;
            WHEN OTHERS THEN
               errbuf  := 'Other for Line Read' || chr(0);
               retcode := '2';
               RETURN;
         END;
      
         -- parse line
         IF v_read_code <> 0 THEN
            -- read condition
            v_counter := v_counter + 1;
            v_place   := instr(v_line_buf, v_delimiter);
         
            IF nvl(v_place, 0) = 0 OR (v_place > 100) THEN
               -- check delimiter existance
               errbuf  := 'No Delimiter In The File, Line' ||
                          to_char(v_counter) || chr(0);
               retcode := '2';
            ELSE
               v_item_code := ltrim(rtrim(substr(v_line_buf, 1, v_place - 1)));
               v_tmp_line  := ltrim(substr(v_line_buf,
                                           v_place + 1,
                                           length(v_line_buf)));
            
               FOR cnt IN 1 .. v_month_count LOOP
                  v_place := instr(v_tmp_line, v_delimiter);
                  v_qty(cnt) := ltrim(rtrim(substr(v_tmp_line,
                                                   1,
                                                   v_place - 1)));
                  v_tmp_line := ltrim(substr(v_tmp_line,
                                             v_place + 1,
                                             length(v_tmp_line)));
               END LOOP;
            
               v_place    := length(v_tmp_line);
               v_org_code := ltrim(rtrim(substr(v_tmp_line, 1, v_place - 1)));
            
               -- actions performing section. (Line has been read successfully. Now do required actions)
               fnd_file.put_line(fnd_file.log,
                                 'Now working on line: ' || v_counter ||
                                 ', item: ' || v_item_code ||
                                 ', organization: ' || v_org_code);
               BEGIN
                  -- find item_id and organization_id
                  SELECT msi.inventory_item_id, msi.organization_id
                    INTO v_inventory_item_id, v_organization_id
                    FROM msc_system_items msi
                   WHERE msi.item_name = v_item_code AND
                         msi.organization_code = v_org_code AND
                         msi.plan_id = p_plan_id;
               
               EXCEPTION
                  WHEN OTHERS THEN
                     fnd_file.put_line(fnd_file.log,
                                       'Unable to translate item or organization. line: ' ||
                                       v_counter || ', item: ' ||
                                       v_item_code || ', organization: ' ||
                                       v_org_code);
                     retcode := '2';
                     RETURN;
               END;
            
               v_ins_indicator := 0; -- indicator for inserts performed per item line
            
               FOR cnt IN 1 .. v_month_count LOOP
                  -- go over all periods for current item
                  fnd_file.put_line(fnd_file.log, '  Period: ' || cnt);
                  -- zero out current plans
                  IF v_qty(cnt) IS NOT NULL THEN
                     v_ret := do_update(v_inventory_item_id,
                                        v_organization_id,
                                        p_plan_id,
                                        cnt);
                     IF v_ret != 0 THEN
                        fnd_file.put_line(fnd_file.log,
                                          '    Update operation failed for period: ' || cnt);
                        errbuf  := 'Error in Update operation';
                        retcode := '2';
                        ROLLBACK;
                        RETURN;
                     END IF;
                  
                  END IF;
               
                  -- insert new plans             
                  IF v_qty(cnt) IS NOT NULL AND v_qty(cnt) != 0 THEN
                     -- calculate insert date
                     v_ins_date := to_date(p_day_of_month || '-' ||
                                           to_char(g_periods_tbl(cnt)
                                                   .start_date + 10,
                                                   'MON-YYYY'),
                                           'DD-MON-YYYY');
                     v_ins_date := add_months(v_ins_date, -1); -- Added 22/12/09
                     fnd_file.put_line(fnd_file.log,
                                       '  about to perform inserts for period: ' || cnt ||
                                       ', v_ins_date=' || /*p_day_of_month || '-' ||
                                                                                                                                                                                                                                                                                                                                                                                                                            to_char(g_periods_tbl(cnt).start_date + 10,
                                                                                                                                                                                                                                                                                                                                                                                                                                    'MON-YYYY')*/
                                       to_char(v_ins_date, 'DD-MON-YYYY')); -- Changed 22/12/09
                     -- calculate insert qty
                     v_ret := calc_insert_qty(v_inventory_item_id,
                                              v_organization_id,
                                              v_qty(cnt),
                                              p_plan_id,
                                              v_ins_qty,
                                              v_ins_times);
                     IF v_ret != 0 THEN
                        fnd_file.put_line(fnd_file.log,
                                          '  calc_insert_qty failed for period: ' || cnt ||
                                          ', date: ' ||
                                          to_char(v_ins_date, 'DD-MON-YYYY'));
                        errbuf  := 'Error in Insert preparations';
                        retcode := '2';
                        ROLLBACK;
                        RETURN;
                     END IF;
                  
                     --FOR ins_count IN 1..v_qty(cnt) LOOP -- one insert per qty
                     FOR ins_count IN 1 .. v_ins_times LOOP
                        -- insert loop
                        v_ret := do_insert(v_inventory_item_id,
                                           v_organization_id,
                                           v_ins_date,
                                           p_plan_id,
                                           v_ins_qty,
                                           g_periods_tbl(cnt).start_date); --Added 22/12/09
                        IF v_ret != 0 THEN
                           fnd_file.put_line(fnd_file.log,
                                             '  Insert operation failed for period: ' || cnt ||
                                             ', date: ' ||
                                             to_char(v_ins_date,
                                                     'DD-MON-YYYY'));
                           errbuf  := 'Error in Insert operation';
                           retcode := '2';
                           ROLLBACK;
                           RETURN;
                        END IF;
                        v_ins_indicator := v_ins_indicator + 1;
                     END LOOP;
                  END IF;
               
               END LOOP;
            
               -- if no inserts done for this item - do one general insert
               IF v_ins_indicator = 0 THEN
                  -- first check no plans exist after the last period
               
                  insert_general_plan(p_plan_id,
                                      v_inventory_item_id,
                                      v_organization_id,
                                      retcode,
                                      errbuf);
               
                  /* BEGIN
                     SELECT 'Y'
                       INTO v_future_plans_exist
                       FROM msc_supplies
                      WHERE plan_id = p_plan_id AND
                            organization_id = v_organization_id AND
                            order_type = 5 AND
                            nvl(new_wip_start_date, new_schedule_date) >=
                            g_periods_tbl(v_month_count)
                     .next_date --to_date('1/11/2009','DD/MM/YYYY')
                            AND
                            nvl(firm_quantity, nvl(new_order_quantity, 0)) > 0 AND
                            implement_as IS NULL AND
                            inventory_item_id = v_inventory_item_id AND
                            rownum < 2;
                  EXCEPTION
                     WHEN no_data_found THEN
                        v_future_plans_exist := 'N';
                  END;
                  
                  IF v_future_plans_exist = 'N' THEN
                     fnd_file.put_line(fnd_file.log,
                                       '  No inserts done for this item. About to perform general insert');
                     v_ret := do_insert(v_inventory_item_id,
                                        v_organization_id,
                                        SYSDATE + 750,
                                        p_plan_id,
                                        1,
                                        SYSDATE + 750); --Added 22/12/09
                     IF v_ret != 0 THEN
                        fnd_file.put_line(fnd_file.log,
                                          '  General Insert operation failed for the item');
                        errbuf  := 'Error in Insert operation';
                        retcode := '2';
                        ROLLBACK;
                        RETURN;
                     END IF;
                  END IF;*/
               END IF;
               -- End actions performing section
            
            END IF; -- End check delimiter existance
         END IF; -- End read condition
      
      END LOOP; -- loop on lines in input file
   
      COMMIT;
   
   EXCEPTION
      WHEN OTHERS THEN
         errbuf  := 'Unexpected error: ' || SQLERRM;
         retcode := '2';
         ROLLBACK;
      
   END main;

   ----------------------------------------------------------------------------------------

   PROCEDURE update_planned_orders(errbuf               OUT VARCHAR2,
                                   retcode              OUT VARCHAR2,
                                   p_compile_designator IN NUMBER,
                                   p_organization_id    IN NUMBER,
                                   p_date               IN VARCHAR2) IS
   
      t_plan_id_tbl           t_number_type;
      t_inventory_item_id_tbl t_number_type;
      t_organization_id_tbl   t_number_type;
   
      general_plan_err EXCEPTION;
   
   BEGIN
   
      UPDATE msc_supplies mscsupp
         SET mscsupp.firm_quantity     = 0,
             mscsupp.firm_planned_type = 1,
             mscsupp.firm_date         = mscsupp.new_schedule_date
       WHERE mscsupp.plan_id = p_compile_designator AND
             mscsupp.organization_id = p_organization_id AND
             mscsupp.order_type = 5 AND
             mscsupp.new_schedule_date <=
             to_date(p_date, 'YYYY/MM/DD HH24:MI:SS') AND
             mscsupp.implement_as IS NULL AND
             nvl(mscsupp.firm_quantity, -1) != 0 AND
             nvl(mscsupp.firm_planned_type, -1) != 1
      RETURNING plan_id, inventory_item_id, organization_id BULK COLLECT INTO t_plan_id_tbl, t_inventory_item_id_tbl, t_organization_id_tbl;
   
      fnd_file.put_line(fnd_file.log,
                        'Number of updated records: ' || SQL%ROWCOUNT);
      retcode := 0;
   
      FOR i IN 1 .. t_plan_id_tbl.COUNT LOOP
      
         insert_general_plan(t_plan_id_tbl(i),
                             t_inventory_item_id_tbl(i),
                             t_organization_id_tbl(i),
                             retcode,
                             errbuf);
         IF retcode != 0 THEN
            RAISE general_plan_err;
         END IF;
      
      END LOOP;
   
      COMMIT;
   
   EXCEPTION
      WHEN general_plan_err THEN
         ROLLBACK;
      WHEN OTHERS THEN
         errbuf  := 'Unexpected error: ' || SQLERRM;
         retcode := '2';
      
   END update_planned_orders;

END xxmsc_mpp_load_pkg;
/

