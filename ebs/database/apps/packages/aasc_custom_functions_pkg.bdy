create or replace 
PACKAGE BODY        "AASC_CUSTOM_FUNCTIONS_PKG"
AS
  /*
  Version # :aasc_custom_functions_pkg.pkb
  Initial Creation date : Febrauary 24, 2012
  Intial Created by     :  Karthik
  Purpose               :   Custom function- ship to address(freight forwarder logic)
  DATE            NAME                      CHANGE
  24/02/2012   S A Karthik       Initial version created with Ship_to_address function which retunrs the location id to pull shipto address
                                 in shipconsole based on custom logic given by cutomer.
  14/03/2012   S A Karthik       Added Update_SCAC_Codes Procedure- Updates Ship Console Tables(aasc_shipmethod_mapping.scac_codes) used for
                                 ECHO and ConnectShip with SCAC Codes Mapped in Oracle Freight Carriers DFF(WSH_CARRIER_SERVICES.ATTRIBUTE15)
  18/03/12     S A Karthik       Added Explode_Master_LPN which explodes packages in shipconsole
  21/03/12     S A Karthik       Added get_custom_ship_to_name to pull Ship_to_name based on Custom Logic
  26/12/12     Karthik           Added get_contact_details to pull contact details, option to pull contact details from sales order header attachements
  03/01/13     Ravi Teja/Karthik Added logic in custom ship from to get custom name if custom selected else company name
  21/02/12     Ambica            Added a procedure GET_CUSTOM_FREIGHT_TERM to call custom freight term from oracle
  07/11/13     Karthik           Added custom_pkg_dimension procedure , procedure replaced with from  PREVIOUSLY AASC_LPN_CUSTOM_PKG.LPN_DIMENSION
  10/02/14     mmazanet          CR1320 Changed get_contact_details to get ship to on the order in OM         
  */
PROCEDURE Ship_to_address(
    ip_delivery_id     IN NUMBER,
    ip_organization_id IN NUMBER,
    x_location_id OUT NUMBER,
    X_profile OUT NUMBER,
    op_error_status OUT VARCHAR2)
AS
  L_FREIGHT_FORWARDER VARCHAR2(1);
  L_customer_address  VARCHAR2(30);
  L_address           VARCHAR2(30);
  l_custom            VARCHAR2(30);
BEGIN
  dbms_output.put_line(' start ');
  BEGIN
    SELECT Customer_address
    INTO L_customer_address
    FROM aasc_org_profile_options apop
    WHERE APOP.INV_ORGANIZATION_ID = IP_ORGANIZATION_ID
      --    AND apop.org_id                = ip_org_id
      ;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    dbms_output.put_line('no data found in profile options');
    OP_ERROR_STATUS := OP_ERROR_STATUS || 'No ship to address in profile Options' || CHR (10);
    -- L_customer_address := NULL;
  WHEN OTHERS THEN
    dbms_output.put_line('when others profile options');
    OP_ERROR_STATUS := OP_ERROR_STATUS || 'When others ship to address profile Options' || CHR (10);
  END;
  /*Custom logic to be maintained by Customer */
  BEGIN
    ----IF NO LOGIC IS PRESENT AND CUSTOM SHIP TO PROFILE OPTION IS CUSTOM THEN NVL(DELIVERY TO , SHIP TO ) LOGIC WILL WORK
    dbms_output.put_line('custom logic');
    L_FREIGHT_FORWARDER := NULL;
    /*Custom logic to be maintained by Customer */
    L_address:= NULL;
    --assign value 'SHIP TO/ DELIVER TO if custome profile option is Custom based on the logic
  EXCEPTION
  WHEN OTHERS THEN
    op_error_status := op_error_status || 'Freight Forwader- Ship to/Deliver to'||SQLERRM;
  END;
  BEGIN
    SELECT DECODE(L_CUSTOMER_ADDRESS,'DELIVER TO', WDD.DELIVER_TO_LOCATION_ID,'SHIP TO', WDD.SHIP_TO_LOCATION_ID,'Custom',NVL2 (L_FREIGHT_FORWARDER,WDD.SHIP_TO_LOCATION_ID, NVL( WDD.DELIVER_TO_LOCATION_ID, WDD.SHIP_TO_LOCATION_ID)), NVL( WDD.DELIVER_TO_LOCATION_ID, WDD.SHIP_TO_LOCATION_ID)),
      DECODE(L_customer_address,'DELIVER TO', 1,'SHIP TO',2,'Custom', NVL2(l_freight_forwarder,1,nvl2(wdd.deliver_to_location_id,1,2)), NVL2(wdd.deliver_to_location_id,1,2))
      --NVL2 (l_freight_forwarder,wdd.ship_to_location_id, nvl( wdd.deliver_to_location_id, wdd.ship_to_location_id))
    INTO x_location_id,
      X_profile
    FROM apps.wsh_new_deliveries wnd,
      apps.wsh_delivery_assignments wda,
      apps.wsh_delivery_details wdd
    WHERE wnd.delivery_id      = wda.delivery_id
    AND wda.delivery_detail_id = wdd.delivery_detail_id
    AND wnd.name               = TO_CHAR(ip_delivery_id)
    AND wnd.organization_id    = ip_organization_id
    AND rownum                 =1 ;
  EXCEPTION
  WHEN no_data_found THEN
    l_freight_forwarder := NULL;
  WHEN OTHERS THEN
    op_error_status := op_error_status || 'Freight Forwader- Ship to/Deliver to';
  END;
  dbms_output.put_line('end');
