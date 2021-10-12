CREATE OR REPLACE PACKAGE BODY XXCS_PNL_REPORT_PKG IS
------------------------------------------------------------------
FUNCTION get_pnl_report RETURN XXCS_PNL_REPORT_TBL PIPELINED IS



CURSOR get_pnl_data IS
SELECT cust.org_id,
       cust.operating_unit,
       pnl.source_id,
       pnl.source_name,
       pnl.customer_id,
       pnl.customer_name,
       pnl.current_owner_cs_region,
       pnl.printer_inv_item_id,
       pnl.printer_item,
       pnl.printer_item_description,
       pnl.instance_id,
       pnl.serial_number,
       LEAD(pnl.serial_number) OVER (ORDER BY cust.operating_unit,pnl.customer_id,pnl.serial_number,pnl.source_id)     next_serial_number,
       pnl.revenue,
       pnl.expense,
       CONTRACTS_TAB.contract_number,
       CONTRACTS_TAB.contract_type,
       CONTRACTS_TAB.contract_coverage,
       CONTRACTS_TAB.contract_full_period_factor
FROM  XXCS_CUSTOMER_PROPERTIES_V  cust,
      XXCS_PNL_REPORT_DET_V       pnl,
     (SELECT C_TAB.party_id,
             C_TAB.instance_id,
             C_TAB.contract_number,
             C_TAB.contract_type,
             C_TAB.contract_coverage,
             C_TAB.rank,
             decode(C_TAB.report_days,0,0,C_TAB.overlapping_days/C_TAB.report_days)       contract_full_period_factor
      FROM (SELECT a.party_id,
                   a.instance_id,
                   a.contract_number,
                   a.type       contract_type,
                   a.coverage   contract_coverage,
                   DENSE_RANK() OVER (PARTITION BY a.party_id, a.instance_id
                                      ORDER BY     a.party_id, a.instance_id,
                                                   decode(a.status,'ACTIVE',1,2),
                                                   nvl(a.line_date_terminated,a.line_end_date),
                                                   a.sub_line_id,
                                                   a.line_id)    rank,
                   XXCS_SESSION_PARAM.get_session_param_date(2)-XXCS_SESSION_PARAM.get_session_param_date(1)  report_days, --to_date - from_date
                   CASE
                      WHEN XXCS_SESSION_PARAM.get_session_param_date(2)< nvl(a.line_date_terminated,a.line_end_date) THEN
                             XXCS_SESSION_PARAM.get_session_param_date(2)
                      ELSE
                             nvl(a.line_date_terminated,a.line_end_date)
                      END
                   -
                   CASE
                      WHEN XXCS_SESSION_PARAM.get_session_param_date(1)> a.line_start_date THEN
                             XXCS_SESSION_PARAM.get_session_param_date(1)
                      ELSE
                             a.line_start_date
                      END    overlapping_days
            FROM   XXCS_INST_CONTR_AND_WARR_ALL_V  a
            WHERE a.line_start_date < XXCS_SESSION_PARAM.get_session_param_date(2)  --report to_date
            AND   nvl(a.line_date_terminated,a.line_end_date) > XXCS_SESSION_PARAM.get_session_param_date(1)  --report from_date
                    ) C_TAB
      WHERE C_TAB.rank=1
                       )    CONTRACTS_TAB
WHERE /*XXCS_SESSION_PARAM.set_session_param_date(to_date('01-JAN-2010','DD-MON-YYYY'),1)=1 AND
      XXCS_SESSION_PARAM.set_session_param_date(to_date('31-MAR-2010','DD-MON-YYYY'),2)=1 AND*/
      pnl.customer_id=cust.party_id(+)
AND   pnl.customer_id=CONTRACTS_TAB.party_id(+)
AND   pnl.instance_id=CONTRACTS_TAB.instance_id(+)
ORDER BY cust.operating_unit,pnl.customer_id,pnl.serial_number,pnl.source_id;



