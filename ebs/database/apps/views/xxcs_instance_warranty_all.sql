CREATE OR REPLACE VIEW XXCS_INSTANCE_WARRANTY_ALL AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INSTANCE_WARRANTY_ALL
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
                w.LINE_ID                       WARRANTY_LINE_ID,
                w.SERVICE                       WARRANTY_SERVICE,
                w.TYPE                          WARRANTY_TYPE,
                w.COVERAGE                      WARRANTY_COVERAGE,
                w.instance_id                   WARRANTY_INSTANCE_ID,
                w.INSTANCE_ITEM_DESC            WARRANTY_INSTANCE_ITEM_DESC,
                w.ITEM_REVISION                 WARRANTY_ITEM_REVISION,
                w.CONTRACT_NUMBER               WARRANTY_NUMBER,
                w.VERSION_NUMBER                WARRANTY_VERSION_NUMBER,
                w.STATUS                        WARRANTY_STATUS,
                w.start_date                    WARRANTY_START_DATE,
                w.end_date                      WARRANTY_END_DATE,
                w.LINE_STATUS                   WARRANTY_LINE_STATUS,
                w.LINE_START_DATE               WARRANTY_LINE_START_DATE,
                w.LINE_END_DATE                 WARRANTY_LINE_END_DATE,
                w."ID",w."LANGUAGE",w."SOURCE_LANG",w."SFWT_FLAG",w."NAME",w."COMMENTS",w."ITEM_DESCRIPTION",w."BLOCK23TEXT",w."CREATED_BY",w."CREATION_DATE",w."LAST_UPDATED_BY",w."LAST_UPDATE_DATE",w."LAST_UPDATE_LOGIN",w."SECURITY_GROUP_ID",w."OKE_BOE_DESCRIPTION",w."COGNOMEN"
           FROM XXCS_INST_CONTR_AND_WARR_ALL_V   w
          WHERE w.CONTRACT_OR_WARRANTY='WARRANTY'
          AND   upper(w.status)      IN ('ACTIVE', 'EXPIRED')
          AND   upper(w.line_status) IN ('ACTIVE', 'EXPIRED');

