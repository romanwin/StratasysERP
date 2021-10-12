CREATE OR REPLACE PACKAGE BODY xxcs_price_list_chg_pkg IS
  --------------------------------------------------------------------
  --  name:            XXCS_PRICE_LIST_CHG_PKG
  --  create by:       Ella Malchi
  --  Revision:        1.0 
  --  creation date:   xx/xx/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        CUST222 - Update Price list in Charges table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --  1.1  21/03/2010  Dalit A. Raviv  add condition to chg_charges_price_list procedure
  --  1.2   1.12.13    Yuval Tal       change_warranty_coverage - CR1163-Service - Customization support new operating unit 737
  --------------------------------------------------------------------  

  --------------------------------------------------------------------
  --  name:            get_price_list_id
  --  create by:       Ella Malchi
  --  Revision:        1.0 
  --  creation date:   xx/xx/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        CUST222 - Update Price list in Charges table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --------------------------------------------------------------------       
  FUNCTION get_price_list_id(p_business_process_id NUMBER,
                             p_instance_id         NUMBER) RETURN NUMBER IS
  
    l_business_process okx_bus_processes_v.name%TYPE;
    l_price_list_id    NUMBER;
  
  BEGIN
  
    SELECT NAME
      INTO l_business_process
      FROM okx_bus_processes_v
     WHERE id1 = p_business_process_id;
  
    /*** Get price list from customer DFF's according to business process (Heads/Not Heads)  ***/
    SELECT (CASE
             WHEN l_business_process LIKE '%Heads%' THEN
              attribute11
             ELSE
              attribute11
           END)
      INTO l_price_list_id
      FROM csi_item_instances cii
     WHERE cii.instance_id = p_instance_id;
  
    RETURN l_price_list_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_price_list_id;

  --------------------------------------------------------------------
  --  name:            get_price_list_details
  --  create by:       Ella Malchi
  --  Revision:        1.0 
  --  creation date:   xx/xx/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        CUST222 - Update Price list in Charges table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  -------------------------------------------------------------------- 
  FUNCTION get_price_list_details(p_list_header_id  NUMBER,
                                  x_price_list_name OUT VARCHAR2,
                                  x_currency_code   OUT VARCHAR2)
    RETURN NUMBER IS
  
    CURSOR csr_price_list(p_price_list_id NUMBER) IS
      SELECT b.list_header_id, t.name, b.currency_code
        FROM qp_list_headers_all_b b, qp_list_headers_tl t
       WHERE b.list_header_id = t.list_header_id
         AND t.language = userenv('LANG')
         AND b.list_type_code IN ('PRL', 'AGR')
         AND b.list_header_id = p_price_list_id;
  
    l_price_list_id NUMBER := NULL;
  
  BEGIN
  
    OPEN csr_price_list(p_list_header_id);
    FETCH csr_price_list
      INTO l_price_list_id, x_price_list_name, x_currency_code;
    CLOSE csr_price_list;
  
    RETURN l_price_list_id;
  
  END get_price_list_details;

  --------------------------------------------------------------------
  --  name:            chg_charges_price_list
  --  create by:       Ella Malchi
  --  Revision:        1.0 
  --  creation date:   xx/xx/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        CUST222 - Update Price list in Charges table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --  1.1  21/03/2010  Dalit A. Raviv  add condition - to take the selling price
  --                                   if user enter manual, and not the price 
  --                                   from the price list
  -------------------------------------------------------------------- 
  PROCEDURE chg_charges_price_list(errbuf        OUT VARCHAR2,
                                   retcode       OUT VARCHAR2,
                                   p_incident_id NUMBER DEFAULT NULL) IS
  
    CURSOR csr_charges IS
      SELECT ced.estimate_detail_id,
             ci.incident_number,
             ced.line_number,
             ced.object_version_number,
             ced.org_id,
             decode(msi.material_billable_flag,
                    'XXOBJ_HEADS',
                    cii.attribute11,
                    cii.attribute11) price_list_header_id,
             msi.material_billable_flag,
             msi.inventory_item_id,
             ced.unit_of_measure_code,
             ced.quantity_required,
             ced.after_warranty_cost, -- 1.1  21/03/2010  Dalit A. Raviv
             ced.transaction_type_id -- 1.1  21/03/2010  Dalit A. Raviv
        FROM cs_incidents_all_b  ci,
             csi_item_instances  cii,
             cs_estimate_details ced,
             mtl_system_items_b  msi
       WHERE ci.incident_id = nvl(p_incident_id, ci.incident_id)
         AND ci.incident_id = ced.incident_id
         AND ci.customer_product_id = cii.instance_id
         AND ced.contract_id IS NULL
         AND ced.inventory_item_id = msi.inventory_item_id
         AND msi.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND nvl(ced.line_submitted, 'N') = 'N'
         AND ced.price_list_header_id !=
             nvl(decode(msi.material_billable_flag,
                        'XXOBJ_HEADS',
                        cii.attribute11,
                        cii.attribute11),
                 ced.price_list_header_id);
  
    t_charges_rec           cs_charge_details_pub.charges_rec_type := cs_charge_details_pub.g_miss_chrg_rec;
    cur_charge              csr_charges%ROWTYPE;
    l_return_status         VARCHAR2(1);
    l_msg_count             NUMBER;
    l_msg_index_out         NUMBER;
    l_msg_data              VARCHAR2(1000);
    l_err_msg               VARCHAR2(1000);
    l_user_id               NUMBER;
    l_object_version_number NUMBER;
    l_currency_code         VARCHAR2(20);
    l_price_list_name       VARCHAR2(250);
    l_price_list_id         NUMBER;
    l_list_price            NUMBER;
    l_success_counter       NUMBER := 0;
    l_invalid_counter       NUMBER := 0;
  
    invalid_charge EXCEPTION;
  
  BEGIN
  
    SELECT user_id
      INTO l_user_id
      FROM fnd_user
     WHERE user_name = 'SCHEDULER';
  
    FOR cur_charge IN csr_charges LOOP
    
      BEGIN
      
        t_charges_rec           := cs_charge_details_pub.g_miss_chrg_rec;
        l_object_version_number := NULL;
        l_currency_code         := NULL;
        l_price_list_name       := NULL;
        --l_price_list_id         := NULL;
        l_list_price    := NULL;
        l_return_status := NULL;
        l_msg_count     := NULL;
        l_msg_index_out := NULL;
        l_msg_data      := NULL;
        l_err_msg       := NULL;
      
        mo_global.set_org_access(p_org_id_char     => cur_charge.org_id,
                                 p_sp_id_char      => NULL,
                                 p_appl_short_name => 'QP');
      
        l_price_list_id := get_price_list_details(p_list_header_id  => cur_charge.price_list_header_id,
                                                  x_price_list_name => l_price_list_name,
                                                  x_currency_code   => l_currency_code);
      
        cs_pricing_item_pkg.call_pricing_item(p_api_version       => 1.0,
                                              p_init_msg_list     => 'T',
                                              p_commit            => 'F',
                                              p_validation_level  => NULL,
                                              p_inventory_item_id => cur_charge.inventory_item_id,
                                              p_price_list_id     => l_price_list_id,
                                              p_uom_code          => cur_charge.unit_of_measure_code,
                                              p_currency_code     => l_currency_code,
                                              p_quantity          => cur_charge.quantity_required,
                                              p_org_id            => cur_charge.org_id,
                                              x_list_price        => l_list_price,
                                              x_return_status     => l_return_status,
                                              x_msg_count         => l_msg_count,
                                              x_msg_data          => l_msg_data);
      
        IF l_return_status != fnd_api.g_ret_sts_success THEN
        
          FOR i IN 1 .. l_msg_count LOOP
            fnd_msg_pub.get(p_msg_index     => i,
                            p_data          => l_msg_data,
                            p_encoded       => fnd_api.g_false,
                            p_msg_index_out => l_msg_index_out);
            l_err_msg := l_err_msg || l_msg_data || chr(10);
          END LOOP;
          RAISE invalid_charge;
        
        END IF;
      
        t_charges_rec.estimate_detail_id := cur_charge.estimate_detail_id;
        -- t_charges_rec.list_price         := nvl(l_list_price, 0);  
        -- 1.1  21/03/2010  Dalit A. Raviv
        -- if line type is of transaction EXPENCE (10) and cost <> 0 take the 
        -- price entered at line  
        IF cur_charge.transaction_type_id = 10 THEN
          IF cur_charge.after_warranty_cost <> 0 THEN
            l_list_price := cur_charge.after_warranty_cost;
          END IF;
        END IF;
        -- end 1.1  21/03/2010
      
        t_charges_rec.selling_price := nvl(l_list_price, 0);
        t_charges_rec.price_list_id := l_price_list_id;
        t_charges_rec.currency_code := l_currency_code;
      
        fnd_msg_pub.initialize;
        cs_charge_details_pub.update_charge_details(p_api_version           => 1.0,
                                                    p_init_msg_list         => fnd_api.g_true,
                                                    p_commit                => fnd_api.g_false,
                                                    x_return_status         => l_return_status,
                                                    x_msg_count             => l_msg_count,
                                                    x_object_version_number => l_object_version_number,
                                                    x_msg_data              => l_msg_data,
                                                    p_resp_appl_id          => 514,
                                                    p_resp_id               => fnd_profile.value_specific('XXCS_AUTO_DEBRIEF_RESPONSIBILITY',
                                                                                                          NULL,
                                                                                                          NULL,
                                                                                                          NULL,
                                                                                                          cur_charge.org_id),
                                                    p_user_id               => l_user_id,
                                                    p_transaction_control   => fnd_api.g_true,
                                                    p_charges_rec           => t_charges_rec);
      
        IF l_return_status != fnd_api.g_ret_sts_success THEN
        
          FOR i IN 1 .. l_msg_count LOOP
            fnd_msg_pub.get(p_msg_index     => i,
                            p_data          => l_msg_data,
                            p_encoded       => fnd_api.g_false,
                            p_msg_index_out => l_msg_index_out);
            l_err_msg := l_err_msg || l_msg_data || chr(10);
          END LOOP;
          RAISE invalid_charge;
        
        END IF;
        l_success_counter := l_success_counter + 1;
      
        COMMIT;
      EXCEPTION
        WHEN invalid_charge THEN
          l_invalid_counter := l_invalid_counter + 1;
          retcode           := 1;
          ROLLBACK;
        WHEN OTHERS THEN
          l_invalid_counter := l_invalid_counter + 1;
          retcode           := 1;
          l_err_msg         := SQLERRM;
          ROLLBACK;
      END;
    
      fnd_file.put_line(fnd_file.log,
                        'Incident ' || cur_charge.incident_number ||
                        ' Line ' || cur_charge.line_number ||
                        ' was processed with status : ' || l_return_status || ', ' ||
                        l_err_msg);
    
    END LOOP;
  
    fnd_file.put_line(fnd_file.log,
                      '=============================================');
    fnd_file.put_line(fnd_file.log,
                      l_success_counter ||
                      ' rows were processed successfuly.');
    fnd_file.put_line(fnd_file.log,
                      l_invalid_counter || ' rows failed with error.');
    fnd_file.put_line(fnd_file.log,
                      '=============================================');
    -- Dalit A. Raviv 21/03/2010
    IF retcode = 1 THEN
      errbuf := 'Error in xxcs_price_list_chg_pkg.chg_charges_price_list';
    END IF;
  END chg_charges_price_list;

  PROCEDURE change_warranty_coverage(errbuf  OUT VARCHAR2,
                                     retcode OUT VARCHAR2) IS
  
    CURSOR csr_all_contracts IS
      SELECT h.id,
             h.contract_number || ' ' || h.contract_number_modifier contract_number,
             l.id line_id,
             s.id service_line_id,
             s.coverage_id,
             i.object1_id1 item_id,
             i.object1_id2 organization_id,
             l.start_date,
             l.end_date,
             s.object_version_number,
             h.org_id,
             s.standard_cov_yn,
             cii.instance_id,
             cii.instance_number,
             cii.serial_number,
             cii.attribute10 warranty_coverage_id
        FROM okc_k_headers_all_b h,
             okc_k_lines_b       l,
             oks_k_lines_b       s,
             okc_k_items         i,
             okc_k_lines_b       subl,
             okc_k_items         subi,
             csi_item_instances  cii
       WHERE h.id = l.chr_id
         AND h.id = s.dnz_chr_id
         AND s.cle_id = l.id
         AND i.cle_id = l.id
         AND h.scs_code = 'WARRANTY'
         AND h.sts_code = 'ACTIVE'
         AND l.lse_id = 14
         AND subl.dnz_chr_id = h.id
         AND subl.cle_id = l.id
         AND subl.lse_id IN (9, 18)
         AND subi.dnz_chr_id = h.id
         AND subi.cle_id = subl.id
         AND subi.object1_id1 = cii.instance_id
         AND subi.object1_id2 = '#'
         AND subi.jtot_object1_code = 'OKX_CUSTPROD'
         AND s.coverage_id != nvl(cii.attribute10, s.coverage_id);
  
    cur_contract   csr_all_contracts%ROWTYPE;
    l_klnv_tbl_in  oks_contract_line_pub.klnv_tbl_type;
    l_klnv_tbl_out oks_contract_line_pub.klnv_tbl_type;
  
    l_klnv_tbl_miss oks_contract_line_pub.klnv_tbl_type;
  
    l_return_status VARCHAR2(1);
    l_msg_count     NUMBER;
    l_msg_index_out NUMBER;
    l_msg_data      VARCHAR2(1000);
    l_err_msg       VARCHAR2(1000);
    l_user_id       NUMBER;
    l_counter       NUMBER := 0;
    invalid_contract EXCEPTION;
  
  BEGIN
  
    SELECT user_id
      INTO l_user_id
      FROM fnd_user
     WHERE user_name = 'SCHEDULER';
  
    FOR cur_contract IN csr_all_contracts LOOP
    
      l_err_msg       := NULL;
      l_return_status := 'S';
      l_counter       := l_counter + 1;
    
      IF cur_contract.org_id = 81 THEN
        fnd_global.apps_initialize(user_id      => l_user_id,
                                   resp_id      => 50571,
                                   resp_appl_id => 515);
      
      ELSIF cur_contract.org_id IN (737, 89) THEN
        fnd_global.apps_initialize(user_id      => l_user_id,
                                   resp_id      => 50572,
                                   resp_appl_id => 515);
      ELSIF cur_contract.org_id = 96 THEN
        fnd_global.apps_initialize(user_id      => l_user_id,
                                   resp_id      => 50573,
                                   resp_appl_id => 515);
      ELSIF cur_contract.org_id = 103 THEN
        fnd_global.apps_initialize(user_id      => l_user_id,
                                   resp_id      => 50574,
                                   resp_appl_id => 515);
      END IF;
    
      mo_global.set_org_access(p_org_id_char     => cur_contract.org_id,
                               p_sp_id_char      => NULL,
                               p_appl_short_name => 'OKS');
    
      BEGIN
      
        l_klnv_tbl_in := l_klnv_tbl_miss;
      
        l_klnv_tbl_in(1).id := cur_contract.service_line_id;
        l_klnv_tbl_in(1).cle_id := cur_contract.line_id;
        l_klnv_tbl_in(1).dnz_chr_id := cur_contract.id;
        l_klnv_tbl_in(1).last_updated_by := l_user_id;
        l_klnv_tbl_in(1).last_update_date := SYSDATE;
        l_klnv_tbl_in(1).object_version_number := cur_contract.object_version_number;
        l_klnv_tbl_in(1).coverage_id := cur_contract.warranty_coverage_id; --l_coverage_template_id; -- 
        l_klnv_tbl_in(1).standard_cov_yn := 'Y';
        -- CRA --
        -- GCHADHA --
        fnd_msg_pub.initialize;
        oks_contract_line_pub.update_line(p_api_version   => 1.0,
                                          p_init_msg_list => fnd_api.g_true,
                                          x_return_status => l_return_status,
                                          x_msg_count     => l_msg_count,
                                          x_msg_data      => l_msg_data,
                                          p_klnv_tbl      => l_klnv_tbl_in,
                                          x_klnv_tbl      => l_klnv_tbl_out,
                                          p_validate_yn   => 'N');
      
        IF l_return_status != fnd_api.g_ret_sts_success THEN
        
          FOR i IN 1 .. l_msg_count LOOP
            fnd_msg_pub.get(p_msg_index     => i,
                            p_data          => l_msg_data,
                            p_encoded       => fnd_api.g_false,
                            p_msg_index_out => l_msg_index_out);
            l_err_msg := l_err_msg || l_msg_data || chr(10);
          END LOOP;
          RAISE invalid_contract;
        
        END IF;
      
      EXCEPTION
        WHEN invalid_contract THEN
          retcode := 1;
          ROLLBACK;
        WHEN OTHERS THEN
          retcode   := 1;
          l_err_msg := SQLERRM;
          ROLLBACK;
      END;
    
      COMMIT;
    
      fnd_file.put_line(fnd_file.log,
                        'Warranty ' || cur_contract.contract_number ||
                        ' was updated with status : ' || l_return_status || ', ' ||
                        l_err_msg);
    
    END LOOP;
  
    fnd_file.put_line(fnd_file.log,
                      '=============================================');
    fnd_file.put_line(fnd_file.log, l_counter || ' rows were updated.');
    fnd_file.put_line(fnd_file.log,
                      '=============================================');
  
    IF retcode = 1 THEN
      errbuf := 'Error in xxcs_price_list_chg_pkg.change_warranty_coverage';
    END IF;
  END change_warranty_coverage;

END xxcs_price_list_chg_pkg;
/
