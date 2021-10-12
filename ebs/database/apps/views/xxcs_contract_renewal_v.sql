CREATE OR REPLACE VIEW XXCS_CONTRACT_RENEWAL_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CONTRACT_RENEWAL_V
--  create by:       Yoram Zamir
--  Revision:        1.6
--  creation date:   13/04/2010
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  13/04/2010  Yoram Zamir      initial build
--  1.1  25/04/2010  Vitaly           Last Contract Notes was added
--  1.2  03/06/2010  Yoram Zamir      renewal_type, TM_TO_SLA,NO_RENEW,SLA_TO_SLA,WRTY_TO_SLA  were added
--  1.3  09/06/2010  Vitaly           Old org_id, Renewal org_id, Security by OU were added
--  1.4  19/12/2010  Roman            Added customer_type
--  1.5  10/02/2011  Roman            Removed 'CANCELLED','ENTERED','SIGNED' contracts from old contract table
--  1.6  24/02/2011  Roman            Removed 'TERMINATED' contracts from old contract table
--------------------------------------------------------------------
                CALC_TAB.serial_number,
                CALC_TAB.contract_id,
                CALC_TAB.contract_number,
                CALC_TAB.contract_start_date,
                CALC_TAB.contract_end_date,
                CALC_TAB.child_contract_id,
                CALC_TAB.child_contract_number,
                CALC_TAB.child_start_date,
                CALC_TAB.child_end_date,
                CALC_TAB.oldcont_instance_item,
                CALC_TAB.oldcont_instance_item_desc,
                CALC_TAB.oldcont_item_for_parm,
                CALC_TAB.oldcont_operating_unit,
                CALC_TAB.oldcont_cs_region,
                CALC_TAB.oldcont_service_type,
                CALC_TAB.oldcont_service,
                CALC_TAB.oldcont_coverage,
                CALC_TAB.oldcont_customer_name,
                CALC_TAB.oldcont_end_customer,
                CALC_TAB.oldcont_account_name,
                CALC_TAB.oldcont_instance_id,
                CALC_TAB.oldcont_install_date,
                CALC_TAB.oldcont_contract_number,
                CALC_TAB.oldcont_version_number,
                CALC_TAB.oldcont_status,
                CALC_TAB.oldcont_line_start_date,
                CALC_TAB.oldcont_line_end_date,
                CALC_TAB.oldcont_line_status,
                CALC_TAB.oldcont_line_subtotal,
                CALC_TAB.oldcont_line_currency_code,
                CALC_TAB.oldcont_conv_line_subtotal_usd,
                CALC_TAB.oldcont_invoiced,
                CALC_TAB.renewed_instance_item,
                CALC_TAB.renewed_instance_item_desc,
                CALC_TAB.renewed_item_for_parm,
                CALC_TAB.renewed_operating_unit,
                CALC_TAB.renewed_cs_region,
                CALC_TAB.renewed_service_type,
                CALC_TAB.renewed_service,
                CALC_TAB.renewed_coverage,
                CALC_TAB.renewed_customer_name,
                CALC_TAB.renewed_end_customer,
                CALC_TAB.renewed_account_name,
                CALC_TAB.renewed_instance_id,
                CALC_TAB.renewed_install_date,
                CALC_TAB.renewed_contract_number,
                CALC_TAB.renewed_version_number,
                CALC_TAB.renewed_status,
                CALC_TAB.renewed_line_start_date,
                CALC_TAB.renewed_line_end_date,
                CALC_TAB.renewed_line_status,
                CALC_TAB.renewed_line_subtotal,
                CALC_TAB.renewed_line_currency_code,
                CALC_TAB.renewed_conv_line_subtotal_usd,
                CALC_TAB.renewed_invoiced,
                CALC_TAB.last_contract_note,
                CALC_TAB.t_and_m,
                ------------------
                nvl(decode(nvl(CALC_TAB.renewed_contract_number,'ZZZ'),'ZZZ','',
                 decode(CALC_TAB.t_and_m,'Y','T&M TO SLA','N',
                  decode(CALC_TAB.oldcont_service_type,'WARRANTY','WRTY TO SLA',
                                              'SERVICE', 'SLA TO SLA'))),'NO_RENEW')
                                                        renewal_type,
                ------------------
                decode(nvl(CALC_TAB.renewed_contract_number,'ZZZ'),'ZZZ',0,
                 decode(CALC_TAB.t_and_m,'Y',1,'N',
                  decode(CALC_TAB.oldcont_service_type,'WARRANTY',0,
                                              'SERVICE', 0)))
                                                        TM_TO_SLA,
                ------------------
                decode(nvl(CALC_TAB.renewed_contract_number,'ZZZ'),'ZZZ',0,
                 decode(CALC_TAB.t_and_m,'Y',0,'N',
                  decode(CALC_TAB.oldcont_service_type,'WARRANTY',1,
                                              'SERVICE', 0)))
                                                        WRTY_TO_SLA,
                -----------------
                decode(nvl(CALC_TAB.renewed_contract_number,'ZZZ'),'ZZZ',0,
                 decode(CALC_TAB.t_and_m,'Y',0,'N',
                  decode(CALC_TAB.oldcont_service_type,'WARRANTY',0,
                                              'SERVICE', 1)))
                                                        SLA_TO_SLA,
                -----------------
               nvl(decode(nvl(CALC_TAB.renewed_contract_number,'ZZZ'),'ZZZ',1,
                 decode(CALC_TAB.t_and_m,'Y',0,'N',
                  decode(CALC_TAB.oldcont_service_type,'WARRANTY',0,
                                              'SERVICE',0))),1)
                                                        NO_RENEW,
               CALC_TAB.old_contract_org_id,
               CALC_TAB.renewed_org_id,
               CALC_TAB.customer_type
