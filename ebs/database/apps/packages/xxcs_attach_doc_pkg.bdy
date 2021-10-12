CREATE OR REPLACE PACKAGE BODY xxcs_attach_doc_pkg IS

  PROCEDURE objet_store_pdf(p_entity_name       IN VARCHAR2,
                            p_pk1               IN VARCHAR2,
                            p_pk2               IN VARCHAR2,
                            p_pk3               IN VARCHAR2,
                            p_pk4               IN VARCHAR2,
                            p_pk5               IN VARCHAR2,
                            p_conc_req_id       IN NUMBER,
                            p_doc_categ         IN VARCHAR2,
                            p_file_name         IN VARCHAR2,
                            resultout           OUT NOCOPY VARCHAR2,
                            p_file_content_type VARCHAR2 DEFAULT 'application/pdf',
                            p_oracle_directory  VARCHAR2 DEFAULT NULL,
                            p_description       VARCHAR2 DEFAULT NULL) IS

    row_id_tmp        VARCHAR2(100);
    l_document_id     NUMBER;
    l_revision        NUMBER;
    l_po_hid          NUMBER;
    l_document_type   VARCHAR2(20);
    l_document_num    VARCHAR2(20);
    l_conc_req_id     NUMBER;
    l_media_id        NUMBER;
    l_blob_data       BLOB;
    l_blob_data2      BLOB;
    l_entity_name     VARCHAR2(30);
    seq_num           NUMBER;
    l_category_id     NUMBER;
    l_count           NUMBER;
    v_doc_type        VARCHAR2(100);
    v_cat             VARCHAR2(50);
    l_revision_number NUMBER;
    l_seq_num         NUMBER;
    v_file_name       VARCHAR2(150);
    v_file_name_alt   VARCHAR2(150);
  BEGIN

    fnd_file.put_line(fnd_file.log, 'P_ENTITY_NAME:' || p_entity_name);
    fnd_file.put_line(fnd_file.log, 'P_PK1:' || to_char(p_pk1));
    fnd_file.put_line(fnd_file.log,
                      'P_CONC_REQ_ID:' || to_char(p_conc_req_id));
    fnd_file.put_line(fnd_file.log, 'P_DOC_CATEG:' || p_doc_categ);
    fnd_file.put_line(fnd_file.log, 'P_FILE_NAME:' || p_file_name);

    l_blob_data  := empty_blob();
    l_blob_data2 := empty_blob();
    l_count      := 0;

    l_category_id := to_number(p_doc_categ);
    v_file_name   := p_file_name;

    xxcs_attach_doc_pkg.load_file_to_db(v_file_name,
                                        l_blob_data,
                                        p_oracle_directory);

    fnd_file.put_line(fnd_file.log, 'After load_file_to_db');

    fnd_documents_pkg.insert_row(row_id_tmp,
                                 l_document_id,
                                 SYSDATE,
                                 fnd_global.user_id, --NVL(X_created_by,0),
                                 SYSDATE,
                                 fnd_global.user_id, --NVL(X_created_by,0),
                                 fnd_global.login_id, --X_last_update_login,
                                 6, --X_datatype_id
                                 l_category_id, --Get the value for the category id 'PO Documents'
                                 1, --null,--security_type,
                                 NULL, --security_id,
                                 'Y', --null,--publish_flag,
                                 NULL, --image_type,
                                 NULL, --storage_type,
                                 'O', --usage_type,
                                 SYSDATE, --start_date_active,
                                 NULL, --end_date_active,
                                 NULL, --X_request_id, --null
                                 NULL, --X_program_application_id, --null
                                 NULL, --X_program_id,--null
                                 SYSDATE,
                                 NULL, --language,
                                 p_description, --'????? '||l_document_num||' ??'' '||NVL(TO_CHAR(l_revision_number),'0')||' '||TO_CHAR(SYSDATE,' dd-mm-rrrr HH24:mi'),--description,
                                 nvl(p_description, v_file_name), --l_file_name,
                                 l_media_id);

    SELECT MAX(seq_num)
      INTO l_seq_num
      FROM fnd_attached_documents ad
     WHERE ad.entity_name = p_entity_name --l_entity_name
       AND pk1_value = p_pk1; --TO_CHAR(l_po_hId);
    -- AND nvl(pk2_value,'0') = nvl(to_char(l_revision_number),'0');
    fnd_file.put_line(fnd_file.log, 'After Select MAX');

    INSERT INTO fnd_lobs
      (file_id,
       file_name,
       file_content_type,
       upload_date,
       expiration_date,
       program_name,
       program_tag,
       file_data,
       LANGUAGE,
       oracle_charset,
       file_format)
    VALUES
      (l_media_id,
       v_file_name, --l_full_file_name,--
       p_file_content_type, -- 'application/pdf', --   'Tau/PoDoc/pdf',
       SYSDATE,
       NULL,
       NULL,
       NULL,
       l_blob_data,
       NULL,
       NULL,
       'binary');

    fnd_file.put_line(fnd_file.log, 'After Insert into fnd_lobs');

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
      (fnd_attached_documents_s.NEXTVAL,
       l_document_id,
       SYSDATE,
       fnd_global.user_id, --NVL(X_created_by,0),
       SYSDATE,
       fnd_global.user_id, --NVL(X_created_by,0),
       fnd_global.login_id, -- X_last_update_login,
       nvl(l_seq_num, 0) + 10,
       p_entity_name,
       p_pk1,
       p_pk2,
       p_pk3,
       p_pk4,
       p_pk5,
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
       l_category_id);
    fnd_file.put_line(fnd_file.log,
                      'After Insert into fnd_attached_documents');
    -- By Adi (according to Hod) END IF;
    resultout := 'COMPLETE:' || 'Y';
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'In Objet_Store_PDF Exception:' || SQLERRM);
      resultout := SQLERRM; --'COMPLETE:' || 'N';

  END objet_store_pdf;
  /**********************************************************************************************************/
  PROCEDURE load_file_to_db(p_file_name        VARCHAR2,
                            p_blob             OUT BLOB,
                            p_oracle_directory VARCHAR2 DEFAULT 'XXOBJT_DIR') AS

    f_lob              BFILE;
    b_lob              BLOB := empty_blob();
    destination_offset INTEGER := 1;
    source_offset      INTEGER := 1;
    language_context   INTEGER := dbms_lob.default_lang_ctx;
    warning_message    NUMBER;

    v_file      VARCHAR2(150);
    v_dir       VARCHAR2(150);
    l_directory VARCHAR2(50) := p_oracle_directory; --'XXOBJT_DIR';

  BEGIN
    --   CREATE OR REPLACE DIRECTORY TAUPO_FILES as '/fs1/comn/devcomn/admin/out/DEV_present'--'/emcdsk0/tauhr/files/'
    dbms_output.put_line('load_file_to_db :oracle_directory=' ||
                         p_oracle_directory);

    dbms_lob.createtemporary(b_lob, TRUE, dbms_lob.session);

    v_file := substr(p_file_name,
                     instr(p_file_name, '/', -1) + 1,
                     length(p_file_name));
    v_dir  := substr(p_file_name, 1, instr(p_file_name, '/', -1) - 1);

    fnd_file.put_line(fnd_file.log, 'v_file:' || v_file);
    fnd_file.put_line(fnd_file.log, 'v_dir:' || v_dir);
    --  dbms_output.put_line('v_dir:' || v_dir || ' v_file:' || v_file);
    BEGIN

      SELECT directory_name
        INTO l_directory
        FROM all_directories
       WHERE directory_path = TRIM(v_dir)
         AND rownum = 1;

    EXCEPTION
      WHEN no_data_found THEN
        dbms_output.put_line('CREATE OR REPLACE DIRECTORY ' || l_directory ||
                             ' AS ''' || v_dir || '''');
        EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY ' || l_directory ||
                          ' AS ''' || v_dir || '''';
    END;
    -- dbms_output.put_line('v_dir:' || v_dir || ' v_file:' || v_file);

    f_lob := bfilename(l_directory, v_file); --'TAU_AMC_PO_ST2_3053076_1.PDF');--'Tm1Prs.txt');

    dbms_lob.fileopen(f_lob, dbms_lob.file_readonly);
    fnd_file.put_line(fnd_file.log, 'After fileopen');

    dbms_lob.loadblobfromfile(b_lob,
                              f_lob,
                              dbms_lob.getlength(f_lob),
                              destination_offset,
                              source_offset);
    fnd_file.put_line(fnd_file.log, 'After loadblobfromfile');
    dbms_lob.fileclose(f_lob);
    p_blob := b_lob;

    --  commit;
  END load_file_to_db;
  /**********************************************************************************************************/
  PROCEDURE relevant_sr_for_attach(errbuf        OUT VARCHAR2,
                                   retcode       OUT NUMBER,
                                   p_incident_id NUMBER DEFAULT NULL) IS

    CURSOR check_sr IS
      SELECT cia.incident_number,
             cia.incident_id,
             cis.attribute2 attachment_category_id
        FROM cs_incidents_all_b cia, cs_incident_statuses_b cis
       WHERE cia.external_attribute_10 IS NULL
         AND -- The program hasn't attached yet the SR report for the SR
             cis.incident_status_id = cia.incident_status_id
         AND cis.attribute2 IS NOT NULL
         AND cia.incident_id = nvl(p_incident_id, cia.incident_id)
         AND rownum < 11; -- The SR is in status which is relevant for attaching the SR Report

    CURSOR csr_dest_hosts IS
      SELECT host FROM fnd_nodes WHERE support_db = 'Y';

    cur_dest_host csr_dest_hosts%ROWTYPE;
    l_dest_dir    VARCHAR2(50);
    l_dest_user   VARCHAR2(50);

    l_request_id  NUMBER;
    v_request_id  NUMBER;
    ls_request_id NUMBER;
    v_result      VARCHAR2(100);

    lb_result    BOOLEAN;
    v_phase      VARCHAR2(20);
    v_status     VARCHAR2(20);
    v_dev_phase  VARCHAR2(20);
    v_dev_status VARCHAR2(20);
    v_message1   VARCHAR2(20);
    l_file_name  VARCHAR2(500);
    v_sr_number  VARCHAR2(64);
    l_result     BOOLEAN;
    v_target_dir VARCHAR2(50);
    v_pk1        VARCHAR2(30);

    -- sari friman 18/03/2010
    lv_flag_status    CHAR(1);
    lv_flag_type      CHAR(1);
    lv_flag_item      CHAR(1);
    lv_flag_send_mail CHAR(1) := 'N';
    lv_cont_mail      VARCHAR2(500);

  BEGIN

    SELECT '/usr/tmp/' || NAME, lower('ORA' || NAME)
      INTO l_dest_dir, l_dest_user
      FROM v$database;

    FOR sr_rec IN check_sr LOOP

      fnd_file.put_line(fnd_file.log,
                        'Service Request: ' || sr_rec.incident_number);
      BEGIN

        v_sr_number := sr_rec.incident_number;
        v_pk1       := to_char(sr_rec.incident_id);
        l_result    := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                              template_code      => 'XXCSSRREP',
                                              template_language  => 'en',
                                              template_territory => NULL,
                                              output_format      => 'PDF');

        ---- start sari fraiman 18/03/2010
        BEGIN
          SELECT 'Y'
            INTO lv_flag_status
            FROM cs_incident_statuses_b cisb, cs_incidents_all_b ciab
           WHERE ciab.incident_status_id = cisb.incident_status_id
             AND cisb.attribute5 = 'Y' -- in dev cisb.attribute5
             AND ciab.incident_number = v_sr_number;

          SELECT 'Y'
            INTO lv_flag_type
            FROM cs_incident_types_b citb, cs_incidents_all_b ciab
           WHERE ciab.incident_type_id = citb.incident_type_id
             AND citb.attribute7 = 'Y' -- in dev citb.attribute5
             AND ciab.incident_number = v_sr_number;

          SELECT 'Y'
            INTO lv_flag_item
            FROM csi_item_instances cii, cs_incidents_all_b ciab
           WHERE ciab.customer_product_id = cii.instance_id
             AND cii.attribute8 IN
                 (SELECT v.flex_value
                    FROM fnd_flex_values     v,
                         fnd_flex_value_sets s,
                         fnd_flex_values_tl  t
                   WHERE flex_value_set_name = 'XXCS_CS_REGIONS'
                     AND s.flex_value_set_id = v.flex_value_set_id
                     AND t.flex_value_id = v.flex_value_id
                     AND v.attribute5 = 'Direct'
                     AND t.LANGUAGE = 'US')
             AND ciab.incident_number = v_sr_number;

          SELECT h.email_address
            INTO lv_cont_mail
            FROM cs_hz_sr_contact_points c,
                 hz_contact_points       h,
                 hz_parties              hp,
                 hz_relationships        r
           WHERE h.owner_table_id = c.party_id
             AND h.owner_table_name = 'HZ_PARTIES'
             AND h.contact_point_type = 'EMAIL'
             AND r.subject_type = 'PERSON'
             AND r.party_id = c.party_id
             AND hp.party_id = r.subject_id
             AND c.contact_point_id = h.contact_point_id
             AND h.contact_point_id IN
                 (SELECT h2.contact_point_id
                    FROM hz_contact_points h2, cs_hz_sr_contact_points c2
                   WHERE c2.incident_id = c.incident_id
                     AND c2.primary_flag = 'Y'
                     AND c2.party_id = h2.owner_table_id)
             AND c.incident_id = sr_rec.incident_id;

        EXCEPTION
          WHEN OTHERS THEN
            lv_flag_status := NULL;
            lv_flag_type   := NULL;
            lv_flag_item   := NULL;
            lv_cont_mail   := NULL;
        END;

        IF lv_flag_status = 'Y' AND lv_flag_type = 'Y' AND
           lv_flag_item = 'Y' AND lv_cont_mail IS NOT NULL THEN

          lv_flag_send_mail := 'Y';
        ELSE
          lv_flag_send_mail := 'N';
        END IF;

        ---End  sari fraiman 18/03/2010
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXCSSRREP',
                                                   argument1   => v_sr_number,
                                                   argument2   => lv_flag_send_mail, --Y /N  Send Mail
                                                   argument3   => NULL);
        COMMIT;
        fnd_file.put_line(fnd_file.log, 'Submit Report: ' || l_request_id);

      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,
                            'Submit Request Error' || SQLERRM);
      END;

      lb_result := fnd_concurrent.wait_for_request(l_request_id,
                                                   10,
                                                   0,
                                                   v_phase,
                                                   v_status,
                                                   v_dev_phase,
                                                   v_dev_status,
                                                   v_message1);

      IF v_dev_phase = 'COMPLETE' THEN
        IF v_dev_status = 'WARNING' OR v_dev_status = 'ERROR' THEN
          fnd_file.put_line(fnd_file.log,
                            'SR No. ' || v_sr_number ||
                            ' Ends with error or warnnig');
          NULL;
        ELSIF v_dev_status = 'NORMAL' THEN

          FOR cur_dest_host IN csr_dest_hosts LOOP
            --Running Avi Shell

            -- | Parameters     ARGUMENT1     - Request ID                          |
            -- |                ARGUMENT2     - Destination Diectory                |
            -- |                ARGUMENT3     - Sever name                          |
            -- |                ARGUMENT4     - Destination User Name               |

            ls_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                        program     => 'XXAU_CP_PDF_TODIR', -- Avi concurrent short name
                                                        argument1   => 'XXCSSRREP_' ||
                                                                       l_request_id,
                                                        argument2   => l_dest_dir,
                                                        argument3   => cur_dest_host.host,
                                                        argument4   => l_dest_user);

            COMMIT;
            lb_result := fnd_concurrent.wait_for_request(ls_request_id,
                                                         10,
                                                         0,
                                                         v_phase,
                                                         v_status,
                                                         v_dev_phase,
                                                         v_dev_status,
                                                         v_message1);

            fnd_file.put_line(fnd_file.log,
                              'Send file to server: ' || cur_dest_host.host);

          END LOOP;

          l_file_name := l_dest_dir || '/' || 'XXCSSRREP_' || l_request_id ||
                         '_1.PDF';

          fnd_file.put_line(fnd_file.log, 'File Name: ' || l_file_name);

          /*v_Request_id := fnd_request.Submit_Request(application => 'XXOBJT',
          program     => 'XXFND_ATTCH_DOC',
          argument1   => null,--'CS_INCIDENTS',
          argument2   => null,--v_pk1, -- No Send Mail
          argument3   => null,
          argument4   => null,
          argument5   => null,
          argument6   => null,
          argument7   => null,--l_Request_id,
          argument8   => null,--SR_rec.attachment_category_id,
          argument9   => null);--l_file_name);*/

          objet_store_pdf('CS_INCIDENTS',
                          sr_rec.incident_id,
                          NULL,
                          NULL,
                          NULL,
                          NULL,
                          l_request_id,
                          sr_rec.attachment_category_id,
                          l_file_name,
                          v_result);
        END IF;
      END IF;

      IF v_result = 'COMPLETE:Y' THEN
        BEGIN
          UPDATE cs_incidents_all_b
             SET external_attribute_10 = 'Y'
           WHERE incident_id = sr_rec.incident_id;
          COMMIT;
        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Update Error' || SQLERRM);
        END;
      ELSE
        fnd_file.put_line(fnd_file.log,
                          'Objet_Store_PDF Procedure Completed with Error on SR #' ||
                          v_sr_number);
      END IF;

    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'relevant_SR_for_Attach fail on SR #' ||
                        v_sr_number || ' Error:' || SQLERRM);
  END relevant_sr_for_attach;

END xxcs_attach_doc_pkg;
/

