CREATE OR REPLACE VIEW XXCS_IB_STATISTICS_MTXX_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_IB_STATISTICS_MTXX_V
--  create by:       Yoram Zamir
--  Revision:        1.15
--  creation date:   24/02/2010
--------------------------------------------------------------------
--  purpose :       Discoverer Reports REP266 - MTXX Reports
--                  late version of XXCS_IB_STATISTICS_V
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  24/02/2010  Yoram Zamir      initial build
--  1.1  08/03/2010  Vitaly           Operating_Unit_Party and Sales_Channel were added;
--  1.2  12/04/2010  Yoram Zamir      owner_hist.install_date IS NOT NULL -- Only installed printers
--  1.3  22/04/2010  Vitaly           Owner history changes
--  1.4  09/05/2010  Yoram Zamir      INSTALLED_DATE and ACTIVE_END_DATE for the 0 instance logic was changed
--  1.5  10/05/2010  Vitaly           Install date history was added
--  1.6  12/05/2010  Yoram Zamir      total_factor_for_period was added
--  1.7  13/05/2010  Yoram Zamir      Current_customer was added
--  1.8  17/05/2010  Vitaly K.        new revision with XXCS_IB_STATISTICS_DET_V
--  1.9  24/05/2010  Yoram Zamir      Correct the num_of_printers_per_customer
--  1.10 08/06/2010  Yoram Zamir      contract type
--  1.11 13/06/2010  Vitaly           nvl added    (nvl(EFF_IB.current_owner_cs_region, 'NO REGION') )
--  1.12 24/06/2010  Yoram Zamir      contract type logic (nvl on line date terminated)
--  1.13 24/06/2010  Vitaly           org_id was added
--  1.14 14/07/2010  Vitaly           printer_calc_install_date added
--  1.15 10/05/2012  Dalit A. Raviv/  Handle for upgrade printers.
--                   Yoram Zamir      call to xxcs_ib_history tbl instead of pipeline
--                                    this view is copy of XXCS_IB_STATISTICS_V and
--                                    have some changes - this is because this view is a major view.
--                                    and we want only to correct MTXX reports.
-- 1.16 16/01/2013   Adi Safin        Add Item_instance_type Column
--------------------------------------------------------------------
       EFF_IB.instance_id,
       EFF_IB.serial_number,
       EFF_IB.inventory_item_id,
       EFF_IB.printer,
       EFF_IB.printer_description,
       EFF_IB.family,
       EFF_IB.item_category,
       nvl(EFF_IB.current_owner_cs_region, 'NO REGION') current_owner_cs_region,
       EFF_IB.Current_customer,
       EFF_IB.end_customer,
       EFF_IB.Customer,
       EFF_IB.party_id,
       EFF_IB.refurbished_date,
       EFF_IB.org_id,
       EFF_IB.operating_unit_party,
       EFF_IB.sales_channel_code,
       EFF_IB.objet_internal_install_base, -- Y or N -- for LOV in Disco report only
       EFF_IB.factor,
       EFF_IB.printer_install_date,
       EFF_IB.printer_calc_install_date,   -- after CASE
       EFF_IB.printer_active_end_date,
       EFF_IB.total_factor_for_period,
       EFF_IB.count_printers,
       EFF_IB.num_of_printers_per_customer,
       EFF_IB.total_factor_per_customer,
       EFF_IB.weight_of_printer,
       NVL(CONT.contract_or_warranty, 'T&M') contract_type,
       flv2.meaning Item_instance_type --  1.16  13/01/2013  Adi Safin
