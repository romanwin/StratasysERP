CREATE OR REPLACE VIEW XXCS_INSTANCE_WARRANTY AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INSTANCE_WARRANTY
--  create by:       Yoram Zamir
--  Revision:        2.0
--  creation date:   03/09/2009
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  03/09/2009  Yoram Zamir      initial build
--  2.0  11/02/2010  Yoram Zamir      Revised version after data fix
--------------------------------------------------------------------
       WARR_TAB.WARRANTY_LINE_ID,
       WARR_TAB.WARRANTY_SERVICE,
       WARR_TAB.WARRANTY_TYPE,
       WARR_TAB.WARRANTY_COVERAGE,
       WARR_TAB.WARRANTY_INSTANCE_ID,
       WARR_TAB.WARRANTY_INSTANCE_ITEM_DESC,
       WARR_TAB.WARRANTY_ITEM_REVISION,
       WARR_TAB.WARRANTY_NUMBER,
       WARR_TAB.WARRANTY_VERSION_NUMBER,
       WARR_TAB.WARRANTY_STATUS,
       WARR_TAB.WARRANTY_START_DATE,
       WARR_TAB.WARRANTY_END_DATE,
       WARR_TAB.WARRANTY_LINE_STATUS,
       WARR_TAB.WARRANTY_LINE_START_DATE,
       WARR_TAB.WARRANTY_LINE_END_DATE,
       WARR_TAB.warranty_end_date_desc_rank
FROM (SELECT
       to_char(wr.WARRANTY_LINE_ID) WARRANTY_LINE_ID,
       wr.WARRANTY_SERVICE,
       wr.WARRANTY_TYPE,
       wr.WARRANTY_COVERAGE,
       wr.WARRANTY_INSTANCE_ID,
       wr.WARRANTY_INSTANCE_ITEM_DESC,
       wr.WARRANTY_ITEM_REVISION,
       wr.WARRANTY_NUMBER,
       wr.WARRANTY_VERSION_NUMBER,
       wr.WARRANTY_STATUS,
       wr.WARRANTY_START_DATE,
       wr.WARRANTY_END_DATE,
       wr.WARRANTY_LINE_STATUS,
       wr.WARRANTY_LINE_START_DATE,
       wr.WARRANTY_LINE_END_DATE,
       DENSE_RANK() OVER (PARTITION BY wr.WARRANTY_INSTANCE_ID
                          ORDER BY decode(wr.WARRANTY_LINE_STATUS,'ACTIVE',1,2),
                                   wr.WARRANTY_LINE_END_DATE DESC,
                                   to_char(wr.WARRANTY_LINE_ID))  warranty_end_date_desc_rank
FROM   XXCS_INSTANCE_WARRANTY_ALL wr
                   )   WARR_TAB
WHERE  WARR_TAB.warranty_end_date_desc_rank=1;