END Ship_to_address;
/*** Updates SCAC Codes Mapped in Oracle Freight Carriers DFF(WSH_CARRIER_SERVICES.ATTRIBUTE15) to Ship Console Tables used for ECHO and ConnectShip**/
PROCEDURE UPDATE_SCAC_CODES(
    ERRBUF OUT VARCHAR2,
    retcode OUT NUMBER)
AS
  CURSOR C_SCAC_Codes_Cur
  IS
    SELECT DISTINCT WCS.SHIP_METHOD_CODE,
      wcs.ship_method_meaning,
      WCS.ATTRIBUTE15 SCAC_CODE
    FROM apps.WSH_CARRIER_SERVICES wcs
    WHERE 1              =1
    AND WCS.ENABLED_FLAG = 'Y'
      --and WCS.CARRIER_ID=12524
    AND wcs.attribute15 IS NOT NULL ;
BEGIN
  APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '                   SCAC Codes Update Program' );
  apps.fnd_file.put_line (apps.fnd_file.output, '                --------------------------------' );
  APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, ' ');
  apps.fnd_file.put_line (apps.fnd_file.output, 'The Following Ship Method''s SCAC are loaded into ShipConsole DataBase:' );
  APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, ' ');
  APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, ' ShipMethod Name                                            SCAC Code         ' );
  apps.fnd_file.put_line (apps.fnd_file.output, '------------------                                         ------------       ' );
  APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, ' ');
  FOR update_sacc_cur IN C_SCAC_Codes_Cur
  LOOP
    BEGIN
      apps.fnd_file.put_line (apps.fnd_file.output, RPAD(update_sacc_cur.ship_method_meaning,47) ||'               '||update_sacc_cur.SCAC_CODE );
      UPDATE aasc_ship_method_mapping
      SET scac_code           = update_sacc_cur.SCAC_CODE
      WHERE shipping_method   = update_sacc_cur.SHIP_METHOD_CODE
      AND ship_method_meaning = update_sacc_cur.ship_method_meaning;
      COMMIT;
    EXCEPTION
    WHEN OTHERS THEN
      errbuf := errbuf || SQLERRM||chr(10);
    END;
  END LOOP;
EXCEPTION
WHEN OTHERS THEN
  errbuf := errbuf || SQLERRM||chr(10);
END Update_SCAC_Codes;
PROCEDURE Explode_Master_LPN(
    ip_delivery_id     IN NUMBER,
    ip_Master_lpn_name IN VARCHAR2,
    ip_organization_id IN NUMBER,
    op_child_packages OUT aasc_child_packages,
    op_status OUT NUMBER,
    op_error_status OUT VARCHAR2 )
AS
  l_master_lpn VARCHAR2(100);
  L_dim        VARCHAR2(30);
  L_count      NUMBER;
