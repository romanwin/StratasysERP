CREATE OR REPLACE VIEW XXCS_CUST_CONTACTS_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CUST_CONTACTS_V
--  create by:       Vitaly.K
--  Revision:        1.7
--  creation date:   09/12/2009
--------------------------------------------------------------------
--  purpose :      Disco Reports
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  09/12/2009  Vitaly            initial build
--  1.1  07/03/2010  Vitaly            Region=NULL
--  1.2  08/03/2010  Vitaly            Operating_Unit_Party and Sales_Channel were added
--  1.3  09/06/2010  Vitaly            Security by OU was added
--  1.4  20/07/2010  Yoram Zair        Title was added
--  1.5  06/02/2011  Roman             Added contact creation_date
--  1.6  14/05/2011  Roman             Removed Subcontractors
--  1.7  16/05/2011  Roman             Added IB_Customer (Y/N) field
--------------------------------------------------------------------
       ----party level contacts
       party_rel.relationship_code     contact_type,
       'PARTY'                  CONTACT_LEVEL,
       PARTY_REL.OBJECT_ID      PARTY_ID,
       obj.party_name,
       obj.party_number,
       ---obj.attribute1           REGION,
       ''                       REGION,
       ter.territory_short_name COUNTRY,
       NULL                     CUST_ACCOUNT_ID,
       NULL                     PARTY_SITE_ID,
       sub.person_first_name,
       sub.person_last_name,
       sub.person_title title,
       sub.creation_date,
       PHONES_TAB.PRIMARY_FLAG,
       PHONES_TAB.PHONE_COUNTRY_CODE,
       PHONES_TAB.PHONE_AREA_CODE,
       PHONES_TAB.PHONE_NUMBER,
       PHONES_TAB.PHONE_EXTENSION,
       PHONES_TAB.PHONE_LINE_TYPE,
       PHONES_TAB.EMAIL_ADDRESS,
       oup.name                 operating_unit_party,
       SALES_CHANNEL_TAB.sales_channel_code,
       CASE WHEN (SELECT DISTINCT 1 FROM xxcs_ib_customers_v v WHERE v.party_id = PARTY_REL.OBJECT_ID) > 0 THEN 'Y' ELSE 'N' END IB_CUSTOMER
FROM   hz_relationships       party_rel,
       hz_parties             obj,
       hr_operating_units     oup,
       fnd_territories_tl     ter,
       Hz_parties             sub,
       hz_parties             rel,
       ar_lookups             ar,
       ar_lookups             relm,
       XXCS_CUST_CLASSIFICATIONS_V v,
    (SELECT ca.party_id,
            MAX(ca.sales_channel_code)   sales_channel_code
     FROM   hz_cust_accounts   ca
     WHERE  ca.sales_channel_code IS NOT NULL
     GROUP BY ca.party_id)                       SALES_CHANNEL_TAB,
    (select  HCP.OWNER_TABLE_ID  party_id,
             HCP.PRIMARY_FLAG,
             HCP.PHONE_COUNTRY_CODE,
             HCP.PHONE_AREA_CODE,
             HCP.PHONE_NUMBER,
             HCP.PHONE_EXTENSION,
             ---HCP.PHONE_LINE_TYPE,
             CASE
                WHEN HCP.EMAIL_ADDRESS IS NOT NULL THEN  'EMAIL'
                WHEN HCP.PHONE_LINE_TYPE='FAX'     THEN  'FAX'
                WHEN HCP.PHONE_LINE_TYPE='MOBILE'  THEN  'MOBILE'
                ELSE 'PHONE'
                END   PHONE_LINE_TYPE,
             HCP.EMAIL_ADDRESS
      from HZ_CONTACT_POINTS HCP
      where  hcp.OWNER_TABLE_NAME = 'HZ_PARTIES'
      and hcp.status = 'A')    PHONES_TAB
