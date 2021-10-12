CREATE OR REPLACE PACKAGE BODY APPS.xxfnd_conc_req_metadata_rpt AS
---------------------------------------------------------------------------------------
--  name:            xxfnd_conc_req_metadata_rpt
--  create by:       S3 Project
--  Revision:        1.0
--  creation date:   05-APR-2017
--  Object Type :    Package Body      
---------------------------------------------------------------------------------------
--  purpose :        
---------------------------------------------------------------------------------------
--  ver  date          name                 desc
--  1.0                S3 Project           initial build - Created During S3 Project
--  1.1  05-APR-2017   Lingaraj Sarangi     Deployment on 12.1.3
---------------------------------------------------------------------------------------
--*****************************************************************************
   --*  PUBLIC FUNCTIONS
   --*****************************************************************************
   FUNCTION f_conc_req_hdr_md (
     p_concurent_request_id IN NUMBER) 
   RETURN APPS.XXFND_CR_MD_HDR_TABLE_TYPE
    --* Description: 
    --*    This function returns a rows for the header information pertaining
	--*    to a concurrent request.

    --* Inputs:
    --*    p_concurent_request_id: Concurrent Request ID
    --* Outputs:
    --*    APPS.XXFND_CR_MD_HDR_TABLE_TYPE
   IS
        /* Local Constants*/
        c_function_name VARCHAR2 (30) := 'f_conc_req_hdr_md';
        c_sql VARCHAR2(32000);  --Holds generic SQL statement
        c_where_clause_conc_req_id VARCHAR2 (150) := Q'[ AND request_id = ]';  --Base WHERE clause, pertaining to the Concurrent Request ID for the dynamic SQL statement.

        /* Local Variables */
        l_concurrent_request_id NUMBER;
        l_result_temp APPS.XXFND_CR_MD_HDR_TABLE_TYPE := APPS.XXFND_CR_MD_HDR_TABLE_TYPE();  -- Holds the result of the dynamic sql query
        
        /* Local variables for dynamic SQL */
        l_dynamic_sql VARCHAR2(32000);  --Holds dynamic SQL statement
        l_where_clause_conc_req_id VARCHAR2 (150);  --Component of WHERE clause, pertaining to the Organization ID for the dynamic SQL statement.
        
        /* Cursors*/
        TYPE t_ref_cursor IS REF CURSOR;-- SYS_REFCURSOR;
        cur_dynamic t_ref_cursor;
 
    BEGIN
        IF c_debug_level = 10 THEN
            fnd_file.put_line(which => fnd_file.log, buff => c_output_header || c_function_name);
            dbms_output.put_line(c_output_header || c_function_name); 
        END IF;
       
        /* Prepare Parameters*/
        l_concurrent_request_id := p_concurent_request_id;
        
        /* Build components of the WHERE clause.  */
        l_where_clause_conc_req_id := c_where_clause_conc_req_id || l_concurrent_request_id;
        
        IF c_debug_level = 10 THEN
            fnd_file.put_line( fnd_file.log, 'WHERE clause components built.');
            dbms_output.put_line('WHERE clause components built.'); 
        END IF;
  
        IF c_debug_level = 10 THEN
            fnd_file.put_line( fnd_file.log, 'Begin build of dynamic SQL.' );
            dbms_output.put_line('Begin build of dynamic SQL.'); 
        END IF;
      
    /* Build a dynamic SQL Statement.  Note the use of the alternative quoting 
       mechanism (Q') using "[" as the quote_delimiter.  This is to make the 
       use of single quotes in the variable clearer. Note that bind variables 
       are not, and cannot, be used because the view/table names will be 
       different across orgs. (Bind variables can't be used to specify table or
       view names.) */
    l_dynamic_sql := Q'[
/* Return Concurrent Request Metadata for Report Header. */
WITH sq_a
AS
	/* Application Info */
	(
	SELECT application_id
		,application_name
	FROM fnd_application_tl
	WHERE LANGUAGE = SYS_CONTEXT('USERENV', 'LANG')
	)
    ,sq_cr
