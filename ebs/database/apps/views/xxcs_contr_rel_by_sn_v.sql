CREATE OR REPLACE VIEW XXCS_CONTR_REL_BY_SN_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CONTR_REL_BY_SN_V
--  create by:       Izik
--  Revision:        1.1
--  creation date:   01/09/2009
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  01/09/2009  Izik             initial build
--  1.1  14/04/2010  Yoram Zamir      Replace S/N with instance id
--------------------------------------------------------------------
       cont.instance_id        instance_id,
       cont.serial_number      serial_number,
       cont.contract_id        contract_id,
       cont.contract_number    contract_number,
       cont.start_date         contract_start_date,
       cont.end_date           contract_end_date,
       lag(cont.contract_id,1)     over(partition by cont.instance_id order by(cont.end_date) desc) child_contract_id,
       lag(cont.contract_number,1) over(partition by cont.instance_id order by(cont.end_date) desc) child_contract_number,
       lag(cont.start_date,1)      over(partition by cont.instance_id order by(cont.end_date) desc) child_start_date,
       lag(cont.end_date,1)        over(partition by cont.instance_id order by(cont.end_date) desc) child_end_date
FROM   (SELECT DISTINCT  cii.serial_number,
                         okhab.id contract_id,
                         okhab.contract_number,
                         okhab.start_date,
                         okhab.end_date,
                         cii.instance_id
        FROM             okc_k_headers_all_b okhab,
                         okc_k_lines_b       lines,
                         okc_k_lines_b       sub_lines,
                         csi_item_instances  cii,
                         okc_k_items         oki
        WHERE            okhab.id = lines.chr_id
          and            lines.id = sub_lines.cle_id
          and            sub_lines.id = oki.cle_id
          and            oki.object1_id1 = cii.instance_id
        ORDER BY         1,5 DESC) CONT;

