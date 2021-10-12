CREATE OR REPLACE VIEW XXCS_INSTANCE_OWNERSHIP_H_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INSTANCE_OWNERSHIP_H_V
--  create by:       Vitaly K
--  Revision:        1.1
--  creation date:   10/05/2010
--------------------------------------------------------------------
--  purpose :        Printers Ownership Periods (rank) History
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  10/05/2010  Vitaly K         initial build
--  1.1  17/05/20010 Vitaly K.        new revision
--------------------------------------------------------------------
       HIST_TAB.instance_id,
       HIST_TAB.party_id,
       HIST_TAB.party_number,
       HIST_TAB.party_name,
       HIST_TAB.ownership_date,  ---start
       HIST_TAB.end_date,        ---stop
       HIST_TAB.item,
       HIST_TAB.item_desc,
       HIST_TAB.item_type,
       HIST_TAB.party_hist_creation_date     creation_date,
       HIST_TAB.party_hist_transaction_id    transaction_id,
       HIST_TAB.history_rank
FROM (SELECT INSTANCE_ID,
             PARTY_ID,
             PARTY_NUMBER,
             PARTY_NAME,
             OWNERSHIP_DATE,    ---start
             END_DATE,    ---stop
             INSTANCE_ACTIVE_END_DATE,
             ITEM,
             ITEM_DESC,
             ITEM_TYPE,
             PARTY_HIST_TRANSACTION_ID,
             PARTY_HIST_CREATION_DATE,
             DENSE_RANK() OVER (PARTITION BY INSTANCE_ID
                                ORDER BY INSTANCE_ID,HISTORY_RANK DESC  NULLS LAST) -1      HISTORY_RANK
      FROM   TABLE (XXCS_ITEM_INSTANCE_PKG.get_instance_ownership_history(NULL))
                        )   HIST_TAB;

