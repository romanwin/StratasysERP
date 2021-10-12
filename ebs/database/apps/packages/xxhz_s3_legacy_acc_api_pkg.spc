CREATE OR REPLACE PACKAGE xxhz_s3_legacy_acc_api_pkg AUTHID CURRENT_USER IS

  -- Author  : 547746
  -- Created : 06/20/2016
  -- Purpose :

  -- Author  : 547746
  -- Created : 06/20/2016
  -- Purpose : Stratasys AR Customers Data Conversion Program
  /******************************************************************************************************************************************
  * Type                : Package                                                                                                          *
  * Conversion Name     : AR_CUSTOMERS                                                                                                     *
  * Name                : XXAR_CUST_CONV_PKG                                                                                           *
  * Script Name         : XXAR_CUST_CONV_PKG.pks                                                                                       *
  * Procedures          :                                                                                 *
                                                                                                                                           *
                                                                                                                                           *
  * Purpose             : This script is used to create Package "XXHYT_AR_CUST_CONV_PKG" in APPS schema,                                   *
                                                                                *
  * HISTORY                                                                                                                                *
  * =======                                                                                                                                *
  * VERSION  DATE         AUTHOR(S)           DESCRIPTION                                                                                       *
  * -------  -----------  ---------------     ---------------------                                                              *
  *1.00      08/04/2016   Rohan Mukherjee     Draft version                                                                                        *
  ******************************************************************************************************************************************/

  --- Global Varialbe Declaration .

  g_num_run_id NUMBER;

  /******************************************************************************************************************
  * Type                : Procedure                                                                                *
  * Name                : XXAR_CUST_MAIN_PRC                                                                      *
  * Input Parameters    :                                                                                          *
  * Purpose             : This procedure is used for running the extraction,transformation,validation              *
                and load procedures by running this procedure alone.                                               *
  ******************************************************************************************************************/

  /******************************************************************************************************************
  * Type                : Procedure                                                                                 *
  * Name                : XXAR_CUST_ORG_PRC                                                                         *
  * Input Parameters    :                                                                                           *
  * Purpose             : This procedure is used for creating Organization                                          *
  ******************************************************************************************************************/
  PROCEDURE create_person(p_person_record IN hz_party_v2pub.person_rec_type,
                          p_party_id      OUT NUMBER,
                          p_api_status    OUT VARCHAR2,
                          p_error_msg     OUT VARCHAR2);

  PROCEDURE update_person(p_person_record IN hz_party_v2pub.person_rec_type,
                          p_obj_version   IN NUMBER,
                          p_api_status    OUT VARCHAR2,
                          p_error_msg     OUT VARCHAR2);

  PROCEDURE create_organization(p_organization_record IN hz_party_v2pub.organization_rec_type,
                                p_party_id            OUT NUMBER,
                                p_return_status       OUT VARCHAR2,
                                p_api_status          OUT VARCHAR2,
                                p_error_msg           OUT VARCHAR2);

  PROCEDURE update_organization(p_organization_record   IN hz_party_v2pub.organization_rec_type,
                                p_party_obj_version_num IN NUMBER,
                                p_api_status            OUT VARCHAR2,
                                p_error_msg             OUT VARCHAR2);

  PROCEDURE create_location(p_location_record IN hz_location_v2pub.location_rec_type,
                            p_location_id     OUT NUMBER,
                            p_api_status      OUT VARCHAR2,
                            p_error_msg       OUT VARCHAR2);

  /*PROCEDURE create_party_site(p_party_site_record IN hz_party_site_v2pub.party_site_rec_type,
  p_api_status        OUT VARCHAR2,
  p_error_msg         OUT VARCHAR2);*/

  PROCEDURE create_account(p_org_record          IN hz_party_v2pub.organization_rec_type,
                           p_cust_account_record IN hz_cust_account_v2pub.cust_account_rec_type,
                           p_cust_prof_record    IN hz_customer_profile_v2pub.customer_profile_rec_type,
                           p_cust_account_id     OUT NUMBER,
                           p_api_status          OUT VARCHAR2,
                           p_error_msg           OUT VARCHAR2);

  PROCEDURE update_account(p_cust_account_record     IN hz_cust_account_v2pub.cust_account_rec_type,
                           p_cust_prof_record        IN hz_customer_profile_v2pub.customer_profile_rec_type,
                           p_account_obj_version_num IN NUMBER,
                           p_api_status              OUT VARCHAR2,
                           p_error_msg               OUT VARCHAR2);

  PROCEDURE update_cust_profile(p_cust_prof_record IN hz_customer_profile_v2pub.customer_profile_rec_type);

  PROCEDURE update_cust_profile_amt(p_cust_prof_amt_record IN hz_customer_profile_v2pub.cust_profile_amt_rec_type);

  PROCEDURE create_contact_point(p_contact_point_record IN hz_contact_point_v2pub.contact_point_rec_type,
                                 p_edi_record           IN hz_contact_point_v2pub.edi_rec_type,
                                 p_email_record         IN hz_contact_point_v2pub.email_rec_type,
                                 p_phone_record         IN hz_contact_point_v2pub.phone_rec_type,
                                 p_telex_record         IN hz_contact_point_v2pub.telex_rec_type,
                                 p_web_record           IN hz_contact_point_v2pub.web_rec_type,
                                 p_obj_versio           IN NUMBER,
                                 p_contact_point_id     OUT NUMBER,
                                 p_api_status           OUT VARCHAR2,
                                 p_error_msg            OUT VARCHAR2);

  PROCEDURE update_contact_point(p_contact_point_record IN hz_contact_point_v2pub.contact_point_rec_type,
                                 p_edi_record           IN hz_contact_point_v2pub.edi_rec_type,
                                 p_email_record         IN hz_contact_point_v2pub.email_rec_type,
                                 p_phone_record         IN hz_contact_point_v2pub.phone_rec_type,
                                 p_telex_record         IN hz_contact_point_v2pub.telex_rec_type,
                                 p_web_record           IN hz_contact_point_v2pub.web_rec_type,
                                 p_obj_version          IN NUMBER,
                                 p_api_status           OUT VARCHAR2,
                                 p_error_msg            OUT VARCHAR2);

  PROCEDURE create_contact(p_contact_record        IN hz_party_contact_v2pub.org_contact_rec_type,
                           p_relationship_party_id OUT NUMBER,
                           p_org_contact_id        OUT NUMBER,
                           p_api_status            OUT VARCHAR2,
                           p_error_msg             OUT VARCHAR2);

  PROCEDURE update_contact(p_contact_record           IN hz_party_contact_v2pub.org_contact_rec_type,
                           p_contact_obj_version_num  IN NUMBER,
                           p_relation_obj_version_num IN NUMBER,
                           p_party_obj_version_num    IN NUMBER,
                           p_api_status               OUT VARCHAR2,
                           p_error_msg                OUT VARCHAR2);

  PROCEDURE create_account_role(p_cust_account_role_record IN OUT hz_cust_account_role_v2pub.cust_account_role_rec_type,
                                p_relationship_party_id    IN NUMBER,
                                p_cust_account_role_id     OUT NUMBER,
                                p_api_status               OUT VARCHAR2,
                                p_error_msg                OUT VARCHAR2);
  PROCEDURE update_account_role(p_cust_account_role_record IN OUT hz_cust_account_role_v2pub.cust_account_role_rec_type,
                                p_obj_version_num          IN OUT NUMBER,
                                p_api_status               OUT VARCHAR2,
                                p_error_msg                OUT VARCHAR2);
  PROCEDURE create_role_responsibility(p_role_responsibility_record IN OUT hz_cust_account_role_v2pub.role_responsibility_rec_type,
                                       p_responsibility_id          OUT NUMBER,
                                       p_api_status                 OUT VARCHAR2,
                                       p_error_msg                  OUT VARCHAR2);
  PROCEDURE update_role_responsibility(p_role_responsibility_record IN OUT hz_cust_account_role_v2pub.role_responsibility_rec_type,
                                       p_object_version_num         OUT NUMBER,
                                       p_api_status                 OUT VARCHAR2,
                                       p_error_msg                  OUT VARCHAR2);
  PROCEDURE create_party_relationship(p_party_relationship_record IN OUT hz_relationship_v2pub.relationship_rec_type,
                                      p_relationship_id           OUT NUMBER,
                                      p_api_status                OUT VARCHAR2,
                                      p_error_msg                 OUT VARCHAR2);

  PROCEDURE update_party_relationship(p_party_relationship_record IN OUT hz_relationship_v2pub.relationship_rec_type,
                                      p_api_status                OUT VARCHAR2,
                                      p_error_msg                 OUT VARCHAR2);

  PROCEDURE create_account_relationship(p_cust_account_relate_record IN hz_cust_account_v2pub.cust_acct_relate_rec_type,
                                        p_cust_acct_relate_id        OUT NUMBER,
                                        p_api_status                 OUT VARCHAR2,
                                        p_error_msg                  OUT VARCHAR2);

  PROCEDURE update_account_relationship(p_cust_account_relate_record IN hz_cust_account_v2pub.cust_acct_relate_rec_type,
                                        p_api_status                 OUT VARCHAR2,
                                        p_error_msg                  OUT VARCHAR2);

  PROCEDURE create_acct_site(p_cust_acct_site_rec IN hz_cust_account_site_v2pub.cust_acct_site_rec_type,
                             p_cust_acct_site_id  OUT NUMBER,
                             p_api_status         OUT VARCHAR2,
                             p_error_msg          OUT VARCHAR2);

  PROCEDURE update_acct_site(p_cust_acct_site_rec    IN hz_cust_account_site_v2pub.cust_acct_site_rec_type,
                             p_object_version_number IN OUT NOCOPY NUMBER,
                             p_api_status            OUT VARCHAR2,
                             p_error_msg             OUT VARCHAR2);

  PROCEDURE create_acct_site_use(p_cust_site_use_rec IN hz_cust_account_site_v2pub.cust_site_use_rec_type,
                                 p_site_use_id       OUT NUMBER,
                                 p_api_status        OUT VARCHAR2,
                                 p_error_msg         OUT VARCHAR2);

  PROCEDURE update_acct_site_use(p_cust_site_use_rec     IN hz_cust_account_site_v2pub.cust_site_use_rec_type,
                                 p_object_version_number IN OUT NOCOPY NUMBER,
                                 p_api_status            OUT VARCHAR2,
                                 p_error_msg             OUT VARCHAR2);

  /*PROCEDURE create_loc(p_location_rec IN hz_location_v2pub.location_rec_type,
  p_location_id  OUT NUMBER,
  p_api_status   OUT VARCHAR2,
  p_error_msg    OUT VARCHAR2);*/
  PROCEDURE update_loc(p_location_rec          IN hz_location_v2pub.location_rec_type,
                       p_object_version_number IN OUT NOCOPY NUMBER,
                       p_api_status            OUT VARCHAR2,
                       p_error_msg             OUT VARCHAR2);
  PROCEDURE create_party_site(p_party_site_rec    IN hz_party_site_v2pub.party_site_rec_type,
                              p_party_site_id     OUT NUMBER,
                              p_party_site_number OUT VARCHAR2);

  PROCEDURE update_party_sites(p_party_site_rec     IN hz_party_site_v2pub.party_site_rec_type,
                               p_object_version_num IN NUMBER,
                               p_api_status         OUT VARCHAR2,
                               p_error_msg          OUT VARCHAR2);
END xxhz_s3_legacy_acc_api_pkg;
/

