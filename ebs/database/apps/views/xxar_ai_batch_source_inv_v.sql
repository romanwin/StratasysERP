CREATE OR REPLACE VIEW XXAR_AI_BATCH_SOURCE_INV_V AS
SELECT name,
       max(description) description,
       max(batch_source_id) batch_source_id,
       max(org_id) org_id,
       'Y' get_all
  from ra_batch_sources_all RBS
 WHERE STATUS='A'
 group by name
UNION ALL
select name, description, batch_source_id, org_id, 'N' get_all
  from ra_batch_sources_all
 where STATUS='A';

