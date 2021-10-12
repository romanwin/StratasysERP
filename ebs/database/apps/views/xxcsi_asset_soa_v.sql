create or replace view xxcsi_asset_soa_v as
WITH asset AS
 (SELECT ALL -----------------------------------------------------------------------------------------------
	 -- Ver     When         Who           Description
	 -- ------  -----------  -----------  ----------------------------------------------------------
	 -- 1.0     02/03/2018   Roman.W      Init Version
	 --                                   CHG0042619 - Install base interface from Oracle to salesforce
	 -- 1.1     24/07/2018   Lingaraj     CTASK0037633  - Adittional Fields to Strataforce
	 -- 1.2     6.Sep.2018   Lingaraj     CHG0043859 - Install base interface changes from Oracle to salesforce
	 -- 1.2     6.Sep.2018   Lingaraj     CHG0043859-CTASK0038761 - Install base interface changes from Oracle to salesforce
	 --                                   Instead of "OR" use "union all" , To improve performance.
	 -- 1.3     20/02/2019   Lingaraj     CHG0045159 - Install base interface - remove fields from interface that maintain by CS
     --1.4      24.5.21      yuval tal    CHG0049822 - performance 
	 -----------------------------------------------------------------------------------------------
	  xe.event_id,
	 xe.status event_status,
	 xe.attribute1 event_name,
	 xadv.sf_account_id, -- 1
	 xadv.instance_id, -- 2
	 xadv.serial_number, -- 3
	xadv.sf_product_id  sf_product_id, --Modified on 25APR18    -- 4
	 xadv.creation_date, -- 5
	 xadv.embedded_sw_version, -- 6
	 xadv.objet_studio_sw_version, -- 7
	 xadv.ship_date, -- 8
	 decode(xadv.sf_parent_instance_id,
	        'NOVALUE',
	        NULL,
	        xadv.sf_parent_instance_id) sf_parent_instance_id, --Modified on 25APR18                                                  -- 9
	xadv.sf_so_order_id sf_so_order_id, -- 10
	xadv.sf_so_line_id sf_so_line_id, -- 11
	 xadv.ato_flag, -- 12
	 xadv.gmn_flag, -- 13
	 xadv.status, -- 14
	 /*  xadv.sf_end_customer,                                                             -- 15
             xadv.sf_current_location,                                                         -- 16
             xadv.sf_install_location, # Commented for CHG0045159*/ -- 17
	 xadv.sf_bill_to, -- 18
	 xadv.sf_ship_to, -- 19
	 xadv.asset_type, -- 20
	 parent_instance_id,
	 substr(serial_number || '-' || item_description, 1, 80) asset_name,
	xe.attribute2,  --CHG0049822
	-- nvl2(xe.attribute2,
	  --    xxssys_oa2sf_util_pkg.get_sf_product_id(xe.attribute2),
	    --  '') upgrade_product --Added on 6Sep@018 for #CHG0043859
	--,
	 xe.attribute3 upgrade_oracle_number --Added on 6Sep@018 for #CHG0043859
	,
	 to_date(xe.attribute4, 'DD-MON-YYYY') upgrade_date --Added on 6Sep@018 for #CHG0043859
  FROM   xxcsi_asset_dtl_v xadv,
         xxssys_events     xe
  WHERE  xe.entity_id = xadv.instance_id
  AND    xe.target_name = 'STRATAFORCE'
  AND    xe.entity_name = 'ASSET'
  AND    xe.status = 'NEW')
SELECT "EVENT_ID",
       "EVENT_STATUS",
       "EVENT_NAME",
       "SF_ACCOUNT_ID",
       "INSTANCE_ID",
       "SERIAL_NUMBER",
      decode(sf_product_id, 'NOVALUE', NULL, sf_product_id)  "SF_PRODUCT_ID",--CHG0049822
       "CREATION_DATE",
       "EMBEDDED_SW_VERSION",
       "OBJET_STUDIO_SW_VERSION",
       "SHIP_DATE",
       "SF_PARENT_INSTANCE_ID",
       "SF_SO_ORDER_ID",
    decode(sf_so_line_id, 'NOVALUE', NULL, sf_so_line_id)    "SF_SO_LINE_ID",--CHG0049822
       "ATO_FLAG",
       "GMN_FLAG",
       "STATUS",               
       "SF_BILL_TO",
       "SF_SHIP_TO",
       "ASSET_TYPE",
       "PARENT_INSTANCE_ID",
       "ASSET_NAME", 
    nvl2(attribute2,
	      xxssys_oa2sf_util_pkg.get_sf_product_id(attribute2),
	      '')    "UPGRADE_PRODUCT",--CHG0049822
       "UPGRADE_DATE",
       "UPGRADE_ORACLE_NUMBER"
FROM   asset
WHERE  parent_instance_id = -1
UNION ALL
SELECT "EVENT_ID",
       "EVENT_STATUS",
       "EVENT_NAME",
       "SF_ACCOUNT_ID",
       "INSTANCE_ID",
       "SERIAL_NUMBER",
     decode(sf_product_id, 'NOVALUE', NULL, sf_product_id)     "SF_PRODUCT_ID",--CHG0049822
       "CREATION_DATE",
       "EMBEDDED_SW_VERSION",
       "OBJET_STUDIO_SW_VERSION",
       "SHIP_DATE",
       "SF_PARENT_INSTANCE_ID",
       "SF_SO_ORDER_ID",
     decode(sf_so_line_id, 'NOVALUE', NULL, sf_so_line_id)  "SF_SO_LINE_ID",--CHG0049822
       "ATO_FLAG",
       "GMN_FLAG",
       "STATUS",               
       "SF_BILL_TO",
       "SF_SHIP_TO",
       "ASSET_TYPE",
       "PARENT_INSTANCE_ID",
       "ASSET_NAME", 
     nvl2(attribute2,
	      xxssys_oa2sf_util_pkg.get_sf_product_id(attribute2),
	      '')   "UPGRADE_PRODUCT",--CHG0049822
       "UPGRADE_DATE",
       "UPGRADE_ORACLE_NUMBER"
FROM   asset
WHERE  parent_instance_id != -1 AND sf_parent_instance_id is not null /*!= 'NOVALUE'*/;----CHG0049822


