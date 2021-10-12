create or replace package body xxhz_api_pkg AS
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
  --  1.1  11/04/2015  Diptasurjya CHG0036940 - Bug fixes - Nullify GL CCID
  --                               for non BILL_TO sites uses creation, and
  --                               stop duplicate checking for account updates
  --  1.2  11/04/2015  Diptasurjya CHG0036791 - Consider site use contact id as change
  --                               in procedure is_site_changed
  --  1.3  22-Mar-2016 Lingaraj    CHG0037971 - SSYS Customer Maintenance form not handling contact DFF
  --  1.4  22-Aug-2017 Lingaraj    CHG0040036 - Upgrade Avalara interface to AvaTax
  --------------------------------------------------------------------

  g_log               VARCHAR2(1) := fnd_profile.value('AFLOG_ENABLED');
  g_log_module        VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
  g_request_id        NUMBER := to_number(fnd_global.conc_request_id);
  g_program_unit      VARCHAR2(30);
  g_created_by_module VARCHAR2(30) := '';

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg VARCHAR2) IS
  BEGIN
    IF g_log = 'Y' AND
       upper('xxhz.customer_maint.xxhz_api_pkg.' || g_program_unit) LIKE
       upper(g_log_module) THEN
      fnd_log.string(log_level => fnd_log.level_unexpected,
	         module    => 'xxhz.customer_maint.xxhz_api_pkg',
	         message   => p_msg);
    END IF;
  END write_log;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Check for difference between old and new values
  --
  -- Change History
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- ---------------------------------------------------------------------------------------------
  FUNCTION is_modified(p_old_value IN VARCHAR2,
	           p_new_value IN VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    IF nvl(p_new_value, fnd_api.g_miss_char) <>
       nvl(p_old_value, fnd_api.g_miss_char) THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      write_log('Handled Exception in IS_MODIFIED: ' ||
	    dbms_utility.format_error_stack);
      RAISE;
  END is_modified;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure has three purposes.  First, if it detects a difference between new and
  --          old value, it will return 'Y'.  Notice that 'Y' is the only value it can return,
  --          otherwise it will be left alone.  This is because it is called consecutively for
  --          sets of data, for example, hz_cust_accounts_all data.  Once a difference is found,
  --          we want p_change_flg to stay as 'Y'.  See is_account_changed for a clear example.
  --
  --          The second purpose of this procedure is to set the new value to G_MISS character
  --          in the event we are changing from a value to NULL.  G_MISS indicates to the API
  --          that we are setting a value to NULL.
  --
  --          Finally, this is used to detect if any of the new values are populated.  If nothing
  --          is populated for, let's say for example, a site, then none of the site APIs need to
  --          be called.  This works similar to the p_change_flg where it will only return a 'Y'
  --          value if new value is populated.  See is_account_changed for a clear example.
  --
  -- Change History
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE is_modified(p_old_value       IN VARCHAR2,
		p_new_value       IN OUT VARCHAR2,
		p_change_flg      IN OUT VARCHAR2,
		p_value_populated IN OUT VARCHAR2) IS
  BEGIN
    IF nvl(p_new_value, fnd_api.g_miss_char) <>
       nvl(p_old_value, fnd_api.g_miss_char) THEN
      p_change_flg := 'Y';

      IF p_new_value IS NULL THEN
        p_new_value := fnd_api.g_miss_char;
      END IF;
    END IF;

    -- Used to detect if field has a value
    IF p_new_value IS NOT NULL THEN
      p_value_populated := 'Y';
    END IF;

    write_log('p_old_value: ' || p_old_value || ' p_new_value: ' ||
	  p_new_value);
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Handled Exception in IS_MODIFIED: ' ||
	    dbms_utility.format_error_stack);
      RAISE;
  END is_modified;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Overloaded procedure of is_modified for numbers
  --
  -- Change History
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE is_modified(p_old_value       IN NUMBER,
		p_new_value       IN OUT NUMBER,
		p_change_flg      IN OUT VARCHAR2,
		p_value_populated IN OUT VARCHAR2) IS
  BEGIN
    IF nvl(p_new_value, fnd_api.g_miss_num) <>
       nvl(p_old_value, fnd_api.g_miss_num) THEN
      p_change_flg := 'Y';

      IF p_new_value IS NULL THEN
        p_new_value := fnd_api.g_miss_num;
      END IF;
    END IF;

    -- Used to detect if field has a value
    IF p_new_value IS NOT NULL THEN
      p_value_populated := 'Y';
    END IF;

    write_log('p_old_value: ' || p_old_value || ' p_new_value: ' ||
	  p_new_value);
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Handled Exception in IS_MODIFIED: ' ||
	    dbms_utility.format_error_stack);
      RAISE;
  END is_modified;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Overloaded procedure of is_modified for dates
  --
  -- Change History
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE is_modified(p_old_value       IN DATE,
		p_new_value       IN OUT DATE,
		p_change_flg      IN OUT VARCHAR2,
		p_value_populated IN OUT VARCHAR2) IS
  BEGIN
    IF nvl(p_new_value, fnd_api.g_miss_date) <>
       nvl(p_old_value, fnd_api.g_miss_date) THEN
      p_change_flg := 'Y';

      IF p_new_value IS NULL THEN
        p_new_value := fnd_api.g_miss_date;
      END IF;
    END IF;

    -- Used to detect if field has a value
    IF p_new_value IS NOT NULL THEN
      p_value_populated := 'Y';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Handled Exception in IS_MODIFIED: ' ||
	    dbms_utility.format_error_stack);
      RAISE;
  END is_modified;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Checks account level data for
  --                Customers                 - hz_parties, hz_cust_accounts_all
  --                Customer Classifications  - hz_code_assignments
  --                Party Relationships       - hz_relationships
  --                Account Relationships     - hz_cust_acct_relate
  --            for ANY changes (in the case of updates) or for ANY fields populated
  --            (in the case of inserts).  If it finds changes, x_chg_flag will be
  --            returned with 'Y' signaling the calling program to call the corresponding
  --            Oracle update API.  If it finds fields populated, in the case of inserts,
  --            x_populated_flag will be returned with a value of 'Y' signaling the calling
  --            program to call the corresponding Oracle create API.
  --
  --            is_modified will also set NULL values to fnd_api.g_miss
  --            values in the event of NULL values vs database
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------
  PROCEDURE is_account_changed(p_acc_rec        IN OUT customer_rec,
		       p_type           IN VARCHAR2,
		       x_chg_flag       OUT VARCHAR2,
		       x_populated_flag OUT VARCHAR2,
		       x_ovn            OUT NUMBER) IS
    t_party_rec                 hz_parties%ROWTYPE;
    t_account_rec               hz_cust_accounts_all%ROWTYPE;
    t_code_assignments_rec      hz_code_assignments%ROWTYPE;
    t_party_relationships_rec   hz_relationships%ROWTYPE;
    t_account_relationships_rec hz_cust_acct_relate%ROWTYPE;
    t_tax_registrations         zx_registrations%ROWTYPE;
  BEGIN
    write_log('BEGIN IS_ACCOUNT_CHANGED');

    IF p_type = 'PARTY' THEN
      x_chg_flag       := 'N';
      x_populated_flag := 'N';

      IF p_acc_rec.cust_organization_rec.party_rec.party_id IS NOT NULL THEN
        SELECT *
        INTO   t_party_rec
        FROM   hz_parties
        WHERE  party_id =
	   p_acc_rec.cust_organization_rec.party_rec.party_id;

        p_acc_rec.cust_organization_rec.created_by_module := NULL;
      END IF;

      is_modified(t_party_rec.party_id,
	      p_acc_rec.cust_organization_rec.party_rec.party_id,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.status,
	      p_acc_rec.cust_organization_rec.party_rec.status,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.party_name,
	      p_acc_rec.cust_organization_rec.organization_name,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.organization_name_phonetic,
	      p_acc_rec.cust_organization_rec.organization_name_phonetic,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.category_code,
	      p_acc_rec.cust_organization_rec.party_rec.category_code,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.duns_number_c,
	      p_acc_rec.cust_organization_rec.duns_number_c,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.tax_reference,
	      p_acc_rec.cust_organization_rec.tax_reference,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.jgzz_fiscal_code,
	      p_acc_rec.cust_organization_rec.jgzz_fiscal_code,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.known_as,
	      p_acc_rec.cust_organization_rec.known_as,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute_category,
	      p_acc_rec.cust_organization_rec.attribute_category,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute1,
	      p_acc_rec.cust_organization_rec.party_rec.attribute1,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute2,
	      p_acc_rec.cust_organization_rec.party_rec.attribute2,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute3,
	      p_acc_rec.cust_organization_rec.party_rec.attribute3,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute4,
	      p_acc_rec.cust_organization_rec.party_rec.attribute4,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute5,
	      p_acc_rec.cust_organization_rec.party_rec.attribute5,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute6,
	      p_acc_rec.cust_organization_rec.party_rec.attribute6,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute7,
	      p_acc_rec.cust_organization_rec.party_rec.attribute7,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute8,
	      p_acc_rec.cust_organization_rec.party_rec.attribute8,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute9,
	      p_acc_rec.cust_organization_rec.party_rec.attribute9,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute10,
	      p_acc_rec.cust_organization_rec.party_rec.attribute10,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute11,
	      p_acc_rec.cust_organization_rec.party_rec.attribute11,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute12,
	      p_acc_rec.cust_organization_rec.party_rec.attribute12,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute13,
	      p_acc_rec.cust_organization_rec.party_rec.attribute13,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute14,
	      p_acc_rec.cust_organization_rec.party_rec.attribute14,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute15,
	      p_acc_rec.cust_organization_rec.party_rec.attribute15,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute16,
	      p_acc_rec.cust_organization_rec.party_rec.attribute16,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute17,
	      p_acc_rec.cust_organization_rec.party_rec.attribute17,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute18,
	      p_acc_rec.cust_organization_rec.party_rec.attribute18,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute19,
	      p_acc_rec.cust_organization_rec.party_rec.attribute19,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.attribute20,
	      p_acc_rec.cust_organization_rec.party_rec.attribute20,
	      x_chg_flag,
	      x_populated_flag);

      x_ovn := t_party_rec.object_version_number;
    END IF;

    IF p_type = 'CUST_ACCOUNT' THEN
      x_chg_flag       := 'N';
      x_populated_flag := 'N';

      IF p_acc_rec.cust_account_rec.cust_account_id IS NOT NULL THEN
        SELECT *
        INTO   t_account_rec
        FROM   hz_cust_accounts_all
        WHERE  cust_account_id = p_acc_rec.cust_account_rec.cust_account_id;

        p_acc_rec.cust_account_rec.created_by_module := NULL;
      END IF;

      -- x_chg_flag will stay = 'N' unless ANY difference is found.  Then it will be 'Y' indicating a change has occurred.
      is_modified(t_account_rec.customer_type,
	      p_acc_rec.cust_account_rec.customer_type,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.account_name,
	      p_acc_rec.cust_account_rec.account_name,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.sales_channel_code,
	      p_acc_rec.cust_account_rec.sales_channel_code,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.price_list_id,
	      p_acc_rec.cust_account_rec.price_list_id,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.freight_term,
	      p_acc_rec.cust_account_rec.freight_term,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.ship_via,
	      p_acc_rec.cust_account_rec.ship_via,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.fob_point,
	      p_acc_rec.cust_account_rec.fob_point,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.warehouse_id,
	      p_acc_rec.cust_account_rec.warehouse_id,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.date_type_preference,
	      p_acc_rec.cust_account_rec.date_type_preference,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.ship_sets_include_lines_flag,
	      p_acc_rec.cust_account_rec.ship_sets_include_lines_flag,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.arrivalsets_include_lines_flag,
	      p_acc_rec.cust_account_rec.arrivalsets_include_lines_flag,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.sched_date_push_flag,
	      p_acc_rec.cust_account_rec.sched_date_push_flag,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.status,
	      p_acc_rec.cust_account_rec.status,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute_category,
	      p_acc_rec.cust_account_rec.attribute_category,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute1,
	      p_acc_rec.cust_account_rec.attribute1,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute2,
	      p_acc_rec.cust_account_rec.attribute2,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute3,
	      p_acc_rec.cust_account_rec.attribute3,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute4,
	      p_acc_rec.cust_account_rec.attribute4,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute5,
	      p_acc_rec.cust_account_rec.attribute5,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute6,
	      p_acc_rec.cust_account_rec.attribute6,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute7,
	      p_acc_rec.cust_account_rec.attribute7,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute8,
	      p_acc_rec.cust_account_rec.attribute8,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute9,
	      p_acc_rec.cust_account_rec.attribute9,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute10,
	      p_acc_rec.cust_account_rec.attribute10,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute11,
	      p_acc_rec.cust_account_rec.attribute11,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute12,
	      p_acc_rec.cust_account_rec.attribute12,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute13,
	      p_acc_rec.cust_account_rec.attribute13,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute14,
	      p_acc_rec.cust_account_rec.attribute14,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute15,
	      p_acc_rec.cust_account_rec.attribute15,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute16,
	      p_acc_rec.cust_account_rec.attribute16,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute17,
	      p_acc_rec.cust_account_rec.attribute17,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute18,
	      p_acc_rec.cust_account_rec.attribute18,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute19,
	      p_acc_rec.cust_account_rec.attribute19,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_account_rec.attribute20,
	      p_acc_rec.cust_account_rec.attribute20,
	      x_chg_flag,
	      x_populated_flag);

      x_ovn := t_account_rec.object_version_number;
    END IF;

    IF p_type = 'CUST_CLASS' THEN
      x_chg_flag       := 'N';
      x_populated_flag := 'N';

      IF p_acc_rec.cust_classifications_rec.code_assignment_id IS NOT NULL THEN
        SELECT *
        INTO   t_code_assignments_rec
        FROM   hz_code_assignments
        WHERE  code_assignment_id =
	   p_acc_rec.cust_classifications_rec.code_assignment_id;

        p_acc_rec.cust_classifications_rec.created_by_module := NULL;
      END IF;

      is_modified(t_code_assignments_rec.class_category,
	      p_acc_rec.cust_classifications_rec.class_category,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_code_assignments_rec.class_code,
	      p_acc_rec.cust_classifications_rec.class_code,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_code_assignments_rec.start_date_active,
	      p_acc_rec.cust_classifications_rec.start_date_active,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_code_assignments_rec.end_date_active,
	      p_acc_rec.cust_classifications_rec.end_date_active,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_code_assignments_rec.status,
	      p_acc_rec.cust_classifications_rec.status,
	      x_chg_flag,
	      x_populated_flag);

      x_ovn := t_account_rec.object_version_number;
    END IF;

    IF p_type = 'PARTY_RELATIONSHIP' THEN
      x_chg_flag       := 'N';
      x_populated_flag := 'N';

      IF p_acc_rec.cust_relationship_rec.relationship_id IS NOT NULL THEN
        SELECT *
        INTO   t_party_relationships_rec
        FROM   hz_relationships
        WHERE  relationship_id =
	   p_acc_rec.cust_relationship_rec.relationship_id
        AND    directional_flag = 'B';

        p_acc_rec.cust_relationship_rec.created_by_module := NULL;

        -- Since this value is defaulted on the form, I don't want to check it for new customers in case the form sends a 'blank' record through
        is_modified(t_party_relationships_rec.status,
	        p_acc_rec.cust_relationship_rec.status,
	        x_chg_flag,
	        x_populated_flag);
      END IF;

      is_modified(t_party_relationships_rec.comments,
	      p_acc_rec.cust_relationship_rec.comments,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_relationships_rec.start_date,
	      p_acc_rec.cust_relationship_rec.start_date,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_relationships_rec.end_date,
	      p_acc_rec.cust_relationship_rec.end_date,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_relationships_rec.relationship_code,
	      p_acc_rec.cust_relationship_rec.relationship_code,
	      x_chg_flag,
	      x_populated_flag);

      x_ovn := t_party_relationships_rec.object_version_number;
    END IF;

    IF p_type = 'ACCOUNT_RELATIONSHIP' THEN
      x_chg_flag       := 'N';
      x_populated_flag := 'N';

      IF p_acc_rec.cust_account_relationship_rec.cust_acct_relate_id IS NOT NULL THEN
        SELECT *
        INTO   t_account_relationships_rec
        FROM   hz_cust_acct_relate_all
        WHERE  cust_acct_relate_id =
	   p_acc_rec.cust_account_relationship_rec.cust_acct_relate_id;

        p_acc_rec.cust_account_relationship_rec.created_by_module := NULL;

        -- Since these values are defaulted on the form, I don't want to check them for new customers in case the form sends a 'blank' record through
        is_modified(t_account_relationships_rec.status,
	        p_acc_rec.cust_account_relationship_rec.status,
	        x_chg_flag,
	        x_populated_flag);
        is_modified(t_account_relationships_rec.customer_reciprocal_flag,
	        p_acc_rec.cust_account_relationship_rec.customer_reciprocal_flag,
	        x_chg_flag,
	        x_populated_flag);
        is_modified(t_account_relationships_rec.bill_to_flag,
	        p_acc_rec.cust_account_relationship_rec.bill_to_flag,
	        x_chg_flag,
	        x_populated_flag);
        is_modified(t_account_relationships_rec.ship_to_flag,
	        p_acc_rec.cust_account_relationship_rec.ship_to_flag,
	        x_chg_flag,
	        x_populated_flag);
      END IF;

      -- This is to check if a new customer is coming through.  This value will never change after initial creation
      is_modified(t_account_relationships_rec.related_cust_account_id,
	      p_acc_rec.cust_account_relationship_rec.related_cust_account_id,
	      x_chg_flag,
	      x_populated_flag);

      x_ovn := t_account_relationships_rec.object_version_number;
    END IF;

    IF p_type = 'PARTY_TAX_REGISTRATION' THEN
      x_chg_flag       := 'N';
      x_populated_flag := 'N';

      IF p_acc_rec.cust_tax_registration.registration_id IS NOT NULL THEN
        SELECT *
        INTO   t_tax_registrations
        FROM   zx_registrations
        WHERE  registration_id =
	   p_acc_rec.cust_tax_registration.registration_id;
      END IF;

      is_modified(t_tax_registrations.registration_status_code,
	      p_acc_rec.cust_tax_registration.registration_status_code,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_tax_registrations.tax_regime_code,
	      p_acc_rec.cust_tax_registration.tax_regime_code,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_tax_registrations.effective_from,
	      p_acc_rec.cust_tax_registration.effective_from,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_tax_registrations.effective_to,
	      p_acc_rec.cust_tax_registration.effective_to,
	      x_chg_flag,
	      x_populated_flag);

    END IF;

    write_log('x_populated_flag: ' || x_populated_flag);
    write_log('x_chg_flag: ' || x_chg_flag);
    write_log('x_ovn: ' || x_ovn);

    write_log('END IS_ACCOUNT_CHANGED');
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Error in IS_ACCOUNT_CHANGED: ' ||
	    dbms_utility.format_error_stack);
      write_log('END IS_ACCOUNT_CHANGED (EXCEPTION)');
      RAISE;
  END is_account_changed;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Checks profile data on hz_customer profiles
  --            for ANY changes (in the case of updates) or for ANY fields populated
  --            (in the case of inserts).  If it finds changes, x_chg_flag will be
  --            returned with 'Y' signaling the calling program to call the corresponding
  --            Oracle update API.  If it finds fields populated, in the case of inserts,
  --            x_populated_flag will be returned with a value of 'Y' signaling the calling
  --            program to call the corresponding Oracle create API.
  --
  --            is_modified will also set NULL values to fnd_api.g_miss
  --            values in the event of NULL values vs database
  --
  --            This is used for customer account level and site level profiles
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------
  PROCEDURE is_profile_changed(p_cust_profile_rec IN OUT hz_customer_profile_v2pub.customer_profile_rec_type,
		       x_chg_flag         OUT VARCHAR2,
		       x_populated_flag   OUT VARCHAR2,
		       x_ovn              OUT NUMBER) IS
    t_profile_rec     hz_customer_profiles%ROWTYPE;
    t_profile_amt_rec hz_cust_profile_amts%ROWTYPE;
  BEGIN
    write_log('BEGIN IS_PROFILE_CHANGED');

    x_chg_flag       := 'N';
    x_populated_flag := 'N';

    write_log('cust_account_profile_id: ' ||
	  p_cust_profile_rec.cust_account_profile_id);
    IF p_cust_profile_rec.cust_account_profile_id IS NOT NULL THEN
      SELECT *
      INTO   t_profile_rec
      FROM   hz_customer_profiles
      WHERE  cust_account_profile_id =
	 p_cust_profile_rec.cust_account_profile_id;

      p_cust_profile_rec.created_by_module := NULL;
    END IF;

    is_modified(t_profile_rec.profile_class_id,
	    p_cust_profile_rec.profile_class_id,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.collector_id,
	    p_cust_profile_rec.collector_id,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.credit_checking,
	    p_cust_profile_rec.credit_checking,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.credit_hold,
	    p_cust_profile_rec.credit_hold,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.override_terms,
	    p_cust_profile_rec.override_terms,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.discount_terms,
	    p_cust_profile_rec.discount_terms,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.standard_terms,
	    p_cust_profile_rec.standard_terms,
	    x_chg_flag,
	    x_populated_flag);

    -- Profile DFFs
    is_modified(t_profile_rec.attribute_category,
	    p_cust_profile_rec.attribute_category,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute1,
	    p_cust_profile_rec.attribute1,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute2,
	    p_cust_profile_rec.attribute2,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute3,
	    p_cust_profile_rec.attribute3,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute4,
	    p_cust_profile_rec.attribute4,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute5,
	    p_cust_profile_rec.attribute5,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute6,
	    p_cust_profile_rec.attribute6,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute7,
	    p_cust_profile_rec.attribute7,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute8,
	    p_cust_profile_rec.attribute8,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute9,
	    p_cust_profile_rec.attribute9,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute10,
	    p_cust_profile_rec.attribute10,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute11,
	    p_cust_profile_rec.attribute11,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute12,
	    p_cust_profile_rec.attribute12,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute13,
	    p_cust_profile_rec.attribute13,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute14,
	    p_cust_profile_rec.attribute14,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_rec.attribute15,
	    p_cust_profile_rec.attribute15,
	    x_chg_flag,
	    x_populated_flag);

    x_ovn := t_profile_rec.object_version_number;

    write_log('x_populated_flag: ' || x_populated_flag);
    write_log('x_chg_flag: ' || x_chg_flag);
    write_log('x_ovn: ' || x_ovn);

    write_log('END IS_PROFILE_CHANGED');
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Error in IS_PROFILE_CHANGED: ' ||
	    dbms_utility.format_error_stack);
      write_log('END IS_PROFILE_CHANGED (EXCEPTION)');
      RAISE;
  END is_profile_changed;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Checks amount profile data on hz_cust_profile_amts
  --            for ANY changes (in the case of updates) or for ANY fields populated
  --            (in the case of inserts).  If it finds changes, x_chg_flag will be
  --            returned with 'Y' signaling the calling program to call the corresponding
  --            Oracle update API.  If it finds fields populated, in the case of inserts,
  --            x_populated_flag will be returned with a value of 'Y' signaling the calling
  --            program to call the corresponding Oracle create API.
  --
  --            is_modified will also set NULL values to fnd_api.g_miss
  --            values in the event of NULL values vs database
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------
  PROCEDURE is_profile_amt_changed(p_cust_profile_amt_rec IN OUT hz_customer_profile_v2pub.cust_profile_amt_rec_type,
		           x_chg_flag             OUT VARCHAR2,
		           x_populated_flag       OUT VARCHAR2,
		           x_ovn                  OUT NUMBER) IS
    t_profile_rec     hz_customer_profiles%ROWTYPE;
    t_profile_amt_rec hz_cust_profile_amts%ROWTYPE;
  BEGIN
    write_log('BEGIN IS_PROFILE_AMT_CHANGED');

    x_chg_flag       := 'N';
    x_populated_flag := 'N';

    IF p_cust_profile_amt_rec.cust_acct_profile_amt_id IS NOT NULL THEN
      SELECT *
      INTO   t_profile_amt_rec
      FROM   hz_cust_profile_amts
      WHERE  cust_acct_profile_amt_id =
	 p_cust_profile_amt_rec.cust_acct_profile_amt_id;

      p_cust_profile_amt_rec.created_by_module := NULL;
    END IF;

    is_modified(t_profile_amt_rec.overall_credit_limit,
	    p_cust_profile_amt_rec.overall_credit_limit,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.currency_code,
	    p_cust_profile_amt_rec.currency_code,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute_category,
	    p_cust_profile_amt_rec.attribute_category,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute1,
	    p_cust_profile_amt_rec.attribute1,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute2,
	    p_cust_profile_amt_rec.attribute2,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute3,
	    p_cust_profile_amt_rec.attribute3,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute4,
	    p_cust_profile_amt_rec.attribute4,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute5,
	    p_cust_profile_amt_rec.attribute5,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute6,
	    p_cust_profile_amt_rec.attribute6,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute7,
	    p_cust_profile_amt_rec.attribute7,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute8,
	    p_cust_profile_amt_rec.attribute8,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute9,
	    p_cust_profile_amt_rec.attribute9,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute10,
	    p_cust_profile_amt_rec.attribute10,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute11,
	    p_cust_profile_amt_rec.attribute11,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute12,
	    p_cust_profile_amt_rec.attribute12,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute13,
	    p_cust_profile_amt_rec.attribute13,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute14,
	    p_cust_profile_amt_rec.attribute14,
	    x_chg_flag,
	    x_populated_flag);
    is_modified(t_profile_amt_rec.attribute15,
	    p_cust_profile_amt_rec.attribute15,
	    x_chg_flag,
	    x_populated_flag);

    x_ovn := t_profile_amt_rec.object_version_number;

    write_log('x_populated_flag: ' || x_populated_flag);
    write_log('x_chg_flag: ' || x_chg_flag);
    write_log('x_ovn: ' || x_ovn);

    write_log('END IS_PROFILE_AMT_CHANGED');
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Error in IS_PROFILE_AMT_CHANGED: ' ||
	    dbms_utility.format_error_stack);
      write_log('END IS_PROFILE_AMT_CHANGED (EXCEPTION)');
      RAISE;
  END is_profile_amt_changed;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: utility function to get object's version numbers based on p_type.  This is called
  --          from the handle lock procedures
  --
  -- Change History
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- ---------------------------------------------------------------------------------------------
  FUNCTION get_object_version_number(p_type VARCHAR2,
			 p_id   NUMBER,
			 p_id2  NUMBER DEFAULT NULL)
    RETURN NUMBER IS
    l_ovn NUMBER;
  BEGIN
    write_log('BEGIN GET_OBJECT_VERSION_NUMBER');
    write_log('p_type: ' || p_type || ' p_id ' || p_id);

    -- account party level
    IF p_type = 'ACCOUNT' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_cust_accounts_all
      WHERE  cust_account_id = p_id;
    ELSIF p_type = 'PARTY' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_parties
      WHERE  party_id = p_id;

      -- Party relationship
    ELSIF p_type = 'PARTY_RELATIONSHIP' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_relationships
      WHERE  relationship_id = p_id
      AND    directional_flag = 'B';
      -- Customer Account relationship
    ELSIF p_type = 'ACCOUNT_RELATIONSHIP' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_cust_acct_relate_all
      WHERE  cust_acct_relate_id = p_id;

      -- profile level
    ELSIF p_type = 'CUST_PROFILE' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_customer_profiles
      WHERE  cust_account_profile_id = p_id;
    ELSIF p_type = 'CUST_PROFILE_AMT' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_cust_profile_amts
      WHERE  cust_acct_profile_amt_id = p_id;

      -- Customer Classification
    ELSIF p_type = 'CUST_CLASS' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_code_assignments
      WHERE  code_assignment_id = p_id;

      -- Customer Tax Registration
    ELSIF p_type = 'PARTY_TAX_REGISTRATION' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   zx_registrations
      WHERE  registration_id = p_id;

      -- site level
    ELSIF p_type = 'LOCATION' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_locations
      WHERE  location_id = p_id;
    ELSIF p_type = 'PARTY_SITE' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_party_sites
      WHERE  party_site_id = p_id;
    ELSIF p_type = 'CUST_SITE' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_cust_acct_sites_all
      WHERE  cust_acct_site_id = p_id;
    ELSIF p_type = 'SITE_USE' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_cust_site_uses_all
      WHERE  site_use_id = p_id;

      -- Contact level
    ELSIF p_type = 'CONTACT_PARTY' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_parties
      WHERE  party_id = p_id;
    ELSIF p_type = 'ORG_CONTACT' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_org_contacts
      WHERE  org_contact_id = p_id;
    ELSIF p_type = 'ROLE' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_cust_account_roles
      WHERE  cust_account_role_id = p_id;
    ELSIF p_type = 'CONTACT_SITE_USE' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_party_site_uses
      WHERE  party_site_use_id = p_id;
    ELSIF p_type = 'CONTACT_ROLE_RESPONSIBILITY' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_role_responsibility
      WHERE  responsibility_id = p_id;
    ELSIF p_type = 'CONTACT_POINT' THEN
      SELECT object_version_number
      INTO   l_ovn
      FROM   hz_contact_points
      WHERE  contact_point_id = p_id;
    END IF;

    write_log('l_ovn: ' || l_ovn);
    write_log('END GET_OBJECT_VERSION_NUMBER');
    RETURN l_ovn;
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Handled Exception in GET_OBJECT_VERSION_NUMBER: ' ||
	    dbms_utility.format_error_stack);
      write_log('END GET_OBJECT_VERSION_NUMBER (EXCEPTION)');
      --RETURN FND_API.G_MISS_NUM;
      RETURN NULL;
  END get_object_version_number;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: utility function to get lookup_code or validate lookup code
  --
  -- Change History
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- ---------------------------------------------------------------------------------------------
  FUNCTION get_lookup_code(p_lookup_type fnd_lookup_values.lookup_type%TYPE,
		   p_value       VARCHAR2) RETURN VARCHAR2 IS
    l_lookup_code fnd_lookup_values.lookup_code%TYPE;
  BEGIN
    write_log('START GET_LOOKUP_CODE');
    write_log('p_lookup_type: ' || p_lookup_type);
    write_log('p_value: ' || p_value);

    SELECT lookup_code
    INTO   l_lookup_code
    FROM   fnd_lookup_values
    WHERE  lookup_type = p_lookup_type
    AND    LANGUAGE = userenv('LANG')
    AND    (upper(meaning) = upper(p_value) OR
          upper(lookup_code) = upper(p_value));

    write_log('END GET_LOOKUP_CODE');
    RETURN l_lookup_code;
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Handled Exception in GET_LOOKUP_CODE: ' ||
	    dbms_utility.format_error_stack);
      write_log('END GET_LOOKUP_CODE (EXCEPTION)');
      RETURN NULL;
  END get_lookup_code;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: utility function to get site_use_id based on site_use_code and cust_acct_site_id
  --
  -- Change History
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- ---------------------------------------------------------------------------------------------
  FUNCTION get_site_use_id(p_cust_acct_site_id IN hz_cust_acct_sites_all.cust_acct_site_id%TYPE,
		   p_site_use_code     IN hz_cust_site_uses_all.site_use_code%TYPE)
    RETURN NUMBER IS
    l_site_use_id hz_cust_site_uses_all.site_use_id%TYPE;
  BEGIN
    write_log('START GET_SITE_USE_ID');
    write_log('p_cust_acct_site_id: ' || p_cust_acct_site_id);

    SELECT site_use_id
    INTO   l_site_use_id
    FROM   hz_cust_site_uses_all
    WHERE  site_use_code = p_site_use_code
    AND    cust_acct_site_id = p_cust_acct_site_id;

    write_log('END GET_SITE_USE_ID');
    RETURN l_site_use_id;
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Handled Exception in GET_SITE_USE_ID: ' ||
	    dbms_utility.format_error_stack);
      write_log('END GET_SITE_USE_ID (EXCEPTION)');
      RETURN NULL;
  END get_site_use_id;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles customer credit profile workflows.  These fire when any of the
  --            following fields are changed.
  --
  --            table                     column                 p_entity_code
  --            ------------------------  ---------------------  ----------------------
  --            hz_customer_profiles      standard_terms         CUST_PAY_TERM
  --            hz_customer_profiles      credit_hold            CUST_CREDIT_CHK
  --            hz_customer_profiles      credit_checking        CUST_CREDIT_CHK
  --            hz_cust_profile_amts      overall_credit_limit   CUST_CREDIT_LIMIT
  --
  --            NOTE: CUST_PAY_TERM is called at the account and site use level.
  --
  --            The first part of the procedure checks if any of the fields above
  --            have been modified.  The field checked is based on the p_entity_code.
  --
  --            If one of the fields has been changed, the l_process_flag will be set
  --            to TRUE.  Then, either the worflow will fire or the user will be notified
  --            that a change is pending and that the workflow is already in process.
  --            The e_appr_skip EXCEPTION will then handle resetting the value to it's
  --            previous value to reset for the calling program, as the workflow handles
  --            setting the value to the new value
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE handle_custom_wf(p_entity_code    IN VARCHAR2,
		     p_acc_rec        IN OUT customer_rec,
		     p_site_rec       IN OUT customer_site_rec,
		     x_return_status  OUT VARCHAR2,
		     x_return_message OUT VARCHAR2) IS
    l_exists_pending_wf           VARCHAR2(1);
    l_err_msg                     VARCHAR2(1000);
    l_err_code                    NUMBER;
    l_curr_payment_term_id        hz_customer_profiles.standard_terms%TYPE;
    l_curr_credit_hold_flag       hz_customer_profiles.credit_hold%TYPE;
    l_curr_credit_check_flag      hz_customer_profiles.credit_checking%TYPE;
    l_process_flag                BOOLEAN := FALSE;
    l_cust_account_id             hz_cust_accounts_all.cust_account_id%TYPE;
    l_site_use_id                 hz_cust_site_uses_all.site_use_id%TYPE;
    l_appr_needed                 VARCHAR2(1);
    l_curr_credit_limit           NUMBER;
    l_cust_account_profile_id     hz_customer_profiles.cust_account_profile_id%TYPE;
    l_cust_account_profile_amt_id NUMBER;
    l_item_key                    VARCHAR2(240);
    l_old_value                   VARCHAR2(240);
    l_new_value                   VARCHAR2(240);
    l_currency_code               VARCHAR2(3);

    e_skip      EXCEPTION;
    e_appr_skip EXCEPTION;
  BEGIN
    write_log('START HANDLE_CUSTOM_WF');
    write_log('p_entity_code: ' || p_entity_code);

    -- Check if custom AR WF is enabled
    IF nvl(fnd_profile.value('XXAR_CUST_WF_ENABLED'), 'N') <> 'Y' THEN
      RAISE e_skip;
    END IF;

    -- Check for changes to fields

    -- Pay terms at the CUSTOMER ACCOUNT level
    IF p_entity_code = 'CUST_PAY_TERM' AND
       p_acc_rec.cust_profile_rec.cust_account_profile_id IS NOT NULL AND
       p_acc_rec.cust_profile_rec.standard_terms IS NOT NULL THEN
      SELECT standard_terms
      INTO   l_curr_payment_term_id
      FROM   hz_customer_profiles
      WHERE  cust_account_profile_id =
	 p_acc_rec.cust_profile_rec.cust_account_profile_id
      AND    site_use_id IS NULL;

      write_log('l_curr_payment_term_id: ' || l_curr_payment_term_id);

      IF is_modified(l_curr_payment_term_id,
	         p_acc_rec.cust_profile_rec.standard_terms) THEN
        l_cust_account_id         := p_acc_rec.cust_profile_rec.cust_account_id;
        l_cust_account_profile_id := p_acc_rec.cust_profile_rec.cust_account_profile_id;
        l_process_flag            := TRUE;
        l_old_value               := l_curr_payment_term_id;
        l_new_value               := p_acc_rec.cust_profile_rec.standard_terms;
      END IF;
    END IF;

    -- Pay terms at the CUSTOMER SITE level
    IF p_entity_code = 'CUST_PAY_TERM' AND
       p_site_rec.cust_site_use_rec.site_use_id IS NOT NULL AND
       p_site_rec.cust_site_use_rec.payment_term_id IS NOT NULL THEN
      SELECT payment_term_id
      INTO   l_curr_payment_term_id
      FROM   hz_cust_site_uses_all
      WHERE  site_use_id = p_site_rec.cust_site_use_rec.site_use_id;

      write_log('l_curr_payment_term_id: ' || l_curr_payment_term_id);

      IF is_modified(l_curr_payment_term_id,
	         p_site_rec.cust_site_use_rec.payment_term_id) THEN
        l_cust_account_id := p_site_rec.cust_site_rec.cust_account_id;
        l_site_use_id     := p_site_rec.cust_site_use_rec.site_use_id;
        l_process_flag    := TRUE;
        l_old_value       := l_curr_payment_term_id;
        l_new_value       := p_site_rec.cust_site_use_rec.payment_term_id;
      END IF;
    END IF;

    -- Credit hold ACCOUNT LEVEL ONLY
    IF p_entity_code = 'CUST_CREDIT_HOLD' AND
       p_acc_rec.cust_profile_rec.cust_account_profile_id IS NOT NULL THEN
      SELECT credit_hold
      INTO   l_curr_credit_hold_flag
      FROM   hz_customer_profiles
      WHERE  cust_account_profile_id =
	 p_acc_rec.cust_profile_rec.cust_account_profile_id
      AND    site_use_id IS NULL;

      write_log('l_curr_credit_hold_flag: ' || l_curr_credit_hold_flag);

      IF is_modified(l_curr_credit_hold_flag,
	         p_acc_rec.cust_profile_rec.credit_hold) THEN
        l_cust_account_id         := p_acc_rec.cust_profile_rec.cust_account_id;
        l_cust_account_profile_id := p_acc_rec.cust_profile_rec.cust_account_profile_id;
        l_process_flag            := TRUE;
        l_old_value               := l_curr_credit_hold_flag;
        l_new_value               := p_acc_rec.cust_profile_rec.credit_hold;
      END IF;
    END IF;

    -- Credit check ACCOUNT LEVEL ONLY
    IF p_entity_code = 'CUST_CREDIT_CHK' AND
       p_acc_rec.cust_profile_rec.cust_account_profile_id IS NOT NULL THEN
      SELECT credit_checking
      INTO   l_curr_credit_check_flag
      FROM   hz_customer_profiles
      WHERE  cust_account_profile_id =
	 p_acc_rec.cust_profile_rec.cust_account_profile_id
      AND    site_use_id IS NULL;

      write_log('l_curr_credit_hold_flag: ' || l_curr_credit_hold_flag);

      IF is_modified(l_curr_credit_check_flag,
	         p_acc_rec.cust_profile_rec.credit_checking) THEN
        l_cust_account_id         := p_acc_rec.cust_profile_rec.cust_account_id;
        l_cust_account_profile_id := p_acc_rec.cust_profile_rec.cust_account_profile_id;
        l_process_flag            := TRUE;
        l_old_value               := l_curr_credit_check_flag;
        l_new_value               := p_acc_rec.cust_profile_rec.credit_checking;
      END IF;
    END IF;

    -- Credit limit ACCOUNT LEVEL ONLY
    IF p_entity_code = 'CUST_CREDIT_LIMIT' AND
       p_acc_rec.cust_profile_amt_rec.cust_acct_profile_amt_id IS NOT NULL AND
       p_acc_rec.cust_profile_amt_rec.overall_credit_limit IS NOT NULL THEN
      SELECT MAX(overall_credit_limit),
	 MAX(currency_code)
      INTO   l_curr_credit_limit,
	 l_currency_code
      FROM   hz_cust_profile_amts
      WHERE  cust_acct_profile_amt_id =
	 p_acc_rec.cust_profile_amt_rec.cust_acct_profile_amt_id;

      write_log('l_curr_credit_limit: ' || l_curr_credit_limit);

      IF is_modified(l_curr_credit_limit,
	         p_acc_rec.cust_profile_amt_rec.overall_credit_limit) THEN
        l_cust_account_id             := p_acc_rec.cust_profile_rec.cust_account_id;
        l_cust_account_profile_amt_id := p_acc_rec.cust_profile_amt_rec.cust_acct_profile_amt_id;
        l_process_flag                := TRUE;
        l_old_value                   := l_curr_credit_limit;
        l_new_value                   := p_acc_rec.cust_profile_amt_rec.overall_credit_limit;
      END IF;
    END IF;

    write_log('l_old_value: ' || l_old_value);
    write_log('l_new_value: ' || l_new_value);

    -- Since a change has occurred, proceed with processing
    IF l_process_flag THEN

      -- Check if in-process workflow exists
      xxhz_cust_apr_util_pkg.get_wf_info(p_cust_acct_id      => l_cust_account_id, --p_acc_rec.cust_profile_rec.cust_account_id,
			     p_site_id           => NULL,
			     p_site_use_id       => l_site_use_id,
			     p_entity_code       => p_entity_code,
			     x_err_code          => l_err_code,
			     x_err_msg           => l_err_msg,
			     x_exists_pending_wf => l_exists_pending_wf,
			     x_info              => x_return_message);

      write_log('l_exists_pending_wf: ' || l_exists_pending_wf);

      IF l_err_code = 1 OR l_exists_pending_wf = 'Y' THEN
        RAISE e_appr_skip;
      END IF;

      -- If no in-process workflow exists, submit the workflow
      xxhz_cust_apr_util_pkg.submit_wf(p_entity_code              => p_entity_code,
			   p_old_value                => l_old_value,
			   p_new_value                => l_new_value,
			   p_cust_acct_id             => l_cust_account_id,
			   p_site_id                  => NULL,
			   p_site_use_id              => l_site_use_id,
			   p_cust_account_profile_id  => l_cust_account_profile_id,
			   p_cust_acct_profile_amt_id => l_cust_account_profile_amt_id,
			   p_attribute1               => l_currency_code,
			   p_attribute2               => NULL,
			   p_attribute3               => NULL,
			   x_err_code                 => l_err_code,
			   x_err_msg                  => l_err_msg,
			   x_itemkey                  => l_item_key,
			   x_appr_needed              => l_appr_needed);

      write_log('l_appr_needed: ' || l_appr_needed);

      IF l_err_code = 1 OR l_appr_needed = 'Y' THEN
        RAISE e_appr_skip;
      END IF;

    END IF;

    x_return_status := fnd_api.g_ret_sts_success;
    write_log('END HANDLE_CUSTOM_WF');
  EXCEPTION
    WHEN e_skip THEN
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_appr_skip THEN
      x_return_message := nvl(l_err_msg, x_return_message);

      -- Need to set values back to their old values.  This will allow program to
      -- continue execution without updating the WF affected values because they
      -- are awaiting approval.
      IF p_entity_code = 'CUST_PAY_TERM' THEN
        -- Doesn't matter that these are set to the same value.  One will be set when saving customers
        -- and one will be set when saving sites.  Basically p_acc_rec.cust_profile_rec is used by customers
        -- and p_site_rec.cust_site_use_rec is used for sites.  When we're looking at a customer
        -- p_site_rec.cust_site_use_rec is essentially a dummy value.  When we're looking at sites,
        -- p_acc_rec.cust_profile_rec is essentially a dummy value.
        p_acc_rec.cust_profile_rec.standard_terms    := l_curr_payment_term_id;
        p_site_rec.cust_site_use_rec.payment_term_id := l_curr_payment_term_id;
      ELSIF p_entity_code = 'CUST_CREDIT_HOLD' THEN
        p_acc_rec.cust_profile_rec.credit_hold := l_curr_credit_hold_flag;
      ELSIF p_entity_code = 'CUST_CREDIT_CHK' THEN
        p_acc_rec.cust_profile_rec.credit_checking := l_curr_credit_check_flag;
      ELSIF p_entity_code = 'CUST_CREDIT_LIMIT' THEN
        p_acc_rec.cust_profile_amt_rec.overall_credit_limit := l_curr_credit_limit;
      END IF;

      -- This will allow program to continue processing, even if a workflow is
      -- submitted or pending.
      write_log('END HANDLE_CUSTOM_WF (E_APPR_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in HANDLE_CUSTOM_WF: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END HANDLE_CUSTOM_WF (EXCEPTION)');
  END handle_custom_wf;

  -- ------------------------------------------------------------------------------------------------------------------------------
  -- *******************************************  HANDLES CUSTOMER EXT ************************************************************
  -- ------------------------------------------------------------------------------------------------------------------------------

  -- -------------------------------------------------------------------------------
  -- Purpose  : This procedure is used to update the xssys_customer_ext table.
  --            See Tech Design for further explanation of this table.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------
  PROCEDURE update_customer_ext(p_external_id            IN xxssys_customer_ext.external_id%TYPE,
		        p_xxssys_customer_ext_id IN xxssys_customer_ext.xxssys_customer_ext_id%TYPE,
		        x_return_status          OUT VARCHAR2,
		        x_return_message         OUT VARCHAR2) IS
    CURSOR c_update IS
      SELECT external_id
      FROM   xxssys_customer_ext
      WHERE  xxssys_customer_ext_id = p_xxssys_customer_ext_id
      FOR    UPDATE OF external_id NOWAIT;

    e_lock EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_lock, -54);
  BEGIN
    write_log('START UPDATE_CUSOTMER_EXT');

    FOR rec IN c_update LOOP
      UPDATE xxssys_customer_ext
      SET    external_id = p_external_id
      WHERE  CURRENT OF c_update;
    END LOOP;

    x_return_status := fnd_api.g_ret_sts_success;
    write_log('END UPDATE_CUSTOMER_EXT');
  EXCEPTION
    WHEN e_lock THEN
      x_return_message := 'Error xxssys_customer_ext record currently locked by another user.';
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END UPDATE_CUSTOMER_EXT (E_ERROR)');
    WHEN OTHERS THEN
      x_return_message := 'Error in ' || g_program_unit || ': ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END UPDATE_CUSTOMER_EXT (EXCEPTION)');
  END update_customer_ext;

  -- -------------------------------------------------------------------------------
  -- Purpose  : This procedure is used to insert into the xssys_customer_ext table.
  --            See Tech Design for further explanation of this table.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------
  PROCEDURE create_customer_ext(p_oe_id           IN xxssys_customer_ext.oe_id%TYPE,
		        p_oe_type         IN xxssys_customer_ext.oe_type%TYPE,
		        p_external_system IN xxssys_customer_ext.external_system%TYPE,
		        p_external_id     IN xxssys_customer_ext.external_id%TYPE DEFAULT NULL,
		        x_return_status   OUT VARCHAR2,
		        x_return_message  OUT VARCHAR2) IS
  BEGIN
    write_log('START CREATE_CUSTOMER_EXT');

    INSERT INTO xxssys_customer_ext
      (xxssys_customer_ext_id,
       oe_id,
       oe_type,
       external_system,
       external_id)
    VALUES
      (xxssys_customer_ext_s.nextval,
       p_oe_id,
       p_oe_type,
       p_external_system,
       p_external_id);

    x_return_status := fnd_api.g_ret_sts_success;
    write_log('END CREATE_CUSTOMER_EXT');
  EXCEPTION
    WHEN OTHERS THEN
      x_return_message := 'Error in ' || g_program_unit || ': ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END CREATE_CUSTOMER_EXT (EXCEPTION)');
  END create_customer_ext;

  -- -------------------------------------------------------------------------------
  -- Purpose  : This handles UPDATE/INSERT into xxssys_customer_ext table
  --            See Tech Design for further explanation of this table.
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------
  PROCEDURE handle_customer_ext(p_oe_id           IN xxssys_customer_ext.oe_id%TYPE,
		        p_oe_type         IN xxssys_customer_ext.oe_type%TYPE,
		        p_external_system IN xxssys_customer_ext.external_system%TYPE,
		        p_external_id     IN xxssys_customer_ext.external_id%TYPE DEFAULT NULL,
		        x_return_status   OUT VARCHAR2,
		        x_return_message  OUT VARCHAR2) IS
    l_xxssys_customer_ext_id xxssys_customer_ext.xxssys_customer_ext_id%TYPE;
  BEGIN
    write_log('START HANDLE_CUSTOMER_EXT');
    write_log('p_oe_id: ' || p_oe_id);
    write_log('p_oe_type: ' || p_oe_type);
    write_log('p_external_system: ' || p_external_system);
    write_log('p_external_id: ' || p_external_id);

    BEGIN
      SELECT xxssys_customer_ext_id
      INTO   l_xxssys_customer_ext_id
      FROM   xxssys_customer_ext
      WHERE  oe_id = p_oe_id
      AND    oe_type = p_oe_type
      AND    external_system = p_external_system;

      update_customer_ext(p_external_id            => p_external_id,
		  p_xxssys_customer_ext_id => l_xxssys_customer_ext_id,
		  x_return_status          => x_return_status,
		  x_return_message         => x_return_message);
    EXCEPTION
      WHEN no_data_found THEN
        create_customer_ext(p_oe_id           => p_oe_id,
		    p_oe_type         => p_oe_type,
		    p_external_system => p_external_system,
		    p_external_id     => p_external_id,
		    x_return_status   => x_return_status,
		    x_return_message  => x_return_message);
    END;

    x_return_status := fnd_api.g_ret_sts_success;
    write_log('END HANDLE_CUSTOMER_EXT');
  EXCEPTION
    WHEN OTHERS THEN
      x_return_message := 'Error in ' || g_program_unit || ': ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END HANDLE_CUSTOMER_EXT (EXCEPTION)');
  END handle_customer_ext;

  -- ------------------------------------------------------------------------------------------------------------------------------
  -- *******************************************  HANDLES CUSTOMER PARTY/ACCOUNT **************************************************
  -- ------------------------------------------------------------------------------------------------------------------------------

  ----------------------------------------------------------------------------------
  -- Purpose  : This will hold any validations for hz_cust_accounts_all, hz_parties,
  --            hz_customer_profiles (at customer level), or hz_cust_profile_amts at
  --            the customer level.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  ----------------------------------------------------------------------------------
  PROCEDURE validate_account(p_acc_rec        IN OUT customer_rec,
		     x_return_status  OUT VARCHAR2,
		     x_return_message OUT VARCHAR2) IS
    e_error EXCEPTION;
  BEGIN
    write_log('BEGIN VALIDATE_ACCOUNT');

    -- Ensure profile class is populated
    IF p_acc_rec.cust_profile_rec.profile_class_id IS NULL OR
       p_acc_rec.cust_organization_rec.party_rec.category_code IS NULL OR
       p_acc_rec.cust_account_rec.customer_type IS NULL OR
       p_acc_rec.cust_account_rec.sales_channel_code IS NULL THEN
      x_return_message := 'Error: Profile Class, Category, Account Type, and Sales Channel are required.';
      RAISE e_error;
    END IF;

    -- Validates that inactivation reason (ATTRIBUTE12) is populated when an account is inactive.
    IF p_acc_rec.cust_account_rec.status = 'I' AND
       p_acc_rec.cust_account_rec.attribute12 IS NULL THEN
      x_return_message := 'Error: Inactive Accounts require Inactivation Reason located under Account Additional Information.';
      RAISE e_error;
    END IF;

    x_return_status := fnd_api.g_ret_sts_success;
    write_log('END VALIDATE_ACCOUNT');
  EXCEPTION
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END VALIDATE_ACCOUNT (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_message := 'Error in VALIDATE_ACCOUNT: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := 'E';
      write_log('END VALIDATE_ACCOUNT (EXCEPTION)');
  END validate_account;

  ----------------------------------------------------------------------------------
  -- Purpose  : Handles create and update of hz_cust_accounts_all data.  x_call_prof_flag
  --            is set to 'Y' on creation of an account.  This signals to the calling
  --            procedure that we do not need to call the API to create a new profile
  --            because it has already been called here.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  ----------------------------------------------------------------------------------
  PROCEDURE handle_account_api(p_ovn            IN hz_cust_accounts_all.object_version_number%TYPE,
		       p_acc_rec        IN OUT customer_rec,
		       x_call_prof_flag OUT VARCHAR2,
		       x_return_status  OUT VARCHAR2,
		       x_return_message OUT VARCHAR2) IS
    t_cust_account_rec     hz_cust_account_v2pub.cust_account_rec_type;
    t_organization_rec     hz_party_v2pub.organization_rec_type;
    t_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;

    l_chg_flag       VARCHAR2(1);
    l_populated_flag VARCHAR2(1);
    l_action         VARCHAR2(20);
    l_ovn            hz_cust_accounts_all.object_version_number%TYPE;

    l_return_status           VARCHAR2(1);
    l_msg_count               NUMBER;
    l_msg_data                VARCHAR2(2000);
    l_data                    VARCHAR2(2000);
    l_msg_index_out           NUMBER;
    l_organization_profile_id hz_organization_profiles.organization_profile_id%TYPE;
    l_create_prof_amt_flag    VARCHAR2(1) := 'F';

    e_error EXCEPTION;
    e_skip  EXCEPTION;
  BEGIN
    write_log('START HANDLE_ACCOUNT_API');
    write_log('p_acc_rec.cust_account_rec.account_name: ' ||
	  p_acc_rec.cust_account_rec.account_name);

    -- Gets set to 'N' on account create
    x_call_prof_flag := 'Y';

    p_acc_rec.cust_organization_rec.organization_type := 'ORGANIZATION';

    fnd_msg_pub.initialize;

    is_account_changed(p_acc_rec        => p_acc_rec,
	           p_type           => 'CUST_ACCOUNT',
	           x_chg_flag       => l_chg_flag,
	           x_populated_flag => l_populated_flag,
	           x_ovn            => l_ovn);

    write_log('p_acc_rec.cust_account_rec.cust_account_id: ' ||
	  p_acc_rec.cust_account_rec.cust_account_id);
    IF p_acc_rec.cust_account_rec.cust_account_id IS NULL THEN
      l_action := 'CREATE';

      IF p_acc_rec.cust_account_rec.account_name IS NULL THEN
        p_acc_rec.cust_account_rec.account_name := p_acc_rec.cust_organization_rec.organization_name;
      END IF;

      IF p_acc_rec.cust_profile_rec.profile_class_id IS NULL THEN
        l_create_prof_amt_flag := 'F';
      ELSE
        l_create_prof_amt_flag := 'T';
      END IF;

      write_log('l_create_prof_amt_flag: ' || l_create_prof_amt_flag);

      hz_cust_account_v2pub.create_cust_account(p_init_msg_list        => 'T',
				p_cust_account_rec     => p_acc_rec.cust_account_rec,
				p_organization_rec     => p_acc_rec.cust_organization_rec,
				p_customer_profile_rec => p_acc_rec.cust_profile_rec,
				p_create_profile_amt   => l_create_prof_amt_flag,
				x_cust_account_id      => p_acc_rec.cust_account_rec.cust_account_id,
				x_account_number       => p_acc_rec.cust_account_rec.account_number,
				x_party_id             => p_acc_rec.cust_organization_rec.party_rec.party_id,
				x_party_number         => p_acc_rec.cust_organization_rec.party_rec.party_number,
				x_profile_id           => l_organization_profile_id,
				x_return_status        => x_return_status,
				x_msg_count            => l_msg_count,
				x_msg_data             => l_msg_data);

      -- On Create of account, profile is already created.  This is sent back to the calling program to indicate
      -- that we do not need to call the profile API again.
      x_call_prof_flag := 'N';
    ELSE
      l_action := 'UPDATE';

      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      -- Record has changed
      IF l_ovn <> p_acc_rec.acct_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_cust_account_v2pub.update_cust_account(p_init_msg_list         => fnd_api.g_true,
				p_cust_account_rec      => p_acc_rec.cust_account_rec,
				p_object_version_number => p_acc_rec.acct_ovn, --l_acc_rec.object_version_number,
				x_return_status         => x_return_status,
				x_msg_count             => l_msg_count,
				x_msg_data              => l_msg_data);
    END IF;
    write_log('Customer Account API ' || l_action || ' return status: ' ||
	  x_return_status);

    -- Handle return status of API
    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'The Customer ' || l_action || ' API Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    ELSE
      -- Profile returned from API is the organization level profile_id.  I need the customer account level profile_id.
      IF x_call_prof_flag = 'N' THEN
        SELECT cust_account_profile_id
        INTO   p_acc_rec.cust_profile_rec.cust_account_profile_id
        FROM   hz_customer_profiles
        WHERE  cust_account_id = p_acc_rec.cust_account_rec.cust_account_id
        AND    site_use_id IS NULL;
      END IF;
    END IF;

    write_log('END HANDLE_ACCOUNT_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END HANDLE_ACCOUNT_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END HANDLE_ACCOUNT_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_message := 'Error in HANDLE_ACCOUNT_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := 'E';
      write_log('END HANDLE_ACCOUNT_API (EXCEPTION)');
  END handle_account_api;

  ----------------------------------------------------------------------------------
  -- Purpose  : Updates hz_parties.  Party is initially created with account in
  --            handle_account_api.
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  ----------------------------------------------------------------------------------
  PROCEDURE update_party_api(p_acc_rec        IN OUT customer_rec,
		     x_return_message OUT VARCHAR2,
		     x_return_status  OUT VARCHAR2) IS

    t_organization_rec hz_party_v2pub.organization_rec_type;

    l_ovn            hz_parties.object_version_number%TYPE;
    l_chg_flag       VARCHAR2(1) := 'N';
    l_populated_flag VARCHAR2(1) := 'Y';
    l_msg_count      NUMBER := NULL;
    l_msg_data       VARCHAR2(2000) := NULL;
    l_data           VARCHAR2(2000) := NULL;
    l_msg_index_out  NUMBER;

    l_profile_id NUMBER;

    e_error EXCEPTION;
    e_skip  EXCEPTION;

    -- 22/04/201 Michal Tzvik CHG0034610
    l_party_rec hz_parties%ROWTYPE;
  BEGIN
    write_log('START UPDATE_PARTY_API');
    fnd_msg_pub.initialize;

    -- If object version number not populated (won't be first time through), then
    -- find it here.
    IF p_acc_rec.party_ovn IS NULL AND
       p_acc_rec.cust_organization_rec.party_rec.party_id IS NOT NULL THEN
      SELECT object_version_number
      INTO   p_acc_rec.party_ovn
      FROM   hz_parties
      WHERE  party_id = p_acc_rec.cust_organization_rec.party_rec.party_id;
    END IF;

    is_account_changed(p_acc_rec        => p_acc_rec,
	           p_type           => 'PARTY',
	           x_chg_flag       => l_chg_flag,
	           x_populated_flag => l_populated_flag,
	           x_ovn            => l_ovn);

    IF l_chg_flag = 'N' THEN
      RAISE e_skip;
    END IF;

    -- Record has changed
    IF l_ovn <> p_acc_rec.party_ovn THEN
      fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
      x_return_message := fnd_message.get;
      RAISE e_error;
    END IF;

    apps.hz_party_v2pub.update_organization(p_init_msg_list               => apps.fnd_api.g_true,
			        p_organization_rec            => p_acc_rec.cust_organization_rec,
			        p_party_object_version_number => p_acc_rec.party_ovn,
			        x_profile_id                  => l_profile_id,
			        x_return_status               => x_return_status,
			        x_msg_count                   => l_msg_count,
			        x_msg_data                    => l_msg_data);

    write_log('Return Status for party UPDATE API: ' || x_return_status);
    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'The Party UPDATE API Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END UPDATE_PARTY_API');
  EXCEPTION
    WHEN e_skip THEN
      -- Exception to skip record... not an error.
      x_return_status := fnd_api.g_ret_sts_success;
      write_log('END UPDATE_PARTY_API (E_SKIP)');
    WHEN e_error THEN
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END UPDATE_PARTY_API (E_ERROR)');
    WHEN OTHERS THEN
      x_return_message := 'Error in UPDATE_PARTY_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END UPDATE_PARTY_API (EXCEPTION)');
  END update_party_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of customer profiles at the account
  --            and site use level on the hz_customer_profiles table
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE cust_profile_api(p_profile_level        VARCHAR2,
		     p_ovn                  IN OUT hz_customer_profiles.object_version_number%TYPE,
		     p_customer_profile_rec IN OUT hz_customer_profile_v2pub.customer_profile_rec_type,
		     x_return_status        OUT VARCHAR2,
		     x_return_message       OUT VARCHAR2) IS
    l_action         VARCHAR2(15);
    l_ovn            hz_cust_site_uses.object_version_number%TYPE;
    l_chg_flag       VARCHAR2(1) := 'N';
    l_populated_flag VARCHAR2(1) := 'Y';

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;

    e_error EXCEPTION;
    e_skip  EXCEPTION;
  BEGIN
    write_log('START CUST_PROFILE_API');
    write_log('p_profile_level: ' || p_profile_level);

    fnd_msg_pub.initialize;

    is_profile_changed(p_cust_profile_rec => p_customer_profile_rec,
	           x_chg_flag         => l_chg_flag,
	           x_populated_flag   => l_populated_flag,
	           x_ovn              => l_ovn);

    IF p_customer_profile_rec.cust_account_profile_id IS NULL THEN
      l_action := 'Create';

      -- if nothing for profiles populated, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      hz_customer_profile_v2pub.create_customer_profile(p_init_msg_list           => 'T',
				        p_customer_profile_rec    => p_customer_profile_rec,
				        p_create_profile_amt      => 'F',
				        x_cust_account_profile_id => p_customer_profile_rec.cust_account_profile_id,
				        x_return_status           => x_return_status,
				        x_msg_count               => l_msg_count,
				        x_msg_data                => l_msg_data);
    ELSE
      write_log('cust_account_profile_id: ' ||
	    p_customer_profile_rec.cust_account_profile_id);

      -- if nothing for profiles changed, skip processing
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      l_action := 'Update';

      -- Record has changed
      IF l_ovn <> p_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;

      hz_customer_profile_v2pub.update_customer_profile(p_init_msg_list         => 'T',
				        p_customer_profile_rec  => p_customer_profile_rec,
				        p_object_version_number => p_ovn,
				        x_return_status         => x_return_status,
				        x_msg_count             => l_msg_count,
				        x_msg_data              => l_msg_data);
    END IF;

    write_log('Customer Profile API ' || l_action || ' return status: ' ||
	  x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'The Customer Profile ' || l_action ||
		  ' API Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END CUST_PROFILE_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END CUST_PROFILE_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END CUST_PROFILE_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in CUST_PROFILE_API_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END CUST_PROFILE_API (EXCEPTION)');
  END cust_profile_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of customer profile amounts at the account
  --            and site use level on the hz_cust_profile_amts table
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE cust_profile_amount_api(p_profile_level        VARCHAR2,
			p_ovn                  IN OUT hz_cust_profile_amts.object_version_number%TYPE,
			p_cust_profile_amt_rec IN OUT hz_customer_profile_v2pub.cust_profile_amt_rec_type,
			x_return_status        OUT VARCHAR2,
			x_return_message       OUT VARCHAR2) IS
    l_action         VARCHAR2(15);
    l_ovn            hz_cust_site_uses.object_version_number%TYPE;
    l_chg_flag       VARCHAR2(1) := 'N';
    l_populated_flag VARCHAR2(1) := 'Y';

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;

    e_error EXCEPTION;
    e_skip  EXCEPTION;
  BEGIN
    write_log('START CUST_PROFILE_AMOUNT_API');
    write_log('p_profile_level: ' || p_profile_level);

    fnd_msg_pub.initialize;

    is_profile_amt_changed(p_cust_profile_amt_rec => p_cust_profile_amt_rec,
		   x_chg_flag             => l_chg_flag,
		   x_populated_flag       => l_populated_flag,
		   x_ovn                  => l_ovn);

    IF p_cust_profile_amt_rec.cust_acct_profile_amt_id IS NULL THEN
      l_action := 'Create';

      -- if no profile amount values populated, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      hz_customer_profile_v2pub.create_cust_profile_amt(p_init_msg_list            => 'T',
				        p_cust_profile_amt_rec     => p_cust_profile_amt_rec,
				        x_cust_acct_profile_amt_id => p_cust_profile_amt_rec.cust_acct_profile_amt_id,
				        x_return_status            => x_return_status,
				        x_msg_count                => l_msg_count,
				        x_msg_data                 => l_msg_data);
    ELSE
      write_log('cust_acct_profile_amt_id: ' ||
	    p_cust_profile_amt_rec.cust_acct_profile_amt_id);

      -- If no profile amount values changed, skip processing
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      l_action := 'Update';

      -- Record has changed
      IF l_ovn <> p_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_customer_profile_v2pub.update_cust_profile_amt(p_init_msg_list         => 'T',
				        p_cust_profile_amt_rec  => p_cust_profile_amt_rec,
				        p_object_version_number => p_ovn,
				        x_return_status         => x_return_status,
				        x_msg_count             => l_msg_count,
				        x_msg_data              => l_msg_data);
    END IF;

    write_log('Customer Profile Amount API ' || l_action ||
	  ' return status: ' || x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'The Customer Profile Amount ' || l_action ||
		  ' API Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END CUST_PROFILE_AMOUNT_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END CUST_PROFILE_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END CUST_PROFILE_AMOUNT_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in CUST_PROFILE_AMOUNT_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END CUST_PROFILE_AMOUNT_API (EXCEPTION)');
  END cust_profile_amount_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance customer classifications on
  --            hz_code_assignments table
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE cust_classification_api(p_acc_rec        IN OUT customer_rec,
			x_return_status  OUT VARCHAR2,
			x_return_message OUT VARCHAR2) IS
    l_action         VARCHAR2(15);
    l_ovn            hz_cust_site_uses.object_version_number%TYPE;
    l_chg_flag       VARCHAR2(1) := 'N';
    l_populated_flag VARCHAR2(1) := 'Y';

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;

    e_error EXCEPTION;
    e_skip  EXCEPTION;
  BEGIN
    write_log('START CUST_CLASSIFICATION_API');

    fnd_msg_pub.initialize;

    is_account_changed(p_acc_rec        => p_acc_rec,
	           p_type           => 'CUST_CLASS',
	           x_chg_flag       => l_chg_flag,
	           x_populated_flag => l_populated_flag,
	           x_ovn            => l_ovn);

    IF p_acc_rec.cust_classifications_rec.code_assignment_id IS NULL THEN

      -- Constants
      p_acc_rec.cust_classifications_rec.primary_flag     := 'N';
      p_acc_rec.cust_classifications_rec.owner_table_name := 'HZ_PARTIES';
      p_acc_rec.cust_classifications_rec.owner_table_id   := p_acc_rec.cust_organization_rec.party_rec.party_id;

      l_action := 'Create';

      -- if no classification values populated, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      hz_classification_v2pub.create_code_assignment(p_init_msg_list       => fnd_api.g_true,
				     p_code_assignment_rec => p_acc_rec.cust_classifications_rec,
				     x_code_assignment_id  => p_acc_rec.cust_classifications_rec.code_assignment_id,
				     x_return_status       => x_return_status,
				     x_msg_count           => l_msg_count,
				     x_msg_data            => l_msg_data);
    ELSE
      write_log('code_assignment_id: ' ||
	    p_acc_rec.cust_classifications_rec.code_assignment_id);

      -- If no classification values changed, skip processing
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      l_action := 'Update';

      -- Record has changed
      IF l_ovn <> p_acc_rec.cust_classification_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_classification_v2pub.update_code_assignment(p_init_msg_list         => fnd_api.g_true,
				     p_code_assignment_rec   => p_acc_rec.cust_classifications_rec,
				     p_object_version_number => p_acc_rec.cust_classification_ovn,
				     x_return_status         => x_return_status,
				     x_msg_count             => l_msg_count,
				     x_msg_data              => l_msg_data);
    END IF;

    write_log('Customer Classification API ' || l_action ||
	  ' return status: ' || x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'The Customer Classification ' || l_action ||
		  ' API Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END CUST_CLASSIFICATION_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END CUST_CLASSIFICATION_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END CUST_CLASSIFICATION_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in CUST_CLASSIFICATION_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END CUST_CLASSIFICATION_API (EXCEPTION)');
  END cust_classification_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance PARTY relationships (not account)
  --            on hz_relationships table
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE party_relationship_api(p_acc_rec        IN OUT customer_rec,
		           x_return_status  OUT VARCHAR2,
		           x_return_message OUT VARCHAR2) IS
    l_action         VARCHAR2(15);
    l_ovn            hz_cust_site_uses.object_version_number%TYPE;
    l_chg_flag       VARCHAR2(1) := 'N';
    l_populated_flag VARCHAR2(1) := 'Y';

    l_relationship_role VARCHAR2(240);

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    x_party_id      hz_parties.party_id%TYPE;
    x_party_number  hz_parties.party_number%TYPE;

    e_error EXCEPTION;
    e_skip  EXCEPTION;
  BEGIN
    write_log('START PARTY_RELATIONSHIP_API');

    write_log('Relation Code:' ||
	  p_acc_rec.cust_relationship_rec.relationship_code);
    write_log('Relation Type:' ||
	  p_acc_rec.cust_relationship_rec.relationship_type);

    fnd_msg_pub.initialize;

    is_account_changed(p_acc_rec        => p_acc_rec,
	           p_type           => 'PARTY_RELATIONSHIP',
	           x_chg_flag       => l_chg_flag,
	           x_populated_flag => l_populated_flag,
	           x_ovn            => l_ovn);

    IF p_acc_rec.cust_relationship_rec.relationship_id IS NULL THEN
      IF p_acc_rec.cust_relationship_rec.relationship_type IS NOT NULL AND
         p_acc_rec.cust_relationship_rec.relationship_code IS NOT NULL THEN
        SELECT forward_rel_code
        INTO   l_relationship_role
        FROM   hz_relationship_types
        WHERE  relationship_type =
	   p_acc_rec.cust_relationship_rec.relationship_type
        AND    role = p_acc_rec.cust_relationship_rec.relationship_code;
      END IF;

      p_acc_rec.cust_relationship_rec.relationship_code := l_relationship_role;

      -- Constants
      p_acc_rec.cust_relationship_rec.subject_type       := 'ORGANIZATION';
      p_acc_rec.cust_relationship_rec.subject_table_name := 'HZ_PARTIES';
      p_acc_rec.cust_relationship_rec.object_type        := 'ORGANIZATION';
      p_acc_rec.cust_relationship_rec.object_table_name  := 'HZ_PARTIES';

      l_action := 'Create';
      write_log('Party Relation API: ' || l_action);

      -- if no classification values populated, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      hz_relationship_v2pub.create_relationship(p_init_msg_list    => fnd_api.g_true,
				p_relationship_rec => p_acc_rec.cust_relationship_rec,
				x_relationship_id  => p_acc_rec.cust_relationship_rec.relationship_id,
				x_party_id         => x_party_id,
				x_party_number     => x_party_number,
				x_return_status    => x_return_status,
				x_msg_count        => l_msg_count,
				x_msg_data         => l_msg_data);

    ELSE
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      l_action := 'Update';

      write_log('Party Relation API: ' || l_action);
      write_log('Party Relation API Update: ID ' ||
	    p_acc_rec.cust_relationship_rec.relationship_id);
      write_log('Party Relation API Update: OVN ' ||
	    p_acc_rec.cust_relationship_ovn);

      /*select relationship_code
        into l_relationship_role
        from hz_relationships
       where relationship_id = p_acc_rec.cust_relationship_rec.relationship_id;

      p_acc_rec.cust_relationship_rec.relationship_code := l_relationship_role;*/

      -- Record has changed
      IF l_ovn <> p_acc_rec.cust_relationship_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      p_acc_rec.cust_relationship_rec.object_id         := NULL;
      p_acc_rec.cust_relationship_rec.subject_id        := NULL;
      p_acc_rec.cust_relationship_rec.relationship_code := NULL;
      p_acc_rec.cust_relationship_rec.relationship_type := NULL;

      hz_relationship_v2pub.update_relationship(p_init_msg_list               => fnd_api.g_true,
				p_relationship_rec            => p_acc_rec.cust_relationship_rec,
				p_object_version_number       => p_acc_rec.cust_relationship_ovn,
				p_party_object_version_number => p_acc_rec.cust_relationship_party_ovn,
				x_return_status               => x_return_status,
				x_msg_count                   => l_msg_count,
				x_msg_data                    => l_msg_data);
    END IF;

    write_log('Party Relationship API ' || l_action || ' return status: ' ||
	  x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'The Party Relationship ' || l_action ||
		  ' API Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END PARTY_RELATIONSHIP_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END PARTY_RELATIONSHIP_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END PARTY_RELATIONSHIP_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in PARTY_RELATIONSHIP_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END PARTY_RELATIONSHIP_API (EXCEPTION)');
  END party_relationship_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance ACCOUNT relationships (not party)
  --            on hz_cust_acct_relate_all table
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE account_relationship_api(p_acc_rec        IN OUT customer_rec,
			 x_return_status  OUT VARCHAR2,
			 x_return_message OUT VARCHAR2) IS
    l_action         VARCHAR2(15);
    l_ovn            hz_cust_site_uses.object_version_number%TYPE;
    l_chg_flag       VARCHAR2(1) := 'N';
    l_populated_flag VARCHAR2(1) := 'Y';

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    x_party_id      hz_parties.party_id%TYPE;
    x_party_number  hz_parties.party_number%TYPE;

    e_error EXCEPTION;
    e_skip  EXCEPTION;
  BEGIN
    write_log('START ACCOUNT_RELATIONSHIP_API');

    fnd_msg_pub.initialize;

    is_account_changed(p_acc_rec        => p_acc_rec,
	           p_type           => 'ACCOUNT_RELATIONSHIP',
	           x_chg_flag       => l_chg_flag,
	           x_populated_flag => l_populated_flag,
	           x_ovn            => l_ovn);

    IF p_acc_rec.cust_account_relationship_rec.cust_acct_relate_id IS NULL THEN

      -- Constants
      p_acc_rec.cust_account_relationship_rec.relationship_type := 'ALL';

      l_action := 'Create';

      -- if no classification values populated, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      hz_cust_account_v2pub.create_cust_acct_relate(p_init_msg_list        => fnd_api.g_true,
				    p_cust_acct_relate_rec => p_acc_rec.cust_account_relationship_rec,
				    x_cust_acct_relate_id  => p_acc_rec.cust_account_relationship_rec.cust_acct_relate_id,
				    x_return_status        => x_return_status,
				    x_msg_count            => l_msg_count,
				    x_msg_data             => l_msg_data);

    ELSE

      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      l_action := 'Update';

      -- Record has changed
      IF l_ovn <> p_acc_rec.cust_account_relationship_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_cust_account_v2pub.update_cust_acct_relate(p_init_msg_list         => fnd_api.g_true,
				    p_cust_acct_relate_rec  => p_acc_rec.cust_account_relationship_rec,
				    p_object_version_number => p_acc_rec.cust_account_relationship_ovn,
				    x_return_status         => x_return_status,
				    x_msg_count             => l_msg_count,
				    x_msg_data              => l_msg_data);

    END IF;

    write_log('Account Relationship API ' || l_action ||
	  ' return status: ' || x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'The Account Relationship ' || l_action ||
		  ' API Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END ACCOUNT_RELATIONSHIP_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END ACCOUNT_RELATIONSHIP_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END ACCOUNT_RELATIONSHIP_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in ACCOUNT_RELATIONSHIP_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END ACCOUNT_RELATIONSHIP_API (EXCEPTION)');
  END account_relationship_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance ACCOUNT relationships (not party)
  --            on hz_cust_acct_relate_all table
  --
  --            NOTE: Currently, there is no Oracle public API to add/modify records
  --            on the ZX_REGISTRATIONS table (See Oracle Support BUG 7705696, which
  --            has had an enhancement request since 2009), however, this functionality
  --            is currently on the customer form.  In order to bring this functionality
  --            to the new form, I needed a way to add/modify this data.  I found a forum
  --            article suggesting I use the Oracle private procedures ZX_ REGISTRATIONS_PKG
  --            (CREATE_ROW/UPDATE_ROW) procedures to create/update ZX_REGISTRATION
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE party_tax_registration_api(p_acc_rec        IN OUT customer_rec,
			   x_return_status  OUT VARCHAR2,
			   x_return_message OUT VARCHAR2) IS
    l_action         VARCHAR2(15);
    l_ovn            hz_cust_site_uses.object_version_number%TYPE;
    l_chg_flag       VARCHAR2(1) := 'N';
    l_populated_flag VARCHAR2(1) := 'Y';

    l_tax_profile_id zx_party_tax_profile.party_tax_profile_id%TYPE;

    e_error EXCEPTION;
    e_skip  EXCEPTION;
  BEGIN
    write_log('START PARTY_TAX_REGISTRATION_API');

    fnd_msg_pub.initialize;

    is_account_changed(p_acc_rec        => p_acc_rec,
	           p_type           => 'PARTY_TAX_REGISTRATION',
	           x_chg_flag       => l_chg_flag,
	           x_populated_flag => l_populated_flag,
	           x_ovn            => l_ovn);

    IF p_acc_rec.cust_tax_registration.registration_id IS NULL THEN
      l_action := 'Create';

      -- if no classification values populated, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      SELECT party_tax_profile_id
      INTO   l_tax_profile_id
      FROM   zx_party_tax_profile
      WHERE  party_type_code = 'THIRD_PARTY'
      AND    party_id = p_acc_rec.cust_organization_rec.party_rec.party_id;

      write_log('l_tax_profile_id: ' || l_tax_profile_id);

      zx_registrations_pkg.insert_row(p_request_id                => NULL,
			  p_attribute1                => NULL,
			  p_attribute2                => NULL,
			  p_attribute3                => NULL,
			  p_attribute4                => NULL,
			  p_attribute5                => NULL,
			  p_attribute6                => NULL,
			  p_validation_rule           => NULL,
			  p_rounding_rule_code        => NULL,
			  p_tax_jurisdiction_code     => NULL,
			  p_self_assess_flag          => NULL,
			  p_registration_status_code  => p_acc_rec.cust_tax_registration.registration_status_code,
			  p_registration_source_code  => NULL,
			  p_registration_reason_code  => NULL,
			  p_tax                       => NULL,
			  p_tax_regime_code           => p_acc_rec.cust_tax_registration.tax_regime_code,
			  p_inclusive_tax_flag        => 'N',
			  p_effective_from            => nvl(p_acc_rec.cust_tax_registration.effective_from,
						 SYSDATE),
			  p_effective_to              => p_acc_rec.cust_tax_registration.effective_to,
			  p_rep_party_tax_name        => NULL,
			  p_default_registration_flag => 'N',
			  p_bank_account_num          => NULL,
			  p_record_type_code          => NULL,
			  p_legal_location_id         => NULL,
			  p_tax_authority_id          => NULL,
			  p_rep_tax_authority_id      => NULL,
			  p_coll_tax_authority_id     => NULL,
			  p_registration_type_code    => NULL,
			  p_registration_number       => NULL,
			  p_party_tax_profile_id      => l_tax_profile_id,
			  p_legal_registration_id     => NULL,
			  p_bank_id                   => NULL,
			  p_bank_branch_id            => NULL,
			  p_account_site_id           => NULL,
			  p_attribute14               => NULL,
			  p_attribute15               => NULL,
			  p_attribute_category        => NULL,
			  p_program_login_id          => NULL,
			  p_account_id                => NULL,
			  p_tax_classification_code   => NULL,
			  p_attribute7                => NULL,
			  p_attribute8                => NULL,
			  p_attribute9                => NULL,
			  p_attribute10               => NULL,
			  p_attribute11               => NULL,
			  p_attribute12               => NULL,
			  p_attribute13               => NULL,
			  x_return_status             => x_return_status);

    ELSE

      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      l_action := 'Update';

      -- Record has changed
      IF l_ovn <> p_acc_rec.cust_account_relationship_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      zx_registrations_pkg.update_row(p_registration_id           => p_acc_rec.cust_tax_registration.registration_id,
			  p_request_id                => NULL,
			  p_attribute1                => NULL,
			  p_attribute2                => NULL,
			  p_attribute3                => NULL,
			  p_attribute4                => NULL,
			  p_attribute5                => NULL,
			  p_attribute6                => NULL,
			  p_validation_rule           => NULL,
			  p_rounding_rule_code        => NULL,
			  p_tax_jurisdiction_code     => NULL,
			  p_self_assess_flag          => NULL,
			  p_registration_status_code  => p_acc_rec.cust_tax_registration.registration_status_code,
			  p_registration_source_code  => NULL,
			  p_registration_reason_code  => NULL,
			  p_tax                       => NULL,
			  p_tax_regime_code           => p_acc_rec.cust_tax_registration.tax_regime_code,
			  p_inclusive_tax_flag        => NULL,
			  p_effective_from            => p_acc_rec.cust_tax_registration.effective_from,
			  p_effective_to              => p_acc_rec.cust_tax_registration.effective_to,
			  p_rep_party_tax_name        => NULL,
			  p_default_registration_flag => NULL,
			  p_bank_account_num          => NULL,
			  p_record_type_code          => NULL,
			  p_legal_location_id         => NULL,
			  p_tax_authority_id          => NULL,
			  p_rep_tax_authority_id      => NULL,
			  p_coll_tax_authority_id     => NULL,
			  p_registration_type_code    => NULL,
			  p_registration_number       => NULL,
			  p_party_tax_profile_id      => NULL,
			  p_legal_registration_id     => NULL,
			  p_bank_id                   => NULL,
			  p_bank_branch_id            => NULL,
			  p_account_site_id           => NULL,
			  p_attribute14               => NULL,
			  p_attribute15               => NULL,
			  p_attribute_category        => NULL,
			  p_program_login_id          => NULL,
			  p_account_id                => NULL,
			  p_tax_classification_code   => NULL,
			  p_attribute7                => NULL,
			  p_attribute8                => NULL,
			  p_attribute9                => NULL,
			  p_attribute10               => NULL,
			  p_attribute11               => NULL,
			  p_attribute12               => NULL,
			  p_attribute13               => NULL,
			  x_return_status             => x_return_status);

    END IF;

    write_log('Party Tax Registration API ' || l_action ||
	  ' return status: ' || x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      -- The packages above do not return error messages.  They only return a status
      -- of success or failure.
      x_return_message := 'The Party Tax Registration ' || l_action ||
		  ' API Failed: ';
    END IF;

    write_log('END PARTY_TAX_REGISTRATION_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END PARTY_TAX_REGISTRATION_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END PARTY_TAX_REGISTRATION_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in PARTY_TAX_REGISTRATION_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END PARTY_TAX_REGISTRATION_API (EXCEPTION)');
  END party_tax_registration_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Looks for duplicate customers based on p_match_type.  Searching is
  --            performed based on XXHZ_CUSTOMER_DUP_CRITERIA lookup type.  p_match_type
  --            could be LIKE or EXACT.  See code below for further explanation of how the
  --            duplicate searching is built based on the lookup.
  --
  -- Change History
  -- -------------------------------------------------------------------------------
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------

  PROCEDURE find_duplicate_customers(p_dup_cust        IN OUT dup_tbl,
			 p_match_type      IN VARCHAR2 DEFAULT 'EXACT',
			 p_cust_account_id IN NUMBER,
			 p_party_name      IN VARCHAR2,
			 p_atradius_id     IN VARCHAR2,
			 p_duns_number     IN NUMBER,
			 p_tax_reference   IN VARCHAR2,
			 x_return_status   OUT VARCHAR2,
			 x_return_message  OUT VARCHAR2) IS
    l_in_dup_tbl      dup_tbl;
    l_cust_account_id NUMBER;

    l_from_where  VARCHAR2(4000);
    l_select      VARCHAR2(4000);
    l_loop_select VARCHAR2(4000);
    l_sql         VARCHAR2(4000);
    l_var         VARCHAR2(250);
    l_count       NUMBER := 0;

    -- Get join conditions for looking for duplicates
    CURSOR c_where IS
      SELECT lookup_code,
	 meaning,
	 description
      FROM   fnd_lookup_values
      WHERE  lookup_type = 'XXHZ_CUSTOMER_DUP_CRITERIA'
      AND    enabled_flag = 'Y'
      AND    LANGUAGE = userenv('LANG')
	-- Finds lookup codes that are either LIKE or EXACT depending on p_match_type
      AND    lookup_code LIKE p_match_type || '%';

    CURSOR c_dups(p_name VARCHAR2) IS
      SELECT cust_account_id,
	 NULL match_type
      FROM   xxhz_api_cust_accounts_v;

    TYPE dup_cur_typ IS REF CURSOR;
    l_dup_cur dup_cur_typ;
    l_dup_rec c_dups%ROWTYPE;

  BEGIN
    write_log('START FIND_DUPLICATE_CUSTOMERS');
    write_log('p_match_type: ' || p_match_type);
    write_log('party_name : ' || p_party_name);

    -- Need to get matching cust_account_ids.
    l_select := 'SELECT                                  ' ||
	    ' xacav.cust_account_id  cust_account_id,';

    -- Set default from/where clause
    l_from_where := 'FROM                                                         ' ||
	        '  xxhz_api_cust_accounts_v   xacav                           ' ||
	       -- Excludes current record in the event of an update
	        'WHERE xacav.cust_account_id <> ' ||
	        nvl(p_cust_account_id, -9);

    -- Append to match check where clause based on p_match_type and XXHZ_CUSTOMER_DUP_CRITERIA lookup
    FOR rec IN c_where LOOP
      -- Needs to be initialized as each LOOP through changes the join clause
      l_loop_select := NULL;
      l_var         := NULL;

      -- Set bind variable l_var depending on which field we are matching on
      IF rec.meaning LIKE '%NAME_MATCH' THEN
        l_var := p_party_name;
      ELSIF rec.meaning LIKE '%DUNS_MATCH' THEN
        l_var := p_duns_number;
      ELSIF rec.meaning LIKE '%ATRADIUS_MATCH' THEN
        l_var := p_atradius_id;
      ELSIF rec.meaning LIKE '%VAT_MATCH' THEN
        l_var := p_tax_reference;
      END IF;
      write_log('l_var: ' || l_var);

      IF l_var IS NOT NULL THEN
        -- Add match type to SELECT statement
        l_loop_select := l_select || '''' || rec.meaning || ''' ';

        write_log('rec.description: ' || rec.description);

        -- Dynamic WHERE from lookups description
        l_sql := l_loop_select || l_from_where || rec.description;

        write_log(l_sql);

        -- Open dynamically created CURSOR using l_sql
        OPEN l_dup_cur FOR l_sql
          USING l_var;

        -- Execute CURSOR to find duplicates
        LOOP
          FETCH l_dup_cur
	INTO l_dup_rec;
          EXIT WHEN l_dup_cur%NOTFOUND;

          write_log('dup cust_account_id: ' || l_dup_rec.cust_account_id);

          l_count := l_count + 1;
          p_dup_cust(l_count).id2 := l_dup_rec.cust_account_id;
          p_dup_cust(l_count).match_type := l_dup_rec.match_type;
        END LOOP;

        CLOSE l_dup_cur;
      END IF;
    END LOOP;

    write_log('p_dup_cust.COUNT: ' || p_dup_cust.count);

    -- Select other values for duplicate cust_account_ids
    FOR j IN 1 .. p_dup_cust.count LOOP
      SELECT party_id,
	 party_name,
	 party_number,
	 account_number,
	 party_duns_number,
	 atradius_id
      INTO   p_dup_cust(j).id1,
	 p_dup_cust(j).char1,
	 p_dup_cust(j).char2,
	 p_dup_cust(j).char3,
	 p_dup_cust(j).num1,
	 p_dup_cust(j).char4
      FROM   xxhz_api_cust_accounts_v
      WHERE  cust_account_id = p_dup_cust(j).id2;
    END LOOP;

    -- For duplicate checking, the return status may be 'D' if duplicates exist.
    IF l_count > 0 THEN
      x_return_status  := 'D';
      x_return_message := 'Duplicates Exist';
    ELSE
      x_return_status := fnd_api.g_ret_sts_success;
    END IF;

    write_log('x_return_status: ' || x_return_status);
    write_log('END FIND_DUPLICATE_CUSTOMERS');
  EXCEPTION
    WHEN OTHERS THEN
      x_return_message := 'Error in FIND_DUPLICATE_CUSTOMERS: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END FIND_DUPLICATE_CUSTOMERS (EXCEPTION)');
  END find_duplicate_customers;

  ----------------------------------------------------------------------------------
  -- Purpose  : Main procedure to validate, check for duplicate, and call Oracle APIs
  --            for customer related entities.
  --
  --            This is the main entry point for accounts.
  --
  -- Parameters : p_match_type
  --                This will be 'LIKE' or 'EXACT'.  Depending on how this is set, the
  --                p_dup_acct_tbl will contain records that are LIKE or and EXACT
  --                match to the customer being created/updated.
  --              p_match_only
  --                This will force the program to exit after calling
  --                find_duplicate_customers.  This is used by the find_duplicate_customers_only
  --                procedure.  handle_custom_wf and validate_account will both be
  --                called but nothing will fire for these two procedures.
  --              p_dup_acct_tbl
  --                Returns a table type of any maching customers for inbound customer
  --              x_wf_return_message
  --                If handle_custom_wf fires any of its workflows, messages from those
  --                workflows will come back in this parameter in a hyphenated concatenated
  --                string.  The form will parse those apart to popup messages to the user
  --
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET          CHG0035118. Initial creation.
  -- 11/04/2015    Dipta Chatterjee  CHG0036940 - Duplicate checking to be restricted
  --                                 for new creations only
  ----------------------------------------------------------------------------------
  PROCEDURE handle_account(p_dup_match_type    IN VARCHAR2 DEFAULT 'LIKE',
		   p_acc_rec           IN OUT customer_rec,
		   p_dup_acct_tbl      OUT dup_tbl,
		   x_return_status     OUT VARCHAR2,
		   x_return_message    OUT VARCHAR2,
		   x_wf_return_message OUT VARCHAR2) IS
    l_customer_rec xxhz_api_cust_accounts_v%ROWTYPE;
    l_site_rec     customer_site_rec;

    l_dup_accounts_tbl     dup_tbl;
    l_dup_accounts_out_obj hz_cust_acct_bo;

    l_dup_cust_tbl dup_tbl;

    x_msg_count   NUMBER;
    x_msg_data    VARCHAR2(1000);
    l_entity_code VARCHAR2(30);

    l_new_customer_flag      VARCHAR2(1) := 'N';
    l_call_prof_flag         VARCHAR2(1) := 'Y';
    l_disable_dup_check_flag VARCHAR2(1) := 'N';

    /* CHG0036940 - Dipta - Bug Fix - variable to check for new records only*/
    l_is_new_record VARCHAR2(1);
    /* END CHG0036940 - Dipta*/

    e_error EXCEPTION;
    e_skip  EXCEPTION;
  BEGIN
    write_log('START HANDLE_ACCOUNT');
    write_log('p_dup_match_type: ' || p_dup_match_type);

    mo_global.init('AR');

    -- ****************************************************************************
    -- handle checking and submitting custom workflow
    -- ****************************************************************************

    -- handle_custom_wf is called three times... once for each type of check it needs
    -- to make
    FOR i IN 1 .. 4 LOOP
      -- Need to check each of these values
      IF i = 1 THEN
        l_entity_code := 'CUST_PAY_TERM';
      ELSIF i = 2 THEN
        l_entity_code := 'CUST_CREDIT_CHK';
      ELSIF i = 3 THEN
        l_entity_code := 'CUST_CREDIT_HOLD';
      ELSIF i = 4 THEN
        l_entity_code := 'CUST_CREDIT_LIMIT';
      END IF;

      handle_custom_wf(p_acc_rec        => p_acc_rec,
	           p_site_rec       => l_site_rec,
	           p_entity_code    => l_entity_code,
	           x_return_status  => x_return_status,
	           x_return_message => x_return_message);

      write_log('handle_custom_wf return_status: ' || x_return_status);
      write_log('handle_custom_wf return_message: ' || x_return_message);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;

      -- Load return message into x_wf_return_message
      IF x_return_message IS NOT NULL THEN
        x_wf_return_message := x_wf_return_message || '~' ||
		       x_return_message;
      END IF;
    END LOOP;

    write_log('x_wf_return_message: ' || x_wf_return_message);

    -- ****************************************************************************
    -- handle account validation
    -- ****************************************************************************
    validate_account(p_acc_rec        => p_acc_rec,
	         x_return_status  => x_return_status,
	         x_return_message => x_return_message);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle looking for matching accounts
    -- ****************************************************************************

    -- Check if profile for diabling duplicate checking
    l_disable_dup_check_flag := fnd_profile.value('XXHZ_CUSTOMER_DISABLE_DUP_CHECK');
    write_log('l_disable_dup_check_flag: ' || l_disable_dup_check_flag);

    IF nvl(l_disable_dup_check_flag, 'N') = 'N' THEN
      -- Get current values to see if this is an update or create
      BEGIN
        SELECT *
        INTO   l_customer_rec
        FROM   xxhz_api_cust_accounts_v
        WHERE  cust_account_id = p_acc_rec.cust_account_rec.cust_account_id;
        /* CHG0036940 - Dipta - Bug Fix - existing records*/
        l_is_new_record := 'N';
        /* End - CHG0036940 */
      EXCEPTION
        WHEN no_data_found THEN
          /* CHG0036940 - Dipta - Bug Fix - new records only*/
          l_is_new_record := 'Y'; -- means this is a new record
        /* End - CHG0036940 */
      END;

      -- Check if one of the duplicate check match fields has changed.  If it has, we need to do duplicate check.  If
      -- not, we can skip the check.
      /* CHG0036940 - Dipta - Bug Fix - existing records*/
      IF l_is_new_record = 'Y' THEN
        /* End - CHG0036940 */
        IF is_modified(l_customer_rec.party_name,
	           p_acc_rec.cust_organization_rec.organization_name) OR
           is_modified(l_customer_rec.atradius_id,
	           p_acc_rec.cust_profile_amt_rec.attribute1) OR
           is_modified(l_customer_rec.party_duns_number,
	           p_acc_rec.cust_organization_rec.duns_number_c) OR
           is_modified(l_customer_rec.party_tax_reference,
	           p_acc_rec.cust_organization_rec.tax_reference) THEN

          find_duplicate_customers(p_dup_cust        => p_dup_acct_tbl,
		           p_match_type      => p_dup_match_type,
		           p_cust_account_id => p_acc_rec.cust_account_rec.cust_account_id,
		           p_party_name      => p_acc_rec.cust_organization_rec.organization_name,
		           p_atradius_id     => p_acc_rec.cust_profile_amt_rec.attribute1,
		           p_duns_number     => p_acc_rec.cust_organization_rec.duns_number_c,
		           p_tax_reference   => p_acc_rec.cust_organization_rec.tax_reference,
		           x_return_status   => x_return_status,
		           x_return_message  => x_return_message);

          write_log('find_duplicate_customers x_return_status: ' ||
	        x_return_status);
        END IF;
        /* CHG0036940 - Dipta - Bug Fix - existing records*/
      END IF;
      /* End - CHG0036940 */
    END IF;

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    write_log('p_acc_rec.cust_account_rec.cust_account_id: ' ||
	  p_acc_rec.cust_account_rec.cust_account_id);

    -- ****************************************************************************
    -- handle accounts
    -- ****************************************************************************
    handle_account_api(p_ovn            => p_acc_rec.acct_ovn,
	           p_acc_rec        => p_acc_rec,
	           x_call_prof_flag => l_call_prof_flag,
	           x_return_status  => x_return_status,
	           x_return_message => x_return_message);

    write_log('cust_account_api return_status: ' || x_return_status);
    write_log('cust_account_id: ' ||
	  p_acc_rec.cust_account_rec.cust_account_id);
    write_log('party_id: ' ||
	  p_acc_rec.cust_organization_rec.party_rec.party_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle party
    -- ****************************************************************************
    update_party_api(p_acc_rec        => p_acc_rec,
	         x_return_message => x_return_message,
	         x_return_status  => x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle cust profiles
    -- ****************************************************************************
    -- If profile and profile amount were created by customer creation account API, l_call_prof_flag = N
    -- and we will not call profile and profile amount APIs.
    write_log('l_call_prof_flag: ' || l_call_prof_flag);
    IF l_call_prof_flag = 'Y' THEN
      IF p_acc_rec.cust_profile_rec.cust_account_id IS NULL THEN
        p_acc_rec.cust_profile_rec.cust_account_id := p_acc_rec.cust_account_rec.cust_account_id;
      END IF;

      cust_profile_api(p_profile_level        => 'CUSTOMER',
	           p_ovn                  => p_acc_rec.cust_profile_ovn,
	           p_customer_profile_rec => p_acc_rec.cust_profile_rec,
	           x_return_status        => x_return_status,
	           x_return_message       => x_return_message);

      write_log('cust_profile_api return_status: ' || x_return_status);
      write_log('cust_account_profile_id: ' ||
	    p_acc_rec.cust_profile_rec.cust_account_profile_id);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;

      -- ****************************************************************************
      -- handle cust profile amounts
      -- ****************************************************************************
      IF p_acc_rec.cust_profile_amt_rec.cust_acct_profile_amt_id IS NULL THEN
        p_acc_rec.cust_profile_amt_rec.cust_account_profile_id := p_acc_rec.cust_profile_rec.cust_account_profile_id;
        p_acc_rec.cust_profile_amt_rec.cust_account_id         := p_acc_rec.cust_account_rec.cust_account_id;
      END IF;

      cust_profile_amount_api(p_profile_level        => 'CUSTOMER',
		      p_ovn                  => p_acc_rec.cust_profile_amt_ovn,
		      p_cust_profile_amt_rec => p_acc_rec.cust_profile_amt_rec,
		      x_return_status        => x_return_status,
		      x_return_message       => x_return_message);

      write_log('cust_profile_amount_api return_status: ' ||
	    x_return_status);
      write_log('cust_acct_profile_amt_id: ' ||
	    p_acc_rec.cust_profile_amt_rec.cust_acct_profile_amt_id);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;
    END IF;

    -- ****************************************************************************
    -- handle cust classifications
    -- ****************************************************************************

    cust_classification_api(p_acc_rec        => p_acc_rec,
		    x_return_message => x_return_message,
		    x_return_status  => x_return_status);

    write_log('cust_classification_api return_status: ' || x_return_status);
    write_log('cust_classification_id: ' ||
	  p_acc_rec.cust_classifications_rec.code_assignment_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle party relationships
    -- ****************************************************************************
    party_relationship_api(p_acc_rec        => p_acc_rec,
		   x_return_message => x_return_message,
		   x_return_status  => x_return_status);

    write_log('party_relationship_api return_status: ' || x_return_status);
    write_log('party_relationship_api: ' ||
	  p_acc_rec.cust_relationship_rec.relationship_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle account relationships
    -- ****************************************************************************
    account_relationship_api(p_acc_rec        => p_acc_rec,
		     x_return_message => x_return_message,
		     x_return_status  => x_return_status);

    write_log('account_relationship_api return_status: ' ||
	  x_return_status);
    write_log('account_relationship_api: ' ||
	  p_acc_rec.cust_account_relationship_rec.cust_acct_relate_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle party tax registration
    -- ****************************************************************************
    party_tax_registration_api(p_acc_rec        => p_acc_rec,
		       x_return_message => x_return_message,
		       x_return_status  => x_return_status);

    write_log('party_tax_registration_api return_status: ' ||
	  x_return_status);
    write_log('party_tax_registration_api: ' ||
	  p_acc_rec.cust_tax_registration.registration_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    write_log('END HANDLE_ACCOUNT');
  EXCEPTION
    WHEN e_skip THEN
      -- This is not an error condition... it allows us to skip processing.  SFDC requirements for
      -- CHG0035118 are only to call find_duplicates.  We will do that step and skip processing of
      -- the rest of this procedure.  However, it will be easy to turn this on and off.
      write_log('END HANDLE_ACCOUNT (E_SKIP)');
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END HANDLE_ACCOUNT (E_EXCEPTION)');
    WHEN OTHERS THEN
      x_return_message := 'Error in ' || g_program_unit || ': ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END HANDLE_ACCOUNT (EXCEPTION)');
  END handle_account;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Function used to load from a frm_customer_rec type to a customer_rec_type,
  --            which contains the proper record types for use by Oracle's APIs.  This is
  --            necessary because the standard hz_party_v2pub.organization_rec_type and
  --            hz_classification_v2pub.code_assignment_rec_type contain global variables,
  --            which cause the form to error.  Because of this, I needed to create my
  --            own form specific record types of these for use with the XXHZCUSTOMER.fmb
  --            form.  I then need to load the form specific record types into Oracle's
  --            standard record types for ease of processing by the Oracle APIs.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------
  FUNCTION load_customer_rec(p_frm_customer_rec IN frm_customer_rec)
    RETURN customer_rec IS
    x_customer_rec customer_rec;
  BEGIN
    write_log('START LOAD_CUSTOMER_REC');

    -- Set form object version number to Oracle standard record type
    x_customer_rec.party_ovn                     := p_frm_customer_rec.party_ovn;
    x_customer_rec.acct_ovn                      := p_frm_customer_rec.acct_ovn;
    x_customer_rec.cust_profile_ovn              := p_frm_customer_rec.cust_profile_ovn;
    x_customer_rec.cust_profile_amt_ovn          := p_frm_customer_rec.cust_profile_amt_ovn;
    x_customer_rec.cust_classification_ovn       := p_frm_customer_rec.cust_classification_ovn;
    x_customer_rec.cust_relationship_ovn         := p_frm_customer_rec.cust_relationship_ovn;
    x_customer_rec.cust_relationship_party_ovn   := p_frm_customer_rec.cust_relationship_party_ovn;
    x_customer_rec.cust_account_relationship_ovn := p_frm_customer_rec.cust_account_relationship_ovn;
    x_customer_rec.cust_tax_registration_ovn     := p_frm_customer_rec.cust_tax_registration_ovn;

    -- Set form record types to Oracle standard record types
    x_customer_rec.cust_account_rec              := p_frm_customer_rec.cust_account_rec;
    x_customer_rec.cust_profile_rec              := p_frm_customer_rec.cust_profile_rec;
    x_customer_rec.cust_profile_amt_rec          := p_frm_customer_rec.cust_profile_amt_rec;
    x_customer_rec.cust_account_relationship_rec := p_frm_customer_rec.cust_account_relationship_rec;
    x_customer_rec.cust_tax_registration         := p_frm_customer_rec.cust_tax_registration;

    -- Organizations
    x_customer_rec.cust_organization_rec.party_rec.party_id         := p_frm_customer_rec.cust_organization_rec.party_id;
    x_customer_rec.cust_organization_rec.party_rec.party_number     := p_frm_customer_rec.cust_organization_rec.party_number;
    x_customer_rec.cust_organization_rec.party_rec.status           := p_frm_customer_rec.cust_organization_rec.party_status;
    x_customer_rec.cust_organization_rec.organization_name          := p_frm_customer_rec.cust_organization_rec.organization_name;
    x_customer_rec.cust_organization_rec.organization_name_phonetic := p_frm_customer_rec.cust_organization_rec.organization_name_phonetic;
    x_customer_rec.cust_organization_rec.party_rec.category_code    := p_frm_customer_rec.cust_organization_rec.category_code;
    x_customer_rec.cust_organization_rec.duns_number_c              := p_frm_customer_rec.cust_organization_rec.duns_number_c;
    x_customer_rec.cust_organization_rec.tax_reference              := p_frm_customer_rec.cust_organization_rec.tax_reference;
    x_customer_rec.cust_organization_rec.jgzz_fiscal_code           := p_frm_customer_rec.cust_organization_rec.jgzz_fiscal_code;
    x_customer_rec.cust_organization_rec.known_as                   := p_frm_customer_rec.cust_organization_rec.known_as;
    x_customer_rec.cust_organization_rec.party_rec.attribute1       := p_frm_customer_rec.cust_organization_rec.attribute1;
    x_customer_rec.cust_organization_rec.party_rec.attribute2       := p_frm_customer_rec.cust_organization_rec.attribute2;
    x_customer_rec.cust_organization_rec.party_rec.attribute3       := p_frm_customer_rec.cust_organization_rec.attribute3;
    x_customer_rec.cust_organization_rec.party_rec.attribute4       := p_frm_customer_rec.cust_organization_rec.attribute4;
    x_customer_rec.cust_organization_rec.party_rec.attribute5       := p_frm_customer_rec.cust_organization_rec.attribute5;
    x_customer_rec.cust_organization_rec.party_rec.attribute6       := p_frm_customer_rec.cust_organization_rec.attribute6;
    x_customer_rec.cust_organization_rec.party_rec.attribute7       := p_frm_customer_rec.cust_organization_rec.attribute7;
    x_customer_rec.cust_organization_rec.party_rec.attribute8       := p_frm_customer_rec.cust_organization_rec.attribute8;
    x_customer_rec.cust_organization_rec.party_rec.attribute9       := p_frm_customer_rec.cust_organization_rec.attribute9;
    x_customer_rec.cust_organization_rec.party_rec.attribute10      := p_frm_customer_rec.cust_organization_rec.attribute10;
    x_customer_rec.cust_organization_rec.party_rec.attribute11      := p_frm_customer_rec.cust_organization_rec.attribute11;
    x_customer_rec.cust_organization_rec.party_rec.attribute12      := p_frm_customer_rec.cust_organization_rec.attribute12;
    x_customer_rec.cust_organization_rec.party_rec.attribute13      := p_frm_customer_rec.cust_organization_rec.attribute13;
    x_customer_rec.cust_organization_rec.party_rec.attribute14      := p_frm_customer_rec.cust_organization_rec.attribute14;
    x_customer_rec.cust_organization_rec.party_rec.attribute15      := p_frm_customer_rec.cust_organization_rec.attribute15;
    x_customer_rec.cust_organization_rec.party_rec.attribute16      := p_frm_customer_rec.cust_organization_rec.attribute16;
    x_customer_rec.cust_organization_rec.party_rec.attribute17      := p_frm_customer_rec.cust_organization_rec.attribute17;
    x_customer_rec.cust_organization_rec.party_rec.attribute18      := p_frm_customer_rec.cust_organization_rec.attribute18;
    x_customer_rec.cust_organization_rec.party_rec.attribute19      := p_frm_customer_rec.cust_organization_rec.attribute19;
    x_customer_rec.cust_organization_rec.party_rec.attribute20      := p_frm_customer_rec.cust_organization_rec.attribute20;

    -- Classifications
    x_customer_rec.cust_classifications_rec.code_assignment_id    := p_frm_customer_rec.cust_classifications_rec.code_assignment_id;
    x_customer_rec.cust_classifications_rec.owner_table_name      := p_frm_customer_rec.cust_classifications_rec.owner_table_name;
    x_customer_rec.cust_classifications_rec.owner_table_id        := p_frm_customer_rec.cust_classifications_rec.owner_table_id;
    x_customer_rec.cust_classifications_rec.owner_table_key_1     := p_frm_customer_rec.cust_classifications_rec.owner_table_key_1;
    x_customer_rec.cust_classifications_rec.owner_table_key_2     := p_frm_customer_rec.cust_classifications_rec.owner_table_key_2;
    x_customer_rec.cust_classifications_rec.owner_table_key_3     := p_frm_customer_rec.cust_classifications_rec.owner_table_key_3;
    x_customer_rec.cust_classifications_rec.owner_table_key_4     := p_frm_customer_rec.cust_classifications_rec.owner_table_key_4;
    x_customer_rec.cust_classifications_rec.owner_table_key_5     := p_frm_customer_rec.cust_classifications_rec.owner_table_key_5;
    x_customer_rec.cust_classifications_rec.class_category        := p_frm_customer_rec.cust_classifications_rec.class_category;
    x_customer_rec.cust_classifications_rec.class_code            := p_frm_customer_rec.cust_classifications_rec.class_code;
    x_customer_rec.cust_classifications_rec.primary_flag          := p_frm_customer_rec.cust_classifications_rec.primary_flag;
    x_customer_rec.cust_classifications_rec.content_source_type   := p_frm_customer_rec.cust_classifications_rec.content_source_type;
    x_customer_rec.cust_classifications_rec.start_date_active     := p_frm_customer_rec.cust_classifications_rec.start_date_active;
    x_customer_rec.cust_classifications_rec.end_date_active       := p_frm_customer_rec.cust_classifications_rec.end_date_active;
    x_customer_rec.cust_classifications_rec.status                := p_frm_customer_rec.cust_classifications_rec.status;
    x_customer_rec.cust_classifications_rec.created_by_module     := p_frm_customer_rec.cust_classifications_rec.created_by_module;
    x_customer_rec.cust_classifications_rec.rank                  := p_frm_customer_rec.cust_classifications_rec.rank;
    x_customer_rec.cust_classifications_rec.application_id        := p_frm_customer_rec.cust_classifications_rec.application_id;
    x_customer_rec.cust_classifications_rec.actual_content_source := p_frm_customer_rec.cust_classifications_rec.actual_content_source;

    -- Party Relationships
    x_customer_rec.cust_relationship_rec.relationship_id    := p_frm_customer_rec.cust_relationship_rec.relationship_id;
    x_customer_rec.cust_relationship_rec.party_rec.party_id := p_frm_customer_rec.cust_relationship_rec.relationship_party_id;
    x_customer_rec.cust_relationship_rec.subject_id         := p_frm_customer_rec.cust_relationship_rec.subject_id;
    x_customer_rec.cust_relationship_rec.object_id          := p_frm_customer_rec.cust_relationship_rec.object_id;
    x_customer_rec.cust_relationship_rec.status             := p_frm_customer_rec.cust_relationship_rec.status;
    x_customer_rec.cust_relationship_rec.comments           := p_frm_customer_rec.cust_relationship_rec.comments;
    x_customer_rec.cust_relationship_rec.start_date         := p_frm_customer_rec.cust_relationship_rec.start_date;
    x_customer_rec.cust_relationship_rec.end_date           := p_frm_customer_rec.cust_relationship_rec.end_date;
    x_customer_rec.cust_relationship_rec.relationship_code  := p_frm_customer_rec.cust_relationship_rec.relationship_code;
    x_customer_rec.cust_relationship_rec.relationship_type  := p_frm_customer_rec.cust_relationship_rec.relationship_type;
    x_customer_rec.cust_relationship_rec.created_by_module  := p_frm_customer_rec.cust_relationship_rec.created_by_module;

    write_log('END LOAD_CUSTOMER_REC');
    RETURN x_customer_rec;
  EXCEPTION
    WHEN OTHERS THEN
      write_log('END LLOAD_CUSTOMER_REC (EXCEPTION)');
      RAISE;
  END load_customer_rec;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Function used to load from Oracle's standard customer record types
  --            in customer_rec to the form specific record type frm_customer_rec
  --            to pass values back to the form.  This is the opposite of the
  --            procedure above.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------
  FUNCTION load_customer_rec(p_customer_rec IN customer_rec)
    RETURN frm_customer_rec IS
    x_customer_rec frm_customer_rec;
  BEGIN
    write_log('START LOAD_CUSTOMER_REC');

    -- Set form object version number to Oracle standard record type
    x_customer_rec.party_ovn                     := p_customer_rec.party_ovn;
    x_customer_rec.acct_ovn                      := p_customer_rec.acct_ovn;
    x_customer_rec.cust_profile_ovn              := p_customer_rec.cust_profile_ovn;
    x_customer_rec.cust_profile_amt_ovn          := p_customer_rec.cust_profile_amt_ovn;
    x_customer_rec.cust_classification_ovn       := p_customer_rec.cust_classification_ovn;
    x_customer_rec.cust_relationship_ovn         := p_customer_rec.cust_relationship_ovn;
    x_customer_rec.cust_relationship_party_ovn   := p_customer_rec.cust_relationship_party_ovn;
    x_customer_rec.cust_account_relationship_ovn := p_customer_rec.cust_account_relationship_ovn;
    x_customer_rec.cust_tax_registration_ovn     := p_customer_rec.cust_tax_registration_ovn;

    -- Set form record types to Oracle standard record types
    x_customer_rec.cust_account_rec              := p_customer_rec.cust_account_rec;
    x_customer_rec.cust_profile_rec              := p_customer_rec.cust_profile_rec;
    x_customer_rec.cust_profile_amt_rec          := p_customer_rec.cust_profile_amt_rec;
    x_customer_rec.cust_account_relationship_rec := p_customer_rec.cust_account_relationship_rec;
    x_customer_rec.cust_tax_registration         := p_customer_rec.cust_tax_registration;

    -- Organizations
    x_customer_rec.cust_organization_rec.party_id                   := p_customer_rec.cust_organization_rec.party_rec.party_id;
    x_customer_rec.cust_organization_rec.party_number               := p_customer_rec.cust_organization_rec.party_rec.party_number;
    x_customer_rec.cust_organization_rec.party_status               := p_customer_rec.cust_organization_rec.party_rec.status;
    x_customer_rec.cust_organization_rec.organization_name          := p_customer_rec.cust_organization_rec.organization_name;
    x_customer_rec.cust_organization_rec.organization_name_phonetic := p_customer_rec.cust_organization_rec.organization_name_phonetic;
    x_customer_rec.cust_organization_rec.category_code              := p_customer_rec.cust_organization_rec.party_rec.category_code;
    x_customer_rec.cust_organization_rec.duns_number_c              := p_customer_rec.cust_organization_rec.duns_number_c;
    x_customer_rec.cust_organization_rec.tax_reference              := p_customer_rec.cust_organization_rec.tax_reference;
    x_customer_rec.cust_organization_rec.jgzz_fiscal_code           := p_customer_rec.cust_organization_rec.jgzz_fiscal_code;
    x_customer_rec.cust_organization_rec.known_as                   := p_customer_rec.cust_organization_rec.known_as;
    x_customer_rec.cust_organization_rec.attribute1                 := p_customer_rec.cust_organization_rec.party_rec.attribute1;
    x_customer_rec.cust_organization_rec.attribute2                 := p_customer_rec.cust_organization_rec.party_rec.attribute2;
    x_customer_rec.cust_organization_rec.attribute3                 := p_customer_rec.cust_organization_rec.party_rec.attribute3;
    x_customer_rec.cust_organization_rec.attribute4                 := p_customer_rec.cust_organization_rec.party_rec.attribute4;
    x_customer_rec.cust_organization_rec.attribute5                 := p_customer_rec.cust_organization_rec.party_rec.attribute5;
    x_customer_rec.cust_organization_rec.attribute6                 := p_customer_rec.cust_organization_rec.party_rec.attribute6;
    x_customer_rec.cust_organization_rec.attribute7                 := p_customer_rec.cust_organization_rec.party_rec.attribute7;
    x_customer_rec.cust_organization_rec.attribute8                 := p_customer_rec.cust_organization_rec.party_rec.attribute8;
    x_customer_rec.cust_organization_rec.attribute9                 := p_customer_rec.cust_organization_rec.party_rec.attribute9;
    x_customer_rec.cust_organization_rec.attribute10                := p_customer_rec.cust_organization_rec.party_rec.attribute10;
    x_customer_rec.cust_organization_rec.attribute11                := p_customer_rec.cust_organization_rec.party_rec.attribute11;
    x_customer_rec.cust_organization_rec.attribute12                := p_customer_rec.cust_organization_rec.party_rec.attribute12;
    x_customer_rec.cust_organization_rec.attribute13                := p_customer_rec.cust_organization_rec.party_rec.attribute13;
    x_customer_rec.cust_organization_rec.attribute14                := p_customer_rec.cust_organization_rec.party_rec.attribute14;
    x_customer_rec.cust_organization_rec.attribute15                := p_customer_rec.cust_organization_rec.party_rec.attribute15;
    x_customer_rec.cust_organization_rec.attribute16                := p_customer_rec.cust_organization_rec.party_rec.attribute16;
    x_customer_rec.cust_organization_rec.attribute17                := p_customer_rec.cust_organization_rec.party_rec.attribute17;
    x_customer_rec.cust_organization_rec.attribute18                := p_customer_rec.cust_organization_rec.party_rec.attribute18;
    x_customer_rec.cust_organization_rec.attribute19                := p_customer_rec.cust_organization_rec.party_rec.attribute19;
    x_customer_rec.cust_organization_rec.attribute20                := p_customer_rec.cust_organization_rec.party_rec.attribute20;

    -- Classifications
    x_customer_rec.cust_classifications_rec.code_assignment_id    := p_customer_rec.cust_classifications_rec.code_assignment_id;
    x_customer_rec.cust_classifications_rec.owner_table_name      := p_customer_rec.cust_classifications_rec.owner_table_name;
    x_customer_rec.cust_classifications_rec.owner_table_id        := p_customer_rec.cust_classifications_rec.owner_table_id;
    x_customer_rec.cust_classifications_rec.owner_table_key_1     := p_customer_rec.cust_classifications_rec.owner_table_key_1;
    x_customer_rec.cust_classifications_rec.owner_table_key_2     := p_customer_rec.cust_classifications_rec.owner_table_key_2;
    x_customer_rec.cust_classifications_rec.owner_table_key_3     := p_customer_rec.cust_classifications_rec.owner_table_key_3;
    x_customer_rec.cust_classifications_rec.owner_table_key_4     := p_customer_rec.cust_classifications_rec.owner_table_key_4;
    x_customer_rec.cust_classifications_rec.owner_table_key_5     := p_customer_rec.cust_classifications_rec.owner_table_key_5;
    x_customer_rec.cust_classifications_rec.class_category        := p_customer_rec.cust_classifications_rec.class_category;
    x_customer_rec.cust_classifications_rec.class_code            := p_customer_rec.cust_classifications_rec.class_code;
    x_customer_rec.cust_classifications_rec.primary_flag          := p_customer_rec.cust_classifications_rec.primary_flag;
    x_customer_rec.cust_classifications_rec.content_source_type   := p_customer_rec.cust_classifications_rec.content_source_type;
    x_customer_rec.cust_classifications_rec.start_date_active     := p_customer_rec.cust_classifications_rec.start_date_active;
    x_customer_rec.cust_classifications_rec.end_date_active       := p_customer_rec.cust_classifications_rec.end_date_active;
    x_customer_rec.cust_classifications_rec.status                := p_customer_rec.cust_classifications_rec.status;
    x_customer_rec.cust_classifications_rec.created_by_module     := p_customer_rec.cust_classifications_rec.created_by_module;
    x_customer_rec.cust_classifications_rec.rank                  := p_customer_rec.cust_classifications_rec.rank;
    x_customer_rec.cust_classifications_rec.application_id        := p_customer_rec.cust_classifications_rec.application_id;
    x_customer_rec.cust_classifications_rec.actual_content_source := p_customer_rec.cust_classifications_rec.actual_content_source;

    -- Party Relationships
    x_customer_rec.cust_relationship_rec.relationship_id       := p_customer_rec.cust_relationship_rec.relationship_id;
    x_customer_rec.cust_relationship_rec.relationship_party_id := p_customer_rec.cust_relationship_rec.party_rec.party_id;
    x_customer_rec.cust_relationship_rec.subject_id            := p_customer_rec.cust_relationship_rec.subject_id;
    x_customer_rec.cust_relationship_rec.object_id             := p_customer_rec.cust_relationship_rec.object_id;
    x_customer_rec.cust_relationship_rec.status                := p_customer_rec.cust_relationship_rec.status;
    x_customer_rec.cust_relationship_rec.comments              := p_customer_rec.cust_relationship_rec.comments;
    x_customer_rec.cust_relationship_rec.start_date            := p_customer_rec.cust_relationship_rec.start_date;
    x_customer_rec.cust_relationship_rec.end_date              := p_customer_rec.cust_relationship_rec.end_date;
    x_customer_rec.cust_relationship_rec.relationship_code     := p_customer_rec.cust_relationship_rec.relationship_code;
    x_customer_rec.cust_relationship_rec.relationship_type     := p_customer_rec.cust_relationship_rec.relationship_type;
    x_customer_rec.cust_relationship_rec.created_by_module     := p_customer_rec.cust_relationship_rec.created_by_module;

    write_log('END LOAD_CUSTOMER_REC');
    RETURN x_customer_rec;
  EXCEPTION
    WHEN OTHERS THEN
      write_log('END LLOAD_CUSTOMER_REC (EXCEPTION)');
      RAISE;
  END load_customer_rec;

  ----------------------------------------------------------------------------------
  -- Purpose  : Wrapper procedure to handle_account for customer data from
  --            XXHZCUSTOMER.FMB.  Unfortunately, the form has issues with record
  --            types that use global variables, as is the case with the
  --            hz_party_v2pub.organization_rec_type and
  --            hz_classification_v2pub.code_assignment_rec_type.  Because of this, I've
  --            created custom versions of these record types, then wrapped it in the
  --            frm_customer_rec record type.  We then take data from this record type
  --            and put it into the customer_rec record type, which uses Oracle's
  --            standard record types with it's APIs.  After processing, we move the
  --            data from the standard customer_rec type back to the frm_customer_rec
  --            record type.
  --
  --            For further explanation of other parameters, please see Parameters
  --            section of comments for handle_account procedure.
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  ----------------------------------------------------------------------------------
  PROCEDURE frm_handle_account(p_dup_match_type    IN VARCHAR2 DEFAULT 'LIKE',
		       p_acc_rec           IN OUT frm_customer_rec,
		       p_dup_acct_tbl      OUT dup_tbl,
		       x_return_status     OUT VARCHAR2,
		       x_return_message    OUT VARCHAR2,
		       x_wf_return_message OUT VARCHAR2) IS
    t_customer_rec     customer_rec;
    t_organization_rec hz_party_v2pub.organization_rec_type;
  BEGIN
    write_log('START HANDLE_ACCOUNT');

    -- Assign frm rec to Oracle rec for use with Oracle APIs
    t_customer_rec := load_customer_rec(p_acc_rec);

    -- **********************************************************************
    -- Call main customer procedure
    -- *********************************************************************

    handle_account(p_dup_match_type    => p_dup_match_type,
	       p_acc_rec           => t_customer_rec,
	       p_dup_acct_tbl      => p_dup_acct_tbl,
	       x_return_status     => x_return_status,
	       x_return_message    => x_return_message,
	       x_wf_return_message => x_wf_return_message);

    -- Assign Oracle rec to form rec for use with XXHZCUSTOMER.fmb
    p_acc_rec := load_customer_rec(t_customer_rec);

    write_log('Return Status from handle_account: ' || x_return_status);
    write_log('END FRM_HANDLE_ACCOUNT');
  EXCEPTION
    WHEN OTHERS THEN
      x_return_message := 'Error in FFRM_HANDLE_ACCOUNT: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END FRM_HANDLE_ACCOUNT (EXCEPTION)');
  END frm_handle_account;

  -- -------------------------------------------------------------------------------
  -- Purpose  : This procedure is meant to be called from external systems.  This will
  --            be wrapped in a web service and called from that web service.  Two calls
  --            should be made to this procedure.
  --
  --            Call 1 with p_dup_check = 'Y'.  When the calling program attempts to
  --            create/update a customer, the program will look for LIKE customers.  If
  --            it finds any, it will return them in the p_dup_org_cust_tbl collection.
  --
  --            Call 2 with p_dup_check = 'N'.  If the calling program chooses to ignore
  --            the LIKE customers, they can then call with p_dup_check = 'N'.  This will
  --            return any exact customer matches in the p_dup_org_cust_tbl collection.
  --            They will NOT be able to UPSERT customers with exact matches.
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE handle_account_obj_api(p_dup_match_type    IN VARCHAR2 DEFAULT 'LIKE',
		           p_org_cust_tbl      IN OUT hz_org_cust_bo_tbl,
		           p_error_tbl         OUT xxssys_error_tbl,
		           p_dup_org_cust_tbl  OUT hz_org_cust_bo_tbl,
		           x_return_status     OUT VARCHAR2,
		           x_return_message    OUT VARCHAR2,
		           x_wf_return_message OUT VARCHAR2) IS
    -- Rec types
    t_cust_account_rec     hz_cust_account_v2pub.cust_account_rec_type;
    t_organization_rec     hz_party_v2pub.organization_rec_type; --hz_party_v2pub.organization_rec_type;
    t_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;
    t_customer_rec         xxhz_api_pkg.customer_rec;

    -- Table Types
    l_dup_org_cust_obj hz_org_cust_bo;
    l_dup_acct_tbl     dup_tbl;

    -- Vars
    l_count             NUMBER := 0;
    l_return_status     VARCHAR2(1);
    l_return_message    VARCHAR2(4000);
    l_wf_return_message VARCHAR2(4000);

    x_msg_count               NUMBER;
    x_msg_data                VARCHAR2(1000);
    l_current_duplicate_count NUMBER := 0;
    l_party_ovn               hz_parties.object_version_number%TYPE;
    l_acct_ovn                hz_cust_accounts_all.object_version_number%TYPE;

    -- Exceptions
    e_error EXCEPTION;
  BEGIN
    g_program_unit := 'HANDLE_ACCOUNT_OBJ_API';
    write_log('START ' || g_program_unit);
    write_log('p_dup_match_type: ' || p_dup_match_type);

    -- Initialize table types
    p_error_tbl        := xxssys_error_tbl();
    p_dup_org_cust_tbl := hz_org_cust_bo_tbl();

    -- Initialize to success.  Will be overwritten in case of error.
    x_return_status := fnd_api.g_ret_sts_success;

    -- Loop through org_cust_tbl records
    FOR i IN 1 .. p_org_cust_tbl.count LOOP
      BEGIN
        l_return_status  := fnd_api.g_ret_sts_success;
        l_return_message := NULL;

        write_log('****** BEGIN PROCESSING RECORD # ' || i || ' *******');
        -- Populate common_obj_id on both org_cust_tbl and error_tbl, so they can be linked together by calling program
        p_org_cust_tbl(i).account_objs(1).common_obj_id := i;
        t_organization_rec.organization_name := p_org_cust_tbl(i)
				.organization_obj.organization_name;

        -- Assign p_cust_acct_tbl values to rec values for use with hz account APIs.
        t_cust_account_rec.account_name := p_org_cust_tbl(i).account_objs(1)
			       .account_name;
        /*
                --t_cust_account_rec.date_type_preference       := 'ARRIVAL';
                t_cust_account_rec.account_number             := p_org_cust_tbl(i).account_objs(1).account_number;
                t_cust_account_rec.sales_channel_code         := p_org_cust_tbl(i).account_objs(1).sales_channel_code;
                t_cust_account_rec.created_by_module          := p_org_cust_tbl(i).account_objs(1).orig_system;
                t_cust_account_rec.attribute4                 := p_org_cust_tbl(i).account_objs(1).attribute4;
                t_cust_account_rec.attribute_category         := p_org_cust_tbl(i).account_objs(1).attribute_category;
                t_cust_account_rec.attribute1                 := p_org_cust_tbl(i).account_objs(1).attribute1;
                t_cust_account_rec.attribute2                 := p_org_cust_tbl(i).account_objs(1).attribute2;
                t_cust_account_rec.attribute3                 := p_org_cust_tbl(i).account_objs(1).attribute3;
                t_cust_account_rec.attribute4                 := p_org_cust_tbl(i).account_objs(1).attribute4;
                t_cust_account_rec.attribute5                 := p_org_cust_tbl(i).account_objs(1).attribute5;
                t_cust_account_rec.attribute6                 := p_org_cust_tbl(i).account_objs(1).attribute6;
                t_cust_account_rec.attribute7                 := p_org_cust_tbl(i).account_objs(1).attribute7;
                t_cust_account_rec.attribute8                 := p_org_cust_tbl(i).account_objs(1).attribute8;
                t_cust_account_rec.attribute9                 := p_org_cust_tbl(i).account_objs(1).attribute9;
                t_cust_account_rec.attribute10                := p_org_cust_tbl(i).account_objs(1).attribute10;
                t_cust_account_rec.attribute11                := p_org_cust_tbl(i).account_objs(1).attribute11;
                t_cust_account_rec.attribute12                := p_org_cust_tbl(i).account_objs(1).attribute12;
                t_cust_account_rec.attribute13                := p_org_cust_tbl(i).account_objs(1).attribute13;
                t_cust_account_rec.attribute14                := p_org_cust_tbl(i).account_objs(1).attribute14;
                t_cust_account_rec.attribute15                := p_org_cust_tbl(i).account_objs(1).attribute15;
                t_cust_account_rec.attribute16                := p_org_cust_tbl(i).account_objs(1).attribute16;
                t_cust_account_rec.attribute17                := p_org_cust_tbl(i).account_objs(1).attribute17;
                t_cust_account_rec.attribute18                := p_org_cust_tbl(i).account_objs(1).attribute18;
                t_cust_account_rec.attribute19                := p_org_cust_tbl(i).account_objs(1).attribute19;
                t_cust_account_rec.attribute20                := p_org_cust_tbl(i).account_objs(1).attribute20;
                t_cust_account_rec.status                     := nvl(p_org_cust_tbl(i).account_objs(1).status, 'A');
        */
        t_customer_rec.cust_account_rec      := t_cust_account_rec;
        t_customer_rec.cust_organization_rec := t_organization_rec;

        -- Get object version numbers to check for record changes during update

        l_party_ovn := get_object_version_number('PARTY',
				 t_organization_rec.party_rec.party_id);
        write_log('l_party_ovn: ' || l_party_ovn);

        l_acct_ovn := get_object_version_number('ACCOUNT',
				t_cust_account_rec.cust_account_id);
        write_log('l_acct_ovn: ' || l_acct_ovn);

        -- **********************************************************************
        -- Call main customer procedure
        -- **********************************************************************
        handle_account(p_dup_match_type    => p_dup_match_type,
	           p_acc_rec           => t_customer_rec,
	           p_dup_acct_tbl      => l_dup_acct_tbl,
	           x_return_status     => x_return_status,
	           x_return_message    => x_return_message,
	           x_wf_return_message => x_wf_return_message);

        write_log('handle_account x_return_status: ' || x_return_status);
        write_log('l_return_status: ' || l_return_status);

        -- Set return values if successful
        IF x_return_status = fnd_api.g_ret_sts_success THEN
          p_org_cust_tbl(i).account_objs(1).cust_acct_id := t_customer_rec.cust_account_rec.cust_account_id;
          p_org_cust_tbl(i).account_objs(1).account_number := t_customer_rec.cust_account_rec.account_number;
        ELSE

          -- If return status is D, this means we have similar/duplicate customers and requires additional
          -- handling.
          IF x_return_status = 'D' THEN
	write_log('l_dup_acct_tbl.COUNT: ' || l_dup_acct_tbl.count);

	-- Need to loop through l_dup_acct_tbl, which contains similar/duplicate party_ids
	FOR j IN 1 .. l_dup_acct_tbl.count LOOP
	  l_count := l_count + 1;
	  write_log('LOOP duplicates party_id: ' || l_dup_acct_tbl(j).id1);

	  -- Get all account/party info for duplicate party to return to calling system
	  hz_org_cust_bo_pub.get_org_cust_bo(p_init_msg_list    => fnd_api.g_true,
				 p_organization_id  => l_dup_acct_tbl(j).id1,
				 p_organization_os  => NULL,
				 p_organization_osr => NULL,
				 x_org_cust_obj     => l_dup_org_cust_obj,
				 x_return_status    => l_return_status,
				 x_msg_count        => x_msg_count,
				 x_msg_data         => x_msg_data);

	  write_log('hz_org_cust_bo_pub.get_org_cust_bo x_return_status: ' ||
		l_return_status);

	  IF l_return_status <> fnd_api.g_ret_sts_success THEN
	    l_return_message := 'Error retrieving duplicate customers.';
	    l_return_status  := fnd_api.g_ret_sts_error;
	    RAISE e_error;
	  END IF;

	  p_dup_org_cust_tbl.extend;
	  p_dup_org_cust_tbl(l_count) := l_dup_org_cust_obj;
	  write_log('org name: ' || p_dup_org_cust_tbl(j)
		.organization_obj.organization_id);
	  p_dup_org_cust_tbl(l_count).account_objs(1).common_obj_id := i;
	  p_dup_org_cust_tbl(l_count).account_objs(1).global_attribute1 := l_dup_acct_tbl(j)
						       .match_type;
	END LOOP;

	write_log('l_count: ' || l_count);
	write_log('Duplicate table count: ' ||
	          p_dup_org_cust_tbl.count);
	write_log('Duplicate check x_return_status: ' ||
	          x_return_status);

	-- If we've successfully gathered duplicate customer details, we return 'D'.  Otherwise
	-- we'll return an error status.  Both cases should raise e_error
	IF l_return_status = fnd_api.g_ret_sts_success THEN
	  l_return_message := 'Duplicates Exist';
	  l_return_status  := 'D';
	END IF;
	RAISE e_error;

          END IF; -- END IF l_return_status = 'D'
        END IF; --END IF l_return_status = fnd_api.g_ret_sts_success

      EXCEPTION
        WHEN e_error THEN
          -- Sets overall program's return values.
          x_return_status  := fnd_api.g_ret_sts_error;
          x_return_message := l_return_message;
          write_log(l_return_message);
        WHEN OTHERS THEN
          -- Sets LOOP record's return values
          l_return_status  := fnd_api.g_ret_sts_error;
          l_return_message := 'Error in loop for HANDLE_ACCOUNT_OBJ_API: ' ||
		      dbms_utility.format_error_stack;
          -- Sets overall program's return values.
          x_return_status  := fnd_api.g_ret_sts_error;
          x_return_message := l_return_message;
          write_log(l_return_message);
      END;

      write_log('p_org_cust_tbl(i).account_objs(1).cust_acct_id: ' || p_org_cust_tbl(i).account_objs(1)
	    .cust_acct_id);
      -- Writes return values to error table type
      p_error_tbl.extend;
      p_error_tbl(i) := xxssys_error_obj(i,
			     NULL,
			     l_return_status,
			     l_return_message);

      write_log('****** END PROCESSING RECORD # ' || i || ' *******');
    END LOOP;

    write_log('END HANDLE_ACCOUNT_OBJ_API');
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in HANDLE_ACCOUNT_OBJ_API: ' ||
		  dbms_utility.format_error_stack;
      write_log('END HANDLE_ACCOUNT_OBJ_API (EXCEPTION)');
  END handle_account_obj_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : This is a wrapper procedure written specifically for SFDC.  This
  --            procedure will simply look for duplicates, and return a table type
  --            of xxar_cust_match_tab to SFDC for any matching accounts.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------
  PROCEDURE find_duplicate_customers_only(p_match_type       IN VARCHAR2 DEFAULT 'LIKE',
			      p_customer_in_tbl  IN xxar_cust_match_tab,
			      x_dup_customer_tbl OUT xxar_cust_match_tab,
			      x_return_status    OUT VARCHAR2,
			      x_return_message   OUT VARCHAR2) IS
    l_customer_rec xxhz_api_cust_accounts_v%ROWTYPE;
    l_dup_acct_tbl dup_tbl;

    l_sf_id             hz_cust_accounts_all.attribute4%TYPE;
    l_wf_return_message VARCHAR2(2000);
  BEGIN
    write_log('START FIND_DUPLICATE_CUSTOMERS_ONLY');

    x_dup_customer_tbl := xxar_cust_match_tab();

    -- Get current values to see if this is an update or create
    BEGIN
      SELECT *
      INTO   l_customer_rec
      FROM   xxhz_api_cust_accounts_v
      WHERE  cust_account_id = p_customer_in_tbl(1).cust_account_id;
    EXCEPTION
      WHEN no_data_found THEN
        NULL; -- means this is a new record
    END;

    -- Check if one of the duplicate check match fields has changed.  If it has, we need to do duplicate check.  If
    -- not, we can skip the check.
    IF is_modified(l_customer_rec.party_name,
	       p_customer_in_tbl(1).party_name) OR
       is_modified(l_customer_rec.atradius_id,
	       p_customer_in_tbl(1).atradius_id) OR
       is_modified(l_customer_rec.party_duns_number,
	       p_customer_in_tbl(1).duns_number_c) OR
       is_modified(l_customer_rec.party_tax_reference,
	       p_customer_in_tbl(1).vat_id) THEN

      find_duplicate_customers(p_dup_cust        => l_dup_acct_tbl,
		       p_match_type      => p_match_type,
		       p_cust_account_id => p_customer_in_tbl(1)
				    .cust_account_id,
		       p_party_name      => p_customer_in_tbl(1)
				    .party_name,
		       p_atradius_id     => p_customer_in_tbl(1)
				    .atradius_id,
		       p_duns_number     => p_customer_in_tbl(1)
				    .duns_number_c,
		       p_tax_reference   => p_customer_in_tbl(1)
				    .vat_id,
		       x_return_status   => x_return_status,
		       x_return_message  => x_return_message);

      write_log('find_duplicate_customers x_return_status: ' ||
	    x_return_status);
    END IF;

    -- If duplicates found, load the outbound x_dup_customer_tbl with the duplicates
    IF x_return_status = 'D' THEN
      FOR i IN 1 .. l_dup_acct_tbl.count LOOP
        l_sf_id := NULL;

        -- Get SFDC ID
        SELECT attribute4
        INTO   l_sf_id
        FROM   hz_cust_accounts_all
        WHERE  cust_account_id = l_dup_acct_tbl(i).id2;

        x_dup_customer_tbl.extend;
        x_dup_customer_tbl(i) := xxar_cust_match_rec(l_dup_acct_tbl(i)
				     .match_type,
				     l_dup_acct_tbl(i).id2,
				     l_sf_id,
				     NULL,
				     NULL,
				     NULL,
				     NULL,
				     NULL);
      END LOOP;
    END IF;

    write_log('END FIND_DUPLICATE_CUSTOMERS_ONLY');
  EXCEPTION
    WHEN OTHERS THEN
      x_return_message := 'Error in FIND_DUPLICATE_CUSTOMERS_ONLY: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END UPDATE_CUSTOMER_EXT (EXCEPTION)');
  END find_duplicate_customers_only;

  ----------------------------------------------------------------------------------
  -- Purpose  : This mimics the Oracle standard form's locking functionality for HZ
  --            tables.  All HZ tables we are dealing with contain an object_version_number
  --            field.  When a record is updated, the object_version_number is incremented by
  --            1.  Rather than looking through all fields for changes, we can simply
  --            check the object version number.
  --
  --            For example, let's say I want to change the party_name on hz_parties.
  --            I enter the form and the name is MAZ CO., and the object_version_number = 1.
  --            However, another user enters in a different session and updates the same
  --            party's name to MAZ COMPANY before I change it.  Oracle's API will also update
  --            the object_version_number = 2.  When I click on party_name to edit, it will
  --            fire the form block's ON-LOCK trigger, which compares my object_version_number
  --            to what's in the database.  Since the they won't match (1 <> 2), the code below
  --            will throw a message back to the form that the record has been changed and will
  --            force the user to requery.
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  ----------------------------------------------------------------------------------
  PROCEDURE handle_account_lock(p_acc_rec        IN OUT frm_customer_rec,
		        x_return_status  OUT VARCHAR2,
		        x_return_message OUT VARCHAR2) IS
    l_ovn hz_parties.object_version_number%TYPE;

    e_error EXCEPTION;
  BEGIN
    g_program_unit := 'HANDLE_ACCOUNT_LOCK';
    write_log('START ' || g_program_unit);
    write_log('p_acc_rec.cust_organization_rec.party_id ' ||
	  p_acc_rec.cust_organization_rec.party_id);

    l_ovn := get_object_version_number('PARTY',
			   p_acc_rec.cust_organization_rec.party_id);
    IF p_acc_rec.party_ovn <> l_ovn THEN
      x_return_message := 'HZ_PARTIES record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('ACCOUNT',
			   p_acc_rec.cust_account_rec.cust_account_id);
    IF p_acc_rec.acct_ovn <> l_ovn THEN
      x_return_message := 'HZ_CUST_ACCOUNTS_ALL record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('CUST_PROFILE',
			   p_acc_rec.cust_profile_rec.cust_account_profile_id);
    IF p_acc_rec.cust_profile_ovn <> l_ovn THEN
      x_return_message := 'HZ_CUSTOMER_PROFILES record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('CUST_PROFILE_AMT',
			   p_acc_rec.cust_profile_amt_rec.cust_acct_profile_amt_id);
    IF p_acc_rec.cust_profile_amt_ovn <> l_ovn THEN
      x_return_message := 'HZ_CUST_PROFILE_AMTS record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('CUST_CLASS',
			   p_acc_rec.cust_classifications_rec.code_assignment_id);
    IF p_acc_rec.cust_classification_ovn <> l_ovn THEN
      x_return_message := 'HZ_CODE_ASSIGNMENTS record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('PARTY_RELATIONSHIP',
			   p_acc_rec.cust_relationship_rec.relationship_id);
    IF p_acc_rec.cust_relationship_ovn <> l_ovn THEN
      x_return_message := 'HZ_RELATIONSHIPS record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('ACCOUNT_RELATIONSHIP',
			   p_acc_rec.cust_account_relationship_rec.cust_acct_relate_id);
    IF p_acc_rec.cust_account_relationship_ovn <> l_ovn THEN
      x_return_message := 'HZ_CUST_ACCT_RELATE record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('PARTY_TAX_REGISTRATION',
			   p_acc_rec.cust_tax_registration.registration_id);
    IF p_acc_rec.cust_tax_registration_ovn <> l_ovn THEN
      x_return_message := 'ZX_REGISTRATIONS record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    write_log('END HANDLE_ACCOUNT_LOCK');
  EXCEPTION
    WHEN e_error THEN
      x_return_status := 'E';
      write_log('END HANDLE_ACCOUNT_LOCK (E_ERROR)');
    WHEN OTHERS THEN
      x_return_message := 'Error in ' || g_program_unit || ': ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := 'E';
      write_log('END HANDLE_ACCOUNT_LOCK (EXCEPTION)');
  END handle_account_lock;

  -- ------------------------------------------------------------------------------------------------------------------------------
  -- *******************************************  HANDLES CUSTOMER SITE ***********************************************************
  -- ------------------------------------------------------------------------------------------------------------------------------

  ----------------------------------------------------------------------------------
  -- Purpose  : This will hold any validations hz_party_sites, hz_locations,
  --            hz_cust_acct_sites_all, hz_site_uses_all, hz_customer_profiles at site
  --            use level, or hz_customer_profiles at the site use level.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  ----------------------------------------------------------------------------------
  PROCEDURE validate_site(p_site_rec       IN OUT customer_site_rec,
		  x_return_status  OUT VARCHAR2,
		  x_return_message OUT VARCHAR2) IS
    l_existing_site_use_status VARCHAR2(1);
    l_existing_site_status     VARCHAR2(1);

    e_error EXCEPTION;
  BEGIN
    write_log('BEGIN VALIDATE_SITE');

    BEGIN
      SELECT status
      INTO   l_existing_site_status
      FROM   hz_cust_acct_sites_all hcasa
      WHERE  p_site_rec.cust_site_rec.cust_acct_site_id =
	 hcasa.cust_acct_site_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_existing_site_status := NULL;
    END;

    IF p_site_rec.cust_site_rec.status <> l_existing_site_status THEN
      -- Validates that inactivation reason (ATTRIBUTE2) is populated when an account site is inactive.
      IF p_site_rec.cust_site_rec.status = 'I' AND
         p_site_rec.cust_site_rec.attribute2 IS NULL THEN
        x_return_message := 'Error: Inactive Account Sites requires Inactivation Reason located under Additional Customer Site Info.';
        RAISE e_error;
      END IF;
    END IF;

    -- Validates that inactivation reason (ATTRIBUTE2) is populated when a site use is inactive.
    BEGIN
      SELECT status
      INTO   l_existing_site_use_status
      FROM   hz_cust_site_uses_all hcsua
      WHERE  p_site_rec.cust_site_use_rec.site_use_id = hcsua.site_use_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_existing_site_use_status := NULL;
    END;

    IF p_site_rec.cust_site_use_rec.status <> l_existing_site_use_status THEN
      IF p_site_rec.cust_site_use_rec.status = 'I' AND
         p_site_rec.cust_site_use_rec.attribute2 IS NULL THEN
        x_return_message := 'Error: Inactive Site Uses requires Inactivation Reason located under Additional Site Use Info.';
        RAISE e_error;
      END IF;
    END IF;

    x_return_status := fnd_api.g_ret_sts_success;
    write_log('END VALIDATE_SITE');
  EXCEPTION
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END VALIDATE_SITE (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_message := 'Error in VALIDATE_SITE: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := 'E';
      write_log('END VALIDATE_SITE (EXCEPTION)');
  END validate_site;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Checks site level data on ,
  --            hz_cust_acct_sites_all, hz_cust_site_uses_all
  --                Sites                 - hz_pary_sites, hz_locations, hz_cust_acct_sites_all
  --                Site Uses             - hz_cust_site_uses_all
  --            ... for changes against the database.  is_modified will also set NULL
  --            values to fnd_api.g_miss values in the event of NULL values vs database.
  --            See is_account_changed for more details as functionality is very similar.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- 1.1  04/11/2015  Diptasurjya CHG0036791 - Consider site use contact id as change
  -- -------------------------------------------------------------------------------
  PROCEDURE is_site_changed(p_site_rec       IN OUT customer_site_rec,
		    p_type           IN VARCHAR2,
		    x_chg_flag       OUT VARCHAR2,
		    x_populated_flag OUT VARCHAR2,
		    x_ovn            OUT NUMBER) IS
    t_location_rec       hz_locations%ROWTYPE;
    t_party_sites_rec    hz_party_sites%ROWTYPE;
    t_cust_site_rec      hz_cust_acct_sites_all%ROWTYPE;
    t_cust_site_uses_rec hz_cust_site_uses_all%ROWTYPE;
  BEGIN
    write_log('BEGIN IS_SITE_CHANGED');
    write_log('p_type: ' || p_type);

    IF p_type = 'LOCATION' THEN
      x_chg_flag := 'N';

      write_log('location_id: ' || p_site_rec.location_rec.location_id);
      IF p_site_rec.location_rec.location_id IS NOT NULL THEN
        SELECT *
        INTO   t_location_rec
        FROM   hz_locations
        WHERE  location_id = p_site_rec.location_rec.location_id;

        p_site_rec.location_rec.created_by_module := NULL;
      END IF;

      is_modified(t_location_rec.location_id,
	      p_site_rec.location_rec.location_id,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_location_rec.address1,
	      p_site_rec.location_rec.address1,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_location_rec.address2,
	      p_site_rec.location_rec.address2,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_location_rec.address3,
	      p_site_rec.location_rec.address3,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_location_rec.address4,
	      p_site_rec.location_rec.address4,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_location_rec.city,
	      p_site_rec.location_rec.city,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_location_rec.state,
	      p_site_rec.location_rec.state,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_location_rec.postal_code,
	      p_site_rec.location_rec.postal_code,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_location_rec.province,
	      p_site_rec.location_rec.province,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_location_rec.county,
	      p_site_rec.location_rec.county,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_location_rec.country,
	      p_site_rec.location_rec.country,
	      x_chg_flag,
	      x_populated_flag);

      x_ovn := t_location_rec.object_version_number;
    END IF;

    IF p_type = 'PARTY_SITE' THEN
      x_chg_flag := 'N';

      write_log('party_site_id: ' ||
	    p_site_rec.party_site_rec.party_site_id);
      IF p_site_rec.party_site_rec.party_site_id IS NOT NULL THEN
        SELECT *
        INTO   t_party_sites_rec
        FROM   hz_party_sites
        WHERE  party_site_id = p_site_rec.party_site_rec.party_site_id;

        p_site_rec.party_site_rec.created_by_module := NULL;
      END IF;

      is_modified(t_party_sites_rec.identifying_address_flag,
	      p_site_rec.party_site_rec.identifying_address_flag,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.party_site_name,
	      p_site_rec.party_site_rec.party_site_name,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.status,
	      p_site_rec.party_site_rec.status,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute_category,
	      p_site_rec.party_site_rec.attribute_category,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute1,
	      p_site_rec.party_site_rec.attribute1,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute2,
	      p_site_rec.party_site_rec.attribute2,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute3,
	      p_site_rec.party_site_rec.attribute3,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute4,
	      p_site_rec.party_site_rec.attribute4,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute5,
	      p_site_rec.party_site_rec.attribute5,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute6,
	      p_site_rec.party_site_rec.attribute6,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute7,
	      p_site_rec.party_site_rec.attribute7,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute8,
	      p_site_rec.party_site_rec.attribute8,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute9,
	      p_site_rec.party_site_rec.attribute9,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute10,
	      p_site_rec.party_site_rec.attribute10,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute11,
	      p_site_rec.party_site_rec.attribute11,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute12,
	      p_site_rec.party_site_rec.attribute12,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute13,
	      p_site_rec.party_site_rec.attribute13,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute14,
	      p_site_rec.party_site_rec.attribute14,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute15,
	      p_site_rec.party_site_rec.attribute15,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute16,
	      p_site_rec.party_site_rec.attribute16,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute17,
	      p_site_rec.party_site_rec.attribute17,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute18,
	      p_site_rec.party_site_rec.attribute18,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute19,
	      p_site_rec.party_site_rec.attribute19,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_sites_rec.attribute20,
	      p_site_rec.party_site_rec.attribute20,
	      x_chg_flag,
	      x_populated_flag);

      x_ovn := t_party_sites_rec.object_version_number;
    END IF;

    IF p_type = 'CUST_SITE' THEN
      x_chg_flag := 'N';

      IF p_site_rec.cust_site_rec.cust_acct_site_id IS NOT NULL THEN
        SELECT *
        INTO   t_cust_site_rec
        FROM   hz_cust_acct_sites_all
        WHERE  cust_acct_site_id =
	   p_site_rec.cust_site_rec.cust_acct_site_id;

        p_site_rec.cust_site_rec.created_by_module := NULL;
      END IF;

      is_modified(t_cust_site_rec.status,
	      p_site_rec.cust_site_rec.status,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute_category,
	      p_site_rec.cust_site_rec.attribute_category,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute1,
	      p_site_rec.cust_site_rec.attribute1,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute2,
	      p_site_rec.cust_site_rec.attribute2,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute3,
	      p_site_rec.cust_site_rec.attribute3,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute4,
	      p_site_rec.cust_site_rec.attribute4,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute5,
	      p_site_rec.cust_site_rec.attribute5,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute6,
	      p_site_rec.cust_site_rec.attribute6,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute7,
	      p_site_rec.cust_site_rec.attribute7,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute8,
	      p_site_rec.cust_site_rec.attribute8,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute9,
	      p_site_rec.cust_site_rec.attribute9,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute10,
	      p_site_rec.cust_site_rec.attribute10,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute11,
	      p_site_rec.cust_site_rec.attribute11,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute12,
	      p_site_rec.cust_site_rec.attribute12,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute13,
	      p_site_rec.cust_site_rec.attribute13,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute14,
	      p_site_rec.cust_site_rec.attribute14,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute15,
	      p_site_rec.cust_site_rec.attribute15,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute16,
	      p_site_rec.cust_site_rec.attribute16,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute17,
	      p_site_rec.cust_site_rec.attribute17,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute18,
	      p_site_rec.cust_site_rec.attribute18,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute19,
	      p_site_rec.cust_site_rec.attribute19,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_rec.attribute20,
	      p_site_rec.cust_site_rec.attribute20,
	      x_chg_flag,
	      x_populated_flag);

      x_ovn := t_cust_site_rec.object_version_number;
    END IF;

    IF p_type = 'CUST_SITE_USE' THEN
      x_chg_flag := 'N';

      IF p_site_rec.cust_site_use_rec.site_use_id IS NOT NULL THEN
        SELECT *
        INTO   t_cust_site_uses_rec
        FROM   hz_cust_site_uses_all
        WHERE  site_use_id = p_site_rec.cust_site_use_rec.site_use_id;

        p_site_rec.cust_site_use_rec.created_by_module := NULL;
      END IF;

      is_modified(t_cust_site_uses_rec.status,
	      p_site_rec.cust_site_use_rec.status,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.site_use_code,
	      p_site_rec.cust_site_use_rec.site_use_code,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.ship_via,
	      p_site_rec.cust_site_use_rec.ship_via,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.freight_term,
	      p_site_rec.cust_site_use_rec.freight_term,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.warehouse_id,
	      p_site_rec.cust_site_use_rec.warehouse_id,
	      x_chg_flag,
	      x_populated_flag);

      is_modified(t_cust_site_uses_rec.fob_point,
	      p_site_rec.cust_site_use_rec.fob_point,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.date_type_preference,
	      p_site_rec.cust_site_use_rec.date_type_preference,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.ship_sets_include_lines_flag,
	      p_site_rec.cust_site_use_rec.ship_sets_include_lines_flag,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.arrivalsets_include_lines_flag,
	      p_site_rec.cust_site_use_rec.arrivalsets_include_lines_flag,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.primary_salesrep_id,
	      p_site_rec.cust_site_use_rec.primary_salesrep_id,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.payment_term_id,
	      p_site_rec.cust_site_use_rec.payment_term_id,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.location,
	      p_site_rec.cust_site_use_rec.location,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.bill_to_site_use_id,
	      p_site_rec.cust_site_use_rec.bill_to_site_use_id,
	      x_chg_flag,
	      x_populated_flag);

      is_modified(t_cust_site_uses_rec.gl_id_rec,
	      p_site_rec.cust_site_use_rec.gl_id_rec,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.gl_id_rev,
	      p_site_rec.cust_site_use_rec.gl_id_rev,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.gl_id_tax,
	      p_site_rec.cust_site_use_rec.gl_id_tax,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.gl_id_freight,
	      p_site_rec.cust_site_use_rec.gl_id_freight,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.gl_id_clearing,
	      p_site_rec.cust_site_use_rec.gl_id_clearing,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.gl_id_unbilled,
	      p_site_rec.cust_site_use_rec.gl_id_unbilled,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.gl_id_unearned,
	      p_site_rec.cust_site_use_rec.gl_id_unearned,
	      x_chg_flag,
	      x_populated_flag);

      is_modified(t_cust_site_uses_rec.attribute_category,
	      p_site_rec.cust_site_use_rec.attribute_category,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute1,
	      p_site_rec.cust_site_use_rec.attribute1,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute2,
	      p_site_rec.cust_site_use_rec.attribute2,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute3,
	      p_site_rec.cust_site_use_rec.attribute3,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute4,
	      p_site_rec.cust_site_use_rec.attribute4,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute5,
	      p_site_rec.cust_site_use_rec.attribute5,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute6,
	      p_site_rec.cust_site_use_rec.attribute6,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute7,
	      p_site_rec.cust_site_use_rec.attribute7,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute8,
	      p_site_rec.cust_site_use_rec.attribute8,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute9,
	      p_site_rec.cust_site_use_rec.attribute9,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute10,
	      p_site_rec.cust_site_use_rec.attribute10,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute11,
	      p_site_rec.cust_site_use_rec.attribute11,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute12,
	      p_site_rec.cust_site_use_rec.attribute12,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute13,
	      p_site_rec.cust_site_use_rec.attribute13,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute14,
	      p_site_rec.cust_site_use_rec.attribute14,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute15,
	      p_site_rec.cust_site_use_rec.attribute15,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute16,
	      p_site_rec.cust_site_use_rec.attribute16,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute17,
	      p_site_rec.cust_site_use_rec.attribute17,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute18,
	      p_site_rec.cust_site_use_rec.attribute18,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute19,
	      p_site_rec.cust_site_use_rec.attribute19,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute20,
	      p_site_rec.cust_site_use_rec.attribute20,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute21,
	      p_site_rec.cust_site_use_rec.attribute21,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute22,
	      p_site_rec.cust_site_use_rec.attribute22,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute23,
	      p_site_rec.cust_site_use_rec.attribute23,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute24,
	      p_site_rec.cust_site_use_rec.attribute24,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.attribute25,
	      p_site_rec.cust_site_use_rec.attribute25,
	      x_chg_flag,
	      x_populated_flag);

      /* CHG0036791 - Dipta - Bug Fix - existing records*/
      is_modified(t_cust_site_uses_rec.contact_id,
	      p_site_rec.cust_site_use_rec.contact_id,
	      x_chg_flag,
	      x_populated_flag);

      is_modified(t_cust_site_uses_rec.primary_flag,
	      p_site_rec.cust_site_use_rec.primary_flag,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_site_uses_rec.price_list_id,
	      p_site_rec.cust_site_use_rec.price_list_id,
	      x_chg_flag,
	      x_populated_flag);
      /* END - CHG0036791 - Dipta */

      x_ovn := t_location_rec.object_version_number;
    END IF;

    write_log('x_populated_flag: ' || x_populated_flag);
    write_log('x_chg_flag: ' || x_chg_flag);
    write_log('x_ovn: ' || x_ovn);

    write_log('END IS_SITE_CHANGED');
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Error in IS_SITE_CHANGED: ' ||
	    dbms_utility.format_error_stack);
      write_log('END IS_SITE_CHANGED (EXCEPTION)');
      RAISE;
  END is_site_changed;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Function used to load location information from frm_location_rec
  --            into hz_location_v2pub.location_rec_type for use with standard Oracle APIs.
  --            This needs to be done because hz_location_v2pub.location_rec_type contains
  --            global variables which causes errors with XXHZCUSTOMER.fmb.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------
  FUNCTION load_location_rec(p_location_rec IN frm_location_rec)
    RETURN hz_location_v2pub.location_rec_type IS
    x_location_rec hz_location_v2pub.location_rec_type;
  BEGIN
    write_log('START LOAD_LOCATION_REC');

    x_location_rec.location_id        := p_location_rec.location_id;
    x_location_rec.country            := p_location_rec.country;
    x_location_rec.address1           := p_location_rec.address1;
    x_location_rec.address2           := p_location_rec.address2;
    x_location_rec.address3           := p_location_rec.address3;
    x_location_rec.address4           := p_location_rec.address4;
    x_location_rec.city               := p_location_rec.city;
    x_location_rec.postal_code        := p_location_rec.postal_code;
    x_location_rec.state              := p_location_rec.state;
    x_location_rec.province           := p_location_rec.province;
    x_location_rec.county             := p_location_rec.county;
    x_location_rec.attribute_category := p_location_rec.attribute_category;
    x_location_rec.attribute1         := p_location_rec.attribute1;
    x_location_rec.attribute2         := p_location_rec.attribute2;
    x_location_rec.attribute3         := p_location_rec.attribute3;
    x_location_rec.attribute4         := p_location_rec.attribute4;
    x_location_rec.attribute5         := p_location_rec.attribute5;
    x_location_rec.attribute6         := p_location_rec.attribute6;
    x_location_rec.attribute7         := p_location_rec.attribute7;
    x_location_rec.attribute8         := p_location_rec.attribute8;
    x_location_rec.attribute9         := p_location_rec.attribute9;
    x_location_rec.attribute10        := p_location_rec.attribute10;
    x_location_rec.attribute11        := p_location_rec.attribute11;
    x_location_rec.attribute12        := p_location_rec.attribute12;
    x_location_rec.attribute13        := p_location_rec.attribute13;
    x_location_rec.attribute14        := p_location_rec.attribute14;
    x_location_rec.attribute15        := p_location_rec.attribute15;
    x_location_rec.attribute16        := p_location_rec.attribute16;
    x_location_rec.attribute17        := p_location_rec.attribute17;
    x_location_rec.attribute18        := p_location_rec.attribute18;
    x_location_rec.attribute19        := p_location_rec.attribute19;
    x_location_rec.attribute20        := p_location_rec.attribute20;
    x_location_rec.created_by_module  := p_location_rec.created_by_module;

    write_log('END LOAD_LOCATION_REC');
    RETURN x_location_rec;
  EXCEPTION
    WHEN OTHERS THEN
      write_log('END LOAD_LOCATION_REC (EXCEPTION)');
      RAISE;
  END load_location_rec;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Function used to load location information from frm_location_rec
  --            into hz_location_v2pub.location_rec_type for use with standard Oracle APIs.
  --            This needs to be done because hz_location_v2pub.location_rec_type contains
  --            global variables which causes errors with XXHZCUSTOMER.fmb.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------
  FUNCTION load_location_rec(p_location_rec IN hz_location_v2pub.location_rec_type)
    RETURN frm_location_rec IS
    x_location_rec frm_location_rec;
  BEGIN
    write_log('START LOAD_LOCATION_REC');

    x_location_rec.location_id        := p_location_rec.location_id;
    x_location_rec.country            := p_location_rec.country;
    x_location_rec.address1           := p_location_rec.address1;
    x_location_rec.address2           := p_location_rec.address2;
    x_location_rec.address3           := p_location_rec.address3;
    x_location_rec.address4           := p_location_rec.address4;
    x_location_rec.city               := p_location_rec.city;
    x_location_rec.postal_code        := p_location_rec.postal_code;
    x_location_rec.state              := p_location_rec.state;
    x_location_rec.province           := p_location_rec.province;
    x_location_rec.county             := p_location_rec.county;
    x_location_rec.attribute_category := p_location_rec.attribute_category;
    x_location_rec.attribute1         := p_location_rec.attribute1;
    x_location_rec.attribute2         := p_location_rec.attribute2;
    x_location_rec.attribute3         := p_location_rec.attribute3;
    x_location_rec.attribute4         := p_location_rec.attribute4;
    x_location_rec.attribute5         := p_location_rec.attribute5;
    x_location_rec.attribute6         := p_location_rec.attribute6;
    x_location_rec.attribute7         := p_location_rec.attribute7;
    x_location_rec.attribute8         := p_location_rec.attribute8;
    x_location_rec.attribute9         := p_location_rec.attribute9;
    x_location_rec.attribute10        := p_location_rec.attribute10;
    x_location_rec.attribute11        := p_location_rec.attribute11;
    x_location_rec.attribute12        := p_location_rec.attribute12;
    x_location_rec.attribute13        := p_location_rec.attribute13;
    x_location_rec.attribute14        := p_location_rec.attribute14;
    x_location_rec.attribute15        := p_location_rec.attribute15;
    x_location_rec.attribute16        := p_location_rec.attribute16;
    x_location_rec.attribute17        := p_location_rec.attribute17;
    x_location_rec.attribute18        := p_location_rec.attribute18;
    x_location_rec.attribute19        := p_location_rec.attribute19;
    x_location_rec.attribute20        := p_location_rec.attribute20;
    x_location_rec.created_by_module  := p_location_rec.created_by_module;

    write_log('END LOAD_LOCATION_REC');
    RETURN x_location_rec;
  EXCEPTION
    WHEN OTHERS THEN
      write_log('END LOAD_LOCATION_REC (EXCEPTION)');
      RAISE;
  END load_location_rec;

  -- -------------------------------------------------------------------------------
  -- Purpose  : This procedure is used to get the Avalara version of the address.  The
  --            functionality was taken from the hz_locations XXAVL_HZ_LOCATIONS_BRIU
  --            trigger.  The procedure makes a web service call to Avalara, which
  --            returns the Avalara formatted address.
  --
  --            For example, if I enter the following... 4076 Meadowlark Curve, Avalara
  --            changes it to 4076 Meadowlark Curv (no e).  The 'Curv' version is what
  --            will get saved to the DB.  Part of this project is to prevent duplicate
  --            sites within a customer.  When checking for duplicates, I need to check
  --            against Avalara's validated address vs what the user enters, otherwise
  --            I may inadvertently allow duplicates.
  --
  --            This procedure is called before anything is sent to the DB.  It will
  --            take in the user entered address, allow Avalara to format, then
  --            check for duplicates against the Avalara address, since that is what
  --            will get saved to the DB.
  --
  -- Change History
  -- ...............................................................................
  -- Ver     Date          Name            Desc 
  -- 1.0     10-JUN-2015   MMAZANET        CHG0035118. Initial creation. 
  -- 1.1     22-Aug-2017   Lingaraj        CHG0040036 - Upgrade Avalara interface to AvaTax
  -- -------------------------------------------------------------------------------
  PROCEDURE get_address(p_site_rec       IN OUT frm_customer_site_rec,
		x_return_message OUT VARCHAR2,
		x_return_status  OUT VARCHAR2) 
  IS
    /*l_address_tbl   xxavl_dir_xml_pkg.g_address_validation_tab;
    l_error_message VARCHAR2(2000);
    l_status        VARCHAR2(1);
    */---- Commented 22-Aug-2017 CHG0040036
    l_p_addr_validate VARCHAR2(3);   --Added CHG0040036
    l_AvaTaxDocParams AVATAX_GEN_PKG.AvaTaxDocParams;  --Added CHG0040036
    l_AddressLines    AddressLinesTbl := AddressLinesTbl(); --Added CHG0040036
    l_return_status   BOOLEAN; --Added CHG0040036

    e_error EXCEPTION;

    FUNCTION validate_this_country(p_country_code IN VARCHAR2) RETURN BOOLEAN IS

      l_boolean BOOLEAN;

      CURSOR flv_cursor(p_lookup_code IN VARCHAR2) IS
        SELECT flv.meaning
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = 'XXAVL_ADDR_VALIDTN_COUNTRIES'
        AND    flv.lookup_code = p_lookup_code
        AND    flv.enabled_flag = 'Y'
        AND    SYSDATE BETWEEN flv.start_date_active AND
	   nvl(flv.end_date_active, SYSDATE + 1);

      flv_rec flv_cursor%ROWTYPE;
    BEGIN

      flv_rec.meaning := NULL;
      OPEN flv_cursor(p_country_code);
      FETCH flv_cursor
        INTO flv_rec;
      IF flv_cursor%FOUND THEN
        l_boolean := TRUE;
      ELSE
        l_boolean := FALSE;
      END IF;
      CLOSE flv_cursor;

      RETURN l_boolean;

    END validate_this_country;

  BEGIN
    write_log('START GET_ADDRESS');
    ------Added for CHG0040036  START ---
    IF  (nvl(fnd_profile.value('AFLOG_ENABLED'), 'N') = 'Y') 
      AND validate_this_country(p_site_rec.location_rec.country) 
    THEN
        IF ( nvl(fnd_global.conc_request_id,-1) <> -1 )
        THEN
             AVATAX_CONNECTOR_UTILITY_PKG.GlobalPrintOption := 'L';
        ELSE
             AVATAX_CONNECTOR_UTILITY_PKG.GlobalPrintOption := 'Y';
        END IF;
    END IF;
    
    l_p_addr_validate := NVL(FND_PROFILE.VALUE('AVATAX_EXPLICIT_ADDR_VALIDATION'), 'N');
    AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: AVATAX_CONNECTOR_UTILITY_PKG.GlobalPrintOption = '||AVATAX_CONNECTOR_UTILITY_PKG.GlobalPrintOption);
    AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: P_ADDR_VALIDATE = '||l_p_addr_validate);
    AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: AVATAX_CONNECTOR_UTILITY_PKG.g_upd_addr_validate_res_flag = '||AVATAX_CONNECTOR_UTILITY_PKG.g_upd_addr_validate_res_flag);
    
    IF (l_p_addr_validate = 'Y')
     AND (nvl(AVATAX_CONNECTOR_UTILITY_PKG.g_upd_addr_validate_res_flag, 'N') = 'N')  
     AND (UPPER(p_site_rec.location_rec.country) = 'US' )  
    THEN  
        l_AddressLines.extend;
        l_AddressLines(1) := AddressLinesObj('HZ',
                                nvl(p_site_rec.location_rec.LOCATION_ID, -1),
                                substrb(p_site_rec.location_rec.address1,1,50),
                                substrb(p_site_rec.location_rec.address2,1,50),
                                substrb(p_site_rec.location_rec.address3,1,50),
                                substrb(p_site_rec.location_rec.city,1,50),
                                substrb(p_site_rec.location_rec.state,1,2),
                                substrb(p_site_rec.location_rec.postal_code,1,11),
                                UPPER(p_site_rec.location_rec.country)
                                );
        l_AvaTaxDocParams.XMLSplitSize := 32000;
        l_AvaTaxDocParams.AddressRawResp := XMLRespTbl();        
        
        -- ====================================================================
        -- = Pass the address table to the address validation procedure....
        -- ====================================================================

        write_log('Calling address validation procedure... ');        
    
        l_AvaTaxDocParams.AddressRawResp := avatax_generic_connector.ADDRESSES_VALIDATION(l_AvaTaxDocParams.XMLSplitSize, 'XMLRESPTBL', l_AddressLines);
        AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: AvaTaxDocParams.AddressRawResp count := ['||l_AvaTaxDocParams.AddressRawResp.count||']');
        AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: ******** End of AVATAX_GENERIC_CONNECTOR.ADDRESS_VALIDATION *********');
        
        l_AvaTaxDocParams.AddressLinesInfo := null;  
        
        for i in 1..l_AvaTaxDocParams.AddressRawResp.count
        Loop  
          AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: AvaTaxDocParams.AddressRawResp('||i||').PartXML => '||l_AvaTaxDocParams.AddressRawResp(i).PartXML);
          l_AvaTaxDocParams.AddressLinesInfo := l_AvaTaxDocParams.AddressLinesInfo||l_AvaTaxDocParams.AddressRawResp(i).PartXML;
        End Loop;
        
        AVATAX_CONNECTOR_UTILITY_PKG.TransAddressValidateResult(
                                                l_AvaTaxDocParams.AddressLinesInfo,
                                                l_AvaTaxDocParams.AddrLinesResult,
                                                l_return_status);                                               
                                                 
        ---
        IF l_return_status THEN       
          FOR i in 1..l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT.count LOOP
             IF (nvl(p_site_rec.location_rec.LOCATION_ID,-1) = l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).AddressID)
               AND  (upper(l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).Resultcode) = 'SUCCESS') 
             THEN  
                p_site_rec.location_rec.address1 := l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).LINE1;
                p_site_rec.location_rec.address2 := l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).LINE2;
                p_site_rec.location_rec.address3 := l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).LINE3;
                p_site_rec.location_rec.city     := l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).CITY;
                p_site_rec.location_rec.postal_code := l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).POSTALCODE;
                p_site_rec.location_rec.state    := l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).REGION;
             END IF;    
        
          END LOOP;  
        ELSE  
          AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: AVATAX_CONNECTOR_UTILITY_PKG.TransAddressValidateResult() return status is false');
          for i in 1..l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT.count
          LOOP
            IF (nvl(p_site_rec.location_rec.LOCATION_ID,-1) = l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).AddressID)
               AND (upper(l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).Resultcode) <> 'SUCCESS') 
            THEN
              AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: AvaTax Address Validation Result Code => '
                                               ||l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).Resultcode);
              AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: Error Message => '
                                            ||l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).ErrorMsg);
              RAISE_APPLICATION_ERROR(-20002, 'AVATAX: '||l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).ErrorMsg);
            END IF;
          END LOOP;
          RAISE_APPLICATION_ERROR(-20003, 'AVATAX: Error occurred during Address Validation');
        END IF; 
        
    Else
      Return;    
    End If;
    
     IF upper(l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(1).Resultcode) = 'SUCCESS' THEN
        x_return_status := fnd_api.g_ret_sts_success;
     ELSE
        x_return_status  := fnd_api.g_ret_sts_error;
        x_return_message := 'Error occurred validating address';
     END IF;
      
    ------Added for CHG0040036  END ---
    
    
    /* Commented CHG0040036
    IF nvl(fnd_profile.value('AVA_VALIDATE_ADDRESSES'), 'N') = 'Y' AND
       validate_this_country(p_site_rec.location_rec.country) THEN
      write_log('Loading Address info...');

      -- ====================================================================
      -- = Load address info into address table....
      -- ====================================================================

      l_address_tbl(1).address1 := p_site_rec.location_rec.address1;
      l_address_tbl(1).address2 := p_site_rec.location_rec.address2;
      l_address_tbl(1).address3 := p_site_rec.location_rec.address3;
      l_address_tbl(1).address4 := p_site_rec.location_rec.address4;
      l_address_tbl(1).city := p_site_rec.location_rec.city;
      l_address_tbl(1).postal_code := p_site_rec.location_rec.postal_code;
      l_address_tbl(1).state := p_site_rec.location_rec.state;
      l_address_tbl(1).county := p_site_rec.location_rec.county;
      l_address_tbl(1).country := p_site_rec.location_rec.country;
      l_address_tbl(1).taxregionid := '0';
      l_address_tbl(1).textcase := 'Default';
      l_address_tbl(1).coordinates := 'false';
      l_address_tbl(1).taxability := 'false';
      l_address_tbl(1).request_date := to_char(SYSDATE, 'yyyy-mm-dd');
      l_address_tbl(1).latitude := NULL;
      l_address_tbl(1).longitude := NULL;
      l_address_tbl(1).fipscode := NULL;
      l_address_tbl(1).carrierroute := NULL;
      l_address_tbl(1).postnet := NULL;
      l_address_tbl(1).addresstype := NULL;
      l_address_tbl(1).validatestatus := NULL;
      l_address_tbl(1).geocodetype := NULL;
      l_address_tbl(1).taxable := NULL;
      l_address_tbl(1).resultcode := NULL;
      l_address_tbl(1).errormessage := NULL;
      
      -- ====================================================================
      -- = Pass the address table to the address validation procedure....
      -- ====================================================================

      write_log('Calling address validation procedure... ');

      xxavl_dir_xml_pkg.address_validation(p_address_val_tab => l_address_tbl, -- in out table def below
			       p_error_message   => x_return_message -- only for exception failure in proc
			       );
      
      write_log('Avalara address validation return status: ' ||
	    x_return_message);

      IF x_return_message IS NOT NULL THEN
        RAISE e_error;
      END IF;
      
      -- ====================================================================
      -- = If we are here then the address validation procedure had no
      -- = unexpected errors (not to be confused with whether the address
      -- = is valid or not).
      -- ====================================================================

      p_site_rec.location_rec.address1    := l_address_tbl(1).address1;
      p_site_rec.location_rec.address2    := l_address_tbl(1).address2;
      p_site_rec.location_rec.address3    := l_address_tbl(1).address3;
      p_site_rec.location_rec.city        := l_address_tbl(1).city;
      p_site_rec.location_rec.postal_code := l_address_tbl(1).postal_code;
      p_site_rec.location_rec.state       := l_address_tbl(1).state;
      
      -- ====================================================================
      -- = Set the status value based upon the ResultCode...
      -- ====================================================================

      IF upper(l_address_tbl(1).resultcode) = 'SUCCESS' THEN
        x_return_status := fnd_api.g_ret_sts_success;
      ELSE
        x_return_status  := fnd_api.g_ret_sts_error;
        x_return_message := 'Error occurred validating address';
      END IF;
      */ --Commented CHG0040036
      -- ====================================================================
      -- = Set the validated_flag and the address4 value.
      -- ====================================================================
      IF x_return_status = fnd_api.g_ret_sts_success THEN
        p_site_rec.location_rec.address4 := NULL;
      ELSE
        -- display status to users on Address4 column
        p_site_rec.location_rec.address4 := '** AVALARA UNABLE TO VALIDATE ADDRESS ** ' || 
                substr(l_AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(1).ErrorMsg, 1,239);-- added CHG0040036
			        /*substr(l_address_tbl(1)
				   .errormessage,
				   1,
				   239);*/-- Commented CHG0040036
        x_return_status := fnd_api.g_ret_sts_success;
      END IF;
    --END IF;-- Commented CHG0040036

  EXCEPTION
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END GET_ADDRESS (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in GET_ADDRESS: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END GET_ADDRESS (EXCEPTION)');
  END get_address;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of locations (hz_locations)
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE location_api(p_site_rec       IN OUT customer_site_rec,
		 x_return_message OUT VARCHAR2,
		 x_return_status  OUT VARCHAR2) IS
    l_location_id    NUMBER;
    l_ovn            hz_locations.object_version_number%TYPE;
    l_chg_flag       VARCHAR2(1);
    l_populated_flag VARCHAR2(1);

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    l_action        VARCHAR2(15);

    e_error EXCEPTION;
    e_skip  EXCEPTION;
  BEGIN
    write_log('START LOCATION_API');

    is_site_changed(p_site_rec       => p_site_rec,
	        p_type           => 'LOCATION',
	        x_chg_flag       => l_chg_flag,
	        x_populated_flag => l_populated_flag,
	        x_ovn            => l_ovn);

    IF p_site_rec.location_rec.location_id IS NULL THEN
      l_action := 'Create';

      -- If nothing populated, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      hz_location_v2pub.create_location(p_init_msg_list => 'T',
			    p_location_rec  => p_site_rec.location_rec,
			    x_location_id   => p_site_rec.location_rec.location_id,
			    x_return_status => x_return_status,
			    x_msg_count     => l_msg_count,
			    x_msg_data      => l_msg_data);
    ELSE
      l_action := 'Update';

      -- If no changes, skip processing
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      -- Record has changed
      IF l_ovn <> p_site_rec.location_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_location_v2pub.update_location(p_init_msg_list         => 'T', -- i v
			    p_location_rec          => p_site_rec.location_rec,
			    p_object_version_number => p_site_rec.location_ovn,
			    x_return_status         => x_return_status,
			    x_msg_count             => l_msg_count,
			    x_msg_data              => l_msg_data);
    END IF;
    write_log('Location API ' || l_action || ' return status: ' ||
	  x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'Location API ' || l_action || ' Failed ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END LOCATION_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END LOCATION_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END LOCATION_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in LOCATION_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END LOCATION_API (EXCEPTION)');
  END location_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of party sites (hz_party_sites)
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE party_site_api(p_site_rec       IN OUT customer_site_rec,
		   x_return_message OUT VARCHAR2,
		   x_return_status  OUT VARCHAR2) IS

    l_party_id          NUMBER := NULL;
    l_party_site_number NUMBER := NULL;
    l_party_site_id     NUMBER := NULL;

    l_action         VARCHAR2(15);
    l_ovn            hz_party_sites.object_version_number%TYPE;
    l_chg_flag       VARCHAR2(1);
    l_populated_flag VARCHAR2(1);

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    l_party_name    VARCHAR2(360) := NULL;

    e_skip  EXCEPTION;
    e_error EXCEPTION;
  BEGIN
    write_log('START PARTY_SITE_API');
    fnd_msg_pub.initialize;

    is_site_changed(p_site_rec       => p_site_rec,
	        p_type           => 'PARTY_SITE',
	        x_chg_flag       => l_chg_flag,
	        x_populated_flag => l_populated_flag,
	        x_ovn            => l_ovn);

    p_site_rec.party_site_rec.status := nvl(p_site_rec.party_site_rec.status,
			        'A');

    IF p_site_rec.party_site_rec.party_site_id IS NULL THEN
      l_action := 'Create';

      -- If nothing on party site populated, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      hz_party_site_v2pub.create_party_site(p_init_msg_list     => 'T',
			        p_party_site_rec    => p_site_rec.party_site_rec,
			        x_party_site_id     => p_site_rec.party_site_rec.party_site_id,
			        x_party_site_number => p_site_rec.party_site_rec.party_site_number,
			        x_return_status     => x_return_status,
			        x_msg_count         => l_msg_count,
			        x_msg_data          => l_msg_data);

    ELSE
      l_action := 'Update';

      -- If nothing on party site changed, skip processing
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      -- Record has changed
      IF l_ovn <> p_site_rec.party_site_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_party_site_v2pub.update_party_site(p_init_msg_list         => 'T',
			        p_party_site_rec        => p_site_rec.party_site_rec,
			        p_object_version_number => p_site_rec.party_site_ovn,
			        x_return_status         => x_return_status,
			        x_msg_count             => l_msg_count,
			        x_msg_data              => l_msg_data);

    END IF;
    write_log('Party Site API ' || l_action || ' return status: ' ||
	  x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'Party Site API ' || l_action || 'Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END PARTY_SITE_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END PARTY_SITE_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END PARTY_SITE_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in PARTY_SITE_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END PARTY_SITE_API (EXCEPTION)');
  END party_site_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of customer account sites (hz_cust_account_sites_all)
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE cust_account_site_api(p_site_rec       IN OUT customer_site_rec,
		          x_return_message OUT VARCHAR2,
		          x_return_status  OUT VARCHAR2) IS
    l_party_id          NUMBER := NULL;
    l_party_site_number NUMBER := NULL;
    l_party_site_id     NUMBER := NULL;

    l_action         VARCHAR2(15);
    l_ovn            hz_party_sites.object_version_number%TYPE;
    l_chg_flag       VARCHAR2(1);
    l_populated_flag VARCHAR2(1);

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    l_party_name    VARCHAR2(360) := NULL;

    e_skip  EXCEPTION;
    e_error EXCEPTION;
  BEGIN
    write_log('START CUST_ACCOUNT_SITE_API');
    fnd_msg_pub.initialize;

    -- Sets the org for this table which is org specific
    mo_global.set_org_access(p_org_id_char     => p_site_rec.cust_site_rec.org_id,
		     p_sp_id_char      => NULL,
		     p_appl_short_name => 'AR');

    is_site_changed(p_site_rec       => p_site_rec,
	        p_type           => 'CUST_SITE',
	        x_chg_flag       => l_chg_flag,
	        x_populated_flag => l_populated_flag,
	        x_ovn            => l_ovn);

    IF p_site_rec.cust_site_rec.cust_acct_site_id IS NULL THEN
      l_action := 'Create';

      -- If nothing populated for cust_acct_site, then skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      hz_cust_account_site_v2pub.create_cust_acct_site(p_init_msg_list      => 'T',
				       p_cust_acct_site_rec => p_site_rec.cust_site_rec,
				       x_cust_acct_site_id  => p_site_rec.cust_site_rec.cust_acct_site_id,
				       x_return_status      => x_return_status,
				       x_msg_count          => l_msg_count,
				       x_msg_data           => l_msg_data);
    ELSE
      l_action := 'Update';

      -- If nothing changed for cust_acct_site, then skip processing
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      -- Record has changed
      IF l_ovn <> p_site_rec.cust_acct_sites_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_cust_account_site_v2pub.update_cust_acct_site(p_init_msg_list         => 'T',
				       p_cust_acct_site_rec    => p_site_rec.cust_site_rec,
				       p_object_version_number => p_site_rec.cust_acct_sites_ovn,
				       x_return_status         => x_return_status,
				       x_msg_count             => l_msg_count,
				       x_msg_data              => l_msg_data);

    END IF;

    write_log('Cust Site API ' || l_action || ' return status: ' ||
	  x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'Cust Site API ' || l_action || 'Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END CUST_ACCOUNT_SITE_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END CUST_ACCOUNT_SITE_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END CUST_ACCOUNT_SITE_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in CUST_ACCOUNT_SITE_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END CUST_ACCOUNT_SITE_API (EXCEPTION)');
  END cust_account_site_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of customer site uses (hz_site_uses_all)
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET          CHG0035118. Initial creation.
  -- 11/04/2015    Dipta Chatterjee  CHG0036940 - Reset Gl accounts for non BILL_TO sites
  -- -------------------------------------------------------------------------------
  PROCEDURE cust_account_site_use_api(p_site_rec       IN OUT customer_site_rec,
			  x_return_message OUT VARCHAR2,
			  x_return_status  OUT VARCHAR2) IS
    t_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;

    l_action         VARCHAR2(15);
    l_ovn            hz_cust_site_uses.object_version_number%TYPE;
    l_chg_flag       VARCHAR2(1);
    l_populated_flag VARCHAR2(1);

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    l_party_name    VARCHAR2(360) := NULL;
    l_location_s    NUMBER := 0;

    e_skip  EXCEPTION;
    e_error EXCEPTION;
  BEGIN
    write_log('START CUST_ACCOUNT_SITE_USE_API');
    fnd_msg_pub.initialize;

    is_site_changed(p_site_rec       => p_site_rec,
	        p_type           => 'CUST_SITE_USE',
	        x_chg_flag       => l_chg_flag,
	        x_populated_flag => l_populated_flag,
	        x_ovn            => l_ovn);

    IF p_site_rec.cust_site_use_rec.site_use_id IS NULL THEN
      l_action := 'Create';

      -- If nothing populated for site use, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      /* CHG0036940 - Dipta - Bug Fix - Reset GL Accounts for non BILL_TO site use*/
      IF p_site_rec.cust_site_use_rec.site_use_code <> 'BILL_TO' THEN
        p_site_rec.cust_site_use_rec.gl_id_rec      := NULL;
        p_site_rec.cust_site_use_rec.gl_id_rev      := NULL;
        p_site_rec.cust_site_use_rec.gl_id_tax      := NULL;
        p_site_rec.cust_site_use_rec.gl_id_freight  := NULL;
        p_site_rec.cust_site_use_rec.gl_id_clearing := NULL;
        p_site_rec.cust_site_use_rec.gl_id_unbilled := NULL;
        p_site_rec.cust_site_use_rec.gl_id_unearned := NULL;
      END IF;
      /* CHG0036940 - Dipta - End Bug Fix*/

      hz_cust_account_site_v2pub.create_cust_site_use(p_init_msg_list        => 'T',
				      p_cust_site_use_rec    => p_site_rec.cust_site_use_rec,
				      p_customer_profile_rec => t_customer_profile_rec,
				      p_create_profile       => 'F',
				      p_create_profile_amt   => 'F',
				      x_site_use_id          => p_site_rec.cust_site_use_rec.site_use_id,
				      x_return_status        => x_return_status,
				      x_msg_count            => l_msg_count,
				      x_msg_data             => l_msg_data);

    ELSE

      l_action := 'Update';
      -- If nothing changed for site use, skip processing
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      -- Record has changed
      IF l_ovn <> p_site_rec.cust_site_use_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_cust_account_site_v2pub.update_cust_site_use(p_init_msg_list         => 'T',
				      p_cust_site_use_rec     => p_site_rec.cust_site_use_rec,
				      p_object_version_number => p_site_rec.cust_site_use_ovn,
				      x_return_status         => x_return_status,
				      x_msg_count             => l_msg_count,
				      x_msg_data              => l_msg_data);
    END IF;

    write_log('Cust Site Use API ' || l_action || ' return status: ' ||
	  x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'Cust Site Use API ' || l_action || 'Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END CUST_ACCOUNT_SITE_USE_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END CUST_ACCOUNT_SITE_USE_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END CUST_ACCOUNT_SITE_USE_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in CUST_ACCOUNT_SITE_USE_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END CUST_ACCOUNT_SITE_USE_API (EXCEPTION)');
  END cust_account_site_use_api;

  -- ----------------------------------------------------------------------------------------------------------
  -- Purpose  : Checks for duplicate site/locations on the customer.  The p_match_type determines if we are
  --            doing a LIKE match or EXACT match (EXACT match would end at Step 2.1 ADDRESS_EXACT).  The LIKE
  --            match is essentially done in three steps.
  --
  --            Step 1: Look for mctching sites/locations WITHIN the customer we are
  --                    trying to find site matches on.  First, we execute the C_TO_SITES
  --                    CURSOR looking for a matching city, state, first 5 of postal, and province
  --                    This, in itself, does not mean we have a match.
  --
  --            Step 2: The 'match' column of the C_TO_SITES CURSOR attempts to match
  --                    on address (combo of all address lines).  There are four possible ways
  --                    to match here...
  --                        1)  ADDRESS_EXACT
  --                              Case insensitive address match
  --                        * Notice that each of the below matches can be disabled via the flexfield
  --                          on the XXHZ_CUSTOMER_DUP_CRITERIA lookup where lookup_code = 'SITE MATCHING'.
  --                          The p_dsbl_mtch_... field is set for each of the match criteria below based
  --                          on this look up's flex values.
  --                        2)  ADDRESS_EXACT_MINUS_SPECIAL
  --                              Case insensitive address match minus special characters
  --                        3)  ADDRESS_NUMBERS_MATCH
  --                              If p_number_compare_threshold amount of numbers match in the
  --                              addresses.  For example, if p_number_compare_threshold was 4,
  --                              and we had 1234 Anywhere St. and 1234 Anywhere Street, this
  --                              would be a match.
  --                        4)  ADDRESS_SOUNDS_LIKE
  --                              Uses Oracle SOUNDEX funtion to attempt to find similar sounding addresses
  --
  --            Step 3: If none of the matches above occur, then PART_OF_ADDRESS_LIKE matching will occur.
  --                    This couldn't be done with regular SQL, which is why the logic was not performed in the
  --                    CURSOR.  Basically, it attempts to find similar words within an address.  If it finds
  --                    greater than a certain percent of like words (49 percent, which is again defined on the
  --                    XXHZ_CUSTOMER_DUP_CRITERIA lookup where lookup_code = 'SITE MATCHING' flex), we have
  --                    a match.  For example, lets say we have the following two addresses...
  --                          Inbound Address   - 1 Armory Sq PO Box 9000
  --                          Existing Address  - 1 Armory Square
  --                    The logic would find a match on "1", "Armory", and "Sq" (since Square would evaluate to LIKE Sq)
  --                    Since 3 out of 5 words of the inbound address match, which is greater than 49 percent, this
  --                    would get returned as a matching address.
  --
  --            The Tech Design contains full details of each of these.
  --
  -- Change History
  -- ...........................................................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -----------------------------------------------------------------------------------------------------------
  PROCEDURE find_duplicate_sites(p_match_type      IN VARCHAR2 DEFAULT 'LIKE',
		         p_cust_account_id IN NUMBER,
		         p_location_id     IN NUMBER,
		         p_address1        IN VARCHAR2,
		         p_address2        IN VARCHAR2,
		         p_address3        IN VARCHAR2,
		         p_address4        IN VARCHAR2,
		         p_city            IN VARCHAR2,
		         p_state           IN VARCHAR2,
		         p_province        IN VARCHAR2,
		         p_postal_code     IN VARCHAR2,
		         p_country         IN VARCHAR2,
		         p_dup_sites_tbl   IN OUT dup_tbl,
		         x_return_status   OUT VARCHAR2,
		         x_return_message  OUT VARCHAR2) IS
    -- This CURSOR is use to find duplicate sites WITHIN a customer.  The join clause
    -- is the first phase of finding matches.  We are looking for matching at the
    -- city, state, first 5 of postal, and province.  Next, the CASE statement of the
    -- 'match' column attempts to match several different ways.
    CURSOR c_to_sites(p_cust_account_id             NUMBER,
	          p_location_id                 NUMBER,
	          p_address                     VARCHAR2,
	          p_city                        VARCHAR2,
	          p_state                       VARCHAR2,
	          p_province                    VARCHAR2,
	          p_postal_code                 VARCHAR2,
	          p_dsbl_mtch_addr_no_spcl_flag VARCHAR2,
	          p_dsbl_mtch_addr_numbers_flag VARCHAR2,
	          p_dsbl_mtch_addr_soundx_flag  VARCHAR2,
	          p_dsbl_mtch_addr_like_flag    VARCHAR2,
	          p_number_compare_threshold    NUMBER) IS
      SELECT DISTINCT hca.cust_account_id cust_account_id,
	          hcasa.cust_acct_site_id cust_acct_site_id,
	          hcasa.status cust_acct_status,
	          hps.party_site_id party_site_id,
	          hps.party_site_number party_site_number,
	          hl.location_id location_id,
	          hl.address1 || hl.address2 || hl.address3 address,
	          upper(hl.address1) address1,
	          upper(hl.address2) address2,
	          upper(hl.address3) address3,
	          upper(hl.address4) address4,
	          upper(hl.city) city,
	          upper(hl.state) state,
	          upper(hl.province) province,
	          upper(hl.postal_code) postal_code,
	          country country,
	          CASE
	          -- Check for exact match
		WHEN upper(hl.address1 || hl.address2 || hl.address3) =
		     upper(p_address) THEN
		 'ADDRESS_EXACT'
	          -- Check for match with special chars stripped out
		WHEN regexp_replace(upper(p_address),
			        '[]~!@#$%^&*()_+=\{}[:¿;¿<,>./?-]+',
			        '') =
		     regexp_replace(upper(hl.address1 || hl.address2 ||
				  hl.address3),
			        '[]~!@#$%^&*()_+=\{}[:¿;¿<,>./?-]+',
			        '') AND
		     nvl(p_dsbl_mtch_addr_no_spcl_flag, 'N') <> 'Y' THEN
		 'ADDRESS_EXACT_MINUS_SPECIAL'
	          -- Check that address numbers match if the number of numbers in address is > p_number_compare_threshold
		WHEN length(regexp_replace(p_address, '[^0-9]', '')) >
		     p_number_compare_threshold AND
		     regexp_replace(p_address, '[^0-9]', '') =
		     regexp_replace(hl.address1 || hl.address2 ||
			        hl.address3,
			        '[^0-9]',
			        '') AND
		     nvl(p_dsbl_mtch_addr_numbers_flag, 'N') <> 'Y' THEN
		 'ADDRESS_NUMBERS_MATCH'
	          -- Check for sounds like match
		WHEN soundex(upper(p_address)) =
		     soundex(upper(hl.address1 || hl.address2 ||
			       hl.address3)) AND
		     regexp_replace(p_address, '[^0-9]', '') =
		     regexp_replace(hl.address1 || hl.address2 ||
			        hl.address3,
			        '[^0-9]',
			        '') AND
		     nvl(p_dsbl_mtch_addr_soundx_flag, 'N') <> 'Y' THEN
		 'ADDRESS_SOUNDS_LIKE'
		ELSE
		 'N'
	          END match
      FROM   hz_cust_accounts_all   hca,
	 hz_cust_acct_sites_all hcasa,
	 hz_party_sites         hps,
	 hz_locations           hl
      WHERE  hca.cust_account_id = hcasa.cust_account_id
      AND    hcasa.party_site_id = hps.party_site_id
      AND    hps.location_id = hl.location_id
	-- Exclude OBJET US
	-- AND   hcasa.org_id                          <> 89
      AND    nvl(upper(hl.city), 'X') = nvl(upper(p_city), 'X')
      AND    nvl(upper(hl.state), 'X') = nvl(upper(p_state), 'X')
      AND    nvl(upper(hl.province), 'X') = nvl(upper(p_province), 'X')
	--AND   NVL(SUBSTR(hl.postal_code,1,5),'X')   = NVL(SUBSTR(p_postal_code,1,5),'X')
      AND    ((hl.postal_code IS NULL OR p_postal_code IS NULL) OR
	(hl.postal_code IS NOT NULL AND p_postal_code IS NOT NULL AND
	substr(hl.postal_code, 1, 5) = substr(p_postal_code, 1, 5)))
      AND    hl.location_id <> nvl(p_location_id, -9)
      AND    hca.cust_account_id = p_cust_account_id
      ORDER  BY match;

    l_first_number NUMBER;
    l_numeric_flag BOOLEAN;

    l_from_address_clean VARCHAR2(2000);
    l_to_address_clean   VARCHAR2(2000);

    l_from_address VARCHAR2(2000);
    l_to_address   VARCHAR2(2000);

    l_from_address_numbers VARCHAR2(2000);
    l_to_address_numbers   VARCHAR2(2000);

    l_space_count1  NUMBER := 0;
    l_space_count2  NUMBER := 0;
    l_space_count   NUMBER := 0;
    l_address1_part VARCHAR2(2000);
    l_address2_part VARCHAR2(2000);

    l_match_count NUMBER := 0;

    l_address VARCHAR2(2000);
    l_match   VARCHAR2(30);
    l_counter NUMBER := 1;

    -- Match Values
    l_number_compare_threshold    NUMBER;
    l_address_like_threshold      NUMBER;
    l_dsbl_mtch_addr_no_spcl_flag VARCHAR2(1) DEFAULT 'N';
    l_dsbl_mtch_addr_numbers_flag VARCHAR2(1) DEFAULT 'N';
    l_dsbl_mtch_addr_soundx_flag  VARCHAR2(1) DEFAULT 'N';
    l_dsbl_mtch_addr_like_flag    VARCHAR2(1) DEFAULT 'N';

    l_curr_location_rec hz_locations%ROWTYPE;

    e_skip    EXCEPTION;
    e_process EXCEPTION;
    e_bypass  EXCEPTION;
  BEGIN
    write_log('BEGIN FIND_DUPLICATE_SITES');
    write_log('p_dup_match_type: ' || p_match_type);

    -- Initialize x_return_status to success
    x_return_status := fnd_api.g_ret_sts_success;

    write_log('Getting Dynamic Comparison Values...');

    BEGIN
      -- Find lookup flex values which control some of the functionality
      -- of site searches.  See the TDD for full explanation.
      SELECT attribute1,
	 attribute2,
	 attribute3,
	 attribute4,
	 attribute5,
	 attribute6 / 100
      INTO   l_dsbl_mtch_addr_no_spcl_flag,
	 l_dsbl_mtch_addr_numbers_flag,
	 l_dsbl_mtch_addr_soundx_flag,
	 l_dsbl_mtch_addr_like_flag,
	 l_number_compare_threshold,
	 l_address_like_threshold
      FROM   fnd_lookup_values
      WHERE  lookup_type = 'XXHZ_CUSTOMER_DUP_CRITERIA'
      AND    lookup_code = 'SITE_MATCHING_VALUES'
      AND    LANGUAGE = userenv('LANG');

      write_log('Successfully retrieved Dynamic Comparison Values');
    EXCEPTION
      WHEN OTHERS THEN
        x_return_status  := fnd_api.g_ret_sts_error;
        x_return_message := 'Error Gathering Match Criteria: ' ||
		    dbms_utility.format_error_stack;
        RAISE e_bypass;
    END;

    l_address := p_address1 || p_address2 || p_address3;

    write_log('l_curr_location_rec.location_id: ' || p_location_id);
    write_log('l_address: ' || l_address);
    write_log('l_curr_location_rec.city: ' || p_city);
    write_log('l_curr_location_rec.state: ' || p_state);
    write_log('l_curr_location_rec.postal_code: ' || p_postal_code);
    write_log('l_number_compare_threshold: ' || l_number_compare_threshold);
    write_log('l_dsbl_mtch_addr_no_spcl_flag: ' ||
	  l_dsbl_mtch_addr_no_spcl_flag);
    write_log('l_dsbl_mtch_addr_numbers_flag: ' ||
	  l_dsbl_mtch_addr_numbers_flag);
    write_log('l_dsbl_mtch_addr_soundx_flag: ' ||
	  l_dsbl_mtch_addr_soundx_flag);
    write_log('l_dsbl_mtch_addr_like_flag: ' || l_dsbl_mtch_addr_like_flag);

    -- LOOP Matching Sites
    FOR rec_to IN c_to_sites(p_cust_account_id,
		     p_location_id,
		     l_address,
		     p_city,
		     p_state,
		     p_province,
		     p_postal_code,
		     l_dsbl_mtch_addr_no_spcl_flag,
		     l_dsbl_mtch_addr_numbers_flag,
		     l_dsbl_mtch_addr_soundx_flag,
		     l_dsbl_mtch_addr_like_flag,
		     l_number_compare_threshold) LOOP
      write_log('l_counter: ' || l_counter);
      write_log('rec_to.match: ' || rec_to.match);

      l_match := NULL;
      BEGIN
        l_match := rec_to.match;

        -- Handle exact matching
        IF p_match_type = 'EXACT' THEN
          -- If exact match, enter that record into dup table
          IF l_match = 'ADDRESS_EXACT' THEN
	RAISE e_process;

	-- If not exact match, skip to next record
          ELSE
	RAISE e_skip;
          END IF;
        END IF;

        -- This means we have some sort of match from CURSOR so record should be entered into
        -- duplicate tbl.
        IF rec_to.match <> 'N' THEN
          l_match := rec_to.match;
          RAISE e_process;
        END IF;

        -- If we've disabled address like matching, we will skip the next section of code
        IF nvl(l_dsbl_mtch_addr_like_flag, 'N') = 'Y' THEN
          RAISE e_skip;
        END IF;

        -- Remove all special characters except for space
        l_from_address_clean := regexp_replace(l_address,
			           '[]~!@#$%^&*()_+=\{}[:¿;¿<,>./?-]+',
			           '');
        l_to_address_clean   := regexp_replace(rec_to.address,
			           '[]~!@#$%^&*()_+=\{}[:¿;¿<,>./?-]+',
			           '');

        write_log('l_from_address_clean: ' || l_from_address_clean);
        write_log('l_to_address_clean: ' || l_to_address_clean);

        -- Count spaces to get word count in clean from address
        SELECT nvl(regexp_count(l_from_address_clean, ' '), 0)
        INTO   l_space_count1
        FROM   dual;

        -- Count spaces to get word count in clean to address
        SELECT nvl(regexp_count(l_to_address_clean, ' '), 0)
        INTO   l_space_count2
        FROM   dual;

        write_log('l_space_count1: ' || l_space_count1);
        write_log('l_space_count2: ' || l_space_count2);

        l_match_count   := 0;
        l_address1_part := NULL;

        -- Looks at the individual words in each address for similarities.  If more than one 'like' match on individual words
        -- return PART_OF_ADDRESS_LIKE
        -- First loop separates from address into individual words (separated by spaces)
        FOR i IN 1 .. l_space_count1 + 1 LOOP
          -- LOOP Words in l_from_address_clean
          -- Get individual word from address
          l_address1_part := regexp_substr(l_from_address_clean,
			       '[^' || ' ' || ']+',
			       1,
			       i);

          IF l_address1_part IS NOT NULL THEN
	-- separates to address into individual words (separated by spaces)
	FOR j IN 1 .. l_space_count2 + 1 LOOP
	  -- END LOOP Words in l_to_address_clean
	  -- Get individual word from address
	  l_address2_part := regexp_substr(l_to_address_clean,
			           '[^' || ' ' || ']+',
			           1,
			           j);

	  -- Compare individual word for from_address to individual word from to_address
	  -- or individual word for to_address to individual word from from_address
	  -- The regular expression adds percents after each letter, so if we were trying
	  -- to compare CURVE to CRV, it would evaluate as CURVE LIKE C%R%V%.  We would want
	  -- a match in this case.
	  IF l_address1_part LIKE
	     regexp_replace(l_address2_part, '([A-Za-z0-9])', '\1%') OR
	     l_address2_part LIKE
	     regexp_replace(l_address1_part, '([A-Za-z0-9])', '\1%') THEN

	    write_log('l_address1_part: ' || l_address1_part);
	    write_log('l_address2_part: ' || l_address2_part);

	    l_match_count := l_match_count + 1;
	  END IF;
	END LOOP; -- END LOOP Words in l_to_address_clean
          END IF;
        END LOOP; -- END LOOP Words in l_from_address_clean

        -- Get space count of the smallest address
        l_space_count := least(l_space_count2, l_space_count1);

        write_log('l_space_count: ' || l_space_count);
        write_log('l_match_count: ' || l_match_count);

        IF l_space_count > 0 THEN
          -- If p_address_like_threshold (percentage) or more of the words in the smallest address have a like match to
          -- a word in the other address, we consider this a match.
          IF (l_match_count / (l_space_count + 1)) >
	 l_address_like_threshold THEN
	l_match := 'PART_OF_ADDRESS_LIKE';
	RAISE e_process;
          END IF;
        END IF;
      EXCEPTION
        -- Process record into p_dup_sites_tbl
        WHEN e_process THEN
          x_return_status  := 'D';
          x_return_message := 'Duplicates Exist';

          write_log('rec_to.cust_acct_site_id: ' ||
	        rec_to.cust_acct_site_id);

          -- Populate outbound table with duplicate records
          p_dup_sites_tbl(l_counter).match_type := l_match;
          p_dup_sites_tbl(l_counter).num1 := rec_to.party_site_id;
          p_dup_sites_tbl(l_counter).num2 := rec_to.cust_account_id;
          p_dup_sites_tbl(l_counter).id1 := rec_to.cust_acct_site_id;
          p_dup_sites_tbl(l_counter).num3 := rec_to.location_id;
          p_dup_sites_tbl(l_counter).char1 := rec_to.party_site_number;
          p_dup_sites_tbl(l_counter).char2 := rec_to.address1;
          p_dup_sites_tbl(l_counter).char3 := rec_to.address2;
          p_dup_sites_tbl(l_counter).char4 := rec_to.address3;
          p_dup_sites_tbl(l_counter).char5 := rec_to.address4;
          p_dup_sites_tbl(l_counter).char6 := rec_to.city;
          p_dup_sites_tbl(l_counter).char7 := rec_to.state;
          p_dup_sites_tbl(l_counter).char8 := rec_to.postal_code;
          p_dup_sites_tbl(l_counter).char9 := rec_to.province;
          p_dup_sites_tbl(l_counter).char10 := rec_to.country;
          p_dup_sites_tbl(l_counter).char11 := rec_to.cust_acct_status;

          l_counter := l_counter + 1;
        WHEN e_skip THEN
          write_log('Not exact match - Skip to next record');
        WHEN OTHERS THEN
          RAISE;
      END;
    END LOOP; -- END LOOP Matching Sites

    write_log('END FIND_DUPLICATE_SITES');
  EXCEPTION
    -- no error, skipping processing
    WHEN e_bypass THEN
      write_log('END FIND_DUPLICATE_SITES (E_BYPASS)');
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in FIND_DUPLICATE_SITES: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END FIND_DUPLICATE_SITES (EXCEPTION)');
  END find_duplicate_sites;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of customer site related entities
  --            This is the main entry point for sites.
  --
  -- Parameters : p_match_type
  --                This will be 'LIKE' or 'EXACT'.  Depending on how this is set, the
  --                p_dup_acct_tbl will contain records that are LIKE or and EXACT
  --                match to the customer being created/updated.
  --              p_match_only
  --                This will force the program to exit after calling
  --                find_duplicate_sites.
  --              p_dup_sites_tbl
  --                Returns a table type of any maching sites for inbound sites
  --              x_wf_return_message
  --                returns workflow message from handle_custom_wf
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET          CHG0035118. Initial creation.
  -- 11/04/2015    Dipta Chatterjee  CHG0036940 - Duplicate checking to be restricted
  --                                 for new creations only
  -- -------------------------------------------------------------------------------
  PROCEDURE handle_sites(p_dup_match_type    IN VARCHAR2 DEFAULT 'LIKE',
		 p_cust_site_rec     IN OUT customer_site_rec,
		 p_dup_sites_tbl     OUT dup_tbl,
		 x_return_message    OUT VARCHAR2,
		 x_return_status     OUT VARCHAR2,
		 x_wf_return_message OUT VARCHAR2) IS
    l_dup_sites_tbl dup_tbl;
    l_acc_rec       customer_rec;

    l_location_ovn      hz_parties.object_version_number%TYPE;
    l_party_site_ovn    hz_cust_accounts_all.object_version_number%TYPE;
    l_cust_site_ovn     hz_parties.object_version_number%TYPE;
    l_cust_site_use_ovn hz_cust_accounts_all.object_version_number%TYPE;

    /* CHG0036940 - Dipta - Bug Fix - variable to check for new records only*/
    l_new_flag VARCHAR2(1) := 'N';
    /* END CHG0036940 - Dipta*/

    l_site_use_count         NUMBER := 0;
    l_site_use_value         hz_cust_site_uses_all.site_use_code%TYPE;
    l_site_use_all_value     hz_cust_site_uses_all.site_use_code%TYPE;
    l_site_use_id            hz_cust_site_uses_all.site_use_id%TYPE;
    l_disable_dup_check_flag VARCHAR2(1) := 'N';
    l_chg_flag               VARCHAR2(1) := 'N';

    l_populated_flag VARCHAR2(1) := 'N';

    e_error EXCEPTION;
  BEGIN
    write_log('BEGIN HANDLE_SITES');

    mo_global.init('AR');

    -- ****************************************************************************
    -- handle checking and submitting custom workflow
    -- ****************************************************************************
    handle_custom_wf(p_acc_rec        => l_acc_rec,
	         p_site_rec       => p_cust_site_rec,
	         p_entity_code    => 'CUST_PAY_TERM',
	         x_return_status  => x_return_status,
	         x_return_message => x_return_message);

    write_log('handle_custom_wf return_status: ' || x_return_status);
    write_log('handle_custom_wf return_message: ' || x_return_message);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- Load return message into x_wf_return_message
    IF x_return_message IS NOT NULL THEN
      x_wf_return_message := x_wf_return_message || '~' || x_return_message;
    END IF;

    write_log('x_wf_return_message: ' || x_wf_return_message);

    -- ****************************************************************************
    -- Validate sites
    -- ****************************************************************************
    validate_site(p_site_rec       => p_cust_site_rec,
	      x_return_status  => x_return_status,
	      x_return_message => x_return_message);

    write_log('validate_site return_status: ' || x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- Check for duplicate sites
    -- ****************************************************************************

    -- Check if profile for diabling duplicate checking
    l_disable_dup_check_flag := fnd_profile.value('XXHZ_CUSTOMER_SITE_DISABLE_DUP_CHECK');
    write_log('l_disable_dup_check_flag: ' || l_disable_dup_check_flag);

    IF nvl(l_disable_dup_check_flag, 'N') = 'N' THEN

      -- Check to see if any of the location columns have changed if this is an existing
      -- record.  If any of the location columns have changed, we need to perform checking
      -- for duplicate location.
      IF p_cust_site_rec.location_rec.location_id IS NOT NULL THEN
        is_site_changed(p_site_rec       => p_cust_site_rec,
		p_type           => 'LOCATION',
		x_chg_flag       => l_chg_flag,
		x_populated_flag => l_populated_flag,
		x_ovn            => l_location_ovn);

        /* CHG0036940 - Dipta - Bug Fix - existing records*/
        l_new_flag := 'N';
        /* END CHG0036940 - Dipta*/
      ELSE
        -- Forces duplicate check if new record
        l_chg_flag := 'Y';
        /* CHG0036940 - Dipta - Bug Fix - existing records*/
        l_new_flag := 'Y';
        /* END CHG0036940 - Dipta*/
      END IF;

      write_log('SITE l_chg_flag: ' || l_chg_flag);
      write_log('SITE l_new_flag: ' || l_new_flag);
      -- If the location record is new or changed, we need to check for duplicates
      /* CHG0036940 - Dipta - Bug Fix - existing records*/
      IF l_new_flag = 'Y' THEN
        /* END CHG0036940 - Dipta*/
        IF l_chg_flag = 'Y' THEN
          find_duplicate_sites(p_match_type      => p_dup_match_type,
		       p_cust_account_id => p_cust_site_rec.cust_site_rec.cust_account_id,
		       p_location_id     => p_cust_site_rec.location_rec.location_id,
		       p_address1        => p_cust_site_rec.location_rec.address1,
		       p_address2        => p_cust_site_rec.location_rec.address2,
		       p_address3        => p_cust_site_rec.location_rec.address3,
		       p_address4        => p_cust_site_rec.location_rec.address4,
		       p_city            => p_cust_site_rec.location_rec.city,
		       p_state           => p_cust_site_rec.location_rec.state,
		       p_province        => p_cust_site_rec.location_rec.province,
		       p_postal_code     => p_cust_site_rec.location_rec.postal_code,
		       p_country         => p_cust_site_rec.location_rec.country,
		       p_dup_sites_tbl   => p_dup_sites_tbl,
		       x_return_status   => x_return_status,
		       x_return_message  => x_return_message);
        END IF;
        /* CHG0036940 - Dipta - Bug Fix - existing records*/
      END IF;
      /* END CHG0036940 - Dipta*/

      write_log('find_duplicate_sites return_status: ' || x_return_status);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;
    END IF;

    -- ****************************************************************************
    -- handle location
    -- ****************************************************************************
    location_api(p_site_rec       => p_cust_site_rec,
	     x_return_status  => x_return_status,
	     x_return_message => x_return_message);

    write_log('location_api return_status: ' || x_return_status);
    write_log('location_id: ' || p_cust_site_rec.location_rec.location_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle party site
    -- ****************************************************************************
    IF p_cust_site_rec.party_site_rec.location_id IS NULL THEN
      p_cust_site_rec.party_site_rec.location_id := p_cust_site_rec.location_rec.location_id;
    END IF;

    party_site_api(p_site_rec       => p_cust_site_rec,
	       x_return_status  => x_return_status,
	       x_return_message => x_return_message);

    write_log('party_site_api return_status: ' || x_return_status);
    write_log('party_site_id: ' ||
	  p_cust_site_rec.party_site_rec.party_site_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle cust site
    -- ****************************************************************************
    IF p_cust_site_rec.cust_site_rec.party_site_id IS NULL THEN
      p_cust_site_rec.cust_site_rec.party_site_id := p_cust_site_rec.party_site_rec.party_site_id;
    END IF;

    cust_account_site_api(p_site_rec       => p_cust_site_rec,
		  x_return_status  => x_return_status,
		  x_return_message => x_return_message);

    write_log('cust_account_site_api return_status: ' || x_return_status);
    write_log('cust_acct_site_id: ' ||
	  p_cust_site_rec.cust_site_rec.cust_acct_site_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle cust site use
    -- ****************************************************************************
    IF p_cust_site_rec.cust_site_use_rec.cust_acct_site_id IS NULL THEN
      p_cust_site_rec.cust_site_use_rec.cust_acct_site_id := p_cust_site_rec.cust_site_rec.cust_acct_site_id;
    END IF;

    -- site_use_id for updates from the form will be populated.  However, SFDC does not store to the site_use_id
    -- level.  site_use_id will be derived for SFDC based on the site_use_code and cust_acct_site_id.
    IF p_cust_site_rec.cust_site_use_rec.site_use_id IS NOT NULL THEN
      l_site_use_id        := p_cust_site_rec.cust_site_use_rec.site_use_id;
      l_site_use_count     := 1;
      l_site_use_all_value := p_cust_site_rec.cust_site_use_rec.site_use_code;
    ELSE
      -- Valid Site use codes come in as Bill To, Ship To, or Bill To/Ship To from Salesforce.  Code below will make
      -- multiple calls to cust_account_site_use_api, if SITE_USE_CODE contains '/'.  It will also
      -- find the correct lookup_code to pass through.  Calls from the form will come through with one value,
      -- BILL_TO, SHIP_TO, etc.  It's important to note that SFDC does not store site_use_ids, so they essentially
      -- need to be derived for updates.
      l_site_use_all_value := p_cust_site_rec.cust_site_use_rec.site_use_code;
      l_site_use_count     := regexp_count(l_site_use_all_value, '/') + 1;
    END IF;

    write_log('l_site_use_all_value: ' || l_site_use_all_value);
    write_log('l_site_use_count: ' || l_site_use_count);

    FOR i IN 1 .. l_site_use_count LOOP
      -- REGEXP will handle multi values from SFDC or single value from form or SFDC
      l_site_use_value := regexp_substr(l_site_use_all_value,
			    '[^' || '/' || ']+',
			    1,
			    i);
      write_log('l_site_use_value: ' || l_site_use_value);

      -- Gets Oracle lookup code value to send to API
      p_cust_site_rec.cust_site_use_rec.site_use_code := get_lookup_code('PARTY_SITE_USE_CODE',
						 l_site_use_value);

      IF p_cust_site_rec.cust_site_use_rec.site_use_code IS NULL THEN
        x_return_message := 'Error: ' ||
		    p_cust_site_rec.cust_site_use_rec.site_use_code ||
		    ' is invalid.';
        x_return_status  := fnd_api.g_ret_sts_error;
        RAISE e_error;
      END IF;

      -- Finds existing site_use_id based on cust_acct_site_id and site_use_code, if there is one.  If there isn't
      -- one, cust_account_site_use_api will create one.  For SFDC this is used for update.
      IF l_site_use_id IS NULL THEN
        p_cust_site_rec.cust_site_use_rec.site_use_id := get_site_use_id(p_cust_site_rec.cust_site_use_rec.cust_acct_site_id,
						 p_cust_site_rec.cust_site_use_rec.site_use_code);

        write_log('p_cust_site_rec.cust_site_use_rec.site_use_id: ' ||
	      p_cust_site_rec.cust_site_use_rec.site_use_id);
        write_log('l_site_use_id: ' || l_site_use_id);
      END IF;

      cust_account_site_use_api(p_site_rec       => p_cust_site_rec,
		        x_return_status  => x_return_status,
		        x_return_message => x_return_message);

      write_log('cust_account_site_use_api return_status: ' ||
	    x_return_status);
      write_log('site_use_id: ' ||
	    p_cust_site_rec.cust_site_use_rec.site_use_id);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;
    END LOOP;

    -- ****************************************************************************
    -- handle cust profiles
    -- ****************************************************************************
    write_log('p_cust_site_rec.cust_profile_rec.cust_account_profile_id: ' ||
	  p_cust_site_rec.cust_profile_rec.cust_account_profile_id);

    IF p_cust_site_rec.cust_profile_rec.cust_account_profile_id IS NULL THEN
      p_cust_site_rec.cust_profile_rec.cust_account_id := p_cust_site_rec.cust_site_rec.cust_account_id;
      p_cust_site_rec.cust_profile_rec.site_use_id     := p_cust_site_rec.cust_site_use_rec.site_use_id;
    END IF;

    -- NOTE - This API is in the customer section as it is shared by for account and site use profiles.
    cust_profile_api(p_profile_level        => 'SITE_USE',
	         p_ovn                  => p_cust_site_rec.cust_profile_ovn,
	         p_customer_profile_rec => p_cust_site_rec.cust_profile_rec,
	         x_return_status        => x_return_status,
	         x_return_message       => x_return_message);

    write_log('cust_profile_api return_status: ' || x_return_status);
    write_log('cust_account_profile_id: ' ||
	  p_cust_site_rec.cust_profile_rec.cust_account_profile_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle cust profile amounts
    -- ****************************************************************************
    IF p_cust_site_rec.cust_profile_amt_rec.cust_acct_profile_amt_id IS NULL THEN
      p_cust_site_rec.cust_profile_amt_rec.cust_account_profile_id := p_cust_site_rec.cust_profile_rec.cust_account_profile_id;
      p_cust_site_rec.cust_profile_amt_rec.cust_account_id         := p_cust_site_rec.cust_site_rec.cust_account_id;
      p_cust_site_rec.cust_profile_amt_rec.site_use_id             := p_cust_site_rec.cust_site_use_rec.site_use_id;
    END IF;

    -- NOTE - This API is in the customer section as it is shared by for account and site use profile amounts.
    cust_profile_amount_api(p_profile_level        => 'SITE_USE',
		    p_ovn                  => p_cust_site_rec.cust_profile_amt_ovn,
		    p_cust_profile_amt_rec => p_cust_site_rec.cust_profile_amt_rec,
		    x_return_status        => x_return_status,
		    x_return_message       => x_return_message);

    write_log('cust_profile_amount_api return_status: ' || x_return_status);
    write_log('cust_acct_profile_amt_id: ' ||
	  p_cust_site_rec.cust_profile_amt_rec.cust_acct_profile_amt_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    write_log('END HANDLE_SITES');
  EXCEPTION
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('BEGIN HANDLE_SITES (E_EXCEPTION)');
    WHEN OTHERS THEN
      x_return_message := 'Error in HANDLE_SITES: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END HANDLE_SITES (EXCEPTION)');
  END handle_sites;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Wrapper procedure called by XXHZCUSTOMER.fmb to call handle_site.
  --            Form had issues with using Oracle's standard hz_location_v2pub.location_rec_type
  --            because of it's use of global variables.  We need to load the location info
  --            from the form's location record type into Oracle's
  --            hz_location_v2pub.location_rec_type for use with Oracle's APIs.
  --            We then call handle_sites to process records, then move the location
  --            records from the standard location type back to the form's location type.
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE frm_handle_sites(p_dup_match_type    IN VARCHAR2 DEFAULT 'LIKE',
		     p_cust_site_rec     IN OUT frm_customer_site_rec,
		     p_dup_sites_tbl     OUT dup_tbl,
		     x_return_message    OUT VARCHAR2,
		     x_return_status     OUT VARCHAR2,
		     x_wf_return_message OUT VARCHAR2) IS
    l_customer_site_rec customer_site_rec;
  BEGIN
    write_log('START FRM_HANDLE_SITES');

    -- Assign matching record types, including converting form version of location rec to Oracle API version
    -- of location rec.
    l_customer_site_rec.location_rec         := load_location_rec(p_cust_site_rec.location_rec);
    l_customer_site_rec.party_site_rec       := p_cust_site_rec.party_site_rec;
    l_customer_site_rec.cust_site_rec        := p_cust_site_rec.cust_site_rec;
    l_customer_site_rec.cust_site_use_rec    := p_cust_site_rec.cust_site_use_rec;
    l_customer_site_rec.cust_profile_rec     := p_cust_site_rec.cust_profile_rec;
    l_customer_site_rec.cust_profile_amt_rec := p_cust_site_rec.cust_profile_amt_rec;
    l_customer_site_rec.location_ovn         := p_cust_site_rec.location_ovn;
    l_customer_site_rec.party_site_ovn       := p_cust_site_rec.party_site_ovn;
    l_customer_site_rec.cust_acct_sites_ovn  := p_cust_site_rec.cust_acct_sites_ovn;
    l_customer_site_rec.cust_site_use_ovn    := p_cust_site_rec.cust_site_use_ovn;
    l_customer_site_rec.cust_profile_ovn     := p_cust_site_rec.cust_profile_ovn;
    l_customer_site_rec.cust_profile_amt_ovn := p_cust_site_rec.cust_profile_amt_ovn;

    -- Call main handling procedure for sites
    handle_sites(p_dup_match_type    => p_dup_match_type,
	     p_cust_site_rec     => l_customer_site_rec,
	     p_dup_sites_tbl     => p_dup_sites_tbl,
	     x_return_message    => x_return_message,
	     x_return_status     => x_return_status,
	     x_wf_return_message => x_wf_return_message);

    -- Assign matching record types, including converting Oracle API version of location rec to form version
    -- of location rec.
    p_cust_site_rec.location_rec         := load_location_rec(l_customer_site_rec.location_rec);
    p_cust_site_rec.party_site_rec       := l_customer_site_rec.party_site_rec;
    p_cust_site_rec.cust_site_rec        := l_customer_site_rec.cust_site_rec;
    p_cust_site_rec.cust_site_use_rec    := l_customer_site_rec.cust_site_use_rec;
    p_cust_site_rec.cust_profile_rec     := l_customer_site_rec.cust_profile_rec;
    p_cust_site_rec.cust_profile_amt_rec := l_customer_site_rec.cust_profile_amt_rec;
    p_cust_site_rec.location_ovn         := l_customer_site_rec.location_ovn;
    p_cust_site_rec.party_site_ovn       := l_customer_site_rec.party_site_ovn;
    p_cust_site_rec.cust_acct_sites_ovn  := l_customer_site_rec.cust_acct_sites_ovn;
    p_cust_site_rec.cust_site_use_ovn    := l_customer_site_rec.cust_site_use_ovn;
    p_cust_site_rec.cust_profile_ovn     := l_customer_site_rec.cust_profile_ovn;
    p_cust_site_rec.cust_profile_amt_ovn := l_customer_site_rec.cust_profile_amt_ovn;

    write_log('Return Status from handle_sites: ' || x_return_status);
    write_log('END FRM_HANDLE_SITES');
  EXCEPTION
    WHEN OTHERS THEN
      x_return_message := 'Error in FRM_HANDLE_SITES: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END FRM_HANDLE_SITES (EXCEPTION)');
  END frm_handle_sites;

  ----------------------------------------------------------------------------------
  -- Purpose  : Handles checking for record changes from ON-LOCK trigger of XXHZCUSTOMER
  --            form.  Uses object version number to identify any changes on any of the
  --            entities.  See handle_account_lock procedure or TDD for more information
  --            on how this works.
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  ----------------------------------------------------------------------------------
  PROCEDURE handle_site_lock(p_cust_site_rec  IN OUT frm_customer_site_rec,
		     x_return_status  OUT VARCHAR2,
		     x_return_message OUT VARCHAR2) IS
    l_ovn hz_parties.object_version_number%TYPE;
    e_error EXCEPTION;
  BEGIN
    g_program_unit := 'HANDLE_SITE_LOCK';
    write_log('START ' || g_program_unit);

    l_ovn := get_object_version_number('LOCATION',
			   p_cust_site_rec.location_rec.location_id);
    IF p_cust_site_rec.location_ovn <> l_ovn THEN
      write_log('HZ_LOCATIONS changed');
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('PARTY_SITE',
			   p_cust_site_rec.party_site_rec.party_site_id);
    IF p_cust_site_rec.party_site_ovn <> l_ovn THEN
      write_log('HZ_PARTY_SITES changed');
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('CUST_SITE',
			   p_cust_site_rec.cust_site_rec.cust_acct_site_id);
    IF p_cust_site_rec.cust_acct_sites_ovn <> l_ovn THEN
      write_log('HZ_CUST_ACCT_SITES changed');
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('SITE_USE',
			   p_cust_site_rec.cust_site_use_rec.site_use_id);
    IF p_cust_site_rec.cust_site_use_ovn <> l_ovn THEN
      write_log('HZ_CUST_SITE_USES changed');
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('CUST_PROFILE',
			   p_cust_site_rec.cust_profile_rec.cust_account_profile_id);
    IF p_cust_site_rec.cust_profile_ovn <> l_ovn THEN
      write_log('HZ_CUSTOMER_PROFILES changed');
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('CUST_PROFILE_AMT',
			   p_cust_site_rec.cust_profile_amt_rec.cust_acct_profile_amt_id);
    IF p_cust_site_rec.cust_profile_amt_ovn <> l_ovn THEN
      write_log('HZ_CUST_PROFILE_AMTS changed');
      RAISE e_error;
    END IF;

    write_log('END HANDLE_SITE_LOCK');
  EXCEPTION
    WHEN e_error THEN
      fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
      x_return_message := fnd_message.get;
      x_return_status  := 'E';
      write_log('END HANDLE_SITE_LOCK (E_ERROR)');
    WHEN OTHERS THEN
      x_return_message := 'Error in ' || g_program_unit || ': ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := 'E';
      write_log('END HANDLE_SITE_LOCK (EXCEPTION)');
  END handle_site_lock;

  -- ------------------------------------------------------------------------------------------------------------------------------
  -- *******************************************  HANDLES CUSTOMER CONTACTS *******************************************************
  -- ------------------------------------------------------------------------------------------------------------------------------

  -- -------------------------------------------------------------------------------
  -- Purpose  : Checks contact level data for...
  --                Contacts        - hz_parties, hz_relationships
  --                Contact Sites   - hz_locations, hz_party_sites
  --                Contact Site Use- hz_party_site_uses
  --                Contact Points  - hz_contact_points
  --                Contact Roles   - hz_role_responsibility
  --            ...for changes against the database.  is_modified will also set NULL
  --            values to fnd_api.g_miss values in the event of NULL input values vs
  --            database populated values.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- 1.1  22-Mar-2016 Lingaraj    CHG0037971 - SSYS Customer Maintenance form not handling contact DFF
  -- -------------------------------------------------------------------------------
  PROCEDURE is_contact_changed(p_customer_contact_rec IN OUT customer_contact_rec,
		       p_type                 IN VARCHAR2,
		       x_chg_flag             OUT VARCHAR2,
		       x_populated_flag       OUT VARCHAR2,
		       x_ovn                  OUT NUMBER) IS
    t_party_rec               hz_parties%ROWTYPE;
    t_cust_cont_role_rec      hz_cust_account_roles%ROWTYPE;
    t_cont_point_rec          hz_contact_points%ROWTYPE;
    t_cust_cont_role_resp_rec hz_role_responsibility%ROWTYPE;
    t_cust_cont_site_use_rec  hz_party_site_uses%ROWTYPE;

    l_populated_flag VARCHAR2(1);
  BEGIN
    write_log('BEGIN IS_CONTACT_CHANGED');

    IF p_type = 'PERSON' THEN
      x_chg_flag       := 'N';
      x_populated_flag := 'N';

      IF p_customer_contact_rec.cust_cont_person_rec.party_rec.party_id IS NOT NULL THEN
        SELECT *
        INTO   t_party_rec
        FROM   hz_parties
        WHERE  party_id =
	   p_customer_contact_rec.cust_cont_person_rec.party_rec.party_id;

        p_customer_contact_rec.cust_cont_person_rec.created_by_module := NULL;
      END IF;

      is_modified(t_party_rec.person_pre_name_adjunct,
	      p_customer_contact_rec.cust_cont_person_rec.person_pre_name_adjunct,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.person_first_name,
	      p_customer_contact_rec.cust_cont_person_rec.person_first_name,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.person_middle_name,
	      p_customer_contact_rec.cust_cont_person_rec.person_middle_name,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.person_last_name,
	      p_customer_contact_rec.cust_cont_person_rec.person_last_name,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_party_rec.person_name_suffix,
	      p_customer_contact_rec.cust_cont_person_rec.person_name_suffix,
	      x_chg_flag,
	      x_populated_flag);

      x_ovn := t_party_rec.object_version_number;
    END IF;

    IF p_type = 'ROLE' THEN
      x_chg_flag       := 'N';
      x_populated_flag := 'N';

      IF p_customer_contact_rec.cust_cont_role_rec.cust_account_role_id IS NOT NULL THEN
        SELECT *
        INTO   t_cust_cont_role_rec
        FROM   hz_cust_account_roles
        WHERE  cust_account_role_id =
	   p_customer_contact_rec.cust_cont_role_rec.cust_account_role_id;

        p_customer_contact_rec.cust_cont_role_rec.created_by_module := NULL;
      END IF;

      is_modified(t_cust_cont_role_rec.status,
	      p_customer_contact_rec.cust_cont_role_rec.status,
	      x_chg_flag,
	      x_populated_flag);

      --Added New 22-Mar-2016 for CHG0037971
      is_modified(t_cust_cont_role_rec.attribute_category,
	      p_customer_contact_rec.cust_cont_role_rec.attribute_category,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute1,
	      p_customer_contact_rec.cust_cont_role_rec.attribute1,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute2,
	      p_customer_contact_rec.cust_cont_role_rec.attribute2,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute3,
	      p_customer_contact_rec.cust_cont_role_rec.attribute3,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute4,
	      p_customer_contact_rec.cust_cont_role_rec.attribute4,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute5,
	      p_customer_contact_rec.cust_cont_role_rec.attribute5,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute6,
	      p_customer_contact_rec.cust_cont_role_rec.attribute6,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute7,
	      p_customer_contact_rec.cust_cont_role_rec.attribute7,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute8,
	      p_customer_contact_rec.cust_cont_role_rec.attribute8,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute9,
	      p_customer_contact_rec.cust_cont_role_rec.attribute9,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute10,
	      p_customer_contact_rec.cust_cont_role_rec.attribute10,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute11,
	      p_customer_contact_rec.cust_cont_role_rec.attribute11,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute12,
	      p_customer_contact_rec.cust_cont_role_rec.attribute12,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute13,
	      p_customer_contact_rec.cust_cont_role_rec.attribute13,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute14,
	      p_customer_contact_rec.cust_cont_role_rec.attribute14,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute15,
	      p_customer_contact_rec.cust_cont_role_rec.attribute15,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute16,
	      p_customer_contact_rec.cust_cont_role_rec.attribute16,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute17,
	      p_customer_contact_rec.cust_cont_role_rec.attribute17,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute18,
	      p_customer_contact_rec.cust_cont_role_rec.attribute18,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute19,
	      p_customer_contact_rec.cust_cont_role_rec.attribute19,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute20,
	      p_customer_contact_rec.cust_cont_role_rec.attribute20,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute21,
	      p_customer_contact_rec.cust_cont_role_rec.attribute21,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute22,
	      p_customer_contact_rec.cust_cont_role_rec.attribute22,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute23,
	      p_customer_contact_rec.cust_cont_role_rec.attribute23,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute24,
	      p_customer_contact_rec.cust_cont_role_rec.attribute24,
	      x_chg_flag,
	      x_populated_flag);
      is_modified(t_cust_cont_role_rec.attribute25,
	      p_customer_contact_rec.cust_cont_role_rec.attribute25,
	      x_chg_flag,
	      x_populated_flag);

      x_ovn := t_cust_cont_role_rec.object_version_number;
    END IF;

    IF p_type = 'ROLE_RESP' THEN
      x_chg_flag       := 'N';
      x_populated_flag := 'N';

      IF p_customer_contact_rec.cust_cont_role_resp_rec.responsibility_id IS NOT NULL THEN
        SELECT *
        INTO   t_cust_cont_role_resp_rec
        FROM   hz_role_responsibility
        WHERE  responsibility_id =
	   p_customer_contact_rec.cust_cont_role_resp_rec.responsibility_id;

        p_customer_contact_rec.cust_cont_role_resp_rec.created_by_module := NULL;

        -- Only look at this for existing records
        is_modified(t_cust_cont_role_resp_rec.primary_flag,
	        p_customer_contact_rec.cust_cont_role_resp_rec.primary_flag,
	        x_chg_flag,
	        x_populated_flag);
      END IF;

      is_modified(t_cust_cont_role_resp_rec.responsibility_type,
	      p_customer_contact_rec.cust_cont_role_resp_rec.responsibility_type,
	      x_chg_flag,
	      x_populated_flag);

      x_ovn := t_cust_cont_role_resp_rec.object_version_number;
    END IF;

    IF p_type = 'CONTACT_POINT' THEN
      x_chg_flag       := 'N';
      x_populated_flag := 'N';

      write_log('contact_point_id: ' ||
	    p_customer_contact_rec.cust_cont_point_rec.contact_point_id);
      IF p_customer_contact_rec.cust_cont_point_rec.contact_point_id IS NOT NULL THEN
        SELECT *
        INTO   t_cont_point_rec
        FROM   hz_contact_points
        WHERE  contact_point_id =
	   p_customer_contact_rec.cust_cont_point_rec.contact_point_id;

        p_customer_contact_rec.cust_cont_point_rec.contact_point_type := t_cont_point_rec.contact_point_type;
        p_customer_contact_rec.cust_cont_point_rec.created_by_module  := NULL;

        -- Only want to check if changed as it is x_populated_flag will always be 'Y' on creation, but we may not necessarily want to create a record
        is_modified(t_cont_point_rec.contact_point_purpose,
	        p_customer_contact_rec.cust_cont_point_rec.contact_point_purpose,
	        x_chg_flag,
	        x_populated_flag);
        is_modified(t_cont_point_rec.status,
	        p_customer_contact_rec.cust_cont_point_rec.status,
	        x_chg_flag,
	        x_populated_flag);
        is_modified(t_cont_point_rec.primary_flag,
	        p_customer_contact_rec.cust_cont_point_rec.primary_flag,
	        x_chg_flag,
	        x_populated_flag);
      END IF;

      write_log('contact_point_type: ' ||
	    p_customer_contact_rec.cust_cont_point_rec.contact_point_type);
      write_log('contact_point_purpose: ' ||
	    p_customer_contact_rec.cust_cont_point_rec.contact_point_purpose);

      IF p_customer_contact_rec.cust_cont_point_rec.contact_point_type =
         'PHONE' THEN

        -- line_type is defaulted on create of contacts, so need to check if we're actually creating a record or not.  If phone number is
        -- not populated, we won't check phone_line_type, because it will set x_populated_flag = Y when we're not creating a phone contact point.
        IF p_customer_contact_rec.cust_cont_phone_rec.phone_number IS NOT NULL THEN
          is_modified(t_cont_point_rec.phone_line_type,
	          p_customer_contact_rec.cust_cont_phone_rec.phone_line_type,
	          x_chg_flag,
	          x_populated_flag);
          is_modified(t_cont_point_rec.primary_flag,
	          p_customer_contact_rec.cust_cont_point_rec.primary_flag,
	          x_chg_flag,
	          x_populated_flag);
          is_modified(t_cont_point_rec.phone_number,
	          p_customer_contact_rec.cust_cont_phone_rec.phone_number,
	          x_chg_flag,
	          x_populated_flag);
          is_modified(t_cont_point_rec.phone_area_code,
	          p_customer_contact_rec.cust_cont_phone_rec.phone_area_code,
	          x_chg_flag,
	          x_populated_flag);
          is_modified(t_cont_point_rec.phone_country_code,
	          p_customer_contact_rec.cust_cont_phone_rec.phone_country_code,
	          x_chg_flag,
	          x_populated_flag);
          is_modified(t_cont_point_rec.phone_extension,
	          p_customer_contact_rec.cust_cont_phone_rec.phone_extension,
	          x_chg_flag,
	          x_populated_flag);
        END IF;
      ELSIF p_customer_contact_rec.cust_cont_point_rec.contact_point_type =
	'EMAIL' THEN

        -- email_format is defaulted on create of contacts, so need to check if we're actually creating a record or not.  If email_address is
        -- not populated, we won't check email_format, because it will set x_populated_flag = Y when we're not creating an email contact point.
        IF p_customer_contact_rec.cust_cont_email_rec.email_address IS NOT NULL THEN
          is_modified(t_cont_point_rec.email_format,
	          p_customer_contact_rec.cust_cont_email_rec.email_format,
	          x_chg_flag,
	          x_populated_flag);
          is_modified(t_cont_point_rec.email_address,
	          p_customer_contact_rec.cust_cont_email_rec.email_address,
	          x_chg_flag,
	          x_populated_flag);
        END IF;
      ELSIF p_customer_contact_rec.cust_cont_point_rec.contact_point_type =
	'WEB' THEN
        is_modified(t_cont_point_rec.web_type,
	        p_customer_contact_rec.cust_cont_web_rec.web_type,
	        x_chg_flag,
	        x_populated_flag);
        is_modified(t_cont_point_rec.url,
	        p_customer_contact_rec.cust_cont_web_rec.url,
	        x_chg_flag,
	        x_populated_flag);
      END IF;

      x_ovn := t_cont_point_rec.object_version_number;
    END IF;

    IF p_type = 'CONTACT_SITE_USE' THEN
      x_chg_flag       := 'N';
      x_populated_flag := 'N';

      write_log('party_site_use_id: ' ||
	    p_customer_contact_rec.party_site_use_rec.party_site_use_id);
      IF p_customer_contact_rec.party_site_use_rec.party_site_use_id IS NOT NULL THEN
        SELECT *
        INTO   t_cust_cont_site_use_rec
        FROM   hz_party_site_uses
        WHERE  party_site_use_id =
	   p_customer_contact_rec.party_site_use_rec.party_site_use_id;

        p_customer_contact_rec.party_site_use_rec.created_by_module := NULL;
        p_customer_contact_rec.party_site_use_rec.party_site_id     := NULL;

        -- Only look at these values when updating as they are defaulted on insert.
        is_modified(t_cust_cont_site_use_rec.primary_per_type,
	        p_customer_contact_rec.party_site_use_rec.primary_per_type,
	        x_chg_flag,
	        x_populated_flag);
        is_modified(t_cust_cont_site_use_rec.status,
	        p_customer_contact_rec.party_site_use_rec.status,
	        x_chg_flag,
	        x_populated_flag);
      END IF;

      is_modified(t_cust_cont_site_use_rec.site_use_type,
	      p_customer_contact_rec.party_site_use_rec.site_use_type,
	      x_chg_flag,
	      x_populated_flag);

      x_ovn := t_cust_cont_site_use_rec.object_version_number;
    END IF;

    write_log('x_populated_flag: ' || x_populated_flag);
    write_log('x_chg_flag: ' || x_chg_flag);
    write_log('x_ovn: ' || x_ovn);

    write_log('END IS_CONTACT_CHANGED');
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Error in IS_CONTACT_CHANGED: ' ||
	    dbms_utility.format_error_stack);
      write_log('END IS_CONTACT_CHANGED (EXCEPTION)');
      RAISE;
  END is_contact_changed;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Checks org contact changes.  Separate from is_contact_changed because
  --            it returns multiple object version numbers.  Checks are performed
  --            against the following tables... hz_org_contacts, hz_relationships,
  --            hz_parties.
  --
  -- Change History
  -- ...............................................................................
  -- 1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
  -- -------------------------------------------------------------------------------
  PROCEDURE is_org_contact_changed(p_customer_contact_rec IN OUT customer_contact_rec,
		           x_chg_flag             OUT VARCHAR2,
		           x_org_contact_ovn      OUT NUMBER,
		           x_relationship_ovn     OUT NUMBER,
		           x_rel_party_ovn        OUT NUMBER) IS
    t_org_contact_rec  hz_org_contacts%ROWTYPE;
    t_relationship_rec hz_relationships%ROWTYPE;
    t_party_rec        hz_parties%ROWTYPE;
    l_populated_flag   VARCHAR2(1);
  BEGIN
    write_log('BEGIN IS_ORG_CONTACT_CHANGED');

    x_chg_flag := 'N';

    write_log('Retrieving hz_org_contact info for org_contact_id: ' ||
	  p_customer_contact_rec.cust_cont_org_rec.org_contact_id);
    IF p_customer_contact_rec.cust_cont_org_rec.org_contact_id IS NOT NULL THEN
      SELECT *
      INTO   t_org_contact_rec
      FROM   hz_org_contacts
      WHERE  org_contact_id =
	 p_customer_contact_rec.cust_cont_org_rec.org_contact_id;

      write_log('Retrieving hz_relationships info for relationship_id: ' ||
	    p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.relationship_id);
      SELECT *
      INTO   t_relationship_rec
      FROM   hz_relationships
      WHERE  relationship_id =
	 p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.relationship_id
      AND    object_type = 'ORGANIZATION'
      AND    relationship_code = 'CONTACT_OF';

      write_log('Retrieving hz_parties info for party_id: ' ||
	    p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.party_rec.party_id);
      SELECT *
      INTO   t_party_rec
      FROM   hz_parties
      WHERE  party_id =
	 p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.party_rec.party_id;

      p_customer_contact_rec.cust_cont_org_rec.created_by_module               := NULL;
      p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.created_by_module := NULL;
      p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.created_by_module := NULL;

    END IF;

    -- Currently, this is the only value on the three tables above that could change.
    is_modified(t_org_contact_rec.job_title,
	    p_customer_contact_rec.cust_cont_org_rec.job_title,
	    x_chg_flag,
	    l_populated_flag);

    is_modified(t_org_contact_rec.attribute_category,
	    p_customer_contact_rec.cust_cont_org_rec.attribute_category,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute1,
	    p_customer_contact_rec.cust_cont_org_rec.attribute1,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute2,
	    p_customer_contact_rec.cust_cont_org_rec.attribute2,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute3,
	    p_customer_contact_rec.cust_cont_org_rec.attribute3,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute4,
	    p_customer_contact_rec.cust_cont_org_rec.attribute4,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute5,
	    p_customer_contact_rec.cust_cont_org_rec.attribute5,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute6,
	    p_customer_contact_rec.cust_cont_org_rec.attribute6,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute7,
	    p_customer_contact_rec.cust_cont_org_rec.attribute7,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute8,
	    p_customer_contact_rec.cust_cont_org_rec.attribute8,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute9,
	    p_customer_contact_rec.cust_cont_org_rec.attribute9,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute10,
	    p_customer_contact_rec.cust_cont_org_rec.attribute10,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute11,
	    p_customer_contact_rec.cust_cont_org_rec.attribute11,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute12,
	    p_customer_contact_rec.cust_cont_org_rec.attribute12,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute13,
	    p_customer_contact_rec.cust_cont_org_rec.attribute13,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute14,
	    p_customer_contact_rec.cust_cont_org_rec.attribute14,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute15,
	    p_customer_contact_rec.cust_cont_org_rec.attribute15,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute16,
	    p_customer_contact_rec.cust_cont_org_rec.attribute16,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute17,
	    p_customer_contact_rec.cust_cont_org_rec.attribute17,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute18,
	    p_customer_contact_rec.cust_cont_org_rec.attribute18,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute19,
	    p_customer_contact_rec.cust_cont_org_rec.attribute19,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute20,
	    p_customer_contact_rec.cust_cont_org_rec.attribute20,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute21,
	    p_customer_contact_rec.cust_cont_org_rec.attribute21,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute22,
	    p_customer_contact_rec.cust_cont_org_rec.attribute22,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute23,
	    p_customer_contact_rec.cust_cont_org_rec.attribute23,
	    x_chg_flag,
	    l_populated_flag);
    is_modified(t_org_contact_rec.attribute24,
	    p_customer_contact_rec.cust_cont_org_rec.attribute24,
	    x_chg_flag,
	    l_populated_flag);

    x_org_contact_ovn  := t_org_contact_rec.object_version_number;
    x_relationship_ovn := t_relationship_rec.object_version_number;
    x_rel_party_ovn    := t_party_rec.object_version_number;

    write_log('x_chg_flag: ' || x_chg_flag);
    write_log('x_org_contact_ovn: ' || x_org_contact_ovn);
    write_log('x_relationship_ovn: ' || x_relationship_ovn);
    write_log('x_rel_party_ovn: ' || x_rel_party_ovn);

    write_log('END IS_ORG_CONTACT_CHANGED');
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Error in IS_ORG_CONTACT_CHANGED: ' ||
	    dbms_utility.format_error_stack);
      write_log('END IS_ORG_CONTACT_CHANGED (EXCEPTION)');
      RAISE;
  END is_org_contact_changed;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of contact hz_parties record
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE contact_person_api(p_customer_contact_rec IN OUT customer_contact_rec,
		       x_return_message       OUT VARCHAR2,
		       x_return_status        OUT VARCHAR2) IS
    l_action         VARCHAR2(15);
    l_ovn            hz_party_sites.object_version_number%TYPE;
    l_profile_id     NUMBER;
    l_chg_flag       VARCHAR2(1);
    l_populated_flag VARCHAR2(1);

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;

    e_skip  EXCEPTION;
    e_error EXCEPTION;
  BEGIN
    write_log('START CONTACT_PERSON_API');

    is_contact_changed(p_customer_contact_rec => p_customer_contact_rec,
	           p_type                 => 'PERSON',
	           x_chg_flag             => l_chg_flag,
	           x_populated_flag       => l_populated_flag,
	           x_ovn                  => l_ovn);

    IF p_customer_contact_rec.cust_cont_person_rec.party_rec.party_id IS NULL THEN
      l_action := 'Create';

      -- If nothing populated on contact, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      hz_party_v2pub.create_person(p_init_msg_list => 'T',
		           p_person_rec    => p_customer_contact_rec.cust_cont_person_rec,
		           x_party_id      => p_customer_contact_rec.cust_cont_person_rec.party_rec.party_id,
		           x_party_number  => p_customer_contact_rec.cust_cont_person_rec.party_rec.party_number,
		           x_profile_id    => l_profile_id,
		           x_return_status => x_return_status,
		           x_msg_count     => l_msg_count,
		           x_msg_data      => l_msg_data);

    ELSE
      l_action := 'Update';

      -- If nothing changed on contact, skip processing
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      -- Record has changed
      IF l_ovn <> p_customer_contact_rec.party_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_party_v2pub.update_person(p_init_msg_list               => 'T',
		           p_person_rec                  => p_customer_contact_rec.cust_cont_person_rec,
		           p_party_object_version_number => p_customer_contact_rec.party_ovn,
		           x_profile_id                  => l_profile_id,
		           x_return_status               => x_return_status,
		           x_msg_count                   => l_msg_count,
		           x_msg_data                    => l_msg_data);

    END IF;
    write_log('Contact Person API ' || l_action || ' return status: ' ||
	  x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'Contact Person API ' || l_action || 'Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END CONTACT_PERSON_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END CONTACT_PERSON_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END CONTACT_PERSON_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in CONTACT_PERSON_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END CONTACT_PERSON_API (EXCEPTION)');
  END contact_person_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of org_contacts (hz_org_contacts,
  --            hz_relationships, hz_parties).
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE contact_org_api(p_customer_contact_rec IN OUT customer_contact_rec,
		    x_return_message       OUT VARCHAR2,
		    x_return_status        OUT VARCHAR2) IS
    l_action           VARCHAR2(15);
    l_org_contact_ovn  hz_org_contacts.object_version_number%TYPE;
    l_relationship_ovn hz_relationships.object_version_number%TYPE;
    l_rel_party_ovn    hz_parties.object_version_number%TYPE;

    l_profile_id     NUMBER;
    l_chg_flag       VARCHAR2(1);
    l_populated_flag VARCHAR2(1);

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;

    e_skip  EXCEPTION;
    e_error EXCEPTION;
  BEGIN
    write_log('START CONTACT_ORG_API');
    write_log('org_contact_id: ' ||
	  p_customer_contact_rec.cust_cont_org_rec.org_contact_id);

    IF p_customer_contact_rec.cust_cont_org_rec.org_contact_id IS NULL THEN
      -- Values are static for our purposes since we are now only allowing contacts at account level.
      p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.subject_id         := p_customer_contact_rec.cust_cont_person_rec.party_rec.party_id;
      p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.subject_type       := 'PERSON';
      p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.subject_table_name := 'HZ_PARTIES';
      p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.object_type        := 'ORGANIZATION';
      p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.object_table_name  := 'HZ_PARTIES';
      p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.relationship_code  := 'CONTACT_OF';
      p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.relationship_type  := 'CONTACT';

      l_action := 'Create';

      hz_party_contact_v2pub.create_org_contact(p_init_msg_list   => 'T',
				p_org_contact_rec => p_customer_contact_rec.cust_cont_org_rec,
				x_org_contact_id  => p_customer_contact_rec.cust_cont_org_rec.org_contact_id,
				x_party_rel_id    => p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.relationship_id,
				x_party_id        => p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.party_rec.party_id,
				x_party_number    => p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.party_rec.party_number,
				x_return_status   => x_return_status,
				x_msg_count       => l_msg_count,
				x_msg_data        => l_msg_data);

    ELSE
      l_action := 'Update';

      is_org_contact_changed(p_customer_contact_rec => p_customer_contact_rec,
		     x_chg_flag             => l_chg_flag,
		     x_org_contact_ovn      => l_org_contact_ovn,
		     x_relationship_ovn     => l_relationship_ovn,
		     x_rel_party_ovn        => l_rel_party_ovn);

      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      -- Record has changed
      IF l_org_contact_ovn <> p_customer_contact_rec.org_contact_ovn OR
         l_relationship_ovn <> p_customer_contact_rec.relationship_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_party_contact_v2pub.update_org_contact(p_init_msg_list               => 'T',
				p_org_contact_rec             => p_customer_contact_rec.cust_cont_org_rec,
				p_cont_object_version_number  => p_customer_contact_rec.org_contact_ovn,
				p_rel_object_version_number   => p_customer_contact_rec.relationship_ovn,
				p_party_object_version_number => l_rel_party_ovn,
				x_return_status               => x_return_status,
				x_msg_count                   => l_msg_count,
				x_msg_data                    => l_msg_data);

    END IF;
    write_log('Org Contact API ' || l_action || ' return status: ' ||
	  x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'Org Contact API ' || l_action || 'Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END CONTACT_ORG_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END CONTACT_ORG_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END CONTACT_ORG_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in CONTACT_ORG_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END CONTACT_ORG_API (EXCEPTION)');
  END contact_org_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of contact roles (hz_cust_account_roles)
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE contact_role_api(p_customer_contact_rec IN OUT customer_contact_rec,
		     x_return_message       OUT VARCHAR2,
		     x_return_status        OUT VARCHAR2) IS
    l_action VARCHAR2(15);
    l_ovn    hz_parties.object_version_number%TYPE;

    l_chg_flag       VARCHAR2(1);
    l_populated_flag VARCHAR2(1);

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;

    e_skip  EXCEPTION;
    e_error EXCEPTION;
  BEGIN
    write_log('START CONTACT_ROLE_API');

    is_contact_changed(p_customer_contact_rec => p_customer_contact_rec,
	           p_type                 => 'ROLE',
	           x_chg_flag             => l_chg_flag,
	           x_populated_flag       => l_populated_flag,
	           x_ovn                  => l_ovn);

    IF p_customer_contact_rec.cust_cont_role_rec.cust_account_role_id IS NULL THEN
      -- If nothing populated on customer contact roles, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      l_action := 'Create';

      -- Static value
      p_customer_contact_rec.cust_cont_role_rec.role_type := 'CONTACT';
      p_customer_contact_rec.cust_cont_role_rec.party_id  := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.party_rec.party_id;

      hz_cust_account_role_v2pub.create_cust_account_role(p_init_msg_list         => 'T',
				          p_cust_account_role_rec => p_customer_contact_rec.cust_cont_role_rec,
				          x_cust_account_role_id  => p_customer_contact_rec.cust_cont_role_rec.cust_account_role_id,
				          x_return_status         => x_return_status,
				          x_msg_count             => l_msg_count,
				          x_msg_data              => l_msg_data);
    ELSE
      l_action := 'Update';

      -- If no changes to customer contact roles, skip processing
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      -- Record has changed
      IF l_ovn <> p_customer_contact_rec.role_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_cust_account_role_v2pub.update_cust_account_role(p_init_msg_list         => 'T',
				          p_cust_account_role_rec => p_customer_contact_rec.cust_cont_role_rec,
				          p_object_version_number => l_ovn,
				          x_return_status         => x_return_status,
				          x_msg_count             => l_msg_count,
				          x_msg_data              => l_msg_data);

    END IF;
    write_log('Contact Role API ' || l_action || ' return status: ' ||
	  x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'Contact Role API ' || l_action || 'Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END CONTACT_ROLE_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END CONTACT_ROLE_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END CONTACT_ROLE_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in CONTACT_ROLE_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END CONTACT_ROLE_API (EXCEPTION)');
  END contact_role_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of contact site uses (hz_party_site_uses)
  --            NOTE - The creation of party sites and locations is handled by the
  --                   party_site_api and location_api procedures in the Contact Sites
  --                   section of this code.
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE contact_party_site_use_api(p_customer_contact_rec IN OUT customer_contact_rec,
			   x_return_message       OUT VARCHAR2,
			   x_return_status        OUT VARCHAR2) IS
    l_action VARCHAR2(15);
    l_ovn    hz_parties.object_version_number%TYPE;

    l_chg_flag       VARCHAR2(1);
    l_populated_flag VARCHAR2(1);

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;

    e_skip  EXCEPTION;
    e_error EXCEPTION;
  BEGIN
    write_log('START CONTACT_PARTY_SITE_USE_API');

    is_contact_changed(p_customer_contact_rec => p_customer_contact_rec,
	           p_type                 => 'CONTACT_SITE_USE',
	           x_chg_flag             => l_chg_flag,
	           x_populated_flag       => l_populated_flag,
	           x_ovn                  => l_ovn);

    IF p_customer_contact_rec.party_site_use_rec.party_site_use_id IS NULL THEN
      -- If nothing populated on customer contact roles, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      l_action := 'Create';

      hz_party_site_v2pub.create_party_site_use(p_init_msg_list      => 'T',
				p_party_site_use_rec => p_customer_contact_rec.party_site_use_rec,
				x_party_site_use_id  => p_customer_contact_rec.party_site_use_rec.party_site_use_id,
				x_return_status      => x_return_status,
				x_msg_count          => l_msg_count,
				x_msg_data           => l_msg_data);
    ELSE
      l_action := 'Update';

      -- If no changes to customer contact roles, skip processing
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      -- Record has changed
      IF l_ovn <> p_customer_contact_rec.party_site_use_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_party_site_v2pub.update_party_site_use(p_init_msg_list         => 'T',
				p_party_site_use_rec    => p_customer_contact_rec.party_site_use_rec,
				p_object_version_number => p_customer_contact_rec.party_site_use_ovn,
				x_return_status         => x_return_status,
				x_msg_count             => l_msg_count,
				x_msg_data              => l_msg_data);

    END IF;
    write_log('Contact Site Use API ' || l_action || ' return status: ' ||
	  x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'Contact Site Use API ' || l_action || 'Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END CONTACT_PARTY_SITE_USE_API_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END CONTACT_PARTY_SITE_USE_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END CONTACT_PARTY_SITE_USE_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in CONTACT_PARTY_SITE_USE_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END CONTACT_PARTY_SITE_USE_API (EXCEPTION)');
  END contact_party_site_use_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of contact role responsibilities
  --            (hz_role_responsibility).  Please see code below as we are doing
  --            a delete rather than update.  Comments reference Oracle SR.
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE contact_role_resp_api(p_customer_contact_rec IN OUT customer_contact_rec,
		          x_return_message       OUT VARCHAR2,
		          x_return_status        OUT VARCHAR2) IS
    l_action VARCHAR2(15);
    l_ovn    hz_parties.object_version_number%TYPE;

    l_chg_flag       VARCHAR2(1);
    l_populated_flag VARCHAR2(1);

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;

    e_skip  EXCEPTION;
    e_error EXCEPTION;
  BEGIN
    write_log('START CONTACT_ROLE_RESP_API');

    is_contact_changed(p_customer_contact_rec => p_customer_contact_rec,
	           p_type                 => 'ROLE_RESP',
	           x_chg_flag             => l_chg_flag,
	           x_populated_flag       => l_populated_flag,
	           x_ovn                  => l_ovn);

    -- Most hz table rows are not deleted.  Usually, they are have a status flag set to 'I' when the user clicks 'Delete' on the standard forms.
    -- However, hz_role_responsibility does not have a status flag.  Oracle's standard forms delete the record from hz_role_responsibility row.
    -- I've confirmed this with Oracle support, and also confirmed that there are NOT dependent objects on this table.  See SR 3-11110331911
    -- Our only option here is to do a direct delete on the table.
    --
    -- Additionally, we need a way to trigger the delete.  Rather than create a flag, I'm simply populating attribute1 with N or Y.  If Y,
    -- we will delete.  Also, notice that the value for attribute1 is reset to NULL if this is a create or update.
    IF p_customer_contact_rec.cust_cont_role_resp_rec.responsibility_id IS NOT NULL AND
       p_customer_contact_rec.cust_cont_role_resp_rec.attribute1 = 'Y' THEN
      -- Record has changed
      IF l_ovn <> p_customer_contact_rec.role_resp_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      BEGIN
        l_action := 'Delete';

        DELETE FROM hz_role_responsibility
        WHERE  responsibility_id =
	   p_customer_contact_rec.cust_cont_role_resp_rec.responsibility_id;

        x_return_status := 'S';
      EXCEPTION
        WHEN OTHERS THEN
          x_return_message := 'Error in CONTACT_ROLE_RESP_API: ' ||
		      dbms_utility.format_error_stack;
          RAISE e_error;
      END;

    ELSIF p_customer_contact_rec.cust_cont_role_resp_rec.responsibility_id IS NULL THEN

      p_customer_contact_rec.cust_cont_role_resp_rec.attribute1 := NULL;

      -- If nothing populated on customer contact roles, skip processing
      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      l_action := 'Create';

      hz_cust_account_role_v2pub.create_role_responsibility(p_init_msg_list           => 'T',
					p_role_responsibility_rec => p_customer_contact_rec.cust_cont_role_resp_rec,
					x_responsibility_id       => p_customer_contact_rec.cust_cont_role_resp_rec.responsibility_id,
					x_return_status           => x_return_status,
					x_msg_count               => l_msg_count,
					x_msg_data                => l_msg_data);
    ELSE

      p_customer_contact_rec.cust_cont_role_resp_rec.attribute1 := NULL;

      l_action := 'Update';

      -- If no changes to customer contact roles, skip processing
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      -- Record has changed
      IF l_ovn <> p_customer_contact_rec.role_resp_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      hz_cust_account_role_v2pub.update_role_responsibility(p_init_msg_list           => 'T',
					p_role_responsibility_rec => p_customer_contact_rec.cust_cont_role_resp_rec,
					p_object_version_number   => p_customer_contact_rec.role_resp_ovn,
					x_return_status           => x_return_status,
					x_msg_count               => l_msg_count,
					x_msg_data                => l_msg_data);

    END IF;
    write_log('Contact Role Responsibility API ' || l_action ||
	  ' return status: ' || x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'Contact Role Responsiblity API ' || l_action ||
		  'Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END CONTACT_ROLE_RESP_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END CONTACT_ROLE_RESP_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END CONTACT_ROLE_RESP_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in CONTACT_ROLE_RESP_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END CONTACT_ROLE_RESP_API (EXCEPTION)');
  END contact_role_resp_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of contact points.  This could be
  --            phone number, email, or web site (hz_contact_points)
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE contact_point_api(p_customer_contact_rec IN OUT customer_contact_rec,
		      x_return_message       OUT VARCHAR2,
		      x_return_status        OUT VARCHAR2) IS
    l_action VARCHAR2(15);
    l_ovn    hz_parties.object_version_number%TYPE;

    l_chg_flag       VARCHAR2(1);
    l_populated_flag VARCHAR2(1);

    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2500);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;

    e_skip  EXCEPTION;
    e_error EXCEPTION;
  BEGIN
    write_log('START CONTACT_POINT_API');
    write_log('contact_point_type: ' ||
	  p_customer_contact_rec.cust_cont_point_rec.contact_point_type);

    is_contact_changed(p_customer_contact_rec => p_customer_contact_rec,
	           p_type                 => 'CONTACT_POINT',
	           x_chg_flag             => l_chg_flag,
	           x_populated_flag       => l_populated_flag,
	           x_ovn                  => l_ovn);

    IF p_customer_contact_rec.cust_cont_point_rec.contact_point_id IS NULL THEN
      -- If nothing on contact point populated, skip processing

      IF l_populated_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      -- Static Value
      p_customer_contact_rec.cust_cont_point_rec.owner_table_name := 'HZ_PARTIES';
      p_customer_contact_rec.cust_cont_point_rec.owner_table_id   := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.party_rec.party_id;

      l_action := 'Create';

      -- API called depends on the type of contact_point we are saving.
      IF p_customer_contact_rec.cust_cont_point_rec.contact_point_type =
         'PHONE' THEN
        hz_contact_point_v2pub.create_phone_contact_point(p_init_msg_list     => fnd_api.g_true,
				          p_contact_point_rec => p_customer_contact_rec.cust_cont_point_rec,
				          p_phone_rec         => p_customer_contact_rec.cust_cont_phone_rec,
				          x_contact_point_id  => p_customer_contact_rec.cust_cont_point_rec.contact_point_id,
				          x_return_status     => x_return_status,
				          x_msg_count         => l_msg_count,
				          x_msg_data          => l_msg_data);
      ELSIF p_customer_contact_rec.cust_cont_point_rec.contact_point_type =
	'EMAIL' THEN
        hz_contact_point_v2pub.create_email_contact_point(p_init_msg_list     => fnd_api.g_true,
				          p_contact_point_rec => p_customer_contact_rec.cust_cont_point_rec,
				          p_email_rec         => p_customer_contact_rec.cust_cont_email_rec,
				          x_contact_point_id  => p_customer_contact_rec.cust_cont_point_rec.contact_point_id,
				          x_return_status     => x_return_status,
				          x_msg_count         => l_msg_count,
				          x_msg_data          => l_msg_data);

      ELSIF p_customer_contact_rec.cust_cont_point_rec.contact_point_type =
	'WEB' THEN

        hz_contact_point_v2pub.create_web_contact_point(p_init_msg_list     => fnd_api.g_true,
				        p_contact_point_rec => p_customer_contact_rec.cust_cont_point_rec,
				        p_web_rec           => p_customer_contact_rec.cust_cont_web_rec,
				        x_contact_point_id  => p_customer_contact_rec.cust_cont_point_rec.contact_point_id,
				        x_return_status     => x_return_status,
				        x_msg_count         => l_msg_count,
				        x_msg_data          => l_msg_data);
      END IF;
    ELSE
      l_action := 'Update';

      -- If nothing on contact point changed, skip processing
      IF l_chg_flag = 'N' THEN
        RAISE e_skip;
      END IF;

      -- Record has changed
      IF l_ovn <> p_customer_contact_rec.contact_point_ovn THEN
        fnd_message.set_name('AR', 'AR_TW_RECORD_LOCKED');
        x_return_message := fnd_message.get;
        RAISE e_error;
      END IF;

      IF p_customer_contact_rec.cust_cont_point_rec.contact_point_type =
         'PHONE' THEN
        hz_contact_point_v2pub.update_phone_contact_point(p_init_msg_list         => fnd_api.g_true,
				          p_contact_point_rec     => p_customer_contact_rec.cust_cont_point_rec,
				          p_phone_rec             => p_customer_contact_rec.cust_cont_phone_rec,
				          p_object_version_number => p_customer_contact_rec.contact_point_ovn,
				          x_return_status         => x_return_status,
				          x_msg_count             => l_msg_count,
				          x_msg_data              => l_msg_data);
      ELSIF p_customer_contact_rec.cust_cont_point_rec.contact_point_type =
	'EMAIL' THEN
        hz_contact_point_v2pub.update_email_contact_point(p_init_msg_list         => fnd_api.g_true,
				          p_contact_point_rec     => p_customer_contact_rec.cust_cont_point_rec,
				          p_email_rec             => p_customer_contact_rec.cust_cont_email_rec,
				          p_object_version_number => p_customer_contact_rec.contact_point_ovn,
				          x_return_status         => x_return_status,
				          x_msg_count             => l_msg_count,
				          x_msg_data              => l_msg_data);

      ELSIF p_customer_contact_rec.cust_cont_point_rec.contact_point_type =
	'WEB' THEN
        hz_contact_point_v2pub.update_web_contact_point(p_init_msg_list         => fnd_api.g_true,
				        p_contact_point_rec     => p_customer_contact_rec.cust_cont_point_rec,
				        p_web_rec               => p_customer_contact_rec.cust_cont_web_rec,
				        p_object_version_number => p_customer_contact_rec.contact_point_ovn,
				        x_return_status         => x_return_status,
				        x_msg_count             => l_msg_count,
				        x_msg_data              => l_msg_data);
      END IF;

    END IF;
    write_log('Contact Point API ' || l_action || ' return status: ' ||
	  x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      x_return_message := 'Contact API Point ' || l_action || ' Failed: ';

      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        x_return_message := substr(x_return_message || ' - ' || l_data,
		           1,
		           500);
      END LOOP;
    END IF;

    write_log('END CONTACT_POINT_API');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END CONTACT_POINT_API (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END CONTACT_POINT_API (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in CONTACT_POINT_API: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END CONTACT_POINT_API (EXCEPTION)');
  END contact_point_api;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles validation of contacts and contact related entities
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE validate_contacts(p_customer_contact_rec IN OUT customer_contact_rec,
		      x_return_message       OUT VARCHAR2,
		      x_return_status        OUT VARCHAR2) IS
    l_is_mail_valid VARCHAR2(1) := 'N';

    e_skip  EXCEPTION;
    e_error EXCEPTION;
  BEGIN
    write_log('BEGIN VALIDATE_CONTACTS');

    IF p_customer_contact_rec.cust_cont_email_rec.email_address IS NOT NULL THEN
      l_is_mail_valid := xxobjt_general_utils_pkg.is_mail_valid(p_customer_contact_rec.cust_cont_email_rec.email_address);
      IF l_is_mail_valid = 'N' THEN
        x_return_message := 'Email address: ' ||
		    p_customer_contact_rec.cust_cont_email_rec.email_address ||
		    ' is invalid.';
        RAISE e_error;
      END IF;
    END IF;

    x_return_status := fnd_api.g_ret_sts_success;
    write_log('END VALIDATE_CONTACTS');
  EXCEPTION
    -- no changes, skip processing
    WHEN e_skip THEN
      write_log('END VALIDATE_CONTACTS (E_SKIP)');
      x_return_status := fnd_api.g_ret_sts_success;
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END VALIDATE_CONTACTS (E_ERROR)');
      x_return_status := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_return_status  := fnd_api.g_ret_sts_error;
      x_return_message := 'Error in VALIDATE_CONTACTS: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      write_log('END VALIDATE_CONTACTS (EXCEPTION)');
  END validate_contacts;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Handles creation and maintenance of account contacts
  --
  -- NOTE     : Checking for duplicate contacts was outside the scope for the
  --            original CHG (CHG0035118).
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE handle_contacts(p_cust_contact_rec IN OUT customer_contact_rec,
		    x_return_message   OUT VARCHAR2,
		    x_return_status    OUT VARCHAR2) IS
    l_customer_site_rec customer_site_rec;

    e_error EXCEPTION;
  BEGIN
    write_log('BEGIN HANDLE_CONTACTS');

    mo_global.init('AR');

    -- ****************************************************************************
    -- validate contacts
    -- ****************************************************************************
    validate_contacts(p_customer_contact_rec => p_cust_contact_rec,
	          x_return_message       => x_return_message,
	          x_return_status        => x_return_status);

    write_log('contact_person_api return_status: ' || x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle contact person
    -- ****************************************************************************
    contact_person_api(p_customer_contact_rec => p_cust_contact_rec,
	           x_return_status        => x_return_status,
	           x_return_message       => x_return_message);

    write_log('contact_person_api return_status: ' || x_return_status);
    write_log('contact_person_api party_id: ' ||
	  p_cust_contact_rec.cust_cont_person_rec.party_rec.party_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle contact org
    -- ****************************************************************************
    contact_org_api(p_customer_contact_rec => p_cust_contact_rec,
	        x_return_status        => x_return_status,
	        x_return_message       => x_return_message);

    write_log('contact_org_api return_status: ' || x_return_status);
    write_log('contact_org_api org_contact_id: ' ||
	  p_cust_contact_rec.cust_cont_org_rec.org_contact_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle contact role
    -- ****************************************************************************
    contact_role_api(p_customer_contact_rec => p_cust_contact_rec,
	         x_return_status        => x_return_status,
	         x_return_message       => x_return_message);

    write_log('contact_role_api return_status: ' || x_return_status);
    write_log('contact: ' ||
	  l_customer_site_rec.party_site_rec.party_site_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle contact role responsiblities
    -- ****************************************************************************
    contact_role_resp_api(p_customer_contact_rec => p_cust_contact_rec,
		  x_return_status        => x_return_status,
		  x_return_message       => x_return_message);

    write_log('contact_role_resp_api return_status: ' || x_return_status);
    write_log('contact_role_resp_api responsibility_id: ' ||
	  p_cust_contact_rec.cust_cont_role_resp_rec.responsibility_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle location and party site
    -- ****************************************************************************

    -- Assign cust_contact_rec values to cust_site_rec because location and party site
    -- APIs were already built to use cust_site_rec.  We will reassign to contact rec
    -- after calling location_api and party_site_api
    l_customer_site_rec.location_ovn   := p_cust_contact_rec.location_ovn;
    l_customer_site_rec.party_site_ovn := p_cust_contact_rec.party_site_ovn;
    l_customer_site_rec.location_rec   := p_cust_contact_rec.location_rec;
    l_customer_site_rec.party_site_rec := p_cust_contact_rec.party_site_rec;

    IF l_customer_site_rec.location_rec.country IS NOT NULL THEN

      -- ****************************************************************************
      -- handle location
      -- ****************************************************************************
      location_api(p_site_rec       => l_customer_site_rec,
	       x_return_status  => x_return_status,
	       x_return_message => x_return_message);

      write_log('location_api return_status: ' || x_return_status);
      write_log('location_id: ' ||
	    l_customer_site_rec.location_rec.location_id);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;

      -- ****************************************************************************
      -- handle party site
      -- ****************************************************************************
      IF l_customer_site_rec.party_site_rec.location_id IS NULL THEN
        l_customer_site_rec.party_site_rec.location_id := l_customer_site_rec.location_rec.location_id;
      END IF;

      -- For contacts, link the party_id on the site to the hz_relationsip party_id for the 'CONTACT OF' relationship of the contact
      l_customer_site_rec.party_site_rec.party_id := p_cust_contact_rec.cust_cont_org_rec.party_rel_rec.party_rec.party_id;

      write_log('Party ID: ' ||
	    l_customer_site_rec.party_site_rec.party_id);

      party_site_api(p_site_rec       => l_customer_site_rec,
	         x_return_status  => x_return_status,
	         x_return_message => x_return_message);

      write_log('party_site_api return_status: ' || x_return_status);
      write_log('party_site_id: ' ||
	    l_customer_site_rec.party_site_rec.party_site_id);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;

      -- Re-assign cust_site_rec values to cust_contact_rec values
      p_cust_contact_rec.location_ovn   := l_customer_site_rec.location_ovn;
      p_cust_contact_rec.party_site_ovn := l_customer_site_rec.party_site_ovn;
      p_cust_contact_rec.location_rec   := l_customer_site_rec.location_rec;
      p_cust_contact_rec.party_site_rec := l_customer_site_rec.party_site_rec;
    END IF;

    -- ****************************************************************************
    -- handle contact site use
    -- ****************************************************************************
    contact_party_site_use_api(p_customer_contact_rec => p_cust_contact_rec,
		       x_return_status        => x_return_status,
		       x_return_message       => x_return_message);

    write_log('contact_party_site_use_api return_status: ' ||
	  x_return_status);
    write_log('party_site_use_id: ' ||
	  p_cust_contact_rec.party_site_use_rec.party_site_use_id);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- ****************************************************************************
    -- handle contact point
    -- ****************************************************************************
    IF p_cust_contact_rec.cust_cont_phone_rec.phone_number IS NOT NULL OR
       p_cust_contact_rec.cust_cont_email_rec.email_address IS NOT NULL OR
       p_cust_contact_rec.cust_cont_web_rec.url IS NOT NULL THEN

      contact_point_api(p_customer_contact_rec => p_cust_contact_rec,
		x_return_status        => x_return_status,
		x_return_message       => x_return_message);

      write_log('contact_point_api return_status: ' || x_return_status);
      write_log('contact_point_id: ' ||
	    p_cust_contact_rec.cust_cont_point_rec.contact_point_id);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;

      write_log('END HANDLE_CONTACTS');
    END IF;
  EXCEPTION
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('BEGIN HANDLE_CONTACTS (E_EXCEPTION)');
    WHEN OTHERS THEN
      x_return_message := 'Error in HANDLE_CONTACTS: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END HANDLE_CONTACTS (EXCEPTION)');
  END handle_contacts;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Assigns form specific types to Oracle's standard record type for use
  --            in Oracle's APIs
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  FUNCTION load_contact_rec(p_frm_customer_contact_rec frm_customer_contact_rec,
		    p_contact_point            IN NUMBER DEFAULT 1)
    RETURN customer_contact_rec IS
    x_customer_contact_rec customer_contact_rec;
  BEGIN
    write_log('START LOAD_CONTACT_REC');

    -- Assign matching record types, including converting form version of location rec to Oracle API version
    -- of location rec.

    -- Object Version Numbers
    x_customer_contact_rec.party_ovn          := p_frm_customer_contact_rec.party_ovn;
    x_customer_contact_rec.org_contact_ovn    := p_frm_customer_contact_rec.org_contact_ovn;
    x_customer_contact_rec.relationship_ovn   := p_frm_customer_contact_rec.relationship_ovn;
    x_customer_contact_rec.rel_party_ovn      := p_frm_customer_contact_rec.rel_party_ovn;
    x_customer_contact_rec.location_ovn       := p_frm_customer_contact_rec.location_ovn;
    x_customer_contact_rec.party_site_ovn     := p_frm_customer_contact_rec.party_site_ovn;
    x_customer_contact_rec.party_site_use_ovn := p_frm_customer_contact_rec.party_site_use_ovn;
    x_customer_contact_rec.role_ovn           := p_frm_customer_contact_rec.role_ovn;
    x_customer_contact_rec.role_resp_ovn      := p_frm_customer_contact_rec.role_resp_ovn;
    x_customer_contact_rec.contact_point_ovn  := p_frm_customer_contact_rec.contact_point_ovn;

    -- Record types without form specific record types
    x_customer_contact_rec.location_rec            := load_location_rec(p_frm_customer_contact_rec.location_rec);
    x_customer_contact_rec.party_site_rec          := p_frm_customer_contact_rec.party_site_rec;
    x_customer_contact_rec.party_site_use_rec      := p_frm_customer_contact_rec.party_site_use_rec;
    x_customer_contact_rec.cust_cont_role_rec      := p_frm_customer_contact_rec.cust_cont_role_rec;
    x_customer_contact_rec.cust_cont_role_resp_rec := p_frm_customer_contact_rec.cust_cont_role_resp_rec;
    x_customer_contact_rec.cust_cont_phone_rec     := p_frm_customer_contact_rec.cust_cont_phone_rec;
    x_customer_contact_rec.cust_cont_email_rec     := p_frm_customer_contact_rec.cust_cont_email_rec;
    x_customer_contact_rec.cust_cont_web_rec       := p_frm_customer_contact_rec.cust_cont_web_rec;

    -- Contact
    x_customer_contact_rec.cust_cont_person_rec.person_pre_name_adjunct := p_frm_customer_contact_rec.cust_cont_person_rec.person_pre_name_adjunct;
    x_customer_contact_rec.cust_cont_person_rec.person_first_name       := p_frm_customer_contact_rec.cust_cont_person_rec.person_first_name;
    x_customer_contact_rec.cust_cont_person_rec.person_middle_name      := p_frm_customer_contact_rec.cust_cont_person_rec.person_middle_name;
    x_customer_contact_rec.cust_cont_person_rec.person_last_name        := p_frm_customer_contact_rec.cust_cont_person_rec.person_last_name;
    x_customer_contact_rec.cust_cont_person_rec.person_name_suffix      := p_frm_customer_contact_rec.cust_cont_person_rec.person_name_suffix;
    x_customer_contact_rec.cust_cont_person_rec.person_title            := p_frm_customer_contact_rec.cust_cont_person_rec.person_title;
    x_customer_contact_rec.cust_cont_person_rec.created_by_module       := p_frm_customer_contact_rec.cust_cont_person_rec.created_by_module;
    x_customer_contact_rec.cust_cont_person_rec.party_rec               := p_frm_customer_contact_rec.cust_cont_person_rec.party_rec;

    -- Org Contact
    x_customer_contact_rec.cust_cont_org_rec.org_contact_id        := p_frm_customer_contact_rec.cust_cont_org_rec.org_contact_id;
    x_customer_contact_rec.cust_cont_org_rec.contact_number        := p_frm_customer_contact_rec.cust_cont_org_rec.contact_number;
    x_customer_contact_rec.cust_cont_org_rec.job_title             := p_frm_customer_contact_rec.cust_cont_org_rec.job_title;
    x_customer_contact_rec.cust_cont_org_rec.job_title_code        := p_frm_customer_contact_rec.cust_cont_org_rec.job_title_code;
    x_customer_contact_rec.cust_cont_org_rec.orig_system_reference := p_frm_customer_contact_rec.cust_cont_org_rec.orig_system_reference;
    x_customer_contact_rec.cust_cont_org_rec.orig_system           := p_frm_customer_contact_rec.cust_cont_org_rec.orig_system;
    x_customer_contact_rec.cust_cont_org_rec.attribute_category    := p_frm_customer_contact_rec.cust_cont_org_rec.attribute_category;
    x_customer_contact_rec.cust_cont_org_rec.attribute1            := p_frm_customer_contact_rec.cust_cont_org_rec.attribute1;
    x_customer_contact_rec.cust_cont_org_rec.attribute2            := p_frm_customer_contact_rec.cust_cont_org_rec.attribute2;
    x_customer_contact_rec.cust_cont_org_rec.attribute3            := p_frm_customer_contact_rec.cust_cont_org_rec.attribute3;
    x_customer_contact_rec.cust_cont_org_rec.attribute4            := p_frm_customer_contact_rec.cust_cont_org_rec.attribute4;
    x_customer_contact_rec.cust_cont_org_rec.attribute5            := p_frm_customer_contact_rec.cust_cont_org_rec.attribute5;
    x_customer_contact_rec.cust_cont_org_rec.attribute6            := p_frm_customer_contact_rec.cust_cont_org_rec.attribute6;
    x_customer_contact_rec.cust_cont_org_rec.attribute7            := p_frm_customer_contact_rec.cust_cont_org_rec.attribute7;
    x_customer_contact_rec.cust_cont_org_rec.attribute8            := p_frm_customer_contact_rec.cust_cont_org_rec.attribute8;
    x_customer_contact_rec.cust_cont_org_rec.attribute9            := p_frm_customer_contact_rec.cust_cont_org_rec.attribute9;
    x_customer_contact_rec.cust_cont_org_rec.attribute10           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute10;
    x_customer_contact_rec.cust_cont_org_rec.attribute11           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute11;
    x_customer_contact_rec.cust_cont_org_rec.attribute12           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute12;
    x_customer_contact_rec.cust_cont_org_rec.attribute13           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute13;
    x_customer_contact_rec.cust_cont_org_rec.attribute14           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute14;
    x_customer_contact_rec.cust_cont_org_rec.attribute15           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute15;
    x_customer_contact_rec.cust_cont_org_rec.attribute16           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute16;
    x_customer_contact_rec.cust_cont_org_rec.attribute17           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute17;
    x_customer_contact_rec.cust_cont_org_rec.attribute18           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute18;
    x_customer_contact_rec.cust_cont_org_rec.attribute19           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute19;
    x_customer_contact_rec.cust_cont_org_rec.attribute20           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute20;
    x_customer_contact_rec.cust_cont_org_rec.attribute21           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute21;
    x_customer_contact_rec.cust_cont_org_rec.attribute22           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute22;
    x_customer_contact_rec.cust_cont_org_rec.attribute23           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute23;
    x_customer_contact_rec.cust_cont_org_rec.attribute24           := p_frm_customer_contact_rec.cust_cont_org_rec.attribute24;
    x_customer_contact_rec.cust_cont_org_rec.created_by_module     := p_frm_customer_contact_rec.cust_cont_org_rec.created_by_module;
    x_customer_contact_rec.cust_cont_org_rec.application_id        := p_frm_customer_contact_rec.cust_cont_org_rec.application_id;

    -- Contact Relationship
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.party_rec.party_id := p_frm_customer_contact_rec.cust_cont_org_rec.party_id;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.relationship_id    := p_frm_customer_contact_rec.cust_cont_org_rec.relationship_id;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.subject_id         := p_frm_customer_contact_rec.cust_cont_org_rec.subject_id;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.subject_type       := p_frm_customer_contact_rec.cust_cont_org_rec.subject_type;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.subject_table_name := p_frm_customer_contact_rec.cust_cont_org_rec.subject_table_name;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.object_id          := p_frm_customer_contact_rec.cust_cont_org_rec.object_id;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.object_type        := p_frm_customer_contact_rec.cust_cont_org_rec.object_type;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.object_table_name  := p_frm_customer_contact_rec.cust_cont_org_rec.object_table_name;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.relationship_code  := p_frm_customer_contact_rec.cust_cont_org_rec.relationship_code;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.relationship_type  := p_frm_customer_contact_rec.cust_cont_org_rec.relationship_type;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.comments           := p_frm_customer_contact_rec.cust_cont_org_rec.comments;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.start_date         := p_frm_customer_contact_rec.cust_cont_org_rec.start_date;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.end_date           := p_frm_customer_contact_rec.cust_cont_org_rec.end_date;
    x_customer_contact_rec.cust_cont_org_rec.party_rel_rec.status             := p_frm_customer_contact_rec.cust_cont_org_rec.status;

    -- Contact Point
    x_customer_contact_rec.cust_cont_point_rec.contact_point_id      := p_frm_customer_contact_rec.cust_cont_point_rec.contact_point_id;
    x_customer_contact_rec.cust_cont_point_rec.contact_point_type    := p_frm_customer_contact_rec.cust_cont_point_rec.contact_point_type;
    x_customer_contact_rec.cust_cont_point_rec.status                := p_frm_customer_contact_rec.cust_cont_point_rec.status;
    x_customer_contact_rec.cust_cont_point_rec.owner_table_name      := p_frm_customer_contact_rec.cust_cont_point_rec.owner_table_name;
    x_customer_contact_rec.cust_cont_point_rec.owner_table_id        := p_frm_customer_contact_rec.cust_cont_point_rec.owner_table_id;
    x_customer_contact_rec.cust_cont_point_rec.primary_flag          := p_frm_customer_contact_rec.cust_cont_point_rec.primary_flag;
    x_customer_contact_rec.cust_cont_point_rec.orig_system_reference := p_frm_customer_contact_rec.cust_cont_point_rec.orig_system_reference;
    x_customer_contact_rec.cust_cont_point_rec.orig_system           := p_frm_customer_contact_rec.cust_cont_point_rec.orig_system;
    x_customer_contact_rec.cust_cont_point_rec.content_source_type   := p_frm_customer_contact_rec.cust_cont_point_rec.content_source_type;
    x_customer_contact_rec.cust_cont_point_rec.attribute_category    := p_frm_customer_contact_rec.cust_cont_point_rec.attribute_category;
    x_customer_contact_rec.cust_cont_point_rec.attribute1            := p_frm_customer_contact_rec.cust_cont_point_rec.attribute1;
    x_customer_contact_rec.cust_cont_point_rec.attribute2            := p_frm_customer_contact_rec.cust_cont_point_rec.attribute2;
    x_customer_contact_rec.cust_cont_point_rec.attribute3            := p_frm_customer_contact_rec.cust_cont_point_rec.attribute3;
    x_customer_contact_rec.cust_cont_point_rec.attribute4            := p_frm_customer_contact_rec.cust_cont_point_rec.attribute4;
    x_customer_contact_rec.cust_cont_point_rec.attribute5            := p_frm_customer_contact_rec.cust_cont_point_rec.attribute5;
    x_customer_contact_rec.cust_cont_point_rec.attribute6            := p_frm_customer_contact_rec.cust_cont_point_rec.attribute6;
    x_customer_contact_rec.cust_cont_point_rec.attribute7            := p_frm_customer_contact_rec.cust_cont_point_rec.attribute7;
    x_customer_contact_rec.cust_cont_point_rec.attribute8            := p_frm_customer_contact_rec.cust_cont_point_rec.attribute8;
    x_customer_contact_rec.cust_cont_point_rec.attribute9            := p_frm_customer_contact_rec.cust_cont_point_rec.attribute9;
    x_customer_contact_rec.cust_cont_point_rec.attribute10           := p_frm_customer_contact_rec.cust_cont_point_rec.attribute10;
    x_customer_contact_rec.cust_cont_point_rec.attribute11           := p_frm_customer_contact_rec.cust_cont_point_rec.attribute11;
    x_customer_contact_rec.cust_cont_point_rec.attribute12           := p_frm_customer_contact_rec.cust_cont_point_rec.attribute12;
    x_customer_contact_rec.cust_cont_point_rec.attribute13           := p_frm_customer_contact_rec.cust_cont_point_rec.attribute13;
    x_customer_contact_rec.cust_cont_point_rec.attribute14           := p_frm_customer_contact_rec.cust_cont_point_rec.attribute14;
    x_customer_contact_rec.cust_cont_point_rec.attribute15           := p_frm_customer_contact_rec.cust_cont_point_rec.attribute15;
    x_customer_contact_rec.cust_cont_point_rec.attribute16           := p_frm_customer_contact_rec.cust_cont_point_rec.attribute16;
    x_customer_contact_rec.cust_cont_point_rec.attribute17           := p_frm_customer_contact_rec.cust_cont_point_rec.attribute17;
    x_customer_contact_rec.cust_cont_point_rec.attribute18           := p_frm_customer_contact_rec.cust_cont_point_rec.attribute18;
    x_customer_contact_rec.cust_cont_point_rec.attribute19           := p_frm_customer_contact_rec.cust_cont_point_rec.attribute19;
    x_customer_contact_rec.cust_cont_point_rec.attribute20           := p_frm_customer_contact_rec.cust_cont_point_rec.attribute20;
    x_customer_contact_rec.cust_cont_point_rec.contact_point_purpose := p_frm_customer_contact_rec.cust_cont_point_rec.contact_point_purpose;
    x_customer_contact_rec.cust_cont_point_rec.primary_by_purpose    := p_frm_customer_contact_rec.cust_cont_point_rec.primary_by_purpose;
    x_customer_contact_rec.cust_cont_point_rec.created_by_module     := p_frm_customer_contact_rec.cust_cont_point_rec.created_by_module;
    x_customer_contact_rec.cust_cont_point_rec.application_id        := p_frm_customer_contact_rec.cust_cont_point_rec.application_id;
    x_customer_contact_rec.cust_cont_point_rec.actual_content_source := p_frm_customer_contact_rec.cust_cont_point_rec.actual_content_source;

    RETURN x_customer_contact_rec;
    write_log('END LOAD_CONTACT_REC');
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Error in LOAD_CONTACT_REC: ' ||
	    dbms_utility.format_error_stack);
      RAISE;
  END load_contact_rec;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Assigns Oracle's standard record types to  form specific types to
  --            send back to the form.
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  FUNCTION load_contact_rec(p_customer_contact_rec customer_contact_rec)
    RETURN frm_customer_contact_rec IS
    x_customer_contact_rec frm_customer_contact_rec;
  BEGIN
    write_log('START LOAD_CONTACT_REC');

    -- Assign matching record types, including converting form version of location rec to Oracle API version
    -- of location rec.
    x_customer_contact_rec.party_ovn          := p_customer_contact_rec.party_ovn;
    x_customer_contact_rec.org_contact_ovn    := p_customer_contact_rec.org_contact_ovn;
    x_customer_contact_rec.relationship_ovn   := p_customer_contact_rec.relationship_ovn;
    x_customer_contact_rec.rel_party_ovn      := p_customer_contact_rec.rel_party_ovn;
    x_customer_contact_rec.location_ovn       := p_customer_contact_rec.location_ovn;
    x_customer_contact_rec.party_site_ovn     := p_customer_contact_rec.party_site_ovn;
    x_customer_contact_rec.party_site_use_ovn := p_customer_contact_rec.party_site_use_ovn;
    x_customer_contact_rec.role_ovn           := p_customer_contact_rec.role_ovn;
    x_customer_contact_rec.role_resp_ovn      := p_customer_contact_rec.role_resp_ovn;
    x_customer_contact_rec.contact_point_ovn  := p_customer_contact_rec.contact_point_ovn;
    x_customer_contact_rec.location_rec       := load_location_rec(p_customer_contact_rec.location_rec);

    x_customer_contact_rec.party_site_rec          := p_customer_contact_rec.party_site_rec;
    x_customer_contact_rec.party_site_use_rec      := p_customer_contact_rec.party_site_use_rec;
    x_customer_contact_rec.cust_cont_role_rec      := p_customer_contact_rec.cust_cont_role_rec;
    x_customer_contact_rec.cust_cont_role_resp_rec := p_customer_contact_rec.cust_cont_role_resp_rec;
    x_customer_contact_rec.cust_cont_phone_rec     := p_customer_contact_rec.cust_cont_phone_rec;
    x_customer_contact_rec.cust_cont_email_rec     := p_customer_contact_rec.cust_cont_email_rec;
    x_customer_contact_rec.cust_cont_web_rec       := p_customer_contact_rec.cust_cont_web_rec;

    x_customer_contact_rec.cust_cont_person_rec.person_pre_name_adjunct := p_customer_contact_rec.cust_cont_person_rec.person_pre_name_adjunct;
    x_customer_contact_rec.cust_cont_person_rec.person_first_name       := p_customer_contact_rec.cust_cont_person_rec.person_first_name;
    x_customer_contact_rec.cust_cont_person_rec.person_middle_name      := p_customer_contact_rec.cust_cont_person_rec.person_middle_name;
    x_customer_contact_rec.cust_cont_person_rec.person_last_name        := p_customer_contact_rec.cust_cont_person_rec.person_last_name;
    x_customer_contact_rec.cust_cont_person_rec.person_name_suffix      := p_customer_contact_rec.cust_cont_person_rec.person_name_suffix;
    x_customer_contact_rec.cust_cont_person_rec.person_title            := p_customer_contact_rec.cust_cont_person_rec.person_title;
    x_customer_contact_rec.cust_cont_person_rec.created_by_module       := p_customer_contact_rec.cust_cont_person_rec.created_by_module;
    x_customer_contact_rec.cust_cont_person_rec.party_rec               := p_customer_contact_rec.cust_cont_person_rec.party_rec;

    x_customer_contact_rec.cust_cont_org_rec.org_contact_id        := p_customer_contact_rec.cust_cont_org_rec.org_contact_id;
    x_customer_contact_rec.cust_cont_org_rec.contact_number        := p_customer_contact_rec.cust_cont_org_rec.contact_number;
    x_customer_contact_rec.cust_cont_org_rec.job_title             := p_customer_contact_rec.cust_cont_org_rec.job_title;
    x_customer_contact_rec.cust_cont_org_rec.job_title_code        := p_customer_contact_rec.cust_cont_org_rec.job_title_code;
    x_customer_contact_rec.cust_cont_org_rec.orig_system_reference := p_customer_contact_rec.cust_cont_org_rec.orig_system_reference;
    x_customer_contact_rec.cust_cont_org_rec.orig_system           := p_customer_contact_rec.cust_cont_org_rec.orig_system;
    x_customer_contact_rec.cust_cont_org_rec.attribute_category    := p_customer_contact_rec.cust_cont_org_rec.attribute_category;
    x_customer_contact_rec.cust_cont_org_rec.attribute1            := p_customer_contact_rec.cust_cont_org_rec.attribute1;
    x_customer_contact_rec.cust_cont_org_rec.attribute2            := p_customer_contact_rec.cust_cont_org_rec.attribute2;
    x_customer_contact_rec.cust_cont_org_rec.attribute3            := p_customer_contact_rec.cust_cont_org_rec.attribute3;
    x_customer_contact_rec.cust_cont_org_rec.attribute4            := p_customer_contact_rec.cust_cont_org_rec.attribute4;
    x_customer_contact_rec.cust_cont_org_rec.attribute5            := p_customer_contact_rec.cust_cont_org_rec.attribute5;
    x_customer_contact_rec.cust_cont_org_rec.attribute6            := p_customer_contact_rec.cust_cont_org_rec.attribute6;
    x_customer_contact_rec.cust_cont_org_rec.attribute7            := p_customer_contact_rec.cust_cont_org_rec.attribute7;
    x_customer_contact_rec.cust_cont_org_rec.attribute8            := p_customer_contact_rec.cust_cont_org_rec.attribute8;
    x_customer_contact_rec.cust_cont_org_rec.attribute9            := p_customer_contact_rec.cust_cont_org_rec.attribute9;
    x_customer_contact_rec.cust_cont_org_rec.attribute10           := p_customer_contact_rec.cust_cont_org_rec.attribute10;
    x_customer_contact_rec.cust_cont_org_rec.attribute11           := p_customer_contact_rec.cust_cont_org_rec.attribute11;
    x_customer_contact_rec.cust_cont_org_rec.attribute12           := p_customer_contact_rec.cust_cont_org_rec.attribute12;
    x_customer_contact_rec.cust_cont_org_rec.attribute13           := p_customer_contact_rec.cust_cont_org_rec.attribute13;
    x_customer_contact_rec.cust_cont_org_rec.attribute14           := p_customer_contact_rec.cust_cont_org_rec.attribute14;
    x_customer_contact_rec.cust_cont_org_rec.attribute15           := p_customer_contact_rec.cust_cont_org_rec.attribute15;
    x_customer_contact_rec.cust_cont_org_rec.attribute16           := p_customer_contact_rec.cust_cont_org_rec.attribute16;
    x_customer_contact_rec.cust_cont_org_rec.attribute17           := p_customer_contact_rec.cust_cont_org_rec.attribute17;
    x_customer_contact_rec.cust_cont_org_rec.attribute18           := p_customer_contact_rec.cust_cont_org_rec.attribute18;
    x_customer_contact_rec.cust_cont_org_rec.attribute19           := p_customer_contact_rec.cust_cont_org_rec.attribute19;
    x_customer_contact_rec.cust_cont_org_rec.attribute20           := p_customer_contact_rec.cust_cont_org_rec.attribute20;
    x_customer_contact_rec.cust_cont_org_rec.attribute21           := p_customer_contact_rec.cust_cont_org_rec.attribute21;
    x_customer_contact_rec.cust_cont_org_rec.attribute22           := p_customer_contact_rec.cust_cont_org_rec.attribute22;
    x_customer_contact_rec.cust_cont_org_rec.attribute23           := p_customer_contact_rec.cust_cont_org_rec.attribute23;
    x_customer_contact_rec.cust_cont_org_rec.attribute24           := p_customer_contact_rec.cust_cont_org_rec.attribute24;
    x_customer_contact_rec.cust_cont_org_rec.created_by_module     := p_customer_contact_rec.cust_cont_org_rec.created_by_module;
    x_customer_contact_rec.cust_cont_org_rec.application_id        := p_customer_contact_rec.cust_cont_org_rec.application_id;

    x_customer_contact_rec.cust_cont_org_rec.relationship_id    := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.relationship_id;
    x_customer_contact_rec.cust_cont_org_rec.subject_id         := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.subject_id;
    x_customer_contact_rec.cust_cont_org_rec.subject_type       := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.subject_type;
    x_customer_contact_rec.cust_cont_org_rec.subject_table_name := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.subject_table_name;
    x_customer_contact_rec.cust_cont_org_rec.object_id          := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.object_id;
    x_customer_contact_rec.cust_cont_org_rec.object_type        := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.object_type;
    x_customer_contact_rec.cust_cont_org_rec.object_table_name  := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.object_table_name;
    x_customer_contact_rec.cust_cont_org_rec.relationship_code  := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.relationship_code;
    x_customer_contact_rec.cust_cont_org_rec.relationship_type  := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.relationship_type;
    x_customer_contact_rec.cust_cont_org_rec.comments           := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.comments;
    x_customer_contact_rec.cust_cont_org_rec.start_date         := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.start_date;
    x_customer_contact_rec.cust_cont_org_rec.end_date           := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.end_date;
    x_customer_contact_rec.cust_cont_org_rec.status             := p_customer_contact_rec.cust_cont_org_rec.party_rel_rec.status;

    x_customer_contact_rec.cust_cont_point_rec.contact_point_id      := p_customer_contact_rec.cust_cont_point_rec.contact_point_id;
    x_customer_contact_rec.cust_cont_point_rec.status                := p_customer_contact_rec.cust_cont_point_rec.status;
    x_customer_contact_rec.cust_cont_point_rec.owner_table_name      := p_customer_contact_rec.cust_cont_point_rec.owner_table_name;
    x_customer_contact_rec.cust_cont_point_rec.owner_table_id        := p_customer_contact_rec.cust_cont_point_rec.owner_table_id;
    x_customer_contact_rec.cust_cont_point_rec.primary_flag          := p_customer_contact_rec.cust_cont_point_rec.primary_flag;
    x_customer_contact_rec.cust_cont_point_rec.orig_system_reference := p_customer_contact_rec.cust_cont_point_rec.orig_system_reference;
    x_customer_contact_rec.cust_cont_point_rec.orig_system           := p_customer_contact_rec.cust_cont_point_rec.orig_system;
    x_customer_contact_rec.cust_cont_point_rec.content_source_type   := p_customer_contact_rec.cust_cont_point_rec.content_source_type;
    x_customer_contact_rec.cust_cont_point_rec.attribute_category    := p_customer_contact_rec.cust_cont_point_rec.attribute_category;
    x_customer_contact_rec.cust_cont_point_rec.attribute1            := p_customer_contact_rec.cust_cont_point_rec.attribute1;
    x_customer_contact_rec.cust_cont_point_rec.attribute2            := p_customer_contact_rec.cust_cont_point_rec.attribute2;
    x_customer_contact_rec.cust_cont_point_rec.attribute3            := p_customer_contact_rec.cust_cont_point_rec.attribute3;
    x_customer_contact_rec.cust_cont_point_rec.attribute4            := p_customer_contact_rec.cust_cont_point_rec.attribute4;
    x_customer_contact_rec.cust_cont_point_rec.attribute5            := p_customer_contact_rec.cust_cont_point_rec.attribute5;
    x_customer_contact_rec.cust_cont_point_rec.attribute6            := p_customer_contact_rec.cust_cont_point_rec.attribute6;
    x_customer_contact_rec.cust_cont_point_rec.attribute7            := p_customer_contact_rec.cust_cont_point_rec.attribute7;
    x_customer_contact_rec.cust_cont_point_rec.attribute8            := p_customer_contact_rec.cust_cont_point_rec.attribute8;
    x_customer_contact_rec.cust_cont_point_rec.attribute9            := p_customer_contact_rec.cust_cont_point_rec.attribute9;
    x_customer_contact_rec.cust_cont_point_rec.attribute10           := p_customer_contact_rec.cust_cont_point_rec.attribute10;
    x_customer_contact_rec.cust_cont_point_rec.attribute11           := p_customer_contact_rec.cust_cont_point_rec.attribute11;
    x_customer_contact_rec.cust_cont_point_rec.attribute12           := p_customer_contact_rec.cust_cont_point_rec.attribute12;
    x_customer_contact_rec.cust_cont_point_rec.attribute13           := p_customer_contact_rec.cust_cont_point_rec.attribute13;
    x_customer_contact_rec.cust_cont_point_rec.attribute14           := p_customer_contact_rec.cust_cont_point_rec.attribute14;
    x_customer_contact_rec.cust_cont_point_rec.attribute15           := p_customer_contact_rec.cust_cont_point_rec.attribute15;
    x_customer_contact_rec.cust_cont_point_rec.attribute16           := p_customer_contact_rec.cust_cont_point_rec.attribute16;
    x_customer_contact_rec.cust_cont_point_rec.attribute17           := p_customer_contact_rec.cust_cont_point_rec.attribute17;
    x_customer_contact_rec.cust_cont_point_rec.attribute18           := p_customer_contact_rec.cust_cont_point_rec.attribute18;
    x_customer_contact_rec.cust_cont_point_rec.attribute19           := p_customer_contact_rec.cust_cont_point_rec.attribute19;
    x_customer_contact_rec.cust_cont_point_rec.attribute20           := p_customer_contact_rec.cust_cont_point_rec.attribute20;
    x_customer_contact_rec.cust_cont_point_rec.contact_point_purpose := p_customer_contact_rec.cust_cont_point_rec.contact_point_purpose;
    x_customer_contact_rec.cust_cont_point_rec.primary_by_purpose    := p_customer_contact_rec.cust_cont_point_rec.primary_by_purpose;
    x_customer_contact_rec.cust_cont_point_rec.created_by_module     := p_customer_contact_rec.cust_cont_point_rec.created_by_module;
    x_customer_contact_rec.cust_cont_point_rec.application_id        := p_customer_contact_rec.cust_cont_point_rec.application_id;
    x_customer_contact_rec.cust_cont_point_rec.actual_content_source := p_customer_contact_rec.cust_cont_point_rec.actual_content_source;

    write_log('END LOAD_CONTACT_REC');
    RETURN x_customer_contact_rec;
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Error in LOAD_CONTACT_REC: ' ||
	    dbms_utility.format_error_stack);
      RAISE;
  END load_contact_rec;

  -- -------------------------------------------------------------------------------
  -- Purpose  : Wrapper procedure of handle_contacts.  This procedure is called from
  --            the XXHZCUSTOMER.fmb form.
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  -- -------------------------------------------------------------------------------
  PROCEDURE frm_handle_contacts(p_new_contact_flag IN VARCHAR2,
		        p_cust_contact_rec IN OUT frm_customer_contact_rec,
		        x_return_message   OUT VARCHAR2,
		        x_return_status    OUT VARCHAR2) IS
    l_customer_contact_rec customer_contact_rec;
    e_error EXCEPTION;
  BEGIN
    write_log('FRM_HANDLE_CONTACTS');

    -- Convert frm record types to Oracle recort types for use with Oracle's APIs
    l_customer_contact_rec := load_contact_rec(p_cust_contact_rec);

    handle_contacts(p_cust_contact_rec => l_customer_contact_rec,
	        x_return_message   => x_return_message,
	        x_return_status    => x_return_status);

    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      RAISE e_error;
    END IF;

    -- When creating new records users have the option to create multiple contact points at the same time.
    -- (phone, cell phone, email).  This code will handle creating the multiple contacts points
    IF p_new_contact_flag = 'Y' THEN
      -- Call contact point API to create mobile phone
      l_customer_contact_rec.cust_cont_phone_rec                    := p_cust_contact_rec.mobile_cont_phone_rec;
      l_customer_contact_rec.cust_cont_point_rec.contact_point_type := 'PHONE';
      l_customer_contact_rec.cust_cont_point_rec.contact_point_id   := NULL;

      contact_point_api(p_customer_contact_rec => l_customer_contact_rec,
		x_return_status        => x_return_status,
		x_return_message       => x_return_message);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;
    END IF;

    IF p_new_contact_flag = 'Y' THEN
      l_customer_contact_rec.cust_cont_point_rec.contact_point_type := 'EMAIL';
      l_customer_contact_rec.cust_cont_point_rec.contact_point_id   := NULL;

      -- Call contact point API to create email
      contact_point_api(p_customer_contact_rec => l_customer_contact_rec,
		x_return_status        => x_return_status,
		x_return_message       => x_return_message);

      IF x_return_status <> fnd_api.g_ret_sts_success THEN
        RAISE e_error;
      END IF;
    END IF;

    -- Convert Oracle record types to frm record types
    p_cust_contact_rec := load_contact_rec(l_customer_contact_rec);

    write_log('Return Status from FRM_HANDLE_CONTACTS: ' ||
	  x_return_status);
    write_log('END FRM_HANDLE_CONTACTS');
  EXCEPTION
    WHEN e_error THEN
      write_log(x_return_message);
      write_log('END FRM_HANDLE_CONTACTS (E_ERROR)');
    WHEN OTHERS THEN
      x_return_message := 'Error in FRM_HANDLE_CONTACTS: ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := fnd_api.g_ret_sts_error;
      write_log('END FRM_HANDLE_CONTACTS (EXCEPTION)');

  END frm_handle_contacts;

  ----------------------------------------------------------------------------------
  -- Purpose  : Called from XXHZCUSTOMER.fmb from the ON-LOCK trigger for contact
  --            entities.  See handle_account_lock comments for full explanation
  --            of how this works.
  --
  -- Change History
  -- ...............................................................................
  -- 10-JUN-2015   MMAZANET        CHG0035118. Initial creation.
  ----------------------------------------------------------------------------------
  PROCEDURE handle_contact_lock(p_customer_contact_rec IN OUT frm_customer_contact_rec,
		        x_return_status        OUT VARCHAR2,
		        x_return_message       OUT VARCHAR2) IS
    l_ovn hz_parties.object_version_number%TYPE;

    e_error EXCEPTION;
  BEGIN
    g_program_unit := 'HANDLE_CONTACT_LOCK';
    write_log('START ' || g_program_unit);
    --write_log('p_acc_rec.cust_organization_rec.party_id '||p_acc_rec.cust_organization_rec.party_id);

    l_ovn := get_object_version_number('CONTACT_PARTY',
			   p_customer_contact_rec.cust_cont_person_rec.party_rec.party_id);
    IF p_customer_contact_rec.party_ovn <> l_ovn THEN
      x_return_message := 'HZ_PARTIES contact record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('ORG_CONTACT',
			   p_customer_contact_rec.cust_cont_org_rec.org_contact_id);
    IF p_customer_contact_rec.org_contact_ovn <> l_ovn THEN
      x_return_message := 'HZ_ORG_CONTACTS contact record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('ROLE',
			   p_customer_contact_rec.cust_cont_role_rec.cust_account_role_id);
    IF p_customer_contact_rec.role_ovn <> l_ovn THEN
      x_return_message := 'HZ_CUST_ACCOUNT_ROLES contact record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('LOCATION',
			   p_customer_contact_rec.location_rec.location_id);
    IF p_customer_contact_rec.location_ovn <> l_ovn THEN
      x_return_message := 'HZ_LOCATIONS contact record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('PARTY_SITE',
			   p_customer_contact_rec.party_site_rec.party_site_id);
    IF p_customer_contact_rec.party_site_ovn <> l_ovn THEN
      x_return_message := 'HZ_PARTY_SITE contact record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('CONTACT_SITE_USE',
			   p_customer_contact_rec.party_site_use_rec.party_site_use_id);
    IF p_customer_contact_rec.party_site_use_ovn <> l_ovn THEN
      x_return_message := 'HZ_PARTY_SITE_USES contact record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('CONTACT_ROLE_RESPONSIBILITY',
			   p_customer_contact_rec.cust_cont_role_resp_rec.responsibility_id);
    IF p_customer_contact_rec.role_resp_ovn <> l_ovn THEN
      x_return_message := 'HZ_RESPONSIBILITY contact record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    l_ovn := get_object_version_number('CONTACT_POINT',
			   p_customer_contact_rec.cust_cont_point_rec.contact_point_id);
    IF p_customer_contact_rec.contact_point_ovn <> l_ovn THEN
      x_return_message := 'HZ_CONTACT_POINTS contact record has been changed.  Please re-query.';
      RAISE e_error;
    END IF;

    write_log('END HANDLE_CONTACT_LOCK');
  EXCEPTION
    WHEN e_error THEN
      x_return_status := 'E';
      write_log('END HANDLE_CONTACT_LOCK (E_ERROR)');
    WHEN OTHERS THEN
      x_return_message := 'Error in ' || g_program_unit || ': ' ||
		  dbms_utility.format_error_stack;
      write_log(x_return_message);
      x_return_status := 'E';
      write_log('END HANDLE_CONTACT_LOCK (EXCEPTION)');
  END handle_contact_lock;

END xxhz_api_pkg;
/