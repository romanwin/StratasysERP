create or replace package XXOBJT_WIP_JOBS_TRX is

Procedure Process_Interface(errbuf            out varchar2,
                            retcode           out varchar2,
                            P_Job_Number      In  Varchar2);

end XXOBJT_WIP_JOBS_TRX;
/

