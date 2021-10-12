create or replace
PACKAGE BODY XXCSI_LEGACY_EVENT_PKG
-- +===================================================================+
-- |                         Stratesys.Inc                                 |
-- |                                                                   |
-- +===================================================================+
-- |                                                                   |
-- |Package Name     : XXCSI_LEGACY_EVENT_PKG                    |
-- |                                                                   |
-- |Description      : This package is used in the Custom Event subscription
-- |                   to catch the entity id and parameters for custom event
-- |                    and insert into xxssys_events
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |1.0   12-08-2016   Vishal Roy(TCS)       Initial code version      |
-- |                                                                   |
-- |                                                                   |
-- +===================================================================+
AS
FUNCTION ProcessEvent(
    p_subscription_guid IN RAW,
    p_event             IN OUT wf_event_t)
  RETURN VARCHAR2
-- +===================================================================+
-- |                                                                   |
-- |Function Name     : ProcessEvent                    |
-- |                                                                   |
-- |Description      : This package is used in the Custom Event subscription
-- |                   to catch the entity id and parameters for custom event
-- |                    and insert into xxssys_events
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |1.0   12-08-2016   Vishal Roy(TCS)       Initial code version      |
-- |                                                                   |
-- |                                                                   |
-- +===================================================================+
IS 
  L_PARAM_LIST        WF_PARAMETER_LIST_T; 
  L_PARAM_NAME        VARCHAR2 (240); 
  L_PARAM_VALUE       VARCHAR2 (2000); 
  L_EVENT_NAME        VARCHAR2 (2000); 
  L_EVENT_KEY         VARCHAR2 (2000); 
  L_EVENT_DATA        VARCHAR2 (4000); 
  L_INSTANCE_ID       NUMBER;
  L_SERIAL_NUMBER     VARCHAR2(100);
  L_INV_ITEM_ID       NUMBER;
  l_val_count         NUMBER;
  L_XXSSYS_EVENT_REC  XXSSYS_EVENTS%ROWTYPE;
  L_ERRM              VARCHAR2(4000);
