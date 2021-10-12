CREATE OR REPLACE PACKAGE BODY xxom_auto_book_order_pkg AS
  --------------------------------------------------------------------
  --  Name         :     xxom_auto_book_order_pkg
  --  Created by   :     Gubendran K
  --  Revision     :     1.0
  --  Creation Date:     04/23/2015
  --------------------------------------------------------------------
  --  Purpose      :    Auto book the sales order, Once the hold is released
  --------------------------------------------------------------------
  --  Version  Date        Name           Description
  --  1.0      04/23/2015  Gubendran K    Initial Build - CHG0031592
  --  1.1      11.10.2018  yuval tal      CHG0044178 add book order
  --  1.2      05.9.19     yuval tal      INC0168330 - modify auto_book_order/book_order
  --------------------------------------------------------------------
  --  Name:            auto_book_order
  --  Create by:       Gubendran K
  --  Revision:        1.0
  --  Creation Date:   04/23/2015
  --------------------------------------------------------------------
  --  purpose :        Auto book the sales order, Once the hold is released
  --------------------------------------------------------------------
  --  Version  Date        Name           Description
  --  1.0      04/23/2015  Gubendran K    Initial Build - CHG0031592
  --  1.1      23.10.2018  Diptasurjya    CHG0044273 - Do apps initialize with user pass as input
  --  1.2      06-Feb-2019 Diptasurjya    INC0146497 - change hold check criteria in book_order
  --  1.3      20-Jun-2019 Diptasurjya    CHG0045885 - Change auto book error report format
  --  1.4       05.9.19     yuval tal     INC0168330 - replace ; to , in receipient list 
  --------------------------------------------------------------------
  PROCEDURE auto_book_order(errbuf               OUT VARCHAR2,
		    retcode              OUT NUMBER,
		    p_order_source_id    IN NUMBER,
		    p_created_by_user_id IN NUMBER,
		    p_send_mail          IN VARCHAR2,
		    p_org_id             IN NUMBER) IS
  
    g_request_id CONSTANT NUMBER := fnd_global.conc_request_id;
    --g_email_address      VARCHAR2(150) := NULL;
    l_api_version_number NUMBER := 1.0;
    l_return_status      VARCHAR2(2000);
    l_return_status_out  VARCHAR2(2000);
    l_msg_count          NUMBER;
    l_msg_data           VARCHAR2(2000);
    l_debug_level        NUMBER := fnd_profile.value('ONT_DEBUG_LEVEL');
    -- IN Variables --
    l_header_rec         oe_order_pub.header_rec_type;
    l_line_tbl           oe_order_pub.line_tbl_type;
    l_action_request_tbl oe_order_pub.request_tbl_type;
    l_line_adj_tbl       oe_order_pub.line_adj_tbl_type;
    -- OUT Variables --
    l_header_rec_out             oe_order_pub.header_rec_type;
    l_header_val_rec_out         oe_order_pub.header_val_rec_type;
    l_header_adj_tbl_out         oe_order_pub.header_adj_tbl_type;
    l_header_adj_val_tbl_out     oe_order_pub.header_adj_val_tbl_type;
    l_header_price_att_tbl_out   oe_order_pub.header_price_att_tbl_type;
    l_header_adj_att_tbl_out     oe_order_pub.header_adj_att_tbl_type;
    l_header_adj_assoc_tbl_out   oe_order_pub.header_adj_assoc_tbl_type;
    l_header_scredit_tbl_out     oe_order_pub.header_scredit_tbl_type;
    l_header_scredit_val_tbl_out oe_order_pub.header_scredit_val_tbl_type;
    l_line_tbl_out               oe_order_pub.line_tbl_type;
    l_line_val_tbl_out           oe_order_pub.line_val_tbl_type;
    l_line_adj_tbl_out           oe_order_pub.line_adj_tbl_type;
    l_line_adj_val_tbl_out       oe_order_pub.line_adj_val_tbl_type;
    l_line_price_att_tbl_out     oe_order_pub.line_price_att_tbl_type;
    l_line_adj_att_tbl_out       oe_order_pub.line_adj_att_tbl_type;
    l_line_adj_assoc_tbl_out     oe_order_pub.line_adj_assoc_tbl_type;
    l_line_scredit_tbl_out       oe_order_pub.line_scredit_tbl_type;
    l_line_scredit_val_tbl_out   oe_order_pub.line_scredit_val_tbl_type;
    l_lot_serial_tbl_out         oe_order_pub.lot_serial_tbl_type;
    l_lot_serial_val_tbl_out     oe_order_pub.lot_serial_val_tbl_type;
    l_action_request_tbl_out     oe_order_pub.request_tbl_type;
    l_action_request_tbl_index   NUMBER := 0;
    l_error_message              VARCHAR2(2000);
    -- l_user_id                    NUMBER := fnd_global.user_id;
    --  l_resp_id                    NUMBER := fnd_global.resp_id;
    -- l_resp_appl_id               NUMBER := fnd_global.resp_appl_id;
  
    l_header_insert NUMBER := 1;
    l_debug_file    VARCHAR2(200);
    l_data          VARCHAR2(2000);
    l_msg_index     NUMBER;
    -- l_booked_flag            NUMBER;
    l_order_no               VARCHAR2(30) := NULL;
    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
    --p_send_mail VARCHAR2(20):='Y';
    --l_mail_header   NUMBER := 1;
    l_error_exist   VARCHAR2(20) := 'N';
    l_mail_list     VARCHAR2(500);
    l_success_count NUMBER := 0;
    l_failure_count NUMBER := 0;
  
    CURSOR c_hdr_id IS
      SELECT order_number,
	 header_id,
	 org_id,
	 flow_status_code
      FROM   oe_order_headers_all oha
      WHERE  oha.flow_status_code = 'ENTERED'
      AND    oha.created_by = nvl(p_created_by_user_id, oha.created_by)
      AND    oha.order_source_id =
	 nvl(p_order_source_id, oha.order_source_id)
      AND    oha.org_id = nvl(p_org_id, oha.org_id)
      AND    EXISTS (SELECT 1
	  FROM   oe_order_holds_all  oh,
	         oe_hold_sources_all hs,
	         oe_hold_releases    hr,
	         oe_hold_definitions hd
	  WHERE  oh.hold_source_id = hs.hold_source_id
	  AND    hs.hold_id = hd.hold_id
	  AND    oh.hold_release_id = hr.hold_release_id
	  AND    hs.org_id = oh.org_id
	  AND    hs.released_flag = 'Y'
	  AND    oh.header_id = oha.header_id)
      AND    NOT EXISTS
       (SELECT 1
	  FROM   oe_order_holds_all  oh,
	         oe_hold_sources_all hs,
	         oe_hold_releases    hr,
	         oe_hold_definitions hd
	  WHERE  oh.hold_source_id = hs.hold_source_id
	  AND    hs.hold_id = hd.hold_id
	  AND    oh.hold_release_id = hr.hold_release_id
	  AND    hs.org_id = oh.org_id
	  AND    nvl(hs.released_flag, 'N') = 'N'
	  AND    oh.header_id = oha.header_id);
  
  BEGIN
    -- Setting the Enviroment
    mo_global.init('ONT');
  
    IF (l_debug_level > 0) THEN
      oe_debug_pub.initialize;
      l_debug_file := oe_debug_pub.set_debug_mode('FILE');
      oe_debug_pub.setdebuglevel(l_debug_level);
    END IF;
  
    l_mail_list := REPLACE(xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					           p_program_short_name => 'XXOM_AUTO_BOOK_ORDER'),
		   ';',
		   ','); --INC0168330
  
    FOR i IN c_hdr_id LOOP
      oe_msg_pub.initialize;
      mo_global.set_policy_context('S', i.org_id);
      l_action_request_tbl_index := 1;
      l_action_request_tbl(l_action_request_tbl_index) := oe_order_pub.g_miss_request_rec;
      l_action_request_tbl(l_action_request_tbl_index).request_type := oe_globals.g_book_order;
      l_action_request_tbl(l_action_request_tbl_index).entity_code := oe_globals.g_entity_header;
      l_action_request_tbl(l_action_request_tbl_index).entity_id := i.header_id;
    
      -- Calling the API to Book an Existing Order --
      oe_order_pub.process_order(p_api_version_number => l_api_version_number,
		         p_header_rec         => l_header_rec,
		         p_line_tbl           => l_line_tbl,
		         p_action_request_tbl => l_action_request_tbl,
		         p_line_adj_tbl       => l_line_adj_tbl,
		         -- OUT variables
		         x_header_rec             => l_header_rec_out,
		         x_header_val_rec         => l_header_val_rec_out,
		         x_header_adj_tbl         => l_header_adj_tbl_out,
		         x_header_adj_val_tbl     => l_header_adj_val_tbl_out,
		         x_header_price_att_tbl   => l_header_price_att_tbl_out,
		         x_header_adj_att_tbl     => l_header_adj_att_tbl_out,
		         x_header_adj_assoc_tbl   => l_header_adj_assoc_tbl_out,
		         x_header_scredit_tbl     => l_header_scredit_tbl_out,
		         x_header_scredit_val_tbl => l_header_scredit_val_tbl_out,
		         x_line_tbl               => l_line_tbl_out,
		         x_line_val_tbl           => l_line_val_tbl_out,
		         x_line_adj_tbl           => l_line_adj_tbl_out,
		         x_line_adj_val_tbl       => l_line_adj_val_tbl_out,
		         x_line_price_att_tbl     => l_line_price_att_tbl_out,
		         x_line_adj_att_tbl       => l_line_adj_att_tbl_out,
		         x_line_adj_assoc_tbl     => l_line_adj_assoc_tbl_out,
		         x_line_scredit_tbl       => l_line_scredit_tbl_out,
		         x_line_scredit_val_tbl   => l_line_scredit_val_tbl_out,
		         x_lot_serial_tbl         => l_lot_serial_tbl_out,
		         x_lot_serial_val_tbl     => l_lot_serial_val_tbl_out,
		         x_action_request_tbl     => l_action_request_tbl_out,
		         x_return_status          => l_return_status_out,
		         x_msg_count              => l_msg_count,
		         x_msg_data               => l_msg_data);
      BEGIN
        IF l_action_request_tbl_out(l_action_request_tbl_index)
         .return_status <> fnd_api.g_ret_sts_success THEN
          IF l_header_insert = 1 THEN
	l_error_message                          := NULL;
	l_xxssys_generic_rpt_rec.request_id      := g_request_id;
	l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
	l_xxssys_generic_rpt_rec.email_to        := 'EMAIL';
	l_xxssys_generic_rpt_rec.col1            := 'Order Number';
	l_xxssys_generic_rpt_rec.col_msg         := 'Error Message';
          
	xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
				          x_return_status          => l_return_status,
				          x_return_message         => l_error_message);
          
	IF l_return_status <> 'S' THEN
	  fnd_file.put_line(fnd_file.log,
		        'Error Report Prompts' || l_error_message);
	END IF;
          END IF;
          l_error_exist   := 'Y';
          l_failure_count := l_failure_count + 1;
          l_order_no      := i.order_number;
          FOR i IN 1 .. l_msg_count LOOP
	l_header_insert := l_header_insert + 1;
	oe_msg_pub.get(p_msg_index     => i,
		   p_encoded       => fnd_api.g_false,
		   p_data          => l_data,
		   p_msg_index_out => l_msg_index);
	fnd_file.put_line(fnd_file.log, 'Message is:' || l_data);
	fnd_file.put_line(fnd_file.log,
		      'Message Index is:' || l_msg_index);
	fnd_file.put_line(fnd_file.log,
		      'Booking of an Existing Order failed:' ||
		      l_order_no || ':' || l_data);
	IF l_data <> 'Order has been booked.' THEN
	  l_xxssys_generic_rpt_rec.request_id      := g_request_id;
	  l_xxssys_generic_rpt_rec.header_row_flag := 'N';
	  l_xxssys_generic_rpt_rec.email_to        := l_mail_list;
	  l_xxssys_generic_rpt_rec.col1            := l_order_no;
	  l_xxssys_generic_rpt_rec.col_msg         := l_data;
	
	  xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
					x_return_status          => l_return_status,
					x_return_message         => l_error_message);
	  IF l_return_status <> 'S' THEN
	    fnd_file.put_line(fnd_file.log,
		          'Error Report Prompts' || l_error_message);
	  END IF;
	END IF;
          END LOOP;
          ROLLBACK;
        ELSE
          COMMIT;
          l_success_count := l_success_count + 1;
          fnd_file.put_line(fnd_file.log,
		    'Booking of an Existing Order is Success: ' ||
		    i.order_number);
        END IF;
      END;
    END LOOP;
    fnd_file.put_line(fnd_file.log,
	          'Total No of Orders Booked Successfully: ======>' ||
	          l_success_count);
    fnd_file.put_line(fnd_file.log,
	          'Total No of Unbooked Orders =====>' ||
	          l_failure_count);
  
    -- Display Return Status Flags
    IF (l_debug_level > 0) THEN
      fnd_file.put_line(fnd_file.log,
		'Book Order Return Status is: ======>' ||
		l_return_status_out);
      fnd_file.put_line(fnd_file.log,
		'Book Order Message Data is: =======>' ||
		l_msg_data);
      fnd_file.put_line(fnd_file.log,
		'Book Order Message Count is:=======>' ||
		l_msg_count);
    END IF;
  
    IF p_send_mail = 'Y' AND l_error_exist = 'Y' THEN
      xxssys_generic_rpt_pkg.submit_request(p_burst_flag         => 'Y',
			        p_request_id         => g_request_id,
			        p_l_report_title     => '''' ||
					        'Summary of Auto Book Order Error Report' || '''',
			        p_l_email_subject    => '''' ||
					        'Summary of Auto Book Order Error Report' || '''',
			        p_l_email_body1      => '''' ||
					        'Please find the error report of unbooked orders' || '''',
			        p_l_order_by         => 'TO_NUMBER(col1)',
			        p_l_file_name        => '''' ||
					        'Auto_Book_Order_Report' ||
					        '.xls' || '''',
			        p_l_purge_table_flag => 'Y',
			        x_return_status      => l_return_status,
			        x_return_message     => l_error_message);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := substr('Unexpected Error in Auto Book Order: ' ||
		        SQLERRM,
		        1,
		        200);
      fnd_file.put_line(fnd_file.log, l_error_message);
      errbuf  := l_error_message;
      retcode := '2';
  END auto_book_order;

  --------------------------------------------------------------------
  --  purpose :        Auto book the sales order without holds
  --                   used by XXOM Order Book/XXOM_ORDER_BOOK
  --                   must be submited  from region OU resposibility
  --------------------------------------------------------------------
  --  Version  Date        Name           Description
  --  1.0      11.10.2018  yuval tal      CHG0044178 book order in enter status without hold
  --  1.1      23.10.2018  Diptasurjya    CHG0044273 - Do apps initialize with user pass as input
  --                                      and OM responsibility corresponding to org id input
  --  1.2      06-Feb-2019 Diptasurjya    INC0146497 - change hold check criteria
  --  1.3      20-Jun-2019 Diptasurjya    CHG0045885 - Error report format changes
  --  1.4      05.9.19     yuval tal      INC0168330 - replace ; to , in receipient list 
  --------------------------------------------------------------------
  PROCEDURE book_order(errbuf               OUT VARCHAR2,
	           retcode              OUT NUMBER,
	           p_order_source_id    IN NUMBER,
	           p_created_by_user_id IN NUMBER,
	           p_send_mail          IN VARCHAR2,
	           p_org_id             IN NUMBER) IS
  
    g_request_id CONSTANT NUMBER := fnd_global.conc_request_id;
  
    l_api_version_number NUMBER := 1.0;
    l_return_status      VARCHAR2(2000);
    l_return_status_out  VARCHAR2(2000);
    l_msg_count          NUMBER;
    l_msg_data           VARCHAR2(2000);
    l_debug_level        NUMBER := fnd_profile.value('ONT_DEBUG_LEVEL');
    -- IN Variables --
    l_header_rec         oe_order_pub.header_rec_type;
    l_line_tbl           oe_order_pub.line_tbl_type;
    l_action_request_tbl oe_order_pub.request_tbl_type;
    l_line_adj_tbl       oe_order_pub.line_adj_tbl_type;
    -- OUT Variables --
    l_header_rec_out             oe_order_pub.header_rec_type;
    l_header_val_rec_out         oe_order_pub.header_val_rec_type;
    l_header_adj_tbl_out         oe_order_pub.header_adj_tbl_type;
    l_header_adj_val_tbl_out     oe_order_pub.header_adj_val_tbl_type;
    l_header_price_att_tbl_out   oe_order_pub.header_price_att_tbl_type;
    l_header_adj_att_tbl_out     oe_order_pub.header_adj_att_tbl_type;
    l_header_adj_assoc_tbl_out   oe_order_pub.header_adj_assoc_tbl_type;
    l_header_scredit_tbl_out     oe_order_pub.header_scredit_tbl_type;
    l_header_scredit_val_tbl_out oe_order_pub.header_scredit_val_tbl_type;
    l_line_tbl_out               oe_order_pub.line_tbl_type;
    l_line_val_tbl_out           oe_order_pub.line_val_tbl_type;
    l_line_adj_tbl_out           oe_order_pub.line_adj_tbl_type;
    l_line_adj_val_tbl_out       oe_order_pub.line_adj_val_tbl_type;
    l_line_price_att_tbl_out     oe_order_pub.line_price_att_tbl_type;
    l_line_adj_att_tbl_out       oe_order_pub.line_adj_att_tbl_type;
    l_line_adj_assoc_tbl_out     oe_order_pub.line_adj_assoc_tbl_type;
    l_line_scredit_tbl_out       oe_order_pub.line_scredit_tbl_type;
    l_line_scredit_val_tbl_out   oe_order_pub.line_scredit_val_tbl_type;
    l_lot_serial_tbl_out         oe_order_pub.lot_serial_tbl_type;
    l_lot_serial_val_tbl_out     oe_order_pub.lot_serial_val_tbl_type;
    l_action_request_tbl_out     oe_order_pub.request_tbl_type;
    l_action_request_tbl_index   NUMBER := 0;
    l_error_message              VARCHAR2(2000);
  
    l_header_insert NUMBER := 1;
    l_debug_file    VARCHAR2(200);
    l_data          VARCHAR2(2000);
    l_msg_index     NUMBER;
    -- l_booked_flag            NUMBER;
    l_order_no               VARCHAR2(30) := NULL;
    l_cust_name              VARCHAR2(2000);
    l_cust_number            VARCHAR2(200);
    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
    --p_send_mail VARCHAR2(20):='Y';
  
    l_error_exist   VARCHAR2(20) := 'N';
    l_mail_list     VARCHAR2(500);
    l_success_count NUMBER := 0;
    l_failure_count NUMBER := 0;
  
    l_resp_id  NUMBER; -- CHG0044273
    l_org_name VARCHAR2(240); -- CHG0045885 added
  
    CURSOR c_hdr_id IS
      SELECT order_number,
	 header_id,
	 oha.org_id,
	 flow_status_code,
	 hp.party_name, -- CHG0045885 add
	 hca.account_number -- CHG0045885 add
      FROM   oe_order_headers_all oha,
	 hz_cust_accounts     hca, -- CHG0045885 add
	 hz_parties           hp -- CHG0045885 add
      WHERE  oha.flow_status_code = 'ENTERED'
      AND    oha.created_by = nvl(p_created_by_user_id, oha.created_by)
      AND    oha.order_source_id =
	 nvl(p_order_source_id, oha.order_source_id)
      AND    oha.org_id = nvl(p_org_id, oha.org_id)
      AND    oha.sold_to_org_id = hca.cust_account_id -- CHG0045885 add
      AND    hca.party_id = hp.party_id -- CHG0045885 add
      AND    NOT EXISTS
       (SELECT 1
	  FROM   oe_order_holds_all  oh,
	         oe_hold_sources_all hs,
	         oe_hold_releases    hr,
	         oe_hold_definitions hd
	  WHERE  oh.hold_source_id = hs.hold_source_id
	  AND    hs.hold_id = hd.hold_id
	  AND    oh.hold_release_id = hr.hold_release_id
	  AND    hs.org_id = oh.org_id
	        --AND    nvl(hs.released_flag, 'N') = 'N'  -- INC0146497 commented
	  AND    nvl(oh.released_flag, 'N') = 'N' -- INC0146497 added
	  AND    oh.header_id = oha.header_id);
  
  BEGIN
    -- Setting the Enviroment
    -- CHG0044273 - begin responsibility id determination based on user ID and org ID
    BEGIN
      SELECT fr.responsibility_id
      INTO   l_resp_id
      FROM   fnd_profile_options_vl    fpo,
	 fnd_profile_option_values fpov,
	 fnd_responsibility_vl     fr,
	 fnd_user_resp_groups_all  furg
      WHERE  fpo.profile_option_name = 'ORG_ID'
      AND    fpo.profile_option_id = fpov.profile_option_id
      AND    profile_option_value = p_org_id
      AND    fpov.level_value = fr.responsibility_id
      AND    fr.responsibility_id = furg.responsibility_id
      AND    furg.responsibility_application_id = 660
      AND    furg.user_id = p_created_by_user_id
      AND    SYSDATE BETWEEN nvl(furg.start_date, SYSDATE - 1) AND
	 nvl(furg.end_date, SYSDATE + 1)
      AND    SYSDATE BETWEEN nvl(fr.start_date, SYSDATE - 1) AND
	 nvl(fr.end_date, SYSDATE + 1)
      AND    rownum = 1;
    EXCEPTION
      WHEN no_data_found THEN
        fnd_file.put_line(fnd_file.log,
		  'ERROR: No active OM responsibility for user ' ||
		  p_created_by_user_id || ' and organization ID ' ||
		  p_org_id || ' combination found');
        errbuf  := l_error_message;
        retcode := '2';
      
        RETURN;
    END;
    -- CHG0044273 - responsibility ID determination end
  
    fnd_global.apps_initialize(p_created_by_user_id, l_resp_id, 660); -- CHG0044273 - Do apps initialize
    mo_global.init('ONT');
  
    IF (l_debug_level > 0) THEN
      oe_debug_pub.initialize;
      l_debug_file := oe_debug_pub.set_debug_mode('FILE');
      oe_debug_pub.setdebuglevel(l_debug_level);
    END IF;
  
    l_mail_list := REPLACE(xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => p_org_id,
					           p_program_short_name => 'XXOM_BOOK_ORDER'),
		   ';',
		   ','); --INC0168330
  
    FOR i IN c_hdr_id LOOP
      oe_msg_pub.initialize;
      mo_global.set_policy_context('S', i.org_id);
      l_action_request_tbl_index := 1;
      l_action_request_tbl(l_action_request_tbl_index) := oe_order_pub.g_miss_request_rec;
      l_action_request_tbl(l_action_request_tbl_index).request_type := oe_globals.g_book_order;
      l_action_request_tbl(l_action_request_tbl_index).entity_code := oe_globals.g_entity_header;
      l_action_request_tbl(l_action_request_tbl_index).entity_id := i.header_id;
    
      -- Calling the API to Book an Existing Order --
      oe_order_pub.process_order(p_api_version_number => l_api_version_number,
		         p_header_rec         => l_header_rec,
		         p_line_tbl           => l_line_tbl,
		         p_action_request_tbl => l_action_request_tbl,
		         p_line_adj_tbl       => l_line_adj_tbl,
		         -- OUT variables
		         x_header_rec             => l_header_rec_out,
		         x_header_val_rec         => l_header_val_rec_out,
		         x_header_adj_tbl         => l_header_adj_tbl_out,
		         x_header_adj_val_tbl     => l_header_adj_val_tbl_out,
		         x_header_price_att_tbl   => l_header_price_att_tbl_out,
		         x_header_adj_att_tbl     => l_header_adj_att_tbl_out,
		         x_header_adj_assoc_tbl   => l_header_adj_assoc_tbl_out,
		         x_header_scredit_tbl     => l_header_scredit_tbl_out,
		         x_header_scredit_val_tbl => l_header_scredit_val_tbl_out,
		         x_line_tbl               => l_line_tbl_out,
		         x_line_val_tbl           => l_line_val_tbl_out,
		         x_line_adj_tbl           => l_line_adj_tbl_out,
		         x_line_adj_val_tbl       => l_line_adj_val_tbl_out,
		         x_line_price_att_tbl     => l_line_price_att_tbl_out,
		         x_line_adj_att_tbl       => l_line_adj_att_tbl_out,
		         x_line_adj_assoc_tbl     => l_line_adj_assoc_tbl_out,
		         x_line_scredit_tbl       => l_line_scredit_tbl_out,
		         x_line_scredit_val_tbl   => l_line_scredit_val_tbl_out,
		         x_lot_serial_tbl         => l_lot_serial_tbl_out,
		         x_lot_serial_val_tbl     => l_lot_serial_val_tbl_out,
		         x_action_request_tbl     => l_action_request_tbl_out,
		         x_return_status          => l_return_status_out,
		         x_msg_count              => l_msg_count,
		         x_msg_data               => l_msg_data);
      BEGIN
        IF l_action_request_tbl_out(l_action_request_tbl_index)
         .return_status <> fnd_api.g_ret_sts_success THEN
          IF l_header_insert = 1 THEN
	l_error_message                          := NULL;
	l_xxssys_generic_rpt_rec.request_id      := g_request_id;
	l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
	l_xxssys_generic_rpt_rec.email_to        := 'EMAIL';
	l_xxssys_generic_rpt_rec.col1            := 'Order Number';
	l_xxssys_generic_rpt_rec.col2            := 'Customer Name'; -- CHG0045885 add
	l_xxssys_generic_rpt_rec.col3            := 'Account Number'; -- CHG0045885 add
	l_xxssys_generic_rpt_rec.col_msg         := 'Error Message';
          
	xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
				          x_return_status          => l_return_status,
				          x_return_message         => l_error_message);
          
	IF l_return_status <> 'S' THEN
	  fnd_file.put_line(fnd_file.log,
		        'Error Report Prompts' || l_error_message);
	END IF;
          END IF;
          l_error_exist   := 'Y';
          l_failure_count := l_failure_count + 1;
          l_order_no      := i.order_number;
          l_cust_name     := i.party_name;
          l_cust_number   := i.account_number;
          FOR i IN 1 .. l_msg_count LOOP
	l_header_insert := l_header_insert + 1;
	oe_msg_pub.get(p_msg_index     => i,
		   p_encoded       => fnd_api.g_false,
		   p_data          => l_data,
		   p_msg_index_out => l_msg_index);
	fnd_file.put_line(fnd_file.log, 'Message is:' || l_data);
	fnd_file.put_line(fnd_file.log,
		      'Message Index is:' || l_msg_index);
	fnd_file.put_line(fnd_file.log,
		      'Booking of an Existing Order failed:' ||
		      l_order_no || ':' || l_data);
	IF l_data <> 'Order has been booked.' THEN
	  l_xxssys_generic_rpt_rec.request_id      := g_request_id;
	  l_xxssys_generic_rpt_rec.header_row_flag := 'N';
	  l_xxssys_generic_rpt_rec.email_to        := l_mail_list;
	  l_xxssys_generic_rpt_rec.col1            := l_order_no;
	  l_xxssys_generic_rpt_rec.col2            := l_cust_name; -- CHG0045885 add
	  l_xxssys_generic_rpt_rec.col3            := l_cust_number; -- CHG0045885 add
	  l_xxssys_generic_rpt_rec.col_msg         := l_data;
	
	  xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
					x_return_status          => l_return_status,
					x_return_message         => l_error_message);
	  IF l_return_status <> 'S' THEN
	    fnd_file.put_line(fnd_file.log,
		          'Error Report Prompts' || l_error_message);
	  END IF;
	END IF;
          END LOOP;
          ROLLBACK;
        ELSE
          COMMIT;
          l_success_count := l_success_count + 1;
          fnd_file.put_line(fnd_file.log,
		    'Booking of an Existing Order is Success: ' ||
		    i.order_number);
        END IF;
      END;
    END LOOP;
    fnd_file.put_line(fnd_file.log,
	          'Total No of Orders Booked Successfully: ======>' ||
	          l_success_count);
    fnd_file.put_line(fnd_file.log,
	          'Total No of Unbooked Orders =====>' ||
	          l_failure_count);
  
    -- Display Return Status Flags
    IF (l_debug_level > 0) THEN
      fnd_file.put_line(fnd_file.log,
		'Book Order Return Status is: ======>' ||
		l_return_status_out);
      fnd_file.put_line(fnd_file.log,
		'Book Order Message Data is: =======>' ||
		l_msg_data);
      fnd_file.put_line(fnd_file.log,
		'Book Order Message Count is:=======>' ||
		l_msg_count);
    END IF;
  
    fnd_file.put_line(fnd_file.log,
	          'p_send_mail=' || p_send_mail || ' ' ||
	          'l_error_exist=' || l_error_exist);
  
    IF p_send_mail = 'Y' AND l_error_exist = 'Y' THEN
      l_org_name := xxhr_util_pkg.get_org_name(p_org_id); -- CHG0045885 add
      xxssys_generic_rpt_pkg.submit_request(p_burst_flag         => 'Y',
			        p_request_id         => g_request_id,
			        p_l_report_title     => '''' ||
					        'Summary of Auto Book Order Error Report - ' ||
					        l_org_name || '''', -- CHG0045885 append org name
			        p_l_email_subject    => '''' ||
					        'Summary of Auto Book Order Error Report - ' ||
					        l_org_name || '''', -- CHG0045885 append org name
			        p_l_email_body1      => '''' ||
					        'Please find the error report of unbooked orders' || '''',
			        p_l_order_by         => 'TO_NUMBER(col1)',
			        p_l_file_name        => '''' ||
					        'Book_Err_' ||
					        REPLACE(l_org_name,
						    ' ',
						    '_') ||
					        '.xls' || '''', -- CHG0045885 append org name after replacing space
			        p_l_purge_table_flag => 'Y',
			        x_return_status      => l_return_status,
			        x_return_message     => l_error_message);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := substr('Unexpected Error in Auto Book Order: ' ||
		        SQLERRM,
		        1,
		        200);
      fnd_file.put_line(fnd_file.log, l_error_message);
      errbuf  := l_error_message;
      retcode := '2';
  END;

END xxom_auto_book_order_pkg;
/
