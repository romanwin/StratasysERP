CREATE OR REPLACE PACKAGE BODY xxconv_withholding_tax_pkg IS

   PROCEDURE insert_new_certificate(p_start_date_f       IN DATE,
                                    p_end_date_f         IN DATE,
                                    p_tax_name           IN VARCHAR2,
                                    p_tax_rate           IN NUMBER,
                                    p_user               IN NUMBER,
                                    p_vendor_id          IN NUMBER,
                                    p_vendor_number      IN NUMBER,
                                    p_vendor_name        IN VARCHAR2,
                                    p_tax_id             IN NUMBER,
                                    p_org_id             IN NUMBER,
                                    p_priority           IN NUMBER,
                                    p_certificate_number IN NUMBER) IS
      ln_tax_rate    NUMBER;
      ld_open_new    DATE;
      ld_close_exist DATE;
      lc_flag_update VARCHAR2(3);
      ln_level_name  NUMBER;
      lc_comments    VARCHAR2(50);
   
   BEGIN
      BEGIN
         INSERT INTO ap_awt_tax_rates_all
            (tax_rate_id,
             tax_name,
             tax_rate,
             rate_type,
             start_date,
             end_date,
             start_amount,
             end_amount,
             last_update_date,
             last_updated_by,
             last_update_login,
             creation_date,
             created_by,
             vendor_id,
             vendor_site_id,
             invoice_num,
             certificate_number,
             certificate_type,
             comments,
             priority,
             org_id)
         VALUES
            (ap_awt_tax_rates_s.NEXTVAL,
             p_tax_name,
             p_tax_rate,
             'CERTIFICATE',
             p_start_date_f + 1,
             p_end_date_f,
             NULL,
             NULL,
             SYSDATE,
             p_user,
             1,
             SYSDATE,
             p_user,
             p_vendor_id,
             p_vendor_number,
             NULL,
             p_certificate_number,
             'STANDARD',
             NULL,
             p_priority,
             p_org_id);
      
      EXCEPTION
         WHEN OTHERS THEN
            dbms_output.put_line('Error: ' || p_vendor_number);
      END;
   END insert_new_certificate;

   PROCEDURE main IS
   
      CURSOR cr_get_withtax IS
         SELECT *
           FROM xxobjt_conv_withholding a
          WHERE trans_to_int_code = 'N'
            FOR UPDATE;
   
      v_org_id         NUMBER;
      v_vendor_id      NUMBER;
      v_tax_id         NUMBER;
      v_vendor_site_id NUMBER;
      v_vendor_name    VARCHAR2(240);
      v_vendor_code    VARCHAR2(30);
      v_tax_name       VARCHAR2(30);
      v_status         VARCHAR2(1);
      v_error          VARCHAR2(1000);
   
      l_user_id NUMBER;
   
   BEGIN
   
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
   
      FOR i IN cr_get_withtax LOOP
      
         v_status := 'S';
         v_error  := NULL;
      
         v_org_id         := NULL;
         v_vendor_id      := NULL;
         v_tax_id         := NULL;
         v_vendor_site_id := NULL;
         v_vendor_name    := NULL;
         v_vendor_code    := NULL;
         v_tax_name       := NULL;
      
         BEGIN
            SELECT organization_id
              INTO v_org_id
              FROM hr_all_organization_units
             WHERE NAME = i.org_name;
         EXCEPTION
            WHEN OTHERS THEN
               v_org_id := NULL;
               v_status := 'E';
               v_error  := 'Org Id Does Not Exist';
         END;
      
         BEGIN
            SELECT ap.vendor_id,
                   ap.vendor_name,
                   aps.vendor_site_id,
                   ap.segment1
              INTO v_vendor_id,
                   v_vendor_name,
                   v_vendor_site_id,
                   v_vendor_code
              FROM ap_supplier_sites_all aps, ap_suppliers ap
             WHERE substr(vendor_site_code, 1, 15) =
                   substr(i.supplier_site_code, 1, 15) AND
                   ap.vendor_name = i.supplier_name AND
                   aps.vendor_id = ap.vendor_id;
         EXCEPTION
            WHEN no_data_found THEN
            
               BEGIN
               
                  SELECT ap.vendor_id,
                         ap.vendor_name,
                         aps.vendor_site_id,
                         ap.segment1
                    INTO v_vendor_id,
                         v_vendor_name,
                         v_vendor_site_id,
                         v_vendor_code
                    FROM ap_supplier_sites_all aps, ap_suppliers ap
                   WHERE ap.vendor_name = i.supplier_name AND
                         aps.vendor_id = ap.vendor_id AND
                         rownum < 2;
               
               EXCEPTION
                  WHEN OTHERS THEN
                     v_status := 'E';
                     IF v_error IS NULL THEN
                        v_error := 'Supplier Site Does Not Exist';
                     ELSE
                        v_error := v_error || chr(10) ||
                                   'Supplier Site Does Not Exist';
                     END IF;
               END;
            
            WHEN OTHERS THEN
               v_status := 'E';
               IF v_error IS NULL THEN
                  v_error := 'Supplier Site Does Not Exist';
               ELSE
                  v_error := v_error || chr(10) ||
                             'Supplier Site Does Not Exist';
               END IF;
         END;
      
         BEGIN
            SELECT at.tax_id, at.NAME
              INTO v_tax_id, v_tax_name
              FROM ap_tax_codes_all at
             WHERE at.NAME LIKE i.tax_code || '%';
         EXCEPTION
            WHEN OTHERS THEN
               v_status := 'E';
               IF v_error IS NULL THEN
                  v_error := 'Tax Does Not Exist';
               ELSE
                  v_error := v_error || chr(10) || 'Tax Does Not Exist';
               END IF;
         END;
      
         IF i.certificate IS NULL THEN
            v_status := 'E';
            IF v_error IS NULL THEN
               v_error := 'Certificate Is Null';
            ELSE
               v_error := v_error || chr(10) || 'Certificate Is Null';
            END IF;
         END IF;
      
         BEGIN
            UPDATE xxobjt_conv_withholding w
               SET w.org_id           = v_org_id,
                   w.supplier_site_id = v_vendor_site_id,
                   --  w.supplier_name      = v_vendor_name,
                   --  w.supplier_code      = v_vendor_code,
                   w.supplier_id        = v_vendor_id,
                   w.tax_id             = v_tax_id,
                   w.trans_to_int_code  = v_status,
                   w.trans_to_int_error = v_error
             WHERE CURRENT OF cr_get_withtax;
         EXCEPTION
            WHEN OTHERS THEN
               dbms_output.put_line(v_status);
         END;
         IF v_status = 'S' THEN
            insert_new_certificate(i.from_date,
                                   i.to_date,
                                   v_tax_name,
                                   i.rate,
                                   l_user_id,
                                   v_vendor_id,
                                   v_vendor_site_id,
                                   v_vendor_name,
                                   v_tax_id,
                                   v_org_id,
                                   i.priority,
                                   i.certificate);
         END IF;
      
      END LOOP;
   
      COMMIT;
   
   END main;

END xxconv_withholding_tax_pkg;
/

