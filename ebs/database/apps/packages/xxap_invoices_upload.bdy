create or replace package body xxap_invoices_upload AS
  ---------------------------------------------------------------------------
  -- $Header: xxap_invoices_upload   $
  ---------------------------------------------------------------------------
  -- Package: xxap_invoices_upload
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: upload scan invoices into fnd_lobs
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  16.08.11   yuval tal            Initial Build
  --     1.2  2-JUL-2014 sandeep akula        CHG0031533 Changes
  --                                          Added Procedures invoice_requester_exists, get_nonmatched_inv_profile, needs_reapproval, is_ssus_op_unit
  --                                          Added Functions check_active_person and validate_approver
  --     1.3  12-AUG-2014 sandeep akula       CHG0032899 Changes
  --                                          Added Variable l_org_id
  --                                          Added Condition to send emails to Stratasys US Accounts Payable
  -- 1.4         29.11.15  yuval tal          CHG0037104 - ignore locking of file when tring to delete
  --                                          add function is_invoice_exists
  --                                          modify procedure is_invoice_exist
  --                                          modify upload_invoices_process
  --                                          add remove_file procedure
  --                                          modify upload file
  --  1.5   21.1.16       yuval tal           CHG0037161 - Upload GTMS invoice to AP : modify get_pk,upload_file,upload_invoices_process
  --                                          support upload file with name start with INV
  --                                          INV_<INTERFACE INVOICE_ID>_<INVOICE_NUMBER>_< OPERATING_UNIT >_<VENDOR_NAME >.pdf
  -- 1.6 21.2.16          yuval tal           CHG0037828 - Add options to allow for multiple file names per invoice
  --                                          add is_attached_file_exists
  --                                          modify is_invoice_exists
  --                                          add is_scan_invoice_exists
  --                                          modify get_pk
  --                                          upload_invoiceses_process
  --1.7   4-MAY-2016     Lingaraj Sarangi     CHG0038386 - AP Invoice Approval workflow modification to handle OIC invoices
  --1.8   1-AUG-2017     Piyali bhowmick      CHG0041105 - AP Invoice Approval Change
  ------------------------------------------------------------------------------------------------------

  -- '/UtlFiles/AP/ScanInvoices';
  -- '/UtlFiles/AP/UnMatchInvoices';

  /*

   dbms_java.grant_permission('APPS',
  'SYS:java.io.FilePermission',
  '/UtlFiles/AP/ScanInvoices/*',
  'execute');

  */
  CURSOR c_check_needed(c_pk NUMBER) IS
    SELECT 1

    FROM   ap_invoice_distributions_all aid,
           po_distributions_all         pda,
           po_line_locations_all        pll
    WHERE  pda.po_distribution_id = aid.po_distribution_id
    AND    aid.invoice_id = c_pk --:transactionId
    AND    pda.destination_type_code = 'EXPENSE'
    AND    (pda.req_distribution_id IS NOT NULL OR
          pda.deliver_to_person_id IS NOT NULL)
    AND    pll.line_location_id = pda.line_location_id
    AND    pll.match_option = 'P'
    AND    rownum = 1;

  PROCEDURE mail_error(p_file_name          VARCHAR2,
	           p_dir                VARCHAR2,
	           l_unmatch_oracle_dir VARCHAR2,
	           p_err_msg            VARCHAR2);

  ---------------------------------
  -- create_oracle_dir
  ---------------------------------
  PROCEDURE create_oracle_dir(p_name VARCHAR2,
		      p_dir  VARCHAR2) IS

  BEGIN

    EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY ' || p_name || ' AS ''' ||
	          p_dir || '''';
  END;

  ---------------------------------
  -- remove_file
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  -- 1.4     29.11.15  yuval tal    CHG0037104 - ignore locking of file when tring to delete

  PROCEDURE remove_file(p_dir       VARCHAR2,
		p_file_name VARCHAR2) IS
  BEGIN
    utl_file.fremove(location => p_dir, filename => p_file_name);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;

  END;

  ---------------------------------
  -- get_pk
  --------------------------------------------------------------------------
  -- Version    Date      Performer       Comments
  ----------    --------  --------------  -------------------------------------
  --     1.0    16.08.11   yuval tal      Initial Build
  --     1.1    21.01.15   yuval tal      CHG0037161 ? Upload GTMS invoice to AP Intterface - support upload files with new file name convention
  --     1.2    21.2.16    yuval tal      CHG0037828 change logic of extract voucher no from file name
  PROCEDURE get_pk(p_file_name       VARCHAR2,
	       p_out_invoive_id  OUT NUMBER,
	       p_out_voucher_num OUT VARCHAR2,
	       p_err_code        OUT NUMBER,
	       p_err_message     OUT VARCHAR2) IS

  BEGIN
    p_err_code := 0;
    -- CHG0037161

    IF p_file_name LIKE 'INV%' THEN

      /* SELECT aia.invoice_id,
             aia.doc_sequence_value
      INTO   p_out_invoive_id,
             p_out_voucher_num
      FROM   ap_invoices_interface intr,
             ap_invoices_all       aia
      WHERE  intr.invoice_id =
             substr(p_file_name, 5, instr(p_file_name, '_', 1, 2) - 5)
      AND    aia.vendor_site_id = intr.vendor_site_id
      AND    aia.invoice_num = intr.invoice_num
      AND    aia.invoice_date = intr.invoice_date;*/

      SELECT aia.invoice_id,
	 aia.doc_sequence_value
      INTO   p_out_invoive_id,
	 p_out_voucher_num
      FROM   ap_invoices_interface intr,
	 ap_invoices_all       aia,
	 po_vendors            pv,
	 po_vendor_sites_all   pvs
      WHERE  intr.invoice_id =
	 substr(p_file_name, 5, instr(p_file_name, '_', 1, 2) - 5)
      AND    aia.vendor_site_id = pvs.vendor_site_id
      AND    aia.invoice_num = intr.invoice_num
      AND    aia.invoice_date = trunc(intr.invoice_date)
      AND    pv.segment1 = intr.vendor_num
      AND    pvs.vendor_id = pv.vendor_id
      AND    (pvs.vendor_site_code = intr.vendor_site_code OR
	pvs.vendor_site_id = intr.vendor_site_id);

    ELSE
      -- CHG0037828  assuming  first segment is voucher number 12345_??????.pdf or 123.pdf
      p_out_voucher_num := regexp_substr(p_file_name, '[^_|.]+', 1, 1); --CHG0037828

      fnd_file.put_line(fnd_file.log,
		'p_out_voucher_num= ' || p_out_voucher_num);
      BEGIN

        SELECT t.invoice_id
        INTO   p_out_invoive_id
        FROM   ap_invoices t
        WHERE  t.doc_sequence_value = p_out_voucher_num
        AND    fnd_profile.value('XXAP_UPLOAD_SCANNED_INVOICES') = 'Y';
      EXCEPTION
        WHEN too_many_rows THEN
          p_out_invoive_id := NULL;
          p_err_code       := 1;
          p_err_message    := 'Multiple vouchers found. Manual upload required';
      END;
    END IF;

  EXCEPTION
    WHEN no_data_found THEN
      p_out_invoive_id := NULL;
      p_err_code       := 0;

    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'sqlerrm= ' || SQLERRM);
      p_out_invoive_id := NULL;
      p_err_code       := 1;
      p_err_message    := 'General Error :' || SQLERRM;

  END;
  ---------------------------------
  -- upload_file
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  -- 1.4     29.11.15  yuval tal    CHG0037104  --if file exists then ignore
  -- 1.5    21.01.16   yuval tal    CHG0037161  adjust call to change get_pk
  -- 1.6    21.2.16    yuval tal    CHG0037828 change description logic
  --                                           if p_file name start with INV or equal voucher no.pdf then
  --                                           put voucher.pdf else null

  PROCEDURE upload_file(p_dir         VARCHAR2,
		p_db_dir      VARCHAR2, -- Added Database Directory Parameter -- 02-JUL-2014 SAkula (CHG0031533)
		p_file_name   VARCHAR2,
		p_category_id NUMBER,
		p_errcode     OUT NUMBER,
		p_err_msg     OUT VARCHAR2) IS
    l_resultout         VARCHAR2(150);
    l_invoice_id        NUMBER;
    l_voucher_num       ap_invoices_all.voucher_num%TYPE;
    l_bfile             BFILE;
    l_ext               VARCHAR2(5);
    l_description       VARCHAR2(500);
    l_err_code          NUMBER;
    l_err_message       VARCHAR2(500);
    l_use_misc_cat_flag VARCHAR2(1);
  BEGIN
    p_errcode := 0;
    p_err_msg := 'File Attached successfuly';
    --  RETURN;
    -- get pk

    get_pk(p_file_name,
           l_invoice_id,
           l_voucher_num,
           l_err_code,
           l_err_message); --CHG0037161

    fnd_file.put_line(fnd_file.log, 'invoice id=' || l_invoice_id);
    fnd_file.put_line(fnd_file.log,
	          'file exists=' ||
	          is_attached_file_exists(l_invoice_id, p_file_name));

    IF l_invoice_id IS NOT NULL AND
       is_attached_file_exists(l_invoice_id, p_file_name) = 'Y' THEN
      p_err_msg := 'File already uploaded ';
      fnd_file.put_line(fnd_file.log, p_err_msg);
      p_errcode := 2;
      RETURN;
    END IF;

    IF l_err_code = 1 THEN
      p_err_msg := l_err_message;
      fnd_file.put_line(fnd_file.log, p_err_msg);
      p_errcode := 2;
      RETURN;

    END IF;

    IF l_invoice_id IS NULL THEN
      p_errcode := 3;
      p_err_msg := 'No invoice found for file ' || p_file_name;
    ELSE
      -- check file size > 0

      l_bfile := bfilename(p_db_dir, p_file_name); -- Parameterized call to bfilename -- 2-JUL-2014 SAkula (CHG0031533)
      IF dbms_lob.getlength(l_bfile) = 0 THEN
        -- dbms_output.put_line('size= ' || dbms_lob.getlength(l_bfile));

        RETURN;
      END IF;

      l_ext := substr(p_file_name, instr(p_file_name, '.', -1) + 1);
      -- set description when file is  scaned invoice  only CHG0037828
      l_description := p_file_name;
      -- in case file is scanned invoice do not use Miscellaneous category
      l_use_misc_cat_flag := CASE
		       WHEN (p_file_name LIKE 'INV%' OR
			(lower(p_file_name) =
			lower(l_voucher_num || '.' || l_ext))) THEN
		        'N'
		       ELSE
		        'Y'
		     END;

      xxcs_attach_doc_pkg.objet_store_pdf(p_entity_name       => 'AP_INVOICES',
			      p_pk1               => l_invoice_id,
			      p_pk2               => NULL,
			      p_pk3               => NULL,
			      p_pk4               => NULL,
			      p_pk5               => NULL,
			      p_conc_req_id       => fnd_global.conc_request_id,
			      p_doc_categ         => CASE
					      l_use_misc_cat_flag

					       WHEN 'Y' THEN
					        1
					       ELSE
					        p_category_id
					     END,
			      p_file_name         => p_dir || '/' ||
					     p_file_name, --CHG0037161
			      resultout           => l_resultout,
			      p_file_content_type => get_content_type(l_ext),
			      --p_oracle_directory  => 'XXAP_SCANED_INVOICES_DIR',
			      p_oracle_directory => p_db_dir, -- Removed Hardcoded DB Dir and Added p_db_dir -- 2-JUL-2014 SAkula (CHG0031533)
			      p_description      => l_description); -- CHG0037828
      IF l_resultout != 'COMPLETE:' || 'Y' THEN
        ROLLBACK;
        p_errcode := 2;
        p_err_msg := 'failure in xxcs_attach_doc_pkg.objet_store_pdf ' ||
	         l_resultout;

      END IF;
      COMMIT;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_errcode := 3;
      p_err_msg := SQLERRM;
  END;
  ---------------------------------
  -- upload_invoices
  -- read all files under directory XX and upload into invoice attachments
  -- under category Scaned Invoice
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.X  16.08.11   yuval tal    CHG0037104 on remove file failure ,no need to do anything , probably locking issue
  --     1.1  21.1.16    yuval tal    CHG0037161  : in case file name start with INT do not move to unmatch invoices
  --                                  file will wait to next run
  --     1.2  17.3.16    yuval tal     CHG0037828 - use profile for category of scanned invoice
  PROCEDURE upload_invoices_process(errbuf          OUT VARCHAR2,
			retcode         OUT VARCHAR2,
			p_dir           VARCHAR2, -- /UtlFiles/AP/ScanInvoices
			p_unmatch_dir   VARCHAR2, -- /UtlFiles/AP/UnMatchInvoices
			p_category_name VARCHAR2) IS
    -- CUSTOM1001227

    l_mail_list VARCHAR2(500);
    l_file_list VARCHAR2(32000);
    l_err_code  NUMBER;
    l_err_msg   VARCHAR2(200);
    my_exception EXCEPTION;
    l_category_id NUMBER;
    l_inx         NUMBER := 0;
    --l_scan_oracle_dir    VARCHAR2(50) := 'XXAP_SCANED_INVOICES_DIR'; -- Commented -- 2-JUL-2014 SAkula (CHG0031533)
    --l_unmatch_oracle_dir VARCHAR2(50) := 'XXAP_UNSCANED_INVOICES_DIR'; -- Commented -- 2-JUL-2014 SAkula (CHG0031533)
    l_scan_oracle_dir    VARCHAR2(50) := fnd_profile.value('XXAP_SCANNED_INVOICES_DB_DIR'); -- l_scan_oracle_dir variable gets value from Profile -- 2-JUL-2014 SAkula (CHG0031533)
    l_unmatch_oracle_dir VARCHAR2(50) := fnd_profile.value('XXAP_UNSCANNED_INVOICES_DB_DIR'); -- l_unmatch_oracle_dir variable gets value from Profile -- 2-JUL-2014 SAkula (CHG0031533)
    l_database           VARCHAR2(50);
    l_error              VARCHAR2(32000);
    CURSOR c_files(c_list_files VARCHAR2) IS
      SELECT *
      FROM   (SELECT TRIM(substr(txt,
		         instr(txt, ',', 1, LEVEL) + 1,
		         instr(txt, ',', 1, LEVEL + 1) -
		         instr(txt, ',', 1, LEVEL) - 1)) AS file_name
	  FROM   (SELECT ',' || c_list_files || ',' AS txt
	          FROM   dual)
	  CONNECT BY LEVEL <=
		 length(txt) - length(REPLACE(txt, ',', '')) - 1)
      WHERE  file_name != 'null';

  BEGIN
    errbuf  := '';
    retcode := 0;

    l_error := '1';

    -- check profiles

    IF fnd_profile.value('XXAP_SCANNED_INVOICES_DB_DIR') IS NULL OR
       fnd_profile.value('XXAP_UNSCANNED_INVOICES_DB_DIR') IS NULL THEN

      errbuf    := '------> Profiles XXAP_SCANNED_INVOICES_DB_DIR/XXAP_UNSCANNED_INVOICES_DB_DIR are not defined ';
      l_err_msg := errbuf;
      retcode   := 2;
      RETURN;

    END IF;

    fnd_file.put_line(fnd_file.log,
	          'XXAP_SCANNED_INVOICES_DB_DIR= ' || l_scan_oracle_dir);
    fnd_file.put_line(fnd_file.log,
	          'XXAP_UNSCANNED_INVOICES_DB_DIR= ' ||
	          l_unmatch_oracle_dir);

    fnd_file.put_line(fnd_file.log,
	          'Profile XXAP_UPLOAD_SCANNED_INVOICES= ' ||
	          fnd_profile.value('XXAP_UPLOAD_SCANNED_INVOICES'));

    -- set oracle directory
    create_oracle_dir(l_scan_oracle_dir, p_dir);
    create_oracle_dir(l_unmatch_oracle_dir, p_unmatch_dir);

    BEGIN

      SELECT category_id
      INTO   l_category_id
      FROM   fnd_document_categories c
      WHERE  c.name = nvl(fnd_profile.value('XXAP_SCAN_INV_CATEGOEY_NAME'),
		  p_category_name); --CHG0037828

    EXCEPTION
      WHEN OTHERS THEN
        errbuf    := 'Invalid Category -' || p_category_name;
        l_err_msg := errbuf;
        retcode   := 1;
        RAISE my_exception;
    END;

    fnd_file.put_line(fnd_file.log,
	          'Looking for files at directory ' || p_dir);
    fnd_file.put_line(fnd_file.log,
	          '----------------------------------------------------------- ');

    l_file_list := xxobjt_java_util.get_dir_files(p_dir);
    -- dbms_output.put_line(l_file_list);

    FOR i IN c_files(l_file_list) LOOP
      fnd_file.put_line(fnd_file.log, 'Process File ' || i.file_name);

      l_inx := l_inx + 1;

      l_err_code := 0;
      l_err_msg  := NULL;
      BEGIN
        -- dbms_output.put_line(i.file_name);
        IF upper(i.file_name) LIKE '%.TMP' THEN
          fnd_file.put_line(fnd_file.log, 'tmp file found --> ignore');
          continue;
        END IF;

        upload_file(p_dir,
	        l_scan_oracle_dir, -- Added New Parameter --2-JUL-2014 SAkula (CHG0031533)
	        i.file_name,
	        l_category_id,
	        l_err_code,
	        l_err_msg);

        IF l_err_code = 3 /*AND i.file_name LIKE 'INV%'*/
         THEN
          -- no invoice found / problem upload file
          -- CHG0037161
          -- wait for next run maybe invoice still in interface
          fnd_file.put_line(fnd_file.log, l_err_msg);

        ELSIF l_err_code IN (2, 1) THEN

          -- upload failed move file to unmatch folder with new name

          -- remove_file(l_unmatch_oracle_dir, i.file_name); -- CHG0037104
          fnd_file.put_line(fnd_file.log,
		    l_scan_oracle_dir || ' ' ||
		    l_unmatch_oracle_dir || ' ' || i.file_name);

          utl_file.fcopy(src_location  => l_scan_oracle_dir,
		 src_filename  => i.file_name,
		 dest_location => l_unmatch_oracle_dir,
		 dest_filename => fnd_global.conc_request_id || '_' ||
			      i.file_name);

          remove_file(l_scan_oracle_dir, i.file_name); -- CHG0037104

          fnd_file.put_line(fnd_file.log,
		    'Transferring file to ' || p_unmatch_dir ||
		    ' as ' || fnd_global.conc_request_id || '_' ||
		    i.file_name);
          l_err_msg := l_err_msg || chr(10) || 'Transferring file to ' ||
	           p_unmatch_dir || ' as ' ||
	           fnd_global.conc_request_id || '_' || i.file_name;
          -- mail error

          mail_error(i.file_name, p_dir, l_unmatch_oracle_dir, l_err_msg);

        ELSE
          -- successfull upload
          remove_file(l_scan_oracle_dir, i.file_name); -- CHG0037104

          fnd_file.put_line(fnd_file.log, 'Removing file ' || i.file_name);
        END IF;

        --  END IF;
      EXCEPTION

        WHEN OTHERS THEN
          errbuf  := 'Error:' || SQLERRM || ' ' || l_err_msg;
          retcode := 1;
          fnd_file.put_line(fnd_file.log,
		    '---->Error uploading file : ' || i.file_name || ': ' ||
		    SQLERRM || ' ' || l_err_msg);

          mail_error(i.file_name, p_dir, l_unmatch_oracle_dir, l_err_msg);

      END;
      fnd_file.put_line(fnd_file.log,
		'----------------------------------------------------------- ');
      COMMIT;
    END LOOP;

    fnd_file.put_line(fnd_file.log, '-----------------------');
    fnd_file.put_line(fnd_file.log, l_inx || ' files found');
  END;

  ------------------------------------
  -- get_content_type
  ------------------------------------

  FUNCTION get_content_type(p_ext VARCHAR2) RETURN VARCHAR2 IS
  BEGIN

    CASE upper(p_ext)
      WHEN 'PDF' THEN
        RETURN 'application/pdf';
      WHEN 'TXT' THEN
        RETURN 'plain/text';
      WHEN 'HTML' THEN
        RETURN 'text/html';
      WHEN 'ZIP' THEN
        RETURN 'application/x-zip-compressed';
      WHEN 'PNG' THEN
        RETURN 'image/x-png';
      WHEN 'PNG' THEN
        RETURN 'image/gif';
      WHEN 'TIF' THEN
        RETURN 'image/tiff';
      WHEN 'DOC' THEN
        RETURN 'application/msword';

      ELSE

        RETURN 'application/octet-stream';
    END CASE;

  END;
  -----------------------------
  -- init_attribute_wf
  -----------------------------
  PROCEDURE init_attribute_wf(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2) IS

    l_org_id NUMBER := ''; -- 07/30/2014 SAkula Added Variable l_org_id (CHG0032899)
  BEGIN

    -- 07/30/2014 SAkula Deriving value for Variable l_org_id  (CHG0032899)
    l_org_id := wf_engine.getitemattrnumber(itemtype => itemtype,
			        itemkey  => itemkey,
			        aname    => 'ORG_ID');

    -- 07/30/2014 SAkula Added Condition to send emails to Stratasys US Accounts Payable (CHG0032899)
    IF l_org_id = '737' THEN

      wf_engine.setitemattrtext(itemtype,
		        itemkey,
		        'XX_USER_NAME',
		        fnd_profile.value('XXAP_SSUS_NOTIFICATION_EMAIL'));
    ELSE
      wf_engine.setitemattrtext(itemtype,
		        itemkey,
		        'XX_USER_NAME',
		        fnd_global.user_name);
    END IF;

    /* Commented as Part of change CHG0032899
    wf_engine.setitemattrtext(itemtype,
                              itemkey,
                              'XX_USER_NAME',
                              fnd_global.user_name);  */

    wf_engine.setitemattrnumber(itemtype,
		        itemkey,
		        'XX_LOOP_MAX_COUNT',
		        fnd_profile.value('XXAP_INV_WF_MAX_LOOP_COUNT'));

    /*wf_engine.SetItemAttrText(itemtype => itemtype,
    itemkey  => itemkey,
    aname    => 'XX_INVOICE_DIST_DETAILS',
    avalue   => 'PLSQLCLOB:XXAP_INVOICES_UPLOAD.GET_INVOICE_NOTIF_DETAILS/'||
                      itemtype||':'|| itemkey);  */

    wf_engine.setitemattrnumber(itemtype,
		        itemkey,
		        'XX_DOCAPPRV_REMINDER_1_TIMEOUT',
		        fnd_profile.value('XXAP_WF_APINVAPR_DOCAPPRV_REMINDER_FIRST_TIMEOUT'));

    wf_engine.setitemattrnumber(itemtype,
		        itemkey,
		        'XX_DOCAPPRV_REMINDER_2_TIMEOUT',
		        fnd_profile.value('XXAP_WF_APINVAPR_DOCAPPRV_REMINDER_SECOND_TIMEOUT'));

    wf_engine.setitemattrnumber(itemtype,
		        itemkey,
		        'XX_DOCAPPRV_PRREMNDR_1_TIMEOUT',
		        fnd_profile.value('XXAP_WF_APINVAPR_DOCAPPRV_PR_REMINDER_FIRST_TIMEOUT'));

    wf_engine.setitemattrnumber(itemtype,
		        itemkey,
		        'XX_DOCAPPRV_PRREMNDR_2_TIMEOUT',
		        fnd_profile.value('XXAP_WF_APINVAPR_DOCAPPRV_PR_REMINDER_SECOND_TIMEOUT'));

  END;

  -----------------------------
  -- is_objet_approval_needded
  -----------------------------

  PROCEDURE is_objet_approval_needded(itemtype  IN VARCHAR2,
			  itemkey   IN VARCHAR2,
			  actid     IN NUMBER,
			  funcmode  IN VARCHAR2,
			  resultout OUT NOCOPY VARCHAR2) IS
    l_invoice_id NUMBER;
    l_tmp        NUMBER;

  BEGIN
    l_invoice_id := wf_engine.getitemattrnumber(itemtype,
				itemkey,
				'INVOICE_ID');

    OPEN c_check_needed(l_invoice_id);
    FETCH c_check_needed
      INTO l_tmp;
    CLOSE c_check_needed;

    IF nvl(l_tmp, 0) = 1 THEN
      resultout := wf_engine.eng_completed || ':' || 'Y';
    ELSE
      resultout := wf_engine.eng_completed || ':' || 'N';
    END IF;

  END;

  -----------------------------
  -- is_invoice_exists
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  -- 1.X      29.11.15  yuval tal       CHG0037104 - call function is_function_exists
  -- 1.1      21.2.16   yuval tal       CHG0037828 - call is_attached_file_exists
  PROCEDURE is_invoice_exists(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2) IS

    l_invoice_id     NUMBER;
    l_tmp            NUMBER;
    l_invoice_exists VARCHAR2(1);

  BEGIN

    l_invoice_id := wf_engine.getitemattrnumber(itemtype,
				itemkey,
				'INVOICE_ID');

    OPEN c_check_needed(l_invoice_id);
    FETCH c_check_needed
      INTO l_tmp;
    CLOSE c_check_needed;

    IF nvl(l_tmp, 0) = 0 THEN
      resultout := wf_engine.eng_completed || ':' || 'Y';
      RETURN;
    END IF;

    l_tmp := NULL;

    l_invoice_exists := is_scan_invoice_exists(l_invoice_id); --CHG0037828

    resultout := wf_engine.eng_completed || ':' || l_invoice_exists;

  END;

  -----------------------------
  -- is_invoice_exists
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  -- 1.0      16.08.11   yuval tal       Initial Build
  -- 1.1      21.2.16    yuval tal       CHG0037828 - check  by category only
  FUNCTION is_scan_invoice_exists(p_invoice_id NUMBER) RETURN VARCHAR2 IS

    CURSOR c(c_pk NUMBER) IS
      SELECT 1
      FROM   fnd_document_datatypes     dat,
	 fnd_document_entities_tl   det,
	 fnd_documents_tl           dt,
	 fnd_documents              d,
	 fnd_document_categories_tl dct,
	 fnd_attached_documents     ad,
	 fnd_lobs                   f,
	 ap_invoices_all            t
      WHERE  f.file_id = d.media_id
      AND    d.document_id = ad.document_id
      AND    dt.document_id = d.document_id
      AND    dt.language = userenv('LANG')
      AND    dct.category_id = d.category_id
      AND    dct.language = userenv('LANG')
      AND    d.datatype_id = dat.datatype_id
      AND    dat.language = userenv('LANG')
      AND    ad.entity_name = det.data_object_code
      AND    det.language = userenv('LANG')
      AND    d.datatype_id = 6
      AND    ad.entity_name = 'AP_INVOICES'
      AND    ad.pk1_value = to_char(t.invoice_id)
      AND    t.invoice_id = c_pk
	--  AND    dt.description LIKE '%' || t.doc_sequence_value || '%' --CHG0037828
      AND    dct.name = fnd_profile.value('XXAP_SCAN_INV_CATEGOEY_NAME'); --CHG0037828
    l_tmp NUMBER;
  BEGIN

    OPEN c(p_invoice_id);
    FETCH c
      INTO l_tmp;
    CLOSE c;

    IF nvl(l_tmp, 0) = 0 THEN

      RETURN 'N';
    ELSE
      RETURN 'Y';
    END IF;

  END;

  -----------------------------
  -- is_attached_file_exists
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  -- 1.0      16.08.11   yuval tal       Initial Build
  -- 1.1      21.2.16    yuval tal       CHG0037828 - rename proc name modify logic add parameter p_file_name
  FUNCTION is_attached_file_exists(p_invoice_id NUMBER,
		           p_file_name  VARCHAR2) RETURN VARCHAR2 IS

    CURSOR c(c_pk NUMBER) IS
      SELECT 1
      FROM   fnd_document_datatypes     dat,
	 fnd_document_entities_tl   det,
	 fnd_documents_tl           dt,
	 fnd_documents              d,
	 fnd_document_categories_tl dct,
	 fnd_attached_documents     ad,
	 fnd_lobs                   f,
	 ap_invoices_all            t
      WHERE  f.file_id = d.media_id
      AND    d.document_id = ad.document_id
      AND    dt.document_id = d.document_id
      AND    dt.language = userenv('LANG')
      AND    dct.category_id = d.category_id
      AND    dct.language = userenv('LANG')
      AND    d.datatype_id = dat.datatype_id
      AND    dat.language = userenv('LANG')
      AND    ad.entity_name = det.data_object_code
      AND    det.language = userenv('LANG')
      AND    d.datatype_id = 6
      AND    ad.entity_name = 'AP_INVOICES'
      AND    ad.pk1_value = to_char(t.invoice_id)
      AND    t.invoice_id = c_pk
      AND    (lower(f.file_name) LIKE lower('%' || p_file_name) /*OR
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    lower(dt.description) LIKE lower('%' || p_file_name)*/
	);
    l_tmp NUMBER;
  BEGIN

    OPEN c(p_invoice_id);
    FETCH c
      INTO l_tmp;
    CLOSE c;

    IF nvl(l_tmp, 0) = 0 THEN

      RETURN 'N';
    ELSE
      RETURN 'Y';
    END IF;

  END;

  --------------------------
  -- get_wf_inv_attachmnets
  --
  --  plsqlblob:xxap_invoices_upload.get_wf_inv_attachmnets/&INVOICE_ID
  -- find scan invoice by description field
  --------------------------
  PROCEDURE get_wf_inv_attachmnets(document_id   IN VARCHAR2,
		           display_type  IN VARCHAR2,
		           document      IN OUT BLOB,
		           document_type IN OUT VARCHAR2) IS
    lob_id NUMBER;

    CURSOR c(c_pk VARCHAR2) IS
      SELECT ad.pk1_value,
	 ad.entity_name,
	 f.file_data,
	 f.file_content_type,
	 substr(f.file_name, instr(f.file_name, '/', -1) + 1) file_name,
	 -- t.doc_sequence_value,
	 f.file_id
      FROM   fnd_document_datatypes     dat,
	 fnd_document_entities_tl   det,
	 fnd_documents_tl           dt,
	 fnd_documents              d,
	 fnd_document_categories_tl dct,
	 fnd_attached_documents     ad,
	 fnd_lobs                   f,
	 ap_invoices_all            t
      WHERE  f.file_id = d.media_id
      AND    d.document_id = ad.document_id
      AND    dt.document_id = d.document_id
      AND    dt.language = userenv('LANG')
      AND    dct.category_id = d.category_id
      AND    dct.language = userenv('LANG')
      AND    d.datatype_id = dat.datatype_id
      AND    dat.language = userenv('LANG')
      AND    ad.entity_name = det.data_object_code
      AND    det.language = userenv('LANG')
      AND    d.datatype_id = 6
      AND    ad.entity_name = 'AP_INVOICES'
      AND    ad.pk1_value = to_char(t.invoice_id)
      AND    t.invoice_id = to_char(c_pk)
	-- AND f.file_name LIKE '%'||t.doc_sequence_value || '%'
      AND    dt.description LIKE '%' || t.doc_sequence_value || '%'
      ORDER  BY d.creation_date DESC;

  BEGIN

    lob_id := to_number(document_id);

    FOR i IN c(lob_id) LOOP

      document_type := i.file_content_type || ';name=' ||
	           'Scanned_Invoice_' || i.file_name;
      dbms_lob.copy(document, i.file_data, dbms_lob.getlength(i.file_data));

      EXIT;

    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN

      wf_core.context('xxap_invoices_upload',
	          'get_wf_inv_att',
	          document_id,
	          display_type);
      RAISE;
  END;

  --------------------------------------
  -- PROCESS_DOC_REJECTION
  --------------------------------------

  PROCEDURE process_doc_rejection(itemtype  IN VARCHAR2,
		          itemkey   IN VARCHAR2,
		          actid     IN NUMBER,
		          funcmode  IN VARCHAR2,
		          resultout OUT NOCOPY VARCHAR2) IS
    l_invoice_id NUMBER;

  BEGIN

    l_invoice_id := wf_engine.getitemattrnumber(itemtype,
				itemkey,
				'INVOICE_ID');
    wf_engine.setitemattrtext(itemtype,
		      itemkey,
		      'APPROVER_NAME',
		      'SYSADMIN');

    wf_engine.setitemattrtext(itemtype,
		      itemkey,
		      'DOCUMENT_APPROVER',
		      'SYSADMIN');

    wf_engine.setitemattrtext(itemtype,
		      itemkey,
		      'WF_NOTE',
		      'Auto reject : No Scanned invoice found');

    ap_workflow_pkg.process_doc_rejection(itemtype  => itemtype,
			      itemkey   => itemkey,
			      actid     => actid,
			      funcmode  => funcmode,
			      resultout => resultout);

    UPDATE ap_invoice_lines
    SET    wfapproval_status = 'REJECTED',
           last_update_date  = SYSDATE,
           last_updated_by   = fnd_global.user_id,
           last_update_login = fnd_global.login_id
    WHERE  invoice_id = l_invoice_id
    AND    wfapproval_status <> 'MANUALLY APPROVED';
    /* AND line_number IN
    (SELECT line_number
       FROM ap_apinv_approvers
      WHERE notification_key = itemkey);*/

  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('APINVAPR',
	          'xxap_invoices_upload.process_doc_rejection',
	          itemtype,
	          itemkey,
	          to_char(actid),
	          funcmode);
      RAISE;
  END;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    invoice_requester_exists
  Author's Name:   Sandeep Akula
  Date Written:    18-JUNE-2014
  Purpose:         Checks if Requestor exists for the Invoice in Invoice Workbench
  Program Style:   Procedure Definition
  Called From:     Called in APINVAPR Workflow (Process: Main Approval Process)
  Workflow Usage Details:
                     Item Type: AP Invoice Approval
                     Process Internal Name: APPROVAL_MAIN
                     Process Display Name: Main Approval Process
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  18-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031533
  04-MAY-2016         1.1                  Lingaraj Sarangi  CHG0038386 - AP Invoice Approval workflow modification to handle OIC invoices
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE invoice_requester_exists(itemtype  IN VARCHAR2,
			 itemkey   IN VARCHAR2,
			 actid     IN NUMBER,
			 funcmode  IN VARCHAR2,
			 resultout OUT NOCOPY VARCHAR2) IS

    l_org_id            ap_invoices_all.org_id%TYPE;
    l_invoice_id        ap_invoices_all.invoice_id%TYPE;
    l_orig_system       VARCHAR2(20);
    l_requester_id      NUMBER := '';
    l_username          VARCHAR2(100) := '';
    l_user_display_name VARCHAR2(100) := '';
    l_source            VARCHAR2(25);/*Added CHG0038386*/
  BEGIN

    -- Do nothing in cancel or timeout mode
    --
    IF (funcmode <> wf_engine.eng_run) THEN
      resultout := wf_engine.eng_null;
      RETURN;
    END IF;

    l_org_id := wf_engine.getitemattrnumber(itemtype => itemtype,
			        itemkey  => itemkey,
			        aname    => 'ORG_ID');

    l_invoice_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				itemkey  => itemkey,
				aname    => 'INVOICE_ID');

    BEGIN
      SELECT requester_id, source /*Added CHG0038386*/
      INTO   l_requester_id, l_source /*Added CHG0038386*/
      FROM   ap_invoices_all
      WHERE  invoice_id = l_invoice_id
      AND    org_id = l_org_id;

      /*Added CHG0038386
       When Invoice Source is 'ORACLE_SALES_COMPENSATION', the request_id is null,
        So update the request id as -1
      */
      IF l_source = 'ORACLE_SALES_COMPENSATION' AND l_requester_id IS NULL THEN
         l_requester_id := -1 ;
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        l_requester_id := '';
    END;

    IF l_requester_id IS NULL THEN
      --wf_core.context('XXAP_INVOICES_UPLOAD','get_invoice_requestor',to_char(l_invoice_id));
      --raise;
      resultout := wf_engine.eng_completed || ':N';
    ELSE

      /*  l_orig_system:= 'PER';

      WF_DIRECTORY.GetUserName(l_orig_system,
                               l_requester_id,
                               l_username,
                               l_user_display_name);

      wf_engine.SetItemAttrText(itemtype   => itemType,
                                itemkey    => itemkey,
                                aname      => 'XX_INVOICE_REQUESTOR' ,
                                avalue     => l_username);*/

      resultout := wf_engine.eng_completed || ':Y';

    END IF;

  END invoice_requester_exists;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_nonmatched_inv_profile
  Author's Name:   Sandeep Akula
  Date Written:    18-JUNE-2014
  Purpose:         Derives the value for profile XXAP_INV_WF_EXECUTE_NONMATCHED_INV_REQUESTER_LOGIC
  Program Style:   Procedure Definition
  Called From:     Called in APINVAPR Workflow (Process: Main Approval Process)
  Workflow Usage Details:
                     Item Type: AP Invoice Approval
                     Process Internal Name: APPROVAL_MAIN
                     Process Display Name: Main Approval Process
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  18-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031533
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE get_nonmatched_inv_profile(itemtype  IN VARCHAR2,
			   itemkey   IN VARCHAR2,
			   actid     IN NUMBER,
			   funcmode  IN VARCHAR2,
			   resultout OUT NOCOPY VARCHAR2) IS
    l_value VARCHAR2(10);
  BEGIN

    l_value := fnd_profile.value('XXAP_INV_WF_EXECUTE_NONMATCHED_INV_REQUESTER_LOGIC');

    IF l_value = 'Y' THEN
      resultout := wf_engine.eng_completed || ':Y';
    ELSE
      resultout := wf_engine.eng_completed || ':N';
    END IF;

  END get_nonmatched_inv_profile;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    needs_reapproval
  Author's Name:   Sandeep Akula
  Date Written:    18-JUNE-2014
  Purpose:         Updates wfapproval_status column in Invoice Header and Lines tables
  Program Style:   Procedure Definition
  Called From:     Called in APINVAPR Workflow (Process: Main Approval Process)
  Workflow Usage Details:
                     Item Type: AP Invoice Approval
                     Process Internal Name: APPROVAL_MAIN
                     Process Display Name: Main Approval Process
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  18-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031533
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE needs_reapproval(itemtype  IN VARCHAR2,
		     itemkey   IN VARCHAR2,
		     actid     IN NUMBER,
		     funcmode  IN VARCHAR2,
		     resultout OUT NOCOPY VARCHAR2) IS

    l_invoice_id ap_invoices_all.invoice_id%TYPE;
  BEGIN

    l_invoice_id := wf_engine.getitemattrnumber(itemtype => itemtype,
				itemkey  => itemkey,
				aname    => 'INVOICE_ID');
    UPDATE ap_invoice_lines_all
    SET    wfapproval_status = 'REQUIRED'
    WHERE  invoice_id = l_invoice_id
    AND    wfapproval_status = 'INITIATED';

    UPDATE ap_invoices_all
    SET    wfapproval_status = 'NEEDS WFREAPPROVAL'
    WHERE  invoice_id = l_invoice_id;

    resultout := wf_engine.eng_completed || ':' || 'FINISH';

  END needs_reapproval;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    is_ssus_op_unit
  Author's Name:   Sandeep Akula
  Date Written:    18-JUNE-2014
  Purpose:         If the Operating Unit is SSUS this procedure will return Y else N
  Program Style:   Procedure Definition
  Called From:     Called in APINVAPR Workflow (Process: Main Approval Process)
  Workflow Usage Details:
                     Item Type: AP Invoice Approval
                     Process Internal Name: APPROVAL_INVOICE
                     Process Display Name: Invoice Approval Process
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  18-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031533
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE is_ssus_op_unit(itemtype  IN VARCHAR2,
		    itemkey   IN VARCHAR2,
		    actid     IN NUMBER,
		    funcmode  IN VARCHAR2,
		    resultout OUT NOCOPY VARCHAR2) IS
    l_org_id NUMBER;
  BEGIN

    l_org_id := wf_engine.getitemattrnumber(itemtype => itemtype,
			        itemkey  => itemkey,
			        aname    => 'ORG_ID');

    IF l_org_id = '737' THEN
      resultout := wf_engine.eng_completed || ':' || 'Y';
    ELSE
      resultout := wf_engine.eng_completed || ':' || 'N';
    END IF;

  END is_ssus_op_unit;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    check_active_person
  Author's Name:   Sandeep Akula
  Date Written:    17-JULY-2014
  Purpose:         Checks if the Person is Active in HR, has a Role record in wf_roles and has a active FND_USER record
  Program Style:   Procedure Definition
  Called From:     Called in XX_AP_INVOICE_APPROVER AME Approver Groups
  AME Usage Details:
                     Approver Group: XX_AP_INVOICE_APPROVER
                     Transaction Type: Payables Invoice Approval
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  17-JULY-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031533
  ---------------------------------------------------------------------------------------------------*/

  FUNCTION check_active_person(p_person_id IN NUMBER) RETURN VARCHAR2 IS
    l_person_id NUMBER;
  BEGIN

    l_person_id := '';
    BEGIN
      SELECT ppx.person_id
      INTO   l_person_id
      FROM   per_people_x ppx,
	 fnd_user     fu,
	 wf_roles     wr
      WHERE  ppx.person_id = fu.employee_id
      AND    ppx.person_id = wr.orig_system_id
      AND    wr.orig_system = 'PER'
      AND    nvl(trunc(fu.end_date), trunc(SYSDATE)) > = trunc(SYSDATE)
      AND    wr.orig_system_id = p_person_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_person_id := NULL;
    END;

    RETURN(l_person_id);

  END check_active_person;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    validate_approver
  Author's Name:   Sandeep Akula
  Date Written:    17-JULY-2014
  Purpose:         Derives the approver from AP Invoice if Original Approver is Terminated. The Approver derived will be the requester on the Invoice
  Program Style:   Procedure Definition
  Called From:     Called in XX_AP_INVOICE_APPROVER AME Approver Groups
  AME Usage Details:
                     Approver Group: XX_AP_INVOICE_APPROVER
                     Transaction Type: Payables Invoice Approval
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  17-JULY-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031533
  1-AUG-2017          1.1                  Piyali bhowmick   CHG0041105 - AP Invoice Approval Change
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION validate_approver(p_person_id    IN NUMBER,
		     p_invoice_id   IN NUMBER,
		     p_po_header_id IN NUMBER) RETURN NUMBER IS
    l_person_flag  VARCHAR2(10) := '';
   l_supervisor_id    NUMBER;
    l_supervisor_flag   VARCHAR2(10) := '';
    l_requester_id NUMBER; 
    l_person_id NUMBER;
  BEGIN

    l_person_flag := check_active_person(p_person_id); -- Checking if the Person is valid 
    
   

    IF l_person_flag IS NULL THEN
    
     -- The below part is commented on 02-AUGUST-2017 for CHG0041105 - AP Invoice Approval Change
     
     /* l_buyer_id := '';
      \* Deriving Buyer *\
      BEGIN
        SELECT agent_id
        INTO   l_buyer_id
        FROM   po_headers_all
        WHERE  po_header_id = p_po_header_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_buyer_id := '';
      END;

      l_buyer_flag := check_active_person(l_buyer_id); -- Checking if the Buyer is valid

      IF l_buyer_flag IS NOT NULL THEN
        RETURN(l_buyer_id);
      ELSE

        l_requester_id := '';
        \* Deriving AP Invoice Requester *\
        BEGIN
          SELECT requester_id
          INTO   l_requester_id
          FROM   ap_invoices_all
          WHERE  invoice_id = p_invoice_id;
        EXCEPTION
          WHEN OTHERS THEN
	l_requester_id := '';
        END;

        IF l_requester_id IS NULL THEN
          RETURN('-99');
        ELSE
          RETURN(l_requester_id);
        END IF; -- Requester Check

      END IF; -- Buyer Check*/ 
      
      -- Start  on 02-AUGUST-2017  for CHG0041105 - AP Invoice Approval Change
      
      l_person_id := p_person_id; 
      
      
      
      loop 
      --get supervisor_id of the person
       l_supervisor_id :=xxhr_util_pkg.get_suppervisor_id(l_person_id,sysdate,0); 
       --If Supervisor Id not Found, Find the last Supervisor assigned
       If l_supervisor_id is null Then
         Select supervisor_id
         into  l_supervisor_id
          From (
          SELECT a.*    
            FROM   per_all_people_f      p,
                   per_all_assignments_f a
            WHERE  p.person_id = a.person_id   
            AND    p.business_group_id = 0
            AND    a.business_group_id = 0
            AND    p.person_id         = l_person_id
            and    a.supervisor_id is not null
            Order by a.EFFECTIVE_START_DATE DESC
            ) Where rownum = 1;      
       End If;     
    
       
         
        if l_supervisor_id is not null then 
           l_person_id := l_supervisor_id ; 
           -- verify the supervisor is active
           l_supervisor_flag  :=xxap_invoices_upload.check_active_person(l_person_id);
           
          
            
             if l_supervisor_flag  is not null then
               l_requester_id := l_supervisor_id; 
              
              
               exit;
              end if;
              
         else
         -- if there is no supervisor it returns -99
          l_requester_id :=-99;
          exit;
        end if;
         
        
      end loop; 
      

    ELSE
      RETURN(p_person_id);
    END IF; -- Person Check
      return (l_requester_id); 
      -- End on 02-AUGUST-2017   for CHG0041105 - AP Invoice Approval Change
  END validate_approver;

  -----------------------------
  -- mail_error
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------

  -- 1.1      21.2.16   yuval tal       CHG0037828 - Add options to allow for multiple file names per invoice
  --                                    send mail according to VS XX_SEND_MAIL setup
  --                                    id dir contain US send OU

  PROCEDURE mail_error(p_file_name          VARCHAR2,
	           p_dir                VARCHAR2,
	           l_unmatch_oracle_dir VARCHAR2,
	           p_err_msg            VARCHAR2) IS
    l_err_code        NUMBER;
    l_err_msg         VARCHAR2(200);
    l_mail_list       VARCHAR2(500);
    l_admin_user_name VARCHAR2(500);
  BEGIN

    IF instr(p_dir, 'US') > 0 THEN
      l_admin_user_name := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					           p_program_short_name => 'XXINVOICEUPLOAD_US_USER_NAME');
      l_mail_list       := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					           p_program_short_name => 'XXINVOICEUPLOAD_US');
    ELSE
      l_admin_user_name := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					           p_program_short_name => 'XXINVOICEUPLOAD_USER_NAME');
      l_mail_list       := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					           p_program_short_name => 'XXINVOICEUPLOAD');

    END IF;
    IF l_admin_user_name IS NOT NULL THEN
      xxobjt_wf_mail.send_mail_text(p_to_role   => l_admin_user_name,
			p_cc_mail   => l_mail_list,
			p_subject   => 'AP Upload invoices failure',
			p_body_text => 'Error loading file ' ||
				   p_dir || ' ' ||
				   p_file_name || ' ' ||
				   p_err_msg,

			p_err_code    => l_err_code,
			p_err_message => l_err_msg);
      COMMIT;
    END IF;

  END;

END xxap_invoices_upload;
/