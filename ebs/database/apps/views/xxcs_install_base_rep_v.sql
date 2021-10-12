CREATE OR REPLACE VIEW XXCS_INSTALL_BASE_REP_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_INSTALL_BASE_REP_V
--  create by:       Yoram Zamir
--  Revision:        2.3
--  creation date:   01/09/2009
--------------------------------------------------------------------
--  purpose :        Disco Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  01/09/2009  Yoram Zamir      initial build
--  1.1  07/02/2010  Yoram Zamir      add instance_usage_code
--  1.2  08/03/2010  Vitaly           Operating_Unit_Party was added
--  1.3  07/04/2010  Vitaly           Address1,Address2,Address3,Address4,City and Internal  fields were added
--  1.4  09/05/2010  Yoram Zamir      New field ib.CONTRACT_TYPE
--  1.5  24/06/2010  Yoram Zamir      New field instance_contract_type
--  1.6  20/07/2010  Roman            New Field installdate_MON_YEAR
--  1.7  26/09/2010  Roman            New fields for End customer, party number and end customer marketing classification
--  1.8  29/12/2010  Roman            Added related_distributor field
--  1.9  12/01/2011  Roman            Added global account flag
--  2.0  07/02/2011  Roman            Added System Upgrade Type and System Upgrade Date
--  2.1  16/02/2011  Roman            Added associated_distributor
--  2.2  27/04/2011  Roman            Added partner_program
--  2.3  29/05/2011  Roman            Changed GA validation according to end_customer_party_id
--  2.4  08/11/2011  Dalit A. Raviv   Add CS_region_group field
--  2.5  29/03/2012  Dalit A. Raviv   add field that check if printer have attachment
--  2.6  03/10/2012  Adi Safin        add Global parent column
--  2.7  03/02/2014  Adi Safin        CR1293 - add field - product line
--  2.8  13/07/2014  Ginat B.         CHG0032654 Change GA logic
--------------------------------------------------------------------
       ib.instance_id                              instance_id,
       ib.internal                                 internal,
       ib.owner_cs_region                          cs_region,
       ib.owner_name                               Customer,
       ib.owner_market_classification,
       ib.end_market_classification                end_market_classification,
       ib.instance_usage_code,
       ib.end_customer                             end_customer,
       ib.owner_party_number                       owner_customer_number,
       (select hca.account_number
       from hz_cust_accounts hca
       where hca.party_id=ib.end_customer_party_id
       and rownum=1) end_customer_account_number,
       ib.end_customer_party_number                end_customer_number,
       ib.serial_number                            serial_number,
       ib.item                                     Printer,
       ib.item_description                         Printer_Description,
       ib.item || '   -   ' || ib.item_description ITEM_FOR_PARAMETER,
       ib.quantity                                 QTY,
       ib.unit_of_measure                          UOM,
       ib.last_update_date                         last_update_date,
       ib.counter_reading                          counter_reading,
       ib.counter_reading_date                     counter_reading_date,
       ib.COI                                      COI,
       ib.COI_Date                                 COI_Date,
       ib.Embedded_SW_Version                      Embedded_SW_Version,
       ib.Objet_Studio_SW_version                  Objet_Studio_SW_version,
       ib.Optimax_Upgrade_Date                     Optimax_Upgrade_Date,
       ib.Tempo_Upgrade_Date                       Tempo_Upgrade_Date,
       nvl(ib.Ship_Date, ib.Initial_Ship_Date)     Ship_Date,
       trunc(ib.install_date)                      install_date,
       to_char(ib.install_date,'MON-YYYY')         install_date_MON_YEAR,
       ib.instance_account_number                  account_number,
       ib.sales_channel_code                       sales_channel_code,
       ib.category_code                            category_code,
       ib.country                                  country,
       ib.state                                    state,
       ib.postal_code                              postal_code,
       ib.city                                     city,
       ib.address1                                 address1,
       ib.address2                                 address2,
       ib.address3                                 address3,
       ib.address4                                 address4,
       ib.ib_status                                IB_status,
       ib.item_instance_type                       item_instance_type,
       ib.inventory_item_id                        inventory_item_id,
       ib.category_id                              category_id,
       ib.category_structure_id                    category_structure_id,
       ib.category_segment1                        category_segment1,
       ib.category_segment2                        category_segment2,
       ib.category_segment3                        category_segment3,
       ib.Item_Category                            Item_Category,
       ib.category_set_id                          category_set_id,
       ib.item_enabled_flag                        enabled_flag,
       ib.primary_cse                              IB_Contacts,
       ib.operating_unit_party,
       ib.instance_contract_type,
       ib.CONTRACT_SERVICE                        CONTRACT_SERVICE,
       ib.CONTRACT_COVERAGE                       CONTRACT_COVERAGE,
       ib.CONTRACT_TYPE                           CONTRACT_TYPE,
       ib.CONTRACT_NUMBER                         CONTRACT_NUMBER,
       ----nvl(ib.CONTRACT_STATUS,'Inactive')  --closed by Vitaly 06-Dec-2009
       ib.CONTRACT_STATUS                         CONTRACT_STATUS,
       ib.CONTRACT_START_DATE                     CONTRACT_START_DATE,
       ib.CONTRACT_END_DATE                       CONTRACT_END_DATE,
       ib.CONTRACT_LINE_STATUS                    CONTRACT_LINE_STATUS,
       ib.CONTRACT_LINE_START_DATE                CONTRACT_LINE_START_DATE,
       ib.CONTRACT_LINE_END_DATE                  CONTRACT_LINE_END_DATE,
       ib.WARRANTY_SERVICE                        WARRANTY_SERVICE,
       ib.WARRANTY_COVERAGE                       WARRANTY_COVERAGE,
       ib.WARRANTY_NUMBER                         WARRANTY_NUMBER,
       ----nvl(ib.WARRANTY_STATUS,'Inactive')  --closed by Vitaly 06-Dec-2009
       ib.WARRANTY_STATUS                         WARRANTY_STATUS,
       ib.WARRANTY_START_DATE                     WARRANTY_START_DATE,
       ib.WARRANTY_END_DATE                       WARRANTY_END_DATE,
       ib.WARRANTY_LINE_STATUS                    WARRANTY_LINE_STATUS,
       ib.WARRANTY_LINE_START_DATE                WARRANTY_LINE_START_DATE,
       ib.WARRANTY_LINE_END_DATE                  WARRANTY_LINE_END_DATE,
       ib.dealer                                  RELATED_DISTRIBUTOR,
       --xxhz_party_ga_util.is_party_ga (ib.end_customer_party_id) GA,
       (select GLOBAL_KEY from xxhz_party_ga_v v where v.party_id=ib.end_customer_party_id) GA,
       ib.System_Upgrade_Date,
       ib.System_Upgrade_Type,
       ib.associated_distributor,
       ib.partner_program,
       region_gr.CS_Region_group                  CS_Region_group,
       -- 2.5  29/03/2012  Dalit A. Raviv
       case when ib.Item_Category = 'PRINTER' then
              XXCSI_UTILS_PKG.get_Attached_file_to_printer(ib.instance_id)
            else
              null
       end Attached_files_to_printers,
       (select nvl(hp_par.party_name,' ')
        from   hz_relationships         tt,
               hz_parties               hp_par,
               hz_parties               hp_sub
        where  tt.object_table_name     = 'HZ_PARTIES'
        and    tt.subject_id            = hp_sub.party_id
        and    hp_sub.party_id          = ib.end_customer_party_id
        and    tt.object_id             = hp_par.party_id
        and    tt.status                = 'A'
        and    sysdate                  between tt.start_date and nvl(tt.end_date, sysdate + 1)
        and    tt.relationship_type     = 'XX_OBJ_GLOBAL'
        and    tt.relationship_code     = 'GLOBAL_SUBSIDIARY_OF'
        and    nvl(hp_sub.attribute5,'N') = 'N'
        and    rownum = 1
        union
        select hp.party_name
        from   hz_parties               hp
        where  hp.party_id              = ib.end_customer_party_id
        and    hp.attribute5            = 'Y' -- Global Account
        and    rownum = 1
       ) Global_parent,
       -- CR1293 Adi Safin 03/02/2014
       (SELECT FFVT.DESCRIPTION
         FROM   FND_FLEX_VALUE_SETS FFVS,
                FND_FLEX_VALUES     FFV,
                FND_FLEX_VALUES_TL  FFVT
         WHERE FFVS.FLEX_VALUE_SET_NAME = 'XXCS_PRODUCT_LINE'
         AND FFVS.FLEX_VALUE_SET_ID = FFV.FLEX_VALUE_SET_ID
         AND FFVT.FLEX_VALUE_ID = FFV.FLEX_VALUE_ID
         AND FFVT.LANGUAGE = 'US'
         AND FFV.ENABLED_FLAG = 'Y'
         AND FFV.FLEX_VALUE = ib.inventory_item_id) Product_line
from
       xxcs_install_base_bi_v                     ib,
       xxcs_regions_v                             region_gr
where  ib.owner_cs_region                         = region_gr.CS_Region(+);
