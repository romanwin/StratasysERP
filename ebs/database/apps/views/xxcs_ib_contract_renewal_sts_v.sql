CREATE OR REPLACE VIEW xxcs_ib_contract_renewal_sts_v AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_IB_CONTRACT_RENEWAL_STS_V
--  create by:       Yoram Zamir
--  Revision:        1.7
--  creation date:   20/06/2010
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  20/06/2010  Yoram Zamir      initial build
--  1.1  23/06/2010  Yoram Zamir      from_date and to_date logic was changed + 2 new fields begin/end line_date_terminated
--  1.2  20/06/2010  Yoram Zamir      org_id added;      security by OU and party_id added
--  1.3  28/11/2010  Roman            Added customer_type
--  1.4  01/12/2010  Roman            Added Marketing_classificatoin
--  1.5  31/01/2011  Roman            Modified From_Date for old contract to suport T&M logic of -60 days
--  1.6  14/02/2011  Dalit A. Raviv   Modified From_Date for old contract to suport T&M logic of -60 days
--  1.7  24/02/2010  Roman            Removed Terminated contracts
--  1.8  22/03/2012  Dalit A. Raviv   when Contract or service have ended, customer want to have GRACE time of 60 days
--                                    at this time of grace user ask not see these rows.
--  1.9  06/06/2012  Yoram Zamir      Replaced the view XXCS_IB_STATISTICS_V with xxcs_ib_statistics_mtxx_v
--------------------------------------------------------------------
        RENEWAL_C.party_id,
        RENEWAL_C.instance_id,
        RENEWAL_C.install_date,
        RENEWAL_C.serial_number,
        RENEWAL_C.inventory_item_id,
        RENEWAL_C.printer,
        RENEWAL_C.printer_description,
        RENEWAL_C.family,
        RENEWAL_C.item_category,
        RENEWAL_C.current_owner_cs_region,
        RENEWAL_C.Current_customer,
        RENEWAL_C.Customer,
        RENEWAL_C.end_customer,
        RENEWAL_C.org_id,
        RENEWAL_C.operating_unit_party,
        RENEWAL_C.sales_channel_code,
        RENEWAL_C.customer_type,
        RENEWAL_C.BEGIN_contract_number,
        RENEWAL_C.BEGIN_contract_or_warranty,
        RENEWAL_C.BEGIN_line_start_date,
        RENEWAL_C.BEGIN_line_end_date,
        RENEWAL_C.BEGIN_line_date_terminated,
        RENEWAL_C.BEGIN_service,
        RENEWAL_C.BEGIN_type,
        RENEWAL_C.BEGIN_coverage,
        RENEWAL_C.BEGIN_version_number,
        RENEWAL_C.BEGIN_line_subtotal_conv_usd,
        RENEWAL_C.BEGIN_modifier,
        RENEWAL_C.BEGIN_org_id,
        RENEWAL_C.BEGIN_operating_unit,
        RENEWAL_C.BEGIN_cs_region,
        RENEWAL_C.BEGIN_item_type,
        RENEWAL_C.BEGIN_account_name,
        RENEWAL_C.BEGIN_account_number,
        RENEWAL_C.BEGIN_invoiced,
        RENEWAL_C.END_contract_number,
        RENEWAL_C.END_contract_or_warranty,
        RENEWAL_C.END_line_start_date,
        RENEWAL_C.END_line_end_date,
        RENEWAL_C.END_line_date_terminated,
        RENEWAL_C.END_service,
        RENEWAL_C.END_type,
        RENEWAL_C.END_coverage,
        RENEWAL_C.END_version_number,
        RENEWAL_C.END_line_subtotal_conv_usd,
        RENEWAL_C.END_modifier,
        RENEWAL_C.END_org_id,
        RENEWAL_C.END_operating_unit,
        RENEWAL_C.END_cs_region,
        RENEWAL_C.END_item_type,
        RENEWAL_C.END_account_name,
        RENEWAL_C.END_account_number,
        RENEWAL_C.END_invoiced,
        RENEWAL_C.RENEWAL_STS,
        RENEWAL_C.begin_contract_type,
        RENEWAL_C.end_contract_type,
        RENEWAL_C.renewal_distance,
        COUNT (RENEWAL_C.instance_id) over (PARTITION BY RENEWAL_C.operating_unit_party,
                                                         RENEWAL_C.current_owner_cs_region,
                                                         RENEWAL_C.item_category,
                                                         RENEWAL_C.begin_contract_type) total_printers,
        RENEWAL_C.marketing_classification,
        --  1.8 22/03/2012  Dalit A. Raviv
        case when RENEWAL_C.BEGIN_line_end_date is null then
               'Y'
             when ((trunc(sysdate) - RENEWAL_C.BEGIN_line_end_date) < 60 ) then
               'N'
             else
               'Y'
        end show_row
        -- end 1.8 22/03/2012
        -- renewal_c
