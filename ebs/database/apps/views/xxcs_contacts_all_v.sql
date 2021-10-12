CREATE OR REPLACE VIEW xxcs_contacts_all_v AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CONTACTS_ALL_V
--  create by:       Roman
--  Revision:        1.7
--  creation date:   28/07/2011
--------------------------------------------------------------------
--  purpose :        Disco Reports
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  28/07/2011  Roman            initial build
--  1.1  01/08/2011  Roman            Fixed outer join for Country
--  1.2  07/08/2011  Roman            Added Customer party_number
--  1.3  04/09/2011  Roman            Added statuses
--  1.4  11/03/2012  Dalit A. Raviv   add field contact_point_id
--  1.5  24/10/2012  Adi Safin        add WW_Global_Main_Contact,Site_Main_Contact,GAM_Contact fields
--  1.6  23/01/2013  Adi Safin        add 4 new fields for GAM site.
--  1.7  28/02/2013  Adi Safin        add primary flag for phone mobile and fax
--------------------------------------------------------------------
        oup.name                      perating_unit_party,
        party_rel.object_id           customer_id,
        party_rel.party_id            relationship_party_id,
        obj.party_name                customer_name,
        obj.party_number,
        ter.territory_short_name      country,
        null                          cust_account_id,
        null                          party_site_id,
        sub.person_first_name,
        sub.person_last_name,
        hoc.job_title,
        sub.creation_date,
        phone_tab.phone_country_code,
        phone_tab.phone_area_code,
        phone_tab.phone_number,
        phone_tab.phone_extension,
        phone_tab.primary_flag        phone_primary_flag,   --  1.7  28/02/2013  Adi Safin 
        mobile_tab.phone_country_code mobile_country_code,
        mobile_tab.phone_area_code    mobile_area_code,
        mobile_tab.phone_number       mobile_number,
        mobile_tab.phone_extension    mobile_extension,
        mobile_tab.primary_flag       mobile_primary_flag,  --  1.7  28/02/2013  Adi Safin 
        fax_tab.phone_country_code    fax_country_code,
        fax_tab.phone_area_code       fax_area_code,
        fax_tab.phone_number          fax_number,
        fax_tab.phone_extension       fax_extension,
        fax_tab.primary_flag          fax_primary_flag,     --  1.7  28/02/2013  Adi Safin 
        email_tab.email_address,
        sales_channel_tab.sales_channel_code,
        case when (select distinct 1
                   from xxcs_ib_customers_v v
                   where v.party_id = party_rel.object_id) > 0 then
               'Y'
             else
               'N'
        end                            ib_customer,
        party_rel.status               party_relationship_status,
        hcar.status                    account_contact_status,
        email_tab.email_contact_point_id,
        fax_tab.fax_contact_point_id,
        mobile_tab.mobile_contact_point_id,
        phone_tab.phone_contact_point_id,
        --  1.5  24/10/2012  Adi Safin
        hoc.attribute1                 WW_Global_Main_Contact,
        hoc.attribute2                 Site_Main_Contact,
        hoc.attribute3                 GAM_Contact,
        --  1.6  23/01/2013  Adi Safin
        rel.address1,
        rel.city,
        rel.state,
        rel.postal_code
        --
from    hz_relationships               party_rel,
        hz_org_contacts                hoc,
        hz_parties                     obj,
        hr_operating_units             oup,
        fnd_territories_tl             ter,
        hz_parties                     sub,
        hz_parties                     rel,
        ar_lookups                     ar,
        ar_lookups                     relm,
        xxcs_cust_classifications_v    v,
        hz_cust_account_roles          hcar,
        (select ca.party_id,
                max(ca.sales_channel_code) sales_channel_code
         from   hz_cust_accounts       ca
         where  ca.sales_channel_code  is not null
         group by ca.party_id)                          sales_channel_tab,
        (select hcp.owner_table_id     party_id,
                hcp.email_address,
                hcp.contact_point_id   email_contact_point_id
         from   hz_contact_points      hcp
         where  hcp.owner_table_name   = 'HZ_PARTIES'
         and    hcp.contact_point_type = 'EMAIL'
         and    hcp.email_address      is not null
         and    hcp.status             = 'A'
         and    hcp.primary_flag       = 'Y')           email_tab,
        (select hcp.owner_table_id     party_id,
                hcp.primary_flag,
                hcp.phone_country_code,
                hcp.phone_area_code,
                hcp.phone_number,
                hcp.phone_extension,
                hcp.phone_line_type,
                hcp.contact_point_id   fax_contact_point_id
         from   hz_contact_points      hcp
         where  hcp.owner_table_name   = 'HZ_PARTIES'
         and    hcp.phone_line_type    = 'FAX'
         and    hcp.status = 'A')                       fax_tab,
        (select hcp.owner_table_id     party_id,
                hcp.primary_flag,
                hcp.phone_country_code,
                hcp.phone_area_code,
                hcp.phone_number,
                hcp.phone_extension,
                hcp.phone_line_type,
                hcp.contact_point_id   mobile_contact_point_id
         from   hz_contact_points hcp
         where  hcp.owner_table_name   = 'HZ_PARTIES'
         and    hcp.phone_line_type    = 'MOBILE'
         and    hcp.status             = 'A')           mobile_tab,
        (select hcp.owner_table_id     party_id,
                hcp.primary_flag,
                hcp.phone_country_code,
                hcp.phone_area_code,
                hcp.phone_number,
                hcp.phone_extension,
                hcp.phone_line_type,
                hcp.contact_point_id   phone_contact_point_id
         from   hz_contact_points      hcp
         where  hcp.owner_table_name   = 'HZ_PARTIES'
         and    phone_line_type        = 'GEN'
         and    hcp.status             = 'A')           phone_tab
where   party_rel.party_id             = rel.party_id
and     party_rel.relationship_id      = hoc.party_relationship_id (+)
and     rel.party_type                 = 'PARTY_RELATIONSHIP'
and     rel.status                     is not null
and     party_rel.subject_id           = sub.party_id
and     sub.party_type                 = 'PERSON'
and     sub.status                     is not null
and     ar.lookup_type(+)              = 'CONTACT_TITLE'
and     sub.person_pre_name_adjunct    = ar.lookup_code(+)
and     relm.lookup_type(+)            = 'PARTY_RELATIONS_TYPE'
and     party_rel.relationship_code    = relm.lookup_code(+)
and     obj.party_type                 = 'ORGANIZATION'
and     obj.status                     = 'A'
and     obj.party_id                   = party_rel.object_id
and     party_rel.party_id             = phone_tab.party_id(+)
and     party_rel.party_id             = email_tab.party_id(+)
and     party_rel.party_id             = fax_tab.party_id(+)
and     party_rel.party_id             = mobile_tab.party_id(+)
and     ter.language (+)               = USERENV('LANG')
and     obj.country                    = ter.territory_code(+)
and     to_number(obj.attribute3)      = oup.organization_id(+)
and     obj.party_id                   = sales_channel_tab.party_id(+)
and     v.party_id                     = obj.party_id
and     v.class_code                   <> 'Subcontractor'
and     hcar.role_type (+)             = 'CONTACT'
and     hcar.party_id                  = party_rel.party_id (+)
and     xxcs_utils_pkg.check_security_by_oper_unit(to_number(obj.attribute3),party_rel.object_id) = 'Y';
