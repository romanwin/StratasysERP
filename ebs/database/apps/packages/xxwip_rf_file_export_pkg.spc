CREATE OR REPLACE PACKAGE xxwip_rf_file_export_pkg IS
  --------------------------------------------------------------------
  --  name:            xxwip_rf_file_export_pkg
  --  create by:       yuval tal
  --  Revision:
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :        support  bpel rf process
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  12.11.14    yuval tal       CHG0032304  modify call_rf_bpel_process

  PROCEDURE call_rf_bpel_process(errbuf         OUT VARCHAR2,
		         retcode        OUT NUMBER,
		         p_job_number   IN VARCHAR2,
		         p_lot          IN VARCHAR2,
		         p_organization IN VARCHAR2,
		         p_destination  IN VARCHAR2);

  PROCEDURE call_rf_oic_process(errbuf         OUT VARCHAR2,
		        retcode        OUT NUMBER,
		        p_job_number   IN VARCHAR2,
		        p_lot          IN VARCHAR2,
		        p_organization IN VARCHAR2,
		        p_destination  IN VARCHAR2);
END xxwip_rf_file_export_pkg;
/