FROM   (SELECT  RENEWAL_B.party_id,
                RENEWAL_B.instance_id,
                RENEWAL_B.install_date,
                RENEWAL_B.serial_number,
                RENEWAL_B.inventory_item_id,
                RENEWAL_B.printer,
                RENEWAL_B.printer_description,
                RENEWAL_B.family,
                RENEWAL_B.item_category,
                RENEWAL_B.current_owner_cs_region,
                RENEWAL_B.Current_customer,
                RENEWAL_B.Customer,
                RENEWAL_B.end_customer,
                RENEWAL_B.org_id,
                RENEWAL_B.operating_unit_party,
                RENEWAL_B.sales_channel_code,
                RENEWAL_B.customer_type,
                RENEWAL_B.BEGIN_contract_number,
                RENEWAL_B.BEGIN_contract_or_warranty,
                RENEWAL_B.BEGIN_line_start_date,
                RENEWAL_B.BEGIN_line_end_date,
                RENEWAL_B.BEGIN_line_date_terminated,
                RENEWAL_B.BEGIN_service,
                RENEWAL_B.BEGIN_type,
                RENEWAL_B.BEGIN_coverage,
                RENEWAL_B.BEGIN_version_number,
                RENEWAL_B.BEGIN_line_subtotal_conv_usd,
                RENEWAL_B.BEGIN_modifier,
                RENEWAL_B.BEGIN_org_id,
                RENEWAL_B.BEGIN_operating_unit,
                RENEWAL_B.BEGIN_cs_region,
                RENEWAL_B.BEGIN_item_type,
                RENEWAL_B.BEGIN_account_name,
                RENEWAL_B.BEGIN_account_number,
                RENEWAL_B.BEGIN_invoiced,
                RENEWAL_B.END_contract_number,
                RENEWAL_B.END_contract_or_warranty,
                RENEWAL_B.END_line_start_date,
                RENEWAL_B.END_line_end_date,
                RENEWAL_B.END_line_date_terminated,
                RENEWAL_B.END_service,
                RENEWAL_B.END_type,
                RENEWAL_B.END_coverage,
                RENEWAL_B.END_version_number,
                RENEWAL_B.END_line_subtotal_conv_usd,
                RENEWAL_B.END_modifier,
                RENEWAL_B.END_org_id,
                RENEWAL_B.END_operating_unit,
                RENEWAL_B.END_cs_region,
                RENEWAL_B.END_item_type,
                RENEWAL_B.END_account_name,
                RENEWAL_B.END_account_number,
                RENEWAL_B.END_invoiced,
                --  1.6  14/02/2011  Dalit A. Raviv
                --RENEWAL_B.begin_contract_type,
                decode(RENEWAL_B.begin_contract_type,'T&M',XXCS_DISCO_PKG.get_early_contract_status
                                                        (RENEWAL_b.instance_id,
                                                         XXCS_SESSION_PARAM.get_session_param_date(1) -60,
                                                         XXCS_SESSION_PARAM.get_session_param_date(2))
                                                   ,RENEWAL_b.begin_contract_type )BEGIN_contract_type,
                -- end 1.6  14/02/2011  Dalit A. Raviv
                RENEWAL_B.end_contract_type,
                RENEWAL_B.renewal_distance,
                decode(RENEWAL_B.renewal_distance, 'NOT RENEWED', 'NOT RENEWED',
                --  1.6  14/02/2011  Dalit A. Raviv
                /*(CASE WHEN RENEWAL_B.begin_contract_type ='T&M' AND RENEWAL_B.end_contract_type ='T&M'
                THEN 'NOT RENEWED'
                ELSE RENEWAL_B.begin_contract_type || ' TO ' || RENEWAL_B.end_contract_type
                END)
                    ) RENEWAL_STS,*/
                (CASE WHEN RENEWAL_B.begin_contract_type ='T&M' AND RENEWAL_B.end_contract_type ='T&M'
                THEN 'NOT RENEWED'
                ELSE decode(RENEWAL_b.begin_contract_type,'T&M',XXCS_DISCO_PKG.get_early_contract_status
                                                        (RENEWAL_B.instance_id,
                                                         XXCS_SESSION_PARAM.get_session_param_date(1) -60,
                                                         XXCS_SESSION_PARAM.get_session_param_date(2))
                                                   ,RENEWAL_b.begin_contract_type ) || ' TO ' || RENEWAL_B.end_contract_type
                END)
                    ) RENEWAL_STS,
                -- end 1.6  14/02/2011  Dalit A. Raviv
                RENEWAL_B.marketing_classification
                -- renewal_b
        FROM    (SELECT RENEWAL_A.party_id,
                        RENEWAL_A.instance_id,
                        RENEWAL_A.install_date,
                        RENEWAL_A.serial_number,
                        RENEWAL_A.inventory_item_id,
                        RENEWAL_A.printer,
                        RENEWAL_A.printer_description,
                        RENEWAL_A.family,
                        RENEWAL_A.item_category,
                        RENEWAL_A.current_owner_cs_region,
                        RENEWAL_A.Current_customer,
                        RENEWAL_A.Customer,
                        RENEWAL_A.end_customer,
                        RENEWAL_A.org_id,
                        RENEWAL_A.operating_unit_party,
                        RENEWAL_A.sales_channel_code,
                        RENEWAL_A.customer_type,
                        RENEWAL_A.BEGIN_contract_number,
                        RENEWAL_A.BEGIN_contract_or_warranty,
                        RENEWAL_A.BEGIN_line_start_date,
                        RENEWAL_A.BEGIN_line_end_date,
                        RENEWAL_A.BEGIN_line_date_terminated,
                        RENEWAL_A.BEGIN_service,
                        RENEWAL_A.BEGIN_type,
                        RENEWAL_A.BEGIN_coverage,
                        RENEWAL_A.BEGIN_version_number,
                        RENEWAL_A.BEGIN_line_subtotal_conv_usd,
                        RENEWAL_A.BEGIN_modifier,
                        RENEWAL_A.BEGIN_org_id,
                        RENEWAL_A.BEGIN_operating_unit,
                        RENEWAL_A.BEGIN_cs_region,
                        RENEWAL_A.BEGIN_item_type,
                        RENEWAL_A.BEGIN_account_name,
                        RENEWAL_A.BEGIN_account_number,
                        RENEWAL_A.BEGIN_invoiced,
                        RENEWAL_A.END_contract_number,
                        RENEWAL_A.END_contract_or_warranty,
                        RENEWAL_A.END_line_start_date,
                        RENEWAL_A.END_line_end_date,
                        RENEWAL_A.END_line_date_terminated,
                        RENEWAL_A.END_service,
                        RENEWAL_A.END_type,
                        RENEWAL_A.END_coverage,
                        RENEWAL_A.END_version_number,
                        RENEWAL_A.END_line_subtotal_conv_usd,
                        RENEWAL_A.END_modifier,
                        RENEWAL_A.END_org_id,
                        RENEWAL_A.END_operating_unit,
                        RENEWAL_A.END_cs_region,
                        RENEWAL_A.END_item_type,
                        RENEWAL_A.END_account_name,
                        RENEWAL_A.END_account_number,
                        RENEWAL_A.END_invoiced,
                        decode(RENEWAL_A.renewal_distance,'60+','T&M',RENEWAL_A.begin_contract_type) begin_contract_type,
                        RENEWAL_A.end_contract_type,
                        RENEWAL_A.renewal_distance,
                        RENEWAL_A.marketing_classification
                        -- renewal_a
                 FROM   (SELECT RENEWAL_TAB.party_id,
                                RENEWAL_TAB.instance_id,
                                RENEWAL_TAB.install_date,
                                RENEWAL_TAB.serial_number,
                                RENEWAL_TAB.inventory_item_id,
                                RENEWAL_TAB.printer,
                                RENEWAL_TAB.printer_description,
                                RENEWAL_TAB.family,
                                RENEWAL_TAB.item_category,
                                RENEWAL_TAB.current_owner_cs_region,
                                RENEWAL_TAB.Current_customer,
                                RENEWAL_TAB.Customer,
                                RENEWAL_TAB.end_customer,
                                RENEWAL_TAB.org_id,
                                RENEWAL_TAB.operating_unit_party,
                                RENEWAL_TAB.sales_channel_code,
                                RENEWAL_TAB.customer_type,
                                RENEWAL_TAB.BEGIN_contract_number,
                                RENEWAL_TAB.BEGIN_contract_or_warranty,
                                RENEWAL_TAB.BEGIN_line_start_date,
                                RENEWAL_TAB.BEGIN_line_end_date,
                                RENEWAL_TAB.BEGIN_line_date_terminated,
                                RENEWAL_TAB.BEGIN_service,
                                RENEWAL_TAB.BEGIN_type,
                                RENEWAL_TAB.BEGIN_coverage,
                                RENEWAL_TAB.BEGIN_version_number,
                                RENEWAL_TAB.BEGIN_line_subtotal_conv_usd,
                                RENEWAL_TAB.BEGIN_modifier,
                                RENEWAL_TAB.BEGIN_org_id,
                                RENEWAL_TAB.BEGIN_operating_unit,
                                RENEWAL_TAB.BEGIN_cs_region,
                                RENEWAL_TAB.BEGIN_item_type,
                                RENEWAL_TAB.BEGIN_account_name,
                                RENEWAL_TAB.BEGIN_account_number,
                                RENEWAL_TAB.BEGIN_invoiced,
                                RENEWAL_TAB.END_contract_number,
                                RENEWAL_TAB.END_contract_or_warranty,
                                RENEWAL_TAB.END_line_start_date,
                                RENEWAL_TAB.END_line_end_date,
                                RENEWAL_TAB.END_line_date_terminated,
                                RENEWAL_TAB.END_service,
                                RENEWAL_TAB.END_type,
                                RENEWAL_TAB.END_coverage,
                                RENEWAL_TAB.END_version_number,
                                RENEWAL_TAB.END_line_subtotal_conv_usd,
                                RENEWAL_TAB.END_modifier,
                                RENEWAL_TAB.END_org_id,
                                RENEWAL_TAB.END_operating_unit,
                                RENEWAL_TAB.END_cs_region,
                                RENEWAL_TAB.END_item_type,
                                RENEWAL_TAB.END_account_name,
                                RENEWAL_TAB.END_account_number,
                                RENEWAL_TAB.END_invoiced,
                                decode(RENEWAL_TAB.new_exist,'NEW','NEW',RENEWAL_TAB.begin_contract_type) begin_contract_type,
                                RENEWAL_TAB.end_contract_type,
                                CASE WHEN RENEWAL_TAB.days = 0 THEN 'NOT RENEWED'
                                     WHEN RENEWAL_TAB.days > 0 AND RENEWAL_TAB.days < 61 THEN '0-60'
                                     WHEN RENEWAL_TAB.days > 60 THEN '60+'
                                     WHEN RENEWAL_TAB.days = -999 THEN 'N/A'
                                     ELSE to_char(RENEWAL_TAB.days)
                                END                         renewal_distance,
                                RENEWAL_TAB.marketing_classification
                                -- renewal_tab
                         FROM   (SELECT  IB.party_id,
                                         IB.instance_id,
                                         IB.printer_install_date install_date,
                                         IB.serial_number,
                                         IB.inventory_item_id,
                                         IB.printer,
                                         IB.printer_description,
                                         IB.family,
                                         IB.item_category,
                                         IB.current_owner_cs_region,
                                         IB.Current_customer,
                                         IB.Customer,
                                         IB.end_customer,
                                         IB.org_id,
                                         IB.operating_unit_party,
                                         IB.sales_channel_code,
                                         nvl(hca.customer_type,'R') customer_type,
                                         --CONT_STS_BEGIN.contract_number             BEGIN_contract_number,
                                         CONT_STS_BEGIN.contract_or_warranty        BEGIN_contract_or_warranty,
                                         CONT_STS_BEGIN.line_start_date             BEGIN_line_start_date,
                                         CONT_STS_BEGIN.line_end_date               BEGIN_line_end_date,
                                         CONT_STS_BEGIN.service                     BEGIN_service,
                                         CONT_STS_BEGIN.type                        BEGIN_type,
                                         CONT_STS_BEGIN.coverage                    BEGIN_coverage,
                                         CONT_STS_BEGIN.version_number              BEGIN_version_number,
                                         CONT_STS_BEGIN.line_subtotal_converted_usd BEGIN_line_subtotal_conv_usd,
                                         CONT_STS_BEGIN.modifier                    BEGIN_modifier,
                                         CONT_STS_BEGIN.org_id                      BEGIN_org_id,
                                         CONT_STS_BEGIN.operating_unit              BEGIN_operating_unit,
                                         CONT_STS_BEGIN.cs_region                   BEGIN_cs_region,
                                         CONT_STS_BEGIN.item_type                   BEGIN_item_type,
                                         CONT_STS_BEGIN.account_name                BEGIN_account_name,
                                         CONT_STS_BEGIN.account_number              BEGIN_account_number,
                                         CONT_STS_BEGIN.invoiced                    BEGIN_invoiced,
                                         --CONT_STS_END.contract_number               END_contract_number,
                                         CONT_STS_END.contract_or_warranty          END_contract_or_warranty,
                                         CONT_STS_END.line_start_date               END_line_start_date,
                                         CONT_STS_END.line_end_date                 END_line_end_date,
                                         CONT_STS_END.service                       END_service,
                                         CONT_STS_END.type                          END_type,
                                         CONT_STS_END.coverage                      END_coverage,
                                         CONT_STS_END.version_number                END_version_number,
                                         CONT_STS_END.line_subtotal_converted_usd   END_line_subtotal_conv_usd,
                                         CONT_STS_END.modifier                      END_modifier,
                                         CONT_STS_END.org_id                        END_org_id,
                                         CONT_STS_END.operating_unit                END_operating_unit,
                                         CONT_STS_END.cs_region                     END_cs_region,
                                         CONT_STS_END.item_type                     END_item_type,
                                         CONT_STS_END.account_name                  END_account_name,
                                         CONT_STS_END.account_number                END_account_number,
                                         CONT_STS_END.invoiced                      END_invoiced,
                                         XXCS_SESSION_PARAM.get_session_param_date(1)    start_date,
                                         CONT_STS_BEGIN.line_end_date                    BEGIN_period_line_end_date,
                                         CONT_STS_BEGIN.line_date_terminated             BEGIN_line_date_terminated,
                                         CONT_STS_END.line_end_date                      END_period_line_end_date,
                                         CONT_STS_END.line_date_terminated               END_line_date_terminated,
                                         CONT_STS_BEGIN.line_start_date                  BEGIN_period_line_start_date,
                                         CONT_STS_END.line_start_date                    END_period_line_start_date,
                                         nvl(decode(CONT_STS_BEGIN.line_id-CONT_STS_END.line_id,
                                                0,0,CONT_STS_END.line_start_date - CONT_STS_BEGIN.line_end_date),-999) days,
                                         CASE WHEN   CONT_STS_BEGIN.contract_service_id IS NULL
                                              AND    trunc(IB.printer_install_date) >= XXCS_SESSION_PARAM.get_session_param_date(1)
                                              THEN   'NEW'
                                              ELSE   'EXIST'
                                         END                                             new_exist,
                                         NVL(CONT_STS_BEGIN.contract_or_warranty, 'T&M') BEGIN_contract_type ,
                                         NVL(CONT_STS_END.contract_or_warranty, 'T&M')   END_contract_type,
                                         CONT_STS_BEGIN.line_id                          BEGIN_line_id,
                                         CONT_STS_END.line_id                            END_line_id,
                                         CONT_STS_BEGIN.contract_service_id              BEGIN_contract_service_id,
                                         CONT_STS_END.contract_service_id                END_contract_service_id,
                                         CONT_STS_BEGIN.contract_number                  BEGIN_contract_number,
                                         CONT_STS_END.contract_number                    END_contract_number,
                                         CONT_STS_BEGIN.contract_id                      BEGIB_contract_id,
                                         CONT_STS_END.contract_id                        END_contract_id,
                                         MARKET_CLASSIFICATION_TAB.marketing_classification
                                 FROM    --XXCS_IB_STATISTICS_V    IB,
                                         xxcs_ib_statistics_mtxx_v IB, -- 1.9 06/06/2012 Yoram Zamir
                                         hz_cust_accounts        hca,
                                         -- contract that are completed in this period  CONT_STS_BEGIN
                                         (SELECT gg.contract_service_id,
                                                 gg.contract_number,
                                                 gg.contract_id,
                                                 gg.line_id,
                                                 gg.party_id,
                                                 gg.instance_id,
                                                 gg.contract_or_warranty,
                                                 gg.line_start_date,
                                                 gg.line_end_date,
                                                 gg.line_date_terminated,
                                                 gg.service,
                                                 gg.type,
                                                 gg.coverage,
                                                 gg.version_number,
                                                 gg.line_subtotal_converted_usd,
                                                 gg.modifier,
                                                 gg.org_id,
                                                 gg.operating_unit,
                                                 gg.cs_region,
                                                 gg.item_type,
                                                 gg.account_name,
                                                 gg.account_number,
                                                 gg.invoiced,
                                                 gg.rank
                                          FROM (SELECT zz.contract_service_id,
                                                       zz.contract_number,
                                                       zz.contract_id,
                                                       zz.line_id,
                                                       zz.party_id,
                                                       zz.instance_id,
                                                       zz.contract_or_warranty,
                                                       zz.line_start_date,
                                                       zz.line_end_date,
                                                       zz.line_date_terminated,
                                                       zz.service,
                                                       zz.type,
                                                       zz.coverage,
                                                       zz.version_number,
                                                       zz.line_subtotal_converted_usd,
                                                       zz.modifier,
                                                       zz.org_id,
                                                       zz.operating_unit,
                                                       zz.cs_region,
                                                       zz.item_type,
                                                       zz.account_name,
                                                       zz.account_number,
                                                       zz.invoiced,
                                                       DENSE_RANK() OVER (PARTITION BY zz.party_id,zz.instance_id ORDER BY nvl(zz.line_date_terminated,zz.line_end_date) DESC) rank
                                                FROM   XXCS_INST_CONTR_AND_WARR_ALL_V  zz
                                                WHERE  zz.line_status NOT IN ('CANCELLED','ENTERED','SIGNED','TERMINATED')
                                                AND    nvl(zz.line_date_terminated,zz.line_end_date)BETWEEN
                                                       XXCS_SESSION_PARAM.get_session_param_date(1) AND
                                                       XXCS_SESSION_PARAM.get_session_param_date(2)  ) GG
                                          WHERE gg.rank = 1  ) CONT_STS_BEGIN,
                                         -- renew contract  (status end) CONT_STS_END
                                         (SELECT gg.contract_service_id,
                                                 gg.contract_number,
                                                 gg.contract_id,
                                                 gg.line_id,
                                                 gg.party_id,
                                                 gg.instance_id,
                                                 gg.contract_or_warranty,
                                                 gg.line_start_date,
                                                 gg.line_end_date,
                                                 gg.line_date_terminated,
                                                 gg.service,
                                                 gg.type,
                                                 gg.coverage,
                                                 gg.version_number,
                                                 gg.line_subtotal_converted_usd,
                                                 gg.modifier,
                                                 gg.org_id,
                                                 gg.operating_unit,
                                                 gg.cs_region,
                                                 gg.item_type,
                                                 gg.account_name,
                                                 gg.account_number,
                                                 gg.invoiced,
                                                 gg.rank
                                          FROM   (SELECT zz.contract_service_id,
                                                         zz.contract_number,
                                                         zz.contract_id,
                                                         zz.line_id,
                                                         zz.party_id,
                                                         zz.instance_id,
                                                         zz.contract_or_warranty,
                                                         zz.line_start_date,
                                                         zz.line_end_date,
                                                         zz.line_date_terminated,
                                                         zz.service,
                                                         zz.type,
                                                         zz.coverage,
                                                         zz.version_number,
                                                         zz.line_subtotal_converted_usd,
                                                         zz.modifier,
                                                         zz.org_id,
                                                         zz.operating_unit,
                                                         zz.cs_region,
                                                         zz.item_type,
                                                         zz.account_name,
                                                         zz.account_number,
                                                         zz.invoiced,
                                                         DENSE_RANK() OVER (PARTITION BY zz.party_id,zz.instance_id ORDER BY nvl(zz.line_date_terminated,zz.line_end_date) DESC) rank
                                                  FROM   XXCS_INST_CONTR_AND_WARR_ALL_V  zz
                                                  WHERE  zz.line_status = 'ACTIVE'
                                                  AND    zz.line_start_date                           BETWEEN
                                                             XXCS_SESSION_PARAM.get_session_param_date(1) AND
                                                             XXCS_SESSION_PARAM.get_session_param_date(2)  ) GG
                                          WHERE  gg.rank = 1  )  CONT_STS_END,
                                         --  MARKET_CLASSIFICATION_TAB
                                         (SELECT    hp.party_id,
                                                    -- hp.party_number,
                                                    -- hp.party_name,
                                                    -- ca.class_code,
                                                    MAX(lu.MEANING)   marketing_classification
                                          FROM      hz_parties hp,
                                                    hz_code_assignments ca,
                                                    hz_classcode_relations_v lu
                                          WHERE     hp.party_id = ca.owner_table_id (+) AND
                                                    ca.class_category =  'Objet Business Type' AND
                                                    hp.party_type = 'ORGANIZATION' AND
                                                    ca.status = 'A' AND
                                                    hp.status = 'A' AND
                                                    SYSDATE BETWEEN ca.start_date_active AND nvl(ca.end_date_active, SYSDATE) AND
                                                    lu.lookup_type = 'Objet Business Type' AND
                                                    lu.language = 'US' AND
                                                    ca.class_code = lu.LOOKUP_CODE
                                          GROUP BY  hp.party_id) MARKET_CLASSIFICATION_TAB
                                 WHERE  IB.factor      > 0
                                 AND    IB.party_id    = CONT_STS_BEGIN.party_id (+)
                                 AND    ib.party_id    = hca.party_id
                                 AND    IB.party_id    = CONT_STS_END.party_id (+)
                                 AND    IB.instance_id = CONT_STS_BEGIN.instance_id (+)
                                 AND    IB.instance_id = CONT_STS_END.instance_id (+)
                                 AND    IB.party_id    = MARKET_CLASSIFICATION_TAB.party_id (+)
                                )RENEWAL_TAB
                        )RENEWAL_A
                )RENEWAL_B
       )RENEWAL_C
WHERE  RENEWAL_C.begin_contract_type != 'NEW'
AND    RENEWAL_C.RENEWAL_STS         != 'NOT RENEWED'
AND    XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(RENEWAL_C.org_id,RENEWAL_C.party_id) = 'Y';
