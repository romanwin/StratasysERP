CREATE OR REPLACE PACKAGE xxfnd_purge_pkg IS
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
		        p_keep_days_arc NUMBER);
END xxfnd_purge_pkg;
/
