CREATE OR REPLACE PACKAGE BODY apps.xxokl_lease_contract_rpt_pkg
AS
/************************************************************************
*  Package        :  xxokl_lease_contract_rpt_pkg
*
*  Description    :  Package's before_report procedure is called from 
*                    XXOKL_LEASE_CONTRACT_DTL1's Data Template. 
*
*  Ver   Date           Changed By  Description
*  ----  -----------    ----------  ---------------------------------
*  1.1   19-Jan-2009    D. Singh    Initial create.
*  1.2   22-Oct-2014    M. Mazanet  CHG0034777. Added functionality to 
*                                   get_short_term_liab_interest to get
*                                   monthly liab interest.
*  1.3   02-June-2015   S. Akula    Added Procedures next_due,contract_unbilled_streams to 
*                                   get the Payment due date and Amt as of the Date Given  
************************************************************************/
g_log_message BOOLEAN := TRUE;
g_formula_next_payment_amt CONSTANT okl_formulae_v.name%TYPE := 'OKL_LC_NEXT_PAYMENT_AMOUNT';

-- -------------------------------------------------------------------------------------------
-- Purpose: Log messages
-- ---------------------------------------------------------------------------------------------
-- Ver  Date         Name        Description
-- 1.0  22-Oct-2014  M. Mazanet  CHG0034777. Initial Creation.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE log_message(
      p_msg          VARCHAR2
   ,  p_sub_routine  VARCHAR2 DEFAULT NULL
   ,  p_level        NUMBER   DEFAULT fnd_log.level_statement
   )
   IS
   BEGIN
      IF g_log_message THEN
         fnd_log.string(
            log_level => fnd_log.level_statement
         ,  module    => 'xxobjt.plsql.xxokl_lease_contract_rpt_pkg.'||p_sub_routine
         ,  message   => p_msg);
      END IF;
   END log_message;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    next_due
  Author's Name:   Sandeep Akula
  Date Written:    02-JUNE-2015
  Purpose:         This Procedure calculates the Next Payment due date for the Contract as of the given date
  Program Style:   Procedure Definition
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-JUNE-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034777
---------------------------------------------------------------------------------------------------*/  
PROCEDURE next_due(p_contract_id     IN  NUMBER,
                   p_as_of_Date      IN DATE,
                   o_next_due_amt    OUT NOCOPY NUMBER,
                   o_next_due_date   OUT NOCOPY DATE) IS

CURSOR cr_next_payment_date(c_contract_id IN NUMBER) IS
  SELECT MIN(sel.stream_element_date)
  FROM   okl_strm_elements sel,
         okl_streams stm,
         okl_strm_type_v sty
  WHERE  stm.sty_id = sty.id
  AND    stm.say_code = 'CURR'
  AND    stm.active_yn = 'Y'
  AND    sty.billable_yn = 'Y'
  AND    sty.stream_type_purpose NOT LIKE '%TAX%'   
  AND    sty.stream_type_purpose NOT LIKE '%INTEREST%'  
  AND    stm.purpose_code is NULL
  AND    stm.khr_id = c_contract_id
  AND    sel.stm_id = stm.id
  AND    sel.date_billed is null
  --AND    sel.stream_element_date > sysdate
  AND    TRUNC(sel.stream_element_date) >= TRUNC(p_as_of_Date);

  lx_return_status VARCHAR2(1);
  lx_msg_count     NUMBER;
  lx_msg_data      VARCHAR2(2000);
BEGIN
  OPEN cr_next_payment_date(p_contract_id);
  FETCH cr_next_payment_date INTO o_next_due_date;
  CLOSE cr_next_payment_date;

  Okl_Execute_Formula_Pub.EXECUTE(p_api_version          => 1.0
                                 ,p_init_msg_list        => null
                                 ,x_return_status        => lx_return_status
                                 ,x_msg_count            => lx_msg_count
                                 ,x_msg_data             => lx_msg_data
                                 ,p_formula_name         => g_formula_next_payment_amt
                                 ,p_contract_id          => p_contract_id
                                 ,x_value                => o_next_due_amt
                                 );

EXCEPTION
WHEN OTHERS THEN
IF cr_next_payment_date%ISOPEN  THEN
CLOSE cr_next_payment_date;
END IF;
END next_due;


