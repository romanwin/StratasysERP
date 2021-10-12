/*
** File Name: xx_okl_formulas_pkg.pkb
** Created by: Devendra Singh 
** Revision: 1.0
** Creation Date: 13/01/2014
-------------------------------------------------------------------------
** Purpose : Package defined to derive the amount based on custom formula
-------------------------------------------------------------------------
** Version    Date        Name           Desc
-------------------------------------------------------------------------
** 1.0     13/01/2014 Devendra Singh Initial build for CR-1242
** 1.1     13/02/2014 Devendra Singh Added functions for Lease Maintenance CR-1334 
*/

CREATE OR REPLACE PACKAGE BODY xx_okl_formulas_pkg
AS
   /*
   ** Function Name: contract_principal_amt
   ** Created by: Devendra Singh
   ** Revision: 1.0
   ** Creation Date: 13/01/2014
   -------------------------------------------------------------------------
   ** Purpose : Function to return amount for "PRINCIPAL PAYMENT" stream type
   -------------------------------------------------------------------------
   ** Version    Date        Name           Desc
   -------------------------------------------------------------------------
   ** 1.0     13/01/2014 Devendra Singh Initial build
   */
   FUNCTION contract_principal_amt (p_dnz_chr_id IN NUMBER, p_kle_id IN NUMBER)
      RETURN NUMBER
   IS
      l_sum_principal_amt   NUMBER;

      CURSOR sum_prin_amt_csr (p_ctr_id okc_k_headers_b.ID%TYPE)
      IS
         SELECT SUM (ste.amount)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_ctr_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'PRINCIPAL PAYMENT'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND stm.sgn_code = 'MANL'
            AND ste.stm_id = stm.ID
            AND ste.date_billed IS NULL;
   BEGIN
      OPEN sum_prin_amt_csr (p_dnz_chr_id);

      FETCH sum_prin_amt_csr
       INTO l_sum_principal_amt;

      CLOSE sum_prin_amt_csr;

      RETURN NVL (l_sum_principal_amt, 0);
   EXCEPTION
      WHEN OTHERS
      THEN
         --l_return_status := OKL_API.G_RET_STS_UNEXP_ERROR ;
         okl_api.set_message (p_app_name          => okl_api.g_app_name,
                              p_msg_name          => 'OKL_UNEXPECTED_ERROR',
                              p_token1            => 'OKL_SQLCODE',
                              p_token1_value      => SQLCODE,
                              p_token2            => 'OKL_SQLERRM',
                              p_token2_value      => SQLERRM
                             );
         RETURN 0;
   END contract_principal_amt;

   /*
   ** Function Name: contract_interest_amt
   ** Created by: Devendra Singh
   ** Revision: 1.0
   ** Creation Date: 13/01/2014
   -------------------------------------------------------------------------
   ** Purpose : Function to return amount for "INTEREST PAYMENT" stream type
   -------------------------------------------------------------------------
   ** Version    Date        Name           Desc
   -------------------------------------------------------------------------
   ** 1.0     13/01/2014 Devendra Singh Initial build
   */
   FUNCTION contract_interest_amt (p_dnz_chr_id IN NUMBER, p_kle_id IN NUMBER)
      RETURN NUMBER
   IS
      l_sum_interest_amt   NUMBER;

      CURSOR sum_int_amt_csr (p_ctr_id okc_k_headers_b.ID%TYPE)
      IS
         SELECT SUM (ste.amount)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_ctr_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'INTEREST PAYMENT'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND stm.sgn_code = 'MANL'
            AND ste.stm_id = stm.ID
            AND ste.date_billed IS NULL;
   BEGIN
      OPEN sum_int_amt_csr (p_dnz_chr_id);

      FETCH sum_int_amt_csr
       INTO l_sum_interest_amt;

      CLOSE sum_int_amt_csr;

      RETURN NVL (l_sum_interest_amt, 0);
   EXCEPTION
      WHEN OTHERS
      THEN
         --l_return_status := OKL_API.G_RET_STS_UNEXP_ERROR ;
         okl_api.set_message (p_app_name          => okl_api.g_app_name,
                              p_msg_name          => 'OKL_UNEXPECTED_ERROR',
                              p_token1            => 'OKL_SQLCODE',
                              p_token1_value      => SQLCODE,
                              p_token2            => 'OKL_SQLERRM',
                              p_token2_value      => SQLERRM
                             );
         RETURN 0;
   END contract_interest_amt;

   /*
   ** Function Name: contract_prepaid_comm_amt
   ** Created by: Devendra Singh
   ** Revision: 1.0
   ** Creation Date: 13/01/2014
   -------------------------------------------------------------------------
   ** Purpose : Function to return amount for "PREPAID COMMISSION" stream type
   -------------------------------------------------------------------------
   ** Version    Date        Name           Desc
   -------------------------------------------------------------------------
   ** 1.0     13/01/2014 Devendra Singh Initial build
   */
   FUNCTION contract_prepaid_comm_amt (
      p_dnz_chr_id   IN   NUMBER,
      p_kle_id       IN   NUMBER
   )
      RETURN NUMBER
   IS
      l_sum_comm_amt   NUMBER;

      CURSOR sum_comm_amt_csr (p_ctr_id okc_k_headers_b.ID%TYPE)
      IS
         SELECT SUM (ste.amount)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_ctr_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'PREPAID COMMISSION'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND stm.sgn_code = 'MANL'
            AND ste.stm_id = stm.ID
            AND ste.date_billed IS NULL;
   BEGIN
      OPEN sum_comm_amt_csr (p_dnz_chr_id);

      FETCH sum_comm_amt_csr
       INTO l_sum_comm_amt;

      CLOSE sum_comm_amt_csr;

      RETURN NVL (l_sum_comm_amt, 0);
   EXCEPTION
      WHEN OTHERS
      THEN
         --l_return_status := OKL_API.G_RET_STS_UNEXP_ERROR ;
         okl_api.set_message (p_app_name          => okl_api.g_app_name,
                              p_msg_name          => 'OKL_UNEXPECTED_ERROR',
                              p_token1            => 'OKL_SQLCODE',
                              p_token1_value      => SQLCODE,
                              p_token2            => 'OKL_SQLERRM',
                              p_token2_value      => SQLERRM
                             );
         RETURN 0;
   END contract_prepaid_comm_amt;

   /*
   ** Function Name: zero_amt
   ** Created by: Devendra Singh
   ** Revision: 1.0
   ** Creation Date: 13/01/2014
   -------------------------------------------------------------------------
   ** Purpose : Function to return zero amount
   -------------------------------------------------------------------------
   ** Version    Date        Name           Desc
   -------------------------------------------------------------------------
   ** 1.0     13/01/2014 Devendra Singh Initial build
   */
   FUNCTION zero_amt (p_dnz_chr_id IN NUMBER, p_kle_id IN NUMBER)
      RETURN NUMBER
   IS
   BEGIN
      RETURN 0;
   END zero_amt;

   /*
   ** Function Name: contract_principal_amt_rbk
   ** Created by: Devendra Singh
   ** Revision: 1.0
   ** Creation Date: 13/01/2014
   -------------------------------------------------------------------------
   ** Purpose : Function to return amount for "PRINCIPAL PAYMENT" stream type for rebooking transaction
   -------------------------------------------------------------------------
   ** Version    Date        Name           Desc
   -------------------------------------------------------------------------
   ** 1.0     13/01/2014 Devendra Singh Initial build
   */
   FUNCTION contract_principal_amt_rbk (
      p_dnz_chr_id   IN   NUMBER,
      p_kle_id       IN   NUMBER
   )
      RETURN NUMBER
   IS
      l_sum_principal_amt   NUMBER;

      CURSOR sum_prin_amt_csr (p_ctr_id okc_k_headers_b.ID%TYPE)
      IS
         SELECT SUM (ste.amount)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id =
                   (SELECT khr_id_new
                      FROM okl_trx_contracts_all txn
                     WHERE khr_id = p_ctr_id
                       AND tcn_type = 'TRBK'
                       AND tsu_code = 'ENTERED')
            AND stm.sty_id = sty.ID
            AND sty.code = 'PRINCIPAL PAYMENT'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND ste.stm_id = stm.ID
            AND ste.date_billed IS NULL
            AND stm.kle_id IN (
                   SELECT ID
                     FROM okc_k_lines_b
                    WHERE dnz_chr_id = stm.khr_id
                      AND lse_id = 33
                      AND orig_system_id1 IS NULL);
   BEGIN
      OPEN sum_prin_amt_csr (p_dnz_chr_id);

      FETCH sum_prin_amt_csr
       INTO l_sum_principal_amt;

      CLOSE sum_prin_amt_csr;

      RETURN NVL (l_sum_principal_amt, 0);
   EXCEPTION
      WHEN OTHERS
      THEN
         --l_return_status := OKL_API.G_RET_STS_UNEXP_ERROR ;
         okl_api.set_message (p_app_name          => okl_api.g_app_name,
                              p_msg_name          => 'OKL_UNEXPECTED_ERROR',
                              p_token1            => 'OKL_SQLCODE',
                              p_token1_value      => SQLCODE,
                              p_token2            => 'OKL_SQLERRM',
                              p_token2_value      => SQLERRM
                             );
         RETURN 0;
   END contract_principal_amt_rbk;

   /*
   ** Function Name: contract_interest_amt_rbk
   ** Created by: Devendra Singh
   ** Revision: 1.0
   ** Creation Date: 13/01/2014
   -------------------------------------------------------------------------
   ** Purpose : Function to return amount for "INTEREST PAYMENT" stream type for rebooking transaction
   -------------------------------------------------------------------------
   ** Version    Date        Name           Desc
   -------------------------------------------------------------------------
   ** 1.0     13/01/2014 Devendra Singh Initial build
   */
   FUNCTION contract_interest_amt_rbk (
      p_dnz_chr_id   IN   NUMBER,
      p_kle_id       IN   NUMBER
   )
      RETURN NUMBER
   IS
      l_sum_interest_amt   NUMBER;

      CURSOR sum_int_amt_csr (p_ctr_id okc_k_headers_b.ID%TYPE)
      IS
         SELECT SUM (ste.amount)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id =
                   (SELECT khr_id_new
                      FROM okl_trx_contracts_all txn
                     WHERE khr_id = p_ctr_id
                       AND tcn_type = 'TRBK'
                       AND tsu_code = 'ENTERED')
            AND stm.sty_id = sty.ID
            AND sty.code = 'INTEREST PAYMENT'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND ste.stm_id = stm.ID
            AND ste.date_billed IS NULL
            AND stm.kle_id IN (
                   SELECT ID
                     FROM okc_k_lines_b
                    WHERE dnz_chr_id = stm.khr_id
                      AND lse_id = 33
                      AND orig_system_id1 IS NULL);
   BEGIN
      OPEN sum_int_amt_csr (p_dnz_chr_id);

      FETCH sum_int_amt_csr
       INTO l_sum_interest_amt;

      CLOSE sum_int_amt_csr;

      RETURN NVL (l_sum_interest_amt, 0);
   EXCEPTION
      WHEN OTHERS
      THEN
         --l_return_status := OKL_API.G_RET_STS_UNEXP_ERROR ;
         okl_api.set_message (p_app_name          => okl_api.g_app_name,
                              p_msg_name          => 'OKL_UNEXPECTED_ERROR',
                              p_token1            => 'OKL_SQLCODE',
                              p_token1_value      => SQLCODE,
                              p_token2            => 'OKL_SQLERRM',
                              p_token2_value      => SQLERRM
                             );
         RETURN 0;
   END contract_interest_amt_rbk;

   /*
   ** Function Name: contract_prepaid_comm_amt_rbk
   ** Created by: Devendra Singh
   ** Revision: 1.0
   ** Creation Date: 13/01/2014
   -------------------------------------------------------------------------
   ** Purpose : Function to return amount for "PREPAID COMMISSION" stream type for rebooking transaction
   -------------------------------------------------------------------------
   ** Version    Date        Name           Desc
   -------------------------------------------------------------------------
   ** 1.0     13/01/2014 Devendra Singh Initial build
   */
   FUNCTION contract_prepaid_comm_amt_rbk (
      p_dnz_chr_id   IN   NUMBER,
      p_kle_id       IN   NUMBER
   )
      RETURN NUMBER
   IS
      l_sum_comm_amt   NUMBER;

      CURSOR sum_comm_amt_csr (p_ctr_id okc_k_headers_b.ID%TYPE)
      IS
         SELECT SUM (ste.amount)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id =
                   (SELECT khr_id_new
                      FROM okl_trx_contracts_all txn
                     WHERE khr_id = p_ctr_id
                       AND tcn_type = 'TRBK'
                       AND tsu_code = 'ENTERED')
            AND stm.sty_id = sty.ID
            AND sty.code = 'PREPAID COMMISSION'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND ste.stm_id = stm.ID
            AND ste.date_billed IS NULL
            AND stm.kle_id IN (
                   SELECT ID
                     FROM okc_k_lines_v
                    WHERE dnz_chr_id = stm.khr_id
                      AND lse_id = 52
                      AND NAME = 'PREPAID COMMISSION'
                      AND orig_system_id1 IS NULL);
   BEGIN
      OPEN sum_comm_amt_csr (p_dnz_chr_id);

      FETCH sum_comm_amt_csr
       INTO l_sum_comm_amt;

      CLOSE sum_comm_amt_csr;

      RETURN NVL (l_sum_comm_amt, 0);
   EXCEPTION
      WHEN OTHERS
      THEN
         --l_return_status := OKL_API.G_RET_STS_UNEXP_ERROR ;
         okl_api.set_message (p_app_name          => okl_api.g_app_name,
                              p_msg_name          => 'OKL_UNEXPECTED_ERROR',
                              p_token1            => 'OKL_SQLCODE',
                              p_token1_value      => SQLCODE,
                              p_token2            => 'OKL_SQLERRM',
                              p_token2_value      => SQLERRM
                             );
         RETURN 0;
   END contract_prepaid_comm_amt_rbk;

   /*
   ** Function Name: contract_lease_maint_amt
   ** Created by: Devendra Singh
   ** Revision: 1.0
   ** Creation Date: 23/01/2014
   -------------------------------------------------------------------------
   ** Purpose : Function to return amount for "LEASE MAINTENANCE" stream type
   -------------------------------------------------------------------------
   ** Version    Date        Name           Desc
   -------------------------------------------------------------------------
   ** 1.0     23/01/2014 Devendra Singh Initial build
   */
   FUNCTION contract_lease_maint_amt (
      p_dnz_chr_id   IN   NUMBER,
      p_kle_id       IN   NUMBER
   )
      RETURN NUMBER
   IS
      l_sum_maint_amt   NUMBER;

      CURSOR sum_maint_amt_csr (p_ctr_id okc_k_headers_b.ID%TYPE)
      IS
         SELECT SUM (ste.amount)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id = p_ctr_id
            AND stm.sty_id = sty.ID
            AND sty.code = 'LEASE MAINTENANCE'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND stm.sgn_code = 'MANL'
            AND ste.stm_id = stm.ID
            AND ste.date_billed IS NULL;
   BEGIN
      OPEN sum_maint_amt_csr (p_dnz_chr_id);

      FETCH sum_maint_amt_csr
       INTO l_sum_maint_amt;

      CLOSE sum_maint_amt_csr;

      RETURN NVL (l_sum_maint_amt, 0);
   EXCEPTION
      WHEN OTHERS
      THEN
         --l_return_status := OKL_API.G_RET_STS_UNEXP_ERROR ;
         okl_api.set_message (p_app_name          => okl_api.g_app_name,
                              p_msg_name          => 'OKL_UNEXPECTED_ERROR',
                              p_token1            => 'OKL_SQLCODE',
                              p_token1_value      => SQLCODE,
                              p_token2            => 'OKL_SQLERRM',
                              p_token2_value      => SQLERRM
                             );
         RETURN 0;
   END contract_lease_maint_amt;

   /*
   ** Function Name: contract_lease_maint_amt_rbk
   ** Created by: Devendra Singh
   ** Revision: 1.0
   ** Creation Date: 23/01/2014
   -------------------------------------------------------------------------
   ** Purpose : Function to return amount for "LEASE MAINTENANCE" stream type
   -------------------------------------------------------------------------
   ** Version    Date        Name           Desc
   -------------------------------------------------------------------------
   ** 1.0     23/01/2014 Devendra Singh Initial build
   */
   FUNCTION contract_lease_maint_amt_rbk (
      p_dnz_chr_id   IN   NUMBER,
      p_kle_id       IN   NUMBER
   )
      RETURN NUMBER
   IS
      l_sum_maint_amt   NUMBER;

      CURSOR sum_maint_amt_csr (p_ctr_id okc_k_headers_b.ID%TYPE)
      IS
         SELECT SUM (ste.amount)
           FROM okl_streams stm, okl_strm_elements ste, okl_strm_type_b sty
          WHERE stm.khr_id =
                   (SELECT khr_id_new
                      FROM okl_trx_contracts_all txn
                     WHERE khr_id = p_ctr_id
                       AND tcn_type = 'TRBK'
                       AND tsu_code = 'ENTERED')
            AND stm.sty_id = sty.ID
            AND sty.code = 'LEASE MAINTENANCE'
            AND stm.active_yn = 'Y'
            AND stm.say_code = 'CURR'
            AND ste.stm_id = stm.ID
            AND ste.date_billed IS NULL
            AND stm.kle_id IN (
                   SELECT ID
                     FROM okc_k_lines_v
                    WHERE dnz_chr_id = stm.khr_id
                      AND lse_id = 52
                      AND NAME = 'LEASE MAINTENANCE'
                      AND orig_system_id1 IS NULL);
   BEGIN
      OPEN sum_maint_amt_csr (p_dnz_chr_id);

      FETCH sum_maint_amt_csr
       INTO l_sum_maint_amt;

      CLOSE sum_maint_amt_csr;

      RETURN NVL (l_sum_maint_amt, 0);
   EXCEPTION
      WHEN OTHERS
      THEN
         --l_return_status := OKL_API.G_RET_STS_UNEXP_ERROR ;
         okl_api.set_message (p_app_name          => okl_api.g_app_name,
                              p_msg_name          => 'OKL_UNEXPECTED_ERROR',
                              p_token1            => 'OKL_SQLCODE',
                              p_token1_value      => SQLCODE,
                              p_token2            => 'OKL_SQLERRM',
                              p_token2_value      => SQLERRM
                             );
         RETURN 0;
   END contract_lease_maint_amt_rbk;
END xx_okl_formulas_pkg;
/
