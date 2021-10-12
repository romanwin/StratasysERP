create or replace package body xxinv_export_spare_parts_pkg IS
  --------------------------------------------------------------------
  --  name:            XXINV_EXPORT_SPARE_PARTS_PKG
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   06/09/2012
  --------------------------------------------------------------------
  --  purpose :        CHG0035332 - Objet PartnerZone - Spare Parts
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  31/05/21015  Michal Tzvik    initial build
  --  1.1  22/07/2015   Michal Tzvik    CHG0035863: update procedure export_family
  --                                      1. replace msib_dfv.returnable with msib_dfv.repairable
  --                                      2. replace logic for file_name field
  -- 1.2   19/10/2017  yuval tal        INC0104796 modify export family
  -- 1.3   06/06/2018  L. Sarangi       CHG0043165 - My stratasys Spare Catalog changes to support Strataforce
  -- 1.4   20/01/2019  Roman W.         INC0144327 - export_family XXINV - Export Spare Parts Family complited with worning
  -- 1.5   28/08/2019  Bellona B.       CHG0046397 - export_family - Change in Spare Part Catalog Export package for My Stratasys
  -- 1.6   21/01/2020  Roman W.         CHG0047302 - increase number of categories from 30 to 45
  -- 1.7   25/07/2021  Roman W.         INC0237442 - XXINV - Export Spare Parts Family failes when rename
  --------------------------------------------------------------------

  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  customization code: print_message
  --  name:
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      31/05/2015
  --  Purpose :           Print messages to output, log file or dbms_output
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0  31/05/2015    Michal Tzvik    initial build
  --  1.1  22/07/2015    Michal Tzvik    CHG0035863:   PROCEDURE export_family: replace msib_dfv.returnable with msib_dfv.repairable
  --  1.2  27/07/2016    L. Sarangi      CHG0038799 - New fields in SP catalog PZ and Oracle
  -----------------------------------------------------------------------
  PROCEDURE print_message(p_msg         VARCHAR2,
                          p_destination VARCHAR2 DEFAULT fnd_file.log) IS
  BEGIN
    IF fnd_global.conc_request_id = '-1' THEN
      dbms_output.put_line(p_msg);
    ELSE
      fnd_file.put_line(p_destination, p_msg);
    END IF;
  END print_message;
  --------------------------------------------------------------------
  --  name:            Find CS Recommended stock
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   11-Aug-2016
  --------------------------------------------------------------------
  --  purpose :        CHG0038799 - New fields in SP catalog PZ and Oracle
  --                   Added to get the Segement2 value for the 'CS Recommended stock' Category Set
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11-Aug-2016 Lingaraj Sarangi  initial build
  --------------------------------------------------------------------
  FUNCTION find_cs_recommended_stock(p_printers_perved IN VARCHAR2,
                                     p_categorysetid   IN NUMBER,
                                     p_inv_id          IN NUMBER)
    RETURN VARCHAR2 IS
    l_segment1 VARCHAR2(50) := upper(p_printers_perved);
    l_segment2 VARCHAR2(50);
  BEGIN
  
    SELECT (CASE l_segment1
             WHEN '1-10 PRINTERS SERVED' THEN
              segment2
             WHEN '51+ PRINTERS SERVED' THEN
              segment2
             WHEN 'SERVICE-ENGINEER STOCK' THEN
              segment2
             WHEN '11-50 PRINTERS SERVED' THEN
              segment2
           END)
      INTO l_segment2
      FROM mtl_item_categories_v
     WHERE category_set_id = p_categorysetid
       AND inventory_item_id = p_inv_id
       AND organization_id = 91
       AND upper(segment1) = l_segment1;
  
    RETURN l_segment2;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN '';
    WHEN OTHERS THEN
      RETURN 'ERROR';
  END find_cs_recommended_stock;
  --------------------------------------------------------------------
  --  name:            export_family
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   31/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035332 - Objet PartnerZone - Spare Parts
  --                   modify value to fit CSV format
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  31/05/2015  Michal Tzvik      initial build
  --------------------------------------------------------------------
  FUNCTION field_to_csv(p_value VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    RETURN '"' || REPLACE(p_value, '"', '""') || '"';
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN p_value;
  END field_to_csv;

  --------------------------------------------------------------------
  --  name:            export_family
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   31/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035332 - Objet PartnerZone - Spare Parts
  --                   Create csv file of printer family spare parts.
  --                   The file is available in request output and on the server
  --                   until Bpel process move it by FTP.
  --                   Technology, family and categories are defined in
  --                   value set XXCS_PB_PRODUCT_FAMILY
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  31/05/2015  Michal Tzvik      initial build
  --  1.1  22/07/2015  Michal Tzvik      CHG0035863:
  --                                      1. replace msib_dfv.returnable with msib_dfv.repairable
  --                                      2. replace logic for file_name field
  --  1.2  27/07/2016  L. Sarangi        CHG0038799 - New fields in SP catalog PZ and Oracle
  --  1.3  19/10/2017  yuval tal         INC0104796 support extra 10 categories  till 30
  --  1.4  06/06/2018  L. Sarangi        CHG0043165 - My stratasys Spare Catalog changes to support Strataforce
  --                                     Condition added : item assign to item category ¿Visible in MySSYS¿ = Y
  --  1.5  20/01/2019  Roman W.          INC0144327 - XXINV - Export Spare Parts Family complited with worning
  --  1.6  28/08/2019  Bellona B.        CHG0046397 - Change in Spare Part Catalog Export package for My Stratasys
  --  1.7  22/01/2020  Roman W.          CHG0047302 - increase number of categories from 30 to 45
  --  1.8  25/07/2021  Roman W.          INC0237442 -   XXINV - Export Spare Parts Family failes when rename
  --------------------------------------------------------------------
  PROCEDURE export_family(errbuf       OUT VARCHAR2,
                          retcode      OUT VARCHAR2,
                          p_technology IN VARCHAR2,
                          p_family     IN VARCHAR2) IS
  
    C_WARNING_CATEGORY_COUNT NUMBER := 40; -- CHG0047302
    C_MAX_CATEGORY_COUNT     NUMBER := 45; -- CHG0047302
    l_sql                    VARCHAR2(5000);
    l_cat_list               VARCHAR2(1000);
    l_header_rec             VARCHAR(1000);
    l_line_rec               VARCHAR(5000);
    l_miss_col               VARCHAR2(700);
    l_cat_count              NUMBER;
    l_recom_catsetid         NUMBER; -- Added 1.1 26/07/2016 L.Sarangi CHG0038799
    l_error_code             VARCHAR2(700);
    l_error_desc             VARCHAR2(700);
  
    TYPE ref_cur_type IS REF CURSOR;
    l_cat_cursor ref_cur_type;
  
    TYPE req_cat IS RECORD(
      item_number      VARCHAR2(40),
      item_desc        VARCHAR2(240),
      file             VARCHAR2(50),
      repair_dispose   VARCHAR2(25),
      category         VARCHAR2(150),
      remarks          VARCHAR2(4000),
      consumable       VARCHAR2(1), -- Added 1.1 26/07/2016 L.Sarangi CHG0038799
      printers1        VARCHAR2(240), -- Added 1.1 26/07/2016 L.Sarangi CHG0038799
      printers2        VARCHAR2(240), -- Added 1.1 26/07/2016 L.Sarangi CHG0038799
      printers3        VARCHAR2(240), -- Added 1.1 26/07/2016 L.Sarangi CHG0038799
      printers4        VARCHAR2(240), -- Added 1.1 26/07/2016 L.Sarangi CHG0038799
      category_name_1  VARCHAR2(300),
      category_name_2  VARCHAR2(300),
      category_name_3  VARCHAR2(300),
      category_name_4  VARCHAR2(300),
      category_name_5  VARCHAR2(300),
      category_name_6  VARCHAR2(300),
      category_name_7  VARCHAR2(300),
      category_name_8  VARCHAR2(300),
      category_name_9  VARCHAR2(300),
      category_name_10 VARCHAR2(300),
      category_name_11 VARCHAR2(300),
      category_name_12 VARCHAR2(300),
      category_name_13 VARCHAR2(300),
      category_name_14 VARCHAR2(300),
      category_name_15 VARCHAR2(300),
      category_name_16 VARCHAR2(300),
      category_name_17 VARCHAR2(300),
      category_name_18 VARCHAR2(300),
      category_name_19 VARCHAR2(300),
      category_name_20 VARCHAR2(300),
      category_name_21 VARCHAR2(300), --INC0104796
      category_name_22 VARCHAR2(300),
      category_name_23 VARCHAR2(300),
      category_name_24 VARCHAR2(300),
      category_name_25 VARCHAR2(300),
      category_name_26 VARCHAR2(300),
      category_name_27 VARCHAR2(300),
      category_name_28 VARCHAR2(300),
      category_name_29 VARCHAR2(300),
      category_name_30 VARCHAR2(300),
      category_name_31 VARCHAR2(300), -- CHG0047302
      category_name_32 VARCHAR2(300), -- CHG0047302
      category_name_33 VARCHAR2(300), -- CHG0047302
      category_name_34 VARCHAR2(300), -- CHG0047302
      category_name_35 VARCHAR2(300), -- CHG0047302
      category_name_36 VARCHAR2(300), -- CHG0047302
      category_name_37 VARCHAR2(300), -- CHG0047302
      category_name_38 VARCHAR2(300), -- CHG0047302
      category_name_39 VARCHAR2(300), -- CHG0047302
      category_name_40 VARCHAR2(300), -- CHG0047302
      category_name_41 VARCHAR2(300), -- CHG0047302
      category_name_42 VARCHAR2(300), -- CHG0047302
      category_name_43 VARCHAR2(300), -- CHG0047302
      category_name_44 VARCHAR2(300), -- CHG0047302
      category_name_45 VARCHAR2(300));
  
    l_req_cat req_cat;
  
    l_att_category_name fnd_document_categories_tl.user_name%TYPE := fnd_profile.value('XXCS_PZ_ATTACHMENT_CATEGORY');
    l_directory         VARCHAR2(50) := 'XXCS_PZ_SHARED_DIRECTORY';
    l_file_path         VARCHAR2(250);
    l_file_handle       utl_file.file_type;
    l_lines_cnt         NUMBER := 0;
    l_tmp_file_name     VARCHAR2(150);
    l_file_name         VARCHAR2(150);
    l_debag_ing         VARCHAR2(10);
    l_mail_subject      VARCHAR2(500);
    l_mail_body         VARCHAR2(500);
    l_mail_to           VARCHAR2(500);
    l_mail_from         VARCHAR2(500);
  BEGIN
    l_debag_ing := 'EF0';
    l_cat_count := 0;
    --  1.2  27/07/2016  L. Sarangi        CHG0038799
    print_message('Technology :' || p_technology);
    print_message('Family :' || p_family);
  
    --Get Category Set Id for  "CS Recommended stock"
    -- Added 1.1 26/07/2016 L.Sarangi CHG0038799
    SELECT category_set_id
      INTO l_recom_catsetid
      FROM mtl_category_sets
     WHERE upper(category_set_name) = 'CS RECOMMENDED STOCK';
  
    -- Get list of categories, number of categories and csv file path on linux server
    SELECT listagg('''' || concatenated_segments || '''', ',') within GROUP(ORDER BY concatenated_segments) category_name,
           COUNT(*),
           MAX(csv_file_path),
           MAX(pz_file_name)
      INTO l_cat_list, l_cat_count, l_file_path, l_file_name
      FROM (SELECT DISTINCT mc.concatenated_segments,
                            ffv_tech.attribute3 csv_file_path,
                            nvl(ffv_fmly.attribute4, ffv_fmly.flex_value) pz_file_name
              FROM mtl_item_categories       mic,
                   mtl_categories_kfv        mc,
                   mtl_category_sets         mcs,
                   fnd_flex_value_children_v fl, -- family
                   fnd_flex_value_children_v fl_1, -- technology
                   fnd_flex_value_sets       vs,
                   fnd_flex_values           ffv_tech,
                   fnd_flex_values           ffv_fmly
             WHERE mic.category_id = mc.category_id
               AND mcs.category_set_id = mic.category_set_id
               AND mic.organization_id =
                   xxinv_utils_pkg.get_master_organization_id
               AND mcs.category_set_name = 'CS Price Book Product Type'
               AND vs.flex_value_set_name = 'XXCS_PB_PRODUCT_FAMILY'
               AND fl.flex_value_set_id = vs.flex_value_set_id
               AND fl.flex_value = mc.concatenated_segments
               AND fl.parent_flex_value =
                   nvl(p_family, fl.parent_flex_value)
               AND fl_1.flex_value_set_id = vs.flex_value_set_id
               AND fl_1.flex_value = fl.parent_flex_value
               AND fl_1.parent_flex_value =
                   nvl(p_technology, fl_1.parent_flex_value)
               AND ffv_tech.flex_value_set_id = vs.flex_value_set_id
               AND ffv_tech.flex_value = fl_1.parent_flex_value
               AND ffv_fmly.flex_value_set_id = vs.flex_value_set_id
               AND ffv_fmly.flex_value = fl.parent_flex_value
             ORDER BY mc.concatenated_segments);
  
    l_debag_ing := 'EF1';
  
    --  1.2  09/08/2016  L. Sarangi    CHG0038799
    print_message('CSV File Path :' || l_file_path);
    print_message('pz_file_name  :' || l_file_name);
  
    -- For each Technology, a different path exists on server, so the
    -- directory should be updated in run time
    EXECUTE IMMEDIATE 'create or replace directory ' || l_directory ||
                      ' as ''' || l_file_path || '''';
  
    l_debag_ing := 'EF2';
  
    IF l_cat_count > C_WARNING_CATEGORY_COUNT THEN
      l_mail_subject := fnd_global.CONC_REQUEST_ID ||
                        ' - XXINV - Export Spare Parts Family (The amount of categories is growing above ' ||
                        C_WARNING_CATEGORY_COUNT || ' , with maximum - ' ||
                        C_MAX_CATEGORY_COUNT || '. please take care )';
    
      l_mail_body := '<h5 style="color: #2e6c80;">Dear Oracle Tech Team</h5>' ||
                     '<h5 style="color: #5e9ca0;">' ||
                     '<span style="background-color: #ffff00;">' ||
                     '<span style="background-color: #2b2301; color: #fff; display: inline-block; padding: 3px 3px; font-weight: normal ; border-radius: 3px;">' ||
                     'REQUEST_ID : ' || fnd_global.CONC_REQUEST_ID ||
                     ' , </span>' ||
                     'CONCURRENT : XXINV - Export Spare Parts Family' ||
                     '</span> (The number of categories is growing above ' ||
                     C_WARNING_CATEGORY_COUNT || ' , with maximum - ' ||
                     C_MAX_CATEGORY_COUNT || ' . ' || '<p>&nbsp;</p>' ||
                     '<span style="background-color: #993300;">' ||
                     'Please take care' || '</span>' || '</h5>';
    
      xxobjt_wf_mail.send_mail_html(p_to_role     => 'SYSADMIN',
                                    p_subject     => l_mail_subject,
                                    p_body_html   => l_mail_body,
                                    p_err_code    => l_error_code,
                                    p_err_message => l_error_desc);
    END IF;
  
    IF l_cat_count = 0 THEN
      l_debag_ing := 'EF3';
      print_message('Error!!! no category was found. ');
      retcode := '1';
      errbuf  := 'Data caused error.';
      RETURN;
    
      -- ELSIF l_cat_count > 30 THEN Rem by Roman W. 21/01/2020 CHG0047302
    ELSIF l_cat_count > C_MAX_CATEGORY_COUNT THEN
    
      l_debag_ing := 'EF4';
      -- The restriction to 20 categories is needed in order to fit record type req_cat
      print_message('Error!!! more than ' || C_MAX_CATEGORY_COUNT ||
                    ' categories exists for ' || p_technology || ', ' ||
                    p_family);
      retcode := '2';
      errbuf  := 'Data caused error.';
      RETURN;
    END IF;
  
    l_debag_ing := 'EF5';
    -- add missing columns to sql in order to fit record type req_cat
    l_miss_col := '';
    -- FOR i IN l_cat_count + 1 .. 30 LOOP
    FOR i IN l_cat_count + 1 .. C_MAX_CATEGORY_COUNT LOOP
      l_miss_col := l_miss_col || ','''' miss_col_' || i;
    END LOOP;
  
    l_debag_ing := 'EF6';
    -- A dynamic sql statment that retrieves data for csv file
    l_sql := 'select iview.* ' || l_miss_col ||
             ' from (SELECT msib.segment1 item_number ' ||
             ',msib.description ' ||
            -- ',msib.segment1 || ''.PDF'' file_name ' ||
             ',decode(xxobjt_general_utils_pkg.is_file_exist(p_directory => ''XXCS_PZ_IMAGES_DIR'',' ||
             ' p_file_name => msib.segment1 || ''.pdf''),' || '''Y'',' ||
             'msib.segment1 || ''.PDF'',' || 'null) file_name' || -- 1.1 Michal Tzvik CHG0035863: replace logic for file_name field
            --**CHG0046397 Start
            --',decode(nvl(msib_dfv.repairable, ''N''),''N'',''Disposable'',''Returnable'') rma' || -- 1.1 Michal Tzvik CHG0035863: replace msib_dfv.returnable with msib_dfv.repairable
             ',decode(nvl(msib_dfv.returnable, ''N''),''N'',''Disposable'',''Returnable'') rma' ||
            --**CHG0046397 End
             ',xxinv_utils_pkg.get_sp_technical_category(msib.inventory_item_id) tech_category ' ||
             ',replace(replace(xxobjt_fnd_attachments.get_short_text_attached(p_function_name => ''INVIDITM'',p_entity_name =>''MTL_SYSTEM_ITEMS'' ,p_category_name => ''' ||
             l_att_category_name || ''',' ||
             'p_entity_id1 => msib.organization_id ,p_entity_id2 => msib.inventory_item_id),chr(10),''<BR>''),chr(13),null) remarks' ||
             ', Decode(Nvl(msib_dfv.consumable, ''N''),''N'',''0'',''Y'',''1'') consumable' || -- 1.1 26/07/2016 L.Sarangi CHG0038799
             ',(xxinv_export_spare_parts_pkg.find_CS_Recommended_stock(''1-10 Printers Served''  ,' ||
             l_recom_catsetid || ' ,msib.inventory_item_id )) Printers1 ' || -- 1.1 26/07/2016 L.Sarangi CHG0038799
             ',(xxinv_export_spare_parts_pkg.find_CS_Recommended_stock(''11-50 Printers Served'' ,' ||
             l_recom_catsetid || ' ,msib.inventory_item_id )) Printers2 ' || -- 1.1 26/07/2016 L.Sarangi CHG0038799
             ',(xxinv_export_spare_parts_pkg.find_CS_Recommended_stock(''51+ Printers Served''   ,' ||
             l_recom_catsetid || ' ,msib.inventory_item_id )) Printers3 ' || -- 1.1 26/07/2016 L.Sarangi CHG0038799
             ',(xxinv_export_spare_parts_pkg.find_CS_Recommended_stock(''Service-Engineer Stock'',' ||
             l_recom_catsetid || ' ,msib.inventory_item_id )) Printers4 ' || -- 1.1 26/07/2016 L.Sarangi CHG0038799
             ',mc.concatenated_segments category_name ' ||
             ' FROM   mtl_item_categories       mic, ' ||
             '  mtl_categories_kfv        mc, ' ||
             '  mtl_category_sets         mcs, ' ||
             '  mtl_system_items_b        msib, ' ||
             '  mtl_system_items_b_dfv    msib_dfv, ' ||
             '  fnd_flex_value_children_v fl, ' ||
             '  fnd_flex_value_children_v fl_1, ' ||
             '  fnd_flex_value_sets       vs ' ||
             ' WHERE  msib.inventory_item_id = mic.inventory_item_id ' ||
             ' AND    msib.organization_id = mic.organization_id ' ||
             ' AND    msib_dfv.row_id(+) = msib.rowid ' ||
             ' AND    mic.category_id = mc.category_id ' ||
             ' AND    mcs.category_set_id = mic.category_set_id ' ||
             ' AND    mic.organization_id = xxinv_utils_pkg.get_master_organization_id ' ||
             ' AND    mcs.category_set_name = ''CS Price Book Product Type'' ' ||
             ' AND    vs.flex_value_set_name = ''XXCS_PB_PRODUCT_FAMILY'' ' ||
            --CHG0043165 - Check Item is Assigned to "Visible in MySSYS"
             ' AND  nvl(xxssys_oa2sf_util_pkg.get_category_value(''Visible in MySSYS'' ,msib.inventory_item_id ),''N'') = ''Y''  ' ||
             ' AND    fl.flex_value_set_id = vs.flex_value_set_id ' ||
             ' AND    fl.flex_value = mc.concatenated_segments ' ||
             ' AND    fl.parent_flex_value =:1 ' ||
             ' AND    fl_1.flex_value_set_id = vs.flex_value_set_id ' ||
             ' AND    fl_1.flex_value = fl.parent_flex_value ' ||
             ' AND    fl_1.parent_flex_value = :2) ' ||
             ' pivot (max(''1'')  ' || ' for category_name in (' ||
             l_cat_list || ')) iview ' || ' order by item_number';
  
    print_message('l_sql: ' || chr(10) || l_sql);
    l_debag_ing := 'EF7';
  
    l_file_name := regexp_replace(l_file_name, '( *[[:punct:]])|( )', '_'); -- added by Roman W. 25/07/2021 INC0237442
    -- In order to avoid bpel process from reading the file before this program
    -- complete writing, the temporary file name include '.tmp'.
    -- At the end the program rename the file by removing '.tmp' extension.
  
    /* rem by Roman W. 25/07/2021 INC0237442
    l_tmp_file_name := fnd_global.conc_request_id || '_' ||
                       regexp_replace(l_file_name,
                                      '( *[[:punct:]])|( )',
                                      '_') || '.csv.tmp';
    */
  
    l_tmp_file_name := fnd_global.conc_request_id || '_' || l_file_name ||
                       '.csv.tmp'; -- Added By Roman W. INC0237442
  
    l_file_name := fnd_global.conc_request_id || '_' || l_file_name ||
                   '.csv';
  
    l_debag_ing := 'EF8';
    -- Open file for writing
    l_file_handle := utl_file.fopen(location     => l_directory,
                                    filename     => l_tmp_file_name,
                                    open_mode    => 'w',
                                    max_linesize => 32767 -- INC0144327
                                    );
  
    l_debag_ing := 'EF9';
    -- Modified 1.1 09-Aug-2016 L.Sarangi CHG0038799
    l_header_rec := 'partnum,description,file,Repair/Dispose,Category,remarks,Consumable,Printers1,Printers2,Printers3,Printers4,' ||
                    REPLACE(l_cat_list, '''', '');
  
    -- insert header line to file
    print_message(p_destination => fnd_file.output, --
                  p_msg         => l_header_rec);
    utl_file.put_line(l_file_handle, l_header_rec);
  
    l_debag_ing := 'EF10';
    OPEN l_cat_cursor FOR l_sql
      USING p_family, p_technology;
  
    LOOP
      FETCH l_cat_cursor
        INTO l_req_cat;
    
      EXIT WHEN l_cat_cursor%NOTFOUND;
    
      l_debag_ing := 'EF11';
      l_lines_cnt := l_lines_cnt + 1;
      -- INC0104796 add 21-30
      l_line_rec := field_to_csv(l_req_cat.item_number) || ',' ||
                    field_to_csv(l_req_cat.item_desc) || ',' ||
                    field_to_csv(l_req_cat.file) || ',' ||
                    field_to_csv(l_req_cat.repair_dispose) || ',' ||
                    field_to_csv(l_req_cat.category) || ',' ||
                    field_to_csv(l_req_cat.remarks) || ',' ||
                    field_to_csv(l_req_cat.consumable) || ',' || --Added 1.1 26/07/2016 L.Sarangi CHG0038799
                    field_to_csv(l_req_cat.printers1) || ',' || --Added 1.1 26/07/2016 L.Sarangi CHG0038799
                    field_to_csv(l_req_cat.printers2) || ',' || --Added 1.1 26/07/2016 L.Sarangi CHG0038799
                    field_to_csv(l_req_cat.printers3) || ',' || --Added 1.1 26/07/2016 L.Sarangi CHG0038799
                    field_to_csv(l_req_cat.printers4) || ',' || --Added 1.1 26/07/2016 L.Sarangi CHG0038799
                    field_to_csv(nvl(l_req_cat.category_name_1, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_2, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_3, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_4, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_5, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_6, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_7, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_8, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_9, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_10, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_11, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_12, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_13, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_14, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_15, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_16, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_17, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_18, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_19, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_20, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_21, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_22, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_23, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_24, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_25, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_26, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_27, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_28, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_29, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_30, '0')) || ',' ||
                    field_to_csv(nvl(l_req_cat.category_name_31, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_32, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_33, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_34, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_35, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_36, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_37, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_38, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_39, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_40, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_41, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_42, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_43, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_44, '0')) || ',' || -- Added by Roman W. 21/01/2020 CHG0047302
                    field_to_csv(nvl(l_req_cat.category_name_45, '0'));
    
      l_debag_ing := 'EF12';
      -- remove extra columns:
      -- There might be extra "miss_columns" for categories
      -- which cause extra un-needed fields in output file.
      -- Number of total category columns in record type is 30
      -- Number of existing (actual) category columns is l_cat_count
      -- So number of extra miss columns is (30-l_cat_count)
      -- For each field there are 4 characters to remove: "0",
      -- SELECT REVERSE(substr(REVERSE(l_line_rec), (30 - l_cat_count) * 4 + 1)) -- rem by Roman W. 21/01/2020 CHG0047302
    
      SELECT REVERSE(substr(REVERSE(l_line_rec),
                            (C_MAX_CATEGORY_COUNT - l_cat_count) * 4 + 1)) -- Added by Roman W. 21/01/2020 CHG0047302
        INTO l_line_rec
        FROM dual;
    
      l_debag_ing := 'EF13';
      -- insert line to file
      print_message(p_destination => fnd_file.output, --
                    p_msg         => l_line_rec);
      utl_file.put_line(l_file_handle, l_line_rec);
    
      l_debag_ing := 'EF14';
    END LOOP;
  
    l_debag_ing := 'EF15';
    CLOSE l_cat_cursor;
    utl_file.fclose(l_file_handle);
  
    l_debag_ing := 'EF16';
    -- remove extension ".tmp" after finish write to file
    utl_file.frename(src_location  => l_directory, --
                     src_filename  => l_tmp_file_name, --
                     dest_location => l_directory, --
                     dest_filename => l_file_name);
    l_debag_ing := 'EF18';
  
  EXCEPTION
    WHEN utl_file.invalid_path THEN
      retcode := '2';
      errbuf  := errbuf || 'Invalid Path for ' || ltrim(l_file_name) ||
                 chr(0);
    WHEN utl_file.invalid_mode THEN
      retcode := '2';
      errbuf  := errbuf || 'Invalid Mode for ' || ltrim(l_file_name) ||
                 chr(0);
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := 'Unexpected error in xxinv_export_spare_parts_pkg.export_family: ' ||
                 SQLERRM || '(DEBUG IND:' || l_debag_ing || ')';
  END export_family;

  --------------------------------------------------------------------
  --  name:            submit_export_family
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   31/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035332 - Objet PartnerZone - Spare Parts
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  31/05/2015  Michal Tzvik      initial build
  --------------------------------------------------------------------
  PROCEDURE submit_export_family(errbuf       OUT VARCHAR2,
                                 retcode      OUT VARCHAR2,
                                 p_technology IN VARCHAR2,
                                 p_family     IN VARCHAR2,
                                 x_request_id OUT VARCHAR2) IS
  
    l_phase         VARCHAR2(20);
    l_status        VARCHAR2(20);
    l_dev_phase     VARCHAR2(20);
    l_dev_status    VARCHAR2(20);
    l_message       VARCHAR2(150);
    l_complete_flag BOOLEAN := FALSE;
    l_return_bool   BOOLEAN;
  
    l_prog_short_name VARCHAR2(30) := 'XXINV_EXP_SPARE_PARTS_FAMILY';
  BEGIN
  
    errbuf  := '';
    retcode := '0';
  
    x_request_id := fnd_request.submit_request(application => 'XXOBJT', --
                                               program     => l_prog_short_name, --
                                               argument1   => p_technology, --
                                               argument2   => p_family);
    COMMIT;
  
    IF x_request_id = 0 THEN
      errbuf  := 'Error submitting request of ' || l_prog_short_name;
      retcode := 1;
      RETURN;
    
    ELSE
      errbuf := 'Request ' || x_request_id || ' was submitted successfully';
    
    END IF;
  
    WHILE l_complete_flag = FALSE LOOP
      l_return_bool := fnd_concurrent.wait_for_request(request_id => x_request_id, --
                                                       INTERVAL   => 5, --
                                                       phase      => l_phase, --
                                                       status     => l_status, --
                                                       dev_phase  => l_dev_phase, --
                                                       dev_status => l_dev_status, --
                                                       message    => l_message);
    
      IF upper(l_phase) = 'COMPLETED' THEN
        l_complete_flag := TRUE;
        IF upper(l_status) IN ('ERROR', 'WARNING') THEN
          retcode := 1;
          errbuf  := l_prog_short_name ||
                     ' concurrent program completed in ' || l_status ||
                     '. See log for request_id=' || x_request_id;
        END IF;
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Error submitting ' || l_prog_short_name || ': ' ||
                 SQLERRM;
      retcode := 1;
    
  END submit_export_family;
  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   31/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035332 - Objet PartnerZone - Spare Parts
  --                   A shell procedure that run export family for each
  --                   printer family in the range.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  31/05/2015  Michal Tzvik      initial build
  --  1.1  09/08/2016  L. Sarangi        CHG0038799 - New fields in SP catalog PZ and Oracle
  --------------------------------------------------------------------
  PROCEDURE main(errbuf       OUT VARCHAR2,
                 retcode      OUT VARCHAR2,
                 p_technology IN VARCHAR2,
                 p_family     IN VARCHAR2) IS
  
    l_errbuf         VARCHAR2(4000);
    l_retcode        VARCHAR2(1);
    l_exp_request_id NUMBER;
  
    CURSOR c_family(p_technology VARCHAR2, p_family VARCHAR2) IS
      SELECT fl_1.parent_flex_value technology, fl.parent_flex_value family
        FROM fnd_flex_value_children_v fl,
             fnd_flex_value_children_v fl_1,
             fnd_flex_value_sets       vs
       WHERE 1 = 1
         AND vs.flex_value_set_name = 'XXCS_PB_PRODUCT_FAMILY'
         AND fl.flex_value_set_id = vs.flex_value_set_id
         AND fl_1.flex_value_set_id = vs.flex_value_set_id
         AND fl_1.flex_value = fl.parent_flex_value
         AND fl_1.parent_flex_value =
             nvl(p_technology, fl_1.parent_flex_value)
         AND fl.parent_flex_value = nvl(p_family, fl.parent_flex_value)
       GROUP BY fl_1.parent_flex_value, fl.parent_flex_value
       ORDER BY fl_1.parent_flex_value, fl.parent_flex_value;
  
  BEGIN
  
    FOR l_family IN c_family(p_technology, p_family) LOOP
      submit_export_family(l_errbuf,
                           l_retcode,
                           l_family.technology,
                           l_family.family,
                           l_exp_request_id);
      IF l_retcode = 1 THEN
        retcode := '1';
        errbuf  := 'A failure oocur, see log file for  details.';
        print_message('Error occur for request_id ' || l_exp_request_id || ': ' ||
                      l_errbuf);
      END IF;
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '1';
      errbuf  := 'Unexpected error in xxinv_export_spare_parts_pkg.main: ' ||
                 SQLERRM;
  END main;

END xxinv_export_spare_parts_pkg;
/