WHERE party_rel.party_id = rel.party_id
AND   rel.party_type = 'PARTY_RELATIONSHIP'
AND   rel.status IS NOT NULL
AND   party_rel.subject_id = sub.party_id
AND   sub.party_type = 'PERSON'
AND   sub.status IS NOT NULL
AND   ar.lookup_type(+) = 'CONTACT_TITLE'
AND   sub.person_pre_name_adjunct = ar.lookup_code(+)
AND   relm.lookup_type(+) = 'PARTY_RELATIONS_TYPE'
AND   party_rel.relationship_code = relm.lookup_code(+)
AND   obj.party_type='ORGANIZATION'
AND   obj.status='A'
AND   obj.party_id=PARTY_REL.OBJECT_ID
AND   party_rel.PARTY_ID=PHONES_TAB.party_id(+)
AND   ter.language=userenv('LANG')
AND   obj.country=ter.territory_code(+)
AND   to_number(obj.attribute3)=oup.organization_id(+)
AND   obj.party_id=SALES_CHANNEL_TAB.party_id(+)
AND   v.party_id = obj.party_id
AND   v.class_code <> 'Subcontractor'
AND   XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(to_number(obj.attribute3),PARTY_REL.OBJECT_ID)='Y'  ---org_id,party_id
UNION ALL
SELECT ---customer account and party site levels
       hr.relationship_code contact_type,
       decode(hps.party_site_id,NULL,'ACCOUNT','SITE')    CONTACT_LEVEL,
       hr.object_id    party_id,
       hpobj.party_name,
       hpobj.party_number,
       ---hpobj.attribute1           REGION,
       ''                         REGION,
       ter.territory_short_name   COUNTRY,
       hcar.cust_account_id,
       hps.party_site_id,
       hpsub.person_first_name,
       hpsub.person_last_name,
       hoc.job_title title,
       hpsub.creation_date,
       NULL  PRIMARY_FLAG,
       hprel.primary_phone_country_code,
       hprel.primary_phone_area_code,
       hprel.primary_phone_number,
       hprel.primary_phone_extension,
       hprel.primary_phone_line_type,
       hprel.email_address,
       oup.name                 operating_unit_party,
       SALES_CHANNEL_TAB.sales_channel_code,
       CASE WHEN (SELECT DISTINCT 1 FROM xxcs_ib_customers_v v WHERE v.party_id = hr.object_id) > 0 THEN 'Y' ELSE 'N' END IB_CUSTOMER
FROM   hz_cust_account_roles hcar,
       hz_parties            hpobj,
       hr_operating_units    oup,
       fnd_territories_tl    ter,
       hz_parties            hpsub,
       hz_parties            hprel,
       hz_org_contacts       hoc,
       hz_relationships      hr,
       hz_party_sites        hps,
       fnd_territories_vl    ftv,
       fnd_lookup_values_vl  lookups,
       XXCS_CUST_CLASSIFICATIONS_V v,
      (SELECT ca.party_id,
       MAX(ca.sales_channel_code)   sales_channel_code
     FROM   hz_cust_accounts   ca
     WHERE  ca.sales_channel_code IS NOT NULL
     GROUP BY ca.party_id)                       SALES_CHANNEL_TAB
WHERE  hcar.role_type = 'CONTACT'
AND    hcar.party_id = hr.party_id
AND    hr.party_id = hprel.party_id
AND    hr.subject_id = hpsub.party_id
AND    hr.object_id  = hpobj.party_id
AND    hoc.party_relationship_id = hr.relationship_id
AND    hr.directional_flag = 'F'
AND    hps.party_id(+) = hprel.party_id
AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
AND    nvl(hps.status, 'A') = 'A'
AND    hprel.country = ftv.territory_code(+)
AND    lookups.lookup_type(+) = 'RESPONSIBILITY'
AND    lookups.lookup_code(+) = hoc.job_title_code
AND    ter.language=userenv('LANG')
AND    hpobj.country=ter.territory_code(+)
AND    to_number(hpobj.attribute3)=oup.organization_id(+)
AND    hpobj.party_id=SALES_CHANNEL_TAB.party_id(+)
AND    v.party_id = hpobj.party_id
AND    v.class_code <> 'Subcontractor'
AND    XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(to_number(hpobj.attribute3),hpobj.party_id)='Y';

