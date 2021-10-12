CREATE OR REPLACE PACKAGE BODY xxfnd_purge_pkg IS
  --------------------------------------------------------------------
  --  name:               XXFND_PURGE_PKG
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      13.07.2015
  --  Purpose :           CHG0035887 - Archive Purge FND Concurrent Requests table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   13.07.2015    Michal Tzvik    initial build
  --  1.1  16.2.17       yuval tal        INC0087610  archive_concurrents  Add purge to concurrent XX FND Archive Concurrents 
  -----------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:               archive_concurrents
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      13.07.2015
  --------------------------------------------------------------------
  --  purpose :           Archive concurrent requests information
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  13.07.2015    Michal Tzvik     CHG0035887 - initial build
  --  1.1  16.2.17       yuval tal        INC0087610   Add p_keep_days_arc parameter to keep X days of archive data 
  --------------------------------------------------------------------
  PROCEDURE archive_concurrents(errbuf          OUT VARCHAR2,
		        retcode         OUT VARCHAR2,
		        p_days_back     NUMBER,
		        p_keep_days_arc NUMBER) IS
    l_rowcount NUMBER;
  
  BEGIN
    errbuf  := '';
    retcode := '0';
  
    IF p_days_back IS NULL THEN
      errbuf  := 'p_days_back parameter is required.';
      retcode := '1';
      RETURN;
    END IF;
  
    fnd_file.put_line(fnd_file.log, '');
    fnd_file.put_line(fnd_file.log, 'Parameters:');
    fnd_file.put_line(fnd_file.log, '------------');
    fnd_file.put_line(fnd_file.log, 'p_days_back: ' || p_days_back);
    fnd_file.put_line(fnd_file.log, 'p_keep_days_arc: ' || p_days_back);
  
    fnd_file.put_line(fnd_file.log, '------------');
    fnd_file.put_line(fnd_file.log, '');
  
    --INC0087610
    BEGIN
      LOOP
        DELETE FROM xxfnd_conc_req_summary_arc t
        WHERE  request_date < SYSDATE - p_keep_days_arc
        AND    rownum < 10000;
      
        fnd_file.put_line(fnd_file.log, 'rows deleted : ' || SQL%ROWCOUNT);
        EXIT WHEN nvl(SQL%ROWCOUNT, 0) = 0;
        COMMIT;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        errbuf  := 'Unexpected error in xxfnd_purge_pkg.archive_concurrents: ' ||
	       SQLERRM;
        retcode := '2';
      
    END;
    --
    COMMIT;
  
    fnd_file.put_line(fnd_file.log, 'Start merge : ');
    MERGE INTO xxfnd_conc_req_summary_arc xcrsa
    USING (SELECT *
           FROM   fnd_conc_req_summary_v fcrsv
           WHERE  fcrsv.request_date <= (trunc(SYSDATE) - p_days_back)) h
    ON (xcrsa.request_id = h.request_id)
    WHEN MATCHED THEN
      UPDATE
      SET    xcrsa.row_id                        = h.row_id,
	 xcrsa.phase_code                    = h.phase_code,
	 xcrsa.status_code                   = h.status_code,
	 xcrsa.priority_request_id           = h.priority_request_id,
	 xcrsa.priority                      = h.priority,
	 xcrsa.request_date                  = h.request_date,
	 xcrsa.requested_by                  = h.requested_by,
	 xcrsa.requested_start_date          = h.requested_start_date,
	 xcrsa.hold_flag                     = h.hold_flag,
	 xcrsa.has_sub_request               = h.has_sub_request,
	 xcrsa.is_sub_request                = h.is_sub_request,
	 xcrsa.update_protected              = h.update_protected,
	 xcrsa.queue_method_code             = h.queue_method_code,
	 xcrsa.responsibility_application_id = h.responsibility_application_id,
	 xcrsa.responsibility_id             = h.responsibility_id,
	 xcrsa.save_output_flag              = h.save_output_flag,
	 xcrsa.last_update_date              = h.last_update_date,
	 xcrsa.last_updated_by               = h.last_updated_by,
	 xcrsa.last_update_login             = h.last_update_login,
	 xcrsa.printer                       = h.printer,
	 xcrsa.print_style                   = h.print_style,
	 xcrsa.parent_request_id             = h.parent_request_id,
	 xcrsa.controlling_manager           = h.controlling_manager,
	 xcrsa.actual_start_date             = h.actual_start_date,
	 xcrsa.actual_completion_date        = h.actual_completion_date,
	 xcrsa.completion_text               = h.completion_text,
	 xcrsa.argument_text                 = h.argument_text,
	 xcrsa.implicit_code                 = h.implicit_code,
	 xcrsa.request_type                  = h.request_type,
	 xcrsa.program_application_id        = h.program_application_id,
	 xcrsa.concurrent_program_id         = h.concurrent_program_id,
	 xcrsa.program_short_name            = h.program_short_name,
	 xcrsa.execution_method_code         = h.execution_method_code,
	 xcrsa.enabled                       = h.enabled,
	 xcrsa.program                       = h.program,
	 xcrsa.fcp_printer                   = h.fcp_printer,
	 xcrsa.fcp_print_style               = h.fcp_print_style,
	 xcrsa.fcp_required_style            = h.fcp_required_style,
	 xcrsa.requestor                     = h.requestor,
	 xcrsa.user_print_style              = h.user_print_style,
	 xcrsa.description                   = h.description,
	 xcrsa.user_concurrent_program_name  = h.user_concurrent_program_name
    WHEN NOT MATCHED THEN
      INSERT
      VALUES
        (h.row_id,
         h.request_id,
         h.phase_code,
         h.status_code,
         h.priority_request_id,
         h.priority,
         h.request_date,
         h.requested_by,
         h.requested_start_date,
         h.hold_flag,
         h.has_sub_request,
         h.is_sub_request,
         h.update_protected,
         h.queue_method_code,
         h.responsibility_application_id,
         h.responsibility_id,
         h.save_output_flag,
         h.last_update_date,
         h.last_updated_by,
         h.last_update_login,
         h.printer,
         h.print_style,
         h.parent_request_id,
         h.controlling_manager,
         h.actual_start_date,
         h.actual_completion_date,
         h.completion_text,
         h.argument_text,
         h.implicit_code,
         h.request_type,
         h.program_application_id,
         h.concurrent_program_id,
         h.program_short_name,
         h.execution_method_code,
         h.enabled,
         h.program,
         h.fcp_printer,
         h.fcp_print_style,
         h.fcp_required_style,
         h.requestor,
         h.user_print_style,
         h.description,
         h.user_concurrent_program_name);
  
    l_rowcount := SQL%ROWCOUNT;
    fnd_file.put_line(fnd_file.log, l_rowcount || ' lines were processed.');
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Unexpected error in xxfnd_purge_pkg.archive_concurrents: ' ||
	     SQLERRM;
      retcode := '2';
  END archive_concurrents;

END xxfnd_purge_pkg;
/