AS
    /* Concurrent Request Details */
    (SELECT      
        fcrsv.request_id
        ,fcrsv.parent_request_id
        ,fcrsv.program_application_id
        ,fcrsv.concurrent_program_id
        ,fcrsv.program
        ,fcrsv.program_short_name
        ,'not yet mapped to source' cr_local_time_zone --http://allaboutoracleapplication.blogspot.com/search/label/How%20to%20show%20Report%20Date%20in%20Local%20Timezone%20instead%20of%20Server%20Timezone%20in%20Oracle%20Apps
        ,TO_CHAR(fcrsv.request_date, 'DD-MON-YYYY HH24:MI:SS') date_submitted_text
        ,TO_CHAR(fcrsv.requested_start_date, 'DD-MON-YYYY HH24:MI:SS') requested_start_date_text
        ,TO_CHAR(fcrsv.actual_completion_date, 'DD-MON-YYYY HH24:MI:SS') actual_completion_date_text
        ,fcrsv.requested_by  --ID
        ,fcrsv.requestor
        ,fcrsv.status_code
        ,fcrsv.phase_code
        ,fcrsv.completion_text
        ,fcrsv.printer
        ,fcrsv.responsibility_id
        ,FND_PROFILE.VALUE_SPECIFIC('SERVER_TIMEZONE_ID',null) server_timezone_code
        ,FND_PROFILE.VALUE_SPECIFIC('CLIENT_TIMEZONE_ID',fcrsv.requested_by) client_timezone_code
        ,frt.responsibility_name
        ,sa.application_name resp_application_name
    FROM fnd_conc_req_summary_v fcrsv 
    LEFT JOIN fnd_responsibility_tl frt ON (frt.responsibility_id = fcrsv.responsibility_id AND frt.language = SYS_CONTEXT('USERENV', 'LANG'))
    LEFT JOIN sq_a sa ON (sa.application_id = frt.application_id) 
    )	
	,sq_p
AS
	/* Concurrent Program Information*/
	(
	SELECT fcp.application_id
		,fcp.concurrent_program_id
		,fcp.concurrent_program_name
		,fcpt.user_concurrent_program_name
		,fcpt.description
	FROM fnd_concurrent_programs fcp
	INNER JOIN fnd_concurrent_programs_tl fcpt ON (
			fcp.application_id = fcpt.application_id
			AND fcp.concurrent_program_id = fcpt.concurrent_program_id
			)
	WHERE fcpt.LANGUAGE = SYS_CONTEXT('USERENV', 'LANG')
	)
	/* Concurrent Program Status Codes*/
	,sq_cpsc
AS (
	SELECT lookup_code
		,meaning
	FROM fnd_lookup_values
	WHERE lookup_type = 'CP_STATUS_CODE'
		AND LANGUAGE = SYS_CONTEXT('USERENV', 'LANG')
		AND enabled_flag = 'Y'
		/* There are duplicate rows differentiated by the view_application_id values*/
		AND view_application_id = 0
	)
	/* Concurrent Program Phase Codes*/
	,sq_cppc
AS (
	SELECT lookup_code
		,meaning
	FROM fnd_lookup_values
	WHERE lookup_type = 'CP_PHASE_CODE'
		AND LANGUAGE = SYS_CONTEXT('USERENV', 'LANG')
		AND enabled_flag = 'Y'
		/* There are duplicate rows differentiated by the view_application_id values*/
		AND view_application_id = 0
	)
	,sq_opp
AS
	/* Output Post-Processing info*/
	(
	SELECT concurrent_request_id
		,action_type
		,status_s_flag
		,status_w_flag
		,status_f_flag
		,arguments
		,completed
		,number_of_copies
		,sequence
		,argument1 application_short_name
		,argument2 template_code
		,argument3
		,argument4
		,argument5
		,argument6
		,argument7
		,argument8
		,argument9
		,argument10
		,publisher_return_results
	FROM fnd_conc_pp_actions
	WHERE action_type = 6
	)

	,sq_tz
AS
	/* Timezones*/
	(
	SELECT
	timezone_code
	,upgrade_tz_id
	,'(GMT ' || RTRIM(TZ_OFFSET(timezone_code),chr(0)) || ') ' || name timezone_description
	FROM fnd_timezones_vl
	)

   ,sq_env
	/* Get various environment-related information.*/
AS (
    SELECT
    SYS_CONTEXT('USERENV', 'DB_NAME') sc_db_name
    ,SYS_CONTEXT('USERENV', 'MODULE') sc_module
    ,SYS_CONTEXT('USERENV', 'LANG') sc_lang
    ,SYS_CONTEXT('USERENV', 'HOST') sc_host
    ,SYS_CONTEXT('USERENV', 'OS_USER') sc_os_user
    ,(
        SELECT organization_code
        FROM org_organization_definitions 
        WHERE organization_id = TO_NUMBER(FND_PROFILE.VALUE('MFG_ORGANIZATION_ID')) 
        ) organization_code  
    FROM DUAL
    )
	
