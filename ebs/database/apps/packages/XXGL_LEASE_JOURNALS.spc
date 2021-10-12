create or replace package XXGL_LEASE_JOURNALS is
  --------------------------------------------------------------------
  --  name:            XXGL_LEASE_JOURNALS
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       JE ForLease contract ASC 842 and IFRS 16
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0    15/08/2011  Ofer Suad     CHG0041583  initial build
  --------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Ver     When        Who          Description
  -- ------  ----------  -----------  -----------------------------------------
  -- 1.0     2019-08-27  Roman W.     CHG0041583
  -----------------------------------------------------------------------------    
  procedure message(p_msg in varchar2);

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :        Main produre called from concurent - will call functios to
  --                   calcualte amounts and create the Journals   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --  1.1  27/08/2019  Roman W.    CHG0041583
  --------------------------------------------------------------------
  procedure main(errbuf out varchar2, retcode out varchar2);

  -------------------------------------------------------------------
  --  name:            get_contract_avg_pmt
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       Calculate the contract avarage payment amount   
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --  1.1  27/08/2019  Roman W.    CHG0041583
  --------------------------------------------------------------------
  function get_contract_avg_pmt(l_payment_schedule_id number,
                                p_as_of_date          date,
                                p_from_date           date) return number;
  -------------------------------------------------------------------
  --  name:            get_lease_liability
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       Calculate leablity (Short+Long terms for specific date 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2019  OFER.SUAD   initial build  
  --------------------------------------------------------------------                              
  function get_lease_liability(l_payment_schedule_id number,
                               p_as_of_date          date) return number;
  -------------------------------------------------------------------
  --  name:            get_st_lease_liability
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       Calculate Short term leablity   for specific date 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --  1.1  27/08/2019  Roman W.    CHG0041583
  --------------------------------------------------------------------                                     
  function get_st_lease_liability(l_payment_schedule_id number,
                                  p_as_of_date          date) return number;
  -------------------------------------------------------------------
  --  name:            init_date
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       Intiate Global parameters strat date and end date 
  --------------------------------------------------------------------
  --  ver  date        name        desc
  --  ---  ----------  ---------   -----------------------------------
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --  1.1  27/08/2019  Roman W.    CHG0041583
  --------------------------------------------------------------------   
  --function init_date return number;
  procedure init_date(p_start_date out date,
                      p_end_date   out date,
                      p_error_desc out varchar2,
                      p_error_code out varchar2);
  -------------------------------------------------------------------
  --  name:            populate_table
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       Insert ending balance to  XXGL_LEASE table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --  1.1  27/08/2019  Roman W.    CHG0041583
  --                                 added :p_end_date in date,errbuf out varchar2, retcode out varchar2  
  --------------------------------------------------------------------
  procedure populate_table(p_end_date in date,
                           errbuf     out varchar2,
                           retcode    out varchar2);
  -------------------------------------------------------------------
  --  name:            create_journal
  --  create by:       OFER.SUAD
  --  Revision:        1.0
  --  creation date:   13/08/2019
  --------------------------------------------------------------------
  --  purpose :       Insert data to GL Interface and import the journals 
  --------------------------------------------------------------------
  --  ver  date        name        desc
  --  1.0  13/08/2019  OFER.SUAD   initial build
  --  1.1  27/08/2019  Roman W.    CHG0041583
  --------------------------------------------------------------------
  --  procedure create_journal(l_period_name varchar2);
  procedure create_journal(p_period_name in varchar2,
                           p_start_date  in date,
                           p_end_date    in date,
                           errbuf        out varchar2,
                           retcode       out varchar2);
end XXGL_LEASE_JOURNALS;
/
