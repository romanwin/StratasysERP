CREATE OR REPLACE PACKAGE BODY xxs3_ptm_safety_stock_pkg AS
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Item Safety Stock Details
  --                   from Legacy system

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  23/09/2016  V.V.Sateesh                Initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Safety Stock Details and insert into
  --           staging table XXS3_PTM_ITEM_SAFETY_STOCK
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
 --  1.0  23/09/2016  V.V.Sateesh                Initial build
  -- --------------------------------------------------------------------------------------------

  report_error EXCEPTION;

  g_delimiter varchar2(5):='~';
  g_sysdate             DATE := SYSDATE;

--------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent output
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  23/09/2016  V.V.Sateesh                Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE log_p(p_msg VARCHAR2) IS
  BEGIN

    fnd_file.put_line(fnd_file.log, p_msg);
    /*dbms_output.put_line(i_msg);*/

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Log File. ' || SQLERRM);
  END log_p;
  --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent output
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  23/09/2016  V.V.Sateesh                Initial build
  -- --------------------------------------------------------------------------------------------


PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN

    fnd_file.put_line(fnd_file.output, p_msg);
   /* dbms_output.put_line(p_msg);*/

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Output File. ' || SQLERRM);
  END out_p;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  23/09/2016  V.V.Sateesh                Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE safety_stock_extract_data(x_errbuf  OUT VARCHAR2,
                    		          x_retcode OUT NUMBER) IS

    l_step                   VARCHAR2(50) ;



	CURSOR c_saftey(p_org_id IN NUMBER) IS
	SELECT
	      (SELECT organization_code
            FROM mtl_parameters mp
            WHERE mp.organization_id = mss.organization_id) organization_code,
         	mss.organization_id,
			msi.segment1,
            mss.safety_stock_quantity,
            MAX(mss.effectivity_date) effectivity_date,
			mss.inventory_item_id
    FROM mtl_safety_stocks mss, mtl_system_items_b msi
    WHERE mss.organization_id=p_org_id
    AND msi.organization_id = mss.organization_id
    AND msi.inventory_item_id = mss.inventory_item_id
    AND mss.effectivity_date < SYSDATE
    AND mss.safety_stock_quantity > 0
    GROUP BY mss.organization_id, msi.segment1, mss.safety_stock_quantity,mss.inventory_item_id
    UNION
    SELECT
	 ( SELECT organization_code
            FROM mtl_parameters mp
            WHERE mp.organization_id = mss.organization_id) organization_code,
	mss.organization_id,
           msi.segment1,
           mss.safety_stock_quantity,
           MAX(mss.effectivity_date) effectivity_date,
           	mss.inventory_item_id
    FROM mtl_safety_stocks mss, mtl_system_items_b msi
    WHERE mss.organization_id=p_org_id --UME,USE,UTP
    AND msi.organization_id = mss.organization_id
    AND msi.inventory_item_id = mss.inventory_item_id
    AND mss.effectivity_date > SYSDATE
-- and   m.safety_stock_quantity > 0
 GROUP BY mss.organization_id, msi.segment1, mss.safety_stock_quantity,mss.inventory_item_id;

