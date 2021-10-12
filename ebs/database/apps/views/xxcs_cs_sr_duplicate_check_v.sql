CREATE OR REPLACE VIEW XXCS_CS_SR_DUPLICATE_CHECK_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CS_SR_DUPLICATE_CHECK_V
--  create by:       XXX
--  Revision:        1.0
--  creation date:   xx/xx/2009
--------------------------------------------------------------------
--  purpose :
--------------------------------------------------------------------
--  ver  date        name          desc
--  1.0  xx/xx/2009  xx            initial build
--  1.1  31/12/2009  Roman         Incident Date was not correct - change to  incident_occurred_date
--------------------------------------------------------------------
       INC.INCIDENT_ID,
       INC.SUMMARY,
       STAT.NAME STATUS,
       inc.CREATION_DATE,
       INC.INCIDENT_NUMBER,
       INC.INCIDENT_OCCURRED_DATE,
       TYPE.NAME TYPE,
       FLV.DESCRIPTION PROBLEM_CODE,
       PARTY.PARTY_NAME,
       INC.CUSTOMER_PRODUCT_ID,
       INC.INVENTORY_ITEM_ID,
       TYPE.MAINTENANCE_FLAG,
       INC.INV_ORGANIZATION_ID
  FROM CS_INCIDENTS_ALL_VL     INC,
       CS_INCIDENT_STATUSES_VL STAT,
       CS_INCIDENT_TYPES_VL    TYPE,
       HZ_PARTIES              PARTY,
       fnd_lookup_values       flv
 WHERE INC.INCIDENT_STATUS_ID = STAT.INCIDENT_STATUS_ID
   AND INC.INCIDENT_TYPE_ID = TYPE.INCIDENT_TYPE_ID
   AND FLV.LOOKUP_TYPE = 'REQUEST_PROBLEM_CODE'
   AND FLV.LANGUAGE = 'US'
   AND FLV.LOOKUP_CODE = INC.PROBLEM_CODE
   AND INC.CUSTOMER_ID = PARTY.PARTY_ID
   ORDER BY INC.INCIDENT_OCCURRED_DATE desc;