--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    contract_unbilled_streams
  Author's Name:   Sandeep Akula
  Date Written:    02-JUNE-2015
  Purpose:         Returns the sum of all Unbilled Streams for leases/loans,including taxes, with due date prior to current system date
  Program Style:   Function Definition
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-JUNE-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034777
---------------------------------------------------------------------------------------------------*/  
  FUNCTION contract_unbilled_streams(
    p_as_of_date IN DATE,
    p_contract_id IN NUMBER,
    p_contract_line_id IN NUMBER)
    RETURN NUMBER IS

    CURSOR cr_unbilled_streams(c_contract_id IN NUMBER) IS
    SELECT NVL(sum(sel.amount),0)
    FROM   okl_strm_elements sel,
           okl_streams stm,
           okl_strm_type_b sty
    WHERE  stm.say_code = 'CURR'
    AND    stm.active_yn = 'Y'
    AND    stm.purpose_code is NULL
    AND    stm.khr_id = c_contract_id
    AND    sty.id = stm.sty_id
    AND    sty.billable_yn = 'Y'
    AND    sel.stm_id = stm.id
    AND    date_billed is null
    --AND    stream_element_date <= SYSDATE
    AND    TRUNC(stream_element_date) < TRUNC(p_as_of_date);

    l_unbilled_streams NUMBER;

  BEGIN
    OPEN cr_unbilled_streams (p_contract_id);
    FETCH cr_unbilled_streams INTO l_unbilled_streams;
    CLOSE cr_unbilled_streams;

    RETURN l_unbilled_streams;
EXCEPTION
WHEN OTHERS THEN
IF cr_unbilled_streams%ISOPEN THEN
CLOSE cr_unbilled_streams;
END IF;
RETURN NULL;
END contract_unbilled_streams;

-- -------------------------------------------------------------------------------------------
-- Purpose: Gets remaining interest income
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  01/19/2009  D. Singh    Initial Creation
-- ---------------------------------------------------------------------------------------------
   FUNCTION get_interest_income_remaining (
      p_contract_id   IN   NUMBER,
      p_date          IN   DATE
   )
      RETURN NUMBER
   IS
      CURSOR get_interest_income_rem_csr
      IS
         SELECT NVL (SUM (ste.amount), 0)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_contract_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'INTEREST INCOME'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND ste.stm_id = stm.ID
            AND ste.stream_element_date >= p_date+1;

      l_amt   NUMBER;
   BEGIN
      OPEN get_interest_income_rem_csr;

      FETCH get_interest_income_rem_csr
       INTO l_amt;

      CLOSE get_interest_income_rem_csr;

      RETURN NVL (l_amt, 0);
   END get_interest_income_remaining;

   FUNCTION get_lease_maint_remaining (p_contract_id IN NUMBER, p_date IN DATE)
      RETURN NUMBER
   IS
      CURSOR get_lease_maint_rem_csr
      IS
         SELECT NVL (SUM (ste.amount), 0)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_contract_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'LEASE MAINTENANCE'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND ste.stm_id = stm.ID
            AND ste.stream_element_date >= p_date;

      l_amt   NUMBER;
   BEGIN
      OPEN get_lease_maint_rem_csr;

      FETCH get_lease_maint_rem_csr
       INTO l_amt;

      CLOSE get_lease_maint_rem_csr;

      RETURN NVL (l_amt, 0);
   END get_lease_maint_remaining;

-- -------------------------------------------------------------------------------------------
-- Purpose: Gets remaining principal
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  01/19/2009  D. Singh    Initial Creation
-- ---------------------------------------------------------------------------------------------
   FUNCTION get_principal_remaining (p_contract_id IN NUMBER, p_date IN DATE)
      RETURN NUMBER
   IS
      CURSOR get_prin_rem_csr
      IS
         SELECT NVL (SUM (ste.amount), 0)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_contract_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'PRINCIPAL PAYMENT'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND ste.stm_id = stm.ID
            AND ste.stream_element_date >= p_date;

      l_return_status         VARCHAR2 (100);
      l_principal_remaining   NUMBER;
   BEGIN
      OPEN get_prin_rem_csr;

      FETCH get_prin_rem_csr
       INTO l_principal_remaining;

      CLOSE get_prin_rem_csr;

      RETURN NVL (l_principal_remaining, 0);
   END get_principal_remaining;

