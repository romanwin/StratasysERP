CREATE OR REPLACE PACKAGE BODY xxpo_attch_mf_doc_pkg IS

  --------------------------------------------------------------------
  --  name:             XXPO_ATTCH_MF_DOC_PKG
  --  ver  date        name              desc
  --  1.0  8.5.11  YUVAL TAL    initial build

  --------------------------------------------------------------------
  --  purpose :         CUST315 - PO Attach automatically MFs to RFRs and to the POs
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  8.5.11       YUVAL TAL        initial build
  --  1.1  07.06.12     yuval tal        move mf attach file from header to line level
  --  1.2  15.7.12      yuval tal        add check_mf_att_header_exist
  --  1.3  16-APR-2018  Hubert, Eric     Description detail (CHG0042757):
  --                                       1) In attach_mf_to_po, add capability to attach XXQA: Quality
  --                                          Nonconformance Report.
  --                                       2) In attach_mf_to_po, capability to attach Malfunction Report was
  --                                          removed.
  --                                       3) Literal text referencing "MF" or "Malfunction" has been changed to
  --                                          reference the Nonconformance Disposition.  Object and Variable
  --                                          names were not changed and still may have "mf" in their name.
  --
  --  1.4  20-Jun-2018  Hubert, Eric      CHG0042754: Updated arguments for submitting XXQA: Quality Nonconformance Report to support updating of the nonconformance status and the report layout.
  --  1.5  31/12/2019   Roman W.          INC0179119 Concurrent XXMVFILE  completed with ERROR :
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            attach_mf_to_po
  --  create by:        YUVAL TAL
  --  Revision:        1.0
  --  creation date:   8.5.11
  --------------------------------------------------------------------
  --  purpose :        For each Nonconformance Disposition number;
  --                   1) Run XXQA: Quality Nonconformance Report.
  --                   2) Attach the pdf output to PO.
  --  In Param:        p_mf_number - Disposition Number (formerly called a Malfunction Number), which is prefixed with a "D".
  --                   p_po_header_id - Unique Po header id to to which the Quality Nonconformance report will be attached..
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  8.5.11  YUVAL TAL    initial build
  --  1.1  16-APR-2018 Hubert, Eric      CHG0042757: Add capability to attach XXQA: Quality Nonconformance Report to support the Nonconformance process which replaces the Malfunction process.
  --  1.2  20-Jun-2018 Hubert, Eric      CHG0042754: Updated arguments for submitting XXQA: Quality Nonconformance Report to support updating of the nonconformance status and the report layout.
  --------------------------------------------------------------------

  PROCEDURE attach_mf_to_po(errbuf       OUT VARCHAR2,
                            retcode      OUT NUMBER,
                            p_mf_number  IN VARCHAR2,
                            p_po_line_id IN NUMBER) IS
  
    l_print_option    BOOLEAN;
    l_printer_name    VARCHAR2(150) := NULL;
    l_request_id      NUMBER;
    l_result          BOOLEAN;
    l_completed_flag  BOOLEAN := FALSE;
    l_phase           VARCHAR2(100);
    l_status          VARCHAR2(100);
    l_dev_phase       VARCHAR2(100);
    l_dev_status      VARCHAR2(100);
    l_message         VARCHAR2(100);
    l_return_bool     BOOLEAN;
    l_conc_output_dir VARCHAR2(150) := fnd_profile.value('XXOBJT_CONC_OUTPUT_DIRECTORY');
    --ls_request_id NUMBER;
    --l_message1    VARCHAR2(200);
    --lb_result     BOOLEAN;
    l_result1       VARCHAR2(200);
    l_file_name     VARCHAR2(500);
    l_share_dir     VARCHAR2(500) := '/UtlFiles';
    l_report_layout VARCHAR2(30) := fnd_profile.value('XXQA_DEFAULT_NONCONFORMANCE_REPORT_LAYOUT'); --Profile option value for report layout code [CHG0042754]
  
    l_err_code    NUMBER;
    l_err_message VARCHAR2(50);
  BEGIN
    retcode := 0;
  
    log('----------------------------------------');
    log('Start attaching Disposition: ' || p_mf_number);
    log('----------------------------------------');
    -- check exist
  
    --CHG0042757-- IF check_mf_att_exist(p_po_line_id, 'File', 'MF' || p_mf_number) = 1 THEN
    IF check_mf_att_exist(p_po_line_id, 'File', p_mf_number) = 1 THEN
      --CHG0042757: the Disposition number has a "D" prefix.
      log('MF: ' || p_mf_number || ' Already Exists');
      RETURN;
    
    END IF;
  
    --
    -- Set printer and print option
    --
    l_printer_name := fnd_profile.value('PRINTER');
    l_print_option := fnd_request.set_print_options(printer        => l_printer_name,
                                                    style          => '',
                                                    copies         => 0,
                                                    save_output    => TRUE,
                                                    print_together => 'N');
  
    IF l_print_option = TRUE AND (SUBSTR(p_mf_number, 1, 1) = 'D') THEN
      --Check if p_mf_number references a Nonconformance Disposition # which is prefixed with a "D".  (MF# support has been deprecated.)
      /* CHG0042757 - Block to submit a Nonconformance Report request. */
      DECLARE
        l_organization_id NUMBER;
        l_layout_result   BOOLEAN;
      
      BEGIN
        /* Get the organization_id associated with the nonconformance number. */
        SELECT qr.organization_id
          INTO l_organization_id
          FROM qa_results qr
         INNER JOIN qa_plans qp
            ON (qr.plan_id = qp.plan_id)
         WHERE qp.plan_type_code = 'XX_DISPOSITION' --Plan type used just for Nonconformance plans
           AND qr.sequence7 = p_mf_number --sequence7 is globally used for the Disposition Number
        ;
      
        /*Assign template*/
        l_layout_result := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                                  template_code      => 'XXQA_NONCONFORMANCE_RPT',
                                                  template_language  => 'en',
                                                  template_territory => 'US',
                                                  output_format      => 'PDF');
      
        /*Submit Request for Quality Nonconformance report. */
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXQA_NONCONFORMANCE_RPT',
                                                   description => 'XXQA: Quality Nonconformance Report',
                                                   start_time  => NULL,
                                                   sub_request => FALSE,
                                                   argument1   => l_organization_id, --Org ID
                                                   argument2   => NULL, --Nonconformance Number
                                                   argument3   => NULL, --Verification Number
                                                   argument4   => p_mf_number, --Disposition Number
                                                   argument5   => 'N', --Print Verify NC Result (set to N so supplier won't see the verification)
                                                   argument6   => 'No', --Print Header Footer
                                                   argument7   => l_report_layout, --Updated to be based on profile option [CHG0042754]
                                                   argument8   => 'Yes' --Update Nonconformance Status [CHG0042754]
                                                   );
      
      EXCEPTION
        WHEN NO_DATA_FOUND OR TOO_MANY_ROWS THEN
          l_request_id := 0; --Flag this attempt as a "problem" so it can be wriiten to the log later.
      END;
    
      l_file_name := 'XXQA_NONCONFORMANCE_RPT_' || l_request_id || '_1.PDF';
    
      COMMIT;
    
      -- Check request run
      IF l_request_id = 0 THEN
        errbuf  := 1;
        retcode := 'Problem running, XXQA: Quality Nonconformance Report ' ||
                   fnd_message.get;
        log(retcode); -- to add the log
      ELSE
      
        -- loop to wait until the request finished
        l_completed_flag := FALSE;
        l_phase          := NULL;
        l_status         := NULL;
        l_dev_phase      := NULL;
        l_dev_status     := NULL;
        l_message        := NULL;
        -- wait for request to finish running
      
        l_return_bool := fnd_concurrent.wait_for_request(l_request_id,
                                                         5,
                                                         -- 600, rem by Roman W. INC0179119 31/12/2019
                                                         900, -- added by Roman W. INC0179119 31/12/2019
                                                         l_phase,
                                                         l_status,
                                                         l_dev_phase,
                                                         l_dev_status,
                                                         l_message);
      
        IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
          l_completed_flag := TRUE;
          errbuf           := 'Nonconformance report request finished  l_request_id=  ' ||
                              l_request_id;
        ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
        
          log('---------------------------------------------------------------');
          log('Nonconformance report request finished in error or warrning  ' ||
              l_message);
          log('---------------------------------------------------------------');
          retcode := 1;
          errbuf  := 'Nonconformance report request finished in error or warrning  ' ||
                     l_message;
          RETURN;
        END IF; -- dev_phase
      
        COMMIT;
      
        --------------------------------------------
        -- move file to servers shared dir
        ---------------------------------------------
      
        log('Start : Move file  ' || l_file_name || ' to ' || l_share_dir);
      
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXMVFILE',
                                                   argument1   => l_conc_output_dir, --from directory
                                                   argument2   => l_file_name, --from file name
                                                   argument3   => l_share_dir, --to directory
                                                   argument4   => l_file_name) --to file name
         ;
      
        COMMIT;
      
        IF l_request_id = 0 THEN
          errbuf := 1;
          log('Problem running, XXMVFILE:' || fnd_message.get());
        
        ELSE
        
          l_return_bool := fnd_concurrent.wait_for_request(l_request_id,
                                                           5,
                                                           600,
                                                           l_phase,
                                                           l_status,
                                                           l_dev_phase,
                                                           l_dev_status,
                                                           l_message);
          COMMIT;
        
          IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
            l_completed_flag := TRUE;
            errbuf           := 'XXMVFILE  l_request_id=  ' || l_request_id;
          ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
          
            log('---------------------------------------------------------------');
          
            errbuf := 'XXMVFILE : ended in error or warrning l_request_id= ' ||
                      l_request_id || fnd_message.get;
          
            log(errbuf);
            log('---------------------------------------------------------------');
            retcode := 1;
          
            RETURN;
          
          ELSE
          
            retcode := 1;
            errbuf  := 'XXMVFILE in error or warrning  ' || l_message;
            log(errbuf);
          
          END IF;
        END IF;
        -------------------------------------------
        -- Attached file
        --------------------------------------------
        log('Begin Attach File: Name=' || l_file_name);
      
        xxcs_attach_doc_pkg.objet_store_pdf('PO_LINES',
                                            p_po_line_id,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            l_request_id,
                                            33, -- TO_SUPPLIER--sr_rec.attachment_category_id,  -- the attachment category
                                            l_share_dir || '/' ||
                                            l_file_name,
                                            l_result1,
                                            'application/pdf',
                                            'XXOBJT_UTLFILES_DIR',
                                            --CHG0042757-- 'MF' || p_mf_number);
                                            p_mf_number); --CHG0042757: the Disposition number has a "D" prefix.
      
        IF l_result1 != 'COMPLETE:' || 'Y' THEN
          retcode := 2;
          errbuf  := l_result1;
          log('l_result1=' || l_result1);
        
          log('---------------------------------------------------------------');
          log('Failed attching Nonconformance report file ' ||
              'xxcs_attach_doc_pkg.objet_store_pdf : failed to attach file ' ||
              l_file_name);
          log('---------------------------------------------------------------');
        
        ELSE
          COMMIT;
          --------------------------------------------
          -- delete file from  shared dir
          ---------------------------------------------
          BEGIN
            utl_file.fremove(location => l_share_dir,
                             filename => l_file_name);
          
            errbuf := 'File ' || l_file_name || ' successfully attached ';
          EXCEPTION
            WHEN OTHERS THEN
              xxobjt_wf_mail.send_mail_text(p_to_role => 'SYSADMIN',
                                            p_subject => 'Warning in xxpo_attch_mf_doc_pkg: unable to delete file ' ||
                                                         l_share_dir || '/' ||
                                                         l_file_name,
                                            
                                            p_body_text   => 'Warning in xxpo_attch_mf_doc_pkg: unable to delete file ' ||
                                                             l_share_dir || '/' ||
                                                             l_file_name,
                                            p_err_code    => l_err_code,
                                            p_err_message => l_err_message);
            
          END;
          log(errbuf);
          retcode := 0;
          COMMIT;
        END IF;
      
      END IF; -- l_error_flag
    END IF; -- request_id
  
  END attach_mf_to_po;

  ---------------------------------------------------
  -- attach_mf_to_po_main
  ---------------------------------------------------

  PROCEDURE attach_mf_to_po_main(errbuf         OUT VARCHAR2,
                                 retcode        OUT NUMBER,
                                 p_po_header_id IN NUMBER) IS
  
    CURSOR c_mf IS
      SELECT l.po_line_id,
             nvl(tt.attribute4, '-1') attribute4,
             nvl(tt.attribute5, '-1') attribute5,
             nvl(tt.attribute6, '-1') attribute6,
             nvl(tt.attribute7, '-1') attribute7,
             nvl(tt.attribute8, '-1') attribute8
        FROM wip_discrete_jobs tt, po_lines_all l, po_distributions_all y
       WHERE tt.wip_entity_id = y.wip_entity_id
         AND l.po_line_id = y.po_line_id
         AND l.po_header_id = p_po_header_id;
    /*      SELECT nvl(attribute4, '-1') attribute4,
          nvl(attribute5, '-1') attribute5,
          nvl(attribute6, '-1') attribute6,
          nvl(attribute7, '-1') attribute7,
          nvl(attribute8, '-1') attribute8
     FROM wip_discrete_jobs tt
    WHERE tt.wip_entity_id IN (SELECT y.wip_entity_id
                                 FROM po_distributions_all y
                                WHERE y.po_header_id = p_po_header_id --line_location_id = 44286
                               );*/
  
    TYPE t_mf_tab IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
    l_mf_rec     t_mf_tab;
    l_current_mf VARCHAR2(50);
    l_errbuf     VARCHAR2(2000);
    l_retcode    NUMBER;
    l_flag       NUMBER;
  BEGIN
    retcode := 0;
    FOR i IN c_mf LOOP
    
      l_mf_rec(i.attribute4) := i.po_line_id;
      l_mf_rec(i.attribute5) := i.po_line_id;
      l_mf_rec(i.attribute6) := i.po_line_id;
      l_mf_rec(i.attribute7) := i.po_line_id;
      l_mf_rec(i.attribute8) := i.po_line_id;
    END LOOP;
  
    l_current_mf := l_mf_rec.first;
  
    LOOP
    
      EXIT WHEN l_current_mf IS NULL;
    
      -- call attch report
      ----------------------
      --      IF l_current_mf != -1 THEN --CHG0042757: the MF# was numeric but the disposition has a letter prefix.
      IF l_current_mf != '-1' THEN
        --CHG0042757: the MF# was numeric but the disposition has a letter prefix.
        l_errbuf  := NULL;
        l_retcode := 0;
        l_flag    := 1;
      
        attach_mf_to_po(errbuf       => l_errbuf,
                        retcode      => l_retcode,
                        p_mf_number  => l_current_mf,
                        p_po_line_id => l_mf_rec(l_current_mf));
      
        IF l_retcode != 0 THEN
        
          retcode := 1;
          errbuf  := errbuf || chr(13) || l_errbuf;
        END IF;
      END IF;
      -- find next MF
    
      IF l_mf_rec.exists(l_mf_rec.next(l_current_mf)) THEN
      
        l_current_mf := l_mf_rec.next(l_current_mf);
      
      ELSE
      
        l_current_mf := NULL;
      
      END IF;
    
    END LOOP;
  
    -- add short text
    IF l_flag = 1 AND
       check_mf_att_header_exist(p_po_header_id,
                                 'Short Text',
                                 'XXPO_MF_MSG_TO_SUPPLIER') = 0 THEN
    
      log('--------------------');
      log('Add short text : XXPO_MF_MSG_TO_SUPPLIER');
    
      -- cr 347 --------
      DECLARE
        l_att2 VARCHAR2(20);
      BEGIN
        IF check_mf_att_header_exist(p_po_header_id,
                                     'Short Text',
                                     'XX_RFR_ACCOUNT') = 0 THEN
          SELECT attribute2
            INTO l_att2
            FROM po_headers_all
           WHERE po_header_id = p_po_header_id;
        
          IF l_att2 = 'S' THEN
          
            attached_short_text(p_entity_name          => 'PO_HEADERS',
                                p_pk1                  => p_po_header_id,
                                p_document_text        => fnd_message.get_string('XXOBJT',
                                                                                 'XX_RFR_SUPPLIER_ACCOUNT'),
                                p_document_category    => 33,
                                p_document_description => 'XX_RFR_ACCOUNT');
          
          ELSIF l_att2 = 'O' THEN
            attached_short_text(p_entity_name          => 'PO_HEADERS',
                                p_pk1                  => p_po_header_id,
                                p_document_text        => fnd_message.get_string('XXOBJT',
                                                                                 'XX_RFR_OBJET_ACCOUNT'),
                                p_document_category    => 33,
                                p_document_description => 'XX_RFR_ACCOUNT');
          
          END IF;
        END IF;
      END;
    
      -- end cr 347 ----
      IF check_mf_att_header_exist(p_po_header_id,
                                   'Short Text',
                                   'XXPO_MF_MSG_TO_SUPPLIER') = 0 THEN
        attached_short_text(p_entity_name          => 'PO_HEADERS',
                            p_pk1                  => p_po_header_id,
                            p_document_text        => fnd_message.get_string('XXOBJT',
                                                                             'XXPO_MF_MSG_TO_SUPPLIER'),
                            p_document_category    => 33,
                            p_document_description => 'XXPO_MF_MSG_TO_SUPPLIER');
      
      END IF;
    
      COMMIT;
    END IF;
  
  END;

  ----------------------------------------------------
  -- check_mf_att_header_exist
  ------------------------------------------------------

  FUNCTION check_mf_att_header_exist(p_po_header_id NUMBER,
                                     p_data_type    VARCHAR2,
                                     p_desc         VARCHAR2) RETURN NUMBER IS
  
    CURSOR c IS
      SELECT 1
        FROM fnd_attached_docs_form_vl t
       WHERE t.pk1_value = to_char(p_po_header_id)
         AND t.entity_name = 'PO_HEADERS'
         AND t.category_id = 33
         AND t.function_name = 'PO_POXPOEPO'
         AND t.datatype_name = p_data_type --'File'
         AND t.document_description = p_desc;
  
    l_tmp NUMBER;
  
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN nvl(l_tmp, 0);
  
  END;

  ---------------------------------------------------
  -- check_mf_att_exist
  --------------------------------------------------

  FUNCTION check_mf_att_exist(p_po_line_id NUMBER,
                              p_data_type  VARCHAR2,
                              p_desc       VARCHAR2) RETURN NUMBER IS
  
    CURSOR c IS
      SELECT 1
        FROM fnd_attached_docs_form_vl t
       WHERE t.pk1_value = to_char(p_po_line_id)
         AND t.entity_name = 'PO_LINES'
         AND t.category_id = 33
         AND t.function_name = 'PO_POXPOEPO'
         AND t.datatype_name = p_data_type --'File'
         AND t.document_description = p_desc;
  
    l_tmp NUMBER;
  
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN nvl(l_tmp, 0);
  
  END;

  ----------------------------------------------------------
  -- attached_short_text
  --------------------------------------------------------
  PROCEDURE attached_short_text(p_entity_name          VARCHAR2,
                                p_pk1                  VARCHAR2,
                                p_document_text        VARCHAR2,
                                p_document_category    NUMBER,
                                p_document_description VARCHAR2) IS
    l_media_id NUMBER;
    l_rowid    VARCHAR2(30);
    --l_language    VARCHAR2(30);
    --l_dummy       VARCHAR2(5);
    l_document_id NUMBER;
  
    l_user_id                NUMBER := fnd_global.user_id;
    l_login_id               NUMBER := fnd_global.login_id;
    l_program_id             NUMBER := fnd_global.conc_program_id;
    l_program_application_id NUMBER := fnd_global.prog_appl_id;
    l_request_id             NUMBER := fnd_global.conc_request_id;
    l_curr_date              DATE := SYSDATE;
    l_program_update_date    DATE := NULL;
    x_document_id            NUMBER;
    l_seq_num                NUMBER;
  BEGIN
    SELECT (nvl(MAX(seq_num), 0) + 10)
      INTO l_seq_num
      FROM fnd_attached_documents
     WHERE entity_name = p_entity_name
       AND pk1_value = p_pk1;
  
    fnd_documents_pkg.insert_row(x_rowid                  => l_rowid,
                                 x_document_id            => l_document_id,
                                 x_creation_date          => l_curr_date,
                                 x_created_by             => l_user_id,
                                 x_last_update_date       => l_curr_date,
                                 x_last_updated_by        => l_user_id,
                                 x_last_update_login      => l_login_id,
                                 x_request_id             => l_request_id,
                                 x_program_application_id => l_program_application_id,
                                 x_program_id             => l_program_id,
                                 x_program_update_date    => l_program_update_date,
                                 x_datatype_id            => 1, --g_datatype_short_text,
                                 x_category_id            => p_document_category,
                                 x_security_type          => 1, --p_security_type,
                                 x_security_id            => NULL, --p_security_id,
                                 x_publish_flag           => 'Y',
                                 x_image_type             => NULL,
                                 x_storage_type           => NULL,
                                 x_usage_type             => 'O',
                                 x_start_date_active      => SYSDATE, --p_start_date_active,
                                 x_end_date_active        => NULL,
                                 x_language               => NULL,
                                 x_description            => p_document_description,
                                 x_file_name              => NULL,
                                 x_media_id               => l_media_id);
    x_document_id := l_document_id;
  
    -- now we need to insert the document text in fnd_document_short_text table
    ---------------------------------------------------------------------------
  
    INSERT INTO fnd_documents_short_text
      (media_id, short_text)
    VALUES
      (l_media_id, p_document_text);
  
    INSERT INTO fnd_attached_documents
      (attached_document_id,
       document_id,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       last_update_login,
       seq_num,
       entity_name,
       pk1_value,
       pk2_value,
       pk3_value,
       pk4_value,
       pk5_value,
       automatically_added_flag,
       program_application_id,
       program_id,
       program_update_date,
       request_id,
       attribute_category,
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
       column1,
       category_id)
    VALUES
      (fnd_attached_documents_s.nextval,
       l_document_id,
       SYSDATE,
       fnd_global.user_id, --NVL(X_created_by,0),
       SYSDATE,
       fnd_global.user_id, --NVL(X_created_by,0),
       fnd_global.login_id, -- X_last_update_login,
       nvl(l_seq_num, 0) + 10,
       p_entity_name,
       p_pk1,
       NULL, --p_pk2,
       NULL, -- p_pk3,
       NULL, --p_pk4,
       NULL, --p_pk5,
       'N',
       NULL,
       NULL,
       SYSDATE,
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
       NULL,
       NULL,
       p_document_category);
  
    COMMIT;
  END;

  ------------------------------------------------
  -- attach_mf_to_po_wf
  ------------------------------------------------
  PROCEDURE attach_mf_to_po_wf(itemtype  IN VARCHAR2,
                               itemkey   IN VARCHAR2,
                               actid     IN NUMBER,
                               funcmode  IN VARCHAR2,
                               resultout OUT NOCOPY VARCHAR2) IS
    l_document_id  NUMBER;
    l_errbuf       VARCHAR2(250);
    l_retcode      NUMBER;
    l_user_id      NUMBER;
    l_resp_id      NUMBER;
    l_resp_appl_id NUMBER;
    my_exception EXCEPTION;
  
    l_err_code    NUMBER;
    l_err_message VARCHAR2(50);
    l_po_num      VARCHAR2(50);
  
  BEGIN
    l_user_id      := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                  itemkey  => itemkey,
                                                  aname    => 'USER_ID');
    l_resp_id      := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                  itemkey  => itemkey,
                                                  aname    => 'RESPONSIBILITY_ID');
    l_resp_appl_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                  itemkey  => itemkey,
                                                  aname    => 'APPLICATION_ID');
  
    l_po_num := wf_engine.getitemattrtext(itemtype => itemtype,
                                          itemkey  => itemkey,
                                          aname    => 'DOCUMENT_NUMBER');
    fnd_global.apps_initialize(user_id      => l_user_id,
                               resp_id      => l_resp_id,
                               resp_appl_id => l_resp_appl_id);
  
    l_document_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                 itemkey  => itemkey,
                                                 aname    => 'DOCUMENT_ID');
    attach_mf_to_po_main(errbuf         => l_errbuf,
                         retcode        => l_retcode,
                         p_po_header_id => l_document_id);
  
    IF l_retcode != 0 THEN
    
      RAISE my_exception;
    
    END IF;
    resultout := wf_engine.eng_completed;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN',
                                    p_subject     => 'Error attaching Nonconformance report to PO:' ||
                                                     l_po_num,
                                    p_body_text   => l_errbuf,
                                    p_err_code    => l_err_code,
                                    p_err_message => l_err_message);
    
      wf_core.context('XXPO_ATTCH_MF_DOC_PKG',
                      'ATTACH_MF_TO_PO_WF',
                      itemtype,
                      itemkey,
                      to_char(actid),
                      funcmode,
                      'Others',
                      l_document_id,
                      l_errbuf || ' ' || SQLERRM);
      RAISE;
  END;
  ------------------------------------------------
  -- is_mf_related
  ------------------------------------------------
  PROCEDURE is_mf_related(itemtype  IN VARCHAR2,
                          itemkey   IN VARCHAR2,
                          actid     IN NUMBER,
                          funcmode  IN VARCHAR2,
                          resultout OUT NOCOPY VARCHAR2) IS
    TYPE l_rec IS TABLE OF VARCHAR2(50) INDEX BY VARCHAR2(50);
    l_mf_rec l_rec;
    --l_current_mf  VARCHAR2(50);
    --l_errbuf      VARCHAR2(2000);
    --l_retcode     NUMBER;
    --l_flag        NUMBER;
    l_document_id NUMBER;
    CURSOR c_mf IS
      SELECT nvl(attribute4, '-1') attribute4,
             nvl(attribute5, '-1') attribute5,
             nvl(attribute6, '-1') attribute6,
             nvl(attribute7, '-1') attribute7,
             nvl(attribute8, '-1') attribute8
        FROM wip_discrete_jobs tt
       WHERE tt.wip_entity_id IN (SELECT y.wip_entity_id
                                    FROM po_distributions_all y
                                   WHERE y.po_header_id = l_document_id --line_location_id = 44286
                                  );
  
  BEGIN
  
    l_document_id := wf_engine.getitemattrnumber(itemtype => itemtype,
                                                 itemkey  => itemkey,
                                                 aname    => 'DOCUMENT_ID');
    FOR i IN c_mf LOOP
    
      l_mf_rec(i.attribute4) := i.attribute4;
      l_mf_rec(i.attribute5) := i.attribute5;
      l_mf_rec(i.attribute6) := i.attribute6;
      l_mf_rec(i.attribute7) := i.attribute7;
      l_mf_rec(i.attribute8) := i.attribute8;
    END LOOP;
  
    IF l_mf_rec.count = 0 THEN
      resultout := wf_engine.eng_completed || ':N';
    ELSIF l_mf_rec.exists('-1') THEN
      l_mf_rec.delete('-1');
      IF l_mf_rec.count = 0 THEN
        resultout := wf_engine.eng_completed || ':N';
      ELSE
        resultout := wf_engine.eng_completed || ':Y';
      END IF;
    ELSE
      resultout := wf_engine.eng_completed || ':Y';
    
    END IF;
  END;
  -------------------------------------------------
  -- log
  ------------------------------------------------
  PROCEDURE log(p_message VARCHAR2) IS
  BEGIN
    IF fnd_global.conc_request_id < 0 THEN
      dbms_output.put_line(p_message);
    
    ELSE
    
      fnd_file.put_line(fnd_file.log, p_message);
    END IF;
  
  END;
END xxpo_attch_mf_doc_pkg;
/
