CREATE OR REPLACE VIEW XXCS_AVG_INSTALATION_ALL_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_AVG_INSTALATION_ALL_V
--  create by:       Vitaly.K
--  Revision:        1.3
--  creation date:   14/12/2009
--------------------------------------------------------------------
--  purpose :        Disco Report:  XX: AVG For Instalation
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  14/12/2009  Vitaly           initial build
--  1.1  15/12/2009  Vitaly           XXCS_SESSION_PARAM.get_session_param_date(1) --- for parameter "From Date"
--                                and XXCS_SESSION_PARAM.get_session_param_date(2) --- for parameter "To Date"
--                                and XXCS_SESSION_PARAM.get_session_param_char(1) --- for parameter "Item For Parameter" were added
--  1.2  16/12/2009  Vitaly       (it.segment1||'   -   '||it.description) was replaced with (msi.segment1||'   -   '||msi.description)
--  1.3  06/06/2010  Vitaly       Security by OU was added.
--------------------------------------------------------------------
       ch.incident_id SR_ID,
       sr.incident_number,
       sr.external_attribute_1  region,
       mtc.segment2             family,
       mtc.segment3             item_category,
       trunc(sr.incident_occurred_date) incident_date,
       SUM(xxcs_mtb_report_pkg.convert_duration_uom(ch.unit_of_measure_code ,'HR',ch.quantity_required))    SUM_H,
       'HR' AS UOM
FROM   CS_INCIDENTS_ALL_B         sr,
       HZ_PARTIES                 hp,
       CS_CHARGE_DETAILS_V        ch,
       MTL_SYSTEM_ITEMS_B         it,
       CS_INCIDENT_STATUSES       st,
       CS_INCIDENT_TYPES          ty,
       MTL_ITEM_CATEGORIES        mic,
       MTL_CATEGORIES_B           mtc,
       MTL_SYSTEM_ITEMS_B         msi
WHERE  sr.incident_occurred_date >= XXCS_SESSION_PARAM.get_session_param_date(1) ---From Incident Date parameter
AND    sr.incident_occurred_date <= XXCS_SESSION_PARAM.get_session_param_date(2) -----To Incident Date parameter
AND   (msi.segment1||'   -   '||msi.description) = nvl(XXCS_SESSION_PARAM.get_session_param_char(1),  ---Item For Parameter
                                                    (msi.segment1||'   -   '||msi.description))
AND    XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(sr.org_id,hp.party_id)='Y'
AND    sr.customer_id=hp.party_id
AND    ch.inventory_item_id = it.inventory_item_id
AND    it.segment1 = 'WKHRS-ON-SITE'
AND    it.organization_id = 91
AND    ch.incident_id = sr.incident_id
AND    sr.incident_status_id = st.INCIDENT_STATUS_ID
AND    upper(st.name) IN ('CLOSED BY ENGINEER','COMPLETE','FSR CLOSED')
AND    nvl(st.END_DATE_ACTIVE, SYSDATE) >= SYSDATE
AND    sr.incident_type_id = ty.INCIDENT_TYPE_ID
AND    upper(ty.NAME) IN  ('INSTALLATION', 'FSR INSTALLATION')
AND    nvl(ty.END_DATE_ACTIVE, SYSDATE) >= SYSDATE
AND    sr.inventory_item_id  = mic.inventory_item_id
and    mtc.category_id       = mic.category_id
and    mic.inventory_item_id = msi.inventory_item_id
and    mic.organization_id   = msi.organization_id
and    mic.category_set_id   = 1100000041
and    mtc.enabled_flag      = 'Y'
and    msi.organization_id   = 91
GROUP BY ch.incident_id,
      sr.incident_number,
      sr.external_attribute_1,
      mtc.segment2,
      mtc.segment3,
      sr.incident_occurred_date;

