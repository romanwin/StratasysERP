CREATE OR REPLACE VIEW XXCS_INSTALL_BASE_BI_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INSTALL_BASE_BI_V
--  create by:       Yoram Zamir
--  Revision:        2.7
--  creation date:   25/02/2010
--------------------------------------------------------------------
--  purpose :        Install Base Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  25/02/2010  Yoram Zamir      initial build
--  1.1  07/03/2010  Vitaly --        Source for Region was changed to CSI_ITEM_INSTANCES.attribute8
--  1.2  08/03/2010  Vitaly           Operating_Unit_Party was added
--  1.3  07/04/2010  Vitaly           Address1,Address2,Address3,Address4,City and Internal  fields were added
--  1.4  15/04/2010  Yoram Zamir      "Internal" field logic was changed.
--  1.5  05/05/2010  Yoram Zamir      new condition ca.status = 'A'
--  1.6  09/05/2010  Yoram Zamir      New fields ic.CONTRACT_LINE_ID, ic.CONTRACT_TYPE,
--  1.8  24/05/2010  Yoram Zamir      Fix the outer join with hz_cust_accounts by adding sub select, Security by OU was added
--  1.9  24/06/2010  Yoram Zamir      instance_contract_type
--  2.0  26/09/2010  Roman            Modified end_customer name info, add party_numbers and end_customer_market_classification
--  2.1  29/12/2010  Roman            Added Related_distributor field
--  2.2  07/02/2011  Roman            Added System_Upgrade_Type and System_Upgrade_Date
--  2.3  16/02/2011  Roman            Added associated_distributor
--  2.4  27/04/2011  Roman            Added Partner_program
--  2.5  05/05/2011  Roman            Fixed the Dealer name retrieval, take it from jtf_rs_resource_extns_tl
--  2.6  29/05/2011  Roman            Added end_customer_party_id
--  2.7  31/08/2011  Roman            Changed contract status logic to take not only Active contracts
--  2.8  17/07/2014  Adi Safin        Add the CONTRACT option for contracts via SO
--------------------------------------------------------------------
--> csi_item_instances cii
    cii.instance_id,
    cii.instance_number,
    cii.inventory_item_id,
    cii.inventory_revision,
    cii.inv_master_organization_id,
    cii.serial_number,
    cii.mfg_serial_number_flag,
    cii.quantity,
    cii.unit_of_measure,
    cii.instance_status_id,
    cii.customer_view_flag,
    cii.system_id,
    cii.active_start_date,
    cii.active_end_date,
    cii.location_type_code,
    cii.location_id,
    cii.inv_organization_id,
    cii.inv_subinventory_name,
    cii.inv_locator_id,
    cii.po_order_line_id,
    cii.last_oe_order_line_id,
    cii.last_oe_rma_line_id,
    cii.last_po_po_line_id,
    cii.last_oe_po_number,
    cii.install_date,
    cii.manually_created_flag,
    cii.return_by_date,
    cii.actual_return_date,
    cii.creation_complete_flag,
    cii.context,
    cii.attribute1 cust16,
    cii.attribute2 record_id_data_conv,
    cii.attribute3 coi,
    cii.attribute4 embedded_sw_version,
    cii.attribute5 objet_studio_sw_version,
    to_date(cii.attribute6,'yyyy/mm/dd hh24:mi:ss')        initial_ship_date,
    NVL(LOOL.ACTUAL_SHIPMENT_DATE, LOOL.FULFILLMENT_DATE)  ship_date,
    to_date(cii.attribute7,'yyyy/mm/dd hh24:mi:ss')        coi_date,
    cii.attribute13 System_Upgrade_Date,
    sys_ug.description System_Upgrade_Type,
    cii.created_by,
    cii.creation_date,
    cii.last_updated_by,
    cii.last_update_date,
    cii.object_version_number,
    cii.install_location_type_code,
    cii.install_location_id,
    cii.instance_usage_code,
    cii.owner_party_source_table,
    cii.owner_party_id,
    cii.owner_party_account_id,
    cii.last_vld_organization_id,
    cii.instance_description,
    cii.sales_unit_price,
    cii.sales_currency_code,
    cii.instance_type_code,
    DECODE(cii.owner_party_id,10041,'YES','NO')   internal,
--> csi_systems_v csv
    csv.operating_unit_id,
    csv.operating_unit_name,
    csv.customer_id cust_account_id,
    csv.customer_name,
    csv.customer_party_number party_number,
    csv.customer_number account_number,
    csv.system_type_code,
    csv.system_type,
    --csv.name end_customer,
    nvl(csv.attribute1,csv.name)  end_customer, --Roman 26/09/2010
    hp_sys.party_number end_customer_party_number, --Roman 26/09/2010
    hp_sys.party_id end_customer_party_id, --Roman 29/05/2011
    msi.segment1 item,
    msi.organization_id,
    cca.instance_association_id,
    cca.source_object_code,
    cca.last_update_login,
    cca.security_group_id,
    cca.migrated_flag,
    cca.counter_id,
    cca.start_date_active,
    cca.end_date_active,
    cca.maint_organization_id,
    cca.primary_failure_flag,
