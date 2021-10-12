create or replace package XXCSI_UTILS_PKG is
-----------------------------------------------------------------------
--  customization code: GENERAL
--  name:               XXCSI_UTILS_PKG
--  create by:          Dalit A. Raviv
--  $Revision:          1.0 
--  creation date:      14/10/2010 
--  Purpose :           Install Base generic package
-----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   14/10/2010    Dalit A. Raviv  Initial version
--  1.1   29/03/2012    Dalit A. Raviv  add function get_Attached_file_to_printer
--  1.2   13/05/2015    Dalit A. Raviv  CHG0034234 - Update PTO Validation Setup
--                                      add procedure get_printer_and_contract_info
-----------------------------------------------------------------------
                                     
  --------------------------------------------------------------------
  --  name:            create_cust_account_role
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   12/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that create cust account role                
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_system (errbuf  out varchar2,
                           retcode out varchar2);
                           
  --------------------------------------------------------------------
  --  name:            get_Attached_file_to_printer
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   29/03/2012
  --------------------------------------------------------------------
  --  purpose :        function that find if instance have attachment              
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/03/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                        
  function get_Attached_file_to_printer(p_instance_id in number) return varchar2;
  
  --------------------------------------------------------------------
  --  name:            get_printer_and_contract_info
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/05/2015
  --------------------------------------------------------------------
  --  purpose :        function that get serial number and contract SO line id
  --                   and retun IB info          
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/05/2015  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure get_printer_and_contract_info (p_serial_number     in  varchar2,
                                           p_so_line_id        in  number,
                                           p_entity            in  varchar2,
                                           p_instance_id       out varchar2,
                                           p_contract_end_date out date,
                                           p_sf_id             out varchar2,
                                           p_inventory_item_id in out number ); 
                            
end XXCSI_UTILS_PKG;

 
/
