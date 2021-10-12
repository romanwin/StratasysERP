CREATE OR REPLACE PACKAGE BODY xxhz_s3_legacy_acc_api_pkg IS
  g_num_user_id        NUMBER := apps.fnd_global.user_id;
  g_num_application_id NUMBER := apps.fnd_global.resp_appl_id;
  g_num_resp_id        NUMBER := apps.fnd_global.resp_id;
  -- Created : 08/09/2016 2:37:10 PM
  -- Purpose : Stratasys Customer Interim Solution

  /******************************************************************************************************************************************
  * Type                : Package                                                                                                          *
  * Module Name         : AR_CUSTOMERS                                                                                                     *
  * Name                : xxhz_s3_legacy_acc_api_pkg                                                                                           *
  * Script Name         : xxhz_s3_legacy_acc_api_pkg.pks                                                                                       *
  * Procedure           : 1.create_person                                                                                             *
                          2.update_person
                          3.create_organization
                          4.update_organization
                          5.create_account
                          6.update_account
                          7.create_contact_point
                          8.update_contact_point
                          9.create_contact
                          10.update_contact
                          11.create_account_role
                          12.create_party_relationship
                          13.update_party_relationship
                          14.create_account_relationship
                          15.update_account_relationship                                                                                                                 *                                                                                                                                            *
  * Purpose             : This script is used to create Package "XXSSYS_S3_LEGACY_INT_PKG" in APPS schema,                                   *
                                                                                                                                           *
  * HISTORY                                                                                                                                *
  * =======                                                                                                                                *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                       *
  * -------  ----------- ---------------    ------------------------------------                                                              *
  * 1.00     08/09/2016  TCS               Draft version                                                                                     *
  ******************************************************************************************************************************************/

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_person                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_party_v2pub.create_person api to create Person in
                           Legacy system with the same data of S3 environment. This api will populate all the
                           person data to the Legacy system                                                                                                             *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/
  PROCEDURE create_person(p_person_record IN hz_party_v2pub.person_rec_type,
                          p_party_id      OUT NUMBER,
                          p_api_status    OUT VARCHAR2,
                          p_error_msg     OUT VARCHAR2) IS
    l_new_subject_id NUMBER;
    l_party_number   hz_parties.party_number%TYPE;
    l_profile_id     NUMBER;
    l_return_status  VARCHAR2(10);
    l_msg_count      NUMBER;
    l_msg_data       VARCHAR2(1000);
    l_error_msg      VARCHAR2(4000);
  BEGIN
    hz_party_v2pub.create_person(p_person_rec    => p_person_record,
                                 x_party_id      => l_new_subject_id,
                                 x_party_number  => l_party_number,
                                 x_profile_id    => l_profile_id,
                                 x_return_status => l_return_status,
                                 x_msg_count     => l_msg_count,
                                 x_msg_data      => l_msg_data);
    p_party_id   := l_new_subject_id;
    p_api_status := l_return_status;
    IF l_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'l_party_id = ' || p_party_id || ' Party Number=' || l_party_number);
      fnd_file.put_line(fnd_file.log,
                        'Create person l_return_status = ' || l_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'l_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'l_msg_data = ' || l_msg_data);
    END IF;
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      
      END LOOP;
    END IF;
    p_error_msg := l_msg_data;
  END create_person;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : update_person                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_party_v2pub.update_person api to update the Person in
                           Legacy system with the same data of S3 environment. This api will populate all the
                           updated person data to the Legacy system                                                                                                       *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/
  PROCEDURE update_person(p_person_record IN hz_party_v2pub.person_rec_type,
                          p_obj_version   IN NUMBER,
                          p_api_status    OUT VARCHAR2,
                          p_error_msg     OUT VARCHAR2) IS
    l_profile_id         NUMBER;
    l_return_status      VARCHAR2(10);
    l_msg_count          NUMBER;
    l_msg_data           VARCHAR2(1000);
    l_error_msg          VARCHAR2(4000);
    l_obj_version_number NUMBER;
  BEGIN
    l_obj_version_number := p_obj_version;
    hz_party_v2pub.update_person(p_person_rec                  => p_person_record,
                                 p_party_object_version_number => l_obj_version_number,
                                 x_profile_id                  => l_profile_id,
                                 x_return_status               => l_return_status,
                                 x_msg_count                   => l_msg_count,
                                 x_msg_data                    => l_msg_data);
  
    p_api_status := l_return_status;
    IF l_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Update Person l_return_status = ' || l_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'l_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'l_msg_data = ' || l_msg_data);
    END IF;
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := l_msg_data;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Unexpected error in Update person' || SQLERRM);
  END update_person;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_organization                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_party_v2pub.create_organization api to create the party type
                           organization in Legacy system with the same data of S3 environment. This api will create all the
                           Organization type party data to the Legacy system collected through the xxhz_acct_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE create_organization(p_organization_record IN hz_party_v2pub.organization_rec_type,
                                p_party_id            OUT NUMBER,
                                p_return_status       OUT VARCHAR2,
                                p_api_status          OUT VARCHAR2,
                                p_error_msg           OUT VARCHAR2) IS
    l_return_status VARCHAR2(255) := 'N';
    l_msg_count     NUMBER(22);
    l_msg_data      VARCHAR2(255);
    l_error_msg     VARCHAR2(4000);
    l_party_id      NUMBER(22);
    l_party_number  VARCHAR2(255);
    l_profile_id    NUMBER(22);
    x_party_id      hz_parties.party_id%TYPE;
    x_party_number  NUMBER;
  
    x_return_status VARCHAR2(255) := 'N';
    x_msg_count     NUMBER;
    x_msg_data      VARCHAR2(255);
    e_finding_cust_accnt_id EXCEPTION;
  
  BEGIN
    hz_party_v2pub.create_organization(p_organization_rec => p_organization_record,
                                       x_return_status    => l_return_status,
                                       x_msg_count        => l_msg_count,
                                       x_msg_data         => l_msg_data,
                                       x_party_id         => l_party_id,
                                       x_party_number     => l_party_number,
                                       x_profile_id       => l_profile_id);
    p_return_status := l_return_status;
    p_api_status    := l_return_status;
    p_party_id      := l_party_id;
    IF l_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'l_party_id = ' || p_party_id || ' Party Number=' || l_party_number);
      fnd_file.put_line(fnd_file.log,
                        'Create organization l_return_status = ' || l_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'l_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'l_msg_data = ' || l_msg_data);
    END IF;
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := l_msg_data;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Unexpected error ' || SQLERRM);
  END create_organization;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : update_organization                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_party_v2pub.update_organization api to update
                           organization type party in Legacy system with the same data of S3 environment. This api will update all the
                           Organization type party data to the Legacy system collected through the xxhz_acct_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE update_organization(p_organization_record   IN hz_party_v2pub.organization_rec_type,
                                p_party_obj_version_num IN NUMBER,
                                p_api_status            OUT VARCHAR2,
                                p_error_msg             OUT VARCHAR2) IS
    l_return_status         VARCHAR2(10);
    l_msg_count             NUMBER;
    l_msg_data              VARCHAR2(1000);
    x_profile_id            NUMBER;
    l_error_msg             VARCHAR2(4000);
    l_party_obj_version_num NUMBER := p_party_obj_version_num;
  BEGIN
    hz_party_v2pub.update_organization(p_organization_rec            => p_organization_record,
                                       p_party_object_version_number => l_party_obj_version_num,
                                       x_profile_id                  => x_profile_id,
                                       x_return_status               => l_return_status,
                                       x_msg_count                   => l_msg_count,
                                       x_msg_data                    => l_msg_data);
  
    p_api_status := l_return_status;
    IF l_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Update organization l_return_status = ' || l_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'l_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'l_msg_data = ' || l_msg_data);
    END IF;
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := l_msg_data;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Unexpected error ' || SQLERRM);
  END update_organization;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_account                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the HZ_LOCATION_V2PUB.CREATE_LOCATION api to create party location
                           in Legacy system with the same data of S3 environment. This api will create the
                           party location to the Legacy system collected through the  xxhz_contact_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/
  PROCEDURE create_location(p_location_record IN hz_location_v2pub.location_rec_type,
                            p_location_id     OUT NUMBER,
                            p_api_status      OUT VARCHAR2,
                            p_error_msg       OUT VARCHAR2) IS
    l_location_id   NUMBER;
    l_return_status VARCHAR2(10);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(1000);
  BEGIN
    hz_location_v2pub.create_location(p_init_msg_list => fnd_api.g_true,
                                      p_location_rec  => p_location_record,
                                      x_location_id   => l_location_id,
                                      x_return_status => l_return_status,
                                      x_msg_count     => l_msg_count,
                                      x_msg_data      => l_msg_data);
    p_location_id := l_location_id;
    p_api_status  := l_return_status;
    IF l_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Creating Location...');
      fnd_file.put_line(fnd_file.log,
                        'l_return_status = ' || l_return_status);
      fnd_file.put_line(fnd_file.log,
                        'l_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'l_msg_data = ' || l_msg_data);
    END IF;
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
      END LOOP;
    END IF;
    p_error_msg := l_msg_data;
  END create_location;
  /*PROCEDURE create_party_site(p_party_site_record IN hz_party_site_v2pub.party_site_rec_type,
                              p_api_status        OUT VARCHAR2,
                              p_error_msg         OUT VARCHAR2) IS
    x_party_site_id     NUMBER;
    x_party_site_number hz_party_sites.party_site_number%TYPE;
    l_return_status     VARCHAR2(10);
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(1000);
  BEGIN
    hz_party_site_v2pub.create_party_site(p_init_msg_list     => 'T',
                                          p_party_site_rec    => p_party_site_record,
                                          x_party_site_id     => x_party_site_id,
                                          x_party_site_number => x_party_site_number,
                                          x_return_status     => l_return_status,
                                          x_msg_count         => l_msg_count,
                                          x_msg_data          => l_msg_data);
    IF l_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Creating Party Site...');
      fnd_file.put_line(fnd_file.log,
                        'l_return_status = ' || l_return_status);
      fnd_file.put_line(fnd_file.log,
                        'l_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'l_msg_data = ' || l_msg_data);
    END IF;
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
      END LOOP;
    END IF;
    p_error_msg := l_msg_data;
  END create_party_site;*/
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_account                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_cust_account_v2pub.create_cust_account api to create customer account
                           in Legacy system with the same data of S3 environment. This api will create the
                           customer account to the Legacy system collected through the xxhz_acct_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE create_account(p_org_record          IN hz_party_v2pub.organization_rec_type,
                           p_cust_account_record IN hz_cust_account_v2pub.cust_account_rec_type,
                           p_cust_prof_record    IN hz_customer_profile_v2pub.customer_profile_rec_type,
                           p_cust_account_id     OUT NUMBER,
                           p_api_status          OUT VARCHAR2,
                           p_error_msg           OUT VARCHAR2) IS
  
    l_error_msg       VARCHAR2(4000);
    x_cust_account_id hz_cust_accounts_all.cust_account_id%TYPE;
    x_account_number  hz_cust_accounts_all.account_number%TYPE;
  
    x_party_id      hz_parties.party_id%TYPE;
    x_party_number  NUMBER;
    x_profile_id    NUMBER;
    x_return_status VARCHAR2(255) := 'N';
    x_msg_count     NUMBER;
    x_msg_data      VARCHAR2(255);
  
  BEGIN
    hz_cust_account_v2pub.create_cust_account(p_init_msg_list        => fnd_api.g_true,
                                              p_cust_account_rec     => p_cust_account_record,
                                              p_organization_rec     => p_org_record,
                                              p_customer_profile_rec => p_cust_prof_record,
                                              p_create_profile_amt   => fnd_api.g_true,
                                              x_cust_account_id      => x_cust_account_id,
                                              x_account_number       => x_account_number,
                                              x_party_id             => x_party_id,
                                              x_party_number         => x_party_number,
                                              x_profile_id           => x_profile_id,
                                              x_return_status        => x_return_status,
                                              x_msg_count            => x_msg_count,
                                              x_msg_data             => x_msg_data);
  
    p_cust_account_id := x_cust_account_id;
    p_api_status      := x_return_status;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'party id ' || x_party_id);
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := x_msg_data;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Unexpected error ' || SQLERRM);
  END create_account;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : update_account                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_cust_account_v2pub.update_cust_account api to update
                           customer account in Legacy system with the same data of S3 environment. This api will update
                           the customer account to the Legacy system collected through the xxhz_acct_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE update_account(p_cust_account_record     IN hz_cust_account_v2pub.cust_account_rec_type,
                           p_cust_prof_record        IN hz_customer_profile_v2pub.customer_profile_rec_type,
                           p_account_obj_version_num IN NUMBER,
                           p_api_status              OUT VARCHAR2,
                           p_error_msg               OUT VARCHAR2) IS
    l_account_obj_version_num NUMBER;
    l_error_msg               VARCHAR2(4000);
    l_return_status           VARCHAR2(10);
    l_msg_count               NUMBER;
    l_msg_data                VARCHAR2(1000);
  BEGIN
    SELECT object_version_number
      INTO l_account_obj_version_num
      FROM hz_cust_accounts_all
     WHERE cust_account_id = p_cust_account_record.cust_account_id;
    hz_cust_account_v2pub.update_cust_account(p_init_msg_list         => fnd_api.g_true,
                                              p_cust_account_rec      => p_cust_account_record,
                                              p_object_version_number => l_account_obj_version_num,
                                              x_return_status         => l_return_status,
                                              x_msg_count             => l_msg_count,
                                              x_msg_data              => l_msg_data);
    p_api_status := l_return_status;
    IF l_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Update account l_return_status = ' || l_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'l_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'l_msg_data = ' || l_msg_data);
    END IF;
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    
    END IF;
    p_error_msg := l_msg_data;
    update_cust_profile(p_cust_prof_record);
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Unexpected error in update account api call package ' || SQLERRM);
  END update_account;
  PROCEDURE update_cust_profile(p_cust_prof_record IN hz_customer_profile_v2pub.customer_profile_rec_type) IS
    l_object_version_number NUMBER;
    l_return_status         VARCHAR2(10);
    l_msg_count             NUMBER;
    l_msg_data              VARCHAR2(1000);
  BEGIN
    SELECT object_version_number
      INTO l_object_version_number
      FROM hz_customer_profiles
     WHERE cust_account_profile_id = p_cust_prof_record.cust_account_profile_id
       AND site_use_id IS NULL;
    hz_customer_profile_v2pub.update_customer_profile(p_init_msg_list         => 'T',
                                                      p_customer_profile_rec  => p_cust_prof_record,
                                                      p_object_version_number => l_object_version_number,
                                                      x_return_status         => l_return_status,
                                                      x_msg_count             => l_msg_count,
                                                      x_msg_data              => l_msg_data);
    IF l_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Updating account Profile...');
      fnd_file.put_line(fnd_file.log,
                        'l_return_status = ' || l_return_status);
      fnd_file.put_line(fnd_file.log,
                        'l_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'l_msg_data = ' || l_msg_data);
    END IF;
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
      END LOOP;
    
    END IF;
  END update_cust_profile;
  PROCEDURE update_cust_profile_amt(p_cust_prof_amt_record IN hz_customer_profile_v2pub.cust_profile_amt_rec_type) IS
    l_obj_version   NUMBER;
    l_return_status VARCHAR2(10);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(1000);
  BEGIN
    BEGIN
      SELECT object_version_number
        INTO l_obj_version
        FROM hz_cust_profile_amts
       WHERE cust_acct_profile_amt_id = p_cust_prof_amt_record.cust_acct_profile_amt_id
         AND site_use_id IS NULL;
    EXCEPTION
      WHEN OTHERS THEN
        l_obj_version := 1;
    END;
    hz_customer_profile_v2pub.update_cust_profile_amt(p_init_msg_list         => 'T',
                                                      p_cust_profile_amt_rec  => p_cust_prof_amt_record,
                                                      p_object_version_number => l_obj_version,
                                                      x_return_status         => l_return_status,
                                                      x_msg_count             => l_msg_count,
                                                      x_msg_data              => l_msg_data);
    IF l_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Updating account Profile Amounts...');
      fnd_file.put_line(fnd_file.log,
                        'l_return_status = ' || l_return_status);
      fnd_file.put_line(fnd_file.log,
                        'l_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'l_msg_data = ' || l_msg_data);
    END IF;
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
      END LOOP;
    
    END IF;
  END update_cust_profile_amt;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_contact_point                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_contact_point_v2pub.create_contact_point api to create
                           contact point in Legacy system with the same data of S3 environment. This api will create
                           the contact point to the Legacy system collected through the xxhz_contact_pnt_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE create_contact_point(p_contact_point_record IN hz_contact_point_v2pub.contact_point_rec_type,
                                 p_edi_record           IN hz_contact_point_v2pub.edi_rec_type,
                                 p_email_record         IN hz_contact_point_v2pub.email_rec_type,
                                 p_phone_record         IN hz_contact_point_v2pub.phone_rec_type,
                                 p_telex_record         IN hz_contact_point_v2pub.telex_rec_type,
                                 p_web_record           IN hz_contact_point_v2pub.web_rec_type,
                                 p_obj_versio           IN NUMBER,
                                 p_contact_point_id     OUT NUMBER,
                                 p_api_status           OUT VARCHAR2,
                                 p_error_msg            OUT VARCHAR2) IS
    x_return_status         VARCHAR2(20);
    x_msg_count             NUMBER;
    x_msg_data              VARCHAR2(2000);
    x_contact_point_id      NUMBER;
    l_error_msg             VARCHAR2(4000);
    l_num_user_id           NUMBER := fnd_global.user_id;
    l_num_responsibility_id NUMBER := apps.fnd_global.resp_appl_id;
    l_num_applicaton_id     NUMBER := apps.fnd_global.resp_id;
    l_conc_request_id       NUMBER := fnd_global.conc_request_id;
    l_num_user_id           NUMBER := fnd_global.user_id;
    l_num_responsibility_id NUMBER := fnd_global.resp_id;
    l_num_applicaton_id     NUMBER := fnd_global.resp_appl_id;
    l_conc_request_id       NUMBER := fnd_global.conc_request_id;
    e_finding_cust_accnt_id EXCEPTION;
  
  BEGIN
  
    fnd_global.apps_initialize(user_id      => g_num_user_id,
                               resp_id      => g_num_resp_id,
                               resp_appl_id => g_num_application_id);
  
    hz_contact_point_v2pub.create_contact_point(p_init_msg_list     => 'T',
                                                p_contact_point_rec => p_contact_point_record,
                                                p_edi_rec           => p_edi_record,
                                                p_email_rec         => p_email_record,
                                                p_phone_rec         => p_phone_record,
                                                p_telex_rec         => p_telex_record,
                                                p_web_rec           => p_web_record,
                                                x_contact_point_id  => x_contact_point_id,
                                                x_return_status     => x_return_status,
                                                x_msg_count         => x_msg_count,
                                                x_msg_data          => x_msg_data);
    p_api_status       := x_return_status;
    p_contact_point_id := x_contact_point_id;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        substr('Create Contact Point l_return_status = ' || x_return_status,
                               1,
                               255));
    
      fnd_file.put_line(fnd_file.log,
                        'l_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'l_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := x_msg_data;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Unexpected error ' || SQLERRM);
  END create_contact_point;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : update_contact_point                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_contact_point_v2pub.update_contact_point api to update
                           contact point in Legacy system with the same data of S3 environment. This api will update
                           the contact point to the Legacy system collected through the xxhz_contact_pnt_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE update_contact_point(p_contact_point_record IN hz_contact_point_v2pub.contact_point_rec_type,
                                 p_edi_record           IN hz_contact_point_v2pub.edi_rec_type,
                                 p_email_record         IN hz_contact_point_v2pub.email_rec_type,
                                 p_phone_record         IN hz_contact_point_v2pub.phone_rec_type,
                                 p_telex_record         IN hz_contact_point_v2pub.telex_rec_type,
                                 p_web_record           IN hz_contact_point_v2pub.web_rec_type,
                                 p_obj_version          IN NUMBER,
                                 p_api_status           OUT VARCHAR2,
                                 p_error_msg            OUT VARCHAR2) IS
    l_object_version_number NUMBER;
    x_return_status         VARCHAR2(20);
    x_msg_data              VARCHAR2(2000);
    x_msg_count             NUMBER;
    l_error_msg             VARCHAR2(4000);
  BEGIN
    fnd_global.apps_initialize(user_id      => g_num_user_id,
                               resp_id      => g_num_resp_id,
                               resp_appl_id => g_num_application_id);
    l_object_version_number := p_obj_version;
    hz_contact_point_v2pub.update_contact_point(p_init_msg_list         => 'T',
                                                p_contact_point_rec     => p_contact_point_record,
                                                p_edi_rec               => p_edi_record,
                                                p_email_rec             => p_email_record,
                                                p_phone_rec             => p_phone_record,
                                                p_telex_rec             => p_telex_record,
                                                p_web_rec               => p_web_record,
                                                p_object_version_number => l_object_version_number,
                                                x_return_status         => x_return_status,
                                                x_msg_count             => x_msg_count,
                                                x_msg_data              => x_msg_data);
  
    p_api_status := x_return_status;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Update Contact Point l_return_status = ' || x_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'l_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'l_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    
    END IF;
    p_error_msg := x_msg_data;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Unexpected error ' || SQLERRM);
  END update_contact_point;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_contact                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_party_contact_v2pub.create_org_contact api to Create
                           contact at organization level in Legacy system with the same data of S3 environment. This api will create
                           the contact to the Legacy system collected through the xxhz_contact_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE create_contact(p_contact_record        IN hz_party_contact_v2pub.org_contact_rec_type,
                           p_relationship_party_id OUT NUMBER,
                           p_org_contact_id        OUT NUMBER,
                           p_api_status            OUT VARCHAR2,
                           p_error_msg             OUT VARCHAR2) IS
    x_org_contact_id NUMBER;
    x_party_rel_id   NUMBER;
    x_party_id       NUMBER;
    x_party_number   NUMBER;
    x_return_status  VARCHAR2(10);
    x_msg_count      NUMBER;
    x_msg_data       VARCHAR2(2000);
    l_error_msg      VARCHAR2(4000);
  
  BEGIN
    fnd_global.apps_initialize(user_id      => g_num_user_id,
                               resp_id      => g_num_resp_id,
                               resp_appl_id => g_num_application_id);
  
    hz_party_contact_v2pub.create_org_contact(p_init_msg_list   => 'T',
                                              p_org_contact_rec => p_contact_record,
                                              x_org_contact_id  => x_org_contact_id,
                                              x_party_rel_id    => x_party_rel_id,
                                              x_party_id        => x_party_id,
                                              x_party_number    => x_party_number,
                                              x_return_status   => x_return_status,
                                              x_msg_count       => x_msg_count,
                                              x_msg_data        => x_msg_data);
  
    p_api_status            := x_return_status;
    p_relationship_party_id := x_party_id;
    p_org_contact_id        := x_org_contact_id;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Creating Contact');
      fnd_file.put_line(fnd_file.log,
                        'x_org_contact_id= ' || x_org_contact_id);
      fnd_file.put_line(fnd_file.log,
                        'party id=' || x_party_id);
      fnd_file.put_line(fnd_file.log,
                        'x_party_rel_id= ' || x_party_rel_id);
      fnd_file.put_line(fnd_file.log,
                        'x_party_number= ' || x_party_number);
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    END IF;
    /*IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;*/
    p_error_msg := x_msg_data;
  END create_contact;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : update_contact                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_party_contact_v2pub.update_org_contact api to update the
                           contact in Legacy system with the same data of S3 environment. This api will update
                           the contact to the Legacy system collected through the xxhz_contact_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE update_contact(p_contact_record           IN hz_party_contact_v2pub.org_contact_rec_type,
                           p_contact_obj_version_num  IN NUMBER,
                           p_relation_obj_version_num IN NUMBER,
                           p_party_obj_version_num    IN NUMBER,
                           p_api_status               OUT VARCHAR2,
                           p_error_msg                OUT VARCHAR2) IS
    x_return_status            VARCHAR2(10);
    x_msg_count                NUMBER;
    x_msg_data                 VARCHAR2(2000);
    l_error_msg                VARCHAR2(4000);
    l_contact_obj_version_num  NUMBER := p_contact_obj_version_num;
    l_relation_obj_version_num NUMBER := p_relation_obj_version_num;
    l_party_obj_version_num    NUMBER := p_party_obj_version_num;
  BEGIN
    fnd_global.apps_initialize(user_id      => g_num_user_id,
                               resp_id      => g_num_resp_id,
                               resp_appl_id => g_num_application_id);
    hz_party_contact_v2pub.update_org_contact(p_org_contact_rec             => p_contact_record,
                                              p_cont_object_version_number  => l_contact_obj_version_num,
                                              p_rel_object_version_number   => l_relation_obj_version_num,
                                              p_party_object_version_number => l_party_obj_version_num,
                                              x_return_status               => x_return_status,
                                              x_msg_count                   => x_msg_count,
                                              x_msg_data                    => x_msg_data);
    p_api_status := x_return_status;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    
    END IF;
    p_error_msg := x_msg_data;
  END update_contact;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_account_role                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_cust_account_role_v2pub.create_cust_account_role api to
                           create the contact at account level in Legacy system with the same data of S3 environment.
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE create_account_role(p_cust_account_role_record IN OUT hz_cust_account_role_v2pub.cust_account_role_rec_type,
                                p_relationship_party_id    IN NUMBER,
                                p_cust_account_role_id     OUT NUMBER,
                                p_api_status               OUT VARCHAR2,
                                p_error_msg                OUT VARCHAR2) IS
    x_return_status         VARCHAR2(10);
    x_msg_count             NUMBER;
    l_relationship_party_id NUMBER;
    x_msg_data              VARCHAR2(2000);
    x_cust_account_role_id  NUMBER;
    l_error_msg             VARCHAR2(4000);
  BEGIN
    fnd_global.apps_initialize(user_id      => g_num_user_id,
                               resp_id      => g_num_resp_id,
                               resp_appl_id => g_num_application_id);
  
    BEGIN
    
      p_cust_account_role_record.party_id          := p_relationship_party_id;
      p_cust_account_role_record.role_type         := 'CONTACT';
      p_cust_account_role_record.created_by_module := 'TCA_V1_API';
      hz_cust_account_role_v2pub.create_cust_account_role('T',
                                                          p_cust_account_role_record,
                                                          x_cust_account_role_id,
                                                          x_return_status,
                                                          x_msg_count,
                                                          x_msg_data);
    
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log,
                          'Contact at Account level is not created....');
    END;
    p_cust_account_role_id := x_cust_account_role_id;
    p_api_status           := x_return_status;
    fnd_file.put_line(fnd_file.log,
                      'p_relationship_party_id= ' || p_relationship_party_id);
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Creating Role ...');
    
      fnd_file.put_line(fnd_file.log,
                        'x_cust_account_role_id= ' || x_cust_account_role_id);
    
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := x_msg_data;
  END create_account_role;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : update_account_role                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_cust_account_role_v2pub.update_cust_account_role api to
                           update the contact at account level in Legacy system with the same data of S3 environment.
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE update_account_role(p_cust_account_role_record IN OUT hz_cust_account_role_v2pub.cust_account_role_rec_type,
                                p_obj_version_num          IN OUT NUMBER,
                                p_api_status               OUT VARCHAR2,
                                p_error_msg                OUT VARCHAR2) IS
    x_return_status         VARCHAR2(10);
    x_msg_count             NUMBER;
    l_relationship_party_id NUMBER;
    x_msg_data              VARCHAR2(2000);
    x_cust_account_role_id  NUMBER;
    l_error_msg             VARCHAR2(4000);
  BEGIN
    fnd_global.apps_initialize(user_id      => g_num_user_id,
                               resp_id      => g_num_resp_id,
                               resp_appl_id => g_num_application_id);
  
    BEGIN
      hz_cust_account_role_v2pub.update_cust_account_role('T',
                                                          p_cust_account_role_record,
                                                          p_obj_version_num,
                                                          x_return_status,
                                                          x_msg_count,
                                                          x_msg_data);
    
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log,
                          'Contact at Account level is not Updated....');
    END;
    p_api_status := x_return_status;
  
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Updating Role Error ...');
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := x_msg_data;
  END update_account_role;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_role_responsibility                                                                                               *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_cust_account_role_v2pub.create_role_responsibility api to
                           create the contact role and responsibility in Legacy system with the same data of S3 environment.
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE create_role_responsibility(p_role_responsibility_record IN OUT hz_cust_account_role_v2pub.role_responsibility_rec_type,
                                       p_responsibility_id          OUT NUMBER,
                                       p_api_status                 OUT VARCHAR2,
                                       p_error_msg                  OUT VARCHAR2) IS
    x_responsibility_id NUMBER;
    x_return_status     VARCHAR2(10);
    x_msg_count         NUMBER;
    x_msg_data          VARCHAR2(2000);
    l_error_msg         VARCHAR2(4000);
  BEGIN
    hz_cust_account_role_v2pub.create_role_responsibility('T',
                                                          p_role_responsibility_record,
                                                          x_responsibility_id,
                                                          x_return_status,
                                                          x_msg_count,
                                                          x_msg_data);
    p_api_status := x_return_status;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Creating Role Responsibility error ...');
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := x_msg_data;
  END create_role_responsibility;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : update_role_responsibility                                                                                               *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_cust_account_role_v2pub.create_role_responsibility api to
                           update the contact role and responsibility in Legacy system with the same data of S3 environment.
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE update_role_responsibility(p_role_responsibility_record IN OUT hz_cust_account_role_v2pub.role_responsibility_rec_type,
                                       p_object_version_num         OUT NUMBER,
                                       p_api_status                 OUT VARCHAR2,
                                       p_error_msg                  OUT VARCHAR2) IS
    x_responsibility_id NUMBER;
    x_return_status     VARCHAR2(10);
    x_msg_count         NUMBER;
    x_msg_data          VARCHAR2(2000);
    l_error_msg         VARCHAR2(4000);
  BEGIN
    hz_cust_account_role_v2pub.update_role_responsibility('T',
                                                          p_role_responsibility_record,
                                                          p_object_version_num,
                                                          x_return_status,
                                                          x_msg_count,
                                                          x_msg_data);
    p_api_status := x_return_status;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Updating Role Responsibility error ...');
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := x_msg_data;
  END update_role_responsibility;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_party_relationship                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_relationship_v2pub.create_relationship api to Create
                           party relationship in Legacy system with the same data of S3 environment. This api will create
                           the party relationship to the Legacy system collected through the xxhz_prty_rltion_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE create_party_relationship(p_party_relationship_record IN OUT hz_relationship_v2pub.relationship_rec_type,
                                      p_relationship_id           OUT NUMBER,
                                      p_api_status                OUT VARCHAR2,
                                      p_error_msg                 OUT VARCHAR2) IS
    x_relationship_id NUMBER;
    x_party_id        NUMBER;
    x_party_number    VARCHAR2(100);
    x_return_status   VARCHAR2(10);
    x_msg_count       NUMBER;
    x_msg_data        VARCHAR2(2000);
    l_error_msg       VARCHAR2(4000);
  BEGIN
    p_party_relationship_record.subject_table_name := 'HZ_PARTIES';
    p_party_relationship_record.object_table_name  := 'HZ_PARTIES';
    p_party_relationship_record.created_by_module  := 'TCA_V1_API';
    hz_relationship_v2pub.create_relationship(p_relationship_rec => p_party_relationship_record,
                                              x_relationship_id  => x_relationship_id,
                                              x_party_id         => x_party_id,
                                              x_party_number     => x_party_number,
                                              x_return_status    => x_return_status,
                                              x_msg_count        => x_msg_count,
                                              x_msg_data         => x_msg_data);
  
    p_relationship_id := x_relationship_id;
    p_api_status      := x_return_status;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Creating Party Relationship ...');
    
      fnd_file.put_line(fnd_file.log,
                        'x_relationship_id= ' || x_relationship_id);
    
      fnd_file.put_line(fnd_file.log,
                        'x_party_id = ' || x_party_id);
      fnd_file.put_line(fnd_file.log,
                        'x_party_number = ' || x_party_number);
      fnd_file.put_line(fnd_file.log,
                        'x_return_status= ' || x_return_status);
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := x_msg_data;
  END create_party_relationship;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : update_party_relationship                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_relationship_v2pub.update_relationship api to update
                           party relationship data in Legacy system with the same data of S3 environment. This api will update
                           the party relationship to the Legacy system collected through the xxhz_prty_rltion_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE update_party_relationship(p_party_relationship_record IN OUT hz_relationship_v2pub.relationship_rec_type,
                                      p_api_status                OUT VARCHAR2,
                                      p_error_msg                 OUT VARCHAR2) IS
    l_obj_version_number    NUMBER;
    l_par_version_number    NUMBER;
    l_msg_count             NUMBER;
    l_relationship_party_id NUMBER;
    l_msg_data              VARCHAR2(2000);
    l_return_status         VARCHAR2(10);
    l_error_msg             VARCHAR2(4000);
  BEGIN
    p_party_relationship_record.subject_table_name := 'HZ_PARTIES';
    p_party_relationship_record.object_table_name  := 'HZ_PARTIES';
    BEGIN
      SELECT object_version_number,
             party_id
        INTO l_obj_version_number,
             l_relationship_party_id
        FROM hz_relationships
       WHERE relationship_id = p_party_relationship_record.relationship_id
         AND subject_id = p_party_relationship_record.subject_id
         AND object_id = p_party_relationship_record.object_id
         AND relationship_type = p_party_relationship_record.relationship_type
         AND relationship_code = p_party_relationship_record.relationship_code;
    
      SELECT object_version_number
        INTO l_par_version_number
        FROM hz_parties
       WHERE party_id = l_relationship_party_id;
    
    EXCEPTION
      WHEN OTHERS THEN
        l_obj_version_number := 1;
        l_par_version_number := 1;
        fnd_file.put_line(fnd_file.log,
                          'Error is Fetching object version number in API Package*********** ');
    END;
    hz_relationship_v2pub.update_relationship(p_init_msg_list               => fnd_api.g_false,
                                              p_relationship_rec            => p_party_relationship_record,
                                              p_object_version_number       => l_obj_version_number,
                                              p_party_object_version_number => l_par_version_number,
                                              x_return_status               => l_return_status,
                                              x_msg_count                   => l_msg_count,
                                              x_msg_data                    => l_msg_data);
    p_api_status := l_return_status;
    IF l_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Updating Party Relationship ...');
    
      fnd_file.put_line(fnd_file.log,
                        'l_return_status= ' || l_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'l_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'l_msg_data = ' || l_msg_data);
    END IF;
    IF l_msg_count > 1 THEN
      FOR i IN 1 .. l_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := l_msg_data;
  END update_party_relationship;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : create_account_relationship                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_cust_account_v2pub.create_cust_acct_relate api to Create
                           account relationship in Legacy system with the same data of S3 environment. This api will create
                           the account relationship to the Legacy system collected through the xxhz_acct_relate_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE create_account_relationship(p_cust_account_relate_record IN hz_cust_account_v2pub.cust_acct_relate_rec_type,
                                        p_cust_acct_relate_id        OUT NUMBER,
                                        p_api_status                 OUT VARCHAR2,
                                        p_error_msg                  OUT VARCHAR2) IS
  
    x_msg_count           NUMBER;
    x_return_status       VARCHAR2(10);
    x_msg_data            VARCHAR2(2000);
    x_cust_acct_relate_id NUMBER;
    l_error_msg           VARCHAR2(4000);
  BEGIN
  
    hz_cust_account_v2pub.create_cust_acct_relate(p_cust_acct_relate_rec => p_cust_account_relate_record,
                                                  x_cust_acct_relate_id  => x_cust_acct_relate_id,
                                                  x_return_status        => x_return_status,
                                                  x_msg_count            => x_msg_count,
                                                  x_msg_data             => x_msg_data);
    p_api_status          := x_return_status;
    p_cust_acct_relate_id := x_cust_acct_relate_id;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Error Creating Cust account Relationship ...');
    
      fnd_file.put_line(fnd_file.log,
                        'x_return_status= ' || x_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := x_msg_data;
  END create_account_relationship;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : AR_CUSTOMERS                                                                                                      *
  * Name                : update_account_relationship                                                                                                *
  * Script Name         : XXSSYS_S3_LEGACY_INT_PKG.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the hz_cust_account_v2pub.update_cust_acct_relate api to update
                           account relationship in Legacy system with the same data of S3 environment. This api will update
                           the account relationship to the Legacy system collected through the xxhz_acct_relate_legacy_int_v view
                                                                                                                      *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/09/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE update_account_relationship(p_cust_account_relate_record IN hz_cust_account_v2pub.cust_acct_relate_rec_type,
                                        p_api_status                 OUT VARCHAR2,
                                        p_error_msg                  OUT VARCHAR2) IS
    x_msg_count       NUMBER;
    x_return_status   VARCHAR2(10);
    x_msg_data        VARCHAR2(2000);
    l_obj_version_num NUMBER;
    l_error_msg       VARCHAR2(4000);
  BEGIN
    BEGIN
      SELECT object_version_number
        INTO l_obj_version_num
        FROM hz_cust_acct_relate_all
       WHERE cust_acct_relate_id = p_cust_account_relate_record.cust_acct_relate_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_obj_version_num := 1;
    END;
    hz_cust_account_v2pub.update_cust_acct_relate(p_cust_acct_relate_rec  => p_cust_account_relate_record,
                                                  p_object_version_number => l_obj_version_num,
                                                  x_return_status         => x_return_status,
                                                  x_msg_count             => x_msg_count,
                                                  x_msg_data              => x_msg_data);
    p_api_status := x_return_status;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Updating Cust account Relationship ...');
    
      fnd_file.put_line(fnd_file.log,
                        'x_return_status= ' || x_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        l_error_msg := l_error_msg || chr(10) || i || '. ' ||
                       substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                              1,
                              255);
      END LOOP;
    END IF;
    p_error_msg := x_msg_data;
  END update_account_relationship;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Conversion Name     :                                                                                                                   *
  * Name                : CREATE_ACCT_SITE                                                                                                  *
  * Script Name         : CREATE_ACCT_SITE.prc                                                                                              *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             : This Procedure is Used to Create Account Site in Legacy Environment                                               *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
  * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     16/08/2016  Rohan Mukherjee    Draft version                                                                                   *
  ******************************************************************************************************************************************/
  PROCEDURE create_acct_site(p_cust_acct_site_rec IN hz_cust_account_site_v2pub.cust_acct_site_rec_type,
                             p_cust_acct_site_id  OUT NUMBER,
                             p_api_status         OUT VARCHAR2,
                             p_error_msg          OUT VARCHAR2) IS
  
    -- Local Variable Declaration .
    x_cust_acct_site_id NUMBER;
    x_return_status     VARCHAR2(10);
    x_msg_count         NUMBER;
    x_msg_data          VARCHAR2(4000);
    l_error_msg         VARCHAR2(4000);
  
  BEGIN
    hz_cust_account_site_v2pub.create_cust_acct_site(p_init_msg_list      => 'T',
                                                     p_cust_acct_site_rec => p_cust_acct_site_rec,
                                                     x_cust_acct_site_id  => x_cust_acct_site_id,
                                                     x_return_status      => x_return_status,
                                                     x_msg_count          => x_msg_count,
                                                     x_msg_data           => x_msg_data);
    p_cust_acct_site_id := x_cust_acct_site_id;
    p_api_status        := x_return_status;
    p_error_msg         := x_msg_data;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Creating Cust account site...');
      fnd_file.put_line(fnd_file.log,
                        'x_cust_acct_site_id=' || x_cust_acct_site_id);
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        substr('x_msg_data = ' || x_msg_data,
                               1,
                               255));
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
      END LOOP;
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'Unexpected Error' || SQLERRM;
      fnd_file.put_line(fnd_file.log,
                        l_error_msg);
  END create_acct_site;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Conversion Name     :                                                                                                                   *
  * Name                : UPDATE_ACCT_SITE                                                                                                 *
  * Script Name         : UPDATE_ACCT_SITE.prc                                                                                             *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             : This Procedure is Used to Update Location in S3 Environment if there is Modification                              *
                          of Location Entity in S3 Environment.                                                                             *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
  * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     16/08/2016  Rohan Mukherjee    Draft version                                                                                   *
  ******************************************************************************************************************************************/

  PROCEDURE update_acct_site(p_cust_acct_site_rec    IN hz_cust_account_site_v2pub.cust_acct_site_rec_type,
                             p_object_version_number IN OUT NOCOPY NUMBER,
                             p_api_status            OUT VARCHAR2,
                             p_error_msg             OUT VARCHAR2) IS
  
    -- Local Variable Declaration.
    x_return_status         VARCHAR2(10);
    x_msg_count             NUMBER;
    x_msg_data              VARCHAR2(2000);
    l_object_version_number NUMBER := p_object_version_number;
    l_error_msg             VARCHAR2(4000);
  
  BEGIN
    fnd_global.apps_initialize(user_id      => g_num_user_id,
                               resp_id      => g_num_resp_id,
                               resp_appl_id => g_num_application_id);
  
    hz_cust_account_site_v2pub.update_cust_acct_site(p_init_msg_list         => 'T',
                                                     p_cust_acct_site_rec    => p_cust_acct_site_rec,
                                                     p_object_version_number => l_object_version_number,
                                                     x_return_status         => x_return_status,
                                                     x_msg_count             => x_msg_count,
                                                     x_msg_data              => x_msg_data);
  
    p_api_status := x_return_status;
    p_error_msg  := x_msg_data;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Updating Cust account site...');
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
      END LOOP;
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'Unexpected Error Happened in Updatec API' || SQLERRM;
      fnd_file.put_line(fnd_file.log,
                        l_error_msg);
  END update_acct_site;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Conversion Name     :                                                                                                                   *
  * Name                : CREATE_ACCT_SITE_USE                                                                                              *
  * Script Name         : CREATE_ACCT_SITE_USE.prc                                                                                          *
  *                                                                                                                                         *
                                                                                                                                            *
  * Purpose             : This Procedure is Used to Create Account Site in Legacy Environment.                                              *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
  * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     16/08/2016  Rohan Mukherjee    Draft version                                                                                   *
  ******************************************************************************************************************************************/

  PROCEDURE create_acct_site_use(p_cust_site_use_rec IN hz_cust_account_site_v2pub.cust_site_use_rec_type,
                                 p_site_use_id       OUT NUMBER,
                                 p_api_status        OUT VARCHAR2,
                                 p_error_msg         OUT VARCHAR2) IS
  
    -- Local Variable Declaration .
    x_site_use_id           NUMBER;
    x_return_status         VARCHAR2(10);
    x_msg_count             NUMBER;
    x_msg_data              VARCHAR2(4000);
    l_error_msg             VARCHAR2(4000);
    xx_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;
  
  BEGIN
    hz_cust_account_site_v2pub.create_cust_site_use(p_init_msg_list        => 'T',
                                                    p_cust_site_use_rec    => p_cust_site_use_rec,
                                                    p_customer_profile_rec => xx_customer_profile_rec,
                                                    p_create_profile       => '',
                                                    p_create_profile_amt   => '',
                                                    x_site_use_id          => x_site_use_id,
                                                    x_return_status        => x_return_status,
                                                    x_msg_count            => x_msg_count,
                                                    x_msg_data             => x_msg_data);
  
    p_api_status  := x_return_status;
    p_site_use_id := x_site_use_id;
  
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Creating Cust account Site Use...');
      fnd_file.put_line(fnd_file.log,
                        'x_site_use_id = ' || x_site_use_id);
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
        x_msg_data := x_msg_data || i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                                        1,
                                                        255);
      END LOOP;
    
    END IF;
    p_error_msg := x_msg_data;
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'Unexpected Error' || ' ' || SQLERRM;
      fnd_file.put_line(fnd_file.log,
                        l_error_msg);
    
  END create_acct_site_use;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Conversion Name     :                                                                                                                   *
  * Name                : UPDATE_ACCT_SITE_USE                                                                                              *
  * Script Name         : UPDATE_ACCT_SITE_USE.prc                                                                                          *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             : This Procedure is Used to Update Location in S3 Environment if there is Modification                              *
                          of Location Entity in S3 Environment.                                                                             *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
  * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     16/08/2016  Rohan Mukherjee    Draft version                                                                                   *
  ******************************************************************************************************************************************/

  PROCEDURE update_acct_site_use(p_cust_site_use_rec     IN hz_cust_account_site_v2pub.cust_site_use_rec_type,
                                 p_object_version_number IN OUT NOCOPY NUMBER,
                                 p_api_status            OUT VARCHAR2,
                                 p_error_msg             OUT VARCHAR2) IS
  
    -- Local Variable Declaration
    x_return_status         VARCHAR2(10);
    x_msg_count             NUMBER;
    x_msg_data              VARCHAR2(2000);
    l_object_version_number NUMBER := p_object_version_number;
  
  BEGIN
    fnd_global.apps_initialize(user_id      => g_num_user_id,
                               resp_id      => g_num_resp_id,
                               resp_appl_id => g_num_application_id);
  
    hz_cust_account_site_v2pub.update_cust_site_use(p_init_msg_list         => 'T',
                                                    p_cust_site_use_rec     => p_cust_site_use_rec,
                                                    p_object_version_number => l_object_version_number,
                                                    x_return_status         => x_return_status,
                                                    x_msg_count             => x_msg_count,
                                                    x_msg_data              => x_msg_data);
  
    p_api_status := x_return_status;
    p_error_msg  := x_msg_data;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Updating Cust account Site Use...');
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
      END LOOP;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Unexpected error in update_acct_site_use: ' || SQLERRM);
  END update_acct_site_use;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Conversion Name     :                                                                                                                   *
  * Name                : UPDATE_LOC                                                                                                        *
  * Script Name         : UPDATE_LOC.prc                                                                                                    *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             : This Procedure is Used to Update Location in S3 Environment if there is Modification                              *
                          of Location Entity in S3 Environment.                                                                             *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
  * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     16/08/2016  Rohan Mukherjee    Draft version                                                                                   *
  ******************************************************************************************************************************************/

  PROCEDURE update_loc(p_location_rec          IN hz_location_v2pub.location_rec_type,
                       p_object_version_number IN OUT NOCOPY NUMBER,
                       p_api_status            OUT VARCHAR2,
                       p_error_msg             OUT VARCHAR2)
  
   IS
    -- Local Variable Declaration.
    x_return_status         VARCHAR2(10);
    x_msg_count             NUMBER;
    x_msg_data              VARCHAR2(2000);
    l_object_version_number NUMBER := p_object_version_number;
    l_error_msg             VARCHAR2(4000);
  
  BEGIN
  
    ---------------------------------------------------
    -- Calling Update Location API .
    ---------------------------------------------------
  
    hz_location_v2pub.update_location(p_init_msg_list         => fnd_api.g_false,
                                      p_location_rec          => p_location_rec,
                                      p_object_version_number => l_object_version_number,
                                      x_return_status         => x_return_status,
                                      x_msg_count             => x_msg_count,
                                      x_msg_data              => x_msg_data);
  
    p_api_status := x_return_status;
    p_error_msg  := x_msg_data;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'Updating Location...');
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      END LOOP;
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'Unexpected Error--' || SQLERRM;
      fnd_file.put_line(fnd_file.log,
                        l_error_msg);
    
  END;

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Conversion Name     :                                                                                                                   *
  * Name                : CREATE_PARTY_SITE                                                                                                 *
  * Script Name         : CREATE_PARTY_SITE.prc                                                                                             *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             : This Procedure is Used to Create Party Site in Legacy Environment.                                                *
                                                                                                                                            *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
  * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     16/08/2016  Rohan Mukherjee    Draft version                                                                                   *
  ******************************************************************************************************************************************/

  PROCEDURE create_party_site(p_party_site_rec    IN hz_party_site_v2pub.party_site_rec_type,
                              p_party_site_id     OUT NUMBER,
                              p_party_site_number OUT VARCHAR2)
  
   IS
  
    -- Local Variable Declaration .
    x_party_site_id     NUMBER;
    x_party_site_number VARCHAR2(100);
    x_return_status     VARCHAR2(10);
    x_msg_count         NUMBER;
    x_msg_data          VARCHAR2(4000);
    l_var_error_msg     VARCHAR2(4000);
  BEGIN
  
    hz_party_site_v2pub.create_party_site(p_init_msg_list     => 'T',
                                          p_party_site_rec    => p_party_site_rec,
                                          x_party_site_id     => x_party_site_id,
                                          x_party_site_number => x_party_site_number,
                                          x_return_status     => x_return_status,
                                          x_msg_count         => x_msg_count,
                                          x_msg_data          => x_msg_data);
  
    p_party_site_id     := x_party_site_id;
    p_party_site_number := x_party_site_number;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'x_party_site_id=' || x_party_site_id);
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
      END LOOP;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_var_error_msg := 'Unexpected Error--' || SQLERRM;
      fnd_file.put_line(fnd_file.log,
                        l_var_error_msg);
  END create_party_site;

  PROCEDURE update_party_sites(p_party_site_rec     IN hz_party_site_v2pub.party_site_rec_type,
                               p_object_version_num IN NUMBER,
                               p_api_status         OUT VARCHAR2,
                               p_error_msg          OUT VARCHAR2) IS
    x_return_status   VARCHAR2(10);
    x_msg_count       NUMBER;
    x_msg_data        VARCHAR2(4000);
    l_obj_version_num NUMBER;
  BEGIN
    l_obj_version_num := p_object_version_num;
    hz_party_site_v2pub.update_party_site(p_party_site_rec        => p_party_site_rec,
                                          p_object_version_number => l_obj_version_num,
                                          x_return_status         => x_return_status,
                                          x_msg_count             => x_msg_count,
                                          x_msg_data              => x_msg_data);
    p_api_status := x_return_status;
    p_error_msg  := x_msg_data;
    IF x_return_status <> 'S' THEN
      fnd_file.put_line(fnd_file.log,
                        'x_return_status = ' || x_return_status);
    
      fnd_file.put_line(fnd_file.log,
                        'x_msg_count = ' || to_char(x_msg_count));
      fnd_file.put_line(fnd_file.log,
                        'x_msg_data = ' || x_msg_data);
    END IF;
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      
      END LOOP;
    
    END IF;
  END update_party_sites;
END xxhz_s3_legacy_acc_api_pkg;
/