-->  hz_parties hzp
    hzp.party_name owner_name,
    hzp.party_number owner_party_number,
    ----hzp.attribute1 owner_cs_region,
    cii.attribute8     owner_cs_region,
    MARKET_CLASSIFICATION_TAB.marketing_classification    owner_market_classification,
    END_MARKET_CLASSIFICATION_TAB.marketing_classification end_market_classification, --Roman 26/09/2010
-->  mtl_system_items_b msi
    msi.item_type,
    msi.description    item_description,
--> fnd_lookup_values_vl flv
    flv.meaning        item_type_meaning,
    COUNTER_READING_TAB.counter_reading,
    COUNTER_READING_TAB.counter_reading_date,
    OPTIMAX_UPGRADE_DATE_TAB.optimax_upgrade_date    optimax_upgrade_date,
    TEMPO_UPGRADE_DATE_TAB.tempo_upgrade_date        tempo_upgrade_date,
    COALESCE(DECODE(IC.CONTRACT_LINE_STATUS,'ACTIVE','CONTRACT',NULL),CONT.contract_or_warranty,'T&&M') instance_contract_type, --- 2.8  17/07/2014  Adi Safin
--> xxcs_instance_contract IC
    ic.CONTRACT_LINE_ID,
    ic.CONTRACT_SERVICE,
    ic.CONTRACT_TYPE, 
    ic.CONTRACT_COVERAGE,
    ic.CONTRACT_NUMBER,
    ic.CONTRACT_STATUS,
    ic.CONTRACT_START_DATE,
    ic.CONTRACT_END_DATE,
    ic.CONTRACT_LINE_STATUS,
    ic.CONTRACT_LINE_START_DATE,
    ic.CONTRACT_LINE_END_DATE,
-->xxcs_instance_warranty IW
    iw.WARRANTY_SERVICE,
    iw.WARRANTY_COVERAGE,
    iw.WARRANTY_NUMBER,
    iw.WARRANTY_STATUS,
    iw.WARRANTY_START_DATE,
    iw.WARRANTY_END_DATE,
    iw.WARRANTY_LINE_STATUS,
    iw.WARRANTY_LINE_START_DATE,
    iw.WARRANTY_LINE_END_DATE,
    IB_CONTACTS_TAB.full_name    primary_cse,
    ca.account_number            instance_account_number,
    ca.sales_channel_code,
    op.category_code,
    cl.country,
    cl.state,
    cl.postal_code,
    cl.CITY,
    cl.ADDRESS1,
    cl.ADDRESS2,
    cl.ADDRESS3,
    cl.ADDRESS4,
    st.name                      ib_status,
    flv2.meaning                 item_instance_type,
    mtc.category_id              category_id,
    mtc.structure_id             category_structure_id,
    mtc.segment1                 category_segment1,
    mtc.segment2                 category_segment2,
    mtc.segment3                 category_segment3,
    mtc.attribute4               Item_Category,
    mic.category_set_id          category_set_id,
    mtc.enabled_flag             item_enabled_flag,
    msi.segment1 || '   -   ' || msi.description      item_for_parameter,
    oup.name                     operating_unit_party,
    dealer.name dealer,
    rel_dist.party_name associated_distributor,
    partner_program.partner_program
