/*
** File Name: xx_okl_formulas_pkg.pks
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

CREATE OR REPLACE PACKAGE xx_okl_formulas_pkg
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
      RETURN NUMBER;

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
      RETURN NUMBER;

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
      RETURN NUMBER;

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
      RETURN NUMBER;

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
      RETURN NUMBER;

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
      RETURN NUMBER;

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
      RETURN NUMBER;

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
      RETURN NUMBER;

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
      RETURN NUMBER;
END xx_okl_formulas_pkg;
/
