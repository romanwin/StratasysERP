CREATE OR REPLACE PACKAGE xxhz_interfaces_pkg IS

  --------------------------------------------------------------------
  --  customization code: CHG0031514 Customer support SF --> Oracle interfaces project
  --  name:               XXHZ_INTERFACES_PKG
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/03/2014
  --  Description:        Handle all HZ interfaces
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/03/2014    Dalit A. Raviv  initial build
  --  1.1   13/10/2014    Dalit A. RAviv  CHG0033449 SF Creating account relationship
  --                                      add function - Handle_SF_account_relation
  --  1.2   13/01/2015    Michal Tzvik    CHG0033182:
  --                                      New function - main_process_locations
  --  1.3   03/03/2015    Dalit A. Raviv  CHG0033183 - new procedure handle_sites_uploads
  --  1.4   20/04/2015    Michal Tzvik    CHG0034610 - Add parameter p_source to procedure main_process_accounts
  --  1.6  05/05/2015     Dalit A. Raviv  CHG0035283 - Inactivate Customer Sites via existing API
  --                                      new procedures set_Inactivate_Sites, print_out
  --  1.7  12/10/2015    Diptasurjya      CHG0036474 - Add customer account mass update API to load data from csv
  --                                      to TCA tables for ACCOUNT, PARTY and Classification update/create
  --  1.8 11/10/2018     Suad Ofer        CHG0043940 Add fileds to Customer update
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:               validate_dff_values
  --  create by:          Diptasurjya Chatterjee
  --  $Revision:          1.0
  --  creation date:      12/31/2015
  --  Description:        CHG0036474 - This is a generic procedure and can be used for validating any DFF segment values
  --                      Validate DFF segments values against their assigned value sets.
  --                      If assigned value set is table based or independent this procedure
  --                      will call validate_value_with_valueset to generate value set query dynamically
  --                      and validate passed segment value against the query
  --                      For Other value sets the value passed will be validated
  --                      against other attributes of value set like data format, length,
  --                      precision, max and min values etc
  --                      In case no value set is assigned, value will be passed as-is
  --                      Date type values will be converted to canonical form
  --------------------------------------------------------------------
  --  ver   date          name                    desc
  --  1.0   12/31/2015    Diptasurjya Chatterjee  CHG0036474 - initial build
  --------------------------------------------------------------------
  procedure validate_dff_values (p_dff_name IN varchar2,
                                 p_dff_column IN varchar2,
                                 p_dff_context_code IN varchar2,
                                 p_segment_value IN varchar2,
                                 x_status OUT varchar2,
                                 x_status_message OUT varchar2,
                                 x_storage_value OUT varchar2);
  --------------------------------------------------------------------
  --  name:               handle_accounts
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/03/2014
  --  Description:        Procedure that will handle account per interface record
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_accounts(errbuf         OUT VARCHAR2,
		    retcode        OUT VARCHAR2,
		    p_interface_id IN NUMBER);

  --------------------------------------------------------------------
  --  name:               handle_sites
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      19/03/2014
  --  Description:        Procedure that will handle site per interface record
  --                      each procedure handle the case of create or update
  --                      Handle_location          -> create/update
  --                      Handle_party_site        -> create/update
  --                      Handle_cust_account_site -> create/update
  --                      Handle_cust_site_use     -> create/update
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_sites(errbuf         OUT VARCHAR2,
		 retcode        OUT VARCHAR2,
		 p_interface_id IN NUMBER);

  --------------------------------------------------------------------
  --  name:               handle_contacts
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      23/03/2014
  --  Description:        Procedure that Handle create/update contacts
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE handle_contacts(errbuf         OUT VARCHAR2,
		    retcode        OUT VARCHAR2,
		    p_interface_id IN NUMBER);

  --------------------------------------------------------------------
  --  name:               main_Sf_Interface
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      13/04/2014
  --  Description:        Procedure that will
  --                      1) look at BI database for cahnges that done in salesforce.
  --                      2) all diff record that found will enter row to interface tables (account, site, contact)
  --                      3) when success enter record to xxobjt_oa2sf_interface table to
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/03/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE main_sf_interface(errbuf  OUT VARCHAR2,
		      retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:               main_process_Accounts
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      28/04/2014
  --  Description:        Procedure that will
  --                      1) Handle sites -> use all API and update oracle with changes from SF
  --                      2) Insert record to oa2sf interface table
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/04/2014    Dalit A. Raviv  initial build
  --  1.1   20/04/2015    Michal Tzvik    CHG0034610- Add parameter p_source
  --------------------------------------------------------------------
  PROCEDURE main_process_accounts(errbuf   OUT VARCHAR2,
		          retcode  OUT VARCHAR2,
		          p_source IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:               main_process_sites
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      27/04/2014
  --  Description:        Procedure that will
  --                      1) Handle sites -> use all API and update oracle with changes from SF
  --                      2) Insert record to oa2sf interface table
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   27/04/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE main_process_sites(errbuf  OUT VARCHAR2,
		       retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:               main_process_contacts
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      27/04/2014
  --  Description:        Procedure that will
  --                      1) Handle contacts -> use all API and update oracle with changes from SF
  --                      2) Insert record to oa2sf interface table
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   27/04/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE main_process_contacts(errbuf  OUT VARCHAR2,
		          retcode OUT VARCHAR2);
  --------------------------------------------------------------------
  --  name:               main_process_locations
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      13/01/2015
  --  Description:        Handle locations
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   13/01/2015    Michal Tzvik    CHG0033182: initial build
  --------------------------------------------------------------------
  PROCEDURE main_process_locations(errbuf   OUT VARCHAR2,
		           retcode  OUT VARCHAR2,
		           p_source IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:               main_Sf_Interface
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      22/04/2014
  --  Description:        Procedure that will
  --                      insert record to account interface table.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   22/04/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE insert_into_account_int(errbuf    OUT VARCHAR2,
			retcode   OUT VARCHAR2,
			p_acc_rec IN xxhz_account_interface%ROWTYPE);

  --------------------------------------------------------------------
  --  name:               insert_into_site_int
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      24/04/2014
  --  Description:        Procedure that will
  --                      insert record to site interface table.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   24/04/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE insert_into_site_int(errbuf     OUT VARCHAR2,
		         retcode    OUT VARCHAR2,
		         p_site_rec IN xxhz_site_interface%ROWTYPE);

  --------------------------------------------------------------------
  --  name:               insert_into_site_int
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      24/04/2014
  --  Description:        Procedure that will
  --                      insert record to site interface table.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   24/04/2014    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE insert_into_contact_int(errbuf        OUT VARCHAR2,
			retcode       OUT VARCHAR2,
			p_contact_rec IN xxhz_contact_interface%ROWTYPE);

  PROCEDURE insert_test_records;

  --------------------------------------------------------------------
  --  name:            Handle_SF_account_relation
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/10/2014
  --------------------------------------------------------------------
  --  purpose :        Procedure that handle create/ update account relationship
  --                   CHG0033449
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/10/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_sf_account_relation(errbuf      OUT VARCHAR2,
			   retcode     OUT VARCHAR2,
			   p_days_back IN NUMBER);

  --------------------------------------------------------------------
  --  name:            handle_sites_uploads
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/03/2015
  --------------------------------------------------------------------
  --  purpose :        Procedure that handle update site for FIN usages
  --                   CHG0033183
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/03/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_sites_uploads(errbuf          OUT VARCHAR2,
		         retcode         OUT VARCHAR2,
		         p_table_name    IN VARCHAR2, -- XXHZ_SITE_INTERFACE
		         p_template_name IN VARCHAR2, -- Salesrep_Agent
		         p_file_name     IN VARCHAR2, -- xxx.csv
		         p_directory     IN VARCHAR2, -- /UtlFiles/shared/DEV -> PROD/HZ/locations
		         p_source        IN VARCHAR2,
		         p_upload        IN VARCHAR2, -- Y/N
		         p_send_mail     IN VARCHAR2); -- Y/N
  --------------------------------------------------------------------
  --  name:            handle_contact_uploads
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   22/10/2018
  --------------------------------------------------------------------
  --  purpose :        Procedure that handle update Contact 
  --                   CHG0043940
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/10/2018  Ofer Suad    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_contact_uploads(errbuf          OUT VARCHAR2,
             retcode         OUT VARCHAR2,
             p_table_name    IN VARCHAR2, -- XXHZ_SITE_INTERFACE
             p_template_name IN VARCHAR2, -- Salesrep_Agent
             p_file_name     IN VARCHAR2, -- xxx.csv
             p_directory     IN VARCHAR2, -- /UtlFiles/shared/DEV -> PROD/HZ/locations
             p_source        IN VARCHAR2,
             p_upload        IN VARCHAR2, -- Y/N
             p_send_mail     IN VARCHAR2); -- Y/N           

  --------------------------------------------------------------------
  --  name:            handle_account_uploads
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   12/04/2015
  --------------------------------------------------------------------
  --  purpose :        Procedure that handle update account for FIN usages
  --                   CHG0036474
  --------------------------------------------------------------------
  --  ver  date        name                      desc
  --  1.0  12/04/2015  Diptasurjya Chatterjee    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_account_uploads(errbuf          OUT VARCHAR2,
		           retcode         OUT VARCHAR2,
		           p_table_name    IN VARCHAR2, -- XXHZ_ACCOUNT_INTERFACE
		           p_template_name IN VARCHAR2, -- XXHZ_ACCOUNT
		           p_file_name     IN VARCHAR2, -- xxx.csv
		           p_directory     IN VARCHAR2, -- /UtlFiles/shared/DEV -> PROD/HZ/locations
		           p_source        IN VARCHAR2,
		           p_upload        IN VARCHAR2, -- Y/N
		           p_send_mail     IN VARCHAR2);

  /*----------------------------------------------------------------------------------------
  --------------------------------------------------------------------
  --  name:            create_party_site_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/03/2014
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create cust account site API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/03/2014  Dalit A. Raviv    initial build
  --  1.1  04/03/2015  Dalit A. Raviv    CHG0033183 add nvl to status field.
  --  1.2  30/04/2015  Michal Tzvik      CHG0034610 remove G_MISS
  --------------------------------------------------------------------
  PROCEDURE update_cust_account_site_api(errbuf       OUT VARCHAR2,
                                         retcode      OUT VARCHAR2,
                                         p_org_id     OUT NUMBER,
                                         p_party_name OUT VARCHAR2,
                                         p_entity     IN VARCHAR2,
                                         p_site_rec   IN xxhz_site_interface%ROWTYPE) ;
  */
  --------------------------------------------------------------------
  --  name:            set_Inactivate_Sites
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035283 Inactivate Customer Sites via existing API
  --                   Procedure that update site ti inactive
  --                   will cal from concurrent program
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/05/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE set_inactivate_sites(errbuf          OUT VARCHAR2,
		         retcode         OUT VARCHAR2,
		         p_table_name    IN VARCHAR2, -- XXHZ_SITE_INTERFACE
		         p_template_name IN VARCHAR2, -- SITE_INACTIVE
		         p_file_name     IN VARCHAR2, -- xxx.csv
		         p_directory     IN VARCHAR2, -- /UtlFiles/shared/DEV -> PROD/HZ/locations
		         p_upload        IN VARCHAR2 -- Y/N
		         );

  --------------------------------------------------------------------
  --  name:            print_out
  --  create by:       Dalit A. RAviv
  --  Revision:        1.0
  --  creation date:   10/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035283
  --                   Print message to output
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  10/05/2015  Dalit A. RAviv  CHG0035283
  --------------------------------------------------------------------
  PROCEDURE print_out(p_print_msg VARCHAR2);

--XXHZ_INTERFACES_PKG.main_process_accounts  main_process_sites main_process_contacts
END xxhz_interfaces_pkg;
/