SELECT XXFND_CR_MD_HDR_ROW_TYPE(
	/* Concurrent Program Details */
	 sq_cr.program
	,sq_cr.program_short_name
	
	/* Concurrent Request Details */
	,sq_cr.request_id
	,sq_cr.parent_request_id
	,sq_cr.date_submitted_text
	,sq_cr.requested_start_date_text
	,sq_cr.actual_completion_date_text
	,sq_cr.requested_by--ID
	,sq_cr.requestor
	,sq_cr.completion_text
	,'not yet mapped to source field' --layout
	,sq_cr.printer
	,sq_cr.responsibility_name
	,sq_cr.resp_application_name
	
	/* Environment Details */
    ,sq_env.sc_db_name
    ,sq_env.sc_module
    ,sq_env.sc_lang
    ,sq_env.sc_host
    ,sq_env.sc_os_user
	,sq_env.organization_code
	,NULL--request group
	,NULL--schedule
	
	/* Translated values to meanings */
	,sq_a.application_name
	,sq_p.description
	,sq_cpsc.meaning
	,sq_cppc.meaning
	,sq_opp.publisher_return_results
	,stz1.timezone_description --server time zone
	,stz2.timezone_description --local time zone  --http://allaboutoracleapplication.blogspot.com/search/label/How%20to%20show%20Report%20Date%20in%20Local%20Timezone%20instead%20of%20Server%20Timezone%20in%20Oracle%20Apps
)
FROM sq_cr
LEFT JOIN sq_a ON (sq_a.application_id = sq_cr.program_application_id)
LEFT JOIN sq_p ON (
		sq_p.application_id = sq_cr.program_application_id
		AND sq_p.concurrent_program_id = sq_cr.concurrent_program_id
		)
LEFT JOIN sq_cpsc ON (sq_cpsc.lookup_code = sq_cr.status_code)
LEFT JOIN sq_cppc ON (sq_cppc.lookup_code = sq_cr.phase_code)
LEFT JOIN sq_opp ON (sq_opp.concurrent_request_id = sq_cr.request_id)
LEFT JOIN sq_tz stz1 ON (stz1.upgrade_tz_id = sq_cr.server_timezone_code)
LEFT JOIN sq_tz stz2 ON (stz2.upgrade_tz_id = sq_cr.client_timezone_code)
LEFT JOIN sq_env ON (1=1)
        WHERE 1=1 ]'

        || l_where_clause_conc_req_id