from csi_item_instances              cii,
     csi_systems_v                   csv,
     hz_parties                      hp_sys,
     mtl_system_items_b              msi,
     csi_counter_associations_v      cca,
     hz_parties                      hzp,
     hr_operating_units              oup,
     fnd_lookup_values_vl            flv,
     xxcs_instance_contract          IC,
     xxcs_instance_warranty          IW,
     oe_order_lines_all              LOOL,
     (SELECT bz.party_id ,
             bz.account_number,
             bz.sales_channel_code
      FROM  hz_cust_accounts  bz
      WHERE bz.status = 'A'
                              )      ca,
     hz_organization_profiles_v      op,
     xxcsi_inst_current_location_v   cl,
     csi_instance_statuses           st,
     fnd_lookup_values               flv2,
     mtl_item_categories             mic,
     mtl_categories_b                mtc,
   (select ccr.counter_id,
           ccr.counter_reading,
           ccr.value_timestamp   counter_reading_date
    from csi_counter_readings    ccr
   where ccr.counter_value_id =
         (select max(ccr2.counter_value_id)
            from csi_counter_readings ccr2
           where ccr2.counter_id = ccr.counter_id
           group by ccr2.counter_id)
                            )   COUNTER_READING_TAB,
   (select   cp.instance_id,
             MAX(pp.full_name)   full_name
        from csi_i_parties cp,
             per_all_people_f pp
       where cp.relationship_type_code =  'TECHNICAL'
         and cp.party_source_table =      'EMPLOYEE'
         and cp.preferred_flag =          'Y'
         and cp.contact_flag =            'Y'
         and cp.primary_flag =            'Y'
         and sysdate between nvl(cp.active_start_date, sysdate) and nvl(cp.active_end_date, sysdate)
         and cp.party_id =                pp.person_id
         and sysdate between pp.effective_start_date and pp.effective_end_date
       group by cp.instance_id
                                 )    IB_CONTACTS_TAB,
   (SELECT        hp.party_id,
                 --- hp.party_number,
                  --hp.party_name,
                  --ca.class_code,
                  MAX(lu.MEANING)   marketing_classification
    FROM          hz_parties hp,
                  hz_code_assignments ca,
                  hz_classcode_relations_v lu
    WHERE         hp.party_id = ca.owner_table_id (+) AND
                  ca.class_category =  'Objet Business Type' AND
                  hp.party_type = 'ORGANIZATION' AND
                  ca.status = 'A' AND
                  hp.status = 'A' AND
                  SYSDATE BETWEEN ca.start_date_active AND nvl(ca.end_date_active, SYSDATE) AND
                  lu.lookup_type = 'Objet Business Type' AND
                  lu.language = 'US' AND
                  ca.class_code = lu.LOOKUP_CODE
    GROUP BY hp.party_id)
                           MARKET_CLASSIFICATION_TAB,
   (SELECT        hp.party_id,
                 --- hp.party_number,
                  --hp.party_name,
                  --ca.class_code,
                  MAX(lu.MEANING)   marketing_classification
    FROM          hz_parties hp,
                  hz_code_assignments ca,
                  hz_classcode_relations_v lu
    WHERE         hp.party_id = ca.owner_table_id (+) AND
                  ca.class_category =  'Objet Business Type' AND
                  hp.party_type = 'ORGANIZATION' AND
                  ca.status = 'A' AND
                  hp.status = 'A' AND
                  SYSDATE BETWEEN ca.start_date_active AND nvl(ca.end_date_active, SYSDATE) AND
                  lu.lookup_type = 'Objet Business Type' AND
                  lu.language = 'US' AND
                  ca.class_code = lu.LOOKUP_CODE
    GROUP BY hp.party_id)
                           END_MARKET_CLASSIFICATION_TAB,
   (select civ.instance_id,
           civ.attribute_value   optimax_upgrade_date
    from   CSI_IEA_VALUES civ
    where  civ.attribute_id = 10000 -- Optimax upgrade date
                     )    OPTIMAX_UPGRADE_DATE_TAB,
   (select civ.instance_id,
           civ.attribute_value   tempo_upgrade_date
    from   CSI_IEA_VALUES civ
    where  civ.attribute_id = 11000 -- Tempo upgrade date
                     )    TEMPO_UPGRADE_DATE_TAB,
    (SELECT
               gg.party_id,
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
        WHERE zz.status_category IN ('ACTIVE', 'QA_HOLD','SIGNED')
        AND   SYSDATE
              BETWEEN zz.line_start_date AND nvl(zz.line_date_terminated,zz.line_end_date)
             ) GG
       WHERE  gg.rank = 1
                                      )  CONT,
     (select hp.party_id, rs.resource_name name
        from hz_party_sites hps, hz_parties hp, jtf_rs_salesreps jrs, jtf_rs_resource_extns_tl rs
       where hps.attribute11 is not NULL
         and rs.resource_id = jrs.resource_id
         AND rs.language = 'US'
         and hp.party_id = hps.party_id
         and hps.attribute11 = jrs.salesrep_id
         and hps.identifying_address_flag = 'Y'
         and hps.status = 'A') dealer,

     (SELECT MSIB.DESCRIPTION, msib.inventory_item_id
        FROM mtL_SYSTEM_ITEMS_B MSIB, MTL_ITEM_CATEGORIES MIC
       WHERE MSIB.ORGANIZATION_ID = 91
         AND MSIB.INVENTORY_ITEM_ID = MIC.INVENTORY_ITEM_ID
         AND MIC.ORGANIZATION_ID = 91
         AND MIC.CATEGORY_ID = 36123) sys_ug,
    (SELECT GG.PARTY_ID, GG.PARTNER_PROGRAM, GG.RANK
  FROM (SELECT OKPR.OBJECT1_ID1 PARTY_ID,
               MSIB.SEGMENT1 PARTNER_PROGRAM,
               DENSE_RANK() OVER(PARTITION BY OKPR.OBJECT1_ID1 ORDER BY L.END_DATE DESC) RANK
          FROM OKC_K_HEADERS_ALL_B H,
               OKC_K_LINES_B       L,
               OKC_K_ITEMS         OKI2,
               MTL_SYSTEM_ITEMS_B  MSIB,
               OKC_K_PARTY_ROLES_B OKPR
         WHERE OKI2.CLE_ID = L.ID
           AND L.CHR_ID = H.ID
           AND MSIB.INVENTORY_ITEM_ID = OKI2.OBJECT1_ID1
           AND MSIB.ORGANIZATION_ID = 91
           AND MSIB.SEGMENT1 IN ('SERVICE CARE', 'TOTAL CARE')
           AND H.ID = OKPR.CHR_ID
           AND OKPR.JTOT_OBJECT1_CODE = 'OKX_PARTY'
           AND L.STS_CODE = 'ACTIVE'
           AND SYSDATE BETWEEN L.START_DATE AND
               NVL(L.DATE_TERMINATED, L.END_DATE)) GG
 WHERE GG.RANK = 1) partner_program,
   (SELECT INSTANCE_ID, PARTY_NAME
      FROM (SELECT CIP.INSTANCE_ID,
             HP.PARTY_NAME,
             DENSE_RANK() OVER(PARTITION BY CIP.INSTANCE_ID ORDER BY CIP.CREATION_DATE DESC) RANK
      FROM CSI_INST_PARTY_DETAILS_V CIP, HZ_PARTIES HP
     WHERE CIP.CONTACT_FLAG = 'N'
       AND NVL(CIP.ACTIVE_END_DATE, SYSDATE + 1) > SYSDATE
       AND CIP.RELATIONSHIP_TYPE_CODE = 'SUPPORTED BY DISTRIBUTOR'
       AND CIP.PARTY_ID = HP.PARTY_ID) rel_dist_rank
      WHERE rel_dist_rank.rank = 1) rel_dist
   where  cii.system_id = csv.system_id (+)
   AND hp_sys.party_id (+) = csv.attribute2
   and cii.inventory_item_id (+) = msi.inventory_item_id
   and msi.organization_id   = 91
   and mic.inventory_item_id = msi.inventory_item_id
   and mic.organization_id   = msi.organization_id
   and mic.organization_id   = 91
   and mic.category_set_id   = 1100000041
   and mtc.category_id       = mic.category_id
   and mtc.enabled_flag      = 'Y'
   and cii.instance_id       = cca.source_object_id (+)
   and cii.owner_party_id    = hzp.party_id
   AND to_number(hzp.attribute3) = oup.organization_id(+)
   AND cii.owner_party_id    = MARKET_CLASSIFICATION_TAB.party_id(+)
   AND hp_sys.party_id       = END_MARKET_CLASSIFICATION_TAB.party_id(+)
   and msi.item_type         = flv.lookup_code
   and flv.lookup_type       = 'ITEM_TYPE'
   and cii.instance_id       = ic.CONTRACT_INSTANCE_ID (+)
   and cii.instance_id       = iw.WARRANTY_INSTANCE_ID (+)
   and CII.LAST_OE_ORDER_LINE_ID = LOOL.LINE_ID(+)
   and cca.counter_id        = COUNTER_READING_TAB.counter_id(+)
   and cii.instance_id       = IB_CONTACTS_TAB.instance_id(+)
   and cii.owner_party_id    = ca.party_id(+)
   AND cii.owner_party_id    = partner_program.party_id (+)
   --and ca.status             = 'A'
   and cii.owner_party_id    =op.party_id(+)
   and cii.instance_id       =cl.instance_id(+)
   and cii.instance_status_id=st.instance_status_id(+)
   and nvl(cii.instance_type_code,'XXCS_STANDARD') = flv2.lookup_code
   and flv2.language         ='US'
   and flv2.lookup_type      ='CSI_INST_TYPE_CODE'
   AND cii.instance_id=OPTIMAX_UPGRADE_DATE_TAB.instance_id(+)
   AND cii.instance_id=TEMPO_UPGRADE_DATE_TAB.instance_id(+)
   AND XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(to_number(hzp.attribute3), cii.owner_party_id)='Y'
   AND cii.owner_party_id = cont.party_id (+)
   AND cii.instance_id = cont.instance_id (+)
   and cii.owner_party_id = dealer.party_id (+)
   AND cii.attribute14 = sys_ug.inventory_item_id (+)
   AND cii.instance_id = rel_dist.INSTANCE_ID (+);
  
