CREATE OR REPLACE PACKAGE XXHR_PAY_ELEMENTS_PKG IS

--------------------------------------------------------------------
--  name:            XXHR_PAY_ELEMENTS_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   13/12/2010 10:30:11 PM
--------------------------------------------------------------------
--  purpose :        HR project - Handle upload of elements from Har-Gal to oracle
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  13/12/2010  Dalit A. Raviv    initial build
--------------------------------------------------------------------   
  TYPE t_elements_rec IS RECORD
     (employee_number          varchar2(30), 
      effective_start_date     date, 
      effective_end_date       date, 
      element_code             varchar2(10),
      element_name             varchar2(30),
      entry_value1             varchar2(250),
      entry_value2             varchar2(250),
      entry_value3             varchar2(250),
      entry_value4             varchar2(250),
      entry_value5             varchar2(250),
      entry_value6             varchar2(250)
     );
     
  TYPE t_elements_log_rec IS RECORD   
     (batch_id                 number,        
      entity_id                number,  
      employee_number          varchar2(30), 
      effective_start_date     date, 
      effective_end_date       date, 
      element_code             varchar2(10),
      element_name             varchar2(30),
      status                   varchar2(30),
      log_code	               varchar2 (5),
      log_message	             varchar2 (2500)
     );     

  --------------------------------------------------------------------
  --  name:            delete_element_test
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/01/2011 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        
  --  in params:       
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/01/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE delete_element_test;

  --------------------------------------------------------------------
  --  name:            update_element
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        
  --  in params:       
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/12/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE update_element_test;
  
  --------------------------------------------------------------------
  --  name:            create_element_test
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        
  --  in params:       
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/12/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE create_element_test;
  
  --------------------------------------------------------------------
  --  name:            get_element_type_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        
  --  in params:       
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/12/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION get_element_type_id(p_element_name         IN VARCHAR2,
                               p_effective_start_date IN DATE) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_element_link_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        
  --  in params:       
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/12/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION get_element_link_id(p_assignment_id        IN NUMBER,
                               p_element_type_id      IN NUMBER,
                               p_effective_start_date IN DATE) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_business_group_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Get bussiness group id      
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_business_group_id RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_element_entry_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   15/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose:         get element entry id   by element name assignment id
  --                   and effective date.
  --  return:             
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_element_entry_id(p_element_name     pay_element_types_f.element_name%TYPE,
                                 p_assignment_id    per_all_assignments_f.assignment_id%TYPE,
                                 p_effective_date   DATE,
                                 p_obj_ver_no       OUT pay_element_entries_f.object_version_number%TYPE,
                                 p_start_date       OUT DATE,
                                 p_element_entry_id OUT pay_element_entries.element_entry_id%TYPE);
   
  --------------------------------------------------------------------
  --  name:            get_element_name_by_code
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   04/02/2011 
  --------------------------------------------------------------------
  --  purpose:         get element entry name by the hargal code.
  --                   we keep at attribute 2 of element type table 
  --                   the hargal code
  --  return:          element name   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/02/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_element_name_by_code (p_hargal_code in varchar2) return varchar2;
   
  --------------------------------------------------------------------
  --  name:            get_element_name_is_valid
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   04/02/2011 
  --------------------------------------------------------------------
  --  purpose:         get_element_name_is_valid 
  --                   check the element name is valid at oracle
  --                   
  --  return:          Y -> valid 
  --                   N -> not valid  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/02/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_element_name_is_valid (p_element_name in varchar2) return varchar2; 
  
  --------------------------------------------------------------------
  --  name:            get_emp_ele_exist_for_period
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   04/02/2011 
  --------------------------------------------------------------------
  --  purpose:         get_emp_ele_exist_for_period - check that this elemnet
  --                   at this date exist(UPDATE) or not exist (CREATE) record
  --                   
  --  return:          Y - element exist - need to update element for the person
  --                   N - element do not exist - need to create element for the person 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/02/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_emp_ele_exist_for_period (p_element_name   in varchar2,
                                         p_effective_date in date) return varchar2;
  
  --------------------------------------------------------------------
  --  name:            delete_det_interface
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   04/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        delete rows from xxhr_element_det_interface tbl
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  04/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure delete_det_interface (errbuf   out varchar2,
                                  retcode  out varchar2) ;
                                         
  --------------------------------------------------------------------
  --  name:            upload_data
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   29/12/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        upload data to xxhr_element_det_interface table
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  29/12/2009  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure upload_data (p_location in  varchar2,
                         p_filename in  varchar2,
                         p_err_code out varchar2,
                         p_err_msg  out varchar2) ;
  
  --------------------------------------------------------------------
  --  name:            process_data
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   02/01/2011 
  --------------------------------------------------------------------
  --  purpose:         Program that will process the data that just upload
  --                   to temp table
  --  In  Params:      
  --  Out Params:      errbuf     null if success , WARNING if only 15 err rows
  --                              and ERROR if more then 15 rows are in err. 
  --                   retcode    null if success , 1 if only 15 err rows
  --                              and 2 if more then 15 rows are in err.   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/01/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  procedure process_data (p_emp_num  in  varchar2,
                          p_err_code out varchar2,
                          p_err_msg  out varchar2);
                                 
  --------------------------------------------------------------------
  --  name:            delete_element
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/01/2011 
  --------------------------------------------------------------------
  --  purpose:         this procedure look for the elements that need to be closed.
  --                   person had 2 elements XX, YY and this upload only one need to 
  --                   be upload, for example XX. the procedure will expose the element 
  --                   YY and close it. old population minus new population will give 
  --                   the elements pop that need to be close.
  --                   closing element use delete element API.
  --  In  Params:      p_employee_number
  --                   p_emp_assignment_id
  --  Out Params:      errbuf     null if success , error string if error
  --                   retcode    null if success , 1 error.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/01/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure delete_element (p_employee_number      in  varchar2,
                            p_effective_start_date in  date,
                            --p_entity_id            in  number,
                            p_batch_id             in  number,
                            p_err_code             out varchar2,
                            p_err_msg              out varchar2);
  
  --------------------------------------------------------------------
  --  name:            create_element
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/01/2011 
  --------------------------------------------------------------------
  --  purpose:         this procedure create_element .
  --                   
  --  In  Params:      p_employee_number
  --                   p_element_name
  --                   p_effective_date
  --                   p_entity_id
  --                   p_batch_id
  --                   p_value1, p_value2, p_value3, _value4, p_value5, p_value6
  --  Out Params:      errbuf     null if success , error string if error
  --                   retcode    null if success , 1 error.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/01/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure create_element (p_employee_number  in  varchar2,
                            p_element_name     in  varchar2,
                            p_effective_date   in  date,
                            p_entity_id        in  number,
                            p_batch_id         in  number,
                            p_value1           in  number,
                            p_value2           in  number   default null,
                            p_value3           in  number   default null,
                            p_value4           in  varchar2 default null,
                            p_value5           in  varchar2 default null,
                            p_value6           in  varchar2 default null,
                            p_err_code         out varchar2,
                            p_err_msg          out varchar2);
  
  --------------------------------------------------------------------
  --  name:            update_element
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/01/2011 
  --------------------------------------------------------------------
  --  purpose:         this procedure update_element .
  --                   
  --  In  Params:      p_employee_number
  --                   p_element_name
  --                   p_effective_date
  --                   p_entity_id
  --                   p_batch_id
  --                   p_value1, p_value2, p_value3, _value4, p_value5, p_value6
  --  Out Params:      errbuf     null if success , error string if error
  --                   retcode    null if success , 1 error.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/01/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure update_element (p_employee_number  in  varchar2,
                            p_element_name     in  varchar2,
                            p_effective_date   in  date,
                            p_entity_id        in  number,
                            p_batch_id         in  number,
                            p_value1           in  number,
                            p_value2           in  number   default null,
                            p_value3           in  number   default null,
                            p_value4           in  varchar2 default null,
                            p_value5           in  varchar2 default null,
                            p_value6           in  varchar2 default null,
                            p_err_code         out varchar2,
                            p_err_msg          out varchar2);
  
  procedure test_clob (p_clob out clob) ;
  
  --------------------------------------------------------------------
  --  name:            load_elements_data
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   27/12/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose:         Program that will read CSV file and load the data 
  --                   From Har-Gal to Oracle.
  --  In  Params:      p_location - the location where to get the file to load from
  --                   p_filename - filename
  --                   p_token    - for the security 
  --                   p_token2   - for the security
  --  Out Params:      errbuf     null if success , WARNING if only 15 err rows
  --                              and ERROR if more then 15 rows are in err. 
  --                   retcode    null if success , 1 if only 15 err rows
  --                              and 2 if more then 15 rows are in err.   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                              
  PROCEDURE load_elements_data (errbuf             out varchar2,
                                retcode            out varchar2,
                                p_location         in  varchar2,
                                p_filename         in  varchar2,
                                p_token1           in  varchar2,
                                --p_token2           in  varchar2,
                                p_debug            in  varchar2 default 'N',
                                p_employee_number  in  varchar2);                                                               

END xxhr_pay_elements_pkg;
/

