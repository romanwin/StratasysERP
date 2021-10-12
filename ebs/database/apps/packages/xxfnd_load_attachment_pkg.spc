create or replace package xxfnd_load_attachment_pkg authid current_user as

  --------------------------------------------------------------------
 
  --  name:          xxfnd_load_attachment_pkg
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
  );
end xxfnd_load_attachment_pkg;
/