v_pnl_rec                          XXCS_PNL_REPORT_REC;
v_org_id                           NUMBER;
v_operating_unit                   VARCHAR2(300);
v_source_id                        NUMBER;
v_source_name                      VARCHAR2(300);
v_customer_id                      NUMBER;
v_customer_name                    VARCHAR2(300);
v_current_owner_cs_region          VARCHAR2(300);
v_printer_inv_item_id              NUMBER;
v_printer                          VARCHAR2(300);
v_printer_description              VARCHAR2(300);
v_instance_id                      NUMBER;
v_serial_number                    VARCHAR2(300);
v_next_serial_number               VARCHAR2(300);
v_revenue_usd                      NUMBER;
v_expense_usd                      NUMBER;
v_contract_number                  VARCHAR2(300);
v_contract_type                    VARCHAR2(300);
v_contract_coverage                VARCHAR2(300);
v_contract_full_period_factor      NUMBER;
v_total_expense_per_serial_num     NUMBER:=0;
v_total_revenue_per_serial_num     NUMBER:=0;
v_numeric_mask                     VARCHAR2(100):='999,990.00';



BEGIN


IF get_pnl_data%ISOPEN THEN
   CLOSE get_pnl_data;
END IF;
OPEN  get_pnl_data;
LOOP
   FETCH get_pnl_data INTO v_org_id,
                           v_operating_unit,
                           v_source_id,
                           v_source_name,
                           v_customer_id,
                           v_customer_name,
                           v_current_owner_cs_region,
                           v_printer_inv_item_id,
                           v_printer,
                           v_printer_description,
                           v_instance_id,
                           v_serial_number,
                           v_next_serial_number,
                           v_revenue_usd,
                           v_expense_usd,
                           v_contract_number,
                           v_contract_type,
                           v_contract_coverage,
                           v_contract_full_period_factor;
   EXIT WHEN get_pnl_data%NOTFOUND;
   v_pnl_rec.org_id                      :=v_org_id;
   v_pnl_rec.operating_unit              :=v_operating_unit;
   v_pnl_rec.source_id                   :=v_source_id;
   v_pnl_rec.source_name                 :=v_source_name;
   v_pnl_rec.customer_id                 :=v_customer_id;
   v_pnl_rec.customer_name               :=v_customer_name;
   v_pnl_rec.current_owner_cs_region     :=v_current_owner_cs_region;
   v_pnl_rec.printer_inv_item_id         :=v_printer_inv_item_id;
   v_pnl_rec.printer                     :=v_printer;
   v_pnl_rec.printer_description         :=v_printer_description;
   v_pnl_rec.instance_id                 :=v_instance_id;
   v_pnl_rec.serial_number               :=v_serial_number;
   v_pnl_rec.revenue_usd                 :=v_revenue_usd;
   v_pnl_rec.expense_usd                 :=v_expense_usd;
   v_pnl_rec.profit_usd                  :=0;
   v_pnl_rec.contract_number             :=v_contract_number;
   v_pnl_rec.contract_type               :=v_contract_type;
   v_pnl_rec.contract_coverage           :=v_contract_coverage;
   v_pnl_rec.contract_full_period_factor :=v_contract_full_period_factor;
   v_pnl_rec.revenue_usd_str             :=ltrim(to_char(v_revenue_usd,v_numeric_mask));
   v_pnl_rec.expense_usd_str             :=ltrim(to_char(v_expense_usd,v_numeric_mask));
   IF v_source_id=2 OR    -----'Service Contracts'  revenue only
      v_source_id=3 THEN  -----'Warranties'         revenue only
      v_pnl_rec.expense_usd_str:='N/A';
   END IF;
   IF v_source_id=4 THEN  -----'Charges'            expense only
      v_pnl_rec.revenue_usd_str:='N/A';
   END IF;
   ------------------------------------
   PIPE ROW (v_pnl_rec);
   ------------------------------------
   IF v_source_id IN (1,2,3,4) THEN --1--'Sales Order'; 2--'Service Contracts'; 3--'Warranties';4--'Charges'
      v_total_expense_per_serial_num:= v_total_expense_per_serial_num+v_expense_usd;
      v_total_revenue_per_serial_num:= v_total_revenue_per_serial_num+v_revenue_usd;
   END IF;
   IF v_pnl_rec.serial_number<>v_next_serial_number OR
      v_next_serial_number IS NULL THEN   ---before last serial number
      -----Prepare 'Total Per SN and Customer' record
      v_pnl_rec.org_id                      :=v_org_id;
      v_pnl_rec.operating_unit              :=v_operating_unit;
      v_pnl_rec.source_id                   :=50;
      v_pnl_rec.source_name                 :='Total Per SN and Customer';
      v_pnl_rec.customer_id                 :=v_customer_id;
      v_pnl_rec.customer_name               :=v_customer_name;
      v_pnl_rec.current_owner_cs_region     :=v_current_owner_cs_region;
      v_pnl_rec.printer_inv_item_id         :=v_printer_inv_item_id;
      v_pnl_rec.printer                     :=v_printer;
      v_pnl_rec.printer_description         :=v_printer_description;
      v_pnl_rec.instance_id                 :=v_instance_id;
      v_pnl_rec.serial_number               :=v_serial_number;
      v_pnl_rec.revenue_usd                 :=v_total_revenue_per_serial_num;
      v_pnl_rec.expense_usd                 :=v_total_expense_per_serial_num;
      v_pnl_rec.profit_usd                  :=v_total_revenue_per_serial_num-v_total_expense_per_serial_num;
      v_pnl_rec.revenue_usd_str             :=ltrim(to_char(v_total_revenue_per_serial_num,v_numeric_mask));
      v_pnl_rec.expense_usd_str             :=ltrim(to_char(v_total_expense_per_serial_num,v_numeric_mask));
      v_pnl_rec.contract_number             :=v_contract_number;
      v_pnl_rec.contract_type               :=v_contract_type;
      v_pnl_rec.contract_coverage           :=v_contract_coverage;
      v_pnl_rec.contract_full_period_factor :=v_contract_full_period_factor;
      ------------------------------------
      PIPE ROW (v_pnl_rec);
      ------------------------------------
      v_total_expense_per_serial_num:=0;
      v_total_revenue_per_serial_num:=0;
   END IF;
