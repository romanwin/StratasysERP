CREATE OR REPLACE VIEW XXAGILE_MFG_OUTGING_V AS
SELECT rpad(s.vendor_name, 48, ' ') vendor_name,
       rpad(nvl(s.attribute10, 'Vendor'), 20, ' ') mfr_type,
       lpad(CASE nvl(s.end_date_active, SYSDATE + 1)
               WHEN SYSDATE + 1 THEN
                'Active'
               ELSE
                'Not Active'
            END,
            12,
            ' ') status, --Haggit alias
       rpad(nvl(ss.phone, ' '), 16, ' ') phone,
       rpad(nvl(ss.fax, ' '), 16, ' ') fax,
       rpad(nvl(ss.email_address, ' '), 48, ' ') email_address,
       lpad(nvl(ss.address_line1, ' '), 80, ' ') address_line1,
       lpad(ss.city || ' ' || ss.state, 40, ' ') city_state,
       rpad(nvl(ss.zip, ' '), 10, ' ') zip,
       rpad(nvl(ft.territory_short_name, ' '), 16, ' ') country,
       rpad(nvl(s.attribute13, ' '), 32, ' ') url,
       lpad(replace ((replace ((replace(nvl(trim(s.attribute3 || ' ' || s.attribute4 || ' ' || s.attribute5 || ' ' ||
            s.attribute6), ' '),'(')), ')')),','),
            32,
            ' ') technology,
       rpad(sc.person_first_name || ' ' || sc.person_last_name, 24, ' ') contact_name,
       rpad(nvl(sc.primary_phone_number, ' '), 16, ' ') contact_phone,
       rpad(nvl(sc.email_address, ' '), 48, ' ') contact_address, chr(13) last_col
  FROM ap_suppliers s,
       ap_supplier_sites_all ss,
       fnd_territories_vl ft,
       (SELECT hzr.object_id supplier_party_id,
               hp.party_id,
               hp.person_first_name,
               hp.person_last_name,
               hp.party_name,
               hcpe.email_address,
               ltrim(rtrim(hcpp.phone_area_code || ' ' || hcpp.phone_number || ' ' ||
                           hcpp.phone_extension)) AS primary_phone_number,
               nvl2(fu.user_name, 'UserAcct', 'N') AS is_user,
               hcpp.raw_phone_number
          FROM hz_parties               hp,
               fnd_user                 fu,
               hz_relationships         hzr,
               hz_party_usg_assignments hpua,
               hz_contact_points        hcpp,
               hz_contact_points        hcpe
         WHERE hp.party_id = hzr.subject_id AND
              --hzr.object_id = :1 AND -- Supplier Party
               hzr.relationship_type = 'CONTACT' AND
               hzr.relationship_code = 'CONTACT_OF' AND
               hzr.subject_type = 'PERSON' AND
               hzr.object_type = 'ORGANIZATION' AND
               hzr.status = 'A' AND
               fu.person_party_id(+) = hp.party_id AND
               hp.party_id NOT IN
               (SELECT contact_party_id
                  FROM pos_contact_requests pcr, pos_supplier_mappings psm
                 WHERE pcr.request_status = 'PENDING' AND
                       psm.mapping_id = pcr.mapping_id AND
                       psm.party_id = hzr.object_id AND
                       contact_party_id IS NOT NULL) AND
               hpua.party_id = hp.party_id AND
               hpua.status_flag = 'A' AND
               hpua.party_usage_code = 'SUPPLIER_CONTACT' AND
               hcpp.owner_table_name(+) = 'HZ_PARTIES' AND
               hcpp.owner_table_id(+) = hzr.party_id AND
               hcpp.phone_line_type(+) = 'GEN' AND
               hcpp.contact_point_type(+) = 'PHONE' AND
               hcpe.owner_table_name(+) = 'HZ_PARTIES' AND
               hcpe.owner_table_id(+) = hzr.party_id AND
               hcpe.contact_point_type(+) = 'EMAIL' AND
               hcpe.status(+) = 'A' AND
               hcpp.status(+) = 'A'
        UNION
        SELECT hzr.object_id supplier_party_id,
               hp.party_id,
               hp.person_first_name,
               hp.person_last_name,
               hp.party_name,
               hcpe.email_address,
               ltrim(rtrim(hcpp.phone_area_code || ' ' || hcpp.phone_number || ' ' ||
                           hcpp.phone_extension)) AS primary_phone_number,
               nvl2(fu.user_name, 'UserAcct', 'N') AS is_user,
               hcpp.raw_phone_number
          FROM hz_parties               hp,
               fnd_user                 fu,
               hz_relationships         hzr,
               pos_contact_requests     pcr,
               pos_supplier_mappings    psm,
               hz_party_usg_assignments hpua,
               hz_contact_points        hcpp,
               hz_contact_points        hcpe
         WHERE hp.party_id = hzr.subject_id AND
               hzr.relationship_type = 'CONTACT' AND
               hzr.relationship_code = 'CONTACT_OF' AND
               hzr.subject_type = 'PERSON' AND
               hzr.object_type = 'ORGANIZATION' AND
               hzr.status = 'A' AND
               fu.person_party_id(+) = hp.party_id AND
               hp.party_id = pcr.contact_party_id AND
               pcr.request_status = 'PENDING' AND
               psm.mapping_id = pcr.mapping_id AND
               psm.party_id = hzr.object_id AND
               pcr.request_type IN ('UPDATE', 'DELETE') AND
               hpua.party_id = hp.party_id AND
               hpua.status_flag = 'A' AND
               hpua.party_usage_code = 'SUPPLIER_CONTACT' AND
               hcpp.owner_table_name(+) = 'HZ_PARTIES' AND
               hcpp.owner_table_id(+) = hzr.party_id AND
               hcpp.phone_line_type(+) = 'GEN' AND
               hcpp.contact_point_type(+) = 'PHONE' AND
               hcpe.owner_table_name(+) = 'HZ_PARTIES' AND
               hcpe.owner_table_id(+) = hzr.party_id AND
               hcpe.contact_point_type(+) = 'EMAIL' AND
               hcpe.status(+) = 'A' AND
               hcpp.status(+) = 'A'
        UNION
        SELECT psm.party_id supplier_party_id,
               contact_party_id AS party_id,
               first_name AS person_first_name,
               last_name AS person_last_name,
               first_name || ' ' || last_name AS party_name,
               pcr.email_address,
               ltrim(rtrim(phone_area_code || ' ' || phone_number || ' ' ||
                           phone_extension)) AS primary_phone_number,
               nvl2(fu.user_name, 'UserAcct', 'N') AS is_user,
               pcr.phone_area_code || '-' || pcr.phone_number raw_phone_number
          FROM pos_contact_requests  pcr,
               fnd_user              fu,
               pos_supplier_mappings psm
         WHERE fu.person_party_id(+) = pcr.contact_party_id AND
               psm.mapping_id = pcr.mapping_id AND
               pcr.request_status = 'PENDING' AND
               pcr.request_type = 'ADD') sc
 WHERE s.vendor_id = ss.vendor_id AND
       s.party_id = sc.supplier_party_id(+) AND
       ss.country = ft.territory_code(+) AND
       s.attribute14 = 'Y';

