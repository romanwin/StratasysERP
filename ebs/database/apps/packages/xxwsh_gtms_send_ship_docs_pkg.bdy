create or replace package body xxwsh_gtms_send_ship_docs_pkg IS

  --------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               XXWSH_SEND_SHIPPING_DOCS_PKG
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      12/05/2015
  --  Description:        Sending shipping documents by FTP Folder
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/04/2015    Michal Tzvik    initial build
  --  1.1   19.2.17      YUVAL TAL       CHG0039163 modify submit_shipping_docs
  --  1.2   20.02.2018  bellona banerjee  CHG0041294- Added P_Delivery_Name to 
  --	    							  send_shipping_docs, submit_shipping_docs
  --									  submit_document_set as part of delivery_id 
  --									  to delivery_name conversion.  
  --------------------------------------------------------------------

  ----------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               submit_packing_list
  --  create by:          Michal Tzvik
  --  creation date:      12/05/2015
  --  Purpose :           CHG0034901 - Sending shipping documents by FTP Folder
  --
  --                      Submit concurrent requst "XX: Copy Concurrent Request Output"
  --                      in order to copy concurrent request output to a directory
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/05/2015    Michal Tzvik    Initial Build
  ----------------------------------------------------------------------
  PROCEDURE copy_concurrent_output(p_request_id       NUMBER,
                   p_target_directory VARCHAR2,
                   p_target_file_name VARCHAR2,
                   x_err_code         OUT NUMBER,
                   x_err_msg          OUT VARCHAR2) IS
  
    l_conc_name  fnd_concurrent_programs.concurrent_program_name%TYPE;
    l_file_type  fnd_conc_req_outputs.file_type%TYPE;
    l_phase      VARCHAR2(20);
    l_status     VARCHAR2(20);
    l_dev_phase  VARCHAR2(20);
    l_dev_status VARCHAR2(20);
    l_message    VARCHAR2(150);
    x_request_id NUMBER;
  BEGIN
  
    x_err_msg  := '';
    x_err_code := 0;
  
    BEGIN
    
      SELECT fcp.concurrent_program_name,
     fcro.file_type
      INTO   l_conc_name,
     l_file_type
      FROM   fnd_concurrent_requests fcr,
     fnd_concurrent_programs fcp,
     fnd_conc_req_outputs    fcro
      WHERE  fcr.request_id = p_request_id
      AND    fcp.concurrent_program_id = fcr.concurrent_program_id
      AND    fcro.concurrent_request_id(+) = fcr.request_id;
    EXCEPTION
      WHEN OTHERS THEN
        x_err_msg  := 'Error: failed to get concurrent name for requset id ' ||
              p_request_id || ': ' || SQLERRM;
        x_err_code := 1;
        RETURN;
    END;
  
    x_request_id := fnd_request.submit_request(application => 'XXOBJT', --
                       program     => 'XXFNDCPCONCOUTPUT', --
                       argument1   => l_conc_name, -- Concurrent Name
                       argument2   => p_request_id, -- Request_Id
                       argument3   => l_file_type, -- Output Extension
                       argument4   => p_target_directory, -- Target_Directory
                       argument5   => p_target_file_name -- Target_File_Name
                       );
  
    COMMIT;
  
    IF x_request_id = 0 THEN
      x_err_msg  := 'Error submitting request of copy concurrent request output to directory';
      x_err_code := 1;
      RETURN;
    
    ELSE
      x_err_msg := 'Request ' || x_request_id ||
           ' was submitted successfully';
    
    END IF;
  
    IF fnd_concurrent.wait_for_request(request_id => x_request_id, --
               INTERVAL   => 5, --
               phase      => l_phase, --
               status     => l_status, --
               dev_phase  => l_dev_phase, --
               dev_status => l_dev_status, --
               message    => l_message) THEN
    
      NULL;
    
    END IF;
    IF upper(l_phase) = 'COMPLETE' AND
       upper(l_status) IN ('ERROR', 'WARNING') THEN
      x_err_code := 1;
      x_err_msg  := ' copy concurrent output program completed in ' ||
            l_status || '. See log for request_id=' || x_request_id;
      RETURN;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_msg  := 'Error when copy concurrent request output to directory: ' ||
            SQLERRM;
      x_err_code := 1;
  END copy_concurrent_output;

  ----------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               submit_comm_invoice
  --  create by:          Michal Tzvik
  --  creation date:      12/05/2015
  --  Purpose :           CHG0034901 - Sending shipping documents by FTP Folder
  --
  --                      Submit commercial invoice concurrent request.
  --                      There is only one rellevant concurrent for all OU.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   14/05/2015    Michal Tzvik    Initial Build
  ----------------------------------------------------------------------
  PROCEDURE submit_comm_invoice(--p_delivery_id     IN NUMBER, -- CHG0041294 on 20/02/2018 for delivery id to name change
                p_delivery_name     in varchar2,    
                p_organization_id IN NUMBER,
                x_request_id      OUT NUMBER,
                x_err_code        OUT NUMBER,
                x_err_msg         OUT VARCHAR2) IS
  
    l_default_language    VARCHAR2(20);
    l_default_territory   VARCHAR2(20);
    l_default_output_type VARCHAR2(20);
    l_phase               VARCHAR2(20);
    l_status              VARCHAR2(20);
    l_dev_phase           VARCHAR2(20);
    l_dev_status          VARCHAR2(20);
    l_message             VARCHAR2(150);
    l_request_id          NUMBER;
  
    l_prog_short_name VARCHAR2(30) := fnd_profile.value('XXWSH_SEND_COMMERCIAL_INVOICE');
  BEGIN
  
    x_err_msg  := '';
    x_err_code := 0;
  
    SELECT xt.default_language,
           xt.default_territory,
           nvl(xt.default_output_type, 'PDF')
    INTO   l_default_language,
           l_default_territory,
           l_default_output_type
    FROM   xdo_templates_b xt
    WHERE  xt.application_short_name = 'XXOBJT'
    AND    xt.template_code = l_prog_short_name;
  
    IF NOT
        fnd_request.add_layout(template_appl_name => 'XXOBJT', --
               template_code      => l_prog_short_name, --
               template_language  => l_default_language, --
               template_territory => l_default_territory, --
               output_format      => l_default_output_type) THEN
    
      x_err_msg  := 'Error assigning template to commercial invoice';
      x_err_code := 1;
      RETURN;
    
    END IF;
  
    l_request_id := fnd_request.submit_request(application => 'XXOBJT', --
                       program     => l_prog_short_name, --
                       argument1   => NULL, -- trip stop
                       argument2   => NULL, -- Departure Date (Low)
                       argument3   => NULL, -- Departure Date (high)
                       argument4   => NULL, -- Freight Carrier
                       argument5   => p_organization_id, --Warehouse
                       argument6   => p_delivery_name,--p_delivery_id, --Delivery Name    -- CHG0041294 on 20/02/2018 for delivery id to name change
                       argument7   => 'D', --Item Display
                       argument8   => fnd_profile.value('OE_ID_FLEX_CODE'), --Item Flex Code
                       argument9   => NULL, -- Currency Code
                       argument10  => 'N', -- Print Customer Item Information
                       argument11  => 'Y', -- Print Item Country of Origin
                       argument12  => 'Y', -- Print Item Tariff Code
                       argument13  => 'N', -- Included Yes / No
                       argument14  => 'N', -- Send Mail Yes / No
                       argument15  => NULL -- P_COPY_NO
                       );
  
    COMMIT;
  
    IF x_request_id = 0 THEN
      x_err_msg  := 'Error submitting request of commercial invoice';
      x_err_code := 1;
      RETURN;
    
    ELSE
      x_err_msg := 'Request ' || l_request_id ||
           ' was submitted successfully';
    
    END IF;
  
    IF fnd_concurrent.wait_for_request(request_id => l_request_id, --
               INTERVAL   => 5, --
               phase      => l_phase, --
               status     => l_status, --
               dev_phase  => l_dev_phase, --
               dev_status => l_dev_status, --
               message    => l_message) THEN
    
      NULL;
    
    END IF;
    IF upper(l_phase) = 'COMPLETE' AND
       upper(l_status) IN ('ERROR', 'WARNING') THEN
      x_err_code := 1;
      x_err_msg  := ' Commercial invoice concurrent program completed in ' ||
            l_status || '. See log for request_id=' || l_request_id;
      RETURN;
    END IF;
  
    SELECT fcr.request_id
    INTO   x_request_id
    FROM   fnd_concurrent_requests fcr
    WHERE  fcr.parent_request_id = l_request_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_msg  := 'Error submitting commercial invoice: ' || SQLERRM;
      x_err_code := 1;
    
  END submit_comm_invoice;
  ----------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               submit_packing_list
  --  create by:          Michal Tzvik
  --  creation date:      12/05/2015
  --  Purpose :           CHG0034901 - Sending shipping documents by FTP Folder
  --
  --                      Submit packing list concurrent request.
  --                      There are several PL programs, all of them have the
  --                      same parameters.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/05/2015    Michal Tzvik    Initial Build
  ----------------------------------------------------------------------
  PROCEDURE submit_packing_list(p_conc_appl_short_name IN VARCHAR2,
                p_conc_program_name    IN VARCHAR2,
                --p_delivery_id          IN NUMBER,    
                p_delivery_name        IN VARCHAR2,-- CHG0041294 on 20/02/2018 for delivery id to name change
                p_organization_id      IN NUMBER,
                x_request_id           OUT NUMBER,
                x_err_code             OUT NUMBER,
                x_err_msg              OUT VARCHAR2) IS
  
    l_temp_appl_short_name xdo_templates_b.application_short_name%TYPE;
    l_template_name        xdo_templates_b.template_code%TYPE;
    l_default_language     VARCHAR2(20);
    l_default_territory    VARCHAR2(20);
    l_default_output_type  VARCHAR2(20);
    l_phase                VARCHAR2(20);
    l_status               VARCHAR2(20);
    l_dev_phase            VARCHAR2(20);
    l_dev_status           VARCHAR2(20);
    l_message              VARCHAR2(150);
  
  BEGIN
  
    x_err_msg  := '';
    x_err_code := 0;
  
    SELECT xt.default_language,
           xt.default_territory,
           nvl(xt.default_output_type, 'PDF'),
           xt.template_code,
           xt.application_short_name
    INTO   l_default_language,
           l_default_territory,
           l_default_output_type,
           l_template_name,
           l_temp_appl_short_name
    FROM   xdo_templates_b xt
    WHERE  xt.ds_app_short_name = p_conc_appl_short_name
    AND    xt.data_source_code = p_conc_program_name;
  
    IF NOT
        fnd_request.add_layout(template_appl_name => l_temp_appl_short_name, --
               template_code      => l_template_name, --
               template_language  => l_default_language, --
               template_territory => l_default_territory, --
               output_format      => l_default_output_type) THEN
    
      x_err_msg  := 'Error assigning template to packing list ' ||
            p_conc_program_name;
      x_err_code := 1;
      RETURN;
    
    END IF;
  
    x_request_id := fnd_request.submit_request(application => p_conc_appl_short_name, --
                       program     => p_conc_program_name, --
                       argument1   => p_organization_id, -- Warehouse
                       argument2   => p_delivery_name,--p_delivery_id, -- Delivery Name -- CHG0041294 on 20/02/2018 for delivery id to name change
                       argument3   => 'N', -- Print Customer Item
                       argument4   => 'D', -- Item Display Option
                       argument5   => 'DRAFT', --Print Mode
                       argument6   => 'INV', -- Sort Option
                       argument7   => NULL, --Delivery Date (Low)
                       argument8   => NULL, --Delivery Date (High)
                       argument9   => NULL, -- Freight Carrier
                       argument10  => fnd_profile.value('REPORT_QUANTITY_PRECISION'), --Quantity Precision
                       argument11  => 'Y');
  
    COMMIT;
  
    IF x_request_id = 0 THEN
      x_err_msg  := 'Error submitting request of ' || p_conc_program_name;
      x_err_code := 1;
      RETURN;
    
    ELSE
      x_err_msg := 'Request ' || x_request_id ||
           ' was submitted successfully';
    
    END IF;
  
    IF fnd_concurrent.wait_for_request(request_id => x_request_id, --
               INTERVAL   => 5, --
               phase      => l_phase, --
               status     => l_status, --
               dev_phase  => l_dev_phase, --
               dev_status => l_dev_status, --
               message    => l_message) THEN
    
      NULL;
    
    END IF;
    IF upper(l_phase) = 'COMPLETE' AND
       upper(l_status) IN ('ERROR', 'WARNING') THEN
      x_err_code := 1;
      x_err_msg  := ' Packing List concurrent program ' ||
            p_conc_program_name || ' completed in ' || l_status ||
            '. See log for request_id=' || x_request_id;
      RETURN;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_msg  := 'Error submitting packing list ' || p_conc_program_name || ': ' ||
            SQLERRM;
      x_err_code := 1;
  END submit_packing_list;

  --------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               send_shipping_docs
  --  create by:          Michal Tzvik
  --  creation date:      12/05/2015
  --  Purpose :           CHG0034901 - Sending shipping documents by FTP Folder
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/05/2015    Michal Tzvik  Initial Build
  ----------------------------------------------------------------------
  PROCEDURE send_shipping_docs(errbuf        OUT VARCHAR2,
               retcode       OUT VARCHAR2,
               --p_delivery_id IN NUMBER    -- CHG0041294 on 20/02/2018 for delivery id to name change
               p_delivery_name        IN VARCHAR2) IS
    l_err_msg  VARCHAR2(1000);
    l_err_code NUMBER;
  
    l_delivery_rec wsh_new_deliveries%ROWTYPE;
    l_org_id       NUMBER;
    l_pl_conc_name VARCHAR2(30);
    l_defined      BOOLEAN;
    l_request_id   NUMBER;
    l_errbuf       VARCHAR2(1500);
    l_retcode      VARCHAR2(1);
  
    l_target_directory VARCHAR2(1000);
  
    process_failed EXCEPTION;
  BEGIN
  
    -- Get path on server where output files will be saved.
    -- A Bpel process then move them by ftp from this path to final destination
    l_target_directory := fnd_profile.value('XXWSH_GTMS_SHARED_DIRECTORY');
    IF l_target_directory IS NULL THEN
      l_err_msg := 'Directory path is not defined.';
      RAISE process_failed;
    END IF;
  
    -- 1. Determine which PL to send, according to OU
    BEGIN
      SELECT *
      INTO   l_delivery_rec
      FROM   wsh_new_deliveries wnd
      WHERE  1 = 1
      AND    wnd.delivery_id = xxinv_trx_in_pkg.get_delivery_id(p_delivery_name);
      --p_delivery_id;  -- CHG0041294 on 20/02/2018 for delivery id to name change
    
      l_org_id := xxhz_util.get_inv_org_ou(l_delivery_rec.organization_id);
    
    EXCEPTION
      WHEN OTHERS THEN
        l_err_msg := 'Failed to get org id: ' || SQLERRM;
        RAISE process_failed;
    END;
  
    IF l_org_id IS NULL THEN
      l_err_msg := 'Failed to get current OU';
      RAISE process_failed;
    END IF;
  
    fnd_profile.get_specific(name_z    => 'XXWSH_SEND_PACKING_LIST_ACCORDING_OU', -- Profile name
             org_id_z  => l_org_id, -- ou
             val_z     => l_pl_conc_name, -- out: profile value
             defined_z => l_defined -- out: is profile defined for current level
             );
  
    IF l_pl_conc_name IS NULL THEN
      l_err_msg := 'No PL is defined to current OU';
      RAISE process_failed;
    END IF;
  
    -- 2. Submit Packing list
    submit_packing_list(p_conc_appl_short_name => 'XXOBJT', --
        p_conc_program_name    => l_pl_conc_name, --
        --p_delivery_id          => l_delivery_rec.delivery_id, --
        p_delivery_name        => p_delivery_name,              -- CHG0041294 on 20/02/2018 for delivery id to name change
        p_organization_id      => l_delivery_rec.organization_id, --
        x_request_id           => l_request_id, --
        x_err_code             => l_err_code, --
        x_err_msg              => l_err_msg);
  
    IF l_err_code != '0' THEN
      l_err_msg := nvl(l_err_msg, 'Failed to submit packing list');
      RAISE process_failed;
    END IF;
  
    -- 3. Copy pl output to shared directory
    copy_concurrent_output(p_request_id       => l_request_id, --
           p_target_directory => l_target_directory, --
           p_target_file_name => 'PL_' || p_delivery_name ||--p_delivery_id ||    -- CHG0041294 on 20/02/2018 for delivery id to name change
                 '.pdf', --
           x_err_code         => l_err_code, --
           x_err_msg          => l_err_msg);
  
    IF l_err_code != '0' THEN
      l_err_msg := nvl(l_err_msg,
               'Failed to copy packing list to directory');
      RAISE process_failed;
    END IF;
  
    -- 4. Submit commercial invoice
    submit_comm_invoice(--p_delivery_id     => l_delivery_rec.delivery_id, --
        p_delivery_name        => p_delivery_name,                         -- CHG0041294 on 20/02/2018 for delivery id to name change
        p_organization_id => l_delivery_rec.organization_id, --
        x_request_id      => l_request_id, --
        x_err_code        => l_err_code, --
        x_err_msg         => l_err_msg);
  
    IF l_err_code != '0' THEN
      l_err_msg := nvl(l_err_msg, 'Failed to submit commercial invoice');
      RAISE process_failed;
    END IF;
  
    -- 3. Copy comm invoice output to shared directory
    copy_concurrent_output(p_request_id       => l_request_id, --
           p_target_directory => l_target_directory, --
           p_target_file_name => 'CI_' || p_delivery_name ||--p_delivery_id ||    -- CHG0041294 on 20/02/2018 for delivery id to name change
                 '.pdf', --
           x_err_code         => l_err_code, --
           x_err_msg          => l_err_msg);
  
    IF l_err_code != '0' THEN
      l_err_msg := nvl(l_err_msg,
               'Failed to copy commercial invoice to directory');
      RAISE process_failed;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Unexpected error: ' || l_err_msg);
      retcode := '2';
      xxobjt_wf_mail.send_mail_text(p_to_role     => xxobjt_general_utils_pkg.get_dist_mail_list(l_org_id,
                                 'GTMS_SHIPP_DOCS_TO'), --
            p_cc_mail     => xxobjt_general_utils_pkg.get_dist_mail_list(l_org_id,
                                 'GTMS_SHIPP_DOCS_CC'), --
            p_subject     => 'GTMS send shipping documents : Failure', --
            p_body_text   => 'An error occurred while trying to send shipping documents for delivery ' ||p_delivery_name || ': ' ||
                     --p_delivery_id || ': ' ||    -- CHG0041294 on 20/02/2018 for delivery id to name change
                     chr(10) ||
                     nvl(l_err_msg, SQLERRM), --
            p_err_code    => l_retcode, --
            p_err_message => l_errbuf);
      IF l_retcode != '0' THEN
        fnd_file.put_line(fnd_file.log,
          '***** Failed to send email: ' || l_errbuf);
        xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN', --
              p_subject     => 'GTMS send shipping documents : Failure', --
              p_body_text   => 'An error occurred while trying to send shipping documents for delivery ' ||p_delivery_name || ': ' ||
                       --p_delivery_id || ': ' ||
                       chr(10) ||
                       nvl(l_err_msg,
                           SQLERRM), --
              p_err_code    => l_retcode, --
              p_err_message => l_errbuf);
      END IF;
  END send_shipping_docs;

  --------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               submit_shipping_docs
  --  create by:          Michal Tzvik
  --  creation date:      12/05/2015
  --  Purpose :           CHG0034901 - Sending shipping documents by FTP Folder
  --                      Run concurrent program XXWSH_SEND_SHIPPING_DOCS
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/05/2015    Michal Tzvik  Initial Build
  -- 1.1    19.2.17       YUVAL TAL     CHG0039163 FORWARD proc to new proc submit_document_set
  ----------------------------------------------------------------------
  PROCEDURE submit_shipping_docs(--p_delivery_id IN NUMBER, -- CHG0041294 on 20/02/2018 for delivery id to name change
                 p_delivery_name        IN VARCHAR2,
                 x_err_code    OUT NUMBER,
                 x_err_msg     OUT VARCHAR2) IS
    l_request_id NUMBER;
    l_err_msg    VARCHAR2(1000);
  
    l_user_id      NUMBER;
    l_resp_id      NUMBER;
    l_resp_appl_id NUMBER;
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    --Commented for CHG0039163 on 19 Feb 2017 by Yuval.Tal
    /*  x_err_code := '0';
    x_err_msg  := '';
    l_user_id  := fnd_profile.value('XXWSH_SEND_SHIPP_DOCS_USER');
    
    SELECT fr.responsibility_id,
           fr.application_id
    INTO   l_resp_id,
           l_resp_appl_id
    FROM   fnd_responsibility fr
    WHERE  fr.responsibility_id =
           fnd_profile.value('XXWSH_SEND_SHIPP_DOCS_RESP');
    
    fnd_global.apps_initialize(user_id => l_user_id, resp_id => l_resp_id, resp_appl_id => l_resp_appl_id);
    
    l_request_id := fnd_request.submit_request(application => 'XXOBJT', --
                                               program => 'XXWSH_SEND_SHIPPING_DOCS', --
                                               argument1 => p_delivery_id -- Delivery_Id
                                               );
    
    COMMIT;
    dbms_output.put_line(l_request_id);
    IF l_request_id = 0 THEN
      l_err_msg := 'Error submitting shipping docs';
    END IF;
    dbms_output.put_line(l_err_msg);*/
  
    --Added for CHG0039163 on 19 Feb 2017 by Yuval.Tal
    submit_document_set(p_set_code    => 'GTMS',
        p_delivery_name => p_delivery_name,--p_delivery_id,  -- CHG0041294 on 20/02/2018 for delivery id to name change
        x_err_code    => x_err_code,
        x_err_msg     => x_err_msg);
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      x_err_code := '1';
      x_err_msg  := 'Unexpected error in xxwsh_gtms_send_ship_docs_pkg.submit_shipping_docs: ' ||
            SQLERRM;
  END submit_shipping_docs;

  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               submit_document_set
  --  create by:          Lingaraj Sarangi
  --  creation date:      19/02/2017
  --  Purpose :           CHG0039163 - Auto submit Shipping docs
  --                      Submit the Concurrent Program 'XXCUSTDOCSUB' to Submit a Set of Programs
  ----------------------------------------------------------------------
  --  ver   date          name               desc
  --  1.0   19/02/2017    Lingaraj Sarangi   Initial Build  
  ----------------------------------------------------------------------
  PROCEDURE submit_document_set(p_set_code    IN VARCHAR2 DEFAULT 'GTMS',
                --p_delivery_id IN VARCHAR2,    -- CHG0041294 on 20/02/2018 for delivery id to name change
                p_delivery_name        IN VARCHAR2,
                x_err_code    OUT NUMBER,
                x_err_msg     OUT VARCHAR2) IS
    l_user_id      NUMBER;
    l_resp_id      NUMBER;
    l_resp_appl_id NUMBER;
    l_request_id   NUMBER;
    l_org_id       NUMBER;
  BEGIN
    x_err_code := 0;
    --Apps Initiliaze if Submitted from Service                                      
    IF fnd_global.user_id = -1 THEN
      l_user_id := fnd_profile.value('XXWSH_SEND_SHIPP_DOCS_USER');
      BEGIN
        SELECT fr.responsibility_id,
       fr.application_id
        INTO   l_resp_id,
       l_resp_appl_id
        FROM   fnd_responsibility fr
        WHERE  fr.responsibility_id =
       fnd_profile.value('XXWSH_SEND_SHIPP_DOCS_RESP');
      
        fnd_global.apps_initialize(user_id      => l_user_id,
                   resp_id      => l_resp_id,
                   resp_appl_id => l_resp_appl_id);
      
      EXCEPTION
        WHEN OTHERS THEN
          x_err_code := 1;
          x_err_msg  := 'Error in setting up Apps Initiliaze.Error :' ||
        SQLERRM;
          RETURN;
      END;
    END IF;
  
    --Get Org ID from the Delivery Number
    BEGIN
      SELECT odd.operating_unit
      INTO   l_org_id
      FROM   wsh_new_deliveries           wnd,
     org_organization_definitions odd
      WHERE  1 = 1
      AND    wnd.organization_id = odd.organization_id
      AND    wnd.delivery_id = xxinv_trx_in_pkg.get_delivery_id(p_delivery_name);--p_delivery_id; -- CHG0041294 on 20/02/2018 for delivery id to name change
    EXCEPTION
      WHEN OTHERS THEN
        x_err_code := 1;
        x_err_msg  := 'ORG_ID not Found for the Delivery :' || p_delivery_name;
              --p_delivery_id; -- CHG0041294 on 20/02/2018 for delivery id to name change
        RETURN;
    END;
    --Submit Concurrent Program
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                       program     => 'XXCUSTDOCSUB',
                       start_time  => SYSDATE,
                       argument1   => p_set_code,
                       argument2   => l_org_id,
                       argument3   => p_delivery_name--p_delivery_id    -- CHG0041294 on 20/02/2018 for delivery id to name change
                       );
  
    COMMIT;
  
    IF l_request_id = 0 THEN
      x_err_code := 1;
      x_err_msg  := 'Error submitting shipping docs';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := SQLERRM;
  END submit_document_set;

END xxwsh_gtms_send_ship_docs_pkg;
/