END LOOP;
CLOSE get_pnl_data;

-----Prepare 'Total Per SN and Customer' record FOR LAST SERIAL NUMBER
v_pnl_rec.org_id                      :=v_org_id;
v_pnl_rec.operating_unit              :=v_operating_unit;
v_pnl_rec.source_id                   :=50;
v_pnl_rec.source_name                 :='Total Per SN and Customer';
v_pnl_rec.customer_id                 :=v_customer_id;
v_pnl_rec.customer_name               :=v_customer_name;
v_pnl_rec.current_owner_cs_region     :=v_current_owner_cs_region;
v_pnl_rec.printer_inv_item_id         :=v_printer_inv_item_id;
v_pnl_rec.printer                     :=v_printer;
v_pnl_rec.printer_description         :=v_printer_description;
v_pnl_rec.instance_id                 :=v_instance_id;
v_pnl_rec.serial_number               :=v_serial_number;
v_pnl_rec.revenue_usd                 :=v_total_revenue_per_serial_num;
v_pnl_rec.expense_usd                 :=v_total_expense_per_serial_num;
v_pnl_rec.profit_usd                  :=v_total_revenue_per_serial_num-v_total_expense_per_serial_num;
v_pnl_rec.revenue_usd_str             :=ltrim(to_char(v_total_revenue_per_serial_num,v_numeric_mask));
v_pnl_rec.expense_usd_str             :=ltrim(to_char(v_total_expense_per_serial_num,v_numeric_mask));
v_pnl_rec.contract_number             :=v_contract_number;
v_pnl_rec.contract_type               :=v_contract_type;
v_pnl_rec.contract_coverage           :=v_contract_coverage;
v_pnl_rec.contract_full_period_factor :=v_contract_full_period_factor;
------------------------------------
PIPE ROW (v_pnl_rec);
------------------------------------

RETURN;


EXCEPTION
  WHEN OTHERS THEN
    NULL;
END get_pnl_report;
------------------------------------------------------------------
END XXCS_PNL_REPORT_PKG;
/

