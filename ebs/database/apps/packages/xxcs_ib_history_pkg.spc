create or replace package xxcs_ib_history_pkg is

--------------------------------------------------------------------
--  name:            XXCS_IB_HISTORY
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   07/05/2012 09:27:10
--------------------------------------------------------------------
--  purpose :        REP266 - MTXX Reports - Disco report
--                   Need to support upgrade items at MTXX reports.
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  07/05/2012  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  TYPE t_hist_rec IS RECORD
      (instance_id       number, 
       party_id          number,
       inventory_item_id number,
       from_date         date,
       to_date           date);

  --------------------------------------------------------------------
  --  name:            main_history
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   1) check if there is old record if yes need to update end date.
  --                   2) insert new row
  --                   3) update party details, item details and IB active_end_date
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main_history ( errbuf   out varchar2,
                           retcode  out number,
                           p_date   in  varchar2);
                           
  --------------------------------------------------------------------
  --  name:            apd_additional_details
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   add party, item, and IB active_end_date details
  --                   to each row.
  --                   Process flag give indication that these are new rows to process on
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                        
  procedure apd_additional_details (p_err_code    out number,
                                    p_err_desc    out varchar2);
                                    
  --------------------------------------------------------------------
  --  name:            update_history
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   before insert new row the program look if this instance 
  --                   have allready row at XXCS_IB_HISTORY table that have no end_date
  --                   in this case we need to close the last row (end_date is null)
  --                   with current row start date minus 1 sec.
  --                   Afetr that we can insert the new row.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_history(p_end_date    in  date,
                           p_instance_id in  number,
                           p_err_code    out number,
                           p_err_desc    out varchar2); 
  
  --------------------------------------------------------------------
  --  name:            insert_history
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   insert new row to XXCS_IB_HISTORY table by  
  --                   cursor population
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure insert_history(p_hist_rec   in  t_hist_rec,
                           p_err_code   out number,
                           p_err_desc   out varchar2); 
  
  --------------------------------------------------------------------
  --  name:            get_last_item_per_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   This function look for the nearest item_id
  --                   by instance_id and date.
  --                   because party history held at one table and item history
  --                   at enother we need to find what was the item when the party changed.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                          
  function get_last_item_per_date (p_instance_id in number,
                                   p_date        in date) return number;
  
  --------------------------------------------------------------------
  --  name:            get_last_party_per_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   This function look for the nearest party_id
  --                   by instance_id and date.
  --                   because party history held at one table and item history
  --                   at enother we need to find what was the party when the item changed.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                                  
  function get_last_party_per_date (p_instance_id in number,
                                    p_date        in date) return number;                                    
  
  --------------------------------------------------------------------
  --  name:            get_install_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  function get_install_date (p_instance_id in number,
                             p_start_date  in date,
                             p_end_date    in date) return date ;
  
  --------------------------------------------------------------------
  --  name:            upd_install_date_first_run
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   Help to run programe with each day a parameter.
  --                   USE ONLY FOR DUBUG OR FIRST RUN AT PRODUCTION
  --                   will correct install_date and update it to Hist tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                          
  procedure upd_install_date_first_run (p_err_code    out number,
                                        p_err_desc    out varchar2);
  
  --------------------------------------------------------------------
  --  name:            install_date_remainder_to_fix
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   Help to run programe with each day a parameter.
  --                   USE ONLY FOR DUBUG OR FIRST RUN AT PRODUCTION
  --                   will correct install_date after update that was made
  --                   with procedure upd_install_date_first_run
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure install_date_remainder_to_fix (p_err_code    out number,
                                           p_err_desc    out varchar2);                                                                     
  
  -------------------------------
  function alter_db_hidden_parameter return number; 
  
  --------------------------------------------------------------------
  --  name:            
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   23/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure upd_changes_install_date (p_err_code    out number,
                                      p_err_desc    out varchar2); 
  
  
  --------------------------------------------------------------------
  --  name:            run_prog
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   Help to run programe with each day a parameter.
  --                   USE ONLY FOR DUBUG
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                                     
  procedure run_prog;                                                                                          
  
end XXCS_IB_HISTORY_PKG;
/
