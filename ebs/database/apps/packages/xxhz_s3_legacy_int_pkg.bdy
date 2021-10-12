CREATE OR REPLACE PACKAGE xxhz_s3_legacy_int_pkg IS
  ----------------------------------------------------------------------------
  --  name:            xxhz_s3_legacy_int_pkg
  --  create by:       TCS
  --  $Revision:       1.0
  --  creation date:   17/08/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package containing procedure to pull all the customer information(Account,Contact Point,Contact,Relationship)
  --                   from S3 and loading those information to Legacy environment
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  17/08/2016  TCS                    Initial build
  ----------------------------------------------------------------------------

  PROCEDURE pull_account(p_errbuf     OUT VARCHAR2,
                         p_retcode    OUT NUMBER,
                         p_batch_size IN NUMBER);

  PROCEDURE pull_contact_point(p_errbuf     OUT VARCHAR2,
                               p_retcode    OUT NUMBER,
                               p_batch_size IN NUMBER);

  PROCEDURE pull_contact(p_errbuf     OUT VARCHAR2,
                         p_retcode    OUT NUMBER,
                         p_batch_size IN NUMBER);

  PROCEDURE pull_relationship(p_errbuf     OUT VARCHAR2,
                              p_retcode    OUT NUMBER,
                              p_batch_size IN NUMBER);

  PROCEDURE pull_acc_relationship(p_errbuf     OUT VARCHAR2,
                                  p_retcode    OUT NUMBER,
                                  p_batch_size IN NUMBER);

  PROCEDURE pull_acct_site(p_errbuf     OUT VARCHAR2,
                           p_retcode    OUT NUMBER,
                           p_batch_size IN NUMBER);

  PROCEDURE pull_acct_site_use(p_errbuf     OUT VARCHAR2,
                               p_retcode    OUT NUMBER,
                               p_batch_size IN NUMBER);
