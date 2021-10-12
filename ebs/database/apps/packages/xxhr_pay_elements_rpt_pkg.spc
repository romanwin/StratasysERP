create or replace package xxhr_pay_elements_rpt_pkg is
  
--------------------------------------------------------------------
--  name:            XXHR_PAY_ELEMENTS_RPT_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   06/06/2012 15:34:52
--------------------------------------------------------------------
--  purpose :        REP499 - Elements Reports
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  06/06/2012  Dalit A. Raviv    initial build
--------------------------------------------------------------------     
  
  -- global var for xmlp report params
  P_TOKEN        varchar2(50)  := null;
  P_PERIOD_DATE  varchar2(50)  := null;
	P_DEPT         varchar2(240) := null;			
	P_DIVISION     varchar2(240) := null;			
	P_JOB_ID       number        := null;					
	P_POSITION_ID  number        := null;	
  P_ELEMENT_NAME varchar2(240) := null;             
  
  --------------------------------------------------------------------
  --  name:            beforereport
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   06/06/2012 15:34:52
  --------------------------------------------------------------------
  --  purpose :        REP499 - Elements Reports
  --                   1) set security token - open encrypt data
  --                   2) set session param - period date
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  function beforereport (--p_period_date    in varchar2,
                         p_token in varchar2) return boolean;
  
  --------------------------------------------------------------------
  --  name:            afterreport
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   06/06/2012 15:34:52
  --------------------------------------------------------------------
  --  purpose :        REP499 - Elements Reports
  --                   send report output as mail to user that run the report.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                        
  function afterreport return boolean;  

  --------------------------------------------------------------------
  --  name:            get_is_last_element_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   12/07/2012 
  --------------------------------------------------------------------
  --  purpose :        Procedure that handel Run element report and send output 
  --                   to user who run the mail
  --  in params:       
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/07/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------     
  function get_is_last_element_date (p_assignment_id   in number,
                                     p_element_type_id in number,
                                     p_start_date      in date) return number;

  --------------------------------------------------------------------
  --  name:            Run_element_rpt
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   06/06/2012
  --------------------------------------------------------------------
  --  purpose :        Procedure that handel Run element report and send output 
  --                   to user who run the mail
  --  in params:       p_assignment_id
  --                   p_element_type_id
  --                   p_Input_Name
  --                   p_input_value
  --  Return:          max_effective_end_date by ass_id, element_type_id,
  --                   input_name and input val
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/06/2012  Dalit A. Raviv    initial build
  ------------------------------------------------------------------- 
  function get_max_end_date (p_assignment_id   in number,
                             p_element_type_id in number,
                             p_Input_Name      in varchar2,
                             p_input_value     in varchar2 ) return date;

  --------------------------------------------------------------------
  --  name:            Run_element_rpt
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   06/06/2012
  --------------------------------------------------------------------
  --  purpose :        Procedure that handel Run element report and send output 
  --                   to user who run the mail
  --  in params:       p_security_token
  --                   p_period_date
  --                   p_department
  --                   p_division
  --                   p_job_id
  --                   p_position_id   
  --                   retcode      - 0    success other fialed
  --                   errbuf       - null success other fialed
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  procedure Run_element_rpt (errbuf          out varchar2,
                             retcode         out varchar2,
                             p_token         in  varchar2,
                             p_period_date   in  varchar2,
                             p_department    in  varchar2,
                             p_division      in  varchar2,
                             p_job_id        in  number,
                             p_position_id   in  number
                            );

end XXHR_PAY_ELEMENTS_RPT_PKG;
/
