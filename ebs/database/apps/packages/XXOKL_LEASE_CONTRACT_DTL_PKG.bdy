CREATE OR REPLACE PACKAGE BODY XXOKL_LEASE_CONTRACT_DTL_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXOKL_LEASE_CONTRACT_DTL_PKG.bdy
Author's Name:   Sandeep Akula
Date Written:    26-MARCH-2014
Purpose:         Find Various Column Values for XX: OKL Lease Contract Details Report
Program Style:   Stored Package
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
26-MARCH-2014        1.0                  Sandeep Akula
---------------------------------------------------------------------------------------------------*/
FUNCTION GET_BILL_TO_ADDRESS(P_CONTRACT_ID IN NUMBER)
RETURN VARCHAR2 IS

l_contract_id NUMBER;
l_bill_to_address    Varchar2(2000);
l_bill_to_address_id    NUMBER;

CURSOR c_get_bill_to_address_id(c_id1 NUMBER)
IS
SELECT bill_to_site_use_id
FROM OKC_K_HEADERS_B
WHERE id = c_id1;

CURSOR c_get_bill_to_address(c_id1 NUMBER,c_id2 VARCHAR2)
IS
SELECT description
FROM okx_cust_site_uses_v
WHERE id1=c_id1
AND id2=c_id2;

BEGIN

-- Get the bill_to_address_id from okc_k_headers_b
OPEN c_get_bill_to_Address_id(P_CONTRACT_ID); --l_contract_id
FETCH c_get_bill_to_Address_id INTO l_bill_to_address_id;
CLOSE c_get_bill_to_Address_id;

--Get the value for bill_to_address from view here.
OPEN c_get_bill_to_Address(l_bill_to_address_id, '#');
FETCH c_get_bill_to_Address INTO l_bill_to_address;
CLOSE c_get_bill_to_Address;

--dbms_output.put_line('l_bill_to_address :'||l_bill_to_address);
RETURN(l_bill_to_address);

EXCEPTION
WHEN OTHERS THEN
RETURN(NULL);
END GET_BILL_TO_ADDRESS;

FUNCTION GET_CUSTOMER_ACCOUNT_NUMBER(P_CUST_ACCT_ID IN NUMBER)
RETURN VARCHAR2 IS
l_account_num varchar2(30);
BEGIN

begin
select account_number
into l_account_num
from hz_cust_accounts_all
where cust_Account_id = P_CUST_ACCT_ID;

exception
when others then
l_account_num := '';
end;

RETURN(l_account_num);

END GET_CUSTOMER_ACCOUNT_NUMBER;

