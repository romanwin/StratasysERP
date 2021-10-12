CREATE OR REPLACE VIEW XXCS_INST_FIRST_CONTRACT_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INST_FIRST_CONTRACT_V
--  create by:       Yoram Zamir
--  Revision:        1.0
--  creation date:   02/05/2010
--------------------------------------------------------------------
--  purpose :        Discoverer Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  02/05/2010  Yoram Zamir      initial  build
--------------------------------------------------------------------
       HIST_TAB.instance_id,
       CONTR_TAB.serial_number,
       HIST_TAB.party_id,
       HIST_TAB.party_name,
       CONTR_TAB.line_start_date,
       CONTR_TAB.line_end_date
FROM (SELECT hist.instance_id,
             hist.party_id,
             hist.party_name
      FROM   XXCS_INSTANCE_OWNER_HISTORY_V   hist
      WHERE  hist.party_name!='Objet Internal Install Base'  ---party_id!=10041
      GROUP BY hist.instance_id,
             hist.party_id,
             hist.party_name )  HIST_TAB,
     (SELECT contr.instance_id,
             contr.instance_serial_number serial_number,
             contr.party_id,
             MIN(contr.line_start_date)  line_start_date,
             max(contr.line_end_date)    line_end_date
      FROM   XXCS_INST_CONTR_AND_WARR_ALL_V  contr
      WHERE  contr.contract_or_warranty='CONTRACT'
      GROUP BY contr.instance_id,
               contr.instance_serial_number,
               contr.party_id)  CONTR_TAB
WHERE  HIST_TAB.instance_id=CONTR_TAB.instance_id
AND    HIST_TAB.party_id   =CONTR_TAB.party_id;

