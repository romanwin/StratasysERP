CREATE OR REPLACE PACKAGE xxhr_oa2ad_pkg IS

  --------------------------------------------------------------------
  --  name:            XXHR_AD_INTERFACE_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.3 
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   This Package handle: Active directory interface
  --                                        Position changes interface
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  --  1.1  14/02/2012  Dalit A. raviv    Add handling of changed position interface
  --                                     new procedure - insert_position_diff
  --                                     new procedure - populate_diff_position
  --                                     new procedure - update_diff_position_int
  --                                     new procedure - position_send_mail
  -- 1.2   19.11.2012  yuval tal         new procedure - get_concate_position_hierarchy
  -- 1.3   09/02/2014  Dalit A. Raviv    Handle change in Organization name and not id
  -------------------------------------------------------------------- 

  TYPE t_person_rec IS RECORD(
    person_id              NUMBER,
    user_person_type       VARCHAR2(240),
    location_id            NUMBER,
    position_id            NUMBER,
    organization_id        NUMBER,
    --  1.3  09/02/2014  Dalit A. Raviv
    organization_name      varchar2(150),
    mobile_number          VARCHAR2(60),
    supervisor_id          NUMBER,
    period_terminate_date  DATE,
    grade_id               NUMBER,
    office_phone_extension VARCHAR2(150),
    office_phone_full      VARCHAR2(150),
    office_fax             VARCHAR2(150));

  -- Dalit A. Raviv 14/02/2012   
  TYPE t_position_diff_rec IS RECORD(
    person_id              NUMBER,
    user_person_type       VARCHAR2(240),
    position_id            NUMBER,
    organization_id        NUMBER,
    organization_name      VARCHAR2(150),
    supervisor_id          NUMBER,
    send_mail              VARCHAR2(2),
    log_msg                VARCHAR2(500),
    position_info          VARCHAR2(1000));

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   Procedure will call from concurrent program and will run once a day.
  --                   1) check that there are rows at table - handle first time run
  --                   2) get max batch id to get last population to compare too
  --                   3) populate interface with today all Objet persons data
  --                   4) populate diff interface table
  --                   5) send mail to IT (HELPDESK)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE main(errbuf OUT VARCHAR2, retcode OUT NUMBER);

  --------------------------------------------------------------------
  --  name:            send_mail
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   Send mail 
  --                   from diff interface tbl find population to send mail to IT group (Helpdesk)                
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/10/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE send_mail(errbuf OUT VARCHAR2, retcode OUT NUMBER);

  --------------------------------------------------------------------
  --  name:            update_diff_person_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   23/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   update XXHR_DIFF_PERSONS_INTERFACE table with process_mode
  --                   and log messages
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/10/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE update_diff_person_interface(errbuf              OUT VARCHAR2,
                                         retcode             OUT NUMBER,
                                         p_to_process_mode   IN VARCHAR2,
                                         p_from_process_mode IN VARCHAR2,
                                         p_log_message       IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            delete_person_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/11/2011 
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   delete interface table data that is old then 4 months.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/11/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE delete_person_interface(errbuf  OUT VARCHAR2,
                                    retcode OUT NUMBER);

  --------------------------------------------------------------------
  --  name:            delete_diff_person_interface
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/11/2011 
  --------------------------------------------------------------------
  --  purpose :        CUST460 - Active directory interface
  --
  --                   delete interface table data that is old then 45 days.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/11/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE delete_diff_person_interface(errbuf  OUT VARCHAR2,
                                         retcode OUT NUMBER);

  --------------------------------------------------------------------
  --  name:            update_diff_position_int
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/02/2012 
  --------------------------------------------------------------------
  --  purpose :        CUST482 - Employee Position Changed - notify Oracle_Operations - Alert
  --
  --                   update XXHR_EMP_CHANGE_POSITION_INT table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/02/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_diff_position_int(errbuf           OUT VARCHAR2,
                                     retcode          OUT NUMBER,
                                     p_to_send_mail   IN VARCHAR2, -- P
                                     p_from_send_mail IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            send_mail_position
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/02/2012 
  --------------------------------------------------------------------
  --  purpose :        CUST482 - Employee Position Changed - notify Oracle_Operations - Alert
  --
  --                   send mail oo employees that changed positions to oracle_operations
  --                   they need to change in position heirarchy
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/02/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE send_mail_position(errbuf OUT VARCHAR2, retcode OUT NUMBER);
  --------------------------------------------------------------------
  --  name:            get_concate_position_Hierarchy
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   19.11.2012
  --------------------------------------------------------------------
  --  purpose :        CUST482 /CR418 - Employee Position Changed - get position  location in Hierarchys
  --
  --                   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19.11.2012  yuval tal          initial build

  --------------------------------------------------------------------
  FUNCTION get_concate_position_hierarchy(p_position_id NUMBER)
    RETURN VARCHAR2;

END xxhr_oa2ad_pkg;

 
/
