CREATE OR REPLACE PACKAGE BODY xxwar_receipts_pkg
AS
  /*****************************************************************************************
  * $Header$                                                                    		   *
  * Program Name : XXWAR_RECEIPTS_PKG.pkb                                       		   *
  * Language     : PL/SQL                                                       		   *
  * Description  : This package has the following procedures                    		   *
  *                  1. submit_lockbox                                          		   *
  *                     Submits the Lockbox Program in new transmission mode    		   *
  *                     with submit import ; submit validation and submit       		   *
  *                     post quick cash as "YES"                                		   *
  *                  2. conc_stat_and_adj_creation                              		   *
  *                     Get the Phase sand Status of the concurrent request     		   *
  *                     and call the private procedure create_adjustment, if    		   *
  *                     payment method is ACH-CTX                               		   *
  *                                                                             		   *
  *                                                                             		   *
  * History      :                                                              		   *
  *                                                                             		   *
  * WHO            VERSION   WHAT                                       	 WHEN          *
  *--------------- ------- -------------------------------------------       ------------  *
  * Raguraman K    1.0   	Original version.                        		12-May-2008    *
  * Raguraman K    1.1   	Modified.xxwar_lbx_derive_rcpt_num                        	   *
  *                   		to derive the receipt number for LBX                      	   *
  * Raguraman K    1.2   	Addition function to derive receipt                            *
  *                   		number for LBX, ACH and DTD                                    *
  * Rohith A       1.3   	Added function get_error_message_pvt     		05-jan-2010    *
  * Rohith A       1.4   	Enhancement#58718:Added new procedure    		08-Sep-2010    *
  *                   		to receipt batch report                                   	   *
  *                   		SP28 field is used as transmission NAME                   	   *
  *                   		for DTD receipts.                                              *
  * Kalyan G       1.5   	Issue:63993: Create receipt for DTD      		13-Jan-2011    *
  *                   		payment records with missing SI record                    	   *
  * Kalyan G       1.6   	Issue#64649: Added new function          		10-Feb-2011    *
  *                   		xxwar_validate_customer                                   	   *
  * Kalyan G       1.7   	Issue:65174: Create unidentified receipt 		09-Mar-2011    *
  *                   		if invoice number in flat file doesnt exists              	   *
  *                   		in ERP FOR WIR,ACH AND LBX                                	   *
  * Kalyan G       1.8   	Enhancement#65531: SI30 check number used 		24-Mar-2011    *
  *                   		AS receipt number instead of SI24                         	   *
  * Kalyan G       1.9    	Enhancement#66480:Create ACH receipt      		11_may_2011    *
  *                   		using last 12 characters of trace number                  	   *
  * Mahidhar S     2.0    	Issue-63484 -Oracle Patch added new parameter 	10-jan-2011    *
  *                    		unearned discount. Added new profile option         		   *
  *                     	value as a parameter  to new conc prog.                        *
  * Mahidhar S     2.1   	Issue#TCS9:Unable to generate WIR receipts 		4-June-2012    *
  *					  		batches due to Invoice Numbers                            	   *
  *					  		longer than 20 characters.                                	   *
  * Sudheer 	   2.2	  	Enhancement#ENH72, Patch #8443 ACH Non-CTX  	05-Mar-2013    *
  *                    		Receipts  for Identifying Customer Number                      *
  *                         based on Originator Company ID                                 *
  ******************************************************************************************
  * Stratasys - Version Control
  ******************************************************************************************
  * Venu Kandi     3.0      CR 1312 - Tech Log 209 - Initial Creation              24-Feb-2014   * 
  *                         Bug fixes, Changes to WF Package                                     *
  *****************************************************************************************
  */

lc_cust_valid_msg VARCHAR2 (500) := NULL; -- Added for #ENH72

PROCEDURE print_out(p_print_msg VARCHAR2)
IS
BEGIN
  FND_FILE.PUT_LINE(FND_FILE.OUTPUT,p_print_msg);
END;

PROCEDURE print_log  (p_print_msg VARCHAR2)
IS
BEGIN
FND_FILE.PUT_LINE(FND_FILE.LOG,p_print_msg);
END;

PROCEDURE get_emailids(p_org_name IN VARCHAR2
                       ,p_email_ids OUT VARCHAR2
                       ,p_error_msg OUT VARCHAR2)
IS
lc_email_ids  VARCHAR2(3200);
BEGIN
   SELECT FLV.description
     INTO lc_email_ids
     FROM fnd_lookup_values FLV,
          fnd_application FA
    WHERE lookup_type = 'XXWAR_EMAIL_USERS'
      AND enabled_flag = 'Y'
      AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(start_date_active,SYSDATE)) AND TRUNC(NVL(end_date_active, SYSDATE ) )
      AND LANGUAGE = USERENV('LANG')
      AND FLV.view_application_id = FA.application_id
      AND FA.application_short_name = 'AR'
      AND FLV.meaning = p_org_name;
	  p_email_ids := lc_email_ids;
	  print_log('emailids fetched '||lc_email_ids);
EXCEPTION
   WHEN NO_DATA_FOUND THEN
        print_log('emailids are not defined in the lookup for the organization'||p_org_name );
        p_email_ids := NULL;
        --p_error_msg := 'emailids are not defined in the lookup for the organization'||p_org_name;
   WHEN others THEN
        print_log('Unhandled exception when fetching emailids from the lookup: '||SQLERRM);
        p_email_ids := NULL;
	    --p_error_msg := 'Unhandled exception when fetching emailids from the lookup for Organization : '||p_org_name ||' '||SQLERRM;
END get_emailids;

FUNCTION get_error_message_pvt(p_msg_name IN VARCHAR2
                               ,p_tokens IN VARCHAR2
                               ,p_token_values IN VARCHAR2
                               )
RETURN VARCHAR2
IS
  ln_token_pos                 NUMBER             :=1;
  lc_msg                       VARCHAR2(1000);
  ln_value_pos                 NUMBER            :=1;
  lc_token                     VARCHAR2(1000);
  lc_value                     VARCHAR2(1000);
  lc_tokens_string             VARCHAR2(1000);
  lc_token_values_str          VARCHAR2(1000);
BEGIN
     lc_tokens_string := p_tokens;
     lc_token_values_str := p_token_values;
     FND_MESSAGE.SET_NAME('AR',p_msg_name);
     IF(LENGTH(lc_tokens_string) > 0 ) THEN
      WHILE ln_token_pos > 0 LOOP
           ln_token_pos := InStr(lc_tokens_string,'|');
           IF ln_token_pos > 0 THEN
              lc_token := TRIM (substr (lc_tokens_string,1, ln_token_pos-1));
              lc_tokens_string := SUBSTR(lc_tokens_string, ln_token_pos+1);
           ELSE
              lc_token := TRIM(lc_tokens_string);
           END IF;
           ln_value_pos := InStr(lc_token_values_str,'|');
           IF ln_value_pos > 0 THEN
              lc_value := TRIM (substr (lc_token_values_str,1, ln_value_pos-1));
              lc_token_values_str := SUBSTR(lc_token_values_str, ln_value_pos+1);
            ELSE
              lc_value := TRIM(lc_token_values_str);
            END IF;
            FND_MESSAGE.SET_TOKEN(lc_token,lc_value);
      EXIT  WHEN ln_token_pos = 0;
      END LOOP;
     END IF;
   lc_msg := FND_MESSAGE.GET;
   RETURN lc_msg;
EXCEPTION
    WHEN OTHERS THEN
         print_log('Error occured while fetching the error message :'|| SQLERRM);
         RETURN NULL;
END get_error_message_pvt;

PROCEDURE submit_lockbox
  (
    p_user_name                IN VARCHAR2,
    p_resp_name                IN VARCHAR2,
    p_batch_hdr_id             IN VARCHAR2,
    p_lockbox_file_id          IN VARCHAR2,
    p_datafile_path_name       IN VARCHAR2,
    p_controlfile_name         IN VARCHAR2,
    p_transmission_format_name IN VARCHAR2,
    p_lockbox_number           IN VARCHAR2,
    p_organization_name        IN VARCHAR2,
    p_data_fetch_flag          IN VARCHAR2,
    p_auto_adjustments_flag    IN VARCHAR2,
    p_request_id               IN OUT NUMBER,
    p_process_status           IN OUT NUMBER,
    p_parent_request_id        OUT NUMBER,
    p_error_string             OUT VARCHAR2,
    p_error_type               OUT VARCHAR2,
    p_error_count              OUT NUMBER,
    p_transmission_name        OUT VARCHAR2,
    p_parent_logfile           OUT VARCHAR2,
    p_logfile                  OUT VARCHAR2,
    p_outfile                  OUT VARCHAR2,
	p_email_ids                OUT VARCHAR2)
IS
  /*Variables list for Apps Iniitalize*/
  lc_user_id                      fnd_user.user_id%TYPE;
  lc_resp_id                      fnd_responsibility_tl.responsibility_id%TYPE;
  lc_resp_appl_id                 fnd_responsibility_tl.application_id%TYPE;
  lc_request_id                   NUMBER;
  lc_apps_init_flag               VARCHAR2 (1) := 'N';
  lc_submit_conc_prog_flag        VARCHAR2 (1) ;
  lc_error_count                  NUMBER := 0;
  lc_error_string                 VARCHAR2 (32000) ;
  lc_conc_req_id                  fnd_concurrent_requests.request_id%TYPE;
  lc_org_id                       ar_system_parameters.org_id%TYPE;
  lc_trans_format_id              ar_transmission_formats.transmission_format_id%TYPE;
  lc_lockbox_id                   ar_lockboxes.lockbox_id%TYPE;
  lc_transmission_name            ar_transmissions.transmission_name%TYPE;
  lc_logfile                      fnd_concurrent_requests.logfile_name%TYPE;
  lc_outfile                      fnd_concurrent_requests.outfile_name%TYPE;
  lc_parent_logfile               fnd_concurrent_requests.logfile_name%TYPE;
  lc_exception_string             VARCHAR2 (32000) ;
  lc_security_policy              VARCHAR2 (30) ;
  lc_conc_complete_flag           VARCHAR2 (1) := 'N';
  lc_phase                        VARCHAR2 (50) ;
  lc_status                       VARCHAR2 (50) ;
  lc_devphase                     VARCHAR2 (50) := 'NO_PHASE';
  lc_devstatus                    VARCHAR2 (50) := NULL;
  lc_message                      VARCHAR2 (4000) ;
  lc_conc_status_msg              VARCHAR2 (50) ;
  lc_prog_call_status             BOOLEAN;
  lc_process_status xxwar_trfmd_batch_stg.process_status%TYPE;
  lc_request_id1 xxwar_trfmd_batch_stg.request_id%TYPE;
  lc_latest_request_id xxwar_trfmd_batch_stg.latest_request_id%TYPE;
  lc_adjustment_creation_flag xxwar_trfmd_batch_stg.adjustment_creation_flag%TYPE;
  lc_data_fetch_flag xxwar_trfmd_batch_stg.data_fetch_flag%TYPE;
  lc_error_msg xxwar_trfmd_batch_stg.error_msg%TYPE;
  lc_error_type xxwar_trfmd_batch_stg.error_type%TYPE;
  lc_phace_code VARCHAR2(2);
  lc_status_code VARCHAR2(2);
  lc_email_ids   VARCHAR2(32000) := NULL;
  WF_APPS_INITIALIZATION_ERROR EXCEPTION;

  CURSOR c_user_id (p_user_name IN VARCHAR2)
  IS
     SELECT user_id
       FROM fnd_user fu
      WHERE UPPER (user_name) = UPPER (p_user_name)
        AND TRUNC (SYSDATE) BETWEEN fu.start_date AND NVL (fu.end_date, TRUNC (SYSDATE)) ;

  CURSOR c_resp_appl_id (p_resp_name IN VARCHAR2)
  IS
     SELECT ftl.responsibility_id,
            ftl.application_id
       FROM fnd_responsibility_tl ftl,
            fnd_responsibility fr
      WHERE UPPER (responsibility_name) LIKE UPPER (p_resp_name)
        AND ftl.responsibility_id = fr.responsibility_id
        AND TRUNC (SYSDATE) BETWEEN fr.start_date AND NVL (fr.end_date, TRUNC (SYSDATE))
        AND ftl.LANGUAGE = userenv('LANG'); -- Added by Srinandini(SA) on 10-SEP-09

  CURSOR c_org_id (p_org_id NUMBER)
  IS
     SELECT org_id
       FROM ar_system_parameters
      WHERE org_id = p_org_id;

  CURSOR c_transmission_format_id (p_trans_format_name IN VARCHAR2)
  IS
     SELECT transmission_format_id
       FROM ar_transmission_formats
      WHERE UPPER (format_name) = UPPER (p_trans_format_name) ;

BEGIN
   /****************************************************************************
  --         Get Email ID's
  ****************************************************************************/
    xxwar_receipts_pkg.get_emailids(p_org_name  => p_organization_name,
                                    p_email_ids => lc_email_ids ,
                                    p_error_msg => lc_error_string);
    BEGIN
     lc_email_ids := substr(rtrim(lc_email_ids,','),1,249);
     UPDATE xxwar_trfmd_batch_stg

       SET org_mail_ids  = lc_email_ids
           ,last_update_date = SYSDATE
           ,last_updated_by = fnd_global.user_id
           ,last_update_login = fnd_global.login_id
     WHERE lbx_file_id = p_lockbox_file_id;
    EXCEPTION
     WHEN OTHERS THEN
          print_log('Unhandled wxception whlie updating xxwar_trfmd_batch_stg '||SQLERRM);
    END;
  /****************************************************************************
  --         Get User ID
  ****************************************************************************/
  BEGIN
    OPEN c_user_id (p_user_name) ;
    FETCH c_user_id INTO lc_user_id;
    IF c_user_id%NOTFOUND THEN
      lc_error_count := lc_error_count + 1;
		lc_error_string := CONCAT (lc_error_string, '|'|| 'Error '
                                 || lc_error_count
								 || ': '
                                 || get_error_message_pvt('XXWAR_ERROR_MESSAGES_001','USER_NAME',p_user_name)) ;
    END IF;
    CLOSE c_user_id;
  END;
  /****************************************************************************
  --         Get Responsibility ID and Application ID
  *************************************************** *************************/
  BEGIN
    OPEN c_resp_appl_id (p_resp_name) ;
    FETCH c_resp_appl_id INTO lc_resp_id, lc_resp_appl_id;
    IF c_resp_appl_id%NOTFOUND THEN
      lc_error_count := lc_error_count + 1;
      lc_error_string := CONCAT (lc_error_string, '|'|| 'Error '
                                 || lc_error_count
								 || ': '
                                 || get_error_message_pvt('XXWAR_ERROR_MESSAGES_002','RESP_NAME',p_resp_name)) ;
    END IF;
    CLOSE c_resp_appl_id;
  END;
  IF (lc_resp_id IS NOT NULL)
    AND (lc_resp_appl_id IS NOT NULL)
    AND (lc_user_id IS NOT NULL) THEN
    fnd_global.apps_initialize (user_id          => lc_user_id,
                                resp_id          => lc_resp_id,
                                resp_appl_id     => lc_resp_appl_id) ;
    mo_global.init ('AR') ;
    lc_apps_init_flag := 'Y';
  ELSE
    RAISE WF_APPS_INITIALIZATION_ERROR;
  END IF;
  /* Added by Ramachandra */
  IF lc_apps_init_flag = 'Y' THEN


    lc_request_id := FND_REQUEST.SUBMIT_REQUEST (application  => xxwar_cust_appl.gc_appl_short_name
                                               , program      => 'XXWAR_LOCKBOX_PVT'
                                               , description  => NULL
                                               , start_time   => NULL
                                               , sub_request  => FALSE
                                               , argument1    => p_batch_hdr_id
                                               , argument2    => p_lockbox_file_id
                                               , argument3    => p_datafile_path_name
                                               , argument4    => p_controlfile_name
                                               , argument5    => p_transmission_format_name
                                               , argument6    => p_lockbox_number
                                               , argument7    => p_organization_name
                                               , argument8    => p_data_fetch_flag
                                               , argument9    => p_auto_adjustments_flag
                                               , argument10   => p_process_status
                                               , argument11   => p_request_id) ;
                                     --   COMMIT;
  END IF;
  IF lc_request_id <> 0 THEN
  COMMIT;
    LOOP
    /*  lc_prog_call_status := fnd_concurrent.wait_for_request ( request_id => lc_conc_req_id
                                                             , interval   => 3
                                                             , max_wait   => 10
                                                             , phase      => lc_phase
                                                             , status     => lc_status
                                                             , dev_phase  => lc_devphase
                                                             , dev_status => lc_devstatus
                                                             , MESSAGE    => lc_message
                                                           ) ;
      EXIT
         WHEN lc_devphase IN ('INACTIVE', 'COMPLETE');*/
                     SELECT phase_code
                           ,status_code
                       INTO lc_phace_code
                           ,lc_status_code
                       FROM fnd_concurrent_requests
                      WHERE request_id = lc_request_id;

        EXIT   WHEN lc_phace_code in ('I','C');
    END LOOP;
      IF lc_phace_code = 'C' THEN
        BEGIN
            SELECT process_status,
                   request_id,
                   latest_request_id,
                   transmission_name,
                   adjustment_creation_flag,
                   data_fetch_flag,
                   error_msg,
                   error_type
              INTO lc_process_status,
                   lc_request_id1,
                   lc_latest_request_id,
                   lc_transmission_name,
                   lc_adjustment_creation_flag,
                   lc_data_fetch_flag,
                   lc_error_msg,
                   lc_error_type
              FROM  xxwar_trfmd_batch_stg
             WHERE  lbx_file_id = p_lockbox_file_id;
        EXCEPTION
           WHEN NO_DATA_FOUND THEN
               lc_error_count := lc_error_count + 1;
               lc_error_string := CONCAT (lc_error_string, 'Error : '
                                 || lc_error_count
								 || ' - '
                                 || get_error_message_pvt('XXWAR_ERROR_MESSAGES_027'
                                                          ,'FILE_ID'
                                                          ,p_lockbox_file_id));
                                 --No record available in the xxwar_trfmd_batch_stg table with lockbox file ID:
           WHEN others THEN
               lc_error_count := lc_error_count + 1;
               lc_error_string := CONCAT (lc_error_string, 'Error : '
                                 || lc_error_count
                                 || ' - '
								 || get_error_message_pvt('XXWAR_ERROR_MESSAGES_028'
                                                          ,'FILE_ID|SQL_ERRM'
                                                          ,p_lockbox_file_id||'|'||SQLERRM));
                                 --Unhandled excepion while fetching the process status from the batch trfmd tables with lockbox file ID:
        END ;
        BEGIN
           SELECT logfile_name,
                  outfile_name
             INTO lc_logfile,
                  lc_outfile
             FROM fnd_concurrent_requests
            WHERE request_id = lc_latest_request_id;


        EXCEPTION
          WHEN NO_DATA_FOUND THEN
              lc_logfile := NULL;
              lc_outfile := NULL;
              lc_error_count := lc_error_count + 1;
              lc_error_string := CONCAT (lc_error_string, 'Error : '
                                 || lc_error_count
                                 || ' - '
                                 ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_029'
                                                         ,'REQUEST_ID'
                                                         ,g_lbx_request_id) );
								 --No Out and Log where generated for standard process lockbox request ID:
          WHEN others THEN
              lc_logfile := NULL;
              lc_outfile := NULL;
              lc_error_count := lc_error_count + 1;
              lc_error_string := CONCAT (lc_error_string, 'Error : '
                                 || lc_error_count
                                 || ' - '
								 ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_030'
                                                         ,'REQUEST_ID'
                                                         ,g_lbx_request_id));
                                 --Unhandled Exception to fetch path to Log and Out file of standard process lockbox request ID
        END ;

        BEGIN
           SELECT logfile_name
             INTO lc_parent_logfile
             FROM fnd_concurrent_requests
            WHERE request_id = lc_request_id;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
              lc_parent_logfile := NULL;
              lc_error_count := lc_error_count + 1;
              lc_error_string := CONCAT (lc_error_string, 'Error : '
                                 || lc_error_count
                                 || ' - '
                                 || get_error_message_pvt('XXWAR_ERROR_MESSAGES_031'
                                                         ,'REQUEST_ID'
                                                         ,lc_request_id));
                                 --No Log where generated for submit lockbox request ID:
          WHEN others THEN
              lc_parent_logfile := NULL;
              lc_error_count := lc_error_count + 1;
              lc_error_string := CONCAT (lc_error_string, 'Error : '
                                 || lc_error_count
                                 || ' - '
								 || get_error_message_pvt('XXWAR_ERROR_MESSAGES_032'
                                                         ,'REQUEST_ID'
                                                         ,g_lbx_request_id));
								 --Unhandled Exception to fetch path to Log file of submit lockbox request ID
        END ;


         -- IF ( (lc_phase = 'Completed' AND lc_status = 'Normal') OR (lc_phase = 'Completed' AND lc_status = 'Warning')) THEN
          IF lc_phace_code = 'C' AND lc_status_code = 'C' THEN
             p_request_id            := lc_latest_request_id;
             p_process_status        := lc_process_status;
             p_parent_request_id     := lc_request_id;
             p_error_string          := lc_error_msg;
             p_error_type            := lc_error_type;
             p_error_count           := lc_error_count;
             p_transmission_name     := lc_transmission_name;
             p_parent_logfile        := lc_parent_logfile;
             p_logfile               := lc_logfile;
             p_outfile               := lc_outfile;
			 p_email_ids             := lc_email_ids;

             UPDATE xxwar_trfmd_batch_stg
                SET parent_request_id = lc_request_id             ,
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
          ELSE
             p_request_id            := lc_latest_request_id;
             p_process_status        := 2;
             p_parent_request_id     := lc_request_id;
             p_error_string          := get_error_message_pvt('XXWAR_ERROR_MESSAGES_033','REQUEST_ID',lc_request_id);
             p_error_type            := 'RCPT_CREATION_ERROR';
             p_error_count           := lc_error_count;
             p_transmission_name     := lc_transmission_name;
             p_parent_logfile        := lc_parent_logfile;
             p_logfile               := lc_logfile;
             p_outfile               := lc_outfile;
			 p_email_ids             := lc_email_ids;

             UPDATE xxwar_trfmd_batch_stg
                SET process_status = 2           ,
                    parent_request_id = lc_request_id             ,
                    error_msg = p_error_string  ,
                    error_type = 'RCPT_CREATION_ERROR',
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
          END IF;
      ELSE
         p_request_id            := lc_latest_request_id;
         p_process_status        := 3;
         p_parent_request_id     := lc_request_id;
         p_error_string          := get_error_message_pvt('XXWAR_ERROR_MESSAGES_034'
                                                         ,'REQUEST_ID'
                                                         ,lc_request_id);
         p_error_type            := 'RCPT_CREATION_ERROR';
         p_error_count           := lc_error_count;
         p_transmission_name     := lc_transmission_name;
         p_parent_logfile        := lc_parent_logfile;
         p_logfile               := lc_logfile;
         p_outfile               := lc_outfile;
		 p_email_ids             := lc_email_ids;

             UPDATE xxwar_trfmd_batch_stg
                SET process_status = 3           ,
                    parent_request_id = lc_request_id             ,
                    error_msg =  p_error_string            ,
                    error_type = 'RCPT_CREATION_ERROR',
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
      END IF;

  ELSE
             p_request_id            := lc_latest_request_id;
             p_process_status        := 2;
             p_parent_request_id     := 0;
             p_error_string          := get_error_message_pvt('XXWAR_ERROR_MESSAGES_035','','');
             p_error_type            := 'RCPT_CREATION_ERROR';
             p_error_count           := lc_error_count;
             p_transmission_name     := lc_transmission_name;
             p_parent_logfile        := lc_parent_logfile;
             p_logfile               := lc_logfile;
             p_outfile               := lc_outfile;
			 p_email_ids             := lc_email_ids;
             UPDATE xxwar_trfmd_batch_stg
                SET process_status = 2           ,
                    parent_request_id = 0             ,
                    error_msg = p_error_string  ,
                    error_type = 'RCPT_CREATION_ERROR',
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
  END IF; /*--ln_request_id <> 0*/
EXCEPTION
WHEN WF_APPS_INITIALIZATION_ERROR THEN
             p_request_id            := lc_latest_request_id;
             p_process_status        := 2;
             p_parent_request_id     := 0;
             p_error_string          := get_error_message_pvt('XXWAR_ERROR_MESSAGES_036'
                                                              ,''
                                                              ,'')||lc_error_string;
             p_error_type            := 'INITIALIZATION_ERROR';
             p_error_count           := lc_error_count;
             p_transmission_name     := lc_transmission_name;
             p_parent_logfile        := lc_parent_logfile;
             p_logfile               := lc_logfile;
             p_outfile               := lc_outfile;
			 p_email_ids             := lc_email_ids;
             UPDATE xxwar_trfmd_batch_stg
                SET process_status = 2           ,
                    parent_request_id = 0             ,
                    error_msg = p_error_string  ,
                    error_type = 'INITIALIZATION_ERROR',
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;

WHEN OTHERS THEN
             p_request_id            := lc_latest_request_id;
             p_process_status        := 2;
             p_parent_request_id     := 0;
             p_error_string          := get_error_message_pvt('XXWAR_ERROR_MESSAGES_037'
                                                              ,'SQL_ERRM'
                                                              ,SQLERRM) ||lc_error_string;
             p_error_type            := 'RCPT_CREATION_ERROR';
             p_error_count           := lc_error_count;
             p_transmission_name     := lc_transmission_name;
             p_parent_logfile        := lc_parent_logfile;
             p_logfile               := lc_logfile;
             p_outfile               := lc_outfile;
			 p_email_ids             := lc_email_ids;
             UPDATE xxwar_trfmd_batch_stg
                SET process_status = 2           ,
                    parent_request_id = 0             ,
                    error_msg =  p_error_string ,
                    error_type = 'RCPT_CREATION_ERROR',
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
END submit_lockbox;

PROCEDURE load_custom_data
  (
    p_lbx_file_id IN VARCHAR2,
	p_payment_rec_id IN NUMBER,
	p_inv_trfmd_rec_id IN NUMBER,
    x_return_status OUT VARCHAR2,
    x_error_msg OUT VARCHAR2)
IS
TYPE lr_payment_rec
IS
  RECORD
  (
    batch_hdr_id xxwar_trfmd_pymt_stg.batch_hdr_id%TYPE,
    lbx_file_id xxwar_trfmd_pymt_stg.lbx_file_id%TYPE,
    record_type xxwar_trfmd_pymt_stg.record_type%TYPE,
    payment_type xxwar_trfmd_pymt_stg.payment_type%TYPE,
    credit_debit xxwar_trfmd_pymt_stg.credit_debit%TYPE,
    payment_amount xxwar_trfmd_pymt_stg.payment_amount%TYPE,
    destination_rtn xxwar_trfmd_pymt_stg.destination_rtn%TYPE,
    destination_account_no xxwar_trfmd_pymt_stg.destination_account_no%TYPE,
    originator_rtn xxwar_trfmd_pymt_stg.originator_rtn%TYPE,
    originator_account_no xxwar_trfmd_pymt_stg.originator_account_no%TYPE,
    effective_date xxwar_trfmd_pymt_stg.effective_date%TYPE,
    payment_rec_id xxwar_trfmd_pymt_stg.payment_rec_id%TYPE,
    supplemental_payment_field1 xxwar_trfmd_pymt_stg.supplemental_payment_field1%TYPE,
    supplemental_payment_field2 xxwar_trfmd_pymt_stg.supplemental_payment_field2%TYPE,
    supplemental_payment_field3 xxwar_trfmd_pymt_stg.supplemental_payment_field3%TYPE,
    supplemental_payment_field4 xxwar_trfmd_pymt_stg.supplemental_payment_field4%TYPE,
    supplemental_payment_field5 xxwar_trfmd_pymt_stg.supplemental_payment_field5%TYPE,
    supplemental_payment_field6 xxwar_trfmd_pymt_stg.supplemental_payment_field6%TYPE,
    supplemental_payment_field7 xxwar_trfmd_pymt_stg.supplemental_payment_field7%TYPE,
    supplemental_payment_field8 xxwar_trfmd_pymt_stg.supplemental_payment_field8%TYPE,
    supplemental_payment_field9 xxwar_trfmd_pymt_stg.supplemental_payment_field9%TYPE,
    supplemental_payment_field10 xxwar_trfmd_pymt_stg.supplemental_payment_field10%TYPE,
    supplemental_payment_field11 xxwar_trfmd_pymt_stg.supplemental_payment_field11%TYPE,
    supplemental_payment_field12 xxwar_trfmd_pymt_stg.supplemental_payment_field12%TYPE,
    supplemental_payment_field13 xxwar_trfmd_pymt_stg.supplemental_payment_field13%TYPE,
    supplemental_payment_field14 xxwar_trfmd_pymt_stg.supplemental_payment_field14%TYPE,
    supplemental_payment_field15 xxwar_trfmd_pymt_stg.supplemental_payment_field15%TYPE,
    supplemental_payment_field16 xxwar_trfmd_pymt_stg.supplemental_payment_field16%TYPE,
    supplemental_payment_field17 xxwar_trfmd_pymt_stg.supplemental_payment_field17%TYPE,
    supplemental_payment_field18 xxwar_trfmd_pymt_stg.supplemental_payment_field18%TYPE,
    supplemental_payment_field19 xxwar_trfmd_pymt_stg.supplemental_payment_field19%TYPE,
    supplemental_payment_field20 xxwar_trfmd_pymt_stg.supplemental_payment_field20%TYPE,
    supplemental_payment_field21 xxwar_trfmd_pymt_stg.supplemental_payment_field21%TYPE,
    supplemental_payment_field22 xxwar_trfmd_pymt_stg.supplemental_payment_field22%TYPE,
    supplemental_payment_field23 xxwar_trfmd_pymt_stg.supplemental_payment_field23%TYPE,
    supplemental_payment_field24 xxwar_trfmd_pymt_stg.supplemental_payment_field24%TYPE,
    supplemental_payment_field25 xxwar_trfmd_pymt_stg.supplemental_payment_field25%TYPE,
    supplemental_payment_field26 xxwar_trfmd_pymt_stg.supplemental_payment_field26%TYPE,
    supplemental_payment_field27 xxwar_trfmd_pymt_stg.supplemental_payment_field27%TYPE,
    supplemental_payment_field28 xxwar_trfmd_pymt_stg.supplemental_payment_field28%TYPE,
    supplemental_payment_field29 xxwar_trfmd_pymt_stg.supplemental_payment_field29%TYPE,
    supplemental_payment_field30 xxwar_trfmd_pymt_stg.supplemental_payment_field30%TYPE,
    supplemental_payment_field31 xxwar_trfmd_pymt_stg.supplemental_payment_field31%TYPE,
    supplemental_payment_field32 xxwar_trfmd_pymt_stg.supplemental_payment_field32%TYPE,
    supplemental_payment_field33 xxwar_trfmd_pymt_stg.supplemental_payment_field33%TYPE,
    supplemental_payment_field34 xxwar_trfmd_pymt_stg.supplemental_payment_field34%TYPE,
    supplemental_payment_field35 xxwar_trfmd_pymt_stg.supplemental_payment_field35%TYPE,
    supplemental_payment_field36 xxwar_trfmd_pymt_stg.supplemental_payment_field36%TYPE,
    supplemental_payment_field37 xxwar_trfmd_pymt_stg.supplemental_payment_field37%TYPE,
    supplemental_payment_field38 xxwar_trfmd_pymt_stg.supplemental_payment_field38%TYPE,
    supplemental_payment_field39 xxwar_trfmd_pymt_stg.supplemental_payment_field39%TYPE,
    supplemental_payment_field40 xxwar_trfmd_pymt_stg.supplemental_payment_field40%TYPE,
    supplemental_payment_field41 xxwar_trfmd_pymt_stg.supplemental_payment_field41%TYPE,
    supplemental_payment_field42 xxwar_trfmd_pymt_stg.supplemental_payment_field42%TYPE,
    supplemental_payment_field43 xxwar_trfmd_pymt_stg.supplemental_payment_field43%TYPE,
    supplemental_payment_field44 xxwar_trfmd_pymt_stg.supplemental_payment_field44%TYPE,
    supplemental_payment_field45 xxwar_trfmd_pymt_stg.supplemental_payment_field45%TYPE,
    supplemental_payment_field46 xxwar_trfmd_pymt_stg.supplemental_payment_field46%TYPE,
    supplemental_payment_field47 xxwar_trfmd_pymt_stg.supplemental_payment_field47%TYPE,
    supplemental_payment_field48 xxwar_trfmd_pymt_stg.supplemental_payment_field48%TYPE,
    supplemental_payment_field49 xxwar_trfmd_pymt_stg.supplemental_payment_field49%TYPE,
    supplemental_payment_field50 xxwar_trfmd_pymt_stg.supplemental_payment_field50%TYPE,
    created_by xxwar_trfmd_pymt_stg.created_by%TYPE,
    creation_date xxwar_trfmd_pymt_stg.creation_date%TYPE,
    last_update_date xxwar_trfmd_pymt_stg.last_update_date%TYPE,
    last_updated_by xxwar_trfmd_pymt_stg.last_updated_by%TYPE,
    last_update_login xxwar_trfmd_pymt_stg.last_update_login%TYPE,
    file_number xxwar_file_stg.file_number%TYPE,
    file_date xxwar_file_stg.file_date%TYPE) ;
