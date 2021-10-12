CREATE OR REPLACE PACKAGE BODY xxap_oic_util_pkg AS
  --------------------------------------------------------------------
  --  name:               xxap_oic_util_pkg 
  --  create by:          yuval tal
  --  Revision:           1.0
  --  creation date:      12.7.20
  --------------------------------------------------------------------
  --  purpose:            used by oic services
  ---------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     1.4.20     yuval tal        CHG0048579 - OIC  intergration - plsql modifications

  ---------------------------------------------------------------------------------------------------------------------------------------------

  ---------------------------------------------------------------------------------------
  PROCEDURE message(p_msg IN VARCHAR2) IS
    l_msg VARCHAR(4000);
  BEGIN
  
    l_msg := to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') || p_msg;
  
    IF fnd_global.conc_request_id > 0 THEN
      fnd_file.put_line(fnd_file.log, l_msg);
    ELSE
      dbms_output.put_line(l_msg);
    END IF;
  
  END message;

  --------------------------------------------------------------------
  --  name:               insert_ap_inv_interface 
  --  create by:          yuval tal
  --  Revision:           1.0
  --  creation date:      1.4.20
  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 2.8  30/03/2020  yuval tal   CHG0048579 - OIC  intergration - plsql modifications
  -----------------------------------------------------------------------------------------
  PROCEDURE insert_ap_inv_interface(p_flow_id        NUMBER,
			p_err_code       OUT VARCHAR2,
			p_err_message    OUT VARCHAR2,
			p_ap_invoice_tab OUT xxobjt.xxap_oic_invoice_tab_type) IS
  
    CURSOR c_header(c_request_id NUMBER) IS
      SELECT *
      FROM   xxap_oic_invoices_interface t
      WHERE  request_id = c_request_id;
  
    CURSOR c_lines(c_invoice_id NUMBER) IS
      SELECT *
      FROM   xxap_oic_invoice_lines_int t
      WHERE  invoice_id = c_invoice_id;
    --AP_INVOICES_INTERFACE
  
    l_header              ap_invoices_interface%ROWTYPE;
    l_line                ap_invoice_lines_interface%ROWTYPE;
    l_original_invoice_id NUMBER;
    l_count_s             NUMBER := 0;
    l_count_e             NUMBER := 0;
  BEGIN
    p_err_code       := 'S';
    p_ap_invoice_tab := xxobjt.xxap_oic_invoice_tab_type();
    FOR i IN c_header(p_flow_id)
    LOOP
      BEGIN
      
        p_ap_invoice_tab.extend();
        p_ap_invoice_tab(c_header%ROWCOUNT) := NEW
			           xxobjt.xxap_oic_invoice_type(NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL);
        p_ap_invoice_tab(c_header%ROWCOUNT).invoice_id := l_original_invoice_id;
        p_ap_invoice_tab(c_header%ROWCOUNT).invoice_num := i.invoice_num;
        p_ap_invoice_tab(c_header%ROWCOUNT).vendor_id := i.vendor_id;
        l_original_invoice_id := i.invoice_id;
        i.invoice_id := ap_invoices_interface_s.nextval;
        i.request_id := NULL;
      
        INSERT INTO ap_invoices_interface
        VALUES i;
      
        FOR j IN c_lines(l_original_invoice_id)
        LOOP
        
          j.invoice_id      := i.invoice_id;
          j.invoice_line_id := ap_invoice_lines_interface_s.nextval;
          INSERT INTO ap_invoice_lines_interface
          VALUES j;
        
        END LOOP;
        p_ap_invoice_tab(c_header%ROWCOUNT).is_success := 'True';
      
        COMMIT;
        l_count_s := l_count_s + 1;
      EXCEPTION
        WHEN OTHERS THEN
          l_count_e := l_count_e + 1;
          --  dbms_output.put_line(substr(SQLERRM, 200));
          ROLLBACK;
          p_ap_invoice_tab(c_header%ROWCOUNT).is_success := 'False';
          p_ap_invoice_tab(c_header%ROWCOUNT).is_success := substr(SQLERRM,
					       200);
      END;
    END LOOP;
  
    COMMIT;
    p_err_message := 'Success=' || l_count_s || ' Error=' || l_count_e;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 'E';
      p_err_message := SQLERRM;
  END;

END xxap_oic_util_pkg;
/
