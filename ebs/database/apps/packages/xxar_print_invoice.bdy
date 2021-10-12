create or replace package body xxar_print_invoice IS
  --------------------------------------------------------------------
  --  name:            XXAR_PRINT_INVOICE
  --  create by:       Daniel Katz
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :        This package handle ap print invoice
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/2010  Daniel Katz       initial build
  --  1.1  06/10/2011  Dalit A. Raviv    add the ability to send invoice output by mail
  --  1.2  19/01/2012  Dalit A. RAviv    procedure Print_Invoice_Send_mail - modifications
  --       17/06/2012  Ofer Suad         add parameters p_print_zero_amt and printing category
  --  1.3  14/04/2013  yuval tal         CR724 Invoice for Japan: modify procedure print_invoice_no_mail
  --  1.4  1/05/2014   Dalit A. Raviv    CHG0032051 -  change in the invoice process related to sending to a certain email
  --                                     change logic of get_send_to_mail,
  --  1.5   3/3/2017    Sandeep Patel     CHG0039377 Development - Requested Changes to Lease Invoice
  --                                     CHG0037087 Update and standardize email generation logic
  --                                     New Procedure Added : get_Invoice_email_info()
  --                                     New Function Added  : get_invoice_water_mark()
  --  1.6 06.06.2017   Lingaraj(TCS)     CHG0040768 - Enhance Invoice Ditribution Functionality
  --  1.7 29.07.2017   Lingaraj(TCS)     INC0098186 - None of the customer that should be email a invoic
  --  2.0 05/03/2018   Erik Morgan       CHG0042403 - Change location of email to customer bill-to address
  --  2.1 06/05/2018   Bellona(TCS)      CHG0041929 - Added new paramter p_template in procedure get_Invoice_email_info
  --                    for the logic of introducing Dynamic template for AR Invoice Print bursting process
  --  2.3 23/08/2018   Roman Winer      CHG0040499(BR5) - Created new function add_delivery_options for adding delivery option to programs.
  --                      "XX: AR DE Invoice" / "XX: AR Invoice" / "XX: SSUS AR Invoice"
  --  2.4 15/10/2918   Bellona(TCS)      CHG0040499(BR6) - Simplify logic for sending email, created new function - get_send_bcc_email,
  --                      Modified procedures - get_Invoice_email_info, get_send_to_email and function - afterreport.
  --  2.5 22/01/2019   Roman W.          INC0144462  "get_send_bcc_email" replace ";" with ","
  -- 2.6  13/02/2021   Ofer Suad         CHG0045485 - put OKS creator msg token in Rem 
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            add_delivery_options
  --  create by:       XXXXX
  --  Revision:        1.0
  --  creation date:   23/08/2018
  --------------------------------------------------------------------
  --  purpose :   CHG0040499(BR5) - new function before submitting programs.
  --        "XX: AR DE Invoice" / "XX: AR Invoice" / "XX: SSUS AR Invoice"
  --------------------------------------------------------------------
  --  ver  date        name               desc
  --  1.0  23/08/2018  Roman Winer       initial build
  --------------------------------------------------------------------
  FUNCTION add_delivery_options(p_req_id IN NUMBER) RETURN NUMBER IS
    l_result     NUMBER;
    l_bol_result BOOLEAN;
    l_subject    fnd_conc_pp_actions.argument2%TYPE;
    l_mail_from  fnd_conc_pp_actions.argument3%TYPE;
    l_mail_to    fnd_conc_pp_actions.argument4%TYPE;
    l_mail_cc    fnd_conc_pp_actions.argument5%TYPE;
    l_mail_lang  fnd_conc_pp_actions.argument6%TYPE;
    l_arg7       fnd_conc_pp_actions.argument7%TYPE;

  BEGIN

    select fcpa.argument2 SUBJECT,
           fcpa.argument3 MAIL_FROM,
           fcpa.argument4 MAIL_TO,
           fcpa.argument5 MAIL_CC,
           fcpa.argument6 MAIL_LANG,
           fcpa.argument7
      into l_subject,
           l_mail_from,
           l_mail_to,
           l_mail_cc,
           l_mail_lang,
           l_arg7
      from apps.fnd_conc_pp_actions fcpa
     where 1 = 1
       and fcpa.concurrent_request_id = p_req_id --fnd_global.CONC_REQUEST_ID
       and fcpa.action_type = 7
       and fcpa.argument1 = 'E';

    -- Boolean parameters are translated from/to integers:
    -- 0/1/null <--> false/true/null
    --
    l_bol_result := fnd_delivery.add_email(subject      => l_subject,
                                           from_address => l_mail_from,
                                           to_address   => l_mail_to,
                                           cc           => l_mail_cc,
                                           lang         => l_mail_lang);
    -- Convert false/true/null to 0/1/null
    l_result := sys.diutil.bool_to_int(l_bol_result);
    return(l_result);

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Error while retrieving delivery_option');
      fnd_file.put_line(fnd_file.log, 'Error: ' || SQLERRM);
      return(null);
  END add_delivery_options;
  --------------------------------------------------------------------
  --  name:            bill_to_contact_email
  --  create by:       Erik Morgan
  --  Revision:        2.0
  --  creation date:   05/03/2018
  --------------------------------------------------------------------
  --  purpose :        Private function to return invoice email address for invoices from bill to contact on invoice
  --                   if contact is configured to receive invoices by mail
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  2.0  05/03/2018  Erik Morgan         CHG0042403 - Change location of email to customer bill-to address
  --------------------------------------------------------------------
  FUNCTION bill_to_contact_email(p_customer_trx_id IN NUMBER) RETURN VARCHAR2 IS
    l_b2_contact_mail hz_contact_points.email_address%type; --VARCHAR2(2000 BYTE)

  BEGIN
    Select b2_ct_point.email_address
    --,b2_party.party_id, b2_party.party_number, b2_party.party_name, b2_party.party_type, b2_party.person_first_name, b2_party.person_middle_name, b2_party.person_last_name, b2_party.status, b2_party.do_not_mail_flag
    --,b2_relationship.relationship_id, b2_relationship.subject_id, b2_relationship.subject_type, b2_relationship.subject_table_name, b2_relationship.object_id, b2_relationship.object_type, b2_relationship.object_table_name, b2_relationship.relationship_code, b2_relationship.directional_flag, b2_relationship.status, b2_relationship.relationship_type
    --,b2_contact.org_contact_id, b2_contact.party_relationship_id, b2_contact.contact_number
    --,b2_ct_point.contact_point_id, b2_ct_point.contact_point_type, b2_ct_point.status, b2_ct_point.owner_table_name, b2_ct_point.owner_table_id, b2_ct_point.primary_flag, b2_ct_point.email_format
    --,inv_ct_type.responsibility_type, inv_ct_role.cust_account_role_id
      Into l_b2_contact_mail
      From ar.hz_parties             b2_party,
           ar.hz_relationships       b2_relationship,
           ar.hz_org_contacts        b2_contact,
           ar.hz_contact_points      b2_ct_point,
           ar.hz_cust_account_roles  inv_ct_role,
           ar.Hz_Role_Responsibility inv_ct_type,
           ar.ra_customer_trx_all    rta
     Where rta.customer_trx_id = p_customer_trx_id
       and rta.bill_to_contact_id = inv_ct_role.cust_account_role_id
       and rta.bill_to_customer_id = inv_ct_role.cust_account_id
       and b2_party.party_id = b2_relationship.subject_id
       and b2_relationship.subject_table_name = 'HZ_PARTIES'
       and b2_relationship.object_table_name = 'HZ_PARTIES'
       and b2_relationship.directional_flag = 'F'
       and b2_relationship.relationship_id =
           b2_contact.party_relationship_id
       and b2_relationship.party_id = b2_ct_point.owner_table_id
       and b2_ct_point.owner_table_name = 'HZ_PARTIES'
       and b2_ct_point.contact_point_type = 'EMAIL'
       and b2_relationship.party_id = inv_ct_role.party_id
       and inv_ct_role.cust_account_role_id =
           inv_ct_type.cust_account_role_id
       and inv_ct_type.responsibility_type = 'INV' --Invoices contact role
    ;

    fnd_file.put_line(fnd_file.log,
                      'bill_to_contact_email Function Returned :' ||
                      l_b2_contact_mail);

    RETURN l_b2_contact_mail;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      fnd_file.put_line(fnd_file.log,
                        'bill_to_contact_email Function Returned : ');
      Return Null;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'bill_to_contact_email Function Returned : Error');
      fnd_file.put_line(fnd_file.log, 'Error: ' || SQLERRM);
      Return Null;

  END bill_to_contact_email;

  --------------------------------------------------------------------
  --  name:            bill_to_address_email
  --  create by:       Erik Morgan
  --  Revision:        2.0
  --  creation date:   05/03/2018
  --------------------------------------------------------------------
  --  purpose :        Private function to return invoice email address for invoices from bill to address on invoice
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  2.0  05/03/2018  Erik Morgan         CHG0042403 - Change location of email to customer bill-to address
  --------------------------------------------------------------------
  FUNCTION bill_to_address_email(p_customer_trx_id IN NUMBER) RETURN VARCHAR2 IS
    l_b2_address_mail hz_contact_points.email_address%type;

  BEGIN
    Select inv_email.email_address
    --,b2_csu.site_use_id as b2_site_use_id, b2_csu.cust_acct_site_id, b2_csu.site_use_code, b2_csu.bill_to_site_use_id, b2_csu.org_id
    --,rta.trx_number
    --,cas.cust_account_id, cas.party_site_id, cas.org_id
    --,inv_csu.site_use_id as inv_site_use_id, inv_csu.site_use_code, inv_csu.primary_flag, inv_csu.status, inv_csu.location, inv_csu.org_id, inv_csu.created_by_module, inv_csu.application_id
    --,inv_email.contact_point_id, inv_email.contact_point_type, inv_email.status, inv_email.primary_flag, inv_email.email_format
      Into l_b2_address_mail
      from ar.ra_customer_trx_all    rta,
           ar.HZ_CUST_SITE_USES_ALL  b2_csu,
           ar.HZ_CUST_ACCT_SITES_ALL cas,
           ar.HZ_CUST_SITE_USES_ALL  inv_csu,
           ar.hz_contact_points      inv_email
     where rta.customer_trx_id = p_customer_trx_id
       and rta.bill_to_site_use_id = b2_csu.site_use_id
       and cas.cust_acct_site_id = b2_csu.cust_acct_site_id
       and cas.cust_acct_site_id = inv_csu.cust_acct_site_id
       and inv_csu.site_use_code = 'INV'
       and inv_csu.status = 'A'
       and cas.party_site_id = inv_email.owner_table_id
       and inv_email.owner_table_name = 'HZ_PARTY_SITES'
       and inv_email.contact_point_type = 'EMAIL'
       and inv_email.status = 'A'
       and inv_email.primary_flag = 'Y';

    fnd_file.put_line(fnd_file.log,
                      'bill_to_address_email Function Returned :' ||
                      l_b2_address_mail);

    RETURN l_b2_address_mail;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      fnd_file.put_line(fnd_file.log,
                        'bill_to_address_email Function Returned : ');
      Return Null;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'bill_to_address_email Function Returned : Error');
      fnd_file.put_line(fnd_file.log, 'Error: ' || SQLERRM);
      Return Null;

  END bill_to_address_email;

  --------------------------------------------------------------------
  --  name:            default_invoices_email
  --  create by:       Erik Morgan
  --  Revision:        2.0
  --  creation date:   05/03/2018
  --------------------------------------------------------------------
  --  purpose :        Private function to return default invoice email for invoices from primary Invoices site
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  2.0  05/03/2018  Erik Morgan         CHG0042403 - Change location of email to customer bill-to address
  --------------------------------------------------------------------
  FUNCTION default_invoices_email(p_customer_trx_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_default_invoices_email hz_contact_points.email_address%type;

  BEGIN
    Select d_email.email_address
    --,rta.trx_number
    --,dcas.cust_account_id, dcas.party_site_id, dcas.org_id, d_csu.site_use_id, d_csu.site_use_code, d_csu.primary_flag, d_csu.status, d_csu.location, d_csu.org_id, d_csu.created_by_module, d_csu.application_id
    --,d_email.contact_point_id, d_email.contact_point_type, d_email.status, d_email.primary_flag, d_email.email_format
      Into l_default_invoices_email
      From ar.ra_customer_trx_all    rta,
           ar.HZ_CUST_ACCT_SITES_ALL dcas,
           ar.HZ_CUST_SITE_USES_ALL  d_csu,
           ar.hz_contact_points      d_email
     Where rta.customer_trx_id = p_customer_trx_id
       And rta.bill_to_customer_id = dcas.cust_account_id
       And rta.org_id = dcas.org_id
       And dcas.status = 'A'
       And dcas.cust_acct_site_id = d_csu.cust_acct_site_id
       And d_csu.site_use_code = 'INV'
       And d_csu.status = 'A'
       And d_csu.primary_flag = 'Y'
       And dcas.party_site_id = d_email.owner_table_id
       And d_email.owner_table_name = 'HZ_PARTY_SITES'
       And d_email.contact_point_type = 'EMAIL'
       And d_email.status = 'A'
       And d_email.primary_flag = 'Y';

    fnd_file.put_line(fnd_file.log,
                      'default_invoices_email Function Returned: ' ||
                      l_default_invoices_email);

    RETURN l_default_invoices_email;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      fnd_file.put_line(fnd_file.log,
                        'default_invoices_email Function Returned: ');
      Return Null;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'default_invoices_email Function Returned: Error');
      fnd_file.put_line(fnd_file.log, 'Error: ' || SQLERRM);
      Return Null;

  END default_invoices_email;

  --------------------------------------------------------------------
  --  name:            Print_Invoice_Special
  --  create by:       Daniel Katz
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/2010  Daniel Katz       initial build
  --------------------------------------------------------------------
  PROCEDURE print_invoice_special(p_org_id             IN NUMBER,
                                  p_choice             IN NUMBER,
                                  p_batch_source_id    IN NUMBER,
                                  p_cust_trx_class     IN VARCHAR2,
                                  p_cust_trx_type_id   IN ra_cust_trx_types.cust_trx_type_id%TYPE,
                                  p_customer_name_low  IN hz_parties.party_name%TYPE,
                                  p_customer_name_high IN hz_parties.party_name%TYPE,
                                  p_customer_no_low    IN hz_cust_accounts.account_number%TYPE,
                                  p_customer_no_high   IN hz_cust_accounts.account_number%TYPE,
                                  p_trx_from           IN ra_interface_lines.trx_number%TYPE,
                                  p_to_trx             IN ra_interface_lines.trx_number%TYPE,
                                  p_installment        IN NUMBER,
                                  p_from_date          IN VARCHAR2,
                                  p_to_date            IN VARCHAR2,
                                  p_open_invoices_only IN VARCHAR2,
                                  --parameter added by daniel katz
                                  p_printing_pending IN VARCHAR2,
                                  --added by daniel katz on 28-mar-10
                                  p_show_country_origin IN VARCHAR2) IS
    l_request_id NUMBER;
    l_choice     NUMBER := p_choice; --varialble added by daniel katz

  BEGIN
    --if block added  by daniel katz
    IF p_printing_pending = 'N' THEN
      l_choice := 2; --from personalization it comes "Draft" (3) and if it is already originaly printed then it should be changed to "copy" (2)
    END IF;

    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXARPRTINV_NEW',
                                               argument1   => p_org_id,
                                               argument2   => l_choice, --changed by daniel katz
                                               argument3   => p_batch_source_id,
                                               argument4   => p_cust_trx_class,
                                               argument5   => p_cust_trx_type_id,
                                               argument6   => p_customer_name_low,
                                               argument7   => p_customer_name_high,
                                               argument8   => p_customer_no_low,
                                               argument9   => p_customer_no_high,
                                               argument10  => p_installment,
                                               argument11  => p_trx_from,
                                               argument12  => p_to_trx,
                                               argument13  => p_from_date, --P_FROM_DATE,
                                               argument14  => p_to_date, --P_TO_DATE,
                                               argument15  => p_open_invoices_only,
                                               --added by daniel katz on 28-mar-10
                                               argument16 => p_show_country_origin);

    COMMIT;
    fnd_file.put_line(fnd_file.log, 'submit_request: ' || l_request_id);
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Procedure Exception: ' || SQLERRM);
  END print_invoice_special;

  --------------------------------------------------------------------
  --  name:            Print_Invoice_no_mail
  --  create by:       Daniel Katz
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :        Program that print AR invoices
  --                   Concurrent XX: Print Invoice
  --                   Report     XXAR_INVOICE
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/2010  Daniel Katz       initial build
  --  1.1  06/10/2011  Dalit A. Raviv    add the ability to send invoice output by mail
  --                                     if customer sent parameter p_send_mail the program will
  --                                     send each invoice to a different customer by mail.
  --                                     add 2 return parameters
  -- 1.2   14/04/2013 yuval tal          CR724 Invoice for Japan : support jpn ORG - set template XXAR_JPN_TRX_REP
  -- 1.5   3/3/2017    Sandeep Patel     CHG0039377 Development - Requested Changes to Lease Invoice
  --                                     CHG0037087 Update and standardize email generation logic
  -- 1.6   24/08/2018  Roman Winer       CHG0040499(BR5) Call to function add_delivery_options before submitting programs.
  --                                        "XX: AR DE Invoice" / "XX: AR Invoice" / "XX: SSUS AR Invoice"
  --------------------------------------------------------------------
  PROCEDURE print_invoice_new(errbuf               OUT VARCHAR2,
                              retcode              OUT NUMBER,
                              p_request_id         OUT NUMBER, -- Dalit A. Raviv 06/10/2011
                              p_conc_shor_name     OUT VARCHAR2, -- Dalit A. Raviv 06/10/2011
                              p_org_id             IN NUMBER,
                              p_choice             IN NUMBER,
                              p_batch_source_id    IN NUMBER,
                              p_cust_trx_class     IN VARCHAR2,
                              p_cust_trx_type_id   IN ra_cust_trx_types.cust_trx_type_id%TYPE,
                              p_customer_name_low  IN hz_parties.party_name%TYPE,
                              p_customer_name_high IN hz_parties.party_name%TYPE,
                              p_customer_no_low    IN hz_cust_accounts.account_number%TYPE,
                              p_customer_no_high   IN hz_cust_accounts.account_number%TYPE,
                              p_installment        IN NUMBER,
                              p_trx_from           IN ra_interface_lines.trx_number%TYPE,
                              p_to_trx             IN ra_interface_lines.trx_number%TYPE,
                              p_from_date          IN VARCHAR2,
                              p_to_date            IN VARCHAR2,
                              p_open_invoices_only IN VARCHAR2,
                              -- daniel katz on 28-mar-10
                              p_show_country_origin IN VARCHAR2,
                              p_print_zero_amt      IN VARCHAR2,
                              p_printing_category   IN VARCHAR2,
                              p_invoice_dist_mode   IN NUMBER --Added on 06.06.2017 for CHG0040768, in place of p_send_mail
                              -- Dalit A. Raviv 08/05/2014
                              --p_send_mail IN VARCHAR2  -- Commented on 06.06.2017 for CHG0040768
                              ) IS

    v_request_id NUMBER := fnd_global.conc_request_id;
    l_request_id NUMBER;
    l_result     BOOLEAN;
    v_country    VARCHAR2(20);
    v_count      NUMBER;
    v_no_copies  NUMBER;
    v_printer    VARCHAR2(30);
    lb_flag      BOOLEAN := FALSE;
    v_us_org     NUMBER := 89;
    v_copy_orig  VARCHAR2(1);
    -- 07/05/2014 Dalit A. Raviv
    l_env VARCHAR2(20) := xxobjt_general_utils_pkg.am_i_in_production; -- return Y if Production; --CHG0040768
    --l_send_mail VARCHAR2(20) := NULL;--CHG0040768
    -- v_source VARCHAR2(100) := 'OTHERS'; -- spatel
    v_batch_source_id NUMBER; -- spatel
    l_del_result      NUMBER; -- CHG0040499(BR5)
  BEGIN

    --v_from_date := to_date(P_FROM_DATE, 'YYYY/MM/DD HH24:MI:SS');
    --v_to_date   := to_date(P_TO_DATE, 'YYYY/MM/DD HH24:MI:SS');

    --fnd_file.put_line(fnd_file.log, 'P_FROM_DATE: ' || v_from_date);
    --fnd_file.put_line(fnd_file.log, 'P_TO_DATE: ' || v_to_date);

    BEGIN
      SELECT fcr.number_of_copies, fcr.printer
        INTO v_no_copies, v_printer
        FROM fnd_concurrent_requests fcr
       WHERE fcr.request_id = v_request_id;

    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log,
                          'Execption Request_id: ' || v_request_id);
        v_no_copies := NULL;
        v_printer   := NULL;
    END;
    -------------------------------- No Printer-------------
    -- 07/05/2014 Dalit A. Raviv add condition of environment
    --l_env := xxagile_util_pkg.get_bpel_domain;
    --l_env := xxobjt_general_utils_pkg.am_i_in_production; -- return Y if Production --CHG0040768
    --if l_env = 'production' and (p_org_id <> v_us_org) then --
    IF l_env = 'Y' AND (p_org_id <> v_us_org) THEN
      --
      IF p_choice = 1 AND v_printer = 'noprint' THEN
        fnd_file.put_line(fnd_file.log, 'Printer hasn''t been selected');
        retcode := 1;
        RETURN;
      END IF;
    END IF;

    fnd_file.put_line(fnd_file.log, 'Printer: ' || v_printer);
    --------------------------------------------------------
    IF p_choice = 1 AND v_no_copies > 1 THEN
      v_copy_orig := 'Y';
      v_no_copies := v_no_copies - 1;
    ELSE
      v_copy_orig := 'N';
    END IF;

    /*--CHG0040768 Set the Printer and No of Copies depend on the Invoice Distribution Method
    If l_env = 'Y'
      AND p_invoice_dist_mode in (1,3,4)
      AND v_printer = 'noprint'
    Then   --1,3,4 Print Invoices
       fnd_file.put_line(fnd_file.log, 'Printer hasn''t been selected');
       retcode := 1;
       RETURN;
    End If; */
    -- CHG0040768  Remove Printer If Distribution Method is 02
    If p_invoice_dist_mode = 2 Then
      -- Only Email Invoices
      v_printer   := 'noprint';
      v_no_copies := 0;
    End If;

    fnd_file.put_line(fnd_file.log, 'p_choice:    ' || p_choice); --CHG0040768
    fnd_file.put_line(fnd_file.log,
                      'p_invoice_dist_mode:    ' || p_invoice_dist_mode); --CHG0040768
    fnd_file.put_line(fnd_file.log, 'v_copy_orig: ' || v_copy_orig); --CHG0040768
    fnd_file.put_line(fnd_file.log, 'v_no_copies: ' || v_no_copies); --CHG0040768
    fnd_file.put_line(fnd_file.log, 'v_printer: ' || v_printer); --CHG0040768
    --------------------------------------------------------
    FOR i IN 1 .. 1 LOOP
      /*2 LOOP*/ --CHG0040768
      /*IF i = 2 THEN
        l_send_mail := 'N';
      ELSE
        l_send_mail := p_send_mail;
      END IF;   --CHG0040768*/
      IF p_org_id = 96 THEN
        BEGIN
          --Sending the invoice to DE or AT
          SELECT COUNT(1)
            INTO v_count
            FROM hz_cust_acct_sites_all cas,
                 hz_cust_site_uses_all  csu,
                 hz_party_sites         psi,
                 ra_customer_trx_all    cta,
                 hz_locations           loc
           WHERE cas.cust_acct_site_id = csu.cust_acct_site_id
             AND psi.party_site_id = cas.party_site_id
             AND cta.bill_to_site_use_id = csu.site_use_id
             AND loc.location_id = psi.location_id
             AND csu.site_use_code = 'BILL_TO'
             AND cta.trx_number >= nvl(p_trx_from, cta.trx_number)
             AND cta.trx_number <= nvl(p_to_trx, cta.trx_number)
             AND loc.country IN ('AT', 'DE')
             AND cta.org_id = p_org_id;
        EXCEPTION
          WHEN OTHERS THEN
            v_count := NULL;
        END;
        fnd_file.put_line(fnd_file.log,
                          '1: Submitting Invoice for AT or DE');

        v_country := 'DE';
        IF v_count >= 1 THEN
          BEGIN
            --Create a Layout when running from the Tools Option
            l_result := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                               template_code      => 'XXAR_DE_TRX_REP',
                                               template_language  => 'en',
                                               template_territory => 'US', -- 'IL'
                                               output_format      => 'PDF');

            lb_flag := fnd_request.set_print_options(printer     => v_printer,
                                                     copies      => v_no_copies,
                                                     save_output => TRUE);

            --Calling new function add_delivery_options to set delivery option for XX: AR DE Invoice
            --CHG0040499(BR5)
            l_del_result := add_delivery_options(fnd_global.CONC_REQUEST_ID);

            l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                       program     => 'XXAR_DE_TRX_REP',
                                                       argument1   => p_org_id,
                                                       argument2   => p_choice,
                                                       argument3   => p_cust_trx_class,
                                                       argument4   => p_cust_trx_type_id,
                                                       argument5   => p_customer_name_low,
                                                       argument6   => p_customer_name_high,
                                                       argument7   => p_customer_no_low,
                                                       argument8   => p_customer_no_high,
                                                       argument9   => p_trx_from,
                                                       argument10  => p_to_trx,
                                                       argument11  => p_installment,
                                                       argument12  => p_from_date,
                                                       argument13  => p_to_date,
                                                       argument14  => p_open_invoices_only,
                                                       argument15  => v_country,
                                                       argument16  => v_copy_orig,
                                                       argument17  => p_batch_source_id,
                                                       -- daniel katz on 28-mar-10
                                                       argument18 => p_show_country_origin,
                                                       -- Dalit A. Raviv 08/05/2014
                                                       --argument19 => l_send_mail --CHG0040768
                                                       argument19 => p_invoice_dist_mode);

            COMMIT;
            -- Dalit A. Raviv 06/10/2011
            p_request_id     := l_request_id;
            p_conc_shor_name := 'XXAR_DE_TRX_REP';
            --
            fnd_file.put_line(fnd_file.log,
                              'submit_request: ' || l_request_id);
          EXCEPTION
            WHEN OTHERS THEN
              fnd_file.put_line(fnd_file.log,
                                '1: AT or DE Country Exception: ' ||
                                SQLERRM);
          END;
        END IF;

        BEGIN
          SELECT COUNT(1)
            INTO v_count
            FROM hz_cust_acct_sites_all cas,
                 hz_cust_site_uses_all  csu,
                 hz_party_sites         psi,
                 ra_customer_trx_all    cta,
                 hz_locations           loc
           WHERE cas.cust_acct_site_id = csu.cust_acct_site_id
             AND psi.party_site_id = cas.party_site_id
             AND cta.bill_to_site_use_id = csu.site_use_id
             AND loc.location_id = psi.location_id
             AND csu.site_use_code = 'BILL_TO'
             AND cta.trx_number >= nvl(p_trx_from, cta.trx_number)
             AND cta.trx_number <= nvl(p_to_trx, cta.trx_number)
             AND loc.country NOT IN ('AT', 'DE')
             AND cta.org_id = p_org_id;
        EXCEPTION
          WHEN OTHERS THEN
            v_count := NULL;
        END;

        IF v_count >= 1 THEN
          BEGIN
            -- Sending the invoice Not to DE or AT
            fnd_file.put_line(fnd_file.log,
                              '4: Submitting Invoice Not AT or DE');

            -- Create a Layout when running from the Tools Option
            l_result := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                               template_code      => 'XXAR_TRX_REP',
                                               template_language  => 'en',
                                               template_territory => 'US', -- 'IL'
                                               output_format      => 'PDF');

            lb_flag := fnd_request.set_print_options(printer     => v_printer,
                                                     copies      => v_no_copies,
                                                     save_output => TRUE);

            --Calling new function add_delivery_options to set delivery option for XX: AR DE Invoice
            --CHG0040499(BR5)
            l_del_result := add_delivery_options(fnd_global.CONC_REQUEST_ID);

            l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                       program     => 'XXAR_TRX_REP',
                                                       argument1   => p_org_id,
                                                       argument2   => p_choice,
                                                       argument3   => p_cust_trx_class,
                                                       argument4   => p_cust_trx_type_id,
                                                       argument5   => p_customer_name_low,
                                                       argument6   => p_customer_name_high,
                                                       argument7   => p_customer_no_low,
                                                       argument8   => p_customer_no_high,
                                                       argument9   => p_trx_from,
                                                       argument10  => p_to_trx,
                                                       argument11  => p_installment,
                                                       argument12  => p_from_date,
                                                       argument13  => p_to_date,
                                                       argument14  => p_open_invoices_only,
                                                       argument15  => 'X',
                                                       argument16  => v_copy_orig,
                                                       argument17  => p_batch_source_id,
                                                       -- daniel katz on 28-mar-10
                                                       argument18 => p_show_country_origin,
                                                       argument19 => p_print_zero_amt,
                                                       argument20 => p_printing_category,
                                                       -- Dalit A. Raviv 08/05/2014
                                                       --argument21 => l_send_mail    --CHG0040768
                                                       argument21 => p_invoice_dist_mode);

            COMMIT;
            -- Dalit A. Raviv 06/10/2011
            p_request_id     := l_request_id;
            p_conc_shor_name := 'XXAR_TRX_REP';
            --
            fnd_file.put_line(fnd_file.log,
                              'submit_request: ' || l_request_id);
          EXCEPTION
            WHEN OTHERS THEN
              fnd_file.put_line(fnd_file.log,
                                '2: Country Exception: ' || SQLERRM);
          END;
        END IF;
      ELSIF xxhz_util.get_operating_unit_name(p_org_id) = 'Stratasys US OU' THEN
        --
        -- This part is added by sanjai k misra
        -- StrataSys US had modified Invoice Print program, so if org is StrataSys then
        -- submit XXAR_SSUS_TRX_REP
        --
        -- spatel Lease Contract start  4/21/2017

        begin
          select batch_source_id
            INTO v_batch_source_id
            from RA_BATCH_SOURCES_ALL
           where name = 'OKL_CONTRACTS'
             and status = 'A'
             and org_id = p_org_id; --
        exception
          when others then
            v_batch_source_id := 0;
        end;

        -- IF v_source = 'OKL_CONTRACTS'  THEN

        IF p_batch_source_id = v_batch_source_id THEN
          BEGIN
            --Create a Layout when running from the Tools Option
            fnd_file.put_line(fnd_file.log, '1: Submitting Lease Invoices');

            l_result := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                               template_code      => 'XXAR_LEASE_TRX_REP',
                                               template_language  => 'en',
                                               template_territory => 'US', -- 'IL'
                                               output_format      => 'PDF');

            lb_flag := fnd_request.set_print_options(printer     => v_printer,
                                                     copies      => v_no_copies,
                                                     save_output => TRUE);

            --Calling new function add_delivery_options to set delivery option for XX: AR DE Invoice
            --CHG0040499(BR5)
            l_del_result := add_delivery_options(fnd_global.CONC_REQUEST_ID);

            l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                       program     => 'XXAR_SSUS_TRX_REP',
                                                       argument1   => p_org_id,
                                                       argument2   => p_choice,
                                                       argument3   => p_cust_trx_class,
                                                       argument4   => p_cust_trx_type_id,
                                                       argument5   => p_customer_name_low,
                                                       argument6   => p_customer_name_high,
                                                       argument7   => p_customer_no_low,
                                                       argument8   => p_customer_no_high,
                                                       argument9   => p_trx_from,
                                                       argument10  => p_to_trx,
                                                       argument11  => p_installment,
                                                       argument12  => p_from_date,
                                                       argument13  => p_to_date,
                                                       argument14  => p_open_invoices_only,
                                                       argument15  => 'X',
                                                       argument16  => v_copy_orig,
                                                       argument17  => p_batch_source_id,
                                                       -- daniel katz on 28-mar-10
                                                       argument18 => p_show_country_origin,
                                                       argument19 => p_print_zero_amt,
                                                       argument20 => p_printing_category,
                                                       -- Dalit A. Raviv 08/05/2014
                                                       --argument21 => l_send_mail --CHG0040768
                                                       argument21 => p_invoice_dist_mode);

            COMMIT;
            -- Dalit A. Raviv 06/10/2011
            p_request_id     := l_request_id;
            p_conc_shor_name := 'XXAR_SSUS_TRX_REP';
            --
            fnd_file.put_line(fnd_file.log,
                              'submit_request: ' || l_request_id);
          EXCEPTION
            WHEN OTHERS THEN
              fnd_file.put_line(fnd_file.log,
                                '1: Lease Invoice for Exception: ' ||
                                SQLERRM);
          END;

        end if;
        -- Lease Contract  end 2/24/2017
        --if v_source != 'OKL_CONTRACTS'  or v_source is NULL THEN
        IF p_batch_source_id != v_batch_source_id THEN

          lb_flag  := fnd_request.set_print_options(printer     => v_printer,
                                                    copies      => v_no_copies,
                                                    save_output => TRUE);
          l_result := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                             template_code      => 'XXAR_SSUS_TRX_REP',
                                             template_language  => 'en',
                                             template_territory => 'US',
                                             output_format      => 'PDF');

          --Calling new function add_delivery_options to set delivery option for XX: AR DE Invoice
          --CHG0040499(BR5)
          l_del_result := add_delivery_options(fnd_global.CONC_REQUEST_ID);

          l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                     program     => 'XXAR_SSUS_TRX_REP',
                                                     argument1   => p_org_id,
                                                     argument2   => p_choice,
                                                     argument3   => p_cust_trx_class,
                                                     argument4   => p_cust_trx_type_id,
                                                     argument5   => p_customer_name_low,
                                                     argument6   => p_customer_name_high,
                                                     argument7   => p_customer_no_low,
                                                     argument8   => p_customer_no_high,
                                                     argument9   => p_trx_from,
                                                     argument10  => p_to_trx,
                                                     argument11  => p_installment,
                                                     argument12  => p_from_date,
                                                     argument13  => p_to_date,
                                                     argument14  => p_open_invoices_only,
                                                     argument15  => 'X',
                                                     argument16  => v_copy_orig,
                                                     argument17  => p_batch_source_id,
                                                     -- daniel katz on 28-mar-10
                                                     argument18 => p_show_country_origin,
                                                     argument19 => p_print_zero_amt,
                                                     argument20 => p_printing_category,
                                                     -- Dalit A. Raviv 08/05/2014
                                                     --argument21 => l_send_mail--CHG0040768
                                                     argument21 => p_invoice_dist_mode);

          COMMIT;
          -- Dalit A. Raviv 06/10/2011
          p_request_id     := l_request_id;
          p_conc_shor_name := 'XXAR_SSUS_TRX_REP';
          --
          fnd_file.put_line(fnd_file.log,
                            'submit_request for StrataSys US: ' ||
                            l_request_id);
        end if; -- spatel

      ELSE
        --p_org_id <> 96
        BEGIN

          fnd_file.put_line(fnd_file.log, ' Submitting Invoice');
          -- CR724 support jpn template

          CASE xxhz_util.get_ou_lang(p_org_id)
            WHEN 'JA' THEN
              l_result := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                                 template_code      => 'XXAR_JPN_TRX_REP',
                                                 template_language  => 'en',
                                                 template_territory => 'US',
                                                 output_format      => 'PDF');
            ELSE

              l_result := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                                 template_code      => 'XXAR_TRX_REP',
                                                 template_language  => 'en',
                                                 template_territory => 'US',
                                                 output_format      => 'PDF');
          END CASE;

          lb_flag := fnd_request.set_print_options(printer     => v_printer,
                                                   copies      => v_no_copies,
                                                   save_output => TRUE);

          --Calling new function add_delivery_options to set delivery option for XX: AR DE Invoice
          --CHG0040499(BR5)
          l_del_result := add_delivery_options(fnd_global.CONC_REQUEST_ID);

          l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                     program     => 'XXAR_TRX_REP',
                                                     argument1   => p_org_id,
                                                     argument2   => p_choice,
                                                     argument3   => p_cust_trx_class,
                                                     argument4   => p_cust_trx_type_id,
                                                     argument5   => p_customer_name_low,
                                                     argument6   => p_customer_name_high,
                                                     argument7   => p_customer_no_low,
                                                     argument8   => p_customer_no_high,
                                                     argument9   => p_trx_from,
                                                     argument10  => p_to_trx,
                                                     argument11  => p_installment,
                                                     argument12  => p_from_date,
                                                     argument13  => p_to_date,
                                                     argument14  => p_open_invoices_only,
                                                     argument15  => 'X',
                                                     argument16  => v_copy_orig,
                                                     argument17  => p_batch_source_id,
                                                     -- daniel katz on 28-mar-10
                                                     argument18 => p_show_country_origin,
                                                     argument19 => p_print_zero_amt,
                                                     argument20 => p_printing_category,
                                                     -- Dalit A. Raviv 08/05/2014
                                                     --argument21 => l_send_mail--CHG0040768
                                                     argument21 => p_invoice_dist_mode);

          COMMIT;
          -- Dalit A. Raviv 06/10/2011
          p_request_id     := l_request_id;
          p_conc_shor_name := 'XXAR_TRX_REP';
          --
          fnd_file.put_line(fnd_file.log,
                            'submit_request: ' || l_request_id);
        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log,
                              '2: Country Exception: ' || SQLERRM);
        END;
      END IF; -- p_org_id
    /* IF v_copy_orig = 'Y' THEN
                v_copy_orig := 'N';
              ELSIF v_copy_orig = 'N' THEN
                EXIT;
              END IF;*/ --CHG0040768
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        '3: Procedure Exception: ' || SQLERRM);
      retcode := 2;
      errbuf  := SQLERRM;

  END print_invoice_new;

  --------------------------------------------------------------------
  --  name:            send_invoice_email
  --  create by:       Sandeep Patel
  --  Revision:        1.0
  --  creation date:   03/03/2017
  --------------------------------------------------------------------
  --  purpose :        Program that calls from Invoice Reports ( program units)
  --                   Concurrent XX: Print Invoice
  --                   Report     XXAR_INVOICE and XXAR_SSUS_TRX_REP
  --
  --                   This function get the email address to send the invoice to.
  --                   check environment - if production get the email from the customer
  --                                       else get oradev@objet.com
  --                   check profile if to send the mail with specific messages based on profiles
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/03/2017  Sandeep Patel    initial build
  --                                    CHG0037087 - Update and standardize email generation logic
  --  1.1  06/05/2018  Bellona(TCS)     CHG0041929 - Added new paramter p_template for the logic of introducing
  --                                      Dynamic template for AR Invoice Print bursting process
  --  1.2  22/10/2018  Bellona(TCS)     CHG0040499(BR6)
  --------------------------------------------------------------------
  procedure get_Invoice_email_info(p_org_id                   IN NUMBER,
                                   p_trx_number               IN VARCHAR2,
                                   p_customer_trx_id          IN NUMBER,
                                   p_bill_to_customer_name    in VARCHAR2,
                                   p_inv_type                 IN VARCHAR2,
                                   p_interface_header_context IN VARCHAR2,
                                   p_rep_id                   IN NUMBER,
                                   p_inv_dist_mode            IN NUMBER,
                                   --p_choice                   IN NUMBER,
                                   p_file_name  OUT VARCHAR2,
                                   p_from_email OUT VARCHAR2,
                                   p_to_email   OUT VARCHAR2,
                                   p_bcc_email  OUT VARCHAR2, --CHG0040499(BR6)
                                   p_to_body    OUT VARCHAR2,
                                   p_to_title   OUT VARCHAR2,
                                   p_template   OUT VARCHAR2 --CHG0041929
                                   ) IS
    l_to_body  VARCHAR2(500) := null;
    l_to_title VARCHAR2(500) := null;

    l_body            VARCHAR2(500) := null;
    l_temp_body       VARCHAR2(500) := null;
    l_so_order_number NUMBER := null;
    l_contract_number VARCHAR2(120) := null;
    l_cust_po_number  VARCHAR2(150) := null;
    l_create_by       VARCHAR2(360) := null;
    l_title           VARCHAR2(500) := null;

    l_env          VARCHAR2(20) := xxobjt_general_utils_pkg.am_i_in_production; -- return Y if Production;
    l_text         VARCHAR2(200) := null;
    l_db           VARCHAR2(50) := sys_context('userenv', 'db_name');
    l_customer     VARCHAR2(360) := null;
    l_greeting_msg VARCHAR2(360) := null;
    l_message_msg  VARCHAR2(360) := null;
    l_subjnpo_msg  VARCHAR2(360) := null;
    l_subj_po_msg  VARCHAR2(360) := null;
    l_trx_type     VARCHAR2(360) := null;
    l_msg_type     VARCHAR2(1);

    l_level_type  varchar2(360) := null;
    l_level_id    number;
    l_is_prod_env VARCHAR2(2) := xxobjt_general_utils_pkg.am_i_in_production;
  Begin

    fnd_file.put_line(fnd_file.log,
                      '*********Start :Input Parameters for get_Invoice_email_info ********');
    fnd_file.put_line(fnd_file.log, 'p_org_id     :' || p_org_id);
    fnd_file.put_line(fnd_file.log, 'p_trx_number :' || p_trx_number);
    fnd_file.put_line(fnd_file.log,
                      'p_customer_trx_id :' || p_customer_trx_id);
    fnd_file.put_line(fnd_file.log,
                      'p_bill_to_customer_name :' ||
                      p_bill_to_customer_name);
    fnd_file.put_line(fnd_file.log, 'p_inv_type :' || p_inv_type);
    fnd_file.put_line(fnd_file.log,
                      'p_interface_header_context :' ||
                      p_interface_header_context);
    fnd_file.put_line(fnd_file.log, 'p_rep_id   :' || p_rep_id);
    fnd_file.put_line(fnd_file.log, 'p_inv_dist_mode :' || p_inv_dist_mode);
    fnd_file.put_line(fnd_file.log,
                      '*********End :Input Parameters for get_Invoice_email_info ********');

    -- <Start CHG0041929 added logic to hold dynamic template value>
    IF xxhz_util.get_ou_lang(p_org_id) = 'JA' THEN
      p_template := 'xdo://XXOBJT.XXAR_JPN_TRX_REP.en.US?getSource=true';
    ELSE
      p_template := 'xdo://XXOBJT.XXAR_TRX_REP.en.US?getSource=true';
    END IF;
    -- <End CHG0041929 added logic to hold dynamic template value>

    If p_inv_type = 'INV' then
      l_trx_type := 'Invoice';
    Elsif p_inv_type = 'CM' then
      l_trx_type := 'Credit Memo';
    Elsif p_inv_type = 'DEP' then
      l_trx_type := 'Deposite';
    End If;

    p_file_name  := 'Invoice' || p_trx_number;
    p_from_email := xxobjt_general_utils_pkg.get_from_mail;
    /*
    1 - All customers printed, suppress email
    2 - Customers for Email distribution
    3 - All customers printed, auxiliary email
    4 - Customers for Printed distribution
    */
    If p_inv_dist_mode = 2 or p_inv_dist_mode = 3 Then
      p_to_email := xxar_print_invoice.get_send_to_email(p_customer_trx_id,
                                                         p_org_id);
      --Commented below as part of CHG0040499(BR6), since this section is been moved to get_send_bcc_email.
      /*    Else
      p_to_email := fnd_profile.value('XXAR_SEND_INVOICE_GENERAL_MAIL_BOX');
      If nvl(l_is_prod_env, 'N') = 'N' Then
        p_to_email := p_to_email || ',' ||
                      fnd_profile.value('XXOBJT_GEN_EMAIL_FOR_DEV_ENV');
      End If;*/
    End If;

    p_to_email  := REPLACE(p_to_email, ';', ',');
    p_bcc_email := xxar_print_invoice.get_send_bcc_email(p_customer_trx_id,
                                                         p_org_id);

    fnd_file.put_line(fnd_file.log, 'File Name  :' || p_file_name);
    fnd_file.put_line(fnd_file.log, 'From Email :' || p_from_email);
    fnd_file.put_line(fnd_file.log, 'To Email   :' || p_to_email);

    l_greeting_msg := nvl(xxobjt_general_utils_pkg.get_profile_value('XXAR_INVOICE_SEND_MAIL_GREETING',
                                                                     'Responsibility',
                                                                     p_rep_id),
                          xxobjt_general_utils_pkg.get_profile_value('XXAR_INVOICE_SEND_MAIL_GREETING',
                                                                     'SITE',
                                                                     null));

    l_message_msg := nvl(xxobjt_general_utils_pkg.get_profile_value('XXAR_INVOICE_SEND_MAIL_MESSAGE',
                                                                    'Responsibility',
                                                                    p_rep_id),
                         xxobjt_general_utils_pkg.get_profile_value('XXAR_INVOICE_SEND_MAIL_MESSAGE',
                                                                    'SITE',
                                                                    null));

    Begin
      SELECT 'Y' -- It means Profile at Resp level
        into l_msg_type
        FROM xxobjt_profiles_v p, fnd_responsibility fnd
       WHERE p.profile_option_name = 'XXAR_INVOICE_SEND_MAIL_GREETING'
         and fnd.responsibility_id = p.level_id
         and fnd.responsibility_id = p_rep_id;
    Exception
      when No_Data_Found then
        l_msg_type := 'N'; -- It means Profile at Site level
    End;

    If l_msg_type = 'Y' then

      fnd_message.set_name('XXOBJT', l_greeting_msg);
      fnd_message.set_token('CUST', p_bill_to_customer_name);
      l_temp_body := fnd_message.get;
      l_body      := l_temp_body || '<br>';

      fnd_message.set_name('XXOBJT', l_message_msg);
      fnd_message.set_token('TRX_TYPE', l_trx_type);
      l_temp_body := fnd_message.get;

      l_body := l_body || l_temp_body || '<br>';

      fnd_message.set_name('XXOBJT', 'XXAR_INVOICE_SEND_MAIL3.2');
      l_temp_body := fnd_message.get || '<br>';
      l_body      := l_body || l_temp_body;
    Else
      fnd_message.set_name('XXOBJT', l_greeting_msg);
      l_temp_body := fnd_message.get;
      l_body      := l_temp_body || '<br>';

      fnd_message.set_name('XXOBJT', l_message_msg);
      l_temp_body := fnd_message.get;
      l_body      := l_body || l_temp_body || '<br>';

      fnd_message.set_name('XXOBJT', 'XXAR_INVOICE_SEND_MAIL3.2');
      l_temp_body := fnd_message.get;
      l_body      := l_body || l_temp_body || '<br>';

    End if;

    p_to_body := l_body;

    fnd_file.put_line(fnd_file.log, 'Body  p_to_body :' || p_to_body);

    -- Get mail title
    Begin
      fnd_file.put_line(fnd_file.log,
                        ' Batch Source :' || p_interface_header_context);

      -- Logic based on Profile US
      If p_interface_header_context in ('ORDER ENTRY', 'INTERCOMPANY') Then
        select oh.order_number,
               oh.cust_po_number,
               pf.full_name,
               substr(hp.party_name, 1, 40) party_name
          into l_so_order_number, l_cust_po_number, l_create_by, l_customer
          from ra_customer_trx_all  rct,
               oe_order_headers_all oh,
               fnd_user             u,
               per_all_people_f     pf,
               hz_cust_accounts     hca,
               hz_parties           hp
         where rct.trx_number = p_trx_number
           and rct.org_id = p_org_id
           and rct.interface_header_attribute1 = oh.order_number
           and rct.org_id = oh.org_id
           and u.user_id = oh.created_by
           and pf.person_id = u.employee_id
           and trunc(sysdate) between pf.effective_start_date and
               pf.effective_end_date
           and rct.bill_to_customer_id = hca.cust_account_id
           and hca.party_id = hp.party_id;

        If l_cust_po_number is null then
          If l_msg_type = 'Y' then
            l_level_type := 'Responsibility';
            l_level_id   := p_rep_id;

            l_subjnpo_msg := xxobjt_general_utils_pkg.get_profile_value('XXAR_INVOICE_SEND_MAIL_SUBJNPO',
                                                                        l_level_type,
                                                                        l_level_id);
            fnd_message.set_name('XXOBJT', l_subjnpo_msg);
            fnd_message.set_token('CUST', l_customer);
            fnd_message.set_token('TRX_NUM', p_trx_number);
            fnd_message.set_token('TRX_TYPE', Initcap(l_trx_type));
          Else
            l_level_type  := 'SITE';
            l_level_id    := -1; -- set message at site level
            l_subjnpo_msg := xxobjt_general_utils_pkg.get_profile_value('XXAR_INVOICE_SEND_MAIL_SUBJNPO',
                                                                        l_level_type,
                                                                        l_level_id);

            fnd_message.set_name('XXOBJT', l_subjnpo_msg);
            fnd_message.set_token('CUST', l_customer);
            fnd_message.set_token('TRX_NUM', p_trx_number);

            fnd_message.set_token('SOURCE_NUM', l_so_order_number);
            fnd_message.set_token('CREATOR', l_create_by);
          End if;
        Else
          If l_msg_type = 'Y' then
            l_level_type  := 'Responsibility';
            l_level_id    := p_rep_id; -- Resp level Profile
            l_subj_po_msg := xxobjt_general_utils_pkg.get_profile_value('XXAR_INVOICE_SEND_MAIL_SUBJ_PO',
                                                                        l_level_type,
                                                                        l_level_id);

            fnd_message.set_name('XXOBJT', l_subj_po_msg); -- XXAR_INVOICE_SEND_MAIL_US5 -->  --
            fnd_message.set_token('CUST', l_customer);
            fnd_message.set_token('TRX_NUM', p_trx_number);
            fnd_message.set_token('TRX_TYPE', Initcap(l_trx_type));
            fnd_message.set_token('PO_NUM', l_cust_po_number);
          Else
            -- set message at site level
            l_level_type  := 'SITE';
            l_level_id    := -1; -- set message at site level
            l_subj_po_msg := xxobjt_general_utils_pkg.get_profile_value('XXAR_INVOICE_SEND_MAIL_SUBJ_PO',
                                                                        l_level_type,
                                                                        l_level_id);

            fnd_message.set_name('XXOBJT', l_subj_po_msg);
            fnd_message.set_token('CUST', l_customer);
            fnd_message.set_token('TRX_NUM', p_trx_number);

            fnd_message.set_token('SOURCE_NUM', l_so_order_number);
            fnd_message.set_token('PO_NUM', l_cust_po_number);
            fnd_message.set_token('CREATOR', l_create_by);
          End if;
        End if;

        l_title    := fnd_message.get;
        l_to_title := l_title;
      Elsif p_interface_header_context = 'OKS CONTRACTS' then
        Begin
          select oh.contract_number,
                 oh.cust_po_number,
                 pf.full_name,
                 substr(hp.party_name, 1, 40) party_name
            into l_contract_number,
                 l_cust_po_number,
                 l_create_by,
                 l_customer
            from ra_customer_trx_all rct,
                 okc_k_headers_all_b oh,
                 fnd_user            u,
                 per_all_people_f    pf,
                 hz_cust_accounts    hca,
                 hz_parties          hp
           where rct.trx_number = p_trx_number
             and rct.org_id = p_org_id
             and rct.interface_header_attribute1 = oh.contract_number
             and rct.org_id = oh.org_id
             and u.user_id = oh.created_by
             and pf.person_id = u.employee_id
             and trunc(sysdate) between pf.effective_start_date and
                 pf.effective_end_date
             and rct.interface_header_context = 'OKS CONTRACTS'
             and rct.bill_to_customer_id = hca.cust_account_id
             and hca.party_id = hp.party_id;

          fnd_message.set_name('XXOBJT', 'XXAR_INVOICE_SEND_MAIL7');
          fnd_message.set_token('CUST', l_customer);
          fnd_message.set_token('TRX_NUM', p_trx_number);
          fnd_message.set_token('CONT_NUM', nvl(l_contract_number, '.'));
          fnd_message.set_token('CUST_PO', nvl(l_cust_po_number, '.'));
         -- fnd_message.set_token('CREATOR', l_create_by);--CHG0045485

          l_title    := fnd_message.get;
          l_to_title := l_title;
        Exception
          when No_Data_Found then
            Begin
              select substr(hp.party_name, 1, 40) party_name
                into l_customer
                from ra_customer_trx_all rct,
                     hz_cust_accounts    hca,
                     hz_parties          hp
               where rct.bill_to_customer_id = hca.cust_account_id
                 and hca.party_id = hp.party_id
                 and rct.trx_number = p_trx_number
                 and rct.org_id = p_org_id;
            Exception
              when No_Data_Found then
                l_customer := '.';
            End;

            fnd_message.set_name('XXOBJT', 'XXAR_INVOICE_SEND_MAIL6');
            fnd_message.set_token('CUST', l_customer);
            fnd_message.set_token('TRX_NUM', p_trx_number);
            l_title    := fnd_message.get;
            l_to_title := l_title;
        End;
      else
        -- Invoice INVOICE_NUM has been created
        begin
          select substr(hp.party_name, 1, 40) party_name
            into l_customer
            from ra_customer_trx_all rct,
                 hz_cust_accounts    hca,
                 hz_parties          hp
           where rct.bill_to_customer_id = hca.cust_account_id
             and hca.party_id = hp.party_id
             and rct.trx_number = p_trx_number --'4000206'
             and rct.org_id = p_org_id;
        exception
          when no_data_found then
            l_customer := '.';
        end;

        fnd_message.set_name('XXOBJT', 'XXAR_INVOICE_SEND_MAIL6');
        fnd_message.set_token('CUST', l_customer);
        fnd_message.set_token('TRX_NUM', p_trx_number);
        l_title    := fnd_message.get;
        l_to_title := l_title;
      end if;

      if l_env = 'N' then
        l_to_title := l_to_title || ' (' || l_db || ')';
      else
        l_to_title := l_to_title;
      end if;

      p_to_title := l_to_title;
    Exception
      when others then
        begin
          select substr(hp.party_name, 1, 40) party_name
            into l_customer
            from ra_customer_trx_all rct,
                 hz_cust_accounts    hca,
                 hz_parties          hp
           where rct.bill_to_customer_id = hca.cust_account_id
             and hca.party_id = hp.party_id
             and rct.trx_number = p_trx_number
             and rct.org_id = p_org_id;
        exception
          when others then
            l_customer := '.';
        end;
        fnd_message.set_name('XXOBJT', 'XXAR_INVOICE_SEND_MAIL6');
        fnd_message.set_token('CUST', l_customer);
        fnd_message.set_token('TRX_NUM', p_trx_number);
        l_title := fnd_message.get;

        if l_env = 'N' then
          l_to_title := l_title || ' (' || l_db || ')';
        else
          l_to_title := l_title;
        end if;
        p_to_title := l_to_title;

        fnd_file.put_line(fnd_file.log, ' Title final ' || p_to_title);

    end;
  end get_Invoice_email_info;

  --------------------------------------------------------------------
  --  name:            get_send_to_mail
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/10/2010
  --------------------------------------------------------------------
  --  purpose :        Program that print AR invoices
  --                   Concurrent XX: Print Invoice
  --                   Report     XXAR_INVOICE
  --
  --                   This function get the email address to send the invoice to.
  --                   check environment - if production get the email from the customer
  --                                       else get oradev@objet.com
  --                   check profile if to send the mail to the user run the report Y/N
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/10/2010  Dalit A. Raviv    initial build
  --  1.1  04/05/2014  Dalit A. Raviv    change logic, send user allways, and to a general mailbox
  --  1.2  25/07/2017  Lingaraj Sarangi  INC0098186 -  Increase Email Variable length
  --  1.3  10/10/2018  Bellona(TCS)      CHG0040499(BR6)
  --------------------------------------------------------------------
  FUNCTION get_send_to_email(p_customer_trx_id IN NUMBER,
                             p_org_id          IN NUMBER) RETURN VARCHAR2 IS
    l_email_address VARCHAR2(500);
    l_user_mail     VARCHAR2(500);
    l_profile       VARCHAR2(100) := fnd_profile.value('XXAR_INVOICE_SEND_MAIL_USER');
    l_env           VARCHAR2(20) := NULL;
    l_gen_email     VARCHAR2(100) := NULL;
    l_cust_type     hz_cust_accounts.customer_type%TYPE; -- CHG0040499(BR6) -- will hold customer type
    l_send_org_inv  VARCHAR2(10); --Will hold Profile value of "XXAR_SEND_ORIGINAL_INV_BY_MAIL"
  BEGIN
    l_send_org_inv := nvl(xxobjt_general_utils_pkg.get_profile_value('XXAR_SEND_ORIGINAL_INV_BY_MAIL',
                                                                     'ORG',
                                                                     P_ORG_ID),
                          'N');
    --l_env := xxagile_util_pkg.get_bpel_domain;
    l_env := xxobjt_general_utils_pkg.am_i_in_production; -- return Y if Production
    --IF l_env = 'production' THEN
    --  IF l_env = 'Y' THEN -- APR-2017 spatel , as per Erik M
    --Added on 25th Jul 2017 for INC0098186
    l_email_address := get_customer_contact_email(p_customer_trx_id);
    /* -- Commented on 25th Jul 2017 for INC0098186
       -- After Comenting the Below SQL used 'get_customer_contact_email' function to fetch the Email.
    BEGIN
      SELECT hov.email_address
        INTO l_email_address
        FROM ra_customer_trx_all   rta,
             hz_cust_accounts      htc,
             hz_relationships      rl,
             hz_org_contacts_v     hov,
             hz_cust_account_roles hcar
       WHERE rta.customer_trx_id = p_customer_trx_id
         AND htc.cust_account_id = rta.bill_to_customer_id
         AND rl.subject_id = htc.party_id
         AND hov.party_relationship_id = rl.relationship_id
         AND hov.job_title = 'Invoice Mail'
         AND hov.job_title_code = 'XX_ACCOUNTS_PAYABLE'
         AND nvl(hov.status, 'A') = 'A'
         AND hov.contact_point_type = 'EMAIL'
         AND hov.contact_primary_flag = 'Y'
         AND hcar.party_id = rl.party_id
         AND nvl(hcar.current_role_state, 'A') = 'A'
         AND hcar.cust_account_id = htc.cust_account_id
         AND rownum = 1;
    EXCEPTION
      WHEN OTHERS THEN
        l_email_address := NULL;
    END;*/
    --  ELSE
    fnd_file.put_line(fnd_file.log, 'Customer Email :' || l_email_address);
    --<Added as part of CHG0040499(BR6) Start>
    fnd_file.put_line(fnd_file.log,
                      'Profile value for profile(XXAR_SEND_ORIGINAL_INV_BY_MAIL) : ' ||
                      l_send_org_inv);

    BEGIN
      select htc.customer_type
        into l_cust_type
        FROM ra_customer_trx_all rta, hz_cust_accounts htc
       WHERE rta.customer_trx_id = p_customer_trx_id
         AND htc.cust_account_id = rta.bill_to_customer_id
         AND rownum = 1;

      --If customer type is intercompany then fetch email address of customer contact
      IF l_cust_type = 'I' THEN
        l_email_address := get_customer_contact_email(p_customer_trx_id);
      ELSE
        --If customer type is not intercompany
        --and customer is not eligible for getting original invoice by mail
        IF l_send_org_inv = 'N' Then
          l_email_address := NULL;
        ELSE
          l_email_address := get_customer_contact_email(p_customer_trx_id);
        END IF;
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        l_email_address := NULL;
    END;
    --<Added as part of CHG0040499(BR6) End>

    IF l_env = 'N' and l_email_address is not null THEN
      -- APR-2017 spatel , as per Erik M
      l_email_address := fnd_profile.value('XXOBJT_GEN_EMAIL_FOR_DEV_ENV'); --'oradev@objet.com'
    END IF;

    /*  Commented below part as part of CHG0040499(BR6) for changing logic of sending mail.
    --l_email_address := replace(l_email_address,';',', ');

    -- Dalit A. Raviv 04/05/2014
    -- allways send the mail to the user
    IF \*l_email_address IS NOT NULL AND*\
     nvl(l_profile, 'N') = 'Y' THEN
      IF fnd_global.user_name \*fnd_profile.value('USER_NAME')*\
         <> 'SCHEDULER' THEN
        SELECT papf.email_address
          INTO l_user_mail
          FROM per_all_people_f papf, fnd_user fu
         WHERE papf.person_id = fu.employee_id
           AND trunc(SYSDATE) BETWEEN papf.effective_start_date AND
               papf.effective_end_date
           AND fu.user_id = fnd_profile.value('USER_ID');

        IF l_email_address IS NOT NULL AND l_user_mail IS NOT NULL THEN
          l_email_address := l_email_address || ', ' || l_user_mail;
        ELSE
          l_email_address := l_user_mail;
        END IF;
      END IF;

    END IF;
    -- allways send mail to general mail box
    l_gen_email := fnd_profile.value('XXAR_SEND_INVOICE_GENERAL_MAIL_BOX');
    IF l_email_address IS NOT NULL AND l_gen_email IS NOT NULL THEN
      l_email_address := l_email_address || ', ' || l_gen_email;
    ELSIF l_email_address IS NOT NULL AND l_gen_email IS NULL THEN
      l_email_address := l_email_address;
    ELSE
      l_email_address := l_gen_email;
    END IF;*/

    l_email_address := REPLACE(l_email_address, ';', ',');
    --l_email_address := 'dalit.raviv@stratasys.com;yuval.tal@stratasys.com, oradev@stratasys.com';
    --l_email_address := 'Dalit.Raviv@gamil.com, dalit.raviv@stratasys.com';
    --l_email_address := 'xxxxxxxx@stratasys.com';
    fnd_file.put_line(fnd_file.log,
                      'get_send_to_email Function Returned :' ||
                      l_email_address);
    RETURN l_email_address;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_send_to_email;

  --------------------------------------------------------------------
  --  name:            get_send_bcc_mail
  --  create by:       Bellona(TCS)
  --  Revision:        1.0
  --  creation date:   12/10/2016
  --------------------------------------------------------------------
  --  purpose :        Concurrent XX: Print Invoice
  --                   Report     XXAR_INVOICE
  --
  --                   This function get the email address bcc send the invoice to.
  --                   check environment - if production get the email from the user
  --                                       or general mail box, else get oradev@objet.com
  --                   check profile if to send the mail to the user run the report Y/N
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2018  Bellona(TCS)      CHG0040499(BR6)
  --  1.1  22/01/2019  Roman W.          INC0144462 replace ";" with ","
  --------------------------------------------------------------------
  FUNCTION get_send_bcc_email(p_customer_trx_id IN NUMBER,
                              p_org_id          IN NUMBER) RETURN VARCHAR2 IS
    l_email_address VARCHAR2(500);
    l_user_mail     VARCHAR2(500);
    l_profile       VARCHAR2(100) := fnd_profile.value('XXAR_INVOICE_SEND_MAIL_USER');
    l_env           VARCHAR2(20) := NULL;
    l_gen_email     VARCHAR2(100) := NULL;

    l_cust_type    hz_cust_accounts.customer_type%TYPE; -- CHG0040499(BR6) -- will hold customer type
    l_send_org_inv VARCHAR2(10); --Will hold Profile value of "XXAR_SEND_ORIGINAL_INV_BY_MAIL"
  BEGIN

    -- Send the mail to the user
    IF --l_email_address IS NOT NULL AND
     nvl(l_profile, 'N') = 'Y' THEN
      IF fnd_global.user_name --\*fnd_profile.value('USER_NAME')*\
         <> 'SCHEDULER' THEN
        SELECT papf.email_address
          INTO l_user_mail
          FROM per_all_people_f papf, fnd_user fu
         WHERE papf.person_id = fu.employee_id
           AND trunc(SYSDATE) BETWEEN papf.effective_start_date AND
               papf.effective_end_date
           AND fu.user_id = fnd_profile.value('USER_ID');

        IF l_email_address IS NOT NULL AND l_user_mail IS NOT NULL THEN
          l_email_address := l_email_address || ', ' || l_user_mail;
        ELSE
          l_email_address := l_user_mail;
        END IF;
      END IF;

    END IF;

    --send mail to general mail box
    l_gen_email := fnd_profile.value('XXAR_SEND_INVOICE_GENERAL_MAIL_BOX');
    IF l_email_address IS NOT NULL AND l_gen_email IS NOT NULL THEN
      l_email_address := l_email_address || ', ' || l_gen_email;
    ELSIF l_email_address IS NOT NULL AND l_gen_email IS NULL THEN
      l_email_address := l_email_address;
    ELSE
      l_email_address := l_gen_email;
    END IF;

    --l_env := xxagile_util_pkg.get_bpel_domain;
    l_env := xxobjt_general_utils_pkg.am_i_in_production; -- return Y if Production
    IF l_env = 'N' and l_email_address is not null THEN
      -- APR-2017 spatel , as per Erik M
      l_email_address := fnd_profile.value('XXOBJT_GEN_EMAIL_FOR_DEV_ENV'); --'oradev@objet.com'
    END IF;

    l_email_address := REPLACE(l_email_address, ';', ','); -- INC0144462

    fnd_file.put_line(fnd_file.log,
                      'get_send_bcc_email Function Returned :' ||
                      l_email_address);

    RETURN l_email_address;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_send_bcc_email;

  --------------------------------------------------------------------
  --  name:            send_mail
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/10/2010
  --------------------------------------------------------------------
  --  purpose :        Program that print AR invoices
  --                   Concurrent XX: Print Invoice
  --                   Report     XXAR_INVOICE
  --
  --                   This procedure call concurrent program that send mail
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE send_mail(p_request_id      IN NUMBER,
                      p_conc_short_name IN VARCHAR2,
                      p_trx_num         IN VARCHAR2,
                      p_customer_trx_id IN NUMBER,
                      p_legal_entity_id IN NUMBER,
                      p_org_id          IN NUMBER,
                      p_err_code        OUT NUMBER,
                      p_err_desc        OUT VARCHAR2) IS

    l_req_id        NUMBER;
    l_email_address VARCHAR2(2000);
    l_email_body    VARCHAR2(150);
    l_email_body1   VARCHAR2(150) := chr(13);
    l_email_body2   VARCHAR2(150) := chr(13);
    l_phone_num     VARCHAR2(250) := NULL;
    l_ou_mail       VARCHAR2(250) := NULL;
    l_ou_name       VARCHAR2(250) := NULL;

  BEGIN
    -- get email address
    l_email_address := get_send_to_email(p_customer_trx_id, p_org_id);
    IF l_email_address IS NOT NULL THEN
      -- get email body from messages
      l_phone_num := xxar_utils_pkg.get_company_phone(p_legal_entity_id,
                                                      p_org_id);
      l_ou_mail   := xxar_utils_pkg.get_company_email(p_legal_entity_id,
                                                      p_org_id);
      l_ou_name   := xxar_utils_pkg.get_company_name(p_legal_entity_id,
                                                     p_org_id);
      -- Hello,
      --fnd_message.set_name('XXOBJT','XXAR_INVOICE_SEND_MAIL3');
      --l_email_body := fnd_message.get||chr(13)||chr(13);
      -- Attached please find the invoice for your recent order with Objet.
      fnd_message.set_name('XXOBJT', 'XXAR_INVOICE_SEND_MAIL1');
      fnd_message.set_token('DOWN1', chr(13));
      fnd_message.set_token('DOWN2', chr(13));
      l_email_body := l_email_body || fnd_message.get || chr(13) || chr(13);
      -- If you have any questions, please feel free to call us at
      fnd_message.set_name('XXOBJT', 'XXAR_INVOICE_SEND_MAIL2');
      fnd_message.set_token('PHONE', l_phone_num);
      fnd_message.set_token('EMAIL', l_ou_mail);
      l_email_body1 := fnd_message.get;
      l_email_body1 := l_email_body1 || chr(13) || chr(13);
      -- Thank You,
      fnd_message.set_name('XXOBJT', 'XXAR_INVOICE_SEND_MAIL4');
      l_email_body2 := fnd_message.get;
      l_email_body2 := l_email_body2 || chr(13) || chr(13) || l_ou_name;

      --l_email_address := 'dalit.raviv@objet.com';

      l_email_body  := REPLACE(l_email_body, ' ', '_');
      l_email_body1 := REPLACE(l_email_body1, ' ', '_');
      l_email_body2 := REPLACE(l_email_body2, ' ', '_');
      -- send request to send by mail
      l_req_id := fnd_request.submit_request(application => 'XXOBJT',
                                             program     => 'XXSENDREQTOMAIL', -- Short name of the send mail
                                             argument1   => 'Objet_Invoice_' ||
                                                            p_trx_num, -- Subject
                                             argument2   => l_email_body, -- Body
                                             argument3   => l_email_body1, -- Body1
                                             argument4   => l_email_body2, -- Body2
                                             argument5   => p_conc_short_name, -- Concurrent Short Name that the output need to send
                                             argument6   => p_request_id, -- Request Id (of the report output to send)
                                             argument7   => l_email_address, -- Mail Recipient
                                             argument8   => 'ObjetInvoice', -- Report Name (each run can get different name)
                                             argument9   => p_trx_num, -- Report subject number (Sr Number, SO Number...)
                                             argument10  => 'PDF', -- Concurrent Output Extention - PDF, EXCEL ...
                                             argument11  => 'pdf', -- File Extention to Send - pdf, exl
                                             argument12  => 'N'); -- Delete Concurrent Output - Y/N
      COMMIT;
      --dbms_lock.sleep(seconds => 20);
      IF l_req_id = 0 THEN

        fnd_file.put_line(fnd_file.log,
                          'Failed to Send Report by mail ' || p_trx_num ||
                          ' -----');
        fnd_file.put_line(fnd_file.log, 'Err - ' || SQLERRM);
        p_err_code := 2;
        p_err_desc := 'Failed to Send report';
      ELSE
        fnd_file.put_line(fnd_file.log,
                          'Success to Send Report by mail ' || p_trx_num ||
                          ' -----');
      END IF; -- l_request_id
    END IF; -- l_email_address
  END send_mail;

  --------------------------------------------------------------------
  --  name:            Print_Invoice_send_mail
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/10/2011
  --------------------------------------------------------------------
  --  purpose :        Program that print AR invoices
  --                   Concurrent XX: Print Invoice
  --                   Report     XXAR_INVOICE
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/10/2010  Dalit A. Raviv    Procedure that print each invoice at separate
  --                                     conccurent and send it to the customer by mail.
  --  1.1  19/01/2012  Dalit A. Raviv    1) add condition to the parameter if.
  --                                     2) change checking of complete
  --------------------------------------------------------------------
  PROCEDURE print_invoice_send_mail(errbuf                OUT VARCHAR2,
                                    retcode               OUT NUMBER,
                                    p_org_id              IN NUMBER,
                                    p_choice              IN NUMBER,
                                    p_batch_source_id     IN NUMBER,
                                    p_cust_trx_class      IN VARCHAR2,
                                    p_cust_trx_type_id    IN ra_cust_trx_types.cust_trx_type_id%TYPE,
                                    p_customer_name_low   IN hz_parties.party_name%TYPE,
                                    p_customer_name_high  IN hz_parties.party_name%TYPE,
                                    p_customer_no_low     IN hz_cust_accounts.account_number%TYPE,
                                    p_customer_no_high    IN hz_cust_accounts.account_number%TYPE,
                                    p_installment         IN NUMBER,
                                    p_trx_from            IN ra_interface_lines.trx_number%TYPE,
                                    p_to_trx              IN ra_interface_lines.trx_number%TYPE,
                                    p_from_date           IN VARCHAR2,
                                    p_to_date             IN VARCHAR2,
                                    p_open_invoices_only  IN VARCHAR2,
                                    p_show_country_origin IN VARCHAR2,
                                    --  17/06/2012 added by Ofer Suad
                                    p_print_zero_amt    IN VARCHAR2,
                                    p_printing_category IN VARCHAR2,
                                    -- Dalit A. Raviv 08/05/2014
                                    p_send_mail IN VARCHAR2) IS

    l_request_id NUMBER := fnd_global.conc_request_id;
    -------------
    TYPE incurtyp IS REF CURSOR; -- define weak REF CURSOR type
    inv_cv       incurtyp; -- declare
    l_trx_number VARCHAR2(20);
    l_query      VARCHAR2(1500);
    l_select_sql VARCHAR2(100) := 'select trx.trx_number , trx.org_id, trx.customer_trx_id, trx.legal_entity_id';
    l_from_sql   VARCHAR2(1000) := ' from ra_customer_trx_all  trx';
    l_where_sql  VARCHAR2(2500);

    l_org_id          NUMBER;
    l_customer_trx_id NUMBER;
    l_legal_entity_id NUMBER;
    l_return          BOOLEAN;
    l_error_flag      BOOLEAN := FALSE;
    l_phase           VARCHAR2(100);
    l_status          VARCHAR2(100);
    l_dev_phase       VARCHAR2(100);
    l_dev_status      VARCHAR2(100);
    l_message         VARCHAR2(1000);
    l_return_bool     BOOLEAN;
    l_conc_short_name VARCHAR2(250) := NULL;
    l_err_desc        VARCHAR2(2500);
    l_err_code        NUMBER;
    l_mark            NUMBER := 0;

    gen_exception EXCEPTION;

  BEGIN

    -- Step 1 Handle invoices population by dynamic sql (handle parameters sent)
    IF p_customer_name_low IS NULL AND p_customer_name_high IS NULL AND
       p_customer_no_low IS NULL AND p_customer_no_high IS NULL AND
       p_trx_from IS NULL AND p_to_trx IS NULL AND p_from_date IS NULL AND
       p_to_date IS NULL AND p_choice <> 1 THEN
      -- Dalit A. RAviv 19/01/2012

      fnd_file.put_line(fnd_file.log,
                        '!!!! Need to choose at list one of the major parameters:' ||
                        'p_customer_name_low / hight, p_customer_no_low / hight ' ||
                        'p_trx_from or p_to_trx, p_from_date or p_to_date ');
      errbuf  := '!!!! Need to choose at list one of the major parameters';
      retcode := 2;
      RAISE gen_exception;
    END IF;

    l_where_sql := ' where trx.org_id = ' || p_org_id ||
                   ' and trx.batch_source_id = ' || p_batch_source_id;
    IF p_cust_trx_type_id IS NOT NULL THEN
      l_where_sql := l_where_sql || ' and trx.cust_trx_type_id = ' ||
                     p_cust_trx_type_id;
    END IF;
    l_mark := 1;
    IF p_cust_trx_class IS NOT NULL THEN
      l_from_sql  := l_from_sql || ',ra_cust_trx_types_all types ';
      l_where_sql := l_where_sql ||
                     ' and trx.cust_trx_type_id = types.cust_trx_type_id and types.type = ' || '''' ||
                     p_cust_trx_class || '''';
    END IF;
    l_mark := 2;
    IF p_customer_name_low IS NOT NULL THEN
      l_from_sql  := l_from_sql ||
                     ',hz_parties b_bill_party,hz_cust_accounts_all  b_bill ';
      l_where_sql := l_where_sql ||
                     ' and trx.bill_to_customer_id = b_bill.cust_account_id ' ||
                     ' and b_bill.party_id = b_bill_party.party_id ' ||
                     ' and b_bill_party.party_name >= ' || '''' ||
                     p_customer_name_low || '''';
    END IF;
    l_mark := 3;
    IF p_customer_name_high IS NOT NULL THEN
      IF p_customer_name_low IS NULL THEN
        l_from_sql  := l_from_sql ||
                       ',hz_parties b_bill_party,hz_cust_accounts_all  b_bill';
        l_where_sql := l_where_sql ||
                       ' and trx.bill_to_customer_id = b_bill.cust_account_id ' ||
                       ' and b_bill.party_id = b_bill_party.party_id ';
      END IF;
      l_where_sql := l_where_sql || ' and b_bill_party.party_name <= ' || '''' ||
                     p_customer_name_high || '''';
    END IF;
    l_mark := 4;
    IF p_customer_no_low IS NOT NULL THEN
      IF p_customer_name_low IS NULL AND p_customer_name_high IS NULL THEN
        l_from_sql  := l_from_sql ||
                       ',hz_parties b_bill_party,hz_cust_accounts_all  b_bill';
        l_where_sql := l_where_sql ||
                       ' and trx.bill_to_customer_id = b_bill.cust_account_id ' ||
                       ' and b_bill.party_id = b_bill_party.party_id ';
      END IF;
      l_where_sql := l_where_sql || ' and b_bill.account_number >= ' || '''' ||
                     p_customer_no_low || '''';
    END IF;
    l_mark := 5;
    IF p_customer_no_high IS NOT NULL THEN
      IF p_customer_name_low IS NULL AND p_customer_name_high IS NULL AND
         p_customer_no_low IS NULL THEN
        l_from_sql  := l_from_sql ||
                       ',hz_parties b_bill_party,hz_cust_accounts_all  b_bill';
        l_where_sql := l_where_sql ||
                       ' and trx.bill_to_customer_id = b_bill.cust_account_id ' ||
                       ' and b_bill.party_id=b_bill_party.party_id ';
      END IF;
      l_where_sql := l_where_sql || ' and b_bill.account_number <= ' || '''' ||
                     p_customer_no_high || '''';
    END IF;
    l_mark := 6;
    IF p_trx_from IS NOT NULL THEN
      l_where_sql := l_where_sql || ' and   trx.trx_number >= ' || '''' ||
                     p_trx_from || '''';
    END IF;
    l_mark := 7;
    IF p_to_trx IS NOT NULL THEN
      l_where_sql := l_where_sql || ' and   trx.trx_number <= ' || '''' ||
                     p_to_trx || '''';
    END IF;
    l_mark := 8;
    IF p_from_date IS NOT NULL THEN
      l_where_sql := l_where_sql || ' and trx.trx_date >= ''' ||
                     to_date(p_from_date, 'YYYY/MM/DD HH24:MI:SS') || '''';
    END IF;
    l_mark := 9;
    IF p_to_date IS NOT NULL THEN
      --l_where_sql := l_where_sql || ' and trx.trx_date <= ' || '''' || p_to_date || '''';
      l_where_sql := l_where_sql || ' and trx.trx_date <= ''' ||
                     to_date(p_to_date, 'YYYY/MM/DD HH24:MI:SS') || '''';
    END IF;
    l_mark := 10;
    IF p_choice = 1 OR p_choice = 3 THEN
      l_where_sql := l_where_sql || ' and trx.printing_pending = ''Y''';
    ELSE
      l_where_sql := l_where_sql || ' and trx.printing_pending = ''N''';
    END IF;
    --  17/06/2012 added by Ofer Suad
    IF p_print_zero_amt = 'N' THEN
      l_where_sql := l_where_sql ||
                     ' and exists (select 1 from ra_customer_trx_lines_all rctl where rctl.customer_trx_id=trx.customer_trx_id ' ||
                     'having  sum(rctl.unit_selling_price*nvl(rctl.quantity_invoiced,rctl.quantity_credited))!=0)';
    END IF;
    IF p_printing_category IS NOT NULL THEN
      l_from_sql  := l_from_sql || ',hz_cust_accounts_all  b_cat';
      l_where_sql := l_where_sql ||
                     ' and trx.bill_to_customer_id = b_cat.cust_account_id ' ||
                     'and b_cat.attribute7=' || '''' || p_printing_category || '''';
    END IF;
    l_mark := 11;
    -- Step 2 - create the query
    l_query := l_select_sql || l_from_sql || l_where_sql;
    fnd_file.put_line(fnd_file.log, l_query);
    l_mark := 12;

    -- Step 3 - by loop go over all invoices and print each one and send to customer.
    OPEN inv_cv FOR l_query;
    LOOP
      l_trx_number      := NULL;
      l_org_id          := NULL;
      l_customer_trx_id := NULL;
      l_legal_entity_id := NULL;
      l_err_desc        := NULL;
      l_err_code        := NULL;
      l_conc_short_name := NULL;
      FETCH inv_cv
        INTO l_trx_number, l_org_id, l_customer_trx_id, l_legal_entity_id; -- fetch next row
      IF l_org_id IS NOT NULL AND l_trx_number IS NOT NULL AND
         get_send_to_email(l_customer_trx_id, l_org_id) IS NOT NULL THEN
        -- create the report
        print_invoice_new(errbuf                => l_err_desc, -- o v
                          retcode               => l_err_code, -- o n
                          p_request_id          => l_request_id, -- o n  Dalit A. Raviv 06/10/2011
                          p_conc_shor_name      => l_conc_short_name, -- o v  Dalit A. Raviv 06/10/2011
                          p_org_id              => l_org_id, -- i n
                          p_choice              => p_choice, -- i n
                          p_batch_source_id     => p_batch_source_id, -- i n
                          p_cust_trx_class      => p_cust_trx_class, -- i v
                          p_cust_trx_type_id    => p_cust_trx_type_id, -- i n
                          p_customer_name_low   => NULL, -- i v
                          p_customer_name_high  => NULL, -- i v
                          p_customer_no_low     => NULL, -- i v
                          p_customer_no_high    => NULL, -- i v
                          p_installment         => p_installment, -- i n
                          p_trx_from            => l_trx_number, -- i v
                          p_to_trx              => l_trx_number, -- i v
                          p_from_date           => NULL, -- i v
                          p_to_date             => NULL, -- i v
                          p_open_invoices_only  => p_open_invoices_only, -- i v
                          p_show_country_origin => p_show_country_origin,
                          p_print_zero_amt      => p_print_zero_amt,
                          p_printing_category   => p_printing_category, -- i v
                          p_invoice_dist_mode   => 1 --ADDED on 06.06.2017 for CHG0040768, in place of p_send_mail
                          -- Dalit A. Raviv 08/05/2014
                          --p_send_mail => p_send_mail  --Commented on 06.06.2017 for CHG0040768
                          );

        -- check the report failed or success
        IF l_request_id = 0 THEN
          fnd_file.put_line(fnd_file.log,
                            'Failed to print report for invoice - ' ||
                            l_trx_number || ' -----');
          fnd_file.put_line(fnd_file.log, 'Err - ' || l_err_desc);
          errbuf  := 'Failed to print report for invoice - ' ||
                     l_trx_number;
          retcode := 2;
        ELSE
          fnd_file.put_line(fnd_file.log,
                            'Success to print report for invoice ' ||
                            l_trx_number || ' -----');
          -- must commit the request
          COMMIT;

          -- loop to wait until the request finished
          WHILE l_error_flag = FALSE LOOP
            l_return_bool := fnd_concurrent.wait_for_request(l_request_id,
                                                             5,
                                                             86400,
                                                             l_phase,
                                                             l_status,
                                                             l_dev_phase,
                                                             l_dev_status,
                                                             l_message);
            -- 1.1 19/01/2012 Dalit A. RAviv
            IF l_dev_phase = 'COMPLETE' THEN
              l_error_flag := TRUE;
            END IF;

            IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
              l_error_flag := TRUE;
            ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
              l_error_flag := TRUE;
              errbuf       := 'Request finished in error or warrning, no email send';
              retcode      := 1;
              fnd_file.put_line(fnd_file.log,
                                'Request finished in error or warrning, no email send. try again later. - ' ||
                                l_message);
            END IF; -- dev_phase
          -- 1.1 end
          END LOOP; -- l_error_flag
          fnd_file.put_line(fnd_file.log, 'Dev Status: ' || l_dev_status);
          IF l_error_flag = TRUE AND
             (l_dev_status IN ('NORMAL', 'WARNING')) THEN
            l_err_code := 0;
            l_err_desc := NULL;
            send_mail(p_request_id      => l_request_id, -- i n
                      p_conc_short_name => l_conc_short_name, -- i v
                      p_trx_num         => l_trx_number, -- i v
                      p_customer_trx_id => l_customer_trx_id, -- i n
                      p_legal_entity_id => l_legal_entity_id, -- i n
                      p_org_id          => l_org_id, -- i n
                      p_err_code        => l_err_code, -- o n
                      p_err_desc        => l_err_desc); -- o v
          END IF; -- l_error_flag
        END IF; -- l_request_id concurrent run
      END IF; -- l_org_id is null
      EXIT WHEN inv_cv%NOTFOUND; -- exit loop when last row is fetched
      --dbms_output.put_line(l_trx_number||' Org ' ||l_org_id);
    END LOOP;
    CLOSE inv_cv;

  EXCEPTION
    WHEN gen_exception THEN
      l_return := fnd_concurrent.set_completion_status('ERROR', errbuf);
      IF NOT l_return THEN
        fnd_file.put_line(fnd_file.log, 'Dalit ');
      END IF;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        '3: Procedure Exception: ' || SQLERRM);
      fnd_file.put_line(fnd_file.log, 'l_mark - ' || l_mark);
      retcode := 2;
      errbuf  := SQLERRM;
  END print_invoice_send_mail;

  --------------------------------------------------------------------
  --  name:            Print_Invoice
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/10/2011
  --------------------------------------------------------------------
  --  purpose :        Program that print AR invoices
  --                   Concurrent XX: Print Invoice
  --                   Report     XXAR_INVOICE
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/10/2010  Dalit A. Raviv    add the ability to send invoice output by mail
  --                                     if customer sent parameter p_send_mail the program will
  --                                     send each invoice to a different customer by mail.
  --                                     this program handle
  --  1.1  12/05/2014  Dalit A. Raviv    Invoice Print will use bursting technology.
  --                                     therefor no need to use send mail any more.
  --------------------------------------------------------------------
  PROCEDURE print_invoice(errbuf               OUT VARCHAR2,
                          retcode              OUT NUMBER,
                          p_org_id             IN NUMBER,
                          p_choice             IN NUMBER,
                          p_batch_source_id    IN NUMBER,
                          p_cust_trx_class     IN VARCHAR2,
                          p_cust_trx_type_id   IN ra_cust_trx_types.cust_trx_type_id%TYPE,
                          p_customer_name_low  IN hz_parties.party_name%TYPE,
                          p_customer_name_high IN hz_parties.party_name%TYPE,
                          p_customer_no_low    IN hz_cust_accounts.account_number%TYPE,
                          p_customer_no_high   IN hz_cust_accounts.account_number%TYPE,
                          p_installment        IN NUMBER,
                          p_trx_from           IN ra_interface_lines.trx_number%TYPE,
                          p_to_trx             IN ra_interface_lines.trx_number%TYPE,
                          p_from_date          IN VARCHAR2,
                          p_to_date            IN VARCHAR2,
                          p_open_invoices_only IN VARCHAR2,
                          --added by daniel katz on 28-mar-10
                          p_show_country_origin IN VARCHAR2,
                          -- 1.1 Dalit A. Raviv
                          /*p_send_mail IN VARCHAR2 DEFAULT 'N', --Commented on 06.06.2017 for CHG0040768*/
                          p_invoice_dist_mode IN NUMBER, --Invoice Distribution mode , Added on 06.06.2017 for CHG0040768 , in Place of p_send_mail
                          --  17/06/2012 added by Ofer Suad
                          p_print_zero_amt    IN VARCHAR2 DEFAULT 'N',
                          p_printing_category IN VARCHAR2) IS

    l_err_msg        VARCHAR2(2000) := NULL;
    l_err_code       NUMBER := 0;
    l_request_id     NUMBER := NULL;
    l_conc_shor_name VARCHAR2(250) := NULL;
    l_return         BOOLEAN;

    gen_exception EXCEPTION;

  BEGIN
    -- Step 1 Handle invoices population by dynamic sql (handle parameters sent)
    IF p_customer_name_low IS NULL AND p_customer_name_high IS NULL AND
       p_customer_no_low IS NULL AND p_customer_no_high IS NULL AND
       p_trx_from IS NULL AND p_to_trx IS NULL AND p_from_date IS NULL AND
       p_to_date IS NULL AND p_choice <> 1 THEN
      -- Dalit A. RAviv 19/01/2012

      fnd_file.put_line(fnd_file.log,
                        '!!!! Need to choose at list one of the major parameters:' ||
                        'p_customer_name_low / hight, p_customer_no_low / hight ' ||
                        'p_trx_from or p_to_trx, p_from_date or p_to_date ');
      errbuf  := '!!!! Need to choose at list one of the major parameters';
      retcode := 2;
      RAISE gen_exception;
    END IF;

    --IF p_send_mail = 'N' THEN
    print_invoice_new(errbuf                => l_err_msg, -- o v
                      retcode               => l_err_code, -- o n
                      p_request_id          => l_request_id, -- o n Dalit A. Raviv 06/10/2011
                      p_conc_shor_name      => l_conc_shor_name, -- o v Dalit A. Raviv 06/10/2011
                      p_org_id              => p_org_id, -- i n
                      p_choice              => p_choice, -- i n
                      p_batch_source_id     => p_batch_source_id, -- i n
                      p_cust_trx_class      => p_cust_trx_class, -- i v
                      p_cust_trx_type_id    => p_cust_trx_type_id, -- i n
                      p_customer_name_low   => p_customer_name_low, -- i v
                      p_customer_name_high  => p_customer_name_high, -- i v
                      p_customer_no_low     => p_customer_no_low, -- i v
                      p_customer_no_high    => p_customer_no_high, -- i v
                      p_installment         => p_installment, -- i n
                      p_trx_from            => p_trx_from, -- i v
                      p_to_trx              => p_to_trx, -- i v
                      p_from_date           => p_from_date, -- i v
                      p_to_date             => p_to_date, -- i v
                      p_open_invoices_only  => p_open_invoices_only, -- i v
                      p_show_country_origin => p_show_country_origin, -- i v
                      --  17/06/2012 added by Ofer Suad
                      p_print_zero_amt    => p_print_zero_amt,
                      p_printing_category => p_printing_category,
                      p_invoice_dist_mode => p_invoice_dist_mode); --Added on 06.06.2017 for CHG0040768, in Place of p_send_mail
    /*p_send_mail         => p_send_mail \*'N'*\); -- Dalit A. Raviv 08/05/2014
    --Commented on 06.06.2017 for CHG0040768, New Parameter Added p_invoice_dist_mode*/
    /*END IF;
    IF p_send_mail = 'Y' THEN
      print_invoice_send_mail(errbuf                => l_err_msg, -- o v
                              retcode               => l_err_code, -- o n
                              p_org_id              => p_org_id, -- i n
                              p_choice              => p_choice, -- i n
                              p_batch_source_id     => p_batch_source_id, -- i n
                              p_cust_trx_class      => p_cust_trx_class, -- i v
                              p_cust_trx_type_id    => p_cust_trx_type_id, -- i n
                              p_customer_name_low   => p_customer_name_low, -- i v
                              p_customer_name_high  => p_customer_name_high, -- i v
                              p_customer_no_low     => p_customer_no_low, -- i v
                              p_customer_no_high    => p_customer_no_high, -- i v
                              p_installment         => p_installment, -- i n
                              p_trx_from            => p_trx_from, -- i v
                              p_to_trx              => p_to_trx, -- i v
                              p_from_date           => p_from_date, -- i v
                              p_to_date             => p_to_date, -- i v
                              p_open_invoices_only  => p_open_invoices_only, -- i v
                              p_show_country_origin => p_show_country_origin, -- i v
                              --  17/06/2012 added by Ofer Suad
                              p_print_zero_amt      => p_print_zero_amt,
                              p_printing_category   => p_printing_category,
                              p_send_mail           => 'Y'); -- Dalit A. Raviv 08/05/2014
    END IF;*/

    errbuf  := l_err_msg;
    retcode := l_err_code;
  EXCEPTION
    WHEN gen_exception THEN
      l_return := fnd_concurrent.set_completion_status('ERROR', errbuf);
      IF NOT l_return THEN
        fnd_file.put_line(fnd_file.log, 'Dalit ');
      END IF;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        '3: print_invoice Exception: ' || SQLERRM);
      retcode := 2;
      errbuf  := SQLERRM;
  END print_invoice;
  --------------------------------------------------------------------
  --  name:            get_invoice_water_mark
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   30/05/2017
  ---------------------------------------------------------------------
  --  purpose :        This Procedure will be Called from XXAR_INVOICE.rdf & XXAR_SSUS_TRX_REP.rdf
  --                   common Procedure t0 get the Invoice WaterMark
  --  Parameters :     p_invoice_choice (1 0r 2 or 3 ) Oroginal / Copy / Draft
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/05/2017  Lingaraj Sarangi  CHG0037087 Update and standardize email generation logic proc send_Invoice_email()
  --------------------------------------------------------------------
  FUNCTION get_invoice_water_mark(p_invoice_choice NUMBER) RETURN VARCHAR2 IS
    l_env        VARCHAR2(20) := xxobjt_general_utils_pkg.am_i_in_production;
    l_water_mark VARCHAR2(50) := '';
  Begin
    --Set Watermark Text.
    If nvl(fnd_profile.value('XXAR_INVOICE_USE_WATERMARK'), 'N') = 'Y' then
      if p_invoice_choice = 1 then
        if l_env = 'Y' then
          l_water_mark := null;
        else
          fnd_message.set_name('XXOBJT', 'XXAR_INVOICE_SEND_MAIL8');
          l_water_mark := fnd_message.get;
        end if;
      else
        l_water_mark := null;
      end If;
    end if;
    Return l_water_mark;
  End get_invoice_water_mark;
  --------------------------------------------------------------------
  --  name:            get_customer_contact_email
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   24/05/2017
  --------------------------------------------------------------------
  --  purpose :        To Get the Customer Contact Email to Send Invoice
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  1.0  24/05/2017  Lingaraj Sarangi    CHG0037087 :  Email options for sending out daily invoices
  --  1.1  25/07/2017  Lingaraj Sarangi    INC0098186 -  Increase Email Variable length
  --  2.0  02/03/2018  Erik Morgan         CHG0042403 - Change location of email to customer bill-to address
  --------------------------------------------------------------------
  FUNCTION get_customer_contact_email(p_customer_trx_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_email_address Varchar2(500); --Added 25/07/2017 for INC0098186 - Variable length increased from 100 to 500
  Begin
    /* Old logic, replaced with new functionality CHG0042403
      SELECT hov.email_address
          INTO l_email_address
          FROM ra_customer_trx_all   rta,
               hz_cust_accounts      htc,
               hz_relationships      rl,
               hz_org_contacts_v     hov,
               hz_cust_account_roles hcar
         WHERE rta.customer_trx_id = p_customer_trx_id
           AND htc.cust_account_id = rta.bill_to_customer_id
           AND rl.subject_id = htc.party_id
           AND hov.party_relationship_id = rl.relationship_id
           AND hov.job_title = 'Invoice Mail'
           AND hov.job_title_code = 'XX_ACCOUNTS_PAYABLE'
           AND nvl(hov.status, 'A') = 'A'
           AND hov.contact_point_type = 'EMAIL'
           AND hov.contact_primary_flag = 'Y'
           AND hcar.party_id = rl.party_id
           AND nvl(hcar.current_role_state, 'A') = 'A'
           AND hcar.cust_account_id = htc.cust_account_id
           AND rownum = 1;
    --End Old logic, replaced with new function ality
    */

    --Begin New Logic
    Begin
      l_email_address := bill_to_contact_email(p_customer_trx_id); --Level 1 Bill To Contact

      If l_email_address is null Then
        --if not value found check next level
        l_email_address := bill_to_address_email(p_customer_trx_id); --Level 2 bill to address email

        if l_email_address is null then
          --if not value found check next level
          l_email_address := default_invoices_email(p_customer_trx_id); --Level 3 account default email

        end if;

      End If;

    Exception
      When OTHERS Then
        fnd_file.put_line(fnd_file.log, 'Error: ' || SQLERRM);
        l_email_address := null;

    End;
    --End New Logic

    l_email_address := REPLACE(l_email_address, ';', ','); --Added 25/07/2017 for INC0098186 - Variable length increased from 100 to 500
    Return l_email_address;
  Exception
    When No_Data_Found Then
      Return Null;
    When OTHERS Then
      fnd_file.put_line(fnd_file.log, 'Error: ' || SQLERRM);
      Return Null;
  End get_customer_contact_email;
  --------------------------------------------------------------------
  --  name:            is_cust_contact_email_exists
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   24/05/2017
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  1.0  24/05/2017  Lingaraj Sarangi    CHG0037087 :  Email options for sending out daily invoices
  --------------------------------------------------------------------
  FUNCTION is_cust_contact_email_exists(p_customer_trx_id IN NUMBER)
    RETURN VARCHAR2 IS
  Begin
    If (get_customer_contact_email(p_customer_trx_id)) is not null Then
      Return 'Y';
    Else
      Return 'N';
    End If;
  End is_cust_contact_email_exists;
  --------------------------------------------------------------------
  --  name:            get_sales_admin_name
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   24/05/2017
  --------------------------------------------------------------------
  --  purpose :        Get Sales Admin Name for Non US Invoice
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  1.0  24/05/2017  Lingaraj Sarangi    CHG0037087 :  Email options for sending out daily invoices
  --------------------------------------------------------------------
  FUNCTION get_sales_admin_name(p_customer_trx_id IN NUMBER) RETURN VARCHAR2 IS
    l_sales_admin_name Varchar2(240);
  Begin
    select pf.full_name
      into l_sales_admin_name
      from oe_order_headers_all      oh,
           oe_order_lines_all        ol,
           fnd_user                  u,
           per_all_people_f          pf,
           ra_customer_trx_lines_all rctl
     where u.user_id = oh.created_by
       and ol.header_id = oh.header_id
       and pf.person_id = u.employee_id
       and oh.creation_date between pf.effective_start_date and
           pf.effective_end_date
       and to_char(ol.line_id) = rctl.interface_line_attribute6
       and rctl.interface_line_context in ('ORDER ENTRY', 'INTERCOMPANY')
       and rctl.customer_trx_id = p_customer_trx_id
       and rctl.line_type = 'LINE'
       and rownum = 1;

    Return l_sales_admin_name;
  Exception
    When no_data_found Then
      Return Null;
  End get_sales_admin_name;
  --------------------------------------------------------------------
  --  name:            get_inv_dist_where_query (Get Invoice Distribution Where Query)
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   24/05/2017
  --------------------------------------------------------------------
  --  purpose :        Prepare Invoice Distribution Query which can be
  --                   used with the  XXAR_INVOICE.rdf & XXAR_SSUS_TRX_REP.rdf
  --                   Report Parameter:-   :P_WHERE_INV_DIST_MODE
  --                   This Function Specific to use in RDF Reports Only
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  1.0  24/05/2017  Lingaraj Sarangi    CHG0040768 : initial Build
  --------------------------------------------------------------------
  FUNCTION get_inv_dist_where_query(p_inv_dist_mode NUMBER) RETURN VARCHAR2 IS
    l_where_cond VARCHAR2(400);
  Begin

    If p_inv_dist_mode = 1 Then
      --SUPPRESS_EMAIL ( Print All generated Invoices)
      --Donot fire bursting program
      l_where_cond := '';
    ElsIf p_inv_dist_mode = 2 Then
      --CUSTOMER_EMAIL (Only generate Invoices, where Customer contact Email available to Send invoices by email)
      l_where_cond := q'[ And xxar_print_invoice.is_cust_contact_email_exists(trx.customer_trx_id) = 'Y']';
    ElsIf p_inv_dist_mode = 3 Then
      --CUSTOMER_EMAIL & PRINTER
      --Send Invoices by Email who ever eligiable and print all the Generated Invoices also
      l_where_cond := '';
    ElsIf p_inv_dist_mode = 4 Then
      --CUSTOMER_NO_EMAIL_PRINT
      --Generate Invoices for only those invoices for which Customer Contact email is not exists
      l_where_cond := q'[ And xxar_print_invoice.is_cust_contact_email_exists(trx.customer_trx_id) = 'N']';
    End If;
    Return l_where_cond;
  End get_inv_dist_where_query;
  --------------------------------------------------------------------
  --  name:            get_inv_dist_where_query (Get Invoice Distribution Where Query)
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   24/05/2017
  --------------------------------------------------------------------
  --  purpose :        Prepare Invoice Distribution Query which can be
  --                   used with the  XXAR_INVOICE.rdf & XXAR_SSUS_TRX_REP.rdf
  --                   Report Parameter:-   :P_WHERE_INV_DIST_MODE
  --                   This Function Specific to use in RDF Reports Only
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  1.0  24/05/2017  Lingaraj Sarangi    CHG0040768 : initial Build
  --------------------------------------------------------------------
  Function submit_bursting_request(p_conc_request_id in number) Return Number Is
    l_burst_request_id NUMBER;
  Begin
    l_burst_request_id := fnd_request.submit_request(application => 'XDO',
                                                     program     => 'XDOBURSTREP',
                                                     argument1   => 'Y',
                                                     argument2   => p_conc_request_id);
    if l_burst_request_id is not null then
      fnd_file.put_line(fnd_file.log,
                        'Bursting Sucessful for Concurrent request :' ||
                        p_conc_request_id);
      fnd_file.put_line(fnd_file.log,
                        'Bursting  request ID:' || l_burst_request_id);
    else
      fnd_file.put_line(fnd_file.log,
                        'Bursting Failed for Concurrent request :' ||
                        p_conc_request_id);
    end if;
    Return l_burst_request_id;
  Exception
    When Others Then
      fnd_file.put_line(fnd_file.log,
                        'Bursting Failed for Concurrent request :' ||
                        p_conc_request_id);
      fnd_file.put_line(fnd_file.log, 'Error :' || sqlerrm);
      Return Null;
  End submit_bursting_request;
  --------------------------------------------------------------------
  --  name:            afterreport
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   24/05/2017
  --------------------------------------------------------------------
  --  purpose :        After Report Trigger for XXAR_INVOICE.rdf ,XXAR_SSUS_TRX_REP.rdf
  --                   The Code content added from RDF Files
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  1.0  24/05/2017  Lingaraj Sarangi    CHG0037087 : initial Build
  --  1.1  25/07/2017  Lingaraj Sarangi    INC0098186 - Busring Should not Fire for Only Printing Options
  --                                       Copy Invoice Program should not be triggered if Distribution is - 2 - Customers for Email distribution or  3 - All customers printed, auxiliary email.
  --                                       When Original Invoice and  Send Original Invoice By Mail = N.
  --  1.2  31/10/2018  Bellona(TCS)        CHG0040499(BR6) : Change logic of sending mail
  --                                       If intercompany trigger bursting for Inv Dist Mode = 2,3,4
  --                                       If non-intercompany trigger bursting for Inv Dist Mode = 2,3
  --------------------------------------------------------------------
  FUNCTION afterreport(p_batch_source_id   IN NUMBER, --CHG0040499(BR6)
                       p_invoice_dist_mode IN NUMBER,
                       p_org_id            IN NUMBER,
                       p_choice            IN NUMBER,
                       P_Copy_Orig         IN VARCHAR2,
                       p_conc_request_id   IN NUMBER,
                       p_report_rec_count  IN NUMBER -- No of Records fetched in the AR Invoice Report
                       ) RETURN BOOLEAN IS

    l_burst_request_id NUMBER := 0;
    l_request_id       NUMBER;
    l_result           BOOLEAN;
    l_no_copies        NUMBER;
    l_printer          VARCHAR2(30);
    lb_flag            BOOLEAN := FALSE;
    --l_db         varchar2(20) := sys_context('userenv', 'db_name');
    l_fcr_row      fnd_concurrent_requests%rowtype;
    l_send_org_inv VARCHAR2(10); --Will hold Profile value of "XXAR_SEND_ORIGINAL_INV_BY_MAIL"
    l_profile      VARCHAR2(100) := fnd_profile.value('XXAR_INVOICE_SEND_MAIL_USER');

    l_complete   BOOLEAN;
    l_phase      VARCHAR2(100);
    l_status     VARCHAR2(100);
    l_dev_phase  VARCHAR2(100);
    l_dev_status VARCHAR2(100);
    l_message    VARCHAR2(1000);
    --l_gen_mailbox_email ,l_trigger_bursting_prog -  Added on 25th Jul 2017 for INC0098186
    l_gen_mailbox_email     VARCHAR2(240) := xxobjt_general_utils_pkg.get_profile_value('XXAR_SEND_INVOICE_GENERAL_MAIL_BOX',
                                                                                        'ORG',
                                                                                        p_org_id);
    l_trigger_bursting_prog VARCHAR2(1) := 'N';
    l_src_type              RA_BATCH_SOURCES_ALL.NAME%TYPE; -- CHG0040499(BR6) -- will hold invoivce source type
  begin
    fnd_file.put_line(fnd_file.log,
                      'AfterReport Trigger Called the Package');
    fnd_file.put_line(fnd_file.log, ':P_ORG_ID:   ' || P_ORG_ID);
    fnd_file.put_line(fnd_file.log, ':P_CHOICE:   ' || P_CHOICE);
    fnd_file.put_line(fnd_file.log, ':P_Copy_Orig:' || P_Copy_Orig);
    fnd_file.put_line(fnd_file.log,
                      ':p_inv_dis_mode(Invoice Distribution Mode):' ||
                      p_invoice_dist_mode);
    fnd_file.put_line(fnd_file.log,
                      ':p_batch_source_id:' || p_batch_source_id);

    --Fetching source type - CHG0040499(BR6)
    select decode(NAME, 'Intercompany', 'I', NAME)
      into l_src_type
      from RA_BATCH_SOURCES_ALL
     where BATCH_SOURCE_ID = P_BATCH_SOURCE_ID
       and ORG_ID = P_ORG_ID;

    fnd_file.put_line(fnd_file.log, 'Source Type: ' || l_src_type);
    /* Invoice Distribution Method : Value Set : XXAR_INVOICE_DISTRIBUTION_METHOD
    1 -    SUPPRESS_EMAIL (Print All generated Invoice)
        > Donot Fire bursting
    2 -     CUSTOMER_EMAIL (Generate Invoices , only for those Customers whose Contact email id Exists )
        >  xxar_print_invoice.is_cust_contact_email_exists(p_customer_trx_id)  = 'Y'
        > Fire bursting Program
    3 -  CUSTOMER_EMAIL & PRINTER   (Send emails both in Email and Print - All invoices)
        > Fire bursting Program
    4 -  CUSTOMER_NO_EMAIL_PRINT (Generate Invoices, only for those customers whose contact email id does not exists)
      >  xxar_print_invoice.is_customer_contact_email_exists(p_customer_trx_id)  = 'N'
      >  donot Fire bursting
      -----------------------------------------------------------------------------------------
      2 or 3       > EMAIl invoices (Fire Bursting)
      1 or 3 or 4  > Print Invoices
      -------------------------------------------
      1 - All customers printed, suppress email
      2 - Customers for Email distribution
      3 - All customers printed, auxiliary email
      4 - Customers for Printed distribution
    */
    --l_trigger_bursting_prog Condition -  Added on 25th Jul 2017 for INC0098186
    -- Mails will be send to General Email Box, irespective of the Distribution Method.
    -- If General Mail Box Email is not available and Distribution method is Only Printing , then do not trigger the Bursting
    l_trigger_bursting_prog := (Case
                                 When p_invoice_dist_mode = 2 or
                                      p_invoice_dist_mode = 3 Then
                                  'Y' -- Distribution Mode is Email
                                 When p_invoice_dist_mode = 4 and
                                      (l_src_type = 'I' or
                                      l_gen_mailbox_email is not null or
                                      nvl(l_profile, 'N') = 'Y') Then
                                  'Y'
                                 Else
                                  'N'
                               End);

    --Fetch the Profile Value for Sending Original Invoice By Mail or Not
    --Profile Value Set on the Organization Level / OU Level.
    l_send_org_inv := nvl(xxobjt_general_utils_pkg.get_profile_value('XXAR_SEND_ORIGINAL_INV_BY_MAIL',
                                                                     'ORG',
                                                                     P_ORG_ID),
                          'N');
    fnd_file.put_line(fnd_file.log,
                      'Send Original Invoice by Mail ?:' || l_send_org_inv);

    --If p_invoice_dist_mode = 2 or p_invoice_dist_mode = 3 Then  -- iN CASE OF eMAIL
    -- Or Condition [p_invoice_dist_mode in (1,4)] Added on 31-JUL-2017 for INC0098186
    -- Or Condition [l_src_type = 'I'] Added for CHG0040499(BR6)
    If p_choice = 1 and (nvl(l_send_org_inv, 'N') = 'Y' /*OR p_invoice_dist_mode in (1, 4)*/
       OR l_src_type = 'I') Then
      -- If Send original Invoice is Enabled for the Operating Unit
      -- Send the Invoice by Email
      --- p_invoice_dist_mode  condition Added on 25/07/2017 INC0098186

      If p_report_rec_count > 0 And l_trigger_bursting_prog = 'Y' Then
        l_burst_request_id := submit_bursting_request(P_CONC_REQUEST_ID);
      End If;
      /*    Else
      If p_choice <> 1 then
        -- For Invoice Copy or Draft
        -- If Invoice is not Original, Then send the invoice Copy / Draft by Mail
        --p_invoice_dist_mode  condition added on 25/07/2017 INC0098186 -

        If p_report_rec_count > 0 And l_trigger_bursting_prog = 'Y' Then
         -- CHG0040499(BR6) do not use email bursting for Copy or Draft
         -- l_burst_request_id := submit_bursting_request(P_CONC_REQUEST_ID);
         NULL;
        End If;
      Else
        --If Invoice is Original, then generate the Report again with Copy of the Invoice
        --Only for Distribution mode 2(Customers for Email distribution) or 3 (All customers printed, auxiliary email)
        Begin
          select fcr.number_of_copies, fcr.printer
            into l_no_copies, l_printer
            from fnd_concurrent_requests fcr
           where fcr.request_id = P_CONC_REQUEST_ID;
        Exception
          when no_data_found then
            fnd_file.put_line(fnd_file.log,
                              'Execption Request_id: ' || P_CONC_REQUEST_ID);
            l_no_copies := null;
            l_printer   := null;
        End;
        Begin
          --Get the Parameters from parent Program
          Select fcr1.*
            into l_fcr_row
            from fnd_concurrent_requests fcr1, fnd_concurrent_requests fcr2
           where fcr1.request_id = fcr2.parent_request_id
             and fcr2.request_id = p_conc_request_id;

          -- Submit the report again (submit the program that submit the report)
          l_Request_id := fnd_request.Submit_Request(application => 'XXOBJT',
                                                     program     => 'XXARPRTINV_NEW',
                                                     argument1   => p_org_id,
                                                     argument2   => 2,
                                                     argument3   => l_fcr_row.argument3, --:p_batch_source_id,
                                                     argument4   => l_fcr_row.argument4, --:p_cust_trx_class,
                                                     argument5   => l_fcr_row.argument5, --:p_cust_trx_type_id,
                                                     argument6   => l_fcr_row.argument6, --:p_customer_name_low,
                                                     argument7   => l_fcr_row.argument7, --:p_customer_name_high,
                                                     argument8   => l_fcr_row.argument8, --:p_customer_no_low,
                                                     argument9   => l_fcr_row.argument9, --:p_customer_no_high,
                                                     argument10  => l_fcr_row.argument10, --:p_installment,
                                                     argument11  => l_fcr_row.argument11, --:p_trx_from,
                                                     argument12  => l_fcr_row.argument12, --:p_to_trx,
                                                     argument13  => l_fcr_row.argument13, --:p_from_date,
                                                     argument14  => l_fcr_row.argument14, --:p_to_date,
                                                     argument15  => l_fcr_row.argument15, --:p_open_invoices_only,
                                                     argument16  => l_fcr_row.argument16, --:P_COUNTRY_YN,
                                                     argument17  => l_fcr_row.argument17, --:P_INVOICE_DISTRIBUTION_MODE
                                                     argument18  => l_fcr_row.argument18, --:P_INV_W_ZERO_AMT,
                                                     argument19  => l_fcr_row.argument19 --:P_CUST_PRINT_CATEGORY
                                                     );

          commit;
        Exception
          When no_Data_found Then
            fnd_file.put_line(fnd_file.log,
                              'No Data found for the Request ID :' ||
                              p_conc_request_id ||
                              ' when trying to submit the Program with a Invoice Copy');
          When Others Then
            fnd_file.put_line(fnd_file.log,
                              'Error During XX: Print Invoice Program Submission , Error :' ||
                              SQLERRM);
        End;

      End If;*/
    End If;

    commit;

    return(TRUE);
  Exception
    When Others Then
      fnd_file.put_line(fnd_file.log, sqlerrm);
      Return TRUE;
  End afterreport;

END xxar_print_invoice;
/