FUNCTION GET_OUTSTANDING_INVOICES(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_outstanding_invoices  NUMBER := '';
BEGIN
l_outstanding_invoices := okl_cs_lc_contract_pvt.get_total_billed(p_khr_id    => P_CONTRACT_ID);
RETURN(l_outstanding_invoices);
END GET_OUTSTANDING_INVOICES;

FUNCTION GET_APPLIED_AMOUNTS(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_applied_amounts  NUMBER := '';
BEGIN
l_applied_amounts := okl_cs_lc_contract_pvt.get_total_paid_credited(p_khr_id    => P_CONTRACT_ID);
RETURN(l_applied_amounts);
END GET_APPLIED_AMOUNTS;

FUNCTION GET_AMOUNT_REMAINING(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_amt_remaining  NUMBER := '';
BEGIN
l_amt_remaining := okl_cs_lc_contract_pvt.get_total_remaining(p_khr_id    => P_CONTRACT_ID);
RETURN(l_amt_remaining);
END GET_AMOUNT_REMAINING;

FUNCTION GET_AMOUNT_PAST_DUE(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_billed_rcvbl        NUMBER := '';
BEGIN
/*okl_cs_lc_contract_pvt.outstanding_billed_amt(p_contract_id  => P_CONTRACT_ID,
                                              o_billed_amt   => l_billed_rcvbl);*/
l_billed_rcvbl := OKL_SEEDED_FUNCTIONS_PVT.CONTRACT_UNPAID_INVOICES(P_CONTRACT_ID,'');
RETURN(l_billed_rcvbl);
END GET_AMOUNT_PAST_DUE;


FUNCTION GET_UNBILLED_PAST_DUE(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_unbilled_rcvbl      NUMBER;
BEGIN
/*okl_cs_lc_contract_pvt.outstanding_unbilled_amt(p_contract_id    => P_CONTRACT_ID,
                                                o_unbilled_amt   => l_unbilled_rcvbl);*/
l_unbilled_rcvbl:= OKL_SEEDED_FUNCTIONS_PVT.CONTRACT_UNBILLED_STREAMS(P_CONTRACT_ID,'');
RETURN(l_unbilled_rcvbl);
END GET_UNBILLED_PAST_DUE;


FUNCTION GET_TERM(P_CONTRACT_ID IN NUMBER)
RETURN VARCHAR2 IS
l_start_date          DATE;
l_end_date            DATE;
l_term                NUMBER;
BEGIN

okl_cs_lc_contract_pvt.contract_dates(p_contract_id     => P_CONTRACT_ID,
                                      o_start_date      => l_start_date,
                                      o_end_date        => l_end_date,
                                      o_term_duration   => l_term);

RETURN(l_term);
END GET_TERM;

FUNCTION GET_LAST_PAYMENT_DATE(P_CONTRACT_ID IN NUMBER,
                               P_CUST_ACCT_ID IN NUMBER)
RETURN VARCHAR2 IS
l_last_payment_amount NUMBER;
l_last_payment_date   DATE;
BEGIN
okl_cs_lc_contract_pvt.last_due(p_customer_id   => P_CUST_ACCT_ID,
                                p_contract_id => P_CONTRACT_ID,
                                o_last_due_amt    => l_last_payment_amount,
                                o_last_due_date   => l_last_payment_date);

RETURN(to_char(l_last_payment_date,'MM/DD/RRRR'));
END GET_LAST_PAYMENT_DATE;

FUNCTION GET_LAST_PAYMENT_AMOUNT(P_CONTRACT_ID IN NUMBER,
                                 P_CUST_ACCT_ID IN NUMBER)
RETURN NUMBER IS
l_last_payment_amount NUMBER;
l_last_payment_date   DATE;
BEGIN
okl_cs_lc_contract_pvt.last_due(p_customer_id   => P_CUST_ACCT_ID,
                                p_contract_id => P_CONTRACT_ID,
                                o_last_due_amt    => l_last_payment_amount,
                                o_last_due_date   => l_last_payment_date);

RETURN(l_last_payment_amount);
END GET_LAST_PAYMENT_AMOUNT;

FUNCTION GET_NEXT_PAYMENT_DATE(P_CONTRACT_ID IN NUMBER)
RETURN VARCHAR2 IS
l_Next_payment_amount NUMBER;
l_Next_payment_date   DATE;
BEGIN
okl_cs_lc_contract_pvt.next_due(p_contract_id => P_CONTRACT_ID,
                                o_next_due_amt    => l_next_payment_amount,
                                o_next_due_date   => l_next_payment_date);
RETURN(to_char(l_next_payment_date,'MM/DD/RRRR'));
END GET_NEXT_PAYMENT_DATE;


FUNCTION GET_NEXT_PAYMENT_AMOUNT(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l2_Next_payment_amount NUMBER;
l2_Next_payment_date   DATE;
BEGIN
/*okl_cs_lc_contract_pvt.next_due(p_contract_id => P_CONTRACT_ID,
                                o_next_due_amt    => l2_next_payment_amount,
                                o_next_due_date   => l2_next_payment_date);*/
l2_Next_payment_amount := OKL_SEEDED_FUNCTIONS_PVT.CONTRACT_NEXT_PAYMENT_AMOUNT(P_CONTRACT_ID,'');
RETURN(l2_next_payment_amount);
END GET_NEXT_PAYMENT_AMOUNT;

/*FUNCTION GET_PAYMENTS_REMAINING(P_CONTRACT_ID IN NUMBER)
RETURN VARCHAR2 IS
l_payments_remaining  VARCHAR2(1000);
BEGIN
l_payments_remaining := okl_cs_lc_contract_pvt.get_payment_remaining(p_khr_id => P_CONTRACT_ID);
RETURN(l_payments_remaining);
END GET_PAYMENTS_REMAINING; */

FUNCTION GET_PAYMENTS_REMAINING(P_CONTRACT_ID IN NUMBER,
                                P_DATE IN DATE)
RETURN NUMBER IS
l_payments_remaining  NUMBER;
BEGIN
select count(*)
into l_payments_remaining
FROM OKL_CS_PAYMENT_SCH_HDR_UV a,
     OKL_CS_PAYMENT_SCH_DTLS_UV b,
     OKC_K_HEADERS_TL CHRT,
     OKC_K_HEADERS_ALL_B CHR
WHERE a.khr_id = b.khr_id and
      a.sty_id = b.sty_id and
      a.status_code = 'CURR' and
      upper(a.stream_type) = 'PRINCIPAL PAYMENT' and
      a.khr_id = chr.id and
      CHRT.ID   = CHR.ID  and
      CHRT.LANGUAGE    = USERENV('LANG') and
      CHR.id = P_CONTRACT_ID and
      b.stream_element_date > NVL(trunc(P_DATE),trunc(sysdate));
RETURN(l_payments_remaining);
END GET_PAYMENTS_REMAINING;

FUNCTION GET_TERMS_REMAINING(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_terms_remaining NUMBER;
BEGIN
l_terms_remaining := okl_cs_lc_contract_pvt.get_term_remaining(p_khr_id    => P_CONTRACT_ID);
RETURN(l_terms_remaining);
END GET_TERMS_REMAINING;


FUNCTION GET_TOTAL_ASSET_COST(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_total_asset_cost    NUMBER;
BEGIN
okl_cs_lc_contract_pvt.total_asset_cost(p_contract_id  => P_CONTRACT_ID,
                                        o_asset_cost     =>l_total_asset_cost);
RETURN(l_total_asset_cost);
END GET_TOTAL_ASSET_COST;


FUNCTION GET_SUBSIDISED_COST(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_total_subsidy_cost  NUMBER;
l_total_asset_cost    NUMBER;
BEGIN

okl_cs_lc_contract_pvt.total_asset_cost(p_contract_id  => P_CONTRACT_ID,
                                        o_asset_cost     =>l_total_asset_cost);
--dbms_output.put_line('l_total_asset_cost :'||l_total_asset_cost);
okl_cs_lc_contract_pvt.total_subsidy_cost(p_contract_id  => P_CONTRACT_ID,
                                          o_subsidy_cost     =>l_total_subsidy_cost);


IF l_total_asset_cost IS NOT NULL OR l_total_asset_cost > 0 THEN

l_total_subsidy_cost := l_total_asset_cost - l_total_subsidy_cost;
ELSE
 -- If total asset cost is Null or zero then set the subsidised cost
 -- same as asset cost.
l_total_subsidy_cost := nvl(l_total_asset_cost,0);
END IF;

RETURN(l_total_subsidy_cost);
--dbms_output.put_line('l_total_subsidy_cost2 :'||l_total_subsidy_cost);  -- Final Subsidy Cost

END GET_SUBSIDISED_COST;


FUNCTION GET_SECURITY_DEPOSIT(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_interest_type       VARCHAR2(100);
l_security_deposit    NUMBER;
l_advance_rent        NUMBER;
BEGIN
okl_cs_lc_contract_pvt.rent_security_interest(p_contract_id     => P_CONTRACT_ID,
                                              o_advance_rent     => l_advance_rent,
                                              o_security_deposit => l_security_deposit,
                                              o_interest_type    => l_interest_type);
RETURN(l_security_deposit);
END GET_SECURITY_DEPOSIT;

FUNCTION GET_ADVANCE_RENT(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_interest_type       VARCHAR2(100);
l_security_deposit    NUMBER;
l_advance_rent        NUMBER;
BEGIN
okl_cs_lc_contract_pvt.rent_security_interest(p_contract_id     => P_CONTRACT_ID,
                                              o_advance_rent     => l_advance_rent,
                                              o_security_deposit => l_security_deposit,
                                              o_interest_type    => l_interest_type);
RETURN(l_advance_rent);
END GET_ADVANCE_RENT;

FUNCTION GET_SERIAL_NUMBER(P_OBJECT1_ID1 IN VARCHAR2,
                           P_OBJECT1_ID2 IN VARCHAR2,
                           P_CLE_ID IN NUMBER,
                           P_STATUS IN VARCHAR2)
RETURN VARCHAR2 IS

CURSOR c_serialno(p_id1 IN varchar2,p_id2 IN VARCHAR2) IS
      SELECT oii.serial_number,
             oii.instance_id,
             oii.inventory_item_id,
             oii.INV_ORGANIZATION_ID
      FROM   okx_install_items_v oii
      WHERE  oii.id1 = p_id1
      AND oii.id2 = p_id2;

    CURSOR c_serial(p_cle_id   IN NUMBER) IS
    SELECT serial_number,
           INVENTORY_ITEM_ID,
           INVENTORY_ORG_ID
    FROM okl_txl_itm_insts_v
    WHERE kle_id = p_cle_id;

  l_object1_id1             VARCHAR2(30);
  l_object1_id2              VARCHAR2(200);
  l_serial_no                VARCHAR2(30);
  l_instance_id              NUMBER;
  l_inventory_item_id        NUMBER;
  l_cle_id                   NUMBER;
  l_inv_org_id               NUMBER;

BEGIN

IF  P_STATUS IN ('BOOKED','EVERGREEN','BANKRUPTCY_HOLD','LITIGATION_HOLD','APPROVED','TERMINATED','EXPIRED') THEN
    OPEN c_serialno(P_OBJECT1_ID1,P_OBJECT1_ID2);
    FETCH c_serialno INTO l_serial_no,l_instance_id,l_inventory_item_id,l_inv_org_id;
    CLOSE c_serialno;
ELSE
    OPEN c_serial(P_CLE_ID);
    FETCH c_serial INTO l_serial_no,l_inventory_item_id,l_inv_org_id;
    CLOSE c_serial;
END IF;

RETURN(l_serial_no);
END GET_SERIAL_NUMBER;


FUNCTION GET_PRINCIPAL_TOTAL(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_principal_total NUMBER;
BEGIN

begin
select sum(amount)
into l_principal_total
from OKL_CS_PAYMENT_SCH_HDR_UV
where khr_id = P_CONTRACT_ID and
      status_code = 'CURR' and
      upper(stream_type) = 'PRINCIPAL PAYMENT';
exception
when others then
l_principal_total := null;
end;

RETURN(l_principal_total);

END GET_PRINCIPAL_TOTAL;


FUNCTION GET_INTEREST_TOTAL(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_interest_total NUMBER;
BEGIN

begin
select sum(amount)
into l_interest_total
from OKL_CS_PAYMENT_SCH_HDR_UV
where khr_id = P_CONTRACT_ID and
      status_code = 'CURR' and
      upper(stream_type) = 'INTEREST PAYMENT';
exception
when others then
l_interest_total := null;
end;

RETURN(l_interest_total);

END GET_INTEREST_TOTAL;

FUNCTION GET_LEASE_MAINT_TOTAL(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_lease_maint_total NUMBER;
BEGIN

begin
select sum(amount)
into l_lease_maint_total
from OKL_CS_PAYMENT_SCH_HDR_UV
where khr_id = P_CONTRACT_ID and
      status_code = 'CURR' and
      upper(stream_type) = 'LEASE MAINTENANCE';
exception
when others then
l_lease_maint_total := null;
end;

RETURN(l_lease_maint_total);
END GET_LEASE_MAINT_TOTAL;

FUNCTION GET_STREAM_TYPES(P_CONTRACT_ID IN NUMBER)
RETURN VARCHAR2 IS
l_stream_type varchar2(1000);
cursor c_stream_type is
select stream_type
from OKL_CS_PAYMENT_SCH_HDR_UV
where khr_id = P_CONTRACT_ID and
      status_code = 'CURR';
BEGIN
l_stream_type := '';
for c_1 in c_stream_type loop
l_stream_type := l_stream_type||','||c_1.stream_type;
end loop;

RETURN(substr(l_stream_type,2));
END GET_STREAM_TYPES;

FUNCTION GET_LEASE_MAINT_REMAINING(P_CONTRACT_ID IN NUMBER,
                                   P_DATE IN DATE)
RETURN NUMBER IS
l_amt  NUMBER;
BEGIN

begin
SELECT SUM(b.amount)
INTO l_amt
FROM OKL_CS_PAYMENT_SCH_HDR_UV a,
     OKL_CS_PAYMENT_SCH_DTLS_UV b,
     OKC_K_HEADERS_TL CHRT,
     OKC_K_HEADERS_ALL_B CHR
WHERE a.khr_id = b.khr_id and
      a.sty_id = b.sty_id and
      a.status_code = 'CURR' and
      upper(a.stream_type) = 'LEASE MAINTENANCE' and
      a.khr_id = chr.id and
      CHRT.ID   = CHR.ID  and
      CHRT.LANGUAGE    = USERENV('LANG') and
      CHR.id = P_CONTRACT_ID and
      b.stream_element_date > NVL(trunc(P_DATE),trunc(sysdate));

exception
when others then
l_amt := '0';
end;
RETURN(l_amt);
END GET_LEASE_MAINT_REMAINING;

/*FUNCTION GET_TOTAL_PRINCIPAL_REMAINING(P_CONTRACT_ID IN NUMBER,
                                       P_DATE IN DATE)
RETURN NUMBER IS
l_return_status  varchar2(100);
l_principal_remaining  NUMBER;
l_lease_maintenance_cnt NUMBER;
l_lease_maintenance_amt NUMBER;
BEGIN

l_principal_remaining := OKL_VARIABLE_INT_UTIL_PVT.get_principal_bal(x_return_status => l_return_status,
                                                                         p_khr_id        => P_CONTRACT_ID, --> Contract ID
                                                                         p_kle_id        => null,
                                                                         p_Date          => NVL(P_DATE,SYSDATE));

l_lease_maintenance_cnt :=  GET_LEASE_MAINTENANCE_CNT(P_CONTRACT_ID,P_DATE);

IF l_lease_maintenance_cnt > '0' THEN
l_lease_maintenance_amt :=  GET_LEASE_MAINTENANCE_AMOUNT(P_CONTRACT_ID,P_DATE);
l_principal_remaining := l_principal_remaining + nvl(l_lease_maintenance_amt,'0');
ELSE
NULL;
END IF;

RETURN(l_principal_remaining);
END GET_TOTAL_PRINCIPAL_REMAINING;  */

FUNCTION GET_PRINCIPAL_REMAINING(P_CONTRACT_ID IN NUMBER,
                                 P_DATE IN DATE)
RETURN NUMBER IS
l_return_status  varchar2(100);
l_principal_remaining  NUMBER;
BEGIN

l_principal_remaining := OKL_VARIABLE_INT_UTIL_PVT.get_principal_bal(x_return_status => l_return_status,
                                                                         p_khr_id        => P_CONTRACT_ID, --> Contract ID
                                                                         p_kle_id        => null,
                                                                         p_Date          => NVL(P_DATE,SYSDATE));

RETURN(l_principal_remaining);
END GET_PRINCIPAL_REMAINING;

FUNCTION GET_INTEREST_REMAINING(P_CONTRACT_ID IN NUMBER,
                                P_DATE IN DATE)
RETURN NUMBER IS
l_amt NUMBER;
BEGIN

begin
select sum(amount)
into l_amt
from okl_cs_payment_detail_uv
where khr_id = P_CONTRACT_ID and
sty_id in (select sty_id
from okl_cs_payment_summary_uv
where khr_id = P_CONTRACT_ID and
status_code = 'CURR' and
stream_type = 'INTEREST PAYMENT') and
stream_element_date > NVL(trunc(P_DATE),trunc(sysdate));
exception
when others then
l_amt := null;
end;

RETURN(l_amt);
END GET_INTEREST_REMAINING;

/*FUNCTION GET_INTEREST_REMAINING(P_CONTRACT_ID IN NUMBER)
RETURN NUMBER IS
l_amt NUMBER;
BEGIN

begin
select sum(amount)
into l_amt
from okl_cs_payment_detail_uv
where khr_id = P_CONTRACT_ID and
sty_id in (select sty_id
from okl_cs_payment_summary_uv
where khr_id = P_CONTRACT_ID and
status_code = 'CURR' and
stream_type = 'INTEREST PAYMENT') and
stream_element_date >= trunc(sysdate);
exception
when others then
l_amt := null;
end;

RETURN(l_amt);
END GET_INTEREST_REMAINING;*/

FUNCTION GET_PRINCIPAL_INTEREST_TOTAL(P_PRINCIPAL_REMAINING IN NUMBER,
                                      P_INTEREST_REMAINING IN NUMBER)
RETURN NUMBER IS
l_amt NUMBER;
BEGIN
l_amt := '';
l_amt := ROUND(NVL(P_PRINCIPAL_REMAINING,'0') + NVL(P_INTEREST_REMAINING,'0'),2);
RETURN(l_amt);
END GET_PRINCIPAL_INTEREST_TOTAL;

FUNCTION GET_PRINCPL_INTRST_LEASE_TOTAL(P_PRINCIPAL_REMAINING IN NUMBER,
                                        P_INTEREST_REMAINING IN NUMBER,
                                        P_LEASE_REMAINING IN NUMBER)
RETURN NUMBER IS
l_amt NUMBER;
BEGIN
l_amt := '';
l_amt := ROUND(NVL(P_PRINCIPAL_REMAINING,'0') + NVL(P_INTEREST_REMAINING,'0') + NVL(P_LEASE_REMAINING,'0'),2);
RETURN(l_amt);
END GET_PRINCPL_INTRST_LEASE_TOTAL;

/*FUNCTION GET_SHORT_TERM_LIABILITY(P_PAYMENTS_REMAINING IN NUMBER,
                                  --P_NEXT_PAYMENT_AMOUNT IN NUMBER,
                                  P_PAYMENT_AMOUNT IN NUMBER,
                                  P_PAYMENT_FREQUENCY IN VARCHAR2)
RETURN NUMBER IS
l_short_term_liability  NUMBER;
l_payments  NUMBER;
BEGIN

IF P_PAYMENT_FREQUENCY = 'A' THEN
l_payments := '1';
ELSIF P_PAYMENT_FREQUENCY = 'M' THEN
l_payments := '12';
ELSIF P_PAYMENT_FREQUENCY = 'Q' THEN
l_payments := '4';
ELSIF P_PAYMENT_FREQUENCY = 'S' THEN
l_payments := '2';
END IF;

begin
IF P_PAYMENTS_REMAINING >= l_payments THEN
l_short_term_liability := nvl(P_PAYMENT_AMOUNT,0) * nvl(l_payments,0);
ELSIF P_PAYMENTS_REMAINING < l_payments THEN
l_short_term_liability := nvl(P_PAYMENTS_REMAINING,0) * nvl(P_PAYMENT_AMOUNT,0);
END IF;
exception
when others then
l_short_term_liability := null;
end;

RETURN(l_short_term_liability);
END GET_SHORT_TERM_LIABILITY;  */

/*FUNCTION GET_LONG_TERM_LIABILITY(P_TOTAL_PRINCIPAL_REMAINING IN NUMBER,
                                 P_INTEREST_REMAINING IN NUMBER,
                                 P_SHORT_TERM_LIABILITY IN NUMBER,
                                 P_PAYMENTS_REMAINING IN NUMBER,
                                 P_PAYMENT_FREQUENCY IN VARCHAR2,
                                 --P_NEXT_PAYMENT_AMOUNT IN NUMBER
                                 P_PAYMENT_AMOUNT IN NUMBER)
RETURN NUMBER IS
l_long_term_liability  NUMBER;
l_payments  NUMBER;
BEGIN
l_payments := '';
IF P_PAYMENT_FREQUENCY = 'A' THEN
l_payments := '1';
ELSIF P_PAYMENT_FREQUENCY = 'M' THEN
l_payments := '12';
ELSIF P_PAYMENT_FREQUENCY = 'Q' THEN
l_payments := '4';
ELSIF P_PAYMENT_FREQUENCY = 'S' THEN
l_payments := '2';
END IF;

begin
IF P_PAYMENTS_REMAINING <= l_payments THEN
l_long_term_liability := '0';
ELSE
l_long_term_liability := (nvl(P_TOTAL_PRINCIPAL_REMAINING,0) + nvl(P_INTEREST_REMAINING,0) - nvl(P_SHORT_TERM_LIABILITY,0));
       if l_long_term_liability < '0' then
            l_long_term_liability := (nvl(P_PAYMENT_AMOUNT,'0') * nvl(P_PAYMENTS_REMAINING,0)) - nvl(P_SHORT_TERM_LIABILITY,'0');
       end if;
END IF;
exception
when others then
l_long_term_liability := null;
end;

RETURN(l_long_term_liability);
END GET_LONG_TERM_LIABILITY;*/

FUNCTION GET_LONG_TERM_LIABILITY(P_SHORT_TERM_LIAB_PAYMENT IN NUMBER,
                                 P_PRINCPL_INTRST_LEASE_TOTAL IN NUMBER)
RETURN NUMBER IS
l_amt NUMBER;
BEGIN
l_amt := '';
l_amt := ROUND(NVL(P_PRINCPL_INTRST_LEASE_TOTAL,'0') - NVL(P_SHORT_TERM_LIAB_PAYMENT,'0'),2);
RETURN(l_amt);
END GET_LONG_TERM_LIABILITY;

/*FUNCTION GET_SHORT_TERM_LIAB_PRINCIPAL(P_PRINCIPAL_PAYMENT IN NUMBER,
                                       P_PRINCIPAL_INTEREST_TOTAL IN NUMBER,
                                       P_SHORT_TERM_LIABILITY IN NUMBER)
RETURN NUMBER IS
l_principal NUMBER;
BEGIN
begin
l_principal := ROUND(((P_PRINCIPAL_PAYMENT/P_PRINCIPAL_INTEREST_TOTAL) * P_SHORT_TERM_LIABILITY),2);
exception
when others then
l_principal := '';
end;
RETURN(l_principal);
END GET_SHORT_TERM_LIAB_PRINCIPAL;*/

FUNCTION GET_SHORT_TERM_LIAB_PAYMENT(P_PAYMENTS_REMAINING IN NUMBER,
                                     P_CONTRACT_ID IN NUMBER,
                                     P_PAYMENT_FREQUENCY IN VARCHAR2,
                                     P_DATE IN DATE)
RETURN NUMBER IS
l_short_term_liability_pymt  NUMBER;
l_payments  NUMBER;
l_mnths_principal_amt NUMBER;
l_mnths_interest_amt NUMBER;
l_mnths_lease_amt NUMBER;
l_total_principal_amt NUMBER;
l_total_interest_amt NUMBER;
l_total_lease_amt NUMBER;
BEGIN

IF P_PAYMENT_FREQUENCY = 'A' THEN
l_payments := '1';
ELSIF P_PAYMENT_FREQUENCY = 'M' THEN
l_payments := '12';
ELSIF P_PAYMENT_FREQUENCY = 'Q' THEN
l_payments := '4';
ELSIF P_PAYMENT_FREQUENCY = 'S' THEN
l_payments := '2';
END IF;

/* Next 12 Months Principal Amount*/
begin
select sum(amount)
into l_mnths_principal_amt
from okl_cs_payment_detail_uv
where khr_id = P_CONTRACT_ID and
sty_id in (select sty_id
from okl_cs_payment_summary_uv
where khr_id = P_CONTRACT_ID and
status_code = 'CURR' and
stream_type = 'PRINCIPAL PAYMENT') and
stream_element_date > NVL(trunc(P_DATE),trunc(sysdate)) and
stream_element_date <= add_months(NVL(trunc(P_DATE),trunc(sysdate)),l_payments);
exception
when others then
l_mnths_principal_amt := null;
end;

/* Next 12 Months Interest Amount*/
begin
select sum(amount)
into l_mnths_interest_amt
from okl_cs_payment_detail_uv
where khr_id = P_CONTRACT_ID and
sty_id in (select sty_id
from okl_cs_payment_summary_uv
where khr_id = P_CONTRACT_ID and
status_code = 'CURR' and
stream_type = 'INTEREST PAYMENT') and
stream_element_date > NVL(trunc(P_DATE),trunc(sysdate)) and
stream_element_date <= add_months(NVL(trunc(P_DATE),trunc(sysdate)),l_payments);
exception
when others then
l_mnths_interest_amt := null;
end;

/* Next 12 Months Lease Maintenance Amount*/
begin
select sum(amount)
into l_mnths_lease_amt
from okl_cs_payment_detail_uv
where khr_id = P_CONTRACT_ID and
sty_id in (select sty_id
from okl_cs_payment_summary_uv
where khr_id = P_CONTRACT_ID and
status_code = 'CURR' and
stream_type = 'LEASE MAINTENANCE') and
stream_element_date > NVL(trunc(P_DATE),trunc(sysdate)) and
stream_element_date <= add_months(NVL(trunc(P_DATE),trunc(sysdate)),l_payments);
exception
when others then
l_mnths_lease_amt := null;
end;


/* Total Principal Amount*/
begin
select sum(amount)
into l_total_principal_amt
from okl_cs_payment_detail_uv
where khr_id = P_CONTRACT_ID and
sty_id in (select sty_id
from okl_cs_payment_summary_uv
where khr_id = P_CONTRACT_ID and
status_code = 'CURR' and
stream_type = 'PRINCIPAL PAYMENT');
exception
when others then
l_total_principal_amt := null;
end;

/* Total Interest Amount*/
begin
select sum(amount)
into l_total_interest_amt
from okl_cs_payment_detail_uv
where khr_id = P_CONTRACT_ID and
sty_id in (select sty_id
from okl_cs_payment_summary_uv
where khr_id = P_CONTRACT_ID and
status_code = 'CURR' and
stream_type = 'INTEREST PAYMENT');
exception
when others then
l_total_interest_amt := null;
end;

/* Total Lease Maintenance Amount*/
begin
select sum(amount)
into l_total_lease_amt
from okl_cs_payment_detail_uv
where khr_id = P_CONTRACT_ID and
sty_id in (select sty_id
from okl_cs_payment_summary_uv
where khr_id = P_CONTRACT_ID and
status_code = 'CURR' and
stream_type = 'LEASE MAINTENANCE');
exception
when others then
l_total_lease_amt := null;
end;

begin
IF P_PAYMENTS_REMAINING >= l_payments THEN
l_short_term_liability_pymt := nvl(l_mnths_principal_amt,'0') + nvl(l_mnths_interest_amt,'0') + nvl(l_mnths_lease_amt,'0');
ELSIF P_PAYMENTS_REMAINING < l_payments THEN
l_short_term_liability_pymt := nvl(l_total_principal_amt,'0') + nvl(l_total_interest_amt,'0') + nvl(l_total_lease_amt,'0');
END IF;

IF P_PAYMENTS_REMAINING = '0' THEN
l_short_term_liability_pymt := '0';
END IF;

exception
when others then
l_short_term_liability_pymt := null;
end;

RETURN(l_short_term_liability_pymt);
END GET_SHORT_TERM_LIAB_PAYMENT;

/*FUNCTION GET_SHORT_TERM_LIAB_INTEREST(P_INTEREST_PAYMENT IN NUMBER,
                                      P_PRINCIPAL_INTEREST_TOTAL IN NUMBER,
                                      P_SHORT_TERM_LIABILITY IN NUMBER)
RETURN NUMBER IS
l_interest NUMBER;
BEGIN
begin
l_interest := ROUND(((P_INTEREST_PAYMENT/P_PRINCIPAL_INTEREST_TOTAL) * P_SHORT_TERM_LIABILITY),2);
exception
when others then
l_interest := '';
end;
RETURN(l_interest);
END GET_SHORT_TERM_LIAB_INTEREST; */

FUNCTION GET_SHORT_TERM_LIAB_INTEREST(P_PAYMENTS_REMAINING IN NUMBER,
                                     P_CONTRACT_ID IN NUMBER,
                                     P_PAYMENT_FREQUENCY IN VARCHAR2,
                                     P_DATE IN DATE)
RETURN NUMBER IS

l_short_term_liab_interest  NUMBER;
l_payments  NUMBER;
l_mnths_interest_amt NUMBER;
l_total_interest_amt NUMBER;
BEGIN

IF P_PAYMENT_FREQUENCY = 'A' THEN
l_payments := '1';
ELSIF P_PAYMENT_FREQUENCY = 'M' THEN
l_payments := '12';
ELSIF P_PAYMENT_FREQUENCY = 'Q' THEN
l_payments := '4';
ELSIF P_PAYMENT_FREQUENCY = 'S' THEN
l_payments := '2';
END IF;

/* Next 12 Months Interest Amount*/
begin
select sum(amount)
into l_mnths_interest_amt
from okl_cs_payment_detail_uv
where khr_id = P_CONTRACT_ID and
sty_id in (select sty_id
from okl_cs_payment_summary_uv
where khr_id = P_CONTRACT_ID and
status_code = 'CURR' and
stream_type = 'INTEREST PAYMENT') and
stream_element_date > NVL(trunc(P_DATE),trunc(sysdate)) and
stream_element_date <= add_months(NVL(trunc(P_DATE),trunc(sysdate)),l_payments);
exception
when others then
l_mnths_interest_amt := null;
end;

/* Total Interest Amount*/
begin
select sum(amount)
into l_total_interest_amt
from okl_cs_payment_detail_uv
where khr_id = P_CONTRACT_ID and
sty_id in (select sty_id
from okl_cs_payment_summary_uv
where khr_id = P_CONTRACT_ID and
status_code = 'CURR' and
stream_type = 'INTEREST PAYMENT');
exception
when others then
l_total_interest_amt := null;
end;

begin
IF P_PAYMENTS_REMAINING >= l_payments THEN
l_short_term_liab_interest := nvl(l_mnths_interest_amt,'0');
ELSIF P_PAYMENTS_REMAINING < l_payments THEN
l_short_term_liab_interest := nvl(l_total_interest_amt,'0');
END IF;

IF P_PAYMENTS_REMAINING = '0' THEN
l_short_term_liab_interest := '0';
END IF;

exception
when others then
l_short_term_liab_interest := null;
end;

RETURN(l_short_term_liab_interest);
END GET_SHORT_TERM_LIAB_INTEREST;

FUNCTION GET_PARAM_P_CONTRACT_ID RETURN VARCHAR2 IS
l_contract_number VARCHAR2(120);
BEGIN
begin
SELECT CONTRACT_NUMBER
INTO l_contract_number
FROM OKC_K_HEADERS_ALL_B
WHERE id = P_CONTRACT_ID;
exception
when others then
l_contract_number := null;
end;
RETURN(l_contract_number);
END GET_PARAM_P_CONTRACT_ID;

FUNCTION GET_PARAM_P_PARTY_ID RETURN VARCHAR2 IS
l_party VARCHAR2(360);
BEGIN
begin
SELECT PARTY_NAME
INTO  l_party
FROM HZ_PARTIES HP,
     HZ_CUST_ACCOUNTS_aLL HCA
WHERE HP.PARTY_ID = HCA.PARTY_ID AND
      HP.PARTY_ID = P_PARTY_ID;
exception
when others then
l_party := null;
end;
RETURN(l_party);
END GET_PARAM_P_PARTY_ID;

FUNCTION GET_PARAM_P_ITEM_ID RETURN VARCHAR2 IS
l_item VARCHAR2(40);
BEGIN
begin
select segment1
into l_item
from mtl_system_items_b
where inventory_item_id = P_ITEM_ID
group by segment1;
exception
when others then
l_item := null;
end;
RETURN(l_item);
END GET_PARAM_P_ITEM_ID;


FUNCTION AFTERPFORM RETURN BOOLEAN IS
begin

 IF P_LEASE_STATUS IS NOT NULL THEN
  	    LEASE_STATUS := 'AND upper(contract_party.contract_status) = upper(:P_LEASE_STATUS) ';
 ELSE
        LEASE_STATUS := 'AND 1 =1';
 END IF;

 IF P_CONTRACT_ID IS NOT NULL THEN
  	    CONTRACT_NUMBER := 'AND contract_party.contract_id = :P_CONTRACT_ID ';
 ELSE
        CONTRACT_NUMBER := 'AND 2 = 2';
 END IF;

 IF P_PARTY_ID IS NOT NULL THEN
  	    CUSTOMER := 'AND contract_party.party_id = :P_PARTY_ID ';
 ELSE
        CUSTOMER := 'AND 3 =3';
 END IF;

 IF P_PRODUCT IS NOT NULL THEN
  	    PRODUCT := 'AND contract_party.product_name = :P_PRODUCT ';
 ELSE
        PRODUCT := 'AND 4 =4';
 END IF;

 IF P_ITEM_ID IS NOT NULL THEN
  	    ITEM_NUMBER := 'AND asset_query.inventory_item_id = :P_ITEM_ID ';
 ELSE
        ITEM_NUMBER := 'AND 5 =5';
 END IF;

return (TRUE);
END AFTERPFORM;
FUNCTION AFTERREPORT RETURN BOOLEAN IS
BEGIN
null;
return (TRUE);
END AFTERREPORT;
END XXOKL_LEASE_CONTRACT_DTL_PKG;
/