BEGIN
  SELECT mater_lpn.parent_lpn,
    msib.unit_length
    ||'X'
    || msib.unit_width
    ||'X'
    || msib.unit_height
  INTO l_master_lpn,
    L_dim
  FROM
    (SELECT NVL(msib.segment1, wdd.container_name) parent_lpn,
      wdd.delivery_detail_id master_detail_id
    FROM wsh_new_deliveries wnd,
      wsh_delivery_assignments wda,
      wsh_delivery_details wdd,
      mtl_system_items_b msib
    WHERE wnd.name         = ip_delivery_id
    AND wdd.container_name = ip_Master_lpn_name
      --and wnd.organization_id            = ip_organization_id
    AND wnd.delivery_id                = wda.delivery_id
    AND wda.delivery_detail_id         = wdd.delivery_detail_id
    AND msib.inventory_item_id(+)      = wdd.inventory_item_id
    AND msib.organization_id(+)        = wdd.organization_id
    AND wda.parent_delivery_detail_id IS NULL
    AND wdd.container_flag             ='Y'
    )mater_lpn,
    wsh_new_deliveries wnd,
    wsh_delivery_assignments wda,
    wsh_delivery_details wdd ,
    mtl_system_items_b msib
  WHERE 1             =1
  AND wnd.name        = ip_delivery_id
  AND wnd.delivery_id = wda.delivery_id
    --and wnd.organization_id    = ip_organization_id
  AND wda.delivery_detail_id     = wdd.delivery_detail_id
  AND msib.inventory_item_id(+)  = wdd.inventory_item_id
  AND msib.organization_id(+)    = wdd.organization_id
  AND mater_lpn.master_detail_id = wda.parent_delivery_detail_id
  AND rownum                     =1 ;
  IF L_dim                       = '0X0X0' THEN
    L_count                     := 1;
  END IF;
  op_status := 100;
  /***********gross weight in shipconsole query but unit weight in explode**********/
  OPEN op_child_packages FOR SELECT wdd.delivery_detail_id deliverydetailid,
  wdd.tracking_number trackingnumber,
  NULL dimensions,
  DECODE(lower(wdd.weight_uom_code),'lbs','LB','lb','LB','kgs','KG','kg','KG',NULL) uom,
  wdd.unit_weight weight,--karthik
  NULL msn,
  NULL codflag,
  NULL codamt,
  NULL LINENO,
  msib.DIMENSION_UOM_CODE dimension_units,
  NULL intl_qty,
  NULL intl_unit_uom,
  NULL intl_unit_weight,
  NULL intl_unit_value,
  NULL intl_product_desc,
  NULL package_declared_value,
  NULL signature_option,
  NULL return_shipment_indicator,
  NULL package_surcharges,
  NULL future_day_shipment,
  DECODE(wdd.container_flag,'Y', NULL,DECODE(L_count, 1,msib.unit_length, DECODE(msib.unit_length, 0,1,msib.unit_length))) package_length,
  DECODE(wdd.container_flag,'Y', NULL,DECODE(L_count, 1,msib.unit_width, DECODE(msib.unit_width,0,1,msib.unit_width))) package_width,
  DECODE(wdd.container_flag,'Y', NULL,DECODE(L_count, 1,msib.unit_height, DECODE(msib.unit_height,0,1,msib.unit_height))) package_height,
  NULL package_ship_cost,
  'N' package_void_flag,
  NULL packaging,
  NULL cod_type,
  NULL cod_funds_code,
  NULL cod_currency,
  NULL dec_val_currency,
  NULL return_ship_method,
  NULL return_dropofftype,
  NULL return_packaging,
  NULL return_pay_code,
  NULL return_acct_number,
  NULL return_material_auth,
  NULL return_tracking_number,
  NULL return_package_cost,
  NULL return_declared_value,
  NULL hold_at_location_flag,
  NULL hold_at_location_phone,
  NULL hold_at_location_line1,
  NULL hold_at_location_city,
  NULL hold_at_location_state,
  NULL hold_at_location_postal_code,
  NULL hazmat_flag,
  NULL hazmat_type,
  NULL hazmat_class,
  NULL hazmat_label_type,
  NULL hazmat_charges,
  NULL dimension_id,
  NULL hold_at_location_line2,
  NULL hazmat_qty,
  NULL hazmat_units,
  NULL hazmat_identification_number,
  NULL hazmat_emergency_contact_no,
  NULL hazmat_emergency_contact_name,
  NULL hazmat_packging_group,
  NULL hazmat_dot_labels,
  NULL hazmat_material_id,
  NULL pkg_discount_net_charges,
  NULL pkg_list_net_charges,
  NULL dry_ice_units,
  NULL dry_ice_weight,
  NULL dry_ice_flag,
  NULL largepackageflag,
  NULL addlhandlingflag,
  NULL hazmatpkgingcnt,
  NULL hazmatpkgingunits,
  NULL hazmattechincalname,
  NULL pallet_count_temp,
  NULL non_pallet_count_temp,
  DECODE(WDD.CONTAINER_FLAG, 'Y',NVL(msib.segment1, wdd.container_name), NULL) package_name,
  mater_lpn.parent_lpn,
  WDD.CONTAINER_FLAG,
  wdd.shipped_quantity FROM
  (SELECT NVL(msib.segment1, wdd.container_name) parent_lpn,
    wdd.delivery_detail_id master_detail_id
  FROM wsh_new_deliveries wnd,
    wsh_delivery_assignments wda,
    wsh_delivery_details wdd,
    mtl_system_items_b msib
  WHERE wnd.name         = ip_delivery_id
  AND wdd.container_name = ip_Master_lpn_name
    --and wnd.organization_id            = ip_organization_id
  AND wnd.delivery_id                = wda.delivery_id
  AND wda.delivery_detail_id         = wdd.delivery_detail_id
  AND msib.inventory_item_id(+)      = wdd.inventory_item_id
  AND msib.organization_id(+)        = wdd.organization_id
  AND wda.parent_delivery_detail_id IS NULL
  AND wdd.container_flag             ='Y'
  )mater_lpn,
  wsh_new_deliveries wnd,
  wsh_delivery_assignments wda,
  wsh_delivery_details wdd ,
  mtl_system_items_b msib WHERE 1=1 AND wnd.name = ip_delivery_id AND wnd.delivery_id = wda.delivery_id
  --and wnd.organization_id    = ip_organization_id
  AND wda.delivery_detail_id = wdd.delivery_detail_id AND msib.inventory_item_id(+) = wdd.inventory_item_id AND msib.organization_id(+) = wdd.organization_id AND mater_lpn.master_detail_id = wda.parent_delivery_detail_id;