TYPE lt_payment_tbl_type
IS
  TABLE OF lr_payment_rec;
  lt_pymt_tbl lt_payment_tbl_type;
TYPE lr_rmtr_rec
IS
  RECORD
  (
    record_type xxwar_trfmd_rmtr_iden_stg.record_type%TYPE,
    remitter_identity_field1 xxwar_trfmd_rmtr_iden_stg.remitter_identity_field1%TYPE,
    remitter_identity_field2 xxwar_trfmd_rmtr_iden_stg.remitter_identity_field2%TYPE,
    remitter_identity_field3 xxwar_trfmd_rmtr_iden_stg.remitter_identity_field3%TYPE,
    remitter_identity_field4 xxwar_trfmd_rmtr_iden_stg.remitter_identity_field4%TYPE,
    remitter_identity_field5 xxwar_trfmd_rmtr_iden_stg.remitter_identity_field5%TYPE,
    remitter_identity_field6 xxwar_trfmd_rmtr_iden_stg.remitter_identity_field6%TYPE,
    remitter_identity_field7 xxwar_trfmd_rmtr_iden_stg.remitter_identity_field7%TYPE,
    remitter_identity_field8 xxwar_trfmd_rmtr_iden_stg.remitter_identity_field8%TYPE,
    remitter_identity_field9 xxwar_trfmd_rmtr_iden_stg.remitter_identity_field9%TYPE,
    remitter_identity_field10 xxwar_trfmd_rmtr_iden_stg.remitter_identity_field10%TYPE,
    remitter_identity_field11 xxwar_trfmd_rmtr_iden_stg.remitter_identity_field11%TYPE,
    payment_rec_id xxwar_trfmd_rmtr_iden_stg.payment_rec_id%TYPE,
    remitter_iden_rec_id xxwar_trfmd_rmtr_iden_stg.remitter_iden_rec_id%TYPE,
    created_by xxwar_trfmd_rmtr_iden_stg.created_by%TYPE,
    creation_date xxwar_trfmd_rmtr_iden_stg.creation_date%TYPE,
    last_update_date xxwar_trfmd_rmtr_iden_stg.last_update_date%TYPE,
    last_updated_by xxwar_trfmd_rmtr_iden_stg.last_updated_by%TYPE,
    last_update_login xxwar_trfmd_rmtr_iden_stg.last_update_login%TYPE) ;
TYPE lt_rmtr_tbl_type
IS
  TABLE OF lr_rmtr_rec;
  lt_rmtr_tbl lt_rmtr_tbl_type;
TYPE lr_inv_rec
IS
  RECORD
  (
    record_type xxwar_trfmd_invoice_stg.record_type%TYPE,
    reference_iden_qualifier xxwar_trfmd_invoice_stg.reference_iden_qualifier%TYPE,
    reference_identification xxwar_trfmd_invoice_stg.reference_identification%TYPE,
    payment_action_code xxwar_trfmd_invoice_stg.payment_action_code%TYPE,
    amount_paid xxwar_trfmd_invoice_stg.amount_paid%TYPE,
    invoice_amount xxwar_trfmd_invoice_stg.invoice_amount%TYPE,
    discount_amount xxwar_trfmd_invoice_stg.discount_amount%TYPE,
    adjustment_reason_code xxwar_trfmd_invoice_stg.adjustment_reason_code%TYPE,
    adjustment_amount xxwar_trfmd_invoice_stg.adjustment_amount%TYPE,
    payment_rec_id xxwar_trfmd_invoice_stg.payment_rec_id%TYPE,
    invoice_rec_id xxwar_trfmd_invoice_stg.invoice_rec_id%TYPE,
    inv_trfmd_rec_id xxwar_trfmd_invoice_stg.inv_trfmd_rec_id%TYPE,
    created_by xxwar_trfmd_invoice_stg.created_by%TYPE,
    creation_date xxwar_trfmd_invoice_stg.creation_date%TYPE,
    last_update_date xxwar_trfmd_invoice_stg.last_update_date%TYPE,
    last_updated_by xxwar_trfmd_invoice_stg.last_updated_by%TYPE,
    last_update_login xxwar_trfmd_invoice_stg.last_update_login%TYPE) ;
TYPE lt_inv_tbl_type
IS
  TABLE OF lr_inv_rec;
  lt_inv_tbl lt_inv_tbl_type;
TYPE lt_supp_inv_rec
IS
  RECORD
  (
    record_type xxwar_trfmd_supp_invoice_stg.record_type%TYPE,
    supplemental_invoice_field1 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field1%TYPE,
    supplemental_invoice_field2 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field2%TYPE,
    supplemental_invoice_field3 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field3%TYPE,
    supplemental_invoice_field4 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field4%TYPE,
    supplemental_invoice_field5 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field5%TYPE,
    supplemental_invoice_field6 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field6%TYPE,
    supplemental_invoice_field7 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field7%TYPE,
    supplemental_invoice_field8 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field8%TYPE,
    supplemental_invoice_field9 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field9%TYPE,
    supplemental_invoice_field10 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field10%TYPE,
    supplemental_invoice_field11 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field11%TYPE,
    supplemental_invoice_field12 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field12%TYPE,
    supplemental_invoice_field13 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field13%TYPE,
    supplemental_invoice_field14 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field14%TYPE,
    supplemental_invoice_field15 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field15%TYPE,
    supplemental_invoice_field16 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field16%TYPE,
    supplemental_invoice_field17 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field17%TYPE,
    supplemental_invoice_field18 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field18%TYPE,
    supplemental_invoice_field19 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field19%TYPE,
    supplemental_invoice_field20 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field20%TYPE,
    supplemental_invoice_field21 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field21%TYPE,
    supplemental_invoice_field22 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field22%TYPE,
    supplemental_invoice_field23 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field23%TYPE,
    supplemental_invoice_field24 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field24%TYPE,
    supplemental_invoice_field25 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field25%TYPE,
    supplemental_invoice_field26 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field26%TYPE,
    supplemental_invoice_field27 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field27%TYPE,
    supplemental_invoice_field28 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field28%TYPE,
    supplemental_invoice_field29 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field29%TYPE,
    supplemental_invoice_field30 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field30%TYPE,
    supplemental_invoice_field31 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field31%TYPE,
    supplemental_invoice_field32 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field32%TYPE,
    supplemental_invoice_field33 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field33%TYPE,
    supplemental_invoice_field34 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field34%TYPE,
    supplemental_invoice_field35 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field35%TYPE,
    supplemental_invoice_field36 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field36%TYPE,
    supplemental_invoice_field37 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field37%TYPE,
    supplemental_invoice_field38 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field38%TYPE,
    supplemental_invoice_field39 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field39%TYPE,
    supplemental_invoice_field40 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field40%TYPE,
    supplemental_invoice_field41 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field41%TYPE,
    supplemental_invoice_field42 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field42%TYPE,
    supplemental_invoice_field43 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field43%TYPE,
    supplemental_invoice_field44 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field44%TYPE,
    supplemental_invoice_field45 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field45%TYPE,
    supplemental_invoice_field46 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field46%TYPE,
    supplemental_invoice_field47 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field47%TYPE,
    supplemental_invoice_field48 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field48%TYPE,
    supplemental_invoice_field49 xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field49%TYPE,
    invoice_rec_id xxwar_trfmd_supp_invoice_stg.invoice_rec_id%TYPE,
    supplemental_rec_id xxwar_trfmd_supp_invoice_stg.supplemental_rec_id%TYPE,
    created_by xxwar_trfmd_supp_invoice_stg.created_by%TYPE,
    creation_date xxwar_trfmd_supp_invoice_stg.creation_date%TYPE,
    last_update_date xxwar_trfmd_supp_invoice_stg.last_update_date%TYPE,
    last_updated_by xxwar_trfmd_supp_invoice_stg.last_updated_by%TYPE,
    last_update_login xxwar_trfmd_supp_invoice_stg.last_update_login%TYPE) ;
TYPE lt_supp_inv_tbl_type
IS
  TABLE OF lt_supp_inv_rec;
  lt_supp_inv_tbl lt_supp_inv_tbl_type;
  /*--Adjustment Detail Record*/
TYPE lr_adj_rec
IS
  RECORD
  (
    record_type xxwar_trfmd_adj_dtl_stg.record_type%TYPE,
    adjustment_amount xxwar_trfmd_adj_dtl_stg.adjustment_amount%TYPE,
    adjustment_reason xxwar_trfmd_adj_dtl_stg.adjustment_reason%TYPE,
    adjustment_id_qualifier xxwar_trfmd_adj_dtl_stg.adjustment_id_qualifier%TYPE,
    adjustment_id xxwar_trfmd_adj_dtl_stg.adjustment_id%TYPE,
    invoice_rec_id xxwar_trfmd_adj_dtl_stg.invoice_rec_id%TYPE,
    adjustment_hdr_id xxwar_trfmd_adj_dtl_stg.adjustment_hdr_id%TYPE,
    adjustment_status xxwar_trfmd_adj_dtl_stg.adjustment_status%TYPE,
    adjustment_error_msg xxwar_trfmd_adj_dtl_stg.adjustment_error_msg%TYPE,
    created_by xxwar_trfmd_adj_dtl_stg.created_by%TYPE,
    creation_date xxwar_trfmd_adj_dtl_stg.creation_date%TYPE,
    last_update_date xxwar_trfmd_adj_dtl_stg.last_update_date%TYPE,
    last_updated_by xxwar_trfmd_adj_dtl_stg.last_updated_by%TYPE,
    last_update_login xxwar_trfmd_adj_dtl_stg.last_update_login%TYPE,
    base_tbl_adjustment_id xxwar_trfmd_adj_dtl_stg.base_tbl_adjustment_id%TYPE) ;
TYPE lt_adj_rec_tbl_type
IS
  TABLE OF lr_adj_rec;
  lt_adj_dtl_tbl lt_adj_rec_tbl_type;
TYPE lr_adj_ln_rec
IS
  RECORD
  (
    record_type xxwar_trfmd_adj_ln_item_stg.record_type%TYPE,
    assigned_identification xxwar_trfmd_adj_ln_item_stg.assigned_identification%TYPE,
    quantity_invoiced xxwar_trfmd_adj_ln_item_stg.quantity_invoiced%TYPE,
    unit_of_measurement xxwar_trfmd_adj_ln_item_stg.unit_of_measurement%TYPE,
    unit_price xxwar_trfmd_adj_ln_item_stg.unit_price%TYPE,
    basis_of_unit_price_code xxwar_trfmd_adj_ln_item_stg.basis_of_unit_price_code%TYPE,
    product_id_qualifier1 xxwar_trfmd_adj_ln_item_stg.product_id_qualifier1%TYPE,
    product_id1 xxwar_trfmd_adj_ln_item_stg.product_id1%TYPE,
    product_id_qualifier2 xxwar_trfmd_adj_ln_item_stg.product_id_qualifier2%TYPE,
    product_id2 xxwar_trfmd_adj_ln_item_stg.product_id2%TYPE,
    product_id_qualifier3 xxwar_trfmd_adj_ln_item_stg.product_id_qualifier3%TYPE,
    product_id3 xxwar_trfmd_adj_ln_item_stg.product_id3%TYPE,
    product_id_qualifier4 xxwar_trfmd_adj_ln_item_stg.product_id_qualifier4%TYPE,
    product_id4 xxwar_trfmd_adj_ln_item_stg.product_id4%TYPE,
    product_id_qualifier5 xxwar_trfmd_adj_ln_item_stg.product_id_qualifier5%TYPE,
    product_id5 xxwar_trfmd_adj_ln_item_stg.product_id5%TYPE,
    product_id_qualifier6 xxwar_trfmd_adj_ln_item_stg.product_id_qualifier6%TYPE,
    product_id6 xxwar_trfmd_adj_ln_item_stg.product_id6%TYPE,
    product_id_qualifier7 xxwar_trfmd_adj_ln_item_stg.product_id_qualifier7%TYPE,
    product_id7 xxwar_trfmd_adj_ln_item_stg.product_id7%TYPE,
    product_id_qualifier8 xxwar_trfmd_adj_ln_item_stg.product_id_qualifier8%TYPE,
    product_id8 xxwar_trfmd_adj_ln_item_stg.product_id8%TYPE,
    product_id_qualifier9 xxwar_trfmd_adj_ln_item_stg.product_id_qualifier9%TYPE,
    product_id9 xxwar_trfmd_adj_ln_item_stg.product_id9%TYPE,
    adjustment_hdr_id xxwar_trfmd_adj_ln_item_stg.adjustment_hdr_id%TYPE,
    created_by xxwar_trfmd_adj_ln_item_stg.created_by%TYPE,
    creation_date xxwar_trfmd_adj_ln_item_stg.creation_date%TYPE,
    last_update_date xxwar_trfmd_adj_ln_item_stg.last_update_date%TYPE,
    last_updated_by xxwar_trfmd_adj_ln_item_stg.last_updated_by%TYPE,
    last_update_login xxwar_trfmd_adj_ln_item_stg.last_update_login%TYPE,
    adj_ln_item_id xxwar_trfmd_adj_ln_item_stg.adj_ln_item_id%TYPE) ;
TYPE lt_adj_ln_rec_tbl_type
IS
  TABLE OF lr_adj_ln_rec;
  lt_adj_ln_item_tbl lt_adj_ln_rec_tbl_type;
  lc_interim_status VARCHAR2 (1) :='S' ;
  lc_status_msg     VARCHAR2 (32000) ;
  ln_row_count     NUMBER  := 0;
BEGIN
    SAVEPOINT ls_custom_data;
  BEGIN
     SELECT xps.batch_hdr_id          ,
      xps.lbx_file_id                 ,
      xps.record_type                 ,
      xps.payment_type                ,
      xps.credit_debit                ,
      xps.payment_amount              ,
      xps.destination_rtn             ,
      xps.destination_account_no      ,
      xps.originator_rtn              ,
      xps.originator_account_no       ,
      xps.effective_date              ,
      xps.payment_rec_id              ,
      xps.supplemental_payment_field1 ,
      xps.supplemental_payment_field2 ,
      xps.supplemental_payment_field3 ,
      xps.supplemental_payment_field4 ,
      xps.supplemental_payment_field5 ,
      xps.supplemental_payment_field6 ,
      xps.supplemental_payment_field7 ,
      xps.supplemental_payment_field8 ,
      xps.supplemental_payment_field9 ,
      xps.supplemental_payment_field10,
      xps.supplemental_payment_field11,
      xps.supplemental_payment_field12,
      xps.supplemental_payment_field13,
      xps.supplemental_payment_field14,
      xps.supplemental_payment_field15,
      xps.supplemental_payment_field16,
      xps.supplemental_payment_field17,
      xps.supplemental_payment_field18,
      xps.supplemental_payment_field19,
      xps.supplemental_payment_field20,
      xps.supplemental_payment_field21,
      xps.supplemental_payment_field22,
      xps.supplemental_payment_field23,
      xps.supplemental_payment_field24,
      xps.supplemental_payment_field25,
      xps.supplemental_payment_field26,
      xps.supplemental_payment_field27,
      xps.supplemental_payment_field28,
      xps.supplemental_payment_field29,
      xps.supplemental_payment_field30,
      xps.supplemental_payment_field31,
      xps.supplemental_payment_field32,
      xps.supplemental_payment_field33,
      xps.supplemental_payment_field34,
      xps.supplemental_payment_field35,
      xps.supplemental_payment_field36,
      xps.supplemental_payment_field37,
      xps.supplemental_payment_field38,
      xps.supplemental_payment_field39,
      xps.supplemental_payment_field40,
      xps.supplemental_payment_field41,
      xps.supplemental_payment_field42,
      xps.supplemental_payment_field43,
      xps.supplemental_payment_field44,
      xps.supplemental_payment_field45,
      xps.supplemental_payment_field46,
      xps.supplemental_payment_field47,
      xps.supplemental_payment_field48,
      xps.supplemental_payment_field49,
      xps.supplemental_payment_field50,
      xps.created_by                  ,
      xps.creation_date               ,
      xps.last_update_date            ,
      xps.last_updated_by             ,
      xps.last_update_login           ,
      xfs.file_number                 ,
      xfs.file_date BULK COLLECT
       INTO lt_pymt_tbl
       FROM xxwar_trfmd_pymt_stg xps,
      xxwar_trfmd_batch_stg xbs     ,
      xxwar_file_stg xfs
      WHERE xfs.file_number = xbs.file_number
    AND xbs.lbx_file_id = xps.lbx_file_id
    AND xps.lbx_file_id = p_lbx_file_id
	AND xps.payment_rec_id = nvl(p_payment_rec_id,xps.payment_rec_id);
  EXCEPTION
  WHEN OTHERS THEN
    lc_interim_status := 'E';
    lc_status_msg := get_error_message_pvt('XXWAR_ERROR_MESSAGES_038'
                                           ,'SQL_ERRM'
                                           ,SQLERRM);
                     --'Failed while fetching records at payment level. Error : '|| SQLERRM;
  END;
  IF lt_pymt_tbl.count > 0 THEN
    FOR pymt_ndx IN lt_pymt_tbl.FIRST..lt_pymt_tbl.LAST
    LOOP
      BEGIN
         SELECT record_type        ,
          remitter_identity_field1 ,
          remitter_identity_field2 ,
          remitter_identity_field3 ,
          remitter_identity_field4 ,
          remitter_identity_field5 ,
          remitter_identity_field6 ,
          remitter_identity_field7 ,
          remitter_identity_field8 ,
          remitter_identity_field9 ,
          remitter_identity_field10,
          remitter_identity_field11,
          payment_rec_id           ,
          remitter_iden_rec_id     ,
          created_by               ,
          creation_date            ,
          last_update_date         ,
          last_updated_by          ,
          last_update_login BULK COLLECT
           INTO lt_rmtr_tbl
           FROM xxwar_trfmd_rmtr_iden_stg
          WHERE payment_rec_id = lt_pymt_tbl (pymt_ndx) .payment_rec_id;
      EXCEPTION
      WHEN OTHERS THEN
        lc_interim_status := 'E';
        lc_status_msg := lc_status_msg ||' | ' ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_039'
                                                                       ,'SQL_ERRM'
                                                                       ,SQLERRM);
                                                 --'Failed at remitter identity level. Error :' ||SQLERRM;
      END;
      BEGIN
         SELECT record_type       ,
          reference_iden_qualifier,
          reference_identification,
          payment_action_code     ,
          amount_paid             ,
          invoice_amount          ,
          discount_amount         ,
          adjustment_reason_code  ,
          adjustment_amount       ,
          payment_rec_id          ,
          invoice_rec_id          ,
          inv_trfmd_rec_id        ,
          created_by              ,
          creation_date           ,
          last_update_date        ,
          last_updated_by         ,
          last_update_login BULK COLLECT
           INTO lt_inv_tbl
           FROM xxwar_trfmd_invoice_stg
          WHERE payment_rec_id = lt_pymt_tbl (pymt_ndx) .payment_rec_id
		  AND inv_trfmd_rec_id = NVL(p_inv_trfmd_rec_id,inv_trfmd_rec_id);
      EXCEPTION
      WHEN OTHERS THEN
        lc_interim_status := 'E';
        lc_status_msg := lc_status_msg ||' | ' ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_040'
                                                                       ,'SQL_ERRM'
                                                                       ,SQLERRM);
                                                --'Failed during fetching records at invoice staging level. Error :' ||SQLERRM;
      END;
      IF lt_inv_tbl.count > 0 THEN
        FOR inv_ndx IN lt_inv_tbl.FIRST..lt_inv_tbl.LAST
        LOOP
          BEGIN
             SELECT record_type           ,
              supplemental_invoice_field1 ,
              supplemental_invoice_field2 ,
              supplemental_invoice_field3 ,
              supplemental_invoice_field4 ,
              supplemental_invoice_field5 ,
              supplemental_invoice_field6 ,
              supplemental_invoice_field7 ,
              supplemental_invoice_field8 ,
              supplemental_invoice_field9 ,
              supplemental_invoice_field10,
              supplemental_invoice_field11,
              supplemental_invoice_field12,
              supplemental_invoice_field13,
              supplemental_invoice_field14,
              supplemental_invoice_field15,
              supplemental_invoice_field16,
              supplemental_invoice_field17,
              supplemental_invoice_field18,
              supplemental_invoice_field19,
              supplemental_invoice_field20,
              supplemental_invoice_field21,
              supplemental_invoice_field22,
              supplemental_invoice_field23,
              supplemental_invoice_field24,
              supplemental_invoice_field25,
              supplemental_invoice_field26,
              supplemental_invoice_field27,
              supplemental_invoice_field28,
              supplemental_invoice_field29,
              supplemental_invoice_field30,
              supplemental_invoice_field31,
              supplemental_invoice_field32,
              supplemental_invoice_field33,
              supplemental_invoice_field34,
              supplemental_invoice_field35,
              supplemental_invoice_field36,
              supplemental_invoice_field37,
              supplemental_invoice_field38,
              supplemental_invoice_field39,
              supplemental_invoice_field40,
              supplemental_invoice_field41,
              supplemental_invoice_field42,
              supplemental_invoice_field43,
              supplemental_invoice_field44,
              supplemental_invoice_field45,
              supplemental_invoice_field46,
              supplemental_invoice_field47,
              supplemental_invoice_field48,
              supplemental_invoice_field49,
              invoice_rec_id              ,
              supplemental_rec_id         ,
              created_by                  ,
              creation_date               ,
              last_update_date            ,
              last_updated_by             ,
              last_update_login BULK COLLECT
               INTO lt_supp_inv_tbl
               FROM xxwar_trfmd_supp_invoice_stg
              WHERE invoice_rec_id = lt_inv_tbl (inv_ndx) .inv_trfmd_rec_id;
          EXCEPTION
          WHEN OTHERS THEN
            lc_interim_status := 'E';
            lc_status_msg := lc_status_msg ||' | ' ||get_error_message_pvt( 'XXWAR_ERROR_MESSAGES_041'
                                                                           ,'SQL_ERRM'
                                                                           ,SQLERRM);
                                                    --'Failed during fetching records at Supplemntal Invoice staging level. Error :' ||SQLERRM;
          END;
          BEGIN
             SELECT record_type      ,
              adjustment_amount      ,
              adjustment_reason      ,
              adjustment_id_qualifier,
              adjustment_id          ,
              invoice_rec_id         ,
              adjustment_hdr_id      ,
              adjustment_status      ,
              adjustment_error_msg   ,
              created_by             ,
              creation_date          ,
              last_update_date       ,
              last_updated_by        ,
              last_update_login      ,
              base_tbl_adjustment_id BULK COLLECT
               INTO lt_adj_dtl_tbl
               FROM xxwar_trfmd_adj_dtl_stg
              WHERE invoice_rec_id = lt_inv_tbl (inv_ndx) .inv_trfmd_rec_id;
          EXCEPTION
          WHEN OTHERS THEN
            lc_interim_status := 'E';
            lc_status_msg := lc_status_msg
                             ||' | '
                             ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_018','','')||'. Error :'
                             ||SQLERRM;
          END;
          IF lt_adj_dtl_tbl.count > 0 THEN
            FOR adj_ndx IN lt_adj_dtl_tbl.FIRST..lt_adj_dtl_tbl.LAST
            LOOP
              BEGIN
                 SELECT record_type       ,
                  assigned_identification ,
                  quantity_invoiced       ,
                  unit_of_measurement     ,
                  unit_price              ,
                  basis_of_unit_price_code,
                  product_id_qualifier1   ,
                  product_id1             ,
                  product_id_qualifier2   ,
                  product_id2             ,
                  product_id_qualifier3   ,
                  product_id3             ,
                  product_id_qualifier4   ,
                  product_id4             ,
                  product_id_qualifier5   ,
                  product_id5             ,
                  product_id_qualifier6   ,
                  product_id6             ,
                  product_id_qualifier7   ,
                  product_id7             ,
                  product_id_qualifier8   ,
                  product_id8             ,
                  product_id_qualifier9   ,
                  product_id9             ,
                  adjustment_hdr_id       ,
                  created_by              ,
                  creation_date           ,
                  last_update_date        ,
                  last_updated_by         ,
                  last_update_login       ,
                  adj_ln_item_id BULK COLLECT
                   INTO lt_adj_ln_item_tbl
                   FROM xxwar_trfmd_adj_ln_item_stg
                  WHERE adjustment_hdr_id = lt_adj_dtl_tbl (adj_ndx) .adjustment_hdr_id;
              EXCEPTION
              WHEN OTHERS THEN
                lc_interim_status := 'E';
                lc_status_msg := lc_status_msg
                                 ||' | '
                                 ||get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_042'
                                                         ,'SQL_ERRM'
                                                         ,SQLERRM);
								 --'Failed during fetching records at adjustment line staging level. Error :'||SQLERRM;
              END;
              BEGIN
                FORALL ladj_ln_indx IN lt_adj_ln_item_tbl.FIRST .. lt_adj_ln_item_tbl.LAST
                 INSERT INTO xxwar_adj_ln_item_tbl VALUES lt_adj_ln_item_tbl
                  (ladj_ln_indx
                  ) ;
              EXCEPTION
              WHEN OTHERS THEN
                lc_interim_status := 'E';
                lc_status_msg := lc_status_msg
                                 ||' | '
                                 ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_019','SQL_ERRM',SQLERRM);
              END;
            END LOOP;
            BEGIN
              FORALL ladj_indx IN lt_adj_dtl_tbl.FIRST .. lt_adj_dtl_tbl.LAST
               INSERT INTO xxwar_adj_dtl_tbl VALUES lt_adj_dtl_tbl
                (ladj_indx
                ) ;
            EXCEPTION
            WHEN OTHERS THEN
              lc_interim_status := 'E';
              lc_status_msg := lc_status_msg
                               ||' | '
                               ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_043'
                                                       ,'SQL_ERRM'
                                                       ,SQLERRM);
							   --' records failed to be inserted into xxwar_adj_dtl_tbl. Error :'||SQLERRM;
            END;
          END IF;
          BEGIN
            FORALL supp_inv_ndx IN lt_supp_inv_tbl.FIRST .. lt_supp_inv_tbl.LAST
             INSERT INTO xxwar_supp_invoice_tbl VALUES lt_supp_inv_tbl
              (supp_inv_ndx
              ) ;
          EXCEPTION
          WHEN OTHERS THEN
            lc_interim_status := 'E';
            lc_status_msg := lc_status_msg
                             ||' | '
                             ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_044'
                                                     ,'SQL_ERRM'
                                                     ,SQLERRM);
                            --' records failed to be inserted into xxwar_supp_invoice_tbl. Error :'||SQLERRM;
          END;
        END LOOP;
        BEGIN
          FORALL invoice_ndx IN lt_inv_tbl.FIRST .. lt_inv_tbl.LAST
           INSERT INTO xxwar_invoice_tbl VALUES lt_inv_tbl
            (invoice_ndx
            ) ;
        EXCEPTION
        WHEN OTHERS THEN
          lc_interim_status := 'E';
          lc_status_msg := lc_status_msg
                           ||' | '
                           ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_045'
                                                   ,'SQL_ERRM'
                                                   ,SQLERRM);
                           --' records failed to be inserted into xxwar_invoice_tbl. Error :'||SQLERRM;
        END;
      END IF;
      IF lt_rmtr_tbl.count > 0 THEN
        BEGIN
          FORALL rmtr_indx IN lt_rmtr_tbl.FIRST .. lt_rmtr_tbl.LAST
           INSERT INTO xxwar_rmtr_iden_tbl VALUES lt_rmtr_tbl
            (rmtr_indx
            ) ;
        EXCEPTION
        WHEN OTHERS THEN
          lc_interim_status := 'E';
          lc_status_msg := lc_status_msg
                           ||' | '
                           ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_046'
                                                   ,'SQL_ERRM'
                                                   ,SQLERRM );
                           --' records failed to be inserted into xxwar_rmtr_iden_tbl. Error :'||SQLERRM;
        END;
      END IF;
    END LOOP;
    BEGIN
      SELECT COUNT(payment_rec_id)
         INTO ln_row_count
	     FROM xxwar_pymt_tbl
        WHERE payment_rec_id = nvl(p_payment_rec_id,0);
		IF ln_row_count  = 0 THEN
	      FORALL payment_indx IN lt_pymt_tbl.FIRST .. lt_pymt_tbl.LAST
		  INSERT INTO xxwar_pymt_tbl VALUES lt_pymt_tbl(payment_indx) ;
	    END IF;
    EXCEPTION
    WHEN OTHERS THEN
      lc_interim_status := 'E';
      lc_status_msg := lc_status_msg
                       ||' | '
                       ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_047'
                                              ,'SQL_ERRM'
                                              ,SQLERRM);
					   --' records failed to be inserted into xxwar_pymt_tbl. Error :'||SQLERRM;
    END;
  END IF;
  IF lc_interim_status = 'E' THEN
    x_return_status := lc_interim_status;
    x_error_msg := lc_status_msg;
    ROLLBACK TO ls_custom_data;
  ELSE
    x_return_status := lc_interim_status;
    x_error_msg := NULL;
  END IF;
  /*--Issue COMMIT in the calling environment/procedure.*/
