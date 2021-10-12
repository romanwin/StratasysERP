CREATE OR REPLACE VIEW XXCS_ENG_SUBINV_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CUSTOMER_ADDRESSES_V
--  create by:       Vitaly.K
--  Revision:        1.3
--  creation date:   01/09/2009
--------------------------------------------------------------------
--  purpose :      Disco Reports
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  01/09/2009  Vitaly            initial build
--  1.1  10/12/2009  Vitaly            subinventory description was added
--  1.2  09/03/2010  Vitaly            Operating_Unit was added
--  1.3  15/06/2010  Vitaly            org_id and security by OU were added
--  1.4  16/02/2014  Adi Safin         add join condition in order to distinguish same warehouse in different organizations
--------------------------------------------------------------------
         ou.name    operating_unit,
         ood.OPERATING_UNIT  org_id,
         a.organization_id,
         a.resource_id,
         r.resource_name,
         a.subinventory_code,
         t.description     subinv_desc,
         a.default_code,
         a.effective_date_start,
         a.effective_date_end,
         r.email,
         r.user_id,
         fu.user_name,
         fu.description
from     CSP_INV_LOC_ASSIGNMENTS       a,
         MTL_SECONDARY_INVENTORIES     t,
         ORG_ORGANIZATION_DEFINITIONS  ood,
         HR_OPERATING_UNITS            ou,
         XXCS_RESOURCES                r,
         FND_USER                      fu
WHERE    a.resource_id=r.resource_id
AND      r.user_id=fu.user_id
AND      a.subinventory_code=t.secondary_inventory_name
AND      t.organization_id = a.organization_id  -- 1.4  16/02/2014  Adi Safin  
AND      a.organization_id=ood.ORGANIZATION_ID(+)
AND      ood.OPERATING_UNIT=ou.organization_id(+)
AND      XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(ood.OPERATING_UNIT)='Y';
