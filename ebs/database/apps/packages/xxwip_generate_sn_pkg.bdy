CREATE OR REPLACE PACKAGE BODY xxwip_generate_sn_pkg IS

  --------------------------------------------------------------------
  --  name:              XXWIP_GENERATE_SN_PKG
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     07/07/2013 10:39:52
  --------------------------------------------------------------------
  --  purpose :          CUST494 - Mass Generate Serial Numbers
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  07/07/2013    Dalit A. Raviv    initial build
  --  1.1  13/10/2013    Vitaly            cr870 -- change hard-coded organization
  --  1.2  01-APR-2018  danm              CHG0042327 Generate Job number to check Make item SN only (as Single entry point function)
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:              get_message_text
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     07/07/2013
  --------------------------------------------------------------------
  --  purpose :          CUST494 - Mass Generate Serial Numbers
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  07/07/2013    Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_message_text(p_message_name IN VARCHAR2) RETURN VARCHAR2 IS
    l_message VARCHAR2(1500) := NULL;
  BEGIN
    fnd_message.set_name('XXOBJT', p_message_name);
    l_message := fnd_message.get;

    fnd_file.put_line(fnd_file.log, l_message);
    RETURN l_message;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_message_text;

  --------------------------------------------------------------------
  --  name:              check_item_control
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     07/07/2013 10:39:52
  --------------------------------------------------------------------
  --  purpose :          CUST494 - Mass Generate Serial Numbers
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  07/07/2013    Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION check_item_control(p_org_id      IN NUMBER,
                              p_inv_item_id IN mtl_system_items_b.inventory_item_id%TYPE)
    RETURN VARCHAR2 IS

    l_inv_itm_id                 mtl_system_items_b.inventory_item_id%TYPE;
    l_shelf_life_code            mtl_system_items_b.shelf_life_code%TYPE;
    l_lot_control_code           mtl_system_items_b.lot_control_code%TYPE;
    l_serial_number_control_code mtl_system_items_b.serial_number_control_code%TYPE;
    l_shlf_life_d                mtl_system_items_b.shelf_life_days%TYPE;
    l_return_code                VARCHAR2(1); -- 'L' for lot control , 'S' for Serial control , 'N'  for none
  BEGIN
    -- Selects the inventory item id
    SELECT msi.inventory_item_id,
           msi.shelf_life_code,
           msi.lot_control_code,
           msi.serial_number_control_code,
           msi.shelf_life_days
      INTO l_inv_itm_id,
           l_shelf_life_code,
           l_lot_control_code,
           l_serial_number_control_code,
           l_shlf_life_d
      FROM mtl_system_items_b msi
     WHERE msi.organization_id = p_org_id
       AND msi.inventory_item_id = p_inv_item_id;

    IF l_shelf_life_code = 2 AND l_lot_control_code = 2 THEN
      l_return_code := 'L';

    ELSIF l_serial_number_control_code IN (2, 5) THEN
      l_return_code := 'S';
    ELSE
      l_return_code := 'N';
    END IF;

    RETURN l_return_code;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END check_item_control;

  --------------------------------------------------------------------
  --  name:              get_next_sn_exist
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     07/07/2013 10:39:52
  --------------------------------------------------------------------
  --  purpose :          CUST494 - Mass Generate Serial Numbers
  --                     check if SN for item already exists in Job
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  07/07/2013    Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_next_sn_exist(p_org_id IN NUMBER, p_assembly_id IN NUMBER)
    RETURN VARCHAR2 IS

    l_next_sn VARCHAR2(100) := NULL;
    l_exists  VARCHAR2(5) := 'N';
  BEGIN

    -- get next serial number per item per organization
    SELECT msib.auto_serial_alpha_prefix || msib.start_auto_serial_number
      INTO l_next_sn
      FROM mtl_system_items_b msib
     WHERE msib.serial_number_control_code = 2
       AND msib.organization_id = p_org_id
       AND msib.inventory_item_id = p_assembly_id;

    -- look if there is a job already exists for this new serial
    SELECT 'Y'
      INTO l_exists
      FROM wip_entities we
     WHERE we.wip_entity_name = l_next_sn and we.organization_id=p_org_id;

    fnd_file.put_line(fnd_file.log, 'Next Serial number: ' || l_next_sn);
    RETURN l_exists;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END get_next_sn_exist;


  --------------------------------------------------------------------
  --  name:              CheckSR
  --  create by:         Dan Melamed
  --  Revision:          1.6
  --  creation date:     01-APR-2018
  --------------------------------------------------------------------
  --  purpose :          CHG0042327 - Single entry point function to check if SR exists for another MAKE Item.
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.2  01-APR-2018  danm              CHG0042327 Generate Job number to check Make item SN only (as Single entry point function)
  --------------------------------------------------------------------