END load_custom_data;

PROCEDURE create_adjustment
  (
    p_lockbox_file_id IN VARCHAR2,
    p_org_id IN NUMBER,
    x_adjst_creation_status OUT VARCHAR2
  )
IS
TYPE lr_adjustment_rec
IS
  RECORD
  (
    row_id            ROWID,
    adjustment_hdr_id xxwar_trfmd_adj_dtl_stg.adjustment_hdr_id%TYPE,
    adjustment_amount xxwar_trfmd_adj_dtl_stg.adjustment_amount%TYPE,
    adjustment_reason xxwar_trfmd_adj_dtl_stg.adjustment_reason%TYPE,
    invoice_number    xxwar_trfmd_invoice_stg.reference_identification%TYPE,
    cash_receipt_id   ar_receivable_applications_all.cash_receipt_id%TYPE
  )
  ;
TYPE lt_adjustment_tbl_type
IS
  TABLE OF lr_adjustment_rec;
  lt_adjustment_tbl lt_adjustment_tbl_type;
  CURSOR c_receivables_trx (p_receivable_trx VARCHAR2)
  IS
     SELECT receivables_trx_id
       FROM ar_receivables_trx
      WHERE NAME = p_receivable_trx
        AND status = 'A';

  lc_pmt_schedule_id      NUMBER;
  lc_receivables_trx_id   NUMBER;
  lc_adjustment_rec_valid VARCHAR2 (1) ;
  lc_return_status        VARCHAR2 (1) ;
  lc_new_adjust_id        NUMBER;
  lc_adjst_batch_status   VARCHAR2 (1) ;
  lc_apimsg_data          VARCHAR2 (32000) ;
  lc_apimsg_data1         VARCHAR2 (32000) ;
  lr_adjustment_rec1 ar_adjustments%ROWTYPE;
  lc_msg_data              VARCHAR2 (2000) ;
  lc_msg_count             NUMBER;
  lc_new_adjustment_number NUMBER;
  lc_batch_exists_eligible     VARCHAR2 (1);
  lc_sqlerrm              VARCHAR2(4000);
  lc_org_id               NUMBER;
  lc_update_error_str     VARCHAR2(400);
  lc_set_error_str        VARCHAR2(400);
  lc_set_error_str1       VARCHAR2(400);
  Batch_not_eligible_exception EXCEPTION;
  unhandled_exception          EXCEPTION;
  lc_msg_str              VARCHAR2(2000);




BEGIN
    print_log('Start Adjustment creation for LBX file ID: '||p_lockbox_file_id);
    print_log('Org id: '||p_org_id);
    lc_org_id := p_org_id;
    FND_REQUEST.SET_ORG_ID (lc_org_id) ;
    BEGIN
         SELECT DISTINCT 'Y'
           INTO lc_batch_exists_eligible
           FROM ar_cash_receipts_all ACRA,
                ar_transmissions_all ATL,
                xxwar_trfmd_batch_stg XBS
          WHERE ACRA.request_id = ATL.latest_request_id
            AND ACRA.org_id = ATL.org_id
            AND ATL.status = 'CL'
            And ATL.transmission_request_id = XBS.request_id
            AND XBS.lbx_file_id = p_lockbox_file_id
            AND ATL.org_id = lc_org_id;

    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        print_log('Batch_not_eligible_exception for LBX file ID: '||p_lockbox_file_id);
        RAISE Batch_not_eligible_exception;
    WHEN others THEN
        print_log('unhandled_exception for LBX file ID: '
                                      ||p_lockbox_file_id
                                      || ' - '
                                      ||SQLERRM);
        RAISE unhandled_exception;
    END;

 IF lc_batch_exists_eligible = 'Y' THEN
  print_log('Batch is eligble to create adjustments');
  BEGIN
   SELECT xads.ROWID row_id                 ,
          xads.adjustment_hdr_id                      ,
          xads.adjustment_amount adjustment_amount,
          xads.adjustment_reason adjustment_reason,
          xis.reference_identification invoice_number,
          araa.cash_receipt_id
        BULK COLLECT INTO lt_adjustment_tbl
     FROM xxwar_trfmd_batch_stg xbs,
          xxwar_trfmd_pymt_stg xps       ,
          xxwar_trfmd_invoice_stg xis    ,
          xxwar_trfmd_adj_dtl_stg xads   ,
          ar_cash_receipts_all acra          ,
          ar_transmissions_all ata           ,
          ra_customer_trx_all rctl           ,
          ar_receivable_applications_all araa
    WHERE xbs.latest_request_id = acra.request_id
      AND acra.request_id = ata.latest_request_id
     -- AND ata.status = 'CL'
      AND xbs.lbx_file_id = xps.lbx_file_id
      AND xps.payment_rec_id = xis.payment_rec_id
      AND xis.inv_trfmd_rec_id = xads.invoice_rec_id
      AND rctl.trx_number = xis.reference_identification
      AND acra.cash_receipt_id = araa.cash_receipt_id
      AND rctl.customer_trx_id = araa.applied_customer_trx_id
      AND xps.supplemental_payment_field35 = 'CTX'
      AND xads.adjustment_status IN ('E','N')
      AND acra.org_id = ata.org_id
      AND rctl.org_id = araa.org_id
      AND rctl.org_id = ata.org_id
      AND ata.org_id = lc_org_id
      AND xbs.lbx_file_id = p_lockbox_file_id
      AND xps.payment_rec_id = acra.attribute15;


  print_log('Start savepoint ls_create_adjst ');
  SAVEPOINT ls_create_adjst;
  IF lt_adjustment_tbl.COUNT > 0 THEN
  FOR adjust_rec IN lt_adjustment_tbl.FIRST .. lt_adjustment_tbl.COUNT
  LOOP
    BEGIN
     lc_pmt_schedule_id := NULL;
     SELECT apsa.payment_schedule_id
       INTO lc_pmt_schedule_id
       FROM ar_payment_schedules_all apsa,
            ra_customer_trx_all rctl,
            ar_receivable_applications_all araa,
            xxwar_trfmd_batch_stg xbs
      WHERE apsa.customer_trx_id = rctl.customer_trx_id
        AND apsa.trx_number = lt_adjustment_tbl (adjust_rec) .invoice_number
        AND araa.applied_payment_schedule_id = apsa.payment_schedule_id
        AND araa.request_id = xbs.latest_request_id
        AND apsa.org_id = rctl.org_id
        AND rctl.org_id = araa.org_id
        AND araa.org_id = lc_org_id
        AND xbs.lbx_file_id = p_lockbox_file_id
        AND Araa.cash_receipt_id = lt_adjustment_tbl (adjust_rec) .cash_receipt_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
           lc_adjustment_rec_valid := 'N';
           lc_msg_data := lc_msg_data
                          || get_error_message_pvt('XXWAR_ERROR_MESSAGES_020','INV_NUM',lt_adjustment_tbl (adjust_rec) .invoice_number);
           print_log(get_error_message_pvt('XXWAR_ERROR_MESSAGES_020','INV_NUM',lt_adjustment_tbl (adjust_rec) .invoice_number));
      WHEN others THEN
           lc_adjustment_rec_valid := 'N';
           lc_msg_data := lc_msg_data
                          || get_error_message_pvt('XXWAR_ERROR_MESSAGES_021','INV_NUM|SQL_ERRM',lt_adjustment_tbl (adjust_rec) .invoice_number||'|'||SQLERRM);
           print_log(get_error_message_pvt('XXWAR_ERROR_MESSAGES_021','INV_NUM|SQL_ERRM',lt_adjustment_tbl (adjust_rec) .invoice_number||'|'||SQLERRM));
    END;


    BEGIN
       lc_receivables_trx_id := NULL;
        SELECT receivables_trx_id
          INTO lc_receivables_trx_id
          FROM ar_receivables_trx_all
         WHERE NAME = lt_adjustment_tbl (adjust_rec) .adjustment_reason
           AND status = 'A'
           AND org_id = lc_org_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
           lc_adjustment_rec_valid := 'N';
           lc_msg_data := CONCAT (lc_msg_data, get_error_message_pvt('XXWAR_ERROR_MESSAGES_022','REC_ACTIVITY',lt_adjustment_tbl (adjust_rec) .adjustment_reason)) ;
           print_log(get_error_message_pvt('XXWAR_ERROR_MESSAGES_022','REC_ACTIVITY',lt_adjustment_tbl (adjust_rec) .adjustment_reason));
      WHEN others THEN
           lc_adjustment_rec_valid := 'N';
           lc_msg_data := CONCAT (lc_msg_data, get_error_message_pvt('XXWAR_ERROR_MESSAGES_023','REC_ACTIVITY|SQL_ERRM',lt_adjustment_tbl (adjust_rec) .adjustment_reason||'|'||SQLERRM)) ;
           print_log(get_error_message_pvt('XXWAR_ERROR_MESSAGES_023','REC_ACTIVITY|SQL_ERRM',lt_adjustment_tbl (adjust_rec) .adjustment_reason||'|'||SQLERRM));
    END ;


    /*Set lc_adjustment_rec_valid = 'N' on error while fetching payment_schedule_id and
    receivables_trx_id;*/
    IF (lc_pmt_schedule_id IS NULL or lc_receivables_trx_id IS NULL) THEN
      lc_adjustment_rec_valid := 'N';
      print_log('lc_adjustment_rec_valid is set to ''N''');
    ELSE
      lc_adjustment_rec_valid := 'Y';
      print_log('lc_adjustment_rec_valid is set to ''Y''');
    END IF;
    IF lc_adjustment_rec_valid = 'Y' THEN
     BEGIN
       print_log('before calling API ');
       fnd_message.CLEAR;
       lr_adjustment_rec1.TYPE := 'LINE';
       lr_adjustment_rec1.payment_schedule_id := lc_pmt_schedule_id;
       lr_adjustment_rec1.amount := TO_NUMBER ((lt_adjustment_tbl (adjust_rec).adjustment_amount/100));
       lr_adjustment_rec1.receivables_trx_id := lc_receivables_trx_id;
       lr_adjustment_rec1.apply_date := TO_DATE (SYSDATE, 'DD-MON-RR');
       lr_adjustment_rec1.gl_date := TO_DATE (SYSDATE, 'DD-MON-RR');
       lr_adjustment_rec1.created_FROM := 'ADJ-API';
       print_log('Submit Create Adjustment API');
      ar_adjust_pub.create_adjustment (p_api_name             => 'AR_ADJUST_PUB'
                                     , p_api_version          => 1.0
                                     , p_init_msg_list        => fnd_api.g_false
                                     , p_commit_flag          => fnd_api.g_false
                                     , p_validation_level     => fnd_api.g_valid_level_full
                                     , p_msg_count            => lc_msg_count
                                     , p_msg_data             => lc_apimsg_data
                                     , p_return_status        => lc_return_status
                                     , p_adj_rec              => lr_adjustment_rec1
                                     , p_chk_approval_limits  => fnd_api.g_true
                                     , p_check_amount         => fnd_api.g_true
                                     , p_move_deferred_tax    => NULL
                                     , p_new_adjust_number    => lc_new_adjustment_number
                                     , p_new_adjust_id        => lc_new_adjust_id
                                     , p_called_FROM          => NULL
                                     , p_old_adjust_id        => NULL
                                     , p_org_id               => lc_org_id
                                  ) ;
       print_log('After calling API ');
       IF lc_return_status = 'S' THEN
       print_log('No validation errors for Adjustment Hdr ID:'
                                    || lt_adjustment_tbl (adjust_rec).adjustment_hdr_id);
          xxwar_receipts_pkg.update_adjustment (p_adj_hdr_id => lt_adjustment_tbl (adjust_rec).adjustment_hdr_id
                                              , p_adj_error => lc_apimsg_data
                                              , p_status => 'P'
                                              , p_base_table_adj_id => lc_new_adjust_id) ;

       ELSE
          lc_adjst_batch_status := 'E';
          print_log('Validation errors for Adjustment Hdr ID: '
                                    || lt_adjustment_tbl (adjust_rec).adjustment_hdr_id);
          FOR l_index IN 1 .. lc_msg_count LOOP
            lc_apimsg_data1 := fnd_msg_pub.get (p_msg_index      => l_index,
                                                p_encoded        => fnd_api.g_false
                                                );
            lc_apimsg_data := lc_apimsg_data || ' | '
                                             || l_index
                                             || '- '
                                             || lc_apimsg_data1;
            print_log( l_index
                            || ' - '
                            || lc_apimsg_data1);
           END LOOP;
          xxwar_receipts_pkg.update_adjustment (p_adj_hdr_id => lt_adjustment_tbl (adjust_rec).adjustment_hdr_id
                                              , p_adj_error => lc_apimsg_data
                                              , p_status => 'E'
                                              , p_base_table_adj_id => NULL) ;
       END IF;
     EXCEPTION
      WHEN others THEN
           lc_adjst_batch_status := 'E';
           xxwar_receipts_pkg.update_adjustment (p_adj_hdr_id => lt_adjustment_tbl (adjust_rec).adjustment_hdr_id
                                               , p_adj_error => get_error_message_pvt('XXWAR_ERROR_MESSAGES_050'
                                                                                      ,'SQL_ERRM'
                                                                                      ,SQLERRM)
                                               --'Exception Occured while calling Adjustment API.'||SQLERRM
                                               , p_status => 'E'
                                               , p_base_table_adj_id => NULL) ;
          print_log('Exception Occured while calling Adjustment API.'
                                    ||SQLERRM
                                    || ' - For Adjustment Hdr ID: '
                                    || lt_adjustment_tbl (adjust_rec).adjustment_hdr_id);
     END ;
    ELSE
        lc_adjst_batch_status := 'E';
        xxwar_receipts_pkg.update_adjustment (p_adj_hdr_id => lt_adjustment_tbl (adjust_rec).adjustment_hdr_id
                                            , p_adj_error => get_error_message_pvt('XXWAR_ERROR_MESSAGES_059','','')||' - '||lc_msg_data
											 --'Adjustment record validation failed'
                                            , p_status => 'E'
                                            , p_base_table_adj_id => NULL) ;
         print_log('Adjustment record validation failed - '
                                       ||lc_msg_data
                                       || ' - For Adjustment Hdr ID: '
                                       || lt_adjustment_tbl (adjust_rec).adjustment_hdr_id);
    END IF;
  END LOOP;
  ELSE
    ROLLBACK TO ls_create_adjst;
    print_log('Invoice number in AR file doesn''t exists in ERP. No adjustments has been created.');
       lc_update_error_str := 'Invoice number in AR file doesn''t exists in ERP. No adjustments has been created.';
       UPDATE xxwar_trfmd_adj_dtl_stg
         SET adjustment_error_msg = lc_update_error_str,
             adjustment_status = 'E',
             last_update_date = SYSDATE,
             last_updated_by = fnd_global.user_id,
             last_update_login = fnd_global.login_id
       WHERE adjustment_hdr_id IN (
                   SELECT xads.adjustment_hdr_id
                     FROM xxwar_trfmd_batch_stg xbs,
                          xxwar_trfmd_pymt_stg xps,
                          xxwar_trfmd_invoice_stg xis,
                          xxwar_trfmd_adj_dtl_stg xads
                    WHERE xbs.lbx_file_id = p_lockbox_file_id
                      AND xbs.lbx_file_id = xps.lbx_file_id
                      AND xps.payment_rec_id = xis.payment_rec_id
                      AND xis.inv_trfmd_rec_id = xads.invoice_rec_id);
     COMMIT;

  END IF;
  IF lc_adjst_batch_status = 'E' THEN
    x_adjst_creation_status := 'E';
    print_log('a. Rollback to savepoint ''ls_create_adjst''');
    ROLLBACK TO ls_create_adjst;
  ELSE
    x_adjst_creation_status := 'S';
    COMMIT;
  END IF;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
     print_log('b. Rollback to savepoint ''ls_create_adjst''');
          ROLLBACK TO ls_create_adjst;
          x_adjst_creation_status := 'E';
		  lc_update_error_str := get_error_message_pvt('XXWAR_ERROR_MESSAGES_024','LOCKBBOX_FILE_ID',p_lockbox_file_id);
     print_log( lc_update_error_str);
          UPDATE xxwar_trfmd_adj_dtl_stg
             SET adjustment_error_msg = lc_update_error_str,
                 adjustment_status = 'E',
                 last_update_date = SYSDATE,
                 last_updated_by = fnd_global.user_id,
                 last_update_login = fnd_global.login_id
           WHERE adjustment_hdr_id IN (
                      SELECT xads.adjustment_hdr_id
                        FROM xxwar_trfmd_batch_stg xbs,
                             xxwar_trfmd_pymt_stg xps,
                             xxwar_trfmd_invoice_stg xis,
                             xxwar_trfmd_adj_dtl_stg xads
                       WHERE xbs.lbx_file_id = p_lockbox_file_id
                         AND xbs.lbx_file_id = xps.lbx_file_id
                         AND xps.payment_rec_id = xis.payment_rec_id
                         AND xis.inv_trfmd_rec_id = xads.invoice_rec_id);
     COMMIT;
    WHEN others THEN
      print_log('d. Rollback to savepoint ''ls_create_adjst''');
          ROLLBACK TO ls_create_adjst;
          x_adjst_creation_status := 'E';
      print_log('Adjustment PLSQL collection failed for lockbox file ID : '
                                  || p_lockbox_file_id
                                  || ' '
                                  || SQLERRM);
      lc_sqlerrm := SQLERRM;
	  lc_update_error_str := get_error_message_pvt('XXWAR_ERROR_MESSAGES_049'
                                                   ,'FILE_ID|SQL_ERRM'
                                                   ,p_lockbox_file_id||'|'||lc_sqlerrm);
          UPDATE xxwar_trfmd_adj_dtl_stg
             SET adjustment_error_msg = lc_update_error_str,
                                       --'Adjustment PLSQL collection failed for lockbox file ID : '|| p_lockbox_file_id|| ' '|| lc_sqlerrm,
                 adjustment_status = 'E',
                 last_update_date = SYSDATE,
                 last_updated_by = fnd_global.user_id,
                 last_update_login = fnd_global.login_id
           WHERE adjustment_hdr_id IN (
                      SELECT xads.adjustment_hdr_id
                        FROM xxwar_trfmd_batch_stg xbs,
                             xxwar_trfmd_pymt_stg xps,
                             xxwar_trfmd_invoice_stg xis,
                             xxwar_trfmd_adj_dtl_stg xads
                       WHERE xbs.lbx_file_id = p_lockbox_file_id
                         AND xbs.lbx_file_id = xps.lbx_file_id
                         AND xps.payment_rec_id = xis.payment_rec_id
                         AND xis.inv_trfmd_rec_id = xads.invoice_rec_id);
     COMMIT;
  END;
END IF;
EXCEPTION
  WHEN Batch_not_eligible_exception THEN
       x_adjst_creation_status := 'E';
	   lc_set_error_str := get_error_message_pvt('XXWAR_ERROR_MESSAGES_025','','');
       print_log(lc_set_error_str
                                    || p_lockbox_file_id);
       UPDATE xxwar_trfmd_adj_dtl_stg
          SET adjustment_error_msg =
                     lc_set_error_str
                      || p_lockbox_file_id,
              adjustment_status = 'E',
              last_update_date = SYSDATE,
              last_updated_by = fnd_global.user_id,
              last_update_login = fnd_global.login_id
        WHERE adjustment_hdr_id IN (
                      SELECT xads.adjustment_hdr_id
                        FROM xxwar_trfmd_batch_stg xbs,
                             xxwar_trfmd_pymt_stg xps,
                             xxwar_trfmd_invoice_stg xis,
                             xxwar_trfmd_adj_dtl_stg xads
                       WHERE xbs.lbx_file_id = p_lockbox_file_id
                         AND xbs.lbx_file_id = xps.lbx_file_id
                         AND xps.payment_rec_id = xis.payment_rec_id
                         AND xis.inv_trfmd_rec_id = xads.invoice_rec_id);
    COMMIT;
WHEN unhandled_exception THEN
     x_adjst_creation_status := 'E';
     lc_sqlerrm := SQLERRM;
	 lc_set_error_str1  := get_error_message_pvt('XXWAR_ERROR_MESSAGES_026','LOCKBBOX_FILE_ID',p_lockbox_file_id);
     print_log( lc_set_error_str1
                                     ||' - '
                                     || lc_sqlerrm );
     UPDATE xxwar_trfmd_adj_dtl_stg
          SET adjustment_error_msg = lc_set_error_str1
                                     ||' - '
                                     || lc_sqlerrm,
              adjustment_status = 'E',
              last_update_date = SYSDATE,
              last_updated_by = fnd_global.user_id,
              last_update_login = fnd_global.login_id
        WHERE adjustment_hdr_id IN (
                      SELECT xads.adjustment_hdr_id
                        FROM xxwar_trfmd_batch_stg xbs,
                             xxwar_trfmd_pymt_stg xps,
                             xxwar_trfmd_invoice_stg xis,
                             xxwar_trfmd_adj_dtl_stg xads
                       WHERE xbs.lbx_file_id = p_lockbox_file_id
                         AND xbs.lbx_file_id = xps.lbx_file_id
                         AND xps.payment_rec_id = xis.payment_rec_id
                         AND xis.inv_trfmd_rec_id = xads.invoice_rec_id);
    COMMIT;
  WHEN others THEN
     print_log('c. Rollback to savepoint ''ls_create_adjst''');
     ROLLBACK TO ls_create_adjst;
     x_adjst_creation_status := 'E';
     lc_sqlerrm := SQLERRM;
	 lc_msg_str := get_error_message_pvt('XXWAR_ERROR_MESSAGES_048'
                                           ,'FILE_ID|SQL_ERRM'
                                           ,p_lockbox_file_id||'|'||lc_sqlerrm);
          print_log(' Unhandled Exception for lockbox file ID : '
                                        || p_lockbox_file_id
                                        || 'Error: '
                                        || lc_sqlerrm);
     UPDATE xxwar_trfmd_adj_dtl_stg
            SET adjustment_error_msg = lc_msg_str                    ,
                     --' Unhandled Exception for lockbox file ID : '|| p_lockbox_file_id|| 'Error: ' || lc_sqlerrm,
                adjustment_status = 'E',
                last_update_date = SYSDATE,
                last_updated_by = fnd_global.user_id,
                last_update_login = fnd_global.login_id
          WHERE adjustment_hdr_id IN (
                   SELECT xads.adjustment_hdr_id
                     FROM xxwar_trfmd_batch_stg xbs,
                          xxwar_trfmd_pymt_stg xps,
                          xxwar_trfmd_invoice_stg xis,
                          xxwar_trfmd_adj_dtl_stg xads
                    WHERE xbs.lbx_file_id = p_lockbox_file_id
                      AND xbs.lbx_file_id = xps.lbx_file_id
                      AND xps.payment_rec_id = xis.payment_rec_id
                      AND xis.inv_trfmd_rec_id = xads.invoice_rec_id);
    COMMIT;
END create_adjustment;

PROCEDURE submit_lockbox_pvt
  (
    x_errbuf                  OUT VARCHAR2,
    x_retcode                 OUT VARCHAR2,
    p_batch_hdr_id             IN VARCHAR2,
    p_lockbox_file_id          IN VARCHAR2,
    p_datafile_path_name       IN VARCHAR2,
    p_controlfile_name         IN VARCHAR2,
    p_transmission_format_name IN VARCHAR2,
    p_lockbox_number           IN VARCHAR2,
    p_organization_name        IN VARCHAR2,
    p_data_fetch_flag          IN VARCHAR2,
    p_auto_adjustments_flag    IN VARCHAR2,
    p_process_status           IN NUMBER,
    p_request_id               IN NUMBER)
IS

TYPE lr_adj_rec
IS
  RECORD
  ( reference_identification xxwar_trfmd_invoice_stg.reference_identification%TYPE,
    adjustment_hdr_id xxwar_trfmd_adj_dtl_stg.adjustment_hdr_id%TYPE,
    adjustment_error_msg xxwar_trfmd_adj_dtl_stg.adjustment_error_msg%TYPE
    ) ;

TYPE lt_adj_rec_tbl_type IS TABLE OF lr_adj_rec;
  lt_adj_dtl_tbl lt_adj_rec_tbl_type;

  lc_conc_prog_submission_flag   VARCHAR2(1) ;
  lc_org_id                      hr_operating_units.organization_id%TYPE;
  lc_lockbox_id                  ar_lockboxes.lockbox_id%TYPE;
  lc_request_id                  fnd_concurrent_requests.request_id%TYPE;
  lc_create_adj_and_fetch_data   VARCHAR2(1) ;
  lc_count_receipts              NUMBER;
  lc_latest_request_id           NUMBER;
  lc_pmt_count                   NUMBER;
  lc_adj_creation_status         VARCHAR2(50) ;
  lc_transmission_format_id      ar_transmission_formats.transmission_format_id%TYPE;
  lc_return_status               VARCHAR2(32000) ;
  lc_status_msg                  VARCHAR2(32000) ;
  lc_phase                       VARCHAR2(50) ;
  lc_devstatus                   VARCHAR2(50) ;
  lc_devphase                    VARCHAR2(50) ;
  lc_transmission_name           VARCHAR2(50) ;
  lc_error_count                 NUMBER := 0;
  lc_error_string                VARCHAR2(32000) ;
  lc_adj_creation_errors         VARCHAR2(32000);
  lc_payment_type                VARCHAR2(50) ;
  lc_status                      VARCHAR2(32000) ;
  lc_processing_unit             VARCHAR2(50) ;
  lc_message                     VARCHAR2(32000) ;
  lc_interim_status              VARCHAR2(32000) ;
  lc_is_trans_name_exists        VARCHAR2(1) := 'Y';
  lc_pymt_count                  NUMBER;
  lc_total_line_count            NUMBER;
  lc_inv_count                   NUMBER;
  lc_prog_call_status            BOOLEAN;
  lc_sec_code                     xxwar_trfmd_pymt_stg.supplemental_payment_field35%TYPE;
  XXWAR_LOCKBOX_SUBMISSION_ERROR EXCEPTION;
  XXWAR_LOCKBOX_VALIDATION_ERROR EXCEPTION;
  XXWAR_REQUEST_INACTIVE         EXCEPTION;
  XXWAR_IMPORT_ERROR_EXCEPTION   EXCEPTION;
  lc_lookup_name                 VARCHAR2(320) ;
  lc_dest_rtn                    xxwar_trfmd_pymt_stg.destination_rtn%TYPE;
  lc_acc_no                      xxwar_trfmd_pymt_stg.destination_account_no%TYPE;
  lc_paymnt_type                 VARCHAR2(50);
  lc_line_count                  NUMBER;
  lc_adj_status                  VARCHAR2(100);
  lc_profile_val                 VARCHAR2(50) := NULL; --  This is part of Issue-63484 for fetching Unearned discount profile value; and included in #ENH72 for the generic purpose
  lc_unearned_disc_param_req     VARCHAR2(50) := NULL; -- Added for #ENH72
  lc_dummy						 varchar2(20) := NULL;-- Added for #ENH72
  CURSOR c_sec_code (p_lockbox_file_id varchar2)
  IS
     SELECT supplemental_payment_field35
	 ,supplemental_payment_field36 -- Added for #ENH72
       FROM xxwar_trfmd_pymt_stg
      WHERE lbx_file_id = p_lockbox_file_id;

