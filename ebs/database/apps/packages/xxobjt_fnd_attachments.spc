CREATE OR REPLACE PACKAGE xxobjt_fnd_attachments AS

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
  --  1.5  02/06/2015  Michal Tzvik      CHG0035332 - Add procedure create_short_text_att to spec
  --                                     New procedure: update_short_text_att
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
  FUNCTION get_short_message_name(p_entity_name VARCHAR2) RETURN VARCHAR2;

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
		       p_pk3         VARCHAR2) RETURN NUMBER;

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
		     p_entity_name   VARCHAR2) RETURN VARCHAR2;

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
  FUNCTION generate_arc_file_name(p_file_id NUMBER) RETURN VARCHAR2;

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
		p_document_id   NUMBER);

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
		  p_file_id       NUMBER);

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
		   p_pk3         VARCHAR2);

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
			x_media_id          IN OUT NUMBER);

  --------------------------------------------------------------------
  --  name:            reverse_archive
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   16.08.2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.08.2011  yuval tal         initial build
  --------------------------------------------------------------------
  PROCEDURE reverse_archive(p_errmsg    OUT VARCHAR2,
		    p_errcode   OUT NUMBER,
		    p_file_id   NUMBER,
		    p_blob_data BLOB);

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
		      p_blob      OUT BLOB);

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
  FUNCTION get_environment_name RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_directory_path
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/06/2012
  --------------------------------------------------------------------
  --  purpose:         function that set directory path
  --                   according to the environment program run.
  --                   (PROD,TEST,DEV,YES,PATCH etc.)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_oracle_dir(p_name VARCHAR2,
		      p_dir  VARCHAR2);

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
		         p_sub_dir VARCHAR2);

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
		        p_directory IN VARCHAR2);

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
		          retcode OUT VARCHAR2);

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
		          retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:               Handle_OKS_attachments
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      28/05/2014
  --  Description:        download SR attachments files to a local folder
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/05/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_oks_attachments(errbuf  OUT VARCHAR2,
		           retcode OUT VARCHAR2);

  /*PROCEDURE delete_files(errmsg            OUT VARCHAR2,
  errcode           OUT NUMBER,
  p_conc_request_id NUMBER);*/

  /*PROCEDURE create_attachmnets(err_code      OUT NUMBER,
  err_msg       OUT VARCHAR2,
  p_category_id NUMBER,
  p_entity_name VARCHAR2,
  p_file_name   VARCHAR2,
  p_title       VARCHAR2,
  p_description VARCHAR2,
  p_pk1         NUMBER,
  p_pk2         NUMBER,
  p_pk3         NUMBER);*/

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
		           --p_function_type IN VARCHAR2,
		           p_entity_name   IN VARCHAR2,
		           p_category_name IN VARCHAR2,
		           p_entity_id1    IN VARCHAR2,
		           p_entity_id2    IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2;

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
  --  1.1  02.06.2015  Michal Tzvik     CHG0035332 - Add this procedure to spec
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
		          p_pk3                     NUMBER);

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
		          p_pk3           NUMBER);

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
		      p_pk1             VARCHAR2,
		      p_pk2             VARCHAR2,
		      p_pk3             VARCHAR2);

END xxobjt_fnd_attachments;
/
