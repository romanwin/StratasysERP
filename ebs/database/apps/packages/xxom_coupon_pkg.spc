create or replace package xxom_coupon_pkg IS

  ------------------------------------------------------------
  -- Author  : PIYALI.BHOWMICK
  -- Created : 7/8/2017 
  -- Purpose : To add the Coupon events from the Coupon Voucher 
  --           Report into the Staging Table 
  --            xxssys_events 
  -- ---------------------------------------------------------
  --------------------------------------------------------------------------
  -- Version  Date      Performer             Comments
  ----------  --------  --------------       -------------------------------------
  --
  --   1.1    7.8.2017     Piyali Bhowmick     CHG0041104- Initial Build 
  ------------------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041104
  --          To add the Coupon events into the Staging Table xxssys_events 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  7.8.2017  Piyali Bhowmick           Initial Build
  --                                         CHG0041104 - To add the Coupon events into the Staging Table xxssys_events 
  -- --------------------------------------------------------------------------------------------

  PROCEDURE generate_coupon(errbuf      OUT NOCOPY VARCHAR2,
		    retcode     OUT NOCOPY NUMBER,
		    p_days_back NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041104
  --          To submit  Coupon voucher and update the status.
  --                                          
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  7.8.2017  Piyali Bhowmick        CHG0041104- To submit  Coupon voucher 
  --                                       and update the status 
  -- --------------------------------------------------------------------------------------------

  PROCEDURE process_coupon_events;

END xxom_coupon_pkg;
/