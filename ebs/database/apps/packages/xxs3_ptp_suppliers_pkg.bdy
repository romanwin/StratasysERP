CREATE OR REPLACE PACKAGE BODY xxs3_ptp_suppliers_pkg AS
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Suppliers template fields
  --                   from Legacy system

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  28/04/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required supplier fields and insert into
  --           staging table XXS3_PTP_SUPPLIERS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  28/04/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  report_error EXCEPTION;
  g_request_id CONSTANT NUMBER := fnd_global.conc_request_id;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors and update master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE insert_update_supplier_dq(p_xx_vendor_id NUMBER,
                                      p_rule_name    IN VARCHAR2,
                                      p_reject_code  IN VARCHAR2) IS
    l_step VARCHAR2(50);
  BEGIN
   /* Update Process flag for DQ records with 'Q' */
    l_step := 'Set Process_Flag =Q';

    UPDATE xxs3_ptp_suppliers
    SET    process_flag = 'Q'
    WHERE  xx_vendor_id = p_xx_vendor_id;

    /* Insert records in the DQ table with DQ details */
	   l_step := 'Insert into DQ table';

    INSERT INTO xxs3_ptp_suppliers_dq
      (xx_dq_vendor_id,
       xx_vendor_id,
       rule_name,
       notes)
    VALUES
      (xxs3_ptp_suppliers_dq_seq.NEXTVAL,
       p_xx_vendor_id,
       p_rule_name,
       p_reject_code);
  EXCEPTION
    WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table DML for xx_vendor_id = '
                          ||p_xx_vendor_id|| 'at step: '||l_step||chr(10) || SQLCODE || chr(10) || SQLERRM);

  END insert_update_supplier_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors and update master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE insert_update_supp_reject_dq(p_xx_vendor_id NUMBER,
                                         p_rule_name    IN VARCHAR2,
                                         p_reject_code  IN VARCHAR2) IS
    l_step VARCHAR2(50);
  BEGIN
    /* Update Process flag for DQ records with 'Q' */
    l_step := 'Set Process_Flag =R';

    UPDATE xxs3_ptp_suppliers
    SET    process_flag = 'R'
    WHERE  xx_vendor_id = p_xx_vendor_id;

    /* Insert records in the DQ table with DQ details */
	   l_step := 'Insert into DQ table for rejected records';

    INSERT INTO xxs3_ptp_suppliers_dq
      (xx_dq_vendor_id,
       xx_vendor_id,
       rule_name,
       notes)
    VALUES
      (xxs3_ptp_suppliers_dq_seq.NEXTVAL,
       p_xx_vendor_id,
       p_rule_name,
       p_reject_code);

  EXCEPTION
    WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table DML for xx_vendor_id = '
                          ||p_xx_vendor_id|| 'at step: '||l_step||chr(10) || SQLCODE || chr(10) || SQLERRM);

  END insert_update_supp_reject_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors and update master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE insert_update_site_dq(p_xx_vendor_site_id NUMBER,
                                  p_rule_name         IN VARCHAR2,
                                  p_reject_code       IN VARCHAR2) IS

    l_step VARCHAR2(50);
  BEGIN
  /* Update Process flag for DQ records with 'Q' */
    l_step := 'Set Process_Flag =Q';
    UPDATE xxs3_ptp_suppliers_sites
    SET    process_flag = 'Q'
    WHERE  xx_vendor_site_id = p_xx_vendor_site_id;

  /* Insert records in the DQ table with DQ details */
	   l_step := 'Insert into DQ table';
    INSERT INTO xxs3_ptp_suppliers_sites_dq
      (xx_dq_vendor_site_id,
       xx_vendor_site_id,
       rule_name,
       notes)
    VALUES
      (xxs3_ptp_suppliers_site_dq_seq.NEXTVAL,
       p_xx_vendor_site_id,
       p_rule_name,
       p_reject_code);

  EXCEPTION
    WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table DML for xx_vendor_site_id = '
                          ||p_xx_vendor_site_id|| 'at step: '||l_step||chr(10) || SQLCODE || chr(10) || SQLERRM);
  END insert_update_site_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors and update master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE insert_update_site_reject_dq(p_xx_vendor_site_id NUMBER,
                                         p_rule_name         IN VARCHAR2,
                                         p_reject_code       IN VARCHAR2) IS
    l_step VARCHAR2(50);
  BEGIN
   /* Update Process flag for DQ records with 'R' */
    l_step := 'Set Process_Flag =R';
    UPDATE xxs3_ptp_suppliers_sites
    SET    process_flag = 'R'
    WHERE  xx_vendor_site_id = p_xx_vendor_site_id;

    /* Insert records in the DQ table with DQ details */
	   l_step := 'Insert into DQ table for rejected records';

    INSERT INTO xxs3_ptp_suppliers_sites_dq
      (xx_dq_vendor_site_id,
       xx_vendor_site_id,
       rule_name,
       notes)
    VALUES
      (xxs3_ptp_suppliers_site_dq_seq.NEXTVAL,
       p_xx_vendor_site_id,
       p_rule_name,
       p_reject_code);
  EXCEPTION
    WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table DML for xx_vendor_site_id = '
                          ||p_xx_vendor_site_id|| 'at step: '||l_step||chr(10) || SQLCODE || chr(10) || SQLERRM);

  END insert_update_site_reject_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors and update master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  3/08/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE insert_update_contact_dq(p_xx_vendor_contact_id NUMBER,
                                     p_rule_name            IN VARCHAR2,
                                     p_reject_code          IN VARCHAR2) IS
    l_step VARCHAR2(50);
  BEGIN
    /* Update Process flag for DQ records with 'R' */
    l_step := 'Set Process_Flag =Q';

    UPDATE xxs3_ptp_suppliers_cont
    SET    process_flag = 'Q'
    WHERE  xx_vendor_contact_id = p_xx_vendor_contact_id;

    /* Insert records in the DQ table with DQ details */
	   l_step := 'Insert into DQ table ';

    INSERT INTO xxs3_ptp_suppliers_cont_dq
      (xx_dq_vendor_contact_id,
       xx_vendor_contact_id,
       rule_name,
       notes)
    VALUES
      (xxs3_ptp_suppliers_cont_dq_seq.NEXTVAL,
       p_xx_vendor_contact_id,
       p_rule_name,
       p_reject_code);
  EXCEPTION
    WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table DML for xx_vendor_contact_id = '
                          ||p_xx_vendor_contact_id|| 'at step: '||l_step||chr(10) || SQLCODE || chr(10) || SQLERRM);

  END insert_update_contact_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors and update master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE insert_update_quote_hdr_dq(p_xx_po_header_id NUMBER,
                                       p_rule_name       IN VARCHAR2,
                                       p_reject_code     IN VARCHAR2) IS
   l_step VARCHAR2(50);
  BEGIN
    /* Update Process flag for DQ records with 'R' */
    l_step := 'Set Process_Flag =Q';

    UPDATE xxs3_ptp_quotation_hdr
    SET    process_flag = 'Q'
    WHERE  xx_po_header_id = p_xx_po_header_id;

  /* Insert records in the DQ table with DQ details */
	   l_step := 'Insert into DQ table ';
    INSERT INTO xxs3_ptp_quotation_hdr_dq
      (xx_dq_po_hdr_id,
       xx_po_header_id,
       rule_name,
       notes)
    VALUES
      (xxs3_ptp_quotation_hdr_dq_seq.NEXTVAL,
       p_xx_po_header_id,
       p_rule_name,
       p_reject_code);
  EXCEPTION
    WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table DML for xx_po_header_id = '
                          ||p_xx_po_header_id|| 'at step: '||l_step||chr(10) || SQLCODE || chr(10) || SQLERRM);

  END insert_update_quote_hdr_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors and update master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE insert_update_quote_line_dq(p_xx_po_line_id NUMBER,
                                        p_rule_name     IN VARCHAR2,
                                        p_reject_code   IN VARCHAR2) IS
   l_step VARCHAR2(50);
  BEGIN
  /* Update Process flag for DQ records with 'R' */
    l_step := 'Set Process_Flag =Q';

    UPDATE xxs3_ptp_quotation_line
    SET    process_flag = 'Q'
    WHERE  xx_po_line_id = p_xx_po_line_id;

    /* Insert records in the DQ table with DQ details */
	   l_step := 'Insert into DQ table ';
    INSERT INTO xxs3_ptp_quotation_line_dq
      (xx_dq_po_line_id,
       xx_po_line_id,
       rule_name,
       notes)
    VALUES
      (xxs3_ptp_quotation_line_dq_seq.NEXTVAL,
       p_xx_po_line_id,
       p_rule_name,
       p_reject_code);

  EXCEPTION
    WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table DML for xx_po_line_id = '
                          ||p_xx_po_line_id|| 'at step: '||l_step||chr(10) || SQLCODE || chr(10) || SQLERRM);

  END insert_update_quote_line_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update agent_name
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_agent_name(p_id         IN NUMBER,
                              p_agent_id   IN NUMBER,
                              p_agent_name IN VARCHAR2) IS

    l_buyer NUMBER := 0;
    l_emp   NUMBER := 0;
    l_step VARCHAR2(50);

  BEGIN
    SELECT COUNT(1)
    INTO   l_emp
    FROM   per_all_people_f papf
    WHERE  papf.person_id = p_agent_id
    AND    SYSDATE BETWEEN nvl(papf.effective_start_date, SYSDATE) AND
           nvl(papf.effective_end_date, SYSDATE);

    SELECT COUNT(1)
    INTO   l_buyer
    FROM   po_agents pa
    WHERE  pa.agent_id = p_agent_id
    AND    SYSDATE BETWEEN nvl(pa.start_date_active, SYSDATE) AND
           nvl(pa.end_date_active, SYSDATE);

   BEGIN
    IF l_buyer > 0 AND l_emp > 0 THEN
    l_step := 'Update quotation hdr table with agent_name';
      UPDATE xxs3_ptp_quotation_hdr
      SET    s3_agent_name = p_agent_name
      WHERE  xx_po_header_id = p_id;
    ELSE
    l_step := 'Update quotation hdr table with default agent_name';
      UPDATE xxs3_ptp_quotation_hdr
      SET    s3_agent_name = 'Buyer, Stratasys'
      WHERE  xx_po_header_id = p_id;
    END IF;
   EXCEPTION
    WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during staging table DML for xx_po_header_id = '
                          ||p_id|| 'at step: '||l_step||chr(10) || SQLCODE || chr(10) || SQLERRM);
   END;

    COMMIT;

  END update_agent_name;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update vendor_name
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_vendor_name(p_id          IN NUMBER,
                               p_vendor_name IN VARCHAR2,
                               p_entity      IN VARCHAR2) IS

    l_error_msg VARCHAR2(2000);

  BEGIN

    IF regexp_like(p_vendor_name, '[A-Za-z]', 'i') THEN
      IF p_entity = 'SUPPLIER' THEN
        BEGIN
          UPDATE xxs3_ptp_suppliers
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'Inc\.|INC', 'Inc'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_id = p_id
          AND    regexp_like(p_vendor_name, 'Inc\.|INC');

          UPDATE xxs3_ptp_suppliers
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'Corp\.|CORP', 'Corp'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_id = p_id
          AND    regexp_like(p_vendor_name, 'Corp\.|CORP');

          UPDATE xxs3_ptp_suppliers
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'LLC\.', 'LLC'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_id = p_id
          AND    regexp_like(p_vendor_name, 'LLC\.');

          UPDATE xxs3_ptp_suppliers
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'Ltd\.|LTD\.|LTD', 'Ltd'), --LTD\. is new rule
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_id = p_id
          AND    regexp_like(p_vendor_name, 'Ltd\.|LTD\.|LTD');

          UPDATE xxs3_ptp_suppliers
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'P\.O\.', 'PO'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_id = p_id
          AND    regexp_like(p_vendor_name, 'P\.O\.');

          UPDATE xxs3_ptp_suppliers
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'A\.P\.|A/P', 'AP'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_id = p_id
          AND    regexp_like(p_vendor_name, 'A\.P\.|A/P');

          UPDATE xxs3_ptp_suppliers
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'CO\.|Co\.', 'Company'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_id = p_id
          AND    regexp_like(p_vendor_name, 'CO\.|Co\.');

          UPDATE xxs3_ptp_suppliers
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'A\.R\.|A/R', 'AR'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_id = p_id
          AND    regexp_like(p_vendor_name, 'A\.R\.|A/R');

        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'UNEXPECTED ERROR on Vendor Name update : ' ||
                           SQLERRM;

            UPDATE xxs3_ptp_suppliers
            SET    cleanse_status = 'FAIL',
                   cleanse_error  = cleanse_error || '' || '' || l_error_msg
            WHERE  xx_vendor_id = p_id;
        END;
      ELSIF p_entity = 'SITE' THEN
        BEGIN
          UPDATE xxs3_ptp_suppliers_sites
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'Inc\.|INC', 'Inc'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_site_id = p_id
          AND    regexp_like(p_vendor_name, 'Inc\.|INC');

          UPDATE xxs3_ptp_suppliers_sites
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'Corp\.|CORP', 'Corp'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_site_id = p_id
          AND    regexp_like(p_vendor_name, 'Corp\.|CORP');

          UPDATE xxs3_ptp_suppliers_sites
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'LLC\.', 'LLC'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_site_id = p_id
          AND    regexp_like(p_vendor_name, 'LLC\.');

          UPDATE xxs3_ptp_suppliers_sites
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'Ltd\.|LTD|LTD\.', 'Ltd'), --LTD\. is new rule
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_site_id = p_id
          AND    regexp_like(p_vendor_name, 'Ltd\.|LTD');

          UPDATE xxs3_ptp_suppliers_sites
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'P\.O\.', 'PO'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_site_id = p_id
          AND    regexp_like(p_vendor_name, 'P\.O\.');

          UPDATE xxs3_ptp_suppliers_sites
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'A\.P\.|A/P', 'AP'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_site_id = p_id
          AND    regexp_like(p_vendor_name, 'A\.P\.|A/P');

          UPDATE xxs3_ptp_suppliers_sites
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'CO\.|Co\.', 'Company'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_site_id = p_id
          AND    regexp_like(p_vendor_name, 'CO\.|Co\.');

          UPDATE xxs3_ptp_suppliers_sites
          SET    s3_vendor_name = regexp_replace(p_vendor_name, 'A\.R\.|A/R', 'AR'),
                 cleanse_status = 'PASS'
          WHERE  xx_vendor_site_id = p_id
          AND    regexp_like(p_vendor_name, 'A\.R\.|A/R');

        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'UNEXPECTED ERROR on Vendor Name update : ' ||
                           SQLERRM;

            UPDATE xxs3_ptp_suppliers_sites
            SET    cleanse_status = 'FAIL',
                   cleanse_error  = cleanse_error || '' || '' || l_error_msg
            WHERE  xx_vendor_site_id = p_id;
        END;

      END IF;
    END IF;

  END update_vendor_name;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update alternate vendor_name
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_vendor_name_alt(p_id              IN NUMBER,
                                   p_alt_vendor_name IN VARCHAR2,
                                   p_entity          IN VARCHAR2) IS

    l_error_msg VARCHAR2(2000);

  BEGIN

    IF regexp_like(p_alt_vendor_name, '[A-Za-z]', 'i') THEN

      BEGIN
        UPDATE xxs3_ptp_suppliers
        SET    s3_vendor_name_alt = regexp_replace(p_alt_vendor_name, 'Inc\.|INC', 'Inc'),
               cleanse_status     = 'PASS'
        WHERE  xx_vendor_id = p_id
        AND    regexp_like(p_alt_vendor_name, 'Inc\.|INC');

        UPDATE xxs3_ptp_suppliers
        SET    s3_vendor_name_alt = regexp_replace(p_alt_vendor_name, 'Corp\.|CORP', 'Corp'),
               cleanse_status     = 'PASS'
        WHERE  xx_vendor_id = p_id
        AND    regexp_like(p_alt_vendor_name, 'Corp\.|CORP');

        UPDATE xxs3_ptp_suppliers
        SET    s3_vendor_name_alt = regexp_replace(p_alt_vendor_name, 'LLC\.', 'LLC'),
               cleanse_status     = 'PASS'
        WHERE  xx_vendor_id = p_id
        AND    regexp_like(p_alt_vendor_name, 'LLC\.');

        UPDATE xxs3_ptp_suppliers
        SET    s3_vendor_name_alt = regexp_replace(p_alt_vendor_name, 'Ltd\.|LTD\.|LTD', 'Ltd'),
               cleanse_status     = 'PASS'
        WHERE  xx_vendor_id = p_id
        AND    regexp_like(p_alt_vendor_name, 'Ltd\.|LTD\.|LTD');

        UPDATE xxs3_ptp_suppliers
        SET    s3_vendor_name_alt = regexp_replace(p_alt_vendor_name, 'P\.O\.', 'PO'),
               cleanse_status     = 'PASS'
        WHERE  xx_vendor_id = p_id
        AND    regexp_like(p_alt_vendor_name, 'P\.O\.');

        UPDATE xxs3_ptp_suppliers
        SET    s3_vendor_name_alt = regexp_replace(p_alt_vendor_name, 'A\.P\.|A/P', 'AP'),
               cleanse_status     = 'PASS'
        WHERE  xx_vendor_id = p_id
        AND    regexp_like(p_alt_vendor_name, 'A\.P\.|A/P');

        UPDATE xxs3_ptp_suppliers
        SET    s3_vendor_name_alt = regexp_replace(p_alt_vendor_name, 'A\.R\.|A/R', 'AR'),
               cleanse_status     = 'PASS'
        WHERE  xx_vendor_id = p_id
        AND    regexp_like(p_alt_vendor_name, 'A\.R\.|A/R');

      EXCEPTION
        WHEN OTHERS THEN
          l_error_msg := 'UNEXPECTED ERROR on Alternate Vendor Name update : ' ||
                         SQLERRM;

          UPDATE xxs3_ptp_suppliers
          SET    cleanse_status = 'FAIL',
                 cleanse_error  = cleanse_error || '' || '' || l_error_msg
          WHERE  xx_vendor_id = p_id;
      END;
    END IF;
  END update_vendor_name_alt;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update match_option
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  09/08/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_match_option(p_id IN NUMBER /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               p_entity IN VARCHAR2*/) IS

    l_error_msg VARCHAR2(2000);

  BEGIN

    UPDATE xxs3_ptp_suppliers
    SET    s3_match_option = 'P',
           cleanse_status  = 'PASS'
    WHERE  xx_vendor_id = p_id;

    UPDATE xxs3_ptp_suppliers
    SET    s3_match_option = 'P'
    WHERE  s3_match_option IS NULL;

  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'UNEXPECTED ERROR on Match option update : ' ||
                     SQLERRM;

      UPDATE xxs3_ptp_suppliers
      SET    cleanse_status = 'FAIL',
             cleanse_error  = cleanse_error || '' || '' || l_error_msg
      WHERE  xx_vendor_id = p_id;

  END update_match_option;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update vendor_name
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_address(p_id      IN NUMBER,
                           p_address IN VARCHAR2,
                           p_entity  IN VARCHAR2) IS

    l_error_msg VARCHAR2(2000);

  BEGIN

    IF regexp_like(p_address, '[A-Za-z]', 'i') THEN
      IF p_entity = 'ADDRESS_LINE1' THEN
        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line1 = regexp_replace(p_address, 'Inc\.|INC', 'Inc'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'Inc\.|INC');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line1 = regexp_replace(p_address, 'Corp\.|CORP', 'Corp'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'Corp\.|CORP');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line1 = regexp_replace(p_address, 'LLC\.', 'LLC'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'LLC\.');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line1 = regexp_replace(p_address, 'Ltd\.|LTD\.|LTD', 'Ltd'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'Ltd\.|LTD\.|LTD');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line1 = regexp_replace(p_address, 'P\.O\.', 'PO'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'P\.O\.');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line1 = regexp_replace(p_address, 'A\.P\.|A/P', 'AP'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'A\.P\.|A/P');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line1 = regexp_replace(p_address, 'CO\.|Co\.', 'Company'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'CO\.|Co\.');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line1 = regexp_replace(p_address, 'A\.R\.|A/R', 'AR'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'A\.R\.|A/R');

      ELSIF p_entity = 'ADDRESS_LINE2' THEN
        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line2 = regexp_replace(p_address, 'Inc\.|INC', 'Inc'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'Inc\.|INC');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line2 = regexp_replace(p_address, 'Corp\.|CORP', 'Corp'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'Corp\.|CORP');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line2 = regexp_replace(p_address, 'LLC\.', 'LLC'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'LLC\.');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line2 = regexp_replace(p_address, 'Ltd\.|LTD\.|LTD', 'Ltd'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'Ltd\.|LTD\.|LTD');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line2 = regexp_replace(p_address, 'P\.O\.', 'PO'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'P\.O\.');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line2 = regexp_replace(p_address, 'A\.P\.|A/P', 'AP'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'A\.P\.|A/P');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line1 = regexp_replace(p_address, 'CO\.|Co\.', 'Company'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'CO\.|Co\.');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line2 = regexp_replace(p_address, 'A\.R\.|A/R', 'AR'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'A\.R\.|A/R');

      ELSIF p_entity = 'ADDRESS_LINE3' THEN
        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line3 = regexp_replace(p_address, 'Inc\.|INC', 'Inc'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'Inc\.|INC');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line3 = regexp_replace(p_address, 'Corp\.|CORP', 'Corp'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'Corp\.|CORP');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line3 = regexp_replace(p_address, 'LLC\.', 'LLC'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'LLC\.');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line3 = regexp_replace(p_address, 'Ltd\.|LTD\.|LTD', 'Ltd'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'Ltd\.|LTD\.|LTD');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line3 = regexp_replace(p_address, 'P\.O\.', 'PO'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'P\.O\.');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line3 = regexp_replace(p_address, 'A\.P\.|A/P', 'AP'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'A\.P\.|A/P');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line1 = regexp_replace(p_address, 'CO\.|Co\.', 'Company'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'CO\.|Co\.');

        UPDATE xxs3_ptp_suppliers_sites
        SET    s3_address_line3 = regexp_replace(p_address, 'A\.R\.|A/R', 'AR'),
               cleanse_status   = 'PASS'
        WHERE  xx_vendor_site_id = p_id
        AND    regexp_like(p_address, 'A\.R\.|A/R');

      END IF;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'UNEXPECTED ERROR on ' || p_entity || ' update : ' ||
                     SQLERRM;

      UPDATE xxs3_ptp_suppliers_sites
      SET    cleanse_status = 'FAIL',
             cleanse_error  = cleanse_error || '' || '' || l_error_msg
      WHERE  xx_vendor_site_id = p_id;

  END update_address;

  --- --------------------------------------------------------------------------------------------
  -- Purpose: Update AWT
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  01/08/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_awt(p_id IN NUMBER) IS

    l_error_msg VARCHAR2(4000);

  BEGIN

    UPDATE xxs3_ptp_suppliers
    SET    s3_invoice_withhlding_tax_grp = NULL
    WHERE  xx_vendor_id = p_id;
    /*ELSE
      UPDATE XXS3_PTP_SUPPLIERS
      SET S3_INVOICE_WITHHLDING_TAX_GRP = p_old_awt
      WHERE xx_vendor_id = p_id;
    END IF;*/

  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'UNEXPECTED ERROR : ' || SQLERRM;

      UPDATE xxs3_ptp_suppliers
      SET    cleanse_status = 'FAIL',
             cleanse_error  = cleanse_error || ':' || '' || l_error_msg
      WHERE  xx_vendor_id = p_id;

  END update_awt;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update vendor_name
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_legacy_values(p_id              IN NUMBER,
                                 p_old_awt         IN VARCHAR2,
                                 p_vendor_name     IN VARCHAR2,
                                 p_vendor_name_alt IN VARCHAR2,
                                 --p_terms IN VARCHAR2,
                                 p_add1   IN VARCHAR2,
                                 p_add2   IN VARCHAR2,
                                 p_add3   IN VARCHAR2,
                                 p_entity IN VARCHAR2) IS

  BEGIN

    IF p_entity = 'SUPPLIER' THEN

      UPDATE xxs3_ptp_suppliers
      SET    s3_vendor_name = p_vendor_name
      WHERE  s3_vendor_name IS NULL
      AND    xx_vendor_id = p_id;

      UPDATE xxs3_ptp_suppliers
      SET    s3_vendor_name_alt = p_vendor_name_alt
      WHERE  s3_vendor_name_alt IS NULL
      AND    xx_vendor_id = p_id;

      UPDATE xxs3_ptp_suppliers
      SET    s3_invoice_withhlding_tax_grp = p_old_awt
      WHERE  xx_vendor_id = p_id;

      /* UPDATE xxs3_ptp_suppliers
      SET s3_terms = p_terms
      WHERE s3_terms IS NULL
      AND xx_vendor_id = p_id;*/

    ELSIF p_entity = 'SITE' THEN

      UPDATE xxs3_ptp_suppliers_sites
      SET    s3_vendor_name = p_vendor_name
      WHERE  s3_vendor_name IS NULL
      AND    xx_vendor_site_id = p_id;

      /*UPDATE xxs3_ptp_suppliers_sites
      SET s3_terms = p_terms
      WHERE s3_terms IS NULL
      AND xx_vendor_site_id = p_id;*/

      UPDATE xxs3_ptp_suppliers_sites
      SET    s3_address_line1 = p_add1
      WHERE  s3_address_line1 IS NULL
      AND    xx_vendor_site_id = p_id;

      UPDATE xxs3_ptp_suppliers_sites
      SET    s3_address_line2 = p_add2
      WHERE  s3_address_line2 IS NULL
      AND    xx_vendor_site_id = p_id;

      UPDATE xxs3_ptp_suppliers_sites
      SET    s3_address_line3 = p_add3
      WHERE  s3_address_line3 IS NULL
      AND    xx_vendor_site_id = p_id;

    END IF;

  END update_legacy_values;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of CS track
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  --  1.1  07/12/2016  Debarati Banerjee            New DQ Rules added
  -----------------------------------------------------------------------------------------------

  PROCEDURE quality_check_supplier IS

    l_uom             VARCHAR2(10);
    l_quantity        VARCHAR2(10);
    l_attribute3      VARCHAR2(10);
    l_attribute7      VARCHAR2(10);
    l_attribute6      VARCHAR2(10);
    l_attribute4      VARCHAR2(10);
    l_attribute5      VARCHAR2(10);
    l_attribute10     VARCHAR2(10);
    l_attribute8      VARCHAR2(10);
    l_attribute11     VARCHAR2(10);
    l_attribute16     VARCHAR2(10);
    l_status          VARCHAR2(10) := 'SUCCESS';
    l_check_rule      VARCHAR2(10) := 'TRUE';
    l_check_rule_acct BOOLEAN;

    CURSOR cur_ptp IS
      SELECT *
      FROM   xxs3_ptp_suppliers
      WHERE  process_flag = 'N'
      AND    nvl(cleanse_status, 'PASS') <> 'FAIL';

    /*CURSOR cur_cs_relationship IS
    SELECT * from XXS3_CS_RELATIONSHIP;

    CURSOR cur_cs_attributes IS
    SELECT * from XXS3_CS_ATTRIBUTES;*/

  BEGIN
    FOR i IN cur_ptp LOOP
      l_status := 'SUCCESS';

      IF i.s3_vendor_name IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_001(i.s3_vendor_name);

        IF l_check_rule = 'FALSE' THEN
          insert_update_supplier_dq(i.xx_vendor_id, 'EQT_001:Standardize Organization Name', 'Non-std Org Name for field vendor_name');
          l_status := 'ERR';
        END IF;
      ELSE
        l_check_rule := xxs3_dq_util_pkg.eqt_001(i.vendor_name);

        IF l_check_rule = 'FALSE' THEN
          insert_update_supplier_dq(i.xx_vendor_id, 'EQT_001:Standardize Organization Name', 'Non-std Org Name for field vendor_name');
          l_status := 'ERR';
        END IF;
      END IF;
      
      --New change as per FDD update of 01-Dec
      
      IF i.s3_vendor_name_alt IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_001(i.s3_vendor_name_alt);

        IF l_check_rule = 'FALSE' THEN
          insert_update_supplier_dq(i.xx_vendor_id, 'EQT_001:Standardize Organization Name', 'Non-std Org Name for field vendor_name_alt');
          l_status := 'ERR';
        END IF;
      ELSE
       IF i.vendor_name_alt IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_001(i.vendor_name_alt);

        IF l_check_rule = 'FALSE' THEN
          insert_update_supplier_dq(i.xx_vendor_id, 'EQT_001:Standardize Organization Name', 'Non-std Org Name for field vendor_name_alt');
          l_status := 'ERR';
        END IF;
       END IF;
      END IF;
      
      --New change as per FDD update of 01-Dec

      IF i.vendor_type_lookup_code = 'EMPLOYEE' THEN
        IF i.employee_id IS NULL THEN
          insert_update_supplier_dq(i.xx_vendor_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                     'for field ' ||
                                     'employee_id');
          l_status := 'ERR';
        ELSE
          l_check_rule := xxs3_dq_util_pkg.eqt_002(i.vendor_name);

          IF l_check_rule = 'FALSE' THEN
            insert_update_supplier_dq(i.xx_vendor_id, 'EQT_002:Standardize Person Name', 'Non-std Person Name for field vendor_name');
            l_status := 'ERR';
          END IF;
          
          --New change as per FDD update of 01-Dec
         IF i.vendor_name_alt IS NOT NULL THEN
          l_check_rule := xxs3_dq_util_pkg.eqt_002(i.vendor_name_alt);

          IF l_check_rule = 'FALSE' THEN
            insert_update_supplier_dq(i.xx_vendor_id, 'EQT_002:Standardize Person Name', 'Non-std Person Name for field vendor_name_alt ');
            l_status := 'ERR';
          END IF;
         END IF; 
          --New change as per FDD update of 01-Dec
        END IF;
      END IF;

      IF i.vendor_type_lookup_code IS NULL THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                   'for field ' ||
                                   'VENDOR_TYPE_LOOKUP_CODE');
        l_status := 'ERR';
      END IF;

      IF i.vendor_type_lookup_code = 'EMPLOYEE' THEN
        IF i.employee_id IS NULL OR i.pay_group_lookup_code <> 'EMPLOYEE' THEN
          insert_update_supplier_dq(i.xx_vendor_id, 'EQT-032 :Employee Vendor Type Pay Group Combo', 'Invalid Vendor Type Pay Group Combo');
          l_status := 'ERR';
        END IF;
      END IF;

      /*IF i.ONE_TIME_FLAG IS NULL THEN
       insert_update_supplier_dq(i.xx_vendor_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'ONE_TIME_FLAG');
         l_status := 'ERR';
      END IF;*/

      IF i.terms IS NULL THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                   'for field ' ||
                                   'TERMS');
        l_status := 'ERR';
      END IF;

      /*IF i.ALWAYS_TAKE_DISC_FLAG IS NULL THEN
       insert_update_supplier_dq(i.xx_vendor_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'ALWAYS_TAKE_DISC_FLAG');
         l_status := 'ERR';
      END IF;*/

      IF i.pay_date_basis_lookup_code IS NULL THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                   'for field ' ||
                                   'PAY_DATE_BASIS_LOOKUP_CODE');
        l_status := 'ERR';
      END IF;

      IF i.pay_group_lookup_code IS NULL THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                   'for field ' ||
                                   'PAY_GROUP_LOOKUP_CODE');
        l_status := 'ERR';
        --END IF;

      ELSIF i.pay_group_lookup_code NOT IN
            ('VENDOR', 'EMPLOYEE', 'RESELLER', 'REFUND') THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-033: Pay Group LOV', 'Invalid Pay Group' || '' ||
                                   'for field ' ||
                                   'PAY_GROUP_LOOKUP_CODE');
        l_status := 'ERR';
      END IF;
      
      ----New change as per FDD update of 01-Dec
      
      IF i.pay_group_lookup_code = 'RESELLER' THEN
        IF i.s3_terms <> 'IMMEDIATE' THEN
          insert_update_supplier_dq(i.xx_vendor_id, 'EQT-NEW: Invalid Terms', 'Invalid Terms for pay_group = RESELLER');
          
          l_status := 'ERR';
        END IF;         
      END IF;
      
      --New change as per FDD update of 01-Dec

      IF i.payment_priority <> 99 THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-034: Payment Priority US', 'Non Standard US Value');
        l_status := 'ERR';
      END IF;

      IF i.invoice_currency_code IS NULL THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                   'for field ' ||
                                   'PAY_GROUP_LOOKUP_CODE');
        l_status := 'ERR';
      END IF;

      IF i.payment_currency_code IS NULL THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                   'for field ' ||
                                   'PAY_GROUP_LOOKUP_CODE');
        l_status := 'ERR';
      END IF;

      IF i.hold_all_payments_flag <> 'N' THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-035:Always Equals N - US', 'Should be N');
        l_status := 'ERR';
      END IF;

      IF i.vendor_type_lookup_code <> 'EMPLOYEE' THEN
        IF i.organization_type_lookup_code IS NULL THEN
          insert_update_supplier_dq(i.xx_vendor_id, 'EQT-037:Organization Type Vendor Type Combo', 'Invalid Org Type Vendor Type Combo');
          l_status := 'ERR';
        END IF;
      END IF;

      /*IF i.WOMEN_OWNED_FLAG IS NULL THEN
       insert_update_supplier_dq(i.xx_vendor_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'WOMEN_OWNED_FLAG');
         l_status := 'ERR';
      END IF;

      IF i.SMALL_BUSINESS_FLAG IS NULL THEN
       insert_update_supplier_dq(i.xx_vendor_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'SMALL_BUSINESS_FLAG');
         l_status := 'ERR';
      END IF;

      IF i.HOLD_FLAG IS NULL THEN
         insert_update_supplier_dq(i.xx_vendor_id,
                      'EQT-028:Is Not Null',
                  'Missing value'||''||'for field '||'HOLD_FLAG');
         l_status := 'ERR';
       END IF;*/

      IF i.terms_date_basis <> 'Invoice' THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-038:Terms Date Basis US', 'Non Std US value' || '' ||
                                   'for field ' ||
                                   'HOLD_FLAG');
        l_status := 'ERR';
      END IF;

      /*IF i.INSPECTION_REQUIRED_FLAG IS NULL THEN
       insert_update_supplier_dq(i.xx_vendor_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'INSPECTION_REQUIRED_FLAG');
         l_status := 'ERR';
      END IF;

      IF i.RECEIPT_REQUIRED_FLAG IS NULL THEN
       insert_update_supplier_dq(i.xx_vendor_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'RECEIPT_REQUIRED_FLAG');
         l_status := 'ERR';
      END IF;*/

      IF i.hold_unmatched_invoices_flag <> 'N' THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-035:Always Equals N - US', 'Should be N' || '' ||
                                   'for field ' ||
                                   'HOLD_UNMATCHED_INVOICES_FLAG');
        l_status := 'ERR';
      END IF;

      IF i.exclude_freight_from_discount <> 'N' THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-035:Always Equals N - US', 'Should be N' || '' ||
                                   'for field ' ||
                                   'EXCLUDE_FREIGHT_FROM_DISCOUNT');
        l_status := 'ERR';
      END IF;

      IF i.allow_awt_flag <> 'N' THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-035:Always Equals N - US', 'Should be N' || '' ||
                                   'for field ' ||
                                   i.allow_awt_flag);
        l_status := 'ERR';
      END IF;

      /*IF i.MATCH_OPTION IS NULL THEN
       insert_update_supplier_dq(i.xx_vendor_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'MATCH_OPTION');
         l_status := 'ERR';
      --END IF;

      ELSIF i.MATCH_OPTION NOT IN ('P','R') THEN
       insert_update_supplier_dq(i.xx_vendor_id,
        'EQT-039:Match Option LOV',
        'Invalid or Missing Match Option'||''||'for field '||'MATCH_OPTION');
         l_status := 'ERR';
      END IF;*/

      IF i.s3_match_option <> 'P' THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT-073:Match Option Should equal P', 'Match Option Should equal P');
        l_status := 'ERR';
      END IF;

      /*IF i.CREATE_DEBIT_MEMO_FLAG IS NULL THEN
       insert_update_supplier_dq(i.xx_vendor_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'CREATE_DEBIT_MEMO_FLAG');
         l_status := 'ERR';
      END IF;  */

      l_check_rule_acct := xxs3_dq_util_pkg.eqt_030(i.accts_pay_code_combination_id);

      IF l_check_rule_acct = TRUE THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT_030:Should be NULL', 'Should be NULL');
        l_status := 'ERR';
      END IF;

      l_check_rule_acct := xxs3_dq_util_pkg.eqt_030(i.disc_lost_code_combination_id);

      IF l_check_rule_acct = TRUE THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT_030:Should be NULL', 'Should be NULL');
        l_status := 'ERR';
      END IF;

      l_check_rule_acct := xxs3_dq_util_pkg.eqt_030(i.disc_taken_code_combination_id);

      IF l_check_rule_acct = TRUE THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT_030:Should be NULL', 'Should be NULL');
        l_status := 'ERR';
      END IF;

      l_check_rule_acct := xxs3_dq_util_pkg.eqt_030(i.expense_code_combination_id);

      IF l_check_rule_acct = TRUE THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT_030:Should be NULL', 'Should be NULL');
        l_status := 'ERR';
      END IF;

      l_check_rule_acct := xxs3_dq_util_pkg.eqt_030(i.prepay_code_combination_id);

      IF l_check_rule_acct = TRUE THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT_030:Should be NULL', 'Should be NULL');
        l_status := 'ERR';
      END IF;

      l_check_rule_acct := xxs3_dq_util_pkg.eqt_030(i.future_dated_payment_ccid);

      IF l_check_rule_acct = TRUE THEN
        insert_update_supplier_dq(i.xx_vendor_id, 'EQT_030:Should be NULL', 'Should be NULL');
        l_status := 'ERR';
      END IF;

      IF l_status <> 'ERR' THEN
        UPDATE xxs3_ptp_suppliers
        SET    process_flag = 'Y'
        WHERE  xx_vendor_id = i.xx_vendor_id;
      END IF;

    -- Cleanse and Standardize Business Rules/Program Logic

    --update_vendor_name(i.xx_vendor_id,i.vendor_name,'SUPPLIER');

    END LOOP;

    COMMIT;

  END quality_check_supplier;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of Supplier sites
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE quality_check_supplier_site IS

    l_uom                VARCHAR2(10);
    l_quantity           VARCHAR2(10);
    l_attribute3         VARCHAR2(10);
    l_attribute7         VARCHAR2(10);
    l_attribute6         VARCHAR2(10);
    l_attribute4         VARCHAR2(10);
    l_attribute5         VARCHAR2(10);
    l_attribute10        VARCHAR2(10);
    l_attribute8         VARCHAR2(10);
    l_attribute11        VARCHAR2(10);
    l_attribute16        VARCHAR2(10);
    l_status             VARCHAR2(10) := 'SUCCESS';
    l_check_rule         VARCHAR2(10) := 'FALSE';
    l_check_rule_email   BOOLEAN := FALSE;
    l_check_rule_country VARCHAR2(10) := 'FALSE';

    CURSOR cur_ptp IS
      SELECT *
      FROM   xxs3_ptp_suppliers_sites
      WHERE  process_flag = 'N'
      AND    nvl(cleanse_status, 'PASS') <> 'FAIL';

  BEGIN
    FOR i IN cur_ptp LOOP
      l_status := 'SUCCESS';

      IF i.s3_vendor_name IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_001(i.s3_vendor_name);

        IF l_check_rule = 'FALSE' THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT_001:Standardize Organization Name', 'Non-std Org Name');
          l_status := 'ERR';
        END IF;
      ELSE
        l_check_rule := xxs3_dq_util_pkg.eqt_001(i.vendor_name);

        IF l_check_rule = 'FALSE' THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT_001:Standardize Organization Name', 'Non-std Org Name');
          l_status := 'ERR';
        END IF;
      END IF;

      IF i.vendor_type_lookup_code = 'EMPLOYEE' THEN

        l_check_rule := xxs3_dq_util_pkg.eqt_002(i.vendor_name);

        IF l_check_rule = 'FALSE' THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT_002:Standardize Person Name', 'Non-std Person Name');
          l_status := 'ERR';
        END IF;
      ELSE
        IF i.location_id IS NULL THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                 'for field ' ||
                                 'LOCATION_ID');
          l_status := 'ERR';
        END IF;

      END IF;

      IF i.terms IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'TERMS');
        l_status := 'ERR';
      END IF;

      IF i.pay_group_lookup_code IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'PAY_GROUP_LOOKUP_CODE');
        l_status := 'ERR';
      END IF;

      IF i.pay_date_basis_lookup_code IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'PAY_DATE_BASIS_LOOKUP_CODE');
        l_status := 'ERR';
      END IF;

      IF i.pay_group_lookup_code NOT IN
         ('VENDOR', 'EMPLOYEE', 'RESELLER', 'REFUND') THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-033: Pay Group LOV', 'Invalid Pay Group' || '' ||
                               'for field ' ||
                               'PAY_GROUP_LOOKUP_CODE');
        l_status := 'ERR';
      END IF;
      
        ----New change as per FDD update of 01-Dec
      
      IF i.pay_group_lookup_code = 'RESELLER' AND i.terms <> 'Immediate' THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT-NEW: Invalid Terms', 'Invalid Terms for pay_group = RESELLER');
          
          l_status := 'ERR';
      END IF;
      
      --New change as per FDD update of 01-Dec

      IF i.payment_priority <> 99 THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-034: Payment Priority US', 'Non Standard US Value');
        l_status := 'ERR';
      END IF;

      IF i.invoice_currency_code IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'INVOICE_CURRENCY_CODE');
        l_status := 'ERR';
      END IF;

      IF i.payment_currency_code IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'PAY_GROUP_LOOKUP_CODE');
        l_status := 'ERR';
      END IF;

      IF i.hold_all_payments_flag <> 'N' THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-035:Always Equals N - US', 'Should be N');
        l_status := 'ERR';
      END IF;

      /*IF i.HOLD_FUTURE_PAYMENTS_FLAG IS NULL THEN
       insert_update_site_dq(i.xx_vendor_site_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'HOLD_FUTURE_PAYMENTS_FLAG');
         l_status := 'ERR';
      END IF;*/

      IF i.hold_all_payments_flag IS NOT NULL AND
         i.hold_future_payments_flag IS NOT NULL THEN

        l_check_rule := xxs3_dq_util_pkg.eqt_036(i.hold_all_payments_flag, i.hold_future_payments_flag, i.hold_reason);

        IF l_check_rule = 'FALSE' THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT_036:Hold Flag Reason Code Combo', 'Invalid Hold Flag Reason Code Combo');
          l_status := 'ERR';
        END IF;
      END IF;

      IF i.hold_unmatched_invoices_flag <> 'N' THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-035:Always Equals N - US', 'Should be N' || '' ||
                               'for field ' ||
                               'HOLD_UNMATCHED_INVOICES_FLAG');
        l_status := 'ERR';
      END IF;

      IF i.exclude_freight_from_discount <> 'N' THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-035:Always Equals N - US', 'Should be N' || '' ||
                               'for field ' ||
                               'EXCLUDE_FREIGHT_FROM_DISCOUNT');
        l_status := 'ERR';
      END IF;

      IF i.allow_awt_flag <> 'N' THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-035:Always Equals N - US', 'Should be N' || '' ||
                               'for field ' ||
                               'ALLOW_AWT_FLAG');
        l_status := 'ERR';
      END IF;

      /*IF i.CREATE_DEBIT_MEMO_FLAG IS NULL THEN
       insert_update_site_dq(i.xx_vendor_site_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'CREATE_DEBIT_MEMO_FLAG');
         l_status := 'ERR';
      END IF;*/

      /*IF i.MATCH_OPTION IS NULL THEN
         insert_update_site_dq(i.xx_vendor_site_id,
          'EQT-028:Is Not Null',
          'Missing value'||''||'for field '||'MATCH_OPTION');
           l_status := 'ERR';
      ELSIF i.MATCH_OPTION NOT IN ('P','R') THEN
       insert_update_site_dq(i.xx_vendor_site_id,
        'EQT-039:Match Option LOV',
        'Invalid or Missing Match Option'||''||'for field '||'MATCH_OPTION');
         l_status := 'ERR';
      END IF;*/

      IF i.match_option <> 'P' THEN
        insert_update_supplier_dq(i.xx_vendor_site_id, 'EQT-073:Match Option Should equal P', 'Match Option Should equal P');
        l_status := 'ERR';
      END IF;

      /*IF i.PURCHASING_SITE_FLAG IS NULL THEN
       insert_update_site_dq(i.xx_vendor_site_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'PURCHASING_SITE_FLAG');
         l_status := 'ERR';
      END IF;*/

      IF i.attention_ar_flag <> 'N' THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-035:Always Equals N - US', 'Should be N' || '' ||
                               'for field ' ||
                               'ATTENTION_AR_FLAG');
        l_status := 'ERR';
      END IF;

      IF i.vendor_type_lookup_code <> 'EMPLOYEE' THEN
        IF i.address_line1 IS NULL THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT-020:Address1 Required', 'Missing Address1');
          l_status := 'ERR';
          --END IF;
        ELSE
          IF i.s3_address_line1 IS NOT NULL THEN
            l_check_rule := xxs3_dq_util_pkg.eqt_004(i.s3_address_line1);

            IF l_check_rule = 'FALSE' THEN
              insert_update_site_dq(i.xx_vendor_site_id, 'EQT_004: Standardize Address Line', 'Non-std Address Line' || '' ||
                                     'for field ' ||
                                     'ADDRESS_LINE1');
              l_status := 'ERR';
            END IF;
          ELSE
            l_check_rule := xxs3_dq_util_pkg.eqt_004(i.address_line1);

            IF l_check_rule = 'FALSE' THEN
              insert_update_site_dq(i.xx_vendor_site_id, 'EQT_004: Standardize Address Line', 'Non-std Address Line' || '' ||
                                     'for field ' ||
                                     'ADDRESS_LINE1');
              l_status := 'ERR';
            END IF;
          END IF;
        END IF;
      END IF;

      IF i.address_line2 IS NOT NULL THEN
        IF i.s3_address_line2 IS NOT NULL THEN
          l_check_rule := xxs3_dq_util_pkg.eqt_004(i.s3_address_line2);

          IF l_check_rule = 'FALSE' THEN
            insert_update_site_dq(i.xx_vendor_site_id, 'EQT_004: Standardize Address Line', 'Non-std Address Line' || '' ||
                                   'for field ' ||
                                   'ADDRESS_LINE2');
            l_status := 'ERR';
          END IF;
        ELSE
          l_check_rule := xxs3_dq_util_pkg.eqt_004(i.address_line2);

          IF l_check_rule = 'FALSE' THEN
            insert_update_site_dq(i.xx_vendor_site_id, 'EQT_004: Standardize Address Line', 'Non-std Address Line' || '' ||
                                   'for field ' ||
                                   'ADDRESS_LINE2');
            l_status := 'ERR';
          END IF;
        END IF;
      END IF;

      IF i.address_line3 IS NOT NULL THEN
        IF i.s3_address_line3 IS NOT NULL THEN
          l_check_rule := xxs3_dq_util_pkg.eqt_004(i.s3_address_line3);

          IF l_check_rule = 'FALSE' THEN
            insert_update_site_dq(i.xx_vendor_site_id, 'EQT_004: Standardize Address Line', 'Non-std Address Line' || '' ||
                                   'for field ' ||
                                   'ADDRESS_LINE3');
            l_status := 'ERR';
          END IF;
        ELSE
          l_check_rule := xxs3_dq_util_pkg.eqt_004(i.address_line3);

          IF l_check_rule = 'FALSE' THEN
            insert_update_site_dq(i.xx_vendor_site_id, 'EQT_004: Standardize Address Line', 'Non-std Address Line' || '' ||
                                   'for field ' ||
                                   'ADDRESS_LINE3');
            l_status := 'ERR';
          END IF;
        END IF;
      END IF;

      IF i.city IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-015:City Required', 'Missing City');
        l_status := 'ERR';

      ELSE
        l_check_rule := xxs3_dq_util_pkg.eqt_005(i.city);
        IF l_check_rule = 'FALSE' THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT_005: Standardize City', 'Non-std City');
          l_status := 'ERR';
        END IF;
      END IF;

      IF i.zip IS NULL THEN
        insert_update_site_reject_dq(i.xx_vendor_site_id, 'EQT-016:Postal Code Required', 'Missing Postal Code');
        l_status := 'ERR';
      END IF;

      IF i.country IS NULL THEN
        insert_update_site_reject_dq(i.xx_vendor_site_id, 'EQT-012:Country Required', 'Missing Country Code');
        l_status := 'ERR';

      ELSE
        IF length(i.country) = 2 THEN
          l_check_rule_country := xxs3_dq_util_pkg.eqt_008(i.country);
          IF l_check_rule_country = 'FALSE' THEN
            insert_update_site_reject_dq(i.xx_vendor_site_id, 'EQT_008: Standardize Country Code', 'Non-std Country Code');
          END IF;
        ELSIF length(i.country) > 2 THEN
          l_check_rule_country := xxs3_dq_util_pkg.eqt_011(i.country);

          IF l_check_rule_country = 'FALSE' THEN
            insert_update_site_reject_dq(i.xx_vendor_site_id, 'EQT_011: Standardize Country Name', 'Non-std Country Name');
          END IF;
        END IF;

        IF l_check_rule_country = 'TRUE' THEN

          --check state if country lookup is available
          IF i.state IS NOT NULL THEN
            IF length(i.state) = 2 THEN
              l_check_rule := xxs3_dq_util_pkg.eqt_006(i.state, i.country);
              IF l_check_rule = 'FALSE' THEN
                insert_update_site_dq(i.xx_vendor_site_id, 'EQT_006: Standardize State Code', 'Non-std State Code');
              END IF;
            ELSIF length(i.state) > 2 THEN
              l_check_rule := xxs3_dq_util_pkg.eqt_009(i.state, i.country);

              IF l_check_rule = 'FALSE' THEN
                insert_update_site_dq(i.xx_vendor_site_id, 'EQT_009: Standardize State Name', 'Non-std State Name');
              END IF;
            END IF;
          END IF;
          ----check province if country lookup is available

          IF i.province IS NOT NULL THEN
            IF length(i.province) = 2 THEN
              l_check_rule := xxs3_dq_util_pkg.eqt_007(i.province, i.country);
              IF l_check_rule = 'FALSE' THEN
                insert_update_site_dq(i.xx_vendor_site_id, 'EQT_007: Standardize Province Code', 'Non-std Province Code');
              END IF;
            ELSIF length(i.province) > 2 THEN
              l_check_rule := xxs3_dq_util_pkg.eqt_010(i.province, i.country);

              IF l_check_rule = 'FALSE' THEN
                insert_update_site_dq(i.xx_vendor_site_id, 'EQT_010: Standardize Province Name', 'Non-std Province Name');
              END IF;
            END IF;
          END IF;
        END IF;
      END IF;
      IF i.ship_to_location_id IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'SHIP_TO_LOCATION_ID');
        l_status := 'ERR';
      END IF;

      IF i.bill_to_location_id IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'BILL_TO_LOCATION_ID');
        l_status := 'ERR';
      END IF;

      IF i.ship_via_lookup_code IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_040(i.ship_via_lookup_code);

        IF l_check_rule = 'FALSE' THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT-040: Should Not Contain %', 'Does not contain "%"');
          l_status := 'ERR';
        END IF;
      END IF;

      IF i.terms_date_basis <> 'Invoice' THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-038:Terms Date Basis US', 'Non Std US value');
        l_status := 'ERR';
      END IF;

      IF i.liability_account IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'LIABILITY_ACCOUNT');
        l_status := 'ERR';
      END IF;

      IF i.liability_acct_segment4 IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_076(i.liability_acct_segment4);

        IF l_check_rule = 'FALSE' THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT_076:Valid supplier liability account (segment 4)', 'Invalid supplier liability account (segment 4)');
          l_status := 'ERR';
        END IF;
      END IF;

      IF i.pay_group_lookup_code IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'PAY_GROUP_LOOKUP_CODE');
        l_status := 'ERR';
      END IF;

      IF i.prepayment_acct_segment4 IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_077(i.prepayment_acct_segment4, i.pay_group_lookup_code);

        IF l_check_rule = 'FALSE' THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT_077:Valid prepayment account (segment 4)', 'Invalid pre-payment account (segment 4)');
          l_status := 'ERR';
        END IF;
      END IF;

      IF i.payment_priority <> 99 THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-034: Payment Priority US', 'Non Standard US Value');
        l_status := 'ERR';
      END IF;

      IF i.terms IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'TERMS');
        l_status := 'ERR';
      END IF;

      IF i.pay_date_basis_lookup_code IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'PAY_DATE_BASIS_LOOKUP_CODE');
        l_status := 'ERR';
      ELSIF i.pay_date_basis_lookup_code NOT IN ('DUE', 'DISCOUNT') THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-041:Pay Date Basis LOV', 'Invalid Pay Date Basis');
        l_status := 'ERR';
      END IF;
      /*
      IF i.ALWAYS_TAKE_DISC_FLAG IS NULL THEN
       insert_update_site_dq(i.xx_vendor_site_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'ALWAYS_TAKE_DISC_FLAG');
         l_status := 'ERR';
      END IF;*/

      IF i.invoice_currency_code IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'INVOICE_CURRENCY_CODE');
        l_status := 'ERR';
      END IF;

      IF i.payment_currency_code IS NULL THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                               'for field ' ||
                               'PAYMENT_CURRENCY_CODE');
        l_status := 'ERR';
      END IF;

      /*IF i.HOLD_FUTURE_PAYMENTS_FLAG IS NULL THEN
       insert_update_site_dq(i.xx_vendor_site_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'HOLD_FUTURE_PAYMENTS_FLAG');
         l_status := 'ERR';
      END IF;
      */

      IF i.hold_unmatched_invoices_flag <> 'N' THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-035:Always Equals N - US', 'Should be N' || '' ||
                               'for field ' ||
                               'HOLD_UNMATCHED_INVOICES_FLAG');
        l_status := 'ERR';
      END IF;

      /*IF i.TAX_REPORTING_SITE_FLAG IS NULL THEN
       insert_update_site_dq(i.xx_vendor_site_id,
        'EQT-028:Is Not Null',
        'Missing value'||''||'for field '||'TAX_REPORTING_SITE_FLAG');
         l_status := 'ERR';
      END IF;  */

      IF i.address_line4 = '** AVALARA UNABLE TO VALIDATE ADDRESS **' THEN
        insert_update_site_dq(i.xx_vendor_site_id, 'EQT-013: Address4 Avalara Error', 'Avalara Error');
        l_status := 'ERR';
      END IF;

      IF i.email_address IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_021(i.email_address);

        IF l_check_rule = 'FALSE' THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT-021: Email Address', 'Invalid email format');
          l_status := 'ERR';
        END IF;
      END IF;

      IF i.prepayment_acct_segment5 IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_183(i.prepayment_acct_segment5);

        IF l_check_rule = 'FALSE' THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT_183:Segment 5 Should be 0000', 'Segment 5 Should be 0000');
          l_status := 'ERR';
        END IF;
      END IF;

      IF i.liability_acct_segment5 IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_183(i.liability_acct_segment5);

        IF l_check_rule = 'FALSE' THEN
          insert_update_site_dq(i.xx_vendor_site_id, 'EQT_183:Segment 5 Should be 0000', 'Segment 5 Should be 0000');
          l_status := 'ERR';
        END IF;
      END IF;

      /*IF i.email_format IS NOT NULL THEN
         l_check_rule_email    := xxs3_dq_util_pkg.eqt_023(i.email_format,i.email_address);

            IF l_check_rule_email = FALSE THEN
              insert_update_site_dq(i.xx_vendor_site_id,
                     'EQT-022: Email Format2',
                     'Invalid Email Address-Email Format combo');
              l_status := 'ERR';
            END IF;
      END IF;*/

      IF l_status <> 'ERR' THEN
        UPDATE xxs3_ptp_suppliers_sites
        SET    process_flag = 'Y'
        WHERE  xx_vendor_site_id = i.xx_vendor_site_id;
      END IF;
    END LOOP;

    COMMIT;

  END quality_check_supplier_site;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of Supplier contacts
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  3/08/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE quality_check_supplier_cont IS

    l_status             VARCHAR2(10) := 'SUCCESS';
    l_check_rule         VARCHAR2(10) := 'FALSE';
    l_check_rule_email   BOOLEAN := FALSE;
    l_check_rule_country VARCHAR2(10) := 'FALSE';

    CURSOR cur_ptp IS
      SELECT *
      FROM   xxs3_ptp_suppliers_cont
      WHERE  process_flag = 'N';

  BEGIN
    FOR i IN cur_ptp LOOP
      l_status := 'SUCCESS';

      IF i.email_address IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_021(i.email_address);

        IF l_check_rule = 'FALSE' THEN
          insert_update_contact_dq(i.xx_vendor_contact_id, 'EQT-021: Email Address', 'Invalid email format');
          l_status := 'ERR';
        END IF;

        l_check_rule_email := xxs3_dq_util_pkg.eqt_022(i.email_format, i.email_address);

        IF l_check_rule_email = TRUE THEN
          insert_update_contact_dq(i.xx_vendor_contact_id, 'EQT-022: Email Format1', 'Invalid Email Address-Email Format combo');
          l_status := 'ERR';
        END IF;
      END IF;

      IF i.email_format IS NOT NULL THEN
        l_check_rule_email := xxs3_dq_util_pkg.eqt_023(i.email_format, i.email_address);

        IF l_check_rule_email = TRUE THEN
          insert_update_contact_dq(i.xx_vendor_contact_id, 'EQT-022: Email Format2', 'Invalid Email Address-Email Format combo');
          l_status := 'ERR';
        END IF;
      END IF;

      IF l_status <> 'ERR' THEN
        UPDATE xxs3_ptp_suppliers_cont
        SET    process_flag = 'Y'
        WHERE  xx_vendor_contact_id = i.xx_vendor_contact_id;
      END IF;
    END LOOP;

    COMMIT;

  END quality_check_supplier_cont;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of Quotation Header
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE quality_check_quotation_hdr IS

    l_status             VARCHAR2(10) := 'SUCCESS';
    l_check_rule         VARCHAR2(10) := 'FALSE';
    l_check_rule_country VARCHAR2(10) := 'FALSE';

    CURSOR c_quote_hdr IS
      SELECT *
      FROM   xxs3_ptp_quotation_hdr
      WHERE  process_flag = 'N';

  BEGIN
    FOR i IN c_quote_hdr LOOP
      l_status := 'SUCCESS';

      IF i.vendor_id IS NULL THEN
        insert_update_quote_hdr_dq(i.xx_po_header_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                    'for field ' ||
                                    'VENDOR_ID');
        l_status := 'ERR';
      END IF;

      IF i.vendor_site_id IS NULL THEN
        insert_update_quote_hdr_dq(i.xx_po_header_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                    'for field ' ||
                                    'VENDOR_SITE_ID');
        l_status := 'ERR';
      END IF;

      IF i.bill_to_location_id IS NULL THEN
        insert_update_quote_hdr_dq(i.xx_po_header_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                    'for field ' ||
                                    'BILL_TO_LOCATION_ID');
        l_status := 'ERR';
      END IF;

      IF i.payment_terms IS NULL THEN
        insert_update_quote_hdr_dq(i.xx_po_header_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                    'for field ' ||
                                    'PAYMENT_TERMS');
        l_status := 'ERR';
      END IF;

      IF i.status_lookup_code IS NOT NULL THEN
        IF i.status_lookup_code = 'I' THEN
          insert_update_quote_hdr_dq(i.xx_po_header_id, 'EQT-054:Supplier Quote Lookup Status', 'Invalid Supplier Quote Lookup Status');
          l_status := 'ERR';
        END IF;
      END IF;

      IF i.currency_code IS NOT NULL THEN
        IF i.currency_code <> 'USD' THEN
          insert_update_quote_hdr_dq(i.xx_po_header_id, 'EQT-050:USD Currency', 'Currency is not USD');
          l_status := 'ERR';
        END IF;
      END IF;

      IF i.quote_type_lookup_code IS NOT NULL THEN
        IF i.quote_type_lookup_code NOT IN ('CATALOG', 'STANDARD') THEN
          insert_update_quote_hdr_dq(i.xx_po_header_id, 'EQT-055:Supplier Quote Type Lookup', 'Invalid Supplier Quote Type');
          l_status := 'ERR';
        END IF;
      END IF;

      IF i.quotation_class_code IS NOT NULL THEN
        IF i.quotation_class_code NOT IN ('CATALOG') THEN
          insert_update_quote_hdr_dq(i.xx_po_header_id, 'EQT-056:Supplier Quote Class Code', 'Invalid Supplier Quote Class Code');
          l_status := 'ERR';
        END IF;
      END IF;

      IF l_status <> 'ERR' THEN
        UPDATE xxs3_ptp_quotation_hdr
        SET    process_flag = 'Y'
        WHERE  xx_po_header_id = i.xx_po_header_id;
      END IF;

    END LOOP;
    COMMIT;

  END quality_check_quotation_hdr;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of Quotation line
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  19/04/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE quality_check_quotation_line IS

    l_status             VARCHAR2(10) := 'SUCCESS';
    l_check_rule         VARCHAR2(10) := 'FALSE';
    l_check_rule_country VARCHAR2(10) := 'FALSE';

    CURSOR c_quote_line IS
      SELECT *
      FROM   xxs3_ptp_quotation_line
      WHERE  process_flag = 'N';

  BEGIN
    FOR i IN c_quote_line LOOP
      l_status := 'SUCCESS';

      IF i.unit_price IS NULL THEN
        insert_update_quote_line_dq(i.xx_po_line_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                     'for field ' ||
                                     'UNIT_PRICE');
        l_status := 'ERR';
      END IF;

      IF i.quantity IS NULL THEN
        insert_update_quote_line_dq(i.xx_po_line_id, 'EQT-028:Is Not Null', 'Missing value' || '' ||
                                     'for field ' ||
                                     'QUANTITY');
        l_status := 'ERR';
      END IF;

      IF l_status <> 'ERR' THEN
        UPDATE xxs3_ptp_quotation_line
        SET    process_flag = 'Y'
        WHERE  xx_po_line_id = i.xx_po_line_id;
      END IF;

    END LOOP;
    COMMIT;

  END quality_check_quotation_line;

  --------------------------------------------------------------------
  --  name:              report_data
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/05/2016
  --------------------------------------------------------------------
  --  purpose :          write report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report DQ errors
  --------------------------------------------------------------------
  PROCEDURE report_data_supplier(p_entity            VARCHAR2,
                                 p_xx_vendor_site_id NUMBER,
                                 p_vendor_site_id    NUMBER,
                                 p_error             VARCHAR2,
                                 p_accnt_type        VARCHAR2 /*x_err_code OUT NUMBER,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   x_err_msg  OUT VARCHAR2*/) IS
    CURSOR c_report_supplier IS
      SELECT nvl(xcid.rule_name, ' ') rule_name,
             nvl(xcid.notes, ' ') notes,
             xci.vendor_id vendor_id,
             xci.xx_vendor_id xx_vendor_id
      FROM   xxs3_ptp_suppliers    xci,
             xxs3_ptp_suppliers_dq xcid
      WHERE  xci.xx_vendor_id = xcid.xx_vendor_id
      AND    xci.process_flag IN ('Q', 'R');

    CURSOR c_report_site IS
      SELECT nvl(xcid.rule_name, ' ') rule_name,
             nvl(xcid.notes, ' ') notes,
             xci.vendor_site_id vendor_site_id,
             xci.xx_vendor_site_id xx_vendor_site_id
      FROM   xxs3_ptp_suppliers_sites    xci,
             xxs3_ptp_suppliers_sites_dq xcid
      WHERE  xci.xx_vendor_site_id = xcid.xx_vendor_site_id
      AND    xci.process_flag IN ('Q', 'R');

    /* CURSOR c_report_contact IS
       SELECT 'PTP',
    'Instance',
    xcid.rule_name         rule_name,
    xcid.notes             notes,
    xci.vendor_contact_id  vendor_contact_id,
    xci.xx_vendor_contact_id       xx_vendor_contact_id
       FROM   XXS3_PTP_SUPPLIERS_CONT    xci,
              XXS3_PTP_SUPPLIERS_CONT_DQ xcid
       WHERE  xci.xx_vendor_id = xcid.xx_vendor_id
       AND    xci.process_flag = 'Q';*/

    p_delimiter VARCHAR2(5) := '~';
    l_err_msg   VARCHAR2(2000);

  BEGIN
    /*
    x_err_code := 0;
    x_err_msg  := '';*/
    IF p_entity = 'SUPPLIER' THEN

      fnd_file.put_line(fnd_file.output, rpad('Supplier DQ status report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('=============================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Date:    ' ||
                         to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                         p_delimiter);

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 11, ' ') ||
                         p_delimiter ||
                         rpad('XX Vendor ID  ', 14, ' ') ||
                         p_delimiter ||
                         rpad('Vendor ID', 10, ' ') ||
                         p_delimiter ||
                         rpad('Rule Name', 45, ' ') ||
                         p_delimiter ||
                         rpad('Reject Reason', 50, ' '));

      FOR r_data IN c_report_supplier LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('SUPPLIER', 11, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_vendor_id, 14, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_id, 10, ' ') ||
                           p_delimiter ||
                           rpad(r_data.rule_name, 45, ' ') ||
                           p_delimiter ||
                           rpad(r_data.notes, 50, ' '));

      END LOOP;

    ELSIF p_entity = 'SUPPLIER_SITE' THEN

      fnd_file.put_line(fnd_file.output, rpad('Supplier Site DQ status report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('=============================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Date:    ' ||
                         to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                         p_delimiter);

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         p_delimiter ||
                         rpad('XX Vendor Site ID  ', 20, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Site ID', 15, ' ') ||
                         p_delimiter ||
                         rpad('Rule Name', 45, ' ') ||
                         p_delimiter ||
                         rpad('Reject Reason', 50, ' '));

      FOR r_data IN c_report_site LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('SUPPLIER SITE', 15, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_vendor_site_id, 20, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_site_id, 15, ' ') ||
                           p_delimiter ||
                           rpad(r_data.rule_name, 45, ' ') ||
                           p_delimiter ||
                           rpad(r_data.notes, 50, ' '));

      END LOOP;

    ELSIF p_entity = 'CoA_TRANSFORM' THEN

      fnd_file.put_line(fnd_file.output, rpad('CoA Transformation Failure report', 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('=============================', 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Date:    ' ||
                         to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 11, ' ') ||
                         p_delimiter ||
                         rpad('XX Vendor Site ID  ', 20, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Site ID', 15, ' ') ||
                         p_delimiter ||
                         rpad('Account Type', 27, ' ') ||
                         p_delimiter ||
                         rpad('Transformation_Status ', 10, ' ') ||
                         p_delimiter ||
                         rpad('Reject Reason', 50, ' '));

      fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                         p_delimiter ||
                         rpad('CoA Transform ', 11, ' ') ||
                         p_delimiter ||
                         rpad(p_xx_vendor_site_id, 20, ' ') ||
                         p_delimiter ||
                         rpad(p_vendor_site_id, 15, ' ') ||
                         p_delimiter ||
                         rpad(p_accnt_type, 27, ' ') ||
                         p_delimiter ||
                         rpad('FAIL', 10, ' ') ||
                         p_delimiter ||
                         rpad(p_error, 50, ' '));

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      --x_err_code := 1;
      l_err_msg := 'Failed to generate report: ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, l_err_msg);

  END report_data_supplier;

  --------------------------------------------------------------------
  --  name:              extract_report_supplier
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/05/2016
  --------------------------------------------------------------------
  --  purpose :          write extract report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     extract report
  --------------------------------------------------------------------

  PROCEDURE extract_report_supplier(p_entity VARCHAR2) IS

    CURSOR cur_col IS
      SELECT column_name
      FROM   all_tab_columns
      WHERE  table_name = 'XXS3_PTP_SUPPLIERS';

    CURSOR c_report_supplier IS
      SELECT *
      FROM   xxs3_ptp_suppliers xci
      WHERE  xci.process_flag IN ('Q', 'Y');

    l_count_extract NUMBER;
    l_count_reject  NUMBER;
    p_delimiter     VARCHAR2(1) := '~';

  BEGIN

    SELECT COUNT(1)
    INTO   l_count_extract
    FROM   xxs3_ptp_suppliers xci
    WHERE  xci.process_flag IN ('Q', 'Y');

    SELECT COUNT(1)
    INTO   l_count_reject
    FROM   xxs3_ptp_suppliers xci
    WHERE  xci.process_flag IN ('R');

    fnd_file.put_line(fnd_file.output, rpad('Report name = Data Extract Report' ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('=================================' ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = SUPPLIER' ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                            to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Total Record Count Processed = ' ||
                            l_count_extract || p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected =  ' ||
                            l_count_reject || p_delimiter, 100, ' '));

    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                       p_delimiter);

  END extract_report_supplier;
  --------------------------------------------------------------------
  --  name:              dq_report_supplier
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/05/2016
  --------------------------------------------------------------------
  --  purpose :          write dq report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report DQ errors
  --------------------------------------------------------------------

  PROCEDURE dq_report_supplier(p_entity VARCHAR2) IS

    CURSOR c_report_supplier IS
      SELECT nvl(xcid.rule_name, ' ') rule_name,
             nvl(xcid.notes, ' ') notes,
             xci.vendor_id vendor_id,
             xci.vendor_name vendor_name,
             xci.segment1 segment1,
             xci.xx_vendor_id xx_vendor_id,
             decode(xci.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM   xxs3_ptp_suppliers    xci,
             xxs3_ptp_suppliers_dq xcid
      WHERE  xci.xx_vendor_id = xcid.xx_vendor_id
      AND    xci.process_flag IN ('Q', 'R')
      ORDER  BY vendor_id DESC;

    CURSOR c_report_site IS
      SELECT nvl(xcid.rule_name, ' ') rule_name,
             nvl(xcid.notes, ' ') notes,
             xci.vendor_site_id vendor_site_id,
             xci.vendor_name vendor_name,
             xci.vendor_id vendor_id,
             xci.segment1 segment1,
             xci.vendor_site_code vendor_site_code,
             xci.xx_vendor_site_id xx_vendor_site_id,
             decode(xci.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM   xxs3_ptp_suppliers_sites    xci,
             xxs3_ptp_suppliers_sites_dq xcid
      WHERE  xci.xx_vendor_site_id = xcid.xx_vendor_site_id
      AND    xci.process_flag IN ('Q', 'R')
      ORDER  BY vendor_id DESC;

    CURSOR c_report_contact IS
      SELECT nvl(xcid.rule_name, ' ') rule_name,
             nvl(xcid.notes, ' ') notes,
             xci.vendor_id vendor_id,
             xci.segment1 segment1,
             xci.vendor_contact_id,
             xci.xx_vendor_contact_id,
             xci.person_first_name,
             xci.person_middle_name,
             xci.person_last_name,
             decode(xci.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM   xxs3_ptp_suppliers_cont    xci,
             xxs3_ptp_suppliers_cont_dq xcid
      WHERE  xci.xx_vendor_contact_id = xcid.xx_vendor_contact_id
      AND    xci.process_flag IN ('Q', 'R')
      ORDER  BY vendor_id DESC;

    CURSOR c_report_quote_hdr IS
      SELECT nvl(xcid.rule_name, ' ') rule_name,
             nvl(xcid.notes, ' ') notes,
             xci.po_header_id po_header_id,
             xci.segment1 segment1,
             xci.xx_po_header_id xx_po_header_id,
             decode(xci.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM   xxs3_ptp_quotation_hdr    xci,
             xxs3_ptp_quotation_hdr_dq xcid
      WHERE  xci.xx_po_header_id = xcid.xx_po_header_id
      AND    xci.process_flag IN ('Q', 'R')
      ORDER  BY po_header_id DESC;

    CURSOR c_report_quote_line IS
      SELECT nvl(xcid.rule_name, ' ') rule_name,
             nvl(xcid.notes, ' ') notes,
             xci.po_header_id po_header_id,
             xci.po_line_id po_line_id,
             xci.segment1 segment1,
             xci.xx_po_line_id xx_po_line_id,
             decode(xci.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM   xxs3_ptp_quotation_line    xci,
             xxs3_ptp_quotation_line_dq xcid
      WHERE  xci.xx_po_line_id = xcid.xx_po_line_id
      AND    xci.process_flag IN ('Q', 'R')
      ORDER  BY po_line_id DESC;

    p_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;

  BEGIN
    /*
    x_err_code := 0;
    x_err_msg  := '';*/
    IF p_entity = 'SUPPLIER' THEN

      SELECT COUNT(1)
      INTO   l_count_dq
      FROM   xxs3_ptp_suppliers xci
      WHERE  xci.process_flag IN ('Q', 'R');

      SELECT COUNT(1)
      INTO   l_count_reject
      FROM   xxs3_ptp_suppliers xci
      WHERE  xci.process_flag = 'R';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Quality Error Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues = ' ||
                              l_count_dq || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected =  ' ||
                              l_count_reject || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 11, ' ') ||
                         p_delimiter ||
                         rpad('XX Vendor ID  ', 14, ' ') ||
                         p_delimiter ||
                         rpad('Vendor ID', 10, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Name', 240, ' ') ||
                         p_delimiter ||
                         rpad('Supplier Number', 30, ' ') ||
                         p_delimiter ||
                         rpad('Reject Record Flag(Y/N)', 22, ' ') ||
                         p_delimiter ||
                         rpad('Rule Name', 45, ' ') ||
                         p_delimiter ||
                         rpad('Reason Code', 50, ' '));

      FOR r_data IN c_report_supplier LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('SUPPLIER', 11, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_vendor_id, 14, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_id, 10, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_name, 240, ' ') ||
                           p_delimiter ||
                           rpad(r_data.segment1, 30, ' ') ||
                           p_delimiter ||
                           rpad(r_data.reject_record, 22, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.rule_name, 'NULL'), 45, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.notes, 'NULL'), 50, ' '));

      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);

    ELSIF p_entity = 'SUPPLIER_SITE' THEN

      SELECT COUNT(1)
      INTO   l_count_dq
      FROM   xxs3_ptp_suppliers_sites xci
      WHERE  xci.process_flag IN ('Q', 'R');

      SELECT COUNT(1)
      INTO   l_count_reject
      FROM   xxs3_ptp_suppliers_sites xci
      WHERE  xci.process_flag = 'R';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Quality Error Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues ' ||
                              l_count_dq || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected = ' ||
                              l_count_reject || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         p_delimiter ||
                         rpad('XX Vendor Site ID  ', 14, ' ') ||
                         p_delimiter ||
                         rpad('Vendor ID', 10, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Name', 240, ' ') ||
                         p_delimiter ||
                         rpad('Supplier Number', 30, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Site Code', 17, ' ') ||
                         p_delimiter ||
                         rpad('Reject Record Flag(Y/N)', 22, ' ') ||
                         p_delimiter ||
                         rpad('Rule Name', 45, ' ') ||
                         p_delimiter ||
                         rpad('Reason Code', 50, ' '));

      FOR r_data IN c_report_site LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('SUPPLIER_SITE', 15, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_vendor_site_id, 14, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_id, 10, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_name, 240, ' ') ||
                           p_delimiter ||
                           rpad(r_data.segment1, 30, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.vendor_site_code, 'NULL'), 17, ' ') ||
                           p_delimiter ||
                           rpad(r_data.reject_record, 22, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.rule_name, 'NULL'), 45, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.notes, 'NULL'), 50, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);

    ELSIF p_entity = 'SUPPLIER_CONTACT' THEN

      SELECT COUNT(1)
      INTO   l_count_dq
      FROM   xxs3_ptp_suppliers_cont xci
      WHERE  xci.process_flag IN ('Q', 'R');

      SELECT COUNT(1)
      INTO   l_count_reject
      FROM   xxs3_ptp_suppliers_cont xci
      WHERE  xci.process_flag = 'R';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Quality Error Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues ' ||
                              l_count_dq || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected = ' ||
                              l_count_reject || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         p_delimiter ||
                         rpad('XX Vendor Contact ID  ', 25, ' ') ||
                         p_delimiter ||
                         rpad('Vendor ID', 10, ' ') ||
                         p_delimiter ||
                         rpad('Supplier Number', 30, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Contact ID', 17, ' ') ||
                         p_delimiter ||
                         rpad('Vendor First Name', 150, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Middle Name', 60, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Last Name', 150, ' ') ||
                         p_delimiter ||
                         rpad('Reject Record Flag(Y/N)', 22, ' ') ||
                         p_delimiter ||
                         rpad('Rule Name', 45, ' ') ||
                         p_delimiter ||
                         rpad('Reason Code', 50, ' '));

      FOR r_data IN c_report_contact LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('SUPPLIER_CONTACT', 15, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_vendor_contact_id, 25, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_id, 10, ' ') ||
                           p_delimiter ||
                           rpad(r_data.segment1, 30, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.vendor_contact_id, 'NULL'), 17, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.person_first_name, 'NULL'), 150, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.person_middle_name, 'NULL'), 60, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.person_last_name, 'NULL'), 150, ' ') ||
                           p_delimiter ||
                           rpad(r_data.reject_record, 22, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.rule_name, 'NULL'), 45, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.notes, 'NULL'), 50, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);

    ELSIF p_entity = 'QUOTATION_HDR' THEN

      SELECT COUNT(1)
      INTO   l_count_dq
      FROM   xxs3_ptp_quotation_hdr xci
      WHERE  xci.process_flag IN ('Q', 'R');

      SELECT COUNT(1)
      INTO   l_count_reject
      FROM   xxs3_ptp_quotation_hdr xci
      WHERE  xci.process_flag = 'R';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Quality Error Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues ' ||
                              l_count_dq || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected = ' ||
                              l_count_reject || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 17, ' ') ||
                         p_delimiter ||
                         rpad('XX PO Header ID  ', 17, ' ') ||
                         p_delimiter ||
                         rpad('PO Header ID', 13, ' ') ||
                         p_delimiter ||
                         rpad('Document Number', 20, ' ') ||
                         p_delimiter ||
                         rpad('Reject Record Flag(Y/N)', 22, ' ') ||
                         p_delimiter ||
                         rpad('Rule Name', 45, ' ') ||
                         p_delimiter ||
                         rpad('Reason Code', 50, ' '));

      FOR r_data IN c_report_quote_hdr LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('QUOTATION_HEADER', 17, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_po_header_id, 17, ' ') ||
                           p_delimiter ||
                           rpad(r_data.po_header_id, 13, ' ') ||
                           p_delimiter ||
                           rpad(r_data.segment1, 20, ' ') ||
                           p_delimiter ||
                           rpad(r_data.reject_record, 22, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.rule_name, 'NULL'), 45, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.notes, 'NULL'), 50, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);

    ELSIF p_entity = 'QUOTATION_LINE' THEN

      SELECT COUNT(1)
      INTO   l_count_dq
      FROM   xxs3_ptp_quotation_line xci
      WHERE  xci.process_flag IN ('Q', 'R');

      SELECT COUNT(1)
      INTO   l_count_reject
      FROM   xxs3_ptp_quotation_line xci
      WHERE  xci.process_flag = 'R';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Quality Error Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues ' ||
                              l_count_dq || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected = ' ||
                              l_count_reject || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 17, ' ') ||
                         p_delimiter ||
                         rpad('XX PO Line ID  ', 17, ' ') ||
                         p_delimiter ||
                         rpad('PO Header ID', 13, ' ') ||
                         p_delimiter ||
                         rpad('PO Line ID', 13, ' ') ||
                         p_delimiter ||
                         rpad('Document Number', 20, ' ') ||
                         p_delimiter ||
                         rpad('Reject Record Flag(Y/N)', 22, ' ') ||
                         p_delimiter ||
                         rpad('Rule Name', 45, ' ') ||
                         p_delimiter ||
                         rpad('Reason Code', 50, ' '));

      FOR r_data IN c_report_quote_line LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('QUOTATION_LINE', 17, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_po_line_id, 17, ' ') ||
                           p_delimiter ||
                           rpad(r_data.po_header_id, 13, ' ') ||
                           p_delimiter ||
                           rpad(r_data.po_line_id, 13, ' ') ||
                           p_delimiter ||
                           rpad(r_data.segment1, 20, ' ') ||
                           p_delimiter ||
                           rpad(r_data.reject_record, 22, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.rule_name, 'NULL'), 45, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.notes, 'NULL'), 50, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);
    END IF;
  END dq_report_supplier;

  --------------------------------------------------------------------
  --  name:              data_cleanse_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/05/2016
  --------------------------------------------------------------------
  --  purpose :          write data cleanse report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report data cleanse
  --------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity VARCHAR2) IS

    CURSOR c_report_supplier IS
      SELECT xci.vendor_id vendor_id,
             xci.vendor_name vendor_name,
             xci.s3_vendor_name s3_vendor_name,
             xci.vendor_name_alt vendor_name_alt,
             xci.s3_vendor_name_alt s3_vendor_name_alt,
             xci.segment1 segment1,
             xci.xx_vendor_id xx_vendor_id,
             xci.cleanse_status,
             xci.cleanse_error
      FROM   xxs3_ptp_suppliers xci
      WHERE  xci.cleanse_status IN ('PASS', 'FAIL');

    CURSOR c_report_site IS
      SELECT xci.vendor_site_id vendor_site_id,
             xci.vendor_id,
             xci.vendor_name vendor_name,
             xci.s3_vendor_name s3_vendor_name,
             xci.address_line1,
             xci.address_line2,
             xci.address_line3,
             xci.s3_address_line1,
             xci.s3_address_line2,
             xci.s3_address_line3,
             xci.segment1 segment1,
             xci.vendor_site_code vendor_site_code,
             xci.xx_vendor_site_id xx_vendor_site_id,
             xci.cleanse_status,
             xci.cleanse_error
      FROM   xxs3_ptp_suppliers_sites xci
      WHERE  xci.cleanse_status IN ('PASS', 'FAIL');

    p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;

  BEGIN
    /*
    x_err_code := 0;
    x_err_msg  := '';*/
    IF p_entity = 'SUPPLIER' THEN

      SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_ptp_suppliers xci
      WHERE  xci.cleanse_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_ptp_suppliers xci
      WHERE  xci.cleanse_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Automated Cleanse & Standardize Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('====================================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 11, ' ') ||
                         p_delimiter ||
                         rpad('XX Vendor ID  ', 14, ' ') ||
                         p_delimiter ||
                         rpad('Vendor ID', 10, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Name', 240, ' ') ||
                         p_delimiter ||
                         rpad('S3 Vendor Name', 240, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Name Alt', 240, ' ') ||
                         p_delimiter ||
                         rpad('S3 Vendor Name Alt', 240, ' ') ||
                         p_delimiter ||
                         rpad('Supplier Number', 30, ' ') ||
                         p_delimiter ||
                         rpad('Status', 10, ' ') ||
                         p_delimiter ||
                         rpad('Error Message', 200, ' '));

      /* fnd_file.put_line(fnd_file.output,'Track Name'|| p_delimiter ||
      'Entity Name'|| p_delimiter ||
      'XX Vendor ID  '|| p_delimiter ||
      'Vendor ID'|| p_delimiter ||
      'Vendor Name' || p_delimiter ||
      'S3 Vendor Name' || p_delimiter ||
      'Supplier Number' || p_delimiter ||
      'Status' || p_delimiter ||
      'Error Message' );*/

      FOR r_data IN c_report_supplier LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('SUPPLIER', 11, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_vendor_id, 14, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_id, 10, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_name, 240, ' ') ||
                           p_delimiter ||
                           rpad(r_data.s3_vendor_name, 240, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_name_alt, 240, ' ') ||
                           p_delimiter ||
                           rpad(r_data.s3_vendor_name_alt, 240, ' ') ||
                           p_delimiter ||
                           rpad(r_data.segment1, 30, ' ') ||
                           p_delimiter ||
                           rpad(r_data.cleanse_status, 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));

      /*  fnd_file.put_line(fnd_file.output, 'PTP' || p_delimiter ||
                                                                                                                                                                                           'SUPPLIER' || p_delimiter ||
                                                                                                                                                                                           r_data.xx_vendor_id || p_delimiter ||
                                                                                                                                                                                           r_data.vendor_id || p_delimiter ||
                                                                                                                                                                                           r_data.vendor_name|| p_delimiter ||
                                                                                                                                                                                           r_data.s3_vendor_name || p_delimiter ||
                                                                                                                                                                                           r_data.segment1 || p_delimiter ||
                                                                                                                                                                                           r_data.cleanse_status || p_delimiter ||
                                                                                                                                                                                           nvl(r_data.cleanse_error,'NULL') );*/
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);

    ELSIF p_entity = 'SUPPLIER_SITE' THEN

      SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_ptp_suppliers_sites xci
      WHERE  xci.cleanse_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_ptp_suppliers_sites xci
      WHERE  xci.cleanse_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Automated Cleanse & Standardize Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('====================================================', 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         p_delimiter ||
                         rpad('XX Vendor Site ID  ', 14, ' ') ||
                         p_delimiter ||
                         rpad('Vendor ID', 10, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Name', 240, ' ') ||
                         p_delimiter ||
                         rpad('S3 Vendor Name', 240, ' ') ||
                         p_delimiter ||
                         rpad('Address Line1', 240, ' ') ||
                         p_delimiter ||
                         rpad('S3 Address Line1', 240, ' ') ||
                         p_delimiter ||
                         rpad('Address Line2', 240, ' ') ||
                         p_delimiter ||
                         rpad('S3 Address Line2', 240, ' ') ||
                         p_delimiter ||
                         rpad('Address Line3', 240, ' ') ||
                         p_delimiter ||
                         rpad('S3 Address Line3', 240, ' ') ||
                         p_delimiter ||
                         rpad('Supplier Number', 30, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Site Code', 17, ' ') ||
                         p_delimiter ||
                         rpad('Status', 10, ' ') ||
                         p_delimiter ||
                         rpad('Error Message', 200, ' '));

      FOR r_data IN c_report_site LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('SUPPLIER_SITE', 15, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_vendor_site_id, 14, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_id, 10, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_name, 240, ' ') ||
                           p_delimiter ||
                           rpad(r_data.s3_vendor_name, 240, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.address_line1, 'NULL'), 240, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_address_line1, 'NULL'), 240, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.address_line2, 'NULL'), 240, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_address_line2, 'NULL'), 240, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.address_line3, 'NULL'), 240, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_address_line3, 'NULL'), 240, ' ') ||
                           p_delimiter ||
                           rpad(r_data.segment1, 30, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_site_code, 17, ' ') ||
                           p_delimiter ||
                           rpad(r_data.cleanse_status, 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);
    END IF;

  END data_cleanse_report;

  --------------------------------------------------------------------
  --  name:              data_transform_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/05/2016
  --------------------------------------------------------------------
  --  purpose :          write data transform report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report data cleanse
  --------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2) IS

    CURSOR c_report_supplier IS
      SELECT xci.vendor_id vendor_id,
             xci.vendor_name vendor_name,
             xci.terms terms,
             xci.s3_terms s3_terms,
             xci.segment1 segment1,
             xci.vendor_type_lookup_code,
             xci.s3_vendor_type_lookup_code,
             xci.pay_group_lookup_code,
             xci.s3_pay_group_lookup_code,
             xci.xx_vendor_id xx_vendor_id,
             xci.transform_status,
             xci.transform_error
      FROM   xxs3_ptp_suppliers xci
      WHERE  xci.transform_status IN ('PASS', 'FAIL');

    CURSOR c_report_site IS
      SELECT xci.vendor_site_id vendor_site_id,
             xci.vendor_id,
             xci.vendor_name vendor_name,
             xci.terms terms,
             xci.s3_terms s3_terms,
             xci.segment1 segment1,
             xci.vendor_site_code vendor_site_code,
             xci.xx_vendor_site_id xx_vendor_site_id,
             xci.liability_acct_segment1,
             xci.liability_acct_segment2,
             xci.liability_acct_segment3,
             xci.liability_acct_segment4,
             xci.liability_acct_segment5,
             xci.liability_acct_segment6,
             xci.liability_acct_segment7,
             xci.liability_acct_segment10,
             xci.s3_liability_acct_segment1,
             xci.s3_liability_acct_segment2,
             xci.s3_liability_acct_segment3,
             xci.s3_liability_acct_segment4,
             xci.s3_liability_acct_segment5,
             xci.s3_liability_acct_segment6,
             xci.s3_liability_acct_segment7,
             xci.s3_liability_acct_segment8,
             xci.prepayment_acct_segment1,
             xci.prepayment_acct_segment2,
             xci.prepayment_acct_segment3,
             xci.prepayment_acct_segment4,
             xci.prepayment_acct_segment5,
             xci.prepayment_acct_segment6,
             xci.prepayment_acct_segment7,
             xci.prepayment_acct_segment10,
             xci.s3_prepayment_acct_segment1,
             xci.s3_prepayment_acct_segment2,
             xci.s3_prepayment_acct_segment3,
             xci.s3_prepayment_acct_segment4,
             xci.s3_prepayment_acct_segment5,
             xci.s3_prepayment_acct_segment6,
             xci.s3_prepayment_acct_segment7,
             xci.s3_prepayment_acct_segment8,
             xci.future_payment_acct_segment1,
             xci.future_payment_acct_segment2,
             xci.future_payment_acct_segment3,
             xci.future_payment_acct_segment4,
             xci.future_payment_acct_segment5,
             xci.future_payment_acct_segment6,
             xci.future_payment_acct_segment7,
             xci.future_payment_acct_segment10,
             xci.s3_future_pmt_acct_segment1,
             xci.s3_future_pmt_acct_segment2,
             xci.s3_future_pmt_acct_segment3,
             xci.s3_future_pmt_acct_segment4,
             xci.s3_future_pmt_acct_segment5,
             xci.s3_future_pmt_acct_segment6,
             xci.s3_future_pmt_acct_segment7,
             xci.s3_future_pmt_acct_segment8,
             xci.vendor_type_lookup_code,
             xci.s3_vendor_type_lookup_code,
             xci.pay_group_lookup_code,
             xci.s3_pay_group_lookup_code,
             xci.ship_via_lookup_code,
             xci.s3_ship_via_lookup_code,
             xci.freight_terms_lookup_code,
             xci.s3_freight_terms_lookup_code,
             xci.fob_lookup_code,
             xci.s3_fob_lookup_code,
             xci.ship_to,
             xci.s3_ship_to,
             xci.bill_to,
             xci.s3_bill_to,
             xci.org_name,
             xci.s3_org_name,
             xci.tolerance_name,
             xci.s3_tolerance_name,
             xci.transform_status,
             xci.transform_error
      FROM   xxs3_ptp_suppliers_sites xci
      WHERE  xci.transform_status IN ('PASS', 'FAIL');

    CURSOR c_quote_header IS
      SELECT xx_po_header_id,
             po_header_id,
             segment1,
             s3_vendor_id,
             org_name,
             s3_org_name,
             agent_name,
             s3_agent_name,
             ship_to_location,
             s3_ship_to_location,
             bill_to_location,
             s3_bill_to_location,
             payment_terms,
             s3_payment_terms,
             ship_via_lookup_code,
             s3_ship_via_lookup_code,
             freight_terms_lookup_code,
             s3_freight_terms_lookup_code,
             fob_lookup_code,
             s3_fob_lookup_code,
             xci.transform_status,
             xci.transform_error
      FROM   xxs3_ptp_quotation_hdr xci
      WHERE  xci.transform_status IN ('PASS', 'FAIL');

    CURSOR c_quote_line IS
      SELECT xx_po_line_id,
             po_line_id,
             segment1,
             line_num,
             s3_po_line_id,
             org_name,
             s3_org_name,
             category,
             s3_category,
             xci.transform_status,
             xci.transform_error
      FROM   xxs3_ptp_quotation_line xci
      WHERE  xci.transform_status IN ('PASS', 'FAIL');

    CURSOR c_price_break IS
      SELECT ship_to_location_code,
             s3_ship_to_location_code,
             terms,
             s3_terms,
             freight_terms_lookup_code,
             s3_freight_terms_lookup_code,
             fob_lookup_code,
             s3_fob_lookup_code,
             ship_via_lookup_code,
             s3_ship_via_lookup_code,
             ship_to_organization_code,
             s3_ship_to_organization_code,
             transform_status,
             transform_error
      FROM   xxs3_ptp_price_break xci
      WHERE  xci.transform_status IN ('PASS', 'FAIL');

    p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;

  BEGIN
    /*
    x_err_code := 0;
    x_err_msg  := '';*/
    IF p_entity = 'SUPPLIER' THEN

      SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_ptp_suppliers xci
      WHERE  xci.transform_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_ptp_suppliers xci
      WHERE  xci.transform_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Transformation Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 11, ' ') ||
                         p_delimiter ||
                         rpad('XX Vendor ID  ', 14, ' ') ||
                         p_delimiter ||
                         rpad('Vendor ID', 10, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Name', 240, ' ') ||
                         p_delimiter ||
                         rpad('Supplier Number', 30, ' ') ||
                         p_delimiter ||
                         rpad('Terms', 50, ' ') ||
                         p_delimiter ||
                         rpad('S3 Terms', 50, ' ') ||
                         p_delimiter ||
                         rpad('VENDOR_TYPE_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('S3_VENDOR_TYPE_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('PAY_GROUP_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('S3_PAY_GROUP_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('Status', 10, ' ') ||
                         p_delimiter ||
                         rpad('Error Message', 200, ' '));

      FOR r_data IN c_report_supplier LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('SUPPLIER', 11, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_vendor_id, 14, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_id, 10, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_name, 240, ' ') ||
                           p_delimiter ||
                           rpad(r_data.segment1, 30, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.terms, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_terms, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.vendor_type_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_vendor_type_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.pay_group_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_pay_group_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(r_data.transform_status, 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);

    ELSIF p_entity = 'SUPPLIER_SITE' THEN

      SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_ptp_suppliers_sites xci
      WHERE  xci.transform_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_ptp_suppliers_sites xci
      WHERE  xci.transform_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Transformation Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         p_delimiter ||
                         rpad('XX Vendor Site ID  ', 14, ' ') ||
                         p_delimiter ||
                         rpad('Vendor ID', 10, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Name', 240, ' ') ||
                         p_delimiter ||
                         rpad('Supplier Number', 30, ' ') ||
                         p_delimiter ||
                         rpad('Vendor Site Code', 17, ' ') ||
                         p_delimiter ||
                         rpad('Terms', 50, ' ') ||
                         p_delimiter ||
                         rpad('S3 Terms', 50, ' ') ||
                         p_delimiter ||
                         rpad('VENDOR_TYPE_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('S3_VENDOR_TYPE_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('PAY_GROUP_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('S3_PAY_GROUP_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('SHIP_VIA_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('S3_SHIP_VIA_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('FREIGHT_TERMS_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('S3_FREIGHT_TERMS_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('FOB_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('S3_FOB_LOOKUP_CODE', 50, ' ') ||
                         p_delimiter ||
                         rpad('LIABILITY_SEGMENT1', 25, ' ') ||
                         p_delimiter ||
                         rpad('LIABILITY_SEGMENT2', 25, ' ') ||
                         p_delimiter ||
                         rpad('LIABILITY_SEGMENT3', 25, ' ') ||
                         p_delimiter ||
                         rpad('LIABILITY_SEGMENT4', 25, ' ') ||
                         p_delimiter ||
                         rpad('LIABILITY_SEGMENT5', 25, ' ') ||
                         p_delimiter ||
                         rpad('LIABILITY_SEGMENT6', 25, ' ') ||
                         p_delimiter ||
                         rpad('LIABILITY_SEGMENT7', 25, ' ') ||
                         p_delimiter ||
                         rpad('LIABILITY_SEGMENT10', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_LIABILITY_SEGMENT1', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_LIABILITY_SEGMENT2', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_LIABILITY_SEGMENT3', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_LIABILITY_SEGMENT4', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_LIABILITY_SEGMENT5', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_LIABILITY_SEGMENT6', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_LIABILITY_SEGMENT7', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_LIABILITY_SEGMENT8', 25, ' ') ||
                         p_delimiter ||
                         rpad('PREPAYMENT_SEGMENT1', 25, ' ') ||
                         p_delimiter ||
                         rpad('PREPAYMENT_SEGMENT2', 25, ' ') ||
                         p_delimiter ||
                         rpad('PREPAYMENT_SEGMENT3', 25, ' ') ||
                         p_delimiter ||
                         rpad('PREPAYMENT_SEGMENT4', 25, ' ') ||
                         p_delimiter ||
                         rpad('PREPAYMENT_SEGMENT5', 25, ' ') ||
                         p_delimiter ||
                         rpad('PREPAYMENT_SEGMENT6', 25, ' ') ||
                         p_delimiter ||
                         rpad('PREPAYMENT_SEGMENT7', 25, ' ') ||
                         p_delimiter ||
                         rpad('PREPAYMENT_SEGMENT10', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_PREPAYMENT_SEGMENT1', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_PREPAYMENT_SEGMENT2', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_PREPAYMENT_SEGMENT3', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_PREPAYMENT_SEGMENT4', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_PREPAYMENT_SEGMENT5', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_PREPAYMENT_SEGMENT6', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_PREPAYMENT_SEGMENT7', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_PREPAYMENT_SEGMENT8', 25, ' ') ||
                         p_delimiter ||
                         rpad('FUTURE_SEGMENT1', 25, ' ') ||
                         p_delimiter ||
                         rpad('FUTURE_SEGMENT2', 25, ' ') ||
                         p_delimiter ||
                         rpad('FUTURE_SEGMENT3', 25, ' ') ||
                         p_delimiter ||
                         rpad('FUTURE_SEGMENT4', 25, ' ') ||
                         p_delimiter ||
                         rpad('FUTURE_SEGMENT5', 25, ' ') ||
                         p_delimiter ||
                         rpad('FUTURE_SEGMENT6', 25, ' ') ||
                         p_delimiter ||
                         rpad('FUTURE_SEGMENT7', 25, ' ') ||
                         p_delimiter ||
                         rpad('FUTURE_SEGMENT10', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_FUTURE_SEGMENT1', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_FUTURE_SEGMENT2', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_FUTURE_SEGMENT3', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_FUTURE_SEGMENT4', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_FUTURE_SEGMENT5', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_FUTURE_SEGMENT6', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_FUTURE_SEGMENT7', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_FUTURE_SEGMENT8', 25, ' ') ||
                         p_delimiter ||
                         rpad('SHIP_TO', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_SHIP_TO', 25, ' ') ||
                         p_delimiter ||
                         rpad('BILL_TO', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_BILL_TO', 25, ' ') ||
                         p_delimiter ||
                         rpad('ORG_NAME', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_ORG_NAME', 25, ' ') ||
                         p_delimiter ||
                         rpad('TOLERANCE_NAME', 25, ' ') ||
                         p_delimiter ||
                         rpad('S3_TOLERANCE_NAME', 25, ' ') ||
                         p_delimiter ||
                         rpad('Status', 10, ' ') ||
                         p_delimiter ||
                         rpad('Error Message', 200, ' '));

      FOR r_data IN c_report_site LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('SUPPLIER_SITE', 15, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_vendor_site_id, 14, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_id, 10, ' ') ||
                           p_delimiter ||
                           rpad(r_data.vendor_name, 240, ' ') ||
                           p_delimiter ||
                           rpad(r_data.segment1, 30, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.vendor_site_code, 'NULL'), 17, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.terms, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_terms, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.vendor_type_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_vendor_type_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.pay_group_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_pay_group_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.ship_via_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_ship_via_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.freight_terms_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_freight_terms_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.fob_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_fob_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.liability_acct_segment1, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.liability_acct_segment2, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.liability_acct_segment3, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.liability_acct_segment4, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.liability_acct_segment5, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.liability_acct_segment6, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.liability_acct_segment7, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.liability_acct_segment10, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_liability_acct_segment1, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_liability_acct_segment2, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_liability_acct_segment3, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_liability_acct_segment4, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_liability_acct_segment5, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_liability_acct_segment6, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_liability_acct_segment7, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_liability_acct_segment8, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.prepayment_acct_segment1, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.prepayment_acct_segment2, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.prepayment_acct_segment3, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.prepayment_acct_segment4, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.prepayment_acct_segment5, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.prepayment_acct_segment6, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.prepayment_acct_segment7, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.prepayment_acct_segment10, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_prepayment_acct_segment1, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_prepayment_acct_segment2, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_prepayment_acct_segment3, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_prepayment_acct_segment4, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_prepayment_acct_segment5, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_prepayment_acct_segment6, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_prepayment_acct_segment7, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_prepayment_acct_segment8, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.future_payment_acct_segment1, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.future_payment_acct_segment2, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.future_payment_acct_segment3, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.future_payment_acct_segment4, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.future_payment_acct_segment5, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.future_payment_acct_segment6, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.future_payment_acct_segment7, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.future_payment_acct_segment10, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_future_pmt_acct_segment1, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_future_pmt_acct_segment2, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_future_pmt_acct_segment3, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_future_pmt_acct_segment4, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_future_pmt_acct_segment5, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_future_pmt_acct_segment6, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_future_pmt_acct_segment7, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_future_pmt_acct_segment8, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.ship_to, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_ship_to, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.bill_to, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_bill_to, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.org_name, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_org_name, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.tolerance_name, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_tolerance_name, 'NULL'), 25, ' ') ||
                           p_delimiter ||
                           rpad(r_data.transform_status, 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);

    ELSIF p_entity = 'QUOTATION_HDR' THEN

      SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_ptp_quotation_hdr xci
      WHERE  xci.transform_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_ptp_quotation_hdr xci
      WHERE  xci.transform_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Transformation Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         p_delimiter ||
                         rpad('xx_po_header_id', 14, ' ') ||
                         p_delimiter ||
                         rpad('po_header_id', 14, ' ') ||
                         p_delimiter ||
                         rpad('segment1', 14, ' ') ||
                         p_delimiter ||
                         rpad('org_name', 14, ' ') ||
                         p_delimiter ||
                         rpad('s3_org_name', 14, ' ') ||
                         p_delimiter ||
                         rpad('agent_name', 14, ' ') ||
                         p_delimiter ||
                         rpad('s3_agent_name', 14, ' ') ||
                         p_delimiter ||
                         rpad('ship_to_location', 14, ' ') ||
                         p_delimiter ||
                         rpad('s3_ship_to_location', 14, ' ') ||
                         p_delimiter ||
                         rpad('bill_to_location', 14, ' ') ||
                         p_delimiter ||
                         rpad('s3_bill_to_location', 14, ' ') ||
                         p_delimiter ||
                         rpad('payment_terms', 14, ' ') ||
                         p_delimiter ||
                         rpad('s3_payment_terms', 14, ' ') ||
                         p_delimiter ||
                         rpad('ship_via_lookup_code', 14, ' ') ||
                         p_delimiter ||
                         rpad('s3_ship_via_lookup_code', 14, ' ') ||
                         p_delimiter ||
                         rpad('freight_terms_lookup_code', 14, ' ') ||
                         p_delimiter ||
                         rpad('s3_freight_terms_lookup_code', 14, ' ') ||
                         p_delimiter ||
                         rpad('fob_lookup_code', 14, ' ') ||
                         p_delimiter ||
                         rpad('s3_fob_lookup_code', 14, ' ') ||
                         p_delimiter ||
                         rpad('Status', 10, ' ') ||
                         p_delimiter ||
                         rpad('Error Message', 200, ' '));

      FOR r_data IN c_quote_header LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('QUOTATION_HDR', 15, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.xx_po_header_id, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.po_header_id, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.segment1, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.org_name, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_org_name, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.agent_name, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_agent_name, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.ship_to_location, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_ship_to_location, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.bill_to_location, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_bill_to_location, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.payment_terms, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_payment_terms, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.ship_via_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_ship_via_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.freight_terms_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_freight_terms_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.fob_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_fob_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.transform_status, 'NULL'), 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);

    ELSIF p_entity = 'QUOTATION_LINE' THEN

      SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_ptp_quotation_line xci
      WHERE  xci.transform_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_ptp_quotation_line xci
      WHERE  xci.transform_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Transformation Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         p_delimiter ||
                         rpad('xx_po_line_id', 14, ' ') ||
                         p_delimiter ||
                         rpad('po_line_id', 14, ' ') ||
                         p_delimiter ||
                         rpad('segment1', 14, ' ') ||
                         p_delimiter ||
                         rpad('line_num', 14, ' ') ||
                         p_delimiter ||
                         rpad('org_name', 14, ' ') ||
                         p_delimiter ||
                         rpad('s3_org_name', 14, ' ') ||
                         p_delimiter ||
                         rpad('category', 14, ' ') ||
                         p_delimiter ||
                         rpad('s3_category', 14, ' ') ||
                         p_delimiter ||
                         rpad('Status', 10, ' ') ||
                         p_delimiter ||
                         rpad('Error Message', 200, ' '));

      FOR r_data IN c_quote_line LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('QUOTATION_LINE', 15, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.xx_po_line_id, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.po_line_id, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.segment1, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.line_num, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.org_name, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_org_name, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.category, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_category, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.transform_status, 'NULL'), 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);

    ELSIF p_entity = 'PRICE_BREAK' THEN

      SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_ptp_price_break xci
      WHERE  xci.transform_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_ptp_price_break xci
      WHERE  xci.transform_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Transformation Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         p_delimiter ||
                         rpad('ship_to_location_code', 14, ' ') ||
                         p_delimiter ||
                         rpad('S3_SHIP_TO_LOCATION_CODE', 14, ' ') ||
                         p_delimiter ||
                         rpad('terms', 14, ' ') ||
                         p_delimiter ||
                         rpad('S3_TERMS', 14, ' ') ||
                         p_delimiter ||
                         rpad('freight_terms_lookup_code', 14, ' ') ||
                         p_delimiter ||
                         rpad('S3_FREIGHT_TERMS_LOOKUP_CODE', 14, ' ') ||
                         p_delimiter ||
                         rpad('fob_lookup_code', 14, ' ') ||
                         p_delimiter ||
                         rpad('S3_FOB_LOOKUP_CODE', 14, ' ') ||
                         p_delimiter ||
                         rpad('ship_via_lookup_code', 14, ' ') ||
                         p_delimiter ||
                         rpad('S3_SHIP_VIA_LOOKUP_CODE', 14, ' ') ||
                         p_delimiter ||
                         rpad('ship_to_organization_code', 14, ' ') ||
                         p_delimiter ||
                         rpad('S3_SHIP_TO_ORGANIZATION_CODE', 14, ' ') ||
                         p_delimiter ||
                         rpad('TRANSFORM_STATUS', 14, ' ') ||
                         p_delimiter ||
                         rpad('TRANSFORM_ERROR', 200, ' ') ||
                         p_delimiter);

      FOR r_data IN c_price_break LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTP', 10, ' ') ||
                           p_delimiter ||
                           rpad('PRICE_BREAK', 15, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.ship_to_location_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_ship_to_location_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.terms, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_terms, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.freight_terms_lookup_code, 'NULL'), 50, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_freight_terms_lookup_code, 'NULL'), 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.fob_lookup_code, 'NULL'), 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_fob_lookup_code, 'NULL'), 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.ship_via_lookup_code, 'NULL'), 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_ship_via_lookup_code, 'NULL'), 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.ship_to_organization_code, 'NULL'), 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.s3_ship_to_organization_code, 'NULL'), 200, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.transform_status, 'NULL'), 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);

    END IF;

  END data_transform_report;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  28/04/2016  Debarati Banerjee            Initial build
  --  1.1  02/12/2016  Debarati Banerjee            Migrate attribute15  
  --  1.2  12/12/2016  Debarati Banerjee            Exclude Resellers who earn commissions and 
  --                                                are set up as Vendors 
  -- --------------------------------------------------------------------------------------------

  PROCEDURE suppliers_extract_data(x_errbuf  OUT VARCHAR2,
                                   x_retcode OUT NUMBER ) IS
                                   
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_output             VARCHAR2(4000);
    l_org_id NUMBER := fnd_global.org_id;

    CURSOR cur_suppliers_extract IS
    SELECT DISTINCT aas.vendor_id vendor_id,
                 aas.vendor_name vendor_name,
                 aas.vendor_name_alt vendor_name_alt,
                 aas.segment1 segment1,
                 aas.employee_id employee_id,
                 (SELECT employee_number
                    FROM per_all_people_f papf
                   WHERE papf.person_id = aas.employee_id
                     AND SYSDATE BETWEEN
                         nvl(papf.effective_start_date, SYSDATE) AND
                         nvl(papf.effective_end_date, SYSDATE)) employee_number,
                 aas.vendor_type_lookup_code vendor_type_lookup_code,
                 aas.one_time_flag one_time_flag,
                 at.NAME terms,
                 aas.pay_date_basis_lookup_code pay_date_basis_lookup_code,
                 aas.pay_group_lookup_code pay_group_lookup_code,
                 aas.payment_priority payment_priority,
                 aas.invoice_currency_code invoice_currency_code,
                 aas.payment_currency_code payment_currency_code,
                 aas.hold_all_payments_flag hold_all_payments_flag,
                 aas.hold_unmatched_invoices_flag hold_unmatched_invoices_flag,
                 aas.hold_future_payments_flag hold_future_payments_flag,
                 aas.hold_reason hold_reason,
                 aas.num_1099 num_1099,
                 --Tax type,
                 aas.organization_type_lookup_code organization_type_lookup_code,
                 aas.vat_code                      vat_code,
                 aas.purchasing_hold_reason        purchasing_hold_reason,
                 aas.terms_date_basis              terms_date_basis,
                 aas.qty_rcv_tolerance             qty_rcv_tolerance,
                 aas.qty_rcv_exception_code        qty_rcv_exception_code,
                 aas.enforce_ship_to_location_code enforce_ship_to_location_code,
                 aas.days_early_receipt_allowed    days_early_receipt_allowed,
                 aas.days_late_receipt_allowed     days_late_receipt_allowed,
                 aas.receipt_days_exception_code   receipt_days_exception_code,
                 --aas.RECEIVING_ROUTING_ID RECEIVING_ROUTING_ID,
                 (SELECT meaning
                    FROM fnd_lookup_values_vl flvv
                   WHERE lookup_type = 'RCV_ROUTING_HEADERS'
                     AND flvv.lookup_code = aas.receiving_routing_id) receipt_routing,
                 aas.ap_tax_rounding_rule ap_tax_rounding_rule,
                 aas.state_reportable_flag state_reportable_flag,
                 aas.federal_reportable_flag federal_reportable_flag,
                 aas.vat_registration_num vat_registration_num,
                 aas.allow_awt_flag allow_awt_flag,
                 aag.NAME invoice_withholding_tax_group,
                 aas.match_option match_option,
                 aas.always_take_disc_flag always_take_disc_flag,
                 aas.type_1099 type_1099,
                 aas.start_date_active,
                 aas.women_owned_flag women_owned_flag,
                 aas.small_business_flag small_business_flag,
                 aas.inspection_required_flag inspection_required_flag,
                 aas.receipt_required_flag receipt_required_flag,
                 aas.allow_substitute_receipts_flag allow_substitute_receipts_flag,
                 aas.allow_unordered_receipts_flag allow_unordered_receipts_flag,
                 aas.exclude_freight_from_discount exclude_freight_from_discount,
                 aas.create_debit_memo_flag create_debit_memo_flag,
                 aas.auto_tax_calc_flag auto_tax_calc_flag,
                 aas.amount_includes_tax_flag amount_includes_tax_flag,
                 aas.auto_calculate_interest_flag auto_calculate_interest_flag,
                 aas.offset_tax_flag offset_tax_flag,
                 aas.party_id party_id,
                 (SELECT party_number
                    FROM hz_parties
                   WHERE party_id = aas.party_id) party_number,
                 aas.hold_flag,
                 aas.accts_pay_code_combination_id,
                 aas.disc_lost_code_combination_id,
                 aas.disc_taken_code_combination_id,
                 aas.expense_code_combination_id,
                 aas.prepay_code_combination_id,
                 aas.future_dated_payment_ccid,
                 aas.attribute15 --new field as on 1st Dec FDD update
   FROM ap_suppliers          aas,
        ap_terms              at,
        ap_awt_groups         aag,
        ap_supplier_sites_all aps,
        hr_operating_units    ou
  WHERE aas.terms_id = at.term_id(+)
    AND aas.awt_group_id = aag.group_id(+)
    AND aps.vendor_id = aas.vendor_id
    AND ou.organization_id = aps.org_id
    AND nvl(aps.inactive_date, SYSDATE + 1) > SYSDATE
    AND nvl(aas.end_date_active, SYSDATE + 1) > SYSDATE
    AND aps.org_id = l_org_id
    --new change 12th December FDD update to exclude 
    --Resellers who earn commissions and are set up as Vendors 
    AND NOT EXISTS    
  (SELECT DISTINCT asp.vendor_id
           FROM ap_suppliers          asp,
                ap_supplier_sites_all ass,
                ap_supplier_contacts  apsc,
                hz_parties            person,
                hz_parties            pty_rel,
                hr_operating_units    hou,
                apps.cn_salesreps     cns,
                ap_terms_vl           site_term
          WHERE ass.vendor_id = asp.vendor_id
            AND apsc.per_party_id = person.party_id
            AND apsc.rel_party_id = pty_rel.party_id
            AND ass.org_id = hou.organization_id
            AND apsc.org_party_site_id = ass.party_site_id
               --AND asp.vendor_name = 'LS Supplier'
            AND cns.source_id = apsc.vendor_contact_id
            AND ass.terms_id = site_term.term_id
            AND cns.TYPE = 'SUPPLIER_CONTACT'
            AND SYSDATE < nvl(cns.end_date_active, SYSDATE + 1)
            AND ass.org_id = l_org_id
            AND asp.vendor_id = aas.vendor_id);
            
     --new change 12th December FDD update to exclude 
    --Resellers who earn commissions and are set up as Vendors        
    --AND   aas.ONE_TIME_FLAG <> 'Y';
    
    


    CURSOR cur_vendor_name IS
      SELECT vendor_name,
             xx_vendor_id
      FROM   xxs3_ptp_suppliers
      WHERE  regexp_like(vendor_name, 'Inc\.|INC|Corp\.|CORP|LLC\.|LLC|Ltd\.|LTD\.|LTD|P\.O\.|A\.P\.|A/P|A\.R\.|A/R|CO\.|Co\.', 'c')
      AND    process_flag IN ('N');

    CURSOR cur_alt_vendor_name IS
      SELECT vendor_name_alt,
             xx_vendor_id
      FROM   xxs3_ptp_suppliers
      WHERE  regexp_like(vendor_name_alt, 'Inc\.|INC|Corp\.|CORP|LLC\.|LLC|Ltd\.|LTD\.|LTD|P\.O\.|A\.P\.|A/P|A\.R\.|A/R|CO\.|Co\.', 'c')
      AND    process_flag IN ('N');

    CURSOR cur_match IS
      SELECT xx_vendor_id
      FROM   xxs3_ptp_suppliers
      WHERE  match_option <> 'P';

    CURSOR cur_awt IS
      SELECT xx_vendor_id,
             invoice_withholding_tax_group
      FROM   xxs3_ptp_suppliers
      WHERE  invoice_withholding_tax_group IS NOT NULL;

    CURSOR cur_supplier IS
      SELECT vendor_name,
             terms,
             vendor_name_alt,
             invoice_withholding_tax_group,
             xx_vendor_id
      FROM   xxs3_ptp_suppliers;

    CURSOR c_transform IS
      SELECT *
      FROM   xxs3_ptp_suppliers
      WHERE  process_flag IN ('Y', 'Q');

    l_err_code VARCHAR2(4000);
    l_err_msg  VARCHAR2(4000);

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    l_org_id  := fnd_global.org_id;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptp_suppliers';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptp_suppliers_dq';

    --IF p_only_dq = 'N' THEN

    FOR i IN cur_suppliers_extract LOOP

      INSERT INTO xxs3_ptp_suppliers
      VALUES
        (xxs3_ptp_suppliers_seq.NEXTVAL,
         SYSDATE,
         'N',
         NULL,
         NULL,
         i.vendor_id,
         i.vendor_name,
         NULL,
         i.vendor_name_alt,
         NULL,
         i.segment1,
         i.employee_id,
         i.employee_number,
         i.vendor_type_lookup_code,
         NULL,
         i.one_time_flag,
         i.terms,
         NULL,
         i.pay_date_basis_lookup_code,
         i.pay_group_lookup_code,
         NULL,
         i.payment_priority,
         i.invoice_currency_code,
         i.payment_currency_code,
         i.hold_all_payments_flag,
         i.hold_unmatched_invoices_flag,
         i.hold_future_payments_flag,
         i.hold_reason,
         i.num_1099,
         i.organization_type_lookup_code,
         i.vat_code,
         i.purchasing_hold_reason,
         i.terms_date_basis,
         i.qty_rcv_tolerance,
         i.qty_rcv_exception_code,
         i.enforce_ship_to_location_code,
         i.days_early_receipt_allowed,
         i.days_late_receipt_allowed,
         i.receipt_days_exception_code,
         i.receipt_routing,
         i.ap_tax_rounding_rule,
         i.state_reportable_flag,
         i.federal_reportable_flag,
         i.vat_registration_num,
         i.allow_awt_flag,
         i.invoice_withholding_tax_group,
         NULL,
         i.match_option,
         NULL,
         i.always_take_disc_flag,
         i.type_1099,
         i.start_date_active,
         i.women_owned_flag,
         i.small_business_flag,
         i.inspection_required_flag,
         i.receipt_required_flag,
         i.allow_substitute_receipts_flag,
         i.allow_unordered_receipts_flag,
         i.exclude_freight_from_discount,
         i.create_debit_memo_flag,
         i.auto_tax_calc_flag,
         i.amount_includes_tax_flag,
         i.auto_calculate_interest_flag,
         i.offset_tax_flag,
         i.party_id,
         i.hold_flag,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         i.attribute15, --new field as on 1st Dec FDD update
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL);

    END LOOP;

    COMMIT;
    --END IF;
    fnd_file.put_line(fnd_file.log, 'Loading complete');

    --Auto Cleanse

    FOR j IN cur_vendor_name LOOP
      --update vendor_name
      update_vendor_name(j.xx_vendor_id, j.vendor_name, 'SUPPLIER');
    END LOOP;

    FOR j IN cur_alt_vendor_name LOOP
      --update vendor_name
      update_vendor_name_alt(j.xx_vendor_id, j.vendor_name_alt, 'SUPPLIER');
    END LOOP;

    FOR j IN cur_match LOOP
      --update match_option
      update_match_option(j.xx_vendor_id);
    END LOOP;

    FOR j IN cur_awt LOOP
      update_awt(j.xx_vendor_id);
    END LOOP;

    -- DQ check supplier
    quality_check_supplier;
    fnd_file.put_line(fnd_file.log, 'DQ complete');

    --Trnaformation
    FOR l IN c_transform LOOP

      --terms transformation
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'payment_terms_ptp', p_stage_tab => 'XXS3_PTP_SUPPLIERS', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => l.xx_vendor_id, --Staging Table Primary Column Value
                                             p_legacy_val => l.terms, --Legacy Value
                                             p_stage_col => 'S3_TERMS', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --vendor_type_lookup_code transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'vendor_type_lookup_code', p_stage_tab => 'XXS3_PTP_SUPPLIERS', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => l.xx_vendor_id, --Staging Table Primary Column Value
                                             p_legacy_val => l.vendor_type_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_VENDOR_TYPE_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --pay_group_lookup_code transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'pay_group_lookup_code', p_stage_tab => 'XXS3_PTP_SUPPLIERS', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => l.xx_vendor_id, --Staging Table Primary Column Value
                                             p_legacy_val => l.pay_group_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_PAY_GROUP_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

    END LOOP;

    FOR k IN cur_supplier LOOP
      update_legacy_values(k.xx_vendor_id, k.invoice_withholding_tax_group, k.vendor_name, k.vendor_name_alt, /*k.terms,*/ NULL, NULL, NULL, 'SUPPLIER');
    END LOOP;

    COMMIT;

  EXCEPTION

    WHEN report_error THEN
      fnd_file.put_line(fnd_file.log, 'Failed to generate report');
      x_retcode := 1;
      x_errbuf  := 'Unexpected error: report error';

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

    /*fnd_file.put_line(fnd_file.output, 'Concurrent Request processed successfully');
    fnd_file.put_line(fnd_file.output, '--------------------------------------'); */
  END suppliers_extract_data;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  28/04/2016  Debarati Banerjee            Initial build
  --  1.1  02/12/2016  Debarati Banerjee            exclude sites where vendor_site_code ='HOME'
  -- --------------------------------------------------------------------------------------------

  PROCEDURE supplier_site_extract_data(x_errbuf  OUT VARCHAR2,
                                       x_retcode OUT NUMBER /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         p_only_dq IN VARCHAR2 DEFAULT 'N'*/) IS

    --l_request_id         NUMBER := fnd_global.conc_request_id;
    l_errbuf                 VARCHAR2(2000);
    l_retcode                VARCHAR2(1);
    l_requestor              NUMBER;
    l_program_short_name     VARCHAR2(100);
    l_status_message         VARCHAR2(4000);
    l_output_liability       VARCHAR2(4000);
    l_output_code_liability  VARCHAR2(100);
    l_output_prepayment      VARCHAR2(4000);
    l_output_code_prepayment VARCHAR2(100);
    l_output_future          VARCHAR2(4000);
    l_output_code_future     VARCHAR2(100);
    l_output                 VARCHAR2(4000);
    l_output_code            VARCHAR2(100);
    l_output_coa_update      VARCHAR2(4000);
    l_output_code_coa_update VARCHAR2(100);
    l_s3_gl_string           VARCHAR2(2000);
    --l_org_id             NUMBER := fnd_profile.value('ORG_ID');
    l_org_id NUMBER := fnd_global.org_id;
    l_file   utl_file.file_type;

    CURSOR c_utl_upload IS
      SELECT *
      FROM   xxobjt.xxs3_ptp_suppliers_sites;

    CURSOR cur_suppliers_sites_extract/*(p_vendor_id IN NUMBER)*/ IS
      SELECT assa.creation_date creation_date,
             assa.created_by created_by,
             assa.vendor_id vendor_id,
             aas.segment1 segment1,
             assa.vendor_site_id vendor_site_id,
             assa.vendor_site_code vendor_site_code,
             assa.purchasing_site_flag purchasing_site_flag,
             assa.rfq_only_site_flag rfq_only_site_flag,
             assa.pay_site_flag pay_site_flag,
             assa.address_line1 address_line1,
             assa.address_line2 address_line2,
             assa.address_line3 address_line3,
             assa.city city,
             assa.state state,
             assa.zip zip,
             assa.province province,
             assa.country country,
             assa.area_code area_code,
             assa.phone phone,
             assa.ship_to_location_id ship_to_location_id,
             (SELECT hla.location_code
              FROM   hr_locations_all hla
              WHERE  hla.ship_to_site_flag = 'Y'
              AND    SYSDATE <= nvl(hla.inactive_date, SYSDATE + 1)
              AND    hla.location_id = assa.ship_to_location_id) ship_to,
             assa.bill_to_location_id bill_to_location_id,
             (SELECT hla.location_code
              FROM   hr_locations_all hla
              WHERE  hla.bill_to_site_flag = 'Y'
              AND    SYSDATE <= nvl(hla.inactive_date, SYSDATE + 1)
              AND    hla.location_id = assa.bill_to_location_id) bill_to,
             assa.ship_via_lookup_code ship_via_lookup_code,
             assa.freight_terms_lookup_code freight_terms_lookup_code,
             assa.fob_lookup_code fob_lookup_code,
             assa.shipping_control shipping_control,
             assa.inactive_date inactive_date,
             assa.fax fax,
             assa.fax_area_code fax_area_code,
             assa.telex telex,
             assa.terms_date_basis terms_date_basis,
             assa.vat_code vat_code,
             assa.distribution_set_id distribution_set_id,
             (SELECT distribution_set_name
              FROM   ap_distribution_sets_all adsa
              WHERE  adsa.distribution_set_id = assa.distribution_set_id) distribution_set_name,
             (SELECT concatenated_segments
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.accts_pay_code_combination_id) liability_account,
             (SELECT concatenated_segments
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.prepay_code_combination_id) prepayment_account,
             (SELECT segment1
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.accts_pay_code_combination_id) liability_acct_segment1,
             (SELECT segment2
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.accts_pay_code_combination_id) liability_acct_segment2,
             (SELECT segment3
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.accts_pay_code_combination_id) liability_acct_segment3,
             (SELECT segment4
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.accts_pay_code_combination_id) liability_acct_segment4,
             (SELECT segment5
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.accts_pay_code_combination_id) liability_acct_segment5,
             (SELECT segment6
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.accts_pay_code_combination_id) liability_acct_segment6,
             (SELECT segment7
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.accts_pay_code_combination_id) liability_acct_segment7,
             (SELECT segment10
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.accts_pay_code_combination_id) liability_acct_segment10,
             (SELECT segment1
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.prepay_code_combination_id) prepayment_acct_segment1,
             (SELECT segment2
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.prepay_code_combination_id) prepayment_acct_segment2,
             (SELECT segment3
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.prepay_code_combination_id) prepayment_acct_segment3,
             (SELECT segment4
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.prepay_code_combination_id) prepayment_acct_segment4,
             (SELECT segment5
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.prepay_code_combination_id) prepayment_acct_segment5,
             (SELECT segment6
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.prepay_code_combination_id) prepayment_acct_segment6,
             (SELECT segment7
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.prepay_code_combination_id) prepayment_acct_segment7,
             (SELECT segment10
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.prepay_code_combination_id) prepayment_acct_segment10,
             assa.pay_group_lookup_code pay_group_lookup_code,
             assa.payment_priority payment_priority,
             at.NAME terms,
             assa.pay_date_basis_lookup_code pay_date_basis_lookup_code,
             assa.always_take_disc_flag always_take_disc_flag,
             assa.invoice_currency_code invoice_currency_code,
             assa.payment_currency_code payment_currency_code,
             assa.hold_all_payments_flag hold_all_payments_flag,
             assa.hold_future_payments_flag hold_future_payments_flag,
             assa.hold_reason hold_reason,
             assa.hold_unmatched_invoices_flag hold_unmatched_invoices_flag,
             assa.ap_tax_rounding_rule ap_tax_rounding_rule,
             assa.auto_tax_calc_flag auto_tax_calc_flag,
             assa.amount_includes_tax_flag amount_includes_tax_flag,
             assa.tax_reporting_site_flag tax_reporting_site_flag,
             assa.vat_registration_num vat_registration_num,
             ou.organization_id org_id,
             ou.NAME org_name,
             assa.address_line4 address_line4,
             assa.county county,
             assa.address_style address_style,
             assa.LANGUAGE LANGUAGE,
             assa.allow_awt_flag allow_awt_flag,
             assa.bank_charge_bearer bank_charge_bearer,
             assa.pay_on_code pay_on_code,
             assa.match_option match_option,
             assa.country_of_origin_code country_of_origin_code,
             --assa.FUTURE_DATED_PAYMENT_CCID FUTURE_DATED_PAYMENT_CCID,
             (SELECT concatenated_segments
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.future_dated_payment_ccid) future_dated_payment_ccid,
             (SELECT segment1
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.future_dated_payment_ccid) future_payment_acct_segment1,
             (SELECT segment2
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.future_dated_payment_ccid) future_payment_acct_segment2,
             (SELECT segment3
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.future_dated_payment_ccid) future_payment_acct_segment3,
             (SELECT segment4
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.future_dated_payment_ccid) future_payment_acct_segment4,
             (SELECT segment5
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.future_dated_payment_ccid) future_payment_acct_segment5,
             (SELECT segment6
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.future_dated_payment_ccid) future_payment_acct_segment6,
             (SELECT segment7
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.future_dated_payment_ccid) future_payment_acct_segment7,
             (SELECT segment10
              FROM   gl_code_combinations_kfv gcck
              WHERE  gcck.code_combination_id =
                     assa.future_dated_payment_ccid) future_payment_acct_segment10,
             assa.create_debit_memo_flag create_debit_memo_flag,
             assa.offset_tax_flag offset_tax_flag,
             assa.supplier_notif_method supplier_notif_method,
             assa.email_address email_address,
             assa.primary_pay_site_flag primary_pay_site_flag,
             --SERVICES_TOLERANCE_ID
             aas.vendor_name vendor_name,
             assa.vendor_site_code_alt vendor_site_code_alt,
             assa.attention_ar_flag attention_ar_flag,
             assa.exclude_freight_from_discount exclude_freight_from_discount,
             assa.pcard_site_flag pcard_site_flag,
             assa.gapless_inv_num_flag gapless_inv_num_flag,
             assa.tolerance_id tolerance_id,
             (SELECT tolerance_name
              FROM   ap_tolerance_templates att
              WHERE  att.tolerance_id = assa.tolerance_id) tolerance_name,
             assa.location_id location_id,
             (SELECT hl.location_code
              FROM   hr_locations hl
              WHERE  hl.location_id = assa.location_id) location_code,
             assa.party_site_id party_site_id,
             (SELECT hps.party_site_name
              FROM   hz_party_sites hps
              WHERE  hps.party_site_id = assa.party_site_id) party_site_name,
             aas.vendor_type_lookup_code
      --3880 total count
      FROM   ap_supplier_sites_all assa,
             ap_suppliers          aas,
             hr_operating_units    ou,
             ap_terms              at
      WHERE  assa.vendor_id = aas.vendor_id
      AND    ou.organization_id = assa.org_id
      AND    aas.terms_id = at.term_id(+)
      AND    nvl(assa.inactive_date, SYSDATE + 1) > SYSDATE
      AND    nvl(aas.end_date_active, SYSDATE + 1) > SYSDATE
            --AND   ou.name = 'Stratasys US OU'
      AND    assa.org_id = l_org_id
      AND    assa.vendor_site_code <> 'HOME'
      AND EXISTS (SELECT vendor_id
             FROM xxs3_ptp_suppliers
             WHERE process_flag <> 'R'
             AND vendor_id = assa.vendor_id)
      AND assa.vendor_site_code <> 'HOME';--new change as on 1st Dec FDD update
      --AND    assa.vendor_id = p_vendor_id;

    CURSOR cur_vendor_name IS
      SELECT vendor_name,
             xx_vendor_site_id
      FROM   xxs3_ptp_suppliers_sites
      WHERE  regexp_like(vendor_name, 'Inc\.|INC|Corp\.|CORP|LLC\.|LLC|Ltd\.|LTD\.|LTD|P\.O\.|A\.P\.|A/P|A\.R\.|A/R', 'c')
      AND    process_flag = 'N';

    CURSOR cur_sup_site IS
      SELECT *
      FROM   xxs3_ptp_suppliers_sites;
    --WHERE process_flag = 'N';

    CURSOR cur_sup_site_transform IS
      SELECT *
      FROM   xxs3_ptp_suppliers_sites
      WHERE  process_flag IN ('Y', 'Q');

    l_err_code VARCHAR2(4000);
    l_err_msg  VARCHAR2(4000);

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    l_file    := utl_file.fopen('/UtlFiles/shared/DEV', 'ptp_supplier_site_24_08_2016.XLS', 'w', 32767);

    fnd_file.put_line(fnd_file.log, 'l_org_id ' || l_org_id);
    
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptp_suppliers_sites';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptp_suppliers_sites_dq';
    --FOR m IN cur_valid_suppliers LOOP

      FOR i IN cur_suppliers_sites_extract/*(m.vendor_id)*/ LOOP
        --WHERE  process_flag = 'P';

        INSERT INTO xxs3_ptp_suppliers_sites
        VALUES
          (xxs3_ptp_suppliers_sites_seq.NEXTVAL,
           SYSDATE,
           'N',
           NULL,
           NULL,
           i.creation_date,
           i.created_by,
           i.vendor_id,
           i.segment1,
           i.vendor_site_id,
           i.vendor_site_code,
           i.purchasing_site_flag,
           i.rfq_only_site_flag,
           i.pay_site_flag,
           i.address_line1,
           i.address_line2,
           i.address_line3,
           NULL,
           NULL,
           NULL,
           i.city,
           i.state,
           i.zip,
           i.province,
           i.country,
           i.area_code,
           i.phone,
           i.ship_to_location_id,
           i.ship_to,
           NULL,
           i.bill_to_location_id,
           i.bill_to,
           NULL,
           i.ship_via_lookup_code,
           NULL,
           i.freight_terms_lookup_code,
           NULL,
           i.fob_lookup_code,
           NULL,
           i.shipping_control,
           i.inactive_date,
           i.fax,
           i.fax_area_code,
           i.telex,
           i.terms_date_basis,
           i.vat_code,
           i.distribution_set_id,
           i.distribution_set_name,
           i.liability_account,
           i.prepayment_account,
           NULL,
           NULL,
           i.liability_acct_segment1,
           i.liability_acct_segment2,
           i.liability_acct_segment3,
           i.liability_acct_segment4,
           i.liability_acct_segment5,
           i.liability_acct_segment6,
           i.liability_acct_segment7,
           i.liability_acct_segment10,
           i.prepayment_acct_segment1,
           i.prepayment_acct_segment2,
           i.prepayment_acct_segment3,
           i.prepayment_acct_segment4,
           i.prepayment_acct_segment5,
           i.prepayment_acct_segment6,
           i.prepayment_acct_segment7,
           i.prepayment_acct_segment10,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           i.pay_group_lookup_code,
           NULL,
           i.payment_priority,
           i.terms,
           NULL,
           i.pay_date_basis_lookup_code,
           i.always_take_disc_flag,
           i.invoice_currency_code,
           i.payment_currency_code,
           i.hold_all_payments_flag,
           i.hold_future_payments_flag,
           i.hold_reason,
           i.hold_unmatched_invoices_flag,
           i.ap_tax_rounding_rule,
           i.auto_tax_calc_flag,
           i.amount_includes_tax_flag,
           i.tax_reporting_site_flag,
           i.vat_registration_num,
           i.org_id,
           i.org_name,
           NULL,
           --i.ORGANIZATION_NAME,
           i.address_line4,
           i.county,
           i.address_style,
           i.LANGUAGE,
           i.allow_awt_flag,
           i.bank_charge_bearer,
           i.pay_on_code,
           i.match_option,
           i.country_of_origin_code,
           i.future_dated_payment_ccid,
           i.future_payment_acct_segment1,
           i.future_payment_acct_segment2,
           i.future_payment_acct_segment3,
           i.future_payment_acct_segment4,
           i.future_payment_acct_segment5,
           i.future_payment_acct_segment6,
           i.future_payment_acct_segment7,
           i.future_payment_acct_segment10,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           i.create_debit_memo_flag,
           i.offset_tax_flag,
           i.supplier_notif_method,
           i.email_address,
           i.primary_pay_site_flag,
           i.vendor_name,
           NULL,
           i.vendor_site_code_alt,
           i.attention_ar_flag,
           i.exclude_freight_from_discount,
           i.pcard_site_flag,
           i.gapless_inv_num_flag,
           i.tolerance_id,
           i.tolerance_name,
           NULL,
           i.location_id,
           i.location_code,
           i.party_site_id,
           i.party_site_name,
           i.vendor_type_lookup_code,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL,
           NULL);

      END LOOP;
    --END LOOP;
    COMMIT;
    --END IF;
    fnd_file.put_line(fnd_file.log, 'Loading complete');

    --Auto Cleanse

    --update vendor_name
    FOR j IN cur_vendor_name LOOP
      update_vendor_name(j.xx_vendor_site_id, j.vendor_name, 'SITE');
    END LOOP;

    --update address

    FOR k IN cur_sup_site LOOP

      update_address(k.xx_vendor_site_id, k.address_line1, 'ADDRESS_LINE1');
      update_address(k.xx_vendor_site_id, k.address_line2, 'ADDRESS_LINE2');
      update_address(k.xx_vendor_site_id, k.address_line3, 'ADDRESS_LINE3');
    END LOOP;

    --check DQ Rules
    quality_check_supplier_site;

    fnd_file.put_line(fnd_file.log, 'DQ complete');
    --create report

    --DQ_report_data('SUPPLIER_SITE');
    --report_data_supplier('SUPPLIER_SITE',NULL,NULL,NULL,NULL);

    FOR k IN cur_sup_site_transform LOOP

      --CoA Transform

      IF k.liability_account IS NOT NULL THEN
        /*xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'LIABILITY_ACCOUNT', p_legacy_company_val => k.liability_acct_segment1, --Legacy Company Value
                                                   p_legacy_department_val => k.liability_acct_segment2, --Legacy Department Value
                                                   p_legacy_account_val => k.liability_acct_segment3, --Legacy Account Value
                                                   p_legacy_product_val => k.liability_acct_segment5, --Legacy Product Value
                                                   p_legacy_location_val => k.liability_acct_segment6, --Legacy Location Value
                                                   p_legacy_intercompany_val => k.liability_acct_segment7, --Legacy Intercompany Value
                                                   p_legacy_division_val => k.liability_acct_segment10, --Legacy Division Value
                                                   p_item_number => NULL, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message

        xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxs3_ptp_suppliers_sites', p_stage_primary_col => 'xx_vendor_site_id', p_stage_primary_col_val => k.xx_vendor_site_id, p_stage_company_col => 's3_Liability_Acct_segment1', p_stage_business_unit_col => 's3_Liability_Acct_segment2', p_stage_department_col => 's3_Liability_Acct_segment3', p_stage_account_col => 's3_Liability_Acct_segment4', p_stage_product_line_col => 's3_Liability_Acct_segment5', p_stage_location_col => 's3_Liability_Acct_segment6', p_stage_intercompany_col => 's3_Liability_Acct_segment7', p_stage_future_col => 's3_Liability_Acct_segment8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);*/
      
      --24th November(New CoA mapping)
        xxs3_coa_transform_pkg.coa_transform(p_field_name => 'LIABILITY_ACCOUNT'
                                              ,p_legacy_company_val => k.liability_acct_segment1 --Legacy Company Value
                                              ,p_legacy_department_val => k.liability_acct_segment2 --Legacy Department Value
                                              ,p_legacy_account_val => k.liability_acct_segment3 --Legacy Account Value
                                              ,p_legacy_product_val => k.liability_acct_segment5 --Legacy Product Value
                                              ,p_legacy_location_val => k.liability_acct_segment6 --Legacy Location Value
                                              ,p_legacy_intercompany_val => k.liability_acct_segment7 --Legacy Intercompany Value
                                              ,p_legacy_division_val => k.liability_acct_segment10 --Legacy Division Value
                                              ,p_item_number => NULL
                                              ,p_s3_org => NULL
                                              ,p_trx_type => 'ALL'
                                              ,p_set_of_books_id => NULL
                                              ,p_debug_flag => 'N'
                                              ,p_s3_gl_string => l_s3_gl_string
                                              ,p_err_code => l_output_code
                                              ,p_err_msg => l_output);
                                              
                                              
        xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string,
                                                         p_stage_tab => 'xxs3_ptp_suppliers_sites', 
                                                         p_stage_primary_col => 'xx_vendor_site_id', 
                                                         p_stage_primary_col_val => k.xx_vendor_site_id, 
                                                         p_stage_company_col => 's3_Liability_Acct_segment1', 
                                                         p_stage_business_unit_col => 's3_Liability_Acct_segment2', 
                                                         p_stage_department_col => 's3_Liability_Acct_segment3', 
                                                         p_stage_account_col => 's3_Liability_Acct_segment4', 
                                                         p_stage_product_line_col => 's3_Liability_Acct_segment5', 
                                                         p_stage_location_col => 's3_Liability_Acct_segment6', 
                                                         p_stage_intercompany_col => 's3_Liability_Acct_segment7', 
                                                         p_stage_future_col => 's3_Liability_Acct_segment8', 
                                                         p_coa_err_msg => l_output, 
                                                         p_err_code => l_output_code_coa_update, 
                                                         p_err_msg => l_output_coa_update);
        --24th November(New CoA mapping)                                                 
      END IF;

      IF k.prepayment_account IS NOT NULL THEN
        /*xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'PREPAYMENT_ACCOUNT', p_legacy_company_val => k.prepayment_acct_segment1, --Legacy Company Value
                                                   p_legacy_department_val => k.prepayment_acct_segment2, --Legacy Department Value
                                                   p_legacy_account_val => k.prepayment_acct_segment3, --Legacy Account Value
                                                   p_legacy_product_val => k.prepayment_acct_segment5, --Legacy Product Value
                                                   p_legacy_location_val => k.prepayment_acct_segment6, --Legacy Location Value
                                                   p_legacy_intercompany_val => k.prepayment_acct_segment7, --Legacy Intercompany Value
                                                   p_legacy_division_val => k.prepayment_acct_segment10, --Legacy Division Value
                                                   p_item_number => NULL, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message

        xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxs3_ptp_suppliers_sites', p_stage_primary_col => 'xx_vendor_site_id', p_stage_primary_col_val => k.xx_vendor_site_id, p_stage_company_col => 's3_PrePayment_Acct_segment1', p_stage_business_unit_col => 's3_PrePayment_Acct_segment2', p_stage_department_col => 's3_PrePayment_Acct_segment3', p_stage_account_col => 's3_PrePayment_Acct_segment4', p_stage_product_line_col => 's3_PrePayment_Acct_segment5', p_stage_location_col => 's3_PrePayment_Acct_segment6', p_stage_intercompany_col => 's3_PrePayment_Acct_segment7', p_stage_future_col => 's3_PrePayment_Acct_segment8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);*/
        
         --24th November(New CoA mapping)
        xxs3_coa_transform_pkg.coa_transform(p_field_name => 'PREPAYMENT_ACCOUNT'
                                              ,p_legacy_company_val => k.prepayment_acct_segment1 --Legacy Company Value
                                              ,p_legacy_department_val => k.prepayment_acct_segment2 --Legacy Department Value
                                              ,p_legacy_account_val => k.prepayment_acct_segment3 --Legacy Account Value
                                              ,p_legacy_product_val => k.prepayment_acct_segment5 --Legacy Product Value
                                              ,p_legacy_location_val => k.prepayment_acct_segment6 --Legacy Location Value
                                              ,p_legacy_intercompany_val => k.prepayment_acct_segment7 --Legacy Intercompany Value
                                              ,p_legacy_division_val => k.prepayment_acct_segment10 --Legacy Division Value
                                              ,p_item_number => NULL
                                              ,p_s3_org => NULL
                                              ,p_trx_type => 'ALL'
                                              ,p_set_of_books_id => NULL
                                              ,p_debug_flag => 'N'
                                              ,p_s3_gl_string => l_s3_gl_string
                                              ,p_err_code => l_output_code
                                              ,p_err_msg => l_output);
                                              
        xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string, 
                                          p_stage_tab => 'xxs3_ptp_suppliers_sites', 
                                          p_stage_primary_col => 'xx_vendor_site_id', 
                                          p_stage_primary_col_val => k.xx_vendor_site_id, 
                                          p_stage_company_col => 's3_PrePayment_Acct_segment1',
                                          p_stage_business_unit_col => 's3_PrePayment_Acct_segment2', 
                                          p_stage_department_col => 's3_PrePayment_Acct_segment3', 
                                          p_stage_account_col => 's3_PrePayment_Acct_segment4', 
                                          p_stage_product_line_col => 's3_PrePayment_Acct_segment5', 
                                          p_stage_location_col => 's3_PrePayment_Acct_segment6', 
                                          p_stage_intercompany_col => 's3_PrePayment_Acct_segment7',
                                          p_stage_future_col => 's3_PrePayment_Acct_segment8', 
                                          p_coa_err_msg => l_output, 
                                          p_err_code => l_output_code_coa_update, 
                                          p_err_msg => l_output_coa_update); 
                                          
                                                                             
        --24th November(New CoA mapping)                                                                     
      END IF;

      IF k.future_dated_payment_ccid IS NOT NULL THEN
        /*xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'FUTURE_DATED_PAYMENT_CCID', p_legacy_company_val => k.future_payment_acct_segment1, --Legacy Company Value
                                                   p_legacy_department_val => k.future_payment_acct_segment2, --Legacy Department Value
                                                   p_legacy_account_val => k.future_payment_acct_segment3, --Legacy Account Value
                                                   p_legacy_product_val => k.future_payment_acct_segment5, --Legacy Product Value
                                                   p_legacy_location_val => k.future_payment_acct_segment6, --Legacy Location Value
                                                   p_legacy_intercompany_val => k.future_payment_acct_segment7, --Legacy Intercompany Value
                                                   p_legacy_division_val => k.future_payment_acct_segment10, --Legacy Division Value
                                                   p_item_number => NULL, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message

        xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxs3_ptp_suppliers_sites', p_stage_primary_col => 'xx_vendor_site_id', p_stage_primary_col_val => k.xx_vendor_site_id, p_stage_company_col => 's3_future_pmt_acct_segment1', p_stage_business_unit_col => 's3_future_pmt_acct_segment2', p_stage_department_col => 's3_future_pmt_acct_segment3', p_stage_account_col => 's3_future_pmt_acct_segment4', p_stage_product_line_col => 's3_future_pmt_acct_segment5', p_stage_location_col => 's3_future_pmt_acct_segment6', p_stage_intercompany_col => 's3_future_pmt_acct_segment7', p_stage_future_col => 's3_future_pmt_acct_segment8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);*/

        --24th November(New CoA mapping)
        xxs3_coa_transform_pkg.coa_transform(p_field_name => 'FUTURE_DATED_PAYMENT_CCID'
                                              ,p_legacy_company_val => k.future_payment_acct_segment1 --Legacy Company Value
                                              ,p_legacy_department_val => k.future_payment_acct_segment2 --Legacy Department Value
                                              ,p_legacy_account_val => k.future_payment_acct_segment3 --Legacy Account Value
                                              ,p_legacy_product_val => k.future_payment_acct_segment5 --Legacy Product Value
                                              ,p_legacy_location_val => k.future_payment_acct_segment6 --Legacy Location Value
                                              ,p_legacy_intercompany_val => k.future_payment_acct_segment7 --Legacy Intercompany Value
                                              ,p_legacy_division_val => k.future_payment_acct_segment10 --Legacy Division Value
                                              ,p_item_number => NULL
                                              ,p_s3_org => NULL
                                              ,p_trx_type => 'ALL'
                                              ,p_set_of_books_id => NULL
                                              ,p_debug_flag => 'N'
                                              ,p_s3_gl_string => l_s3_gl_string
                                              ,p_err_code => l_output_code
                                              ,p_err_msg => l_output);
                                              
          xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string, 
                                                  p_stage_tab => 'xxs3_ptp_suppliers_sites', 
                                                  p_stage_primary_col => 'xx_vendor_site_id', 
                                                  p_stage_primary_col_val => k.xx_vendor_site_id, 
                                                  p_stage_company_col => 's3_future_pmt_acct_segment1', 
                                                  p_stage_business_unit_col => 's3_future_pmt_acct_segment2', 
                                                  p_stage_department_col => 's3_future_pmt_acct_segment3', 
                                                  p_stage_account_col => 's3_future_pmt_acct_segment4', 
                                                  p_stage_product_line_col => 's3_future_pmt_acct_segment5',
                                                  p_stage_location_col => 's3_future_pmt_acct_segment6', 
                                                  p_stage_intercompany_col => 's3_future_pmt_acct_segment7', 
                                                  p_stage_future_col => 's3_future_pmt_acct_segment8', 
                                                  p_coa_err_msg => l_output, 
                                                  p_err_code => l_output_code_coa_update, 
                                                  p_err_msg => l_output_coa_update);                                    
                                              
       --24th November(New CoA mapping)                                       
      END IF;
      
      --CoA transformation

      --term transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'payment_terms_ptp', p_stage_tab => 'XXS3_PTP_SUPPLIERS_SITES', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_SITE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => k.xx_vendor_site_id, --Staging Table Primary Column Value
                                             p_legacy_val => k.terms, --Legacy Value
                                             p_stage_col => 'S3_TERMS', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --vendor_type_lookup_code transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'vendor_type_lookup_code', p_stage_tab => 'XXS3_PTP_SUPPLIERS_SITES', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_SITE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => k.xx_vendor_site_id, --Staging Table Primary Column Value
                                             p_legacy_val => k.vendor_type_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_VENDOR_TYPE_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --ship_via_lookup_code transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'ship_via_lookup_code', p_stage_tab => 'XXS3_PTP_SUPPLIERS_SITES', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_SITE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => k.xx_vendor_site_id, --Staging Table Primary Column Value
                                             p_legacy_val => k.ship_via_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_SHIP_VIA_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --freight_terms_lookup_code transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'freight_terms_lookup_code', p_stage_tab => 'XXS3_PTP_SUPPLIERS_SITES', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_SITE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => k.xx_vendor_site_id, --Staging Table Primary Column Value
                                             p_legacy_val => k.freight_terms_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_FREIGHT_TERMS_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --fob_lookup_code transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'fob_lookup_code', p_stage_tab => 'XXS3_PTP_SUPPLIERS_SITES', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_SITE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => k.xx_vendor_site_id, --Staging Table Primary Column Value
                                             p_legacy_val => k.fob_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_FOB_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --pay_group_lookup_code transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'pay_group_lookup_code', p_stage_tab => 'XXS3_PTP_SUPPLIERS_SITES', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_SITE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => k.xx_vendor_site_id, --Staging Table Primary Column Value
                                             p_legacy_val => k.pay_group_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_PAY_GROUP_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      /*--org_id transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type =>'operating_unit',
                                            p_stage_tab => 'XXS3_PTP_SUPPLIERS_SITES' ,          --Staging Table Name
                                            p_stage_primary_col =>'XX_VENDOR_SITE_ID' ,    --Staging Table Primary Column Name
                                            p_stage_primary_col_val=> k.xx_vendor_site_id, --Staging Table Primary Column Value
                                            p_legacy_val => k.org_id ,              --Legacy Value
                                            p_stage_col  => 'S3_ORG_ID',            --Staging Table Name
                                            p_err_code   => l_err_code ,                  -- Output error code
                                            p_err_msg   => l_err_msg ) ; */

      --ou
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'organization_name', p_stage_tab => 'XXS3_PTP_SUPPLIERS_SITES', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_SITE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => k.xx_vendor_site_id, --Staging Table Primary Column Value
                                             p_legacy_val => k.org_name, --Legacy Value
                                             p_stage_col => 'S3_ORG_NAME', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --tolerance transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'tolerance', p_stage_tab => 'XXS3_PTP_SUPPLIERS_SITES', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_SITE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => k.xx_vendor_site_id, --Staging Table Primary Column Value
                                             p_legacy_val => k.tolerance_name, --Legacy Value
                                             p_stage_col => 'S3_TOLERANCE_NAME', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --ship_to_location transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'location_code', p_stage_tab => 'XXS3_PTP_SUPPLIERS_SITES', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_SITE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => k.xx_vendor_site_id, --Staging Table Primary Column Value
                                             p_legacy_val => k.ship_to, --Legacy Value
                                             p_stage_col => 'S3_SHIP_TO', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --ship_to_location transformation

      --bill_to_location transformation
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'location_code', p_stage_tab => 'XXS3_PTP_SUPPLIERS_SITES', --Staging Table Name
                                             p_stage_primary_col => 'XX_VENDOR_SITE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => k.xx_vendor_site_id, --Staging Table Primary Column Value
                                             p_legacy_val => k.bill_to, --Legacy Value
                                             p_stage_col => 'S3_BILL_TO', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

    /* IF l_output_liability IS NOT NULL  and l_output_liability <> 'SUCCESS' THEN
                                                                                                                report_data_supplier('CoA_TRANSFORM',k.xx_vendor_site_id,k.vendor_site_id,l_output_liability,'LIABILITY_ACCOUNT');
                                                                                                               END IF;

                                                                                                               IF l_output_prepayment IS NOT NULL  and l_output_prepayment <> 'SUCCESS' THEN
                                                                                                                report_data_supplier('CoA_TRANSFORM',k.xx_vendor_site_id,k.vendor_site_id,l_output_prepayment,'PREPAYMENT_ACCOUNT');
                                                                                                               END IF;

                                                                                                               IF l_output_future IS NOT NULL  and l_output_future <> 'SUCCESS' THEN
                                                                                                                report_data_supplier('CoA_TRANSFORM',k.xx_vendor_site_id,k.vendor_site_id,l_output_future,'FUTURE_DATED_PAYMENT_CCID');
                                                                                                               END IF;  */

    END LOOP;

    FOR k IN cur_sup_site LOOP
      update_legacy_values(k.xx_vendor_site_id, NULL, k.vendor_name, NULL, /*k.terms,*/ k.address_line1, k.address_line2, k.address_line3, 'SITE');
    END LOOP;

    COMMIT;

    utl_file.put(l_file, ',' || 'XX_VENDOR_SITE_ID');
    utl_file.put(l_file, ',' || 'LIABILITY_ACCT_SEGMENT5');
    utl_file.put(l_file, ',' || ' S3_LIABILITY_ACCT_SEGMENT3 ');
    utl_file.new_line(l_file);
    FOR c1 IN c_utl_upload LOOP
      utl_file.put(l_file, ',' || c1.xx_vendor_site_id);
      utl_file.put(l_file, ',' || c1.liability_acct_segment5);
      utl_file.put(l_file, ',' || c1.s3_liability_acct_segment3);
      utl_file.new_line(l_file);
    END LOOP;
    utl_file.fclose(l_file);

  EXCEPTION

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

    /*fnd_file.put_line(fnd_file.output, 'Concurrent Request processed successfully');
    fnd_file.put_line(fnd_file.output, '--------------------------------------'); */
  END supplier_site_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  05/05/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE suppliers_cont_extract_data(x_errbuf  OUT VARCHAR2,
                                        x_retcode OUT NUMBER /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    p_only_dq IN VARCHAR2 DEFAULT 'N'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                p_email_id IN VARCHAR2,*/) IS

    --l_request_id         NUMBER := fnd_global.conc_request_id;
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_org_id             NUMBER := fnd_global.org_id;
    l_org_name           VARCHAR2(240) := fnd_global.org_name;

    CURSOR cur_ptp_suppliers_cont/*(p_vendor_id IN NUMBER)*/ IS(
      SELECT NULL vendor_contact_id,
             NULL vendor_site_id,
             hr.creation_date,
             hr.created_by,
             hr.end_date inactive_date,
             asp.vendor_id,
             asp.segment1 segment1,
             NULL address_name,
             --'Stratasys US OU' org_id,
             hprv.subject_person_first_name    person_first_name,
             hprv.subject_person_middle_name   person_middle_name,
             hprv.subject_person_last_name     person_last_name,
             hprv.subject_per_pre_name_adjunct person_pre_name_adjunct,
             -- hps.party_site_name address_name,
             -- hou.name Org_id ,
             hoc.job_title,
             hoc.mail_stop,
             xpcpv_phone.phone_area_code,
             xpcpv_phone.phone_number,
             hoc.department,
             xecpv.email_address,
             xecpv.email_format,
             pty_rel.url,
             xpcpv_mobile.phone_area_code alt_phone_area_code,
             xpcpv_mobile.phone_number alt_phone_number,
             xpcpv_fax.phone_area_code fax_area_code,
             xpcpv_fax.phone_number fax_number /*,
                                                                                                                                                                             person.party_id CONTACT_PARTY_ID */
      FROM   ap_suppliers               asp,
             hz_parties                 person,
             hz_parties                 pty_rel,
             hz_party_relationship_v    hprv,
             hz_parties                 pty_org,
             hz_org_contacts            hoc,
             xxhz_phone_contact_point_v xpcpv_phone,
             xxhz_phone_contact_point_v xpcpv_mobile,
             xxhz_phone_contact_point_v xpcpv_fax,
             xxs3_email_contact_point_v xecpv,
             hz_relationships           hr
      WHERE  asp.party_id = person.party_id
      AND    asp.party_id = pty_org.party_id
      AND    pty_rel.party_id = xpcpv_phone.owner_table_id(+)
      AND    pty_rel.party_id = xpcpv_mobile.owner_table_id(+)
      AND    pty_rel.party_id = xpcpv_fax.owner_table_id(+)
      AND    pty_rel.party_id = xecpv.owner_table_id(+)
      AND    xpcpv_phone.phone_line_type(+) = 'GEN'
      AND    xpcpv_phone.primary_flag(+) = 'Y'
      AND    xpcpv_mobile.phone_line_type(+) = 'GEN'
            --AND    xpcpv_mobile.phone_rownum(+) = 1
      AND    xpcpv_mobile.primary_flag(+) = 'N'
      AND    xpcpv_fax.phone_line_type(+) = 'FAX'
      AND    xpcpv_fax.primary_flag(+) = 'N'
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
            --AND    hr.subject_id = person.party_id
      AND    hr.subject_id = asp.party_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    nvl(hr.end_date, SYSDATE + 1) > SYSDATE
      AND    hprv.party_id = pty_rel.party_id
      AND    hprv.object_id = asp.party_id
      AND    hoc.party_relationship_id = hprv.party_relationship_id
      AND    person.status = 'A'
      AND    pty_rel.status = 'A'
      AND    pty_org.status = 'A'
      --AND    asp.vendor_id = p_vendor_id
      AND EXISTS (SELECT vendor_id
             FROM xxs3_ptp_suppliers
             WHERE process_flag <> 'R'
             AND vendor_id = asp.vendor_id)
      AND    pty_rel.created_by_module IN
             ('AP_SUPPLIERS_API', 'POS_SUPPLIER_MGMT')
      --AND    asp.segment1='38'

      MINUS
      SELECT NULL vendor_contact_id,
             NULL vendor_site_id,
             hr.creation_date,
             hr.created_by,
             hr.end_date inactive_date,
             asp.vendor_id,
             asp.segment1 segment1,
             NULL address_name,
             --hou.name Org_id ,
             person.person_first_name,
             person.person_middle_name,
             person.person_last_name,
             person.person_pre_name_adjunct,
             hoc.job_title,
             hoc.mail_stop,
             xpcpv_phone.phone_area_code,
             xpcpv_phone.phone_number,
             hoc.department,
             xecpv.email_address,
             xecpv.email_format,
             pty_rel.url,
             xpcpv_mobile.phone_area_code alt_phone_area_code,
             xpcpv_mobile.phone_number alt_phone_number,
             xpcpv_fax.phone_area_code fax_area_code,
             xpcpv_fax.phone_number fax_number /*,
                                                                                                                                                                             person.party_id CONTACT_PARTY_ID */
      FROM   ap_suppliers               asp,
             ap_supplier_sites_all      ass,
             ap_supplier_contacts       apsc,
             hz_parties                 person,
             hz_parties                 pty_rel,
             hr_operating_units         hou,
             hz_org_contacts            hoc,
             xxhz_phone_contact_point_v xpcpv_phone,
             xxhz_phone_contact_point_v xpcpv_mobile,
             xxhz_phone_contact_point_v xpcpv_fax,
             xxs3_email_contact_point_v xecpv,
             hz_relationships           hr,
             hz_party_sites             hps
      WHERE  ass.vendor_id = asp.vendor_id
      AND    apsc.per_party_id = person.party_id
      AND    apsc.rel_party_id = pty_rel.party_id
      AND    ass.org_id = hou.organization_id
      AND    apsc.org_party_site_id = ass.party_site_id
      AND    pty_rel.party_id = xpcpv_phone.owner_table_id(+)
      AND    pty_rel.party_id = xpcpv_mobile.owner_table_id(+)
      AND    pty_rel.party_id = xpcpv_fax.owner_table_id(+)
      AND    pty_rel.party_id = xecpv.owner_table_id(+)
      AND    xpcpv_phone.phone_line_type(+) = 'GEN'
      AND    xpcpv_phone.primary_flag(+) = 'Y'
            --AND    xpcpv_phone.phone_rownum(+) = 1
      AND    xpcpv_mobile.phone_line_type(+) = 'GEN'
            --AND    xpcpv_mobile.phone_rownum(+) = 1
      AND    xpcpv_mobile.primary_flag(+) = 'N'
      AND    xpcpv_fax.phone_line_type(+) = 'FAX'
            --AND    xpcpv_fax.phone_rownum(+) = 1
      AND    xpcpv_fax.primary_flag(+) = 'N'
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
      AND    hr.subject_id = asp.party_id
      AND    hr.object_id = person.party_id
      AND    hr.party_id = pty_rel.party_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    ass.party_site_id = hps.party_site_id
      AND    nvl(hr.end_date, SYSDATE + 1) > SYSDATE
            --AND    hou.name = 'Stratasys US OU'
      AND    ass.org_id = l_org_id
            --AND    asp.segment1='38'
      AND    nvl(apsc.inactive_date, SYSDATE + 1) > SYSDATE
      AND    person.status = 'A'
      AND    pty_rel.status = 'A'
      AND    nvl(hps.status, 'A') = 'A'
      AND EXISTS (SELECT vendor_id
             FROM xxs3_ptp_suppliers
             WHERE process_flag <> 'R'
             AND vendor_id = asp.vendor_id)
      /*AND    asp.vendor_id = p_vendor_id*/)

      UNION

      SELECT apsc.vendor_contact_id,
             apsc.vendor_site_id,
             hr.creation_date,
             hr.created_by,
             hr.end_date inactive_date,
             asp.vendor_id,
             asp.segment1 segment1,
             hps.party_site_name address_name,
             --hou.name Org_id ,
             person.person_first_name,
             person.person_middle_name,
             person.person_last_name,
             person.person_pre_name_adjunct,
             hoc.job_title,
             hoc.mail_stop,
             xpcpv_phone.phone_area_code,
             xpcpv_phone.phone_number,
             hoc.department,
             xecpv.email_address,
             xecpv.email_format,
             pty_rel.url,
             xpcpv_mobile.phone_area_code alt_phone_area_code,
             xpcpv_mobile.phone_number alt_phone_number,
             xpcpv_fax.phone_area_code fax_area_code,
             xpcpv_fax.phone_number fax_number /*,
                                                                                                                                                                             person.party_id CONTACT_PARTY_ID */
      FROM   ap_suppliers               asp,
             ap_supplier_sites_all      ass,
             ap_supplier_contacts       apsc,
             hz_parties                 person,
             hz_parties                 pty_rel,
             hr_operating_units         hou,
             hz_org_contacts            hoc,
             xxhz_phone_contact_point_v xpcpv_phone,
             xxhz_phone_contact_point_v xpcpv_mobile,
             xxhz_phone_contact_point_v xpcpv_fax,
             xxs3_email_contact_point_v xecpv,
             hz_relationships           hr,
             hz_party_sites             hps
      WHERE  ass.vendor_id = asp.vendor_id
      AND    apsc.per_party_id = person.party_id
      AND    apsc.rel_party_id = pty_rel.party_id
      AND    ass.org_id = hou.organization_id
      AND    apsc.org_party_site_id = ass.party_site_id
      AND    pty_rel.party_id = xpcpv_phone.owner_table_id(+)
      AND    pty_rel.party_id = xpcpv_mobile.owner_table_id(+)
      AND    pty_rel.party_id = xpcpv_fax.owner_table_id(+)
      AND    pty_rel.party_id = xecpv.owner_table_id(+)
      AND    xpcpv_phone.phone_line_type(+) = 'GEN'
      AND    xpcpv_phone.primary_flag(+) = 'Y'
            --AND    xpcpv_phone.phone_rownum(+) = 1
      AND    xpcpv_mobile.phone_line_type(+) = 'GEN'
            --AND    xpcpv_mobile.phone_rownum(+) = 1
      AND    xpcpv_mobile.primary_flag(+) = 'N'
      AND    xpcpv_fax.phone_line_type(+) = 'FAX'
            --AND    xpcpv_fax.phone_rownum(+) = 1
      AND    xpcpv_fax.primary_flag(+) = 'N'
      AND    xecpv.contact_point_type(+) = 'EMAIL'
      AND    xecpv.email_rownum(+) = 1
      AND    hr.subject_id = asp.party_id
      AND    hr.object_id = person.party_id
      AND    hr.party_id = pty_rel.party_id
      AND    hoc.party_relationship_id = hr.relationship_id
      AND    ass.party_site_id = hps.party_site_id
      AND    nvl(hr.end_date, SYSDATE + 1) > SYSDATE
      AND    ass.org_id = l_org_id
            --AND    hou.name = 'Stratasys US OU'
            --AND    asp.segment1='38'
      AND    nvl(apsc.inactive_date, SYSDATE + 1) > SYSDATE
      AND    person.status = 'A'
      AND    pty_rel.status = 'A'
      AND    nvl(hps.status, 'A') = 'A'
      AND EXISTS (SELECT vendor_id
             FROM xxs3_ptp_suppliers
             WHERE process_flag <> 'R'
             AND vendor_id = asp.vendor_id);
      --AND    asp.vendor_id = p_vendor_id;

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptp_suppliers_cont';

    --FOR m IN cur_valid_suppliers LOOP
      FOR i IN cur_ptp_suppliers_cont/*(m.vendor_id)*/ LOOP

        INSERT INTO xxs3_ptp_suppliers_cont
        VALUES
          (xxobjt.xxs3_ptp_suppliers_cont_seq.NEXTVAL,
           SYSDATE,
           'N',
           NULL,
           NULL,
           i.vendor_contact_id,
           i.vendor_site_id,
           i.creation_date,
           i.created_by,
           i.inactive_date,
           i.vendor_id,
           i.segment1,
           i.address_name,
           --i.org_id,
           l_org_name,
           i.person_first_name,
           i.person_middle_name,
           i.person_last_name,
           i.person_pre_name_adjunct,
           i.job_title,
           i.mail_stop,
           i.phone_area_code,
           i.phone_number,
           i.department,
           i.email_address,
           i.email_format,
           i.url,
           i.alt_phone_area_code,
           i.alt_phone_number,
           i.fax_area_code,
           i.fax_number,
           NULL,
           NULL,
           NULL,
           NULL);

      END LOOP;
    --END LOOP;
    COMMIT;
    --END IF;
    fnd_file.put_line(fnd_file.log, 'Loading complete');

    -- DQ check supplier
    quality_check_supplier_cont;
    fnd_file.put_line(fnd_file.log, 'DQ complete');

  EXCEPTION

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');
      
  END suppliers_cont_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  05/05/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE suppliers_bank_extract_data(x_errbuf  OUT VARCHAR2,
                                        x_retcode OUT NUMBER /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    p_only_dq IN VARCHAR2 DEFAULT 'N'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                p_email_id IN VARCHAR2,*/) IS

    --l_request_id         NUMBER := fnd_global.conc_request_id;
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_org_id             NUMBER := fnd_global.org_id;
    

    CURSOR cur_ptp_suppliers_bank/*(p_vendor_id IN NUMBER)*/ IS
      SELECT hzpbank.party_id     bank_party_id,
             aps.vendor_id        vendor_id,
             ass.vendor_site_id   vendor_site_id,
             aps.segment1         segment1,
             ass.vendor_site_code vendor_site_code,
             hps.party_site_name  address_name,
             --ASS.COUNTRY COUNTRY,
             ieb.country_code country,
             'Site' assignment_level,
             hzpbank.party_name bank_name,
             --HZPBRANCH.PARTY_NAME BRANCH_NAME,
             iebb.bank_branch_name branch_name,
             ieb.bank_account_num account_number,
             ieb.bank_account_name account_name,
             ieb.check_digits check_digits,
             ieb.currency_code currency,
             ieb.iban iban,
             ieb.foreign_payment_use_flag allow_international_payments,
             trunc(ipi.start_date) start_date,
             trunc(ipi.end_date) end_date
      FROM   hz_parties               hzp,
             ap_suppliers             aps,
             hz_party_sites           site_supp,
             ap_supplier_sites_all    ass,
             iby_external_payees_all  iep,
             iby_pmt_instr_uses_all   ipi,
             iby_ext_bank_accounts    ieb,
             hz_parties               hzpbank,
             hz_parties               hzpbranch,
             hz_organization_profiles hopbank,
             hz_organization_profiles hopbranch,
             hr_operating_units       hou,
             hz_party_sites           hps,
             iby_ext_bank_branches_v  iebb
      WHERE  hzp.party_id = aps.party_id
      AND    hzp.party_id = site_supp.party_id
      AND    site_supp.party_site_id = ass.party_site_id
      AND    ass.vendor_id = aps.vendor_id
      AND    iep.payee_party_id = hzp.party_id
      AND    iep.party_site_id = site_supp.party_site_id
      AND    iep.supplier_site_id = ass.vendor_site_id
      AND    iep.ext_payee_id = ipi.ext_pmt_party_id
      AND    ipi.instrument_id = ieb.ext_bank_account_id
      AND    ieb.bank_id = hzpbank.party_id
      AND    ieb.bank_id = hzpbranch.party_id
      AND    hzpbranch.party_id = hopbranch.party_id
      AND    hzpbank.party_id = hopbank.party_id
      AND    SYSDATE BETWEEN nvl(ieb.start_date, SYSDATE) AND
             nvl(ieb.end_date, SYSDATE)
      AND    SYSDATE BETWEEN nvl(ipi.start_date, SYSDATE) AND
             nvl(ipi.end_date, SYSDATE)
      AND    SYSDATE BETWEEN trunc(hopbank.effective_start_date(+)) AND
             nvl(trunc(hopbank.effective_end_date(+)), SYSDATE + 1)
      AND    ass.vendor_id = aps.vendor_id
      AND    ass.org_id = hou.organization_id
            --AND HOU.NAME = 'Stratasys US OU'
      AND    ass.org_id = l_org_id
      AND    ass.party_site_id = hps.party_site_id
      --AND    aps.vendor_id = p_vendor_id
      AND    ieb.branch_id = iebb.branch_party_id
      AND    SYSDATE BETWEEN trunc(iebb.start_date) AND
             nvl(trunc(iebb.end_date), SYSDATE + 1)
      AND    nvl(ass.inactive_date, SYSDATE + 1) > SYSDATE
      AND    nvl(hopbank.effective_end_date, SYSDATE + 1) > SYSDATE
      AND    nvl(hopbranch.effective_end_date, SYSDATE + 1) > SYSDATE
      AND EXISTS (SELECT vendor_id
             FROM xxs3_ptp_suppliers
             WHERE process_flag <> 'R'
             AND vendor_id = aps.vendor_id)
      AND EXISTS (SELECT vendor_site_id
             FROM xxs3_ptp_suppliers_sites
             WHERE process_flag <> 'R'
             AND vendor_site_id = ass.vendor_site_id)
      --and ASS.ORG_ID=123
      --AND APS.SEGMENT1=11034
      --and APS.SEGMENT1=30112

      UNION
      SELECT hzpbank.party_id bank_party_id,
             aps.vendor_id    vendor_id,
             NULL             vendor_site_id,
             aps.segment1     segment1,
             NULL             vendor_site_code,
             NULL             address_name,
             --NULL COUNTRY,
             ieb.country_code country,
             'Supplier' assignment_level,
             hzpbank.party_name bank_name,
             --HZPBRANCH.PARTY_NAME BRANCH_NAME,
             iebb.bank_branch_name branch_name,
             ieb.bank_account_num account_number,
             ieb.bank_account_name account_name,
             ieb.check_digits,
             ieb.currency_code currency,
             ieb.iban,
             ieb.foreign_payment_use_flag allow_international_payments,
             trunc(ipi.start_date) start_date,
             trunc(ipi.end_date) end_date
      FROM   apps.hz_parties               hzp,
             apps.ap_suppliers             aps,
             apps.iby_external_payees_all  iep,
             apps.iby_pmt_instr_uses_all   ipi,
             apps.iby_ext_bank_accounts    ieb,
             apps.hz_parties               hzpbank,
             apps.hz_parties               hzpbranch,
             apps.hz_organization_profiles hopbank,
             apps.hz_organization_profiles hopbranch,
             hr_operating_units            hou,
             ap_supplier_sites_all         ass,
             iby_ext_bank_branches_v       iebb
      WHERE  hzp.party_id = aps.party_id
      AND    iep.payee_party_id = hzp.party_id
      AND    iep.ext_payee_id = ipi.ext_pmt_party_id
      AND    ipi.instrument_id = ieb.ext_bank_account_id
      AND    ieb.bank_id = hzpbank.party_id
      AND    ieb.bank_id = hzpbranch.party_id
      AND    hzpbranch.party_id = hopbranch.party_id
      AND    hzpbank.party_id = hopbank.party_id
      AND    iep.supplier_site_id IS NULL
      AND    iep.party_site_id IS NULL
      AND    SYSDATE BETWEEN nvl(ieb.start_date, SYSDATE) AND
             nvl(ieb.end_date, SYSDATE)
      AND    SYSDATE BETWEEN nvl(ipi.start_date, SYSDATE) AND
             nvl(ipi.end_date, SYSDATE)
      AND    SYSDATE BETWEEN trunc(hopbank.effective_start_date(+)) AND
             nvl(trunc(hopbank.effective_end_date(+)), SYSDATE + 1)
      AND    ass.vendor_id(+) = aps.vendor_id
      AND    ass.org_id = hou.organization_id
            --AND HOU.NAME = 'Stratasys US OU'
      AND    ass.org_id = l_org_id
      --AND    aps.vendor_id = p_vendor_id
      AND    ieb.branch_id = iebb.branch_party_id
      AND    SYSDATE BETWEEN trunc(iebb.start_date) AND
             nvl(trunc(iebb.end_date), SYSDATE + 1)
      AND    nvl(ass.inactive_date, SYSDATE + 1) > SYSDATE
      AND    nvl(hopbank.effective_end_date, SYSDATE + 1) > SYSDATE
      AND    nvl(hopbranch.effective_end_date, SYSDATE + 1) > SYSDATE
      AND EXISTS (SELECT vendor_id
             FROM xxs3_ptp_suppliers
             WHERE process_flag <> 'R'
             AND vendor_id = aps.vendor_id)
      -- AND APS.SEGMENT1=11034
      --ORDER BY 1
      UNION
      SELECT hzpbank.party_id bank_party_id,
             aps.vendor_id    vendor_id,
             NULL             vendor_site_id,
             aps.segment1     segment1,
             NULL             vendor_site_code,
             NULL             address_name,
             --NULL COUNTRY,
             ieb.country_code country,
             'Address - Operating Unit' assignment_level,
             hzpbank.party_name bank_name,
             --HZPBRANCH.PARTY_NAME BRANCH_NAME,
             iebb.bank_branch_name branch_name,
             ieb.bank_account_num account_number,
             ieb.bank_account_name account_name,
             ieb.check_digits,
             ieb.currency_code currency,
             ieb.iban,
             ieb.foreign_payment_use_flag allow_international_payments,
             trunc(ipi.start_date) start_date,
             trunc(ipi.end_date) end_date
      FROM   apps.hz_parties               hzp,
             apps.ap_suppliers             aps,
             apps.iby_external_payees_all  iep,
             apps.iby_pmt_instr_uses_all   ipi,
             apps.iby_ext_bank_accounts    ieb,
             apps.hz_parties               hzpbank,
             apps.hz_parties               hzpbranch,
             apps.hz_organization_profiles hopbank,
             apps.hz_organization_profiles hopbranch,
             apps.hz_party_sites           hps,
             hr_operating_units            hou,
             ap_supplier_sites_all         ass,
             iby_ext_bank_branches_v       iebb
      WHERE  hzp.party_id = aps.party_id
      AND    iep.payee_party_id = hzp.party_id
      AND    iep.ext_payee_id = ipi.ext_pmt_party_id
      AND    ipi.instrument_id = ieb.ext_bank_account_id
      AND    ieb.bank_id = hzpbank.party_id
      AND    ieb.bank_id = hzpbranch.party_id
      AND    hzpbranch.party_id = hopbranch.party_id
      AND    hzpbank.party_id = hopbank.party_id
      AND    aps.party_id = hps.party_id
      AND    hps.party_site_id = iep.party_site_id
      AND    iep.supplier_site_id IS NULL
      AND    iep.org_id IS NOT NULL
      AND    SYSDATE BETWEEN nvl(ieb.start_date, SYSDATE) AND
             nvl(ieb.end_date, SYSDATE)
      AND    SYSDATE BETWEEN nvl(ipi.start_date, SYSDATE) AND
             nvl(ipi.end_date, SYSDATE)
      AND    SYSDATE BETWEEN trunc(hopbank.effective_start_date(+)) AND
             nvl(trunc(hopbank.effective_end_date(+)), SYSDATE + 1)
      AND    ass.vendor_id(+) = aps.vendor_id
      AND    ass.org_id = hou.organization_id
            --AND HOU.NAME = 'Stratasys US OU'
      AND    ass.org_id = l_org_id
      --AND    aps.vendor_id = p_vendor_id
      AND    ieb.branch_id = iebb.branch_party_id
      AND    SYSDATE BETWEEN trunc(iebb.start_date) AND
             nvl(trunc(iebb.end_date), SYSDATE + 1)
      AND    nvl(ass.inactive_date, SYSDATE + 1) > SYSDATE
      AND    nvl(hopbank.effective_end_date, SYSDATE + 1) > SYSDATE
      AND    nvl(hopbranch.effective_end_date, SYSDATE + 1) > SYSDATE
      AND EXISTS (SELECT vendor_id
             FROM xxs3_ptp_suppliers
             WHERE process_flag <> 'R'
             AND vendor_id = aps.vendor_id)
      UNION
      SELECT hzpbank.party_id bank_party_id,
             aps.vendor_id    vendor_id,
             NULL             vendor_site_id,
             aps.segment1     segment1,
             NULL             vendor_site_code,
             NULL             address_name,
             --NULL COUNTRY,
             ieb.country_code country,
             'Address' assignment_level,
             hzpbank.party_name bank_name,
             --HZPBRANCH.PARTY_NAME BRANCH_NAME,
             iebb.bank_branch_name branch_name,
             ieb.bank_account_num account_number,
             ieb.bank_account_name account_name,
             ieb.check_digits,
             ieb.currency_code currency,
             ieb.iban,
             ieb.foreign_payment_use_flag allow_international_payments,
             trunc(ipi.start_date) start_date,
             trunc(ipi.end_date) end_date
      FROM   apps.hz_parties               hzp,
             apps.ap_suppliers             aps,
             apps.iby_external_payees_all  iep,
             apps.iby_pmt_instr_uses_all   ipi,
             apps.iby_ext_bank_accounts    ieb,
             apps.hz_parties               hzpbank,
             apps.hz_parties               hzpbranch,
             apps.hz_organization_profiles hopbank,
             apps.hz_organization_profiles hopbranch,
             apps.hz_party_sites           hps,
             hr_operating_units            hou,
             ap_supplier_sites_all         ass,
             iby_ext_bank_branches_v       iebb
      WHERE  hzp.party_id = aps.party_id
      AND    iep.payee_party_id = hzp.party_id
      AND    iep.ext_payee_id = ipi.ext_pmt_party_id
      AND    ipi.instrument_id = ieb.ext_bank_account_id
      AND    ieb.bank_id = hzpbank.party_id
      AND    ieb.bank_id = hzpbranch.party_id
      AND    hzpbranch.party_id = hopbranch.party_id
      AND    hzpbank.party_id = hopbank.party_id
      AND    aps.party_id = hps.party_id
      AND    hps.party_site_id = iep.party_site_id
      AND    iep.supplier_site_id IS NULL
      AND    iep.org_id IS NULL
      AND    SYSDATE BETWEEN nvl(ieb.start_date, SYSDATE) AND
             nvl(ieb.end_date, SYSDATE)
      AND    SYSDATE BETWEEN nvl(ipi.start_date, SYSDATE) AND
             nvl(ipi.end_date, SYSDATE)
      AND    SYSDATE BETWEEN trunc(hopbank.effective_start_date(+)) AND
             nvl(trunc(hopbank.effective_end_date(+)), SYSDATE + 1)
      AND    ass.vendor_id(+) = aps.vendor_id
      AND    ass.org_id = hou.organization_id
            --AND HOU.NAME = 'Stratasys US OU'
      AND    ass.org_id = l_org_id
      --AND    aps.vendor_id = p_vendor_id
      AND    ieb.branch_id = iebb.branch_party_id
      AND    SYSDATE BETWEEN trunc(iebb.start_date) AND
             nvl(trunc(iebb.end_date), SYSDATE + 1)
      AND    nvl(ass.inactive_date, SYSDATE + 1) > SYSDATE
      AND    nvl(hopbank.effective_end_date, SYSDATE + 1) > SYSDATE
      AND    nvl(hopbranch.effective_end_date, SYSDATE + 1) > SYSDATE
      AND EXISTS (SELECT vendor_id
             FROM xxs3_ptp_suppliers
             WHERE process_flag <> 'R'
             AND vendor_id = aps.vendor_id)
      /*AND EXISTS (SELECT party_site_name
             FROM xxs3_ptp_suppliers_sites
             WHERE process_flag <> 'R'
             AND vendor_site_id = ass.vendor_site_id)*/
      ORDER  BY 1;

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptp_supplier_bank';

    --FOR m IN cur_valid_suppliers LOOP

      FOR i IN cur_ptp_suppliers_bank/*(m.vendor_id)*/ LOOP

        INSERT INTO xxs3_ptp_supplier_bank
        VALUES
          (xxobjt.xxs3_ptp_supplier_bank_seq.NEXTVAL,
           SYSDATE,
           'N',
           NULL,
           NULL,
           i.bank_party_id,
           i.vendor_id,
           i.vendor_site_id,
           i.segment1,
           i.vendor_site_code,
           i.country,
           i.assignment_level,
           i.bank_name,
           --NULL,
           i.branch_name,
           i.account_number,
           i.account_name,
           i.check_digits,
           i.currency,
           i.iban,
           i.allow_international_payments,
           i.start_date,
           i.end_date,
           NULL,
           NULL,
           NULL,
           NULL);

      END LOOP;
    --END LOOP;
    COMMIT;
    --END IF;
    fnd_file.put_line(fnd_file.log, 'Loading complete');

  EXCEPTION

    WHEN report_error THEN
      fnd_file.put_line(fnd_file.log, 'Failed to generate report');
      x_retcode := 1;
      x_errbuf  := 'Unexpected error: report error';

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');
      
  END suppliers_bank_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  05/05/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bank_details_extract_data(x_errbuf  OUT VARCHAR2,
                                      x_retcode OUT NUMBER) IS

    --l_request_id         NUMBER := fnd_global.conc_request_id;
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_file               utl_file.file_type;
    l_file_path          VARCHAR2(100);
    l_file_name          VARCHAR2(100);

    CURSOR cur_rtr_bank_dtls IS
      SELECT iebv.bank_party_id bank_party_id,
             iebv.home_country home_country,
             iebv.bank_name bank_name,
             iebv.bank_number bank_number,
             iebv.bank_institution_type bank_institution_type,
             iebv.bank_name_alt bank_name_alt,
             iebv.short_bank_name short_bank_name,
             iebv.description description,
             iebv.end_date end_date,
             iebv.address1 address_line1,
             iebv.address2 address_line2,
             iebv.address3 address_line3,
             iebv.city city,
             iebv.state state,
             iebv.postal_code zip,
             iebv.country country,
             iebv.tax_payer_id tax_payer_id,
             hp.attribute_category,
             hp.attribute1,
             hp.attribute2,
             hp.attribute3,
             hp.attribute4,
             hp.attribute5,
             hp.attribute6,
             hp.attribute7,
             hp.attribute8,
             hp.attribute9,
             hp.attribute10,
             hp.attribute11,
             hp.attribute12,
             hp.attribute13,
             hp.attribute14,
             hp.attribute15,
             hp.attribute16,
             hp.attribute17,
             hp.attribute18,
             hp.attribute19,
             hp.attribute20,
             hp.attribute21,
             hp.attribute22,
             hp.attribute23,
             hp.attribute24
      FROM   iby_ext_banks_v iebv,
             hz_parties      hp
      WHERE  iebv.bank_party_id = hp.party_id
      AND    nvl(iebv.end_date, SYSDATE + 1) > SYSDATE
      AND    hp.status = 'A';

    CURSOR c_bank_details_extract_upload IS
      SELECT *
      FROM   xxobjt.xxs3_rtr_bank;

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';

    BEGIN
      --Get the file path from the lookup
      SELECT TRIM(' ' FROM meaning)
      INTO   l_file_path
      FROM   fnd_lookup_values_vl
      WHERE  lookup_type = 'XXS3_ITEM_OUT_FILE_PATH';

      --Get the file name
      l_file_name := 'Bank_Master_Extract' || '_' || SYSDATE || '.xls';

      --Get the utl file open
      l_file := utl_file.fopen(l_file_path, l_file_name, 'w', 32767);
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Invalid File Path' || SQLERRM);
        NULL;
    END;

    --l_file := UTL_FILE.FOPEN('/UtlFiles/shared/DEV','BANK_DETAILS_EXTRACT.CSV','w',32767);

    DELETE FROM xxobjt.xxs3_rtr_bank;

    --IF p_only_dq = 'N' THEN

    FOR i IN cur_rtr_bank_dtls LOOP

      INSERT INTO xxs3_rtr_bank
      VALUES
        (xxobjt.xxs3_ptp_supplier_bank_seq.NEXTVAL,
         SYSDATE,
         'N',
         NULL,
         NULL,
         i.bank_party_id,
         i.home_country,
         i.bank_name,
         i.bank_number,
         i.bank_institution_type,
         i.bank_name_alt,
         i.short_bank_name,
         i.description,
         i.end_date,
         i.address_line1,
         i.address_line2,
         i.address_line3,
         i.city,
         i.state,
         i.zip,
         i.country,
         i.tax_payer_id,
         i.attribute_category,
         i.attribute1,
         i.attribute2,
         i.attribute3,
         i.attribute4,
         i.attribute5,
         i.attribute6,
         i.attribute7,
         i.attribute8,
         i.attribute9,
         i.attribute10,
         i.attribute11,
         i.attribute12,
         i.attribute13,
         i.attribute14,
         i.attribute15,
         i.attribute16,
         i.attribute17,
         i.attribute18,
         i.attribute19,
         i.attribute20,
         i.attribute21,
         i.attribute22,
         i.attribute23,
         i.attribute24,
         NULL,
         NULL);

    END LOOP;
    COMMIT;

    --generate csv

    utl_file.put(l_file, '~' || 'XX_BANK_PARTY_ID');
    utl_file.put(l_file, '~' || 'DATE_EXTRACTED_ON');
    utl_file.put(l_file, '~' || 'PROCESS_FLAG');
    utl_file.put(l_file, '~' || 'S3_BANK_PARTY_ID');
    utl_file.put(l_file, '~' || 'NOTES');
    utl_file.put(l_file, '~' || 'BANK_PARTY_ID');
    utl_file.put(l_file, '~' || 'HOME_COUNTRY');
    utl_file.put(l_file, '~' || 'BANK_NAME');
    utl_file.put(l_file, '~' || 'BANK_NUMBER');
    utl_file.put(l_file, '~' || 'BANK_INSTITUTION_TYPE');
    utl_file.put(l_file, '~' || 'BANK_NAME_ALT');
    utl_file.put(l_file, '~' || 'SHORT_BANK_NAME');
    utl_file.put(l_file, '~' || 'DESCRIPTION');
    utl_file.put(l_file, '~' || 'END_DATE');
    utl_file.put(l_file, '~' || 'ADDRESS_LINE1');
    utl_file.put(l_file, '~' || 'ADDRESS_LINE2');
    utl_file.put(l_file, '~' || 'ADDRESS_LINE3');
    utl_file.put(l_file, '~' || 'CITY');
    utl_file.put(l_file, '~' || 'STATE');
    utl_file.put(l_file, '~' || 'ZIP');
    utl_file.put(l_file, '~' || 'COUNTRY');
    utl_file.put(l_file, '~' || 'TAX_PAYER_ID');
    utl_file.put(l_file, '~' || 'ATTRIBUTE_CATEGORY');
    utl_file.put(l_file, '~' || 'ATTRIBUTE1');
    utl_file.put(l_file, '~' || 'ATTRIBUTE2');
    utl_file.put(l_file, '~' || 'ATTRIBUTE3');
    utl_file.put(l_file, '~' || 'ATTRIBUTE4');
    utl_file.put(l_file, '~' || 'ATTRIBUTE5');
    utl_file.put(l_file, '~' || 'ATTRIBUTE6');
    utl_file.put(l_file, '~' || 'ATTRIBUTE7');
    utl_file.put(l_file, '~' || 'ATTRIBUTE8');
    utl_file.put(l_file, '~' || 'ATTRIBUTE9');
    utl_file.put(l_file, '~' || 'ATTRIBUTE10');
    utl_file.put(l_file, '~' || 'ATTRIBUTE11');
    utl_file.put(l_file, '~' || 'ATTRIBUTE12');
    utl_file.put(l_file, '~' || 'ATTRIBUTE13');
    utl_file.put(l_file, '~' || 'ATTRIBUTE14');
    utl_file.put(l_file, '~' || 'ATTRIBUTE15');
    utl_file.put(l_file, '~' || 'ATTRIBUTE16');
    utl_file.put(l_file, '~' || 'ATTRIBUTE17');
    utl_file.put(l_file, '~' || 'ATTRIBUTE18');
    utl_file.put(l_file, '~' || 'ATTRIBUTE19');
    utl_file.put(l_file, '~' || 'ATTRIBUTE20');
    utl_file.put(l_file, '~' || 'ATTRIBUTE21');
    utl_file.put(l_file, '~' || 'ATTRIBUTE22');
    utl_file.put(l_file, '~' || 'ATTRIBUTE23');
    utl_file.put(l_file, '~' || 'ATTRIBUTE24');
    utl_file.new_line(l_file);

    FOR c1 IN c_bank_details_extract_upload LOOP
      utl_file.put(l_file, '~' || c1.xx_bank_party_id);
      utl_file.put(l_file, '~' || c1.date_extracted_on);
      utl_file.put(l_file, '~' || c1.process_flag);
      utl_file.put(l_file, '~' || c1.s3_bank_party_id);
      utl_file.put(l_file, '~' || c1.notes);
      utl_file.put(l_file, '~' || c1.bank_party_id);
      utl_file.put(l_file, '~' || c1.home_country);
      utl_file.put(l_file, '~' || c1.bank_name);
      utl_file.put(l_file, '~' || c1.bank_number);
      utl_file.put(l_file, '~' || c1.bank_institution_type);
      utl_file.put(l_file, '~' || c1.bank_name_alt);
      utl_file.put(l_file, '~' || c1.short_bank_name);
      utl_file.put(l_file, '~' || c1.description);
      utl_file.put(l_file, '~' || c1.end_date);
      utl_file.put(l_file, '~' || c1.address_line1);
      utl_file.put(l_file, '~' || c1.address_line2);
      utl_file.put(l_file, '~' || c1.address_line3);
      utl_file.put(l_file, '~' || c1.city);
      utl_file.put(l_file, '~' || c1.state);
      utl_file.put(l_file, '~' || c1.zip);
      utl_file.put(l_file, '~' || c1.country);
      utl_file.put(l_file, '~' || c1.tax_payer_id);
      utl_file.put(l_file, '~' || c1.attribute_category);
      utl_file.put(l_file, '~' || c1.attribute1);
      utl_file.put(l_file, '~' || c1.attribute2);
      utl_file.put(l_file, '~' || c1.attribute3);
      utl_file.put(l_file, '~' || c1.attribute4);
      utl_file.put(l_file, '~' || c1.attribute5);
      utl_file.put(l_file, '~' || c1.attribute6);
      utl_file.put(l_file, '~' || c1.attribute7);
      utl_file.put(l_file, '~' || c1.attribute8);
      utl_file.put(l_file, '~' || c1.attribute9);
      utl_file.put(l_file, '~' || c1.attribute10);
      utl_file.put(l_file, '~' || c1.attribute11);
      utl_file.put(l_file, '~' || c1.attribute12);
      utl_file.put(l_file, '~' || c1.attribute13);
      utl_file.put(l_file, '~' || c1.attribute14);
      utl_file.put(l_file, '~' || c1.attribute15);
      utl_file.put(l_file, '~' || c1.attribute16);
      utl_file.put(l_file, '~' || c1.attribute17);
      utl_file.put(l_file, '~' || c1.attribute18);
      utl_file.put(l_file, '~' || c1.attribute19);
      utl_file.put(l_file, '~' || c1.attribute20);
      utl_file.put(l_file, '~' || c1.attribute21);
      utl_file.put(l_file, '~' || c1.attribute22);
      utl_file.put(l_file, '~' || c1.attribute23);
      utl_file.put(l_file, '~' || c1.attribute24);
      utl_file.new_line(l_file);
    END LOOP;
    utl_file.fclose(l_file);

    --END IF;
    fnd_file.put_line(fnd_file.log, 'Loading complete');

  EXCEPTION

    WHEN report_error THEN
      fnd_file.put_line(fnd_file.log, 'Failed to generate report');
      x_retcode := 1;
      x_errbuf  := 'Unexpected error: report error';

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

  END bank_details_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  05/05/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bank_branches_extract_data(x_errbuf  OUT VARCHAR2,
                                       x_retcode OUT NUMBER) IS

    --l_request_id         NUMBER := fnd_global.conc_request_id;
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_file               utl_file.file_type;
    l_file_path          VARCHAR2(100);
    l_file_name          VARCHAR2(100);

    CURSOR cur_rtr_bank_branches IS
      SELECT iebbv.branch_party_id branch_party_id,
             iebv.bank_party_id bank_party_id,
             nvl(iebbv.home_country, iebv.home_country) home_country,
             iebbv.bank_branch_name bank_branch_name,
             iebv.bank_name bank_name,
             iebv.bank_number bank_number,
             iebbv.bank_branch_name_alt bank_branch_name_alt,
             iebbv.branch_number branch_number,
             iebbv.start_date start_date,
             iebbv.end_date end_date,
             iebbv.address_line1 address_line1,
             iebbv.address_line2 address_line2,
             iebbv.address_line3 address_line3,
             iebbv.address_line4 address_line4,
             iebbv.city city,
             iebbv.state state,
             iebbv.province province,
             iebbv.zip zip,
             iebbv.country country,
             iebbv.bank_branch_type bank_branch_type,
             iebbv.description description,
             iebbv.eft_swift_code eft_swift_code,
             iebbv.eft_user_number eft_user_number,
             hp.attribute_category,
             hp.attribute1,
             hp.attribute2,
             hp.attribute3,
             hp.attribute4,
             hp.attribute5,
             hp.attribute6,
             hp.attribute7,
             hp.attribute8,
             hp.attribute9,
             hp.attribute10,
             hp.attribute11,
             hp.attribute12,
             hp.attribute13,
             hp.attribute14,
             hp.attribute15,
             hp.attribute16,
             hp.attribute17,
             hp.attribute18,
             hp.attribute19,
             hp.attribute20,
             hp.attribute21,
             hp.attribute22,
             hp.attribute23,
             hp.attribute24
      FROM   iby_ext_bank_branches_v iebbv,
             iby_ext_banks_v         iebv,
             hz_parties              hp
      WHERE  iebbv.branch_party_id = hp.party_id
      AND    iebbv.bank_party_id = iebv.bank_party_id
      AND    SYSDATE BETWEEN trunc(iebbv.start_date) AND
             nvl(trunc(iebbv.end_date), SYSDATE + 1)
      AND    nvl(iebv.end_date, SYSDATE + 1) > SYSDATE
      AND    hp.status = 'A';

    CURSOR c_bank_branches_extract_upload IS
      SELECT *
      FROM   xxobjt.xxs3_rtr_bankbranch;

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';

    BEGIN
      --Get the file path from the lookup
      SELECT TRIM(' ' FROM meaning)
      INTO   l_file_path
      FROM   fnd_lookup_values_vl
      WHERE  lookup_type = 'XXS3_ITEM_OUT_FILE_PATH';

      --Get the file name
      l_file_name := 'Bank_Branches_Extract' || '_' || SYSDATE || '.xls';

      --Get the utl file open
      l_file := utl_file.fopen(l_file_path, l_file_name, 'w', 32767);
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Invalid File Path' || SQLERRM);
        NULL;
    END;
    --l_file := UTL_FILE.FOPEN('/UtlFiles/shared/DEV','BANK_BRANCHES_EXTRACT_DATA.CSV','w',32767);

    DELETE FROM xxs3_rtr_bankbranch;

    --IF p_only_dq = 'N' THEN

    FOR i IN cur_rtr_bank_branches LOOP

      INSERT INTO xxs3_rtr_bankbranch
      VALUES
        (xxobjt.xxs3_ptp_supplier_bank_seq.NEXTVAL,
         SYSDATE,
         'N',
         NULL,
         NULL,
         i.branch_party_id,
         i.bank_party_id,
         i.home_country,
         i.bank_branch_name,
         i.bank_name,
         i.bank_number,
         i.bank_branch_name_alt,
         i.branch_number,
         i.start_date,
         i.end_date,
         i.address_line1,
         i.address_line2,
         i.address_line3,
         i.address_line4,
         i.city,
         i.state,
         i.province,
         i.zip,
         i.country,
         i.bank_branch_type,
         i.description,
         i.eft_swift_code,
         i.eft_user_number,
         i.attribute_category,
         i.attribute1,
         i.attribute2,
         i.attribute3,
         i.attribute4,
         i.attribute5,
         i.attribute6,
         i.attribute7,
         i.attribute8,
         i.attribute9,
         i.attribute10,
         i.attribute11,
         i.attribute12,
         i.attribute13,
         i.attribute14,
         i.attribute15,
         i.attribute16,
         i.attribute17,
         i.attribute18,
         i.attribute19,
         i.attribute20,
         i.attribute21,
         i.attribute22,
         i.attribute23,
         i.attribute24,
         NULL,
         NULL);

    END LOOP;
    COMMIT;
    --END IF;

    --generate csv

    utl_file.put(l_file, '~' || 'XX_BRANCH_PARTY_ID');
    utl_file.put(l_file, '~' || 'DATE_EXTRACTED_ON');
    utl_file.put(l_file, '~' || 'PROCESS_FLAG');
    utl_file.put(l_file, '~' || 'S3_BRANCH_PARTY_ID');
    utl_file.put(l_file, '~' || 'NOTES');
    utl_file.put(l_file, '~' || 'BRANCH_PARTY_ID');
    utl_file.put(l_file, '~' || 'BANK_PARTY_ID');
    utl_file.put(l_file, '~' || 'HOME_COUNTRY');
    utl_file.put(l_file, '~' || 'BANK_BRANCH_NAME');
    utl_file.put(l_file, '~' || 'BANK_NAME');
    utl_file.put(l_file, '~' || 'BANK_NUMBER');
    utl_file.put(l_file, '~' || 'BANK_BRANCH_NAME_ALT');
    utl_file.put(l_file, '~' || 'BRANCH_NUMBER');
    utl_file.put(l_file, '~' || 'START_DATE');
    utl_file.put(l_file, '~' || 'END_DATE');
    utl_file.put(l_file, '~' || 'ADDRESS_LINE1');
    utl_file.put(l_file, '~' || 'ADDRESS_LINE2');
    utl_file.put(l_file, '~' || 'ADDRESS_LINE3');
    utl_file.put(l_file, '~' || 'ADDRESS_LINE4');
    utl_file.put(l_file, '~' || 'CITY');
    utl_file.put(l_file, '~' || 'STATE');
    utl_file.put(l_file, '~' || 'PROVINCE');
    utl_file.put(l_file, '~' || 'ZIP');
    utl_file.put(l_file, '~' || 'COUNTRY');
    utl_file.put(l_file, '~' || 'BANK_BRANCH_TYPE');
    utl_file.put(l_file, '~' || 'DESCRIPTION');
    utl_file.put(l_file, '~' || 'EFT_SWIFT_CODE');
    utl_file.put(l_file, '~' || 'EFT_USER_NUMBER');
    utl_file.put(l_file, '~' || 'ATTRIBUTE_CATEGORY');
    utl_file.put(l_file, '~' || 'ATTRIBUTE1');
    utl_file.put(l_file, '~' || 'ATTRIBUTE2');
    utl_file.put(l_file, '~' || 'ATTRIBUTE3');
    utl_file.put(l_file, '~' || 'ATTRIBUTE4');
    utl_file.put(l_file, '~' || 'ATTRIBUTE5');
    utl_file.put(l_file, '~' || 'ATTRIBUTE6');
    utl_file.put(l_file, '~' || 'ATTRIBUTE7');
    utl_file.put(l_file, '~' || 'ATTRIBUTE8');
    utl_file.put(l_file, '~' || 'ATTRIBUTE9');
    utl_file.put(l_file, '~' || 'ATTRIBUTE10');
    utl_file.put(l_file, '~' || 'ATTRIBUTE11');
    utl_file.put(l_file, '~' || 'ATTRIBUTE12');
    utl_file.put(l_file, '~' || 'ATTRIBUTE13');
    utl_file.put(l_file, '~' || 'ATTRIBUTE14');
    utl_file.put(l_file, '~' || 'ATTRIBUTE15');
    utl_file.put(l_file, '~' || 'ATTRIBUTE16');
    utl_file.put(l_file, '~' || 'ATTRIBUTE17');
    utl_file.put(l_file, '~' || 'ATTRIBUTE18');
    utl_file.put(l_file, '~' || 'ATTRIBUTE19');
    utl_file.put(l_file, '~' || 'ATTRIBUTE20');
    utl_file.put(l_file, '~' || 'ATTRIBUTE21');
    utl_file.put(l_file, '~' || 'ATTRIBUTE22');
    utl_file.put(l_file, '~' || 'ATTRIBUTE23');
    utl_file.put(l_file, '~' || 'ATTRIBUTE24');
    utl_file.new_line(l_file);

    FOR c1 IN c_bank_branches_extract_upload LOOP

      utl_file.put(l_file, '~' || c1.xx_branch_party_id);
      utl_file.put(l_file, '~' || c1.date_extracted_on);
      utl_file.put(l_file, '~' || c1.process_flag);
      utl_file.put(l_file, '~' || c1.s3_branch_party_id);
      utl_file.put(l_file, '~' || c1.notes);
      utl_file.put(l_file, '~' || c1.branch_party_id);
      utl_file.put(l_file, '~' || c1.bank_party_id);
      utl_file.put(l_file, '~' || c1.home_country);
      utl_file.put(l_file, '~' || c1.bank_branch_name);
      utl_file.put(l_file, '~' || c1.bank_name);
      utl_file.put(l_file, '~' || c1.bank_number);
      utl_file.put(l_file, '~' || c1.bank_branch_name_alt);
      utl_file.put(l_file, '~' || c1.branch_number);
      utl_file.put(l_file, '~' || c1.start_date);
      utl_file.put(l_file, '~' || c1.end_date);
      utl_file.put(l_file, '~' || c1.address_line1);
      utl_file.put(l_file, '~' || c1.address_line2);
      utl_file.put(l_file, '~' || c1.address_line3);
      utl_file.put(l_file, '~' || c1.address_line4);
      utl_file.put(l_file, '~' || c1.city);
      utl_file.put(l_file, '~' || c1.state);
      utl_file.put(l_file, '~' || c1.province);
      utl_file.put(l_file, '~' || c1.zip);
      utl_file.put(l_file, '~' || c1.country);
      utl_file.put(l_file, '~' || c1.bank_branch_type);
      utl_file.put(l_file, '~' || c1.description);
      utl_file.put(l_file, '~' || c1.eft_swift_code);
      utl_file.put(l_file, '~' || c1.eft_user_number);
      utl_file.put(l_file, '~' || c1.attribute_category);
      utl_file.put(l_file, '~' || c1.attribute1);
      utl_file.put(l_file, '~' || c1.attribute2);
      utl_file.put(l_file, '~' || c1.attribute3);
      utl_file.put(l_file, '~' || c1.attribute4);
      utl_file.put(l_file, '~' || c1.attribute5);
      utl_file.put(l_file, '~' || c1.attribute6);
      utl_file.put(l_file, '~' || c1.attribute7);
      utl_file.put(l_file, '~' || c1.attribute8);
      utl_file.put(l_file, '~' || c1.attribute9);
      utl_file.put(l_file, '~' || c1.attribute10);
      utl_file.put(l_file, '~' || c1.attribute11);
      utl_file.put(l_file, '~' || c1.attribute12);
      utl_file.put(l_file, '~' || c1.attribute13);
      utl_file.put(l_file, '~' || c1.attribute14);
      utl_file.put(l_file, '~' || c1.attribute15);
      utl_file.put(l_file, '~' || c1.attribute16);
      utl_file.put(l_file, '~' || c1.attribute17);
      utl_file.put(l_file, '~' || c1.attribute18);
      utl_file.put(l_file, '~' || c1.attribute19);
      utl_file.put(l_file, '~' || c1.attribute20);
      utl_file.put(l_file, '~' || c1.attribute21);
      utl_file.put(l_file, '~' || c1.attribute22);
      utl_file.put(l_file, '~' || c1.attribute23);
      utl_file.put(l_file, '~' || c1.attribute24);
      utl_file.new_line(l_file);

    END LOOP;
    utl_file.fclose(l_file);
    fnd_file.put_line(fnd_file.log, 'Loading complete');

  EXCEPTION

    WHEN report_error THEN
      fnd_file.put_line(fnd_file.log, 'Failed to generate report');
      x_retcode := 1;
      x_errbuf  := 'Unexpected error: report error';

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

  END bank_branches_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  09/06/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------------------------

  PROCEDURE quotation_header_extract_data(x_errbuf  OUT VARCHAR2,
                                          x_retcode OUT NUMBER

                                          ) IS

    l_org_id             NUMBER := fnd_global.org_id;
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_err_code           VARCHAR2(4000);
    l_err_msg            VARCHAR2(4000);

    CURSOR cur_quote_header IS
      SELECT phv.po_header_id,
             phv.org_id,
             (SELECT NAME
              FROM   hr_operating_units
              WHERE  organization_id = phv.org_id) org_name,
             phv.type_lookup_code,
             phv.quote_type_lookup_code,
             phv.segment1,
             phv.currency_code,
             phv.rate_type,
             phv.rate_date,
             phv.rate,
             phv.agent_id,
             phv.agent_name,
             phv.vendor_name,
             phv.vendor_site_code,
             phv.vendor_contact_id,
             phv.vendor_contact,
             phv.ship_to_location,
             phv.bill_to_location,
             phv.payment_terms,
             phv.ship_via_lookup_code,
             phv.freight_terms_lookup_code,
             phv.fob_lookup_code,
             phv.status_lookup_code,
             phv.revision_num,
             phv.note_to_vendor,
             ph.note_to_receiver,
             phv.comments,
             phv.start_date,
             phv.end_date,
             phv.rfq_close_date,
             phv.reply_date,
             phv.reply_method_lookup_code,
             phv.quote_warning_delay,
             phv.approval_required_flag,
             phv.from_type_lookup_code,
             phv.quote_vendor_quote_number,
             ph.created_language,
             ph.style_id,
             ph.created_by,
             phv.quotation_class_code,
             phv.vendor_id,
             phv.vendor_site_id,
             phv.bill_to_location_id
      FROM   po_headers_rfqqt_v phv,
             po_headers_all     ph,
             ap_suppliers       aps
      WHERE  phv.end_date IS NULL
      AND    phv.org_id = l_org_id
      AND    phv.po_header_id = ph.po_header_id
      AND    phv.vendor_id = aps.vendor_id
      AND    nvl(aps.end_date_active, SYSDATE + 1) > SYSDATE;

    CURSOR cur_quote_transform IS
      SELECT *
      FROM   xxs3_ptp_quotation_hdr
      WHERE  process_flag IN ('Y', 'Q');

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';

    mo_global.init('PO');
    mo_global.set_policy_context('S', l_org_id);

    DELETE FROM xxs3_ptp_quotation_hdr;

    --IF p_only_dq = 'N' THEN

    FOR i IN cur_quote_header LOOP

      INSERT INTO xxs3_ptp_quotation_hdr
      VALUES
        (xxobjt.xxs3_ptp_quotation_hdr_seq.NEXTVAL,
         SYSDATE,
         'N',
         NULL,
         NULL,
         i.po_header_id,
         i.org_id,
         i.org_name,
         NULL,
         i.type_lookup_code,
         i.quote_type_lookup_code,
         i.segment1,
         i.currency_code,
         i.rate_type,
         i.rate_date,
         i.rate,
         i.agent_id,
         i.agent_name,
         NULL,
         i.vendor_name,
         i.vendor_site_code,
         i.vendor_contact_id,
         i.vendor_contact,
         i.ship_to_location,
         NULL,
         i.bill_to_location,
         NULL,
         i.payment_terms,
         NULL,
         i.ship_via_lookup_code,
         NULL,
         i.fob_lookup_code,
         NULL,
         i.freight_terms_lookup_code,
         NULL,
         i.status_lookup_code,
         i.revision_num,
         i.note_to_vendor,
         i.note_to_receiver,
         i.comments,
         i.start_date,
         i.end_date,
         i.rfq_close_date,
         i.reply_date,
         i.reply_method_lookup_code,
         i.quote_warning_delay,
         i.approval_required_flag,
         i.from_type_lookup_code,
         i.quote_vendor_quote_number,
         i.created_language,
         i.style_id,
         NULL,
         i.created_by,
         i.quotation_class_code,
         i.vendor_id,
         i.vendor_site_id,
         i.bill_to_location_id,
         NULL,
         NULL,
         NULL,
         NULL);

    END LOOP;
    COMMIT;
    --END IF;
    fnd_file.put_line(fnd_file.log, 'Loading complete');

    -- DQ
    quality_check_quotation_hdr;
    fnd_file.put_line(fnd_file.log, 'DQ complete');

    FOR m IN cur_quote_transform LOOP

      --Transformation
      update_agent_name(m.xx_po_header_id, m.agent_id, m.agent_name);
      --ou
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'organization_name', p_stage_tab => 'xxs3_ptp_quotation_hdr', --Staging Table Name
                                             p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.org_name, --Legacy Value
                                             p_stage_col => 'S3_ORG_NAME', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);
      --ship to location
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'ship_to_location_code', p_stage_tab => 'xxs3_ptp_quotation_hdr', --Staging Table Name
                                             p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.ship_to_location, --Legacy Value
                                             p_stage_col => 'S3_SHIP_TO_LOCATION', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);
      --bill to location
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'location_code', p_stage_tab => 'xxs3_ptp_quotation_hdr', --Staging Table Name
                                             p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.bill_to_location, --Legacy Value
                                             p_stage_col => 'S3_BILL_TO_LOCATION', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --payment terms

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'payment_terms_ptp', p_stage_tab => 'xxs3_ptp_quotation_hdr', --Staging Table Name
                                             p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.payment_terms, --Legacy Value
                                             p_stage_col => 'S3_PAYMENT_TERMS', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --ship_via_lookup_code transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'ship_via_lookup_code', p_stage_tab => 'xxs3_ptp_quotation_hdr', --Staging Table Name
                                             p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.ship_via_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_SHIP_VIA_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --freight_terms_lookup_code transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'freight_terms_lookup_code', p_stage_tab => 'xxs3_ptp_quotation_hdr', --Staging Table Name
                                             p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.freight_terms_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_FREIGHT_TERMS_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --fob transformation
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'fob_lookup_code', p_stage_tab => 'xxs3_ptp_quotation_hdr', --Staging Table Name
                                             p_stage_primary_col => 'XX_PO_HEADER_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_po_header_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.fob_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_FOB_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

    END LOOP;

  EXCEPTION

    WHEN report_error THEN
      fnd_file.put_line(fnd_file.log, 'Failed to generate report');
      x_retcode := 1;
      x_errbuf  := 'Unexpected error: report error';

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

    /*fnd_file.put_line(fnd_file.output, 'Concurrent Request processed successfully');
    fnd_file.put_line(fnd_file.output, '--------------------------------------'); */

  END quotation_header_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  09/06/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------------------------

  PROCEDURE quotation_line_extract_data(x_errbuf  OUT VARCHAR2,
                                        x_retcode OUT NUMBER

                                        ) IS

    l_org_id             NUMBER := fnd_global.org_id;
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);

    CURSOR cur_quote_header IS
      SELECT phv.po_header_id
      FROM   po_headers_rfqqt_v phv,
             po_headers_all     ph,
             ap_suppliers       aps
      WHERE  phv.end_date IS NULL
      AND    phv.org_id = l_org_id
      AND    phv.po_header_id = ph.po_header_id
      AND    phv.vendor_id = aps.vendor_id
      AND    nvl(aps.end_date_active, SYSDATE + 1) > SYSDATE;

    CURSOR cur_quote_line(p_header_id IN NUMBER) IS
      SELECT pl.po_line_id,
             ph.po_header_id,
             pl.org_id,
             (SELECT NAME
              FROM   hr_operating_units
              WHERE  organization_id = pl.org_id) org_name,
             plv.category_id,
             (SELECT concatenated_segments
              FROM   mtl_categories_b_kfv mcbk
              WHERE  mcbk.category_id = plv.category_id) category,
             ph.segment1,
             (SELECT segment1
              FROM   mtl_system_items_b msib
              WHERE  plv.item_id = msib.inventory_item_id
              AND    organization_id = 91) item_number,
             plv.item_description,
             plv.item_revision,
             plv.line_num,
             (SELECT line_type
              FROM   po_line_types plt
              WHERE  plv.line_type_id = plt.line_type_id) line_type,
             plv.max_order_quantity,
             plv.min_order_quantity,
             plv.note_to_vendor,
             plv.quantity,
             plv.vendor_product_num,
             plv.unit_price,
             (SELECT muom.uom_code
              --INTO l_uom_code_line
              FROM   mtl_units_of_measure    muom,
                     mtl_units_of_measure_tl muomt
              WHERE  muom.uom_code = muomt.uom_code
              AND    muomt.LANGUAGE = userenv('LANG')
              AND    muom.unit_of_measure(+) = plv.unit_meas_lookup_code
              AND    nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) uom,
             --PLV.UNIT_MEAS_LOOKUP_CODE ,
             plv.created_by,
             plv.creation_date,
             pl.ip_category_id,
             plv.matching_basis,
             plv.order_type_lookup_code,
             plv.purchase_basis
      FROM   po_lines_rfqqt_v plv,
             po_lines_all     pl,
             po_headers_all   ph
      WHERE  plv.po_line_id = pl.po_line_id
      AND    pl.po_header_id = ph.po_header_id
      AND    pl.org_id = l_org_id
      AND    pl.po_header_id = p_header_id;

    CURSOR cur_quote_transform IS
      SELECT *
      FROM   xxs3_ptp_quotation_line
      WHERE  process_flag IN ('Y', 'Q');

    l_err_code VARCHAR2(4000);
    l_err_msg  VARCHAR2(4000);

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';

    mo_global.init('PO');
    mo_global.set_policy_context('S', l_org_id);

    DELETE FROM xxs3_ptp_quotation_line;

    FOR j IN cur_quote_header LOOP
      --IF p_only_dq = 'N' THEN

      FOR i IN cur_quote_line(j.po_header_id) LOOP

        INSERT INTO xxs3_ptp_quotation_line
        VALUES
          (xxobjt.xxs3_ptp_quotation_line_seq.NEXTVAL,
           SYSDATE,
           'N',
           NULL,
           NULL,
           i.po_line_id,
           i.po_header_id,
           i.org_id,
           i.org_name,
           NULL,
           i.category_id,
           i.category,
           NULL,
           i.segment1,
           i.item_number,
           i.item_description,
           i.item_revision,
           i.line_num,
           i.line_type,
           i.max_order_quantity,
           i.min_order_quantity,
           i.note_to_vendor,
           i.quantity,
           i.vendor_product_num,
           i.unit_price,
           i.uom,
           --i.UNIT_MEAS_LOOKUP_CODE ,
           i.created_by,
           i.creation_date,
           i.ip_category_id,
           i.matching_basis,
           i.order_type_lookup_code,
           i.purchase_basis,
           NULL,
           NULL,
           NULL,
           NULL);

      END LOOP;
    END LOOP;
    COMMIT;
    --END IF;
    fnd_file.put_line(fnd_file.log, 'Loading complete');

    -- DQ
    quality_check_quotation_line;
    fnd_file.put_line(fnd_file.log, 'DQ complete');

    --transformation
    FOR m IN cur_quote_transform LOOP

      --ou
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'organization_name', p_stage_tab => 'xxs3_ptp_quotation_line', --Staging Table Name
                                             p_stage_primary_col => 'XX_PO_LINE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_po_line_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.org_name, --Legacy Value
                                             p_stage_col => 'S3_ORG_NAME', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);
      --category

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'category', p_stage_tab => 'xxs3_ptp_quotation_line', --Staging Table Name
                                             p_stage_primary_col => 'XX_PO_LINE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_po_line_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.category, --Legacy Value
                                             p_stage_col => 'S3_CATEGORY', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

    --ou
    /*xxs3_data_transform_util_pkg.transform(p_mapping_type =>'operating_unit',
                                                                                                                                                                 p_stage_tab => 'xxs3_ptp_quotation_line' ,          --Staging Table Name
                                                                                                                                                                 p_stage_primary_col =>'XX_PO_LINE_ID' ,    --Staging Table Primary Column Name
                                                                                                                                                                 p_stage_primary_col_val=> m.XX_PO_LINE_ID, --Staging Table Primary Column Value
                                                                                                                                                                 p_legacy_val => m.org_id ,              --Legacy Value
                                                                                                                                                                 p_stage_col  => 'S3_ORG_ID',            --Staging Table Name
                                                                                                                                                                 p_err_code   => l_err_code ,                  -- Output error code
                                                                                                                                                                 p_err_msg   => l_err_msg ) ;*/
    END LOOP;
  EXCEPTION

    WHEN report_error THEN
      fnd_file.put_line(fnd_file.log, 'Failed to generate report');
      x_retcode := 1;
      x_errbuf  := 'Unexpected error: report error';

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

    /*fnd_file.put_line(fnd_file.output, 'Concurrent Request processed successfully');
    fnd_file.put_line(fnd_file.output, '--------------------------------------'); */

  END quotation_line_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  09/06/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------------------------

  PROCEDURE price_break_extract_data(x_errbuf  OUT VARCHAR2,
                                     x_retcode OUT NUMBER) IS

    l_org_id             NUMBER := fnd_global.org_id;
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);

    CURSOR cur_quote_header IS
      SELECT phv.po_header_id
      FROM   po_headers_rfqqt_v phv,
             po_headers_all     ph,
             ap_suppliers       aps
      WHERE  phv.end_date IS NULL
      AND    phv.org_id = l_org_id
      AND    phv.po_header_id = ph.po_header_id
      AND    phv.vendor_id = aps.vendor_id
      AND    nvl(aps.end_date_active, SYSDATE + 1) > SYSDATE;

    CURSOR cur_quote_line(p_header_id IN NUMBER) IS
      SELECT pl.po_line_id
      FROM   po_lines_rfqqt_v plv,
             po_lines_all     pl,
             po_headers_all   ph
      WHERE  plv.po_line_id = pl.po_line_id
      AND    pl.po_header_id = ph.po_header_id
      AND    pl.org_id = l_org_id
      AND    pl.po_header_id = p_header_id;

    CURSOR cur_price_break(p_header_id IN NUMBER, p_line_id IN NUMBER) IS
      SELECT pha.segment1 segment1,
             pllv.po_line_id,
             plv.line_num,
             pllv.shipment_type,
             pllv.shipment_num,
             pllv.ship_to_organization_code,
             pllv.ship_to_location_code,
             (SELECT at.NAME
              FROM   ap_terms at
              WHERE  at.term_id(+) = pllv.terms_id) terms,
             pllv.qty_rcv_exception_code,
             pllv.fob_lookup_code,
             pllv.freight_terms_lookup_code,
             pllv.enforce_ship_to_location_code,
             pllv.allow_substitute_receipts_flag,
             pllv.days_early_receipt_allowed,
             pllv.days_late_receipt_allowed,
             pllv.receipt_days_exception_code,
             pllv.invoice_close_tolerance,
             pllv.receive_close_tolerance,
             (SELECT meaning
              FROM   fnd_lookup_values_vl flvv
              WHERE  lookup_type = 'RCV_ROUTING_HEADERS'
              AND    flvv.lookup_code = pllv.receiving_routing_id) receiving_routing,
             pllv.accrue_on_receipt_flag,
             pllv.need_by_date,
             pllv.promised_date,
             pllv.inspection_required_flag,
             pllv.receipt_required_flag,
             pllv.note_to_receiver,
             pllv.quantity,
             pllv.price_discount,
             pllv.start_date,
             pllv.end_date,
             pllv.price_override,
             pllv.lead_time,
             pllv.lead_time_unit,
             pllv.amount,
             pllv.secondary_quantity,
             (SELECT muom.uom_code
              --INTO l_uom_code_line
              FROM   mtl_units_of_measure    muom,
                     mtl_units_of_measure_tl muomt
              WHERE  muom.uom_code = muomt.uom_code
              AND    muomt.LANGUAGE = userenv('LANG')
              AND    muom.unit_of_measure(+) =
                     pllv.secondary_unit_of_measure
              AND    nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) secondary_unit_of_measure,
             --pllv.SECONDARY_UNIT_OF_MEASURE  ,
             (SELECT muom.uom_code
              --INTO l_uom_code_line
              FROM   mtl_units_of_measure    muom,
                     mtl_units_of_measure_tl muomt
              WHERE  muom.uom_code = muomt.uom_code
              AND    muomt.LANGUAGE = userenv('LANG')
              AND    muom.unit_of_measure(+) = pllv.unit_meas_lookup_code
              AND    nvl(muom.disable_date, SYSDATE + 1) >= SYSDATE) unit_meas_lookup_code,
             --pllv.UNIT_MEAS_LOOKUP_CODE  ,
             --VALUE_BASIS ,
             pllv.preferred_grade,
             pllv.qty_rcv_tolerance,
             pllv.ship_via_lookup_code
      FROM   po_line_locations_v pllv,
             po_headers_all      pha,
             po_lines_v          plv
      WHERE  pha.po_header_id = pllv.po_header_id
      AND    pha.org_id = l_org_id
      AND    pllv.po_header_id = p_header_id
      AND    pllv.po_line_id = plv.po_line_id
      AND    pllv.po_line_id = p_line_id;

    CURSOR cur_pb_transform IS
      SELECT *
      FROM   xxs3_ptp_price_break;

    l_err_code VARCHAR2(4000);
    l_err_msg  VARCHAR2(4000);

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';

    mo_global.init('PO');
    mo_global.set_policy_context('S', l_org_id);

    DELETE FROM xxs3_ptp_price_break;

    FOR j IN cur_quote_header LOOP
      --IF p_only_dq = 'N' THEN

      FOR k IN cur_quote_line(j.po_header_id) LOOP
        --IF p_only_dq = 'N' THEN

        FOR i IN cur_price_break(j.po_header_id, k.po_line_id) LOOP

          INSERT INTO xxs3_ptp_price_break
          VALUES
            (xxobjt.xxs3_ptp_price_break_seq.NEXTVAL,
             SYSDATE,
             'N',
             NULL,
             NULL,
             i.segment1,
             i.po_line_id,
             i.line_num,
             i.shipment_type,
             i.shipment_num,
             i.ship_to_organization_code,
             NULL,
             i.ship_to_location_code,
             NULL,
             i.terms,
             NULL,
             i.qty_rcv_exception_code,
             i.fob_lookup_code,
             NULL,
             i.freight_terms_lookup_code,
             NULL,
             i.enforce_ship_to_location_code,
             i.allow_substitute_receipts_flag,
             i.days_early_receipt_allowed,
             i.days_late_receipt_allowed,
             i.receipt_days_exception_code,
             i.invoice_close_tolerance,
             i.receive_close_tolerance,
             i.receiving_routing,
             i.accrue_on_receipt_flag,
             i.need_by_date,
             i.promised_date,
             i.inspection_required_flag,
             i.receipt_required_flag,
             i.note_to_receiver,
             i.quantity,
             i.price_discount,
             i.start_date,
             i.end_date,
             i.price_override,
             i.lead_time,
             i.lead_time_unit,
             i.amount,
             i.secondary_quantity,
             i.secondary_unit_of_measure,
             i.unit_meas_lookup_code,
             --VALUE_BASIS ,
             i.preferred_grade,
             i.qty_rcv_tolerance,
             i.ship_via_lookup_code,
             NULL,
             NULL,
             NULL,
             NULL,
             NULL);

        END LOOP;
      END LOOP;
    END LOOP;
    COMMIT;
    --END IF;
    fnd_file.put_line(fnd_file.log, 'Loading complete');
    FOR m IN cur_pb_transform LOOP
      --Transformation
      --ship to location
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'ship_to_location_code', p_stage_tab => 'XXS3_PTP_PRICE_BREAK', --Staging Table Name
                                             p_stage_primary_col => 'XX_LINE_LOCATION_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_line_location_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.ship_to_location_code, --Legacy Value
                                             p_stage_col => 'S3_SHIP_TO_LOCATION_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --payment terms

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'payment_terms_ptp', p_stage_tab => 'XXS3_PTP_PRICE_BREAK', --Staging Table Name
                                             p_stage_primary_col => 'XX_LINE_LOCATION_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_line_location_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.terms, --Legacy Value
                                             p_stage_col => 'S3_TERMS', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --freight_terms_lookup_code transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'freight_terms_lookup_code', p_stage_tab => 'XXS3_PTP_PRICE_BREAK', --Staging Table Name
                                             p_stage_primary_col => 'XX_LINE_LOCATION_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_line_location_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.freight_terms_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_FREIGHT_TERMS_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --fob transformation
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'fob_lookup_code', p_stage_tab => 'XXS3_PTP_PRICE_BREAK', --Staging Table Name
                                             p_stage_primary_col => 'XX_LINE_LOCATION_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_line_location_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.fob_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_FOB_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

      --ship_via_lookup_code transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'ship_via_lookup_code', p_stage_tab => 'XXS3_PTP_PRICE_BREAK', --Staging Table Name
                                             p_stage_primary_col => 'XX_LINE_LOCATION_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_line_location_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.ship_via_lookup_code, --Legacy Value
                                             p_stage_col => 'S3_SHIP_VIA_LOOKUP_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);
      --ship_to_org_code transformation
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org_ptp', p_stage_tab => 'XXS3_PTP_PRICE_BREAK', --Staging Table Name
                                             p_stage_primary_col => 'XX_LINE_LOCATION_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => m.xx_line_location_id, --Staging Table Primary Column Value
                                             p_legacy_val => m.ship_to_organization_code, --Legacy Value
                                             p_stage_col => 'S3_SHIP_TO_ORGANIZATION_CODE', --Staging Table Name
                                             p_other_col => m.ship_to_location_code, p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);

    END LOOP;

  EXCEPTION

    WHEN report_error THEN
      fnd_file.put_line(fnd_file.log, 'Failed to generate report');
      x_retcode := 1;
      x_errbuf  := 'Unexpected error: report error';

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

    

  END price_break_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  09/06/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------------------------

  PROCEDURE sourcing_rules_extract_data(x_errbuf  OUT VARCHAR2,
                                        x_retcode OUT NUMBER

                                        ) IS

    l_org_id             NUMBER := fnd_global.org_id;
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_err_code           VARCHAR2(4000);
    l_err_msg            VARCHAR2(4000);

    CURSOR c_vendor IS
      SELECT vendor_id
      FROM   xxs3_ptp_suppliers;

    CURSOR c_sourcing_rule(p_vendor_id IN NUMBER) IS
      SELECT msr.sourcing_rule_id,
             msr.sourcing_rule_name,
             msr.description,
             CASE
               WHEN msr.organization_id IS NULL THEN
                'Yes'
               WHEN msr.organization_id IS NOT NULL THEN
                'No'
             END AS allorgs,
             CASE
               WHEN msr.organization_id IS NULL THEN
                NULL
               WHEN msr.organization_id IS NOT NULL THEN
                (SELECT organization_code
                 FROM   mtl_parameters
                 WHERE  organization_id = msr.organization_id)
             END AS sourcingruleorg,
             msr.planning_active,
             msrov.effective_date,
             msrov.disable_date,
             msr.sourcing_rule_type,
             'Buy From' TYPE,
             mssov.source_organization_code,
             (SELECT segment1
              FROM   ap_suppliers asp
              WHERE  asp.vendor_id = mssov.vendor_id) segment1,
             mssov.vendor_name,
             (SELECT s3_vendor_name
              FROM   xxs3_ptp_suppliers
              WHERE  vendor_id = p_vendor_id) s3_vendor_name,
             mssov.vendor_site,
             mssov.allocation_percent,
             mssov.rank,
             mssov.ship_method,
             mssov.intransit_time
      FROM   mrp_sourcing_rules   msr,
             mrp_sr_source_org_v  mssov,
             mrp_sr_receipt_org_v msrov
      WHERE  msr.sourcing_rule_id = msrov.sourcing_rule_id
      AND    msrov.sr_receipt_id = mssov.sr_receipt_id
      AND    mssov.source_type = 3
      AND    msrov.disable_date IS NULL
      AND    msr.organization_id IN ('739', '740', '742')
      AND    mssov.vendor_id = p_vendor_id

      UNION

      SELECT msr.sourcing_rule_id,
             msr.sourcing_rule_name,
             msr.description,
             CASE
               WHEN msr.organization_id IS NULL THEN
                'Yes'
               WHEN msr.organization_id IS NOT NULL THEN
                'No'
             END AS allorgs,
             CASE
               WHEN msr.organization_id IS NULL THEN
                NULL
               WHEN msr.organization_id IS NOT NULL THEN
                (SELECT organization_code
                 FROM   mtl_parameters
                 WHERE  organization_id = msr.organization_id)
             END AS sourcingruleorg,
             msr.planning_active,
             msrov.effective_date,
             msrov.disable_date,
             msr.sourcing_rule_type,
             'Transfer From' TYPE,
             mssov.source_organization_code,
             (SELECT segment1
              FROM   ap_suppliers asp
              WHERE  asp.vendor_id = mssov.vendor_id) segment1,
             mssov.vendor_name,
             (SELECT s3_vendor_name
              FROM   xxs3_ptp_suppliers
              WHERE  vendor_id = p_vendor_id) s3_vendor_name,
             mssov.vendor_site,
             mssov.allocation_percent,
             mssov.rank,
             mssov.ship_method,
             mssov.intransit_time
      FROM   mrp_sourcing_rules   msr,
             mrp_sr_source_org_v  mssov,
             mrp_sr_receipt_org_v msrov
      WHERE  msr.sourcing_rule_id = msrov.sourcing_rule_id
      AND    msrov.sr_receipt_id = mssov.sr_receipt_id
      AND    mssov.source_type <> 3
      AND    msrov.disable_date IS NULL
      AND    msr.organization_id IN ('739', '740', '742')
      AND    mssov.vendor_id = p_vendor_id;

    CURSOR cur_src IS
      SELECT *
      FROM   xxs3_ptp_sourcing_rules;

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';

    mo_global.init('PO');
    mo_global.set_policy_context('M', NULL);

    DELETE FROM xxs3_ptp_sourcing_rules;
    --DELETE FROM xxs3_ptp_sourcing_rules_dq;

    FOR j IN c_vendor LOOP
      FOR i IN c_sourcing_rule(j.vendor_id) LOOP
        INSERT INTO xxs3_ptp_sourcing_rules
        VALUES
          (xxs3_ptp_sourcing_rules_seq.NEXTVAL,
           SYSDATE,
           'N',
           NULL,
           NULL,
           i.sourcing_rule_id,
           i.sourcing_rule_name,
           i.description,
           i.allorgs,
           i.sourcingruleorg,
           NULL,
           i.planning_active,
           i.effective_date,
           i.disable_date,
           i.sourcing_rule_type,
           i.TYPE,
           i.source_organization_code,
           i.segment1,
           i.vendor_name,
           i.s3_vendor_name,
           i.vendor_site,
           i.allocation_percent,
           i.rank,
           i.ship_method,
           i.intransit_time,
           NULL,
           NULL,
           NULL,
           NULL);
      END LOOP;
    END LOOP;

    COMMIT;

    fnd_file.put_line(fnd_file.log, 'Loading complete');

    --Transformation
    --org transformation
    FOR k IN cur_src LOOP
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org_ptp', p_stage_tab => 'XXS3_PTP_SOURCING_RULES', --Staging Table Name
                                             p_stage_primary_col => 'XX_SOURCING_RULE_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => k.xx_sourcing_rule_id, --Staging Table Primary Column Value
                                             p_legacy_val => k.sourcingruleorg, --Legacy Value
                                             p_stage_col => 'S3_SOURCINGRULEORG', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);
    END LOOP;

  EXCEPTION

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

  END sourcing_rules_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  09/06/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------------------------

  PROCEDURE src_rules_assign_extract_data(x_errbuf  OUT VARCHAR2,
                                          x_retcode OUT NUMBER

                                          ) IS

    l_org_id             NUMBER := fnd_global.org_id;
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_err_code           VARCHAR2(4000);             
    l_err_msg            VARCHAR2(4000);

    CURSOR c_sourcing_rule IS
      SELECT sourcing_rule_id
      FROM   xxs3_ptp_sourcing_rules;

    CURSOR c_sourcing_rule_assign(p_sourcing_rule_id IN NUMBER) IS
      SELECT msra.assignment_id,
             msra.sourcing_rule_id,
             mas.assignment_set_name,
             mas.description assignment_desc,
             'Item-Organization' assigned_to
             --, msra.organization_id
            ,
             msra.organization_code,
             msra.customer_name,
             msra.ship_to_address customer_site,
             msra.entity_name item_code,
             msra.description description,
             msra.sourcing_rule_type_text,
             msra.sourcing_rule_name
      FROM   apps.mrp_sr_assignments_v msra,
             mrp_assignment_sets       mas
      WHERE  msra.assignment_set_id = mas.assignment_set_id
      AND    mas.assignment_set_name = 'SSYS Global Assignment'
      AND    msra.organization_id IN ('739', '740', '742')
      AND    msra.assignment_type = 6
      AND    msra.sourcing_rule_id = p_sourcing_rule_id;

    CURSOR cur_src IS
      SELECT *
      FROM   xxs3_ptp_src_rules_assign;

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';

    mo_global.init('PO');
    mo_global.set_policy_context('M', NULL);

    DELETE FROM xxs3_ptp_src_rules_assign;
    --DELETE FROM xxs3_ptp_sourcing_rules_dq;

    FOR j IN c_sourcing_rule LOOP
      FOR i IN c_sourcing_rule_assign(j.sourcing_rule_id) LOOP
        INSERT INTO xxs3_ptp_src_rules_assign
        VALUES
          (xxs3_ptp_src_rules_assign_seq.NEXTVAL,
           SYSDATE,
           'N',
           NULL,
           NULL,
           i.assignment_id,
           i.sourcing_rule_id,
           i.assignment_set_name,
           i.assignment_desc,
           i.assigned_to,
           i.organization_code,
           NULL,
           i.customer_name,
           i.customer_site,
           i.item_code,
           i.description,
           i.sourcing_rule_type_text,
           i.sourcing_rule_name,
           NULL,
           NULL,
           NULL,
           NULL);
      END LOOP;
    END LOOP;

    COMMIT;

    fnd_file.put_line(fnd_file.log, 'Loading complete');

    --Transformation
    --org transformation
    FOR k IN cur_src LOOP
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org_ptp', p_stage_tab => 'XXS3_PTP_SRC_RULES_ASSIGN', --Staging Table Name
                                             p_stage_primary_col => 'XX_ASSIGNMENT_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => k.xx_assignment_id, --Staging Table Primary Column Value
                                             p_legacy_val => k.organization_code, --Legacy Value
                                             p_stage_col => 'S3_ORGANIZATION_CODE', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);
    END LOOP;

  EXCEPTION

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

  END src_rules_assign_extract_data;

END xxs3_ptp_suppliers_pkg;
/
