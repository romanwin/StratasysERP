CREATE OR REPLACE PACKAGE BODY xxobjt_fnd_attachments AS

  --------------------------------------------------------------------
  --  name:            XXOBJT_FND_ATTACHMENTS
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :        upload scan invoices into fnd_lobs (xxap_invoices_upload)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --  1.1  25.10.2011  yuval tal         SUPPORT FILE SHARING : add param p_file_arc_path
  --                                     to handle_file call from java conc program
  --                                     XX FND Attachment2Archive/XXFNDATTARC
  --  1.2  12/06/2012  Dalit A. Raviv    add procedures:
  --                                     get_environment_name, load_file_to_db,
  --                                     get_directory_path,   create_oracle_dir
  --  1.3  27/05/2014  Dalit A. Raviv    CHG0031652 - CS attachments - handle_ib_attachments, handle_sr_attachments, handle_oks_attachments
  --  1.4  06/05/2015  Michal Tzvik      CHG0033893 - Add function Get_Short_Text_Attached
  --  1.5  10/05/2015  Michal Tzvik      CHG0035332 New procedure: update_short_text_att
  --                                     New procedure: delete_attachment
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_short_message_name
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --------------------------------------------------------------------
  FUNCTION get_short_message_name(p_entity_name VARCHAR2) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(150);
  BEGIN
  
    SELECT t.attribute6 message_name
    INTO   l_tmp
    FROM   fnd_flex_values_vl  t,
           fnd_flex_value_sets ffv
    WHERE  ffv.flex_value_set_id = t.flex_value_set_id
    AND    ffv.flex_value_set_name = 'XXFND_ARCHIVE_RULES'
          
    AND    t.attribute1 = p_entity_name
    AND    t.attribute6 IS NOT NULL
    AND    rownum = 1;
    RETURN l_tmp;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END get_short_message_name;

  --------------------------------------------------------------------
  --  name:            get_entity_dyn_select
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --------------------------------------------------------------------
  FUNCTION get_entity_dyn_select(p_entity_name VARCHAR2,
		         p_category_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(500);
  BEGIN
    SELECT t.dyn_condition
    INTO   l_tmp
    FROM   xxobjt_fnd_attachments_rules_v t
    WHERE  t.entity_name = p_entity_name
    AND    (nvl(t.category_id, '-1') =
          nvl(p_category_id, nvl(t.category_id, '-1')) OR
          t.category_id IS NULL)
    AND    rownum = 1
    AND    dyn_condition IS NOT NULL;
  
    RETURN l_tmp;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    
  END get_entity_dyn_select;

  --------------------------------------------------------------------
  --  name:            check_dyn_condition
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --------------------------------------------------------------------
  FUNCTION check_dyn_condition(p_entity_name VARCHAR2,
		       p_category_id NUMBER,
		       p_pk1         VARCHAR2,
		       p_pk2         VARCHAR2,
		       p_pk3         VARCHAR2) RETURN NUMBER IS
    l_tmp    NUMBER;
    sql_stmt VARCHAR2(2000);
    l_add    VARCHAR2(50);
    TYPE curtyp IS REF CURSOR;
    l_cur curtyp;
  
  BEGIN
  
    sql_stmt := get_entity_dyn_select(p_entity_name, p_category_id);
    -- dbms_output.put_line('sql_stmt' || sql_stmt || l_add);
    IF sql_stmt IS NULL THEN
      RETURN 1;
    ELSE
    
      -- sql_stmt := 'SELECT 1 FROM po_headers_ALL where po_header_id=:1 and
      -- authorization_status=''APPROVED''';
      IF p_pk2 IS NULL THEN
        l_add := ' AND :2=1';
      END IF;
      IF p_pk3 IS NULL THEN
        l_add := l_add || ' AND :3=1';
      END IF;
      --  dbms_output.put_line(sql_stmt || l_add);
      OPEN l_cur FOR sql_stmt || l_add
        USING p_pk1, nvl(p_pk2, 1), nvl(p_pk3, 1);
    
      FETCH l_cur
        INTO l_tmp;
      CLOSE l_cur;
    END IF;
  
    RETURN nvl(l_tmp, 0);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
    
  END check_dyn_condition;

  --------------------------------------------------------------------
  --  name:            generate_arc_path
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --------------------------------------------------------------------
  FUNCTION generate_arc_path(p_creation_date DATE,
		     p_file_id       NUMBER,
		     p_entity_name   VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
  
    RETURN fnd_profile.value('XXFND_ATTCH_ARC_PATH') || '/' || p_entity_name || '/' || to_char(p_creation_date,
							           'yyyy/mm');
  END generate_arc_path;

  --------------------------------------------------------------------
  --  name:            generate_arc_file_name
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --------------------------------------------------------------------
  FUNCTION generate_arc_file_name(p_file_id NUMBER) RETURN VARCHAR2 IS
    --l_tmp       VARCHAR2(250);
    l_file_name VARCHAR2(500);
  BEGIN
  
    SELECT file_name
    INTO   l_file_name
    FROM   fnd_lobs t
    WHERE  t.file_id = p_file_id;
  
    l_file_name := substr(l_file_name,
		  instr(l_file_name, '/', -1) + 1,
		  length(l_file_name));
  
    l_file_name := REPLACE(l_file_name, ' ', '_');
    l_file_name := REPLACE(l_file_name, '~', '_');
  
    RETURN p_file_id || '_' || l_file_name;
  END generate_arc_file_name;

  --------------------------------------------------------------------
  --  name:            delete_attachment
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   11.06.2015
  --------------------------------------------------------------------
  --  purpose :        Delete attachment
  --  Parameters:      If p_document_id is not populated,
  --                   The following must be populated:
  --                   p_entity_name, p_category_name, p_function_name
  --                   p_delete_ref_flag is used in order to delete from fnd_attached_documents too
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11.06.2015  Michal Tzvik      CHG0035332 - initial build
  --  1.1 3.4.16       yuval tal         INC0061782 - change parameter  type of p_pk1/2/3 from number to varchar
  --------------------------------------------------------------------
  PROCEDURE delete_attachment(err_code          OUT NUMBER,
		      err_msg           OUT VARCHAR2,
		      p_document_id     VARCHAR2,
		      p_entity_name     VARCHAR2,
		      p_category_name   VARCHAR2,
		      p_function_name   VARCHAR2,
		      p_delete_ref_flag VARCHAR2 DEFAULT 'N',
		      p_pk1             VARCHAR2, --INC0061782
		      p_pk2             VARCHAR2, --INC0061782
		      p_pk3             VARCHAR2 /*INC0061782 */) IS
  
    CURSOR c_attachment(p_document_id   VARCHAR2,
		p_entity_name   VARCHAR2,
		p_category_name VARCHAR2,
		p_function_name VARCHAR2) IS
      SELECT fadfv.document_id,
	 fadfv.datatype_id
      FROM   fnd_attached_docs_form_vl  fadfv,
	 fnd_document_categories_tl fdct
      WHERE  1 = 1
      AND    fadfv.document_id = nvl(p_document_id, fadfv.document_id)
      AND    fadfv.function_name =
	 nvl(p_function_name, fadfv.function_name)
      AND    fadfv.entity_name = nvl(p_entity_name, fadfv.entity_name)
      AND    fadfv.pk1_value = p_pk1
      AND    (fadfv.pk2_value = p_pk2 OR p_pk2 IS NULL)
      AND    (fadfv.pk2_value = p_pk2 OR p_pk2 IS NULL)
      AND    (fadfv.pk3_value = p_pk3 OR p_pk3 IS NULL)
      AND    fadfv.category_id = fdct.category_id
      AND    fdct.language = 'US'
      AND    fdct.user_name = nvl(p_category_name, fdct.user_name);
  BEGIN
    err_code := 0;
    err_msg  := '';
  
    FOR r_att IN c_attachment(p_document_id,
		      p_entity_name,
		      p_category_name,
		      p_function_name) LOOP
      -- delete file
      fnd_documents_pkg.delete_row(x_document_id   => r_att.document_id, --
		           x_datatype_id   => r_att.datatype_id, --
		           delete_ref_flag => p_delete_ref_flag);
    END LOOP;
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      err_code := 1;
      err_msg  := 'Unexpected error in xxobjt_fnd_attachments.delete_attachment: ' ||
	      SQLERRM;
  END delete_attachment;

  --------------------------------------------------------------------
  --  name:            create_short_text_att
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :        CREATE ATTACHMNETS
  --                   called by java conc program : XXFNDATTARC
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --------------------------------------------------------------------
  PROCEDURE create_short_text_att(err_code                  OUT NUMBER,
		          err_msg                   OUT VARCHAR2,
		          p_document_id             OUT NUMBER,
		          p_category_id             NUMBER,
		          p_entity_name             VARCHAR2,
		          p_file_name               VARCHAR2,
		          p_title                   VARCHAR2,
		          p_description             VARCHAR2,
		          p_short_text              VARCHAR2 DEFAULT NULL,
		          p_short_text_message_name VARCHAR2 DEFAULT NULL,
		          p_pk1                     NUMBER,
		          p_pk2                     NUMBER,
		          p_pk3                     NUMBER) IS
  
    l_document_id NUMBER;
    l_row_id_tmp  VARCHAR2(100);
    l_media_id    NUMBER;
    l_seq_num     NUMBER;
    l_short_text  VARCHAR2(3200);
  BEGIN
    err_code := 0;
  
    fnd_documents_pkg.insert_row(x_rowid               => l_row_id_tmp,
		         x_document_id         => l_document_id,
		         x_creation_date       => SYSDATE,
		         x_created_by          => fnd_global.user_id,
		         x_last_update_date    => SYSDATE,
		         x_last_updated_by     => fnd_global.user_id,
		         x_last_update_login   => fnd_global.login_id,
		         x_datatype_id         => 1, -- :x_datatype_id,
		         x_category_id         => p_category_id,
		         x_security_type       => 1,
		         x_publish_flag        => 'Y', --:x_publish_flag,
		         x_usage_type          => 'O', -- :x_usage_type,
		         x_start_date_active   => SYSDATE, --:x_start_date_active,
		         x_program_update_date => SYSDATE,
		         x_language            => NULL,
		         x_description         => p_description,
		         x_file_name           => p_file_name,
		         x_media_id            => l_media_id,
		         x_title               => p_title);
  
    SELECT MAX(seq_num)
    INTO   l_seq_num
    FROM   fnd_attached_documents ad
    WHERE  ad.entity_name = p_entity_name
    AND    pk1_value = p_pk1
    AND    nvl(pk2_value, '-1') = nvl(p_pk2, '-1')
    AND    nvl(pk3_value, '-1') = nvl(p_pk3, '-1');
  
    IF p_short_text IS NOT NULL THEN
      l_short_text := p_short_text;
    ELSE
      fnd_message.set_name(application => 'XXOBJT',
		   NAME        => nvl(p_short_text_message_name,
			          'XXOBJT_FND_ARCHIVE_MESSAGE'));
      fnd_message.set_token(token => 'FILE_NAME', VALUE => p_file_name);
      l_short_text := fnd_message.get;
    
    END IF;
  
    INSERT INTO fnd_documents_short_text
      (media_id,
       short_text)
    VALUES
      (l_media_id,
       l_short_text);
  
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
       p_pk2,
       p_pk3,
       NULL, -- p_pk4,
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
       p_category_id);
  
    p_document_id := l_document_id;
  EXCEPTION
    WHEN OTHERS THEN
      err_code := 1;
      err_msg  := 'Error creating Attachmnets - ' || SQLERRM;
    
  END create_short_text_att;
  --------------------------------------------------------------------
  --  name:            update_short_text_att
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   03.06.2015
  --------------------------------------------------------------------
  --  purpose :        Update short text attachment
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03.06.2015  Michal Tzvik      CHG0035332 - initial build
  --------------------------------------------------------------------
  PROCEDURE update_short_text_att(err_code        OUT NUMBER,
		          err_msg         OUT VARCHAR2,
		          p_entity_name   VARCHAR2,
		          p_category_name VARCHAR2,
		          p_function_name VARCHAR2,
		          p_short_text    VARCHAR2,
		          p_pk1           NUMBER,
		          p_pk2           NUMBER,
		          p_pk3           NUMBER) IS
  
    l_document_id NUMBER;
    l_row_id_tmp  VARCHAR2(100);
    l_media_id    NUMBER;
    l_seq_num     NUMBER;
    l_short_text  VARCHAR2(3200);
  
  BEGIN
    err_code := 0;
  
    IF p_short_text IS NOT NULL THEN
    
      UPDATE fnd_documents_short_text fdst
      SET    fdst.short_text = p_short_text
      WHERE  fdst.media_id IN
	 (SELECT MAX(fadfv.media_id) keep(dense_rank LAST ORDER BY fadfv.creation_date) -- update most current attachment
	  FROM   fnd_attached_docs_form_vl  fadfv,
	         fnd_document_categories_tl fdct
	  WHERE  fadfv.function_name = p_function_name
	  AND    EXISTS
	   (SELECT 1
	          FROM   fnd_document_datatypes fdt
	          WHERE  fdt.language = 'US'
	          AND    fdt.name = 'SHORT_TEXT'
	          AND    fdt.datatype_id = fadfv.datatype_id)
	  AND    fadfv.entity_name = p_entity_name
	  AND    fadfv.pk1_value = p_pk1
	  AND    (fadfv.pk2_value = p_pk2 OR p_pk2 IS NULL)
	  AND    (fadfv.pk3_value = p_pk3 OR p_pk3 IS NULL)
	  AND    fadfv.category_id = fdct.category_id
	  AND    fdct.language = 'US'
	  AND    fdct.user_name = nvl(p_category_name, fdct.user_name));
    END IF;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      err_code := 1;
      err_msg  := 'Error updating short text attachmnets - ' || SQLERRM;
    
  END update_short_text_att;

  --------------------------------------------------------------------
  --  name:            handle_file
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --------------------------------------------------------------------
  PROCEDURE handle_file(errmsg          OUT VARCHAR2,
		errcode         OUT NUMBER,
		p_file_arc_path VARCHAR2,
		p_document_id   NUMBER) IS
  
    l_err_code   NUMBER;
    l_err_msg    VARCHAR2(250);
    l_flag       NUMBER := 0;
    l_ref_doc_id NUMBER;
    l_file_id    NUMBER;
    CURSOR c IS
      SELECT *
      FROM   xxobjt_fnd_file_documents_v t
      WHERE  t.document_id = p_document_id;
  
    my_exception EXCEPTION;
  BEGIN
    errmsg  := '';
    errcode := 0;
  
    FOR i IN c LOOP
      l_file_id := i.file_id;
      l_flag    := 1;
    
      -- create attachments
      create_short_text_att(l_err_code,
		    l_err_msg,
		    l_ref_doc_id,
		    i.category_id,
		    i.entity_name,
		    i.file_name,
		    i.title,
		    i.description,
		    NULL, --p_short_text
		    get_short_message_name(i.entity_name), --i.short_text_message_name
		    i.pk1_value,
		    i.pk2_value,
		    i.pk3_value);
      IF l_err_code != 0 THEN
        errmsg := l_err_msg;
        RAISE my_exception;
      
      END IF;
      -- insert row to objet archive
      INSERT INTO xxobjt_attachments_archive
        (file_id,
         category_id,
         entity_name,
         arc_path,
         pk1,
         pk2,
         pk3,
         title,
         description,
         seq,
         file_content_type,
         file_name,
         arc_file_name,
         creation_date,
         created_by,
         last_update_date,
         last_updated_by,
         last_update_login,
         o_creation_date,
         o_created_by,
         o_last_update_date,
         o_last_updated_by,
         o_last_update_login,
         ref_doc_id,
         file_format,
         oracle_charset,
         security_type,
         security_id,
         publish_flag,
         program_name,
         conc_request_id)
      VALUES
        (i.file_id,
         i.category_id,
         i.entity_name,
         p_file_arc_path,
         i.pk1_value,
         i.pk2_value,
         i.pk3_value,
         i.title,
         i.description,
         i.seq_num,
         i.file_content_type,
         i.file_name,
         i.arc_file_name,
         SYSDATE,
         fnd_global.user_id,
         SYSDATE,
         fnd_global.user_id,
         fnd_global.login_id,
         i.creation_date,
         i.created_by,
         i.last_update_date,
         i.last_updated_by,
         i.last_update_login,
         l_ref_doc_id,
         i.file_format,
         i.oracle_charset,
         i.security_type,
         i.security_id,
         i.publish_flag,
         i.program_name,
         fnd_global.conc_request_id);
    
      -- delete file
      fnd_attached_documents3_pkg.delete_row(x_attached_document_id => i.attached_document_id,
			         x_datatype_id          => 6, -- file
			         delete_document_flag   => 'Y');
    
      COMMIT;
    END LOOP;
  
    DELETE FROM fnd_lobs l
    WHERE  l.file_id = l_file_id;
  
    COMMIT;
  
    IF l_flag = 1 THEN
      errmsg := 'Documnet moved to Archive';
    ELSE
      errcode := 1;
      errmsg  := 'Attachmet not found , document_id=' || p_document_id;
    END IF;
  
  EXCEPTION
  
    WHEN OTHERS THEN
      ROLLBACK;
      errmsg  := 'Error in xxobjt_fnd_attachments.handle_file: document_id=' ||
	     p_document_id || ' ' || errmsg || ' ' || SQLERRM;
      errcode := 1;
  END handle_file;

  --------------------------------------------------------------------
  --  name:            reverse_archive
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :        called by java cuncurrent named:
  --                   do
  --                   upload  archive file into original apps attachments system
  --                   remove archive info
  --                   delete file from archive
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --------------------------------------------------------------------
  PROCEDURE reverse_archive(p_errmsg    OUT VARCHAR2,
		    p_errcode   OUT NUMBER,
		    p_file_id   NUMBER,
		    p_blob_data BLOB) IS
    CURSOR c IS
      SELECT *
      FROM   xxobjt_attachments_archive t
      WHERE  t.file_id = p_file_id;
    l_media_id NUMBER;
  BEGIN
    -- p_errcode := dbms_lob.getlength(p_blob_data);
    -- RETURN;
    FOR i IN c LOOP
      create_attachments_file(errmsg              => p_errmsg,
		      errcode             => p_errcode,
		      p_oracle_directory  => NULL,
		      p_entity_name       => i.entity_name,
		      p_pk1               => i.pk1,
		      p_pk2               => i.pk2,
		      p_pk3               => i.pk3,
		      p_pk4               => NULL,
		      p_pk5               => NULL,
		      p_category_id       => i.category_id,
		      p_file_name         => i.file_name,
		      p_file_content_type => i.file_content_type,
		      p_security_type     => i.security_type,
		      p_security_id       => i.security_id,
		      p_publish_flag      => i.publish_flag,
		      p_description       => i.description,
		      p_title             => i.title,
		      p_user_id           => i.o_created_by,
		      p_creation_date     => i.o_creation_date,
		      p_last_update_date  => i.o_last_update_date,
		      p_last_update_by    => i.o_last_updated_by,
		      p_oracle_charset    => i.oracle_charset,
		      p_file_format       => i.file_format,
		      p_program_name      => i.program_name,
		      p_blob              => p_blob_data,
		      x_media_id          => l_media_id);
    
      IF p_errcode = 1 THEN
        EXIT;
      END IF;
    
      -- Delete the reference
      DELETE FROM fnd_attached_documents x
      WHERE  x.document_id = i.ref_doc_id;
    
      -- Delete the document
      fnd_documents_pkg.delete_row(i.ref_doc_id, 1, 'N');
    
    END LOOP;
  
    DELETE FROM xxobjt_attachments_archive t
    WHERE  t.file_id = p_file_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_errmsg  := SQLERRM;
      p_errcode := 1;
    
  END reverse_archive;

  --------------------------------------------------------------------
  --  name:            check_session
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --------------------------------------------------------------------
  PROCEDURE check_session(errmsg          OUT VARCHAR2,
		  errcode         OUT NUMBER,
		  p_arc_full_path OUT VARCHAR2,
		  p_file_name     OUT VARCHAR2,
		  p_content_type  OUT VARCHAR2,
		  p_session_id    NUMBER,
		  p_file_id       NUMBER) IS
    CURSOR c IS
      SELECT a.arc_path || '/' || a.arc_file_name,
	 a.file_name,
	 a.file_content_type
      FROM   xxobjt_attachments_archive_v a
      WHERE  a.file_id = p_file_id;
  
  BEGIN
  
    OPEN c;
    FETCH c
      INTO p_arc_full_path,
           p_file_name,
           p_content_type;
    CLOSE c;
  
    IF p_arc_full_path IS NOT NULL THEN
      errmsg  := 'Session is valid';
      errcode := 0;
    ELSE
      errcode := 1;
      errmsg  := 'Session is not valid';
    
    END IF;
  
  EXCEPTION
  
    WHEN OTHERS THEN
      errmsg  := 'Error in xxobjt_fnd_attachments.check_session: ' || ' ' ||
	     SQLERRM;
      errcode := 1;
  END check_session;

  --------------------------------------------------------------------
  --  name:            insert_session
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --------------------------------------------------------------------
  PROCEDURE insert_session(errmsg        OUT VARCHAR2,
		   errcode       OUT NUMBER,
		   p_session_id  NUMBER,
		   p_entity_name VARCHAR2,
		   p_pk1         VARCHAR2,
		   p_pk2         VARCHAR2,
		   p_pk3         VARCHAR2) IS
  BEGIN
  
    errmsg  := '';
    errcode := 0;
    dbms_output.put_line('p_session_id - ' || p_session_id);
    dbms_output.put_line('p_entity_name - ' || p_entity_name);
    dbms_output.put_line('p_pk1 - ' || p_pk1);
    dbms_output.put_line('p_pk2 - ' || p_pk2);
    dbms_output.put_line('p_pk3 - ' || p_pk3);
  
  EXCEPTION
  
    WHEN OTHERS THEN
      errmsg  := 'Error in xxobjt_fnd_attachments.insert_session: =' || ' ' ||
	     SQLERRM;
      errcode := 1;
  END insert_session;

  --------------------------------------------------------------------
  --  name:            create_attachments_file
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --------------------------------------------------------------------
  PROCEDURE create_attachments_file(errmsg              OUT VARCHAR2,
			errcode             OUT NUMBER,
			p_oracle_directory  VARCHAR2,
			p_entity_name       IN VARCHAR2,
			p_pk1               IN VARCHAR2,
			p_pk2               IN VARCHAR2,
			p_pk3               IN VARCHAR2,
			p_pk4               IN VARCHAR2,
			p_pk5               IN VARCHAR2,
			p_category_id       IN NUMBER,
			p_file_name         IN VARCHAR2,
			p_file_content_type VARCHAR2,
			p_security_type     NUMBER DEFAULT NULL,
			p_security_id       NUMBER DEFAULT NULL,
			p_publish_flag      VARCHAR2 DEFAULT NULL,
			p_description       VARCHAR2 DEFAULT NULL,
			p_title             VARCHAR2 DEFAULT NULL,
			p_user_id           NUMBER DEFAULT NULL,
			p_creation_date     DATE DEFAULT NULL,
			p_last_update_date  DATE DEFAULT NULL,
			p_last_update_by    NUMBER DEFAULT NULL,
			p_oracle_charset    VARCHAR2 DEFAULT NULL,
			p_file_format       VARCHAR2 DEFAULT NULL,
			p_program_name      VARCHAR2 DEFAULT NULL,
			p_blob              BLOB DEFAULT NULL,
			x_media_id          IN OUT NUMBER) IS
  
    l_row_id_tmp  VARCHAR2(100);
    l_document_id NUMBER;
  
    l_media_id  NUMBER;
    l_blob_data BLOB;
  
    l_seq_num NUMBER;
  
    l_file_name VARCHAR2(150);
  
  BEGIN
    errcode    := 0;
    l_media_id := x_media_id;
    SAVEPOINT a;
    /* fnd_file.put_line(fnd_file.log, 'P_ENTITY_NAME:' || p_entity_name);
    fnd_file.put_line(fnd_file.log, 'P_PK1:' || to_char(p_pk1));
    
    fnd_file.put_line(fnd_file.log, 'P_DOC_CATEG:' || p_category_id);
    fnd_file.put_line(fnd_file.log, 'P_FILE_NAME:' || p_file_name);*/
  
    l_blob_data := empty_blob();
  
    l_file_name := p_file_name;
    IF p_blob IS NULL AND p_oracle_directory IS NULL THEN
      errcode := 1;
      errmsg  := 'Error in : xxobjt_fnd_attachments.create_file_attachments : p_blob and p_oracle_directory are null';
      fnd_file.put_line(fnd_file.log, errmsg);
      RETURN;
    END IF;
  
    IF p_blob IS NULL AND x_media_id IS NULL THEN
      -- fnd_file.put_line(fnd_file.log, 'p_blob is null');
      xxcs_attach_doc_pkg.load_file_to_db(l_file_name,
			      l_blob_data,
			      p_oracle_directory);
    
    ELSE
      l_blob_data := p_blob;
    END IF;
  
    -- fnd_file.put_line(fnd_file.log, 'After blob loading');
    fnd_documents_pkg.insert_row(x_rowid                  => l_row_id_tmp,
		         x_document_id            => l_document_id,
		         x_creation_date          => nvl(p_creation_date,
					     SYSDATE),
		         x_created_by             => nvl(p_user_id,
					     fnd_global.user_id),
		         x_last_update_date       => nvl(p_last_update_date,
					     SYSDATE),
		         x_last_updated_by        => nvl(p_last_update_by,
					     fnd_global.user_id),
		         x_last_update_login      => fnd_global.login_id, --,
		         x_datatype_id            => 6, --X_datatype_id
		         x_category_id            => p_category_id,
		         x_security_type          => nvl(p_security_type,
					     1),
		         x_security_id            => nvl(p_security_id,
					     NULL),
		         x_publish_flag           => nvl(p_publish_flag,
					     'Y'),
		         x_image_type             => NULL,
		         x_storage_type           => NULL,
		         x_usage_type             => 'O',
		         x_start_date_active      => SYSDATE,
		         x_end_date_active        => NULL,
		         x_request_id             => fnd_global.conc_request_id, --X_request_id, --null
		         x_program_application_id => fnd_global.conc_program_id, --X_program_id,--null
		         x_language               => NULL, --language,
		         x_description            => p_description,
		         x_file_name              => p_file_name,
		         x_media_id               => x_media_id,
		         x_title                  => p_title);
  
    SELECT MAX(seq_num)
    INTO   l_seq_num
    FROM   fnd_attached_documents ad
    WHERE  ad.entity_name = p_entity_name --l_entity_name
    AND    pk1_value = p_pk1
    AND    nvl(pk2_value, '-1') = nvl(p_pk2, '-1')
    AND    nvl(pk3_value, '-1') = nvl(p_pk3, '-1');
  
    -- fnd_file.put_line(fnd_file.log, 'After Select MAX');
    IF l_media_id IS NULL THEN
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
        (x_media_id,
         l_file_name, --l_full_file_name,--
         p_file_content_type, -- 'application/pdf', --   'Tau/PoDoc/pdf',
         SYSDATE,
         NULL,
         NULL,
         NULL,
         l_blob_data,
         NULL,
         p_oracle_charset,
         nvl(p_file_format, 'binary'));
    END IF;
  
    -- fnd_file.put_line(fnd_file.log, 'After Insert into fnd_lobs');
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
       nvl(p_creation_date, SYSDATE),
       nvl(p_user_id, fnd_global.user_id), --NVL(X_created_by,0),
       nvl(p_last_update_date, NULL),
       p_last_update_by, --NVL(X_created_by,0),
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
       p_category_id);
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO a;
    
      fnd_file.put_line(fnd_file.log,
		'Error in : xxobjt_fnd_attachments.create_file_attachments ' ||
		SQLERRM);
      errmsg  := 'Error in : xxobjt_fnd_attachments.create_file_attachments ' ||
	     SQLERRM;
      errcode := 1;
    
  END create_attachments_file;

  --------------------------------------------------------------------
  --  name:            load_file_to_blob
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2012
  --------------------------------------------------------------------
  --  purpose:         General procedure that get file name and directory
  --                   and return file into BLOB variable.
  --  In  Params:      p_file_name
  --                   p_directory
  --  Out Params:      p_blob
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE load_file_to_blob(p_file_name IN VARCHAR2,
		      p_directory IN VARCHAR2,
		      p_blob      OUT BLOB) IS
  
    f_lob              BFILE;
    b_lob              BLOB := empty_blob();
    destination_offset INTEGER := 1;
    source_offset      INTEGER := 1;
  
  BEGIN
    --dbms_output.put_line('load_file_to_db :oracle_directory = ' || p_directory);
  
    dbms_lob.createtemporary(b_lob, TRUE, dbms_lob.session);
  
    f_lob := bfilename(p_directory, p_file_name);
    dbms_lob.fileopen(f_lob, dbms_lob.file_readonly);
    --fnd_file.put_line(fnd_file.log, 'After fileopen');
  
    dbms_lob.loadblobfromfile(b_lob,
		      f_lob,
		      dbms_lob.getlength(f_lob),
		      destination_offset,
		      source_offset);
  
    --fnd_file.put_line(fnd_file.log, 'After loadblobfromfile');
    --dbms_lob.freetemporary(b_lob);
    dbms_lob.fileclose(f_lob);
    p_blob := b_lob;
  
  END load_file_to_blob;

  --------------------------------------------------------------------
  --  name:            get_environment_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/06/2012
  --------------------------------------------------------------------
  --  purpose:         function that return the environment name
  --                   PROD,TEST,DEV,YES,PATCH etc.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_environment_name RETURN VARCHAR2 IS
    l_database VARCHAR2(15) := NULL;
  BEGIN
    SELECT NAME --decode(name, 'PROD', 'production', 'default')
    INTO   l_database
    FROM   v$database;
  
    RETURN l_database;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_environment_name;

  --------------------------------------------------------------------
  --  name:            get_directory_path
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/06/2012
  --------------------------------------------------------------------
  --  purpose:         function that set directory path
  --                   according to the environment program run.
  --                   (PROD,TEST,DEV,YES,PATCH etc.)
  --
  --                   This is teh comand to create Directory
  --                   create or replace directory XXOBJT_SHARED_FILES_PROD
  --                   as '/UtlFiles/shared/PROD';
  --
  --  In Param:        p_name - the name of the Directory i want to change the path
  --                   p_dir  - the new path for the Directory.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_oracle_dir(p_name VARCHAR2,
		      p_dir  VARCHAR2) IS
  
  BEGIN
  
    EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY ' || p_name || ' AS ''' ||
	          p_dir || '''';
  
  END create_oracle_dir;

  --------------------------------------------------------------------
  --  name:            set_shared_directory
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/06/2012
  --------------------------------------------------------------------
  --  purpose:         1) Get environment program run at
  --                   2) Get the directory Path according to environment
  --                   3) Exceute immediate change dirctory path to the correct environment
  --
  --  In Param:        p_name - the name of the Directory i want to change the path
  --                   p_sub_dir  - the new path for the Directory.
  --                                'HR/xx',  'CS/coupons' !!!! MUST KEEP THIS SAMPLE !!!!
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE set_shared_directory(p_name    VARCHAR2,
		         p_sub_dir VARCHAR2) IS
  
    --l_directory  varchar2(150);
    l_env      VARCHAR2(20);
    l_dir_path VARCHAR2(150);
  BEGIN
  
    -- Get environment program run at
    l_env := xxobjt_fnd_attachments.get_environment_name;
  
    -- Get the directory Path according to environment
    l_dir_path := '/UtlFiles/shared/' || l_env || '/';
  
    -- exceute immediate change dirctory path to the correct environment
    xxobjt_fnd_attachments.create_oracle_dir(p_name,
			         l_dir_path || p_sub_dir);
  
  END set_shared_directory;

  --------------------------------------------------------------------
  --  name:               download_attachment
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      28/05/2014
  --  Description:        download blob into a directory specified
  --                      utl_file.fopen parameters
  --                      location     -               Directory location of file - This string is a directory object name.
  --                                                   Read privileges must be granted on this directory object for the UTL_FILE user to run FOPEN.
  --                      filename     -               File name, including extension (file type), without directory path.
  --                      open_mode    -               Specifies how the file is opened. Modes include:
  --                                                   r  -> read text
  --                                                   w  -> write text
  --                                                   a  -> append text
  --                                                   rb -> read byte mode
  --                                                   wb -> write byte mode
  --                                                   ab -> append byte mode
  --                                                   If you try to open a file specifying 'a' or 'ab' for open_mode but the file does not exist,
  --                                                   the file is created in write mode.
  --                      max_linesize -               Maximum number of characters for each line, including the newline character,
  --                                                   for this file (minimum value 1, maximum value 32767). If unspecified default value of 1024.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/05/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE download_attachment(errbuf      OUT VARCHAR2,
		        retcode     OUT VARCHAR2,
		        p_blob      IN BLOB,
		        p_filename  IN VARCHAR2,
		        p_directory IN VARCHAR2) IS
  
    l_file     utl_file.file_type;
    l_buffer   RAW(32767);
    l_amount   BINARY_INTEGER := 32767;
    l_pos      NUMBER := 1;
    l_blob_len INTEGER;
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    l_blob_len := dbms_lob.getlength(p_blob);
  
    -- Open the file.in Directory that is already created.(p_directory)
    l_file := utl_file.fopen(p_directory, p_filename, 'WB', 32767);
  
    -- File will be created with the name stored as in LOB_NAME column
    -- Read chunks of the BLOB and write them to the file created in directory until complete.
    WHILE l_pos < l_blob_len LOOP
      dbms_lob.read(p_blob, l_amount, l_pos, l_buffer);
      utl_file.put_raw(l_file, l_buffer, TRUE);
      l_pos := l_pos + l_amount;
    END LOOP; -- This will end the While loop when condition met.
  
    -- Close the file.
    utl_file.fclose(l_file);
  
  EXCEPTION
    WHEN OTHERS THEN
      -- close the file if something goes wrong.
      IF utl_file.is_open(l_file) THEN
        utl_file.fclose(l_file);
      END IF;
    
      errbuf  := substr(SQLERRM, 1, 240);
      retcode := 1;
  END download_attachment;

  --------------------------------------------------------------------
  --  name:               Handle_IB_attachments
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      28/05/2014
  --  Description:        download IB attachments files to a local folder
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/05/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_ib_attachments(errbuf  OUT VARCHAR2,
		          retcode OUT VARCHAR2) IS
    CURSOR ib_c IS
    --Install base attachments
      SELECT t.pk1_value parent_id, --  install_base_oe_id,
	 CASE
	   WHEN instr(fo.file_name, '.') = 0 THEN
	    fo.file_name || '.pdf'
	   ELSE
	    fo.file_name
	 END file_name,
	 CASE
	   WHEN instr(fo.file_name, '.') = 0 THEN
	    to_char(t.attached_document_id)
	   ELSE
	    to_char(t.attached_document_id) ||
	    substr(fo.file_name, instr(fo.file_name, '.', -1))
	 END new_name, -- this is the FileName to use (because the users saved attachments with the same name for diff IB
	 CASE
	   WHEN instr(fo.file_name, '.') > 0 THEN
	    substr(fo.file_name, instr(fo.file_name, '.', -1))
	   ELSE
	    '.pdf'
	 END contenttype,
	 NULL ownerid,
	 'C:\Maayan\IB\' || CASE
	   WHEN instr(fo.file_name, '.') = 0 THEN
	    to_char(t.attached_document_id) || '.pdf'
	   ELSE
	    to_char(t.attached_document_id) ||
	    substr(fo.file_name, instr(fo.file_name, '.', -1))
	 END new_body, -- body_c
	 t.attached_document_id attachment_oe_id,
	 fl.file_data,
	 fl.file_id
      FROM   fnd_attached_documents t,
	 fnd_documents          fo,
	 fnd_lobs               fl
      WHERE  fo.document_id = t.document_id
      AND    t.entity_name = 'XX_ITEM_INSTANCE'
      AND    fo.media_id = fl.file_id;
    --and    rownum < 100;
  
    l_prod           VARCHAR2(10);
    l_file1          utl_file.file_type;
    l_directory_name VARCHAR2(100) := 'XXEXPORT_ATTACHMENTS1'; --'XXIB_ATTACHMENTS';
    l_error_msg      VARCHAR2(1000);
    l_error_code     VARCHAR2(100);
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    l_prod := xxobjt_general_utils_pkg.am_i_in_production;
  
    IF l_prod = 'N' THEN
      xxobjt_fnd_attachments.create_oracle_dir(p_name => l_directory_name, -- 'XXIB_ATTACHMENTS'
			           p_dir  => '/oracle/exportfs/DEV/IB'); --'/UtlFiles/shared/DEV/CS/IB'); -- directory path
    END IF;
  
    l_file1 := utl_file.fopen(l_directory_name,
		      'IB_Summary.csv',
		      'w',
		      32767);
  
    utl_file.put_line(file   => l_file1,
	          buffer => '"PARENT_ID","FILE_NAME","CONTENTTYPE","OWNERID","NEW_BODY","ATTACHMENT_OE_ID","REMARKS"');
  
    FOR ib_r IN ib_c LOOP
    
      download_attachment(errbuf      => l_error_msg, -- o v
		  retcode     => l_error_code, -- o v
		  p_blob      => ib_r.file_data, -- i blob
		  p_filename  => ib_r.new_name, -- i v
		  p_directory => l_directory_name); -- i v
    
      BEGIN
        utl_file.put_line(file   => l_file1,
		  buffer => '"' || ib_r.parent_id || '","' ||
			ib_r.file_name || '","' ||
			ib_r.contenttype || '","' ||
			ib_r.ownerid || '","' || ib_r.new_body ||
			'","' || ib_r.attachment_oe_id || '","' ||
			l_error_msg || '"');
      EXCEPTION
        WHEN utl_file.invalid_mode THEN
          fnd_file.put_line(fnd_file.log,
		    'The open_mode parameter in FOPEN is invalid');
          dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_path THEN
          fnd_file.put_line(fnd_file.log,
		    'Specified path does not exist or is not visible to Oracle');
          dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_filehandle THEN
          fnd_file.put_line(fnd_file.log, 'File handle does not exist');
          dbms_output.put_line('File handle does not exist');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.internal_error THEN
          fnd_file.put_line(fnd_file.log,
		    'Unhandled internal error in the UTL_FILE package');
          dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.file_open THEN
          fnd_file.put_line(fnd_file.log, 'File is already open');
          dbms_output.put_line('File is already open');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_maxlinesize THEN
          fnd_file.put_line(fnd_file.log,
		    'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
          dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_operation THEN
          fnd_file.put_line(fnd_file.log,
		    'File could not be opened or operated on as requested');
          dbms_output.put_line('File could not be opened or operated on as requested');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.write_error THEN
          fnd_file.put_line(fnd_file.log, 'Unable to write to file');
          dbms_output.put_line('Unable to write to file');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.access_denied THEN
          fnd_file.put_line(fnd_file.log,
		    'Access to the file has been denied by the operating system');
          dbms_output.put_line('Access to the file has been denied by the operating system');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log, 'Unknown UTL_FILE Error');
          dbms_output.put_line('Unknown UTL_FILE Error - ' || SQLERRM);
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
      END;
    
    END LOOP;
    utl_file.fclose(file => l_file1);
  
  EXCEPTION
    WHEN OTHERS THEN
      IF utl_file.is_open(l_file1) THEN
        utl_file.fclose(l_file1);
      END IF;
      errbuf  := 2;
      retcode := 'Procedure Handle_IB_attachments failed' ||
	     substr(SQLERRM, 1, 240);
      fnd_file.put_line(fnd_file.log,
		'Procedure Handle_IB_attachments failed - ' ||
		SQLERRM);
      dbms_output.put_line('Procedure Handle_IB_attachments failed - ' ||
		   substr(SQLERRM, 1, 240));
  END handle_ib_attachments;

  --------------------------------------------------------------------
  --  name:               Handle_SR_attachments
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      28/05/2014
  --  Description:        download SR attachments files to a local folder
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/05/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_sr_attachments(errbuf  OUT VARCHAR2,
		          retcode OUT VARCHAR2) IS
    CURSOR sr_c IS
    -- Service Request Attachments
      SELECT adf.pk1_value parent_id, -- SR_incident_id,  -- 18707
	 CASE
	   WHEN instr(adf.file_name, '.') = 0 THEN
	    adf.file_name || '.pdf'
	   ELSE
	    adf.file_name
	 END file_name,
	 CASE
	   WHEN instr(adf.file_name, '.') = 0 THEN
	    to_char(adf.attached_document_id)
	   ELSE
	    to_char(adf.attached_document_id) ||
	    substr(adf.file_name, instr(adf.file_name, '.', -1))
	 END new_name, -- this is the FileName to use (because the users saved attachments with the same name for diff IB
	 CASE
	   WHEN instr(adf.file_name, '.') > 0 THEN
	    substr(adf.file_name, instr(adf.file_name, '.', -1))
	   ELSE
	    '.pdf'
	 END contenttype,
	 NULL ownerid,
	 'C:\Maayan\SR\' || CASE
	   WHEN instr(adf.file_name, '.') = 0 THEN
	    to_char(adf.attached_document_id) || '.pdf'
	   ELSE
	    to_char(adf.attached_document_id) ||
	    substr(adf.file_name, instr(adf.file_name, '.', -1))
	 END new_body, -- body_c
	 adf.attached_document_id attachment_oe_id,
	 fl.file_data,
	 fl.file_id
      FROM   fnd_attached_docs_form_vl adf,
	 fnd_lobs                  fl
      WHERE  adf.entity_name = 'CS_INCIDENTS'
      AND    adf.function_name = 'CSXSRISR'
      AND    adf.datatype_name = 'File'
      AND    adf.file_name IS NOT NULL
      AND    adf.media_id = fl.file_id;
    --and    rownum < 100;
  
    l_prod           VARCHAR2(10);
    l_file1          utl_file.file_type;
    l_directory_name VARCHAR2(100) := 'XXEXPORT_ATTACHMENTS2'; --'XXSR_ATTACHMENTS';
    l_error_msg      VARCHAR2(1000);
    l_error_code     VARCHAR2(100);
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    l_prod := xxobjt_general_utils_pkg.am_i_in_production;
  
    IF l_prod = 'N' THEN
      xxobjt_fnd_attachments.create_oracle_dir(p_name => l_directory_name, --'XXSR_ATTACHMENTS',
			           p_dir  => '/oracle/exportfs/DEV/SR'); --'/UtlFiles/shared/DEV/CS/SR'); -- directory path
    END IF;
  
    l_file1 := utl_file.fopen(l_directory_name,
		      'SR_Summary.csv',
		      'w',
		      32767);
  
    utl_file.put_line(file   => l_file1,
	          buffer => '"PARENT_ID","FILE_NAME","CONTENTTYPE","OWNERID","NEW_BODY","ATTACHMENT_OE_ID","REMARKS"');
  
    FOR sr_r IN sr_c LOOP
    
      download_attachment(errbuf      => l_error_msg, -- o v
		  retcode     => l_error_code, -- o v
		  p_blob      => sr_r.file_data, -- i blob
		  p_filename  => sr_r.new_name, -- i v
		  p_directory => l_directory_name); -- i v
    
      BEGIN
        utl_file.put_line(file   => l_file1,
		  buffer => '"' || sr_r.parent_id || '","' ||
			sr_r.file_name || '","' ||
			sr_r.contenttype || '","' ||
			sr_r.ownerid || '","' || sr_r.new_body ||
			'","' || sr_r.attachment_oe_id || '","' ||
			l_error_msg || '"');
      EXCEPTION
        WHEN utl_file.invalid_mode THEN
          fnd_file.put_line(fnd_file.log,
		    'The open_mode parameter in FOPEN is invalid');
          dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_path THEN
          fnd_file.put_line(fnd_file.log,
		    'Specified path does not exist or is not visible to Oracle');
          dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_filehandle THEN
          fnd_file.put_line(fnd_file.log, 'File handle does not exist');
          dbms_output.put_line('File handle does not exist');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.internal_error THEN
          fnd_file.put_line(fnd_file.log,
		    'Unhandled internal error in the UTL_FILE package');
          dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.file_open THEN
          fnd_file.put_line(fnd_file.log, 'File is already open');
          dbms_output.put_line('File is already open');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_maxlinesize THEN
          fnd_file.put_line(fnd_file.log,
		    'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
          dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_operation THEN
          fnd_file.put_line(fnd_file.log,
		    'File could not be opened or operated on as requested');
          dbms_output.put_line('File could not be opened or operated on as requested');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.write_error THEN
          fnd_file.put_line(fnd_file.log, 'Unable to write to file');
          dbms_output.put_line('Unable to write to file');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.access_denied THEN
          fnd_file.put_line(fnd_file.log,
		    'Access to the file has been denied by the operating system');
          dbms_output.put_line('Access to the file has been denied by the operating system');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log, 'Unknown UTL_FILE Error');
          dbms_output.put_line('Unknown UTL_FILE Error - ' || SQLERRM);
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
      END;
    
    END LOOP;
    utl_file.fclose(file => l_file1);
  
  EXCEPTION
    WHEN OTHERS THEN
      IF utl_file.is_open(l_file1) THEN
        utl_file.fclose(l_file1);
      END IF;
      errbuf  := 2;
      retcode := 'Procedure Handle_SR_attachments failed' ||
	     substr(SQLERRM, 1, 240);
      fnd_file.put_line(fnd_file.log,
		'Procedure Handle_SR_attachments failed - ' ||
		SQLERRM);
      dbms_output.put_line('Procedure Handle_SR_attachments failed - ' ||
		   substr(SQLERRM, 1, 240));
  END handle_sr_attachments;

  --------------------------------------------------------------------
  --  name:               Handle_OKS_attachments
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      28/05/2014
  --  Description:        download OKS attachments files to a local folder
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/05/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_oks_attachments(errbuf  OUT VARCHAR2,
		           retcode OUT VARCHAR2) IS
    CURSOR oks_c IS
    -- Contracts Attachments
      SELECT adf.pk1_value parent_id, -- contract_header_id,  -- 18707
	 CASE
	   WHEN instr(adf.file_name, '.') = 0 THEN
	    adf.file_name || '.pdf'
	   ELSE
	    adf.file_name
	 END file_name,
	 CASE
	   WHEN instr(adf.file_name, '.') = 0 THEN
	    to_char(adf.attached_document_id)
	   ELSE
	    to_char(adf.attached_document_id) ||
	    substr(adf.file_name, instr(adf.file_name, '.', -1))
	 END new_name, -- this is the FileName to use (because the users saved attachments with the same name for diff IB
	 CASE
	   WHEN instr(adf.file_name, '.') > 0 THEN
	    substr(adf.file_name, instr(adf.file_name, '.', -1))
	   ELSE
	    '.pdf'
	 END contenttype,
	 NULL ownerid,
	 'C:\Maayan\OKS\' || CASE
	   WHEN instr(adf.file_name, '.') = 0 THEN
	    to_char(adf.attached_document_id) || '.pdf'
	   ELSE
	    to_char(adf.attached_document_id) ||
	    substr(adf.file_name, instr(adf.file_name, '.', -1))
	 END new_body, -- body_c
	 adf.attached_document_id attachment_oe_id,
	 fl.file_data,
	 fl.file_id
      FROM   fnd_attached_docs_form_vl adf,
	 fnd_lobs                  fl
      WHERE  adf.entity_name = 'OKC_K_HEADERS_V'
      AND    adf.function_name = 'OKSAUDET'
      AND    adf.datatype_name = 'File'
      AND    adf.file_name IS NOT NULL
      AND    adf.media_id = fl.file_id;
    --and    rownum < 100;
  
    l_prod           VARCHAR2(10);
    l_file1          utl_file.file_type;
    l_directory_name VARCHAR2(100) := 'XXEXPORT_ATTACHMENTS3'; --'XXSR_ATTACHMENTS';
    l_error_msg      VARCHAR2(1000);
    l_error_code     VARCHAR2(100);
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    l_prod := xxobjt_general_utils_pkg.am_i_in_production;
  
    IF l_prod = 'N' THEN
      xxobjt_fnd_attachments.create_oracle_dir(p_name => l_directory_name, --'XXSR_ATTACHMENTS',
			           p_dir  => '/oracle/exportfs/DEV/OKS'); --'/UtlFiles/shared/DEV/CS/OKS'); -- directory path
    END IF;
  
    l_file1 := utl_file.fopen(l_directory_name,
		      'OKS_Summary.csv',
		      'w',
		      32767);
  
    utl_file.put_line(file   => l_file1,
	          buffer => '"PARENT_ID","FILE_NAME","CONTENTTYPE","OWNERID","NEW_BODY","ATTACHMENT_OE_ID","REMARKS"');
  
    FOR oks_r IN oks_c LOOP
    
      download_attachment(errbuf      => l_error_msg, -- o v
		  retcode     => l_error_code, -- o v
		  p_blob      => oks_r.file_data, -- i blob
		  p_filename  => oks_r.new_name, -- i v
		  p_directory => l_directory_name); -- i v
    
      BEGIN
        utl_file.put_line(file   => l_file1,
		  buffer => '"' || oks_r.parent_id || '","' ||
			oks_r.file_name || '","' ||
			oks_r.contenttype || '","' ||
			oks_r.ownerid || '","' || oks_r.new_body ||
			'","' || oks_r.attachment_oe_id || '","' ||
			l_error_msg || '"');
      EXCEPTION
        WHEN utl_file.invalid_mode THEN
          fnd_file.put_line(fnd_file.log,
		    'The open_mode parameter in FOPEN is invalid');
          dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_path THEN
          fnd_file.put_line(fnd_file.log,
		    'Specified path does not exist or is not visible to Oracle');
          dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_filehandle THEN
          fnd_file.put_line(fnd_file.log, 'File handle does not exist');
          dbms_output.put_line('File handle does not exist');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.internal_error THEN
          fnd_file.put_line(fnd_file.log,
		    'Unhandled internal error in the UTL_FILE package');
          dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.file_open THEN
          fnd_file.put_line(fnd_file.log, 'File is already open');
          dbms_output.put_line('File is already open');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_maxlinesize THEN
          fnd_file.put_line(fnd_file.log,
		    'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
          dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_operation THEN
          fnd_file.put_line(fnd_file.log,
		    'File could not be opened or operated on as requested');
          dbms_output.put_line('File could not be opened or operated on as requested');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.write_error THEN
          fnd_file.put_line(fnd_file.log, 'Unable to write to file');
          dbms_output.put_line('Unable to write to file');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.access_denied THEN
          fnd_file.put_line(fnd_file.log,
		    'Access to the file has been denied by the operating system');
          dbms_output.put_line('Access to the file has been denied by the operating system');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log, 'Unknown UTL_FILE Error');
          dbms_output.put_line('Unknown UTL_FILE Error - ' || SQLERRM);
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
      END;
    
    END LOOP;
    utl_file.fclose(file => l_file1);
  
  EXCEPTION
    WHEN OTHERS THEN
      IF utl_file.is_open(l_file1) THEN
        utl_file.fclose(l_file1);
      END IF;
      errbuf  := 2;
      retcode := 'Procedure Handle_OKS_attachments failed' ||
	     substr(SQLERRM, 1, 240);
      fnd_file.put_line(fnd_file.log,
		'Procedure Handle_OKS_attachments failed - ' ||
		SQLERRM);
      dbms_output.put_line('Procedure Handle_OKS_attachments failed - ' ||
		   substr(SQLERRM, 1, 240));
  END handle_oks_attachments;

  /*
  ------------------------------------
  -- delete_files
  -------------------------------------
  
  PROCEDURE delete_files(errmsg            OUT VARCHAR2,
                         errcode           OUT NUMBER,
                         p_conc_request_id NUMBER) IS
  
    CURSOR c IS
      SELECT *
        FROM xxobjt_attachments_archive x
       WHERE x.conc_request_id = p_conc_request_id
         FOR UPDATE;
  
  BEGIN
    FOR i IN c LOOP
  
      DELETE FROM fnd_lobs f WHERE f.file_id = i.file_id;
  
      \* UPDATE xxobjt_attachments_archive
        SET del_file_flag = NULL
      WHERE CURRENT OF c;*\
      COMMIT;
  
    END LOOP;
  
  END;*/

  --------------------------------------------------------------------
  --  name:            Get_Short_Text_Attached
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   06/05/2015
  --------------------------------------------------------------------
  --  purpose :       Return concatenated short text attachments by
  --                 a given category name.
  --                 If no category name is given then all the attachments
  --                 will be taken. (Use the english Category User Name)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06.05.2015  Michal Tzvik      CHG0033893 - initial build
  --------------------------------------------------------------------
  FUNCTION get_short_text_attached(p_function_name IN VARCHAR2,
		           p_entity_name   IN VARCHAR2,
		           p_category_name IN VARCHAR2,
		           p_entity_id1    IN VARCHAR2,
		           p_entity_id2    IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_short_text_str VARCHAR2(9000) := '';
  
    CURSOR c_short_text_cursor IS
      SELECT fdst.short_text
      FROM   fnd_attached_docs_form_vl  fadfv,
	 fnd_documents_short_text   fdst,
	 fnd_document_categories_tl fdct
      WHERE  fadfv.function_name = p_function_name
	-- AND    fadfv.function_type = p_function_type
	-- and    fadfv.datatype_name  = 'Short Text'
      AND    EXISTS
       (SELECT 1
	  FROM   fnd_document_datatypes fdt
	  WHERE  fdt.language = 'US'
	  AND    fdt.name = 'SHORT_TEXT'
	  AND    fdt.datatype_id = fadfv.datatype_id)
      AND    fadfv.entity_name = p_entity_name
      AND    fadfv.pk1_value = p_entity_id1
      AND    (fadfv.pk2_value = p_entity_id2 OR p_entity_id2 IS NULL)
      AND    fadfv.media_id = fdst.media_id
      AND    fadfv.category_id = fdct.category_id
      AND    fdct.language = 'US'
      AND    fdct.user_name = nvl(p_category_name, fdct.user_name)
      ORDER  BY fadfv.user_entity_name,
	    fadfv.seq_num;
  BEGIN
    FOR r_short_text_rec IN c_short_text_cursor LOOP
      l_short_text_str := l_short_text_str || r_short_text_rec.short_text ||
		  chr(10);
    END LOOP;
    l_short_text_str := substr(l_short_text_str,
		       1,
		       length(l_short_text_str) - 1);
  
    RETURN l_short_text_str;
  END get_short_text_attached;

END xxobjt_fnd_attachments;
/