EXCEPTION
WHEN no_data_found THEN
  OPEN op_child_packages FOR SELECT NULL deliverydetailid,
  NULL trackingnumber,
  NULL dimensions,
  NULL uom,
  NULL weight,
  NULL msn,
  NULL codflag,
  NULL codamt,
  NULL lineno,
  NULL dimension_units,
  NULL intl_qty,
  NULL intl_unit_uom,
  NULL intl_unit_weight,
  NULL intl_unit_value,
  NULL intl_product_desc,
  NULL package_declared_value,
  NULL signature_option,
  NULL return_shipment_indicator,
  NULL package_surcharges,
  NULL future_day_shipment,
  NULL package_length,
  NULL package_width,
  NULL package_height,
  NULL package_ship_cost,
  'N' package_void_flag,
  NULL packaging,
  NULL cod_type,
  NULL cod_funds_code,
  NULL cod_currency,
  NULL dec_val_currency,
  NULL return_ship_method,
  NULL return_dropofftype,
  NULL return_packaging,
  NULL return_pay_code,
  NULL return_acct_number,
  NULL return_material_auth,
  NULL return_tracking_number,
  NULL return_package_cost,
  NULL return_declared_value,
  NULL hold_at_location_flag,
  NULL hold_at_location_phone,
  NULL hold_at_location_line1,
  NULL hold_at_location_city,
  NULL hold_at_location_state,
  NULL hold_at_location_postal_code,
  NULL hazmat_flag,
  NULL hazmat_type,
  NULL hazmat_class,
  NULL hazmat_label_type,
  NULL hazmat_charges,
  NULL dimension_id,
  NULL hold_at_location_line2,
  NULL hazmat_qty,
  NULL hazmat_units,
  NULL hazmat_identification_number,
  NULL hazmat_emergency_contact_no,
  NULL hazmat_emergency_contact_name,
  NULL hazmat_packging_group,
  NULL hazmat_dot_labels,
  NULL hazmat_material_id,
  NULL pkg_discount_net_charges,
  NULL pkg_list_net_charges,
  NULL dry_ice_units,
  NULL dry_ice_weight,
  NULL dry_ice_flag,
  NULL largepackageflag,
  NULL addlhandlingflag,
  NULL hazmatpkgingcnt,
  NULL hazmatpkgingunits,
  NULL hazmattechincalname,
  NULL pallet_count_temp,
  NULL non_pallet_count_temp,
  NULL package_name,
  NULL parent_lpn,
  NULL CONTAINER_FLAG,
  NULL shipped_quantity FROM dual;
  op_error_status := op_error_status || SQLERRM;
