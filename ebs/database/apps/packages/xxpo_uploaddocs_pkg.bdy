CREATE OR REPLACE PACKAGE BODY xxpo_uploaddocs_pkg IS

  TYPE v_read_rec IS RECORD(
    operating_unit    hr_organization_units.name%TYPE,
    operating_unit_id hr_operating_units.organization_id%TYPE,
    po_number         po_headers_all.segment1%TYPE,
    supplier          ap_suppliers.vendor_name%TYPE,
    supplier_id       ap_suppliers.vendor_id%TYPE,
    suppliersite_id   ap_supplier_sites_all.vendor_site_id%TYPE,
    ship_to_loc_id    ap_supplier_sites_all.ship_to_location_id%TYPE,
    bill_to_loc_id    ap_supplier_sites_all.bill_to_location_id%TYPE,
    currency          po_headers_all.currency_code%TYPE,
    pohdrcurreny      po_headers_all.currency_code%TYPE,
    currrate          po_headers_all.rate%TYPE,
    buyer             per_all_people_f.full_name%TYPE,
    buyer_id          per_all_people_f.person_id%TYPE,
    po_description    po_headers_all.comments%TYPE,
    line_number       po_lines_all.line_num%TYPE,
    line_type         fnd_lookup_values.lookup_code%TYPE,
    item_num          mtl_system_items_b.segment1%TYPE,
    item_id           mtl_system_items_b.inventory_item_id%TYPE,
    item_desc         mtl_system_items_b.description%TYPE,
    mfg_part_num      mtl_system_items_b.segment1%TYPE,
    uom               mtl_system_items_b.primary_uom_code%TYPE,
    lineqty           po_lines_all.quantity%TYPE,
    unit_price        po_lines_all.unit_price%TYPE,
    promised_date     VARCHAR2(8),
    needby_date       VARCHAR2(8),
    shipto_orgid      mtl_parameters.organization_id%TYPE,
    materialacct      mtl_parameters.material_account%TYPE,
    pohdrrate         po_headers_all.rate%TYPE,
    lineretcode       VARCHAR2(10),
    lineerrbuf        VARCHAR2(2000));
  TYPE v_read_tab IS TABLE OF v_read_rec INDEX BY BINARY_INTEGER;

  v_user_id  fnd_user.user_id%TYPE;
  v_login_id fnd_logins.login_id%TYPE;
  -- Convert To Hebrew 7 Bits
  FUNCTION hebconv(str IN VARCHAR2) RETURN VARCHAR2 IS
    conv_str     VARCHAR2(2000) := '';
    run_str      VARCHAR2(2000) := '';
    is_heb_run   BOOLEAN := FALSE;
    letter       VARCHAR2(1);
    hebrew_found BOOLEAN := FALSE;
  BEGIN
    IF str IS NULL THEN
      RETURN NULL;
    END IF;
  
    FOR i IN 1 .. length(str) LOOP
      hebrew_found := hebrew_found OR (substr(str, i, 1) >= 'à' AND
                      substr(str, i, 1) <= 'ú');
    END LOOP;
  
    IF NOT hebrew_found THEN
      RETURN str;
    END IF;
  
    FOR i IN 1 .. length(str) LOOP
      letter := substr(str, i, 1);
    
      IF letter = '(' THEN
        letter := ')';
      ELSIF letter = ')' THEN
        letter := '(';
      END IF;
    
      IF (letter >= 'à' AND letter <= 'ú') OR
         (letter IN ('-', '%', '(', ')')) THEN
        IF is_heb_run THEN
          run_str := letter || run_str;
        ELSE
          conv_str   := run_str || conv_str;
          is_heb_run := TRUE;
          run_str    := letter;
        END IF;
      ELSE
        IF is_heb_run THEN
          conv_str   := run_str || conv_str;
          is_heb_run := FALSE;
          run_str    := letter;
        ELSE
          run_str := run_str || letter;
        END IF;
      END IF;
    END LOOP;
  
    conv_str := run_str || conv_str;
  
    RETURN conv_str;
  END hebconv;

  FUNCTION getconversoinmls RETURN VARCHAR2 IS
  BEGIN
    RETURN('IW');
  END;

  FUNCTION get_conv_rate(p_from_currency IN po_headers_all.currency_code%TYPE,
                         p_to_currency   IN po_headers_all.currency_code%TYPE,
                         p_base_date     IN DATE) RETURN NUMBER IS
    l_rate       gl_daily_rates.conversion_rate%TYPE;
    l_convr_type VARCHAR2(100) := fnd_profile.value('XXPO_CURR_CONVERSION_TYPE');
  BEGIN
    -- Get Currency Rate   
    BEGIN
      l_rate := gl_currency_api.get_rate(x_from_currency   => p_from_currency,
                                         x_to_currency     => p_to_currency,
                                         x_conversion_date => p_base_date,
                                         x_conversion_type => l_convr_type);
    EXCEPTION
      WHEN no_data_found THEN
        BEGIN
          l_rate := gl_currency_api.get_rate(x_from_currency   => p_to_currency,
                                             x_to_currency     => p_from_currency,
                                             x_conversion_date => p_base_date,
                                             x_conversion_type => l_convr_type);
          l_rate := 1 / l_rate;
        EXCEPTION
          WHEN no_data_found THEN
            l_rate := gl_currency_api.get_closest_rate(x_from_currency   => p_from_currency,
                                                       x_to_currency     => p_to_currency,
                                                       x_conversion_date => p_base_date,
                                                       x_conversion_type => l_convr_type,
                                                       x_max_roll_days   => 100);
        END;
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log,
                          'Problem At Conversion Rate: ' || SQLERRM);
        dbms_output.put_line(a => 'Problem At Conversion Rate: ' || SQLERRM);
    END;
    RETURN(l_rate);
  END get_conv_rate;

  PROCEDURE do_linkage(p_po_num        IN po_headers_all.segment1%TYPE,
                       p_from_currency IN po_headers_all.currency_code%TYPE,
                       p_to_currency   IN po_headers_all.currency_code%TYPE,
                       p_base_date     IN DATE,
                       p_lineunitprice IN po_lines_all.unit_price%TYPE,
                       p_pohdrattr3    OUT po_headers_all.attribute3%TYPE) IS
    l_rate       gl_daily_rates.conversion_rate%TYPE;
    l_convr_type VARCHAR2(100) := fnd_profile.value('XXPO_CURR_CONVERSION_TYPE');
    l_curr_desc  fnd_currencies_tl.description%TYPE;
    l_num        NUMBER;
  BEGIN
    -- Get Currency Rate   
    BEGIN
      l_rate := gl_currency_api.get_rate(x_from_currency   => p_from_currency,
                                         x_to_currency     => p_to_currency,
                                         x_conversion_date => p_base_date,
                                         x_conversion_type => l_convr_type);
    EXCEPTION
      WHEN no_data_found THEN
        BEGIN
          l_rate := gl_currency_api.get_rate(x_from_currency   => p_to_currency,
                                             x_to_currency     => p_from_currency,
                                             x_conversion_date => p_base_date,
                                             x_conversion_type => l_convr_type);
          l_rate := 1 / l_rate;
        EXCEPTION
          WHEN no_data_found THEN
            l_rate := gl_currency_api.get_closest_rate(x_from_currency   => p_from_currency,
                                                       x_to_currency     => p_to_currency,
                                                       x_conversion_date => p_base_date,
                                                       x_conversion_type => l_convr_type,
                                                       x_max_roll_days   => 100);
        END;
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log,
                          'Linkage Problem At PO ' || p_po_num || ': ' ||
                          SQLERRM);
        dbms_output.put_line(a => 'Linkage Problem At PO ' || p_po_num || ': ' ||
                                  SQLERRM);
    END;
    -- Get currency description
    BEGIN
      SELECT cc.description
        INTO l_curr_desc
        FROM fnd_currencies_vl cc
       WHERE cc.currency_code = p_from_currency;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    -- check if no linkage
    IF l_rate IS NOT NULL THEN
      BEGIN
        SELECT 1
          INTO l_num
          FROM clef062_po_index_esc_set cc
         WHERE cc.module = 'PO'
           AND cc.document_id = p_po_num
           AND rownum = 1;
      EXCEPTION
        WHEN no_data_found THEN
          -- insert into linkage table
          INSERT INTO clef062_po_index_esc_set
            (module,
             document_id,
             currency_code,
             conversion_type,
             linkage_to,
             base_rate,
             base_date,
             description,
             last_updated_by,
             last_update_date,
             created_by,
             creation_date,
             last_update_login,
             currency_name,
             rate_limit)
          VALUES
            ('PO',
             p_po_num,
             p_from_currency,
             l_convr_type,
             1,
             substr(to_char(l_rate), 1, 20),
             trunc(p_base_date),
             'Auto index for PO',
             fnd_global.user_id,
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.login_id,
             substr(l_curr_desc, 1, 20),
             NULL);
        
      END;
      -- Changed By AviH On 02-Sep-09. Was: p_POHdrAttr3 := to_char(trunc(p_LineUnitPrice * (1 / l_rate), 3)) || ' ' || p_from_currency;
      p_pohdrattr3 := to_char(trunc(p_lineunitprice, 3)) || ' ' ||
                      p_from_currency;
    END IF;
    -- Update amount in original currency  - DFF
  
  END do_linkage;
  --------------------------------------------------------------------
  --  customization code: 
  --  name:               Ascii_StandrardPOInt
  --  create by:          
  --  $Revision:          1.0
  --  creation date:      
  --  Description:
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18.08.2013    Vitaly          CR 870 std cost - change hard-coded organization
  --                                      variables names are changed too: 
  --                                          v_WRI_OrganizID    changed to v_IRK_OrganizID
  --                                          v_WRI_MaterialAcct changed to v_IRK_MaterialAcct
  --                                          v_WPI_OrganizID    changed to v_IPK_OrganizID
  --                                          v_WPI_MaterialAcct changed to v_IPK_MaterialAcct
  --                                      ITA organization added
  --------------------------------------------------------------------
  PROCEDURE ascii_standrardpoint(errbuf              OUT VARCHAR2,
                                 retcode             OUT VARCHAR2,
                                 p_location          IN VARCHAR2,
                                 p_filename          IN VARCHAR2,
                                 p_master_organiz_id IN NUMBER,
                                 p_processlines      IN CHAR) IS
    v_read_file   utl_file.file_type;
    v_read_code   NUMBER(5) := 1;
    v_line_buf    VARCHAR2(2000);
    v_tmp_line    VARCHAR2(2000);
    v_delimiter   CHAR(1) := ',';
    v_place       NUMBER(3);
    v_counter     NUMBER := 0;
    v_lineerrbuf  VARCHAR2(2000);
    v_lineretcode VARCHAR2(10);
    v_dummydate   DATE;
  
    v_read_array      v_read_tab;
    v_hdrinterfaceid  po_headers_interface.interface_header_id%TYPE;
    v_lineinterfaceid po_lines_interface.interface_line_id%TYPE;
    v_distinterfaceid po_distributions_interface.interface_distribution_id%TYPE;
    v_curr_po_num     po_headers_interface.document_num%TYPE;
    v_polineattr3     po_lines_all.attribute3%TYPE;
  
    v_irk_organizid    mtl_parameters.organization_id%TYPE;
    v_irk_materialacct mtl_parameters.material_account%TYPE;
    v_ipk_organizid    mtl_parameters.organization_id%TYPE;
    v_ipk_materialacct mtl_parameters.material_account%TYPE;
    v_ita_organizid    mtl_parameters.organization_id%TYPE;
    v_ita_materialacct mtl_parameters.material_account%TYPE;
  BEGIN
    SELECT organization_id, material_account
      INTO v_irk_organizid, v_irk_materialacct
      FROM mtl_parameters
     WHERE organization_code = 'IRK'; ---'WRI'
    SELECT organization_id, material_account
      INTO v_ipk_organizid, v_ipk_materialacct
      FROM mtl_parameters
     WHERE organization_code = 'IPK'; ---'WPI'
    SELECT organization_id, material_account
      INTO v_ita_organizid, v_ita_materialacct
      FROM mtl_parameters
     WHERE organization_code = 'ITA';
    -- Open the given file for reading
    BEGIN
      v_read_file := utl_file.fopen(location  => p_location,
                                    filename  => p_filename,
                                    open_mode => 'r');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(rtrim(p_location)) || '/' ||
                        ltrim(rtrim(p_filename)) || ' Opened');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        errbuf  := 'Invalid Path for ' || ltrim(rtrim(p_location)) || '/' ||
                   ltrim(rtrim(p_filename)) || chr(0);
        retcode := '2';
      WHEN utl_file.invalid_mode THEN
        errbuf  := 'Invalid Mode for ' || ltrim(rtrim(p_location)) || '/' ||
                   ltrim(rtrim(p_filename)) || chr(0);
        retcode := '2';
      WHEN utl_file.invalid_operation THEN
        errbuf  := 'Invalid operation for ' || ltrim(rtrim(p_location)) || '/' ||
                   ltrim(rtrim(p_filename)) || chr(0);
        retcode := '2';
      WHEN OTHERS THEN
        errbuf  := 'Other for ' || ltrim(rtrim(p_location)) || '/' ||
                   ltrim(rtrim(p_filename)) || chr(0);
        retcode := '2';
    END;
    -- Loop The File For Reading
    WHILE v_read_code <> 0 AND nvl(retcode, '0') = '0' LOOP
      BEGIN
        utl_file.get_line(file => v_read_file, buffer => v_line_buf);
      EXCEPTION
        WHEN utl_file.read_error THEN
          errbuf  := 'Read Error' || chr(0);
          retcode := '2';
        WHEN no_data_found THEN
          fnd_file.put_line(fnd_file.log, 'Read Complete');
          v_read_code := 0;
        WHEN OTHERS THEN
          errbuf  := 'Other for Line Read' || chr(0);
          retcode := '2';
      END;
      -- Check The EOF
      IF v_read_code <> 0 THEN
        v_counter     := v_counter + 1;
        v_lineerrbuf  := NULL;
        v_lineretcode := '0';
        v_place       := instrb(v_line_buf, v_delimiter);
        -- Check The Delimiter
        IF nvl(v_place, 0) = 0 OR (v_place > 100) THEN
          fnd_file.put_line(fnd_file.log,
                            'No Delimiter In The File, Line' ||
                            to_char(v_counter));
          errbuf  := 'No Delimiter In The File, Line' || to_char(v_counter) ||
                     chr(0);
          retcode := '2';
        ELSE
          v_read_array(v_counter).po_number := ltrim(rtrim(substrb(v_line_buf,
                                                                   1,
                                                                   v_place - 1)));
          v_tmp_line := ltrim(substrb(v_line_buf,
                                      v_place + 1,
                                      length(v_line_buf)));
        
          IF substrb(v_tmp_line, 1, 1) = chr(34) THEN
            v_place := instrb(v_tmp_line, chr(34) || v_delimiter);
            v_read_array(v_counter).supplier := ltrim(rtrim(substrb(v_tmp_line,
                                                                    2,
                                                                    v_place - 2)));
            v_tmp_line := ltrim(substrb(v_tmp_line,
                                        v_place + 2,
                                        length(v_tmp_line)));
          ELSE
            v_place := instrb(v_tmp_line, v_delimiter);
            v_read_array(v_counter).supplier := ltrim(rtrim(substrb(v_tmp_line,
                                                                    1,
                                                                    v_place - 1)));
            v_tmp_line := ltrim(substrb(v_tmp_line,
                                        v_place + 1,
                                        length(v_tmp_line)));
          END IF;
        
          v_place := instrb(v_tmp_line, v_delimiter);
          v_read_array(v_counter).currency := ltrim(rtrim(substrb(v_tmp_line,
                                                                  1,
                                                                  v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
        
          v_place := instrb(v_tmp_line, v_delimiter);
          v_read_array(v_counter).buyer := ltrim(rtrim(substrb(v_tmp_line,
                                                               1,
                                                               v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
        
          v_place := instrb(v_tmp_line, v_delimiter);
          v_read_array(v_counter).po_description := ltrim(rtrim(substrb(v_tmp_line,
                                                                        1,
                                                                        v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
        
          v_place := instrb(v_tmp_line, v_delimiter);
          v_read_array(v_counter).line_number := ltrim(rtrim(substrb(v_tmp_line,
                                                                     1,
                                                                     v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
        
          v_place := instrb(v_tmp_line, v_delimiter);
          v_read_array(v_counter).item_num := ltrim(rtrim(substrb(v_tmp_line,
                                                                  1,
                                                                  v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
        
          IF substrb(v_tmp_line, 1, 1) = chr(34) THEN
            v_place := instrb(v_tmp_line, chr(34) || v_delimiter);
            v_read_array(v_counter).item_desc := ltrim(rtrim(substrb(v_tmp_line,
                                                                     2,
                                                                     v_place - 2)));
            v_tmp_line := ltrim(substrb(v_tmp_line,
                                        v_place + 2,
                                        length(v_tmp_line)));
          ELSE
            v_place := instrb(v_tmp_line, v_delimiter);
            v_read_array(v_counter).item_desc := ltrim(rtrim(substrb(v_tmp_line,
                                                                     1,
                                                                     v_place - 1)));
            v_tmp_line := ltrim(substrb(v_tmp_line,
                                        v_place + 1,
                                        length(v_tmp_line)));
          END IF;
        
          v_place := instrb(v_tmp_line, v_delimiter);
          v_read_array(v_counter).mfg_part_num := ltrim(rtrim(substrb(v_tmp_line,
                                                                      1,
                                                                      v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
        
          v_place := instrb(v_tmp_line, v_delimiter);
          v_read_array(v_counter).uom := ltrim(rtrim(substrb(v_tmp_line,
                                                             1,
                                                             v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
        
          v_place := instrb(v_tmp_line, v_delimiter);
          v_read_array(v_counter).lineqty := ltrim(rtrim(substrb(v_tmp_line,
                                                                 1,
                                                                 v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
        
          v_place := instrb(v_tmp_line, v_delimiter);
          v_read_array(v_counter).unit_price := ltrim(rtrim(substrb(v_tmp_line,
                                                                    1,
                                                                    v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
        
          v_place := instrb(v_tmp_line, v_delimiter);
          v_read_array(v_counter).promised_date := ltrim(rtrim(substrb(v_tmp_line,
                                                                       1,
                                                                       v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
        
          v_place := instrb(v_tmp_line, v_delimiter);
          v_read_array(v_counter).needby_date := ltrim(rtrim(substrb(v_tmp_line,
                                                                     1,
                                                                     v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
        
          v_place := instrb(v_tmp_line, v_delimiter);
          v_read_array(v_counter).operating_unit := ltrim(rtrim(substrb(v_tmp_line,
                                                                        1,
                                                                        v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
        
          v_place := instrb(v_tmp_line, v_delimiter);
          IF v_place = 0 THEN
            v_place := length(v_tmp_line);
          END IF;
          v_read_array(v_counter).pohdrcurreny := ltrim(rtrim(substrb(v_tmp_line,
                                                                      1,
                                                                      v_place - 1)));
          v_tmp_line := ltrim(substrb(v_tmp_line,
                                      v_place + 1,
                                      length(v_tmp_line)));
          -- Start Validating The Header Input, First Omit The 2 PO Characters
          IF substrb(v_read_array(v_counter).po_number, 1, 2) = 'PO' THEN
            v_read_array(v_counter).po_number := substrb(v_read_array(v_counter)
                                                         .po_number,
                                                         3,
                                                         length(v_read_array(v_counter)
                                                                .po_number));
          END IF;
          BEGIN
            SELECT hp.organization_id
              INTO v_read_array(v_counter).operating_unit_id
              FROM hr_operating_units hp
             WHERE hp.name = v_read_array(v_counter).operating_unit;
          EXCEPTION
            WHEN no_data_found THEN
              v_lineretcode := '2';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) ||
                               'No Operating Unit Found,';
          END;
          BEGIN
            SELECT '2', ltrim(rtrim(v_lineerrbuf)) || 'PO Already Exists,'
              INTO v_lineretcode, v_lineerrbuf
              FROM po_headers_all ph
             WHERE segment1 = v_read_array(v_counter).po_number
               AND type_lookup_code = 'STANDARD'
               AND org_id = v_read_array(v_counter).operating_unit_id;
          EXCEPTION
            WHEN no_data_found THEN
              NULL;
          END;
          -- Remove " From Supplier Name
          IF substrb(v_read_array(v_counter).supplier, 1, 1) = chr(34) THEN
            v_read_array(v_counter).supplier := substrb(v_read_array(v_counter)
                                                        .supplier,
                                                        2,
                                                        length(v_read_array(v_counter)
                                                               .supplier) - 2);
          END IF;
          BEGIN
            SELECT s.vendor_id
              INTO v_read_array(v_counter).supplier_id
              FROM ap_suppliers s
             WHERE s.vendor_name_alt = v_read_array(v_counter).supplier
                OR s.vendor_name = v_read_array(v_counter).supplier;
          EXCEPTION
            WHEN no_data_found THEN
              v_lineretcode := '2';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) || 'No Supplier,';
          END;
          -- Get Site
          BEGIN
            SELECT nvl(MIN(ass.vendor_site_id), 0)
              INTO v_read_array(v_counter).suppliersite_id
              FROM ap_supplier_sites_all ass
             WHERE ass.vendor_id = v_read_array(v_counter).supplier_id;
            IF v_read_array(v_counter).suppliersite_id = 0 THEN
              v_lineretcode := '2';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) ||
                               'No Site For Supplier,';
            ELSE
              SELECT ass.ship_to_location_id, ass.bill_to_location_id
                INTO v_read_array(v_counter).ship_to_loc_id,
                     v_read_array(v_counter).bill_to_loc_id
                FROM ap_supplier_sites_all ass
               WHERE ass.vendor_site_id = v_read_array(v_counter)
                    .suppliersite_id;
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              v_lineretcode := '2';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) ||
                               'No Site For Supplier,';
          END;
          -- Start Validating The Lines Input
          BEGIN
            SELECT msi.inventory_item_id, msi.description
              INTO v_read_array(v_counter).item_id,
                   v_read_array(v_counter).item_desc
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = p_master_organiz_id
               AND msi.segment1 = v_read_array(v_counter).item_num;
          EXCEPTION
            WHEN no_data_found THEN
              v_lineretcode := '2';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) ||
                               'No Item In Master,';
          END;
          -- Get ShipTo Inventory Organization
          v_read_array(v_counter).shipto_orgid := xxinv_utils_pkg.get_organization_id_to_assign(v_read_array(v_counter)
                                                                                                .item_id);
          IF v_read_array(v_counter).shipto_orgid IS NULL THEN
            BEGIN
              SELECT msi.organization_id
                INTO v_read_array(v_counter).shipto_orgid
                FROM mtl_system_items_b msi
               WHERE msi.organization_id = v_irk_organizid
                 AND msi.inventory_item_id = v_read_array(v_counter)
                    .item_id;
              v_read_array(v_counter).materialacct := v_irk_materialacct;
            EXCEPTION
              WHEN no_data_found THEN
                BEGIN
                  SELECT msi.organization_id
                    INTO v_read_array(v_counter).shipto_orgid
                    FROM mtl_system_items_b msi
                   WHERE msi.organization_id = v_ipk_organizid
                     AND msi.inventory_item_id = v_read_array(v_counter)
                        .item_id;
                  v_read_array(v_counter).materialacct := v_ipk_materialacct;
                EXCEPTION
                  WHEN no_data_found THEN
                    /*v_lineretcode := '2';
                    v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) ||
                                     'No Item Assignment,';*/
                    ---added by Vitaly 10-Nov-2013
                    BEGIN
                      SELECT msi.organization_id
                        INTO v_read_array(v_counter).shipto_orgid
                        FROM mtl_system_items_b msi
                       WHERE msi.organization_id = v_ita_organizid
                         AND msi.inventory_item_id = v_read_array(v_counter)
                            .item_id;
                      v_read_array(v_counter).materialacct := v_ita_materialacct;
                    EXCEPTION
                      WHEN no_data_found THEN
                        v_lineretcode := '2';
                        v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) ||
                                         'No Item Assignment,';
                    END;
                END;
            END;
          END IF;
          --fnd_file.put_line (fnd_file.log, 'Debug Line '||v_counter||' : '||v_Read_array(v_counter).ShipTo_OrgID);
          -- Check The Found Location
          BEGIN
            SELECT hl.location_id
              INTO v_read_array(v_counter).ship_to_loc_id
              FROM hr_locations_all hl
             WHERE hl.inventory_organization_id = v_read_array(v_counter)
                  .shipto_orgid
               AND hl.ship_to_site_flag = 'Y'
               AND hl.location_id = v_read_array(v_counter).ship_to_loc_id;
          EXCEPTION
            WHEN no_data_found THEN
              BEGIN
                SELECT MAX(hl.location_id)
                  INTO v_read_array(v_counter).ship_to_loc_id
                  FROM hr_locations_all hl
                 WHERE hl.inventory_organization_id = v_read_array(v_counter)
                      .shipto_orgid
                   AND hl.ship_to_site_flag = 'Y';
              EXCEPTION
                WHEN no_data_found THEN
                  v_lineretcode := '2';
                  v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) ||
                                   'No ShipTo Location,';
              END;
          END;
        
          BEGIN
            SELECT gc.currency_code
              INTO v_read_array(v_counter).currency
              FROM gl_currencies gc
             WHERE gc.currency_code = v_read_array(v_counter).currency;
          EXCEPTION
            WHEN no_data_found THEN
              v_lineretcode := '2';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) || 'No Currency,';
          END;
          BEGIN
            SELECT gc.currency_code
              INTO v_read_array(v_counter).pohdrcurreny
              FROM gl_currencies gc
             WHERE gc.currency_code = v_read_array(v_counter).pohdrcurreny;
          EXCEPTION
            WHEN no_data_found THEN
              v_lineretcode := '2';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) ||
                               'No Hdr Currency,';
          END;
          BEGIN
            SELECT p.person_id
              INTO v_read_array(v_counter).buyer_id
              FROM per_all_people_f p
             WHERE ltrim(rtrim(p.first_name)) || ' ' ||
                   ltrim(rtrim(p.last_name)) = v_read_array(v_counter)
                  .buyer
               AND p.current_employee_flag = 'Y'
               AND SYSDATE BETWEEN p.effective_start_date AND
                   p.effective_end_date;
          EXCEPTION
            WHEN no_data_found THEN
              v_lineretcode := '2';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) || 'No Buyer,';
          END;
          BEGIN
            SELECT MAX(mp.mfg_part_num)
              INTO v_read_array(v_counter).mfg_part_num
              FROM mtl_mfg_part_numbers mp
             WHERE mp.inventory_item_id = v_read_array(v_counter).item_id
               AND mp.mfg_part_num = v_read_array(v_counter).mfg_part_num;
          EXCEPTION
            WHEN no_data_found THEN
              v_lineretcode := '1';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) || 'No MFG P/N,';
          END;
          BEGIN
            SELECT to_date(v_read_array(v_counter).promised_date,
                           'YYYYMMDD')
              INTO v_dummydate
              FROM dual;
          EXCEPTION
            WHEN OTHERS THEN
              v_lineretcode := '2';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) ||
                               'No Promised Date,';
          END;
          BEGIN
            SELECT to_date(v_read_array(v_counter).needby_date, 'YYYYMMDD')
              INTO v_dummydate
              FROM dual;
          EXCEPTION
            WHEN OTHERS THEN
              v_lineretcode := '2';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) ||
                               'No NeedBy Date,';
          END;
          -- Check If Item Is Assigned To Ship-To Organization
          BEGIN
            SELECT msi.inventory_item_id
              INTO v_read_array(v_counter).item_id
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = v_read_array(v_counter)
                  .shipto_orgid
               AND msi.inventory_item_id = v_read_array(v_counter).item_id;
          EXCEPTION
            WHEN no_data_found THEN
              v_lineretcode := '2';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) ||
                               'No Item In ShipTo,';
          END;
          -- Check UOM Code Exists
          BEGIN
            SELECT um.uom_code
              INTO v_read_array(v_counter).uom
              FROM mtl_units_of_measure um
             WHERE um.uom_code = v_read_array(v_counter).uom;
          EXCEPTION
            WHEN no_data_found THEN
              v_lineretcode := '2';
              v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) || 'No UOM,';
          END;
          -- Get Exchange Rate
          IF v_read_array(v_counter).pohdrcurreny != 'USD' THEN
            BEGIN
              v_read_array(v_counter).currrate := gl_currency_api.get_rate(x_from_currency   => v_read_array(v_counter)
                                                                                                .pohdrcurreny,
                                                                           x_to_currency     => 'USD',
                                                                           x_conversion_date => SYSDATE,
                                                                           x_conversion_type => 'Corporate');
            EXCEPTION
              WHEN OTHERS THEN
                v_lineretcode := '2';
                v_lineerrbuf  := ltrim(rtrim(v_lineerrbuf)) ||
                                 'No Exchange Rate,';
            END;
          ELSE
            v_read_array(v_counter).currrate := NULL;
          END IF;
          -- Get PO Header Exchange Rate
          IF v_read_array(v_counter)
           .currency != v_read_array(v_counter).pohdrcurreny THEN
            --fnd_file.put_line (fnd_file.log, 'Before Sending For Line '||v_counter);
            v_read_array(v_counter).pohdrrate := get_conv_rate(v_read_array(v_counter)
                                                               .currency,
                                                               v_read_array(v_counter)
                                                               .pohdrcurreny,
                                                               SYSDATE);
          ELSE
            v_read_array(v_counter).pohdrrate := 1;
          END IF;
        END IF;
      
        v_read_array(v_counter).lineretcode := v_lineretcode;
        v_read_array(v_counter).lineerrbuf := v_lineerrbuf;
      
        IF v_lineretcode = '2' THEN
          fnd_file.put_line(fnd_file.log,
                            'Line ' || v_counter || ' : ' || v_lineerrbuf);
        END IF;
      END IF;
    END LOOP;
  
    IF p_processlines = 'Y' THEN
      -- Loop For Entering Lines Into PO Interface
      v_curr_po_num     := '@@@';
      v_hdrinterfaceid  := NULL;
      v_lineinterfaceid := NULL;
      FOR poln IN 1 .. v_counter LOOP
        IF nvl(v_read_array(poln).lineretcode, '0') != '2' THEN
          -- Only For If Number Is Changed, Handle The Header
          IF v_curr_po_num != v_read_array(poln).po_number THEN
            SELECT po_headers_interface_s.nextval
              INTO v_hdrinterfaceid
              FROM dual;
            v_curr_po_num := v_read_array(poln).po_number;
            INSERT INTO po_headers_interface
              (interface_header_id,
               action,
               batch_id,
               process_code,
               org_id,
               document_type_code,
               document_num,
               currency_code,
               agent_id,
               vendor_id,
               vendor_site_id,
               ship_to_location_id,
               bill_to_location_id,
               rate_type_code,
               rate_date,
               creation_date,
               created_by,
               last_update_date,
               last_updated_by,
               --created_language,
               --approval_required_flag,
               comments)
            VALUES
              (v_hdrinterfaceid,
               'ORIGINAL',
               1,
               'PENDING',
               v_read_array(poln).operating_unit_id,
               'STANDARD',
               v_read_array(poln).po_number,
               v_read_array(poln).pohdrcurreny,
               v_read_array(poln).buyer_id,
               v_read_array(poln).supplier_id,
               v_read_array(poln).suppliersite_id,
               v_read_array(poln).ship_to_loc_id,
               v_read_array(poln).bill_to_loc_id,
               'Corporate',
               trunc(SYSDATE),
               SYSDATE,
               v_user_id,
               SYSDATE,
               v_user_id,
               --'US',
               --'N',
               v_read_array(poln).po_description);
          END IF;
        
          -- Make The CLE PO Linkage
          v_polineattr3 := NULL;
          IF v_read_array(poln).currency != v_read_array(poln).pohdrcurreny THEN
            do_linkage(v_read_array (poln).po_number,
                       v_read_array (poln).currency,
                       v_read_array (poln).pohdrcurreny,
                       SYSDATE,
                       v_read_array (poln).unit_price,
                       v_polineattr3);
          END IF;
          -- Handle The PO Line Anyway
          SELECT po_lines_interface_s.nextval
            INTO v_lineinterfaceid
            FROM dual;
          INSERT INTO po_lines_interface
            (interface_line_id,
             interface_header_id,
             action,
             process_code,
             line_num,
             shipment_num,
             line_type_id,
             item_id,
             uom_code,
             closed_code,
             price_break_flag,
             --vendor_product_num,
             quantity,
             unit_price,
             ship_to_location_id,
             ship_to_organization_id,
             line_attribute1,
             item_description,
             need_by_date,
             promised_date,
             line_attribute3,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by)
          VALUES
            (v_lineinterfaceid,
             v_hdrinterfaceid,
             'ADD',
             'PENDING',
             v_read_array(poln).line_number,
             1,
             1,
             v_read_array(poln).item_id,
             v_read_array(poln).uom,
             'OPEN',
             'N',
             --cur_quotation_line.supplier_item,
             v_read_array(poln).lineqty,
             round(v_read_array(poln)
                   .unit_price * v_read_array(poln).pohdrrate,
                   3),
             v_read_array(poln).ship_to_loc_id,
             v_read_array(poln).shipto_orgid,
             v_read_array(poln).mfg_part_num,
             v_read_array(poln).item_desc,
             to_date(v_read_array(poln).needby_date, 'YYYYMMDD'),
             to_date(v_read_array(poln).promised_date, 'YYYYMMDD'),
             v_polineattr3,
             SYSDATE,
             v_user_id,
             SYSDATE,
             v_user_id);
        
          SELECT po_distributions_interface_s.nextval
            INTO v_distinterfaceid
            FROM dual;
          INSERT INTO po.po_distributions_interface
            (interface_header_id,
             interface_line_id,
             interface_distribution_id,
             distribution_num,
             quantity_ordered,
             charge_account_id,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by)
          
          VALUES
            (v_hdrinterfaceid,
             v_lineinterfaceid,
             v_distinterfaceid,
             1,
             v_read_array(poln).lineqty,
             v_read_array(poln).materialacct,
             SYSDATE,
             v_user_id,
             SYSDATE,
             v_user_id);
        
        END IF;
      END LOOP;
    END IF;
    utl_file.fclose(file => v_read_file);
  END ascii_standrardpoint;

BEGIN
  -- Of Package
  v_user_id  := fnd_global.user_id;
  v_login_id := fnd_global.login_id;

END xxpo_uploaddocs_pkg;
/