BEGIN
   print_log('***************************************');
   print_log('********** Submit Lockbox Log *********');
   print_log('***************************************');
   print_log(' ');
   print_log(' ');
   print_log('Process Status: '||p_process_status);
   BEGIN
         SELECT DISTINCT payment_type
           INTO lc_paymnt_type
           FROM xxwar_trfmd_pymt_stg
          WHERE lbx_file_id	= p_lockbox_file_id;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
              print_log(get_error_message_pvt('XXWAR_ERROR_MESSAGES_053','FILE_ID',p_lockbox_file_id));
         WHEN OTHERS THEN
              print_log(get_error_message_pvt('XXWAR_ERROR_MESSAGES_054','FILE_ID|SQL_ERRM',p_lockbox_file_id||'|'||SQLERRM));
    END;
  IF p_process_status IN (1, 2) THEN /*--1*/

    lc_conc_prog_submission_flag := 'Y';

    BEGIN
       print_log('Fetch Transmission Format ID for Transmission Format name: '
                                       ||p_transmission_format_name);

       SELECT transmission_format_id
         INTO lc_transmission_format_id
         FROM ar_transmission_formats
        WHERE UPPER (format_name) = UPPER (p_transmission_format_name) ;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      lc_error_count := lc_error_count + 1;
      lc_error_string := lc_error_string ||'|'
                         || 'Error '
                         || lc_error_count
						 || ': '
                         || get_error_message_pvt('XXWAR_ERROR_MESSAGES_003','TRANS_FORMAT_NAME',p_transmission_format_name);
       print_log(get_error_message_pvt('XXWAR_ERROR_MESSAGES_003','TRANS_FORMAT_NAME',p_transmission_format_name));

    WHEN OTHERS THEN
      lc_error_count := lc_error_count + 1;
      lc_error_string := lc_error_string ||'|'
                         || 'Error '
                         || lc_error_count
                         || ': '
						 ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_004','TRANS_FORMAT_NAME|SQL_ERRM',p_transmission_format_name||'|'||SQLERRM);
    print_log( 'Error '
                         || lc_error_count
						 || ': '
                         ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_004','TRANS_FORMAT_NAME|SQL_ERRM',p_transmission_format_name||'|'||SQLERRM));

    END;
    BEGIN
        print_log('Fetch Organization ID  for Organization name: '
                                       ||p_organization_name);
	   IF( lc_paymnt_type = 'LBX') THEN
		 lc_lookup_name := 'XXWAR_LBX_ORG_MAPPING';
		 ELSE
		 lc_lookup_name := 'XXWAR_DEST_MICR_ORG_MAPPING';
		 END IF;
	   SELECT organization_id
         INTO lc_org_id
         FROM hr_operating_units
        WHERE name = p_organization_name;
		--lc_lookup_name := decode(substr(p_controlfile_name,length(p_controlfile_name)-2),'LBX','XXWAR_LBX_ORG_MAPPING','XXWAR_DEST_MICR_ORG_MAPPING');

	EXCEPTION
    WHEN NO_DATA_FOUND THEN
     lc_error_count := lc_error_count + 1;
     lc_error_string := lc_error_string ||'|'
                        || 'Error '
                        || lc_error_count
                        || ': '
						|| get_error_message_pvt('XXWAR_ERROR_MESSAGES_005','ORG_NAME|LOOKUP_NAME',p_organization_name||'|'||lc_lookup_name);
      print_log('Error '
                        || lc_error_count
						|| ': '
                        || get_error_message_pvt('XXWAR_ERROR_MESSAGES_005','ORG_NAME|LOOKUP_NAME',p_organization_name||'|'||lc_lookup_name));

    WHEN OTHERS THEN
      lc_error_count := lc_error_count + 1;
      lc_error_string := lc_error_string ||'|'
                         || 'Error '
                         || lc_error_count
                         || ': '
						 || get_error_message_pvt('XXWAR_ERROR_MESSAGES_006','ORG_NAME|SQL_ERRM',p_organization_name||'|'||SQLERRM);
      print_log('Error '
                         || lc_error_count
						 || ': '
                         || get_error_message_pvt('XXWAR_ERROR_MESSAGES_006','ORG_NAME|SQL_ERRM',p_organization_name||'|'||SQLERRM));
    END;

    BEGIN
        print_log('Fetch Lockbox ID  for Lockbox Number: '
                                       ||p_lockbox_number);

     IF( lc_paymnt_type = 'LBX') THEN
          SELECT lockbox_id
            INTO lc_lockbox_id
            FROM ar_lockboxes_all
           WHERE lockbox_number = p_lockbox_number
            AND status = 'A'
            AND org_id = lc_org_id;
     ELSE
        BEGIN
	  SELECT DISTINCT destination_rtn
                ,NVL(master_account_no,destination_account_no)
           INTO lc_dest_rtn
                ,lc_acc_no
           FROM xxwar_trfmd_pymt_stg
	  WHERE lbx_file_id = p_lockbox_file_id;
	EXCEPTION
	     WHEN NO_DATA_FOUND THEN
              print_log('No data found Exception while fetching Account number and destination rtn from xxwar_trfmd_pymt_stg for LBX File id: '||p_lockbox_file_id);
         WHEN OTHERS THEN
              print_log('Unhandled Exception while fecthing Account number and destination rtn from xxwar_trfmd_pymt_stg for LBX File id:'||p_lockbox_file_id || SQLERRM);
        END;
          SELECT ALA.lockbox_id
            INTO lc_lockbox_id
            FROM ce_bank_accounts CBA,
                 ce_bank_branches_v CBBV,
                 ce_bank_acct_uses_all CBAU,
                 ar_lockboxes_all ALA,
                 ar_batch_sources_all ABS
           WHERE CBA.bank_branch_id = CBBV.branch_party_id
             AND CBA.bank_account_id = CBAU.bank_account_id
             AND CBAU.org_id = ALA.org_id
			 AND TRUNC(NVL(cbau.end_date,sysdate+1)) >  TRUNC(sysdate)
             AND ALA.org_id = ABS.org_id
             AND ABS.batch_source_id = ALA.batch_source_id
             AND ABS.remit_bank_acct_use_id = CBAU.bank_acct_use_id
             AND CBBV.branch_number = lc_dest_rtn
             AND CBA.bank_account_num = lc_acc_no
			 AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(CBA.start_date,SYSDATE)) AND TRUNC(NVL(CBA.end_date, SYSDATE ) )
             AND CBAU.org_id = lc_org_id
             AND ALA.lockbox_number = p_lockbox_number
             AND ALA.status = 'A';
     END IF;
	EXCEPTION
    WHEN NO_DATA_FOUND THEN
       lc_error_count := lc_error_count + 1;
       lc_error_string := lc_error_string ||'|'
                         || 'Error '
                         || lc_error_count
                         || ': '
                         || get_error_message_pvt('XXWAR_ERROR_MESSAGES_007','LOCKBOX_NUM|ORG_NAME|BRANCH|ACCOUNT',p_lockbox_number||'|'||p_organization_name||'|'||lc_dest_rtn||'|'||lc_acc_no);
       print_log('Error '
                         || lc_error_count
                         || ': '
                         || get_error_message_pvt('XXWAR_ERROR_MESSAGES_007','LOCKBOX_NUM|ORG_NAME|BRANCH|ACCOUNT',p_lockbox_number||'|'||p_organization_name||'|'||lc_dest_rtn||'|'||lc_acc_no));
    WHEN OTHERS THEN
      lc_error_count := lc_error_count + 1;
      lc_error_string := lc_error_string ||'|'
                         || 'Error '
                         || lc_error_count
						 || ': '
                         ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_008','LOCKBOX_NUM|SQL_ERRM',p_lockbox_number||'|'||SQLERRM);
      print_log( 'Error '
                         || lc_error_count
						 || ': '
                         ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_008','LOCKBOX_NUM|SQL_ERRM',p_lockbox_number||'|'||SQLERRM));
    END ;

    IF lc_transmission_format_id IS NULL /*--2*/
      OR lc_org_id IS NULL
      OR lc_lockbox_id IS NULL THEN
      lc_conc_prog_submission_flag := 'N';
      print_log('Process Submission flag is set to No ');
    END IF;                                    /*--2*/

    IF lc_conc_prog_submission_flag = 'Y' THEN /*--3*/
      FND_REQUEST.SET_ORG_ID (lc_org_id) ;     /*-- For R12*/
      print_log('ORG ID: '||lc_org_id);


         /****************************************************************************
         --Initialize Transmission Name using the sequence xxwar_trans_format_name_seq
         ****************************************************************************/
         BEGIN
          print_log('Fetch Transmission Name ');
              IF( lc_paymnt_type = 'DTD') THEN          /*Enhancement#58718*/
                 SELECT 'WFB' || supplemental_payment_field28
                   INTO lc_transmission_name
                   FROM xxwar_trfmd_pymt_stg
                  WHERE lbx_file_id = p_lockbox_file_id;
              ELSE
                 SELECT 'WFB' || xxwar_trans_format_name_seq.NEXTVAL
                   INTO lc_transmission_name
                   FROM DUAL;
              END IF;
             g_trans_name := lc_transmission_name;
          print_log('Transmission Name: '||lc_transmission_name);
         EXCEPTION
             WHEN NO_DATA_FOUND THEN
               lc_is_trans_name_exists := 'N';
               lc_error_count := lc_error_count + 1;
               lc_error_string :=
                  CONCAT (lc_error_string, '|'||'Error '
                         || lc_error_count
						 || ': '
                         || get_error_message_pvt('XXWAR_ERROR_MESSAGES_009','',''));
              print_log('Error '
                         || lc_error_count
                         || ': '
                         || get_error_message_pvt('XXWAR_ERROR_MESSAGES_009','',''));
             WHEN others THEN
               lc_is_trans_name_exists := 'N';
               lc_error_count := lc_error_count + 1;
               lc_error_string :=
                  CONCAT (lc_error_string, '|'|| 'Error '
                         || lc_error_count
                         || ': '
                         ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_010','SQL_ERRM',SQLERRM));
               print_log('Error '
                         || lc_error_count
                         || ': '
                         || get_error_message_pvt('XXWAR_ERROR_MESSAGES_010','SQL_ERRM',SQLERRM));

         END;
      IF lc_is_trans_name_exists = 'Y' THEN

/* Code Added for #ENH72 */

	  lc_unearned_disc_param_req := fnd_profile.value('XXWAR_UNEARN_DISC_PARAM_REQ');

	  IF lc_unearned_disc_param_req = 'Y' THEN

	  lc_profile_val     := fnd_profile.value('XXWAR_UNEARN_DISCOUNT');   --This is part of Issue-63484 for fetching Unearned discount profile value; and included in #ENH72 for the generic purpose
	  --/*submit lockbox program, ARLPLB using,
/****************************************************************************
                     ARLPLB Concurrent Parameters
                     ===========================
                     1.  NEW_TRANSMISSION           - Yes
                     2.  LB_TRANSMISSION_ID         - Null
                     3.  ORIG_REQUEST_ID            - Null
                     4.  TRANSMISSION_NAME          - Passed from Calling Env.
                     5.  SUBMIT_IMPORT              - Yes
                     6.  DATA_FILE                  - Passed from Calling Env.
                     7.  CNTRL_FILE                 - Passed from Calling Env.
                     8.  TRANSMISSION_FORMAT_ID     - Passed from Calling Env.
                     9.  SUBMIT_VALIDATION          - Yes
                     10. PAY_UNRELATED_INVOICES     - Yes
                     11. LOCKBOX_ID                 - Passed from Calling Env.
                     12. GL_DATE                    - Null
                     13. REPORT_FORMAT              - All
                     14. COMPLETE_BATCHES_ONLY      - Yes
                     15. SUBMIT_POSTBATCH           - Yes
                     16. ALTERNATE_NAME_SEARCH      - Automatic
                     17. IGNORE_INVALID_TXN_NUM     - No
                     18. USSGL_TRANSACTION_CODE     - NUll
                     19. ORG_ID                     - Operating Unit ID
                     20. SUBMISSION_TYPE            - Pass L as argument
                     21. SCORING_MODEL
********************************************************************************/
       print_log('Submit Process Lockbox Standard Concurrent Program');
       lc_request_id := FND_REQUEST.SUBMIT_REQUEST (application  => 'AR'
                                                  , program      => 'ARLPLB'
                                                  , description  => NULL
                                                  , start_time   => NULL
                                                  , sub_request  => FALSE
                                                  , argument1    => 'Y'
                                                  , argument2    => NULL
                                                  , argument3    => NULL
                                                  , argument4    => lc_transmission_name
                                                  , argument5    => 'Y'
                                                  , argument6    => p_datafile_path_name
                                                  , argument7    => p_controlfile_name
                                                  , argument8    => lc_transmission_format_id
                                                  , argument9    => 'Y'
                                                  , argument10   => 'Y'
                                                  , argument11   => lc_lockbox_id
                                                  , argument12   => NULL
                                                  , argument13   => 'A'
                                                  , argument14   => 'N' -- Modified by Venu on 02/24/2014 -- 'Y'
                                                  , argument15   => 'N' -- Modified by Venu on 01/29/2013 -- 'Y'
                                                  , argument16   => 'N'
                                                  , argument17   => 'Y' -- Modified by Venu on 02/20/2013 -- 'N'
												  , argument18   => NULL
                                                  , argument19   => lc_org_id
                                                  , argument20   => lc_profile_val   -- Issue-63484 -Added ny Mahidhar for fetching unearned discount profile value
												  , argument21   => 'L'      --Pass L argument. Don't change this
                                                  , argument22   => NULL
                                                ) ;
                                           -- COMMIT;
	  ELSE
	  print_log('Submit Process Lockbox Standard Concurrent Program if the XXWAR_UNEARN_DISC_PARAM_REQ profile option is NO');
      /*submit lockbox program, ARLPLB using, */
	/* This code logic works; if the XXWAR_UNEARN_DISC_PARAM_REQ profile option is 'N'	*/
/****************************************************************************
                     ARLPLB Concurrent Parameters
                     ===========================
                     1.  NEW_TRANSMISSION           - Yes
                     2.  LB_TRANSMISSION_ID         - Null
                     3.  ORIG_REQUEST_ID            - Null
                     4.  TRANSMISSION_NAME          - Passed from Calling Env.
                     5.  SUBMIT_IMPORT              - Yes
                     6.  DATA_FILE                  - Passed from Calling Env.
                     7.  CNTRL_FILE                 - Passed from Calling Env.
                     8.  TRANSMISSION_FORMAT_ID     - Passed from Calling Env.
                     9.  SUBMIT_VALIDATION          - Yes
                     10. PAY_UNRELATED_INVOICES     - Yes
                     11. LOCKBOX_ID                 - Passed from Calling Env.
                     12. GL_DATE                    - Null
                     13. REPORT_FORMAT              - All
                     14. COMPLETE_BATCHES_ONLY      - Yes
                     15. SUBMIT_POSTBATCH           - Yes
                     16. ALTERNATE_NAME_SEARCH      - Automatic
                     17. IGNORE_INVALID_TXN_NUM     - No
                     18. USSGL_TRANSACTION_CODE     - NUll
                     19. ORG_ID                     - Operating Unit ID
                     20. SUBMISSION_TYPE            - Pass L as argument
                     21. SCORING_MODEL
********************************************************************************/
       print_log('Submit Process Lockbox Standard Concurrent Program');
       lc_request_id := FND_REQUEST.SUBMIT_REQUEST (application  => 'AR'
                                                  , program      => 'ARLPLB'
                                                  , description  => NULL
                                                  , start_time   => NULL
                                                  , sub_request  => FALSE
                                                  , argument1    => 'Y'
                                                  , argument2    => NULL
                                                  , argument3    => NULL
                                                  , argument4    => lc_transmission_name
                                                  , argument5    => 'Y'
                                                  , argument6    => p_datafile_path_name
                                                  , argument7    => p_controlfile_name
                                                  , argument8    => lc_transmission_format_id
                                                  , argument9    => 'Y'
                                                  , argument10   => 'Y'
                                                  , argument11   => lc_lockbox_id
                                                  , argument12   => NULL
                                                  , argument13   => 'A'
                                                  , argument14   => 'N' -- Modified by Venu on 02/24/2014 -- 'Y' 
                                                  , argument15   => 'N' -- Modified by Venu on 01/29/2013 --  'Y'
                                                  , argument16   => 'N'
                                                  , argument17   => 'Y' -- Modified by Venu on 02/20/2013 -- 'N' 
                                                  , argument18   => NULL
                                                  , argument19   => lc_org_id
                                                  , argument20   => 'N'      -- Added by Venu on 01/29/2013 -- Exists above, missing here 
												  , argument21   => 'L'      --Pass L argument. Don't change this
                                                  , argument22   => NULL
                                               ) ;
                                           -- COMMIT;
		END IF; -- Added for #ENH72	If Clause Ended
/* Code Ended for #ENH72 */
      IF lc_request_id <> 0 THEN /*--4*/
        print_log('Process Lockbox Standard Concurrent Program Submitted and request ID: '
                        ||lc_request_id);
        UPDATE xxwar_trfmd_batch_stg
           SET request_id = lc_request_id,
               latest_request_id = lc_request_id,
               process_status = 3,
               transmission_name = lc_transmission_name,
               last_updated_by = fnd_global.user_id,
               last_update_date = sysdate
         WHERE lbx_file_id = p_lockbox_file_id;
        COMMIT;
        print_log('Update XXWAR_TRFMD_BATCH_STG with process status - 3');
        LOOP
          lc_prog_call_status := fnd_concurrent.wait_for_request (request_id => lc_request_id
                                                                , INTERVAL   => 3
                                                                , max_wait   => 10
                                                                , phase      => lc_phase
                                                                , status     => lc_status
                                                                , dev_phase  => lc_devphase
                                                                , dev_status => lc_devstatus
                                                                , MESSAGE    => lc_message) ;
          EXIT
        WHEN lc_devphase IN ('INACTIVE', 'COMPLETE');
        END LOOP;
        IF lc_devphase = 'COMPLETE' THEN
          IF ( (lc_phase = 'Completed' AND lc_status = 'Normal') OR (lc_phase = 'Completed' AND lc_status = 'Warning')) THEN
             g_lbx_request_id        := lc_request_id;
             g_process_status        := 3;
             g_error_string          := lc_error_string;
             g_adj_creation_flag     := 'N';
             g_data_fetch_flag       := 'N';
             g_error_type            := NULL;
             lc_create_adj_and_fetch_data := 'Y';
          ELSE
            print_log('Raise Exception XXWAR_LOCKBOX_SUBMISSION_ERROR - 1');
            RAISE XXWAR_LOCKBOX_SUBMISSION_ERROR;
          END IF;
        ELSE
           print_log('Raise Exception XXWAR_REQUEST_INACTIVE');
           RAISE XXWAR_REQUEST_INACTIVE;
        END IF;
      ELSE
        print_log('Raise Exception XXWAR_LOCKBOX_SUBMISSION_ERROR - 2');
        RAISE XXWAR_LOCKBOX_SUBMISSION_ERROR;
      END IF; /*-- 4*/
      ELSE
        print_log('Raise Exception XXWAR_LOCKBOX_VALIDATION_ERROR - 1');
        RAISE XXWAR_LOCKBOX_VALIDATION_ERROR;
      END IF;
    ELSE
        print_log('Raise Exception XXWAR_LOCKBOX_VALIDATION_ERROR - 2');
        RAISE XXWAR_LOCKBOX_VALIDATION_ERROR;
    END IF;   /*--3*/
  ELSE
    lc_create_adj_and_fetch_data := 'Y';
  END IF; /*--1*/

  IF lc_create_adj_and_fetch_data = 'Y' THEN
    IF p_process_status = '3' THEN /*--6*/
      lc_latest_request_id := p_request_id;
    ELSIF p_process_status IN ('1', '2') THEN
      lc_latest_request_id := lc_request_id;
    END IF; /*--6*/
    /* Get Receipt Count */
    print_log('Transmission Request ID '||lc_latest_request_id);
    BEGIN
       print_log('Fetch Total Receipts Created ');
     /* SELECT COUNT (cash_receipt_id)
        INTO lc_count_receipts
       FROM ar_cash_receipts_all acra,
            ar_transmissions_all atl
      WHERE acra.request_id = atl.latest_request_id
        AND atl.status = 'CL'
        AND atl.latest_request_id = lc_latest_request_id;*/

        SELECT COUNT (cash_receipt_id)
          INTO lc_count_receipts
          FROM ar_cash_receipts_all
         WHERE request_id = lc_latest_request_id
           AND org_id = lc_org_id;

        /* -- commented out by Venu on 02/14/2014
           -- Email notification shows failed in subject line
           -- even when there are no errors

        IF lc_count_receipts = 0 THEN
            SELECT COUNT (1)
              INTO lc_pymt_count
              FROM xxwar_trfmd_pymt_stg
             WHERE lbx_file_id = p_lockbox_file_id;

            SELECT COUNT (invoice_rec_id)
              INTO lc_inv_count
              FROM xxwar_trfmd_invoice_stg tis,
                   xxwar_trfmd_pymt_stg tps
             WHERE tps.payment_rec_id = tis.payment_rec_id
               AND tps.lbx_file_id = p_lockbox_file_id;

            SELECT COUNT (1)
              INTO lc_total_line_count
              FROM ar_payments_interface_all
             WHERE transmission_request_id = lc_latest_request_id
               AND org_id = lc_org_id;

            IF lc_paymnt_type IN ('DTD','IBP') THEN
               lc_line_count := lc_inv_count + 2;
            ELSE
               lc_line_count := lc_pymt_count + lc_inv_count + 2;
            END IF;

            IF lc_line_count = lc_total_line_count THEN
                lc_error_count := lc_error_count + 1;
                lc_error_string := CONCAT (lc_error_string, ' Error '
                                   || lc_error_count
                                   || ': '
                                   || get_error_message_pvt('XXWAR_ERROR_MESSAGES_014','REQUEST_ID',lc_latest_request_id)) ;
                print_log('Error '
                                   || lc_error_count
                                   || ': '
                                   || get_error_message_pvt('XXWAR_ERROR_MESSAGES_014','REQUEST_ID',lc_latest_request_id));
            ELSE
                lc_error_count := lc_error_count + 1;
                lc_error_string := CONCAT (lc_error_string, ' Error '
                                   || lc_error_count
                                   || ': '
                                   || get_error_message_pvt('XXWAR_ERROR_MESSAGES_015','DATAFILE_PATH_NAME|CONTROL_FILE|TRANS_FORMAT_NAME|LOCKBOX_NUM',p_datafile_path_name||'|'||p_controlfile_name||'|'||p_transmission_format_name||'|'||p_lockbox_number) ) ;
                print_log(' Error '
                                   || lc_error_count
                                   || ': '
                                   || get_error_message_pvt('XXWAR_ERROR_MESSAGES_015','DATAFILE_PATH_NAME|CONTROL_FILE|TRANS_FORMAT_NAME|LOCKBOX_NUM',p_datafile_path_name||'|'||p_controlfile_name||'|'||p_transmission_format_name||'|'||p_lockbox_number)  ) ;
                 print_log('Raise Exception XXWAR_IMPORT_ERROR_EXCEPTION');
                RAISE XXWAR_IMPORT_ERROR_EXCEPTION;
            END IF;
        END IF;
        */ -- End of changes by Venu Kandi on 02/14/2014
    END;

    BEGIN
      print_log('Fetch expected Total Receipts count ');
         IF lc_paymnt_type IN ('LBX','ACH','WIR') THEN
		 SELECT lbx_file_payment_count
           INTO lc_pmt_count
           FROM xxwar_trfmd_batch_stg
          WHERE lbx_file_id = p_lockbox_file_id;
        ELSE
		  SELECT count(xis.invoice_rec_id)
		    INTO lc_pmt_count
            FROM xxwar_trfmd_pymt_stg XPS
                 ,xxwar_trfmd_invoice_stg XIS
           WHERE XPS.payment_rec_id = xis.payment_rec_id
             AND XPS.lbx_file_id = p_lockbox_file_id;
        END IF;
          print_log('Expected Total Receipts count '||lc_pmt_count);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      lc_error_count := lc_error_count + 1;
      lc_error_string := CONCAT (lc_error_string, '|'|| ' Error '
                                || lc_error_count
								|| ': '
                                || get_error_message_pvt('XXWAR_ERROR_MESSAGES_051','FILE_ID',p_lockbox_file_id)
								) ;
								--'No Batch exists in the custom Batch table with lockbox file ID: '||p_lockbox_file_id
      print_log( 'Error '
                                || lc_error_count
								|| ': '
                                || get_error_message_pvt('XXWAR_ERROR_MESSAGES_051','FILE_ID',p_lockbox_file_id) );
    WHEN others THEN
      lc_error_count := lc_error_count + 1;
      lc_error_string := CONCAT (lc_error_string, '|'||' Error '
                                || lc_error_count
								|| ': '
                                || get_error_message_pvt('XXWAR_ERROR_MESSAGES_052','SQL_ERRM',SQLERRM)--' unhandled exception on fetchimg the expected recepipt count '
                                 );
      print_log( 'Error '
                                || lc_error_count
								|| ': '
                                || get_error_message_pvt('XXWAR_ERROR_MESSAGES_052','SQL_ERRM',SQLERRM) );

    END;
    IF lc_pmt_count = lc_count_receipts THEN /*--9*/
             g_lbx_request_id        := lc_latest_request_id;
             g_process_status        := 4;
             g_error_string          := lc_error_string;
             g_adj_creation_flag     := 'N';
             g_data_fetch_flag       := 'N';
             g_error_type            := NULL;
       UPDATE xxwar_trfmd_batch_stg
          SET process_status = 4,
              receipt_count = lc_count_receipts
        WHERE lbx_file_id = p_lockbox_file_id;
        COMMIT;
    /* Get Payment Type */
      BEGIN
        SELECT DISTINCT(payment_type)
          INTO lc_payment_type
          FROM xxwar_trfmd_pymt_stg
         WHERE lbx_file_id = p_lockbox_file_id;
      EXCEPTION
       WHEN NO_DATA_FOUND THEN
           lc_error_count := lc_error_count + 1;
           lc_error_string := CONCAT (lc_error_string, '|'||' Error '
                                || lc_error_count
								|| ': '
                                || get_error_message_pvt('XXWAR_ERROR_MESSAGES_053','FILE_ID',p_lockbox_file_id)
								--'Payment type not exits in the xxwar_trfmd_pymt_stg table for lbx_file_id: '|| p_lockbox_file_id
								);
           print_log('Error '
                                || lc_error_count
								|| ': '
                                || get_error_message_pvt('XXWAR_ERROR_MESSAGES_053','FILE_ID',p_lockbox_file_id)
								);
       WHEN others THEN
           lc_error_count := lc_error_count + 1;
           lc_error_string := CONCAT (lc_error_string,'|'|| ' Error '
                                || lc_error_count
								|| ': '
                                || get_error_message_pvt('XXWAR_ERROR_MESSAGES_054','FILE_ID|SQL_ERRM',p_lockbox_file_id||'|'||SQLERRM)
								--'Exception to fetch payment type from custom batch table for lockbox file ID: '||p_lockbox_file_id ||' - ' ||SQLERRM
								) ;
           print_log(' Error '
                                || lc_error_count
								|| ': '
                                || get_error_message_pvt('XXWAR_ERROR_MESSAGES_054','FILE_ID|SQL_ERRM',p_lockbox_file_id||'|'||SQLERRM)
                                ) ;
      END;
	  BEGIN
	   FOR r_sec_code in c_sec_code(p_lockbox_file_id)
	   LOOP

	   lc_sec_code := r_sec_code.supplemental_payment_field35;
	   lc_dummy:=XXWAR_VALIDATE_CUSTOMER_ACH(r_sec_code.supplemental_payment_field36); -- Added for #ENH72
	   print_log(lc_cust_valid_msg);
	   EXIT WHEN lc_sec_code = 'CTX';
       END LOOP;
	  END;
    IF lc_payment_type = 'ACH' AND p_auto_adjustments_flag = 'Y' AND lc_sec_code = 'CTX' THEN         /*--10*/
        /* Call create adjustment procedure with following parameters*/
        print_log('Call Create_adjustment Procedure');

        create_adjustment (p_lockbox_file_id       => p_lockbox_file_id
                         , p_org_id                => lc_org_id
                         , x_adjst_creation_status => lc_adj_creation_status) ;

        print_log('Create_adjustment Procedure completed successfully');
        print_log('Adjustment Creation Status: '||lc_adj_creation_status);
        /*--Call custom data fetch procedure*/
        IF lc_adj_creation_status = 'S' THEN /*--12*/
             g_lbx_request_id        := lc_latest_request_id;
             g_process_status        := 6;
             g_error_string          := lc_error_string;
             g_adj_creation_flag     := 'Y';
             g_data_fetch_flag       := 'N';
             g_error_type            := NULL;
          IF p_data_fetch_flag = 'Y' THEN
              print_log('Call load_custom_data Procedure');

              load_custom_data (p_lbx_file_id => p_lockbox_file_id
                              , x_return_status => lc_return_status
                              , x_error_msg =>lc_status_msg
                                            ) ;
             print_log('Load Custom data Procedure completed successfully ');
             print_log('Custom data fetch status: '||lc_return_status);

             IF lc_return_status = 'S' THEN /*--14*/
                g_lbx_request_id        := lc_latest_request_id;
                g_process_status        := 8;
                g_error_string          := lc_error_string;
                g_adj_creation_flag     := 'Y';
                g_data_fetch_flag       := 'Y';
                g_error_type            := NULL;
             ELSE
                g_lbx_request_id        := lc_latest_request_id;
                g_process_status        := 9;
                g_error_string          := lc_error_string||' | '||lc_status_msg;
                g_adj_creation_flag     := 'Y';
                g_data_fetch_flag       := 'E';
                g_error_type            := 'DATA_FETCH_ERROR';

               print_log('Custom data fetch Error Message: '||lc_status_msg);
             END IF;
          END IF;
        ELSE
            print_log('Fetch Adjustment Creation Error Messages');
          BEGIN
               SELECT xti.reference_identification,
                      xtad.adjustment_hdr_id,
                      xtad.adjustment_error_msg
                 BULK COLLECT INTO lt_adj_dtl_tbl
                 FROM xxwar_trfmd_adj_dtl_stg xtad,
                      xxwar_trfmd_invoice_stg xti,
                      xxwar_trfmd_pymt_stg xtp
                WHERE xti.inv_trfmd_rec_id = xtad.invoice_rec_id
                  AND xtad.adjustment_status = 'E'
                  AND xtp.payment_rec_id = xti.payment_rec_id
                AND xtp.lbx_file_id = p_lockbox_file_id ;
            --print_out(get_error_message_pvt('XXWAR_ERROR_MESSAGES_058','','') ) ; --'** Adjustments Creation Errors **'
            lc_adj_creation_errors := '<<< Adjustments Creation Errors >>> |';
            FOR adj_ndx IN lt_adj_dtl_tbl.FIRST .. lt_adj_dtl_tbl.LAST
            LOOP
              lc_adj_creation_errors := lc_adj_creation_errors
                                        || 'Invoice Number:'||lt_adj_dtl_tbl (adj_ndx).reference_identification
                                        || ' - '
                                        || 'Adjustment Header ID:'||lt_adj_dtl_tbl (adj_ndx).adjustment_hdr_id
                                        || ' | '
                                        ||lt_adj_dtl_tbl (adj_ndx).adjustment_error_msg
                                        || '|';
            END LOOP;
            print_log(lc_adj_creation_errors);
          EXCEPTION
          WHEN OTHERS THEN
           lc_error_count := lc_error_count + 1;
           lc_error_string := CONCAT (lc_error_string,'|'|| 'Error '
                                || lc_error_count
								|| ': '
                                || get_error_message_pvt('XXWAR_ERROR_MESSAGES_055','SQL_ERRM',SQLERRM)
								--'Exception to fetch Adjustment Creation Error Messages: '
                                ) ;
           print_log('Error '
                                || lc_error_count
								|| ': '
                                || get_error_message_pvt('XXWAR_ERROR_MESSAGES_055','SQL_ERRM',SQLERRM)
								--'Exception to fetch Adjustment Creation Error Messages: '||' - '||SQLERRM
								);
          END;
             g_lbx_request_id        := lc_latest_request_id;
             g_process_status        := 7;
             g_error_string          := SUBSTR(lc_adj_creation_errors,1,length(lc_adj_creation_errors)-1);
             g_adj_creation_flag     := 'E';
             g_data_fetch_flag       := 'N';
             g_error_type            := 'ADJ_CREATION_ERROR';
        END IF;                                                          /*--12*/
    ELSE
        IF  lc_payment_type = 'ACH' AND lc_sec_code = 'CTX' THEN
		  lc_error_string := CONCAT (lc_error_string,'|'|| 'Error : '
                                || lc_error_count
                                || get_error_message_pvt('XXWAR_ERROR_MESSAGES_016','','')) ;
          print_log( get_error_message_pvt('XXWAR_ERROR_MESSAGES_016','','')) ;
        END IF;
      IF p_data_fetch_flag = 'Y' THEN /*--17*/
        print_log('Call load_custom_data Procedure');

        load_custom_data (p_lbx_file_id => p_lockbox_file_id
                              , x_return_status => lc_return_status
                              , x_error_msg =>lc_status_msg);

        print_log('Load Custom data Procedure completed successfully ');
        print_log('Custom data fetch status: '||lc_return_status);

         IF lc_return_status = 'S' THEN /*--18*/
            g_lbx_request_id        := lc_latest_request_id;
            g_process_status        := 8;
            g_error_string          := lc_error_string;
            g_adj_creation_flag     := 'N';
            g_data_fetch_flag       := 'Y';
            g_error_type            := NULL;
         ELSE
            g_lbx_request_id        := lc_latest_request_id;
            g_process_status        := 9;
            g_error_string          := lc_error_string||' | '||lc_status_msg;
            g_adj_creation_flag     := 'N';
            g_data_fetch_flag       := 'E';
            g_error_type            := 'DATA_FETCH_ERROR';
            print_log('Custom data fetch Error Message: '||lc_status_msg);
         END IF; /*--18*/
      ELSE
            print_log( get_error_message_pvt('XXWAR_ERROR_MESSAGES_017','','')) ;
            g_lbx_request_id        := lc_latest_request_id;
            g_process_status        := 4;
            g_error_string          := get_error_message_pvt('XXWAR_ERROR_MESSAGES_017','','');
            g_adj_creation_flag     := 'N';
            g_data_fetch_flag       := 'N';
            g_error_type            := NULL;
      END IF;  /*--17*/
    END IF;   /*--11*/
    ELSE
        g_lbx_request_id        := lc_latest_request_id;
        g_process_status        := 5;
        g_error_string          := lc_error_string
                                   ||' | '
                                   ||get_error_message_pvt('XXWAR_ERROR_MESSAGES_056','REQUEST_ID',lc_latest_request_id);
								   --'Expected total receipts were not created. Plese refer outfile of request ID: '||lc_latest_request_id || ' for more details'
         g_adj_creation_flag     := 'N';
         g_data_fetch_flag       := 'N';
         g_error_type            := 'RCPT_CREATION_ERROR';
      UPDATE XXWAR_TRFMD_BATCH_STG
         SET process_status = 5,
             receipt_count = lc_count_receipts
       WHERE lbx_file_id = p_lockbox_file_id;
    COMMIT;
    END IF; /*--9*/
  END IF; /*--10*/
  /*--Issuing COMMIT is the responsibility of the calling environment/program*/
             UPDATE xxwar_trfmd_batch_stg
                SET process_status = g_process_status           ,
                    request_id = g_lbx_request_id                 ,
                    latest_request_id = g_lbx_request_id,
                    transmission_name = g_trans_name,
                    adjustment_creation_flag = g_adj_creation_flag,
                    data_fetch_flag = g_data_fetch_flag           ,
                    error_msg = g_error_string   ,
                    error_type = g_error_type,
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
EXCEPTION
WHEN XXWAR_LOCKBOX_VALIDATION_ERROR THEN
         g_lbx_request_id        := 0;
         g_process_status        := 2;
         g_error_string          := get_error_message_pvt('XXWAR_ERROR_MESSAGES_057','','')||lc_error_string; --Validation Failure
         g_adj_creation_flag     := 'N';
         g_data_fetch_flag       := 'N';
         g_error_type            := 'RCPT_CREATION_ERROR';

             UPDATE xxwar_trfmd_batch_stg
                SET process_status = g_process_status           ,
                    request_id = g_lbx_request_id                 ,
                    latest_request_id = g_lbx_request_id,
                    transmission_name = g_trans_name,
                    adjustment_creation_flag = g_adj_creation_flag,
                    data_fetch_flag = g_data_fetch_flag           ,
                    error_msg = g_error_string   ,
                    error_type = g_error_type,
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;


WHEN XXWAR_LOCKBOX_SUBMISSION_ERROR THEN
  IF lc_request_id = 0 THEN
     g_lbx_request_id        := 0;
     g_process_status        := 2;
     g_error_string          := get_error_message_pvt('XXWAR_ERROR_MESSAGES_011','','')||lc_error_string;
     g_adj_creation_flag     := 'N';
     g_data_fetch_flag       := 'N';
     g_error_type            := 'RCPT_CREATION_ERROR';

  ELSE
     g_lbx_request_id        := lc_request_id;
     g_process_status        := 2;
     g_error_string          := get_error_message_pvt('XXWAR_ERROR_MESSAGES_012','','')||lc_error_string;
     g_adj_creation_flag     := 'N';
     g_data_fetch_flag       := 'N';
     g_error_type            := 'RCPT_CREATION_ERROR';
  END IF;
             UPDATE xxwar_trfmd_batch_stg
                SET process_status = g_process_status           ,
                    request_id = g_lbx_request_id                 ,
                    latest_request_id = g_lbx_request_id,
                    transmission_name = g_trans_name,
                    adjustment_creation_flag = g_adj_creation_flag,
                    data_fetch_flag = g_data_fetch_flag           ,
                    error_msg = g_error_string   ,
                    error_type = g_error_type,
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
WHEN XXWAR_REQUEST_INACTIVE THEN
     g_lbx_request_id        := lc_request_id;
     g_process_status        := 3;
     g_error_string          := get_error_message_pvt('XXWAR_ERROR_MESSAGES_013','','')||lc_error_string;
     g_adj_creation_flag     := 'N';
     g_data_fetch_flag       := 'N';
     g_error_type            := 'RCPT_CREATION_ERROR';
             UPDATE xxwar_trfmd_batch_stg
                SET process_status = g_process_status           ,
                    request_id = g_lbx_request_id                 ,
                    latest_request_id = g_lbx_request_id,
                    transmission_name = g_trans_name,
                    adjustment_creation_flag = g_adj_creation_flag,
                    data_fetch_flag = g_data_fetch_flag           ,
                    error_msg = g_error_string   ,
                    error_type = g_error_type,
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
WHEN XXWAR_IMPORT_ERROR_EXCEPTION THEN
     g_lbx_request_id        := lc_request_id;
     g_process_status        := 10;
     g_error_string          := lc_error_string;
     g_adj_creation_flag     := 'N';
     g_data_fetch_flag       := 'N';
     g_error_type            := 'RCPT_CREATION_ERROR';
             UPDATE xxwar_trfmd_batch_stg
                SET process_status = g_process_status           ,
                    request_id = g_lbx_request_id                 ,
                    latest_request_id = g_lbx_request_id,
                    transmission_name = g_trans_name,
                    adjustment_creation_flag = g_adj_creation_flag,
                    data_fetch_flag = g_data_fetch_flag           ,
                    error_msg = g_error_string   ,
                    error_type = g_error_type,
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;

WHEN others THEN
     g_lbx_request_id        := lc_request_id;
     g_process_status        := 2;
     g_error_string          := 'Unhandled Exception '
	                            || '-'
                                ||SQLERRM
                                ||'  '
                                ||lc_error_string ;
     g_adj_creation_flag     := 'N';
     g_data_fetch_flag       := 'N';
     g_error_type            := 'RCPT_CREATION_ERROR';
             UPDATE xxwar_trfmd_batch_stg
                SET process_status = g_process_status           ,
                    request_id = g_lbx_request_id                 ,
                    latest_request_id = g_lbx_request_id,
                    transmission_name = g_trans_name,
                    adjustment_creation_flag = g_adj_creation_flag,
                    data_fetch_flag = g_data_fetch_flag           ,
                    error_msg = g_error_string   ,
                    error_type = g_error_type,
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
END submit_lockbox_pvt;
/* Load Custom Data*/


/*--Overloaded procedure. This will be called by concurrent program  XXWAR_TRFR_ADDL_INFO*/
PROCEDURE load_custom_data
  (
    errbuf OUT VARCHAR2,
    retcode OUT NUMBER,
    p_batch_name IN VARCHAR2
  )
IS
  CURSOR c_lbx_file_id ( p_transmission_name VARCHAR2 ) IS
   SELECT lbx_file_id
     FROM xxwar_trfmd_batch_stg
    WHERE transmission_name = p_transmission_name;

  lc_return_status VARCHAR2(1);
  lc_error_msg     varchar2(32000);
  ln_latest_request_id NUMBER;
BEGIN
   print_log('******************************************************');
   print_log('******* WFAdapter Additional Data load Report ********');
   print_log('******************************************************');
   FOR r_lbx_file_id IN c_lbx_file_id(p_batch_name)
   LOOP
      load_custom_data
              (p_lbx_file_id    => r_lbx_file_id.lbx_file_id,
               x_return_status  => lc_return_status,
               x_error_msg      => lc_error_msg
              );
     IF lc_return_status = 'S' THEN
        BEGIN
            SELECT latest_request_id
              INTO ln_latest_request_id
              FROM ar_transmissions_all
             WHERE transmission_name = p_batch_name
               AND org_id = fnd_global.org_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                 print_log('Error while fetching the latest request id.Please check the batch name entered');
            WHEN others THEN
                  print_log('Unexpected error while fetching the latest request id.Please check the batch name entered '
                                                  || SQLERRM);
        END;
        UPDATE xxwar_trfmd_batch_stg
           SET process_status = '8'
               ,data_fetch_flag = 'Y'
               ,error_msg = NULL
               ,error_type = NULL
               ,latest_request_id = nvl(ln_latest_request_id,latest_request_id)
               ,last_update_date = SYSDATE
               ,last_updated_by = fnd_global.user_id
               ,last_update_login = fnd_global.login_id
            WHERE lbx_file_id = r_lbx_file_id.lbx_file_id;
        COMMIT;
        print_log('Additional Data Transfer is complete for Transmission Name: '||p_batch_name);
     ELSE
        print_log('Failure to Transfer Additional Data for Transmission Name'||p_batch_name);
        print_log('Error Message: '||lc_error_msg);
     END IF;

   END LOOP;

END load_custom_data;
/* Create Adjust ments*/

/*Overload Procedure. Called by concurrent program */
PROCEDURE create_adjustment
  ( errbuf       OUT  VARCHAR2,
    retcode      OUT  VARCHAR2,
    p_batch_name IN   VARCHAR2)
IS
  CURSOR c_lbx_file_id ( p_transmission_name VARCHAR2 ) IS
   SELECT lbx_file_id
     FROM xxwar_trfmd_batch_stg
    WHERE transmission_name = p_transmission_name;

  lc_adj_creation_status VARCHAR2(1);
  ln_latest_request_id NUMBER;
BEGIN
   print_log('******************************************************');
   print_log('******* WFAdapter Adjustments Creation Report ********');
   print_log('******************************************************');
   FOR r_lbx_file_id IN c_lbx_file_id(p_batch_name)
   LOOP
      create_adjustment (p_lockbox_file_id       => r_lbx_file_id.lbx_file_id
                         , p_org_id                => fnd_global.org_id
                         , x_adjst_creation_status => lc_adj_creation_status) ;
     IF lc_adj_creation_status = 'S' THEN
        print_log('Creation of adjustments is completed successfully for Transmission Name: '
                                       ||p_batch_name);
        BEGIN
            SELECT latest_request_id
              INTO ln_latest_request_id
              FROM ar_transmissions_all
             WHERE transmission_name = p_batch_name
               AND org_id = fnd_global.org_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                 print_log('Error while fetching the latest request id.Please check the batch name entered');
            WHEN others THEN
                  print_log('Unexpected error while fetching the latest request id.Please check the batch name entered '
                                                  || SQLERRM);
        END;
        UPDATE XXWAR_TRFMD_BATCH_STG
           SET process_status = 6,
               adjustment_creation_flag = 'Y',
               latest_request_id = nvl(ln_latest_request_id,latest_request_id),
               last_update_date = SYSDATE,
               last_updated_by  = fnd_global.user_id,
               last_update_login = fnd_global.login_id
         WHERE lbx_file_id = r_lbx_file_id.lbx_file_id;
        COMMIT;
     ELSE
        print_log('Failure to create Adjustments for Transmission Name'||p_batch_name);
     END IF;
   END LOOP;
END create_adjustment;
/* written by ujjwala. need review again.*/
/*--Procedure to update Transformed Adjustment Stg Table*/
PROCEDURE update_adjustment
                       (p_adj_hdr_id         IN  NUMBER,
                        p_adj_error          IN  VARCHAR2,
                        p_status             IN  VARCHAR2,
                        p_base_table_adj_id  IN  NUMBER
)
IS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
 UPDATE xxwar_trfmd_adj_dtl_stg
    SET adjustment_status = p_status           ,
        adjustment_error_msg = SUBSTR(p_adj_error, 1 , 4000),
        base_tbl_adjustment_id = p_base_table_adj_id,
        last_update_date = SYSDATE               ,
        last_updated_by = fnd_global.user_id     ,
        last_update_login = fnd_global.login_id
  WHERE adjustment_hdr_id = p_adj_hdr_id;


 COMMIT;
END update_adjustment;
/*--Procedure to update Transformed Adjustment Stg Table*/
PROCEDURE update_batch_stg
  (
    p_lockbox_file_id IN NUMBER,
    p_status          IN NUMBER)
IS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   UPDATE xxwar_trfmd_batch_stg
      SET process_status = p_status
    WHERE lbx_file_id = p_lockbox_file_id;
  COMMIT;
END update_batch_stg;

PROCEDURE update_adjustment
  (
    p_adjustment_id     IN NUMBER,
    p_adjustment_error  IN VARCHAR2,
    p_status            IN VARCHAR2,
    p_base_table_adj_id IN NUMBER)
IS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   UPDATE xxwar_trfmd_adj_dtl_stg
      SET adjustment_status = p_status           ,
          adjustment_error_msg = p_adjustment_error,
          base_tbl_adjustment_id = p_base_table_adj_id
    WHERE adjustment_id = p_adjustment_id;
  COMMIT;
END update_adjustment;

FUNCTION xxwar_get_receipt_date (p_invoice_rec_id NUMBER)
      RETURN DATE
   AS
      ld_effective_date   xxwar_pymt_stg.effective_date%TYPE;

      CURSOR c_receipt_date (p_invoice_rec_id NUMBER)
      IS
         SELECT xps.effective_date
           FROM xxwar_trfmd_pymt_stg xps, xxwar_trfmd_invoice_stg xis
          WHERE xps.payment_rec_id = xis.payment_rec_id
            AND xis.invoice_rec_id = p_invoice_rec_id
            AND ROWNUM < 2;
   BEGIN
      OPEN c_receipt_date (p_invoice_rec_id);

      FETCH c_receipt_date
       INTO ld_effective_date;

      CLOSE c_receipt_date;

      RETURN ld_effective_date;
   END xxwar_get_receipt_date;

 FUNCTION xxwar_DTD_get_receipt_date (p_invoice_rec_id NUMBER)
       RETURN DATE
   AS
   ld_effective_date   xxwar_pymt_stg.effective_date%TYPE;
   CURSOR c_dtd_receipt_date (p_invoice_rec_id NUMBER)
      IS
		  SELECT xps.effective_date
           FROM xxwar_trfmd_pymt_stg xps, xxwar_trfmd_invoice_stg xis,xxwar_supp_invoice_stg xsis
          WHERE xps.payment_rec_id = xis.payment_rec_id
            AND xsis.supplemental_rec_id = p_invoice_rec_id
            AND xis.invoice_rec_id = xsis.invoice_rec_id
            AND ROWNUM < 2;
   CURSOR c_receipt_date (p_invoice_rec_id NUMBER)
      IS
         SELECT xps.effective_date
           FROM xxwar_trfmd_pymt_stg xps, xxwar_trfmd_invoice_stg xis
          WHERE xps.payment_rec_id = xis.payment_rec_id
            AND xis.invoice_rec_id = p_invoice_rec_id
            AND ROWNUM < 2;
   BEGIN
     OPEN c_receipt_date (p_invoice_rec_id);
     FETCH c_receipt_date
       INTO ld_effective_date;
      IF c_receipt_date%NOTFOUND THEN
       OPEN c_dtd_receipt_date(p_invoice_rec_id);
	   FETCH c_dtd_receipt_date
	   INTO ld_effective_date;
	   CLOSE c_dtd_receipt_date;
      END IF;
      CLOSE c_receipt_date;
    RETURN ld_effective_date;
   END xxwar_DTD_get_receipt_date;

   FUNCTION xxwar_derive_inv_amt (p_invoice_rec_id NUMBER, p_amt_paid NUMBER)
      RETURN NUMBER
   AS
      lc_adjustment_exists_flag   VARCHAR2 (1)                         := 'N';

      CURSOR c_adj_exists (p_invoice_rec_id NUMBER)
      IS
         SELECT 'Y'
           FROM xxwar_adj_dtl_stg
          WHERE invoice_rec_id = p_invoice_rec_id;

      CURSOR c_total_adj_amt (p_invoice_rec_id NUMBER)
      IS
         SELECT SUM (adjustment_amount)
           FROM xxwar_adj_dtl_stg
          WHERE invoice_rec_id = p_invoice_rec_id;

      CURSOR c_check_for_inv_blank_amt (p_invoice_rec_id NUMBER)
      IS
         SELECT amount_paid, payment_rec_id
           FROM xxwar_invoice_stg
          WHERE invoice_rec_id = p_invoice_rec_id;

      CURSOR c_inv_count_and_pymt_amount (p_payment_rec_id NUMBER)
      IS
         SELECT   COUNT (xis.invoice_rec_id), xps.payment_amount
             FROM xxwar_invoice_stg xis, xxwar_pymt_stg xps
            WHERE xis.payment_rec_id = p_payment_rec_id
              AND xps.payment_rec_id = xis.payment_rec_id
         GROUP BY xps.payment_amount;

      ln_total_adjustment_amt     xxwar_adj_dtl_stg.adjustment_amount%TYPE;
      ln_amount_paid              xxwar_invoice_stg.amount_paid%TYPE;
      ln_payment_rec_id           xxwar_pymt_stg.payment_rec_id%TYPE;
      ln_invoice_count            NUMBER;
      ln_pymt_amount              xxwar_pymt_stg.payment_amount%TYPE;
      lc_inv_num                  xxwar_trfmd_invoice_stg.reference_identification%TYPE;  --Issue:65174
   BEGIN
      ln_total_adjustment_amt := 0;
      --Start of code for Issue:65174
             lc_inv_num := xxwar_receipts_pkg.xxwar_validate_invoice(p_invoice_rec_id);
        IF lc_inv_num IS NOT NULL THEN  --end of code for Issue:65174
           OPEN c_check_for_inv_blank_amt (p_invoice_rec_id);
           FETCH c_check_for_inv_blank_amt
            INTO ln_amount_paid, ln_payment_rec_id;

               OPEN c_inv_count_and_pymt_amount (ln_payment_rec_id);
              FETCH c_inv_count_and_pymt_amount
               INTO ln_invoice_count, ln_pymt_amount;
              CLOSE c_inv_count_and_pymt_amount;

              IF ln_amount_paid = 0 THEN
                 IF ln_invoice_count = 1 THEN
                    RETURN (ln_pymt_amount);
                 ELSE
                    RETURN (ln_amount_paid);
                 END IF;
              ELSIF ln_amount_paid <> 0 THEN
                 OPEN c_adj_exists (p_invoice_rec_id);
                FETCH c_adj_exists
                 INTO lc_adjustment_exists_flag;

                  IF c_adj_exists%FOUND THEN
                      OPEN c_total_adj_amt (p_invoice_rec_id);
                     FETCH c_total_adj_amt
                      INTO ln_total_adjustment_amt;
                     CLOSE c_total_adj_amt;

                     RETURN (ln_amount_paid + ln_total_adjustment_amt);
                  ELSIF c_adj_exists%NOTFOUND THEN
                    IF ln_pymt_amount = 0  THEN
                      RETURN (0);
                    ELSE
                      RETURN (ln_amount_paid);
                    END IF;
                  END IF;
                CLOSE c_adj_exists;
              END IF;
           CLOSE c_check_for_inv_blank_amt;
        ELSE                     --Issue:65174
            RETURN NULL;
        END IF;
   END xxwar_derive_inv_amt;

   FUNCTION xxwar_lbx_derive_rcpt_num (p_payment_rec_id NUMBER)
      RETURN VARCHAR2
   IS
      CURSOR c_derive_receipt_number (p_payment_rec_id IN NUMBER)
      IS
       SELECT   xps.supplemental_payment_field2          -- Check Number
             || xps.supplemental_payment_field1          --Lock Box Number
             || TO_CHAR (xfs.file_date, 'RRMMDD')              -- File Date
        FROM xxwar_pymt_stg xps, xxwar_batch_stg xbs, xxwar_file_stg xfs
       WHERE xps.batch_hdr_id = xbs.batch_hdr_id
         AND xbs.file_number = xfs.file_number
         AND xps.payment_rec_id = p_payment_rec_id;

      lc_derived_receipt_number   VARCHAR2 (240);
      l_seq_num                   NUMBER;
      lc_check_num                xxwar_pymt_stg.supplemental_payment_field2%TYPE;
   BEGIN
      BEGIN
       SELECT xps.supplemental_payment_field2          -- Check Number
        INTO  lc_check_num
         FROM xxwar_pymt_stg xps,
              xxwar_batch_stg xbs,
              xxwar_file_stg xfs
        WHERE xps.batch_hdr_id = xbs.batch_hdr_id
          AND xbs.file_number = xfs.file_number
          AND xps.payment_rec_id = p_payment_rec_id;
      EXCEPTION
        WHEN others THEN
         lc_check_num := NULL;
      END;
    IF lc_check_num IS NOT NULL THEN
        RETURN lc_check_num;
    ELSE
        OPEN c_derive_receipt_number (p_payment_rec_id);
       FETCH c_derive_receipt_number
        INTO lc_derived_receipt_number;
       CLOSE c_derive_receipt_number;
      /* Added by Srinandini,12-08-2009 on 'AR Receipt number uniqueness' */
      BEGIN
        SELECT XXWAR_RECEIPT_NUMBER_SEQ.nextval
          INTO l_seq_num
          FROM Dual;
      END;
        lc_derived_receipt_number := lc_derived_receipt_number||l_seq_num;
       /* EOA 12-08-2009 */
        RETURN (lc_derived_receipt_number);
    END IF;
   END xxwar_lbx_derive_rcpt_num;

   /*Added by Raguraman, 08-OCT-2008  Referenece : Phase 2 BRD V1.2 Point : 4.2.1.2*/
   FUNCTION xxwar_ach_derive_rcpt_num (p_payment_rec_id NUMBER)
      RETURN VARCHAR2
   IS
      CURSOR c_derive_receipt_number (p_payment_rec_id IN NUMBER)
      IS
         /* Commented by Srinandini,12-08-2009 on 'AR Receipt number uniqueness' */
	 	 /* SELECT    xps.supplemental_payment_field39           -- Trace Number
                || CHR (45)
                || TO_CHAR (xfs.file_date, 'RRMMDD')              -- File Date
           FROM xxwar_pymt_stg xps, xxwar_batch_stg xbs, xxwar_file_stg xfs
          WHERE xps.batch_hdr_id = xbs.batch_hdr_id
            AND xbs.file_number = xfs.file_number
            AND xps.payment_rec_id = p_payment_rec_id; */
           /* Added by Srinandini,12-08-2009 */
	 SELECT xps.supplemental_payment_field39           -- Trace Number
           FROM xxwar_pymt_stg xps, xxwar_batch_stg xbs, xxwar_file_stg xfs
          WHERE xps.batch_hdr_id = xbs.batch_hdr_id
            AND xbs.file_number = xfs.file_number
            AND xps.payment_rec_id = p_payment_rec_id;

          /* EOA 12-08-2009 */

      lc_derived_receipt_number   VARCHAR2 (240);

   BEGIN
      OPEN c_derive_receipt_number (p_payment_rec_id);

      FETCH c_derive_receipt_number
       INTO lc_derived_receipt_number;

      CLOSE c_derive_receipt_number;

      IF LENGTH(lc_derived_receipt_number) > 12 THEN                --Enhancement#66480
         lc_derived_receipt_number := SUBSTR(lc_derived_receipt_number,-12);
      END IF;

      RETURN (lc_derived_receipt_number);
   END xxwar_ach_derive_rcpt_num;

   /*Added by Raguraman, 08-OCT-2008  Referenece : Phase 2 BRD V1.2 Point : 4.2.1.3*/
  /* commented for Enhancement#65531 new function with same name is added below.
   FUNCTION xxwar_dtd_derive_rcpt_num (p_invoice_rec_id NUMBER)
      RETURN VARCHAR2
   IS
      CURSOR c_derive_receipt_number (p_invoice_rec_id IN NUMBER)
      IS
         SELECT    xsis.supplemental_invoice_field24    -- Deposited Check ID
                || CHR (45)
                || TO_CHAR (xfs.file_date, 'RRMMDD')              -- File Date
                ,xsis.supplemental_invoice_field24
           FROM xxwar_pymt_stg xps,
                xxwar_batch_stg xbs,
                xxwar_file_stg xfs,
                xxwar_invoice_stg xis,
                xxwar_supp_invoice_stg xsis
          WHERE xps.batch_hdr_id = xbs.batch_hdr_id
            AND xbs.file_number = xfs.file_number
            AND xps.payment_rec_id = xis.payment_rec_id
            AND xsis.invoice_rec_id = xis.invoice_rec_id
            AND xsis.supplemental_rec_id = p_invoice_rec_id;  --Added by Ramesh on 20/01/2009 . Adapter should passs supplemental record id for DTD alone. Adapter is writing only one SI into final data file depending on configurable parameter. That SI supplemental rec id should be passed here
            --AND xis.invoice_rec_id = p_invoice_rec_id
            --AND ROWNUM < 2;        --Commented by Ramesh. Irrespective of matching option number (i.e either policy number or tenant ID), query is returning first row

      lc_derived_receipt_number   VARCHAR2(240);
      lc_sup_inv24                VARCHAR2(240);
   BEGIN
      OPEN c_derive_receipt_number (p_invoice_rec_id);

      FETCH c_derive_receipt_number
       INTO lc_derived_receipt_number
            ,lc_sup_inv24;

      CLOSE c_derive_receipt_number;

      IF lc_sup_inv24 IS NULL THEN    -- Issue:63993 Start of enhancement code
         SELECT 'WFDTD'||XXWAR_DTD_RCPT_NUM_SEQ.NEXTVAL
         INTO lc_derived_receipt_number
         FROM DUAL;
        RETURN (lc_derived_receipt_number); -- Issue:63993 end of enhancement code
      ELSE
        RETURN (lc_derived_receipt_number);
      END IF;
   END xxwar_dtd_derive_rcpt_num;*/
   FUNCTION xxwar_dtd_derive_rcpt_num (p_check_num VARCHAR2)   --Enhancement#65531
      RETURN VARCHAR2
   IS
     lc_derived_receipt_number   VARCHAR2(240);
   BEGIN
      IF p_check_num IS NULL THEN    -- Issue:63993 Start of enhancement code
         SELECT 'WFDTD'||XXWAR_DTD_RCPT_NUM_SEQ.NEXTVAL
         INTO lc_derived_receipt_number
         FROM DUAL;
        RETURN (lc_derived_receipt_number); -- Issue:63993 end of enhancement code
      ELSE
        RETURN (p_check_num);
      END IF;
   END xxwar_dtd_derive_rcpt_num;
   --Added by Sudheer on 12/Feb/2009
   FUNCTION xxwar_lbx_derive_batch_num (p_payment_rec_id NUMBER)
      RETURN VARCHAR2
   IS
      CURSOR c_derive_batch_number (p_payment_rec_id IN NUMBER)
      IS
         SELECT    xbs.batch_number
           FROM xxwar_trfmd_pymt_stg xps
              , xxwar_trfmd_batch_stg xbs
          WHERE xps.lbx_file_id = xbs.lbx_file_id
            AND xps.payment_rec_id = p_payment_rec_id;

      lc_derived_batch_number   VARCHAR2 (240);
   BEGIN
      OPEN c_derive_batch_number (p_payment_rec_id);

      FETCH c_derive_batch_number
       INTO lc_derived_batch_number;

      CLOSE c_derive_batch_number;

      RETURN (lc_derived_batch_number);
   END xxwar_lbx_derive_batch_num;
   --End added by Sudheer on 12/Feb/2009
    FUNCTION xxwar_validate_invoice (p_invoice_rec_id NUMBER)
      RETURN VARCHAR2
    IS
       CURSOR c_inv_details (p_invoice_rec_id IN NUMBER)
       IS
         SELECT HOU.organization_id
               ,TIS.reference_identification
           FROM xxwar_trfmd_batch_stg TBS,
                xxwar_trfmd_pymt_stg TPS,
                xxwar_trfmd_invoice_stg TIS,
                hr_operating_units HOU
          WHERE HOU.name = TBS.organization_name
            AND TBS.lbx_file_id = TPS.lbx_file_id
            AND tps.payment_rec_id = TIS.payment_rec_id
            AND TIS.invoice_rec_id = p_invoice_rec_id;

       CURSOR c_validate_invoice (p_invoice IN VARCHAR2, p_org_id IN NUMBER)
       IS
       SELECT  COUNT(1)
         FROM  ra_customer_trx_all RA
        WHERE  RA.complete_flag='Y'
          AND  RA.trx_number = p_invoice
          AND  RA.org_id = p_org_id;
    lc_inv_count NUMBER :=0 ;
    --lc_invoice_num ra_customer_trx_all.trx_number%TYPE;
	  lc_invoice_num VARCHAR2(50); --Issue#TCS9-Added by Mahidhar to generate WIR receipts batches even Invoice Number is longer than 20 characters.


   BEGIN
      FOR r_inv_details IN c_inv_details (p_invoice_rec_id) LOOP
          OPEN   c_validate_invoice (r_inv_details.reference_identification,r_inv_details.organization_id);
         FETCH  c_validate_invoice
          INTO   lc_inv_count;
         CLOSE  c_validate_invoice;
         lc_invoice_num := r_inv_details.reference_identification;
      END LOOP;
   IF lc_inv_count >=1 THEN
      RETURN (lc_invoice_num);
   ELSE
      RETURN NULL;
   END IF;

   END xxwar_validate_invoice;
   FUNCTION xxwar_dtd_misc_derive_rcpt_num (p_invoice_rec_id NUMBER)
      RETURN VARCHAR2
   IS
      CURSOR c_derive_receipt_number (p_invoice_rec_id IN NUMBER)
      IS
         SELECT /*   xsis.supplemental_invoice_field24    -- Deposited Check ID
                || CHR (45)
                || TO_CHAR (xfs.file_date, 'RRMMDD')              -- File Date commented for Enhancement#65531 */
                xsis.supplemental_invoice_field30         -- SI24 IS changed to SI30 for Enhancement#65531
           FROM xxwar_pymt_stg xps,
                xxwar_trfmd_batch_stg xbs,
                xxwar_file_stg xfs,
                xxwar_trfmd_invoice_stg xis,
                xxwar_trfmd_supp_invoice_stg xsis
          WHERE xps.batch_hdr_id = xbs.batch_hdr_id
            AND xbs.file_number = xfs.file_number
            AND xps.payment_rec_id = xis.payment_rec_id
            AND xsis.invoice_rec_id = xis.inv_trfmd_rec_id
            AND xsis.supplemental_rec_id = p_invoice_rec_id;
      lc_derived_receipt_number   VARCHAR2 (240);
 --     lc_sup_inv24                VARCHAR2(240);
   BEGIN
      OPEN c_derive_receipt_number (p_invoice_rec_id);

      FETCH c_derive_receipt_number
       INTO lc_derived_receipt_number;
          -- ,lc_sup_inv24; --commented for Enhancement#65531

      CLOSE c_derive_receipt_number;

      IF lc_derived_receipt_number IS NULL THEN         -- Issue:63993 Start of enhancement code
         SELECT 'WFDTD'||XXWAR_DTD_RCPT_NUM_SEQ.NEXTVAL
         INTO lc_derived_receipt_number
         FROM DUAL;
        RETURN (lc_derived_receipt_number);              -- Issue:63993 end of enhancement code
      ELSE
        RETURN (lc_derived_receipt_number);
      END IF;
   END xxwar_dtd_misc_derive_rcpt_num;
Procedure misc_receipts(p_user_name               IN VARCHAR2,
                        p_resp_name               IN VARCHAR2,
                        p_lockbox_file_id         IN NUMBER,
                        p_organization_name       IN VARCHAR2,
                        p_receipts_created        OUT NUMBER,
                        p_receipts_failed         OUT NUMBER,
                        p_logfile                 OUT VARCHAR2,
                        p_outfile                 OUT VARCHAR2,
                        p_error_string            OUT VARCHAR2,
                        p_error_count             OUT NUMBER,
                        p_process_status          OUT NUMBER,
                        p_email_ids               OUT VARCHAR2,
                        p_error_type              OUT VARCHAR2
	)
IS
    lc_user_id                      fnd_user.user_id%TYPE;
    lc_resp_id                      fnd_responsibility_tl.responsibility_id%TYPE;
    lc_resp_appl_id                 fnd_responsibility_tl.application_id%TYPE;
    lc_request_id                   NUMBER;
    lc_apps_init_flag               VARCHAR2 (1)                          := 'N';
    lc_error_count                  NUMBER                                := 0;
    lc_error_string                 VARCHAR2 (32000) ;
    lc_logfile                      fnd_concurrent_requests.logfile_name%TYPE;
    lc_outfile                      fnd_concurrent_requests.outfile_name%TYPE;
    lc_org_id                       hr_operating_units.organization_id%TYPE;
    lc_process_status               xxwar_trfmd_batch_stg.process_status%TYPE;
    WF_APPS_INITIALIZATION_ERROR    EXCEPTION;
    lb_set_profile                  BOOLEAN;
    lc_prog_call_status	            BOOLEAN;
    lc_devphase                     VARCHAR2 (50)                         := 'NO_PHASE';
    lc_phase                        VARCHAR2 (50) ;
    lc_status                       VARCHAR2 (50) ;
    lc_devstatus                    VARCHAR2 (50)                         := NULL;
    lc_message                      VARCHAR2 (4000) ;
    ln_receipts_created             NUMBER                                := 0;
    ln_receipts_failed              NUMBER                                := 0;
    lc_email_ids                    VARCHAR2(32000)                       := NULL;
    lc_payment_type                 VARCHAR2(15)                          := NULL;
    lc_pymt_flag                    VARCHAR2(1)                           := 'N';
    lc_sqlerrm                      VARCHAR2(32000);
    lc_err_message                  VARCHAR2(32000)                      :=NULL;

 CURSOR c_user_id (p_user_name IN VARCHAR2)
  IS
     SELECT user_id
       FROM fnd_user fu
      WHERE UPPER (user_name) = UPPER (p_user_name)
        AND TRUNC (SYSDATE) BETWEEN fu.start_date AND NVL (fu.end_date, TRUNC (SYSDATE)) ;

  CURSOR c_org_id (p_org_name VARCHAR2)
  IS
     SELECT organization_id
       FROM hr_operating_units
      WHERE name = p_org_name;

  CURSOR c_resp_appl_id (p_resp_name IN VARCHAR2)
  IS
     SELECT ftl.responsibility_id,
            ftl.application_id
       FROM fnd_responsibility_tl ftl,
            fnd_responsibility fr
      WHERE UPPER (responsibility_name) LIKE UPPER (p_resp_name)
        AND ftl.responsibility_id = fr.responsibility_id
        AND TRUNC (SYSDATE) BETWEEN fr.start_date AND NVL (fr.end_date, TRUNC (SYSDATE)) ;

BEGIN
   /****************************************************************************
  --         Get Email Id's
  ****************************************************************************/
   --print_log('cllaing get_emailid procedure');
   xxwar_receipts_pkg.get_emailids(p_org_name => p_organization_name,
                                   p_email_ids => lc_email_ids,
                                   p_error_msg => lc_error_string			   );
   BEGIN
      lc_email_ids := substr(rtrim(lc_email_ids,','),1,249);
      UPDATE xxwar_trfmd_batch_stg
         SET org_mail_ids  = lc_email_ids,
             last_update_date = SYSDATE,
             last_updated_by = fnd_global.user_id,
             last_update_login = fnd_global.login_id
       WHERE lbx_file_id = p_lockbox_file_id;

   EXCEPTION
    WHEN OTHERS THEN
         print_log('Unhandled wxception whlie updating xxwar_trfmd_batch_stg '||SQLERRM);
   END;
  /****************************************************************************
  --         Get User ID
  ****************************************************************************/
  BEGIN
    OPEN c_user_id (p_user_name) ;
    FETCH c_user_id INTO lc_user_id;
    IF c_user_id%NOTFOUND THEN
      lc_error_count := lc_error_count + 1;
      lc_error_string := CONCAT (lc_error_string, '|'|| 'Error '
                                 || lc_error_count
                                 || ': '
                                 || get_error_message_pvt('XXWAR_ERROR_MESSAGES_001','USER_NAME',p_user_name)) ;
    END IF;
    CLOSE c_user_id;
  END;

   /****************************************************************************
  --         Get ORGANIZATION ID
  *************************************************** *************************/
  BEGIN
     OPEN c_org_id(p_organization_name);
      FETCH c_org_id INTO lc_org_id;
       IF c_org_id%NOTFOUND THEN
         lc_error_count := lc_error_count + 1;
         lc_error_string := CONCAT (lc_error_string, '|'|| 'Error '
                                 || lc_error_count
                                 || ': '
                                 || get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_018','','')) ;
       END IF;
     CLOSE c_org_id;
  END;


  /****************************************************************************
  --         Get Responsibility ID and Application ID
  *************************************************** *************************/
  BEGIN
    OPEN c_resp_appl_id (p_resp_name) ;
    FETCH c_resp_appl_id INTO lc_resp_id, lc_resp_appl_id;
    IF c_resp_appl_id%NOTFOUND THEN
      lc_error_count := lc_error_count + 1;
      lc_error_string := CONCAT (lc_error_string, '|'|| 'Error '
                                 || lc_error_count
                                 || ': '
                                 || get_error_message_pvt('XXWAR_ERROR_MESSAGES_002','RESP_NAME',p_resp_name)) ;
    END IF;
    CLOSE c_resp_appl_id;
  END;

  IF (lc_resp_id IS NOT NULL)
    AND (lc_resp_appl_id IS NOT NULL)
    AND (lc_user_id IS NOT NULL) THEN
     fnd_global.apps_initialize (user_id          => lc_user_id,
                                resp_id          => lc_resp_id,
                                resp_appl_id     => lc_resp_appl_id) ;
     mo_global.init ('AR') ;
     lc_apps_init_flag := 'Y';

  ELSE
    RAISE WF_APPS_INITIALIZATION_ERROR;
  END IF;

  BEGIN
     SELECT DISTINCT(payment_type)
       INTO lc_payment_type
       FROM xxwar_trfmd_pymt_stg
      WHERE lbx_file_id = p_lockbox_file_id;
  EXCEPTION
      WHEN NO_DATA_FOUND THEN
           lc_error_count := lc_error_count + 1;
           lc_error_string := CONCAT (lc_error_string, 'Error '
                                                       || lc_error_count
                                                       || ': '
                                                       || get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_019','FILE_ID',p_lockbox_file_id));
													   --Payment Type not found for the following file id : FILE_ID
           lc_pymt_flag := 'Y';
      WHEN OTHERS THEN
           lc_error_count := lc_error_count + 1;
           lc_error_string := CONCAT (lc_error_string, 'Error '
                                                       || lc_error_count
                                                       || ': '
                                                       || get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_020','FILE_ID',p_lockbox_file_id));
           lc_pymt_flag := 'Y';
  END;

  IF lc_apps_init_flag = 'Y' AND lc_pymt_flag = 'N' THEN
     FND_REQUEST.SET_ORG_ID (lc_org_id) ;
     lc_request_id := FND_REQUEST.SUBMIT_REQUEST (    application  => xxwar_cust_appl.gc_appl_short_name
                                                     ,program      => 'XXWAR_MISC_RECEIPTS_PVT'
                                                     ,description  => NULL
                                                     ,start_time   => NULL
                                                     ,sub_request  => FALSE
                                                     ,argument1    => NULL
                                                     ,argument2    => p_lockbox_file_id
                                                     ,argument3    => lc_payment_type
                                                  ) ;
  END IF;
  IF lc_request_id <> 0 THEN
    COMMIT;
    LOOP
        lc_prog_call_status := fnd_concurrent.wait_for_request (request_id => lc_request_id
                                                                , phase      => lc_phase
                                                                , status     => lc_status
                                                                , dev_phase  => lc_devphase
                                                                , dev_status => lc_devstatus
                                                                , MESSAGE    => lc_message) ;
        EXIT
        WHEN lc_devphase IN ('INACTIVE', 'COMPLETE');
    END LOOP;
        IF lc_devphase = 'COMPLETE' THEN
          BEGIN
            SELECT process_status
                  ,misc_rcpt_created_count
                  ,misc_rcpt_failed_count
                  --,error_msg
              INTO lc_process_status
                  ,ln_receipts_created
                  ,ln_receipts_failed
                  --,lc_err_message
              FROM xxwar_trfmd_batch_stg
             WHERE lbx_file_id = p_lockbox_file_id;
          EXCEPTION
           WHEN NO_DATA_FOUND THEN
               lc_error_count := lc_error_count + 1;
               lc_error_string := CONCAT (lc_error_string, 'Error '
                                 || lc_error_count
                                 || ': '
                                 ||get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_021','FILE_ID',p_lockbox_file_id));
								 --No record available in the xxwar_trfmd_batch_stg table with file ID:
           WHEN OTHERS THEN
               lc_error_count := lc_error_count + 1;
               lc_error_string := CONCAT (lc_error_string, 'Error '
                                 || lc_error_count
                                 || ': '
                                 || get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_022','FILE_ID|SQL_ERRM',p_lockbox_file_id||'|'||SQLERRM));
								 --Unhandled excepion while fetching the process status from the batch trfmd tables with file ID
          END ;
          BEGIN
           SELECT logfile_name,
                  outfile_name
             INTO lc_logfile,
                  lc_outfile
             FROM fnd_concurrent_requests
            WHERE request_id = lc_request_id;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              lc_logfile      := NULL;
              lc_outfile      := NULL;
              lc_error_count  := lc_error_count + 1;
              lc_error_string := CONCAT (lc_error_string, 'Error '
                                 || lc_error_count
                                 || ': '
                                 || get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_023','REQUEST_ID',g_lbx_request_id));
								 --- No Out and Log where generated for XXWAR Miscellaneous Receipt Creation program request ID:
            WHEN OTHERS THEN
              lc_logfile := NULL;
              lc_outfile := NULL;
              lc_error_count := lc_error_count + 1;
              lc_error_string := CONCAT (lc_error_string, 'Error '
                                 || lc_error_count
                                 || ': '
                                 || get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_024','REQUEST_ID|SQL_ERRM',g_lbx_request_id||'|'||SQLERRM));
								 --Unhandled Exception to fetch path to Log and Out file of XXWAR Miscellaneous Receipt Creation request ID
          END ;

          IF ( (lc_phase = 'Completed' AND lc_status = 'Normal') OR (lc_phase = 'Completed' AND lc_status = 'Warning')) THEN
            UPDATE xxwar_trfmd_batch_stg
                SET request_id = lc_request_id             ,
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
	      COMMIT;
                  p_receipts_created  := ln_receipts_created;
                  p_receipts_failed   := ln_receipts_failed;
                  p_logfile           := lc_logfile;
                  p_outfile           := lc_outfile;
                  p_error_string      := lc_err_message;
                  p_error_count       := lc_error_count;
                  p_process_status    := lc_process_status;
                  p_email_ids         := lc_email_ids;
                  p_error_type        := 'MISC_RCPT_CREATION_ERROR';

          ELSE
              p_error_string      := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_025'
                                                             ,'REQUEST_ID'
                                                             ,lc_request_id);
                                    --XXWAR Miscellaneous Receipt Creation concurrent request:||lc_request_id||' is Completed with Error status';
			 UPDATE xxwar_trfmd_batch_stg
                SET process_status = 5           ,
                    request_id = lc_request_id             ,
                    error_msg = substr(p_error_string,1,2000),
					--'XXWAR Miscellaneous Receipt Creation concurrent request: ||lc_request_id|| is Completed with Error status'
                    error_type = 'MISC_RCPT_CREATION_ERROR',
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
              p_receipts_created  := ln_receipts_created;
              p_receipts_failed   := ln_receipts_failed;
              p_logfile           := lc_logfile;
              p_outfile           := lc_outfile;
              p_error_count       := lc_error_count;
              p_process_status    := 5;
              p_email_ids         := lc_email_ids;
              p_error_type        := 'MISC_RCPT_CREATION_ERROR';
          END IF;
        ELSE
             p_error_string      := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_026'
                                                           ,'REQUEST_ID'
                                                           ,lc_request_id) ;
             --' XXWAR Miscellaneous Receipt Creation concurrent request: '||lc_request_id||' status is Inactive. Please check your concurrent managers. '
			 UPDATE xxwar_trfmd_batch_stg
                SET process_status = 5           ,
                    request_id = lc_request_id             ,
                    error_msg = substr(p_error_string,1,2000),
                    --' XXWAR Miscellaneous Receipt Creation concurrent request: '||lc_request_id||' status is Inactive. Please check your concurrent managers. '
                    error_type = 'MISC_RCPT_CREATION_ERROR',
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
              p_receipts_created  := ln_receipts_created;
              p_receipts_failed   := ln_receipts_failed;
              p_logfile           := lc_logfile;
              p_outfile           := lc_outfile;
              p_error_count       := lc_error_count;
              p_process_status    := 5;
              p_email_ids         := lc_email_ids;
              p_error_type        := 'MISC_RCPT_CREATION_ERROR';
        END IF;
   ELSE
       lc_sqlerrm := SQLERRM;
       p_error_string      := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_027','','')||lc_sqlerrm;
	   UPDATE xxwar_trfmd_batch_stg
          SET process_status = 5           ,
              request_id = lc_request_id             ,
              error_msg = substr(p_error_string||lc_sqlerrm,1,2000),
              --Concurrent Request "XXWAR Miscellaneous Receipt Creation" failed to submit
              error_type = 'MISC_RCPT_CREATION_ERROR',
              last_update_date = SYSDATE,
              last_updated_by = fnd_global.user_id,
              last_update_login = fnd_global.login_id
        WHERE lbx_file_id = p_lockbox_file_id;
         p_receipts_created  := ln_receipts_created;
         p_receipts_failed   := ln_receipts_failed;
         p_logfile           := lc_logfile;
         p_outfile           := lc_outfile;
         p_error_count       := lc_error_count;
         p_process_status    := 5;
         p_email_ids         := lc_email_ids;
         p_error_type        := 'MISC_RCPT_CREATION_ERROR';
   END IF;

  COMMIT;

  EXCEPTION
  WHEN WF_APPS_INITIALIZATION_ERROR THEN
             p_error_string      := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_028','','')||lc_error_string;
             UPDATE xxwar_trfmd_batch_stg
                SET process_status = 5           ,
                    error_msg = substr(p_error_string||lc_error_string  ,1,2000),
                    --'Apps Session could not be Initialized. '
                    error_type = 'INITIALIZATION_ERROR',
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
              p_receipts_created  := ln_receipts_created;
              p_receipts_failed   := ln_receipts_failed;
              p_logfile           := lc_logfile;
              p_outfile           := lc_outfile;
              p_error_count       := lc_error_count;
              p_process_status    := 5;
              p_email_ids         := lc_email_ids;
              p_error_type        := 'INITIALIZATION_ERROR';
  WHEN OTHERS THEN
            lc_sqlerrm := SQLERRM;
            p_error_string      := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_029'
                                                           ,'SQL_ERRM'
                                                           ,lc_sqlerrm) ||' '||lc_error_string;
                                   --Unhandled Exception
            UPDATE xxwar_trfmd_batch_stg
                SET process_status = 5           ,
                    error_msg = substr(p_error_string||' '||lc_error_string  ,1,2000),
                    --Unhandled Exception
                    error_type = 'MISC_RCPT_CREATION_ERROR',
                    last_update_date = SYSDATE,
                    last_updated_by = fnd_global.user_id,
                    last_update_login = fnd_global.login_id
              WHERE lbx_file_id = p_lockbox_file_id;
              COMMIT;
              p_receipts_created  := ln_receipts_created;
              p_receipts_failed   := ln_receipts_failed;
              p_logfile           := lc_logfile;
              p_outfile           := lc_outfile;
              p_error_count       := lc_error_count;
              p_process_status    := 5;
              p_email_ids         := lc_email_ids;
              p_error_type        := 'MISC_RCPT_CREATION_ERROR';

 END misc_receipts;

 PROCEDURE misc_receipts_pvt(
                          x_errbuf             OUT VARCHAR2
                         ,x_retcode            OUT VARCHAR2
                         ,p_organization_name  IN  VARCHAR2
                         ,p_lockbox_file_id    IN  NUMBER
                         ,p_payment_type       IN  VARCHAR2
                       	)
IS
   -- variables declared FOR API
    lc_api_version                    NUMBER;
    lc_init_msg_list                  VARCHAR2(200);
    lc_commit                         VARCHAR2(200);
    lc_validation_level               NUMBER;
    x_return_status                   VARCHAR2(200);
    x_msg_count                       NUMBER;
    x_msg_data                        VARCHAR2(200);
    lc_usr_currency_code              VARCHAR2(200);
    lc_currency_code                  VARCHAR2(200);
    lc_usr_exchange_rate_type         VARCHAR2(200);
    lc_exchange_rate_type             VARCHAR2(200);
    lc_exchange_rate                  NUMBER;
    lc_exchange_rate_date             DATE;
    lc_amount                         NUMBER;
    lc_receipt_number                 VARCHAR2(200);
    lc_receipt_date                   DATE;
    lc_gl_date                        DATE;
    lc_receivables_trx_id             NUMBER;
    lc_misc_payment_source            VARCHAR2(200);
    lc_tax_code                       VARCHAR2(200);
    lc_vat_tax_id                     VARCHAR2(200);
    lc_tax_rate                       NUMBER;
    lc_tax_amount                     NUMBER;
    lc_deposit_date                   DATE;
    lc_reference_type                 VARCHAR2(200);
    lc_reference_num                  VARCHAR2(200);
    lc_reference_id                   NUMBER;
    lc_remittance_bank_account_id     NUMBER;
    lc_remittance_bank_account_num    VARCHAR2(200);
    lc_remit_bank_acc_name            VARCHAR2(200);
    lc_receipt_method_id              NUMBER;
    lc_receipt_method_name            VARCHAR2(200);
    lc_doc_sequence_value             NUMBER;
    lc_ussgl_transaction_code         VARCHAR2(200);
    lc_anticipated_clearing_date      DATE;
    lc_attribute_record               AR_RECEIPT_API_PUB.attribute_rec_type;
    lc_global_attribute_record        AR_RECEIPT_API_PUB.global_attribute_rec_type;
    lc_comments                       VARCHAR2(200);
    lc_misc_receipt_id                NUMBER;
    lc_called_from                    VARCHAR2(200);
    lc_error_string                   VARCHAR2 (32000) ;
    TYPE lc_attribute_tbl IS TABLE OF AR_RECEIPT_API_PUB.attribute_rec_type INDEX BY BINARY_INTEGER;
    attribute_tbl_var  lc_attribute_tbl;
    -- Variables FOR MISC processing
    --
    ln_payment_amount               xxwar_trfmd_pymt_stg.payment_amount%TYPE;
    lc_receipt_method               fnd_lookup_values.meaning%TYPE;
    lc_activity                     fnd_lookup_values.description%TYPE;
    lc_error_count                  NUMBER := 0;
    lc_receipt_success_count        NUMBER := 0;
    lc_receipt_failed_count         NUMBER := 0;
    ln_rel_count                    NUMBER := 0;
    ld_effective_date               DATE;
    lc_destination_account_no       xxwar_trfmd_pymt_stg.destination_account_no%TYPE;
    ln_payment_rec_id               xxwar_trfmd_invoice_stg.payment_rec_id%TYPE;
    lc_supp_payment_field33         xxwar_trfmd_pymt_stg.supplemental_payment_field33%TYPE;
    lc_destination_rtn              xxwar_trfmd_pymt_stg.destination_rtn%TYPE;
    ln_supplemental_rec_id          xxwar_trfmd_supp_invoice_stg.supplemental_rec_id%TYPE;
    lc_supp_invoice_field21         xxwar_trfmd_supp_invoice_stg.supplemental_invoice_field21%TYPE;
    lc_wir_receipt_num              xxwar_trfmd_pymt_stg.supplemental_payment_field33%TYPE;
    lc_master_account_no            VARCHAR2(35);
    lc_return_status                VARCHAR2(1);
    lc_status_msg                   VARCHAR2(32000) ;
    lc_error_flag                   VARCHAR2(1):='N';
    lc_error_msg                    VARCHAR2(32000);
    ln_inv_trfmd_rec_id             NUMBER;
    lc_amount_paid_cur_flag         NUMBER := 0;
    ln_count                        NUMBER := 0;
    lc_sqlerrm                      VARCHAR2(32000);
    ln_cur_count                    NUMBER;
    lc_org_name                     VARCHAR2(240);
    lc_date                         DATE;
    lc_string                       VARCHAR2(4000);
    lc_bank_acct_use_id             ce_bank_acct_uses.bank_acct_use_id%TYPE;
    lc_org_id                       hr_operating_units.organization_id%TYPE;
	ln_attr_rec                     NUMBER := 0;
    lc_error_api_msg                VARCHAR2(2000);
    lc_batch_error_msg              VARCHAR2(4000);
	lc_dtd_matching_key             VARCHAR2(400);
    lc_updated_flag                 VARCHAR2(4) := 'N';
    TYPE r_cursor is REF CURSOR;
    c_amount_paid r_cursor;
    c_receipts_details r_cursor;


    CURSOR cur_bank_acct_id (p_lbx_file_id NUMBER)
        IS
          SELECT DISTINCT master_account_no
                ,destination_rtn
           FROM xxwar_trfmd_pymt_stg
          WHERE lbx_file_id = p_lbx_file_id;
  BEGIN
        /****************************************************************************
          --         Get ORGANIZATION ID AND ORG NAME
         *****************************************************************************/
	BEGIN
          SELECT XTBS.organization_name
                ,HOU.organization_id
            INTO lc_org_name
                ,lc_org_id
            FROM xxwar_trfmd_batch_stg XTBS
                 ,hr_operating_units HOU
           WHERE XTBS.lbx_file_id = p_lockbox_file_id
             AND HOU.name =XTBS.organization_name;
          FND_REQUEST.SET_ORG_ID (lc_org_id) ;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
	       print_log(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_015','',''));
			        ---'Unable to fetch organization name '
          WHEN OTHERS THEN
               print_log(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_016','',''));
			   --Unhandled Exception while fetching organization name
        END;


        BEGIN
         UPDATE  xxwar_trfmd_invoice_stg
            SET  misc_rcpt_status = NULL
                ,error_msg = NULL
                ,last_updated_by = fnd_global.user_id
                ,last_update_login = fnd_global.login_id
                ,last_update_date = SYSDATE
          WHERE payment_rec_id IN (SELECT payment_rec_id
                                     FROM xxwar_trfmd_pymt_stg
                                    WHERE lbx_file_id = p_lockbox_file_id)
            AND NVL(misc_rcpt_status,'X') = 'E';
         COMMIT;
        EXCEPTION
         WHEN OTHERS THEN
              print_log('Unhandled Exception while updating xxwar_trfmd_invoice_stg'||SQLERRM);
        END;
        BEGIN
           UPDATE xxwar_trfmd_batch_stg
              SET latest_request_id = fnd_global.conc_request_id
            WHERE lbx_file_id = p_lockbox_file_id;
           COMMIT;
        EXCEPTION
          WHEN OTHERS THEN
               print_log('Unhandled Exception while updating xxwar_trfmd_batch_stg '||SQLERRM);
        END;
        BEGIN
         UPDATE xxwar_trfmd_pymt_stg
            SET misc_rcpt_status = NULL
                ,error_msg = NULL
                ,last_updated_by = fnd_global.user_id
                ,last_update_login = fnd_global.login_id
                ,last_update_date = SYSDATE
          WHERE lbx_file_id = p_lockbox_file_id
            AND NVL(misc_rcpt_status,'X') = 'E';
         COMMIT;
        EXCEPTION
          WHEN OTHERS THEN
               print_log('Unhandled Exception while updating xxwar_trfmd_pymt_stg'||SQLERRM);
        END;

        /*SELECT name
          INTO lc_org_name
          FROM hr_organization_units
         WHERE organization_id = fnd_global.org_id;*/

        print_out(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_038','',''));--                                      ----------------------------------------------------
        print_out(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_039','',''));--                                            Miscellaneous Receipts creation Report
        print_out(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_038','',''));--                                      ----------------------------------------------------
        print_out('                                            ');
        print_out('                                            ');
        print_out('Organization Name:'||lc_org_name );
        print_out('                                            ');
       BEGIN
          SELECT FLV.meaning receipt_method
                 ,FLV.description activity
            INTO lc_receipt_method
                 ,lc_activity
            FROM fnd_lookup_values flv
                 ,fnd_application FA
           WHERE lookup_type = 'XXWAR_MISC_RECEIPT_PMT_TYPE'
             AND enabled_flag = 'Y'
             AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(start_date_active,SYSDATE)) AND TRUNC(NVL(end_date_active, SYSDATE ) )
             AND LANGUAGE = USERENV('LANG')
             AND FLV.view_application_id = FA.application_id
             AND FA.application_short_name = 'AR'
             AND FLV.lookup_code = p_payment_type;


            IF lc_activity IS NOT NULL THEN
              BEGIN
                 SELECT receivables_trx_id
                   INTO lc_receivables_trx_id
                   FROM ar_receivables_trx_all
                  WHERE name = lc_activity
                    AND org_id = lc_org_id;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                     lc_error_msg := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_001','ACTIVITY_NAME|ORG_NAME',lc_activity||'|'||lc_org_name);
                     print_log(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_001','ACTIVITY_NAME|ORG_NAME',lc_activity||'|'||lc_org_name));
                     lc_error_flag := 'Y';
                WHEN OTHERS THEN
                    lc_error_msg := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_002','ACTIVITY_NAME|ORG_NAME',lc_activity||'|'||lc_org_name);
                    print_log(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_002','ACTIVITY_NAME|ORG_NAME',lc_activity||'|'||lc_org_name));
                    lc_error_flag := 'Y';
              END;
            ELSE
              lc_error_msg :=  get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_009','PAYMENT_TYPE',p_payment_type)||lc_error_msg ;
              print_log(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_009','PAYMENT_TYPE',p_payment_type));
              lc_error_flag := 'Y';
            END IF;

            IF lc_receipt_method IS NOT NULL THEN
              BEGIN
                SELECT receipt_method_id
                  INTO lc_receipt_method_id
                  FROM ar_receipt_methods
                 WHERE name = lc_receipt_method;
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                     lc_error_msg := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_003','PAYMENT_METHOD|ORG_NAME',lc_receipt_method||'|'||lc_org_name)||'  '||lc_error_msg ;
                     print_log(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_003','PAYMENT_METHOD|ORG_NAME',lc_receipt_method||'|'||lc_org_name));
                     lc_error_flag := 'Y';
                WHEN OTHERS THEN
                     lc_error_msg := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_004','PAYMENT_METHOD|ORG_NAME',lc_receipt_method||'|'||lc_org_name)||SQLERRM ||'|'||lc_error_msg;
                     print_log(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_004','PAYMENT_METHOD|ORG_NAME',lc_receipt_method||'|'||lc_org_name) || SQLERRM);
                     lc_error_flag := 'Y';
              END;
            ELSE
              lc_error_msg :=  get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_012','PAYMENT_TYPE',p_payment_type)||'  '||lc_error_msg ;
              print_log(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_012','PAYMENT_TYPE',p_payment_type));
              lc_error_flag := 'Y';
            END IF;

       EXCEPTION
	    WHEN no_data_found THEN
                 lc_error_msg := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_010','PAYMENT_TYPE',p_payment_type)||'  '||lc_error_msg ;
                 print_log(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_010','PAYMENT_TYPE',p_payment_type));
                 lc_error_flag := 'Y';
	    WHEN others THEN
                 lc_error_msg := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_010','PAYMENT_TYPE',p_payment_type)||SQLERRM||'  '||lc_error_msg ;
                 print_log(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_010','PAYMENT_TYPE',p_payment_type)||SQLERRM);
                 lc_error_flag := 'Y';
       END;


       FOR rec_bank_acct_id IN cur_bank_acct_id(p_lockbox_file_id) LOOP
         BEGIN
	  /*fetching account_id for misc receipt creation */
           SELECT ABA.bank_account_id
             INTO lc_remittance_bank_account_id
             FROM ce_bank_accounts ABA
                  ,ce_bank_branches_v CBBV
            WHERE bank_account_num = rec_bank_acct_id.master_account_no
              AND ABA.bank_branch_id = CBBV.branch_party_id
              AND CBBV.branch_number = rec_bank_acct_id.destination_rtn;

            BEGIN
                SELECT CBAU.bank_acct_use_id
                  INTO lc_bank_acct_use_id
                  FROM ar_receipt_method_accounts_all ARMC,
                       ce_bank_accounts CBA,
                       ce_bank_acct_uses_all CBAU
                  WHERE ARMC.receipt_method_id = lc_receipt_method_id
                    AND CBA.bank_account_id = lc_remittance_bank_account_id
                    AND CBA.bank_account_id = CBAU.bank_account_id
                    AND ARMC.remit_bank_acct_use_id = CBAU.bank_acct_use_id
                    AND ARMC.org_id = lc_org_id
                    AND TRUNC(NVL(ARMC.end_date,SYSDATE+1)) >= SYSDATE;
                  IF lc_bank_acct_use_id IS NULL THEN
                     lc_string := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_007','ACC_NUMBER|PAYMENT_METHOD'
                                                                                       ,rec_bank_acct_id.master_account_no
                                                                                        ||'|'
                                                                                        ||lc_receipt_method||'outer QUERY');
                     print_log(lc_string);

                     UPDATE xxwar_trfmd_pymt_stg
                        SET misc_rcpt_status = 'E',
                            error_msg = SUBSTR(lc_string||'  '||lc_error_msg,1,4000)
                      WHERE lbx_file_id = p_lockbox_file_id
                        AND master_account_no = rec_bank_acct_id.master_account_no
                        AND destination_rtn = rec_bank_acct_id.destination_rtn;

                     IF p_payment_type IN ('DTD','IBP') THEN
                        UPDATE  xxwar_trfmd_invoice_stg
                           SET  misc_rcpt_status = 'E'
                               ,error_msg = SUBSTR(lc_string||'  '||lc_error_msg,1,4000)
                               ,last_updated_by = fnd_global.user_id
                               ,last_update_login = fnd_global.login_id
                               ,last_update_date = SYSDATE
                          WHERE payment_rec_id IN (SELECT payment_rec_id
                                                     FROM xxwar_trfmd_pymt_stg
                                                    WHERE lbx_file_id = p_lockbox_file_id
                                                      AND misc_rcpt_status = 'E');
                     END IF;
                     COMMIT;
                  END IF;

            EXCEPTION
	       WHEN NO_DATA_FOUND THEN
                    lc_string := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_007','ACC_NUMBER|PAYMENT_METHOD'
                                                      ,rec_bank_acct_id.master_account_no
                                                       ||'|'
                                                       ||lc_receipt_method);
                    print_log(lc_string);
                    UPDATE xxwar_trfmd_pymt_stg
                       SET misc_rcpt_status = 'E',
                           error_msg = SUBSTR(lc_string||'  '||lc_error_msg,1,4000)
                     WHERE lbx_file_id = p_lockbox_file_id
                       AND master_account_no = rec_bank_acct_id.master_account_no
                       AND destination_rtn = rec_bank_acct_id.destination_rtn;

				    IF p_payment_type IN ('DTD','IBP') THEN
					        UPDATE  xxwar_trfmd_invoice_stg
                               SET  misc_rcpt_status = 'E'
                                   ,error_msg = SUBSTR(lc_string||'  '||lc_error_msg,1,4000)
								   ,last_updated_by = fnd_global.user_id
                                   ,last_update_login = fnd_global.login_id
                                   ,last_update_date = SYSDATE
                             WHERE payment_rec_id IN (SELECT payment_rec_id
                                                        FROM xxwar_trfmd_pymt_stg
                                                       WHERE lbx_file_id = p_lockbox_file_id
                                                         AND misc_rcpt_status = 'E');
					END IF;
					COMMIT;
	       WHEN OTHERS THEN
                    lc_sqlerrm := SQLERRM;
                    lc_string  := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_008','ACC_NUMBER|PAYMENT_METHOD'
                                                                                       ,rec_bank_acct_id.master_account_no
                                                                                        ||'|'
                                                                                        ||lc_receipt_method);
                    print_log(lc_string||lc_sqlerrm);
                    UPDATE xxwar_trfmd_pymt_stg
                       SET misc_rcpt_status = 'E',
                           error_msg = SUBSTR(lc_string||lc_sqlerrm||'  '||lc_error_msg,1,4000)
                     WHERE lbx_file_id = p_lockbox_file_id
                       AND master_account_no = rec_bank_acct_id.master_account_no
                       AND destination_rtn = rec_bank_acct_id.destination_rtn;
                     IF p_payment_type IN ('DTD','IBP') THEN
                        UPDATE  xxwar_trfmd_invoice_stg
                           SET  misc_rcpt_status = 'E'
                               ,error_msg = SUBSTR(lc_string||'  '||lc_error_msg,1,4000)
                               ,last_updated_by = fnd_global.user_id
                               ,last_update_login = fnd_global.login_id
                               ,last_update_date = SYSDATE
                          WHERE payment_rec_id IN (SELECT payment_rec_id
                                                     FROM xxwar_trfmd_pymt_stg
                                                    WHERE lbx_file_id = p_lockbox_file_id
                                                      AND misc_rcpt_status = 'E');
                     END IF;
                     COMMIT;
	    END;

         EXCEPTION
            WHEN NO_DATA_FOUND THEN
                 lc_string := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_005','ACC_NUMBER|BRANCH_NUMBER|ORG_NAME',rec_bank_acct_id.master_account_no||'|'||rec_bank_acct_id.destination_rtn||'|'||lc_org_name);
                 print_log(lc_string);

                    UPDATE xxwar_trfmd_pymt_stg
                       SET misc_rcpt_status = 'E',
                           error_msg = SUBSTR(lc_string||'  '||lc_error_msg,1,4000)
                     WHERE lbx_file_id = p_lockbox_file_id
                       AND master_account_no = rec_bank_acct_id.master_account_no
                       AND destination_rtn = rec_bank_acct_id.destination_rtn;
					 IF p_payment_type IN ('DTD','IBP') THEN
					        UPDATE  xxwar_trfmd_invoice_stg
                               SET  misc_rcpt_status = 'E'
                                   ,error_msg = SUBSTR(lc_string||'  '||lc_error_msg,1,4000)
								   ,last_updated_by = fnd_global.user_id
                                   ,last_update_login = fnd_global.login_id
                                   ,last_update_date = SYSDATE
                             WHERE payment_rec_id IN (SELECT payment_rec_id
                                                        FROM xxwar_trfmd_pymt_stg
                                                       WHERE lbx_file_id = p_lockbox_file_id
                                                         AND misc_rcpt_status = 'E');
					END IF;
					COMMIT;
	       WHEN OTHERS THEN
                    lc_sqlerrm := SQLERRM;
                    lc_string  := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_006','ACC_NUMBER|BRANCH_NUMBER'
                                                                                       ,rec_bank_acct_id.master_account_no
                                                                                        ||'|'
                                                                                        ||rec_bank_acct_id.destination_rtn);
                    print_log(lc_string||lc_sqlerrm);
                    UPDATE xxwar_trfmd_pymt_stg
                       SET misc_rcpt_status = 'E',
                           error_msg = SUBSTR(lc_string||lc_sqlerrm||'  '||lc_error_msg ,1,4000)
                     WHERE lbx_file_id = p_lockbox_file_id
                       AND master_account_no = rec_bank_acct_id.master_account_no
                       AND destination_rtn = rec_bank_acct_id.destination_rtn;
					IF p_payment_type IN ('DTD','IBP') THEN
					        UPDATE  xxwar_trfmd_invoice_stg
                               SET  misc_rcpt_status = 'E'
                                   ,error_msg = SUBSTR(lc_string||'  '||lc_error_msg,1,4000)
								   ,last_updated_by = fnd_global.user_id
                                   ,last_update_login = fnd_global.login_id
                                   ,last_update_date = SYSDATE
                             WHERE payment_rec_id IN (SELECT payment_rec_id
                                                        FROM xxwar_trfmd_pymt_stg
                                                       WHERE lbx_file_id = p_lockbox_file_id
                                                         AND misc_rcpt_status = 'E');
					END IF;
                    COMMIT;
         END;
       END LOOP;
       IF lc_error_flag = 'N' THEN
         IF p_payment_type IN ('ACH','WIR') THEN
           OPEN c_amount_paid FOR
           SELECT XPS.payment_amount
                 ,XPS.payment_rec_id
                 ,0 inv_trfmd_rec_id
                 ,XPS.destination_account_no
                 ,XPS.supplemental_payment_field33
                 ,XPS.effective_date
                 ,XPS.destination_rtn
                 ,XPS.master_account_no
                 ,0 supplemental_rec_id
                 ,'xx' supplemental_invoice_field21
                 ,SUBSTR(XPS.supplemental_payment_field49,0,30) supplemental_invoice_field29
            FROM xxwar_trfmd_batch_stg XBS,
                 xxwar_trfmd_pymt_stg XPS
           WHERE XBS.lbx_file_id = p_lockbox_file_id
             AND XBS.lbx_file_id = XPS.lbx_file_id
             AND NVL(xps.misc_rcpt_status,'X') NOT IN ('E', 'S') ;
         ELSIF p_payment_type = 'DTD' THEN

           BEGIN
             SELECT FLV.tag
               INTO lc_dtd_matching_key
               FROM fnd_lookup_values FLV
                   ,fnd_application FA
              WHERE lookup_type = 'XXWAR_MISC_RECEIPT_PMT_TYPE'
                AND enabled_flag = 'Y'
                AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(start_date_active,SYSDATE)) AND TRUNC(NVL(end_date_active, SYSDATE ) )
                AND LANGUAGE = USERENV('LANG')
                AND FLV.view_application_id = FA.application_id
                AND FA.application_short_name = 'AR'
                AND FLV.lookup_code = 'DTD';
                  IF lc_dtd_matching_key IS NULL THEN
                     lc_error_string := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_013','','');
                     print_log(lc_error_string);

                     BEGIN
                       UPDATE xxwar_trfmd_pymt_stg
                          SET misc_rcpt_status = 'E'
                             ,error_msg = SUBSTR(lc_error_string||' '||lc_string,1,4000)
                             ,last_updated_by = fnd_global.user_id
                             ,last_update_login = fnd_global.login_id
                             ,last_update_date = SYSDATE
                        WHERE lbx_file_id = p_lockbox_file_id
                          AND NVL(misc_rcpt_status,'X') != 'S';
                       UPDATE  xxwar_trfmd_invoice_stg
                          SET  misc_rcpt_status = 'E'
                              ,error_msg = SUBSTR(lc_error_string,1,4000)
                              ,last_updated_by = fnd_global.user_id
                              ,last_update_login = fnd_global.login_id
                              ,last_update_date = SYSDATE
                         WHERE payment_rec_id in (SELECT payment_rec_id
                                                    FROM xxwar_trfmd_pymt_stg
                                                   WHERE lbx_file_id = p_lockbox_file_id)
                                                     AND NVL(misc_rcpt_status,'X') != 'S';
                       COMMIT;
                     EXCEPTION
                         WHEN OTHERS THEN
                              print_log('Unhandled Exception '||SQLERRM);
                     END;
                  ELSE
                    BEGIN
                       lc_error_string := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_017','','');

                       UPDATE  xxwar_trfmd_invoice_stg
                          SET  misc_rcpt_status = 'E'
                              ,error_msg = SUBSTR(lc_error_string||' '||lc_string,1,4000)
                              ,last_updated_by = fnd_global.user_id
                              ,last_update_login = fnd_global.login_id
                              ,last_update_date = SYSDATE
                         WHERE NVL(misc_rcpt_status,'x') != 'E'
                           AND inv_trfmd_rec_id NOT IN ( SELECT  XIS.inv_trfmd_rec_id
                                                           FROM  xxwar_trfmd_supp_invoice_stg XTSI
                                                                ,xxwar_trfmd_invoice_stg XIS
                                                                ,xxwar_trfmd_pymt_stg XPS
                                                           WHERE XIS.inv_trfmd_rec_id = XTSI.invoice_rec_id
                                                             AND XPS.lbx_file_id = p_lockbox_file_id
                                                             AND XPS.payment_rec_id = XIS.payment_rec_id
                                                             AND XTSI.supplemental_invoice_field27 = lc_dtd_matching_key )
                           AND inv_trfmd_rec_id IN ( SELECT  XIS.inv_trfmd_rec_id
                                                       FROM  xxwar_trfmd_supp_invoice_stg XTSI
                                                            ,xxwar_trfmd_invoice_stg XIS
                                                            ,xxwar_trfmd_pymt_stg XPS
                                                      WHERE XIS.inv_trfmd_rec_id = XTSI.invoice_rec_id
                                                        AND XPS.lbx_file_id = p_lockbox_file_id
                                                        AND XPS.payment_rec_id = XIS.payment_rec_id
                                                        AND NVL(XIS.misc_rcpt_status,'X') != 'S');
                      COMMIT;
                    EXCEPTION
                       WHEN OTHERS THEN
                            print_log('Unhandled Exception '||SQLERRM);
                    END;
                 END IF;
           EXCEPTION
                WHEN NO_DATA_FOUND THEN
                     print_log(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_013','',''));
                     print_out(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_013','',''));
                     print_out(' ');
                     print_out(' ');
                WHEN OTHERS THEN
                     print_log(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_014','SQL_ERRM',SQLERRM));
                     print_out(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_014','SQL_ERRM',SQLERRM));
                     print_out(' ');
                     print_out(' ');
           END;
           OPEN c_amount_paid FOR
           SELECT XIS.amount_paid payment_amount
                 ,XIS.payment_rec_id
                 ,XIS.inv_trfmd_rec_id
                 ,XPS.destination_account_no
                 ,XPS.supplemental_payment_field33
                 ,XPS.effective_date
                 ,XPS.destination_rtn
                 ,XPS.master_account_no
                 ,XTSI.supplemental_rec_id
                 ,'xx' supplemental_invoice_field21
                 ,SUBSTR(XTSI.supplemental_invoice_field29,0,30)
            FROM xxwar_trfmd_batch_stg XBS,
                 xxwar_trfmd_pymt_stg XPS,
                 xxwar_trfmd_invoice_stg XIS,
                 xxwar_trfmd_supp_invoice_stg XTSI
           WHERE XBS.lbx_file_id = p_lockbox_file_id
             AND XBS.lbx_file_id = XPS.lbx_file_id
             AND XPS.payment_rec_id = XIS.payment_rec_id
             AND XIS.inv_trfmd_rec_id = XTSI.invoice_rec_id(+)
             AND NVL(XPS.misc_rcpt_status,'X') NOT IN ('E', 'S')
             AND NVL(XIS.misc_rcpt_status,'X') NOT IN ('E', 'S')
             AND XTSI.supplemental_invoice_field27(+) = lc_dtd_matching_key;
         ELSIF p_payment_type = 'IBP' THEN
           OPEN c_amount_paid FOR
          SELECT XIS.amount_paid payment_amount
                ,XIS.payment_rec_id
                ,XIS.inv_trfmd_rec_id
                ,XPS.destination_account_no
                ,XPS.supplemental_payment_field33
                ,XPS.effective_date
                ,XPS.destination_rtn
                ,XPS.master_account_no
                ,0 supplemental_rec_id
                ,XTSI.supplemental_invoice_field21
                ,SUBSTR(XPS.supplemental_payment_field49,0,30)
           FROM xxwar_trfmd_batch_stg XBS,
                xxwar_trfmd_pymt_stg XPS,
                xxwar_trfmd_invoice_stg XIS,
                xxwar_trfmd_supp_invoice_stg XTSI
          WHERE XBS.lbx_file_id = p_lockbox_file_id
            AND XBS.lbx_file_id = XPS.lbx_file_id
            AND XPS.payment_rec_id = XIS.payment_rec_id
            AND XTSI.invoice_rec_id = XIS.inv_trfmd_rec_id
            AND NVL(XPS.misc_rcpt_status,'X') NOT IN ('E', 'S')
            AND NVL(XIS.misc_rcpt_status,'X') NOT IN ('E', 'S');
         END IF;
         LOOP
            FETCH c_amount_paid
             INTO ln_payment_amount
                 ,ln_payment_rec_id
                 ,ln_inv_trfmd_rec_id
                 ,lc_destination_account_no
                 ,lc_supp_payment_field33
                 ,ld_effective_date
                 ,lc_destination_rtn
                 ,lc_master_account_no
                 ,ln_supplemental_rec_id
                 ,lc_supp_invoice_field21
                 ,lc_misc_payment_source;
         EXIT WHEN c_amount_paid%notfound;
              lc_amount_paid_cur_flag := 1;
            BEGIN
              SELECT ABA.bank_account_id
                INTO lc_remittance_bank_account_id
                FROM ce_bank_accounts ABA
                    ,ce_bank_branches_v CBBV
               WHERE bank_account_num = lc_master_account_no
                 AND ABA.bank_branch_id = CBBV.branch_party_id
                 AND CBBV.branch_number = lc_destination_rtn;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                    lc_string := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_005','ACC_NUMBER|BRANCH_NUMBER|ORG_NAME',lc_master_account_no||'|'||lc_destination_rtn||'|'||lc_org_name)||'  '||lc_string;
                    print_log(lc_string);
                    UPDATE xxwar_trfmd_pymt_stg
                       SET misc_rcpt_status = 'E'
                          ,error_msg = SUBSTR(lc_string||'|'||lc_error_msg,1,4000)
                          ,last_updated_by = fnd_global.user_id
                          ,last_update_login = fnd_global.login_id
                          ,last_update_date = SYSDATE
                     WHERE lbx_file_id = p_lockbox_file_id
                       AND master_account_no = lc_master_account_no
                       AND destination_rtn = lc_destination_rtn;
                 COMMIT;
               WHEN OTHERS THEN
                    lc_sqlerrm := SQLERRM;
                    lc_string  := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_006','ACC_NUMBER|BRANCH_NUMBER',lc_master_account_no||'|'||lc_destination_rtn)||'  '||lc_string;
                    print_log(lc_string||lc_sqlerrm);
                    UPDATE xxwar_trfmd_pymt_stg
                       SET misc_rcpt_status = 'E'
                          ,error_msg = SUBSTR(lc_string||lc_sqlerrm||'|'||lc_error_msg ,1,4000)
                          ,last_updated_by = fnd_global.user_id
                          ,last_update_login = fnd_global.login_id
                          ,last_update_date = SYSDATE
                    WHERE lbx_file_id = p_lockbox_file_id
                      AND master_account_no = lc_master_account_no
                      AND destination_rtn = lc_destination_rtn;
                 COMMIT;
            END;
            BEGIN
               SELECT CBAU.bank_acct_use_id
                 INTO lc_bank_acct_use_id
                 FROM ar_receipt_method_accounts_all ARMC,
                      ce_bank_accounts CBA,
                      ce_bank_acct_uses_all CBAU
                WHERE ARMC.receipt_method_id = lc_receipt_method_id
                  AND CBA.bank_account_id = lc_remittance_bank_account_id
                  AND CBA.bank_account_id = CBAU.bank_account_id
                  AND ARMC.remit_bank_acct_use_id = CBAU.bank_acct_use_id
                  AND TRUNC(NVL(ARMC.end_date,SYSDATE+1)) >= SYSDATE
                  AND ARMC.org_id = lc_org_id;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                    lc_string := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_007','ACC_NUMBER|PAYMENT_METHOD',lc_master_account_no||'|'||lc_receipt_method)||'  '||lc_string;
                    print_log(lc_string);
                    UPDATE xxwar_trfmd_pymt_stg
                       SET misc_rcpt_status = 'E'
                          ,error_msg = SUBSTR(lc_string||'|'||lc_error_msg,1,4000)
                          ,last_updated_by = fnd_global.user_id
                          ,last_update_login = fnd_global.login_id
                          ,last_update_date = SYSDATE
                    WHERE lbx_file_id = p_lockbox_file_id
                      AND master_account_no = lc_master_account_no
                      AND destination_rtn = lc_destination_rtn;
                 COMMIT;
               WHEN OTHERS THEN
                    lc_sqlerrm := SQLERRM;
                    lc_string  := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_008','ACC_NUMBER|PAYMENT_METHOD'
                                                        ,lc_master_account_no
                                                         ||'|'
                                                         ||lc_receipt_method)||'  '||lc_string;
                    print_log(lc_string||lc_sqlerrm);
                    UPDATE xxwar_trfmd_pymt_stg
                       SET misc_rcpt_status = 'E'
                          ,error_msg = SUBSTR(lc_string||lc_sqlerrm||'|'||lc_error_msg,1,4000)
                          ,last_updated_by = fnd_global.user_id
                          ,last_update_login = fnd_global.login_id
                          ,last_update_date = SYSDATE
                     WHERE lbx_file_id = p_lockbox_file_id
                       AND master_account_no = lc_master_account_no
                       AND destination_rtn = lc_destination_rtn;
                COMMIT;
            END;
        BEGIN
          IF(p_payment_type = 'ACH') THEN
             lc_receipt_number :=  XXWAR_RECEIPTS_PKG.xxwar_ach_derive_rcpt_num (ln_payment_rec_id);
          ELSIF(p_payment_type = 'DTD') THEN
             lc_receipt_number :=  XXWAR_RECEIPTS_PKG.xxwar_dtd_misc_derive_rcpt_num (ln_supplemental_rec_id);
          ELSIF(p_payment_type = 'WIR') THEN
            SELECT substr(trim(lc_supp_payment_field33),decode(length(trim(lc_supp_payment_field33))-4,0,1,-1,1,-2,1,-3,1,-5))
              INTO lc_wir_receipt_num
              FROM DUAL;
              lc_receipt_number := lc_wir_receipt_num;
          ELSIF(p_payment_type = 'IBP') THEN
	     lc_receipt_number := lc_supp_invoice_field21;
          END IF;
          lc_currency_code         := 'USD';
          lc_receipt_date          := NVL(ld_effective_date,SYSDATE);
          lc_gl_date               := NVL(ld_effective_date,SYSDATE);
          lc_amount                := ln_payment_amount/100;
          ln_attr_rec              := ln_attr_rec + 1;
          /* Assigning ln_payment_rec_id value to Attribute15 to invoke correct additional information form at the front end.
             IF value is NULL then XXWARDTDIBP form will be activated else XXWARPYMT will be activated*/
          IF p_payment_type IN ('ACH','WIR') THEN
             attribute_tbl_var(ln_attr_rec).attribute15 := ln_payment_rec_id;
          ELSIF p_payment_type = 'DTD' THEN
             attribute_tbl_var(ln_attr_rec).attribute15 := ln_inv_trfmd_rec_id;
          ELSE
             attribute_tbl_var(ln_attr_rec).attribute15 := NULL;
          END IF;
          IF lc_amount != 0 THEN
            SAVEPOINT api_start;
            AR_RECEIPT_API_PUB.create_misc(
                                            p_api_version                   => 1.0,
                                            p_init_msg_list                 => FND_API.G_TRUE, --FND_API.G_FALSE,
                                            p_commit                        => FND_API.G_TRUE,
                                            p_validation_level              => FND_API.G_VALID_LEVEL_FULL,
                                            x_return_status                 => x_return_status,
                                            x_msg_count                     => x_msg_count,
                                            x_msg_data                      => x_msg_data,
                                            p_usr_currency_code             => lc_currency_code,
                                            p_currency_code                 => lc_currency_code,
                                            p_usr_exchange_rate_type        => lc_usr_exchange_rate_type,
                                            p_exchange_rate_type            => lc_exchange_rate_type,
                                            p_exchange_rate                 => lc_exchange_rate,
                                            p_exchange_rate_date            => lc_exchange_rate_date,
                                            p_amount                        => lc_amount,
                                            p_receipt_number                => lc_receipt_number,
                                            p_receipt_date                  => lc_receipt_date,
                                            p_gl_date                       => lc_gl_date,
                                            p_receivables_trx_id            => lc_receivables_trx_id,
                                            p_activity                      => lc_activity,
                                            p_misc_payment_source           => lc_misc_payment_source,
                                            p_tax_code                      => lc_tax_code,
                                            p_vat_tax_id                    => lc_vat_tax_id,
                                            p_tax_rate                      => lc_tax_rate,
                                            p_tax_amount                    => lc_tax_amount,
                                            p_deposit_date                  => lc_deposit_date,
                                            p_reference_type                => lc_reference_type,
                                            p_reference_num                 => lc_reference_num,
                                            p_reference_id                  => lc_reference_id,
                                            p_remittance_bank_account_id    => lc_bank_acct_use_id,/*lc_remittance_bank_account_id,*/
                                            p_remittance_bank_account_num   => lc_remittance_bank_account_num,
                                            p_remittance_bank_account_name  => lc_remit_bank_acc_name,
                                            p_receipt_method_id             => lc_receipt_method_id,
                                            p_receipt_method_name           => lc_receipt_method_name,
                                            p_doc_sequence_value            => lc_doc_sequence_value,
                                            p_ussgl_transaction_code        => lc_ussgl_transaction_code,
                                            p_anticipated_clearing_date     => lc_anticipated_clearing_date,
                                            p_attribute_record              => attribute_tbl_var(ln_attr_rec) ,
                                            p_global_attribute_record       => lc_global_attribute_record,
                                            p_org_id                        => lc_org_id,
                                            p_comments                      => lc_comments,
                                            p_misc_receipt_id               => lc_misc_receipt_id,
                                            p_called_from                   => lc_called_from
                                            );

              IF (x_return_status = 'S') THEN
                 IF p_payment_type IN ('DTD', 'IBP') THEN
                    UPDATE xxwar_trfmd_invoice_stg
                       SET misc_rcpt_status = 'S'
                          ,receipt_number = lc_receipt_number
                          ,last_updated_by = fnd_global.user_id
                          ,last_update_login = fnd_global.login_id
                          ,last_update_date = SYSDATE
                     WHERE payment_rec_id = ln_payment_rec_id
                       AND inv_trfmd_rec_id = ln_inv_trfmd_rec_id;
                    COMMIT;
                 ELSE
                   UPDATE xxwar_trfmd_pymt_stg
                      SET misc_rcpt_status = 'S'
                         ,receipt_number = lc_receipt_number
                         ,last_updated_by = fnd_global.user_id
                         ,last_update_login = fnd_global.login_id
                         ,last_update_date = SYSDATE
                    WHERE payment_rec_id = ln_payment_rec_id;
                 END IF;
                lc_receipt_success_count := lc_receipt_success_count + 1 ;
                COMMIT;
                IF p_payment_type IN ('DTD', 'IBP') THEN
                   load_custom_data (p_lbx_file_id => p_lockbox_file_id
                                    ,p_payment_rec_id => ln_payment_rec_id
                                    ,p_inv_trfmd_rec_id => ln_inv_trfmd_rec_id
                                    ,x_return_status => lc_return_status
                                    ,x_error_msg => lc_status_msg  ) ;
                ELSE
                   load_custom_data (p_lbx_file_id => p_lockbox_file_id
                                    ,p_payment_rec_id => ln_payment_rec_id
                                    ,x_return_status => lc_return_status
                                    ,x_error_msg =>lc_status_msg
                                            ) ;
                END IF;
                 print_log('Procedure for loading custom data for Miscellaneous Receipts: completed successfully ');
                 print_log('Misc Custom data fetch status: '||lc_return_status);
                 IF lc_return_status = 'S' THEN
                    NULL;
                 ELSE
                    print_log('Misc Custom data fetch Error Message: '||lc_status_msg);
                 END IF;
              ELSE
                 ROLLBACK TO api_start;
                 lc_error_msg :=APPS.FND_MSG_PUB.Get ( p_msg_index    => APPS.FND_MSG_PUB.G_LAST,
                                                       p_encoded      => APPS.FND_API.G_FALSE);
                 lc_batch_error_msg := substr(lc_batch_error_msg ||'|'||lc_error_msg,1,2000) ;
                 IF p_payment_type IN ('DTD', 'IBP') THEN
                    UPDATE xxwar_trfmd_invoice_stg
                       SET misc_rcpt_status = 'E'
                          ,receipt_number = lc_receipt_number
                          ,error_msg = SUBSTR (lc_error_msg,1,4000) --(lc_error_msg||'|'||x_msg_data,1,4000)
                          ,last_updated_by = fnd_global.user_id
                          ,last_update_login = fnd_global.login_id
                          ,last_update_date = SYSDATE
                     WHERE payment_rec_id = ln_payment_rec_id
                       AND inv_trfmd_rec_id = ln_inv_trfmd_rec_id;

                 ELSE
                   UPDATE xxwar_trfmd_pymt_stg
                      SET misc_rcpt_status = 'E'
                         ,receipt_number = lc_receipt_number
                         ,error_msg = SUBSTR (lc_error_msg,1,4000) --lc_error_msg||'|'||x_msg_data,1,4000)
                         ,last_updated_by = fnd_global.user_id
                         ,last_update_login = fnd_global.login_id
                         ,last_update_date = SYSDATE
                    WHERE payment_rec_id = ln_payment_rec_id;
                 END IF;
                 COMMIT;
                 lc_receipt_failed_count := lc_receipt_failed_count + 1;
                 print_log('Receipt Number = '|| lc_receipt_number);
                 print_log('Return Status  = '|| SUBSTR (x_return_status,1,255));
                 print_log('Message Count  = '|| TO_CHAR(x_msg_count ));
                 print_log('Message Data   = '|| SUBSTR (x_msg_data,1,255));
                 print_log(APPS.FND_MSG_PUB.Get ( p_msg_index    => APPS.FND_MSG_PUB.G_LAST,
                                                  p_encoded      => APPS.FND_API.G_FALSE));
                 IF x_msg_count >0 THEN
                    FOR I IN 1..x_msg_count LOOP
                      dbms_output.put_line(I||'. '|| SUBSTR (FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                    END LOOP;
                 END IF;
              END IF;
          ELSE
             lc_receipt_failed_count := lc_receipt_failed_count + 1;
			 IF p_payment_type IN ('DTD', 'IBP') THEN
			    lc_error_string := get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_036','','');
                    UPDATE xxwar_trfmd_invoice_stg
                       SET misc_rcpt_status = 'E'
                          ,receipt_number = lc_receipt_number
                          ,error_msg = lc_error_string --'Receipt amount can not be zero'
                          ,last_updated_by = fnd_global.user_id
                          ,last_update_login = fnd_global.login_id
                          ,last_update_date = SYSDATE
                     WHERE payment_rec_id = ln_payment_rec_id
                       AND inv_trfmd_rec_id = ln_inv_trfmd_rec_id;
             ELSE
                   UPDATE xxwar_trfmd_pymt_stg
                      SET misc_rcpt_status = 'E'
                         ,receipt_number = lc_receipt_number
                         ,error_msg = lc_error_string--'Receipt amount can not be zero'
                         ,last_updated_by = fnd_global.user_id
                         ,last_update_login = fnd_global.login_id
                         ,last_update_date = SYSDATE
                    WHERE payment_rec_id = ln_payment_rec_id;
             END IF;
             COMMIT;
          END IF;
         EXCEPTION
            WHEN OTHERS THEN
               print_log('Unhandled Exception :'||sqlerrm);
               lc_receipt_failed_count := lc_receipt_failed_count + 1 ;
               lc_error_api_msg := 'Unhandled Exception :'||sqlerrm;
               IF p_payment_type IN ('DTD', 'IBP') THEN
                  UPDATE xxwar_trfmd_invoice_stg
                     SET misc_rcpt_status = 'E'
                         ,receipt_number = lc_receipt_number
                         ,error_msg = SUBSTR (lc_error_msg||'|'||lc_error_api_msg,1,4000)
			 ,last_updated_by = fnd_global.user_id
                         ,last_update_login = fnd_global.login_id
                         ,last_update_date = SYSDATE
                   WHERE payment_rec_id = ln_payment_rec_id
                     AND inv_trfmd_rec_id = ln_inv_trfmd_rec_id;
					 COMMIT;
               ELSE
                  UPDATE xxwar_trfmd_pymt_stg
                     SET  misc_rcpt_status = 'E'
                         ,receipt_number = lc_receipt_number
                         ,error_msg = SUBSTR (lc_error_msg||'|'||lc_error_api_msg,1,4000)
                         ,last_updated_by = fnd_global.user_id
                         ,last_update_login = fnd_global.login_id
                         ,last_update_date = SYSDATE
                   WHERE payment_rec_id = ln_payment_rec_id;
				   COMMIT;
               END IF;
         END;
         END LOOP;
           IF lc_amount_paid_cur_flag = 1 THEN
               UPDATE xxwar_trfmd_batch_stg
                  SET misc_rcpt_created_count =  lc_receipt_success_count
                     ,misc_rcpt_failed_count =   lc_receipt_failed_count
                     ,error_msg = substr(lc_error_msg,1,2000)
                     ,process_status = DECODE(lc_receipt_failed_count,0,8,5)
                     ,last_updated_by = fnd_global.user_id
                     ,last_update_login = fnd_global.login_id
                     ,last_update_date = SYSDATE
                WHERE lbx_file_id = p_lockbox_file_id;
               COMMIT;
           ELSE
               IF p_payment_type IN ('ACH','WIR') THEN
          SELECT count(XPS.payment_rec_id)
            INTO lc_receipt_failed_count
            FROM xxwar_trfmd_batch_stg XBS
                 ,xxwar_trfmd_pymt_stg XPS
           WHERE XBS.lbx_file_id = p_lockbox_file_id
             AND XBS.lbx_file_id = XPS.lbx_file_id
             AND NVL(XPS.misc_rcpt_status,'X') NOT IN ('S') ;
          ELSE
          SELECT count(XIS.invoice_rec_id)
            INTO lc_receipt_failed_count
            FROM xxwar_trfmd_batch_stg XBS
                ,xxwar_trfmd_pymt_stg XPS
                ,xxwar_trfmd_invoice_stg XIS
           WHERE XBS.lbx_file_id = p_lockbox_file_id
             AND XBS.lbx_file_id = XPS.lbx_file_id
             AND XPS.payment_rec_id = XIS.payment_rec_id
             AND NVL(XPS.misc_rcpt_status,'X') NOT IN ('S')
             AND NVL(XIS.misc_rcpt_status,'X') NOT IN ('S');
          END IF;
               UPDATE xxwar_trfmd_batch_stg
                  SET misc_rcpt_created_count =  lc_receipt_success_count
                     ,misc_rcpt_failed_count =   lc_receipt_failed_count
                     ,error_msg = substr(lc_error_msg,1,2000)
                     ,process_status = 5
                     ,last_updated_by = fnd_global.user_id
                     ,last_update_login = fnd_global.login_id
                     ,last_update_date = SYSDATE
                WHERE lbx_file_id = p_lockbox_file_id;
               COMMIT;
           END IF;
             print_out(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_030','','')); --'Following Miscellaneous Receipts are created successfully'
             print_out('No# '||'Receipt Number                  '||'Date    '||'  Amount              ' );
             print_out('--- '||'------------------------------  '||'--------'||'  ---------------------');
            lc_receipt_number := NULL;
            lc_error_msg := NULL;
            IF p_payment_type IN ('DTD', 'IBP') THEN
               OPEN c_receipts_details FOR
             SELECT XIS.receipt_number
                    ,XPS.effective_date
                    ,XIS.amount_paid pymt_amount
               FROM xxwar_trfmd_invoice_stg XIS
                   ,xxwar_trfmd_pymt_stg  XPS
              WHERE XPS.payment_rec_id = XIS.payment_rec_id
                AND XPS.lbx_file_id =  p_lockbox_file_id
                AND XIS.misc_rcpt_status = 'S';
            ELSE
               OPEN c_receipts_details FOR
               SELECT XPS.receipt_number
                      ,XPS.effective_date
                      ,XPS.payment_amount pymt_amount
                 FROM xxwar_trfmd_pymt_stg  XPS
                WHERE XPS.lbx_file_id =  p_lockbox_file_id
                  AND XPS.misc_rcpt_status = 'S';
            END IF;
            LOOP
              FETCH c_receipts_details
               INTO lc_receipt_number
                    ,lc_date
                    ,lc_amount;
               ln_cur_count := c_receipts_details%rowcount;
              EXIT WHEN c_receipts_details%notfound;
              ln_count := ln_count + 1;
              print_out(RPAD(ln_count,4)||RPAD(lc_receipt_number,32)||RPAD(lc_date,10)||lc_amount/100);
            END LOOP;
            IF ln_cur_count = 0 THEN
               print_out('');
               print_out(get_error_message_pvt( 'XXWAR_MISC_ERROR_MESSAGES_034','',''));--No receipts created
            END IF;
            print_out('');
            print_out('');
            print_out(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_031','',''));--Following Miscellaneous Receipts are failed to create
            print_out('');
            print_out('Miscellaneous Receipt File ID:'||p_lockbox_file_id);
            print_out(' ');
            print_out(RPAD('No#',4)||RPAD('Receipt Number',32)||RPAD('Date',10)||RPAD('Amount',16)||RPAD('Account Number',36)||RPAD('Error Message',76));
            print_out('--- '||RPAD('------------------------------  ',32)||RPAD('--------',10)||'--------------- '||'---------------------------------- '||RPAD('------------------------------------------------------------------------------',76));
            ln_count := 0;
            IF p_payment_type IN ('DTD', 'IBP') THEN
               OPEN c_receipts_details FOR
             SELECT xis.receipt_number
                   ,NVL(xis.error_msg,xps.error_msg)
                   ,xis.amount_paid pymt_amount
                   ,xps.master_account_no
                   ,xps.effective_date
               FROM xxwar_trfmd_invoice_stg xis
                   ,xxwar_trfmd_pymt_stg  xps
              WHERE xps.payment_rec_id = xis.payment_rec_id
                AND xps.lbx_file_id =  p_lockbox_file_id
                AND xis.misc_rcpt_status = 'E';
                --AND xps.misc_rcpt_status = 'E';
            ELSE
               OPEN c_receipts_details FOR
               SELECT xps.receipt_number
                     ,xps.error_msg
                     ,xps.payment_amount pymt_amount
                     ,xps.master_account_no
                     ,xps.effective_date
                 FROM xxwar_trfmd_pymt_stg  xps
                WHERE xps.lbx_file_id =  p_lockbox_file_id
                  AND xps.misc_rcpt_status = 'E';
            END IF;
            LOOP
              FETCH c_receipts_details
               INTO lc_receipt_number
                   ,lc_error_msg
                   ,lc_amount
                   ,lc_master_account_no
                   ,lc_date;
                ln_cur_count := c_receipts_details%rowcount;
                EXIT WHEN c_receipts_details%notfound;
              ln_count := ln_count + 1;
              print_out(RPAD(ln_count,4)||RPAD(NVL(lc_receipt_number,' '),32)||RPAD(lc_date,10)||RPAD(lc_amount/100,16)||RPAD(lc_master_account_no,36)||xxwar_format_utility(lc_error_msg,76));
            END LOOP;
            IF ln_cur_count = 0 THEN
               print_out('');
               print_out(get_error_message_pvt( 'XXWAR_MISC_ERROR_MESSAGES_035','',''));--No receipts Failed
            ELSE
               print_out(' ');
               print_out(' ');
               print_out( get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_032','','') );
               --'Please make necessary changes and submit the concurrent program "XXWAR Miscellaneous Receipt Creation" to process the file.'
            END IF;
       ELSE
          print_log('Misc Receipts creation API is not called for the file_id: '||p_lockbox_file_id);
                    UPDATE xxwar_trfmd_pymt_stg
                       SET misc_rcpt_status = 'E'
                          ,error_msg = SUBSTR(lc_string||'  '||lc_error_msg,1,4000)
                          ,last_updated_by = fnd_global.user_id
                          ,last_update_login = fnd_global.login_id
                          ,last_update_date = SYSDATE
                     WHERE lbx_file_id = p_lockbox_file_id;
                    COMMIT;
                    IF p_payment_type IN ('DTD','IBP') THEN
                       UPDATE  xxwar_trfmd_invoice_stg
                          SET  misc_rcpt_status = 'E'
                              ,error_msg = SUBSTR(lc_string||'  '||lc_error_msg,1,4000)
                              ,last_updated_by = fnd_global.user_id
                              ,last_update_login = fnd_global.login_id
                              ,last_update_date = SYSDATE
                        WHERE payment_rec_id IN (SELECT payment_rec_id
                                                  FROM xxwar_trfmd_pymt_stg
                                                 WHERE lbx_file_id = p_lockbox_file_id);
                    END IF;
                    COMMIT;
       IF p_payment_type IN ('ACH','WIR') THEN
          SELECT COUNT(XPS.payment_rec_id)
            INTO lc_receipt_failed_count
            FROM xxwar_trfmd_batch_stg XBS
                 ,xxwar_trfmd_pymt_stg XPS
           WHERE XBS.lbx_file_id = p_lockbox_file_id
             AND XBS.lbx_file_id = XPS.lbx_file_id
             AND NVL(XPS.misc_rcpt_status,'X') NOT IN ('S') ;
          ELSE
          SELECT COUNT(XIS.invoice_rec_id)
            INTO lc_receipt_failed_count
            FROM xxwar_trfmd_batch_stg XBS
                ,xxwar_trfmd_pymt_stg XPS
                ,xxwar_trfmd_invoice_stg XIS
           WHERE XBS.lbx_file_id = p_lockbox_file_id
             AND XBS.lbx_file_id = XPS.lbx_file_id
             AND XPS.payment_rec_id = XIS.payment_rec_id
             AND NVL(XPS.misc_rcpt_status,'X') NOT IN ('S')
             AND NVL(XIS.misc_rcpt_status,'X') NOT IN ('S');
       END IF;
          UPDATE xxwar_trfmd_batch_stg
             SET misc_rcpt_created_count =  lc_receipt_success_count
                ,misc_rcpt_failed_count =   lc_receipt_failed_count
                ,error_msg = SUBSTR(lc_error_msg,1,2000)
                ,process_status = 5
                ,last_updated_by = fnd_global.user_id
                ,last_update_login = fnd_global.login_id
                ,last_update_date = SYSDATE
           WHERE lbx_file_id = p_lockbox_file_id;
           COMMIT;
          print_out(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_033','','')); --Please refer log file for the errors.
          print_out(' ');
          print_out(' ');
          print_out(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_032','',''));
          --'Please make necessary changes and submit the concurrent program "XXWAR Miscellaneous Receipt Creation" to process the file.'
          lc_updated_flag := 'Y';
       END IF;
      print_out('');
      print_out('');
      print_out(get_error_message_pvt('XXWAR_MISC_ERROR_MESSAGES_037','',''));      --*** End of Report ***
        IF lc_updated_flag = 'N' THEN
          UPDATE xxwar_trfmd_batch_stg
             SET misc_rcpt_created_count =  lc_receipt_success_count
                ,misc_rcpt_failed_count =   ln_cur_count
                ,error_msg = substr(lc_error_msg,1,2000)
                ,process_status = DECODE(ln_cur_count,0,8,5)
                ,last_updated_by = fnd_global.user_id
                ,last_update_login = fnd_global.login_id
                ,last_update_date = SYSDATE
           WHERE lbx_file_id = p_lockbox_file_id;
           COMMIT;
	  END IF;
EXCEPTION
   WHEN OTHERS THEN
   print_log('Error : unhandled exception '||SQLERRM);
     IF p_payment_type IN ('ACH','WIR') THEN
          SELECT COUNT(XPS.payment_rec_id) - lc_receipt_success_count
            INTO lc_receipt_failed_count
            FROM xxwar_trfmd_batch_stg XBS
                 ,xxwar_trfmd_pymt_stg XPS
           WHERE XBS.lbx_file_id = p_lockbox_file_id
             AND XBS.lbx_file_id = XPS.lbx_file_id
             AND NVL(XPS.misc_rcpt_status,'X') NOT IN ('S') ;
     ELSE
      SELECT COUNT(XIS.invoice_rec_id) - lc_receipt_success_count
            INTO lc_receipt_failed_count
            FROM xxwar_trfmd_batch_stg XBS
                ,xxwar_trfmd_pymt_stg XPS
                ,xxwar_trfmd_invoice_stg XIS
           WHERE XBS.lbx_file_id = p_lockbox_file_id
             AND XBS.lbx_file_id = XPS.lbx_file_id
             AND XPS.payment_rec_id = XIS.payment_rec_id
             AND NVL(XPS.misc_rcpt_status,'X') NOT IN ('S')
             AND NVL(XIS.misc_rcpt_status,'X') NOT IN ('S');
     END IF;
   UPDATE xxwar_trfmd_batch_stg
      SET misc_rcpt_created_count =  lc_receipt_success_count
         ,misc_rcpt_failed_count =   lc_receipt_failed_count
         ,error_msg = SUBSTR(lc_error_msg,1,2000)
         ,process_status = DECODE(lc_receipt_failed_count,0,8,5)
         ,last_updated_by = fnd_global.user_id
         ,last_update_login = fnd_global.login_id
         ,last_update_date = SYSDATE
    WHERE lbx_file_id = p_lockbox_file_id;
   COMMIT;
END misc_receipts_pvt;

PROCEDURE batch_receipts_details(
                          x_errbuf             OUT VARCHAR2
                         ,x_retcode            OUT VARCHAR2
                         ,p_org_id              IN NUMBER
                         ,p_date                IN DATE
                         ,p_receipt_method      IN VARCHAR2
                       	)                                             /*Enhancement#58718*/
IS
  lc_count                          NUMBER := 1;
  ln_total_amt                      NUMBER := 0;
  ln_grand_total_amt                NUMBER := 0;
  lc_org_name                       hr_operating_units.name%type;
  CURSOR cur_receipt_details (p_date DATE,p_receipt_method VARCHAR2)
  IS
    SELECT abv.bank_account_number,
          TRIM(TRANSLATE(abv.Comments, 'SUB ACCOUNT',' ')) AS sub_account,
          abv.transmission_name,
          abv.name,control_amount,
          abv.receipt_method_id
     FROM ar_batches_v  ABV
         ,ar_receipt_methods ARM
    WHERE TRUNC(batch_date) = TRUNC(NVL(p_date,SYSDATE))
      AND ABV.receipt_method_id = ARM.receipt_method_id
      AND ARM.name LIKE '%'||p_receipt_method||'%'
      AND ABV.org_id = p_org_id
 ORDER BY abv.bank_account_number,abv.transmission_name ASC;

  CURSOR cur_receipt_methods(p_receipt_method VARCHAR2)
  IS
    SELECT 'ACH' AS Receipt_method FROM dual WHERE p_receipt_method IN  ('ACH','ALL')
    UNION ALL
    SELECT 'DTD' FROM dual WHERE p_receipt_method IN  ('DTD','ALL')
    UNION ALL
    SELECT 'IBP' FROM dual WHERE p_receipt_method IN  ('IBP','ALL')
    UNION ALL
    SELECT 'LBX' FROM dual WHERE p_receipt_method IN  ('LBX','ALL')
    UNION ALL
    SELECT 'WIR' FROM dual WHERE p_receipt_method IN  ('WIR','ALL');

  BEGIN
     BEGIN
        SELECT NAME
          INTO lc_org_name
          FROM hr_operating_units
          WHERE organization_id = p_org_id;
     EXCEPTION
         WHEN OTHERS THEN
             print_log('Exception While fetching Operating unit name '||SQLERRM);
     END;

     print_out(' ');
     print_out(' ');
     print_out('                                   =======================================================================================');
     print_out('                                   Receipt Batches created by the Wells Fargo Adapter for ' ||lc_org_name||' on '||TO_CHAR(p_date,'DD-Mon-YYYY'));
     print_out('                                   =======================================================================================');
     print_out(' ');
     print_out(' ');

     FOR lcur_receipt_methods IN cur_receipt_methods(p_receipt_method)
     LOOP
         lc_count := 1;
         ln_total_amt := 0;
         print_out(' ');
         print_out(' ');
         print_out(' ');
         print_out('Receipt Method: '||lcur_receipt_methods.RECEIPT_METHOD);
         print_out(RPAD('=',143,'='));
         print_out(RPAD('#',4)||RPAD('Main Account',32)||RPAD('Sub Account',32)||RPAD('Transmission Name',32)||RPAD('Batch Number',22)||RPAD('Receipt Batch Amount',20));
         print_out(RPAD('=',143,'='));
         FOR lcur_receipt_details IN cur_receipt_details(p_date,lcur_receipt_methods.RECEIPT_METHOD)
         LOOP
             print_out(RPAD(lc_count,4)||RPAD(lcur_receipt_details.bank_account_number,32)||RPAD(NVL(lcur_receipt_details.sub_Account,' '),32)||RPAD(lcur_receipt_details.transmission_name,32)||RPAD(lcur_receipt_details.name,22)||LPAD(TRIM(to_char(lcur_receipt_details.control_amount,'9999999999999999999.99')),21));
             ln_total_amt := ln_total_amt + lcur_receipt_details.control_amount;
             lc_count := lc_count + 1;
         END LOOP;
         IF lc_count > 1 THEN
            print_out(RPAD('=',143,'='));
            print_out(LPAD('Total : '||TRIM(to_char(ln_total_amt,'999,999,999,999,999,999,999.99')),143));
            print_out(RPAD('=',143,'='));
            ln_grand_total_amt := ln_grand_total_amt + ln_total_amt;
         ELSE
            print_out(' ');
            print_out('   No Receipt Batches Found');
            print_out(RPAD('=',143,'='));
         END IF;
     END LOOP;
            print_out(' ');
            print_out(' ');
            print_out(LPAD('G R A N D    T O T A L : '||TRIM(to_char(ln_grand_total_amt,'999,999,999,990.99')),143));
            print_out(' ');
            print_out(' ');
            print_out('                                                        *** End of Report ***');
  EXCEPTION
    WHEN OTHERS THEN
	   print_log('Unhandled Excveption In batch_receipts_details '||SQLERRM);
END batch_receipts_details;

FUNCTION xxwar_format_utility (p_ip_string      VARCHAR2,
                               p_line_width     NUMBER)
RETURN VARCHAR2
IS
  lc_string         VARCHAR2(32000)    := p_ip_string;
  ln_line_count     NUMBER             := 0;
  ln_line_width     NUMBER             := p_line_width ;
  ln_start_pos      NUMBER             := 0;
  ln_end_pos        NUMBER             := ln_line_width;
  lc_out_string     VARCHAR2(32000);
  ln_new_line       VARCHAR2(32000);
  ln_cntr           NUMBER             := -1;
BEGIN
  IF lc_string IS NOT NULL THEN
     IF LENGTH(lc_string) > ln_line_width THEN
        FOR pos_count     IN 1..length(lc_string)
        LOOP
          IF mod(pos_count,ln_line_width)=0 THEN
            ln_line_count               :=ln_line_count+1;
          END IF;
        END LOOP;
        FOR act_cnt IN 0..ln_line_count
        LOOP
          ln_cntr := ln_cntr + 1;
          IF act_cnt      = 0 THEN
            ln_start_pos :=1;
          ELSE
            ln_start_pos := (act_cnt*ln_line_width)+1;
          END IF;
          IF act_cnt-1     =ln_line_count THEN
            ln_new_line := NULL;
          ELSE
            ln_new_line:=CHR(10)||'                                                                                                  ';
          END IF;
          IF  ln_cntr <> ln_line_count THEN
           lc_out_string:=lc_out_string||
                          RPAD(SUBSTR(lc_string,ln_start_pos,ln_end_pos),ln_line_width)
                          ||ln_new_line;
          ELSE
           lc_out_string:=lc_out_string||
                          RPAD(SUBSTR(lc_string,ln_start_pos,ln_end_pos),ln_line_width);
          END IF;
        END LOOP;
     ELSE
        lc_out_string := RPAD(lc_string,ln_line_width);
     END IF;
     RETURN (lc_out_string);
  ELSE
     RETURN (lc_string );
  END IF;
  END xxwar_format_utility;

  FUNCTION xxwar_validate_customer (p_cust_num VARCHAR2)      --Issue#64649
      RETURN VARCHAR2
    IS
       CURSOR c_validate_customer (p_cust_num IN VARCHAR2)
       IS
       SELECT  COUNT(1)
         FROM  hz_cust_Accounts HCA
        WHERE  HCA.status='A'
          AND  HCA.account_number = p_cust_num;
       lc_cust_count NUMBER :=0 ;

   BEGIN
      OPEN   c_validate_customer (p_cust_num);
      FETCH  c_validate_customer
      INTO   lc_cust_count;
      CLOSE  c_validate_customer;

   IF lc_cust_count >=1 THEN
      RETURN (p_cust_num);
   ELSE
      RETURN NULL;
   END IF;

   END xxwar_validate_customer;

 FUNCTION xxwar_get_invoice_amt (p_invoice_rec_id NUMBER)      -- Issue:65174
 RETURN NUMBER
 IS
   lc_inv_num        xxwar_trfmd_invoice_stg.reference_identification%TYPE;
   lc_amt_paid       xxwar_trfmd_invoice_stg.amount_paid%TYPE;
 BEGIN
     lc_inv_num := xxwar_receipts_pkg.xxwar_validate_invoice(p_invoice_rec_id);
     IF lc_inv_num IS NOT NULL THEN
        SELECT amount_paid
          INTO lc_amt_paid
          FROM xxwar_trfmd_invoice_stg
         WHERE invoice_rec_id = p_invoice_rec_id;

        RETURN lc_amt_paid;
     ELSE
        RETURN NULL;
     END IF;
 EXCEPTION
     WHEN NO_DATA_FOUND THEN
          print_log('No data found exception while fetching invoice number at xxwar_receipts_pkg.xxwar_get_invoice_amt');
          RETURN NULL;
     WHEN others THEN
          print_log('Exception while fetching invoice number at xxwar_receipts_pkg.xxwar_get_invoice_amt: '||SQLERRM);
          RETURN NULL;
 END xxwar_get_invoice_amt;

 FUNCTION xxwar_dtd_comments (p_string VARCHAR2)  --Enhancement#65531
 RETURN VARCHAR2
 IS
   lc_sub_acct VARCHAR2(50);
   ln_sup_rec_id NUMBER;
   lc_deposited_check_id VARCHAR2(30);
   lc_return_string VARCHAR2(4000);
 BEGIN
    BEGIN
      SELECT TO_NUMBER (SUBSTR (p_string, 1,
         CASE
           WHEN instr (p_string, '|') = 0
           THEN LENGTH (p_string)
           ELSE instr (p_string, '|') - 1
         END))
       INTO ln_sup_rec_id
       FROM dual;



      SELECT
        CASE
          WHEN instr (p_string, 'SUB ACCT') = 0
          THEN NULL
          ELSE trim (SUBSTR (p_string, instr (p_string, 'SUB ACCT') + 8))
        END
      INTO lc_sub_acct
      FROM dual;

    EXCEPTION
       WHEN others THEN
         ln_sup_rec_id := NULL;
         lc_sub_acct := NULL;
    END;
    BEGIN
        SELECT xsis.supplemental_invoice_field24    -- Deposited Check ID
          INTO lc_deposited_check_id
          FROM xxwar_pymt_stg xps,
               xxwar_batch_stg xbs,
               xxwar_file_stg xfs,
               xxwar_invoice_stg xis,
               xxwar_supp_invoice_stg xsis
         WHERE xps.batch_hdr_id = xbs.batch_hdr_id
           AND xbs.file_number = xfs.file_number
           AND xps.payment_rec_id = xis.payment_rec_id
           AND xsis.invoice_rec_id = xis.invoice_rec_id
           AND xsis.supplemental_rec_id = ln_sup_rec_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
         lc_deposited_check_id := NULL;
    END;

    RETURN CASE WHEN lc_sub_acct IS NOT NULL THEN 'SUB ACCT: '||lc_sub_acct END
             ||
           CASE WHEN lc_sub_acct IS NOT NULL THEN chr(10) END
             ||
           CASE WHEN lc_deposited_check_id IS NOT NULL THEN 'CHECK ID: '||lc_deposited_check_id END;

 END xxwar_dtd_comments;

FUNCTION xxwar_get_invoice_rec_id (p_string VARCHAR2)
RETURN VARCHAR2
IS
ln_is_exists NUMBER;
ln_id NUMBER;
ln_inv_trfmd_rec_id NUMBER;
BEGIN

   SELECT INSTR(p_string,'|SI|')
     INTO ln_is_exists
     FROM dual;

   SELECT TO_NUMBER(SUBSTR(p_string, 2008, 15))
     INTO ln_id
     FROM dual;

    IF ln_is_exists > 0 THEN
       SELECT TIS.inv_trfmd_rec_id
         INTO ln_inv_trfmd_rec_id
         FROM xxwar_supp_invoice_stg SIS,
              xxwar_trfmd_invoice_stg TIS
        WHERE SIS.invoice_rec_id    = TIS.invoice_rec_id
          AND SIS.supplemental_rec_id = ln_id;
    ELSE
       SELECT inv_trfmd_rec_id
         INTO ln_inv_trfmd_rec_id
         FROM xxwar_trfmd_invoice_stg
        WHERE invoice_rec_id = ln_id;
    END IF;
    RETURN TO_CHAR(ln_inv_trfmd_rec_id);
EXCEPTION
  WHEN others THEN
       print_log('Exception in xxwar_receipts_pkg.xxwar_get_invoice_rec_id: '||SQLERRM);
       RETURN NULL;
END xxwar_get_invoice_rec_id;

/* Function added for #ENH72 */
 /*   This Function will fetch the Customer Number and Customer Name by passsing Originator Company Id from
	 the lookup XXWAR_CUST_ACH_COMPID_MAP so that, the receipt will be created with 'Applied' status with
	  proper customer details. */
FUNCTION XXWAR_VALIDATE_CUSTOMER_ACH(P_ORIGINATOR_COMPANY_ID VARCHAR2)
RETURN VARCHAR2
IS
lc_cust_number varchar2(50) :=NULL;
lc_cust_name  varchar2(100) :=NULL;
lc_originator_company_id varchar2(20) :=NULL;
BEGIN
		BEGIN
			SELECT   FLV.MEANING
					,FLV.DESCRIPTION
					,FLV.LOOKUP_CODE
			INTO  lc_cust_number, lc_cust_name, lc_originator_company_id
			FROM  FND_LOOKUP_VALUES FLV,
				  FND_APPLICATION FA
			WHERE FLV.LOOKUP_TYPE = 'XXWAR_CUST_ACH_COMPID_MAP'
			AND   FLV.LOOKUP_CODE = P_ORIGINATOR_COMPANY_ID
			AND   FLV.ENABLED_FLAG = 'Y'
			AND   TRUNC(SYSDATE) BETWEEN TRUNC(NVL(start_date_active,SYSDATE)) AND TRUNC(NVL(end_date_active, SYSDATE ) )
			AND   LANGUAGE = USERENV('LANG')
			AND   FLV.VIEW_APPLICATION_ID = FA.APPLICATION_ID
			AND   FA.APPLICATION_SHORT_NAME = 'AR';
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
							lc_cust_valid_msg := 	'Originator Company Id : '|| P_ORIGINATOR_COMPANY_ID || ', is not mapped to a Customer '||CHR(10)||
													'Or the Customer Mapping is inactive '||CHR(10)||
													'Or The Mapped customer is not valid in Application.';
							lc_cust_number:= NULL;
            WHEN others THEN
							lc_cust_valid_msg := 	'Originator Company Id : '|| P_ORIGINATOR_COMPANY_ID || ', is not mapped to a Customer '||CHR(10)||
												    'Or the Customer Mapping is inactive '||CHR(10)||
												    'Or The Mapped customer is not valid in Application.'||SQLERRM;
							lc_cust_number := NULL;
		END;
		/* If the Customer Number is present in the lookup,enter into the IF condition and check the customer number in the database
              i.e. in 	HZ_CUST_ACCOUNTS table	*/
		IF lc_originator_company_id IS NOT NULL THEN
		 print_log('Entered Inside the IF Condition: '||lc_originator_company_id);
		    BEGIN
			     lc_cust_valid_msg := NULL;
				SELECT  HCA.ACCOUNT_NUMBER
				  INTO  lc_cust_number
				  FROM  HZ_CUST_ACCOUNTS HCA
				 WHERE  HCA.ACCOUNT_NUMBER = lc_cust_number;
				 lc_cust_valid_msg:='Customer Number: '||lc_cust_number ||' for Originator Company Id : '|| P_ORIGINATOR_COMPANY_ID;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					/*	lc_cust_valid_msg := 	'Originator Company Id : '|| P_ORIGINATOR_COMPANY_ID || ', is not mapped to a Customer '||CHR(10)||
												'Or the Customer Mapping is inactive '||CHR(10)||
												'Or The Mapped customer is not valid in Application.';
							lc_cust_number:= NULL;	*/
					print_log('Entered Inside the WHEN NO_DATA_FOUND Exception: ');
					BEGIN
						  lc_cust_valid_msg := NULL;
						SELECT RA.CUSTOMER_NUMBER
						INTO   lc_cust_number
						FROM   RA_CUSTOMERS RA
						WHERE  RA.CUSTOMER_NUMBER = lc_cust_number;
						lc_cust_valid_msg:='Customer Number: '||lc_cust_number ||' for Originator Company Id : '|| P_ORIGINATOR_COMPANY_ID;
					EXCEPTION
					WHEN NO_DATA_FOUND THEN
							lc_cust_valid_msg := 	'Originator Company Id : '|| P_ORIGINATOR_COMPANY_ID || ', is not mapped to a Customer '||CHR(10)||
												    'Or the Customer Mapping is inactive '||CHR(10)||
												    'Or The Mapped customer is not valid in Application.';
							lc_cust_number:= NULL;
					WHEN others THEN
							lc_cust_valid_msg := 	'Originator Company Id : '|| P_ORIGINATOR_COMPANY_ID || ', is not mapped to a Customer '||CHR(10)||
												    'Or the Customer Mapping is inactive '||CHR(10)||
												    'Or The Mapped customer is not valid in Application.'||SQLERRM;
							lc_cust_number := NULL;
					END;


				WHEN others THEN
							lc_cust_valid_msg := 	'Originator Company Id : '|| P_ORIGINATOR_COMPANY_ID || ', is not mapped to a Customer '||CHR(10)||
												    'Or the Customer Mapping is inactive '||CHR(10)||
												    'Or The Mapped customer is not valid in Application.'||SQLERRM;
							lc_cust_number := NULL;
		    END;
	ELSE /* If the Lookup returns NULL  then it enters into ELSE condition */
							lc_cust_valid_msg := 	'Originator Company Id : '|| P_ORIGINATOR_COMPANY_ID || ', is not mapped to a Customer '||CHR(10)||
												    'Or the Customer Mapping is inactive '||CHR(10)||
												    'Or The Mapped customer is not valid in Application.';
							lc_cust_number := NULL;

	END IF;
			RETURN lc_cust_number;
END XXWAR_VALIDATE_CUSTOMER_ACH;
/* Function Ended for #ENH72 */

END xxwar_receipts_pkg;
/
show errors
exit
