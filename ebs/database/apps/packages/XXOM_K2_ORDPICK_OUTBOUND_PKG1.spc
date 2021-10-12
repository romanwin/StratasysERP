create or replace PACKAGE      XXOM_K2_ORDPICK_OUTBOUND_PKG1 IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXOM_K2_ORDERPICK_OUTBOUND_PKG.spc
Author's Name:   Sandeep Akula
Date Written:    29-JUNE-2014
Purpose:         Used in K2 Order Pick Outbound Program
Program Style:   Stored Package SPECIFICATION
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
29-JUNE-2014        1.0                  Sandeep Akula    Initial Version (CHG0032547)
28-APR-2015         1.1                  Sandeep Akula    Added Procedure UPDATE_K2_ORDER_STATUS -- CHG0033570
13-JUL-2015         1.2                  Sandeep AKula    Added new parameters to procedure INSERT_ORDER_PICK_DATA (CHG0035864)
---------------------------------------------------------------------------------------------------*/
P_CURR_REQUEST_ID       NUMBER := FND_GLOBAL.CONC_REQUEST_ID;

/*
TYPE k2_inbound_945_rec IS RECORD(k2_order               VARCHAR2(100),
                                    stratasys_orderdelv    VARCHAR2(100),
                                    ship_to                VARCHAR2(250),
                                    created                VARCHAR2(50),
                                    expected               VARCHAR2(50),
                                    actual                 VARCHAR2(50),
                                    item                   VARCHAR2(100),
                                    lot                    VARCHAR2(100),
                                    qty                    VARCHAR2(100),
                                    status_cd              VARCHAR2(100),
                                    status                 VARCHAR2(100),
                                    line_id                VARCHAR2(100),
                                    trackingid             VARCHAR2(100)
                                    );

TYPE k2_inbound_945_tbl IS TABLE OF k2_inbound_945_rec
INDEX BY PLS_INTEGER;    */

PROCEDURE INSERT_ORDER_PICK_DATA(P_SOURCE IN VARCHAR2,
P_ORDER_NUMBER IN NUMBER,
P_ORDER_HEADER_ID IN NUMBER, -- Added New Parameter 07/13/2015 SAkula CHG0035864
P_ORDER_LINE_ID IN NUMBER,   -- Added New Parameter 07/13/2015 SAkula CHG0035864
P_ORG_ID IN NUMBER,
P_INV_ORG_ID IN NUMBER DEFAULT NULL,
P_CUST_PO_NUMBER IN VARCHAR2 DEFAULT NULL,
P_shipping_instructions IN VARCHAR2 DEFAULT NULL,
P_packing_instructions IN VARCHAR2 DEFAULT NULL,
P_SHIP_TO_party_site_number IN VARCHAR2 DEFAULT NULL,
P_SHIP_TO_party_name IN VARCHAR2 DEFAULT NULL,
P_SHIP_TO_CUSTOMER_ADDRESS1 IN VARCHAR2 DEFAULT NULL,
P_SHIP_TO_CUSTOMER_ADDRESS2 IN VARCHAR2 DEFAULT NULL,
P_SHIP_TO_CITY IN VARCHAR2 DEFAULT NULL,
P_SHIP_TO_STATE IN VARCHAR2 DEFAULT NULL,
P_SHIP_TO_POSTAL_CODE IN VARCHAR2 DEFAULT NULL,
P_SHIP_TO_COUNTRY IN VARCHAR2 DEFAULT NULL,
P_ORDER_LINE_NUMBER IN NUMBER DEFAULT NULL,
P_schedule_ship_date IN VARCHAR2 DEFAULT NULL,
P_freight_carrier_code IN VARCHAR2 DEFAULT NULL,
p_ship_method IN VARCHAR2 DEFAULT NULL,
P_ITEM_NUMBER IN VARCHAR2 DEFAULT NULL,
P_QTY IN NUMBER DEFAULT NULL,
P_UOM IN VARCHAR2 DEFAULT NULL,
P_DELIVERY_ID IN NUMBER  DEFAULT NULL,
P_DELIVERY_NAME IN VARCHAR2 DEFAULT NULL,
P_MO_NUMBER IN VARCHAR2 DEFAULT NULL,
P_MO_LINE_NUMBER IN NUMBER DEFAULT NULL,
P_PICK_SLIP_NUMBER IN NUMBER DEFAULT NULL,
P_SERIAL_NUMBER IN VARCHAR2 DEFAULT NULL,
P_LOT_NUMBER IN VARCHAR2 DEFAULT NULL,
P_LOT_QTY IN NUMBER DEFAULT NULL,
P_SHIP_FROM_WSH IN VARCHAR2 DEFAULT NULL,
P_REQUEST_ID IN NUMBER,
P_DELIVERY_DETAIL_ID IN NUMBER,
P_TRANSACTION_ID IN NUMBER,
P_FROM_SUBINV IN VARCHAR2,
p_customer_contact IN VARCHAR2,
p_cust_contact_email IN VARCHAR2,
p_cust_contact_phone IN VARCHAR2,
P_LOT_EXPIRATION_DATE IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE1 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE2 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE3 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE4 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE5 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE6 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE7 IN VARCHAR2 DEFAULT NULL,
P_ATTRIBUTE8 IN VARCHAR2 DEFAULT NULL);

PROCEDURE UPDATE_TABLE_WITH_ERRORS(p_request_id IN NUMBER,
                                   p_file_name IN VARCHAR2,
                                   p_error_message IN VARCHAR2);

FUNCTION REPROCESS_RECORDS(p_request_id IN NUMBER,
                           p_order_number IN NUMBER,
                           p_delivery_id IN NUMBER)
RETURN VARCHAR2;

PROCEDURE DELETE_DATA(p_request_id IN NUMBER,
                      p_order_number IN NUMBER,
                      p_delivery_id IN NUMBER);

PROCEDURE PURGE_DATA(p_retention_limit IN NUMBER);

PROCEDURE MAIN(errbuf OUT VARCHAR2,
               retcode OUT NUMBER,
               p_request_id IN NUMBER,
               p_data_dir IN VARCHAR2,
               p_reprocess_rec IN VARCHAR2,
               p_delete_flag IN VARCHAR2,
               p_order_number IN NUMBER,
               p_delivery_id IN NUMBER);

PROCEDURE UPDATE_K2_ORDER_STATUS(p_k2_file_data IN xxom_k2_945_tab_type,
                                  p_err_code OUT VARCHAR2,
                                  p_err_message OUT VARCHAR2);

END XXOM_K2_ORDPICK_OUTBOUND_PKG1;
/
