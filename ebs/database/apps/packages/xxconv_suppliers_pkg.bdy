CREATE OR REPLACE PACKAGE BODY xxconv_suppliers_pkg IS

-------------------------------------------------------------------
--       Owner : Stratasys Inc
-- Application : Stratasys (Objet) Customizations
--   File Name : XXCONV_SUPPLIERS_PKG.pkb
--        Date : 08-AUG-13
--      Author : Venu Kandi
-- Description : Package to load Syteline suppliers to Oracle
--
--   Called By : sqlplus
--      Output : standard out
--
-- Table and View  Table Name                Sel  Ins  Upd  Del
-- Usage:          ~~~~~~~~~~                ~~~  ~~~  ~~~  ~~~
--                xxobjt_conv_suppliers       X    X    X
--                xxobjt_conv_supp_contacts   X    X    X
--                xxobjt_conv_suppliers_comm  X    X    X
--                ap_suppliers_int            X    X
--                ap_supplier_sites_int       X    X
--                ap_suppliers                X         X
--                ap_supplier_sites_all       X         X
--
-- Modification History :
-- Who          Date         Reason
-- ~~~~~~~~~~~~ ~~~~~~~~~~   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- v.kandi      08-AUG-13    Created by IL. Adopted by US for loading
--                           Syteline Suppliers to Oracle
-- Mandar S     30-APR-21    CHG0049229 Added Default Attribute to ap_supplier_sites_int 
-- Eric H       30-APR-21    CHG0049229 Added return paramaters and assigned values 
-- Ofer         07-JAN-21    CHG0049229 Added loop to create Multiple Sites
------------------------------------------------------------------------

   /*** To load Fiscal and task data we can try ZX_PTP_MIGRATE_PKG***/
   PROCEDURE xxconv_create_supplier_api(errbuf  OUT VARCHAR2,
                                        retcode OUT VARCHAR2) AS
      l_vendor_type                 VARCHAR2(30);
      l_verify_flag                 VARCHAR(1);
      l_error_message               VARCHAR2(2500);
      l_invoice_currency            VARCHAR2(10);
      l_payment_currency            VARCHAR2(10);
      l_term_id                     NUMBER;
      l_site_term_id                NUMBER;
      l_pay_code_combination_id     NUMBER;
      l_prepay_code_combination_id  NUMBER;
      l_f_dated_code_combination_id NUMBER;
      l_org_id                      NUMBER;
      l_territory_code              VARCHAR2(10);
      l_cnt                         NUMBER(3);
      l_ship_location_id            NUMBER;
      l_bill_location_id            NUMBER;
      l_vendor_name                 VARCHAR2(150);
      l_vendor_site_code            VARCHAR2(100);
      l_employee_id                 NUMBER;
      v_interface_id                NUMBER;
      l_country_of_origin           VARCHAR2(2);
      l_pay_date_basis              VARCHAR2(20);
      l_match_option                VARCHAR2(10);
      l_payment_method              VARCHAR2(30);
      l_ship_via_lookup_code        VARCHAR2(30);
      l_pay_group_lookup_code       VARCHAR2(30);
      l_coa_id                      NUMBER;
      invalid_site EXCEPTION;
      invalid_vendor EXCEPTION;
      l_user_id             NUMBER;
      l_global_context_code VARCHAR2(150);
      l_return_status       VARCHAR2(1);
      l_err_msg             VARCHAR2(500);
      l_awt_flag            VARCHAR2(1);
      l_fob_lookup_code     VARCHAR2(30);
      l_freight_terms       VARCHAR2(30);

      l_stage 				VARCHAR2(30);

      CURSOR csr_suppliers IS
         SELECT DISTINCT a.legacy_supp_code,
                         a.vendor_name,
                         a.vendor_name_alt,
                         a.vendor_type,
                         a.payment_terms,
                         a.vat_registration_num,
                         a.standard_industry_class,
                         a.one_time_flag,
                         --a.invoice_currency,
                         --a.payment_currency,
                         a.employee_name,
                         a.calculate_tax_override,
                         receipt_days,
                         attribute1,
                         attribute2,
                         attribute3,
                         attribute4,
                         attribute5,
                         attribute6,
                         attribute7,
                         attribute8,
                         attribute9,
                         attribute10,
                         attribute11,
                         attribute12,
                         attribute13,
                         attribute14,
                         attribute15,
                         effective_date,
						 num_1099,
						 Type_1099,
						 Federal_Reportable_Flag,
						 State_Reportable_Flag,
						 Legacy_Supplier_Name
           FROM xxobjt_conv_suppliers a
          WHERE verify_flag = 'N';

      CURSOR csr_supplier_sites(p_supp_name VARCHAR2) IS
         SELECT *
           FROM xxobjt_conv_suppliers pvs
          WHERE pvs.legacy_supp_code = p_supp_name AND
                verify_flag = 'N';
      /*
      CURSOR c_supp_contact (P_supp_name varchar2, P_supp_site_code  varchar2) is
      select *
      from XXOBJT_conv_SUPPLIERS
      where vendor_name = p_supp_name
      and vendor_site_code = P_supp_site_code
      and nvl(verify_flag,'N') = 'N';
      */

      cur_supplier      csr_suppliers%ROWTYPE;
      cur_supplier_site csr_supplier_sites%ROWTYPE;

	  l_vendor_exists  VARCHAR(1); -- Added by Venu on 8/7/13
	  l_vendor_id	   NUMBER; -- Added by Venu on 8/7/13
	  l_site_exists    VARCHAR(1); -- Added by Venu on 8/8/13

   BEGIN

      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';

      FOR cur_supplier IN csr_suppliers LOOP

         l_verify_flag                := 'N';
         l_error_message              := NULL;
         l_cnt                        := 0;
         l_vendor_name                := NULL;
         l_org_id                     := NULL;
         l_employee_id                := NULL;
         l_vendor_type                := NULL;
         l_term_id                    := NULL;
         l_pay_code_combination_id    := NULL;
         l_prepay_code_combination_id := NULL;
         l_global_context_code        := NULL;
      	 l_vendor_exists 			  := 'N';
		 l_vendor_id	 			  := NULL;
		 v_interface_id				  := NULL;

         BEGIN

            l_stage := '001';

            BEGIN

			   SELECT vendor_id
                 INTO l_vendor_id  FROM ap_suppliers
                WHERE TRIM(upper(vendor_name)) =
                      TRIM(upper(cur_supplier.legacy_supp_code));

			   l_vendor_exists := 'Y';

			EXCEPTION
               WHEN no_data_found THEN
                  NULL;
			   WHEN others THEN
			   	  --l_verify_flag := 'E';
				  l_error_message := l_stage || ' Error looking up Vendor ' || substr(sqlerrm,1,500);
				  RAISE invalid_vendor;

            END;
            l_stage := '002';

            IF cur_supplier.employee_name IS NULL THEN
               l_employee_id := NULL;
            ELSE
               BEGIN

                  SELECT a.person_id
                    INTO l_employee_id
                    FROM per_people_f a
                   WHERE a.full_name = cur_supplier.employee_name;

               EXCEPTION
                  WHEN others THEN
                     l_employee_id := NULL;
                     --l_verify_flag := 'N';
                     l_error_message := l_stage || ' User is Not Valid';
                     RAISE invalid_vendor;
               END;
            END IF;

            l_stage := '003';

            IF cur_supplier.vendor_type IS NULL THEN
               l_vendor_type := NULL;
            ELSE
               BEGIN
                  SELECT lookup_code
                    INTO l_vendor_type
                    FROM po_lookup_codes plc
                   WHERE lookup_type = 'VENDOR TYPE' AND
                         upper(plc.displayed_field) =
                         upper(cur_supplier.vendor_type);
               EXCEPTION
                  WHEN OTHERS THEN
                     --l_verify_flag := 'N';
                     l_error_message := l_stage || ' Vendor Type Lookup Code not existing';
                     RAISE invalid_vendor;
               END;
            END IF;

            l_stage := '004';

            IF cur_supplier.payment_terms IS NULL THEN
               l_term_id := NULL;
            ELSE
               BEGIN
                  SELECT term_id
                    INTO l_term_id
                    FROM ap_terms_vl
                   WHERE upper(NAME) =
                         upper(TRIM(cur_supplier.payment_terms));
               EXCEPTION
                  WHEN OTHERS THEN
                     --l_verify_flag := 'N';
                     l_error_message := l_stage || '  Payment Term is not valid: ' || cur_supplier.payment_terms;
                     RAISE invalid_vendor;
               END;
            END IF;

            l_stage := '006';

            IF cur_supplier.legacy_supp_code IS NULL THEN
               l_verify_flag   := 'N';
               l_error_message := l_stage || ' Legacy Supp Code (Vendor Name) is not existing';
               RAISE invalid_vendor;
            END IF;

            l_stage := '007';

            BEGIN

               SELECT 'Y'
                 INTO l_awt_flag
                 FROM xxobjt_conv_withholding wh
                WHERE wh.supplier_name = cur_supplier.legacy_supp_code AND
                      rownum < 2;

            EXCEPTION
               WHEN others THEN
                  l_awt_flag := 'N';
            END;

            BEGIN

               SELECT DISTINCT invoice_currency, payment_currency
                 INTO l_invoice_currency, l_payment_currency
                 FROM xxobjt_conv_suppliers
                WHERE legacy_supp_code = cur_supplier.legacy_supp_code;

            EXCEPTION
               WHEN OTHERS THEN
                  l_invoice_currency := NULL;
                  l_payment_currency := NULL;
            END;
            l_stage := '008';


			IF l_vendor_exists = 'N' then
			BEGIN

	            SELECT ap_suppliers_int_s.NEXTVAL
	              INTO v_interface_id
	              FROM dual;

	            INSERT INTO ap_suppliers_int
	               (vendor_interface_id,
	                segment1,
	                vendor_name,
	                vendor_name_alt,
	                vendor_type_lookup_code,
	                invoice_currency_code,
	                payment_currency_code,
	                terms_id,
	                receipt_days_exception_code,
	                -- receiving_routing_id,  -- refer to issue log # 95 -- should be left null
	                -- inspection_required_flag,  -- refer to issue log # 95 -- should be left null
	                -- receipt_required_flag,  -- refer to issue log # 95 -- should be left null
	                auto_tax_calc_override,
	                vat_registration_num,
	                standard_industry_class,
	                one_time_flag,
	                start_date_active,
	                --employee_id,
	                allow_awt_flag,
	                attribute1,
	                attribute2,
	                attribute3,
	                attribute4,
	                attribute5,
	                attribute6,
	                attribute7,
	                attribute8,
	                attribute9,
	                attribute10,
	                attribute11,
	                attribute12,
	                attribute13,
	                attribute14,
	                attribute15,
	                attribute_category,
	                created_by,
	                creation_date,
	                last_updated_by,
	                last_update_date,
	                last_update_login,
					num_1099,
					Type_1099,
					Federal_Reportable_Flag,
					State_Reportable_Flag
					)
	            VALUES
	               (v_interface_id,
	                v_interface_id,
	                nvl(cur_supplier.legacy_supp_code, v_interface_id),
	                null, -- TRIM(cur_supplier.vendor_name), -- modified on 12/13/2013 - supplier name prints twice on checks
	                -- TRIM(cur_supplier.vendor_name_alt),
	                l_vendor_type,
	                l_invoice_currency,
	                l_payment_currency,
	                l_term_id,
	                upper(cur_supplier.receipt_days),
	                --  1, -- refer to issue log # 95 -- should be left null
	                -- 'N', -- refer to issue log # 95 -- should be left null
	                -- 'Y', -- refer to issue log # 95 -- should be left null
	                upper(cur_supplier.calculate_tax_override),
	                cur_supplier.vat_registration_num,
	                cur_supplier.standard_industry_class,
	                upper(cur_supplier.one_time_flag),
	                nvl(cur_supplier.effective_date, SYSDATE),
	                --l_employee_id,
	                l_awt_flag,
	                cur_supplier.attribute1,
	                cur_supplier.attribute2,
	                cur_supplier.attribute3,
	                cur_supplier.attribute4,
	                cur_supplier.attribute5,
	                cur_supplier.attribute6,
	                cur_supplier.attribute7,
	                cur_supplier.attribute8,
	                l_employee_id, --cur_supplier.attribute9,
	                cur_supplier.attribute10,
	                cur_supplier.attribute11,
	                cur_supplier.attribute12,
	                cur_supplier.attribute13,
	                cur_supplier.attribute14,
					-- Modified by Venu on 07/24/2013
	                -- cur_supplier.attribute15,
					cur_supplier.Legacy_Supplier_Name, -- Stores Syteline Vendor Number
	                null, -- (CASE WHEN cur_supplier.attribute1 IS NOT NULL THEN 81 WHEN
	                -- cur_supplier.attribute10 IS NOT NULL THEN 81 WHEN
	               --  cur_supplier.attribute14 IS NOT NULL THEN 81 ELSE NULL END),
	                l_user_id,
	                SYSDATE,
	                l_user_id,
	                SYSDATE,
	                -1,
					cur_supplier.num_1099,
					cur_supplier.Type_1099,
					cur_supplier.Federal_Reportable_Flag,
					cur_supplier.State_Reportable_Flag
					);

			END;
			ELSE -- Added by Venu on 8/7/13
				UPDATE xxobjt_conv_suppliers
				SET additional_notes = 'Vendor is already existing'
				WHERE vendor_name = cur_supplier.vendor_name;
			END IF;


            l_stage := '009';

            /*          UPDATE XXOBJT_conv_SUPPLIERS
                         SET verify_flag = 'Y'
                       WHERE vendor_name = cur_supplier.vendor_name;
            */
