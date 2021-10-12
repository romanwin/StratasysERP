CREATE OR REPLACE PACKAGE BODY xxoks_coverages_pvt AS
--------------------------------------------------------------------
--  name:            xxoks_coverages_pvt
--  create by:       XXXX
--  Revision:        1.0 
--  creation date:   XX/XX/20XX 
--------------------------------------------------------------------
--  purpose : $Header: OKSRMCVB.pls 120.18.12000000.2 2007/03/26 21:21:50 hmnair ship $                      
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  XX/XX/20XX  XXXX              initial build
--  1.0  04/12/2011  Dalit A. Raviv    add procedure apply_standard, populate_oks_line
-------------------------------------------------------------------- 
  ---------------------------------------------------------------------------
  -- PROCEDURE Validate_svc_line_id
  ---------------------------------------------------------------------------

  l_debug VARCHAR2(1) := nvl(fnd_profile.VALUE('AFLOG_ENABLED'), 'N');
  
  ---------------------------------------------------------------------------
  -- PROCEDURE validate_svc_cle_id
  ---------------------------------------------------------------------------
  PROCEDURE validate_svc_cle_id(p_ac_rec        IN ac_rec_type,
                               x_return_status OUT NOCOPY VARCHAR2) IS
    l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
  BEGIN
    IF p_ac_rec.svc_cle_id = okc_api.g_miss_num OR
       p_ac_rec.svc_cle_id IS NULL THEN
       okc_api.set_message(g_app_name,
                           g_required_value,
                           g_col_name_token,
                           'Svc_Cle_id');
        
       l_return_status := okc_api.g_ret_sts_error;
    END IF;
    x_return_status := l_return_status;
  EXCEPTION
    WHEN OTHERS THEN
       -- store SQL error message on message stack for caller
       okc_api.set_message(g_app_name,
                           g_unexpected_error,
                           g_sqlcode_token,
                           SQLCODE,
                           g_sqlerrm_token,
                           SQLERRM);
       -- notify caller of an UNEXPECTED error
       x_return_status := okc_api.g_ret_sts_unexp_error;
  END validate_svc_cle_id;

  ---------------------------------------------------------------------------
  -- PROCEDURE Validate_Line_id
  ---------------------------------------------------------------------------
  PROCEDURE validate_line_id(p_line_id       IN NUMBER,
                            x_return_status OUT NOCOPY VARCHAR2) IS
    l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
    l_count         NUMBER;
    CURSOR cur_line(p_line_id IN NUMBER) IS
       SELECT COUNT(*) FROM okc_k_lines_v WHERE id = p_line_id;
  BEGIN
    IF p_line_id = okc_api.g_miss_num OR p_line_id IS NULL THEN
       okc_api.set_message(g_app_name,
                           g_required_value,
                           g_col_name_token,
                           'P_Line_Id');
        
       l_return_status := okc_api.g_ret_sts_error;
    END IF;
     
    OPEN cur_line(p_line_id);
    FETCH cur_line
       INTO l_count;
    CLOSE cur_line;
    IF NOT l_count = 1 THEN
       okc_api.set_message(g_app_name,
                           g_invalid_value,
                           g_col_name_token,
                           'P_Line_Id');
        
       l_return_status := okc_api.g_ret_sts_error;
    END IF;
    x_return_status := l_return_status;
  EXCEPTION
    WHEN OTHERS THEN
       -- store SQL error message on message stack for caller
       okc_api.set_message(g_app_name,
                           g_unexpected_error,
                           g_sqlcode_token,
                           SQLCODE,
                           g_sqlerrm_token,
                           SQLERRM);
       -- notify caller of an UNEXPECTED error
       x_return_status := okc_api.g_ret_sts_unexp_error;
  END validate_line_id;
  
  ---------------------------------------------------------------------------
  -- PROCEDURE validate_svc_cle_id
  ---------------------------------------------------------------------------
  PROCEDURE validate_tmp_cle_id(p_ac_rec        IN ac_rec_type,
                               x_template_yn   OUT NOCOPY VARCHAR2,
                               x_return_status OUT NOCOPY VARCHAR2) IS
     
    CURSOR check_cov_tmpl(p_cov_id IN NUMBER) IS
       SELECT COUNT(*)
         FROM okc_k_lines_b
        WHERE id = p_cov_id AND
              lse_id IN (2, 15, 20) AND
              dnz_chr_id < 0;
     
    l_count         NUMBER := 0;
    l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
  BEGIN
    IF p_ac_rec.tmp_cle_id = okc_api.g_miss_num OR
       p_ac_rec.tmp_cle_id IS NULL THEN
       okc_api.set_message(g_app_name,
                           g_required_value,
                           g_col_name_token,
                           'Tmp_cle_Id');
        
       l_return_status := okc_api.g_ret_sts_error;
    END IF;
     
    OPEN check_cov_tmpl(p_ac_rec.tmp_cle_id);
    FETCH check_cov_tmpl
       INTO l_count;
    CLOSE check_cov_tmpl;
    IF l_count > 0 THEN
       x_template_yn := 'Y';
    ELSE
       x_template_yn := 'N';
    END IF;
    x_return_status := l_return_status;
  EXCEPTION
    WHEN OTHERS THEN
       -- store SQL error message on message stack for caller
       okc_api.set_message(g_app_name,
                           g_unexpected_error,
                           g_sqlcode_token,
                           SQLCODE,
                           g_sqlerrm_token,
                           SQLERRM);
       -- notify caller of an UNEXPECTED error
       x_return_status := okc_api.g_ret_sts_unexp_error;
  END validate_tmp_cle_id;

  ---------------------------------------------------------------------------
  -- PROCEDURE init_clev
  ---------------------------------------------------------------------------
  PROCEDURE init_clev(p_clev_tbl_in_out IN OUT NOCOPY okc_contract_pub.clev_tbl_type) IS
     
  BEGIN
    IF NOT p_clev_tbl_in_out.COUNT = 0 THEN
       FOR v_index IN p_clev_tbl_in_out.FIRST .. p_clev_tbl_in_out.LAST LOOP
          p_clev_tbl_in_out(v_index).line_number := NULL;
          p_clev_tbl_in_out(v_index).chr_id := NULL;
          p_clev_tbl_in_out(v_index).cle_id := NULL;
          p_clev_tbl_in_out(v_index).lse_id := NULL;
          p_clev_tbl_in_out(v_index).display_sequence := NULL;
          p_clev_tbl_in_out(v_index).sts_code := NULL;
          p_clev_tbl_in_out(v_index).trn_code := NULL;
          p_clev_tbl_in_out(v_index).dnz_chr_id := NULL;
          p_clev_tbl_in_out(v_index).exception_yn := NULL;
          p_clev_tbl_in_out(v_index).object_version_number := NULL;
          p_clev_tbl_in_out(v_index).created_by := NULL;
          p_clev_tbl_in_out(v_index).creation_date := NULL;
          p_clev_tbl_in_out(v_index).last_updated_by := NULL;
          p_clev_tbl_in_out(v_index).last_update_date := NULL;
          p_clev_tbl_in_out(v_index).hidden_ind := NULL;
          p_clev_tbl_in_out(v_index).price_negotiated := NULL;
          p_clev_tbl_in_out(v_index).price_level_ind := NULL;
          p_clev_tbl_in_out(v_index).invoice_line_level_ind := NULL;
          p_clev_tbl_in_out(v_index).dpas_rating := NULL;
          p_clev_tbl_in_out(v_index).template_used := 'Y';
          p_clev_tbl_in_out(v_index).price_type := NULL;
          p_clev_tbl_in_out(v_index).currency_code := NULL;
          p_clev_tbl_in_out(v_index).last_update_login := NULL;
          p_clev_tbl_in_out(v_index).date_terminated := NULL;
          p_clev_tbl_in_out(v_index).start_date := NULL;
          p_clev_tbl_in_out(v_index).end_date := NULL;
          p_clev_tbl_in_out(v_index).attribute_category := NULL;
          p_clev_tbl_in_out(v_index).attribute1 := NULL;
          p_clev_tbl_in_out(v_index).attribute2 := NULL;
          p_clev_tbl_in_out(v_index).attribute3 := NULL;
          p_clev_tbl_in_out(v_index).attribute4 := NULL;
          p_clev_tbl_in_out(v_index).attribute5 := NULL;
          p_clev_tbl_in_out(v_index).attribute6 := NULL;
          p_clev_tbl_in_out(v_index).attribute7 := NULL;
          p_clev_tbl_in_out(v_index).attribute8 := NULL;
          p_clev_tbl_in_out(v_index).attribute9 := NULL;
          p_clev_tbl_in_out(v_index).attribute10 := NULL;
          p_clev_tbl_in_out(v_index).attribute11 := NULL;
          p_clev_tbl_in_out(v_index).attribute12 := NULL;
          p_clev_tbl_in_out(v_index).attribute13 := NULL;
          p_clev_tbl_in_out(v_index).attribute14 := NULL;
          p_clev_tbl_in_out(v_index).attribute15 := NULL;
       END LOOP;
    END IF;
  END init_clev;
  
  ---------------------------------------------------------------------------
  -- PROCEDURE init_rgpv
  ---------------------------------------------------------------------------
  PROCEDURE init_rgpv(p_rgpv_tbl_in_out IN OUT NOCOPY okc_rule_pub.rgpv_tbl_type) IS
     
  BEGIN
    IF NOT p_rgpv_tbl_in_out.COUNT = 0 THEN
       FOR v_index IN p_rgpv_tbl_in_out.FIRST .. p_rgpv_tbl_in_out.LAST LOOP
          p_rgpv_tbl_in_out(v_index).id := NULL;
          p_rgpv_tbl_in_out(v_index).rgd_code := NULL;
          p_rgpv_tbl_in_out(v_index).chr_id := NULL;
          p_rgpv_tbl_in_out(v_index).cle_id := NULL;
          p_rgpv_tbl_in_out(v_index).dnz_chr_id := NULL;
          p_rgpv_tbl_in_out(v_index).parent_rgp_id := NULL;
          p_rgpv_tbl_in_out(v_index).object_version_number := NULL;
          p_rgpv_tbl_in_out(v_index).created_by := NULL;
          p_rgpv_tbl_in_out(v_index).creation_date := NULL;
          p_rgpv_tbl_in_out(v_index).last_updated_by := NULL;
          p_rgpv_tbl_in_out(v_index).last_update_date := NULL;
          p_rgpv_tbl_in_out(v_index).last_update_login := NULL;
          p_rgpv_tbl_in_out(v_index).attribute_category := NULL;
          p_rgpv_tbl_in_out(v_index).attribute1 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute2 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute3 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute4 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute5 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute6 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute7 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute8 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute9 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute10 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute11 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute12 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute13 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute14 := NULL;
          p_rgpv_tbl_in_out(v_index).attribute15 := NULL;
          p_rgpv_tbl_in_out(v_index).rgp_type := NULL;
       END LOOP;
    END IF;
  END init_rgpv;
  
  ---------------------------------------------------------------------------
  -- PROCEDURE init_rgpv
  ---------------------------------------------------------------------------   
  PROCEDURE init_rgpv(p_rgpv_rec_in_out IN OUT NOCOPY okc_rule_pub.rgpv_rec_type) IS
     
  BEGIN
    p_rgpv_rec_in_out.id                    := NULL;
    p_rgpv_rec_in_out.rgd_code              := NULL;
    p_rgpv_rec_in_out.chr_id                := NULL;
    p_rgpv_rec_in_out.cle_id                := NULL;
    p_rgpv_rec_in_out.dnz_chr_id            := NULL;
    p_rgpv_rec_in_out.parent_rgp_id         := NULL;
    p_rgpv_rec_in_out.object_version_number := NULL;
    p_rgpv_rec_in_out.created_by            := NULL;
    p_rgpv_rec_in_out.creation_date         := NULL;
    p_rgpv_rec_in_out.last_updated_by       := NULL;
    p_rgpv_rec_in_out.last_update_date      := NULL;
    p_rgpv_rec_in_out.last_update_login     := NULL;
    p_rgpv_rec_in_out.attribute_category    := NULL;
    p_rgpv_rec_in_out.attribute1            := NULL;
    p_rgpv_rec_in_out.attribute2            := NULL;
    p_rgpv_rec_in_out.attribute3            := NULL;
    p_rgpv_rec_in_out.attribute4            := NULL;
    p_rgpv_rec_in_out.attribute5            := NULL;
    p_rgpv_rec_in_out.attribute6            := NULL;
    p_rgpv_rec_in_out.attribute7            := NULL;
    p_rgpv_rec_in_out.attribute8            := NULL;
    p_rgpv_rec_in_out.attribute9            := NULL;
    p_rgpv_rec_in_out.attribute10           := NULL;
    p_rgpv_rec_in_out.attribute11           := NULL;
    p_rgpv_rec_in_out.attribute12           := NULL;
    p_rgpv_rec_in_out.attribute13           := NULL;
    p_rgpv_rec_in_out.attribute14           := NULL;
    p_rgpv_rec_in_out.attribute15           := NULL;
    p_rgpv_rec_in_out.rgp_type              := NULL;
  END init_rgpv;

  ---------------------------------------------------------------------------
  -- PROCEDURE init_rulv
  --------------------------------------------------------------------------- 
  PROCEDURE init_rulv(p_rulv_tbl_in_out IN OUT NOCOPY okc_rule_pub.rulv_tbl_type) IS
     
  BEGIN
    IF NOT p_rulv_tbl_in_out.COUNT = 0 THEN
       FOR v_index IN p_rulv_tbl_in_out.FIRST .. p_rulv_tbl_in_out.LAST LOOP
          p_rulv_tbl_in_out(v_index).id := NULL;
          p_rulv_tbl_in_out(v_index).rgp_id := NULL;
          p_rulv_tbl_in_out(v_index).object1_id1 := NULL;
          p_rulv_tbl_in_out(v_index).object2_id1 := NULL;
          p_rulv_tbl_in_out(v_index).object3_id1 := NULL;
          p_rulv_tbl_in_out(v_index).object1_id2 := NULL;
          p_rulv_tbl_in_out(v_index).object2_id2 := NULL;
          p_rulv_tbl_in_out(v_index).object3_id2 := NULL;
          p_rulv_tbl_in_out(v_index).jtot_object1_code := NULL;
          p_rulv_tbl_in_out(v_index).jtot_object2_code := NULL;
          p_rulv_tbl_in_out(v_index).jtot_object3_code := NULL;
          p_rulv_tbl_in_out(v_index).dnz_chr_id := NULL;
          p_rulv_tbl_in_out(v_index).std_template_yn := NULL;
          p_rulv_tbl_in_out(v_index).warn_yn := NULL;
          p_rulv_tbl_in_out(v_index).priority := NULL;
          p_rulv_tbl_in_out(v_index).object_version_number := NULL;
          p_rulv_tbl_in_out(v_index).created_by := NULL;
          p_rulv_tbl_in_out(v_index).creation_date := NULL;
          p_rulv_tbl_in_out(v_index).last_updated_by := NULL;
          p_rulv_tbl_in_out(v_index).last_update_date := NULL;
          p_rulv_tbl_in_out(v_index).last_update_login := NULL;
          p_rulv_tbl_in_out(v_index).attribute_category := NULL;
          p_rulv_tbl_in_out(v_index).attribute1 := NULL;
          p_rulv_tbl_in_out(v_index).attribute2 := NULL;
          p_rulv_tbl_in_out(v_index).attribute3 := NULL;
          p_rulv_tbl_in_out(v_index).attribute4 := NULL;
          p_rulv_tbl_in_out(v_index).attribute5 := NULL;
          p_rulv_tbl_in_out(v_index).attribute6 := NULL;
          p_rulv_tbl_in_out(v_index).attribute7 := NULL;
          p_rulv_tbl_in_out(v_index).attribute8 := NULL;
          p_rulv_tbl_in_out(v_index).attribute9 := NULL;
          p_rulv_tbl_in_out(v_index).attribute10 := NULL;
          p_rulv_tbl_in_out(v_index).attribute11 := NULL;
          p_rulv_tbl_in_out(v_index).attribute12 := NULL;
          p_rulv_tbl_in_out(v_index).attribute13 := NULL;
          p_rulv_tbl_in_out(v_index).attribute14 := NULL;
          p_rulv_tbl_in_out(v_index).attribute15 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information_category := NULL;
          p_rulv_tbl_in_out(v_index).rule_information1 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information2 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information3 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information4 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information5 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information6 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information7 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information8 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information9 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information10 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information11 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information12 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information13 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information14 := NULL;
          p_rulv_tbl_in_out(v_index).rule_information15 := NULL;
       END LOOP;
    END IF;
  END init_rulv;
  
  ---------------------------------------------------------------------------
  -- PROCEDURE init_ctcv
  ---------------------------------------------------------------------------
  PROCEDURE init_ctcv(p_ctcv_tbl_in_out IN OUT NOCOPY okc_contract_party_pub.ctcv_tbl_type) IS
  BEGIN
    IF p_ctcv_tbl_in_out.COUNT > 0 THEN
       FOR v_index IN p_ctcv_tbl_in_out.FIRST .. p_ctcv_tbl_in_out.LAST LOOP
          p_ctcv_tbl_in_out(v_index).id := NULL;
          p_ctcv_tbl_in_out(v_index).object_version_number := NULL;
          p_ctcv_tbl_in_out(v_index).cpl_id := NULL;
          p_ctcv_tbl_in_out(v_index).cro_code := NULL;
          p_ctcv_tbl_in_out(v_index).dnz_chr_id := NULL;
          p_ctcv_tbl_in_out(v_index).contact_sequence := NULL;
          p_ctcv_tbl_in_out(v_index).object1_id1 := NULL;
          p_ctcv_tbl_in_out(v_index).object1_id2 := NULL;
          p_ctcv_tbl_in_out(v_index).jtot_object1_code := NULL;
          --P_CTCV_tbl_In_Out(v_Index).ROLE  := NULL;
          p_ctcv_tbl_in_out(v_index).attribute_category := NULL;
          p_ctcv_tbl_in_out(v_index).attribute1 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute2 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute3 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute4 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute5 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute6 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute7 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute8 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute9 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute10 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute11 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute12 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute13 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute14 := NULL;
          p_ctcv_tbl_in_out(v_index).attribute15 := NULL;
          p_ctcv_tbl_in_out(v_index).created_by := NULL;
          p_ctcv_tbl_in_out(v_index).creation_date := NULL;
          p_ctcv_tbl_in_out(v_index).last_updated_by := NULL;
          p_ctcv_tbl_in_out(v_index).last_update_date := NULL;
          p_ctcv_tbl_in_out(v_index).last_update_login := NULL;
          p_ctcv_tbl_in_out(v_index).start_date := NULL;
          p_ctcv_tbl_in_out(v_index).end_date := NULL;
          p_ctcv_tbl_in_out(v_index).primary_yn := NULL;
          p_ctcv_tbl_in_out(v_index).resource_class := NULL;
          p_ctcv_tbl_in_out(v_index).sales_group_id := NULL;
           
       END LOOP;
    END IF;
  END;

  ---------------------------------------------------------------------------
  -- PROCEDURE init_cimv
  ---------------------------------------------------------------------------
  PROCEDURE init_cimv(p_cimv_tbl_in_out IN OUT NOCOPY okc_contract_item_pub.cimv_tbl_type) IS
     
  BEGIN
    IF p_cimv_tbl_in_out.COUNT > 0 THEN
       FOR v_index IN p_cimv_tbl_in_out.FIRST .. p_cimv_tbl_in_out.LAST LOOP
           
          p_cimv_tbl_in_out(v_index).id := NULL;
          p_cimv_tbl_in_out(v_index).cle_id := NULL;
          p_cimv_tbl_in_out(v_index).chr_id := NULL;
          p_cimv_tbl_in_out(v_index).cle_id_for := NULL;
          p_cimv_tbl_in_out(v_index).dnz_chr_id := NULL;
          p_cimv_tbl_in_out(v_index).object1_id1 := NULL;
          p_cimv_tbl_in_out(v_index).object1_id2 := NULL;
          p_cimv_tbl_in_out(v_index).jtot_object1_code := NULL;
          p_cimv_tbl_in_out(v_index).uom_code := NULL;
          p_cimv_tbl_in_out(v_index).exception_yn := NULL;
          p_cimv_tbl_in_out(v_index).number_of_items := NULL;
          p_cimv_tbl_in_out(v_index).priced_item_yn := NULL;
          p_cimv_tbl_in_out(v_index).object_version_number := NULL;
          p_cimv_tbl_in_out(v_index).created_by := NULL;
          p_cimv_tbl_in_out(v_index).creation_date := NULL;
          p_cimv_tbl_in_out(v_index).last_updated_by := NULL;
          p_cimv_tbl_in_out(v_index).last_update_date := NULL;
          p_cimv_tbl_in_out(v_index).last_update_login := NULL;
          --P_CIMV_tbl_In_Out(v_Index).SECURITY_GROUP_ID := NULL;
          p_cimv_tbl_in_out(v_index).upg_orig_system_ref := NULL;
          p_cimv_tbl_in_out(v_index).upg_orig_system_ref_id := NULL;
          p_cimv_tbl_in_out(v_index).program_application_id := NULL;
          p_cimv_tbl_in_out(v_index).program_id := NULL;
          p_cimv_tbl_in_out(v_index).program_update_date := NULL;
          p_cimv_tbl_in_out(v_index).request_id := NULL;
           
       END LOOP;
    END IF;
  END;
  
  ---------------------------------------------------------------------------
  -- PROCEDURE get_contract_id
  ---------------------------------------------------------------------------
  PROCEDURE get_contract_id(p_clev_rec      IN xxoks_cle_pvt.clev_rec_type,
                           x_chr_id        OUT NOCOPY NUMBER,
                           x_return_status OUT NOCOPY VARCHAR2) IS
    CURSOR l_clev_csr IS
       SELECT dnz_chr_id FROM okc_k_lines_b WHERE id = p_clev_rec.id;
  BEGIN
    -- initialize return status
    x_return_status := okc_api.g_ret_sts_success;
    -- if dnz_chr_id is present, return it
    IF (p_clev_rec.dnz_chr_id IS NOT NULL AND
       p_clev_rec.dnz_chr_id <> okc_api.g_miss_num) THEN
       x_chr_id := p_clev_rec.dnz_chr_id;
    ELSE
       -- else if chr_id is present , return it
       IF (p_clev_rec.chr_id IS NOT NULL AND
          p_clev_rec.chr_id <> okc_api.g_miss_num) THEN
          x_chr_id := p_clev_rec.chr_id;
       ELSE
          -- else get header id from database
          OPEN l_clev_csr;
          FETCH l_clev_csr
             INTO x_chr_id;
          IF (l_clev_csr%NOTFOUND) THEN
             CLOSE l_clev_csr;
             x_return_status := okc_api.g_ret_sts_error;
             RAISE okc_api.g_exception_error;
          END IF;
          CLOSE l_clev_csr;
       END IF;
    END IF;
  EXCEPTION
    WHEN okc_api.g_exception_error THEN
       okc_api.set_message(p_app_name     => g_app_name,
                           p_msg_name     => g_unexpected_error,
                           p_token1       => g_sqlcode_token,
                           p_token1_value => SQLCODE,
                           p_token2       => g_sqlerrm_token,
                           p_token2_value => SQLERRM);
       x_return_status := okc_api.g_ret_sts_error;
        
    WHEN OTHERS THEN
       -- store SQL error message on message stack
       okc_api.set_message(p_app_name     => g_app_name,
                           p_msg_name     => g_unexpected_error,
                           p_token1       => g_sqlcode_token,
                           p_token1_value => SQLCODE,
                           p_token2       => g_sqlerrm_token,
                           p_token2_value => SQLERRM);
        
       -- notify caller of an UNEXPETED error
       x_return_status := okc_api.g_ret_sts_unexp_error;
  END get_contract_id;

  ---------------------------------------------------------------------------
  -- PROCEDURE delete_ancestry
  ---------------------------------------------------------------------------
  PROCEDURE delete_ancestry(p_api_version   IN NUMBER,
                           p_init_msg_list IN VARCHAR2,
                           x_return_status OUT NOCOPY VARCHAR2,
                           x_msg_count     OUT NOCOPY NUMBER,
                           x_msg_data      OUT NOCOPY VARCHAR2,
                           p_cle_id        IN NUMBER) IS
     
    l_acyv_rec      okc_acy_pvt.acyv_rec_type;
    --l_out_rec       okc_acy_pvt.acyv_rec_type;
    l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
     
    -- cursor to get ancestry records to delete
    CURSOR l_acyv_csr IS
       SELECT cle_id, cle_id_ascendant
         FROM okc_ancestrys
        WHERE cle_id = p_cle_id;
     
  BEGIN
    -- delete all ancestry records if p_cle_id is not null
    IF (p_cle_id <> okc_api.g_miss_num AND p_cle_id IS NOT NULL) THEN
       OPEN l_acyv_csr;
        
       -- fetch first record
       FETCH l_acyv_csr
          INTO l_acyv_rec.cle_id, l_acyv_rec.cle_id_ascendant;
       WHILE l_acyv_csr%FOUND LOOP
          okc_acy_pvt.delete_row(p_api_version   => p_api_version,
                                 p_init_msg_list => p_init_msg_list,
                                 x_return_status => l_return_status,
                                 x_msg_count     => x_msg_count,
                                 x_msg_data      => x_msg_data,
                                 p_acyv_rec      => l_acyv_rec);
          IF (l_return_status <> okc_api.g_ret_sts_success) THEN
             RAISE g_exception_halt_validation;
          END IF;
          -- fetch next record
          FETCH l_acyv_csr
             INTO l_acyv_rec.cle_id, l_acyv_rec.cle_id_ascendant;
       END LOOP;
       CLOSE l_acyv_csr;
       x_return_status := l_return_status;
    END IF;
  EXCEPTION
    WHEN g_exception_halt_validation THEN
       -- store SQL error message on message stack
       okc_api.set_message(p_app_name     => g_app_name,
                           p_msg_name     => g_unexpected_error,
                           p_token1       => g_sqlcode_token,
                           p_token1_value => SQLCODE,
                           p_token2       => g_sqlerrm_token,
                           p_token2_value => SQLERRM);
       x_return_status := l_return_status;
        
    WHEN OTHERS THEN
       -- store SQL error message on message stack
       okc_api.set_message(p_app_name     => g_app_name,
                           p_msg_name     => g_unexpected_error,
                           p_token1       => g_sqlcode_token,
                           p_token1_value => SQLCODE,
                           p_token2       => g_sqlerrm_token,
                           p_token2_value => SQLERRM);
        
       -- notify caller of an UNEXPETED error
       x_return_status := okc_api.g_ret_sts_unexp_error;
        
       -- verify that cursor was closed
       IF l_acyv_csr%ISOPEN THEN
          CLOSE l_acyv_csr;
       END IF;
        
  END delete_ancestry;
  ---------------------------------------------------------------------------
  -- PROCEDURE update_minor_version
  ---------------------------------------------------------------------------
  FUNCTION update_minor_version(p_chr_id IN NUMBER) RETURN VARCHAR2 IS
  l_api_version   NUMBER := 1;
  l_init_msg_list VARCHAR2(1) := 'F';
  x_return_status VARCHAR2(1);
  x_msg_count     NUMBER;
  x_msg_data      VARCHAR2(2000);
  x_out_rec       okc_cvm_pvt.cvmv_rec_type;
  l_cvmv_rec      okc_cvm_pvt.cvmv_rec_type;
  BEGIN
     
  -- initialize return status
  x_return_status := okc_api.g_ret_sts_success;
     
  -- assign/populate contract header id
  l_cvmv_rec.chr_id := p_chr_id;
     
  okc_cvm_pvt.update_contract_version(p_api_version   => l_api_version,
                                      p_init_msg_list => l_init_msg_list,
                                      x_return_status => x_return_status,
                                      x_msg_count     => x_msg_count,
                                      x_msg_data      => x_msg_data,
                                      p_cvmv_rec      => l_cvmv_rec,
                                      x_cvmv_rec      => x_out_rec);
     
  -- Error handling....
  -- calls OTHERS exception
  RETURN(x_return_status);
  EXCEPTION
  WHEN OTHERS THEN
     -- notify caller of an error
     x_return_status := okc_api.g_ret_sts_error;
        
     -- store SQL error message on message stack
     okc_api.set_message(p_app_name     => g_app_name,
                         p_msg_name     => g_unexpected_error,
                         p_token1       => g_sqlcode_token,
                         p_token1_value => SQLCODE,
                         p_token2       => g_sqlerrm_token,
                         p_token2_value => SQLERRM);
        
     RETURN(x_return_status);
  END;
  
  ---------------------------------------------------------------------------
  -- PROCEDURE delete_contract_line
  ---------------------------------------------------------------------------
  PROCEDURE delete_contract_line(p_api_version   IN NUMBER,
                              p_init_msg_list IN VARCHAR2,
                              x_return_status OUT NOCOPY VARCHAR2,
                              x_msg_count     OUT NOCOPY NUMBER,
                              x_msg_data      OUT NOCOPY VARCHAR2,
                              p_clev_rec      IN xxoks_cle_pvt.clev_rec_type) IS
     
  l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
  l_chr_id        NUMBER;
  l_dummy_val     NUMBER;
  l_major_version fnd_attached_documents.pk2_value%TYPE;
     
  CURSOR l_clev_csr IS
     SELECT COUNT(*) FROM okc_k_lines_b WHERE cle_id = p_clev_rec.id;
     
  CURSOR l_cimv_csr IS
     SELECT COUNT(*) FROM okc_k_items WHERE cle_id = p_clev_rec.id;
     
  CURSOR l_crjv_csr IS
     SELECT id, object_version_number
       FROM okc_k_rel_objs
      WHERE cle_id = p_clev_rec.id;
     
  CURSOR l_cvm_csr(p_chr_id NUMBER) IS
     SELECT to_char(major_version)
       FROM okc_k_vers_numbers
      WHERE chr_id = p_chr_id;
     
  CURSOR l_scrv_csr IS
     SELECT id, object_version_number, dnz_chr_id
       FROM okc_k_sales_credits
      WHERE cle_id = p_clev_rec.id;
     
  CURSOR l_okc_ph_line_breaks_v_csr IS
     SELECT id, object_version_number, cle_id
       FROM okc_ph_line_breaks
      WHERE cle_id = p_clev_rec.id;
     
  -- Bug #3358872; Added condition dnz_chr_id to improve the
  -- performance of the sql.
     
  CURSOR l_gvev_csr IS
     SELECT id, object_version_number
       FROM okc_governances
      WHERE cle_id = p_clev_rec.id AND
            dnz_chr_id = l_chr_id;
     
  l_crjv_rec okc_k_rel_objs_pub.crjv_rec_type;
  --i          NUMBER := 0;
     
  l_scrv_rec okc_sales_credit_pub.scrv_rec_type;
     
  l_okc_ph_line_breaks_v_rec okc_ph_line_breaks_pub.okc_ph_line_breaks_v_rec_type;
  --l_lse_id                   NUMBER; --linestyle
  --l_dnz_chr_id               NUMBER;
  l_ph_pricing_type          VARCHAR2(30);
     
  l_gvev_rec okc_gve_pvt.gvev_rec_type;
     
  BEGIN
  -- check whether the contract is updateable or not
  xxoks_coverages_pvt.get_contract_id(p_clev_rec      => p_clev_rec,
                                      x_chr_id        => l_chr_id,
                                      x_return_status => l_return_status);
     
  IF (l_return_status = okc_api.g_ret_sts_success) THEN
     IF (okc_contract_pub.update_allowed(l_chr_id) <> 'Y') THEN
        RAISE g_no_update_allowed_exception;
     END IF;
  END IF;
     
  -- check whether detail records exists
  OPEN l_clev_csr;
  FETCH l_clev_csr
     INTO l_dummy_val;
  CLOSE l_clev_csr;
     
  -- delete only if there are no detail records
  IF (l_dummy_val = 0) THEN
     -- check if there are any items exist for this contract line
     OPEN l_cimv_csr;
     FETCH l_cimv_csr
        INTO l_dummy_val;
     CLOSE l_cimv_csr;
        
     -- delete only if there are no items
     IF (l_dummy_val = 0) THEN
        xxoks_cle_pvt.delete_row(p_api_version   => p_api_version,
                                 p_init_msg_list => p_init_msg_list,
                                 x_return_status => x_return_status,
                                 x_msg_count     => x_msg_count,
                                 x_msg_data      => x_msg_data,
                                 p_clev_rec      => p_clev_rec);
           
        -- if the above process is success, delete all ancestrys
        IF (x_return_status = okc_api.g_ret_sts_success) THEN
           delete_ancestry(p_api_version   => p_api_version,
                           p_init_msg_list => p_init_msg_list,
                           x_return_status => x_return_status,
                           x_msg_count     => x_msg_count,
                           x_msg_data      => x_msg_data,
                           p_cle_id        => p_clev_rec.id);
        END IF;
           
     ELSE
        okc_api.set_message(p_app_name     => g_app_name,
                            p_msg_name     => g_no_parent_record,
                            p_token1       => g_child_table_token,
                            p_token1_value => 'OKC_K_ITEMS_V',
                            p_token2       => g_parent_table_token,
                            p_token2_value => 'OKC_K_LINES_V');
        -- notify caller of an error
        x_return_status := okc_api.g_ret_sts_error;
     END IF;
  ELSE
     okc_api.set_message(p_app_name     => g_app_name,
                         p_msg_name     => g_no_parent_record,
                         p_token1       => g_child_table_token,
                         p_token1_value => 'OKC_K_LINES_V',
                         p_token2       => g_parent_table_token,
                         p_token2_value => 'OKC_K_LINES_V');
     -- notify caller of an error
     x_return_status := okc_api.g_ret_sts_error;
  END IF;
     
  -- Delete relationships with line and other objects
  IF (x_return_status = okc_api.g_ret_sts_success) THEN
     FOR c IN l_crjv_csr LOOP
        l_crjv_rec.id                    := c.id;
        l_crjv_rec.object_version_number := c.object_version_number;
           
        okc_k_rel_objs_pub.delete_row(p_api_version   => p_api_version,
                                      p_init_msg_list => p_init_msg_list,
                                      x_return_status => x_return_status,
                                      x_msg_count     => x_msg_count,
                                      x_msg_data      => x_msg_data,
                                      p_crjv_rec      => l_crjv_rec);
           
     END LOOP;
  END IF;
     
  -- Delete sales credits
  IF (x_return_status = okc_api.g_ret_sts_success) THEN
     FOR c IN l_scrv_csr LOOP
        l_scrv_rec.id                    := c.id;
        l_scrv_rec.object_version_number := c.object_version_number;
        l_scrv_rec.dnz_chr_id            := c.dnz_chr_id;
           
        okc_sales_credit_pub.delete_sales_credit(p_api_version   => p_api_version,
                                                 p_init_msg_list => p_init_msg_list,
                                                 x_return_status => x_return_status,
                                                 x_msg_count     => x_msg_count,
                                                 x_msg_data      => x_msg_data,
                                                 p_scrv_rec      => l_scrv_rec);
           
     END LOOP;
  END IF;
     
  -- Delete price hold line breaks
  IF (x_return_status = okc_api.g_ret_sts_success) THEN
        
     /**********************************************
          don't need to do this for delete
     --added for price hold top lines
     IF l_lse_id = 61 THEN
          --if the contract line being deleted is a Price Hold top line,
          --we need to delete the corresponding entries in QP
           
          OKC_PHI_PVT.process_price_hold(
                  p_api_version    => p_api_version,
                  p_init_msg_list  => p_init_msg_list,
                  x_return_status  => x_return_status,
                  x_msg_count      => x_msg_count,
                  x_msg_data       => x_msg_data,
                  p_chr_id         => l_dnz_chr_id,
                  p_operation_code => 'TERMINATE');
     END IF;
     ****************************************************/
        
     --added for price hold sublines
     IF l_ph_pricing_type = 'PRICE_BREAK' THEN
        --if the contract line being deleted is a Price Hold sub line with pricing type of 'Price Break'
        --we need to delete the price hold line breaks as well
           
        FOR c IN l_okc_ph_line_breaks_v_csr LOOP
           l_okc_ph_line_breaks_v_rec.id                    := c.id;
           l_okc_ph_line_breaks_v_rec.object_version_number := c.object_version_number;
           l_okc_ph_line_breaks_v_rec.cle_id                := c.cle_id;
              
           okc_ph_line_breaks_pub.delete_price_hold_line_breaks(p_api_version              => p_api_version,
                                                                p_init_msg_list            => p_init_msg_list,
                                                                x_return_status            => x_return_status,
                                                                x_msg_count                => x_msg_count,
                                                                x_msg_data                 => x_msg_data,
                                                                p_okc_ph_line_breaks_v_rec => l_okc_ph_line_breaks_v_rec);
        END LOOP;
     END IF;
        
  END IF;
     
  -- Delete all contract governances information at the line level
  IF (x_return_status = okc_api.g_ret_sts_success) THEN
     --(note: we do not have to write code to delete goverances in delete_contract_header because
     --that is already being done in okc_delete_contract_pvt.delete_contract where the delete is done
     --on the basis of dnz_chr_id so lines are deleted there as well)
        
     FOR c IN l_gvev_csr LOOP
           
        l_gvev_rec.id                    := c.id;
        l_gvev_rec.object_version_number := c.object_version_number;
           
        okc_gve_pvt.delete_row(p_api_version   => p_api_version,
                               p_init_msg_list => p_init_msg_list,
                               x_return_status => x_return_status,
                               x_msg_count     => x_msg_count,
                               x_msg_data      => x_msg_data,
                               p_gvev_rec      => l_gvev_rec);
           
     END LOOP;
        
  END IF;
     
  -- get major version
  OPEN l_cvm_csr(l_chr_id);
  FETCH l_cvm_csr
     INTO l_major_version;
  CLOSE l_cvm_csr;
     
  -- Delete any attachments assiciated with this line
  IF (x_return_status = okc_api.g_ret_sts_success) THEN
     IF (fnd_attachment_util_pkg.get_atchmt_exists(l_entity_name => 'OKC_K_LINES_B',
                                                   l_pkey1       => p_clev_rec.id,
                                                   l_pkey2       => l_major_version) = 'Y')
           
     -- The following line to be added to the code once
     -- bug 1553916 completes
     -- l_pkey2 => l_major_version) = 'Y')
     -- also below remove the comments
     -- in fnd_attached_documents2_pkg.delete_attachments call
      THEN
        fnd_attached_documents2_pkg.delete_attachments(x_entity_name => 'OKC_K_LINES_B',
                                                       x_pk1_value   => p_clev_rec.id,
                                                       x_pk2_value   => l_major_version);
     END IF;
  END IF;
     
  -- Update minor version
  IF (x_return_status = okc_api.g_ret_sts_success) THEN
     x_return_status := update_minor_version(l_chr_id);
  END IF;
  EXCEPTION
  WHEN g_no_update_allowed_exception THEN
     okc_api.set_message(p_app_name     => g_app_name,
                         p_msg_name     => g_no_update_allowed,
                         p_token1       => 'VALUE1',
                         p_token1_value => 'Contract Lines');
        
     -- notify caller of an error
     x_return_status := okc_api.g_ret_sts_error;
  WHEN OTHERS THEN
     -- store SQL error message on message stack
     okc_api.set_message(p_app_name     => g_app_name,
                         p_msg_name     => g_unexpected_error,
                         p_token1       => g_sqlcode_token,
                         p_token1_value => SQLCODE,
                         p_token2       => g_sqlerrm_token,
                         p_token2_value => SQLERRM);
        
     -- notify caller of an UNEXPETED error
     x_return_status := okc_api.g_ret_sts_unexp_error;
  END delete_contract_line;

  ---------------------------------------------------------------------------
  -- PROCEDURE delete_contract_lines
  ---------------------------------------------------------------------------
  PROCEDURE delete_contract_lines(p_api_version   IN NUMBER,
                               p_init_msg_list IN VARCHAR2,
                               x_return_status OUT NOCOPY VARCHAR2,
                               x_msg_count     OUT NOCOPY NUMBER,
                               x_msg_data      OUT NOCOPY VARCHAR2,
                               p_clev_tbl      IN xxoks_cle_pvt.clev_tbl_type) IS
     
  l_api_name    CONSTANT VARCHAR2(30) := 'DELETE_CONTRACT_LINE';
  l_api_version CONSTANT NUMBER := 1.0;
  l_return_status  VARCHAR2(1) := okc_api.g_ret_sts_success;
  l_overall_status VARCHAR2(1) := okc_api.g_ret_sts_success;
  i                NUMBER;
  BEGIN
    -- call START_ACTIVITY to create savepoint, check compatibility
    -- and initialize message list
    l_return_status := okc_api.start_activity(p_api_name      => l_api_name,
                                              p_pkg_name      => g_pkg_name,
                                              p_init_msg_list => p_init_msg_list,
                                              l_api_version   => l_api_version,
                                              p_api_version   => p_api_version,
                                              p_api_type      => '_PUB',
                                              x_return_status => x_return_status);
       
    -- check if activity started successfully
    IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
       RAISE okc_api.g_exception_unexpected_error;
    ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
       RAISE okc_api.g_exception_error;
    END IF;
       
    IF (p_clev_tbl.COUNT > 0) THEN
       i := p_clev_tbl.FIRST;
       LOOP
          -- call procedure in complex API
          xxoks_coverages_pvt.delete_contract_line(p_api_version   => p_api_version,
                                                   p_init_msg_list => p_init_msg_list,
                                                   x_return_status => x_return_status,
                                                   x_msg_count     => x_msg_count,
                                                   x_msg_data      => x_msg_data,
                                                   p_clev_rec      => p_clev_tbl(i));
             
          -- store the highest degree of error
          IF x_return_status <> okc_api.g_ret_sts_success THEN
             IF l_overall_status <> okc_api.g_ret_sts_unexp_error THEN
                l_overall_status := x_return_status;
             END IF;
          END IF;
          EXIT WHEN(i = p_clev_tbl.LAST);
          i := p_clev_tbl.NEXT(i);
       END LOOP;
       -- return overall status
       x_return_status := l_overall_status;
    END IF;
       
    IF x_return_status = okc_api.g_ret_sts_unexp_error THEN
       RAISE okc_api.g_exception_unexpected_error;
    ELSIF x_return_status = okc_api.g_ret_sts_error THEN
       RAISE okc_api.g_exception_error;
    END IF;
       
    -- end activity
    okc_api.end_activity(x_msg_count => x_msg_count,
                         x_msg_data  => x_msg_data);
  EXCEPTION
    WHEN okc_api.g_exception_error THEN
       x_return_status := okc_api.handle_exceptions(p_api_name  => l_api_name,
                                                    p_pkg_name  => g_pkg_name,
                                                    p_exc_name  => 'OKC_API.G_RET_STS_ERROR',
                                                    x_msg_count => x_msg_count,
                                                    x_msg_data  => x_msg_data,
                                                    p_api_type  => '_PUB');
          
    WHEN okc_api.g_exception_unexpected_error THEN
       x_return_status := okc_api.handle_exceptions(p_api_name  => l_api_name,
                                                    p_pkg_name  => g_pkg_name,
                                                    p_exc_name  => 'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                    x_msg_count => x_msg_count,
                                                    x_msg_data  => x_msg_data,
                                                    p_api_type  => '_PUB');
          
    WHEN OTHERS THEN
       x_return_status := okc_api.handle_exceptions(p_api_name  => l_api_name,
                                                    p_pkg_name  => g_pkg_name,
                                                    p_exc_name  => 'OTHERS',
                                                    x_msg_count => x_msg_count,
                                                    x_msg_data  => x_msg_data,
                                                    p_api_type  => '_PUB');
          
  END delete_contract_lines;
  
  ---------------------------------------------------------------------------
  -- PROCEDURE create_actual_coverage
  ---------------------------------------------------------------------------
  PROCEDURE create_actual_coverage( p_api_version        IN NUMBER,
                                    p_init_msg_list      IN VARCHAR2 DEFAULT okc_api.g_false,
                                    x_return_status      OUT NOCOPY VARCHAR2,
                                    x_msg_count          OUT NOCOPY NUMBER,
                                    x_msg_data           OUT NOCOPY VARCHAR2,
                                    p_ac_rec_in          IN ac_rec_type,
                                    p_restricted_update  IN VARCHAR2 DEFAULT 'F',
                                    x_actual_coverage_id IN OUT NUMBER) IS
     
  CURSOR cur_linedet(p_line_id IN NUMBER) IS
     SELECT sfwt_flag,
            chr_id,
            start_date,
            end_date,
            lse_id,
            line_number,
            display_sequence,
            NAME,
            item_description,
            exception_yn,
            price_list_id,
            attribute_category,
            attribute1,
            attribute2,
            attribute3,
            attribute4,
            attribute5,
            attribute6,
            attribute7,
            attribute8,
            attribute9,
            attribute10,
            attribute11,
            attribute12,
            attribute13,
            attribute14,
            attribute15
       FROM okc_k_lines_v
      WHERE id = p_line_id;
  --------------------------
  CURSOR cur_linedet3(p_line_id IN NUMBER) IS
     SELECT sfwt_flag,
            chr_id,
            start_date,
            end_date,
            lse_id,
            line_number,
            display_sequence,
            NAME,
            item_description,
            exception_yn,
            price_list_id,
            attribute_category,
            attribute1,
            attribute2,
            attribute3,
            attribute4,
            attribute5,
            attribute6,
            attribute7,
            attribute8,
            attribute9,
            attribute10,
            attribute11,
            attribute12,
            attribute13,
            attribute14,
            attribute15
       FROM okc_k_lines_v
      WHERE id = p_line_id;
  --------------------------
  linedet_rec3 cur_linedet3%ROWTYPE;
  linedet_rec  cur_linedet%ROWTYPE;
  linedet_rec1 cur_linedet%ROWTYPE;
  --linedet_rec2 cur_linedet%ROWTYPE;
     
  CURSOR cur_childline(p_cle_id IN NUMBER, p_lse_id IN NUMBER) IS
     SELECT id
       FROM okc_k_lines_b
      WHERE cle_id = p_cle_id AND
            lse_id = p_lse_id;
  -------------------------------------
     
  CURSOR cur_childline_br(p_cle_id IN NUMBER, p_lse_id IN NUMBER) IS
     SELECT id,
            exception_yn,
            attribute_category,
            attribute1,
            attribute2,
            attribute3,
            attribute4,
            attribute5,
            attribute6,
            attribute7,
            attribute8,
            attribute9,
            attribute10,
            attribute11,
            attribute12,
            attribute13,
            attribute14,
            attribute15
       FROM okc_k_lines_b
      WHERE cle_id = p_cle_id AND
            lse_id = p_lse_id;
  ---------------------------------------
     
  CURSOR cur_childline_bt(p_cle_id IN NUMBER, p_lse_id IN NUMBER) IS
     SELECT id
       FROM okc_k_lines_b
      WHERE cle_id = p_cle_id AND
            lse_id = p_lse_id;
  ----------------------------------------
     
  CURSOR cur_childline1(p_cle_id IN NUMBER, p_lse_id IN NUMBER) IS
     SELECT id
       FROM okc_k_lines_b
      WHERE cle_id = p_cle_id AND
            lse_id = p_lse_id;
  -----------------------------------------
     
  CURSOR cur_ptrldet(p_cle_id IN NUMBER, p_role_code IN VARCHAR2) IS
     SELECT pr.id,
            pr.sfwt_flag,
            pr.object1_id1,
            pr.object1_id2,
            pr.jtot_object1_code,
            pr.code,
            pr.facility,
            pr.minority_group_lookup_code,
            pr.small_business_flag,
            pr.women_owned_flag
       FROM okc_k_party_roles_v pr, okc_k_lines_b lv
      WHERE pr.cle_id = p_cle_id AND
            pr.rle_code = p_role_code AND
            pr.cle_id = lv.id AND
            pr.dnz_chr_id = lv.dnz_chr_id;
  ptrldet_rec cur_ptrldet%ROWTYPE;
  ------------------------------------------
     
  CURSOR cur_contactdet(p_cpl_id IN NUMBER) IS
     SELECT cro_code,
            contact_sequence,
            object1_id1,
            object1_id2,
            jtot_object1_code,
            resource_class
       FROM okc_contacts_v
      WHERE cpl_id = p_cpl_id;
  --------------------------------------------
     
  CURSOR cur_itemdet(p_id IN NUMBER) IS
     SELECT object1_id1,
            object1_id2,
            jtot_object1_code,
            number_of_items,
            exception_yn
       FROM okc_k_items_v
      WHERE cle_id = p_id;
     
  --------------------------------------------------
     
  CURSOR cur_get_billrate_schedules(p_cle_id IN NUMBER) IS
     SELECT id,
            cle_id,
            bt_cle_id,
            dnz_chr_id,
            start_hour,
            start_minute,
            end_hour,
            end_minute,
            monday_flag,
            tuesday_flag,
            wednesday_flag,
            thursday_flag,
            friday_flag,
            saturday_flag,
            sunday_flag,
            object1_id1,
            object1_id2,
            jtot_object1_code,
            bill_rate_code,
            flat_rate,
            uom,
            holiday_yn,
            percent_over_list_price,
            program_application_id,
            program_id,
            program_update_date,
            request_id,
            created_by,
            creation_date,
            last_updated_by,
            last_update_date,
            last_update_login,
            security_group_id,
            object_version_number --Added
       FROM oks_billrate_schedules
      WHERE cle_id = p_cle_id;
     
  -------------------------------------------------
     
  CURSOR cur_get_oks_line(p_cle_id IN NUMBER) IS
     SELECT id,
            cle_id,
            dnz_chr_id,
            discount_list,
            coverage_type,
            exception_cov_id,
            limit_uom_quantified,
            discount_amount,
            discount_percent,
            offset_duration,
            offset_period,
            incident_severity_id,
            pdf_id,
            work_thru_yn,
            react_active_yn,
            transfer_option,
            prod_upgrade_yn,
            inheritance_type,
            pm_program_id,
            pm_conf_req_yn,
            pm_sch_exists_yn,
            allow_bt_discount,
            apply_default_timezone,
            sync_date_install,
            sfwt_flag,
            react_time_name,
            object_version_number,
            security_group_id,
            request_id,
            created_by,
            creation_date,
            last_updated_by,
            last_update_date,
            last_update_login
       FROM oks_k_lines_v
      WHERE cle_id = p_cle_id;
     
  -------------------------------------------------
     
  -- FOR NOTES BARORA 07/31/03
     
  CURSOR cur_get_notes(p_source_object_id IN NUMBER) IS
     SELECT jtf_note_id,
            parent_note_id,
            source_object_code,
            source_number,
            notes, --
            notes_detail,
            note_status,
            source_object_meaning,
            note_type,
            note_type_meaning,
            attribute1,
            attribute2,
            attribute3,
            attribute4,
            attribute5,
            attribute6,
            attribute7,
            attribute8,
            attribute9,
            attribute10,
            attribute11,
            attribute12,
            attribute13,
            attribute14,
            attribute15,
            note_status_meaning,
            decoded_source_code,
            decoded_source_meaning,
            CONTEXT
       FROM jtf_notes_vl
      WHERE source_object_id = p_source_object_id AND
            source_object_code = 'OKS_COVTMPL_NOTE' AND
            note_status <> 'P';
  -------------------------------------------------------------------------------
  -- get the pm_program_id associated with the service line added by jvorugan for R12 bug:4610449
  CURSOR cur_get_program_id(p_contract_line_id IN NUMBER) IS
     SELECT pm_program_id
       FROM oks_k_lines_b
      WHERE cle_id = p_contract_line_id;
     
  -------------------------------------------------------------------------------
  CURSOR get_cov_timezones(p_cle_id IN NUMBER) IS
     SELECT id, cle_id, default_yn, timezone_id
       FROM oks_coverage_timezones
      WHERE cle_id = p_cle_id;
  -------------------------------------------------------------------------------
  CURSOR get_cov_times(p_cov_tz_id IN NUMBER) IS
     SELECT id,
            cov_tze_line_id,
            dnz_chr_id,
            start_hour,
            start_minute,
            end_hour,
            end_minute,
            monday_yn,
            tuesday_yn,
            wednesday_yn,
            thursday_yn,
            friday_yn,
            saturday_yn,
            sunday_yn
       FROM oks_coverage_times
      WHERE cov_tze_line_id = p_cov_tz_id;
  -------------------------------------------------------------------------------
     
  CURSOR cur_get_action_types(p_cle_id IN NUMBER) IS
     SELECT id, action_type_code
       FROM oks_action_time_types
      WHERE cle_id = p_cle_id;
     
  CURSOR cur_get_action_times(p_cov_act_type_id IN NUMBER) IS
     SELECT id,
            uom_code,
            sun_duration,
            mon_duration,
            tue_duration,
            wed_duration,
            thu_duration,
            fri_duration,
            sat_duration
       FROM oks_action_times
      WHERE cov_action_type_id = p_cov_act_type_id;
  -------------------------------------------------------------------------------
  -- Fix for Bug:4703431. Modified by jvorugan
  CURSOR cur_get_org_id(p_contract_id IN NUMBER) IS
     SELECT org_id FROM okc_k_headers_all_b WHERE id = p_contract_id;
     
  --l_jtf_note_id   NUMBER;
  --l_notes_detail  VARCHAR2(32767);
  --l_pm_program_id NUMBER;
  l_object_id     NUMBER;
     
  g_start_date        DATE;
  g_end_date          DATE;
  --l_clev_rec          okc_contract_pub.clev_rec_type;
  l_clev_tbl_in       okc_contract_pub.clev_tbl_type;
  l_clev_tbl_out      okc_contract_pub.clev_tbl_type;
  --l_lsl_id            NUMBER;
  c_cle_id            NUMBER;
  txg_cle_id          NUMBER;
  crt_cle_id          NUMBER;
  bt_cle_id           NUMBER;
  br_cle_id           NUMBER;
  tmp_txg_cle_id      NUMBER;
  tmp_crt_cle_id      NUMBER;
  tmp_bt_cle_id       NUMBER;
  tmp_br_cle_id       NUMBER;
  g_chr_id            NUMBER;
  --l_ctiv_tbl_in       okc_rule_pub.ctiv_tbl_type;
  --l_ctiv_tbl_out      okc_rule_pub.ctiv_tbl_type;
  l_contact_id        NUMBER;
  l_bill_rate_tbl_in  oks_brs_pvt.oksbillrateschedulesvtbltype;
  x_bill_rate_tbl_out oks_brs_pvt.oksbillrateschedulesvtbltype;
  --
  l_api_version   CONSTANT NUMBER := 1.0;
  l_init_msg_list CONSTANT VARCHAR2(1) := 'F';
  l_return_status      VARCHAR2(1);
  l_msg_count          NUMBER;
  l_msg_data           VARCHAR2(2000) := NULL;
  --l_msg_index_out      NUMBER;
  l_service_line_id    NUMBER;
  l_template_line_id   NUMBER;
  --l_actual_coverage_id NUMBER;
  --l_api_name CONSTANT VARCHAR2(30) := 'Create_Actual_Coverage';
  --
  --l_catv_rec_in   okc_k_article_pub.catv_rec_type;
  --l_catv_rec_out   okc_k_article_pub.catv_rec_type;
  --l_article_id        NUMBER;
  --v_clob              CLOB;
  --v_Text              varchar2(2000);
  --v_Length            BINARY_INTEGER;
  --
     
  --
  l_cimv_tbl_in  okc_contract_item_pub.cimv_tbl_type;
  l_cimv_tbl_out okc_contract_item_pub.cimv_tbl_type;
  --
  l_ctcv_tbl_in   okc_contract_party_pub.ctcv_tbl_type;
  l_ctcv_tbl_out  okc_contract_party_pub.ctcv_tbl_type;
  l_cplv_tbl_in   okc_contract_party_pub.cplv_tbl_type;
  l_cplv_tbl_out  okc_contract_party_pub.cplv_tbl_type;
  l_cpl_id        NUMBER;
  tmp_cpl_id      NUMBER;
  l_parent_lse_id NUMBER;
  tmp_lse_id      NUMBER;
  l_bt_lse_id     NUMBER;
  l_br_lse_id     NUMBER;
  l_rle_code      VARCHAR2(30);
     
  l_klnv_tbl_in  oks_kln_pvt.klnv_tbl_type;
  l_klnv_tbl_out oks_kln_pvt.klnv_tbl_type;
     
  l_covtz_tbl_in  oks_ctz_pvt.okscoveragetimezonesvtbltype;
  l_covtz_tbl_out oks_ctz_pvt.okscoveragetimezonesvtbltype;
     
  --l_covtz_rec_in  oks_ctz_pvt.okscoveragetimezonesvrectype;
  --l_covtz_rec_out oks_ctz_pvt.okscoveragetimezonesvrectype;
     
  l_covtim_tbl_in  oks_cvt_pvt.oks_coverage_times_v_tbl_type;
  l_covtim_tbl_out oks_cvt_pvt.oks_coverage_times_v_tbl_type;
     
  l_act_type_tbl_in  oks_act_pvt.oksactiontimetypesvtbltype;
  l_act_type_tbl_out oks_act_pvt.oksactiontimetypesvtbltype;
     
  l_act_time_tbl_in  oks_acm_pvt.oks_action_times_v_tbl_type;
  l_act_time_tbl_out oks_acm_pvt.oks_action_times_v_tbl_type;
     
  covtim_ctr     NUMBER := 0;
  --acttim_ctr     NUMBER := 0;
  l_cov_templ_yn VARCHAR2(1) := 'Y';
     
  l_rt_cle_id            NUMBER := 0;
  l_act_type_line_id     NUMBER := 0;
  l_cov_act_type_line_id NUMBER := 0;
  act_time_ctr           NUMBER := 0;
     
  --l_exists     NUMBER;
  l_start_date DATE;
  l_currency   VARCHAR2(15) := NULL;
  l_type_msmtch CONSTANT VARCHAR2(200) := 'OKS_COV_TYPE_MSMTCH';
  -----------------------------------
  CURSOR check_cur(p_line_id IN NUMBER) IS
     SELECT COUNT(1)
       FROM okc_k_lines_b
      WHERE cle_id = p_line_id AND
            lse_id IN (2, 15, 20);
     
  ------------------------------------
  FUNCTION getcurrency(p_id IN NUMBER) RETURN VARCHAR2 IS
     CURSOR currency_cur IS
        SELECT currency_code FROM okc_k_lines_b WHERE id = p_id;
        
  BEGIN
     OPEN currency_cur;
     FETCH currency_cur
        INTO l_currency;
     CLOSE currency_cur;
     RETURN l_currency;
  END getcurrency;
  FUNCTION getstatus(p_id IN NUMBER) RETURN VARCHAR2 IS
     l_sts okc_k_lines_b.sts_code%TYPE := NULL;
     CURSOR sts_cur IS
        SELECT sts_code FROM okc_k_lines_b WHERE id = p_id;
  BEGIN
     OPEN sts_cur;
     FETCH sts_cur
        INTO l_sts;
     CLOSE sts_cur;
     RETURN l_sts;
  END getstatus;
  -----------------------------------------
  BEGIN
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.set_indentation('Create_Actual_Coverage');
     okc_debug.log('Entered Create_Actual_Coverage', 2);
  END IF;
     
  l_service_line_id  := p_ac_rec_in.svc_cle_id;
  l_template_line_id := p_ac_rec_in.tmp_cle_id;
  l_rle_code         := nvl(p_ac_rec_in.rle_code, 'VENDOR');
     
  validate_svc_cle_id(p_ac_rec        => p_ac_rec_in,
                      x_return_status => l_return_status);
     
  IF NOT l_return_status = okc_api.g_ret_sts_success THEN
     okc_api.set_message(g_app_name,
                         g_invalid_value,
                         g_col_name_token,
                         'Error in Service Line Validation');
     RAISE g_exception_halt_validation;
  END IF;
     
  validate_tmp_cle_id(p_ac_rec        => p_ac_rec_in,
                      x_template_yn   => l_cov_templ_yn,
                      x_return_status => l_return_status);
     
  IF NOT l_return_status = okc_api.g_ret_sts_success THEN
     okc_api.set_message(g_app_name,
                         g_invalid_value,
                         g_col_name_token,
                         'Error in Coverage Template Line Validation');
     RAISE g_exception_halt_validation;
  END IF;
     
  IF NOT
      (SYSDATE BETWEEN linedet_rec.start_date AND linedet_rec.end_date) THEN
        
     okc_api.set_message(g_app_name,
                         g_invalid_value,
                         g_col_name_token,
                         'Coverage Template_dates');
     x_return_status := okc_api.g_ret_sts_error;
     RETURN;
  END IF;
     
  /*      OPEN check_cur(l_service_line_id);
        FETCH check_cur
           INTO l_exists;
        CLOSE check_cur;
           
        IF NOT l_exists = 0 THEN
           l_msg_data := 'Coverage already Exists';
           okc_api.set_message(g_app_name,
                               g_invalid_value,
                               g_col_name_token,
                               'Coverage Exists');
           x_return_status := okc_api.g_ret_sts_error;
           RETURN;
        END IF;
  */
  -- Contract Line for the Service Line
  OPEN cur_linedet(l_service_line_id);
  FETCH cur_linedet
     INTO linedet_rec;
  IF cur_linedet%FOUND THEN
     l_parent_lse_id := linedet_rec.lse_id;
     g_chr_id        := linedet_rec.chr_id;
  ELSE
     okc_api.set_message(g_app_name,
                         g_invalid_value,
                         g_col_name_token,
                         'Given Service or Warranty does not exist');
     CLOSE cur_linedet;
     l_return_status := okc_api.g_ret_sts_error;
     RAISE g_exception_halt_validation;
  END IF;
  CLOSE cur_linedet;
     
  -- Coverage for that Service Line
     
  OPEN cur_linedet(l_template_line_id);
  FETCH cur_linedet
     INTO linedet_rec;
  IF cur_linedet%FOUND THEN
     tmp_lse_id := linedet_rec.lse_id;
  ELSE
     okc_api.set_message(g_app_name,
                         g_invalid_value,
                         g_col_name_token,
                         'Coverage Template does not exist');
     CLOSE cur_linedet;
     l_return_status := okc_api.g_ret_sts_error;
     RAISE g_exception_halt_validation;
  END IF;
  CLOSE cur_linedet;
     
  -- commented for NEW  ER ; warranty to be opened up for bill types and bill rates
  -- added additional check tmp_lse_id NOT IN (2,20) for bug # 3378148
     
  IF (l_parent_lse_id IN (1, 19)) THEN
     IF (tmp_lse_id NOT IN (2, 20)) THEN
        okc_api.set_message(g_app_name, l_type_msmtch);
        l_return_status := okc_api.g_ret_sts_error;
        RAISE g_exception_halt_validation;
     END IF;
  ELSIF (l_parent_lse_id = 14) THEN
     IF (tmp_lse_id <> 15) THEN
        okc_api.set_message(g_app_name, l_type_msmtch);
        l_return_status := okc_api.g_ret_sts_error;
        RAISE g_exception_halt_validation;
     END IF;
     -- commented on 15-Jan-2004 SMOHAPAT
     /*  ELSIF (l_Parent_lse_id = 19) THEN
        IF (tmp_lse_id <> 20) THEN
           OKC_API.set_message(G_APP_NAME, l_type_msmtch);
           l_return_status := OKC_API.G_RET_STS_ERROR;
           RAISE G_EXCEPTION_HALT_VALIDATION;
        END IF;
     */
  END IF;
     
  -- Create Coverage line
  init_clev(l_clev_tbl_in);
     
  l_clev_tbl_in(1).chr_id := NULL;
  l_clev_tbl_in(1).id := x_actual_coverage_id;
  l_clev_tbl_in(1).cle_id := l_service_line_id;
  l_clev_tbl_in(1).dnz_chr_id := g_chr_id;
  l_clev_tbl_in(1).sfwt_flag := linedet_rec.sfwt_flag;
  l_clev_tbl_in(1).lse_id := l_parent_lse_id + 1; --LineDet_Rec.lse_id
  l_clev_tbl_in(1).sts_code := getstatus(l_service_line_id);
  l_clev_tbl_in(1).currency_code := getcurrency(l_service_line_id);
  l_clev_tbl_in(1).display_sequence := linedet_rec.display_sequence;
  l_clev_tbl_in(1).line_number := nvl(linedet_rec.line_number, 1);
  l_clev_tbl_in(1).exception_yn := nvl(linedet_rec.exception_yn, 'N');
  l_clev_tbl_in(1).item_description := linedet_rec.item_description;
  l_clev_tbl_in(1).NAME := linedet_rec.NAME;
  l_clev_tbl_in(1).start_date := p_ac_rec_in.start_date;
  l_clev_tbl_in(1).end_date := p_ac_rec_in.end_date;
  l_clev_tbl_in(1).attribute_category := linedet_rec.attribute_category;
  l_clev_tbl_in(1).attribute1 := linedet_rec.attribute1;
  l_clev_tbl_in(1).attribute2 := linedet_rec.attribute2;
  l_clev_tbl_in(1).attribute3 := linedet_rec.attribute3;
  l_clev_tbl_in(1).attribute4 := linedet_rec.attribute4;
  l_clev_tbl_in(1).attribute5 := linedet_rec.attribute5;
  l_clev_tbl_in(1).attribute6 := linedet_rec.attribute6;
  l_clev_tbl_in(1).attribute7 := linedet_rec.attribute7;
  l_clev_tbl_in(1).attribute8 := linedet_rec.attribute8;
  l_clev_tbl_in(1).attribute9 := linedet_rec.attribute9;
  l_clev_tbl_in(1).attribute10 := linedet_rec.attribute10;
  l_clev_tbl_in(1).attribute11 := linedet_rec.attribute11;
  l_clev_tbl_in(1).attribute12 := linedet_rec.attribute12;
  l_clev_tbl_in(1).attribute13 := linedet_rec.attribute13;
  l_clev_tbl_in(1).attribute14 := linedet_rec.attribute14;
  l_clev_tbl_in(1).attribute15 := linedet_rec.attribute15;
     
  okc_contract_pub.update_contract_line(p_api_version       => l_api_version,
                                        p_init_msg_list     => l_init_msg_list,
                                        x_return_status     => l_return_status,
                                        x_msg_count         => l_msg_count,
                                        x_msg_data          => l_msg_data,
                                        p_restricted_update => p_restricted_update,
                                        p_clev_tbl          => l_clev_tbl_in,
                                        x_clev_tbl          => l_clev_tbl_out);
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.log('After okc_contract_pub create_contract_line', 2);
  END IF;
     
  IF NOT l_return_status = okc_api.g_ret_sts_success THEN
     RAISE g_exception_halt_validation;
  ELSE
     c_cle_id := l_clev_tbl_out(1).id;
  END IF;
     
  -- Create record in OKS_K_LINES (new for 11.5.10)
     
  FOR oks_cov_rec IN cur_get_oks_line(l_template_line_id) LOOP
        
     init_oks_k_line(l_klnv_tbl_in);
        
     l_klnv_tbl_in(1).cle_id := c_cle_id;
     l_klnv_tbl_in(1).dnz_chr_id := g_chr_id;
     l_klnv_tbl_in(1).coverage_type := oks_cov_rec.coverage_type;
     l_klnv_tbl_in(1).exception_cov_id := oks_cov_rec.exception_cov_id;
     l_klnv_tbl_in(1).transfer_option := oks_cov_rec.transfer_option;
     l_klnv_tbl_in(1).prod_upgrade_yn := oks_cov_rec.prod_upgrade_yn;
     l_klnv_tbl_in(1).inheritance_type := oks_cov_rec.inheritance_type;
     /* Commented by Jvorugan for R12. Bugno:4610449  l_klnv_tbl_in(1).pm_program_id := oks_cov_rec.pm_program_id;
     l_klnv_tbl_in(1).pm_conf_req_yn                 := oks_cov_rec.pm_conf_req_yn;
     l_klnv_tbl_in(1).pm_sch_exists_yn               := oks_cov_rec.pm_sch_exists_yn;  */
     l_klnv_tbl_in(1).sync_date_install := oks_cov_rec.sync_date_install;
     l_klnv_tbl_in(1).sfwt_flag := oks_cov_rec.sfwt_flag;
     l_klnv_tbl_in(1).object_version_number := 1; --oks_cov_rec.object_version_number;
     l_klnv_tbl_in(1).security_group_id := oks_cov_rec.security_group_id;
        
     oks_contract_line_pub.create_line(p_api_version   => l_api_version,
                                       p_init_msg_list => l_init_msg_list,
                                       x_return_status => l_return_status,
                                       x_msg_count     => l_msg_count,
                                       x_msg_data      => l_msg_data,
                                       p_klnv_tbl      => l_klnv_tbl_in,
                                       x_klnv_tbl      => l_klnv_tbl_out,
                                       p_validate_yn   => 'N');
        
     IF (g_debug_enabled = 'Y') THEN
        okc_debug.log('After OKS_CONTRACT_LINE_PUB.CREATE_LINE', 2);
     END IF;
        
     IF NOT l_return_status = okc_api.g_ret_sts_success THEN
        RAISE g_exception_halt_validation;
     END IF;
  END LOOP;
     
  /* Commented by jvorugan. Since notes and pm creation will be done by create_k_coverage_ext
     during renual consolidation,it should not be created.
  --Create Notes and PM schedule only if it is invoked from CREATE_ADJUSTED_COVERAGE based on 12.0 design
  IF l_cov_templ_yn = 'N' then
    -- create notes for actual coverage from the template
    FOR notes_rec IN CUR_GET_NOTES(l_Template_Line_Id) LOOP
        
        JTF_NOTES_PUB.writeLobToData(notes_rec.JTF_NOTE_ID,L_Notes_detail);
        
        JTF_NOTES_PUB.CREATE_NOTE(p_parent_note_id        => notes_rec.parent_note_id ,
                                  p_api_version           => l_api_version,
                                  p_init_msg_list         =>  l_init_msg_list,
                                  p_commit                => 'F',
                                  p_validation_level      => 100,
                                  x_return_status         => l_return_status ,
                                  x_msg_count             => l_msg_count,
                                  x_msg_data              => l_msg_data ,
                                  p_org_id                =>  NULL,
                                  p_source_object_id      => l_Service_Line_Id,
                                  p_source_object_code    => 'OKS_COV_NOTE',
                                  p_notes                 =>notes_rec.notes,
                                  p_notes_detail          => L_Notes_detail,
                                  p_note_status           =>  notes_rec.note_status,
                                  p_entered_by            =>  FND_GLOBAL.USER_ID,
                                  p_entered_date          => SYSDATE ,
                                  x_jtf_note_id           => l_jtf_note_id,
                                  p_last_update_date      => sysdate,
                                  p_last_updated_by       => FND_GLOBAL.USER_ID,
                                  p_creation_date         => SYSDATE,
                                  p_created_by            => FND_GLOBAL.USER_ID,
                                  p_last_update_login     => FND_GLOBAL.LOGIN_ID,
                                  p_attribute1            => notes_rec.ATTRIBUTE1,
                                  p_attribute2            => notes_rec.ATTRIBUTE2,
                                  p_attribute3            => notes_rec.ATTRIBUTE3,
                                  p_attribute4            => notes_rec.ATTRIBUTE4,
                                  p_attribute5            => notes_rec.ATTRIBUTE5,
                                  p_attribute6            => notes_rec.ATTRIBUTE6,
                                  p_attribute7            => notes_rec.ATTRIBUTE7,
                                  p_attribute8            => notes_rec.ATTRIBUTE8,
                                  p_attribute9            => notes_rec.ATTRIBUTE9,
                                  p_attribute10           => notes_rec.ATTRIBUTE10,
                                  p_attribute11           => notes_rec.ATTRIBUTE11,
                                  p_attribute12           => notes_rec.ATTRIBUTE12,
                                  p_attribute13           => notes_rec.ATTRIBUTE13,
                                  p_attribute14           => notes_rec.ATTRIBUTE14,
                                  p_attribute15           => notes_rec.ATTRIBUTE15,
                                  p_context               => notes_rec.CONTEXT,
                                  p_note_type             => notes_rec.NOTE_TYPE);
        
          IF NOT l_return_status = OKC_API.G_RET_STS_SUCCESS THEN
            RAISE G_EXCEPTION_HALT_VALIDATION;
        END IF;
     END LOOP;
        
    OPEN  CUR_GET_PROGRAM_ID(l_Service_Line_Id);
    FETCH CUR_GET_PROGRAM_ID INTO l_pm_program_id;
    CLOSE CUR_GET_PROGRAM_ID;
        
  -- Commented by Jvorugan for R12 bugno:4610449
  --IF l_klnv_tbl_in(1).pm_program_id IS NOT NULL then -- No need to call PM schedule instantiation if there is no program id
    IF l_pm_program_id IS NOT NULL then
        
   OKS_PM_PROGRAMS_PVT. CREATE_PM_PROGRAM_SCHEDULE(
      p_api_version        => l_api_version,
      p_init_msg_list      => l_init_msg_list,
      x_return_status      => l_return_status,
      x_msg_count          => l_msg_count,
      x_msg_data           => l_msg_data,
      p_template_cle_id    => l_Template_Line_Id,
      p_cle_id             => l_Service_Line_Id, --c_cle_id, --instantiated cle id
      p_cov_start_date     => P_ac_rec_in.start_date,
      p_cov_end_date       => P_ac_rec_in.end_date);
        
        
        
    IF (G_DEBUG_ENABLED = 'Y') THEN
        okc_debug.log('After OKS_PM_PROGRAMS_PVT. CREATE_PM_PROGRAM_SCHEDULE'||l_return_status, 2);
    END IF;
        
        
    IF NOT l_return_status = OKC_API.G_RET_STS_SUCCESS THEN
       RAISE G_EXCEPTION_HALT_VALIDATION;
    END IF;
   END IF;
  END IF; -- end of IF condition if l_cov_templ_yn = N
        
  */ -- End of changes by Jvorugan
  l_klnv_tbl_in.DELETE;
  -- FOR THE BUSINESS PROCESSES UNDER COVERAGE TEMPLATE
     
  FOR childline_rec1 IN cur_childline(l_template_line_id,
                                      tmp_lse_id + 1) LOOP
     --L1
     tmp_txg_cle_id := childline_rec1.id;
        
     -- FOR ALL THE LINES UNDER BUSINESS PROCESS
        
     FOR linedet_rec1 IN cur_linedet(tmp_txg_cle_id) LOOP
           
        FOR oks_bp_rec IN cur_get_oks_line(tmp_txg_cle_id) LOOP
           -- Offset Period Logic for Start date and End date
           IF oks_bp_rec.offset_duration IS NOT NULL AND
              oks_bp_rec.offset_period IS NOT NULL THEN
                 
              l_start_date := okc_time_util_pub.get_enddate(p_ac_rec_in.start_date,
                                                            oks_bp_rec.offset_period,
                                                            oks_bp_rec.offset_duration);
                 
              IF oks_bp_rec.offset_duration > 0 THEN
                 l_start_date := l_start_date + 1;
              END IF;
                 
              IF NOT l_start_date > p_ac_rec_in.end_date THEN
                 g_start_date := l_start_date;
                 g_end_date   := p_ac_rec_in.end_date;
              ELSE
                 g_start_date := p_ac_rec_in.end_date;
                 g_end_date   := p_ac_rec_in.end_date;
              END IF;
           ELSE
              g_start_date := p_ac_rec_in.start_date;
              g_end_date   := p_ac_rec_in.end_date;
           END IF;
              
           -- Create Contract Line for the (Business Process) of Actual Coverage
           init_clev(l_clev_tbl_in);
           l_clev_tbl_in(1).dnz_chr_id := g_chr_id;
           l_clev_tbl_in(1).cle_id := c_cle_id;
           l_clev_tbl_in(1).chr_id := NULL;
           l_clev_tbl_in(1).sfwt_flag := linedet_rec1.sfwt_flag;
           l_clev_tbl_in(1).lse_id := l_parent_lse_id + 2; -- LineDet_Rec1.lse_id;
           l_clev_tbl_in(1).display_sequence := linedet_rec1.display_sequence;
           l_clev_tbl_in(1).NAME := linedet_rec1.NAME;
           l_clev_tbl_in(1).exception_yn := linedet_rec1.exception_yn;
           l_clev_tbl_in(1).start_date := g_start_date;
           l_clev_tbl_in(1).end_date := g_end_date;
           l_clev_tbl_in(1).sts_code := getstatus(l_service_line_id);
           l_clev_tbl_in(1).currency_code := getcurrency(l_service_line_id);
           l_clev_tbl_in(1).attribute_category := linedet_rec1.attribute_category;
           l_clev_tbl_in(1).attribute1 := linedet_rec1.attribute1;
           l_clev_tbl_in(1).attribute2 := linedet_rec1.attribute2;
           l_clev_tbl_in(1).attribute3 := linedet_rec1.attribute3;
           l_clev_tbl_in(1).attribute4 := linedet_rec1.attribute4;
           l_clev_tbl_in(1).attribute5 := linedet_rec1.attribute5;
           l_clev_tbl_in(1).attribute6 := linedet_rec1.attribute6;
           l_clev_tbl_in(1).attribute7 := linedet_rec1.attribute7;
           l_clev_tbl_in(1).attribute8 := linedet_rec1.attribute8;
           l_clev_tbl_in(1).attribute9 := linedet_rec1.attribute9;
           l_clev_tbl_in(1).attribute10 := linedet_rec1.attribute10;
           l_clev_tbl_in(1).attribute11 := linedet_rec1.attribute11;
           l_clev_tbl_in(1).attribute12 := linedet_rec1.attribute12;
           l_clev_tbl_in(1).attribute13 := linedet_rec1.attribute13;
           l_clev_tbl_in(1).attribute14 := linedet_rec1.attribute14;
           l_clev_tbl_in(1).attribute15 := linedet_rec1.attribute15;
           l_clev_tbl_in(1).price_list_id := linedet_rec1.price_list_id;
              
           okc_contract_pub.create_contract_line(p_api_version       => l_api_version,
                                                 p_init_msg_list     => l_init_msg_list,
                                                 x_return_status     => l_return_status,
                                                 x_msg_count         => l_msg_count,
                                                 x_msg_data          => l_msg_data,
                                                 p_restricted_update => p_restricted_update,
                                                 p_clev_tbl          => l_clev_tbl_in,
                                                 x_clev_tbl          => l_clev_tbl_out);
              
           IF NOT l_return_status = okc_api.g_ret_sts_success THEN
              RAISE g_exception_halt_validation;
           ELSE
              txg_cle_id := l_clev_tbl_out(1).id;
           END IF;
              
           FOR itemdet_rec IN cur_itemdet(tmp_txg_cle_id) LOOP
              --L3
              --  Create a Contract ITEM FOR BUSINESS PROCESS (ACTUAL COVERAGE)
              init_cimv(l_cimv_tbl_in);
              l_cimv_tbl_in(1).cle_id := txg_cle_id;
              l_cimv_tbl_in(1).chr_id := NULL;
              l_cimv_tbl_in(1).cle_id_for := NULL;
              l_cimv_tbl_in(1).object1_id1 := itemdet_rec.object1_id1;
              l_cimv_tbl_in(1).object1_id2 := itemdet_rec.object1_id2;
              l_cimv_tbl_in(1).jtot_object1_code := itemdet_rec.jtot_object1_code;
              l_cimv_tbl_in(1).exception_yn := itemdet_rec.exception_yn;
              l_cimv_tbl_in(1).number_of_items := itemdet_rec.number_of_items;
              l_cimv_tbl_in(1).dnz_chr_id := g_chr_id;
                 
              okc_contract_item_pub.create_contract_item(p_api_version   => l_api_version,
                                                         p_init_msg_list => l_init_msg_list,
                                                         x_return_status => l_return_status,
                                                         x_msg_count     => l_msg_count,
                                                         x_msg_data      => l_msg_data,
                                                         p_cimv_tbl      => l_cimv_tbl_in,
                                                         x_cimv_tbl      => l_cimv_tbl_out);
                 
              IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                 RAISE g_exception_halt_validation;
              END IF;
           END LOOP;
              
           -- Create record in OKS_K_LINES
              
           init_oks_k_line(l_klnv_tbl_in);
              
           l_klnv_tbl_in(1).cle_id := txg_cle_id;
           l_klnv_tbl_in(1).dnz_chr_id := g_chr_id;
           l_klnv_tbl_in(1).discount_list := oks_bp_rec.discount_list;
           l_klnv_tbl_in(1).offset_duration := oks_bp_rec.offset_duration;
           l_klnv_tbl_in(1).offset_period := oks_bp_rec.offset_period;
           l_klnv_tbl_in(1).allow_bt_discount := oks_bp_rec.allow_bt_discount;
           l_klnv_tbl_in(1).apply_default_timezone := oks_bp_rec.apply_default_timezone;
           l_klnv_tbl_in(1).sfwt_flag := oks_bp_rec.sfwt_flag;
           l_klnv_tbl_in(1).object_version_number := 1; --oks_cov_rec.object_version_number;
           l_klnv_tbl_in(1).security_group_id := oks_bp_rec.security_group_id;
              
           oks_contract_line_pub.create_line(p_api_version   => l_api_version,
                                             p_init_msg_list => l_init_msg_list,
                                             x_return_status => l_return_status,
                                             x_msg_count     => l_msg_count,
                                             x_msg_data      => l_msg_data,
                                             p_klnv_tbl      => l_klnv_tbl_in,
                                             x_klnv_tbl      => l_klnv_tbl_out,
                                             p_validate_yn   => 'N');
              
           IF NOT l_return_status = okc_api.g_ret_sts_success THEN
              RAISE g_exception_halt_validation;
           END IF;
           l_klnv_tbl_in.DELETE;
           -- Create Cover Time Rule For BUS PROC FOR ACTUAL COVERAGE
              
           FOR cov_tz_rec IN get_cov_timezones(tmp_txg_cle_id) LOOP
                 
              init_oks_timezone_line(l_covtz_tbl_in);
                 
              l_covtz_tbl_in(1).cle_id := txg_cle_id;
              l_covtz_tbl_in(1).default_yn := cov_tz_rec.default_yn;
              l_covtz_tbl_in(1).timezone_id := cov_tz_rec.timezone_id;
              l_covtz_tbl_in(1).dnz_chr_id := g_chr_id;
              oks_ctz_pvt.insert_row(p_api_version                  => l_api_version,
                                     p_init_msg_list                => l_init_msg_list,
                                     x_return_status                => l_return_status,
                                     x_msg_count                    => l_msg_count,
                                     x_msg_data                     => l_msg_data,
                                     p_oks_coverage_timezones_v_tbl => l_covtz_tbl_in,
                                     x_oks_coverage_timezones_v_tbl => l_covtz_tbl_out);
                 
              IF (g_debug_enabled = 'Y') THEN
                 okc_debug.log('After OKS_CTZ_PVT insert_row' ||
                               l_return_status,
                               2);
              END IF;
                 
              IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                 RAISE g_exception_halt_validation;
              END IF;
                 
              covtim_ctr := 0;
                 
              init_oks_cover_time_line(l_covtim_tbl_in);
                 
              FOR cov_times_rec IN get_cov_times(cov_tz_rec.id) LOOP
                 covtim_ctr := covtim_ctr + 1;
                 l_covtim_tbl_in(covtim_ctr).dnz_chr_id := g_chr_id;
                 l_covtim_tbl_in(covtim_ctr).cov_tze_line_id := l_covtz_tbl_out(1).id;
                 l_covtim_tbl_in(covtim_ctr).start_hour := cov_times_rec.start_hour;
                 l_covtim_tbl_in(covtim_ctr).start_minute := cov_times_rec.start_minute;
                 l_covtim_tbl_in(covtim_ctr).end_hour := cov_times_rec.end_hour;
                 l_covtim_tbl_in(covtim_ctr).end_minute := cov_times_rec.end_minute;
                 l_covtim_tbl_in(covtim_ctr).monday_yn := cov_times_rec.monday_yn;
                 l_covtim_tbl_in(covtim_ctr).tuesday_yn := cov_times_rec.tuesday_yn;
                 l_covtim_tbl_in(covtim_ctr).wednesday_yn := cov_times_rec.wednesday_yn;
                 l_covtim_tbl_in(covtim_ctr).thursday_yn := cov_times_rec.thursday_yn;
                 l_covtim_tbl_in(covtim_ctr).friday_yn := cov_times_rec.friday_yn;
                 l_covtim_tbl_in(covtim_ctr).saturday_yn := cov_times_rec.saturday_yn;
                 l_covtim_tbl_in(covtim_ctr).sunday_yn := cov_times_rec.sunday_yn;
                 l_covtim_tbl_in(covtim_ctr).security_group_id := oks_bp_rec.security_group_id;
                 l_covtim_tbl_in(covtim_ctr).program_application_id := NULL;
                 l_covtim_tbl_in(covtim_ctr).program_id := NULL;
                 l_covtim_tbl_in(covtim_ctr).program_update_date := NULL;
                 l_covtim_tbl_in(covtim_ctr).request_id := NULL;
              END LOOP;
                 
              oks_cvt_pvt.insert_row(p_api_version              => l_api_version,
                                     p_init_msg_list            => l_init_msg_list,
                                     x_return_status            => l_return_status,
                                     x_msg_count                => l_msg_count,
                                     x_msg_data                 => l_msg_data,
                                     p_oks_coverage_times_v_tbl => l_covtim_tbl_in,
                                     x_oks_coverage_times_v_tbl => l_covtim_tbl_out);
           END LOOP;
              
           IF (g_debug_enabled = 'Y') THEN
              okc_debug.log('After OKS_CVT_PVT insert_row' ||
                            l_return_status,
                            2);
           END IF;
              
           IF NOT l_return_status = okc_api.g_ret_sts_success THEN
              RAISE g_exception_halt_validation;
           END IF;
        END LOOP; -- End loop for OKS_BP_REC
           
        -- Done Business Process
           
        -- For all Reaction Times in Template
        FOR tmp_crt_rec IN cur_childline1(tmp_txg_cle_id,
                                          (tmp_lse_id + 2)) LOOP
           tmp_crt_cle_id := tmp_crt_rec.id;
              
           OPEN cur_linedet3(tmp_crt_cle_id);
           FETCH cur_linedet3
              INTO linedet_rec3;
           CLOSE cur_linedet3;
              
           -- Create same for Actual Coverage
           init_clev(l_clev_tbl_in);
           l_clev_tbl_in(1).cle_id := txg_cle_id;
           l_clev_tbl_in(1).chr_id := NULL;
           l_clev_tbl_in(1).dnz_chr_id := g_chr_id;
           l_clev_tbl_in(1).sfwt_flag := linedet_rec3.sfwt_flag;
           l_clev_tbl_in(1).lse_id := l_parent_lse_id + 3; -- LineDet_Rec3.lse_id;
           l_clev_tbl_in(1).start_date := g_start_date;
           l_clev_tbl_in(1).end_date := g_end_date;
           l_clev_tbl_in(1).sts_code := getstatus(l_service_line_id);
           l_clev_tbl_in(1).currency_code := getcurrency(l_service_line_id);
           l_clev_tbl_in(1).display_sequence := linedet_rec3.display_sequence;
           l_clev_tbl_in(1).item_description := linedet_rec3.item_description;
           l_clev_tbl_in(1).NAME := linedet_rec3.NAME;
           l_clev_tbl_in(1).exception_yn := linedet_rec3.exception_yn;
           l_clev_tbl_in(1).attribute_category := linedet_rec3.attribute_category;
           l_clev_tbl_in(1).attribute1 := linedet_rec3.attribute1;
           l_clev_tbl_in(1).attribute2 := linedet_rec3.attribute2;
           l_clev_tbl_in(1).attribute3 := linedet_rec3.attribute3;
           l_clev_tbl_in(1).attribute4 := linedet_rec3.attribute4;
           l_clev_tbl_in(1).attribute5 := linedet_rec3.attribute5;
           l_clev_tbl_in(1).attribute6 := linedet_rec3.attribute6;
           l_clev_tbl_in(1).attribute7 := linedet_rec3.attribute7;
           l_clev_tbl_in(1).attribute8 := linedet_rec3.attribute8;
           l_clev_tbl_in(1).attribute9 := linedet_rec3.attribute9;
           l_clev_tbl_in(1).attribute10 := linedet_rec3.attribute10;
           l_clev_tbl_in(1).attribute11 := linedet_rec3.attribute11;
           l_clev_tbl_in(1).attribute12 := linedet_rec3.attribute12;
           l_clev_tbl_in(1).attribute13 := linedet_rec3.attribute13;
           l_clev_tbl_in(1).attribute14 := linedet_rec3.attribute14;
           l_clev_tbl_in(1).attribute15 := linedet_rec3.attribute15;
              
           okc_contract_pub.create_contract_line(p_api_version       => l_api_version,
                                                 p_init_msg_list     => l_init_msg_list,
                                                 x_return_status     => l_return_status,
                                                 x_msg_count         => l_msg_count,
                                                 x_msg_data          => l_msg_data,
                                                 p_restricted_update => p_restricted_update,
                                                 p_clev_tbl          => l_clev_tbl_in,
                                                 x_clev_tbl          => l_clev_tbl_out);
              
           IF NOT l_return_status = okc_api.g_ret_sts_success THEN
              RAISE g_exception_halt_validation;
           ELSE
              crt_cle_id := l_clev_tbl_out(1).id;
           END IF;
              
           -- Create record in OKS_K_LINES
              
           FOR oks_react_rec IN cur_get_oks_line(tmp_crt_cle_id) LOOP
                 
              init_oks_k_line(l_klnv_tbl_in);
                 
              l_klnv_tbl_in(1).cle_id := crt_cle_id;
              l_klnv_tbl_in(1).dnz_chr_id := g_chr_id;
              l_klnv_tbl_in(1).react_time_name := oks_react_rec.react_time_name;
              l_klnv_tbl_in(1).incident_severity_id := oks_react_rec.incident_severity_id;
              l_klnv_tbl_in(1).pdf_id := oks_react_rec.pdf_id;
              l_klnv_tbl_in(1).work_thru_yn := oks_react_rec.work_thru_yn;
              l_klnv_tbl_in(1).react_active_yn := oks_react_rec.react_active_yn;
              l_klnv_tbl_in(1).sfwt_flag := oks_react_rec.sfwt_flag;
              l_klnv_tbl_in(1).object_version_number := 1; --oks_cov_rec.object_version_number;
              l_klnv_tbl_in(1).security_group_id := oks_react_rec.security_group_id;
                 
              oks_contract_line_pub.create_line(p_api_version   => l_api_version,
                                                p_init_msg_list => l_init_msg_list,
                                                x_return_status => l_return_status,
                                                x_msg_count     => l_msg_count,
                                                x_msg_data      => l_msg_data,
                                                p_klnv_tbl      => l_klnv_tbl_in,
                                                x_klnv_tbl      => l_klnv_tbl_out,
                                                p_validate_yn   => 'N');
                 
              IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                 RAISE g_exception_halt_validation;
              END IF;
              l_rt_cle_id := l_klnv_tbl_out(1).id;
           END LOOP; -- end loop for oks_react_rec
              
           FOR act_type_rec IN cur_get_action_types(tmp_crt_cle_id) LOOP
                 
              init_oks_act_type(l_act_type_tbl_in);
                 
              l_act_type_line_id := act_type_rec.id;
                 
              l_act_type_tbl_in(1).cle_id := crt_cle_id; --l_rt_cle_id ;
              l_act_type_tbl_in(1).dnz_chr_id := g_chr_id;
              l_act_type_tbl_in(1).action_type_code := act_type_rec.action_type_code;
                 
              oks_act_pvt.insert_row(p_api_version                 => l_api_version,
                                     p_init_msg_list               => l_init_msg_list,
                                     x_return_status               => l_return_status,
                                     x_msg_count                   => l_msg_count,
                                     x_msg_data                    => l_msg_data,
                                     p_oks_action_time_types_v_tbl => l_act_type_tbl_in,
                                     x_oks_action_time_types_v_tbl => l_act_type_tbl_out);
                 
              IF (g_debug_enabled = 'Y') THEN
                 okc_debug.log('After OKS_ACT_PVT INSERT_ROW' ||
                               l_return_status,
                               2);
              END IF;
                 
              IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                 RAISE g_exception_halt_validation;
              END IF;
              l_cov_act_type_line_id := l_act_type_tbl_out(1).id;
                 
              act_time_ctr := 0;
                 
              FOR act_time_rec IN cur_get_action_times(l_act_type_line_id) LOOP
                 act_time_ctr := act_time_ctr + 1;
                    
                 init_oks_act_time(l_act_time_tbl_in);
                 l_act_time_tbl_in(act_time_ctr).cov_action_type_id := l_cov_act_type_line_id;
                 l_act_time_tbl_in(act_time_ctr).cle_id := crt_cle_id; --l_rt_cle_id;
                 l_act_time_tbl_in(act_time_ctr).dnz_chr_id := g_chr_id;
                 l_act_time_tbl_in(act_time_ctr).uom_code := act_time_rec.uom_code;
                 l_act_time_tbl_in(act_time_ctr).sun_duration := act_time_rec.sun_duration;
                 l_act_time_tbl_in(act_time_ctr).mon_duration := act_time_rec.mon_duration;
                 l_act_time_tbl_in(act_time_ctr).tue_duration := act_time_rec.tue_duration;
                 l_act_time_tbl_in(act_time_ctr).wed_duration := act_time_rec.wed_duration;
                 l_act_time_tbl_in(act_time_ctr).thu_duration := act_time_rec.thu_duration;
                 l_act_time_tbl_in(act_time_ctr).fri_duration := act_time_rec.fri_duration;
                 l_act_time_tbl_in(act_time_ctr).sat_duration := act_time_rec.sat_duration;
              END LOOP; -- END LOOP FOR ACT_TIME_REC
                 
              oks_acm_pvt.insert_row(p_api_version            => l_api_version,
                                     p_init_msg_list          => l_init_msg_list,
                                     x_return_status          => l_return_status,
                                     x_msg_count              => l_msg_count,
                                     x_msg_data               => l_msg_data,
                                     p_oks_action_times_v_tbl => l_act_time_tbl_in,
                                     x_oks_action_times_v_tbl => l_act_time_tbl_out);
                 
              IF (g_debug_enabled = 'Y') THEN
                 okc_debug.log('After OKS_ACM_PVT insert_row' ||
                               l_return_status,
                               2);
              END IF;
                 
              IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                 RAISE g_exception_halt_validation;
              END IF;
           END LOOP; -- END LOOP FOR ACT_TYPE_REC
        END LOOP;
           
        -- Preferred Engineers
           
        OPEN cur_ptrldet(tmp_txg_cle_id, 'VENDOR');
        FETCH cur_ptrldet
           INTO ptrldet_rec;
        IF NOT cur_ptrldet%FOUND THEN
           tmp_cpl_id := NULL;
        ELSE
           tmp_cpl_id := ptrldet_rec.id;
        END IF;
        CLOSE cur_ptrldet;
           
        -- If it's there in Template, create it for Actual Coverage
        IF NOT tmp_cpl_id IS NULL THEN
           --Init_Cplv(l_cplv_tbl_in);
           l_cplv_tbl_in(1).sfwt_flag := 'N';
           l_cplv_tbl_in(1).cle_id := txg_cle_id;
           l_cplv_tbl_in(1).dnz_chr_id := g_chr_id;
           l_cplv_tbl_in(1).rle_code := l_rle_code; --'VENDOR';
           -- l_cplv_tbl_in(1).object1_id1       :=PtrlDet_Rec.object1_id1;
           --  l_cplv_tbl_in(1).object1_id2       :=PtrlDet_Rec.object1_id2;
           --  l_cplv_tbl_in(1).jtot_object1_code :=PtrlDet_Rec.jtot_object1_code;
              
           -- Fix for Bug:4703431. Modified by Jvorugan
           OPEN cur_get_org_id(g_chr_id);
           FETCH cur_get_org_id
              INTO l_object_id;
           CLOSE cur_get_org_id;
              
           l_cplv_tbl_in(1).object1_id1 := l_object_id;
           l_cplv_tbl_in(1).object1_id2 := '#';
           l_cplv_tbl_in(1).jtot_object1_code := 'OKX_OPERUNIT';
           -- End of changes for  Bug:4703431.
              
           okc_contract_party_pub.create_k_party_role(p_api_version   => l_api_version,
                                                      p_init_msg_list => l_init_msg_list,
                                                      x_return_status => l_return_status,
                                                      x_msg_count     => l_msg_count,
                                                      x_msg_data      => l_msg_data,
                                                      p_cplv_tbl      => l_cplv_tbl_in,
                                                      x_cplv_tbl      => l_cplv_tbl_out);
              
           IF NOT l_return_status = okc_api.g_ret_sts_success THEN
              RAISE g_exception_halt_validation;
           ELSE
              l_cpl_id := l_cplv_tbl_out(1).id;
           END IF;
              
           FOR contactdet_rec IN cur_contactdet(tmp_cpl_id) LOOP
              -- To Create Contact
              init_ctcv(l_ctcv_tbl_in);
              l_ctcv_tbl_in(1).cpl_id := l_cpl_id;
              l_ctcv_tbl_in(1).cro_code := contactdet_rec.cro_code;
              l_ctcv_tbl_in(1).dnz_chr_id := g_chr_id;
              l_ctcv_tbl_in(1).contact_sequence := contactdet_rec.contact_sequence;
              l_ctcv_tbl_in(1).object1_id1 := contactdet_rec.object1_id1;
              l_ctcv_tbl_in(1).object1_id2 := contactdet_rec.object1_id2;
              l_ctcv_tbl_in(1).jtot_object1_code := contactdet_rec.jtot_object1_code;
              l_ctcv_tbl_in(1).resource_class := contactdet_rec.resource_class;
                 
              okc_contract_party_pub.create_contact(p_api_version   => l_api_version,
                                                    p_init_msg_list => l_init_msg_list,
                                                    x_return_status => l_return_status,
                                                    x_msg_count     => l_msg_count,
                                                    x_msg_data      => l_msg_data,
                                                    p_ctcv_tbl      => l_ctcv_tbl_in,
                                                    x_ctcv_tbl      => l_ctcv_tbl_out);
                 
              IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                 RAISE g_exception_halt_validation;
              ELSE
                 l_contact_id := l_ctcv_tbl_out(1).id;
              END IF;
           END LOOP;
        END IF;
        -- Done Preferred Engineer
           
        -- For all the Bill Types in Template, create the same for ACTUAL COVERAGE
           
        IF l_parent_lse_id = 14 THEN
           l_bt_lse_id := 59;
        ELSE
           l_bt_lse_id := tmp_lse_id + 3;
        END IF;
           
        -- FOR tmp_bt_Rec IN Cur_ChildLine_bt(tmp_txg_cle_Id,tmp_lse_id+3)
        FOR tmp_bt_rec IN cur_childline_bt(tmp_txg_cle_id, l_bt_lse_id) LOOP
           tmp_bt_cle_id := tmp_bt_rec.id;
              
           -- For Warranty
           -- commented for NEW  ER ; warranty to be opened up for bill types and bill rates
           /*
               IF l_Parent_Lse_Id =14
               THEN
                 tmp_bt_cle_Id:=NULL;
               END IF;
           */
              
           IF NOT tmp_bt_cle_id IS NULL THEN
              OPEN cur_linedet3(tmp_bt_cle_id);
              FETCH cur_linedet3
                 INTO linedet_rec3;
              CLOSE cur_linedet3;
                 
              init_clev(l_clev_tbl_in);
              l_clev_tbl_in(1).cle_id := txg_cle_id;
              l_clev_tbl_in(1).chr_id := NULL;
              l_clev_tbl_in(1).dnz_chr_id := g_chr_id;
              l_clev_tbl_in(1).sfwt_flag := linedet_rec3.sfwt_flag;
                 
              -- changed for NEW  ER ; warranty to be opened up for bill types and bill rates
                 
              IF l_parent_lse_id IN (1, 19) THEN
                 l_clev_tbl_in(1).lse_id := l_parent_lse_id + 4; --LineDet_Rec3.lse_id ;
              ELSIF l_parent_lse_id IN (14) THEN
                 l_clev_tbl_in(1).lse_id := 59; --l_Parent_lse_Id+4;--LineDet_Rec3.lse_id ;
              END IF;
                 
              l_clev_tbl_in(1).start_date := g_start_date;
              l_clev_tbl_in(1).end_date := g_end_date;
              l_clev_tbl_in(1).sts_code := getstatus(l_service_line_id);
              l_clev_tbl_in(1).currency_code := getcurrency(l_service_line_id);
              l_clev_tbl_in(1).display_sequence := linedet_rec3.display_sequence;
              l_clev_tbl_in(1).item_description := linedet_rec3.item_description;
              l_clev_tbl_in(1).NAME := linedet_rec3.NAME;
              l_clev_tbl_in(1).exception_yn := linedet_rec3.exception_yn;
              l_clev_tbl_in(1).attribute_category := linedet_rec3.attribute_category;
              l_clev_tbl_in(1).attribute1 := linedet_rec3.attribute1;
              l_clev_tbl_in(1).attribute2 := linedet_rec3.attribute2;
              l_clev_tbl_in(1).attribute3 := linedet_rec3.attribute3;
              l_clev_tbl_in(1).attribute4 := linedet_rec3.attribute4;
              l_clev_tbl_in(1).attribute5 := linedet_rec3.attribute5;
              l_clev_tbl_in(1).attribute6 := linedet_rec3.attribute6;
              l_clev_tbl_in(1).attribute7 := linedet_rec3.attribute7;
              l_clev_tbl_in(1).attribute8 := linedet_rec3.attribute8;
              l_clev_tbl_in(1).attribute9 := linedet_rec3.attribute9;
              l_clev_tbl_in(1).attribute10 := linedet_rec3.attribute10;
              l_clev_tbl_in(1).attribute11 := linedet_rec3.attribute11;
              l_clev_tbl_in(1).attribute12 := linedet_rec3.attribute12;
              l_clev_tbl_in(1).attribute13 := linedet_rec3.attribute13;
              l_clev_tbl_in(1).attribute14 := linedet_rec3.attribute14;
              l_clev_tbl_in(1).attribute15 := linedet_rec3.attribute15;
                 
              okc_contract_pub.create_contract_line(p_api_version       => l_api_version,
                                                    p_init_msg_list     => l_init_msg_list,
                                                    x_return_status     => l_return_status,
                                                    x_msg_count         => l_msg_count,
                                                    x_msg_data          => l_msg_data,
                                                    p_restricted_update => p_restricted_update,
                                                    p_clev_tbl          => l_clev_tbl_in,
                                                    x_clev_tbl          => l_clev_tbl_out);
                 
              IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                 RAISE g_exception_halt_validation;
              ELSE
                 bt_cle_id := l_clev_tbl_out(1).id;
              END IF;
              -- Create record in OKS_K_LINES
              FOR oks_bt_rec IN cur_get_oks_line(tmp_bt_cle_id) LOOP
                 init_oks_k_line(l_klnv_tbl_in);
                 l_klnv_tbl_in(1).cle_id := bt_cle_id;
                 l_klnv_tbl_in(1).dnz_chr_id := g_chr_id;
                 l_klnv_tbl_in(1).limit_uom_quantified := oks_bt_rec.limit_uom_quantified;
                 l_klnv_tbl_in(1).discount_amount := oks_bt_rec.discount_amount;
                 l_klnv_tbl_in(1).discount_percent := oks_bt_rec.discount_percent;
                 l_klnv_tbl_in(1).work_thru_yn := oks_bt_rec.work_thru_yn;
                 l_klnv_tbl_in(1).react_active_yn := oks_bt_rec.react_active_yn;
                 l_klnv_tbl_in(1).sfwt_flag := oks_bt_rec.sfwt_flag;
                 l_klnv_tbl_in(1).object_version_number := 1; --oks_cov_rec.object_version_number;
                 l_klnv_tbl_in(1).security_group_id := oks_bt_rec.security_group_id;
                    
                 oks_contract_line_pub.create_line(p_api_version   => l_api_version,
                                                   p_init_msg_list => l_init_msg_list,
                                                   x_return_status => l_return_status,
                                                   x_msg_count     => l_msg_count,
                                                   x_msg_data      => l_msg_data,
                                                   p_klnv_tbl      => l_klnv_tbl_in,
                                                   x_klnv_tbl      => l_klnv_tbl_out,
                                                   p_validate_yn   => 'N');
                    
                 IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                    RAISE g_exception_halt_validation;
                 END IF;
              END LOOP;
              -- For all the Contract Item for BILL TYPE in TEMPLATE, create the same for Actual Coverage
              FOR itemdet_rec IN cur_itemdet(tmp_bt_cle_id) LOOP
                 --L3
                 init_cimv(l_cimv_tbl_in);
                 l_cimv_tbl_in(1).cle_id := bt_cle_id;
                 l_cimv_tbl_in(1).chr_id := NULL;
                 l_cimv_tbl_in(1).cle_id_for := NULL;
                 l_cimv_tbl_in(1).object1_id1 := itemdet_rec.object1_id1;
                 l_cimv_tbl_in(1).object1_id2 := itemdet_rec.object1_id2;
                 l_cimv_tbl_in(1).jtot_object1_code := itemdet_rec.jtot_object1_code;
                 l_cimv_tbl_in(1).exception_yn := itemdet_rec.exception_yn;
                 l_cimv_tbl_in(1).number_of_items := itemdet_rec.number_of_items;
                 l_cimv_tbl_in(1).dnz_chr_id := g_chr_id;
                    
                 okc_contract_item_pub.create_contract_item(p_api_version   => l_api_version,
                                                            p_init_msg_list => l_init_msg_list,
                                                            x_return_status => l_return_status,
                                                            x_msg_count     => l_msg_count,
                                                            x_msg_data      => l_msg_data,
                                                            p_cimv_tbl      => l_cimv_tbl_in,
                                                            x_cimv_tbl      => l_cimv_tbl_out);
                    
                 IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                    RAISE g_exception_halt_validation;
                 END IF;
              END LOOP;
                 
              -- For all the Bill Rate in Template, create the same in Actual
                 
              IF l_parent_lse_id = 14 THEN
                 l_br_lse_id := 60;
              ELSE
                 l_br_lse_id := tmp_lse_id + 4;
              END IF;
                 
              --      FOR tmp_br_Rec IN Cur_ChildLine_br(tmp_bt_cle_id,tmp_lse_id+4)
              FOR tmp_br_rec IN cur_childline_br(tmp_bt_cle_id,
                                                 l_br_lse_id) LOOP
                 tmp_br_cle_id := tmp_br_rec.id;
                 IF NOT tmp_br_cle_id IS NULL THEN
                    init_clev(l_clev_tbl_in);
                    l_clev_tbl_in(1).cle_id := bt_cle_id;
                    l_clev_tbl_in(1).chr_id := NULL;
                    l_clev_tbl_in(1).dnz_chr_id := g_chr_id;
                    l_clev_tbl_in(1).sfwt_flag := linedet_rec.sfwt_flag;
                       
                    -- changed for NEW  ER ; warranty to be opened up for bill types and bill rates
                       
                    IF l_parent_lse_id IN (1, 19) THEN
                       l_clev_tbl_in(1).lse_id := l_parent_lse_id + 5; -- tmp_br_rec.lse_id;
                    ELSIF l_parent_lse_id IN (14) THEN
                       l_clev_tbl_in(1).lse_id := 60; -- tmp_br_rec.lse_id;
                    END IF;
                       
                    l_clev_tbl_in(1).start_date := g_start_date;
                    l_clev_tbl_in(1).end_date := g_end_date;
                    l_clev_tbl_in(1).sts_code := getstatus(l_service_line_id);
                    l_clev_tbl_in(1).currency_code := getcurrency(l_service_line_id);
                    l_clev_tbl_in(1).display_sequence := linedet_rec.display_sequence;
                    l_clev_tbl_in(1).item_description := linedet_rec.item_description;
                    l_clev_tbl_in(1).NAME := linedet_rec.NAME;
                    l_clev_tbl_in(1).exception_yn := tmp_br_rec.exception_yn;
                    l_clev_tbl_in(1).attribute_category := tmp_br_rec.attribute_category;
                    l_clev_tbl_in(1).attribute1 := tmp_br_rec.attribute1;
                    l_clev_tbl_in(1).attribute2 := tmp_br_rec.attribute2;
                    l_clev_tbl_in(1).attribute3 := tmp_br_rec.attribute3;
                    l_clev_tbl_in(1).attribute4 := tmp_br_rec.attribute4;
                    l_clev_tbl_in(1).attribute5 := tmp_br_rec.attribute5;
                    l_clev_tbl_in(1).attribute6 := tmp_br_rec.attribute6;
                    l_clev_tbl_in(1).attribute7 := tmp_br_rec.attribute7;
                    l_clev_tbl_in(1).attribute8 := tmp_br_rec.attribute8;
                    l_clev_tbl_in(1).attribute9 := tmp_br_rec.attribute9;
                    l_clev_tbl_in(1).attribute10 := tmp_br_rec.attribute10;
                    l_clev_tbl_in(1).attribute11 := tmp_br_rec.attribute11;
                    l_clev_tbl_in(1).attribute12 := tmp_br_rec.attribute12;
                    l_clev_tbl_in(1).attribute13 := tmp_br_rec.attribute13;
                    l_clev_tbl_in(1).attribute14 := tmp_br_rec.attribute14;
                    l_clev_tbl_in(1).attribute15 := tmp_br_rec.attribute15;
                       
                    okc_contract_pub.create_contract_line(p_api_version       => l_api_version,
                                                          p_init_msg_list     => l_init_msg_list,
                                                          x_return_status     => l_return_status,
                                                          x_msg_count         => l_msg_count,
                                                          x_msg_data          => l_msg_data,
                                                          p_restricted_update => p_restricted_update,
                                                          p_clev_tbl          => l_clev_tbl_in,
                                                          x_clev_tbl          => l_clev_tbl_out);
                       
                    IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                       RAISE g_exception_halt_validation;
                    ELSE
                       br_cle_id := l_clev_tbl_out(1).id;
                    END IF;
                       
                    FOR brs_rec IN cur_get_billrate_schedules(tmp_br_cle_id) LOOP
                          
                       init_bill_rate_line(l_bill_rate_tbl_in);
                          
                       l_bill_rate_tbl_in(1).cle_id := br_cle_id;
                       l_bill_rate_tbl_in(1).bt_cle_id := bt_cle_id;
                       l_bill_rate_tbl_in(1).dnz_chr_id := g_chr_id;
                       l_bill_rate_tbl_in(1).start_hour := brs_rec.start_hour;
                       l_bill_rate_tbl_in(1).start_minute := brs_rec.start_minute;
                       l_bill_rate_tbl_in(1).end_hour := brs_rec.end_hour;
                       l_bill_rate_tbl_in(1).end_minute := brs_rec.end_minute;
                       l_bill_rate_tbl_in(1).monday_flag := brs_rec.monday_flag;
                       l_bill_rate_tbl_in(1).tuesday_flag := brs_rec.tuesday_flag;
                       l_bill_rate_tbl_in(1).wednesday_flag := brs_rec.wednesday_flag;
                       l_bill_rate_tbl_in(1).thursday_flag := brs_rec.thursday_flag;
                       l_bill_rate_tbl_in(1).friday_flag := brs_rec.friday_flag;
                       l_bill_rate_tbl_in(1).saturday_flag := brs_rec.saturday_flag;
                       l_bill_rate_tbl_in(1).sunday_flag := brs_rec.sunday_flag;
                       l_bill_rate_tbl_in(1).object1_id1 := brs_rec.object1_id1;
                       l_bill_rate_tbl_in(1).object1_id2 := brs_rec.object1_id2;
                       l_bill_rate_tbl_in(1).bill_rate_code := brs_rec.bill_rate_code;
                       l_bill_rate_tbl_in(1).flat_rate := brs_rec.flat_rate;
                       l_bill_rate_tbl_in(1).uom := brs_rec.uom;
                       l_bill_rate_tbl_in(1).holiday_yn := brs_rec.holiday_yn;
                       l_bill_rate_tbl_in(1).percent_over_list_price := brs_rec.percent_over_list_price;
                       l_bill_rate_tbl_in(1).program_application_id := brs_rec.program_application_id;
                       l_bill_rate_tbl_in(1).program_id := brs_rec.program_id;
                       l_bill_rate_tbl_in(1).program_update_date := brs_rec.program_update_date;
                       l_bill_rate_tbl_in(1).request_id := brs_rec.request_id;
                       l_bill_rate_tbl_in(1).created_by := NULL;
                       l_bill_rate_tbl_in(1).creation_date := NULL;
                       l_bill_rate_tbl_in(1).last_updated_by := NULL;
                       l_bill_rate_tbl_in(1).last_update_date := NULL;
                       l_bill_rate_tbl_in(1).last_update_login := NULL;
                       l_bill_rate_tbl_in(1).security_group_id := brs_rec.security_group_id;
                       l_bill_rate_tbl_in(1).object_version_number := brs_rec.object_version_number;
                          
                       oks_brs_pvt.insert_row(p_api_version                  => l_api_version,
                                              p_init_msg_list                => l_init_msg_list,
                                              x_return_status                => l_return_status,
                                              x_msg_count                    => l_msg_count,
                                              x_msg_data                     => l_msg_data,
                                              p_oks_billrate_schedules_v_tbl => l_bill_rate_tbl_in,
                                              x_oks_billrate_schedules_v_tbl => x_bill_rate_tbl_out);
                          
                       IF (g_debug_enabled = 'Y') THEN
                          okc_debug.log('Exiting Create_Actual_Coverage',
                                        2);
                          okc_debug.reset_indentation;
                       END IF;
                          
                       IF NOT
                           l_return_status = okc_api.g_ret_sts_success THEN
                          RAISE g_exception_halt_validation;
                       END IF;
                    END LOOP;
                 END IF;
              END LOOP;
           END IF;
        END LOOP;
     END LOOP;
        
  END LOOP;
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.log('Exiting Create_Actual_Coverage', 2);
     okc_debug.reset_indentation;
  END IF;
     
  x_actual_coverage_id := c_cle_id;
  x_return_status      := l_return_status;
  x_msg_count          := l_msg_count;
  x_msg_data           := l_msg_data;
     
  EXCEPTION
  WHEN g_exception_halt_validation THEN
     x_return_status := l_return_status;
     /*    x_msg_count :=l_msg_count;
       x_msg_data:=l_msg_data;
       x_return_status := OKC_API.HANDLE_EXCEPTIONS
       (
         l_api_name,
         'Create_actual_coverage',
         'OKC_API.G_RET_STS_ERROR',
         x_msg_count,
         x_msg_data,
         '_PVT'
       );
     WHEN OKC_API.G_EXCEPTION_ERROR THEN
       x_msg_count :=l_msg_count;
       x_msg_data:=l_msg_data;
       x_return_status := OKC_API.HANDLE_EXCEPTIONS
       (
         l_api_name,
         'Create_actual_coverage',
         'OKC_API.G_RET_STS_ERROR',
         x_msg_count,
         x_msg_data,
         '_PVT'
       );
     WHEN OKC_API.G_EXCEPTION_UNEXPECTED_ERROR THEN
       x_msg_count :=l_msg_count;
       x_msg_data:=l_msg_data;
       x_return_status :=OKC_API.HANDLE_EXCEPTIONS
       (
         l_api_name,
         'Create_actual_coverage',
         'OKC_API.G_RET_STS_UNEXP_ERROR',
         x_msg_count,
         x_msg_data,
         '_PVT'
       );
       */
        
     IF (g_debug_enabled = 'Y') THEN
        okc_debug.log('Exiting Create_Actual_Coverage' ||
                      l_return_status,
                      2);
        okc_debug.reset_indentation;
     END IF;
        
  WHEN OTHERS THEN
     okc_api.set_message(p_app_name     => g_app_name,
                         p_msg_name     => g_unexpected_error,
                         p_token1       => g_sqlcode_token,
                         p_token1_value => SQLCODE,
                         p_token2       => g_sqlerrm_token,
                         p_token2_value => SQLERRM);
     -- notify caller of an error as UNEXPETED error
     x_return_status := okc_api.g_ret_sts_unexp_error;
     x_msg_count     := l_msg_count;
        
     IF (g_debug_enabled = 'Y') THEN
        okc_debug.log('Exiting Create_Actual_Coverage' || SQLERRM, 2);
        okc_debug.reset_indentation;
     END IF;
        
  END create_actual_coverage;

  ---------------------------------------------------------------------------
  -- PROCEDURE undo_header
  ---------------------------------------------------------------------------
  PROCEDURE undo_header(p_api_version   IN NUMBER,
                     p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                     x_return_status OUT NOCOPY VARCHAR2,
                     x_msg_count     OUT NOCOPY NUMBER,
                     x_msg_data      OUT NOCOPY VARCHAR2,
                     p_header_id     IN NUMBER) IS
     
  CURSOR cur_line(p_chr_id IN NUMBER) IS
     SELECT id FROM okc_k_lines_v WHERE chr_id = p_chr_id;
     
  CURSOR cur_gov(p_chr_id IN NUMBER) IS
     SELECT id
       FROM okc_governances_v
      WHERE dnz_chr_id = p_chr_id AND
            cle_id IS NULL;
     
  l_chrv_rec okc_contract_pub.chrv_rec_type;
  l_line_id  NUMBER;
  --
  l_api_version   CONSTANT NUMBER := 1.0;
  l_init_msg_list CONSTANT VARCHAR2(1) := 'T';
  l_return_status VARCHAR2(1);
  l_msg_count     NUMBER;
  l_msg_data      VARCHAR2(2000) := NULL;
  --l_msg_index_out NUMBER;
  l_api_name CONSTANT VARCHAR2(30) := 'UNDO Header';
  --
  l_gvev_tbl_in okc_contract_pub.gvev_tbl_type;
  e_error EXCEPTION;
  n       NUMBER;
  --m       NUMBER;
  v_index NUMBER;
  TYPE line_tbl_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
  l_line_tbl line_tbl_type;
  BEGIN
     
  IF p_header_id IS NULL THEN
     l_msg_data      := 'Header_id Can not be Null';
     l_return_status := okc_api.g_ret_sts_error;
     RAISE e_error;
  END IF;
  l_chrv_rec.id := p_header_id;
     
  n := 1;
  FOR line_rec IN cur_line(p_header_id) LOOP
     l_line_tbl(n) := line_rec.id;
     n := n + 1;
  END LOOP;
     
  n := 1;
  FOR gov_rec IN cur_gov(p_header_id) LOOP
     l_gvev_tbl_in(n).id := gov_rec.id;
     n := n + 1;
  END LOOP;
     
  IF NOT l_gvev_tbl_in.COUNT = 0 THEN
     okc_contract_pub.delete_governance(p_api_version   => l_api_version,
                                        p_init_msg_list => l_init_msg_list,
                                        x_return_status => l_return_status,
                                        x_msg_count     => l_msg_count,
                                        x_msg_data      => l_msg_data,
                                        p_gvev_tbl      => l_gvev_tbl_in);
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        l_msg_data := 'Error while deleting governance -' || l_msg_data;
        RETURN;
     END IF;
  END IF;
  IF NOT l_line_tbl.COUNT = 0 THEN
     v_index := l_line_tbl.COUNT;
     FOR v_index IN l_line_tbl.FIRST .. l_line_tbl.LAST LOOP
        l_line_id := l_line_tbl(v_index);
        undo_counters(p_kline_id      => l_line_id,
                      x_return_status => l_return_status,
                      x_msg_data      => l_msg_data);
        IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
           l_msg_data := 'Error while deleting Counters -' ||
                         l_msg_data;
           RETURN;
        END IF;
     END LOOP;
  END IF;
  okc_delete_contract_pub.delete_contract(p_api_version   => l_api_version,
                                          p_init_msg_list => l_init_msg_list,
                                          x_return_status => l_return_status,
                                          x_msg_count     => l_msg_count,
                                          x_msg_data      => l_msg_data,
                                          p_chrv_rec      => l_chrv_rec);
  IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
     l_msg_data := 'Error while deleting Header -' || l_msg_data;
     RETURN;
  END IF;
  x_return_status := l_return_status;
  EXCEPTION
  WHEN e_error THEN
     x_msg_count     := l_msg_count;
     x_msg_data      := l_msg_data;
     x_return_status := l_return_status;
        
     x_return_status := okc_api.handle_exceptions(l_api_name,
                                                  'Undo_Header',
                                                  'OKC_API.G_RET_STS_ERROR',
                                                  x_msg_count,
                                                  x_msg_data,
                                                  '_PVT');
  WHEN okc_api.g_exception_error THEN
     x_msg_count := l_msg_count;
     x_msg_data  := l_msg_data;
        
     x_return_status := okc_api.handle_exceptions(l_api_name,
                                                  'Undo_Header',
                                                  'OKC_API.G_RET_STS_ERROR',
                                                  x_msg_count,
                                                  x_msg_data,
                                                  '_PVT');
  WHEN okc_api.g_exception_unexpected_error THEN
     x_msg_count     := l_msg_count;
     x_msg_data      := l_msg_data;
     x_return_status := okc_api.handle_exceptions(l_api_name,
                                                  'Undo_Header',
                                                  'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                  x_msg_count,
                                                  x_msg_data,
                                                  '_PVT');
  WHEN OTHERS THEN
        
     okc_api.set_message(p_app_name     => g_app_name,
                         p_msg_name     => g_unexpected_error,
                         p_token1       => g_sqlcode_token,
                         p_token1_value => SQLCODE,
                         p_token2       => g_sqlerrm_token,
                         p_token2_value => SQLERRM);
     -- notify caller of an error as UNEXPETED error
     x_return_status := okc_api.g_ret_sts_unexp_error;
     x_msg_count     := l_msg_count;
  END undo_header;
  
  ---------------------------------------------------------------------------
  -- PROCEDURE undo_line
  ---------------------------------------------------------------------------
  PROCEDURE undo_line(p_api_version   IN NUMBER,
                   p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                   x_return_status OUT NOCOPY VARCHAR2,
                   x_msg_count     OUT NOCOPY NUMBER,
                   x_msg_data      OUT NOCOPY VARCHAR2,
                   p_line_id       IN NUMBER) IS
     
  --l_cov_cle_id NUMBER;
  --l_item_id    NUMBER;
  --l_contact_id NUMBER;
  --l_rgp_id     NUMBER;
  --l_rule_id    NUMBER;
  --l_cle_id     NUMBER;
  v_index      BINARY_INTEGER;
     
  g_app_name         CONSTANT VARCHAR2(3) := okc_api.g_app_name;
  g_required_value   CONSTANT VARCHAR2(200) := okc_api.g_required_value;
  g_col_name_token   CONSTANT VARCHAR2(200) := okc_api.g_col_name_token;
  g_unexpected_error CONSTANT VARCHAR2(200) := 'OKS_UNEXP_ERROR';
  g_sqlerrm_token    CONSTANT VARCHAR2(200) := 'SQLerrm';
  g_sqlcode_token    CONSTANT VARCHAR2(200) := 'SQLcode';
     
  CURSOR line_det_cur(p_cle_id IN NUMBER) IS
     SELECT id, start_date, lse_id
       FROM okc_k_lines_b
      WHERE id = p_cle_id;
     
  CURSOR child_cur(p_cle_id IN NUMBER) IS
     SELECT dnz_chr_id, id, lse_id
       FROM okc_k_lines_b
      WHERE cle_id = p_cle_id;
     
  CURSOR child_cur1(p_parent_id IN NUMBER) IS
     SELECT id, dnz_chr_id
       FROM okc_k_lines_b
      WHERE cle_id = p_parent_id;
     
  CURSOR child_cur2(p_parent_id IN NUMBER) IS
     SELECT id, dnz_chr_id
       FROM okc_k_lines_b
      WHERE cle_id = p_parent_id;
  CURSOR child_cur3(p_parent_id IN NUMBER) IS
     SELECT id, dnz_chr_id
       FROM okc_k_lines_b
      WHERE cle_id = p_parent_id;
  CURSOR child_cur4(p_parent_id IN NUMBER) IS
     SELECT id, dnz_chr_id
       FROM okc_k_lines_b
      WHERE cle_id = p_parent_id;
  CURSOR child_cur5(p_parent_id IN NUMBER) IS
     SELECT id, dnz_chr_id
       FROM okc_k_lines_b
      WHERE cle_id = p_parent_id;
     
  CURSOR item_cur(p_line_id IN NUMBER) IS
     SELECT id FROM okc_k_items WHERE cle_id = p_line_id;
     
  CURSOR rt_cur(p_rule_id IN NUMBER) IS
     SELECT tve_id FROM okc_react_intervals WHERE rul_id = p_rule_id;
     
  CURSOR kprl_cur(p_cle_id IN NUMBER) IS
     SELECT pr.id
       FROM okc_k_party_roles_b pr, okc_k_lines_v lv
      WHERE pr.cle_id = p_cle_id AND
            pr.cle_id = lv.id AND
            pr.dnz_chr_id = lv.dnz_chr_id;
     
  CURSOR contact_cur(p_cpl_id IN NUMBER) IS
     SELECT id FROM okc_contacts WHERE cpl_id = p_cpl_id;
     
  /*
   CURSOR TRule_Cur( P_Rgp_Id IN NUMBER,
                     P_Rule_Type IN Varchar2) IS
    SELECT ID FROM OKC_RULES_B
    WHERE  Rgp_Id=P_Rgp_Id
    AND    Rule_Information_category=P_rule_Type;
        
   CURSOR Rl_Cur(P_Rgp_Id IN NUMBER) IS
    SELECT ID FROM OKC_RULES_B
    WHERE  Rgp_Id=P_Rgp_Id;
        
   CURSOR Rgp_Cur(P_cle_Id IN NUMBER) IS
    SELECT ID FROM OKC_RULE_GROUPS_B
    WHERE  cle_Id=P_Cle_Id;
  */
     
  CURSOR relobj_cur(p_cle_id IN NUMBER) IS
     SELECT id FROM okc_k_rel_objs_v WHERE cle_id = p_cle_id;
     
  CURSOR orderdetails_cur(p_chr_id IN NUMBER, p_cle_id IN NUMBER) IS
     SELECT id
       FROM oks_k_order_details_v
      WHERE chr_id = p_chr_id AND
            cle_id = p_cle_id;
     
  CURSOR salescredits_cur(p_cle_id IN NUMBER) IS
     SELECT id FROM oks_k_sales_credits_v WHERE cle_id = p_cle_id;
     
  CURSOR ordercontacts_cur(p_cod_id IN NUMBER) IS
     SELECT id FROM oks_k_order_contacts_v WHERE cod_id = p_cod_id;
     
  --03/16/04 chkrishn removed for rules rearchitecture
  /*    CURSOR CUR_GET_SCH(p_cov_id IN NUMBER) IS
   SELECT ID FROM OKS_PM_SCHEDULES
   WHERE CLE_ID = p_cov_id;
        
  l_pm_schedules_v_tbl  OKS_PMS_PVT.oks_pm_schedules_v_tbl_type ;
  l_sch_index NUMBER := 0;*/
     
  CURSOR cur_get_brs_id(p_service_line_id IN NUMBER) IS
     SELECT brs.id brs_line_id
       FROM okc_k_lines_b          lines1,
            okc_k_lines_b          lines2,
            okc_k_lines_b          lines3,
            okc_k_lines_b          lines4,
            oks_billrate_schedules brs
      WHERE lines1.cle_id = p_service_line_id AND
            lines2.cle_id = lines1.id AND
            lines3.cle_id = lines2.id AND
            lines4.cle_id = lines3.id AND
            lines1.lse_id IN (2, 15, 20) AND
            lines2.lse_id IN (3, 16, 21) AND
            lines3.lse_id IN (5, 23, 59) AND
            lines4.lse_id IN (6, 24, 60) AND
            brs.cle_id = lines4.id AND
            brs.dnz_chr_id = lines1.dnz_chr_id;
     
  --05/17/04 chkrishn Added for deleting notes
  -- Commented by Jvorugan
  -- Bugno:4535339.
  -- From R12, notes and PM will be deleted when the serviceline id is deleted and not with the coverage.
  /*
     CURSOR Cur_Service_line(p_cle_id IN NUMBER) IS
     SELECT cle_id
     from okc_k_lines_b
     where id=p_cle_id
     and lse_id in (2,15,20);
        
     l_service_line_id NUMBER;
        
     CURSOR Cur_Get_notes(p_source_object_id IN Number) IS
       SELECT jtf_note_id
       FROM JTF_NOTES_VL
       WHERE source_object_id = p_source_object_id
       AND   source_object_code = 'OKS_COV_NOTE';
  */
  -- End of Bug:4535339 by Jvorugan
     
  CURSOR k_line_cur(p_id IN NUMBER, p_dnz_chr_id IN NUMBER) IS
     SELECT id, dnz_chr_id
       FROM oks_k_lines_b
      WHERE cle_id = p_id AND
            dnz_chr_id = p_dnz_chr_id;
     
  CURSOR time_zone_csr(p_id IN NUMBER, p_dnz_chr_id IN NUMBER) IS
     SELECT id, cle_id, dnz_chr_id
       FROM oks_coverage_timezones
      WHERE cle_id = p_id AND
            dnz_chr_id = p_dnz_chr_id;
     
  CURSOR cov_time_csr(p_id IN NUMBER, p_dnz_chr_id IN NUMBER) IS
     SELECT id, dnz_chr_id
       FROM oks_coverage_times
      WHERE cov_tze_line_id = p_id AND
            dnz_chr_id = p_dnz_chr_id;
     
  CURSOR action_type_csr(p_id IN NUMBER, p_dnz_chr_id IN NUMBER) IS
     SELECT id, dnz_chr_id
       FROM oks_action_time_types
      WHERE cle_id = p_id AND
            dnz_chr_id = p_dnz_chr_id;
     
  CURSOR action_times_csr(p_id IN NUMBER, p_dnz_chr_id IN NUMBER) IS
     SELECT id, dnz_chr_id
       FROM oks_action_times
      WHERE cov_action_type_id = p_id AND
            dnz_chr_id = p_dnz_chr_id;
     
  CURSOR bill_rate_csr(p_id IN NUMBER, p_dnz_chr_id IN NUMBER) IS
     SELECT id, dnz_chr_id
       FROM oks_billrate_schedules
      WHERE cle_id = p_id AND
            dnz_chr_id = p_dnz_chr_id;
     
  l_brs_tbl_in oks_brs_pvt.oksbillrateschedulesvtbltype;
     
  l_brs_id  NUMBER;
  l_line_id NUMBER;
     
  --n               NUMBER := 0;
  l_cov_id        NUMBER;
  line_det_rec    line_det_cur%ROWTYPE;
  --line_det_rec2   line_det_cur%ROWTYPE;
  l_child_cur_rec child_cur%ROWTYPE;
  l_clev_tbl_in   xxoks_cle_pvt.clev_tbl_type;
  l_clev_tbl_tmp  xxoks_cle_pvt.clev_tbl_type;
     
  l_cimv_tbl_in okc_contract_item_pub.cimv_tbl_type;
  l_ctcv_tbl_in okc_contract_party_pub.ctcv_tbl_type;
  l_cplv_tbl_in okc_contract_party_pub.cplv_tbl_type;
  l_crjv_tbl_in okc_k_rel_objs_pub.crjv_tbl_type;
  l_cocv_tbl_in oks_order_contacts_pub.cocv_tbl_type;
  l_codv_tbl_in oks_order_details_pub.codv_tbl_type;
  l_scrv_tbl_in oks_sales_credit_pub.scrv_tbl_type;
     
  l_klev_tbl_in oks_kln_pvt.klnv_tbl_type;
  l_tzev_tbl_in oks_ctz_pvt.okscoveragetimezonesvtbltype;
  l_cvtv_tbl_in oks_cvt_pvt.oks_coverage_times_v_tbl_type;
  l_actv_tbl_in oks_act_pvt.oksactiontimetypesvtbltype;
  l_acmv_tbl_in oks_acm_pvt.oks_action_times_v_tbl_type;
  l_brsv_tbl_in oks_brs_pvt.oksbillrateschedulesvtbltype;
     
  l_api_version   CONSTANT NUMBER := 1.0;
  l_init_msg_list CONSTANT VARCHAR2(1) := 'T';
  l_return_status VARCHAR2(1);
  l_msg_count     NUMBER;
  l_msg_data      VARCHAR2(2000) := NULL;
  --l_msg_index_out NUMBER;
  --l_api_name CONSTANT VARCHAR2(30) := 'Undo Line';
  --l_catv_tbl_in  okc_k_article_pub.catv_tbl_type;
  e_error EXCEPTION;
     
  c_clev   NUMBER := 1;
  --c_rulv   NUMBER := 1;
  --c_rgpv   NUMBER := 1;
  c_cimv   NUMBER := 1;
  c_ctcv   NUMBER := 1;
  --c_catv   NUMBER := 1;
  c_cplv   NUMBER := 1;
  c_crjv   NUMBER := 1;
  l_lse_id NUMBER;
  c_cocv   NUMBER := 1;
  c_codv   NUMBER := 1;
  c_scrv   NUMBER := 1;
     
  k_clev      NUMBER := 1;
  l_tzev      NUMBER := 1;
  l_cvtv      NUMBER := 1;
  l_actv      NUMBER := 1;
  l_acmv      NUMBER := 1;
  l_brsv      NUMBER := 1;
  --l_id        NUMBER;
  --l_pm_cle_id NUMBER := NULL;
     
  l_dummy_terminate_date DATE;
  l_line_type            NUMBER;
     
  FUNCTION bp_check(p_rgp_id IN NUMBER) RETURN BOOLEAN IS
     CURSOR getlse_cur IS
        SELECT kl.lse_id
          FROM okc_k_lines_v kl, okc_rule_groups_v rg
         WHERE kl.id = rg.cle_id AND
               rg.id = p_rgp_id;
        
  BEGIN
        
     OPEN getlse_cur;
     FETCH getlse_cur
        INTO l_lse_id;
     IF NOT getlse_cur%FOUND THEN
        l_lse_id := NULL;
     END IF;
     CLOSE getlse_cur;
     IF l_lse_id IN (3, 16, 21) THEN
        RETURN TRUE;
     ELSE
        RETURN FALSE;
     END IF;
  END bp_check;
     
  BEGIN
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.set_indentation('Undo_Line');
     okc_debug.log('Entered Undo_Line', 2);
  END IF;
     
  -- Commented by Jvorugan for Coverage Rearchitecture.
  -- From R12, notes and PM will be deleted when the serviceline id is deleted and not with the coverage.
  -- Bugno:4535339
  /*    OPEN line_det_cur(p_line_id);
         FETCH line_det_cur INTO line_det_rec2;
             IF (line_det_rec2.lse_id = 2) OR (line_det_rec2.lse_id = 14)
             THEN
                 l_pm_cle_id := line_det_rec2.ID;
             END IF;
     CLOSE line_det_cur;
  */
  -- End of Bug:4535339 by Jvorugan
     
  x_return_status := okc_api.g_ret_sts_success;
     
  oks_coverages_pvt.validate_line_id(p_line_id, l_return_status);
  IF NOT l_return_status = okc_api.g_ret_sts_success THEN
     -- IF NOT l_Return_Status ='S' THEN
     RETURN;
  END IF;
     
  -- l_clev_tbl_tmp(c_clev).id := p_line_id;
     
  l_line_id := p_line_id;
     
  --05/17/2004 chkrishn added for deleting notes
  -- Commented by Jvorugan for Coverage Rearchitecture.
  -- From R12, notes and PM will be deleted when the serviceline id is deleted and not with the coverage.
  -- Bugno:4535339
  /*
   OPEN Cur_Service_line(p_line_id);
   FETCH Cur_Service_line INTO l_service_line_id;
   CLOSE  Cur_Service_line;
        
   FOR note_rec IN Cur_Get_notes(l_service_line_id)
  LOOP
  JTF_NOTES_PUB.Secure_Delete_note
  ( p_api_version           => l_api_version,
    p_init_msg_list         =>  l_init_msg_list,   --         VARCHAR2 DEFAULT 'F'
    p_commit                => 'F',  --IN            VARCHAR2 DEFAULT 'F'
    p_validation_level     => 100, --IN            NUMBER   DEFAULT 100
    x_return_status        => l_return_status , -- OUT NOCOPY VARCHAR2
    x_msg_count            => l_msg_count, -- OUT NOCOPY NUMBER
    x_msg_data             => l_msg_data , --  OUT NOCOPY VARCHAR2
    p_jtf_note_id          => note_rec.jtf_note_id,
    p_use_AOL_security     => 'F' --IN            VARCHAR2 DEFAULT 'T'
  );
  IF NOT l_return_status = OKC_API.G_RET_STS_SUCCESS THEN
     RAISE e_Error;
  END IF;
  END LOOP;
        
  */
     
  -- End of Bug:4535339 by Jvorugan
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.log('Before BRS_REC', 2);
  END IF;
     
  FOR brs_rec IN cur_get_brs_id(l_line_id) LOOP
        
     oks_coverages_pvt.init_bill_rate_line(l_brs_tbl_in);
     l_brs_id := brs_rec.brs_line_id;
     l_brs_tbl_in(1).id := l_brs_id;
        
     oks_brs_pvt.delete_row(p_api_version                  => l_api_version,
                            p_init_msg_list                => l_init_msg_list,
                            x_return_status                => l_return_status,
                            x_msg_count                    => l_msg_count,
                            x_msg_data                     => l_msg_data,
                            p_oks_billrate_schedules_v_tbl => l_brs_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RAISE e_error;
     END IF;
        
  END LOOP;
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.log('After OKS_BRS_PVT delete_row', 2);
  END IF;
     
  OPEN child_cur(p_line_id);
     
  FETCH child_cur
     INTO l_child_cur_rec;
  l_clev_tbl_tmp(c_clev).dnz_chr_id := l_child_cur_rec.dnz_chr_id;
  l_cov_id := l_child_cur_rec.lse_id;
  l_cov_id := l_child_cur_rec.id;
     
  CLOSE child_cur;
     
  c_clev := c_clev + 1;
  FOR child_rec1 IN child_cur1(p_line_id) LOOP
     l_clev_tbl_tmp(c_clev).id := child_rec1.id;
     l_clev_tbl_tmp(c_clev).dnz_chr_id := child_rec1.dnz_chr_id;
     c_clev := c_clev + 1;
     FOR child_rec2 IN child_cur2(child_rec1.id) LOOP
        l_clev_tbl_tmp(c_clev).id := child_rec2.id;
        l_clev_tbl_tmp(c_clev).dnz_chr_id := child_rec2.dnz_chr_id;
        c_clev := c_clev + 1;
        FOR child_rec3 IN child_cur3(child_rec2.id) LOOP
           l_clev_tbl_tmp(c_clev).id := child_rec3.id;
           l_clev_tbl_tmp(c_clev).dnz_chr_id := child_rec3.dnz_chr_id;
           c_clev := c_clev + 1;
           FOR child_rec4 IN child_cur4(child_rec3.id) LOOP
              l_clev_tbl_tmp(c_clev).id := child_rec4.id;
              l_clev_tbl_tmp(c_clev).dnz_chr_id := child_rec4.dnz_chr_id;
              c_clev := c_clev + 1;
              FOR child_rec5 IN child_cur5(child_rec4.id) LOOP
                 l_clev_tbl_tmp(c_clev).id := child_rec5.id;
                 l_clev_tbl_tmp(c_clev).dnz_chr_id := child_rec5.dnz_chr_id;
                 c_clev := c_clev + 1;
              END LOOP;
           END LOOP;
        END LOOP;
     END LOOP;
  END LOOP;
  c_clev := 1;
     
  FOR v_index IN REVERSE l_clev_tbl_tmp.FIRST .. l_clev_tbl_tmp.LAST LOOP
        
     l_clev_tbl_in(c_clev).id := l_clev_tbl_tmp(v_index).id;
     l_clev_tbl_in(c_clev).dnz_chr_id := l_clev_tbl_tmp(v_index)
                                        .dnz_chr_id;
     c_clev := c_clev + 1;
  END LOOP;
     
  --==============================================================================
     
  FOR k_index IN l_clev_tbl_in.FIRST .. l_clev_tbl_in.LAST LOOP
        
     FOR k_line_rec IN k_line_cur(l_clev_tbl_in(k_index).id,
                                  l_clev_tbl_in(k_index).dnz_chr_id) LOOP
           
        l_klev_tbl_in(k_clev).id := k_line_rec.id;
        l_klev_tbl_in(k_clev).dnz_chr_id := k_line_rec.dnz_chr_id;
        k_clev := k_clev + 1;
           
     END LOOP;
        
  END LOOP;
     
  FOR tz_index IN l_clev_tbl_in.FIRST .. l_clev_tbl_in.LAST LOOP
        
     FOR time_zone_rec IN time_zone_csr(l_clev_tbl_in(tz_index).id,
                                        l_clev_tbl_in(tz_index)
                                        .dnz_chr_id) LOOP
           
        l_tzev_tbl_in(l_tzev).id := time_zone_rec.id;
        l_tzev_tbl_in(l_tzev).dnz_chr_id := time_zone_rec.dnz_chr_id;
           
        l_tzev := l_tzev + 1;
     END LOOP;
  END LOOP;
     
  IF l_tzev_tbl_in.COUNT > 0 THEN
     FOR ti_index IN l_tzev_tbl_in.FIRST .. l_tzev_tbl_in.LAST LOOP
           
        FOR cov_time_rec IN cov_time_csr(l_tzev_tbl_in(ti_index).id,
                                         l_tzev_tbl_in(ti_index)
                                         .dnz_chr_id) LOOP
           l_cvtv_tbl_in(l_cvtv).id := cov_time_rec.id;
           l_cvtv_tbl_in(l_cvtv).dnz_chr_id := cov_time_rec.dnz_chr_id;
           l_cvtv := l_cvtv + 1;
        END LOOP;
           
     END LOOP;
        
  END IF;
     
  FOR ac_index IN l_clev_tbl_in.FIRST .. l_clev_tbl_in.LAST LOOP
        
     FOR action_type_rec IN action_type_csr(l_clev_tbl_in(ac_index).id,
                                            l_clev_tbl_in(ac_index)
                                            .dnz_chr_id) LOOP
           
        l_actv_tbl_in(l_actv).id := action_type_rec.id;
        l_actv_tbl_in(l_actv).dnz_chr_id := action_type_rec.dnz_chr_id;
           
        l_actv := l_actv + 1;
     END LOOP;
  END LOOP;
     
  IF l_actv_tbl_in.COUNT > 0 THEN
     FOR at_index IN l_actv_tbl_in.FIRST .. l_actv_tbl_in.LAST LOOP
        FOR action_times_rec IN action_times_csr(l_actv_tbl_in(at_index).id,
                                                 l_actv_tbl_in(at_index)
                                                 .dnz_chr_id) LOOP
              
           l_acmv_tbl_in(l_acmv).id := action_times_rec.id;
           l_acmv_tbl_in(l_acmv).dnz_chr_id := action_times_rec.dnz_chr_id;
              
           l_acmv := l_acmv + 1;
              
        END LOOP;
           
     END LOOP;
        
  END IF;
     
  IF l_clev_tbl_in.COUNT > 0 THEN
        
     FOR br_index IN l_clev_tbl_in.FIRST .. l_clev_tbl_in.LAST LOOP
           
        FOR bill_rate_rec IN bill_rate_csr(l_clev_tbl_in(br_index).id,
                                           l_clev_tbl_in(br_index)
                                           .dnz_chr_id) LOOP
              
           l_brsv_tbl_in(l_brsv).id := bill_rate_rec.id;
           l_brsv_tbl_in(l_brsv).dnz_chr_id := bill_rate_rec.dnz_chr_id;
           l_brsv := l_brsv + 1;
              
        END LOOP;
           
     END LOOP;
        
  END IF;
     
  -- Commented by Jvorugan for Coverage Rearchitecture.
  -- From R12, notes and PM will be deleted when the serviceline id is deleted and not with the coverage.
  -- Bugno:4535339
     
  /*
        
  IF (G_DEBUG_ENABLED = 'Y') THEN
          okc_debug.log('BEFORE OKS_PM_PROGRAMS_PVT UNDO_PM_LINE', 2);
        
  END IF;
        
        
        
        
  IF l_pm_cle_id IS NOT NULL THEN
        
        
          OKS_PM_PROGRAMS_PVT.UNDO_PM_LINE(
          p_api_version                   =>l_api_version,
          p_init_msg_list                 =>l_init_msg_list,
          x_return_status                 =>l_return_status,
          x_msg_count                     =>l_msg_count,
          x_msg_data                      =>l_msg_data,
          p_cle_id                        =>l_pm_cle_id);
        
  --chkrishn 03/17/04 exception handling
      IF  NOT (l_return_status = OKC_API.G_RET_STS_SUCCESS)   then
        return;
      END IF;
        
        
  END IF;
        
  */
  -- End of Bug:4535339 by Jvorugan
     
  IF l_brsv_tbl_in.COUNT > 0 THEN
        
     oks_brs_pvt.delete_row(p_api_version                  => l_api_version,
                            p_init_msg_list                => l_init_msg_list,
                            x_return_status                => l_return_status,
                            x_msg_count                    => l_msg_count,
                            x_msg_data                     => l_msg_data,
                            p_oks_billrate_schedules_v_tbl => l_brsv_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RETURN;
     END IF;
        
  END IF;
     
  IF l_klev_tbl_in.COUNT > 0 THEN
        
     oks_kln_pvt.delete_row(p_api_version   => l_api_version,
                            p_init_msg_list => l_init_msg_list,
                            x_return_status => l_return_status,
                            x_msg_count     => l_msg_count,
                            x_msg_data      => l_msg_data,
                            p_klnv_tbl      => l_klev_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RETURN;
     END IF;
        
  END IF;
     
  IF l_cvtv_tbl_in.COUNT > 0 THEN
        
     oks_cvt_pvt.delete_row(p_api_version              => l_api_version,
                            p_init_msg_list            => l_init_msg_list,
                            x_return_status            => l_return_status,
                            x_msg_count                => l_msg_count,
                            x_msg_data                 => l_msg_data,
                            p_oks_coverage_times_v_tbl => l_cvtv_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RETURN;
     END IF;
  END IF;
     
  IF l_tzev_tbl_in.COUNT > 0 THEN
     oks_ctz_pvt.delete_row(p_api_version                  => l_api_version,
                            p_init_msg_list                => l_init_msg_list,
                            x_return_status                => l_return_status,
                            x_msg_count                    => l_msg_count,
                            x_msg_data                     => l_msg_data,
                            p_oks_coverage_timezones_v_tbl => l_tzev_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RETURN;
     END IF;
        
  END IF;
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.log('AFTER OKS_CTZ_PVT  delete_row', 2);
        
  END IF;
     
  IF l_acmv_tbl_in.COUNT > 0 THEN
        
     oks_acm_pvt.delete_row(p_api_version            => l_api_version,
                            p_init_msg_list          => l_init_msg_list,
                            x_return_status          => l_return_status,
                            x_msg_count              => l_msg_count,
                            x_msg_data               => l_msg_data,
                            p_oks_action_times_v_tbl => l_acmv_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RETURN;
     END IF;
  END IF;
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.log('AFTER OKS_ACM_PVT  delete_row', 2);
        
  END IF;
     
  IF l_actv_tbl_in.COUNT > 0 THEN
        
     oks_act_pvt.delete_row(p_api_version                 => l_api_version,
                            p_init_msg_list               => l_init_msg_list,
                            x_return_status               => l_return_status,
                            x_msg_count                   => l_msg_count,
                            x_msg_data                    => l_msg_data,
                            p_oks_action_time_types_v_tbl => l_actv_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RETURN;
     END IF;
        
     IF (g_debug_enabled = 'Y') THEN
        okc_debug.log('AFTER OKS_ACT_PVT  delete_row', 2);
           
     END IF;
        
  END IF;
  --=============================================================================
     
  -- Get Relational Objects Linked to the lines
  FOR v_index IN l_clev_tbl_in.FIRST .. l_clev_tbl_in.LAST LOOP
     FOR relobj_rec IN relobj_cur(l_clev_tbl_in(v_index).id) LOOP
        l_crjv_tbl_in(c_crjv).id := relobj_rec.id;
        c_crjv := c_crjv + 1;
     END LOOP;
        
     FOR orderdetails_rec IN orderdetails_cur(l_clev_tbl_in(v_index)
                                              .dnz_chr_id,
                                              l_clev_tbl_in(v_index).id)
           
      LOOP
        l_codv_tbl_in(c_codv).id := orderdetails_rec.id;
        FOR ordercontacts_rec IN ordercontacts_cur(l_codv_tbl_in(c_codv).id) LOOP
           l_cocv_tbl_in(c_cocv).id := ordercontacts_rec.id;
           c_cocv := c_cocv + 1;
        END LOOP;
        c_codv := c_codv + 1;
     END LOOP;
     FOR salescredits_rec IN salescredits_cur(l_clev_tbl_in(v_index).id) LOOP
        l_scrv_tbl_in(c_scrv).id := salescredits_rec.id;
        c_scrv := c_scrv + 1;
     END LOOP;
        
  END LOOP;
     
  -- Get Items
  FOR v_index IN l_clev_tbl_in.FIRST .. l_clev_tbl_in.LAST LOOP
     FOR item_rec IN item_cur(l_clev_tbl_in(v_index).id) LOOP
        l_cimv_tbl_in(c_cimv).id := item_rec.id;
        c_cimv := c_cimv + 1;
     END LOOP;
  END LOOP;
  -- GET K Party Roles and Contacts
  FOR v_index IN l_clev_tbl_in.FIRST .. l_clev_tbl_in.LAST LOOP
     FOR kprl_rec IN kprl_cur(l_clev_tbl_in(v_index).id) LOOP
        l_cplv_tbl_in(c_cplv).id := kprl_rec.id;
        c_cplv := c_cplv + 1;
        FOR contact_rec IN contact_cur(kprl_rec.id) LOOP
           l_ctcv_tbl_in(c_ctcv).id := contact_rec.id;
           c_ctcv := c_ctcv + 1;
        END LOOP;
     END LOOP;
  END LOOP;
     
  IF NOT l_cocv_tbl_in.COUNT = 0 THEN
        
     oks_order_contacts_pub.delete_order_contact(p_api_version   => l_api_version,
                                                 p_init_msg_list => l_init_msg_list,
                                                 x_return_status => l_return_status,
                                                 x_msg_count     => l_msg_count,
                                                 x_msg_data      => l_msg_data,
                                                 p_cocv_tbl      => l_cocv_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RETURN;
     END IF;
  END IF;
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.log('AFTER OKS_ORDER_CONTACTS_PUB  delete_order_contract',
                   2);
        
  END IF;
     
  IF NOT l_codv_tbl_in.COUNT = 0 THEN
        
     oks_order_details_pub.delete_order_detail(p_api_version   => l_api_version,
                                               p_init_msg_list => l_init_msg_list,
                                               x_return_status => l_return_status,
                                               x_msg_count     => l_msg_count,
                                               x_msg_data      => l_msg_data,
                                               p_codv_tbl      => l_codv_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RETURN;
     END IF;
  END IF;
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.log('AFTER OKS_ORDER_DETAILS_PUB  delete_order_detail',
                   2);
        
  END IF;
     
  IF NOT l_scrv_tbl_in.COUNT = 0 THEN
        
     oks_sales_credit_pub.delete_sales_credit(p_api_version   => l_api_version,
                                              p_init_msg_list => l_init_msg_list,
                                              x_return_status => l_return_status,
                                              x_msg_count     => l_msg_count,
                                              x_msg_data      => l_msg_data,
                                              p_scrv_tbl      => l_scrv_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RETURN;
     END IF;
  END IF;
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.log('AFTER OKS_SALES_CREDIT_PUB Delete_Sales_Credit', 2);
        
  END IF;
     
  IF NOT l_crjv_tbl_in.COUNT = 0 THEN
        
     okc_k_rel_objs_pub.delete_row(p_api_version   => l_api_version,
                                   p_init_msg_list => l_init_msg_list,
                                   x_return_status => l_return_status,
                                   x_msg_count     => l_msg_count,
                                   x_msg_data      => l_msg_data,
                                   p_crjv_tbl      => l_crjv_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RETURN;
     END IF;
  END IF;
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.log('AFTER OKC_K_REL_OBJS_PUB Delete_Row', 2);
        
  END IF;
     
  IF NOT l_ctcv_tbl_in.COUNT = 0 THEN
     okc_contract_party_pub.delete_contact(p_api_version   => l_api_version,
                                           p_init_msg_list => l_init_msg_list,
                                           x_return_status => l_return_status,
                                           x_msg_count     => l_msg_count,
                                           x_msg_data      => l_msg_data,
                                           p_ctcv_tbl      => l_ctcv_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RETURN;
     END IF;
  END IF;
  IF NOT l_cplv_tbl_in.COUNT = 0 THEN
     okc_contract_party_pub.delete_k_party_role(p_api_version   => l_api_version,
                                                p_init_msg_list => l_init_msg_list,
                                                x_return_status => l_return_status,
                                                x_msg_count     => l_msg_count,
                                                x_msg_data      => l_msg_data,
                                                p_cplv_tbl      => l_cplv_tbl_in);
        
     IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
        RETURN;
     END IF;
  END IF;
     
  --IF NOT l_rulv_tbl_in.COUNT=0 THEN
  -------delete level elements before deleting rules.
     
  OPEN line_det_cur(p_line_id);
  FETCH line_det_cur
     INTO line_det_rec;
     
  l_dummy_terminate_date := line_det_rec.start_date - 1;
     
  IF line_det_rec.lse_id = 1 OR line_det_rec.lse_id = 12 OR
     line_det_rec.lse_id = 14 OR line_det_rec.lse_id = 19 THEN
        
     l_line_type := 1; --1 for TOP line
  ELSE
        
     l_line_type := 2; --2 for covered level
  END IF;
     
  CLOSE line_det_cur;
     
  oks_bill_util_pub.pre_del_level_elements(p_api_version     => l_api_version,
                                           p_terminated_date => l_dummy_terminate_date,
                                           p_id              => p_line_id,
                                           p_flag            => l_line_type,
                                           x_return_status   => l_return_status);
     
  IF NOT nvl(l_return_status, 'S') = okc_api.g_ret_sts_success THEN
     x_return_status := okc_api.g_ret_sts_error;
        
     okc_api.set_message(g_app_name,
                         g_required_value,
                         g_col_name_token,
                         'ERROR
  IN DELETING LEVEL_ELEMENTS');
     RETURN;
  END IF;
     
  --03/16/04 chkrishn removed for rules rearchitecture. Replaced with call to oks_pm_programs_pvt.undo_pm_line
  -- call the schedule deletion API
     
  /*
  FOR C1 IN CUR_GET_SCH(l_cov_id)
   LOOP
    l_sch_index:= l_sch_index + 1 ;
    l_pm_schedules_v_tbl(l_sch_index).id:= C1.ID;
    END LOOP ;
        
  IF l_pm_schedules_v_tbl.count  <> 0 then
    OKS_PMS_PVT.delete_row(
      p_api_version   => l_api_version,
      p_init_msg_list  => l_init_msg_list,
      x_return_status  => l_return_status,
      x_msg_count   => l_msg_count,
      x_msg_data   => l_msg_data,
      p_oks_pm_schedules_v_tbl    =>   l_pm_schedules_v_tbl);
  END IF ;
        
    IF NOT nvl(l_return_status,'S') = OKC_API.G_RET_STS_SUCCESS THEN
       x_return_status := OKC_API.G_RET_STS_ERROR;
        
  OKC_API.Set_Message(G_APP_NAME,G_REQUIRED_VALUE,G_COL_NAME_TOKEN,'ERROR
  IN DELETING PM_SCHEDULES');
       RETURN;
    END IF;
  */
     
  IF NOT l_cimv_tbl_in.COUNT = 0 THEN
     okc_contract_item_pub.delete_contract_item(p_api_version   => l_api_version,
                                                p_init_msg_list => l_init_msg_list,
                                                x_return_status => l_return_status,
                                                x_msg_count     => l_msg_count,
                                                x_msg_data      => l_msg_data,
                                                p_cimv_tbl      => l_cimv_tbl_in);
        
     IF NOT l_return_status = okc_api.g_ret_sts_success THEN
        RAISE e_error;
     END IF;
  END IF;
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.log('AFTER okc_contract_ITEM_pub.delete_Contract_ITEM',
                   2);
        
  END IF;
     
  IF NOT l_clev_tbl_in.COUNT = 0 THEN
     xxoks_coverages_pvt.delete_contract_lines(p_api_version   => l_api_version,
                                               p_init_msg_list => l_init_msg_list,
                                               x_return_status => l_return_status,
                                               x_msg_count     => l_msg_count,
                                               x_msg_data      => l_msg_data,
                                               p_clev_tbl      => l_clev_tbl_in);
        
     IF NOT l_return_status = okc_api.g_ret_sts_success THEN
        RAISE e_error;
     END IF;
  END IF;
     
  oks_coverages_pvt.undo_events(p_line_id, l_return_status, l_msg_data);
  IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
     RAISE e_error;
  END IF;
     
  oks_coverages_pvt.undo_counters(p_line_id,
                                  l_return_status,
                                  l_msg_data);
  IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
     RAISE e_error;
  END IF;
  x_return_status := l_return_status;
     
  IF (g_debug_enabled = 'Y') THEN
     okc_debug.log('End of  Undo Line', 2);
     okc_debug.reset_indentation;
  END IF;
     
  EXCEPTION
  WHEN e_error THEN
        
     IF (g_debug_enabled = 'Y') THEN
        okc_debug.log('Exception of  Undo Line  e_Error' || SQLERRM, 2);
        okc_debug.reset_indentation;
     END IF;
        
     x_msg_count     := l_msg_count;
     x_msg_data      := l_msg_data;
     x_return_status := l_return_status;
        
  WHEN OTHERS THEN
        
     IF (g_debug_enabled = 'Y') THEN
        okc_debug.log('Exception of  Undo Line  when_others' ||
                      SQLERRM,
                      2);
        okc_debug.reset_indentation;
     END IF;
        
     x_msg_count := l_msg_count;
     okc_api.set_message(p_app_name     => g_app_name,
                         p_msg_name     => g_unexpected_error,
                         p_token1       => g_sqlcode_token,
                         p_token1_value => SQLCODE,
                         p_token2       => g_sqlerrm_token,
                         p_token2_value => SQLERRM);
     -- notify caller of an error as UNEXPETED error
     x_return_status := okc_api.g_ret_sts_unexp_error;
        
  END undo_line;

  ---------------------------------------------------------------------------
  -- PROCEDURE undo_header
  ---------------------------------------------------------------------------
  PROCEDURE undo_events(p_kline_id      IN NUMBER,
                       x_return_status OUT NOCOPY VARCHAR2,
                       x_msg_data      OUT NOCOPY VARCHAR2) IS
    l_cnhv_tbl okc_conditions_pub.cnhv_tbl_type;
    l_cnlv_tbl okc_conditions_pub.cnlv_tbl_type;
    l_coev_tbl okc_conditions_pub.coev_tbl_type;
    l_aavv_tbl okc_conditions_pub.aavv_tbl_type;
    l_ocev_tbl okc_outcome_pub.ocev_tbl_type;
    l_oatv_tbl okc_outcome_pub.oatv_tbl_type;
    c_cnhv     NUMBER := 1;
    c_cnlv     NUMBER := 1;
    c_aavv     NUMBER := 1;
    c_ocev     NUMBER := 1;
    c_oatv     NUMBER := 1;
    c_coev     NUMBER := 1;
    l_api_version   CONSTANT NUMBER := 1.0;
    l_init_msg_list CONSTANT VARCHAR2(1) := 'T';
    l_return_status VARCHAR2(3);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000) := NULL;
    --l_msg_index_out NUMBER;
    --l_api_name CONSTANT VARCHAR2(30) := 'UNDO EVENT';
     
    CURSOR cur_cnh(p_kline_id IN NUMBER) IS
       SELECT id
         FROM okc_condition_headers_v
        WHERE object_id = p_kline_id AND
              jtot_object_code = 'OKC_K_LINE';
    CURSOR cur_coe(p_cnh_id IN NUMBER) IS
       SELECT id FROM okc_condition_occurs_v WHERE cnh_id = p_cnh_id;
    CURSOR cur_aav(p_coe_id IN NUMBER) IS
       SELECT aae_id, coe_id
         FROM okc_action_att_vals_v
        WHERE coe_id = p_coe_id;
    CURSOR cur_cnl(p_cnh_id IN NUMBER) IS
       SELECT id FROM okc_condition_lines_v WHERE cnh_id = p_cnh_id;
    CURSOR cur_oce(p_cnh_id IN NUMBER) IS
       SELECT id FROM okc_outcomes_v WHERE cnh_id = p_cnh_id;
    CURSOR cur_oat(p_oce_id IN NUMBER) IS
       SELECT id FROM okc_outcome_arguments_v WHERE oce_id = p_oce_id;
  BEGIN
    x_return_status := okc_api.g_ret_sts_success;
    FOR cnh_rec IN cur_cnh(p_kline_id) LOOP
       l_cnhv_tbl(c_cnhv).id := cnh_rec.id;
       c_cnhv := c_cnhv + 1;
       FOR coe_rec IN cur_coe(l_cnhv_tbl(c_cnhv - 1).id) LOOP
          l_coev_tbl(c_coev).id := coe_rec.id;
          c_coev := c_coev + 1;
          FOR aav_rec IN cur_aav(l_coev_tbl(c_coev - 1).id) LOOP
             l_aavv_tbl(c_aavv).aae_id := aav_rec.aae_id;
             l_aavv_tbl(c_aavv).coe_id := aav_rec.coe_id;
             c_aavv := c_aavv + 1;
          END LOOP;
       END LOOP;
       FOR cnl_rec IN cur_cnl(l_cnhv_tbl(c_cnhv - 1).id) LOOP
          l_cnlv_tbl(c_cnlv).id := cnl_rec.id;
          c_cnlv := c_cnlv + 1;
       END LOOP;
       FOR oce_rec IN cur_oce((l_cnhv_tbl(c_cnhv - 1).id)) LOOP
          l_ocev_tbl(c_ocev).id := oce_rec.id;
          c_ocev := c_ocev + 1;
          FOR oat_rec IN cur_oat(l_ocev_tbl(c_ocev - 1).id) LOOP
             l_oatv_tbl(c_oatv).id := oat_rec.id;
             c_oatv := c_oatv + 1;
          END LOOP;
       END LOOP;
    END LOOP;
    IF NOT l_oatv_tbl.COUNT = 0 THEN
       okc_outcome_pub.delete_out_arg(p_api_version   => l_api_version,
                                      p_init_msg_list => l_init_msg_list,
                                      x_return_status => l_return_status,
                                      x_msg_count     => l_msg_count,
                                      x_msg_data      => l_msg_data,
                                      p_oatv_tbl      => l_oatv_tbl);
       IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
          x_return_status := l_return_status;
          RETURN;
       END IF;
    END IF;
    IF NOT l_ocev_tbl.COUNT = 0 THEN
       okc_outcome_pub. delete_outcome(p_api_version   => l_api_version,
                                       p_init_msg_list => l_init_msg_list,
                                       x_return_status => l_return_status,
                                       x_msg_count     => l_msg_count,
                                       x_msg_data      => l_msg_data,
                                       p_ocev_tbl      => l_ocev_tbl);
       IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
          x_return_status := l_return_status;
          RETURN;
       END IF;
    END IF;
    IF NOT l_aavv_tbl.COUNT = 0 THEN
       okc_conditions_pub.delete_act_att_vals(p_api_version   => l_api_version,
                                              p_init_msg_list => l_init_msg_list,
                                              x_return_status => l_return_status,
                                              x_msg_count     => l_msg_count,
                                              x_msg_data      => l_msg_data,
                                              p_aavv_tbl      => l_aavv_tbl);
       IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
          x_return_status := l_return_status;
          RETURN;
       END IF;
    END IF;
    IF NOT l_coev_tbl.COUNT = 0 THEN
       okc_conditions_pub. delete_cond_occurs(p_api_version   => l_api_version,
                                              p_init_msg_list => l_init_msg_list,
                                              x_return_status => l_return_status,
                                              x_msg_count     => l_msg_count,
                                              x_msg_data      => l_msg_data,
                                              p_coev_tbl      => l_coev_tbl);
       IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
          x_return_status := l_return_status;
          RETURN;
       END IF;
    END IF;
    IF NOT l_cnlv_tbl.COUNT = 0 THEN
       okc_conditions_pub.delete_cond_lines(p_api_version   => l_api_version,
                                            p_init_msg_list => l_init_msg_list,
                                            x_return_status => l_return_status,
                                            x_msg_count     => l_msg_count,
                                            x_msg_data      => l_msg_data,
                                            p_cnlv_tbl      => l_cnlv_tbl);
       IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
          x_return_status := l_return_status;
          RETURN;
       END IF;
    END IF;
    IF NOT l_cnhv_tbl.COUNT = 0 THEN
       okc_conditions_pub. delete_cond_hdrs(p_api_version   => l_api_version,
                                            p_init_msg_list => l_init_msg_list,
                                            x_return_status => l_return_status,
                                            x_msg_count     => l_msg_count,
                                            x_msg_data      => l_msg_data,
                                            p_cnhv_tbl      => l_cnhv_tbl);
       IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
          x_return_status := l_return_status;
          RETURN;
       END IF;
    END IF;
    x_return_status := okc_api.g_ret_sts_success;
  EXCEPTION
    WHEN OTHERS THEN
       x_return_status := l_return_status;
       x_msg_data      := SQLCODE || '-' || SQLERRM;
  END undo_events;
  
  ---------------------------------------------------------------------------
  -- PROCEDURE undo_header
  ---------------------------------------------------------------------------
 -- Temporary Fix for Undo Counters by updating end_date_active to sysdate
   -- To be attended to later

   -- *************************************************************************************************
   PROCEDURE undo_counters(p_kline_id      IN NUMBER,
                           x_return_status OUT NOCOPY VARCHAR2,
                           x_msg_data      OUT NOCOPY VARCHAR2) IS
   
      CURSOR cur_cgp(p_kline_id IN NUMBER) IS
         SELECT counter_group_id
           FROM okx_counter_groups_v
          WHERE source_object_id = p_kline_id
               
                AND
                source_object_code = 'CONTRACT_LINE';
   
      CURSOR cur_ovn(p_ctrgrp_id IN NUMBER) IS
         SELECT object_version_number
           FROM cs_counter_groups
          WHERE counter_group_id = p_ctrgrp_id;
   
      TYPE t_idtable IS TABLE OF NUMBER(35) INDEX BY BINARY_INTEGER;
      l_cgp_tbl               t_idtable;
      c_cgp                   NUMBER := 1;
      l_ctr_grp_id            NUMBER;
      x_object_version_number NUMBER;
      l_object_version_number NUMBER;
      l_api_version   CONSTANT NUMBER := 1.0;
      l_init_msg_list CONSTANT VARCHAR2(1) := 'T';
      l_return_status VARCHAR2(1);
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(2000) := NULL;
      --l_msg_index_out NUMBER;
      --l_api_name CONSTANT VARCHAR2(30) := 'UNDO COUNTERS';
      l_commit                   VARCHAR2(3);
      l_ctr_grp_rec              cs_counters_pub.ctrgrp_rec_type;
      l_cascade_upd_to_instances VARCHAR2(1);
   BEGIN
      x_return_status := okc_api.g_ret_sts_success;
      FOR cgp_rec IN cur_cgp(p_kline_id) LOOP
         l_cgp_tbl(c_cgp) := cgp_rec.counter_group_id;
         c_cgp := c_cgp + 1;
         FOR i IN 1 .. l_cgp_tbl.COUNT LOOP
            l_ctr_grp_id                  := l_cgp_tbl(i);
            l_ctr_grp_rec.end_date_active := SYSDATE;
            OPEN cur_ovn(l_ctr_grp_id);
            FETCH cur_ovn
               INTO l_object_version_number;
            CLOSE cur_ovn;
            cs_counters_pub.update_ctr_grp(p_api_version              => l_api_version,
                                           p_init_msg_list            => l_init_msg_list,
                                           p_commit                   => l_commit,
                                           x_return_status            => l_return_status,
                                           x_msg_count                => l_msg_count,
                                           x_msg_data                 => l_msg_data,
                                           p_ctr_grp_id               => l_ctr_grp_id,
                                           p_object_version_number    => l_object_version_number,
                                           p_ctr_grp_rec              => l_ctr_grp_rec,
                                           p_cascade_upd_to_instances => l_cascade_upd_to_instances,
                                           x_object_version_number    => x_object_version_number);
         END LOOP;
         IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
            x_return_status := l_return_status;
            RETURN;
         END IF;
      END LOOP;
      x_return_status := okc_api.g_ret_sts_success;
   
   EXCEPTION
      WHEN OTHERS THEN
         x_return_status := l_return_status;
         x_msg_data      := SQLERRM;
      
   END undo_counters;

   -- *************************************************************************************************

   PROCEDURE update_coverage_effectivity(p_api_version     IN NUMBER,
                                         p_init_msg_list   IN VARCHAR2 DEFAULT okc_api.g_false,
                                         x_return_status   OUT NOCOPY VARCHAR2,
                                         x_msg_count       OUT NOCOPY NUMBER,
                                         x_msg_data        OUT NOCOPY VARCHAR2,
                                         p_service_line_id IN NUMBER,
                                         p_new_start_date  IN DATE,
                                         p_new_end_date    IN DATE) IS
   
      l_api_version   CONSTANT NUMBER := 1.0;
      l_init_msg_list CONSTANT VARCHAR2(1) := 'T';
      l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_msg_count     NUMBER;
      l_message       VARCHAR2(2000) := NULL;
      l_msg_data      VARCHAR2(2000) := NULL;
      l_msg_index_out NUMBER;
      l_api_name CONSTANT VARCHAR2(30) := 'Update_cov_eff';
      e_error EXCEPTION;
      no_cov_error EXCEPTION;
      g_chr_id       NUMBER;
      l_clev_tbl_in  okc_contract_pub.clev_tbl_type;
      l_clev_tbl_out okc_contract_pub.clev_tbl_type;
      l_cov_id       NUMBER;
      l_bp_id        NUMBER;
      --l_id           NUMBER;
      i              NUMBER := 0;
      l_start_date   DATE;
      g_start_date   DATE;
      g_end_date     DATE;
      l_lse_id       NUMBER;
   
      -- Cursor for Coverage
      CURSOR linecov_cur(p_id IN NUMBER) IS
         SELECT id, lse_id, start_date, end_date
           FROM okc_k_lines_v
          WHERE cle_id = p_id AND
                lse_id IN (2, 14, 15, 20, 13, 19);
   
      linecov_rec linecov_cur%ROWTYPE;
      ----------------------------------------------
      -- Cursor for Business Process
      CURSOR linedet_cur(p_id IN NUMBER) IS
         SELECT id, start_date, end_date
           FROM okc_k_lines_v
          WHERE cle_id = p_id;
   
      linedet_rec linedet_cur%ROWTYPE;
   
      -- Cursor for getting offset period for BP from OKS
      CURSOR cur_get_offset_bp(p_cle_id IN NUMBER) IS
         SELECT id, offset_duration, offset_period
           FROM oks_k_lines_b
          WHERE cle_id = p_cle_id;
   
      oks_offset_rec cur_get_offset_bp%ROWTYPE;
      ------------------------------------------------
      -- Cursor for Bill Type/Reaction Time
      CURSOR linedet1_cur(p_id IN NUMBER) IS
         SELECT id FROM okc_k_lines_v WHERE cle_id = p_id;
      ------------------------------------------------
      --Cursor for Bill Rate
      CURSOR linedet2_cur(p_id IN NUMBER) IS
         SELECT id FROM okc_k_lines_v WHERE cle_id = p_id;
      ------------------------------------------------
      CURSOR dnz_cur IS
         SELECT chr_id FROM okc_k_lines_v WHERE id = p_service_line_id;
   
      l_bp_offset_duration NUMBER := NULL;
      l_bp_offset_period   VARCHAR2(3) := NULL;
   
   BEGIN
   
      dbms_transaction.SAVEPOINT(l_api_name);
   
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.set_indentation('Update Coverage Effectivity');
         okc_debug.log('Entered Update Coverage Effectivity', 2);
      END IF;
   
      OPEN dnz_cur;
      FETCH dnz_cur
         INTO g_chr_id;
      CLOSE dnz_cur;
   
      -- Populate Line TBL for Coverage
   
      FOR linecov_rec IN linecov_cur(p_service_line_id) LOOP
         i := i + 1;
         l_cov_id := linecov_rec.id;
         l_clev_tbl_in(i).id := l_cov_id;
         l_clev_tbl_in(i).start_date := p_new_start_date;
         l_clev_tbl_in(i).end_date := p_new_end_date;
         l_lse_id := linecov_rec.lse_id;
      END LOOP;
   
      -- Effectivity for Business Process
      IF l_lse_id <> 13 THEN
      
         FOR linedet_rec IN linedet_cur(l_cov_id) LOOP
            i       := i + 1;
            l_bp_id := linedet_rec.id;
         
            -- Populate Line TBL for Business Process
            l_clev_tbl_in(i).id := l_bp_id;
         
            -- fetch OFS rule for Business Process
         
            OPEN cur_get_offset_bp(l_bp_id);
            FETCH cur_get_offset_bp
               INTO oks_offset_rec;
            IF cur_get_offset_bp%FOUND THEN
               l_bp_offset_period   := oks_offset_rec.offset_period;
               l_bp_offset_duration := oks_offset_rec.offset_duration;
            END IF;
            CLOSE cur_get_offset_bp;
         
            IF l_bp_offset_period IS NOT NULL AND
               l_bp_offset_duration IS NOT NULL THEN
            
               l_start_date := okc_time_util_pub.get_enddate(p_new_start_date,
                                                             l_bp_offset_period,
                                                             l_bp_offset_duration);
            
               IF l_bp_offset_duration > 0 THEN
                  l_start_date := l_start_date + 1;
               END IF;
            
               IF l_start_date < p_new_end_date THEN
                  g_start_date := l_start_date;
                  g_end_date   := p_new_end_date;
               ELSE
                  g_start_date := p_new_end_date;
                  g_end_date   := p_new_end_date;
               END IF;
            ELSE
               g_start_date := p_new_start_date;
               g_end_date   := p_new_end_date;
            END IF;
         
            -- Calculate Line Start Date for Business Process
            /*
               l_start_date:=OKC_Time_Util_Pub.get_enddate
                                                    (P_New_Start_date,
                                                l_bp_offset_period,
                                                l_bp_offset_duration);
            
                          IF  l_bp_offset_duration IS NOT NULL
                              AND l_bp_offset_duration  > 0
                          THEN
                             l_start_date := l_start_date + 1;
                          END IF;
            
               -- IF Line Start Date is later that End Date
                         IF l_start_date > P_New_End_Date
                         THEN
                               l_return_status:=OKC_API.G_RET_STS_ERROR;
                               RAISE e_error;
                         END IF;
            
               -- If there is no Offset, Coverage Start Date will be start date for Business Process
                          IF l_start_date is NOT NULL
                          THEN
                               g_start_date:=l_start_date;
                          ELSE
                                g_start_date:=p_new_start_date;
                         END IF;
                            g_end_date:= P_New_End_Date;
            */
         
            --   IF NOT l_start_date > P_New_End_Date
            --   THEN
         
            -- Populate Line TBL for Business Process
            l_clev_tbl_in(i).start_date := g_start_date;
            l_clev_tbl_in(i).end_date := g_end_date;
         
            -- Fetch Bill Types/ Reaction Times
         
            FOR linedet_rec1 IN linedet1_cur(l_bp_id) LOOP
               -- Populate Line TBL for Bill Types /Reaction Times
               i := i + 1;
               l_clev_tbl_in(i).id := linedet_rec1.id;
               l_clev_tbl_in(i).start_date := g_start_date;
               l_clev_tbl_in(i).end_date := g_end_date;
            
               -- Fetch Bill Rate
               FOR linedet_rec2 IN linedet2_cur(linedet_rec1.id) LOOP
                  -- Populate Line TBL for Bill Rate
                  i := i + 1;
                  l_clev_tbl_in(i).id := linedet_rec2.id;
                  l_clev_tbl_in(i).start_date := g_start_date;
                  l_clev_tbl_in(i).end_date := g_end_date;
               END LOOP; -- Bill Rate
            END LOOP; -- Bill Type/Reaction Times
         --     END IF ;
         END LOOP; -- Business process
      END IF;
   
      -- Update Line with all the data for Coverage, Business process, React Times, Bill Types, Bill Rate
   
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.log('Before  okc_contract_pub.Update_Contract_Line', 2);
      END IF;
      IF l_clev_tbl_in.COUNT > 0 THEN
      
         okc_contract_pub.update_contract_line(p_api_version       => l_api_version,
                                               p_init_msg_list     => l_init_msg_list,
                                               x_return_status     => l_return_status,
                                               x_msg_count         => l_msg_count,
                                               x_msg_data          => l_msg_data,
                                               p_restricted_update => 'T',
                                               p_clev_tbl          => l_clev_tbl_in,
                                               x_clev_tbl          => l_clev_tbl_out);
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('After  okc_contract_pub.Update_Contract_Line' ||
                          l_return_status,
                          2);
         END IF;
      
         IF NOT l_return_status = okc_api.g_ret_sts_success THEN
         
            IF l_msg_count > 0 THEN
               FOR i IN 1 .. l_msg_count LOOP
                  fnd_msg_pub.get(p_msg_index     => -1,
                                  p_encoded       => 'T', -- OKC$APPLICATION.GET_FALSE,
                                  p_data          => l_message,
                                  p_msg_index_out => l_msg_index_out);
               
                  l_msg_data := l_msg_data || '  ' || l_message;
               
               END LOOP;
            END IF;
         
            RAISE e_error;
         END IF;
      END IF;
      x_return_status := l_return_status;
   
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.log('End of Update_Coverage_Effectivity' ||
                       l_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN no_cov_error THEN
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Exp of Update_Coverage_Effectivity' || SQLERRM,
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         dbms_transaction.rollback_savepoint(l_api_name);
         --ROLLBACK ;
         okc_api.set_message(g_app_name,
                             'OKSMIS_REQUIRED_FIELD',
                             'FIELD_NAME',
                             'Coverage to run effectivity adjustment');
         x_return_status := 'E';
      
      WHEN e_error THEN
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Exp of Update_Coverage_Effectivity e_Error' ||
                          SQLERRM,
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         dbms_transaction.rollback_savepoint(l_api_name);
         --ROLLBACK ;
         x_msg_count     := l_msg_count;
         x_msg_data      := l_msg_data;
         x_return_status := 'E';
      
      WHEN okc_api.g_exception_error THEN
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Exp of Update_Coverage_Effectivity ' || SQLERRM,
                          2);
            okc_debug.reset_indentation;
         END IF;
         dbms_transaction.rollback_savepoint(l_api_name);
         --ROLLBACK ;
         x_msg_count     := l_msg_count;
         x_msg_data      := l_msg_data;
         x_return_status := 'E';
      
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Exp of Update_Coverage_Effectivity ' || SQLERRM,
                          2);
            okc_debug.reset_indentation;
         END IF;
         dbms_transaction.rollback_savepoint(l_api_name);
         --ROLLBACK ;
         x_msg_count     := l_msg_count;
         x_msg_data      := l_msg_data;
         x_return_status := 'E';
      
      WHEN OTHERS THEN
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Exp of Update_Coverage_Effectivity ' || SQLERRM,
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         dbms_transaction.rollback_savepoint(l_api_name);
         --ROLLBACK ;
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
         x_msg_count     := l_msg_count;
      
   END update_coverage_effectivity;

   PROCEDURE undo_line(p_api_version     IN NUMBER,
                       p_init_msg_list   IN VARCHAR2 DEFAULT okc_api.g_false,
                       p_validate_status IN VARCHAR2 DEFAULT 'N',
                       x_return_status   OUT NOCOPY VARCHAR2,
                       x_msg_count       OUT NOCOPY NUMBER,
                       x_msg_data        OUT NOCOPY VARCHAR2,
                       p_line_id         IN NUMBER) IS
   
      --l_cov_cle_id NUMBER;
      --l_item_id    NUMBER;
      --l_contact_id NUMBER;
      l_rgp_id     NUMBER;
      --l_rule_id    NUMBER;
      --l_cle_id     NUMBER;
      v_index      BINARY_INTEGER;
   
      CURSOR line_det_cur(p_cle_id IN NUMBER) IS
         SELECT id, start_date, lse_id
           FROM okc_k_lines_b
          WHERE id = p_cle_id;
   
      CURSOR child_cur(p_cle_id IN NUMBER) IS
         SELECT dnz_chr_id FROM okc_k_lines_b WHERE cle_id = p_cle_id;
   
      CURSOR child_cur1(p_parent_id IN NUMBER) IS
         SELECT id, dnz_chr_id
           FROM okc_k_lines_b
          WHERE cle_id = p_parent_id;
   
      CURSOR child_cur2(p_parent_id IN NUMBER) IS
         SELECT id, dnz_chr_id
           FROM okc_k_lines_b
          WHERE cle_id = p_parent_id;
      CURSOR child_cur3(p_parent_id IN NUMBER) IS
         SELECT id, dnz_chr_id
           FROM okc_k_lines_b
          WHERE cle_id = p_parent_id;
      CURSOR child_cur4(p_parent_id IN NUMBER) IS
         SELECT id, dnz_chr_id
           FROM okc_k_lines_b
          WHERE cle_id = p_parent_id;
      CURSOR child_cur5(p_parent_id IN NUMBER) IS
         SELECT id, dnz_chr_id
           FROM okc_k_lines_b
          WHERE cle_id = p_parent_id;
   
      CURSOR item_cur(p_line_id IN NUMBER) IS
         SELECT id FROM okc_k_items WHERE cle_id = p_line_id;
   
      CURSOR rt_cur(p_rule_id IN NUMBER) IS
         SELECT tve_id FROM okc_react_intervals WHERE rul_id = p_rule_id;
   
      CURSOR kprl_cur(p_cle_id IN NUMBER) IS
         SELECT pr.id
           FROM okc_k_party_roles_b pr, okc_k_lines_v lv
          WHERE pr.cle_id = p_cle_id AND
                pr.cle_id = lv.id AND
                pr.dnz_chr_id = lv.dnz_chr_id;
   
      CURSOR contact_cur(p_cpl_id IN NUMBER) IS
         SELECT id FROM okc_contacts WHERE cpl_id = p_cpl_id;
   
      CURSOR trule_cur(p_rgp_id IN NUMBER, p_rule_type IN VARCHAR2) IS
         SELECT id
           FROM okc_rules_b
          WHERE rgp_id = p_rgp_id AND
                rule_information_category = p_rule_type;
   
      CURSOR rl_cur(p_rgp_id IN NUMBER) IS
         SELECT id FROM okc_rules_b WHERE rgp_id = p_rgp_id;
   
      CURSOR rgp_cur(p_cle_id IN NUMBER) IS
         SELECT id FROM okc_rule_groups_b WHERE cle_id = p_cle_id;
   
      CURSOR relobj_cur(p_cle_id IN NUMBER) IS
         SELECT id FROM okc_k_rel_objs_v WHERE cle_id = p_cle_id;
   
      CURSOR orderdetails_cur(p_chr_id IN NUMBER, p_cle_id IN NUMBER) IS
         SELECT id
           FROM oks_k_order_details_v
          WHERE chr_id = p_chr_id AND
                cle_id = p_cle_id;
   
      CURSOR salescredits_cur(p_cle_id IN NUMBER) IS
         SELECT id FROM oks_k_sales_credits_v WHERE cle_id = p_cle_id;
   
      CURSOR ordercontacts_cur(p_cod_id IN NUMBER) IS
         SELECT id FROM oks_k_order_contacts_v WHERE cod_id = p_cod_id;
   
      --n NUMBER := 0;
   
      --line_det_rec    line_det_cur%ROWTYPE;
      l_child_cur_rec child_cur%ROWTYPE;
      l_clev_tbl_in   okc_contract_pub.clev_tbl_type;
      l_clev_tbl_tmp  okc_contract_pub.clev_tbl_type;
      l_rgpv_tbl_in   okc_rule_pub.rgpv_tbl_type;
      l_rulv_tbl_in   okc_rule_pub.rulv_tbl_type;
      l_cimv_tbl_in   okc_contract_item_pub.cimv_tbl_type;
      l_ctcv_tbl_in   okc_contract_party_pub.ctcv_tbl_type;
      l_cplv_tbl_in   okc_contract_party_pub.cplv_tbl_type;
      l_crjv_tbl_in   okc_k_rel_objs_pub.crjv_tbl_type;
      l_cocv_tbl_in   oks_order_contacts_pub.cocv_tbl_type;
      l_codv_tbl_in   oks_order_details_pub.codv_tbl_type;
      l_scrv_tbl_in   oks_sales_credit_pub.scrv_tbl_type;
   
      l_api_version   CONSTANT NUMBER := 1.0;
      l_init_msg_list CONSTANT VARCHAR2(1) := 'T';
      l_return_status VARCHAR2(1);
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(2000) := NULL;
      --l_msg_index_out NUMBER;
      --l_api_name CONSTANT VARCHAR2(30) := 'Undo Line';
      --l_catv_tbl_in   okc_k_article_pub.catv_tbl_type;
      e_error EXCEPTION;
      c_clev                 NUMBER := 1;
      c_rulv                 NUMBER := 1;
      c_rgpv                 NUMBER := 1;
      c_cimv                 NUMBER := 1;
      c_ctcv                 NUMBER := 1;
      --c_catv                 NUMBER := 1;
      c_cplv                 NUMBER := 1;
      c_crjv                 NUMBER := 1;
      l_lse_id               NUMBER;
      c_cocv                 NUMBER := 1;
      c_codv                 NUMBER := 1;
      c_scrv                 NUMBER := 1;
      --l_dummy_terminate_date DATE;
      --l_line_type            NUMBER;
   
      FUNCTION bp_check(p_rgp_id IN NUMBER) RETURN BOOLEAN IS
         CURSOR getlse_cur IS
            SELECT kl.lse_id
              FROM okc_k_lines_v kl, okc_rule_groups_v rg
             WHERE kl.id = rg.cle_id AND
                   rg.id = p_rgp_id;
      
      BEGIN
      
         OPEN getlse_cur;
         FETCH getlse_cur
            INTO l_lse_id;
         IF NOT getlse_cur%FOUND THEN
            l_lse_id := NULL;
         END IF;
         CLOSE getlse_cur;
         IF l_lse_id IN (3, 16, 21) THEN
            RETURN TRUE;
         ELSE
            RETURN FALSE;
         END IF;
      END bp_check;
   
   BEGIN
      x_return_status := okc_api.g_ret_sts_success;
   
      validate_line_id(p_line_id, l_return_status);
      IF NOT l_return_status = okc_api.g_ret_sts_success THEN
         -- IF NOT l_Return_Status ='S' THEN
         RETURN;
      END IF;
   
      l_clev_tbl_tmp(c_clev).id := p_line_id;
   
      OPEN child_cur(p_line_id);
      FETCH child_cur
         INTO l_child_cur_rec;
      l_clev_tbl_tmp(c_clev).dnz_chr_id := l_child_cur_rec.dnz_chr_id;
   
      CLOSE child_cur;
   
      c_clev := c_clev + 1;
      FOR child_rec1 IN child_cur1(p_line_id) LOOP
         l_clev_tbl_tmp(c_clev).id := child_rec1.id;
         l_clev_tbl_tmp(c_clev).dnz_chr_id := child_rec1.dnz_chr_id;
         c_clev := c_clev + 1;
         FOR child_rec2 IN child_cur2(child_rec1.id) LOOP
            l_clev_tbl_tmp(c_clev).id := child_rec2.id;
            l_clev_tbl_tmp(c_clev).dnz_chr_id := child_rec2.dnz_chr_id;
            c_clev := c_clev + 1;
            FOR child_rec3 IN child_cur3(child_rec2.id) LOOP
               l_clev_tbl_tmp(c_clev).id := child_rec3.id;
               l_clev_tbl_tmp(c_clev).dnz_chr_id := child_rec3.dnz_chr_id;
               c_clev := c_clev + 1;
               FOR child_rec4 IN child_cur4(child_rec3.id) LOOP
                  l_clev_tbl_tmp(c_clev).id := child_rec4.id;
                  l_clev_tbl_tmp(c_clev).dnz_chr_id := child_rec4.dnz_chr_id;
                  c_clev := c_clev + 1;
                  FOR child_rec5 IN child_cur5(child_rec4.id) LOOP
                     l_clev_tbl_tmp(c_clev).id := child_rec5.id;
                     l_clev_tbl_tmp(c_clev).dnz_chr_id := child_rec5.dnz_chr_id;
                     c_clev := c_clev + 1;
                  END LOOP;
               END LOOP;
            END LOOP;
         END LOOP;
      END LOOP;
      c_clev := 1;
      FOR v_index IN REVERSE l_clev_tbl_tmp.FIRST .. l_clev_tbl_tmp.LAST LOOP
         l_clev_tbl_in(c_clev).id := l_clev_tbl_tmp(v_index).id;
         l_clev_tbl_in(c_clev).dnz_chr_id := l_clev_tbl_tmp(v_index)
                                            .dnz_chr_id;
         c_clev := c_clev + 1;
      END LOOP;
   
      -- Get Relational Objects Linked to the lines
      FOR v_index IN l_clev_tbl_in.FIRST .. l_clev_tbl_in.LAST LOOP
         FOR relobj_rec IN relobj_cur(l_clev_tbl_in(v_index).id) LOOP
            l_crjv_tbl_in(c_crjv).id := relobj_rec.id;
            c_crjv := c_crjv + 1;
         END LOOP;
      
         FOR orderdetails_rec IN orderdetails_cur(l_clev_tbl_in(v_index)
                                                  .dnz_chr_id,
                                                  l_clev_tbl_in(v_index).id) LOOP
            l_codv_tbl_in(c_codv).id := orderdetails_rec.id;
            FOR ordercontacts_rec IN ordercontacts_cur(l_codv_tbl_in(c_codv).id) LOOP
               l_cocv_tbl_in(c_cocv).id := ordercontacts_rec.id;
               c_cocv := c_cocv + 1;
            END LOOP;
            c_codv := c_codv + 1;
         END LOOP;
         FOR salescredits_rec IN salescredits_cur(l_clev_tbl_in(v_index).id) LOOP
            l_scrv_tbl_in(c_scrv).id := salescredits_rec.id;
            c_scrv := c_scrv + 1;
         END LOOP;
      
      END LOOP;
   
      -- Get Rule Groups and Rules
      FOR v_index IN l_clev_tbl_in.FIRST .. l_clev_tbl_in.LAST LOOP
         OPEN rgp_cur(l_clev_tbl_in(v_index).id);
         FETCH rgp_cur
            INTO l_rgp_id;
         IF rgp_cur%NOTFOUND THEN
            l_rgp_id := NULL;
         END IF;
         IF NOT l_rgp_id IS NULL THEN
            l_rgpv_tbl_in(c_rgpv).id := l_rgp_id;
            c_rgpv := c_rgpv + 1;
            FOR rl_rec IN rl_cur(l_rgp_id) LOOP
               l_rulv_tbl_in(c_rulv).id := rl_rec.id;
               c_rulv := c_rulv + 1;
            END LOOP;
         END IF;
         IF rgp_cur%ISOPEN THEN
            CLOSE rgp_cur;
         END IF;
      END LOOP;
   
      -- Get Items
      FOR v_index IN l_clev_tbl_in.FIRST .. l_clev_tbl_in.LAST LOOP
         FOR item_rec IN item_cur(l_clev_tbl_in(v_index).id) LOOP
            l_cimv_tbl_in(c_cimv).id := item_rec.id;
            c_cimv := c_cimv + 1;
         END LOOP;
      END LOOP;
      -- GET K Party Roles and Contacts
      FOR v_index IN l_clev_tbl_in.FIRST .. l_clev_tbl_in.LAST LOOP
         FOR kprl_rec IN kprl_cur(l_clev_tbl_in(v_index).id) LOOP
            l_cplv_tbl_in(c_cplv).id := kprl_rec.id;
            c_cplv := c_cplv + 1;
            FOR contact_rec IN contact_cur(kprl_rec.id) LOOP
               l_ctcv_tbl_in(c_ctcv).id := contact_rec.id;
               c_ctcv := c_ctcv + 1;
            END LOOP;
         END LOOP;
      END LOOP;
   
      IF NOT l_cocv_tbl_in.COUNT = 0 THEN
      
         oks_order_contacts_pub.delete_order_contact(p_api_version   => l_api_version,
                                                     p_init_msg_list => l_init_msg_list,
                                                     x_return_status => l_return_status,
                                                     x_msg_count     => l_msg_count,
                                                     x_msg_data      => l_msg_data,
                                                     p_cocv_tbl      => l_cocv_tbl_in);
      
         IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
            RETURN;
         END IF;
      END IF;
   
      IF NOT l_codv_tbl_in.COUNT = 0 THEN
      
         oks_order_details_pub.delete_order_detail(p_api_version   => l_api_version,
                                                   p_init_msg_list => l_init_msg_list,
                                                   x_return_status => l_return_status,
                                                   x_msg_count     => l_msg_count,
                                                   x_msg_data      => l_msg_data,
                                                   p_codv_tbl      => l_codv_tbl_in);
      
         IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
            RETURN;
         END IF;
      END IF;
   
      IF NOT l_scrv_tbl_in.COUNT = 0 THEN
      
         oks_sales_credit_pub.delete_sales_credit(p_api_version   => l_api_version,
                                                  p_init_msg_list => l_init_msg_list,
                                                  x_return_status => l_return_status,
                                                  x_msg_count     => l_msg_count,
                                                  x_msg_data      => l_msg_data,
                                                  p_scrv_tbl      => l_scrv_tbl_in);
      
         IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
            RETURN;
         END IF;
      END IF;
   
      IF NOT l_crjv_tbl_in.COUNT = 0 THEN
      
         okc_k_rel_objs_pub.delete_row(p_api_version   => l_api_version,
                                       p_init_msg_list => l_init_msg_list,
                                       x_return_status => l_return_status,
                                       x_msg_count     => l_msg_count,
                                       x_msg_data      => l_msg_data,
                                       p_crjv_tbl      => l_crjv_tbl_in);
      
         IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
            RETURN;
         END IF;
      END IF;
      IF NOT l_ctcv_tbl_in.COUNT = 0 THEN
         okc_contract_party_pub.delete_contact(p_api_version   => l_api_version,
                                               p_init_msg_list => l_init_msg_list,
                                               x_return_status => l_return_status,
                                               x_msg_count     => l_msg_count,
                                               x_msg_data      => l_msg_data,
                                               p_ctcv_tbl      => l_ctcv_tbl_in);
      
         IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
            RETURN;
         END IF;
      END IF;
      IF NOT l_cplv_tbl_in.COUNT = 0 THEN
         okc_contract_party_pub.delete_k_party_role(p_api_version   => l_api_version,
                                                    p_init_msg_list => l_init_msg_list,
                                                    x_return_status => l_return_status,
                                                    x_msg_count     => l_msg_count,
                                                    x_msg_data      => l_msg_data,
                                                    p_cplv_tbl      => l_cplv_tbl_in);
      
         IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
            RETURN;
         END IF;
      END IF;
      /*
      IF NOT l_rulv_tbl_in.COUNT=0 THEN
        -------delete level elements before deleting rules.
      
        OPEN line_det_cur(p_line_id);
        FETCH line_det_cur INTO line_det_rec;
      
        l_dummy_terminate_date := line_det_rec.start_date - 1;
      
        IF line_det_rec.lse_id = 1 OR line_det_rec.lse_id = 12 OR line_det_rec.lse_id = 14
          OR line_det_rec.lse_id = 19 THEN
      
          l_line_type := 1;             --1 for TOP line
        ELSE
      
          l_line_type := 2;             --2 for covered level
        END IF;
      
        CLOSE line_det_cur;
      
        ------ERROROUT_AD('l_line_lse_id = ' || TO_CHAR(line_det_rec.lse_id));
        ------ERROROUT_AD('l_line_type = ' || TO_CHAR(l_line_type));
        ------ERROROUT_AD('l_dummy_terminate_date = ' || TO_CHAR(l_dummy_terminate_date));
        ------ERROROUT_AD('P_line_id = '|| TO_CHAR(P_line_id));
        ------ERROROUT_AD('CALLING pre_del_level_elements');
      
        OKS_BILL_UTIL_PUB.pre_del_level_elements(
                                  p_api_version       => l_api_version,
                                  p_terminated_date   => l_dummy_terminate_date,
                                  p_id                => P_line_id ,
                                  p_flag              => l_line_type,
                                  x_return_status     => l_return_status);
      
        IF NOT nvl(l_return_status,'S') = OKC_API.G_RET_STS_SUCCESS THEN
           x_return_status := OKC_API.G_RET_STS_ERROR;
           OKC_API.Set_Message(G_APP_NAME,G_REQUIRED_VALUE,G_COL_NAME_TOKEN,'ERROR IN DELETING LEVEL_ELEMENTS');
           RETURN;
        END IF;
      
        okc_Rule_pub.delete_Rule (
              p_api_version         => l_api_version,
            p_init_msg_list      => l_init_msg_list,
               x_return_status      => l_return_status,
                x_msg_count         => l_msg_count,
                x_msg_data     => l_msg_data,
                p_rulv_tbl     => l_rulv_tbl_in);
      /---if not (l_return_status = OKC_API.G_RET_STS_SUCCESS)
      THEN
      
            IF l_msg_count > 0
            THEN
             FOR i in 1..l_msg_count
             LOOP
              fnd_msg_pub.get (p_msg_index     => -1,
                               p_encoded       => 'T', -- OKC$APPLICATION.GET_FALSE,
                               p_data          => l_msg_data,
                               p_msg_index_out => l_msg_index_out);
             END LOOP;
            END IF;---/
      IF NOT l_return_status = OKC_API.G_RET_STS_SUCCESS THEN
         RAISE e_Error;
      END IF;
      END IF;
      
      IF NOT l_rgpv_tbl_in.COUNT=0
      THEN
        okc_Rule_pub.delete_Rule_group (
              p_api_version         => l_api_version,
            p_init_msg_list      => l_init_msg_list,
               x_return_status      => l_return_status,
                x_msg_count         => l_msg_count,
                x_msg_data     => l_msg_data,
                p_rgpv_tbl     => l_rgpv_tbl_in);
      
         if not (l_return_status = OKC_API.G_RET_STS_SUCCESS)
         then
            return;
         end if;
      END IF;
      */
      IF NOT l_cimv_tbl_in.COUNT = 0 THEN
         okc_contract_item_pub.delete_contract_item(p_api_version   => l_api_version,
                                                    p_init_msg_list => l_init_msg_list,
                                                    x_return_status => l_return_status,
                                                    x_msg_count     => l_msg_count,
                                                    x_msg_data      => l_msg_data,
                                                    p_cimv_tbl      => l_cimv_tbl_in);
         /* IF nvl(l_return_status,'*') <> 'S'
         THEN
               IF l_msg_count > 0
               THEN
                FOR i in 1..l_msg_count
                LOOP
                 fnd_msg_pub.get (p_msg_index     => -1,
                                  p_encoded       => 'T', -- OKC$APPLICATION.GET_FALSE,
                                  p_data          => l_msg_data,
                                  p_msg_index_out => l_msg_index_out);
                END LOOP;
               END IF;
               RAISE e_Error; */
         IF NOT l_return_status = okc_api.g_ret_sts_success THEN
            RAISE e_error;
         END IF;
      END IF;
   
      IF NOT l_clev_tbl_in.COUNT = 0 THEN
         IF (p_validate_status = 'Y') THEN
            okc_contract_pub.delete_contract_line(p_api_version   => l_api_version,
                                                  p_init_msg_list => l_init_msg_list,
                                                  x_return_status => l_return_status,
                                                  x_msg_count     => l_msg_count,
                                                  x_msg_data      => l_msg_data,
                                                  p_clev_tbl      => l_clev_tbl_in);
         ELSE
            FOR i IN l_clev_tbl_in.FIRST .. l_clev_tbl_in.LAST LOOP
               BEGIN
                  DELETE okc_k_lines_tl WHERE id = l_clev_tbl_in(i).id;
                  DELETE okc_k_lines_b WHERE id = l_clev_tbl_in(i).id;
               
               EXCEPTION
                  WHEN OTHERS THEN
                     -- store SQL error message on message stack for caller
                     okc_api.set_message(g_app_name,
                                         g_unexpected_error,
                                         g_sqlcode_token,
                                         SQLCODE,
                                         g_sqlerrm_token,
                                         SQLERRM);
                     -- notify caller of an UNEXPECTED error
                     x_return_status := okc_api.g_ret_sts_unexp_error;
               END;
            END LOOP;
         END IF;
      
         /* IF nvl(l_return_status,'*') <> 'S'
         THEN
               IF l_msg_count > 0
               THEN
                FOR i in 1..l_msg_count
                LOOP
                 fnd_msg_pub.get (p_msg_index     => -1,
                                  p_encoded       => 'T', -- OKC$APPLICATION.GET_FALSE,
                                  p_data          => l_msg_data,
                                  p_msg_index_out => l_msg_index_out);
                END LOOP;
               END IF;
               RAISE e_Error;*/
         IF NOT l_return_status = okc_api.g_ret_sts_success THEN
            RAISE e_error;
         END IF;
      END IF;
   
      oks_coverages_pvt.undo_events(p_line_id, l_return_status, l_msg_data);
      IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
         RAISE e_error;
      END IF;
   
      oks_coverages_pvt.undo_counters(p_line_id,
                                      l_return_status,
                                      l_msg_data);
      IF NOT (l_return_status = okc_api.g_ret_sts_success) THEN
         RAISE e_error;
      END IF;
      x_return_status := l_return_status;
   
   EXCEPTION
      WHEN e_error THEN
         -- notify caller of an error as UNEXPETED error
         x_msg_count     := l_msg_count;
         x_msg_data      := l_msg_data;
         x_return_status := l_return_status;
         /*      x_return_status := OKC_API.HANDLE_EXCEPTIONS
               (
                 l_api_name,
                 'Undo_Line',
                 'OKC_API.G_RET_STS_ERROR',
                 l_msg_count,
                 l_msg_data,
                 '_PVT'
               );
             WHEN OKC_API.G_EXCEPTION_ERROR THEN
         x_msg_count :=l_msg_count;
         x_msg_data:=l_msg_data;
               x_return_status := OKC_API.HANDLE_EXCEPTIONS
               (
                 l_api_name,
                 'Undo_Line',
                 'OKC_API.G_RET_STS_ERROR',
                 l_msg_count,
                 l_msg_data,
                 '_PVT'
               );
             WHEN OKC_API.G_EXCEPTION_UNEXPECTED_ERROR THEN
         x_msg_count :=l_msg_count;
         x_msg_data:=l_msg_data;
               x_return_status :=OKC_API.HANDLE_EXCEPTIONS
               (
                 l_api_name,
                 'Undo_Line',
                 'OKC_API.G_RET_STS_UNEXP_ERROR',
                 l_msg_count,
                 l_msg_data,
                 '_PVT'
               );*/
      WHEN OTHERS THEN
         x_msg_count := l_msg_count;
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END undo_line;

   PROCEDURE check_coverage_match(p_api_version             IN NUMBER,
                                  p_init_msg_list           IN VARCHAR2 DEFAULT okc_api.g_false,
                                  x_return_status           OUT NOCOPY VARCHAR2,
                                  x_msg_count               OUT NOCOPY NUMBER,
                                  x_msg_data                OUT NOCOPY VARCHAR2,
                                  p_source_contract_line_id IN NUMBER,
                                  p_target_contract_line_id IN NUMBER,
                                  x_coverage_match          OUT NOCOPY VARCHAR2) IS
   
      --  First compare coverage
      CURSOR cur_get_cov_info(p_contract_line_id NUMBER) IS
         SELECT coverage_id, standard_cov_yn
           FROM oks_k_lines_b
          WHERE cle_id = p_contract_line_id;
      --  get the coverage info
   
      CURSOR cur_get_cov_details(p_cov_line_id NUMBER) IS
         SELECT NAME, item_description, exception_yn
           FROM okc_k_lines_v
          WHERE id = p_cov_line_id AND
                lse_id IN (2, 15, 20);
   
      CURSOR get_coverage_rules(p_cov_line_id NUMBER) IS
         SELECT coverage_type,
                exception_cov_id,
                inheritance_type,
                transfer_option,
                prod_upgrade_yn
         /* COmmented by Jvorugan for Bug:4610449  NVL(PM_PROGRAM_ID,0) PM_PROGRAM_ID,
                                                                                                                                     NVL(PM_CONF_REQ_YN,0) PM_CONF_REQ_YN,
                                                                                                                                     NVL(PM_SCH_EXISTS_YN,0) PM_SCH_EXISTS_YN */
           FROM oks_k_lines_b
          WHERE cle_id = p_cov_line_id;
   
      source_coverage_rules get_coverage_rules%ROWTYPE;
      target_coverage_rules get_coverage_rules%ROWTYPE;
   
      --Added by Jvorugan for Bug:4610449
      -- Cursor to get the PM info. With R12, PM info will be stored with oks_k_lines_b record for the topline
      CURSOR get_pm_rules(p_contract_line_id NUMBER) IS
         SELECT nvl(pm_program_id, 0) pm_program_id,
                nvl(pm_conf_req_yn, 0) pm_conf_req_yn,
                nvl(pm_sch_exists_yn, 0) pm_sch_exists_yn
           FROM oks_k_lines_b
          WHERE cle_id = p_contract_line_id;
   
      source_pm_rules get_pm_rules%ROWTYPE;
      target_pm_rules get_pm_rules%ROWTYPE;
   
      CURSOR cur_get_bussproc(p_cle_id NUMBER) IS
         SELECT lines.id,
                -- lines.start_date start_date,
                -- lines.end_date end_date,
                items.object1_id1
           FROM okc_k_lines_v lines, okc_k_items_v items
          WHERE lines.cle_id = p_cle_id AND
                lines.lse_id IN (3, 16, 21) AND
                items.jtot_object1_code = 'OKX_BUSIPROC' AND
                items.cle_id = lines.id;
   
      -- PRE AND DST RULES FOR A BP
   
      CURSOR cur_get_oks_bp(p_cle_id NUMBER) IS
         SELECT lines.id bp_line_id,
                nvl(lines.price_list_id, 0) price_list_id,
                items.object1_id1 object1_id1,
                nvl(kines.discount_list, 0) discount_list,
                nvl(kines.offset_duration, 0) offset_duration,
                nvl(kines.offset_period, 0) offset_period,
                nvl(kines.allow_bt_discount, 0) allow_bt_discount,
                nvl(kines.apply_default_timezone, 0) apply_default_timezone
           FROM okc_k_lines_b lines, okc_k_items items, oks_k_lines_b kines
          WHERE lines.cle_id = p_cle_id AND
                lines.id = items.cle_id AND
                items.jtot_object1_code = 'OKX_BUSIPROC' AND
                lines.lse_id IN (3, 16, 21) AND
                kines.cle_id = lines.id AND
                lines.dnz_chr_id = kines.dnz_chr_id AND
                lines.dnz_chr_id = items.dnz_chr_id;
   
      -- COVER TIMES FOR BUSINESS PROCESS
   
      CURSOR cur_get_cover_times(p_id NUMBER, p_bp_id NUMBER) IS
         SELECT lines.id,
                items.object1_id1 object1_id1,
                covtz.timezone_id timezone_id,
                covtz.default_yn default_yn,
                covtm.start_hour start_hour,
                covtm.start_minute start_minute,
                covtm.end_hour end_hour,
                covtm.end_minute end_minute,
                covtm.monday_yn monday_yn,
                covtm.tuesday_yn tuesday_yn,
                covtm.wednesday_yn wednesday_yn,
                covtm.thursday_yn thursday_yn,
                covtm.friday_yn friday_yn,
                covtm.saturday_yn saturday_yn,
                covtm.sunday_yn sunday_yn
           FROM okc_k_lines_b          lines,
                okc_k_items            items,
                oks_coverage_timezones covtz,
                oks_coverage_times     covtm
          WHERE lines.id = p_id AND
                lines.lse_id IN (3, 16, 21) AND
                lines.dnz_chr_id = items.dnz_chr_id AND
                items.cle_id = lines.id AND
                items.object1_id1 = p_bp_id AND
                items.jtot_object1_code = 'OKX_BUSIPROC' AND
                items.dnz_chr_id = lines.dnz_chr_id AND
                covtz.cle_id = lines.id AND
                covtz.dnz_chr_id = lines.dnz_chr_id AND
                covtm.cov_tze_line_id = covtz.id
          ORDER BY to_number(items.object1_id1), covtz.timezone_id;
   
      --    REACTION  TIMES FOR A BUSINESS PROCESS
   
      CURSOR cur_get_react_times(p_cle_id NUMBER) IS
         SELECT lines.id react_time_line_id,
                oksl.id oks_react_line_id,
                nvl(oksl.incident_severity_id, 0) incident_severity_id,
                nvl(oksl.pdf_id, 0) pdf_id,
                nvl(oksl.work_thru_yn, 'N') work_thru_yn,
                nvl(oksl.react_active_yn, 'N') react_active_yn,
                oksl.react_time_name react_time_name,
                act.id act_type_line_id,
                act.action_type_code action_type_code,
                acm.uom_code uom_code,
                nvl(acm.sun_duration, 0) sun_duration,
                nvl(acm.mon_duration, 0) mon_duration,
                nvl(acm.tue_duration, 0) tue_duration,
                nvl(acm.wed_duration, 0) wed_duration,
                nvl(acm.thu_duration, 0) thu_duration,
                nvl(acm.fri_duration, 0) fri_duration,
                nvl(acm.sat_duration, 0) sat_duration
           FROM okc_k_lines_b         lines,
                oks_k_lines_v         oksl,
                oks_action_time_types act,
                oks_action_times      acm
          WHERE lines.cle_id = p_cle_id AND
                lines.lse_id IN (4, 17, 22) AND
                oksl.cle_id = lines.id AND
                act.cle_id = lines.id AND
                act.dnz_chr_id = lines.dnz_chr_id AND
                acm.cov_action_type_id = act.id AND
                acm.dnz_chr_id = act.dnz_chr_id;
   
      -- RESOLUTION TIMES FOR A BUSINES PROCESS
   
      -- RESOURCES FOR A BUSINES PROCESS
   
      CURSOR cur_get_resources(p_bp_line_id NUMBER, p_bp_id NUMBER) IS
         SELECT lines.id           lines_id,
                party.id           party_id,
                items.object1_id1  bp_id,
                ocv.cro_code       cro_code,
                ocv.object1_id1    res_id,
                ocv.resource_class resource_class
           FROM okc_k_lines_v       lines,
                okc_k_party_roles_b party,
                okc_contacts_v      ocv,
                okc_k_items_v       items
          WHERE lines.id = p_bp_line_id AND
                lines.lse_id IN (3, 16, 21) AND
                party.cle_id = lines.id AND
                items.cle_id = lines.id AND
                items.object1_id1 = p_bp_id AND
                items.jtot_object1_code = 'OKX_BUSIPROC' AND
                party.id = ocv.cpl_id AND
                lines.dnz_chr_id = party.dnz_chr_id;
   
      -- BILLING TYPES  FOR A BUSINESS PROCESS
   
      CURSOR cur_get_bill_types(p_cle_id NUMBER) IS
         SELECT lines.id              bill_type_line_id,
                items.object1_id1     object1_id1,
                oksl.discount_amount  discount_amount,
                oksl.discount_percent discount_percent,
                txn.billing_type      billing_type
           FROM okc_k_lines_v           lines,
                oks_k_lines_b           oksl,
                okc_k_items_v           items,
                okx_txn_billing_types_v txn
          WHERE lines.cle_id = p_cle_id AND
                oksl.cle_id = lines.id AND
                oksl.dnz_chr_id = lines.dnz_chr_id AND
                items.cle_id = lines.id AND
                lines.lse_id IN (5, 23, 59) AND
                items.jtot_object1_code = 'OKX_BILLTYPE' AND
                items.object1_id1 = txn.id1;
   
      -- BILL RATES FOR A BUSINES PROCESS
   
      -- code changed for new bill rate schedules, 02/24/2003
   
      CURSOR cur_get_brs(p_bt_cle_id NUMBER) IS
         SELECT nvl(brs.start_hour, 0) start_hour,
                nvl(brs.start_minute, 0) start_minute,
                nvl(brs.end_hour, 0) end_hour,
                nvl(brs.end_minute, 0) end_minute,
                nvl(brs.monday_flag, 'N') monday_flag,
                nvl(brs.tuesday_flag, 'N') tuesday_flag,
                nvl(brs.wednesday_flag, 'N') wednesday_flag,
                nvl(brs.thursday_flag, 'N') thursday_flag,
                nvl(brs.friday_flag, 'N') friday_flag,
                nvl(brs.saturday_flag, 'N') saturday_flag,
                nvl(brs.sunday_flag, 'N') sunday_flag,
                nvl(brs.object1_id1, 'N') object1_id1,
                nvl(brs.object1_id2, 'N') object1_id2,
                nvl(brs.jtot_object1_code, 'N') jtot_object1_code,
                nvl(brs.bill_rate_code, 'N') bill_rate_code,
                nvl(brs.flat_rate, 0) flat_rate,
                nvl(brs.uom, 'N') uom,
                nvl(brs.holiday_yn, 'N') holiday_yn,
                nvl(brs.percent_over_list_price, 0) perc_over_list_price
           FROM oks_billrate_schedules brs
          WHERE brs.bt_cle_id = p_bt_cle_id;
   
      i                   NUMBER := 0;
      j                   NUMBER := 0;
      k                   NUMBER := 0;
      src_cvr_index       NUMBER := 0;
      tgt_cvr_index       NUMBER := 0;
      --l_source_start_date DATE;
      --l_source_end_date   DATE;
      --l_target_start_date DATE;
      --l_target_end_date   DATE;
      l_source_exp        okc_k_lines_v.exception_yn%TYPE;
      l_target_exp        okc_k_lines_v.exception_yn%TYPE;
      l_src_cov_id        NUMBER;
      l_tgt_cov_id        NUMBER;
      g_mismatch EXCEPTION;
      --l_return                BOOLEAN := TRUE;
      v_bp_found              BOOLEAN := FALSE;
      --l_bp                    VARCHAR2(100);
      src_index               NUMBER;
      tgt_index               NUMBER;
      src_res_index           NUMBER;
      tgt_res_index           NUMBER := 0;
      l_param                 NUMBER := 0;
      l_param2                NUMBER := 0;
      src_cvr_index1          NUMBER := 0;
      tgt_cvr_index1          NUMBER := 0;
      src_rcn_index           NUMBER := 0;
      tgt_rcn_index           NUMBER := 0;
      src_rcn_index1          NUMBER := 0;
      tgt_rcn_index1          NUMBER := 0;
      l_rcn                   NUMBER := 0;
      --l_rsn                   NUMBER := 0;
      --src_rsn_index           NUMBER := 0;
      --tgt_rsn_index           NUMBER := 0;
      --src_rsn_index1          NUMBER := 0;
      --tgt_rsn_index1          NUMBER := 0;
      src_bill_type_index     NUMBER := 0;
      tgt_bill_type_index     NUMBER := 0;
      src_bill_type_index1    NUMBER := 0;
      tgt_bill_type_index1    NUMBER := 0;
      l_bill_type             NUMBER := 0;
      --l_bill_rate_type        VARCHAR2(10);
      src_bill_rate_index     NUMBER := 0;
      tgt_bill_rate_index     NUMBER := 0;
      l_src_bill_rate_line_id NUMBER := 0;
      l_tgt_bill_rate_line_id NUMBER := 0;
      src_bill_rate_index1    NUMBER := 0;
      tgt_bill_rate_index1    NUMBER := 0;
      l_bill_rate             NUMBER := 0;
      src_bp_rule_index       NUMBER := 0;
      tgt_bp_rule_index       NUMBER := 0;
      src_bp_rule_index1      NUMBER := 0;
      tgt_bp_rule_index1      NUMBER := 0;
      l_bp_rule               NUMBER := 0;
      source_res_index        NUMBER := 0;
      target_res_index        NUMBER := 0;
      -- x_return_status           VARCHAR2(1);
      l_msg_count       NUMBER;
      l_msg_data        VARCHAR2(2000) := NULL;
      l_source_cov_name VARCHAR2(150);
      l_target_cov_name VARCHAR2(150);
      l_source_cov_desc okc_k_lines_v.item_description%TYPE;
      l_target_cov_desc okc_k_lines_v.item_description%TYPE;
      --l_pml_src_index   NUMBER := 0;
      --l_pml_tgt_index   NUMBER := 0;
      -- l_src_pml_index1           NUMBER:= 0;
      -- l_tgt_pml_index1           NUMBER:= 0;
      --l_pml_param     NUMBER := 0;
      --l_src_pml_index NUMBER;
      --src_pma_index1  NUMBER;
      --tgt_pma_index1  NUMBER;
      --l_pma_rule      VARCHAR2(1);
      --src_pma_index   NUMBER := 0;
      --tgt_pma_index   NUMBER := 0;
      -- GLOBAL VARIABLES
      l_api_version   CONSTANT NUMBER := 1.0;
      l_init_msg_list CONSTANT VARCHAR2(1) := 'F';
      l_return_status  VARCHAR2(1);
      l_pm_match       VARCHAR2(1);
      l_src_std_cov_yn VARCHAR2(1);
      l_tgt_std_cov_yn VARCHAR2(1);
   
   BEGIN
      -- R12 changes start
      OPEN cur_get_cov_info(p_source_contract_line_id);
      FETCH cur_get_cov_info
         INTO l_src_cov_id, l_src_std_cov_yn;
      CLOSE cur_get_cov_info;
   
      OPEN cur_get_cov_info(p_target_contract_line_id);
      FETCH cur_get_cov_info
         INTO l_tgt_cov_id, l_tgt_std_cov_yn;
      CLOSE cur_get_cov_info;
      -- If one standard coverage and the other one customized coverage, raise mismatch
      IF l_src_std_cov_yn <> l_tgt_std_cov_yn THEN
         RAISE g_mismatch;
      END IF;
      -- If both are standard coverage and are not same, raise mismatch
      IF l_src_std_cov_yn = 'Y' AND l_src_cov_id <> l_tgt_cov_id THEN
         RAISE g_mismatch;
      END IF;
   
      OPEN cur_get_cov_details(l_src_cov_id);
      FETCH cur_get_cov_details
         INTO l_source_cov_name, l_source_cov_desc,
      --l_source_start_date, l_source_end_date,
      l_source_exp;
      CLOSE cur_get_cov_details;
   
      OPEN cur_get_cov_details(l_tgt_cov_id);
      FETCH cur_get_cov_details
         INTO l_target_cov_name, l_target_cov_desc,
      --l_target_start_date, l_target_end_date,
      l_target_exp;
      CLOSE cur_get_cov_details;
   
      -- R12 changes end
   
      IF l_source_cov_name <> l_target_cov_name OR
         l_source_cov_desc <> l_target_cov_desc
        --OR l_source_start_date <> l_target_start_date
        --OR l_source_end_date <> l_target_end_date
         OR l_source_exp <> l_target_exp THEN
         RAISE g_mismatch;
      END IF;
   
      OPEN get_coverage_rules(l_src_cov_id);
      FETCH get_coverage_rules
         INTO source_coverage_rules;
      CLOSE get_coverage_rules;
   
      OPEN get_coverage_rules(l_tgt_cov_id);
      FETCH get_coverage_rules
         INTO target_coverage_rules;
      CLOSE get_coverage_rules;
   
      IF ((source_coverage_rules.coverage_type <>
         target_coverage_rules.coverage_type) OR
         (source_coverage_rules.exception_cov_id <>
         target_coverage_rules.exception_cov_id) OR
         (source_coverage_rules.transfer_option <>
         target_coverage_rules.transfer_option) OR
         (source_coverage_rules.prod_upgrade_yn <>
         target_coverage_rules.prod_upgrade_yn) OR
         (source_coverage_rules.inheritance_type <>
         target_coverage_rules.inheritance_type))
      /* Commented by Jvorugan for Bug:4610449. With R12 Pm info will be stored with oks_k_lines_b
                                                             record associated with the service line.
                                                              OR  (Source_Coverage_rules.PM_PROGRAM_ID     <> Target_Coverage_rules.PM_PROGRAM_ID )
                                                              OR  (Source_Coverage_rules.PM_CONF_REQ_YN    <> Target_Coverage_rules.PM_CONF_REQ_YN   )
                                                              OR  (Source_Coverage_rules.PM_SCH_EXISTS_YN  <> Target_Coverage_rules.PM_SCH_EXISTS_YN)) */
       THEN
      
         RAISE g_mismatch;
      END IF;
      -- Added by Jvorugan for Bug:4610449. R12 Changes start
      OPEN get_pm_rules(p_source_contract_line_id);
      FETCH get_pm_rules
         INTO source_pm_rules;
      CLOSE get_pm_rules;
   
      OPEN get_pm_rules(p_target_contract_line_id);
      FETCH get_pm_rules
         INTO target_pm_rules;
      CLOSE get_pm_rules;
   
      IF ((source_pm_rules.pm_program_id <> target_pm_rules.pm_program_id) OR
         (source_pm_rules.pm_conf_req_yn <> target_pm_rules.pm_conf_req_yn) OR
         (source_pm_rules.pm_sch_exists_yn <>
         target_pm_rules.pm_sch_exists_yn))
      
       THEN
         RAISE g_mismatch;
      END IF;
   
      IF ((source_pm_rules.pm_program_id IS NOT NULL) AND
         (target_pm_rules.pm_program_id IS NOT NULL)) THEN
      
         oks_pm_programs_pvt.check_pm_match(p_api_version             => l_api_version,
                                            p_init_msg_list           => l_init_msg_list,
                                            x_return_status           => l_return_status,
                                            x_msg_count               => l_msg_count,
                                            x_msg_data                => l_msg_data,
                                            p_source_coverage_line_id => p_source_contract_line_id, -- l_src_cov_id,commented by Jvorugan
                                            p_target_coverage_line_id => p_target_contract_line_id, -- l_tgt_cov_id,
                                            x_pm_match                => l_pm_match);
      
         IF l_pm_match <> 'Y' THEN
            RAISE g_mismatch;
         END IF;
      
      END IF;
   
      -- End of Changes for R12 by Jvorugan
      -------------------------Business Process ------------------------------
   
      FOR c1 IN cur_get_bussproc(l_src_cov_id) LOOP
         i := i + 1;
         x_source_bp_tbl_type(i).object1_id1 := c1.object1_id1;
         x_source_bp_tbl_type(i).bp_line_id := c1.id;
         --x_source_bp_tbl_type(i).start_date:= C1.start_date;
      --x_source_bp_tbl_type(i).end_date:= C1.end_date;
      END LOOP;
   
      FOR c2 IN cur_get_bussproc(l_tgt_cov_id) LOOP
         j := j + 1;
         x_target_bp_tbl_type(j).object1_id1 := c2.object1_id1;
         x_target_bp_tbl_type(j).bp_line_id := c2.id;
         --x_target_bp_tbl_type(j).start_date:= C2.start_date;
      --x_target_bp_tbl_type(j).end_date:= C2.end_date;
      END LOOP;
   
      IF x_source_bp_tbl_type.COUNT <> x_target_bp_tbl_type.COUNT THEN
      
         RAISE g_mismatch;
      END IF;
   
      IF x_source_bp_tbl_type.COUNT > 0 THEN
         FOR src_index IN x_source_bp_tbl_type.FIRST .. x_source_bp_tbl_type.LAST LOOP
         
            FOR tgt_index IN x_target_bp_tbl_type.FIRST .. x_target_bp_tbl_type.LAST LOOP
            
               IF x_source_bp_tbl_type(src_index)
               .object1_id1 = x_target_bp_tbl_type(tgt_index).object1_id1 THEN
                  /*
                        IF   ((x_source_bp_tbl_type(src_index).end_date <> x_target_bp_tbl_type(tgt_index).end_date)
                            OR (x_source_bp_tbl_type(src_index).start_date <> x_target_bp_tbl_type(tgt_index).start_date)) THEN
                  
                  
                            RAISE G_MISMATCH ;
                       END IF;
                  */
                  v_bp_found := TRUE;
                  k := k + 1;
                  l_bp_tbl(k).bp_id := x_source_bp_tbl_type(src_index)
                                      .object1_id1;
                  l_bp_tbl(k).src_bp_line_id := x_source_bp_tbl_type(src_index)
                                               .bp_line_id;
                  l_bp_tbl(k).tgt_bp_line_id := x_target_bp_tbl_type(tgt_index)
                                               .bp_line_id;
                  EXIT;
               END IF;
            END LOOP;
         
            IF NOT v_bp_found THEN
               RAISE g_mismatch;
            END IF;
            v_bp_found := FALSE;
         
         END LOOP;
      END IF;
      -------resource---
   
      IF l_bp_tbl.COUNT > 0 THEN
         -- IF 1
      
         FOR bp_index IN l_bp_tbl.FIRST .. l_bp_tbl.LAST LOOP
            -- LOOP 1
         
            source_res_index := 0;
         
            FOR c1 IN cur_get_resources(l_bp_tbl(bp_index).src_bp_line_id,
                                        to_number(l_bp_tbl(bp_index).bp_id)) LOOP
               -- LOOP 2
               source_res_index := source_res_index + 1;
               x_source_res_tbl_type(source_res_index).bp_id := c1.bp_id;
               x_source_res_tbl_type(source_res_index).cro_code := c1.cro_code;
               x_source_res_tbl_type(source_res_index).object1_id1 := c1.res_id;
               x_source_res_tbl_type(source_res_index).resource_class := c1.resource_class;
            END LOOP; -- LOOP 2
         
            target_res_index := 0;
         
            FOR c2 IN cur_get_resources(l_bp_tbl(bp_index).tgt_bp_line_id,
                                        to_number(l_bp_tbl(bp_index).bp_id)) LOOP
               -- LOOP 3
               target_res_index := target_res_index + 1;
               x_target_res_tbl_type(target_res_index).bp_id := c2.bp_id;
               x_target_res_tbl_type(target_res_index).cro_code := c2.cro_code;
               x_target_res_tbl_type(target_res_index).object1_id1 := c2.res_id;
               x_target_res_tbl_type(target_res_index).resource_class := c2.resource_class;
            END LOOP; -- LOOP 3
         
            IF x_source_res_tbl_type.COUNT <> x_target_res_tbl_type.COUNT THEN
               --IF 2
            
               RAISE g_mismatch;
            END IF; --IF 2
         
            IF x_source_res_tbl_type.COUNT > 0 THEN
               --IF 3
               FOR src_res_index IN x_source_res_tbl_type.FIRST .. x_source_res_tbl_type.LAST LOOP
                  --LOOP 4
               
                  tgt_res_index := x_target_res_tbl_type.FIRST;
               
                  LOOP
                     --LOOP 5
                  
                     IF x_source_res_tbl_type(src_res_index)
                     .cro_code = x_target_res_tbl_type(tgt_res_index)
                     .cro_code AND x_source_res_tbl_type(src_res_index)
                     .object1_id1 = x_target_res_tbl_type(tgt_res_index)
                     .object1_id1 AND
                        x_source_res_tbl_type(src_res_index)
                     .resource_class =
                        x_target_res_tbl_type(tgt_res_index)
                     .resource_class THEN
                     
                        l_param := 1;
                        EXIT;
                     
                     ELSE
                        l_param := 2;
                     END IF;
                  
                     EXIT WHEN(tgt_res_index = x_target_res_tbl_type.LAST);
                     tgt_res_index := x_target_res_tbl_type.NEXT(tgt_res_index);
                  
                  END LOOP; --LOOP 5
               
                  IF l_param = 2 THEN
                     RAISE g_mismatch;
                  END IF;
               END LOOP; --LOOP 4
            
            END IF;
         END LOOP; -- LOOP 1
      END IF;
   
      ---EnD resource---
      ------------------Buss Process OKS LINES--------------------
   
      FOR source_bp_rec IN cur_get_oks_bp(l_src_cov_id) LOOP
         src_bp_rule_index := src_bp_rule_index + 1;
      
         x_source_bp_tbl(src_bp_rule_index).price_list_id := source_bp_rec.price_list_id;
         x_source_bp_tbl(src_bp_rule_index).object1_id1 := source_bp_rec.object1_id1;
         x_source_bp_tbl(src_bp_rule_index).discount_list := source_bp_rec.discount_list;
         x_source_bp_tbl(src_bp_rule_index).offset_duration := source_bp_rec.offset_duration;
         x_source_bp_tbl(src_bp_rule_index).offset_period := source_bp_rec.offset_period;
         x_source_bp_tbl(src_bp_rule_index).allow_bt_discount := source_bp_rec.allow_bt_discount;
         x_source_bp_tbl(src_bp_rule_index).apply_default_timezone := source_bp_rec.apply_default_timezone;
      END LOOP;
   
      FOR target_bp_rec IN cur_get_oks_bp(l_tgt_cov_id) LOOP
      
         tgt_bp_rule_index := tgt_bp_rule_index + 1;
      
         x_target_bp_tbl(tgt_bp_rule_index).price_list_id := target_bp_rec.price_list_id;
         x_target_bp_tbl(tgt_bp_rule_index).object1_id1 := target_bp_rec.object1_id1;
         x_target_bp_tbl(tgt_bp_rule_index).discount_list := target_bp_rec.discount_list;
         x_target_bp_tbl(tgt_bp_rule_index).offset_duration := target_bp_rec.offset_duration;
         x_target_bp_tbl(tgt_bp_rule_index).offset_period := target_bp_rec.offset_period;
         x_target_bp_tbl(tgt_bp_rule_index).allow_bt_discount := target_bp_rec.allow_bt_discount;
         x_target_bp_tbl(tgt_bp_rule_index).apply_default_timezone := target_bp_rec.apply_default_timezone;
      
      END LOOP;
   
      IF x_source_bp_tbl.COUNT <> x_target_bp_tbl.COUNT THEN
      
         RAISE g_mismatch;
      END IF;
   
      IF x_source_bp_tbl.COUNT > 0 THEN
         --x_source_bp_tbl.count > 0
         FOR src_bp_rule_index1 IN x_source_bp_tbl.FIRST .. x_source_bp_tbl.LAST LOOP
            tgt_bp_rule_index1 := x_target_bp_tbl.FIRST;
         
            LOOP
            
               IF x_source_bp_tbl(src_bp_rule_index1)
               .object1_id1 = x_target_bp_tbl(tgt_bp_rule_index1)
               .object1_id1 AND x_source_bp_tbl(src_bp_rule_index1)
               .price_list_id = x_target_bp_tbl(tgt_bp_rule_index1)
               .price_list_id AND x_source_bp_tbl(src_bp_rule_index1)
               .discount_list = x_target_bp_tbl(tgt_bp_rule_index1)
               .discount_list AND x_source_bp_tbl(src_bp_rule_index1)
               .offset_duration = x_target_bp_tbl(tgt_bp_rule_index1)
               .offset_duration AND x_source_bp_tbl(src_bp_rule_index1)
               .offset_period = x_target_bp_tbl(tgt_bp_rule_index1)
               .offset_period AND x_source_bp_tbl(src_bp_rule_index1)
               .allow_bt_discount = x_target_bp_tbl(tgt_bp_rule_index1)
               .allow_bt_discount AND x_source_bp_tbl(src_bp_rule_index1)
               .apply_default_timezone =
                  x_target_bp_tbl(tgt_bp_rule_index1)
               .apply_default_timezone THEN
                  l_bp_rule := 1;
                  EXIT;
               ELSE
                  l_bp_rule := 2;
               END IF;
            
               EXIT WHEN(tgt_bp_rule_index1 = x_target_bp_tbl.LAST);
               tgt_bp_rule_index1 := x_target_bp_tbl.NEXT(tgt_bp_rule_index1);
            
            END LOOP;
         
            IF l_bp_rule = 2 THEN
               RAISE g_mismatch;
            END IF;
         
         END LOOP;
      
      END IF; --x_source_bp_tbl.count > 0
   
      ------------------Buss Process OKS LINES--------------------
   
      ------------------Coverage Times-------------------------
   
      src_cvr_index := 0;
   
      FOR i IN l_bp_tbl.FIRST .. l_bp_tbl.LAST LOOP
         FOR c1 IN cur_get_cover_times(l_bp_tbl(i).src_bp_line_id,
                                       l_bp_tbl(i).bp_id) LOOP
         
            src_cvr_index := src_cvr_index + 1;
         
            x_source_bp_cover_time_tbl(src_cvr_index).object1_id1 := c1.object1_id1;
            x_source_bp_cover_time_tbl(src_cvr_index).timezone_id := c1.timezone_id;
            x_source_bp_cover_time_tbl(src_cvr_index).default_yn := c1.default_yn;
            x_source_bp_cover_time_tbl(src_cvr_index).start_hour := c1.start_hour;
            x_source_bp_cover_time_tbl(src_cvr_index).start_minute := c1.start_minute;
            x_source_bp_cover_time_tbl(src_cvr_index).end_hour := c1.end_hour;
            x_source_bp_cover_time_tbl(src_cvr_index).end_minute := c1.end_minute;
            x_source_bp_cover_time_tbl(src_cvr_index).monday_yn := c1.monday_yn;
            x_source_bp_cover_time_tbl(src_cvr_index).tuesday_yn := c1.tuesday_yn;
            x_source_bp_cover_time_tbl(src_cvr_index).wednesday_yn := c1.wednesday_yn;
            x_source_bp_cover_time_tbl(src_cvr_index).thursday_yn := c1.thursday_yn;
            x_source_bp_cover_time_tbl(src_cvr_index).friday_yn := c1.friday_yn;
            x_source_bp_cover_time_tbl(src_cvr_index).saturday_yn := c1.saturday_yn;
            x_source_bp_cover_time_tbl(src_cvr_index).sunday_yn := c1.sunday_yn;
         END LOOP;
      END LOOP;
   
      tgt_cvr_index := 0;
      FOR i IN l_bp_tbl.FIRST .. l_bp_tbl.LAST LOOP
         FOR c2 IN cur_get_cover_times(l_bp_tbl(i).tgt_bp_line_id,
                                       l_bp_tbl(i).bp_id) LOOP
            tgt_cvr_index := tgt_cvr_index + 1;
         
            x_target_bp_cover_time_tbl(tgt_cvr_index).object1_id1 := c2.object1_id1;
            x_target_bp_cover_time_tbl(tgt_cvr_index).timezone_id := c2.timezone_id;
            x_target_bp_cover_time_tbl(tgt_cvr_index).default_yn := c2.default_yn;
            x_target_bp_cover_time_tbl(tgt_cvr_index).start_hour := c2.start_hour;
            x_target_bp_cover_time_tbl(tgt_cvr_index).start_minute := c2.start_minute;
            x_target_bp_cover_time_tbl(tgt_cvr_index).end_hour := c2.end_hour;
            x_target_bp_cover_time_tbl(tgt_cvr_index).end_minute := c2.end_minute;
            x_target_bp_cover_time_tbl(tgt_cvr_index).monday_yn := c2.monday_yn;
            x_target_bp_cover_time_tbl(tgt_cvr_index).tuesday_yn := c2.tuesday_yn;
            x_target_bp_cover_time_tbl(tgt_cvr_index).wednesday_yn := c2.wednesday_yn;
            x_target_bp_cover_time_tbl(tgt_cvr_index).thursday_yn := c2.thursday_yn;
            x_target_bp_cover_time_tbl(tgt_cvr_index).friday_yn := c2.friday_yn;
            x_target_bp_cover_time_tbl(tgt_cvr_index).saturday_yn := c2.saturday_yn;
            x_target_bp_cover_time_tbl(tgt_cvr_index).sunday_yn := c2.sunday_yn;
         
         END LOOP;
      END LOOP;
      IF x_source_bp_cover_time_tbl.COUNT <>
         x_target_bp_cover_time_tbl.COUNT THEN
      
         RAISE g_mismatch;
      END IF;
   
      IF x_source_bp_cover_time_tbl.COUNT > 0 THEN
         FOR src_cvr_index1 IN x_source_bp_cover_time_tbl.FIRST .. x_source_bp_cover_time_tbl.LAST LOOP
         
            tgt_cvr_index1 := x_target_bp_cover_time_tbl.FIRST;
         
            LOOP
            
               IF x_source_bp_cover_time_tbl(src_cvr_index1)
               .object1_id1 = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .object1_id1 AND
                  x_source_bp_cover_time_tbl(src_cvr_index1)
               .timezone_id = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .timezone_id AND
                  x_source_bp_cover_time_tbl(src_cvr_index1)
               .default_yn = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .default_yn AND x_source_bp_cover_time_tbl(src_cvr_index1)
               .start_hour = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .start_hour AND x_source_bp_cover_time_tbl(src_cvr_index1)
               .start_minute = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .start_minute AND
                  x_source_bp_cover_time_tbl(src_cvr_index1)
               .end_hour = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .end_hour AND x_source_bp_cover_time_tbl(src_cvr_index1)
               .end_minute = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .end_minute AND x_source_bp_cover_time_tbl(src_cvr_index1)
               .monday_yn = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .monday_yn AND x_source_bp_cover_time_tbl(src_cvr_index1)
               .tuesday_yn = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .tuesday_yn AND x_source_bp_cover_time_tbl(src_cvr_index1)
               .wednesday_yn = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .wednesday_yn AND
                  x_source_bp_cover_time_tbl(src_cvr_index1)
               .thursday_yn = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .thursday_yn AND
                  x_source_bp_cover_time_tbl(src_cvr_index1)
               .friday_yn = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .friday_yn AND x_source_bp_cover_time_tbl(src_cvr_index1)
               .saturday_yn = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .saturday_yn AND
                  x_source_bp_cover_time_tbl(src_cvr_index1)
               .sunday_yn = x_target_bp_cover_time_tbl(tgt_cvr_index1)
               .sunday_yn THEN
                  l_param2 := 1;
                  EXIT;
               ELSE
                  l_param2 := 2;
               END IF;
            
               EXIT WHEN(tgt_cvr_index1 = x_target_bp_cover_time_tbl.LAST);
               tgt_cvr_index1 := x_target_bp_cover_time_tbl.NEXT(tgt_cvr_index1);
            
            END LOOP;
         
            IF l_param2 = 2 THEN
            
               RAISE g_mismatch;
            END IF;
         
         END LOOP;
      END IF;
   
      ------------------ END Coverage Times-------------------------
      ------------------Reaction Times-------------------------
   
      src_rcn_index := 0;
      FOR i IN l_bp_tbl.FIRST .. l_bp_tbl.LAST LOOP
         FOR c1 IN cur_get_react_times(l_bp_tbl(i).src_bp_line_id) LOOP
            src_rcn_index := src_rcn_index + 1;
         
            x_source_react_time_tbl(src_rcn_index).incident_severity_id := c1.incident_severity_id;
            x_source_react_time_tbl(src_rcn_index).pdf_id := c1.pdf_id;
            x_source_react_time_tbl(src_rcn_index).work_thru_yn := c1.work_thru_yn;
            x_source_react_time_tbl(src_rcn_index).react_active_yn := c1.react_active_yn;
            x_source_react_time_tbl(src_rcn_index).react_time_name := c1.react_time_name;
            x_source_react_time_tbl(src_rcn_index).action_type_code := c1.action_type_code;
            x_source_react_time_tbl(src_rcn_index).uom_code := c1.uom_code;
            x_source_react_time_tbl(src_rcn_index).sun_duration := c1.sun_duration;
            x_source_react_time_tbl(src_rcn_index).mon_duration := c1.mon_duration;
            x_source_react_time_tbl(src_rcn_index).tue_duration := c1.tue_duration;
            x_source_react_time_tbl(src_rcn_index).wed_duration := c1.wed_duration;
            x_source_react_time_tbl(src_rcn_index).thu_duration := c1.thu_duration;
            x_source_react_time_tbl(src_rcn_index).fri_duration := c1.fri_duration;
            x_source_react_time_tbl(src_rcn_index).sat_duration := c1.wed_duration;
         
         END LOOP;
      END LOOP;
   
      tgt_rcn_index := 0;
      FOR i IN l_bp_tbl.FIRST .. l_bp_tbl.LAST LOOP
         FOR c2 IN cur_get_react_times(l_bp_tbl(i).tgt_bp_line_id) LOOP
            tgt_rcn_index := tgt_rcn_index + 1;
         
            x_target_react_time_tbl(tgt_rcn_index).incident_severity_id := c2.incident_severity_id;
            x_target_react_time_tbl(tgt_rcn_index).pdf_id := c2.pdf_id;
            x_target_react_time_tbl(tgt_rcn_index).work_thru_yn := c2.work_thru_yn;
            x_target_react_time_tbl(tgt_rcn_index).react_active_yn := c2.react_active_yn;
            x_target_react_time_tbl(tgt_rcn_index).react_time_name := c2.react_time_name;
            x_target_react_time_tbl(tgt_rcn_index).action_type_code := c2.action_type_code;
            x_target_react_time_tbl(tgt_rcn_index).uom_code := c2.uom_code;
            x_target_react_time_tbl(tgt_rcn_index).sun_duration := c2.sun_duration;
            x_target_react_time_tbl(tgt_rcn_index).mon_duration := c2.mon_duration;
            x_target_react_time_tbl(tgt_rcn_index).tue_duration := c2.tue_duration;
            x_target_react_time_tbl(tgt_rcn_index).wed_duration := c2.wed_duration;
            x_target_react_time_tbl(tgt_rcn_index).thu_duration := c2.thu_duration;
            x_target_react_time_tbl(tgt_rcn_index).fri_duration := c2.fri_duration;
            x_target_react_time_tbl(tgt_rcn_index).sat_duration := c2.wed_duration;
         
         END LOOP;
      END LOOP;
   
      -- NOW COMPARE THE SOURCE AND TARGET RCN TABLES
   
      IF x_source_react_time_tbl.COUNT <> x_target_react_time_tbl.COUNT THEN
         RAISE g_mismatch;
      END IF;
      IF x_source_react_time_tbl.COUNT > 0 THEN
         FOR src_rcn_index1 IN x_source_react_time_tbl.FIRST .. x_source_react_time_tbl.LAST LOOP
            tgt_rcn_index1 := x_target_react_time_tbl.FIRST;
            LOOP
            
               IF x_source_react_time_tbl(src_rcn_index1)
               .incident_severity_id =
                  x_target_react_time_tbl(tgt_rcn_index1)
               .incident_severity_id AND
                  x_source_react_time_tbl(src_rcn_index1)
               .pdf_id = x_target_react_time_tbl(tgt_rcn_index1)
               .pdf_id AND x_source_react_time_tbl(src_rcn_index1)
               .work_thru_yn = x_target_react_time_tbl(tgt_rcn_index1)
               .work_thru_yn AND x_source_react_time_tbl(src_rcn_index1)
               .react_active_yn = x_target_react_time_tbl(tgt_rcn_index1)
               .react_active_yn AND
                  x_source_react_time_tbl(src_rcn_index1)
               .react_time_name = x_target_react_time_tbl(tgt_rcn_index1)
               .react_time_name AND
                  x_source_react_time_tbl(src_rcn_index1)
               .action_type_code =
                  x_target_react_time_tbl(tgt_rcn_index1)
               .action_type_code AND
                  x_source_react_time_tbl(src_rcn_index1)
               .uom_code = x_target_react_time_tbl(tgt_rcn_index1)
               .uom_code AND x_source_react_time_tbl(src_rcn_index1)
               .sun_duration = x_target_react_time_tbl(tgt_rcn_index1)
               .sun_duration AND x_source_react_time_tbl(src_rcn_index1)
               .mon_duration = x_target_react_time_tbl(tgt_rcn_index1)
               .mon_duration AND x_source_react_time_tbl(src_rcn_index1)
               .tue_duration = x_target_react_time_tbl(tgt_rcn_index1)
               .tue_duration AND x_source_react_time_tbl(src_rcn_index1)
               .wed_duration = x_target_react_time_tbl(tgt_rcn_index1)
               .wed_duration AND x_source_react_time_tbl(src_rcn_index1)
               .thu_duration = x_target_react_time_tbl(tgt_rcn_index1)
               .thu_duration AND x_source_react_time_tbl(src_rcn_index1)
               .fri_duration = x_target_react_time_tbl(tgt_rcn_index1)
               .fri_duration AND x_source_react_time_tbl(src_rcn_index1)
               .sat_duration = x_target_react_time_tbl(tgt_rcn_index1)
               .sat_duration THEN
                  l_rcn := 1;
                  EXIT;
               
               ELSE
                  l_rcn := 2;
               END IF;
            
               EXIT WHEN(tgt_rcn_index1 = x_target_react_time_tbl.LAST);
               tgt_rcn_index1 := x_target_react_time_tbl.NEXT(tgt_rcn_index1);
            
            END LOOP; -- inner loop
         
            IF l_rcn = 2 THEN
               RAISE g_mismatch;
            END IF;
         END LOOP;
      END IF;
      ------------------ END Reaction Times-------------------------
   
      -------------------BILL TYPES/RATES--------------------------
   
      src_bill_type_index := 0;
      FOR i IN l_bp_tbl.FIRST .. l_bp_tbl.LAST LOOP
         FOR c1 IN cur_get_bill_types(l_bp_tbl(i).src_bp_line_id) LOOP
         
            src_bill_type_index := src_bill_type_index + 1;
         
            x_source_bill_tbl(src_bill_type_index).object1_id1 := c1.object1_id1;
            x_source_bill_tbl(src_bill_type_index).bill_type_line_id := c1.bill_type_line_id;
            x_source_bill_tbl(src_bill_type_index).billing_type := c1.billing_type;
            x_source_bill_tbl(src_bill_type_index).discount_amount := c1.discount_amount;
            x_source_bill_tbl(src_bill_type_index).discount_percent := c1.discount_percent;
         END LOOP;
      END LOOP;
   
      tgt_bill_type_index := 0;
   
      FOR i IN l_bp_tbl.FIRST .. l_bp_tbl.LAST LOOP
         FOR c2 IN cur_get_bill_types(l_bp_tbl(i).tgt_bp_line_id) LOOP
            tgt_bill_type_index := tgt_bill_type_index + 1;
            x_target_bill_tbl(tgt_bill_type_index).object1_id1 := c2.object1_id1;
            x_target_bill_tbl(tgt_bill_type_index).bill_type_line_id := c2.bill_type_line_id;
            x_target_bill_tbl(tgt_bill_type_index).billing_type := c2.billing_type;
            x_target_bill_tbl(tgt_bill_type_index).discount_amount := c2.discount_amount;
            x_target_bill_tbl(tgt_bill_type_index).discount_percent := c2.discount_percent;
         END LOOP;
      END LOOP;
   
      IF x_source_bill_tbl.COUNT <> x_target_bill_tbl.COUNT THEN
      
         RAISE g_mismatch;
      END IF;
   
      IF x_source_bill_tbl.COUNT > 0 THEN
         FOR src_bill_type_index1 IN x_source_bill_tbl.FIRST .. x_source_bill_tbl.LAST LOOP
         
            tgt_bill_type_index1 := x_target_bill_tbl.FIRST;
         
            LOOP
            
               IF ((x_source_bill_tbl(src_bill_type_index1)
                  .object1_id1 = x_target_bill_tbl(tgt_bill_type_index1)
                  .object1_id1) AND
                  (x_source_bill_tbl(src_bill_type_index1)
                  .billing_type = x_target_bill_tbl(tgt_bill_type_index1)
                  .billing_type) AND
                  (x_source_bill_tbl(src_bill_type_index1)
                  .discount_amount =
                   x_target_bill_tbl(tgt_bill_type_index1).discount_amount) AND
                  (x_source_bill_tbl(src_bill_type_index1)
                  .discount_percent =
                   x_target_bill_tbl(tgt_bill_type_index1).discount_percent)) THEN
               
                  l_bill_type := 1;
               
                  IF x_source_bill_tbl(src_bill_type_index1)
                  .billing_type = 'L' THEN
                     l_src_bill_rate_line_id := x_source_bill_tbl(src_bill_type_index1)
                                               .bill_type_line_id;
                  
                     src_bill_rate_index := 0;
                  
                     FOR src_brs_rec IN cur_get_brs(l_src_bill_rate_line_id) LOOP
                        src_bill_rate_index := src_bill_rate_index + 1;
                     
                        x_source_brs_tbl(src_bill_rate_index).start_hour := src_brs_rec.start_hour;
                        x_source_brs_tbl(src_bill_rate_index).start_minute := src_brs_rec.start_minute;
                        x_source_brs_tbl(src_bill_rate_index).end_hour := src_brs_rec.end_hour;
                        x_source_brs_tbl(src_bill_rate_index).end_minute := src_brs_rec.end_minute;
                        x_source_brs_tbl(src_bill_rate_index).monday_flag := src_brs_rec.monday_flag;
                        x_source_brs_tbl(src_bill_rate_index).tuesday_flag := src_brs_rec.tuesday_flag;
                        x_source_brs_tbl(src_bill_rate_index).wednesday_flag := src_brs_rec.wednesday_flag;
                        x_source_brs_tbl(src_bill_rate_index).thursday_flag := src_brs_rec.thursday_flag;
                        x_source_brs_tbl(src_bill_rate_index).friday_flag := src_brs_rec.friday_flag;
                        x_source_brs_tbl(src_bill_rate_index).saturday_flag := src_brs_rec.saturday_flag;
                        x_source_brs_tbl(src_bill_rate_index).sunday_flag := src_brs_rec.sunday_flag;
                        x_source_brs_tbl(src_bill_rate_index).object1_id1 := src_brs_rec.object1_id1;
                        x_source_brs_tbl(src_bill_rate_index).object1_id2 := src_brs_rec.object1_id2;
                        x_source_brs_tbl(src_bill_rate_index).jtot_object1_code := src_brs_rec.jtot_object1_code;
                        x_source_brs_tbl(src_bill_rate_index).bill_rate_code := src_brs_rec.bill_rate_code;
                        x_source_brs_tbl(src_bill_rate_index).flat_rate := src_brs_rec.flat_rate;
                        x_source_brs_tbl(src_bill_rate_index).uom := src_brs_rec.uom;
                        x_source_brs_tbl(src_bill_rate_index).holiday_yn := src_brs_rec.holiday_yn;
                        x_source_brs_tbl(src_bill_rate_index).percent_over_list_price := src_brs_rec.perc_over_list_price;
                     
                     END LOOP;
                  
                     l_tgt_bill_rate_line_id := x_target_bill_tbl(tgt_bill_type_index1)
                                               .bill_type_line_id;
                  
                     tgt_bill_rate_index := 0;
                  
                     FOR tgt_brs_rec IN cur_get_brs(l_tgt_bill_rate_line_id) LOOP
                        tgt_bill_rate_index := tgt_bill_rate_index + 1;
                     
                        x_target_brs_tbl(tgt_bill_rate_index).start_hour := tgt_brs_rec.start_hour;
                        x_target_brs_tbl(tgt_bill_rate_index).start_minute := tgt_brs_rec.start_minute;
                        x_target_brs_tbl(tgt_bill_rate_index).end_hour := tgt_brs_rec.end_hour;
                        x_target_brs_tbl(tgt_bill_rate_index).end_minute := tgt_brs_rec.end_minute;
                        x_target_brs_tbl(tgt_bill_rate_index).monday_flag := tgt_brs_rec.monday_flag;
                        x_target_brs_tbl(tgt_bill_rate_index).tuesday_flag := tgt_brs_rec.tuesday_flag;
                        x_target_brs_tbl(tgt_bill_rate_index).wednesday_flag := tgt_brs_rec.wednesday_flag;
                        x_target_brs_tbl(tgt_bill_rate_index).thursday_flag := tgt_brs_rec.thursday_flag;
                        x_target_brs_tbl(tgt_bill_rate_index).friday_flag := tgt_brs_rec.friday_flag;
                        x_target_brs_tbl(tgt_bill_rate_index).saturday_flag := tgt_brs_rec.saturday_flag;
                        x_target_brs_tbl(tgt_bill_rate_index).sunday_flag := tgt_brs_rec.sunday_flag;
                        x_target_brs_tbl(tgt_bill_rate_index).object1_id1 := tgt_brs_rec.object1_id1;
                        x_target_brs_tbl(tgt_bill_rate_index).object1_id2 := tgt_brs_rec.object1_id2;
                        x_target_brs_tbl(tgt_bill_rate_index).jtot_object1_code := tgt_brs_rec.jtot_object1_code;
                        x_target_brs_tbl(tgt_bill_rate_index).bill_rate_code := tgt_brs_rec.bill_rate_code;
                        x_target_brs_tbl(tgt_bill_rate_index).flat_rate := tgt_brs_rec.flat_rate;
                        x_target_brs_tbl(tgt_bill_rate_index).uom := tgt_brs_rec.uom;
                        x_target_brs_tbl(tgt_bill_rate_index).holiday_yn := tgt_brs_rec.holiday_yn;
                        x_target_brs_tbl(tgt_bill_rate_index).percent_over_list_price := tgt_brs_rec.perc_over_list_price;
                     
                     END LOOP;
                  
                     IF x_source_brs_tbl.COUNT <> x_target_brs_tbl.COUNT THEN
                     
                        RAISE g_mismatch;
                     END IF;
                  
                     IF x_source_brs_tbl.COUNT > 0 THEN
                        FOR src_bill_rate_index1 IN x_source_brs_tbl.FIRST .. x_source_brs_tbl.LAST LOOP
                           tgt_bill_rate_index1 := x_target_brs_tbl.FIRST;
                        
                           LOOP
                              IF x_source_brs_tbl(src_bill_rate_index1)
                              .start_hour =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .start_hour AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .start_minute =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .start_minute AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .end_hour =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .end_hour AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .end_minute =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .end_minute AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .monday_flag =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .monday_flag AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .tuesday_flag =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .tuesday_flag AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .wednesday_flag =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .wednesday_flag AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .thursday_flag =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .thursday_flag AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .friday_flag =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .friday_flag AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .saturday_flag =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .saturday_flag AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .sunday_flag =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .sunday_flag AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .object1_id1 =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .object1_id1 AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .object1_id2 =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .object1_id2 AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .jtot_object1_code =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .jtot_object1_code AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .bill_rate_code =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .bill_rate_code AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .flat_rate =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .flat_rate AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .uom =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .uom AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .holiday_yn =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .holiday_yn AND
                                 x_source_brs_tbl(src_bill_rate_index1)
                              .percent_over_list_price =
                                 x_target_brs_tbl(tgt_bill_rate_index1)
                              .percent_over_list_price THEN
                              
                                 l_bill_rate := 1;
                              
                                 EXIT;
                              
                              ELSE
                                 l_bill_rate := 2;
                              END IF;
                           
                              EXIT WHEN(tgt_bill_rate_index1 =
                                        x_target_brs_tbl.LAST);
                              tgt_bill_rate_index1 := x_target_brs_tbl.NEXT(tgt_bill_rate_index1);
                           
                           END LOOP;
                           IF l_bill_rate = 2 THEN
                           
                              RAISE g_mismatch;
                           END IF;
                        END LOOP;
                     END IF;
                  END IF; -- for labor type = 'L'
                  EXIT;
               
               ELSE
                  l_bill_type := 2;
               END IF;
            
               EXIT WHEN(tgt_bill_type_index1 = x_target_bill_tbl.LAST);
               tgt_bill_type_index1 := x_target_bill_tbl.NEXT(tgt_bill_type_index1);
            
            END LOOP; -- INNER LOOP
            IF l_bill_type = 2 THEN
            
               RAISE g_mismatch;
            END IF;
         END LOOP; -- outer loop
      END IF;
   
      -------------------END BILL TYPES/RATES--------------------------
   
      x_source_bp_tbl.DELETE;
      x_target_bp_tbl.DELETE;
      x_source_res_tbl_type.DELETE;
      x_target_res_tbl_type.DELETE;
      x_source_bp_cover_time_tbl.DELETE;
      x_target_bp_cover_time_tbl.DELETE;
      x_source_react_time_tbl.DELETE;
      x_target_react_time_tbl.DELETE;
      x_source_bill_tbl.DELETE;
      x_target_bill_tbl.DELETE;
      x_source_brs_tbl.DELETE;
      x_target_brs_tbl.DELETE;
   
      x_return_status  := okc_api.g_ret_sts_success;
      x_coverage_match := 'Y';
   
   EXCEPTION
   
      WHEN g_mismatch THEN
         x_coverage_match := 'N';
         x_return_status  := okc_api.g_ret_sts_success;
      
      WHEN OTHERS THEN
         okc_api.set_message(g_app_name,
                             g_unexpected_error,
                             g_sqlcode_token,
                             SQLCODE,
                             g_sqlerrm_token,
                             SQLERRM);
         -- notify caller of an UNEXPECTED error
         x_return_status  := okc_api.g_ret_sts_unexp_error;
         x_coverage_match := 'E';
      
   END check_coverage_match;

   PROCEDURE check_timezone_exists(p_api_version     IN NUMBER,
                                   p_init_msg_list   IN VARCHAR2 DEFAULT okc_api.g_false,
                                   x_return_status   OUT NOCOPY VARCHAR2,
                                   x_msg_count       OUT NOCOPY NUMBER,
                                   x_msg_data        OUT NOCOPY VARCHAR2,
                                   p_bp_line_id      IN NUMBER,
                                   p_timezone_id     IN NUMBER,
                                   x_timezone_exists OUT NOCOPY VARCHAR2) IS
   
      l_cle_id      NUMBER;
      l_timezone_id NUMBER;
      l_dummy       VARCHAR2(1) := NULL;
   
      CURSOR check_covtime_zone(l_cle_id IN NUMBER, l_timezone_id IN NUMBER) IS
         SELECT 'X'
           FROM oks_coverage_timezones
          WHERE cle_id = l_cle_id AND
                timezone_id = l_timezone_id;
   
   BEGIN
   
      l_cle_id      := p_bp_line_id;
      l_timezone_id := p_timezone_id;
   
      OPEN check_covtime_zone(l_cle_id, l_timezone_id);
      FETCH check_covtime_zone
         INTO l_dummy;
      CLOSE check_covtime_zone;
   
      IF l_dummy = 'X' THEN
         x_timezone_exists := 'Y';
      ELSE
         x_timezone_exists := 'N';
      END IF;
   
      x_return_status := okc_api.g_ret_sts_success;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
      
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END check_timezone_exists;

   PROCEDURE create_adjusted_coverage(p_api_version             IN NUMBER,
                                      p_init_msg_list           IN VARCHAR2 DEFAULT okc_api.g_false,
                                      x_return_status           OUT NOCOPY VARCHAR2,
                                      x_msg_count               OUT NOCOPY NUMBER,
                                      x_msg_data                OUT NOCOPY VARCHAR2,
                                      p_source_contract_line_id IN NUMBER,
                                      p_target_contract_line_id IN NUMBER,
                                      x_actual_coverage_id      OUT NOCOPY NUMBER) IS
   
      CURSOR cur_linedet(p_line_id IN NUMBER) IS
         SELECT id
           FROM okc_k_lines_v
          WHERE cle_id = p_line_id AND
                lse_id IN (2, 15, 20);
   
      CURSOR cur_linedet1(p_line_id IN NUMBER) IS
         SELECT start_date, end_date
           FROM okc_k_lines_v
          WHERE id = p_line_id;
   
      l_cov_id     okc_k_lines_v.id%TYPE;
      l_start_date okc_k_lines_v.start_date%TYPE;
      l_end_date   okc_k_lines_v.end_date%TYPE;
   
      l_api_version   CONSTANT NUMBER := 1.0;
      --l_init_msg_list CONSTANT VARCHAR2(1) := 'F';
      l_return_status VARCHAR2(1);
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(2000) := NULL;
      --l_msg_index_out NUMBER;
      l_source_contract_line_id CONSTANT NUMBER := p_source_contract_line_id;
      l_target_contract_line_id CONSTANT NUMBER := p_target_contract_line_id;
      l_actual_coverage_id NUMBER;
      --l_api_name CONSTANT VARCHAR2(30) := 'create_adjusted_coverage';
      l_ac_rec_in oks_coverages_pvt.ac_rec_type;
   
      -----------------------------------------
   BEGIN
   
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.set_indentation('Create_Adjusted_Coverage');
         okc_debug.log('Entered Create_Adjusted_Coverage', 2);
      END IF;
   
      l_ac_rec_in.svc_cle_id := l_target_contract_line_id;
   
      OPEN cur_linedet(l_source_contract_line_id);
      FETCH cur_linedet
         INTO l_cov_id;
      IF cur_linedet%FOUND THEN
         l_ac_rec_in.tmp_cle_id := l_cov_id;
      ELSE
         okc_api.set_message(g_app_name,
                             g_invalid_value,
                             g_col_name_token,
                             'Coverage does not exist');
         CLOSE cur_linedet;
         l_return_status := okc_api.g_ret_sts_error;
         RAISE g_exception_halt_validation;
      END IF;
      CLOSE cur_linedet;
   
      OPEN cur_linedet1(l_target_contract_line_id);
      FETCH cur_linedet1
         INTO l_start_date, l_end_date;
      IF cur_linedet1%FOUND THEN
         l_ac_rec_in.start_date := l_start_date;
         l_ac_rec_in.end_date   := l_end_date;
      ELSE
         okc_api.set_message(g_app_name,
                             g_invalid_value,
                             g_col_name_token,
                             'Target contract line does not exist');
         CLOSE cur_linedet1;
         l_return_status := okc_api.g_ret_sts_error;
         RAISE g_exception_halt_validation;
      END IF;
      CLOSE cur_linedet1;
   
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.log('Before create_actual_coverage', 2);
      END IF;
   
      oks_coverages_pvt.create_actual_coverage(p_api_version        => l_api_version,
                                               p_init_msg_list      => 'F',
                                               x_return_status      => l_return_status,
                                               x_msg_count          => l_msg_count,
                                               x_msg_data           => l_msg_data,
                                               p_ac_rec_in          => l_ac_rec_in,
                                               p_restricted_update  => 'T', -- 'F', modified based on bug 5493713
                                               x_actual_coverage_id => l_actual_coverage_id);
   
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.log('After create_actual_coverage ' || l_return_status,
                       2);
      END IF;
   
      /*  IF nvl(l_return_status,'*') <> 'S'
      THEN
        IF l_msg_count > 0
        THEN
          FOR i in 1..l_msg_count
          LOOP
            fnd_msg_pub.get (p_msg_index     => -1,
                         p_encoded       => 'T', -- OKC$APPLICATION.GET_FALSE,
                         p_data          => l_msg_data,
                         p_msg_index_out => l_msg_index_out);
          END LOOP;
        END IF;*/
   
      IF NOT l_return_status = okc_api.g_ret_sts_success THEN
         RAISE g_exception_halt_validation;
      END IF;
   
      x_return_status      := l_return_status;
      x_actual_coverage_id := l_actual_coverage_id;
   
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.log('End of CREATE_ADJUSTED_COVERAGE' ||
                       l_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Exp of CREATE_ADJUSTED_COVERAGE' || SQLERRM, 2);
            okc_debug.reset_indentation;
         END IF;
         x_return_status := l_return_status;
         /*    x_msg_count :=l_msg_count;
           x_msg_data:=l_msg_data;
           x_return_status := OKC_API.HANDLE_EXCEPTIONS
           (
             l_api_name,
             'Create_actual_coverage',
             'OKC_API.G_RET_STS_ERROR',
             x_msg_count,
             x_msg_data,
             '_PVT'
           );
         WHEN OKC_API.G_EXCEPTION_ERROR THEN
           x_msg_count :=l_msg_count;
           x_msg_data:=l_msg_data;
           x_return_status := OKC_API.HANDLE_EXCEPTIONS
           (
             l_api_name,
             'Create_actual_coverage',
             'OKC_API.G_RET_STS_ERROR',
             x_msg_count,
             x_msg_data,
             '_PVT'
           );
         WHEN OKC_API.G_EXCEPTION_UNEXPECTED_ERROR THEN
           x_msg_count :=l_msg_count;
           x_msg_data:=l_msg_data;
           x_return_status :=OKC_API.HANDLE_EXCEPTIONS
           (
             l_api_name,
             'Create_actual_coverage',
             'OKC_API.G_RET_STS_UNEXP_ERROR',
             x_msg_count,
             x_msg_data,
             '_PVT'
           );
           */
   
      WHEN OTHERS THEN
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Exp of CREATE_ADJUSTED_COVERAGE' || SQLERRM, 2);
            okc_debug.reset_indentation;
         END IF;
      
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
         x_msg_count     := l_msg_count;
   END create_adjusted_coverage;

   --=============================================================================

   PROCEDURE init_bill_rate_line(x_bill_rate_tbl OUT NOCOPY oks_brs_pvt.oksbillrateschedulesvtbltype) IS
   
   BEGIN
   
      x_bill_rate_tbl(1).id := okc_api.g_miss_num;
      x_bill_rate_tbl(1).cle_id := okc_api.g_miss_num;
      x_bill_rate_tbl(1).bt_cle_id := okc_api.g_miss_num;
      x_bill_rate_tbl(1).dnz_chr_id := okc_api.g_miss_num;
      x_bill_rate_tbl(1).start_hour := okc_api.g_miss_num;
      x_bill_rate_tbl(1).start_minute := okc_api.g_miss_num;
      x_bill_rate_tbl(1).end_hour := okc_api.g_miss_num;
      x_bill_rate_tbl(1).end_minute := okc_api.g_miss_num;
      x_bill_rate_tbl(1).monday_flag := okc_api.g_miss_char;
      x_bill_rate_tbl(1).tuesday_flag := okc_api.g_miss_char;
      x_bill_rate_tbl(1).wednesday_flag := okc_api.g_miss_char;
      x_bill_rate_tbl(1).thursday_flag := okc_api.g_miss_char;
      x_bill_rate_tbl(1).friday_flag := okc_api.g_miss_char;
      x_bill_rate_tbl(1).saturday_flag := okc_api.g_miss_char;
      x_bill_rate_tbl(1).sunday_flag := okc_api.g_miss_char;
      x_bill_rate_tbl(1).object1_id1 := okc_api.g_miss_char;
      x_bill_rate_tbl(1).object1_id2 := okc_api.g_miss_char;
      x_bill_rate_tbl(1).jtot_object1_code := okc_api.g_miss_char;
      x_bill_rate_tbl(1).bill_rate_code := okc_api.g_miss_char;
      x_bill_rate_tbl(1).flat_rate := okc_api.g_miss_num;
      x_bill_rate_tbl(1).uom := okc_api.g_miss_char;
      x_bill_rate_tbl(1).holiday_yn := okc_api.g_miss_char;
      x_bill_rate_tbl(1).percent_over_list_price := okc_api.g_miss_num;
      x_bill_rate_tbl(1).program_application_id := okc_api.g_miss_num;
      x_bill_rate_tbl(1).program_id := okc_api.g_miss_num;
      x_bill_rate_tbl(1).program_update_date := okc_api.g_miss_date;
      x_bill_rate_tbl(1).request_id := okc_api.g_miss_num;
      x_bill_rate_tbl(1).created_by := okc_api.g_miss_num;
      x_bill_rate_tbl(1).creation_date := okc_api.g_miss_date;
      x_bill_rate_tbl(1).last_updated_by := okc_api.g_miss_num;
      x_bill_rate_tbl(1).last_update_date := okc_api.g_miss_date;
      x_bill_rate_tbl(1).last_update_login := okc_api.g_miss_num;
      x_bill_rate_tbl(1).security_group_id := okc_api.g_miss_num;
   
   END;
   --===========================================================================================

   PROCEDURE validate_billrate_schedule(p_billtype_line_id IN NUMBER,
                                        p_holiday_yn       IN VARCHAR2,
                                        x_days_overlap     OUT NOCOPY billrate_day_overlap_type,
                                        x_return_status    OUT NOCOPY VARCHAR2) IS
   
      TYPE billrate_schedule_rec IS RECORD(
         start_time NUMBER,
         end_time   NUMBER);
      TYPE billrate_schedule_tbl_type IS TABLE OF billrate_schedule_rec INDEX BY BINARY_INTEGER;
      i                 NUMBER := 0;
      l_overlap_yn      VARCHAR2(1);
      --l_overlap_message VARCHAR2(200);
   
      l_time_tbl     billrate_schedule_tbl_type;
      l_api_name     VARCHAR2(50) := 'VALIDATE_BILLRATE_SCHEDULE';
      x_msg_count    NUMBER;
      x_msg_data     VARCHAR2(2000);
      l_overlap_days VARCHAR2(1000) := NULL;
   
      CURSOR cur_monday(l_bt_id IN NUMBER, l_holiday IN VARCHAR2) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_billrate_schedules_v
          WHERE bt_cle_id = l_bt_id AND
                monday_flag = 'Y' AND
                holiday_yn = l_holiday;
   
      CURSOR cur_tuesday(l_bt_id IN NUMBER, l_holiday IN VARCHAR2) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_billrate_schedules_v
          WHERE bt_cle_id = l_bt_id AND
                tuesday_flag = 'Y' AND
                holiday_yn = l_holiday;
   
      CURSOR cur_wednesday(l_bt_id IN NUMBER, l_holiday IN VARCHAR2) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_billrate_schedules_v
          WHERE bt_cle_id = l_bt_id AND
                wednesday_flag = 'Y' AND
                holiday_yn = l_holiday;
   
      CURSOR cur_thursday(l_bt_id IN NUMBER, l_holiday IN VARCHAR2) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_billrate_schedules_v
          WHERE bt_cle_id = l_bt_id AND
                thursday_flag = 'Y' AND
                holiday_yn = l_holiday;
   
      CURSOR cur_friday(l_bt_id IN NUMBER, l_holiday IN VARCHAR2) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_billrate_schedules_v
          WHERE bt_cle_id = l_bt_id AND
                friday_flag = 'Y' AND
                holiday_yn = l_holiday;
   
      CURSOR cur_saturday(l_bt_id IN NUMBER, l_holiday IN VARCHAR2) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_billrate_schedules_v
          WHERE bt_cle_id = l_bt_id AND
                saturday_flag = 'Y' AND
                holiday_yn = l_holiday;
   
      CURSOR cur_sunday(l_bt_id IN NUMBER, l_holiday IN VARCHAR2) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_billrate_schedules_v
          WHERE bt_cle_id = l_bt_id AND
                sunday_flag = 'Y' AND
                holiday_yn = l_holiday;
   
      --Define cursors for other days.
      FUNCTION get_day_meaning(p_day_code IN VARCHAR2) RETURN VARCHAR2 IS
         CURSOR get_day IS
            SELECT meaning
              FROM fnd_lookups
             WHERE lookup_type = 'DAY_NAME' AND
                   lookup_code = p_day_code;
         l_day_meaning VARCHAR2(100);
      
      BEGIN
         OPEN get_day;
         FETCH get_day
            INTO l_day_meaning;
         CLOSE get_day;
         RETURN nvl(l_day_meaning, NULL);
      END get_day_meaning;
   
      PROCEDURE check_overlap(p_time_tbl   IN billrate_schedule_tbl_type,
                              p_overlap_yn OUT NOCOPY VARCHAR2) IS
      
         l_start NUMBER;
         l_end   NUMBER;
      
         l_start_new NUMBER;
         l_end_new   NUMBER;
         j           NUMBER := 0;
         k           NUMBER := 0;
      
      BEGIN
         p_overlap_yn := 'N';
         FOR j IN 1 .. p_time_tbl.COUNT LOOP
            l_start := p_time_tbl(j).start_time;
            l_end   := p_time_tbl(j).end_time;
         
            FOR k IN 1 .. p_time_tbl.COUNT LOOP
               l_start_new := p_time_tbl(k).start_time;
               l_end_new   := p_time_tbl(k).end_time;
               IF j <> k THEN
                  IF (l_start_new <= l_end AND l_start_new >= l_start) OR
                     (l_end_new >= l_start AND l_end_new <= l_end) THEN
                  
                     IF (l_start_new = l_end) OR (l_end_new = l_start) THEN
                        IF p_overlap_yn <> 'Y' THEN
                           p_overlap_yn := 'N';
                        END IF;
                     ELSE
                        p_overlap_yn := 'Y';
                     END IF;
                  
                  END IF;
               END IF;
            END LOOP;
         
         END LOOP;
      
         --write the validation logic
      END check_overlap;
   
   BEGIN
      --l_overlap_message := 'The following days have overlap :';
      -- Validating for Monday.
      x_return_status := okc_api.g_ret_sts_success;
      l_time_tbl.DELETE;
      FOR monday_rec IN cur_monday(p_billtype_line_id, p_holiday_yn) LOOP
      
         i := i + 1;
         l_time_tbl(i).start_time := monday_rec.start_time;
         l_time_tbl(i).end_time := monday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
   
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.monday_overlap);
      
         IF x_days_overlap.monday_overlap = 'Y' THEN
            l_overlap_days := get_day_meaning('MON') || ',';
         END IF;
      
      END IF;
   
      -- Validating for Tuesday.
   
      l_time_tbl.DELETE;
      i := 0;
   
      FOR tuesday_rec IN cur_tuesday(p_billtype_line_id, p_holiday_yn) LOOP
         i := i + 1;
         l_time_tbl(i).start_time := tuesday_rec.start_time;
         l_time_tbl(i).end_time := tuesday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.tuesday_overlap);
         IF x_days_overlap.tuesday_overlap = 'Y' THEN
            l_overlap_days := l_overlap_days || get_day_meaning('TUE') || ',';
         END IF;
      
      END IF;
   
      -- Validating for wednesday.
   
      l_time_tbl.DELETE;
      i := 0;
   
      FOR wednesday_rec IN cur_wednesday(p_billtype_line_id, p_holiday_yn) LOOP
         i := i + 1;
         l_time_tbl(i).start_time := wednesday_rec.start_time;
         l_time_tbl(i).end_time := wednesday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.wednesday_overlap);
         IF x_days_overlap.wednesday_overlap = 'Y' THEN
            l_overlap_days := l_overlap_days || get_day_meaning('WED') || ',';
         END IF;
      
      END IF;
   
      -- Validating for thursday.
   
      l_time_tbl.DELETE;
      i := 0;
   
      FOR thursday_rec IN cur_thursday(p_billtype_line_id, p_holiday_yn) LOOP
         i := i + 1;
         l_time_tbl(i).start_time := thursday_rec.start_time;
         l_time_tbl(i).end_time := thursday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.thursday_overlap);
         IF x_days_overlap.thursday_overlap = 'Y' THEN
            l_overlap_days := l_overlap_days || get_day_meaning('THU') || ',';
         END IF;
      
      END IF;
   
      -- Validating for friday.
   
      l_time_tbl.DELETE;
      i := 0;
   
      FOR friday_rec IN cur_friday(p_billtype_line_id, p_holiday_yn) LOOP
         i := i + 1;
         l_time_tbl(i).start_time := friday_rec.start_time;
         l_time_tbl(i).end_time := friday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.friday_overlap);
         IF x_days_overlap.friday_overlap = 'Y' THEN
            l_overlap_days := l_overlap_days || get_day_meaning('FRI') || ',';
         END IF;
      
      END IF;
   
      -- Validating for saturday.
   
      l_time_tbl.DELETE;
      i := 0;
   
      FOR saturday_rec IN cur_saturday(p_billtype_line_id, p_holiday_yn) LOOP
         i := i + 1;
         l_time_tbl(i).start_time := saturday_rec.start_time;
         l_time_tbl(i).end_time := saturday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.saturday_overlap);
         IF x_days_overlap.saturday_overlap = 'Y' THEN
            l_overlap_days := l_overlap_days || get_day_meaning('SAT') || ',';
         END IF;
      
      END IF;
   
      -- Validating for sunday.
   
      l_time_tbl.DELETE;
      i := 0;
   
      FOR sunday_rec IN cur_sunday(p_billtype_line_id, p_holiday_yn) LOOP
         i := i + 1;
         l_time_tbl(i).start_time := sunday_rec.start_time;
         l_time_tbl(i).end_time := sunday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.sunday_overlap);
         IF x_days_overlap.sunday_overlap = 'Y' THEN
            l_overlap_days := l_overlap_days || get_day_meaning('SUN') || ',';
         END IF;
      
      END IF;
   
      IF l_overlap_days IS NOT NULL THEN
         fnd_message.set_name('OKS', 'OKS_BILLRATE_DAYS_OVERLAP');
         fnd_message.set_token('DAYS', l_overlap_days);
      END IF;
   
      x_return_status := okc_api.g_ret_sts_success;
   
   EXCEPTION
   
      WHEN okc_api.g_exception_unexpected_error THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
      WHEN OTHERS THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
      
   END; -- Validate_billrate_schedule;

   --=======================================================================================
   PROCEDURE init_contract_line(x_clev_tbl OUT NOCOPY okc_contract_pub.clev_tbl_type) IS
   BEGIN
   
      x_clev_tbl(1).id := NULL;
      x_clev_tbl(1).object_version_number := NULL;
      x_clev_tbl(1).sfwt_flag := NULL;
      x_clev_tbl(1).chr_id := NULL;
      x_clev_tbl(1).cle_id := NULL;
      x_clev_tbl(1).lse_id := NULL;
      x_clev_tbl(1).line_number := NULL;
      x_clev_tbl(1).sts_code := NULL;
      x_clev_tbl(1).display_sequence := NULL;
      x_clev_tbl(1).trn_code := NULL;
      x_clev_tbl(1).NAME := NULL;
      x_clev_tbl(1).comments := NULL;
      x_clev_tbl(1).item_description := NULL;
      x_clev_tbl(1).hidden_ind := NULL;
      x_clev_tbl(1).price_negotiated := NULL;
      x_clev_tbl(1).price_level_ind := NULL;
      x_clev_tbl(1).dpas_rating := NULL;
      x_clev_tbl(1).block23text := NULL;
      x_clev_tbl(1).exception_yn := NULL;
      x_clev_tbl(1).template_used := NULL;
      x_clev_tbl(1).date_terminated := NULL;
      x_clev_tbl(1).start_date := NULL;
      x_clev_tbl(1).attribute_category := NULL;
      x_clev_tbl(1).attribute1 := NULL;
      x_clev_tbl(1).attribute2 := NULL;
      x_clev_tbl(1).attribute3 := NULL;
      x_clev_tbl(1).attribute4 := NULL;
      x_clev_tbl(1).attribute5 := NULL;
      x_clev_tbl(1).attribute6 := NULL;
      x_clev_tbl(1).attribute7 := NULL;
      x_clev_tbl(1).attribute8 := NULL;
      x_clev_tbl(1).attribute9 := NULL;
      x_clev_tbl(1).attribute10 := NULL;
      x_clev_tbl(1).attribute11 := NULL;
      x_clev_tbl(1).attribute12 := NULL;
      x_clev_tbl(1).attribute13 := NULL;
      x_clev_tbl(1).attribute14 := NULL;
      x_clev_tbl(1).attribute15 := NULL;
      x_clev_tbl(1).created_by := NULL;
      x_clev_tbl(1).creation_date := NULL;
      x_clev_tbl(1).last_updated_by := NULL;
      x_clev_tbl(1).last_update_date := NULL;
      x_clev_tbl(1).price_type := NULL;
      x_clev_tbl(1).currency_code := NULL;
      x_clev_tbl(1).last_update_login := NULL;
      x_clev_tbl(1).dnz_chr_id := NULL;
   
   END; -- INIT_CONTRACT_LINE
   --=================================================

   PROCEDURE oks_migrate_billrates(p_api_version   IN NUMBER,
                                   p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                                   x_return_status OUT NOCOPY VARCHAR2,
                                   x_msg_count     OUT NOCOPY NUMBER,
                                   x_msg_data      OUT NOCOPY VARCHAR2) IS
   
      CURSOR cur_get_billrates IS
      
         SELECT lines1.id billtype_line_id,
                lines2.id billrate_line_id,
                orgb.id rule_group_id,
                rules.id rule_id,
                rules.dnz_chr_id rule_dnz_chr_id,
                rules.created_by,
                rules.creation_date,
                rules.last_updated_by,
                rules.last_update_date,
                rules.last_update_login,
                rules.rule_information_category,
                rules.rule_information1 uom, -- uom
                rules.rule_information2 flat_rate, -- flat_rate
                rules.rule_information3 percent_over_list_price, -- %over_list_price
                rules.rule_information4 bill_rate_code, -- bill_rate_code
                nvl(rules.template_yn, 'N') template_yn
           FROM okc_k_lines_b     lines1,
                okc_k_lines_b     lines2,
                okc_rule_groups_b orgb,
                okc_rules_b       rules
          WHERE lines1.lse_id IN (5, 23, 59) AND
                lines2.lse_id IN (6, 24, 60) AND
                lines1.dnz_chr_id = lines2.dnz_chr_id AND
                lines2.cle_id = lines1.id AND
                lines2.id = orgb.cle_id AND
                lines2.dnz_chr_id = orgb.dnz_chr_id AND
                rules.rgp_id = orgb.id AND
                rules.dnz_chr_id = orgb.dnz_chr_id AND
                rules.rule_information_category = 'RSL' AND
                rules.rule_information9 IS NULL; -- upgrade_flag
   
      l_bill_rate_tbl_in  oks_brs_pvt.oksbillrateschedulesvtbltype;
      x_bill_rate_tbl_out oks_brs_pvt.oksbillrateschedulesvtbltype;
   
      l_check_flag VARCHAR2(1) := 'N';
      l_api_version   CONSTANT NUMBER := 1.0;
      l_init_msg_list CONSTANT VARCHAR2(1) := 'F';
      l_return_status VARCHAR2(1);
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(2000) := NULL;
      l_api_name      VARCHAR2(80) := 'OKS_MIGRATE_BILLRATES';
      g_pkg_name      VARCHAR2(80) := 'OKS_COVERAGES_PVT';
   
      --l_rulv_tbl_in  okc_rule_pub.rulv_tbl_type;
      --l_rulv_tbl_out okc_rule_pub.rulv_tbl_type;
   BEGIN
   
      FOR br_rec IN cur_get_billrates LOOP
         l_check_flag := 'Y';
      
         init_bill_rate_line(l_bill_rate_tbl_in);
      
         l_bill_rate_tbl_in(1).cle_id := br_rec.billrate_line_id;
         l_bill_rate_tbl_in(1).bt_cle_id := br_rec.billtype_line_id;
         l_bill_rate_tbl_in(1).dnz_chr_id := br_rec.rule_dnz_chr_id;
         l_bill_rate_tbl_in(1).start_hour := NULL;
         l_bill_rate_tbl_in(1).start_minute := NULL;
         l_bill_rate_tbl_in(1).end_hour := NULL;
         l_bill_rate_tbl_in(1).end_minute := NULL;
         l_bill_rate_tbl_in(1).monday_flag := NULL;
         l_bill_rate_tbl_in(1).tuesday_flag := NULL;
         l_bill_rate_tbl_in(1).wednesday_flag := NULL;
         l_bill_rate_tbl_in(1).thursday_flag := NULL;
         l_bill_rate_tbl_in(1).friday_flag := NULL;
         l_bill_rate_tbl_in(1).saturday_flag := NULL;
         l_bill_rate_tbl_in(1).sunday_flag := NULL;
         l_bill_rate_tbl_in(1).object1_id1 := NULL;
         l_bill_rate_tbl_in(1).object1_id2 := NULL;
         l_bill_rate_tbl_in(1).bill_rate_code := br_rec.bill_rate_code;
         l_bill_rate_tbl_in(1).flat_rate := br_rec.flat_rate;
         l_bill_rate_tbl_in(1).uom := br_rec.uom;
         l_bill_rate_tbl_in(1).holiday_yn := 'N';
         l_bill_rate_tbl_in(1).percent_over_list_price := br_rec.percent_over_list_price;
         l_bill_rate_tbl_in(1).program_application_id := NULL;
         l_bill_rate_tbl_in(1).program_id := NULL;
         l_bill_rate_tbl_in(1).program_update_date := NULL;
         l_bill_rate_tbl_in(1).request_id := NULL;
         l_bill_rate_tbl_in(1).created_by := br_rec.created_by;
         l_bill_rate_tbl_in(1).creation_date := br_rec.creation_date;
         l_bill_rate_tbl_in(1).last_updated_by := br_rec.last_updated_by;
         l_bill_rate_tbl_in(1).last_update_date := br_rec.last_update_date;
         l_bill_rate_tbl_in(1).last_update_login := br_rec.last_update_login;
         l_bill_rate_tbl_in(1).security_group_id := NULL;
         l_bill_rate_tbl_in(1).object_version_number := 1; --Added
      
         oks_brs_pvt.insert_row(p_api_version                  => l_api_version,
                                p_init_msg_list                => l_init_msg_list,
                                x_return_status                => l_return_status,
                                x_msg_count                    => l_msg_count,
                                x_msg_data                     => l_msg_data,
                                p_oks_billrate_schedules_v_tbl => l_bill_rate_tbl_in,
                                x_oks_billrate_schedules_v_tbl => x_bill_rate_tbl_out);
      
         IF NOT l_return_status = okc_api.g_ret_sts_success THEN
            RAISE g_exception_halt_validation;
         END IF;
      
         x_return_status := l_return_status;
      
         UPDATE okc_rules_b
            SET rule_information9 = 'Y'
          WHERE id = br_rec.rule_id;
      
      END LOOP;
   
      IF l_check_flag = 'N' THEN
         --Added
      
         UPDATE oks_billrate_schedules SET object_version_number = 1;
      
      END IF;
   
      x_return_status := okc_api.g_ret_sts_success;
   EXCEPTION
   
      WHEN g_exception_rule_update THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
      
      WHEN g_exception_halt_validation THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
      WHEN okc_api.g_exception_unexpected_error THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
      WHEN OTHERS THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
      
   END oks_migrate_billrates;

   --==========================================================================
   PROCEDURE oks_billrate_mapping(p_api_version         IN NUMBER,
                                  p_init_msg_list       IN VARCHAR2 DEFAULT okc_api.g_false,
                                  p_business_process_id IN NUMBER,
                                  p_time_labor_tbl_in   IN time_labor_tbl,
                                  x_return_status       OUT NOCOPY VARCHAR2,
                                  x_msg_count           OUT NOCOPY NUMBER,
                                  x_msg_data            OUT NOCOPY VARCHAR2) IS
   
      i              NUMBER := 0;
      j              NUMBER := 0;
      l_bus_proc_id  NUMBER;
      l_holiday_flag VARCHAR2(1);
      l_api_version   CONSTANT NUMBER := 1.0;
      l_init_msg_list CONSTANT VARCHAR2(1) := 'F';
      l_return_status VARCHAR2(1);
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(2000) := NULL;
      l_api_name      VARCHAR2(80) := 'OKS_BILLRATE_MAPPING';
      g_pkg_name      VARCHAR2(80) := 'OKS_COVERAGES_PVT';
   
      l_bill_rate_tbl_in  oks_brs_pvt.oksbillrateschedulesvtbltype;
      x_bill_rate_tbl_out oks_brs_pvt.oksbillrateschedulesvtbltype;
      l_clev_tbl_in       okc_contract_pub.clev_tbl_type;
      l_clev_tbl_out      okc_contract_pub.clev_tbl_type;
      --l_rulv_tbl_in       okc_rule_pub.rulv_tbl_type;
      --l_rulv_tbl_out      okc_rule_pub.rulv_tbl_type;
      l_cle_id            NUMBER;
      l_bill_rate_code    VARCHAR2(30);
   
      l_conc_request_id     NUMBER;
      l_prog_appl_id        NUMBER;
      l_conc_program_id     NUMBER;
      l_program_update_date DATE;
   
      CURSOR cur_get_all_bill_rate_codes(p_business_process_id IN NUMBER) IS
         SELECT lines1.id bp_line_id,
                lines2.id bill_type_line_id,
                lines2.lse_id bt_lse_id,
                lines3.id bill_rate_line_id,
                lines3.lse_id br_lse_id,
                lines3.sts_code sts_code,
                lines3.dnz_chr_id br_dnz_chr_id,
                orgb.id rule_group_id,
                rules.id rule_id,
                rules.template_yn template_yn,
                rules.rule_information4 rule_information4,
                items.object1_id1, -- bp_id
                bills.id billrate_sch_id,
                bills.cle_id br_line_id,
                bills.bt_cle_id bt_cle_id,
                bills.bill_rate_code bill_rate_code,
                bills.flat_rate flat_rate,
                bills.uom uom,
                bills.percent_over_list_price percent_over_list_price,
                bills.created_by created_by,
                bills.creation_date creation_date,
                bills.last_updated_by last_updated_by,
                bills.last_update_date last_update_date,
                bills.last_update_login last_update_login,
                bills.security_group_id security_group_id,
                bills.object_version_number object_version_number --Added
           FROM okc_k_lines_b          lines1,
                okc_k_lines_b          lines2,
                okc_k_lines_b          lines3,
                okc_k_items            items,
                okc_rule_groups_b      orgb,
                okc_rules_b            rules,
                oks_billrate_schedules bills
          WHERE lines1.lse_id IN (3, 16, 21) AND
                lines2.lse_id IN (5, 23, 59) AND
                lines3.lse_id IN (6, 24, 60) AND
                lines2.cle_id = lines1.id AND
                lines3.cle_id = lines2.id AND
                orgb.cle_id = lines3.id AND
                rules.rgp_id = orgb.id AND
                items.cle_id = lines1.id AND
                bills.bt_cle_id = lines2.id AND
                bills.cle_id = lines3.id AND
                lines2.dnz_chr_id = lines1.dnz_chr_id AND
                lines3.dnz_chr_id = lines2.dnz_chr_id AND
                rules.rule_information10 IS NULL AND
                items.object1_id1 = to_char(p_business_process_id);
      --  and rules.rule_information_category = 'RSL' ;
      -- and bills.start_time and end time is null;
   
      l_bill_rate_exists VARCHAR2(1) := 'N';
   
      /*    CURSOR CUR_GET_TIME_INFO(p_bus_proc_id IN NUMBER, p_holiday_flag IN VARCHAR2,p_labor_code IN VARCHAR2) IS
      SELECT TO_CHAR(START_TIME,'HH24') START_HOUR,TO_CHAR(START_TIME,'MI')START_MINUTE,
             TO_CHAR(END_TIME,'HH24')END_HOUR,TO_CHAR(END_TIME,'MI')END_MINUTE,
             MONDAY_FLAG,TUESDAY_FLAG,WEDNESDAY_FLAG,THURSDAY_FLAG,FRIDAY_FLAG,
             SATURDAY_FLAG,SUNDAY_FLAG, INVENTORY_ITEM_ID, LABOR_CODE
             FROM  CS_TM_LABOR_SCHEDULES
             WHERE BUSINESS_PROCESS_ID = p_bus_proc_id
             AND  HOLIDAY_FLAG = p_holiday_flag
             AND LABOR_CODE = p_labor_code; */
   
   BEGIN
   
      FOR bill_rate_rec IN cur_get_all_bill_rate_codes(p_business_process_id) LOOP
      
         IF (okc_assent_pub.header_operation_allowed(bill_rate_rec.br_dnz_chr_id,
                                                     'UPDATE') = 'T') THEN
            -- status and operations check
         
            i := i + 1;
         
            l_bus_proc_id    := to_number(bill_rate_rec.object1_id1);
            l_holiday_flag   := 'N';
            l_bill_rate_code := bill_rate_rec.rule_information4;
         
            l_conc_request_id := fnd_global.conc_request_id;
         
            IF l_conc_request_id <> -1 THEN
               l_prog_appl_id        := fnd_global.prog_appl_id;
               l_conc_program_id     := fnd_global.conc_program_id;
               l_program_update_date := SYSDATE;
            ELSE
               l_prog_appl_id        := NULL;
               l_conc_program_id     := NULL;
               l_program_update_date := NULL;
               l_conc_request_id     := NULL;
            END IF;
         
            IF fnd_global.conc_request_id <> -1 THEN
               fnd_file.put_line(fnd_file.log,
                                 'PROGRAM_APPLICATION_ID....' ||
                                 l_prog_appl_id);
               fnd_file.put_line(fnd_file.log,
                                 'PROGRAM_ID...' || l_conc_program_id);
               fnd_file.put_line(fnd_file.log,
                                 'PROGRAM_UPDATE_DATE...' ||
                                 l_program_update_date);
               fnd_file.put_line(fnd_file.log,
                                 'REQUEST_ID...' || l_conc_request_id);
               fnd_file.put_line(fnd_file.log,
                                 'Processing for BP_LINE_ID.....' ||
                                 bill_rate_rec.bp_line_id);
            END IF;
         
            l_bill_rate_exists := 'N';
         
            FOR j IN p_time_labor_tbl_in.FIRST .. p_time_labor_tbl_in.LAST LOOP
            
               IF p_time_labor_tbl_in(j)
               .holiday_flag = 'N' AND p_time_labor_tbl_in(j)
               .labor_code = l_bill_rate_code THEN
               
                  IF l_bill_rate_exists = 'N' THEN
                     l_bill_rate_exists := 'Y';
                  
                     init_bill_rate_line(l_bill_rate_tbl_in);
                  
                     l_bill_rate_tbl_in(1).id := bill_rate_rec.billrate_sch_id;
                     l_bill_rate_tbl_in(1).cle_id := bill_rate_rec.br_line_id;
                     l_bill_rate_tbl_in(1).bt_cle_id := bill_rate_rec.bt_cle_id;
                     l_bill_rate_tbl_in(1).start_hour := to_number(to_char(p_time_labor_tbl_in(j)
                                                                           .start_time,
                                                                           'HH24'));
                     l_bill_rate_tbl_in(1).start_minute := to_number(to_char(p_time_labor_tbl_in(j)
                                                                             .start_time,
                                                                             'MI'));
                     l_bill_rate_tbl_in(1).end_hour := to_number(to_char(p_time_labor_tbl_in(j)
                                                                         .end_time,
                                                                         'HH24'));
                     l_bill_rate_tbl_in(1).end_minute := to_number(to_char(p_time_labor_tbl_in(j)
                                                                           .end_time,
                                                                           'MI'));
                     l_bill_rate_tbl_in(1).monday_flag := p_time_labor_tbl_in(j)
                                                         .monday_flag;
                     l_bill_rate_tbl_in(1).tuesday_flag := p_time_labor_tbl_in(j)
                                                          .tuesday_flag;
                     l_bill_rate_tbl_in(1).wednesday_flag := p_time_labor_tbl_in(j)
                                                            .wednesday_flag;
                     l_bill_rate_tbl_in(1).thursday_flag := p_time_labor_tbl_in(j)
                                                           .thursday_flag;
                     l_bill_rate_tbl_in(1).friday_flag := p_time_labor_tbl_in(j)
                                                         .friday_flag;
                     l_bill_rate_tbl_in(1).saturday_flag := p_time_labor_tbl_in(j)
                                                           .saturday_flag;
                     l_bill_rate_tbl_in(1).sunday_flag := p_time_labor_tbl_in(j)
                                                         .sunday_flag;
                     l_bill_rate_tbl_in(1).object1_id1 := p_time_labor_tbl_in(j)
                                                         .inventory_item_id;
                     l_bill_rate_tbl_in(1).object1_id2 := '#';
                     l_bill_rate_tbl_in(1).bill_rate_code := bill_rate_rec.bill_rate_code;
                     l_bill_rate_tbl_in(1).flat_rate := bill_rate_rec.flat_rate;
                     l_bill_rate_tbl_in(1).uom := bill_rate_rec.uom;
                     l_bill_rate_tbl_in(1).holiday_yn := 'N';
                     l_bill_rate_tbl_in(1).percent_over_list_price := bill_rate_rec.percent_over_list_price;
                     l_bill_rate_tbl_in(1).program_application_id := l_prog_appl_id;
                     l_bill_rate_tbl_in(1).program_id := l_conc_program_id;
                     l_bill_rate_tbl_in(1).program_update_date := l_program_update_date;
                     l_bill_rate_tbl_in(1).request_id := l_conc_request_id;
                     l_bill_rate_tbl_in(1).created_by := bill_rate_rec.created_by;
                     l_bill_rate_tbl_in(1).creation_date := bill_rate_rec.creation_date;
                     l_bill_rate_tbl_in(1).last_updated_by := bill_rate_rec.last_updated_by;
                     l_bill_rate_tbl_in(1).last_update_date := bill_rate_rec.last_update_date;
                     l_bill_rate_tbl_in(1).last_update_login := bill_rate_rec.last_update_login;
                     l_bill_rate_tbl_in(1).security_group_id := bill_rate_rec.security_group_id;
                     l_bill_rate_tbl_in(1).object_version_number := bill_rate_rec.object_version_number; --Added
                  
                     oks_brs_pvt.update_row(p_api_version                  => l_api_version,
                                            p_init_msg_list                => p_init_msg_list,
                                            x_return_status                => l_return_status,
                                            x_msg_count                    => l_msg_count,
                                            x_msg_data                     => l_msg_data,
                                            p_oks_billrate_schedules_v_tbl => l_bill_rate_tbl_in,
                                            x_oks_billrate_schedules_v_tbl => x_bill_rate_tbl_out);
                  
                     IF fnd_global.conc_request_id <> -1 THEN
                        fnd_file.put_line(fnd_file.log,
                                          'AFTER OKS_BRS_PVT.UPDATE_ROW......');
                        fnd_file.put_line(fnd_file.log,
                                          'Return Status from OKS_BRS_PVT.UPDATE_ROW API...' ||
                                          l_return_status);
                     END IF;
                  
                     IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                        RAISE g_exception_brs_update;
                     END IF;
                  
                  ELSE
                     -- create lines in okc_k_lines_b, oks_billrate_schedules
                  
                     init_contract_line(l_clev_tbl_in);
                     init_bill_rate_line(l_bill_rate_tbl_in);
                  
                     l_clev_tbl_in(1).cle_id := bill_rate_rec.bill_type_line_id;
                     l_clev_tbl_in(1).lse_id := bill_rate_rec.br_lse_id;
                     l_clev_tbl_in(1).sfwt_flag := 'N';
                     l_clev_tbl_in(1).exception_yn := 'N';
                     l_clev_tbl_in(1).sts_code := bill_rate_rec.sts_code;
                     l_clev_tbl_in(1).dnz_chr_id := bill_rate_rec.br_dnz_chr_id;
                     l_clev_tbl_in(1).display_sequence := 1;
                  
                     okc_contract_pub.create_contract_line(p_api_version       => l_api_version,
                                                           p_init_msg_list     => l_init_msg_list,
                                                           x_return_status     => l_return_status,
                                                           x_msg_count         => l_msg_count,
                                                           x_msg_data          => l_msg_data,
                                                           p_restricted_update => 'F',
                                                           p_clev_tbl          => l_clev_tbl_in,
                                                           x_clev_tbl          => l_clev_tbl_out);
                  
                     x_return_status := l_return_status;
                  
                     IF fnd_global.conc_request_id <> -1 THEN
                        fnd_file.put_line(fnd_file.log,
                                          'AFTER OKC_CONTRACT_PUB.CREATE_CONTRACT_LINE......');
                        fnd_file.put_line(fnd_file.log,
                                          'Return Status from OKC_CONTRACT_PUB.CREATE_CONTRACT_LINE API...' ||
                                          l_return_status);
                     END IF;
                  
                     IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                        RAISE g_exception_halt_validation;
                     END IF;
                  
                     l_cle_id := l_clev_tbl_out(1).id;
                  
                     l_bill_rate_tbl_in(1).cle_id := l_cle_id; --C1.billrate_line_id ;
                     l_bill_rate_tbl_in(1).bt_cle_id := bill_rate_rec.bill_type_line_id;
                     l_bill_rate_tbl_in(1).start_hour := to_number(to_char(p_time_labor_tbl_in(j)
                                                                           .start_time,
                                                                           'HH24'));
                     l_bill_rate_tbl_in(1).start_minute := to_number(to_char(p_time_labor_tbl_in(j)
                                                                             .start_time,
                                                                             'MI'));
                     l_bill_rate_tbl_in(1).end_hour := to_number(to_char(p_time_labor_tbl_in(j)
                                                                         .end_time,
                                                                         'HH24'));
                     l_bill_rate_tbl_in(1).end_minute := to_number(to_char(p_time_labor_tbl_in(j)
                                                                           .end_time,
                                                                           'MI'));
                     l_bill_rate_tbl_in(1).monday_flag := p_time_labor_tbl_in(j)
                                                         .monday_flag;
                     l_bill_rate_tbl_in(1).tuesday_flag := p_time_labor_tbl_in(j)
                                                          .tuesday_flag;
                     l_bill_rate_tbl_in(1).wednesday_flag := p_time_labor_tbl_in(j)
                                                            .wednesday_flag;
                     l_bill_rate_tbl_in(1).thursday_flag := p_time_labor_tbl_in(j)
                                                           .thursday_flag;
                     l_bill_rate_tbl_in(1).friday_flag := p_time_labor_tbl_in(j)
                                                         .friday_flag;
                     l_bill_rate_tbl_in(1).saturday_flag := p_time_labor_tbl_in(j)
                                                           .saturday_flag;
                     l_bill_rate_tbl_in(1).sunday_flag := p_time_labor_tbl_in(j)
                                                         .sunday_flag;
                     l_bill_rate_tbl_in(1).object1_id1 := p_time_labor_tbl_in(j)
                                                         .inventory_item_id;
                     l_bill_rate_tbl_in(1).object1_id2 := '#';
                     l_bill_rate_tbl_in(1).bill_rate_code := p_time_labor_tbl_in(j)
                                                            .labor_code;
                     l_bill_rate_tbl_in(1).flat_rate := NULL;
                     l_bill_rate_tbl_in(1).uom := NULL;
                     l_bill_rate_tbl_in(1).holiday_yn := 'N';
                     l_bill_rate_tbl_in(1).percent_over_list_price := NULL;
                     l_bill_rate_tbl_in(1).program_application_id := l_prog_appl_id;
                     l_bill_rate_tbl_in(1).program_id := l_conc_program_id;
                     l_bill_rate_tbl_in(1).program_update_date := l_program_update_date;
                     l_bill_rate_tbl_in(1).request_id := l_conc_request_id;
                     l_bill_rate_tbl_in(1).created_by := bill_rate_rec.created_by;
                     l_bill_rate_tbl_in(1).creation_date := bill_rate_rec.creation_date;
                     l_bill_rate_tbl_in(1).last_updated_by := bill_rate_rec.last_updated_by;
                     l_bill_rate_tbl_in(1).last_update_date := bill_rate_rec.last_update_date;
                     l_bill_rate_tbl_in(1).last_update_login := bill_rate_rec.last_update_login;
                     l_bill_rate_tbl_in(1).security_group_id := bill_rate_rec.security_group_id;
                     l_bill_rate_tbl_in(1).object_version_number := bill_rate_rec.object_version_number; --Added
                  
                     oks_brs_pvt.insert_row(p_api_version                  => l_api_version,
                                            p_init_msg_list                => l_init_msg_list,
                                            x_return_status                => l_return_status,
                                            x_msg_count                    => l_msg_count,
                                            x_msg_data                     => l_msg_data,
                                            p_oks_billrate_schedules_v_tbl => l_bill_rate_tbl_in,
                                            x_oks_billrate_schedules_v_tbl => x_bill_rate_tbl_out);
                  
                     x_return_status := l_return_status;
                  
                     IF fnd_global.conc_request_id <> -1 THEN
                        fnd_file.put_line(fnd_file.log,
                                          'AFTER OKS_BRS_PVT.INSERT_ROW......');
                        fnd_file.put_line(fnd_file.log,
                                          'Return Status from OKS_BRS_PVT.INSERT_ROW API...' ||
                                          l_return_status);
                     END IF;
                  
                     IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                        RAISE g_exception_halt_validation;
                     END IF;
                  
                  END IF;
               END IF;
            END LOOP;
         
            -- update the rule line with mapped status to Y
         
            -- code commented to fix bug#2954917 for charges integration
            UPDATE okc_rules_b
               SET rule_information9 = 'Y'
             WHERE id = bill_rate_rec.rule_id;
         
            /*  l_rulv_tbl_in(1).id := bill_rate_rec.rule_id ;
            l_rulv_tbl_in(1).rule_information10 := 'Y';
            l_rulv_tbl_in(1).template_yn := bill_rate_rec.template_yn;
            
            
              OKC_RULE_PUB.UPDATE_RULE(p_api_version      => l_api_version,
                                       p_init_msg_list    => l_init_msg_list,
                                       x_return_status    => l_return_status,
                                       x_msg_count        => l_msg_count,
                                       x_msg_data         => l_msg_data,
                                       p_rulv_tbl         => l_rulv_tbl_in,
                                       x_rulv_tbl         => l_rulv_tbl_out); */
         
            IF fnd_global.conc_request_id <> -1 THEN
               fnd_file.put_line(fnd_file.log,
                                 'AFTER OKC_RULE_PUB.UPDATE_RULE......Updating RULE_INFORMATION10 to Y');
               --  fnd_file.put_line(FND_FILE.LOG, 'Return Status from OKC_RULE_PUB.UPDATE_RULE API...'||l_return_status);
            END IF;
         
         END IF; -- status and operations check
      
      END LOOP;
      x_return_status := okc_api.g_ret_sts_success;
   
      IF fnd_global.conc_request_id <> -1 THEN
         fnd_file.put_line(fnd_file.log,
                           'Return Status from API...' || x_return_status);
      END IF;
   
   EXCEPTION
      WHEN g_exception_rule_update THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
         IF fnd_global.conc_request_id <> -1 THEN
            fnd_file.put_line(fnd_file.log,
                              'Raised Exception...||G_EXCEPTION_RULE_UPDATE');
         END IF;
      
      WHEN g_exception_brs_update THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
         IF fnd_global.conc_request_id <> -1 THEN
            fnd_file.put_line(fnd_file.log,
                              'Raised Exception...||G_EXCEPTION_BRS_UPDATE');
         END IF;
      
      WHEN g_exception_halt_validation THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
      
         IF fnd_global.conc_request_id <> -1 THEN
            fnd_file.put_line(fnd_file.log,
                              'Raised Exception...||G_EXCEPTION_HALT_VALIDATION');
         END IF;
      
      WHEN okc_api.g_exception_unexpected_error THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
         IF fnd_global.conc_request_id <> -1 THEN
            fnd_file.put_line(fnd_file.log,
                              'Raised Exception...||G_EXCEPTION_UNEXPECTED_ERROR');
         END IF;
      
      WHEN OTHERS THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
         IF fnd_global.conc_request_id <> -1 THEN
            fnd_file.put_line(fnd_file.log, 'Raised Exception...||OTHERS');
         END IF;
      
   END oks_billrate_mapping;

   --==========================================================================================

   PROCEDURE get_notes_details(p_source_object_id   IN NUMBER,
                               x_notes_tbl          OUT NOCOPY jtf_note_tbl_type,
                               x_return_status      OUT NOCOPY VARCHAR2,
                               p_source_object_code IN VARCHAR2) IS
      -- Bug:5944200
   
      CURSOR get_notes_details_cur(l_id IN NUMBER) IS
         SELECT b.jtf_note_id        jtf_note_id,
                b.source_object_code source_object_code,
                b.note_status        note_status,
                b.note_type          note_type,
                b.notes              notes,
                b.notes_detail       notes_detail,
                -- Modified by Jvorugan for Bug:4489214 who columns not to be populated from old contract
                b.entered_by   entered_by,
                b.entered_date entered_date
         -- End of changes for Bug:4489214
           FROM jtf_notes_vl b
          WHERE b.source_object_id = l_id AND
                b.source_object_code = p_source_object_code; -- Bug:5944200
   
      i NUMBER := 0;
   
   BEGIN
   
      i := 0;
      l_notes_tbl.DELETE;
   
      FOR get_notes_details_rec IN get_notes_details_cur(p_source_object_id) LOOP
      
         l_notes_tbl(i).source_object_code := get_notes_details_rec.source_object_code;
         l_notes_tbl(i).notes := get_notes_details_rec.notes;
         jtf_notes_pub.writelobtodata(get_notes_details_rec.jtf_note_id,
                                      l_notes_tbl(i).notes_detail);
         --GET_NOTES_DETAILS_REC.NOTES_DETAIL;
         l_notes_tbl(i).note_status := get_notes_details_rec.note_status;
         l_notes_tbl(i).note_type := get_notes_details_rec.note_type;
         -- Modified by Jvorugan for Bug:4489214 who columns not to be populated from old contract
         l_notes_tbl(i).entered_by := get_notes_details_rec.entered_by;
         l_notes_tbl(i).entered_date := get_notes_details_rec.entered_date;
         -- End of changes for Bug:4489214
      
         i := i + 1;
      END LOOP;
      x_return_status := 'S';
   EXCEPTION
      WHEN OTHERS THEN
         x_return_status := 'E';
         okc_api.set_message(g_app_name,
                             g_unexpected_error,
                             g_sqlcode_token,
                             SQLCODE,
                             g_sqlerrm_token,
                             SQLERRM);
   END get_notes_details;

   PROCEDURE copy_notes(p_api_version   IN NUMBER,
                        p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                        p_line_id       IN NUMBER,
                        x_return_status OUT NOCOPY VARCHAR2,
                        x_msg_count     OUT NOCOPY NUMBER,
                        x_msg_data      OUT NOCOPY VARCHAR2) IS
   
      l_line_id   NUMBER := p_line_id;
      --l_first_rec VARCHAR2(1) := 'N';
   
      --l_created_by        NUMBER := NULL;
      --l_last_updated_by   NUMBER := NULL;
      --l_last_update_login NUMBER := NULL;
   
      CURSOR get_orig_contract_cur(l_id IN NUMBER) IS
         SELECT lines2.id orig_line_id,
                lines2.dnz_chr_id orig_dnz_chr_id,
                lines1.id new_line_id,
                lines1.chr_id new_chr_id,
                lines1.created_by,
                lines1.last_updated_by,
                lines1.last_update_login
           FROM -- okc_k_lines_v lines1, --new_id
                -- okc_k_lines_v lines2  -- old_id
                 okc_k_lines_b lines1, --Modified by Jvorugan for Bug:4560735
                okc_k_lines_b lines2
          WHERE lines1.id = l_id AND
                lines1.orig_system_id1 = lines2.id;
      --AND     lines1.lse_id =1
      --AND     lines2.lse_id = 1;
   
      --l_source_object_code jtf_notes_b.source_object_code%TYPE;
      --l_source_object_id   jtf_notes_b.source_object_id%TYPE;
      --l_note_type          jtf_notes_b.note_type%TYPE;
      --l_note_status        jtf_notes_b.note_status%TYPE;
      --l_notes              jtf_notes_tl.notes%TYPE;
      --l_notes_detail       VARCHAR2(32767);
   
      l_return_status         VARCHAR2(1) := NULL;
      l_msg_count             NUMBER;
      l_msg_data              VARCHAR2(1000);
      l_jtf_note_id           NUMBER;
      l_jtf_note_contexts_tab jtf_notes_pub.jtf_note_contexts_tbl_type;
   
   BEGIN
   
      x_return_status := okc_api.g_ret_sts_success;
   
      FOR get_orig_contract_rec IN get_orig_contract_cur(l_line_id) LOOP
      
         /* Commented by Jvorugan for Bug:4489214 who columns not to be populated from old contract
         l_created_by            :=  get_orig_contract_REC.created_by;
              l_last_updated_by       :=  get_orig_contract_REC.last_updated_by;
              l_last_update_login     :=  get_orig_contract_REC.last_update_login; */
      
         get_notes_details(p_source_object_id   => get_orig_contract_rec.orig_line_id,
                           x_notes_tbl          => l_notes_tbl,
                           x_return_status      => l_return_status,
                           p_source_object_code => 'OKS_COV_NOTE'); -- Bug:5944200
      
         IF l_return_status = 'S' THEN
            IF (l_notes_tbl.COUNT > 0) THEN
               FOR i IN l_notes_tbl.FIRST .. l_notes_tbl.LAST LOOP
               
                  jtf_notes_pub.create_note(p_jtf_note_id           => NULL --:JTF_NOTES.JTF_NOTE_ID
                                           ,
                                            p_api_version           => 1.0,
                                            p_init_msg_list         => 'F',
                                            p_commit                => 'F',
                                            p_validation_level      => 0,
                                            x_return_status         => l_return_status,
                                            x_msg_count             => l_msg_count,
                                            x_msg_data              => l_msg_data,
                                            p_source_object_code    => l_notes_tbl(i)
                                                                      .source_object_code,
                                            p_source_object_id      => get_orig_contract_rec.new_line_id,
                                            p_notes                 => l_notes_tbl(i)
                                                                      .notes,
                                            p_notes_detail          => l_notes_tbl(i)
                                                                      .notes_detail,
                                            p_note_status           => l_notes_tbl(i)
                                                                      .note_status,
                                            p_note_type             => l_notes_tbl(i)
                                                                      .note_type,
                                            p_entered_by            => l_notes_tbl(i)
                                                                      .entered_by -- -1 Modified for Bug:4489214
                                           ,
                                            p_entered_date          => l_notes_tbl(i)
                                                                      .entered_date -- SYSDATE Modified for Bug:4489214
                                           ,
                                            x_jtf_note_id           => l_jtf_note_id,
                                            p_creation_date         => SYSDATE,
                                            p_created_by            => fnd_global.user_id --  created_by Modified for Bug:4489214
                                           ,
                                            p_last_update_date      => SYSDATE,
                                            p_last_updated_by       => fnd_global.user_id -- l_last_updated_by Modified for Bug:4489214
                                           ,
                                            p_last_update_login     => fnd_global.login_id -- l_last_update_login Modified for Bug:4489214
                                           ,
                                            p_attribute1            => NULL,
                                            p_attribute2            => NULL,
                                            p_attribute3            => NULL,
                                            p_attribute4            => NULL,
                                            p_attribute5            => NULL,
                                            p_attribute6            => NULL,
                                            p_attribute7            => NULL,
                                            p_attribute8            => NULL,
                                            p_attribute9            => NULL,
                                            p_attribute10           => NULL,
                                            p_attribute11           => NULL,
                                            p_attribute12           => NULL,
                                            p_attribute13           => NULL,
                                            p_attribute14           => NULL,
                                            p_attribute15           => NULL,
                                            p_context               => NULL,
                                            p_jtf_note_contexts_tab => l_jtf_note_contexts_tab); --l_jtf_note_contexts_tab  );
               
               END LOOP;
            END IF;
         
         END IF;
      END LOOP;
      -- COMMIT;  -- There should not be any COMMIT in any API
   EXCEPTION
   
      WHEN OTHERS THEN
      
         okc_api.set_message(g_app_name,
                             g_unexpected_error,
                             g_sqlcode_token,
                             SQLCODE,
                             g_sqlerrm_token,
                             SQLERRM);
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END copy_notes;

   PROCEDURE copy_coverage(p_api_version      IN NUMBER,
                           p_init_msg_list    IN VARCHAR2 DEFAULT okc_api.g_false,
                           x_return_status    OUT NOCOPY VARCHAR2,
                           x_msg_count        OUT NOCOPY NUMBER,
                           x_msg_data         OUT NOCOPY VARCHAR2,
                           p_contract_line_id IN NUMBER) IS
   
      l_klnv_tbl_in          oks_kln_pvt.klnv_tbl_type;
      l_klnv_tbl_out         oks_kln_pvt.klnv_tbl_type;
      l_billrate_sch_tbl_in  oks_brs_pvt.oksbillrateschedulesvtbltype;
      l_billrate_sch_tbl_out oks_brs_pvt.oksbillrateschedulesvtbltype;
   
      l_timezone_tbl_in  oks_ctz_pvt.okscoveragetimezonesvtbltype;
      l_timezone_tbl_out oks_ctz_pvt.okscoveragetimezonesvtbltype;
   
      l_cover_time_tbl_in  oks_cvt_pvt.oks_coverage_times_v_tbl_type;
      l_cover_time_tbl_out oks_cvt_pvt.oks_coverage_times_v_tbl_type;
   
      l_act_pvt_tbl_in  oks_act_pvt.oksactiontimetypesvtbltype;
      l_act_pvt_tbl_out oks_act_pvt.oksactiontimetypesvtbltype;
   
      l_acm_pvt_tbl_in  oks_acm_pvt.oks_action_times_v_tbl_type;
      l_acm_pvt_tbl_out oks_acm_pvt.oks_action_times_v_tbl_type;
   
      l_new_bp_line_id       NUMBER := NULL;
      l_new_timezone_id      NUMBER := NULL;
      l_new_contract_line_id NUMBER;
      l_new_cov_line_id      NUMBER;
      l_new_cov_start_date   DATE;
      l_new_cov_end_date     DATE;
      l_new_dnz_chr_id       NUMBER;
      l_old_dnz_chr_id       NUMBER;
   
      --l_old_contract_line_id NUMBER;
      l_old_cov_line_id      NUMBER;
      l_old_cov_start_date   DATE;
      l_old_cov_end_date     DATE;
   
      l_old_time_zone_id         NUMBER;
      l_old_time_zone_dnz_chr_id NUMBER;
   
      l_api_version   CONSTANT NUMBER := 1.0;
      l_init_msg_list CONSTANT VARCHAR2(1) := 'F';
      l_return_status VARCHAR2(1);
      l_msg_count     NUMBER;
   
      --l_message       VARCHAR2(2000) := NULL;
      --l_msg_index_out NUMBER;
   
      l_msg_data           VARCHAR2(2000) := NULL;
      l_api_name           VARCHAR2(80) := 'OKS_COPY_COVERAGE';
      --g_pkg_name           VARCHAR2(80) := 'OKS_COVERAGES_PVT';
      l_validate_yn        VARCHAR2(1) := 'N';
      l_orig_sys_id1       NUMBER;
      i                    NUMBER := 0;
      --l_bp_id              NUMBER;
      l_old_bp_line_id     NUMBER;
      --l_old_busi_proc_id   NUMBER;
      --j                    NUMBER;
      --l_tze_id             NUMBER;
      --l_bp_line_id         NUMBER := NULL;
      --l_cov_tze_line_id    NUMBER;
      l_line_number        NUMBER;
      l_rt_id              NUMBER;
      l_rt_dnz_chr_id      NUMBER;
      m                    NUMBER;
      n                    NUMBER;
      l                    NUMBER := 0;
      k                    NUMBER := 0;
      f                    NUMBER := 0;
      l_line_id_four       NUMBER := 0;
      l_act_pvt_id         NUMBER := 0;
      l_act_pvt_new_id     NUMBER := 0;
      l_act_pvt_dnz_chr_id NUMBER := 0;
      l_act_pvt_cle_id     NUMBER := 0;
   
      l_old_bill_type_id     NUMBER := 0;
      l_bill_type_id         NUMBER := 0;
      l_bill_type_dnz_chr_id NUMBER := 0;
   
      --l_old_object1_id1    NUMBER := 0;
      l_old_line_number    NUMBER := 0;
      --l_new_bp_object1_id1 NUMBER := 0;
      -- get the original system_id1 from okc_k_lines_b
   
      CURSOR cur_get_orig_sys_id1(p_id IN NUMBER) IS
         SELECT orig_system_id1 FROM okc_k_lines_b WHERE id = p_id;
      -- get the coverage details for the coverage line added by jvorugan
      CURSOR cur_get_cov_det(p_id IN NUMBER) IS
         SELECT id, dnz_chr_id, start_date, end_date
           FROM okc_k_lines_b
          WHERE id = p_id;
   
      cr_cov_det cur_get_cov_det%ROWTYPE;
   
      -- get the pm_program_id associated with the service line added by jvorugan
      CURSOR cur_get_program_id(p_contract_line_id IN NUMBER) IS
         SELECT pm_program_id
           FROM oks_k_lines_b
          WHERE cle_id = p_contract_line_id;
   
      -- check whether the coverage is template   added by jvorugan
      CURSOR check_cov_tmpl(p_cov_id IN NUMBER) IS
         SELECT COUNT(*)
           FROM okc_k_lines_b
          WHERE id = p_cov_id AND
                lse_id IN (2, 15, 20) AND
                dnz_chr_id < 0;
   
      -- get the coverage id for the service line
   
      CURSOR cur_get_cov_line_id(p_contract_line_id IN NUMBER) IS
         SELECT id, dnz_chr_id, start_date, end_date
           FROM okc_k_lines_b
          WHERE cle_id = p_contract_line_id AND
                lse_id IN (2, 15, 20);
   
      cr_cov_line cur_get_cov_line_id%ROWTYPE;
   
      -- get the coverage line attributes from oks_k_lines_b
      CURSOR cur_get_cov_attr(p_cle_id IN NUMBER) IS
         SELECT id,
                cle_id,
                coverage_type,
                exception_cov_id,
                sync_date_install,
                transfer_option,
                prod_upgrade_yn,
                inheritance_type,
                pm_program_id,
                pm_conf_req_yn,
                pm_sch_exists_yn,
                object_version_number
           FROM oks_k_lines_b
          WHERE cle_id = p_cle_id;
   
      -- get the old and new business process line details
      /*
        CURSOR CUR_GET_OLD_BP(p_cle_id IN NUMBER) IS
        SELECT lines1.id bp_line_id, lines1.start_date start_date, lines1.end_date end_date,
               to_number(items.object1_id1) object1_id1,
               oks.discount_list discount_list,
               oks.offset_period offset_period,
               oks.offset_duration offset_duration,
               oks.allow_bt_discount allow_bt_discount,
               oks.apply_default_timezone apply_default_timezone,
               oks.OBJECT_VERSION_NUMBER OBJECT_VERSION_NUMBER
               FROM okc_k_lines_b lines1,
                    oks_k_lines_b oks,
                    okc_k_items items
               WHERE lines1.cle_id = p_cle_id
               AND items.cle_id = lines1.id
               AND items.jtot_object1_code = 'OKX_BUSIPROC'
               AND oks.cle_id = lines1.id
               AND lines1.lse_id IN (3,16,21)
               ORDER BY items.object1_id1, lines1.start_date, lines1.end_date;
      */
   
      -- CURSOR CUR_GET_OLD_BP modified for bug#4155384 - smohapat
      CURSOR cur_get_old_bp(p_cle_id IN NUMBER) IS
         SELECT lines1.id                  bp_line_id,
                lines1.start_date          start_date,
                lines1.end_date            end_date,
                oks.discount_list          discount_list,
                oks.offset_period          offset_period,
                oks.offset_duration        offset_duration,
                oks.allow_bt_discount      allow_bt_discount,
                oks.apply_default_timezone apply_default_timezone,
                oks.object_version_number  object_version_number
           FROM okc_k_lines_b lines1, oks_k_lines_b oks
          WHERE lines1.cle_id = p_cle_id AND
                oks.cle_id = lines1.id AND
                lines1.lse_id IN (3, 16, 21);
      /*
        CURSOR CUR_GET_NEW_BP(p_cle_id IN NUMBER ,P_Object1_Id1 IN NUMBER , p_old_bp_id in number) IS
        SELECT lines1.id bp_line_id, lines1.dnz_chr_id dnz_chr_id,lines1.start_date start_date, lines1.end_date end_date,
               to_number(items.object1_id1) object1_id1
                FROM okc_k_lines_b lines1,
                     okc_k_items items
               WHERE lines1.cle_id = p_cle_id
               AND items.cle_id = lines1.id
               AND items.jtot_object1_code = 'OKX_BUSIPROC'
               AND to_number(items.object1_id1) = p_object1_id1
               AND lines1.lse_id IN (3,16,21)
               AND lines1.orig_system_id1 = p_old_bp_id --New check added to allow duplicate BP
               ORDER BY items.object1_id1, lines1.start_date, lines1.end_date;
      */
      -- CURSOR CUR_GET_NEW_BP modified for bug#4155384 - smohapat
   
      CURSOR cur_get_new_bp(p_cle_id IN NUMBER, p_old_bp_id IN NUMBER) IS
         SELECT lines1.id         bp_line_id,
                lines1.dnz_chr_id dnz_chr_id,
                lines1.start_date start_date,
                lines1.end_date   end_date
           FROM okc_k_lines_b lines1
          WHERE lines1.cle_id = p_cle_id AND
                lines1.lse_id IN (3, 16, 21) AND
                lines1.orig_system_id1 = p_old_bp_id;
   
      -- Get Old And New Reaction Times
      CURSOR cur_get_old_rt(p_cle_id IN NUMBER) IS
         SELECT lines1.id rt_line_id,
                lines1.dnz_chr_id rt_dnz_chr_id,
                lines1.line_number rt_line_number,
                lines1.start_date start_date,
                lines1.end_date end_date,
                oks.incident_severity_id,
                oks.work_thru_yn,
                oks.react_active_yn,
                oks.sfwt_flag,
                oks.react_time_name,
                oks.discount_list discount_list,
                oks.offset_period offset_period,
                oks.offset_duration offset_duration,
                oks.allow_bt_discount allow_bt_discount,
                oks.apply_default_timezone apply_default_timezone,
                oks.object_version_number object_version_number
           FROM okc_k_lines_b lines1, oks_k_lines_v oks
          WHERE lines1.cle_id = p_cle_id AND
                oks.cle_id = lines1.id AND
                lines1.lse_id IN (4, 17, 22)
          ORDER BY lines1.line_number, lines1.start_date, lines1.end_date;
   
      /*
      CURSOR  CUR_GET_NEW_RT(P_Bp_line_Id IN NUMBER,P_new_dnz_chr_id IN NUMBER,l_new_Bp_Object1_ID1 IN NUMBER,
                                                            l_orig_system_id1 IN NUMBER) IS
      
        SELECT RT.ID,
               RT.DNZ_CHR_ID
        FROM   okc_k_lines_b   BT,
               okc_k_lines_B    RT,
               okc_k_items      BT_Item
        WHERE   BT.id =   P_Bp_line_Id
        AND     BT.dnz_chr_id = P_new_dnz_chr_id
        AND    BT.lse_id IN (3,16,21)
        AND    BT.ID = RT.cle_id
        AND    RT.lse_id in(4,17,22)
        AND    BT_ITEM.cle_id =    BT.id
        AND    BT_ITEM.DNZ_CHR_ID =BT.DNZ_CHR_ID
        AND    to_number(BT_ITEM.Object1_id1) =l_new_Bp_Object1_ID1 --1000
        AND    RT.dnz_chr_id = BT_ITEM.dnz_chr_id
            AND        RT.orig_system_id1   = l_orig_system_id1;
        */
   
      -- CURSOR CUR_GET_NEW_RT modified for bug#4155384 - smohapat
      CURSOR cur_get_new_rt(p_bp_line_id IN NUMBER, p_old_rt_id IN NUMBER) IS
         SELECT rt.id, rt.dnz_chr_id
           FROM okc_k_lines_b rt
          WHERE rt.cle_id = p_bp_line_id AND
                rt.lse_id IN (4, 17, 22) AND
                rt.orig_system_id1 = p_old_rt_id;
   
      CURSOR get_old_act_time_types(p_rt_id IN NUMBER, p_dnz_chr_id IN NUMBER) IS
         SELECT id, dnz_chr_id, action_type_code, object_version_number
           FROM oks_action_time_types
          WHERE cle_id = p_rt_id AND
                dnz_chr_id = p_dnz_chr_id;
   
      CURSOR get_old_act_times_cur(p_act_pvt_id IN NUMBER, p_act_dnz_chr_id IN NUMBER) IS
         SELECT id,
                cov_action_type_id,
                cle_id,
                dnz_chr_id,
                uom_code,
                sun_duration,
                mon_duration,
                tue_duration,
                wed_duration,
                thu_duration,
                fri_duration,
                sat_duration,
                security_group_id,
                object_version_number
           FROM oks_action_times
          WHERE cov_action_type_id = p_act_pvt_id AND
                dnz_chr_id = p_act_dnz_chr_id;
   
      -- Get Old And new Billing Types
      /*
       CURSOR CUR_GET_OLD_BT(p_id IN NUMBER) IS
       SELECT lines1.id bp_line_id, lines1.start_date start_date, lines1.end_date end_date,
              lines2.id bt_line_id, lines2.dnz_chr_id dnz_chr_id,
              lines2.object_version_number object_version_number,
              lines2.line_number line_number,
               to_number(items1.object1_id1) busi_proc_id,
               to_number(items2.object1_id1) bill_type_id,
               oks.discount_amount  discount_amount,
               oks.discount_percent discount_percent
               FROM okc_k_lines_b lines1,
                    okc_k_lines_b lines2,
                    oks_k_lines_b oks,
                    okc_k_items items1,
                    okc_k_items items2
               WHERE lines1.id = p_id
               AND   lines2.cle_id = lines1.id
               AND items1.cle_id = lines1.id
               AND items2.cle_id = lines2.id
               AND items1.jtot_object1_code = 'OKX_BUSIPROC'
               AND items2.jtot_object1_code = 'OKX_BILLTYPE'
               AND oks.cle_id = lines2.id
               AND items1.dnz_chr_id = lines1.dnz_chr_id
               AND items2.dnz_chr_id = lines2.dnz_chr_id
               AND lines1.lse_id IN (3,16,21)
               AND lines2.lse_id IN (5,23,59)
               ORDER BY busi_proc_id, bill_type_id, lines1.start_date, lines1.end_date;
      */
   
      -- CURSOR CUR_GET_OLD_BT modified for bug#4155384 - smohapat
   
      CURSOR cur_get_old_bt(p_bp_id IN NUMBER) IS
         SELECT lines1.id                    bt_line_id,
                lines1.start_date            start_date,
                lines1.end_date              end_date,
                lines2.dnz_chr_id            dnz_chr_id,
                lines2.object_version_number object_version_number,
                lines1.line_number           line_number,
                lines2.discount_amount       discount_amount,
                lines2.discount_percent      discount_percent
           FROM okc_k_lines_b lines1, oks_k_lines_b lines2
          WHERE lines1.cle_id = p_bp_id AND
                lines2.cle_id = lines1.id AND
                lines1.lse_id IN (5, 23, 59);
   
      /*
       CURSOR CUR_GET_NEW_BT(p_id IN NUMBER,p_object2_id IN NUMBER) IS
       SELECT lines1.id bp_line_id, lines1.start_date start_date, lines1.end_date end_date,
              lines2.id bt_line_id, lines2.dnz_chr_id dnz_chr_id,
              lines2.object_version_number object_version_number,
               to_number(items1.object1_id1) busi_proc_id,
               to_number(items2.object1_id1) bill_type_id
               FROM okc_k_lines_b lines1,
                    okc_k_lines_b lines2,
                    okc_k_items items1,
                    okc_k_items items2
               WHERE lines1.id = p_id
               AND   lines2.cle_id = lines1.id
      --         AND   lines2.line_number = p_line_number
               AND items1.cle_id = lines1.id
               AND items2.cle_id = lines2.id
               AND items1.jtot_object1_code = 'OKX_BUSIPROC'
               AND items2.jtot_object1_code = 'OKX_BILLTYPE'
               AND to_number(items2.object1_id1) = p_object2_id
               AND items1.dnz_chr_id = lines1.dnz_chr_id
               AND items2.dnz_chr_id = lines2.dnz_chr_id
               AND lines1.lse_id IN (3,16,21)
               AND lines2.lse_id IN (5,23,59)
               ORDER BY busi_proc_id, bill_type_id, lines1.start_date, lines1.end_date;
      
      
      */
   
      -- CURSOR CUR_GET_NEW_BT modified for bug#4155384 - smohapat
   
      CURSOR cur_get_new_bt(p_bp_line_id IN NUMBER, p_old_bt_id IN NUMBER) IS
         SELECT bt.id bt_line_id,
                bt.start_date start_date,
                bt.dnz_chr_id,
                bt.end_date end_date,
                bt.object_version_number
           FROM okc_k_lines_b bt
          WHERE bt.cle_id = p_bp_line_id AND
                bt.lse_id IN (5, 23, 59) AND
                bt.orig_system_id1 = p_old_bt_id;
   
      -- get the old and new bill rates
      /*
          CURSOR CUR_GET_OLD_BILL_RATE(p_id IN NUMBER,p_object1_id1 IN NUMBER)IS
          SELECT BTY.id BT_LINE_ID,
                 BTY.start_date start_date,
                 BTY.end_date end_date,
                 BRT.id BR_LINE_ID,
                 BRT.line_number line_number,
                 TO_NUMBER(BTY_ITEM.object1_id1) bill_type_id,
                 BRS.start_hour start_hour,
                 BRS.start_minute start_minute,
                 BRS.end_hour end_hour,
                 BRS.end_minute end_minute,
                 BRS.monday_flag monday_flag,
                 BRS.tuesday_flag tuesday_flag,
                 BRS.wednesday_flag wednesday_flag,
                 BRS.thursday_flag thursday_flag,
                 BRS.friday_flag friday_flag,
                 BRS.saturday_flag saturday_flag,
                 BRS.sunday_flag sunday_flag,
                 BRS.object1_id1 object1_id1,
                 BRS.object1_id2 object1_id2,
                 BRS.jtot_object1_code jtot_object1_code,
                 BRS.bill_rate_code bill_rate_code,
                 BRS.flat_rate flat_rate,
                 BRS.uom uom,
                 BRS.holiday_yn holiday_yn,
                 BRS.percent_over_list_price percent_over_list_price,
                 BRS.object_version_number object_version_number --Added
          FROM   okc_k_lines_b BTY,
                 okc_k_lines_b BRT,
                 okc_k_items   BTY_ITEM,
                 oks_billrate_schedules BRS
          WHERE  BTY.id = p_id --274672627862321176435113785401106834939--
          AND    BTY.lse_id IN (5,23,59)
      --    AND    BRT.line_number = p_line_number
          AND    BTY_ITEM.cle_id = BTY.id
          AND    BTY_ITEM.dnz_chr_id = BTY.dnz_chr_id
          AND    BTY_ITEM.jtot_object1_code = 'OKX_BILLTYPE'
          AND    TO_NUMBER(BTY_ITEM.object1_id1) = p_object1_id1
          AND    BTY.id = BRT.cle_id
          AND    BRT.lse_id IN (6,24,60)
          AND    BRS.cle_id = BRT.id
          ORDER BY  BRT.line_number ,BTY.start_date,BTY.end_date,bill_type_id;
      
          */
   
      -- CURSOR CUR_GET_OLD_BILL_RATE modified for bug#4155384 - smohapat
      CURSOR cur_get_old_bill_rate(p_id IN NUMBER) IS
         SELECT brs.cle_id,
                brs.start_hour start_hour,
                brs.start_minute start_minute,
                brs.end_hour end_hour,
                brs.end_minute end_minute,
                brs.monday_flag monday_flag,
                brs.tuesday_flag tuesday_flag,
                brs.wednesday_flag wednesday_flag,
                brs.thursday_flag thursday_flag,
                brs.friday_flag friday_flag,
                brs.saturday_flag saturday_flag,
                brs.sunday_flag sunday_flag,
                brs.object1_id1 object1_id1,
                brs.object1_id2 object1_id2,
                brs.jtot_object1_code jtot_object1_code,
                brs.bill_rate_code bill_rate_code,
                brs.flat_rate flat_rate,
                brs.uom uom,
                brs.holiday_yn holiday_yn,
                brs.percent_over_list_price percent_over_list_price,
                brs.object_version_number object_version_number --Added
           FROM oks_billrate_schedules brs
          WHERE brs.bt_cle_id = p_id;
   
      /*
          CURSOR CUR_GET_NEW_BILL_RATE(p_id IN NUMBER,p_object1_id1 IN NUMBER)IS
          SELECT BTY.ID BT_LINE_ID,
                 BTY.start_date start_date,
                 BTY.end_date end_date,
                 BTY.line_number line_number,
                 BRT.ID BR_LINE_ID,
                 BRT.dnz_chr_id dnz_chr_id,
                 TO_NUMBER(BTY_ITEM.object1_id1) bill_type_id
          FROM   okc_k_lines_b BTY,
                 okc_k_lines_b BRT,
                 okc_k_items   BTY_ITEM
          WHERE  BTY.id =p_id
        --  AND    BTY.line_Number = p_line_number
          AND    BTY.lse_id IN (5,23,59)
          AND    BTY.id = BTY_ITEM.cle_id
          AND    BTY_ITEM.dnz_chr_id = BTY.dnz_chr_id
          AND    BTY_ITEM.jtot_object1_code = 'OKX_BILLTYPE'
          AND    BRT.cle_id = BTY.id
          AND    BRT.lse_id IN (6,24,60)
          AND    TO_NUMBER(BTY_ITEM.object1_id1) = p_object1_id1
          ORDER BY  BTY.start_date,BTY.end_date,bill_type_id;
      */
   
      -- CURSOR CUR_GET_NEW_BILL_RATE modified for bug#4155384 - smohapat
   
      CURSOR cur_get_new_bill_rate(p_bt_id IN NUMBER, p_old_brs_id IN NUMBER) IS
         SELECT brt.id         brs_line_id,
                brt.cle_id     brs_cle_line_id,
                brt.dnz_chr_id dnz_chr_id
           FROM okc_k_lines_b brt
          WHERE brt.cle_id = p_bt_id AND
                brt.lse_id IN (6, 24, 60) AND
                brt.orig_system_id1 = p_old_brs_id;
   
      -- get the old and new coverage timezones and covered times for the business process
   
      CURSOR cur_get_old_busi_proc(p_cle_id IN NUMBER) IS
         SELECT lines1.id old_bp_line_id,
                to_number(items.object1_id1) old_busi_proc_id
           FROM okc_k_lines_b lines1, okc_k_items items
          WHERE lines1.cle_id = p_cle_id AND
                lines1.lse_id IN (3, 16, 21) AND
                items.cle_id = lines1.id AND
                items.jtot_object1_code = 'OKX_BUSIPROC' AND
                items.dnz_chr_id = lines1.dnz_chr_id;
   
      /*
      
      CURSOR CUR_GET_OLD_COV_TZ(p_id IN NUMBER,p_cle_id IN NUMBER)    IS
           SELECT tze.id timezone_line_id, tze.cle_id timezone_cle_id,
                  tze.timezone_id timezone_id,tze.default_yn default_yn,
                  tze.dnz_chr_id tze_dnz_chr_id,tze.object_version_number tze_object_version_number,
                  to_number(items.object1_id1) busi_proc_id
           FROM   OKC_K_LINES_B lines1,
                              okc_k_items items,
                  oks_coverage_timezones tze
           WHERE  lines1.id     = p_id
           AND    lines1.cle_id = p_cle_id
           AND    lines1.lse_id IN (3,16,21)
           AND    items.cle_id = lines1.id
           and    items.jtot_object1_code = 'OKX_BUSIPROC'
           And    items.dnz_chr_id = lines1.dnz_chr_id
           And    lines1.dnz_chr_id = tze.dnz_chr_id
           AND    tze.cle_id = lines1.id
           ORDER BY   to_number(items.object1_id1),
                                      lines1.start_date, lines1.end_date, tze.timezone_id;
      
      */
      -- CURSOR CUR_GET_OLD_COV_TZ modified for bug#4155384 - smohapat
      CURSOR cur_get_old_cov_tz(p_bp_line_id IN NUMBER) IS
         SELECT tze.id                    timezone_line_id,
                tze.cle_id                timezone_cle_id,
                tze.timezone_id           timezone_id,
                tze.default_yn            default_yn,
                tze.dnz_chr_id            tze_dnz_chr_id,
                tze.object_version_number tze_object_version_number
           FROM oks_coverage_timezones tze
          WHERE tze.cle_id = p_bp_line_id;
   
      CURSOR cur_get_old_times(p_cle_id IN NUMBER, p_dnz_chr_id IN NUMBER) IS
      
         SELECT times.id                    cover_time_line_id,
                times.dnz_chr_id            times_dnz_chr_id,
                times.start_hour            start_hour,
                times.start_minute          start_minute,
                times.end_hour              end_hour,
                times.end_minute            end_minute,
                times.monday_yn             monday_yn,
                times.tuesday_yn            tuesday_yn,
                times.wednesday_yn          wednesday_yn,
                times.thursday_yn           thursday_yn,
                times.friday_yn             friday_yn,
                times.saturday_yn           saturday_yn,
                times.sunday_yn             sunday_yn,
                times.object_version_number object_version_number
           FROM oks_coverage_times times
          WHERE times.cov_tze_line_id = p_cle_id AND
                times.dnz_chr_id = p_dnz_chr_id;
   
      CURSOR cur_get_new_busi_proc_id(p_cle_id IN NUMBER, p_busi_proc_id IN NUMBER) IS
         SELECT lines1.id new_bp_line_id,
                lines1.dnz_chr_id new_dnz_chr_id,
                to_number(items1.object1_id1) busi_proc_id
           FROM okc_k_lines_b lines1, okc_k_items items1
          WHERE lines1.cle_id = p_cle_id AND
                lines1.lse_id IN (3, 16, 21) AND
                items1.cle_id = lines1.id AND
                items1.jtot_object1_code = 'OKX_BUSIPROC' AND
                to_number(items1.object1_id1) = p_busi_proc_id
          ORDER BY to_number(items1.object1_id1),
                   lines1.start_date,
                   lines1.end_date;
   
      --cu_get_new_busi_proc_id cur_get_new_busi_proc_id%ROWTYPE;
   
      CURSOR bill_rate_cur(p_id IN NUMBER, p_dnz_chr_id IN NUMBER) IS
         SELECT id, dnz_chr_id
           FROM okc_k_lines_b
          WHERE cle_id = p_id AND
                dnz_chr_id = p_dnz_chr_id;
   
      l_new_bp_exists   BOOLEAN := FALSE;
      --l_new_br_exists   BOOLEAN := FALSE;
      --l_new_bt_exists   BOOLEAN := FALSE;
      l_cov_time_exists BOOLEAN := FALSE;
      l_count           NUMBER := 0;
      l_cov_templ_yn    VARCHAR2(1);
      l_pm_program_id   NUMBER;
      l_oks_exist       VARCHAR2(1);
   
      /* Added by jvorugan as part of Copy API Redesign,this function
      checks if oks_k_lines_b record already exists and returns the status */
      FUNCTION check_oksline_exist(p_new_cle_id NUMBER,
                                   x_oks_exist  OUT NOCOPY VARCHAR2)
         RETURN VARCHAR2 IS
      
         CURSOR check_line_exist IS
            SELECT 1
              FROM oks_k_lines_b
             WHERE cle_id = p_new_cle_id AND
                   rownum = 1;
      
         l_count         NUMBER := 0;
         x_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      
      BEGIN
         OPEN check_line_exist;
         FETCH check_line_exist
            INTO l_count;
         CLOSE check_line_exist;
      
         IF l_count > 0 THEN
            x_oks_exist := 'Y';
         ELSE
            x_oks_exist := 'N';
         END IF;
         RETURN(x_return_status);
      
      EXCEPTION
         WHEN OTHERS THEN
            okc_api.set_message(g_app_name,
                                g_unexpected_error,
                                g_sqlcode_token,
                                SQLCODE,
                                g_sqlerrm_token,
                                SQLERRM);
            x_return_status := okc_api.g_ret_sts_unexp_error;
            RETURN(x_return_status);
         
      END check_oksline_exist;
   
   BEGIN
   
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.set_indentation('Create_Actual_Coverage');
         okc_debug.log('Entered Copy_Coverage', 2);
      END IF;
   
      l_new_contract_line_id := p_contract_line_id;
   
      OPEN cur_get_orig_sys_id1(l_new_contract_line_id);
      FETCH cur_get_orig_sys_id1
         INTO l_orig_sys_id1;
      CLOSE cur_get_orig_sys_id1;
   
      -- Added by jvorugan for copyying template
      OPEN check_cov_tmpl(l_new_contract_line_id);
      FETCH check_cov_tmpl
         INTO l_count;
      CLOSE check_cov_tmpl;
      IF l_count > 0 THEN
         l_cov_templ_yn := 'Y';
      ELSE
         l_cov_templ_yn := 'N';
      END IF;
   
      IF l_cov_templ_yn = 'N' -- Get values associated with service line
       THEN
         OPEN cur_get_cov_line_id(l_orig_sys_id1);
         FETCH cur_get_cov_line_id
            INTO cr_cov_line;
         IF cur_get_cov_line_id%FOUND THEN
            l_old_cov_line_id    := cr_cov_line.id;
            l_old_dnz_chr_id     := cr_cov_line.dnz_chr_id;
            l_old_cov_start_date := cr_cov_line.start_date;
            l_old_cov_end_date   := cr_cov_line.end_date;
         END IF;
         CLOSE cur_get_cov_line_id;
      
         OPEN cur_get_cov_line_id(l_new_contract_line_id);
         FETCH cur_get_cov_line_id
            INTO cr_cov_line;
         IF cur_get_cov_line_id%FOUND THEN
            l_new_cov_line_id    := cr_cov_line.id;
            l_new_dnz_chr_id     := cr_cov_line.dnz_chr_id;
            l_new_cov_start_date := cr_cov_line.start_date;
            l_new_cov_end_date   := cr_cov_line.end_date;
         END IF;
         CLOSE cur_get_cov_line_id;
      
      ELSE
         -- Get values associated with template
         OPEN cur_get_cov_det(l_orig_sys_id1);
         FETCH cur_get_cov_det
            INTO cr_cov_det;
         IF cur_get_cov_det%FOUND THEN
            l_old_cov_line_id    := cr_cov_det.id;
            l_old_dnz_chr_id     := cr_cov_det.dnz_chr_id;
            l_old_cov_start_date := cr_cov_det.start_date;
            l_old_cov_end_date   := cr_cov_det.end_date;
         END IF;
         CLOSE cur_get_cov_det;
      
         OPEN cur_get_cov_det(l_new_contract_line_id);
         FETCH cur_get_cov_det
            INTO cr_cov_det;
         IF cur_get_cov_det%FOUND THEN
            l_new_cov_line_id    := cr_cov_det.id;
            l_new_dnz_chr_id     := cr_cov_det.dnz_chr_id;
            l_new_cov_start_date := cr_cov_det.start_date;
            l_new_cov_end_date   := cr_cov_det.end_date;
         END IF;
         CLOSE cur_get_cov_det;
      
      END IF;
   
      IF l_old_cov_line_id IS NOT NULL AND l_new_cov_line_id IS NOT NULL THEN
         ---1
         -- Added by Jvorugan if oks_k_lines_b record already exists,then not created
         l_return_status := check_oksline_exist(p_new_cle_id => l_new_cov_line_id,
                                                x_oks_exist  => l_oks_exist);
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('AFTER  CHECK_OKSLINE_EXIST1' || l_return_status,
                          2);
         END IF;
      
         IF NOT l_return_status = okc_api.g_ret_sts_success THEN
            RAISE g_exception_halt_validation;
         END IF;
         x_return_status := l_return_status;
         IF l_oks_exist = 'N' THEN
            FOR cov_attr_rec IN cur_get_cov_attr(l_old_cov_line_id) LOOP
               init_oks_k_line(l_klnv_tbl_in);
            
               l_klnv_tbl_in(1).cle_id := l_new_cov_line_id;
               l_klnv_tbl_in(1).dnz_chr_id := l_new_dnz_chr_id;
               l_klnv_tbl_in(1).coverage_type := cov_attr_rec.coverage_type;
               l_klnv_tbl_in(1).exception_cov_id := cov_attr_rec.exception_cov_id;
               l_klnv_tbl_in(1).transfer_option := cov_attr_rec.transfer_option;
               l_klnv_tbl_in(1).prod_upgrade_yn := cov_attr_rec.prod_upgrade_yn;
               l_klnv_tbl_in(1).inheritance_type := cov_attr_rec.inheritance_type;
               l_klnv_tbl_in(1).sfwt_flag := 'N';
               l_klnv_tbl_in(1).sync_date_install := cov_attr_rec.sync_date_install;
               l_klnv_tbl_in(1).pm_program_id := cov_attr_rec.pm_program_id;
               l_klnv_tbl_in(1).pm_conf_req_yn := cov_attr_rec.pm_conf_req_yn;
               l_klnv_tbl_in(1).pm_sch_exists_yn := cov_attr_rec.pm_sch_exists_yn;
               l_klnv_tbl_in(1).object_version_number := cov_attr_rec.object_version_number;
            
               oks_contract_line_pub.create_line(p_api_version   => l_api_version,
                                                 p_init_msg_list => l_init_msg_list,
                                                 x_return_status => l_return_status,
                                                 x_msg_count     => l_msg_count,
                                                 x_msg_data      => l_msg_data,
                                                 p_klnv_tbl      => l_klnv_tbl_in,
                                                 x_klnv_tbl      => l_klnv_tbl_out,
                                                 p_validate_yn   => l_validate_yn);
            
               IF (g_debug_enabled = 'Y') THEN
                  okc_debug.log('After OKS_CONTRACT_LINE_PUB.CREATE_LINE' ||
                                l_return_status,
                                2);
               END IF;
            
               IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                  RAISE g_exception_halt_validation;
               END IF;
               x_return_status := l_return_status;
            
               IF l_klnv_tbl_in(1).pm_program_id IS NOT NULL THEN
                  -- Copy PM for coverage template
                  IF l_cov_templ_yn = 'Y' THEN
                     oks_pm_programs_pvt.copy_pm_template(p_api_version     => l_api_version,
                                                          p_init_msg_list   => 'T',
                                                          x_return_status   => l_return_status,
                                                          x_msg_count       => x_msg_count,
                                                          x_msg_data        => x_msg_data,
                                                          p_old_coverage_id => l_old_cov_line_id,
                                                          p_new_coverage_id => l_new_cov_line_id);
                     IF (g_debug_enabled = 'Y') THEN
                        okc_debug.log('AFTER CALLING OKS_PM_PROGRAMS_PVT.Copy_pm_template' ||
                                      l_return_status,
                                      2);
                     END IF;
                  
                     IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                        RAISE g_exception_halt_validation;
                     END IF;
                  END IF;
               
               END IF; -- PM Ends
            
            END LOOP; -- Coverage End
         END IF; -- End  for oks_line_exist check
      
         -- BP STARTS HERE
      
         init_oks_k_line(l_klnv_tbl_in);
         i := 0;
         FOR old_bp_rec IN cur_get_old_bp(l_old_cov_line_id) LOOP
            -- OLD BP
            l_klnv_tbl_in.DELETE;
            i                := i + 1;
            l_old_bp_line_id := old_bp_rec.bp_line_id;
            -- Added by jvorugan as a part of Copy API Redesign
            FOR new_bp_rec IN cur_get_new_bp(l_new_cov_line_id,
                                             old_bp_rec.bp_line_id) LOOP
               l_new_bp_exists := TRUE;
               l_new_bp_line_id := new_bp_rec.bp_line_id;
               l_klnv_tbl_in(i).cle_id := new_bp_rec.bp_line_id;
               l_klnv_tbl_in(i).dnz_chr_id := new_bp_rec.dnz_chr_id;
            
            END LOOP;
            -- Added by Jvorugan if oks_k_lines_b record already exists,then not created
            l_return_status := check_oksline_exist(p_new_cle_id => l_new_bp_line_id,
                                                   x_oks_exist  => l_oks_exist);
            IF (g_debug_enabled = 'Y') THEN
               okc_debug.log('AFTER  CHECK_OKSLINE_EXIST2' ||
                             l_return_status,
                             2);
            END IF;
         
            IF NOT l_return_status = okc_api.g_ret_sts_success THEN
               RAISE g_exception_halt_validation;
            END IF;
            x_return_status := l_return_status;
            IF l_oks_exist = 'N' THEN
               l_klnv_tbl_in(i).discount_list := old_bp_rec.discount_list;
               l_klnv_tbl_in(i).offset_duration := old_bp_rec.offset_duration;
               l_klnv_tbl_in(i).offset_period := old_bp_rec.offset_period;
               l_klnv_tbl_in(i).allow_bt_discount := old_bp_rec.allow_bt_discount;
               l_klnv_tbl_in(i).apply_default_timezone := old_bp_rec.apply_default_timezone;
               l_klnv_tbl_in(i).object_version_number := old_bp_rec.object_version_number;
            
               --   i:= 0;
            
               /*    FOR new_bp_rec IN CUR_GET_NEW_BP(l_new_cov_line_id , OLD_BP_REC.BP_LINE_ID)    LOOP
                  l_new_bp_exists := TRUE;
                  l_new_Bp_line_Id            :=  new_bp_rec.bp_line_id;
                  l_klnv_tbl_in(i).CLE_ID      := new_bp_rec.bp_line_id;
                  l_klnv_tbl_in(i).DNZ_CHR_ID  := new_bp_rec.dnz_chr_id;
               
               END LOOP ; */ --commented by JVORUGAN
            
               IF l_klnv_tbl_in.COUNT > 0 AND (l_new_bp_exists = TRUE) THEN
                  -- 2
               
                  oks_contract_line_pub.create_line(p_api_version   => l_api_version,
                                                    p_init_msg_list => l_init_msg_list,
                                                    x_return_status => l_return_status,
                                                    x_msg_count     => l_msg_count,
                                                    x_msg_data      => l_msg_data,
                                                    p_klnv_tbl      => l_klnv_tbl_in,
                                                    x_klnv_tbl      => l_klnv_tbl_out,
                                                    p_validate_yn   => l_validate_yn);
               
                  IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                     RAISE g_exception_halt_validation;
                  END IF;
                  x_return_status := l_return_status;
               END IF; -- 2 -- BP ENDS HERE
            END IF; -- End  for oks_line_exist check
         
            /****************************************************/
         
            IF l_return_status = okc_api.g_ret_sts_success THEN
               ---- For Time Zones
            
               init_oks_timezone_line(l_timezone_tbl_in);
               init_oks_cover_time_line(l_cover_time_tbl_in);
            
               m := 0;
               n := 0;
            
               FOR old_times_rec IN cur_get_old_cov_tz(l_old_bp_line_id) LOOP
                  -- TZ LOOP
               
                  m                 := m + 1;
                  l_cov_time_exists := TRUE;
               
                  --   IF i = 1 OR ((l_tze_id <> old_times_rec.timezone_id) OR(l_bp_id  <> old_times_rec.busi_proc_id))then
                  l_old_time_zone_id := old_times_rec.timezone_line_id;
                  l_old_time_zone_dnz_chr_id := old_times_rec.tze_dnz_chr_id;
                  l_timezone_tbl_in(m).default_yn := old_times_rec.default_yn;
                  l_timezone_tbl_in(m).timezone_id := old_times_rec.timezone_id;
                  l_timezone_tbl_in(m).object_version_number := old_times_rec.tze_object_version_number;
               
                  l_timezone_tbl_in(m).cle_id := l_new_bp_line_id;
                  l_timezone_tbl_in(m).dnz_chr_id := l_new_dnz_chr_id;
               
                  -- create the time zone record here
                  oks_ctz_pvt.insert_row(p_api_version                  => l_api_version,
                                         p_init_msg_list                => l_init_msg_list,
                                         x_return_status                => l_return_status,
                                         x_msg_count                    => l_msg_count,
                                         x_msg_data                     => l_msg_data,
                                         p_oks_coverage_timezones_v_tbl => l_timezone_tbl_in,
                                         x_oks_coverage_timezones_v_tbl => l_timezone_tbl_out);
               
                  IF (g_debug_enabled = 'Y') THEN
                     okc_debug.log('After OKS_CTZ_PVT INSERT_ROW' ||
                                   l_return_status,
                                   2);
                  END IF;
               
                  IF l_return_status = okc_api.g_ret_sts_success THEN
                     IF l_timezone_tbl_out.COUNT > 0 THEN
                        FOR i IN l_timezone_tbl_out.FIRST .. l_timezone_tbl_out.LAST LOOP
                           l_new_timezone_id := l_timezone_tbl_out(m).id;
                        END LOOP;
                     ELSE
                        RAISE g_exception_halt_validation;
                     END IF;
                  ELSE
                     RAISE g_exception_halt_validation;
                  END IF;
               
                  IF l_new_timezone_id IS NOT NULL THEN
                     FOR cur_get_old_times_rec IN cur_get_old_times(l_old_time_zone_id,
                                                                    l_old_time_zone_dnz_chr_id) LOOP
                        n := n + 1;
                        l_cover_time_tbl_in(n).cov_tze_line_id := l_new_timezone_id;
                        l_cover_time_tbl_in(n).dnz_chr_id := l_new_dnz_chr_id;
                        l_cover_time_tbl_in(n).start_hour := cur_get_old_times_rec.start_hour;
                        l_cover_time_tbl_in(n).start_minute := cur_get_old_times_rec.start_minute;
                        l_cover_time_tbl_in(n).end_hour := cur_get_old_times_rec.end_hour;
                        l_cover_time_tbl_in(n).end_minute := cur_get_old_times_rec.end_minute;
                        l_cover_time_tbl_in(n).monday_yn := cur_get_old_times_rec.monday_yn;
                        l_cover_time_tbl_in(n).tuesday_yn := cur_get_old_times_rec.tuesday_yn;
                        l_cover_time_tbl_in(n).wednesday_yn := cur_get_old_times_rec.wednesday_yn;
                        l_cover_time_tbl_in(n).thursday_yn := cur_get_old_times_rec.thursday_yn;
                        l_cover_time_tbl_in(n).friday_yn := cur_get_old_times_rec.friday_yn;
                        l_cover_time_tbl_in(n).saturday_yn := cur_get_old_times_rec.saturday_yn;
                        l_cover_time_tbl_in(n).sunday_yn := cur_get_old_times_rec.sunday_yn;
                        l_cover_time_tbl_in(n).object_version_number := cur_get_old_times_rec.object_version_number;
                     END LOOP;
                  
                     IF l_cover_time_tbl_in.COUNT > 0 THEN
                     
                        oks_cvt_pvt.insert_row(p_api_version              => l_api_version,
                                               p_init_msg_list            => l_init_msg_list,
                                               x_return_status            => l_return_status,
                                               x_msg_count                => l_msg_count,
                                               x_msg_data                 => l_msg_data,
                                               p_oks_coverage_times_v_tbl => l_cover_time_tbl_in,
                                               x_oks_coverage_times_v_tbl => l_cover_time_tbl_out);
                     
                     END IF;
                  
                     IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                        RAISE g_exception_halt_validation;
                     ELSE
                        l_timezone_tbl_in.DELETE;
                        l_cover_time_tbl_in.DELETE;
                     END IF;
                  
                  END IF;
               
               END LOOP; -- TZ LOOP
            END IF; --For Time Zones
         
            /************************************************************************************/
            -- RT Starts HERE
         
            FOR rec_get_old_rt IN cur_get_old_rt(l_old_bp_line_id) LOOP
               -- OLD RT
               l := 0;
               l_klnv_tbl_in.DELETE;
               l := l + 1;
            
               l_line_number   := rec_get_old_rt.rt_line_number;
               l_rt_id         := rec_get_old_rt.rt_line_id;
               l_rt_dnz_chr_id := rec_get_old_rt.rt_dnz_chr_id;
            
               --Added by JVORUGAN as a part of COPY API Redesign
               FOR new_bp_rec IN cur_get_new_rt(l_new_bp_line_id,
                                                rec_get_old_rt.rt_line_id) LOOP
                  --2
               
                  l_klnv_tbl_in(l).cle_id := new_bp_rec.id;
                  l_klnv_tbl_in(l).dnz_chr_id := new_bp_rec.dnz_chr_id;
               
               END LOOP; --2
               -- Added by Jvorugan if oks_k_lines_b record already exists,then not created
               l_return_status := check_oksline_exist(p_new_cle_id => l_klnv_tbl_in(l)
                                                                     .cle_id,
                                                      x_oks_exist  => l_oks_exist);
            
               IF (g_debug_enabled = 'Y') THEN
                  okc_debug.log('AFTER  CHECK_OKSLINE_EXIST3' ||
                                l_return_status,
                                2);
               END IF;
            
               IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                  RAISE g_exception_halt_validation;
               END IF;
               x_return_status := l_return_status;
               IF l_oks_exist = 'N' THEN
               
                  l_klnv_tbl_in(l).discount_list := rec_get_old_rt.discount_list;
                  l_klnv_tbl_in(l).offset_duration := rec_get_old_rt.offset_duration;
                  l_klnv_tbl_in(l).offset_period := rec_get_old_rt.offset_period;
                  l_klnv_tbl_in(l).allow_bt_discount := rec_get_old_rt.allow_bt_discount;
                  l_klnv_tbl_in(l).apply_default_timezone := rec_get_old_rt.apply_default_timezone;
                  l_klnv_tbl_in(l).object_version_number := rec_get_old_rt.object_version_number;
                  l_klnv_tbl_in(l).incident_severity_id := rec_get_old_rt.incident_severity_id;
                  l_klnv_tbl_in(l).work_thru_yn := rec_get_old_rt.work_thru_yn;
                  l_klnv_tbl_in(l).react_active_yn := rec_get_old_rt.react_active_yn;
                  l_klnv_tbl_in(l).sfwt_flag := rec_get_old_rt.sfwt_flag;
                  l_klnv_tbl_in(l).react_time_name := rec_get_old_rt.react_time_name;
               
                  /*        FOR new_bp_rec IN CUR_GET_NEW_RT(l_new_Bp_line_Id,REC_GET_OLD_RT.Rt_Line_ID) LOOP --2
                  
                  l_klnv_tbl_in(l).CLE_ID      := new_bp_rec.id;
                  l_klnv_tbl_in(l).DNZ_CHR_ID  := new_bp_rec.dnz_chr_id;
                  
                  END LOOP ; --2  */ --commented by Jvorugan
                  IF l_klnv_tbl_in.COUNT > 0 THEN
                     -- 2
                  
                     oks_contract_line_pub.create_line(p_api_version   => l_api_version,
                                                       p_init_msg_list => l_init_msg_list,
                                                       x_return_status => l_return_status,
                                                       x_msg_count     => l_msg_count,
                                                       x_msg_data      => l_msg_data,
                                                       p_klnv_tbl      => l_klnv_tbl_in,
                                                       x_klnv_tbl      => l_klnv_tbl_out,
                                                       p_validate_yn   => l_validate_yn);
                  
                     IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                        RAISE g_exception_halt_validation;
                     ELSE
                        l_klnv_tbl_in.DELETE;
                        FOR i IN l_klnv_tbl_out.FIRST .. l_klnv_tbl_out.LAST LOOP
                           l_line_id_four := l_klnv_tbl_out(i).cle_id;
                        END LOOP;
                     END IF;
                     x_return_status := l_return_status;
                  END IF; -- 2
               END IF; -- End  for oks_line_exist check
            
               FOR get_old_act_time_types_rec IN get_old_act_time_types(l_rt_id,
                                                                        l_rt_dnz_chr_id) LOOP
                  --3
                  l_act_pvt_tbl_in.DELETE;
                  k            := k + 1;
                  l_act_pvt_id := get_old_act_time_types_rec.id;
               
                  l_act_pvt_tbl_in(k).cle_id := l_line_id_four;
                  l_act_pvt_tbl_in(k).dnz_chr_id := l_new_dnz_chr_id; --Get_Old_Act_Time_Types_Rec.Dnz_Chr_ID;
                  l_act_pvt_tbl_in(k).action_type_code := get_old_act_time_types_rec.action_type_code;
                  l_act_pvt_tbl_in(k).object_version_number := get_old_act_time_types_rec.object_version_number;
               
                  oks_act_pvt.insert_row(p_api_version                 => l_api_version,
                                         p_init_msg_list               => l_init_msg_list,
                                         x_return_status               => l_return_status,
                                         x_msg_count                   => l_msg_count,
                                         x_msg_data                    => l_msg_data,
                                         p_oks_action_time_types_v_tbl => l_act_pvt_tbl_in,
                                         x_oks_action_time_types_v_tbl => l_act_pvt_tbl_out);
               
                  IF (g_debug_enabled = 'Y') THEN
                     okc_debug.log('After oks_act_pvt insert_row' ||
                                   l_return_status,
                                   2);
                  END IF;
               
                  IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                     RAISE g_exception_halt_validation;
                  ELSE
                     FOR i IN l_act_pvt_tbl_out.FIRST .. l_act_pvt_tbl_out.LAST LOOP
                        l_act_pvt_new_id     := l_act_pvt_tbl_out(i).id;
                        l_act_pvt_dnz_chr_id := l_act_pvt_tbl_out(i)
                                               .dnz_chr_id;
                        l_act_pvt_cle_id     := l_act_pvt_tbl_out(i).cle_id;
                     END LOOP;
                  END IF;
               
                  FOR get_old_act_times_rec IN get_old_act_times_cur(l_act_pvt_id,
                                                                     get_old_act_time_types_rec.dnz_chr_id) LOOP
                     --4
                     l_acm_pvt_tbl_in.DELETE;
                     f := f + 1;
                     l_acm_pvt_tbl_in(f).cov_action_type_id := l_act_pvt_new_id;
                     l_acm_pvt_tbl_in(f).cle_id := l_act_pvt_cle_id;
                     l_acm_pvt_tbl_in(f).dnz_chr_id := l_act_pvt_dnz_chr_id;
                     l_acm_pvt_tbl_in(f).uom_code := get_old_act_times_rec.uom_code;
                     l_acm_pvt_tbl_in(f).sun_duration := get_old_act_times_rec.sun_duration;
                     l_acm_pvt_tbl_in(f).mon_duration := get_old_act_times_rec.mon_duration;
                     l_acm_pvt_tbl_in(f).tue_duration := get_old_act_times_rec.tue_duration;
                     l_acm_pvt_tbl_in(f).wed_duration := get_old_act_times_rec.wed_duration;
                     l_acm_pvt_tbl_in(f).thu_duration := get_old_act_times_rec.thu_duration;
                     l_acm_pvt_tbl_in(f).fri_duration := get_old_act_times_rec.fri_duration;
                     l_acm_pvt_tbl_in(f).sat_duration := get_old_act_times_rec.sat_duration;
                     l_acm_pvt_tbl_in(f).security_group_id := get_old_act_times_rec.security_group_id;
                     l_acm_pvt_tbl_in(f).object_version_number := get_old_act_times_rec.object_version_number;
                  
                     oks_acm_pvt.insert_row(p_api_version            => l_api_version,
                                            p_init_msg_list          => l_init_msg_list,
                                            x_return_status          => l_return_status,
                                            x_msg_count              => l_msg_count,
                                            x_msg_data               => l_msg_data,
                                            p_oks_action_times_v_tbl => l_acm_pvt_tbl_in,
                                            x_oks_action_times_v_tbl => l_acm_pvt_tbl_out);
                  
                     IF (g_debug_enabled = 'Y') THEN
                        okc_debug.log('After OKS_ACM_PVT insert_row' ||
                                      l_return_status,
                                      2);
                     END IF;
                  
                     IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                        RAISE g_exception_halt_validation;
                     ELSE
                        l_acm_pvt_tbl_in.DELETE;
                        l_act_pvt_tbl_in.DELETE;
                        l_klnv_tbl_in.DELETE;
                     END IF;
                  
                  END LOOP; --4
                  x_return_status := l_return_status;
               END LOOP; --3
            END LOOP; -- OLD RT
         
            -- RT Ends HERE
         
            /******************************************************************************/
            -- BT STARTS HERE
         
            init_oks_k_line(l_klnv_tbl_in);
         
            i := 0;
         
            --FOR old_bt_rec IN CUR_GET_OLD_BT(l_old_cov_line_id)     LOOP --BT LOOP
            FOR old_bt_rec IN cur_get_old_bt(l_old_bp_line_id) LOOP
               --l_old_bp_line_id)  LOOP
               l_klnv_tbl_in.DELETE;
               i := i + 1;
            
               l_old_bill_type_id := old_bt_rec.bt_line_id;
               l_old_line_number  := old_bt_rec.line_number;
            
               l_klnv_tbl_in(i).discount_amount := old_bt_rec.discount_amount;
               l_klnv_tbl_in(i).discount_percent := old_bt_rec.discount_percent;
               l_klnv_tbl_in(i).object_version_number := old_bt_rec.object_version_number;
            
               FOR new_bt_rec IN cur_get_new_bt(l_new_bp_line_id,
                                                old_bt_rec.bt_line_id) LOOP
                  l_klnv_tbl_in(i).cle_id := new_bt_rec.bt_line_id;
                  l_klnv_tbl_in(i).dnz_chr_id := new_bt_rec.dnz_chr_id;
                  l_klnv_tbl_in(i).object_version_number := new_bt_rec.object_version_number;
               
               END LOOP;
               -- Added by Jvorugan if oks_k_lines_b record already exists,then not created
               l_return_status := check_oksline_exist(p_new_cle_id => l_klnv_tbl_in(i)
                                                                     .cle_id,
                                                      x_oks_exist  => l_oks_exist);
               IF (g_debug_enabled = 'Y') THEN
                  okc_debug.log('AFTER  CHECK_OKSLINE_EXIST4' ||
                                l_return_status,
                                2);
               END IF;
            
               IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                  RAISE g_exception_halt_validation;
               END IF;
               x_return_status := l_return_status;
               IF l_oks_exist = 'N' THEN
               
                  oks_contract_line_pub.create_line(p_api_version   => l_api_version,
                                                    p_init_msg_list => l_init_msg_list,
                                                    x_return_status => l_return_status,
                                                    x_msg_count     => l_msg_count,
                                                    x_msg_data      => l_msg_data,
                                                    p_klnv_tbl      => l_klnv_tbl_in,
                                                    x_klnv_tbl      => l_klnv_tbl_out,
                                                    p_validate_yn   => l_validate_yn);
               
                  IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                     RAISE g_exception_halt_validation;
                  ELSE
                     l_klnv_tbl_in.DELETE;
                     FOR i IN l_klnv_tbl_out.FIRST .. l_klnv_tbl_out.LAST LOOP
                        l_bill_type_id         := l_klnv_tbl_out(i).cle_id;
                        l_bill_type_dnz_chr_id := l_klnv_tbl_out(i)
                                                 .dnz_chr_id;
                     END LOOP;
                  END IF;
               END IF; -- End  for oks_line_exist check
            
               /****************************************************************************/
               l_klnv_tbl_in.DELETE;
            
               FOR bill_rate_rec IN bill_rate_cur(l_bill_type_id,
                                                  l_bill_type_dnz_chr_id) LOOP
                  l_klnv_tbl_in(i).cle_id := bill_rate_rec.id;
                  l_klnv_tbl_in(i).dnz_chr_id := bill_rate_rec.dnz_chr_id;
                  -- Added by Jvorugan if oks_k_lines_b record already exists,then not created
                  l_return_status := check_oksline_exist(p_new_cle_id => l_klnv_tbl_in(i)
                                                                        .cle_id,
                                                         x_oks_exist  => l_oks_exist);
                  IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                     RAISE g_exception_halt_validation;
                  END IF;
                  x_return_status := l_return_status;
                  IF l_oks_exist = 'N' THEN
                  
                     oks_contract_line_pub.create_line(p_api_version   => l_api_version,
                                                       p_init_msg_list => l_init_msg_list,
                                                       x_return_status => l_return_status,
                                                       x_msg_count     => l_msg_count,
                                                       x_msg_data      => l_msg_data,
                                                       p_klnv_tbl      => l_klnv_tbl_in,
                                                       x_klnv_tbl      => l_klnv_tbl_out,
                                                       p_validate_yn   => l_validate_yn);
                  
                     IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                        RAISE g_exception_halt_validation;
                     END IF;
                  END IF; -- End  for oks_line_exist check
               END LOOP;
            
               /*****************************************************************************/
            
               init_bill_rate_line(l_billrate_sch_tbl_in);
            
               i := 0;
               l_billrate_sch_tbl_in.DELETE;
            
               FOR old_brs_rec IN cur_get_old_bill_rate(l_old_bill_type_id) LOOP
                  i := i + 1;
               
                  l_billrate_sch_tbl_in(i).start_hour := old_brs_rec.start_hour;
                  l_billrate_sch_tbl_in(i).start_minute := old_brs_rec.start_minute;
                  l_billrate_sch_tbl_in(i).end_hour := old_brs_rec.end_hour;
                  l_billrate_sch_tbl_in(i).end_minute := old_brs_rec.end_minute;
                  l_billrate_sch_tbl_in(i).monday_flag := old_brs_rec.monday_flag;
                  l_billrate_sch_tbl_in(i).tuesday_flag := old_brs_rec.tuesday_flag;
                  l_billrate_sch_tbl_in(i).wednesday_flag := old_brs_rec.wednesday_flag;
                  l_billrate_sch_tbl_in(i).thursday_flag := old_brs_rec.thursday_flag;
                  l_billrate_sch_tbl_in(i).friday_flag := old_brs_rec.friday_flag;
                  l_billrate_sch_tbl_in(i).saturday_flag := old_brs_rec.saturday_flag;
                  l_billrate_sch_tbl_in(i).sunday_flag := old_brs_rec.sunday_flag;
                  l_billrate_sch_tbl_in(i).object1_id1 := old_brs_rec.object1_id1;
                  l_billrate_sch_tbl_in(i).object1_id2 := old_brs_rec.object1_id2;
                  l_billrate_sch_tbl_in(i).jtot_object1_code := old_brs_rec.jtot_object1_code;
                  l_billrate_sch_tbl_in(i).bill_rate_code := old_brs_rec.bill_rate_code;
                  l_billrate_sch_tbl_in(i).uom := old_brs_rec.uom;
                  l_billrate_sch_tbl_in(i).flat_rate := old_brs_rec.flat_rate;
                  l_billrate_sch_tbl_in(i).holiday_yn := old_brs_rec.holiday_yn;
                  l_billrate_sch_tbl_in(i).percent_over_list_price := old_brs_rec.percent_over_list_price;
                  l_billrate_sch_tbl_in(i).object_version_number := old_brs_rec.object_version_number;
               
                  FOR new_brs_rec IN cur_get_new_bill_rate(l_bill_type_id,
                                                           old_brs_rec.cle_id) LOOP
                     l_billrate_sch_tbl_in(i).cle_id := new_brs_rec.brs_line_id;
                     l_billrate_sch_tbl_in(i).bt_cle_id := new_brs_rec.brs_cle_line_id;
                     l_billrate_sch_tbl_in(i).dnz_chr_id := new_brs_rec.dnz_chr_id;
                  END LOOP;
               END LOOP;
            
               IF l_billrate_sch_tbl_in.COUNT > 0 THEN
               
                  oks_brs_pvt.insert_row(p_api_version                  => l_api_version,
                                         p_init_msg_list                => l_init_msg_list,
                                         x_return_status                => l_return_status,
                                         x_msg_count                    => l_msg_count,
                                         x_msg_data                     => l_msg_data,
                                         p_oks_billrate_schedules_v_tbl => l_billrate_sch_tbl_in,
                                         x_oks_billrate_schedules_v_tbl => l_billrate_sch_tbl_out);
               
                  IF (g_debug_enabled = 'Y') THEN
                     okc_debug.log('After oks_brs_pvt insert_row' ||
                                   l_return_status,
                                   2);
                  END IF;
               
                  IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                     RAISE g_exception_halt_validation;
                  END IF;
               
                  x_return_status := l_return_status;
               END IF;
            
               -- BR ENDs HERE
            
               x_return_status := l_return_status;
            
            /****************************************************************************/
            END LOOP; --BT LOOP
            /****************************************************************/
         
            x_return_status := l_return_status;
         
         END LOOP; -- OLD BP --BP ENDS
      
      END IF; ---1
   
      copy_notes(p_api_version   => l_api_version,
                 p_init_msg_list => l_init_msg_list,
                 p_line_id       => l_new_contract_line_id,
                 x_return_status => l_return_status,
                 x_msg_count     => l_msg_count,
                 x_msg_data      => l_msg_data);
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.log('AFTER  COPY_NOTES' || l_return_status, 2);
      END IF;
   
      IF NOT l_return_status = okc_api.g_ret_sts_success THEN
         RAISE g_exception_halt_validation;
      END IF;
   
      -- Added as part of R12 coverage Rearchitecture,create Pm schedule and associate with the service line but not coverage line
      IF l_cov_templ_yn = 'N' -- Create pm schedule only if it's not a coverage template
       THEN
         OPEN cur_get_program_id(l_orig_sys_id1);
         FETCH cur_get_program_id
            INTO l_pm_program_id;
         CLOSE cur_get_program_id;
      
         IF l_pm_program_id IS NOT NULL --Generate schedule only if pm_program_id exists
          THEN
            oks_pm_programs_pvt.renew_pm_program_schedule(p_api_version      => l_api_version,
                                                          p_init_msg_list    => l_init_msg_list,
                                                          x_return_status    => l_return_status,
                                                          x_msg_count        => l_msg_count,
                                                          x_msg_data         => l_msg_data,
                                                          p_contract_line_id => l_new_contract_line_id);
         
            IF (g_debug_enabled = 'Y') THEN
               okc_debug.log('After RENEW_PM_PROGRAM_SCHEDULE' ||
                             l_return_status,
                             2);
            END IF;
         
            IF NOT l_return_status = okc_api.g_ret_sts_success THEN
               RAISE g_exception_halt_validation;
            END IF;
         END IF;
      END IF;
      -- End changes for coverage Rearchitecture by jvorugan
   
      x_return_status := okc_api.g_ret_sts_success;
      l_klnv_tbl_in.DELETE;
      l_billrate_sch_tbl_in.DELETE;
      l_timezone_tbl_in.DELETE;
      l_cover_time_tbl_in.DELETE;
   
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.log('End of Copy_Coverage' || l_return_status, 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
   
      WHEN g_exception_halt_validation THEN
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Exp of Copy_Coverage' || SQLERRM, 2);
            okc_debug.reset_indentation;
         END IF;
         x_return_status := l_return_status;
         x_msg_count     := l_msg_count;
         x_msg_data      := l_msg_data;
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      'OKS_COPY_COVERAGE',
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_error THEN
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Exp of Copy_Coverage' || SQLERRM, 2);
            okc_debug.reset_indentation;
         END IF;
         x_msg_count     := l_msg_count;
         x_msg_data      := l_msg_data;
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      'OKS_COPY_COVERAGE',
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Exp of Copy_Coverage' || SQLERRM, 2);
            okc_debug.reset_indentation;
         END IF;
         x_msg_count     := l_msg_count;
         x_msg_data      := l_msg_data;
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      'OKS_COPY_COVERAGE',
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
      WHEN OTHERS THEN
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Exp of Copy_Coverage' || SQLERRM, 2);
            okc_debug.reset_indentation;
         END IF;
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
         x_msg_count     := l_msg_count;
      
   END copy_coverage;

   --===========================================================================================

   PROCEDURE init_oks_k_line(x_klnv_tbl OUT NOCOPY oks_kln_pvt.klnv_tbl_type) IS
   
   BEGIN
   
      x_klnv_tbl(1).id := okc_api.g_miss_num;
      x_klnv_tbl(1).cle_id := okc_api.g_miss_num;
      x_klnv_tbl(1).dnz_chr_id := okc_api.g_miss_num;
      x_klnv_tbl(1).discount_list := okc_api.g_miss_num;
      x_klnv_tbl(1).acct_rule_id := okc_api.g_miss_num;
      x_klnv_tbl(1).payment_type := okc_api.g_miss_char;
      x_klnv_tbl(1).cc_no := okc_api.g_miss_char;
      x_klnv_tbl(1).cc_expiry_date := okc_api.g_miss_date;
      x_klnv_tbl(1).cc_bank_acct_id := okc_api.g_miss_num;
      x_klnv_tbl(1).cc_auth_code := okc_api.g_miss_char;
      x_klnv_tbl(1).commitment_id := okc_api.g_miss_num;
      x_klnv_tbl(1).locked_price_list_id := okc_api.g_miss_num;
      x_klnv_tbl(1).usage_est_yn := okc_api.g_miss_char;
      x_klnv_tbl(1).usage_est_method := okc_api.g_miss_char;
      x_klnv_tbl(1).usage_est_start_date := okc_api.g_miss_date;
      x_klnv_tbl(1).termn_method := okc_api.g_miss_char;
      x_klnv_tbl(1).ubt_amount := okc_api.g_miss_num;
      x_klnv_tbl(1).credit_amount := okc_api.g_miss_num;
      x_klnv_tbl(1).suppressed_credit := okc_api.g_miss_num;
      x_klnv_tbl(1).override_amount := okc_api.g_miss_num;
      x_klnv_tbl(1).grace_duration := okc_api.g_miss_num;
      x_klnv_tbl(1).grace_period := okc_api.g_miss_char;
      x_klnv_tbl(1).inv_print_flag := okc_api.g_miss_char;
      x_klnv_tbl(1).price_uom := okc_api.g_miss_char;
      x_klnv_tbl(1).tax_amount := okc_api.g_miss_num;
      x_klnv_tbl(1).tax_inclusive_yn := okc_api.g_miss_char;
      x_klnv_tbl(1).tax_status := okc_api.g_miss_char;
      x_klnv_tbl(1).tax_code := okc_api.g_miss_num;
      x_klnv_tbl(1).tax_exemption_id := okc_api.g_miss_num;
      x_klnv_tbl(1).ib_trans_type := okc_api.g_miss_char;
      x_klnv_tbl(1).ib_trans_date := okc_api.g_miss_date;
      x_klnv_tbl(1).prod_price := okc_api.g_miss_num;
      x_klnv_tbl(1).service_price := okc_api.g_miss_num;
      x_klnv_tbl(1).clvl_list_price := okc_api.g_miss_num;
      x_klnv_tbl(1).clvl_quantity := okc_api.g_miss_num;
      x_klnv_tbl(1).clvl_extended_amt := okc_api.g_miss_num;
      x_klnv_tbl(1).clvl_uom_code := okc_api.g_miss_char;
      x_klnv_tbl(1).toplvl_operand_code := okc_api.g_miss_char;
      x_klnv_tbl(1).toplvl_operand_val := okc_api.g_miss_num;
      x_klnv_tbl(1).toplvl_quantity := okc_api.g_miss_num;
      x_klnv_tbl(1).toplvl_uom_code := okc_api.g_miss_char;
      x_klnv_tbl(1).toplvl_adj_price := okc_api.g_miss_num;
      x_klnv_tbl(1).toplvl_price_qty := okc_api.g_miss_num;
      x_klnv_tbl(1).averaging_interval := okc_api.g_miss_num;
      x_klnv_tbl(1).settlement_interval := okc_api.g_miss_char;
      x_klnv_tbl(1).minimum_quantity := okc_api.g_miss_num;
      x_klnv_tbl(1).default_quantity := okc_api.g_miss_num;
      x_klnv_tbl(1).amcv_flag := okc_api.g_miss_char;
      x_klnv_tbl(1).fixed_quantity := okc_api.g_miss_num;
      x_klnv_tbl(1).usage_duration := okc_api.g_miss_num;
      x_klnv_tbl(1).usage_period := okc_api.g_miss_char;
      x_klnv_tbl(1).level_yn := okc_api.g_miss_char;
      x_klnv_tbl(1).usage_type := okc_api.g_miss_char;
      x_klnv_tbl(1).uom_quantified := okc_api.g_miss_char;
      x_klnv_tbl(1).base_reading := okc_api.g_miss_num;
      x_klnv_tbl(1).billing_schedule_type := okc_api.g_miss_char;
      x_klnv_tbl(1).coverage_type := okc_api.g_miss_char;
      x_klnv_tbl(1).exception_cov_id := okc_api.g_miss_num;
      x_klnv_tbl(1).limit_uom_quantified := okc_api.g_miss_char;
      x_klnv_tbl(1).discount_amount := okc_api.g_miss_num;
      x_klnv_tbl(1).discount_percent := okc_api.g_miss_num;
      x_klnv_tbl(1).offset_duration := okc_api.g_miss_num;
      x_klnv_tbl(1).offset_period := okc_api.g_miss_char;
      x_klnv_tbl(1).incident_severity_id := okc_api.g_miss_num;
      x_klnv_tbl(1).pdf_id := okc_api.g_miss_num;
      x_klnv_tbl(1).work_thru_yn := okc_api.g_miss_char;
      x_klnv_tbl(1).react_active_yn := okc_api.g_miss_char;
      x_klnv_tbl(1).transfer_option := okc_api.g_miss_char;
      x_klnv_tbl(1).prod_upgrade_yn := okc_api.g_miss_char;
      x_klnv_tbl(1).inheritance_type := okc_api.g_miss_char;
      x_klnv_tbl(1).pm_program_id := okc_api.g_miss_num;
      x_klnv_tbl(1).pm_conf_req_yn := okc_api.g_miss_char;
      x_klnv_tbl(1).pm_sch_exists_yn := okc_api.g_miss_char;
      x_klnv_tbl(1).allow_bt_discount := okc_api.g_miss_char;
      x_klnv_tbl(1).apply_default_timezone := okc_api.g_miss_char;
      x_klnv_tbl(1).sync_date_install := okc_api.g_miss_char;
      x_klnv_tbl(1).sfwt_flag := okc_api.g_miss_char;
      x_klnv_tbl(1).object_version_number := okc_api.g_miss_num;
      x_klnv_tbl(1).security_group_id := okc_api.g_miss_num;
      x_klnv_tbl(1).request_id := okc_api.g_miss_num;
      x_klnv_tbl(1).created_by := okc_api.g_miss_num;
      x_klnv_tbl(1).creation_date := okc_api.g_miss_date;
      x_klnv_tbl(1).last_updated_by := okc_api.g_miss_num;
      x_klnv_tbl(1).last_update_date := okc_api.g_miss_date;
      x_klnv_tbl(1).last_update_login := okc_api.g_miss_num;
   END;

   --================================================================================
   PROCEDURE init_oks_timezone_line(x_timezone_tbl OUT NOCOPY oks_ctz_pvt.okscoveragetimezonesvtbltype) IS
   
   BEGIN
      x_timezone_tbl(1).id := okc_api.g_miss_num;
      x_timezone_tbl(1).cle_id := okc_api.g_miss_num;
      x_timezone_tbl(1).default_yn := okc_api.g_miss_char;
      x_timezone_tbl(1).timezone_id := okc_api.g_miss_num;
      x_timezone_tbl(1).dnz_chr_id := okc_api.g_miss_num;
      x_timezone_tbl(1).created_by := okc_api.g_miss_num;
      x_timezone_tbl(1).creation_date := okc_api.g_miss_date;
      x_timezone_tbl(1).last_updated_by := okc_api.g_miss_num;
      x_timezone_tbl(1).last_update_date := okc_api.g_miss_date;
      x_timezone_tbl(1).last_update_login := okc_api.g_miss_num;
      x_timezone_tbl(1).security_group_id := okc_api.g_miss_num;
      x_timezone_tbl(1).program_application_id := okc_api.g_miss_num;
      x_timezone_tbl(1).program_id := okc_api.g_miss_num;
      x_timezone_tbl(1).program_update_date := okc_api.g_miss_date;
      x_timezone_tbl(1).request_id := okc_api.g_miss_num;
   
   END;
   --=================================================================================
   PROCEDURE init_oks_cover_time_line(x_cover_time_tbl OUT NOCOPY oks_cvt_pvt.oks_coverage_times_v_tbl_type)
   
    IS
   BEGIN
      x_cover_time_tbl(1).id := okc_api.g_miss_num;
      x_cover_time_tbl(1).cov_tze_line_id := okc_api.g_miss_num;
      x_cover_time_tbl(1).dnz_chr_id := okc_api.g_miss_num;
      x_cover_time_tbl(1).start_hour := okc_api.g_miss_num;
      x_cover_time_tbl(1).start_minute := okc_api.g_miss_num;
      x_cover_time_tbl(1).end_hour := okc_api.g_miss_num;
      x_cover_time_tbl(1).end_minute := okc_api.g_miss_num;
      x_cover_time_tbl(1).monday_yn := okc_api.g_miss_char;
      x_cover_time_tbl(1).tuesday_yn := okc_api.g_miss_char;
      x_cover_time_tbl(1).wednesday_yn := okc_api.g_miss_char;
      x_cover_time_tbl(1).thursday_yn := okc_api.g_miss_char;
      x_cover_time_tbl(1).friday_yn := okc_api.g_miss_char;
      x_cover_time_tbl(1).saturday_yn := okc_api.g_miss_char;
      x_cover_time_tbl(1).sunday_yn := okc_api.g_miss_char;
      x_cover_time_tbl(1).created_by := okc_api.g_miss_num;
      x_cover_time_tbl(1).creation_date := okc_api.g_miss_date;
      x_cover_time_tbl(1).last_updated_by := okc_api.g_miss_num;
      x_cover_time_tbl(1).last_update_date := okc_api.g_miss_date;
      x_cover_time_tbl(1).last_update_login := okc_api.g_miss_num;
      x_cover_time_tbl(1).security_group_id := okc_api.g_miss_num;
      x_cover_time_tbl(1).program_application_id := okc_api.g_miss_num;
      x_cover_time_tbl(1).program_id := okc_api.g_miss_num;
      x_cover_time_tbl(1).program_update_date := okc_api.g_miss_date;
      x_cover_time_tbl(1).request_id := okc_api.g_miss_num;
   
   END;
   --==========================================================================

   PROCEDURE init_oks_act_type(x_act_time_tbl OUT NOCOPY oks_act_pvt.oksactiontimetypesvtbltype) IS
   BEGIN
   
      x_act_time_tbl(1).id := okc_api.g_miss_num;
      x_act_time_tbl(1).cle_id := okc_api.g_miss_num;
      x_act_time_tbl(1).dnz_chr_id := okc_api.g_miss_num;
      x_act_time_tbl(1).action_type_code := okc_api.g_miss_char;
      x_act_time_tbl(1).security_group_id := okc_api.g_miss_num;
      x_act_time_tbl(1).program_application_id := okc_api.g_miss_num;
      x_act_time_tbl(1).program_id := okc_api.g_miss_num;
      x_act_time_tbl(1).program_update_date := okc_api.g_miss_date;
      x_act_time_tbl(1).request_id := okc_api.g_miss_num;
      x_act_time_tbl(1).created_by := okc_api.g_miss_num;
      x_act_time_tbl(1).creation_date := okc_api.g_miss_date;
      x_act_time_tbl(1).last_updated_by := okc_api.g_miss_num;
      x_act_time_tbl(1).last_update_date := okc_api.g_miss_date;
      x_act_time_tbl(1).last_update_login := okc_api.g_miss_num;
   END;
   --===============================================================================
   PROCEDURE init_oks_act_time(x_act_type_tbl OUT NOCOPY oks_acm_pvt.oks_action_times_v_tbl_type)
   
    IS
   BEGIN
   
      x_act_type_tbl(1).id := okc_api.g_miss_num;
      x_act_type_tbl(1).cov_action_type_id := okc_api.g_miss_num;
      x_act_type_tbl(1).cle_id := okc_api.g_miss_num;
      x_act_type_tbl(1).dnz_chr_id := okc_api.g_miss_num;
      x_act_type_tbl(1).uom_code := okc_api.g_miss_char;
      x_act_type_tbl(1).sun_duration := okc_api.g_miss_num;
      x_act_type_tbl(1).mon_duration := okc_api.g_miss_num;
      x_act_type_tbl(1).tue_duration := okc_api.g_miss_num;
      x_act_type_tbl(1).wed_duration := okc_api.g_miss_num;
      x_act_type_tbl(1).thu_duration := okc_api.g_miss_num;
      x_act_type_tbl(1).fri_duration := okc_api.g_miss_num;
      x_act_type_tbl(1).sat_duration := okc_api.g_miss_num;
      x_act_type_tbl(1).security_group_id := okc_api.g_miss_num;
      x_act_type_tbl(1).program_application_id := okc_api.g_miss_num;
      x_act_type_tbl(1).program_id := okc_api.g_miss_num;
      x_act_type_tbl(1).program_update_date := okc_api.g_miss_date;
      x_act_type_tbl(1).request_id := okc_api.g_miss_num;
      x_act_type_tbl(1).created_by := okc_api.g_miss_num;
      x_act_type_tbl(1).creation_date := okc_api.g_miss_date;
      x_act_type_tbl(1).last_updated_by := okc_api.g_miss_num;
      x_act_type_tbl(1).last_update_date := okc_api.g_miss_date;
      x_act_type_tbl(1).last_update_login := okc_api.g_miss_num;
   
   END;
   --============================================================================

   PROCEDURE validate_covertime(p_tze_line_id   IN NUMBER,
                                x_days_overlap  OUT NOCOPY oks_coverages_pvt.billrate_day_overlap_type,
                                x_return_status OUT NOCOPY VARCHAR2) IS
      g_pkg_name VARCHAR2(40) := 'OKS_COVERAGES_PVT';
   
      TYPE covertime_schedule_rec IS RECORD(
         start_time NUMBER,
         end_time   NUMBER);
   
      TYPE covertime_schedule_tbl_type IS TABLE OF covertime_schedule_rec INDEX BY BINARY_INTEGER;
   
      i                 NUMBER := 0;
      l_overlap_yn      VARCHAR2(1);
      --l_overlap_message VARCHAR2(200);
   
      l_time_tbl     covertime_schedule_tbl_type;
      l_api_name     VARCHAR2(50) := 'VALIDATE_COVERTIME_SCHEDULE';
      x_msg_count    NUMBER;
      x_msg_data     VARCHAR2(2000);
      l_overlap_days VARCHAR2(1000) := NULL;
   
      CURSOR cur_monday(l_tze_id IN NUMBER) IS
      
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_coverage_times_v
          WHERE cov_tze_line_id = l_tze_id AND
                monday_yn = 'Y';
   
      CURSOR cur_tuesday(l_tze_id IN NUMBER) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_coverage_times_v
          WHERE cov_tze_line_id = l_tze_id AND
                tuesday_yn = 'Y';
   
      CURSOR cur_wednesday(l_tze_id IN NUMBER) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_coverage_times_v
          WHERE cov_tze_line_id = l_tze_id AND
                wednesday_yn = 'Y';
   
      CURSOR cur_thursday(l_tze_id IN NUMBER) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_coverage_times_v
          WHERE cov_tze_line_id = l_tze_id AND
                thursday_yn = 'Y';
   
      CURSOR cur_friday(l_tze_id IN NUMBER) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_coverage_times_v
          WHERE cov_tze_line_id = l_tze_id AND
                friday_yn = 'Y';
   
      CURSOR cur_saturday(l_tze_id IN NUMBER) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_coverage_times_v
          WHERE cov_tze_line_id = l_tze_id AND
                saturday_yn = 'Y';
   
      CURSOR cur_sunday(l_tze_id IN NUMBER) IS
         SELECT to_number(start_hour || decode(length(start_minute),
                                               1,
                                               '0' || start_minute,
                                               start_minute)) start_time,
                to_number(end_hour || decode(length(end_minute),
                                             1,
                                             '0' || end_minute,
                                             end_minute)) end_time
           FROM oks_coverage_times_v
          WHERE cov_tze_line_id = l_tze_id AND
                sunday_yn = 'Y';
   
      --Define cursors for other days.
      FUNCTION get_day_meaning(p_day_code IN VARCHAR2) RETURN VARCHAR2 IS
         CURSOR get_day IS
            SELECT meaning
              FROM fnd_lookups
             WHERE lookup_type = 'DAY_NAME' AND
                   lookup_code = p_day_code;
         l_day_meaning VARCHAR2(100);
      
      BEGIN
         OPEN get_day;
         FETCH get_day
            INTO l_day_meaning;
         CLOSE get_day;
         RETURN nvl(l_day_meaning, NULL);
      END get_day_meaning;
   
      PROCEDURE check_overlap(p_time_tbl   IN covertime_schedule_tbl_type,
                              p_overlap_yn OUT NOCOPY VARCHAR2) IS
      
         l_start     NUMBER;
         l_end       NUMBER;
         l_start_new NUMBER;
         l_end_new   NUMBER;
         j           NUMBER := 0;
         k           NUMBER := 0;
      
      BEGIN
         p_overlap_yn := 'N';
         FOR j IN 1 .. p_time_tbl.COUNT LOOP
            l_start := p_time_tbl(j).start_time;
            l_end   := p_time_tbl(j).end_time;
         
            FOR k IN 1 .. p_time_tbl.COUNT LOOP
               l_start_new := p_time_tbl(k).start_time;
               l_end_new   := p_time_tbl(k).end_time;
               IF j <> k THEN
                  IF (l_start_new <= l_end AND l_start_new >= l_start) OR
                     (l_end_new >= l_start AND l_end_new <= l_end) THEN
                  
                     IF (l_start_new = l_end) OR (l_end_new = l_start) THEN
                        IF p_overlap_yn <> 'Y' THEN
                           p_overlap_yn := 'N';
                        END IF;
                     ELSE
                        p_overlap_yn := 'Y';
                     END IF;
                  
                  END IF;
               END IF;
            END LOOP;
         
         END LOOP;
      
         --write the validation logic
      END check_overlap;
   
   BEGIN
   
      x_return_status := okc_api.g_ret_sts_success;
      l_time_tbl.DELETE;
      FOR monday_rec IN cur_monday(p_tze_line_id) LOOP
      
         i := i + 1;
         l_time_tbl(i).start_time := monday_rec.start_time;
         l_time_tbl(i).end_time := monday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
   
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.monday_overlap);
      
         IF x_days_overlap.monday_overlap = 'Y' THEN
            l_overlap_days := get_day_meaning('MON') || ',';
         END IF;
      
      END IF;
   
      -- Validating for Tuesday.
   
      l_time_tbl.DELETE;
      i := 0;
   
      FOR tuesday_rec IN cur_tuesday(p_tze_line_id) LOOP
         i := i + 1;
         l_time_tbl(i).start_time := tuesday_rec.start_time;
         l_time_tbl(i).end_time := tuesday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.tuesday_overlap);
         IF x_days_overlap.tuesday_overlap = 'Y' THEN
            l_overlap_days := l_overlap_days || get_day_meaning('TUE') || ',';
         END IF;
      
      END IF;
   
      -- Validating for wednesday.
   
      l_time_tbl.DELETE;
      i := 0;
   
      FOR wednesday_rec IN cur_wednesday(p_tze_line_id) LOOP
         i := i + 1;
         l_time_tbl(i).start_time := wednesday_rec.start_time;
         l_time_tbl(i).end_time := wednesday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.wednesday_overlap);
         IF x_days_overlap.wednesday_overlap = 'Y' THEN
            l_overlap_days := l_overlap_days || get_day_meaning('WED') || ',';
         END IF;
      
      END IF;
   
      -- Validating for thursday.
   
      l_time_tbl.DELETE;
      i := 0;
   
      FOR thursday_rec IN cur_thursday(p_tze_line_id) LOOP
         i := i + 1;
         l_time_tbl(i).start_time := thursday_rec.start_time;
         l_time_tbl(i).end_time := thursday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.thursday_overlap);
         IF x_days_overlap.thursday_overlap = 'Y' THEN
            l_overlap_days := l_overlap_days || get_day_meaning('THU') || ',';
         END IF;
      
      END IF;
   
      -- Validating for friday.
   
      l_time_tbl.DELETE;
      i := 0;
   
      FOR friday_rec IN cur_friday(p_tze_line_id) LOOP
         i := i + 1;
         l_time_tbl(i).start_time := friday_rec.start_time;
         l_time_tbl(i).end_time := friday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.friday_overlap);
         IF x_days_overlap.friday_overlap = 'Y' THEN
            l_overlap_days := l_overlap_days || get_day_meaning('FRI') || ',';
         END IF;
      
      END IF;
   
      -- Validating for saturday.
   
      l_time_tbl.DELETE;
      i := 0;
   
      FOR saturday_rec IN cur_saturday(p_tze_line_id) LOOP
         i := i + 1;
         l_time_tbl(i).start_time := saturday_rec.start_time;
         l_time_tbl(i).end_time := saturday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.saturday_overlap);
         IF x_days_overlap.saturday_overlap = 'Y' THEN
            l_overlap_days := l_overlap_days || get_day_meaning('SAT') || ',';
         END IF;
      
      END IF;
   
      -- Validating for sunday.
   
      l_time_tbl.DELETE;
      i := 0;
   
      FOR sunday_rec IN cur_sunday(p_tze_line_id) LOOP
         i := i + 1;
         l_time_tbl(i).start_time := sunday_rec.start_time;
         l_time_tbl(i).end_time := sunday_rec.end_time;
      END LOOP;
      l_overlap_yn := 'N';
      IF l_time_tbl.COUNT > 0 THEN
         check_overlap(p_time_tbl   => l_time_tbl,
                       p_overlap_yn => x_days_overlap.sunday_overlap);
         IF x_days_overlap.sunday_overlap = 'Y' THEN
            l_overlap_days := l_overlap_days || get_day_meaning('SUN') || ',';
         END IF;
      
      END IF;
   
      IF l_overlap_days IS NOT NULL THEN
         fnd_message.set_name('OKS', 'OKS_BILLRATE_DAYS_OVERLAP');
         fnd_message.set_token('DAYS', l_overlap_days);
      END IF;
   
      x_return_status := okc_api.g_ret_sts_success;
   
   EXCEPTION
   
      WHEN okc_api.g_exception_unexpected_error THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
      WHEN OTHERS THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
         ROLLBACK;
      
   END; -- Validate_covertime;

   --===========================================================================
   PROCEDURE migrate_primary_resources(p_api_version   IN NUMBER,
                                       p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                                       x_return_status OUT NOCOPY VARCHAR2,
                                       x_msg_count     OUT NOCOPY NUMBER,
                                       x_msg_data      OUT NOCOPY VARCHAR2) IS
   
   BEGIN
   
      -- Stubing out this procedure since no more in use.
      NULL;
   
   END migrate_primary_resources;

   PROCEDURE version_coverage(p_api_version   IN NUMBER,
                              p_init_msg_list IN VARCHAR2,
                              x_return_status OUT NOCOPY VARCHAR2,
                              x_msg_count     OUT NOCOPY NUMBER,
                              x_msg_data      OUT NOCOPY VARCHAR2,
                              p_chr_id        IN NUMBER,
                              p_major_version IN NUMBER) IS
   
      l_chr_id        CONSTANT NUMBER := p_chr_id;
      l_major_version CONSTANT NUMBER := p_major_version;
      l_return_status VARCHAR2(1);
   
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(1000);
      l_api_version   NUMBER := 1;
      l_init_msg_list VARCHAR2(1) := okc_api.g_false;
      g_exception_halt_validation EXCEPTION;
   
   BEGIN
   
      l_return_status := oks_act_pvt.create_version(p_id            => l_chr_id,
                                                    p_major_version => l_major_version);
   
      IF l_return_status <> 'S' THEN
         RAISE g_exception_halt_validation;
      END IF;
      l_return_status := oks_acm_pvt.create_version(p_id            => l_chr_id,
                                                    p_major_version => l_major_version);
   
      IF l_return_status <> 'S' THEN
         RAISE g_exception_halt_validation;
      END IF;
      l_return_status := oks_cvt_pvt.create_version(p_id            => l_chr_id,
                                                    p_major_version => l_major_version);
   
      IF l_return_status <> 'S' THEN
         RAISE g_exception_halt_validation;
      END IF;
      l_return_status := oks_ctz_pvt.create_version(p_id            => l_chr_id,
                                                    p_major_version => l_major_version);
      IF l_return_status <> 'S' THEN
         RAISE g_exception_halt_validation;
      END IF;
   
      l_return_status := oks_brs_pvt.create_version(p_id            => l_chr_id,
                                                    p_major_version => l_major_version);
   
      IF l_return_status <> 'S' THEN
         RAISE g_exception_halt_validation;
      END IF;
   
      oks_pm_programs_pvt.version_pm(p_api_version   => l_api_version,
                                     p_init_msg_list => l_init_msg_list,
                                     x_return_status => l_return_status,
                                     x_msg_count     => l_msg_count,
                                     x_msg_data      => l_msg_data,
                                     p_chr_id        => l_chr_id,
                                     p_major_version => l_major_version);
   
      IF l_return_status = 'S' THEN
         x_return_status := okc_api.g_ret_sts_success;
      ELSE
         RAISE g_exception_halt_validation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_error;
         x_msg_count     := l_msg_count;
      
      WHEN OTHERS THEN
      
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
      
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END version_coverage;

   PROCEDURE restore_coverage(p_api_version   IN NUMBER,
                              p_init_msg_list IN VARCHAR2,
                              x_return_status OUT NOCOPY VARCHAR2,
                              x_msg_count     OUT NOCOPY NUMBER,
                              x_msg_data      OUT NOCOPY VARCHAR2,
                              p_chr_id        IN NUMBER) IS
   
      l_chr_id        CONSTANT NUMBER := p_chr_id;
      l_major_version CONSTANT NUMBER := -1;
      l_return_status VARCHAR2(1);
   
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(1000);
      l_api_version   NUMBER := 1;
      l_init_msg_list VARCHAR2(1) := okc_api.g_false;
      g_exception_halt_validation EXCEPTION;
   
   BEGIN
   
      l_return_status := oks_act_pvt.restore_version(p_id            => l_chr_id,
                                                     p_major_version => l_major_version);
   
      IF l_return_status <> 'S' THEN
         RAISE g_exception_halt_validation;
      END IF;
   
      l_return_status := oks_acm_pvt.restore_version(p_id            => l_chr_id,
                                                     p_major_version => l_major_version);
   
      IF l_return_status <> 'S' THEN
         RAISE g_exception_halt_validation;
      END IF;
      l_return_status := oks_cvt_pvt.restore_version(p_id            => l_chr_id,
                                                     p_major_version => l_major_version);
   
      IF l_return_status <> 'S' THEN
         RAISE g_exception_halt_validation;
      END IF;
      l_return_status := oks_ctz_pvt.restore_version(p_id            => l_chr_id,
                                                     p_major_version => l_major_version);
   
      IF l_return_status <> 'S' THEN
         RAISE g_exception_halt_validation;
      END IF;
      l_return_status := oks_brs_pvt.restore_version(p_id            => l_chr_id,
                                                     p_major_version => l_major_version);
   
      IF l_return_status <> 'S' THEN
         RAISE g_exception_halt_validation;
      END IF;
   
      oks_pm_programs_pvt.restore_pm(p_api_version   => l_api_version,
                                     p_init_msg_list => l_init_msg_list,
                                     x_return_status => l_return_status,
                                     x_msg_count     => l_msg_count,
                                     x_msg_data      => l_msg_data,
                                     p_chr_id        => l_chr_id);
   
      IF l_return_status = 'S' THEN
         x_return_status := okc_api.g_ret_sts_success;
      ELSE
         RAISE g_exception_halt_validation;
      END IF;
   
   EXCEPTION
   
      WHEN g_exception_halt_validation THEN
      
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_error;
         x_msg_count     := l_msg_count;
      
      WHEN OTHERS THEN
      
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
      
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END restore_coverage;

   PROCEDURE delete_history(p_api_version   IN NUMBER,
                            p_init_msg_list IN VARCHAR2,
                            x_return_status OUT NOCOPY VARCHAR2,
                            x_msg_count     OUT NOCOPY NUMBER,
                            x_msg_data      OUT NOCOPY VARCHAR2,
                            p_chr_id        IN NUMBER) IS
   
      l_chr_id CONSTANT NUMBER := p_chr_id;
      l_return_status VARCHAR2(1);
   
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(1000);
      l_api_version   NUMBER := 1;
      l_init_msg_list VARCHAR2(1) := okc_api.g_false;
      g_exception_halt_validation EXCEPTION;
   
   BEGIN
   
      DELETE oks_action_time_types_h WHERE dnz_chr_id = l_chr_id;
   
      DELETE oks_action_times_h WHERE dnz_chr_id = l_chr_id;
   
      DELETE oks_coverage_times_h WHERE dnz_chr_id = l_chr_id;
   
      DELETE oks_coverage_timezones_h WHERE dnz_chr_id = l_chr_id;
   
      DELETE oks_billrate_schedules_h WHERE dnz_chr_id = l_chr_id;
   
      oks_pm_programs_pvt.delete_pmhistory(p_api_version   => l_api_version,
                                           p_init_msg_list => l_init_msg_list,
                                           x_return_status => l_return_status,
                                           x_msg_count     => l_msg_count,
                                           x_msg_data      => l_msg_data,
                                           p_chr_id        => l_chr_id);
   
      IF l_return_status = 'S' THEN
         x_return_status := okc_api.g_ret_sts_success;
      ELSE
         RAISE g_exception_halt_validation;
      END IF;
   
   EXCEPTION
   
      WHEN g_exception_halt_validation THEN
      
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
         x_msg_count     := l_msg_count;
      WHEN OTHERS THEN
      
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
      
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END delete_history;

   PROCEDURE delete_saved_version(p_api_version   IN NUMBER,
                                  p_init_msg_list IN VARCHAR2,
                                  x_return_status OUT NOCOPY VARCHAR2,
                                  x_msg_count     OUT NOCOPY NUMBER,
                                  x_msg_data      OUT NOCOPY VARCHAR2,
                                  p_chr_id        IN NUMBER) IS
   
      l_api_version   NUMBER := 1;
      l_init_msg_list VARCHAR2(1) DEFAULT okc_api.g_false;
      l_return_status VARCHAR2(1);
      --l_return_msg    VARCHAR2(2000);
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(2000);
      l_api_name      VARCHAR2(30) := 'Delete_Saved_Version';
      l_chr_id CONSTANT NUMBER := p_chr_id;
   
      g_exception_halt_validation EXCEPTION;
   BEGIN
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                p_init_msg_list,
                                                '_PUB',
                                                x_return_status);
   
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      ELSIF l_return_status IS NULL THEN
         RAISE okc_api.g_exception_unexpected_error;
      END IF;
   
      DELETE oks_action_time_types_h
       WHERE dnz_chr_id = l_chr_id AND
             major_version = -1;
   
      DELETE oks_action_times_h
       WHERE dnz_chr_id = l_chr_id AND
             major_version = -1;
   
      DELETE oks_coverage_times_h
       WHERE dnz_chr_id = l_chr_id AND
             major_version = -1;
   
      DELETE oks_coverage_timezones_h
       WHERE dnz_chr_id = l_chr_id AND
             major_version = -1;
   
      DELETE oks_billrate_schedules_h
       WHERE dnz_chr_id = l_chr_id AND
             major_version = -1;
   
      oks_pm_programs_pvt.delete_pmsaved_version(p_api_version   => l_api_version,
                                                 p_init_msg_list => l_init_msg_list,
                                                 x_return_status => l_return_status,
                                                 x_msg_count     => l_msg_count,
                                                 x_msg_data      => l_msg_data,
                                                 p_chr_id        => l_chr_id);
   
      IF l_return_status = 'S' THEN
         x_return_status := okc_api.g_ret_sts_success;
      ELSE
         RAISE g_exception_halt_validation;
      END IF;
   
   EXCEPTION
   
      WHEN g_exception_halt_validation THEN
      
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
         x_msg_count     := l_msg_count;
      
      WHEN okc_api.g_exception_error THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PUB');
      WHEN okc_api.g_exception_unexpected_error THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PUB');
      WHEN OTHERS THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         x_return_status := okc_api.g_ret_sts_unexp_error;
         ROLLBACK;
   END delete_saved_version;
   --===========================================================================

   PROCEDURE copy_k_hdr_notes(p_api_version   IN NUMBER,
                              p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                              p_chr_id        IN NUMBER,
                              x_return_status OUT NOCOPY VARCHAR2,
                              x_msg_count     OUT NOCOPY NUMBER,
                              x_msg_data      OUT NOCOPY VARCHAR2) IS
   
      --l_created_by        NUMBER := NULL;
      --l_last_updated_by   NUMBER := NULL;
      --l_last_update_login NUMBER := NULL;
      l_old_chr_id        NUMBER := 0;
   
      l_return_status         VARCHAR2(1);
      l_msg_count             NUMBER;
      l_msg_data              VARCHAR2(1000);
      l_jtf_note_id           NUMBER;
      l_jtf_note_contexts_tab jtf_notes_pub.jtf_note_contexts_tbl_type;
   
      CURSOR get_orig_system_id_cur(l_chr_id IN NUMBER) IS
         SELECT orig_system_id1,
                created_by,
                last_updated_by,
                last_update_login
           FROM okc_k_headers_b
          WHERE id = l_chr_id;
   
   BEGIN
   
      --For Get_Orig_System_Id_Rec IN Get_Orig_System_Id_Cur(P_source_object_id) LOOP
      FOR get_orig_system_id_rec IN get_orig_system_id_cur(p_chr_id) LOOP
         l_old_chr_id := get_orig_system_id_rec.orig_system_id1;
         /* Modified by Jvorugan for Bug:4489214 who columns not to be populated from old contract
         l_created_by := Get_Orig_System_Id_Rec.created_by;
              l_last_updated_by := Get_Orig_System_Id_Rec.last_updated_by;
              l_last_update_login := Get_Orig_System_Id_Rec.last_update_login;  */
      END LOOP;
   
      get_notes_details(p_source_object_id   => l_old_chr_id,
                        x_notes_tbl          => l_notes_tbl,
                        x_return_status      => l_return_status,
                        p_source_object_code => 'OKS_HDR_NOTE'); -- Bug:5944200
   
      IF l_return_status = 'S' THEN
      
         IF (l_notes_tbl.COUNT > 0) THEN
            FOR i IN l_notes_tbl.FIRST .. l_notes_tbl.LAST LOOP
            
               jtf_notes_pub.create_note(p_jtf_note_id           => NULL --:JTF_NOTES.JTF_NOTE_ID
                                        ,
                                         p_api_version           => 1.0,
                                         p_init_msg_list         => 'F',
                                         p_commit                => 'F',
                                         p_validation_level      => 0,
                                         x_return_status         => l_return_status,
                                         x_msg_count             => l_msg_count,
                                         x_msg_data              => l_msg_data,
                                         p_source_object_code    => l_notes_tbl(i)
                                                                   .source_object_code,
                                         p_source_object_id      => p_chr_id,
                                         p_notes                 => l_notes_tbl(i)
                                                                   .notes,
                                         p_notes_detail          => l_notes_tbl(i)
                                                                   .notes_detail,
                                         p_note_status           => l_notes_tbl(i)
                                                                   .note_status,
                                         p_note_type             => l_notes_tbl(i)
                                                                   .note_type,
                                         p_entered_by            => l_notes_tbl(i)
                                                                   .entered_by -- -1 Modified for Bug:4489214
                                        ,
                                         p_entered_date          => l_notes_tbl(i)
                                                                   .entered_date -- SYSDATE Modified for Bug:4489214
                                        ,
                                         x_jtf_note_id           => l_jtf_note_id,
                                         p_creation_date         => SYSDATE,
                                         p_created_by            => fnd_global.user_id --  created_by Modified for Bug:4489214
                                        ,
                                         p_last_update_date      => SYSDATE,
                                         p_last_updated_by       => fnd_global.user_id -- l_last_updated_by Modified for Bug:4489214
                                        ,
                                         p_last_update_login     => fnd_global.login_id -- l_last_update_login Modified for Bug:4489214
                                        ,
                                         p_attribute1            => NULL,
                                         p_attribute2            => NULL,
                                         p_attribute3            => NULL,
                                         p_attribute4            => NULL,
                                         p_attribute5            => NULL,
                                         p_attribute6            => NULL,
                                         p_attribute7            => NULL,
                                         p_attribute8            => NULL,
                                         p_attribute9            => NULL,
                                         p_attribute10           => NULL,
                                         p_attribute11           => NULL,
                                         p_attribute12           => NULL,
                                         p_attribute13           => NULL,
                                         p_attribute14           => NULL,
                                         p_attribute15           => NULL,
                                         p_context               => NULL,
                                         p_jtf_note_contexts_tab => l_jtf_note_contexts_tab);
            
            END LOOP;
         END IF;
      
      END IF;
   
      x_return_status := okc_api.g_ret_sts_success;
   
   EXCEPTION
   
      WHEN OTHERS THEN
      
         okc_api.set_message(g_app_name,
                             g_unexpected_error,
                             g_sqlcode_token,
                             SQLCODE,
                             g_sqlerrm_token,
                             SQLERRM);
      
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END copy_k_hdr_notes;

   PROCEDURE update_dnz_chr_id(p_coverage_id IN NUMBER,
                               p_dnz_chr_id  IN NUMBER) IS
   
      -- coverage --
      l_clev_tbl_in  okc_contract_pub.clev_tbl_type;
      l_clev_tbl_out okc_contract_pub.clev_tbl_type;
      -- End --
      -- OKC_K_ITEMS
      l_cimv_tbl_in  okc_contract_item_pub.cimv_tbl_type;
      l_cimv_tbl_out okc_contract_item_pub.cimv_tbl_type;
      --
      -- OKS_K_LINES_B
      l_klnv_tbl_in  oks_contract_line_pub.klnv_tbl_type;
      l_klnv_tbl_out oks_contract_line_pub.klnv_tbl_type;
   
      l_timezone_tbl_in  oks_ctz_pvt.okscoveragetimezonesvtbltype;
      l_timezone_tbl_out oks_ctz_pvt.okscoveragetimezonesvtbltype;
   
      l_cov_time_tbl_in  oks_cvt_pvt.oks_coverage_times_v_tbl_type;
      l_cov_time_tbl_out oks_cvt_pvt.oks_coverage_times_v_tbl_type;
      --  END
   
      -- Reaction Time --
      l_act_type_tbl_in  oks_act_pvt.oksactiontimetypesvtbltype;
      l_act_type_tbl_out oks_act_pvt.oksactiontimetypesvtbltype;
   
      l_act_time_tbl_in  oks_acm_pvt.oks_action_times_v_tbl_type;
      l_act_time_tbl_out oks_acm_pvt.oks_action_times_v_tbl_type;
   
      -- End Reaction Time  --
   
      -- Preffered Resource  --
      l_cplv_tbl_in  okc_contract_party_pub.cplv_tbl_type;
      l_cplv_tbl_out okc_contract_party_pub.cplv_tbl_type;
      --
      l_ctcv_tbl_in  okc_contract_party_pub.ctcv_tbl_type;
      l_ctcv_tbl_out okc_contract_party_pub.ctcv_tbl_type;
      -- end Resource --
   
      -- Bill Rate  --
      l_bill_rate_tbl_in  oks_brs_pvt.oksbillrateschedulesvtbltype;
      l_bill_rate_tbl_out oks_brs_pvt.oksbillrateschedulesvtbltype;
   
      -- End Bill Rate --
   
      -- Preventive Maintainance --
      -- OKs_Pm_stream_levels
      l_pmlv_tbl_in  oks_pml_pvt.pmlv_tbl_type;
      l_pmlv_tbl_out oks_pml_pvt.pmlv_tbl_type;
      -- Oks_pm_stream_levels
      -- OKs_Pm_schedules
      l_pms_tbl_in  oks_pms_pvt.oks_pm_schedules_v_tbl_type;
      l_pms_tbl_out oks_pms_pvt.oks_pm_schedules_v_tbl_type;
      -- Oks_Pm_schedules
      -- OKS_PM_ACTIVITIES --
      l_pmav_tbl_in  oks_pma_pvt.pmav_tbl_type;
      l_pmav_tbl_out oks_pma_pvt.pmav_tbl_type;
      -- OKS_PM_ACTIVITIES --
      -- End Preventive Maintainance --
   
      CURSOR cur_react_time(p_id NUMBER) IS
         SELECT id, dnz_chr_id
           FROM okc_k_lines_b
          WHERE cle_id = p_id AND
                lse_id IN (4, 17);
   
      CURSOR cur_act_times(p_id NUMBER) IS
         SELECT id, dnz_chr_id, object_version_number
           FROM oks_action_times
          WHERE cov_action_type_id = p_id;
   
      CURSOR cur_act_time_type(p_id NUMBER) IS
         SELECT id, dnz_chr_id, object_version_number
           FROM oks_action_time_types
          WHERE cle_id = p_id AND
                action_type_code IN ('RCN', 'RSN');
   
      CURSOR cur_oks_id(p_id NUMBER) IS
         SELECT id, dnz_chr_id, cle_id, sfwt_flag, object_version_number
           FROM oks_k_lines_v
          WHERE cle_id = p_id;
   
      -- Time Zone  --
      CURSOR csr_tz_id(l_cle_id NUMBER) IS
         SELECT id, dnz_chr_id, object_version_number
           FROM oks_coverage_timezones
          WHERE cle_id = l_cle_id;
      CURSOR csr_times_id(l_cle_id NUMBER) IS
         SELECT id, dnz_chr_id, object_version_number
           FROM oks_coverage_times
          WHERE cov_tze_line_id = l_cle_id;
   
      -- End Time Zone --
   
      -- Business Process --
   
      CURSOR csr_bp_id(l_cle_id NUMBER) IS
         SELECT id, dnz_chr_id
           FROM okc_k_lines_b
          WHERE cle_id = l_cle_id AND
                lse_id IN (3, 16);
   
      -- End Business Process--
   
      CURSOR cur_party(p_id NUMBER) IS
         SELECT id,
                dnz_chr_id,
                chr_id,
                cpl_id,
                primary_yn,
                small_business_flag,
                women_owned_flag,
                cle_id,
                jtot_object1_code,
                object1_id1,
                rle_code
           FROM okc_k_party_roles_v
          WHERE cle_id = p_id AND
                dnz_chr_id = p_dnz_chr_id;
   
      CURSOR cur_contact(p_id NUMBER) IS
         SELECT id,
                dnz_chr_id,
                cro_code,
                cpl_id,
                primary_yn,
                resource_class
           FROM okc_contacts
          WHERE cpl_id = p_id;
   
      -- Billing Type  --
      CURSOR cur_bill_type(p_id NUMBER) IS
         SELECT id, dnz_chr_id
           FROM okc_k_lines_b
          WHERE cle_id = p_id AND
                lse_id IN (5, 59, 23);
   
      CURSOR cur_item(p_id NUMBER) IS
         SELECT id,
                dnz_chr_id,
                jtot_object1_code,
                object1_id1,
                cle_id,
                chr_id,
                cle_id_for,
                exception_yn,
                priced_item_yn,
                uom_code
           FROM okc_k_items
          WHERE cle_id = p_id;
   
      -- End Billing Type --
   
      -- Bill Rate  --
      CURSOR cur_bill_sch(p_id NUMBER) IS
         SELECT id, dnz_chr_id, object_version_number
           FROM oks_billrate_schedules
          WHERE cle_id = p_id;
   
      CURSOR cur_bill_rate(p_id NUMBER) IS
         SELECT id, dnz_chr_id
           FROM okc_k_lines_b
          WHERE cle_id = p_id AND
                lse_id IN (6, 60, 24);
      -- End Bill Rate --
      -- Coverage_id --
      CURSOR cur_coverage(p_id NUMBER) IS
         SELECT dnz_chr_id FROM okc_k_lines_b WHERE id = p_id;
      -- End Coverage id --
   
      --  Variable Used --
      l_coverage_id NUMBER;
      l_dnz_chr_id  NUMBER := -1;
      --l_oks_line_id NUMBER;
      l_cle_id      NUMBER;
      l_api_version   CONSTANT NUMBER := 1.0;
      l_init_msg_list CONSTANT VARCHAR2(1) := okc_api.g_true;
      l_return_status VARCHAR2(1) := 'S';
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(240);
      l_validate_yn   VARCHAR2(1) := 'N';
      cnt             NUMBER;
      cnt1            NUMBER;
   
      -- End --
      -- Preventive Maintainance --
      CURSOR cur_pm_act(p_id NUMBER) IS
         SELECT id, dnz_chr_id, object_version_number
           FROM oks_pm_activities
          WHERE cle_id = p_id;
   
      CURSOR cur_pm_sch(p_id NUMBER) IS
         SELECT id, dnz_chr_id, object_version_number
           FROM oks_pm_schedules
          WHERE cle_id = p_id;
   
      CURSOR cur_pm_stream(p_id NUMBER) IS
         SELECT id, dnz_chr_id, object_version_number
           FROM oks_pm_stream_levels
          WHERE cle_id = p_id;
      -- Preventive Maintanance --
   
   BEGIN
   
      -- Check the Status of Warranty_YN Check Box
      -- If checked then set dnz_chr_id = -2
      -- else set dnz_chr_id = -1
   
      l_coverage_id := p_coverage_id;
      l_dnz_chr_id  := p_dnz_chr_id;
      cnt           := 0;
      cnt1          := 0;
      OPEN cur_coverage(p_coverage_id);
      FETCH cur_coverage
         INTO l_dnz_chr_id;
      CLOSE cur_coverage;
   
      IF l_dnz_chr_id <> p_dnz_chr_id THEN
         -- Coverage --
         l_clev_tbl_in(1).id := l_coverage_id;
         l_clev_tbl_in(1).dnz_chr_id := p_dnz_chr_id;
      
         okc_contract_pub.update_contract_line(p_api_version       => l_api_version,
                                               p_init_msg_list     => l_init_msg_list,
                                               x_return_status     => l_return_status,
                                               x_msg_count         => l_msg_count,
                                               x_msg_data          => l_msg_data,
                                               p_restricted_update => 'F',
                                               p_clev_tbl          => l_clev_tbl_in,
                                               x_clev_tbl          => l_clev_tbl_out);
      
      END IF;
   
      FOR rec_line IN cur_oks_id(l_coverage_id) LOOP
         IF rec_line.dnz_chr_id <> p_dnz_chr_id THEN
         
            l_klnv_tbl_in(cnt).id := rec_line.id;
            l_klnv_tbl_in(cnt).dnz_chr_id := p_dnz_chr_id;
            l_klnv_tbl_in(cnt).cle_id := rec_line.cle_id;
            l_klnv_tbl_in(cnt).sfwt_flag := rec_line.sfwt_flag;
            l_klnv_tbl_in(cnt).object_version_number := rec_line.object_version_number;
         
            cnt := cnt + 1;
         END IF;
      END LOOP;
      IF cnt > 0 THEN
      
         oks_contract_line_pub.update_line(p_api_version   => l_api_version,
                                           p_init_msg_list => l_init_msg_list,
                                           x_return_status => l_return_status,
                                           x_msg_count     => l_msg_count,
                                           x_msg_data      => l_msg_data,
                                           p_klnv_tbl      => l_klnv_tbl_in,
                                           x_klnv_tbl      => l_klnv_tbl_out,
                                           p_validate_yn   => l_validate_yn);
      END IF;
      -- coverage End --
   
      cnt := 0;
   
      -- Preventive Maintainance  --
      FOR rec_pma IN cur_pm_act(l_coverage_id) LOOP
         IF rec_pma.dnz_chr_id <> p_dnz_chr_id THEN
            l_pmav_tbl_in(cnt).id := rec_pma.id;
            l_pmav_tbl_in(cnt).dnz_chr_id := p_dnz_chr_id;
            l_pmav_tbl_in(cnt).object_version_number := rec_pma.object_version_number;
            cnt := cnt + 1;
         END IF;
      END LOOP;
      IF cnt > 0 THEN
         -- OKS_PM_ACTIVITIES
         oks_pma_pvt.update_row(p_api_version   => l_api_version,
                                p_init_msg_list => l_init_msg_list,
                                x_return_status => l_return_status,
                                x_msg_count     => l_msg_count,
                                x_msg_data      => l_msg_data,
                                p_pmav_tbl      => l_pmav_tbl_in,
                                x_pmav_tbl      => l_pmav_tbl_out);
      END IF;
   
      cnt := 0;
      FOR rec_sch IN cur_pm_sch(l_coverage_id) LOOP
         IF rec_sch.dnz_chr_id <> p_dnz_chr_id THEN
            l_pms_tbl_in(cnt).id := rec_sch.id;
            l_pms_tbl_in(cnt).dnz_chr_id := p_dnz_chr_id;
            l_pms_tbl_in(cnt).object_version_number := rec_sch.object_version_number;
            cnt := cnt + 1;
         END IF;
      END LOOP;
      IF cnt > 0 THEN
         -- OKS_PM_SCHEDULES --
         oks_pms_pvt.update_row(p_api_version            => l_api_version,
                                p_init_msg_list          => l_init_msg_list,
                                x_return_status          => l_return_status,
                                x_msg_count              => l_msg_count,
                                x_msg_data               => l_msg_data,
                                p_oks_pm_schedules_v_tbl => l_pms_tbl_in,
                                x_oks_pm_schedules_v_tbl => l_pms_tbl_out);
      END IF;
   
      cnt := 0;
      FOR rec_stream IN cur_pm_stream(l_coverage_id) LOOP
         IF rec_stream.dnz_chr_id <> p_dnz_chr_id THEN
            l_pmlv_tbl_in(cnt).id := rec_stream.id;
            l_pmlv_tbl_in(cnt).dnz_chr_id := p_dnz_chr_id;
            l_pmlv_tbl_in(cnt).object_version_number := rec_stream.object_version_number;
            cnt := cnt + 1;
         END IF;
      END LOOP;
      IF cnt > 0 THEN
         -- OKS_PM_STRAM_LEVELS
         oks_pml_pvt.update_row(p_api_version   => l_api_version,
                                p_init_msg_list => l_init_msg_list,
                                x_return_status => l_return_status,
                                x_msg_count     => l_msg_count,
                                x_msg_data      => l_msg_data,
                                p_pmlv_tbl      => l_pmlv_tbl_in,
                                x_pmlv_tbl      => l_pmlv_tbl_out);
      END IF;
   
      -- End Preventive Maintainance --
   
      cnt := 0;
      -- Business Process  --
      --oksaucvt_tool_box.init_contract_line (l_clev_tbl_in);
      FOR rec_bp IN csr_bp_id(l_coverage_id) LOOP
      
         IF rec_bp.dnz_chr_id <> p_dnz_chr_id THEN
         
            l_clev_tbl_in(cnt).id := rec_bp.id;
            l_clev_tbl_in(cnt).dnz_chr_id := p_dnz_chr_id;
            cnt := cnt + 1;
         END IF;
         -- Contract Item
      
         --oksaucvt_tool_box.init_contract_item (l_cimv_tbl_in);
      
         FOR rec_item IN cur_item(rec_bp.id) LOOP
            IF rec_item.dnz_chr_id <> p_dnz_chr_id THEN
               l_cimv_tbl_in(cnt1).id := rec_item.id;
               l_cimv_tbl_in(cnt1).cle_id := rec_item.cle_id;
               l_cimv_tbl_in(cnt1).dnz_chr_id := p_dnz_chr_id;
               l_cimv_tbl_in(cnt1).jtot_object1_code := rec_item.jtot_object1_code;
               l_cimv_tbl_in(cnt1).cle_id_for := rec_item.cle_id_for;
               l_cimv_tbl_in(cnt1).priced_item_yn := rec_item.priced_item_yn;
               l_cimv_tbl_in(cnt1).chr_id := rec_item.chr_id;
               l_cimv_tbl_in(cnt1).exception_yn := rec_item.exception_yn;
               l_cimv_tbl_in(cnt1).object1_id1 := rec_item.object1_id1;
            
               cnt1 := cnt1 + 1;
            END IF;
         END LOOP;
         IF cnt1 > 0 THEN
            okc_contract_item_pub.update_contract_item(p_api_version   => l_api_version,
                                                       p_init_msg_list => l_init_msg_list,
                                                       x_return_status => l_return_status,
                                                       x_msg_count     => l_msg_count,
                                                       x_msg_data      => l_msg_data,
                                                       p_cimv_tbl      => l_cimv_tbl_in,
                                                       x_cimv_tbl      => l_cimv_tbl_out);
         END IF;
         -- End Contract Item
         -- OKS_K_LINES_B
         cnt1 := 0;
         FOR rec_line IN cur_oks_id(rec_bp.id) LOOP
         
            IF rec_line.dnz_chr_id <> p_dnz_chr_id THEN
               l_klnv_tbl_in(cnt1).id := rec_line.id;
               l_klnv_tbl_in(cnt1).dnz_chr_id := p_dnz_chr_id;
               l_klnv_tbl_in(cnt1).cle_id := rec_line.cle_id;
               l_klnv_tbl_in(cnt1).sfwt_flag := rec_line.sfwt_flag;
               l_klnv_tbl_in(cnt1).object_version_number := rec_line.object_version_number;
               cnt1 := cnt1 + 1;
            END IF;
         
         END LOOP;
         IF cnt1 > 0 THEN
            oks_contract_line_pub.update_line(p_api_version   => l_api_version,
                                              p_init_msg_list => l_init_msg_list,
                                              x_return_status => l_return_status,
                                              x_msg_count     => l_msg_count,
                                              x_msg_data      => l_msg_data,
                                              p_klnv_tbl      => l_klnv_tbl_in,
                                              x_klnv_tbl      => l_klnv_tbl_out,
                                              p_validate_yn   => l_validate_yn);
         END IF;
         -- End OKS_K_LINES_B --
         cnt1 := 0;
      
      END LOOP; -- end Loop BP
   
      IF cnt > 0 THEN
         okc_contract_pub.update_contract_line(p_api_version       => l_api_version,
                                               p_init_msg_list     => l_init_msg_list,
                                               x_return_status     => l_return_status,
                                               x_msg_count         => l_msg_count,
                                               x_msg_data          => l_msg_data,
                                               p_restricted_update => 'F',
                                               p_clev_tbl          => l_clev_tbl_in,
                                               x_clev_tbl          => l_clev_tbl_out);
      END IF;
   
      -- End Business process--
      cnt := 0;
   
      -- Reaction Time  --
      FOR rec_bp IN csr_bp_id(l_coverage_id) LOOP
         FOR rec_react IN cur_react_time(rec_bp.id) LOOP
         
            IF rec_react.dnz_chr_id <> p_dnz_chr_id THEN
               l_clev_tbl_in(cnt).dnz_chr_id := p_dnz_chr_id;
               l_clev_tbl_in(cnt).id := rec_react.id;
               cnt := cnt + 1;
            END IF;
            -- Fetch OKS_K_LINES id
            cnt1 := 0;
            FOR rec_line IN cur_oks_id(rec_react.id) LOOP
            
               IF rec_line.dnz_chr_id <> p_dnz_chr_id THEN
                  l_klnv_tbl_in(cnt1).id := rec_line.id;
                  l_klnv_tbl_in(cnt1).dnz_chr_id := p_dnz_chr_id;
                  l_klnv_tbl_in(cnt1).cle_id := rec_line.cle_id;
                  l_klnv_tbl_in(cnt1).sfwt_flag := rec_line.sfwt_flag;
                  l_klnv_tbl_in(cnt1).object_version_number := rec_line.object_version_number;
                  cnt1 := cnt1 + 1;
               END IF;
            END LOOP;
            IF cnt1 > 0 THEN
               oks_contract_line_pub.update_line(p_api_version   => l_api_version,
                                                 p_init_msg_list => l_init_msg_list,
                                                 x_return_status => l_return_status,
                                                 x_msg_count     => l_msg_count,
                                                 x_msg_data      => l_msg_data,
                                                 p_klnv_tbl      => l_klnv_tbl_in,
                                                 x_klnv_tbl      => l_klnv_tbl_out,
                                                 p_validate_yn   => l_validate_yn);
            END IF;
            -- update the oks_action_types line
            cnt1 := 0;
            FOR rec_type IN cur_act_time_type(rec_react.id) LOOP
            
               IF rec_type.dnz_chr_id <> p_dnz_chr_id THEN
                  l_act_type_tbl_in(cnt1).dnz_chr_id := p_dnz_chr_id;
                  l_act_type_tbl_in(cnt1).id := rec_type.id;
                  l_act_type_tbl_in(cnt1).object_version_number := rec_type.object_version_number;
                  cnt1 := cnt1 + 1;
               
               END IF;
            END LOOP;
            IF cnt1 > 0 THEN
               oks_act_pvt.update_row(p_api_version                 => l_api_version,
                                      p_init_msg_list               => l_init_msg_list,
                                      x_return_status               => l_return_status,
                                      x_msg_count                   => l_msg_count,
                                      x_msg_data                    => l_msg_data,
                                      p_oks_action_time_types_v_tbl => l_act_type_tbl_in,
                                      x_oks_action_time_types_v_tbl => l_act_type_tbl_out);
            END IF;
         
            cnt1 := 0;
            -- End Update oks_action_types line
            -- Update the oks_action_times_line
            FOR rec_type IN cur_act_time_type(rec_react.id) LOOP
               FOR rec_time IN cur_act_times(rec_type.id) LOOP
               
                  IF rec_time.dnz_chr_id <> p_dnz_chr_id THEN
                  
                     l_act_time_tbl_in(cnt1).dnz_chr_id := p_dnz_chr_id;
                     l_act_time_tbl_in(cnt1).id := rec_time.id;
                     l_act_time_tbl_in(cnt1).object_version_number := rec_time.object_version_number;
                     cnt1 := cnt1 + 1;
                  
                  END IF;
               END LOOP;
            END LOOP;
            IF cnt1 > 0 THEN
               oks_acm_pvt.update_row(p_api_version            => l_api_version,
                                      p_init_msg_list          => l_init_msg_list,
                                      x_return_status          => l_return_status,
                                      x_msg_count              => l_msg_count,
                                      x_msg_data               => l_msg_data,
                                      p_oks_action_times_v_tbl => l_act_time_tbl_in,
                                      x_oks_action_times_v_tbl => l_act_time_tbl_out);
            END IF;
            -- End oks_action_times_line
            cnt1 := 0;
         END LOOP; -- Reaction Time
      END LOOP; -- BP
      IF cnt > 0 THEN
         okc_contract_pub.update_contract_line(p_api_version       => l_api_version,
                                               p_init_msg_list     => l_init_msg_list,
                                               x_return_status     => l_return_status,
                                               x_msg_count         => l_msg_count,
                                               x_msg_data          => l_msg_data,
                                               p_restricted_update => 'F',
                                               p_clev_tbl          => l_clev_tbl_in,
                                               x_clev_tbl          => l_clev_tbl_out);
      END IF;
      -- End Reaction Time --
   
      cnt := 0;
   
      -- Resource --
      FOR rec_bp IN csr_bp_id(p_coverage_id) LOOP
         FOR rec_part IN cur_party(rec_bp.id) LOOP
            IF rec_part.dnz_chr_id <> p_dnz_chr_id THEN
               l_cplv_tbl_in(cnt).dnz_chr_id := p_dnz_chr_id;
               l_cplv_tbl_in(cnt).id := rec_part.id;
               l_cplv_tbl_in(cnt).chr_id := rec_part.chr_id;
               l_cplv_tbl_in(cnt).cle_id := rec_part.cle_id;
               l_cplv_tbl_in(cnt).cpl_id := rec_part.cpl_id;
               l_cplv_tbl_in(cnt).small_business_flag := rec_part.small_business_flag;
               l_cplv_tbl_in(cnt).women_owned_flag := rec_part.women_owned_flag;
               l_cplv_tbl_in(cnt).primary_yn := rec_part.primary_yn;
               l_cplv_tbl_in(cnt).jtot_object1_code := rec_part.jtot_object1_code;
               l_cplv_tbl_in(cnt).object1_id1 := rec_part.object1_id1;
               l_cplv_tbl_in(cnt).rle_code := rec_part.rle_code;
            
               cnt := cnt + 1;
            END IF;
            -- OKC_CONTACTS --
            cnt1 := 0;
            FOR rec_con IN cur_contact(rec_part.id) LOOP
               IF rec_con.dnz_chr_id <> p_dnz_chr_id THEN
                  l_ctcv_tbl_in(cnt1).id := rec_con.id;
                  l_ctcv_tbl_in(cnt1).dnz_chr_id := p_dnz_chr_id;
                  l_ctcv_tbl_in(cnt1).cro_code := rec_con.cro_code;
                  l_ctcv_tbl_in(cnt1).cpl_id := rec_con.cpl_id;
                  l_ctcv_tbl_in(cnt1).primary_yn := rec_con.primary_yn;
                  l_ctcv_tbl_in(cnt1).resource_class := rec_con.resource_class;
                  cnt1 := cnt1 + 1;
               END IF;
            END LOOP;
            IF cnt1 > 0 THEN
               okc_contract_party_pub.update_contact(p_api_version   => l_api_version,
                                                     p_init_msg_list => l_init_msg_list,
                                                     x_return_status => l_return_status,
                                                     x_msg_count     => l_msg_count,
                                                     x_msg_data      => l_msg_data,
                                                     p_ctcv_tbl      => l_ctcv_tbl_in,
                                                     x_ctcv_tbl      => l_ctcv_tbl_out);
            END IF;
            -- OKC_CONTACTS --
         END LOOP; -- End Party Roles
      END LOOP; -- End Bp
      IF cnt > 0 THEN
         okc_contract_party_pub.update_k_party_role(p_api_version   => l_api_version,
                                                    p_init_msg_list => l_init_msg_list,
                                                    x_return_status => l_return_status,
                                                    x_msg_count     => l_msg_count,
                                                    x_msg_data      => l_msg_data,
                                                    p_cplv_tbl      => l_cplv_tbl_in,
                                                    x_cplv_tbl      => l_cplv_tbl_out);
      END IF;
   
      -- End Prefered Resource --
      cnt := 0;
   
      -- Billing Type --
      FOR rec_bp IN csr_bp_id(l_coverage_id) LOOP
         FOR rec_bill IN cur_bill_type(rec_bp.id) LOOP
            -- Contract Line for Billing Type
            IF rec_bill.dnz_chr_id <> p_dnz_chr_id THEN
               l_clev_tbl_in(cnt).dnz_chr_id := p_dnz_chr_id;
               l_clev_tbl_in(cnt).id := rec_bill.id;
               cnt := cnt + 1;
            END IF;
            cnt1 := 0;
         
            FOR rec_item IN cur_item(rec_bill.id) LOOP
               -- Contract Item
               IF rec_item.dnz_chr_id <> p_dnz_chr_id THEN
                  l_cimv_tbl_in(cnt1).id := rec_item.id;
                  l_cimv_tbl_in(cnt1).cle_id := rec_item.cle_id;
                  l_cimv_tbl_in(cnt1).dnz_chr_id := p_dnz_chr_id;
                  l_cimv_tbl_in(cnt1).jtot_object1_code := rec_item.jtot_object1_code;
                  l_cimv_tbl_in(cnt1).cle_id_for := rec_item.cle_id_for;
                  l_cimv_tbl_in(cnt1).priced_item_yn := rec_item.priced_item_yn;
                  l_cimv_tbl_in(cnt1).chr_id := rec_item.chr_id;
                  l_cimv_tbl_in(cnt1).exception_yn := rec_item.exception_yn;
                  l_cimv_tbl_in(cnt1).object1_id1 := rec_item.object1_id1;
                  cnt1 := cnt1 + 1;
               END IF;
            END LOOP;
            IF cnt1 > 0 THEN
               okc_contract_item_pub.update_contract_item(p_api_version   => l_api_version,
                                                          p_init_msg_list => l_init_msg_list,
                                                          x_return_status => l_return_status,
                                                          x_msg_count     => l_msg_count,
                                                          x_msg_data      => l_msg_data,
                                                          p_cimv_tbl      => l_cimv_tbl_in,
                                                          x_cimv_tbl      => l_cimv_tbl_out);
               -- End OKC_K_ITEMS
            END IF;
            cnt1 := 0;
            FOR rec_oks_line IN cur_oks_id(rec_bill.id) LOOP
            
               IF rec_oks_line.dnz_chr_id <> p_dnz_chr_id THEN
                  l_klnv_tbl_in(cnt1).id := rec_oks_line.id;
                  l_klnv_tbl_in(cnt1).dnz_chr_id := p_dnz_chr_id;
                  l_klnv_tbl_in(cnt1).cle_id := rec_oks_line.cle_id;
                  l_klnv_tbl_in(cnt1).sfwt_flag := rec_oks_line.sfwt_flag;
                  l_klnv_tbl_in(cnt1).object_version_number := rec_oks_line.object_version_number;
                  cnt1 := cnt1 + 1;
               END IF;
            END LOOP;
            IF cnt1 > 0 THEN
               oks_contract_line_pub.update_line(p_api_version   => l_api_version,
                                                 p_init_msg_list => l_init_msg_list,
                                                 x_return_status => l_return_status,
                                                 x_msg_count     => l_msg_count,
                                                 x_msg_data      => l_msg_data,
                                                 p_klnv_tbl      => l_klnv_tbl_in,
                                                 x_klnv_tbl      => l_klnv_tbl_out,
                                                 p_validate_yn   => l_validate_yn);
            END IF;
         END LOOP;
      END LOOP; -- BP --
      IF cnt > 0 THEN
         okc_contract_pub.update_contract_line(p_api_version       => l_api_version,
                                               p_init_msg_list     => l_init_msg_list,
                                               x_return_status     => l_return_status,
                                               x_msg_count         => l_msg_count,
                                               x_msg_data          => l_msg_data,
                                               p_restricted_update => 'F',
                                               p_clev_tbl          => l_clev_tbl_in,
                                               x_clev_tbl          => l_clev_tbl_out);
      END IF;
      -- BILLING Tpye ---
   
      cnt := 0;
   
      -- Billing Rate --
      FOR rec_bp IN csr_bp_id(l_coverage_id) LOOP
         FOR rec_bill IN cur_bill_type(rec_bp.id) LOOP
            FOR rec_billrate IN cur_bill_rate(rec_bill.id) LOOP
            
               IF rec_billrate.dnz_chr_id <> p_dnz_chr_id THEN
                  l_clev_tbl_in(cnt).id := rec_billrate.id;
                  l_clev_tbl_in(cnt).dnz_chr_id := p_dnz_chr_id;
                  cnt := cnt + 1;
               END IF;
               cnt1 := 0;
               FOR rec_oks_line IN cur_oks_id(rec_bill.id) LOOP
                  IF rec_oks_line.dnz_chr_id <> p_dnz_chr_id THEN
                     l_klnv_tbl_in(cnt1).id := rec_oks_line.id;
                     l_klnv_tbl_in(cnt1).dnz_chr_id := p_dnz_chr_id;
                     l_klnv_tbl_in(cnt1).cle_id := rec_oks_line.cle_id;
                     l_klnv_tbl_in(cnt1).sfwt_flag := rec_oks_line.sfwt_flag;
                     l_klnv_tbl_in(cnt1).object_version_number := rec_oks_line.object_version_number;
                     cnt1 := cnt1 + 1;
                  END IF;
               END LOOP; -- End OKS_LINES
               IF cnt1 > 0 THEN
                  oks_contract_line_pub.update_line(p_api_version   => l_api_version,
                                                    p_init_msg_list => l_init_msg_list,
                                                    x_return_status => l_return_status,
                                                    x_msg_count     => l_msg_count,
                                                    x_msg_data      => l_msg_data,
                                                    p_klnv_tbl      => l_klnv_tbl_in,
                                                    x_klnv_tbl      => l_klnv_tbl_out,
                                                    p_validate_yn   => l_validate_yn);
               END IF;
               cnt1 := 0;
            
               FOR rec_billsch IN cur_bill_sch(rec_billrate.id) LOOP
               
                  IF rec_billsch.dnz_chr_id <> p_dnz_chr_id THEN
                     l_bill_rate_tbl_in(cnt1).id := rec_billsch.id;
                     l_bill_rate_tbl_in(cnt1).dnz_chr_id := p_dnz_chr_id;
                     l_bill_rate_tbl_in(cnt1).object_version_number := rec_billsch.object_version_number;
                  
                     cnt1 := cnt1 + 1;
                  END IF;
               END LOOP; -- Billsch
            
               IF cnt1 > 0 THEN
               
                  oks_brs_pvt.update_row(p_api_version                  => l_api_version,
                                         p_init_msg_list                => l_init_msg_list,
                                         x_return_status                => l_return_status,
                                         x_msg_count                    => l_msg_count,
                                         x_msg_data                     => l_msg_data,
                                         p_oks_billrate_schedules_v_tbl => l_bill_rate_tbl_in,
                                         x_oks_billrate_schedules_v_tbl => l_bill_rate_tbl_out);
               END IF;
               cnt1 := 0;
            
            END LOOP; -- billrate
         END LOOP;
      END LOOP; -- BP
      IF cnt > 0 THEN
         okc_contract_pub.update_contract_line(p_api_version       => l_api_version,
                                               p_init_msg_list     => l_init_msg_list,
                                               x_return_status     => l_return_status,
                                               x_msg_count         => l_msg_count,
                                               x_msg_data          => l_msg_data,
                                               p_restricted_update => 'F',
                                               p_clev_tbl          => l_clev_tbl_in,
                                               x_clev_tbl          => l_clev_tbl_out);
      END IF;
      cnt := 0;
      -- End Billing Rate --
   
      -- TimeZone--
      FOR rec_bp IN csr_bp_id(l_coverage_id) LOOP
         FOR rec_covtz IN csr_tz_id(rec_bp.id) LOOP
         
            IF rec_covtz.dnz_chr_id <> p_dnz_chr_id THEN
               l_timezone_tbl_in(cnt).id := rec_covtz.id;
               l_timezone_tbl_in(cnt).dnz_chr_id := p_dnz_chr_id;
               l_timezone_tbl_in(cnt).object_version_number := rec_covtz.object_version_number;
            
               cnt := cnt + 1;
            END IF;
         END LOOP;
      END LOOP;
      IF cnt > 0 THEN
      
         oks_ctz_pvt.update_row(p_api_version                  => l_api_version,
                                p_init_msg_list                => l_init_msg_list,
                                x_return_status                => l_return_status,
                                x_msg_count                    => l_msg_count,
                                x_msg_data                     => l_msg_data,
                                p_oks_coverage_timezones_v_tbl => l_timezone_tbl_in,
                                x_oks_coverage_timezones_v_tbl => l_timezone_tbl_out);
      END IF;
      cnt := 0;
   
      -- End Time Zone--
      -- Times --
      FOR rec_bp IN csr_bp_id(l_coverage_id) LOOP
         FOR rec_covtz IN csr_tz_id(rec_bp.id) LOOP
            FOR rec_times IN csr_times_id(rec_covtz.id) LOOP
               -- If rec_times.dnz_chr_id<>p_dnz_chr_id Then
               l_cov_time_tbl_in(cnt).id := rec_times.id;
               l_cov_time_tbl_in(cnt).dnz_chr_id := p_dnz_chr_id;
               l_cov_time_tbl_in(cnt).object_version_number := rec_times.object_version_number;
            
               cnt := cnt + 1;
               -- End if;
            END LOOP;
         END LOOP;
      END LOOP;
      --If cnt>0 Then
      oks_cvt_pvt.update_row(p_api_version              => l_api_version,
                             p_init_msg_list            => l_init_msg_list,
                             x_return_status            => l_return_status,
                             x_msg_count                => l_msg_count,
                             x_msg_data                 => l_msg_data,
                             p_oks_coverage_times_v_tbl => l_cov_time_tbl_in,
                             x_oks_coverage_times_v_tbl => l_cov_time_tbl_out);
      -- End if;
      -- End Times --
   
   END update_dnz_chr_id;

   /* This procedure is used for creation of  PM and notes.
     Parameters :         p_standard_cov_id : Id of the source coverage or source contract line
                          p_contract_line_id : Id of the target contract line
     Create_K_coverage_ext can be called during the creation of service line from authoring or from renewal
     consolidation flow.
   */
   PROCEDURE create_k_coverage_ext(p_api_version   IN NUMBER,
                                   p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                                   p_src_line_id   IN NUMBER,
                                   p_tgt_line_id   IN NUMBER,
                                   x_return_status OUT NOCOPY VARCHAR2,
                                   x_msg_count     OUT NOCOPY NUMBER,
                                   x_msg_data      OUT NOCOPY VARCHAR2) IS
   
      --Cursor definition
      /*  Modified by Jvorugan .Added p_source_object_code as input parameter.
      This  differentiates whether notes is associated with a standard coverage
      or a service line  */
   
      CURSOR cur_get_notes(p_source_object_id IN NUMBER, p_source_object_code IN VARCHAR2) IS
         SELECT jtf_note_id,
                parent_note_id,
                source_object_code,
                source_number,
                notes, --
                notes_detail,
                note_status,
                source_object_meaning,
                note_type,
                note_type_meaning,
                attribute1,
                attribute2,
                attribute3,
                attribute4,
                attribute5,
                attribute6,
                attribute7,
                attribute8,
                attribute9,
                attribute10,
                attribute11,
                attribute12,
                attribute13,
                attribute14,
                attribute15,
                note_status_meaning,
                decoded_source_code,
                decoded_source_meaning,
                CONTEXT
           FROM jtf_notes_vl
          WHERE source_object_id = p_source_object_id AND
                source_object_code = p_source_object_code --  'OKS_COVTMPL_NOTE'
                AND
                note_status <>
                (CASE WHEN p_source_object_code = 'OKS_COVTMPL_NOTE' THEN 'P' ELSE '!' END);
      -- Commented by Jvorugan. note_status <> 'P';
   
      CURSOR cur_get_line_dates IS
         SELECT start_date, end_date
           FROM okc_k_lines_b
          WHERE id = p_tgt_line_id; --p_contract_line_id;
   
      -- Modified by Jvorugan for Bug:4610475. Added pm_sch_exists_yn,pm_conf_req_yn
      CURSOR cur_check_pm_prog IS
         SELECT pm_program_id, pm_sch_exists_yn, pm_conf_req_yn
           FROM oks_k_lines_b
          WHERE cle_id = p_src_line_id; --p_standard_cov_id;  -- modified by Jvorugan Bug:4535339  ID = p_standard_cov_id;
   
      -- Added by Jvorugan
      CURSOR cur_get_lse_id IS
         SELECT lse_id FROM okc_k_lines_b WHERE id = p_src_line_id; --p_standard_cov_id;
   
      get_lse_id_rec cur_get_lse_id%ROWTYPE;
   
      l_start_date   DATE;
      l_end_date     DATE;
      l_pm_prog_id   NUMBER;
      l_jtf_note_id  NUMBER;
      l_notes_detail VARCHAR2(32767);
   
      l_api_version   CONSTANT NUMBER := 1.0;
      l_init_msg_list CONSTANT VARCHAR2(1) := 'F';
      l_return_status VARCHAR2(1);
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(2000) := NULL;
      --l_msg_index_out NUMBER;
      l_api_name CONSTANT VARCHAR2(30) := 'Create_K_coverage_ext';
   
      -- Added by Jvorugan for Bug: 4610475.
      l_pm_sch_exists_yn   VARCHAR2(1);
      l_pm_conf_req_yn     VARCHAR2(1);
      l_source_object_code jtf_notes_b.source_object_code%TYPE;
      l_source_line_id     NUMBER;
   
   BEGIN
      l_return_status := 'S';
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.set_indentation('Create_K_Coverage_Ext');
         okc_debug.log('BEGIN  CREATE_K_COVERAGE_EXT' || l_return_status,
                       2);
      END IF;
   
      SAVEPOINT create_k_coverage_ext_pvt;
   
      -- Added by Jvorugan. Depending on  lse_id, l_source_object_code is populated.
      OPEN cur_get_lse_id;
      FETCH cur_get_lse_id
         INTO get_lse_id_rec;
      CLOSE cur_get_lse_id;
   
      l_source_line_id := p_src_line_id; --p_standard_cov_id;
      IF get_lse_id_rec.lse_id IN (1, 14, 19) THEN
         l_source_object_code := 'OKS_COV_NOTE';
      ELSE
         l_source_object_code := 'OKS_COVTMPL_NOTE';
      END IF;
      -- End of changes by Jvorugan
      FOR get_line_dates_rec IN cur_get_line_dates LOOP
         l_start_date := get_line_dates_rec.start_date;
         l_end_date   := get_line_dates_rec.end_date;
      END LOOP;
      FOR check_pm_prog_rec IN cur_check_pm_prog LOOP
         l_pm_prog_id       := check_pm_prog_rec.pm_program_id;
         l_pm_sch_exists_yn := check_pm_prog_rec.pm_sch_exists_yn; -- Added by Jvorugan for Bug:4610475
         l_pm_conf_req_yn   := check_pm_prog_rec.pm_conf_req_yn;
      
      END LOOP;
      -- create notes for actual coverage from the template
      -- pass coverage_template_id as (p_source_object_id IN parameter )in the cursor below
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.log('BEFORE CALLING JTF_NOTES_PUB.CREATE_NOTE' ||
                       l_return_status,
                       2);
      END IF;
   
      -- Added l_source_object_code,l_source_line_id as input parameters for CUR_GET_NOTES
      FOR notes_rec IN cur_get_notes(l_source_line_id, l_source_object_code) LOOP
         jtf_notes_pub.writelobtodata(notes_rec.jtf_note_id,
                                      l_notes_detail);
      
         jtf_notes_pub.create_note(p_parent_note_id     => notes_rec.parent_note_id,
                                   p_api_version        => l_api_version,
                                   p_init_msg_list      => l_init_msg_list,
                                   p_commit             => 'F',
                                   p_validation_level   => 100,
                                   x_return_status      => l_return_status,
                                   x_msg_count          => l_msg_count,
                                   x_msg_data           => l_msg_data,
                                   p_org_id             => NULL,
                                   p_source_object_id   => p_tgt_line_id, -- p_contract_line_id,
                                   p_source_object_code => 'OKS_COV_NOTE',
                                   p_notes              => notes_rec.notes,
                                   p_notes_detail       => l_notes_detail,
                                   p_note_status        => notes_rec.note_status,
                                   p_entered_by         => fnd_global.user_id,
                                   p_entered_date       => SYSDATE,
                                   x_jtf_note_id        => l_jtf_note_id,
                                   p_last_update_date   => SYSDATE,
                                   p_last_updated_by    => fnd_global.user_id,
                                   p_creation_date      => SYSDATE,
                                   p_created_by         => fnd_global.user_id,
                                   p_last_update_login  => fnd_global.login_id,
                                   p_attribute1         => notes_rec.attribute1,
                                   p_attribute2         => notes_rec.attribute2,
                                   p_attribute3         => notes_rec.attribute3,
                                   p_attribute4         => notes_rec.attribute4,
                                   p_attribute5         => notes_rec.attribute5,
                                   p_attribute6         => notes_rec.attribute6,
                                   p_attribute7         => notes_rec.attribute7,
                                   p_attribute8         => notes_rec.attribute8,
                                   p_attribute9         => notes_rec.attribute9,
                                   p_attribute10        => notes_rec.attribute10,
                                   p_attribute11        => notes_rec.attribute11,
                                   p_attribute12        => notes_rec.attribute12,
                                   p_attribute13        => notes_rec.attribute13,
                                   p_attribute14        => notes_rec.attribute14,
                                   p_attribute15        => notes_rec.attribute15,
                                   p_context            => notes_rec.CONTEXT,
                                   p_note_type          => notes_rec.note_type);
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('AFTER CALLING JTF_NOTES_PUB.CREATE_NOTE' ||
                          l_return_status,
                          2);
         END IF;
      
         IF NOT l_return_status = okc_api.g_ret_sts_success THEN
            RAISE g_exception_halt_validation;
         END IF;
      END LOOP;
      --errorout_ad('before'||l_return_status);
   
      --IF l_klnv_tbl_in(1).pm_program_id IS NOT NULL then -- No need to call PM schedule instantiation if there is no program id.
      --(Now I am going to add this validation (IF condition) into CREATE_PM_PROGRAM_SCHEDULE for simplicity)
      IF l_pm_prog_id IS NOT NULL THEN
         -- Added by Jvorugan for Bug:4610475
         -- From R12, PM will always be associated with service line instead of coverage.
         -- Update oks_k_lines_b record of the service line  with the pm information.
         UPDATE oks_k_lines_b
            SET pm_program_id    = l_pm_prog_id,
                pm_sch_exists_yn = l_pm_sch_exists_yn,
                pm_conf_req_yn   = l_pm_conf_req_yn
          WHERE cle_id = p_tgt_line_id; --p_contract_line_id;
      
         oks_pm_programs_pvt.create_pm_program_schedule(p_api_version     => l_api_version,
                                                        p_init_msg_list   => l_init_msg_list,
                                                        x_return_status   => l_return_status,
                                                        x_msg_count       => l_msg_count,
                                                        x_msg_data        => l_msg_data,
                                                        p_template_cle_id => p_src_line_id, --p_standard_cov_id,
                                                        p_cle_id          => p_tgt_line_id, --p_contract_line_id,
                                                        p_cov_start_date  => l_start_date,
                                                        p_cov_end_date    => l_end_date);
         --errorout_ad('after'||l_return_status);
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('After OKS_PM_PROGRAMS_PVT. CREATE_PM_PROGRAM_SCHEDULE' ||
                          l_return_status,
                          2);
         END IF;
      
         IF NOT l_return_status = okc_api.g_ret_sts_success THEN
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
      x_return_status := l_return_status;
   EXCEPTION
   
      WHEN g_exception_halt_validation THEN
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Create_K_coverage_ext' || SQLERRM, 2);
            okc_debug.reset_indentation;
         END IF;
         x_return_status := l_return_status;
         x_msg_count     := l_msg_count;
         x_msg_data      := l_msg_data;
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      'Create_K_coverage_ext',
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_error THEN
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Create_K_coverage_ext' || SQLERRM, 2);
            okc_debug.reset_indentation;
         END IF;
         x_msg_count     := l_msg_count;
         x_msg_data      := l_msg_data;
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      'Create_K_coverage_ext',
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Create_K_coverage_ext' || SQLERRM, 2);
            okc_debug.reset_indentation;
         END IF;
         x_msg_count     := l_msg_count;
         x_msg_data      := l_msg_data;
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      'Create_K_coverage_ext',
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('Create_K_coverage_ext' || SQLERRM, 2);
            okc_debug.reset_indentation;
         END IF;
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
         x_msg_count     := l_msg_count;
      
   END create_k_coverage_ext;

   /* This procedure is used for Copying the standard coverage template.
   Parameters:
              P_old_coverage_id    --  ID of the source coverage
              P_new_coverage_name  --  Name of the Target coverage
              x_new_coverage_id    -- New Id of the copied coverage    */
   PROCEDURE copy_standard_coverage(p_api_version       IN NUMBER,
                                    p_init_msg_list     IN VARCHAR2 DEFAULT okc_api.g_false,
                                    x_return_status     OUT NOCOPY VARCHAR2,
                                    x_msg_count         OUT NOCOPY NUMBER,
                                    x_msg_data          OUT NOCOPY VARCHAR2,
                                    p_old_coverage_id   IN NUMBER,
                                    p_new_coverage_name IN VARCHAR2,
                                    x_new_coverage_id   OUT NOCOPY NUMBER) IS
   
      -----------------------------------------------
      CURSOR cur_get_line_id(p_cle_id NUMBER) IS
         SELECT id FROM okc_k_lines_b WHERE cle_id = p_cle_id;
   
      -----------------------------------------------
      CURSOR cur_childline(p_cle_id IN NUMBER) IS
         SELECT id, lse_id FROM okc_k_lines_b WHERE cle_id = p_cle_id;
      -----------------------------------------------
      CURSOR cur_itemdet(p_id IN NUMBER) IS
         SELECT id FROM okc_k_items_v WHERE cle_id = p_id;
      ------------------------------------------------
      CURSOR cur_childline1(p_cle_id IN NUMBER) IS
         SELECT id, lse_id FROM okc_k_lines_b WHERE cle_id = p_cle_id;
      -------------------------------------------------
      CURSOR cur_ptrldet(p_cle_id IN NUMBER, p_role_code IN VARCHAR2) IS
         SELECT pr.id
           FROM okc_k_party_roles_v pr, okc_k_lines_b lv
          WHERE pr.cle_id = p_cle_id AND
                pr.rle_code = p_role_code AND
                pr.cle_id = lv.id AND
                pr.dnz_chr_id = lv.dnz_chr_id;
   
      cr_ptrl_det cur_ptrldet%ROWTYPE;
      -------------------------------------------------
      CURSOR cur_contactdet(p_cpl_id IN NUMBER) IS
         SELECT id FROM okc_contacts_v WHERE cpl_id = p_cpl_id;
      -------------------------------------------------
      CURSOR cur_childline_br(p_cle_id IN NUMBER) IS
         SELECT id FROM okc_k_lines_b WHERE cle_id = p_cle_id;
      -------------------------------------------------
      l_old_coverage_id okc_k_lines_b.id%TYPE;
      l_new_coverage_id okc_k_lines_b.id%TYPE;
      l_old_bp_id       okc_k_lines_b.id%TYPE;
      l_new_bp_id       okc_k_lines_b.id%TYPE;
      l_old_bp_item_id  okc_k_items.id%TYPE;
      l_new_bp_item_id  okc_k_items.id%TYPE;
      l_old_rt_id       okc_k_lines_b.id%TYPE;
      l_new_rt_id       okc_k_lines_b.id%TYPE;
      l_new_rt_item_id  okc_k_items.id%TYPE;
      l_old_rt_item_id  okc_k_items.id%TYPE;
      l_old_party_id    okc_k_party_roles_b.id%TYPE;
      l_new_party_id    okc_k_party_roles_b.id%TYPE;
      --l_old_contact_id  okc_contacts.id%TYPE;
      --l_new_contact_id  okc_contacts.id%TYPE;
      --l_old_bt_id       okc_k_lines_b.id%TYPE;
      --l_new_bt_id       okc_k_lines_b.id%TYPE;
      l_old_br_id       okc_k_lines_b.id%TYPE;
      l_new_br_id       okc_k_lines_b.id%TYPE;
      l_cov_flag        NUMBER;
      l_return_status   VARCHAR2(1) := okc_api.g_ret_sts_success;
   
      -- This function is called by copy_standard_coverage for insertion into okc_k_lines_b table
      FUNCTION create_okc_line(p_new_line_id NUMBER,
                               p_old_line_id NUMBER,
                               p_flag        NUMBER,
                               p_cle_id      NUMBER DEFAULT NULL)
         RETURN VARCHAR2 IS
      
         x_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
         l_start_date    DATE;
         l_coverage_name VARCHAR2(150);
      
      BEGIN
         -- If flag is 1, then call is made for creating the top coverage line.
         -- so, we need to default sysdate as the start date
         IF p_flag = 1 THEN
            l_start_date    := trunc(SYSDATE);
            l_coverage_name := p_new_coverage_name;
         ELSE
            l_start_date    := NULL;
            l_coverage_name := NULL;
         END IF;
      
         INSERT INTO okc_k_lines_b
            (id,
             line_number,
             chr_id,
             cle_id,
             cle_id_renewed,
             dnz_chr_id,
             display_sequence,
             sts_code,
             trn_code,
             lse_id,
             exception_yn,
             object_version_number,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date,
             hidden_ind,
             price_negotiated,
             price_level_ind,
             price_unit,
             price_unit_percent,
             invoice_line_level_ind,
             dpas_rating,
             template_used,
             price_type,
             currency_code,
             last_update_login,
             date_terminated,
             start_date,
             end_date,
             attribute_category,
             attribute1,
             attribute2,
             attribute3,
             attribute4,
             attribute5,
             attribute6,
             attribute7,
             attribute8,
             attribute9,
             attribute10,
             attribute11,
             attribute12,
             attribute13,
             attribute14,
             attribute15,
             security_group_id,
             cle_id_renewed_to,
             price_negotiated_renewed,
             currency_code_renewed,
             upg_orig_system_ref,
             upg_orig_system_ref_id,
             date_renewed,
             orig_system_source_code,
             orig_system_id1,
             orig_system_reference1,
             program_application_id,
             program_id,
             program_update_date,
             request_id,
             price_list_id,
             price_list_line_id,
             line_list_price,
             item_to_price_yn,
             pricing_date,
             price_basis_yn,
             config_header_id,
             config_revision_number,
             config_complete_yn,
             config_valid_yn,
             config_top_model_line_id,
             config_item_type,
             config_item_id,
             service_item_yn,
             ph_pricing_type,
             ph_price_break_basis,
             ph_min_qty,
             ph_min_amt,
             ph_qp_reference_id,
             ph_value,
             ph_enforce_price_list_yn,
             ph_adjustment,
             ph_integrated_with_qp,
             cust_acct_id,
             bill_to_site_use_id,
             inv_rule_id,
             line_renewal_type_code,
             ship_to_site_use_id,
             payment_term_id,
             date_cancelled,
             -- CANC_REASON_CODE,
             -- TRXN_EXTENSION_ID,
             term_cancel_source,
             annualized_factor)
            SELECT p_new_line_id id,
                   line_number,
                   chr_id,
                   p_cle_id cle_id,
                   cle_id_renewed,
                   dnz_chr_id,
                   display_sequence,
                   sts_code,
                   trn_code,
                   lse_id,
                   exception_yn,
                   1 object_version_number,
                   fnd_global.user_id created_by,
                   SYSDATE creation_date,
                   fnd_global.user_id last_updated_by,
                   SYSDATE last_update_date,
                   hidden_ind,
                   price_negotiated,
                   price_level_ind,
                   price_unit,
                   price_unit_percent,
                   invoice_line_level_ind,
                   dpas_rating,
                   template_used,
                   price_type,
                   currency_code,
                   fnd_global.login_id last_update_login,
                   date_terminated,
                   l_start_date start_date,
                   NULL end_date,
                   attribute_category,
                   attribute1,
                   attribute2,
                   attribute3,
                   attribute4,
                   attribute5,
                   attribute6,
                   attribute7,
                   attribute8,
                   attribute9,
                   attribute10,
                   attribute11,
                   attribute12,
                   attribute13,
                   attribute14,
                   attribute15,
                   security_group_id,
                   cle_id_renewed_to,
                   price_negotiated_renewed,
                   currency_code_renewed,
                   upg_orig_system_ref,
                   upg_orig_system_ref_id,
                   date_renewed,
                   orig_system_source_code, -- CHECK IF THIS NEED TO BE POPULATED
                   p_old_line_id orig_system_id1,
                   orig_system_reference1,
                   program_application_id,
                   program_id,
                   program_update_date,
                   request_id,
                   price_list_id,
                   price_list_line_id,
                   line_list_price,
                   item_to_price_yn,
                   pricing_date,
                   price_basis_yn,
                   config_header_id,
                   config_revision_number,
                   config_complete_yn,
                   config_valid_yn,
                   config_top_model_line_id,
                   config_item_type,
                   config_item_id,
                   service_item_yn,
                   ph_pricing_type,
                   ph_price_break_basis,
                   ph_min_qty,
                   ph_min_amt,
                   ph_qp_reference_id,
                   ph_value,
                   ph_enforce_price_list_yn,
                   ph_adjustment,
                   ph_integrated_with_qp,
                   cust_acct_id,
                   bill_to_site_use_id,
                   inv_rule_id,
                   line_renewal_type_code,
                   ship_to_site_use_id,
                   payment_term_id,
                   date_cancelled,
                   -- CANC_REASON_CODE,
                   -- TRXN_EXTENSION_ID,
                   term_cancel_source,
                   annualized_factor
              FROM okc_k_lines_b
             WHERE id = p_old_line_id;
      
         INSERT INTO okc_k_lines_tl
            (id,
             LANGUAGE,
             source_lang,
             sfwt_flag,
             NAME,
             comments,
             item_description,
             block23text,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date,
             last_update_login,
             security_group_id,
             oke_boe_description,
             cognomen)
            SELECT p_new_line_id id,
                   LANGUAGE,
                   source_lang,
                   sfwt_flag,
                   l_coverage_name NAME,
                   comments,
                   item_description,
                   block23text,
                   fnd_global.user_id created_by,
                   SYSDATE creation_date,
                   fnd_global.user_id last_updated_by,
                   SYSDATE last_update_date,
                   fnd_global.login_id last_update_login,
                   security_group_id,
                   oke_boe_description,
                   cognomen
              FROM okc_k_lines_tl
             WHERE id = p_old_line_id;
      
         RETURN x_return_status;
      
      EXCEPTION
         WHEN OTHERS THEN
            okc_api.set_message(g_app_name,
                                g_unexpected_error,
                                g_sqlcode_token,
                                SQLCODE,
                                g_sqlerrm_token,
                                SQLERRM);
            x_return_status := okc_api.g_ret_sts_unexp_error;
            RETURN x_return_status;
         
      END create_okc_line;
   
      -- This function is called by copy_standard_coverage for insertion into okc_k_items table
      FUNCTION create_okc_item(p_new_item_id NUMBER,
                               p_old_item_id NUMBER,
                               p_cle_id      NUMBER) RETURN VARCHAR2 IS
      
         x_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      
      BEGIN
      
         INSERT INTO okc_k_items
            (id,
             cle_id,
             chr_id,
             cle_id_for,
             dnz_chr_id,
             object1_id1,
             object1_id2,
             jtot_object1_code,
             uom_code,
             exception_yn,
             number_of_items,
             priced_item_yn,
             object_version_number,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date,
             last_update_login,
             security_group_id,
             upg_orig_system_ref,
             upg_orig_system_ref_id,
             program_application_id,
             program_id,
             program_update_date,
             request_id)
            SELECT p_new_item_id id,
                   p_cle_id cle_id,
                   chr_id,
                   cle_id_for,
                   dnz_chr_id,
                   object1_id1,
                   object1_id2,
                   jtot_object1_code,
                   uom_code,
                   exception_yn,
                   number_of_items,
                   priced_item_yn,
                   1 object_version_number,
                   fnd_global.user_id created_by,
                   SYSDATE creation_date,
                   fnd_global.user_id last_updated_by,
                   SYSDATE last_update_date,
                   fnd_global.login_id last_update_login,
                   security_group_id,
                   upg_orig_system_ref,
                   p_old_item_id upg_orig_system_ref_id,
                   program_application_id,
                   program_id,
                   program_update_date,
                   request_id
              FROM okc_k_items
             WHERE id = p_old_item_id;
      
         RETURN x_return_status;
      
      EXCEPTION
         WHEN OTHERS THEN
            x_return_status := okc_api.g_ret_sts_unexp_error;
            okc_api.set_message(g_app_name,
                                g_unexpected_error,
                                g_sqlcode_token,
                                SQLCODE,
                                g_sqlerrm_token,
                                SQLERRM);
         
            RETURN x_return_status;
         
      END create_okc_item;
   
      -- This function is called by copy_standard_coverage for insertion into okc_k_party_roles_b table
      FUNCTION create_okc_party(p_new_party_id NUMBER,
                                p_old_party_id NUMBER,
                                p_cle_id       NUMBER) RETURN VARCHAR2 IS
      
         x_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      
      BEGIN
      
         INSERT INTO okc_k_party_roles_b
            (id,
             chr_id,
             cle_id,
             dnz_chr_id,
             rle_code,
             object1_id1,
             object1_id2,
             jtot_object1_code,
             object_version_number,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date,
             code,
             facility,
             minority_group_lookup_code,
             small_business_flag,
             women_owned_flag,
             last_update_login,
             attribute_category,
             attribute1,
             attribute2,
             attribute3,
             attribute4,
             attribute5,
             attribute6,
             attribute7,
             attribute8,
             attribute9,
             attribute10,
             attribute11,
             attribute12,
             attribute13,
             attribute14,
             attribute15,
             security_group_id,
             cpl_id,
             primary_yn,
             bill_to_site_use_id,
             cust_acct_id,
             orig_system_id1,
             orig_system_reference1,
             orig_system_source_code)
            SELECT p_new_party_id id,
                   chr_id,
                   p_cle_id cle_id,
                   dnz_chr_id,
                   rle_code,
                   object1_id1,
                   object1_id2,
                   jtot_object1_code,
                   object_version_number,
                   fnd_global.user_id created_by,
                   SYSDATE creation_date,
                   fnd_global.user_id last_updated_by,
                   SYSDATE last_update_date,
                   code,
                   facility,
                   minority_group_lookup_code,
                   small_business_flag,
                   women_owned_flag,
                   fnd_global.login_id last_update_login,
                   attribute_category,
                   attribute1,
                   attribute2,
                   attribute3,
                   attribute4,
                   attribute5,
                   attribute6,
                   attribute7,
                   attribute8,
                   attribute9,
                   attribute10,
                   attribute11,
                   attribute12,
                   attribute13,
                   attribute14,
                   attribute15,
                   security_group_id,
                   cpl_id,
                   primary_yn,
                   bill_to_site_use_id,
                   cust_acct_id,
                   p_old_party_id orig_system_id1,
                   orig_system_reference1,
                   orig_system_source_code
              FROM okc_k_party_roles_b
             WHERE id = p_old_party_id;
      
         -- insert into tl table
         INSERT INTO okc_k_party_roles_tl
            (id,
             LANGUAGE,
             source_lang,
             sfwt_flag,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date,
             cognomen,
             alias,
             last_update_login,
             security_group_id)
            SELECT p_new_party_id id,
                   LANGUAGE,
                   source_lang,
                   sfwt_flag,
                   fnd_global.user_id created_by,
                   SYSDATE creation_date,
                   fnd_global.user_id last_updated_by,
                   SYSDATE last_update_date,
                   cognomen,
                   alias,
                   fnd_global.login_id last_update_login,
                   security_group_id
              FROM okc_k_party_roles_tl
             WHERE id = p_old_party_id;
      
         RETURN x_return_status;
      
      EXCEPTION
         WHEN OTHERS THEN
            okc_api.set_message(g_app_name,
                                g_unexpected_error,
                                g_sqlcode_token,
                                SQLCODE,
                                g_sqlerrm_token,
                                SQLERRM);
            x_return_status := okc_api.g_ret_sts_unexp_error;
            RETURN x_return_status;
      END create_okc_party;
   
      -- This function is called by copy_standard_coverage for insertion into okc_contacts table
      FUNCTION create_okc_contact(p_new_cpl_id NUMBER, p_old_cpl_id NUMBER)
         RETURN VARCHAR2 IS
      
         x_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      
      BEGIN
      
         INSERT INTO okc_contacts
            (id,
             cpl_id,
             cro_code,
             dnz_chr_id,
             object1_id1,
             object1_id2,
             jtot_object1_code,
             object_version_number,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date,
             contact_sequence,
             last_update_login,
             attribute_category,
             attribute1,
             attribute2,
             attribute3,
             attribute4,
             attribute5,
             attribute6,
             attribute7,
             attribute8,
             attribute9,
             attribute10,
             attribute11,
             attribute12,
             attribute13,
             attribute14,
             attribute15,
             security_group_id,
             start_date,
             end_date,
             primary_yn,
             resource_class,
             sales_group_id)
         --ORIG_SYSTEM_ID)
            SELECT okc_p_util.raw_to_number(sys_guid()),
                   p_new_cpl_id cpl_id, -- new party id (CPL_ID)
                   cro_code,
                   dnz_chr_id,
                   object1_id1,
                   object1_id2,
                   jtot_object1_code,
                   object_version_number,
                   fnd_global.user_id created_by,
                   SYSDATE creation_date,
                   fnd_global.user_id last_updated_by,
                   SYSDATE last_update_date,
                   contact_sequence,
                   fnd_global.login_id last_update_login,
                   attribute_category,
                   attribute1,
                   attribute2,
                   attribute3,
                   attribute4,
                   attribute5,
                   attribute6,
                   attribute7,
                   attribute8,
                   attribute9,
                   attribute10,
                   attribute11,
                   attribute12,
                   attribute13,
                   attribute14,
                   attribute15,
                   security_group_id,
                   start_date,
                   end_date,
                   primary_yn,
                   resource_class,
                   sales_group_id
            --ID --ORIG_SYSTEM_ID
              FROM okc_contacts
             WHERE cpl_id = p_old_cpl_id;
      
         RETURN x_return_status;
      
      EXCEPTION
         WHEN OTHERS THEN
            okc_api.set_message(g_app_name,
                                g_unexpected_error,
                                g_sqlcode_token,
                                SQLCODE,
                                g_sqlerrm_token,
                                SQLERRM);
            x_return_status := okc_api.g_ret_sts_unexp_error;
            RETURN x_return_status;
         
      END create_okc_contact;
   
   BEGIN
   
      SAVEPOINT copy_standard_coverage;
      l_old_coverage_id := p_old_coverage_id;
   
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.set_indentation('Copy_Standard_Coverage');
         okc_debug.log('BEGIN COPY_STANDARD_COVERAGE' || l_return_status,
                       2);
      END IF;
   
      -- Create Coverage line
      l_new_coverage_id := okc_p_util.raw_to_number(sys_guid());
      l_cov_flag        := 1;
      l_return_status   := create_okc_line(l_new_coverage_id,
                                           l_old_coverage_id,
                                           l_cov_flag);
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.log('AFTER CREATE_OKC_LINE FOR COVERAGE' ||
                       l_return_status,
                       2);
      END IF;
   
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         RAISE g_exception_halt_validation;
      END IF;
   
      -- Create business process line
      FOR childline_rec1 IN cur_childline(l_old_coverage_id) --Loop1
       LOOP
         l_old_bp_id     := childline_rec1.id;
         l_new_bp_id     := okc_p_util.raw_to_number(sys_guid());
         l_cov_flag      := 2;
         l_return_status := create_okc_line(l_new_bp_id,
                                            l_old_bp_id,
                                            l_cov_flag,
                                            l_new_coverage_id);
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('AFTER CREATE_OKC_LINE FOR BP' ||
                          l_return_status,
                          2);
         END IF;
      
         IF l_return_status <> okc_api.g_ret_sts_success THEN
            RAISE g_exception_halt_validation;
         END IF;
      
         -- Create  a Contract ITEM FOR BUSINESS PROCESS
         OPEN cur_itemdet(l_old_bp_id);
         FETCH cur_itemdet
            INTO l_old_bp_item_id;
         CLOSE cur_itemdet;
         l_new_bp_item_id := okc_p_util.raw_to_number(sys_guid());
         l_return_status  := create_okc_item(l_new_bp_item_id,
                                             l_old_bp_item_id,
                                             l_new_bp_id);
         IF (g_debug_enabled = 'Y') THEN
            okc_debug.log('AFTER CREATE_OKC_ITEM' || l_return_status, 2);
         END IF;
      
         IF l_return_status <> okc_api.g_ret_sts_success THEN
            RAISE g_exception_halt_validation;
         END IF;
         -- Done Business Process
      
         -- Create Reaction times line  Billtypes
         FOR tmp_crt_rec IN cur_childline1(l_old_bp_id) LOOP
            l_old_rt_id     := tmp_crt_rec.id;
            l_new_rt_id     := okc_p_util.raw_to_number(sys_guid());
            l_cov_flag      := 3;
            l_return_status := create_okc_line(l_new_rt_id,
                                               l_old_rt_id,
                                               l_cov_flag,
                                               l_new_bp_id);
            IF (g_debug_enabled = 'Y') THEN
               okc_debug.log('AFTER CREATE_OKC_LINE FOR RT' ||
                             l_return_status,
                             2);
            END IF;
         
            IF l_return_status <> okc_api.g_ret_sts_success THEN
               RAISE g_exception_halt_validation;
            END IF;
            IF tmp_crt_rec.lse_id IN (5, 59) -- For Billtypes
             THEN
               --Create entry in okc_k_items
               OPEN cur_itemdet(l_old_rt_id);
               FETCH cur_itemdet
                  INTO l_old_rt_item_id;
               CLOSE cur_itemdet;
               l_new_rt_item_id := okc_p_util.raw_to_number(sys_guid());
               l_return_status  := create_okc_item(l_new_rt_item_id,
                                                   l_old_rt_item_id,
                                                   l_new_rt_id);
               IF (g_debug_enabled = 'Y') THEN
                  okc_debug.log('AFTER CREATE_OKC_ITEM FOR RT' ||
                                l_return_status,
                                2);
               END IF;
            
               IF l_return_status <> okc_api.g_ret_sts_success THEN
                  RAISE g_exception_halt_validation;
               END IF;
               --Create bill rate lines
               FOR tmp_br_rec IN cur_childline_br(l_old_rt_id) LOOP
                  l_old_br_id := tmp_br_rec.id;
                  IF NOT l_old_br_id IS NULL THEN
                     l_new_br_id     := okc_p_util.raw_to_number(sys_guid());
                     l_cov_flag      := 4;
                     l_return_status := create_okc_line(l_new_br_id,
                                                        l_old_br_id,
                                                        l_cov_flag,
                                                        l_new_rt_id);
                     IF (g_debug_enabled = 'Y') THEN
                        okc_debug.log('AFTER CREATE_OKC_LINE FOR BR' ||
                                      l_return_status,
                                      2);
                     END IF;
                  
                     IF l_return_status <> okc_api.g_ret_sts_success THEN
                        RAISE g_exception_halt_validation;
                     END IF;
                  END IF;
               END LOOP; --End loop for billrates
            END IF;
         END LOOP;
         -- Done Reaction times  billtypes
      
         -- Preferred Engineers
         OPEN cur_ptrldet(l_old_bp_id, 'VENDOR');
         FETCH cur_ptrldet
            INTO cr_ptrl_det;
         IF cur_ptrldet % FOUND THEN
            l_old_party_id  := cr_ptrl_det.id;
            l_new_party_id  := okc_p_util.raw_to_number(sys_guid());
            l_return_status := create_okc_party(l_new_party_id,
                                                l_old_party_id,
                                                l_new_bp_id);
            IF (g_debug_enabled = 'Y') THEN
               okc_debug.log('AFTER CREATE_OKC_PARTY' || l_return_status,
                             2);
            END IF;
         
            IF l_return_status <> okc_api.g_ret_sts_success THEN
               RAISE g_exception_halt_validation;
            END IF;
            -- okc_contacts
            l_return_status := create_okc_contact(l_new_party_id,
                                                  l_old_party_id);
            IF (g_debug_enabled = 'Y') THEN
               okc_debug.log('AFTER CREATE_OKC_CONTACT' || l_return_status,
                             2);
            END IF;
         
            IF l_return_status <> okc_api.g_ret_sts_success THEN
               RAISE g_exception_halt_validation;
            END IF;
         END IF;
         CLOSE cur_ptrldet;
      
      -- Done Preferred Engineers
      
      END LOOP; -- End loop for bp
      -- Create oks components
      copy_coverage(p_api_version      => 1.0,
                    p_init_msg_list    => okc_api.g_false,
                    x_return_status    => l_return_status,
                    x_msg_count        => x_msg_count,
                    x_msg_data         => x_msg_data,
                    p_contract_line_id => l_new_coverage_id);
   
      IF (g_debug_enabled = 'Y') THEN
         okc_debug.log('AFTER Copy_Coverage' || l_return_status, 2);
      END IF;
   
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         RAISE g_exception_halt_validation;
      END IF;
   
      x_new_coverage_id := l_new_coverage_id;
      x_return_status   := l_return_status;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
         x_return_status := l_return_status;
         ROLLBACK TO copy_standard_coverage;
      WHEN OTHERS THEN
         okc_api.set_message(g_app_name,
                             g_unexpected_error,
                             g_sqlcode_token,
                             SQLCODE,
                             g_sqlerrm_token,
                             SQLERRM);
         x_return_status := okc_api.g_ret_sts_unexp_error;
         ROLLBACK TO copy_standard_coverage;
      
   END copy_standard_coverage;

   PROCEDURE delete_coverage(p_api_version     IN NUMBER,
                             p_init_msg_list   IN VARCHAR2 DEFAULT okc_api.g_false,
                             x_return_status   OUT NOCOPY VARCHAR2,
                             x_msg_count       OUT NOCOPY NUMBER,
                             x_msg_data        OUT NOCOPY VARCHAR2,
                             p_service_line_id IN NUMBER) IS
   
      l_api_version   CONSTANT NUMBER := 1.0;
      l_init_msg_list CONSTANT VARCHAR2(1) := 'T';
      l_return_status VARCHAR2(3);
      --l_return_msg    VARCHAR2(2000);
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(2000);
      --l_msg_index_out NUMBER;
      --l_commit        VARCHAR2(2000) := 'F';
      l_api_name CONSTANT VARCHAR2(30) := 'Delete_Coverage';
   
      CURSOR cur_cov_id IS
         SELECT id
           FROM okc_k_lines_b
          WHERE cle_id = p_service_line_id AND
                lse_id IN (2, 15, 20);
   
   BEGIN
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                p_init_msg_list,
                                                '_PUB',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      ELSIF l_return_status IS NULL THEN
         RAISE okc_api.g_exception_unexpected_error;
      END IF;
   
      FOR cov_id_rec IN cur_cov_id LOOP
         /*
         OKS_COVERAGES_PUB.Undo_Line(
             p_api_version          => l_api_version,
             p_init_msg_list         => l_init_msg_list,
             x_return_status         => l_return_status,
             x_msg_count             => l_msg_count,
             x_msg_data              => l_msg_data,
             P_Line_Id               => Cov_Id_rec.Id);
         
         --dbms_output.put_line('status:'||l_return_status);
         */
      
         /* Valiate Status added */
      
         /*OKS_COVERAGES_PVT.Undo_Line(
         p_api_version          => l_api_version,
         p_init_msg_list         => l_init_msg_list,
         x_return_status         => l_return_status,
         x_msg_count             => l_msg_count,
         x_msg_data              => l_msg_data,
         p_validate_status       => 'N',
         P_Line_Id               => Cov_Id_rec.Id);*/
      
         --03/16/04 chkrishn modified to call api with no validate status
         undo_line(l_api_version,
                   l_init_msg_list,
                   l_return_status,
                   l_msg_count,
                   l_msg_data,
                   cov_id_rec.id);
      
         /*
              IF l_msg_count > 0
               THEN
                FOR i in 1..l_msg_count
                LOOP
                 fnd_msg_pub.get (p_msg_index     => -1,
                                  p_encoded       => 'F', -- OKC$APPLICATION.GET_FALSE,
                                  p_data          => l_msg_data,
                                  p_msg_index_out => l_msg_index_out);
         
         --dbms_output.put_line('Value of l_msg_data='||l_msg_data);
         
                END LOOP;
              END IF;
         */
         IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
            RAISE okc_api.g_exception_unexpected_error;
         ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
            RAISE okc_api.g_exception_error;
         ELSIF l_return_status IS NULL THEN
            RAISE okc_api.g_exception_unexpected_error;
         END IF;
      
      END LOOP;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PUB');
      WHEN okc_api.g_exception_unexpected_error THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PUB');
      WHEN g_exception_halt_validation THEN
         NULL;
      WHEN OTHERS THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END delete_coverage;
  --------------------------------------------------------------------
  --  name:            populate_oks_line 
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   04/12/2011 
  --------------------------------------------------------------------
  --  purpose :        populate_oks_line
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  04/12/2011  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
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
    --
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
    --
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
    --
    x_oks_line_tbl_out(1).coverage_id := okc_api.g_miss_num;
    x_oks_line_tbl_out(1).standard_cov_yn := okc_api.g_miss_char;
    x_oks_line_tbl_out(1).orig_system_id1 := okc_api.g_miss_num;
    x_oks_line_tbl_out(1).orig_system_reference1 := okc_api.g_miss_char;
    x_oks_line_tbl_out(1).orig_system_source_code := okc_api.g_miss_char;
   
    x_oks_line_tbl_out := x_oks_line_tbl_out;
  END populate_oks_line;
 
  --------------------------------------------------------------------
  --  name:            apply_standard 
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   04/12/2011 
  --------------------------------------------------------------------
  --  purpose :        apply_standard
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  04/12/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure apply_standard (errbuf     out varchar2, 
                            retcode    out varchar2) is

    cursor csr_all_contracts is
      select  h.id,
              l.id                     line_id,
              s.id                     service_line_id,
              s.coverage_id,
              msi.coverage_schedule_id cov_template_id,
              i.object1_id1            item_id,
              i.object1_id2            organization_id,
              l.start_date,
              l.end_date,
              h.org_id,
              s.standard_cov_yn,
              s.object_version_number
      from    okc_k_headers_all_b   h,
              okc_k_lines_b         l,
              oks_k_lines_b         s,
              okc_k_items           i,
              mtl_system_items_b    msi
      where   h.id                  = l.chr_id
      and     h.id                  = s.dnz_chr_id
      and     h.scs_code            = 'SERVICE'
      and     h.sts_code            not in ('CANCELLED')
      and     s.cle_id              = l.id
      and     i.cle_id              = l.id
      and     l.lse_id              = 1
      and     l.attribute1          = 'Y'
      and     i.object1_id1         = msi.inventory_item_id
      and     h.inv_organization_id = msi.organization_id
      and     msi.coverage_schedule_id != s.coverage_id;
   
      cur_contract   csr_all_contracts%ROWTYPE;
      l_klnv_tbl_in  oks_contract_line_pub.klnv_tbl_type;
      l_klnv_tbl_out oks_contract_line_pub.klnv_tbl_type;
      --l_clev_tbl_in  okc_contract_pub.clev_tbl_type;
      --l_clev_tbl_out okc_contract_pub.clev_tbl_type;
   
      l_return_status        varchar2(1);
      l_msg_count            number;
      l_msg_index_out        number;
      l_msg_data             varchar2(1000);
      --l_coverage_template_id number;
      l_err_msg              varchar2(1000);
      l_user_id              number;
      --l_prog_maint_id        number;
      --l_actual_coverage_id   number;
      --l_counter              number;
      invalid_contract       exception;
   
  begin
    errbuf   := null;
    retcode  := 0;
    
    select user_id
    into   l_user_id
    from   fnd_user
    where  user_name = 'SCHEDULER';
   
    for cur_contract in csr_all_contracts loop
            
      l_err_msg       := null;
      l_return_status := 's';
            
      if cur_contract.org_id = 81 then
        fnd_global.apps_initialize(user_id      => l_user_id,
                                   resp_id      => 50571,
                                   resp_appl_id => 515);
               
      elsif cur_contract.org_id = 89 then
        fnd_global.apps_initialize(user_id      => l_user_id,
                                   resp_id      => 50572,
                                   resp_appl_id => 515);
      elsif cur_contract.org_id = 96 then
        fnd_global.apps_initialize(user_id      => l_user_id,
                                   resp_id      => 50573,
                                   resp_appl_id => 515);
      elsif cur_contract.org_id = 103 then
        fnd_global.apps_initialize(user_id      => l_user_id,
                                   resp_id      => 50574,
                                   resp_appl_id => 515);
      end if;
            
      mo_global.set_org_access(p_org_id_char     => cur_contract.org_id,
                               p_sp_id_char      => NULL,
                               p_appl_short_name => 'OKS');
      
      begin
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
         
        if l_return_status != fnd_api.g_ret_sts_success then
            
           for i in 1 .. l_msg_count loop
              fnd_msg_pub.get(p_msg_index     => i,
                              p_data          => l_msg_data,
                              p_encoded       => fnd_api.g_false,
                              p_msg_index_out => l_msg_index_out);
              l_err_msg := l_err_msg || l_msg_data || chr(10);
           end loop;
           fnd_file.put_line(fnd_file.log,'------ Error ------');
           fnd_file.put_line(fnd_file.log,'id         - '||cur_contract.service_line_id);
           fnd_file.put_line(fnd_file.log,'cle_idc    - '||cur_contract.line_id);
           fnd_file.put_line(fnd_file.log,'dnz_chr_id - '||cur_contract.id);
           fnd_file.put_line(fnd_file.log,'cle_idc    - '||cur_contract.line_id);
           fnd_file.put_line(fnd_file.log,'------ Error ------');
           errbuf   := 'E - '||l_err_msg;
           retcode  := 1; 
           raise invalid_contract;
        else
          commit; 
          fnd_file.put_line(fnd_file.log,'------ Success ------');
          fnd_file.put_line(fnd_file.log,'id         - '||cur_contract.service_line_id);
          fnd_file.put_line(fnd_file.log,'cle_idc    - '||cur_contract.line_id);
          fnd_file.put_line(fnd_file.log,'dnz_chr_id - '||cur_contract.id);
          fnd_file.put_line(fnd_file.log,'cle_idc    - '||cur_contract.line_id);
          fnd_file.put_line(fnd_file.log,'------ Success ------');
          errbuf   := 'SUCCESS';
          retcode  := 0;   
        end if;
         
      exception
        when invalid_contract then
          rollback;
        when others then
          l_err_msg := sqlerrm;
          rollback;
      end;
    end loop;
   
  end apply_standard; 

END xxoks_coverages_pvt;
/
