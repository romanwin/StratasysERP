CREATE OR REPLACE PACKAGE BODY xxap_legacy_s3_int_pkg

-- =============================================================================
-- Copyright(c) :
-- Application  : Custom Application
-- -----------------------------------------------------------------------------
-- Program name                         Creation Date    Original Ver    Created by
-- xxap_legacy_s3_int_pkg               4-AUG-2016      1.0             TCS
-- -----------------------------------------------------------------------------
-- Usage: This will be used as Auto AP Invoice Creation program based on AR Invoice.
-- This is the Package Specification.
-- -----------------------------------------------------------------------------
-- Description: This program will be used to create
--              AP invoice for AR Invoice in legacy.
-- Parameter    : Written in each procedure section.
-- Return value : Written in each procedure section.
-- -----------------------------------------------------------------------------
-- Modification History:
-- Modified Date     Version      Done by       Change Description
--
-- ============================================================================

 IS

  -- ===========================================================================
  --  Program name                 Creation Date               Created by
  --  update_event_status           30-JUL-2016                TCS
  -- ---------------------------------------------------------------------------
  -- Description  : This procedure is used to insert the invoices in events table
  --
  -- Return value : None
  --
  -- ===========================================================================

  PROCEDURE update_event_status(x_errbuff    OUT VARCHAR2,
                                x_retcode    OUT NUMBER,
                                p_request_id IN NUMBER) IS

  -- Cursor Declaration - Start
    -- This cursor will fetch all the all records from the
    -- Invoice header and Line staging table for a particular request id

    CURSOR c_po_data IS
      SELECT xaihs.*
        FROM xx_ap_invoices_hdr_stg xaihs, xx_ap_invoices_line_stg xails
       WHERE xaihs.invoice_num = xails.invoice_num
         AND xaihs.status IS NOT NULL
         AND xaihs.request_id = p_request_id;

  BEGIN

    fnd_file.put_line(fnd_file.LOG, 'Request ID - ' || p_request_id);

    --Opening the cursor

    FOR rec_po_data IN c_po_data LOOP

      fnd_file.put_line(fnd_file.LOG,
                        'Event ID - ' || rec_po_data.event_id);

    --Updating Success Status in business event table

      IF rec_po_data.status = 'S' THEN

        xxssys_event_pkg_s3.update_success(rec_po_data.event_id);

        fnd_file.put_line(fnd_file.LOG,
                          'Event ID - ' || rec_po_data.event_id);

    --Updating Error Status in business event table

      ELSIF rec_po_data.status = 'E' THEN

        xxssys_event_pkg_s3.update_error(rec_po_data.event_id,
                                         rec_po_data.error_message);

      END IF;

    END LOOP;
  COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      x_errbuff  := 'ERROR';
      x_retcode := '2';
      fnd_file.put_line(fnd_file.LOG,
                        'Error code :' || SQLCODE || '  ' || 'Error Msg :' ||
                        SQLERRM);
  END;

  -- ===========================================================================
  --                     End of Procedure update_event_status
  -- ===========================================================================

  PROCEDURE pull_ar_invoices(x_errbuf     OUT VARCHAR2,
                             x_retcode    OUT VARCHAR2,
                             p_batch_size IN NUMBER)

    -- ===========================================================================
    --  Program name                Creation Date                Created by
    --  pull_ar_invoices            4-AUG-2016                    TCS
    -- ---------------------------------------------------------------------------
    -- Description  : This is the Data pull procedure
    --
    -- Return value : None
    --
    -- ===========================================================================
   IS

    -- ===========================================================================
    --                     Global Variable Declaration
    -- ===========================================================================
    g_last_updated_by   NUMBER := fnd_global.user_id;
    g_last_update_login NUMBER := fnd_global.conc_login_id;
    g_request_id        NUMBER := fnd_global.conc_request_id;
    g_sqlerrm           VARCHAR2(2000) := NULL;
    g_error_msg         VARCHAR2(4000) := NULL;
    g_step_id           VARCHAR2(100) := NULL;
    g_last_update_date  DATE := SYSDATE;
    g_created_by        NUMBER := fnd_global.user_id;
    g_creation_date     DATE := SYSDATE;
    g_match_option      xx_ap_invoices_line_stg.match_option%type := 'P';
    g_source            xx_ap_invoices_hdr_stg.source%type := 'INTERFACE IMPORT';
    g_invoice_type      xx_ap_invoices_hdr_stg.invoice_type_lookup_code%type := 'STANDARD';
    g_invoice_line_type xx_ap_invoices_line_stg.line_type_lookup_code%type := 'ITEM';
    g_new_status        VARCHAR2(100) := 'NEW';

    -- Local Variable decleration
    l_error_msg        VARCHAR2(30000) := NULL;
    l_record_status    VARCHAR2(10) := 'S';
    l_hdr_count        NUMBER := NULL;
    l_line_num_count   NUMBER := NULL;
    l_errbuf         VARCHAR2(4000);
    l_retcode        VARCHAR2(100);

    -- ===========================================================================
    --                       Global Exception Declaration
    -- ===========================================================================
    e_abort EXCEPTION;

    --------------------------------------------------------------
    --Table Type Line varaible Declaration
    ---------------------------------------------------

    TYPE l_ar_inv_val_rec IS TABLE OF xxar_invoice_s3_int_v%ROWTYPE INDEX BY BINARY_INTEGER;
    l_ar_inv_val_tab l_ar_inv_val_rec;

   --Table Type Header varaible Declaration

    TYPE l_ar_inv_hdr_val_rec IS RECORD(
      invoice_num    xxar_invoice_s3_int_v.invoice_num%TYPE,
      release_id     xxar_invoice_s3_int_v.release_id%TYPE,
      po_number      xxar_invoice_s3_int_v.po_number%TYPE,
      operating_unit xxar_invoice_s3_int_v.operating_unit%TYPE,
      event_id       xxar_invoice_s3_int_v.event_id%TYPE,
      invoice_date   xxar_invoice_s3_int_v.invoice_date%TYPE);

    TYPE l_ar_hdr_val_tab IS TABLE OF l_ar_inv_hdr_val_rec INDEX BY BINARY_INTEGER;

    l_ar_inv_hdr_val_tab l_ar_hdr_val_tab;

    -- ===========================================================================
    --        Cursor for retriving po headerdetails from s3
    -- ===========================================================================
    CURSOR c_po_hdr_details(p_release_id xxar_invoice_s3_int_v.release_id%TYPE) IS
      SELECT asp.vendor_name,
             asp.segment1 vendor_num,
             assa.vendor_site_code,
             pha.currency_code,
             pha.terms_id,
             pha.vendor_id,
             pha.vendor_site_id,
             pha.org_id
        FROM po_releases_all       pra,
             po_headers_all        pha,
             ap_suppliers          asp,
             ap_supplier_sites_all assa
       WHERE pha.po_header_id = pra.po_header_id
         AND pha.vendor_id = asp.vendor_id
         AND pha.vendor_id = assa.vendor_id
         AND pha.vendor_site_id = assa.vendor_site_id
         AND pha.org_id = assa.org_id
         AND pra.po_release_id = p_release_id;

    -- ===========================================================================
    --        Cursor for retriving po details from s3
    -- ===========================================================================

    CURSOR c_po_details(p_release_id xxar_invoice_s3_int_v.release_id%TYPE, p_line_loc_id xxar_invoice_s3_int_v.line_location_id%TYPE) IS
      SELECT pra.po_release_id,
             pra.po_header_id,
             pra.release_num,
             pra.revision_num,
             plla.shipment_num,
             plla.line_location_id,
             pla.line_num po_line_num,
             pla.po_line_id,
             asp.vendor_name,
             asp.segment1 vendor_num,
             assa.vendor_site_code,
             assa.pay_group_lookup_code,
             pha.currency_code,
             pha.terms_id,
             pha.vendor_id,
             pha.vendor_site_id,
             pha.org_id,
             pla.unit_price
        FROM po_releases_all       pra,
             po_headers_all        pha,
             po_line_locations_all plla,
             po_lines_all          pla,
             ap_suppliers          asp,
             ap_supplier_sites_all assa
       WHERE pha.po_header_id = pra.po_header_id
         AND pra.po_release_id = plla.po_release_id
         AND pla.po_line_id = plla.po_line_id
         AND pha.vendor_id = asp.vendor_id
         AND pha.vendor_id = assa.vendor_id
         AND pha.vendor_site_id = assa.vendor_site_id
         AND pha.org_id = assa.org_id
         AND pra.po_release_id = p_release_id
         AND plla.line_location_id = p_line_loc_id;

    -- ===========================================================================
    --        Cursor for retriving invoice id in header staging table
    -- ===========================================================================

    CURSOR c_hdr_inv IS
      SELECT xaihs.invoice_num, xaihs.ROWID
        FROM xx_ap_invoices_hdr_stg xaihs
       WHERE xaihs.request_id = g_request_id
         AND xaihs.status = g_new_status;

    -- ===========================================================================
    --        Cursor for retriving line amount from line staging table
    -- ===========================================================================

    CURSOR c_line_inv(p_invoice_num VARCHAR2) IS
      SELECT sum(xails.amount) line_amount
        FROM xx_ap_invoices_line_stg xails
       WHERE xails.invoice_num = p_invoice_num
         AND xails.request_id = g_request_id;

  BEGIN
    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) || 'Procedure pull_ar_invoices - Start');

    -- Initialization of Variables - Start
    x_errbuf  := 'SUCCESS';
    x_retcode := '0';

    -- Initialization of Variables - End

    --//==========================================================================
    --// Retriving Header AR Invoice data using pull method --start
    --//==========================================================================
    BEGIN
      SELECT DISTINCT invoice_num,
                      release_id,
                      po_number,
                      operating_unit,
                      event_id,
                      invoice_date BULK COLLECT
        INTO l_ar_inv_hdr_val_tab
        FROM xxar_invoice_s3_int_v
       WHERE status = g_new_status
         AND rownum <= 100;
    EXCEPTION
      WHEN OTHERS THEN
        g_step_id   := 'P01';
        g_sqlerrm   := SQLERRM;
        g_error_msg := 'Unexpected error has occured while Retriving the AP Invoice Data from Interface view';
        RAISE e_abort;
    END;

    --Retriving Header AR Invoice data using pull method end---

    --//==========================================================================
    --// Retriving Line AR Invoice data using pull method
    --//==========================================================================
    BEGIN
      SELECT * BULK COLLECT
        INTO l_ar_inv_val_tab
        FROM xxar_invoice_s3_int_v
       WHERE status = g_new_status
         AND rownum <= 100;
      -- ORDER by last_update_date ASC;

    EXCEPTION
      WHEN OTHERS THEN
        g_step_id   := 'P01';
        g_sqlerrm   := SQLERRM;
        g_error_msg := 'Unexpected error has occured while Retriving the AP Invoice Data from Interface view';
        RAISE e_abort;
    END;

    --//==========================================================================
    --// Insert into Header staging table
    --//==========================================================================

    BEGIN

      FND_FILE.PUT_LINE(FND_FILE.LOG, CHR(13) || 'before header loop');
      FOR i IN l_ar_inv_hdr_val_tab.first .. l_ar_inv_hdr_val_tab.last LOOP

      ----Intailaizing line number count----
      l_line_num_count:= 0;

        FND_FILE.PUT_LINE(FND_FILE.LOG,
                          CHR(13) ||
                          'Processing Header Interface view Data - Start');

        FND_FILE.PUT_LINE(FND_FILE.LOG,
                          CHR(13) || 'l_ar_inv_hdr_val_tab(i).release_id' ||
                          l_ar_inv_hdr_val_tab(i).release_id);

        FOR rec_po_hdr_details IN c_po_hdr_details(l_ar_inv_hdr_val_tab(i)
                                                     .release_id) LOOP
          FND_FILE.PUT_LINE(FND_FILE.LOG,
                            CHR(13) ||
                            'Inside rec_po_hdr_details loop- Start');

          BEGIN

            FND_FILE.PUT_LINE(FND_FILE.LOG,
                              CHR(13) ||
                              'Header Staging Table insertion - Start');

            INSERT INTO xx_ap_invoices_hdr_stg
              (invoice_num,
               invoice_type_lookup_code,
               invoice_date,
               po_number,
               vendor_id,
               vendor_num,
               vendor_name,
               vendor_site_id,
               vendor_site_code,
               -- invoice_amount,
               invoice_currency_code,
               payment_currency_code,
               terms_id,
               terms_date,
               status,
               source,
               org_id,
               --payment_method_lookup_code,
               gl_date,
               operating_unit,
               event_id,
               creation_date,
               created_by,
               last_update_date,
               last_updated_by,
               last_update_login,
               request_id)
            VALUES
              (l_ar_inv_hdr_val_tab(i).invoice_num,
               g_invoice_type,
               l_ar_inv_hdr_val_tab(i).invoice_date,
               l_ar_inv_hdr_val_tab(i).po_number,
               rec_po_hdr_details.vendor_id,
               rec_po_hdr_details.vendor_num,
               rec_po_hdr_details.vendor_name,
               rec_po_hdr_details.vendor_site_id,
               rec_po_hdr_details.vendor_site_code,
               rec_po_hdr_details.currency_code,
               rec_po_hdr_details.currency_code,
               rec_po_hdr_details.terms_id,
               sysdate,
               g_new_status,
               g_source,
               rec_po_hdr_details.org_id,
               sysdate,
               l_ar_inv_hdr_val_tab(i).operating_unit,
               l_ar_inv_hdr_val_tab(i).event_id,
               g_creation_date,
               g_created_by,
               g_last_update_date,
               g_last_updated_by,
               g_last_update_login,
               g_request_id);

          EXCEPTION
            WHEN OTHERS THEN
              g_step_id       := 'P02';
              l_error_msg     := 'Failed to insert the record' ||
                                 ' in header staging table for the invoice ' ||
                                 'Number "' || l_ar_inv_hdr_val_tab(i)
                                .invoice_num || '" Error : ' || SQLERRM;
              l_record_status := 'E';

              FND_FILE.PUT_LINE(FND_FILE.LOG,
                                CHR(13) || 'Insert hdr Exp: ' ||
                                l_error_msg);
              RAISE e_abort;
          END;
        END LOOP;
      END LOOP;

      --//==========================================================================
      --// Insert into Line staging table
      --//==========================================================================

      FOR j IN l_ar_inv_val_tab.first .. l_ar_inv_val_tab.LAST LOOP

       l_line_num_count := l_line_num_count+1;

        FND_FILE.PUT_LINE(FND_FILE.LOG,
                          CHR(13) ||
                          'Processing Interface view Data - Start');

        FOR rec_po_details IN c_po_details(l_ar_inv_val_tab(j).release_id,
                                             l_ar_inv_val_tab(j).line_location_id) LOOP

          BEGIN

            FND_FILE.PUT_LINE(FND_FILE.LOG,
                              CHR(13) ||
                              'Line Staging Table insertion - Start');

            INSERT INTO xx_ap_invoices_line_stg
              (invoice_line_id,
               invoice_num,
               line_number,
               line_type_lookup_code,
               supplier_number,
               amount,
               accounting_date,
               po_header_id,
               po_number,
               po_line_id,
               po_line_number,
               po_line_location_id,
               po_shipment_num,
               item_number,
               item_description,
               quantity_invoiced,
               unit_price,
               po_release_id,
               release_num,
               org_id,
               operating_unit,
               match_option,
               --distribution account pending
               event_id,
               status,
               creation_date,
               created_by,
               last_update_date,
               last_updated_by,
               last_update_login,
               request_id)
            VALUES
              (ap_invoice_lines_interface_s.NEXTVAL,
               l_ar_inv_val_tab(j).invoice_num,
               l_line_num_count,
               g_invoice_line_type,
               rec_po_details.vendor_num,
               (l_ar_inv_val_tab(j)
               .quantity_invoiced * rec_po_details.unit_price),
               sysdate,
               rec_po_details.po_header_id,
               l_ar_inv_val_tab(j).po_number,
               rec_po_details.po_line_id,
               rec_po_details.po_line_num,
               rec_po_details.line_location_id,
               rec_po_details.shipment_num,
               l_ar_inv_val_tab(j).item_number,
               l_ar_inv_val_tab(j).description,
               l_ar_inv_val_tab(j).quantity_invoiced,
               rec_po_details.unit_price,
               rec_po_details.po_release_id,
               rec_po_details.release_num,
               rec_po_details.org_id,
               l_ar_inv_val_tab(j).operating_unit,
               g_match_option, --purchase order
               l_ar_inv_val_tab(j).event_id,
               g_new_status,
               g_creation_date,
               g_created_by,
               g_last_update_date,
               g_last_updated_by,
               g_last_update_login,
               g_request_id);

          EXCEPTION
            WHEN OTHERS THEN
              g_step_id       := 'P03';
              l_error_msg     := 'Failed to insert the record' ||
                                 ' in line staging table for the invoice ' ||
                                 'Number "' || l_ar_inv_val_tab(j)
                                .invoice_num || '" Error : ' || SQLERRM;
              l_record_status := 'E';

              FND_FILE.PUT_LINE(FND_FILE.LOG,
                                CHR(13) || 'Insert line Exp: ' ||
                                l_error_msg);
              RAISE e_abort;
          END;
        END LOOP;
      END LOOP;
    END;
    l_ar_inv_hdr_val_tab.delete;
    l_ar_inv_val_tab.delete;

    --//==========================================================================
    --// updating invoice amount for sum of each line amount
    --//==========================================================================

    FND_FILE.PUT_LINE(FND_FILE.LOG,
                      CHR(13) ||
                      'After Header Line Stage table insertion: Request_id' ||
                      g_request_id);

    ----processing header cusror------------

    FOR rec_hdr_inv IN c_hdr_inv LOOP

      FND_FILE.PUT_LINE(FND_FILE.LOG, CHR(13) || 'Inside Header loop');

      ----processing Line cusror------------

      FOR rec_line_inv IN c_line_inv(rec_hdr_inv.invoice_num) LOOP

        FND_FILE.PUT_LINE(FND_FILE.LOG, CHR(13) || 'Inside line loop');

        BEGIN
          UPDATE xx_ap_invoices_hdr_stg xaihs
             SET xaihs.invoice_amount = rec_line_inv.line_amount
           WHERE xaihs.invoice_num = rec_hdr_inv.invoice_num
             AND xaihs.request_id = g_request_id
             AND xaihs.ROWID = rec_hdr_inv.ROWID;

          FND_FILE.PUT_LINE(FND_FILE.LOG,
                            CHR(13) ||
                            'Invoice amount update success in Header staging table');
        EXCEPTION
          WHEN OTHERS THEN
            FND_FILE.PUT_LINE(FND_FILE.LOG,
                              CHR(13) ||
                              'Invoice amount update Failed in Header staging table');
            g_step_id   := 'P04';
            g_sqlerrm   := SQLERRM;
            g_error_msg := 'Unexpected error has occured while Updating invoice line amount';
            RAISE e_abort;
        END;
      END LOOP;
    END LOOP;
    COMMIT;

    -- Checking record present in Header and Line staging table
    BEGIN
      SELECT COUNT(1)
        INTO l_hdr_count
        FROM xx_ap_invoices_hdr_stg xaihs, xx_ap_invoices_line_stg xails
       WHERE xaihs.invoice_num = xails.invoice_num
         AND xaihs.status = 'NEW'
         AND xaihs.request_id = g_request_id;
    EXCEPTION
      WHEN OTHERS THEN
        g_step_id   := 'P05';
        g_sqlerrm   := SQLERRM;
        g_error_msg := 'Unexpected error has occured while taking the Staging header count';
        RAISE e_abort;
    END;
    --//==========================================================================
    --// calling procedure for ap invoice creation
    --//==========================================================================

    IF l_hdr_count > 0 THEN

      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        CHR(13) ||
                        'Interface Program to create Invoice - Start');

      xxap_legacy_s3_intf_pkg.main(x_errbuf     => x_errbuf,
                                   x_retcode    => x_retcode);

    END IF;

    -- ===========================================================================
    --      Update status in business event events table --start
    -- ===========================================================================

   BEGIN 
    update_event_status(x_errbuff => l_errbuf,
                        x_retcode => l_retcode,
                        p_request_id => g_request_id);
  EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log,
                          'Error in Calling of update_event_status.............');
        fnd_file.put_line(fnd_file.log,
                          'Error code :' || l_errbuf || SQLCODE || '  ' ||
                          'Error Msg :' || l_retcode || SQLERRM);

    END;

    --  Update status in business event events table --end

  EXCEPTION
    WHEN e_abort THEN
      ROLLBACK;
      x_errbuf  := 'ERROR';
      x_retcode := '2';
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        CHR(13) || g_error_msg || '/SQLERRM: ' || g_sqlerrm ||
                        '/Step ID:' || g_step_id);

    WHEN OTHERS THEN
      ROLLBACK;
      x_errbuf  := 'ERROR';
      x_retcode := '2';
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        CHR(13) ||
                        'Unexpected error occurred.Please contact SysAdmin.' ||
                        '/SQLERRM: ' || SQLERRM || '/Step ID : M02' ||
                        CHR(13));

    -- ===========================================================================
    --                     End of Procedure pull_ar_invoices
    -- ===========================================================================
  END pull_ar_invoices;

END xxap_legacy_s3_int_pkg;
/