WHEN OTHERS THEN
  op_error_status := op_error_status || SQLERRM;
END Explode_Master_LPN ;
PROCEDURE get_custom_ship_to_name(
    ip_delivery_id     IN NUMBER,
    ip_organization_id IN NUMBER,
    op_custom_ship_to_name OUT VARCHAR2,
    op_error_status OUT VARCHAR2)
AS
BEGIN
  Op_Custom_Ship_To_Name := 'Custom';
  -- op_custom_ship_to_name := null;
EXCEPTION
WHEN OTHERS THEN
  op_error_status := op_error_status || ' When Others Eception- Custom Ship To Name';
END GET_CUSTOM_SHIP_TO_NAME;
PROCEDURE get_custom_reference_vales(
    ip_delivery_id     IN NUMBER,
    ip_organization_id IN NUMBER,
    op_custom_reference_value OUT VARCHAR2,
    op_error_status OUT VARCHAR2 )
AS
BEGIN
  BEGIN
    op_custom_reference_value := 'Custom ';
  EXCEPTION
  WHEN no_data_found THEN
    op_custom_reference_value := TO_CHAR( ip_delivery_id ) ;
  WHEN OTHERS THEN
    op_error_status := op_error_status ||'When Others retreiving company name for custom ship from '||sqlerrm;
  END;
EXCEPTION
WHEN OTHERS THEN
  op_error_status:= 'When others retreiving Custom Reference Value '||sqlerrm;
END get_custom_reference_vales;
PROCEDURE get_custom_ship_from(
    ip_delivery_id     IN NUMBER,
    ip_organization_id IN NUMBER,
    op_custom_ship_from_name OUT VARCHAR2,
    op_error_status OUT VARCHAR2 )
AS
  l_custom_ship_profil VARCHAR2(30);
BEGIN
  BEGIN
    SELECT custom_ship_from
    INTO l_custom_ship_profil
    FROM aasc_org_profile_options
    WHERE inv_organization_id = ip_organization_id;
  EXCEPTION
  WHEN OTHERS THEN
    op_error_status := op_error_status ||'When Others retreiving profile options value for custom ship from '||sqlerrm;
  END;
  IF l_custom_ship_profil = 'CUSTOM' THEN
    BEGIN
      OP_CUSTOM_SHIP_FROM_NAME:= 'Custom';
      /*
      CUSTOM LOGIC TO BE PLACED HERE
      */
    EXCEPTION
    WHEN OTHERS THEN
      op_error_status := op_error_status ||'When Others retreiving company name for custom ship from '||sqlerrm;
    END;
  ELSIF l_custom_ship_profil = 'COMPANY NAME' THEN
    BEGIN
      SELECT company_name
      INTO op_custom_ship_from_name
      FROM aasc_org_profile_options
      WHERE inv_organization_id = ip_organization_id;
    EXCEPTION
    WHEN OTHERS THEN
      op_error_status := op_error_status ||'When Others retreiving company name for custom ship from '||sqlerrm;
    END;
  END IF;
EXCEPTION
WHEN OTHERS THEN
  op_error_status := op_error_status ||'When Others retreiving custom ship from '||sqlerrm;
END get_custom_ship_from;

-- ---------------------------------------------------------------------------------------
-- Procedure to get ship to contact name.  This has been modified by Stratasys to get the 
-- ship to contact on the order tied to the delivery_id.
-- 
-- Change History
-- ........................................................................................
-- 10/02/2014  MMAZANET CRXXXX.  Modified to return shipping contact info from order
-- ........................................................................................
-- ----------------------------------------------------------------------------------------
PROCEDURE get_contact_details(
   ip_delivery_name        IN VARCHAR2
,  OP_CONTACT_NAME         OUT VARCHAR2
,  op_phone_no             OUT VARCHAR2 
,  IP_inv_organization_id  IN NUMBER
)
AS
   L_SHIPTOCONTACT VARCHAR2(20);
