CREATE OR REPLACE PACKAGE xxobjt_wip_job_number_intf_pkg AS
  PROCEDURE p_extract_jobs(errbuf  OUT VARCHAR2,
		   retcode OUT NUMBER);

  PROCEDURE p_wip_job_name_change(errbuf  OUT VARCHAR2,
		          retcode OUT NUMBER);

END xxobjt_wip_job_number_intf_pkg;
/
