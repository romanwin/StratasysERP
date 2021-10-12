create or replace package xxconv_hr_pkg is

--------------------------------------------------------------------
--  name:            XXCONV_HR_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   10/01/2011 08:47:46
--------------------------------------------------------------------
--  purpose :        HR project - Handle All conversion programs 
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  10/01/2011  Dalit A. Raviv    initial build
--  1.1  20/11/2011  Dalit A. raviv    add 3 procedures:
--                                     upload_phone_eit, upload_car_eit, get_lookup_code
--  1.2  23/08/2012  Dalit A. Raviv    add procedure upd_IT_phone_numbers
--------------------------------------------------------------------  
  
  --------------------------------------------------------------------
  --  name:            update_assignment_grade
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   28/11/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        update_assignment_grade
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/11/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  procedure update_assignment_grade;

  --------------------------------------------------------------------
  --  name:            upd_hebrew_names
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   09/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        CUST377 - Conversion - Employee hebrew first and last name to DFF
  --                   upload hebrew first last name from excel to oracle
  --                   1) select for update of XXHR_CONV_PERSON_DETAILS
  --                   2) load data to table
  --                   3) process this procedure by test
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  09/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure upd_hebrew_names (errbuf    out varchar2,
                              retcode   out varchar2); 
  
  --------------------------------------------------------------------
  --  name:            Add_positions_names_to_vs
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   10/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        Add position names to Value Set - XXHR_POSITION_NAME_VS
  --                   all positions will enter to temp table xxhr_conv_jobs_positions
  --                   select with distinct will give me all the new names 
  --                   to add to Value set.
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  10/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure Add_positions_names_to_vs (errbuf    out varchar2,
                                       retcode   out varchar2); 
                                       
  --------------------------------------------------------------------
  --  name:            Add_positions_names_to_vs
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   10/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        Add position names to Value Set - XXHR_POSITION_NAME_VS
  --                   all positions will enter to temp table xxhr_conv_jobs_positions
  --                   select with distinct will give me all the new names 
  --                   to add to Value set.
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  10/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure Add_jobs_names_to_vs (errbuf    out varchar2,
                                  retcode   out varchar2);  
  
  --------------------------------------------------------------------
  --  name:            create_new_job
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   10/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        use API to create the new jobs
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  10/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure create_new_job (errbuf    out varchar2,
                            retcode   out varchar2) ;
   
  --------------------------------------------------------------------
  --  name:            create_hr_organization
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   12/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        use API to create new organizations
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  12/01/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------                         
  procedure create_hr_organization ( errbuf    out varchar2,
                                     retcode   out varchar2 ); 
                                     
  --------------------------------------------------------------------
  --  name:            correct_start_date
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   12/01/2011 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        use API to change start date of employee
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  12/01/2011  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
  procedure correct_start_date (errbuf        out varchar2,
                                retcode       out varchar2,
                                p_person_id   in  number,
                                p_old_date    in  date,
                                p_new_date    in  date,
                                p_update_type in  varchar2);
  
  --------------------------------------------------------------------
  --  name:            close_posiotions
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   28/02/2011 
  --------------------------------------------------------------------
  --  purpose :        use API to close positions after conversion
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  28/02/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------                               
  procedure close_posiotions   (errbuf        out varchar2,
                                retcode       out varchar2);  
  
  --------------------------------------------------------------------
  --  name:            get_value_from_line
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   28/03/2011
  --------------------------------------------------------------------
  --  purpose :        get value from excel line 
  --                   return short string each time by the deliminar 
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  28/03/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  function get_value_from_line( p_line_string in out varchar2,
                                p_err_msg     in out varchar2,
                                c_delimiter   in varchar2) return varchar2;
                                                              
  --------------------------------------------------------------------
  --  name:            Add_Atzmon_codes_to_vs
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   28/03/2011 
  --------------------------------------------------------------------
  --  purpose :        Add atsmon codes to Value Set - XXHR_ATSMON_CODES
  --                   
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  28/03/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------   
  procedure Add_Atzmon_codes_to_vs (errbuf    out varchar2,
                                    retcode   out varchar2);
  
  --------------------------------------------------------------------
  --  name:            upload_atsmon_code
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   28/03/2011 
  --------------------------------------------------------------------
  --  purpose :        use API to add atzmon code to emp assignment
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  28/03/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------                               
  procedure upload_atsmon_code (errbuf        out varchar2,
                                retcode       out varchar2,
                                p_location    in  varchar2, --/UtlFiles/HR
                                p_filename    in  varchar2);
   
  --------------------------------------------------------------------
  --  name:            upload_phone_eit
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   25/10/2011 
  --------------------------------------------------------------------
  --  purpose :        use API to add Phone EIT to person
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  25/10/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------                                                                                                                                                     
  procedure upload_phone_eit(errbuf        out varchar2,
                             retcode       out varchar2,
                             p_location    in  varchar2,  -- /UtlFiles/HR
                             p_filename    in  varchar2); -- Upload_phone_info.csv
                             
  --------------------------------------------------------------------
  --  name:            upload_zviran_code
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   14/03/2012 
  --------------------------------------------------------------------
  --  purpose :        use API to add zviran code to emp assignment
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  14/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------                               
  procedure upload_zviran_code (errbuf        out varchar2,
                                retcode       out varchar2,
                                p_location    in  varchar2, --/UtlFiles/HR
                                p_filename    in  varchar2);
  
  --------------------------------------------------------------------
  --  name:            upload_phone_eit
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   25/10/2011 
  --------------------------------------------------------------------
  --  purpose :        use API to add Phone EIT to person
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  25/10/2011  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
  procedure upload_car_eit(errbuf        out varchar2,
                           retcode       out varchar2,
                           p_location    in  varchar2,    -- /UtlFiles/HR
                           p_filename    in  varchar2) ;  -- Upload_car_info.csv
                           
  --------------------------------------------------------------------
  --  name:            upload_it_Phones_eit
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   28/11/2011 
  --------------------------------------------------------------------
  --  purpose :        use API to add IT Phones EIT to person
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  25/10/2011  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
  procedure upload_it_Phones_eit(errbuf        out varchar2,
                                 retcode       out varchar2,
                                 p_location    in  varchar2,    -- /UtlFiles/HR
                                 p_filename    in  varchar2) ;  -- IT_IL_PHONES.csv                          
                           
  --------------------------------------------------------------------
  --  name:            get_lookup_code
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   25/10/2011 
  --------------------------------------------------------------------
  --  purpose :        translate meaning to code
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  25/10/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------                            
  function get_lookup_code (p_lookup_type    in varchar2,
                            p_lookup_meaning in varchar2) return varchar2; 
                            
  --------------------------------------------------------------------
  --  name:            upd_IT_phone_numbers
  --  create by:       Dalit A. Raviv 
  --  Revision:        1.0 
  --  creation date:   23/08/2012
  --------------------------------------------------------------------
  --  purpose :        update full phone number at person EIT - IT
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  23/08/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------                            
  procedure upd_IT_phone_numbers (errbuf        out varchar2,
                                  retcode       out varchar2);                                                        

end XXCONV_HR_PKG;
/