BEGIN   
  BEGIN
    SELECT DISTINCT SUBSTRB (TRANSLATE (ha.person_last_name, '"?', ' '), 1, 50 )
      || ' '
      || Substrb (TRANSLATE (Ha.Person_First_Name, '"?', ' '), 1, 40 ),
      REPLACE ( nvl2(hcp.phone_area_code,'('
      ||hcp.phone_area_code
      ||')',hcp.phone_area_code)
      || DECODE (HCP.CONTACT_POINT_TYPE, 'TLX', HCP.TELEX_NUMBER, HCP.PHONE_NUMBER ), ',.~`!@#$%^&*??<>:"?|}{ ', '' )
    INTO op_contact_name,
      op_phone_no
    FROM apps.oe_order_headers_all ooha,
      apps.wsh_new_deliveries wnd ,
      apps.wsh_delivery_assignments wda ,
      apps.wsh_delivery_details wdd ,
      apps.hz_cust_account_roles hcar ,
      apps.hz_parties ha ,
      apps.hz_relationships hr ,
      apps.hz_contact_points hcp
    WHERE 1                       = 1
    AND ROWNUM                    =1
    AND ooha.header_id            = wdd.source_header_id
    AND wdd.delivery_detail_id    = wda.delivery_detail_id
    AND wda.delivery_id           = wnd.delivery_id
    AND wdd.organization_id       = wnd.organization_id
    AND wdd.released_status      IN ('Y', 'S') -- AND wdd.released_status = 'Y'
    AND wnd.NAME                  = ip_delivery_name
    AND ooha.sold_to_contact_id   = hcar.cust_account_role_id
    AND hcar.party_id             = hr.party_id
    AND ha.party_id               = hr.subject_id
    AND hr.party_id               = hcp.owner_table_id(+)
    AND hcp.primary_flag(+)       = 'Y'
    AND hcp.contact_point_type(+) = 'PHONE'
    AND hcp.status(+)             = 'A'
    AND hcar.role_type            = 'CONTACT'
    AND hr.subject_type           = 'PERSON';
  EXCEPTION
  WHEN OTHERS THEN
    --    op_contact_name := NULL;
    OP_PHONE_NO := NULL;
  END;
  
  -- Get shipping profile
  BEGIN
    SELECT SHIPTOCONTACT
    INTO L_SHIPTOCONTACT
    FROM AASC.AASC_ORG_PROFILE_OPTIONS
    WHERE INV_ORGANIZATION_ID = IP_INV_ORGANIZATION_ID;
  EXCEPTION
  WHEN OTHERS THEN
    --    op_contact_name := NULL;
    OP_PHONE_NO := NULL;
  END;
  
  IF upper(L_SHIPTOCONTACT) = 'CUSTOM' THEN
   -- 10/02/2014 MMAZANET CR1320
   -- Replaced logic below to pull from Shipping Contact (see above)
   SELECT DISTINCT 
   -- Formatting pulled from original commented code below
      SUBSTRB (TRANSLATE (ship_party.person_last_name, '"?', ' '), 1, 50 )
      || ' '
      || SUBSTRB (TRANSLATE (ship_party.Person_First_Name, '"?', ' '), 1, 40 )
   ,  REPLACE ( nvl2(hcp.phone_area_code,'('
      ||hcp.phone_area_code
      ||')',hcp.phone_area_code)
      || DECODE (HCP.CONTACT_POINT_TYPE, 'TLX', HCP.TELEX_NUMBER, HCP.PHONE_NUMBER ), ',.~`!@#$%^&*??<>:"?|}{ ', '' )
   INTO 
      op_contact_name
   ,  op_phone_no
   FROM
      oe_order_headers_all       ooh
   ,  hz_cust_account_roles      ship_roles
   ,  hz_relationships           ship_rel
   ,  hz_cust_accounts_all       ship_acct
   ,  hz_parties                 ship_party
   ,  ar_lookups                 ship_arl
   ,  apps.hz_contact_points     hcp
   WHERE ooh.ship_to_contact_id        = ship_roles.cust_account_role_id(+)
   AND   ship_roles.party_id           = ship_rel.party_id(+)
   AND   ship_roles.role_type(+)       = 'CONTACT'
   AND   ship_roles.cust_account_id    = ship_acct.cust_account_id(+)
   AND   NVL(ship_rel.object_id,-1)    = NVL(ship_acct.party_id,-1)
   AND   ship_rel.subject_id           = ship_party.party_id(+)
   AND   ship_arl.lookup_type(+)       = 'CONTACT_TITLE'
   AND   ship_arl.lookup_code(+)       = ship_party.person_pre_name_adjunct
   AND   ship_rel.party_id             = hcp.owner_table_id (+)
   AND   'Y'                           = hcp.primary_flag (+)
   AND   'PHONE'                       = hcp.contact_point_type (+)
   AND   'A'                           = hcp.status (+)
   AND   EXISTS  (SELECT null
                  FROM WSH_DELIVERY_LINE_STATUS_V wdlsv
                  WHERE wdlsv.source_code       = 'OE'
                  AND   wdlsv.source_header_id  = ooh.header_id 
                  AND   wdlsv.delivery_name     = ip_delivery_name);    
    /*
    BEGIN
      SELECT FDST.SHORT_TEXT
      INTO op_contact_name
      FROM WSH_NEW_DELIVERIES WND,
        WSH_DELIVERY_ASSIGNMENTS WDA,
        WSH_DELIVERY_DETAILS WDD,
        FND_ATTACHED_DOCUMENTS FAD,
        --      FND_DOCUMENTS FDT,---to be replace by fnd_documents_tl
        fnd_documents_tl FDT,--uncomment for emerson
        FND_DOCUMENTS_SHORT_TEXT FDST,
        fnd_document_categories_tl fdct
      WHERE 1                    =1
      AND wnd.name               = TO_CHAR(ip_delivery_name)
      AND WND.DELIVERY_ID        = WDa.DELIVERY_ID
      AND WDA.DELIVERY_DETAIL_ID = WDD.DELIVERY_DETAIL_ID
      AND RELEASED_STATUS       IN ('S', 'Y')
      AND FAD.ENTITY_NAME        = 'OE_ORDER_HEADERS'
      AND fad.pk1_value          =wdd.source_header_id --1065876   1065933
      AND fad.document_id        =fdt.document_id
      AND FDT.MEDIA_ID           = FDST.MEDIA_ID
      AND fdt.language           ='US'---include along with fnd_documents_tl table
      AND FDCT.CATEGORY_ID       =FAD.CATEGORY_ID
      AND FDCT.USER_NAME         = 'ECS Ship to Attention'
      AND fdct.language          ='US'
      AND FAD.DOCUMENT_ID        = FDT.DOCUMENT_ID
      AND fdt.media_id           = FDST.MEDIA_ID
      AND ROWNUM                 =1;
    EXCEPTION
    WHEN OTHERS THEN
      OP_CONTACT_NAME := NULL;
    END;
    */
  END IF;
