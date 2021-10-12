                       CREATE OR REPLACE VIEW xxcs_ib_statistics_det_mtxx_v AS
select
--------------------------------------------------------------------
--  name:            XXCS_IB_STATISTICS_DET_MTXX_V
--  create by:       Yoram Zamir
--  Revision:        1.4
--  creation date:   17/05/2010
--------------------------------------------------------------------
--  purpose :        REP266 - MTXX Reports - Discoverer Reports
--                   late version of view  XXCS_IB_STATISTICS_DET_V
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  17/05/2010  Yoram Zamir      initial build
--  1.1  24/05/2010  Yoram Zamir      Remove wrong conditions and create outer join with owner_hist
--  1.2  14/06/2010  Vitaly           org_id was added
--  1.3  14/07/2010  Vitaly           printer_calc_install_date added
--  1.4  10/05/2012  Dalit A. Raviv/  Handle for upgrade printers. call to xxcs_ib_history tbl instead of pipeline.
--                   Yoram Zamir      this view is copy of XXCS_IB_STATISTICS_DET_V and
--                                    have some changes - this is because this view is a major view.
--                                    and we want only to correct MTXX reports.
--
--                                    DO NOT TAKE OUT STATEMENT: there is a bug in 10g DB and this give
--                                    work around to handle the bug.
--                                    + OPT_PARAM('_OPTIMIZER_PUSH_PRED_COST_BASED','FALSE')
--------------------------------------------------------------------

       /*+ OPT_PARAM('_OPTIMIZER_PUSH_PRED_COST_BASED','FALSE')*/
       ii.instance_id,
       ii.serial_number,
       -- 1.4  10/05/2012
       -- ii.inventory_item_id,
       OWNER_HIST.inventory_item_id        inventory_item_id,
       -- end 1.4
       printer.item                        printer,
       printer.item_description            printer_description,
       printer.family                      family,
       printer.item_category               item_category,
       ii.attribute8                       current_owner_cs_region, --cs_region,
       owner_hist.party_id,
       owner_hist.party_name               Customer,
       p.party_name                        Current_customer,
       refurbished.refurbished_date,
       csv.name                            end_customer,
       owner_hist.install_date             printer_install_date,
       owner_hist.calculated_install_date  printer_calc_install_date,  ---after CASE
       owner_hist.end_date                 printer_active_end_date,
       nvl(
       xxcs_mtb_report_pkg.get_factor_for_sr_statistics(XXCS_SESSION_PARAM.get_session_param_date(1),  ---p_from_date
                                                        XXCS_SESSION_PARAM.get_session_param_date(2),  ---p_to_date
                                                        nvl(owner_hist.calculated_install_date,to_date('31-JAN-2049','DD-MON-YYYY')),  ----printer install_date
                                                        nvl(owner_hist.end_date,    to_date('31-JAN-2049','DD-MON-YYYY'))   ----printer end_date
                                                                        ),0)    factor,


       to_number(p.attribute3)             org_id,
       ou.name                             operating_unit_party,
       SALES_CHANNEL_TAB.sales_channel_code,
       owner_hist.history_rank,
       ''                                  objet_internal_install_base  --- Y or N --for LOV in Disco report only
from   csi_item_instances                  ii,
       csi_systems_v                       csv,
       hz_parties                          p,
       hr_operating_units                  ou,
       XXCS_ITEMS_PRINTERS_V               printer,
       (select hist.instance_id,
               null history_rank,
               hist.end_date,
               case when hist.install_date is null then null
                    when hist.start_date > hist.install_date then hist.start_date
                    else hist.install_date
               end calculated_install_date,
               hist.install_date,
               hist.party_name,
               hist.party_id,
               hist.inventory_item_id,
               hist.item
        from   xxcs_ib_history hist        -- 1.4  10/05/2012
        where  hist.item_type              is not null
        and    hist.start_date             is not null
        and    hist.item_type              = 'PRINTER'
        and    hist.start_date             < XXCS_SESSION_PARAM.get_session_param_date(2)     -- p_to_date
        AND    nvl(hist.end_date,SYSDATE+1000)> XXCS_SESSION_PARAM.get_session_param_date(1)  -- p_from_date
        )                                              OWNER_HIST,
       (select civ.instance_id, civ.attribute_value refurbished_date
        from   csi_iea_values civ, csi_i_extended_attribs cie
        where  civ.attribute_id   = cie.attribute_id
        and    cie.attribute_code = 'OBJ_REFURBISH')   REFURBISHED,
       (SELECT ca.party_id,
               MAX(ca.sales_channel_code) sales_channel_code
        FROM   hz_cust_accounts           ca
        WHERE  ca.sales_channel_code      IS NOT NULL
        GROUP BY ca.party_id)                          SALES_CHANNEL_TAB
where
       --------------------------------------------------------------------------------------------
       /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-JAN-2009','DD-MON-YYYY'),1)=1 AND
       XXCS_SESSION_PARAM.set_session_param_date(to_date('31-DEC-2009','DD-MON-YYYY'),2)=1 AND*/
       --------------------------------------------------------------------------------------------
       ii.instance_id                     = owner_hist.instance_id
AND    p.party_id                         = ii.owner_party_id
AND    ii.instance_id                     = refurbished.instance_id (+)
AND    to_number(p.attribute3)            = ou.organization_id(+)
AND    p.party_id                         = SALES_CHANNEL_TAB.party_id(+)
AND    ii.system_id                       = csv.system_id (+)
and    owner_hist.inventory_item_id       = printer.inventory_item_id;
