CREATE OR REPLACE PACKAGE xxobjt_sf2oa_interface_pkg IS

  -----------------------------------------------------
  --  name:            XXOBJT_SF2OA_INTERFACE_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        CUST352 - Oracle Interface with SFDC
  --                   This package Handle all procedure that get data
  --                   data from SF and pass it to Oracle.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  Dalit A. Raviv    initial build
  --  1.1  26/10/2010  Dalit A. Raviv    add sf_fax number option for contact ins/upd
  --  1.2  24/11/2010  Dalit A. Raviv    1) create_code_assignment_api - when api finished
  --                                        with error table will update with warning and not error
  --                                     2) create_account_api - update party attribute3 with Sales_Territory__c (from sf)
  --                                     3) create_location_api - add validation on state only
  --                                        when territory_code is US.
  --  1.3  05/12/2010  Dalit A. Raviv    l_state was to short. update_location_api/ create_location_api
  --  1.4  21/12/2010  Dalit A. Raviv    procedure -> create_party_site_api.
  --                                     t_cust_site_use_rec.location have only 40 char
  --                                     the data we send is bigger - p_party_name || ' - ' ||l_location_s
  --                                     solution to sorten p_party_name to 30 char
  --  1.5  02/01/2010  Dalit A. Raviv    Procedure create_party_site_api:
  --                                     change party_site_name from country to party_name
  --  1.6  18/07/2012  Dalit A. Raviv    add procedure purge_log_tables
  --  1.7  16/10/2012  Dalit A. Raviv    add function get_sf_id_exist and call it from several places.
  --                                     CUST352 1.8 CR-503 Oracle Interface with SFDC -Prevent duplications from SFDC
  --------------------------------------------------------------------

  TYPE t_sf2oa_rec IS RECORD(
    status       VARCHAR2(50), -- NEW/IN-PROCESS/ERR/SUCCESS
    process_mode VARCHAR2(50), -- INSERT/UPDATE
    source_id    NUMBER,
    source_name  VARCHAR2(50) -- ACCOUNT/SITE/?.
    );

  --------------------------------------------------------------------
  --  name:            Main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf        OUT VARCHAR2,
	     retcode       OUT VARCHAR2,
	     p_source_name IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            get_cust_account_id_by_sf_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Function - get SF_ID and return oracle cust_account_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_cust_account_id_by_sf_id(p_sf_id IN VARCHAR2) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            update_SF_header_xml_Data
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that update interface header tbl
  --                   with the respond xml, ans source_name, and bpel_instance_id
  --                   by batch_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_sf_header_xml_data(p_batch_id    IN NUMBER,
			  p_bpel_id     IN NUMBER,
			  p_respond     IN xmltype,
			  p_source_name IN VARCHAR2,
			  p_err_code    OUT VARCHAR2,
			  p_err_msg     OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            insert_SF_line_xml_Data
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that insert new rows to interface line tbl
  --                   with the respond xml, ans source_name, and bpel_instance_id
  --                   by batch_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE insert_sf_line_xml_data(p_batch_id    IN NUMBER,
			p_source_name OUT VARCHAR2,
			p_err_code    OUT VARCHAR2,
			p_err_msg     OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            handle_contacts_in_oracle
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that Handle only CONTACTS DATA will get batch id
  --                   1) get population to work on
  --                   2) parse xml data
  --                   3) call API to create Contacts
  --                   4) update interface line table with errors / sf_id / oracle_id etc'
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_contacts_in_oracle(p_batch_id IN NUMBER,
			  p_err_code OUT VARCHAR2,
			  p_err_msg  OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            Handle_entities_in_oracle
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that Handle only SITE DATA will get batch id
  --                   1) get population to work on
  --                   2) parse xml data
  --                   3) call API to create SITE
  --                   4) update interface line table with errors / sf_id / oracle_id etc'
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_sites_in_oracle(p_batch_id IN NUMBER,
		           p_err_code OUT VARCHAR2,
		           p_err_msg  OUT VARCHAR2);
  --------------------------------------------------------------------
  --  name:            Handle_entities_in_oracle
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that Handle only ACCOUNT DATA will get batch id
  --                   1) get population to work on
  --                   2) parse xml data
  --                   3) call API to create Account
  --                   4) update interface line table with errors / sf_id / oracle_id etc'
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_accounts_in_oracle(p_batch_id IN NUMBER,
			  p_err_code OUT VARCHAR2,
			  p_err_msg  OUT VARCHAR2);

  -------------------------------------------------------------------
  --  name:            Handle_entities_in_oracle
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that will go by source_name and batch id
  --                   and will exctrat the xml, get sf_id, and data to handle
  --                   at oracle. account / site will insert to oracle, contact
  --                   will insert or update (check if oracle_id is null or not).
  --                   * This Procedure is an envelope to each entity handling.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_entities_in_oracle(p_batch_id    IN NUMBER,
			  p_source_name IN VARCHAR2,
			  p_err_code    OUT VARCHAR2,
			  p_err_msg     OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            insert_into_header
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that insert row to interface header tbl
  --                   at the begining of the process.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE insert_into_header(p_source_name IN VARCHAR2,
		       p_batch_id    OUT NUMBER,
		       p_err_code    OUT VARCHAR2,
		       p_err_msg     OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            update_SF_Data
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that will be call from BPEL process
  --                   and update for batch the instance id, and respond xml
  --                   from Bpel. (all the data we need to process)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_sf_data(p_batch_id    IN NUMBER,
		   p_bpel_id     IN NUMBER,
		   p_respond     IN xmltype,
		   p_source_name IN VARCHAR2,
		   p_err_code    OUT VARCHAR2,
		   p_err_msg     OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            update_SF_callback_results
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that will be call from BPEL process
  --                   and update if after we insert/update oracle with API
  --                   SF success to update with oracle_id.
  --                   This procedure willl update interface line tbl
  --                   with the retun SF_UPDATE flag Y/N.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_sf_callback_results(p_batch_id    IN NUMBER,
			   p_respond     IN xmltype,
			   p_source_name IN VARCHAR2,
			   p_err_code    OUT VARCHAR2,
			   p_err_msg     OUT VARCHAR2);
  --------------------------------------------------------------------
  --  name:            Call_Bpel_Process
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Call Bpel Process xxSF2OA_interfaces
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE call_bpel_process(p_source_name IN VARCHAR2,
		      p_batch_id    IN NUMBER,
		      p_status      OUT VARCHAR2,
		      p_message     OUT VARCHAR2,
		      p_respond     OUT sys.xmltype);

  --------------------------------------------------------------------
  --  name:            upd_system_err
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that will update header interface tbl
  --                   if there are BPEL system errors
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE upd_system_err(p_batch_id IN NUMBER,
		   p_err_code IN OUT VARCHAR2,
		   p_err_msg  IN OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            remove_xmlns
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   19/09/2010
  --------------------------------------------------------------------
  --  purpose :        xml transform - take out the xmlns (name space)
  --                   out of an xmltype.
  --                   return xmltype without name space.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/09/2010  Yuval Tal         initial build
  --------------------------------------------------------------------
  FUNCTION remove_xmlns(p_xml xmltype) RETURN xmltype;

  --------------------------------------------------------------------
  --  name:            create_location_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create location API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_location_api(p_country         IN VARCHAR2,
		        p_address_line1   IN VARCHAR2,
		        p_city            IN VARCHAR2,
		        p_postal_code     IN VARCHAR2,
		        p_state           IN VARCHAR2,
		        p_county          IN VARCHAR2,
		        p_oracle_event_id IN NUMBER,
		        p_entity          IN VARCHAR2 DEFAULT 'INSERT',
		        p_location_id     OUT NUMBER,
		        p_err_code        OUT VARCHAR2,
		        p_err_msg         OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            purge_log_tables
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/07/2012
  --------------------------------------------------------------------
  --  purpose :        Procedure that cwill delete xxobjt_sf2oa_interface_l table
  --                   data that is older then 6 month.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/07/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE purge_log_tables(errbuf        OUT VARCHAR2,
		     retcode       OUT VARCHAR2,
		     p_num_of_days IN NUMBER);

  --------------------------------------------------------------------
  --  name:            get_sf_id_exist
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/10/2012
  --------------------------------------------------------------------
  --  purpose :        function that check if sf_id already exist in oracle.
  --                   if yes this is a mistake and we do not want the program
  --                   create new object that is allready exists.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/10/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_sf_id_exist(p_source_name IN VARCHAR2,
		   p_sf_id       IN VARCHAR2) RETURN VARCHAR2;

  PROCEDURE update_sf_exist(p_sf_id           IN VARCHAR2,
		    p_oracle_event_id IN NUMBER,
		    p_err_msg         OUT VARCHAR2,
		    p_err_code        OUT VARCHAR2);
END xxobjt_sf2oa_interface_pkg;
/