-- -------------------------------------------------------------------------------------------
-- Purpose: Gets remaining interest
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  01/19/2009  D. Singh    Initial Creation
-- ---------------------------------------------------------------------------------------------
   FUNCTION get_interest_remaining (p_contract_id IN NUMBER, p_date IN DATE)
      RETURN NUMBER
   IS
      CURSOR get_int_rem_csr
      IS
         SELECT NVL (SUM (ste.amount), 0)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_contract_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'INTEREST PAYMENT'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND ste.stm_id = stm.ID
            AND ste.stream_element_date >= p_date;

      l_amt   NUMBER;
   BEGIN
      OPEN get_int_rem_csr;

      FETCH get_int_rem_csr
       INTO l_amt;

      CLOSE get_int_rem_csr;

      RETURN NVL (l_amt, 0);
   END get_interest_remaining;

   FUNCTION get_short_term_liab_payment (
      p_contract_id   IN   NUMBER,
      p_date          IN   DATE
   )
      RETURN NUMBER
   IS
      CURSOR get_short_term_pmt_csr (p_start_date DATE, p_end_date DATE)
      IS
         SELECT NVL (SUM (ste.amount), 0)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_contract_id
            AND stm.sty_id = sty.ID
            AND sty.code IN
                   ('INTEREST PAYMENT',
                    'PRINCIPAL PAYMENT',
                    'LEASE MAINTENANCE'
                   )
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND ste.stm_id = stm.ID
            AND ste.stream_element_date BETWEEN p_start_date AND p_end_date;

      ln_short_term_liab_pmt   NUMBER;
      ld_start_date            DATE;
      ld_end_date              DATE;
   BEGIN
      ld_start_date := p_date;
      ld_end_date := ADD_MONTHS (ld_start_date, 12);

      OPEN get_short_term_pmt_csr (ld_start_date, ld_end_date);

      FETCH get_short_term_pmt_csr
       INTO ln_short_term_liab_pmt;

      CLOSE get_short_term_pmt_csr;

      RETURN NVL (ln_short_term_liab_pmt, 0);
   END get_short_term_liab_payment;

-- -------------------------------------------------------------------------------------------
-- Purpose: Gets short term liability interest for month of report date
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  01/19/2009  D. Singh    Initial Creation
-- 1.1  10/17/2014  MMAZANET    CHG0034777.  Added functionality to get the short term interest
--                              for one month as well as for the whole year.
-- ---------------------------------------------------------------------------------------------
   FUNCTION get_short_term_liab_interest (
      p_contract_id     IN   NUMBER
   ,  p_date            IN   DATE
   ,  p_one_month_flag  IN   VARCHAR2  DEFAULT 'N'
   )
      RETURN NUMBER
   IS
      CURSOR get_short_term_int_csr (p_start_date DATE, p_end_date DATE)
      IS
         SELECT NVL (SUM (ste.amount), 0)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_contract_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'INTEREST INCOME'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND ste.stm_id = stm.ID
            AND ste.stream_element_date BETWEEN p_start_date AND p_end_date;

      l_short_term_liab_interest   NUMBER;
      l_payments                   NUMBER;
      l_mnths_interest_amt         NUMBER;
      l_total_interest_amt         NUMBER;
      ld_start_date                DATE;
      ld_end_date                  DATE;
   BEGIN
      IF p_one_month_flag = 'N' THEN
         ld_start_date := p_date + 1;
         ld_end_date := ADD_MONTHS (ld_start_date, 12);
      ELSE
         ld_start_date := LAST_DAY(ADD_MONTHS(SYSDATE,-1))+1;
         ld_end_date   := LAST_DAY(SYSDATE);      
      END IF;

      OPEN get_short_term_int_csr (ld_start_date, ld_end_date);

      FETCH get_short_term_int_csr
       INTO l_short_term_liab_interest;

      CLOSE get_short_term_int_csr;

      RETURN NVL (l_short_term_liab_interest, 0);
   END get_short_term_liab_interest;


