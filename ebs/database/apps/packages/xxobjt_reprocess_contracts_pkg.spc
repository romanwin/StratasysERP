create or replace package xxobjt_reprocess_contracts_pkg is

--------------------------------------------------------------------
--  name:            XXOBJT_REPROCESS_CONTRACTS_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   08/01/2012 17:01:32
--------------------------------------------------------------------
--  purpose :        CUST475 - Reprocess Contracts
--                   During the SO shipment in Objet, the installation date of 
--                   the printer is not known, therefore impossible to predict  
--                   the start date of the second year contract that customer 
--                   purchases in initial sales order together with the printer.
--
--                   Required to perform several system changes in order to enable  
--                   creation of second year contract that will be aligned with  
--                   installation date of the printer and its warranty period.
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  08/01/2012  Dalit A. Raviv    initial build
--------------------------------------------------------------------   

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST475 - Reprocess Contracts
  --
  --                   Procedure will call from concurrent program and will run once a day.
  --                   1) Update service item in sales order line.
  --                      For service item will be updated Service_start_date and 
  --                      Service_end_date in oe_order_lines_all table
  --                   2) Update oks_reprocessing table – change the success_flag = ‘N’
  --                   3)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/01/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
 procedure  main (errbuf         out varchar2,
                  retcode        out number,
                  p_so_number    in  number,
                  p_so_line_id   in  number,
                  p_warr_to_cont in  varchar2);

end XXOBJT_REPROCESS_CONTRACTS_PKG;

 
/