EXCEPTION
   WHEN OTHERS THEN
      op_contact_name := NULL;
      OP_PHONE_NO     := NULL;
END GET_CONTACT_DETAILS;

PROCEDURE GET_CUSTOM_FREIGHT_TERM(
    IP_DELIVERY_ID     IN NUMBER,
    IP_ORGANIZATION_ID IN NUMBER,
    l_custom_freight OUT VARCHAR2,
    op_error_status OUT VARCHAR2 )
AS
BEGIN
  /* Change FFV.ATTRIBUTE6 to the attribute column to which attribute you need to assign*/
  SELECT FFV.attribute6 SHIPCONSOLE_VALUE ------attribute6 is DFF created for value set 'Flexfield segment Values'.This DFF is a column(ATTRIBUTE6) in FND_FLEX_VALUES_VL.
  INTO l_custom_freight
  FROM FND_FLEX_VALUES_VL ffv,
    FND_FLEX_VALUE_SETS FFVS,
    OE_ORDER_HEADERS_ALL OOHA,
    WSH_DELIVERY_DETAILS WDD,
    WSH_DELIVERY_ASSIGNMENTS WDA,
    WSH_NEW_DELIVERIES wnd
  WHERE FFV.FLEX_VALUE_SET_ID  = FFVS.FLEX_VALUE_SET_ID
  AND FFV.FLEX_VALUE           =OOHA.ATTRIBUTE9 -----attribute9 is DFF created in sales order form in 'Additional Header Information'.This DFF is a column(attribute9) in oe_order_headers_all
  AND OOHA.HEADER_ID           =WDD.SOURCE_HEADER_ID
  AND WDD.DELIVERY_DETAIL_ID   =WDA.DELIVERY_DETAIL_ID
  AND WDA.DELIVERY_ID          =WND.DELIVERY_ID
  AND FFVS.FLEX_VALUE_SET_NAME = 'Freight Payment Term'
  AND WND.DELIVERY_ID          =IP_DELIVERY_ID;
  dbms_output.put_line('Freight term value ' ||l_custom_freight);