-- -------------------------------------------------------------------------------------------
-- Purpose: Routine called from before_report procedure to populate the xxokl_lease_header_gtt 
--          global temparary table used by the XXOKL_LEASE_CONTRACT_DTL report's data source
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  01/19/2009  D. Singh    Initial Creation
-- 1.1  10/17/2014  MMAZANET    CHG0034777.  Added call to get_short_term_liab_interest to get
--                              monthly liab interest.
-- ---------------------------------------------------------------------------------------------
   PROCEDURE populate_rpt_data (p_as_of_date IN DATE)
   IS
      CURSOR get_lease_data
      IS
         SELECT 
            CHR.ID                     contract_id                 
         ,  contract_number            contract_number             
         ,  chrt.description           contract_description        
         ,  hou.NAME                   operating_unit              
         ,  hzp.party_name             customer_name               
         ,  hca.account_number         customer_account_number     
         ,  ocs.description            customer_bill_to_address    
         ,  CHR.sts_code               contract_status             
         ,  CHR.start_date             contract_start_date         
         ,  CHR.end_date               contract_end_date           
         ,  prd.NAME                   product              
         ,  scs_code                   scs_code                    
         ,  khr.term_duration          term                        
         ,  clev.NAME                  asset_number                
         ,  msi.segment1               item_number                 
         ,  msi.description            item_description            
         ,  cii.serial_number          serial_number               
         ,  NULL                       stream_types                
         ,  kle.oec                    asset_cost_total            
         ,  NULL                       principal_total             
         ,  NULL                       lease_maintenance_total     
         ,  NULL                       interest_total              
         ,  NULL                       principal_interest_total    
         ,  NULL                       principal_remaining         
         ,  NULL                       lease_maintenance_remaining 
         ,  NULL                       interest_remaining          
         ,  NULL                       prin_int_main_remain_total  
         ,  NULL                       down_payment                
         ,  NULL                       payment_amount              
         ,  NULL                       current_invoice_total       
         ,  NULL                       current_applied_amount      
         ,  NULL                       current_amount_remianing    
         ,  NULL                       current_outstanding         
         ,  NULL                       current_amount_past_due     
         ,  NULL                       current_unbled_pst_due_total
         ,  NULL                       last_payment_date           
         ,  NULL                       last_payment_amount         
         ,  NULL                       next_payment_due_date       
         ,  NULL                       next_payment_due_amount     
         ,  NULL                       no_payments_remaining       
         ,  NULL                       payment_frequency           
         ,  NULL                       long_term_liability         
         ,  NULL                       short_term_liab_total       
         ,  NULL                       short_term_liab_interest    
         ,  NULL                       short_term_liab_interest_mo
         ,  khr.attribute2             sales_order_number          
         ,  khr.attribute1             pl_segment_maint            
         ,  khr.attribute3             pl_segment_ar_sales         
         ,  khr.attribute4             busines_unit                
         ,  NULL                       interest_income_rem         
         ,  NULL                       long_term_interest_income   
         FROM 
            okc_k_headers_all_b              CHR
         ,  okc_k_headers_tl                 chrt
         ,  okl_k_headers                    khr
         ,  hz_cust_accounts_all             hca
         ,  hz_cust_site_uses_all            hcu
         ,  hr_operating_units               hou
         ,  hz_parties                       hzp
         ,  okx_cust_sites_v                 ocs
         ,  okl_products                     prd
         ,  okc_k_lines_b                    cle
         ,  okc_k_items                      oki
         ,  mtl_system_items                 msi
         ,  okc_k_lines_v                    clev
         ,  okc_k_lines_b                    cle_ib
         ,  okc_k_items                      oki_ib
         ,  csi_item_instances               cii
         ,  okl_k_lines                      kle
         ,  okl_pdt_pqy_vals_uv              pqv
         WHERE scs_code             IN ('LEASE', 'LOAN')
         AND   CHR.sts_code         IN ('BOOKED', 'EVERGREEN', 'TERMINATED', 'EXPIRED')
         AND   CHR.ID               = khr.ID
         AND   chrt.LANGUAGE        = 'US'
         AND   chrt.ID              = CHR.ID
         AND   prd.ID               = khr.pdt_id
         AND   pqv.pdt_id           = prd.ID
         AND   pqv.NAME             = 'LEASE'
         AND   clev.dnz_chr_id      = CHR.ID
         AND   clev.lse_id          = 33
         AND   clev.ID              = kle.ID
         AND   CHR.cust_acct_id     = hca.cust_account_id
         AND   hzp.party_id         = hca.party_id
         AND   hou.organization_id  = CHR.authoring_org_id
         AND   hcu.site_use_id      = CHR.bill_to_site_use_id
         AND   ocs.id1              = hcu.cust_acct_site_id
         AND   cle.dnz_chr_id       = CHR.ID
         AND   cle.ID               = oki.cle_id
         AND   oki.dnz_chr_id       = cle.dnz_chr_id
         AND   oki.jtot_object1_code 
                                    = 'OKX_SYSITEM'
         AND   msi.organization_id  = oki.object1_id2
         AND   msi.inventory_item_id 
                                    = oki.object1_id1
         AND   ocs.id2              = '#'
         AND   ocs.cust_account_id  = CHR.cust_acct_id
         AND   cle_ib.dnz_chr_id    = CHR.ID
         AND   cle_ib.ID            = oki_ib.cle_id
         AND   oki_ib.dnz_chr_id    = cle_ib.dnz_chr_id
         AND   oki_ib.jtot_object1_code 
                                    = 'OKX_IB_ITEM'
         AND   cii.instance_id      = oki_ib.object1_id1
         AND   oki_ib.object1_id2   = '#'
         AND   CHR.sts_code         = NVL (p_lease_status, CHR.sts_code)
         AND   CHR.ID               = NVL (p_contract_id, CHR.ID)
         AND   hzp.party_id         = NVL (p_party_id, hzp.party_id)
         AND   prd.NAME             = NVL (p_product, prd.NAME)
         AND   msi.inventory_item_id 
                                    = NVL (p_item_id, msi.inventory_item_id)
         AND   pqv.VALUE            = p_lease_type;

      CURSOR get_strm_types (p_khr_id NUMBER)
      IS
         SELECT code
           FROM okl_strm_type_b sty
          WHERE EXISTS (SELECT 1
                          FROM okl_streams stm
                         WHERE stm.khr_id = p_khr_id AND stm.sty_id = sty.ID)
            AND billable_yn = 'Y';

