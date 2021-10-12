create or replace package body xxconv_ar_upload_invoice_pkg is

  type tbl_of_str is table of varchar2(2000) index by binary_integer;
  g_interface_line_context varchar2(50) := 'RTLX_IMPORTED_INVOICES';
  g_batch_source_name      varchar2(50) := 'RTX INC Imported Invoices2';
  g_cust_trx_type          varchar2(50) := 'Retalix INC INV';
  g_line_type              varchar2(50) := 'LINE';

  procedure load_file(p_file_name     in varchar2,
                      x_error_message out varchar2) is
    l_file      utl_file.file_type;
    l_line      varchar2(32000);
    l_line_data tbl_of_str;

    l_bill_to_cust_id number;
    l_ship_to_cust_id number;
    l_bill_to_site_id number;
    l_ship_to_site_id number;

    l_pos1 number;
    l_pos2 number;
  begin
    -- Open file
    begin
      l_file := utl_file.fopen(fnd_profile.value('XXRTX_LOAD_PATH'),
                               p_file_name,
                               'r');
    exception
      when others then
        x_error_message := 'Error openning file: ' || sqlerrm;
        return;
    end;
    -- Ignore first 8 rows of file
    for i in 1 .. 8 loop
      utl_file.get_line(l_file, l_line);
    end loop;

    -- Load file to temp table
    begin
      loop
        l_pos1 := 0;
        l_pos2 := 1;
        for i in 1 .. 13 loop
          l_line_data(i) := null;
        end loop;
        l_bill_to_cust_id := null;
        l_ship_to_cust_id := null;
        l_bill_to_site_id := null;
        l_ship_to_site_id := null;
        utl_file.get_line(l_file, l_line);

        -- Parse line data
        for i in 1 .. 17 loop
          l_pos1 := instr(l_line, ',', l_pos2);
          l_pos2 := instr(l_line, ',', l_pos1 + 1);
          if i = 1 then
            l_pos2 := l_pos1;
            l_line_data(i) := substr(l_line, 1, l_pos1 - 1);
          elsif i < 17 then
            l_line_data(i) := substr(l_line,
                                     l_pos1 + 1,
                                     l_pos2 - l_pos1 - 1);
          else
            l_line_data(i) := substr(l_line, l_pos1 + 1);
          end if;
        end loop;
        begin
          select customer_id
            into l_bill_to_cust_id
            from ar_customers_all_v
           where customer_name = l_line_data(3);
          select cas.cust_acct_site_id
            into l_bill_to_site_id
            from hz_party_sites ps, Hz_Cust_Acct_Sites_All cas
           where ps.party_site_id = cas.party_site_id
             and party_site_number = l_line_data(4);
          if l_line_data(5) is not null then
            select customer_id
              into l_ship_to_cust_id
              from ar_customers_all_v
             where customer_name = l_line_data(5);
          end if;
          if l_line_data(6) is not null then
            select cas.cust_acct_site_id
              into l_ship_to_site_id
              from hz_party_sites ps, Hz_Cust_Acct_Sites_All cas
             where ps.party_site_id = cas.party_site_id
               and party_site_number = l_line_data(6);
          end if;
        exception
          when others then
            null;
        end;
        -- Insert to interface table
        INSERT INTO ra_interface_lines_all
          (interface_line_context,
           interface_line_attribute1,
           interface_line_attribute2,
           interface_line_attribute3,
           uom_code,
           batch_source_name,
           set_of_books_id,
           org_id,
           line_type,
           currency_code,
           cust_trx_type_name,
           term_name,
           orig_system_bill_customer_id,
           orig_system_bill_address_id,
           orig_system_ship_customer_id,
           orig_system_ship_address_id,
           line_number,
           amount,
           quantity,
           unit_Selling_price,
           trx_date,
           mtl_system_items_seg1,
           description,
           conversion_type,
           conversion_date,
           conversion_rate,
           amount_includes_tax_flag,
           creation_date,
           created_by)
        VALUES
          (g_interface_line_context, --interface_line_context,
           l_line_data(1), --interface_line_attribute1,
           l_line_data(2), --interface_line_attribute2,
           l_line_data(11), --interface_line_attribute3,
           l_line_data(12), -- uom_code,
           g_batch_source_name, -- batch_source_name
           fnd_profile.value('GL_SET_OF_BKS_ID'), --set_of_books_id,
           fnd_global.org_id, --org_id,
           g_line_type, --g_line_type, -- line_type
           l_line_data(7), -- currency_code
           g_cust_trx_type, -- cust_trx_type
           l_line_data(9), -- Payment_term,
           l_bill_to_cust_id, --orig_system_bill_customer_id,
           l_bill_to_site_id, --orig_system_bill_address_id,
           l_ship_to_cust_id, --orig_system_ship_customer_id,
           l_ship_to_site_id, --orig_system_ship_address_id,
           l_line_data(10), -- line_number
           l_line_data(15), -- amount,
           l_line_data(13), -- quantity,
           l_line_data(14), -- unit_Selling_price,
           l_line_data(2), --trx_date,
           l_line_data(11), -- mtl_system_items_seg1,
           l_line_data(17), -- description,
           'User', --conversion_type,
           l_line_data(2), --conversion_date,
           1, --conversion_rate
           'N', -- amount_includes_tax_flag
           sysdate, -- creation date
           fnd_global.user_id -- created by
           );
      end loop;
    exception
      when no_data_found then
        -- End of file
        if utl_file.is_open(l_file) then
          utl_file.fclose(l_file);
        end if;
      when others then
        x_error_message := 'Error reading file: ' || sqlerrm;
        rollback;
        if utl_file.is_open(l_file) then
          utl_file.fclose(l_file);
        end if;
    end;
    commit;
  exception
    when others then
      x_error_message := 'Unexpected error: ' || sqlerrm;
      rollback;
      if utl_file.is_open(l_file) then
        utl_file.fclose(l_file);
      end if;
  end load_file;
  
