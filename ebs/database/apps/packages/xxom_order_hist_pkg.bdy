CREATE OR REPLACE PACKAGE BODY xxom_order_hist_pkg AS
  ----------------------------------------------------------------------------------
  --  name:              xxom_order_hist_pkg
  --  create by:         Kundan Bhagat
  --  Revision:          1.0
  --  creation date:     10/04/2015
  ----------------------------------------------------------------------------------
  --  purpose : CHANGE - CHG0034800
  --           This package is used to fetch Order history information (Header,Line and shipment).
  -- modification history
  ----------------------------------------------------------------------------------
  --  ver   date               name                             desc
  --  1.0   10/04/2015    Kundan Bhagat  CHANGE CHG0034944  initial build
  ------------------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0034800
  --          This function checks whether customer is eCommerce customer or not.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  10/04/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_ecomm_customer(p_cust_account_id IN NUMBER) RETURN BOOLEAN IS
    l_eccom_cust NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_eccom_cust
    FROM   hz_cust_accounts      hca_ecomm,
           hz_cust_account_roles hcar_ecomm,
           hz_relationships      hr_ecomm,
           hz_parties            hp_contact_ecomm,
           hz_parties            hp_cust_ecomm,
           hz_org_contacts       hoc_ecomm,
           hz_party_sites        hps_ecomm
    WHERE  hp_cust_ecomm.party_id = hca_ecomm.party_id
    AND    hps_ecomm.party_id(+) = hcar_ecomm.party_id
    AND    nvl(hps_ecomm.identifying_address_flag, 'Y') = 'Y'
    AND    hca_ecomm.cust_account_id = hcar_ecomm.cust_account_id
    AND    hcar_ecomm.role_type = 'CONTACT'
    AND    hcar_ecomm.cust_acct_site_id IS NULL
    AND    hcar_ecomm.party_id = hr_ecomm.party_id
    AND    hr_ecomm.subject_type = 'PERSON'
    AND    hr_ecomm.subject_id = hp_contact_ecomm.party_id
    AND    hp_contact_ecomm.status = 'A'
    AND    hp_cust_ecomm.status = 'A'
    AND    nvl(hoc_ecomm.status, 'A') = 'A'
    AND    hcar_ecomm.status = 'A'
    AND    hca_ecomm.status = 'A'
    AND    hoc_ecomm.party_relationship_id = hr_ecomm.relationship_id
    AND    hoc_ecomm.attribute5 = 'Y'
    AND    nvl(hps_ecomm.status, 'A') = 'A'
    AND    hca_ecomm.cust_account_id = p_cust_account_id;
  
    IF l_eccom_cust > 0 THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END check_ecomm_customer;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0034800
  --          This procedure generates csv files for Order History information (Header,Line and shipment).
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  10/04/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE order_history_proc(x_retcode OUT NUMBER,
                               x_errbuf  OUT VARCHAR2) IS
    CURSOR cur_header_info IS
      SELECT oohv.sold_to_org_id cust_acc_id,
             oohv.header_id      header_id,
             oohv.order_number   order_number,
             --  to_char(oohv.ordered_date, 'MON DD, YYYY HH:MI:SS PM') ordered_date,
             to_char(oohv.ordered_date, 'YYYY-MM-DD HH24:MI:SS') ordered_date,
             oohv.cust_po_number cust_po_number,
             oohv.invoice_to_address1 || ',' || oohv.invoice_to_address2 || ',' ||
             oohv.invoice_to_address3 || ',' || oohv.invoice_to_address4 || ',' ||
             oohv.invoice_to_address5 invoice_to_address,
             oohv.ship_to_address1 || ',' || oohv.ship_to_address2 || ',' ||
             oohv.ship_to_address3 || ',' || oohv.ship_to_address4 || ',' ||
             oohv.ship_to_address5 ship_to_address,
             oohv.invoice_to_contact invoice_to_contact,
             oohv.sold_to_contact sold_to_contact,
             oohv.ship_to_contact ship_to_contact,
             oohv.terms terms,
             (SELECT oos.NAME
              FROM   oe_order_sources oos
              WHERE  oos.order_source_id = ooha.order_source_id) chanel,
             oohv.flow_status_code status,
             (SELECT round(SUM(oola.unit_selling_price * oola.ordered_quantity), 2)
              FROM   oe_order_lines_all oola,
                     mtl_system_items_b msib
              WHERE  oola.header_id = oohv.header_id
              AND    msib.inventory_item_id = oola.inventory_item_id
              AND    msib.organization_id = oola.ship_from_org_id
              AND    msib.segment1 <> 'FREIGHT') order_sub_total,
             nvl((SELECT round(SUM(oola.unit_selling_price * oola.ordered_quantity), 2)
                 FROM   oe_order_lines_all oola,
                        mtl_system_items_b msib
                 WHERE  oola.header_id = oohv.header_id
                 AND    msib.inventory_item_id = oola.inventory_item_id
                 AND    msib.organization_id = oola.ship_from_org_id
                 AND    msib.segment1 = 'FREIGHT'), 0) +
             nvl(oe_totals_grp.get_order_total(oohv.header_id, NULL, 'CHARGES'), 0) total_freight_handling,
             oe_totals_grp.get_order_total(oohv.header_id, NULL, 'TAXES') total_tax,
             oe_totals_grp.get_order_total(oohv.header_id, NULL, 'ALL') grand_total
      FROM   oe_order_headers_v       oohv,
             oe_order_headers_all     ooha,
             oe_transaction_types_all otta
      WHERE  oohv.header_id = ooha.header_id
      AND    oohv.header_id NOT IN (SELECT header_id
                                    FROM   oe_order_headers_v       oohv,
                                           oe_order_sources         oos,
                                           oe_transaction_types_all otta
                                    WHERE  oos.NAME <> 'eCommerce Order'
                                    AND    oohv.order_source_id = oos.order_source_id
                                    AND    oohv.flow_status_code = 'CANCELLED'
                                    AND    oohv.order_type_id = otta.transaction_type_id
                                    AND    otta.attribute15 = 'Y')
      AND    oohv.ordered_date BETWEEN add_months(SYSDATE, -6) AND SYSDATE
      AND    ooha.order_type_id = otta.transaction_type_id
      AND    otta.attribute15 = 'Y';
  
    -- Cursor to fetch order lines information
    CURSOR cur_line_info IS
      SELECT oolv.header_id line_header_id,
             oolv.line_id line_id,
             oohv.sold_to_org_id cust_acc_id,
             oolv.ordered_item item_number,
             msib.description item_description,
             msib.inventory_item_id item_id,
             xxinv_utils_pkg.get_category_segment('SEGMENT6', (SELECT mcs.category_set_id
                                                    FROM   mtl_category_sets mcs
                                                    WHERE  mcs.category_set_name =
                                                           'Product Hierarchy'), oolv.inventory_item_id) item_technology,
             oolv.ordered_quantity ordered_quantity,
             oolv.unit_selling_price unit_price,
             oolv.unit_selling_price * oolv.ordered_quantity extended_price,
             oolv.tax_value tax,
             flvv.attribute1 status
      FROM   oe_order_lines_v         oolv,
             oe_order_headers_v       oohv,
             oe_order_headers_all     ooha,
             mtl_system_items_b       msib,
             fnd_lookup_values_vl     flvv,
             oe_transaction_types_all otta
      WHERE  oolv.header_id = oohv.header_id
      AND    oohv.header_id = ooha.header_id
      AND    oohv.header_id NOT IN (SELECT header_id
                                    FROM   oe_order_headers_v       oohv,
                                           oe_order_sources         oos,
                                           oe_transaction_types_all otta
                                    WHERE  oos.NAME <> 'eCommerce Order'
                                    AND    oohv.order_source_id = oos.order_source_id
                                    AND    oohv.flow_status_code = 'CANCELLED'
                                    AND    oohv.order_type_id = otta.transaction_type_id
                                    AND    otta.attribute15 = 'Y')
      AND    ooha.order_type_id = otta.transaction_type_id
      AND    otta.attribute15 = 'Y'
      AND    oohv.ordered_date BETWEEN add_months(SYSDATE, -6) AND SYSDATE
      AND    oolv.inventory_item_id = msib.inventory_item_id
      AND    oolv.ship_from_org_id = msib.organization_id
      AND    flvv.lookup_code = oolv.flow_status_code
      AND    flvv.lookup_type = 'LINE_FLOW_STATUS'
      AND    msib.segment1 <> 'FREIGHT';
  
    -- Cursor to fetch order line shipment information
    CURSOR cur_line_ship IS
      SELECT wdlsv.source_line_id     ship_line_id,
             wdlsv.delivery_detail_id ship_id,
             oohv.sold_to_org_id      cust_acc_id,
             --  to_char(wdlsv.date_shipped, 'MON DD, YYYY HH:MI:SS PM') ship_date,
             to_char(wdlsv.date_shipped, 'YYYY-MM-DD HH24:MI:SS') ship_date,
             (SELECT carrier_name
              FROM   wsh_carriers_v
              WHERE  carrier_id = wdd.carrier_id) freight_carrier,
             (SELECT meaning
              FROM   fnd_lookup_values flv
              WHERE  flv.lookup_type = 'SHIP_METHOD'
              AND    flv.lookup_code = wdlsv.ship_method_code
              AND    flv.enabled_flag = 'Y'
              AND    flv.LANGUAGE = userenv('LANG')) shipping_method,
             wdlsv.tracking_number tracking_number,
             (SELECT SUM(oolv.shipped_quantity)
              FROM   oe_order_lines_v oolv
              WHERE  oolv.header_id = oohv.header_id
              AND    oolv.line_id = wdlsv.source_line_id) shipped_qty
      FROM   wsh_delivery_line_status_v wdlsv,
             wsh_delivery_details       wdd,
             oe_order_headers_v         oohv,
             oe_order_lines_v           oolv,
             oe_transaction_types_all   otta
      WHERE  wdlsv.source_header_id = oohv.header_id
      AND    oohv.header_id = oolv.header_id
      AND    wdlsv.source_line_id = oolv.line_id
      AND    wdlsv.source_header_id NOT IN
             (SELECT header_id
               FROM   oe_order_headers_v       oohv,
                      oe_order_sources         oos,
                      oe_transaction_types_all otta
               WHERE  oos.NAME <> 'eCommerce Order'
               AND    oohv.order_source_id = oos.order_source_id
               AND    oohv.flow_status_code = 'CANCELLED'
               AND    oohv.order_type_id = otta.transaction_type_id
               AND    otta.attribute15 = 'Y')
      AND    oohv.order_type_id = otta.transaction_type_id
      AND    otta.attribute15 = 'Y'
      AND    oohv.ordered_date BETWEEN add_months(SYSDATE, -6) AND SYSDATE
      AND    oolv.ordered_item <> 'FREIGHT'
      AND    wdd.delivery_detail_id = wdlsv.delivery_detail_id;
  
    v_file_header        utl_file.file_type;
    v_file_line          utl_file.file_type;
    v_file_shipment      utl_file.file_type;
    l_org_id             NUMBER;
    l_channel            VARCHAR2(200);
    l_fname_header       VARCHAR2(1000);
    l_fname_line         VARCHAR2(1000);
    l_fname_ship         VARCHAR2(1000);
    l_fname_header_tmp   VARCHAR2(1000);
    l_fname_line_tmp     VARCHAR2(1000);
    l_fname_ship_tmp     VARCHAR2(1000);
    l_date               VARCHAR2(200);
    l_directory_path     VARCHAR2(200);
    l_error_message      VARCHAR2(32767) := '';
    l_mail_list          VARCHAR2(500);
    l_request_id         NUMBER := fnd_global.conc_request_id;
    l_requestor          VARCHAR2(100);
    l_program_short_name VARCHAR2(100);
    l_data               VARCHAR(2000) := '';
    l_err_code           NUMBER;
    l_err_msg            VARCHAR2(200);
    file_rename_excp EXCEPTION;
    l_header_count NUMBER := 0;
    l_line_count   NUMBER := 0;
    l_ship_count   NUMBER := 0;
  BEGIN
    -- To fetch organization id
    SELECT hro.organization_id
    INTO   l_org_id
    FROM   hr_operating_units    hro,
           hr_organization_units hru
    WHERE  hro.organization_id = hru.organization_id
    AND    hru.attribute7 = 'Y';
  
    l_date := to_char(SYSDATE, 'dd-MON-rrrr-hh-mi-ss');
    -- initialize environment
    mo_global.set_policy_context('S', l_org_id);
  
    l_fname_header     := 'order_header_' || l_date || '.csv';
    l_fname_line       := 'order_line_' || l_date || '.csv';
    l_fname_ship       := 'order_ship_' || l_date || '.csv';
    l_fname_header_tmp := 'order_header_' || l_date || '.csv.tmp';
    l_fname_line_tmp   := 'order_line_' || l_date || '.csv.tmp';
    l_fname_ship_tmp   := 'order_ship_' || l_date || '.csv.tmp';
    l_directory_path   := 'XXECOMM_OUT_DIR';
  
    l_error_message := 'Error Occured while getting Notification Details for Request ID :' ||
                       l_request_id;
    SELECT fcrsv.requestor,
           fcrsv.program_short_name
    INTO   l_requestor,
           l_program_short_name
    FROM   fnd_conc_req_summary_v fcrsv
    WHERE  fcrsv.request_id = l_request_id;
  
    l_data := 'Data Directory:' || l_directory_path || chr(10) || 'Requestor:' ||
              l_requestor;
  
    -- Generate Order header csv file
    l_error_message := ' Error Occured while Deriving Order Headers information';
    v_file_header   := utl_file.fopen(location => l_directory_path, filename => l_fname_header_tmp, open_mode => 'w');
    /* This will create the heading in order header csv file */
    l_error_message := 'Error Occured in UTL_FILE.PUT_LINE (Order Header): Headers';
    utl_file.put_line(v_file_header, 'cust_acc_id|header_id|order_number|ordered_date|cust_po_number|invoice_to_address|ship_to_address|invoice_to_contact|sold_to_contact|ship_to_contact|terms|chanel|status|order_sub_total|total_freight_handling|total_tax|grand_total');
  
    FOR cur_rec_header IN cur_header_info LOOP
      IF check_ecomm_customer(p_cust_account_id => cur_rec_header.cust_acc_id) THEN
        IF cur_rec_header.chanel <> 'eCommerce Order' THEN
          l_channel := NULL;
        ELSE
          l_channel := 'WEB';
        END IF;
        utl_file.put_line(v_file_header, cur_rec_header.cust_acc_id || '|' ||
                           cur_rec_header.header_id || '|' ||
                           cur_rec_header.order_number || '|' ||
                           cur_rec_header.ordered_date || '|' ||
                           cur_rec_header.cust_po_number || '|' ||
                           cur_rec_header.invoice_to_address || '|' ||
                           cur_rec_header.ship_to_address || '|' ||
                           cur_rec_header.invoice_to_contact || '|' ||
                           cur_rec_header.sold_to_contact || '|' ||
                           cur_rec_header.ship_to_contact || '|' ||
                           cur_rec_header.terms || '|' || l_channel || '|' ||
                           cur_rec_header.status || '|' ||
                           cur_rec_header.order_sub_total || '|' ||
                           cur_rec_header.total_freight_handling || '|' ||
                           cur_rec_header.total_tax || '|' ||
                           cur_rec_header.grand_total);
        l_header_count := l_header_count + 1;
      END IF;
    END LOOP;
    l_error_message := 'Error Occured in Closing the Order Header csv file';
    utl_file.fclose(v_file_header);
  
    -- Generate Order line csv file
    l_error_message := ' Error Occured while Deriving Order lines information';
    v_file_line     := utl_file.fopen(location => l_directory_path, filename => l_fname_line_tmp, open_mode => 'w');
    /*This will create the heading in order lines csv file */
    l_error_message := 'Error Occured in UTL_FILE.PUT_LINE (Order Line): Headers';
    utl_file.put_line(v_file_line, 'header_id|line_id|item_number|item_description|item_id|item_technology|ordered_quantity|unit_price|extended_price|tax|status');
  
    FOR cur_rec_lines IN cur_line_info LOOP
      IF check_ecomm_customer(p_cust_account_id => cur_rec_lines.cust_acc_id) THEN
        utl_file.put_line(v_file_line, cur_rec_lines.line_header_id || '|' ||
                           cur_rec_lines.line_id || '|' ||
                           cur_rec_lines.item_number || '|' ||
                           cur_rec_lines.item_description || '|' ||
                           cur_rec_lines.item_id || '|' ||
                           cur_rec_lines.item_technology || '|' ||
                           cur_rec_lines.ordered_quantity || '|' ||
                           cur_rec_lines.unit_price || '|' ||
                           cur_rec_lines.extended_price || '|' ||
                           cur_rec_lines.tax || '|' || cur_rec_lines.status);
        l_line_count := l_line_count + 1;
      END IF;
    END LOOP;
    l_error_message := 'Error Occured in Closing the Order Line csv file';
    utl_file.fclose(v_file_line);
  
    -- Generate Order line shipment csv file
    l_error_message := ' Error Occured while Deriving Order shipments information';
    v_file_shipment := utl_file.fopen(location => l_directory_path, filename => l_fname_ship_tmp, open_mode => 'w');
    /*This will create the heading in order ship csv file*/
    l_error_message := 'Error Occured in UTL_FILE.PUT_LINE (Order Shipment): Headers';
    utl_file.put_line(v_file_shipment, 'line_id|ship_id|ship_date|freight_carrier|shipping_method|tracking_number|shipped_qty');
  
    FOR cur_rec_ship IN cur_line_ship LOOP
      IF check_ecomm_customer(p_cust_account_id => cur_rec_ship.cust_acc_id) THEN
        utl_file.put_line(v_file_shipment, cur_rec_ship.ship_line_id || '|' ||
                           cur_rec_ship.ship_id || '|' ||
                           cur_rec_ship.ship_date || '|' ||
                           cur_rec_ship.freight_carrier || '|' ||
                           cur_rec_ship.shipping_method || '|' ||
                           cur_rec_ship.tracking_number || '|' ||
                           cur_rec_ship.shipped_qty);
        l_ship_count := l_ship_count + 1;
      END IF;
    END LOOP;
    l_error_message := 'Error Occured in Closing the Order Shipment csv file';
    utl_file.fclose(v_file_shipment);
  
    -- printing extracted Order count into log file
    fnd_file.put_line(fnd_file.log, chr(13) || 'Number of extracted Order Headers :' ||
                       l_header_count);
    fnd_file.put_line(fnd_file.log, chr(13) || 'Number of extracted Order Lines :' ||
                       l_line_count);
    fnd_file.put_line(fnd_file.log, chr(13) ||
                       'Number of extracted Order Shipment Lines :' ||
                       l_ship_count);
  
    -- Renaming the file name
    BEGIN
      utl_file.frename(l_directory_path, l_fname_header_tmp, l_directory_path, l_fname_header, TRUE);
      utl_file.frename(l_directory_path, l_fname_line_tmp, l_directory_path, l_fname_line, TRUE);
      utl_file.frename(l_directory_path, l_fname_ship_tmp, l_directory_path, l_fname_ship, TRUE);
    EXCEPTION
      WHEN OTHERS THEN
        l_error_message := l_error_message || ' : Error while Renaming the files' ||
                           ' OTHERS Exception : ' || SQLERRM;
        fnd_file.put_line(fnd_file.log, l_error_message);
        RAISE file_rename_excp;
    END;
  
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  EXCEPTION
    WHEN no_data_found THEN
      utl_file.fclose(v_file_header);
      utl_file.fclose(v_file_line);
      utl_file.fclose(v_file_shipment);
      l_error_message := l_error_message || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, chr(13) || l_error_message);
      x_retcode := '2';
      x_errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory_path, l_fname_header_tmp);
        utl_file.fremove(l_directory_path, l_fname_line_tmp);
        utl_file.fremove(l_directory_path, l_fname_ship_tmp);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | OTHERS Exception : ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => NULL, p_program_short_name => l_program_short_name);
      xxobjt_wf_mail.send_mail_text(p_to_role => l_requestor, p_cc_mail => l_mail_list, p_subject => 'E-Commerce Order History Outbound Failed' ||
                                                  ' - ' ||
                                                  l_request_id, p_body_text => 'E-Commerce Order History Outbound Request Id :' ||
                                                    l_request_id ||
                                                    chr(10) ||
                                                    'Could not create Order History Files for Hybris' ||
                                                    chr(10) ||
                                                    'NO_DATA_FOUND Exception' ||
                                                    chr(10) ||
                                                    'Error Message :' ||
                                                    l_error_message ||
                                                    chr(10) ||
                                                    '******* E-Commerce Order History Outbound Parameters *********' ||
                                                    chr(10) ||
                                                    l_data, p_err_code => l_err_code, p_err_message => l_err_msg);
    WHEN utl_file.invalid_path THEN
      utl_file.fclose(v_file_header);
      utl_file.fclose(v_file_line);
      utl_file.fclose(v_file_shipment);
      l_error_message := l_error_message || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, chr(13) || l_error_message);
      x_retcode := '2';
      x_errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory_path, l_fname_header_tmp);
        utl_file.fremove(l_directory_path, l_fname_line_tmp);
        utl_file.fremove(l_directory_path, l_fname_ship_tmp);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | OTHERS Exception : ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => NULL, p_program_short_name => l_program_short_name);
      xxobjt_wf_mail.send_mail_text(p_to_role => l_requestor, p_cc_mail => l_mail_list, p_subject => 'E-Commerce Order History Outbound Failed' ||
                                                  ' - ' ||
                                                  l_request_id, p_body_text => 'E-Commerce Order History Outbound Request Id :' ||
                                                    l_request_id ||
                                                    chr(10) ||
                                                    'Could not create Order History Files for Hybris' ||
                                                    chr(10) ||
                                                    'UTL_FILE.INVALID_PATH Exception' ||
                                                    chr(10) ||
                                                    'Error Message :' ||
                                                    l_error_message ||
                                                    chr(10) ||
                                                    '******* E-Commerce Order History Outbound Parameters *********' ||
                                                    chr(10) ||
                                                    l_data, p_err_code => l_err_code, p_err_message => l_err_msg);
    WHEN utl_file.read_error THEN
      utl_file.fclose(v_file_header);
      utl_file.fclose(v_file_line);
      utl_file.fclose(v_file_shipment);
      l_error_message := l_error_message || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, chr(13) || l_error_message);
      x_retcode := '2';
      x_errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory_path, l_fname_header_tmp);
        utl_file.fremove(l_directory_path, l_fname_line_tmp);
        utl_file.fremove(l_directory_path, l_fname_ship_tmp);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | OTHERS Exception : ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => NULL, p_program_short_name => l_program_short_name);
      xxobjt_wf_mail.send_mail_text(p_to_role => l_requestor, p_cc_mail => l_mail_list, p_subject => 'E-Commerce Order History Outbound Failed' ||
                                                  ' - ' ||
                                                  l_request_id, p_body_text => 'E-Commerce Order History Outbound Request Id :' ||
                                                    l_request_id ||
                                                    chr(10) ||
                                                    'Could not create Order History Files for Hybris' ||
                                                    chr(10) ||
                                                    'UTL_FILE.READ_ERROR Exception' ||
                                                    chr(10) ||
                                                    'Error Message :' ||
                                                    l_error_message ||
                                                    chr(10) ||
                                                    '******* E-Commerce Order History Outbound Parameters *********' ||
                                                    chr(10) ||
                                                    l_data, p_err_code => l_err_code, p_err_message => l_err_msg);
    WHEN utl_file.write_error THEN
      utl_file.fclose(v_file_header);
      utl_file.fclose(v_file_line);
      utl_file.fclose(v_file_shipment);
      l_error_message := l_error_message || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, chr(13) || l_error_message);
      x_retcode := '2';
      x_errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory_path, l_fname_header_tmp);
        utl_file.fremove(l_directory_path, l_fname_line_tmp);
        utl_file.fremove(l_directory_path, l_fname_ship_tmp);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | OTHERS Exception : ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => NULL, p_program_short_name => l_program_short_name);
      xxobjt_wf_mail.send_mail_text(p_to_role => l_requestor, p_cc_mail => l_mail_list, p_subject => 'E-Commerce Order History Outbound Failed' ||
                                                  ' - ' ||
                                                  l_request_id, p_body_text => 'E-Commerce Order History Outbound Request Id :' ||
                                                    l_request_id ||
                                                    chr(10) ||
                                                    'Could not create Order History Files for Hybris' ||
                                                    chr(10) ||
                                                    'UTL_FILE.WRITE_ERROR Exception' ||
                                                    chr(10) ||
                                                    'Error Message :' ||
                                                    l_error_message ||
                                                    chr(10) ||
                                                    '******* E-Commerce Order History Outbound Parameters *********' ||
                                                    chr(10) ||
                                                    l_data, p_err_code => l_err_code, p_err_message => l_err_msg);
    WHEN file_rename_excp THEN
      utl_file.fclose(v_file_header);
      utl_file.fclose(v_file_line);
      utl_file.fclose(v_file_shipment);
      l_error_message := l_error_message || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, chr(13) || l_error_message);
      x_retcode := '2';
      x_errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory_path, l_fname_header_tmp);
        utl_file.fremove(l_directory_path, l_fname_line_tmp);
        utl_file.fremove(l_directory_path, l_fname_ship_tmp);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | OTHERS Exception : ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => NULL, p_program_short_name => l_program_short_name);
      xxobjt_wf_mail.send_mail_text(p_to_role => l_requestor, p_cc_mail => l_mail_list, p_subject => 'E-Commerce Order History Outbound Failed' ||
                                                  ' - ' ||
                                                  l_request_id, p_body_text => 'E-Commerce Order History Outbound Request Id :' ||
                                                    l_request_id ||
                                                    chr(10) ||
                                                    'Could not create Order History Files for Hybris' ||
                                                    chr(10) ||
                                                    'FILE_RENAME_EXCP Exception' ||
                                                    chr(10) ||
                                                    'Error Message :' ||
                                                    l_error_message ||
                                                    chr(10) ||
                                                    '******* E-Commerce Order History Outbound Parameters *********' ||
                                                    chr(10) ||
                                                    l_data, p_err_code => l_err_code, p_err_message => l_err_msg);
    WHEN OTHERS THEN
      utl_file.fclose(v_file_header);
      utl_file.fclose(v_file_line);
      utl_file.fclose(v_file_shipment);
      l_error_message := l_error_message || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, chr(13) || l_error_message);
      x_retcode := '2';
      x_errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory_path, l_fname_header_tmp);
        utl_file.fremove(l_directory_path, l_fname_line_tmp);
        utl_file.fremove(l_directory_path, l_fname_ship_tmp);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
                             ' : NO_DATA_FOUND - Error while deleting the files :' ||
                             ' | OTHERS Exception : ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit => NULL, p_program_short_name => l_program_short_name);
      xxobjt_wf_mail.send_mail_text(p_to_role => l_requestor, p_cc_mail => l_mail_list, p_subject => 'E-Commerce Order History Outbound Failed' ||
                                                  ' - ' ||
                                                  l_request_id, p_body_text => 'E-Commerce Order History Outbound Request Id :' ||
                                                    l_request_id ||
                                                    chr(10) ||
                                                    'Could not create Order History Files for Hybris' ||
                                                    chr(10) ||
                                                    'OTHERS Exception' ||
                                                    chr(10) ||
                                                    'Error Message :' ||
                                                    l_error_message ||
                                                    chr(10) ||
                                                    '******* E-Commerce Order History Outbound Parameters *********' ||
                                                    chr(10) ||
                                                    l_data, p_err_code => l_err_code, p_err_message => l_err_msg);
  END order_history_proc;
END xxom_order_hist_pkg;
/