--Princiap Total
      CURSOR get_prin_total (p_khr_id NUMBER)
      IS
         SELECT NVL (SUM (ste.amount), 0)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_khr_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'PRINCIPAL PAYMENT'
            AND ste.stm_id = stm.ID
            AND stm.ID IN (
                   SELECT DISTINCT FIRST_VALUE (ID) OVER (PARTITION BY stm1.khr_id, stm1.kle_id, stm1.sty_id ORDER BY ID DESC)
                              FROM okl_streams stm1
                             WHERE stm1.khr_id = stm.khr_id
                               AND stm1.kle_id = stm.kle_id
                               AND stm1.sty_id = stm.sty_id);

--Interest Total
      CURSOR get_int_total (p_khr_id NUMBER)
      IS
         SELECT NVL (SUM (ste.amount), 0)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_khr_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'INTEREST PAYMENT'
            AND ste.stm_id = stm.ID
            AND stm.ID IN (
                   SELECT DISTINCT FIRST_VALUE (ID) OVER (PARTITION BY stm1.khr_id, stm1.kle_id, stm1.sty_id ORDER BY ID DESC)
                              FROM okl_streams stm1
                             WHERE stm1.khr_id = stm.khr_id
                               AND stm1.kle_id = stm.kle_id
                               AND stm1.sty_id = stm.sty_id);

--Lease maintenane Total
      CURSOR get_maint_total (p_khr_id NUMBER)
      IS
         SELECT NVL (SUM (ste.amount), 0)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_khr_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'LEASE MAINTENANCE'
            AND ste.stm_id = stm.ID
            AND stm.ID IN (
                   SELECT DISTINCT FIRST_VALUE (ID) OVER (PARTITION BY stm1.khr_id, stm1.kle_id, stm1.sty_id ORDER BY ID DESC)
                              FROM okl_streams stm1
                             WHERE stm1.khr_id = stm.khr_id
                               AND stm1.kle_id = stm.kle_id
                               AND stm1.sty_id = stm.sty_id);