FROM  (-- EFF_IB
       SELECT CNT_TAB.instance_id,
              CNT_TAB.serial_number,
              CNT_TAB.inventory_item_id,
              CNT_TAB.printer,
              CNT_TAB.printer_description,
              CNT_TAB.family,
              CNT_TAB.item_category,
              CNT_TAB.current_owner_cs_region,
              CNT_TAB.Current_customer,
              CNT_TAB.end_customer,
              CNT_TAB.Customer,
              CNT_TAB.party_id,
              CNT_TAB.refurbished_date,
              CNT_TAB.org_id,
              CNT_TAB.operating_unit_party,
              CNT_TAB.sales_channel_code,
              CNT_TAB.objet_internal_install_base, -- Y or N -- for LOV in Disco report only
              CNT_TAB.factor,
              CNT_TAB.printer_install_date,
              CNT_TAB.printer_calc_install_date,   -- after CASE
              CNT_TAB.printer_active_end_date,
              CNT_TAB.total_factor_for_period,
              CNT_TAB.count_printers,
              SUM(CNT_TAB.count_printers)
                  OVER (PARTITION BY CNT_TAB.Customer)    num_of_printers_per_customer,
              CNT_TAB.total_factor_per_customer,
              CNT_TAB.weight_of_printer
       FROM  ( -- CNT_TAB
              SELECT STAT_TAB.instance_id,
                     STAT_TAB.serial_number,
                     STAT_TAB.inventory_item_id,
                     STAT_TAB.printer,
                     STAT_TAB.printer_description,
                     STAT_TAB.family,
                     STAT_TAB.item_category,
                     STAT_TAB.current_owner_cs_region,
                     STAT_TAB.Current_customer,
                     STAT_TAB.end_customer,
                     STAT_TAB.Customer,
                     STAT_TAB.party_id,
                     STAT_TAB.refurbished_date,
                     STAT_TAB.org_id,
                     STAT_TAB.operating_unit_party,
                     STAT_TAB.sales_channel_code,
                     STAT_TAB.objet_internal_install_base, -- Y or N --for LOV in Disco report only
                     STAT_TAB.factor,
                     STAT_TAB.printer_install_date,
                     STAT_TAB.printer_calc_install_date,   -- after CASE
                     STAT_TAB.printer_active_end_date,
                     STAT_TAB.factor                                                                        total_factor_for_period,
                     (CASE WHEN
                          STAT_TAB.factor >0 THEN 1
                     ELSE 0
                     END) count_printers,
                     COUNT(*) OVER (PARTITION BY STAT_TAB.Customer)                                         num_of_printers_per_customer,
                     SUM(STAT_TAB.factor) OVER (PARTITION BY STAT_TAB.Customer)                             total_factor_per_customer,
                     decode(SUM(STAT_TAB.factor) OVER (PARTITION BY STAT_TAB.Customer),0,0,
                                STAT_TAB.factor/SUM(STAT_TAB.factor) OVER (PARTITION BY STAT_TAB.Customer)) weight_of_printer
              FROM (-- STAT_TAB
                    SELECT ibs.instance_id,
                           ibs.serial_number,
                           ibs.inventory_item_id,
                           ibs.printer,
                           ibs.printer_description,
                           ibs.family,
                           ibs.item_category,
                           ibs.current_owner_cs_region,
                           ibs.Current_customer,
                           ibs.end_customer,
                           ibs.Customer,
                           ibs.party_id,
                           ibs.refurbished_date,
                           ibs.org_id,
                           ibs.operating_unit_party,
                           ibs.sales_channel_code,
                           ibs.objet_internal_install_base,  -- Y or N -- for LOV in Disco report only
                           SUM(ibs.factor)       factor,
                           MIN(ibs.printer_install_date)       printer_install_date,
                           MAX(ibs.printer_calc_install_date)  printer_calc_install_date, -- after CASE
                           MAX(ibs.printer_active_end_date)    printer_active_end_date
                    FROM   XXCS_IB_STATISTICS_DET_MTXX_V       ibs --  1.15 10/05/2012
                    WHERE
                           --------------------------------------------------------------------------------------------
                           /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-JAN-2009','DD-MON-YYYY'),1)=1 AND
                           XXCS_SESSION_PARAM.set_session_param_date(to_date('31-DEC-2009','DD-MON-YYYY'),2)=1 AND*/
                           --------------------------------------------------------------------------------------------
                           nvl(ibs.printer_install_date, sysdate)< XXCS_SESSION_PARAM.get_session_param_date(2) +9999 -- p_to_date
                           AND  nvl(ibs.printer_install_date, sysdate)< XXCS_SESSION_PARAM.get_session_param_date(1) +9999 -- p_from_date
                    GROUP BY ibs.instance_id,
                             ibs.serial_number,
                             ibs.inventory_item_id,
                             ibs.printer,
                             ibs.printer_description,
                             ibs.family,
                             ibs.item_category,
                             ibs.current_owner_cs_region,
                             ibs.Current_customer,
                             ibs.end_customer,
                             ibs.Customer,
                             ibs.party_id,
                             ibs.refurbished_date,
                             ibs.org_id,
                             ibs.operating_unit_party,
                             ibs.sales_channel_code,
                             ibs.objet_internal_install_base
                   )  STAT_TAB
            ) CNT_TAB
      ) EFF_IB,
     (SELECT gg.party_id,
             gg.instance_id,
             gg.contract_or_warranty,
             gg.line_start_date,
             gg.line_end_date,
             gg.rank
      FROM  (SELECT  zz.party_id,
                     zz.instance_id,
                     zz.contract_or_warranty,
                     zz.line_start_date,
                     zz.line_end_date,
                     DENSE_RANK() OVER (PARTITION BY zz.party_id,zz.instance_id ORDER BY zz.line_end_date DESC) rank
             FROM    xxcs_inst_contr_and_warr_all_v  zz
             WHERE   zz.status                       = 'ACTIVE'
             AND     (XXCS_SESSION_PARAM.get_session_param_date(1)+
                     (XXCS_SESSION_PARAM.get_session_param_date(2)- XXCS_SESSION_PARAM.get_session_param_date(1))/2)
            BETWEEN zz.line_start_date AND nvl(zz.line_date_terminated,zz.line_end_date)
            ) GG
      WHERE  gg.rank = 1
     )  CONT,
     csi_item_instances cii ,--  1.16  13/01/2013  Adi Safin
     fnd_lookup_values  FLV2 --  1.16  13/01/2013  Adi Safin
WHERE  eff_ib.party_id    = cont.party_id (+)
AND    eff_ib.instance_id = cont.instance_id (+)
 -- Start 1.16 Adi Safin
AND  cii.instance_id = eff_ib.instance_id
AND nvl(cii.instance_type_code,'XXCS_STANDARD') = flv2.lookup_code
and flv2.language         ='US'
and flv2.lookup_type      ='CSI_INST_TYPE_CODE'
   -- End 1.16 Adi Safin;
