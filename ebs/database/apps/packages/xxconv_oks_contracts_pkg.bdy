CREATE OR REPLACE PACKAGE BODY xxconv_oks_contracts_pkg IS

   g_user_id NUMBER;

   PROCEDURE populate_oks_line(x_oks_line_tbl_out OUT oks_contract_line_pub.klnv_tbl_type) IS
   BEGIN
      x_oks_line_tbl_out(1).id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).cle_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).dnz_chr_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).discount_list := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).acct_rule_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).payment_type := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).cc_bank_acct_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).cc_auth_code := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).commitment_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).locked_price_list_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).locked_price_list_line_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).break_uom := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).prorate := okc_api.g_miss_char;
   
      x_oks_line_tbl_out(1).usage_est_yn := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).usage_est_method := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).usage_est_start_date := okc_api.g_miss_date;
      x_oks_line_tbl_out(1).termn_method := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).ubt_amount := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).credit_amount := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).suppressed_credit := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).override_amount := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).cust_po_number_req_yn := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).cust_po_number := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).grace_duration := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).grace_period := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).inv_print_flag := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).price_uom := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).tax_amount := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).tax_inclusive_yn := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).tax_status := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).tax_code := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).tax_exemption_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).ib_trans_type := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).ib_trans_date := okc_api.g_miss_date;
      x_oks_line_tbl_out(1).prod_price := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).service_price := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).clvl_list_price := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).clvl_quantity := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).clvl_extended_amt := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).clvl_uom_code := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).toplvl_operand_code := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).toplvl_operand_val := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).toplvl_quantity := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).toplvl_uom_code := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).toplvl_adj_price := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).toplvl_price_qty := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).averaging_interval := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).settlement_interval := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).minimum_quantity := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).default_quantity := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).amcv_flag := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).fixed_quantity := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).usage_duration := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).usage_period := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).level_yn := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).usage_type := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).uom_quantified := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).base_reading := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).billing_schedule_type := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).coverage_type := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).exception_cov_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).limit_uom_quantified := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).discount_amount := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).discount_percent := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).offset_duration := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).offset_period := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).incident_severity_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).pdf_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).work_thru_yn := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).react_active_yn := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).transfer_option := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).prod_upgrade_yn := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).inheritance_type := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).pm_program_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).pm_conf_req_yn := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).invoice_text := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).ib_trx_details := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).status_text := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).react_time_name := okc_api.g_miss_char;
   
      x_oks_line_tbl_out(1).pm_sch_exists_yn := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).allow_bt_discount := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).apply_default_timezone := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).sync_date_install := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).object_version_number := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).request_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).created_by := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).creation_date := okc_api.g_miss_date;
      x_oks_line_tbl_out(1).last_updated_by := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).last_update_date := okc_api.g_miss_date;
      x_oks_line_tbl_out(1).last_update_login := okc_api.g_miss_num;
      --R12
   
      x_oks_line_tbl_out(1).trxn_extension_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).tax_classification_code := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).exempt_certificate_number := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).exempt_reason_code := okc_api.g_miss_char;
   
      x_oks_line_tbl_out(1).coverage_id := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).standard_cov_yn := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).orig_system_id1 := okc_api.g_miss_num;
      x_oks_line_tbl_out(1).orig_system_reference1 := okc_api.g_miss_char;
      x_oks_line_tbl_out(1).orig_system_source_code := okc_api.g_miss_char;
   
      x_oks_line_tbl_out := x_oks_line_tbl_out;
   END populate_oks_line;

   PROCEDURE populate_okc_line(x_clev_tbl_out OUT okc_contract_pub.clev_tbl_type) IS
   BEGIN
      x_clev_tbl_out(1).id := okc_api.g_miss_num;
      x_clev_tbl_out(1).line_number := okc_api.g_miss_char;
      x_clev_tbl_out(1).chr_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).cle_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).cle_id_renewed := okc_api.g_miss_num;
      x_clev_tbl_out(1).dnz_chr_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).display_sequence := okc_api.g_miss_num;
      x_clev_tbl_out(1).sts_code := okc_api.g_miss_char;
      x_clev_tbl_out(1).trn_code := okc_api.g_miss_char;
      x_clev_tbl_out(1).lse_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).exception_yn := okc_api.g_miss_char;
      x_clev_tbl_out(1).object_version_number := okc_api.g_miss_num;
      x_clev_tbl_out(1).created_by := okc_api.g_miss_num;
      x_clev_tbl_out(1).creation_date := okc_api.g_miss_date;
      x_clev_tbl_out(1).last_updated_by := okc_api.g_miss_num;
      x_clev_tbl_out(1).last_update_date := okc_api.g_miss_date;
      x_clev_tbl_out(1).hidden_ind := okc_api.g_miss_char;
      x_clev_tbl_out(1).price_negotiated := okc_api.g_miss_num;
      x_clev_tbl_out(1).price_level_ind := okc_api.g_miss_char;
      x_clev_tbl_out(1).price_unit := okc_api.g_miss_num;
      x_clev_tbl_out(1).price_unit_percent := okc_api.g_miss_num;
      x_clev_tbl_out(1).invoice_line_level_ind := okc_api.g_miss_char;
      x_clev_tbl_out(1).dpas_rating := okc_api.g_miss_char;
      x_clev_tbl_out(1).template_used := okc_api.g_miss_char;
      x_clev_tbl_out(1).price_type := okc_api.g_miss_char;
      x_clev_tbl_out(1).currency_code := okc_api.g_miss_char;
      x_clev_tbl_out(1).last_update_login := okc_api.g_miss_num;
      x_clev_tbl_out(1).date_terminated := okc_api.g_miss_date;
      x_clev_tbl_out(1).start_date := okc_api.g_miss_date;
      x_clev_tbl_out(1).end_date := okc_api.g_miss_date;
      x_clev_tbl_out(1).attribute_category := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute1 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute2 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute3 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute4 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute5 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute6 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute7 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute8 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute9 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute10 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute11 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute12 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute13 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute14 := okc_api.g_miss_char;
      x_clev_tbl_out(1).attribute15 := okc_api.g_miss_char;
      x_clev_tbl_out(1).cle_id_renewed_to := okc_api.g_miss_num;
      x_clev_tbl_out(1).price_negotiated_renewed := okc_api.g_miss_num;
      x_clev_tbl_out(1).currency_code_renewed := okc_api.g_miss_char;
      x_clev_tbl_out(1).upg_orig_system_ref := okc_api.g_miss_char;
      x_clev_tbl_out(1).upg_orig_system_ref_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).date_renewed := okc_api.g_miss_date;
      x_clev_tbl_out(1).orig_system_source_code := okc_api.g_miss_char;
      x_clev_tbl_out(1).orig_system_id1 := okc_api.g_miss_num;
      x_clev_tbl_out(1).orig_system_reference1 := okc_api.g_miss_char;
      x_clev_tbl_out(1).program_application_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).program_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).program_update_date := okc_api.g_miss_date;
      x_clev_tbl_out(1).request_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).price_list_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).price_list_line_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).line_list_price := okc_api.g_miss_num;
      x_clev_tbl_out(1).item_to_price_yn := okc_api.g_miss_char;
      x_clev_tbl_out(1).pricing_date := okc_api.g_miss_date;
      x_clev_tbl_out(1).price_basis_yn := okc_api.g_miss_char;
      x_clev_tbl_out(1).config_header_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).config_revision_number := okc_api.g_miss_num;
      x_clev_tbl_out(1).config_complete_yn := okc_api.g_miss_char;
      x_clev_tbl_out(1).config_valid_yn := okc_api.g_miss_char;
      x_clev_tbl_out(1).config_top_model_line_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).config_item_type := okc_api.g_miss_char;
      x_clev_tbl_out(1).config_item_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).service_item_yn := okc_api.g_miss_char;
      x_clev_tbl_out(1).ph_pricing_type := okc_api.g_miss_char;
      x_clev_tbl_out(1).ph_price_break_basis := okc_api.g_miss_char;
      x_clev_tbl_out(1).ph_min_qty := okc_api.g_miss_num;
      x_clev_tbl_out(1).ph_min_amt := okc_api.g_miss_num;
      x_clev_tbl_out(1).ph_qp_reference_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).ph_value := okc_api.g_miss_num;
      x_clev_tbl_out(1).ph_enforce_price_list_yn := okc_api.g_miss_char;
      x_clev_tbl_out(1).ph_adjustment := okc_api.g_miss_num;
      x_clev_tbl_out(1).ph_integrated_with_qp := okc_api.g_miss_char;
      x_clev_tbl_out(1).cust_acct_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).bill_to_site_use_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).inv_rule_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).line_renewal_type_code := okc_api.g_miss_char;
      x_clev_tbl_out(1).ship_to_site_use_id := okc_api.g_miss_num;
      x_clev_tbl_out(1).payment_term_id := okc_api.g_miss_num;
      --R12
   
      x_clev_tbl_out(1).date_cancelled := okc_api.g_miss_date;
      -- x_clev_tbl_out(1).CANC_REASON_CODE                          :=  OKC_API.G_MISS_CHAR; 
      x_clev_tbl_out(1).trn_code := okc_api.g_miss_char;
      x_clev_tbl_out(1).term_cancel_source := okc_api.g_miss_char;
      x_clev_tbl_out(1).annualized_factor := okc_api.g_miss_num;
      x_clev_tbl_out(1).payment_instruction_type := okc_api.g_miss_char;
      -- Line Cancellation --
      -- Bug 4615934 --
      x_clev_tbl_out(1).cancelled_amount := okc_api.g_miss_num;
      -- Bug 4615934 --
   
   END populate_okc_line;

   PROCEDURE insert_sales_credit(p_id              NUMBER,
                                 p_sales_person_id NUMBER,
                                 p_status          OUT VARCHAR2,
                                 p_error           OUT VARCHAR2) IS
      l_api_version   CONSTANT NUMBER := 1;
      l_init_msg_list CONSTANT VARCHAR2(1) := 'T'; --okc$application.get_true;
      l_return_status VARCHAR2(1);
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(2000);
      scrv_rec_in     oks_sales_credit_pub.scrv_rec_type;
      scrv_rec_out    oks_sales_credit_pub.scrv_rec_type;
      l_msg_index_out NUMBER;
   
   BEGIN
   
      scrv_rec_in.chr_id := p_id;
      -- scrv_rec_in.dnz_chr_id            := p_id;
      scrv_rec_in.ctc_id                := nvl(p_sales_person_id, -3);
      scrv_rec_in.percent               := 100;
      scrv_rec_in.sales_credit_type_id1 := 1;
      scrv_rec_in.sales_credit_type_id2 := '#';
      scrv_rec_in.sales_group_id        := -1;
      scrv_rec_in.created_by            := g_user_id;
      scrv_rec_in.creation_date         := SYSDATE;
      scrv_rec_in.last_updated_by       := g_user_id;
      scrv_rec_in.last_update_date      := SYSDATE;
   
      oks_sales_credit_pub.insert_sales_credit(p_api_version   => l_api_version,
                                               p_init_msg_list => l_init_msg_list,
                                               x_return_status => l_return_status,
                                               x_msg_count     => l_msg_count,
                                               x_msg_data      => l_msg_data,
                                               p_scrv_rec      => scrv_rec_in,
                                               x_scrv_rec      => scrv_rec_out);
   
      IF l_return_status <> 'S' THEN
         p_status := 'E';
         p_error  := l_msg_data;
      ELSE
         p_status := 'S';
         p_error  := NULL;
      END IF;
   
   END insert_sales_credit;

   PROCEDURE load_contracts(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
   
      CURSOR cst_contract_headers IS
         SELECT DISTINCT priority_contract_id,
                         customer_id,
                         contract_number,
                         description,
                         effect_date,
                         expir_date,
                         link_curr,
                         party,
                         operation_unit,
                         contact_name,
                         ship_to_address bill_to,
                         ship_to,
                         payment_terms,
                         contract_price_list,
                         site_id_priority,
                         po_number,
                         t.curr_conversion_type,
                         t.curr_conversion_date,
                         t.sales_person,
                         t.contract_group,
                         t.renewal_pricing_method,
                         t.renewal_price_list,
                         t.security_group,
                         t.contract_type,
                         t.renewal_process
           FROM xxobjt_conv_oks_contracts t
          WHERE return_status = 'N';
   
      CURSOR csr_contract_lines(p_contract_number VARCHAR2) IS
         SELECT *
           FROM xxobjt_conv_oks_contracts
          WHERE return_status = 'N' AND
                contract_number = p_contract_number;
   
      CURSOR csr_coverage_lines(p_cle_id NUMBER) IS
         SELECT cleb.id id,
                cleb.object_version_number object_version_number,
                cleb.cle_id coverage_cle_id,
                cleb.lse_id lse_id,
                cleb.line_number line_number,
                cleb.dnz_chr_id dnz_chr_id,
                cleb.price_list_id,
                cleb.start_date,
                cleb.end_date,
                buspr.NAME process_name
           FROM okc_k_lines_b       cleb,
                okc_k_items         citem,
                okx_bus_processes_v buspr,
                jtf_objects_b       jtfob
          WHERE jtfob.object_code = 'OKX_BUSIPROC' AND
                cleb.lse_id IN (3, 16, 21) AND
                citem.cle_id = cleb.id AND
                citem.jtot_object1_code = jtfob.object_code AND
                buspr.id1 = citem.object1_id1 AND
                buspr.id2 = citem.object1_id2 AND
                cleb.cle_id = p_cle_id;
   
      cur_contract      cst_contract_headers%ROWTYPE;
      cur_line          csr_contract_lines%ROWTYPE;
      cur_coverage_line csr_coverage_lines%ROWTYPE;
      invalid_contract EXCEPTION;
      l_class_code okc_subclasses_b.code%TYPE;
      l_cls_code   okc_subclasses_b.cls_code%TYPE;
   
      t_header_rec           oks_contracts_pub.header_rec_type;
      t_header_contacts_tbl  oks_contracts_pub.contact_tbl;
      t_header_sales_crd_tbl oks_contracts_pub.salescredit_tbl;
      t_header_articles_tbl  oks_contracts_pub.obj_articles_tbl;
      t_line_rec             oks_contracts_pub.line_rec_type;
      t_covarage_rec         oks_contracts_pub.covered_level_rec_type;
   
      l_khrv_tbl_type_in  oks_contract_hdr_pub.khrv_tbl_type;
      l_khrv_tbl_type_out oks_contract_hdr_pub.khrv_tbl_type;
   
      l_chrv_tbl_in  okc_contract_pub.chrv_tbl_type;
      l_chrv_tbl_out okc_contract_pub.chrv_tbl_type;
   
      t_header_rec_miss          oks_contracts_pub.header_rec_type;
      t_line_rec_miss            oks_contracts_pub.line_rec_type;
      t_covarage_rec_miss        oks_contracts_pub.covered_level_rec_type;
      t_header_contacts_tbl_miss oks_contracts_pub.contact_tbl;
      t_cacv_tbl_in              okc_contract_pub.cacv_tbl_type;
      t_cacv_tbl_out             okc_contract_pub.cacv_tbl_type;
      t_ac_rec_type              oks_coverages_pub.ac_rec_type;
      l_actual_coverage_id       okc_k_lines_b.id%TYPE;
      l_chrid                    NUMBER;
      l_return_status            VARCHAR2(1);
      l_msg_count                NUMBER;
      l_msg_data                 VARCHAR2(500);
      l_err_msg                  VARCHAR2(2000);
      l_msg_index_out            NUMBER;
      l_org_id                   NUMBER;
      l_inv_organization_id      NUMBER;
      l_qcl_id                   NUMBER;
      l_party_id                 NUMBER;
      l_bill_id                  NUMBER;
      l_ship_id                  NUMBER;
      l_contact_id               NUMBER;
      l_user_id                  NUMBER;
      l_master_org_id            NUMBER;
      l_duration                 NUMBER;
      l_duration_uom             VARCHAR2(5);
      l_price_list_id            NUMBER;
      l_line_price_list_id       NUMBER;
      l_payment_terms_id         NUMBER;
      l_rate                     NUMBER;
      l_invoice_text             VARCHAR2(500);
      l_cust_account_id          NUMBER;
      l_counter                  NUMBER := 0;
      l_renual_proce_list_id     NUMBER;
      l_item_uom                 VARCHAR2(5);
      l_func_curr                VARCHAR2(5);
      -------------------------------------------------------
      l_init_msg_list CONSTANT VARCHAR2(1) := 'T';
      v_line_number  NUMBER;
      v_lse_id       NUMBER;
      l_clev_tbl_in  okc_contract_pub.clev_tbl_type;
      l_clev_tbl_out okc_contract_pub.clev_tbl_type;
   
      l_osh_cust_acct         NUMBER;
      l_cle_id                NUMBER;
      l_line_item_id          NUMBER;
      l_coverage_template_id  NUMBER;
      l_cimv_id               NUMBER;
      l_instance_id           NUMBER;
      l_inventory_item_id     NUMBER;
      l_unit_of_measure       VARCHAR2(3);
      l_quantity              NUMBER;
      l_salesrep_id           NUMBER;
      l_group_id              NUMBER;
      l_sub_cle_id            NUMBER;
      v_sub_lse_id            NUMBER;
      l_sub_cimv_id           NUMBER;
      l_pdf_id                NUMBER;
      l_security_group_id     NUMBER;
      l_renewal_price_list_id NUMBER;
      l_billing_profile_id    NUMBER;
      l_oks_id                NUMBER;
      l_object_version_number NUMBER;
      l_coverage_id           NUMBER;
      l_price_list_for_rh     NUMBER;
   
      CURSOR get_line_no(p_chr_id NUMBER) IS
         SELECT MAX(to_number(line_number))
           FROM okc_k_lines_v
          WHERE chr_id = p_chr_id;
   
      CURSOR get_subline_no(p_dnz_chr_id IN NUMBER, p_cle_id NUMBER) IS
         SELECT MAX(to_number(line_number))
           FROM okc_k_lines_v
          WHERE dnz_chr_id = p_dnz_chr_id AND
                cle_id = p_cle_id AND
                lse_id IN (7, 8, 9, 10, 11, 12, 18, 13, 46, 25, 35);
   
      CURSOR instacct_cur(p_line_id IN NUMBER) IS
         SELECT cii.owner_party_account_id
           FROM csi_item_instances cii, oks_subscr_header_b osh
          WHERE osh.cle_id = p_line_id AND
                cii.instance_id = osh.instance_id;
      --------------------------------------------------------------
      l_cimv_tbl_in  okc_contract_item_pub.cimv_tbl_type;
      l_cimv_tbl_out okc_contract_item_pub.cimv_tbl_type;
      ----------------------------------------------------
      l_klnv_tbl_in  oks_contract_line_pub.klnv_tbl_type;
      l_klnv_tbl_out oks_contract_line_pub.klnv_tbl_type;
   
   BEGIN
   
      l_return_status := fnd_api.g_ret_sts_success;
   
      SELECT user_id
        INTO g_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
   
      fnd_global.apps_initialize(user_id      => g_user_id,
                                 resp_id      => 50570,
                                 resp_appl_id => 515);
   
      l_master_org_id := xxinv_utils_pkg.get_master_organization_id;
   
      SELECT id
        INTO l_qcl_id
        FROM okc_qa_check_lists_v
       WHERE NAME =
             'Default Service Contracts Quality Assurance Check List';
   
      SELECT id
        INTO l_pdf_id
        FROM okc_process_defs_b
       WHERE NAME = 'APPROVAL PROCESS';
   
      SELECT id
        INTO l_billing_profile_id
        FROM oks_billing_profiles_b obp
       WHERE obp.invoice_jtot_object1_code = 'OKX_INVRULE' AND
             billing_type = 'ONETIME';
   
      FOR cur_contract IN cst_contract_headers LOOP
      
         SELECT code, cls_code
           INTO l_class_code, l_cls_code
           FROM okc_subclasses_v t
          WHERE t.meaning = cur_contract.contract_type; --'Service Agreement'; --!!!!!!!!!!!!!!!!!!!!!!
      
         BEGIN
         
            l_chrid                 := NULL;
            l_return_status         := NULL;
            l_msg_count             := NULL;
            l_msg_data              := NULL;
            l_err_msg               := NULL;
            l_msg_index_out         := NULL;
            l_org_id                := NULL;
            l_inv_organization_id   := NULL;
            l_party_id              := NULL;
            l_bill_id               := NULL;
            l_ship_id               := NULL;
            l_contact_id            := NULL;
            l_duration              := NULL;
            l_duration_uom          := NULL;
            l_price_list_id         := NULL;
            l_line_price_list_id    := NULL;
            l_payment_terms_id      := NULL;
            l_rate                  := NULL;
            l_invoice_text          := NULL;
            l_cust_account_id       := NULL;
            v_lse_id                := NULL;
            l_osh_cust_acct         := NULL;
            l_cle_id                := NULL;
            l_line_item_id          := NULL;
            l_coverage_template_id  := NULL;
            l_cimv_id               := NULL;
            l_instance_id           := NULL;
            l_inventory_item_id     := NULL;
            l_unit_of_measure       := NULL;
            l_quantity              := NULL;
            l_salesrep_id           := NULL;
            l_group_id              := NULL;
            l_sub_cle_id            := NULL;
            v_sub_lse_id            := NULL;
            l_sub_cimv_id           := NULL;
            l_security_group_id     := NULL;
            l_renewal_price_list_id := NULL;
            l_billing_profile_id    := NULL;
            l_oks_id                := NULL;
            l_object_version_number := NULL;
            l_coverage_id           := NULL;
            l_price_list_for_rh     := NULL;
            t_header_contacts_tbl   := t_header_contacts_tbl_miss;
         
            BEGIN
            
               SELECT ou.organization_id, l.currency_code
                 INTO l_org_id, l_func_curr
                 FROM hr_operating_units ou, gl_ledgers l
                WHERE ou.NAME = cur_contract.operation_unit AND
                      ou.set_of_books_id = l.ledger_id;
            
               okc_context.set_okc_org_context(p_org_id          => l_org_id,
                                               p_organization_id => l_master_org_id);
            
               okc_time_util_pub.get_duration(p_start_date    => cur_contract.effect_date,
                                              p_end_date      => cur_contract.expir_date,
                                              x_duration      => l_duration,
                                              x_timeunit      => l_duration_uom,
                                              x_return_status => l_return_status);
            
            EXCEPTION
               WHEN OTHERS THEN
                  l_err_msg := 'Invalid Operating Unit';
                  RAISE invalid_contract;
            END;
         
            BEGIN
            
               SELECT cgpb.id
                 INTO l_group_id
                 FROM okc_k_groups_b cgpb, okc_k_groups_tl cgpt
                WHERE cgpb.id = cgpt.id AND
                      NAME = cur_contract.contract_group AND
                      cgpt.LANGUAGE = userenv('LANG');
            EXCEPTION
               WHEN OTHERS THEN
                  l_err_msg := 'Invalid Group';
                  RAISE invalid_contract;
            END;
         
            IF l_class_code = 'SERVICE' THEN
               BEGIN
               
                  SELECT pl.list_header_id
                    INTO l_renewal_price_list_id
                    FROM qp_list_headers_all pl
                   WHERE pl.NAME = cur_contract.renewal_price_list;
               
               EXCEPTION
                  WHEN OTHERS THEN
                     l_err_msg := 'Invalid renual price list';
                     RAISE invalid_contract;
               END;
            END IF;
         
            BEGIN
            
               SELECT cip.party_id,
                      cia.bill_to_address,
                      cia.ship_to_address,
                      cia.party_account_id
                 INTO l_party_id, l_bill_id, l_ship_id, l_cust_account_id
                 FROM xxobjt_conv_oks_contracts t,
                      csi_item_instances        cii,
                      csi_i_parties             cip,
                      csi_ip_accounts           cia
                WHERE t.serial = cii.serial_number AND
                      cii.instance_id = cip.instance_id AND
                      cip.instance_party_id = cia.instance_party_id AND
                      cia.relationship_type_code = 'OWNER' AND
                      cip.party_source_table = 'HZ_PARTIES' AND
                      cia.active_end_date IS NULL AND
                      contract_number = cur_contract.contract_number AND
                      rownum < 2;
            
            EXCEPTION
               WHEN OTHERS THEN
               
                  /*            BEGIN
                     SELECT hp.party_id,
                            cs_bill.site_use_id,
                            cs_ship.site_use_id,
                            ca_bill.cust_account_id
                       INTO l_party_id,
                            l_bill_id,
                            l_ship_id,
                            l_cust_account_id
                       FROM hz_parties             hp,
                            hz_party_sites         ps_bill,
                            hz_cust_acct_sites_all ca_bill,
                            hz_cust_site_uses_all  cs_bill,
                            hz_party_sites         ps_ship,
                            hz_cust_acct_sites_all ca_ship,
                            hz_cust_site_uses_all  cs_ship
                      WHERE hp.party_id = ps_bill.party_id(+) AND
                            ps_bill.party_site_id =
                            ca_bill.party_site_id(+) AND
                            ca_bill.cust_acct_site_id =
                            cs_bill.cust_acct_site_id(+) AND
                           --   ca_bill.orig_system_reference (+) = p_site_identifier and
                            ca_bill.org_id(+) = l_org_id AND
                            cs_bill.site_use_code(+) = 'BILL_TO' AND
                            hp.party_id = ps_ship.party_id(+) AND
                            ps_ship.party_site_id =
                            ca_ship.party_site_id(+) AND
                            ca_ship.cust_acct_site_id =
                            cs_ship.cust_acct_site_id(+) AND
                           --   ca_ship.orig_system_reference (+) = p_site_identifier and
                            ca_ship.org_id(+) = l_org_id AND
                            cs_ship.site_use_code(+) = 'SHIP_TO' AND
                            party_name = cur_contract.party;
                  EXCEPTION
                     WHEN OTHERS THEN*/
                  l_err_msg := 'Invalid product/customer';
                  RAISE invalid_contract;
                  --   END;
            END;
         
            BEGIN
            
               SELECT 'missing product: ' || serial
                 INTO l_err_msg
                 FROM xxobjt_conv_oks_contracts t
                WHERE contract_number = cur_contract.contract_number AND
                      NOT EXISTS
                (SELECT 1
                         FROM csi_item_instances cii
                        WHERE cii.serial_number = t.serial);
            
               RAISE invalid_contract;
            
            EXCEPTION
               WHEN no_data_found THEN
                  NULL;
            END;
         
            IF cur_contract.sales_person IS NOT NULL THEN
               BEGIN
               
                  SELECT srp.salesrep_id
                    INTO l_salesrep_id
                    FROM jtf_rs_salesreps         srp,
                         oe_sales_credit_types    st,
                         jtf_rs_resource_extns_vl b,
                         jtf_objects_vl           c
                   WHERE srp.sales_credit_type_id = st.sales_credit_type_id AND
                         srp.resource_id = b.resource_id AND
                         b.category = c.object_code AND
                         b.resource_name = cur_contract.sales_person AND
                         org_id = l_org_id;
               
               EXCEPTION
                  WHEN no_data_found THEN
                     l_salesrep_id := -3;
                  
               END;
            ELSE
               l_salesrep_id := -3;
            END IF;
         
            IF l_class_code = 'SERVICE' THEN
            
               BEGIN
                  SELECT pl.list_header_id
                    INTO l_price_list_id
                    FROM qp_list_headers_all pl
                   WHERE pl.NAME = cur_contract.contract_price_list;
               EXCEPTION
                  WHEN OTHERS THEN
                     l_err_msg := 'Invalid price list';
                     RAISE invalid_contract;
               END;
            
            END IF;
         
            BEGIN
               SELECT t.term_id
                 INTO l_payment_terms_id
                 FROM ra_terms_vl t
                WHERE t.description = cur_contract.payment_terms OR
                      t.NAME = cur_contract.payment_terms;
            EXCEPTION
               WHEN OTHERS THEN
                  l_err_msg := 'Invalid terms';
                  RAISE invalid_contract;
            END;
         
            IF cur_contract.link_curr != 'USD' THEN
            
               BEGIN
                  l_rate := gl_currency_api.get_rate(x_from_currency   => cur_contract.link_curr,
                                                     x_to_currency     => l_func_curr,
                                                     x_conversion_date => SYSDATE,
                                                     x_conversion_type => 'Corporate');
               EXCEPTION
                  WHEN OTHERS THEN
                     l_err_msg := 'Invalid rate';
                     RAISE invalid_contract;
               END;
            
            ELSE
               l_rate := NULL;
            END IF;
         
            t_header_rec := t_header_rec_miss;
         
            -- t_header_rec.contract_number   := cur_contract.contract_number;
            t_header_rec.start_date        := cur_contract.effect_date;
            t_header_rec.end_date          := cur_contract.expir_date;
            t_header_rec.sts_code          := 'ACTIVE'; --;'ENTERED'; --
            t_header_rec.scs_code          := l_class_code; --l_cls_code;
            t_header_rec.authoring_org_id  := l_org_id;
            t_header_rec.chr_group         := l_group_id;
            t_header_rec.short_description := cur_contract.description;
            t_header_rec.party_id          := l_party_id;
            t_header_rec.bill_to_id        := l_bill_id;
            t_header_rec.ship_to_id        := l_ship_id;
            t_header_rec.currency          := cur_contract.link_curr;
            --t_header_rec.cust_po_number        := cur_contract.po_number;
            t_header_rec.price_list_id         := l_price_list_id; --PRE
            t_header_rec.payment_term_id       := l_payment_terms_id; --PTR
            t_header_rec.cvn_type              := (CASE WHEN cur_contract.link_curr = l_func_curr THEN NULL ELSE 'Corporate' END); --CVN
            t_header_rec.cvn_rate              := l_rate; --CVN
            t_header_rec.cvn_date              := NULL; --(CASE WHEN cur_contract.link_curr = 'USD' THEN NULL WHEN l_org_id = 81 THEN SYSDATE END); --CVN
            t_header_rec.cvn_euro_rate         := NULL; --CVN
            t_header_rec.renewal_type          := (CASE WHEN cur_contract.renewal_process = 'Do Not Renew' THEN 'DNR' ELSE 'NSR' END);
            t_header_rec.renewal_pricing_type  := 'LST';
            t_header_rec.renewal_price_list_id := l_renewal_price_list_id;
            t_header_rec.qcl_id                := l_qcl_id;
            t_header_rec.pdf_id                := l_pdf_id;
            t_header_rec.attribute15           := cur_contract.contract_number;
            t_header_rec.attribute14           := cur_contract.priority_contract_id;
            t_header_rec.attribute3            := NULL;
            t_header_rec.attribute4            := NULL;
            t_header_rec.attribute5            := NULL;
            t_header_rec.attribute6            := NULL;
            t_header_rec.attribute7            := NULL;
            t_header_rec.attribute8            := NULL;
            t_header_rec.attribute9            := NULL;
            t_header_rec.attribute10           := NULL;
            t_header_rec.attribute11           := NULL;
            t_header_rec.attribute12           := NULL;
            t_header_rec.attribute13           := NULL;
            t_header_rec.attribute1            := NULL;
            t_header_rec.attribute2            := NULL;
            t_header_rec.accounting_rule_type  := 1000;
            t_header_rec.ar_interface_yn       := 'Y';
            t_header_rec.summary_invoice_yn    := 'N';
            t_header_rec.invoice_rule_type     := -2;
         
            /*     SELECT a.cro_code
                    INTO l_contact_role
                    FROM okc_contact_sources_v a, fnd_lookups b
                   WHERE a.cro_code = b.lookup_code AND
                         b.lookup_type = 'OKC_CONTACT_ROLE' AND
                         a.rle_code = 'CUSTOMER' AND
                         a.buy_or_sell = 'S' AND
                         SYSDATE BETWEEN nvl(a.start_date, SYSDATE) AND
                         nvl(a.end_date, SYSDATE) AND
                         a.cro_code NOT LIKE 'CUST%';
            */
         
            t_header_contacts_tbl := t_header_contacts_tbl_miss;
         
            t_header_contacts_tbl(1).party_role := 'VENDOR';
            t_header_contacts_tbl(1).contact_role := 'SALESPERSON';
            t_header_contacts_tbl(1).contact_object_code := 'OKX_SALEPERS';
            t_header_contacts_tbl(1).contact_id := nvl(l_salesrep_id, -3);
         
            IF cur_contract.contact_name IS NOT NULL THEN
            
               BEGIN
               
                  SELECT r.party_id
                    INTO l_contact_id
                    FROM hz_relationships r,
                         hz_parties       p3,
                         hz_parties       p2,
                         hz_org_contacts  oc
                   WHERE p2.party_id = r.subject_id AND
                         r.relationship_code IN
                         ('CONTACT_OF', 'EMPLOYEE_OF') AND
                         r.content_source_type = 'USER_ENTERED' AND
                         p3.party_id = r.party_id AND
                         oc.party_relationship_id = r.relationship_id AND
                         r.object_id = l_party_id AND --:oks_header_parties.object1_id1 AND
                         SYSDATE BETWEEN nvl(r.start_date, SYSDATE) AND
                         nvl(r.end_date, SYSDATE) AND
                         upper(TRIM(TRIM(p2.person_first_name) || ' ' ||
                                    TRIM(p2.person_last_name))) =
                         upper(cur_contract.contact_name) AND
                         r.status = 'A' AND
                         nvl(oc.status, 'A') = 'A' AND
                         p2.status = 'A';
               
                  t_header_contacts_tbl(2).party_role := 'CUSTOMER';
                  t_header_contacts_tbl(2).contact_role := 'XXCS_CONTRACT_CONTACT';
                  t_header_contacts_tbl(2).contact_object_code := 'OKX_PCONTACT';
                  t_header_contacts_tbl(2).contact_id := l_contact_id;
               
               EXCEPTION
                  WHEN OTHERS THEN
                     NULL;
               END;
            END IF;
         
            fnd_msg_pub.initialize;
            oks_contracts_pub.create_contract_header(p_k_header_rec         => t_header_rec,
                                                     p_header_contacts_tbl  => t_header_contacts_tbl,
                                                     p_header_sales_crd_tbl => t_header_sales_crd_tbl,
                                                     p_header_articles_tbl  => t_header_articles_tbl,
                                                     x_chrid                => l_chrid,
                                                     x_return_status        => l_return_status,
                                                     x_msg_count            => l_msg_count,
                                                     x_msg_data             => l_msg_data);
         
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
         
            insert_sales_credit(l_chrid,
                                l_salesrep_id,
                                l_return_status,
                                l_msg_data);
         
            BEGIN
            
               SELECT group_id
                 INTO l_security_group_id
                 FROM okc_resource_groups_v
                WHERE SYSDATE BETWEEN start_date_active AND
                      nvl(end_date_active, SYSDATE) AND
                      status = 'A' AND
                      delete_flag = 'N' AND
                      NAME = cur_contract.security_group;
            EXCEPTION
               WHEN OTHERS THEN
                  l_err_msg := 'Invalid security Group';
                  RAISE invalid_contract;
            END;
         
            t_cacv_tbl_in(1).chr_id := l_chrid;
            t_cacv_tbl_in(1).group_id := l_security_group_id;
            t_cacv_tbl_in(1).resource_id := NULL;
            t_cacv_tbl_in(1).access_level := 'U';
            t_cacv_tbl_in(1).created_by := g_user_id;
            t_cacv_tbl_in(1).creation_date := SYSDATE;
            t_cacv_tbl_in(1).last_updated_by := g_user_id;
            t_cacv_tbl_in(1).last_update_date := SYSDATE;
            t_cacv_tbl_in(1).last_update_login := -1;
         
            okc_contract_pub.create_contract_access(p_api_version   => 1.0,
                                                    p_init_msg_list => 'T',
                                                    x_return_status => l_return_status,
                                                    x_msg_count     => l_msg_count,
                                                    x_msg_data      => l_msg_data,
                                                    p_cacv_tbl      => t_cacv_tbl_in,
                                                    x_cacv_tbl      => t_cacv_tbl_out);
         
            FOR cur_line IN csr_contract_lines(cur_contract.contract_number) LOOP
               l_counter := l_counter + 1;
            
               BEGIN
                  SELECT inventory_item_id,
                         b.coverage_schedule_id,
                         b.primary_uom_code
                    INTO l_line_item_id, l_coverage_template_id, l_item_uom
                    FROM mtl_system_items_b b
                   WHERE segment1 = cur_line.covered_level AND
                         b.organization_id =
                         okc_context.get_okc_organization_id;
               
               EXCEPTION
                  WHEN OTHERS THEN
                     l_err_msg := 'Inalid covered level';
                     RAISE invalid_contract;
               END;
            
               BEGIN
                  SELECT b.list_header_id
                    INTO l_price_list_for_rh
                    FROM qp_list_headers_all_b b, qp_list_headers_tl tl
                   WHERE b.list_header_id = tl.list_header_id AND
                         tl.LANGUAGE = 'US' AND
                         tl.NAME = cur_line.price_list_for_replace_heads;
               EXCEPTION
                  WHEN OTHERS THEN
                     BEGIN
                     
                        SELECT b.list_header_id
                          INTO l_line_price_list_id
                          FROM qp_list_headers_all_b b,
                               qp_list_headers_tl    tl
                         WHERE b.list_header_id = tl.list_header_id AND
                               tl.LANGUAGE = 'US' AND
                               tl.description = cur_line.price_list_a;
                     
                     EXCEPTION
                        WHEN OTHERS THEN
                           l_err_msg           := SQLERRM;
                           l_price_list_for_rh := NULL; --l_err_msg := 'Invalid LINE price list';
                        -- RAISE invalid_contract;
                     END;
                  
               END;
            
               BEGIN
                  SELECT instance_id,
                         msi.inventory_item_id,
                         unit_of_measure,
                         quantity,
                         cur_line.covered_level || ':' || quantity || ':' ||
                         msi.description || ':' || cur_line.line_start_date || ':' ||
                         cur_line.line_end_date
                    INTO l_instance_id,
                         l_inventory_item_id,
                         l_unit_of_measure,
                         l_quantity,
                         l_invoice_text
                    FROM mtl_system_items_b msi, csi_item_instances cii
                   WHERE msi.inventory_item_id = cii.inventory_item_id AND
                         msi.organization_id = l_master_org_id AND
                         msi.segment1 = cur_line.item AND
                         cii.serial_number = cur_line.serial;
               
               EXCEPTION
                  WHEN OTHERS THEN
                     l_err_msg := 'Inalid product';
                     RAISE invalid_contract;
               END;
            
               --AND B.INVENTORY_ITEM_ID = (select object1_id1 from okc_k_items_v where cle_id = p_cle_id);
            
               ---------------------------------- Create OKC Line ------------------------------------
            
               populate_okc_line(x_clev_tbl_out => l_clev_tbl_in);
            
               OPEN get_line_no(l_chrid);
               FETCH get_line_no
                  INTO v_line_number;
               CLOSE get_line_no;
               IF v_line_number IS NULL THEN
                  v_line_number := 1;
               ELSE
                  v_line_number := v_line_number + 1;
               END IF;
               l_clev_tbl_in(1).line_number := v_line_number;
               l_clev_tbl_in(1).cle_id := okc_api.g_miss_num;
            
               l_clev_tbl_in(1).object_version_number := 1;
               l_clev_tbl_in(1).dnz_chr_id := l_chrid;
               --l_clev_tbl_in(1).date_terminated := (CASE WHEN cur_line.expir_date > SYSDATE THEN cur_line.expir_date ELSE NULL END);
               l_clev_tbl_in(1).currency_code := cur_line.link_curr;
               l_clev_tbl_in(1).sfwt_flag := 'N';
               l_clev_tbl_in(1).lse_id := (CASE WHEN l_class_code = 'SERVICE' THEN 1 ELSE 14 END); --1;
               l_clev_tbl_in(1).sts_code := 'ACTIVE';
               l_clev_tbl_in(1).exception_yn := 'N';
               l_clev_tbl_in(1).price_negotiated := cur_line.subtotal;
               l_clev_tbl_in(1).price_level_ind := 'Y';
            
               l_clev_tbl_in(1).created_by := l_user_id;
               l_clev_tbl_in(1).creation_date := SYSDATE;
               l_clev_tbl_in(1).last_updated_by := l_user_id;
               l_clev_tbl_in(1).last_update_date := SYSDATE;
               l_clev_tbl_in(1).last_update_login := -1;
            
               l_clev_tbl_in(1).display_sequence := 1;
               l_clev_tbl_in(1).cust_acct_id := l_cust_account_id;
               l_clev_tbl_in(1).bill_to_site_use_id := l_bill_id;
               l_clev_tbl_in(1).ship_to_site_use_id := l_ship_id;
               --l_clev_tbl_in(1).line_renewal_type_code := name_in(p_block ||'.line_renewal_type_code');
               l_clev_tbl_in(1).start_date := cur_line.line_start_date;
               l_clev_tbl_in(1).end_date := cur_line.line_end_date;
               l_clev_tbl_in(1).price_unit := okc_api.g_miss_num;
               l_clev_tbl_in(1).price_unit_percent := okc_api.g_miss_num;
               l_clev_tbl_in(1).cle_id := okc_api.g_miss_num;
               l_clev_tbl_in(1).chr_id := l_chrid;
               l_clev_tbl_in(1).price_list_id := l_price_list_id;
               -- l_clev_tbl_in(1).price_list_line_id := l_line_price_list_id;
               -- l_clev_tbl_in(1).payment_instruction_type := name_in(p_block ||'.payment_instruction_type');
            
               fnd_msg_pub.initialize;
               okc_contract_pub.create_contract_line(p_api_version       => 1.0,
                                                     p_init_msg_list     => l_init_msg_list,
                                                     x_return_status     => l_return_status,
                                                     x_msg_count         => l_msg_count,
                                                     x_msg_data          => l_msg_data,
                                                     p_restricted_update => 'F',
                                                     p_clev_tbl          => l_clev_tbl_in,
                                                     x_clev_tbl          => l_clev_tbl_out);
            
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
            
               l_cle_id := l_clev_tbl_out(1).id;
            
               ---------------------------------- Create Actual Coverage ------------------------------------
            
               t_ac_rec_type.svc_cle_id := l_cle_id;
               t_ac_rec_type.tmp_cle_id := l_coverage_template_id;
               t_ac_rec_type.start_date := cur_line.line_start_date;
               t_ac_rec_type.end_date   := cur_line.line_end_date;
               t_ac_rec_type.rle_code   := 'VENDOR';
            
               oks_coverages_pub.create_actual_coverage(p_api_version        => 1.0,
                                                        p_init_msg_list      => l_init_msg_list,
                                                        x_return_status      => l_return_status,
                                                        x_msg_count          => l_msg_count,
                                                        x_msg_data           => l_msg_data,
                                                        p_ac_rec_in          => t_ac_rec_type,
                                                        x_actual_coverage_id => l_actual_coverage_id);
            
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
               ---------------------------------- Create OKS Line ------------------------------------
            
               -- IF l_class_code = 'SERVICE' THEN
               BEGIN
                  SELECT b.list_header_id
                    INTO l_line_price_list_id
                    FROM qp_list_headers_all_b b, qp_list_headers_tl tl
                   WHERE b.list_header_id = tl.list_header_id AND
                         tl.LANGUAGE = 'US' AND
                         tl.NAME = cur_line.price_list;
               EXCEPTION
                  WHEN OTHERS THEN
                  
                     BEGIN
                     
                        SELECT b.list_header_id
                          INTO l_line_price_list_id
                          FROM qp_list_headers_all_b b,
                               qp_list_headers_tl    tl
                         WHERE b.list_header_id = tl.list_header_id AND
                               tl.LANGUAGE = 'US' AND
                               tl.description = cur_line.price_list_b;
                     
                     EXCEPTION
                        WHEN OTHERS THEN
                           l_err_msg := SQLERRM;
                           l_err_msg := 'Invalid LINE price list';
                           RAISE invalid_contract;
                     END;
                  
               END;
            
               -- END IF;
               populate_oks_line(l_klnv_tbl_in);
            
               l_klnv_tbl_in(1).cle_id := l_cle_id;
               l_klnv_tbl_in(1).dnz_chr_id := l_chrid;
               l_klnv_tbl_in(1).sfwt_flag := 'N';
               -- l_klnv_tbl_in(1).invoice_text := name_in(p_block || '.invoice_text');           
               l_klnv_tbl_in(1).created_by := l_user_id;
               l_klnv_tbl_in(1).creation_date := SYSDATE;
               l_klnv_tbl_in(1).last_updated_by := l_user_id;
               l_klnv_tbl_in(1).last_update_date := SYSDATE;
               l_klnv_tbl_in(1).last_update_login := -1;
               l_klnv_tbl_in(1).tax_amount := cur_line.tax;
               -- l_klnv_tbl_in(1).tax_inclusive_yn := name_in(p_block ||'.tax_inclusive_yn');
               -- l_klnv_tbl_in(1).tax_status := name_in(p_block ||'.tax_status');
               -- l_klnv_tbl_in(1).tax_code := name_in(p_block || '.tax_code');
               -- start R12 eBtax
               -- l_klnv_tbl_in(1).tax_classification_code := name_in(p_block ||'.tax_classification_code');
               -- l_klnv_tbl_in(1).exempt_certificate_number := name_in(p_block ||'.tax_exemption_number');
               -- l_klnv_tbl_in(1).exempt_reason_code := name_in(p_block ||'.exempt_reason_code');
               -- end R12 eBtax
               -- l_klnv_tbl_in(1).tax_exemption_id := name_in(p_block ||'.tax_exemption_id');
               l_klnv_tbl_in(1).inv_print_flag := 'Y';
               -- l_klnv_tbl_in(1).averaging_interval := name_in(p_block || '.averaging_interval');
               -- l_klnv_tbl_in(1).usage_period := name_in(p_block ||'.rate_min_time_uom_code');
               -- l_klnv_tbl_in(1).settlement_interval := name_in(p_block ||'.settlement_interval');
               -- l_klnv_tbl_in(1).termn_method := name_in(p_block ||'.termn_method');
               -- l_klnv_tbl_in(1).usage_type := name_in(p_block || '.usage_type');
               -- l_klnv_tbl_in(1).payment_type := name_in(p_block ||'.payment_type');
               -- l_klnv_tbl_in(1).cust_po_number_req_yn := name_in(p_block ||'.cust_po_number_req_yn');
               -- l_klnv_tbl_in(1).cust_po_number := name_in(p_block ||'.cust_po_number');
               -- l_klnv_tbl_in(1).commitment_id := name_in(p_block ||'.commitment_id');
               -- l_klnv_tbl_in(1).trxn_extension_id := name_in(p_block ||'.trxn_extension_ID'); --abkumar cc ext           
               -- l_klnv_tbl_in(1).locked_price_list_id := l_line_price_list_id;
               -- l_klnv_tbl_in(1).break_uom := name_in(p_block ||'.break_uom');
               -- l_klnv_tbl_in(1).locked_price_list_line_id := name_in(p_block |'.locked_price_list_line_id');
               -- l_klnv_tbl_in(1).prorate := name_in(p_block || '.prorate');
               -- Partial Period Computation --
               --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
               l_klnv_tbl_in(1).price_uom := 'YR';
               l_klnv_tbl_in(1).coverage_id := l_actual_coverage_id; --l_coverage_template_id; -- 
               l_klnv_tbl_in(1).pm_program_id := 10021;
               l_klnv_tbl_in(1).clvl_list_price := l_line_price_list_id;
               l_klnv_tbl_in(1).standard_cov_yn := 'N';
               -- CRA --
               -- GCHADHA --
               fnd_msg_pub.initialize;
               oks_contract_line_pub.create_line(p_api_version   => 1.0,
                                                 p_init_msg_list => l_init_msg_list,
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
            
               v_lse_id      := l_klnv_tbl_out(1).id;
               l_coverage_id := l_klnv_tbl_out(1).coverage_id;
            
               ---------------------------------- Create Item Line ------------------------------------
            
               l_cimv_tbl_in(1).chr_id := NULL;
               l_cimv_tbl_in(1).cle_id := l_cle_id;
               l_cimv_tbl_in(1).dnz_chr_id := l_chrid;
               l_cimv_tbl_in(1).object1_id1 := l_line_item_id;
               l_cimv_tbl_in(1).object1_id2 := l_master_org_id;
               l_cimv_tbl_in(1).jtot_object1_code := 'OKX_SERVICE';
               l_cimv_tbl_in(1).number_of_items := 1; --name_in(p_block ||'.SUBS_QTY');
               l_cimv_tbl_in(1).uom_code := l_item_uom; --name_in(p_block ||'.SUBS_UOM_CODE');           
               l_cimv_tbl_in(1).priced_item_yn := 'Y';
               l_cimv_tbl_in(1).exception_yn := 'N';
               l_cimv_tbl_in(1).created_by := l_user_id;
               l_cimv_tbl_in(1).creation_date := SYSDATE;
               l_cimv_tbl_in(1).last_updated_by := l_user_id;
               l_cimv_tbl_in(1).last_update_date := SYSDATE;
               l_cimv_tbl_in(1).last_update_login := -1;
            
               --l_cimv_tbl_in(1).object_version_number := name_in(p_block ||'.ITEM_object_version_number');
            
               fnd_msg_pub.initialize;
               okc_contract_item_pub.create_contract_item(p_api_version   => 1.0,
                                                          p_init_msg_list => l_init_msg_list,
                                                          x_return_status => l_return_status,
                                                          x_msg_count     => l_msg_count,
                                                          x_msg_data      => l_msg_data,
                                                          p_cimv_tbl      => l_cimv_tbl_in,
                                                          x_cimv_tbl      => l_cimv_tbl_out);
            
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
            
               l_cimv_id := l_cimv_tbl_out(1).id;
            
               ----------------------------- Update Coverage line price list -------------------------
               populate_okc_line(l_clev_tbl_in);
               l_counter := 0;
               FOR cur_coverage_line IN csr_coverage_lines(l_actual_coverage_id) LOOP
               
                  l_counter := l_counter + 1;
                  l_clev_tbl_in(l_counter).id := cur_coverage_line.id;
                  l_clev_tbl_in(l_counter).dnz_chr_id := cur_coverage_line.dnz_chr_id;
                  l_clev_tbl_in(l_counter).cle_id := cur_coverage_line.coverage_cle_id;
                  IF cur_coverage_line.process_name = 'Replace Heads' THEN
                     l_clev_tbl_in(l_counter).price_list_id := l_price_list_for_rh;
                  ELSE
                     l_clev_tbl_in(l_counter).price_list_id := l_line_price_list_id;
                  END IF;
                  l_clev_tbl_in(l_counter).start_date := cur_coverage_line.start_date;
                  l_clev_tbl_in(l_counter).end_date := cur_coverage_line.end_date;
                  l_clev_tbl_in(l_counter).object_version_number := cur_coverage_line.object_version_number;
               
               END LOOP;
            
               okc_contract_pub.update_contract_line(p_api_version       => 1.0,
                                                     p_init_msg_list     => l_init_msg_list,
                                                     x_return_status     => l_return_status,
                                                     x_msg_count         => l_msg_count,
                                                     x_msg_data          => l_msg_data,
                                                     p_restricted_update => 'T',
                                                     p_clev_tbl          => l_clev_tbl_in,
                                                     x_clev_tbl          => l_clev_tbl_out);
            
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
               ---------------------------------- Additional Line Tasks ------------------------------------
               /*                cs_counters_pub.autoinstantiate_counters(p_api_version               => 1.0,
                                                            p_init_msg_list             => 'T',
                                                            p_commit                    => 'F',
                                                            x_return_status             => l_return_status,
                                                            x_msg_count                 => l_msg_count,
                                                            x_msg_data                  => l_msg_data,
                                                            p_source_object_id_template => l_line_item_id,
                                                            p_source_object_id_instance => l_cle_id,
                                                            x_ctr_grp_id_template       => l_ctr_grp_id_template,
                                                            x_ctr_grp_id_instance       => x_ctr_grp_id_instance);
                   
                   IF (x_return_status) <> 'S' THEN
                      okc_forms_util.display_errors(p_stat => x_return_status);
                      RAISE form_trigger_failure;
                   END IF;
                   oks_extwar_util_pvt.update_timestamp(p_counter_group_id   => x_ctr_grp_id_instance,
                                                        p_service_start_date => cur_contract.effect_date,
                                                        p_service_line_id    => l_cle_id,
                                                        x_status             => l_status);
                   
                   IF (l_status) <> 'S' THEN
                      okc_forms_util.display_errors(p_stat => l_status);
                      RAISE form_trigger_failure;
                   END IF;
                   
                    
                   l_inp_rec.ins_ctr_grp_id   := x_ctr_grp_id_instance;
                   l_inp_rec.tmp_ctr_grp_id   := x_ctr_grp_id_template;
                   l_inp_rec.chr_id           := l_chrid;
                   l_inp_rec.cle_id           := l_cle_id;
                   l_inp_rec.jtot_object_code := 'OKC_K_LINE';
                   l_inp_rec.inv_item_id      := l_line_item_id;
                   
                   okc_inst_cnd_pub.inst_condition(p_api_version     => 1.0,
                                                   p_init_msg_list   => 'T',
                                                   x_return_status   => l_return_status,
                                                   x_msg_count       => l_msg_count,
                                                   x_msg_data        => l_msg_data,
                                                   p_instcnd_inp_rec => l_inp_rec);
                   
                   IF (x_return_status) <> 'S' THEN
                      okc_forms_util.display_errors(p_stat => x_return_status);
                      RAISE form_trigger_failure;
                   END IF;
               */
               fnd_msg_pub.initialize;
               oks_extwar_util_pvt.create_sales_credits(p_header_id     => l_chrid,
                                                        p_line_id       => l_cle_id,
                                                        x_return_status => l_return_status);
            
               -- Create Subscription Schedule
               oks_subscription_pub.create_default_schedule(p_api_version   => 1.0,
                                                            p_init_msg_list => 'F',
                                                            x_return_status => l_return_status,
                                                            x_msg_count     => l_msg_count,
                                                            x_msg_data      => l_msg_data,
                                                            p_intent        => 'SB_O',
                                                            p_cle_id        => l_cle_id);
            
               ---------------------------------- Create OKC Sub Line ------------------------------------
               populate_okc_line(x_clev_tbl_out => l_clev_tbl_in);
            
               OPEN get_subline_no(l_chrid, l_cle_id);
               FETCH get_subline_no
                  INTO v_line_number;
               CLOSE get_subline_no;
            
               IF v_line_number IS NULL THEN
                  v_line_number := 1;
               ELSE
                  v_line_number := v_line_number + 1;
               END IF;
            
               l_clev_tbl_in(1).line_number := v_line_number;
               l_clev_tbl_in(1).dnz_chr_id := l_chrid;
               l_clev_tbl_in(1).trn_code := okc_api.g_miss_char;
               l_clev_tbl_in(1).comments := okc_api.g_miss_char;
               l_clev_tbl_in(1).hidden_ind := okc_api.g_miss_char;
               l_clev_tbl_in(1).invoice_line_level_ind := okc_api.g_miss_char;
            
               l_clev_tbl_in(1).dpas_rating := okc_api.g_miss_char;
               l_clev_tbl_in(1).template_used := okc_api.g_miss_char;
               l_clev_tbl_in(1).date_terminated := okc_api.g_miss_date;
               l_clev_tbl_in(1).price_type := okc_api.g_miss_char;
               l_clev_tbl_in(1).currency_code := cur_line.link_curr;
               l_clev_tbl_in(1).sfwt_flag := 'N';
               l_clev_tbl_in(1).lse_id := 9;
               l_clev_tbl_in(1).sts_code := 'ACTIVE';
               l_clev_tbl_in(1).exception_yn := 'N';
               l_clev_tbl_in(1).price_negotiated := cur_line.subtotal;
               l_clev_tbl_in(1).price_level_ind := 'Y';
               l_clev_tbl_in(1).price_list_id := l_line_price_list_id;
               --l_clev_tbl_in(1).upg_orig_system_ref_id := name_in(p_block ||'.UPG_ORIG_SYSTEM_REF_ID');
               --l_clev_tbl_in(1).upg_orig_system_ref := name_in(p_block ||'.UPG_ORIG_SYSTEM_REF');            
               l_clev_tbl_in(1).created_by := l_user_id;
               l_clev_tbl_in(1).creation_date := SYSDATE;
               l_clev_tbl_in(1).last_updated_by := l_user_id;
               l_clev_tbl_in(1).last_update_date := SYSDATE;
               l_clev_tbl_in(1).last_update_login := -1;
               l_clev_tbl_in(1).start_date := cur_line.line_start_date;
               l_clev_tbl_in(1).end_date := cur_line.line_end_date;
               -- l_clev_tbl_in(1).price_unit := name_in(p_block ||'.UNIT_PRICE');
               -- l_clev_tbl_in(1).price_unit_percent := name_in(p_block ||'.price_unit_percent');
               -- l_clev_tbl_in(1).line_renewal_type_code := name_in(p_block ||'.LINE_RENEWAL_TYPE_CODE');
               l_clev_tbl_in(1).display_sequence := 2;
               l_clev_tbl_in(1).cle_id := l_cle_id;
               l_clev_tbl_in(1).chr_id := okc_api.g_miss_num;
            
               fnd_msg_pub.initialize;
               okc_contract_pub.create_contract_line(p_api_version       => 1.0,
                                                     p_init_msg_list     => l_init_msg_list,
                                                     x_return_status     => l_return_status,
                                                     x_msg_count         => l_msg_count,
                                                     x_msg_data          => l_msg_data,
                                                     p_restricted_update => 'F',
                                                     p_clev_tbl          => l_clev_tbl_in,
                                                     x_clev_tbl          => l_clev_tbl_out);
            
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
            
               l_sub_cle_id := l_clev_tbl_out(1).id;
            
               ---------------------------------- Create Item Sub Line ------------------------------------
            
               l_cimv_tbl_in(1).chr_id := NULL;
               l_cimv_tbl_in(1).cle_id := l_sub_cle_id; --l_cle_id;
               l_cimv_tbl_in(1).dnz_chr_id := l_chrid;
               l_cimv_tbl_in(1).object1_id1 := l_instance_id;
               l_cimv_tbl_in(1).object1_id2 := '#';
               l_cimv_tbl_in(1).jtot_object1_code := 'OKX_CUSTPROD';
            
               l_cimv_tbl_in(1).number_of_items := l_quantity;
               l_cimv_tbl_in(1).uom_code := l_unit_of_measure;
               l_cimv_tbl_in(1).priced_item_yn := 'Y';
               l_cimv_tbl_in(1).exception_yn := 'N';
               l_cimv_tbl_in(1).created_by := l_user_id;
               l_cimv_tbl_in(1).creation_date := SYSDATE;
               l_cimv_tbl_in(1).last_updated_by := l_user_id;
               l_cimv_tbl_in(1).last_update_date := SYSDATE;
               l_cimv_tbl_in(1).last_update_login := -1;
            
               fnd_msg_pub.initialize;
               okc_contract_item_pub.create_contract_item(p_api_version   => 1.0,
                                                          p_init_msg_list => l_init_msg_list,
                                                          x_return_status => l_return_status,
                                                          x_msg_count     => l_msg_count,
                                                          x_msg_data      => l_msg_data,
                                                          p_cimv_tbl      => l_cimv_tbl_in,
                                                          x_cimv_tbl      => l_cimv_tbl_out);
            
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
            
               ---------------------------------- Create OKS Sub Line ------------------------------------
               populate_oks_line(x_oks_line_tbl_out => l_klnv_tbl_in);
            
               l_klnv_tbl_in(1).cle_id := l_sub_cle_id; --l_cle_id;
               l_klnv_tbl_in(1).dnz_chr_id := l_chrid;
               l_klnv_tbl_in(1).sfwt_flag := 'N';
               l_klnv_tbl_in(1).invoice_text := l_invoice_text;
               l_klnv_tbl_in(1).created_by := l_user_id;
               l_klnv_tbl_in(1).creation_date := SYSDATE;
               l_klnv_tbl_in(1).last_updated_by := l_user_id;
               l_klnv_tbl_in(1).last_update_date := SYSDATE;
               l_klnv_tbl_in(1).last_update_login := -1;
               l_klnv_tbl_in(1).tax_amount := cur_line.tax;
               l_klnv_tbl_in(1).tax_inclusive_yn := 'Y';
               l_klnv_tbl_in(1).inv_print_flag := 'Y';
               l_klnv_tbl_in(1).price_uom := 'YR';
               l_klnv_tbl_in(1).clvl_list_price := l_line_price_list_id;
            
               fnd_msg_pub.initialize;
               oks_contract_line_pub.create_line(p_api_version   => 1.0,
                                                 p_init_msg_list => l_init_msg_list,
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
            
            END LOOP;
         
            COMMIT;
            ---------------------------------- Update Header ------------------------------------
         
            l_chrv_tbl_in(1).id := l_chrid;
            l_chrv_tbl_in(1).cognomen := cur_contract.contract_number;
            l_chrv_tbl_in(1).object_version_number := 1;
            l_chrv_tbl_in(1).approval_type := 'Y';
            okc_contract_pub.update_contract_header(p_api_version       => 1.0,
                                                    p_init_msg_list     => l_init_msg_list,
                                                    x_return_status     => l_return_status,
                                                    x_msg_count         => l_msg_count,
                                                    x_msg_data          => l_msg_data,
                                                    p_restricted_update => 'F',
                                                    p_chrv_tbl          => l_chrv_tbl_in,
                                                    x_chrv_tbl          => l_chrv_tbl_out);
         
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
         
            SELECT id, object_version_number
              INTO l_oks_id, l_object_version_number
              FROM oks_k_headers_b
             WHERE chr_id = l_chrid;
         
            l_khrv_tbl_type_in(1).id := l_oks_id;
            l_khrv_tbl_type_in(1).chr_id := l_chrid;
            l_khrv_tbl_type_in(1).service_po_number := cur_contract.po_number;
            l_khrv_tbl_type_in(1).service_po_required := 'N';
            --    l_khrv_tbl_type_in(1).billing_profile_id := l_billing_profile_id;
            l_khrv_tbl_type_in(1).object_version_number := l_object_version_number;
            l_khrv_tbl_type_in(1).tax_amount := 0;
         
            /*           SELECT SUM(nvl(oks_extwar_util_pvt.round_currency_amt(tax_amount,
                                                                              cur_contract.link_curr),
                                       0))
                          INTO l_khrv_tbl_type_in(1).tax_amount 
                          FROM oks_k_lines_b
                         WHERE dnz_chr_id = l_chrid;
            */
            oks_contract_hdr_pub.update_header(p_api_version   => 1.0,
                                               p_init_msg_list => l_init_msg_list,
                                               x_return_status => l_return_status,
                                               x_msg_count     => l_msg_count,
                                               x_msg_data      => l_msg_data,
                                               p_khrv_tbl      => l_khrv_tbl_type_in,
                                               x_khrv_tbl      => l_khrv_tbl_type_out,
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
         
            oks_auth_util_pvt.check_update_amounts(p_api_version   => 1.0,
                                                   p_init_msg_list => l_init_msg_list,
                                                   p_commit        => fnd_api.g_false,
                                                   p_chr_id        => l_chrid,
                                                   x_msg_count     => l_msg_count,
                                                   x_msg_data      => l_msg_data,
                                                   x_return_status => l_return_status);
         
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
         
            ---------------------------------- Update Status ------------------------------------
         
            UPDATE xxobjt_conv_oks_contracts t
               SET t.return_status = 'S', t.err_message = NULL
             WHERE t.contract_number = cur_contract.contract_number;
         
         EXCEPTION
            WHEN invalid_contract THEN
               ROLLBACK;
               UPDATE xxobjt_conv_oks_contracts t
                  SET t.return_status = 'E', t.err_message = l_err_msg
                WHERE t.contract_number = cur_contract.contract_number;
            
            WHEN OTHERS THEN
               ROLLBACK;
               l_err_msg := SQLERRM;
               UPDATE xxobjt_conv_oks_contracts t
                  SET t.return_status = 'E', t.err_message = l_err_msg
                WHERE t.contract_number = cur_contract.contract_number;
            
         END; -- end block for contract header
         COMMIT;
      
      END LOOP;
   
   END load_contracts;

   /* PROCEDURE insert_update_line_oks IS
         l_api_version   CONSTANT NUMBER := 1.0;
         l_init_msg_list CONSTANT VARCHAR2(1) := utility.get_true;
         l_return_status VARCHAR2(1);
         l_msg_count     NUMBER;
         l_msg_data      VARCHAR2(2000);
         l_klnv_tbl_in   oks_contract_line_pub.klnv_tbl_type;
         l_klnv_tbl_out  oks_contract_line_pub.klnv_tbl_type;
      BEGIN
         populate_oks_line(x_oks_line_tbl_out => l_klnv_tbl_in);
      
         l_klnv_tbl_in(1).id := name_in(p_block || '.kln_id');
         l_klnv_tbl_in(1).object_version_number := name_in(p_block ||
                                                           '.kln_obj_num_latest');
         l_klnv_tbl_in(1).cle_id := name_in(p_block || '.id');
         l_klnv_tbl_in(1).dnz_chr_id := name_in('oks_header.id');
         l_klnv_tbl_in(1).sfwt_flag := 'N';
         l_klnv_tbl_in(1).invoice_text := name_in(p_block || '.invoice_text');
      
         l_klnv_tbl_in(1).created_by := okc_api.g_miss_num;
         l_klnv_tbl_in(1).creation_date := okc_api.g_miss_date;
         l_klnv_tbl_in(1).last_updated_by := okc_api.g_miss_num;
         l_klnv_tbl_in(1).last_update_date := okc_api.g_miss_date;
         l_klnv_tbl_in(1).last_update_login := okc_api.g_miss_num;
      
         IF name_in(p_block || '.lse_id') <> 46 THEN
            l_klnv_tbl_in(1).tax_amount := NULL;
            \*    ELSE 
            l_klnv_tbl_in(1).tax_amount             := NAME_IN(p_block||'.tax_amount'); *\
         END IF;
         l_klnv_tbl_in(1).tax_inclusive_yn := name_in(p_block ||
                                                      '.tax_inclusive_yn');
         l_klnv_tbl_in(1).tax_status := name_in(p_block || '.tax_status');
         l_klnv_tbl_in(1).tax_code := name_in(p_block || '.tax_code');
         --start R12 eBtax
         l_klnv_tbl_in(1).tax_classification_code := name_in(p_block ||
                                                             '.tax_classification_code');
         l_klnv_tbl_in(1).exempt_certificate_number := name_in(p_block ||
                                                               '.tax_exemption_number');
         l_klnv_tbl_in(1).exempt_reason_code := name_in(p_block ||
                                                        '.exempt_reason_code');
         --end R12 eBtax
         l_klnv_tbl_in(1).tax_exemption_id := name_in(p_block ||
                                                      '.tax_exemption_id');
         l_klnv_tbl_in(1).inv_print_flag := name_in(p_block ||
                                                    '.inv_print_flag');
         l_klnv_tbl_in(1).averaging_interval := name_in(p_block ||
                                                        '.averaging_interval');
         l_klnv_tbl_in(1).usage_period := name_in(p_block ||
                                                  '.rate_min_time_uom_code');
         l_klnv_tbl_in(1).settlement_interval := name_in(p_block ||
                                                         '.settlement_interval');
         l_klnv_tbl_in(1).termn_method := name_in(p_block || '.termn_method');
         l_klnv_tbl_in(1).usage_type := name_in(p_block || '.usage_type');
         l_klnv_tbl_in(1).payment_type := name_in(p_block || '.payment_type');
         l_klnv_tbl_in(1).cust_po_number_req_yn := name_in(p_block ||
                                                           '.cust_po_number_req_yn');
         l_klnv_tbl_in(1).cust_po_number := name_in(p_block ||
                                                    '.cust_po_number');
         l_klnv_tbl_in(1).commitment_id := name_in(p_block || '.commitment_id');
         --l_klnv_tbl_in(1).cc_no                  := NAME_IN(p_block||'.cc_no');
         --l_klnv_tbl_in(1).cc_expiry_date         := NAME_IN(p_block||'.cc_expiry_date');
         l_klnv_tbl_in(1).trxn_extension_id := name_in(p_block ||
                                                       '.trxn_extension_ID'); --abkumar cc ext
      
         l_klnv_tbl_in(1).locked_price_list_id := name_in(p_block ||
                                                          '.locked_price_list_id');
         l_klnv_tbl_in(1).break_uom := name_in(p_block || '.break_uom');
         l_klnv_tbl_in(1).locked_price_list_line_id := name_in(p_block ||
                                                               '.locked_price_list_line_id');
      
         l_klnv_tbl_in(1).prorate := name_in(p_block || '.prorate');
         -- Partial Period Computation --
         l_klnv_tbl_in(1).price_uom := name_in(p_block || '.price_uom');
         -- Partial Period Computation -- 
         -- CRA --
         -- GCHADHA --
      
         IF name_in('OKS_LINES.LSE_ID') IN (1, 14, 19) THEN
            
               l_klnv_tbl_in(1).coverage_id := name_in(p_block ||
                                                       '.COVERAGE_ID');
               l_klnv_tbl_in(1).standard_cov_yn := name_in(p_block ||
                                                           '.STANDARD_COV_YN');
   
         END IF;
      
         oks_contract_line_pub.update_line(p_api_version   => l_api_version,
                                           p_init_msg_list => l_init_msg_list,
                                           x_return_status => l_return_status,
                                           x_msg_count     => l_msg_count,
                                           x_msg_data      => l_msg_data,
                                           p_klnv_tbl      => l_klnv_tbl_in,
                                           x_klnv_tbl      => l_klnv_tbl_out,
                                           p_validate_yn   => 'N');
      
         IF l_return_status = 'S' THEN
         
            copy(l_klnv_tbl_out(1).object_version_number,
                 p_block || '.kln_obj_num_latest');
            IF p_operation = 'INSERT' THEN
               copy(l_klnv_tbl_out(1).id, p_block || '.kln_id');
            END IF;
         ELSE
            okc_forms_util.display_errors;
            RAISE form_trigger_failure;
         END IF;
      
      END insert_update_line_oks;
   
      PROCEDURE coverage(event IN VARCHAR2) IS
         -- Coverage Rearchitecture --
         -- CRA--
         l_post          BOOLEAN;
         l_function_type VARCHAR2(100);
         l_form_path     VARCHAR2(100);
         l_arguments     VARCHAR2(100);
         l_api_version   CONSTANT NUMBER := 1.0;
         l_init_msg_list CONSTANT VARCHAR2(1) := utility.get_true;
         l_return_status VARCHAR2(1);
         l_msg_count     NUMBER;
         l_msg_data      VARCHAR2(2000);
         l_msg_index_out NUMBER;
      
         -- Cursor to get the standard Coverage id attached to the given Item 
         -- taken at the lines level. 
         CURSOR cur_system_items(p_cle_id IN NUMBER) IS
            SELECT b.coverage_schedule_id coverage_template_id
              FROM mtl_system_items_b_kfv b, mtl_system_items_tl t
             WHERE b.inventory_item_id = t.inventory_item_id AND
                   b.organization_id = t.organization_id AND
                   t.LANGUAGE = userenv('LANG') AND
                   b.organization_id = okc_context.get_okc_organization_id AND
                   b.inventory_item_id =
                   (SELECT object1_id1
                      FROM okc_k_items_v
                     WHERE cle_id = p_cle_id);
      
         l_template_id oks_k_lines_v.id%TYPE;
      
         CURSOR std_cov_csr(p_cov_id NUMBER) IS
            SELECT NAME, item_description
              FROM okc_k_lines_v
             WHERE id = p_cov_id;
      
         std_cov_rec std_cov_csr%ROWTYPE;
         -- CRA -- 
      BEGIN
      
         -- IF nvl(name_in('OKS_LINES.STANDARD_COV_YN'), 'N') = 'Y' THEN
         --    fnd_message.set_name('OKS', 'OKS_STANDARD_COV');
         --    fnd_message.error;
         --    RAISE form_trigger_failure;
         -- ELSE
      
         --End fixes of bug#4624864
         oks_coverages_pub.delete_coverage(p_api_version     => l_api_version,
                                           p_init_msg_list   => l_init_msg_list,
                                           x_return_status   => l_return_status,
                                           x_msg_count       => l_msg_count,
                                           x_msg_data        => l_msg_data,
                                           p_service_line_id => name_in('OKS_LINES.ID'));
         -- CRA -- 
      
         IF nvl(l_return_status, 'N') <> 'S' THEN
            okc_forms_util.display_errors;
            RAISE form_trigger_failure;
         END IF;
      
         OPEN cur_system_items(name_in('OKS_LINES.ID'));
         FETCH cur_system_items
            INTO l_template_id;
         CLOSE cur_system_items;
      
         copy('Y', 'OKS_LINES.STANDARD_COV_YN');
         copy(l_template_id, 'OKS_LINES.COVERAGE_ID');
         -- CRA--
         -- 7/25/2005 -- 
         copy(name_in('OKS_LINES.COVERAGE_ID'), 'PARAMETER.COVERAGE_ID');
         --start fixes of bug#4645365
         OPEN std_cov_csr(name_in('OKS_LINES.COVERAGE_ID'));
         FETCH std_cov_csr
            INTO std_cov_rec;
         CLOSE std_cov_csr;
      
         copy(std_cov_rec.NAME, 'oks_lines.std_coverage_name');
         copy(std_cov_rec.item_description, 'oks_lines.std_coverage_desc');
         --end fixes of bug#4645365
         -- CRA -- 
         line_util.insert_update_line_oks('OKS_LINES', 'UPDATE');
         --Set the Reapply Standard Button Disable --
      
      END coverage;
   */

   PROCEDURE fix_inv_organization IS
   
      CURSOR csr_all_contracts IS
         SELECT h.id,
                l.id line_id,
                s.id service_line_id,
                i.id item_line_id,
                i.object1_id1 item_id,
                i.object1_id2 organization_id,
                h.inv_organization_id,
                h.org_id
           FROM okc_k_headers_all_b h,
                okc_k_party_roles_b hp,
                hz_cust_accounts    hca,
                okc_k_lines_b       l,
                oks_k_lines_b       s,
                okc_k_items         i
          WHERE h.id = l.chr_id AND
                h.id = s.dnz_chr_id AND
                hp.dnz_chr_id = h.id AND
                hp.object1_id1 = hca.party_id AND
                s.cle_id = l.id AND
                hp.rle_code = 'CUSTOMER' AND
                i.cle_id = l.id AND
                l.lse_id IN (1, 14);
   
      cur_contract   csr_all_contracts%ROWTYPE;
      l_klnv_tbl_in  oks_contract_line_pub.klnv_tbl_type;
      l_klnv_tbl_out oks_contract_line_pub.klnv_tbl_type;
      t_ac_rec_type  oks_coverages_pub.ac_rec_type;
      l_clev_tbl_in  okc_contract_pub.clev_tbl_type;
      l_clev_tbl_out okc_contract_pub.clev_tbl_type;
      l_cimv_tbl_in  okc_contract_item_pub.cimv_tbl_type;
      l_cimv_tbl_out okc_contract_item_pub.cimv_tbl_type;
   
      l_return_status        VARCHAR2(1);
      l_msg_count            NUMBER;
      l_msg_index_out        NUMBER;
      l_msg_data             VARCHAR2(500);
      l_coverage_template_id NUMBER;
      l_err_msg              VARCHAR2(500);
      l_user_id              NUMBER;
      l_prog_maint_id        NUMBER;
      l_actual_coverage_id   NUMBER;
      l_counter              NUMBER;
      invalid_contract EXCEPTION;
   
   BEGIN
   
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
   
      FOR cur_contract IN csr_all_contracts LOOP
      
         IF cur_contract.org_id = 81 THEN
            fnd_global.apps_initialize(user_id      => l_user_id,
                                       resp_id      => 50571,
                                       resp_appl_id => 515);
         
         ELSIF cur_contract.org_id = 89 THEN
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
         
            l_err_msg       := NULL;
            l_return_status := fnd_api.g_ret_sts_success;
         
            ---------------------------------- Create Item Line ------------------------------------
         
            --  OKC_CONTEXT.Get_Okc_Organization_Id
            l_cimv_tbl_in(1).id := cur_contract.item_line_id;
            -- l_cimv_tbl_in(1).chr_id := NULL;
            -- l_cimv_tbl_in(1).cle_id := cur_contract.line_id;
            l_cimv_tbl_in(1).dnz_chr_id := cur_contract.id;
            l_cimv_tbl_in(1).object1_id1 := cur_contract.item_id;
            l_cimv_tbl_in(1).object1_id2 := cur_contract.inv_organization_id;
            l_cimv_tbl_in(1).jtot_object1_code := 'OKX_SERVICE';
            --  l_cimv_tbl_in(1).number_of_items := 1; --name_in(p_block ||'.SUBS_QTY');
            --  l_cimv_tbl_in(1).uom_code := l_item_uom; --name_in(p_block ||'.SUBS_UOM_CODE');           
            --  l_cimv_tbl_in(1).priced_item_yn := 'Y';
            --  l_cimv_tbl_in(1).exception_yn := 'N';
            --  l_cimv_tbl_in(1).created_by := l_user_id;
            --  l_cimv_tbl_in(1).creation_date := SYSDATE;
            l_cimv_tbl_in(1).last_updated_by := l_user_id;
            l_cimv_tbl_in(1).last_update_date := SYSDATE;
            l_cimv_tbl_in(1).last_update_login := -1;
         
            --l_cimv_tbl_in(1).object_version_number := name_in(p_block ||'.ITEM_object_version_number');
         
            fnd_msg_pub.initialize;
            okc_contract_item_pub.update_contract_item(p_api_version   => 1.0,
                                                       p_init_msg_list => 'T',
                                                       x_return_status => l_return_status,
                                                       x_msg_count     => l_msg_count,
                                                       x_msg_data      => l_msg_data,
                                                       p_cimv_tbl      => l_cimv_tbl_in,
                                                       x_cimv_tbl      => l_cimv_tbl_out);
         
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
               ROLLBACK;
            WHEN OTHERS THEN
               l_err_msg := SQLERRM;
               ROLLBACK;
         END;
      
         INSERT INTO xxobjt_conv_oks_contract_fix
         VALUES
            (cur_contract.id,
             cur_contract.line_id,
             cur_contract.service_line_id,
             cur_contract.item_id,
             cur_contract.inv_organization_id,
             NULL,
             l_return_status,
             l_err_msg,
             SYSDATE,
             'FIX_INV_ORGANIZATION');
      
         COMMIT;
      
      END LOOP;
   END fix_inv_organization;

   PROCEDURE restore_coverage IS
   
      CURSOR csr_all_contracts IS
         SELECT h.id,
                l.id line_id,
                s.id service_line_id,
                s.coverage_id,
                coverage_schedule_id cov_template_id,
                i.object1_id1 item_id,
                i.object1_id2 organization_id,
                l.start_date,
                l.end_date,
                hca.attribute2 cs_price_list_id,
                hca.attribute3 cs_price_list_heads_id,
                h.org_id,
                s.standard_cov_yn
           FROM okc_k_headers_all_b h,
                okc_k_party_roles_b hp,
                hz_cust_accounts    hca,
                okc_k_lines_b       l,
                oks_k_lines_b       s,
                okc_k_items         i,
                mtl_system_items_b  msi
          WHERE h.id = l.chr_id AND
                h.id = s.dnz_chr_id AND
                hp.dnz_chr_id = h.id AND
                hp.object1_id1 = hca.party_id AND
                s.cle_id = l.id AND
                hp.rle_code = 'CUSTOMER' AND
                i.cle_id = l.id AND
                l.lse_id IN (1, 14) AND
                i.object1_id1 = msi.inventory_item_id AND
                h.inv_organization_id = msi.organization_id AND
                msi.coverage_schedule_id != s.coverage_id AND
                h.id = 14087;
   
      CURSOR csr_coverage_lines(p_cle_id NUMBER) IS
         SELECT cleb.id id,
                cleb.object_version_number object_version_number,
                cleb.cle_id coverage_cle_id,
                cleb.lse_id lse_id,
                cleb.line_number line_number,
                cleb.dnz_chr_id dnz_chr_id,
                cleb.price_list_id,
                cleb.start_date,
                cleb.end_date,
                buspr.NAME process_name
           FROM okc_k_lines_b       cleb,
                okc_k_items         citem,
                okx_bus_processes_v buspr,
                jtf_objects_b       jtfob
          WHERE jtfob.object_code = 'OKX_BUSIPROC' AND
                cleb.lse_id IN (3, 16, 21) AND
                citem.cle_id = cleb.id AND
                citem.jtot_object1_code = jtfob.object_code AND
                buspr.id1 = citem.object1_id1 AND
                buspr.id2 = citem.object1_id2 AND
                cleb.cle_id = p_cle_id;
   
      cur_contract      csr_all_contracts%ROWTYPE;
      cur_service_line  oks_k_lines_b%ROWTYPE;
      cur_coverage_line csr_coverage_lines%ROWTYPE;
      l_klnv_tbl_in     oks_contract_line_pub.klnv_tbl_type;
      l_klnv_tbl_out    oks_contract_line_pub.klnv_tbl_type;
      t_ac_rec          xxoks_coverages_pvt.ac_rec_type;
      l_clev_tbl_in     okc_contract_pub.clev_tbl_type;
      l_clev_tbl_out    okc_contract_pub.clev_tbl_type;
   
      l_return_status        VARCHAR2(1);
      l_msg_count            NUMBER;
      l_msg_index_out        NUMBER;
      l_msg_data             VARCHAR2(1000);
      l_coverage_template_id NUMBER;
      l_err_msg              VARCHAR2(1000);
      l_user_id              NUMBER;
      l_prog_maint_id        NUMBER;
      l_actual_coverage_id   NUMBER;
      l_counter              NUMBER;
      invalid_contract EXCEPTION;
   
   BEGIN
   
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
   
      FOR cur_contract IN csr_all_contracts LOOP
      
         IF cur_contract.org_id = 81 THEN
            fnd_global.apps_initialize(user_id      => l_user_id,
                                       resp_id      => 50571,
                                       resp_appl_id => 515);
         
         ELSIF cur_contract.org_id = 89 THEN
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
         
            l_err_msg       := NULL;
            l_return_status := fnd_api.g_ret_sts_success;
         
            IF cur_contract.cs_price_list_id IS NULL OR
               cur_contract.cs_price_list_heads_id IS NULL THEN
               l_err_msg := 'List price definition is missing';
               RAISE invalid_contract;
            END IF;
         
            xxoks_coverages_pvt.delete_coverage(p_api_version     => 1.0,
                                                p_init_msg_list   => 'T',
                                                x_return_status   => l_return_status,
                                                x_msg_count       => l_msg_count,
                                                x_msg_data        => l_msg_data,
                                                p_service_line_id => cur_contract.line_id);
         
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
         
            COMMIT;
         
            populate_oks_line(l_klnv_tbl_in);
         
            SELECT *
              INTO cur_service_line
              FROM oks_k_lines_b
             WHERE id = cur_contract.service_line_id;
         
            BEGIN
               SELECT b.coverage_schedule_id
                 INTO l_coverage_template_id
                 FROM mtl_system_items_b b
                WHERE b.inventory_item_id = cur_contract.item_id AND
                      b.organization_id = cur_contract.organization_id;
            
            EXCEPTION
               WHEN OTHERS THEN
                  l_err_msg := 'Inalid covered level';
                  RAISE invalid_contract;
            END;
         
            ---------------------------------- Create Actual Coverage Content ------------------------------------
            --     IF cur_contract.cs_price_list_id IS NOT NULL AND
            --        cur_contract.cs_price_list_heads_id IS NOT NULL THEN
         
            l_actual_coverage_id := cur_contract.coverage_id;
         
            t_ac_rec.svc_cle_id := cur_contract.line_id; --cur_contract.service_line_id; --  
            t_ac_rec.tmp_cle_id := cur_contract.cov_template_id;
            t_ac_rec.start_date := cur_contract.start_date;
            t_ac_rec.end_date   := cur_contract.end_date;
            t_ac_rec.rle_code   := 'VENDOR';
         
            xxoks_coverages_pvt.create_actual_coverage(p_api_version        => 1.0,
                                                       p_init_msg_list      => fnd_api.g_true,
                                                       x_return_status      => l_return_status,
                                                       x_msg_count          => l_msg_count,
                                                       x_msg_data           => l_msg_data,
                                                       p_ac_rec_in          => t_ac_rec,
                                                       p_restricted_update  => 'F',
                                                       x_actual_coverage_id => l_actual_coverage_id);
         
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
         
            COMMIT;
         
            -- ELSE
         
            --    l_actual_coverage_id := l_coverage_template_id;
         
            --  END IF;
         
            ---------------------------------- Update OKS Line ------------------------------------
         
            SELECT id1
              INTO l_prog_maint_id
              FROM okx_pm_programs_v
             WHERE mr_status_code = 'COMPLETE';
         
            l_klnv_tbl_in(1).id := cur_service_line.id;
            l_klnv_tbl_in(1).cle_id := cur_service_line.cle_id;
            l_klnv_tbl_in(1).dnz_chr_id := cur_service_line.dnz_chr_id;
            --l_klnv_tbl_in(1).sfwt_flag := cur_service_line.sfwt_flag;
            /*            -- l_klnv_tbl_in(1).invoice_text := cur_service_line.invoice_text;
                        l_klnv_tbl_in(1).last_updated_by := l_user_id;
                        l_klnv_tbl_in(1).last_update_date := SYSDATE;
                        l_klnv_tbl_in(1).last_update_login := -1;
                        l_klnv_tbl_in(1).tax_amount := cur_service_line.tax_amount;
                        l_klnv_tbl_in(1).tax_inclusive_yn := cur_service_line.tax_inclusive_yn;
                        l_klnv_tbl_in(1).tax_status := cur_service_line.tax_status;
                        l_klnv_tbl_in(1).tax_code := cur_service_line.tax_code;
                        l_klnv_tbl_in(1).tax_classification_code := cur_service_line.tax_classification_code;
                        -- l_klnv_tbl_in(1).exempt_certificate_number := cur_service_line.tax_exemption_number;
                        l_klnv_tbl_in(1).exempt_reason_code := cur_service_line.exempt_reason_code;
                        l_klnv_tbl_in(1).tax_exemption_id := cur_service_line.tax_exemption_id;
                        l_klnv_tbl_in(1).inv_print_flag := cur_service_line.inv_print_flag;
                        l_klnv_tbl_in(1).averaging_interval := cur_service_line.averaging_interval;
                        -- l_klnv_tbl_in(1).usage_period := cur_service_line.rate_min_time_uom_code;
                        l_klnv_tbl_in(1).settlement_interval := cur_service_line.settlement_interval;
                        l_klnv_tbl_in(1).termn_method := cur_service_line.termn_method;
                        l_klnv_tbl_in(1).usage_type := cur_service_line.usage_type;
                        l_klnv_tbl_in(1).payment_type := cur_service_line.payment_type;
                        l_klnv_tbl_in(1).cust_po_number_req_yn := cur_service_line.cust_po_number_req_yn;
                        l_klnv_tbl_in(1).cust_po_number := cur_service_line.cust_po_number;
                        l_klnv_tbl_in(1).commitment_id := cur_service_line.commitment_id;
                        l_klnv_tbl_in(1).trxn_extension_id := cur_service_line.trxn_extension_id; --abkumar cc ext           
                        l_klnv_tbl_in(1).locked_price_list_id := cur_service_line.locked_price_list_id;
                        l_klnv_tbl_in(1).break_uom := cur_service_line.break_uom;
                        l_klnv_tbl_in(1).locked_price_list_line_id := cur_service_line.locked_price_list_line_id;
                        l_klnv_tbl_in(1).prorate := cur_service_line.prorate;
                        l_klnv_tbl_in(1).price_uom := cur_service_line.price_uom;
            */
            l_klnv_tbl_in(1).coverage_id := l_actual_coverage_id; --l_coverage_template_id;
            l_klnv_tbl_in(1).pm_program_id := l_prog_maint_id;
            l_klnv_tbl_in(1).clvl_list_price := cur_service_line.clvl_list_price;
            l_klnv_tbl_in(1).standard_cov_yn := 'N';
            l_klnv_tbl_in(1).object_version_number := cur_service_line.object_version_number;
            -- CRA --
            -- GCHADHA --
            fnd_msg_pub.initialize;
            oks_contract_line_pub.update_line(p_api_version   => 1.0,
                                              p_init_msg_list => 'T',
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
         
            ----------------------------- Update Coverage line for price list -------------------------
            populate_okc_line(l_clev_tbl_in);
            l_counter := 0;
            FOR cur_coverage_line IN csr_coverage_lines(l_actual_coverage_id) LOOP
            
               l_counter := l_counter + 1;
               l_clev_tbl_in(l_counter).id := cur_coverage_line.id;
               l_clev_tbl_in(l_counter).dnz_chr_id := cur_coverage_line.dnz_chr_id;
               l_clev_tbl_in(l_counter).cle_id := cur_coverage_line.coverage_cle_id;
               IF cur_coverage_line.process_name = 'Replace Heads' THEN
                  l_clev_tbl_in(l_counter).price_list_id := cur_contract.cs_price_list_heads_id;
               ELSE
                  l_clev_tbl_in(l_counter).price_list_id := cur_contract.cs_price_list_id;
               END IF;
               l_clev_tbl_in(l_counter).start_date := cur_coverage_line.start_date;
               l_clev_tbl_in(l_counter).end_date := cur_coverage_line.end_date;
               l_clev_tbl_in(l_counter).object_version_number := cur_coverage_line.object_version_number;
            
            END LOOP;
         
            okc_contract_pub.update_contract_line(p_api_version       => 1.0,
                                                  p_init_msg_list     => 'T',
                                                  x_return_status     => l_return_status,
                                                  x_msg_count         => l_msg_count,
                                                  x_msg_data          => l_msg_data,
                                                  p_restricted_update => 'T',
                                                  p_clev_tbl          => l_clev_tbl_in,
                                                  x_clev_tbl          => l_clev_tbl_out);
         
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
         
            BEGIN
               SELECT 'Y'
                 INTO l_return_status
                 FROM oks_pm_activities_v
                WHERE cle_id = cur_contract.line_id;
            
            EXCEPTION
               WHEN no_data_found THEN
               
                  oks_pm_programs_pvt.create_pm_program_schedule(p_api_version     => 1.0,
                                                                 p_init_msg_list   => 'T',
                                                                 x_return_status   => l_return_status,
                                                                 x_msg_count       => l_msg_count,
                                                                 x_msg_data        => l_msg_data,
                                                                 p_template_cle_id => cur_contract.cov_template_id,
                                                                 p_cle_id          => cur_contract.line_id,
                                                                 p_cov_start_date  => cur_contract.start_date,
                                                                 p_cov_end_date    => cur_contract.end_date);
               
            END;
         
         EXCEPTION
            WHEN invalid_contract THEN
               ROLLBACK;
            WHEN OTHERS THEN
               l_err_msg := SQLERRM;
               ROLLBACK;
         END;
      
         INSERT INTO xxobjt_conv_oks_contract_fix
         VALUES
            (cur_contract.id,
             cur_contract.line_id,
             cur_contract.service_line_id,
             cur_contract.item_id,
             cur_contract.cs_price_list_id,
             cur_contract.cs_price_list_heads_id,
             l_return_status,
             l_err_msg,
             SYSDATE,
             'RESTORE_COVERAGE');
      
         COMMIT;
      
      END LOOP;
   
   END restore_coverage;

   PROCEDURE apply_standard IS
   
      CURSOR csr_all_contracts IS
         SELECT h.id,
                l.id line_id,
                s.id service_line_id,
                s.coverage_id,
                msi.coverage_schedule_id cov_template_id,
                i.object1_id1 item_id,
                i.object1_id2 organization_id,
                l.start_date,
                l.end_date,
                h.org_id,
                s.standard_cov_yn,
                s.object_version_number
           FROM okc_k_headers_all_b h,
                okc_k_lines_b       l,
                oks_k_lines_b       s,
                okc_k_items         i,
                mtl_system_items_b  msi
          WHERE h.id = l.chr_id AND
                h.id = s.dnz_chr_id AND
                h.scs_code = 'SERVICE' AND
                h.sts_code NOT IN ('CANCELLED') AND
                s.cle_id = l.id AND
                i.cle_id = l.id AND
                l.lse_id = 1 AND
                nvl(l.attribute1, 'Y') = 'Y' AND
                i.object1_id1 = msi.inventory_item_id AND
                h.inv_organization_id = msi.organization_id AND
                msi.coverage_schedule_id != s.coverage_id;
   
      cur_contract   csr_all_contracts%ROWTYPE;
      l_klnv_tbl_in  oks_contract_line_pub.klnv_tbl_type;
      l_klnv_tbl_out oks_contract_line_pub.klnv_tbl_type;
      l_clev_tbl_in  okc_contract_pub.clev_tbl_type;
      l_clev_tbl_out okc_contract_pub.clev_tbl_type;
   
      l_return_status        VARCHAR2(1);
      l_msg_count            NUMBER;
      l_msg_index_out        NUMBER;
      l_msg_data             VARCHAR2(1000);
      l_coverage_template_id NUMBER;
      l_err_msg              VARCHAR2(1000);
      l_user_id              NUMBER;
      l_prog_maint_id        NUMBER;
      l_actual_coverage_id   NUMBER;
      l_counter              NUMBER;
      invalid_contract EXCEPTION;
   
   BEGIN
   
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
   
      FOR cur_contract IN csr_all_contracts LOOP
      
         l_err_msg       := NULL;
         l_return_status := 'S';
      
         IF cur_contract.org_id = 81 THEN
            fnd_global.apps_initialize(user_id      => l_user_id,
                                       resp_id      => 50571,
                                       resp_appl_id => 515);
         
         ELSIF cur_contract.org_id = 89 THEN
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
         
            populate_oks_line(l_klnv_tbl_in);
         
            l_klnv_tbl_in(1).id := cur_contract.service_line_id;
            l_klnv_tbl_in(1).cle_id := cur_contract.line_id;
            l_klnv_tbl_in(1).dnz_chr_id := cur_contract.id;
            l_klnv_tbl_in(1).last_updated_by := l_user_id;
            l_klnv_tbl_in(1).last_update_date := SYSDATE;
            l_klnv_tbl_in(1).object_version_number := cur_contract.object_version_number;
            l_klnv_tbl_in(1).coverage_id := cur_contract.cov_template_id; --l_coverage_template_id; -- 
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
               ROLLBACK;
            WHEN OTHERS THEN
               l_err_msg := SQLERRM;
               ROLLBACK;
         END;
      
         INSERT INTO xxobjt_conv_oks_contract_fix
         VALUES
            (cur_contract.id,
             cur_contract.line_id,
             cur_contract.service_line_id,
             cur_contract.item_id,
             NULL,
             NULL,
             l_return_status,
             l_err_msg,
             SYSDATE,
             'APPLY_STANDARD');
      
         COMMIT;
      
      END LOOP;
   
   END apply_standard;

END xxconv_oks_contracts_pkg;
/

