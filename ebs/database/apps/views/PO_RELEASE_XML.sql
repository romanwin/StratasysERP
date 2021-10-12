CREATE OR REPLACE VIEW PO_RELEASE_XML
(segment1, logo_url, operating_unit, legal_entity_id, entity_name, party_id, party_number, legal_entity_identifier, last_update_date2, location_id, address_line_1, address_line_2, address_line_3, town_or_city, postal_code, country, country_name, phone_number, fax_number, email_address, url, revision_num, print_count, creation_date, creation_date_jpn, printed_date, revised_date, revised_date_jpn, document_buyer_first_name, document_buyer_last_name, document_buyer_first_name_jpn, document_buyer_last_name_jpn, document_buyer_title, document_buyer_agent_id, archive_buyer_agent_id, archive_buyer_first_name, archive_buyer_last_name, archive_buyer_first_name_jpn, archive_buyer_last_name_jpn, archive_buyer_title, cancel_flag, acceptance_required_flag, acceptance_due_date, currency_code, currency_name, rate, ship_via, fob, freight_terms, payment_terms, payment_terms_jpn, customer_num, vendor_num, vendor_name, vendor_address_line1, vendor_address_line2, vendor_address_line3, vendor_city, vendor_state, vendor_postal_code, vendor_country, vendor_phone, vendor_contact_first_name, vendor_contact_last_name, vendor_contact_title, vendor_fax, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, vendor_site_id, po_header_id, po_release_id, approved_flag, language, vendor_id, consigned_consumption_flag, ship_to_location_id, ship_to_location_name, ship_to_address_line1, ship_to_address_line2, ship_to_address_line3, ship_to_address_line4, ship_to_address_info, ship_to_country, ship_to_postal_code, ship_to_city, bill_to_location_id, bill_to_location_name, bill_to_address_line1, bill_to_address_line2, bill_to_address_line3, bill_to_address_line4, bill_to_address_info, bill_to_country, bill_to_postal_code, bill_to_city, authorization_status, ussgl_transaction_code, government_context, request_id, program_application_id, program_id, program_update_date, closed_code, frozen_flag, release_type, note_to_vendor, org_id, last_update_date, last_updated_by, release_num, agent_id, release_date, last_update_login, created_by, approved_date, hold_by, hold_date, hold_reason, hold_flag, cancelled_by, cancel_date, cancel_reason, firm_status_lookup_code, firm_date, attribute_category, edi_processed_flag, global_attribute_category, global_attribute1, global_attribute2, global_attribute3, global_attribute4, global_attribute5, global_attribute6, global_attribute7, global_attribute8, global_attribute9, global_attribute10, global_attribute11, global_attribute12, global_attribute13, global_attribute14, global_attribute15, global_attribute16, global_attribute17, global_attribute18, global_attribute19, global_attribute20, wf_item_type, wf_item_key, pcard_id, pay_on_code, xml_flag, xml_send_date, xml_change_send_date, cbc_accounting_date, change_requested_by, shipping_control, ou_name, ou_addr1, ou_addr2, ou_addr3, ou_town_city, ou_region2, ou_postalcode, ou_country, rel_buyer_location_id, rel_buyer_address_line1, rel_buyer_address_line2, rel_buyer_address_line3, rel_buyer_address_line4, rel_buyer_city_state_zip, rel_buyer_contact_phone, rel_buyer_contact_email, rel_buyer_contact_fax, rel_buyer_country, total_amount, vendor_address_line4, vendor_area_code, vendor_contact_area_code, vendor_contact_phone, le_name, le_addr1, le_addr2, le_addr3, le_town_city, le_stae_province, le_postalcode, le_country, start_date, end_date, start_date_jpn, end_date_jpn, amount_agreed, change_summary, document_creation_method, vendor_order_num)
AS
SELECT
--------------------------------------------------------------------
--  name:            PO_RELEASE_XML
--  create by:       XXX
--  Revision:        1.0
--  creation date:   XX/XX/2009
--------------------------------------------------------------------
--  purpose :        REP001 - PO Document
--------------------------------------------------------------------
--  ver  date        name         desc
--  1.0  XX/XX/2009  XXX          initial build
--  1.1  27.05.13    Vitaly       cr763:creation_date_jpn,revised_date_jpn,   payment_terms_jpn added
---                                     start_date_jpn, end_date_jpn added
---                                     document_buyer_first_name_jpn,document_buyer_last_name_jpn added
---                                     archive_buyer_first_name_jpn, archive_buyer_last_name_jpn added
---                                     ship_to_postal_code, ship_to_city, bill_to_postal_code, bill_to_city added
---                                     len.entity_name field logic was changed
--  1.2  11.06.13    yuval tal    bugfix 821 add logic to linkage  add release num parameter
--------------------------------------------------------------------
        PH.SEGMENT1,
        -- logo
        xxpo_communication_report_pkg.get_logo(ph.segment1) logo_url,
        -- org details
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
       -----
       PR.REVISION_NUM,
       PR.PRINT_COUNT,
      -- TO_CHAR(PR.CREATION_DATE, 'DD-MON-YYYY HH24:MI:SS') CREATION_DATE,
      to_char(nvl(xxpo_utils_pkg.get_first_approve_date(pr.po_release_id,ph.type_lookup_code),pr.creation_date), 'DD-MON-YYYY HH24:MI:SS') CREATION_DATE,
      to_char(nvl(xxpo_utils_pkg.get_first_approve_date(pr.po_release_id,ph.type_lookup_code),pr.creation_date), 'YYYY/MM/DD') CREATION_DATE_JPN,
       TO_CHAR(PR.PRINTED_DATE, 'DD-MON-YYYY HH24:MI:SS') PRINTED_DATE,
      -- TO_CHAR(PR.REVISED_DATE, 'DD-MON-YYYY HH24:MI:SS') REVISED_DATE,
       to_char(nvl(pr.approved_date,pr.creation_date), 'DD-MON-YYYY HH24:MI:SS') REVISED_DATE,
       to_char(nvl(ph.approved_date,ph.creation_date), 'YYYY/MM/DD')             revised_date_jpn,
       HRE.FIRST_NAME DOCUMENT_BUYER_FIRST_NAME,
       HRE.LAST_NAME  DOCUMENT_BUYER_LAST_NAME,
       nvl(hre.attribute1,hre.first_name)         document_buyer_first_name_jpn,
       nvl(hre.attribute2,hre.last_name)          document_buyer_last_name_jpn,
       HRE.TITLE DOCUMENT_BUYER_TITLE,
	PR.AGENT_ID DOCUMENT_BUYER_AGENT_ID,
       DECODE(NVL(PR.REVISION_NUM, 0),
              0,
              NULL,
              PO_COMMUNICATION_PVT.GETARCBUYERAGENTID(PR.PO_HEADER_ID)) ARCHIVE_BUYER_AGENT_ID,
   /*    DECODE(NVL(PR.REVISION_NUM, 0),
              0,
              NULL,
              PO_COMMUNICATION_PVT.GETARCBUYERFNAME())*/ HRE.FIRST_NAME  ARCHIVE_BUYER_FIRST_NAME,
    /*   DECODE(NVL(PR.REVISION_NUM, 0),
              0,
              NULL,
              PO_COMMUNICATION_PVT.GETARCBUYERLNAME())*/HRE.LAST_NAME  ARCHIVE_BUYER_LAST_NAME,
      nvl(hre.attribute1,hre.first_name)           archive_buyer_first_name_jpn,
      nvl(hre.attribute2,hre.last_name)            archive_buyer_last_name_jpn,
      HRE.TITLE  ARCHIVE_BUYER_TITLE,
      PR.CANCEL_FLAG,
	nvl(PR.ACCEPTANCE_REQUIRED_FLAG, 'N'),
       TO_CHAR(PR.ACCEPTANCE_DUE_DATE, 'DD-MON-YYYY HH24:MI:SS') ACCEPTANCE_DUE_DATE,
       --FCC.CURRENCY_CODE,
       nvl(xxpo_communication_report_pkg.get_rate_cur_for_xml(ph.segment1,pr.release_num),
           ph.currency_code) CURRENCY_CODE , -- yuval 18.11.10
       FCC.NAME CURRENCY_NAME,
       TO_CHAR(PH.RATE, PO_COMMUNICATION_PVT.GETFORMATMASK) RATE,
       NVL(OFC.FREIGHT_CODE_TL, PH.SHIP_VIA_LOOKUP_CODE) SHIP_VIA,
       PLC1.MEANING FOB,
       PLC2.MEANING FREIGHT_TERMS,
       T.NAME PAYMENT_TERMS,
       nvl(xxpo_communication_report_pkg.get_ap_term_name_tl(ph.terms_id, ph.org_id),t.NAME)     PAYMENT_TERMS_JPN,
       NVL(PVS.CUSTOMER_NUM, VN.CUSTOMER_NUM) CUSTOMER_NUM,
       VN.SEGMENT1 VENDOR_NUM,
       VN.VENDOR_NAME,
       PVS.ADDRESS_LINE1 VENDOR_ADDRESS_LINE1,
       PVS.ADDRESS_LINE2 VENDOR_ADDRESS_LINE2,
       PVS.ADDRESS_LINE3 VENDOR_ADDRESS_LINE3,
       PVS.CITY VENDOR_CITY,
       DECODE(PVS.STATE,
              NULL,
              DECODE(PVS.PROVINCE, NULL, PVS.COUNTY, PVS.PROVINCE),
              PVS.STATE) VENDOR_STATE,
       PVS.ZIP VENDOR_POSTAL_CODE,
       FTE3.TERRITORY_SHORT_NAME VENDOR_COUNTRY,
       PVS.PHONE VENDOR_PHONE,
       PVC.FIRST_NAME VENDOR_CONTACT_FIRST_NAME,
       PVC.LAST_NAME VENDOR_CONTACT_LAST_NAME,
       PVC.TITLE VENDOR_CONTACT_TITLE,
       PVS.FAX VENDOR_FAX,
       PR.ATTRIBUTE1,
       PR.ATTRIBUTE2,
       PR.ATTRIBUTE3,
       PR.ATTRIBUTE4,
       PR.ATTRIBUTE5,
       PR.ATTRIBUTE6,
       PR.ATTRIBUTE7,
       PR.ATTRIBUTE8,
       PR.ATTRIBUTE9,
       PR.ATTRIBUTE10,
       PR.ATTRIBUTE11,
       PR.ATTRIBUTE12,
       PR.ATTRIBUTE13,
       PR.ATTRIBUTE14,
       PR.ATTRIBUTE15,
       PH.VENDOR_SITE_ID,
       PH.PO_HEADER_ID,
       PR.PO_RELEASE_ID,
       DECODE(PR.APPROVED_FLAG, 'Y', 'Y', 'N') APPROVED_FLAG,
       PVS.LANGUAGE,
       PH.VENDOR_ID,
       PR.CONSIGNED_CONSUMPTION_FLAG,
       DECODE(NVL(PH.SHIP_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETLOCATIONINFO(PH.SHIP_TO_LOCATION_ID)) SHIP_TO_LOCATION_ID,
       DECODE(NVL(PH.SHIP_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETLOCATIONNAME()) SHIP_TO_LOCATION_NAME,
       DECODE(NVL(PH.SHIP_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETADDRESSLINE1()) SHIP_TO_ADDRESS_LINE1,
       DECODE(NVL(PH.SHIP_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETADDRESSLINE2()) SHIP_TO_ADDRESS_LINE2,
       DECODE(NVL(PH.SHIP_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETADDRESSLINE3()) SHIP_TO_ADDRESS_LINE3,
       DECODE(NVL(PH.SHIP_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETADDRESSLINE4()) SHIP_TO_ADDRESS_LINE4,
       DECODE(NVL(PH.SHIP_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETADDRESSINFO()) SHIP_TO_ADDRESS_INFO,
       DECODE(NVL(PH.SHIP_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETTERRITORYSHORTNAME()) SHIP_TO_COUNTRY,
       decode(nvl(ph.ship_to_location_id, -1),
              -1,
              NULL,
              po_communication_pvt.getPostalCode()) ship_to_postal_code,
       decode(nvl(ph.ship_to_location_id, -1),
              -1,
              NULL,
              po_communication_pvt.getTownOrCity()) ship_to_city,
       DECODE(NVL(PH.BILL_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETLOCATIONINFO(PH.BILL_TO_LOCATION_ID)) BILL_TO_LOCATION_ID,
       DECODE(NVL(PH.BILL_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETLOCATIONNAME()) BILL_TO_LOCATION_NAME,
       DECODE(NVL(PH.BILL_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETADDRESSLINE1()) BILL_TO_ADDRESS_LINE1,
       DECODE(NVL(PH.BILL_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETADDRESSLINE2()) BILL_TO_ADDRESS_LINE2,
       DECODE(NVL(PH.BILL_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETADDRESSLINE3()) BILL_TO_ADDRESS_LINE3,
       DECODE(NVL(PH.BILL_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETADDRESSLINE4()) BILL_TO_ADDRESS_LINE4,
       DECODE(NVL(PH.BILL_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETADDRESSINFO()) BILL_TO_ADDRESS_INFO,
       DECODE(NVL(PH.BILL_TO_LOCATION_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETTERRITORYSHORTNAME()) BILL_TO_COUNTRY,
       decode(nvl(ph.bill_to_location_id, -1),
              -1,
              NULL,
              po_communication_pvt.getPostalCode()) bill_to_postal_code,
       decode(nvl(ph.bill_to_location_id, -1),
              -1,
              NULL,
              po_communication_pvt.getTownOrCity()) bill_to_city,

       PR.AUTHORIZATION_STATUS,
       PR.USSGL_TRANSACTION_CODE,
       PR.GOVERNMENT_CONTEXT,
       PR.REQUEST_ID,
       PR.PROGRAM_APPLICATION_ID,
       PR.PROGRAM_ID,
       PR.PROGRAM_UPDATE_DATE,
       PR.CLOSED_CODE,
       PR.FROZEN_FLAG,
       PR.RELEASE_TYPE,
       PR.NOTE_TO_VENDOR,
       PR.ORG_ID,
       TO_CHAR(PR.LAST_UPDATE_DATE, 'DD-MON-YYYY HH24:MI:SS') LAST_UPDATE_DATE,
       PR.LAST_UPDATED_BY,
       PR.RELEASE_NUM,
       PR.AGENT_ID,
       TO_CHAR(PR.RELEASE_DATE, 'DD-MON-YYYY HH24:MI:SS') RELEASE_DATE,
       PR.LAST_UPDATE_LOGIN,
       PR.CREATED_BY,
       TO_CHAR(PR.APPROVED_DATE, 'DD-MON-YYYY HH24:MI:SS') APPROVED_DATE,
       PR.HOLD_BY,
       TO_CHAR(PR.HOLD_DATE, 'DD-MON-YYYY HH24:MI:SS') HOLD_DATE,
       PR.HOLD_REASON,
       PR.HOLD_FLAG,
       PR.CANCELLED_BY,
       TO_CHAR(PR.CANCEL_DATE, 'DD-MON-YYYY HH24:MI:SS') CANCEL_DATE,
       PR.CANCEL_REASON,
       PR.FIRM_STATUS_LOOKUP_CODE,
       TO_CHAR(PR.FIRM_DATE, 'DD-MON-YYYY HH24:MI:SS') FIRM_DATE,
       PR.ATTRIBUTE_CATEGORY,
       PR.EDI_PROCESSED_FLAG,
       PR.GLOBAL_ATTRIBUTE_CATEGORY,
       PR.GLOBAL_ATTRIBUTE1,
       PR.GLOBAL_ATTRIBUTE2,
       PR.GLOBAL_ATTRIBUTE3,
       PR.GLOBAL_ATTRIBUTE4,
       PR.GLOBAL_ATTRIBUTE5,
       PR.GLOBAL_ATTRIBUTE6,
       PR.GLOBAL_ATTRIBUTE7,
       PR.GLOBAL_ATTRIBUTE8,
       PR.GLOBAL_ATTRIBUTE9,
       PR.GLOBAL_ATTRIBUTE10,
       PR.GLOBAL_ATTRIBUTE11,
       PR.GLOBAL_ATTRIBUTE12,
       PR.GLOBAL_ATTRIBUTE13,
       PR.GLOBAL_ATTRIBUTE14,
       PR.GLOBAL_ATTRIBUTE15,
       PR.GLOBAL_ATTRIBUTE16,
       PR.GLOBAL_ATTRIBUTE17,
       PR.GLOBAL_ATTRIBUTE18,
       PR.GLOBAL_ATTRIBUTE19,
       PR.GLOBAL_ATTRIBUTE20,
       PR.WF_ITEM_TYPE,
       PR.WF_ITEM_KEY,
       PR.PCARD_ID,
       PR.PAY_ON_CODE,
       PR.XML_FLAG,
       TO_CHAR(PR.XML_SEND_DATE, 'DD-MON-YYYY HH24:MI:SS') XML_SEND_DATE,
       TO_CHAR(PR.XML_CHANGE_SEND_DATE, 'DD-MON-YYYY HH24:MI:SS') XML_CHANGE_SEND_DATE,
       TO_CHAR(PR.CBC_ACCOUNTING_DATE, 'DD-MON-YYYY HH24:MI:SS') CBC_ACCOUNTING_DATE,
       PR.CHANGE_REQUESTED_BY,
       PLC3.MEANING SHIPPING_CONTROL,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETOPERATIONINFO(PR.ORG_ID)) OU_NAME,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETOUADDRESSLINE1()) OU_ADDR1,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETOUADDRESSLINE2()) OU_ADDR2,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETOUADDRESSLINE3()) OU_ADDR3,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETOUTOWNCITY()) OU_TOWN_CITY,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETOUREGION2()) OU_REGION2,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.GETOUPOSTALCODE()) OU_POSTALCODE,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.getOUCountry()) OU_COUNTRY,
       PO_COMMUNICATION_PVT.GETLOCATIONINFO(PA.LOCATION_ID) REL_BUYER_LOCATION_ID,
       PO_COMMUNICATION_PVT.GETADDRESSLINE1() REL_BUYER_ADDRESS_LINE1,
       PO_COMMUNICATION_PVT.GETADDRESSLINE2() REL_BUYER_ADDRESS_LINE2,
       PO_COMMUNICATION_PVT.GETADDRESSLINE3() REL_BUYER_ADDRESS_LINE3,
       PO_COMMUNICATION_PVT.GETADDRESSLINE4() REL_BUYER_ADDRESS_LINE4,
       PO_COMMUNICATION_PVT.GETADDRESSINFO() REL_BUYER_CITY_STATE_ZIP,
       PO_COMMUNICATION_PVT.GETPHONE(PA.AGENT_ID) REL_BUYER_CONTACT_PHONE,
       PO_COMMUNICATION_PVT.GETEMAIL() REL_BUYER_CONTACT_EMAIL,
       PO_COMMUNICATION_PVT.GETFAX() REL_BUYER_CONTACT_FAX,
       PO_COMMUNICATION_PVT.GETTERRITORYSHORTNAME() REL_BUYER_COUNTRY,
       TO_CHAR( xxpo_communication_report_pkg.get_converted_amount( PO_CORE_S.GET_TOTAL('R', PR.PO_RELEASE_ID) ,ph.segment1,pr.release_num)   ,
               PO_COMMUNICATION_PVT.GETFORMATMASK) TOTAL_AMOUNT,  -- yuval 18.11.10
       PVS.ADDRESS_LINE4 VENDOR_ADDRESS_LINE4,
       PVS.AREA_CODE VENDOR_AREA_CODE,
       PVC.AREA_CODE VENDOR_CONTACT_AREA_CODE,
       PVC.PHONE VENDOR_CONTACT_PHONE,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.getLegalEntityDetails(PR.ORG_ID)) LE_NAME,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.getLEAddressLine1()) LE_ADDR1,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.getLEAddressLine2()) LE_ADDR2,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.getLEAddressLine3()) LE_ADDR3,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.getLETownOrCity()) LE_TOWN_CITY,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.getLEStateOrProvince()) LE_STAE_PROVINCE,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.getLEPostalCode()) LE_POSTALCODE,
       DECODE(NVL(PR.ORG_ID, -1),
              -1,
              NULL,
              PO_COMMUNICATION_PVT.getLECountry()) LE_COUNTRY,
       TO_CHAR(PH.START_DATE, 'DD-MON-YYYY HH24:MI:SS') START_DATE,
       TO_CHAR(PH.END_DATE, 'DD-MON-YYYY HH24:MI:SS')   END_DATE,
       TO_CHAR(PH.START_DATE, 'YYYY/MM/DD') START_DATE_JPN,
       TO_CHAR(PH.END_DATE, 'YYYY/MM/DD')   END_DATE_JPN,
       /*TO_CHAR(NVL(PH.BLANKET_TOTAL_AMOUNT, ''),
               PO_COMMUNICATION_PVT.GETFORMATMASK) AMOUNT_AGREED,*/
       to_char((xxpo_communication_report_pkg.get_converted_amount(nvl(ph.blanket_total_amount, 0),ph.segment1,pr.release_num))
       ,            po_communication_pvt.getformatmask) , -- yuval 18.11.10
       PR.CHANGE_SUMMARY,
       PR.DOCUMENT_CREATION_METHOD,
       PR.VENDOR_ORDER_NUM
  FROM FND_LOOKUP_VALUES   PLC1,
       FND_LOOKUP_VALUES   PLC2,
       FND_CURRENCIES_TL   FCC,
       PO_VENDORS          VN,
       PO_VENDOR_SITES_ALL PVS,
       PO_VENDOR_CONTACTS  PVC,
       PER_ALL_PEOPLE_F    HRE,
       AP_TERMS            T,
       PO_RELEASES_ALL     PR,
       PO_AGENTS           PA,
       PO_HEADERS_ALL      PH,
       FND_TERRITORIES_TL  FTE3,
       FND_LOOKUP_VALUES   PLC3,
       ORG_FREIGHT         OFC,
         (SELECT opu.organization_id operating_unit,
               lep.legal_entity_id,
               --  lep.NAME entity_name,
               nvl(decode(xxhz_util.get_ou_lang(fnd_global.org_id),
                        'JA',
                        lep.attribute2,
                        lep.name),
                 lep.name) entity_name,
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
               phone.phone_country_code || '-' || phone.phone_area_code || '-' ||
               phone.phone_number phone_number,
               fax.phone_country_code || '-' || fax.phone_area_code || '-' ||
               fax.phone_number fax_number,
               email.email_address email_address,
               url.url
          FROM xle_entity_profiles lep,
               xle_registrations   reg,
               hr_locations_all    hrl,
               hz_parties          hzp,
               fnd_territories_vl  ter,
               hr_operating_units  opu,
               hz_contact_points   phone,
               hz_contact_points   fax,
               hz_contact_points   email,
               hz_contact_points   url
         WHERE lep.transacting_entity_flag = 'Y' AND
               lep.party_id = hzp.party_id AND
               lep.legal_entity_id = reg.source_id AND
               reg.source_table = 'XLE_ENTITY_PROFILES' AND
               hrl.location_id = reg.location_id AND
               reg.identifying_flag = 'Y' AND
               ter.territory_code = hrl.country AND
               lep.legal_entity_id = opu.default_legal_context_id AND
            --   opu.organization_id = fnd_profile.VALUE('ORG_ID') AND
               hzp.party_id = phone.owner_table_id AND
               phone.owner_table_name = 'HZ_PARTIES' AND
               phone.contact_point_type = 'PHONE' AND
               phone.phone_line_type = 'GEN' AND
               hzp.party_id = fax.owner_table_id AND
               fax.owner_table_name = 'HZ_PARTIES' AND
               fax.contact_point_type = 'PHONE' AND
               fax.phone_line_type = 'FAX' AND
               hzp.party_id = email.owner_table_id AND
               email.owner_table_name = 'HZ_PARTIES' AND
               email.contact_point_type = 'EMAIL' AND
               hzp.party_id = url.owner_table_id AND
               url.owner_table_name = 'HZ_PARTIES' AND
               url.contact_point_type = 'WEB') len
 WHERE  ph.org_id = len.operating_unit
   and PH.TYPE_LOOKUP_CODE = 'BLANKET'
   AND PH.PO_HEADER_ID = PR.PO_HEADER_ID
   AND VN.VENDOR_ID(+) = PH.VENDOR_ID
   AND PVS.VENDOR_SITE_ID(+) = PH.VENDOR_SITE_ID
   AND PH.VENDOR_CONTACT_ID = PVC.VENDOR_CONTACT_ID(+)
   AND (PH.VENDOR_CONTACT_ID IS NULL OR
       PH.VENDOR_SITE_ID = PVC.VENDOR_SITE_ID)
   AND HRE.PERSON_ID = PR.AGENT_ID
   AND TRUNC(SYSDATE) BETWEEN HRE.EFFECTIVE_START_DATE AND
       HRE.EFFECTIVE_END_DATE
   AND PH.TERMS_ID = T.TERM_ID(+)
   AND FCC.CURRENCY_CODE = PH.CURRENCY_CODE
   AND FCC.LANGUAGE = USERENV('LANG')
   AND PLC1.LOOKUP_CODE(+) = PH.FOB_LOOKUP_CODE
   AND PLC1.LOOKUP_TYPE(+) = 'FOB'
   AND PLC1.VIEW_APPLICATION_ID(+) = 201
   AND PLC1.LANGUAGE(+) = USERENV('LANG')
   AND DECODE(PLC1.LOOKUP_CODE, NULL, 1, PLC1.SECURITY_GROUP_ID) =
       DECODE(PLC1.LOOKUP_CODE,
              NULL,
              1,
              FND_GLOBAL.LOOKUP_SECURITY_GROUP(PLC1.LOOKUP_TYPE,
                                               PLC1.VIEW_APPLICATION_ID))
   AND PLC2.LOOKUP_CODE(+) = PH.FREIGHT_TERMS_LOOKUP_CODE
   AND PLC2.LOOKUP_TYPE(+) = 'FREIGHT TERMS'
   AND PLC2.VIEW_APPLICATION_ID(+) = 201
   AND PLC2.LANGUAGE(+) = USERENV('LANG')
   AND DECODE(PLC2.LOOKUP_CODE, NULL, 1, PLC2.SECURITY_GROUP_ID) =
       DECODE(PLC2.LOOKUP_CODE,
              NULL,
              1,
              FND_GLOBAL.LOOKUP_SECURITY_GROUP(PLC2.LOOKUP_TYPE,
                                               PLC2.VIEW_APPLICATION_ID))
   AND PVS.COUNTRY = FTE3.TERRITORY_CODE(+)
   AND DECODE(FTE3.TERRITORY_CODE, NULL, '1', FTE3.LANGUAGE) =
       DECODE(FTE3.TERRITORY_CODE, NULL, '1', USERENV('LANG'))
   AND PLC3.LOOKUP_CODE(+) = PR.SHIPPING_CONTROL
   AND PLC3.LOOKUP_TYPE(+) = 'SHIPPING CONTROL'
   AND PLC3.LANGUAGE(+) = USERENV('LANG')
   AND PLC3.VIEW_APPLICATION_ID(+) = 201
   AND DECODE(PLC3.LOOKUP_CODE, NULL, 1, PLC3.SECURITY_GROUP_ID) =
       DECODE(PLC3.LOOKUP_CODE,
              NULL,
              1,
              FND_GLOBAL.LOOKUP_SECURITY_GROUP(PLC3.LOOKUP_TYPE,
                                               PLC3.VIEW_APPLICATION_ID))
   AND OFC.FREIGHT_CODE(+) = PH.SHIP_VIA_LOOKUP_CODE
   AND OFC.ORGANIZATION_ID(+) = PH.ORG_ID
   AND PA.AGENT_ID = PR.AGENT_ID;
