CREATE OR REPLACE VIEW XXCS_AVG_INSTAL_BY_PLATFORM_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_AVG_INSTAL_BY_PLATFORM_V
--  create by:       Vitaly.K
--  Revision:        1.0
--  creation date:   14/12/2009
--------------------------------------------------------------------
--  purpose :        Disco Report:  XX: AVG For Instalation
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  14/12/2009  Vitaly           initial build
--  1.1  XX/XX/XXXX
--
--------------------------------------------------------------------
    avgi.family,
    avgi.region,
    avgi.item_category,
    COUNT(avgi.incident_number)     sr_count,
    SUM(avgi.SUM_H)                 sum_hours,
    round(SUM(avgi.SUM_H)/8,4)      sum_days,
    round(SUM(avgi.SUM_H)/COUNT(avgi.incident_number),4)       avg_hours,
    round(SUM(avgi.SUM_H)/(COUNT(avgi.incident_number)*8),4)   avg_days
from XXCS_AVG_INSTALATION_ALL_V  avgi
GROUP BY avgi.family,
         avgi.region,
         avgi.item_category;