EXCEPTION
WHEN OTHERS THEN
  OP_ERROR_STATUS := OP_ERROR_STATUS ||'When Others retreiving freight term '||SQLERRM;
  /*  EXCEPTION
  WHEN OTHERS THEN
  OP_ERROR_STATUS := OP_ERROR_STATUS ||'When Others retreiving custom ship from '||SQLERRM; */
END get_custom_freight_term;
PROCEDURE get_third_party_details(
    IP_DELIVERY_ID     IN NUMBER,
    IP_ORGANIZATION_ID IN NUMBER,
    op_third_party_details OUT aasc_third_party_details,
    op_status OUT NUMBER,
    op_error_status OUT VARCHAR2 )
AS
begin
  open OP_THIRD_PARTY_DETAILS for select OOHA.ATTRIBUTE6 COMPANY_NAME, ----columns from oe_order_headers_all which have third_party address
  OOHA.ATTRIBUTE7 ADDRESS,
  OOHA.ATTRIBUTE8 CITY,
  OOHA.ATTRIBUTE9 STATE,
  OOHA.ATTRIBUTE10 POSTAL_CODE,
  ooha.ATTRIBUTE11 Country_symbol FROM OE_ORDER_HEADERS_ALL OOHA,
  WSH_DELIVERY_DETAILS WDD,
  WSH_DELIVERY_ASSIGNMENTS WDA,
  WSH_NEW_DELIVERIES WND WHERE 1=1 AND OOHA.HEADER_ID=WDD.SOURCE_HEADER_ID AND WDD.DELIVERY_DETAIL_ID=WDA.DELIVERY_DETAIL_ID AND WDA.DELIVERY_ID=WND.DELIVERY_ID AND WND.DELIVERY_ID=IP_DELIVERY_ID AND WND.ORGANIZATION_ID = IP_ORGANIZATION_ID AND rownum =1;
EXCEPTION
WHEN OTHERS THEN
  OP_ERROR_STATUS := OP_ERROR_STATUS ||'When Others retreiving third party details '||SQLERRM;
END get_third_party_details;
---- PREVIOUSLY AASC_LPN_CUSTOM_PKG. LPN_DIMENSION
FUNCTION CUSTOM_PKG_DIMENSION
 (ip_lpn_number in  Varchar2)
  return varchar2
  AS
---- PREVIOUSLY AASC_LPN_CUSTOM_PKG. LPN_DIMENSION
  l_length    number ;
  l_widht     number;
  L_Height    Number;
  l_dimension varchar2(30);
  l_ZERO_DIMENSION VARCHAR2(30);
  BEGIN
--  l_dimension variable format  'LengthXBreadthXHeightXDimension_UOM';
--  L_Dimension := '10X20X30XCM';
BEGIN
select attribute2||'X'||attribute3||'X'||attribute4 ||'X'||attribute5
into L_Dimension
from wsh_delivery_details where container_name=ip_lpn_number;
EXCEPTION WHEN NO_DATA_FOUND THEN
 L_DIMENSION := 'LXBXHXU';
 l_ZERO_DIMENSION := 'LXBXHXU';
end;
 /** ------------
  ----
  CUSOMTER WILL BUILD THE LOGIC TO RETURN THE DIMENSIONS FOR LPNS
  **/
  if l_ZERO_DIMENSION = 'LXBXHXU' then
  return l_ZERO_DIMENSION;
  else
   RETURN L_DIMENSION;

  end if;

   EXCEPTION
   WHEN OTHERS THEN
   L_Dimension := 'LXBXHXU';
   return l_dimension;

END CUSTOM_PKG_DIMENSION;

END aasc_custom_functions_pkg;
/
SHOW ERRORS