FROM
(SELECT         rel.serial_number                       serial_number,
                rel.contract_id                         contract_id,
                rel.contract_number                     contract_number,
                rel.contract_start_date                 contract_start_date,
                rel.contract_end_date                   contract_end_date,
                rel.child_contract_id                   child_contract_id,
                rel.child_contract_number               child_contract_number,
                rel.child_start_date                    child_start_date,
                rel.child_end_date                      child_end_date,
                oldcont.instance_item                   oldcont_instance_item,
                oldcont.instance_item_desc              oldcont_instance_item_desc,
                oldcont.instance_item ||'   -   '|| oldcont.instance_item_desc   oldcont_item_for_parm,
                oldcont.operating_unit                  oldcont_operating_unit,
                oldcont.cs_region                       oldcont_cs_region,
                oldcont.service_type                    oldcont_service_type,
                oldcont.service                         oldcont_service,
                oldcont.coverage                        oldcont_coverage,
                oldcont.customer_name                   oldcont_customer_name,
                oldcont.end_customer                    oldcont_end_customer,
                oldcont.account_name                    oldcont_account_name,
                oldcont.instance_id                      oldcont_instance_id,
                oldcont.install_date                     oldcont_install_date,
                oldcont.contract_number                   oldcont_contract_number,
                oldcont.version_number                  oldcont_version_number,
                oldcont.status                          oldcont_status,
                oldcont.line_start_date                  oldcont_line_start_date,
                oldcont.line_end_date                    oldcont_line_end_date,
                oldcont.line_status                      oldcont_line_status,
                oldcont.line_subtotal                    oldcont_line_subtotal,
                oldcont.line_currency_code              oldcont_line_currency_code,
                oldcont.converted_line_subtotal_usd      oldcont_conv_line_subtotal_usd,
                oldcont.invoiced                        oldcont_invoiced,
                renewed.instance_item                   renewed_instance_item,
                renewed.instance_item_desc              renewed_instance_item_desc,
                renewed.instance_item ||'   -   '|| renewed.instance_item_desc   renewed_item_for_parm,
                renewed.operating_unit                   renewed_operating_unit,
                renewed.cs_region                       renewed_cs_region,
                renewed.service_type                    renewed_service_type,
                renewed.service                         renewed_service,
                renewed.coverage                        renewed_coverage,
                renewed.customer_name                   renewed_customer_name,
                renewed.end_customer                    renewed_end_customer,
                renewed.account_name                     renewed_account_name,
                renewed.instance_id                       renewed_instance_id,
                renewed.install_date                    renewed_install_date,
                renewed.contract_number                   renewed_contract_number,
                renewed.version_number                  renewed_version_number,
                renewed.status                          renewed_status,
                renewed.line_start_date                   renewed_line_start_date,
                renewed.line_end_date                    renewed_line_end_date,
                renewed.line_status                       renewed_line_status,
                renewed.line_subtotal                    renewed_line_subtotal,
                renewed.line_currency_code               renewed_line_currency_code,
                renewed.converted_line_subtotal_usd      renewed_conv_line_subtotal_usd,
                renewed.invoiced                         renewed_invoiced,
                LAST_CONTRACT_NOTES_TAB.notes           last_contract_note,
                CASE WHEN renewed.line_start_date - rel.contract_end_date  /*contract_end_date*/>60
                     THEN 'Y'
                     ELSE 'N'
                END                                     t_and_m,
                oldcont.org_id                          old_contract_org_id,
                renewed.org_id                          renewed_org_id,
                nvl(hca.customer_type,'R') customer_type
FROM            XXCS_CONTR_REL_BY_SN_V                  rel,
                XXCS_CONTRACT_ALL_V                     oldcont,
                XXCS_CONTRACT_ALL_V                     renewed,
                hz_cust_accounts                        hca,
               (SELECT NOTES_TAB.SOURCE_OBJECT_ID   contract_id,
                       NOTES_TAB.NOTES
                FROM (
                SELECT n.SOURCE_OBJECT_ID,
                       n.NOTES,
                       DENSE_RANK() OVER (PARTITION BY n.SOURCE_OBJECT_ID ORDER BY n.CREATION_DATE DESC)  max_creation_date_flag
                FROM   JTF_NOTES_VL n
                WHERE  n.source_object_code='OKS_HDR_NOTE'
                AND    n.NOTE_TYPE='OKS_ADMIN'
                                 ) NOTES_TAB
                WHERE  max_creation_date_flag= 1
                                       )   LAST_CONTRACT_NOTES_TAB
WHERE           rel.contract_id =                       oldcont.CONTRACT_ID
AND             oldcont.party_id =                      hca.party_id
AND             HCA.Status =                            'A'
AND             rel.child_contract_id =                 renewed.CONTRACT_ID (+)
AND             rel.INSTANCE_ID =                       oldcont.INSTANCE_ID
AND             rel.INSTANCE_ID =                       renewed.INSTANCE_ID (+)
AND             oldcont.SERVICE <>                      'HEADS WARRANTY'
AND             oldcont.STATUS NOT IN                   ('CANCELLED','ENTERED','SIGNED','TERMINATED')
AND             oldcont.LINE_STATUS NOT IN              ('CANCELLED','ENTERED','SIGNED','TERMINATED')
AND             rel.contract_id=                        LAST_CONTRACT_NOTES_TAB.contract_id(+)
AND             XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(oldcont.org_id,oldcont.party_id)='Y'
                ) CALC_TAB;