CURSOR c_org_value IS
/*SELECT TO_NUMBER(LOOKUP_CODE) ORG_ID
  FROM  FND_LOOKUP_VALUES_VL
  WHERE lookup_type='XXS3_PTM_INV_ORG_SS'
  AND ENABLED_FLAG='Y';*/
   SELECT SUBSTR(meaning,1,INSTR(meaning,'-')-1) ORG_ID
   FROM FND_LOOKUP_VALUES_VL
   WHERE lookup_type='XXS3_COMMON_EXTRACT_LKP'
   AND ENABLED_FLAG='Y'
   AND trunc(SYSDATE) BETWEEN nvl(start_date_active, trunc(SYSDATE)) AND
             nvl(end_date_active, trunc(SYSDATE))
   AND DESCRIPTION='Inventoryorg'
   AND SUBSTR(LOOKUP_CODE,INSTR(LOOKUP_CODE,'-')+1)='SAFETYSTOCK';


  /* Cursor for the transformation of the attributes */

    CURSOR c_transform IS
      SELECT *
        FROM xxobjt.xxs3_ptm_item_safety_stock
       WHERE process_flag IN ('N','Y');

 TYPE fetch_safteys IS TABLE OF c_saftey%ROWTYPE;
 bulk_safteys fetch_safteys;

 l_err_code VARCHAR2(4000);
 l_err_msg VARCHAR2(4000);



  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
	/* Delete the Records in the stage table before insert */

      EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_PTM_ITEM_SAFETY_STOCK';
	  BEGIN
    FOR rec_org IN c_org_value LOOP

	  OPEN c_saftey(rec_org.org_id);
	  LOOP
      FETCH c_saftey BULK COLLECT INTO bulk_safteys LIMIT 10000;
	      FORALL i IN 1..bulk_safteys.COUNT
         INSERT INTO xxobjt.xxs3_ptm_item_safety_stock
		 (xx_inventory_item_id,
		  l_inventory_item_id,
		  segment1,
		  safety_stock_quantity,
		  effectivity_date,
		  legacy_organization_id,
		  legacy_organization_code,
		  creation_date,
		  last_update_date,
		  created_by,
		  last_updated_by,
		  last_update_login,
		  date_extracted_on,
		  process_flag)
		 VALUES
		 (xxobjt.xxs3_ptm_item_safety_stock_seq.NEXTVAL,
		  bulk_safteys(i).inventory_item_id,
		  bulk_safteys(i).segment1,
		  bulk_safteys(i).safety_stock_quantity,
		  bulk_safteys(i).effectivity_date,
		  bulk_safteys(i).organization_id,
		  bulk_safteys(i).organization_code,
		  g_sysdate,
		  g_sysdate,
		  fnd_profile.VALUE('USER_ID'),
          fnd_profile.VALUE('USER_ID'),
          USERENV ('SESSIONID') ,
		  g_sysdate,
		  'N'
		 );

  EXIT WHEN c_saftey%NOTFOUND;
  END LOOP;
  CLOSE c_saftey;
  END LOOP;
  COMMIT;
  EXCEPTION
  WHEN OTHERS THEN
    log_p('Exception in the Bulk Insert'||'-'||SQLERRM);
	NULL;
 END;

 	/* Transformation of the Attributes */
	BEGIN
      FOR k IN c_transform LOOP
            l_step := 'Update inventory org';

		  /* Org code transformation */

        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'inventory_org',				         /* Mapping type */
                                                p_stage_tab             => 'xxobjt.xxs3_ptm_item_safety_stock',  /* Staging Table Name */
                                                p_stage_primary_col     => 'xx_inventory_item_id',             /* Staging Table Primary Column Name */
                                                p_stage_primary_col_val => k.xx_inventory_item_id,            /* Staging Table Primary Column Value */
                                                p_legacy_val            => k.legacy_organization_code,       /* Legacy Value */
                                                p_stage_col             => 's3_organization_code',          /* Staging Table Name */
                                                p_err_code              => l_err_code,                     /* Output error code  */
                                                p_err_msg               => l_err_msg);                    /* Error Message */

     END LOOP;
      COMMIT;
	 EXCEPTION
      WHEN OTHERS THEN
        log_p('Unexpected error during transformation at step : ' ||
                     l_step ||chr(10) || SQLCODE || chr(10) || SQLERRM);
  END;
 END safety_stock_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Transform Report for the Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  -- 1.0 17/08/2016   V.V.SATEESH                     Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE data_transform_report (p_entity IN VARCHAR2)  IS

     /* Variables */
      l_count_success NUMBER;
      l_count_fail NUMBER;

        /* Cursor for the Data Transform report */

      CURSOR c_report_item IS
      SELECT xx_inventory_item_id
			,l_inventory_item_id
			,segment1
			,legacy_organization_code
			,s3_organization_code
      ,transform_status
      ,transform_error
	FROM  xxobjt.xxs3_ptm_item_safety_stock;

BEGIN
  IF p_entity='SAFETYSTOCK' THEN
    /* Query to get the count of the Transform status pass  */

    SELECT count(1)
    INTO l_count_success
    FROM    xxs3_ptm_item_safety_stock    xpmi
    WHERE  xpmi.transform_status = 'PASS';

 /* Query to get the count of the Transfor status fail  */

    SELECT count(1)
    INTO l_count_fail
    FROM    xxs3_ptm_item_safety_stock    xpmi
    WHERE  xpmi.transform_status  ='FAIL';


 /* Print the Transform details in the output */

	out_p(rpad('Report name = Data Transformation Report'|| g_delimiter, 100, ' '));
    out_p(rpad('========================================'|| g_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = '||'ITEM MASTER' || g_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' || to_char(g_sysdate, 'dd-Mon-YYYY HH24:MI')|| g_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Success = '||l_count_success || g_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Failure = '||l_count_fail|| g_delimiter , 100, ' '));
    out_p('');
    out_p(rpad('Track Name', 10, ' ') || g_delimiter ||
                       rpad('Entity Name', 15, ' ') || g_delimiter ||
                      rpad('XX Inventory Item ID  ', 20, ' ') || g_delimiter ||
                      rpad('Inventory Item ID', 20, ' ') || g_delimiter ||
                       rpad('Item Number', 30, ' ') || g_delimiter ||
                       rpad('legacy_organization_code', 50, ' ') || g_delimiter ||
					   rpad('s3_organization_code', 50, ' ')|| g_delimiter ||
					   rpad('Status', 10, ' ') || g_delimiter ||
                       rpad('Error Message', 200, ' ') );

    FOR r_data IN c_report_item LOOP

		out_p(rpad('PTM', 10, ' ') || g_delimiter ||
                       rpad('SAFETY STOCKS', 15, ' ') || g_delimiter ||
                       rpad(r_data.xx_inventory_item_id , 30, ' ') || g_delimiter ||
                       rpad(r_data.l_inventory_item_id, 30, ' ') || g_delimiter ||
                       rpad(r_data.SEGMENT1, 30, ' ') || g_delimiter ||
					   rpad(NVL(r_data.legacy_organization_code,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_organization_code,'NULL'), 50, ' ') || g_delimiter ||
					   rpad(r_data.transform_status, 10, ' ') || g_delimiter ||
					   rpad(NVL(r_data.transform_error,'NULL'), 200, ' ') );

END LOOP;
     out_p( '');
     out_p('Stratasys Confidential'|| g_delimiter);
END IF;
 END data_transform_report;

END xxs3_ptm_safety_stock_pkg	;
/
