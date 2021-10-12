CREATE OR REPLACE VIEW XXCS_CUSTOMER_PROPERTIES_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CUSTOMER_PROPERTIES_V
--  create by:       Vitaly K
--  Revision:        1.0
--  creation date:   01/03/2010
--------------------------------------------------------------------
--  purpose :        Discoverer Report "Profit and Loss"
--------------------------------------------------------------------
--  ver  date        name          desc
--  1.0  01/03/2010  Vitaly K      initial build
--  1.1  XX/XX/XXXX  Vitaly K
--------------------------------------------------------------------
       p.party_id,
       p.party_name,
       p_dfv.xxcustomer_operating_unit  org_id,
       ou.name              operating_unit
FROM   HZ_PARTIES           p,
       HZ_PARTIES_DFV       p_dfv,
       HR_OPERATING_UNITS   ou
WHERE  p.rowid              = p_dfv.row_id
AND    p_dfv.xxcustomer_operating_unit = ou.organization_id(+)
AND    p.party_type         = 'ORGANIZATION';

