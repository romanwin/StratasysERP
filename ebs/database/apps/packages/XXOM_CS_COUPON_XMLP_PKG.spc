CREATE OR REPLACE PACKAGE XXOM_CS_COUPON_XMLP_PKG AS
  ------------------------------------------------------------
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
  --   1.3    9.8.2017      Piyali Bhowmick     CHG0041104 - To add bursting to
  --                                                        Coupon Voucher Report
  ------------------------------------------------------------------------------------
  
  
  pwhereclause_org  varchar2(3200);
  pwhereclause_cust varchar2(3200);
  pwhereclause_cou  varchar2(3200);
  pwhereclause_trx  varchar2(3200);
  
  p_operating_unit varchar2(400);
  p_customer_name varchar2(400);
  p_coupon_no varchar2(400);
  p_order_types varchar2(400);
  
  --------------------------------------------------------------------
  --  name:               before_report_trigger
  --  created by:          Piyali Bhowmick
  --  Revision:           1.0
  --  creation date:      10/07/2017
  --  Description:        To add lexical parameters for Coupon Report
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10/07/2017   Piyali Bhowmick    CHG0040504- Initial Build 
  --------------------------------------------------------------------
  
  FUNCTION before_report_trigger(p_operating_unit varchar2,
                                 p_customer_name  varchar2,
                                 p_coupon_no      varchar2,
                                 p_order_types     varchar2) RETURN BOOLEAN;
  --------------------------------------------------------------------
                                 
                                 
                                 
   P_header_id number; 
   P_coupon_number varchar2(240); 
   p_send_mail     VARCHAR2(1);
   p_event_id      NUMBER; 
    
   pwhereclause varchar2(3200):='';
   --------------------------------------------------------------------
  --  name:               xxom_coupon_pkg_beforereport
  --  created by:          Piyali Bhowmick
  --  Revision:           1.0
  --  creation date:      07/08/2017
  --  Description:        To add lexical parameters for Coupon Voucher Report
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   7/8/2017   Piyali Bhowmick    CHG0041104 - To add lexical parameters for
  --                                                         coupon voucher report
  --------------------------------------------------------------------
  
                          
                                 
  FUNCTION xxom_coupon_pkg_beforereport(P_header_id number,
                                P_coupon_number varchar2
                              ) RETURN BOOLEAN ;
                                
   --------------------------------------------------------------------
  --  name:               xxom_coupon_pkg_afterreport
  --  created by:          Piyali Bhowmick
  --  Revision:           1.0
  --  creation date:      07/08/2017
  --  Description:        To add bursting  to Coupon Voucher Report
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   7/8/2017   Piyali Bhowmick    CHG0041104 - To add bursting  to
  --                                                         coupon voucher report
  --------------------------------------------------------------------                             
                                
                                
  FUNCTION xxom_coupon_pkg_afterreport(P_send_mail_flag varchar2) RETURN BOOLEAN ;
 
 
 
  
end XXOM_CS_COUPON_XMLP_PKG;
/