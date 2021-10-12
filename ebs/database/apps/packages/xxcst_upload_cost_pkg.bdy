CREATE OR REPLACE PACKAGE BODY xxcst_upload_cost_pkg IS
  ---------------------------------------------------------------------------
  -- $Header: http://sv-glo-tools01p.stratasys.dmn/svn/ERP/ebs/database/apps/packages/xxcst_upload_cost_pkg.bdy 4003 2018-06-26 06:40:05Z DAN.MELAMED $
  ---------------------------------------------------------------------------
  -- Package: xxcst_upload_cost_pkg
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: Load Std Costing to the new organizations
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -------------------------------------
  --     1.0  11.6.13     Vitaly         CR 814  initial build
  --     1.1  09.06.2014  Gary Altman    CHG0032185  add fg_rollup procedure to run Cost Rollup for the Finish Good
  --     1.2  24.06.2014  Gary Altman    CHG0032215  add procedure buy_items_auto_update updating Material Standard Costs for Buy Items
  --     1.3  06-Jun-2018 Dan Melamed    CHG0042784  Add Cost type parameter (instead of hard coded 'Pending'
  ------------------------------------------------------------------

  -----------------------------------------------------------------------------
  PROCEDURE message(p_message VARCHAR2) IS
  
  BEGIN
    dbms_output.put_line(p_message);
    fnd_file.put_line(fnd_file.log, '========= ' || p_message);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END message;
  -----------------------------------------------------------------------------
  -- upload_overhead
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  13.8.13    Vitaly         CR 814 initial build
  -----------------------------------------------------------------------------
  PROCEDURE upload_overhead(errbuf                OUT VARCHAR2,
		    retcode               OUT VARCHAR2,
		    p_mfg_organization_id IN VARCHAR2) IS
  
    CURSOR c_cst_intrface IS
      SELECT UNIQUE t.inventory_item_id,
	 t.organization_id,
	 t.cost_type,
	 t.last_update_date,
	 t.last_updated_by,
	 t.creation_date,
	 t.created_by,
	 t.cost_element,
	 t.process_flag,
	 t.group_id,
	 CASE
	   WHEN nvl(mioc.category_id, 1) = 1 THEN
	    (SELECT mio.usage_rate_or_amount
	     FROM   cst_item_overhead_defaults_v mio,
		fnd_lookup_values            y,
		bom_resources_v              v
	     WHERE  1 = 1
	     AND    mio.resource_id = v.resource_id
	     AND    v.cost_element_id = y.lookup_code
	     AND    v.organization_id = mio.organization_id
	     AND    y.language = 'US'
	     AND    y.lookup_type = 'CST_COST_CODE_TYPE'
	     AND    y.meaning = 'Material Overhead'
	     AND    mio.usage_rate_or_amount IS NOT NULL
	     AND    mio.category_id IS NULL --new noam
	           -- AND MIO.resource_id = mioc.resource_id
	     AND    mio.organization_id = t.organization_id
	     AND    rownum = 1)
	   ELSE
	    mioc.usage_rate_or_amount
	 END usage_rate_or_amount, ------------usage_rate_or_amount organization level
	 t.item_cost,
	 t.basis_type,
	 CASE
	   WHEN nvl(mioc.cost_element_id, 1) = 1 THEN
	    (SELECT v.cost_element_id
	     FROM   cst_item_overhead_defaults_v mio,
		fnd_lookup_values            y,
		bom_resources_v              v
	     WHERE  1 = 1
	     AND    mio.resource_id = v.resource_id
	     AND    v.cost_element_id = y.lookup_code
	     AND    v.organization_id = mio.organization_id
	     AND    y.language = 'US'
	     AND    y.lookup_type = 'CST_COST_CODE_TYPE'
	     AND    y.meaning = 'Material Overhead'
	     AND    mio.usage_rate_or_amount IS NOT NULL
	     AND    mio.category_id IS NULL --new noam
	           -- AND MIO.resource_id = mioc.resource_id
	     AND    mio.organization_id = t.organization_id
	     AND    rownum = 1)
	   ELSE
	    mioc.cost_element_id
	 END cost_element_id_moh, ---  Material Overhead organization_level
	 --(mioc.cost_element_id) cost_element_id_moh, --Material Overhead
	 
	 t.resource_id, --Material
	 CASE
	   WHEN nvl(mioc.resource_id, 1) = 1 THEN
	    (SELECT v.resource_id
	     FROM   cst_item_overhead_defaults_v mio,
		fnd_lookup_values            y,
		bom_resources_v              v
	     WHERE  1 = 1
	     AND    mio.resource_id = v.resource_id
	     AND    v.cost_element_id = y.lookup_code
	     AND    v.organization_id = mio.organization_id
	     AND    y.language = 'US'
	     AND    y.lookup_type = 'CST_COST_CODE_TYPE'
	     AND    y.meaning = 'Material Overhead'
	     AND    mio.usage_rate_or_amount IS NOT NULL
	     AND    mio.category_id IS NULL --new noam
	           -- AND MIO.resource_id = mioc.resource_id
	     AND    mio.organization_id = t.organization_id
	     AND    rownum = 1)
	   ELSE
	    mioc.resource_id
	 END resource_id_moh, --Material Overhead organization_level
	 
	 t.level_type,
	 t.item_cost                     basis_factor,
	 t.rollup_source_type,
	 t.net_yield_or_shrinkage_factor
      FROM   cst_item_cst_dtls_interface t,
	 mtl_system_items_b msi,
	 (SELECT mio.usage_rate_or_amount,
	         mic.inventory_item_id,
	         mic.organization_id,
	         v.resource_id,
	         v.cost_element_id,
	         mio.category_id
	  FROM   cst_item_overhead_defaults_v mio,
	         mtl_item_categories_v        mic,
	         fnd_lookup_values            y,
	         bom_resources_v              v
	  WHERE  mio.organization_id = mic.organization_id
	  AND    mio.category_id = mic.category_id
	  AND    mio.resource_id = v.resource_id
	  AND    v.cost_element_id = y.lookup_code
	  AND    v.organization_id = mio.organization_id
	  AND    y.language = 'US'
	  AND    y.lookup_type = 'CST_COST_CODE_TYPE'
	  AND    y.meaning = 'Material Overhead'
	  AND    mio.category_set_id = mic.category_set_id
	  AND    mio.usage_rate_or_amount IS NOT NULL) mioc, -------cost category
	 
	 mtl_parameters mp
      WHERE  1 = 1
      AND    msi.organization_id = t.organization_id
      AND    msi.inventory_item_id = t.inventory_item_id
      AND    msi.planning_make_buy_code = 2
      AND    mp.organization_id = p_mfg_organization_id ---parameter
      AND    t.cost_element = 'Material'
      AND    mp.organization_id = t.organization_id
      AND    (mioc.inventory_item_id(+) = t.inventory_item_id AND
	mioc.organization_id(+) = t.organization_id)
      AND    t.process_flag = 1;
  
    --v_usage_rate_or_amount NUMBER;
    v_numeric_dummy NUMBER;
  
    v_error_messsage VARCHAR2(5000);
    stop_processing EXCEPTION;
    v_step                  VARCHAR2(100);
    v_bool                  BOOLEAN;
    v_concurrent_request_id NUMBER := fnd_global.conc_request_id;
  
    v_retcode VARCHAR2(300);
    v_errbuf  VARCHAR2(300);
    -----------------------------------------------------------
  
  BEGIN
  
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := 'Success';
  
    ---
    /*BEGIN
      SELECT miod.usage_rate_or_amount
        INTO v_usage_rate_or_amount
        FROM cst_item_overhead_defaults_v miod
       WHERE miod.organization_id = p_mfg_organization_id ---parameter
         AND miod.category_id IS NULL;
    EXCEPTION
      WHEN no_data_found THEN
        v_error_messsage := 'No setup in cst_item_overhead_defaults_v';
        RAISE stop_processing;
    END;*/
    ------
  
    FOR item_tec IN c_cst_intrface LOOP
      IF item_tec.cost_element_id_moh IS NOT NULL THEN
        INSERT INTO cst_item_cst_dtls_interface
          (inventory_item_id,
           organization_id,
           cost_type,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           process_flag,
           cost_element_id,
           usage_rate_or_amount,
           item_cost,
           basis_type,
           resource_id,
           level_type,
           basis_factor,
           rollup_source_type,
           net_yield_or_shrinkage_factor,
           group_id)
        
        VALUES
          (item_tec.inventory_item_id --inventory_item_id (KIT-00040)
          ,
           item_tec.organization_id --organization_id
          ,
           item_tec.cost_type --COST_TYPE (Pending )
          ,
           SYSDATE -- LAST_UPDATE_DATE
          ,
           fnd_global.user_id --LAST_UPDATED_BY
          ,
           SYSDATE --CREATION_DATE
          ,
           fnd_global.user_id --CREATED_BY
          ,
           1 --Process_Flag
          ,
           item_tec.cost_element_id_moh --Cost_Element_ID (Material Overhead)
          ,
           ---L1.USAGE_RATE_OR_AMOUNT
           item_tec.usage_rate_or_amount --USAGE_RATE_OR_AMOUNT
          ,
           item_tec.item_cost --item_cost
          ,
           5 --basis_type
          ,
           item_tec.resource_id_moh --resource_id
          ,
           1 --LEVEL_TYPE
          ,
           item_tec.basis_factor -- basis_factor
          ,
           1 --rollup_source_type
          ,
           1 -- net_yield_or_shrinkage_factor
          ,
           item_tec.group_id);
        -- fnd_global.conc_request_id);
      END IF;
    
    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN stop_processing THEN
      v_error_messsage := 'ERROR in xxcst_upload_cost_pkg.upload_overhead: ' ||
		  v_error_messsage;
      message(v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
    WHEN OTHERS THEN
      v_error_messsage := substr('Unexpected ERROR in xxcst_upload_cost_pkg.upload_overhead (' ||
		         v_step || ') ' || SQLERRM,
		         1,
		         200);
  END upload_overhead;
  -----------------------------------------------------------------------------
  -- upload_cost
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -------------------------------------
  --     1.0  11.6.13     Vitaly           initial build
  --     1.1  05-Jun-2018 Dan Melamed      CHG0042784 - Add Cost type parameter (instead of hard coded 'Pending'
  -----------------------------------------------------------------------------
  PROCEDURE upload_cost(errbuf          OUT VARCHAR2,
		retcode         OUT VARCHAR2,
		p_table_name    IN VARCHAR2, --hidden parameter---- independent value set XXOBJT_LOADER_TABLES
		p_template_name IN VARCHAR2, -- dependent value set XXOBJT_LOADER_TEMPLATES
		p_file_name     IN VARCHAR2,
		p_directory     IN VARCHAR2,
    p_cost_type     IN VARCHAR2  --CHG0042784 DAN.Melamed 05-Jun-2018 : Add Cost type parameter (instead of hard coded 'Pending'
    ) IS
  
    CURSOR c_get_std_costing_data IS
      SELECT ROWID row_id,
	 a.*
      FROM   xxcst_item_cst_dtls_interface a
      WHERE  a.group_id = fnd_global.conc_request_id;
  
    CURSOR c_get_items_translation_errors(p_group_id NUMBER) IS
      SELECT a.item_code,
	 a.organization_code,
	 a.error_explanation
      FROM   xxcst_item_cst_dtls_interface a
      WHERE  a.group_id = p_group_id --- parameter
      AND    a.error_explanation IS NOT NULL;
  
    CURSOR c_get_import_errors(p_group_id NUMBER) IS
      SELECT msi.segment1 item_code,
	 a.organization_code,
	 a.error_code,
	 a.error_explanation,
	 a.inventory_item_id,
	 a.organization_id
      FROM   cst_item_cst_dtls_interface a,
	 mtl_system_items_b          msi
      WHERE  a.group_id = p_group_id --- parameter
	-- AND a.error_explanation IS NOT NULL
      AND    a.error_flag = 'E'
      AND    a.inventory_item_id = msi.inventory_item_id
      AND    a.organization_id = msi.organization_id;
  
    v_error_messsage VARCHAR2(5000);
    stop_processing EXCEPTION;
    v_step                  VARCHAR2(100);
    v_bool                  BOOLEAN;
    v_concurrent_request_id NUMBER := fnd_global.conc_request_id;
  
    v_retcode VARCHAR2(300);
    v_errbuf  VARCHAR2(300);
  
    v_inventory_item_id NUMBER;
    v_organization_id   NUMBER;
  
    v_translate_item_success_cntr  NUMBER;
    v_translate_item_error_cntr    NUMBER;
    v_inserted_into_interface_cntr NUMBER;
    v_material_overhead_cntr       NUMBER;
    v_cost_import_process_err_cntr NUMBER;
  
    ---- out variables for fnd_concurrent.wait_for_request-----
    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);
    -----------------------------------------------------------

    l_cost_type_Vc varchar2(255);  
    l_cost_Type_cnt number;
  BEGIN
    
    --CHG0042784 DAN.Melamed 05-Jun-2018 : Get textual cost type from ID Provided or validate cost type.
    begin
      
    select cst.cost_type
    into l_cost_type_vc
    from CST_COST_TYPES cst
    where cst.cost_type_id = p_cost_Type;
    
    exception
      
       when no_Data_found  then
           errbuf := 'Invalid cost type provided';
           retcode := 1;
           return;
        when others then
           
           begin
          
           select count(1)
           into l_cost_Type_cnt
           from CST_COST_TYPES cst
           where cst.cost_type = '' || p_cost_Type || ''; 
           
           exception
           
              when others then 
                 errbuf := 'Invalid cost type provided';
                 retcode := 1;
                 return;
           
           end;
    end;
           

    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := 'Success';
  
    message('GROUP_ID=' || fnd_global.conc_request_id ||
	'============================================');
  
    v_step := 'Step 40';
    ---Load data from CSV-table into XXCST_ITEM_CST_DTLS_INTERFACE table---------------------
    xxobjt_table_loader_util_pkg.load_file(errbuf                 => v_errbuf,
			       retcode                => v_retcode,
			       p_table_name           => 'XXCST_ITEM_CST_DTLS_INTERFACE',
			       p_template_name        => p_template_name,
			       p_file_name            => p_file_name,
			       p_directory            => p_directory,
			       p_expected_num_of_rows => NULL);
    IF v_retcode <> '0' THEN
      ---WARNING or ERROR---
      v_error_messsage := v_errbuf;
      RAISE stop_processing;
    END IF;
  
    message('All records from file ' || p_file_name ||
	' were successfully loaded into table XXCST_ITEM_CST_DTLS_INTERFACE');
  
    v_step := 'Step 50';
    ---Translate ITEM_CODE to INVENTORY_ITEM_ID---
    ---v_error_messsage              := NULL;
    v_translate_item_success_cntr := 0;
    v_translate_item_error_cntr   := 0;
    FOR item_rec IN c_get_std_costing_data LOOP
      -------
      BEGIN
        SELECT msi.inventory_item_id,
	   mp.organization_id
        INTO   v_inventory_item_id,
	   v_organization_id
        FROM   mtl_system_items msi,
	   mtl_parameters   mp
        WHERE  msi.organization_id = mp.organization_id
        AND    mp.organization_code = item_rec.organization_code
        AND    msi.segment1 = item_rec.item_code;
      
        UPDATE xxcst_item_cst_dtls_interface
        SET    inventory_item_id = v_inventory_item_id,
	   organization_id   = v_organization_id
        WHERE  ROWID = item_rec.row_id;
        v_translate_item_success_cntr := v_translate_item_success_cntr + 1;
      EXCEPTION
        WHEN no_data_found THEN
          UPDATE xxcst_item_cst_dtls_interface
          SET    err_code          = 'E',
	     error_explanation = 'Item ' || item_rec.item_code ||
			 ' does not exist in organization ' ||
			 item_rec.organization_code ||
			 '. This row will not pass to cst interface'
          WHERE  ROWID = item_rec.row_id;
          ----v_error_messsage            := 'Item does not exist in organization';
          v_translate_item_error_cntr := v_translate_item_error_cntr + 1;
      END;
      -------
    END LOOP;
  
    COMMIT;
    message('ITEM_CODE translation status:');
    message('Successfully : ' || v_translate_item_success_cntr ||
	' records');
    message('failed : ' || v_translate_item_error_cntr || ' records');
  
    v_step := 'Step 60';
    IF v_translate_item_error_cntr > 0 THEN
      message('======================================================================================');
      message('Failures translation records (will not pass to cst interface ) =======================');
      message('======================================================================================');
      ---Print in LOG all item_code translation errors
      FOR items_translation_error_rec IN c_get_items_translation_errors(fnd_global.conc_request_id) LOOP
        message('Translation Error: ' ||
	    items_translation_error_rec.error_explanation);
      END LOOP;
    END IF;
  
    v_step := 'Step 70';
    ---Insert all records to interface table CST_ITEM_CST_DTLS_INTERFACE
    INSERT INTO cst_item_cst_dtls_interface
      (inventory_item_id,
       cost_type_id,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login,
       group_id,
       organization_id,
       operation_sequence_id,
       operation_seq_num,
       department_id,
       level_type,
       activity_id,
       resource_seq_num,
       resource_id,
       resource_rate,
       item_units,
       activity_units,
       usage_rate_or_amount,
       basis_type,
       basis_resource_id,
       basis_factor,
       net_yield_or_shrinkage_factor,
       item_cost,
       cost_element_id,
       rollup_source_type,
       activity_context,
       request_id,
       organization_code,
       cost_type,
       inventory_item,
       department,
       activity,
       resource_code,
       basis_resource_code,
       cost_element,
       error_type,
       program_application_id,
       program_id,
       program_update_date,
       attribute_category,
       attribute1,
       attribute2,
       attribute3,
       attribute4,
       attribute5,
       attribute6,
       attribute7,
       attribute8,
       attribute9,
       attribute10,
       attribute11,
       attribute12,
       attribute13,
       attribute14,
       attribute15,
       transaction_id,
       process_flag,
       item_number,
       transaction_type,
       yielded_cost,
       ERROR_CODE,
       error_explanation,
       lot_size,
       based_on_rollup_flag,
       shrinkage_rate,
       inventory_asset_flag,
       error_flag,
       group_description)
      SELECT a.inventory_item_id,
	 a.cost_type_id,
	 a.last_update_date,
	 a.last_updated_by,
	 a.creation_date,
	 a.created_by,
	 a.last_update_login,
	 a.group_id,
	 a.organization_id,
	 a.operation_sequence_id,
	 a.operation_seq_num,
	 a.department_id,
	 a.level_type,
	 a.activity_id,
	 a.resource_seq_num,
	 a.resource_id,
	 a.resource_rate,
	 a.item_units,
	 a.activity_units,
	 a.usage_rate_or_amount,
	 a.basis_type,
	 a.basis_resource_id,
	 a.basis_factor,
	 a.net_yield_or_shrinkage_factor,
	 a.item_cost,
	 a.cost_element_id,
	 a.rollup_source_type,
	 a.activity_context,
	 a.request_id,
	 a.organization_code,
	 a.cost_type,
	 a.inventory_item,
	 a.department,
	 a.activity,
	 a.resource_code,
	 a.basis_resource_code,
	 a.cost_element,
	 a.error_type,
	 a.program_application_id,
	 a.program_id,
	 a.program_update_date,
	 a.attribute_category,
	 a.attribute1,
	 a.attribute2,
	 a.attribute3,
	 a.attribute4,
	 a.attribute5,
	 a.attribute6,
	 a.attribute7,
	 a.attribute8,
	 a.attribute9,
	 a.attribute10,
	 a.attribute11,
	 a.attribute12,
	 a.attribute13,
	 a.attribute14,
	 a.attribute15,
	 a.transaction_id,
	 a.process_flag,
	 a.item_number,
	 a.transaction_type,
	 a.yielded_cost,
	 a.error_code,
	 a.error_explanation,
	 a.lot_size,
	 a.based_on_rollup_flag,
	 a.shrinkage_rate,
	 a.inventory_asset_flag,
	 a.error_flag,
	 a.group_description
      FROM   xxcst_item_cst_dtls_interface a
      WHERE  a.group_id = fnd_global.conc_request_id
      AND    nvl(a.err_code, 'N') <> 'E';
  
    v_inserted_into_interface_cntr := SQL%ROWCOUNT;
  
    COMMIT;
  
    message(' ' || v_inserted_into_interface_cntr ||
	' records were successfully inserted into table CST_ITEM_CST_DTLS_INTERFACE');
  
    v_step := 'Step 100';
    -------Insert into CST_ITEM_CST_DTLS_INTERFACE for Upload Overhead-----------------
    FOR org_rec IN (SELECT DISTINCT t.organization_id
	        FROM   cst_item_cst_dtls_interface t --xxobjt.xxcst_item_cst_dtls_interface t
	        WHERE  t.process_flag = 1) LOOP
      ------check material overheads setup exists---
      SELECT COUNT(1)
      INTO   v_material_overhead_cntr
      FROM   bom_resources_v v
      WHERE  v.organization_id = org_rec.organization_id
      AND    v.cost_element_id = 2; --Material Overhead
      IF v_material_overhead_cntr > 0 THEN
      
        --WHERE t.group_id = fnd_global.conc_request_id) LOOP
        upload_overhead(errbuf                => v_error_messsage,
		retcode               => v_retcode,
		p_mfg_organization_id => org_rec.organization_id);
        IF v_retcode = '0' THEN
          message('Upload_Overhead was SUCCESSFULLY COMPLETED for organization_id=' ||
	      org_rec.organization_id);
        ELSIF v_retcode = '1' THEN
          message('Upload_Overhead was completed with WARNING for organization_id=' ||
	      org_rec.organization_id || ' ' || v_error_messsage);
        ELSIF v_retcode = '2' THEN
          message('Upload_Overhead was completed with ERROR for organization_id=' ||
	      org_rec.organization_id || ' ' || v_error_messsage);
        END IF;
      END IF; ---if v_material_overhead_cntr>0 then
    END LOOP;
  
    v_step := 'Step 200';
    ---Submit concurrent program 'Cost Import Process' / CSTPCIMP-------------------
    v_bool                  := fnd_request.set_print_options(NULL,
					 NULL,
					 0,
					 TRUE,
					 'N');
    v_concurrent_request_id := fnd_request.submit_request(application => 'BOM',
				          program     => 'CSTPCIMP',
				          argument1   => 4, --Import item costs,resource rates, and overhead rates       ----1, ---'Import Item Cost Only' ---parameter Import Cost Option
				          argument2   => 2, ---'Remove and Replace Cost Information' ---parameter Mode to run this request
				          argument3   => 2, --ALL      ----1, ---'Specific Group ID' -------parameter Group ID option
				          argument4   => NULL, ----1, -----parameter Group ID Dummy
				          argument5   => fnd_global.conc_request_id, -----parameter Group ID
				          argument6   => l_cost_type_vc, -- CHG0042784 - Add Cost type parameter (instead of hard coded 'Pending' -----parameter Cost type to import to
				          argument7   => 1 ---'Yes'  -----parameter Delete successful rows
				          );
    COMMIT;
  
    v_step := 'Step 210';
    IF v_concurrent_request_id > 0 THEN
      message('Concurrent ''Cost Import Process'' was submitted successfully (request_id=' ||
	  v_concurrent_request_id || ')');
      ---------
      v_step := 'Step 220';
      LOOP
        x_return_bool := fnd_concurrent.wait_for_request(v_concurrent_request_id,
				         5, --- interval 10  seconds
				         120, ---- max wait 60 seconds
				         x_phase,
				         x_status,
				         x_dev_phase,
				         x_dev_status,
				         x_message);
        EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';
      
      END LOOP;
    
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        message('The ''Cost Import Process'' concurrent program completed in ' ||
	    upper(x_dev_status) || '. See log for request_id=' ||
	    v_concurrent_request_id);
        message('==========================================================================================');
        message('=====================Error log for cst import ============================================');
        message('=item=======organization====error code=========== explanation=============================');
        v_step := 'Step 230';
        ---Print in LOG all errors from Open Interface table CST_ITEM_CST_DTLS_INTERFACE for this group_id
        v_cost_import_process_err_cntr := 0;
        FOR import_error_rec IN c_get_import_errors(fnd_global.conc_request_id) LOOP
          message(import_error_rec.item_code || '  ' ||
	      import_error_rec.organization_code || '  ' ||
	      import_error_rec.error_code || '  ' ||
	      import_error_rec.error_explanation);
          v_cost_import_process_err_cntr := v_cost_import_process_err_cntr + 1;
          UPDATE xxcst_item_cst_dtls_interface a
          SET    a.err_code          = 'E',
	     a.error_code        = import_error_rec.error_code,
	     a.error_explanation = import_error_rec.error_explanation,
	     a.last_update_date  = SYSDATE,
	     a.last_updated_by   = fnd_global.user_id
          WHERE  a.group_id = fnd_global.conc_request_id
          AND    a.inventory_item_id = import_error_rec.inventory_item_id
          AND    a.organization_id = import_error_rec.organization_id;
        END LOOP;
        IF v_cost_import_process_err_cntr = 0 THEN
          message('===================== NO ERRORS in COST IMPORT PROCESS ============================');
        END IF;
      
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
	upper(x_dev_status) = 'NORMAL' THEN
        message('The ''Cost Import Process'' program SUCCESSFULLY COMPLETED for request_id=' ||
	    v_concurrent_request_id);
      
      ELSE
        v_error_messsage := 'The ''Cost Import Process'' request failed review log for Oracle request_id=' ||
		    v_concurrent_request_id;
        RAISE stop_processing;
      END IF;
    ELSE
      v_error_messsage := 'Concurrent ''Cost Import Process'' submitting PROBLEM';
      RAISE stop_processing;
    END IF;
  
  EXCEPTION
    WHEN stop_processing THEN
    
      message(v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
    WHEN OTHERS THEN
      v_error_messsage := substr('Unexpected ERROR in xxcst_upload_cost_pkg.upload_cost (' ||
		         v_step || ') ' || SQLERRM,
		         1,
		         200);
      message(v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
  END upload_cost;
  ------------------------------------------------------------------------
  --  Function submit_request
  --  Run Oracle concurrent ‘Supply Chain Cost Rollup - No Report’
  ------------------------------------------------------------------------
  FUNCTION submit_request(p_batch_id NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c_new_rows IS
      SELECT xfgir.*
      FROM   xxcst_fg_item_rollup xfgir
      WHERE  xfgir.batch_id = p_batch_id
      AND    xfgir.status = 'New';
  
    CURSOR c_working_rows IS
      SELECT xfgir.*
      FROM   xxcst_fg_item_rollup xfgir
      WHERE  xfgir.batch_id = p_batch_id
      AND    xfgir.status = 'In Process';
  
    l_request_id         NUMBER;
    l_phase              VARCHAR2(100);
    l_phase_code         VARCHAR2(100);
    l_status             VARCHAR2(100);
    l_status_code        VARCHAR2(100);
    l_completion_message VARCHAR2(2000);
    l_res                BOOLEAN;
  
    l_org_id             NUMBER;
    l_cost_type_id       NUMBER;
    l_rollup_code        NUMBER;
    l_range_code         NUMBER;
    l_explosion_level    NUMBER;
    l_unimplemented_code NUMBER;
    l_engineering_code   NUMBER;
    l_lot_size_option    NUMBER;
    l_item_dummy         NUMBER;
    l_inventory_item_id  NUMBER;
    l_stat               VARCHAR2(100);
  
  BEGIN
    l_stat := 'Normal';
    message(chr(13));
    message('Results of item rollup for Btach_id = ' || p_batch_id);
  
    FOR l_new_row IN c_new_rows LOOP
    
      BEGIN
        SELECT nvl(t.organization_id, NULL)
        INTO   l_org_id
        FROM   inv.mtl_parameters t
        WHERE  t.organization_code = l_new_row.organization_code;
      EXCEPTION
        WHEN no_data_found THEN
          l_org_id := NULL;
      END;
    
      BEGIN
        SELECT nvl(cct.cost_type_id, NULL)
        INTO   l_cost_type_id
        FROM   cst_cost_types cct
        WHERE  cct.cost_type = l_new_row.cost_type;
      EXCEPTION
        WHEN no_data_found THEN
          l_cost_type_id := NULL;
      END;
    
      BEGIN
        SELECT nvl(lookup_code, NULL)
        INTO   l_rollup_code
        FROM   mfg_lookups
        WHERE  lookup_type = 'CST_ROLLUP_TYPE'
        AND    meaning = l_new_row.rollup_option;
      EXCEPTION
        WHEN no_data_found THEN
          l_rollup_code := NULL;
      END;
    
      BEGIN
        SELECT nvl(lookup_code, NULL)
        INTO   l_range_code
        FROM   mfg_lookups
        WHERE  lookup_type = 'CST_ITEM_RANGE'
        AND    lookup_code NOT IN (6, 7, 8)
        AND    meaning = l_new_row.range;
      EXCEPTION
        WHEN no_data_found THEN
          l_range_code := NULL;
      END;
    
      BEGIN
        SELECT decode(l_rollup_code, 1, 1, nvl(MAX(maximum_bom_level), 60))
        INTO   l_explosion_level
        FROM   bom_parameters
        WHERE  organization_id = l_org_id;
      EXCEPTION
        WHEN no_data_found THEN
          l_explosion_level := NULL;
      END;
    
      BEGIN
        SELECT nvl(lookup_code, NULL)
        INTO   l_unimplemented_code
        FROM   mfg_lookups
        WHERE  lookup_type = 'SYS_YES_NO'
        AND    meaning = l_new_row.include_unimplemented_eco;
      EXCEPTION
        WHEN no_data_found THEN
          l_unimplemented_code := NULL;
      END;
    
      BEGIN
        SELECT nvl(lookup_code, NULL)
        INTO   l_engineering_code
        FROM   mfg_lookups
        WHERE  lookup_type = 'SYS_YES_NO'
        AND    meaning = l_new_row.engineering_bills;
      EXCEPTION
        WHEN no_data_found THEN
          l_engineering_code := NULL;
      END;
    
      BEGIN
        SELECT nvl(lookup_code, NULL)
        INTO   l_lot_size_option
        FROM   mfg_lookups
        WHERE  lookup_type = 'CST_SC_LOT_OPTION'
        AND    meaning = l_new_row.lot_size_option;
      EXCEPTION
        WHEN no_data_found THEN
          l_lot_size_option := NULL;
      END;
    
      BEGIN
        SELECT 1
        INTO   l_item_dummy
        FROM   dual
        WHERE  l_range_code = 2;
      EXCEPTION
        WHEN no_data_found THEN
          l_item_dummy := NULL;
      END;
    
      BEGIN
        SELECT nvl(msb.inventory_item_id, NULL)
        INTO   l_inventory_item_id
        FROM   mtl_system_items_b msb
        WHERE  segment1 = l_new_row.specific_item
        AND    organization_id = l_org_id;
      EXCEPTION
        WHEN no_data_found THEN
          l_inventory_item_id := NULL;
      END;
    
      IF (l_org_id IS NOT NULL) AND (l_inventory_item_id IS NOT NULL) THEN
      
        l_request_id := fnd_request.submit_request(application => 'BOM',
				   program     => 'CSTRSCCRN',
				   argument1   => l_new_row.rollup_lock_flag, --Rollup lock flag
				   argument2   => l_org_id, --Default Org ID
				   argument3   => NULL, --Description
				   argument4   => l_cost_type_id, --Cost Type
				   argument5   => l_org_id, --Organization
				   argument6   => NULL, --Assignment Set
				   argument7   => NULL, --Buy Cost Type
				   argument8   => NULL, --Preserve Buy Cost Details
				   argument9   => l_new_row.conversion_type, --Currency Conversion Type
				   argument10  => l_new_row.default_cost_type, --Default Cost Type
				   argument11  => l_rollup_code, --Rollup Option
				   argument12  => l_range_code, --Range
				   argument13  => l_new_row.report_type, --Report Type
				   argument14  => l_new_row.material_detail, --Material Detail
				   argument15  => l_new_row.material_overhead_detail, --Material Overhead Detail
				   argument16  => l_new_row.routing_detail, --Routing Detail
				   argument17  => l_explosion_level, --Explosion Level
				   argument18  => l_new_row.report_number_of_levels, --Report Number of Levels
				   argument19  => to_char(l_new_row.effective_date,
						  'YYYY/MM/DD HH24:MI:SS'), --Effective Date
				   argument20  => l_unimplemented_code, --Include Unimplemented ECOs
				   argument21  => NULL, --Alternate Bill
				   argument22  => NULL, --Alternate Routing
				   argument23  => l_engineering_code, --Engineering Bills
				   argument24  => l_lot_size_option, --Lot Size Option
				   argument25  => NULL, --Lot Size Setting
				   argument26  => l_item_dummy, --Item dummy
				   argument27  => NULL, --Category dummy
				   argument28  => l_inventory_item_id, --Specific Item
				   argument29  => NULL, --Category set
				   argument30  => NULL, --Category validate flag
				   argument31  => NULL, --Category structure
				   argument32  => NULL, --Specific Category
				   argument33  => NULL, --Item From
				   argument34  => NULL, --Item To
				   argument35  => l_new_row.rollup_report_option, --Rollup Report Option
				   argument36  => l_new_row.quantity_precision, --Quantity Precision
				   argument37  => l_new_row.trace_mode); --Trace Mode
        IF l_request_id <> 0 THEN
          UPDATE xxcst_fg_item_rollup
          SET    request_id = l_request_id,
	     status     = 'In Process'
          WHERE  line_id = l_new_row.line_id;
          COMMIT;
        ELSE
          UPDATE xxcst_fg_item_rollup
          SET    status = 'Failed'
          WHERE  line_id = l_new_row.line_id;
          COMMIT;
          message('Concurrent was not submitted for Item Number = ' ||
	      l_new_row.specific_item);
          l_stat := 'Warning';
        END IF;
      
      ELSE
        UPDATE xxcst_fg_item_rollup
        SET    status = 'Failed'
        WHERE  line_id = l_new_row.line_id;
        COMMIT;
        message('Concurrent was not submitted for Item Number = ' ||
	    l_new_row.specific_item ||
	    '  - Wrong value of item or organization');
        l_stat := 'Warning';
      END IF;
    END LOOP;
  
    FOR l_working_row IN c_working_rows LOOP
    
      IF l_working_row.request_id <> 0 THEN
        COMMIT;
        l_res := fnd_concurrent.wait_for_request(request_id => l_working_row.request_id,
				 INTERVAL   => 1,
				 phase      => l_phase,
				 status     => l_status,
				 dev_phase  => l_phase_code,
				 dev_status => l_status_code,
				 message    => l_completion_message);
      
      END IF;
    
      IF l_phase_code = 'COMPLETE' THEN
        IF l_status_code = 'NORMAL' THEN
          UPDATE xxcst_fg_item_rollup
          SET    status = 'Pass'
          WHERE  line_id = l_working_row.line_id;
          COMMIT;
          message('Concurrent completed successfully for Item Number = ' ||
	      l_working_row.specific_item);
        ELSE
          UPDATE xxcst_fg_item_rollup
          SET    status = 'Failed'
          WHERE  line_id = l_working_row.line_id;
          COMMIT;
          message('Concurrent failed for Item Number = ' ||
	      l_working_row.specific_item || chr(13) ||
	      l_completion_message);
          l_stat := 'Warning';
        END IF;
      END IF;
    
    END LOOP;
  
    RETURN l_stat;
  
  END submit_request;
  -----------------------------------------------------------------------------------------
  --  Procedure fg_rollup
  --  Run Cost Rollup for the Finish Good
  -----------------------------------------------------------------------------------------
  PROCEDURE fg_rollup(errbuf          OUT VARCHAR2,
	          retcode         OUT VARCHAR2,
	          p_table_name    IN VARCHAR2,
	          p_template_name IN VARCHAR2,
	          p_file_name     IN VARCHAR2,
	          p_directory     IN VARCHAR2) IS
  
    l_batch_id NUMBER;
    x_errbuf   VARCHAR2(32000);
    x_retcode  VARCHAR2(100);
    l_status   VARCHAR2(100);
  
  BEGIN
    retcode    := 0;
    l_batch_id := fnd_global.conc_request_id;
  
    xxobjt_table_loader_util_pkg.load_file(x_errbuf,
			       x_retcode,
			       p_table_name,
			       p_template_name,
			       p_file_name,
			       p_directory,
			       NULL);
    IF x_retcode = 2 THEN
      message(x_errbuf);
      retcode := 2;
      RETURN;
    END IF;
  
    IF x_retcode = 1 THEN
      message(x_errbuf);
      l_status := submit_request(l_batch_id);
    ELSE
      l_status := submit_request(l_batch_id);
      NULL;
    END IF;
  
    IF l_status = 'Normal' THEN
      retcode := 0;
    ELSE
      retcode := 1;
    END IF;
  
  END fg_rollup;

  -----------------------------------------------------------------------------------------
  --  Procedure buy_items_auto_update
  --  Updating Material Standard Costs for Buy Items
  -----------------------------------------------------------------------------------------
  PROCEDURE buy_items_auto_update(errbuf   OUT VARCHAR2,
		          retcode  OUT VARCHAR2,
		          p_org_id IN VARCHAR2) IS
  
    CURSOR c_rows(p_to_currency    VARCHAR2,
	      p_operating_unit NUMBER) IS
      SELECT msb.segment1 item_number,
	 msb.inventory_item_id,
	 mp.organization_code,
	 gl_currency_api.convert_closest_amount_sql(nvl(ind.currency_code,
					h.currency_code),
				        p_to_currency,
				        nvl(ind.base_date,
					nvl(h.rate_date,
					    h.creation_date)),
				        'Corporate',
				        nvl(ind.base_rate,
					h.rate),
				        l.unit_price /
				        decode(ind.base_rate,
					   0,
					   1,
					   NULL,
					   1,
					   ind.base_rate),
				        7) material_cost
      FROM   po_headers_all        h,
	 po_lines_all          l,
	 po_line_locations_all pl,
	 -- cst_item_costs           cic,
	 clef062_po_index_esc_set ind,
	 mtl_system_items_b       msb,
	 mtl_parameters           mp
      WHERE  h.po_header_id = l.po_header_id
      AND    h.segment1 = ind.document_id(+)
      AND    h.revision_num = ind.release_num(+)
      AND    l.po_line_id = pl.po_line_id
      AND    h.po_header_id = pl.po_header_id
      AND    ind.module(+) = 'PO'
      AND    l.item_id = msb.inventory_item_id
      AND    pl.ship_to_organization_id = msb.organization_id
      AND    msb.organization_id = p_org_id
      AND    msb.organization_id = mp.organization_id
	--  AND    cic.inventory_item_id(+) = l.item_id
	--  AND    cic.cost_type_id(+) = 3
	--  AND    cic.organization_id(+) = p_org_id
	-- AND    nvl(cic.material_cost(+), 0) = 0
      AND    pl.ship_to_organization_id = msb.organization_id
      AND    pl.line_location_id =
	 (SELECT MAX(pl1.line_location_id)
	   FROM   po_headers_all        h1,
	          po_lines_all          l1,
	          po_line_locations_all pl1
	   WHERE  h1.po_header_id = l1.po_header_id
	   AND    l1.po_line_id = pl1.po_line_id
	   AND    l1.item_id = msb.inventory_item_id
	   AND    pl1.ship_to_organization_id = msb.organization_id
	   AND    l1.org_id = p_operating_unit
	   AND    h1.type_lookup_code IN ('BLANKET', 'STANDARD')
	   AND    h1.authorization_status = 'APPROVED'
	   AND    nvl(l1.cancel_flag, 'N') = 'N'
	   AND    nvl(pl1.promised_date, pl1.need_by_date) < SYSDATE
	   AND    l1.unit_price > 0)
      AND    nvl((SELECT item_cost
	     
	     FROM   cst_item_costs cic
	     WHERE  cic.inventory_item_id = msb.inventory_item_id
	     AND    cic.organization_id = msb.organization_id
	     AND    cic.cost_type_id = 3),
	     0) = 0;
  
    CURSOR c_get_std_costing_data IS
      SELECT ROWID row_id,
	 a.*
      FROM   xxcst_item_cst_dtls_interface a
      WHERE  a.group_id = fnd_global.conc_request_id;
  
    CURSOR c_get_items_translation_errors(p_group_id NUMBER) IS
      SELECT a.item_code,
	 a.organization_code,
	 a.error_explanation
      FROM   xxcst_item_cst_dtls_interface a
      WHERE  a.group_id = p_group_id --- parameter
      AND    a.error_explanation IS NOT NULL;
  
    CURSOR c_get_import_errors(p_group_id NUMBER) IS
      SELECT msi.segment1 item_code,
	 a.organization_code,
	 a.error_code,
	 a.error_explanation,
	 a.inventory_item_id,
	 a.organization_id
      FROM   cst_item_cst_dtls_interface a,
	 mtl_system_items_b          msi
      WHERE  a.group_id = p_group_id --- parameter
	-- AND a.error_explanation IS NOT NULL
      AND    a.error_flag = 'E'
      AND    a.inventory_item_id = msi.inventory_item_id
      AND    a.organization_id = msi.organization_id;
  
    v_error_messsage VARCHAR2(5000);
    stop_processing EXCEPTION;
    v_step                  VARCHAR2(100);
    v_bool                  BOOLEAN;
    v_concurrent_request_id NUMBER := fnd_global.conc_request_id;
  
    v_retcode VARCHAR2(300);
    v_errbuf  VARCHAR2(300);
  
    v_inventory_item_id NUMBER;
    v_organization_id   NUMBER;
  
    v_translate_item_success_cntr  NUMBER;
    v_translate_item_error_cntr    NUMBER;
    v_inserted_into_interface_cntr NUMBER;
    v_material_overhead_cntr       NUMBER;
    v_cost_import_process_err_cntr NUMBER;
    v_num_of_inserted_records      NUMBER;
    l_currency                     VARCHAR2(15);
    l_operating_unit               NUMBER;
  
    ---- out variables for fnd_concurrent.wait_for_request-----
    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);
    -----------------------------------------------------------
  BEGIN
    v_step                    := 'Step 0';
    retcode                   := '0';
    errbuf                    := 'Success';
    v_num_of_inserted_records := 0;
  
    message('GROUP_ID=' || fnd_global.conc_request_id ||
	'============================================');
    SELECT gl.currency_code
    INTO   l_currency
    FROM   org_organization_definitions odf,
           gl_ledgers                   gl
    WHERE  odf.organization_id = p_org_id
    AND    odf.set_of_books_id = gl.ledger_id;
  
    SELECT ioi.operating_unit
    INTO   l_operating_unit
    FROM   inv_organization_info_v ioi
    WHERE  ioi.organization_id = p_org_id;
  
    BEGIN
      FOR l_rows IN c_rows(l_currency, l_operating_unit) LOOP
        INSERT INTO xxcst_item_cst_dtls_interface
          (item_code,
           usage_rate_or_amount,
           organization_code,
           cost_type,
           cost_element,
           process_flag,
           group_id,
           creation_date,
           created_by,
           last_update_date,
           last_updated_by,
           last_update_login)
        VALUES
          (l_rows.item_number,
           l_rows.material_cost,
           l_rows.organization_code,
           'Pending',
           'Material',
           1,
           fnd_global.conc_request_id,
           SYSDATE,
           fnd_global.user_id,
           SYSDATE,
           fnd_global.user_id,
           fnd_global.conc_login_id);
      
        v_num_of_inserted_records := v_num_of_inserted_records + 1;
        IF v_num_of_inserted_records >= 500 THEN
          COMMIT;
          v_num_of_inserted_records := 0;
        END IF;
      END LOOP;
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        v_retcode        := 2;
        v_error_messsage := SQLERRM;
    END;
  
    IF v_retcode <> '0' THEN
      RAISE stop_processing;
    END IF;
  
    message('All records were successfully loaded into table XXCST_ITEM_CST_DTLS_INTERFACE');
  
    v_step := 'Step 50';
    ---Translate ITEM_CODE to INVENTORY_ITEM_ID---
    ---v_error_messsage              := NULL;
    v_translate_item_success_cntr := 0;
    v_translate_item_error_cntr   := 0;
    FOR item_rec IN c_get_std_costing_data LOOP
      -------
      BEGIN
        SELECT msi.inventory_item_id,
	   mp.organization_id
        INTO   v_inventory_item_id,
	   v_organization_id
        FROM   mtl_system_items msi,
	   mtl_parameters   mp
        WHERE  msi.organization_id = mp.organization_id
        AND    mp.organization_code = item_rec.organization_code
        AND    msi.segment1 = item_rec.item_code;
      
        UPDATE xxcst_item_cst_dtls_interface
        SET    inventory_item_id = v_inventory_item_id,
	   organization_id   = v_organization_id
        WHERE  ROWID = item_rec.row_id;
        v_translate_item_success_cntr := v_translate_item_success_cntr + 1;
      EXCEPTION
        WHEN no_data_found THEN
          UPDATE xxcst_item_cst_dtls_interface
          SET    err_code          = 'E',
	     error_explanation = 'Item ' || item_rec.item_code ||
			 ' does not exist in organization ' ||
			 item_rec.organization_code ||
			 '. This row will not pass to cst interface'
          WHERE  ROWID = item_rec.row_id;
          ----v_error_messsage            := 'Item does not exist in organization';
          v_translate_item_error_cntr := v_translate_item_error_cntr + 1;
      END;
      -------
    END LOOP;
  
    COMMIT;
    message('ITEM_CODE translation status:');
    message('Successfully : ' || v_translate_item_success_cntr ||
	' records');
    message('failed : ' || v_translate_item_error_cntr || ' records');
  
    v_step := 'Step 60';
    IF v_translate_item_error_cntr > 0 THEN
      message('======================================================================================');
      message('Failures translation records (will not pass to cst interface ) =======================');
      message('======================================================================================');
      ---Print in LOG all item_code translation errors
      FOR items_translation_error_rec IN c_get_items_translation_errors(fnd_global.conc_request_id) LOOP
        message('Translation Error: ' ||
	    items_translation_error_rec.error_explanation);
      END LOOP;
    END IF;
  
    v_step := 'Step 70';
    ---Insert all records to interface table CST_ITEM_CST_DTLS_INTERFACE
    INSERT INTO cst_item_cst_dtls_interface
      (inventory_item_id,
       cost_type_id,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login,
       group_id,
       organization_id,
       operation_sequence_id,
       operation_seq_num,
       department_id,
       level_type,
       activity_id,
       resource_seq_num,
       resource_id,
       resource_rate,
       item_units,
       activity_units,
       usage_rate_or_amount,
       basis_type,
       basis_resource_id,
       basis_factor,
       net_yield_or_shrinkage_factor,
       item_cost,
       cost_element_id,
       rollup_source_type,
       activity_context,
       request_id,
       organization_code,
       cost_type,
       inventory_item,
       department,
       activity,
       resource_code,
       basis_resource_code,
       cost_element,
       error_type,
       program_application_id,
       program_id,
       program_update_date,
       attribute_category,
       attribute1,
       attribute2,
       attribute3,
       attribute4,
       attribute5,
       attribute6,
       attribute7,
       attribute8,
       attribute9,
       attribute10,
       attribute11,
       attribute12,
       attribute13,
       attribute14,
       attribute15,
       transaction_id,
       process_flag,
       item_number,
       transaction_type,
       yielded_cost,
       ERROR_CODE,
       error_explanation,
       lot_size,
       based_on_rollup_flag,
       shrinkage_rate,
       inventory_asset_flag,
       error_flag,
       group_description)
      SELECT a.inventory_item_id,
	 a.cost_type_id,
	 a.last_update_date,
	 a.last_updated_by,
	 a.creation_date,
	 a.created_by,
	 a.last_update_login,
	 a.group_id,
	 a.organization_id,
	 a.operation_sequence_id,
	 a.operation_seq_num,
	 a.department_id,
	 a.level_type,
	 a.activity_id,
	 a.resource_seq_num,
	 a.resource_id,
	 a.resource_rate,
	 a.item_units,
	 a.activity_units,
	 a.usage_rate_or_amount,
	 a.basis_type,
	 a.basis_resource_id,
	 a.basis_factor,
	 a.net_yield_or_shrinkage_factor,
	 a.item_cost,
	 a.cost_element_id,
	 a.rollup_source_type,
	 a.activity_context,
	 a.request_id,
	 a.organization_code,
	 a.cost_type,
	 a.inventory_item,
	 a.department,
	 a.activity,
	 a.resource_code,
	 a.basis_resource_code,
	 a.cost_element,
	 a.error_type,
	 a.program_application_id,
	 a.program_id,
	 a.program_update_date,
	 a.attribute_category,
	 a.attribute1,
	 a.attribute2,
	 a.attribute3,
	 a.attribute4,
	 a.attribute5,
	 a.attribute6,
	 a.attribute7,
	 a.attribute8,
	 a.attribute9,
	 a.attribute10,
	 a.attribute11,
	 a.attribute12,
	 a.attribute13,
	 a.attribute14,
	 a.attribute15,
	 a.transaction_id,
	 a.process_flag,
	 a.item_number,
	 a.transaction_type,
	 a.yielded_cost,
	 a.error_code,
	 a.error_explanation,
	 a.lot_size,
	 a.based_on_rollup_flag,
	 a.shrinkage_rate,
	 a.inventory_asset_flag,
	 a.error_flag,
	 a.group_description
      FROM   xxcst_item_cst_dtls_interface a
      WHERE  a.group_id = fnd_global.conc_request_id
      AND    nvl(a.err_code, 'N') <> 'E';
  
    v_inserted_into_interface_cntr := SQL%ROWCOUNT;
  
    COMMIT;
  
    message(' ' || v_inserted_into_interface_cntr ||
	' records were successfully inserted into table CST_ITEM_CST_DTLS_INTERFACE');
  
    v_step := 'Step 100';
    -------Insert into CST_ITEM_CST_DTLS_INTERFACE for Upload Overhead-----------------
    FOR org_rec IN (SELECT DISTINCT t.organization_id
	        FROM   cst_item_cst_dtls_interface t --xxobjt.xxcst_item_cst_dtls_interface t
	        WHERE  t.process_flag = 1) LOOP
      ------check material overheads setup exists---
      SELECT COUNT(1)
      INTO   v_material_overhead_cntr
      FROM   bom_resources_v v
      WHERE  v.organization_id = org_rec.organization_id
      AND    v.cost_element_id = 2; --Material Overhead
      IF v_material_overhead_cntr > 0 THEN
      
        --WHERE t.group_id = fnd_global.conc_request_id) LOOP
        upload_overhead(errbuf                => v_error_messsage,
		retcode               => v_retcode,
		p_mfg_organization_id => org_rec.organization_id);
        IF v_retcode = '0' THEN
          message('Upload_Overhead was SUCCESSFULLY COMPLETED for organization_id=' ||
	      org_rec.organization_id);
        ELSIF v_retcode = '1' THEN
          message('Upload_Overhead was completed with WARNING for organization_id=' ||
	      org_rec.organization_id || ' ' || v_error_messsage);
        ELSIF v_retcode = '2' THEN
          message('Upload_Overhead was completed with ERROR for organization_id=' ||
	      org_rec.organization_id || ' ' || v_error_messsage);
        END IF;
      END IF; ---if v_material_overhead_cntr>0 then
    END LOOP;
  
    v_step := 'Step 200';
    ---Submit concurrent program 'Cost Import Process' / CSTPCIMP-------------------
    v_bool                  := fnd_request.set_print_options(NULL,
					 NULL,
					 0,
					 TRUE,
					 'N');
    v_concurrent_request_id := fnd_request.submit_request(application => 'BOM',
				          program     => 'CSTPCIMP',
				          argument1   => 4, --Import item costs,resource rates, and overhead rates       ----1, ---'Import Item Cost Only' ---parameter Import Cost Option
				          argument2   => 2, ---'Remove and Replace Cost Information' ---parameter Mode to run this request
				          argument3   => 2, --ALL      ----1, ---'Specific Group ID' -------parameter Group ID option
				          argument4   => NULL, ----1, -----parameter Group ID Dummy
				          argument5   => fnd_global.conc_request_id, -----parameter Group ID
				          argument6   => 'Pending', -----parameter Cost type to import to
				          argument7   => 1 ---'Yes'  -----parameter Delete successful rows
				          );
    COMMIT;
  
    v_step := 'Step 210';
    IF v_concurrent_request_id > 0 THEN
      message('Concurrent ''Cost Import Process'' was submitted successfully (request_id=' ||
	  v_concurrent_request_id || ')');
      ---------
      v_step := 'Step 220';
      LOOP
        x_return_bool := fnd_concurrent.wait_for_request(v_concurrent_request_id,
				         5, --- interval 10  seconds
				         120, ---- max wait 60 seconds
				         x_phase,
				         x_status,
				         x_dev_phase,
				         x_dev_status,
				         x_message);
        EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';
      
      END LOOP;
    
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        message('The ''Cost Import Process'' concurrent program completed in ' ||
	    upper(x_dev_status) || '. See log for request_id=' ||
	    v_concurrent_request_id);
        message('==========================================================================================');
        message('=====================Error log for cst import ============================================');
        message('=item=======organization====error code=========== explanation=============================');
        v_step := 'Step 230';
        ---Print in LOG all errors from Open Interface table CST_ITEM_CST_DTLS_INTERFACE for this group_id
        v_cost_import_process_err_cntr := 0;
        FOR import_error_rec IN c_get_import_errors(fnd_global.conc_request_id) LOOP
          message(import_error_rec.item_code || '  ' ||
	      import_error_rec.organization_code || '  ' ||
	      import_error_rec.error_code || '  ' ||
	      import_error_rec.error_explanation);
          v_cost_import_process_err_cntr := v_cost_import_process_err_cntr + 1;
          UPDATE xxcst_item_cst_dtls_interface a
          SET    a.err_code          = 'E',
	     a.error_code        = import_error_rec.error_code,
	     a.error_explanation = import_error_rec.error_explanation,
	     a.last_update_date  = SYSDATE,
	     a.last_updated_by   = fnd_global.user_id
          WHERE  a.group_id = fnd_global.conc_request_id
          AND    a.inventory_item_id = import_error_rec.inventory_item_id
          AND    a.organization_id = import_error_rec.organization_id;
        END LOOP;
        IF v_cost_import_process_err_cntr = 0 THEN
          message('===================== NO ERRORS in COST IMPORT PROCESS ============================');
        END IF;
      
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
	upper(x_dev_status) = 'NORMAL' THEN
        message('The ''Cost Import Process'' program SUCCESSFULLY COMPLETED for request_id=' ||
	    v_concurrent_request_id);
      
      ELSE
        v_error_messsage := 'The ''Cost Import Process'' request failed review log for Oracle request_id=' ||
		    v_concurrent_request_id;
        RAISE stop_processing;
      END IF;
    ELSE
      v_error_messsage := 'Concurrent ''Cost Import Process'' submitting PROBLEM';
      RAISE stop_processing;
    END IF;
  
  EXCEPTION
    WHEN stop_processing THEN
    
      message(v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
    WHEN OTHERS THEN
      v_error_messsage := substr('Unexpected ERROR in xxcst_upload_cost_pkg.upload_cost (' ||
		         v_step || ') ' || SQLERRM,
		         1,
		         200);
      message(v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
    
  END buy_items_auto_update;

END xxcst_upload_cost_pkg;
/
