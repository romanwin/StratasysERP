CREATE OR REPLACE VIEW XXAR_INVOICE_LEGACY_INT_V AS
SELECT
-- =============================================================================
-- Copyright(c) : 
-- Application  : Custom Application
-- -----------------------------------------------------------------------------
-- Program name                    Creation Date    Original Ver    Created by
-- XXAR_INVOICE_LEGACY_INT_V        17-aug-2016      1.0             vindhya
-- -----------------------------------------------------------------------------
-- Usage: Table creation script
--
-- -----------------------------------------------------------------------------
-- Description: This is a Integration view script. This table will be used to 
--              hold AR Invoice table and business event table information.
-- Parameter    : None
-- Return value : None
-- -----------------------------------------------------------------------------
-- Modification History:
-- Modified Date     Version      Done by       Change Description
-- 
-- =============================================================================
        "CUSTOMER_TRX_ID",
        "INVOICE_NUM",
        "CUSTOMER_TRX_LINE_ID",   
        "OPERATING_UNIT",   
        "SO_OPERATING_UNIT",   
        "EMAIL_ADDRESS",   
        "PO_NUMBER",   
        "RELEASE_NUMBER",   
        "RELEASE_REVISION",   
        "RELEASE_ID",   
        "LINE_LOCATION_ID",   
        "QUANTITY_INVOICED",   
        "ITEM_NUMBER",   
        "DESCRIPTION",   
        "SALES_ORDER_NUM",   
        "SALES_ORDER_LINE_NUM",   
		"INVOICE_DATE",
        "EVENT_ID",   
        "TARGET_NAME",   
        "ENTITY_NAME",   
        "ENTITY_ID",   
        "ACTIVE_FLAG",   
        "STATUS",   
        "EVENT_NAME",   
        "REQUEST_MESSGAE",   
        "ERR_MESSAGE",   
        "ATTRIBUTE1",   
        "ATTRIBUTE2",   
        "ATTRIBUTE3",   
        "ATTRIBUTE4",   
        "ATTRIBUTE5",   
        "ATTRIBUTE6",   
        "ATTRIBUTE7",   
        "ATTRIBUTE8",   
        "ATTRIBUTE9",   
        "ATTRIBUTE10",   
        "LAST_UPDATE_DATE",   
        "LAST_UPDATED_BY",   
        "CREATION_DATE",   
        "CREATED_BY",   
        "LAST_UPDATE_LOGIN",   
        "BPEL_INSTANCE_ID",   
        "API_MESSAGE",   
        "CONCATENATED_KEY_COLS"    
  FROM xxar_invoice_legacy_dtls_v xildv, xxssys_events xe
 where xildv.customer_trx_id = xe.entity_id
   and xe.target_name = 'S3'
   and status = 'NEW'
   
 -- =============================================================================
--           End Of view Creation script for XXAR_INVOICE_LEGACY_INT_V
-- =============================================================================
/
-- =============================================================================
--            Provide Grant on XXAR_INVOICE_LEGACY_INT_V to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON XXAR_INVOICE_LEGACY_INT_V
   TO xxsync
/
-- =============================================================================
--            Provide Grant on xxssys_events to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON xxssys_events
   TO xxsync
/
-- =============================================================================
--                                 End Of script
-- =============================================================================