CREATE OR REPLACE PACKAGE BODY xx_cst_recon_util IS

  PROCEDURE nullify_cst_recon_tables(x_return_code OUT VARCHAR2,
                                     x_err_msg     OUT VARCHAR2) IS
    l_org_id NUMBER;
  
  BEGIN
    x_return_code := 0;
  
    l_org_id := fnd_global.org_id;
  
    DELETE FROM cst_reconciliation_build a
     WHERE a.operating_unit_id = l_org_id;
  
    DELETE FROM cst_reconciliation_summary a
     WHERE a.operating_unit_id = l_org_id;
  
    DELETE FROM cst_write_off_details a
     WHERE a.operating_unit_id = l_org_id;
  
    DELETE FROM cst_misc_reconciliation a
     WHERE a.operating_unit_id = l_org_id;
  
    DELETE FROM cst_ap_po_reconciliation a
     WHERE a.operating_unit_id = l_org_id;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      x_return_code := 2;
      x_err_msg     := SQLERRM;
  END nullify_cst_recon_tables;
END xx_cst_recon_util;
/

