CREATE OR REPLACE VIEW XXCS_INSTANCE_OWNER_HISTORY_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INSTANCE_OWNER_HISTORY_V
--  create by:       Vitaly K
--  Revision:        1.4
--  creation date:   25/02/2010
--------------------------------------------------------------------
--  purpose :        Printers Owners History...Discoverer Report
--------------------------------------------------------------------
--  ver  date        name            desc
--  1.0  25/02/2010  Vitaly K        initial build
--  1.1  22/04/2010  Vitaly K        new revision
--  1.2  10/05/2010  Vitaly K        Install dates history was added
--  1.3  13/06/2010  Vitaly K        new revision
--  1.4  14/07/2010  Vitaly K        CASE for calculated_install_date was added
--------------------------------------------------------------------
       O_H_TAB.instance_id,
       O_H_TAB.party_id,
       O_H_TAB.party_name,
       O_H_TAB.ownership_date,
       O_H_TAB.end_date,
       O_H_TAB.item_type,
       O_H_TAB.history_rank,
       O_H_TAB.install_date,
       CASE
           WHEN O_H_TAB.install_date IS NULL                THEN  NULL
           WHEN O_H_TAB.ownership_date>O_H_TAB.install_date THEN  O_H_TAB.ownership_date
           ELSE O_H_TAB.install_date
           END      calculated_install_date
FROM ( SELECT
       OWNER_HIST.instance_id,
       OWNER_HIST.party_id,
       OWNER_HIST.party_name,
       OWNER_HIST.ownership_date,
       OWNER_HIST.end_date,
       OWNER_HIST.item_type,
       OWNER_HIST.history_rank,
      (SELECT install_date_hist.new_install_date
       FROM  CSI_ITEM_INSTANCES_H   install_date_hist
       WHERE  NOT (install_date_hist.new_install_date IS NULL AND install_date_hist.old_install_date IS NULL)
       AND    nvl(install_date_hist.new_install_date,SYSDATE-1) <>  nvl(install_date_hist.old_install_date,SYSDATE)
       AND    INSTALL_DATE_HIST.instance_id=OWNER_HIST.instance_id
       AND    INSTALL_DATE_HIST.creation_date < nvl(OWNER_HIST.end_date,SYSDATE)
       AND    INSTALL_DATE_HIST.creation_date= (SELECT MAX(INSTALL_DATE_HIST2.creation_date)
                                                FROM  CSI_ITEM_INSTANCES_H   install_date_hist2
                                                WHERE  NOT (install_date_hist2.new_install_date IS NULL AND install_date_hist2.old_install_date IS NULL)
                                                AND    nvl(install_date_hist2.new_install_date,SYSDATE-1) <>  nvl(install_date_hist2.old_install_date,SYSDATE)
                                                AND    INSTALL_DATE_HIST2.instance_id=OWNER_HIST.instance_id
                                                AND    INSTALL_DATE_HIST2.creation_date < nvl(OWNER_HIST.end_date,SYSDATE)
                                                )
                    )    install_date
FROM   XXCS_INSTANCE_OWNERSHIP_H_V   OWNER_HIST
                       )  O_H_TAB;

