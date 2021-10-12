CREATE OR REPLACE PACKAGE BODY "XXINV_BARTENDER_PKG" IS
  --------------------------------------------------------------------
  --  name:            XXINV_BARTENDER_PKG
  --  create by:       Eli.Ivanir
  --  Revision:        1.11
  --  creation date:   7/8/2009
  --------------------------------------------------------------------
  --  purpose :        REP354 - Receiving Stickers
  --                   Handle BarTender Printings
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    07/08/09    Eli.Ivanir       Initial Build
  --  1.1    5.9.10      yuval tal        change/add  revision logic  at procedures :
  --                                      print_transaction
  --                                      print_rcv_pack
  --  1.2    5.5.11      yuval tal        add print_general_stiker
  --  1.3    29.4.12     yuval tal        add  print_dangerous_mat_stiker CR404
  --  1.4    11.11.12    yuval tal        print_dangerous_mat_stiker: modify param order in
  --                                      in case of quantity null : get quantity by select
  --  1.5    12.12.12    yuval tal        cust612/cr618 Send Formulations Lot data to Inkjet printerSend Formulations Lot data to Inkjet printer
  --                                      add set_ink_printer and    call_printer_tcp
  --  1.6    29.08.13    yuval tal        rep 354 cr 980 add  print_rcv_pack_w
  --  1.7    01.09.13    yuval tal        rep 354 cr 981 add  print_Inspection_Release
  --  1.8    07/10/2013  Dalit A. Raviv   add print_wpi_inspection_release (CR1022)
  --  1.9    05.11.13    yuval tal        cr 1079  add print_subinventory_locator
  --  1.10   25/11/2013  Dalit A. Raviv   add print_ssys_rcv, open_file (CR1116 EP Project)
  --  1.11   22/01/2014  Dalit A. Raviv   new procedure print_auto_label_lot_bottling CR 1259
  --  1.12   29/04/2014  Dalit A. Raviv   procedure print_ssys_rcv -  Add Locator info.
  --  1.13   25.05.14    yuval tal        CHG0032254 : print_dangerous_mat_stiker : Advancing the address retriving for the Dangerous goods sticker
  --  1.14   29/05/2014  Dalit A. Raviv   CHG0032329 - XX: Print Kanban Label Sticker program support printing multi labels
  --  1.15   22/07/2014  yuval tal        CHG0032790 modify print_dft
  --  1.16   28/09/2014  Dalit A. Raviv   CHG0032719 - Release inspection stickers add locator parameter
  --  1.17   16/03/2015  Dalit A. Raviv   CHG0034195 - add procedure print_dft_med
  --  1.18   13/04/2015  Michal Tzvik     CHG0034135 ? Adapt Dangerous Label to be used in Political: update procedure print_dangerous_mat_stiker
  --  1.19   28/09/2014  yuval tal        CHG0032574 add print_ato_hasp_lbl
  --  1.20   29.11.2015  yuval tal        CHG0037096 Fix progarm codes to avoid data duplication due to lot uniqueness remove
  --                                      modify print_resin_pack
  --  1.21   07.09.2017  piyali.bhowmick  INC0101330 - Issue in Label Printing
  --  1.22   27.12.17    Yuval tal        CHG0035037 - modify PRINT_SSYS_RCV
  --  1.23   14.02.2018  bellona banerjee CHG0041294- Added P_Delivery_Name to print_dangerous_mat_stiker as part of delivery_id to delivery_name conversion
  --  1.3    26/02/2019  Roman W.         CHG0045071 - print_resin_pack_new
  --  1.4    27/02/2019  Roman W.         CHG0044871 - print_resin_pack
  --  1.5    27/02/2019  Roman W.         CHG0044871 - print_resin_pack_hamara
  --  1.6    30/04/2019  Eric Hubert      CHG0045604 - Modified PRINT_SSYS_RCV
  --  1.7    13/06/2019  Roman W.         CHG0045832 - Change sticker -XX:Print bottling sticker after hamara
  --                                         create new procedure : print_resin_pack_small_hamara
  -- 1.8     16/7/2019   yuval tal         CHG0046031 - modify print_rcv_pack_w
  -- 1.9     30/10/2019  Bellona(TCS)     CHG0046734 spilt input lot number parameter into lot# and item id.
  -- 2.0     13/01/2019  Roman W.         CHG0047181 - New Inkjet printer in Resin plant
  --                                             ValueSet : XXINV_INKJET_PRINTERS
  --                                          1) XX: Send Formulations Lot to Desktop Inkjet
  --                                                    XXINV_BARTENDER_PKG.print_resin_pack_ink
  --
  --                                          2) XX: Send Formulations Lot to Desktop Inkjet after Hamara
  --                                                    XXINV_BARTENDER_pkg.print_resin_pack_hamara_ink
  -- 2.0.1    28/01/2020  Roman W.        CHG0047181 - print_resin_pack_ink : l_template  varchar2(50) -> varchar2(150)
  -- 3.1      17/09/2020  Roman W.        CHG0048593 - Change formulation sticker and desktop inkjet
  -- 3.2      29/09/2020  Roman W.        CHG0048593 - changes in SQL
  -- 3.3      11/11/2020  yuval tal       INC0212136 - change lot source in print_resin_pack_ink
  -- 3.4      16/11/2020  Roman W.        CHG0048914 - XX: Print Formulations Lot Sticker
  --------------------------------------------------------------------

  PROCEDURE message(p_msg IN VARCHAR2) IS
    ----------------------------
    --       Code Section
    ----------------------------
    l_msg VARCHAR2(400);
    ----------------------------
    --       Code Section
    ----------------------------
  BEGIN
    l_msg := substr(to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') || ' - ' ||
                    p_msg,
                    1,
                    400);
    IF fnd_global.conc_request_id > 0 THEN
      fnd_file.put_line(fnd_file.log, l_msg);
    ELSE
      dbms_output.put_line(p_msg);
    END IF;
  END message;
  -----------------------------------------------------------------------------
  -- Ver     When         Who              Description
  -- ------  -----------  ---------------  ------------------------------------
  -- 1.0     03/03/2019   Roman W.
  -----------------------------------------------------------------------------
  FUNCTION get_dev_dorectory RETURN VARCHAR2 IS
  BEGIN
    EXECUTE IMMEDIATE 'create or replace directory XXINV_BARTENDER as ''/UtlFiles/shared/DEV/bartender''';
    RETURN 'XXINV_BARTENDER';
  END get_dev_dorectory;
  ---------------------------------------
  -- call_printer_tcp
  --------------------------------------------------------------------------
  -- Porpose: cust612/cr618
  -- support  Send Formulations Lot data to Inkjet printer
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  12.12.12   yuval tal        initial Build

  PROCEDURE call_printer_tcp(errbuf       OUT VARCHAR2,
                             retcode      OUT VARCHAR2,
                             p_printer_ip VARCHAR2,
                             p_port       NUMBER,
                             p_string     VARCHAR2) IS
  
    -- send string to ink printer by tcp connection
    c      utl_tcp.connection; -- TCP/IP connection to the web server
    retval PLS_INTEGER;
  
    -- l_str    VARCHAR2(100) := 'OQ001Batch #:vMTL9164rExp: v29-Nov-2013';-- 'OQ001kBATCH #:vMTL9164rkExp: v29-Nov-2013';
    l_result         VARCHAR2(32000);
    l_printer_result RAW(5);
    -- l_remote_host    VARCHAR2(100) := '10.11.90.247';
  BEGIN
  
    retcode := 0;
    -- fnd_log put ('Calculate String to send=' l_str);
  
    c := utl_tcp.open_connection(remote_host => p_printer_ip,
                                 remote_port => p_port,
                                 charset     => 'US7ASCII');
    -- utl_tcp.secure_connection(c);
  
    -- send request
    retval := utl_tcp.write_text(c, p_string);
    utl_tcp.flush(c);
    -- read result
  
    l_result := utl_tcp.read_raw(c, l_printer_result, 1, TRUE);
  
    dbms_output.put_line('x' || 'x' || l_printer_result || 'x');
  
    --utl_tcp.flush(c);
    utl_tcp.close_connection(c);
  
    IF utl_raw.cast_to_varchar2(l_printer_result) = chr(6) THEN
      dbms_output.put_line('ok!');
      errbuf := 'Printer Successfully Set';
    ELSE
      errbuf := 'Printer Error Code' || l_printer_result || '.';
      dbms_output.put_line(errbuf);
      retcode := 1;
    END IF;
  
  EXCEPTION
    WHEN utl_tcp.network_error THEN
      retcode := 1;
      errbuf  := 'Connection Timeout';
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Error: Unable to Set printer, ' || SQLERRM;
    
  END;

  --Resin_Pack_Kg , IL05 - PR LABEL01, 11143 - 03200 | 18946, 734, 1, / UtlFiles / TEST / bartender
  ---------------------------------------------------------------------------
  -- Concurrents :
  --      XXWIPBLSTCK  - XX: Print Bottling lot job sticker(RES)    - V
  --      XXWIPFLSTCK  - XX: Print Formulations Lot Sticker
  ---------------------------------------------------------------------------
  --  ver    date         name          desc
  ---------  -----------  ------------  -------------------------------------
  --  1.2    29.11.2015   yuval tal     CHG0037096 Fix progarm codes to avoid data duplication due to lot uniqueness remove
  --  1.3    26/02/2019   Roman W.      CHG0044871 - Adding a weight line to an MTL sticker is required...
  --                                             Concurrent : XXWIPFLSTCK/XX: Print Formulations Lot Sticker
  --                                       Barcode template : Resin_Small
  --                                      template location : \\usnj01prn02p\OA_Bar_Tender
  --  1.4    16/09/2020   Roman W.      CHG0048593 - Change formulation sticker and desktop inkjet
  --  1.5    29/09/2020   Roman W.      CHG0048593 - to SQL added org_id as a part of too many rows bug fix
  --  1.6    16/11/2020   Roman W.      CHG0048914 - XX: Print Formulations Lot Sticker
  ---------------------------------------------------------------------------
  PROCEDURE print_resin_pack(errbuf         OUT VARCHAR2,
                             retcode        OUT VARCHAR2,
                             p_stiker_name  IN VARCHAR2, -- 10
                             p_printer_name IN VARCHAR2, -- 20
                             p_bot_lot      IN VARCHAR2, -- 30 Added by Roman W. 16/09/2020 CHG0048593
                             p_org_id       IN NUMBER, -- 40
                             p_quantity     IN NUMBER, -- 50
                             p_location     IN VARCHAR2, -- 60
                             p_job_fg       IN VARCHAR2 -- 70 -- added CHG0044871
                             ) IS
  
    v_comp_lot     mtl_lot_numbers.lot_number%TYPE;
    v_assembly_lot mtl_lot_numbers.lot_number%TYPE;
    -- v_expiration_date    mtl_lot_numbers.expiration_date%TYPE; --rem CHG0044871
    v_expiration_date_f3 VARCHAR2(30); -- added CHG0044871
    v_expiration_date_f7 VARCHAR2(30); -- added CHG0044871
    v_segment1           mtl_system_items_b.segment1%TYPE;
    v_start_quantity     wip_discrete_jobs.start_quantity%TYPE := 1;
    v_description        mtl_system_items_b.description%TYPE;
    plist_file           utl_file.file_type;
    v_file_name          VARCHAR2(500);
    v_net_weight         mtl_descr_element_values_v.element_value%TYPE; -- CHG0044871
    v_net_weight_lbs     mtl_descr_element_values_v.element_value%TYPE; -- CHG0044871
  
    l_is_prod     VARCHAR2(300) := xxobjt_general_utils_pkg.am_i_in_production; -- CHG0044871 Y/N
    l_stiker_name VARCHAR2(300);
    l_location    VARCHAR2(300);
  BEGIN
  
    message('Concurrent      : XX: Print Bottling lot job sticker(MTL-OBJ) / XXWIPBLSTCKMTL');
    message('Package         : xxinv_bartender_pkg.print_resin_pack');
    message('p_stiker_name   :' || p_stiker_name);
    message('p_printer_name  :' || p_printer_name);
    message('p_bot_lot       :' || p_bot_lot);
    message('p_org_id        :' || p_org_id);
    message('p_quantity      :' || p_quantity);
    message('p_location      :' || p_location);
    message('p_job_fg        :' || p_job_fg);
    message('l_is_prod       :' || l_is_prod);
  
    -- change 03/09/2009 - expiration date needs to be by the MTL and not the RES
    v_comp_lot := p_bot_lot; --nvl(p_component_lot, p_bot_lot); -- Added CHG0048593
  
    IF 'Y' = l_is_prod THEN
      l_stiker_name := p_stiker_name;
      l_location    := p_location;
    ELSE
      l_stiker_name := 'DEV_' || p_stiker_name;
      l_location    := get_dev_dorectory;
    END IF;
  
    message('(New)l_stiker_name   :' || l_stiker_name);
    message('(New)l_location      :' || l_location);
  
    v_file_name := l_stiker_name || '_' ||
                   to_char(SYSDATE, 'RRMMDD_HH24MISS') || '.txt';
  
    BEGIN
      /* rem by Roman W 29/09/2020 CHG0048593
      SELECT mln.lot_number assembly_lot,
             -- mln.expiration_date, rem CHG0044871
             to_char(mln.expiration_date, 'dd-Mon-yyyy') expiration_date_f3, -- added CHG0044871
             to_char(mln.expiration_date, 'ddmmyyyy') expiration_date_f7, -- added CHG0044871
             msib.segment1,
             wdj.start_quantity,
             msib.description
        INTO v_assembly_lot,
             v_expiration_date_f3,
             v_expiration_date_f7,
             v_segment1,
             v_start_quantity,
             v_description
        FROM wip_discrete_jobs  wdj,
             wip_entities       we,
             mtl_lot_numbers    mln,
             mtl_system_items_b msib
       WHERE wdj.wip_entity_id = we.wip_entity_id
         AND we.wip_entity_name = p_bot_lot --p_job_name
         AND mln.lot_number = v_comp_lot
         AND mln.inventory_item_id = we.primary_item_id --CHG0037096
         AND mln.organization_id = we.organization_id --CHG0037096
         AND msib.inventory_item_id = we.primary_item_id
         AND msib.organization_id = p_org_id
         AND wdj.organization_id = we.organization_id
         AND wdj.organization_id = p_org_id;
      */
      /* rem by Roman W. 16/11/2020 CHG0048914
      -- Added by Roman W. 22/09/2020 CHG0048593
      SELECT --we.wip_entity_id,
      --we.wip_entity_name,
       mln.lot_number assembly_lot,
       to_char(mln.expiration_date, 'dd-Mon-yyyy') expiration_date_f3, -- added CHG0044871
       to_char(mln.expiration_date, 'ddmmyyyy') expiration_date_f7, -- added CHG0044871
       msib.segment1,
       --wdj.start_quantity,
       msib.description
        INTO v_assembly_lot,
             v_expiration_date_f3,
             v_expiration_date_f7,
             v_segment1,
             --v_start_quantity,
             v_description
        FROM wip_entities we, mtl_lot_numbers mln, mtl_system_items_b msib
       WHERE 1 = 1
         AND mln.lot_number || '|' || mln.inventory_item_id = p_bot_lot
         AND mln.inventory_item_id = we.primary_item_id --CHG0037096
         AND mln.organization_id = we.organization_id --CHG0037096
         AND msib.inventory_item_id = we.primary_item_id
         AND msib.organization_id = we.organization_id
         AND we.organization_id = p_org_id
         AND we.wip_entity_id IN
             (SELECT mt.transaction_source_id
                FROM mtl_transaction_lot_numbers mt
               WHERE mt.lot_number = mln.lot_number
                 AND mln.inventory_item_id = mt.inventory_item_id
                 AND mln.organization_id = mt.organization_id
                 AND we.wip_entity_id = mt.transaction_source_id);
      */
      -- Added By Roman W. 16/11/2020 CHG0048914
      SELECT mln.lot_number assembly_lot,
             to_char(mln.expiration_date, 'dd-Mon-yyyy') expiration_date_f3, -- added CHG0044871 
             to_char(mln.expiration_date, 'ddmmyyyy') expiration_date_f7, -- added CHG0044871 
             msib.segment1,
             msib.description
        INTO v_assembly_lot,
             v_expiration_date_f3,
             v_expiration_date_f7,
             v_segment1,
             v_description
        FROM mtl_lot_numbers mln, mtl_system_items_b msib
       WHERE mln.lot_number || '|' || mln.inventory_item_id = p_bot_lot
         AND mln.inventory_item_id = msib.inventory_item_id
         AND mln.organization_id = msib.organization_id
         AND mln.organization_id = p_org_id;
    
      IF p_job_fg IS NOT NULL THEN
      
        SELECT md.element_value, md.element_value * 2.2
          INTO v_net_weight, v_net_weight_lbs
          FROM wip_entities fg, mtl_descr_element_values_v md
         WHERE fg.wip_entity_name = p_job_fg
           AND fg.organization_id = p_org_id
           AND fg.primary_item_id = md.inventory_item_id
           AND md.element_name = 'Weight Factor (Kg)'
           AND md.element_value IS NOT NULL; -- chg0044871
      
        v_net_weight := v_net_weight || 'kg (' || v_net_weight_lbs ||
                        'lbs)';
      ELSE
      
        SELECT md.element_value, md.element_value * 2.2
          INTO v_net_weight, v_net_weight_lbs
          FROM mtl_lot_numbers mlt, mtl_descr_element_values_v md
         WHERE mlt.lot_number = v_assembly_lot
           AND mlt.organization_id = p_org_id
           AND mlt.inventory_item_id = md.inventory_item_id
           AND md.element_name = 'Weight Factor (Kg)'
           AND md.element_value IS NOT NULL;
      
        v_net_weight := v_net_weight || 'kg (' || v_net_weight_lbs ||
                        'lbs)';
      
      END IF;
    
    EXCEPTION
      WHEN no_data_found THEN
        retcode := '2';
        message('EXCEPTION_NO_DATA_FOUND_1 : ' || SQLERRM);
        errbuf := 'EXCEPTION_NO_DATA_FOUND_1 : ' || SQLERRM || chr(0);
      WHEN too_many_rows THEN
        retcode := '2';
        message('EXCEPTION_TOO_MANY_ROWS_1 : ' || SQLERRM);
        errbuf := 'EXCEPTION_TOO_MANY_ROWS_1 : ' || SQLERRM || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 2 THEN
    
      BEGIN
        plist_file := utl_file.fopen(location  => l_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          message('EXCEPTION_UTL_FILE.INVALID_PATH Invalid Path for ' ||
                  ltrim(v_file_name) || ' - ' || SQLERRM);
          errbuf := 'EXCEPTION_UTL_FILE.INVALID_PATH Invalid Path for ' ||
                    ltrim(v_file_name) || chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
        
          errbuf := 'EXCEPTION_UTL_FILE.INVALID_MODE : ' ||
                    ltrim(v_file_name) || ' - ' || SQLERRM;
          message(errbuf);
        
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := 'EXCEPTION_UTL_FILE.INVALID_OPERATION : ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
          message(errbuf);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := 'EXCPTION_OTHERS : ' || ltrim(v_file_name) || ' - ' ||
                     SQLERRM || chr(0);
          message(errbuf);
      END;
    
      IF nvl(retcode, 0) <> 2 THEN
        utl_file.put_line(plist_file,
                          '%BTW% /AF=C:\OA_Bar_Tender\' || l_stiker_name ||
                          '.BTW /D=' || v_bartender_txt_location ||
                          ' /prn="' || p_printer_name || '" /R=3 /P /DD' ||
                          chr(13));
        utl_file.put_line(plist_file, '%END%' || chr(13));
        utl_file.put_line(plist_file,
                          --p_job_name || chr(9) -- field 1 -- R
                          v_assembly_lot || chr(9) -- field 1
                           || v_comp_lot || chr(9) -- field 2
                          -- || to_char(v_expiration_date, 'dd-Mon-yyyy') ||  chr(9) -- field 3
                           || v_expiration_date_f3 || chr(9) -- field 3
                           || v_segment1 || chr(9) -- field 4
                           || v_start_quantity || chr(9) -- field 5
                           || v_description || chr(9) -- field 6
                          -- || to_char(v_expiration_date, 'ddmmyyyy') || chr(9) -- field 7
                           || v_expiration_date_f7 || chr(9) -- field 7
                           || chr(9) -- field 8
                           || chr(9) -- field 9
                           || chr(9) -- field 10
                           || chr(9) -- field 11
                           || chr(9) -- field 12
                           || chr(9) -- field 13
                           || chr(9) -- field 14
                           || chr(9) -- field 15
                           || chr(9) -- field 16
                           || chr(9) -- field 17
                           || chr(9) -- field 18
                           || chr(9) -- field 19
                          -- || chr(9) -- field 20 -- rem CHG0044871
                           || v_net_weight || chr(9) -- field 20 -- added CHG0044871
                           || p_quantity -- field 21
                           || chr(13));
      END IF;
    END IF;
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
      message('file CLOSED');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := 'EXCEPTION_OTHERS xxinv_bartender_pkg.print_resin_pack(' ||
                 p_stiker_name || ',' || p_printer_name || ',' ||
                /*p_job_name CHG0048593*/
                 p_bot_lot || ',' || p_org_id || ',' || /*p_component_lot || ',' ||*/
                 p_quantity || ',' || p_location || ',' || p_job_fg ||
                 ') - ' || SQLERRM;
      message(errbuf);
  END print_resin_pack;

  -------------------------------------------------------------------------
  -- print_rcv_pack_w
  -- cr980 Create WRI Receiving Sticker
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ------------------------------------
  -- 1.0  29.08.13      yuval tal        initial Build
  -- 1.1  27.12.17      yuval tal        CHG0035037 - add Receipt Routing info
  -- 1.2  16/7/2019     yuval tal        CHG0046031 - add paramter quantity
  ---------------------------------------------------------------------------

  PROCEDURE print_rcv_pack_w(errbuf           OUT VARCHAR2,
                             retcode          OUT VARCHAR2,
                             p_stiker_name    IN VARCHAR2,
                             p_printer_name   IN VARCHAR2,
                             p_fm_receipt_num IN NUMBER,
                             p_to_receipt_num IN NUMBER,
                             p_org_id         IN NUMBER,
                             p_copies         IN NUMBER,
                             p_item           IN VARCHAR2,
                             p_location       IN VARCHAR2,
                             p_quantity       NUMBER) IS
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
    --  v_file_name_2 VARCHAR2(500) := p_stiker_name || '_' ||to_char(SYSDATE, 'RRMMDD_HH24MISS') ||'.dat';
    l_rout_desc VARCHAR2(500); -- CHG0035037
  BEGIN
  
    retcode := 0;
    BEGIN
      plist_file := utl_file.fopen(location  => p_location,
                                   filename  => v_file_name,
                                   open_mode => 'w');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(v_file_name) ||
                        ' Is open For Writing ');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_mode THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_operation THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' || ltrim(v_file_name) ||
                   SQLERRM || chr(0);
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 2 THEN
      utl_file.put_line(plist_file,
                        '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                        '.BTW /D=' || v_bartender_txt_location || ' /prn="' ||
                        p_printer_name || '" /R=3 /P /DD' || chr(13));
      utl_file.put_line(plist_file, '%END%' || chr(13));
    ELSE
      fnd_file.put_line(fnd_file.log, errbuf);
      RETURN;
    END IF;
  
    FOR crs IN (SELECT segment1,
                       description,
                       lot_num,
                       exp_date,
                       quantity,
                       receipt_num,
                       rev,
                       vendor_name,
                       vendor_number,
                       rcv_date_medium,
                       rcv_date_small --,
                --  routing_header_id
                  FROM (SELECT decode(msib.segment1,
                                      'REPAIR_OSP_ITEM',
                                      substr(rsl.item_description,
                                             instr(rsl.item_description,
                                                   ',',
                                                   1,
                                                   1) + 2,
                                             instr(rsl.item_description,
                                                   ',',
                                                   1,
                                                   2) - instr(rsl.item_description,
                                                              ',',
                                                              1,
                                                              1) - 2),
                                      msib.segment1) AS segment1,
                               nvl(rsl.item_description, msib.description) AS description,
                               rt.vendor_lot_num AS lot_num,
                               (SELECT to_char(mln.expiration_date,
                                               'DD/Mon/RR')
                                  FROM mtl_lot_numbers mln
                                 WHERE mln.lot_number = rlt.lot_num
                                   AND mln.organization_id =
                                       msib.organization_id
                                   AND mln.inventory_item_id =
                                       msib.inventory_item_id) AS exp_date,
                               1 AS quantity,
                               rsh.receipt_num,
                               nvl(TRIM(pol.item_revision) /*mtlt.revision*/, -- yuval 6.9.10
                                   xxinv_utils_pkg.get_revision4date(msib.inventory_item_id,
                                                                     91,
                                                                     nvl(pll.need_by_date,
                                                                         pll.promised_date))) rev,
                               apven.vendor_name AS vendor_name, --Hod
                               apven.vendor_number AS vendor_number,
                               to_char(rt.transaction_date, 'Month dd, RRRR') AS rcv_date_medium,
                               to_char(rt.transaction_date, 'dd/mm/RR') AS rcv_date_small,
                               rsl.routing_header_id -- CHG0035037
                          FROM rcv_transactions          rt,
                               mtl_system_items_b        msib,
                               po_line_locations_all     pll,
                               rcv_shipment_headers      rsh,
                               rcv_shipment_lines        rsl,
                               mtl_material_transactions mtlt,
                               ap_vendors_v              apven,
                               rcv_lot_transactions      rlt,
                               po_lines_all              pol
                         WHERE rt.po_line_location_id = pll.line_location_id
                           AND rt.po_line_id = pol.po_line_id
                              --  AND rt.transaction_type = 'DELIVER'
                           AND msib.inventory_item_id = rsl.item_id
                           AND rsl.shipment_header_id =
                               rsh.shipment_header_id
                           AND rt.shipment_line_id = rsl.shipment_line_id
                           AND msib.organization_id = p_org_id
                           AND rsh.shipment_header_id = rt.shipment_header_id
                           AND to_number(rsh.receipt_num) >= p_fm_receipt_num
                           AND to_number(rsh.receipt_num) <= p_to_receipt_num
                           AND rt.organization_id = p_org_id
                           AND mtlt.rcv_transaction_id(+) = rt.transaction_id
                           AND apven.vendor_id = rt.vendor_id
                           AND msib.segment1 = nvl(p_item, msib.segment1)
                           AND rlt.transaction_id(+) = rt.transaction_id) a
                 GROUP BY segment1,
                          description,
                          lot_num,
                          exp_date,
                          quantity,
                          receipt_num,
                          rev,
                          vendor_name,
                          vendor_number,
                          rcv_date_medium,
                          rcv_date_small
                 ORDER BY receipt_num ASC) LOOP
    
      -- l_rout_desc := xxobjt_general_utils_pkg.get_lookup_meaning('RCV_ROUTING_HEADERS',
      -- crs.routing_header_id); -- CHG0035037
      utl_file.put_line(plist_file,
                        'RC' || crs.receipt_num || chr(9) || crs.segment1 ||
                        chr(9) || crs.description || chr(9) || crs.lot_num ||
                        chr(9) || crs.exp_date || chr(9) || crs.rev ||
                        chr(9) || crs.vendor_name || chr(9) ||
                        crs.vendor_number || chr(9) || crs.rcv_date_medium ||
                        chr(9) || crs.rcv_date_small || chr(9) ||
                        p_quantity || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || p_copies || chr(13));
    END LOOP;
  
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  END print_rcv_pack_w;

  PROCEDURE print_rcv_pack(errbuf           OUT VARCHAR2,
                           retcode          OUT VARCHAR2,
                           p_stiker_name    IN VARCHAR2,
                           p_printer_name   IN VARCHAR2,
                           p_fm_receipt_num IN NUMBER,
                           p_to_receipt_num IN NUMBER,
                           p_org_id         IN NUMBER,
                           p_quantity       IN NUMBER,
                           p_item           IN VARCHAR2,
                           p_location       IN VARCHAR2) IS
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
    --  v_file_name_2 VARCHAR2(500) := p_stiker_name || '_' ||to_char(SYSDATE, 'RRMMDD_HH24MISS') ||'.dat';
  BEGIN
  
    IF nvl(retcode, 0) <> 1 THEN
      BEGIN
        plist_file := utl_file.fopen(location  => p_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid operation for ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
      END;
    END IF;
  
    IF nvl(retcode, 0) <> 2 THEN
      utl_file.put_line(plist_file,
                        '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                        '.BTW /D=' || v_bartender_txt_location || ' /prn="' ||
                        p_printer_name || '" /R=3 /P /DD' || chr(13));
      utl_file.put_line(plist_file, '%END%' || chr(13));
    END IF;
  
    FOR crs IN (SELECT segment1,
                       description,
                       lot_num,
                       exp_date,
                       quantity,
                       receipt_num,
                       rev,
                       vendor_name,
                       vendor_number,
                       rcv_date_medium,
                       rcv_date_small
                  FROM (SELECT decode(msib.segment1,
                                      'REPAIR_OSP_ITEM',
                                      substr(rsl.item_description,
                                             instr(rsl.item_description,
                                                   ',',
                                                   1,
                                                   1) + 2,
                                             instr(rsl.item_description,
                                                   ',',
                                                   1,
                                                   2) - instr(rsl.item_description,
                                                              ',',
                                                              1,
                                                              1) - 2),
                                      msib.segment1) AS segment1,
                               nvl(rsl.item_description, msib.description) AS description,
                               rlt.lot_num AS lot_num,
                               (SELECT to_char(mln.expiration_date,
                                               'DD/Mon/RR')
                                  FROM mtl_lot_numbers mln
                                 WHERE mln.lot_number = rlt.lot_num
                                   AND mln.organization_id =
                                       msib.organization_id
                                   AND mln.inventory_item_id =
                                       msib.inventory_item_id) AS exp_date,
                               1 AS quantity,
                               rsh.receipt_num,
                               nvl(TRIM(pol.item_revision) /*mtlt.revision*/, -- yuval 6.9.10
                                   xxinv_utils_pkg.get_revision4date(msib.inventory_item_id,
                                                                     91,
                                                                     nvl(pll.need_by_date,
                                                                         pll.promised_date))) rev,
                               apven.vendor_name AS vendor_name, --Hod
                               apven.vendor_number AS vendor_number,
                               to_char(rt.transaction_date, 'Month dd, RRRR') AS rcv_date_medium,
                               to_char(rt.transaction_date, 'dd/mm/RR') AS rcv_date_small
                          FROM rcv_transactions          rt,
                               mtl_system_items_b        msib,
                               po_line_locations_all     pll,
                               rcv_shipment_headers      rsh,
                               rcv_shipment_lines        rsl,
                               mtl_material_transactions mtlt,
                               ap_vendors_v              apven,
                               rcv_lot_transactions      rlt,
                               po_lines_all              pol
                         WHERE rt.po_line_location_id = pll.line_location_id
                           AND rt.po_line_id = pol.po_line_id
                           AND rt.transaction_type = 'DELIVER'
                           AND msib.inventory_item_id = rsl.item_id
                           AND rsl.shipment_header_id =
                               rsh.shipment_header_id
                           AND rt.shipment_line_id = rsl.shipment_line_id
                           AND msib.organization_id = p_org_id
                           AND rsh.shipment_header_id = rt.shipment_header_id
                           AND to_number(rsh.receipt_num) >= p_fm_receipt_num
                           AND to_number(rsh.receipt_num) <= p_to_receipt_num
                           AND rt.organization_id = p_org_id
                           AND mtlt.rcv_transaction_id(+) = rt.transaction_id
                           AND apven.vendor_id = rt.vendor_id
                           AND msib.segment1 = nvl(p_item, msib.segment1)
                           AND rlt.transaction_id(+) = rt.transaction_id) a
                 GROUP BY segment1,
                          description,
                          lot_num,
                          exp_date,
                          quantity,
                          receipt_num,
                          rev,
                          vendor_name,
                          vendor_number,
                          rcv_date_medium,
                          rcv_date_small
                 ORDER BY receipt_num ASC) LOOP
    
      utl_file.put_line(plist_file,
                        'RC' || crs.receipt_num || chr(9) || crs.segment1 ||
                        chr(9) || crs.description || chr(9) || crs.lot_num ||
                        chr(9) || crs.exp_date || chr(9) || crs.rev ||
                        chr(9) || crs.vendor_name || chr(9) ||
                        crs.vendor_number || chr(9) || crs.rcv_date_medium ||
                        chr(9) || crs.rcv_date_small || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || p_quantity ||
                        chr(13));
    END LOOP;
  
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  END print_rcv_pack;

  PROCEDURE print_whtrans_big_pack(errbuf         OUT VARCHAR2,
                                   retcode        OUT VARCHAR2,
                                   p_stiker_name  IN VARCHAR2,
                                   p_printer_name IN VARCHAR2,
                                   p_job_name     IN VARCHAR2,
                                   p_org_id       IN NUMBER,
                                   p_copies       IN NUMBER,
                                   p_location     IN VARCHAR2,
                                   p_qty          NUMBER) IS
  
    v_segment1       mtl_system_items_b.segment1%TYPE;
    v_description    mtl_system_items_b.description%TYPE;
    v_revision       mtl_item_revisions_b.revision%TYPE;
    v_start_quantity wip_discrete_jobs.start_quantity%TYPE;
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
    -- v_file_name_2 VARCHAR2(500) := p_stiker_name || '_' ||to_char(SYSDATE, 'RRMMDD_HH24MISS') ||'.dat';
  BEGIN
  
    BEGIN
      SELECT msib.segment1,
             msib.description,
             wdj.bom_revision,
             wdj.start_quantity
        INTO v_segment1, v_description, v_revision, v_start_quantity
        FROM wip_discrete_jobs  wdj,
             wip_entities       we,
             mtl_system_items_b msib /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               WHERE wdj.wip_entity_id = we.wip_entity_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 AND we.wip_entity_name = p_job_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 AND we.primary_item_id = msib.inventory_item_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 AND msib.organization_id = wdj.organization_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 AND wdj.organization_id = we.organization_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 AND wdj.organization_id = p_org_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              /*AND msib.inventory_item_id = msibr.inventory_item_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              AND msibr.organization_id = wdj.organization_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              AND msibr.effectivity_date =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  (SELECT MAX(msibrv.effectivity_date)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     FROM mtl_item_revisions_b msibrv
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    WHERE msibrv.inventory_item_id = msib.inventory_item_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      AND msibrv.organization_id = msibr.organization_id)*/
      ;
    
    EXCEPTION
      WHEN no_data_found THEN
        retcode := '1';
        errbuf  := errbuf || 'No Data Found ' || chr(0);
      WHEN too_many_rows THEN
        retcode := '1';
        errbuf  := errbuf || 'Too Many Rows Returnd ' || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 1 THEN
    
      BEGIN
        plist_file := utl_file.fopen(location  => p_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid operation for ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
      END;
    
      IF nvl(retcode, 0) <> 2 THEN
        utl_file.put_line(plist_file,
                          '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                          '.BTW /D=' || v_bartender_txt_location ||
                          ' /prn="' || p_printer_name || '" /R=3 /P /DD' ||
                          chr(13));
        utl_file.put_line(plist_file, '%END%' || chr(13));
        utl_file.put_line(plist_file,
                          v_segment1 || chr(9) || v_description || chr(9) ||
                          v_revision || chr(9) || nvl(p_qty, 1) || chr(9) ||
                          chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                          chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                          chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                          chr(9) || p_copies || chr(13));
      END IF;
    END IF;
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  END print_whtrans_big_pack;

  PROCEDURE print_whtrans_components(errbuf         OUT VARCHAR2,
                                     retcode        OUT VARCHAR2,
                                     p_stiker_name  IN VARCHAR2,
                                     p_printer_name IN VARCHAR2,
                                     p_job_name     IN VARCHAR2,
                                     p_org_id       IN NUMBER,
                                     p_quantity     IN NUMBER,
                                     p_location     IN VARCHAR2) IS
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
    -- v_file_name_2 VARCHAR2(500) := p_stiker_name || '_' ||to_char(SYSDATE, 'RRMMDD_HH24MISS') ||'.dat';
  BEGIN
  
    IF nvl(retcode, 0) <> 1 THEN
      BEGIN
        plist_file := utl_file.fopen(location  => p_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid operation for ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
      END;
    END IF;
  
    IF nvl(retcode, 0) <> 2 THEN
      utl_file.put_line(plist_file,
                        '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                        '.BTW /D=' || v_bartender_txt_location || ' /prn="' ||
                        p_printer_name || '" /R=3 /P /DD' || chr(13));
      utl_file.put_line(plist_file, '%END%' || chr(13));
    END IF;
  
    FOR crs IN (SELECT msib.segment1             AS segment1,
                       msib.description          AS description,
                       msibr.revision            AS revision,
                       wro.quantity_per_assembly AS quantity
                  FROM wip_entities               we,
                       wip_discrete_jobs          wdj,
                       wip_requirement_operations wro,
                       mtl_system_items_b         msib,
                       mtl_item_revisions_b       msibr,
                       fnd_lookup_values          flv
                 WHERE we.wip_entity_id = wdj.wip_entity_id
                   AND we.wip_entity_name = p_job_name --'RES00005' --
                   AND wdj.organization_id = p_org_id -- 85 --
                   AND we.organization_id = wdj.organization_id
                   AND msib.organization_id = wro.organization_id
                   AND wro.wip_entity_id = wdj.wip_entity_id
                   AND msib.inventory_item_id = wro.inventory_item_id
                   AND wro.wip_supply_type = flv.lookup_code
                   AND msib.organization_id = wdj.organization_id
                   AND flv.meaning = 'Push'
                   AND flv.lookup_type = 'WIP_SUPPLY'
                   AND msibr.inventory_item_id = msib.inventory_item_id
                   AND msibr.organization_id = msib.organization_id
                   AND flv.language = 'US'
                   AND msibr.effectivity_date =
                       (SELECT MAX(msibrv.effectivity_date)
                          FROM mtl_item_revisions_b msibrv
                         WHERE msibrv.inventory_item_id =
                               msib.inventory_item_id
                           AND msibrv.organization_id = msibr.organization_id)) LOOP
    
      utl_file.put_line(plist_file,
                        crs.segment1 || chr(9) || crs.description || chr(9) ||
                        crs.revision || chr(9) || crs.quantity || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || p_quantity || chr(13));
    END LOOP;
  
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  END print_whtrans_components;

  PROCEDURE print_prodcompissue(errbuf         OUT VARCHAR2,
                                retcode        OUT VARCHAR2,
                                p_stiker_name  IN VARCHAR2,
                                p_printer_name IN VARCHAR2,
                                p_job_name     IN VARCHAR2,
                                p_org_id       IN NUMBER,
                                p_quantity     IN NUMBER,
                                p_location     IN VARCHAR2) IS
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
    --   v_file_name_2 VARCHAR2(500) := p_stiker_name || '_' ||to_char(SYSDATE, 'RRMMDD_HH24MISS') ||'.dat';
  BEGIN
  
    IF nvl(retcode, 0) <> 1 THEN
      BEGIN
        plist_file := utl_file.fopen(location  => p_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid operation for ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
      END;
    END IF;
  
    IF nvl(retcode, 0) <> 2 THEN
      utl_file.put_line(plist_file,
                        '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                        '.BTW /D=' || v_bartender_txt_location || ' /prn="' ||
                        p_printer_name || '" /R=3 /P /DD' || chr(13));
      utl_file.put_line(plist_file, '%END%' || chr(13));
    END IF;
  
    FOR crs IN (SELECT we.wip_entity_name    AS wip_entity_name,
                       msib.segment1         AS component,
                       msib2.segment1        AS assembly,
                       msib.description      AS description,
                       msibr.revision        AS revision,
                       wro.required_quantity AS quantity,
                       mil.segment2          AS slocator
                  FROM wip_entities               we,
                       wip_discrete_jobs          wdj,
                       wip_requirement_operations wro,
                       mtl_system_items_b         msib,
                       mtl_item_revisions_b       msibr,
                       fnd_lookup_values          flv,
                       mtl_system_items_b         msib2,
                       mtl_item_locations         mil
                 WHERE we.wip_entity_id = wdj.wip_entity_id
                   AND we.wip_entity_name = p_job_name --'RES00005' -- :p_job_name
                   AND wdj.organization_id = p_org_id --85 --:p_org_id
                   AND we.organization_id = wdj.organization_id
                   AND msib.organization_id = wro.organization_id
                   AND wro.wip_entity_id = wdj.wip_entity_id
                   AND msib.inventory_item_id = wro.inventory_item_id
                   AND wro.wip_supply_type = flv.lookup_code
                   AND msib.organization_id = wdj.organization_id
                   AND flv.meaning = 'Push'
                   AND flv.lookup_type = 'WIP_SUPPLY'
                   AND msibr.inventory_item_id = msib.inventory_item_id
                   AND msibr.organization_id = msib.organization_id
                   AND msibr.effectivity_date =
                       (SELECT MAX(msibrv.effectivity_date)
                          FROM mtl_item_revisions_b msibrv
                         WHERE msibrv.inventory_item_id =
                               msib.inventory_item_id
                           AND msibrv.organization_id = msibr.organization_id)
                   AND msib2.inventory_item_id = we.primary_item_id
                   AND msib2.organization_id = wdj.organization_id
                   AND wro.supply_locator_id = mil.inventory_location_id(+)
                   AND wro.organization_id = mil.organization_id(+)) LOOP
    
      utl_file.put_line(plist_file,
                        crs.wip_entity_name || chr(9) || crs.component ||
                        chr(9) || crs.assembly || chr(9) || crs.description ||
                        chr(9) || crs.quantity || chr(9) || crs.slocator ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        p_quantity || chr(13));
    END LOOP;
  
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  END print_prodcompissue;

  --------------------------------------------------------------------
  --  name:            print_dft
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXXX XXXXXx            initial build
  --  1.1  29/05/2014  Dalit A. Raviv    CHG0032329 - Adjust XX: Print Kanban Label Sticker program
  --                                     to support printing multi labels
  --                                     add parameter p_kanban_num_to
  -- 1.2  22/07/2014   yuval tal         CHG0032790 MTKG - Print Full Locator on Kanban Card
  --------------------------------------------------------------------
  PROCEDURE print_dft(errbuf          OUT VARCHAR2,
                      retcode         OUT VARCHAR2,
                      p_stiker_name   IN VARCHAR2,
                      p_printer_name  IN VARCHAR2,
                      p_is_full       IN VARCHAR2,
                      p_org_id        IN NUMBER,
                      p_kanban_number IN VARCHAR2,
                      p_kanban_num_to IN VARCHAR2,
                      p_quantity      IN NUMBER,
                      p_location      IN VARCHAR2) IS
  
    --v_kanban_card_number mtl_kanban_cards.kanban_card_number%TYPE;
    --v_segment1           mtl_system_items_b.segment1%TYPE;
    --v_description        mtl_system_items_b.description%TYPE;
    --v_mil_segment        mtl_item_locations.segment2%TYPE;
    --v_kanban_size        mtl_kanban_cards.kanban_size%TYPE;
    --v_full               VARCHAR2(10);
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
    -- 1.1 Dalit A. RAviv 29/05/2014
    CURSOR pop_c IS
      SELECT mkc.kanban_card_number,
             msib.segment1,
             msib.description,
             milk.concatenated_segments /*mil.segment2*/ mil_segment, --CHG0032790 change to concatenated seg
             mkc.kanban_size,
             decode(nvl(p_is_full, 'N'),
                    'Y',
                    'F',
                    substr(mkc.kanban_card_number,
                           instr(mkc.kanban_card_number, 'E'),
                           2)) k_full
        FROM mtl_kanban_cards       mkc,
             mtl_item_locations     mil,
             mtl_item_locations_kfv milk,
             mtl_system_items_b     msib
       WHERE milk.row_id = mil.rowid
         AND milk.inventory_location_id = mil.inventory_location_id
         AND mil.inventory_location_id = mkc.locator_id
         AND msib.inventory_item_id = mkc.inventory_item_id
         AND msib.organization_id = mkc.organization_id
         AND mil.organization_id = mkc.organization_id
         AND mkc.organization_id = p_org_id
         AND mkc.kanban_card_number BETWEEN p_kanban_number AND
             p_kanban_num_to
       ORDER BY msib.segment1;
  
  BEGIN
    -- 1.1 Dalit A. RAviv 29/05/2014
    /*BEGIN
      SELECT mkc.kanban_card_number,
             msib.segment1,
             msib.description,
             mil.segment2,
             mkc.kanban_size,
             decode(nvl(p_is_full, 'N'),
                    'Y',
                    'F',
                    substr(mkc.kanban_card_number,
                           instr(mkc.kanban_card_number, 'E'),
                           2))
        INTO v_kanban_card_number,
             v_segment1,
             v_description,
             v_mil_segment,
             v_kanban_size,
             v_full
        FROM mtl_kanban_cards   mkc,
             mtl_item_locations mil,
             mtl_system_items_b msib
       WHERE mil.inventory_location_id = mkc.locator_id
         AND msib.inventory_item_id = mkc.inventory_item_id
         AND msib.organization_id = mkc.organization_id
         AND mil.organization_id = mkc.organization_id
         AND mkc.organization_id = p_org_id
         AND mkc.kanban_card_number = p_kanban_number;
    
    EXCEPTION
      WHEN no_data_found THEN
        retcode := '1';
        errbuf  := errbuf || 'No Data Found ' || chr(0);
      WHEN too_many_rows THEN
        retcode := '1';
        errbuf  := errbuf || 'Too Many Rows Returnd ' || chr(0);
    END;*/
  
    IF nvl(retcode, 0) <> 1 THEN
    
      BEGIN
        plist_file := utl_file.fopen(location  => p_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid operation for ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
      END;
      -- 1.1 Dalit A. RAviv 29/05/2014
      -- add loop
      IF nvl(retcode, 0) <> 2 THEN
        utl_file.put_line(plist_file,
                          '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                          '.BTW /D=' || v_bartender_txt_location ||
                          ' /prn="' || p_printer_name || '" /R=3 /P /DD' ||
                          chr(13));
        utl_file.put_line(plist_file, '%END%' || chr(13));
      
        FOR pop_r IN pop_c LOOP
          utl_file.put_line(plist_file,
                            pop_r.kanban_card_number || chr(9) ||
                            pop_r.segment1 || chr(9) || pop_r.description ||
                            chr(9) || pop_r.mil_segment || chr(9) ||
                            pop_r.kanban_size || chr(9) || pop_r.k_full ||
                            chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                            chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                            chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                            p_quantity || chr(13));
        END LOOP;
      END IF;
    END IF;
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  END print_dft;

  --------------------------------------------------------------------
  --  name:            print_dft_med
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/03/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034195 - Same as print_dft but
  --                   want to have medium label, and suplier info.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/03/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE print_dft_med(errbuf          OUT VARCHAR2,
                          retcode         OUT VARCHAR2,
                          p_stiker_name   IN VARCHAR2,
                          p_printer_name  IN VARCHAR2,
                          p_is_full       IN VARCHAR2,
                          p_org_id        IN NUMBER,
                          p_kanban_number IN VARCHAR2,
                          p_kanban_num_to IN VARCHAR2,
                          p_quantity      IN NUMBER,
                          p_location      IN VARCHAR2) IS
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.tmp';
  
    CURSOR pop_c IS
      SELECT mkc.kanban_card_number,
             msib.segment1,
             msib.description,
             milk.concatenated_segments mil_segment,
             mkc.kanban_size,
             decode(nvl(p_is_full, 'N'),
                    'Y',
                    'F',
                    substr(mkc.kanban_card_number,
                           instr(mkc.kanban_card_number, 'E'),
                           2)) k_full,
             REPLACE(mkp1.supplier_name, ',', ' ') supplier_name
        FROM mtl_kanban_cards            mkc,
             mtl_item_locations          mil,
             mtl_item_locations_kfv      milk,
             mtl_system_items_b          msib,
             mtl_kanban_pull_sequences_v mkp1
       WHERE milk.row_id = mil.rowid
         AND milk.inventory_location_id = mil.inventory_location_id
         AND mil.inventory_location_id = mkc.locator_id
         AND msib.inventory_item_id = mkc.inventory_item_id
         AND msib.organization_id = mkc.organization_id
         AND mil.organization_id = mkc.organization_id
         AND mkc.pull_sequence_id = mkp1.pull_sequence_id
         AND mkc.organization_id = mkp1.organization_id
         AND mkc.inventory_item_id = mkp1.inventory_item_id
         AND mkc.organization_id = p_org_id
         AND mkc.kanban_card_number BETWEEN p_kanban_number AND
             p_kanban_num_to
       ORDER BY msib.segment1;
  
  BEGIN
    IF nvl(retcode, 0) <> 1 THEN
    
      BEGIN
        plist_file := utl_file.fopen(location  => p_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid operation for ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
      END;
    
      IF nvl(retcode, 0) <> 2 THEN
        utl_file.put_line(plist_file,
                          '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                          '.BTW /D=' || v_bartender_txt_location ||
                          ' /prn="' || p_printer_name || '" /R=3 /P /DD' ||
                          chr(13));
        utl_file.put_line(plist_file, '%END%' || chr(13));
      
        FOR pop_r IN pop_c LOOP
          utl_file.put_line(plist_file,
                            pop_r.kanban_card_number || chr(9) ||
                            pop_r.segment1 || chr(9) || pop_r.description ||
                            chr(9) || pop_r.mil_segment || chr(9) ||
                            pop_r.kanban_size || chr(9) || pop_r.k_full ||
                            chr(9) || pop_r.supplier_name || chr(9) ||
                            chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                            chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                            chr(9) || chr(9) || chr(9) || p_quantity ||
                            chr(13));
        END LOOP;
      END IF;
    END IF;
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    
      utl_file.frename(p_location,
                       v_file_name,
                       p_location,
                       REPLACE(v_file_name, '.tmp', '.txt'),
                       TRUE);
    END IF;
  
  END print_dft_med;

  PROCEDURE print_parts(errbuf         OUT VARCHAR2,
                        retcode        OUT VARCHAR2,
                        p_stiker_name  IN VARCHAR2,
                        p_printer_name IN VARCHAR2,
                        p_segment      IN VARCHAR2,
                        p_org_id       IN NUMBER,
                        p_quantity     IN NUMBER,
                        p_location     IN VARCHAR2) IS
  
    v_segment1    mtl_system_items_b.segment1%TYPE;
    v_description mtl_system_items_b.description%TYPE;
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
    -- v_file_name_2 VARCHAR2(500) := p_stiker_name || '_' ||to_char(SYSDATE, 'RRMMDD_HH24MISS') ||'.dat';
  BEGIN
  
    BEGIN
      SELECT msib.segment1, msib.description
        INTO v_segment1, v_description
        FROM mtl_system_items_b msib
       WHERE msib.organization_id = p_org_id
         AND msib.segment1 = p_segment;
    
    EXCEPTION
      WHEN no_data_found THEN
        retcode := '1';
        errbuf  := errbuf || 'No Data Found ' || chr(0);
      WHEN too_many_rows THEN
        retcode := '1';
        errbuf  := errbuf || 'Too Many Rows Returnd ' || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 1 THEN
    
      BEGIN
        plist_file := utl_file.fopen(location  => p_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid operation for ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
      END;
    
      IF nvl(retcode, 0) <> 2 THEN
        utl_file.put_line(plist_file,
                          '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                          '.BTW /D=' || v_bartender_txt_location ||
                          ' /prn="' || p_printer_name || '" /R=3 /P /DD' ||
                          chr(13));
        utl_file.put_line(plist_file, '%END%' || chr(13));
        utl_file.put_line(plist_file,
                          v_segment1 || chr(9) || v_description || chr(9) ||
                          chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                          chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                          chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                          chr(9) || chr(9) || chr(9) || p_quantity ||
                          chr(13));
      END IF;
    END IF;
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  END print_parts;

  PROCEDURE print_transaction(errbuf             OUT VARCHAR2,
                              retcode            OUT VARCHAR2,
                              p_stiker_name      IN VARCHAR2,
                              p_printer_name     IN VARCHAR2,
                              p_item             IN VARCHAR2,
                              p_item_revision_id NUMBER,
                              p_transqty         IN NUMBER,
                              p_org_id           IN NUMBER,
                              p_quantity         IN NUMBER,
                              p_location         IN VARCHAR2) IS
  
    v_segment1    mtl_system_items_b.segment1%TYPE;
    v_description mtl_system_items_b.description%TYPE;
    v_revision    mtl_item_revisions_b.revision%TYPE;
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
    -- v_file_name_2 VARCHAR2(500) := p_stiker_name || '_' ||to_char(SYSDATE, 'RRMMDD_HH24MISS') ||'.dat';
  
  BEGIN
  
    message('p_stiker_name => ' || p_stiker_name || ',' || chr(10) ||
            'p_printer_name => ' || p_printer_name || ',' || chr(10) ||
            'p_item => ' || p_item || ',' || chr(10) ||
            'p_item_revision_id => ' || p_item_revision_id || ',' ||
            chr(10) || 'p_transqty => ' || p_transqty || ',' || chr(10) ||
            'p_org_id   => ' || p_org_id || ',' || chr(10) ||
            'p_quantity => ' || p_quantity || ',' || chr(10) ||
            'p_location => ' || p_location);
    BEGIN
      SELECT msib.segment1, msib.description, mrib.revision
        INTO v_segment1, v_description, v_revision
        FROM mtl_system_items_b msib, mtl_item_revisions_b mrib
       WHERE msib.inventory_item_id = mrib.inventory_item_id
         AND msib.organization_id = mrib.organization_id
         AND msib.organization_id = p_org_id
         AND msib.segment1 = p_item
         AND mrib.effectivity_date =
             (SELECT MAX(msibrv.effectivity_date)
                FROM mtl_item_revisions_b msibrv
               WHERE msibrv.inventory_item_id = msib.inventory_item_id
                 AND msibrv.organization_id = msib.organization_id);
    
      -----
      IF p_item_revision_id IS NOT NULL THEN
      
        SELECT mir.revision
          INTO v_revision
          FROM mtl_item_revisions_vl mir, mtl_system_items_b mtl
         WHERE mtl.segment1 = p_item
           AND mir.revision_id = p_item_revision_id -- MCP-04001
           AND mir.organization_id = 91
           AND mir.organization_id = mtl.organization_id
           AND mir.inventory_item_id = mtl.inventory_item_id;
      
      END IF;
    
    EXCEPTION
      WHEN no_data_found THEN
        retcode := '1';
        errbuf  := errbuf || 'No Data Found ' || chr(0);
      WHEN too_many_rows THEN
        retcode := '1';
        errbuf  := errbuf || 'Too Many Rows Returnd ' || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 1 THEN
    
      BEGIN
        plist_file := utl_file.fopen(location  => p_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid operation for ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
      END;
    
      IF nvl(retcode, 0) <> 2 THEN
        utl_file.put_line(plist_file,
                          '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                          '.BTW /D=' || v_bartender_txt_location ||
                          ' /prn="' || p_printer_name || '" /R=3 /P /DD' ||
                          chr(13));
        utl_file.put_line(plist_file, '%END%' || chr(13));
        utl_file.put_line(plist_file,
                          v_segment1 || chr(9) || v_description || chr(9) ||
                          v_revision || chr(9) || p_transqty || chr(9) ||
                          chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                          chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                          chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                          chr(9) || p_quantity || chr(13));
      END IF;
    END IF;
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  END print_transaction;

  PROCEDURE print_head_serial_pack(errbuf         OUT VARCHAR2,
                                   retcode        OUT VARCHAR2,
                                   p_stiker_name  IN VARCHAR2,
                                   p_printer_name IN VARCHAR2,
                                   p_item         IN VARCHAR2,
                                   p_serial       IN VARCHAR2,
                                   p_location     IN VARCHAR2) IS
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
    -- v_file_name_2 VARCHAR2(500) := p_stiker_name || '_' ||to_char(SYSDATE, 'RRMMDD_HH24MISS') ||'.dat';
  BEGIN
  
    BEGIN
      plist_file := utl_file.fopen(location  => p_location,
                                   filename  => v_file_name,
                                   open_mode => 'w');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(v_file_name) ||
                        ' Is open For Writing ');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_mode THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_operation THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' || ltrim(v_file_name) ||
                   SQLERRM || chr(0);
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 2 THEN
      utl_file.put_line(plist_file,
                        '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                        '.BTW /D=' || v_bartender_txt_location || ' /prn="' ||
                        p_printer_name || '" /R=3 /P /DD' || chr(13));
      utl_file.put_line(plist_file, '%END%' || chr(13));
      utl_file.put_line(plist_file,
                        p_serial || chr(9) || p_item || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || 1 || chr(13));
    END IF;
  
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  END print_head_serial_pack;

  PROCEDURE print_head_serial_file(errbuf         OUT VARCHAR2,
                                   retcode        OUT VARCHAR2,
                                   p_printer_name IN VARCHAR2,
                                   p_item         IN VARCHAR2,
                                   p_location     IN VARCHAR2,
                                   p_file_name    IN VARCHAR2) IS
  
    plist_file_read  utl_file.file_type;
    plist_file_write utl_file.file_type;
    v_serial         VARCHAR2(1000);
    v_read_code      NUMBER(5) := 1;
    v_line_buf       VARCHAR2(2000);
    v_place          NUMBER(3);
    v_delimiter      CHAR(1) := ',';
    v_counter        NUMBER(5) := 0;
    v_file_name      VARCHAR2(500) := 'Head_Serial_' ||
                                      to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                      '.txt';
    v_temp           NUMBER := 0;
  BEGIN
    BEGIN
      plist_file_read := utl_file.fopen(location  => p_location,
                                        filename  => p_file_name,
                                        open_mode => 'r');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(p_file_name) ||
                        ' Is open For Reading ');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' || ltrim(p_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_mode THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' || ltrim(p_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_operation THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' || ltrim(p_file_name) ||
                   SQLERRM || chr(0);
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := errbuf || 'Other for ' || ltrim(p_file_name) || chr(0);
    END;
    -- Loop For All File's Lines
    WHILE v_read_code <> 0 AND nvl(retcode, 1) = 1 LOOP
      BEGIN
        utl_file.get_line(file => plist_file_read, buffer => v_line_buf);
      EXCEPTION
        WHEN utl_file.read_error THEN
          retcode := '2';
          errbuf  := 'Read Error' || chr(0);
        WHEN no_data_found THEN
          errbuf      := 'Read Complete' || chr(0);
          v_read_code := 0;
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := 'Other for Line Read' || SQLERRM || chr(0);
      END;
    
      IF v_read_code <> 0 AND v_counter = 0 THEN
        BEGIN
          plist_file_write := utl_file.fopen(location  => fnd_profile.value('XXBARTENDERFILES'), --'/UtlFiles/BarTender',
                                             filename  => v_file_name,
                                             open_mode => 'w');
          fnd_file.put_line(fnd_file.log,
                            'File ' || ltrim(v_file_name) ||
                            ' Is open For Writing ');
        EXCEPTION
          WHEN utl_file.invalid_path THEN
            retcode := '2';
            errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                       chr(0);
          WHEN utl_file.invalid_mode THEN
            retcode := '2';
            errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                       chr(0);
          WHEN utl_file.invalid_operation THEN
            retcode := '2';
            errbuf  := errbuf || 'Invalid operation for ' ||
                       ltrim(v_file_name) || SQLERRM || chr(0);
          WHEN OTHERS THEN
            retcode := '2';
            errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) ||
                       chr(0);
        END;
      
        IF nvl(retcode, 0) <> 2 THEN
          utl_file.put_line(plist_file_write,
                            '%BTW% /AF=C:\OA_Bar_Tender\Head_Serial.BTW /D=' ||
                            v_bartender_txt_location || ' /prn="' ||
                            p_printer_name || '" /R=3 /P /DD' || chr(13));
          utl_file.put_line(plist_file_write, '%END%' || chr(13));
        END IF;
      
      END IF;
    
      IF v_read_code <> 0 AND nvl(retcode, 1) = 1 THEN
        v_counter := v_counter + 1;
        v_place   := instr(v_line_buf, v_delimiter);
        v_temp    := instr(v_line_buf, chr(13));
        -- Check The Delimiter
        IF nvl(v_place, 0) = 0 THEN
          v_serial := REPLACE(ltrim(rtrim(v_line_buf)), chr(13), '');
          utl_file.put_line(plist_file_write,
                            v_serial || chr(9) || p_item || chr(9) ||
                            chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                            chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                            chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                            chr(9) || chr(9) || chr(9) || 1 || chr(13));
        ELSE
          v_serial := REPLACE(ltrim(rtrim(substr(v_line_buf, 1, v_place - 1))),
                              chr(13),
                              '');
          utl_file.put_line(plist_file_write,
                            v_serial || chr(9) || p_item || chr(9) ||
                            chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                            chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                            chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                            chr(9) || chr(9) || chr(9) || 1 || chr(13));
        
        END IF;
      END IF;
    END LOOP;
  
    IF utl_file.is_open(plist_file_write) THEN
      utl_file.fclose(plist_file_write);
    END IF;
    IF utl_file.is_open(plist_file_read) THEN
      utl_file.fclose(plist_file_read);
    END IF;
  
  END print_head_serial_file;
  -----------------------------------------------------------------------------------------
  -- Ver     When        Who           Description
  -- ------  ----------  ------------  ------------------------------------------------------
  -- 1.0     25/02/2019  Roman W.      CHG0045071
  --                                      File location     : fnd_profile.value('XXBARTENDERFILES')
  --                                      Concurrent        : XX: Print Bottling lot job sticker(MTL-OBJ) / XXWIPBLSTCKMTL
  --                                      Template Location :
  -- 1.1     31/03/2019  Roman W.      CHG0045071 change date format
  -- 1.2     01/05/2019  Roman W.      CHG0045071 change date format (field 7)
  -- 1.3     30/10/2019  Bellona(TCS)  CHG0046734 spilt p_bot_lot input into lot number and item id.
  -----------------------------------------------------------------------------------------
  PROCEDURE print_resin_pack_new(errbuf         OUT VARCHAR2,
                                 retcode        OUT VARCHAR2,
                                 p_stiker_name  IN VARCHAR2, -- Resin_Pack_Kg
                                 p_printer_name IN VARCHAR2,
                                 p_bot_lot      IN VARCHAR2,
                                 p_org_id       IN NUMBER,
                                 p_quantity     IN NUMBER,
                                 p_location     IN VARCHAR2, -- fnd_profile.value('XXBARTENDERFILES')
                                 p_pack_qty     IN NUMBER -- CHG0045071
                                 ) IS
  
    v_comp_lot        mtl_lot_numbers.lot_number%TYPE;
    v_expiration_date mtl_lot_numbers.expiration_date%TYPE;
    v_segment1        mtl_system_items_b.segment1%TYPE;
    v_start_quantity  wip_discrete_jobs.start_quantity%TYPE;
    v_description     mtl_system_items_b.description%TYPE;
    plist_file        utl_file.file_type;
    v_file_name       VARCHAR2(500) := p_stiker_name || '_' ||
                                       to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                       '.txt';
    v_pack_qty        VARCHAR2(300);
  
    l_stiker_name VARCHAR2(300); -- CHG0045071
    l_is_prod     VARCHAR2(300) := xxobjt_general_utils_pkg.am_i_in_production; -- CHG0044871 Y/N
    l_location    VARCHAR2(300);
    l_lot         mtl_lot_numbers.lot_number%TYPE; --CHG0046734
    l_item_id     mtl_lot_numbers.inventory_item_id%TYPE; --CHG0046734
  BEGIN
    message('Concurrent     : XX: Print Bottling lot job sticker(MTL-OBJ) / XXWIPBLSTCKMTL');
    message('Package        : xxinv_bartender_pkg.print_resin_pack_new');
    message('p_stiker_name  : ' || p_stiker_name);
    message('p_printer_name : ' || p_printer_name);
    message('p_bot_lot      : ' || p_bot_lot);
    message('p_org_id       : ' || p_org_id);
    message('p_quantity     : ' || p_quantity);
    message('p_location     : ' || p_location);
    message('p_pack_qty     : ' || p_pack_qty);
    message('l_is_prod      :' || l_is_prod);
  
    --CHG0046734 splitting p_bot_lot input parameter into lot number and item id
    l_lot     := substr(p_bot_lot, 0, instr(p_bot_lot, '|') - 1);
    l_item_id := substr(p_bot_lot,
                        instr(p_bot_lot, '|') + 1,
                        length(p_bot_lot));
    message('l_lot          :' || l_lot);
    message('l_item_id      :' || l_item_id);
  
    IF 'Y' = l_is_prod THEN
      l_stiker_name := p_stiker_name;
      l_location    := p_location;
    ELSE
      l_stiker_name := 'DEV_' || p_stiker_name;
      l_location    := get_dev_dorectory;
    END IF;
    message('(New)l_stiker_name  : ' || l_stiker_name);
    message('(New)l_location     : ' || l_location);
  
    v_file_name := l_stiker_name || '_' ||
                   to_char(SYSDATE, 'RRMMDD_HH24MISS') || '.txt';
  
    -- extract the MTL number from the bottling lot parameter
    /*SELECT 'MTL' || substr(p_bot_lot, 0, instr(p_bot_lot, '-') - 1)
    INTO   v_comp_lot
    FROM   dual;*/
    --CHG0046734 commented above expression, replaced p_bot_lot with l_lot
    v_comp_lot := 'MTL' || substr(l_lot, 0, instr(l_lot, '-') - 1);
    message('v_comp_lot: ' || v_comp_lot);
  
    BEGIN
      -- get expiration date for mtl
      SELECT mln.expiration_date
        INTO v_expiration_date
        FROM mtl_lot_numbers mln
       WHERE mln.organization_id = p_org_id
         AND mln.lot_number = v_comp_lot --CHG0046734;
         AND mln.disable_flag IS NULL; --CHG0046734;
    
      SELECT msib.segment1, msib.description
        INTO v_segment1, v_description
        FROM mtl_lot_numbers mln, mtl_system_items_b msib
       WHERE mln.organization_id = msib.organization_id
         AND mln.inventory_item_id = msib.inventory_item_id
         AND mln.lot_number = l_lot /*p_bot_lot*/ --CHG0046734 replaced p_bot_lot with l_lot
         AND mln.inventory_item_id = l_item_id --CHG0046734
         AND mln.organization_id = p_org_id
         AND mln.disable_flag IS NULL; -- for INC0101330 - Issue in Label Printing
    
    EXCEPTION
      WHEN no_data_found THEN
        retcode := '1';
        errbuf  := errbuf || 'No Data Found ' || chr(0);
      WHEN too_many_rows THEN
        retcode := '1';
        errbuf  := errbuf || 'Too Many Rows Returnd ' || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 1 THEN
    
      BEGIN
        message('v_file_name :' || v_file_name);
      
        plist_file := utl_file.fopen(location  => l_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid operation for ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
      END;
    
      IF nvl(retcode, 0) <> 2 THEN
      
        v_pack_qty := 'QT-' || p_pack_qty;
      
        message('---------------------------------');
        message('%BTW% /AF=C:\OA_Bar_Tender\' || l_stiker_name ||
                '.BTW /D=' || v_bartender_txt_location || ' /prn="' ||
                p_printer_name || '" /R=3 /P /DD' || chr(13));
        message('%END%' || chr(13));
        message(l_lot /*p_bot_lot*/
                || chr(9) -- field 1        --CHG0046734 replaced p_bot_lot with l_lot
                || '' || chr(9) -- field 2
                || to_char(v_expiration_date, 'dd-Mon-yyyy') || chr(9) -- field 3
                || v_segment1 || chr(9) -- field 4
                || v_start_quantity || chr(9) -- field 5
                || v_description || chr(9) -- field 6
                -- || to_char(v_expiration_date, 'ddmmyyyy') || chr(9) -- field 7
                || to_char(v_expiration_date, 'dd-Mon-yyyy') || chr(9) -- field 7
                || chr(9) -- field 8
                || chr(9) -- field 9
                || chr(9) -- field 10
                || chr(9) -- field 11
                || chr(9) -- field 12
                || chr(9) -- field 13
                || chr(9) -- field 14
                || chr(9) -- field 15
                || chr(9) -- field 16
                || chr(9) -- field 17
                || chr(9) -- field 18
                || chr(9) -- field 19
                --|| chr(9) -- field 20 -- rem By Roman W. 26/02/2019 CHG0045071
                || v_pack_qty || chr(9) -- field 20 addede by Roman W. 26/02/2019 CHG0045071
                || p_quantity -- field 21
                || chr(13));
        message('---------------------------------');
        utl_file.put_line(plist_file,
                          '%BTW% /AF=C:\OA_Bar_Tender\' || l_stiker_name ||
                          '.BTW /D=' || v_bartender_txt_location ||
                          ' /prn="' || p_printer_name || '" /R=3 /P /DD' ||
                          chr(13));
      
        utl_file.put_line(plist_file, '%END%' || chr(13));
        utl_file.put_line(plist_file,
                          l_lot /*p_bot_lot*/
                           || chr(9) -- field 1
                           || '' || chr(9) -- field 2
                           || to_char(v_expiration_date, 'dd-Mon-yyyy') ||
                           chr(9) -- field 3
                           || v_segment1 || chr(9) -- field 4
                           || v_start_quantity || chr(9) -- field 5
                           || v_description || chr(9) -- field 6
                          -- || to_char(v_expiration_date, 'ddmmyyyy') || chr(9) -- field 7
                           || to_char(v_expiration_date, 'dd-Mon-yyyy') ||
                           chr(9) -- field 7
                           || chr(9) -- field 8
                           || chr(9) -- field 9
                           || chr(9) -- field 10
                           || chr(9) -- field 11
                           || chr(9) -- field 12
                           || chr(9) -- field 13
                           || chr(9) -- field 14
                           || chr(9) -- field 15
                           || chr(9) -- field 16
                           || chr(9) -- field 17
                           || chr(9) -- field 18
                           || chr(9) -- field 19
                          --|| chr(9)                                            -- field 20
                           || v_pack_qty || chr(9) -- field 20
                           || p_quantity -- field 21
                           || chr(13));
      
      END IF;
    END IF;
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  END print_resin_pack_new;

  --------------------------------------------------------------------------------------------------------------
  -- Ver     When          Who           Description
  -- ------  ------------  ------------  -----------------------------------------------------------------------
  -- 1.0     27/02/2019    Roman W.      CHG0044871
  --                                        Concurrent : XX:Print Small Sticker after Hamara/XXWIPSTCKSMHAMARA
  --                                        Template   : Resin_Small
  -- 1.1     12/06/2019    Roman W.      CHG0045832 - Change sticker -XX:Print bottling sticker after hamara
  -- 1.2     31/10/2019    Bellona(TCS)  CHG0046734 spilt p_comp_lot & p_lot input into lot number and item id.
  --------------------------------------------------------------------------------------------------------------
  PROCEDURE print_resin_pack_hamara(errbuf         OUT VARCHAR2,
                                    retcode        OUT VARCHAR2,
                                    p_stiker_name  IN VARCHAR2, -- Resin_Pack_Kg
                                    p_printer_name IN VARCHAR2,
                                    p_lot          IN VARCHAR2,
                                    p_comp_lot     IN VARCHAR2,
                                    p_org_id       IN NUMBER,
                                    p_quantity     IN NUMBER,
                                    p_location     IN VARCHAR2,
                                    -- p_job_fg       IN VARCHAR2 -- added CHG0044871 -- rem by Roman W 12/06/2019 CHG0045832
                                    p_pack_qty IN NUMBER -- added by Roman W. 12/06/2019 CHG0045832
                                    ) IS
  
    v_comp_lot mtl_lot_numbers.lot_number%TYPE;
    -- v_expiration_date mtl_lot_numbers.expiration_date%TYPE; -- rem CHG0044871
    v_expiration_date_f3 VARCHAR2(30); -- added CHG0044871
    v_expiration_date_f7 VARCHAR2(30); -- added CHG0044871
    v_segment1           mtl_system_items_b.segment1%TYPE;
    v_start_quantity     wip_discrete_jobs.start_quantity%TYPE;
    v_description        mtl_system_items_b.description%TYPE;
    plist_file           utl_file.file_type;
    v_file_name          VARCHAR2(500);
    -- v_net_weight         VARCHAR2(300); -- CHG0044871 -- rem by Roman W. CHG0045832
    -- v_net_weight_lbs     VARCHAR2(300); -- CHG0044871 -- rem by Roman W. CHG0045832
  
    l_stiker_name VARCHAR2(300); -- CHG0044871
    l_is_prod     VARCHAR2(300) := xxobjt_general_utils_pkg.am_i_in_production; -- CHG0044871 Y/N
    l_location    VARCHAR2(300);
    v_pack_qty    VARCHAR2(300) := NULL; -- added by Roman W. CHG0045832
  
    l_lot          mtl_lot_numbers.lot_number%TYPE; --CHG0046734
    l_item_id      mtl_lot_numbers.inventory_item_id%TYPE; --CHG0046734
    l_comp_lot     mtl_lot_numbers.lot_number%TYPE; --CHG0046734
    l_comp_item_id mtl_lot_numbers.inventory_item_id%TYPE; --CHG0046734
  BEGIN
    message('Concurrent      : XX:Print Small Sticker after Hamara / XXWIPSTCKSMHAMARA');
    message('Package         : xxinv_bartender_pkg.print_resin_pack_hamara');
    message('p_stiker_name   :' || p_stiker_name);
    message('p_printer_name  :' || p_printer_name);
    message('p_lot           :' || p_lot);
    message('p_comp_lot      :' || p_comp_lot);
    message('p_org_id        :' || p_org_id);
    message('p_quantity      :' || p_quantity);
    message('p_location      :' || p_location);
    message('p_pack_qty      :' || p_pack_qty);
  
    --    message('p_job_fg        :' || p_job_fg);
    message('l_is_prod       :' || l_is_prod);
  
    --CHG0046734 splitting p_bot_lot input parameter into lot number and item id
    l_comp_lot     := substr(p_comp_lot, 0, instr(p_comp_lot, '|') - 1);
    l_comp_item_id := substr(p_comp_lot,
                             instr(p_comp_lot, '|') + 1,
                             length(p_comp_lot));
    message('l_comp_lot      :' || l_comp_lot);
    message('l_comp_item_id  :' || l_comp_item_id);
  
    l_lot     := substr(p_lot, 0, instr(p_lot, '|') - 1);
    l_item_id := substr(p_lot, instr(p_lot, '|') + 1, length(p_lot));
    message('l_lot           :' || l_lot);
    message('l_item_id       :' || l_item_id);
  
    v_comp_lot := nvl( /*p_comp_lot*/ l_comp_lot, /*p_lot*/ l_lot); --CHG0046734
    message('v_comp_lot       :' || v_comp_lot);
  
    IF 'Y' = l_is_prod THEN
      l_stiker_name := p_stiker_name;
      l_location    := p_location;
    ELSE
      l_stiker_name := 'DEV_' || p_stiker_name;
      l_location    := get_dev_dorectory;
    END IF;
  
    message('(New)l_stiker_name   :' || l_stiker_name);
    message('(New)l_location      :' || l_location);
  
    v_file_name := l_stiker_name || '_' ||
                   to_char(SYSDATE, 'RRMMDD_HH24MISS') || '.txt';
  
    BEGIN
      -- get expiration date for mtl
      SELECT -- mln.expiration_date rem CHG0044871
       to_char(mln.expiration_date, 'dd-Mon-yyyy') -- added CHG0044871
      ,
       to_char(mln.expiration_date, 'ddmmyyyy') -- added CHG0044871
        INTO --v_expiration_date -- rem CHG0044871
             v_expiration_date_f3,
             v_expiration_date_f7
        FROM mtl_lot_numbers mln
       WHERE mln.organization_id = p_org_id
         AND mln.lot_number = v_comp_lot
         AND mln.inventory_item_id = nvl(l_comp_item_id, l_item_id); --CHG0046734
    
      SELECT msib.segment1, msib.description
        INTO v_segment1, v_description
        FROM mtl_lot_numbers mln, mtl_system_items_b msib
       WHERE mln.organization_id = msib.organization_id
         AND mln.inventory_item_id = msib.inventory_item_id
         AND mln.lot_number = /*p_lot*/
             l_lot --CHG0046734
         AND mln.inventory_item_id = l_item_id --CHG0046734
         AND mln.organization_id = p_org_id;
    
      /*
      -- added chg0044871
      select md.element_value
        into v_net_weight
        from wip_entities FG, mtl_descr_element_values_v md
       where fg.wip_entity_name = p_job_fg
         and fg.primary_item_id = md.inventory_item_id
         and md.element_name = 'Weight Factor (Kg)'
         and md.element_value is not null;
      
      -- added chg0044871
      select md.element_value * 2.2
        into v_net_weight_lbs
        from wip_entities FG, mtl_descr_element_values_v md
       where fg.wip_entity_name = p_job_fg
         and fg.primary_item_id = md.inventory_item_id
         and md.element_name = 'Weight Factor (Kg)'
         and md.element_value is not null; -- chg0044871
      
      v_net_weight := v_net_weight || 'kg (' || v_net_weight_lbs || 'lbs)';
      */
    
    EXCEPTION
      WHEN no_data_found THEN
        retcode := '1';
        errbuf  := errbuf || 'No Data Found ' || chr(0);
      WHEN too_many_rows THEN
        retcode := '1';
        errbuf  := errbuf || 'Too Many Rows Returnd ' || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 1 THEN
    
      BEGIN
        plist_file := utl_file.fopen(location  => l_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid operation for ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
      END;
    
      IF nvl(retcode, 0) <> 2 THEN
      
        v_pack_qty := 'QT-' || p_pack_qty;
      
        utl_file.put_line(plist_file,
                          '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                          '.BTW /D=' || v_bartender_txt_location ||
                          ' /prn="' || p_printer_name || '" /R=3 /P /DD' ||
                          chr(13));
      
        utl_file.put_line(plist_file, '%END%' || chr(13));
      
        utl_file.put_line(plist_file,
                          l_lot /*p_lot*/
                           || chr(9) || -- field 1                 --CHG0046734
                           l_comp_lot /*p_comp_lot*/
                           || chr(9) || -- field 2       --CHG0046734
                          -- to_char(v_expiration_date, 'dd-Mon-yyyy') || -- rem CHG0044871
                           v_expiration_date_f3 || chr(9) || -- field 3 -- added CHG0044871
                           v_segment1 || chr(9) || -- field 4
                           v_start_quantity || chr(9) || -- field 5
                           v_description || chr(9) || -- field 6
                          -- to_char(v_expiration_date, 'ddmmyyyy') || chr(9) || -- field 7 -- rem CHG0044871
                           v_expiration_date_f7 || chr(9) || -- field 7 added CHG0044871
                           chr(9) || -- field 8
                           chr(9) || -- field 9
                           chr(9) || -- field 10
                           chr(9) || -- field 11
                           chr(9) || -- field 12
                           chr(9) || -- field 13
                           chr(9) || -- field 14
                           chr(9) || -- field 15
                           chr(9) || -- field 16
                           chr(9) || -- field 17
                           chr(9) || -- field 18
                           chr(9) || -- field 19
                           v_pack_qty || chr(9) || -- field 20
                           p_quantity || -- field 21
                           chr(13));
      END IF;
    END IF;
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := 'EXCEPTION_OTHERS xxinv_bartender_pkg.print_resin_pack_hamara(' ||
                 p_stiker_name || ',' || p_printer_name || ',' || l_lot /*p_lot*/
                 || ',' || --CHG0046734
                 l_comp_lot /*p_comp_lot*/
                 || ',' || p_org_id || ',' || p_quantity || ',' || --CHG0046734
                 p_location || ',' || p_pack_qty || ') - ' || SQLERRM;
    
  END print_resin_pack_hamara;
  ------------------------------------------------------------------------------------
  -- Ver     When          Who           Description
  -- ------  ------------  ------------  ---------------------------------------------
  -- 1.0     27/02/2019    Roman W.      CHG0045832
  --                                        Concurrent : XX:Print Small Sticker after Hamara/XXWIPSTCKSMSMALLHAMARA
  --                                        Template   : Resin_Small
  -- 1.1     31/10/2019    Bellona(TCS)  CHG0046734 spilt p_botteling_lot input into lot number and item id.
  ------------------------------------------------------------------------------------
  PROCEDURE print_resin_pack_small_hamara(errbuf         OUT VARCHAR2,
                                          retcode        OUT VARCHAR2,
                                          p_stiker_name  IN VARCHAR2, -- Resin_Small
                                          p_printer_name IN VARCHAR2,
                                          p_lot          IN VARCHAR2,
                                          p_comp_lot     IN VARCHAR2,
                                          p_org_id       IN NUMBER,
                                          p_quantity     IN NUMBER,
                                          p_location     IN VARCHAR2,
                                          p_job_fg       IN VARCHAR2 -- added CHG0044871
                                          ) IS
  
    v_comp_lot           mtl_lot_numbers.lot_number%TYPE;
    v_expiration_date_f3 VARCHAR2(30); -- added CHG0044871
    v_expiration_date_f7 VARCHAR2(30); -- added CHG0044871
    v_segment1           mtl_system_items_b.segment1%TYPE;
    v_start_quantity     wip_discrete_jobs.start_quantity%TYPE;
    v_description        mtl_system_items_b.description%TYPE;
    plist_file           utl_file.file_type;
    v_file_name          VARCHAR2(500);
    v_net_weight         VARCHAR2(300); -- CHG0044871
    v_net_weight_lbs     VARCHAR2(300); -- CHG0044871
  
    l_stiker_name VARCHAR2(300); -- CHG0044871
    l_is_prod     VARCHAR2(300) := xxobjt_general_utils_pkg.am_i_in_production; -- CHG0044871 Y/N
    l_location    VARCHAR2(300);
  
    l_lot     mtl_lot_numbers.lot_number%TYPE; --CHG0046734
    l_item_id mtl_lot_numbers.inventory_item_id%TYPE; --CHG0046734
  BEGIN
    message('Concurrent      : XX:Print Small Sticker after Hamara / XXWIPSTCKSMHAMARA');
    message('Package         : xxinv_bartender_pkg.print_resin_pack_hamara');
    message('p_stiker_name   :' || p_stiker_name);
    message('p_printer_name  :' || p_printer_name);
    message('p_lot           :' || p_lot);
    message('p_comp_lot      :' || p_comp_lot);
    message('p_org_id        :' || p_org_id);
    message('p_quantity      :' || p_quantity);
    message('p_location      :' || p_location);
    message('p_job_fg        :' || p_job_fg);
    message('l_is_prod       :' || l_is_prod);
  
    --CHG0046734 splitting p_lot input parameter into lot number and item id
    l_lot     := substr(p_lot, 0, instr(p_lot, '|') - 1);
    l_item_id := substr(p_lot, instr(p_lot, '|') + 1, length(p_lot));
    message('l_lot           :' || l_lot);
    message('l_item_id       :' || l_item_id);
  
    v_comp_lot := nvl(p_comp_lot, /*p_lot*/ l_lot); --CHG0046734 replaced p_lot with l_lot
    message('v_comp_lot       :' || v_comp_lot);
  
    IF 'Y' = l_is_prod THEN
      l_stiker_name := p_stiker_name;
      l_location    := p_location;
    ELSE
      l_stiker_name := 'DEV_' || p_stiker_name;
      l_location    := get_dev_dorectory;
    END IF;
  
    message('(New)l_stiker_name   :' || l_stiker_name);
    message('(New)l_location      :' || l_location);
  
    v_file_name := l_stiker_name || '_' ||
                   to_char(SYSDATE, 'RRMMDD_HH24MISS') || '.txt';
  
    BEGIN
      -- get expiration date for mtl
      SELECT -- mln.expiration_date rem CHG0044871
       to_char(mln.expiration_date, 'dd-Mon-yyyy') -- added CHG0044871
      ,
       to_char(mln.expiration_date, 'ddmmyyyy') -- added CHG0044871
        INTO --v_expiration_date -- rem CHG0044871
             v_expiration_date_f3,
             v_expiration_date_f7
        FROM mtl_lot_numbers mln
       WHERE mln.organization_id = p_org_id
         AND mln.lot_number = v_comp_lot
         AND mln.inventory_item_id = l_item_id; --CHG0046734
    
      SELECT msib.segment1, msib.description
        INTO v_segment1, v_description
        FROM mtl_lot_numbers mln, mtl_system_items_b msib
       WHERE mln.organization_id = msib.organization_id
         AND mln.inventory_item_id = msib.inventory_item_id
         AND mln.lot_number = /*p_lot*/
             l_lot --CHG0046734 replaced p_lot with l_lot
         AND mln.inventory_item_id = l_item_id --CHG0046734
         AND mln.organization_id = p_org_id;
    
      -- added chg0044871
      SELECT md.element_value
        INTO v_net_weight
        FROM wip_entities fg, mtl_descr_element_values_v md
       WHERE fg.wip_entity_name = p_job_fg
         AND fg.primary_item_id = md.inventory_item_id
         AND md.element_name = 'Weight Factor (Kg)'
         AND md.element_value IS NOT NULL;
    
      -- added chg0044871
      SELECT md.element_value * 2.2
        INTO v_net_weight_lbs
        FROM wip_entities fg, mtl_descr_element_values_v md
       WHERE fg.wip_entity_name = p_job_fg
         AND fg.primary_item_id = md.inventory_item_id
         AND md.element_name = 'Weight Factor (Kg)'
         AND md.element_value IS NOT NULL; -- chg0044871
    
      v_net_weight := v_net_weight || 'kg (' || v_net_weight_lbs || 'lbs)';
    
    EXCEPTION
      WHEN no_data_found THEN
        retcode := '1';
        errbuf  := errbuf || 'No Data Found ' || chr(0);
      WHEN too_many_rows THEN
        retcode := '1';
        errbuf  := errbuf || 'Too Many Rows Returnd ' || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 1 THEN
    
      BEGIN
        plist_file := utl_file.fopen(location  => l_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid operation for ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
      END;
    
      IF nvl(retcode, 0) <> 2 THEN
        utl_file.put_line(plist_file,
                          '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                          '.BTW /D=' || v_bartender_txt_location ||
                          ' /prn="' || p_printer_name || '" /R=3 /P /DD' ||
                          chr(13));
        utl_file.put_line(plist_file, '%END%' || chr(13));
        utl_file.put_line(plist_file,
                          /*p_lot*/
                          l_lot || chr(9) || -- field 1         --CHG0046734 replaced p_lot with l_lot
                          p_comp_lot || chr(9) || -- field 2
                          v_expiration_date_f3 || chr(9) || -- field 3 -- added CHG0044871
                          v_segment1 || chr(9) || -- field 4
                          v_start_quantity || chr(9) || -- field 5
                          v_description || chr(9) || -- field 6
                          v_expiration_date_f7 || chr(9) || -- field 7 added CHG0044871
                          chr(9) || -- field 8
                          chr(9) || -- field 9
                          chr(9) || -- field 10
                          chr(9) || -- field 11
                          chr(9) || -- field 12
                          chr(9) || -- field 13
                          chr(9) || -- field 14
                          chr(9) || -- field 15
                          chr(9) || -- field 16
                          chr(9) || -- field 17
                          chr(9) || -- field 18
                          chr(9) || -- field 19
                          v_net_weight || chr(9) || -- field 20
                          p_quantity || -- field 21
                          chr(13));
      END IF;
    END IF;
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := 'EXCEPTION_OTHERS xxinv_bartender_pkg.print_resin_pack_small_hamara(' ||
                 p_stiker_name || ',' || p_printer_name || ',' || /*p_lot*/
                 l_lot || ',' || --CHG0046734 replaced p_lot with l_lot
                 p_comp_lot || ',' || p_org_id || ',' || p_quantity || ',' ||
                 p_location || ',' || p_job_fg || ') - ' || SQLERRM;
    
  END print_resin_pack_small_hamara;

  ------------------------------------------------
  -- print_rcv_pack_e
  ------------------------------------------------
  PROCEDURE print_rcv_pack_e(errbuf           OUT VARCHAR2,
                             retcode          OUT VARCHAR2,
                             p_stiker_name    IN VARCHAR2,
                             p_printer_name   IN VARCHAR2,
                             p_fm_receipt_num IN NUMBER,
                             p_to_receipt_num IN NUMBER,
                             p_org_id         IN NUMBER,
                             p_quantity       IN NUMBER,
                             p_location       IN VARCHAR2) IS
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
    --  v_file_name_2 VARCHAR2(500) := p_stiker_name || '_' ||to_char(SYSDATE, 'RRMMDD_HH24MISS') ||'.dat';
  BEGIN
  
    IF nvl(retcode, 0) <> 1 THEN
      BEGIN
        plist_file := utl_file.fopen(location  => p_location,
                                     filename  => v_file_name,
                                     open_mode => 'w');
        fnd_file.put_line(fnd_file.log,
                          'File ' || ltrim(v_file_name) ||
                          ' Is open For Writing ');
      EXCEPTION
        WHEN utl_file.invalid_path THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_mode THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                     chr(0);
        WHEN utl_file.invalid_operation THEN
          retcode := '2';
          errbuf  := errbuf || 'Invalid operation for ' ||
                     ltrim(v_file_name) || SQLERRM || chr(0);
        WHEN OTHERS THEN
          retcode := '2';
          errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
      END;
    END IF;
  
    IF nvl(retcode, 0) <> 2 THEN
      utl_file.put_line(plist_file,
                        '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                        '.BTW /D=' || v_bartender_txt_location || ' /prn="' ||
                        p_printer_name || '" /R=3 /P /DD' || chr(13));
      utl_file.put_line(plist_file, '%END%' || chr(13));
    END IF;
  
    FOR crs IN (SELECT DISTINCT rsh.receipt_num AS receipt_num,
                                apven.vendor_name AS vendor_name,
                                apven.vendor_number AS vendor_number,
                                to_char(rt.transaction_date,
                                        'Month dd, RRRR') AS rcv_date_medium,
                                to_char(rt.transaction_date, 'dd/mm/RR') AS rcv_date_small
                  FROM rcv_transactions     rt,
                       rcv_shipment_headers rsh,
                       rcv_shipment_lines   rsl,
                       ap_vendors_v         apven
                 WHERE rt.transaction_type = 'DELIVER'
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsh.shipment_header_id = rt.shipment_header_id
                   AND rt.shipment_line_id = rsl.shipment_line_id
                   AND to_number(rsh.receipt_num) >= p_fm_receipt_num
                   AND to_number(rsh.receipt_num) <= p_to_receipt_num
                   AND rt.organization_id = p_org_id
                   AND apven.vendor_id = rt.vendor_id
                   AND rt.destination_type_code = 'EXPENSE') LOOP
    
      utl_file.put_line(plist_file,
                        'RC' || crs.receipt_num || chr(9) || ' ' || chr(9) ||
                        crs.vendor_name || chr(9) || crs.vendor_number ||
                        chr(9) || crs.rcv_date_medium || chr(9) ||
                        crs.rcv_date_small || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || p_quantity || chr(13));
    END LOOP;
  
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  END print_rcv_pack_e;

  PROCEDURE print_general_stiker(errbuf         OUT VARCHAR2,
                                 retcode        OUT VARCHAR2,
                                 p_stiker_name  IN VARCHAR2,
                                 p_printer_name IN VARCHAR2,
                                 p_location     IN VARCHAR2,
                                 p_copies       IN NUMBER,
                                 p_item_code    IN VARCHAR2,
                                 p_att1         IN VARCHAR2,
                                 p_att2         IN VARCHAR2,
                                 p_att3         IN VARCHAR2,
                                 p_att4         IN VARCHAR2,
                                 p_att5         IN VARCHAR2) IS
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
  
    l_item_desc VARCHAR2(150);
    l_str1      VARCHAR2(250);
    l_str       VARCHAR2(250);
    -- v_file_name_2 VARCHAR2(500) := p_stiker_name || '_' ||to_char(SYSDATE, 'RRMMDD_HH24MISS') ||'.dat';
  BEGIN
  
    BEGIN
    
      SELECT t.description
        INTO l_item_desc
        FROM mtl_system_items_b t
       WHERE t.organization_id = 91
         AND t.segment1 = p_item_code;
    EXCEPTION
      WHEN OTHERS THEN
        errbuf  := 'No description found for item ' || p_item_code;
        retcode := '2';
        RETURN;
    END;
    BEGIN
      plist_file := utl_file.fopen(location  => p_location,
                                   filename  => v_file_name,
                                   open_mode => 'w');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(v_file_name) ||
                        ' Is open For Writing ');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_mode THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_operation THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' || ltrim(v_file_name) ||
                   SQLERRM || chr(0);
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 2 THEN
    
      l_str := '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name || '.BTW /D=' ||
               v_bartender_txt_location || ' /prn="' || p_printer_name ||
               '" /R=3 /P ' || '/DD ' || chr(13);
      utl_file.put_line(plist_file, l_str);
    
      utl_file.put_line(plist_file, '%END%' || chr(13));
    
      l_str1 := p_item_code || chr(9) || l_item_desc || chr(9) || p_att1 ||
                chr(9) || p_att2 || chr(9) || p_att3 || chr(9) || p_att4 ||
                chr(9) || p_att5 || chr(9) || chr(9) || chr(9) || chr(9) ||
                chr(9) || chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                chr(9) || chr(9) || chr(9) || chr(9) || p_copies || chr(13);
    
      utl_file.put_line(plist_file, l_str1);
    END IF;
  
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    
      fnd_file.put_line(fnd_file.log, 'Created file :' || v_file_name);
      fnd_file.put_line(fnd_file.log, '--------------------------------');
      fnd_file.put_line(fnd_file.log, l_str);
      fnd_file.put_line(fnd_file.log, l_str1);
    END IF;
  END;

  --------------------------------------------------------------------
  --  name:            print_dangerous_mat_stiker
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   11.11.12
  --------------------------------------------------------------------
  --  purpose :        print_dangerous_mat_stiker
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11.11.12    yuval tal         initial build - print_dangerous_mat_stiker: modify param order in
  --                                     in case of quantity null : get quantity by select
  -- 1.1   13.4.14     yuval tal         CHG0031743: change location when ou is 81
  -- 1.2   25.05.14    yuval tal         CHG0032254 : Further CHG0031743
  --                                     required to bring the address of the IL shipper into the DG sticker according the next logic:
  --                                     in case the shipper location located in israel than bring the location details of
  --                                     IPK - Kiryat Gat ( LOCATION_ID = 144)
  -- 1.3   13.04.2015  Michal Tzvik      CHG0034135 ? Update cursor c_ship to bring the right address for political orders
  -- 1.4   14/02/2018  bellona banerjee  CHG0041294- Added P_Delivery_Name as part of delivery_id to delivery_name conversion
  --------------------------------------------------------------------
  PROCEDURE print_dangerous_mat_stiker(errbuf         OUT VARCHAR2,
                                       retcode        OUT VARCHAR2,
                                       p_stiker_name  IN VARCHAR2,
                                       p_printer_name IN VARCHAR2,
                                       p_location     IN VARCHAR2,
                                       -- p_delivery_id  IN VARCHAR2,  -- CHG0041294 - on 14/02/2018 for delivery id to name change
                                       p_delivery_name IN VARCHAR2, -- CHG0041294 - on 14/02/2018 for delivery id to name change
                                       p_copies        IN NUMBER) IS
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
  
    l_str1 VARCHAR2(500);
    l_str  VARCHAR2(500);
  
    CURSOR c_ship IS
    -- CHG0034135
      SELECT DISTINCT decode(hl.country,
                             'IL',
                             CASE
                               WHEN wdv.is_delivery_political = 1 THEN
                                hl3.location_code
                               ELSE
                                hl2.location_code
                             END,
                             hl.location_code) location_code,
                      decode(hl.country,
                             'IL',
                             CASE
                               WHEN wdv.is_delivery_political = 1 THEN
                                hl3.address_line_1 || ' ' || hl3.address_line_2 || ' ' ||
                                hl3.address_line_3
                               ELSE
                                hl2.address_line_1 || ' ' || hl2.address_line_2 || ' ' ||
                                hl2.address_line_3
                             END,
                             hl.address_line_1 || ' ' || hl.address_line_2 || ' ' ||
                             hl.address_line_3) address,
                      decode(hl.country,
                             'IL',
                             CASE
                               WHEN wdv.is_delivery_political = 1 THEN
                                hl3.town_or_city || ' ' || hl3.region_2 || ' ' ||
                                hl3.postal_code
                               ELSE
                                hl2.town_or_city || ' ' || hl2.region_2 || ' ' ||
                                hl2.postal_code
                             END,
                             hl.town_or_city || ' ' || hl.region_2 || ' ' ||
                             hl.postal_code) town,
                      CASE
                        WHEN wdv.is_delivery_political = 1 THEN
                         ftv3.territory_short_name
                        ELSE
                         ftv2.territory_short_name
                      END territory_short_name,
                      
                      decode(hl.country,
                             'IL',
                             CASE
                               WHEN wdv.is_delivery_political = 1 THEN
                                hl3.telephone_number_1 || ' ' ||
                                hl3.telephone_number_2
                               ELSE
                                hl2.telephone_number_1 || ' ' ||
                                hl2.telephone_number_2
                             END,
                             hl.telephone_number_1 || ' ' ||
                             hl.telephone_number_2) phone
        FROM (SELECT xxwsh_political.is_delivery_political(w.delivery_id) is_delivery_political,
                     w.*
                FROM wsh_deliverables_v w
               WHERE w.delivery_id =
                     xxinv_trx_in_pkg.get_delivery_id(p_delivery_name)) wdv, --p_delivery_id) wdv,
             -- CHG0041294- on 14/02/2018 for delivery id to name change
             hr_locations          hl,
             hr_locations          hl2,
             fnd_territories_vl    ftv2,
             hr_locations          hl3,
             fnd_territories_vl    ftv3,
             hr_organization_units hou3
       WHERE wdv.ship_from_location_id = hl.location_id
         AND wdv.type = 'L'
         AND ftv2.territory_code = hl.country
         AND hl2.location_id = 144
         AND wdv.org_id = hou3.organization_id
         AND hou3.location_id = hl3.location_id
         AND ftv3.territory_code = hl3.country;
  
    CURSOR c_consignee IS
      SELECT DISTINCT xxhz_party_ga_util.get_party_name4account(customer_id) customer,
                      hl.address1 || ' ' || hl.address2 address,
                      hl.city || ' ' || hl.state || ' ' || hl.postal_code city,
                      ftv.territory_short_name
        FROM wsh_deliverables_v wdv,
             hz_locations       hl,
             fnd_territories_vl ftv
       WHERE wdv.ship_to_location_id = hl.location_id
         AND wdv.type = 'L'
         AND ftv.territory_code = hl.country
         AND wdv.delivery_id =
             xxinv_trx_in_pkg.get_delivery_id(p_delivery_name); --p_delivery_id; -- CHG0041294- on 14/02/2018 for delivery id to name change
  
    -- v_file_name_2 VARCHAR2(500) := p_stiker_name || '_' ||to_char(SYSDATE, 'RRMMDD_HH24MISS') ||'.dat';
    l_copies NUMBER;
  BEGIN
  
    fnd_file.put_line(fnd_file.log, 'l_copies ' || l_copies);
  
    -- CR513 set default value (when submitted from document set default value of select type is not working)
    IF p_copies IS NULL THEN
    
      SELECT SUM(wd.requested_quantity)
        INTO l_copies
        FROM wsh_deliverables_v wd, mtl_system_items_b b
       WHERE b.inventory_item_id = wd.inventory_item_id
         AND b.organization_id = 91
         AND wd.delivery_id =
             xxinv_trx_in_pkg.get_delivery_id(p_delivery_name) --p_delivery_id    -- CHG0041294- on 14/02/2018 for delivery id to name change
         AND b.stock_enabled_flag = 'Y'
         AND wd.type = 'L';
    
      fnd_file.put_line(fnd_file.log, 'l_copies ' || l_copies);
    ELSE
    
      l_copies := p_copies;
    END IF;
  
    BEGIN
      plist_file := utl_file.fopen(location  => p_location,
                                   filename  => v_file_name,
                                   open_mode => 'w');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(v_file_name) ||
                        ' Is open For Writing ');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_mode THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_operation THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' || ltrim(v_file_name) ||
                   SQLERRM || chr(0);
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 2 THEN
    
      l_str := '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name || '.BTW /D=' ||
               v_bartender_txt_location || ' /prn="' || p_printer_name ||
               '" /R=3 /P ' || '/DD ' || chr(13);
      utl_file.put_line(plist_file, l_str);
    
      utl_file.put_line(plist_file, '%END%' || chr(13));
    
      FOR i IN c_ship LOOP
        FOR j IN c_consignee LOOP
          l_str1 := chr(9) || chr(9) || chr(9) || i.location_code || chr(9) ||
                    i.address || chr(9) || i.town || chr(9) ||
                    i.territory_short_name || chr(9) || i.
                    phone || chr(9) || j.customer || chr(9) || j.address ||
                    chr(9) || j.city || chr(9) || j.territory_short_name ||
                    chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                    chr(9) || chr(9) || chr(9) || chr(9) || l_copies;
        END LOOP;
      
      END LOOP;
    
      l_str1 := REPLACE(l_str1, chr(13), '');
    
      l_str1 := l_str1 || chr(13);
    
      utl_file.put_line(plist_file, l_str1);
    END IF;
  
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    
      fnd_file.put_line(fnd_file.log, 'Created file :' || v_file_name);
      fnd_file.put_line(fnd_file.log, '--------------------------------');
      fnd_file.put_line(fnd_file.log, l_str);
      fnd_file.put_line(fnd_file.log, l_str1);
    END IF;
  END;

  ---------------------------------------
  -- Concurrent : XXWIPINKPRT / XX: Send Formulations Lot to Desktop Inkjet
  --------------------------------------------------------------------------
  -- Porpose: cust612/cr618
  -- support  Send Formulations Lot data to Inkjet printer
  --------------------------------------------------------------------------
  -- Ver    Date        Performer    Comments
  -- -----  ----------  -----------  -------------------------------------
  -- 1.0    12.12.12    yuval tal    initial Build
  --                                       print_resin_pack_ink
  --                                           set string to ink printer by tcp
  --                                           p_template : string with known chars which support printer commands
  --                                           repelce &JOB and &EXP_DATE with actual values
  --
  -- 1.1    13/01/2020  Roman W.     CHG0047181 - New Inkjet printer in Resin plant
  -- 1.2    28/01/2020  Roman W.     CHG0047181 - l_template  varchar2(50) -> varchar2(150)
  -- 1.3    17/09/2020  Roman W      CHG0048593 - Change formulation sticker and desktop inkjet
  -- 1.4    11/11/2020  yuval tal    INC0212136 - change lot source
  --------------------------------------------------------------------------------------
  PROCEDURE print_resin_pack_ink(errbuf         OUT VARCHAR2,
                                 retcode        OUT VARCHAR2,
                                 p_printer_name IN VARCHAR2,
                                 -- p_job_name      IN VARCHAR2, Rem By Roman W. 17/09/2020 CHG0048593
                                 p_bot_lot       IN VARCHAR2,
                                 p_org_id        IN NUMBER,
                                 p_component_lot IN VARCHAR2,
                                 -- p_template      IN VARCHAR2, -- CHG0047181
                                 p_job_fg IN VARCHAR2 -- CHG0047181
                                 ) IS
  
    l_string          VARCHAR2(32000);
    v_comp_lot        mtl_lot_numbers.lot_number%TYPE;
    v_assembly_lot    mtl_lot_numbers.lot_number%TYPE;
    v_expiration_date mtl_lot_numbers.expiration_date%TYPE;
    v_segment1        mtl_system_items_b.segment1%TYPE;
    v_start_quantity  wip_discrete_jobs.start_quantity%TYPE;
    v_description     mtl_system_items_b.description%TYPE;
  
    l_ip           VARCHAR2(30); -- CHG0047181
    l_template     VARCHAR2(150); -- CHG0047181
    l_net_weight   VARCHAR2(50); -- CHG0047181
    l_weight_instr NUMBER;
  BEGIN
    errbuf  := NULL;
    retcode := '0';
  
    message('p_printer_name = ' || p_printer_name);
    -- message('p_job_name = ' || p_job_name); -- rem CHG0048593
    message('p_bot_lot = ' || p_bot_lot); -- Added CHG0048593
    message('p_org_id = ' || p_org_id);
    message('p_component_lot = ' || p_component_lot);
    message('p_job_fg = ' || p_job_fg);
  
    -- Get Printer IP / Template  CHG0047181
    SELECT ffvv.attribute1, ffvv.attribute2
      INTO l_ip, l_template
      FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvv
     WHERE ffvs.flex_value_set_name = 'XXINV_INKJET_PRINTERS'
       AND ffvs.flex_value_set_id = ffvv.flex_value_set_id
       AND TRIM(ffvv.flex_value) = TRIM(p_printer_name);
  
    -- Check is p_job_fg required --
    l_weight_instr := instr(l_template, 'WEIGHT');
  
    IF 0 < l_weight_instr THEN
    
      IF p_job_fg IS NULL THEN
        errbuf  := 'Error : P_JOB_FG - can''t be empty';
        retcode := '2';
        RETURN;
      ELSE
        -- Added By Roman W. CHG0047181
        SELECT md.element_value
          INTO l_net_weight
          FROM wip_entities fg, mtl_descr_element_values_v md
         WHERE TRIM(fg.wip_entity_name) = TRIM(p_job_fg)
           AND fg.primary_item_id = md.inventory_item_id
           AND md.element_name = 'Weight Factor (Kg)'
           AND md.element_value IS NOT NULL; -- chg0044871
      
      END IF;
    
    END IF;
  
    v_comp_lot := nvl(p_component_lot, /*p_job_name CHG0048593*/ p_bot_lot);
    /*
    SELECT mln.lot_number assembly_lot,
           mln.expiration_date,
           msib.segment1,
           wdj.start_quantity,
           msib.description
      INTO v_assembly_lot,
           v_expiration_date,
           v_segment1,
           v_start_quantity,
           v_description
      FROM wip_discrete_jobs  wdj,
           wip_entities       we,
           mtl_lot_numbers    mln,
           mtl_system_items_b msib
     WHERE wdj.wip_entity_id = we.wip_entity_id
       AND trim(we.wip_entity_name) =
           trim( p_bot_lot)
       AND trim(mln.lot_number) = trim(v_comp_lot)
       AND
          --  we.primary_item_id = mln.inventory_item_id AND
           msib.inventory_item_id = we.primary_item_id
       AND msib.organization_id = p_org_id
       AND wdj.organization_id = we.organization_id
       AND wdj.organization_id = p_org_id;
       */
    SELECT mln.lot_number assembly_lot,
           /*
           to_char(mln.expiration_date, 'dd-Mon-yyyy') expiration_date_f3, -- added CHG0044871
           to_char(mln.expiration_date, 'ddmmyyyy') expiration_date_f7, -- added CHG0044871
           */
           mln.expiration_date,
           msib.segment1,
           --wdj.start_quantity,
           msib.description
      INTO v_assembly_lot,
           v_expiration_date,
           v_segment1,
           --v_start_quantity,
           v_description
      FROM wip_entities we, mtl_lot_numbers mln, mtl_system_items_b msib
     WHERE 1 = 1
       AND mln.lot_number || '|' || mln.inventory_item_id = p_bot_lot
       AND mln.inventory_item_id = we.primary_item_id --CHG0037096
       AND mln.organization_id = we.organization_id --CHG0037096
       AND msib.inventory_item_id = we.primary_item_id
       AND msib.organization_id = we.organization_id
       AND we.organization_id = p_org_id
       AND we.wip_entity_id IN
           (SELECT mt.transaction_source_id
              FROM mtl_transaction_lot_numbers mt
             WHERE mt.lot_number = mln.lot_number
               AND mln.inventory_item_id = mt.inventory_item_id
               AND mln.organization_id = mt.organization_id
               AND we.wip_entity_id = mt.transaction_source_id);
  
    -- set string to print
    --l_string := REPLACE(p_template, '&EXP_DATE', to_char(v_expiration_date, 'DD-MON-YYYY')); -- CHG0047181
  
    --- EXP_DATE ---
    l_string := REPLACE(l_template,
                        '&EXP_DATE',
                        to_char(v_expiration_date, 'DD-MON-YYYY'));
    --- LOT ---
    l_string := REPLACE(l_string, /*'&JOB' CHG0048593 */
                        '&LOT', /*p_job_name CHG0048593 */
                        v_assembly_lot); -- INC0212136
  
    --- WEIGHT --- CHG0047181
    l_string := REPLACE(l_string, '&WEIGHT', l_net_weight);
  
    fnd_file.put_line(fnd_file.output, 'String Set to :' || l_string);
    --call_printer_tcp
  
    -- call_printer_tcp(errbuf, retcode, p_printer_name, 7000, l_string);
  
    call_printer_tcp(errbuf, retcode, l_ip, 7000, l_string);
  
    -- fnd_file.put_line(fnd_file.output, 'String Send to Printer:' || p_printer_name);
    fnd_file.put_line(fnd_file.output, 'String Send to Printer:' || l_ip);
  
  EXCEPTION
    WHEN no_data_found THEN
      retcode := '1';
      errbuf  := errbuf || 'No Data Found ' || chr(0);
      fnd_file.put_line(fnd_file.output, 'Error :' || errbuf);
    WHEN too_many_rows THEN
      retcode := '1';
      errbuf  := errbuf || 'Too Many Rows Returnd ' || chr(0);
      fnd_file.put_line(fnd_file.output, 'Error :' || errbuf);
    
  END print_resin_pack_ink;
  ---------------------------------------
  -- print_resin_pack_hamara_ink
  --------------------------------------------------------------------------
  -- Porpose: cust612/cr618
  -- support  Send Formulations Lot data to Inkjet printer
  ----------------------------------------------------------------------------------------------------------------
  -- Ver   When         Who             Descr
  -- ----  -----------  --------------  --------------------------------------------------------------------------
  -- 1.0   12.12.12     yuval tal       initial Build
  --                                       print_resin_pack_hamara_ink
  --                                         set string to ink printer by tcp
  --                                         p_template : string with known chars which support printer commands
  --                                                     repelce &JOB and &EXP_DATE with actual values
  -- 1.1   31/10/2019   Bellona(TCS)    CHG0046734 spilt p_lot input into lot number and item id.
  -- 1.2   13/01/2020   Roman W.        CHG0047181 - New Inkjet printer in Resin plant
  ----------------------------------------------------------------------------------------------------------------
  PROCEDURE print_resin_pack_hamara_ink(errbuf         OUT VARCHAR2,
                                        retcode        OUT VARCHAR2,
                                        p_printer_name IN VARCHAR2,
                                        p_lot          IN VARCHAR2,
                                        p_comp_lot     IN VARCHAR2,
                                        p_org_id       IN NUMBER,
                                        --p_template     VARCHAR2 rem by Roman W. CHG0047181
                                        p_job_fg IN VARCHAR2) IS
  
    v_comp_lot        mtl_lot_numbers.lot_number%TYPE;
    v_expiration_date mtl_lot_numbers.expiration_date%TYPE;
    v_segment1        mtl_system_items_b.segment1%TYPE;
    --v_start_quantity  wip_discrete_jobs.start_quantity%TYPE;
    v_description mtl_system_items_b.description%TYPE;
  
    l_string  VARCHAR2(32000);
    l_lot     mtl_lot_numbers.lot_number%TYPE; --CHG0046734
    l_item_id mtl_lot_numbers.inventory_item_id%TYPE; --CHG0046734
  
    l_ip           VARCHAR2(30); -- CHG0047181
    l_template     VARCHAR2(300); -- CHG0047181
    l_net_weight   VARCHAR2(50); -- CHG0047181
    l_weight_instr NUMBER;
  BEGIN
    --CHG0046734 splitting p_bot_lot input parameter into lot number and item id
    l_lot     := substr(p_lot, 0, instr(p_lot, '|') - 1);
    l_item_id := substr(p_lot, instr(p_lot, '|') + 1, length(p_lot));
  
    v_comp_lot := nvl(p_comp_lot, /*p_lot*/ l_lot); --CHG0046734
  
    -- Get Printer IP / Template  CHG0047181
    SELECT ffvv.attribute1, ffvv.attribute2
      INTO l_ip, l_template
      FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvv
     WHERE ffvs.flex_value_set_name = 'XXINV_INKJET_PRINTERS'
       AND ffvs.flex_value_set_id = ffvv.flex_value_set_id
       AND ffvv.flex_value = p_printer_name;
  
    l_weight_instr := instr(l_template, 'WEIGHT');
  
    IF 0 < l_weight_instr THEN
    
      IF p_job_fg IS NULL THEN
        errbuf  := 'Error : P_JOB_FG - can''t be empty';
        retcode := '2';
        RETURN;
      ELSE
        -- Added By Roman W. CHG0047181
        SELECT md.element_value
          INTO l_net_weight
          FROM wip_entities fg, mtl_descr_element_values_v md
         WHERE fg.wip_entity_name = p_job_fg
           AND fg.primary_item_id = md.inventory_item_id
           AND md.element_name = 'Weight Factor (Kg)'
           AND md.element_value IS NOT NULL; -- chg0044871
      
      END IF;
    
    END IF;
    -- get expiration date for mtl
    SELECT mln.expiration_date
      INTO v_expiration_date
      FROM mtl_lot_numbers mln
     WHERE mln.organization_id = p_org_id
       AND mln.lot_number = v_comp_lot
       AND mln.inventory_item_id = l_item_id; --CHG0046734
  
    SELECT msib.segment1, msib.description
      INTO v_segment1, v_description
      FROM mtl_lot_numbers mln, mtl_system_items_b msib
     WHERE mln.organization_id = msib.organization_id
       AND mln.inventory_item_id = msib.inventory_item_id
       AND mln.lot_number = /*p_lot*/
           l_lot --CHG0046734 replaced p_lot with l_lot
       AND mln.inventory_item_id = l_item_id --CHG0046734
       AND mln.organization_id = p_org_id;
  
    -- set string to print
    -- l_string := REPLACE(p_template, '&EXP_DATE', to_char(v_expiration_date, 'DD-MON-YYYY')); -- Rem by Roman W. CHG0047181
  
    --- EXP_DATE ---
    l_string := REPLACE(l_template,
                        '&EXP_DATE',
                        to_char(v_expiration_date, 'DD-MON-YYYY')); -- Added By Roman W. CHG0047181
    --- JOB ---
    l_string := REPLACE(l_string, '&JOB', /*p_lot*/ l_lot); --CHG0046734 replaced p_lot with l_lot
    --- WEIGHT ---
    l_string := REPLACE(l_string, '&WEIGHT', l_net_weight); --CHG0046734 replaced p_lot with l_lot
  
    fnd_file.put_line(fnd_file.output, 'String Set to :' || l_string);
    --call_printer_tcp
  
    -- call_printer_tcp(errbuf, retcode, p_printer_name, 7000, l_string); -- rem by Roman W CHG0047181
    call_printer_tcp(errbuf, retcode, l_ip, 7000, l_string);
  
    -- fnd_file.put_line(fnd_file.output, 'String Send to Printer:' || p_printer_name); -- Rem by Roman W. CHG0047181
    fnd_file.put_line(fnd_file.output, 'String Send to Printer:' || l_ip);
  
  EXCEPTION
    WHEN no_data_found THEN
      retcode := '1';
      errbuf  := errbuf || 'No Data Found ' || chr(0);
      fnd_file.put_line(fnd_file.output, 'Error :' || errbuf);
    WHEN too_many_rows THEN
      retcode := '1';
      errbuf  := errbuf || 'Too Many Rows Returnd ' || chr(0);
      fnd_file.put_line(fnd_file.output, 'Error :' || errbuf);
    
  END;

  --------------------------------------------------------------------
  --  name:              print_inspection_release
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     29.08.13
  --------------------------------------------------------------------
  --  purpose :          cr981 Create WRI Inspection Release Sticker
  --------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   29.08.13      yuval tal         initial Build
  --  1.1   28/09/2014    Dalit A. Raviv    CHG0032719 - add locator parameter
  --------------------------------------------------------------------
  PROCEDURE print_inspection_release(errbuf           OUT VARCHAR2,
                                     retcode          OUT VARCHAR2,
                                     p_stiker_name    IN VARCHAR2,
                                     p_printer_name   IN VARCHAR2,
                                     p_fm_receipt_num IN NUMBER,
                                     p_to_receipt_num IN NUMBER,
                                     p_org_id         IN NUMBER,
                                     p_quantity       IN NUMBER,
                                     p_item           IN VARCHAR2,
                                     p_location       IN VARCHAR2,
                                     p_plan_id        IN NUMBER,
                                     p_lot            IN VARCHAR2) IS
  
    CURSOR c IS
      SELECT msib.segment1,
             qrv.character1 lot,
             qrv.character4 approver_name,
             qrv.receipt_num,
             to_char(to_date(qrv.transaction_date, 'DD-MON-YY'),
                     'dd-MON-yyyy') inspection_date,
             to_char(to_date(qrv.character2, 'yyyy/mm/dd'), 'dd-MON-yyyy') expiration_date
        FROM qa_results_v qrv, mtl_system_items_b msib
       WHERE qrv.item_id = msib.inventory_item_id
         AND qrv.organization_id = msib.organization_id
         AND msib.segment1 = nvl(p_item, msib.segment1)
         AND qrv.receipt_num BETWEEN to_char(p_fm_receipt_num) AND
             to_char(p_to_receipt_num)
         AND qrv.plan_id = p_plan_id
         AND (qrv.character1 = p_lot OR p_lot IS NULL); -- Dalit A. RAviv 28/09/2014
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
  
  BEGIN
  
    retcode := 0;
  
    BEGIN
      plist_file := utl_file.fopen(location  => p_location,
                                   filename  => v_file_name,
                                   open_mode => 'w');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(v_file_name) ||
                        ' Is open For Writing ');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_mode THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_operation THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' || ltrim(v_file_name) ||
                   SQLERRM || chr(0);
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 2 THEN
      utl_file.put_line(plist_file,
                        '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                        '.BTW /D=' || v_bartender_txt_location || ' /prn="' ||
                        p_printer_name || '" /R=3 /P /DD' || chr(13));
      utl_file.put_line(plist_file, '%END%' || chr(13));
    ELSE
      fnd_file.put_line(fnd_file.log, errbuf);
      RETURN;
    END IF;
  
    FOR crs IN c LOOP
    
      utl_file.put_line(plist_file,
                        'RC' || crs.receipt_num || chr(9) || crs.segment1 ||
                        chr(9) || crs.lot || chr(9) || crs.approver_name ||
                        chr(9) || crs.expiration_date || chr(9) ||
                        crs.inspection_date || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || p_quantity || chr(13));
    END LOOP;
  
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Error in xxinv_bartender_pkg.print_inspection_release ' ||
                 SQLERRM;
    
      fnd_file.put_line(fnd_file.log, errbuf);
  END;

  --------------------------------------------------------------------
  --  name:            print_inspection_release_m_r
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/10/2013
  --------------------------------------------------------------------
  --  purpose :        REP354 - Receiving Stickers - CR1050
  --                   During the Receiving process in the System Plan in Rehovot,
  --                   after the material pass quality check, there is a need to
  --                   issue Inspection Release Sticker.
  --                   The sticker is printed by the QC worker after entering the
  --                   inspection data to the collection plan in Oracle
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/10/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE print_inspection_release_m_r(errbuf           OUT VARCHAR2,
                                         retcode          OUT VARCHAR2,
                                         p_stiker_name    IN VARCHAR2,
                                         p_printer_name   IN VARCHAR2,
                                         p_fm_receipt_num IN NUMBER,
                                         p_to_receipt_num IN NUMBER,
                                         --p_org_id         in number,--
                                         p_quantity IN NUMBER,
                                         p_item     IN VARCHAR2,
                                         p_location IN VARCHAR2,
                                         p_plan_id  IN NUMBER) IS
  
    CURSOR c IS
      SELECT msib.segment1 item,
             qrv.character2 description,
             qrv.character1 lot,
             qrv.character4 approver_name,
             qrv.receipt_num,
             to_date(qrv.transaction_date, 'DD-MON-YYYY') inspection_date
        FROM qa_results_v qrv, mtl_system_items_b msib
       WHERE qrv.item_id = msib.inventory_item_id
         AND qrv.organization_id = msib.organization_id
         AND (qrv.character5 = 'Accept' OR qrv.character12 = 'Accept')
         AND qrv.plan_id = p_plan_id -- 17102
         AND qrv.receipt_num BETWEEN to_char(p_fm_receipt_num) AND
             to_char(p_to_receipt_num)
         AND (msib.segment1 = p_item OR p_item IS NULL);
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
  
  BEGIN
    retcode := 0;
    errbuf  := NULL;
    BEGIN
      plist_file := utl_file.fopen(location  => p_location,
                                   filename  => v_file_name,
                                   open_mode => 'w');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(v_file_name) ||
                        ' Is open For Writing ');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_mode THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_operation THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' || ltrim(v_file_name) ||
                   SQLERRM || chr(0);
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
    END;
  
    IF nvl(retcode, 0) <> 2 THEN
      utl_file.put_line(plist_file,
                        '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                        '.BTW /D=' || v_bartender_txt_location || ' /prn="' ||
                        p_printer_name || '" /R=3 /P /DD' || chr(13));
      utl_file.put_line(plist_file, '%END%' || chr(13));
    ELSE
      fnd_file.put_line(fnd_file.log, errbuf);
      RETURN;
    END IF;
  
    FOR crs IN c LOOP
      -- chr(9) = tab
      utl_file.put_line(plist_file,
                        crs.item || chr(9) || crs.description || chr(9) ||
                        crs.lot || chr(9) || crs.approver_name || chr(9) || 'RC' ||
                        crs.receipt_num || chr(9) || crs.inspection_date ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        p_quantity || chr(13));
    END LOOP;
  
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Error in xxinv_bartender_pkg.print_inspection_release_m_r ' ||
                 SQLERRM;
    
      fnd_file.put_line(fnd_file.log, errbuf);
  END print_inspection_release_m_r;

  --------------------------------------------------------------------
  --  name:            print_inventory_locator
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   05/11/2013
  --------------------------------------------------------------------
  --  purpose :        cust20 - Receiving Stickers - CR1079
  --                   Warehouse need to issue a Subinventory and Locator label with their Barcode in order
  --                   to use more efficiently the Barcode device. Most of the Warehouse processes are needed
  --                   to enter the Subinventory and Locator values. In order to enter them more easily,
  --                   WH would like to have a Subinventory and Locator label to be stick in every Locator and
  --                   to be scan when performing mobile WH processes.

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/11/2013  yuval tal         initial build
  --------------------------------------------------------------------
  PROCEDURE print_subinventory_locator(errbuf            OUT VARCHAR2,
                                       retcode           OUT VARCHAR2,
                                       p_stiker_name     IN VARCHAR2,
                                       p_printer_name    IN VARCHAR2,
                                       p_location        IN VARCHAR2,
                                       p_copies          IN NUMBER,
                                       p_organization_id IN NUMBER,
                                       p_subinventory    IN VARCHAR2,
                                       p_locator_id      IN VARCHAR2
                                       
                                       ) IS
  
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
  
    CURSOR c IS
      SELECT milk.subinventory_code, milk.concatenated_segments
      
        FROM mtl_item_locations_kfv milk
       WHERE milk.subinventory_code = p_subinventory
         AND nvl(milk.inventory_location_id, -1) =
             nvl(p_locator_id, nvl(inventory_location_id, -1))
         AND milk.enabled_flag = 'Y'
         AND SYSDATE < nvl(milk.disable_date, SYSDATE + 1)
         AND milk.organization_id = p_organization_id
       ORDER BY milk.concatenated_segments;
  
  BEGIN
  
    retcode := 0;
    errbuf  := NULL;
    BEGIN
      plist_file := utl_file.fopen(location  => p_location,
                                   filename  => v_file_name,
                                   open_mode => 'w');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(v_file_name) ||
                        ' Is open For Writing ');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_mode THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_operation THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' || ltrim(v_file_name) ||
                   SQLERRM || chr(0);
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
    END;
  
    fnd_file.put_line(fnd_file.log, 'errbuf= ' || errbuf);
  
    IF nvl(retcode, 0) <> 2 THEN
      utl_file.put_line(plist_file,
                        '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                        '.BTW /D=' || v_bartender_txt_location || ' /prn="' ||
                        p_printer_name || '" /R=3 /P /DD' || chr(13));
      utl_file.put_line(plist_file, '%END%' || chr(13));
    ELSE
      fnd_file.put_line(fnd_file.log, errbuf);
      RETURN;
    END IF;
  
    -- chr(9) = tab
    FOR i IN c LOOP
    
      utl_file.put_line(plist_file,
                        p_subinventory || chr(9) || i.concatenated_segments ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                        chr(9) || chr(9) || chr(9) || chr(9) || p_copies ||
                        chr(13));
    
    END LOOP;
  
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Error in xxinv_bartender_pkg.print_subinventory_locator ' ||
                 SQLERRM;
    
      fnd_file.put_line(fnd_file.log, errbuf);
  END;

  --------------------------------------------------------------------
  --  name:            open_file
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   25/11/2013
  --------------------------------------------------------------------
  --  purpose :

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25/11/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE open_file(errbuf         OUT VARCHAR2,
                      retcode        OUT VARCHAR2,
                      p_stiker_name  IN VARCHAR2,
                      p_printer_name IN VARCHAR2,
                      p_location     IN VARCHAR2,
                      p_plist_file   OUT utl_file.file_type) IS
  
    l_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
    plist_file  utl_file.file_type;
  BEGIN
  
    retcode := 0;
    errbuf  := NULL;
    BEGIN
      plist_file := utl_file.fopen(location  => p_location,
                                   filename  => l_file_name,
                                   open_mode => 'w');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(l_file_name) ||
                        ' Is open For Writing ');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' || ltrim(l_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_mode THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' || ltrim(l_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_operation THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' || ltrim(l_file_name) ||
                   SQLERRM || chr(0);
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := errbuf || 'Other for ' || ltrim(l_file_name) || chr(0);
    END;
  
    fnd_file.put_line(fnd_file.log, 'errbuf= ' || errbuf);
  
    IF nvl(retcode, 0) <> 2 THEN
      utl_file.put_line(plist_file,
                        '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name ||
                        '.BTW /D=' || v_bartender_txt_location || ' /prn="' ||
                        p_printer_name || '" /R=3 /P /DD' || chr(13));
      utl_file.put_line(plist_file, '%END%' || chr(13));
    
      p_plist_file := plist_file;
    ELSE
      fnd_file.put_line(fnd_file.log, errbuf);
      RETURN;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'General error -' || substr(SQLERRM, 1, 240);
  END open_file;

  --------------------------------------------------------------------
  --  name:            print_ssys_rcv
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   25/11/2013
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25/11/2013  Dalit A. Raviv    initial build
  --  1.1  29/04/2014  Dalit A. Raviv    Add Locator info.(program XXPO Purchasing Receiving Label)
  --  1.2  27.12.17    yuval tal         CHG0035037 - add Receipt Routing info
  --  2.0  30-Apr-2019 Hubert, Eric      CHG0045604:
  --                                        Display locator for related supplier kanban
  --                                        Allow labels for internal orders.
  --                                        Sub procedure to return up to two suggested put-away locations
  --                                        Added ABC Class for Item
  --                                        Write data file lines to concurrent request log file.
  -- 2.1   23/062019   Roman W.          CHG0045604 - removed extra chr(9)
  --------------------------------------------------------------------
  PROCEDURE print_ssys_rcv(errbuf         OUT VARCHAR2,
                           retcode        OUT VARCHAR2,
                           p_stikcer_name IN VARCHAR2,
                           p_printer_name IN VARCHAR2,
                           p_location     IN VARCHAR2,
                           p_copies       IN NUMBER,
                           p_rec_num      IN VARCHAR2) IS
  
    /* Declare variables for storing the label's text string (CHG00xxxxx) */
    l_label_text_01 VARCHAR2(4000);
    l_label_text_02 VARCHAR2(4000);
    l_location_1    VARCHAR2(100);
    l_location_2    VARCHAR2(100);
  
    CURSOR c IS
      SELECT DISTINCT rsh.receipt_num,
                      rsl.line_num,
                      rsl.routing_header_id, --CHG0035037
                      rsl.to_organization_id,
                      rsh.creation_date              transaction_date,
                      msib.segment1                  item_number,
                      rrav.vendor_name,
                      msib.description               item_description,
                      msib.revision_qty_control_code revision,
                      rsl.quantity_received,
                      rsl.unit_of_measure,
                      rsl.to_subinventory            subinventory,
                      pha.segment1                   po_num,
                      msib.inventory_item_id,
                      rsl.ship_to_location_id --CHG0045604
        FROM mtl_system_items_b     msib,
             rcv_shipment_lines     rsl,
             rcv_shipment_headers_v rsh,
             rcv_receipts_all_v     rrav,
             po_headers             pha
       WHERE msib.inventory_item_id = rsl.item_id
         AND rsl.to_organization_id = msib.organization_id
         AND rsl.po_header_id = pha.po_header_id(+) --CHG0045604: changed to outer join so internal orders wouldn't be excluded
         AND rsh.receipt_num = rrav.receipt_num(+) --CHG0045604: changed to outer join so internal orders wouldn't be excluded
         AND rsh.shipment_header_id = rsl.shipment_header_id
         AND rrav.shipment_header_id(+) = rsh.shipment_header_id --CHG0045604: changed to outer join so internal orders wouldn't be excluded
         AND rsh.receipt_num = p_rec_num
         AND quantity_received > 0 --CHG0045604
       ORDER BY line_num --CHG0045604
      ;
  
    l_err_code VARCHAR2(100);
    l_err_desc VARCHAR2(2500);
    plist_file utl_file.file_type;
  
    l_location1 VARCHAR2(1000) := NULL;
    l_location2 VARCHAR2(1000) := NULL;
    l_rout_desc VARCHAR2(500);
    l_abc_class mtl_abc_classes.abc_class_name%TYPE; --CHG0045604
  
    /* CHG0045604: private function within procedure to return the ABC Class Name
       for the item, using the most recently-created ABC Assignment Group
       for the org.
    */
    FUNCTION item_abc_class(p_item_id         IN NUMBER,
                            p_organization_id IN NUMBER) RETURN VARCHAR2 IS
      l_result mtl_abc_classes.abc_class_name%TYPE;
    BEGIN
    
      SELECT
      --maag.assignment_group_id
      --,maag.assignment_group_name
      --,maa.inventory_item_id
      --,maa.abc_class_id
       mac.abc_class_name
      --,mac.description
        INTO l_result
        FROM (SELECT row_number() over(ORDER BY creation_date DESC) rownumber,
                     maag.*
                FROM mtl_abc_assignment_groups maag
               WHERE organization_id = p_organization_id) maag
       INNER JOIN mtl_abc_assignments maa
          ON (maa.assignment_group_id = maag.assignment_group_id AND
             maag.rownumber = 1 --Most recently created ABC assignment group
             )
       INNER JOIN mtl_abc_classes mac
          ON (mac.abc_class_id = maa.abc_class_id)
       WHERE nvl(mac.disable_date, SYSDATE + 1) > SYSDATE
         AND maa.inventory_item_id = p_item_id;
    
      RETURN l_result;
    
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END item_abc_class;
  
    /* CHG0045604: private function within procedure to return the suggested put-away
       subinventory/locators for the item.  This reduces the complexity of the SQL
       in the c_loc cursor.
    */
    ---------------------------------------------------------------------------
    PROCEDURE suggested_put_away_locations(p_item_id         IN NUMBER,
                                           p_organization_id IN NUMBER,
                                           p_location_id     IN NUMBER,
                                           p_location_1      OUT VARCHAR2,
                                           p_location_2      OUT VARCHAR2) IS
    
      CURSOR loc_kb(p_item_id         IN NUMBER,
                    p_organization_id IN NUMBER,
                    p_location_id     IN NUMBER) IS
      
        WITH sq_kanban_cards AS
         (SELECT mkc.inventory_item_id,
                 mkc.organization_id,
                 mkc.kanban_card_number,
                 mkc.card_status,
                 mkc.locator_id kb_locator_id,
                 mkc.subinventory_name,
                 milk.concatenated_segments kb_concatenated_segments,
                 mkps.pull_sequence_id,
                 mkps.attribute_category ps_attribute_category,
                 mkps.attribute1 fdt_subinventory,
                 milk2.inventory_location_id fdt_locator_id,
                 milk2.concatenated_segments fdt_locator,
                 coalesce(mkps.attribute1, mkc.subinventory_name) suggested_subinventory --Check for 2-stage first, otherwise use standard subinventory
                ,
                 CASE
                   WHEN mkps.attribute1 IS NOT NULL THEN --Check for 2-stage first, otherwise use standard subinventory/locator
                    coalesce(milk2.concatenated_segments, mkps.attribute1)
                   ELSE
                   
                    coalesce(milk.concatenated_segments,
                             mkc.subinventory_name)
                 END suggested_location
            FROM mtl_kanban_cards mkc
          
          /* Join to get the Pull Sequence (CHG0043792)*/
           INNER JOIN mtl_kanban_pull_sequences mkps
              ON (mkc.pull_sequence_id = mkps.pull_sequence_id)
          
          /* Join Kanban Cards to Stock Locators */
            LEFT JOIN mtl_item_locations_kfv milk
              ON (milk.inventory_location_id = mkc.locator_id)
          
          /* Join Pull Sequences to Stock Locators via Pull Sequence DFFs*/
            LEFT JOIN mtl_item_locations_kfv milk2
              ON (milk2.subinventory_code = mkps.attribute1 AND
                 milk2.inventory_location_id = mkps.attribute2 AND
                 mkps.attribute_category = 'TWO_STAGE_KANBAN' --Context value to denote two-stage kanban on Pull Sequences
                 )
           WHERE 1 = 1
             AND mkc.inventory_item_id = p_item_id
             AND mkc.organization_id = p_organization_id
             AND card_status IN (1, 2) --Active, Hold
          )
        
        SELECT DISTINCT suggested_location,
                        row_number() over(ORDER BY suggested_location) current_row,
                        COUNT(*) over() total_rows
          FROM sq_kanban_cards
         WHERE
        /* Only return kanban locations for subinventories in the value set below. */
         suggested_subinventory IN
         (SELECT fv.flex_value
            FROM fnd_flex_values_vl fv, fnd_flex_value_sets fvs
           WHERE fv.flex_value_set_id = fvs.flex_value_set_id
             AND fvs.flex_value_set_name LIKE
                 'XXINV_US_SUBINV_INCLUD_IN_LABEL'
             AND nvl(fv.enabled_flag, 'N') = 'Y'
             AND trunc(SYSDATE) BETWEEN
                 nvl(fv.start_date_active, SYSDATE - 1) AND
                 nvl(fv.end_date_active, SYSDATE + 1))
         AND
        /* Restrict to subinventories that have the same location as the receipt line.
           This is done because UME does receiving at multiple locations and
           only the subinventories relevant for that location should be presented
           on the receiving label.
        */
         suggested_subinventory IN
         (SELECT secondary_inventory_name
            FROM mtl_secondary_inventories
           WHERE location_id = p_location_id)
         GROUP BY suggested_location
         ORDER BY suggested_location;
    
      CURSOR loc_ohq(p_item_id         IN NUMBER,
                     p_organization_id IN NUMBER,
                     p_location_id     IN NUMBER --CHG0045604
                     ) IS
        SELECT subinventory_code,
               locator,
               inventory_item_id,
               item,
               SUM(transaction_quantity) qty
          FROM (SELECT x.inventory_item_id,
                       x.subinventory_code       subinventory_code,
                       x.locator_id,
                       mil.concatenated_segments locator,
                       x.transaction_quantity,
                       x.organization_id,
                       x.item
                  FROM mtl_item_locations_kfv mil,
                       (SELECT q.organization_id,
                               q.inventory_item_id inventory_item_id,
                               q.subinventory_code subinventory_code,
                               q.locator_id        locator_id,
                               q.on_hand           transaction_quantity,
                               b.segment1          item
                          FROM mtl_onhand_serial_v           q,
                               mtl_secondary_inventories     i,
                               mtl_secondary_inventories_dfv d,
                               mtl_system_items_b            b
                         WHERE i.organization_id = q.organization_id
                           AND i.secondary_inventory_name =
                               q.subinventory_code
                           AND d.row_id = i.rowid
                           AND b.organization_id = q.organization_id
                           AND b.inventory_item_id = q.inventory_item_id
                           AND i.locator_type = 2 --Subinventory must have predefined locator control CHG0045604
                        UNION ALL
                        SELECT q.organization_id,
                               q.inventory_item_id    inventory_item_id,
                               q.subinventory_code,
                               q.locator_id           locator_id,
                               q.transaction_quantity transaction_quantity,
                               b.segment1             item
                          FROM mtl_onhand_quantities_detail  q,
                               mtl_system_items_b            b,
                               mtl_secondary_inventories     i,
                               mtl_secondary_inventories_dfv d
                         WHERE b.organization_id = q.organization_id
                           AND b.inventory_item_id = q.inventory_item_id
                           AND b.serial_number_control_code = 1
                           AND i.organization_id = q.organization_id
                           AND i.secondary_inventory_name =
                               q.subinventory_code
                           AND d.row_id = i.rowid
                           AND i.locator_type = 2 --Subinventory must have predefined locator control CHG0045604
                        ) x
                 WHERE x.locator_id = mil.inventory_location_id(+)
                   AND x.organization_id = mil.organization_id(+)
                   AND x.organization_id = p_organization_id -- <Param>
                )
         WHERE subinventory_code IN
               (SELECT fv.flex_value
                  FROM fnd_flex_values_vl fv, fnd_flex_value_sets fvs
                 WHERE fv.flex_value_set_id = fvs.flex_value_set_id
                   AND fvs.flex_value_set_name LIKE
                       'XXINV_US_SUBINV_INCLUD_IN_LABEL'
                   AND nvl(fv.enabled_flag, 'N') = 'Y'
                   AND trunc(SYSDATE) BETWEEN
                       nvl(fv.start_date_active, SYSDATE - 1) AND
                       nvl(fv.end_date_active, SYSDATE + 1))
           AND
              /* Restrict to subinventories that have the same location as the receipt line.
                 This is done because UME does receiving at multiple locations and
                 only the subinventories relevant for that location should be presented
                 on the receiving label. (CHG0045604)
              */
               subinventory_code IN
               (SELECT secondary_inventory_name
                  FROM mtl_secondary_inventories
                 WHERE location_id = p_location_id)
              --and   subinventory_code = p_subinventory -- <Param>
           AND inventory_item_id = p_item_id -- <Param>
         GROUP BY subinventory_code, locator, inventory_item_id, item
         ORDER BY inventory_item_id,
                  --            decode(subinventory_code, 'RAW-OPS', 1, 2),
                  qty DESC,
                  locator;
    
      l_card_count NUMBER; --Active kanban cards
      l_count      NUMBER := 0;
      l_location_1 VARCHAR2(100);
      l_location_2 VARCHAR2(100);
    
    BEGIN
    
      /* Get OHQ locators for item in designated subinventories.*/
      l_count := 0;
    
      FOR loc_r IN loc_ohq(p_item_id,
                           p_organization_id,
                           p_location_id --CHG______
                           ) LOOP
        IF (l_count = 0) THEN
          IF loc_r.locator IS NOT NULL THEN
            l_location_1 := loc_r.locator || ': Qty ' || loc_r.qty;
          ELSE
            l_location_1 := loc_r.subinventory_code || ': Qty ' ||
                            loc_r.qty;
          END IF;
        END IF;
      
        IF (l_count <> 0) THEN
          IF loc_r.locator IS NOT NULL THEN
            l_location_2 := loc_r.locator || ': Qty ' || loc_r.qty;
          ELSE
            l_location_2 := loc_r.subinventory_code || ': Qty ' ||
                            loc_r.qty;
          END IF;
        END IF;
      
        l_count := l_count + 1;
      
        IF l_count = 2 THEN
          EXIT;
        END IF;
      
      END LOOP;
    
      l_count := 0;
    
      IF l_location_1 IS NULL THEN
        --Nothing was found for OHQ
        /* Get list of relevant kanban card deliver-to subinventory/locators. */
        FOR kb_r IN loc_kb(p_item_id, p_organization_id, p_location_id) LOOP
          IF (l_count = 0) THEN
            l_location_1 := kb_r.suggested_location || ' (KB ' ||
                            kb_r.current_row || '/' || kb_r.total_rows || ')';
          END IF;
        
          IF (l_count <> 0) THEN
            l_location_2 := kb_r.suggested_location || ' (KB ' ||
                            kb_r.current_row || '/' || kb_r.total_rows || ')';
          END IF;
        
          l_count := l_count + 1;
        
          IF l_count = 2 THEN
            EXIT;
          END IF;
        END LOOP;
      END IF;
    
      --dbms_output.put_line ('l_location_1: ' || l_location_1);
      --dbms_output.put_line ('l_location_2: ' || l_location_2);
    
      p_location_1 := l_location_1;
      p_location_2 := l_location_2;
    
    EXCEPTION
      WHEN OTHERS THEN
        p_location_1 := NULL;
        p_location_2 := NULL;
      
    END suggested_put_away_locations;
  
  BEGIN
  
    retcode := 0;
    errbuf  := NULL;
  
    --dbms_output.put_line('-before loop');
  
    FOR i IN c LOOP
      --dbms_output.put_line('-in loop');
      l_err_desc  := 0;
      l_err_code  := NULL;
      l_rout_desc := xxobjt_general_utils_pkg.get_lookup_meaning('RCV_ROUTING_HEADERS',
                                                                 i.routing_header_id); -- CHG0035037
    
      /* Get Items ABC class (CHG0045604)*/
      l_abc_class := item_abc_class(p_item_id         => i.inventory_item_id,
                                    p_organization_id => i.to_organization_id);
    
      /* Get two suggested put-away locations (CHG0045604)*/
      suggested_put_away_locations(p_item_id         => i.inventory_item_id,
                                   p_organization_id => i.to_organization_id,
                                   p_location_id     => i.ship_to_location_id,
                                   p_location_1      => l_location_1,
                                   p_location_2      => l_location_2);
    
      -- end 29/04/2014
      open_file(errbuf         => l_err_desc, -- o v
                retcode        => l_err_code, -- o v
                p_stiker_name  => p_stikcer_name, -- i v
                p_printer_name => p_printer_name, -- i v
                p_location     => p_location, -- i v
                p_plist_file   => plist_file -- o utl_file.file_type
                );
    
      IF l_err_code = 0 THEN
      
        l_label_text_01 :=  --CHG0045604 build label text sting for first label and store in a variable.
         i.receipt_num || chr(9) || i.line_num || chr(9) ||
                           i.transaction_date || chr(9) || i.item_number ||
                           chr(9) || i.vendor_name || chr(9) ||
                           i.item_description || chr(9) || i.revision ||
                           chr(9) || i.quantity_received || chr(9) ||
                           i.unit_of_measure || chr(9) || i.subinventory ||
                           chr(9) || i.po_num || chr(9) || -- 11
                           l_location_1 || chr(9) || l_location_2 || chr(9) ||
                           l_rout_desc || chr(9) || l_abc_class --CHG0045604
                           || chr(9) || chr(9) || chr(9) || chr(9) ||
                           chr(9) || chr(9) || p_copies || chr(13);
        dbms_output.put_line('l_label_text_01: ' || l_label_text_01);
        utl_file.put_line(plist_file, l_label_text_01); --CHG0045604
      
        /* Write the text for first label to concurrent request log. (CHG0045604)*/
        fnd_file.put(fnd_file.log, 'Text for first label:');
        fnd_file.put(fnd_file.log, l_label_text_01);
      
        -- close file
        IF utl_file.is_open(plist_file) THEN
          utl_file.fclose(plist_file);
        END IF;
      
        -- print second label
        open_file(errbuf         => l_err_desc, -- o v
                  retcode        => l_err_code, -- o v
                  p_stiker_name  => p_stikcer_name || '1', -- i v
                  p_printer_name => p_printer_name, -- i v
                  p_location     => p_location, -- i v
                  p_plist_file   => plist_file -- o utl_file.file_type
                  );
      
        IF l_err_code = 0 THEN
        
          l_label_text_02 :=  --CHG0045604 build label text sting for second label and store in a variable.
           i.item_number || chr(9) || -- 1
                             chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                             chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                             chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                             chr(9) || chr(9) || chr(9) || chr(9) || -- 19
                             p_copies || chr(13);
        
          utl_file.put_line(plist_file, l_label_text_02); --CHG0045604
        
          /* Write the text for second label to concurrent request log. (CHG0045604)*/
          fnd_file.put(fnd_file.log, 'Text for second label:');
          fnd_file.put(fnd_file.log, l_label_text_02);
        
          -- close file
          IF utl_file.is_open(plist_file) THEN
            utl_file.fclose(plist_file);
          END IF;
        ELSE
          IF utl_file.is_open(plist_file) THEN
            utl_file.fclose(plist_file);
          END IF;
          retcode := l_err_code;
          errbuf  := l_err_desc;
          EXIT;
        END IF;
      
      ELSE
        IF utl_file.is_open(plist_file) THEN
          utl_file.fclose(plist_file);
        END IF;
        retcode := l_err_code;
        errbuf  := l_err_desc;
        EXIT;
      END IF;
      dbms_lock.sleep(2);
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Error in xxinv_bartender_pkg.print_ssys_rcv ' || SQLERRM;
    
      fnd_file.put_line(fnd_file.log, errbuf);
  END print_ssys_rcv;

  --------------------------------------------------------------------
  --  name:            print_auto_label_lot_bottling
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/01/2014
  --------------------------------------------------------------------
  --  purpose :        CR 1259  print_auto_label_lot_bottling
  --                   Build a new concurrent request that will print the sticker
  --                   through the new auto labeling machine.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/01/2014  Dalit A. Raviv    initial build
  --  1.1  31/10/2019  Bellona(TCS)      CHG0046734 spilt p_botteling_lot input into lot number and item id.
  --------------------------------------------------------------------
  PROCEDURE print_auto_label_lot_bottling(errbuf            OUT VARCHAR2,
                                          retcode           OUT VARCHAR2,
                                          p_stikcer_name    IN VARCHAR2, -- 041C1E1Q1
                                          p_printer_ip      IN VARCHAR2, -- 10.11.90.210
                                          p_botteling_lot   IN VARCHAR2,
                                          p_organization_id IN NUMBER) IS
  
    CURSOR pop_c(p_lot IN VARCHAR2, p_item_id IN NUMBER) IS
      SELECT mln.lot_number,
             msib.segment1 item_number,
             msib.description,
             to_char(mln.expiration_date, 'DD-MON-YYYY') exp_date
        FROM mtl_lot_numbers mln, mtl_system_items_b msib
       WHERE msib.inventory_item_id = mln.inventory_item_id
         AND msib.organization_id = mln.organization_id
         AND mln.lot_number = p_lot --p_botteling_lot       --CHG0046734 replaced p_botteling_lot with l_lot
         AND mln.inventory_item_id = p_item_id --CHG0046734
         AND mln.organization_id = p_organization_id;
  
    CURSOR str_c(p_str IN VARCHAR2) IS
      SELECT regexp_substr(p_str, '[^ ]+', 1, LEVEL) str
        FROM dual
      CONNECT BY regexp_substr(p_str, '[^ ]+', 1, LEVEL) IS NOT NULL;
    -- send string to ink printer by tcp connection
    c      utl_tcp.connection; -- TCP/IP connection to the web server
    retval PLS_INTEGER;
    --l_result             varchar2(32000);
    l_printer_result     RAW(5);
    l_printer_result_str VARCHAR2(500);
    l_string             VARCHAR2(500);
    l_desc1              VARCHAR2(500) := NULL;
    l_desc2              VARCHAR2(500) := NULL;
    l_flag               VARCHAR2(5) := 'N';
    l_lot                mtl_lot_numbers.lot_number%TYPE; --CHG0046734
    l_item_id            mtl_lot_numbers.inventory_item_id%TYPE; --CHG0046734
  
  BEGIN
    retcode := 0;
    errbuf  := NULL;
  
    c := utl_tcp.open_connection(remote_host => p_printer_ip,
                                 remote_port => 9100,
                                 charset     => 'US7ASCII');
  
    --CHG0046734 splitting p_bot_lot input parameter into lot number and item id
    l_lot     := substr(p_botteling_lot, 0, instr(p_botteling_lot, '|') - 1);
    l_item_id := substr(p_botteling_lot,
                        instr(p_botteling_lot, '|') + 1,
                        length(p_botteling_lot));
  
    message(' l_lot: ' || l_lot);
    message('l_item_id: ' || l_item_id);
    --
    -- p_stikcer_name - '041C1E1Q1'
    FOR pop_r IN pop_c(l_lot, l_item_id) LOOP
      FOR str_r IN str_c(pop_r.description) LOOP
        IF l_desc1 IS NULL THEN
          l_desc1 := str_r.str;
        ELSE
          IF length(l_desc1 || ' ' || str_r.str) <= 28 AND l_flag = 'N' THEN
            l_desc1 := l_desc1 || ' ' || str_r.str;
          ELSE
            IF l_desc2 IS NULL THEN
              l_desc2 := str_r.str;
              l_flag  := 'Y';
            ELSE
              l_desc2 := l_desc2 || ' ' || str_r.str;
            END IF;
          END IF;
        END IF;
      END LOOP;
      -- l_string := chr(2)||'041C1E1Q1'||chr(23)|| 'DSOBJ-040255'
      --   ||chr(10)||'PACK OF 2 SUPPORT, FullCure 705'||chr(10)
      --   ||'10689-04020-2004'||chr(10)||'15-May-2015??'||chr(13);
    
      l_string := chr(2) || p_stikcer_name || chr(23) || 'D' ||
                  pop_r.item_number || chr(10) || l_desc1 || chr(10) ||
                  nvl(l_desc2, ' ') || chr(10) || pop_r.lot_number ||
                  chr(10) || pop_r.exp_date || '??' || chr(13);
      EXIT;
    END LOOP;
  
    dbms_output.put_line(' l_string ' || l_string);
    fnd_file.put_line(fnd_file.log, 'String - ' || l_string);
    -- send request
    retval := utl_tcp.write_text(c, l_string);
    --
    dbms_output.put_line('3');
    dbms_output.put_line('retval write text ' || retval);
    fnd_file.put_line(fnd_file.log, 'retval write text ' || retval);
    --
    utl_tcp.flush(c);
    --
    dbms_output.put_line('4');
    -- read result
    retval := utl_tcp.read_text(c, l_printer_result_str, 8, TRUE);
    --
    dbms_output.put_line('retval read text ' || retval);
    fnd_file.put_line(fnd_file.log, 'retval read text ' || retval);
    dbms_output.put_line('5');
    fnd_file.put_line(fnd_file.log, 'x-' || l_printer_result_str || '-x');
    --
    utl_tcp.close_connection(c);
    dbms_output.put_line('6');
    -- '0A41D6' this is the sign that if it return all is correct.
    IF l_printer_result_str = chr(1) || '0A41D6' || chr(13) THEN
      -- chr(1)||'0A41D6'||chr(13)
      dbms_output.put_line('ok!');
      fnd_file.put_line(fnd_file.log, 'ok! - Printer Successfully Set');
      retcode := 0;
      errbuf  := 'Printer Successfully Set';
      dbms_output.put_line('7');
    ELSE
      fnd_file.put_line(fnd_file.log,
                        'Printer Error Code' || l_printer_result || '.');
      errbuf  := 'Printer Error Code' || l_printer_result || '.';
      retcode := 2;
      dbms_output.put_line('8');
    END IF;
  EXCEPTION
    WHEN utl_tcp.network_error THEN
      retcode := 2;
      dbms_output.put_line('Connection Timeout');
      fnd_file.put_line(fnd_file.log, 'Connection Timeout');
      dbms_output.put_line('9');
    WHEN OTHERS THEN
      retcode := 2;
      dbms_output.put_line('Error: Unable to Set printer ' || SQLERRM);
      fnd_file.put_line(fnd_file.log,
                        'Error: Unable to Set printer ' || SQLERRM);
      dbms_output.put_line('10');
  END print_auto_label_lot_bottling;

  --------------------------------------------------------------------
  --  name:            print_ato_hasp_lbl
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   03.09.14

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/11/2013  yuval tal         CHG0032574 Development ATO Hasp Label - initial build
  --------------------------------------------------------------------
  PROCEDURE print_ato_hasp_lbl(errbuf         OUT VARCHAR2,
                               retcode        OUT VARCHAR2,
                               p_stiker_name  IN VARCHAR2,
                               p_printer_name IN VARCHAR2,
                               p_location     IN VARCHAR2,
                               p_copies       IN NUMBER,
                               p_item_code    IN VARCHAR2,
                               p_job_number   IN VARCHAR2) IS
    CURSOR c_serial IS
    
      SELECT qsrv.obj_serial_number
        FROM mtl_system_items_b msib1, -- cmp
             mtl_system_items_b msib2, -- cmp-s
             q_sn_reporting_v   qsrv
       WHERE qsrv.serial_component_item = msib1.segment1
         AND msib1.attribute9 = msib2.inventory_item_id
         AND msib2.serial_number_control_code != 1
         AND msib1.organization_id = 735
         AND msib2.organization_id = 735
         AND qsrv.serial_component_item LIKE 'CMP%'
         AND qsrv.plan_name = 'SN REPORTING'
         AND qsrv.job = p_job_number; --S/N from the ?Machine S/N? parameter
    plist_file  utl_file.file_type;
    v_file_name VARCHAR2(500) := p_stiker_name || '_' ||
                                 to_char(SYSDATE, 'RRMMDD_HH24MISS') ||
                                 '.txt';
  
    l_serial    VARCHAR2(100);
    l_str       VARCHAR2(250);
    l_str1      VARCHAR2(250);
    l_item_desc VARCHAR2(340);
  BEGIN
  
    retcode := 0;
    errbuf  := NULL;
    BEGIN
      plist_file := utl_file.fopen(location  => p_location,
                                   filename  => v_file_name,
                                   open_mode => 'w');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(v_file_name) ||
                        ' Is open For Writing ');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_mode THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' || ltrim(v_file_name) ||
                   chr(0);
      WHEN utl_file.invalid_operation THEN
        retcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' || ltrim(v_file_name) ||
                   SQLERRM || chr(0);
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := errbuf || 'Other for ' || ltrim(v_file_name) || chr(0);
    END;
  
    --
    BEGIN
      SELECT t.description
        INTO l_item_desc
        FROM mtl_system_items_b t
       WHERE t.organization_id = 91
         AND t.segment1 = p_item_code;
    EXCEPTION
      WHEN OTHERS THEN
        errbuf  := 'No description found for item ' || p_item_code;
        retcode := '2';
        RETURN;
    END;
  
    --
    OPEN c_serial;
    FETCH c_serial
      INTO l_serial;
    CLOSE c_serial;
  
    IF nvl(retcode, 0) <> 2 THEN
    
      l_str := '%BTW% /AF=C:\OA_Bar_Tender\' || p_stiker_name || '.BTW /D=' ||
               v_bartender_txt_location || ' /prn="' || p_printer_name ||
               '" /R=3 /P ' || '/DD ' || chr(13);
      utl_file.put_line(plist_file, l_str);
    
      utl_file.put_line(plist_file, '%END%' || chr(13));
    
      /*   l_str1 := l_serial || chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
      chr(9) || chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
      chr(9) || chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
      chr(9) || chr(9) || chr(9) || p_copies || chr(13);*/
    
      l_str1 := p_item_code || chr(9) || l_item_desc || chr(9) ||
                p_job_number || chr(9) || l_serial || chr(9) || chr(9) ||
                chr(9) || chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                chr(9) || chr(9) || chr(9) || chr(9) || chr(9) || chr(9) ||
                chr(9) || chr(9) || chr(9) || p_copies || chr(13);
    
      utl_file.put_line(plist_file, l_str1);
    END IF;
  
    IF utl_file.is_open(plist_file) THEN
      utl_file.fclose(plist_file);
    
      fnd_file.put_line(fnd_file.log, 'Created file :' || v_file_name);
      fnd_file.put_line(fnd_file.log, '--------------------------------');
      fnd_file.put_line(fnd_file.log, l_str);
      fnd_file.put_line(fnd_file.log, l_str1);
    END IF;
  
  END print_ato_hasp_lbl;

END xxinv_bartender_pkg;
/
