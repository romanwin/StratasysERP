CREATE OR REPLACE PACKAGE xxoks_cle_pvt AS
   /* $Header: OKCSCLES.pls 120.8 2005/08/22 00:39:14 maanand noship $ */
   ---------------------------------------------------------------------------
   -- GLOBAL DATASTRUCTURES
   ---------------------------------------------------------------------------
   TYPE cle_rec_type IS RECORD(
      id                       NUMBER := okc_api.g_miss_num,
      line_number              okc_k_lines_b.line_number%TYPE := okc_api.g_miss_char,
      chr_id                   NUMBER := okc_api.g_miss_num,
      cle_id                   NUMBER := okc_api.g_miss_num,
      cle_id_renewed           NUMBER := okc_api.g_miss_num,
      dnz_chr_id               NUMBER := okc_api.g_miss_num,
      display_sequence         NUMBER := okc_api.g_miss_num,
      sts_code                 okc_k_lines_b.sts_code%TYPE := okc_api.g_miss_char,
      trn_code                 okc_k_lines_b.trn_code%TYPE := okc_api.g_miss_char,
      lse_id                   NUMBER := okc_api.g_miss_num,
      exception_yn             okc_k_lines_b.exception_yn%TYPE := okc_api.g_miss_char,
      object_version_number    NUMBER := okc_api.g_miss_num,
      created_by               NUMBER := okc_api.g_miss_num,
      creation_date            okc_k_lines_b.creation_date%TYPE := okc_api.g_miss_date,
      last_updated_by          NUMBER := okc_api.g_miss_num,
      last_update_date         okc_k_lines_b.last_update_date%TYPE := okc_api.g_miss_date,
      hidden_ind               okc_k_lines_b.hidden_ind%TYPE := okc_api.g_miss_char,
      price_unit               NUMBER := okc_api.g_miss_num,
      price_unit_percent       NUMBER := okc_api.g_miss_num,
      price_negotiated         NUMBER := okc_api.g_miss_num,
      price_level_ind          okc_k_lines_b.price_level_ind%TYPE := okc_api.g_miss_char,
      invoice_line_level_ind   okc_k_lines_b.invoice_line_level_ind%TYPE := okc_api.g_miss_char,
      dpas_rating              okc_k_lines_b.dpas_rating%TYPE := okc_api.g_miss_char,
      template_used            okc_k_lines_b.template_used%TYPE := okc_api.g_miss_char,
      price_type               okc_k_lines_b.price_type%TYPE := okc_api.g_miss_char,
      currency_code            okc_k_lines_b.currency_code%TYPE := okc_api.g_miss_char,
      last_update_login        NUMBER := okc_api.g_miss_num,
      date_terminated          okc_k_lines_b.date_terminated%TYPE := okc_api.g_miss_date,
      start_date               okc_k_lines_b.start_date%TYPE := okc_api.g_miss_date,
      end_date                 okc_k_lines_b.end_date%TYPE := okc_api.g_miss_date,
      date_renewed             okc_k_lines_b.date_renewed%TYPE := okc_api.g_miss_date,
      upg_orig_system_ref      okc_k_lines_b.upg_orig_system_ref%TYPE := okc_api.g_miss_char,
      upg_orig_system_ref_id   NUMBER := okc_api.g_miss_num,
      orig_system_source_code  okc_k_lines_b.orig_system_source_code%TYPE := okc_api.g_miss_char,
      orig_system_id1          NUMBER := okc_api.g_miss_num,
      orig_system_reference1   okc_k_lines_b.orig_system_reference1%TYPE := okc_api.g_miss_char,
      attribute_category       okc_k_lines_b.attribute_category%TYPE := okc_api.g_miss_char,
      attribute1               okc_k_lines_b.attribute1%TYPE := okc_api.g_miss_char,
      attribute2               okc_k_lines_b.attribute2%TYPE := okc_api.g_miss_char,
      attribute3               okc_k_lines_b.attribute3%TYPE := okc_api.g_miss_char,
      attribute4               okc_k_lines_b.attribute4%TYPE := okc_api.g_miss_char,
      attribute5               okc_k_lines_b.attribute5%TYPE := okc_api.g_miss_char,
      attribute6               okc_k_lines_b.attribute6%TYPE := okc_api.g_miss_char,
      attribute7               okc_k_lines_b.attribute7%TYPE := okc_api.g_miss_char,
      attribute8               okc_k_lines_b.attribute8%TYPE := okc_api.g_miss_char,
      attribute9               okc_k_lines_b.attribute9%TYPE := okc_api.g_miss_char,
      attribute10              okc_k_lines_b.attribute10%TYPE := okc_api.g_miss_char,
      attribute11              okc_k_lines_b.attribute11%TYPE := okc_api.g_miss_char,
      attribute12              okc_k_lines_b.attribute12%TYPE := okc_api.g_miss_char,
      attribute13              okc_k_lines_b.attribute13%TYPE := okc_api.g_miss_char,
      attribute14              okc_k_lines_b.attribute14%TYPE := okc_api.g_miss_char,
      attribute15              okc_k_lines_b.attribute15%TYPE := okc_api.g_miss_char,
      cle_id_renewed_to        NUMBER := okc_api.g_miss_num,
      currency_code_renewed    okc_k_lines_b.currency_code_renewed%TYPE := okc_api.g_miss_char,
      price_negotiated_renewed NUMBER := okc_api.g_miss_num,
      request_id               NUMBER := okc_api.g_miss_num,
      program_application_id   NUMBER := okc_api.g_miss_num,
      program_id               NUMBER := okc_api.g_miss_num,
      program_update_date      okc_k_lines_b.program_update_date%TYPE := okc_api.g_miss_date,
      price_list_id            NUMBER := okc_api.g_miss_num,
      pricing_date             okc_k_lines_b.pricing_date%TYPE := okc_api.g_miss_date,
      price_list_line_id       NUMBER := okc_api.g_miss_num,
      line_list_price          NUMBER := okc_api.g_miss_num,
      item_to_price_yn         okc_k_lines_b.item_to_price_yn%TYPE := okc_api.g_miss_char,
      price_basis_yn           okc_k_lines_b.price_basis_yn%TYPE := okc_api.g_miss_char,
      config_header_id         NUMBER := okc_api.g_miss_num,
      config_revision_number   NUMBER := okc_api.g_miss_num,
      config_complete_yn       okc_k_lines_b.config_complete_yn%TYPE := okc_api.g_miss_char,
      config_valid_yn          okc_k_lines_b.config_valid_yn%TYPE := okc_api.g_miss_char,
      config_top_model_line_id NUMBER := okc_api.g_miss_num,
      config_item_type         okc_k_lines_b.config_item_type%TYPE := okc_api.g_miss_char,
      config_item_id           NUMBER := okc_api.g_miss_num,
      service_item_yn          okc_k_lines_b.service_item_yn%TYPE := okc_api.g_miss_char,
      --new columns for price hold
      ph_pricing_type          okc_k_lines_b.ph_pricing_type%TYPE := okc_api.g_miss_char,
      ph_price_break_basis     okc_k_lines_b.ph_price_break_basis%TYPE := okc_api.g_miss_char,
      ph_min_qty               okc_k_lines_b.ph_min_qty%TYPE := okc_api.g_miss_num,
      ph_min_amt               okc_k_lines_b.ph_min_amt%TYPE := okc_api.g_miss_num,
      ph_qp_reference_id       okc_k_lines_b.ph_qp_reference_id%TYPE := okc_api.g_miss_num,
      ph_value                 okc_k_lines_b.ph_value%TYPE := okc_api.g_miss_num,
      ph_enforce_price_list_yn okc_k_lines_b.ph_enforce_price_list_yn%TYPE := okc_api.g_miss_char,
      ph_adjustment            okc_k_lines_b.ph_adjustment%TYPE := okc_api.g_miss_num,
      ph_integrated_with_qp    okc_k_lines_b.ph_integrated_with_qp%TYPE := okc_api.g_miss_char,
      --new columns to replace rules
      cust_acct_id           NUMBER := okc_api.g_miss_num,
      bill_to_site_use_id    NUMBER := okc_api.g_miss_num,
      inv_rule_id            NUMBER := okc_api.g_miss_num,
      line_renewal_type_code okc_k_lines_b.line_renewal_type_code%TYPE := okc_api.g_miss_char,
      ship_to_site_use_id    NUMBER := okc_api.g_miss_num,
      payment_term_id        NUMBER := okc_api.g_miss_num,
      --NPALEPU on 03-JUN-2005 Added new column for Annualized amounts Project.
      annualized_factor okc_k_lines_b.annualized_factor%TYPE := okc_api.g_miss_num,
      -- Line level Cancellation --
      date_cancelled okc_k_lines_b.date_cancelled%TYPE := okc_api.g_miss_date,
      --canc_reason_code     OKC_K_LINES_B.CANC_REASON_CODE%TYPE := OKC_API.G_MISS_CHAR,
      term_cancel_source       okc_k_lines_b.term_cancel_source%TYPE := okc_api.g_miss_char,
      cancelled_amount         okc_k_lines_b.cancelled_amount%TYPE := okc_api.g_miss_num,
      payment_instruction_type okc_k_lines_b.payment_instruction_type%TYPE := okc_api.g_miss_char
      
      );

   g_miss_cle_rec cle_rec_type;
   TYPE cle_tbl_type IS TABLE OF cle_rec_type INDEX BY BINARY_INTEGER;

   TYPE okc_k_lines_tl_rec_type IS RECORD(
      id                  NUMBER := okc_api.g_miss_num,
      LANGUAGE            okc_k_lines_tl.LANGUAGE%TYPE := okc_api.g_miss_char,
      source_lang         okc_k_lines_tl.source_lang%TYPE := okc_api.g_miss_char,
      sfwt_flag           okc_k_lines_tl.sfwt_flag%TYPE := okc_api.g_miss_char,
      NAME                okc_k_lines_tl.NAME%TYPE := okc_api.g_miss_char,
      comments            okc_k_lines_tl.comments%TYPE := okc_api.g_miss_char,
      item_description    okc_k_lines_tl.item_description%TYPE := okc_api.g_miss_char,
      oke_boe_description okc_k_lines_tl.oke_boe_description%TYPE := okc_api.g_miss_char,
      cognomen            okc_k_lines_tl.cognomen%TYPE := okc_api.g_miss_char,
      block23text         okc_k_lines_tl.block23text%TYPE := okc_api.g_miss_char,
      created_by          NUMBER := okc_api.g_miss_num,
      creation_date       okc_k_lines_tl.creation_date%TYPE := okc_api.g_miss_date,
      last_updated_by     NUMBER := okc_api.g_miss_num,
      last_update_date    okc_k_lines_tl.last_update_date%TYPE := okc_api.g_miss_date,
      last_update_login   NUMBER := okc_api.g_miss_num);

   g_miss_okc_k_lines_tl_rec okc_k_lines_tl_rec_type;
   TYPE okc_k_lines_tl_tbl_type IS TABLE OF okc_k_lines_tl_rec_type INDEX BY BINARY_INTEGER;

   TYPE clev_rec_type IS RECORD(
      id                       NUMBER := okc_api.g_miss_num,
      object_version_number    NUMBER := okc_api.g_miss_num,
      sfwt_flag                okc_k_lines_v.sfwt_flag%TYPE := okc_api.g_miss_char,
      chr_id                   NUMBER := okc_api.g_miss_num,
      cle_id                   NUMBER := okc_api.g_miss_num,
      cle_id_renewed           NUMBER := okc_api.g_miss_num,
      cle_id_renewed_to        NUMBER := okc_api.g_miss_num,
      lse_id                   NUMBER := okc_api.g_miss_num,
      line_number              okc_k_lines_v.line_number%TYPE := okc_api.g_miss_char,
      sts_code                 okc_k_lines_v.sts_code%TYPE := okc_api.g_miss_char,
      display_sequence         NUMBER := okc_api.g_miss_num,
      trn_code                 okc_k_lines_v.trn_code%TYPE := okc_api.g_miss_char,
      dnz_chr_id               NUMBER := okc_api.g_miss_num,
      comments                 okc_k_lines_v.comments%TYPE := okc_api.g_miss_char,
      item_description         okc_k_lines_v.item_description%TYPE := okc_api.g_miss_char,
      oke_boe_description      okc_k_lines_v.oke_boe_description%TYPE := okc_api.g_miss_char,
      cognomen                 okc_k_lines_v.cognomen%TYPE := okc_api.g_miss_char,
      hidden_ind               okc_k_lines_v.hidden_ind%TYPE := okc_api.g_miss_char,
      price_unit               NUMBER := okc_api.g_miss_num,
      price_unit_percent       NUMBER := okc_api.g_miss_num,
      price_negotiated         NUMBER := okc_api.g_miss_num,
      price_negotiated_renewed NUMBER := okc_api.g_miss_num,
      price_level_ind          okc_k_lines_v.price_level_ind%TYPE := okc_api.g_miss_char,
      invoice_line_level_ind   okc_k_lines_v.invoice_line_level_ind%TYPE := okc_api.g_miss_char,
      dpas_rating              okc_k_lines_v.dpas_rating%TYPE := okc_api.g_miss_char,
      block23text              okc_k_lines_v.block23text%TYPE := okc_api.g_miss_char,
      exception_yn             okc_k_lines_v.exception_yn%TYPE := okc_api.g_miss_char,
      template_used            okc_k_lines_v.template_used%TYPE := okc_api.g_miss_char,
      date_terminated          okc_k_lines_v.date_terminated%TYPE := okc_api.g_miss_date,
      NAME                     okc_k_lines_v.NAME%TYPE := okc_api.g_miss_char,
      start_date               okc_k_lines_v.start_date%TYPE := okc_api.g_miss_date,
      end_date                 okc_k_lines_v.end_date%TYPE := okc_api.g_miss_date,
      date_renewed             okc_k_lines_v.date_renewed%TYPE := okc_api.g_miss_date,
      upg_orig_system_ref      okc_k_lines_v.upg_orig_system_ref%TYPE := okc_api.g_miss_char,
      upg_orig_system_ref_id   NUMBER := okc_api.g_miss_num,
      orig_system_source_code  okc_k_lines_v.orig_system_source_code%TYPE := okc_api.g_miss_char,
      orig_system_id1          NUMBER := okc_api.g_miss_num,
      orig_system_reference1   okc_k_lines_v.orig_system_reference1%TYPE := okc_api.g_miss_char,
      attribute_category       okc_k_lines_v.attribute_category%TYPE := okc_api.g_miss_char,
      attribute1               okc_k_lines_v.attribute1%TYPE := okc_api.g_miss_char,
      attribute2               okc_k_lines_v.attribute2%TYPE := okc_api.g_miss_char,
      attribute3               okc_k_lines_v.attribute3%TYPE := okc_api.g_miss_char,
      attribute4               okc_k_lines_v.attribute4%TYPE := okc_api.g_miss_char,
      attribute5               okc_k_lines_v.attribute5%TYPE := okc_api.g_miss_char,
      attribute6               okc_k_lines_v.attribute6%TYPE := okc_api.g_miss_char,
      attribute7               okc_k_lines_v.attribute7%TYPE := okc_api.g_miss_char,
      attribute8               okc_k_lines_v.attribute8%TYPE := okc_api.g_miss_char,
      attribute9               okc_k_lines_v.attribute9%TYPE := okc_api.g_miss_char,
      attribute10              okc_k_lines_v.attribute10%TYPE := okc_api.g_miss_char,
      attribute11              okc_k_lines_v.attribute11%TYPE := okc_api.g_miss_char,
      attribute12              okc_k_lines_v.attribute12%TYPE := okc_api.g_miss_char,
      attribute13              okc_k_lines_v.attribute13%TYPE := okc_api.g_miss_char,
      attribute14              okc_k_lines_v.attribute14%TYPE := okc_api.g_miss_char,
      attribute15              okc_k_lines_v.attribute15%TYPE := okc_api.g_miss_char,
      created_by               NUMBER := okc_api.g_miss_num,
      creation_date            okc_k_lines_v.creation_date%TYPE := okc_api.g_miss_date,
      last_updated_by          NUMBER := okc_api.g_miss_num,
      last_update_date         okc_k_lines_v.last_update_date%TYPE := okc_api.g_miss_date,
      price_type               okc_k_lines_v.price_type%TYPE := okc_api.g_miss_char,
      currency_code            okc_k_lines_v.currency_code%TYPE := okc_api.g_miss_char,
      currency_code_renewed    okc_k_lines_v.currency_code_renewed%TYPE := okc_api.g_miss_char,
      last_update_login        NUMBER := okc_api.g_miss_num,
      old_sts_code             okc_k_lines_v.sts_code%TYPE := okc_api.g_miss_char,
      new_sts_code             okc_k_lines_v.sts_code%TYPE := okc_api.g_miss_char,
      old_ste_code             okc_statuses_v.ste_code%TYPE := okc_api.g_miss_char,
      new_ste_code             okc_statuses_v.ste_code%TYPE := okc_api.g_miss_char,
      call_action_asmblr       VARCHAR2(1) := 'Y',
      request_id               NUMBER := okc_api.g_miss_num,
      program_application_id   NUMBER := okc_api.g_miss_num,
      program_id               NUMBER := okc_api.g_miss_num,
      program_update_date      okc_k_lines_v.program_update_date%TYPE := okc_api.g_miss_date,
      price_list_id            NUMBER := okc_api.g_miss_num,
      pricing_date             okc_k_lines_v.pricing_date%TYPE := okc_api.g_miss_date,
      price_list_line_id       NUMBER := okc_api.g_miss_num,
      line_list_price          NUMBER := okc_api.g_miss_num,
      item_to_price_yn         okc_k_lines_v.item_to_price_yn%TYPE := okc_api.g_miss_char,
      price_basis_yn           okc_k_lines_v.price_basis_yn%TYPE := okc_api.g_miss_char,
      config_header_id         NUMBER := okc_api.g_miss_num,
      config_revision_number   NUMBER := okc_api.g_miss_num,
      config_complete_yn       okc_k_lines_v.config_complete_yn%TYPE := okc_api.g_miss_char,
      config_valid_yn          okc_k_lines_v.config_valid_yn%TYPE := okc_api.g_miss_char,
      config_top_model_line_id NUMBER := okc_api.g_miss_num,
      config_item_type         okc_k_lines_v.config_item_type%TYPE := okc_api.g_miss_char,
      config_item_id           NUMBER := okc_api.g_miss_num,
      service_item_yn          okc_k_lines_v.service_item_yn%TYPE := okc_api.g_miss_char,
      --new columns for price hold
      ph_pricing_type          okc_k_lines_v.ph_pricing_type%TYPE := okc_api.g_miss_char,
      ph_price_break_basis     okc_k_lines_v.ph_price_break_basis%TYPE := okc_api.g_miss_char,
      ph_min_qty               okc_k_lines_v.ph_min_qty%TYPE := okc_api.g_miss_num,
      ph_min_amt               okc_k_lines_v.ph_min_amt%TYPE := okc_api.g_miss_num,
      ph_qp_reference_id       okc_k_lines_v.ph_qp_reference_id%TYPE := okc_api.g_miss_num,
      ph_value                 okc_k_lines_v.ph_value%TYPE := okc_api.g_miss_num,
      ph_enforce_price_list_yn okc_k_lines_v.ph_enforce_price_list_yn%TYPE := okc_api.g_miss_char,
      ph_adjustment            okc_k_lines_v.ph_adjustment%TYPE := okc_api.g_miss_num,
      ph_integrated_with_qp    okc_k_lines_v.ph_integrated_with_qp%TYPE := okc_api.g_miss_char,
      
      --new columns to replace rules
      cust_acct_id           NUMBER := okc_api.g_miss_num,
      bill_to_site_use_id    NUMBER := okc_api.g_miss_num,
      inv_rule_id            NUMBER := okc_api.g_miss_num,
      line_renewal_type_code okc_k_lines_v.line_renewal_type_code%TYPE := okc_api.g_miss_char,
      ship_to_site_use_id    NUMBER := okc_api.g_miss_num,
      payment_term_id        NUMBER := okc_api.g_miss_num,
      validate_yn            VARCHAR2(1) DEFAULT 'Y', --Bug#3150149.
      --- Line level Cancellation ---
      date_cancelled okc_k_lines_v.date_cancelled%TYPE := okc_api.g_miss_date,
      --canc_reason_code       OKC_K_LINES_V.CANC_REASON_CODE%TYPE := OKC_API.G_MISS_CHAR,
      term_cancel_source okc_k_lines_v.term_cancel_source%TYPE := okc_api.g_miss_char,
      cancelled_amount   okc_k_lines_v.cancelled_amount%TYPE := okc_api.g_miss_num,
      --R12 changes added by mchoudha--
      annualized_factor        okc_k_lines_b.annualized_factor%TYPE := okc_api.g_miss_num,
      payment_instruction_type okc_k_lines_b.payment_instruction_type%TYPE := okc_api.g_miss_char);
   g_miss_clev_rec clev_rec_type;
   TYPE clev_tbl_type IS TABLE OF clev_rec_type INDEX BY BINARY_INTEGER;
   ---------------------------------------------------------------------------
   -- GLOBAL MESSAGE CONSTANTS
   ---------------------------------------------------------------------------
   g_fnd_app                    CONSTANT VARCHAR2(200) := okc_api.g_fnd_app;
   g_form_unable_to_reserve_rec CONSTANT VARCHAR2(200) := okc_api.g_form_unable_to_reserve_rec;
   g_form_record_deleted        CONSTANT VARCHAR2(200) := okc_api.g_form_record_deleted;
   g_form_record_changed        CONSTANT VARCHAR2(200) := okc_api.g_form_record_changed;
   g_record_logically_deleted   CONSTANT VARCHAR2(200) := okc_api.g_record_logically_deleted;
   g_required_value             CONSTANT VARCHAR2(200) := okc_api.g_required_value;
   g_invalid_value              CONSTANT VARCHAR2(200) := okc_api.g_invalid_value;
   g_col_name_token             CONSTANT VARCHAR2(200) := okc_api.g_col_name_token;
   g_parent_table_token         CONSTANT VARCHAR2(200) := okc_api.g_parent_table_token;
   g_child_table_token          CONSTANT VARCHAR2(200) := okc_api.g_child_table_token;
   ---------------------------------------------------------------------------
   -- GLOBAL VARIABLES
   ---------------------------------------------------------------------------
   g_pkg_name CONSTANT VARCHAR2(200) := 'OKC_CLE_PVT';
   g_app_name CONSTANT VARCHAR2(3) := okc_api.g_app_name;
   ---------------------------------------------------------------------------
   -- Procedures and Functions
   ---------------------------------------------------------------------------

   PROCEDURE qc;
   PROCEDURE change_version;
   PROCEDURE api_copy;
   PROCEDURE add_language;
   PROCEDURE insert_row(p_api_version   IN NUMBER,
                        p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                        x_return_status OUT NOCOPY VARCHAR2,
                        x_msg_count     OUT NOCOPY NUMBER,
                        x_msg_data      OUT NOCOPY VARCHAR2,
                        p_clev_rec      IN clev_rec_type,
                        x_clev_rec      OUT NOCOPY clev_rec_type);

   PROCEDURE insert_row(p_api_version   IN NUMBER,
                        p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                        x_return_status OUT NOCOPY VARCHAR2,
                        x_msg_count     OUT NOCOPY NUMBER,
                        x_msg_data      OUT NOCOPY VARCHAR2,
                        p_clev_tbl      IN clev_tbl_type,
                        x_clev_tbl      OUT NOCOPY clev_tbl_type);

   PROCEDURE lock_row(p_api_version   IN NUMBER,
                      p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                      x_return_status OUT NOCOPY VARCHAR2,
                      x_msg_count     OUT NOCOPY NUMBER,
                      x_msg_data      OUT NOCOPY VARCHAR2,
                      p_clev_rec      IN clev_rec_type);

   PROCEDURE lock_row(p_api_version   IN NUMBER,
                      p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                      x_return_status OUT NOCOPY VARCHAR2,
                      x_msg_count     OUT NOCOPY NUMBER,
                      x_msg_data      OUT NOCOPY VARCHAR2,
                      p_clev_tbl      IN clev_tbl_type);

   PROCEDURE update_row(p_api_version       IN NUMBER,
                        p_init_msg_list     IN VARCHAR2 DEFAULT okc_api.g_false,
                        x_return_status     OUT NOCOPY VARCHAR2,
                        x_msg_count         OUT NOCOPY NUMBER,
                        x_msg_data          OUT NOCOPY VARCHAR2,
                        p_restricted_update IN VARCHAR2 DEFAULT okc_api.g_false,
                        p_clev_rec          IN clev_rec_type,
                        x_clev_rec          OUT NOCOPY clev_rec_type);

   PROCEDURE update_row(p_api_version       IN NUMBER,
                        p_init_msg_list     IN VARCHAR2 DEFAULT okc_api.g_false,
                        x_return_status     OUT NOCOPY VARCHAR2,
                        x_msg_count         OUT NOCOPY NUMBER,
                        x_msg_data          OUT NOCOPY VARCHAR2,
                        p_restricted_update IN VARCHAR2 DEFAULT okc_api.g_false,
                        p_clev_tbl          IN clev_tbl_type,
                        x_clev_tbl          OUT NOCOPY clev_tbl_type);

   PROCEDURE delete_row(p_api_version   IN NUMBER,
                        p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                        x_return_status OUT NOCOPY VARCHAR2,
                        x_msg_count     OUT NOCOPY NUMBER,
                        x_msg_data      OUT NOCOPY VARCHAR2,
                        p_clev_rec      IN clev_rec_type);

   PROCEDURE delete_row(p_api_version   IN NUMBER,
                        p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                        x_return_status OUT NOCOPY VARCHAR2,
                        x_msg_count     OUT NOCOPY NUMBER,
                        x_msg_data      OUT NOCOPY VARCHAR2,
                        p_clev_tbl      IN clev_tbl_type);

   PROCEDURE force_delete_row(p_api_version   IN NUMBER,
                              p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                              x_return_status OUT NOCOPY VARCHAR2,
                              x_msg_count     OUT NOCOPY NUMBER,
                              x_msg_data      OUT NOCOPY VARCHAR2,
                              p_clev_tbl      IN clev_tbl_type);

   PROCEDURE validate_row(p_api_version   IN NUMBER,
                          p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                          x_return_status OUT NOCOPY VARCHAR2,
                          x_msg_count     OUT NOCOPY NUMBER,
                          x_msg_data      OUT NOCOPY VARCHAR2,
                          p_clev_rec      IN clev_rec_type);

   PROCEDURE validate_row(p_api_version   IN NUMBER,
                          p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                          x_return_status OUT NOCOPY VARCHAR2,
                          x_msg_count     OUT NOCOPY NUMBER,
                          x_msg_data      OUT NOCOPY VARCHAR2,
                          p_clev_tbl      IN clev_tbl_type);

   PROCEDURE insert_row_upg(x_return_status OUT NOCOPY VARCHAR2,
                            p_clev_tbl      clev_tbl_type);

   FUNCTION create_version(p_chr_id IN NUMBER, p_major_version IN NUMBER)
      RETURN VARCHAR2;

   FUNCTION restore_version(p_chr_id IN NUMBER, p_major_version IN NUMBER)
      RETURN VARCHAR2;

END xxoks_cle_pvt;
/