;      
      
      /* Write the SQL statement to the log file so that it can be debugged should issues arise. */
      IF c_debug_level = 10 THEN dbms_output.put_line(l_dynamic_sql);
          fnd_file.put_line( fnd_file.log, 'SQL Statement in variable "l_dynamic_sql":' );
          fnd_file.put_line( fnd_file.log, l_dynamic_sql ); 
      END IF;

      /* Execute the dynamic SQL statement. */
      EXECUTE IMMEDIATE l_dynamic_sql BULK COLLECT INTO l_result_temp;
      
      IF c_debug_level = 10 THEN 
        dbms_output.put_line('Rows returned: ' || l_result_temp.COUNT);
        fnd_file.put_line( fnd_file.log, 'Rows returned: ' || l_result_temp.COUNT);   
        
        dbms_output.put_line('Request ID: ' || fnd_global.conc_request_id);
        fnd_file.put_line( fnd_file.log, 'Request ID: ' || fnd_global.conc_request_id);     
        
        dbms_output.put_line(c_output_footer || c_function_name);
        fnd_file.put_line( fnd_file.log, c_output_footer || c_function_name); 
      END IF;
 
      RETURN l_result_temp;
    
      EXCEPTION
        WHEN OTHERS THEN
          /* If function was called in the context of a concurrent program, 
          write the error to the log file.  Otherwise write to dbms_output. */
          IF fnd_global.conc_request_id <> -1 THEN
            IF c_debug_level = 10 THEN fnd_file.put_line( fnd_file.log, 'Unhandled exception: ' || SQLERRM ); END IF;
          ELSE
            DBMS_OUTPUT.put_line(SQLERRM);      
          END IF;
          
          /* Return*/
          RETURN NULL;--***Just did this as place holder for more targeted exception handling.***
    END;
 
   FUNCTION f_conc_req_param_md (
     p_concurent_request_id IN NUMBER) 
   RETURN APPS.XXFND_CR_MD_PARAM_TABLE_TYPE
    --* Description: 
    --*    This function returns a row for each parameter of a
	--*    to a concurrent request.

    --* Inputs:
    --*    p_concurent_request_id: Concurrent Request ID
    --* Outputs:
    --*    APPS.XXFND_CR_MD_PARAM_TABLE_TYPE
   IS
        /* Local Constants*/
        c_function_name VARCHAR2 (30) := 'f_conc_req_param_md';
        c_sql VARCHAR2(32000);  --Holds generic SQL statement
        c_where_clause_conc_req_id VARCHAR2 (150) := Q'[ AND request_id = ]';  --Base WHERE clause, pertaining to the Concurrent Request ID for the dynamic SQL statement.

        /* Local Variables */
        l_concurrent_request_id NUMBER;
        l_result_temp APPS.XXFND_CR_MD_PARAM_TABLE_TYPE := APPS.XXFND_CR_MD_PARAM_TABLE_TYPE();  -- Holds the result of the dynamic sql query
        
        /* Local variables for dynamic SQL */
        l_dynamic_sql VARCHAR2(32000);  --Holds dynamic SQL statement
        l_where_clause_conc_req_id VARCHAR2 (150);  --Component of WHERE clause, pertaining to the Organization ID for the dynamic SQL statement.
        
        /* Cursors*/
        TYPE t_ref_cursor IS REF CURSOR;-- SYS_REFCURSOR;
        cur_dynamic t_ref_cursor;
 
    BEGIN
        IF c_debug_level = 10 THEN
            fnd_file.put_line(which => fnd_file.log, buff => c_output_header || c_function_name);
            dbms_output.put_line(c_output_header || c_function_name); 
        END IF;
       
        /* Prepare Parameters*/
        l_concurrent_request_id := p_concurent_request_id;
        
        /* Build components of the WHERE clause.  */
        l_where_clause_conc_req_id := c_where_clause_conc_req_id || l_concurrent_request_id;
        
        IF c_debug_level = 10 THEN
            fnd_file.put_line( fnd_file.log, 'WHERE clause components built.');
            dbms_output.put_line('WHERE clause components built.'); 
        END IF;
  
        IF c_debug_level = 10 THEN
            fnd_file.put_line( fnd_file.log, 'Begin build of dynamic SQL.' );
            dbms_output.put_line('Begin build of dynamic SQL.'); 
        END IF;
      
    /* Build a dynamic SQL Statement.  Note the use of the alternative quoting 
       mechanism (Q') using "[" as the quote_delimiter.  This is to make the 
       use of single quotes in the variable clearer. Note that bind variables 
       are not, and cannot, be used because the view/table names will be 
       different across orgs. (Bind variables can't be used to specify table or
       view names.) */
    l_dynamic_sql := Q'[
/* For a concurrent request, list each enabled parameter for the associated
   concurrent program.  For each parameter, return the corresponding 
   argument value from the concurrent request record.
   Technical note: There are 25 fixed argument columsn in the concurrent request 
   record.  
   */
WITH concurrent_program_paramaters
	/* Get all of the enabled parameters for a concurrent program.*/
AS (
	SELECT request_id
		,column_seq_num
		,form_left_prompt
		,parameter_order_num
		,validation_type
		,flex_value_set_name
	FROM (
		SELECT fcrsv.request_id
			,fdfcuv.column_seq_num
			,fdfcuv.end_user_column_name
			,fdfcuv.form_left_prompt
			,fdfcuv.application_column_name
			,ffvs.flex_value_set_name
            ,ffvs.validation_type
            ,flv2.meaning validation_meaning
			/*Determine the relative order of the parameters as indicated by the Column Sequence.
    This is importnat since we use this column for a join late on.*/
			,row_number() OVER (
				ORDER BY fdfcuv.column_seq_num
				) parameter_order_num
		FROM fnd_conc_req_summary_v fcrsv
		INNER JOIN fnd_concurrent_programs fcp ON (fcrsv.concurrent_program_id = fcp.concurrent_program_id)
		INNER JOIN fnd_concurrent_programs_tl fcpl ON (fcp.concurrent_program_id = fcpl.concurrent_program_id)
		INNER JOIN fnd_application_vl fav ON (fav.application_id = fcp.application_id)
		INNER JOIN fnd_descr_flex_col_usage_vl fdfcuv ON (
				fdfcuv.descriptive_flexfield_name = '$SRS$.' || fcp.
				concurrent_program_name
				)
		INNER JOIN fnd_flex_value_sets ffvs ON (ffvs.flex_value_set_id =  fdfcuv.flex_value_set_id)
		LEFT JOIN fnd_lookup_values flv2 ON (flv2.lookup_type = 'SEG_VAL_TYPES' AND flv2.lookup_code = ffvs.validation_type AND flv2.LANGUAGE = USERENV('LANG'))
		WHERE fcpl.language = 'US'
			AND fdfcuv.enabled_flag = 'Y'
			]' || l_where_clause_conc_req_id || Q'[
		)
	)
	,concurrent_req_argument_values
	/* Return a separate row for each argument in a concurrent request. */
