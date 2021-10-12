create or replace package body xxpo_req_interfaces_pkg IS
  --------------------------------------------------------------------
  --  name:              XXPO_REQ_INTERFACES_PKG
  --  create by:
  --  Revision:
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :          CUST607 - support supplier approval process
  --------------------------------------------------------------------
  --  ver  date          name            desc
  --  1.x  31.12.12      yuval tal       cr644 po requisitions interface group by Sales Order
  --                                     add procedure manipulate_ssys_drop_ship
  --  1.1  23.12.13      yuval tal       CR870 - upload_internal_requisitions : standard cost adjustment remove Check Organization Location Association for Internal Order
  --  1.2  26/03/2014    Dalit A. Raviv  CHG0031662 - Upload Internal Requisition correct select from per_all_people_f
  --                                     upload_internal_requisitions
  -- 1.3 23.11.2015      Yuval tal       CHG0036436 upload_purchase_requisitions ,  Add vendor details to the planned purchase orders lines from ASCP
  -- 1.4 05.06.2017      Lingaraj(TCS)   CHG0040751 - add supporting data to the PO approval request
  --                                     New Column Added to the File which will be Mapped to po_requisitions_interface_all.JUSTIFICATION
  --  1.5  19.09.2018    Lingaraj        CHG0043850 - IR/ISO - Air shipments - reason (justification)
  --                                     New field Added for   "Air shipments - reason"
  --  1.6  8.Nov.18      Lingaraj        CHG0044329 - XX: Upload Purchase Requisitions - Bug fix
  --  1.7  06/01/2020    Bellona(TCS)    CHG0047106 - added new parameter in upload_internal_requisition  
  --------------------------------------------------------------------
  g_req_type     VARCHAR2(10);       --CHG0044329
  g_last_string  VARCHAR2(2000) :='';--CHG0044329
  g_string_tbl   t_string_arr;       --CHG0044329
  --------------------------------------------------------------------------
  -- Purpose:  log messages
  --
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  08.11.18  LINGARAJ        CHG0044329 - XX: Upload Purchase Requisitions - Bug fix
  --                                    log messalges
  ---------------------------------------------------------------------------
  PROCEDURE message(p_msg         VARCHAR2,
                    p_destination VARCHAR2 DEFAULT fnd_file.log) IS
  BEGIN
    /*IF fnd_global.conc_request_id = '-1' THEN
            dbms_output.put_line(p_msg);
        ELSE*/
            fnd_file.put_line(p_destination,p_msg);
    --END IF;
  END message;
  --------------------------------------------------------------------------
  -- Purpose:  Print Line Values for Each Column
  --
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  08.11.18  LINGARAJ        CHG0044329 - XX: Upload Purchase Requisitions - Bug fix
  ---------------------------------------------------------------------------
  PROCEDURE print_file_line(p_tbl_type t_string_arr)
  IS
  Begin
   If g_req_type != 'PUR_REQ' Then
      Return;
   End If;
     message('');
     message(rpad('Field Name',30,' ')||'|'||rpad('Field Value',60,' ')||'|'||'Field Length');
     message(Rpad('-',105,'-'));
     message(rpad('Segment1',30,' ')||'|'||rpad(nvl(p_tbl_type(1),' '),60,' ')||'|'||length(p_tbl_type(1)));
     message(rpad('Quantity',30,' ')||'|'||rpad(nvl(p_tbl_type(2),' '),60,' ')||'|'||length(p_tbl_type(2)));
     message(rpad('Need by Date',30,' ')||'|'||rpad(nvl(p_tbl_type(3),' '),60,' ')||'|'||length(p_tbl_type(3)));
     message(rpad('Operating Unit',30,' ')||'|'||rpad(nvl(p_tbl_type(4),' '),60,' ')||'|'||length(p_tbl_type(4)));
     message(rpad('Dest Organization',30,' ')||'|'||rpad(nvl(p_tbl_type(5),' '),60,' ')||'|'||length(p_tbl_type(5)));
     message(rpad('Source Organization',30,' ')||'|'||rpad(nvl(p_tbl_type(6),' '),60,' ')||'|'||length(p_tbl_type(6)));
     message(rpad('Location',30,' ')||'|'||rpad(nvl(p_tbl_type(7),' '),60,' ')||'|'||length(p_tbl_type(7)));
     message(rpad('UOM',30,' ')||'|'||rpad(nvl(p_tbl_type(8),' '),60,' ')||'|'||length(p_tbl_type(8)));
     message(rpad('Dest Subinventory',30,' ')||'|'||rpad(nvl(p_tbl_type(9),' '),60,' ')||'|'||length(p_tbl_type(9)));
     message(rpad('Source Subinventory',30,' ')||'|'||rpad(nvl(p_tbl_type(10),' '),60,' ')||'|'||length(p_tbl_type(10)));
     message(rpad('Requestor Lastname',30,' ')||'|'||rpad(nvl(p_tbl_type(11),' '),60,' ')||'|'||length(p_tbl_type(11)));
     message(rpad('Requestor Name',30,' ')||'|'||rpad(nvl(p_tbl_type(12),' '),60,' ')||'|'||length(p_tbl_type(12)));
     If g_req_type = 'PUR_REQ' Then
        message(rpad('Suggested Vendor Name',30,' ')||'|'||rpad(nvl(p_tbl_type(13),' '),60,' ')||'|'||length(p_tbl_type(13)));
        message(rpad('Suggested Vendor Site Name',30,' ')||'|'||rpad(nvl(p_tbl_type(14),' '),60,' ')||'|'||length(p_tbl_type(14)));
     End If;
     message(rpad('Justification',30,' ')||'|'||rpad(nvl(p_tbl_type(15),' '),60,' ')||'|'||length(p_tbl_type(15)));
     message(rpad('Air shipments reason',30,' ')||'|'||rpad(nvl(p_tbl_type(16),' '),60,' ')||'|'||length(p_tbl_type(16)));
     message(Rpad('-',105,'-'));
  End print_file_line;

  --------------------------------------------------------------------
  --  name:              manipulate_ssys_drop_ship
  --  create by:
  --  Revision:
  --------------------------------------------------------------------
  --  purpose:           avoid creation of one requisition for more than one sales order
  --                     for source  dropship and ssys items
  --                     proc will keep only lines from one order to  be  processed
  --                     other lines will be processed in next run of cuncurrent set

  --  In  Params:
  --  Out Params:
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.11.2012    yuval tal         initial build
  --------------------------------------------------------------------

  PROCEDURE manipulate_ssys_drop_ship(err_buff OUT VARCHAR2,
			  err_code OUT VARCHAR2,
			  p_org_id NUMBER) IS

    CURSOR c_req IS
      SELECT header_id,
	 COUNT(*)
      FROM   po_requisitions_interface_all pri,
	 mtl_item_categories_v         mic,
	 mtl_system_items_b            msib,
	 mtl_categories_b              mcb,
	 oe_drop_ship_sources          ods
      WHERE  pri.source_type_code = 'VENDOR'
      AND    pri.interface_source_code = 'ORDER ENTRY'
      AND    pri.org_id = p_org_id --fnd_global.org_id --fnd_profile.VALUE('DEFAULT_ORG_ID') --HK=103, DE=96
      AND    mic.inventory_item_id = msib.inventory_item_id
      AND    pri.item_id = msib.inventory_item_id
      AND    msib.organization_id = 91
      AND    mic.organization_id = 91
      AND    mcb.category_id = mic.category_id
      AND    mcb.attribute8 = 'FDM'
      AND    mic.category_set_name = 'Main Category Set'
      AND    pri.interface_source_line_id = ods.drop_ship_source_id
      AND    pri.process_flag IS NULL
      GROUP  BY ods.header_id;

  BEGIN

    err_buff := NULL;
    err_code := 0;

    fnd_file.put_line(fnd_file.log, 'Org id=' || p_org_id);
    -- update previous records
    UPDATE po_requisitions_interface_all t
    SET    t.process_flag = NULL
    WHERE  t.process_flag = 'ERROR'
    AND    t.org_id = p_org_id
    AND    t.program_id IS NULL;
    COMMIT;

    FOR i IN c_req LOOP
      /* dbms_output.put_line('xx header=' || i.header_id || ' ' ||
      c_req%ROWCOUNT);*/
      IF c_req%ROWCOUNT != 1 THEN
        fnd_file.put_line(fnd_file.log,
		  'Hold Order header id =' || i.header_id);
        -- eliminate other rows
        UPDATE po_requisitions_interface_all t
        SET    t.process_flag = 'ERROR'
        WHERE  t.process_flag IS NULL
        AND    t.program_id IS NULL
        AND    t.interface_source_line_id IN
	   (SELECT pri.interface_source_line_id
	     FROM   po_requisitions_interface_all pri,
		mtl_item_categories_v         mic,
		mtl_system_items_b            msib,
		mtl_categories_b              mcb,
		oe_drop_ship_sources          ods
	     WHERE  pri.source_type_code = 'VENDOR'
	     AND    pri.interface_source_code = 'ORDER ENTRY'
	     AND    pri.org_id = p_org_id --HK=103, DE=96
	     AND    mic.inventory_item_id = msib.inventory_item_id
	     AND    pri.item_id = msib.inventory_item_id
	     AND    msib.organization_id = 91
	     AND    mic.organization_id = 91
	     AND    mcb.category_id = mic.category_id
	     AND    mcb.attribute8 = 'FDM'
	     AND    mic.category_set_name = 'Main Category Set'
	     AND    pri.interface_source_line_id =
		ods.drop_ship_source_id
	     AND    ods.header_id = i.header_id);

        dbms_output.put_line('header=' || i.header_id || ' ' ||
		     SQL%ROWCOUNT);
      ELSE
        fnd_file.put_line(fnd_file.log,
		  'Ready to process: Order header id =' ||
		  i.header_id);
      END IF;
      COMMIT;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      err_buff := 'Error see log.';
      err_code := 2;
      fnd_file.put_line(fnd_file.log, 'Error:' || SQLERRM);
  END;

  --------------------------------------------------------------------------
  -- Purpose:  Split the String and return the Collumn Values
  --
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.x  31.12.12      yuval tal      cr644 po requisitions interface group by Sales Order
  --                                     add procedure manipulate_ssys_drop_ship
  --  1.1  08.11.18      LINGARAJ        CHG0044329 - XX: Upload Purchase Requisitions - Bug fix
  ---------------------------------------------------------------------------
  FUNCTION get_field_from_utl_file_line(p_line_str     IN VARCHAR2,
			    p_field_number IN NUMBER)
    RETURN VARCHAR2 IS
    v_last_comma_pos              NUMBER;
    v_pos                         NUMBER;
    v_num_of_columns_in_this_line NUMBER;
    v_start_pos                   NUMBER;
    v_next_comma_pos              NUMBER;
    v_length                      NUMBER;
    ----Start CHG0044329------------------------------
    l_string_tbl1                  t_string_arr;
    v_line_str                    VARCHAR2(4000) := p_line_str||',';
    v_string_start                VARCHAR2(10) := 'FALSE';
    v_tbl_index                   NUMBER:=0;
    v_str_pos                     NUMBER := 1;
    v_chr                         VARCHAR2(100);
    ----End CHG0044329----------------------------------
  BEGIN
    IF p_line_str IS NULL OR p_field_number IS NULL OR p_field_number <= 0 THEN
      RETURN '';
    END IF;
    -- Begin  CHG0044329
    If g_last_string = p_line_str Then
       Return g_string_tbl(p_field_number);
    Else
       g_last_string := p_line_str;
       For i in 1..16 Loop
         l_string_tbl1(i):= '';
       End Loop;
       g_string_tbl  := l_string_tbl1;
    End If;

    For i in 1..length(v_line_str) Loop
       v_chr:= substr(v_line_str,i,1);

      If v_chr = ',' And v_string_start = 'FALSE' Then

        v_tbl_index := v_tbl_index+1;

        g_string_tbl(v_tbl_index)
              := rtrim(Replace(trim(substr(v_line_str,v_str_pos,(i-v_str_pos))),'"',''),chr(13));
        v_str_pos := (i+1);

      ElSIF  v_chr = '"' Then
         v_string_start := (Case v_string_start When 'TRUE' THEN 'FALSE' ElSe 'TRUE' END);
      End If;

    End Loop;

    print_file_line(g_string_tbl);

    Return g_string_tbl(p_field_number);
    -- End  CHG0044329

    /* -- Commented for CHG0044329
    SELECT instr(p_line_str, ',', -1)
    INTO   v_last_comma_pos
    FROM   dual;

    IF v_last_comma_pos >= 1 THEN
      v_num_of_columns_in_this_line := 1;
      LOOP
        v_pos                         := instr(p_line_str,
			           ',',
			           1,
			           v_num_of_columns_in_this_line);
        v_num_of_columns_in_this_line := v_num_of_columns_in_this_line + 1;
        IF v_pos >= v_last_comma_pos OR v_pos = 0 THEN
          EXIT;
        END IF;
      END LOOP;
    END IF;

    -----return to_char(v_num_of_columns_in_this_line);

    IF p_field_number = v_num_of_columns_in_this_line THEN
      ----this is last column in this line
      RETURN rtrim(rtrim(substr(p_line_str, v_last_comma_pos + 1), ' '),
	       chr(13));
    ELSE
      IF p_field_number = 1 THEN
        v_start_pos := 1;
      ELSE
        v_start_pos := instr(p_line_str, ',', 1, p_field_number - 1) + 1;
      END IF;
      v_next_comma_pos := instr(p_line_str, ',', 1, p_field_number);
      v_length         := v_next_comma_pos - v_start_pos;
      RETURN ltrim(rtrim(substr(p_line_str, v_start_pos, v_length), ' '),
	       ' ');
    END IF;
  */
  EXCEPTION
    WHEN OTHERS THEN
      --CHG0044329
      fnd_file.put_line(fnd_file.log,'Unexpected Error in '||
                        'xxpo_req_interfaces_pkg.get_field_from_utl_file_line,'||
                        SQLERRM);
     raise_application_error(-20001,'An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);
  END get_field_from_utl_file_line;
  ------------------------------------------------------------------------------------------------
  -- upload_internal_requisitions
  --
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  23.12.13      yuval tal         CR870 - standard cost adjustment remove Check Organization Location Association for Internal Order
  --  1.1  26/03/2014    Dalit A. Raviv    CHG0031662 - Upload Internal Requisition correct select from per_all_people_f
  --  1.2  05.06.2017    Lingaraj(TCS)     CHG0040751 - add supporting data to the PO approval request
  --                                       New Column Added to the File which will be Mapped to po_requisitions_interface_all.JUSTIFICATION
  --  1.3  19.09.2018    Lingaraj          CHG0043850 - IR/ISO - Air shipments - reason (justification)
  --  1.4  06/01/2020    Bellona(TCS)      CHG0047106 - added new parameter  
  ------------------------------------------------------------------------------------------------
  PROCEDURE upload_internal_requisitions(errbuf                      OUT VARCHAR2,
			     errcode                     OUT VARCHAR2,
			     p_location                  IN VARCHAR2,
			     p_filename                  IN VARCHAR2,
			     p_ignore_first_headers_line IN VARCHAR2 DEFAULT 'N',
			     p_mode                      IN VARCHAR2,
			     p_launch_import_requisition IN VARCHAR2
                 ,p_submit_approval           IN VARCHAR2)IS       --CHG0047106

    CURSOR get_interface_org_id(p_batch_id NUMBER) IS
      SELECT por.org_id,
	 hrou.name operating_unit,
	 COUNT(*) num_of_rows_for_org_id
      FROM   po_requisitions_interface_all por,
	 hr_all_organization_units     hrou
      WHERE  por.interface_source_code = 'FILE'
      AND    por.batch_id = p_batch_id
      AND    por.org_id = hrou.organization_id
      GROUP  BY por.org_id,
	    hrou.name;

    v_request_id    NUMBER;
    v_step          VARCHAR2(1000);
    v_error_message VARCHAR2(1000);
    v_numeric_dummy NUMBER;
    stop_processing  EXCEPTION; --- missing parameter...or invalid parameter. stop (exit) procedure..
    validation_error EXCEPTION; ---the one of fields is invalid. stop processing for this line
    v_file                      utl_file.file_type;
    v_line                      VARCHAR2(7000);
    v_line_number               NUMBER := 0;
    v_line_is_valid_flag        VARCHAR2(1);
    v_valid_error_message       VARCHAR2(1000);
    v_num_of_non_valid_lines    NUMBER := 0;
    v_num_of_valid_lines        NUMBER := 0;
    v_num_of_success_ins_lines  NUMBER := 0;
    v_num_of_failured_ins_lines NUMBER := 0;
    v_read_code                 NUMBER;
    v_there_are_non_valid_rows  VARCHAR2(100) := 'N';
    l_app_short_name            VARCHAR2(100);
    v_batch_id                  NUMBER;
    ---UTL file fields-----
    v_segment1                 VARCHAR2(300); -----1---------  OBJ-13000
    v_quantity                 VARCHAR2(300); -----2---------
    v_need_by_date             VARCHAR2(300); -----3--------- DD-MON-YY
    v_operating_unit           VARCHAR2(300); -----4--------- OBJET US (OU)
    v_dest_oragnization_code   VARCHAR2(300); -----5--------- UOC
    v_source_oragnization_code VARCHAR2(300); -----6--------- WPI
    v_location                 VARCHAR2(300); -----7--------- UOC - US Objet Overall Chicago (IO)
    v_unit_of_measure          VARCHAR2(300); -----8--------- EA
    v_dest_subinventory        VARCHAR2(300); -----9---------
    v_source_subinventory      VARCHAR2(300); ----10---------
    v_comments                 VARCHAR2(300); ----11--------- Cancelled
    v_requestor                VARCHAR2(300); ----11---------   Gabriel 13/10
    v_req_lastname             VARCHAR2(300); ----12---------   Gabriel 14/10
    v_req_id                   NUMBER; -- Gabriel 15/10
    v_item_revision            VARCHAR2(3); -- Gabriel 15/10
    v_justification            VARCHAR2(480);--Added on 05.06.17 for CHG0040751
    v_air_shipment_reason      VARCHAR2(500);--Added on 19Sep2018 for CHG0043850
    -----Selected values-----------------
    v_qty                    NUMBER;
    v_dest_organization_id   NUMBER;
    v_source_organization_id NUMBER;
    v_org_id                 NUMBER;
    v_inventory_item_id      NUMBER;
    v_location_id            NUMBER;
    v_need_by_d              DATE;
    v_primary_uom_code       VARCHAR2(100); -- Added 13/10
    v_charge_account_id      NUMBER;
    v_user_employee_id       NUMBER;

  BEGIN
    g_req_type := 'INT_REQ';
    ---------------INTIALIZATION--------------------------------------
    fnd_global.apps_initialize(user_id      => fnd_global.user_id,
		       resp_id      => fnd_global.resp_id,
		       resp_appl_id => fnd_global.resp_appl_id);

    ----------------Get batch_id -------------------------------------
    v_batch_id := to_number(to_char(SYSDATE, 'HH24' || 'MI' || 'SS'));
    fnd_file.put_line(fnd_file.log,
	          '********************** batch_id=' || v_batch_id ||
	          ' ========================');

    -----Get curr user employee_id--------------
    BEGIN
      SELECT fu.employee_id
      INTO   v_user_employee_id
      FROM   fnd_user fu
      WHERE  fu.user_id = fnd_global.user_id;
    EXCEPTION
      WHEN no_data_found THEN
        v_user_employee_id := NULL;
    END;
    -----

    IF p_location IS NULL THEN
      fnd_file.put_line(fnd_file.log,
		'***************** MISSING PARAMETER p_location ****************');
      RAISE stop_processing;
    END IF;

    IF p_filename IS NULL THEN
      fnd_file.put_line(fnd_file.log,
		'***************** MISSING PARAMETER p_filename ****************');
      RAISE stop_processing;
    END IF;

    IF p_mode IS NULL THEN
      fnd_file.put_line(fnd_file.log,
		'***************** MISSING PARAMETER p_mode ****************');
      RAISE stop_processing;
    END IF;

    IF p_ignore_first_headers_line IS NULL THEN
      fnd_file.put_line(fnd_file.log,
		'***************** MISSING PARAMETER p_ignore_first_headers_line ****************');
      RAISE stop_processing;
    END IF;

    IF p_ignore_first_headers_line NOT IN ('Y', 'N') THEN
      fnd_file.put_line(fnd_file.log,
		'***************** PARAMETER p_ignore_first_headers_line SHOULD BE ''Y'' or ''N'' ****************');
      RAISE stop_processing;
    END IF;

    IF p_launch_import_requisition IS NULL THEN
      fnd_file.put_line(fnd_file.log,
		'***************** MISSING PARAMETER p_launch_import_requisition ****************');
      RAISE stop_processing;
    END IF;

    IF p_launch_import_requisition NOT IN ('Y', 'N') THEN
      fnd_file.put_line(fnd_file.log,
		'***************** PARAMETER p_launch_import_requisition SHOULD BE ''Y'' or ''N'' ****************');
      RAISE stop_processing;
    END IF;
    
    --CHG0047106 start
    IF p_submit_approval IS NULL THEN
      fnd_file.put_line(fnd_file.log,
		'***************** MISSING PARAMETER p_submit_approval ****************');
      RAISE stop_processing;
    END IF;    
    
    IF p_submit_approval NOT IN ('Y', 'N') THEN
      fnd_file.put_line(fnd_file.log,
		'***************** PARAMETER p_submit_approval SHOULD BE ''Y'' or ''N'' ****************');
      RAISE stop_processing;
    END IF;    
    --CHG0047106 end
    
    fnd_file.put_line(fnd_file.log,
	          '***************************************************************************');
    fnd_file.put_line(fnd_file.log,
	          '***************************PARAMETERS*****************************');
    fnd_file.put_line(fnd_file.log,
	          '***************************************************************************');
    fnd_file.put_line(fnd_file.log, '---------p_location=' || p_location);
    fnd_file.put_line(fnd_file.log, '---------p_filename=' || p_filename);
    fnd_file.put_line(fnd_file.log,
	          '---------p_ignore_first_headers_line    =' ||
	          p_ignore_first_headers_line);
    fnd_file.put_line(fnd_file.log, '---------p_mode    =' || p_mode);
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line

    ------------------Open flat file----------------------------
    v_step := 'Step 1';
    BEGIN
      v_file := utl_file.fopen( ---v_dir,v_file_name,'r');
		       p_location,
		       p_filename,
		       'R');
      -- p_location,p_filename,'r',32767);

    EXCEPTION
      WHEN utl_file.invalid_path THEN
        errcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' ||
	       ltrim(p_location || '/' || p_filename) || chr(0);
        RAISE stop_processing;
      WHEN utl_file.invalid_mode THEN
        errcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' ||
	       ltrim(p_location || '/' || p_filename) || chr(0);
        RAISE stop_processing;
      WHEN utl_file.invalid_operation THEN
        errcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' ||
	       ltrim(p_location || '/' || p_filename) || ' ' || SQLERRM ||
	       chr(0);
        RAISE stop_processing;
      WHEN OTHERS THEN
        errcode := '2';
        ---errbuf  :='==============Cannot open '||v_dir||v_file_name||' file';
        errbuf := '==============Cannot open ' || p_location || '/' ||
	      p_filename || ' file';
        RAISE stop_processing;
    END;
    ------------------

    ------------------Get lines---------------------------------
    v_step := 'Step 5';
    BEGIN
      v_read_code := 1;
      WHILE v_read_code <> 0 --EOF    -----AND errcode IS NULL   --- ASK AVI
       LOOP
        ----
        BEGIN
          utl_file.get_line(v_file, v_line);
        EXCEPTION
          WHEN utl_file.read_error THEN
	errbuf  := 'Read Error' || chr(0);
	errcode := '2';
	EXIT;
          WHEN no_data_found THEN
	fnd_file.put_line(fnd_file.log, ' '); ---empty row
	fnd_file.put_line(fnd_file.log, ' '); ---empty row
	fnd_file.put_line(fnd_file.log,
		      '***********************READ COMPLETE******************************');
	errbuf      := 'Read Complete' || chr(0);
	v_read_code := 0;
	EXIT;
          WHEN OTHERS THEN
	errbuf  := 'Other for Line Read' || chr(0);
	errcode := '2';
	EXIT;
        END;

        IF v_line IS NULL THEN
          ----dbms_output.put_line('Got empty line');
          NULL;
        ELSE
          v_step := 'Step 10';
          --------New line was received from file-----------
          v_line_number         := v_line_number + 1;
          v_line_is_valid_flag  := 'Y';
          v_valid_error_message := NULL;

          -----Selected values-----------------
          v_qty                    := NULL;
          v_dest_organization_id   := NULL;
          v_source_organization_id := NULL;
          v_org_id                 := NULL;
          v_inventory_item_id      := NULL;
          v_location_id            := NULL;
          v_need_by_d              := NULL;
          v_primary_uom_code       := NULL;
          v_charge_account_id      := NULL;

          v_segment1                 := get_field_from_utl_file_line(v_line,
					         1);
          v_quantity                 := get_field_from_utl_file_line(v_line,
					         2);
          v_need_by_date             := get_field_from_utl_file_line(v_line,
					         3);
          v_operating_unit           := get_field_from_utl_file_line(v_line,
					         4);
          v_dest_oragnization_code   := get_field_from_utl_file_line(v_line,
					         5);
          v_source_oragnization_code := get_field_from_utl_file_line(v_line,
					         6);
          v_location                 := get_field_from_utl_file_line(v_line,
					         7);
          v_unit_of_measure          := get_field_from_utl_file_line(v_line,
					         8);
          v_dest_subinventory        := get_field_from_utl_file_line(v_line,
					         9);
          v_source_subinventory      := get_field_from_utl_file_line(v_line,
					         10);
          /*          v_comments                 := get_field_from_utl_file_line(v_line, -- Gabriel 13/10
          11);*/
          v_requestor    := get_field_from_utl_file_line(v_line, -- Gabriel 13/10
				         11);
          v_req_lastname := get_field_from_utl_file_line(v_line, -- Gabriel 14/10
				         12);
          /* Column Sequence 13 and 14 Holds "suggested_vendor_name" & "suggested_vendor_site"
             Which will be used during Purchase requisition
           */
          -- v_req_lastname rtrim functionality commented , because now the last column is Justification
          --v_req_lastname := rtrim(v_req_lastname, chr(13)); -- Gabriel 14/10
          -- Added to Support new Column 'Justification'
          -- Added on 05.06.17 for CHG0040751
          v_justification:= get_field_from_utl_file_line(v_line,15);--CHG0043850
          --v_justification := rtrim(v_justification, chr(13)); -- Commented for CHG0043850

          --v_air_shipment_reason Added on 19Sep2018 for CHG0043850
          v_air_shipment_reason:= get_field_from_utl_file_line(v_line,16);
          v_air_shipment_reason := rtrim(v_air_shipment_reason, chr(13));
          --------------------------------------------------------------------------

          IF NOT (v_line_number = 1 AND p_ignore_first_headers_line = 'Y') THEN
	------------------- FOR DEBUGGING ONLY ------------------------------
	fnd_file.put_line(fnd_file.log, ''); ---empty line
	fnd_file.put_line(fnd_file.log,
		      '++++++++++++ Line ' || v_line_number ||
		      ' +++++++++++++++');
	fnd_file.put_line(fnd_file.log,
		      'Segment1           : ' || v_segment1 ||
		      '---(' || length(v_segment1) || ')');
	fnd_file.put_line(fnd_file.log,
		      'Quantity           : ' || v_quantity ||
		      '---(' || length(v_quantity) || ')');
	fnd_file.put_line(fnd_file.log,
		      'Need by Date       : ' || v_need_by_date ||
		      '---(' || length(v_need_by_date) || ')');
	fnd_file.put_line(fnd_file.log,
		      'Operating Unit     : ' || v_operating_unit ||
		      '---(' || length(v_operating_unit) || ')');
	fnd_file.put_line(fnd_file.log,
		      'Dest Organization  : ' ||
		      v_dest_oragnization_code || '---(' ||
		      length(v_dest_oragnization_code) || ')');
	fnd_file.put_line(fnd_file.log,
		      'Source Organization: ' ||
		      v_source_oragnization_code || '---(' ||
		      length(v_source_oragnization_code) || ')');
	fnd_file.put_line(fnd_file.log,
		      'Location           : ' || v_location ||
		      '---(' || length(v_location) || ')');
	fnd_file.put_line(fnd_file.log,
		      'UOM                : ' || v_primary_uom_code ||
		      '---(' || length(v_primary_uom_code) || ')');
	fnd_file.put_line(fnd_file.log,
		      'Dest Subinventory  : ' ||
		      v_dest_subinventory || '---(' ||
		      length(v_dest_subinventory) || ')');
	fnd_file.put_line(fnd_file.log,
		      'Source Subinventory: ' ||
		      v_source_subinventory || '---(' ||
		      length(v_source_subinventory) || ')');

	/*            fnd_file.put_line(fnd_file.log,
            'Comments           : ' || v_comments ||
            '---(' || length(v_comments) || ')');*/ -- Gabriel 13/10

	fnd_file.put_line(fnd_file.log,
		      'Requestor Lastname       : ' || v_requestor ||
		      '---(' || length(v_requestor) || ')'); -- Gabriel 13/10
	fnd_file.put_line(fnd_file.log,
		      'Requestor Name  : ' || v_req_lastname ||
		      '---(' || length(v_req_lastname) || ')'); -- Gabriel 14/10

    fnd_file.put_line(fnd_file.log,
		      'Justification  : ' || v_justification ||
		      '---(' || length(v_justification) || ')'); -- Added on 05.06.17 for CHG0040751

    fnd_file.put_line(fnd_file.log,
		      'Air shipments reason  : ' || v_air_shipment_reason ||
		      '---(' || length(v_air_shipment_reason) || ')'); -- Added on 19.09.18 for CHG0043850
          END IF;

          ---=================Validations========================
          BEGIN
	IF v_line_number = 1 AND p_ignore_first_headers_line = 'Y' THEN
	  RAISE validation_error; ---no validations for this headres line
	END IF;
	v_step := 'Step 12';
	-------check SEGMENT1----------REQUIRED----
	IF v_segment1 IS NULL THEN
	  v_line_is_valid_flag  := 'N';
	  v_valid_error_message := '======Line ' || v_line_number ||
			   ' Validation Error:   SEGMENT1 is MISSING=========';
	  fnd_file.put_line(fnd_file.log, v_valid_error_message);
	  RAISE validation_error;
	END IF;
	IF length(v_segment1) > 40 THEN
	  v_line_is_valid_flag  := 'N';
	  v_valid_error_message := '======Line ' || v_line_number ||
			   ' Validation Error:   SEGMENT1 is TOO LONG (more than 40 characters)    (length=' ||
			   length(v_segment1) || ')=========';
	  fnd_file.put_line(fnd_file.log, v_valid_error_message);
	  RAISE validation_error;
	END IF;

	v_step := 'Step 15';
	----check Operating Unit-------REQUIRED----
	IF v_operating_unit IS NULL THEN
	  v_line_is_valid_flag  := 'N';
	  v_valid_error_message := '======Line ' || v_line_number ||
			   ' Validation Error:   OPERATING UNIT is MISSING=========';
	  fnd_file.put_line(fnd_file.log, v_valid_error_message);
	  RAISE validation_error;
	END IF;
	BEGIN
	  SELECT hrou.organization_id
	  INTO   v_org_id
	  FROM   hr_operating_units hrou
	  WHERE  hrou.name = v_operating_unit;
	EXCEPTION
	  WHEN no_data_found THEN
	    v_org_id              := NULL;
	    v_line_is_valid_flag  := 'N';
	    v_valid_error_message := '======Line ' || v_line_number ||
			     ' Validation Error:   Operating Unit=''' ||
			     v_operating_unit ||
			     ''' DOES NOT EXIST in HR_OPERATING_UNITS';
	    fnd_file.put_line(fnd_file.log, v_valid_error_message);
	    RAISE validation_error;
	END;

	v_step := 'Step 16';
	----check Need by Date-------REQUIRED----
	IF v_need_by_date IS NULL THEN
	  v_line_is_valid_flag  := 'N';
	  v_valid_error_message := '======Line ' || v_line_number ||
			   ' Validation Error:   NEED BY DATE is MISSING=========';
	  fnd_file.put_line(fnd_file.log, v_valid_error_message);
	  RAISE validation_error;
	END IF;
	BEGIN
	  SELECT to_date(upper(v_need_by_date), 'DD-MON-YY')
	  INTO   v_need_by_d
	  FROM   dual;
	EXCEPTION
	  WHEN no_data_found THEN
	    v_need_by_d           := NULL;
	    v_line_is_valid_flag  := 'N';
	    v_valid_error_message := '======Line ' || v_line_number ||
			     ' Validation Error:   Need By Date=''' ||
			     v_need_by_date ||
			     ''' SHOULD BE IN FORMAT ''DD-MON-YY''';
	    fnd_file.put_line(fnd_file.log, v_valid_error_message);
	    RAISE validation_error;
	END;

	v_step := 'Step 18';
	----check Source inventory organization-------REQUIRED----
	IF v_source_oragnization_code IS NULL THEN
	  v_line_is_valid_flag  := 'N';
	  v_valid_error_message := '======Line ' || v_line_number ||
			   ' Validation Error:   SOURCE ORGANIZATION is MISSING=========';
	  fnd_file.put_line(fnd_file.log, v_valid_error_message);
	  RAISE validation_error;
	END IF;
	BEGIN
	  SELECT mp.organization_id
	  INTO   v_source_organization_id
	  FROM   mtl_parameters mp
	  WHERE  mp.organization_code = v_source_oragnization_code;
	EXCEPTION
	  WHEN no_data_found THEN
	    v_source_organization_id := NULL;
	    v_line_is_valid_flag     := 'N';
	    v_valid_error_message    := '======Line ' || v_line_number ||
			        ' Validation Error:   Source Organization=''' ||
			        v_source_oragnization_code ||
			        ''' DOES NOT EXIST in MTL_PARAMETERS';
	    fnd_file.put_line(fnd_file.log, v_valid_error_message);
	    RAISE validation_error;
	END;

	IF v_source_subinventory IS NOT NULL THEN
	  -------Check Source Subinventory---------
	  BEGIN
	    v_step := 'Step 18.2';
	    SELECT 1
	    INTO   v_numeric_dummy
	    FROM   mtl_secondary_inventories mseci
	    WHERE  mseci.secondary_inventory_name =
	           v_source_subinventory
	    AND    mseci.organization_id = v_source_organization_id;
	  EXCEPTION
	    WHEN no_data_found THEN
	      v_line_is_valid_flag  := 'N';
	      v_valid_error_message := '======Line ' || v_line_number ||
			       ' Validation Error:   Source Subinventory=''' ||
			       v_source_subinventory ||
			       ''' DOES NOT EXIST in MTL_SECONDARY_INVENTORIES for Source Organization''' ||
			       v_source_oragnization_code ||
			       ''' (organization_id=' ||
			       v_source_organization_id || ')';
	      fnd_file.put_line(fnd_file.log, v_valid_error_message);
	      RAISE validation_error;
	  END;

	  ----------------
	END IF;

	v_step := 'Step 20';
	----check Destination inventory organization-------REQUIRED----
	IF v_dest_oragnization_code IS NULL THEN
	  v_line_is_valid_flag  := 'N';
	  v_valid_error_message := '======Line ' || v_line_number ||
			   ' Validation Error:   DESTINATION ORGANIZATION is MISSING=========';
	  fnd_file.put_line(fnd_file.log, v_valid_error_message);
	  RAISE validation_error;
	END IF;
	BEGIN
	  SELECT mp.organization_id,
	         mp.material_account
	  INTO   v_dest_organization_id,
	         v_charge_account_id
	  FROM   mtl_parameters mp
	  WHERE  mp.organization_code = v_dest_oragnization_code;
	EXCEPTION
	  WHEN no_data_found THEN
	    v_dest_organization_id := NULL;
	    v_charge_account_id    := NULL;
	    v_line_is_valid_flag   := 'N';
	    v_valid_error_message  := '======Line ' || v_line_number ||
			      ' Validation Error:   Destination Organization=''' ||
			      v_dest_oragnization_code ||
			      ''' DOES NOT EXIST in MTL_PARAMETERS';
	    fnd_file.put_line(fnd_file.log, v_valid_error_message);
	    RAISE validation_error;
	END;

	IF v_dest_subinventory IS NOT NULL THEN
	  -------Check Source Subinventory---------
	  BEGIN
	    v_step := 'Step 20.2';
	    SELECT 1
	    INTO   v_numeric_dummy
	    FROM   mtl_secondary_inventories mseci
	    WHERE  mseci.secondary_inventory_name = v_dest_subinventory
	    AND    mseci.organization_id = v_dest_organization_id;
	  EXCEPTION
	    WHEN no_data_found THEN
	      v_line_is_valid_flag  := 'N';
	      v_valid_error_message := '======Line ' || v_line_number ||
			       ' Validation Error:   Source Subinventory=''' ||
			       v_dest_subinventory ||
			       ''' DOES NOT EXIST in MTL_SECONDARY_INVENTORIES for Source Organization''' ||
			       v_dest_oragnization_code ||
			       ''' (organization_id=' ||
			       v_dest_organization_id || ')';
	      fnd_file.put_line(fnd_file.log, v_valid_error_message);
	      RAISE validation_error;
	  END;

	  ----------------
	END IF;

	-----Search this item in mtl_system_items_b for source organization...
	BEGIN
	  v_step := 'Step 25';
	  SELECT msi.inventory_item_id,
	         msi.primary_uom_code
	  INTO   v_inventory_item_id,
	         v_primary_uom_code
	  FROM   mtl_system_items_b msi
	  WHERE  msi.segment1 = v_segment1
	  AND    msi.organization_id = v_source_organization_id;
	EXCEPTION
	  WHEN no_data_found THEN
	    v_inventory_item_id   := NULL;
	    v_primary_uom_code    := NULL;
	    v_line_is_valid_flag  := 'N';
	    v_valid_error_message := '======Line ' || v_line_number ||
			     ' Validation Error:   Item=''' ||
			     v_segment1 ||
			     ''', Source organization=''' ||
			     v_source_oragnization_code ||
			     ''' (organization_id=' ||
			     v_source_organization_id ||
			     ') DOES NOT EXIST in MTL_SYSTEM_ITEMS_B';
	    fnd_file.put_line(fnd_file.log, v_valid_error_message);
	    RAISE validation_error;
	END;

	v_step := 'Step 27';
	----check Unit of Measure-------REQUIRED----
	/*            IF v_unit_of_measure IS NULL THEN
              v_line_is_valid_flag  := 'N';
              v_valid_error_message := '======Line ' || v_line_number ||
                                       ' Validation Error:   UNIT OF MEASURE is MISSING=========';
              fnd_file.put_line(fnd_file.log, v_valid_error_message);
              RAISE validation_error;
            END IF;
            BEGIN
              SELECT 1
                INTO v_numeric_dummy
                FROM mtl_units_of_measure uom
               WHERE uom.uom_code = v_unit_of_measure;
            EXCEPTION
              WHEN no_data_found THEN
                v_line_is_valid_flag  := 'N';
                v_valid_error_message := '======Line ' || v_line_number ||
                                         ' Validation Error:   UNIT OF MEASURE=''' ||
                                         v_unit_of_measure ||
                                         ''' DOES NOT EXIST in MTL_UNITS_OF_MEASURE';
                fnd_file.put_line(fnd_file.log, v_valid_error_message);
                RAISE validation_error;
            END;*/

	----------Check Quantity-----------------REQUIRED----------------
	v_step := 'Step 30';
	IF v_quantity IS NULL THEN
	  v_line_is_valid_flag  := 'N';
	  v_valid_error_message := '======Line ' || v_line_number ||
			   ' Validation Error:   QUANTITY is MISSING=========';
	  fnd_file.put_line(fnd_file.log, v_valid_error_message);
	  RAISE validation_error;
	END IF;
	--------
	BEGIN
	  v_qty := to_number(v_quantity);
	EXCEPTION
	  WHEN OTHERS THEN
	    v_line_is_valid_flag  := 'N';
	    v_valid_error_message := '======Line ' || v_line_number ||
			     ' Validation Error:   QUANTITY SHOULD BE NUMERIC VALUE';
	    fnd_file.put_line(fnd_file.log, v_valid_error_message);
	    RAISE validation_error;
	END;
	--------
	--------
	IF v_qty <= 0 THEN
	  v_line_is_valid_flag  := 'N';
	  v_valid_error_message := '======Line ' || v_line_number ||
			   ' Validation Error:   QUANTITY SHOULD BE POSITIVE NUMERIC VALUE > 0';
	  fnd_file.put_line(fnd_file.log, v_valid_error_message);
	  RAISE validation_error;
	END IF;

	-------Check Location------REQUIRED--------------------
	IF v_location IS NULL THEN
	  v_line_is_valid_flag  := 'N';
	  v_valid_error_message := '======Line ' || v_line_number ||
			   ' Validation Error:   LOCATION is MISSING=========';
	  fnd_file.put_line(fnd_file.log, v_valid_error_message);
	  RAISE validation_error;
	END IF;
	-----------
	BEGIN
	  v_step := 'Step 35';
	  SELECT loc.location_id
	  INTO   v_location_id
	  FROM   hr_locations loc
	  WHERE  loc.location_code = v_location;

	EXCEPTION
	  WHEN no_data_found THEN
	    v_location_id         := NULL;
	    v_line_is_valid_flag  := 'N';
	    v_valid_error_message := '======Line ' || v_line_number ||
			     ' Validation Error:   LOCATION=' ||
			     v_location ||
			     ' DOES NOT EXIST in HR_LOCATIONS';
	    fnd_file.put_line(fnd_file.log, v_valid_error_message);
	    RAISE validation_error;
	END;

	------- Check Organization Location Association for Internal Order
	/*          BEGIN
              v_step := 'Step 37';
              SELECT 1
                INTO v_numeric_dummy
                FROM po_location_associations_all a,
                     org_organization_definitions ood
               WHERE a.organization_id = v_dest_organization_id
                 AND a.location_id = v_location_id
                 AND a.org_id = ood.operating_unit
                 AND ood.organization_id = v_source_organization_id;
            EXCEPTION
              WHEN no_data_found THEN
                v_line_is_valid_flag  := 'N';
                v_valid_error_message := '======Line ' || v_line_number ||
                                         ' Validation Error:   NO ORGANIZATION LOCATION ASSOCIATION for Internal Order ';
                fnd_file.put_line(fnd_file.log, v_valid_error_message);
                dbms_output.put_line('Vitaly Step 37: Line#' ||
                                     v_line_number ||
                                     ', v_dest_organization_id=' ||
                                     v_dest_organization_id ||
                                     ', v_location_id=' || v_location_id ||
                                     ', v_source_organization_id=' ||
                                     v_source_organization_id ||
                                     ' Validation Error:   NO ORGANIZATION LOCATION ASSOCIATION for Internal Order ');
                RAISE validation_error;
            END;*/

	-- Get employee_id (not curr user) for name validation (Gabriel) --
	-- 26/03/2014 Dalit A. Raviv
	v_step := 'Step 38';
	BEGIN
	  SELECT pap.person_id
	  INTO   v_req_id
	  FROM   per_all_people_f pap
	  WHERE  pap.last_name = v_requestor -- 'Hanke'
	  AND    pap.first_name = v_req_lastname --  'Holger'
	  AND    trunc(SYSDATE) BETWEEN pap.effective_start_date AND
	         pap.effective_end_date;
	EXCEPTION
	  WHEN no_data_found THEN
	    v_req_id              := NULL;
	    v_valid_error_message := ' Validation Error for employee ' ||
			     v_requestor || ', ' ||
			     v_req_lastname;
	    fnd_file.put_line(fnd_file.log, v_valid_error_message);
	    RAISE validation_error;
	END;

	fnd_file.put_line(fnd_file.log,
		      'Employee ID  : ' || v_req_id || '---(' ||
		      length(v_req_id) || ')'); -- Gabriel 15/10

	-- Get item_revision (Gabriel) --
	v_step := 'Step 39';
	BEGIN
	  SELECT a.revision
	  INTO   v_item_revision
	  FROM   mtl_item_revisions a
	  WHERE  a.inventory_item_id = v_inventory_item_id
	  AND    a.organization_id = v_source_organization_id
	  AND    a.effectivity_date =
	         (SELECT MAX(b.effectivity_date)
	           FROM   mtl_item_revisions b
	           WHERE  b.inventory_item_id = v_inventory_item_id
	           AND    b.organization_id = v_source_organization_id
	           AND    v_need_by_d > b.effectivity_date);
	EXCEPTION
	  WHEN no_data_found THEN
	    v_item_revision       := NULL;
	    v_valid_error_message := ' Validation Error for Item Revision ' ||
			     v_item_revision;
	    fnd_file.put_line(fnd_file.log, v_valid_error_message);
	    RAISE validation_error;
	END;

	fnd_file.put_line(fnd_file.log,
		      'Item Revision  : ' || v_item_revision ||
		      '---(' || length(v_item_revision) || ')'); -- Gabriel 15/10
      --Justification Validation Added on 05.06.17 for CHG0040751 **START***
      v_step := 'Step 39.5';
      IF length(v_justification) > 480 THEN
         v_line_is_valid_flag  := 'N';
         v_valid_error_message :='======Line ' || v_line_number ||
                                 ' Validation Error:   JUSTIFICATION is TOO LONG (more than 480 characters)    (length=' ||
                                   length(v_justification) || ')=========';
         fnd_file.put_line(fnd_file.log, v_valid_error_message);
         RAISE validation_error;
      End If;
      fnd_file.put_line(fnd_file.log,
		      'Justification  : ' || v_justification ||
		      '---(' || length(v_justification) || ')');
      -----------CHG0040751 **END***

      ----Air shipments - reason Validation Added on 19.09.18 for CHG0043850 **START***
        v_step := 'Step 40.0';
        If v_air_shipment_reason is not null Then
          IF length(v_air_shipment_reason) > 240 THEN
             v_line_is_valid_flag  := 'N';
             v_valid_error_message :='======Line ' || v_line_number ||
                                     ' Validation Error:   Air shipments - Reason is TOO LONG (more than 240 characters)    (length=' ||
                                       length(v_air_shipment_reason) || ')=========';
             fnd_file.put_line(fnd_file.log, v_valid_error_message);
             RAISE validation_error;
          Else
             Begin
                select ffvv.DESCRIPTION
                into  v_air_shipment_reason
                from
                fnd_flex_values_vl ffvv,
                fnd_flex_value_sets ffvs
                Where ffvv.FLEX_VALUE_SET_ID = ffvs.FLEX_VALUE_SET_ID
                and ffvs.flex_value_set_name  = 'XX_PO_AIR_SHIPMENT_REASON'
                and upper(ffvv.DESCRIPTION) = upper(v_air_shipment_reason)
                and nvl(enabled_flag,'N') = 'Y';
             Exception
             When no_data_found Then
               v_valid_error_message :='======Line ' || v_line_number ||
                                     ' Validation Error: Air shipments - Reason is not a valid Reason,'||
                                     ' not exists in XX_PO_AIR_SHIPMET_REASON Value Set.Reason=' ||
                                       v_air_shipment_reason || ')=========';
               fnd_file.put_line(fnd_file.log, v_valid_error_message);
               RAISE validation_error;
             End;
          End If;
        End If;
         fnd_file.put_line(fnd_file.log,
		      'Air shipments - Reason  : ' || v_air_shipment_reason ||
		      '---(' || length(v_air_shipment_reason) || ')');
      -----------CHG0043850 **END***


          EXCEPTION
	WHEN validation_error THEN
	  IF NOT
	      (v_line_number = 1 AND p_ignore_first_headers_line = 'Y') THEN
	    v_there_are_non_valid_rows := 'Y';
	  END IF;
	  fnd_file.put_line(fnd_file.log, ''); ---empty line
          END;

          ---=============the end of validations=================

          IF v_line_is_valid_flag = 'N' THEN
	v_num_of_non_valid_lines := v_num_of_non_valid_lines + 1;
          ELSE
	v_num_of_valid_lines := v_num_of_valid_lines + 1;
          END IF;

          IF v_line_is_valid_flag = 'Y' AND p_mode <> 'VALIDATE_ONLY' AND
	 NOT (v_line_number = 1 AND p_ignore_first_headers_line = 'Y') THEN
	---***************** Run API for upload this requisition ************************
	v_step := 'Step 40';
	--------
	BEGIN
	  INSERT INTO po_requisitions_interface_all
	    (batch_id,
	     header_description,
	     item_id,
	     item_revision,
	     need_by_date,
	     quantity,
	     org_id,
	     created_by,
	     creation_date,
	     last_updated_by,
	     last_update_date,
	     last_update_login,
	     destination_organization_id,
	     destination_subinventory,
	     deliver_to_location_id,
	     preparer_id,
	     charge_account_id,
	     source_organization_id,
	     source_subinventory,
	     uom_code,
	     deliver_to_requestor_name, -- Added 13/10 Gabriel
	     deliver_to_requestor_id, -- Added 15/10 Gabriel for employee_id
	     authorization_status,
	     source_type_code, -- INVENTORY
	     destination_type_code, --  INVENTORY
	     interface_source_code, --'FORM'
	     project_accounting_context, -- N
	     vmi_flag, --  N
	     autosource_flag, -- P
         justification -- Added on 05.06.17 for CHG0040751
         ,line_attribute4 --Added on 19Sep2018 for CHG0043850
	     )
	  VALUES
	    (v_batch_id,
	     v_comments, -----header_description,
	     v_inventory_item_id,
	     NULL, --v_item_revision,
	     --                 xxinv_utils_pkg.get_current_revision(v_inventory_item_id,
	     --                                                      v_source_organization_id), -- Added 13/10 Gabriel --  NULL, ----item_revision,
	     v_need_by_d,
	     v_qty, -----quantity,
	     v_org_id,
	     fnd_global.user_id, ----created_by,
	     SYSDATE, ----creation_date,
	     fnd_global.user_id, ----last_updated_by,
	     SYSDATE, ----last_update_date,
	     fnd_global.login_id, ----last_update_login,
	     v_dest_organization_id,
	     v_dest_subinventory,
	     v_location_id, ----deliver_to_location_id,
	     v_user_employee_id, ----preparer_id,
	     v_charge_account_id,
	     v_source_organization_id,
	     v_source_subinventory,
	     v_primary_uom_code, -- Added 13/10 Gabriel
	     -- v_unit_of_measure, -- Added 13/10 Gabriel
	     v_requestor || ', ' || v_req_lastname, -- Updated 14/10 Gabriel
	     v_req_id, -- v_user_employee_id, ----deliver_to_requestor_id, -- Updated 15/10 Gabriel
	     'INCOMPLETE', ----authorization_status,
	     'INVENTORY', ----source_type_code,
	     'INVENTORY', ----destination_type_code,
	     'FILE', ----interface_source_code,
	     'N', ----project_accounting_context,
	     'N', ----vmi_flag,
	     'N', ----'P'                  ----autosource_flag
         v_justification  -- Added on 05.06.17 for CHG0040751
         ,v_air_shipment_reason    --Added on 19Sep2018 for CHG0043850
	     );
	  ---COMMIT;
	  v_num_of_success_ins_lines := v_num_of_success_ins_lines + 1;
	EXCEPTION
	  WHEN OTHERS THEN
	    v_num_of_failured_ins_lines := v_num_of_failured_ins_lines + 1;
	    fnd_file.put_line(fnd_file.log,
		          '**************Line ' || v_line_number ||
		          ' INSERT into po_requisitions_interface_all ERROR : ' ||
		          SQLERRM);
	END;
	------------
          END IF;
          ---***********the end of Run API for upload requisition ************************
        END IF;
      END LOOP;

    EXCEPTION
      WHEN no_data_found THEN
        fnd_file.put_line(fnd_file.log,
		  '##############  No more data to read  #################');
    END;
    -----------------

    IF p_mode <> 'VALIDATE_ONLY' THEN
      IF v_there_are_non_valid_rows = 'N' THEN
        COMMIT;
        ---- fnd_file.put_line (fnd_file.log, '********************************* COMMIT *****************************');
      ELSE
        ROLLBACK;
        ----- fnd_file.put_line (fnd_file.log, '***************** ROLLBACK (there are non valid rows in Your file ***********************');
      END IF;
    END IF;

    ------------------Close flat file----------------------------
    utl_file.fclose(v_file);

    IF p_mode <> 'VALIDATE_ONLY' AND v_there_are_non_valid_rows = 'N' AND
       p_launch_import_requisition = 'Y' THEN
      --------------
      BEGIN
        SELECT a.application_short_name
        INTO   l_app_short_name
        FROM   fnd_application a
        WHERE  a.application_id = fnd_global.resp_appl_id;

        FOR org_id_rec IN get_interface_org_id(v_batch_id) LOOP
          --------------------------------------------
          mo_global.set_org_context(p_org_id_char     => org_id_rec.org_id,
			p_sp_id_char      => NULL,
			p_appl_short_name => l_app_short_name);

          fnd_request.set_org_id(org_id_rec.org_id);

          v_request_id := fnd_request.submit_request(application => 'PO',
				     program     => 'REQIMPORT',
				     argument1   => 'FILE', ---interface_source_code
				     argument2   => v_batch_id, ---batch_id
				     argument3   => 'ALL',
				     argument4   => 0,
				     argument5   => 'N',
				     argument6   => p_submit_approval); --'N'); CHG0047106
          COMMIT;
          fnd_file.put_line(fnd_file.log, ''); --empty line
          fnd_file.put_line(fnd_file.log,
		    '=============== ''Requisition Import'' was submitted for ' ||
		    org_id_rec.operating_unit || ' (' ||
		    org_id_rec.num_of_rows_for_org_id ||
		    ' rows with interface_source_code=''FILE'' and batch_id=' ||
		    v_batch_id || ')================');
          fnd_file.put_line(fnd_file.log, ''); --empty line
        --------------------------------------------
        END LOOP;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      --------------
    END IF; ----IF p_launch_import_requisition='Y' ...

    ------------------Display total information about this updload...----------------------------
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
	          '***************************************************************************');
    fnd_file.put_line(fnd_file.log,
	          '********************TOTAL INFORMATION******************************');
    fnd_file.put_line(fnd_file.log,
	          '***************************************************************************');
    fnd_file.put_line(fnd_file.log,
	          '=========There are ' || v_line_number ||
	          ' lines in our file ' || p_location || '/' ||
	          p_filename);
    fnd_file.put_line(fnd_file.log,
	          '=============' || v_num_of_non_valid_lines ||
	          ' LINES ARE NON-VALID');
    fnd_file.put_line(fnd_file.log,
	          '=============' || v_num_of_success_ins_lines ||
	          ' Requisitions were SUCCESSFULY INSERTED into PO_REQUISITIONS_INTERFACE_ALL table');
    fnd_file.put_line(fnd_file.log,
	          '=============' || v_num_of_failured_ins_lines ||
	          ' for these lines INSERT was FAILURED');
    fnd_file.put_line(fnd_file.log, ''); --empty line

    IF p_mode <> 'VALIDATE_ONLY' THEN
      IF v_there_are_non_valid_rows = 'N' THEN
        fnd_file.put_line(fnd_file.log,
		  '********************************* COMMIT *****************************');
      ELSE
        fnd_file.put_line(fnd_file.log,
		  '***************** ROLLBACK (there are non valid rows in Your file) ***********************');
      END IF;
    END IF;

    IF v_there_are_non_valid_rows = 'Y' THEN
      errcode := '1'; ---Warning
    ELSE
      errcode := '0'; ---Success
    END IF;

  EXCEPTION
    WHEN stop_processing THEN
      NULL;
    WHEN OTHERS THEN
      v_error_message := ' =============XXPO_UTILS_PKG.upload_internal_requisitions unexpected ERROR (' ||
		 v_step || ' (utl-file line=' || v_line_number ||
		 ') : ' || SQLERRM;
      errcode         := '2';
      errbuf          := v_error_message;
      fnd_file.put_line(fnd_file.log, v_error_message);
  END upload_internal_requisitions;

  --------------------------------------------------------------------
  --  name:              upload_purchase_requisitions
  --  create by:
  --  Revision:
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :          upload_purchase_requisitions
  --------------------------------------------------------------------
  --  ver  date          name            desc

  -- 1.X 23.11.2015      Yuval tal       CHG0036436 upload_purchase_requisitions ,
  --                                     Add vendor details (suggested_vendor_name, suggested_vendor_site_name) to the planned purchase orders lines from ASCP
  --                                     change  autosource_flag=P
  --                                     add translation suggested_vendor_id,
  --                                                     suggested_vendor_site_id
  --  1.3  19.09.2018    Lingaraj          CHG0043850 - IR/ISO - Air shipments - reason (justification)
  --                                       New Field added "Air shipments - reason"
  --  1.4  08.11.18      LINGARAJ         CHG0044329 - XX: Upload Purchase Requisitions - Bug fix
  --------------------------------------------------------------------
  PROCEDURE upload_purchase_requisitions(errbuf                      OUT VARCHAR2,
			     errcode                     OUT VARCHAR2,
			     p_location                  IN VARCHAR2,
			     p_filename                  IN VARCHAR2,
			     p_ignore_first_headers_line IN VARCHAR2 DEFAULT 'N',
			     p_mode                      IN VARCHAR2,
			     p_launch_import_requisition IN VARCHAR2) IS

    CURSOR get_interface_org_id(p_batch_id NUMBER) IS
      SELECT por.org_id,
	 hrou.name operating_unit,
	 COUNT(*) num_of_rows_for_org_id
      FROM   po_requisitions_interface_all por,
	 hr_all_organization_units     hrou
      WHERE  por.interface_source_code = 'FILEPO'
      AND    por.batch_id = p_batch_id
      AND    por.org_id = hrou.organization_id
      GROUP  BY por.org_id,
	    hrou.name;

    v_request_id    NUMBER;
    v_step          VARCHAR2(1000);
    v_error_message VARCHAR2(1000);
    v_numeric_dummy NUMBER;
    stop_processing  EXCEPTION; --- missing parameter...or invalid parameter. stop (exit) procedure..
    validation_error EXCEPTION; ---the one of fields is invalid. stop processing for this line
    v_file                      utl_file.file_type;
    v_line                      VARCHAR2(7000);
    v_line_number               NUMBER := 0;
    v_line_is_valid_flag        VARCHAR2(1);
    v_valid_error_message       VARCHAR2(1000);
    v_num_of_non_valid_lines    NUMBER := 0;
    v_num_of_valid_lines        NUMBER := 0;
    v_num_of_success_ins_lines  NUMBER := 0;
    v_num_of_failured_ins_lines NUMBER := 0;

    v_read_code                NUMBER;
    v_there_are_non_valid_rows VARCHAR2(100) := 'N';

    l_app_short_name VARCHAR2(100);
    v_batch_id       NUMBER;
    ---UTL file fields-----
    v_segment1                 VARCHAR2(300); -----1---------  OBJ-13000
    v_quantity                 VARCHAR2(300); -----2---------
    v_need_by_date             VARCHAR2(300); -----3--------- DD-MON-YY
    v_operating_unit           VARCHAR2(300); -----4--------- OBJET US (OU)
    v_dest_oragnization_code   VARCHAR2(300); -----5--------- UOC
    v_source_oragnization_code VARCHAR2(300); -----6--------- WPI
    v_location                 VARCHAR2(300); -----7--------- UOC - US Objet Overall Chicago (IO)
    v_unit_of_measure          VARCHAR2(300); -----8--------- EA
    v_dest_subinventory        VARCHAR2(300); -----9---------
    v_source_subinventory      VARCHAR2(300); ----10---------
    v_comments                 VARCHAR2(300); ----11--------- Canceled
    v_requestor                VARCHAR2(300); ----11---------   Gabriel 13/10
    v_req_lname                VARCHAR2(300); ----12---------   Gabriel 14/10
    v_suggested_vendor_name    po_requisitions_interface_all.suggested_vendor_name%TYPE; -- CHG0036436
    v_suggested_vendor_site    po_requisitions_interface_all.suggested_vendor_site%TYPE; -- CHG0036436
    v_req_id                   NUMBER; -- Gabriel 15/10
    v_item_revision            VARCHAR2(3); -- Gabriel 15/10
    v_justification            VARCHAR2(500);-- Added on 05.06.17 for CHG0040751
    v_air_shipment_reason      VARCHAR2(500);--Added on 19Sep2018 for CHG0043850
    -----Selected values-----------------
    v_qty                    NUMBER;
    v_dest_organization_id   NUMBER;
    v_source_organization_id NUMBER;
    v_org_id                 NUMBER;
    v_inventory_item_id      NUMBER;
    v_location_id            NUMBER;
    v_need_by_d              DATE;
    v_primary_uom_code       VARCHAR2(100);
    v_charge_account_id      NUMBER;
    v_user_employee_id       NUMBER;
    -- CHG0036436
    l_vendor_id      NUMBER;
    l_vendor_site_id NUMBER;
  BEGIN
    g_req_type := 'PUR_REQ';  --CHG0044329
    ---------------INTIALIZATION--------------------------------------
    fnd_global.apps_initialize(user_id      => fnd_global.user_id,
		       resp_id      => fnd_global.resp_id,
		       resp_appl_id => fnd_global.resp_appl_id);

    ----------------Get batch_id -------------------------------------
    v_batch_id := to_number(to_char(SYSDATE, 'HH24' || 'MI' || 'SS'));
    fnd_file.put_line(fnd_file.log,
	          '********************** batch_id=' || v_batch_id ||
	          ' ========================');

    -----Get curr user employee_id--------------
    BEGIN
      SELECT fu.employee_id
      INTO   v_user_employee_id
      FROM   fnd_user fu
      WHERE  fu.user_id = fnd_global.user_id;
    EXCEPTION
      WHEN no_data_found THEN
        v_user_employee_id := NULL;
    END;
    -----

    IF p_location IS NULL THEN
      fnd_file.put_line(fnd_file.log,
		'***************** MISSING PARAMETER p_location ****************');
      RAISE stop_processing;
    END IF;

    IF p_filename IS NULL THEN
      fnd_file.put_line(fnd_file.log,
		'***************** MISSING PARAMETER p_filename ****************');
      RAISE stop_processing;
    END IF;

    IF p_mode IS NULL THEN
      fnd_file.put_line(fnd_file.log,
		'***************** MISSING PARAMETER p_mode ****************');
      RAISE stop_processing;
    END IF;

    IF p_ignore_first_headers_line IS NULL THEN
      fnd_file.put_line(fnd_file.log,
		'***************** MISSING PARAMETER p_ignore_first_headers_line ****************');
      RAISE stop_processing;
    END IF;

    IF p_ignore_first_headers_line NOT IN ('Y', 'N') THEN
      fnd_file.put_line(fnd_file.log,
		'***************** PARAMETER p_ignore_first_headers_line SHOULD BE ''Y'' or ''N'' ****************');
      RAISE stop_processing;
    END IF;

    IF p_launch_import_requisition IS NULL THEN
      fnd_file.put_line(fnd_file.log,
		'***************** MISSING PARAMETER p_launch_import_requisition ****************');
      RAISE stop_processing;
    END IF;

    IF p_launch_import_requisition NOT IN ('Y', 'N') THEN
      fnd_file.put_line(fnd_file.log,
		'***************** PARAMETER p_launch_import_requisition SHOULD BE ''Y'' or ''N'' ****************');
      RAISE stop_processing;
    END IF;

    fnd_file.put_line(fnd_file.log,
	          '***************************************************************************');
    fnd_file.put_line(fnd_file.log,
	          '***************************PARAMETERS*****************************');
    fnd_file.put_line(fnd_file.log,
	          '***************************************************************************');
    fnd_file.put_line(fnd_file.log, '---------p_location=' || p_location);
    fnd_file.put_line(fnd_file.log, '---------p_filename=' || p_filename);
    fnd_file.put_line(fnd_file.log,
	          '---------p_ignore_first_headers_line    =' ||
	          p_ignore_first_headers_line);
    fnd_file.put_line(fnd_file.log, '---------p_mode    =' || p_mode);
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line

    ------------------Open flat file----------------------------
    v_step := 'Step 1';
    BEGIN
      v_file := utl_file.fopen(
		       p_location,
		       p_filename,
		       'R');


    EXCEPTION
      WHEN utl_file.invalid_path THEN
        errcode := '2';
        errbuf  := errbuf || 'Invalid Path for ' ||
	       ltrim(p_location || '/' || p_filename) || chr(0);
        RAISE stop_processing;
      WHEN utl_file.invalid_mode THEN
        errcode := '2';
        errbuf  := errbuf || 'Invalid Mode for ' ||
	       ltrim(p_location || '/' || p_filename) || chr(0);
        RAISE stop_processing;
      WHEN utl_file.invalid_operation THEN
        errcode := '2';
        errbuf  := errbuf || 'Invalid operation for ' ||
	       ltrim(p_location || '/' || p_filename) || ' ' || SQLERRM ||
	       chr(0);
        RAISE stop_processing;
      WHEN OTHERS THEN
        errcode := '2';
        errbuf := '==============Cannot open ' || p_location || '/' ||
	      p_filename || ' file';
        RAISE stop_processing;
    END;
    ------------------

    ------------------Get lines---------------------------------
    v_step := 'Step 5';
    BEGIN
      v_read_code := 1;
      WHILE v_read_code <> 0 --EOF    -----AND errcode IS NULL   --- ASK AVI
       LOOP
        ----
        BEGIN
          utl_file.get_line(v_file, v_line);
        EXCEPTION
          WHEN utl_file.read_error THEN
            errbuf  := 'Read Error' || chr(0);
            errcode := '2';
            EXIT;
          WHEN no_data_found THEN
            fnd_file.put_line(fnd_file.log, ' '); ---empty row
            fnd_file.put_line(fnd_file.log, ' '); ---empty row
            fnd_file.put_line(fnd_file.log,
                    '***********************READ COMPLETE******************************');
            errbuf      := 'Read Complete' || chr(0);
            v_read_code := 0;
            EXIT;
          WHEN OTHERS THEN
            errbuf  := 'Other for Line Read' || chr(0);
            errcode := '2';
            EXIT;
        END;

        IF v_line IS NULL THEN
          ----dbms_output.put_line('Got empty line');
          NULL;
        ELSE
          v_step := 'Step 10';
          --------New line was received from file-----------
          v_line_number         := v_line_number + 1;
          v_line_is_valid_flag  := 'Y';
          v_valid_error_message := NULL;

          --CHG0044329
          If v_line_number = 1 and p_ignore_first_headers_line = 'Y' Then
            Continue; -- skip the Header Process
          Else
            message('++++++++++++ Line '|| v_line_number ||' +++++++++++++++');
          End If;

          -----Selected values-----------------
          v_qty                    := NULL;
          v_dest_organization_id   := NULL;
          v_source_organization_id := NULL;
          v_org_id                 := NULL;
          v_inventory_item_id      := NULL;
          v_location_id            := NULL;
          v_need_by_d              := NULL;
          v_primary_uom_code       := NULL;
          v_charge_account_id      := NULL;

          v_segment1                 := get_field_from_utl_file_line(v_line,
					         1);
          v_quantity                 := get_field_from_utl_file_line(v_line,
					         2);
          v_need_by_date             := get_field_from_utl_file_line(v_line,
					         3);
          v_operating_unit           := get_field_from_utl_file_line(v_line,
					         4);
          v_dest_oragnization_code   := get_field_from_utl_file_line(v_line,
					         5);
          v_source_oragnization_code := get_field_from_utl_file_line(v_line,
					         6);
          v_location                 := get_field_from_utl_file_line(v_line,
					         7);
          v_unit_of_measure          := get_field_from_utl_file_line(v_line,
					         8);
          v_dest_subinventory        := get_field_from_utl_file_line(v_line,
					         9);
          v_source_subinventory      := get_field_from_utl_file_line(v_line,
					         10);



          v_requestor := get_field_from_utl_file_line(v_line, 11);
          v_req_lname := get_field_from_utl_file_line(v_line, 12);
          v_req_lname := rtrim(v_req_lname, chr(13)); -- Added 13/10 Gabriel

          l_vendor_id             := NULL; --CHG0036436
          l_vendor_site_id        := NULL; --CHG0036436
          v_suggested_vendor_name := get_field_from_utl_file_line(v_line,
					      13); --CHG0036436
          v_suggested_vendor_site := rtrim(get_field_from_utl_file_line(v_line,
						14),
			       chr(13)); --CHG0036436
          v_justification := rtrim(get_field_from_utl_file_line(v_line,
						15),
			       chr(13));-- Added on 05.06.17 for CHG0040751

          --v_air_shipment_reason Added on 19Sep2018 for CHG0043850
          v_air_shipment_reason:= get_field_from_utl_file_line(v_line,16);
          v_air_shipment_reason := rtrim(v_air_shipment_reason, chr(13));

          /* --commented for CHG0044329
          IF NOT (v_line_number = 1 AND p_ignore_first_headers_line = 'Y') THEN
	          ------------------- FOR DEBUGGING ONLY ------------------------------
              message(''); ---empty line
              message('++++++++++++ Line ' || v_line_number ||
                      ' +++++++++++++++');
              message('Field Name');
              fnd_file.put_line(fnd_file.log,
                      'Segment1           : ' || v_segment1 ||
                      '---(' || length(v_segment1) || ')');
              fnd_file.put_line(fnd_file.log,
                      'Quantity           : ' || v_quantity ||
                      '---(' || length(v_quantity) || ')');
              fnd_file.put_line(fnd_file.log,
                      'Need by Date       : ' || v_need_by_date ||
                      '---(' || length(v_need_by_date) || ')');
              fnd_file.put_line(fnd_file.log,
                      'Operating Unit     : ' || v_operating_unit ||
                      '---(' || length(v_operating_unit) || ')');
              fnd_file.put_line(fnd_file.log,
                      'Dest Organization  : ' ||
                      v_dest_oragnization_code || '---(' ||
                      length(v_dest_oragnization_code) || ')');
              fnd_file.put_line(fnd_file.log,
                      'Source Organization: ' ||
                      v_source_oragnization_code || '---(' ||
                      length(v_source_oragnization_code) || ')');
              fnd_file.put_line(fnd_file.log,
                      'Location           : ' || v_location ||
                      '---(' || length(v_location) || ')');
              fnd_file.put_line(fnd_file.log,
                      'UOM                : ' || v_unit_of_measure ||
                      '---(' || length(v_unit_of_measure) || ')');
              fnd_file.put_line(fnd_file.log,
                      'Dest Subinventory  : ' ||
                      v_dest_subinventory || '---(' ||
                      length(v_dest_subinventory) || ')');
              fnd_file.put_line(fnd_file.log,
                      'Source Subinventory: ' ||
                      v_source_subinventory || '---(' ||
                      length(v_source_subinventory) || ')');

              fnd_file.put_line(fnd_file.log,
                      'Requestor Lastname: ' || v_requestor ||
                      '---(' || length(v_requestor) || ')');
              fnd_file.put_line(fnd_file.log,
                      'Requestor Name     : ' || v_req_lname ||
                      '---(' || length(v_req_lname) || ')');

              fnd_file.put_line(fnd_file.log,
              'Justification  : ' || v_justification ||
              '---(' || length(v_justification) || ')'); -- Added on 05.06.17 for CHG0040751

              fnd_file.put_line(fnd_file.log,
              'Air shipments reason  : ' || v_air_shipment_reason ||
              '---(' || length(v_air_shipment_reason) || ')'); -- Added on 19.09.18 for CHG0043850

          END IF;*/

          ---=================Validations========================
          BEGIN
          IF v_line_number = 1 AND p_ignore_first_headers_line = 'Y' THEN
            RAISE validation_error; ---no validations for this headres line
          END IF;
          v_step := 'Step 12';
          -------check SEGMENT1----------REQUIRED----
          IF v_segment1 IS NULL THEN
            v_line_is_valid_flag  := 'N';
            v_valid_error_message := '======Line ' || v_line_number ||
                     ' Validation Error:   SEGMENT1 is MISSING=========';
            fnd_file.put_line(fnd_file.log, v_valid_error_message);
            RAISE validation_error;
          END IF;
          IF length(v_segment1) > 40 THEN
            v_line_is_valid_flag  := 'N';
            v_valid_error_message := '======Line ' || v_line_number ||
                     ' Validation Error:   SEGMENT1 is TOO LONG (more than 40 characters)    (length=' ||
                     length(v_segment1) || ')=========';
            fnd_file.put_line(fnd_file.log, v_valid_error_message);
            RAISE validation_error;
          END IF;

          v_step := 'Step 15';
          ----check Operating Unit-------REQUIRED----
          IF v_operating_unit IS NULL THEN
            v_line_is_valid_flag  := 'N';
            v_valid_error_message := '======Line ' || v_line_number ||
                     ' Validation Error:   OPERATING UNIT is MISSING=========';
            fnd_file.put_line(fnd_file.log, v_valid_error_message);
            RAISE validation_error;
          END IF;
          BEGIN
            SELECT hrou.organization_id
            INTO   v_org_id
            FROM   hr_operating_units hrou
            WHERE  hrou.name = v_operating_unit;
          EXCEPTION
            WHEN no_data_found THEN
              v_org_id              := NULL;
              v_line_is_valid_flag  := 'N';
              v_valid_error_message := '======Line ' || v_line_number ||
                       ' Validation Error:   Operating Unit=''' ||
                       v_operating_unit ||
                       ''' DOES NOT EXIST in HR_OPERATING_UNITS';
              fnd_file.put_line(fnd_file.log, v_valid_error_message);
              RAISE validation_error;
          END;

          v_step := 'Step 16';
          ----check Need by Date-------REQUIRED----
          IF v_need_by_date IS NULL THEN
            v_line_is_valid_flag  := 'N';
            v_valid_error_message := '======Line ' || v_line_number ||
                     ' Validation Error:   NEED BY DATE is MISSING=========';
            fnd_file.put_line(fnd_file.log, v_valid_error_message);
            RAISE validation_error;
          END IF;
          BEGIN
            SELECT to_date(upper(v_need_by_date), 'DD-MON-YY')
            INTO   v_need_by_d
            FROM   dual;
          EXCEPTION
            WHEN no_data_found THEN
              v_need_by_d           := NULL;
              v_line_is_valid_flag  := 'N';
              v_valid_error_message := '======Line ' || v_line_number ||
                       ' Validation Error:   Need By Date=''' ||
                       v_need_by_date ||
                       ''' SHOULD BE IN FORMAT ''DD-MON-YY''';
              fnd_file.put_line(fnd_file.log, v_valid_error_message);
              RAISE validation_error;
          END;

          v_step := 'Step 18';
          ----check Source inventory organization-------REQUIRED----
          IF v_source_oragnization_code IS NULL THEN
            v_line_is_valid_flag  := 'N';
            v_valid_error_message := '======Line ' || v_line_number ||
                     ' Validation Error:   SOURCE ORGANIZATION is MISSING=========';
            fnd_file.put_line(fnd_file.log, v_valid_error_message);
            RAISE validation_error;
          END IF;
          BEGIN
            SELECT mp.organization_id
            INTO   v_source_organization_id
            FROM   mtl_parameters mp
            WHERE  mp.organization_code = v_source_oragnization_code;
          EXCEPTION
            WHEN no_data_found THEN
              v_source_organization_id := NULL;
              v_line_is_valid_flag     := 'N';
              v_valid_error_message    := '======Line ' || v_line_number ||
                          ' Validation Error:   Source Organization=''' ||
                          v_source_oragnization_code ||
                          ''' DOES NOT EXIST in MTL_PARAMETERS';
              fnd_file.put_line(fnd_file.log, v_valid_error_message);
              RAISE validation_error;
          END;

          IF v_source_subinventory IS NOT NULL THEN
            -------Check Source Subinventory---------
            BEGIN
              v_step := 'Step 18.2';
              SELECT 1
              INTO   v_numeric_dummy
              FROM   mtl_secondary_inventories mseci
              WHERE  mseci.secondary_inventory_name =
                     v_source_subinventory
              AND    mseci.organization_id = v_source_organization_id;
            EXCEPTION
              WHEN no_data_found THEN
                v_line_is_valid_flag  := 'N';
                v_valid_error_message := '======Line ' || v_line_number ||
                         ' Validation Error:   Source Subinventory=''' ||
                         v_source_subinventory ||
                         ''' DOES NOT EXIST in MTL_SECONDARY_INVENTORIES for Source Organization''' ||
                         v_source_oragnization_code ||
                         ''' (organization_id=' ||
                         v_source_organization_id || ')';
                fnd_file.put_line(fnd_file.log, v_valid_error_message);
                RAISE validation_error;
            END;

            ----------------
          END IF;

          v_step := 'Step 20';
          ----check Destination inventory organization-------REQUIRED----
          IF v_dest_oragnization_code IS NULL THEN
            v_line_is_valid_flag  := 'N';
            v_valid_error_message := '======Line ' || v_line_number ||
                     ' Validation Error:   DESTINATION ORGANIZATION is MISSING=========';
            fnd_file.put_line(fnd_file.log, v_valid_error_message);
            RAISE validation_error;
          END IF;
          BEGIN
            SELECT mp.organization_id,
                   mp.material_account
            INTO   v_dest_organization_id,
                   v_charge_account_id
            FROM   mtl_parameters mp
            WHERE  mp.organization_code = v_dest_oragnization_code;
          EXCEPTION
            WHEN no_data_found THEN
              v_dest_organization_id := NULL;
              v_charge_account_id    := NULL;
              v_line_is_valid_flag   := 'N';
              v_valid_error_message  := '======Line ' || v_line_number ||
                        ' Validation Error:   Destination Organization=''' ||
                        v_dest_oragnization_code ||
                        ''' DOES NOT EXIST in MTL_PARAMETERS';
              fnd_file.put_line(fnd_file.log, v_valid_error_message);
              RAISE validation_error;
          END;

          IF v_dest_subinventory IS NOT NULL THEN
            -------Check Source Subinventory---------
            BEGIN
              v_step := 'Step 20.2';
              SELECT 1
              INTO   v_numeric_dummy
              FROM   mtl_secondary_inventories mseci
              WHERE  mseci.secondary_inventory_name = v_dest_subinventory
              AND    mseci.organization_id = v_dest_organization_id;
            EXCEPTION
              WHEN no_data_found THEN
                v_line_is_valid_flag  := 'N';
                v_valid_error_message := '======Line ' || v_line_number ||
                         ' Validation Error:   Source Subinventory=''' ||
                         v_dest_subinventory ||
                         ''' DOES NOT EXIST in MTL_SECONDARY_INVENTORIES for Source Organization''' ||
                         v_dest_oragnization_code ||
                         ''' (organization_id=' ||
                         v_dest_organization_id || ')';
                fnd_file.put_line(fnd_file.log, v_valid_error_message);
                RAISE validation_error;
            END;

            ----------------
          END IF;

          -----Search this item in mtl_system_items_b for source organization...
          BEGIN
            v_step := 'Step 25';
            SELECT msi.inventory_item_id,
                   msi.primary_uom_code
            INTO   v_inventory_item_id,
                   v_primary_uom_code
            FROM   mtl_system_items_b msi
            WHERE  msi.segment1 = v_segment1
            AND    msi.organization_id = v_dest_organization_id;
          EXCEPTION
            WHEN no_data_found THEN
              v_inventory_item_id   := NULL;
              v_primary_uom_code    := NULL;
              v_line_is_valid_flag  := 'N';
              v_valid_error_message := '======Line ' || v_line_number ||
                       ' Validation Error:   Item=''' ||
                       v_segment1 ||
                       ''', Source organization=''' ||
                       v_source_oragnization_code ||
                       ''' (organization_code=' ||
                       v_dest_oragnization_code ||
                       ') DOES NOT EXIST in MTL_SYSTEM_ITEMS_B';
              fnd_file.put_line(fnd_file.log, v_valid_error_message);
              RAISE validation_error;
          END;

	      v_step := 'Step 27';
          ----check Unit of Measure-------REQUIRED----
          IF v_unit_of_measure IS NULL THEN
            v_line_is_valid_flag  := 'N';
            v_valid_error_message := '======Line ' || v_line_number ||
                     ' Validation Error:   UNIT OF MEASURE is MISSING=========';
            fnd_file.put_line(fnd_file.log, v_valid_error_message);
            RAISE validation_error;
          END IF;
          BEGIN
            SELECT 1
            INTO   v_numeric_dummy
            FROM   mtl_units_of_measure uom
            WHERE  uom.uom_code = v_unit_of_measure;
          EXCEPTION
            WHEN no_data_found THEN
              v_line_is_valid_flag  := 'N';
              v_valid_error_message := '======Line ' || v_line_number ||
                       ' Validation Error:   UNIT OF MEASURE=''' ||
                       v_unit_of_measure ||
                       ''' DOES NOT EXIST in MTL_UNITS_OF_MEASURE';
              fnd_file.put_line(fnd_file.log, v_valid_error_message);
              RAISE validation_error;
          END;

          ----------Check Quantity-----------------REQUIRED----------------
          v_step := 'Step 30';
          IF v_quantity IS NULL THEN
            v_line_is_valid_flag  := 'N';
            v_valid_error_message := '======Line ' || v_line_number ||
                     ' Validation Error:   QUANTITY is MISSING=========';
            fnd_file.put_line(fnd_file.log, v_valid_error_message);
            RAISE validation_error;
          END IF;
          --------
          BEGIN
            v_qty := to_number(v_quantity);
          EXCEPTION
            WHEN OTHERS THEN
              v_line_is_valid_flag  := 'N';
              v_valid_error_message := '======Line ' || v_line_number ||
                       ' Validation Error:   QUANTITY SHOULD BE NUMERIC VALUE';
              fnd_file.put_line(fnd_file.log, v_valid_error_message);
              RAISE validation_error;
          END;
          --------
          --------
          IF v_qty <= 0 THEN
            v_line_is_valid_flag  := 'N';
            v_valid_error_message := '======Line ' || v_line_number ||
                     ' Validation Error:   QUANTITY SHOULD BE POSITIVE NUMERIC VALUE > 0';
            fnd_file.put_line(fnd_file.log, v_valid_error_message);
            RAISE validation_error;
          END IF;

          -------Check Location------REQUIRED--------------------
          IF v_location IS NULL THEN
            v_line_is_valid_flag  := 'N';
            v_valid_error_message := '======Line ' || v_line_number ||
                     ' Validation Error:   LOCATION is MISSING=========';
            fnd_file.put_line(fnd_file.log, v_valid_error_message);
            RAISE validation_error;
          END IF;
          -----------
          BEGIN
            v_step := 'Step 35';
            SELECT loc.location_id
            INTO   v_location_id
            FROM   hr_locations loc
            WHERE  loc.location_code = v_location;

          EXCEPTION
            WHEN no_data_found THEN
              v_location_id         := NULL;
              v_line_is_valid_flag  := 'N';
              v_valid_error_message := '======Line ' || v_line_number ||
                       ' Validation Error:   LOCATION=' ||
                       v_location ||
                       ' DOES NOT EXIST in HR_LOCATIONS';
              fnd_file.put_line(fnd_file.log, v_valid_error_message);
              RAISE validation_error;
          END;

          -- Get employee_id (not curr user) for name validation (Gabriel) --
          -- 26/03/2014 Dalit A. Raviv
          v_step := 'Step 38';
          BEGIN
            SELECT pap.person_id
            INTO   v_req_id
            FROM   per_all_people_f pap
            WHERE  pap.last_name = v_requestor -- 'Hanke'
            AND    pap.first_name = v_req_lname --  'Holger'
            AND    trunc(SYSDATE) BETWEEN pap.effective_start_date AND
                   pap.effective_end_date;
            -- 26/03/2014 Dalit A. Raviv
          EXCEPTION
            WHEN no_data_found THEN
              v_req_id              := NULL;
              v_valid_error_message := ' Validation Error for employee ' ||
                       v_requestor || ', ' || v_req_lname;
              fnd_file.put_line(fnd_file.log, v_valid_error_message);
              RAISE validation_error;
          END;

          fnd_file.put_line(fnd_file.log,
                    'Employee ID  : ' || v_req_id || '---(' ||
                    length(v_req_id) || ')'); -- Gabriel 15/10

          -- Get item_revision (Gabriel) --
          v_step := 'Step 39';
          BEGIN
            SELECT MAX(a.revision)
            INTO   v_item_revision
            FROM   mtl_item_revisions a
            WHERE  a.inventory_item_id = v_inventory_item_id
            AND    a.organization_id = v_source_organization_id
            AND    a.effectivity_date =
                   (SELECT MAX(b.effectivity_date)
                     FROM   mtl_item_revisions b
                     WHERE  b.inventory_item_id = v_inventory_item_id
                     AND    b.organization_id = v_source_organization_id
                     AND    v_need_by_d > b.effectivity_date);
          EXCEPTION
            WHEN no_data_found THEN
              v_item_revision       := NULL;
              v_valid_error_message := ' Validation Error for Item Revision ' ||
                       v_item_revision;
              fnd_file.put_line(fnd_file.log, v_valid_error_message);
              RAISE validation_error;
          END;

          fnd_file.put_line(fnd_file.log,
                    'Item Revision  : ' || v_item_revision ||
                    '---(' || length(v_item_revision) || ')'); -- Gabriel 15/10

          /*-- Commented for CHG0044329
          fnd_file.put_line(fnd_file.log,
                    'Justification  : ' || v_justification ||
                    '---(' || length(v_justification) || ')');*/ -- Added on 05.06.17 for CHG0040751
                ----Air shipments - reason Validation Added on 19.09.18 for CHG0043850 **START***
            v_step := 'Step 40.0';
            If v_air_shipment_reason is not Null Then
              IF length(v_air_shipment_reason) > 240 THEN
                 v_line_is_valid_flag  := 'N';
                 v_valid_error_message :='======Line ' || v_line_number ||
                                         ' Validation Error:   Air shipments - Reason is TOO LONG (more than 240 characters)    (length=' ||
                                           length(v_air_shipment_reason) || ')=========';
                 fnd_file.put_line(fnd_file.log, v_valid_error_message);
                 RAISE validation_error;
              Else
                 Begin
                    select ffvv.DESCRIPTION
                    into  v_air_shipment_reason
                    from
                    fnd_flex_values_vl ffvv,
                    fnd_flex_value_sets ffvs
                    Where ffvv.FLEX_VALUE_SET_ID = ffvs.FLEX_VALUE_SET_ID
                    and ffvs.flex_value_set_name  = 'XX_PO_AIR_SHIPMENT_REASON'
                    and upper(ffvv.DESCRIPTION) = upper(v_air_shipment_reason)
                    and nvl(enabled_flag,'N') = 'Y';
                 Exception
                 When no_data_found Then
                   v_valid_error_message :='======Line ' || v_line_number ||
                                         ' Validation Error: Air shipments - Reason is not a valid Reason,'||
                                         ' not exists in XX_PO_AIR_SHIPMET_REASON Value Set.Reason=' ||
                                           v_air_shipment_reason || ')=========';
                   fnd_file.put_line(fnd_file.log, v_valid_error_message);
                   RAISE validation_error;
                 End;
              End If;
            End if;
             /*-- Commented for CHG0044329
             fnd_file.put_line(fnd_file.log,
                  'Air shipments - Reason  : ' || v_air_shipment_reason ||
                  '---(' || length(v_air_shipment_reason) || ')');*/
            -----------CHG0043850 **END***

          EXCEPTION
	       WHEN validation_error THEN
            IF NOT
                (v_line_number = 1 AND p_ignore_first_headers_line = 'Y') THEN
              v_there_are_non_valid_rows := 'Y';
            END IF;
	         fnd_file.put_line(fnd_file.log, ''); ---empty line
          END;

          -----CHG0036436
          v_step := 'Step 39.5';
          IF v_suggested_vendor_name IS NOT NULL THEN
	       --CHG0036436
            BEGIN
              SELECT asp.vendor_id
              INTO   l_vendor_id
              FROM   ap_suppliers asp
              WHERE  asp.vendor_name = v_suggested_vendor_name
              and nvl(enabled_flag, 'Y')= 'Y';   --CHG0044329

              BEGIN
                IF v_suggested_vendor_site IS NOT NULL THEN
                  SELECT assa.vendor_site_id
                  INTO   l_vendor_site_id
                  FROM   ap_supplier_sites_all assa
                  WHERE  assa.vendor_id = l_vendor_id
                  AND    assa.org_id = v_org_id
                  AND    assa.vendor_site_code = v_suggested_vendor_site;
                End If;
              EXCEPTION
                WHEN no_data_found THEN
                 --CHG0044329
                  v_valid_error_message :='======Line ' || v_line_number ||
                                         ' Vendor Site Name :'||
                                           v_suggested_vendor_site || '  is not found.';
                   fnd_file.put_line(fnd_file.log, v_valid_error_message);

              END;
            EXCEPTION
              WHEN no_data_found THEN
              -- CHG0044329
                   v_valid_error_message :='======Line ' || v_line_number ||
                                         ' Vendor Name :'||
                                           v_suggested_vendor_name || '  is not found.';
                   fnd_file.put_line(fnd_file.log, v_valid_error_message);

            END;
          END IF;

          ---=============the end of validations=================
          IF v_line_is_valid_flag = 'N' THEN
	        v_num_of_non_valid_lines := v_num_of_non_valid_lines + 1;
          ELSE
	        v_num_of_valid_lines := v_num_of_valid_lines + 1;
          END IF;

          IF v_line_is_valid_flag = 'Y' AND p_mode <> 'VALIDATE_ONLY' AND
	        NOT (v_line_number = 1 AND p_ignore_first_headers_line = 'Y') THEN
	         ---***************** Run API for upload this requisition ************************
	        v_step := 'Step 40';
            --------
            BEGIN
              INSERT INTO po_requisitions_interface_all
                (batch_id,
                 header_description,
                 item_id,
                 item_revision,
                 need_by_date,
                 quantity,
                 org_id,
                 created_by,
                 creation_date,
                 last_updated_by,
                 last_update_date,
                 last_update_login,
                 destination_organization_id,
                 destination_subinventory,
                 deliver_to_location_id,
                 preparer_id,
                 charge_account_id,
                 source_organization_id,
                 source_subinventory,
                 uom_code,
                 deliver_to_requestor_name, -- Added 13/10 Gabriel
                 deliver_to_requestor_id, -- Added 15/10 Gabriel for employee_id
                 authorization_status,
                 source_type_code, -- VENDOR
                 destination_type_code, --  INVENTORY
                 interface_source_code, --'FORM'
                 project_accounting_context, -- N
                 vmi_flag, --  N
                 autosource_flag, -- Y
                 suggested_vendor_name, --CHG0036436
                 suggested_vendor_site, --CHG0036436
                 suggested_vendor_id, --CHG0036436
                 suggested_vendor_site_id, --CHG0036436
                 justification -- Added on 05.06.17 for CHG0040751
                 ,line_attribute4 --Added on 19Sep2018 for CHG0043850
                 )
              VALUES
                (v_batch_id,
                 v_comments, -----header_description,
                 v_inventory_item_id,
                 NULL, --v_item_revision,
                 --                 xxinv_utils_pkg.get_current_revision(v_inventory_item_id,
                 --                                                      v_source_organization_id), -- Added 13/10 Gabriel --  NULL, ----item_revision,
                 v_need_by_d,
                 v_qty, -----quantity,
                 v_org_id,
                 fnd_global.user_id, ----created_by,
                 SYSDATE, ----creation_date,
                 fnd_global.user_id, ----last_updated_by,
                 SYSDATE, ----last_update_date,
                 fnd_global.login_id, ----last_update_login,
                 v_dest_organization_id,
                 NULL,
                 v_location_id, ----deliver_to_location_id,
                 v_user_employee_id, ----preparer_id,
                 v_charge_account_id,
                 NULL,
                 NULL,
                 --                 v_unit_of_measure, -- Added 13/10
                 v_primary_uom_code, -- Added 13/10
                 v_requestor || ', ' || v_req_lname, -- Updated 14/10 Gabriel
                 v_req_id, -- v_user_employee_id, ----deliver_to_requestor_id, -- Updated 15/10 Gabriel
                 -- v_user_employee_id, ----deliver_to_requestor_id,
                 'INCOMPLETE', ----authorization_status,
                 'VENDOR', ----source_type_code,
                 'INVENTORY', ----destination_type_code,
                 'FILEPO', ----interface_source_code,
                 'N', ----project_accounting_context,
                 'N', ----vmi_flag,
                 'P', ---- was 'Y'    --CHG0036436 ----autosource_flag,
                 v_suggested_vendor_name, --CHG0036436
                 v_suggested_vendor_site, --CHG0036436
                 l_vendor_id, --CHG0036436
                 l_vendor_site_id, --CHG0036436
                 v_justification -- Added on 05.06.17 for CHG0040751
                 ,v_air_shipment_reason    --Added on 19Sep2018 for CHG0043850
                 );
              -----COMMIT;
              v_num_of_success_ins_lines := v_num_of_success_ins_lines + 1;
            EXCEPTION
              WHEN OTHERS THEN
                v_num_of_failured_ins_lines := v_num_of_failured_ins_lines + 1;
                fnd_file.put_line(fnd_file.log,
                          '**************Line ' || v_line_number ||
                          ' INSERT into po_requisitions_interface_all ERROR : ' ||
                          SQLERRM);
            END;
	------------
          END IF;
          ---***********the end of Run API for upload requisition ************************
        END IF;
      END LOOP;

    EXCEPTION
      WHEN no_data_found THEN
        fnd_file.put_line(fnd_file.log,
		  '##############  No more data to read  #################');
    END;
    -----------------

    IF p_mode <> 'VALIDATE_ONLY' THEN
      IF v_there_are_non_valid_rows = 'N' THEN
        COMMIT;
        ---- fnd_file.put_line (fnd_file.log, '********************************* COMMIT *****************************');
      ELSE
        ROLLBACK;
        ----- fnd_file.put_line (fnd_file.log, '***************** ROLLBACK (there are non valid rows in Your file ***********************');
      END IF;
    END IF;

    ------------------Close flat file----------------------------
    utl_file.fclose(v_file);

    IF p_mode <> 'VALIDATE_ONLY' AND v_there_are_non_valid_rows = 'N' AND
       p_launch_import_requisition = 'Y' THEN
      --------------
      BEGIN
        SELECT a.application_short_name
        INTO   l_app_short_name
        FROM   fnd_application a
        WHERE  a.application_id = fnd_global.resp_appl_id;

        FOR org_id_rec IN get_interface_org_id(v_batch_id) LOOP
          --------------------------------------------
          mo_global.set_org_context(p_org_id_char     => org_id_rec.org_id,
			p_sp_id_char      => NULL,
			p_appl_short_name => l_app_short_name);

          fnd_request.set_org_id(org_id_rec.org_id);

          v_request_id := fnd_request.submit_request(application => 'PO',
				     program     => 'REQIMPORT',
				     argument1   => 'FILEPO', ---interface_source_code
				     argument2   => v_batch_id, ---batch_id
				     argument3   => 'ALL',
				     argument4   => 0,
				     argument5   => 'N',
				     argument6   => 'N');
          COMMIT;
          fnd_file.put_line(fnd_file.log, ''); --empty line
          fnd_file.put_line(fnd_file.log,
		    '=============== ''Requisition Import'' was submitted for ' ||
		    org_id_rec.operating_unit || ' (' ||
		    org_id_rec.num_of_rows_for_org_id ||
		    ' rows with interface_source_code=''FILE'' and batch_id=' ||
		    v_batch_id || ')================');
          fnd_file.put_line(fnd_file.log, ''); --empty line
        --------------------------------------------
        END LOOP;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      --------------
    END IF; ----IF p_launch_import_requisition='Y' ...

    ------------------Display total information about this updload...----------------------------
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
	          '***************************************************************************');
    fnd_file.put_line(fnd_file.log,
	          '********************TOTAL INFORMATION******************************');
    fnd_file.put_line(fnd_file.log,
	          '***************************************************************************');
    fnd_file.put_line(fnd_file.log,
	          '=========There are ' || v_line_number ||
	          ' lines in our file ' || p_location || '/' ||
	          p_filename);
    fnd_file.put_line(fnd_file.log,
	          '=============' || v_num_of_non_valid_lines ||
	          ' LINES ARE NON-VALID');
    fnd_file.put_line(fnd_file.log,
	          '=============' || v_num_of_success_ins_lines ||
	          ' Requisitions were SUCCESSFULY INSERTED into PO_REQUISITIONS_INTERFACE_ALL table');
    fnd_file.put_line(fnd_file.log,
	          '=============' || v_num_of_failured_ins_lines ||
	          ' for these lines INSERT was FAILURED');
    fnd_file.put_line(fnd_file.log, ''); --empty line

    IF p_mode <> 'VALIDATE_ONLY' THEN
      IF v_there_are_non_valid_rows = 'N' THEN
        fnd_file.put_line(fnd_file.log,
		  '********************************* COMMIT *****************************');
      ELSE
        fnd_file.put_line(fnd_file.log,
		  '***************** ROLLBACK (there are non valid rows in Your file) ***********************');
      END IF;
    END IF;

    IF v_there_are_non_valid_rows = 'Y' THEN
      errcode := '1'; ---Warning
    ELSE
      errcode := '0'; ---Success
    END IF;

  EXCEPTION
    WHEN stop_processing THEN
      NULL;
    WHEN OTHERS THEN
      v_error_message := ' =============XXPO_UTILS_PKG.upload_internal_requisitions unexpected ERROR (' ||
		 v_step || ' (utl-file line=' || v_line_number ||
		 ') : ' || SQLERRM;
      errcode         := '2';
      errbuf          := v_error_message;
      fnd_file.put_line(fnd_file.log, v_error_message);
  END upload_purchase_requisitions;

  PROCEDURE create_internal_requisition(p_po_header_id      po_headers_all.po_header_id%TYPE,
			    p_po_number         po_headers_all.segment1%TYPE,
			    p_preparer_id       po_headers_all.agent_id%TYPE,
			    p_subinventory_code mtl_secondary_inventories.secondary_inventory_name%TYPE,
			    p_location_id       hr_locations_all.location_id%TYPE,
			    p_assembly_id       mtl_system_items_b.inventory_item_id%TYPE,
			    p_po_line_id        po_lines_all.po_line_id%TYPE,
			    p_item_id           mtl_system_items_b.inventory_item_id%TYPE,
			    p_organization_id   mtl_parameters.organization_id%TYPE,
			    p_need_by_date      DATE,
			    p_quantity          NUMBER,
			    p_org_id            NUMBER,
			    p_user_id           NUMBER,
			    p_resp_id           NUMBER,
			    p_resp_appl_id      NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;

    l_app_short_name fnd_application.application_short_name%TYPE;
    l_request_id     NUMBER;

  BEGIN

    fnd_global.apps_initialize(user_id      => p_user_id,
		       resp_id      => p_resp_id,
		       resp_appl_id => p_resp_appl_id);

    SELECT a.application_short_name
    INTO   l_app_short_name
    FROM   fnd_application a
    WHERE  a.application_id = p_resp_appl_id;

    mo_global.set_org_context(p_org_id_char     => p_org_id,
		      p_sp_id_char      => NULL,
		      p_appl_short_name => l_app_short_name);

    INSERT INTO po_requisitions_interface_all
      (batch_id,
       header_description,
       item_id,
       item_revision,
       need_by_date,
       quantity,
       org_id,
       created_by,
       creation_date,
       last_updated_by,
       last_update_date,
       last_update_login,
       destination_organization_id,
       destination_subinventory,
       deliver_to_location_id,
       preparer_id,
       charge_account_id,
       source_organization_id,
       uom_code,
       deliver_to_requestor_id,
       authorization_status,
       source_type_code, -- INVENTORY
       destination_type_code, --  INVENTORY
       interface_source_code, --'FORM'
       project_accounting_context, -- N
       vmi_flag, --  N
       autosource_flag) -- P
      SELECT p_po_header_id,
	 'PO: ' || p_po_number,
	 bic.component_item_id,
	 xxinv_utils_pkg.get_current_revision(bic.component_item_id,
				  mp.organization_id),
	 p_need_by_date,
	 bic.component_quantity * p_quantity,
	 p_org_id,
	 p_user_id,
	 SYSDATE,
	 p_user_id,
	 SYSDATE,
	 fnd_global.login_id,
	 mp.organization_id,
	 p_subinventory_code,
	 p_location_id,
	 p_preparer_id,
	 mp.material_account,
	 mp.organization_id,
	 msi.primary_uom_code,
	 nvl(mpl.employee_id, p_preparer_id),
	 'INCOMPLETE',
	 'INVENTORY',
	 'INVENTORY',
	 'NJRC',
	 'N',
	 'N',
	 'P'
      FROM   bom_bill_of_materials    bbom,
	 bom_inventory_components bic,
	 mtl_system_items_b       msi,
	 mtl_parameters           mp,
	 mtl_planners             mpl
      WHERE  bbom.assembly_item_id = p_assembly_id
      AND    bbom.organization_id = mp.organization_id
      AND    bbom.bill_sequence_id = bic.bill_sequence_id
      AND    bic.component_item_id != p_item_id
      AND    bic.component_item_id = msi.inventory_item_id
      AND    bbom.organization_id = msi.organization_id
      AND    msi.planner_code = mpl.planner_code(+)
      AND    msi.organization_id = mpl.organization_id(+)
      AND    mp.organization_id = p_organization_id;

    COMMIT;

    l_request_id := fnd_request.submit_request(application => 'PO',
			           program     => 'REQIMPORT',
			           argument1   => 'NJRC',
			           argument2   => p_po_header_id,
			           argument3   => 'ALL',
			           argument4   => NULL,
			           argument5   => 'N',
			           argument6   => 'Y');

    COMMIT;
  END create_internal_requisition;

  PROCEDURE create_njrc_requisition(itemtype  IN VARCHAR2,
			itemkey   IN VARCHAR2,
			actid     IN NUMBER,
			funcmode  IN VARCHAR2,
			resultout OUT NOCOPY VARCHAR2) IS

    -- all line with NJRC category in PO
    CURSOR csr_njrc_items(p_document_id po_headers_all.po_header_id%TYPE) IS
      SELECT pl.po_line_id,
	 pl.item_id,
	 pll.ship_to_organization_id,
	 nvl(pll.need_by_date, pll.promised_date) need_by_date,
	 pl.quantity,
	 pl.org_id
      FROM   po_lines_all          pl,
	 po_line_locations_all pll,
	 mtl_item_categories   mic
      WHERE  pl.po_header_id = p_document_id
      AND    pl.po_line_id = pll.po_line_id
      AND    nvl(pl.cancel_flag, 'N') = 'N'
      AND    pl.item_id = mic.inventory_item_id
      AND    mic.organization_id =
	 xxinv_utils_pkg.get_master_organization_id
      AND    mic.category_id = fnd_profile.value('XXPO_NJRC_CATEGORY');

    cur_line csr_njrc_items%ROWTYPE;

    l_po_header_id      po_headers_all.po_header_id%TYPE;
    l_po_number         po_headers_all.segment1%TYPE;
    l_preparer_id       po_headers_all.agent_id%TYPE;
    l_bom_id            mtl_system_items_b.inventory_item_id%TYPE;
    l_subinventory_code mtl_secondary_inventories.secondary_inventory_name%TYPE;
    l_location_id       mtl_secondary_inventories.location_id%TYPE;

    l_user_id      NUMBER;
    l_resp_id      NUMBER;
    l_resp_appl_id NUMBER;

  BEGIN

    -- Do nothing in cancel or timeout mode
    IF (funcmode <> wf_engine.eng_run) THEN

      resultout := wf_engine.eng_null;
      RETURN;

    END IF;

    l_po_header_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				  itemkey  => itemkey,
				  aname    => 'DOCUMENT_ID');

    l_po_number := wf_engine.getitemattrtext(itemtype => itemtype,
			         itemkey  => itemkey,
			         aname    => 'DOCUMENT_NUMBER');

    l_preparer_id := wf_engine.getitemattrtext(itemtype => itemtype,
			           itemkey  => itemkey,
			           aname    => 'PREPARER_ID');

    l_user_id      := wf_engine.getitemattrnumber(itemtype => itemtype,
				  itemkey  => itemkey,
				  aname    => 'USER_ID');
    l_resp_id      := wf_engine.getitemattrnumber(itemtype => itemtype,
				  itemkey  => itemkey,
				  aname    => 'RESPONSIBILITY_ID');
    l_resp_appl_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				  itemkey  => itemkey,
				  aname    => 'APPLICATION_ID');

    FOR cur_line IN csr_njrc_items(l_po_header_id) LOOP

      BEGIN

        SELECT si.secondary_inventory_name,
	   si.location_id
        INTO   l_subinventory_code,
	   l_location_id
        FROM   po_headers_all            poh,
	   mtl_secondary_inventories si
        WHERE  poh.vendor_site_id = si.attribute1
        AND    poh.po_header_id = l_po_header_id
        AND    si.organization_id = cur_line.ship_to_organization_id;

        resultout := wf_engine.eng_completed || ':SUCCESS';

      EXCEPTION
        WHEN OTHERS THEN
          RETURN;
      END;

      --find BOM, if find more that one raise error
      SELECT bill.assembly_item_id
      INTO   l_bom_id
      FROM   bom_bill_of_materials    bill,
	 bom_inventory_components comp
      WHERE  bill.organization_id = cur_line.ship_to_organization_id
      AND    bill.bill_sequence_id = comp.bill_sequence_id
      AND    comp.component_item_id = cur_line.item_id
      AND    SYSDATE BETWEEN comp.effectivity_date AND
	 nvl(comp.disable_date, SYSDATE + 1);

      --find all component in njrc item level and create int req
      create_internal_requisition(l_po_header_id,
		          l_po_number,
		          l_preparer_id,
		          l_subinventory_code,
		          l_location_id,
		          l_bom_id,
		          cur_line.po_line_id,
		          cur_line.item_id,
		          cur_line.ship_to_organization_id,
		          cur_line.need_by_date,
		          cur_line.quantity,
		          cur_line.org_id,
		          l_user_id,
		          l_resp_id,
		          l_resp_appl_id);

    END LOOP;

    resultout := wf_engine.eng_completed || ':SUCCESS';

  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXPO_WF_NOTIFICATION_PKG',
	          'CREATE_NJRC_REQUISITION',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode,
	          'Error in assembly',
	          'PO: ' || l_po_number,
	          SQLERRM);
      RAISE;

  END create_njrc_requisition;

  PROCEDURE check_is_njrc_req_needed(itemtype  IN VARCHAR2,
			 itemkey   IN VARCHAR2,
			 actid     IN NUMBER,
			 funcmode  IN VARCHAR2,
			 resultout OUT NOCOPY VARCHAR2) IS

    l_req_needed        VARCHAR2(1) := 'N';
    l_document_id       NUMBER;
    l_document_type     VARCHAR2(20);
    l_document_sub_type VARCHAR2(20);

  BEGIN

    -- Do nothing in cancel or timeout mode
    IF (funcmode <> wf_engine.eng_run) THEN

      resultout := wf_engine.eng_null;
      RETURN;

    END IF;

    l_document_id       := wf_engine.getitemattrnumber(itemtype => itemtype,
				       itemkey  => itemkey,
				       aname    => 'DOCUMENT_ID');
    l_document_type     := wf_engine.getitemattrtext(itemtype => itemtype,
				     itemkey  => itemkey,
				     aname    => 'DOCUMENT_TYPE'); -- 'PO'
    l_document_sub_type := wf_engine.getitemattrtext(itemtype => itemtype,
				     itemkey  => itemkey,
				     aname    => 'DOCUMENT_SUBTYPE'); -- 'STANDARD'

    IF l_document_type = 'PO' AND l_document_sub_type = 'STANDARD' THEN

      BEGIN

        SELECT 'Y'
        INTO   l_req_needed
        FROM   po_lines_all        pl,
	   mtl_item_categories mic
        WHERE  po_header_id = l_document_id
        AND    nvl(pl.cancel_flag, 'N') = 'N'
        AND    pl.item_id = mic.inventory_item_id
        AND    mic.organization_id =
	   xxinv_utils_pkg.get_master_organization_id
        AND    mic.category_id = fnd_profile.value('XXPO_NJRC_CATEGORY')
        AND    rownum < 2;

      EXCEPTION
        WHEN no_data_found THEN
          l_req_needed := 'N';
      END;

    ELSE
      -- not l_document_type = 'PO' AND l_document_sub_type = 'STANDARD'
      l_req_needed := 'N';
    END IF;

    resultout := wf_engine.eng_completed || ':' || l_req_needed;

  END check_is_njrc_req_needed;

END xxpo_req_interfaces_pkg;
/