Function CheckSR(p_item_id number,  p_sr varchar2) return number is

 CURSOR c_chk_sr(c_item_id NUMBER, c_sr VARCHAR2) IS
      SELECT 1
      FROM   mtl_serial_numbers msn
             ,mtl_system_items_b msi
      WHERE  1=1
      and msn.inventory_item_id = msi.inventory_item_id
      and decode(msi.planning_make_buy_code, 1, 'Make', 'Else') = 'Make'     
      and msn.inventory_item_id != c_item_id
      AND    msn.serial_number = c_sr;

  l_tmp number;
  begin
    
  
    OPEN c_chk_sr(p_item_id, p_sr);
    FETCH c_chk_sr
      INTO l_tmp;
    CLOSE c_chk_sr;

    IF nvl(l_tmp, 0) = 1 THEN
       return 1;
    else
       return 0;
    end if;
end CheckSR;
          

      
  --------------------------------------------------------------------
  --  name:              check_item_control
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     07/07/2013 10:39:52
  --------------------------------------------------------------------
  --  purpose :          CUST494 - Mass Generate Serial Numbers
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  07/07/2013    Dalit A. Raviv    initial build
  --  1.1  29-mAR-2018   DAN Melamed       CHG0042327 Generate Job number to check Make item SN only
  --------------------------------------------------------------------
  FUNCTION get_sn(p_org_id IN NUMBER, p_inv_itm_id IN NUMBER) RETURN VARCHAR2 IS

    l_wip_id        NUMBER := NULL;
    l_group_mark_id NUMBER := NULL;
    l_line_mark_id  NUMBER := NULL;
    l_rev           NUMBER := NULL;
    l_lot           VARCHAR2(30) := NULL;
    l_start_ser     VARCHAR2(30) := NULL;
    l_end_ser       VARCHAR2(30) := NULL;
    l_status        VARCHAR2(10);
    l_err_msg       VARCHAR2(1000);
    l_tmp           NUMBER;


  BEGIN
    -- SN generation
    l_status := inv_serial_number_pub.generate_serials(p_org_id        => p_org_id,
                                                       p_item_id       => p_inv_itm_id,
                                                       p_qty           => 1,
                                                       p_wip_id        => l_wip_id,
                                                       p_group_mark_id => l_group_mark_id,
                                                       p_line_mark_id  => l_line_mark_id,
                                                       p_rev           => l_rev,
                                                       p_lot           => l_lot,
                                                       p_skip_serial   => wip_constants.yes,
                                                       x_start_ser     => l_start_ser,
                                                       x_end_ser       => l_end_ser,
                                                       x_proc_msg      => l_err_msg);

    IF l_status != 0 THEN
      fnd_file.put_line(fnd_file.log,
                        'There was a problem generating serial number: ' ||
                        substr(SQLERRM, 1, 240) || 'Cuoncurrent problem: ' ||
                        l_err_msg);
      RETURN 'ERROR';
    END IF;

    IF l_start_ser IS NULL THEN
      fnd_file.put_line(fnd_file.log,
                        'There was a problem generating serial number: ' ||
                        substr(SQLERRM, 1, 240) || ' - cannot find SN:' ||
                        l_status || ' - ' || l_err_msg);
      RETURN 'ERROR';
    END IF;

    
    l_tmp := checkSR(p_inv_itm_id, l_start_ser); -- CHG0042327 : Function change for checking only for MAKE Items

    IF nvl(l_tmp, 0) = 1 THEN
      fnd_file.put_line(fnd_file.log,
                        'There was a problem generating serial number ' ||
                        substr(SQLERRM, 1, 240) ||
                        ' - Serial number already exists for different item , please contact Oracle operation support');
      RETURN 'ERROR';
    END IF;

    RETURN l_start_ser;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'There was a problem generating serial number: ' ||
                        ' - ' || l_status || ' - ' || l_err_msg || ' - ' ||
                        substr(SQLERRM, 1, 240));
      RETURN 'ERROR';

  END get_sn;

  --------------------------------------------------------------------
  --  name:              generate_sn_main
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     07/07/2013 10:39:52
  --------------------------------------------------------------------
  --  purpose :          CUST494 - Mass Generate Serial Numbers
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  07/07/2013    Dalit A. Raviv    initial build
  --  1.1  13/10/2013    Vitaly            cr870 -- change hard-coded organization
  --------------------------------------------------------------------
  PROCEDURE generate_sn_main(errbuf        OUT VARCHAR2,
                             retcode       OUT NUMBER,
                             p_org_id      IN NUMBER,
                             p_assembly_id IN NUMBER,
                             p_from_job    IN VARCHAR2,
                             p_to_job      IN VARCHAR2) IS

    CURSOR get_pop_c IS
      SELECT we.wip_entity_name job_name,
             wdj.wip_entity_id wip_entity_id,
             wdj.primary_item_id primary_item_id,
             xxinv_utils_pkg.get_item_segment(wdj.primary_item_id,
                                              735 /*90*/) assembly,
             xxinv_utils_pkg.get_item_desc_tl(wdj.primary_item_id,
                                              wdj.organization_id,
                                              NULL) assembly_desc,
             wdj.start_quantity quantity,
             wdj.status_type status,
             xxwip_general_pkg.get_lookup_code_meaning('WIP_JOB_STATUS',
                                                       wdj.status_type) status_meaning,
             wdj.class_code class_code,
             wdj.scheduled_start_date,
             wdj.scheduled_completion_date
        FROM wip_discrete_jobs wdj, wip_entities we
       WHERE wdj.wip_entity_id = we.wip_entity_id
         AND wdj.organization_id = we.organization_id
         AND wdj.job_type = 1 -- Standard job
         AND wdj.status_type IN (1) -- 1 = Unreleased, 3 = Released
         AND wdj.organization_id = p_org_id
         AND ((wdj.primary_item_id = p_assembly_id) OR
             (p_assembly_id IS NULL))
         AND ((we.wip_entity_name BETWEEN p_from_job AND p_to_job) OR
             (p_from_job IS NULL)); -- '24497' and '24548'

    l_check_control VARCHAR2(1);
    l_message       VARCHAR2(1500);
    l_job_name      VARCHAR2(250);
    l_exists        VARCHAR2(5);
    my_exception EXCEPTION;

  BEGIN
    errbuf  := NULL;
    retcode := 0;

    IF (p_assembly_id IS NULL AND p_from_job IS NULL AND p_to_job IS NULL) THEN
      l_message := get_message_text('XXWIP_GENERATE_SN_PARAMS'); -- 'Must enter assembly or job parameters';
      errbuf    := l_message;
      retcode   := 2;
      RAISE my_exception;
    ELSIF (p_from_job IS NULL AND p_to_job IS NOT NULL) OR
          (p_from_job IS NOT NULL AND p_to_job IS NULL) THEN
      l_message := get_message_text('XXWIP_GENERATE_SN_JOB_PARAMS'); -- 'Must enter Both from/to job parameters';
      errbuf    := l_message;
      retcode   := 2;
      RAISE my_exception;
    END IF;

    fnd_file.put_line(fnd_file.output,
                      'Old Job         Job              Assembly           Description                              Start Date           Completion Date');
    fnd_file.put_line(fnd_file.output,
                      '---------------------------------------------------------------------------------------------------------------------------------');
    FOR get_pop_r IN get_pop_c LOOP
      fnd_file.put_line(fnd_file.log, ' -------------');
      fnd_file.put_line(fnd_file.log,
                        'Job name ' || get_pop_r.job_name ||
                        ' for Assembly ' || get_pop_r.assembly);
      fnd_file.put_line(fnd_file.log,
                        'Quantity ' || get_pop_r.quantity || ' Status ' ||
                        get_pop_r.status_meaning || ' Class ' ||
                        get_pop_r.class_code);
      fnd_file.put_line(fnd_file.log,
                        'Scheduled Start Date ' ||
                        get_pop_r.scheduled_start_date ||
                        ' Scheduled Completed Date ' ||
                        get_pop_r.scheduled_completion_date);

      l_job_name := NULL;
      l_exists   := NULL;
      -- 1) check_item_control
      l_check_control := check_item_control(p_org_id,
                                            get_pop_r.primary_item_id);

      IF l_check_control IS NULL THEN
        l_message := get_message_text('XXWIP_GENERATE_SN_ITEM_IN_ORG'); -- 'Item do not exists in organization '
      ELSIF l_check_control = 'L' THEN
        l_message := get_message_text('XXWIP_GENERATE_SN_LOT_ITEM'); -- 'Item is LOT control'
      ELSIF l_check_control = 'N' THEN
        l_message := get_message_text('XXWIP_GENERATE_SN_NOT_CONTROL'); -- 'Item is not serial controlled'
      ELSIF l_check_control = 'S' THEN

        -- 2) validate start quantity
        IF get_pop_r.quantity != 1 THEN
          l_message := get_message_text('XXWIP_GENERATE_SN_START_QTY'); -- 'Jobs quantity should be 1'
        ELSE
          -- 3) check serial number validation -> only if not exists continue to generate SN
          l_exists := get_next_sn_exist(p_org_id, get_pop_r.primary_item_id);
          IF l_exists = 'N' THEN
            -- 4) generate serial number -. only if success update table
            l_job_name := get_sn(p_org_id, get_pop_r.primary_item_id);

            IF l_job_name <> 'ERROR' THEN
              BEGIN
                fnd_file.put_line(fnd_file.log,
                                  'Serial number ' || l_job_name);
                -- do update to wip table with the return l_job_name (serial number)
                UPDATE wip_entities we
                   SET we.wip_entity_name = l_job_name
                 WHERE we.wip_entity_id = get_pop_r.wip_entity_id;

                UPDATE wip_discrete_jobs wdj
                   SET wdj.attribute3 = 'YES'
                 WHERE wdj.wip_entity_id = get_pop_r.wip_entity_id;

                COMMIT;

                fnd_file.put_line(fnd_file.output,
                                  get_pop_r.job_name || '          ' ||
                                  l_job_name || '          ' ||
                                  get_pop_r.assembly || '          ' ||
                                  get_pop_r.assembly_desc || '          ' ||
                                  to_char(get_pop_r.scheduled_start_date,
                                          'DD-MON-YYYY') || '          ' ||
                                  to_char(get_pop_r.scheduled_completion_date,
                                          'DD-MON-YYYY'));
              EXCEPTION
                WHEN OTHERS THEN
                  l_message := get_message_text('XXWIP_GENERATE_SN_UPD'); -- 'Problem to update Job '
                  retcode   := 1;
              END;
            ELSE
              retcode := 1;
              errbuf  := 'ERR';
            END IF; -- l_job_name
          ELSE
            l_message := get_message_text('XXWIP_GENERATE_SN_EXISTS'); -- 'job number already exists ' 'Wip Job name allredy exists'
          END IF; -- l_exists
        END IF; -- start quantity
      END IF; -- check_control
    END LOOP;

  EXCEPTION
    WHEN my_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'Gen exception - generate_sn_main - ' ||
                 substr(SQLERRM, 1, 240);
      retcode := 2;
  END generate_sn_main;

END xxwip_generate_sn_pkg;
/
