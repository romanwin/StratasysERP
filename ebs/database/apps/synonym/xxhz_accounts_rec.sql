create or replace type xxobjt.xxhz_accounts_rec FORCE AS OBJECT
(
---------------------------------------------------------------------------------
--  Name:            xxhz_accounts_rec
--  Created by:      Somnath Dawn
--  Revision:        1.0
-----------------------------------------------------------------------------------
-- Date:               Version         Name                  Remarks
------------------------------------------------------------------------------------
-- 12-DEC-2016          1.0            Somnath Dawn          GAP-297 - Record Type for creating Account
-- 30-JAN-2017          1.1            Adi Safin             CHG0040057 - Change xxcust --> xxobjt
-- 21-Dec-2017          1.2            Diptasurjya           CHG0042044 - Add SIC code field
-- 8-MAY-2018           1.3            Lingaraj Sarangi      INC0107689 -website Field Length Increased from 50 to 200
-- 4-Sep-2018           1.4            Lingaraj              CHG0043843 - SFDC to Oracle interface- add new field- customer category
------------------------------------------------------------------------------------
  source_reference_id VARCHAR2(50),
  account_id          NUMBER,
  account_name        VARCHAR2(240),--HZ_PARTIES.PARTY_NAME (VARCHAR2 360)
  account_number      VARCHAR2(50),
  account_name_local  VARCHAR2(240),--HZ_PARTIES.ORGANIZATION_NAME_PHONETIC (VARCHAR2 320)
  fax                 VARCHAR2(50),
  oracle_status       VARCHAR2(10),
  ou_id               NUMBER,
  industry            VARCHAR2(50),
  phone               VARCHAR2(50),
  website             VARCHAR2(200), --INC0107689 V1.3
  institution_type    VARCHAR2(50),
  cross_industry      VARCHAR2(50),
  duns_number         VARCHAR2(50),
  department          VARCHAR2(100),
  sic_code            VARCHAR2(30),  -- CHG0042044
  CATEGORY_CODE       VARCHAR2(50),  --CHG0043843
  oe_email_contact_point_id  NUMBER,
  oe_fax_contact_point_id    NUMBER,
  oe_mobile_contact_point_id NUMBER,
  oe_phone_contact_point_id  NUMBER,
  oe_web_contact_point_id    NUMBER,
  ERROR_CODE                 VARCHAR2(1),
  error_msg                  VARCHAR2(4000),
  contact_xxhz_contact_tab xxhz_contact_tab,
  site_xxhz_site_tab       xxhz_site_tab
)
/
create or replace type xxobjt.XXHZ_ACCOUNTS_tab is table of XXOBJT.XXHZ_ACCOUNTS_REC
/