--Down Payment
      CURSOR get_down_payment (p_khr_id NUMBER)
      IS
         SELECT NVL (SUM (ste.amount), 0)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_khr_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'DOWN PAYMENT'
            AND ste.stm_id = stm.ID
            AND stm.ID IN (
                   SELECT DISTINCT FIRST_VALUE (ID) OVER (PARTITION BY stm1.khr_id, stm1.kle_id, stm1.sty_id ORDER BY ID DESC)
                              FROM okl_streams stm1
                             WHERE stm1.khr_id = stm.khr_id
                               AND stm1.kle_id = stm.kle_id
                               AND stm1.sty_id = stm.sty_id);

      CURSOR get_pay_freq (p_khr_id NUMBER)
      IS
         SELECT DECODE (orbl.object1_id1,
                        'M', 'Monthly',
                        'Q', 'Quarterly',
                        'S', 'Semi Annual',
                        'A', 'Annual'
                       ) frequency,
                orbl.rule_information6 payment
           FROM okc_rules_b orb,
                okc_rules_b orbl,
                okc_rule_groups_b rgp,
                okl_strm_type_b sty
          WHERE orb.rgp_id = rgp.ID
            AND sty.ID = orb.object1_id1
            AND sty.code = 'RENT'
            AND rgp.rgd_code = 'LALEVL'
            AND orb.rule_information_category = 'LASLH'
            AND orb.jtot_object1_code = 'OKL_STRMTYP'
            AND orbl.object2_id1 = orb.ID
            AND orbl.rule_information_category = 'LASLL'
            AND orbl.jtot_object2_code = 'OKL_STRMHDR'
            AND orbl.jtot_object1_code = 'OKL_TUOM'
            AND rgp.dnz_chr_id = p_khr_id;

      CURSOR get_khr_amounts (p_contract_number VARCHAR2)
      IS
         SELECT   NVL (SUM (amount_applied), 0)
                + NVL (SUM (amount_credited), 0) amount_paid,
                NVL (SUM (amount_due_original), 0) orig_amount,
                NVL (SUM (amount_due_remaining), 0) amount_rem
           FROM ra_customer_trx_all rct, ar_payment_schedules_all aps
          WHERE rct.customer_trx_id = aps.customer_trx_id
            AND rct.interface_header_attribute6 = p_contract_number;

      CURSOR get_past_due (p_contract_number VARCHAR2)
      IS
         SELECT NVL (SUM (amount_due_remaining), 0) amount_rem
           FROM ra_customer_trx_all rct, ar_payment_schedules_all aps
          WHERE rct.customer_trx_id = aps.customer_trx_id
            AND rct.interface_header_attribute6 = p_contract_number
            AND aps.due_date <= SYSDATE;

      CURSOR get_last_due (p_contract_number VARCHAR2)
      IS
         SELECT   ara.amount_applied, receipt_date
             FROM ar_cash_receipts_all arc,
                  ar_receivable_applications_all ara,
                  ra_customer_trx_all rct
            WHERE rct.customer_trx_id = ara.applied_customer_trx_id
              AND ara.cash_receipt_id = arc.cash_receipt_id
              AND ara.display = 'Y'
              AND ara.application_type = 'CASH'
              AND rct.interface_header_attribute6 = p_contract_number
         ORDER BY receipt_date DESC;

      CURSOR get_unbilled_payment (p_khr_id NUMBER)
      IS
         SELECT COUNT (1) payment_remaining
           FROM okl_strm_type_v styt, okl_strm_elements sele, okl_streams str
          WHERE sele.stm_id = str.ID
            AND str.sty_id = styt.ID
            AND str.say_code = 'CURR'
            AND str.active_yn = 'Y'
            AND str.purpose_code IS NULL
            AND sele.date_billed IS NULL
            AND styt.billable_yn = 'Y'
            AND styt.stream_type_purpose IN
                                ('RENT', 'PRINCIPAL_PAYMENT', 'LOAN_PAYMENT')
            AND str.khr_id = p_khr_id;

      CURSOR get_current_rem (p_khr_id NUMBER)
      IS
         SELECT COUNT (1) current_remaining
           FROM okl_strm_type_v styt, okl_strm_elements sele, okl_streams str
          WHERE sele.stm_id = str.ID
            AND str.sty_id = styt.ID
            AND str.say_code = 'CURR'
            AND str.active_yn = 'Y'
            AND str.purpose_code IS NULL
            AND sele.date_billed IS NULL
            AND styt.billable_yn = 'Y'
            AND str.khr_id = p_khr_id;

      TYPE tb_lease_rpt IS TABLE OF xxobjt.xxokl_lease_header_gtt%ROWTYPE
         INDEX BY BINARY_INTEGER;

      ltb_rpt_type   tb_lease_rpt;
   BEGIN
      OPEN get_lease_data;

      FETCH get_lease_data
      BULK COLLECT INTO ltb_rpt_type;

      CLOSE get_lease_data;

      FOR i IN 1 .. ltb_rpt_type.COUNT
      LOOP
         OPEN get_prin_total (ltb_rpt_type (i).contract_id);

         FETCH get_prin_total
          INTO ltb_rpt_type (i).principal_total;

         CLOSE get_prin_total;

         OPEN get_int_total (ltb_rpt_type (i).contract_id);

         FETCH get_int_total
          INTO ltb_rpt_type (i).interest_total;

         CLOSE get_int_total;

         OPEN get_maint_total (ltb_rpt_type (i).contract_id);

         FETCH get_maint_total
          INTO ltb_rpt_type (i).lease_maintenance_total;

         CLOSE get_maint_total;

         OPEN get_pay_freq (ltb_rpt_type (i).contract_id);

         FETCH get_pay_freq
          INTO ltb_rpt_type (i).payment_frequency,
               ltb_rpt_type (i).payment_amount;

         CLOSE get_pay_freq;

         FOR j IN get_strm_types (ltb_rpt_type (i).contract_id)
         LOOP
            ltb_rpt_type (i).stream_types :=
                               ltb_rpt_type (i).stream_types || j.code || ',';
         END LOOP;

         OPEN get_down_payment (ltb_rpt_type (i).contract_id);

         FETCH get_down_payment
          INTO ltb_rpt_type (i).down_payment;

         CLOSE get_down_payment;

         ltb_rpt_type (i).principal_interest_total :=
              ltb_rpt_type (i).principal_total
            + ltb_rpt_type (i).interest_total
            + ltb_rpt_type (i).lease_maintenance_total;
         ltb_rpt_type (i).principal_remaining :=
            get_principal_remaining (ltb_rpt_type (i).contract_id,
                                     p_as_of_date
                                    );
         ltb_rpt_type (i).lease_maintenance_remaining :=
            get_lease_maint_remaining (ltb_rpt_type (i).contract_id,
                                       p_as_of_date
                                      );
         ltb_rpt_type (i).interest_remaining :=
            get_interest_remaining (ltb_rpt_type (i).contract_id,
                                    p_as_of_date);
         ltb_rpt_type (i).prin_int_main_remain_total :=
              ltb_rpt_type (i).principal_remaining
            + ltb_rpt_type (i).lease_maintenance_remaining
            + ltb_rpt_type (i).interest_remaining;
         ltb_rpt_type (i).short_term_liab_total :=
            get_short_term_liab_payment (ltb_rpt_type (i).contract_id,
                                         p_as_of_date
                                        );
         ltb_rpt_type (i).long_term_liability :=
              ltb_rpt_type (i).prin_int_main_remain_total
            - ltb_rpt_type (i).short_term_liab_total;

         IF ltb_rpt_type (i).long_term_liability < 0
         THEN
            ltb_rpt_type (i).long_term_liability := 0;
         END IF;

         ltb_rpt_type (i).short_term_liab_interest :=
            get_short_term_liab_interest (ltb_rpt_type (i).contract_id,
                                          p_as_of_date
                                         );

         -- Added for CHG0034777
         ltb_rpt_type (i).short_term_liab_interest_mo :=
            get_short_term_liab_interest (
               ltb_rpt_type (i).contract_id
            ,  p_as_of_date
            ,  'Y'
            );

         ltb_rpt_type (i).interest_income_rem :=
            get_interest_income_remaining (ltb_rpt_type (i).contract_id,
                                           p_as_of_date
                                          );
         ltb_rpt_type (i).long_term_interest_income :=
              ltb_rpt_type (i).interest_income_rem
            - ltb_rpt_type (i).short_term_liab_interest;

         OPEN get_khr_amounts (ltb_rpt_type (i).contract_number);

         FETCH get_khr_amounts
          INTO ltb_rpt_type (i).current_applied_amount,
               ltb_rpt_type (i).current_invoice_total,
               ltb_rpt_type (i).current_outstanding;

         CLOSE get_khr_amounts;

         OPEN get_past_due (ltb_rpt_type (i).contract_number);

         FETCH get_past_due
          INTO ltb_rpt_type (i).current_amount_past_due;

         CLOSE get_past_due;

         /* ltb_rpt_type (i).current_amount_past_due :=
             okl_seeded_functions_pvt.contract_unpaid_invoices
                                                  (ltb_rpt_type (i).contract_id,
                                                   ''
                                                  ); */
        /* ltb_rpt_type (i).current_unbled_pst_due_total :=
            okl_seeded_functions_pvt.contract_unbilled_streams
                                                 (ltb_rpt_type (i).contract_id,
                                                  ''
                                                 );*/
           -- Added 02-JUNE-2015 SAkula CHG0034777                                       
           ltb_rpt_type (i).current_unbled_pst_due_total :=
            contract_unbilled_streams(p_as_of_date,
                                      ltb_rpt_type (i).contract_id,
                                      '');

         OPEN get_last_due (ltb_rpt_type (i).contract_number);

         FETCH get_last_due
          INTO ltb_rpt_type (i).last_payment_amount,
               ltb_rpt_type (i).last_payment_date;

         CLOSE get_last_due;

         /*okl_cs_lc_contract_pvt.next_due
                   (p_contract_id        => ltb_rpt_type (i).contract_id,
                    o_next_due_amt       => ltb_rpt_type (i).next_payment_due_amount,
                    o_next_due_date      => ltb_rpt_type (i).next_payment_due_date
                   );*/
               
              -- Added 02-JUNE-2015 SAkula CHG0034777     
             next_due(p_contract_id        => ltb_rpt_type (i).contract_id,
                      p_as_of_Date         => p_as_of_Date,
                      o_next_due_amt       => ltb_rpt_type (i).next_payment_due_amount,
                      o_next_due_date      => ltb_rpt_type (i).next_payment_due_date
                   );

         OPEN get_unbilled_payment (ltb_rpt_type (i).contract_id);

         FETCH get_unbilled_payment
          INTO ltb_rpt_type (i).no_payments_remaining;

         CLOSE get_unbilled_payment;

         OPEN get_current_rem (ltb_rpt_type (i).contract_id);

         FETCH get_current_rem
          INTO ltb_rpt_type (i).current_amount_remianing;

         CLOSE get_current_rem;

         IF p_contract_id IS NOT NULL
         THEN
            xxokl_lease_contract_rpt_pkg.contract_number :=
                                             ltb_rpt_type (i).contract_number;
         END IF;

         IF p_party_id IS NOT NULL
         THEN
            xxokl_lease_contract_rpt_pkg.customer :=
                                               ltb_rpt_type (i).customer_name;
         END IF;

         IF p_item_id IS NOT NULL
         THEN
            xxokl_lease_contract_rpt_pkg.item_number :=
                                                 ltb_rpt_type (i).item_number;
         END IF;
      END LOOP;

      FORALL i IN ltb_rpt_type.FIRST .. ltb_rpt_type.LAST
         INSERT INTO xxobjt.xxokl_lease_header_gtt
              VALUES ltb_rpt_type (i);
   EXCEPTION
      WHEN OTHERS
      THEN
         RAISE;
   END populate_rpt_data;

-- -------------------------------------------------------------------------------------------
-- Purpose: This procedure is called from the data definition file and it accepts all the input 
--          parameters from the concurrent program
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  01/19/2009  D. Singh    Initial Creation
-- ---------------------------------------------------------------------------------------------
   FUNCTION beforereport
      RETURN BOOLEAN
   IS
      ld_as_of_date   DATE;
      l_sub_routine   VARCHAR2(30) := 'beforereport';
   BEGIN
      mo_global.init ('OKL');
      mo_global.set_policy_context ('M', p_org_id);
      ld_as_of_date := fnd_date.canonical_to_date (p_as_of_date);
      
      log_message('ld_as_of_date: '||ld_as_of_date,l_sub_routine);
      
      populate_rpt_data (TRUNC (ld_as_of_date));
      RETURN TRUE;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, ' Exception raised' || SQLERRM);
         RETURN FALSE;
   END beforereport;
END xxokl_lease_contract_rpt_pkg;
/

SHOW ERRORS