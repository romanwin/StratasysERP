CREATE OR REPLACE PACKAGE BODY xxconv_hz_customers_pkg IS

  ---------------------------------------------------------------------------------
  -- Entity Name: xxconv_hz_customers_pkg
  -- Purpose    : CREATING CUSTOMERS
  -- Author     : Evgeniy Braiman
  -- Version    : 1.0
  ---------------------------------------------------------------------------------
  -- Version    Date       Author         Description
  ---------------------------------------------------------------------------------
  -- 1.0       28.6.05     Evgeniy         Initial Build
  -- 1.1       08/03/2010  Dalit A. Raviv  add procedure upd_cust_site_use
  -- 1.2       11/03/2010  Dalit A. Raviv  add procedure upd_party_site_att
  --                                                     upd_entity_id_for_prog
  -- 1.3       20/10/2010  Dalit A. Raviv  add procedure create_sf_contact,
  --                                                     upload_contact_point
  -- 1.4       15/11/2011  Dalit A. raviv  add procedure upload_cti_contact_phones
  -- 1.5       27/dec-2012 Ofer Suad       remove substr from postal code and load adress2 to location
  ---------------------------------------------------------------------------------
  -- 2.0       20/08/2013  Venu Kandi      Modified for US data migrations
  ---------------------------------------------------------------------------------
  -- 2.1       15/06/2014  Ofer Suad       CHG0032453 Modified for Korea data migrations
  -- 2.2       12/01/2016  Ofer Suad       CHG0037406 - Add Transfer to SF? logic

  g_user_id fnd_user.user_id%TYPE := NULL;
  g_org_id  NUMBER := NULL;
  g_create_by_module CONSTANT VARCHAR2(20) := 'SALESFORCE';

  PROCEDURE load_vertical_to_oracle(p_party_id    IN NUMBER,
			p_class_code  IN VARCHAR,
			p_ret_status  OUT VARCHAR,
			p_err_message OUT VARCHAR) IS
  
    lcode_assignment_rec_type hz_classification_v2pub.code_assignment_rec_type;
    x_return_status           VARCHAR2(4000);
    x_msg_count               NUMBER;
    x_msg_data                VARCHAR2(4000);
    x_code_assignment_id      NUMBER;
  
    i               NUMBER;
    x_msg_index_out NUMBER;
    l_data          VARCHAR2(1000);
    lv_error        VARCHAR2(4000);
  BEGIN
  
    lcode_assignment_rec_type.owner_table_name  := 'HZ_PARTIES';
    lcode_assignment_rec_type.owner_table_id    := p_party_id;
    lcode_assignment_rec_type.class_category    := 'Objet Business Type';
    lcode_assignment_rec_type.class_code        := p_class_code;
    lcode_assignment_rec_type.primary_flag      := 'N';
    lcode_assignment_rec_type.start_date_active := '01-JAN-2014';
    lcode_assignment_rec_type.created_by_module := 'CE';
  
    hz_classification_v2pub.create_code_assignment(fnd_api.g_false,
				   lcode_assignment_rec_type,
				   x_return_status,
				   x_msg_count,
				   x_msg_data,
				   x_code_assignment_id);
  
    p_ret_status := x_return_status; -- return status
  
    IF p_ret_status != fnd_api.g_ret_sts_success THEN
      BEGIN
        lv_error := NULL;
        FOR i IN 1 .. x_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => x_msg_index_out);
          lv_error := lv_error || l_data;
        END LOOP;
        p_err_message := lv_error;
      END;
    END IF;
  
  END load_vertical_to_oracle;

  PROCEDURE create_shorttext_attach(p_category_user_name IN VARCHAR2,
			p_pk_value1          IN NUMBER,
			p_short_text         IN VARCHAR2,
			x_return_status      OUT VARCHAR2,
			x_err_msg            OUT VARCHAR2) IS
    v_fnd_doc_s           NUMBER;
    v_fnd_short_doc_s     NUMBER;
    v_fnd_attach_doc_s    NUMBER;
    v_category_id         NUMBER;
    v_default_datatype_id NUMBER;
    v_seq_num             NUMBER;
    v_user_id             NUMBER;
  BEGIN
  
    x_return_status := fnd_api.g_ret_sts_success;
    v_user_id       := g_user_id;
  
    SELECT fnd_documents_s.nextval
    INTO   v_fnd_doc_s
    FROM   dual;
  
    SELECT fnd_documents_short_text_s.nextval
    INTO   v_fnd_short_doc_s
    FROM   dual;
  
    SELECT fnd_attached_documents_s.nextval
    INTO   v_fnd_attach_doc_s
    FROM   dual;
  
    SELECT category_id,
           default_datatype_id
    INTO   v_category_id,
           v_default_datatype_id
    FROM   fnd_doc_categories_active_vl
    WHERE  user_name = p_category_user_name;
    BEGIN
    
      INSERT INTO fnd_documents
        (document_id,
         creation_date,
         created_by,
         last_update_date,
         last_updated_by,
         last_update_login,
         datatype_id,
         category_id,
         security_type,
         media_id,
         publish_flag,
         image_type,
         storage_type,
         usage_type,
         start_date_active,
         end_date_active,
         request_id,
         program_application_id,
         program_id,
         program_update_date)
      VALUES
        (v_fnd_doc_s,
         SYSDATE,
         v_user_id,
         SYSDATE,
         v_user_id,
         v_user_id,
         v_default_datatype_id,
         v_category_id,
         4,
         v_fnd_short_doc_s,
         'Y',
         NULL,
         NULL,
         'O',
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL);
    
      IF SQL%NOTFOUND THEN
      
        x_return_status := fnd_api.g_ret_sts_error;
        x_err_msg       := 'Insert Into FND_DOCUMENTS_TL Failed';
        RETURN;
      
      END IF;
    
    END;
  
    BEGIN
    
      INSERT INTO fnd_documents_tl
        (document_id,
         creation_date,
         created_by,
         last_update_date,
         last_updated_by,
         last_update_login,
         LANGUAGE,
         description,
         file_name,
         media_id,
         request_id,
         program_application_id,
         program_id,
         program_update_date,
         doc_attribute_category,
         doc_attribute1,
         doc_attribute2,
         doc_attribute3,
         doc_attribute4,
         doc_attribute5,
         doc_attribute6,
         doc_attribute7,
         doc_attribute8,
         doc_attribute9,
         doc_attribute10,
         doc_attribute11,
         doc_attribute12,
         doc_attribute13,
         doc_attribute14,
         doc_attribute15,
         source_lang)
        SELECT v_fnd_doc_s,
	   SYSDATE,
	   v_user_id,
	   SYSDATE,
	   v_user_id,
	   v_user_id,
	   l.language_code,
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
	   NULL,
	   NULL,
	   NULL,
	   NULL,
	   NULL,
	   userenv('LANG')
        FROM   fnd_languages l
        WHERE  l.installed_flag IN ('I', 'B')
        AND    NOT EXISTS
         (SELECT NULL
	    FROM   fnd_documents_tl tl
	    WHERE  document_id = v_fnd_doc_s
	    AND    tl.language = l.language_code);
    
      IF SQL%NOTFOUND THEN
      
        x_return_status := fnd_api.g_ret_sts_error;
        x_err_msg       := 'Insert Into FND_DOCUMENTS_TL Failed';
        RETURN;
      
      END IF;
    
    END;
  
    BEGIN
    
      SELECT nvl(MAX(seq_num), -99)
      INTO   v_seq_num
      FROM   fnd_attached_docs_form_vl
      WHERE  pk1_value = to_char(p_pk_value1);
    
      IF v_seq_num = -99 THEN
        v_seq_num := 10;
      ELSE
        v_seq_num := v_seq_num + 10;
      END IF;
    
    EXCEPTION
      WHEN OTHERS THEN
        v_seq_num := 10;
    END;
  
    BEGIN
    
      INSERT INTO fnd_attached_documents
        (attached_document_id,
         document_id,
         category_id,
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
         attribute15)
      VALUES
        (v_fnd_attach_doc_s,
         v_fnd_doc_s,
         v_category_id,
         SYSDATE,
         v_user_id,
         SYSDATE,
         v_user_id,
         -1,
         v_seq_num,
         'AR_CUSTOMERS',
         p_pk_value1,
         NULL,
         NULL,
         NULL,
         NULL,
         'N',
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
         NULL);
      IF SQL%NOTFOUND THEN
      
        x_return_status := fnd_api.g_ret_sts_error;
        x_err_msg       := 'Insert Into FND_ATTACHED_DOCUMENTS Failed';
        RETURN;
      
      END IF;
    
    END;
  
    BEGIN
    
      INSERT INTO fnd_documents_short_text
        (media_id,
         short_text)
      VALUES
        (v_fnd_short_doc_s,
         p_short_text);
    
      IF SQL%NOTFOUND THEN
      
        x_return_status := fnd_api.g_ret_sts_error;
        x_err_msg       := 'Insert Into FND_DOCUMENTS_SHORT_TEXT Failed';
      
      END IF;
    
    END;
  
  END create_shorttext_attach;

  FUNCTION is_customer_not_exists(p_customer_name   IN VARCHAR2,
		          p_party_id        OUT NUMBER,
		          p_cust_account_id OUT NUMBER)
    RETURN BOOLEAN IS
  BEGIN
    SELECT hp.party_id,
           ha.cust_account_id
    INTO   p_party_id,
           p_cust_account_id
    FROM   hz_parties       hp,
           hz_cust_accounts ha
    WHERE  hp.party_id = ha.party_id
    AND    ha.status = 'A'
    AND    hp.party_name = p_customer_name
    AND    rownum = 1;
  
    RETURN FALSE;
  EXCEPTION
    WHEN no_data_found THEN
      p_party_id        := -99;
      p_cust_account_id := -99;
      RETURN TRUE;
  END is_customer_not_exists;

  FUNCTION is_cust_site_exists(p_cust_account_id   IN NUMBER,
		       p_site_identifier   IN VARCHAR2,
		       p_party_site_id     OUT NUMBER,
		       p_cust_acct_site_id OUT NUMBER) RETURN BOOLEAN IS
  BEGIN
  
    SELECT party_site_id,
           cust_acct_site_id
    INTO   p_party_site_id,
           p_cust_acct_site_id
    FROM   hz_cust_acct_sites
    WHERE  cust_account_id = p_cust_account_id
    AND    orig_system_reference = p_site_identifier -- updated for Korea-- Value is null in file for US data migrations
    AND    rownum = 1;
  
    RETURN FALSE;
  EXCEPTION
    WHEN no_data_found THEN
      p_party_site_id     := -99;
      p_cust_acct_site_id := -99;
      RETURN TRUE;
  END is_cust_site_exists;

  FUNCTION is_cust_site_use_exists(p_cust_acct_site_id IN NUMBER,
		           p_site_use_code     IN VARCHAR2,
		           p_site_use_id       OUT NUMBER)
    RETURN BOOLEAN IS
  BEGIN
  
    SELECT site_use_id
    INTO   p_site_use_id
    FROM   hz_cust_site_uses_all,
           ar_lookups
    WHERE  cust_acct_site_id = p_cust_acct_site_id
    AND    lookup_type = 'SITE_USE_CODE'
    AND    lookup_code = site_use_code
    AND    meaning = p_site_use_code
    AND    rownum = 1;
  
    RETURN FALSE;
  EXCEPTION
    WHEN no_data_found THEN
      p_site_use_id := -99;
      RETURN TRUE;
  END is_cust_site_use_exists;

  PROCEDURE create_profile(p_cust_account_id    IN NUMBER,
		   p_customer_name      IN VARCHAR2,
		   p_party_id           IN NUMBER,
		   p_bill_site_use_id   IN NUMBER DEFAULT NULL,
		   p_prof_class         IN VARCHAR2 DEFAULT 'DEFAULT',
		   p_collector          IN VARCHAR2,
		   p_credit_check       IN VARCHAR2,
		   p_credit_hold        IN VARCHAR2,
		   p_currency           IN VARCHAR2,
		   p_credit_limit       IN NUMBER,
		   p_order_credit_limit IN NUMBER,
		   p_return_status      OUT VARCHAR2,
		   p_err_msg            OUT VARCHAR2) IS
  
    --l_error_flag    VARCHAR2(1) := 'N';
    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(1000);
    l_msg_index_out NUMBER;
  
    l_object_version_number NUMBER;
    t_customer_profile_rec  hz_customer_profile_v2pub.customer_profile_rec_type;
    t_cust_profile_amt_rec  hz_customer_profile_v2pub.cust_profile_amt_rec_type;
  
    l_cust_account_profile_id  NUMBER;
    l_cust_acct_profile_amt_id NUMBER;
    l_profile_class_id         NUMBER;
    l_collector_id             NUMBER;
    l_credit_checking          VARCHAR2(1);
    l_credit_hold              VARCHAR2(1);
    l_currency                 VARCHAR2(15);
  BEGIN
  
    p_return_status := fnd_api.g_ret_sts_success;
  
    BEGIN
    
      SELECT cust_account_profile_id,
	 object_version_number
      INTO   l_cust_account_profile_id,
	 l_object_version_number
      FROM   hz_customer_profiles
      WHERE  cust_account_id = p_cust_account_id
      AND    nvl(site_use_id, -1) = nvl(p_bill_site_use_id, -1)
      AND    party_id = p_party_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_cust_account_profile_id := NULL;
    END;
  
    -- Profile Class
    BEGIN
      SELECT profile_class_id
      INTO   l_profile_class_id
      FROM   hz_cust_profile_classes
      WHERE  NAME = nvl(p_prof_class, 'DEFAULT')
      AND    status = 'A';
    EXCEPTION
      WHEN no_data_found THEN
        p_err_msg       := 'Invalid profile class ::' || p_prof_class;
        p_return_status := fnd_api.g_ret_sts_error;
        RETURN;
    END;
  
    -- Collector
    IF p_collector IS NOT NULL THEN
      BEGIN
        SELECT collector_id
        INTO   l_collector_id
        FROM   ar_collectors
        WHERE  NAME = p_collector
        AND    nvl(inactive_date, SYSDATE + 1) > SYSDATE;
      EXCEPTION
        WHEN no_data_found THEN
          p_err_msg       := 'Invalid Collector :' || p_collector;
          p_return_status := fnd_api.g_ret_sts_error;
          RETURN;
      END;
    ELSE
      l_collector_id := NULL;
    END IF;
  
    -- Credit Check
    IF p_credit_check IS NOT NULL THEN
      IF upper(p_credit_check) IN ('YES', 'Y') THEN
        l_credit_checking := 'Y';
      ELSE
        l_credit_checking := 'N';
      END IF;
    ELSE
      l_credit_checking := NULL;
    END IF;
  
    -- Credit Hold
    IF p_credit_hold IS NOT NULL THEN
      IF upper(p_credit_hold) IN ('YES', 'Y') THEN
        l_credit_hold := 'Y';
      ELSE
        l_credit_hold := 'N';
      END IF;
    ELSE
      l_credit_hold := NULL;
    END IF;
  
    t_customer_profile_rec.profile_class_id := l_profile_class_id;
    t_customer_profile_rec.collector_id     := l_collector_id;
    t_customer_profile_rec.credit_checking  := l_credit_checking;
    t_customer_profile_rec.credit_hold      := l_credit_hold;
    t_customer_profile_rec.site_use_id      := p_bill_site_use_id;
  
    IF l_cust_account_profile_id IS NOT NULL THEN
    
      IF t_customer_profile_rec.profile_class_id IS NOT NULL THEN
      
        NULL;
      
        t_customer_profile_rec.cust_account_profile_id := l_cust_account_profile_id;
        hz_customer_profile_v2pub.update_customer_profile(p_init_msg_list         => 'T',
				          p_customer_profile_rec  => t_customer_profile_rec,
				          p_object_version_number => l_object_version_number,
				          x_return_status         => l_return_status,
				          x_msg_count             => l_msg_count,
				          x_msg_data              => l_msg_data);
      
        IF l_return_status <> fnd_api.g_ret_sts_success THEN
        
          p_err_msg := 'Cust Profile Failed:';
        
          fnd_file.put_line(fnd_file.log,
		    'Update of Customer Profile is failed.');
          fnd_file.put_line(fnd_file.log,
		    'l_msg_count = ' || to_char(l_msg_count));
          fnd_file.put_line(fnd_file.log, 'l_msg_data = ' || l_msg_data);
        
          FOR i IN 1 .. l_msg_count LOOP
	fnd_msg_pub.get(p_msg_index     => i,
		    p_data          => l_data,
		    p_encoded       => fnd_api.g_false,
		    p_msg_index_out => l_msg_index_out);
	fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
	p_err_msg := p_err_msg || l_data || chr(10);
          END LOOP;
        
          p_return_status           := l_return_status;
          l_cust_account_profile_id := -99;
          RETURN;
        
        END IF;
      END IF;
    ELSE
      -- create
      t_customer_profile_rec.cust_account_id   := p_cust_account_id;
      t_customer_profile_rec.created_by_module := 'TCA_V1_API';
    
      hz_customer_profile_v2pub.create_customer_profile(p_init_msg_list           => 'T',
				        p_customer_profile_rec    => t_customer_profile_rec,
				        p_create_profile_amt      => 'T',
				        x_cust_account_profile_id => l_cust_account_profile_id,
				        x_return_status           => l_return_status,
				        x_msg_count               => l_msg_count,
				        x_msg_data                => l_msg_data);
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
      
        p_err_msg := 'Cust Profile Failed:';
      
        fnd_file.put_line(fnd_file.log,
		  'Create of Customer Profile is failed.');
        fnd_file.put_line(fnd_file.log,
		  'l_msg_count = ' || to_char(l_msg_count));
        fnd_file.put_line(fnd_file.log, 'l_msg_data = ' || l_msg_data);
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
          p_err_msg := p_err_msg || l_data || chr(10);
        END LOOP;
      
        l_cust_account_profile_id := -99;
        p_return_status           := l_return_status;
        l_cust_account_profile_id := -99;
        RETURN;
      
      END IF;
    END IF;
    IF l_cust_account_profile_id <> -99 THEN
      --l_error_flag := 'N';
      ---------------------------------------
      -- Create an customer profile amount --
      ---------------------------------------
      IF p_credit_limit IS NOT NULL OR p_order_credit_limit IS NOT NULL THEN
        -- Currency
        IF p_currency IS NOT NULL THEN
          BEGIN
	SELECT currency_code
	INTO   l_currency
	FROM   fnd_currencies
	WHERE  enabled_flag = 'Y'
	AND    currency_flag = 'Y'
	AND    currency_code = TRIM(p_currency);
          EXCEPTION
	WHEN no_data_found THEN
	
	  p_err_msg       := 'Invalid Currency :' || p_currency;
	  p_return_status := fnd_api.g_ret_sts_error;
	  RETURN;
	  --             p_error_code        => 'E');
          END;
        ELSE
          RETURN;
        END IF;
      
        BEGIN
          SELECT cust_acct_profile_amt_id,
	     object_version_number
          INTO   l_cust_acct_profile_amt_id,
	     l_object_version_number
          FROM   hz_cust_profile_amts
          WHERE  cust_account_profile_id = l_cust_account_profile_id;
        EXCEPTION
          WHEN no_data_found THEN
	l_cust_acct_profile_amt_id := NULL;
        END;
      
        t_cust_profile_amt_rec.overall_credit_limit := to_char(p_credit_limit);
        t_cust_profile_amt_rec.trx_credit_limit     := p_order_credit_limit;
        t_cust_profile_amt_rec.currency_code        := l_currency;
        t_cust_profile_amt_rec.cust_account_id      := p_cust_account_id;
        t_cust_profile_amt_rec.site_use_id          := p_bill_site_use_id;
      
        IF l_cust_acct_profile_amt_id IS NULL THEN
          -- not updateable:
          t_cust_profile_amt_rec.cust_account_profile_id := l_cust_account_profile_id;
          t_cust_profile_amt_rec.created_by_module       := 'TCA_V1_API';
        ELSE
          t_cust_profile_amt_rec.cust_account_profile_id := l_cust_account_profile_id; --Arik
          t_cust_profile_amt_rec.site_use_id             := p_bill_site_use_id; --Arik
        END IF;
      
        hz_customer_profile_v2pub.create_cust_profile_amt(p_init_msg_list            => 'T',
				          p_check_foreign_key        => 'T',
				          p_cust_profile_amt_rec     => t_cust_profile_amt_rec,
				          x_cust_acct_profile_amt_id => l_cust_acct_profile_amt_id,
				          x_return_status            => l_return_status,
				          x_msg_count                => l_msg_count,
				          x_msg_data                 => l_msg_data);
      
        IF l_return_status <> fnd_api.g_ret_sts_success THEN
        
          p_err_msg := 'Profile Amount Failed: ';
        
          fnd_file.put_line(fnd_file.log,
		    'Creation of Profile Amount ' ||
		    p_customer_name || ' is failed.');
          fnd_file.put_line(fnd_file.log,
		    'l_msg_count = ' || to_char(l_msg_count));
          fnd_file.put_line(fnd_file.log, 'l_msg_data = ' || l_msg_data);
          FOR i IN 1 .. l_msg_count LOOP
	fnd_msg_pub.get(p_msg_index     => i,
		    p_data          => l_data,
		    p_encoded       => fnd_api.g_false,
		    p_msg_index_out => l_msg_index_out);
	fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
          
	p_err_msg := p_err_msg || l_data || chr(10);
          
          END LOOP;
        
          --l_cust_account_profile_id := -99;
          p_return_status := l_return_status;
          --l_cust_account_profile_id := -99;
          RETURN;
        
        END IF;
        /*ELSE --Arik
        
           t_cust_profile_amt_rec.cust_acct_profile_amt_id := l_cust_acct_profile_amt_id;
        
                      hz_customer_profile_v2pub.update_cust_profile_amt(p_init_msg_list         => 'T',
                                                             p_cust_profile_amt_rec  => t_cust_profile_amt_rec,
                                                             p_object_version_number => l_object_version_number,
                                                             x_return_status         => l_return_status,
                                                             x_msg_count             => l_msg_count,
                                                             x_msg_data              => l_msg_data);
        
           IF l_return_status <> fnd_api.g_ret_sts_success THEN
        
              p_err_msg := 'Profile Amount Failed: ';
        
              fnd_file.put_line(fnd_file.log,
                                'Update of Profile Amount ' ||
                                p_customer_name || ' is failed.');
              fnd_file.put_line(fnd_file.log,
                                'l_Msg_Count = ' ||
                                to_char(l_msg_count));
              fnd_file.put_line(fnd_file.log,
                                'l_Msg_Data = ' || l_msg_data);
              FOR i IN 1 .. l_msg_count LOOP
                 fnd_msg_pub.get(p_msg_index     => i,
                                 p_data          => l_data,
                                 p_encoded       => fnd_api.g_false,
                                 p_msg_index_out => l_msg_index_out);
                 fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
                 p_err_msg := p_err_msg || l_data || chr(10);
              END LOOP;
        
              l_cust_account_profile_id := -99;
              p_return_status           := l_return_status;
              l_cust_account_profile_id := -99;
              RETURN;
        
           END IF;
        END IF;*/ --Arik
      END IF;
    END IF;
    --end if;
  END create_profile;

  PROCEDURE create_customer(p_customer_name       IN VARCHAR2,
		    p_customer_alt        IN VARCHAR2,
		    p_account_number      IN VARCHAR2,
		    p_tax_reference       IN VARCHAR2,
		    p_customer_class      IN VARCHAR2,
		    p_customer_type       IN VARCHAR2,
		    p_customer_category   IN VARCHAR2,
		    p_support_region_att1 IN VARCHAR2,
		    p_sales_channel_code  IN VARCHAR2,
		    p_business_type       IN VARCHAR2,
		    p_prof_class          IN VARCHAR2 DEFAULT 'DEFAULT',
		    p_cust_credit_check   IN VARCHAR2,
		    p_currency            IN VARCHAR2,
		    p_credit_limit        IN NUMBER,
		    p_order_credit_limit  IN NUMBER,
		    p_party_id            OUT NUMBER,
		    p_cust_account_id     OUT NUMBER,
		    p_external_reference  IN VARCHAR2,
		    p_attachment_category IN VARCHAR2,
		    --p_attachment_type     IN VARCHAR2,
		    p_attachment_text IN VARCHAR2,
		    p_transfer_to_sf  IN VARCHAR2, --CHG0037406 - Add Transfer to SF? logic
		    p_return_sts      IN OUT VARCHAR2,
		    p_err_msg         IN OUT VARCHAR2) IS
  
    l_cust_account_id NUMBER;
    l_account_number  VARCHAR2(30);
    l_party_id        NUMBER;
    l_party_number    VARCHAR2(30);
    l_profile_id      NUMBER;
    l_return_status   VARCHAR2(1);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(2000);
    l_data            VARCHAR2(1000);
    l_msg_index_out   NUMBER;
    l_err_msg         VARCHAR2(2000);
  
    --l_cust_error_flag     VARCHAR2(1) := 'N';
    l_customer_class_code VARCHAR2(30);
    l_customer_type       VARCHAR2(30);
    l_category_code       VARCHAR2(30);
    l_class_code          VARCHAR2(50);
    v_account_number      VARCHAR2(20);
  
    t_cust_account_rec     hz_cust_account_v2pub.cust_account_rec_type;
    t_organization_rec     hz_party_v2pub.organization_rec_type;
    t_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;
    t_code_assignment_rec  hz_classification_v2pub.code_assignment_rec_type;
  
  BEGIN
  
    -- Customer Class
    IF p_customer_class IS NOT NULL THEN
      BEGIN
        SELECT lookup_code
        INTO   l_customer_class_code
        FROM   ar_lookups
        WHERE  lookup_type = 'CUSTOMER CLASS'
        AND    meaning = p_customer_class
        AND    enabled_flag = 'Y'
        AND    nvl(end_date_active, SYSDATE + 1) > SYSDATE;
      EXCEPTION
        WHEN OTHERS THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'invalid Customer Class ' || p_customer_class;
          RETURN;
      END;
    ELSE
      l_customer_class_code := NULL;
    END IF;
  
    -- Customer Type
    IF p_customer_type IS NOT NULL THEN
      BEGIN
        SELECT lookup_code
        INTO   l_customer_type
        FROM   ar_lookups
        WHERE  lookup_type = 'CUSTOMER_TYPE'
        AND    upper(meaning) = upper(p_customer_type)
        AND    enabled_flag = 'Y'
        AND    nvl(end_date_active, SYSDATE + 1) > SYSDATE;
      EXCEPTION
        WHEN OTHERS THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'invalid Customer Type :' || p_customer_type;
          RETURN;
      END;
    ELSE
      l_customer_type := NULL;
    END IF;
  
    -- Customer Category
    IF p_customer_category IS NOT NULL THEN
      BEGIN
        SELECT lookup_code
        INTO   l_category_code
        FROM   ar_lookups
        WHERE  lookup_type = 'CUSTOMER_CATEGORY'
        AND    meaning = p_customer_category
        AND    enabled_flag = 'Y'
        AND    nvl(end_date_active, SYSDATE + 1) > SYSDATE;
      EXCEPTION
        WHEN OTHERS THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'invalid Customer Category ' ||
		  p_customer_category;
          RETURN;
      END;
    ELSE
      l_category_code := NULL;
    END IF;
  
    /* If p_customer_category = 'End Customer' Then
              -- Modified by Venu Kandi on 07/17/2013
                      -- Use the customer number if it exists, else generate from sequence
              if p_account_number is null then
         select hz_cust_accounts_s.nextval into v_account_number from dual;
                      else
                         v_account_number := p_account_number;
                      end if;
    Else
      v_account_number := p_account_number;
    End If;*/
  
    t_cust_account_rec.account_name := p_customer_name;
    -- t_cust_account_rec.date_type_preference := 'ARRIVAL';
  
    -- Modified by Venu Kandi on 07/17/2013
    -- t_cust_account_rec.account_number      := null;--v_account_number;
    t_cust_account_rec.account_number := v_account_number;
  
    t_cust_account_rec.customer_class_code := l_customer_class_code;
    t_cust_account_rec.customer_type       := l_customer_type;
    t_cust_account_rec.sales_channel_code  := p_sales_channel_code;
    t_cust_account_rec.created_by_module   := 'TCA_V1_API';
    t_cust_account_rec.attribute5          := p_transfer_to_sf; --CHG0037406 - Add Transfer to SF? logic
    -- t_cust_account_rec.orig_system_reference := p_external_reference;
    t_cust_account_rec.attribute8 := p_external_reference;
  
    t_organization_rec.organization_name          := p_customer_name;
    t_organization_rec.created_by_module          := 'TCA_V1_API';
    t_organization_rec.organization_name_phonetic := p_customer_alt;
    t_organization_rec.organization_type          := 'ORGANIZATION';
    t_organization_rec.party_rec.category_code    := l_category_code;
    t_organization_rec.jgzz_fiscal_code           := p_tax_reference;
    t_organization_rec.party_rec.attribute1       := p_support_region_att1; --Arik
    -- t_customer_profile_rec.
  
    --
  
    hz_cust_account_v2pub.create_cust_account(p_init_msg_list        => 'T',
			          p_cust_account_rec     => t_cust_account_rec,
			          p_organization_rec     => t_organization_rec,
			          p_customer_profile_rec => t_customer_profile_rec,
			          p_create_profile_amt   => 'F',
			          x_cust_account_id      => l_cust_account_id,
			          x_account_number       => l_account_number,
			          x_party_id             => l_party_id,
			          x_party_number         => l_party_number,
			          x_profile_id           => l_profile_id,
			          x_return_status        => l_return_status,
			          x_msg_count            => l_msg_count,
			          x_msg_data             => l_msg_data);
  
    --hz_classification_v2pub.create_code_assignment;
  
    IF l_return_status <> fnd_api.g_ret_sts_success THEN
    
      p_err_msg := 'Error create account: ';
    
      fnd_file.put_line(fnd_file.log,
		'Creation of Customer' ||
		t_cust_account_rec.account_name || ' is failed.');
      fnd_file.put_line(fnd_file.log,
		'x_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log, 'x_msg_data = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
      
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        p_err_msg := p_err_msg || l_data || chr(10);
      END LOOP;
    
      p_party_id        := -99;
      p_cust_account_id := -99;
      p_return_sts      := l_return_status;
    
      RETURN;
    
    END IF;
  
    IF p_business_type IS NOT NULL THEN
    
      BEGIN
        SELECT lookup_code
        INTO   l_class_code
        FROM   ar_lookups
        WHERE  lookup_type = 'Objet Business Type'
        AND    upper(description) = upper(ltrim(rtrim(p_business_type)));
        t_code_assignment_rec.owner_table_name      := 'HZ_PARTIES';
        t_code_assignment_rec.owner_table_id        := l_party_id;
        t_code_assignment_rec.class_category        := 'Objet Business Type';
        t_code_assignment_rec.class_code            := l_class_code;
        t_code_assignment_rec.primary_flag          := 'N';
        t_code_assignment_rec.content_source_type   := 'USER_ENTERED';
        t_code_assignment_rec.start_date_active     := SYSDATE;
        t_code_assignment_rec.status                := 'A';
        t_code_assignment_rec.created_by_module     := 'TCA_V1_API';
        t_code_assignment_rec.actual_content_source := 'USER_ENTERED';
      
        hz_classification_v2pub.create_code_assignment(p_init_msg_list       => fnd_api.g_true,
				       p_code_assignment_rec => t_code_assignment_rec,
				       x_return_status       => l_return_status,
				       x_msg_count           => l_msg_count,
				       x_msg_data            => l_msg_data,
				       x_code_assignment_id  => l_msg_index_out);
        IF l_return_status <> fnd_api.g_ret_sts_success THEN
        
          p_err_msg := 'Error create code assignment: ';
        
          fnd_file.put_line(fnd_file.log,
		    'Creation of Customer' ||
		    t_cust_account_rec.account_name ||
		    ' is failed.');
          fnd_file.put_line(fnd_file.log,
		    'x_msg_count = ' || to_char(l_msg_count));
          fnd_file.put_line(fnd_file.log, 'x_msg_data = ' || l_msg_data);
          FOR i IN 1 .. l_msg_count LOOP
	fnd_msg_pub.get(p_msg_index     => i,
		    p_data          => l_data,
		    p_encoded       => fnd_api.g_false,
		    p_msg_index_out => l_msg_index_out);
          
	fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
	p_err_msg := p_err_msg || l_data || chr(10);
          END LOOP;
        
          p_party_id        := -99;
          p_cust_account_id := -99;
          p_return_sts      := l_return_status;
        
          RETURN;
        
        END IF;
      
      EXCEPTION
        WHEN OTHERS THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'invalid business type :' || p_business_type;
          RETURN;
      END;
    END IF;
  
    p_party_id        := l_party_id;
    p_cust_account_id := l_cust_account_id;
  
    IF p_cust_credit_check IS NOT NULL THEN
      create_profile(p_cust_account_id    => p_cust_account_id,
	         p_customer_name      => p_customer_name,
	         p_party_id           => p_party_id,
	         p_bill_site_use_id   => NULL,
	         p_prof_class         => p_prof_class, --DEFAULT Class = 0
	         p_collector          => NULL,
	         p_credit_check       => p_cust_credit_check,
	         p_credit_hold        => NULL,
	         p_currency           => p_currency,
	         p_credit_limit       => p_credit_limit,
	         p_order_credit_limit => p_order_credit_limit,
	         p_return_status      => l_return_status,
	         p_err_msg            => l_err_msg);
    
      IF l_return_status != fnd_api.g_ret_sts_success THEN
        RETURN;
      END IF;
    END IF;
  
    IF p_attachment_text IS NOT NULL THEN
    
      create_shorttext_attach(p_category_user_name => p_attachment_category,
		      p_pk_value1          => l_cust_account_id,
		      p_short_text         => p_attachment_text,
		      x_return_status      => l_return_status,
		      x_err_msg            => l_err_msg);
    
      IF l_return_status != fnd_api.g_ret_sts_success THEN
        RETURN;
      END IF;
    END IF;
  
    /*            create_cust_acct_rel(p_run_id          => p_run_id,
                         p_line_number     => p_line_number,
                         p_cust_account_id => p_cust_account_id,
                         p_rel_customer    => p_relation_ship1,
                         p_field_name      => 'Relation_Ship1');
    
    create_cust_acct_rel(p_run_id          => p_run_id,
                         p_line_number     => p_line_number,
                         p_cust_account_id => p_cust_account_id,
                         p_rel_customer    => p_relation_ship2,
                         p_field_name      => 'Relation_Ship2');
    
    create_cust_acct_rel(p_run_id          => p_run_id,
                         p_line_number     => p_line_number,
                         p_cust_account_id => p_cust_account_id,
                         p_rel_customer    => p_relation_ship3,
                         p_field_name      => 'Relation_Ship3');
    
    create_cust_acct_rel(p_run_id          => p_run_id,
                         p_line_number     => p_line_number,
                         p_cust_account_id => p_cust_account_id,
                         p_rel_customer    => p_relation_ship4,
                         p_field_name      => 'Relation_Ship4');
    
    create_cust_acct_rel(p_run_id          => p_run_id,
                         p_line_number     => p_line_number,
                         p_cust_account_id => p_cust_account_id,
                         p_rel_customer    => p_relation_ship5,
                         p_field_name      => 'Relation_Ship5');*/
  
  EXCEPTION
    WHEN OTHERS THEN
      p_party_id        := -99;
      p_cust_account_id := -99;
      p_err_msg         := SQLERRM;
      p_return_sts      := fnd_api.g_ret_sts_error;
    
  END create_customer;

  PROCEDURE create_customer_site( --p_site_identifier   IN VARCHAR2,
		         p_cust_account_id  IN NUMBER,
		         p_party_id         IN NUMBER,
		         p_customer_name    IN VARCHAR2,
		         p_site_name        IN VARCHAR2,
		         p_org_id           IN NUMBER,
		         p_address_line1    IN VARCHAR2,
		         p_address_line2    IN VARCHAR2,
		         p_address_line3    IN VARCHAR2,
		         p_address_line4    IN VARCHAR2,
		         p_city             IN VARCHAR2,
		         p_county           IN VARCHAR2,
		         p_state            IN VARCHAR2,
		         p_postal_code      IN VARCHAR2,
		         p_country          IN VARCHAR2,
		         p_address_category IN VARCHAR2,
		         --p_bank_acc_number   IN VARCHAR2,
		         --p_collection_note   IN VARCHAR2,
		         --p_cust_organization IN VARCHAR2,
		         p_sales_territory   IN VARCHAR2,
		         p_cust_acct_site_id OUT NUMBER,
		         p_party_site_id     OUT NUMBER,
		         p_return_sts        IN OUT VARCHAR2,
		         p_err_msg           IN OUT VARCHAR2) IS
  
    --l_error_flag        VARCHAR2(1) := 'N';
    l_territory_code    fnd_territories_vl.territory_code%TYPE;
    l_location_id       NUMBER;
    l_return_status     VARCHAR2(1);
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(2000);
    l_party_site_id     NUMBER;
    l_party_site_number VARCHAR2(20);
    l_data              VARCHAR2(1000);
    l_msg_index_out     NUMBER;
    l_category_code     VARCHAR2(30);
    l_territory_id      NUMBER; --Arik
  
    t_location_rec       hz_location_v2pub.location_rec_type;
    t_party_site_rec     hz_party_site_v2pub.party_site_rec_type;
    t_cust_acct_site_rec hz_cust_account_site_v2pub.cust_acct_site_rec_type;
  BEGIN
    -- Country
    IF p_country IS NOT NULL THEN
      BEGIN
        SELECT territory_code
        INTO   l_territory_code
        FROM   fnd_territories_vl t
        WHERE  upper(territory_short_name) = upper(p_country);
      EXCEPTION
        WHEN no_data_found THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'Invalid territory :' || p_country;
          RETURN;
      END;
    ELSE
      l_territory_code := NULL;
    END IF;
  
    -- Customer Category
    IF p_address_category IS NOT NULL THEN
      BEGIN
        SELECT lookup_code
        INTO   l_category_code
        FROM   ar_lookups
        WHERE  lookup_type = 'ADDRESS_CATEGORY'
        AND    lookup_code = p_address_category
        AND    enabled_flag = 'Y'
        AND    nvl(end_date_active, SYSDATE + 1) > SYSDATE;
      EXCEPTION
        WHEN no_data_found THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'Invalid ADDRESS_CATEGORY ' || p_address_category;
          RETURN;
      END;
    ELSE
      l_category_code := NULL;
    END IF;
  
    -- Sales Territory
    IF p_sales_territory IS NOT NULL THEN
      BEGIN
        SELECT territory_id
        INTO   l_territory_id
        FROM   ra_territories
        -- WHERE segment1||'.'||segment2 = p_sales_territory;
        WHERE  upper(NAME) = upper(p_sales_territory);
      EXCEPTION
        WHEN no_data_found THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'Invalid Sales Territory ' || p_address_category;
          RETURN;
      END;
    ELSE
      l_territory_id := NULL;
    END IF;
  
    ------------------------------
    -- Check if location exists --
    ------------------------------
    IF p_address_line1 IS NOT NULL THEN
      BEGIN
        SELECT location_id
        INTO   l_location_id
        FROM   hz_locations
        WHERE  country = nvl(l_territory_code, country)
        AND    address1 = p_address_line1
        AND    nvl(address2, '-999') = nvl(p_address_line2, '-999')
        AND    nvl(address3, '-999') = nvl(p_address_line3, '-999')
        AND    nvl(address4, '-999') = nvl(p_address_line4, '-999')
        AND    nvl(postal_code, '-999') = nvl(p_postal_code, '-999')
        AND    rownum = 1;
      EXCEPTION
        WHEN OTHERS THEN
          l_location_id := NULL;
      END;
    
      IF l_location_id IS NULL THEN
      
        t_location_rec.country                := l_territory_code;
        t_location_rec.address1               := p_address_line1;
        t_location_rec.address2               := p_address_line2;
        t_location_rec.address3               := p_address_line3;
        t_location_rec.address4               := p_address_line4;
        t_location_rec.address_lines_phonetic := NULL;
        t_location_rec.city                   := p_city;
        t_location_rec.postal_code            := p_postal_code; -- 27-dec-2012 move substr
        t_location_rec.state                  := p_state;
        t_location_rec.province               := NULL;
        t_location_rec.county                 := p_county;
        t_location_rec.created_by_module      := 'TCA_V1_API';
        /*
                 dbms_output.put_line(a => 'Debug country:'||t_location_rec.country||','||substr(t_location_rec.country, length(t_location_rec.country), 1));
                 dbms_output.put_line(a => 'Debug address1:'||t_location_rec.address1||','||substr(t_location_rec.address1, length(t_location_rec.address1), 1));
                 dbms_output.put_line(a => 'Debug address4:'||t_location_rec.address4||','||substr(t_location_rec.address4, length(t_location_rec.address4), 1));
                 dbms_output.put_line(a => 'Debug address_lines_phonetic:'||t_location_rec.address_lines_phonetic);
                 dbms_output.put_line(a => 'Debug city:'||t_location_rec.city||','||substr(t_location_rec.city, length(t_location_rec.city), 1));
                 dbms_output.put_line(a => 'Debug postal_code:'||t_location_rec.postal_code);
                 dbms_output.put_line(a => 'Debug state:'||t_location_rec.state||','||substr(t_location_rec.state, length(t_location_rec.state), 1));
                 dbms_output.put_line(a => 'Debug province:'||t_location_rec.province);
                 dbms_output.put_line(a => 'Debug county:'||t_location_rec.county||','||substr(length(t_location_rec.county), 1));
                 dbms_output.put_line(a => 'Debug created_by_module:'||t_location_rec.created_by_module);
        */
        hz_location_v2pub.create_location(p_init_msg_list => 'T',
			      p_location_rec  => t_location_rec,
			      x_location_id   => l_location_id,
			      x_return_status => l_return_status,
			      x_msg_count     => l_msg_count,
			      x_msg_data      => l_msg_data);
      
        --            dbms_outp                                               ut.put_line(a => 'Debug l_return_status:'||l_return_status);
        --            dbms_output.put_line(a => 'Debug l_location_id:'||l_location_id);
        IF l_return_status <> fnd_api.g_ret_sts_success THEN
          p_err_msg := 'Error create location. ';
        
          FOR i IN 1 .. l_msg_count LOOP
	l_data := oe_msg_pub.get(p_msg_index => i,
			 p_encoded   => fnd_api.g_false);
          
	p_err_msg := p_err_msg || ': i = ' || i;
          END LOOP;
        
          p_return_sts := l_return_status;
          RETURN;
        END IF; -- Status if
      END IF; -- Location if
    
      --------------------------
      --  Create a party site --
      --------------------------
      t_party_site_rec.party_id                 := p_party_id;
      t_party_site_rec.location_id              := l_location_id;
      t_party_site_rec.identifying_address_flag := 'Y';
      t_party_site_rec.created_by_module        := 'TCA_V1_API';
      t_party_site_rec.party_site_name          := p_site_name;
    
      hz_party_site_v2pub.create_party_site(p_init_msg_list     => 'T',
			        p_party_site_rec    => t_party_site_rec,
			        x_party_site_id     => l_party_site_id,
			        x_party_site_number => l_party_site_number,
			        x_return_status     => l_return_status,
			        x_msg_count         => l_msg_count,
			        x_msg_data          => l_msg_data);
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
      
        p_err_msg := 'Error create party site: ';
        fnd_file.put_line(fnd_file.log,
		  'Creation of Party Site for ' || p_customer_name ||
		  ' is failed.');
        fnd_file.put_line(fnd_file.log,
		  'l_Msg_Count = ' || to_char(l_msg_count));
        fnd_file.put_line(fnd_file.log, 'l_Msg_Data = ' || l_msg_data);
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
          p_err_msg := p_err_msg || l_data || chr(10);
        END LOOP;
        p_party_site_id := -99;
        p_return_sts    := l_return_status;
        RETURN;
      
      END IF; --  Party Status
    
      ------------------------------
      --  Create an account site  --
      ------------------------------
      t_cust_acct_site_rec.cust_account_id        := p_cust_account_id;
      t_cust_acct_site_rec.party_site_id          := l_party_site_id;
      t_cust_acct_site_rec.customer_category_code := l_category_code;
      --t_cust_acct_site_rec.orig_system_reference  := p_site_identifier;
      t_cust_acct_site_rec.created_by_module := 'TCA_V1_API'; --'XXCUST';
      t_cust_acct_site_rec.org_id            := p_org_id;
      t_cust_acct_site_rec.territory_id      := l_territory_id;
    
      /*     IF p_org_id = 81 THEN
                  fnd_global.apps_initialize(user_id      => g_user_id,
                                             resp_id      => 50582,
                                             resp_appl_id => 222);
               ELSIF p_org_id = 128 THEN
                  fnd_global.apps_initialize(user_id      => g_user_id,
                                             resp_id      => 50686,
                                             resp_appl_id => 222);
               ELSIF p_org_id = 161 THEN
                  fnd_global.apps_initialize(user_id      => g_user_id,
                                             resp_id      => 50866,
                                             resp_appl_id => 222);
               END IF;
      */
    
      mo_global.set_org_access(p_org_id_char     => p_org_id,
		       p_sp_id_char      => NULL,
		       p_appl_short_name => 'AR');
    
      hz_cust_account_site_v2pub.create_cust_acct_site(p_init_msg_list      => 'T',
				       p_cust_acct_site_rec => t_cust_acct_site_rec,
				       x_cust_acct_site_id  => p_cust_acct_site_id,
				       x_return_status      => l_return_status,
				       x_msg_count          => l_msg_count,
				       x_msg_data           => l_msg_data);
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
      
        p_err_msg := 'Error create site account: ';
        fnd_file.put_line(fnd_file.log,
		  'Creation of Customer Account Site for ' ||
		  p_customer_name || ' is failed.');
        fnd_file.put_line(fnd_file.log,
		  ' l_Msg_Count = ' || to_char(l_msg_count));
        fnd_file.put_line(fnd_file.log, ' l_Msg_Data  = ' || l_msg_data);
        p_cust_acct_site_id := -99;
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
          p_err_msg := p_err_msg || l_data || chr(10);
        END LOOP;
        p_party_site_id := -99;
        p_return_sts    := l_return_status;
        RETURN;
      
      END IF; -- Customer Site Status
    END IF; -- Check Address if
  
  END create_customer_site;

  PROCEDURE create_cust_site_use(p_org_id            IN NUMBER,
		         p_customer_name     IN VARCHAR2,
		         p_cust_acct_site_id IN NUMBER,
		         p_location          IN VARCHAR2,
		         p_bus_pur_usage     IN VARCHAR2,
		         --p_site_identifier       IN VARCHAR2,
		         p_bus_pur_primary IN VARCHAR2,
		         p_tax_code        IN VARCHAR2,
		         p_demand_class    IN VARCHAR2,
		         p_payment_terms   IN VARCHAR2,
		         p_ship_terms      IN VARCHAR2,
		         p_sales_person    IN VARCHAR2,
		         p_order_type      IN VARCHAR2,
		         p_price_list      IN VARCHAR2,
		         --p_brand                 IN VARCHAR2,
		         --p_ocean_dest_port       IN VARCHAR2,
		         --p_air_dest_port         IN VARCHAR2,
		         p_means_of_transport IN VARCHAR2,
		         --p_order_opening_instr   IN VARCHAR2,
		         --p_packing_instruct      IN VARCHAR2,
		         --p_quality_instruct      IN VARCHAR2,
		         --p_labeling_instruct     IN VARCHAR2,
		         --p_printed_invoice_text  IN VARCHAR2,
		         --p_printed_proforma_text IN VARCHAR2,
		         --p_label_code            IN VARCHAR2,
		         --p_shipping_instruct     IN VARCHAR2,
		         --p_marks                 IN VARCHAR2,
		         --p_cust_samples          IN VARCHAR2,
		         --p_cust_samples_in_out   IN VARCHAR2,
		         --p_cust_samples_yes_no   IN VARCHAR2,
		         --p_treatment             IN VARCHAR2,
		         --p_No_Picture            in varchar2,
		         --p_picture_code       IN VARCHAR2,
		         --p_netural_label      IN VARCHAR2,
		         p_receivable_acc     IN VARCHAR2,
		         p_revenue_acc        IN VARCHAR2,
		         p_unearned_revenue   IN VARCHAR2,
		         p_cust_account_id    IN NUMBER,
		         p_party_id           IN NUMBER,
		         p_prof_class         IN VARCHAR2 DEFAULT NULL,
		         p_collector          IN VARCHAR2,
		         p_credit_check       IN VARCHAR2,
		         p_credit_hold        IN VARCHAR2,
		         p_currency           IN VARCHAR2,
		         p_credit_limit       IN VARCHAR2,
		         p_order_credit_limit IN VARCHAR2,
		         p_return_sts         IN OUT VARCHAR2,
		         p_err_msg            IN OUT VARCHAR2) IS
    --l_error_flag    VARCHAR2(1) := 'N';
    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(1000);
    l_msg_index_out NUMBER;
  
    l_bus_pur_primary  VARCHAR2(1);
    l_ship_via         VARCHAR2(50);
    l_tax_code         VARCHAR2(50);
    l_term_id          NUMBER;
    l_salesrep_id      NUMBER;
    l_order_type_id    NUMBER;
    l_price_list_id    NUMBER;
    l_demand_class     VARCHAR2(30);
    l_bill_site_use_id NUMBER;
    l_ship_site_use_id NUMBER;
    l_gl_id_rec        NUMBER;
    l_gl_id_rev        NUMBER;
    l_gl_id_unrev      NUMBER;
    --l_err_msg          VARCHAR2(2000);
    l_coa_id          NUMBER;
    l_site_use_code   VARCHAR2(30);
    l_cust_account_id NUMBER;
    v_ship_terms      VARCHAR2(30);
  
    t_cust_site_use_rec    hz_cust_account_site_v2pub.cust_site_use_rec_type;
    t_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;
  BEGIN
  
    l_coa_id := xxgl_utils_pkg.get_coa_id_from_ou(p_org_id);
  
    BEGIN
    
      SELECT lookup_code
      INTO   l_site_use_code
      FROM   ar_lookups
      WHERE  lookup_type = 'SITE_USE_CODE'
      AND    upper(meaning) = upper(p_bus_pur_usage);
    
    EXCEPTION
      WHEN no_data_found THEN
        p_return_sts := fnd_api.g_ret_sts_error;
        p_err_msg    := 'Invalid Site Use Code :' || p_bus_pur_usage;
        RETURN;
    END;
    -- Bus Purposes Primary
    IF upper(p_bus_pur_primary) IN ('YES', 'Y') THEN
      l_bus_pur_primary := 'Y';
    ELSE
      l_bus_pur_primary := 'N';
    END IF;
  
    -- Payment Terms
    IF p_payment_terms IS NOT NULL THEN
      BEGIN
        SELECT term_id
        INTO   l_term_id
        FROM   ra_terms
        WHERE  upper(description) = upper(p_payment_terms)
        OR     upper(NAME) = upper(p_payment_terms);
      EXCEPTION
        WHEN no_data_found THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'Invalid Terms :' || p_payment_terms;
          RETURN;
      END;
    ELSE
      l_term_id := NULL;
    END IF;
  
    --Arik
    -- Ship Terms
    IF p_ship_terms IS NOT NULL THEN
      BEGIN
        SELECT lookup_code
        INTO   v_ship_terms
        FROM   fnd_lookup_values_vl
        WHERE  lookup_type LIKE '%FREIGHT_TERMS%'
        AND    view_application_id = 660
        AND    security_group_id = 0
        AND    upper(meaning) = upper(p_ship_terms);
      EXCEPTION
        WHEN no_data_found THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'Invalid Ship Terms :' || p_ship_terms;
          RETURN;
      END;
    ELSE
      v_ship_terms := NULL;
    END IF;
  
    -- Tax Code
    IF p_tax_code IS NOT NULL THEN
      BEGIN
        SELECT tax_rate_code --TAX_CODE
        INTO   l_tax_code
        FROM   zx_rates_vl
        WHERE  nvl(effective_to, SYSDATE + 1) > SYSDATE
        AND    upper(tax_rate_code) /*TAX_CODE*/
	  = upper(p_tax_code);
      EXCEPTION
        WHEN no_data_found THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'Invalid Tax code :' || p_tax_code;
          RETURN;
        
      END;
    ELSE
      l_tax_code := NULL;
    END IF;
  
    -- Sales_Person
    IF p_sales_person IS NOT NULL THEN
      BEGIN
      
        SELECT srp.salesrep_id
        INTO   l_salesrep_id
        FROM   jtf_rs_salesreps         srp,
	   oe_sales_credit_types    st,
	   jtf_rs_resource_extns_vl b,
	   jtf_objects_vl           c
        WHERE  srp.sales_credit_type_id = st.sales_credit_type_id
        AND    srp.resource_id = b.resource_id
        AND    b.category = c.object_code
        AND    upper(b.resource_name) = upper(ltrim(rtrim(p_sales_person)))
        AND    org_id = p_org_id;
      
      EXCEPTION
        WHEN no_data_found THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'Invalid Sales person :' || p_sales_person;
          RETURN;
        
      END;
    ELSE
      l_salesrep_id := NULL;
    END IF;
  
    -- Order Type
    IF p_order_type IS NOT NULL THEN
      BEGIN
        SELECT transaction_type_id
        INTO   l_order_type_id
        FROM   oe_transaction_types_tl
        WHERE  upper(NAME) = upper(p_order_type)
        AND    LANGUAGE = userenv('LANG');
      EXCEPTION
        WHEN OTHERS THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'Invalid Order Type :' || p_order_type;
          RETURN;
        
      END;
    ELSE
      l_order_type_id := NULL;
    END IF;
  
    -- Price List
    IF p_price_list IS NOT NULL THEN
      BEGIN
        SELECT list_header_id
        INTO   l_price_list_id
        FROM   qp_list_headers_tl
        WHERE  upper(NAME) = upper(p_price_list)
        AND    LANGUAGE = userenv('LANG');
      EXCEPTION
        WHEN OTHERS THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'Invalid Price List :' || p_price_list;
          RETURN;
        
      END;
    ELSE
      l_price_list_id := NULL;
    END IF;
  
    -- Demand Class
    IF p_demand_class IS NOT NULL THEN
      BEGIN
        SELECT flv.lookup_code
        INTO   l_demand_class
        FROM   fnd_lookup_values_vl flv
        WHERE  flv.lookup_type = 'DEMAND_CLASS'
        AND    upper(flv.lookup_code) = upper(p_demand_class)
        AND    flv.enabled_flag = 'Y';
      EXCEPTION
        WHEN OTHERS THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'Invalid Demand class :' || p_demand_class;
          RETURN;
        
      END;
    ELSE
      l_demand_class := NULL;
    END IF;
  
    -- Receivable Account
    IF p_receivable_acc IS NOT NULL THEN
      BEGIN
        SELECT code_combination_id
        INTO   l_gl_id_rec
        FROM   gl_code_combinations_kfv
        WHERE  concatenated_segments = p_receivable_acc
        AND    enabled_flag = 'Y';
      EXCEPTION
        WHEN no_data_found THEN
        
          xxgl_utils_pkg.get_and_create_account(p_concat_segment      => p_receivable_acc,
				p_coa_id              => l_coa_id,
				x_code_combination_id => l_gl_id_rec,
				x_return_code         => p_return_sts,
				x_err_msg             => p_err_msg);
        
          IF p_return_sts != fnd_api.g_ret_sts_success THEN
          
	RETURN;
          
          END IF;
      END;
    ELSE
      l_gl_id_rec := NULL;
    END IF;
  
    -- Revenue Account
    IF p_revenue_acc IS NOT NULL THEN
      BEGIN
        SELECT code_combination_id
        INTO   l_gl_id_rev
        FROM   gl_code_combinations_kfv
        WHERE  concatenated_segments = p_revenue_acc
        AND    enabled_flag = 'Y';
      EXCEPTION
        WHEN no_data_found THEN
          xxgl_utils_pkg.get_and_create_account(p_concat_segment      => p_revenue_acc,
				p_coa_id              => l_coa_id,
				x_code_combination_id => l_gl_id_rev,
				x_return_code         => p_return_sts,
				x_err_msg             => p_err_msg);
        
          IF p_return_sts != fnd_api.g_ret_sts_success THEN
          
	RETURN;
          
          END IF;
      END;
    ELSE
      l_gl_id_rev := NULL;
    END IF;
  
    -- Unearned Revenue Account
    IF p_unearned_revenue IS NOT NULL THEN
      BEGIN
        SELECT code_combination_id
        INTO   l_gl_id_unrev
        FROM   gl_code_combinations_kfv
        WHERE  concatenated_segments = p_unearned_revenue
        AND    enabled_flag = 'Y';
      EXCEPTION
        WHEN no_data_found THEN
          xxgl_utils_pkg.get_and_create_account(p_concat_segment      => p_unearned_revenue,
				p_coa_id              => l_coa_id,
				x_code_combination_id => l_gl_id_unrev,
				x_return_code         => p_return_sts,
				x_err_msg             => p_err_msg);
        
          IF p_return_sts != fnd_api.g_ret_sts_success THEN
          
	RETURN;
          
          END IF;
      END;
    ELSE
      l_gl_id_unrev := NULL;
    END IF;
  
    -- Means Of Transport
    IF p_means_of_transport IS NOT NULL THEN
      BEGIN
        SELECT flv.lookup_code
        INTO   l_ship_via
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = 'SHIP_METHOD'
        AND    upper(flv.meaning) = upper(p_means_of_transport)
        AND    LANGUAGE = userenv('LANG')
        AND    flv.enabled_flag = 'Y';
      EXCEPTION
        WHEN OTHERS THEN
          p_return_sts := fnd_api.g_ret_sts_error;
          p_err_msg    := 'Invalid ship via :' || p_means_of_transport;
          RETURN;
        
      END;
    ELSE
      l_ship_via := NULL;
    END IF;
  
    ---------------------------------
    -- Create an account site use  --
    ---------------------------------
    t_cust_site_use_rec.cust_acct_site_id   := p_cust_acct_site_id;
    t_cust_site_use_rec.primary_flag        := l_bus_pur_primary;
    t_cust_site_use_rec.payment_term_id     := l_term_id;
    t_cust_site_use_rec.tax_code            := l_tax_code;
    t_cust_site_use_rec.primary_salesrep_id := l_salesrep_id;
    t_cust_site_use_rec.order_type_id       := l_order_type_id;
    t_cust_site_use_rec.price_list_id       := l_price_list_id;
    t_cust_site_use_rec.location            := p_location /*p_site_identifier || ' ' ||
                                                     lower(p_bus_pur_usage)*/
     ;
    t_cust_site_use_rec.demand_class_code   := l_demand_class;
    t_cust_site_use_rec.ship_via            := l_ship_via;
    t_cust_site_use_rec.org_id              := p_org_id;
    t_cust_site_use_rec.site_use_code       := l_site_use_code;
    t_cust_site_use_rec.created_by_module   := 'TCA_V1_API';
  
    IF l_site_use_code = 'BILL_TO' THEN
      t_cust_site_use_rec.gl_id_rec         := l_gl_id_rec;
      t_cust_site_use_rec.gl_id_rev         := l_gl_id_rev;
      t_cust_site_use_rec.gl_id_unearned    := l_gl_id_unrev;
      t_cust_site_use_rec.created_by_module := 'TCA_V1_API';
    
      hz_cust_account_site_v2pub.create_cust_site_use(p_init_msg_list        => 'T',
				      p_cust_site_use_rec    => t_cust_site_use_rec,
				      p_customer_profile_rec => t_customer_profile_rec,
				      p_create_profile       => 'F',
				      p_create_profile_amt   => 'F',
				      x_site_use_id          => l_bill_site_use_id,
				      x_return_status        => l_return_status,
				      x_msg_count            => l_msg_count,
				      x_msg_data             => l_msg_data);
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        p_err_msg := 'Error create Bill To: ';
        fnd_file.put_line(fnd_file.log,
		  'Creation of Customer Account BILL_TO Site use for ' ||
		  p_customer_name || ' is failed.');
        fnd_file.put_line(fnd_file.log,
		  ' l_msg_count = ' || to_char(l_msg_count));
        fnd_file.put_line(fnd_file.log, ' l_msg_data = ' || l_msg_data);
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          p_err_msg := p_err_msg || l_data || chr(10);
        END LOOP;
        p_return_sts := l_return_status;
        RETURN;
      
      END IF;
    
      /*      IF l_bill_site_use_id IS NOT NULL AND l_bill_site_use_id <> -99 THEN
         create_profile(p_cust_account_id    => p_cust_account_id,
                        p_customer_name      => p_customer_name,
                        p_party_id           => p_party_id,
                        p_bill_site_use_id   => l_bill_site_use_id,
                        p_prof_class         => p_prof_class,
                        p_collector          => p_collector,
                        p_credit_check       => p_credit_check,
                        p_credit_hold        => p_credit_hold,
                        p_currency           => p_currency,
                        p_credit_limit       => p_credit_limit,
                        p_order_credit_limit => p_order_credit_limit,
                        p_return_status      => p_return_sts,
                        p_err_msg            => p_err_msg);
      
         IF p_return_sts != fnd_api.g_ret_sts_success THEN
            RETURN;
         END IF;
      
      END IF;*/
    ELSIF l_site_use_code = 'SHIP_TO' THEN
      BEGIN
        SELECT site_use_id
        INTO   l_bill_site_use_id
        FROM   hz_cust_site_uses_all
        WHERE  cust_acct_site_id = p_cust_acct_site_id
        AND    site_use_code = 'BILL_TO'
        AND    primary_flag = 'Y';
      EXCEPTION
        WHEN no_data_found THEN
          --Arik. In case of BILL TO is not in the same site.
          BEGIN
	SELECT DISTINCT hc.cust_account_id
	INTO   l_cust_account_id
	FROM   hz_cust_acct_sites hc
	WHERE  hc.cust_acct_site_id = p_cust_acct_site_id;
          
	SELECT site_use_id
	INTO   l_bill_site_use_id
	FROM   hz_cust_acct_sites hc,
	       hz_cust_site_uses  hcu
	WHERE  hc.cust_acct_site_id = hcu.cust_acct_site_id
	AND    hc.cust_account_id = l_cust_account_id
	AND    hcu.site_use_code = 'BILL_TO'
	AND    primary_flag = 'Y';
          EXCEPTION
	WHEN no_data_found THEN
	  l_bill_site_use_id := NULL;
	WHEN OTHERS THEN
	  l_bill_site_use_id := NULL;
          END;
      END;
    
      t_cust_site_use_rec.bill_to_site_use_id := l_bill_site_use_id;
      t_cust_site_use_rec.freight_term        := v_ship_terms;
    
      hz_cust_account_site_v2pub.create_cust_site_use(p_init_msg_list        => 'T',
				      p_cust_site_use_rec    => t_cust_site_use_rec,
				      p_customer_profile_rec => t_customer_profile_rec,
				      p_create_profile       => 'F',
				      p_create_profile_amt   => 'F',
				      x_site_use_id          => l_ship_site_use_id,
				      x_return_status        => l_return_status,
				      x_msg_count            => l_msg_count,
				      x_msg_data             => l_msg_data);
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
      
        p_err_msg := 'Error create ship to: ';
      
        fnd_file.put_line(fnd_file.log,
		  'Creation of Customer Account SHIP_TO Site use for ' ||
		  p_customer_name || ' is failed.');
        fnd_file.put_line(fnd_file.log,
		  ' l_msg_count = ' || to_char(l_msg_count));
        fnd_file.put_line(fnd_file.log, ' l_msg_data = ' || l_msg_data);
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
        
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        
          p_err_msg := p_err_msg || l_data || chr(10);
        END LOOP;
        p_return_sts := l_return_status;
        RETURN;
      
      END IF;
    
    END IF;
  END create_cust_site_use;

  PROCEDURE create_phone( --p_run_id             IN NUMBER,
		 --p_line_number        IN NUMBER,
		 p_owner_table_id     IN NUMBER,
		 p_owner_table_name   IN VARCHAR2,
		 p_primary_flag       IN VARCHAR2,
		 p_area_code          IN VARCHAR2,
		 p_country_code       IN VARCHAR2,
		 p_phone_number       IN VARCHAR2,
		 p_phone_type         IN VARCHAR2,
		 p_phone_extension    IN VARCHAR2,
		 p_contact_point_type IN VARCHAR2 DEFAULT 'PHONE',
		 p_contact_label      IN VARCHAR2 DEFAULT 'Customer') IS
  
    l_error_flag         VARCHAR2(1) := 'N';
    l_phone_type         VARCHAR2(30);
    l_phone_country_code VARCHAR2(30);
    l_primary_flag       VARCHAR2(1);
    l_contact_point_type VARCHAR2(30);
    l_data               VARCHAR2(1000);
    l_msg_index_out      NUMBER;
  
    l_return_status    VARCHAR2(2000);
    l_msg_count        NUMBER;
    l_msg_data         VARCHAR2(2000);
    l_contact_point_id NUMBER;
  
    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_phone_rec         hz_contact_point_v2pub.phone_rec_type;
    l_edi_rec           hz_contact_point_v2pub.edi_rec_type;
    l_email_rec         hz_contact_point_v2pub.email_rec_type;
    l_telex_rec         hz_contact_point_v2pub.telex_rec_type;
    l_web_rec           hz_contact_point_v2pub.web_rec_type;
  BEGIN
    -- Contact Point Type
    IF p_contact_point_type IS NOT NULL THEN
      IF upper(p_contact_point_type) = 'TELECOMMUNICATION' THEN
        l_contact_point_type := 'PHONE';
      END IF;
    ELSE
      l_error_flag := 'Y';
      /*  rec_error(p_run_number        => p_run_id,
      p_line_number       => p_line_number,
      p_error_explanation => 'Invalid :' || p_contact_label ||
                             ' Contact Point Type ',
      p_error_value       => p_contact_label ||
                             ' Contact Point Type',
      p_error_code        => 'E');*/
    END IF;
  
    -- Phone Type
    IF p_phone_type IS NOT NULL THEN
      BEGIN
        SELECT lookup_code
        INTO   l_phone_type
        FROM   (SELECT l.lookup_code,
	           l.meaning
	    FROM   ar_lookups l
	    WHERE  l.lookup_type = 'COMMUNICATION_TYPE'
	    AND    l.enabled_flag = 'Y'
	    AND    l.lookup_code = 'TLX'
	    AND    trunc(SYSDATE) BETWEEN start_date_active AND
	           nvl(end_date_active, trunc(SYSDATE))
	    UNION
	    SELECT l.lookup_code,
	           l.meaning
	    FROM   ar_lookups l
	    WHERE  l.lookup_type = 'PHONE_LINE_TYPE'
	    AND    l.enabled_flag = 'Y'
	    AND    trunc(SYSDATE) BETWEEN start_date_active AND
	           nvl(end_date_active, trunc(SYSDATE)))
        WHERE  meaning = p_phone_type;
      EXCEPTION
        WHEN no_data_found THEN
          l_error_flag := 'Y';
          /* rec_error(p_run_number        => p_run_id,
          p_line_number       => p_line_number,
          p_error_explanation => 'Other Error for Category ' ||
                                 SQLERRM,
          p_error_value       => 'Category',
          p_error_code        => 'E');*/
        WHEN OTHERS THEN
          l_error_flag := 'Y';
          /*  rec_error(p_run_number        => p_run_id,
          p_line_number       => p_line_number,
          p_error_explanation => 'Invalid ' ||
                                 p_contact_label ||
                                 ' General Type ',
          p_error_value       => p_contact_label ||
                                 ' General Type',
          p_error_code        => 'E');*/
      END;
    ELSE
      l_error_flag := 'Y';
      /*    rec_error(p_run_number        => p_run_id,
      p_line_number       => p_line_number,
      p_error_explanation => p_contact_label ||
                             ' General Type is empty ',
      p_error_value       => p_contact_label || ' General Type',
      p_error_code        => 'W');*/
    END IF;
  
    -- Country Code
    IF p_country_code IS NOT NULL THEN
      BEGIN
        SELECT phone_country_code
        INTO   l_phone_country_code
        FROM   hz_phone_country_codes
        WHERE  phone_country_code = p_country_code
        AND    rownum = 1;
      EXCEPTION
        WHEN no_data_found THEN
          l_error_flag := 'Y';
        
        /*  rec_error(p_run_number        => p_run_id,
        p_line_number       => p_line_number,
        p_error_explanation => 'Invalid ' ||
                               p_contact_label ||
                               ' Country Code ',
        p_error_value       => p_contact_label ||
                               ' Country Code ',
        p_error_code        => 'E');*/
        WHEN OTHERS THEN
          l_error_flag := 'Y';
        
        /* rec_error(p_run_number        => p_run_id,
        p_line_number       => p_line_number,
        p_error_explanation => 'Other Error for ' ||
                               p_contact_label ||
                               ' Country Code ' || SQLERRM,
        p_error_value       => p_contact_label ||
                               ' Country Code ',
        p_error_code        => 'E');*/
      END;
    ELSE
      l_phone_country_code := NULL;
    END IF;
  
    -- Phone Number
    IF p_phone_number IS NULL THEN
      l_error_flag := 'Y';
    
      /*  rec_error(p_run_number        => p_run_id,
      p_line_number       => p_line_number,
      p_error_explanation => p_contact_label ||
                             ' Phone Number is empty ',
      p_error_value       => p_contact_label ||
                             ' Phone Number ',
      p_error_code        => 'E');*/
    END IF;
  
    -- Primary Flag
    IF p_primary_flag IS NOT NULL AND
       (upper(p_primary_flag) = 'YES' OR upper(p_primary_flag) = 'Y') THEN
      BEGIN
        SELECT hcp.primary_flag
        INTO   l_primary_flag
        FROM   hz_contact_points hcp
        WHERE  hcp.owner_table_id = p_owner_table_id
        AND    hcp.owner_table_name = p_owner_table_name
        AND    hcp.contact_point_type = p_contact_point_type
        AND    hcp.primary_flag = 'Y'
        AND    hcp.status = 'A'
        AND    rownum = 1;
      
        l_error_flag := 'Y';
        /* rec_error(p_run_number        => p_run_id,
        p_line_number       => p_line_number,
        p_error_explanation => p_contact_label ||
                               ' Primary Flag alredy exists ',
        p_error_value       => p_contact_label ||
                               ' Primary Flag ',
        p_error_code        => 'E');*/
      EXCEPTION
        WHEN no_data_found THEN
          l_primary_flag := 'Y';
      END;
    ELSE
      l_primary_flag := NULL;
    END IF;
  
    IF l_error_flag = 'N' THEN
      l_contact_point_rec.created_by_module  := 'TCA_V1_API';
      l_contact_point_rec.owner_table_name   := p_owner_table_name;
      l_contact_point_rec.owner_table_id     := p_owner_table_id;
      l_contact_point_rec.contact_point_type := l_contact_point_type;
      l_contact_point_rec.primary_flag       := l_primary_flag;
    
      l_phone_rec.phone_area_code    := p_area_code;
      l_phone_rec.phone_country_code := l_phone_country_code;
      l_phone_rec.phone_number       := p_phone_number;
      l_phone_rec.phone_line_type    := l_phone_type;
      l_phone_rec.phone_extension    := p_phone_extension;
    
      hz_contact_point_v2pub.create_contact_point(p_init_msg_list     => 'T',
				  p_contact_point_rec => l_contact_point_rec,
				  p_edi_rec           => l_edi_rec,
				  p_email_rec         => l_email_rec,
				  p_phone_rec         => l_phone_rec,
				  p_telex_rec         => l_telex_rec,
				  p_web_rec           => l_web_rec,
				  x_contact_point_id  => l_contact_point_id,
				  x_return_status     => l_return_status,
				  x_msg_count         => l_msg_count,
				  x_msg_data          => l_msg_data);
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        fnd_file.put_line(fnd_file.log,
		  'Creation :' || p_contact_label ||
		  ' Contact Points is failed.');
        fnd_file.put_line(fnd_file.log,
		  'l_Msg_Count = ' || to_char(l_msg_count));
        fnd_file.put_line(fnd_file.log, 'l_Msg_Data = ' || l_msg_data);
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        END LOOP;
        ROLLBACK;
      ELSE
        COMMIT;
        /* rec_success(p_run_number  => p_run_id,
        p_line_number => p_line_number,
        p_message     => p_contact_label ||
                         ' Phone contact point');*/
      END IF;
    END IF;
  END create_phone;

  PROCEDURE create_email( --p_run_id           IN NUMBER,
		 --p_line_number      IN NUMBER,
		 p_owner_table_id   IN NUMBER,
		 p_owner_table_name IN VARCHAR2,
		 p_primary_flag     IN VARCHAR2,
		 p_email            IN VARCHAR2,
		 p_contact_label    IN VARCHAR2 DEFAULT 'Customer') IS
  
    l_error_flag   VARCHAR2(1) := 'N';
    l_primary_flag VARCHAR2(1);
  
    l_return_status    VARCHAR2(2000);
    l_msg_count        NUMBER;
    l_msg_data         VARCHAR2(2000);
    l_data             VARCHAR2(1000);
    l_msg_index_out    NUMBER;
    l_contact_point_id NUMBER;
  
    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_phone_rec         hz_contact_point_v2pub.phone_rec_type;
    l_edi_rec           hz_contact_point_v2pub.edi_rec_type;
    l_email_rec         hz_contact_point_v2pub.email_rec_type;
    l_telex_rec         hz_contact_point_v2pub.telex_rec_type;
    l_web_rec           hz_contact_point_v2pub.web_rec_type;
  BEGIN
    IF p_email IS NULL THEN
      l_error_flag := 'Y';
    
      /*    rec_error(p_run_number        => p_run_id,
      p_line_number       => p_line_number,
      p_error_explanation => p_contact_label ||
                             ' Email address is empty ',
      p_error_value       => p_contact_label || ' Email ',
      p_error_code        => 'E');*/
    END IF;
  
    -- Primary Flag
    IF p_primary_flag IS NOT NULL AND
       (upper(p_primary_flag) = 'YES' OR upper(p_primary_flag) = 'Y') THEN
      BEGIN
        SELECT hcp.primary_flag
        INTO   l_primary_flag
        FROM   hz_contact_points hcp
        WHERE  hcp.owner_table_id = p_owner_table_id
        AND    hcp.owner_table_name = p_owner_table_name
        AND    hcp.contact_point_type = 'EMAIL'
        AND    hcp.primary_flag = 'Y'
        AND    hcp.status = 'A'
        AND    rownum = 1;
      
        l_error_flag := 'Y';
        /*  rec_error(p_run_number        => p_run_id,
        p_line_number       => p_line_number,
        p_error_explanation => p_contact_label ||
                               ' Primary Flag alredy exists ',
        p_error_value       => p_contact_label ||
                               ' Primary Flag ',
        p_error_code        => 'E');*/
      EXCEPTION
        WHEN no_data_found THEN
          l_primary_flag := 'Y';
      END;
    ELSE
      l_primary_flag := NULL;
    END IF;
  
    IF l_error_flag = 'N' THEN
      l_contact_point_rec.created_by_module  := 'TCA_V1_API';
      l_contact_point_rec.owner_table_name   := p_owner_table_name;
      l_contact_point_rec.owner_table_id     := p_owner_table_id;
      l_contact_point_rec.contact_point_type := 'EMAIL';
      l_contact_point_rec.primary_flag       := l_primary_flag;
    
      l_email_rec.email_address := p_email;
      hz_contact_point_v2pub.create_contact_point(p_init_msg_list     => 'T',
				  p_contact_point_rec => l_contact_point_rec,
				  p_edi_rec           => l_edi_rec,
				  p_email_rec         => l_email_rec,
				  p_phone_rec         => l_phone_rec,
				  p_telex_rec         => l_telex_rec,
				  p_web_rec           => l_web_rec,
				  x_contact_point_id  => l_contact_point_id,
				  x_return_status     => l_return_status,
				  x_msg_count         => l_msg_count,
				  x_msg_data          => l_msg_data);
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        fnd_file.put_line(fnd_file.log,
		  'Creation :' || p_contact_label ||
		  ' Contact Points is failed.');
        fnd_file.put_line(fnd_file.log,
		  'l_Msg_Count = ' || to_char(l_msg_count));
        fnd_file.put_line(fnd_file.log, 'l_Msg_Data = ' || l_msg_data);
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        END LOOP;
        ROLLBACK;
      ELSE
        COMMIT;
        /*  rec_success(p_run_number  => p_run_id,
        p_line_number => p_line_number,
        p_message     => p_contact_label ||
                         ' Email contact point');*/
      END IF;
    END IF;
  END create_email;

  PROCEDURE create_contact( --p_run_id             IN NUMBER,
		   --p_line_number        IN NUMBER,
		   p_party_id           IN NUMBER,
		   p_cust_account_id    IN NUMBER,
		   p_cust_acct_site_id  IN NUMBER,
		   p_contact_last_name  IN VARCHAR2,
		   p_contact_first_name IN VARCHAR2,
		   p_title              IN VARCHAR2,
		   p_contact_job        IN VARCHAR2,
		   p_primary_contact    IN VARCHAR2,
		   p_con_area_code      IN VARCHAR2,
		   p_con_country_code   IN VARCHAR2,
		   p_con_phone_number   IN VARCHAR2,
		   p_con_extension      IN VARCHAR2,
		   p_cont_commun_type   IN VARCHAR2,
		   p_org_cont_party_id  OUT NUMBER) IS
    l_error_flag    VARCHAR2(1) := 'N';
    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(1000);
    l_msg_index_out NUMBER;
  
    l_per_party_id      NUMBER;
    l_org_cont_party_id NUMBER;
    l_party_rel_id      NUMBER;
    l_party_number      VARCHAR2(2000);
    l_profile_id        NUMBER;
    l_org_contact_id    NUMBER;
    l_title             VARCHAR2(30);
    l_job               VARCHAR2(30);
  
    l_person_rec            hz_party_v2pub.person_rec_type;
    l_org_contact_rec       hz_party_contact_v2pub.org_contact_rec_type;
    l_cust_account_role_rec hz_cust_account_role_v2pub.cust_account_role_rec_type;
  
    l_cust_account_role_id       NUMBER;
    l_cont_object_version_number NUMBER;
  BEGIN
    IF p_contact_last_name IS NOT NULL THEN
      BEGIN
        SELECT hp.party_id,
	   hsar.party_id
        INTO   l_per_party_id,
	   l_org_cont_party_id
        FROM   hz_cust_account_roles hsar,
	   hz_parties            hp,
	   hz_relationships      hrel
        WHERE  hsar.party_id = hrel.party_id
        AND    hrel.subject_table_name = 'HZ_PARTIES'
        AND    hrel.object_table_name = 'HZ_PARTIES'
        AND    hsar.role_type = 'CONTACT'
        AND    hp.party_type = 'PERSON'
        AND    hrel.subject_id = hp.party_id
        AND    hsar.cust_acct_site_id = p_cust_acct_site_id
        AND    nvl(hp.person_first_name, '-99') =
	   nvl(p_contact_first_name, '-99')
        AND    hp.person_last_name = p_contact_last_name;
      EXCEPTION
        WHEN no_data_found THEN
          l_per_party_id      := NULL;
          l_org_cont_party_id := NULL;
        WHEN OTHERS THEN
          l_per_party_id      := NULL;
          l_org_cont_party_id := NULL;
          /*  rec_error(p_run_number        => p_run_id,
          p_line_number       => p_line_number,
          p_error_explanation => 'other error for finding of person party_id ' ||
                                 p_contact_first_name || ' ' ||
                                 p_contact_last_name,
          p_error_value       => 'person party id',
          p_error_code        => 'E');*/
      END;
    
      IF l_per_party_id IS NULL THEN
        l_person_rec.person_last_name  := p_contact_last_name;
        l_person_rec.person_first_name := p_contact_first_name;
        l_person_rec.created_by_module := 'TCA_V1_API';
      
        hz_party_v2pub.create_person(p_init_msg_list => 'T',
			 p_person_rec    => l_person_rec,
			 x_party_id      => l_per_party_id,
			 x_party_number  => l_party_number,
			 x_profile_id    => l_profile_id,
			 x_return_status => l_return_status,
			 x_msg_count     => l_msg_count,
			 x_msg_data      => l_msg_data);
        IF l_return_status <> fnd_api.g_ret_sts_success THEN
          fnd_file.put_line(fnd_file.log, 'Creation Person is failed.');
          fnd_file.put_line(fnd_file.log,
		    'l_Msg_Count = ' || to_char(l_msg_count));
          fnd_file.put_line(fnd_file.log, 'l_Msg_Data = ' || l_msg_data);
          l_per_party_id := -99;
        ELSE
          COMMIT;
          /*     rec_success(p_run_number  => p_run_id,
          p_line_number => p_line_number,
          p_message     => ' l_per_party_id=' ||
                           to_char(l_per_party_id));*/
        END IF;
      END IF; -- l_per_party_id is null
    
      -----------------------------------
      -- Create org_contact for person --
      -----------------------------------
      IF l_per_party_id = -99 THEN
        l_error_flag := 'Y';
      ELSE
        l_error_flag := 'N';
      END IF;
    
      IF l_error_flag = 'N' THEN
        BEGIN
          SELECT c.org_contact_id,
	     c.object_version_number
          INTO   l_org_contact_id,
	     l_cont_object_version_number
          FROM   hz_org_contacts  c,
	     hz_relationships r
          WHERE  c.party_relationship_id = r.relationship_id
          AND    r.object_id = p_party_id
          AND    r.object_type = 'ORGANIZATION'
          AND    r.subject_type = 'PERSON'
          AND    r.subject_id = l_per_party_id
          AND    nvl(c.title, '-999') = nvl(l_title, '-999')
          AND    nvl(c.job_title_code, '-999') = nvl(l_job, '-999');
        EXCEPTION
          WHEN no_data_found THEN
	l_org_contact_id    := NULL;
	l_org_cont_party_id := NULL;
        END;
      
        -- Title
        IF p_title IS NOT NULL THEN
          BEGIN
	SELECT lookup_code
	INTO   l_title
	FROM   ar_lookups
	WHERE  lookup_type = 'CONTACT_TITLE'
	AND    meaning = p_title
	AND    enabled_flag = 'Y'
	AND    nvl(end_date_active, SYSDATE + 1) > SYSDATE;
          EXCEPTION
	WHEN no_data_found THEN
	  l_error_flag := 'Y';
	  /*  rec_error(p_run_number        => p_run_id,
              p_line_number       => p_line_number,
              p_error_explanation => 'Invalid Title ' ||
                                     p_title,
              p_error_value       => 'Title',
              p_error_code        => 'E');*/
          END;
        ELSE
          l_title := NULL;
        END IF;
      
        -- Contact Job
        IF p_contact_job IS NOT NULL THEN
          BEGIN
	SELECT lookup_code
	INTO   l_job
	FROM   ar_lookups
	WHERE  lookup_type = 'RESPONSIBILITY'
	AND    meaning = p_contact_job
	AND    enabled_flag = 'Y'
	AND    nvl(end_date_active, SYSDATE + 1) > SYSDATE;
          EXCEPTION
	WHEN no_data_found THEN
	  l_error_flag := 'Y';
	  /*  rec_error(p_run_number        => p_run_id,
              p_line_number       => p_line_number,
              p_error_explanation => 'Invalid Con_Job ' ||
                                     p_contact_job,
              p_error_value       => 'Con_Job',
              p_error_code        => 'E');*/
          END;
        ELSE
          l_job := NULL;
        END IF;
      
        IF l_org_cont_party_id IS NULL AND l_error_flag = 'N' THEN
          l_org_contact_rec.created_by_module                := 'TCA_V1_API';
          l_org_contact_rec.party_rel_rec.subject_id         := l_per_party_id; -- party_id of the contact person
          l_org_contact_rec.party_rel_rec.subject_type       := 'PERSON';
          l_org_contact_rec.party_rel_rec.subject_table_name := 'HZ_PARTIES';
          l_org_contact_rec.party_rel_rec.object_id          := p_party_id;
          l_org_contact_rec.party_rel_rec.object_type        := 'ORGANIZATION'; -- create contact for an organization
          l_org_contact_rec.party_rel_rec.object_table_name  := 'HZ_PARTIES';
          l_org_contact_rec.party_rel_rec.relationship_code  := 'CONTACT_OF';
          l_org_contact_rec.party_rel_rec.relationship_type  := 'CONTACT';
          l_org_contact_rec.title                            := l_title;
          l_org_contact_rec.job_title_code                   := l_job;
        
          hz_party_contact_v2pub.create_org_contact(p_init_msg_list   => 'T',
				    p_org_contact_rec => l_org_contact_rec,
				    x_org_contact_id  => l_org_contact_id,
				    x_party_rel_id    => l_party_rel_id,
				    x_party_id        => l_org_cont_party_id,
				    x_party_number    => l_party_number,
				    x_return_status   => l_return_status,
				    x_msg_count       => l_msg_count,
				    x_msg_data        => l_msg_data);
        
          IF l_return_status <> fnd_api.g_ret_sts_success THEN
	fnd_file.put_line(fnd_file.log,
		      'Creation Org Contact is failed.');
	fnd_file.put_line(fnd_file.log,
		      'l_Msg_Count = ' || to_char(l_msg_count));
	fnd_file.put_line(fnd_file.log, 'l_Msg_Data = ' || l_msg_data);
	FOR i IN 1 .. l_msg_count LOOP
	  fnd_msg_pub.get(p_msg_index     => i,
		      p_data          => l_data,
		      p_encoded       => fnd_api.g_false,
		      p_msg_index_out => l_msg_index_out);
	  fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
	END LOOP;
	l_org_cont_party_id := -99;
          ELSE
	/*      rec_success(p_run_number  => p_run_id,
            p_line_number => p_line_number,
            p_message     => ' l_org_cont_party_id= ' ||
                             to_char(l_org_cont_party_id));*/
	p_org_cont_party_id := l_org_cont_party_id;
          END IF;
        
          IF l_org_cont_party_id IS NOT NULL AND l_org_cont_party_id <> -99 THEN
	--------------------------
	-- Create customer role --
	--------------------------
	l_cust_account_role_rec.created_by_module := 'TCA_V1_API';
	l_cust_account_role_rec.status            := 'A';
	l_cust_account_role_rec.role_type         := 'CONTACT';
	l_cust_account_role_rec.cust_account_id   := p_cust_account_id;
	l_cust_account_role_rec.cust_acct_site_id := p_cust_acct_site_id;
	l_cust_account_role_rec.party_id          := l_org_cont_party_id;
          
	hz_cust_account_role_v2pub.create_cust_account_role(p_init_msg_list         => 'T',
					    p_cust_account_role_rec => l_cust_account_role_rec,
					    x_cust_account_role_id  => l_cust_account_role_id,
					    x_return_status         => l_return_status,
					    x_msg_count             => l_msg_count,
					    x_msg_data              => l_msg_data);
          
	IF l_return_status <> fnd_api.g_ret_sts_success THEN
	  fnd_file.put_line(fnd_file.log,
		        'Creation cust_account_role is failed.');
	  fnd_file.put_line(fnd_file.log,
		        'l_Msg_Count = ' || to_char(l_msg_count));
	  fnd_file.put_line(fnd_file.log,
		        'l_Msg_Data = ' || l_msg_data);
	  FOR i IN 1 .. l_msg_count LOOP
	    fnd_msg_pub.get(p_msg_index     => i,
		        p_data          => l_data,
		        p_encoded       => fnd_api.g_false,
		        p_msg_index_out => l_msg_index_out);
	    fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
	  END LOOP;
	ELSE
	  COMMIT;
	  /*    rec_success(p_run_number  => p_run_id,
              p_line_number => p_line_number,
              p_message     => ' l_cust_account_role_id = ' ||
                               to_char(l_cust_account_role_id));*/
	END IF;
          END IF;
        END IF;
      END IF;
    
      IF l_error_flag = 'N' AND l_org_cont_party_id IS NOT NULL AND
         l_org_cont_party_id <> -99 THEN
        create_phone( --p_run_id             => p_run_id,
	         --p_line_number        => p_line_number,
	         p_owner_table_id     => l_org_cont_party_id,
	         p_owner_table_name   => 'HZ_PARTIES',
	         p_primary_flag       => p_primary_contact,
	         p_area_code          => p_con_area_code,
	         p_country_code       => p_con_country_code,
	         p_phone_number       => p_con_phone_number,
	         p_phone_type         => 'Telephone',
	         p_phone_extension    => p_con_extension,
	         p_contact_point_type => p_cont_commun_type,
	         p_contact_label      => 'Contact');
      END IF;
    END IF;
  END create_contact;

  PROCEDURE main(errbuf  OUT VARCHAR2,
	     errcode OUT VARCHAR2) IS
    --l_run_number NUMBER;
  
    CURSOR csr_customers IS
      SELECT DISTINCT organization_name,
	          organization_alt_name,
	          customer_support_region,
	          customer_category,
	          sales_channel_code,
	          priority_customer_num,
	          tax_reference,
	          nvl(cust_credit_check, 'N') cust_credit_check, --Arik
	          cust_credit_currency,
	          --cust_credit_limit, -- commented by Venu
	          --cust_ord_credit_limit, -- commented by Venu
	          attachment_category,
	          attachment_type,
	          attachment_text,
	          customer_class_code,
	          customer_type,
	          profile_class,
	          business_type,
	          cust_exists_flag,
	          transfer_to_sf, --CHG0037406 - Add Transfer to SF? logic
	          --modified by venu on 7/17/13
	          -- replace(substr(cc.site_identifier,instr(cc.site_identifier,'.')+1,7),'.',null) account_number,
	          account_number
      -- address_line2--Temp(URL) -- commented by Venu
      FROM   xxobjt_conv_hz_customers cc
      WHERE  ERROR_CODE = 'N'
      AND    business_porposes = 'Bill To'
      /*
                      AND
            NOT EXISTS
      (SELECT 1
               FROM xxobjt_conv_hz_customers cc1
              WHERE cc1.organization_name = cc.organization_name AND
                    ERROR_CODE = 'E')
      */
      ORDER  BY organization_name;
  
    CURSOR csr_vertical(p_customer_name     VARCHAR2,
		p_customer_category IN VARCHAR2) IS
      SELECT DISTINCT vertical
      FROM   xxobjt_conv_hz_customers
      WHERE  organization_name = p_customer_name
      AND    customer_category = p_customer_category
      AND    ERROR_CODE = 'N'
      AND    vertical IS NOT NULL;
  
    CURSOR csr_cust_sites(p_customer_name     VARCHAR2,
		  p_customer_category IN VARCHAR2) IS
      SELECT DISTINCT organization_name,
	          site_identifier,
	          site_name,
	          country,
	          address_line1,
	          address_line2,
	          address_line3,
	          address_line4,
	          city,
	          county,
	          state,
	          postal_code,
	          --territory,
	          operating_unit_name,
	          site_exists_flag,
	          -- 11/4/13: CArolyn wants to load Syteline "territory " as sales territory
	          -- As per the revised spec, it will be populated in "sales territory" field in the file
	          territory AS sales_territory
      FROM   xxobjt_conv_hz_customers
      WHERE  organization_name = p_customer_name
      AND    customer_category = p_customer_category
      AND    ERROR_CODE = 'N'
      ORDER  BY organization_name; -- , site_identifier;
  
    CURSOR csr_cust_site_uses(p_customer_name VARCHAR2,
		      -- p_site_identifier VARCHAR2,
		      p_customer_category VARCHAR2,
		      p_site_name         VARCHAR2) IS
      SELECT *
      FROM   xxobjt_conv_hz_customers
      WHERE  organization_name = p_customer_name
      AND    site_name = p_site_name
	-- AND          site_identifier = p_site_identifier
      AND    customer_category = p_customer_category
      AND    ERROR_CODE = 'N' -- Added by Venu on 7/17/2013
      ORDER  BY organization_name; -- , site_identifier;
  
    cur_customer csr_customers%ROWTYPE;
    cur_site     csr_cust_sites%ROWTYPE;
    cur_site_use csr_cust_site_uses%ROWTYPE;
  
    l_cust_account_id   NUMBER;
    l_cust_acct_site_id NUMBER;
    l_party_id          NUMBER;
    l_party_site_id     NUMBER;
    --l_org_cont_party_id NUMBER;
    l_site_uses_id  NUMBER;
    l_org_id        NUMBER;
    l_return_status VARCHAR2(1);
    l_err_msg       VARCHAR2(2000);
  
    invalid_customer EXCEPTION;
  
    l_cust_credit_limit     NUMBER; -- added by venu
    l_cust_ord_credit_limit NUMBER;
  
    l_flg_cust_exists     CHAR(1);
    l_flg_site_exists     CHAR(1);
    l_flg_site_use_exists CHAR(1);
    l_vertical            VARCHAR(100);
  BEGIN
  
    errbuf  := NULL;
    errcode := 0;
  
    UPDATE xxobjt_conv_hz_customers
    SET    ERROR_CODE = 'N'
    WHERE  ERROR_CODE IS NULL;
    COMMIT;
  
    -- Remove special characters from customer category
    UPDATE xxobjt_conv_hz_customers
    SET    customer_category = REPLACE(customer_category, chr(10), '')
    WHERE  ERROR_CODE = 'N';
    COMMIT;
  
    --remove special characters from customer accout number
    UPDATE xxobjt_conv_hz_customers
    SET    account_number = TRIM(REPLACE(REPLACE(account_number, chr(10)),
			     chr(13)))
    WHERE  ERROR_CODE = 'N';
    COMMIT;
  
    SELECT user_id
    INTO   g_user_id
    FROM   fnd_user
    WHERE  user_name = 'CONVERSION';
  
    fnd_global.apps_initialize(user_id      => g_user_id,
		       resp_id      => 20420,
		       resp_appl_id => 1);
  
    FOR cur_customer IN csr_customers LOOP
      BEGIN
        l_party_id        := NULL;
        l_cust_account_id := NULL;
      
        l_return_status := NULL;
        l_err_msg       := NULL;
      
        l_flg_cust_exists := NULL; -- customer already exits in Oracle or not
      
        IF is_customer_not_exists(p_customer_name   => cur_customer.organization_name,
		          p_party_id        => l_party_id,
		          p_cust_account_id => l_cust_account_id) = TRUE THEN
          BEGIN
	-- Get credit limit from Bill to
	BEGIN
	  SELECT cust_credit_limit,
	         cust_ord_credit_limit
	  INTO   l_cust_credit_limit,
	         l_cust_ord_credit_limit
	  FROM   xxobjt_conv_hz_customers
	  WHERE  organization_name = cur_customer.organization_name
	  AND    business_porposes = 'Bill To';
	EXCEPTION
	  WHEN OTHERS THEN
	    l_cust_credit_limit := NULL;
	END;
          
	l_return_status := fnd_api.g_ret_sts_success;
          
	create_customer(p_customer_name       => cur_customer.organization_name,
		    p_customer_alt        => cur_customer.organization_alt_name,
		    p_account_number      => cur_customer.account_number,
		    p_tax_reference       => cur_customer.tax_reference,
		    p_customer_class      => cur_customer.customer_class_code,
		    p_customer_type       => cur_customer.customer_type,
		    p_customer_category   => cur_customer.customer_category,
		    p_support_region_att1 => cur_customer.customer_support_region,
		    p_sales_channel_code  => upper(cur_customer.sales_channel_code),
		    p_business_type       => cur_customer.business_type,
		    p_prof_class          => cur_customer.profile_class,
		    p_cust_credit_check   => cur_customer.cust_credit_check,
		    p_currency            => cur_customer.cust_credit_currency,
		    p_credit_limit        => l_cust_credit_limit, -- cur_customer.cust_credit_limit,
		    p_order_credit_limit  => l_cust_ord_credit_limit, -- cur_customer.cust_ord_credit_limit,
		    p_party_id            => l_party_id,
		    p_cust_account_id     => l_cust_account_id,
		    p_external_reference  => cur_customer.priority_customer_num,
		    p_attachment_category => cur_customer.attachment_category,
		    --p_attachment_type     => cur_customer.attachment_type,
		    p_attachment_text => cur_customer.attachment_text,
		    p_transfer_to_sf  => cur_customer.transfer_to_sf, --CHG0037406 - Add Transfer to SF? logic
		    p_return_sts      => l_return_status,
		    p_err_msg         => l_err_msg);
          
	IF l_return_status != fnd_api.g_ret_sts_success THEN
	  IF l_err_msg IS NULL THEN
	    l_err_msg := 'Customer creation failed';
	  END IF;
	  RAISE invalid_customer;
	END IF;
          
	-- Load the vertical
	FOR lrec_vertical IN csr_vertical(cur_customer.organization_name,
			          cur_customer.customer_category) LOOP
	  BEGIN
	    SELECT lookup_code
	    INTO   l_vertical
	    FROM   fnd_lookup_values
	    WHERE  lookup_type = 'Objet Business Type'
	    AND    upper(lookup_code) = upper(lrec_vertical.vertical)
	    AND    LANGUAGE = userenv('LANG');
	  EXCEPTION
	    WHEN OTHERS THEN
	      l_vertical := lrec_vertical.vertical;
	      NULL;
	  END;
	  load_vertical_to_oracle(l_party_id,
			  l_vertical,
			  l_return_status,
			  l_err_msg);
	  IF l_return_status != fnd_api.g_ret_sts_success THEN
	    l_err_msg := 'Vertical creation failed. ' || l_err_msg;
	    RAISE invalid_customer;
	  END IF;
	END LOOP;
          END;
        ELSE
          -- Customer exists in Oracle
          l_flg_cust_exists := 'Y';
        END IF;
      
        FOR cur_site IN csr_cust_sites(cur_customer.organization_name,
			   cur_customer.customer_category) LOOP
          BEGIN
	BEGIN
	  SELECT hou.organization_id
	  INTO   l_org_id
	  FROM   hr_operating_units hou
	  WHERE  hou.name = cur_site.operating_unit_name;
	
	  mo_global.set_policy_context(p_access_mode => 'S',
			       p_org_id      => l_org_id);
	  mo_global.set_org_access(p_org_id_char     => l_org_id,
			   p_sp_id_char      => NULL,
			   p_appl_short_name => 'AR');
	EXCEPTION
	  WHEN OTHERS THEN
	    l_err_msg := l_err_msg || 'Invalid Opearation Unit Name. ';
	    RAISE invalid_customer;
	END;
          
	l_flg_site_exists := NULL;
          
	IF is_cust_site_exists(p_cust_account_id   => l_cust_account_id,
		           p_site_identifier   => cur_site.site_identifier,
		           p_party_site_id     => l_party_site_id,
		           p_cust_acct_site_id => l_cust_acct_site_id) = TRUE THEN
	  BEGIN
	    --IF cur_site.site_exists_flag = 'N' THEN
	  
	    create_customer_site( -- p_site_identifier   => cur_site.site_identifier,
			 p_cust_account_id  => l_cust_account_id,
			 p_party_id         => l_party_id,
			 p_customer_name    => cur_site.organization_name,
			 p_site_name        => cur_site.site_name,
			 p_org_id           => l_org_id,
			 p_address_line1    => cur_site.address_line1,
			 p_address_line2    => cur_site.address_line2,
			 p_address_line3    => NULL, -- AviH Change. Was: cur_site.address_line3,
			 p_address_line4    => cur_site.address_line4,
			 p_city             => cur_site.city,
			 p_county           => cur_site.county,
			 p_state            => cur_site.state,
			 p_postal_code      => cur_site.postal_code,
			 p_country          => cur_site.country,
			 p_address_category => NULL,
			 --p_bank_acc_number   => NULL,
			 --p_collection_note   => NULL,
			 --p_cust_organization => NULL,
			 p_sales_territory   => cur_site.sales_territory,
			 p_cust_acct_site_id => l_cust_acct_site_id,
			 p_party_site_id     => l_party_site_id,
			 p_return_sts        => l_return_status,
			 p_err_msg           => l_err_msg);
	  
	    --  dbms_output.put_line('l_return_status = ' || l_return_status);
	    --  dbms_output.put_line('l_err_msg = ' || l_err_msg);
	  
	    IF l_return_status != fnd_api.g_ret_sts_success THEN
	      RAISE invalid_customer;
	    END IF;
	  END;
	ELSE
	  -- site already exists
	  l_flg_site_exists := 'Y';
	END IF;
          
	FOR cur_site_use IN csr_cust_site_uses(cur_customer.organization_name,
				   --cur_site.site_identifier,
				   cur_customer.customer_category,
				   cur_site.site_name) LOOP
	  BEGIN
	  
	    l_flg_site_use_exists := NULL;
	  
	    IF is_cust_site_use_exists(p_cust_acct_site_id => l_cust_acct_site_id,
			       p_site_use_code     => cur_site_use.business_porposes,
			       p_site_use_id       => l_site_uses_id) = TRUE THEN
	      BEGIN
	        IF l_cust_acct_site_id <> -99 -- AND cur_site.site_exists_flag = 'N'
	         THEN
	          BEGIN
	          
		create_cust_site_use(p_org_id            => l_org_id,
			         p_customer_name     => cur_site_use.organization_name,
			         p_cust_acct_site_id => l_cust_acct_site_id,
			         p_location          => cur_site_use.location,
			         p_bus_pur_usage     => cur_site_use.business_porposes,
			         --p_site_identifier       => cur_site_use.site_identifier,
			         p_bus_pur_primary => cur_site_use.business_porposes_primary,
			         p_tax_code        => NULL, --cur_site_use.tax_code,
			         p_demand_class    => NULL, --cur_site_use.demand_class,
			         p_payment_terms   => cur_site_use.payment_terms,
			         p_ship_terms      => NULL, -- cur_site_use.address_line3,--Temp - hold the ST
			         p_sales_person    => cur_site_use.sales_person,
			         p_order_type      => NULL, --cur_site_use.order_type,
			         p_price_list      => cur_site_use.price_list,
			         --p_brand                 => NULL, --cur_site_use.brand,
			         --p_ocean_dest_port       => NULL, --cur_site_use.ocean_dest_port,
			         --p_air_dest_port         => NULL, --cur_site_use.air_dest_port,
			         p_means_of_transport => NULL, --cur_site_use.means_of_transport,
			         --p_order_opening_instr   => NULL, --cur_site_use.order_opening_instr,
			         --p_packing_instruct      => NULL, --cur_site_use.packing_instruct,
			         --p_quality_instruct      => NULL, --cur_site_use.quality_instruct,
			         --p_labeling_instruct     => NULL, --cur_site_use.labeling_instruct,
			         --p_printed_invoice_text  => NULL, --cur_site_use.printed_invoice_text,
			         --p_printed_proforma_text => NULL, --cur_site_use.printed_proforma_text,
			         --p_label_code            => NULL, --cur_site_use.label_code,
			         --p_shipping_instruct     => NULL, --cur_site_use.shipping_instruct,
			         --p_marks                 => NULL, --cur_site_use.marks,
			         --p_cust_samples          => NULL, --cur_site_use.cust_samples,
			         --p_cust_samples_in_out   => NULL, --cur_site_use.cust_samples_in_out,
			         --p_cust_samples_yes_no   => NULL, --cur_site_use.cust_samples_yes_no,
			         --p_treatment             => NULL, -- cur_site_use.treatment,
			         -- p_No_Picture            => cur_site_use.No_Picture,
			         --p_picture_code       => NULL, --cur_site_use.picture_code,
			         --p_netural_label      => NULL, --cur_site_use.netural_label,
			         p_receivable_acc     => cur_site_use.receivable,
			         p_revenue_acc        => cur_site_use.revenue,
			         p_unearned_revenue   => cur_site_use.unearned_revenue,
			         p_cust_account_id    => l_cust_account_id,
			         p_party_id           => l_party_id,
			         p_prof_class         => 'DEFAULT',
			         p_collector          => NULL, --cur_site_use.collector,
			         p_credit_check       => cur_site_use.site_credit_check,
			         p_credit_hold        => NULL, --cur_site_use.credit_hold,
			         p_currency           => cur_site_use.site_credit_currency,
			         p_credit_limit       => cur_site_use.site_credit_limit,
			         p_order_credit_limit => cur_site_use.site_ord_credit_limit,
			         p_return_sts         => l_return_status,
			         p_err_msg            => l_err_msg);
	          
		IF l_return_status != fnd_api.g_ret_sts_success THEN
		  RAISE invalid_customer;
		END IF;
	          END;
	        END IF;
	      END;
	    ELSE
	      -- customer site use exists
	      l_flg_site_use_exists := 'Y';
	    END IF; -- End of customer site use exists check
	  
	    -- We loaded the cust, site and site use
	    -- flag the record as processed in staging
	  
	    UPDATE xxobjt_conv_hz_customers cc
	    SET    cc.error_code           = 'S',
	           cc.cust_exists_flag     = l_flg_cust_exists,
	           cc.site_exists_flag     = l_flg_site_exists,
	           cc.site_use_exists_flag = l_flg_site_use_exists
	    WHERE  cc.organization_name = cur_site.organization_name
	    AND    cc.site_name = cur_site.site_name
	    AND    cc.customer_category =
	           cur_site_use.customer_category
	    AND    cc.business_porposes =
	           cur_site_use.business_porposes
	    AND    cc.error_code = 'N';
	  
	    COMMIT;
	  
	  END;
	END LOOP; -- end of site use loop
          
          END;
        END LOOP; -- end of sites loop
      
      EXCEPTION
        WHEN invalid_customer THEN
          -- customer exception
          ROLLBACK;
          UPDATE xxobjt_conv_hz_customers cc
          SET    cc.error_code = 'E',
	     -- cc.cust_exists_flag = 'N',
	     cc.error_message = l_err_msg
          WHERE  cc.organization_name = cur_customer.organization_name
          AND    cc.customer_category = cur_customer.customer_category
          AND    cc.error_code = 'N';
          COMMIT;
      END;
    END LOOP; -- end of customers loop
  
  END main;

  --------------------------

  --------------------------------------------------------------------
  --  name:            get_value_from_line
  --  create by:       Ella malchi
  --  Revision:        1.0
  --  creation date:   08/03/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        get value from excel line
  --                   return short string each time by the deliminar
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  08/03/2010  Ella malchi      initial build
  --------------------------------------------------------------------
  FUNCTION get_value_from_line(p_line_string IN OUT VARCHAR2,
		       p_err_msg     IN OUT VARCHAR2,
		       --p_counter     in number,
		       c_delimiter IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_pos        NUMBER;
    l_char_value VARCHAR2(20);
  
  BEGIN
  
    l_pos := instr(p_line_string, c_delimiter);
  
    IF nvl(l_pos, 0) < 1 THEN
      l_pos := length(p_line_string);
    END IF;
  
    l_char_value := ltrim(rtrim(substr(p_line_string, 1, l_pos - 1)));
  
    p_line_string := substr(p_line_string, l_pos + 1);
  
    RETURN l_char_value;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_msg := 'get_value_from_line - ' || substr(SQLERRM, 1, 250);
  END get_value_from_line;

  --------------------------------------------------------------------
  --  name:            upd_site_use
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/03/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        Update sales person and attribute11 at hz_cust_site_uses
  --                   use API HZ_CUST_ACCOUNT_SITE_V2PUB.update_cust_site_use
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  08/03/2010  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE upd_cust_site_use(errbuf  OUT VARCHAR2,
		      retcode OUT VARCHAR2) IS
  
    invalid_item EXCEPTION;
    l_valid             VARCHAR2(5) := 'VALID';
    l_primary_flag      VARCHAR2(1) := NULL;
    l_status            VARCHAR2(1) := NULL;
    l_ovn               NUMBER := NULL;
    l_orig_sys_ref      VARCHAR2(240) := NULL;
    l_site_use_id       NUMBER := NULL;
    t_cust_site_use_rec hz_cust_account_site_v2pub.cust_site_use_rec_type;
    l_return_status     VARCHAR2(2000);
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(2000);
    l_data              VARCHAR2(2000);
    l_msg_index_out     NUMBER;
    l_salesrep_id       NUMBER;
    l_org_id            NUMBER;
    l_user_id           NUMBER := NULL;
    --l_att_salesrep_id   number         := null;
    l_distributor_flag  VARCHAR2(1) := 'Y';
    l_site_territory_id NUMBER := NULL;
  
    CURSOR get_pop_to_upd_c IS
      SELECT xx.entity_id,
	 xx.account_number,
	 xx.site_number,
	 --xx.site_name,
	 xx.site_use_code,
	 xx.site_sale_person,
	 xx.distributor_attribute11,
	 xx.site_territory
      FROM   xxar_cust_site_use_temp xx
      WHERE  xx.err_message IS NULL;
    --and    rownum < 200;
  
  BEGIN
    SELECT user_id
    INTO   l_user_id
    FROM   fnd_user
    WHERE  user_name = 'CONVERSION';
  
    fnd_global.apps_initialize(user_id      => g_user_id,
		       resp_id      => 20420,
		       resp_appl_id => 1);
  
    FOR get_pop_to_upd_r IN get_pop_to_upd_c LOOP
      l_site_use_id       := NULL;
      l_primary_flag      := NULL;
      l_status            := NULL;
      l_ovn               := NULL;
      l_orig_sys_ref      := NULL;
      l_org_id            := NULL;
      l_salesrep_id       := NULL;
      l_valid             := 'VALID';
      l_distributor_flag  := 'Y';
      l_site_territory_id := NULL;
      -- start validation
      BEGIN
        -- check data from DB
        SELECT hcsu.site_use_id,
	   hcsu.primary_flag,
	   hcsu.status,
	   hcsu.object_version_number ovn,
	   hcsu.orig_system_reference osr,
	   hcsu.org_id
        INTO   l_site_use_id,
	   l_primary_flag,
	   l_status,
	   l_ovn,
	   l_orig_sys_ref,
	   l_org_id
        FROM   hz_cust_acct_sites hcas,
	   hz_cust_site_uses  hcsu,
	   hz_cust_accounts   hca,
	   hz_parties         hp,
	   hz_party_sites     hps
        WHERE  hp.party_id = hps.party_id
        AND    hp.party_id = hca.party_id
        AND    hcas.party_site_id = hps.party_site_id
        AND    hcas.cust_account_id = hca.cust_account_id
        AND    hcsu.cust_acct_site_id = hcas.cust_acct_site_id
        AND    hca.cust_account_id = hcas.cust_account_id
        AND    hca.account_number = get_pop_to_upd_r.account_number
        AND    hcsu.site_use_code = get_pop_to_upd_r.site_use_code
        AND    hps.party_site_number = get_pop_to_upd_r.site_number
        AND    hcsu.org_id = 89; -- 89 is US ORG_ID
      
        -- if valid i call API else write message to log
        l_valid := 'VALID';
        -- Call to API
      EXCEPTION
        WHEN no_data_found THEN
          l_valid := 'NOT';
          dbms_output.put_line('1 Account Number - ' ||
		       get_pop_to_upd_r.account_number ||
		       ' Site use code - ' ||
		       get_pop_to_upd_r.site_use_code ||
		       ' Site number - ' ||
		       get_pop_to_upd_r.site_number || ' Error - ' ||
		       substr(SQLERRM, 1, 100));
          BEGIN
	--l_message := null;
	--l_message := substr(sqlerrm,1,150);
	UPDATE xxar_cust_site_use_temp xx
	SET    xx.err_code         = 1,
	       xx.err_message      = ' Account number - ' ||
			     get_pop_to_upd_r.account_number ||
			     ' Site use Code - ' ||
			     get_pop_to_upd_r.site_use_code ||
			     ' Site Number - ' ||
			     get_pop_to_upd_r.site_number ||
			     ' Error - no data found',
	       xx.last_update_date = SYSDATE,
	       xx.creation_date    = SYSDATE,
	       xx.last_updated_by  = l_user_id,
	       xx.created_by       = l_user_id
	WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
          
	COMMIT;
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('Problem upd temp tbl - ' ||
		           substr(SQLERRM, 1, 150));
	
          END;
        WHEN too_many_rows THEN
          l_valid := 'NOT';
          dbms_output.put_line('2 Account Number - ' ||
		       get_pop_to_upd_r.account_number ||
		       ' Site use code - ' ||
		       get_pop_to_upd_r.site_use_code ||
		       ' Site number - ' ||
		       get_pop_to_upd_r.site_number || ' Error - ' ||
		       substr(SQLERRM, 1, 100));
          BEGIN
	--l_message := null;
	--l_message := substr(sqlerrm,1,150);
	UPDATE xxar_cust_site_use_temp xx
	SET    xx.err_code         = 2,
	       xx.err_message      = ' Account number - ' ||
			     get_pop_to_upd_r.account_number ||
			     ' Site use Code - ' ||
			     get_pop_to_upd_r.site_use_code ||
			     ' Site Number - ' ||
			     get_pop_to_upd_r.site_number ||
			     ' Error - exact fetch returns more than requested number of rows',
	       xx.last_update_date = SYSDATE,
	       xx.creation_date    = SYSDATE,
	       xx.last_updated_by  = l_user_id,
	       xx.created_by       = l_user_id
	WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
	COMMIT;
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('Problem upd temp tbl - ' ||
		           substr(SQLERRM, 1, 150));
          END;
        WHEN OTHERS THEN
          l_valid := 'NOT';
          dbms_output.put_line('3 Account Number - ' ||
		       get_pop_to_upd_r.account_number ||
		       ' Site use code - ' ||
		       get_pop_to_upd_r.site_use_code ||
		       ' Site number - ' ||
		       get_pop_to_upd_r.site_number || ' Error - ' ||
		       substr(SQLERRM, 1, 100));
          BEGIN
	--l_message := null;
	--l_message := substr(sqlerrm,1,150);
	UPDATE xxar_cust_site_use_temp xx
	SET    xx.err_code         = 3,
	       xx.err_message      = ' Account number - ' ||
			     get_pop_to_upd_r.account_number ||
			     ' Site use Code - ' ||
			     get_pop_to_upd_r.site_use_code ||
			     ' Site Number - ' ||
			     get_pop_to_upd_r.site_number ||
			     ' Error - general error ',
	       xx.last_update_date = SYSDATE,
	       xx.creation_date    = SYSDATE,
	       xx.last_updated_by  = l_user_id,
	       xx.created_by       = l_user_id
	WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
	COMMIT;
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('Problem upd temp tbl - ' ||
		           substr(SQLERRM, 1, 150));
          END;
      END;
      -- Check Salesperson from excel exists in data base
      BEGIN
        l_salesrep_id := NULL;
        SELECT t.salesrep_id
        INTO   l_salesrep_id
        FROM   jtf_rs_resource_extns_vl rs,
	   jtf.jtf_rs_salesreps     t
        WHERE  rs.resource_id = t.resource_id
        AND    rs.resource_name = get_pop_to_upd_r.site_sale_person --'No Sales Credit'
        AND    t.org_id = l_org_id; -- 89
      EXCEPTION
        WHEN OTHERS THEN
          l_valid := 'NOT';
          dbms_output.put_line('4 Account Number - ' ||
		       get_pop_to_upd_r.account_number ||
		       ' Site use code - ' ||
		       get_pop_to_upd_r.site_use_code ||
		       ' Site number - ' ||
		       get_pop_to_upd_r.site_number ||
		       ' SalesPerson name - ' ||
		       get_pop_to_upd_r.site_sale_person ||
		       ' Org - ' || l_org_id || ' Error - ' ||
		       substr(SQLERRM, 1, 100));
          BEGIN
	UPDATE xxar_cust_site_use_temp xx
	SET    xx.err_code         = 4,
	       xx.err_message      = 'This Sales Person does not exists in Oracle ' ||
			     get_pop_to_upd_r.site_sale_person,
	       xx.last_update_date = SYSDATE,
	       xx.creation_date    = SYSDATE,
	       xx.last_updated_by  = l_user_id,
	       xx.created_by       = l_user_id
	WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
	COMMIT;
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('Problem upd temp tbl - ' ||
		           substr(SQLERRM, 1, 150));
          END;
      END;
      -- Check Territory from excel exists in data base
      BEGIN
        IF get_pop_to_upd_r.site_territory IS NOT NULL THEN
          SELECT rt.territory_id --, rt.name, rt.enabled_flag
          INTO   l_site_territory_id
          FROM   ra_territories rt
          WHERE  rt.name = get_pop_to_upd_r.site_territory -- 'USA.United States';
          AND    rt.enabled_flag = 'Y';
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_valid := 'NOT';
          dbms_output.put_line('5 Account Number - ' ||
		       get_pop_to_upd_r.account_number ||
		       ' Site use code - ' ||
		       get_pop_to_upd_r.site_use_code ||
		       ' Site number - ' ||
		       get_pop_to_upd_r.site_number ||
		       ' Territory name - ' ||
		       get_pop_to_upd_r.site_territory ||
		       ' Org - ' || l_org_id || ' Error - ' ||
		       substr(SQLERRM, 1, 100));
          BEGIN
	UPDATE xxar_cust_site_use_temp xx
	SET    xx.err_code_terr    = 5,
	       xx.err_message_ter  = 'This Territory does not exists in Oracle ' ||
			     get_pop_to_upd_r.site_territory,
	       xx.last_update_date = SYSDATE,
	       xx.creation_date    = SYSDATE,
	       xx.last_updated_by  = l_user_id,
	       xx.created_by       = l_user_id
	WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
	COMMIT;
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('Problem upd temp tbl - ' ||
		           substr(SQLERRM, 1, 150));
          END;
      END;
    
      --
      IF l_valid = 'VALID' THEN
        mo_global.set_policy_context(p_access_mode => 'S',
			 p_org_id      => l_org_id);
        mo_global.set_org_access(p_org_id_char     => l_org_id,
		         p_sp_id_char      => NULL,
		         p_appl_short_name => 'AR');
        ---------------------------------
        -- Update an account site use  --
        ---------------------------------
        t_cust_site_use_rec.site_use_id           := NULL;
        t_cust_site_use_rec.primary_flag          := NULL;
        t_cust_site_use_rec.site_use_code         := NULL;
        t_cust_site_use_rec.primary_salesrep_id   := NULL;
        t_cust_site_use_rec.orig_system_reference := NULL;
        --t_cust_site_use_rec.attribute_category    := null;
        --t_cust_site_use_rec.attribute11           := null;
      
        t_cust_site_use_rec.site_use_id           := l_site_use_id;
        t_cust_site_use_rec.primary_flag          := l_primary_flag;
        t_cust_site_use_rec.site_use_code         := get_pop_to_upd_r.site_use_code;
        t_cust_site_use_rec.primary_salesrep_id   := l_salesrep_id;
        t_cust_site_use_rec.orig_system_reference := l_orig_sys_ref;
        t_cust_site_use_rec.territory_id          := l_site_territory_id;
        --if get_pop_to_upd_r.distributor_attribute11 is not null and get_pop_to_upd_r.site_use_code = 'SHIP_TO' then
        --  t_cust_site_use_rec.attribute_category    := 'SHIP_TO';
        --  t_cust_site_use_rec.attribute11           := l_att_salesrep_id;--get_pop_to_upd_r.distributor_attribute11;
        --end if;
        l_return_status := NULL;
        l_msg_count     := NULL;
        l_msg_data      := NULL;
        hz_cust_account_site_v2pub.update_cust_site_use(p_init_msg_list         => 'T',
				        p_cust_site_use_rec     => t_cust_site_use_rec,
				        p_object_version_number => l_ovn,
				        x_return_status         => l_return_status,
				        x_msg_count             => l_msg_count,
				        x_msg_data              => l_msg_data);
      
        IF l_return_status <> fnd_api.g_ret_sts_success THEN
          errbuf  := 'Error Update Cust Site Use: ';
          retcode := 1;
        
          dbms_output.put_line('6 Update Cust Site Use Failed ' ||
		       ' Account Number - ' ||
		       get_pop_to_upd_r.account_number ||
		       ' Site use code - ' ||
		       get_pop_to_upd_r.site_use_code ||
		       ' Site number - ' ||
		       get_pop_to_upd_r.site_number ||
		       ' SalesPerson name - ' ||
		       get_pop_to_upd_r.site_sale_person ||
		       ' Org - ' || l_org_id);
        
          FOR i IN 1 .. l_msg_count LOOP
	fnd_msg_pub.get(p_msg_index     => i,
		    p_data          => l_data,
		    p_encoded       => fnd_api.g_false,
		    p_msg_index_out => l_msg_index_out);
	dbms_output.put_line(' l_msg_count = ' || to_char(l_msg_count) ||
		         ' l_msg_data = ' || l_msg_data);
	--l_err_msg := l_err_msg || l_data || chr(10);
          END LOOP;
          BEGIN
	UPDATE xxar_cust_site_use_temp xx
	SET    xx.err_code         = 6,
	       xx.err_message      = 'API Failed ' ||
			     ' Account number - ' ||
			     get_pop_to_upd_r.account_number ||
			     ' Site use Code - ' ||
			     get_pop_to_upd_r.site_use_code ||
			     ' Site Number - ' ||
			     get_pop_to_upd_r.site_number ||
			     l_msg_data,
	       xx.last_update_date = SYSDATE,
	       xx.creation_date    = SYSDATE,
	       xx.last_updated_by  = l_user_id,
	       xx.created_by       = l_user_id
	WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
	COMMIT;
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('Problem upd temp tbl - ' ||
		           substr(SQLERRM, 1, 150));
          END;
        
          ROLLBACK;
        ELSE
          BEGIN
	UPDATE xxar_cust_site_use_temp xx
	SET    xx.err_code         = 7,
	       xx.err_message      = xx.err_message || ' - Success',
	       xx.last_update_date = SYSDATE,
	       xx.creation_date    = SYSDATE,
	       xx.last_updated_by  = l_user_id,
	       xx.created_by       = l_user_id
	WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('Problem upd temp tbl - ' ||
		           substr(SQLERRM, 1, 150));
          END;
          COMMIT;
        END IF; -- l_return
      
      END IF;
    END LOOP;
    IF retcode IS NULL OR retcode <> 1 THEN
      retcode := 0;
      errbuf  := 'Success';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Load AR customer site used - General exception - ' ||
	     substr(SQLERRM, 1, 250);
      retcode := 1;
  END upd_cust_site_use;

  --------------------------------------------------------------------
  --  name:            upd_party_site_att
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   11/03/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        Update attribute11 at party_site
  --                   use HZ_PARTY_SITE_V2PUB.update_party_site
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  11/03/2010  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE upd_party_site_att(errbuf  OUT VARCHAR2,
		       retcode OUT VARCHAR2) IS
  
    CURSOR get_pop_to_upd_c IS
      SELECT xx.entity_id,
	 xx.account_number,
	 xx.site_number,
	 xx.site_use_code,
	 xx.site_sale_person,
	 xx.distributor_attribute11,
	 xx.site_territory
      FROM   xxar_cust_site_use_temp xx
      WHERE  xx.err_message_att IS NULL
      AND    xx.distributor_attribute11 IS NOT NULL;
    --and    rownum < 5;
  
    l_user_id                  NUMBER := NULL;
    l_party_site_id            NUMBER := NULL;
    l_party_id                 NUMBER := NULL;
    l_location_id              NUMBER := NULL;
    l_account_number           VARCHAR2(30) := NULL;
    l_ovn                      NUMBER := NULL;
    l_status                   VARCHAR2(1) := NULL;
    l_identifying_address_flag VARCHAR2(1) := NULL;
    l_valid                    VARCHAR2(5) := 'VALID';
    l_att_salesrep_id          NUMBER := NULL;
    l_org_id                   NUMBER := NULL;
    t_party_site_rec_type      hz_party_site_v2pub.party_site_rec_type;
    l_return_status            VARCHAR2(2000);
    l_msg_count                NUMBER;
    l_msg_data                 VARCHAR2(2000);
    l_data                     VARCHAR2(2000);
    l_msg_index_out            NUMBER;
  
  BEGIN
    SELECT user_id
    INTO   l_user_id
    FROM   fnd_user
    WHERE  user_name = 'CONVERSION';
  
    fnd_global.apps_initialize(user_id      => g_user_id,
		       resp_id      => 20420,
		       resp_appl_id => 1);
  
    FOR get_pop_to_upd_r IN get_pop_to_upd_c LOOP
      l_party_id                 := NULL;
      l_location_id              := NULL;
      l_account_number           := NULL;
      l_ovn                      := NULL;
      l_status                   := NULL;
      l_identifying_address_flag := NULL;
      l_valid                    := 'VALID';
      l_att_salesrep_id          := NULL;
      l_org_id                   := NULL;
      BEGIN
        SELECT DISTINCT hps.party_site_id,
		hp.party_id,
		hps.location_id,
		hca.account_number,
		hps.object_version_number ovn,
		hps.status,
		hps.identifying_address_flag,
		hcsu.org_id
        INTO   l_party_site_id,
	   l_party_id,
	   l_location_id,
	   l_account_number,
	   l_ovn,
	   l_status,
	   l_identifying_address_flag,
	   l_org_id
        FROM   hz_cust_acct_sites hcas,
	   hz_cust_site_uses  hcsu,
	   hz_cust_accounts   hca,
	   hz_parties         hp,
	   hz_party_sites     hps
        WHERE  hp.party_id = hps.party_id
        AND    hp.party_id = hca.party_id
        AND    hcas.party_site_id = hps.party_site_id
        AND    hcas.cust_account_id = hca.cust_account_id
        AND    hcsu.cust_acct_site_id = hcas.cust_acct_site_id
        AND    hca.cust_account_id = hcas.cust_account_id
        AND    hca.account_number = get_pop_to_upd_r.account_number --'AC00435'
        AND    hps.party_site_number = get_pop_to_upd_r.site_number
        AND    hcsu.site_use_code = get_pop_to_upd_r.site_use_code
        AND    hcsu.org_id = 89;
      EXCEPTION
        WHEN no_data_found THEN
          l_valid := 'NOT';
          dbms_output.put_line('1 Account Number - ' ||
		       get_pop_to_upd_r.account_number ||
		       ' Site use code - ' ||
		       get_pop_to_upd_r.site_use_code ||
		       ' Site number - ' ||
		       get_pop_to_upd_r.site_number || ' Error - ' ||
		       substr(SQLERRM, 1, 100));
          BEGIN
	UPDATE xxar_cust_site_use_temp xx
	SET    xx.err_code_att     = 1,
	       xx.err_message_att  = ' Account number - ' ||
			     get_pop_to_upd_r.account_number ||
			     ' Site use Code - ' ||
			     get_pop_to_upd_r.site_use_code ||
			     ' Site Number - ' ||
			     get_pop_to_upd_r.site_number ||
			     ' Error - no data found',
	       xx.last_update_date = SYSDATE,
	       xx.creation_date    = SYSDATE,
	       xx.last_updated_by  = l_user_id,
	       xx.created_by       = l_user_id
	WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
          
	COMMIT;
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('Problem upd temp tbl - ' ||
		           substr(SQLERRM, 1, 150));
	
          END;
        WHEN too_many_rows THEN
          l_valid := 'NOT';
          dbms_output.put_line('2 Account Number - ' ||
		       get_pop_to_upd_r.account_number ||
		       ' Site use code - ' ||
		       get_pop_to_upd_r.site_use_code ||
		       ' Site number - ' ||
		       get_pop_to_upd_r.site_number || ' Error - ' ||
		       substr(SQLERRM, 1, 100));
          BEGIN
	--l_message := null;
	--l_message := substr(sqlerrm,1,150);
	UPDATE xxar_cust_site_use_temp xx
	SET    xx.err_code_att     = 2,
	       xx.err_message_att  = ' Account number - ' ||
			     get_pop_to_upd_r.account_number ||
			     ' Site use Code - ' ||
			     get_pop_to_upd_r.site_use_code ||
			     ' Site Number - ' ||
			     get_pop_to_upd_r.site_number ||
			     ' Error - exact fetch returns more than requested number of rows',
	       xx.last_update_date = SYSDATE,
	       xx.creation_date    = SYSDATE,
	       xx.last_updated_by  = l_user_id,
	       xx.created_by       = l_user_id
	WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
	COMMIT;
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('Problem upd temp tbl - ' ||
		           substr(SQLERRM, 1, 150));
          END;
        WHEN OTHERS THEN
          l_valid := 'NOT';
          dbms_output.put_line('3 Account Number - ' ||
		       get_pop_to_upd_r.account_number ||
		       ' Site use code - ' ||
		       get_pop_to_upd_r.site_use_code ||
		       ' Site number - ' ||
		       get_pop_to_upd_r.site_number || ' Error - ' ||
		       substr(SQLERRM, 1, 100));
          BEGIN
	UPDATE xxar_cust_site_use_temp xx
	SET    xx.err_code_att     = 3,
	       xx.err_message_att  = ' Account number - ' ||
			     get_pop_to_upd_r.account_number ||
			     ' Site use Code - ' ||
			     get_pop_to_upd_r.site_use_code ||
			     ' Site Number - ' ||
			     get_pop_to_upd_r.site_number ||
			     ' Error - general error ',
	       xx.last_update_date = SYSDATE,
	       xx.creation_date    = SYSDATE,
	       xx.last_updated_by  = l_user_id,
	       xx.created_by       = l_user_id
	WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
	COMMIT;
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('Problem upd temp tbl - ' ||
		           substr(SQLERRM, 1, 150));
          END;
      END;
    
      -- Check Distributor from excel exists in data base
      IF get_pop_to_upd_r.distributor_attribute11 IS NOT NULL THEN
        BEGIN
          l_att_salesrep_id := NULL;
          SELECT t.salesrep_id
          INTO   l_att_salesrep_id
          FROM   jtf_rs_resource_extns_vl rs,
	     jtf.jtf_rs_salesreps     t
          WHERE  rs.resource_id = t.resource_id
          AND    rs.resource_name =
	     get_pop_to_upd_r.distributor_attribute11 --'No Sales Credit'
          AND    t.org_id = l_org_id; -- 89
        EXCEPTION
          WHEN OTHERS THEN
	l_valid := 'NOT';
	--l_distributor_flag := 'N';
	dbms_output.put_line('4.1 Account Number - ' ||
		         get_pop_to_upd_r.account_number ||
		         ' Site use code - ' ||
		         get_pop_to_upd_r.site_use_code ||
		         ' Site number - ' ||
		         get_pop_to_upd_r.site_number ||
		         ' SalesPerson name - ' ||
		         get_pop_to_upd_r.distributor_attribute11 ||
		         ' Org - ' || l_org_id || ' Error - ' ||
		         substr(SQLERRM, 1, 100));
	BEGIN
	  UPDATE xxar_cust_site_use_temp xx
	  SET    xx.err_code_att     = 4,
	         xx.err_message_att  = 'This Distributor do not exists in Oracle ' ||
			       get_pop_to_upd_r.distributor_attribute11,
	         xx.last_update_date = SYSDATE,
	         xx.creation_date    = SYSDATE,
	         xx.last_updated_by  = l_user_id,
	         xx.created_by       = l_user_id
	  WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
	  COMMIT;
	EXCEPTION
	  WHEN OTHERS THEN
	    dbms_output.put_line('Problem upd temp tbl - ' ||
			 substr(SQLERRM, 1, 150));
	END; -- update
        END; -- check salesperson
      END IF; -- att11
    
      IF l_valid = 'VALID' THEN
        mo_global.set_policy_context(p_access_mode => 'S',
			 p_org_id      => l_org_id);
        mo_global.set_org_access(p_org_id_char     => l_org_id,
		         p_sp_id_char      => NULL,
		         p_appl_short_name => 'AR');
      
        t_party_site_rec_type := NULL;
      
        t_party_site_rec_type.party_site_id            := l_party_site_id;
        t_party_site_rec_type.party_id                 := l_party_id;
        t_party_site_rec_type.location_id              := l_location_id;
        t_party_site_rec_type.identifying_address_flag := l_identifying_address_flag;
        t_party_site_rec_type.status                   := l_status;
        t_party_site_rec_type.attribute_category       := 'SHIP_TO';
        t_party_site_rec_type.attribute11              := l_att_salesrep_id;
      
        l_return_status := NULL;
        l_msg_count     := NULL;
        l_msg_data      := NULL;
        l_data          := NULL;
        l_msg_index_out := NULL;
      
        hz_party_site_v2pub.update_party_site(p_init_msg_list         => 'T',
			          p_party_site_rec        => t_party_site_rec_type,
			          p_object_version_number => l_ovn,
			          x_return_status         => l_return_status,
			          x_msg_count             => l_msg_count,
			          x_msg_data              => l_msg_data);
      
        --dbms_output.put_line('l_return_status - '||l_return_status);
      
        IF l_return_status <> fnd_api.g_ret_sts_success THEN
          errbuf  := 'Error Update Cust Site Use: ';
          retcode := 1;
        
          dbms_output.put_line('5 Update Cust Site Use Failed ' ||
		       ' Account Number - ' ||
		       get_pop_to_upd_r.account_number ||
		       ' Site use code - ' ||
		       get_pop_to_upd_r.site_use_code ||
		       ' Site number - ' ||
		       get_pop_to_upd_r.site_number ||
		       ' SalesPerson name - ' ||
		       get_pop_to_upd_r.distributor_attribute11 ||
		       ' Org - ' || l_org_id);
        
          FOR i IN 1 .. l_msg_count LOOP
	fnd_msg_pub.get(p_msg_index     => i,
		    p_data          => l_data,
		    p_encoded       => fnd_api.g_false,
		    p_msg_index_out => l_msg_index_out);
	dbms_output.put_line(' l_msg_count = ' || to_char(l_msg_count) ||
		         ' l_msg_data = ' || l_msg_data);
	--l_err_msg := l_err_msg || l_data || chr(10);
          END LOOP;
          BEGIN
	UPDATE xxar_cust_site_use_temp xx
	SET    xx.err_code_att     = 5,
	       xx.err_message_att  = 'API Failed ' ||
			     ' Account number - ' ||
			     get_pop_to_upd_r.account_number ||
			     ' Site use Code - ' ||
			     get_pop_to_upd_r.site_use_code ||
			     ' Site Number - ' ||
			     get_pop_to_upd_r.site_number ||
			     l_msg_data,
	       xx.last_update_date = SYSDATE,
	       xx.creation_date    = SYSDATE,
	       xx.last_updated_by  = l_user_id,
	       xx.created_by       = l_user_id
	WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
	COMMIT;
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('Problem upd temp tbl - ' ||
		           substr(SQLERRM, 1, 150));
          END;
        
          ROLLBACK;
        ELSE
          BEGIN
	UPDATE xxar_cust_site_use_temp xx
	SET    xx.err_code_att     = 6,
	       xx.err_message_att  = 'SUCCESS ATT',
	       xx.last_update_date = SYSDATE,
	       xx.creation_date    = SYSDATE,
	       xx.last_updated_by  = l_user_id,
	       xx.created_by       = l_user_id
	WHERE  xx.entity_id = get_pop_to_upd_r.entity_id;
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('Problem upd temp tbl - ' ||
		           substr(SQLERRM, 1, 150));
          END;
          COMMIT;
        END IF; -- l_return
      END IF; -- valid
    END LOOP;
  END upd_party_site_att;

  --------------------------------------------------------------------
  --  name:            upd_entity_id_for_prog
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   11/03/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        enter value to entity id field
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  08/03/2010  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE upd_entity_id_for_prog IS
  
    CURSOR get_pop_c IS
      SELECT xx.account_number,
	 xx.site_number,
	 xx.site_name,
	 xx.site_use_code,
	 xx.site_sale_person,
	 xx.distributor_attribute11
      FROM   xxar_cust_site_use_temp xx;
  
    l_id NUMBER := NULL;
  BEGIN
    FOR get_pop_r IN get_pop_c LOOP
      SELECT xxar_cust_site_use_temp_s.nextval
      INTO   l_id
      FROM   dual;
    
      BEGIN
        UPDATE xxar_cust_site_use_temp xx
        SET    entity_id = l_id
        WHERE  xx.account_number = get_pop_r.account_number
        AND    xx.site_number = get_pop_r.site_number
        AND    nvl(xx.site_name, 'DD') = nvl(get_pop_r.site_name, 'DD')
        AND    xx.site_use_code = get_pop_r.site_use_code
        AND    xx.site_sale_person = get_pop_r.site_sale_person;
      EXCEPTION
        WHEN OTHERS THEN
          dbms_output.put_line('Sqlerrm - ' || SQLERRM);
      END;
    END LOOP;
  
    COMMIT;
  END upd_entity_id_for_prog;

  --------------------------------------------------------------------
  --  name:            upd_temp_tbl
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that update xxobjt_conv_hz_contacts tbl
  --                   with errors from API's
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE upd_temp_tbl(p_entity_id  IN NUMBER,
		 p_status     IN VARCHAR2,
		 p_error_code IN OUT VARCHAR2,
		 p_error_msg  IN OUT VARCHAR2) IS
  
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_count NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_count
    FROM   xxobjt_conv_hz_contacts c
    WHERE  c.entity_id = p_entity_id
    AND    c.status IN ('ERROR', 'WARNING');
  
    UPDATE xxobjt_conv_hz_contacts c
    SET    c.run_code    = decode(l_count, 0, p_error_code, c.run_code),
           c.run_message = decode(nvl(c.run_message, 'DD'),
		          'DD',
		          p_error_msg,
		          c.run_message || chr(10) || p_error_msg),
           c.status      = decode(l_count, 0, p_status, c.status) --'ERROR', SUCCESS, WARNING
    WHERE  c.entity_id = p_entity_id;
  
    COMMIT;
    p_error_code := 0;
    p_error_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_msg  := 'GEN EXC - upd_temp_tbl - ' ||
	          substr(SQLERRM, 1, 240);
  END upd_temp_tbl;

  --------------------------------------------------------------------
  --  name:            upd_temp_point_tbl
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that update XXOBJT_CONV_HZ_CONTACT_POINTS
  --                   with log messages from API's
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE upd_temp_point_tbl(p_entity_id  IN NUMBER,
		       p_status     IN VARCHAR2,
		       p_error_code IN OUT VARCHAR2,
		       p_error_msg  IN OUT VARCHAR2) IS
  
    PRAGMA AUTONOMOUS_TRANSACTION;
  
  BEGIN
  
    UPDATE xxobjt_conv_hz_contact_points c
    SET    c.run_code    = p_error_code,
           c.run_message = p_error_msg,
           c.status      = p_status --'ERROR', SUCCESS, WARNING
    WHERE  c.entity_id = p_entity_id;
  
    COMMIT;
    p_error_code := 0;
    p_error_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_msg  := 'GEN EXC - upd_temp_tbl - ' ||
	          substr(SQLERRM, 1, 240);
  END upd_temp_point_tbl;

  --------------------------------------------------------------------
  --  name:            update_contact_point_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that update contact_point API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_contact_point_api(p_party_id         IN NUMBER,
			 p_phone_number     IN VARCHAR2,
			 p_mobile_phone     IN VARCHAR2,
			 p_email            IN VARCHAR2,
			 p_ovn              IN NUMBER,
			 p_contact_point_id IN NUMBER,
			 p_err_code         OUT VARCHAR2,
			 p_err_msg          OUT VARCHAR2) IS
  
    -- Contact points
    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_email_rec         hz_contact_point_v2pub.email_rec_type;
    l_phone_rec         hz_contact_point_v2pub.phone_rec_type;
    l_return_status     VARCHAR2(2000) := NULL;
    l_msg_count         NUMBER := NULL;
    l_msg_data          VARCHAR2(2000) := NULL;
    l_ovn               NUMBER := NULL;
    l_data              VARCHAR2(2500) := NULL;
    l_msg_index_out     NUMBER;
  BEGIN
    fnd_msg_pub.initialize;
    p_err_code := 0;
    p_err_msg  := NULL;
    l_ovn      := p_ovn;
  
    -- each point type have different variable that creates the point
    -- l_contact_point_rec.owner_table_id => l_party_rel_id  is
    -- the party_id from hz_parties that is from type PARTY_RELATIONSHIP (CONT_REL_PARTY_ID)
    l_contact_point_rec.owner_table_name := 'HZ_PARTIES';
    l_contact_point_rec.owner_table_id   := p_party_id; --'5151403';
    l_contact_point_rec.primary_flag     := 'Y';
    l_contact_point_rec.contact_point_id := p_contact_point_id;
    IF p_phone_number IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Phone
      l_phone_rec.phone_number               := p_phone_number;
      l_phone_rec.phone_line_type            := 'GEN';
    
      -- phone and mobile phone
      hz_contact_point_v2pub.update_phone_contact_point(p_init_msg_list         => fnd_api.g_true, -- i v 'T',
				        p_contact_point_rec     => l_contact_point_rec,
				        p_phone_rec             => l_phone_rec,
				        p_object_version_number => l_ovn,
				        x_return_status         => l_return_status, -- o v
				        x_msg_count             => l_msg_count, -- o n
				        x_msg_data              => l_msg_data); -- o v
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        p_err_msg := 'Failed update phone contact: ' || p_contact_point_id ||
	         ' - ';
        dbms_output.put_line('Failed update phone contact: ' ||
		     p_contact_point_id);
        dbms_output.put_line('l_msg_data = ' ||
		     substr(l_msg_data, 1, 2000));
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        
          p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
        END LOOP;
        p_err_code := 1;
        ROLLBACK;
      ELSE
        COMMIT;
        p_err_code := 0;
        p_err_msg  := 'Success update phone contact: ' ||
	          p_contact_point_id;
      END IF; -- Status if
    END IF;
  
    IF p_mobile_phone IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Phone
      l_phone_rec.phone_number               := p_mobile_phone;
      l_phone_rec.phone_line_type            := 'MOBILE';
    
      -- phone and mobile phone
      hz_contact_point_v2pub.update_phone_contact_point(p_init_msg_list         => fnd_api.g_true, -- i v 'T',
				        p_contact_point_rec     => l_contact_point_rec,
				        p_phone_rec             => l_phone_rec,
				        p_object_version_number => l_ovn,
				        x_return_status         => l_return_status, -- o v
				        x_msg_count             => l_msg_count, -- o n
				        x_msg_data              => l_msg_data); -- o v
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        IF p_err_msg IS NULL THEN
          p_err_msg := 'Failed update mobile contact: ' ||
	           p_contact_point_id || ' - ';
        ELSE
          p_err_msg := p_err_msg || chr(10) ||
	           'Failed update mobile contact: ' ||
	           p_contact_point_id || ' - ';
        END IF;
        dbms_output.put_line('Failed update mobile contact: ' ||
		     p_contact_point_id);
        dbms_output.put_line('l_msg_data = ' ||
		     substr(l_msg_data, 1, 2000));
      
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        
          p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
        END LOOP;
      
        p_err_code := 1;
        ROLLBACK;
      ELSE
        COMMIT;
        p_err_code := 0;
        IF p_err_msg IS NULL THEN
          p_err_msg := 'Success update mobile contact: ' ||
	           p_contact_point_id;
        ELSE
          p_err_msg := p_err_msg || chr(10) ||
	           'Success update mobile contact: ' ||
	           p_contact_point_id;
        END IF;
      END IF; -- Status if
    END IF;
  
    IF p_email IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'EMAIL';
      l_email_rec.email_format               := 'MAILTEXT';
      l_email_rec.email_address              := p_email;
    
      hz_contact_point_v2pub.update_email_contact_point(p_init_msg_list         => fnd_api.g_true, -- i v 'T',
				        p_contact_point_rec     => l_contact_point_rec,
				        p_email_rec             => l_email_rec,
				        p_object_version_number => l_ovn,
				        x_return_status         => l_return_status, -- o v
				        x_msg_count             => l_msg_count, -- o n
				        x_msg_data              => l_msg_data); -- o v
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        IF p_err_msg IS NULL THEN
          p_err_msg := 'Failed update Email contact: ' ||
	           p_contact_point_id || ' - ';
        ELSE
          p_err_msg := p_err_msg || chr(10) ||
	           'Failed update Email contact: ' ||
	           p_contact_point_id || ' - ';
        END IF;
      
        dbms_output.put_line('Failed update Email contact: ' ||
		     p_contact_point_id);
        dbms_output.put_line('l_msg_data = ' ||
		     substr(l_msg_data, 1, 2000));
      
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        
          p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
        END LOOP;
      
        p_err_code := 1;
        ROLLBACK;
      ELSE
        COMMIT;
        p_err_code := 0;
        IF p_err_msg IS NULL THEN
          p_err_msg := 'Success update Email contact: ' ||
	           p_contact_point_id;
        ELSE
          p_err_msg := p_err_msg || chr(10) ||
	           'Success update Email contact: ' ||
	           p_contact_point_id;
        END IF;
      END IF; -- Status if
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - update_contact_point_api - p_party_id - ' ||
	        p_party_id || ' - ' || ' p_contact_point_id - ' ||
	        p_contact_point_id || ' - ' || substr(SQLERRM, 1, 240);
  END update_contact_point_api;

  --------------------------------------------------------------------
  --  name:            create_contact_point_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create create_contact_point API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_contact_point_api(p_party_id         IN NUMBER,
			 p_phone_number     IN VARCHAR2,
			 p_mobile_phone     IN VARCHAR2,
			 p_email            IN VARCHAR2,
			 p_fax              IN VARCHAR2,
			 p_contact_point_id OUT NUMBER,
			 p_err_code         OUT VARCHAR2,
			 p_err_msg          OUT VARCHAR2) IS
  
    -- Contact points
    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_email_rec         hz_contact_point_v2pub.email_rec_type;
    l_phone_rec         hz_contact_point_v2pub.phone_rec_type;
    l_contact_point_id  NUMBER := NULL;
    l_return_status     VARCHAR2(2000) := NULL;
    l_msg_count         NUMBER := NULL;
    l_msg_data          VARCHAR2(2000) := NULL;
    l_data              VARCHAR2(2500) := NULL;
    l_msg_index_out     NUMBER;
  
  BEGIN
    fnd_msg_pub.initialize;
    p_err_code := 0;
    p_err_msg  := NULL;
  
    -- each point type have different variable that creates the point
    -- l_contact_point_rec.owner_table_id => l_party_rel_id  is
    -- the party_id from hz_parties that is from type PARTY_RELATIONSHIP (CONT_REL_PARTY_ID)
    l_contact_point_rec.owner_table_name  := 'HZ_PARTIES';
    l_contact_point_rec.owner_table_id    := p_party_id; --'5151403';
    l_contact_point_rec.created_by_module := g_create_by_module; --'SALESFORCE';
    IF p_phone_number IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Phone
      l_phone_rec.phone_number               := p_phone_number;
      l_phone_rec.phone_line_type            := 'GEN';
      l_contact_point_rec.primary_flag       := 'Y';
    
      hz_contact_point_v2pub.create_phone_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T',
				        p_contact_point_rec => l_contact_point_rec,
				        p_phone_rec         => l_phone_rec,
				        x_contact_point_id  => l_contact_point_id, -- o n
				        x_return_status     => l_return_status, -- o v
				        x_msg_count         => l_msg_count, -- o n
				        x_msg_data          => l_msg_data); -- o v
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        p_err_msg := p_err_msg || ' Failed phone number: ' ||
	         p_phone_number || chr(10);
        dbms_output.put_line('x_msg_data = ' || l_msg_data);
        IF l_msg_count > 1 THEN
          FOR i IN 1 .. l_msg_count LOOP
	fnd_msg_pub.get(p_msg_index     => i,
		    p_data          => l_data,
		    p_encoded       => fnd_api.g_false,
		    p_msg_index_out => l_msg_index_out);
	dbms_output.put_line('l_data - ' || substr(l_data, 1, 240));
          END LOOP;
        END IF;
        ROLLBACK;
        IF p_err_code = 0 THEN
          p_err_code := 1;
        END IF;
      ELSE
        COMMIT;
        --p_err_code := '0';
        p_err_msg := p_err_msg || ' Success phone number: ' ||
	         p_phone_number || ' - ' || l_contact_point_id ||
	         chr(10);
      END IF; --l_return_status
    END IF; -- phon number
  
    IF p_mobile_phone IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Phone
      l_phone_rec.phone_number               := p_mobile_phone;
      l_phone_rec.phone_line_type            := 'MOBILE';
      l_contact_point_rec.primary_flag       := 'N';
      hz_contact_point_v2pub.create_phone_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T',
				        p_contact_point_rec => l_contact_point_rec,
				        p_phone_rec         => l_phone_rec,
				        x_contact_point_id  => l_contact_point_id, -- o n
				        x_return_status     => l_return_status, -- o v
				        x_msg_count         => l_msg_count, -- o n
				        x_msg_data          => l_msg_data); -- o v
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        p_err_msg := p_err_msg || ' Failed Mobile number: ' ||
	         p_mobile_phone || chr(10);
        dbms_output.put_line('x_msg_data = ' || l_msg_data);
        IF l_msg_count > 1 THEN
          FOR i IN 1 .. l_msg_count LOOP
	fnd_msg_pub.get(p_msg_index     => i,
		    p_data          => l_data,
		    p_encoded       => fnd_api.g_false,
		    p_msg_index_out => l_msg_index_out);
	dbms_output.put_line('l_data - ' || substr(l_data, 1, 240));
          END LOOP;
        END IF;
        dbms_output.put_line('l_msg_data - ' || p_err_msg);
        ROLLBACK;
        IF p_err_code = 0 THEN
          p_err_code := 1;
        END IF;
      ELSE
        COMMIT;
        --p_err_code := '0';
        p_err_msg := p_err_msg || ' Success mobile number: ' ||
	         p_mobile_phone || ' - ' || l_contact_point_id ||
	         chr(10); -- i/o v
      
      END IF; --l_return_status
    END IF;
  
    IF p_fax IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Phone
      l_phone_rec.phone_number               := p_fax;
      l_phone_rec.phone_line_type            := 'FAX';
      l_contact_point_rec.primary_flag       := 'N';
      hz_contact_point_v2pub.create_phone_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T',
				        p_contact_point_rec => l_contact_point_rec,
				        p_phone_rec         => l_phone_rec,
				        x_contact_point_id  => l_contact_point_id, -- o n
				        x_return_status     => l_return_status, -- o v
				        x_msg_count         => l_msg_count, -- o n
				        x_msg_data          => l_msg_data); -- o v
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        p_err_msg := p_err_msg || ' Failed Fax number: ' || p_mobile_phone ||
	         chr(10);
        dbms_output.put_line('x_msg_data = ' || l_msg_data);
        IF l_msg_count > 1 THEN
          FOR i IN 1 .. l_msg_count LOOP
	fnd_msg_pub.get(p_msg_index     => i,
		    p_data          => l_data,
		    p_encoded       => fnd_api.g_false,
		    p_msg_index_out => l_msg_index_out);
	dbms_output.put_line('l_data - ' || substr(l_data, 1, 240));
          END LOOP;
        END IF;
        dbms_output.put_line('l_msg_data - ' || p_err_msg);
        ROLLBACK;
        IF p_err_code = 0 THEN
          p_err_code := 1;
        END IF;
      ELSE
        COMMIT;
        --p_err_code := '0';
        p_err_msg := p_err_msg || ' Success Fax number: ' || p_mobile_phone ||
	         ' - ' || l_contact_point_id || chr(10); -- i/o v
      
      END IF; --l_return_status
    END IF;
  
    IF p_email IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'EMAIL';
      l_email_rec.email_format               := 'MAILTEXT';
      l_email_rec.email_address              := p_email;
      l_contact_point_rec.primary_flag       := 'Y';
    
      hz_contact_point_v2pub.create_email_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T',
				        p_contact_point_rec => l_contact_point_rec,
				        p_email_rec         => l_email_rec,
				        x_contact_point_id  => l_contact_point_id, -- o n
				        x_return_status     => l_return_status, -- o v
				        x_msg_count         => l_msg_count, -- o n
				        x_msg_data          => l_msg_data); -- o v
    
      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        p_err_msg := p_err_msg || ' Failed Email - ' || p_email || chr(10);
        dbms_output.put_line('x_msg_data = ' || l_msg_data);
        IF l_msg_count > 1 THEN
          FOR i IN 1 .. l_msg_count LOOP
	fnd_msg_pub.get(p_msg_index     => i,
		    p_data          => l_data,
		    p_encoded       => fnd_api.g_false,
		    p_msg_index_out => l_msg_index_out);
	dbms_output.put_line('l_data - ' || substr(l_data, 1, 240));
          END LOOP;
        END IF;
        ROLLBACK;
        IF p_err_code = 0 THEN
          p_err_code := 1;
        END IF;
      ELSE
        COMMIT;
        --p_err_code := '0';
        p_err_msg := p_err_msg || ' Success Email - ' || p_email || ' - ' ||
	         l_contact_point_id || chr(10); -- i/o v
      END IF; --l_return_status
    END IF; -- email
    p_contact_point_id := l_contact_point_id;
  
  END create_contact_point_api;

  --------------------------------------------------------------------
  --  name:            create_cust_account_role_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that create cust account role
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_cust_account_role_api(p_contact_party        IN NUMBER,
			     p_cust_account_id      IN NUMBER,
			     p_sf_id                IN VARCHAR2,
			     p_cust_account_role_id OUT NUMBER,
			     p_err_code             OUT VARCHAR2,
			     p_err_msg              OUT VARCHAR2) IS
  
    l_success              VARCHAR2(1) := 'T';
    x_cust_account_role_id NUMBER(10);
    l_return_status        VARCHAR2(2000);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(2000);
    l_msg_index_out        NUMBER;
    l_data                 VARCHAR2(2000);
    l_cr_cust_acc_role_rec hz_cust_account_role_v2pub.cust_account_role_rec_type;
  
  BEGIN
    p_err_msg  := 0;
    p_err_code := NULL;
  
    l_cr_cust_acc_role_rec.party_id          := p_contact_party;
    l_cr_cust_acc_role_rec.cust_account_id   := p_cust_account_id;
    l_cr_cust_acc_role_rec.primary_flag      := 'N';
    l_cr_cust_acc_role_rec.role_type         := 'CONTACT';
    l_cr_cust_acc_role_rec.created_by_module := g_create_by_module; --'SALESFORCE';
    l_cr_cust_acc_role_rec.attribute1        := p_sf_id;
  
    fnd_msg_pub.initialize;
    hz_cust_account_role_v2pub.create_cust_account_role(l_success,
				        l_cr_cust_acc_role_rec,
				        x_cust_account_role_id,
				        l_return_status,
				        l_msg_count,
				        l_msg_data);
  
    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Error create cust account role: ';
      dbms_output.put_line('Failed create cust account role ');
      dbms_output.put_line('l_msg_data = ' || substr(l_msg_data, 1, 2000));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        dbms_output.put_line('l_Data - ' || l_data);
        p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
      END LOOP;
      p_err_code := 1;
      ROLLBACK;
    
    ELSE
      --commit;
      p_cust_account_role_id := x_cust_account_role_id;
      p_err_code             := 0;
      p_err_msg              := 'Success create cust account role: ' ||
		        x_cust_account_role_id;
    END IF; -- status if
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - create_cust_account_role_api - ' ||
	        substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - create_cust_account_role_api - ' ||
		   substr(SQLERRM, 1, 240));
    
  END create_cust_account_role_api;

  --------------------------------------------------------------------
  --  name:            create_party_site_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create party site API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_party_site_api(p_location_id     IN NUMBER,
		          p_cust_account_id IN NUMBER,
		          p_country         IN VARCHAR2,
		          p_party_id        IN NUMBER,
		          p_party_site_id   OUT NUMBER,
		          p_err_code        OUT VARCHAR2,
		          p_err_msg         OUT VARCHAR2) IS
  
    t_party_site_rec    hz_party_site_v2pub.party_site_rec_type;
    l_party_id          NUMBER := NULL;
    l_party_site_number NUMBER := NULL;
    l_party_site_id     NUMBER := NULL;
    l_return_status     VARCHAR2(1);
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(2500);
    l_data              VARCHAR2(2000);
    l_msg_index_out     NUMBER;
  
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
    --------------------------
    --  Get party id        --
    --------------------------
    IF p_party_id IS NULL THEN
      SELECT hca.party_id
      INTO   l_party_id
      FROM   hz_cust_accounts hca
      WHERE  hca.cust_account_id = p_cust_account_id;
    ELSE
      l_party_id := p_party_id;
    END IF;
    fnd_msg_pub.initialize;
  
    t_party_site_rec.party_id    := l_party_id;
    t_party_site_rec.location_id := p_location_id;
    --t_party_site_rec.identifying_address_flag := 'Y';
    t_party_site_rec.created_by_module := g_create_by_module; --'SALESFORCE';
    t_party_site_rec.party_site_name   := p_country; -- p_site_name;  ????????????????
  
    hz_party_site_v2pub.create_party_site(p_init_msg_list     => 'T',
			      p_party_site_rec    => t_party_site_rec,
			      x_party_site_id     => l_party_site_id,
			      x_party_site_number => l_party_site_number,
			      x_return_status     => l_return_status,
			      x_msg_count         => l_msg_count,
			      x_msg_data          => l_msg_data);
  
    IF l_return_status <> fnd_api.g_ret_sts_success THEN
    
      p_err_msg := 'Error create party site: ';
      dbms_output.put_line('Failed create Party Site: ');
      dbms_output.put_line('l_Msg_Data = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        dbms_output.put_line('l_Data - ' || l_data);
        p_err_msg := p_err_msg || l_data || chr(10);
      END LOOP;
      p_party_site_id := -99;
      p_err_code      := 1;
      ROLLBACK;
    
    ELSE
      --commit;
      p_party_site_id := l_party_site_id;
      p_err_msg       := 'Success create party site: ' || l_party_site_id;
      p_err_code      := 0;
    END IF; --  party Status
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - create_party_site_api - ' ||
	        substr(SQLERRM, 1, 240);
  END create_party_site_api;

  --------------------------------------------------------------------
  --  name:            create_person_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_org_contact_api(p_subject_id       IN NUMBER,
		           p_subject_type     IN VARCHAR2,
		           p_object_id        IN NUMBER,
		           p_object_type      IN VARCHAR2,
		           p_relation_code    IN VARCHAR2,
		           p_relation_type    IN VARCHAR2,
		           p_object_tble_name IN VARCHAR2,
		           p_title            IN VARCHAR2,
		           --p_oracle_event_id  in number,
		           p_contact_party OUT NUMBER,
		           p_party_number  OUT NUMBER,
		           p_err_code      OUT VARCHAR2,
		           p_err_msg       OUT VARCHAR2) IS
  
    l_success         VARCHAR2(1) := 'T';
    p_org_contact_rec hz_party_contact_v2pub.org_contact_rec_type;
    l_return_status   VARCHAR2(2000);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(2000);
    x_party_rel_id    NUMBER;
    x_party_id        NUMBER;
    x_party_number    VARCHAR2(2000);
    x_org_contact_id  NUMBER;
    l_msg_index_out   NUMBER;
    l_data            VARCHAR2(2000);
    l_sf_title        VARCHAR2(150) := NULL;
  
  BEGIN
  
    p_err_msg        := 0;
    p_err_code       := NULL;
    l_return_status  := NULL;
    l_msg_count      := NULL;
    l_msg_data       := NULL;
    x_org_contact_id := NULL;
    x_party_id       := NULL;
    x_party_number   := NULL;
  
    fnd_msg_pub.initialize;
  
    IF p_title IS NOT NULL THEN
      BEGIN
        SELECT flv.lookup_code
        INTO   l_sf_title
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = 'RESPONSIBILITY'
        AND    flv.language = 'US'
        AND    flv.enabled_flag = 'Y'
        AND    nvl(flv.end_date_active, SYSDATE + 1) > SYSDATE
        AND    upper(flv.meaning) = upper(p_title);
      
        p_org_contact_rec.job_title_code := l_sf_title; --p_title;
        p_org_contact_rec.job_title      := p_title; --p_title;
      EXCEPTION
        WHEN OTHERS THEN
          p_err_code := 1;
          p_err_msg  := 'create_org_contact_api - Invalid Title :' ||
		p_title;
          dbms_output.put_line('create_org_contact_api - Invalid Title :' ||
		       p_title);
      END;
    END IF; -- p_title
  
    p_org_contact_rec.created_by_module := g_create_by_module; --'SALESFORCE';
  
    p_org_contact_rec.party_rel_rec.subject_id         := p_subject_id;
    p_org_contact_rec.party_rel_rec.subject_type       := p_subject_type;
    p_org_contact_rec.party_rel_rec.subject_table_name := 'HZ_PARTIES';
    p_org_contact_rec.party_rel_rec.object_id          := p_object_id;
    p_org_contact_rec.party_rel_rec.object_type        := p_object_type;
    p_org_contact_rec.party_rel_rec.object_table_name  := p_object_tble_name;
    p_org_contact_rec.party_rel_rec.relationship_code  := p_relation_code;
    p_org_contact_rec.party_rel_rec.relationship_type  := p_relation_type;
    p_org_contact_rec.party_rel_rec.start_date         := SYSDATE;
    p_org_contact_rec.party_rel_rec.status             := 'A';
  
    hz_party_contact_v2pub.create_org_contact(l_success,
			          p_org_contact_rec,
			          x_org_contact_id,
			          x_party_rel_id,
			          x_party_id,
			          x_party_number,
			          l_return_status,
			          l_msg_count,
			          l_msg_data);
  
    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Error create org contact: ';
      dbms_output.put_line('Creation of org contact Failed -');
      dbms_output.put_line('l_msg_data = ' || substr(l_msg_data, 1, 2000));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        dbms_output.put_line('l_Data - ' || substr(l_data, 1, 240));
        p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
      END LOOP;
      p_err_code := 1;
      ROLLBACK;
    
    ELSE
      --commit;
      p_contact_party := x_party_id;
      p_party_number  := x_party_number;
      p_err_code      := 0;
      p_err_msg       := 'Success create org contact: ' || x_party_id;
    END IF; -- status if
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - create_org_contact_api - ' ||
	        substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - create_org_contact_api - ' ||
		   substr(SQLERRM, 1, 240));
    
  END create_org_contact_api;

  --------------------------------------------------------------------
  --  name:            create_location_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create location API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_location_api(p_country       IN VARCHAR2,
		        p_address_line1 IN VARCHAR2,
		        p_city          IN VARCHAR2,
		        p_postal_code   IN VARCHAR2,
		        p_state         IN VARCHAR2,
		        p_county        IN VARCHAR2,
		        --p_oracle_event_id in number,
		        --p_entity          in varchar2 default 'INSERT',
		        p_location_id OUT NUMBER,
		        p_err_code    OUT VARCHAR2,
		        p_err_msg     OUT VARCHAR2) IS
  
    l_territory_code VARCHAR2(2) := NULL;
    l_state          VARCHAR2(10) := NULL;
    t_location_rec   hz_location_v2pub.location_rec_type;
    l_location_id    NUMBER;
    l_return_status  VARCHAR2(1);
    l_msg_count      NUMBER;
    l_msg_data       VARCHAR2(2500);
    l_data           VARCHAR2(2000);
    l_msg_index_out  NUMBER;
  
    general_exception EXCEPTION;
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
    IF p_country IS NOT NULL THEN
      BEGIN
        SELECT territory_code
        INTO   l_territory_code
        FROM   fnd_territories_vl t
        WHERE  upper(territory_short_name) = upper(p_country);
      EXCEPTION
        WHEN OTHERS THEN
          p_err_code := 1;
          p_err_msg  := 'create_location_api - Invalid territory :' ||
		p_country;
          RAISE general_exception;
      END;
    ELSE
      l_territory_code := NULL;
    END IF;
  
    IF p_state IS NOT NULL THEN
      BEGIN
        SELECT lookup_code
        INTO   l_state
        FROM   fnd_common_lookups
        WHERE  lookup_type = 'US_STATE'
        AND    upper(meaning) = upper(p_state);
      
      EXCEPTION
        WHEN OTHERS THEN
          p_err_code := 1;
          p_err_msg  := 'create_location_api - Invalid state :' || p_state;
          RAISE general_exception;
      END;
    ELSE
      l_state := NULL;
    END IF;
  
    fnd_msg_pub.initialize;
    t_location_rec.country           := l_territory_code;
    t_location_rec.address1          := p_address_line1;
    t_location_rec.city              := p_city;
    t_location_rec.postal_code       := p_postal_code;
    t_location_rec.state             := l_state; --p_state;
    t_location_rec.county            := p_county;
    t_location_rec.created_by_module := g_create_by_module; --'SALESFORCE';
  
    hz_location_v2pub.create_location(p_init_msg_list => 'T',
			  p_location_rec  => t_location_rec,
			  x_location_id   => l_location_id,
			  x_return_status => l_return_status,
			  x_msg_count     => l_msg_count,
			  x_msg_data      => l_msg_data);
  
    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Failed create location: ';
    
      dbms_output.put_line('Failed create location:');
      dbms_output.put_line('l_msg_data = ' || substr(l_msg_data, 1, 240));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        dbms_output.put_line('l_data = ' || substr(l_data, 1, 240));
        p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
      END LOOP;
      p_err_code := 1;
      ROLLBACK;
    
    ELSE
      --commit;
      p_location_id := l_location_id;
      p_err_code    := 0;
      p_err_msg     := 'Success create location: ' || l_location_id;
    END IF; -- Status if
    p_location_id := l_location_id;
  EXCEPTION
    WHEN general_exception THEN
      NULL;
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - create_location_api - ' ||
	        substr(SQLERRM, 1, 240);
  END create_location_api;

  --------------------------------------------------------------------
  --  name:            create_person_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create Person API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_person_api(p_first_name      IN VARCHAR2,
		      p_last_name       IN VARCHAR2,
		      p_prefix          IN VARCHAR2,
		      p_person_party_id OUT NUMBER,
		      p_err_code        OUT VARCHAR2,
		      p_err_msg         OUT VARCHAR2) IS
  
    l_upd_person    hz_party_v2pub.person_rec_type;
    l_success       VARCHAR2(1) := 'T';
    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    x_party_id      NUMBER;
    x_party_number  VARCHAR2(2000);
    x_profile_id    NUMBER;
  
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
  
    fnd_msg_pub.initialize;
  
    -- Create contact as person. If OK Continue to RelationShip
    l_upd_person.person_first_name := p_first_name;
    l_upd_person.person_last_name  := p_last_name;
    l_upd_person.created_by_module := g_create_by_module; -- SALESFORCE
    l_upd_person.party_rec.status  := 'A';
    IF p_prefix IS NOT NULL THEN
      l_upd_person.person_pre_name_adjunct := p_prefix;
    END IF;
    hz_party_v2pub.create_person(l_success,
		         l_upd_person,
		         x_party_id,
		         x_party_number,
		         x_profile_id,
		         l_return_status,
		         l_msg_count,
		         l_msg_data);
  
    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Failed create Contact - ' ||
	       substr(l_msg_data, 1, 1000);
      dbms_output.put_line('Failed create Contact:');
      dbms_output.put_line('l_msg_data = ' || substr(l_msg_data, 1, 240));
    
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        dbms_output.put_line('l_data = ' || substr(l_data, 1, 240));
      END LOOP;
      p_err_code := 1;
      ROLLBACK;
    ELSE
      --commit;
      p_person_party_id := x_party_id;
      p_err_code        := 0;
      p_err_msg         := 'Success create Contact - person party -' ||
		   x_party_id;
    END IF; -- Status if
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - create_person_api - ' ||
	        substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - create_person_api - ' ||
		   substr(SQLERRM, 1, 240));
  END create_person_api;

  --------------------------------------------------------------------
  --  name:            create_sf_contact
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/10/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  20/10/2010  Dalit A. Raviv   initial build
  --  1.1  08/12/2010  Dalit A. Raviv   change to upload contact not from SalesForce
  --                                    alter temp table with new column, cust_account_id
  --------------------------------------------------------------------
  PROCEDURE create_sf_contact(errbuf  OUT VARCHAR2,
		      retcode OUT VARCHAR2) IS
  
    CURSOR get_pop_c IS
      SELECT *
      FROM   xxobjt_conv_hz_contacts c
      WHERE  c.status = 'NEW'
      AND    c.run_code IS NULL;
    --and    rownum < 10;  -- for debug
  
    l_org_id               NUMBER := NULL;
    l_party_id             NUMBER := NULL;
    l_cust_account_id      NUMBER := NULL;
    l_person_party_id      NUMBER := NULL;
    l_location_id          NUMBER := NULL;
    l_contact_party_id     NUMBER := NULL;
    l_party_number         NUMBER := NULL;
    l_party_site_id        NUMBER := NULL;
    l_cust_account_role_id NUMBER := NULL;
    l_contact_point_id     NUMBER := NULL;
    l_prefix               VARCHAR2(10) := NULL;
    l_err_code             VARCHAR2(5) := 0;
    l_err_msg              VARCHAR2(2500) := NULL;
  
    general_exception EXCEPTION;
  BEGIN
  
    errbuf  := 'SUCCESS';
    retcode := 0;
  
    SELECT user_id
    INTO   g_user_id
    FROM   fnd_user
    WHERE  user_name = 'SALESFORCE';
  
    FOR get_pop_r IN get_pop_c LOOP
      dbms_output.put_line('----------------------');
      dbms_output.put_line('Entity id ' || get_pop_r.entity_id);
      BEGIN
        l_org_id          := NULL;
        l_party_id        := NULL;
        l_cust_account_id := NULL;
        l_err_code        := 0;
        l_err_msg         := NULL;
        l_person_party_id := NULL;
        l_prefix          := NULL;
        -- Get cust_account , party and org id
        -- 1.1  08/12/2010  Dalit A. Raviv
        -- if there is no value at sf_account_id i do have the cust_account_id at the file to upload
        IF get_pop_r.sf_account_id IS NOT NULL THEN
          BEGIN
	SELECT hp.attribute3,
	       hp.party_id,
	       hca.cust_account_id
	INTO   l_org_id,
	       l_party_id,
	       l_cust_account_id
	FROM   hz_cust_accounts hca,
	       hz_parties       hp
	WHERE  hca.party_id = hp.party_id
	AND    hca.attribute4 = get_pop_r.sf_account_id;
          EXCEPTION
	WHEN OTHERS THEN
	  l_org_id := NULL;
          END;
          -- 1.1  08/12/2010  Dalit A. Raviv
        ELSE
          BEGIN
	SELECT hp.attribute3,
	       hp.party_id,
	       hca.cust_account_id
	INTO   l_org_id,
	       l_party_id,
	       l_cust_account_id
	FROM   hz_cust_accounts hca,
	       hz_parties       hp
	WHERE  hca.party_id = hp.party_id
	AND    hca.cust_account_id = get_pop_r.cust_account_id;
          EXCEPTION
	WHEN OTHERS THEN
	  l_org_id := NULL;
          END;
        END IF;
        IF l_org_id IS NOT NULL THEN
          IF nvl(g_org_id, 1) <> l_org_id THEN
	g_org_id := l_org_id;
          
	mo_global.set_org_access(p_org_id_char     => l_org_id,
			 p_sp_id_char      => NULL,
			 p_appl_short_name => 'AR');
          END IF;
        
          BEGIN
	SELECT lookup_code
	INTO   l_prefix
	FROM   ar_lookups al
	WHERE  al.lookup_type = 'CONTACT_TITLE'
	AND    al.meaning = get_pop_r.prefix;
          
          EXCEPTION
	WHEN OTHERS THEN
	  l_prefix := NULL;
          END;
        
          -- create person
          create_person_api(p_first_name      => get_pop_r.first_name, -- i v
		    p_last_name       => get_pop_r.last_name, -- i v
		    p_prefix          => l_prefix, -- i v
		    p_person_party_id => l_person_party_id, -- o n
		    p_err_code        => l_err_code, -- o v
		    p_err_msg         => l_err_msg); -- o v
        
          IF l_err_code = 1 THEN
	upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		 p_status     => 'WARNING', -- i   v
		 p_error_code => l_err_code, -- i/o v
		 p_error_msg  => l_err_msg); -- i/o v
	RAISE general_exception;
          ELSE
	dbms_output.put_line('Pperson party id - ' ||
		         l_person_party_id);
	upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		 p_status     => 'SUCCESS', -- i   v
		 p_error_code => l_err_code, -- i/o v
		 p_error_msg  => l_err_msg); -- i/o v
          END IF; -- api person
        
          -- create location
          l_err_code    := 0;
          l_err_msg     := NULL;
          l_location_id := NULL;
          -- If success to create person
          -- Create location for the person
          IF get_pop_r.address_line1 IS NOT NULL AND
	 get_pop_r.country IS NOT NULL THEN
          
	create_location_api(p_country       => get_pop_r.country, -- i v
		        p_address_line1 => get_pop_r.address_line1, -- i v
		        p_city          => get_pop_r.city, -- i v
		        p_postal_code   => get_pop_r.postal_code, -- i v
		        p_state         => get_pop_r.state, -- i v
		        p_county        => NULL, -- i v
		        p_location_id   => l_location_id, -- o n
		        p_err_code      => l_err_code, -- o v
		        p_err_msg       => l_err_msg); -- o v
	IF l_err_code = 1 THEN
	  upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		   p_status     => 'WARNING', -- i   v
		   p_error_code => l_err_code, -- i/o v
		   p_error_msg  => l_err_msg); -- i/o v
	  RAISE general_exception;
	ELSE
	  dbms_output.put_line('Create location - Location id - ' ||
		           l_location_id);
	  upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		   p_status     => 'SUCCESS', -- i   v
		   p_error_code => l_err_code, -- i/o v
		   p_error_msg  => l_err_msg); -- i/o v
	END IF; -- api location
          END IF; -- location
        
          l_err_code         := 0;
          l_err_msg          := NULL;
          l_contact_party_id := NULL;
          l_party_number     := NULL;
          -- create org_contact conect the person to party
          create_org_contact_api(p_subject_id       => l_person_party_id, -- i n (party id that just created)
		         p_subject_type     => 'PERSON', -- i v
		         p_object_id        => l_party_id, -- i n (account party id)
		         p_object_type      => 'ORGANIZATION', -- i v
		         p_relation_code    => 'CONTACT_OF', -- i v
		         p_relation_type    => 'CONTACT', -- i v
		         p_object_tble_name => 'HZ_PARTIES', -- i v
		         p_title            => get_pop_r.title, -- i v
		         p_contact_party    => l_contact_party_id, -- o n
		         p_party_number     => l_party_number, -- o n
		         p_err_code         => l_err_code, -- o v
		         p_err_msg          => l_err_msg); -- o v
        
          IF l_err_code = 1 THEN
	upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		 p_status     => 'WARNING', -- i   v
		 p_error_code => l_err_code, -- i/o v
		 p_error_msg  => l_err_msg); -- i/o v
	RAISE general_exception;
          ELSE
	dbms_output.put_line('Create org contact - Contact party id - ' ||
		         l_contact_party_id);
	upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		 p_status     => 'SUCCESS', -- i   v
		 p_error_code => l_err_code, -- i/o v
		 p_error_msg  => l_err_msg); -- i/o v
          END IF; -- api org_contact
        
          l_err_code      := 0;
          l_err_msg       := NULL;
          l_party_site_id := NULL;
          IF get_pop_r.address_line1 IS NOT NULL AND
	 get_pop_r.country IS NOT NULL THEN
	create_party_site_api(p_location_id     => l_location_id, -- i n
		          p_cust_account_id => l_cust_account_id, -- i n
		          p_country         => get_pop_r.country, -- i v
		          p_party_id        => l_contact_party_id, -- i v
		          p_party_site_id   => l_party_site_id, -- o n
		          p_err_code        => l_err_code, -- o v
		          p_err_msg         => l_err_msg); -- o v
          
	IF l_err_code = 1 THEN
	  upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		   p_status     => 'WARNING', -- i   v
		   p_error_code => l_err_code, -- i/o v
		   p_error_msg  => l_err_msg); -- i/o v
	  RAISE general_exception;
	ELSE
	  dbms_output.put_line('Create party site - party site id - ' ||
		           l_party_site_id);
	  upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		   p_status     => 'SUCCESS', -- i   v
		   p_error_code => l_err_code, -- i/o v
		   p_error_msg  => l_err_msg); -- i/o v
	END IF; -- api party site
          END IF; -- party site
        
          l_err_code             := 0;
          l_err_msg              := NULL;
          l_cust_account_role_id := NULL;
          -- create cust_account role
          create_cust_account_role_api(p_contact_party        => l_contact_party_id, -- i n
			   p_cust_account_id      => l_cust_account_id, -- i n
			   p_sf_id                => get_pop_r.sf_contact_id, -- i v
			   p_cust_account_role_id => l_cust_account_role_id, -- o n
			   p_err_code             => l_err_code, -- o v
			   p_err_msg              => l_err_msg); -- o v
          IF l_err_code = 1 THEN
	upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		 p_status     => 'ERROR', -- i   v
		 p_error_code => l_err_code, -- i/o v
		 p_error_msg  => l_err_msg); -- i/o v
	RAISE general_exception;
          ELSE
	dbms_output.put_line('Create cust account role - Cust account role id - ' ||
		         l_cust_account_role_id);
	COMMIT; -- commit for all API's
	upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		 p_status     => 'SUCCESS', -- i   v
		 p_error_code => l_err_code, -- i/o v
		 p_error_msg  => l_err_msg); -- i/o v
          END IF; -- api role
          -- create contact phone number
          l_err_code         := 0;
          l_err_msg          := NULL;
          l_contact_point_id := NULL;
        
          IF get_pop_r.phone_number IS NOT NULL OR
	 get_pop_r.mobile_phone IS NOT NULL OR
	 get_pop_r.email IS NOT NULL THEN
          
	create_contact_point_api(p_party_id         => l_contact_party_id, -- i n
			 p_phone_number     => get_pop_r.phone_number, -- i v
			 p_mobile_phone     => get_pop_r.mobile_phone, -- i v
			 p_email            => get_pop_r.email, -- i v
			 p_fax              => get_pop_r.fax, -- i v
			 p_contact_point_id => l_contact_point_id, -- o n
			 p_err_code         => l_err_code, -- o v
			 p_err_msg          => l_err_msg); -- o v
          
	IF l_err_code = 1 THEN
	  upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		   p_status     => 'WARNING', -- i   v
		   p_error_code => l_err_code, -- i/o v
		   p_error_msg  => l_err_msg); -- i/o v
	ELSE
	  upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		   p_status     => 'SUCCESS', -- i   v
		   p_error_code => l_err_code, -- i/o v
		   p_error_msg  => l_err_msg); -- i/o v
	END IF; -- api
          END IF; -- contact point
        ELSE
          -- update interface line with error
          dbms_output.put_line('Handle_contacts_in_oracle - ' ||
		       'Can not find Org_id, cust_account_id and party_id for sf_id - ' ||
		       get_pop_r.sf_contact_id);
          l_err_msg := 'Handle_contacts_in_oracle - ' ||
	           'Can not find Org_id, cust_account_id and party_id for sf_id - ' ||
	           get_pop_r.sf_contact_id;
        
          upd_temp_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
	           p_status     => 'ERROR', -- i   v
	           p_error_code => l_err_code, -- i/o v
	           p_error_msg  => l_err_msg); -- i/o v
        
        END IF; -- l_org_id
      EXCEPTION
        WHEN general_exception THEN
          NULL;
      END;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'GEN EXC - create_sf_contact - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END create_sf_contact;

  --------------------------------------------------------------------
  --  name:            upload_contact_point
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/10/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        upload from excel email address for contacts.
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  16/12/2010  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE upload_contact_point(errbuf  OUT VARCHAR2,
		         retcode OUT VARCHAR2) IS
  
    CURSOR get_pop_c IS
      SELECT *
      FROM   xxobjt_conv_hz_contact_points c
      WHERE  c.status = 'NEW'
      AND    c.run_code IS NULL;
  
    l_contact_point_id NUMBER;
    l_err_code         VARCHAR2(10);
    l_err_msg          VARCHAR2(2000);
  
    general_exception EXCEPTION;
  BEGIN
    errbuf  := 'SUCCESS';
    retcode := 0;
  
    SELECT user_id
    INTO   g_user_id
    FROM   fnd_user
    WHERE  user_name = 'SALESFORCE';
  
    FOR get_pop_r IN get_pop_c LOOP
      l_contact_point_id := NULL;
      l_err_code         := NULL;
      l_err_msg          := NULL;
    
      IF get_pop_r.contact_point_id IS NULL THEN
        create_contact_point_api(p_party_id         => get_pop_r.rel_party_id, -- i n
		         p_phone_number     => NULL, -- i v
		         p_mobile_phone     => NULL, -- i v
		         p_email            => get_pop_r.email_address, -- i v
		         p_fax              => NULL, -- i v
		         p_contact_point_id => l_contact_point_id, -- o n
		         p_err_code         => l_err_code, -- o v
		         p_err_msg          => l_err_msg); -- o v
      
      ELSE
        update_contact_point_api(p_party_id         => get_pop_r.rel_party_id, -- i n
		         p_phone_number     => NULL, -- i v
		         p_mobile_phone     => NULL, -- i v
		         p_email            => get_pop_r.email_address, -- i v
		         p_ovn              => get_pop_r.object_version_number,
		         p_contact_point_id => get_pop_r.contact_point_id, -- i n
		         p_err_code         => l_err_code, -- o v
		         p_err_msg          => l_err_msg); -- o v
      END IF;
      -- handle log fields
      IF l_err_code = 1 THEN
        upd_temp_point_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		   p_status     => 'ERROR', -- i   v
		   p_error_code => l_err_code, -- i/o v
		   p_error_msg  => l_err_msg); -- i/o v
      
      ELSE
        upd_temp_point_tbl(p_entity_id  => get_pop_r.entity_id, -- i   v
		   p_status     => 'SUCCESS', -- i   v
		   p_error_code => l_err_code, -- i/o v
		   p_error_msg  => l_err_msg); -- i/o v
      
      END IF; -- api party site
    END LOOP;
  END upload_contact_point;

  --------------------------------------------------------------------
  --  name:            upload_cti_contact_phones
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/11/2011
  --------------------------------------------------------------------
  --  purpose :        upload from excel contacts phones for CTI project
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  15/11/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE upload_cti_contact_phones(errbuf     OUT VARCHAR2,
			  retcode    OUT VARCHAR2,
			  p_location IN VARCHAR2, -- /UtlFiles/Forwarder
			  p_filename IN VARCHAR2) IS
  
    l_contact_point_id   NUMBER;
    l_customer_name      VARCHAR2(360);
    l_person_first_name  VARCHAR2(360);
    l_person_last_name   VARCHAR2(360);
    l_primary_flag       VARCHAR2(100);
    l_phone_line_type    VARCHAR2(100);
    l_fixed_country_code VARCHAR2(100);
    l_fixed_area_code    VARCHAR2(100);
    l_fixed_phone_number VARCHAR2(100);
    l_fixed_extension    VARCHAR2(100);
    l_owner_party_id     NUMBER;
    l_ovn                NUMBER;
    l_file_hundler       utl_file.file_type;
    l_line_buffer        VARCHAR2(2500);
    l_counter            NUMBER := 0;
    l_pos                NUMBER;
    c_delimiter CONSTANT VARCHAR2(1) := ',';
    --l_flag               varchar2(2);
    l_err_msg           VARCHAR2(1500);
    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_phone_rec         hz_contact_point_v2pub.phone_rec_type;
    l_return_status     VARCHAR2(2000) := NULL;
    l_msg_count         NUMBER := NULL;
    l_msg_data          VARCHAR2(2000) := NULL;
    l_data              VARCHAR2(2500) := NULL;
    l_msg_index_out     NUMBER;
    invalid_element EXCEPTION;
  
  BEGIN
    errbuf  := 'SUCCESS';
    retcode := 0;
    fnd_msg_pub.initialize;
  
    SELECT user_id
    INTO   g_user_id
    FROM   fnd_user
    WHERE  user_name = 'CONVERSION';
    fnd_global.apps_initialize(user_id      => g_user_id,
		       resp_id      => 51137,
		       resp_appl_id => 514);
  
    -- handle open file to read and handle file exceptions
    BEGIN
      l_file_hundler := utl_file.fopen(location     => p_location,
			   filename     => p_filename,
			   open_mode    => 'r',
			   max_linesize => 32000);
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        retcode := 1;
        errbuf  := 'Import file was failes. 1 Invalid Path for ' ||
	       ltrim(p_filename);
        --fnd_file.put_line(fnd_file.log,'Invalid Path for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Path for ' || ltrim(p_filename));
        RAISE;
      WHEN utl_file.invalid_mode THEN
        retcode := 1;
        errbuf  := 'Import file was failes. 2 Invalid Mode for ' ||
	       ltrim(p_filename);
        --fnd_file.put_line(fnd_file.log,'Invalid Mode for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Mode for ' || ltrim(p_filename));
        RAISE;
      WHEN utl_file.invalid_operation THEN
        retcode := 1;
        errbuf  := 'Invalid operation for ' || ltrim(p_filename) ||
	       substr(SQLERRM, 1, 500);
        --fnd_file.put_line(fnd_file.log,'Invalid operation for ' || ltrim(p_filename) ||SQLERRM);
        dbms_output.put_line('Invalid operation for ' || ltrim(p_filename) ||
		     SQLERRM);
        RAISE;
      WHEN OTHERS THEN
        retcode := 1;
        errbuf  := 'Other for ' || ltrim(p_filename) ||
	       substr(SQLERRM, 1, 500);
        --fnd_file.put_line(fnd_file.log,'Other for ' || ltrim(p_filename));
        dbms_output.put_line('Other for ' || ltrim(p_filename));
        RAISE;
    END;
  
    -- start read from file, do needed validation, and upload data to table. Loop For All File's Lines
    LOOP
      BEGIN
        -- goto next line
        l_counter            := l_counter + 1;
        l_err_msg            := NULL;
        l_contact_point_id   := NULL;
        l_customer_name      := NULL;
        l_person_first_name  := NULL;
        l_person_last_name   := NULL;
        l_primary_flag       := NULL;
        l_phone_line_type    := NULL;
        l_fixed_country_code := NULL;
        l_fixed_area_code    := NULL;
        l_fixed_phone_number := NULL;
        l_fixed_extension    := NULL;
        l_owner_party_id     := NULL;
        l_ovn                := NULL;
      
        -- Get Line and handle exceptions
        BEGIN
          utl_file.get_line(file   => l_file_hundler,
		    buffer => l_line_buffer);
        EXCEPTION
          WHEN utl_file.read_error THEN
	errbuf := 'Read Error for line: ' || l_counter;
	RAISE invalid_element;
          WHEN no_data_found THEN
	EXIT;
          WHEN OTHERS THEN
	errbuf := 'Read Error for line: ' || l_counter || ', Error: ' ||
	          substr(SQLERRM, 1, 500);
	RAISE invalid_element;
        END;
      
        -- Get data from line separate by deliminar
        IF l_counter > 1 THEN
          l_pos              := 0;
          l_contact_point_id := get_value_from_line(l_line_buffer, --
				    l_err_msg,
				    c_delimiter);
          /*l_customer_name        := get_value_from_line(l_line_buffer,
                                                        l_err_msg,
                                                        c_delimiter);
          l_person_first_name    := get_value_from_line(l_line_buffer,
                                                        l_err_msg,
                                                        c_delimiter);
          l_person_last_name     := get_value_from_line(l_line_buffer,
                                                        l_err_msg,
                                                        c_delimiter); */
          l_primary_flag       := get_value_from_line(l_line_buffer, --
				      l_err_msg,
				      c_delimiter);
          l_phone_line_type    := get_value_from_line(l_line_buffer, --
				      l_err_msg,
				      c_delimiter);
          l_fixed_country_code := get_value_from_line(l_line_buffer, --
				      l_err_msg,
				      c_delimiter);
          l_fixed_area_code    := get_value_from_line(l_line_buffer, --
				      l_err_msg,
				      c_delimiter);
          l_fixed_phone_number := get_value_from_line(l_line_buffer, --
				      l_err_msg,
				      c_delimiter);
          l_fixed_extension    := get_value_from_line(l_line_buffer, --
				      l_err_msg,
				      c_delimiter);
          dbms_output.put_line('---- ');
          BEGIN
	SELECT hcp.owner_table_id party_id,
	       hcp.object_version_number
	INTO   l_owner_party_id,
	       l_ovn
	FROM   hz_contact_points hcp
	WHERE  hcp.contact_point_id = l_contact_point_id;
          
          EXCEPTION
	WHEN OTHERS THEN
	  NULL;
          END;
        
          l_contact_point_rec.owner_table_name   := 'HZ_PARTIES';
          l_contact_point_rec.owner_table_id     := l_owner_party_id;
          l_contact_point_rec.primary_flag       := l_primary_flag;
          l_contact_point_rec.contact_point_id   := l_contact_point_id;
          l_contact_point_rec.contact_point_type := 'PHONE';
          l_phone_rec.phone_number               := l_fixed_phone_number;
          l_phone_rec.phone_line_type            := l_phone_line_type;
          l_phone_rec.phone_area_code            := l_fixed_area_code;
          l_phone_rec.phone_extension            := l_fixed_extension;
          l_phone_rec.phone_country_code         := l_fixed_country_code;
        
          -- phone and mobile phone
          hz_contact_point_v2pub.update_phone_contact_point(p_init_msg_list         => fnd_api.g_true, -- i v 'T',
					p_contact_point_rec     => l_contact_point_rec,
					p_phone_rec             => l_phone_rec,
					p_object_version_number => l_ovn,
					x_return_status         => l_return_status, -- o v
					x_msg_count             => l_msg_count, -- o n
					x_msg_data              => l_msg_data); -- o v
        
          IF l_return_status <> fnd_api.g_ret_sts_success THEN
	retcode := 1;
	errbuf  := 'ERROR';
	dbms_output.put_line('E - ' || l_contact_point_id);
	--dbms_output.put_line ('ERR l_customer_name      - '||l_customer_name);
	--dbms_output.put_line ('ERR l_person_first_name  - '||l_person_first_name);
	--dbms_output.put_line ('ERR l_person_last_name   - '||l_person_last_name);
	dbms_output.put_line('Msg data - ' ||
		         substr(l_msg_data, 1, 240));
          
	FOR i IN 1 .. l_msg_count LOOP
	  fnd_msg_pub.get(p_msg_index     => i,
		      p_data          => l_data,
		      p_encoded       => fnd_api.g_false,
		      p_msg_index_out => l_msg_index_out);
	  dbms_output.put_line('ERR Msg - ' || substr(l_data, 1, 240));
	END LOOP;
	ROLLBACK;
          ELSE
	COMMIT;
	retcode := 0;
	errbuf  := 'SUCCESS';
	dbms_output.put_line('S - ' || l_contact_point_id);
	--dbms_output.put_line ('S l_customer_name        - '||l_customer_name);
	--dbms_output.put_line ('S l_person_first_name    - '||l_person_first_name);
	--dbms_output.put_line ('S l_person_last_name     - '||l_person_last_name);
          END IF; -- Status if
        END IF; -- l_counter
      EXCEPTION
        WHEN invalid_element THEN
          NULL;
        WHEN OTHERS THEN
          retcode := 1;
          errbuf  := 'Gen EXC loop Contact point - ' || l_contact_point_id ||
	         ' - ' || substr(SQLERRM, 1, 240);
      END;
    END LOOP;
    utl_file.fclose(l_file_hundler);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'GEN EXC - upload_cti_contact_phones - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
      dbms_output.put_line('GEN EXC - upload_cti_contact_phones - ' ||
		   substr(SQLERRM, 1, 240));
  END upload_cti_contact_phones;

END xxconv_hz_customers_pkg;
/
