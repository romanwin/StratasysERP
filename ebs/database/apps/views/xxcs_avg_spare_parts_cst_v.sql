CREATE OR REPLACE VIEW XXCS_AVG_SPARE_PARTS_CST_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_AVG_SPARE_PARTS_CST_V
--  create by:       Yoram Zamir
--  Revision:        1.4
--  creation date:   04/07/2010
--------------------------------------------------------------------
--  purpose :       Discoverer Reports this view replaces XXCS_AVG_SPARE_PARTS_COST_V
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  04/07/2010  Yoram Zamir      initial build
--  1.1  08/07/2010  Yoram Zamir      Value set CS_REGION_TYPE replace the field xxcs_cs_region_type with the field xxcs_cs_region_type_reports
--  1.2  11/07/2010  Yoram Zamir      contract_type added (CONT sub-select added);  new condition incident_type<>'RMA' was added
--  1.3  21/02/2011  Roman            Chnaged validation of second query in IB table
--  1.4  28/02/2011  Roman            RMA excluded only for Indirect customers
--------------------------------------------------------------------
       SR2SN.operating_unit operating_unit,
       SR2SN.region,
       SR2SN.item_category,
       SR2SN.instance_id,
       SR2SN.customer_id,
       SR2SN.currency_code,
       SR2SN.serial_number,
       SR2SN.customer,
       SR2SN.customer_type,
       decode(SR2SN.customer_type,'DIRECT',SR2SN.factor          ,0)    TOTAL_FACTOR_DIRECT,
       decode(SR2SN.customer_type,'INDIRECT',SR2SN.factor        ,0)    TOTAL_FACTOR_INDIRECT,
       decode(SR2SN.customer_type,'NO CUSTOMER TYPE',SR2SN.factor,0)    TOTAL_FACTOR_NO_CUST_TYPE,
       SR2SN.factor                                                     TOTAL_FACTOR,
       NVL(CONT.contract_or_warranty, 'T&M')                           CONTRACT_TYPE,
       --ib.factor,
-----------------------------------------------------------------------------------
       NVL(SR2SN.TOTAL_COST_DIRECT,0)                TOTAL_COST_DIRECT,
       NVL(SR2SN.TOTAL_COST_INDIRECT,0)              TOTAL_COST_INDIRECT,
       NVL(SR2SN.TOTAL_COST_NO_CUST_TYPE,0)          TOTAL_COST_NO_CUST_TYPE,
       NVL(SR2SN.TOTAL_COST,0)                       TOTAL_COST,
       NVL(SR2SN.TOTAL_COST_HEADS_DIRECT,0)          TOTAL_COST_HEADS_DIRECT,
       NVL(SR2SN.TOTAL_COST_MATERIAL_DIRECT,0)       TOTAL_COST_MATERIAL_DIRECT,
       NVL(SR2SN.TOTAL_COST_HEADS_INDIRECT,0)        TOTAL_COST_HEADS_INDIRECT,
       NVL(SR2SN.TOTAL_COST_MATERIAL_INDIRECT,0)     TOTAL_COST_MATERIAL_INDIRECT,
       NVL(SR2SN.TOTAL_CST_HEADS_NOCUST_TYP,0)       TOTAL_CST_HEADS_NOCUST_TYP,
       NVL(SR2SN.TOTAL_CST_MATERIAL_NOCUST_TYP,0)    TOTAL_CST_MATERIAL_NOCUST_TYP,
       NVL(SR2SN.TOTAL_COST_HEADS,0)                 TOTAL_COST_HEADS,
       NVL(SR2SN.TOTAL_COST_MATERIAL,0)              TOTAL_COST_MATERIAL