Procedure Ascii_ARInvoiceInt (errbuf                   out varchar2, 
                              retcode                  out varchar2,
                              p_location               in varchar2,
                              p_filename               in varchar2,
                              p_processLines           in char)
Is

    Type
         v_Read_rec  is record (Operating_Unit_Id  hr_operating_units.organization_id%type,
                                Invoice_Number     ra_customer_trx_all.trx_number%type,
                                InvoiceDate        Varchar2(10),
                                BillToCustomer     ar_customers_all_v.customer_name%type,
                                BillToCustomerId   ar_customers_all_v.customer_id%type,
                                BillToCusSite      Hz_Cust_Acct_Sites_All.Orig_System_Reference%type,
                                BillToCusSiteId    Hz_Cust_Acct_Sites_All.cust_acct_site_id%type,
                                ShipToCustomer     ar_customers_all_v.customer_name%type,
                                ShipToCustomerId   ar_customers_all_v.customer_id%type,
                                ShipToCusSite      Hz_Cust_Acct_Sites_All.Orig_System_Reference%type,
                                ShipToCusSiteId    Hz_Cust_Acct_Sites_All.cust_acct_site_id%type,
                                CurrencyCode       ra_customer_trx_all.invoice_currency_code%type,
                                GlDate             Varchar2(10),
                                PaymentDate        Varchar2(10), -- Obsolete For DC
                                PaymentTerms       ra_terms.description%type,
                                PaymentTermsId     ra_interface_lines_all.term_id%type,
                                LineNumber         ra_interface_lines_all.line_number%type,
                                ItemCode           mtl_system_items_b.segment1%type, -- Obsolete For DC
                                ItemId             mtl_system_items_b.inventory_item_id%type, -- Obsolete For DC
                                UOM                mtl_system_items_b.primary_uom_code%type, -- Obsolete For DC
                                LineQuantity       ra_interface_lines_all.quantity%type, -- Obsolete For DC
                                UnitPrice          ra_interface_lines_all.unit_selling_price%type, -- Obsolete For DC
                                OutStandingSum     ra_interface_lines_all.unit_selling_price%type,
                                TaxCode            ra_interface_lines_all.tax_code%type,
                                InvoiceDesc        ra_interface_lines_all.description%type,
                                OperatingUnit      mtl_organizations.ORGANIZATION_NAME%type,
                                cust_trx_type      ra_interface_lines_all.cust_trx_type_name%type,
                                cust_trx_typeID    ra_interface_lines_all.cust_trx_type_id%type,
                                batchSourceName    ra_batch_sources_all.name%type,
                                ReferenceField     ra_interface_lines_all.interface_line_attribute1%type,
                                conversion_type    ra_interface_lines_all.conversion_type%type,
                                conversion_date    Varchar2(10),
                                LineRetCode        Varchar2(10),
                                LineErrBuf         Varchar2(2000)
                               );
    Type
        v_Read_tab    is table of v_Read_rec index by binary_integer;
    
  v_Read_array             v_Read_tab;
  v_user_id                fnd_user.user_id%TYPE;
  v_login_id               fnd_logins.login_id%type;
  v_prevInvoiceNum         ra_customer_trx_all.trx_number%type := '@@@';

  v_Read_file              utl_file.file_type;
  v_read_code              number(5) := 1;
  v_line_buf               varchar2(2000);
  v_tmp_line               varchar2(2000);
  v_delimiter              char(1) := ',';
  v_place                  number(3);
  v_counter                number := 0;
  v_LineErrbuf             Varchar2(2000);
  v_LineRetCode            Varchar2(10);
  v_dummyDate              Date;
  v_Gen_ItemID             mtl_system_items_b.inventory_item_id%type;
  v_Gen_UOM                mtl_system_items_b.primary_uom_code%type;
  v_Gen_Desc               mtl_system_items_b.description%type;
