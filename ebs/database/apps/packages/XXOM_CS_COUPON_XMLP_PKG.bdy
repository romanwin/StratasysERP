CREATE OR REPLACE PACKAGE BODY XXOM_CS_COUPON_XMLP_PKG AS

  ----------------------------------------------------------
  -- Author  : PIYALI.BHOWMICK
  -- Created : 10/7/2017 15:45:29
  -- Purpose : To add lexical parameters for Coupon Report
  -- ---------------------------------------------------------
  --------------------------------------------------------------------------
  -- Version  Date      Performer             Comments
  ----------  --------  --------------       -------------------------------------
  --
  --   1.1    10.7.2017     Piyali Bhowmick     CHG0040504- Initial Build
  --   1.2    7.8.2017      Piyali Bhowmick     CHG0041104 - To add lexical parameters for
  --                                                         coupon voucher report
  ------------------------------------------------------------------------------------



  --------------------------------------------------------------------
  --  name:            before_report_trigger
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   10/07/201710/7/2017 15:45:29
  --------------------------------------------------------------------
  --  purpose :  To add lexical parameters for the Coupon Report
  --------------------------------------------------------------------
  --   1.0    10.7.2017    Piyali Bhowmick      CHG0040504- add  before_report_trigger
  -------------------------------------------------------------------------------------------
  FUNCTION before_report_trigger(p_operating_unit varchar2,
                                 p_customer_name  varchar2,
                                 p_coupon_no      varchar2,
                                 p_order_types     varchar2) RETURN BOOLEAN IS

  begin
  if p_operating_unit is NULL
   then
   pwhereclause_org:=' ';
   else
   pwhereclause_org:=' and OOHA.org_id =:p_operating_unit';
  end if;

  if p_customer_name is NULL
   then
   pwhereclause_cust:=' ';
   else
   pwhereclause_cust:=' and hc_sold.cust_account_id =:p_customer_name';
  end if;

  if p_coupon_no is NULL
   then
   pwhereclause_cou := ' ';
   else
   pwhereclause_cou := ' and QC.coupon_id = :p_coupon_no';
   end if;

   if p_order_types is NULL
    then
    pwhereclause_trx:=' ';
    else
    pwhereclause_trx:=' and otta.transaction_type_id =:p_order_types';
   end if;

    RETURN(TRUE);

  end before_report_trigger;

  --------------------------------------------------------------------
  --  name:          xxom_coupon_pkg_beforereport
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   7/8/2017 14:45:36
  --------------------------------------------------------------------
  --  purpose :  To add lexical parameters for the Coupon Voucher
  --------------------------------------------------------------------
  --   1.0    7.8.2017    Piyali Bhowmick      CHG0041104- add  before_event_trigger
  --   1.1    5.10.2017   Piyali Bhowmick      INC0103133-trying to produce manual vouchers
  --                                          is not running manually for voucher parameter
  -------------------------------------------------------------------------------------------
  FUNCTION xxom_coupon_pkg_beforereport(P_header_id number,
                                 P_coupon_number  varchar2/*,
                            P_send_mail varchar2,
                                P_event_id number*/) RETURN BOOLEAN IS

  begin
  if P_header_id is not  NULL
   then
    pwhereclause:= Q'[ocv.header_id =:P_header_id]';
  end if;


  if P_coupon_number is not  NULL then


		--decode(	pwhereclause,null,'', pwhereclause:= pwhereclause || ' AND ' , ;   
     /* Start : For   INC0103133 on   5.10.2017 by  Piyali Bhowmick  */      
     If pwhereclause is not null Then
       pwhereclause := pwhereclause || ' AND '|| Q'[ ocv.coupon_number = :P_coupon_number ]';
     Else
       pwhereclause := Q'[ ocv.coupon_number = :P_coupon_number ]';
     End If; 
     /* End  : For   INC0103133 on   5.10.2017 by  Piyali Bhowmick  */   
	  --pwhereclause := (CASE WHEN pwhereclause IS NULL THEN '' ELSE pwhereclause || ' AND ' end) || Q'[ ocv.coupon_number = :P_coupon_number ]';
   end if;

   if pwhereclause is   NULL
   then

     pwhereclause :='where 1=1';
     else

     pwhereclause :='where '||pwhereclause;



    end if;

  /* if P_send_mail is not NULL then

   pwhereclause : =(CASE pwhereclause WHEN NULL THEN ''ELSE pwhereclause || ' AND ' end)||  Q'[  ]'

   */
       
    fnd_file.put_line(fnd_file.log,'Dynamic where clause : '|| pwhereclause );
    RETURN(TRUE);  
    

  end xxom_coupon_pkg_beforereport;
  --------------------------------------------------------------------
  --  name:          xxom_coupon_pkg_afterreport
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   7/8/2017 14:45:36
  --------------------------------------------------------------------
  --  purpose :  To add bursting to the Coupon Voucher
  --------------------------------------------------------------------
  --   1.0    7.8.2017    Piyali Bhowmick      CHG0041104- To add bursting to the Coupon Voucher
  -------------------------------------------------------------------------------------------
  FUNCTION xxom_coupon_pkg_afterreport(P_send_mail_flag varchar2)
   RETURN BOOLEAN
  is
     l_burst_request_id number;
  begin
  if P_send_mail_flag = 'Y'
   then



        l_burst_request_id := fnd_request.submit_request(application => 'XDO',
				           program     => 'XDOBURSTREP',
				           argument1   => 'Y',
				           argument2   =>  fnd_global.conc_request_id);
          COMMIT;
  end if;
  RETURN TRUE;

  end xxom_coupon_pkg_afterreport;

end XXOM_CS_COUPON_XMLP_PKG;
/