AS (
	SELECT request_id
		,to_number(parameter_order_char) parameter_order_num
		,parameter_value
	FROM (
		/* Get the value for every argument field for the concurrent request.
   There are 25 such argument fields. */
		SELECT request_id
			,argument1
			,argument2
			,argument3
			,argument4
			,argument5
			,argument6
			,argument7
			,argument8
			,argument9
			,argument10
			,argument11
			,argument12
			,argument13
			,argument14
			,argument15
			,argument16
			,argument17
			,argument18
			,argument19
			,argument20
			,argument21
			,argument22
			,argument23
			,argument24
			,argument25
		FROM fnd_concurrent_requests
		WHERE 1 = 1
		]' || l_where_clause_conc_req_id || Q'[
		)
	/* "Unpivot" each argument column to be a separate row, containing the value of the argument. 
	   Rename the column to be just the "number" of the argument (it will converted to a actual
	   number later).*/
	UNPIVOT INCLUDE NULLS(parameter_value FOR parameter_order_char IN (
				argument1 AS '1'
				,argument2 AS '2'
				,argument3 AS '3'
				,argument4 AS '4'
				,argument5 AS '5'
				,argument6 AS '6'
				,argument7 AS '7'
				,argument8 AS '8'
				,argument9 AS '9'
				,argument10 AS '10'
				,argument11 AS '11'
				,argument12 AS '12'
				,argument13 AS '13'
				,argument14 AS '14'
				,argument15 AS '15'
				,argument16 AS '16'
				,argument17 AS '17'
				,argument18 AS '18'
				,argument19 AS '19'
				,argument20 AS '20'
				,argument21 AS '21'
				,argument22 AS '22'
				,argument23 AS '23'
				,argument24 AS '24'
				,argument25 AS '25'
				))
	)
/* Bring the two subqueries together: */
SELECT XXFND_CR_MD_PARAM_ROW_TYPE(
     cpp.request_id
	,cpp.column_seq_num --parameter sequence
	,cpp.parameter_order_num
	,cpp.form_left_prompt
	,cpp.validation_type
	,cpp.flex_value_set_name
	,crav.parameter_value
	,NULL --Parameter Value Meaning: need to find a way to translate the value in the argument fields of the concurrent request record to the user-firendly meaning, via the associated Value Set (flex_value_set_name) for the parameter.
    )
FROM concurrent_program_paramaters cpp
LEFT JOIN concurrent_req_argument_values crav ON (
		cpp.request_id = crav.request_id
		AND cpp.parameter_order_num = crav.parameter_order_num
		)
ORDER BY cpp.column_seq_num
		]'
;      
      
      /* Write the SQL statement to the log file so that it can be debugged should issues arise. */
      IF c_debug_level = 10 THEN dbms_output.put_line(l_dynamic_sql);
          fnd_file.put_line( fnd_file.log, 'SQL Statement in variable "l_dynamic_sql":' );
          fnd_file.put_line( fnd_file.log, l_dynamic_sql ); 
      END IF;

      /* Execute the dynamic SQL statement. */
      EXECUTE IMMEDIATE l_dynamic_sql BULK COLLECT INTO l_result_temp;
      
      IF c_debug_level = 10 THEN 
        dbms_output.put_line('Rows returned: ' || l_result_temp.COUNT);
        fnd_file.put_line( fnd_file.log, 'Rows returned: ' || l_result_temp.COUNT);   
        
        dbms_output.put_line('Request ID: ' || fnd_global.conc_request_id);
        fnd_file.put_line( fnd_file.log, 'Request ID: ' || fnd_global.conc_request_id);     
        
        dbms_output.put_line(c_output_footer);
        fnd_file.put_line( fnd_file.log, c_output_footer); 
      END IF;
 
      RETURN l_result_temp;
    
      EXCEPTION
        WHEN OTHERS THEN
          /* If function was called in the context of a concurrent program, 
          write the error to the log file.  Otherwise write to dbms_output. */
          IF fnd_global.conc_request_id <> -1 THEN
            IF c_debug_level = 10 THEN fnd_file.put_line( fnd_file.log, 'Unhandled exception: ' || SQLERRM ); END IF;
          ELSE
            DBMS_OUTPUT.put_line(SQLERRM);      
          END IF;
          
          /* Return*/
          RETURN NULL;--***Just did this as place holder for more targeted exception handling.***
    END;
END xxfnd_conc_req_metadata_rpt;
/  