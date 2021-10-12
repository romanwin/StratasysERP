CREATE OR REPLACE PACKAGE BODY xxar_invoice_kr_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               XXAR_INVOICE_KR_PKG
  --  create by:          YUVAL TAL
  --  $Revision:          1.0 $
  --  creation date:      23.6.14
  --  Purpose :          Korean Tax Invoice interface 
  --                       Functional & Design Specification Num:  CHG0032318

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0    9.8.10    YUVAL TAL            initial build
  ----------------------------------------------------------------------- 

  ---------------------------------------------------
  -- AFTER_REPORT
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0    9.8.10    YUVAL TAL          initial build
  ----------------------------------------------------------------------- 

  FUNCTION after_report RETURN BOOLEAN IS
  
    l_request_id NUMBER;
    l_count      NUMBER;
    l_conc_date  DATE;
  BEGIN
    -- check records exists
    SELECT t.actual_start_date
      INTO l_conc_date
      FROM fnd_conc_req_summary_v t
     WHERE t.request_id = fnd_global.conc_request_id;
  
    SELECT COUNT(*)
      INTO l_count
      FROM xxar_invoice_tax_kr_v t
     WHERE t.org_id = 914
       AND t.creation_date < l_conc_date
       AND t.trx_date BETWEEN nvl(fnd_date.canonical_to_date(xxar_invoice_kr_pkg.p_from_trx_date),
                                  t.trx_date - 1) AND
           nvl(fnd_date.canonical_to_date(xxar_invoice_kr_pkg.p_to_trx_date),
               t.trx_date + 1);
  
    -- distribute only if records exists  only if records exists
    IF l_count > 0 THEN
    
      l_request_id := fnd_request.submit_request(application => 'XDO',
                                                 program     => 'XDOBURSTREP',
                                                 argument1   => 'Y',
                                                 argument2   => fnd_global.conc_request_id);
      IF l_request_id IS NOT NULL THEN
      
        UPDATE ra_customer_trx_all t
           SET global_attribute_category = 'JL.KR.ARXTWMAI.TGW_HEADER',
                          t.global_attribute1       = fnd_date.date_to_canonical(l_conc_date)
         WHERE t.org_id = 914
           AND t.global_attribute1 IS NULL
           AND t.creation_date < l_conc_date
           AND t.customer_trx_id IN
               (SELECT customer_trx_id
                  FROM xxar_invoice_tax_kr_v inv
                 WHERE inv.org_id = 914
                   AND t.trx_date BETWEEN
                       nvl(fnd_date.canonical_to_date(xxar_invoice_kr_pkg.p_from_trx_date),
                           t.trx_date - 1) AND
                       nvl(fnd_date.canonical_to_date(xxar_invoice_kr_pkg.p_to_trx_date),
                           t.trx_date + 1));
      
        RETURN TRUE;
      ELSE
        RETURN FALSE;
      END IF;
      --  END IF;
    ELSE
      fnd_file.put_line(fnd_file.log, '----------------------');
      fnd_file.put_line(fnd_file.log, 'No Invoices found');
      fnd_file.put_line(fnd_file.log, '----------------------');
    END IF;
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RETURN FALSE;
    
  END;

END xxar_invoice_kr_pkg;
/