END xxhz_s3_legacy_int_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxhz_s3_legacy_int_pkg IS
  g_user_id        NUMBER := fnd_global.user_id;
  g_application_id NUMBER := fnd_global.resp_appl_id;
  g_resp_id        NUMBER := fnd_global.resp_id;
  --------------------------------------------------------------------
  --  name:               pull_account
  --  create by:          TCS
  --  $Revision:          1.0
  --  creation date:      17/08/2016
  --- This procedure will collect the account data from  s3 environment and will create or update those
  --  accounts data into Legacy environment through Oracle standard API
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    TCS       initial build
  --------------------------------------------------------------------
  PROCEDURE pull_account(p_errbuf     OUT VARCHAR2,
                         p_retcode    OUT NUMBER,
                         p_batch_size IN NUMBER)
  
   IS
    l_error_msg               VARCHAR2(2000);
    x_err_code                VARCHAR2(100);
    x_api_status              VARCHAR2(10);
    x_api_message             VARCHAR2(4000);
    x_org_creation_status     VARCHAR2(10);
    l_sm_mngr                 per_all_people_f.full_name%TYPE;
    x_cust_account_id         NUMBER;
    l_party_obj_version_num   NUMBER;
    l_collector_id            NUMBER;
    l_price_list_id           NUMBER;
    l_sam_mgr_id              NUMBER;
    l_payment_term_id         NUMBER;
    l_exist_party_id          NUMBER;
    l_cust_account_profile_id NUMBER;
    l_new_party_id            NUMBER;
    l_party_num               NUMBER;
    l_ou_id                   NUMBER;
    l_call_api_flag           NUMBER := 0;
    l_object_version_number   NUMBER;
    l_legacy_cust_account_id  NUMBER;
    organization_rec          hz_party_v2pub.organization_rec_type;
    cust_account_rec          hz_cust_account_v2pub.cust_account_rec_type;
    customer_profile_rec      hz_customer_profile_v2pub.customer_profile_rec_type;
    cust_profile_amt_rec      hz_customer_profile_v2pub.cust_profile_amt_rec_type;
    TYPE hz_acct_val_tbl IS TABLE OF apps.xxhz_acct_legacy_int_v@source_s3%ROWTYPE INDEX BY BINARY_INTEGER;
    l_hz_acct_val_tab hz_acct_val_tbl;
  BEGIN
  
    fnd_global.apps_initialize(user_id      => g_user_id,
                               resp_id      => g_resp_id,
                               resp_appl_id => g_application_id);
    BEGIN
      SELECT * BULK COLLECT
        INTO l_hz_acct_val_tab
        FROM apps.xxhz_acct_legacy_int_v@source_s3
       WHERE 1 = 1
         AND rownum <= p_batch_size
       ORDER BY last_update_date ASC;
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
      WHEN OTHERS THEN
        p_retcode := 2;
        fnd_file.put_line(fnd_file.log,
                          'Unexpected error 0....' || SQLERRM);
      
    END;
  
    FOR i IN 1 .. l_hz_acct_val_tab.COUNT LOOP
      cust_account_rec     := NULL;
      organization_rec     := NULL;
      customer_profile_rec := NULL;
    
      -----Query for collector
      BEGIN
        SELECT collector_id
          INTO l_collector_id
          FROM ar_collectors
         WHERE NAME = l_hz_acct_val_tab(i).collector;
      EXCEPTION
        WHEN no_data_found THEN
          l_collector_id := '';
          fnd_file.put_line(fnd_file.log,
                            'Collector ' || l_hz_acct_val_tab(i).collector || ' is not found...');
        WHEN OTHERS THEN
          l_collector_id := '';
      END;
    
      -----Query for Pricelist
      IF l_hz_acct_val_tab(i).price_list IS NOT NULL THEN
        BEGIN
          SELECT price_list_id
            INTO l_price_list_id
            FROM qp_price_lists_v
           WHERE NAME = l_hz_acct_val_tab(i).price_list;
        EXCEPTION
          WHEN no_data_found THEN
            xxssys_event_pkg_s3.update_error(l_hz_acct_val_tab(i).event_id,
                                             'Price list ' || l_hz_acct_val_tab(i)
                                             .price_list || ' not found in Legacy');
            l_call_api_flag := 1;
            l_price_list_id := NULL;
            x_api_message   := 'Price List ' || l_hz_acct_val_tab(i)
                              .price_list || ' is not found in Legacy System';
            fnd_file.put_line(fnd_file.log,
                              'Price List ' || l_hz_acct_val_tab(i)
                              .price_list || ' is not found...');
          WHEN OTHERS THEN
            l_call_api_flag := 1;
            xxssys_event_pkg_s3.update_error(l_hz_acct_val_tab(i).event_id,
                                             SQLERRM);
            l_price_list_id := NULL;
            fnd_file.put_line(fnd_file.log,
                              'Error in selecting Price List ' || l_hz_acct_val_tab(i)
                              .price_list || '..Error=' || SQLERRM);
        END;
      
      END IF;
    
      -----Query for Payment Terms
      IF l_hz_acct_val_tab(i).payment_terms IS NOT NULL THEN
        BEGIN
          SELECT term_id
            INTO l_payment_term_id
            FROM ra_terms
           WHERE NAME = l_hz_acct_val_tab(i).payment_terms
             AND nvl(end_date_active,
                     trunc(SYSDATE)) >= trunc(SYSDATE);
        EXCEPTION
          WHEN no_data_found THEN
            xxssys_event_pkg_s3.update_error(l_hz_acct_val_tab(i).event_id,
                                             'Payment term ' || l_hz_acct_val_tab(i)
                                             .payment_terms || ' not found');
            l_call_api_flag   := 1;
            l_payment_term_id := NULL;
            x_api_message     := x_api_message || chr(10) || 'Payment Term ' ||
                                 l_hz_acct_val_tab(i)
                                .payment_terms || ' is not found in Legacy System.';
            fnd_file.put_line(fnd_file.log,
                              'Payment Term ' || l_hz_acct_val_tab(i)
                              .payment_terms || ' is not found...');
          WHEN OTHERS THEN
            l_call_api_flag := 1;
            xxssys_event_pkg_s3.update_error(l_hz_acct_val_tab(i).event_id,
                                             SQLERRM);
            l_payment_term_id := NULL;
            fnd_file.put_line(fnd_file.log,
                              'Error in selecting Payment Term ' || l_hz_acct_val_tab(i)
                              .payment_terms || ' Error=' || SQLERRM);
        END;
      
      END IF;
    
      -----Query for Operating Units
      BEGIN
        SELECT organization_id
          INTO l_ou_id
          FROM hr_organization_information
         WHERE org_information5 = l_hz_acct_val_tab(i)
        .customer_supp_opr_unit
           AND org_information_context = 'Operating Unit Information';
      EXCEPTION
        WHEN no_data_found THEN
          l_ou_id := '';
          fnd_file.put_line(fnd_file.log,
                            'Customer Support OU ' || l_hz_acct_val_tab(i)
                            .customer_supp_opr_unit || ' is not found...');
        WHEN OTHERS THEN
          l_ou_id := '';
      END;
      -----Query for SAM Manager
      BEGIN
        SELECT full_name
          INTO l_sm_mngr
          FROM apps.per_all_people_f@source_s3
         WHERE person_id = l_hz_acct_val_tab(i)
        .sam_manager
           AND SYSDATE BETWEEN effective_start_date AND effective_end_date;
      
        SELECT person_id
          INTO l_sam_mgr_id
          FROM per_all_people_f
         WHERE full_name = l_sm_mngr
           AND SYSDATE BETWEEN effective_start_date AND effective_end_date;
      EXCEPTION
        WHEN no_data_found THEN
          l_sam_mgr_id := NULL;
          fnd_file.put_line(fnd_file.log,
                            'SAM Manager ' || l_hz_acct_val_tab(i)
                            .sam_manager || ' is not found...');
        WHEN OTHERS THEN
        
          l_sam_mgr_id := NULL;
      END;
      cust_account_rec.status               := l_hz_acct_val_tab(i).account_status;
      cust_account_rec.customer_type        := l_hz_acct_val_tab(i).account_type;
      cust_account_rec.sales_channel_code   := l_hz_acct_val_tab(i).sales_channel;
      cust_account_rec.date_type_preference := l_hz_acct_val_tab(i).request_date_type;
      cust_account_rec.price_list_id        := l_price_list_id;
      cust_account_rec.attribute4           := l_hz_acct_val_tab(i).sf_account_id;
      cust_account_rec.attribute5           := l_hz_acct_val_tab(i).transfer_to_sf;
      cust_account_rec.attribute6           := l_hz_acct_val_tab(i).political_customer;
      cust_account_rec.attribute9           := l_hz_acct_val_tab(i).shipping_instruction;
      cust_account_rec.attribute10          := l_hz_acct_val_tab(i).collect_shipping_account;
      cust_account_rec.attribute11          := to_char(l_hz_acct_val_tab(i).customer_start_date,
                                                       'YYYY/MM/DD HH24:MI:SS');
      cust_account_rec.attribute12          := l_hz_acct_val_tab(i).inactive_reason;
      cust_account_rec.attribute13          := to_char(l_hz_acct_val_tab(i).customer_end_date,
                                                       'YYYY/MM/DD HH24:MI:SS');
    
      customer_profile_rec.credit_hold     := l_hz_acct_val_tab(i).credit_hold_flag;
      customer_profile_rec.credit_checking := l_hz_acct_val_tab(i).credit_check_flag;
      customer_profile_rec.collector_id    := l_collector_id;
      customer_profile_rec.standard_terms  := l_payment_term_id;
      customer_profile_rec.attribute2      := l_hz_acct_val_tab(i).credit_hold_reason;
      customer_profile_rec.attribute4      := l_hz_acct_val_tab(i).exempt_type;
      customer_profile_rec.attribute5      := l_hz_acct_val_tab(i).score_card;
    
      cust_profile_amt_rec.trx_credit_limit     := l_hz_acct_val_tab(i).credit_limit;
      cust_profile_amt_rec.overall_credit_limit := l_hz_acct_val_tab(i).credit_limit;
      cust_profile_amt_rec.attribute1           := l_hz_acct_val_tab(i).atradius_id;
      cust_profile_amt_rec.attribute2           := trunc(l_hz_acct_val_tab(i).ci_application_amount);
      cust_profile_amt_rec.attribute3           := to_char(l_hz_acct_val_tab(i).application_date,
                                                           'YYYY/MM/DD HH24:MI:SS');
      cust_profile_amt_rec.attribute4           := trunc(l_hz_acct_val_tab(i).ci_decision_amount);
      cust_profile_amt_rec.attribute5           := to_char(l_hz_acct_val_tab(i)
                                                           .decision_effective_date,
                                                           'YYYY/MM/DD HH24:MI:SS');
      cust_profile_amt_rec.attribute6           := to_char(l_hz_acct_val_tab(i).expiry_date,
                                                           'YYYY/MM/DD HH24:MI:SS');
    
      organization_rec.party_rec.attribute2       := l_hz_acct_val_tab(i).security_exception;
      organization_rec.party_rec.attribute3       := l_ou_id;
      organization_rec.party_rec.attribute4       := to_char(l_hz_acct_val_tab(i)
                                                             .sam_benefit_start_date,
                                                             'YYYY/MM/DD HH24:MI:SS');
      organization_rec.party_rec.attribute5       := l_hz_acct_val_tab(i).sam_account_flag;
      organization_rec.party_rec.attribute7       := l_hz_acct_val_tab(i).vip_customer;
      organization_rec.party_rec.attribute9       := l_sam_mgr_id;
      organization_rec.party_rec.attribute11      := l_hz_acct_val_tab(i).sam_basket_level;
      organization_rec.party_rec.attribute12      := l_hz_acct_val_tab(i).national_rgstrn_number;
      organization_rec.party_rec.attribute13      := to_char(l_hz_acct_val_tab(i)
                                                             .contract_start_date,
                                                             'YYYY/MM/DD HH24:MI:SS');
      organization_rec.party_rec.attribute14      := to_char(l_hz_acct_val_tab(i).contract_end_date,
                                                             'YYYY/MM/DD HH24:MI:SS');
      organization_rec.known_as                   := l_hz_acct_val_tab(i).alias;
      organization_rec.organization_name_phonetic := l_hz_acct_val_tab(i).name_pronunciation;
      organization_rec.duns_number_c              := l_hz_acct_val_tab(i).duns_number;
      organization_rec.tax_reference              := l_hz_acct_val_tab(i).tax_reference;
      organization_rec.jgzz_fiscal_code           := l_hz_acct_val_tab(i).tax_payer_id;
      organization_rec.party_rec.status           := l_hz_acct_val_tab(i).party_status;
      organization_rec.party_rec.category_code    := l_hz_acct_val_tab(i).customer_category_type;
      -----Checking Cross Reference----
      l_legacy_cust_account_id := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-NUMBER',
                                                                                           l_hz_acct_val_tab(i)
                                                                                           .cust_account_id));
    
      IF l_legacy_cust_account_id IS NULL AND l_call_api_flag = 0 THEN
        fnd_file.put_line(fnd_file.log,
                          '**************Creating Account ' || l_hz_acct_val_tab(i)
                          .account_number || ' Party Number ' || l_hz_acct_val_tab(i)
                          .party_number || ' ***************************');
        IF l_hz_acct_val_tab(i).party_type = 'PERSON' THEN
          xxssys_event_pkg_s3.update_error(l_hz_acct_val_tab(i).event_id,
                                           'Account should be created for Organization type Party');
        ELSIF l_hz_acct_val_tab(i).party_type = 'ORGANIZATION' THEN
          organization_rec.organization_name               := l_hz_acct_val_tab(i).party_name;
          organization_rec.created_by_module               := 'TCA_V1_API';
          organization_rec.party_rec.orig_system_reference := l_hz_acct_val_tab(i).party_id;
          organization_rec.party_rec.party_number          := l_hz_acct_val_tab(i).party_number;
        
          ----Call create_organization procedure to create organization
          xxhz_s3_legacy_acc_api_pkg.create_organization(organization_rec,
                                                         l_new_party_id,
                                                         x_org_creation_status,
                                                         x_api_status,
                                                         x_api_message);
        
          -------Updating Status in events table---
          IF x_api_status = 'S' THEN
          
            xxssys_event_pkg_s3.update_success(l_hz_acct_val_tab(i).event_id);
          
          ELSE
            xxssys_event_pkg_s3.update_error(l_hz_acct_val_tab(i).event_id,
                                             x_api_message);
          END IF;
        
          IF x_org_creation_status = 'S' THEN
            organization_rec.party_rec.party_id    := l_new_party_id;
            cust_account_rec.orig_system_reference := l_hz_acct_val_tab(i).cust_account_id;
            cust_account_rec.account_number        := l_hz_acct_val_tab(i).account_number;
            cust_account_rec.account_name          := l_hz_acct_val_tab(i).account_name;
            cust_account_rec.status                := l_hz_acct_val_tab(i).account_status;
            cust_account_rec.customer_type         := l_hz_acct_val_tab(i).account_type;
            cust_account_rec.created_by_module     := 'TCA_V1_API';
          
            ----Call create_account procedure to create account
            xxhz_s3_legacy_acc_api_pkg.create_account(organization_rec,
                                                      cust_account_rec,
                                                      customer_profile_rec,
                                                      x_cust_account_id,
                                                      x_api_status,
                                                      x_api_message);
            BEGIN
              SELECT DISTINCT cust_acct_profile_amt_id
                INTO cust_profile_amt_rec.cust_acct_profile_amt_id
                FROM hz_customer_profiles hcp,
                     hz_cust_profile_amts hcpm
               WHERE hcp.cust_account_id = x_cust_account_id
                 AND hcp.cust_account_id = hcpm.cust_account_id
                 AND hcp.site_use_id IS NULL;
            
              xxhz_s3_legacy_acc_api_pkg.update_cust_profile_amt(cust_profile_amt_rec);
            
            EXCEPTION
              WHEN OTHERS THEN
                cust_profile_amt_rec.cust_acct_profile_amt_id := '';
            END;
            ----if account creation is successfull,then create a record into the cross reference table
            IF x_api_status = 'S' THEN
              xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table(p_entity_name => 'ACCT-NUMBER',
                                                                    p_legacy_id   => to_char(x_cust_account_id),
                                                                    p_s3_id       => to_char(l_hz_acct_val_tab(i)
                                                                                             .cust_account_id),
                                                                    p_org_id      => '',
                                                                    p_attribute1  => '',
                                                                    p_attribute2  => '',
                                                                    p_attribute3  => '',
                                                                    p_attribute4  => '',
                                                                    p_attribute5  => '',
                                                                    p_err_code    => x_err_code,
                                                                    p_err_message => x_api_message);
            
            END IF;
            -------Updating Status in events table---
            IF x_api_status = 'S' THEN
              xxssys_event_pkg_s3.update_success(l_hz_acct_val_tab(i).event_id);
            ELSE
              xxssys_event_pkg_s3.update_error(l_hz_acct_val_tab(i).event_id,
                                               x_api_message);
            END IF;
          END IF;
        END IF;
      ELSIF l_legacy_cust_account_id IS NOT NULL AND l_call_api_flag = 0 THEN
        fnd_file.put_line(fnd_file.log,
                          '**************Updating Account ' || l_hz_acct_val_tab(i)
                          .account_number || ' Party Number ' || l_hz_acct_val_tab(i)
                          .party_number || ' ***************************');
        BEGIN
          SELECT party_number,
                 party_id,
                 object_version_number
            INTO l_party_num,
                 l_exist_party_id,
                 l_party_obj_version_num
            FROM hz_parties
           WHERE party_number = l_hz_acct_val_tab(i).party_number;
        
        EXCEPTION
          WHEN no_data_found THEN
            l_party_num := NULL;
          WHEN OTHERS THEN
            l_party_num := NULL;
            p_retcode   := 2;
            fnd_file.put_line(fnd_file.log,
                              'Unexpected error 1....' || SQLERRM);
        END;
      
        IF l_hz_acct_val_tab(i).party_type = 'PERSON' THEN
          NULL;
          --xxhz_s3_legacy_acc_api_pkg.update_person(xx_person_rec,p_obj_version);
        ELSIF l_hz_acct_val_tab(i).party_type = 'ORGANIZATION' THEN
          organization_rec.party_rec.party_id := l_exist_party_id;
          organization_rec.organization_name  := l_hz_acct_val_tab(i).party_name;
          organization_rec.tax_reference      := l_hz_acct_val_tab(i).tax_reference;
          organization_rec.known_as           := l_hz_acct_val_tab(i).alias;
        
          organization_rec.party_rec.party_number := l_hz_acct_val_tab(i).party_number;
          organization_rec.party_rec.status       := l_hz_acct_val_tab(i).party_status;
          organization_rec.duns_number_c          := l_hz_acct_val_tab(i).duns_number;
        
          ----Call update_organization procedure to update organization type party
          xxhz_s3_legacy_acc_api_pkg.update_organization(organization_rec,
                                                         l_party_obj_version_num,
                                                         x_api_status,
                                                         x_api_message);
          -------Updating Status in events table---
          IF x_api_status = 'S' THEN
            xxssys_event_pkg_s3.update_success(l_hz_acct_val_tab(i).event_id);
          ELSE
            xxssys_event_pkg_s3.update_error(l_hz_acct_val_tab(i).event_id,
                                             x_api_message);
          END IF;
        END IF;
      
        cust_account_rec.account_name    := l_hz_acct_val_tab(i).account_name;
        cust_account_rec.cust_account_id := l_legacy_cust_account_id;
        BEGIN
          SELECT cust_account_profile_id
            INTO l_cust_account_profile_id
            FROM hz_customer_profiles
           WHERE cust_account_id = l_legacy_cust_account_id
             AND site_use_id IS NULL;
        
          customer_profile_rec.cust_account_profile_id := l_cust_account_profile_id;
        EXCEPTION
          WHEN OTHERS THEN
            customer_profile_rec.cust_account_profile_id := '';
        END;
      
        xxhz_s3_legacy_acc_api_pkg.update_account(cust_account_rec,
                                                  customer_profile_rec,
                                                  l_object_version_number,
                                                  x_api_status,
                                                  x_api_message);
      
        BEGIN
          SELECT cust_acct_profile_amt_id
            INTO cust_profile_amt_rec.cust_acct_profile_amt_id
            FROM hz_customer_profiles hcp,
                 hz_cust_profile_amts hcpm
           WHERE hcp.cust_account_profile_id = l_cust_account_profile_id
             AND hcp.cust_account_id = hcpm.cust_account_id;
        
          xxhz_s3_legacy_acc_api_pkg.update_cust_profile_amt(cust_profile_amt_rec);
        EXCEPTION
          WHEN OTHERS THEN
            cust_profile_amt_rec.cust_acct_profile_amt_id := '';
        END;
        -------Updating Status in events table-----
        IF x_api_status = 'S' THEN
        
          xxssys_event_pkg_s3.update_success(l_hz_acct_val_tab(i).event_id);
        
        ELSE
        
          xxssys_event_pkg_s3.update_error(l_hz_acct_val_tab(i).event_id,
                                           x_api_message);
        
        END IF;
      END IF;
      IF l_call_api_flag = 1 THEN
        xxssys_event_pkg_s3.update_error(l_hz_acct_val_tab(i).event_id,
                                         x_api_message);
      END IF;
      x_api_message := '';
    END LOOP;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
    
      l_error_msg := 'Unexpected Error--3' || SQLERRM;
      p_retcode   := 2;
      fnd_file.put_line(fnd_file.log,
                        l_error_msg);
    
  END pull_account;
  --------------------------------------------------------------------
  --  name:               pull_contact_point
  --  create by:          TCS
  --  $Revision:          1.0
  --  creation date:      17/08/2016
  --- Description:        This procedure will collect the Customer Contact Points data from  s3 environment
  --                      and will create or update those Contact points data into Legacy environment through
  --                      Oracle standard API
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    TCS       initial build
  --------------------------------------------------------------------
  PROCEDURE pull_contact_point(p_errbuf     OUT VARCHAR2,
                               p_retcode    OUT NUMBER,
                               p_batch_size IN NUMBER)
  
   IS
    x_api_status              VARCHAR2(10);
    x_api_message             VARCHAR2(4000);
    x_err_code                VARCHAR2(100);
    l_object_version_number   NUMBER;
    l_contact_point_id        NUMBER;
    l_party_id1               NUMBER;
    x_contact_point_id        NUMBER;
    l_s3_subject_id           NUMBER;
    l_s3_object_id            NUMBER;
    l_legacy_subject_party_id NUMBER;
    l_legacy_object_party_id  NUMBER;
    l_legacy_relationship_id  NUMBER;
    l_s3_subject_party_num    VARCHAR2(100);
    l_s3_object_party_num     VARCHAR2(100);
    contact_point_rec         hz_contact_point_v2pub.contact_point_rec_type;
    edi_rec                   hz_contact_point_v2pub.edi_rec_type;
    email_rec                 hz_contact_point_v2pub.email_rec_type;
    phone_rec                 hz_contact_point_v2pub.phone_rec_type;
    telex_rec                 hz_contact_point_v2pub.telex_rec_type;
    web_rec                   hz_contact_point_v2pub.web_rec_type;
    TYPE hz_cntct_pnt_val_tbl IS TABLE OF apps.xxhz_contact_pnt_legacy_int_v@source_s3%ROWTYPE INDEX BY BINARY_INTEGER;
    l_hz_cntct_pnt_val_tab hz_cntct_pnt_val_tbl;
  BEGIN
    fnd_global.apps_initialize(user_id      => g_user_id,
                               resp_id      => g_resp_id,
                               resp_appl_id => g_application_id);
    SELECT * BULK COLLECT
      INTO l_hz_cntct_pnt_val_tab
      FROM apps.xxhz_contact_pnt_legacy_int_v@source_s3
     WHERE 1 = 1
       AND rownum <= p_batch_size
     ORDER BY last_update_date ASC;
  
    FOR i IN 1 .. l_hz_cntct_pnt_val_tab.COUNT LOOP
      /* fnd_file.put_line(fnd_file.log,
      '**************Creating/Updating Contact Point ' || i ||
      ' ***************************');*/
      contact_point_rec := NULL;
      edi_rec           := NULL;
      email_rec         := NULL;
      phone_rec         := NULL;
      telex_rec         := NULL;
      web_rec           := NULL;
      -----Checking Cross Reference----
      l_contact_point_id := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-CONTACTPOINTS',
                                                                                     l_hz_cntct_pnt_val_tab(i)
                                                                                     .contact_point_id));
      BEGIN
        SELECT party_id
          INTO l_party_id1
          FROM hz_parties
         WHERE party_number = to_char(l_hz_cntct_pnt_val_tab(i).party_number);
      
        contact_point_rec.owner_table_id := l_party_id1;
      EXCEPTION
        WHEN no_data_found THEN
          l_party_id1                      := NULL;
          contact_point_rec.owner_table_id := NULL;
        
        WHEN OTHERS THEN
          l_party_id1 := NULL;
          p_retcode   := 2;
          fnd_file.put_line(fnd_file.log,
                            'Unexpected error 4....' || SQLERRM);
        
      END;
      ----End of fetching reference------
      contact_point_rec.contact_point_type    := l_hz_cntct_pnt_val_tab(i).contact_point_type;
      contact_point_rec.contact_point_purpose := l_hz_cntct_pnt_val_tab(i).contact_point_purpose;
      contact_point_rec.owner_table_name      := l_hz_cntct_pnt_val_tab(i).owner_table_name;
      contact_point_rec.status                := l_hz_cntct_pnt_val_tab(i).contact_point_status;
      contact_point_rec.primary_flag          := l_hz_cntct_pnt_val_tab(i).primary_flag;
    
      phone_rec.phone_area_code    := l_hz_cntct_pnt_val_tab(i).phone_area_code;
      phone_rec.phone_country_code := l_hz_cntct_pnt_val_tab(i).phone_country_code;
      phone_rec.phone_number       := l_hz_cntct_pnt_val_tab(i).phone_number;
      phone_rec.phone_extension    := l_hz_cntct_pnt_val_tab(i).phone_extension;
      phone_rec.phone_line_type    := l_hz_cntct_pnt_val_tab(i).phone_line_type;
      email_rec.email_address      := l_hz_cntct_pnt_val_tab(i).email_address;
      email_rec.email_format       := l_hz_cntct_pnt_val_tab(i).email_format;
      web_rec.web_type             := l_hz_cntct_pnt_val_tab(i).web_type;
      web_rec.url                  := l_hz_cntct_pnt_val_tab(i).url;
    
      IF l_contact_point_id IS NULL THEN
        fnd_file.put_line(fnd_file.log,
                          '**************Creating Contact Point ' || i || ' *************Event ID=' ||
                          l_hz_cntct_pnt_val_tab(i).event_id);
        IF l_party_id1 IS NOT NULL THEN
          fnd_file.put_line(fnd_file.log,
                            '**************CreatingContact Point where contact point is created directly..');
          ----Call create_contact_point procedure to create contact point
          contact_point_rec.orig_system_reference := l_hz_cntct_pnt_val_tab(i).contact_point_id;
          contact_point_rec.created_by_module     := 'TCA_V1_API';
          xxhz_s3_legacy_acc_api_pkg.create_contact_point(contact_point_rec,
                                                          edi_rec,
                                                          email_rec,
                                                          phone_rec,
                                                          telex_rec,
                                                          web_rec,
                                                          l_object_version_number,
                                                          x_contact_point_id,
                                                          x_api_status,
                                                          x_api_message);
          -------Updating cross reference table if contact is created successfully-----
          IF x_api_status = 'S' THEN
            xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table(p_entity_name => 'ACCT-CONTACTPOINTS',
                                                                  p_legacy_id   => to_char(x_contact_point_id),
                                                                  p_s3_id       => to_char(l_hz_cntct_pnt_val_tab(i)
                                                                                           .contact_point_id),
                                                                  p_org_id      => '',
                                                                  p_attribute1  => '',
                                                                  p_attribute2  => '',
                                                                  p_attribute3  => '',
                                                                  p_attribute4  => '',
                                                                  p_attribute5  => '',
                                                                  p_err_code    => x_err_code,
                                                                  p_err_message => x_api_message);
          
          END IF;
        END IF;
        -----In case of those contact points which is created from Org contact creation
        IF l_party_id1 IS NULL THEN
          BEGIN
            fnd_file.put_line(fnd_file.log,
                              '**************CreatingContact Point where contact point is created through org contact..');
            SELECT subject_id,
                   object_id
              INTO l_s3_subject_id,
                   l_s3_object_id
              FROM apps.hz_relationships@source_s3
             WHERE directional_flag = 'F'
               AND party_id = l_hz_cntct_pnt_val_tab(i).legacy_party_id;
          
            fnd_file.put_line(fnd_file.log,
                              '1st query s3 party_id=' || l_hz_cntct_pnt_val_tab(i).legacy_party_id);
          
            SELECT party_number
              INTO l_s3_subject_party_num
              FROM apps.hz_parties@source_s3
             WHERE party_id = l_s3_subject_id;
          
            fnd_file.put_line(fnd_file.log,
                              '2nd query s3 subject party_id=' || l_s3_subject_id);
          
            SELECT party_number
              INTO l_s3_object_party_num
              FROM apps.hz_parties@source_s3
             WHERE party_id = l_s3_object_id;
          
            fnd_file.put_line(fnd_file.log,
                              '3rd query s3 object party_id=' || l_s3_object_id);
          
            SELECT party_id
              INTO l_legacy_subject_party_id
              FROM hz_parties
             WHERE party_number = l_s3_subject_party_num;
          
            fnd_file.put_line(fnd_file.log,
                              '4th query s3 subject party_number=' || l_s3_subject_party_num ||
                              ' l_legacy_subject_party_id=' || l_legacy_subject_party_id);
          
            SELECT party_id
              INTO l_legacy_object_party_id
              FROM hz_parties
             WHERE party_number = l_s3_object_party_num;
          
            fnd_file.put_line(fnd_file.log,
                              '5th query s3 object party_number=' || l_s3_object_party_num ||
                              '  l_legacy_object_party_id=' || l_legacy_object_party_id);
          
            SELECT party_id
              INTO l_legacy_relationship_id
              FROM hz_relationships
             WHERE subject_id = l_legacy_subject_party_id
               AND object_id = l_legacy_object_party_id;
          
            fnd_file.put_line(fnd_file.log,
                              '6th query l_legacy_relationship_id=' || l_legacy_relationship_id);
          EXCEPTION
            WHEN OTHERS THEN
              l_legacy_relationship_id := NULL;
              xxssys_event_pkg_s3.update_error(l_hz_cntct_pnt_val_tab(i).event_id,
                                               'Relationship is not created between the subject and object party id ' ||
                                               l_legacy_subject_party_id || ' and ' ||
                                               l_legacy_object_party_id);
          END;
          IF l_legacy_relationship_id IS NOT NULL THEN
            contact_point_rec.owner_table_id        := l_legacy_relationship_id;
            contact_point_rec.orig_system_reference := l_hz_cntct_pnt_val_tab(i).contact_point_id;
            contact_point_rec.created_by_module     := 'TCA_V1_API';
            xxhz_s3_legacy_acc_api_pkg.create_contact_point(contact_point_rec,
                                                            edi_rec,
                                                            email_rec,
                                                            phone_rec,
                                                            telex_rec,
                                                            web_rec,
                                                            l_object_version_number,
                                                            x_contact_point_id,
                                                            x_api_status,
                                                            x_api_message);
            fnd_file.put_line(fnd_file.log,
                              'x_api_status=' || x_api_status);
            fnd_file.put_line(fnd_file.log,
                              'x_api_message=' || x_api_message);
            -------Updating cross reference table if contact is created successfully-----
            IF x_api_status = 'S' THEN
              xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table(p_entity_name => 'ACCT-CONTACTPOINTS',
                                                                    p_legacy_id   => to_char(x_contact_point_id),
                                                                    p_s3_id       => to_char(l_hz_cntct_pnt_val_tab(i)
                                                                                             .contact_point_id),
                                                                    p_org_id      => '',
                                                                    p_attribute1  => '',
                                                                    p_attribute2  => '',
                                                                    p_attribute3  => '',
                                                                    p_attribute4  => '',
                                                                    p_attribute5  => '',
                                                                    p_err_code    => x_err_code,
                                                                    p_err_message => x_api_message);
            
            END IF;
          END IF;
        END IF;
      ELSIF l_contact_point_id IS NOT NULL THEN
        ----Call update_contact_point procedure to update contact point
        fnd_file.put_line(fnd_file.log,
                          '**************Updating Contact Point ' || i || ' *************Event ID=' ||
                          l_hz_cntct_pnt_val_tab(i).event_id);
        BEGIN
          SELECT object_version_number
            INTO l_object_version_number
            FROM hz_contact_points
           WHERE contact_point_id = l_contact_point_id;
        EXCEPTION
          WHEN OTHERS THEN
            p_retcode := 2;
            fnd_file.put_line(fnd_file.log,
                              'Unexpected error 3....' || SQLERRM);
        END;
        contact_point_rec.contact_point_id := l_contact_point_id;
        xxhz_s3_legacy_acc_api_pkg.update_contact_point(contact_point_rec,
                                                        edi_rec,
                                                        email_rec,
                                                        phone_rec,
                                                        telex_rec,
                                                        web_rec,
                                                        l_object_version_number,
                                                        x_api_status,
                                                        x_api_message);
      END IF;
      -------Updating Status into events table---
      IF x_api_status = 'S' THEN
        xxssys_event_pkg_s3.update_success(l_hz_cntct_pnt_val_tab(i).event_id);
      ELSE
        xxssys_event_pkg_s3.update_error(l_hz_cntct_pnt_val_tab(i).event_id,
                                         x_api_message);
      END IF;
      x_api_message := '';
    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_retcode := 2;
      fnd_file.put_line(fnd_file.log,
                        'Unexpected error 5....' || SQLERRM);
  END pull_contact_point;
  -------------------------------------------------------------------
  --  name:               pull_contact
  --  create by:          TCS
  --  $Revision:          1.0
  --  creation date:      17/08/2016
  --- Description:        This procedure will collect the Customer Contact data from  s3 environment
  --                      and will create or update those Contact data into Legacy environment through
  --                      Oracle standard API
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    TCS       initial build
  --------------------------------------------------------------------
  PROCEDURE pull_contact(p_errbuf     OUT VARCHAR2,
                         p_retcode    OUT NUMBER,
                         p_batch_size IN NUMBER)
  
   IS
    x_err_code                   VARCHAR2(100);
    x_api_status                 VARCHAR2(10);
    x_api_message                VARCHAR2(4000);
    l_party_id                   NUMBER;
    l_person_party_id            NUMBER;
    l_subject_id                 NUMBER;
    l_legacy_resp_id             NUMBER;
    x_org_contact_id             NUMBER;
    l_object_id                  NUMBER;
    l_relationship_party_id      NUMBER;
    l_contact_version_num        NUMBER;
    l_object_version_number      NUMBER;
    l_resp_obj_version_num       NUMBER;
    l_relationship_version_num   NUMBER;
    l_cust_account_id            NUMBER;
    l_party_site_id              NUMBER;
    l_prty_site_obj_version_num  NUMBER;
    l_legacy_loc_id              NUMBER;
    l_legacy_org_contact_id      NUMBER;
    l_party_version_num          NUMBER;
    l_location_id                NUMBER;
    l_contact_count              NUMBER;
    x_party_site_id              NUMBER;
    l_account_assignment_count   NUMBER;
    x_party_id                   NUMBER;
    l_cust_account_role_id       NUMBER;
    l_role_object_version_number NUMBER;
    l_legacy_cust_acct_site_id   NUMBER;
    l_api_status                 VARCHAR2(10);
    l_error_msg                  VARCHAR2(4000);
    l_contact_point_id           NUMBER;
    l_legacy_cust_acct_role_id   NUMBER;
    x_responsibility_id          NUMBER;
    x_party_site_num             VARCHAR2(100);
    l_all_msg                    VARCHAR2(1000);
    org_contact_rec              hz_party_contact_v2pub.org_contact_rec_type;
    rec_cust_acc_role            hz_cust_account_role_v2pub.cust_account_role_rec_type;
    rec_contact_role_resp        hz_cust_account_role_v2pub.role_responsibility_rec_type;
    person_rec                   hz_party_v2pub.person_rec_type;
    location_rec                 hz_location_v2pub.location_rec_type;
    party_site_rec               hz_party_site_v2pub.party_site_rec_type;
    contact_point_rec            hz_contact_point_v2pub.contact_point_rec_type;
    email_rec                    hz_contact_point_v2pub.email_rec_type;
    phone_rec                    hz_contact_point_v2pub.phone_rec_type;
    TYPE hz_cntct_val_rec IS TABLE OF apps.xxhz_contact_legacy_int_v@source_s3%ROWTYPE INDEX BY BINARY_INTEGER;
    hz_cntct_val_tbl hz_cntct_val_rec;
  
  BEGIN
    fnd_global.apps_initialize(user_id      => g_user_id,
                               resp_id      => g_resp_id,
                               resp_appl_id => g_application_id);
  
    SELECT * BULK COLLECT
      INTO hz_cntct_val_tbl
      FROM apps.xxhz_contact_legacy_int_v@source_s3
     WHERE 1 = 1
       AND rownum <= p_batch_size
     ORDER BY entity_name,
              primary_flag;
  
    FOR i IN 1 .. hz_cntct_val_tbl.COUNT LOOP
      IF hz_cntct_val_tbl(i).entity_name = 'CONTACT' THEN
        org_contact_rec   := NULL;
        rec_cust_acc_role := NULL;
        person_rec        := NULL;
        party_site_rec    := NULL;
        location_rec      := NULL;
        email_rec         := NULL;
        phone_rec         := NULL;
        -----Checking Cross Reference----
        l_legacy_org_contact_id := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-CONTACTS',
                                                                                            hz_cntct_val_tbl(i)
                                                                                            .org_contact_id));
      
        IF hz_cntct_val_tbl(i).acct_role_cust_acct_site_id IS NOT NULL THEN
          l_legacy_cust_acct_site_id := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-SITES',
                                                                                                 hz_cntct_val_tbl(i)
                                                                                                 .acct_role_cust_acct_site_id));
        END IF;
        person_rec.person_title       := hz_cntct_val_tbl(i).title;
        person_rec.person_first_name  := hz_cntct_val_tbl(i).first_name;
        person_rec.person_middle_name := hz_cntct_val_tbl(i).middle_name;
        person_rec.person_last_name   := hz_cntct_val_tbl(i).last_name;
        location_rec.country          := hz_cntct_val_tbl(i).country;
        location_rec.address1         := hz_cntct_val_tbl(i).address1;
        location_rec.address2         := hz_cntct_val_tbl(i).address2;
        location_rec.address3         := hz_cntct_val_tbl(i).address3;
        location_rec.address4         := hz_cntct_val_tbl(i).address4;
        location_rec.city             := hz_cntct_val_tbl(i).city;
        location_rec.postal_code      := hz_cntct_val_tbl(i).postal_code;
        location_rec.state            := hz_cntct_val_tbl(i).state;
        location_rec.province         := hz_cntct_val_tbl(i).province;
        location_rec.county           := hz_cntct_val_tbl(i).county;
      
        org_contact_rec.contact_number                   := hz_cntct_val_tbl(i).contact_number;
        org_contact_rec.attribute1                       := hz_cntct_val_tbl(i).global_main_contact;
        org_contact_rec.attribute2                       := hz_cntct_val_tbl(i).site_main_contact;
        org_contact_rec.attribute4                       := hz_cntct_val_tbl(i).contact_type;
        org_contact_rec.attribute6                       := hz_cntct_val_tbl(i).decision_maker;
        org_contact_rec.party_rel_rec.status             := hz_cntct_val_tbl(i).party_status;
        org_contact_rec.party_rel_rec.object_table_name  := 'HZ_PARTIES';
        org_contact_rec.party_rel_rec.subject_table_name := hz_cntct_val_tbl(i).subject_table_name;
        org_contact_rec.party_rel_rec.start_date         := hz_cntct_val_tbl(i).start_date;
        org_contact_rec.party_rel_rec.start_date         := hz_cntct_val_tbl(i).end_date;
        org_contact_rec.party_rel_rec.object_type        := hz_cntct_val_tbl(i).object_type;
        org_contact_rec.party_rel_rec.relationship_code  := hz_cntct_val_tbl(i).relationship_code;
        org_contact_rec.party_rel_rec.relationship_type  := hz_cntct_val_tbl(i).relationship_type;
        org_contact_rec.party_rel_rec.subject_type       := hz_cntct_val_tbl(i).subject_type;
      
        IF l_legacy_org_contact_id IS NULL THEN
          fnd_file.put_line(fnd_file.log,
                            'Event ID: ' || hz_cntct_val_tbl(i)
                            .event_id || ' **************Creating Contact ' || i || ' :  ' ||
                             hz_cntct_val_tbl(i).contact_number || ' ***************************');
          BEGIN
            SELECT party_id,
                   object_version_number
              INTO l_party_id,
                   l_party_version_num
              FROM hz_parties
             WHERE party_number = hz_cntct_val_tbl(i).party_number;
            --    AND party_type = 'PERSON';
            fnd_file.put_line(fnd_file.log,
                              'party_number= ' || hz_cntct_val_tbl(i).party_number);
          EXCEPTION
            WHEN OTHERS THEN
              fnd_file.put_line(fnd_file.log,
                                'Error in finding party ' || SQLERRM);
              l_party_id          := NULL;
              l_party_version_num := NULL;
          END;
          IF l_party_id IS NULL THEN
            person_rec.created_by_module               := 'TCA_V1_API';
            person_rec.party_rec.orig_system_reference := hz_cntct_val_tbl(i).subject_id;
            person_rec.party_rec.party_number          := to_char(hz_cntct_val_tbl(i).party_number);
            xxhz_s3_legacy_acc_api_pkg.create_person(person_rec,
                                                     x_party_id,
                                                     x_api_status,
                                                     x_api_message);
          END IF;
          IF l_party_id IS NOT NULL THEN
            person_rec.party_rec.party_id := l_party_id;
            fnd_file.put_line(fnd_file.log,
                              'updating person id ' || l_party_id || ' and version number= ' ||
                              l_party_version_num);
            xxhz_s3_legacy_acc_api_pkg.update_person(person_rec,
                                                     l_party_version_num,
                                                     x_api_status,
                                                     x_api_message);
            x_party_id := l_party_id;
          END IF;
          fnd_file.put_line(fnd_file.log,
                            'person id ' || x_party_id);
          IF x_api_status = 'S' THEN
            --Deriving Organization Party id
            BEGIN
              SELECT y.party_id
                INTO l_object_id
                FROM apps.hz_parties@source_s3 x,
                     hz_parties                y
               WHERE x.party_id = to_number(hz_cntct_val_tbl(i).object_id)
                 AND x.party_number = y.party_number;
              -- AND y.party_type = 'ORGANIZATION';
              fnd_file.put_line(fnd_file.log,
                                'l_object_id = ' || l_object_id);
            EXCEPTION
              WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log,
                                  'Error in finding object_id ' || SQLERRM);
                l_object_id := NULL;
            END;
          
            BEGIN
              SELECT hr.party_id
                INTO l_relationship_party_id
                FROM hz_relationships hr
               WHERE 1 = 1
                 AND hr.directional_flag = 'F'
                 AND hr.subject_id = x_party_id
                 AND hr.object_id = l_object_id;
            
            EXCEPTION
              WHEN OTHERS THEN
                l_relationship_party_id := NULL;
            END;
          
            IF l_relationship_party_id IS NULL THEN
              org_contact_rec.created_by_module        := 'TCA_V1_API';
              org_contact_rec.orig_system_reference    := hz_cntct_val_tbl(i).org_contact_id;
              org_contact_rec.party_rel_rec.subject_id := x_party_id; --l_subject_id;
              org_contact_rec.party_rel_rec.object_id  := l_object_id;
              -------Call procedure create_contact to create contact-----
              xxhz_s3_legacy_acc_api_pkg.create_contact(org_contact_rec,
                                                        l_relationship_party_id,
                                                        x_org_contact_id,
                                                        x_api_status,
                                                        x_api_message);
              IF x_api_status <> 'S' THEN
                xxssys_event_pkg_s3.update_error(hz_cntct_val_tbl(i).event_id,
                                                 x_api_message);
              END IF;
              fnd_file.put_line(fnd_file.log,
                                'Before updating the cross ref');
              IF x_api_status = 'S' THEN
                xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table(p_entity_name => 'ACCT-CONTACTS',
                                                                      p_legacy_id   => to_char(x_org_contact_id),
                                                                      p_s3_id       => to_char(hz_cntct_val_tbl(i)
                                                                                               .org_contact_id),
                                                                      p_org_id      => '',
                                                                      p_attribute1  => '',
                                                                      p_attribute2  => '',
                                                                      p_attribute3  => '',
                                                                      p_attribute4  => '',
                                                                      p_attribute5  => '',
                                                                      p_err_code    => x_err_code,
                                                                      p_err_message => x_api_message);
              
                fnd_file.put_line(fnd_file.log,
                                  'After updating the cross ref');
              END IF;
            
            END IF;
            IF x_api_status = 'S' OR l_relationship_party_id IS NOT NULL THEN
              fnd_file.put_line(fnd_file.log,
                                'Inside here =');
              BEGIN
                SELECT cust_account_id
                  INTO l_cust_account_id
                  FROM hz_cust_accounts_all
                 WHERE account_number = hz_cntct_val_tbl(i).org_acc_number
                   AND status = 'A';
              EXCEPTION
                WHEN OTHERS THEN
                  xxssys_event_pkg_s3.update_error(hz_cntct_val_tbl(i).event_id,
                                                   'Account not found or the contact is not created at account level for the object id ' ||
                                                   l_object_id);
                  fnd_file.put_line(fnd_file.log,
                                    'Error is =');
              END;
              IF l_cust_account_id IS NOT NULL THEN
                rec_cust_acc_role.cust_account_id   := l_cust_account_id;
                rec_cust_acc_role.cust_acct_site_id := nvl(l_legacy_cust_acct_site_id,
                                                           fnd_api.g_null_num);
                rec_cust_acc_role.status            := hz_cntct_val_tbl(i).account_role_status;
                fnd_file.put_line(fnd_file.log,
                                  'org_cust_account_id=' || l_cust_account_id);
                ------Call procedure create_account_role to assign the contacts to account level-----
                xxhz_s3_legacy_acc_api_pkg.create_account_role(rec_cust_acc_role,
                                                               l_relationship_party_id,
                                                               l_legacy_cust_acct_role_id,
                                                               x_api_status,
                                                               x_api_message);
              
                -------Updating Status into events table---
                IF x_api_status = 'S' THEN
                  xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table(p_entity_name => 'ACCT-ROLES',
                                                                        p_legacy_id   => to_char(l_legacy_cust_acct_role_id),
                                                                        p_s3_id       => to_char(hz_cntct_val_tbl(i)
                                                                                                 .cust_account_role_id),
                                                                        p_org_id      => '',
                                                                        p_attribute1  => '',
                                                                        p_attribute2  => '',
                                                                        p_attribute3  => '',
                                                                        p_attribute4  => '',
                                                                        p_attribute5  => '',
                                                                        p_err_code    => x_err_code,
                                                                        p_err_message => x_api_message);
                
                  xxssys_event_pkg_s3.update_success(hz_cntct_val_tbl(i).event_id);
                ELSE
                  xxssys_event_pkg_s3.update_error(hz_cntct_val_tbl(i).event_id,
                                                   x_api_message);
                END IF;
              END IF;
            END IF;
          
            -- Call the party site Api only if the address is present
          
            IF hz_cntct_val_tbl(i).party_site_number IS NOT NULL THEN
              BEGIN
                SELECT location_id,
                       object_version_number
                  INTO l_legacy_loc_id,
                       l_object_version_number
                  FROM hz_locations
                 WHERE orig_system_reference = to_char(hz_cntct_val_tbl(i).location_id);
              EXCEPTION
                WHEN OTHERS THEN
                  l_legacy_loc_id         := NULL;
                  l_object_version_number := NULL;
              END;
            
              IF l_legacy_loc_id IS NOT NULL THEN
                location_rec.location_id := l_legacy_loc_id;
                xxhz_s3_legacy_acc_api_pkg.update_loc(location_rec,
                                                      l_object_version_number,
                                                      x_api_status,
                                                      x_api_message);
              END IF;
              IF l_legacy_loc_id IS NULL THEN
                location_rec.created_by_module     := 'TCA_V1_API';
                location_rec.orig_system_reference := hz_cntct_val_tbl(i).location_id;
                -- Call the location Api only if the address is present
                IF hz_cntct_val_tbl(i).address1 IS NOT NULL THEN
                  xxhz_s3_legacy_acc_api_pkg.create_location(location_rec,
                                                             l_location_id,
                                                             x_api_status,
                                                             x_api_message);
                  IF x_api_status <> 'S' THEN
                    l_all_msg := x_api_message;
                  END IF;
                END IF;
              
              END IF;
            
              BEGIN
                SELECT party_site_id,
                       object_version_number
                  INTO l_party_site_id,
                       l_prty_site_obj_version_num
                  FROM hz_party_sites
                 WHERE party_site_number = hz_cntct_val_tbl(i).party_site_number;
              EXCEPTION
                WHEN OTHERS THEN
                  l_party_site_id             := NULL;
                  l_prty_site_obj_version_num := NULL;
              END;
              IF l_party_site_id IS NULL THEN
                party_site_rec.created_by_module     := 'TCA_V1_API';
                party_site_rec.party_site_number     := hz_cntct_val_tbl(i).party_site_number;
                party_site_rec.party_site_name       := hz_cntct_val_tbl(i).party_site_name;
                party_site_rec.location_id           := l_location_id;
                party_site_rec.party_id              := l_relationship_party_id;
                party_site_rec.orig_system_reference := hz_cntct_val_tbl(i).party_site_id;
                xxhz_s3_legacy_acc_api_pkg.create_party_site(party_site_rec,
                                                             x_party_site_id,
                                                             x_party_site_num);
              END IF;
            END IF;
          ELSE
            xxssys_event_pkg_s3.update_error(hz_cntct_val_tbl(i).event_id,
                                             x_api_message);
          END IF;
        
        ELSIF l_legacy_org_contact_id IS NOT NULL THEN
          fnd_file.put_line(fnd_file.log,
                            'Event ID: ' || hz_cntct_val_tbl(i)
                            .event_id || ' **************Updating Contact ' || i || ' :  ' ||
                             hz_cntct_val_tbl(i).contact_number || ' ***************************');
          BEGIN
            SELECT hr.subject_id,
                   hr.party_id,
                   hoc.object_version_number,
                   hr.object_version_number,
                   hp.object_version_number
              INTO l_person_party_id,
                   l_relationship_party_id,
                   l_contact_version_num,
                   l_relationship_version_num,
                   l_party_version_num
              FROM hz_org_contacts  hoc,
                   hz_relationships hr,
                   hz_parties       hp
             WHERE hoc.party_relationship_id = hr.relationship_id
               AND hp.party_id = hr.subject_id
               AND hoc.org_contact_id = l_legacy_org_contact_id
               AND relationship_code = 'CONTACT_OF';
          EXCEPTION
            WHEN no_data_found THEN
              fnd_file.put_line(fnd_file.log,
                                'No Data Found error ....4.9' || SQLERRM);
              l_contact_version_num      := 1;
              l_relationship_version_num := 1;
              l_party_version_num        := 1;
            WHEN OTHERS THEN
              p_retcode := 2;
              fnd_file.put_line(fnd_file.log,
                                'Unexpected error 5....' || SQLERRM);
              l_contact_version_num      := 1;
              l_relationship_version_num := 1;
              l_party_version_num        := 1;
          END;
          org_contact_rec.org_contact_id := l_legacy_org_contact_id;
          person_rec.party_rec.party_id  := l_person_party_id;
        
          xxhz_s3_legacy_acc_api_pkg.update_person(person_rec,
                                                   l_party_version_num,
                                                   x_api_status,
                                                   x_api_message);
        
          ------Call procedure update_contact to update the contacts------
          xxhz_s3_legacy_acc_api_pkg.update_contact(org_contact_rec,
                                                    l_contact_version_num,
                                                    l_relationship_version_num,
                                                    l_party_version_num,
                                                    x_api_status,
                                                    x_api_message);
        
          ---Assigning contact at account level which is not assigned previously by any chance
        
          BEGIN
            SELECT cust_account_id
              INTO l_cust_account_id
              FROM hz_cust_accounts_all
             WHERE account_number = hz_cntct_val_tbl(i).org_acc_number
               AND status = 'A';
          EXCEPTION
            WHEN OTHERS THEN
              xxssys_event_pkg_s3.update_error(hz_cntct_val_tbl(i).event_id,
                                               'Account not found or the contact is not created at account level for the object id ' ||
                                               l_object_id);
              fnd_file.put_line(fnd_file.log,
                                'Error is =' ||
                                'Account not found or the contact is not created at account level for the object id ' ||
                                l_object_id);
          END;
        
          SELECT COUNT(1)
            INTO l_account_assignment_count
            FROM hz_cust_account_roles
           WHERE cust_account_id = l_cust_account_id
             AND party_id = l_relationship_party_id;
        
          IF l_account_assignment_count = 0 THEN
            rec_cust_acc_role.cust_account_id   := l_cust_account_id;
            rec_cust_acc_role.cust_acct_site_id := nvl(l_legacy_cust_acct_site_id,
                                                       fnd_api.g_null_num);
            rec_cust_acc_role.status            := hz_cntct_val_tbl(i).account_role_status;
            ------Call procedure create_account_role to assign the contacts to account level-----
            xxhz_s3_legacy_acc_api_pkg.create_account_role(rec_cust_acc_role,
                                                           l_relationship_party_id,
                                                           l_legacy_cust_acct_role_id,
                                                           x_api_status,
                                                           x_api_message);
          
            -------Updating Status into events table---
            IF x_api_status = 'S' THEN
              xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table(p_entity_name => 'ACCT-ROLES',
                                                                    p_legacy_id   => to_char(l_legacy_cust_acct_role_id),
                                                                    p_s3_id       => to_char(hz_cntct_val_tbl(i)
                                                                                             .cust_account_role_id),
                                                                    p_org_id      => '',
                                                                    p_attribute1  => '',
                                                                    p_attribute2  => '',
                                                                    p_attribute3  => '',
                                                                    p_attribute4  => '',
                                                                    p_attribute5  => '',
                                                                    p_err_code    => x_err_code,
                                                                    p_err_message => x_api_message);
              xxssys_event_pkg_s3.update_success(hz_cntct_val_tbl(i).event_id);
            ELSE
              xxssys_event_pkg_s3.update_error(hz_cntct_val_tbl(i).event_id,
                                               x_api_message);
            END IF;
          END IF;
        
          ---End of Assigning contact at account level which is not assigned previously by any chance
          IF l_account_assignment_count = 1 THEN
            SELECT cust_account_role_id,
                   object_version_number
              INTO l_cust_account_role_id,
                   l_role_object_version_number
              FROM hz_cust_account_roles
             WHERE cust_account_id = l_cust_account_id
               AND party_id = l_relationship_party_id;
          
            rec_cust_acc_role.cust_account_id      := l_cust_account_id;
            rec_cust_acc_role.cust_acct_site_id    := nvl(l_legacy_cust_acct_site_id,
                                                          fnd_api.g_null_num);
            rec_cust_acc_role.status               := hz_cntct_val_tbl(i).account_role_status;
            rec_cust_acc_role.cust_account_role_id := l_cust_account_role_id;
          
            xxhz_s3_legacy_acc_api_pkg.update_account_role(rec_cust_acc_role,
                                                           l_role_object_version_number,
                                                           x_api_status,
                                                           x_api_message);
          END IF;
          -------Updating Status into events table---
          IF x_api_status = 'S' THEN
            xxssys_event_pkg_s3.update_success(hz_cntct_val_tbl(i).event_id);
          ELSE
            xxssys_event_pkg_s3.update_error(hz_cntct_val_tbl(i).event_id,
                                             x_api_message);
          END IF;
        END IF;
        x_api_message := '';
      END IF;
      IF hz_cntct_val_tbl(i).entity_name = 'CONTACT_ROLE' THEN
        rec_contact_role_resp      := NULL;
        l_legacy_resp_id           := NULL;
        l_resp_obj_version_num     := NULL;
        l_legacy_cust_acct_role_id := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-ROLES',
                                                                                               hz_cntct_val_tbl(i)
                                                                                               .cust_account_role_id));
        BEGIN
          SELECT responsibility_id,
                 object_version_number
            INTO l_legacy_resp_id,
                 l_resp_obj_version_num
            FROM hz_role_responsibility
           WHERE orig_system_reference = to_char(hz_cntct_val_tbl(i).responsibility_id);
        EXCEPTION
          WHEN OTHERS THEN
            l_legacy_resp_id       := NULL;
            l_resp_obj_version_num := NULL;
        END;
        rec_contact_role_resp.primary_flag := hz_cntct_val_tbl(i).primary_flag;
      
        IF l_legacy_resp_id IS NULL THEN
          rec_contact_role_resp.created_by_module     := 'TCA_V1_API';
          rec_contact_role_resp.cust_account_role_id  := l_legacy_cust_acct_role_id;
          rec_contact_role_resp.responsibility_type   := hz_cntct_val_tbl(i).responsibility_type;
          rec_contact_role_resp.orig_system_reference := to_char(hz_cntct_val_tbl(i)
                                                                 .responsibility_id);
          xxhz_s3_legacy_acc_api_pkg.create_role_responsibility(rec_contact_role_resp,
                                                                x_responsibility_id,
                                                                x_api_status,
                                                                x_api_message);
          IF x_api_status = 'S' THEN
            xxssys_event_pkg_s3.update_success(hz_cntct_val_tbl(i).event_id);
          ELSE
            xxssys_event_pkg_s3.update_error(hz_cntct_val_tbl(i).event_id,
                                             x_api_message);
          END IF;
        END IF;
        IF l_legacy_resp_id IS NOT NULL THEN
          fnd_file.put_line(fnd_file.log,
                            'l_legacy_resp_id=' || l_legacy_resp_id || '  l_resp_obj_version_num=' ||
                            l_resp_obj_version_num);
          rec_contact_role_resp.responsibility_id := l_legacy_resp_id;
          xxhz_s3_legacy_acc_api_pkg.update_role_responsibility(rec_contact_role_resp,
                                                                l_resp_obj_version_num,
                                                                x_api_status,
                                                                x_api_message);
        
          IF x_api_status = 'S' THEN
            xxssys_event_pkg_s3.update_success(hz_cntct_val_tbl(i).event_id);
          ELSE
            xxssys_event_pkg_s3.update_error(hz_cntct_val_tbl(i).event_id,
                                             x_api_message);
          END IF;
        END IF;
      END IF;
    
    END LOOP;
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_retcode := 2;
      fnd_file.put_line(fnd_file.log,
                        'Unexpected error 6....' || SQLERRM);
    
  END pull_contact;
  -------------------------------------------------------------------
  --  name:               pull_relationship
  --  create by:          TCS
  --  $Revision:          1.0
  --  creation date:      17/08/2016
  --- Description:        This procedure will collect the party relationship data from  s3 environment
  --                      and will create or update those party relationship data into Legacy environment through
  --                      Oracle standard API
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    TCS       initial build
  --------------------------------------------------------------------
  PROCEDURE pull_relationship(p_errbuf     OUT VARCHAR2,
                              p_retcode    OUT NUMBER,
                              p_batch_size IN NUMBER) IS
  
    x_api_status             VARCHAR2(10);
    x_api_message            VARCHAR2(4000);
    x_err_code               VARCHAR2(100);
    x_relationship_id        NUMBER;
    l_object_party_id        NUMBER;
    l_legacy_relationship_id NUMBER;
    l_subject_party_id       NUMBER;
  
    relationship_rec hz_relationship_v2pub.relationship_rec_type;
    TYPE party_relationship_rec IS TABLE OF apps.xxhz_prty_rltion_legacy_int_v@source_s3%ROWTYPE INDEX BY BINARY_INTEGER;
    party_relationship_tbl party_relationship_rec;
  BEGIN
    fnd_global.apps_initialize(user_id      => g_user_id,
                               resp_id      => g_resp_id,
                               resp_appl_id => g_application_id);
  
    SELECT * BULK COLLECT
      INTO party_relationship_tbl
      FROM apps.xxhz_prty_rltion_legacy_int_v@source_s3
     WHERE 1 = 1
       AND rownum <= p_batch_size
       AND relationship_code NOT LIKE 'CONTACT%'
     ORDER BY last_update_date ASC;
  
    FOR i IN 1 .. party_relationship_tbl.COUNT LOOP
      fnd_file.put_line(fnd_file.log,
                        '**************Creating/Updating Party Relationship ' || i ||
                        ' ***************************');
      relationship_rec := NULL;
      BEGIN
        SELECT party_id
          INTO l_subject_party_id
          FROM hz_parties
         WHERE party_number = to_char(party_relationship_tbl(i).subject_party_number);
        SELECT party_id
          INTO l_object_party_id
          FROM hz_parties
         WHERE party_number = to_char(party_relationship_tbl(i).object_party_number);
      
        relationship_rec.subject_id        := l_subject_party_id;
        relationship_rec.subject_type      := party_relationship_tbl(i).subject_type;
        relationship_rec.object_id         := l_object_party_id;
        relationship_rec.object_type       := party_relationship_tbl(i).object_type;
        relationship_rec.relationship_code := party_relationship_tbl(i).relationship_code;
        relationship_rec.relationship_type := party_relationship_tbl(i).relationship_type;
        relationship_rec.start_date        := party_relationship_tbl(i).start_date;
        relationship_rec.end_date          := party_relationship_tbl(i).end_date;
        relationship_rec.comments          := party_relationship_tbl(i).comments;
      
        -----Checking Cross Reference----
        l_legacy_relationship_id := xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-PARTYRELATION',
                                                                                   party_relationship_tbl(i)
                                                                                   .relationship_id);
      
        IF l_legacy_relationship_id IS NULL THEN
        
          ------Call procedure create_party_relationship to create party relationship------
          xxhz_s3_legacy_acc_api_pkg.create_party_relationship(relationship_rec,
                                                               x_relationship_id,
                                                               x_api_status,
                                                               x_api_message);
          IF x_api_status = 'S' THEN
            -------Updating cross reference table if party relation is created successfully-----
            xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table(p_entity_name => 'ACCT-PARTYRELATION',
                                                                  p_legacy_id   => to_char(x_relationship_id),
                                                                  p_s3_id       => to_char(party_relationship_tbl(i)
                                                                                           .relationship_id),
                                                                  p_org_id      => '',
                                                                  p_attribute1  => '',
                                                                  p_attribute2  => '',
                                                                  p_attribute3  => '',
                                                                  p_attribute4  => '',
                                                                  p_attribute5  => '',
                                                                  p_err_code    => x_err_code,
                                                                  p_err_message => x_api_message);
          
          END IF;
        ELSIF l_legacy_relationship_id IS NOT NULL THEN
          relationship_rec.relationship_id := l_legacy_relationship_id;
          -----call procedure update_party_relationship to update the party relationship---
          xxhz_s3_legacy_acc_api_pkg.update_party_relationship(relationship_rec,
                                                               x_api_status,
                                                               x_api_message);
        END IF;
        -------Updating Status into events table---
        IF x_api_status = 'S' THEN
          xxssys_event_pkg_s3.update_success(party_relationship_tbl(i).event_id);
        ELSE
          xxssys_event_pkg_s3.update_error(party_relationship_tbl(i).event_id,
                                           x_api_message);
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          xxssys_event_pkg_s3.update_error(party_relationship_tbl(i).event_id,
                                           'Party ' || party_relationship_tbl(i)
                                           .object_party_number || ' or ' ||
                                            party_relationship_tbl(i).object_party_number ||
                                            ' is not created in Leagacy for  event id ' ||
                                            party_relationship_tbl(i).event_id);
          fnd_file.put_line(fnd_file.log,
                            'Party ' || party_relationship_tbl(i)
                            .object_party_number || ' or ' || party_relationship_tbl(i)
                            .object_party_number || ' is not created in Leagacy for  event id ' ||
                             party_relationship_tbl(i).event_id);
        WHEN OTHERS THEN
          p_retcode := 2;
          fnd_file.put_line(fnd_file.log,
                            'Unexpected error occured at step 1.' || SQLERRM);
      END;
    END LOOP;
    COMMIT;
  END pull_relationship;
  -------------------------------------------------------------------
  --  name:               pull_acc_relationship
  --  create by:          TCS
  --  $Revision:          1.0
  --  creation date:      17/08/2016
  --- Description:        This procedure will collect the Customer account relationship data from  s3 environment
  --                      and will create or update those account relationship data into Legacy environment through
  --                      Oracle standard API
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    TCS       initial build
  --------------------------------------------------------------------
  PROCEDURE pull_acc_relationship(p_errbuf     OUT VARCHAR2,
                                  p_retcode    OUT NUMBER,
                                  p_batch_size IN NUMBER) IS
  
    l_legacy_cust_acct_relate_id VARCHAR2(100);
    x_err_code                   VARCHAR2(100);
    x_api_status                 VARCHAR2(10);
    x_api_message                VARCHAR2(4000);
    l_ou_name                    fnd_lookup_values.description%TYPE;
    l_rel_cust_acct_id           NUMBER;
    l_cust_acct_id               NUMBER;
    l_org_id                     NUMBER;
    x_relate_cust_acc_id         NUMBER;
    TYPE account_relationship_rec IS TABLE OF apps.xxhz_acct_relate_legacy_int_v@source_s3%ROWTYPE INDEX BY BINARY_INTEGER;
    account_relationship_tbl account_relationship_rec;
    cust_acct_relate_rec     hz_cust_account_v2pub.cust_acct_relate_rec_type;
  BEGIN
    fnd_global.apps_initialize(user_id      => g_user_id,
                               resp_id      => g_resp_id,
                               resp_appl_id => g_application_id);
  
    SELECT * BULK COLLECT
      INTO account_relationship_tbl
      FROM apps.xxhz_acct_relate_legacy_int_v@source_s3
     WHERE 1 = 1
       AND rownum <= p_batch_size
     ORDER BY last_update_date ASC;
  
    FOR i IN 1 .. account_relationship_tbl.COUNT LOOP
      fnd_file.put_line(fnd_file.log,
                        '**************Creating/Updating Account Relationship' || i ||
                        ' ***************************');
      cust_acct_relate_rec := NULL;
    
      l_cust_acct_id                               := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-NUMBER',
                                                                                                               to_char(account_relationship_tbl(i)
                                                                                                                       .cust_account_id)));
      l_rel_cust_acct_id                           := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-NUMBER',
                                                                                                               to_char(account_relationship_tbl(i)
                                                                                                                       .related_cust_account_id)));
      cust_acct_relate_rec.cust_account_id         := l_cust_acct_id;
      cust_acct_relate_rec.related_cust_account_id := l_rel_cust_acct_id;
    
      -----Checking Cross Reference----
      l_legacy_cust_acct_relate_id                  := xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-RELATIONSHIP',
                                                                                                      to_char(account_relationship_tbl(i)
                                                                                                              .cust_acct_relate_id));
      cust_acct_relate_rec.relationship_type        := account_relationship_tbl(i)
                                                      .relationship_type;
      cust_acct_relate_rec.customer_reciprocal_flag := account_relationship_tbl(i)
                                                      .customer_reciprocal_flag;
      cust_acct_relate_rec.status                   := account_relationship_tbl(i)
                                                      .account_relation_status;
      cust_acct_relate_rec.bill_to_flag             := account_relationship_tbl(i).bill_to_flag;
      cust_acct_relate_rec.ship_to_flag             := account_relationship_tbl(i).ship_to_flag;
      BEGIN
        SELECT description
          INTO l_ou_name
          FROM fnd_lookup_values
         WHERE lookup_type = 'XXHZ_S3_LEGACY_OU_MAPPING'
           AND meaning = account_relationship_tbl(i).organization_name
           AND LANGUAGE = 'US';
      
        SELECT organization_id INTO l_org_id FROM hr_operating_units WHERE NAME = l_ou_name;
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,
                            'Error in finding Operating Unit...' || SQLERRM);
          l_org_id := '';
      END;
    
      cust_acct_relate_rec.org_id := l_org_id;
    
      IF l_legacy_cust_acct_relate_id IS NULL THEN
        cust_acct_relate_rec.created_by_module := 'TCA_V1_API';
        -----call procedure create_account_relationship to create the account relationship---
        xxhz_s3_legacy_acc_api_pkg.create_account_relationship(cust_acct_relate_rec,
                                                               x_relate_cust_acc_id,
                                                               x_api_status,
                                                               x_api_message);
        IF x_api_status = 'S' THEN
          -------Updating cross reference table if account relation is created successfully-----
          xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table(p_entity_name => 'ACCT-RELATIONSHIP',
                                                                p_legacy_id   => to_char(x_relate_cust_acc_id),
                                                                p_s3_id       => to_char(account_relationship_tbl(i)
                                                                                         .cust_acct_relate_id),
                                                                p_org_id      => '',
                                                                p_attribute1  => '',
                                                                p_attribute2  => '',
                                                                p_attribute3  => '',
                                                                p_attribute4  => '',
                                                                p_attribute5  => '',
                                                                p_err_code    => x_err_code,
                                                                p_err_message => x_api_message);
        END IF;
      ELSIF l_legacy_cust_acct_relate_id IS NOT NULL THEN
        cust_acct_relate_rec.cust_acct_relate_id := to_number(l_legacy_cust_acct_relate_id);
        -----call procedure update_account_relationship to update the account relationship---
        xxhz_s3_legacy_acc_api_pkg.update_account_relationship(cust_acct_relate_rec,
                                                               x_api_status,
                                                               x_api_message);
      END IF;
      -------Updating Status into events table---
      IF x_api_status = 'S' THEN
        xxssys_event_pkg_s3.update_success(account_relationship_tbl(i).event_id);
      ELSE
        xxssys_event_pkg_s3.update_error(account_relationship_tbl(i).event_id,
                                         x_api_message);
      END IF;
    END LOOP;
    COMMIT;
  END pull_acc_relationship;

  PROCEDURE pull_acct_site(p_errbuf     OUT VARCHAR2,
                           p_retcode    OUT NUMBER,
                           p_batch_size IN NUMBER) IS
  
    x_err_code               VARCHAR2(100);
    x_api_message            VARCHAR2(4000);
    l_error_msg              VARCHAR2(4000);
    x_api_status             VARCHAR2(10);
    x_api_msg                VARCHAR2(4000);
    l_ou_name                fnd_lookup_values.description%TYPE;
    l_loc_cnt                NUMBER := 0;
    l_party_site_cnt         NUMBER := 0;
    l_org_id                 NUMBER;
    l_legacy_party_id        NUMBER;
    l_legacy_cust_account_id NUMBER;
    x_location_id            NUMBER;
    l_legacy_location_id     NUMBER;
    l_cust_acct_site_id      NUMBER;
    l_party_site_id          NUMBER;
    l_legacy_acct_sites_id   NUMBER;
    l_party_site_number      NUMBER;
    cust_acct_site_rec       hz_cust_account_site_v2pub.cust_acct_site_rec_type;
    location_rec             hz_location_v2pub.location_rec_type;
    party_site_rec           hz_party_site_v2pub.party_site_rec_type;
  
    l_object_version_number NUMBER;
  
    TYPE l_hz_acct_site_val_rec IS TABLE OF apps.xxhz_acct_site_legacy_int_v@source_s3%ROWTYPE INDEX BY BINARY_INTEGER;
  
    l_hz_acct_site_val_tab l_hz_acct_site_val_rec;
  
  BEGIN
  
    fnd_global.apps_initialize(user_id      => g_user_id,
                               resp_id      => g_resp_id,
                               resp_appl_id => g_application_id);
  
    BEGIN
      SELECT * BULK COLLECT
        INTO l_hz_acct_site_val_tab
        FROM apps.xxhz_acct_site_legacy_int_v@source_s3
       WHERE rownum <= p_batch_size
         AND status = 'NEW'
       ORDER BY last_update_date ASC;
    EXCEPTION
      WHEN OTHERS THEN
        l_error_msg := SQLERRM;
        fnd_file.put_line(fnd_file.log,
                          l_error_msg);
    END;
  
    FOR i IN 1 .. l_hz_acct_site_val_tab.COUNT LOOP
      location_rec             := NULL;
      party_site_rec           := NULL;
      cust_acct_site_rec       := NULL;
      location_rec.country     := l_hz_acct_site_val_tab(i).country;
      location_rec.address1    := l_hz_acct_site_val_tab(i).address1;
      location_rec.address2    := l_hz_acct_site_val_tab(i).address2;
      location_rec.address3    := l_hz_acct_site_val_tab(i).address3;
      location_rec.address4    := l_hz_acct_site_val_tab(i).address4;
      location_rec.city        := l_hz_acct_site_val_tab(i).city;
      location_rec.postal_code := l_hz_acct_site_val_tab(i).postal_code;
      location_rec.state       := l_hz_acct_site_val_tab(i).state;
      location_rec.province    := l_hz_acct_site_val_tab(i).province;
      location_rec.county      := l_hz_acct_site_val_tab(i).county;
    
      party_site_rec.party_site_number := l_hz_acct_site_val_tab(i).party_site_number;
    
      party_site_rec.status                   := l_hz_acct_site_val_tab(i).party_status;
      party_site_rec.party_site_name          := l_hz_acct_site_val_tab(i).site_name;
      party_site_rec.identifying_address_flag := l_hz_acct_site_val_tab(i).identifying_address_flag;
    
      cust_acct_site_rec.status := l_hz_acct_site_val_tab(i).site_status;
    
      l_legacy_acct_sites_id   := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-SITES',
                                                                                           l_hz_acct_site_val_tab(i)
                                                                                           .cust_acct_site_id));
      l_legacy_cust_account_id := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-NUMBER',
                                                                                           l_hz_acct_site_val_tab(i)
                                                                                           .cust_account_id));
    
      IF l_legacy_cust_account_id IS NOT NULL THEN
        fnd_file.put_line(fnd_file.log,
                          '*************************Creating Account Site : Party Site Number ' ||
                           l_hz_acct_site_val_tab(i)
                          .party_site_number || ' **********************************');
      
        BEGIN
          SELECT party_id
            INTO l_legacy_party_id
            FROM hz_cust_accounts
           WHERE cust_account_id = l_legacy_cust_account_id;
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := SQLERRM;
            fnd_file.put_line(fnd_file.log,
                              l_error_msg);
        END;
        -- Check If Location For the Party Site Exists Or Not.
        BEGIN
          SELECT COUNT(1)
            INTO l_loc_cnt
            FROM hz_locations
           WHERE orig_system_reference = to_char(l_hz_acct_site_val_tab(i).location_id);
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'Unexpected Error Happened while Fetching Location Information';
            fnd_file.put_line(fnd_file.log,
                              l_error_msg);
        END;
      
        IF (l_loc_cnt = 0) THEN
          location_rec.orig_system_reference := to_char(l_hz_acct_site_val_tab(i).location_id);
          location_rec.created_by_module     := 'TCA_V1_API';
          -- Call Location Creation Procedure to Create Location .
          xxhz_s3_legacy_acc_api_pkg.create_location(location_rec,
                                                     x_location_id,
                                                     x_api_status,
                                                     x_api_msg);
          l_legacy_location_id := x_location_id;
        
        ELSE
          BEGIN
            SELECT location_id,
                   object_version_number
              INTO l_legacy_location_id,
                   l_object_version_number
              FROM hz_locations
             WHERE orig_system_reference = to_char(l_hz_acct_site_val_tab(i).location_id);
          EXCEPTION
            WHEN OTHERS THEN
              l_error_msg          := SQLERRM;
              l_legacy_location_id := NULL;
          END;
          location_rec.location_id := l_legacy_location_id;
        
          BEGIN
            SELECT COUNT(1)
              INTO l_party_site_cnt
              FROM hz_party_sites
             WHERE location_id = l_legacy_location_id;
          
            SELECT party_site_id
              INTO l_party_site_id
              FROM hz_party_sites
             WHERE location_id = l_legacy_location_id
               AND rownum < 2;
          
          EXCEPTION
            WHEN OTHERS THEN
              l_party_site_cnt := 0;
              l_party_site_id  := NULL;
          END;
        END IF;
      
        IF (l_party_site_cnt = 0) OR (l_loc_cnt = 0) THEN
        
          party_site_rec.party_id              := l_legacy_party_id;
          party_site_rec.location_id           := l_legacy_location_id;
          party_site_rec.created_by_module     := 'TCA_V1_API';
          party_site_rec.orig_system_reference := to_char(l_hz_acct_site_val_tab(i).party_site_id);
          xxhz_s3_legacy_acc_api_pkg.create_party_site(party_site_rec,
                                                       l_party_site_id,
                                                       l_party_site_number);
        END IF;
        ---------------
      
        IF l_legacy_acct_sites_id IS NULL THEN
        
          cust_acct_site_rec.cust_account_id := l_legacy_cust_account_id;
        
          cust_acct_site_rec.party_site_id         := l_party_site_id;
          cust_acct_site_rec.orig_system_reference := to_char(l_hz_acct_site_val_tab(i)
                                                              .cust_acct_site_id);
          cust_acct_site_rec.created_by_module     := 'TCA_V1_API';
          BEGIN
            SELECT description
              INTO l_ou_name
              FROM fnd_lookup_values
             WHERE lookup_type = 'XXHZ_S3_LEGACY_OU_MAPPING'
               AND meaning = l_hz_acct_site_val_tab(i).org_name
               AND LANGUAGE = 'US';
          
            SELECT organization_id INTO l_org_id FROM hr_operating_units WHERE NAME = l_ou_name;
            cust_acct_site_rec.org_id := l_org_id;
          EXCEPTION
            WHEN OTHERS THEN
              l_org_id := '';
          END;
          xxhz_s3_legacy_acc_api_pkg.create_acct_site(cust_acct_site_rec,
                                                      l_cust_acct_site_id,
                                                      x_api_status,
                                                      x_api_msg);
          IF x_api_status = 'S' THEN
            xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table(p_entity_name => 'ACCT-SITES',
                                                                  p_legacy_id   => to_char(l_cust_acct_site_id),
                                                                  p_s3_id       => to_char(l_hz_acct_site_val_tab(i)
                                                                                           .cust_acct_site_id),
                                                                  p_org_id      => '',
                                                                  p_attribute1  => '',
                                                                  p_attribute2  => '',
                                                                  p_attribute3  => '',
                                                                  p_attribute4  => '',
                                                                  p_attribute5  => '',
                                                                  p_err_code    => x_err_code,
                                                                  p_err_message => x_api_message);
          END IF;
        END IF;
      END IF;
      ----If site is inactivated
      IF l_hz_acct_site_val_tab(i).event_name = 'oracle.apps.ar.hz.PartySite.update' THEN
        fnd_file.put_line(fnd_file.log,
                          '*************************Updating Account Site: Party Site Number ' ||
                           l_hz_acct_site_val_tab(i)
                          .party_site_number || ' **********************************');
        BEGIN
          SELECT party_site_id,
                 object_version_number
            INTO l_party_site_id,
                 l_object_version_number
            FROM hz_party_sites
           WHERE party_site_number = l_hz_acct_site_val_tab(i).party_site_number;
        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log,
                              'Error in Finding party site id...' || SQLERRM);
            l_object_version_number := 1;
        END;
        party_site_rec.party_site_id := l_party_site_id;
        party_site_rec.status        := l_hz_acct_site_val_tab(i).party_status;
        xxhz_s3_legacy_acc_api_pkg.update_party_sites(party_site_rec,
                                                      l_object_version_number,
                                                      x_api_status,
                                                      x_api_message);
      
      END IF;
      -----If only Address is updated
      IF l_hz_acct_site_val_tab(i).event_name = 'oracle.apps.ar.hz.Location.update' THEN
        BEGIN
          SELECT location_id,
                 object_version_number
            INTO l_legacy_location_id,
                 l_object_version_number
            FROM hz_locations
           WHERE orig_system_reference = to_char(l_hz_acct_site_val_tab(i).location_id);
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg          := SQLERRM;
            l_legacy_location_id := NULL;
        END;
        IF l_legacy_location_id IS NOT NULL THEN
          location_rec.location_id := l_legacy_location_id;
          xxhz_s3_legacy_acc_api_pkg.update_loc(location_rec,
                                                l_object_version_number,
                                                x_api_status,
                                                x_api_message);
        
        END IF;
      END IF;
    
      IF x_api_status = 'S' THEN
        xxssys_event_pkg_s3.update_success(l_hz_acct_site_val_tab(i).event_id);
      ELSE
        xxssys_event_pkg_s3.update_error(l_hz_acct_site_val_tab(i).event_id,
                                         x_api_message);
      END IF;
    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'Unexpected Error--' || SQLERRM;
      fnd_file.put_line(fnd_file.log,
                        l_error_msg);
    
  END pull_acct_site;

  /*******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Conversion Name     :                                                                                                                   *
  * Name                : pull_acct_site_use                                                                                                *
  * Script Name         : pull_acct_site_use.prc                                                                                            *
  *                                                                                                                                         *
                                                                                                                                            *
  * Purpose             : This Procedure is Used to Pull Account Site Uses Data from S3 environment                                         *
                          & create the same in Legacy Environment                                                                           *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                     *
  * -------  ----------- ---------------    ------------------------------------                                                            *
  * 1.00     16/08/2016  Somnath Dawn       
  ******************************************************************************************************************************************/

  PROCEDURE pull_acct_site_use(p_errbuf     OUT VARCHAR2,
                               p_retcode    OUT NUMBER,
                               p_batch_size IN NUMBER) IS
  
    x_api_message             VARCHAR2(4000);
    l_var_error_msg           VARCHAR2(2000);
    l_error_msg               VARCHAR2(4000);
    x_api_status              VARCHAR2(1);
    x_api_msg                 VARCHAR2(4000);
    x_err_code                VARCHAR2(100);
    l_fob                     VARCHAR2(100);
    l_freight                 VARCHAR2(100);
    l_legacy_fob              VARCHAR2(100);
    l_legacy_freight          VARCHAR2(100);
    l_site_use_id             NUMBER;
    l_object_version_number   NUMBER;
    l_legacy_location_id      NUMBER;
    x_location_id             NUMBER;
    l_party_site_id           NUMBER;
    l_cust_acct_site_id       NUMBER;
    l_party_site_number       VARCHAR2(100);
    l_price_list_id           NUMBER;
    l_payment_term_id         NUMBER;
    l_salesrep_id             NUMBER;
    l_org_id                  NUMBER;
    l_legacy_acct_sites_id    NUMBER;
    l_legacy_cust_account_id  NUMBER;
    l_ou_name                 VARCHAR2(100);
    l_legacy_acct_site_use_id NUMBER;
    l_legacy_party_id         NUMBER;
    l_bill_to_site_use_id     NUMBER;
    l_cust_account_id         NUMBER;
    cust_acct_site_rec        hz_cust_account_site_v2pub.cust_acct_site_rec_type;
    location_rec              hz_location_v2pub.location_rec_type;
    party_site_rec            hz_party_site_v2pub.party_site_rec_type;
    cust_site_use_rec         hz_cust_account_site_v2pub.cust_site_use_rec_type;
  
    TYPE l_hz_site_use_val_rec IS TABLE OF apps.xxhz_site_use_legacy_int_v@source_s3 %ROWTYPE INDEX BY BINARY_INTEGER;
    l_hz_site_use_val_tab l_hz_site_use_val_rec;
  
  BEGIN
  
    BEGIN
      SELECT * BULK COLLECT
        INTO l_hz_site_use_val_tab
        FROM apps.xxhz_site_use_legacy_int_v@source_s3
       WHERE status = 'NEW'
         AND rownum <= p_batch_size
      --AND event_id = 99867
       ORDER BY site_use_code;
    EXCEPTION
      WHEN OTHERS THEN
        l_error_msg := 'Unexpected error has occured while retrieving the Data ' || SQLERRM;
        fnd_file.put_line(fnd_file.log,
                          l_error_msg);
    END;
    FOR i IN 1 .. l_hz_site_use_val_tab.COUNT LOOP
      fnd_file.put_line(fnd_file.log,
                        'Event ID=' || l_hz_site_use_val_tab(i).event_id);
      cust_site_use_rec := NULL;
      x_api_status      := '';
      x_api_msg         := '';
      -- Checks If the Cust Account Site Already Exists or not .
      l_legacy_acct_site_use_id := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-SITE-USES', --'ACCT-SITEUSE',
                                                                                            l_hz_site_use_val_tab(i)
                                                                                            .site_use_id));
      l_legacy_acct_sites_id    := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-SITES',
                                                                                            l_hz_site_use_val_tab(i)
                                                                                            .cust_acct_site_id));
    
      BEGIN
        SELECT cust_account_id
          INTO l_cust_account_id
          FROM apps.hz_cust_acct_sites_all@source_s3 hcasa
         WHERE cust_acct_site_id = l_hz_site_use_val_tab(i).cust_acct_site_id;
        fnd_file.put_line(fnd_file.log,
                          'After 1st Query..');
        l_legacy_cust_account_id := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-NUMBER',
                                                                                             l_cust_account_id));
      
        IF l_legacy_cust_account_id IS NULL THEN
          x_api_msg := 'S3 account id not found in Reference table or the Account is not created for which site use needs to be created.';
          xxssys_event_pkg_s3.update_error(l_hz_site_use_val_tab(i).event_id,
                                           x_api_msg);
        END IF;
      
        fnd_file.put_line(fnd_file.log,
                          'After 2nd Query..');
        IF l_legacy_cust_account_id IS NOT NULL THEN
          SELECT party_id
            INTO l_legacy_party_id
            FROM hz_cust_accounts_all
           WHERE cust_account_id = l_legacy_cust_account_id;
          fnd_file.put_line(fnd_file.log,
                            'After 3rd Query..');
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,
                            'Error...' || SQLERRM);
          l_cust_account_id := NULL;
          l_legacy_party_id := NULL;
      END;
    
      IF l_legacy_acct_sites_id IS NULL AND l_legacy_cust_account_id IS NOT NULL THEN
      
        location_rec.country               := l_hz_site_use_val_tab(i).country;
        location_rec.address1              := l_hz_site_use_val_tab(i).address1;
        location_rec.address2              := l_hz_site_use_val_tab(i).address2;
        location_rec.address3              := l_hz_site_use_val_tab(i).address3;
        location_rec.address4              := l_hz_site_use_val_tab(i).address4;
        location_rec.city                  := l_hz_site_use_val_tab(i).city;
        location_rec.postal_code           := l_hz_site_use_val_tab(i).postal_code;
        location_rec.state                 := l_hz_site_use_val_tab(i).state;
        location_rec.province              := l_hz_site_use_val_tab(i).province;
        location_rec.county                := l_hz_site_use_val_tab(i).county;
        location_rec.orig_system_reference := to_char(l_hz_site_use_val_tab(i).location_id);
        location_rec.created_by_module     := 'TCA_V1_API';
        xxhz_s3_legacy_acc_api_pkg.create_location(location_rec,
                                                   x_location_id,
                                                   x_api_status,
                                                   x_api_msg);
        l_legacy_location_id := x_location_id;
        BEGIN
          SELECT party_site_id
            INTO l_party_site_id
            FROM hz_party_sites
           WHERE party_site_number = to_char(l_hz_site_use_val_tab(i).party_site_number);
        EXCEPTION
          WHEN OTHERS THEN
            l_party_site_id := NULL;
        END;
        IF l_party_site_id IS NULL THEN
          fnd_file.put_line(fnd_file.log,
                            'Here 1...');
          party_site_rec.party_site_number := l_hz_site_use_val_tab(i).party_site_number;
        
          party_site_rec.status                   := l_hz_site_use_val_tab(i).party_site_status;
          party_site_rec.party_site_name          := l_hz_site_use_val_tab(i).party_site_name;
          party_site_rec.identifying_address_flag := l_hz_site_use_val_tab(i)
                                                    .identifying_address_flag;
          party_site_rec.party_id                 := l_legacy_party_id;
          party_site_rec.location_id              := l_legacy_location_id;
          party_site_rec.created_by_module        := 'TCA_V1_API';
          party_site_rec.orig_system_reference    := to_char(l_hz_site_use_val_tab(i).party_site_id);
          xxhz_s3_legacy_acc_api_pkg.create_party_site(party_site_rec,
                                                       l_party_site_id,
                                                       l_party_site_number);
          fnd_file.put_line(fnd_file.log,
                            'Here 2...l_party_site_id=' || l_party_site_id);
        END IF;
        cust_acct_site_rec.cust_account_id := l_legacy_cust_account_id;
      
        cust_acct_site_rec.party_site_id         := l_party_site_id;
        cust_acct_site_rec.orig_system_reference := to_char(l_hz_site_use_val_tab(i)
                                                            .cust_acct_site_id);
        cust_acct_site_rec.created_by_module     := 'TCA_V1_API';
        BEGIN
          SELECT description
            INTO l_ou_name
            FROM fnd_lookup_values
           WHERE lookup_type = 'XXHZ_S3_LEGACY_OU_MAPPING'
             AND meaning = l_hz_site_use_val_tab(i).org_name
             AND LANGUAGE = 'US';
        
          SELECT organization_id INTO l_org_id FROM hr_operating_units WHERE NAME = l_ou_name;
        
          cust_acct_site_rec.org_id := l_org_id;
          cust_acct_site_rec.status := l_hz_site_use_val_tab(i).party_site_status;
          fnd_file.put_line(fnd_file.log,
                            'Here 3...');

          xxhz_s3_legacy_acc_api_pkg.create_acct_site(cust_acct_site_rec,
                                                      l_cust_acct_site_id,
                                                      x_api_status,
                                                      x_api_msg);
          fnd_file.put_line(fnd_file.log,
                            'Here 4...');
          l_legacy_acct_sites_id := l_cust_acct_site_id;
          IF x_api_status = 'S' THEN
            xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table(p_entity_name => 'ACCT-SITES',
                                                                  p_legacy_id   => to_char(l_cust_acct_site_id),
                                                                  p_s3_id       => to_char(l_hz_site_use_val_tab(i)
                                                                                           .cust_acct_site_id),
                                                                  p_org_id      => '',
                                                                  p_attribute1  => '',
                                                                  p_attribute2  => '',
                                                                  p_attribute3  => '',
                                                                  p_attribute4  => '',
                                                                  p_attribute5  => '',
                                                                  p_err_code    => x_err_code,
                                                                  p_err_message => x_api_message);
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
      
        /*   xxssys_event_pkg_s3.update_error(l_hz_site_use_val_tab(i).event_id,
        'Cust Account Site is not present in Legacy..');*/
      ELSIF l_legacy_acct_sites_id IS NOT NULL AND l_legacy_cust_account_id IS NOT NULL THEN
      
        cust_site_use_rec.bill_to_site_use_id := NULL;
        IF l_hz_site_use_val_tab(i).site_use_code = 'SHIP_TO' THEN
          l_bill_to_site_use_id                 := to_number(xxcust_convert_xref_pkg.get_legacy_id_by_s3_id('ACCT-SITE-USES', --'ACCT-SITEUSE',
                                                                                                            l_hz_site_use_val_tab(i)
                                                                                                            .bill_to_site_use_id));
          cust_site_use_rec.bill_to_site_use_id := l_bill_to_site_use_id;
          cust_site_use_rec.attribute_category  := 'SHIP_TO';
          cust_site_use_rec.attribute10         := l_hz_site_use_val_tab(i).shipping_instruction;
          cust_site_use_rec.attribute12         := l_hz_site_use_val_tab(i)
                                                  .collect_shipping_account;
        END IF;
      
        cust_site_use_rec.site_use_code := l_hz_site_use_val_tab(i).site_use_code;
        cust_site_use_rec.primary_flag  := l_hz_site_use_val_tab(i).primary_flag;
        /*IF l_hz_site_use_val_tab(i).primary_flag = 'Y' THEN
          IF l_hz_site_use_val_tab(i).site_use_status = 'A' THEN
            cust_site_use_rec.primary_flag := l_hz_site_use_val_tab(i).primary_flag;
          END IF;
        ELSIF l_hz_site_use_val_tab(i).primary_flag = 'N' THEN
          cust_site_use_rec.primary_flag := l_hz_site_use_val_tab(i).primary_flag;
        END IF;*/
        cust_site_use_rec.status            := l_hz_site_use_val_tab(i).site_use_status;
        cust_site_use_rec.cust_acct_site_id := l_legacy_acct_sites_id;
        -- cust_site_use_rec.location                     := l_hz_site_use_val_tab(i).location;
        cust_site_use_rec.ship_via                     := l_hz_site_use_val_tab(i).ship_method;
        cust_site_use_rec.ship_sets_include_lines_flag := l_hz_site_use_val_tab(i)
                                                         .ship_set_include_flag;
      
        IF l_hz_site_use_val_tab(i).fob_point IS NOT NULL THEN
          BEGIN
            SELECT meaning,
                   description
              INTO l_freight,
                   l_fob
              FROM fnd_lookup_values
             WHERE lookup_type = 'XXHZ_INCOTERM_LOOKUP'
               AND LANGUAGE = 'US'
               AND lookup_code = l_hz_site_use_val_tab(i).fob_point;
          EXCEPTION
            WHEN OTHERS THEN
              fnd_file.put_line(fnd_file.log,
                                'Error finding Freight term and FOB :' || SQLERRM);
              l_freight := NULL;
              l_fob     := NULL;
          END;
          IF l_freight IS NOT NULL THEN
            BEGIN
              SELECT lookup_code
                INTO l_legacy_freight
                FROM fnd_lookup_values
               WHERE lookup_type = 'FREIGHT_TERMS'
                 AND LANGUAGE = 'US'
                 AND meaning = l_freight;
            EXCEPTION
              WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log,
                                  'Error finding Freight term :' || SQLERRM);
                l_legacy_freight := NULL;
            END;
          END IF;
          IF l_fob IS NOT NULL THEN
            BEGIN
              SELECT lookup_code
                INTO l_legacy_fob
                FROM fnd_lookup_values
               WHERE lookup_type = 'FOB'
                 AND LANGUAGE = 'US'
                 AND tag = 'Y'
                 AND meaning = l_fob;
            EXCEPTION
              WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log,
                                  'Error finding FOB :' || SQLERRM);
                l_legacy_fob := NULL;
              
            END;
          END IF;
        END IF;
        IF l_hz_site_use_val_tab(i).sales_person IS NOT NULL THEN
          BEGIN
          
            SELECT rs.salesrep_id
              INTO l_salesrep_id
              FROM apps.jtf_rs_salesreps         rs,
                   apps.jtf_rs_resource_extns_vl res,
                   hr_organization_units         hou
             WHERE hou.organization_id = rs.org_id
               AND rs.resource_id = res.resource_id
               AND resource_name = l_hz_site_use_val_tab(i)
            .sales_person
               AND nvl(res.end_date_active,
                       trunc(SYSDATE)) >= trunc(SYSDATE); --May need to add org_id condition
          
          EXCEPTION
            WHEN OTHERS THEN
              fnd_file.put_line(fnd_file.log,
                                'Error finding Sales person :' || l_hz_site_use_val_tab(i)
                                .sales_person || '  ' || SQLERRM);
              l_freight := NULL;
              l_fob     := NULL;
          END;
        END IF;
        cust_site_use_rec.fob_point                      := l_legacy_fob;
        cust_site_use_rec.freight_term                   := l_legacy_freight;
        cust_site_use_rec.arrivalsets_include_lines_flag := l_hz_site_use_val_tab(i)
                                                           .arrival_set_include_flag;
        IF l_hz_site_use_val_tab(i).site_use_code = 'BILL_TO' THEN
          cust_site_use_rec.primary_salesrep_id := l_salesrep_id;
        END IF;
        -----Query for Pricelist
        BEGIN
          SELECT price_list_id
            INTO l_price_list_id
            FROM qp_price_lists_v
           WHERE NAME = l_hz_site_use_val_tab(i).price_list;
        EXCEPTION
          WHEN no_data_found THEN
            l_price_list_id := NULL;
            fnd_file.put_line(fnd_file.log,
                              'Price List ' || l_hz_site_use_val_tab(i)
                              .price_list || ' is not found...');
          WHEN OTHERS THEN
            l_price_list_id := NULL;
        END;
        -----Query for Payment Terms
        BEGIN
          SELECT term_id
            INTO l_payment_term_id
            FROM ra_terms
           WHERE NAME = l_hz_site_use_val_tab(i).payment_term
             AND nvl(end_date_active,
                     trunc(SYSDATE)) >= trunc(SYSDATE);
        EXCEPTION
          WHEN no_data_found THEN
            l_payment_term_id := NULL;
            fnd_file.put_line(fnd_file.log,
                              'Payment Term ' || l_hz_site_use_val_tab(i)
                              .payment_term || ' is not found...');
          WHEN OTHERS THEN
            l_payment_term_id := NULL;
        END;
        cust_site_use_rec.payment_term_id := nvl(l_payment_term_id,
                                                 fnd_api.g_null_num);
        cust_site_use_rec.price_list_id   := nvl(l_price_list_id,
                                                 fnd_api.g_null_num);
        IF l_legacy_acct_site_use_id IS NULL THEN
          fnd_file.put_line(fnd_file.log,
                            '*************************Creating Account Site Use : Event ID ' ||
                            l_hz_site_use_val_tab(i).event_id);
          cust_site_use_rec.location              := l_hz_site_use_val_tab(i).location;
          cust_site_use_rec.orig_system_reference := l_hz_site_use_val_tab(i).site_use_id;
          cust_site_use_rec.created_by_module     := 'TCA_V1_API';
          xxhz_s3_legacy_acc_api_pkg.create_acct_site_use(cust_site_use_rec,
                                                          l_site_use_id,
                                                          x_api_status,
                                                          x_api_msg);
          fnd_file.put_line(fnd_file.log,
                            'After api call x_api_msg=' || x_api_msg);
          IF x_api_status = 'S' THEN
            fnd_file.put_line(fnd_file.log,
                              'Before Inserting....');
            xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table(p_entity_name => 'ACCT-SITE-USES', --'ACCT-SITEUSE',
                                                                  p_legacy_id   => to_char(l_site_use_id),
                                                                  p_s3_id       => to_char(l_hz_site_use_val_tab(i)
                                                                                           .site_use_id),
                                                                  p_org_id      => '',
                                                                  p_attribute1  => '',
                                                                  p_attribute2  => '',
                                                                  p_attribute3  => '',
                                                                  p_attribute4  => '',
                                                                  p_attribute5  => '',
                                                                  p_err_code    => x_err_code,
                                                                  p_err_message => x_api_message);
          
            fnd_file.put_line(fnd_file.log,
                              'l_site_use_id=' || l_site_use_id);
            fnd_file.put_line(fnd_file.log,
                              'l_hz_site_use_val_tab(i).site_use_id=' || l_hz_site_use_val_tab(i)
                              .site_use_id);
            fnd_file.put_line(fnd_file.log,
                              'After Inserting....');
          END IF;
        ELSIF l_legacy_acct_site_use_id IS NOT NULL THEN
          fnd_file.put_line(fnd_file.log,
                            '*************************Updating Account Site Use : Event ID ' ||
                            l_hz_site_use_val_tab(i).event_id);
          cust_site_use_rec.site_use_id := l_legacy_acct_site_use_id;
          BEGIN
            SELECT object_version_number
              INTO l_object_version_number
              FROM hz_cust_site_uses_all
             WHERE site_use_id = l_legacy_acct_site_use_id;
          EXCEPTION
            WHEN OTHERS THEN
              l_object_version_number := 1;
          END;
          xxhz_s3_legacy_acc_api_pkg.update_acct_site_use(cust_site_use_rec,
                                                          l_object_version_number,
                                                          x_api_status,
                                                          x_api_msg);
          fnd_file.put_line(fnd_file.log,
                            'Inside else x_api_status=' || x_api_status);
        END IF;
        fnd_file.put_line(fnd_file.log,
                          'outside else x_api_status=' || x_api_status);
        fnd_file.put_line(fnd_file.log,
                          'outside else x_api_msg=' || x_api_msg);
        IF x_api_status = 'S' THEN
          xxssys_event_pkg_s3.update_success(l_hz_site_use_val_tab(i).event_id);
        ELSE
          xxssys_event_pkg_s3.update_error(l_hz_site_use_val_tab(i).event_id,
                                           x_api_msg);
        END IF;
      END IF;
    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      l_var_error_msg := 'Unexpected Error' || SQLERRM;
      fnd_file.put_line(fnd_file.log,
                        l_var_error_msg);
  END pull_acct_site_use;
END xxhz_s3_legacy_int_pkg;
/
