create or replace
TRIGGER "APPS"."XXCSI_INSTANCE_BIR_TRG" BEFORE
  INSERT ON "CSI"."CSI_ITEM_INSTANCES"
  FOR EACH row 
  DECLARE 
  l_instance_id   CSI.CSI_ITEM_INSTANCES.INSTANCE_ID%TYPE := 0; 
  l_serial_num    CSI.CSI_ITEM_INSTANCES.SERIAL_NUMBER%TYPE := 0; 
  l_inv_item_id  NUMBER;
  l_default VARCHAR2(30);
  BEGIN
    --------------------------------------------------------------------
  --  name:            XXCSI_INSTANCE_BIR_TRG
  --  create by:       Vishal roy
  --  Revision:        1.0
  --  creation date:   05.08.16
  --------------------------------------------------------------------
  --  purpose :        Trigger to fire custom event for Interim solution 
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05.08.16    vishal roy         initial build for custom trigger used in Interim sol
  --------------------------------------------------------------------
    BEGIN 
      L_INSTANCE_ID :=0;
     -- INSERT INTO TEST_TRIGGER(text) VALUES('STEP 1.0');
      l_instance_id := :NEW.INSTANCE_ID;
      l_serial_num  := :NEW.SERIAL_NUMBER;
      l_inv_item_id := :NEW.INVENTORY_ITEM_ID;
      EXCEPTION WHEN no_data_found then
        l_instance_id :=0;
        l_serial_num  :=0;
        l_inv_item_id :=0;
      WHEN OTHERS THEN
        l_instance_id :=0;
        l_serial_num  :=0;
        l_inv_item_id :=0;
	  END;
	--
	--
	IF L_INSTANCE_ID <>0 THEN
   -- INSERT INTO TEST_TRIGGER(TEXT) VALUES('STEP 2.0:'||L_INSTANCE_ID);
    -- To add Any filtering conditions
    --
    --RAISE CUSTOM WF EVENTS CALLING XX_ADMIN_UTILITIES_PKG.XX_CUST_EVENT_RAISE
    --
    XX_ADMIN_UTILITIES_PKG.XX_CUST_EVENT_RAISE (
                              P_EVENT_NAME  		  =>'xxib.oracle.apps.instance_creat',
                              P_EVENT_KEY   		  =>'XX'||L_INSTANCE_ID,
                              P_PARAMETER_1 		  =>'INSTANCE_ID',
                              P_PARAMETER_1_VAL 	=>l_instance_id,
                              P_PARAMETER_2     	=>'SERIAL_NUMBER',
                              P_PARAMETER_2_VAL 	=> L_SERIAL_NUM,
                              P_PARAMETER_3     	=> 'INVENTORY_ITEM_ID',
                              P_PARAMETER_3_VAL 	=> l_inv_item_id
              );
     
	END IF; --l_instance_id IS NOT NULL
	--  
  --
  EXCEPTION WHEN OTHERS THEN
  NULL;
  END;
  /