CREATE MATERIALIZED VIEW xxcs_cti_customer_details_mv
REFRESH COMPLETE ON DEMAND
START WITH TO_DATE('06-02-2012 05:00:00', 'DD-MM-YYYY HH24:MI:SS') NEXT SYSDATE + 1/4  
AS
SELECT
--------------------------------------------------------------------
--  name:              XXCS_CTI_CUSTOMER_DETAILS_MV
--  create by:         Dalit A. Raviv
--  Revision:          1.0
--  creation date:     31/08/2011
--------------------------------------------------------------------
--  purpose :          View that show customer details fro CTI CUSt452
--
--  Apps Schema
--  CREATE SYNONYM xxcs_cti_customer_details_mv FOR xxobjt.xxcs_cti_customer_details_mv;
--  XXOBJT schema
--  grant select on XXOBJT.XXCS_CTI_CUSTOMER_DETAILS_MV to netcom;
--  drop MATERIALIZED VIEW xxcs_cti_customer_details_mv
--
--------------------------------------------------------------------
--  ver  date          name              desc
--  1.0  31/08/2011    Dalit A. Raviv    initial build
--  1.1  12/12/2011    Dalit A. Raviv    add union to person and customer data
--------------------------------------------------------------------
       party_rel.object_id party_id,                  -- l_customer_type := get_cust_type(l_party_id);
       obj.party_name                  customer_name, -- l_customer_name
       obj.party_number,                              -- p_customer_number
       sub.person_first_name,                         -- l_contact_first_name
       sub.person_last_name,                          -- l_contact_last_name
       phone_tab.phone_area_code||phone_tab.phone_number phone_number,
       rel.party_number                                  contact_party_number
       /*phone_tab.phone_area_code,
       phone_tab.phone_number,
       phone_tab.phone_extension*/
FROM   ar.hz_relationships             party_rel,
       ar.hz_parties                   obj,
       ar.hz_parties                   sub,
       ar.hz_parties                   rel,
      (select hcp.owner_table_id       party_id,
              hcp.primary_flag         primary_flag,
              hcp.phone_country_code   phone_country_code,
              hcp.phone_area_code      phone_area_code,
              hcp.phone_number         phone_number,
              hcp.phone_extension,
              hcp.phone_line_type
       from   ar.hz_contact_points     hcp
       where  hcp.owner_table_name     = 'HZ_PARTIES'
       and    hcp.status = 'A')        phone_tab
where party_rel.party_id               = rel.party_id
and   rel.party_type                   = 'PARTY_RELATIONSHIP'
and   rel.status                       is not null
and   party_rel.subject_id             = sub.party_id
and   sub.party_type                   = 'PERSON'
and   sub.status                       is not null
and   obj.party_type                   = 'ORGANIZATION'
and   obj.status                       = 'A'
and   obj.party_id                     = party_rel.object_id
and   party_rel.party_id               = phone_tab.party_id
--and   phone_tab.phone_area_code||phone_tab.phone_number = '111' --p_phone_number -- 0541234567;
union
-- Customer (party=ORGANIZATION) phone----
SELECT hp.party_id,                                   -- l_customer_type := get_cust_type(l_party_id);
       hp.party_name                   customer_name, -- l_customer_name
       hp.party_number,                               -- p_customer_number
       null                            person_first_name, -- l_contact_first_name
       null                            person_last_name,  -- l_contact_last_name
       phone_tab.phone_area_code||phone_tab.phone_number phone_number,
       null                                              contact_party_number
FROM   ar.hz_parties                   hp,
       (select hcp.owner_table_id      party_id,
               hcp.primary_flag        primary_flag,
               hcp.phone_country_code  phone_country_code,
               hcp.phone_area_code     phone_area_code,
               hcp.phone_number        phone_number,
               hcp.phone_extension,
               hcp.phone_line_type
        from   ar.hz_contact_points    hcp
        where  hcp.owner_table_name    = 'HZ_PARTIES'
        and    hcp.status = 'A')       phone_tab
where  hp.party_id                     = phone_tab.party_id -- phone_tab.owner_table_id
and    hp.party_type                   = 'ORGANIZATION'
and    hp.status                       = 'A'
union
-- CSE (party=Person) phone----
SELECT hp.party_id,                                       -- l_customer_type := get_cust_type(l_party_id);
       hp.party_name                   customer_name,     -- l_customer_name
       hp.party_number,                                   -- p_customer_number
       hp.person_first_name            person_first_name, -- l_contact_first_name
       hp.person_last_name             person_last_name,  -- l_contact_last_name
       phone_tab.phone_area_code||phone_tab.phone_number phone_number,
       null                                              contact_party_number
FROM   ar.hz_parties                   hp,
       HR.per_all_people_f             papf,
       (select hcp.owner_table_id      party_id,
               hcp.primary_flag        primary_flag,
               hcp.phone_country_code  phone_country_code,
               hcp.phone_area_code     phone_area_code,
               hcp.phone_number        phone_number,
               hcp.phone_extension,
               hcp.phone_line_type
        from   ar.hz_contact_points    hcp
        where  hcp.owner_table_name    = 'HZ_PARTIES'
        and    hcp.status = 'A')       phone_tab
where  hp.party_id                     = phone_tab.party_id -- phone_tab.owner_table_id
and    trunc(sysdate)                  between papf.effective_start_date and papf.effective_end_date
and    hp.person_identifier            = papf.person_id
and    hp.party_type                   = 'PERSON'
and    hp.status                       = 'A'
--and   phone_tab.phone_number = '9314235';
