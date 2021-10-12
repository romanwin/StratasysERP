CREATE OR REPLACE VIEW PO_HEADERS_XML (
  type_lookup_code, 
  segment1, 
  revision_num, 
  print_count, 
  creation_date, 
  creation_date_jpn, 
  printed_date, 
  revised_date, 
  revised_date_jpn, 
  start_date, 
  end_date, 
  start_date_jpn, 
  end_date_jpn, 
  note_to_vendor, 
  document_buyer_first_name, 
  document_buyer_last_name, 
  document_buyer_first_name_jpn, 
  document_buyer_last_name_jpn, 
  document_buyer_title, 
  document_buyer_agent_id, 
  archive_buyer_agent_id, 
  archive_buyer_first_name, 
  archive_buyer_last_name, 
  archive_buyer_first_name_jpn, 
  archive_buyer_last_name_jpn, 
  archive_buyer_title, 
  amount_agreed, 
  cancel_flag, 
  confirming_order_flag, 
  acceptance_required_flag, 
  acceptance_due_date, 
  orig_currency_code, 
  orig_currency_name, 
  rate, 
  ship_via, 
  fob, 
  freight_terms, 
  payment_terms, 
  payment_terms_jpn, 
  customer_num, 
  vendor_num, 
  vendor_name, 
  vendor_name_jpn, 
  vendor_address_line1, 
  vendor_address_line2, 
  vendor_address_line3, 
  vendor_city, 
  vendor_state, 
  vendor_postal_code, 
  vendor_country, 
  vendor_phone, 
  vendor_contact_first_name,
  vendor_contact_last_name, 
  vendor_contact_title, 
  vendor_contact_phone, 
  ship_to_location_id, 
  ship_to_location_name, 
  ship_to_address_line1, 
  ship_to_address_line2, 
  ship_to_address_line3, 
  ship_to_address_line4, 
  ship_to_address_info, 
  ship_to_country, 
  ship_to_postal_code, 
  ship_to_city, 
  bill_to_location_id, 
  bill_to_location_name, 
  bill_to_address_line1, 
  bill_to_address_line2, 
  bill_to_address_line3, 
  bill_to_address_line4, 
  bill_to_address_info, 
  bill_to_country, 
  bill_to_postal_code, 
  bill_to_city, 
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
  vendor_site_id, 
  po_header_id, 
  approved_flag, 
  language, 
  vendor_id, 
  closed_code, 
  ussgl_transaction_code, 
  government_context, 
  request_id, 
  program_application_id, 
  program_id, 
  program_update_date, 
  org_id, 
  comments, 
  reply_date, 
  reply_method_lookup_code, 
  rfq_close_date, 
  quote_type_lookup_code, 
  quotation_class_code,
  quote_warning_delay_unit, 
  quote_warning_delay, 
  quote_vendor_quote_number, 
  closed_date, 
  user_hold_flag, 
  approval_required_flag, 
  firm_status_lookup_code, 
  firm_date, 
  frozen_flag, 
  edi_processed_flag, 
  edi_processed_status, 
  attribute_category, 
  created_by, 
  vendor_contact_id, 
  terms_id, 
  fob_lookup_code, 
  freight_terms_lookup_code, 
  status_lookup_code, 
  rate_type, 
  rate_date, 
  from_header_id, 
  from_type_lookup_code, 
  authorization_status, 
  approved_date, 
  amount_limit, 
  min_release_amount, 
  note_to_authorizer, 
  note_to_receiver, 
  vendor_order_num, 
  last_update_date, 
  last_updated_by, 
  summary_flag, 
  enabled_flag, 
  segment2, 
  segment3, 
  segment4, 
  segment5, 
  start_date_active, 
  end_date_active, 
  last_update_login, 
  supply_agreement_flag, 
  global_attribute_category, 
  global_attribute1, 
  global_attribute2, 
  global_attribute3, 
  global_attribute4, 
  global_attribute5, 
  global_attribute6, 
  global_attribute7, 
  global_attribute8, 
  global_attribute9, 
  global_attribute10, 
  global_attribute11, 
  global_attribute12, 
  global_attribute13,
  global_attribute14, 
  global_attribute15, 
  global_attribute16, 
  global_attribute17, 
  global_attribute18, 
  global_attribute19, 
  global_attribute20, 
  interface_source_code, 
  reference_num, 
  wf_item_type, 
  wf_item_key, 
  pcard_id, 
  price_update_tolerance, 
  mrc_rate_type, 
  mrc_rate_date, 
  mrc_rate, 
  pay_on_code, 
  xml_flag, 
  xml_send_date, 
  xml_change_send_date, 
  global_agreement_flag, 
  consigned_consumption_flag, 
  cbc_accounting_date, 
  consume_req_demand_flag, 
  change_requested_by, 
  shipping_control, 
  conterms_exist_flag, 
  conterms_articles_upd_date, 
  conterms_deliv_upd_date, 
  pending_signature_flag, 
  ou_name, 
  ou_addr1, 
  ou_addr2,
  ou_addr3, 
  ou_town_city, 
  ou_region2, 
  ou_postalcode, 
  ou_country, 
  buyer_location_id, 
  buyer_address_line1, 
  buyer_address_line2, 
  buyer_address_line3, 
  buyer_address_line4, 
  buyer_city_state_zip, 
  buyer_contact_phone, 
  buyer_contact_email, 
  buyer_contact_fax, 
  vendor_fax, 
  vendor_email, 
  total_amount, 
  buyer_country, 
  vendor_address_line4, 
  vendor_area_code, 
  vendor_contact_area_code, 
  le_name, 
  le_addr1,
  le_addr2, 
  le_addr3, 
  le_town_city, 
  le_stae_province, 
  le_postalcode, 
  le_country, 
  cancel_date, 
  change_summary, 
  document_creation_method, 
  encumbrance_required_flag, 
  style_display_name, 
  rate_currency, 
  base_rate, 
  base_date, 
  approver_full_name, 
  approver_job_desc1, 
  approver_job_desc2, 
  approver_company, 
  approver_sign, 
  po_status, 
  logo_url, 
  operating_unit, 
  legal_entity_id, 
  entity_name, 
  party_id, 
  party_number, 
  legal_entity_identifier, 
  last_update_date2, 
  location_id, 
  address_line_1, 
  address_line_2, 
  address_line_3, 
  town_or_city, 
  postal_code, 
  country, 
  country_name, 
  phone_number, 
  fax_number, 
  email_address, 
  url, 
  carrier_name, 
  person_last_name, 
  ca_phone_number, 
  ca_fax_number, 
  currency_code
)
AS
  SELECT
    --------------------------------------------------------------------
    --  name:            PO_HEADERS_XML
    --  create by:
    --  Revision:        1.0
    --  creation date:   xx/xx/2009
    --------------------------------------------------------------------
    --  purpose :
    --------------------------------------------------------------------
    --  ver  date        name              desc
    --  1.0  xx/xx/2009  XXX               initial build
    --  1.1  06/12/2009  Dalit A. Raviv    correct the source of vendor_fax.
    --                                     if vendor site do not have fax bring vendor fax
    --  1.2  05/01/2010  Dalit A. Raviv    the Order date and the Revision date that appear on the PO format,
    --                                     should show the date when the PO/revision has been approved, not the creation date.
    -- 1.3  17.11.2010   yuval             AMOUNT_AGREED : conver amount agreed to linkage currency
    -- 1.4  27.11.11     yuval tal         rfr modificarions cr 347
    -- 1.5   05.11.12    yuval tal         CR512 change source of creation_date and revised_date
    -- 1.6  23.12.12     yuval tal         rep01:cr629 PO Communication report - print current buyer name for ver >0
    -- 1.7  21.05.13     Vitaly            cr763:creation_date_jpn,revised_date_jpn,start_date_jpn,end_date_jpn,
    ---                                          payment_terms_jpn, vendor_name_jpn added
    ---                                          document_buyer_first_name_jpn,document_buyer_last_name_jpn added
    ---                                          archive_buyer_first_name_jpn, archive_buyer_last_name_jpn added
    ---                                          ship_to_postal_code, ship_to_city, bill_to_postal_code, bill_to_city added
    ---                                          len.entity_name field logic was changed
    -- 1.8  11.06.13     yuval tal         bugfix 821 add logic to linkage  add release num parameter
    -- 1.9  06.01.15     mmazanet          CHG0034098 Fix for Org Unit issue
    --                                      Removed join clause AND opu.organization_id = fnd_profile.VALUE('ORG_ID')
    --                                      from len inline view.
    --------------------------------------------------------------------
    ph.type_lookup_code,
    ph.segment1
    ||DECODE (ph.attribute2,NULL,NULL,'N/A',NULL,'-'
    ||xxobjt_general_utils_pkg.get_valueset_desc ('XX_RFR_S_O',ph.attribute2) ) segment1, --1.4
    ph.revision_num,
    ph.print_count,
    --    to_char(nvl(ph.approved_date,ph.creation_date), 'DD-MON-YYYY HH24:MI:SS') creation_date,
    TO_CHAR(NVL(xxpo_utils_pkg.get_first_approve_date(ph.po_header_id,ph.type_lookup_code),ph.creation_date), 'DD-MON-YYYY HH24:MI:SS') creation_date,
    TO_CHAR(NVL(xxpo_utils_pkg.get_first_approve_date(ph.po_header_id,ph.type_lookup_code),ph.creation_date), 'YYYY/MM/DD') creation_date_jpn,
    ph.printed_date,
    --  to_char(ph.revised_date, 'DD-MON-YYYY HH24:MI:SS') revised_date,
    TO_CHAR(NVL(ph.approved_date,ph.creation_date), 'DD-MON-YYYY HH24:MI:SS') revised_date,
    TO_CHAR(NVL(ph.approved_date,ph.creation_date), 'YYYY/MM/DD') revised_date_jpn,
    TO_CHAR(ph.start_date, 'DD-MON-YYYY HH24:MI:SS') start_date,
    TO_CHAR(ph.end_date, 'DD-MON-YYYY HH24:MI:SS') end_date,
    TO_CHAR(ph.start_date, 'YYYY/MM/DD') start_date_jpn,
    TO_CHAR(ph.end_date, 'YYYY/MM/DD') end_date_jpn,
    ph.note_to_vendor,
    hre.first_name document_buyer_first_name,
    hre.last_name document_buyer_last_name,
    NVL(hre.attribute1,hre.first_name) document_buyer_first_name_jpn,
    ---- nvl(hre.attribute2,hre.last_name)||' ??'  document_buyer_last_name_jpn,
    NVL(hre.attribute2,hre.last_name) document_buyer_last_name_jpn,
    hre.title document_buyer_title,
    ph.agent_id document_buyer_agent_id,
    DECODE(NVL(ph.revision_num, 0), 0, NULL, po_communication_pvt.getarcbuyeragentid(ph.po_header_id)) archive_buyer_agent_id,
    /*decode(nvl(ph.revision_num, 0),
    0,
    NULL,
    po_communication_pvt.getarcbuyerfname())*/
    hre.first_name archive_buyer_first_name,
    /* decode(nvl(ph.revision_num, 0),
    0,
    NULL,
    po_communication_pvt.getarcbuyerlname())*/
    hre.last_name archive_buyer_last_name,
    NVL(hre.attribute1,hre.first_name) archive_buyer_first_name_jpn,
    ----nvl(hre.attribute2,hre.last_name)||' ??'   archive_buyer_last_name_jpn,
    NVL(hre.attribute2,hre.last_name) archive_buyer_last_name_jpn,
    /* decode(nvl(ph.revision_num, 0),
    0,
    NULL,
    po_communication_pvt.getarcbuyertitle())*/
    hre.title archive_buyer_title,
    TO_CHAR((xxpo_communication_report_pkg.get_converted_amount(NVL(xxpo_utils_pkg.get_blanket_total_amt(ph.po_header_id), 0),ph.segment1,0)) , po_communication_pvt.getformatmask) amount_agreed, -- yuval 18.11.10
    ph.cancel_flag,
    ph.confirming_order_flag,
    NVL(ph.acceptance_required_flag, 'N'),
    TO_CHAR(ph.acceptance_due_date, 'DD-MON-YYYY HH24:MI:SS') acceptance_due_date,
    fcc.currency_code orig_currency_code,
    fcc.NAME orig_currency_name,
    TO_CHAR(ph.rate, po_communication_pvt.getformatmask) rate,
    NVL(ofc.freight_code_tl, ph.ship_via_lookup_code) ship_via,
    plc1.meaning fob,
    plc2.meaning freight_terms,
    t.NAME payment_terms,
    NVL(xxpo_communication_report_pkg.get_ap_term_name_tl(ph.terms_id, ph.org_id),t.NAME) payment_terms_jpn,
    NVL(pvs.customer_num, vn.customer_num) customer_num,
    vn.segment1 vendor_num,
    vn.vendor_name,
    NVL(vn.vendor_name_alt,vn.vendor_name) vendor_name_jpn,
    pvs.address_line1 vendor_address_line1,
    pvs.address_line2 vendor_address_line2,
    pvs.address_line3 vendor_address_line3,
    pvs.city vendor_city,
    DECODE(pvs.state, NULL, DECODE(pvs.province, NULL, pvs.county, pvs.province), pvs.state) vendor_state,
    pvs.zip vendor_postal_code,
    fte3.territory_short_name vendor_country,
    pvs.phone vendor_phone,
    pvc.first_name vendor_contact_first_name,
    pvc.last_name vendor_contact_last_name,
    plc4.meaning vendor_contact_title,
    pvc.phone vendor_contact_phone,
    DECODE(NVL(ph.ship_to_location_id, -1), -1, NULL, po_communication_pvt.getlocationinfo(ph.ship_to_location_id)) ship_to_location_id,
    DECODE(NVL(ph.ship_to_location_id, -1), -1, NULL, po_communication_pvt.getlocationname()) ship_to_location_name,
    DECODE(NVL(ph.ship_to_location_id, -1), -1, NULL, po_communication_pvt.getaddressline1()) ship_to_address_line1,
    DECODE(NVL(ph.ship_to_location_id, -1), -1, NULL, po_communication_pvt.getaddressline2()) ship_to_address_line2,
    DECODE(NVL(ph.ship_to_location_id, -1), -1, NULL, po_communication_pvt.getaddressline3()) ship_to_address_line3,
    DECODE(NVL(ph.ship_to_location_id, -1), -1, NULL, po_communication_pvt.getaddressline4()) ship_to_address_line4,
    DECODE(NVL(ph.ship_to_location_id, -1), -1, NULL, po_communication_pvt.getaddressinfo()) ship_to_address_info,
    DECODE(NVL(ph.ship_to_location_id, -1), -1, NULL, po_communication_pvt.getterritoryshortname()) ship_to_country,
    DECODE(NVL(ph.ship_to_location_id, -1), -1, NULL, po_communication_pvt.getPostalCode()) ship_to_postal_code,
    DECODE(NVL(ph.ship_to_location_id, -1), -1, NULL, po_communication_pvt.getTownOrCity()) ship_to_city,
    DECODE(NVL(ph.bill_to_location_id, -1), -1, NULL,po_communication_pvt.getlocationinfo(ph.bill_to_location_id)) bill_to_location_id,
    DECODE(NVL(ph.ship_to_location_id, -1), -1, NULL, po_communication_pvt.getlocationname()) bill_to_location_name,
    DECODE(NVL(ph.bill_to_location_id, -1), -1, NULL, po_communication_pvt.getaddressline1()) bill_to_address_line1,
    DECODE(NVL(ph.bill_to_location_id, -1), -1, NULL, po_communication_pvt.getaddressline2()) bill_to_address_line2,
    DECODE(NVL(ph.bill_to_location_id, -1), -1, NULL, po_communication_pvt.getaddressline3()) bill_to_address_line3,
    DECODE(NVL(ph.bill_to_location_id, -1), -1, NULL, po_communication_pvt.getaddressline4()) bill_to_address_line4,
    DECODE(NVL(ph.bill_to_location_id, -1), -1, NULL, po_communication_pvt.getaddressinfo()) bill_to_address_info,
    DECODE(NVL(ph.bill_to_location_id, -1), -1, NULL, po_communication_pvt.getterritoryshortname()) bill_to_country,
    DECODE(NVL(ph.bill_to_location_id, -1), -1, NULL, po_communication_pvt.getPostalCode()) bill_to_postal_code,
    DECODE(NVL(ph.bill_to_location_id, -1), -1, NULL, po_communication_pvt.getTownOrCity()) bill_to_city,
    ph.attribute1,
    ph.attribute2,
    ph.attribute3,
    ph.attribute4,
    ph.attribute5,
    ph.attribute6,
    ph.attribute7,
    ph.attribute8,
    ph.attribute9,
    ph.attribute10,
    ph.attribute11,
    ph.attribute12,
    ph.attribute13,
    ph.attribute14,
    ph.attribute15,
    ph.vendor_site_id,
    ph.po_header_id,
    DECODE(ph.approved_flag, 'Y', 'Y', 'N') approved_flag,
    pvs.LANGUAGE,
    ph.vendor_id,
    ph.closed_code,
    ph.ussgl_transaction_code,
    ph.government_context,
    ph.request_id,
    ph.program_application_id,
    ph.program_id,
    ph.program_update_date,
    ph.org_id,
    ph.comments,
    TO_CHAR(ph.reply_date, 'DD-MON-YYYY HH24:MI:SS') reply_date,
    ph.reply_method_lookup_code,
    TO_CHAR(ph.rfq_close_date, 'DD-MON-YYYY HH24:MI:SS') rfq_close_date,
    ph.quote_type_lookup_code,
    ph.quotation_class_code,
    ph.quote_warning_delay_unit,
    ph.quote_warning_delay,
    ph.quote_vendor_quote_number,
    TO_CHAR(ph.closed_date, 'DD-MON-YYYY HH24:MI:SS') closed_date,
    ph.user_hold_flag,
    ph.approval_required_flag,
    ph.firm_status_lookup_code,
    TO_CHAR(ph.firm_date, 'DD-MON-YYYY HH24:MI:SS') firm_date,
    ph.frozen_flag,
    ph.edi_processed_flag,
    ph.edi_processed_status,
    ph.attribute_category,
    ph.created_by,
    ph.vendor_contact_id,
    ph.terms_id,
    ph.fob_lookup_code,
    ph.freight_terms_lookup_code,
    ph.status_lookup_code,
    ph.rate_type,
    TO_CHAR(ph.rate_date, 'DD-MON-YYYY HH24:MI:SS') rate_date,
    ph.from_header_id,
    ph.from_type_lookup_code,
    NVL(ph.authorization_status, 'N') authorization_status,
    TO_CHAR(ph.approved_date, 'DD-MON-YYYY HH24:MI:SS') approved_date,
    TO_CHAR(ph.amount_limit, po_communication_pvt.getformatmask) amount_limit,
    TO_CHAR(ph.min_release_amount, po_communication_pvt.getformatmask) min_release_amount,
    ph.note_to_authorizer,
    ph.note_to_receiver,
    ph.vendor_order_num,
    TO_CHAR(ph.last_update_date, 'DD-MON-YYYY HH24:MI:SS') last_update_date,
    ph.last_updated_by,
    ph.summary_flag,
    ph.enabled_flag,
    ph.segment2,
    ph.segment3,
    ph.segment4,
    ph.segment5,
    TO_CHAR(ph.start_date_active, 'DD-MON-YYYY HH24:MI:SS') start_date_active,
    TO_CHAR(ph.end_date_active, 'DD-MON-YYYY HH24:MI:SS') end_date_active,
    ph.last_update_login,
    ph.supply_agreement_flag,
    ph.global_attribute_category,
    ph.global_attribute1,
    ph.global_attribute2,
    ph.global_attribute3,
    ph.global_attribute4,
    ph.global_attribute5,
    ph.global_attribute6,
    ph.global_attribute7,
    ph.global_attribute8,
    ph.global_attribute9,
    ph.global_attribute10,
    ph.global_attribute11,
    ph.global_attribute12,
    ph.global_attribute13,
    ph.global_attribute14,
    ph.global_attribute15,
    ph.global_attribute16,
    ph.global_attribute17,
    ph.global_attribute18,
    ph.global_attribute19,
    ph.global_attribute20,
    ph.interface_source_code,
    ph.reference_num,
    ph.wf_item_type,
    ph.wf_item_key,
    ph.pcard_id,
    ph.price_update_tolerance,
    ph.mrc_rate_type,
    ph.mrc_rate_date,
    ph.mrc_rate,
    ph.pay_on_code,
    ph.xml_flag,
    TO_CHAR(ph.xml_send_date, 'DD-MON-YYYY HH24:MI:SS') xml_send_date,
    TO_CHAR(ph.xml_change_send_date, 'DD-MON-YYYY HH24:MI:SS') xml_change_send_date,
    ph.global_agreement_flag,
    ph.consigned_consumption_flag,
    TO_CHAR(ph.cbc_accounting_date, 'DD-MON-YYYY HH24:MI:SS') cbc_accounting_date,
    ph.consume_req_demand_flag,
    ph.change_requested_by,
    plc3.meaning shipping_control,
    ph.conterms_exist_flag,
    TO_CHAR(ph.conterms_articles_upd_date, 'DD-MON-YYYY HH24:MI:SS') conterms_articles_upd_date,
    TO_CHAR(ph.conterms_deliv_upd_date, 'DD-MON-YYYY HH24:MI:SS') conterms_deliv_upd_date,
    NVL(ph.pending_signature_flag, 'N'),
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getoperationinfo(ph.org_id)) ou_name,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getouaddressline1()) ou_addr1,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getouaddressline2()) ou_addr2,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getouaddressline3()) ou_addr3,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getoutowncity()) ou_town_city,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getouregion2()) ou_region2,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getoupostalcode()) ou_postalcode,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getoucountry()) ou_country,
    po_communication_pvt.getlocationinfo(pa.location_id) buyer_location_id,
    po_communication_pvt.getaddressline1() buyer_address_line1,
    po_communication_pvt.getaddressline2() buyer_address_line2,
    po_communication_pvt.getaddressline3() buyer_address_line3,
    po_communication_pvt.getaddressline4() buyer_address_line4,
    po_communication_pvt.getaddressinfo() buyer_city_state_zip,
    po_communication_pvt.getphone(pa.agent_id) buyer_contact_phone,
    po_communication_pvt.getemail() buyer_contact_email,
    po_communication_pvt.getfax() buyer_contact_fax,
    -- pvs.fax vendor_fax,
    -- Dalit A. Raviv 06/12/2009 correct the source of vendor_fax.
    -- if vendor site do not have fax take the vendor fax
    NVL((pvs.fax_area_code
    ||DECODE(pvs.fax_area_code, NULL, NULL, '-')
    || pvs.fax) ,
    (SELECT fax.raw_phone_number fax_number
    FROM hz_party_sites hps,
      hz_contact_points fax
    WHERE hps.status              = 'A'
    AND fax.owner_table_id(+)     = hps.party_site_id
    AND fax.owner_table_name(+)   = 'HZ_PARTY_SITES'
    AND fax.status(+)             = 'A'
    AND fax.contact_point_type(+) = 'PHONE'
    AND fax.phone_line_type(+)    = 'FAX'
    AND fax.primary_flag          = 'Y'
      --and    hps.party_site_id         = pvs.party_site_id
    AND hps.party_id = vn.party_id
    AND rownum       < 2
    ) ) vendor_fax,
    -- 06/12/2009
    pvs.email_address vendor_email,
    /*       TO_CHAR(DECODE(PH.TYPE_LOOKUP_CODE,
    'STANDARD',
    xxpo_communication_report_pkg.get_converted_amount(PO_CORE_S.GET_TOTAL('H', PH.PO_HEADER_ID),ph.segment1),
    NULL),
    PO_COMMUNICATION_PVT.GETFORMATMASK) TOTAL_AMOUNT,
    */
    DECODE(ph.type_lookup_code, 'STANDARD', xxpo_communication_report_pkg.get_converted_amount(xxpo_communication_report_pkg.get_total('H', ph.po_header_id), ph.segment1,0), NULL) total_amount,
    po_communication_pvt.getterritoryshortname() buyer_country,
    pvs.address_line4 vendor_address_line4,
    pvs.area_code vendor_area_code,
    pvc.area_code vendor_contact_area_code,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getlegalentitydetails(ph.org_id)) le_name,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getleaddressline1()) le_addr1,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getleaddressline2()) le_addr2,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getleaddressline3()) le_addr3,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getletownorcity()) le_town_city,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getlestateorprovince()) le_stae_province,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getlepostalcode()) le_postalcode,
    DECODE(NVL(ph.org_id, -1), -1, NULL, po_communication_pvt.getlecountry()) le_country,
    DECODE(ph.cancel_flag, 'Y', po_communication_pvt.getpocanceldate(ph.po_header_id), NULL) cancel_date,
    ph.change_summary,
    ph.document_creation_method,
    ph.encumbrance_required_flag,
    psl.display_name style_display_name,
    xxpo_communication_report_pkg.get_rate_cur_for_xml(ph.segment1,0) rate_currency,
    xxpo_communication_report_pkg.get_rate_baserate_for_xml(ph.segment1,0) base_rate,
    xxpo_communication_report_pkg.get_rate_basedate_for_xml(ph.segment1,0) base_date,
    xxpo_communication_report_pkg.get_approved_details_for_xml(ph.segment1, 'FULL_NAME') approver_full_name,
    xxpo_communication_report_pkg.get_approved_details_for_xml(ph.segment1, 'JOB_DESC_1') approver_job_desc1,
    xxpo_communication_report_pkg.get_approved_details_for_xml(ph.segment1, 'JOB_DESC_2') approver_job_desc2,
    xxpo_communication_report_pkg.get_approved_details_for_xml(ph.segment1, 'COMPANY') approver_company,
    xxpo_communication_report_pkg.get_approved_details_for_xml(ph.segment1, 'SIG_URL') approver_sign,
    po_headers_sv3.get_po_status(ph.po_header_id) po_status,
    xxpo_communication_report_pkg.get_logo(ph.segment1) logo_url,
    len."OPERATING_UNIT",
    len."LEGAL_ENTITY_ID",
    len."ENTITY_NAME",
    len."PARTY_ID",
    len."PARTY_NUMBER",
    len."LEGAL_ENTITY_IDENTIFIER",
    len."LAST_UPDATE_DATE2",
    len."LOCATION_ID",
    len."ADDRESS_LINE_1",
    len."ADDRESS_LINE_2",
    len."ADDRESS_LINE_3",
    len."TOWN_OR_CITY",
    len."POSTAL_CODE",
    len."COUNTRY",
    len."COUNTRY_NAME",
    len."PHONE_NUMBER",
    len."FAX_NUMBER",
    len."EMAIL_ADDRESS",
    len."URL",
    fr_det.carrier_name,
    fr_det.person_last_name,
    fr_det.phone_number ca_phone_number,
    fr_det.fax_number ca_fax_number,
    NVL(xxpo_communication_report_pkg.get_rate_cur_for_xml(ph.segment1,0), ph.currency_code) currency_code
  FROM fnd_lookup_values plc1,
    fnd_lookup_values plc2,
    fnd_currencies_tl fcc,
    po_vendors vn,
    po_vendor_sites_all pvs,
    po_vendor_contacts pvc,
    per_all_people_f hre,
    ap_terms t,
    po_headers_all ph,
    fnd_territories_tl fte3,
    org_freight_tl ofc,
    po_agents pa,
    fnd_lookup_values plc3,
    po_doc_style_lines_tl psl,
    fnd_lookup_values plc4,
    (SELECT opu.organization_id operating_unit,
      lep.legal_entity_id,
      --  lep.NAME entity_name,
      NVL(DECODE(xxhz_util.get_ou_lang(fnd_global.org_id), 'JA', lep.attribute2, lep.name), lep.name) entity_name,
      lep.party_id,
      hzp.party_number,
      lep.legal_entity_identifier,
      lep.last_update_date last_update_date2,
      reg.location_id,
      hrl.address_line_1,
      hrl.address_line_2,
      hrl.address_line_3,
      hrl.town_or_city,
      hrl.postal_code,
      hrl.country,
      ter.territory_short_name country_name,
      phone.phone_country_code
      || '-'
      || phone.phone_area_code
      || '-'
      || phone.phone_number phone_number,
      fax.phone_country_code
      || '-'
      || fax.phone_area_code
      || '-'
      || fax.phone_number fax_number,
      email.email_address email_address,
      url.url
    FROM xle_entity_profiles lep,
      xle_registrations reg,
      hr_locations_all hrl,
      hz_parties hzp,
      fnd_territories_vl ter,
      hr_operating_units opu,
      hz_contact_points phone,
      hz_contact_points fax,
      hz_contact_points email,
      hz_contact_points url
    WHERE lep.transacting_entity_flag = 'Y'
    AND lep.party_id                  = hzp.party_id
    AND lep.legal_entity_id           = reg.source_id
    AND reg.source_table              = 'XLE_ENTITY_PROFILES'
    AND hrl.location_id               = reg.location_id
    AND reg.identifying_flag          = 'Y'
    AND ter.territory_code            = hrl.country
    AND lep.legal_entity_id           = opu.default_legal_context_id
    -- CHG0034098 OU info will be determined by the purchase doc rather than the users profile
    -- AND opu.organization_id = fnd_profile.VALUE('ORG_ID')
    AND hzp.party_id               = phone.owner_table_id
    AND phone.owner_table_name   = 'HZ_PARTIES'
    AND phone.contact_point_type = 'PHONE'
    AND phone.phone_line_type    = 'GEN'
    AND hzp.party_id             = fax.owner_table_id
    AND fax.owner_table_name     = 'HZ_PARTIES'
    AND fax.contact_point_type   = 'PHONE'
    AND fax.phone_line_type      = 'FAX'
    AND hzp.party_id             = email.owner_table_id
    AND email.owner_table_name   = 'HZ_PARTIES'
    AND email.contact_point_type = 'EMAIL'
    AND hzp.party_id             = url.owner_table_id
    AND url.owner_table_name     = 'HZ_PARTIES'
    AND url.contact_point_type   = 'WEB'
    ) LEN,
    (SELECT wc.carrier_id,
      wc.freight_code,
      wc.carrier_name,
      hp.person_last_name,
      hp.party_id,
      hcp.phone_number,
      hcp1.phone_number fax_number
    FROM wsh_carriers_v wc,
      hz_relationships hr,
      hz_parties hp,
      hz_contact_points hcp,
      hz_contact_points hcp1
    WHERE wc.carrier_id                   = hr.subject_id(+)
    AND hr.subject_type(+)                = 'ORGANIZATION'
    AND hr.relationship_code (+)          = 'EMPLOYER_OF'
    AND hr.object_id                      = hp.party_id(+)
    AND hr.party_id                       = hcp.owner_table_id(+)
    AND NVL(hcp.do_not_use_flag(+), 'N')  = 'N'
    AND hcp.phone_line_type(+)            = 'FAX'
    AND hr.party_id                       = hcp1.owner_table_id(+)
    AND NVL(hcp1.do_not_use_flag(+), 'N') = 'N'
    AND hcp1.phone_line_type(+)           = 'GEN'
    ) fr_det -- Gabriel Carrier Details
  WHERE vn.vendor_id(+)      = ph.vendor_id
  AND fr_det.freight_code(+) = ph.ship_via_lookup_code
  AND ofc.freight_code(+)    = ph.ship_via_lookup_code
  AND ofc.organization_id(+) = ph.org_id
  AND ofc.LANGUAGE(+)        = userenv('LANG')
  AND pvs.vendor_site_id(+)  = ph.vendor_site_id
  AND ph.vendor_contact_id   = pvc.vendor_contact_id(+)
  AND (ph.vendor_contact_id IS NULL
  OR ph.vendor_site_id       = pvc.vendor_site_id)
  AND hre.person_id          = ph.agent_id
  AND TRUNC(SYSDATE) BETWEEN hre.effective_start_date AND hre.effective_end_date
  AND ph.terms_id                                               = t.term_id(+)
  AND ph.type_lookup_code                                      IN ('STANDARD', 'BLANKET', 'CONTRACT')
  AND fcc.currency_code                                         = ph.currency_code
  AND plc1.lookup_code(+)                                       = ph.fob_lookup_code
  AND plc1.lookup_type(+)                                       = 'FOB'
  AND plc1.LANGUAGE(+)                                          = userenv('LANG')
  AND plc1.view_application_id(+)                               = 201
  AND ph.org_id                                                 = len.operating_unit
  AND DECODE(plc1.lookup_code, NULL, 1, plc1.security_group_id) = DECODE(plc1.lookup_code, NULL, 1, fnd_global.lookup_security_group(plc1.lookup_type, plc1.view_application_id))
  AND plc2.lookup_code(+)                                       = ph.freight_terms_lookup_code
  AND plc2.lookup_type(+)                                       = 'FREIGHT TERMS'
  AND plc2.LANGUAGE(+)                                          = userenv('LANG')
  AND plc2.view_application_id(+)                               = 201
  AND DECODE(plc2.lookup_code, NULL, 1, plc2.security_group_id) = DECODE(plc2.lookup_code, NULL, 1, fnd_global.lookup_security_group(plc2.lookup_type, plc2.view_application_id))
  AND pvs.country                                               = fte3.territory_code(+)
  AND DECODE(fte3.territory_code, NULL, '1', fte3.LANGUAGE)     = DECODE(fte3.territory_code, NULL, '1', userenv('LANG'))
  AND pa.agent_id                                               = ph.agent_id
  AND plc3.lookup_code(+)                                       = ph.shipping_control
  AND plc3.lookup_type(+)                                       = 'SHIPPING CONTROL'
  AND plc3.LANGUAGE(+)                                          = userenv('LANG')
  AND plc3.view_application_id(+)                               = 201
  AND DECODE(plc3.lookup_code, NULL, 1, plc3.security_group_id) = DECODE(plc3.lookup_code, NULL, 1, fnd_global.lookup_security_group(plc3.lookup_type, plc3.view_application_id))
  AND fcc.LANGUAGE                                              = userenv('LANG')
  AND ph.style_id                                               = psl.style_id(+)
  AND psl.LANGUAGE(+)                                           = userenv('LANG')
  AND psl.document_subtype(+)                                   = ph.type_lookup_code
  AND plc4.lookup_code(+)                                       = pvc.prefix
  AND plc4.lookup_type(+)                                       = 'CONTACT_TITLE'
  AND plc4.LANGUAGE(+)                                          = userenv('LANG')
  AND plc4.view_application_id(+)                               = 222
  AND DECODE(plc4.lookup_code, NULL, 1, plc4.security_group_id) = DECODE(plc4.lookup_code, NULL, 1, fnd_global.lookup_security_group(plc4.lookup_type, plc4.view_application_id))
    --   AND NVL(OFC.FREIGHT_CODE_TL, PH.SHIP_VIA_LOOKUP_CODE) = 128 -- Only for test --
    --  AND PH.SEGMENT1 = '700000005'  -- Only for test
    ;