BEGIN
  SAVEPOINT PROG_START;
  --INSERT INTO xx_CSI_debug_log_tmp (text ) VALUES ('EVENT NAME: vishal' ); 
	-- Variable Initialization 
	l_param_list    := p_event.getparameterlist; 
	l_event_name    := p_event.geteventname (); 
	l_event_key     := p_event.geteventkey (); 
	l_event_data    := p_event.geteventdata (); 
  l_instance_id   := p_event.getvalueforparameter('INSTANCE_ID');
  l_serial_number := p_event.getvalueforparameter('SERIAL_NUMBER');
  l_inv_item_id   := P_EVENT.GETVALUEFORPARAMETER('INVENTORY_ITEM_ID');
	-- Get 
	--INSERT INTO xx_CSI_debug_log_tmp (text ) VALUES ('EVENT NAME: ' || l_event_name ); 
	/*INSERT INTO xx_be_debug_log_tmp (text ) VALUES ('EVENT DATA: ' || l_event_data );*/
  --
	-- Getting the List of Parameters
	-- This will give us the Value for Instanceid and serial_number and inventory_item_id
	-- The instance id can be used in the below Validation Stage
	--
  BEGIN
    IF l_param_list IS NOT NULL 
    THEN FOR i IN l_param_list.FIRST .. l_param_list.LAST 
      LOOP
        --
        -- Initializing Parameter Values
        --
        l_param_name    := l_param_list (i).getname; 
        L_PARAM_VALUE   := L_PARAM_LIST (I).GETVALUE;
        --
        --
       -- INSERT INTO xx_CSI_debug_log_tmp (text ) 
       -- VALUES (l_param_name || ': ' || l_param_value ); 
       -- COMMIT; --
        --
        IF L_EVENT_NAME LIKE 'xxib.oracle.apps.instance_creat%' THEN
        -- GETTING INSTANCE_ID, SERIAL_NUMBER,INV_ITEM_ID FROM LOOP
            IF l_param_name ='INSTANCE_ID'
               THEN l_instance_id := l_param_value;
            ELSIF l_param_name ='SERIAL_NUMBER' THEN
               l_serial_number := l_param_value; 
            ELSIF l_param_name ='INVENTORY_ITEM_ID' THEN
               L_INV_ITEM_ID := l_param_value;--
            END IF;
        --
        END IF; --L_EVENT_NAME LIKE 
    --
    END LOOP;
    --
    --  Validate if event creation is for only 
    --  interim solution instances
    --
    BEGIN
     --INSERT INTO xx_CSI_debug_log_tmp (text ) 
     --VALUES ('JUST BEFORE COUNT' );
     --
     --INSERT INTO XX_CSI_DEBUG_LOG_TMP (TEXT ) 
     --VALUES ('l_serial_number:'||l_serial_number||':l_instance_id :'||l_instance_id||':L_INV_ITEM_ID:'||L_INV_ITEM_ID );
     --COMMIT;
     --
     /*
      SELECT COUNT(CII.serial_number)
      INTO l_val_count
      FROM csi_item_instances   CII,
           XXCSI_INST_S3_DTLS_V CIL,
           mtl_system_items_b   MSI
      WHERE CIL.mstr_serial_num			     =	CII.serial_number
      AND   MSI.inventory_item_id		     =	CII.inventory_item_id
      AND   MSI.segment1				         = 	CIL.mstr_segment1
      AND   CIL.mstr_serial_num          =  l_serial_number
      AND   CII.INSTANCE_ID              =  l_instance_id
      AND   MSI.inventory_item_id        =  L_INV_ITEM_ID
      AND   CII.LAST_VLD_ORGANIZATION_ID = 	MSI.ORGANIZATION_ID;
      */
      --
      SELECT COUNT(CII.serial_number)
      INTO l_val_count
      FROM csi_item_instances    CII,
           apps.xxcsi_inst_s3_dtls_v@SOURCE_S3  CIL,
           mtl_system_items_b    MSI,
           po_headers_all        POH,
           po_lines_all          POL,
           po_releases_all       PRL,
           po_line_locations_all PLL
      WHERE CIL.mstr_serial_num			     = CII.serial_number
      AND   MSI.inventory_item_id		     = CII.inventory_item_id
      AND   MSI.segment1				         = CIL.mstr_segment1
      AND   CIL.mstr_serial_num          = l_serial_number
      AND   CII.instance_id              = l_instance_id
      AND   MSI.inventory_item_id        = L_INV_ITEM_ID
      AND   CIL.ORIG_SYS_DOCUMENT_REF 	 = PRL.po_release_id
      AND   CII.LAST_VLD_ORGANIZATION_ID = MSI.organization_id
      AND   CII.LAST_PO_PO_LINE_ID       = POL.po_line_id
      AND   POL.po_line_id               = PLL.po_line_id
      AND   PLL.po_RELEASE_ID            = PRL.po_release_id
      AND   POL.PO_HEADER_ID             = POH.PO_HEADER_ID
      AND   POH.SEGMENT1				         = SUBSTR(CIL.CUST_PO_NUMBER,1,INSTR(CIL.CUST_PO_NUMBER,'-',1)-1)
      AND   POH.TYPE_LOOKUP_CODE         = 'BLANKET';
      --
    EXCEPTION WHEN NO_DATA_FOUND THEN
    l_val_count :=0;
    ROLLBACK TO PROG_START;
    WHEN OTHERS THEN 
    L_VAL_COUNT :=0;
    --INSERT INTO xx_CSI_debug_log_tmp (text ) 
    -- VALUES ('INSIDE EXCEPTION' );
    -- COMMIT;
    ROLLBACK TO PROG_START;
    END;
    
     --INSERT INTO xx_csi_debug_log_tmp (text ) 
     --VALUES ('l_val_count: '||L_VAL_COUNT );
     --commit;
    --
    --
    --
  BEGIN
    IF L_VAL_COUNT >0 THEN
    --INSERT INTO xx_CSI_debug_log_tmp (text ) VALUES ('INSIDE IF TO POPULATE XXSSYS_EVENTS' ); 
    --COMMIT;
        L_XXSSYS_EVENT_REC.TARGET_NAME := 'LEGACY';
        L_XXSSYS_EVENT_REC.ENTITY_NAME := 'CSI_INST';
        L_XXSSYS_EVENT_REC.ENTITY_ID   := l_instance_id;
        L_XXSSYS_EVENT_REC.EVENT_NAME  := L_EVENT_NAME;
        L_XXSSYS_EVENT_REC.ATTRIBUTE1  := l_serial_number;
        L_XXSSYS_EVENT_REC.ATTRIBUTE2  := L_INV_ITEM_ID;
        L_XXSSYS_EVENT_REC.ACTIVE_FLAG := 'Y';
        --
        --CALLING EVENT INSERT
        --
        --INSERT INTO xx_CSI_debug_log_tmp (text ) VALUES ('JUST BEFORE INSERTING INTO XXSSYS_EVENTS' ); 
        --
        COMMIT;
        XXSSYS_EVENT_PKG.INSERT_EVENT(P_XXSSYS_EVENT_REC => L_XXSSYS_EVENT_REC
       --  xxssys_event_pkg.insert_event(p_xxssys_event_rec => l_xxssys_event_rec);
        );
      COMMIT;
    END IF;
--
  EXCEPTION WHEN OTHERS THEN
  L_ERRM :=SQLERRM;
--INSERT INTO xx_CSI_debug_log_tmp (text ) VALUES ('INSIDE EXCP :'||L_ERRM ); 
   END;--
    --	
    COMMIT;
    END IF; --l_param_list
  EXCEPTION WHEN OTHERS THEN
    ROLLBACK TO PROG_START;
    RETURN 'ERROR';
  END;
--
--
-- 
 RETURN 'SUCCESS'; 
 EXCEPTION WHEN OTHERS THEN 
  wf_core.CONTEXT (pkg_name => 'XXCSI_LEGACY_EVENT_PKG', proc_name => 'ProcessEvent', arg1 => p_event.geteventname (), arg2 => p_event.geteventkey (), arg3 => p_subscription_guid ); -- --Retrieves error information from the error stack and sets it into the event message. -- 
  wf_event.seterrorinfo (p_event => p_event, p_type => 'ERROR'); -- 
  RETURN 'ERROR';  
END ProcessEvent;
 --
 --
END XXCSI_LEGACY_EVENT_PKG;
/