FROM    (SELECT
        ----There are SR's for these printers
               ch.operating_unit            operating_unit,
               ch.customer_id               customer_id,
               nvl(ch.region, 'No Region')  region,
               --ch.cs_region_type,
               ch.item_category,
               ch.instance_id,
               ch.item_cost_cur_code        currency_code,
               ch.serial_number,
               ch.customer,
               decode(ch.cs_region_type,NULL,'NO CUSTOMER TYPE',ch.cs_region_type)   customer_type,
               trunc(ch.printer_install_date)                                        printer_install_date,
               trunc(ch.printer_active_end_date)                                     printer_active_end_date,
               SUM(decode(nvl(ch.cs_region_type,'NO CUSTOMER TYPE'),'DIRECT',ch.qty * ch.item_cost,0))            TOTAL_COST_DIRECT,
               SUM(decode(nvl(ch.cs_region_type,'NO CUSTOMER TYPE'),'INDIRECT',ch.qty * ch.item_cost,0))          TOTAL_COST_INDIRECT,
               SUM(decode(nvl(ch.cs_region_type,'NO CUSTOMER TYPE'),'NO CUSTOMER TYPE',ch.qty * ch.item_cost,0))  TOTAL_COST_NO_CUST_TYPE,
               SUM(ch.qty * ch.item_cost)     TOTAL_COST,
               SUM(decode(ch.billing_type,'Heads',   decode(nvl(ch.cs_region_type,'NO CUSTOMER TYPE'),'DIRECT',ch.qty * ch.item_cost,0)))   TOTAL_COST_HEADS_DIRECT,
               SUM(decode(ch.billing_type,'Material',decode(nvl(ch.cs_region_type,'NO CUSTOMER TYPE'),'DIRECT',ch.qty * ch.item_cost,0)))   TOTAL_COST_MATERIAL_DIRECT,
               SUM(decode(ch.billing_type,'Heads',   decode(nvl(ch.cs_region_type,'NO CUSTOMER TYPE'),'INDIRECT',ch.qty * ch.item_cost,0))) TOTAL_COST_HEADS_INDIRECT,
               SUM(decode(ch.billing_type,'Material',decode(nvl(ch.cs_region_type,'NO CUSTOMER TYPE'),'INDIRECT',ch.qty * ch.item_cost,0))) TOTAL_COST_MATERIAL_INDIRECT,
               SUM(decode(ch.billing_type,'Heads',   decode(nvl(ch.cs_region_type,'NO CUSTOMER TYPE'),'NO CUSTOMER TYPE',ch.qty * ch.item_cost,0))) TOTAL_CST_HEADS_NOCUST_TYP,
               SUM(decode(ch.billing_type,'Material',decode(nvl(ch.cs_region_type,'NO CUSTOMER TYPE'),'NO CUSTOMER TYPE',ch.qty * ch.item_cost,0))) TOTAL_CST_MATERIAL_NOCUST_TYP,
               SUM(decode(ch.billing_type,'Heads',   (ch.qty * ch.item_cost))) TOTAL_COST_HEADS,
               SUM(decode(ch.billing_type,'Material',(ch.qty * ch.item_cost))) TOTAL_COST_MATERIAL,

               xxcs_mtb_report_pkg.get_factor_for_sr_statistics(XXCS_SESSION_PARAM.get_session_param_date(1),  ---p_from_date
                                                                XXCS_SESSION_PARAM.get_session_param_date(2),  ---p_to_date
                                                                trunc(ch.printer_install_date),
                                                                trunc(ch.printer_active_end_date))   factor
        FROM   XXCS_SR_CHARGES_REP_V   ch,
        (SELECT FFV.FLEX_VALUE, FFV.ATTRIBUTE10 FV_REGION
           FROM FND_FLEX_VALUES FFV
          WHERE FFV.FLEX_VALUE_SET_ID = 1014107) FV
        WHERE  /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-JAN-2009','DD-MON-YYYY'),1)=1
        AND    XXCS_SESSION_PARAM.set_session_param_date(to_date('31-DEC-2009','DD-MON-YYYY'),2)=1 AND*/
               ch.billing_type IN ('Material', 'Heads')
        AND    fv.flex_value = ch.region
        AND    ((nvl(fv.fv_region,'Direct') = 'Indirect' AND ch.incident_type<>'RMA') OR nvl(fv.fv_region,'Direct') = 'Direct')
        --AND    ch.incident_type<> 'RMA'
        AND    ch.qty          > 0
        AND    ch.region       <> 'Internal'
        AND    ch.incident_occurred_date between XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
                                             and XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
        GROUP BY
                 ch.operating_unit,
                 ch.customer_id ,
                 nvl(ch.region, 'No Region'),
                 --ch.cs_region_type,
                 ch.item_category,
                 ch.instance_id,
                 ch.item_cost_cur_code,
                 ch.serial_number,
                 ch.customer,
                 decode(ch.cs_region_type,NULL,'NO CUSTOMER TYPE',ch.cs_region_type),
                 trunc(ch.printer_install_date),
                 trunc(ch.printer_active_end_date),
                 xxcs_mtb_report_pkg.get_factor_for_sr_statistics(XXCS_SESSION_PARAM.get_session_param_date(1),  ---p_from_date
                                                                  XXCS_SESSION_PARAM.get_session_param_date(2),  ---p_to_date
                                                                  ch.printer_install_date,
                                                                  ch.printer_active_end_date)

        UNION ALL
        SELECT  ---There are NO SR's for these printers
            org.name                           operating_unit,
            cii.owner_party_id                 customer_id,
            nvl(cii.attribute8,'No Region')    region,
            --CS_REGION_TYPE.xxcs_cs_region_type cs_region_type,
            mtc.segment3                       item_category,
            cii.instance_id,
            'USD'                              currency_code,
            cii.serial_number,
            hzp.party_name                     customer,
            decode(CS_REGION_TYPE.xxcs_cs_region_type,NULL,'NO CUSTOMER TYPE',CS_REGION_TYPE.xxcs_cs_region_type)     customer_type,
            trunc(cii.install_date)                                               printer_install_date,
            trunc(nvl(cii.active_end_date,to_date('31-JAN-3049','DD-MON-YYYY')))  printer_active_end_date,
            0 TOTAL_COST_DIRECT,
            0 TOTAL_COST_INDIRECT,
            0 TOTAL_COST_NO_CUST_TYPE,
            0 TOTAL_COST,
            0 TOTAL_COST_HEADS_DIRECT,
            0 TOTAL_COST_MATERIAL_DIRECT,
            0 TOTAL_COST_HEADS_INDIRECT,
            0 TOTAL_COST_MATERIAL_INDIRECT,
            0 TOTAL_CST_HEADS_NOCUST_TYP,
            0 TOTAL_CST_MATERIAL_NOCUST_TYP,
            0 TOTAL_COST_HEADS,
            0 TOTAL_COST_MATERIAL,
            xxcs_mtb_report_pkg.get_factor_for_sr_statistics(XXCS_SESSION_PARAM.get_session_param_date(1),  ---p_from_date
                                                             XXCS_SESSION_PARAM.get_session_param_date(2),  ---p_to_date
                                                             trunc(cii.install_date),   -----printer_install_date
                                                             trunc(nvl(cii.active_end_date,to_date('31-JAN-3049','DD-MON-YYYY'))) ---printer_active_end_date
                                                            )   factor
        FROM csi_item_instances              cii,
             mtl_system_items_b              msi,
             hz_parties                      hzp,
             hr_operating_units              ORG,
             mtl_item_categories             mic,
             mtl_categories_b                mtc,
             (SELECT
                         ffvv.FLEX_VALUE,
                         ffvv.FLEX_VALUE_MEANING,
                         ffvv.ENABLED_FLAG,
                         ffvv.START_DATE_ACTIVE,
                         ffvv.END_DATE_ACTIVE,
                         ffvv.FLEX_VALUE_SET_ID,
                         ffvv.FLEX_VALUE_ID,
                         ffvv.VALUE_CATEGORY,
                         upper(ffvd.xxcs_cs_region_type_reports) xxcs_cs_region_type
                  FROM   FND_FLEX_VALUES_VL  ffvv,
                         fnd_flex_values_dfv ffvd
                  WHERE  ffvv.FLEX_VALUE_SET_ID = 1014107 --XXCS_CS_REGIONS
                  AND    ffvv.ROW_ID = ffvd.row_id
                  AND    ffvv.ENABLED_FLAG = 'Y'
                  AND    SYSDATE BETWEEN nvl(ffvv.START_DATE_ACTIVE, SYSDATE) AND nvl(ffvv.END_DATE_ACTIVE, SYSDATE)
                       ) CS_REGION_TYPE
        WHERE  /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-DEC-2009','DD-MON-YYYY'),1)=1
           AND XXCS_SESSION_PARAM.set_session_param_date(to_date('31-DEC-2009','DD-MON-YYYY'),2)=1 AND */
               cii.inventory_item_id = msi.inventory_item_id
           AND cii.attribute8        = CS_REGION_TYPE.FLEX_VALUE (+)
           AND cii.install_date        IS NOT NULL
           AND cii.attribute8        <> 'Internal' /*cs_region */
           AND msi.organization_id   = 91
           AND mic.inventory_item_id = msi.inventory_item_id
           AND mic.organization_id   = msi.organization_id
           AND mic.organization_id   = 91
           AND mic.category_set_id   = 1100000041
           AND mtc.category_id       = mic.category_id
           AND mtc.enabled_flag      = 'Y'
           AND cii.owner_party_id    = hzp.party_id
           AND org.organization_id(+)= nvl(hzp.attribute3,-99)
           AND msi.comms_nl_trackable_flag = 'Y'
           AND (mtc.attribute4 = 'PRINTER'
               OR
               mic.CATEGORY_ID = 7127 /*"Water Jet"*/)
           AND NOT EXISTS
               /*(SELECT *                     --Roman 21/02/2011
                FROM cs_incidents_all_b sr
                WHERE\* XXCS_SESSION_PARAM.set_session_param_date(to_date('01-DEC-2009','DD-MON-YYYY'),1)=1
                AND XXCS_SESSION_PARAM.set_session_param_date(to_date('31-DEC-2009','DD-MON-YYYY'),2)=1
                AND *\cii.instance_id = sr.customer_product_id
                AND sr.incident_occurred_date BETWEEN
                    XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
                AND XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
               )*/
               (SELECT 1
                 FROM   XXCS_SR_CHARGES_REP_V   ch,
                        (SELECT FFV.FLEX_VALUE, FFV.ATTRIBUTE10 FV_REGION
                           FROM FND_FLEX_VALUES FFV
                          WHERE FFV.FLEX_VALUE_SET_ID = 1014107) FV
                WHERE  /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-JAN-2009','DD-MON-YYYY'),1)=1
                AND    XXCS_SESSION_PARAM.set_session_param_date(to_date('31-DEC-2009','DD-MON-YYYY'),2)=1 AND*/
                       ch.billing_type IN ('Material', 'Heads')
                AND    fv.flex_value = ch.region
                AND    ((nvl(fv.fv_region,'Direct') = 'Indirect' AND ch.incident_type<>'RMA') OR nvl(fv.fv_region,'Direct') = 'Direct')
                AND    ch.instance_id = cii.instance_id
                --AND    ch.incident_type <> 'RMA'
                AND    ch.qty          > 0
                AND    ch.region       <> 'Internal'
                AND    ch.incident_occurred_date between XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
                                                     and XXCS_SESSION_PARAM.get_session_param_date(2))  ---p_to_date
                          ) SR2SN,
      (SELECT  gg.party_id,
               gg.instance_id,
               gg.contract_or_warranty,
               gg.line_start_date,
               gg.line_end_date,
               gg.rank
       FROM (SELECT
               zz.party_id,
               zz.instance_id,
               zz.contract_or_warranty,
               zz.line_start_date,
               zz.line_end_date,
               DENSE_RANK() OVER (PARTITION BY zz.party_id,zz.instance_id ORDER BY zz.line_end_date DESC) rank
        FROM  xxcs_inst_contr_and_warr_all_v  zz
        WHERE zz.status = 'ACTIVE'
        AND   (XXCS_SESSION_PARAM.get_session_param_date(1)+
       (XXCS_SESSION_PARAM.get_session_param_date(2)- XXCS_SESSION_PARAM.get_session_param_date(1))/2)
              BETWEEN zz.line_start_date AND nvl(zz.line_date_terminated,zz.line_end_date)) GG
       WHERE  gg.rank = 1
                                      )  CONT
WHERE  SR2SN.instance_id=CONT.instance_id(+)
AND    SR2SN.customer_id=CONT.party_id(+);

