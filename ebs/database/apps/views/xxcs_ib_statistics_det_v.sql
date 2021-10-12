CREATE OR REPLACE VIEW XXCS_IB_STATISTICS_DET_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_IB_STATISTICS_DET_V
--  create by:       Yoram Zamir
--  Revision:        1.3
--  creation date:   17/05/2010
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  17/05/2010  Yoram Zamir      initial build
--  1.1  24/05/2010  Yoram Zamir      Remove wrong conditions and create outer join with owner_hist
--  1.2  14/06/2010  Vitaly           org_id was added
--  1.3  14/07/2010  Vitaly           printer_calc_install_date added
--------------------------------------------------------------------
       IB_PRINTERS_TAB.instance_id,
       IB_PRINTERS_TAB.serial_number,
       IB_PRINTERS_TAB.inventory_item_id,
       IB_PRINTERS_TAB.printer,
       IB_PRINTERS_TAB.printer_description,
       IB_PRINTERS_TAB.family,
       IB_PRINTERS_TAB.item_category,
       IB_PRINTERS_TAB.cs_region     current_owner_cs_region,
       IB_PRINTERS_TAB.Current_customer,
       IB_PRINTERS_TAB.end_customer,
       IB_PRINTERS_TAB.printer_install_date,
       IB_PRINTERS_TAB.printer_calc_install_date,  ---after CASE
       IB_PRINTERS_TAB.printer_active_end_date,
       nvl(IB_PRINTERS_TAB.factor,0) factor,
       IB_PRINTERS_TAB.Customer,
       IB_PRINTERS_TAB.party_id,
       IB_PRINTERS_TAB.refurbished_date,
       IB_PRINTERS_TAB.org_id,
       IB_PRINTERS_TAB.operating_unit_party,
       IB_PRINTERS_TAB.sales_channel_code,
       IB_PRINTERS_TAB.history_rank,
       ''              objet_internal_install_base  --- Y or N --for LOV in Disco report only
FROM
     (---all printers in IB that are active during the report time
      select ii.instance_id,
             ii.serial_number,
             ii.inventory_item_id,
             msi.segment1            printer,
             msi.description         printer_description,
             mtc.segment2            family,
             mtc.segment3            item_category,
             ii.attribute8           cs_region,  ---current owner region
             owner_hist.party_id,
             owner_hist.party_name   Customer,
             p.party_name            Current_customer,
             refurbished.refurbished_date,
             csv.name                end_customer,
             owner_hist.install_date                 printer_install_date,
             owner_hist.calculated_install_date      printer_calc_install_date,  ---after CASE
             owner_hist.end_date                     printer_active_end_date,

             xxcs_mtb_report_pkg.get_factor_for_sr_statistics(XXCS_SESSION_PARAM.get_session_param_date(1),  ---p_from_date
                                                              XXCS_SESSION_PARAM.get_session_param_date(2),  ---p_to_date
                                                              nvl(owner_hist.calculated_install_date,to_date('31-JAN-2049','DD-MON-YYYY')),  ----printer install_date
                                                              nvl(owner_hist.end_date,    to_date('31-JAN-2049','DD-MON-YYYY'))   ----printer end_date
                                                                              )    factor,
             to_number(p.attribute3)  org_id,
             ou.name                  operating_unit_party,
             SALES_CHANNEL_TAB.sales_channel_code,
             owner_hist.history_rank
      from   csi_item_instances                           ii,
             csi_systems_v                                csv,
             hz_parties                                   p,
             hr_operating_units                           ou,
             mtl_item_categories                          mic,
             mtl_categories_b                             mtc,
             mtl_system_items_b                           msi,
             (SELECT bz.instance_id ,
                     bz.history_rank,
                     bz.end_date,
                     bz.calculated_install_date,  ---after CASE
                     bz.install_date,
                     bz.party_name,
                     bz.party_id
              FROM   XXCS_INSTANCE_OWNER_HISTORY_V bz
              WHERE  bz.ownership_date  < XXCS_SESSION_PARAM.get_session_param_date(2)  ---p_to_date
              AND    nvl(bz.end_date,SYSDATE+1000)> XXCS_SESSION_PARAM.get_session_param_date(1)  ---p_from_date
              AND    bz.item_type IS NOT NULL      ---Printers and Water Jets ONLY
              AND    bz.ownership_date IS NOT NULL ---Installed printers only
                                               )          OWNER_HIST,
             (select civ.instance_id, civ.attribute_value refurbished_date
              from csi_iea_values civ, csi_i_extended_attribs cie
              where civ.attribute_id = cie.attribute_id
              and cie.attribute_code = 'OBJ_REFURBISH')   REFURBISHED,
             (SELECT ca.party_id,
                     MAX(ca.sales_channel_code)   sales_channel_code
              FROM   hz_cust_accounts   ca
              WHERE  ca.sales_channel_code IS NOT NULL
              GROUP BY ca.party_id)                       SALES_CHANNEL_TAB
      where
             --------------------------------------------------------------------------------------------
             /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-JAN-2009','DD-MON-YYYY'),1)=1 AND
             XXCS_SESSION_PARAM.set_session_param_date(to_date('31-DEC-2009','DD-MON-YYYY'),2)=1 AND*/
             --------------------------------------------------------------------------------------------
             ii.instance_id =         owner_hist.instance_id (+)
      AND    p.party_id =             ii.owner_party_id
      AND    ii.instance_id =         refurbished.instance_id (+)
      AND    to_number(p.attribute3)= ou.organization_id(+)
      AND    p.party_id=              SALES_CHANNEL_TAB.party_id(+)
      AND    ii.system_id =           csv.system_id (+)
      and    ii.inventory_item_id =   mic.inventory_item_id
      and    mtc.category_id =        mic.category_id
      and    mic.inventory_item_id=   msi.inventory_item_id
      and    mic.organization_id =    msi.organization_id
      and    mic.category_set_id =    1100000041
      and    mtc.enabled_flag =       'Y'
      and    msi.organization_id =    91
      and    mtc.attribute4 =         'PRINTER'
                                        )   IB_PRINTERS_TAB;

