CREATE OR REPLACE PACKAGE xxhz_api_pkg AS
--------------------------------------------------------------------
--  name:            xxhz_api_pkg
--  create by:       Mike Mazanet
--  Revision:        1.1
--  creation date:   06/05/2015
--------------------------------------------------------------------
--  purpose : Main package to handle customers.  Main entry points are
--            handle_customer, handle_sites, handle_contacts.  These
--            each branch out and allow users to INSERT/UPDATE 
--            customers, sites, contacts, and the related child 
--            entities of each.
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
--------------------------------------------------------------------

  TYPE frm_organization_rec IS RECORD(
    party_id                        NUMBER,
    party_number                    VARCHAR2(30),
    party_status                    VARCHAR2(1),
    organization_name               VARCHAR2(360),
    organization_name_phonetic      VARCHAR2(320),
    category_code                   VARCHAR2(30),                  
    duns_number_c                   VARCHAR2(30),
    tax_reference                   VARCHAR2(50),       -- Tax registration
    jgzz_fiscal_code                VARCHAR2(20),       -- VAT Number
    known_as                        VARCHAR2(240),
    attribute_category              VARCHAR2(30),
    attribute1                      VARCHAR2(150),
    attribute2                      VARCHAR2(150),
    attribute3                      VARCHAR2(150),
    attribute4                      VARCHAR2(150),
    attribute5                      VARCHAR2(150),
    attribute6                      VARCHAR2(150),
    attribute7                      VARCHAR2(150),
    attribute8                      VARCHAR2(150),
    attribute9                      VARCHAR2(150),
    attribute10                     VARCHAR2(150),
    attribute11                     VARCHAR2(150),
    attribute12                     VARCHAR2(150),
    attribute13                     VARCHAR2(150),
    attribute14                     VARCHAR2(150),
    attribute15                     VARCHAR2(150),
    attribute16                     VARCHAR2(150),
    attribute17                     VARCHAR2(150),
    attribute18                     VARCHAR2(150),
    attribute19                     VARCHAR2(150),
    attribute20                     VARCHAR2(150)
  );

  TYPE frm_relationship_rec_type IS RECORD(
    relationship_id                 NUMBER,
    relationship_party_id           NUMBER,
    subject_id                      NUMBER,
    subject_type                    VARCHAR2(30),
    subject_table_name              VARCHAR2(30),
    object_id                       NUMBER,
    object_type                     VARCHAR2(30),
    object_table_name               VARCHAR2(30),
    relationship_code               VARCHAR2(30),
    relationship_type               VARCHAR2(30),
    comments                        VARCHAR2(240),
    start_date                      DATE ,
    end_date                        DATE,
    status                          VARCHAR2(1),
    created_by_module               VARCHAR2(150)
  );
  
  -- This type mirrors the hz_classification_v2pub.code_assignment_rec_type
  TYPE frm_code_assignment_rec_type IS RECORD (
    code_assignment_id              NUMBER,
    owner_table_name                VARCHAR2(30),
    owner_table_id                  NUMBER,
    owner_table_key_1               VARCHAR2(255),
    owner_table_key_2               VARCHAR2(255),
    owner_table_key_3               VARCHAR2(255),
    owner_table_key_4               VARCHAR2(255),
    owner_table_key_5               VARCHAR2(255),
    class_category                  VARCHAR2(30),
    class_code                      VARCHAR2(30),
    primary_flag                    VARCHAR2(1),
    content_source_type             VARCHAR2(30),
    start_date_active               DATE,
    end_date_active                 DATE,
    status                          VARCHAR2(1),
    created_by_module               VARCHAR2(150),
    rank                            NUMBER,
    application_id                  NUMBER,
    actual_content_source           VARCHAR2(30)
  ); 

  -- This type mirrors the hz_location_v2pub.location_rec_type
  TYPE frm_location_rec IS RECORD(
    location_id                  NUMBER,
    country                      VARCHAR2(60),
    address1                     VARCHAR2(240),
    address2                     VARCHAR2(240),
    address3                     VARCHAR2(240),                                                           
    address4                     VARCHAR2(240),                                                            
    city                         VARCHAR2(60),                                                             
    postal_code                  VARCHAR2(60),                                                             
    state                        VARCHAR2(60),
    county                       VARCHAR2(60),
    province                     VARCHAR2(60),                                                             
    attribute_category           VARCHAR2(30),                                                             
    attribute1                   VARCHAR2(150),                                                            
    attribute2                   VARCHAR2(150),                                                            
    attribute3                   VARCHAR2(150),
    attribute4                   VARCHAR2(150),
    attribute5                   VARCHAR2(150),
    attribute6                   VARCHAR2(150),
    attribute7                   VARCHAR2(150),
    attribute8                   VARCHAR2(150),
    attribute9                   VARCHAR2(150),
    attribute10                  VARCHAR2(150),
    attribute11                  VARCHAR2(150),
    attribute12                  VARCHAR2(150),
    attribute13                  VARCHAR2(150),
    attribute14                  VARCHAR2(150),
    attribute15                  VARCHAR2(150),
    attribute16                  VARCHAR2(150),
    attribute17                  VARCHAR2(150),
    attribute18                  VARCHAR2(150),
    attribute19                  VARCHAR2(150),
    attribute20                  VARCHAR2(150),
    created_by_module            VARCHAR2(150)    
  );                                                                                                               
  
  TYPE frm_cust_cont_person_rec IS RECORD(                                                                         
    person_pre_name_adjunct         VARCHAR2(30),                                                                  
    person_first_name               VARCHAR2(150),                                                                 
    person_middle_name              VARCHAR2(60),                                                                         
    person_last_name                VARCHAR2(150),                                                                 
    person_name_suffix              VARCHAR2(30),                                                                  
    person_title                    VARCHAR2(60),
    created_by_module               VARCHAR2(150),
    -- from hz_party_v2_pub.party_rec_type
    party_rec                       hz_party_v2pub.party_rec_type                                                 
  );

  TYPE frm_cust_cont_org_rec IS RECORD(
    org_contact_id                  NUMBER,
    contact_number                  VARCHAR2(30),
    job_title                       VARCHAR2(100),
    job_title_code                  VARCHAR2(30),
    orig_system_reference           VARCHAR2(240),
    orig_system                     VARCHAR2(30),
    attribute_category              VARCHAR2(30),
    attribute1                      VARCHAR2(150),
    attribute2                      VARCHAR2(150),
    attribute3                      VARCHAR2(150),
    attribute4                      VARCHAR2(150),
    attribute5                      VARCHAR2(150),
    attribute6                      VARCHAR2(150),
    attribute7                      VARCHAR2(150),
    attribute8                      VARCHAR2(150),
    attribute9                      VARCHAR2(150),
    attribute10                     VARCHAR2(150),
    attribute11                     VARCHAR2(150),
    attribute12                     VARCHAR2(150),
    attribute13                     VARCHAR2(150),
    attribute14                     VARCHAR2(150),
    attribute15                     VARCHAR2(150),
    attribute16                     VARCHAR2(150),
    attribute17                     VARCHAR2(150),
    attribute18                     VARCHAR2(150),
    attribute19                     VARCHAR2(150),
    attribute20                     VARCHAR2(150),
    attribute21                     VARCHAR2(150),
    attribute22                     VARCHAR2(150),
    attribute23                     VARCHAR2(150),
    attribute24                     VARCHAR2(150),
    created_by_module               VARCHAR2(150),
    application_id                  NUMBER,
    -- from HZ_RELATIONSHIP_V2PUB.relationship_rec_type
    party_id                        NUMBER,
    relationship_id                 NUMBER,
    subject_id                      NUMBER,
    subject_type                    VARCHAR2(30),
    subject_table_name              VARCHAR2(30),
    object_id                       NUMBER,
    object_type                     VARCHAR2(30),
    object_table_name               VARCHAR2(30),
    relationship_code               VARCHAR2(30),
    relationship_type               VARCHAR2(30),
    comments                        VARCHAR2(240),
    start_date                      DATE ,
    end_date                        DATE,
    status                          VARCHAR2(1)
  );

  TYPE frm_cust_cont_point_rec IS RECORD (
    contact_point_id                        NUMBER,
    contact_point_type                      VARCHAR2(30),
    status                                  VARCHAR2(30),
    owner_table_name                        VARCHAR2(30),
    owner_table_id                          NUMBER,
    primary_flag                            VARCHAR2(1),
    orig_system_reference                   VARCHAR2(240),
    orig_system                             VARCHAR2(30),
    content_source_type                     VARCHAR2(30),
    attribute_category                      VARCHAR2(30),
    attribute1                              VARCHAR2(150),
    attribute2                              VARCHAR2(150),
    attribute3                              VARCHAR2(150),
    attribute4                              VARCHAR2(150),
    attribute5                              VARCHAR2(150),
    attribute6                              VARCHAR2(150),
    attribute7                              VARCHAR2(150),
    attribute8                              VARCHAR2(150),
    attribute9                              VARCHAR2(150),
    attribute10                             VARCHAR2(150),
    attribute11                             VARCHAR2(150),
    attribute12                             VARCHAR2(150),
    attribute13                             VARCHAR2(150),
    attribute14                             VARCHAR2(150),
    attribute15                             VARCHAR2(150),
    attribute16                             VARCHAR2(150),
    attribute17                             VARCHAR2(150),
    attribute18                             VARCHAR2(150),
    attribute19                             VARCHAR2(150),
    attribute20                             VARCHAR2(150),
    contact_point_purpose                   VARCHAR2(30),
    primary_by_purpose                      VARCHAR2(30),
    created_by_module                       VARCHAR2(150),
    application_id                          NUMBER,
    actual_content_source                   VARCHAR2(30)
  );

  -- object version numbers are on this record type, since individual record types don't 
  -- have object version numbers
  TYPE frm_customer_rec IS RECORD(
    party_ovn                       hz_parties.object_version_number%TYPE,
    acct_ovn                        hz_cust_accounts_all.object_version_number%TYPE,  
    cust_profile_ovn                hz_customer_profiles.object_version_number%TYPE, 
    cust_profile_amt_ovn            hz_cust_profile_amts.object_version_number%TYPE,
    cust_classification_ovn         hz_code_assignments.object_version_number%TYPE,
    cust_relationship_ovn           hz_relationships.object_version_number%TYPE,
    cust_relationship_party_ovn     hz_parties.object_version_number%TYPE,    
    cust_account_relationship_ovn   hz_cust_acct_relate_all.object_version_number%TYPE,
    cust_tax_registration_ovn       zx_registrations.object_version_number%TYPE,
    cust_account_rec                hz_cust_account_v2pub.cust_account_rec_type,
    cust_organization_rec           frm_organization_rec,
    cust_profile_rec                hz_customer_profile_v2pub.customer_profile_rec_type,
    cust_profile_amt_rec            hz_customer_profile_v2pub.cust_profile_amt_rec_type,
    cust_classifications_rec        frm_code_assignment_rec_type,  
    cust_account_relationship_rec   hz_cust_account_v2pub.cust_acct_relate_rec_type,
    cust_relationship_rec           frm_relationship_rec_type,           
    cust_tax_registration           zx_registrations%ROWTYPE
  );  
  
  TYPE customer_rec IS RECORD(
    party_ovn                       hz_parties.object_version_number%TYPE,
    acct_ovn                        hz_cust_accounts_all.object_version_number%TYPE,  
    cust_profile_ovn                hz_customer_profiles.object_version_number%TYPE, 
    cust_profile_amt_ovn            hz_cust_profile_amts.object_version_number%TYPE, 
    cust_classification_ovn         hz_code_assignments.object_version_number%TYPE,
    cust_relationship_ovn           hz_relationships.object_version_number%TYPE,
    cust_relationship_party_ovn     hz_parties.object_version_number%TYPE,
    cust_account_relationship_ovn   hz_cust_acct_relate_all.object_version_number%TYPE,
    cust_tax_registration_ovn       zx_registrations.object_version_number%TYPE,
    cust_account_rec                hz_cust_account_v2pub.cust_account_rec_type,
    cust_organization_rec           hz_party_v2pub.organization_rec_type,
    cust_profile_rec                hz_customer_profile_v2pub.customer_profile_rec_type,
    cust_profile_amt_rec            hz_customer_profile_v2pub.cust_profile_amt_rec_type,
    cust_classifications_rec        hz_classification_v2pub.code_assignment_rec_type,
    cust_account_relationship_rec   hz_cust_account_v2pub.cust_acct_relate_rec_type,
    cust_relationship_rec           hz_relationship_v2pub.relationship_rec_type,        
    cust_tax_registration           zx_registrations%ROWTYPE    
  );

  -- Uses custom location_rec because of form issue (see notes by location_rec) declaration
  TYPE frm_customer_site_rec IS RECORD(
    location_ovn              hz_locations.object_version_number%TYPE,
    party_site_ovn            hz_party_sites.object_version_number%TYPE,
    cust_acct_sites_ovn       hz_cust_acct_sites_all.object_version_number%TYPE,
    cust_site_use_ovn         hz_cust_site_uses_all.object_version_number%TYPE, 
    cust_profile_ovn          hz_customer_profiles.object_version_number%TYPE, 
    cust_profile_amt_ovn      hz_cust_profile_amts.object_version_number%TYPE,    
    location_rec              frm_location_rec,
    party_site_rec            hz_party_site_v2pub.party_site_rec_type,
    cust_site_rec             hz_cust_account_site_v2pub.cust_acct_site_rec_type,
    cust_site_use_rec         hz_cust_account_site_v2pub.cust_site_use_rec_type, 
    cust_profile_rec          hz_customer_profile_v2pub.customer_profile_rec_type,
    cust_profile_amt_rec      hz_customer_profile_v2pub.cust_profile_amt_rec_type     
  );

  TYPE customer_site_rec IS RECORD(
    location_ovn              hz_locations.object_version_number%TYPE,
    party_site_ovn            hz_party_sites.object_version_number%TYPE,
    cust_acct_sites_ovn       hz_cust_acct_sites_all.object_version_number%TYPE,
    cust_site_use_ovn         hz_cust_site_uses_all.object_version_number%TYPE, 
    cust_profile_ovn          hz_customer_profiles.object_version_number%TYPE, 
    cust_profile_amt_ovn      hz_cust_profile_amts.object_version_number%TYPE,    
    location_rec              hz_location_v2pub.location_rec_type,
    party_site_rec            hz_party_site_v2pub.party_site_rec_type,
    cust_site_rec             hz_cust_account_site_v2pub.cust_acct_site_rec_type,
    cust_site_use_rec         hz_cust_account_site_v2pub.cust_site_use_rec_type,
    cust_profile_rec          hz_customer_profile_v2pub.customer_profile_rec_type,
    cust_profile_amt_rec      hz_customer_profile_v2pub.cust_profile_amt_rec_type    
  );

  --TYPE customer_site_tbl IS TABLE OF frm_customer_site_rec;

  TYPE frm_customer_contact_rec IS RECORD(
    party_ovn                   hz_parties.object_version_number%TYPE,
    org_contact_ovn             hz_org_contacts.object_version_number%TYPE,
    relationship_ovn            hz_relationships.object_version_number%TYPE,      
    rel_party_ovn               hz_parties.object_version_number%TYPE,
    location_ovn                hz_locations.object_version_number%TYPE,
    party_site_ovn              hz_party_sites.object_version_number%TYPE,
    party_site_use_ovn          hz_party_site_uses.object_version_number%TYPE,
    role_ovn                    hz_cust_account_roles.object_version_number%TYPE,
    role_resp_ovn               hz_role_responsibility.object_version_number%TYPE,
    contact_point_ovn           hz_contact_points.object_version_number%TYPE,
    cust_cont_person_rec        frm_cust_cont_person_rec,
    cust_cont_org_rec           frm_cust_cont_org_rec,
    location_rec                frm_location_rec,
    party_site_rec              hz_party_site_v2pub.party_site_rec_type,
    party_site_use_rec          hz_party_site_v2pub.party_site_use_rec_type,
    cust_cont_role_rec          hz_cust_account_role_v2pub.cust_account_role_rec_type,
    cust_cont_role_resp_rec     hz_cust_account_role_v2pub.role_responsibility_rec_type,
    cust_cont_point_rec         frm_cust_cont_point_rec,
    cust_cont_phone_rec         hz_contact_point_v2pub.phone_rec_type,
    -- Extra phone contact for form when creating contacts
    mobile_cont_phone_rec       hz_contact_point_v2pub.phone_rec_type,
    cust_cont_email_rec         hz_contact_point_v2pub.email_rec_type,
    cust_cont_web_rec           hz_contact_point_v2pub.web_rec_type
  );

  TYPE customer_contact_rec IS RECORD(
    party_ovn                   hz_parties.object_version_number%TYPE,
    org_contact_ovn             hz_org_contacts.object_version_number%TYPE,
    relationship_ovn            hz_relationships.object_version_number%TYPE,      
    rel_party_ovn               hz_parties.object_version_number%TYPE,
    location_ovn                hz_locations.object_version_number%TYPE,
    party_site_ovn              hz_party_sites.object_version_number%TYPE,
    party_site_use_ovn          hz_party_site_uses.object_version_number%TYPE,
    role_ovn                    hz_cust_account_roles.object_version_number%TYPE,
    role_resp_ovn               hz_role_responsibility.object_version_number%TYPE,
    contact_point_ovn           hz_contact_points.object_version_number%TYPE,
    cust_cont_person_rec        hz_party_v2pub.person_rec_type,
    cust_cont_org_rec           hz_party_contact_v2pub.org_contact_rec_type,
    location_rec                hz_location_v2pub.location_rec_type,
    party_site_rec              hz_party_site_v2pub.party_site_rec_type,
    party_site_use_rec          hz_party_site_v2pub.party_site_use_rec_type,
    cust_cont_role_rec          hz_cust_account_role_v2pub.cust_account_role_rec_type,
    cust_cont_role_resp_rec     hz_cust_account_role_v2pub.role_responsibility_rec_type,
    cust_cont_point_rec         hz_contact_point_v2pub.contact_point_rec_type,
    cust_cont_phone_rec         hz_contact_point_v2pub.phone_rec_type,
    cust_cont_email_rec         hz_contact_point_v2pub.email_rec_type,
    cust_cont_web_rec           hz_contact_point_v2pub.web_rec_type
  );

  TYPE dup_rec IS RECORD(
    match_type  VARCHAR2(250),
    id1         NUMBER,
    id2         NUMBER,
    num1        NUMBER,
    num2        NUMBER,
    num3        NUMBER,
    num4        NUMBER,
    char1       VARCHAR2(250),
    char2       VARCHAR2(250),
    char3       VARCHAR2(250),
    char4       VARCHAR2(250),
    char5       VARCHAR2(250),
    char6       VARCHAR2(250),
    char7       VARCHAR2(250),
    char8       VARCHAR2(250),    
    char9       VARCHAR2(250),
    char10      VARCHAR2(250),
    char11      VARCHAR2(250),
    char12      VARCHAR2(250),
    char13      VARCHAR2(250),
    char14      VARCHAR2(250),
    char15      VARCHAR2(250)
  );

  TYPE dup_tbl IS TABLE OF dup_rec INDEX BY BINARY_INTEGER;

  PROCEDURE create_customer_ext(
    p_oe_id           IN xxssys_customer_ext.oe_id%TYPE,
    p_oe_type         IN xxssys_customer_ext.oe_type%TYPE,
    p_external_system IN xxssys_customer_ext.external_system%TYPE,
    p_external_id     IN xxssys_customer_ext.external_id%TYPE       DEFAULT NULL,
    x_return_status   OUT VARCHAR2,
    x_return_message  OUT VARCHAR2
  );

  PROCEDURE handle_customer_ext(
    p_oe_id           IN xxssys_customer_ext.oe_id%TYPE,
    p_oe_type         IN xxssys_customer_ext.oe_type%TYPE,
    p_external_system IN xxssys_customer_ext.external_system%TYPE,
    p_external_id     IN xxssys_customer_ext.external_id%TYPE       DEFAULT NULL,
    x_return_status   OUT VARCHAR2,
    x_return_message  OUT VARCHAR2
  ); 

  PROCEDURE find_duplicate_customers(
    p_dup_cust          IN OUT dup_tbl,
    p_match_type        IN  VARCHAR2 DEFAULT 'EXACT',
    p_cust_account_id   IN  NUMBER,
    p_party_name        IN  VARCHAR2,
    p_atradius_id       IN  VARCHAR2,
    p_duns_number       IN  NUMBER,
    p_tax_reference     IN  VARCHAR2,
    x_return_status     OUT VARCHAR2,
    x_return_message    OUT VARCHAR2
  );

  PROCEDURE find_duplicate_customers_only(
    p_match_type          IN VARCHAR2 DEFAULT 'LIKE',
    p_customer_in_tbl     IN xxar_cust_match_tab,  
    x_dup_customer_tbl    OUT xxar_cust_match_tab,
    x_return_status       OUT VARCHAR2,
    x_return_message      OUT VARCHAR2
  ); 

  PROCEDURE handle_account(
    p_dup_match_type            IN VARCHAR2 DEFAULT 'LIKE',                                                          
    p_acc_rec                   IN OUT customer_rec,
    p_dup_acct_tbl              OUT dup_tbl,
    x_return_status             OUT VARCHAR2,                                                                        
    x_return_message            OUT VARCHAR2, 
    x_wf_return_message         OUT VARCHAR2    
  ) ;

  PROCEDURE frm_handle_account(
    p_dup_match_type            IN VARCHAR2 DEFAULT 'LIKE',                                                             
    p_acc_rec                   IN OUT frm_customer_rec,
    p_dup_acct_tbl              OUT dup_tbl,
    x_return_status             OUT VARCHAR2,                                                                        
    x_return_message            OUT VARCHAR2, 
    x_wf_return_message         OUT VARCHAR2    
  );

  PROCEDURE handle_account_lock(
    p_acc_rec                   IN OUT frm_customer_rec,   
    x_return_status             OUT VARCHAR2,                                                                        
    x_return_message            OUT VARCHAR2    
  );
  
  PROCEDURE handle_account_obj_api(  
    p_dup_match_type      IN VARCHAR2 DEFAULT 'LIKE',   
    p_org_cust_tbl        IN OUT HZ_ORG_CUST_BO_TBL,
    p_error_tbl           OUT XXSSYS_ERROR_TBL,
    p_dup_org_cust_tbl    OUT HZ_ORG_CUST_BO_TBL,
    x_return_status       OUT VARCHAR2,
    x_return_message      OUT VARCHAR2,
    x_wf_return_message   OUT VARCHAR2
  );

  PROCEDURE find_duplicate_sites(
    p_match_type        IN VARCHAR2 DEFAULT 'LIKE',
    p_cust_account_id   IN NUMBER,
    p_location_id       IN NUMBER,
    p_address1          IN VARCHAR2,
    p_address2          IN VARCHAR2,
    p_address3          IN VARCHAR2,
    p_address4          IN VARCHAR2,
    p_city              IN VARCHAR2,
    p_state             IN VARCHAR2,
    p_province          IN VARCHAR2,
    p_postal_code       IN VARCHAR2,
    p_country           IN VARCHAR2,
    p_dup_sites_tbl     IN OUT dup_tbl,
    x_return_status     OUT VARCHAR2,
    x_return_message    OUT VARCHAR2
  );
  
  PROCEDURE get_address(
    p_site_rec            IN OUT frm_customer_site_rec,
    x_return_message      OUT VARCHAR2,
    x_return_status       OUT VARCHAR2     
  );

  PROCEDURE handle_sites(  
    p_dup_match_type      IN VARCHAR2 DEFAULT 'LIKE',  
    p_cust_site_rec       IN OUT customer_site_rec,
    p_dup_sites_tbl       OUT dup_tbl,
    x_return_message      OUT VARCHAR2,
    x_return_status       OUT VARCHAR2,
    x_wf_return_message   OUT VARCHAR2
  ) ;

  PROCEDURE frm_handle_sites(
    p_dup_match_type      IN VARCHAR2 DEFAULT 'LIKE',  
    p_cust_site_rec       IN OUT frm_customer_site_rec,
    p_dup_sites_tbl       OUT dup_tbl,
    x_return_message      OUT VARCHAR2,
    x_return_status       OUT VARCHAR2,
    x_wf_return_message   OUT VARCHAR2
  );

  PROCEDURE handle_site_lock(
    p_cust_site_rec       IN OUT frm_customer_site_rec,
    x_return_status       OUT VARCHAR2,                                                                        
    x_return_message      OUT VARCHAR2    
  );

  PROCEDURE handle_contacts(  
    p_cust_contact_rec    IN OUT customer_contact_rec,
    x_return_message      OUT VARCHAR2,
    x_return_status       OUT VARCHAR2
  );
  
  PROCEDURE frm_handle_contacts(  
    p_new_contact_flag    IN VARCHAR2,
    p_cust_contact_rec    IN OUT frm_customer_contact_rec,
    x_return_message      OUT VARCHAR2,
    x_return_status       OUT VARCHAR2
  ); 
  
  PROCEDURE handle_contact_lock(
    p_customer_contact_rec  IN OUT frm_customer_contact_rec,
    x_return_status         OUT VARCHAR2,                                                                        
    x_return_message        OUT VARCHAR2    
  );  

END xxhz_api_pkg;
/

SHOW ERRORS