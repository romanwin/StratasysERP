create or replace package body xxfnd_load_attachment_pkg as

  --------------------------------------------------------------------
 
  --  name:          xxfnd_load_attachment_pkg
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 15/03/2015
  --------------------------------------------------------------------
  --  purpose :      CHG0034837: Generic Load FND Attachment procedure
  --------------------------------------------------------------------
  g_language   varchar2(240)     := userenv('LANG');

  --------------------------------------------------------------------
 
  --  name:          get_attached_doc_seq
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 15/03/2015
  --------------------------------------------------------------------
  --  purpose :      CHG0034837: This function returns next value of 
  --                 sequence FND_ATTACHED_DOCUMENTS_S
  --------------------------------------------------------------------
  

  function get_attached_doc_seq return number
  is
    l_attached_document_id number;
  begin
    select FND_ATTACHED_DOCUMENTS_S.nextval
      into l_attached_document_id
      from dual;
      
    return l_attached_document_id; 
  end;
  
  --------------------------------------------------------------------
 
  --  name:          get_doc_category_id
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 15/03/2015
  --------------------------------------------------------------------
  --  purpose :      CHG0034837: This function returns document 
  --                 category ID for a provided document category
  --------------------------------------------------------------------

  
  function get_doc_category_id (p_document_category IN varchar2) return number
  is
    l_category_id number;
  begin
    select category_id
      into l_category_id
      from FND_DOCUMENT_CATEGORIES_TL
     where user_name = p_document_category
       and language = g_language;
     
    return l_category_id;
  end;
  
  --------------------------------------------------------------------
 
  --  name:          get_seq_num_sttach_docs
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 15/03/2015
  --------------------------------------------------------------------
  --  purpose :      CHG0034837: This function returns next line
  --                 sequence number for attached documents
  --------------------------------------------------------------------
  
   
  function get_seq_num_sttach_docs (p_pk_value IN fnd_attached_documents.pk1_value%TYPE,
                                    p_entity_name IN varchar2) return number
  is
    l_seq_num number;
  begin
    select nvl(max(seq_num), 0) + 10
      into l_seq_num
      from fnd_attached_documents
     where pk1_value = p_pk_value and entity_name = p_entity_name;
     
    return l_seq_num;
  end;
  
 --------------------------------------------------------------------
 
  --  name:          get_document_datatype
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 15/03/2015
  --------------------------------------------------------------------
  --  purpose :      CHG0034837: This function returns data type ID 
  --                 for FILE attachments
  --------------------------------------------------------------------
  
  
  function get_document_datatype return number
  is
    l_datatype_id number;
  begin
    SELECT datatype_id
      into l_datatype_id
      FROM FND_DOCUMENT_DATATYPES
     where name = 'FILE'
       and language = g_language;
     
    return l_datatype_id;
  end;
  
  --------------------------------------------------------------------
 
  --  name:          check_filepath
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 15/03/2015
  --------------------------------------------------------------------
  --  purpose :      CHG0034837: This function checks if provided 
  --                 filepath is a valid registered database DIRECTORY
  --------------------------------------------------------------------
  
    function check_filepath (p_filepath IN varchar2) return number
  is
    l_count number;
  begin
    SELECT count(1)
      into l_count
      FROM ALL_DIRECTORIES
     where directory_name = p_filepath;
     
    return l_count;
  end;
  --------------------------------------------------------------------
 
  --  name:          load_file_attachment
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 15/03/2015
  --------------------------------------------------------------------
  --  purpose :      CHG0034837: Generic Load FND Attachment procedure
  --------------------------------------------------------------------
  
  procedure load_file_attachment(
    p_pk_id IN number,
    p_entity_name IN varchar2,
    p_file_type IN varchar2,
    p_document_category IN varchar2,
    p_attachment_desc IN varchar2,
    p_filename IN varchar2,
    p_filepath IN varchar2 default null,
    p_file_blob IN BLOB default null,
    x_status OUT varchar2,
    x_status_message OUT varchar2
  ) as
    l_rowid                rowid;
    l_attached_document_id number;
    l_document_id          number;
    l_media_id             number;
    l_category_id          number;
    l_pk1_value            fnd_attached_documents.pk1_value%TYPE;
    l_description          fnd_documents_tl.description%TYPE;
    l_filename             fnd_documents_tl.file_name%TYPE;
    l_seq_num              number;
    l_DATATYPE_ID          number;
    L_FILE_CONTENT_TYPE    VARCHAR2(100);
    L_FILE_FORMAT          VARCHAR2(100);
    
    v_access_id            NUMBER;
    v_file_id              NUMBER;
    src_lob                BFILE;
    dest_lob               BLOB;

    l_directory_count      number:=0;
    l_status               varchar2(1) := 'S';
    l_status_message       varchar2(2000);
  begin
    l_pk1_value       := p_pk_id;
    l_filename        := p_filename;
    l_description     := p_attachment_desc;
    dest_lob          := p_file_blob;
    l_document_id     := NULL;
    l_media_id        := NULL;
    l_seq_num         := NULL;
    l_status_message  := null;
    l_status          := 'S';
    
    IF l_filename IS NULL
    THEN
      l_status := 'E';
      l_status_message := l_status_message||CHR(13)||'VALIDATION ERROR: File Name to be uploaded must be provided.';  
    END IF;
    
    IF p_file_type IS NULL 
    THEN
      l_status := 'E';
      l_status_message := l_status_message||CHR(13)||'VALIDATION ERROR: File Type must be provided';
    END IF;

    IF p_filepath IS NULL AND p_file_blob IS NULL
    THEN
      l_status := 'E';
      l_status_message := l_status_message||CHR(13)||'VALIDATION ERROR: Either File path in UNIX server (registered DIRECTORY name in database) or file BLOB input must be provided.';
    END IF;
    
    IF p_filepath IS NOT NULL 
    THEN
      BEGIN
        l_directory_count := check_filepath(p_filepath);
        IF l_directory_count = 0
        THEN
          l_status := 'E';
          l_status_message := l_status_message||CHR(13)||'VALIDATION ERROR: The filepath parameter provided: '||p_filepath||' is not a registered directory in this database.';
        END iF;
      EXCEPTION
      WHEN OTHERS THEN
        l_status := 'E';
        l_status_message := l_status_message||CHR(13)||'ERROR: API faced issues while checking valid existence of filepath (DB DIRECTORY): '||p_filepath||'. '||SQLERRM;
      END;
    END IF;
        
    --Fetch Attached Document Id---
    BEGIN
      l_attached_document_id := get_attached_doc_seq;
    EXCEPTION
    WHEN OTHERS THEN
      l_status := 'E';
      l_status_message := l_status_message||CHR(13)||'ERROR: While fetching next document attachment sequence value.'||SQLERRM;
    END;
  
    --Fetch Document category Id---
    BEGIN
      l_category_id := get_doc_category_id(p_document_category); 
    EXCEPTION
    WHEN OTHERS THEN
      l_status := 'E';
      l_status_message := l_status_message||CHR(13)||'ERROR: While fetching document category ID.'||SQLERRM;
    END;
  
    --Fetch Attached Document Sequence Number---
    BEGIN
      l_seq_num := get_seq_num_sttach_docs(l_pk1_value,p_entity_name); 
    EXCEPTION
    WHEN OTHERS THEN
      l_status := 'E';
      l_status_message := l_status_message||CHR(13)||'ERROR: While fetching document line number.'||SQLERRM;
    END;
 
    --Fetch Document Datatype---
    BEGIN
      l_datatype_id := get_document_datatype;
    EXCEPTION
    WHEN OTHERS THEN
      l_status := 'E';
      l_status_message := l_status_message||CHR(13)||'ERROR: While fetching document datatype.'||SQLERRM;
    END;
  
    
    
    IF p_file_type is not null and upper(p_file_type) = 'PDF' THEN
      L_FILE_CONTENT_TYPE := 'application/pdf';
      L_FILE_FORMAT       := 'binary';
    ELSIF p_file_type is not null and upper(p_file_type) = 'TXT' THEN
      L_FILE_CONTENT_TYPE := 'text/plain';
      L_FILE_FORMAT       := 'text';
    ELSIF p_file_type is not null and upper(p_file_type) IN ('JPG','JPEG','PNG','BMP','GIF') THEN
      L_FILE_CONTENT_TYPE := 'image/pjpeg';
      L_FILE_FORMAT       := 'binary';
    ELSIF p_file_type is not null and upper(p_file_type) = 'DOCX' THEN
      L_FILE_CONTENT_TYPE := 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      L_FILE_FORMAT       := 'binary';
    ELSIF p_file_type is not null and upper(p_file_type) = 'DOC' THEN
      L_FILE_CONTENT_TYPE := 'application/msword';
      L_FILE_FORMAT       := 'binary';
    ELSIF p_file_type is not null and upper(p_file_type) = 'XLS' THEN
      L_FILE_CONTENT_TYPE := 'application/vnd.ms-excel';
      L_FILE_FORMAT       := 'binary';
    ELSIF p_file_type is not null and upper(p_file_type) = 'XLSX' THEN
      L_FILE_CONTENT_TYPE := 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      L_FILE_FORMAT       := 'binary';
    ELSIF p_file_type is not null and upper(p_file_type) = 'XPS' THEN
      L_FILE_CONTENT_TYPE := 'application/vnd.ms-xpsdocument';
      L_FILE_FORMAT       := 'binary';
    ELSIF p_file_type is not null THEN
      l_status := 'E';
      l_status_message := l_status_message||CHR(13)||'VALIDATION ERROR: File type is not recognised by this custom program';
    END IF;

    IF l_status <> 'E'
    THEN
      fnd_attached_documents_pkg.insert_row(X_ROWID                    => l_rowid,
                                            X_ATTACHED_DOCUMENT_ID     => l_attached_document_id,
                                            X_DOCUMENT_ID              => l_document_id,
                                            X_CREATION_DATE            => sysdate,
                                            X_CREATED_BY               => nvl(fnd_profile.value('USER_ID'),-1),
                                            X_LAST_UPDATE_DATE         => sysdate,
                                            X_LAST_UPDATED_BY          => nvl(fnd_profile.value('USER_ID'),-1),
                                            X_LAST_UPDATE_LOGIN        => nvl(fnd_profile.value('LOGIN_ID'),-1),
                                            X_SEQ_NUM                  => l_seq_num,
                                            X_ENTITY_NAME              => p_entity_name,
                                            X_COLUMN1                  => null,
                                            X_PK1_VALUE                => l_pk1_value,
                                            X_PK2_VALUE                => null,
                                            X_PK3_VALUE                => null,
                                            X_PK4_VALUE                => null,
                                            X_PK5_VALUE                => null,
                                            X_AUTOMATICALLY_ADDED_FLAG => 'N',
                                            X_DATATYPE_ID              => l_DATATYPE_ID,
                                            --X_usage_type                    => 'S',
                                            X_CATEGORY_ID              => l_category_id,
                                            X_SECURITY_TYPE            => 1,
                                            X_PUBLISH_FLAG             => 'Y',
                                            X_LANGUAGE                 => g_language,
                                            X_DESCRIPTION              => l_description,
                                            X_FILE_NAME                => l_filename,
                                            X_MEDIA_ID                 => l_media_id);
    

      -- Insert data into FND_LOB_ACCESS-----
    
      begin
        v_access_id := fnd_gfm.authorize(l_media_id);
        v_file_id   := fnd_gfm.confirm_upload(access_id       => v_access_id,
                                              file_name       => l_filename,
                                              program_name    => 'FNDATTCH',
                                              program_tag     => null,
                                              expiration_date => NULL,
                                              LANGUAGE        => g_language,
                                              wakeup          => TRUE);

      EXCEPTION
      WHEN OTHERS THEN
        l_status := 'E';
        l_status_message := l_status_message||CHR(13)||'ERROR: Error while loading file.'||SQLERRM;
      END;
    END IF;
    ------------------------------------------
  
    ---- Insert into FND_LOBS-----------------
    IF l_status <> 'E' THEN
      BEGIN
        IF dest_lob is null THEN
          src_lob := BFILENAME(p_filepath/*'XXECOM_CUSTOMER_PO_IN'*/, l_filename);
    
          DBMS_LOB.CREATETEMPORARY(dest_lob, TRUE, DBMS_LOB.SESSION);
          DBMS_LOB.OPEN(src_lob, DBMS_LOB.LOB_READONLY);
          DBMS_LOB.LoadFromFile(DEST_LOB => dest_lob,
                                SRC_LOB  => src_lob,
                                AMOUNT   => DBMS_LOB.GETLENGTH(src_lob));
          DBMS_LOB.CLOSE(src_lob);
        END IF;
        
        IF dest_lob IS NOT NULL
        THEN
          INSERT INTO FND_LOBS
            (FILE_ID,
             FILE_NAME,
             FILE_CONTENT_TYPE,
             FILE_DATA,
             UPLOAD_DATE,
             EXPIRATION_DATE,
             PROGRAM_NAME,
             PROGRAM_TAG,
             LANGUAGE,
             ORACLE_CHARSET,
             FILE_FORMAT)
          VALUES
            (l_media_id,
             l_filename,
             L_FILE_CONTENT_TYPE,
             dest_lob,
             SYSDATE,
             NULL,
             'FNDATTCH',
             NULL,
             g_language,
             'UTF8',
             L_FILE_FORMAT
             );
        END IF;
      EXCEPTION
      WHEN OTHERS THEN
        l_status := 'E';
        l_status_message := l_status_message||CHR(13)||'ERROR: Error while loading file.'||SQLERRM;
      END;
    END iF;
    
    x_status := l_status;
    x_status_message := l_status_message;
    
    if l_status = 'S' then
      commit;
    else
      rollback;  
    end if;
    
  exception
  when others then
    rollback;
    x_status := 'E';
    x_status_message := l_status_message||CHR(13)||SQLERRM;
  end load_file_attachment;
  
end xxfnd_load_attachment_pkg;
/
