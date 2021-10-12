create or replace view xxs3_email_contact_point_v as
select
--------------------------------------------------------------------
--  name:            XXS3_EMAIL_CONTACT_POINT_V
--  create by:       Debarati banerjee
--  revision:        1.0
--  creation date:   03/08/2016
--------------------------------------------------------------------
--  purpose :        View that show all contact points from type Email
--------------------------------------------------------------------
--  ver  date        name                 desc
--  1.0  03/08/2016  Debarati banerjee    initial build
--------------------------------------------------------------------
       email.contact_point_id   contact_point_id,
       email.owner_table_name   owner_table_name,
       email.owner_table_id     owner_table_id,
       email.contact_point_type contact_point_type,
       email.email_address      email_address,
       email.email_format       email_format,
       email.status             status,
       email.primary_flag       primary_flag,
       email.last_update_date,
       email.creation_date,
       ROW_NUMBER() OVER (PARTITION BY email.owner_table_id ORDER BY email.primary_flag desc,email.last_update_date desc ) email_rownum
from   hz_contact_points        email
where  email.owner_table_name   = 'HZ_PARTIES'
and    email.contact_point_type = 'EMAIL'
order by email.owner_table_id, email_rownum
/
