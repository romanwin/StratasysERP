create or replace package xxoa2ssys_ftp_pkg is

--------------------------------------------------------------------
--  name:            XXOA2SSYS_FTP_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.2 
--  creation date:   13/08/2012 15:59:19
--------------------------------------------------------------------
--  purpose :        Merge Day1 project - Handle transfer data from oracle to Stratasys
--                   Sales force by FTP.
--                   CUST529 - OA 2 SSYS FTP to SFDC interface
--                   cust538 - OA2Syteline - FTP - Intercompany Inventory In Transit
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  13/08/2012  Dalit A. Raviv    initial build
--  1.1  03/10/2012  Dalit A. Raviv    cust538 OA2Syteline - FTP - Intercompany Inventory In Transit
--                                     add procedure Main_intercompany_inv, po_ftp, rcv_ftp
--                                     modify procedure get_file_name
--  1.2  12/05/2013  Dalit A. Raviv    CUST685 - OA2Syteline - FTP - handle invoice information
--                                     add procedure main_invoice, invoice_backlog_ftp, invoice_booked_ftp, invoice_lines_ftp    
--------------------------------------------------------------------   
 
  --------------------------------------------------------------------
  --  name:            Item_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer item details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------   
  /*procedure Item_ftp_old(errbuf   out varchar2,
                         retcode  out varchar2);*/

  --------------------------------------------------------------------
  --  name:            get_ftp_login_details
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/08/2012 
  --------------------------------------------------------------------
  --  purpose :        get stratasys login details for ftp
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  procedure get_ftp_login_details (p_login_url out varchar2,
                                   p_user      out varchar2,
                                   p_password  out varchar,
                                   p_err_code  out varchar2,
                                   p_err_desc  out varchar2);
  
  --------------------------------------------------------------------
  --  name:            get_file_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/08/2012 
  --------------------------------------------------------------------
  --  purpose :        get the file name according to subject
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  function get_file_name (p_entity in varchar2) return varchar2 ; 
  
  --------------------------------------------------------------------
  --  name:            Item_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer item details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure item_ftp (errbuf     out varchar2,
                      retcode    out varchar2,
                      p_num_days in  number);  
                      
  --------------------------------------------------------------------
  --  name:            relations_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer relations details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/08/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure relations_ftp (errbuf     out varchar2,
                           retcode    out varchar2,
                           p_num_days in  number); 
  
  --------------------------------------------------------------------
  --  name:            contact_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer customer contacts details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/08/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure contact_ftp (errbuf     out varchar2,
                         retcode    out varchar2,
                         p_num_days in  number);
                         
  
  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        Main will handle all programs - and will run each 
  --                   procedure according to entity parameter.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                        
  procedure main (errbuf     out varchar2,
                  retcode    out varchar2,
                  p_entity   in  varchar2,
                  p_num_days in  number); 

  --------------------------------------------------------------------
  --  name:            Main_intercompany_inv
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/10/2012 
  --------------------------------------------------------------------
  --  purpose :        Procedure will handle transfer intercompany inv - intransit
  --                   between Oracle to Sytline.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/10/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  procedure Main_intercompany_inv ( errbuf     out varchar2,
                                    retcode    out varchar2,
                                    p_entity   in  varchar2); 
                                       
  --------------------------------------------------------------------
  --  name:            main_invoice
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/05/2012
  --------------------------------------------------------------------
  --  purpose :        CUST685 - OA2Syteline - FTP - OM General report
  --                   Procedure will handle transfer invoice information 
  --                   between Oracle to Sytline.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main_invoice ( errbuf     out varchar2,
                           retcode    out varchar2,
                           p_entity   in  varchar2);                                                                                                                            

end XXOA2SSYS_FTP_PKG;

 
/
