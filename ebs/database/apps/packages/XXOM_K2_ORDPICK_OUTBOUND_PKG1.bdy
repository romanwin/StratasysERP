CREATE OR REPLACE PACKAGE BODY xxom_k2_ordpick_outbound_pkg1 IS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXOM_K2_ORDERPICK_OUTBOUND_PKG.bdy
  Author's Name:   Sandeep Akula
  Date Written:    29-JUNE-2014
  Purpose:         Used in K2 Order Pick Outbound Program
  Program Style:   Stored Package Body
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  29-JUNE-2014        1.0                  Sandeep Akula    Initial Version (CHG0032547)
  25-MAR-2015         1.1                  Sandeep Akula    Added delivery_detail_id to the extract file. K2 will send back the same id in EDI945 file. -- CHG0033570
  28-APR-2015         1.2                  Sandeep Akula    Added Procedure UPDATE_K2_ORDER_STATUS -- CHG0033570
  26-JUN-2015         1.3                  Sandeep Akula    Changed Procedure MAIN to remove Pipe from replace statement in cursor C_ORDPICK_DATA for columns SHIPPING_INSTRUCTIONS and PACKING_INSTRUCTIONS (CHG0035793)
  13-JUL-2015         1.4                  Sandeep AKula     Added new columns and parameters to procedure INSERT_ORDER_PICK_DATA (CHG0035864)
                                                             Added Parent Item to the File Data in Procedure MAIN (CHG0035864)
  12-JUL-2016         1.5                  Lingaraj Sarangi  CHG0038653 - XX SSUS: Pick Slip Interface does not split Pick Qty by Item / Lot Number                                                                                                                      
  ---------------------------------------------------------------------------------------------------*/
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    INSERT_ORDER_PICK_DATA
  Author's Name:   Sandeep Akula
  Date Written:    16-JULY-2014
  Purpose:         This Procedure Inserts Pick Slip Report data into Custom Table
  Program Style:   Procedure Definition
  Called From:     Called in After Report Trigger of Report "
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  16-JULY-2014        1.0                  Sandeep Akula     Initial Version -- CHG0032547
  12-DEC-2014         1.1                  Sandeep Akula     Added WHO Columns to the Insert Statement (CHG0033527)
  13-JUL-2015         1.2                  Sandeep AKula     Added new columns order_header_id and order_line_id to the INSERT statement (CHG0035864)
                                                             Added new parameters P_ORDER_HEADER_ID and P_ORDER_LINE_ID to the procedure (CHG0035864)
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE insert_order_pick_data(p_source                    IN VARCHAR2,
		           p_order_number              IN NUMBER,
		           p_order_header_id           IN NUMBER, -- Added New Parameter 07/13/2015 SAkula CHG0035864
		           p_order_line_id             IN NUMBER, -- Added New Parameter 07/13/2015 SAkula CHG0035864
		           p_org_id                    IN NUMBER,
		           p_inv_org_id                IN NUMBER DEFAULT NULL,
		           p_cust_po_number            IN VARCHAR2 DEFAULT NULL,
		           p_shipping_instructions     IN VARCHAR2 DEFAULT NULL,
		           p_packing_instructions      IN VARCHAR2 DEFAULT NULL,
		           p_ship_to_party_site_number IN VARCHAR2 DEFAULT NULL,
		           p_ship_to_party_name        IN VARCHAR2 DEFAULT NULL,
		           p_ship_to_customer_address1 IN VARCHAR2 DEFAULT NULL,
		           p_ship_to_customer_address2 IN VARCHAR2 DEFAULT NULL,
		           p_ship_to_city              IN VARCHAR2 DEFAULT NULL,
		           p_ship_to_state             IN VARCHAR2 DEFAULT NULL,
		           p_ship_to_postal_code       IN VARCHAR2 DEFAULT NULL,
		           p_ship_to_country           IN VARCHAR2 DEFAULT NULL,
		           p_order_line_number         IN NUMBER DEFAULT NULL,
		           p_schedule_ship_date        IN VARCHAR2 DEFAULT NULL,
		           p_freight_carrier_code      IN VARCHAR2 DEFAULT NULL,
		           p_ship_method               IN VARCHAR2 DEFAULT NULL,
		           p_item_number               IN VARCHAR2 DEFAULT NULL,
		           p_qty                       IN NUMBER DEFAULT NULL,
		           p_uom                       IN VARCHAR2 DEFAULT NULL,
		           p_delivery_id               IN NUMBER DEFAULT NULL,
		           p_delivery_name             IN VARCHAR2 DEFAULT NULL,
		           p_mo_number                 IN VARCHAR2 DEFAULT NULL,
		           p_mo_line_number            IN NUMBER DEFAULT NULL,
		           p_pick_slip_number          IN NUMBER DEFAULT NULL,
		           p_serial_number             IN VARCHAR2 DEFAULT NULL,
		           p_lot_number                IN VARCHAR2 DEFAULT NULL,
		           p_lot_qty                   IN NUMBER DEFAULT NULL,
		           p_ship_from_wsh             IN VARCHAR2 DEFAULT NULL,
		           p_request_id                IN NUMBER,
		           p_delivery_detail_id        IN NUMBER,
		           p_transaction_id            IN NUMBER,
		           p_from_subinv               IN VARCHAR2,
		           p_customer_contact          IN VARCHAR2,
		           p_cust_contact_email        IN VARCHAR2,
		           p_cust_contact_phone        IN VARCHAR2,
		           p_lot_expiration_date       IN VARCHAR2 DEFAULT NULL,
		           p_attribute1                IN VARCHAR2 DEFAULT NULL,
		           p_attribute2                IN VARCHAR2 DEFAULT NULL,
		           p_attribute3                IN VARCHAR2 DEFAULT NULL,
		           p_attribute4                IN VARCHAR2 DEFAULT NULL,
		           p_attribute5                IN VARCHAR2 DEFAULT NULL,
		           p_attribute6                IN VARCHAR2 DEFAULT NULL,
		           p_attribute7                IN VARCHAR2 DEFAULT NULL,
		           p_attribute8                IN VARCHAR2 DEFAULT NULL) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    l_data_exists_cnt NUMBER := '';
  BEGIN
  
    -- Checking if data exists for the Order Number
    l_data_exists_cnt := '';
    BEGIN
      SELECT COUNT(*)
      INTO   l_data_exists_cnt
      FROM   xxom_k2_orderpick_staging1
      WHERE  order_number = p_order_number
      AND    org_id = p_org_id
      AND    delivery_id = p_delivery_id
      AND    request_id <> p_request_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_data_exists_cnt := '';
    END;
  
    IF l_data_exists_cnt = '0' OR l_data_exists_cnt IS NULL THEN
    
      BEGIN
        INSERT INTO xxom_k2_orderpick_staging1
          (sequence_number,
           SOURCE,
           order_number,
           order_header_id, -- Added New column 07/13/2015 SAkula CHG0035864
           order_line_id, -- Added New column 07/13/2015 SAkula CHG0035864
           org_id,
           cust_po_number,
           shipping_instructions,
           packing_instructions,
           ship_to_party_site_number,
           ship_to_party_name,
           ship_to_customer_address1,
           ship_to_customer_address2,
           ship_to_city,
           ship_to_state,
           ship_to_postal_code,
           ship_to_country,
           order_line_number,
           schedule_ship_date,
           freight_carrier_code,
           ship_method,
           inventory_organization_id,
           item_number,
           qty,
           uom,
           delivery_id,
           delivery_name,
           mo_number,
           mo_line_number,
           pick_slip_number,
           serial_number,
           lot_number,
           lot_qty,
           ship_from_wsh,
           request_id,
           delivery_detail_id,
           transaction_id,
           from_subinv,
           ship_to_contact_name,
           ship_to_contact_phone,
           ship_to_contact_email,
           lot_expiration_date,
           attribute1,
           attribute2,
           attribute3,
           attribute4,
           attribute5,
           attribute6,
           attribute7,
           attribute8,
           creation_date, -- Added Column 12/02/2014 SAkula (CHG0033527)
           created_by, -- Added Column 12/02/2014 SAkula (CHG0033527)
           last_update_date, -- Added Column 12/02/2014 SAkula (CHG0033527)
           last_updated_by -- Added Column 12/02/2014 SAkula (CHG0033527)
           )
        VALUES
          (xxom_k2_orderpick_seq.nextval,
           p_source,
           p_order_number,
           p_order_header_id, -- Added 07/13/2015 SAkula CHG0035864
           p_order_line_id, -- Added 07/13/2015 SAkula CHG0035864
           p_org_id,
           p_cust_po_number,
           p_shipping_instructions,
           p_packing_instructions,
           p_ship_to_party_site_number,
           p_ship_to_party_name,
           p_ship_to_customer_address1,
           p_ship_to_customer_address2,
           p_ship_to_city,
           p_ship_to_state,
           p_ship_to_postal_code,
           p_ship_to_country,
           p_order_line_number,
           p_schedule_ship_date,
           p_freight_carrier_code,
           p_ship_method,
           p_inv_org_id,
           p_item_number,
           p_qty,
           p_uom,
           p_delivery_id,
           p_delivery_name,
           p_mo_number,
           p_mo_line_number,
           p_pick_slip_number,
           p_serial_number,
           p_lot_number,
           p_lot_qty,
           p_ship_from_wsh,
           p_request_id,
           p_delivery_detail_id,
           p_transaction_id,
           p_from_subinv,
           p_customer_contact,
           p_cust_contact_phone,
           p_cust_contact_email,
           p_lot_expiration_date,
           p_attribute1,
           p_attribute2,
           p_attribute3,
           p_attribute4,
           p_attribute5,
           p_attribute6,
           p_attribute7,
           p_attribute8,
           SYSDATE, -- CREATION_DATE  -- Added Value 12/02/2014 SAkula (CHG0033527)
           fnd_global.user_id, --CREATED_BY -- Added Value 12/02/2014 SAkula (CHG0033527)
           SYSDATE, --LAST_UPDATE_DATE  -- Added Value 12/02/2014 SAkula (CHG0033527)
           fnd_global.user_id -- LAST_UPDATED_BY  -- Added Value 12/02/2014 SAkula (CHG0033527)
           );
      
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      COMMIT;
    
    END IF;
  
  END insert_order_pick_data;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    UPDATE_TABLE_WITH_ERRORS
  Author's Name:   Sandeep Akula
  Date Written:    16-JULY-2014
  Purpose:         This Procedure Updates Record Processed Flags in table XXOM_K2_ORDERPICK_STAGING1 which failed Validations
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  16-JULY-2014        1.0                  Sandeep Akula     Initial Version -- CHG0032547
  12-DEC-2014         1.1                  Sandeep Akula     Added WHO Columns to the Update Statement (CHG0033527)
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE update_table_with_errors(p_request_id    IN NUMBER,
			 p_file_name     IN VARCHAR2,
			 p_error_message IN VARCHAR2) IS
  
  BEGIN
  
    UPDATE xxom_k2_orderpick_staging1
    SET    rec_processed_flag = 'N',
           date_rec_processed = to_char(SYSDATE, 'MM/DD/RRRR HH24:MI:SS'),
           file_name          = p_file_name,
           error_message      = p_error_message,
           last_update_date   = SYSDATE, -- Added Column 12/02/2014 SAkula (CHG0033527)
           last_updated_by    = fnd_global.user_id -- Added Column 12/02/2014 SAkula (CHG0033527)
    WHERE  request_id = p_request_id;
    COMMIT;
  END update_table_with_errors;

  FUNCTION reprocess_records(p_request_id   IN NUMBER,
		     p_order_number IN NUMBER,
		     p_delivery_id  IN NUMBER) RETURN VARCHAR2 IS
  
  BEGIN
  
    IF p_order_number IS NOT NULL AND p_delivery_id IS NOT NULL THEN
    
      UPDATE xxom_k2_orderpick_staging1
      SET    rec_processed_flag = NULL,
	 date_rec_processed = '',
	 file_name          = NULL,
	 error_message      = NULL,
	 last_update_date   = SYSDATE, -- Added Column 12/02/2014 SAkula (CHG0033527)
	 last_updated_by    = fnd_global.user_id -- Added Column 12/02/2014 SAkula (CHG0033527)
      WHERE  request_id = p_request_id
      AND    order_number = p_order_number
      AND    delivery_id = p_delivery_id;
    
    ELSE
    
      UPDATE xxom_k2_orderpick_staging1
      SET    rec_processed_flag = NULL,
	 date_rec_processed = '',
	 file_name          = NULL,
	 error_message      = NULL,
	 last_update_date   = SYSDATE, -- Added Column 12/02/2014 SAkula (CHG0033527)
	 last_updated_by    = fnd_global.user_id -- Added Column 12/02/2014 SAkula (CHG0033527)
      WHERE  request_id = p_request_id;
    
    END IF;
  
    COMMIT;
  
    RETURN('C');
  
  END reprocess_records;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    DELETE_DATA
  Author's Name:   Sandeep Akula
  Date Written:    16-JULY-2014
  Purpose:         This Procedure deletes data from table XXOM_K2_ORDERPICK_STAGING1 for a request Id OR Order-Delivery-RequestID Combination
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  16-JULY-2014        1.0                  Sandeep Akula     Initial Version -- CHG0032547
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE delete_data(p_request_id   IN NUMBER,
		p_order_number IN NUMBER,
		p_delivery_id  IN NUMBER) IS
  
  BEGIN
  
    IF p_order_number IS NOT NULL AND p_delivery_id IS NOT NULL THEN
    
      BEGIN
        DELETE FROM xxom_k2_orderpick_staging1
        WHERE  request_id = p_request_id
        AND    order_number = p_order_number
        AND    delivery_id = p_delivery_id;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
    ELSE
    
      BEGIN
        DELETE FROM xxom_k2_orderpick_staging1
        WHERE  request_id = p_request_id;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
    END IF;
  
    COMMIT;
  
  END delete_data;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    PURGE_DATA
  Author's Name:   Sandeep Akula
  Date Written:    10-FEB-2015
  Purpose:         This Procedure Purges data from XXOM_K2_ORDERPICK_STAGING1 table for all deliveries which are closed
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  10-FEB-2015         1.1                  Sandeep Akula    Initial Version (CHG0033527)
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE purge_data(p_retention_limit IN NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
  BEGIN
  
    DELETE FROM xxom_k2_orderpick_staging1 a
    WHERE  a.rec_processed_flag = 'Y'
    AND    trunc(to_date(a.date_rec_processed, 'MM/DD/RRRR HH24:MI:SS')) <
           trunc(SYSDATE) - p_retention_limit
    AND    EXISTS (SELECT b.delivery_id
	FROM   wsh_new_deliveries b
	WHERE  b.delivery_id = a.delivery_id
	AND    b.status_code = 'CL'); -- Closed Deliveries
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.output,
		'Error Occured in Procedure PURGE_DATA. SQL Error :' ||
		SQLERRM);
  END purge_data;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    MAIN
  Author's Name:   Sandeep Akula
  Date Written:    16-JULY-2014
  Purpose:         This Procedure reads data from table XXOM_K2_ORDERPICK_STAGING1 and create a Order Pick file for K2
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  16-JULY-2014        1.0                  Sandeep Akula     Initial Version -- CHG0032547
  12-DEC-2014         1.1                  Sandeep Akula     Added WHO Columns to the Update Statement (CHG0033527)
  10-FEB-2015         1.2                  Sandeep Akula     Added Procedure PURGE_DATA to Purge closed deliveries data in the staging table (CHG0033527)
  25-MAR-2015         1.3                  Sandeep Akula     Added delivery_detail_id to the file. K2 will send back the same id in EDI945 file. -- CHG0033570
                                                             Delivery Detail ID in EDI945 file will be used to update the K2 staging table with orders status in K2 Davinci
  26-JUN-2015         1.4                  Sandeep Akula     Removed Pipe from replace statement in cursor C_ORDPICK_DATA for columns SHIPPING_INSTRUCTIONS and PACKING_INSTRUCTIONS (CHG0035793)
  13-JUL-2015         1.5                  Sandeep Akula     Added Parent Item to the file data (CHG0035864)
  12-JUL-2016         1.6                  Lingaraj Sarangi  CHG0038653 - XX SSUS: Pick Slip Interface does not split Pick Qty by Item / Lot Number
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE main(errbuf          OUT VARCHAR2,
	     retcode         OUT NUMBER,
	     p_request_id    IN NUMBER,
	     p_data_dir      IN VARCHAR2,
	     p_reprocess_rec IN VARCHAR2,
	     p_delete_flag   IN VARCHAR2,
	     p_order_number  IN NUMBER,
	     p_delivery_id   IN NUMBER) IS
  
    CURSOR c_orders(cp_request_id IN NUMBER) IS
      SELECT order_number,
	 delivery_id
      FROM   xxom_k2_orderpick_staging1
      WHERE  request_id = cp_request_id
      AND    rec_processed_flag IS NULL
      GROUP  BY order_number,
	    delivery_id;
  
    CURSOR c_ordpick_data(cp_request_id   IN NUMBER,
		  cp_order_number IN NUMBER,
		  cp_delivery_id  IN NUMBER) IS
    /*SELECT rowid,
                      SEQUENCE_NUMBER,
                                SOURCE,
                                ORDER_NUMBER,
                                ORG_ID,
                                CUST_PO_NUMBER,
                                SHIPPING_INSTRUCTIONS,
                                PACKING_INSTRUCTIONS,
                                SHIP_TO_PARTY_SITE_NUMBER,
                                SHIP_TO_PARTY_NAME,
                                SHIP_TO_CUSTOMER_ADDRESS1,
                                SHIP_TO_CUSTOMER_ADDRESS2,
                                SHIP_TO_CITY,
                                SHIP_TO_STATE,
                                SHIP_TO_POSTAL_CODE,
                                SHIP_TO_COUNTRY,
                                ORDER_LINE_NUMBER,
                                SCHEDULE_SHIP_DATE,
                                FREIGHT_CARRIER_CODE,
                                ITEM_NUMBER,
                                --QTY,
                      decode(SERIAL_NUMBER,NULL,QTY,'1') QTY,
                                UOM,
                                DELIVERY_ID,
                                DELIVERY_NAME,
                                MO_NUMBER,
                                MO_LINE_NUMBER,
                                PICK_SLIP_NUMBER,
                                --SERIAL_NUMBER,
                      REPLACE(SERIAL_NUMBER,CHR(10),',') SERIAL_NUMBER,
                                LOT_NUMBER,
                                LOT_QTY,
                                SHIP_FROM_WSH,
                                INVENTORY_ORGANIZATION_ID,
                                REQUEST_ID
                    FROM XXOM_K2_ORDERPICK_STAGING1
                    WHERE REQUEST_ID = cp_request_id and
                          ORDER_NUMBER = cp_order_number and
                          REC_PROCESSED_FLAG IS NULL
                    ORDER BY SEQUENCE_NUMBER; */
      SELECT pick.sequence_number,
	 pick.source,
	 pick.order_number,
	 pick.org_id,
	 pick.cust_po_number,
	 --REPLACE(pick.SHIPPING_INSTRUCTIONS,CHR(10),'|')  SHIPPING_INSTRUCTIONS, -- Commented 06/26/2015  SAkula CHG0035793
	 --REPLACE(pick.PACKING_INSTRUCTIONS,CHR(10),'|') PACKING_INSTRUCTIONS, -- Commented 06/26/2015  SAkula  CHG0035793
	 REPLACE(pick.shipping_instructions, chr(10), ' ') shipping_instructions, -- Removed Pipe Symbol 06/26/2015  SAkula CHG0035793
	 REPLACE(pick.packing_instructions, chr(10), ' ') packing_instructions, -- Removed Pipe Symbol 06/26/2015 SAkula CHG0035793
	 pick.ship_to_party_site_number,
	 pick.ship_to_party_name,
	 pick.ship_to_customer_address1,
	 pick.ship_to_customer_address2,
	 pick.ship_to_city,
	 pick.ship_to_state,
	 pick.ship_to_postal_code,
	 pick.ship_to_country,
	 pick.ship_to_contact_name,
	 pick.ship_to_contact_phone,
	 pick.ship_to_contact_email,
	 pick.order_line_number,
	 pick.schedule_ship_date,
	 pick.freight_carrier_code,
	 pick.ship_method,
	 pick.item_number,
	 --QTY,
	 -- decode(pick.serial_number, NULL, pick.qty, '1') qty, /* Commented 1.6 12 Jul 2015 CHG0038653*/
   (  CASE 
            WHEN pick.serial_number IS NOT NULL THEN 1
            WHEN lot.lot_number     IS NOT NULL THEN lot.lot_qty            
            ELSE pick.qty
          END
   )qty,  /* CASE Statement Added 1.6 12 Jul 2015 CHG0038653*/
	 pick.uom,
	 pick.delivery_id,
	 pick.delivery_detail_id, -- Added new column 03/25/2015 SAKULA  CHG0033570
	 pick.delivery_name,
	 pick.mo_number,
	 pick.mo_line_number,
	 pick.pick_slip_number,
	 --SERIAL_NUMBER,
	 REPLACE(pick.serial_number, chr(10), ',') serial_number,
	 lot.lot_number,
	 lot.lot_qty,
	 lot.lot_expiration_date,
	 pick.ship_from_wsh,
	 pick.inventory_organization_id,
	 pick.request_id,
	 xxwsh_delivery_info_pkg.get_parent_item(pick.order_line_id) parent_item -- Added 07/13/2015 SAkula CHG0035864
      FROM   xxom_k2_orderpick_staging1 pick,
	 /* Lot Sub Query */
	 (SELECT request_id,
	         order_number,
	         org_id,
	         delivery_detail_id,
	         transaction_id,
	         attribute1,
	         --lot_number,  -- Added SAkula 07/23/2014 (CHG0032820 - Commented)
	         TRIM(rtrim(rtrim(lot_number, '(OK)'), '(**)')) lot_number, -- Added SAkula 07/23/2014 (CHG0032820 - Removing OK and ** from Lot Number)
	         lot_qty,
	         lot_expiration_date
	  FROM   xxom_k2_orderpick_staging1
	  WHERE  attribute1 = 'LOT_DATA'
	  AND    request_id = cp_request_id) lot
      WHERE  pick.request_id = lot.request_id(+)
      AND    pick.order_number = lot.order_number(+)
      AND    pick.org_id = lot.org_id(+)
      AND    pick.delivery_detail_id = lot.delivery_detail_id(+)
      AND    pick.transaction_id = lot.transaction_id(+)
      AND    pick.attribute1 = 'PICK_SERIAL_DATA'
      AND    pick.request_id = cp_request_id
      AND    pick.order_number = cp_order_number
      AND    pick.delivery_id = cp_delivery_id
      AND    pick.rec_processed_flag IS NULL
      ORDER  BY pick.sequence_number;
  
    CURSOR c_serial_numbers(cp_string IN VARCHAR2) IS
      SELECT DISTINCT serial_number
      FROM   mtl_serial_numbers
      WHERE  serial_number IN
	 (SELECT *
	  FROM   TABLE(xx_in_list(cp_string)));
  
    file_handle          utl_file.file_type;
    l_instance_name      v$database.name%TYPE;
    l_directory          VARCHAR2(2000);
    l_programid          NUMBER := apps.fnd_global.conc_program_id;
    l_request_id         NUMBER := fnd_global.conc_request_id;
    l_prog               fnd_concurrent_programs_vl.user_concurrent_program_name%TYPE;
    l_sysdate            VARCHAR2(100);
    l_file_creation_date VARCHAR2(100);
    l_count              NUMBER := '';
    l_reject_count       NUMBER := '';
    l_prg_exe_counter    NUMBER := '';
    l_data_exists_cnt    NUMBER := '';
    l_file_name          VARCHAR2(200) := '';
    l_error_message      VARCHAR2(32767) := '';
    l_completed          BOOLEAN;
    l_status_code        VARCHAR2(1);
    l_phase              VARCHAR2(200);
    l_vstatus            VARCHAR2(200);
    l_dev_phase          VARCHAR2(200);
    l_dev_status         VARCHAR2(200);
    l_message            VARCHAR2(200);
    parent_error   EXCEPTION;
    parent_warning EXCEPTION;
    l_data_exists_cnt2 NUMBER := '';
    l_mail_list        VARCHAR2(500);
    l_err_code         NUMBER;
    l_err_msg          VARCHAR2(200);
  
    -- Added Variables SAkula 07/23/2014 (CHG0032820)
    -- Error Notification Variables
    l_notf_from_order_num     VARCHAR2(100) := '';
    l_notf_to_order_num       VARCHAR2(100) := '';
    l_notf_from_moveorder_num VARCHAR2(100) := '';
    l_notf_to_moveorder_num   VARCHAR2(100) := '';
    l_notf_requestor          VARCHAR2(200) := '';
    l_notf_data               VARCHAR(32767) := '';
    l_retention_limit         NUMBER := fnd_profile.value('XXOM_K2_DATA_RETENTION_LIMIT'); -- Added Variables SAkula 02/10/2015  (CHG0033527)
  
  BEGIN
  
    l_prg_exe_counter := '0';
  
    purge_data(l_retention_limit); -- Added Procedure to Purge closed deliveries data in the staging table  SAKULA 02/10/2015  (CHG0033527)
  
    l_prg_exe_counter := '0.01';
  
    -- Added logic get error notification data elements SAkula 07/23/2014 (CHG0032820)
    /* Getting data elements for Error Notification*/
    l_error_message := 'Error Occured while getting Notification Details for Request ID :' ||
	           p_request_id;
    BEGIN
      SELECT TRIM(substr(argument_text,
		 instr(argument_text, ',', 1, 5) + 1,
		 instr(argument_text, ',', 1, 6) -
		 instr(argument_text, ',', 1, 5) - 1)) from_move_order,
	 TRIM(substr(argument_text,
		 instr(argument_text, ',', 1, 6) + 1,
		 instr(argument_text, ',', 1, 7) -
		 instr(argument_text, ',', 1, 6) - 1)) to_move_order,
	 TRIM(substr(argument_text,
		 instr(argument_text, ',', 1, 3) + 1,
		 instr(argument_text, ',', 1, 4) -
		 instr(argument_text, ',', 1, 3) - 1)) from_order,
	 TRIM(substr(argument_text,
		 instr(argument_text, ',', 1, 4) + 1,
		 instr(argument_text, ',', 1, 5) -
		 instr(argument_text, ',', 1, 4) - 1)) to_order,
	 requestor
      INTO   l_notf_from_moveorder_num,
	 l_notf_to_moveorder_num,
	 l_notf_from_order_num,
	 l_notf_to_order_num,
	 l_notf_requestor
      FROM   fnd_conc_req_summary_v
      WHERE  request_id = p_request_id;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    l_prg_exe_counter := '0.02';
  
    l_notf_data := 'From Move Order:' || l_notf_from_moveorder_num ||
	       chr(10) || 'To Move Order:' || l_notf_to_moveorder_num ||
	       chr(10) || 'From Order:' || l_notf_from_order_num ||
	       chr(10) || 'To Order:' || l_notf_to_order_num || chr(10) ||
	       'Requestor:' || l_notf_requestor;
  
    l_prg_exe_counter := '0.03';
  
    IF p_delete_flag = 'Y' THEN
      l_prg_exe_counter := '0.04';
      l_error_message   := 'Error Occured in DELETE_DATA Procedure';
      delete_data(p_request_id, p_order_number, p_delivery_id);
    ELSE
    
      -- Deriving the Instance Name
    
      l_error_message := 'Instance Name could not be found';
    
      SELECT NAME
      INTO   l_instance_name
      FROM   v$database;
    
      -- Deriving the Directory Path
    
      l_error_message := 'Directory Path Could not be Found';
    
      SELECT p_data_dir
      INTO   l_directory
      FROM   dual;
    
      l_prg_exe_counter := '0.1';
    
      IF p_reprocess_rec = 'Y' THEN
        l_prg_exe_counter := '0.11';
        l_error_message   := 'Error Occured in REPROCESS_RECORDS Procedure';
        l_status_code     := reprocess_records(p_request_id,
			           p_order_number,
			           p_delivery_id);
      ELSE
        l_prg_exe_counter := '0.12';
        --Wait for the completion of the Parentconcurrent request (if submitted successfully)
      
        l_error_message := 'Error Occured while Waiting for the completion of the Parent concurrent request';
        l_completed     := apps.fnd_concurrent.wait_for_request(request_id => p_request_id,
					    INTERVAL   => 10,
					    max_wait   => 3600, -- 60 Minutes
					    phase      => l_phase,
					    status     => l_vstatus,
					    dev_phase  => l_dev_phase,
					    dev_status => l_dev_status,
					    message    => l_message);
      
        l_prg_exe_counter := '0.13';
        /*---------------------------------------------------------------------------------------
          -- Check for the Concurrent Program status
        ------------------------------------------------------------------------------------*/
        l_error_message := 'Error Occured while deriving the status code of the submitted program';
        SELECT status_code
        INTO   l_status_code
        FROM   fnd_concurrent_requests
        WHERE  request_id = p_request_id;
      
        l_prg_exe_counter := '0.14';
      END IF;
    
      l_prg_exe_counter := '0.3';
    
      IF l_status_code = 'E' -- Error
       THEN
        l_prg_exe_counter := '0.4';
        l_error_message   := 'Parent Request with Request ID :' ||
		     p_request_id || ' completed in Error';
        RAISE parent_error;
      
      ELSIF l_status_code = 'G' -- Warning
       THEN
        l_prg_exe_counter := '0.5';
        l_error_message   := 'Parent Request with Request ID :' ||
		     p_request_id || ' completed in Warning';
        RAISE parent_warning;
      
      ELSIF l_status_code = 'C' -- Sucess
       THEN
      
        l_prg_exe_counter := '1';
      
        -- Checking if data exists for the requests Id
        l_data_exists_cnt := '';
        BEGIN
          SELECT COUNT(*)
          INTO   l_data_exists_cnt
          FROM   xxom_k2_orderpick_staging1
          WHERE  request_id = p_request_id
          AND    rec_processed_flag IS NOT NULL;
        EXCEPTION
          WHEN OTHERS THEN
	l_data_exists_cnt := '';
        END;
      
        l_prg_exe_counter := '2';
      
        IF l_data_exists_cnt > '0' THEN
        
          l_prg_exe_counter := '3';
          fnd_file.put_line(fnd_file.output, chr(10));
          fnd_file.put_line(fnd_file.output, chr(10));
          fnd_file.put_line(fnd_file.output, chr(10));
          fnd_file.put_line(fnd_file.output, chr(10));
          fnd_file.put_line(fnd_file.output, chr(10));
          fnd_file.put_line(fnd_file.output, chr(10));
          fnd_file.put_line(fnd_file.output, chr(10));
          fnd_file.put_line(fnd_file.output,
		    '====================================================================');
          fnd_file.put_line(fnd_file.output,
		    '---------------------------------');
          fnd_file.put_line(fnd_file.output,
		    'Request ID: ' || p_request_id);
          fnd_file.put_line(fnd_file.output,
		    'Instance Name: ' || l_instance_name);
          fnd_file.put_line(fnd_file.output,
		    'Directory Path is : ' || l_directory);
          fnd_file.put_line(fnd_file.output,
		    '---------------------------------');
          fnd_file.put_line(fnd_file.output,
		    '======================  Parameters  ============================');
          fnd_file.put_line(fnd_file.output,
		    'p_data_dir   :' || p_data_dir);
          fnd_file.put_line(fnd_file.output,
		    'p_reprocess_rec   :' || p_reprocess_rec);
          fnd_file.put_line(fnd_file.output,
		    'p_delete_flag   :' || p_delete_flag);
          fnd_file.put_line(fnd_file.output,
		    'P_REQUEST_ID   :' || p_request_id);
          fnd_file.put_line(fnd_file.output,
		    '====================== End Of Parameters  ============================');
          fnd_file.put_line(fnd_file.output,
		    '---------------------------------');
          fnd_file.put_line(fnd_file.output,
		    '====================================================================');
          fnd_file.put_line(fnd_file.output,
		    'File Not Created as data already exists in the table XXOM_K2_ORDERPICK_STAGING1 for request id :' ||
		    p_request_id);
          fnd_file.put_line(fnd_file.output,
		    'Data for Request ID :' || p_request_id ||
		    ' already sent to K2. Cannot Resend the data');
          fnd_file.put_line(fnd_file.output, 'Record Count is : ' || '0');
          fnd_file.put_line(fnd_file.output,
		    '====================================================================');
          fnd_file.put_line(fnd_file.output,
		    '---------------------------------');
          l_prg_exe_counter := '4';
        
        ELSE
        
          -- Checking if data exists for the Order
          l_data_exists_cnt2 := '';
          BEGIN
	SELECT COUNT(*)
	INTO   l_data_exists_cnt2
	FROM   xxom_k2_orderpick_staging1
	WHERE  request_id = p_request_id;
          EXCEPTION
	WHEN OTHERS THEN
	  l_data_exists_cnt2 := '';
          END;
        
          IF l_data_exists_cnt2 = '0' THEN
          
	fnd_file.put_line(fnd_file.output, chr(10));
	fnd_file.put_line(fnd_file.output, chr(10));
	fnd_file.put_line(fnd_file.output, chr(10));
	fnd_file.put_line(fnd_file.output, chr(10));
	fnd_file.put_line(fnd_file.output, chr(10));
	fnd_file.put_line(fnd_file.output, chr(10));
	fnd_file.put_line(fnd_file.output, chr(10));
	fnd_file.put_line(fnd_file.output,
		      '====================================================================');
	fnd_file.put_line(fnd_file.output,
		      '---------------------------------');
	fnd_file.put_line(fnd_file.output,
		      'Request ID: ' || p_request_id);
	fnd_file.put_line(fnd_file.output,
		      'Instance Name: ' || l_instance_name);
	fnd_file.put_line(fnd_file.output,
		      'Directory Path is : ' || l_directory);
	fnd_file.put_line(fnd_file.output,
		      '---------------------------------');
	fnd_file.put_line(fnd_file.output,
		      '======================  Parameters  ============================');
	fnd_file.put_line(fnd_file.output,
		      'p_data_dir   :' || p_data_dir);
	fnd_file.put_line(fnd_file.output,
		      'p_delete_flag   :' || p_delete_flag);
	fnd_file.put_line(fnd_file.output,
		      'p_reprocess_rec   :' || p_reprocess_rec);
	fnd_file.put_line(fnd_file.output,
		      'P_REQUEST_ID   :' || p_request_id);
	fnd_file.put_line(fnd_file.output,
		      '====================== End Of Parameters  ============================');
	fnd_file.put_line(fnd_file.output,
		      '---------------------------------');
	fnd_file.put_line(fnd_file.output,
		      '====================================================================');
	fnd_file.put_line(fnd_file.output,
		      'File Not Created as Order data does not exists for Request ID :' ||
		      p_request_id);
	fnd_file.put_line(fnd_file.output, 'Record Count is : ' || '0');
	fnd_file.put_line(fnd_file.output,
		      '====================================================================');
	fnd_file.put_line(fnd_file.output,
		      '---------------------------------');
          
          ELSE
          
	l_prg_exe_counter := '5';
	l_error_message   := 'Error Occured While Opening Cursor c_orders';
	FOR c_1 IN c_orders(p_request_id) LOOP
	
	  BEGIN
	  
	    l_file_name       := '';
	    l_error_message   := ' Error Occured while Deriving l_file_name';
	    l_file_name       := 'K2ORDPICK_' || c_1.order_number || '_' ||
			 c_1.delivery_id || '_' ||
			 to_char(SYSDATE, 'MMDDRRRRHH24MISS') ||
			 '.txt';
	    l_prg_exe_counter := '6';
	  
	    -- File Handle for Outbound File
	    l_error_message   := 'Error Occured in UTL_FILE.FOPEN (FILE_HANDLE)';
	    file_handle       := utl_file.fopen(l_directory,
				    l_file_name,
				    'W',
				    32767);
	    l_prg_exe_counter := '6.1';
	    l_error_message   := 'Error Occured in UTL_FILE.PUT_LINE (FILE_HANDLE)';
	    utl_file.put_line(file_handle,
		          'VENDOR_ACCOUNT_ID' || '|' ||
		          'ORDER_NUMBER' || '|' || 'PO_NUMBER' || '|' ||
		          'SHIP_DATE' || '|' || 'SHIP_METHOD' || '|' ||
		          'CARRIER_CODE' || '|' ||
		          'SPECIAL_INSTRUCTIONS_1' || '|' ||
		          'SPECIAL_INSTRUCTIONS_2' || '|' ||
		          'CUSTOMER_ACCOUNT_ID' || '|' ||
		          'CUSTOMER_DESCRIPTION' || '|' ||
		          'CUSTOMER_ADDR1' || '|' ||
		          'CUSTOMER_ADDR2' || '|' ||
		          'CUSTOMER_CITY' || '|' ||
		          'CUSTOMER_STATE' || '|' || 'CUSTOMER_ZIP' || '|' ||
		          'CUSTOMER_CONTACT' || '|' ||
		          'CUSTOMER_EMAIL' || '|' ||
		          'CUSTOMER_PHONE' || '|' || 'ITEM_CODE' || '|' ||
		          'LOT_CODE' || '|' || 'SUBLOT_CODE' || '|' ||
		          'QTY' || '|' ||
		          'SMALL_PARCEL_THIRD_PARTY_ACCOUNT' || '|' ||
		          'SMALL_PARCEL_INSURANCE_VALUE' || '|' ||
		          'SMALL_PARCEL_COD_VALUE' || '|' ||
		          'CUSTOMER_COUNTRY' || '|' ||
		          'CANCEL_DATE' || '|' || 'BILL_TO_NAME' || '|' ||
		          'BILL_TO_DESCRIPTION' || '|' ||
		          'BILL_TO_ADDRESS1' || '|' ||
		          'BILL_TO_ADDRESS2' || '|' ||
		          'BILL_TO_CITY' || '|' || 'BILL_TO_STATE' || '|' ||
		          'BILL_TO_POSTAL_CODE' || '|' ||
		          'BILL_TO_COUNTRY' || '|' ||
		          'UNIT_OF_MEASURE' || '|' ||
		          'DELIVERY_NUMBER' || '|' ||
		          'LOT_EXPIRATION_DATE' || '|' || 'LINE_ID' || '|' || -- Added 03/25/2015 SAKULA  CHG0033570
		          'PARENT_ITEM' || '|'); -- Added 07/13/2015 SAkula CHG0035864
	  
	    l_prg_exe_counter := '7';
	    l_count           := '0';
	    l_error_message   := 'Error Occured While Opening Cursor c_ordpick_data';
	    FOR c_2 IN c_ordpick_data(p_request_id,
			      c_1.order_number,
			      c_1.delivery_id) LOOP
	      l_prg_exe_counter := '7.1';
	      IF c_2.serial_number IS NOT NULL THEN
	        l_prg_exe_counter := '7.2';
	        l_error_message   := 'Error Occured While Opening Cursor c_serial_numbers';
	        FOR c_3 IN c_serial_numbers(c_2.serial_number) LOOP
	        
	          l_prg_exe_counter := '8';
	          l_error_message   := 'Error Occured in UTL_FILE.PUT_LINE (FILE_HANDLE)';
	          utl_file.put_line(file_handle,
			    'STRAT' || '|' || -- vendor_account_id
			    c_2.order_number || '|' || -- order_number
			    c_2.cust_po_number || '|' || -- po_number
			    c_2.schedule_ship_date || '|' || -- ship_date
			    c_2.ship_method || '|' || -- ship_method
			    c_2.freight_carrier_code || '|' || -- carrier_code
			    substr(c_2.shipping_instructions,
			           1,
			           512) || '|' || -- special_instructions1
			    substr(c_2.packing_instructions,
			           1,
			           512) || '|' || -- special_instructions2
			    c_2.ship_to_party_site_number || '|' || -- cUSTOMER Ship To Site Number
			    c_2.ship_to_party_name || '|' || -- customer description
			    c_2.ship_to_customer_address1 || '|' || -- customer address1
			    c_2.ship_to_customer_address2 || '|' || -- customer address2
			    c_2.ship_to_city || '|' || -- Customer City
			    c_2.ship_to_state || '|' || -- Customer State
			    c_2.ship_to_postal_code || '|' || -- Customer Zip Code
			    c_2.ship_to_contact_name || '|' || -- customer_contact
			    c_2.ship_to_contact_email || '|' || -- customer_email
			    c_2.ship_to_contact_phone || '|' || -- customer_phone
			    c_2.item_number || '|' || -- item_code
			    nvl(c_3.serial_number,
			        c_2.lot_number) || '|' || -- lot_code (Lot and Serial Numbers)
			    NULL || '|' || -- sublot_code
			    c_2.qty || '|' || -- qty
			    NULL || '|' || -- SMALL_PARCEL_THIRD_PARTY_ACCOUNT
			    NULL || '|' || -- SMALL_PARCEL_INSURANCE_VALUE
			    NULL || '|' || -- SMALL_PARCEL_COD_VALUE
			    c_2.ship_to_country || '|' || -- customer_country
			    NULL || '|' || -- cancel_date
			    NULL || '|' || --BILL_TO_NAME
			    NULL || '|' || -- BILL_TO_DESCRIPTION
			    NULL || '|' || -- BILL_TO_ADDRESS1
			    NULL || '|' || -- BILL_TO_ADDRESS2
			    NULL || '|' || -- BILL_TO_CITY
			    NULL || '|' || -- BILL_TO_STATE
			    NULL || '|' || -- BILL_TO_POSTAL_CODE
			    NULL || '|' || -- BILL_TO_COUNTRY
			    c_2.uom || '|' || -- unit_of_measure
			    c_2.delivery_id || '|' || -- Delivery Number
			    c_2.lot_expiration_date || '|' || --LOT_EXPIRATION_DATE
			    c_2.delivery_detail_id || '|' || -- LINE_ID   -- Added new field to the file 03/25/2015 SAKULA  CHG0033570
			    c_2.parent_item || '|' -- PARENT_ITEM Added 07/13/2015 SAkula CHG0035864
			    );
	        
	        END LOOP;
	      
	      ELSE
	      
	        l_prg_exe_counter := '8.1';
	        l_error_message   := 'Error Occured in UTL_FILE.PUT_LINE (FILE_HANDLE)';
	        utl_file.put_line(file_handle,
			  'STRAT' || '|' || -- vendor_account_id
			  c_2.order_number || '|' || -- order_number
			  c_2.cust_po_number || '|' || -- po_number
			  c_2.schedule_ship_date || '|' || -- ship_date
			  c_2.ship_method || '|' || -- ship_method
			  c_2.freight_carrier_code || '|' || -- carrier_code
			  substr(c_2.shipping_instructions,
			         1,
			         512) || '|' || -- special_instructions1
			  substr(c_2.packing_instructions,
			         1,
			         512) || '|' || -- special_instructions2
			  c_2.ship_to_party_site_number || '|' || -- cUSTOMER Ship To Site Number
			  c_2.ship_to_party_name || '|' || -- customer description
			  c_2.ship_to_customer_address1 || '|' || -- customer address1
			  c_2.ship_to_customer_address2 || '|' || -- customer address2
			  c_2.ship_to_city || '|' || -- Customer City
			  c_2.ship_to_state || '|' || -- Customer State
			  c_2.ship_to_postal_code || '|' || -- Customer Zip Code
			  c_2.ship_to_contact_name || '|' || -- customer_contact
			  c_2.ship_to_contact_email || '|' || -- customer_email
			  c_2.ship_to_contact_phone || '|' || -- customer_phone
			  c_2.item_number || '|' || -- item_code
			  nvl(c_2.serial_number, c_2.lot_number) || '|' || -- lot_code (Serial Number)
			  NULL || '|' || -- sublot_code
			  c_2.qty || '|' || -- qty
			  NULL || '|' || -- SMALL_PARCEL_THIRD_PARTY_ACCOUNT
			  NULL || '|' || -- SMALL_PARCEL_INSURANCE_VALUE
			  NULL || '|' || -- SMALL_PARCEL_COD_VALUE
			  c_2.ship_to_country || '|' || -- customer_country
			  NULL || '|' || -- cancel_date
			  NULL || '|' || -- BILL_TO_NAME
			  NULL || '|' || -- BILL_TO_DESCRIPTION
			  NULL || '|' || -- BILL_TO_ADDRESS1
			  NULL || '|' || -- BILL_TO_ADDRESS2
			  NULL || '|' || -- BILL_TO_CITY
			  NULL || '|' || -- BILL_TO_STATE
			  NULL || '|' || -- BILL_TO_POSTAL_CODE
			  NULL || '|' || -- BILL_TO_COUNTRY
			  c_2.uom || '|' || -- unit_of_measure
			  c_2.delivery_id || '|' || -- Delivery Number
			  c_2.lot_expiration_date || '|' || --LOT_EXPIRATION_DATE
			  c_2.delivery_detail_id || '|' || -- LINE_ID   -- Added new field to the file 03/25/2015 SAKULA  CHG0033570
			  c_2.parent_item || '|' -- PARENT_ITEM Added 07/13/2015 SAkula CHG0035864
			  );
	      
	      END IF;
	    
	      l_prg_exe_counter := '9';
	    
	      l_count := l_count + 1; -- Count of Records
	    
	      l_error_message := 'PICK_SERIAL_DATA:Error Occured while Updating REC_PROCESSED_FLAG to Y in XXOM_K2_ORDERPICK_STAGING1 for sequence_number :' ||
			 c_2.sequence_number;
	      ---- UPDATING THE FLAG
	      UPDATE xxom_k2_orderpick_staging1
	      SET    rec_processed_flag = 'Y',
		 date_rec_processed = to_char(SYSDATE,
				      'MM/DD/RRRR HH24:MI:SS'),
		 file_name          = l_file_name,
		 last_update_date   = SYSDATE, -- Added Column 12/02/2014 SAkula (CHG0033527)
		 last_updated_by    = fnd_global.user_id -- Added Column 12/02/2014 SAkula (CHG0033527)
	      WHERE  request_id = c_2.request_id
	      AND    sequence_number = c_2.sequence_number;
	    
	      l_prg_exe_counter := '10';
	    
	    END LOOP;
	    l_prg_exe_counter := '11';
	    -- Output File
	  
	    fnd_file.put_line(fnd_file.output, chr(10));
	    fnd_file.put_line(fnd_file.output, chr(10));
	    fnd_file.put_line(fnd_file.output, chr(10));
	    fnd_file.put_line(fnd_file.output, chr(10));
	    fnd_file.put_line(fnd_file.output, chr(10));
	    fnd_file.put_line(fnd_file.output,
		          '------------------------------------------------------------------');
	    fnd_file.put_line(fnd_file.output,
		          '=========================  LOADING SUMMARY  ======================');
	    fnd_file.put_line(fnd_file.output,
		          '-------------------------------------------------------------------');
	    fnd_file.put_line(fnd_file.output, chr(10));
	    fnd_file.put_line(fnd_file.output,
		          '+====================================================================+');
	    fnd_file.put_line(fnd_file.output,
		          '---------------------------------------------');
	    fnd_file.put_line(fnd_file.output,
		          'Request ID: ' || p_request_id);
	    fnd_file.put_line(fnd_file.output,
		          'Instance Name: ' || l_instance_name);
	    fnd_file.put_line(fnd_file.output,
		          'Directory Path is : ' || l_directory);
	    fnd_file.put_line(fnd_file.output,
		          '---------------------------------------------');
	    fnd_file.put_line(fnd_file.output,
		          '+======================  Parameters  ============================+');
	    fnd_file.put_line(fnd_file.output,
		          'p_data_dir   :' || p_data_dir);
	    fnd_file.put_line(fnd_file.output,
		          'p_reprocess_rec   :' || p_reprocess_rec);
	    fnd_file.put_line(fnd_file.output,
		          'p_delete_flag   :' || p_delete_flag);
	    fnd_file.put_line(fnd_file.output,
		          'P_REQUEST_ID   :' || p_request_id);
	    fnd_file.put_line(fnd_file.output,
		          '+====================== End Of Parameters  ============================+');
	    fnd_file.put_line(fnd_file.output,
		          '---------------------------------------------');
	    fnd_file.put_line(fnd_file.output,
		          '+====================================================================+');
	    fnd_file.put_line(fnd_file.output,
		          'The File Name is : ' || l_file_name);
	    fnd_file.put_line(fnd_file.output,
		          'Record Count is : ' || (l_count));
	    fnd_file.put_line(fnd_file.output,
		          '+====================================================================+');
	    fnd_file.put_line(fnd_file.output,
		          '----------------------------------------------');
	    l_prg_exe_counter := '12';
	  
	    l_error_message := 'Error Occured in Closing the FILE_HANDLE (file_handle)';
	    utl_file.fclose(file_handle);
	  
	    l_prg_exe_counter := '13';
	  
	    l_error_message := 'LOT_DATA: Error Occured while Updating REC_PROCESSED_FLAG to Y in XXOM_K2_ORDERPICK_STAGING1 for order_number :' ||
		           c_1.order_number;
	    ---- UPDATING THE FLAG
	    UPDATE xxom_k2_orderpick_staging1
	    SET    rec_processed_flag = 'Y',
	           date_rec_processed = to_char(SYSDATE,
				    'MM/DD/RRRR HH24:MI:SS'),
	           file_name          = l_file_name,
	           last_update_date   = SYSDATE, -- Added Column 12/02/2014 SAkula (CHG0033527)
	           last_updated_by    = fnd_global.user_id -- Added Column 12/02/2014 SAkula (CHG0033527)
	    WHERE  request_id = p_request_id
	    AND    order_number = c_1.order_number
	    AND    delivery_id = c_1.delivery_id
	    AND    rec_processed_flag IS NULL;
	  
	    l_prg_exe_counter := '13.1';
	  
	  EXCEPTION
	    WHEN OTHERS THEN
	      utl_file.fclose(file_handle);
	      l_error_message := l_error_message || ' - ' ||
			 ' Prg Cntr :' || l_prg_exe_counter ||
			 ' - ' || SQLERRM;
	      fnd_file.put_line(fnd_file.log, l_error_message);
	      /* Deleting File in case of Failure */
	      BEGIN
	        utl_file.fremove(l_directory, l_file_name);
	      EXCEPTION
	        WHEN utl_file.delete_failed THEN
	          l_error_message := l_error_message ||
			     ' : OTHERS - Error while deleting the file :' ||
			     l_file_name || ' | ' || SQLERRM ||
			     ' Prg Cntr :' || l_prg_exe_counter;
	          fnd_file.put_line(fnd_file.log, l_error_message);
	        WHEN OTHERS THEN
	          l_error_message := l_error_message ||
			     ' : OTHERS - Error while deleting the file :' ||
			     l_file_name ||
			     ' | OTHERS Exception : ' ||
			     SQLERRM || ' Prg Cntr :' ||
			     l_prg_exe_counter;
	          fnd_file.put_line(fnd_file.log, l_error_message);
	      END;
	      /* Sending Failure Email */
	      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
						     p_program_short_name => 'XXOMK2ORDPICKOUT');
	      xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
				p_cc_mail     => l_mail_list,
				p_subject     => 'K2 Sales Order Pick Outbound failure for Order/Delivery - ' ||
					     c_1.order_number || '/' ||
					     c_1.delivery_id ||
					     ' - ' ||
					     l_request_id,
				p_body_text   => 'Pick Slip Report Request Id :' ||
					     p_request_id ||
					     chr(10) ||
					     'K2 Sales Order Pick Outbound Request Id :' ||
					     l_request_id ||
					     chr(10) ||
					     'Could not create file for Order :' ||
					     c_1.order_number ||
					     ' and Delivery :' ||
					     c_1.delivery_id ||
					     chr(10) ||
					     'File Name in table XXOM_K2_ORDERPICK_STAGING1 is :' ||
					     l_file_name ||
					     chr(10) ||
					     'Error Message :' ||
					     l_error_message ||
					     chr(10) ||
					     '******* Pick Slip Report Parameters *********' ||
					     chr(10) ||
					     l_notf_data,
				p_err_code    => l_err_code,
				p_err_message => l_err_msg);
	      /* Updating Table with Errors */
	      UPDATE xxom_k2_orderpick_staging1
	      SET    rec_processed_flag = 'N',
		 date_rec_processed = to_char(SYSDATE,
				      'MM/DD/RRRR HH24:MI:SS'),
		 file_name          = l_file_name,
		 error_message      = l_error_message,
		 last_update_date   = SYSDATE, -- Added Column 12/02/2014 SAkula (CHG0033527)
		 last_updated_by    = fnd_global.user_id -- Added Column 12/02/2014 SAkula (CHG0033527)
	      WHERE  request_id = p_request_id
	      AND    order_number = c_1.order_number
	      AND    delivery_id = c_1.delivery_id;
	  END;
	
	END LOOP;
          
	l_prg_exe_counter := '14';
          
          END IF;
          l_prg_exe_counter := '14.1';
        END IF;
      
        l_prg_exe_counter := '15';
        l_error_message   := '';
      END IF;
    
      l_prg_exe_counter := '16';
    
    END IF; -- p_delete_flag
  
    COMMIT;
    l_prg_exe_counter := '17';
  
  EXCEPTION
    WHEN no_data_found THEN
      utl_file.fclose(file_handle);
      ROLLBACK;
      l_error_message := l_error_message || ' - ' || ' Prg Cntr :' ||
		 l_prg_exe_counter || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := '2';
      errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory, l_file_name);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
		     ' : NO_DATA_FOUND - Error while deleting the file :' ||
		     l_file_name || ' | ' || SQLERRM ||
		     ' Prg Cntr :' || l_prg_exe_counter;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
		     ' : NO_DATA_FOUND - Error while deleting the file :' ||
		     l_file_name || ' | OTHERS Exception : ' ||
		     SQLERRM || ' Prg Cntr :' || l_prg_exe_counter;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					     p_program_short_name => 'XXOMK2ORDPICKOUT');
      xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
			p_cc_mail     => l_mail_list,
			p_subject     => 'K2 Sales Order Pick Outbound failure - ' ||
				     l_request_id,
			p_body_text   => 'Pick Slip Report Request Id :' ||
				     p_request_id || chr(10) ||
				     'K2 Sales Order Pick Outbound Request Id :' ||
				     l_request_id || chr(10) ||
				     'Error Message :' ||
				     l_error_message ||
				     chr(10) ||
				     '******* Pick Slip Report Parameters *********' ||
				     chr(10) || l_notf_data,
			p_err_code    => l_err_code,
			p_err_message => l_err_msg);
      /* Updating Table with Errors */
      update_table_with_errors(p_request_id, l_file_name, l_error_message);
    WHEN utl_file.invalid_path THEN
      utl_file.fclose(file_handle);
      ROLLBACK;
      l_error_message := l_error_message || ' - ' || ' Prg Cntr :' ||
		 l_prg_exe_counter || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := '2';
      errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory, l_file_name);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
		     ' : UTL_FILE.INVALID_PATH - Error while deleting the file :' ||
		     l_file_name || ' | ' || SQLERRM ||
		     ' Prg Cntr :' || l_prg_exe_counter;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
		     ' : UTL_FILE.INVALID_PATH - Error while deleting the file :' ||
		     l_file_name || ' | OTHERS Exception : ' ||
		     SQLERRM || ' Prg Cntr :' || l_prg_exe_counter;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					     p_program_short_name => 'XXOMK2ORDPICKOUT');
      xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
			p_cc_mail     => l_mail_list,
			p_subject     => 'K2 Sales Order Pick Outbound failure - ' ||
				     l_request_id,
			p_body_text   => 'Pick Slip Report Request Id :' ||
				     p_request_id || chr(10) ||
				     'K2 Sales Order Pick Outbound Request Id :' ||
				     l_request_id || chr(10) ||
				     'Error Message :' ||
				     l_error_message ||
				     chr(10) ||
				     '******* Pick Slip Report Parameters *********' ||
				     chr(10) || l_notf_data,
			p_err_code    => l_err_code,
			p_err_message => l_err_msg);
      /* Updating Table with Errors */
      update_table_with_errors(p_request_id, l_file_name, l_error_message);
    WHEN utl_file.read_error THEN
      utl_file.fclose(file_handle);
      ROLLBACK;
      l_error_message := l_error_message || ' - ' || ' Prg Cntr :' ||
		 l_prg_exe_counter || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := '2';
      errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory, l_file_name);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
		     ' : UTL_FILE.READ_ERROR - Error while deleting the file :' ||
		     l_file_name || ' | ' || SQLERRM ||
		     ' Prg Cntr :' || l_prg_exe_counter;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
		     ' : UTL_FILE.READ_ERROR - Error while deleting the file :' ||
		     l_file_name || ' | OTHERS Exception : ' ||
		     SQLERRM || ' Prg Cntr :' || l_prg_exe_counter;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					     p_program_short_name => 'XXOMK2ORDPICKOUT');
      xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
			p_cc_mail     => l_mail_list,
			p_subject     => 'K2 Sales Order Pick Outbound failure - ' ||
				     l_request_id,
			p_body_text   => 'Pick Slip Report Request Id :' ||
				     p_request_id || chr(10) ||
				     'K2 Sales Order Pick Outbound Request Id :' ||
				     l_request_id || chr(10) ||
				     'Error Message :' ||
				     l_error_message ||
				     chr(10) ||
				     '******* Pick Slip Report Parameters *********' ||
				     chr(10) || l_notf_data,
			p_err_code    => l_err_code,
			p_err_message => l_err_msg);
      /* Updating Table with Errors */
      update_table_with_errors(p_request_id, l_file_name, l_error_message);
    WHEN utl_file.write_error THEN
      utl_file.fclose(file_handle);
      ROLLBACK;
      l_error_message := l_error_message || ' - ' || ' Prg Cntr :' ||
		 l_prg_exe_counter || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := '2';
      errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory, l_file_name);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
		     ' : UTL_FILE.WRITE_ERROR - Error while deleting the file :' ||
		     l_file_name || ' | ' || SQLERRM ||
		     ' Prg Cntr :' || l_prg_exe_counter;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
		     ' : UTL_FILE.WRITE_ERROR - Error while deleting the file :' ||
		     l_file_name || ' | OTHERS Exception : ' ||
		     SQLERRM || ' Prg Cntr :' || l_prg_exe_counter;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					     p_program_short_name => 'XXOMK2ORDPICKOUT');
      xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
			p_cc_mail     => l_mail_list,
			p_subject     => 'K2 Sales Order Pick Outbound failure - ' ||
				     l_request_id,
			p_body_text   => 'Pick Slip Report Request Id :' ||
				     p_request_id || chr(10) ||
				     'K2 Sales Order Pick Outbound Request Id :' ||
				     l_request_id || chr(10) ||
				     'Error Message :' ||
				     l_error_message ||
				     chr(10) ||
				     '******* Pick Slip Report Parameters *********' ||
				     chr(10) || l_notf_data,
			p_err_code    => l_err_code,
			p_err_message => l_err_msg);
      /* Updating Table with Errors */
      update_table_with_errors(p_request_id, l_file_name, l_error_message);
    WHEN parent_error THEN
      ROLLBACK;
      retcode := '2';
      errbuf  := 'Pick Slip Report Request with Request ID :' ||
	     p_request_id || ' completed in error';
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					     p_program_short_name => 'XXOMK2ORDPICKOUT');
      xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
			p_cc_mail     => l_mail_list,
			p_subject     => 'K2 Sales Order Pick Outbound failure - ' ||
				     l_request_id,
			p_body_text   => 'Pick Slip Report Request Id :' ||
				     p_request_id || chr(10) ||
				     'K2 Sales Order Pick Outbound Request Id :' ||
				     l_request_id || chr(10) ||
				     'Error Message :' ||
				     errbuf || chr(10) ||
				     '******* Pick Slip Report Parameters *********' ||
				     chr(10) || l_notf_data,
			p_err_code    => l_err_code,
			p_err_message => l_err_msg);
      /* Updating Table with Errors */
      update_table_with_errors(p_request_id, l_file_name, l_error_message);
    WHEN parent_warning THEN
      ROLLBACK;
      retcode := '2';
      errbuf  := 'Pick Slip Report Request with Request ID :' ||
	     p_request_id || ' completed in Warning';
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					     p_program_short_name => 'XXOMK2ORDPICKOUT');
      xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
			p_cc_mail     => l_mail_list,
			p_subject     => 'K2 Sales Order Pick Outbound failure - ' ||
				     l_request_id,
			p_body_text   => 'Pick Slip Report Request Id :' ||
				     p_request_id || chr(10) ||
				     'K2 Sales Order Pick Outbound Request Id :' ||
				     l_request_id || chr(10) ||
				     'Error Message :' ||
				     errbuf || chr(10) ||
				     '******* Pick Slip Report Parameters *********' ||
				     chr(10) || l_notf_data,
			p_err_code    => l_err_code,
			p_err_message => l_err_msg);
      /* Updating Table with Errors */
      update_table_with_errors(p_request_id, l_file_name, l_error_message);
    WHEN OTHERS THEN
      utl_file.fclose(file_handle);
      ROLLBACK;
      l_error_message := l_error_message || ' - ' || ' Prg Cntr :' ||
		 l_prg_exe_counter || ' - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := '2';
      errbuf  := l_error_message;
      /* Deleting File in case of Failure */
      BEGIN
        utl_file.fremove(l_directory, l_file_name);
      EXCEPTION
        WHEN utl_file.delete_failed THEN
          l_error_message := l_error_message ||
		     ' : OTHERS - Error while deleting the file :' ||
		     l_file_name || ' | ' || SQLERRM ||
		     ' Prg Cntr :' || l_prg_exe_counter;
          fnd_file.put_line(fnd_file.log, l_error_message);
        WHEN OTHERS THEN
          l_error_message := l_error_message ||
		     ' : OTHERS - Error while deleting the file :' ||
		     l_file_name || ' | OTHERS Exception : ' ||
		     SQLERRM || ' Prg Cntr :' || l_prg_exe_counter;
          fnd_file.put_line(fnd_file.log, l_error_message);
      END;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					     p_program_short_name => 'XXOMK2ORDPICKOUT');
      xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
			p_cc_mail     => l_mail_list,
			p_subject     => 'K2 Sales Order Pick Outbound failure - ' ||
				     l_request_id,
			p_body_text   => 'Pick Slip Report Request Id :' ||
				     p_request_id || chr(10) ||
				     'K2 Sales Order Pick Outbound Request Id :' ||
				     l_request_id || chr(10) ||
				     'Main Others Exception' ||
				     chr(10) ||
				     'Error Message :' ||
				     l_error_message ||
				     chr(10) ||
				     '******* Pick Slip Report Parameters *********' ||
				     chr(10) || l_notf_data,
			p_err_code    => l_err_code,
			p_err_message => l_err_msg);
      /* Updating Table with Errors */
      update_table_with_errors(p_request_id, l_file_name, l_error_message);
  END main;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    UPDATE_K2_ORDER_STATUS
  Author's Name:   Sandeep Akula
  Date Written:    28-APR-2015
  Purpose:         This Procedure updates table XXOM_K2_ORDERPICK_STAGING1 with the Order Status in K2 Davinchi
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  28-APR-2015        1.0                  Sandeep Akula     Initial Version -- CHG0033570
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE update_k2_order_status(p_k2_file_data IN xxom_k2_945_tab_type,
		           p_err_code     OUT VARCHAR2,
		           p_err_message  OUT VARCHAR2) IS
  
    l_total_cnt        NUMBER;
    l_err_cnt          NUMBER;
    l_sucess_cnt       NUMBER;
    l_rejected_rec_msg VARCHAR2(32767);
    l_order_number     NUMBER;
    l_delivery_id      NUMBER;
  
  BEGIN
  
    l_total_cnt := p_k2_file_data.count;
  
    l_err_cnt          := 0;
    l_sucess_cnt       := 0;
    l_rejected_rec_msg := '';
    FOR indx IN 1 .. p_k2_file_data.count LOOP
      EXIT WHEN p_k2_file_data.count = 0;
    
      BEGIN
      
        --dbms_output.put_line('k2 order :'||p_k2_file_data(indx).k2_order);
        --dbms_output.put_line('stratasys_orderdelv :'||p_k2_file_data(indx).stratasys_orderdelv);
        --dbms_output.put_line('status :'||p_k2_file_data(indx).status);
      
        -- Updating K2 Staging Table
      
        BEGIN
          l_order_number := to_number(substr(p_k2_file_data(indx)
			         .stratasys_orderdelv,
			         1,
			         instr(p_k2_file_data(indx)
				   .stratasys_orderdelv,
				   '-',
				   1) - 1));
          l_delivery_id  := to_number(substr(p_k2_file_data(indx)
			         .stratasys_orderdelv,
			         instr(p_k2_file_data(indx)
				   .stratasys_orderdelv,
				   '-',
				   1) + 1));
        
        EXCEPTION
          WHEN OTHERS THEN
	continue;
        END;
      
        UPDATE xxom_k2_orderpick_staging1
        SET    k2_order_status      = p_k2_file_data(indx).status,
	   tracking_numbers     = p_k2_file_data(indx).trackingid,
	   k2_order_status_date = to_date(p_k2_file_data(indx)
			          .k2_order_status_date,
			          'YYYY-MM-DD HH24:MI:SS'),
	   k2_file_receive_date = to_date(p_k2_file_data(indx)
			          .k2_file_receive_date,
			          'YYYY-MM-DD HH24:MI:SS'),
	   last_update_date     = SYSDATE,
	   last_updated_by      = fnd_global.user_id
        WHERE  order_number = l_order_number --to_number( SUBSTR(p_k2_file_data(indx).stratasys_orderdelv,1,instr(p_k2_file_data(indx).stratasys_orderdelv,'-',1)-1) ) and
        AND    delivery_id = l_delivery_id -- to_number(SUBSTR(p_k2_file_data(indx).stratasys_orderdelv,instr(p_k2_file_data(indx).stratasys_orderdelv,'-',1)+1)) and
        AND    rec_processed_flag = 'Y'
        AND    delivery_detail_id = p_k2_file_data(indx).line_id;
      
        COMMIT;
        l_sucess_cnt := l_sucess_cnt + 1;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_err_cnt          := l_err_cnt + 1;
          l_rejected_rec_msg := l_rejected_rec_msg || '-' ||
		        'Could not process Order :' || p_k2_file_data(indx)
		       .stratasys_orderdelv || '. SQL Error:' ||
		        SQLERRM;
      END;
    
    END LOOP;
  
    IF l_err_cnt = 0 THEN
      p_err_code    := 'S';
      p_err_message := 'Success - Total Records received :' || l_total_cnt ||
	           ' and ' || 'Total Records Processed :' ||
	           l_sucess_cnt;
    ELSE
      p_err_code    := 'F';
      p_err_message := 'Failure - Total Records received :' || l_total_cnt ||
	           ' and ' || 'Total Records Processed :' ||
	           l_sucess_cnt || ' and ' ||
	           'Total Records Rejected :' || l_err_cnt ||
	           l_rejected_rec_msg;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code    := 'F';
      p_err_message := SQLERRM;
  END update_k2_order_status;
END xxom_k2_ordpick_outbound_pkg1;
/