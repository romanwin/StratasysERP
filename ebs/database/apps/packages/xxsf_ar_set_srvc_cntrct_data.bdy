CREATE OR REPLACE PACKAGE BODY xxsf_ar_set_srvc_cntrct_data IS
  --------------------------------------------------------------------
  --  customization code: CHG0035139
  --  name:               XXSF_AR_SET_SRVC_CNTRCT_DATA
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      25/05/2015
  --  Description:        Several changes regarding entering service contract through initial sale
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/05/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------

  ----------------------------------------------------------------------
  --  customization code: CHG0035139
  --  name:               main
  --  create by:          Michal Tzvik
  --  creation date:      25/05/2015
  --  Purpose :           CHG0035139
  --
  --                      Populate DFFs in AR invoice line for service contract items
  --                      If they are empty, with values from SalesForce and IB.
  --                      Concurrent executable name: XXSF_AR_SET_SRVC_CNTRCT_DATA
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/05/2015    Michal Tzvik    initial build
  ---------------------------------------------------------------------- 
  PROCEDURE main(errbuf  OUT VARCHAR2,
                 retcode OUT VARCHAR2) IS
  
    l_cnt   NUMBER := 0;
    l_cnt_e NUMBER := 0;
  
    CURSOR c_lines IS(
      SELECT sf_cntr.startdate,
             sf_cntr.enddate,
             xcii.serial_number,
             rctla.customer_trx_line_id
      FROM   ra_customer_trx_lines_all rctla,
             xxsf_servicecontract      sf_cntr,
             xxsf_csi_item_instances   xcii
      WHERE  1 = 1
      AND    xxoe_utils_pkg.is_item_service_contract(rctla.inventory_item_id) = 'Y'
      AND    (rctla.attribute12 IS NULL OR rctla.attribute13 IS NULL)
      AND    rctla.interface_line_context = 'ORDER ENTRY'
      AND    sf_cntr.line_item_oe_id__c = rctla.interface_line_attribute6 --oe line id
      AND    xcii.attribute12 = sf_cntr.serv_machine__c
      AND    sf_cntr.service_contract_type__c != 'Warranty'
      AND    xcii.attribute3 = 'Y');
  BEGIN
    retcode := '0';
    errbuf  := '';
  
    FOR r_line IN c_lines LOOP
      BEGIN
        -- No API exists for updating ar invoice line, so update is used
        UPDATE ra_customer_trx_lines_all rctla
        SET    rctla.attribute12 = to_char(to_date(substr(r_line.startdate, 0, 9), 'DD-MON-YY '), 'YYYY/MM/DD') ||
                                   ' 00:00:00',
               rctla.attribute13 = to_char(to_date(substr(r_line.enddate, 0, 9), 'DD-MON-YY '), 'YYYY/MM/DD') ||
                                   ' 00:00:00',
               rctla.attribute14 = r_line.serial_number
        WHERE  rctla.customer_trx_line_id = r_line.customer_trx_line_id;
        l_cnt := l_cnt + 1;
      EXCEPTION
        WHEN OTHERS THEN
          l_cnt_e := l_cnt_e + 1;
          retcode := '1';
          errbuf  := 'Process failed. See log file for details';
          fnd_file.put_line(fnd_file.log, 'Failed to update invoice line id ' ||
                             r_line.customer_trx_line_id || ': ' ||
                             SQLERRM);
      END;
    END LOOP;
  
    COMMIT;
  
    fnd_file.put_line(fnd_file.log, l_cnt || ' lines where updated');
    fnd_file.put_line(fnd_file.log, l_cnt_e || ' lines failed with errors.');
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '1';
      errbuf  := 'Unexpected error:' || SQLERRM;
  END main;

END xxsf_ar_set_srvc_cntrct_data;
/
