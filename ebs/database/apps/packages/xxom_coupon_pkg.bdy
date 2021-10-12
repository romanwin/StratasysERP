create or replace package body xxom_coupon_pkg IS

  ----------------------------------------------------------
  -- Author  : PIYALI.BHOWMICK
  -- Created : 7/8/2017 12:45:36
  -- Purpose :To generate the Coupon events and insert  
  --          into the Staging Table xxssys_events
  --             
  -- ---------------------------------------------------------
  --------------------------------------------------------------------------
  -- Version  Date      Performer             Comments
  ----------  --------  --------------       -------------------------------------
  --
  --   1.1    7.8.2017     Piyali Bhowmick     CHG0041104- Initial Build 
  ------------------------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            generate_coupon
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   7/08/201710/7/2017 12:45:36
  --------------------------------------------------------------------
  --  purpose :  To generate the Coupon events and insert
  --             into the Staging Table xxssys_events 
  --             
  --------------------------------------------------------------------
  --   1.0    7.8.2017    Piyali Bhowmick      CHG0041104- to generate Coupon Events and insert 
  --                                           it into the Staging Table xxssys_events
  -------------------------------------------------------------------------------------------

  PROCEDURE generate_coupon(errbuf      OUT NOCOPY VARCHAR2,
		    retcode     OUT NOCOPY NUMBER,
		    p_days_back NUMBER) IS
    CURSOR c_coupon IS
      SELECT *
      FROM   xxom_coupon_v ocv
      WHERE  ocv.actual_shipment_date > (SYSDATE - p_days_back)
      AND    NOT EXISTS
       (SELECT 1
	  FROM   xxssys_events se
	  WHERE  se.target_name = 'OMCOUPON'
	  AND    se.entity_id = ocv.coupon_number
	  AND    se.attribute1 = ocv.header_id
      AND    se.entity_name = 'OMCOUPON'
	  AND    se.status IN ('SUCCESS', 'NEW'));
  
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    
    c_record  number(10):= 0;
  
  BEGIN
    l_xxssys_event_rec.entity_name := 'OMCOUPON';
    l_xxssys_event_rec.target_name := 'OMCOUPON';
  
    -- fetch coupon info 
    FOR i IN c_coupon LOOP

      l_xxssys_event_rec.entity_id  := i.coupon_number;
      l_xxssys_event_rec.attribute1 := i.header_id;
      l_xxssys_event_rec.attribute2 := i.org_id;
    
       
         
         
         
    
      -- insert into stage table xxssys_events 
      xxssys_event_pkg.insert_event(l_xxssys_event_rec);
      
      c_record :=c_record+1;
      
     
    END LOOP;
    COMMIT;
    fnd_file.put_line(fnd_file.log,'No. the record that are inserted to stage table XXSSYS_EVENTS '||c_record);
                  
    
   process_coupon_events;
   
    retcode := 0;
  EXCEPTION
  
    WHEN OTHERS THEN
    
      errbuf  := SQLERRM;
      retcode := '2'; -- error 
  
  END generate_coupon;

  -- --------------------------------------------------------------------------------------------
  -- Purpose:  CHG0041104- To submit  Coupon voucher  and update the status
  -- --------------------------------------------------------------------------------------------
  -- Ver    Date        Name                          Description
  -- 1.0   7.8.2017    Piyali Bhowmick            Initial Build
  --                                           CHG0041104- To submit  Coupon voucher 
  --                                           and update the status
  -- -----------------------------------------------------------------------------

  PROCEDURE process_coupon_events IS
  
    -- cursor 
    CURSOR c_coupon_events IS
      SELECT event_id,
	 err_message,
	 entity_id   AS coupon_number,
	 attribute1  AS header_id,
	 attribute2  AS org_id
     
      FROM   xxssys_events
      WHERE  status = 'NEW'
      AND    target_name = 'OMCOUPON';
  
    l_request_id       NUMBER;
    lc_phase           VARCHAR2(50);
    lc_status          VARCHAR2(50);
    lc_dev_phase       VARCHAR2(50);
    lc_dev_status      VARCHAR2(50);
    lc_message         VARCHAR2(50);
    l_complete         BOOLEAN;
    lb_flag            BOOLEAN := FALSE;
    l_result           BOOLEAN;
    l_burst_request_id NUMBER;
  
    l_email_list VARCHAR2(2400);
  
    l_is_valid  VARCHAR2(2);
    l_valid     VARCHAR2(2400);
    l_not_valid VARCHAR2(2400); 
     c_request number(10):=0;
  BEGIN
  
    -- loop over coupon events in status NEW  
    FOR i IN c_coupon_events LOOP
      l_email_list := xxobjt_general_utils_pkg
	         .get_dist_mail_list(i.org_id, 'XXOMCOUPON');
          
      
         fnd_file.put_line(fnd_file.log,'List of email'|| l_email_list );
                  
        
    
      --Check whether the mail is valid or not  
      if(  l_email_list IS NOT NULL) then
              
        xxobjt_general_utils_pkg.validate_mail_list(l_email_list,
                    ';',
                    l_is_valid,
                    l_valid,
                    l_not_valid); 
        else
          l_is_valid :='N';   
      end if;              
    
      IF l_is_valid = 'N' THEN
        
        fnd_file.put_line(fnd_file.log,
          'Email not valid for coupon : ' ||
          i.coupon_number || ' Bad Mail :' || l_not_valid);
        xxssys_event_pkg.update_error(i.event_id,
              'Email not valid for coupon : ' ||
              i.coupon_number || ' Bad Mail :' ||
              l_not_valid);
        COMMIT;
        
        continue;
        
      END IF;   
        
     
      --
    
      l_request_id := 0;
      l_result     := fnd_request.add_layout(template_appl_name => 'XXOBJT',
			         template_code      => 'XXOMCOUPONR',
			         template_language  => 'en',
			         template_territory => 'US', -- 'IL'
			         output_format      => 'PDF');
    
      lb_flag := fnd_request.set_print_options(printer     => 'noprint',
			           copies      => 0,
			           save_output => TRUE);
      --  per event submit XX OM Coupon Report/XXOMCOUPONR 
      l_request_id := fnd_request.submit_request(application => 'XXOBJT', -- Application Short Name
				 program     => 'XXOMCOUPONR', -- Program Short Name                                                 
				 -- description => 'XX OM produce Coupon Vouchers', -- Any Meaningful Description
				 start_time => SYSDATE, -- Start Time
				 -- sub_request => true, -- Subrequest Default False
				 argument1 => i.header_id,
				 argument2 => i.coupon_number,
				 argument3 => 'Y',
				 argument4 => i.event_id);
    
      COMMIT;
    
      -- wait for completion 
    
      IF l_request_id = 0 THEN
      
        xxssys_event_pkg.update_error(i.event_id,
			  'Failure in  Submitting the Concurrent Request for coupon  ' ||
			  i.coupon_number || ' - ' ||
			  fnd_message.get);
      
        COMMIT;
      
      ELSIF l_request_id > 0 THEN
      
        l_complete := fnd_concurrent.wait_for_request(request_id => l_request_id, -- request_id to wait on
				      INTERVAL   => 2, -- time b/w checks..No of Sec to sleep
				      max_wait   => 600, -- max amt of time to wait for completion
				      phase      => lc_phase,
				      status     => lc_status,
				      dev_phase  => lc_dev_phase,
				      dev_status => lc_dev_status,
				      message    => lc_message);
      
        COMMIT;
      
        -- On success  update event to SUCCESS / ERROR on failure
        IF upper(lc_dev_phase) IN ('COMPLETE') THEN
        
          UPDATE xxssys_events
          SET    status           = 'SUCCESS',
	     attribute4       = substr(xxobjt_general_utils_pkg
			       .get_dist_mail_list(i.org_id,
					  'XXOMCOUPON'),
			       1,
			       2000),
	     last_update_date = SYSDATE
          WHERE  event_id = i.event_id;
          COMMIT;
        
          fnd_file.put_line(fnd_file.log,
		    'Successfully Submitted  Request for coupon  ' ||
		    i.coupon_number || ' request_id=' ||
		    l_request_id);
        ELSE
          xxssys_event_pkg.update_error(i.event_id,
			    'Failure in  Submitting the Concurrent Request:' ||
			    l_request_id || ' ' ||
			    fnd_message.get);
        
          COMMIT;
        END IF;
      
      END IF;
       c_request :=c_request+1;
    END LOOP;
      fnd_file.put_line(fnd_file.log,
		    'Number of Request Submitted' ||c_request);
        
  END process_coupon_events;

END xxom_coupon_pkg;
/