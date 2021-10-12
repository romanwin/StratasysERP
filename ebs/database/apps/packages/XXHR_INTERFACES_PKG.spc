create or replace package XXHR_INTERFACES_PKG is

--------------------------------------------------------------------
--  name:            XXHR_INTERFACES_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   26/06/2014 12:27:14
--------------------------------------------------------------------
--  purpose :        CHG0032233 - Upload HR data into Oracle
--                   Handle all HR interfaces programs
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  26/06/2014  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  type t_interface_rec IS RECORD(
      interface_id         number,
      batch_id             number,
      status               varchar2(20),
      action               varchar2(20),
      person_id            number,
      first_name           varchar2(150),
      last_name            varchar2(150),
      person_type          varchar2(80),
      person_type_id       number,
      employee_number      varchar2(30),           -- (generate automatically for new person) (in update mode it requiered else not)
      national_identifier  varchar2(150),
      hire_date            date,                   -- (dd-MON-YYYY) - (if come as null do not update, if need to create do inform on the log_message)
      gender               varchar2(30),
      birthdate            date,                   -- (dd-mon-yyyy)
      email                varchar2(240),
      internal_location    varchar2(150),
      local_last_name      varchar2(150),          -- (attribute1)
      local_first_name     varchar2(150),          -- (attribute2)
      home_email_address   varchar2(150),          -- (attribute3)
      reference_number     varchar2(150),          -- (attribute4)
      sf_title             varchar2(150),          -- (attribute5)
      sf_job               varchar2(150),          -- (attribute6)
      diploma              varchar2(15),           -- (attribute7)
      attribute8           varchar2(150),
      attribute9           varchar2(150),
      attribute10          varchar2(150),
      attribute11          varchar2(150),
      attribute12          varchar2(150),
      attribute13          varchar2(150),
      attribute14          varchar2(150),
      attribute15          varchar2(150),
      attribute16          varchar2(150),
      attribute17          varchar2(150),
      attribute18          varchar2(150),
      attribute19          varchar2(150),
      attribute20          varchar2(150),
      assignment_id        number,
      organization         varchar2(240),
      organization_id      number,
      job                  varchar2(240),
      job_id               number,
      position_name        varchar2(240),          -- (most of US does not use positions)
      position_id          number,
      grade                varchar2(240),
      grade_id             number,
      location_code        varchar2(60),
      location_id          number,
      supervisor           varchar2(30),           -- (need to be a valid emp number)
      supervisor_id        number,
      date_probation_end   date,
      probation_period     number,
      probation_unit       varchar2(30),
      ass_attribute1       varchar2(150),
      ass_attribute2       varchar2(150),
      ass_attribute3       varchar2(150),
      ass_attribute4       varchar2(150),
      ass_attribute5       varchar2(150),
      ass_attribute6       varchar2(150),
      ass_attribute7       varchar2(150),
      ass_attribute8       varchar2(150),
      ass_attribute9       varchar2(150),
      ass_attribute10      varchar2(150),
      ass_attribute11      varchar2(150),
      ass_attribute12      varchar2(150),
      ass_attribute13      varchar2(150),
      ass_attribute14      varchar2(150),
      ass_attribute15      varchar2(150),
      matrix_supervisor    varchar2(150),          -- (attribute16) - (need to be a valid emp number )
      matrix_supervisor_id number,
      ass_attribute17      varchar2(150),
      ass_attribute18      varchar2(150),
      ass_attribute19      varchar2(150),
      ass_attribute20      varchar2(150),
      ledger               varchar2(30),           --(objet israel (usd))
      set_of_books_id      number,
      company              varchar2(150),          -- 10
      department           varchar2(150),          -- 630
      account              varchar2(150),          -- 699999 - (if it is null to put 69999)
      code_combination_id  number,
      FTE_value            number,                 -- (0-1) will handle in the program - only if different from 1 and 1 it will contain value.
      HC_value             number,                 -- (0-1) will handle in the program - only if different from 1 and 1 it will contain value.
      site_name            varchar2(150),          -- (Territory) - will hold US, IL, APJ, EMEA etc
      change_date          date,                   -- the date of the change if it is null for update: use sysdate, for creation: use start date else if there is value at change date use it.
      log_code             varchar2(10),
      log_message          varchar2(2000),
      validation_msg       varchar2(2000),
      file_name            varchar2(150),
      last_update_date  	 date,
      last_updated_by    	 number,
      last_update_login  	 number,
      creation_date        date,
      created_by         	 number,
      reference_int_id     number,
      hire_date_var        varchar2(50),
      birthdate_var        varchar2(50),
      date_probation_end_var varchar2(50),
      change_date_var      varchar2(50) );

  --------------------------------------------------------------------
  --  name:            gen_validation
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/06/2014
  --------------------------------------------------------------------
  --  purpose :        Handle - all general validations that need to do
  --  in params:
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure gen_validation (errbuf          out    varchar2,
                            retcode         out    varchar2,
                            p_interface_rec in out t_interface_rec) ;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/06/2014
  --------------------------------------------------------------------
  --  purpose :        Process the data from excel file
  --                   this procedure will call from retry too
  --  in params:
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/06/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure process_data ( errbuf          out varchar2,
                           retcode         out varchar2,
                           p_interface_rec in  out t_interface_rec/*,
                           p_first_upload  in  varchar2*/);

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/06/2014
  --------------------------------------------------------------------
  --  purpose :        Handle - main program to create/update person in oracle
  --  in params:       p_file_name  -
  --                   p_location   -
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/11/2010  Dalit A. Raviv    initial build
  --  1.1  20/11/2011  Dalit A. Raviv    nvl to get npw_number for contractors
  --------------------------------------------------------------------
  procedure main ( errbuf           out varchar2,
                   retcode          out varchar2,
                   p_table_name     in  varchar2, -- hidden parameter, default value ='xxobjt_conv_category' independent value set xxobjt_loader_tables
                   p_template_name  in  varchar2, -- dependent value set xxobjt_loader_templates
                   p_file_name      in  varchar2,
                   p_directory      in  varchar2,
                   p_retry          in  varchar2/*,
                   p_first_upload   in  varchar2 default 'N'*/
                  );

  --------------------------------------------------------------------
  --  name:            main_retry
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   30/07/2014
  --------------------------------------------------------------------
  --  purpose :        Handle - main retry program to create/update person in oracle
  --  in params:       p_table_name    - the table to refer the upload to - XXHR_INTERFACES
  --                   p_template_name - the same table can have several templates - GEN
  --                   p_file_name     - the file name to upload
  --                   p_directory     - the path where customer put the file - /UtlFiles/shared/DEV
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/07//2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main_retry ( errbuf     out varchar2,
                         retcode    out varchar2
                       ) ;

  --------------------------------------------------------------------
  --  name:            create_person
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/07/2014
  --------------------------------------------------------------------
  --  purpose :        Create new person by using oracle API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure create_person (errbuf          out    varchar2,
                           retcode         out    varchar2,
                           p_interface_rec in out t_interface_rec/*,
                           p_first_upload  in     varchar2*/);

  --------------------------------------------------------------------
  --  name:            update_assignment
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/07/2014
  --------------------------------------------------------------------
  --  purpose :        update person assignment details by using oracle API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_assignment(errbuf          out    varchar2,
                              retcode         out    varchar2,
                              p_interface_rec in out t_interface_rec,
                              p_mode          in     varchar2,
                              p_assignment_id out    number);

  --------------------------------------------------------------------
  --  name:            get_datetrack_mode
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/07/2014
  --------------------------------------------------------------------
  --  purpose :        call oracle API that calculate the datetrake mode
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/07/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_datetrack_mode (p_table_name in varchar2,
                               p_key_column in varchar2,
                               p_key_value  in number,
                               p_date       in date) return varchar2;

end XXHR_INTERFACES_PKG;
/
