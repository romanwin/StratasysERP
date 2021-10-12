CREATE OR REPLACE PACKAGE xxwip_simplicity_jobs_trx_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: xxwip_simplicity_jobs_trx_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxwip_simplicity_jobs_trx_pkg
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: Simplicity Interface
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  31/08/09                  Initial Build

  -- 1.1   13.4.11     yuval tal         add file_name to process_interface and  call_bpel_process
  -- 1.2   16.5.2012   yuval tal         process_interface : add trim in item search select
  ---------------------------------------------------------------------------

  PROCEDURE process_interface(errbuf       OUT VARCHAR2,
		      retcode      OUT VARCHAR2,
		      p_job_number IN VARCHAR2,
		      p_operation  IN VARCHAR2,
		      p_file_name  IN VARCHAR2);

  PROCEDURE call_bpel_process(p_job_number IN VARCHAR2,
		      p_directory  IN VARCHAR2,
		      p_file_name  IN VARCHAR2,
		      p_status     OUT VARCHAR2,
		      p_message    OUT VARCHAR2);
END xxwip_simplicity_jobs_trx_pkg;
/