Begin
  -- Open the given file for reading
  Begin
     v_Read_file := utl_file.fopen (location => p_location, filename => p_filename, open_mode => 'r');
     fnd_file.put_line (fnd_file.log, 'File '||ltrim(rtrim(p_location))||'/'||ltrim(rtrim(p_filename))||' Opened');
  Exception
    when utl_file.invalid_path then
      errbuf := 'Invalid Path for '||ltrim(rtrim(p_location))||'/'||ltrim(rtrim(p_filename)) || chr(0);
      retcode      := '2';
    when utl_file.invalid_mode then
      errbuf := 'Invalid Mode for '||ltrim(rtrim(p_location))||'/'||ltrim(rtrim(p_filename)) || chr(0);
      retcode      := '2';
    when utl_file.invalid_operation then
      errbuf := 'Invalid operation for '||ltrim(rtrim(p_location))||'/'||ltrim(rtrim(p_filename)) || chr(0);
      retcode      := '2';
    when others then
      errbuf := 'Other for '||ltrim(rtrim(p_location))||'/'||ltrim(rtrim(p_filename)) || chr(0);
      retcode      := '2';
  end;
  -- Get General Conversion Item For USA Tax Calculation
  Select msi.inventory_item_id, msi.primary_uom_code, msi.description
    Into v_Gen_ItemID, v_Gen_UOM, v_Gen_Desc
    From mtl_system_items_b msi
   Where msi.organization_id = (Select Organization_id from mtl_parameters where organization_code = 'OMA')
     and msi.segment1 = 'DATA_CONVERSION';
  -- Loop The File For Reading
    While v_read_code <> 0 and nvl(retcode,'0') = '0' loop
      Begin
         utl_file.get_line (file => v_Read_file, buffer => v_line_buf);
      Exception
         When UTL_FILE.READ_ERROR then 
                 errbuf := 'Read Error' || chr(0);
                 retcode      := '2';
         When NO_DATA_FOUND then 
                 fnd_file.put_line (fnd_file.log, 'Read Complete');
                 v_read_code := 0;
         When OTHERS then
                 errbuf := 'Other for Line Read' || chr(0);
                 retcode      := '2';
      End;
      -- Check The EOF
      if v_read_code <> 0 then
         v_counter     := v_counter + 1;
         v_LineErrbuf  := null;
         v_LineRetCode := '0';
         v_place      := instrb(v_line_buf, v_delimiter);
         -- Check The Delimiter
         if nvl(v_place,0) = 0 or (v_place > 100) then 
            fnd_file.put_line (fnd_file.log, 'No Delimiter In The File, Line' || to_char(v_counter));
            errbuf := 'No Delimiter In The File, Line' || to_char(v_counter)||chr(0);
            retcode := '2';
         else
            v_Read_array(v_counter).Invoice_Number       := ltrim(rtrim(substrb(v_line_buf, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_line_buf, v_place+1, length(v_line_buf)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).InvoiceDate          := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            If substrb(v_tmp_line, 1, 1) = chr(34) then
               v_place                                      := instrb(v_tmp_line, chr(34)||v_delimiter);
               v_Read_array(v_counter).BillToCustomer       := ltrim(rtrim(substrb(v_tmp_line, 2, v_place-2)));
               v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+2, length(v_tmp_line)));
            Else
               v_place                                      := instrb(v_tmp_line, v_delimiter);
               v_Read_array(v_counter).BillToCustomer       := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
               v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));
            End if;

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).BillToCusSite        := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).ShipToCustomer       := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).ShipToCusSite        := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).CurrencyCode         := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).GlDate               := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).PaymentDate          := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).PaymentTerms         := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).LineNumber           := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).ItemCode             := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).UOM                  := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).LineQuantity         := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).UnitPrice            := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).OutStandingSum       := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).TaxCode              := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            If substrb(v_tmp_line, 1, 1) = chr(34) then
               v_place                                      := instrb(v_tmp_line, chr(34)||v_delimiter);
               v_Read_array(v_counter).InvoiceDesc          := ltrim(rtrim(substrb(v_tmp_line, 2, v_place-2)));
               v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+2, length(v_tmp_line)));
            Else
               v_place                                      := instrb(v_tmp_line, v_delimiter);
               v_Read_array(v_counter).InvoiceDesc          := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
               v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));
            End if;

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).OperatingUnit        := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).ReferenceField       := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            v_Read_array(v_counter).conversion_type      := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));

            v_place                                      := instrb(v_tmp_line, v_delimiter);
            if v_place = 0 then
               v_place := length(v_tmp_line);
            End if;
            v_Read_array(v_counter).conversion_date      := ltrim(rtrim(substrb(v_tmp_line, 1, v_place-1)));
            v_tmp_line                                   := ltrim(substrb(v_tmp_line, v_place+1, length(v_tmp_line)));
            
            If v_prevInvoiceNum = v_Read_array(v_counter).Invoice_Number then
               v_LineRetCode := '2';
               v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'Duplicate Invoice Number,';
            End if;
            v_prevInvoiceNum := v_Read_array(v_counter).Invoice_Number;
            -- Start Validating The Header Input
            Begin
              Select hp.organization_id Into v_Read_array(v_counter).Operating_Unit_Id
                From hr_operating_units hp
               Where hp.name = v_Read_array(v_counter).OperatingUnit;
            Exception
              When no_data_found then
                   v_LineRetCode := '2';
                   v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'No Operating Unit Found,';
            End;
            Begin
              Select rct.trx_number Into v_Read_array(v_counter).Invoice_Number
                From ra_customer_trx_all rct
               Where rct.org_id = v_Read_array(v_counter).Operating_Unit_Id
                 and rct.trx_number = v_Read_array(v_counter).Invoice_Number;
                 v_LineRetCode := '2';
                 v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'Invoice Already Exists,';
            Exception
              When no_data_found then
                   null;
            End;            
            Begin
              Select to_date(v_Read_array(v_counter).InvoiceDate, 'YYYY-MM-DD') Into v_dummyDate
                From dual;
            Exception
              When Others then
                   v_LineRetCode := '2';
                   v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'No Invoice Date,';
            End;
            Begin
              Select t.customer_id Into v_Read_array(v_counter).BillToCustomerId
                From ar_customers_all_v t
              Where t.customer_name = v_Read_array(v_counter).BillToCustomer;
            Exception
              When no_data_found then
                   v_LineRetCode := '2';
                   v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'No BillTo Customer,';
            End;
            Begin
              Select cas.cust_acct_site_id Into v_Read_array(v_counter).BillToCusSiteId
                From hz_party_sites ps, Hz_Cust_Acct_Sites_All cas
               Where ps.party_site_id = cas.party_site_id
                 and cas.cust_account_id = v_Read_array(v_counter).BillToCustomerId
                 and cas.org_id = v_Read_array(v_counter).Operating_Unit_Id
                 and cas.orig_system_reference = v_Read_array(v_counter).BillToCusSite;
            Exception
              When no_data_found then
                   v_LineRetCode := '2';
                   v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'No BillTo Site,';
            End;
            Begin
              Select gc.currency_code Into v_Read_array(v_counter).CurrencyCode
                From gl_currencies gc
               Where gc.currency_code = v_Read_array(v_counter).CurrencyCode;
            Exception
              When no_data_found then
                   v_LineRetCode := '2';
                   v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'No Currency,';
            End;
            Begin
              Select to_date(v_Read_array(v_counter).GlDate, 'YYYY-MM-DD') Into v_dummyDate
                From dual;
            Exception
              When Others then
                   v_LineRetCode := '2';
                   v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'No GL Date,';
            End;
            Begin
              Select to_date(v_Read_array(v_counter).PaymentDate, 'YYYY-MM-DD') Into v_dummyDate
                From dual;
            Exception
              When Others then
                   v_LineRetCode := '2';
                   v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'No Payment Date,';
            End;
            Begin
              Select to_date(v_Read_array(v_counter).Conversion_Date, 'YYYY-MM-DD') Into v_dummyDate
                From dual;
            Exception
              When Others then
                   v_LineRetCode := '2';
                   v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'No Conversion Date,';
            End;
            Begin
              Select rt.term_id Into v_Read_array(v_counter).PaymentTermsId
                From ra_terms rt
               Where upper(rt.description) = upper(v_Read_array(v_counter).PaymentTerms);
            Exception
              When no_data_found then
                   v_LineRetCode := '2';
                   v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'No Payment Temrs,';
            End;
            -- Get Right Right DC Source Type
            If v_Read_array(v_counter).OutStandingSum < 0 then
               v_Read_array(v_counter).cust_trx_type := 'CM DATA CONVERS '||substrb(v_Read_array(v_counter).OperatingUnit, 7,2);
               v_Read_array(v_counter).PaymentTermsId := null;
            Else
               v_Read_array(v_counter).cust_trx_type := 'DATA CONVERSION '||substrb(v_Read_array(v_counter).OperatingUnit, 7, 2);
            End if;
            Begin
               Select rct.cust_trx_type_id Into v_Read_array(v_counter).cust_trx_typeID
                 From ra_cust_trx_types_all rct
                Where rct.org_id = v_Read_array(v_counter).Operating_Unit_Id
                  and rct.name = v_Read_array(v_counter).cust_trx_type;
            Exception
              When no_data_found then
                   v_LineRetCode := '2';
                   v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'No DC Trx Type,';
            End;
            -- Get Right Batch Source
            Begin
              Select bs.name Into v_Read_array(v_counter).batchSourceName
                From ra_batch_sources_all bs
               Where bs.org_id = v_Read_array(v_counter).Operating_Unit_Id
                  and bs.name = 'Data Conversion '||substrb(v_Read_array(v_counter).OperatingUnit, 7, 2);
            Exception
              When no_data_found then
                   v_LineRetCode := '2';
                   v_LineErrbuf  := ltrim(rtrim(v_LineErrbuf))||'No Batch Source,';
            End;
         End if;
         v_Read_array(v_counter).LineRetCode := v_LineRetCode;
         v_Read_array(v_counter).LineErrbuf  := v_LineErrbuf;
         -- If There Is An Error, Put In The Log File
         If v_LineRetCode = '2' then
            fnd_file.put_line (fnd_file.log, 'Line '||v_counter||' : '||v_LineErrbuf);
            dbms_output.put_line(a => 'Line '||v_counter||' : '||v_LineErrbuf);
         End if;
     End if;
  End loop;        
  If p_processLines = 'Y' then
     -- Loop For Entering Lines Into PO Interface
     For InvLn in 1..v_counter loop
         If nvl(v_Read_array(InvLn).LineRetCode, '0') != '2' then
            -- For USA, Use the DC Item For Tax Calculation
            If v_Read_array(InvLn).OperatingUnit = 'OBJET US (OU)' then
                Insert Into ra_interface_lines_all
                       (interface_line_id,
                        org_id, 
                        batch_source_name,
                        trx_number,
                        trx_date,
                        cust_trx_type_name,
                        cust_trx_type_id,
                        currency_code,
                        orig_system_bill_customer_id,
                        orig_system_bill_address_id,
                        orig_system_ship_customer_id,
                        orig_system_ship_address_id,
                        term_id,
                        conversion_type,
                        conversion_date,
                        line_number,
                        line_type,
                        description,
                        amount,
                        inventory_item_id,
                        uom_code,
                        quantity,
                        unit_selling_price,
                        interface_line_context,
                        interface_line_attribute1,
                        interface_line_attribute2,
                        gl_date,
                        warehouse_id,
                        interface_line_attribute10,
                        tax_exempt_flag,
                        --header_attribute1,
                        last_update_date,
                        last_updated_by,
                        creation_date,
                        created_by, 
                        last_update_login
                       )
                values (ra_customer_trx_lines_s.nextval,
                        v_Read_array(InvLn).Operating_Unit_Id,
                        v_Read_array(InvLn).batchSourceName,
                        v_Read_array(InvLn).Invoice_Number,
                        to_date(v_Read_array(InvLn).InvoiceDate, 'YYYY-MM-DD'),
                        v_Read_array(InvLn).cust_trx_type,
                        v_Read_array(InvLn).cust_trx_typeId,
                        v_Read_array(InvLn).currencyCode,
                        v_Read_array(InvLn).BillToCustomerId,
                        v_Read_array(InvLn).BillToCusSiteId,
                        v_Read_array(InvLn).BillToCustomerId,
                        v_Read_array(InvLn).BillToCusSiteId,
                        v_Read_array(InvLn).PaymentTermsId,
                        v_Read_array(InvLn).conversion_type,
                        to_date(v_Read_array(InvLn).conversion_date, 'YYYY-MM-DD'),
                        v_Read_array(InvLn).LineNumber,
                        'LINE',
                        v_Gen_Desc,
                        v_Read_array(InvLn).OutStandingSum,
                        v_Gen_ItemID,
                        v_Gen_UOM,
                        1,
                        v_Read_array(InvLn).OutStandingSum,
                        v_Read_array(InvLn).batchSourceName,
                        nvl(v_Read_array(InvLn).ReferenceField, v_Read_array(InvLn).Invoice_Number),
                        v_Read_array(InvLn).Invoice_Number,
                        to_date(v_Read_array(InvLn).GlDate, 'YYYY-MM-DD'),
                        95,
                        95,
                        'S',
                        --v_Read_array(InvLn).ReferenceField,
                        sysdate,
                        v_user_id,
                        sysdate,
                        v_user_id,
                        v_login_id
                       );
            Else
                Insert Into ra_interface_lines_all
                       (interface_line_id,
                        org_id, 
                        batch_source_name,
                        trx_number,
                        trx_date,
                        cust_trx_type_name,
                        cust_trx_type_id,
                        currency_code,
                        orig_system_bill_customer_id,
                        orig_system_bill_address_id,
                        term_id,
                        conversion_type,
                        conversion_date,
                        line_number,
                        line_type,
                        description,
                        amount,
                        interface_line_context,
                        interface_line_attribute1,
                        interface_line_attribute2,
                        gl_date,
                        last_update_date,
                        last_updated_by,
                        creation_date,
                        created_by, 
                        last_update_login
                       )
                values (ra_customer_trx_lines_s.nextval,
                        v_Read_array(InvLn).Operating_Unit_Id,
                        v_Read_array(InvLn).batchSourceName,
                        v_Read_array(InvLn).Invoice_Number,
                        to_date(v_Read_array(InvLn).InvoiceDate, 'YYYY-MM-DD'),
                        v_Read_array(InvLn).cust_trx_type,
                        v_Read_array(InvLn).cust_trx_typeId,
                        v_Read_array(InvLn).currencyCode,
                        v_Read_array(InvLn).BillToCustomerId,
                        v_Read_array(InvLn).BillToCusSiteId,
                        v_Read_array(InvLn).PaymentTermsId,
                        v_Read_array(InvLn).conversion_type,
                        to_date(v_Read_array(InvLn).conversion_date, 'YYYY-MM-DD'),
                        v_Read_array(InvLn).LineNumber,
                        'LINE',
                        'DC - '||ltrim(rtrim(v_Read_array(InvLn).InvoiceDesc)),
                        v_Read_array(InvLn).OutStandingSum,
                        --'Data Migration',
                        v_Read_array(InvLn).batchSourceName,
                        nvl(v_Read_array(InvLn).ReferenceField, v_Read_array(InvLn).Invoice_Number),
                        v_Read_array(InvLn).Invoice_Number,
                        to_date(v_Read_array(InvLn).GlDate, 'YYYY-MM-DD'),
                        sysdate,
                        v_user_id,
                        sysdate,
                        v_user_id,
                        v_login_id
                       );
            End if;
         End if;      
     End loop;
  End if;
End Ascii_ARInvoiceInt;

end xxconv_ar_upload_invoice_pkg;
/

