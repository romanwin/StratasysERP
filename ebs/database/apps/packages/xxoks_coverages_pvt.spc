CREATE OR REPLACE PACKAGE xxoks_coverages_pvt AUTHID CURRENT_USER AS
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
--  1.0  04/12/2011  Dalit A. Raviv    add procedure apply_standard
-------------------------------------------------------------------- 

  TYPE jtf_note_rec_type IS RECORD(
    jtf_note_id        NUMBER,
    source_object_code VARCHAR2(240),
    note_status        VARCHAR2(240),
    note_type          VARCHAR2(240),
    notes              VARCHAR2(2000),
    notes_detail       VARCHAR2(32767),
    -- Modified by Jvorugan for Bug:4489214 who columns not to be populated from old contract
    /*  Created_By          NUMBER,
        LAst_Updated_By     Number,
        LAst_Update_Login   Number  */
    entered_by   NUMBER,
    entered_date DATE);
   -- End of changes for Bug:4489214

  TYPE jtf_note_tbl_type IS TABLE OF jtf_note_rec_type INDEX BY BINARY_INTEGER;
  l_notes_tbl jtf_note_tbl_type;

  TYPE ac_rec_type IS RECORD(
    svc_cle_id NUMBER,
    tmp_cle_id NUMBER,
    start_date DATE,
    end_date   DATE,
    rle_code   VARCHAR2(40));
  --   ac_rec_in ac_rec_type;
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
  g_unexpected_error           CONSTANT VARCHAR2(200) := 'OKS_UNEXP_ERROR';
  g_sqlerrm_token              CONSTANT VARCHAR2(200) := 'SQLerrm';
  g_sqlcode_token              CONSTANT VARCHAR2(200) := 'SQLcode';
  g_no_parent_record           CONSTANT VARCHAR2(200) := 'OKC_NO_PARENT_RECORD';
  g_no_update_allowed          CONSTANT VARCHAR2(200) := 'OKC_NO_UPDATE_ALLOWED';
  ------------------------------------------------------------------------------------
  -- GLOBAL EXCEPTION
  ---------------------------------------------------------------------------
  g_exception_halt_validation EXCEPTION;
  g_exception_rule_update EXCEPTION;
  g_exception_brs_update EXCEPTION;
  g_no_update_allowed_exception EXCEPTION;
  -- GLOBAL VARIABLES
  ---------------------------------------------------------------------------
  g_pkg_name CONSTANT VARCHAR2(200) := 'OKS_COVERAGES_PVT';
  g_app_name CONSTANT VARCHAR2(3) := okc_api.g_app_name;
  ---------------------------------------------------------------------------

  g_debug_enabled VARCHAR2(1) := nvl(fnd_profile.VALUE('AFLOG_ENABLED'),
                                    'N');

  PROCEDURE validate_svc_cle_id(p_ac_rec        IN ac_rec_type,
                               x_return_status OUT NOCOPY VARCHAR2);
  PROCEDURE validate_tmp_cle_id(p_ac_rec        IN ac_rec_type,
                               x_template_yn   OUT NOCOPY VARCHAR2,
                               x_return_status OUT NOCOPY VARCHAR2);
  PROCEDURE validate_line_id(p_line_id       IN NUMBER,
                            x_return_status OUT NOCOPY VARCHAR2);
  PROCEDURE create_actual_coverage(p_api_version        IN NUMBER,
                                  p_init_msg_list      IN VARCHAR2 DEFAULT okc_api.g_false,
                                  x_return_status      OUT NOCOPY VARCHAR2,
                                  x_msg_count          OUT NOCOPY NUMBER,
                                  x_msg_data           OUT NOCOPY VARCHAR2,
                                  p_ac_rec_in          IN ac_rec_type,
                                  p_restricted_update  IN VARCHAR2 DEFAULT 'F',
                                  x_actual_coverage_id IN OUT NUMBER);

  PROCEDURE undo_header(p_api_version   IN NUMBER,
                       p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                       x_return_status OUT NOCOPY VARCHAR2,
                       x_msg_count     OUT NOCOPY NUMBER,
                       x_msg_data      OUT NOCOPY VARCHAR2,
                       p_header_id     IN NUMBER);
  PROCEDURE undo_line(p_api_version   IN NUMBER,
                     p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                     x_return_status OUT NOCOPY VARCHAR2,
                     x_msg_count     OUT NOCOPY NUMBER,
                     x_msg_data      OUT NOCOPY VARCHAR2,
                     p_line_id       IN NUMBER);

  /* New one with validate status  */
  PROCEDURE undo_line(p_api_version     IN NUMBER,
                     p_init_msg_list   IN VARCHAR2 DEFAULT okc_api.g_false,
                     p_validate_status IN VARCHAR2 DEFAULT 'N',
                     x_return_status   OUT NOCOPY VARCHAR2,
                     x_msg_count       OUT NOCOPY NUMBER,
                     x_msg_data        OUT NOCOPY VARCHAR2,
                     p_line_id         IN NUMBER);

  PROCEDURE undo_events(p_kline_id      IN NUMBER,
                       x_return_status OUT NOCOPY VARCHAR2,
                       x_msg_data      OUT NOCOPY VARCHAR2);

  PROCEDURE undo_counters(p_kline_id      IN NUMBER,
                         x_return_status OUT NOCOPY VARCHAR2,
                         x_msg_data      OUT NOCOPY VARCHAR2);
  PROCEDURE update_coverage_effectivity(p_api_version     IN NUMBER,
                                       p_init_msg_list   IN VARCHAR2 DEFAULT okc_api.g_false,
                                       x_return_status   OUT NOCOPY VARCHAR2,
                                       x_msg_count       OUT NOCOPY NUMBER,
                                       x_msg_data        OUT NOCOPY VARCHAR2,
                                       p_service_line_id IN NUMBER,
                                       p_new_start_date  IN DATE,
                                       p_new_end_date    IN DATE);

  PROCEDURE init_clev(p_clev_tbl_in_out IN OUT NOCOPY okc_contract_pub.clev_tbl_type);
  PROCEDURE init_ctcv(p_ctcv_tbl_in_out IN OUT NOCOPY okc_contract_party_pub.ctcv_tbl_type);
  PROCEDURE init_cimv(p_cimv_tbl_in_out IN OUT NOCOPY okc_contract_item_pub.cimv_tbl_type);

  /*
  --PROCEDURE Init_RGPV(P_RGPV_tbl_in_out IN OUT NOCOPY okc_Rule_pub.Rgpv_tbl_type);
  --PROCEDURE Init_RULV(P_RULV_tbl_in_out IN OUT NOCOPY okc_Rule_Pub.Rulv_tbl_type);
  --PROCEDURE Init_ATEV(P_ATEV_tbl_in_Out IN OUT NOCOPY okc_article_pub.Atev_tbl_type);
  --PROCEDURE Init_RILV(P_RILV_tbl_in_Out IN OUT NOCOPY okc_rule_pub.Rilv_tbl_type);
  PROCEDURE Init_TGDV(P_TGDV_EXT_tbl_In_Out IN OUT NOCOPY okc_time_pub.TGDV_Ext_tbl_TYPE);
  PROCEDURE Init_IGSV(P_IGSV_EXT_tbl_In_Out IN OUT NOCOPY okc_time_pub.Igsv_Ext_tbl_TYPE);
  PROCEDURE Init_ISEV(P_ISEV_EXT_tbl_In_Out IN OUT NOCOPY okc_time_pub.Isev_Ext_tbl_TYPE);
  --PROCEDURE Init_CTIV(P_CTIV_tbl_In_Out IN OUT NOCOPY okc_rule_pub.Ctiv_tbl_type);
  */

  PROCEDURE init_bill_rate_line(x_bill_rate_tbl OUT NOCOPY oks_brs_pvt.oksbillrateschedulesvtbltype);

  PROCEDURE create_adjusted_coverage(p_api_version             IN NUMBER,
                                    p_init_msg_list           IN VARCHAR2 DEFAULT okc_api.g_false,
                                    x_return_status           OUT NOCOPY VARCHAR2,
                                    x_msg_count               OUT NOCOPY NUMBER,
                                    x_msg_data                OUT NOCOPY VARCHAR2,
                                    p_source_contract_line_id IN NUMBER,
                                    p_target_contract_line_id IN NUMBER,
                                    x_actual_coverage_id      OUT NOCOPY NUMBER);

  TYPE res_rec_type IS RECORD(
    bp_id          okc_k_items_v.object1_id1%TYPE,
    cro_code       okc_contacts_v.cro_code%TYPE,
    object1_id1    okc_contacts_v.object1_id1%TYPE,
    resource_class okc_contacts_v.resource_class%TYPE);

  TYPE res_tbl_type IS TABLE OF res_rec_type INDEX BY BINARY_INTEGER;

  x_source_res_tbl_type res_tbl_type;
  x_target_res_tbl_type res_tbl_type;

  TYPE bp_rec_type IS RECORD(
    object1_id1 okc_k_items_v.object1_id1%TYPE,
    bp_line_id  okc_k_lines_v.id%TYPE,
    start_date  DATE,
    end_date    DATE);

  TYPE bp_tbl_type IS TABLE OF bp_rec_type INDEX BY BINARY_INTEGER;

  x_source_bp_tbl_type bp_tbl_type;
  x_target_bp_tbl_type bp_tbl_type;

  TYPE bp_line_rec_type IS RECORD(
    bp_id          okc_k_items_v.object1_id1%TYPE,
    src_bp_line_id okc_k_lines_v.id%TYPE,
    tgt_bp_line_id okc_k_lines_v.id%TYPE);

  TYPE bp_line_tbl_type IS TABLE OF bp_line_rec_type INDEX BY BINARY_INTEGER;

  l_bp_tbl bp_line_tbl_type;

  TYPE cover_time_rec_type IS RECORD(
    object1_id1  okc_k_items_v.object1_id1%TYPE,
    start_day    okc_timevalues_v.day_of_week%TYPE,
    start_hour   okc_timevalues_v.hour%TYPE,
    start_minute okc_timevalues_v.minute%TYPE,
    end_day      okc_timevalues_v.day_of_week%TYPE,
    end_hour     okc_timevalues_v.hour%TYPE,
    end_minute   okc_timevalues_v.minute%TYPE);

  TYPE cover_time_tbl_type IS TABLE OF cover_time_rec_type INDEX BY BINARY_INTEGER;

  x_source_cover_tbl cover_time_tbl_type;
  x_target_cover_tbl cover_time_tbl_type;

  TYPE brs_rec_type IS RECORD(
    start_hour              oks_billrate_schedules.start_hour%TYPE,
    start_minute            oks_billrate_schedules.start_minute%TYPE,
    end_hour                oks_billrate_schedules.end_minute%TYPE,
    end_minute              oks_billrate_schedules.end_minute%TYPE,
    monday_flag             oks_billrate_schedules.monday_flag%TYPE,
    tuesday_flag            oks_billrate_schedules.tuesday_flag%TYPE,
    wednesday_flag          oks_billrate_schedules.wednesday_flag%TYPE,
    thursday_flag           oks_billrate_schedules.thursday_flag%TYPE,
    friday_flag             oks_billrate_schedules.friday_flag%TYPE,
    saturday_flag           oks_billrate_schedules.saturday_flag%TYPE,
    sunday_flag             oks_billrate_schedules.sunday_flag%TYPE,
    object1_id1             oks_billrate_schedules.object1_id1%TYPE,
    object1_id2             oks_billrate_schedules.object1_id2%TYPE,
    jtot_object1_code       oks_billrate_schedules.jtot_object1_code%TYPE,
    bill_rate_code          oks_billrate_schedules.bill_rate_code%TYPE,
    flat_rate               oks_billrate_schedules.flat_rate%TYPE,
    uom                     oks_billrate_schedules.uom%TYPE,
    holiday_yn              oks_billrate_schedules.holiday_yn%TYPE,
    percent_over_list_price oks_billrate_schedules.percent_over_list_price%TYPE);

  TYPE brs_tbl_type IS TABLE OF brs_rec_type INDEX BY BINARY_INTEGER;

  x_source_brs_tbl brs_tbl_type;
  x_target_brs_tbl brs_tbl_type;

  TYPE billrate_day_overlap_type IS RECORD(
    monday_overlap    VARCHAR2(1),
    tuesday_overlap   VARCHAR2(1),
    wednesday_overlap VARCHAR2(1),
    thursday_overlap  VARCHAR2(1),
    friday_overlap    VARCHAR2(1),
    saturday_overlap  VARCHAR2(1),
    sunday_overlap    VARCHAR2(1));

  PROCEDURE validate_billrate_schedule(p_billtype_line_id IN NUMBER,
                                      p_holiday_yn       IN VARCHAR2,
                                      x_days_overlap     OUT NOCOPY billrate_day_overlap_type,
                                      x_return_status    OUT NOCOPY VARCHAR2);

  PROCEDURE oks_migrate_billrates(p_api_version   IN NUMBER,
                                 p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                                 x_return_status OUT NOCOPY VARCHAR2,
                                 x_msg_count     OUT NOCOPY NUMBER,
                                 x_msg_data      OUT NOCOPY VARCHAR2);

  PROCEDURE init_contract_line(x_clev_tbl OUT NOCOPY okc_contract_pub.clev_tbl_type);

  TYPE time_labor_rec IS RECORD(
    start_time        DATE,
    end_time          DATE,
    monday_flag       VARCHAR2(1),
    tuesday_flag      VARCHAR2(1),
    wednesday_flag    VARCHAR2(1),
    thursday_flag     VARCHAR2(1),
    friday_flag       VARCHAR2(1),
    saturday_flag     VARCHAR2(1),
    sunday_flag       VARCHAR2(1),
    holiday_flag      VARCHAR2(1),
    inventory_item_id NUMBER,
    labor_code        VARCHAR2(30));

  TYPE time_labor_tbl IS TABLE OF time_labor_rec INDEX BY BINARY_INTEGER;

  PROCEDURE oks_billrate_mapping(p_api_version         IN NUMBER,
                                p_init_msg_list       IN VARCHAR2 DEFAULT okc_api.g_false,
                                p_business_process_id IN NUMBER,
                                p_time_labor_tbl_in   IN time_labor_tbl,
                                x_return_status       OUT NOCOPY VARCHAR2,
                                x_msg_count           OUT NOCOPY NUMBER,
                                x_msg_data            OUT NOCOPY VARCHAR2);

  PROCEDURE copy_coverage(p_api_version      IN NUMBER,
                         p_init_msg_list    IN VARCHAR2 DEFAULT okc_api.g_false,
                         x_return_status    OUT NOCOPY VARCHAR2,
                         x_msg_count        OUT NOCOPY NUMBER,
                         x_msg_data         OUT NOCOPY VARCHAR2,
                         p_contract_line_id IN NUMBER);

  PROCEDURE validate_covertime(p_tze_line_id   IN NUMBER,
                              x_days_overlap  OUT NOCOPY oks_coverages_pvt.billrate_day_overlap_type,
                              x_return_status OUT NOCOPY VARCHAR2);

  PROCEDURE init_oks_k_line(x_klnv_tbl OUT NOCOPY oks_kln_pvt.klnv_tbl_type);
  PROCEDURE init_oks_timezone_line(x_timezone_tbl OUT NOCOPY oks_ctz_pvt.okscoveragetimezonesvtbltype);
  PROCEDURE init_oks_cover_time_line(x_cover_time_tbl OUT NOCOPY oks_cvt_pvt.oks_coverage_times_v_tbl_type);
  PROCEDURE init_oks_act_type(x_act_time_tbl OUT NOCOPY oks_act_pvt.oksactiontimetypesvtbltype);
  PROCEDURE init_oks_act_time(x_act_type_tbl OUT NOCOPY oks_acm_pvt.oks_action_times_v_tbl_type);

  PROCEDURE migrate_primary_resources(p_api_version   IN NUMBER,
                                     p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                                     x_return_status OUT NOCOPY VARCHAR2,
                                     x_msg_count     OUT NOCOPY NUMBER,
                                     x_msg_data      OUT NOCOPY VARCHAR2);

  --------------------CHECK COVERAGE MATCH------------------------------------------
  TYPE oks_bp_rec IS RECORD(
    price_list_id          okc_k_lines_b.price_list_id%TYPE,
    object1_id1            okc_k_items.object1_id1%TYPE,
    discount_list          oks_k_lines_b.discount_list%TYPE,
    offset_duration        oks_k_lines_b.offset_duration%TYPE,
    offset_period          oks_k_lines_b.offset_period%TYPE,
    allow_bt_discount      oks_k_lines_b.allow_bt_discount%TYPE,
    apply_default_timezone oks_k_lines_b.apply_default_timezone%TYPE);

  TYPE oks_bp_tbl IS TABLE OF oks_bp_rec INDEX BY BINARY_INTEGER;

  x_source_bp_tbl oks_bp_tbl;
  x_target_bp_tbl oks_bp_tbl;

  TYPE bp_cover_time_rec IS RECORD(
    object1_id1  okc_k_items.object1_id1%TYPE,
    timezone_id  oks_coverage_timezones.timezone_id%TYPE,
    default_yn   oks_coverage_timezones.default_yn%TYPE,
    start_hour   oks_coverage_times.start_hour%TYPE,
    start_minute oks_coverage_times.start_minute%TYPE,
    end_hour     oks_coverage_times.end_hour%TYPE,
    end_minute   oks_coverage_times.end_minute%TYPE,
    monday_yn    oks_coverage_times.monday_yn%TYPE,
    tuesday_yn   oks_coverage_times.tuesday_yn%TYPE,
    wednesday_yn oks_coverage_times.wednesday_yn%TYPE,
    thursday_yn  oks_coverage_times.thursday_yn%TYPE,
    friday_yn    oks_coverage_times.friday_yn%TYPE,
    saturday_yn  oks_coverage_times.saturday_yn%TYPE,
    sunday_yn    oks_coverage_times.sunday_yn%TYPE);

  TYPE bp_cover_time_tbl IS TABLE OF bp_cover_time_rec INDEX BY BINARY_INTEGER;

  x_source_bp_cover_time_tbl bp_cover_time_tbl;
  x_target_bp_cover_time_tbl bp_cover_time_tbl;

  TYPE react_time_rec IS RECORD(
    incident_severity_id oks_k_lines_v.incident_severity_id%TYPE,
    pdf_id               oks_k_lines_v.pdf_id%TYPE,
    work_thru_yn         oks_k_lines_v.work_thru_yn%TYPE,
    react_active_yn      oks_k_lines_v.react_active_yn%TYPE,
    react_time_name      oks_k_lines_v.react_time_name%TYPE,
    action_type_code     oks_action_time_types.action_type_code%TYPE,
    uom_code             oks_action_times.uom_code%TYPE,
    sun_duration         oks_action_times.sun_duration%TYPE,
    mon_duration         oks_action_times.mon_duration%TYPE,
    tue_duration         oks_action_times.tue_duration%TYPE,
    wed_duration         oks_action_times.wed_duration%TYPE,
    thu_duration         oks_action_times.thu_duration%TYPE,
    fri_duration         oks_action_times.fri_duration%TYPE,
    sat_duration         oks_action_times.sat_duration%TYPE);

  TYPE react_time_tbl IS TABLE OF react_time_rec INDEX BY BINARY_INTEGER;

  x_source_react_time_tbl react_time_tbl;
  x_target_react_time_tbl react_time_tbl;

  TYPE bill_type_rec IS RECORD(
    object1_id1       okc_k_items_v.object1_id1%TYPE,
    bill_type_line_id NUMBER,
    billing_type      VARCHAR2(30),
    discount_amount   oks_k_lines_b.discount_amount%TYPE,
    discount_percent  oks_k_lines_b.discount_percent%TYPE);

  TYPE bill_type_tbl IS TABLE OF bill_type_rec INDEX BY BINARY_INTEGER;

  x_source_bill_tbl bill_type_tbl;
  x_target_bill_tbl bill_type_tbl;

  PROCEDURE check_coverage_match(p_api_version             IN NUMBER,
                                p_init_msg_list           IN VARCHAR2 DEFAULT okc_api.g_false,
                                x_return_status           OUT NOCOPY VARCHAR2,
                                x_msg_count               OUT NOCOPY NUMBER,
                                x_msg_data                OUT NOCOPY VARCHAR2,
                                p_source_contract_line_id IN NUMBER,
                                p_target_contract_line_id IN NUMBER,
                                x_coverage_match          OUT NOCOPY VARCHAR2);

  -- The Following API checks for the Business Procees Line Id IF Time Zone Exists.Returns 'Y' If exists else 'N'
  PROCEDURE check_timezone_exists(p_api_version     IN NUMBER,
                                 p_init_msg_list   IN VARCHAR2 DEFAULT okc_api.g_false,
                                 x_return_status   OUT NOCOPY VARCHAR2,
                                 x_msg_count       OUT NOCOPY NUMBER,
                                 x_msg_data        OUT NOCOPY VARCHAR2,
                                 p_bp_line_id      IN NUMBER,
                                 p_timezone_id     IN NUMBER,
                                 x_timezone_exists OUT NOCOPY VARCHAR2);

  PROCEDURE version_coverage(p_api_version   IN NUMBER,
                            p_init_msg_list IN VARCHAR2,
                            x_return_status OUT NOCOPY VARCHAR2,
                            x_msg_count     OUT NOCOPY NUMBER,
                            x_msg_data      OUT NOCOPY VARCHAR2,
                            p_chr_id        IN NUMBER,
                            p_major_version IN NUMBER);

  PROCEDURE restore_coverage(p_api_version   IN NUMBER,
                            p_init_msg_list IN VARCHAR2,
                            x_return_status OUT NOCOPY VARCHAR2,
                            x_msg_count     OUT NOCOPY NUMBER,
                            x_msg_data      OUT NOCOPY VARCHAR2,
                            p_chr_id        IN NUMBER);

  PROCEDURE delete_history( p_api_version   IN NUMBER,
                            p_init_msg_list IN VARCHAR2,
                            x_return_status OUT NOCOPY VARCHAR2,
                            x_msg_count     OUT NOCOPY NUMBER,
                            x_msg_data      OUT NOCOPY VARCHAR2,
                            p_chr_id        IN NUMBER);

  PROCEDURE delete_saved_version( p_api_version   IN NUMBER,
                                  p_init_msg_list IN VARCHAR2,
                                  x_return_status OUT NOCOPY VARCHAR2,
                                  x_msg_count     OUT NOCOPY NUMBER,
                                  x_msg_data      OUT NOCOPY VARCHAR2,
                                  p_chr_id        IN NUMBER);

  PROCEDURE copy_k_hdr_notes( p_api_version   IN NUMBER,
                              p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                              p_chr_id        IN NUMBER,
                              x_return_status OUT NOCOPY VARCHAR2,
                              x_msg_count     OUT NOCOPY NUMBER,
                              x_msg_data      OUT NOCOPY VARCHAR2);

  PROCEDURE update_dnz_chr_id(p_coverage_id IN NUMBER,
                              p_dnz_chr_id  IN NUMBER);

  PROCEDURE create_k_coverage_ext( p_api_version   IN NUMBER,
                                   p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                                   p_src_line_id   IN NUMBER,
                                   p_tgt_line_id   IN NUMBER,
                                   x_return_status OUT NOCOPY VARCHAR2,
                                   x_msg_count     OUT NOCOPY NUMBER,
                                   x_msg_data      OUT NOCOPY VARCHAR2);

  PROCEDURE copy_notes( p_api_version   IN NUMBER,
                        p_init_msg_list IN VARCHAR2 DEFAULT okc_api.g_false,
                        p_line_id       IN NUMBER,
                        x_return_status OUT NOCOPY VARCHAR2,
                        x_msg_count     OUT NOCOPY NUMBER,
                        x_msg_data      OUT NOCOPY VARCHAR2);
  --New procedure for copy coverage functionality
  PROCEDURE copy_standard_coverage( p_api_version       IN NUMBER,
                                    p_init_msg_list     IN VARCHAR2 DEFAULT okc_api.g_false,
                                    x_return_status     OUT NOCOPY VARCHAR2,
                                    x_msg_count         OUT NOCOPY NUMBER,
                                    x_msg_data          OUT NOCOPY VARCHAR2,
                                    p_old_coverage_id   IN NUMBER,
                                    p_new_coverage_name IN VARCHAR2,
                                    x_new_coverage_id   OUT NOCOPY NUMBER);

  PROCEDURE delete_coverage( p_api_version     IN NUMBER,
                             p_init_msg_list   IN VARCHAR2 DEFAULT okc_api.g_false,
                             x_return_status   OUT NOCOPY VARCHAR2,
                             x_msg_count       OUT NOCOPY NUMBER,
                             x_msg_data        OUT NOCOPY VARCHAR2,
                             p_service_line_id IN NUMBER);
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
                            retcode    out varchar2 );                             

END xxoks_coverages_pvt;
/
