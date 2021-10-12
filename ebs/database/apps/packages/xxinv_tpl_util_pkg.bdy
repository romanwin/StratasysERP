CREATE OR REPLACE PACKAGE BODY xxinv_tpl_util_pkg IS
  ------------------------------------------------------------------
  -- $Header: xxinv_tpl_util_pkg   $
  ------------------------------------------------------------------
  -- Package: xxinv_tpl_util_pkg
  -- Created:
  -- Author:  Vitaly
  ------------------------------------------------------------------
  -- Purpose:
  ------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ----------------------------
  --     1.0  29.10.13   Vitaly         initial build
  --     1.1 6.10.14     Yuval tal      chg0032515 : modify onhand_compare 
  ------------------------------------------------------------------

  ---------------------------------------------------------------------------
  -- update_hr_locations
  ---------------------------------------------------------------------------
  -- Purpose: Concurrent program XX INV TPL Sync Location names/XXINVTPLLOC
  ---------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -----------------------------------
  -- 1.0      07.10.2013  Vitaly          initial build - sync background processes  cr1045
  ---------------------------------------------------------------------------
  PROCEDURE update_hr_locations(errbuf          OUT VARCHAR2,
                                retcode         OUT VARCHAR2,
                                p_days          NUMBER,
                                p_location_code VARCHAR2) IS
  
    CURSOR c_get_locations IS
      SELECT v.location_id,
             v.location_code,
             v.object_version_number,
             (SELECT MAX(hp1.party_name)
                FROM po_location_associations_all p,
                     hz_cust_site_uses_all        hcsu1,
                     hz_cust_acct_sites_all       hcas1,
                     hz_cust_accounts             hca1,
                     hz_parties                   hp1
               WHERE p.location_id = v.location_id
                 AND hcsu1.site_use_id = p.site_use_id
                 AND hcas1.cust_acct_site_id(+) = hcsu1.cust_acct_site_id
                 AND hca1.cust_account_id(+) = hcas1.cust_account_id
                 AND hp1.party_id(+) = hca1.party_id) || ' - ' ||
             
             address_line_1 || ',' || address_line_2 || ',' ||
             address_line_3 || ',' || town_or_city description
        FROM hr_locations_v v
       WHERE v.last_update_date > (SYSDATE - p_days)
         AND v.location_code = nvl(p_location_code, v.location_code) ---parameter
         AND location_code LIKE 'CSP%'
         AND EXISTS
       (SELECT 1
                FROM po_location_associations_all p,
                     hz_cust_site_uses_all        hcsu1,
                     hz_cust_acct_sites_all       hcas1,
                     hz_cust_accounts             hca1,
                     hz_parties                   hp1
               WHERE p.location_id = v.location_id
                 AND hcsu1.site_use_id = p.site_use_id
                 AND hcas1.cust_acct_site_id(+) = hcsu1.cust_acct_site_id
                 AND hca1.cust_account_id(+) = hcas1.cust_account_id
                 AND hp1.party_id = hca1.party_id
                 AND hp1.party_type = 'PERSON');
  
    v_step VARCHAR2(100);
    stop_processing EXCEPTION;
    v_error_message VARCHAR2(3000);
  
    v_success_updated_loc_counter NUMBER := 0;
    v_errors_updating_loc_counter NUMBER := 0;
  
  BEGIN
    v_step  := 'Step 0';
    errbuf  := 'Success';
    retcode := '0';
    fnd_file.put_line(fnd_file.log, '============= PARAMETERS ==================');
    IF p_days IS NULL THEN
      v_error_message := 'Error: missing parameter p_days';
      RAISE stop_processing;
    ELSE
      fnd_file.put_line(fnd_file.log, 'p_days=' || p_days);
    END IF;
    IF p_location_code IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log, 'p_location_code=' || p_location_code);
    END IF;
  
    fnd_file.put_line(fnd_file.log, '===========================================');
  
    FOR location_rec IN c_get_locations LOOP
      ---======================= LOOP ===============================
      BEGIN
        hr_location_api.update_location(p_effective_date => SYSDATE, p_location_id => location_rec.location_id, p_object_version_number => location_rec.object_version_number, p_description => location_rec.description);
        v_success_updated_loc_counter := v_success_updated_loc_counter + 1;
      
      EXCEPTION
        WHEN OTHERS THEN
          v_error_message := substr('+++++++++++++ API ERROR when updating location ' ||
                                    location_rec.location_code ||
                                    ', location_id=' ||
                                    location_rec.location_id || ' : ' ||
                                    SQLERRM, 1, 200);
          fnd_file.put_line(fnd_file.log, v_error_message);
          v_errors_updating_loc_counter := v_errors_updating_loc_counter + 1;
      END;
      ---================== the end of LOOP ============================
    END LOOP;
  
    fnd_file.put_line(fnd_file.log, '++++++++++++++++ THIS PROGRAM IS COMPLETED SUCCESSFULLY ++++++++++++++++');
    fnd_file.put_line(fnd_file.log, '++++++++++++++++ RESULTS: ++++++++++++++++++++++++++++++++++++++++++++++');
    IF v_success_updated_loc_counter > 0 THEN
      fnd_file.put_line(fnd_file.log, v_success_updated_loc_counter ||
                         ' locations were SUCCESSFULLY updated +++++++++++++++++++++');
    END IF;
    IF v_errors_updating_loc_counter > 0 THEN
      fnd_file.put_line(fnd_file.log, v_errors_updating_loc_counter ||
                         ' ERRORS when updating hr_locations +++++++++++++++++++++');
      errbuf  := v_errors_updating_loc_counter ||
                 ' ERRORS when updating hr_locations,  ' ||
                 v_success_updated_loc_counter ||
                 ' hr_locations were SUCCESSFULLY updated';
      retcode := '2';
    END IF;
  EXCEPTION
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.log, v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
      ROLLBACK;
    WHEN OTHERS THEN
      v_error_message := substr('Unexpected Error in procedure update_hr_locations ' ||
                                v_step || ': ' || SQLERRM, 1, 200);
      fnd_file.put_line(fnd_file.log, v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
      ROLLBACK;
    
  END update_hr_locations;

  ---------------------------------------------------------------------------
  -- onhand_compare
  ---------------------------------------------------------------------------
  -- Purpose: This procedure will be called from BPEL process after reading TPL data file
  --            ( records with rec_type='TPL' will be inserted before this procedure )
  ---------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -----------------------------------
  -- 1.0      18.02.2014  Vitaly          initial build - sync background processes  cr1045

  -- 1.1      6.10.14     Yuval tal       chg0032515 : fix update of last ind adding source_code
  ---------------------------------------------------------------------------
  PROCEDURE onhand_compare(errbuf        OUT VARCHAR2,
                           retcode       OUT VARCHAR2,
                           p_source_code VARCHAR2,
                           p_bpel_id     NUMBER) IS
    v_step        VARCHAR2(100);
    v_log_message VARCHAR2(3000);
    stop_processing EXCEPTION;
  
    v_user_id                     NUMBER;
    v_resp_id                     NUMBER;
    v_resp_appl_id                NUMBER;
    v_organization_id             NUMBER;
    v_err_code                    NUMBER;
    v_error_message               VARCHAR2(3000);
    v_oracle_onhand_inserted_cntr NUMBER := 0;
    v_tpl_inserted_cntr           NUMBER := 0;
    v_total_diff_inserted_cntr    NUMBER := 0; ---Total num of DIFF records inserted
    v_updated_rec_cntr            NUMBER := 0;
  
  BEGIN
  
    DELETE FROM xxinv_tpl_onhand_qty t
     WHERE t.creation_date < SYSDATE - 60;
  
    COMMIT;
  
    v_step  := 'Step 0';
    errbuf  := 'Success';
    retcode := '0';
  
    IF p_source_code IS NULL THEN
      v_error_message := 'Error: missing parameter P_SOURCE_CODE';
      RAISE stop_processing;
    ELSE
      v_log_message := 'p_source_code=''' || p_source_code || '''';
      ----fnd_file.put_line(fnd_file.log, v_log_message);
      dbms_output.put_line(v_log_message);
    END IF;
  
    IF p_bpel_id IS NULL THEN
      v_error_message := 'Error: missing parameter P_BPEL_ID';
      RAISE stop_processing;
    ELSE
      v_log_message := 'p_bpel_id=' || p_bpel_id;
      ----fnd_file.put_line(fnd_file.log, v_log_message);
      dbms_output.put_line(v_log_message);
    END IF;
  
    v_step := 'Step 10';
    --- Get user details
    xxinv_trx_in_pkg.get_user_details(p_user_name => p_source_code, ---parameter
                                      p_user_id => v_user_id, -- OUT
                                      p_resp_id => v_resp_id, -- OUT
                                      p_resp_appl_id => v_resp_appl_id, -- OUT
                                      p_organization_id => v_organization_id, -- OUT
                                      p_err_code => v_err_code, -- OUT
                                      p_err_message => v_error_message); -- OUT
    IF v_err_code <> 0 THEN
      RAISE stop_processing;
    END IF;
    v_log_message := 'organization_id=' || v_organization_id;
    ---fnd_file.put_line(fnd_file.log, v_log_message);
    dbms_output.put_line(v_log_message);
  
    ---TPL Data from TPL data file will be inserted into table XXINV_TPL_ONHAND_QTY with REC_TYPE=’TPL’
    ------------ by BPEL process BEFORE this procedure
  
    v_step := 'Step 20';
    --- Get on-hand data for this organization from database and insert it into table XXINV_TPL_ONHAND_QTY
    -------- records with REC_TYPE='ORACLE'
    INSERT INTO xxinv_tpl_onhand_qty
      (bpel_id,
       last_ind, ---Y for last batch
       source_code, --- for example: TPL.DE
       rec_type, --- ORACLE /TPL /DIFF
       organization_id, ----------KEY (for MINUS)---------------------
       subinventory_code, --------KEY (for MINUS)---------------------
       locator_id, ---------------KEY (for MINUS)---------------------
       locator,
       inventory_item_id, --------KEY (for MINUS)---------------------
       item_code,
       lot_number, ---------------KEY (for MINUS)---------------------
       serial_number, ------------KEY (for MINUS)---------------------
       qty, --for ORACLE and TPL
       oracle_qty,
       ---tpl_qty,
       ---diff_qty,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       last_update_login)
      SELECT p_bpel_id,
             'Y' last_ind,
             p_source_code source_code, --- TPL.DE
             'ORACLE' rec_type, --- ORACLE /TPL /DIFF
             a.organization_id,
             a.subinventory_code,
             a.locator_id,
             a.locator,
             a.inventory_item_id,
             a.item_code,
             a.lot_number,
             a.serial_number,
             a.qty, --for ORACLE and TPL
             a.qty oracle_qty,
             ---TPL_QTY     NUMBER,
             ---DIFF_QTY    NUMBER,
             SYSDATE                  creation_date,
             fnd_global.user_id       created_by,
             SYSDATE                  last_update_date,
             fnd_global.user_id       last_updated_by,
             fnd_global.conc_login_id last_update_login
        FROM xxinv_tpl_onhand_qty_summary_v a
       WHERE a.organization_id = v_organization_id; ---organization
    ---AND (a.serial_number IN ('p13715', 'J01036', 'WJ133400636EU') ----------------------SERIAL
    ---    OR a.lot_number IN
    ---    ('9977-02257', '9974-04018', '9914-03214', '9866-03269') --------LOT
    ---    OR a.item_code IN ('10007800', '10008900', '100129-0003')); ------no serial no lot
    v_oracle_onhand_inserted_cntr := SQL%ROWCOUNT;
    v_log_message                 := '======= Oracle On-Hand data: ' ||
                                     v_oracle_onhand_inserted_cntr ||
                                     ' records inserted into XXINV_TPL_ONHAND_QTY for organization_id=' ||
                                     v_organization_id || ', bpel_id=' ||
                                     p_bpel_id;
    ----fnd_file.put_line(fnd_file.log, v_log_message);
    dbms_output.put_line(v_log_message);
    COMMIT;
  
    v_step := 'Step 50';
    --- Select differences between ORACLE and TPL data
    --------and insert it into table XXINV_TPL_ONHAND_QTY as records with REC_TYPE='DIFF'
    INSERT INTO xxinv_tpl_onhand_qty
      (bpel_id,
       last_ind, ---Y for last bpel process
       source_code, --- TPL.DE
       rec_type, --- ORACLE /TPL /DIFF
       organization_id, ----------KEY (for MINUS)---------------------
       subinventory_code, --------KEY (for MINUS)---------------------
       locator_id, ---------------KEY (for MINUS)---------------------
       locator,
       inventory_item_id, --------KEY (for MINUS)---------------------
       item_code,
       lot_number, ---------------KEY (for MINUS)---------------------
       serial_number, ------------KEY (for MINUS)---------------------
       qty, --for ORACLE and TPL
       oracle_qty,
       tpl_qty,
       diff_qty,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       last_update_login)
      SELECT p_bpel_id,
             'Y' last_ind,
             p_source_code source_code, --- TPL.DE
             'DIFF' rec_type,
             nvl(diff_tab.oracle_organization_id, diff_tab.tpl_organization_id) organization_id,
             nvl(diff_tab.oracle_subinventory_code, diff_tab.tpl_subinventory_code) subinventory_code,
             nvl(diff_tab.oracle_locator_id, diff_tab.tpl_locator_id) locator_id,
             nvl(diff_tab.oracle_locator, diff_tab.tpl_locator) locator,
             nvl(diff_tab.oracle_inventory_item_id, diff_tab.tpl_inventory_item_id) inventory_item_id,
             
             nvl(nvl(diff_tab.oracle_item_code, diff_tab.tpl_item_code), xxinv_utils_pkg.get_item_segment(nvl(diff_tab.oracle_inventory_item_id, diff_tab.tpl_inventory_item_id), 91)) item_code,
             
             nvl(diff_tab.oracle_lot_number, diff_tab.tpl_lot_number) lot_number,
             nvl(diff_tab.oracle_serial_number, diff_tab.tpl_serial_number) serial_number,
             NULL qty, --for ORACLE and TPL
             diff_tab.oracle_qty,
             diff_tab.tpl_qty,
             nvl(diff_tab.oracle_qty, 0) - nvl(diff_tab.tpl_qty, 0) diff_qty,
             SYSDATE creation_date,
             fnd_global.user_id created_by,
             SYSDATE last_update_date,
             fnd_global.user_id last_updated_by,
             fnd_global.conc_login_id last_update_login
        FROM (SELECT oracle.organization_id   oracle_organization_id,
                     oracle.subinventory_code oracle_subinventory_code,
                     oracle.locator_id        oracle_locator_id,
                     oracle.locator           oracle_locator,
                     oracle.inventory_item_id oracle_inventory_item_id,
                     oracle.item_code         oracle_item_code,
                     oracle.lot_number        oracle_lot_number,
                     oracle.serial_number     oracle_serial_number,
                     oracle.qty               oracle_qty,
                     tpl.qty                  tpl_qty,
                     tpl.organization_id      tpl_organization_id,
                     tpl.subinventory_code    tpl_subinventory_code,
                     tpl.locator_id           tpl_locator_id,
                     tpl.locator              tpl_locator,
                     tpl.inventory_item_id    tpl_inventory_item_id,
                     tpl.item_code            tpl_item_code,
                     tpl.lot_number           tpl_lot_number,
                     tpl.serial_number        tpl_serial_number
                FROM (SELECT *
                        FROM xxinv_tpl_onhand_qty a
                       WHERE a.rec_type = 'ORACLE'
                         AND a.bpel_id = p_bpel_id) oracle
                FULL OUTER JOIN (SELECT *
                                  FROM xxinv_tpl_onhand_qty b
                                 WHERE b.rec_type = 'TPL'
                                   AND b.bpel_id = p_bpel_id) tpl
                  ON oracle.organization_id = tpl.organization_id
                 AND oracle.subinventory_code = tpl.subinventory_code
                 AND nvl(oracle.locator_id, -777) =
                     nvl(tpl.locator_id, -777)
                 AND oracle.inventory_item_id = tpl.inventory_item_id
                 AND nvl(oracle.lot_number, 'ZZZ') =
                     nvl(tpl.lot_number, 'ZZZ')
                 AND nvl(oracle.serial_number, 'ZZZ') =
                     nvl(tpl.serial_number, 'ZZZ')) diff_tab
       WHERE nvl(diff_tab.oracle_qty, 0) <> nvl(diff_tab.tpl_qty, 0);
  
    v_total_diff_inserted_cntr := SQL%ROWCOUNT;
    IF v_total_diff_inserted_cntr > 0 THEN
      v_log_message := '********** ' || v_total_diff_inserted_cntr ||
                       ' diff. records inserted **********';
      ---fnd_file.put_line(fnd_file.log, v_log_message);
      dbms_output.put_line(v_log_message);
    END IF;
    COMMIT;
  
    v_step := 'Step 100';
    --- Update XXINV_TPL_ONHAND_QTY.LAST_IND='N' for previous bpel processes
    UPDATE xxinv_tpl_onhand_qty a
       SET a.last_ind = 'N'
     WHERE a.bpel_id != p_bpel_id ---current bpel_id
       AND a.last_ind = 'Y'
       AND a.source_code = p_source_code;
    v_updated_rec_cntr := SQL%ROWCOUNT;
    v_log_message      := v_updated_rec_cntr ||
                          ' records updated XXINV_TPL_ONHAND_QTY.LAST_IND=''N''';
    ---fnd_file.put_line(fnd_file.log, v_log_message);
    dbms_output.put_line(v_log_message);
    COMMIT;
  
  EXCEPTION
    WHEN stop_processing THEN
      ---fnd_file.put_line(fnd_file.log, v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
      ROLLBACK;
    WHEN OTHERS THEN
      v_error_message := substr('Unexpected Error in procedure onhand_compare ' ||
                                v_step || ': ' || SQLERRM, 1, 200);
      ---fnd_file.put_line(fnd_file.log, v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
      ROLLBACK;
  END onhand_compare;
  -------------------------------------------------------------
END xxinv_tpl_util_pkg;
/