if l_vendor_id is not null then --  CHG0049229 --Ofer
            -- COMMIT;
            FOR cur_supplier_site IN csr_supplier_sites(cur_supplier.legacy_supp_code) LOOP

               --  BEGIN

               l_vendor_site_code  := NULL;
               l_ship_location_id  := NULL;
               l_bill_location_id  := NULL;
               l_country_of_origin := NULL;
               l_territory_code    := NULL;
               l_site_term_id      := NULL;
               l_match_option      := NULL;
               l_pay_date_basis    := NULL;
               l_fob_lookup_code   := NULL;
               l_freight_terms     := NULL;
			   l_error_message	   := NULL;
			   l_site_exists 	   := 'N';
			   l_verify_flag	   := 'N';

			   BEGIN

			      l_stage := '010';

                  SELECT organization_id
                    INTO l_org_id
                    FROM hr_operating_units
                   WHERE NAME = cur_supplier_site.operating_unit_name;

                  l_coa_id := xxgl_utils_pkg.get_coa_id_from_ou(l_org_id);

               EXCEPTION
                  WHEN OTHERS THEN
                     l_verify_flag   := 'E';
                     l_error_message := 'Operating Unit is Invalid';
                     --RAISE invalid_vendor;
               END;

			   IF  l_verify_flag = 'N' THEN
               BEGIN

				 l_stage := '020';

                  SELECT vendor_site_code
                  INTO l_vendor_site_code
                  FROM ap_supplier_sites_all a,
						 ap_suppliers b
                   WHERE a.org_id    = l_org_id
				   AND	 a.vendor_id = b.vendor_id
				   AND	 trim(upper(a.vendor_site_code)) = TRIM(upper(substr(cur_supplier_site.vendor_site_code,1,15)))
				   AND	 trim(upper(b.vendor_name))      = TRIM(upper(cur_supplier.legacy_supp_code));

				  l_site_exists := 'Y';
				  l_verify_flag := 'E';

               EXCEPTION
                  WHEN no_data_found THEN
                     NULL;
				  WHEN others THEN
					 l_verify_flag   := 'E';
                     l_error_message := 'Error looking up Vendor Site';
               END;
			   END IF;

			   -- Site does not exist, add it to interface
			   IF l_site_exists = 'N' AND -- Site does not exist in Oracle
			   	  l_verify_flag = 'N' THEN -- there are no validation errors
			   BEGIN

				   	l_stage := '030';

					IF  l_verify_flag = 'N' THEN
		               IF cur_supplier_site.ship_to_loc_code IS NULL THEN
		                  l_ship_location_id := NULL;
		               ELSE
		                  BEGIN
		                     SELECT location_id
		                       INTO l_ship_location_id
		                       FROM hr_locations a
		                      WHERE location_code =
		                            cur_supplier_site.ship_to_loc_code;
		                  EXCEPTION
		                     WHEN OTHERS THEN
		                        l_verify_flag := 'E';
		                        l_error_message := 'Ship to Location is Not Valid';
		                  END;
		               END IF;
				   END IF;

	               IF  l_verify_flag = 'N' THEN

				       l_stage := '040';
					   IF cur_supplier_site.bill_to_loc_code IS NULL THEN
		                  l_bill_location_id := NULL;
		               ELSE
		                  BEGIN
		                     SELECT location_id
		                       INTO l_bill_location_id
		                       FROM hr_locations
		                      WHERE location_code =
		                            cur_supplier_site.bill_to_loc_code;
		                  EXCEPTION
		                     WHEN OTHERS THEN
		                        l_verify_flag := 'E';
		                        l_error_message := 'Bill to Location is Not Valid';
		                        --RAISE invalid_vendor;
		                  END;
		               END IF;
				   END IF;

	               IF  l_verify_flag = 'N' THEN

					   l_stage := '050';

					   IF cur_supplier_site.country_of_origin_code IS NULL THEN
		                  l_country_of_origin := NULL;
		                  l_territory_code    := NULL;
		               ELSE
		                  BEGIN
						     -- Modified by Venu on 07/16/2013 for US
							 -- Staging table has the territory codes
		                     SELECT m.territory_code, m.territory_code
		                       INTO l_country_of_origin, l_territory_code
		                       FROM fnd_territories_vl m
		                      WHERE upper(m.territory_short_name) =
		                            upper(cur_supplier_site.country_of_origin_code)
									or upper(m.territory_code) = upper(cur_supplier_site.country_of_origin_code);

		                  EXCEPTION
		                     WHEN others THEN
		                        l_country_of_origin := NULL;
		                        l_territory_code    := NULL;
		                        l_verify_flag 		:= 'E';
								l_error_message     := 'Invalid Country';
		                        --RAISE invalid_vendor;
		                  END;
		               END IF;
				   END IF;

	               IF  l_verify_flag = 'N' THEN

					   l_stage := '060';

					   IF cur_supplier_site.terms_name IS NULL THEN
		                  l_term_id := NULL;
		               ELSE
		                  BEGIN
		                     SELECT atv.term_id
		                       INTO l_term_id
		                       FROM ap_terms_vl atv
		                      WHERE upper(atv.NAME) = upper(cur_supplier_site.terms_name);
		                  EXCEPTION
		                     WHEN OTHERS THEN
		                        l_verify_flag := 'E';
		                        l_error_message := 'Terms_Name is Not Valid: ' ||
		                                           cur_supplier_site.terms_name;
		                        --RAISE invalid_vendor;
		                  END;
		               END IF;
	               END IF;

	               IF  l_verify_flag = 'N' THEN

		               l_stage := '070';

					   IF cur_supplier_site.match_option IS NULL THEN
		                  l_match_option := NULL;
		               ELSE
		                  BEGIN

		                     SELECT a.lookup_code
		                       INTO l_match_option
		                       FROM fnd_lookup_values_vl a
		                      WHERE a.lookup_type LIKE 'POS_INVOICE_MATCH_OPTION' AND
		                            a.meaning = cur_supplier_site.match_option;
		                  EXCEPTION
		                     WHEN OTHERS THEN
		                        l_verify_flag := 'E';
		                        l_error_message := 'Match_Option is Not Valid';
		                        --RAISE invalid_vendor;
		                  END;
		               END IF;
	               END IF;

	               IF  l_verify_flag = 'N' THEN

					   l_stage := '080';

					   IF cur_supplier_site.pay_date_basis IS NULL THEN
		                  l_pay_date_basis := NULL;
		               ELSE
		                  BEGIN
		                     SELECT DISTINCT m.lookup_code
		                       INTO l_pay_date_basis
		                       FROM fnd_lookup_values_vl m
		                      WHERE m.lookup_type = 'PAY DATE BASIS' AND
		                            m.meaning = cur_supplier_site.pay_date_basis;

		                  EXCEPTION
		                     WHEN OTHERS THEN
		                        l_verify_flag    := 'E';
		                        l_pay_date_basis := NULL;
								l_error_message := 'Pay_Date_Basis is Not Valid';
		                        --RAISE invalid_vendor;
		                  END;
		               END IF;
	               END IF;

	               IF  l_verify_flag = 'N' THEN

					   l_stage := '090';

		               IF cur_supplier_site.pay_group_lookup_code IS NULL THEN
		                  l_pay_group_lookup_code := NULL;
		               ELSE
		                  BEGIN
		                     SELECT DISTINCT m.lookup_code
		                       INTO l_pay_group_lookup_code
		                       FROM fnd_lookup_values_vl m
		                      WHERE m.lookup_type = 'PAY GROUP' AND
		                            m.meaning =
		                            cur_supplier_site.pay_group_lookup_code;

		                  EXCEPTION
		                     WHEN OTHERS THEN
		                        l_verify_flag           := 'E';
		                        l_pay_group_lookup_code := NULL;
								l_error_message := 'Pay_group_lookup_code is Not Valid';
		                  END;
		               END IF;
	               END IF;

	               IF  l_verify_flag = 'N' THEN

					   l_stage := '100';

					   IF cur_supplier_site.context_value IS NULL THEN
		                  l_global_context_code := NULL;
		               ELSE
		                  BEGIN

		                     /*     SELECT descriptive_flex_context_code
		                      INTO l_global_context_code
		                      FROM fnd_descr_flex_contexts_vl df
		                     WHERE descriptive_flex_context_name =
		                           'Additional Supplier Site Information for Israel';*/

		                     l_global_context_code := 'JE.IL.APXVDMVD.SUPPLIER_SITE';

		                  EXCEPTION
		                     WHEN OTHERS THEN
		                        l_verify_flag := 'E';
		                        l_error_message := 'Invalid cglobal context';
		                  END;
		               END IF;
		           END IF;

	               IF  l_verify_flag = 'N' THEN

					   l_stage := '110';

					   IF cur_supplier_site.accts_pay_code_combination IS NULL THEN
		                  l_pay_code_combination_id := NULL;
		               ELSE
		                  BEGIN
		                     SELECT code_combination_id
		                       INTO l_pay_code_combination_id
		                       FROM gl_code_combinations_kfv gcc
		                      WHERE gcc.concatenated_segments =
		                            cur_supplier_site.accts_pay_code_combination;
		                  EXCEPTION
	/*
		                     WHEN no_data_found THEN

		                        xxgl_utils_pkg.get_and_create_account(p_concat_segment      => cur_supplier_site.accts_pay_code_combination,
		                                                              p_coa_id              => l_coa_id,
		                                                              x_code_combination_id => l_pay_code_combination_id,
		                                                              x_return_code         => l_return_status,
		                                                              x_err_msg             => l_err_msg);

		                        IF l_return_status != fnd_api.g_ret_sts_success THEN

		                           l_error_message := l_error_message || l_err_msg;
		                           RAISE invalid_site;

		                        END IF;

	*/
		                     WHEN OTHERS THEN

		                        l_verify_flag := 'E';
		                        l_error_message := 'Accounts Pay CodeCombination is Not Valid';
		                  END;
		               END IF;
	               END IF;

	               IF  l_verify_flag = 'N' THEN

					   l_stage := '120';

					   IF cur_supplier_site.prepay_code_combination IS NULL THEN
		                  l_prepay_code_combination_id := NULL;
		               ELSE
		                  BEGIN
		                     SELECT code_combination_id
		                       INTO l_prepay_code_combination_id
		                       FROM gl_code_combinations_kfv gcc
		                      WHERE gcc.concatenated_segments =
		                            cur_supplier_site.prepay_code_combination;
		                  EXCEPTION
		                     /*
							 WHEN no_data_found THEN

		                        xxgl_utils_pkg.get_and_create_account(p_concat_segment      => cur_supplier_site.accts_pay_code_combination,
		                                                              p_coa_id              => l_coa_id,
		                                                              x_code_combination_id => l_prepay_code_combination_id,
		                                                              x_return_code         => l_return_status,
		                                                              x_err_msg             => l_err_msg);

		                        IF l_return_status != fnd_api.g_ret_sts_success THEN

		                           l_error_message := l_error_message || l_err_msg;
		                           RAISE invalid_site;

		                        END IF;
							*/
		                     WHEN OTHERS THEN
		                        l_verify_flag := 'E';
		                        l_error_message := 'Pre-Pay Code Combination is Not Valid';
		                  END;
		               END IF;
	               END IF;

	               IF  l_verify_flag = 'N' THEN

					   l_stage := '130';

					   IF cur_supplier_site.future_dated IS NULL THEN
		                  l_f_dated_code_combination_id := NULL;
		               ELSE
		                  BEGIN
		                     SELECT code_combination_id
		                       INTO l_f_dated_code_combination_id
		                       FROM gl_code_combinations_kfv gcc
		                      WHERE gcc.concatenated_segments =
		                            cur_supplier_site.future_dated;
		                  EXCEPTION
						  /*
		                     WHEN no_data_found THEN

		                        xxgl_utils_pkg.get_and_create_account(p_concat_segment      => cur_supplier_site.future_dated,
		                                                              p_coa_id              => l_coa_id,
		                                                              x_code_combination_id => l_f_dated_code_combination_id,
		                                                              x_return_code         => l_return_status,
		                                                              x_err_msg             => l_err_msg);

		                        IF l_return_status != fnd_api.g_ret_sts_success THEN

		                           l_error_message := l_error_message || l_err_msg;
		                           RAISE invalid_site;

		                        END IF;
								*/

		                     WHEN OTHERS THEN
		                        l_verify_flag := 'E';
		                        l_error_message := 'Future Dates Code Combination is Not Valid';
		                  END;
		               END IF;
	               END IF;

	               IF  l_verify_flag = 'N' THEN

					   l_stage := '140';

					   /*
					   IF cur_supplier_site.pay_method_eft = 'Y' THEN

		                  l_payment_method := 'EFT';

		               ELSIF cur_supplier_site.pay_method_outsourced_check = 'Y' THEN

		                  l_payment_method := 'OUTSOURCED_CHECK';

		               ELSIF cur_supplier_site.pay_method_check = 'Y' THEN

		                  l_payment_method := 'CHECK';

		               ELSIF cur_supplier_site.pay_method_wire = 'Y' THEN

		                  l_payment_method := 'WIRE';

		               ELSE

		                  l_payment_method := NULL;

		               END IF;
					   */

					   -- l_payment_method := trim(cur_supplier_site.payment_method);

                                           l_payment_method := null;
                                           if upper(cur_supplier_site.payment_method) = upper('USD Wire Transfer') then
                                              l_payment_method := 'WF - MTS';
                                           elsif upper(cur_supplier_site.payment_method) = upper('Next Day Check') then
                                              l_payment_method := 'WF - CHK';
                                           elsif upper(cur_supplier_site.payment_method) = upper('Domestic ACH') then
                                              l_payment_method := 'WF - DAC';
                                           elsif upper(cur_supplier_site.payment_method) = upper('Intl Wire Transfer') then
                                              l_payment_method := 'WF - IWI';
                                           elsif upper(cur_supplier_site.payment_method) = upper('Same Day Check') then
                                              l_payment_method := 'WF - SDC';
                                           else
                                              l_payment_method := null;
                                           end if;

				   END IF;

	               IF  l_verify_flag = 'N' THEN

					   l_stage := '150';

					   IF cur_supplier_site.ship_via_lookup_code IS NULL THEN
		                  l_ship_via_lookup_code := NULL;
		               ELSE
		                  BEGIN
		                     SELECT fr.freight_code
		                       INTO l_ship_via_lookup_code
		                       FROM org_freight_vl               fr,
		                            financials_system_params_all fspa
		                      WHERE organization_id =
		                            fspa.inventory_organization_id AND
		                            (disable_date IS NULL OR disable_date > SYSDATE) AND
		                            fspa.org_id = l_org_id AND
		                            upper(fr.description) LIKE
		                            upper(cur_supplier_site.ship_via_lookup_code);

		                  EXCEPTION
		                     WHEN OTHERS THEN
		                        l_verify_flag := 'E';
		                        l_error_message := 'Invalid ship via';
		                        -- RAISE invalid_vendor;
		                  END;
		               END IF;
	               END IF;

	               IF  l_verify_flag = 'N' THEN

					   l_stage := '160';

					   IF cur_supplier_site.fob_lookup_code IS NULL THEN
		                  l_fob_lookup_code := NULL;
		               ELSE
		                  BEGIN
		                     SELECT lookup_code
		                       INTO l_fob_lookup_code
		                       FROM fnd_lookup_values
		                      WHERE lookup_type = 'FOB' AND
		                            LANGUAGE = 'US' AND
		                            description = cur_supplier_site.fob_lookup_code;

		                  EXCEPTION
		                     WHEN OTHERS THEN
		                        l_verify_flag := 'E';
		                        l_error_message := 'Invalid fob';
		                        --RAISE invalid_vendor;
		                  END;
		               END IF;
	               END IF;

	               IF  l_verify_flag = 'N' THEN

					   l_stage := '170';

					   IF cur_supplier_site.freight_terms IS NULL THEN
		                  l_freight_terms := NULL;
		               ELSE
		                  BEGIN
		                     SELECT lookup_code
		                       INTO l_freight_terms
		                       FROM fnd_lookup_values
		                      WHERE lookup_type = 'FREIGHT TERMS' AND
		                            LANGUAGE = 'US' AND
		                            upper(description) = upper(cur_supplier_site.freight_terms);

		                  EXCEPTION
		                     WHEN OTHERS THEN
		                        l_verify_flag := 'E';
		                        l_error_message := 'Invalid freight terms';
		                        --RAISE invalid_vendor;
		                  END;
		               END IF;
	               END IF;

	               IF  l_verify_flag = 'N' THEN
	               BEGIN

					  l_stage := '180';

	                  SELECT 'Y'
	                    INTO l_awt_flag
	                    FROM xxobjt_conv_withholding wh
	                   WHERE wh.supplier_name = cur_supplier.legacy_supp_code AND
	                         wh.supplier_site_code =
	                         substr(cur_supplier_site.vendor_site_code,1,15) AND
	                         rownum < 2;

	               EXCEPTION
	                  WHEN no_data_found THEN
	                     l_awt_flag := 'N';
	               END;
	               END IF;



	               IF  l_verify_flag = 'N' THEN

					   l_stage := '190';

					   IF cur_supplier_site.terms_name IS NULL THEN
		                  l_term_id := NULL;
		               ELSE
		                  BEGIN
		                     SELECT term_id
		                       INTO l_site_term_id
		                       FROM ap_terms_vl
		                      WHERE upper(NAME) =
		                            upper(TRIM(cur_supplier_site.terms_name));
		                  EXCEPTION
		                     WHEN OTHERS THEN
		                        l_verify_flag := 'E';
		                        l_error_message := 'Payment Term is not valid: ' ||
		                                           cur_supplier_site.terms_name;
		                        --RAISE invalid_vendor;
		                  END;
		               END IF;
	               END IF;



				   IF l_verify_flag = 'N' THEN -- No errors
				   BEGIN

					   l_stage := '200';

		               INSERT INTO ap_supplier_sites_int
		                  (vendor_interface_id,
						   vendor_id, -- Added by Venu on 8/7/13
		                   vendor_site_interface_id,
		                   vendor_site_code,
		                   vendor_site_code_alt,
		                   address_line1,
		                   address_line2,
		                   address_line3,
		                   city,
		                   state,
		                   country,
		                   zip,
		                   area_code,
		                   phone,
		                   county,
		                   email_address,
		                   accts_pay_code_combination_id,
		                   prepay_code_combination_id,
		                   future_dated_payment_ccid,
		                   operating_unit_name,
		                   ship_to_location_id,
		                   bill_to_location_id,
		                   ship_via_lookup_code,
		                   purchasing_site_flag,
		                   country_of_origin_code,
		                   pay_site_flag,
		                   rfq_only_site_flag,
		                   invoice_amount_limit,
		                   match_option,
		                   invoice_currency_code,
		                   hold_all_payments_flag,
		                   hold_unmatched_invoices_flag,
		                   hold_future_payments_flag,
		                   payment_currency_code,
		                   pay_group_lookup_code,
		                   bank_charge_bearer,
		                   terms_id,
		                   terms_date_basis,
		                   pay_date_basis_lookup_code,
		                   payment_method_lookup_code,
		                   payment_method_code,
		                   tax_reporting_site_flag,
		                   fob_lookup_code,
		                   freight_terms_lookup_code,
		                   allow_awt_flag,
		                   awt_group_name,
						   supplier_notif_method, ---CHG0049229
		                   org_id,
		                   global_attribute_category,
		                   global_attribute15, -- Organization_Type
		                   global_attribute13, -- Book_Keeping_Certificate
		                   global_attribute12, -- Book_Keep_Cer_Expiry_Date
		                   global_attribute11, -- Tax_Officer_Number
		                   global_attribute16, -- Include_In_Shaam_Reporting
		                   global_attribute17, -- Withholding_Tax_Report_Group
		                   global_attribute14, -- Occupation_Description,
		                   created_by,
		                   creation_date,
		                   last_updated_by,
		                   last_update_date,
		                   last_update_login
						   )
		               VALUES
		                  (v_interface_id,
						   l_vendor_id, -- Added by Venu on 8/7/13
		                   ap_supplier_sites_int_s.NEXTVAL,
		                   TRIM(substr(cur_supplier_site.vendor_site_code,1,15)),
		                   TRIM(substr(cur_supplier_site.vendor_site_code,1,15)),
		                   TRIM(cur_supplier_site.address1),
		                   TRIM(cur_supplier_site.address2),
		                   TRIM(cur_supplier_site.address3),
		                   TRIM(cur_supplier_site.city),
		                   TRIM(cur_supplier_site.state),
		                   l_territory_code,
		                   TRIM(cur_supplier_site.zip),
		                   TRIM(cur_supplier_site.area_code),
		                   TRIM(cur_supplier_site.phone),
		                   TRIM(cur_supplier_site.county),
		                   TRIM(cur_supplier_site.email),
		                   l_pay_code_combination_id,
		                   l_prepay_code_combination_id,
		                   l_f_dated_code_combination_id,
		                   cur_supplier_site.operating_unit_name,
		                   l_ship_location_id,
		                   l_bill_location_id,
		                   l_ship_via_lookup_code,
		                   upper(cur_supplier_site.purchasing_site_flag),
		                   l_country_of_origin, --trim(cur_supplier_site.COUNTRY_OF_ORIGIN_CODE),
		                   upper(cur_supplier_site.pay_site_flag),
		                   decode(upper(cur_supplier_site.purchasing_site_flag),
		                          'Y',
		                          NULL,
		                          upper(cur_supplier_site.rfq_only_site_flag)),
		                   TRIM(cur_supplier_site.invoice_amount_limit),
		                   l_match_option,
		                   TRIM(cur_supplier_site.invoice_currency),
		                   TRIM(cur_supplier_site.hold_all_invoices_flag),
		                   TRIM(cur_supplier_site.hold_unmatched_invoices_flag),
		                   TRIM(cur_supplier_site.hold_unvalidated_flag),
		                   TRIM(cur_supplier_site.payment_currency),
		                   l_pay_group_lookup_code,
		                   TRIM(cur_supplier_site.bank_charge_bearer),
		                   l_site_term_id,
		                   TRIM(cur_supplier_site.terms_date_basis),
		                   l_pay_date_basis,
		                   l_payment_method,
		                   l_payment_method,
		                   TRIM(cur_supplier_site.tax_reporting_site_flag),
		                   l_fob_lookup_code,
		                   l_freight_terms,
		                   l_awt_flag,
		                   cur_supplier_site.wht_group,
						   'EMAIL', ---CHG0049229
		                   l_org_id,
		                   l_global_context_code, --  JE.IL.APXVDMVD.SUPPLIER_SITE,
		                   cur_supplier_site.organization_type,
		                   cur_supplier_site.book_keeping_certificate,
		                   cur_supplier_site.book_keep_cer_expiry_date,
		                   decode(cur_supplier_site.tax_officer_number,
		                          NULL,
		                          NULL,
		                          lpad(cur_supplier_site.tax_officer_number, 2, '0')),
		                   decode(cur_supplier_site.include_in_shaam_reporting,
		                          NULL,
		                          NULL,
		                          substr(cur_supplier_site.include_in_shaam_reporting,
		                                 1,
		                                 1)),
		                   decode(cur_supplier_site.withholding_tax_report_group,
		                          NULL,
		                          NULL,
		                          lpad(REPLACE(cur_supplier_site.withholding_tax_report_group,
		                                       '-',
		                                       '0'),
		                               2,
		                               '0')),
		                   cur_supplier_site.occupation_description,
		                   l_user_id,
		                   SYSDATE,
		                   l_user_id,
		                   SYSDATE,
		                   -1
						   );

						l_stage := '210 (END)';

						UPDATE xxobjt_conv_suppliers
						SET verify_flag   = 'S',
							error_message = l_stage
						WHERE vendor_name = cur_supplier.vendor_name
						AND	  vendor_site_code = cur_supplier_site.vendor_site_code;

					END;
					ELSE

						l_stage := '220 (ERROR)';

						UPDATE xxobjt_conv_suppliers
						SET verify_flag   = 'E',
							error_message = l_stage || ' , ' || l_error_message
						WHERE vendor_name = cur_supplier.vendor_name
						AND	  vendor_site_code = cur_supplier_site.vendor_site_code;

					END IF;


				END;
				ELSE

					l_stage := '230 (ERROR)';
					l_error_message := 'Vendor Site is already existing';

					UPDATE xxobjt_conv_suppliers
					SET verify_flag   = 'E',
						error_message = l_stage || ', ' || l_error_message
					WHERE vendor_name = cur_supplier.vendor_name
					AND	  vendor_site_code = cur_supplier_site.vendor_site_code;

				END IF;

            END LOOP;
            end if;----  CHG0049229 -- Ofer

         EXCEPTION
            WHEN invalid_vendor THEN
               ROLLBACK;
               UPDATE xxobjt_conv_suppliers
                  SET verify_flag   = 'E',
                      error_message = l_stage || ', ' || l_error_message
                WHERE legacy_supp_code = cur_supplier.legacy_supp_code;

            WHEN invalid_site THEN
			   ROLLBACK;
               UPDATE xxobjt_conv_suppliers
                  SET verify_flag   = 'E',
                      error_message = l_stage || ', ' || l_error_message
                WHERE legacy_supp_code = cur_supplier.legacy_supp_code;
			WHEN OTHERS THEN
               ROLLBACK;
               l_error_message := substr(SQLERRM,1,1000);
               UPDATE xxobjt_conv_suppliers
                  SET verify_flag   = 'E',
                      error_message = l_stage || ', ' || l_error_message
                WHERE legacy_supp_code = cur_supplier.legacy_supp_code;

            --GOTO next_supp;
         END;

         COMMIT;
      END LOOP;

   END xxconv_create_supplier_api;

   PROCEDURE create_bank_api(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS

      CURSOR csr_banks IS
         SELECT DISTINCT b.country, b.bank_name, b.bank_code
           FROM xxobjt_conv_ap_banks b
          WHERE error_flag = 'N';

      CURSOR csr_branches(p_bank_name VARCHAR2) IS
         SELECT DISTINCT b.branch_name, b.branch_number
           FROM xxobjt_conv_ap_banks b
          WHERE bank_name = p_bank_name AND
                error_flag = 'N';

      CURSOR csr_accounts(p_bank_name VARCHAR2, p_branch_name VARCHAR2, p_branch_number NUMBER) IS
         SELECT *
           FROM xxobjt_conv_ap_banks b
          WHERE b.bank_name = p_bank_name AND
                b.branch_name = p_branch_name AND
                b.branch_number = p_branch_number AND
                error_flag = 'N';

      cur_bank    csr_banks%ROWTYPE;
      cur_branch  csr_branches%ROWTYPE;
      cur_account csr_accounts%ROWTYPE;

      l_error_flag    VARCHAR2(1) := 'N';
      l_msg_index_out NUMBER;
      l_return_status VARCHAR2(20);
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(2000);
      l_data          VARCHAR2(1000);
      l_error_msg     VARCHAR2(2000);

      l_result_code     VARCHAR2(20);
      l_result_category VARCHAR2(20);
      l_result_message  VARCHAR2(2000);

      l_bank_party_id       NUMBER;
      l_branch_id           NUMBER;
      l_acct_id             NUMBER;
      l_owner_acct_id       NUMBER;
      l_supplier_party_id   NUMBER;
      l_joint_acct_owner_id NUMBER;
      l_territory_code      VARCHAR2(2);

      l_bank_sequence NUMBER := 0;

      t_response        iby_fndcpt_common_pub.result_rec_type;
      t_extbankacct_rec iby_ext_bankacct_pub.extbankacct_rec_type;

   BEGIN

      FOR cur_bank IN csr_banks LOOP

         l_bank_party_id  := NULL;
         l_territory_code := NULL;
         l_return_status  := fnd_api.g_ret_sts_success;

         BEGIN

            l_bank_sequence := l_bank_sequence + 1;

            SELECT territory_code
              INTO l_territory_code
              FROM fnd_territories_vl
             WHERE territory_short_name = cur_bank.country;

            BEGIN

               SELECT bank_party_id
                 INTO l_bank_party_id
                 FROM ce_bank_branches_v t
                WHERE t.bank_name = cur_bank.bank_name AND
                      t.bank_home_country = l_territory_code AND
                      rownum < 2;

            EXCEPTION
               WHEN no_data_found THEN

                  iby_ext_bankacct_pub_w.create_ext_bank(p_api_version   => '1.0',
                                                         p_init_msg_list => 'T',
                                                         p2_a0           => NULL, --bank_id
                                                         p2_a1           => cur_bank.bank_name, --bank_name
                                                         p2_a2           => cur_bank.bank_code, --bank_number,
                                                         p2_a3           => NULL, --institution_type
                                                         p2_a4           => l_territory_code, --country_code
                                                         p2_a5           => NULL, --bank_alt_name
                                                         p2_a6           => NULL, --bank_short_name
                                                         p2_a7           => NULL, --description
                                                         p2_a8           => NULL, --tax_payer_id
                                                         p2_a9           => NULL, --tax_registration_number
                                                         p2_a10          => NULL, --attribute_category
                                                         p2_a11          => NULL, --attribute1
                                                         p2_a12          => NULL, --attribute2
                                                         p2_a13          => NULL, --attribute3
                                                         p2_a14          => NULL, --attribute4
                                                         p2_a15          => NULL, --attribute5
                                                         p2_a16          => NULL, --attribute6
                                                         p2_a17          => NULL, --attribute7
                                                         p2_a18          => NULL, --attribute8
                                                         p2_a19          => NULL, --attribute9
                                                         p2_a20          => NULL, --attribute10
                                                         p2_a21          => NULL, --attribute11
                                                         p2_a22          => NULL, --attribute12
                                                         p2_a23          => NULL, --attribute13
                                                         p2_a24          => NULL, --attribute14
                                                         p2_a25          => NULL, --attribute15
                                                         p2_a26          => NULL, --attribute16
                                                         p2_a27          => NULL, --attribute17
                                                         p2_a28          => NULL, --attribute18
                                                         p2_a29          => NULL, --attribute19
                                                         p2_a30          => NULL, --attribute20
                                                         p2_a31          => NULL, --attribute21
                                                         p2_a32          => NULL, --attribute22
                                                         p2_a33          => NULL, --attribute23
                                                         p2_a34          => NULL, --attribute24
                                                         p2_a35          => 1, --object_version_number
                                                         x_bank_id       => l_bank_party_id,
                                                         x_return_status => l_return_status,
                                                         x_msg_count     => l_msg_count,
                                                         x_msg_data      => l_msg_data,
                                                         p7_a0           => l_result_code,
                                                         p7_a1           => l_result_category,
                                                         p7_a2           => l_result_message);

            END;

         EXCEPTION
            WHEN OTHERS THEN

               l_return_status := fnd_api.g_ret_sts_unexp_error;
               l_msg_data      := 'Invalid Country';
               l_msg_count     := 0;
         END;

         IF l_return_status <> fnd_api.g_ret_sts_success THEN
            fnd_file.put_line(fnd_file.log,
                              'Creation ' || cur_bank.bank_name ||
                              ' is failed.');
            fnd_file.put_line(fnd_file.log,
                              'l_Msg_Count = ' || to_char(l_msg_count));
            fnd_file.put_line(fnd_file.log, 'l_Msg_Data = ' || l_msg_data);
            l_error_msg := NULL;
            FOR i IN 1 .. l_msg_count LOOP
               fnd_msg_pub.get(p_msg_index     => i,
                               p_data          => l_data,
                               p_encoded       => fnd_api.g_false,
                               p_msg_index_out => l_msg_index_out);
               fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
               l_error_msg := l_error_msg || l_data || chr(10);
            END LOOP;

            --   ROLLBACK;
            UPDATE xxobjt_conv_ap_banks a
               SET a.error_flag    = 'E',
                   a.error_message = nvl(l_error_msg, l_msg_data)
             WHERE a.bank_name = cur_bank.bank_name;

            --   COMMIT;

         ELSE

            COMMIT;
            -- Create Bank Branch

            FOR cur_branch IN csr_branches(cur_bank.bank_name) LOOP

               l_branch_id     := NULL;
               l_return_status := fnd_api.g_ret_sts_success;

               BEGIN
                  SELECT t.branch_party_id
                    INTO l_branch_id
                    FROM ce_bank_branches_v t
                   WHERE t.bank_name = cur_bank.bank_name AND
                         t.bank_home_country = l_territory_code AND
                         t.bank_branch_name = cur_branch.branch_name AND
                         branch_number = to_char(cur_branch.branch_number);

               EXCEPTION
                  WHEN no_data_found THEN

                     iby_ext_bankacct_pub_w.create_ext_bank_branch(p_api_version   => '1.0',
                                                                   p_init_msg_list => 'T',
                                                                   p2_a0           => NULL, --branch_party_id
                                                                   p2_a1           => l_bank_party_id, --bank_party_id
                                                                   p2_a2           => cur_branch.branch_name, --branch_name
                                                                   p2_a3           => lpad(cur_branch.branch_number,
                                                                                           3,
                                                                                           '0'), --branch_number
                                                                   p2_a4           => 'ABA', --branch_type
                                                                   p2_a5           => NULL, --alternate_branch_name
                                                                   p2_a6           => NULL, --description
                                                                   p2_a7           => NULL, --bic
                                                                   p2_a8           => NULL, --eft_number
                                                                   p2_a9           => NULL, --rfc_identifier
                                                                   p2_a10          => NULL, --attribute_category
                                                                   p2_a11          => NULL, --attribute1
                                                                   p2_a12          => NULL, --attribute2
                                                                   p2_a13          => NULL, --attribute3
                                                                   p2_a14          => NULL, --attribute4
                                                                   p2_a15          => NULL, --attribute5
                                                                   p2_a16          => NULL, --attribute6
                                                                   p2_a17          => NULL, --attribute7
                                                                   p2_a18          => NULL, --attribute8
                                                                   p2_a19          => NULL, --attribute9
                                                                   p2_a20          => NULL, --attribute10
                                                                   p2_a21          => NULL, --attribute11
                                                                   p2_a22          => NULL, --attribute12
                                                                   p2_a23          => NULL, --attribute13
                                                                   p2_a24          => NULL, --attribute14
                                                                   p2_a25          => NULL, --attribute15
                                                                   p2_a26          => NULL, --attribute16
                                                                   p2_a27          => NULL, --attribute17
                                                                   p2_a28          => NULL, --attribute18
                                                                   p2_a29          => NULL, --attribute19
                                                                   p2_a30          => NULL, --attribute20
                                                                   p2_a31          => NULL, --attribute21
                                                                   p2_a32          => NULL, --attribute22
                                                                   p2_a33          => NULL, --attribute23
                                                                   p2_a34          => NULL, --attribute24
                                                                   p2_a35          => NULL, --bch_object_version_number
                                                                   p2_a36          => NULL, --typ_object_version_number
                                                                   p2_a37          => NULL, --rfc_object_version_number
                                                                   p2_a38          => NULL, --eft_object_version_number
                                                                   x_branch_id     => l_branch_id,
                                                                   x_return_status => l_return_status,
                                                                   x_msg_count     => l_msg_count,
                                                                   x_msg_data      => l_msg_data,
                                                                   p7_a0           => l_result_code,
                                                                   p7_a1           => l_result_category,
                                                                   p7_a2           => l_result_message);

               END;

               IF l_return_status <> fnd_api.g_ret_sts_success THEN
                  fnd_file.put_line(fnd_file.log,
                                    'Creation ' || cur_branch.branch_name ||
                                    ' is failed.');
                  fnd_file.put_line(fnd_file.log,
                                    'l_Msg_Count = ' ||
                                    to_char(l_msg_count));
                  fnd_file.put_line(fnd_file.log,
                                    'l_Msg_Data = ' || l_msg_data);
                  l_error_msg := NULL;
                  FOR i IN 1 .. l_msg_count LOOP
                     fnd_msg_pub.get(p_msg_index     => i,
                                     p_data          => l_data,
                                     p_encoded       => fnd_api.g_false,
                                     p_msg_index_out => l_msg_index_out);
                     fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
                     l_error_msg := l_error_msg || l_data || chr(10);
                  END LOOP;

                  --    ROLLBACK;
                  UPDATE xxobjt_conv_ap_banks a
                     SET a.error_flag = 'E', a.error_message = l_error_msg
                   WHERE a.bank_name = cur_bank.bank_name AND
                         branch_name = cur_branch.branch_name AND
                         branch_number = to_char(cur_branch.branch_number);

                  --   COMMIT;

               ELSE

                  COMMIT;
                  FOR cur_account IN csr_accounts(cur_bank.bank_name,
                                                  cur_branch.branch_name,
                                                  cur_branch.branch_number) LOOP

                     -- Create Bank Branch Account
                     l_acct_id := NULL;

                     BEGIN

                        SELECT party_id
                          INTO l_supplier_party_id
                          FROM ap_suppliers s
                         WHERE s.vendor_name = cur_account.supplier_name;

                        t_extbankacct_rec.bank_account_id       := NULL;
                        t_extbankacct_rec.country_code          := l_territory_code;
                        t_extbankacct_rec.branch_id             := l_branch_id;
                        t_extbankacct_rec.bank_id               := l_bank_party_id;
                        t_extbankacct_rec.acct_owner_party_id   := l_supplier_party_id;
                        t_extbankacct_rec.bank_account_name     := NULL;
                        t_extbankacct_rec.bank_account_num      := lpad(cur_account.account_number,
                                                                        9,
                                                                        '0');
                        t_extbankacct_rec.currency              := cur_account.currency;
                        t_extbankacct_rec.object_version_number := 1;

                        iby_ext_bankacct_pub.create_ext_bank_acct(p_api_version       => 1.0,
                                                                  p_init_msg_list     => 'T',
                                                                  p_ext_bank_acct_rec => t_extbankacct_rec,
                                                                  p_association_level => 'S',
                                                                  p_supplier_site_id  => NULL,
                                                                  p_party_site_id     => NULL,
                                                                  p_org_id            => NULL,
                                                                  p_org_type          => NULL, --Bug7136876: new parameter
                                                                  x_acct_id           => l_acct_id,
                                                                  x_return_status     => l_return_status,
                                                                  x_msg_count         => l_msg_count,
                                                                  x_msg_data          => l_msg_data,
                                                                  x_response          => t_response);

                        /*     iby_ext_bankacct_pub_w.create_ext_bank_acct(p_api_version   => '1.0',
                        p_init_msg_list => 'T',
                        p2_a0           => NULL, --bank_account_id
                        p2_a1           => l_territory_code, --country_code
                        p2_a2           => l_branch_id, --branch_id
                        p2_a3           => l_bank_party_id, --bank_id
                        p2_a4           => l_supplier_party_id, --acct_owner_party_id
                        p2_a5           => NULL, --bank_account_name
                        p2_a6           => lpad(cur_account.account_number,
                                                9,
                                                '0'), --bank_account_num
                        p2_a7           => cur_account.currency, --currency
                        p2_a8           => NULL, --iban
                        p2_a9           => NULL, --check_digits
                        p2_a10          => NULL, --multi_currency_allowed_flag
                        p2_a11          => NULL, --alternate_acct_name
                        p2_a12          => NULL, --short_acct_name
                        p2_a13          => NULL, --acct_type
                        p2_a14          => NULL, --acct_suffix
                        p2_a15          => NULL, --description
                        p2_a16          => NULL, --agency_location_code
                        p2_a17          => NULL, --foreign_payment_use_flag
                        p2_a18          => NULL, --exchange_rate_agreement_num
                        p2_a19          => NULL, --exchange_rate_agreement_type
                        p2_a20          => NULL, --exchange_rate
                        p2_a21          => NULL, --payment_factor_flag
                        p2_a22          => NULL, --status
                        p2_a23          => NULL, --end_date
                        p2_a24          => SYSDATE, --start_date
                        p2_a25          => NULL, --hedging_contract_reference
                        p2_a26          => NULL, --attribute_category
                        p2_a27          => NULL, --attribute1
                        p2_a28          => NULL, --attribute2
                        p2_a29          => NULL, --attribute3
                        p2_a30          => NULL, --attribute4
                        p2_a31          => NULL, --attribute5
                        p2_a32          => NULL, --attribute6
                        p2_a33          => NULL, --attribute7
                        p2_a34          => NULL, --attribute8
                        p2_a35          => NULL, --attribute9
                        p2_a36          => NULL, --attribute10
                        p2_a37          => NULL, --attribute11
                        p2_a38          => NULL, --attribute12
                        p2_a39          => NULL, --attribute13
                        p2_a40          => NULL, --attribute14
                        p2_a41          => NULL, --attribute15
                        p2_a42          => NULL, --object_version_number
                        p2_a43          => NULL, --secondary_account_reference
                        x_acct_id       => l_acct_id,
                        x_return_status => l_return_status,
                        x_msg_count     => l_msg_count,
                        x_msg_data      => l_msg_data,
                        p7_a0           => l_result_code,
                        p7_a1           => l_result_category,
                        p7_a2           => l_result_message);*/

                        IF l_return_status <> fnd_api.g_ret_sts_success THEN
                           fnd_file.put_line(fnd_file.log,
                                             'Creation ' ||
                                             cur_account.account_number ||
                                             ' is failed.');
                           fnd_file.put_line(fnd_file.log,
                                             'l_Msg_Count = ' ||
                                             to_char(l_msg_count));
                           fnd_file.put_line(fnd_file.log,
                                             'l_Msg_Data = ' || l_msg_data);
                           l_error_msg := NULL;
                           FOR i IN 1 .. l_msg_count LOOP
                              fnd_msg_pub.get(p_msg_index     => i,
                                              p_data          => l_data,
                                              p_encoded       => fnd_api.g_false,
                                              p_msg_index_out => l_msg_index_out);
                              fnd_file.put_line(fnd_file.log,
                                                'l_Data - ' || l_data);
                              l_error_msg := l_error_msg || l_data ||
                                             chr(10);
                           END LOOP;

                           ROLLBACK;
                           UPDATE xxobjt_conv_ap_banks a
                              SET a.error_flag    = 'E',
                                  a.error_message = l_error_msg
                            WHERE a.bank_name = cur_bank.bank_name AND
                                  branch_name = cur_branch.branch_name AND
                                  branch_number =
                                  to_char(cur_branch.branch_number) AND
                                  a.account_number =
                                  cur_account.account_number;

                           COMMIT;

                        ELSE

                           UPDATE xxobjt_conv_ap_banks a
                              SET a.error_flag    = 'S',
                                  a.error_message = NULL
                            WHERE a.bank_name = cur_bank.bank_name AND
                                  branch_name = cur_branch.branch_name AND
                                  branch_number =
                                  to_char(cur_branch.branch_number) AND
                                  a.account_number =
                                  cur_account.account_number;

                           COMMIT;

                        END IF; --account owner success

                     EXCEPTION
                        WHEN OTHERS THEN

                           ROLLBACK;
                           UPDATE xxobjt_conv_ap_banks a
                              SET a.error_flag    = 'E',
                                  a.error_message = 'Invalid Supplier'
                            WHERE a.bank_name = cur_bank.bank_name AND
                                  branch_name = cur_branch.branch_name AND
                                  branch_number =
                                  to_char(cur_branch.branch_number) AND
                                  a.account_number =
                                  cur_account.account_number;

                           COMMIT;
                     END;

                  END LOOP; --Accounts

               END IF; --branch success

            END LOOP; --Branches

         END IF; --bank success
      END LOOP; --Banks

      COMMIT;

   END create_bank_api;

   PROCEDURE update_taxpayer_id IS

      CURSOR csr_suppliers IS
         SELECT DISTINCT a.legacy_supp_code, a.vat_registration_num
           FROM xxobjt_conv_suppliers a
          WHERE a.verify_flag != 'E' AND
                vat_registration_num IS NOT NULL;

      t_organization_rec      hz_party_v2pub.organization_rec_type;
      cur_supplier            csr_suppliers%ROWTYPE;
      l_supplier_party_id     NUMBER;
      l_object_version_number NUMBER;
      l_profile_id            NUMBER;
      l_return_status         VARCHAR2(1);
      l_msg_count             NUMBER;
      l_msg_data              VARCHAR2(500);

   BEGIN

      FOR cur_supplier IN csr_suppliers LOOP

         BEGIN
            SELECT hp.party_id, hp.object_version_number
              INTO l_supplier_party_id, l_object_version_number
              FROM ap_suppliers s, hz_parties hp
             WHERE s.vendor_name = cur_supplier.legacy_supp_code AND
                   hp.party_id = s.party_id;

            t_organization_rec.party_rec.party_id := l_supplier_party_id;
            t_organization_rec.organization_name  := cur_supplier.legacy_supp_code;
            t_organization_rec.organization_type  := 'ORGANIZATION';
            t_organization_rec.jgzz_fiscal_code   := cur_supplier.vat_registration_num;

            hz_party_v2pub.update_organization(p_organization_rec            => t_organization_rec,
                                               p_party_object_version_number => l_object_version_number,
                                               x_profile_id                  => l_profile_id,
                                               x_return_status               => l_return_status,
                                               x_msg_count                   => l_msg_count,
                                               x_msg_data                    => l_msg_data);
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;

      END LOOP;
      COMMIT;

   END update_taxpayer_id;

   PROCEDURE create_supplier_contact(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS --CHG0049229: added the required parameters

      CURSOR csr_supp_contacts IS
         SELECT * FROM xxobjt_conv_supp_contacts
		 WHERE int_status = 'N';

      CURSOR csr_supp_sites(p_vendor_id NUMBER) IS
         SELECT ss.vendor_site_id, ss.party_site_id
           FROM ap_supplier_sites_all ss
          WHERE ss.vendor_id = p_vendor_id;

      l_contact_point_id   NUMBER;
      l_contact_points_rec hz_contact_point_v2pub.contact_point_rec_type;
      l_phone_rec          hz_contact_point_v2pub.phone_rec_type;

      cur_contact         csr_supp_contacts%ROWTYPE;
      cur_site            csr_supp_sites%ROWTYPE;
      l_vendor_id         NUMBER;
      l_supplier_party_id NUMBER;
      l_return_status     VARCHAR2(1);
      l_msg_count         NUMBER;
      l_msg_data          VARCHAR2(500);
      l_person_party_id   NUMBER;
      l_err_msg           VARCHAR2(500);
      l_msg_index_out     NUMBER;

	  invalid_contact EXCEPTION;
   	  invalid_vendor EXCEPTION; -- Added by Venu on 7/25/13

   BEGIN

      -- Validation for last name
      UPDATE xxobjt_conv_supp_contacts t
      SET int_status = 'E', error_message = 'Last Name is null'
 	  WHERE last_name is null;

	  Commit;

      FOR cur_contact IN csr_supp_contacts LOOP

         BEGIN

			-- Modified by Venu on 7/25/13
			-- added exception handler logic
            BEGIN
			 SELECT vendor_id, party_id
              INTO l_vendor_id, l_supplier_party_id
              FROM ap_suppliers s
             WHERE s.vendor_name = cur_contact.vendor_name OR
                   s.vendor_name_alt = cur_contact.vendor_name OR
                   attribute15 = cur_contact.vendor_number;

			EXCEPTION
			WHEN OTHERS THEN
				 RAISE invalid_vendor;
			END;

			pos_supp_contact_pkg.create_supplier_contact(p_vendor_party_id => l_supplier_party_id,
                                                         p_first_name      => cur_contact.first_name,
                                                         p_last_name       => cur_contact.last_name,
                                                         p_phone_number    => (CASE WHEN cur_contact.phone_number IS NOT NULL AND cur_contact.cell_phone IS NOT NULL THEN cur_contact.phone_number || ' / ' || cur_contact.cell_phone WHEN cur_contact.phone_number IS NOT NULL THEN cur_contact.phone_number WHEN cur_contact.cell_phone IS NOT NULL THEN cur_contact.cell_phone ELSE NULL END),
                                                         p_phone_extension => cur_contact.office_phone,
                                                         p_fax_number      => cur_contact.fax_number,
                                                         p_email_address   => cur_contact.e_mail_address,
                                                         x_return_status   => l_return_status,
                                                         x_msg_count       => l_msg_count,
                                                         x_msg_data        => l_msg_data,
                                                         x_person_party_id => l_person_party_id);
			 IF l_return_status <> fnd_api.g_ret_sts_success THEN
               l_err_msg := NULL;
               FOR i IN 1 .. l_msg_count LOOP
                  fnd_msg_pub.get(p_msg_index     => i,
                                  p_data          => l_msg_data,
                                  p_encoded       => fnd_api.g_false,
                                  p_msg_index_out => l_msg_index_out);
                  l_err_msg := l_err_msg || l_msg_data;
               END LOOP;
			   RAISE invalid_contact;
            END IF;

            /*     l_phone_rec.phone_country_code := NULL;
            l_phone_rec.phone_area_code    := NULL;
            l_phone_rec.phone_number       := cur_contact.cell_phone;
            l_phone_rec.phone_extension    := NULL;
            l_phone_rec.phone_line_type    := 'MOBILE';

            l_contact_points_rec.contact_point_type := 'PHONE';
            l_contact_points_rec.status             := 'A';
            l_contact_points_rec.owner_table_name   := 'HZ_PARTIES';
            l_contact_points_rec.owner_table_id     := l_supplier_party_id;
            l_contact_points_rec.created_by_module  := 'POS_SUPPLIER_MGMT';
            l_contact_points_rec.application_id     := 177;
            l_contact_points_rec.primary_flag       := 'N';

            hz_contact_point_v2pub.create_contact_point(p_init_msg_list     => fnd_api.g_false,
                                                        p_contact_point_rec => l_contact_points_rec,
                                                        p_phone_rec         => l_phone_rec,
                                                        x_contact_point_id  => l_contact_point_id,
                                                        x_return_status     => x_return_status,
                                                        x_msg_count         => x_msg_count,
                                                        x_msg_data          => x_msg_data);*/

            /*           BEGIN
               pos_user_admin_pkg.create_supplier_user_ntf(p_user_name       => :1,
                                                           p_user_email      => :2,
                                                           p_person_party_id => :3,
                                                           p_password        => :4,
                                                           x_return_status   => :5,
                                                           x_msg_count       => :6,
                                                           x_msg_data        => :7,
                                                           x_user_id         => :8,
                                                           x_password        => :9);
            END;*/


            FOR cur_site IN csr_supp_sites(l_vendor_id) LOOP

			   pos_supplier_address_pkg.assign_address_to_contact(p_contact_party_id  => l_person_party_id,
                                                                  p_org_party_site_id => cur_site.party_site_id,
                                                                  p_vendor_id         => l_vendor_id,
                                                                  x_return_status     => l_return_status,
                                                                  x_msg_count         => l_msg_count,
                                                                  x_msg_data          => l_msg_data);

               IF l_return_status <> fnd_api.g_ret_sts_success THEN

                  l_err_msg := NULL;
                  FOR i IN 1 .. l_msg_count LOOP
                     fnd_msg_pub.get(p_msg_index     => i,
                                     p_data          => l_msg_data,
                                     p_encoded       => fnd_api.g_false,
                                     p_msg_index_out => l_msg_index_out);
                     l_err_msg := l_err_msg || l_msg_data;
                  END LOOP;

                  RAISE invalid_contact;
               END IF;

            END LOOP;

            UPDATE xxobjt_conv_supp_contacts t
               SET int_status = 'S', person_party_id = l_person_party_id
             WHERE t.vendor_name = cur_contact.vendor_name AND
                   t.last_name = cur_contact.last_name;

--CHG0049229: added return paramaters and assigned values               
            errbuf  := NULL;
            retcode := '0'; --Success (Green)
         EXCEPTION
            WHEN invalid_contact THEN
               ROLLBACK;
               UPDATE xxobjt_conv_supp_contacts t
                  SET int_status = 'E', error_message = l_err_msg
                WHERE t.vendor_name = cur_contact.vendor_name AND
                      t.last_name = cur_contact.last_name;

                retcode := 2; --Error (Red)
                errbuf  := 'Error (invalid_contact) in create_supplier_contact';

            WHEN invalid_vendor THEN -- Added by venu on 07/25/2013
			   ROLLBACK;
			   l_err_msg := 'Supplier not in Oracle';
               UPDATE xxobjt_conv_supp_contacts t
                  SET int_status = 'E', error_message = l_err_msg
                WHERE t.vendor_name = cur_contact.vendor_name AND
                      t.last_name = cur_contact.last_name;

                retcode := 2; --Error (Red)
                errbuf  := 'Error (invalid_vendor) in create_supplier_contact';

			WHEN OTHERS THEN
               l_err_msg := SQLERRM;
               ROLLBACK;
               UPDATE xxobjt_conv_supp_contacts t
                  SET int_status = 'E', error_message = l_err_msg
                WHERE t.vendor_name = cur_contact.vendor_name AND
                      t.last_name = cur_contact.last_name;
                      
                retcode := 2; --Error (Red)
                errbuf  := 'Error (OTHERS) in create_supplier_contact';
         END;

         COMMIT;

      END LOOP;

      COMMIT;
   END create_supplier_contact;

   PROCEDURE upload_fax IS

      CURSOR csr_supplier_sites IS
         SELECT ss.party_site_id, t.fax
           FROM xxobjt_conv_suppliers t,
                ap_suppliers          s,
                ap_supplier_sites_all ss
          WHERE t.legacy_supp_code = s.vendor_name AND
                s.vendor_id = ss.vendor_id AND
                t.fax IS NOT NULL;

      cur_site        csr_supplier_sites%ROWTYPE;
      l_init_msg_list VARCHAR2(1) := fnd_api.g_false;
      l_return_status VARCHAR2(1);
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(1000);

   BEGIN

      FOR cur_site IN csr_supplier_sites LOOP

         pos_hz_contact_point_pkg.update_party_site_fax(p_party_site_id => cur_site.party_site_id,
                                                        p_country_code  => NULL,
                                                        p_area_code     => NULL,
                                                        p_number        => cur_site.fax,
                                                        p_extension     => NULL,
                                                        x_return_status => l_return_status,
                                                        x_msg_count     => l_msg_count,
                                                        x_msg_data      => l_msg_data);

      END LOOP;
   END upload_fax;

   PROCEDURE vendor_notif_method (errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS

      CURSOR csr_supp_sites IS
      SELECT *
	  FROM xxobjt_conv_suppliers_comm t
	  WHERE  t.process_code = 'N';

		 /*SELECT s.vendor_id,
                ss.vendor_site_id,
                t.vendor_name,
                t.site_number,
                ss.org_id,
                ss.vendor_site_code,
                t.notification_method,
                t.email_address,
                t.fax_area_code,
                t.fax
           FROM xxobjt_conv_suppliers_comm t,
                ap_suppliers               s,
                ap_supplier_sites_all      ss
          WHERE (t.vendor_name = s.vendor_name OR
                t.vendor_name = s.vendor_name_alt OR
                t.site_number = s.attribute15) AND
                s.vendor_id = ss.vendor_id AND
				-- Added by Venu on 07/29/2013
                t.vendor_site_code = ss.vendor_site_code
				-- Modified by Venu on 07/25/2013
				--process_code = 'N';
				 nvl(t.process_code,'N') in ('S','N');
   */

      --cur_site          csr_supp_sites%ROWTYPE;
      l_vendor_site_rec ap_vendor_pub_pkg.r_vendor_site_rec_type;
      l_return_status   VARCHAR2(1);
      l_msg_count       NUMBER;
      l_msg_data        VARCHAR2(500);
      l_err_msg         VARCHAR2(500);
      l_msg_index_out   NUMBER;
	  invalid_data		EXCEPTION; -- Added by Venu on 07/29/13
	  invalid_site 		EXCEPTION;

	  l_vendor_id 		NUMBER;-- Added by Venu on 07/29/13
	  l_vendor_site_id	NUMBER; -- Added by Venu on 07/29/13
	  l_org_id			NUMBER; -- Added by Venu on 07/29/13
	  l_vendor_site_code	   VARCHAR2(30); -- Added by Venu on 07/29/13


   	  l_location_rec 		   hz_location_v2pub.location_rec_type;
	  l_location_id 		   NUMBER;
	  l_object_version_number  NUMBER;
	  x_return_status 		   VARCHAR2(200);
	  x_msg_count 			   NUMBER;
	  x_msg_data 			   VARCHAR2(200);
	  l_error_message 		   VARCHAR2(1000);

   BEGIN

	  -- Get operating unit org id
	  BEGIN
	  	  SELECT organization_id
		  INTO l_org_id
		  FROM hr_operating_units
		  WHERE NAME = 'Stratasys US OU';
	  EXCEPTION
	  WHEN OTHERS THEN
		  l_err_msg := 'Invalid Operating Unit  - Error: ' || sqlerrm;
		  RAISE invalid_data;
	  END;

      FOR cur_site IN csr_supp_sites LOOP

         BEGIN

            l_err_msg 				 := NULL;

			-- Added by Venu on 07/29/13
			l_vendor_id 			 := NULL;
			l_vendor_site_id 		 := NULL;

			-- Added by Venu on 07/29/13
			BEGIN
				SELECT vendor_id
				INTO l_vendor_id
				FROM ap_suppliers
				WHERE upper(vendor_name) = upper(cur_site.vendor_name);
			EXCEPTION
			WHEN OTHERS THEN
				 l_err_msg := 'Invalid Vendor - Error: ' || sqlerrm;
				 RAISE invalid_data;
			END;

			--- Added by Venu on 07/29/13
			BEGIN
				SELECT vendor_site_id,
                	   vendor_site_code
				INTO l_vendor_site_id,
					 l_vendor_site_code
				FROM ap_supplier_sites_all
				WHERE vendor_id = l_vendor_id
				AND	  org_id 	= l_org_id
				-- note: replace condition removes the new line char at the end of the line in comm file
				AND	  trim(upper(vendor_site_code)) = trim(substr(upper(REPLACE(REPLACE(cur_site.vendor_site_code, CHR(10) ), CHR(13) )),1,15));

			EXCEPTION
			WHEN OTHERS THEN
				 l_err_msg := 'Invalid Vendor Site Code - Error: ' || sqlerrm;
				 RAISE invalid_data;
			END;

			/*

         	-- Modified by Venu on 07/29/13
            -- l_vendor_site_rec.vendor_site_id        := cur_site.vendor_site_id;
			l_vendor_site_rec.vendor_site_id        := l_vendor_site_id;

			l_vendor_site_rec.last_update_date      := SYSDATE;
            l_vendor_site_rec.last_updated_by       := 1171;

			-- Modified by Venu on 07/29/13
			--l_vendor_site_rec.vendor_id             := cur_site.vendor_id;
            l_vendor_site_rec.vendor_id             := l_vendor_id;

			-- Modified by Venu on 07/29/13
			--l_vendor_site_rec.vendor_site_code      := cur_site.vendor_site_code;
            l_vendor_site_rec.vendor_site_code      := l_vendor_site_code;

			l_vendor_site_rec.supplier_notif_method := cur_site.notification_method;
            l_vendor_site_rec.email_address         := cur_site.email_address;

			-- Modified by Venu on 07/29/13
			--l_vendor_site_rec.org_id                := cur_site.org_id;
			l_vendor_site_rec.org_id                := l_org_id;

			--l_vendor_site_rec.terms_name            := p_terms_name;
            --l_vendor_site_rec.awt_group_name        := p_awt_group_name;
            --l_vendor_site_rec.distribution_set_name := p_distribution_set_name;
            --l_vendor_site_rec.tolerance_name        := p_tolerance_name;
            l_vendor_site_rec.fax           := cur_site.fax;
            l_vendor_site_rec.fax_area_code := cur_site.fax_area_code;

            pos_vendor_pub_pkg.update_vendor_site(l_vendor_site_rec,
                                                  l_return_status,
                                                  l_msg_count,
                                                  l_msg_data);

            IF l_return_status <> fnd_api.g_ret_sts_success THEN

               FOR i IN 1 .. l_msg_count LOOP
                  fnd_msg_pub.get(p_msg_index     => i,
                                  p_data          => l_msg_data,
                                  p_encoded       => fnd_api.g_false,
                                  p_msg_index_out => l_msg_index_out);
                  l_err_msg := l_err_msg || l_msg_data;
               END LOOP;

               RAISE invalid_site;
            END IF;

			*/

			-- update phone, fax, email and notification method

			UPDATE ap_supplier_sites_all
			SET supplier_notif_method = upper(cur_site.notification_method),
				email_address 		  = trim(cur_site.email_address),
				phone				  = trim(REPLACE(REPLACE(cur_site.phone,CHR(10)),CHR(13))),
				fax					  = trim(REPLACE(REPLACE(cur_site.fax,CHR(10)),CHR(13)))
			WHERE vendor_site_id = l_vendor_site_id
			AND	  org_id 		 = l_org_id;

			-- update staging table

			UPDATE xxobjt_conv_suppliers_comm t
               SET process_code   = 'S',
                   -- vendor_site_id = cur_site.vendor_site_id
				   vendor_site_id = l_vendor_site_id
             WHERE vendor_name = cur_site.vendor_name AND
				   -- site_number = cur_site.site_number;
				   vendor_site_code = cur_site.vendor_site_code;

			COMMIT;

         EXCEPTION
            WHEN invalid_data THEN

               ROLLBACK;
               UPDATE xxobjt_conv_suppliers_comm t
                  SET t.process_code = 'E', t.error_msg = l_err_msg
                WHERE vendor_name = cur_site.vendor_name AND
					  -- site_number = cur_site.site_number;
                      vendor_site_code = cur_site.vendor_site_code;

            WHEN invalid_site THEN

               ROLLBACK;
               UPDATE xxobjt_conv_suppliers_comm t
                  SET t.process_code = 'E', t.error_msg = 'ERROR: ' || l_err_msg
                WHERE vendor_name = cur_site.vendor_name AND
                      --site_number = cur_site.site_number;
					  vendor_site_code = cur_site.vendor_site_code;

			WHEN OTHERS THEN
               l_err_msg := SQLERRM;
               ROLLBACK;
               UPDATE xxobjt_conv_suppliers_comm t
                  SET process_code = 'E', error_msg = l_err_msg
                WHERE vendor_name = cur_site.vendor_name AND
                      --site_number = cur_site.site_number;
            		  vendor_site_code = cur_site.vendor_site_code;
         END;

         COMMIT;

      END LOOP;

	  COMMIT;

	  errbuf := 0;
	  retcode := null;

   EXCEPTION
     WHEN invalid_data THEN
         ROLLBACK;
		 errbuf := 1;
	  	 retcode := l_err_msg;
   END vendor_notif_method;

   PROCEDURE Fix_Cust_Oper_Unit_Attribute(errbuf OUT VARCHAR2, retcode OUT VARCHAR2)
   IS
     ln_count_before   NUMBER;
	 ln_count_updated  NUMBER;
   BEGIN

	   SELECT count(*)
	   into ln_count_before
	   FROM hz_parties
	   WHERE party_id IN (SELECT sup.party_id
	   		 		  	  FROM ap_suppliers_int supint,
						  	   ap_suppliers sup
	  		   	   	  	  WHERE sup.vendor_name = supint.vendor_name
				   		  AND	supint.status   = 'PROCESSED');

	   IF ln_count_before > 0 THEN

		  UPDATE hz_parties
		  SET attribute3 = NULL
		  WHERE party_id IN (SELECT sup.party_id
		  				     FROM ap_suppliers_int supint,
		  				 	 	  ap_suppliers sup
	  		   	   		 	 WHERE sup.vendor_name = supint.vendor_name
				   			 AND   supint.status   = 'PROCESSED');

   		  ln_count_updated := SQL%ROWCOUNT;

		  IF ln_count_before = ln_count_updated THEN
		  	 COMMIT;
			 errbuf := 0;
			 retcode := 'Update successful. Commit executed successfully';
		  ELSE
		     ROLLBACK;
			 errbuf := 1;
			 retcode := 'Updated failed. Before (' ||  ln_count_before || ') and After (' || ln_count_updated || ') rowcounts did not match. Rollback executed successfully';
		  END IF;

	   ELSE

	   	  errbuf := 2;
		  retcode := 'Nothing to update. Please verify';

	   END IF;

   END Fix_Cust_Oper_Unit_Attribute;

   PROCEDURE Upd_LegSuppName
   IS

	-- We process rejected records only
	-- If the record is valid, this value will be automatically updated by the interface
    CURSOR cur_supp
	IS
	SELECT DISTINCT vendor_name, legacy_supplier_name
	FROM  xxobjt_conv_suppliers
	--WHERE verify_flag = 'E'
	--AND	  additional_notes = 'Vendor is already existing'
	--AND	  legacy_supplier_name IS NOT NULL;
        WHERE legacy_supplier_name IS NOT NULL;

	l_vendor_id 	  NUMBER;
	l_legacy_supp_name VARCHAR2(100);


	BEGIN

	FOR rec_supp IN cur_supp LOOP
	BEGIN

		 l_vendor_id := NULL;
		 l_legacy_supp_name := NULL;

		 BEGIN
		 	 SELECT vendor_id, attribute15
		 	 INTO l_vendor_id, l_legacy_supp_name
		 	 FROM ap_suppliers
		 	 WHERE upper(vendor_name) = upper(rec_supp.vendor_name);

		 EXCEPTION
		 WHEN OTHERS THEN
		 	 l_vendor_id := -1;
		 	 NULL;
		 END;

		 IF l_vendor_id != -1 THEN
		 BEGIN
		     IF instr(nvl(l_legacy_supp_name,'X'), rec_supp.legacy_supplier_name) = 0 THEN

			 	 UPDATE ap_suppliers
				 SET attribute15 = DECODE(NVL(l_legacy_supp_name,'X'),'X',rec_supp.legacy_supplier_name, l_legacy_supp_name || ', ' || rec_supp.legacy_supplier_name)
				 WHERE vendor_id = l_vendor_id;
			 END IF;
		 END;
		 END IF;
	END;
	END LOOP;

        COMMIT;

   END Upd_LegSuppName;

   PROCEDURE Fix_hold_flags
   IS
   BEGIN

		-- Remove purchasing hold
   		UPDATE ap_suppliers
		SET    hold_flag 			  = 'N',
	   		   purchasing_hold_reason = NULL,
	   		   hold_date 			  = NULL,
	   		   hold_by 				  = NULL
		WHERE hold_flag   	 		 = 'Y'
		AND	  purchasing_hold_reason = 'New Supplier'
		AND	  creation_date 		 >= sysdate - 30 -- Created in the last 30 days
		AND	  upper(vendor_name) 	 IN (SELECT upper(vendor_name)
	  					 	 		 	 FROM  ap_suppliers_int); -- New vendors only

		-- Remove All Invocies Hold
		UPDATE ap_suppliers
		SET	   hold_all_payments_flag = 'N'
		WHERE hold_all_payments_flag  = 'Y'
		AND	  creation_date 		 >= sysdate - 30 -- Created in the last 30 days
		AND	  upper(vendor_name) 	 IN (SELECT upper(vendor_name)
	  					 	 		 	 FROM  ap_suppliers_int); -- New vendors only

		-- Rest hold reason, if all 3 flags are null
		UPDATE ap_suppliers
		SET	   hold_reason = null
		WHERE hold_all_payments_flag       = 'N' -- All three flags have to be null
		AND	  hold_unmatched_invoices_flag = 'N'
	   	AND	  hold_future_payments_flag    = 'N'
		AND	  creation_date 		 	   >= sysdate - 30 -- Created in the last 30 days
		AND	  upper(vendor_name) 	 	   IN (SELECT upper(vendor_name)
	  					 	 		 	   	   FROM  ap_suppliers_int); -- New vendors only

		COMMIT;

   END Fix_hold_flags;

END xxconv_suppliers_pkg;
/