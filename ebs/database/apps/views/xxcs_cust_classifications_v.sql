CREATE OR REPLACE VIEW XXCS_CUST_CLASSIFICATIONS_V AS
SELECT
--------------------------------------------------------------------
--  customization code: CUST 776 CR1215 Customer support SF-OA interfaces
--  name:               XXOBJT_OA2SF_CATEGORY_V
--  create by:          YUVAL TAL
--  $Revision:          1.0
--  creation date:      16.1.14
--  Description:        CR1215 Customer support SF-OA interfaces
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   ?????/        ???             initial
--  1.0   16.1.14       yuval tal       CR1215 Customer support SF-OA interfaces : add last_update_date,creation_date
--------------------------------------------------------------------
              hp.party_id,
              hp.party_number,
              hp.party_name,
              ca.class_code,
              lu.MEANING,
              ca.CREATION_DATE,
              ca.last_update_date
FROM          hz_parties hp,
              hz_code_assignments ca,
              hz_classcode_relations_v lu
WHERE         hp.party_id = ca.owner_table_id (+) AND
              ca.class_category =  'Objet Business Type' AND
              hp.party_type = 'ORGANIZATION' AND
              ca.status = 'A' AND
              hp.status = 'A' AND
              SYSDATE BETWEEN ca.start_date_active AND nvl(ca.end_date_active, SYSDATE) AND
              lu.lookup_type = 'Objet Business Type' AND
              lu.language = 'US' AND
              ca.class_code = lu.LOOKUP_CODE;
