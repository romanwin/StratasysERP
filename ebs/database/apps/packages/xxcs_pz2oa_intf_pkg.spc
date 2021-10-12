create or replace package XXCS_PZ2OA_INTF_PKG is

--------------------------------------------------------------------
-- name:            XXCS_PZ2OA_INTF_PKG
-- create by:       Dalit A. Raviv
-- Revision:        1.0 
-- creation date:   22/05/2011 2:57:40 PM
--------------------------------------------------------------------
-- purpose :        CUST419 - PZ2Oracle interface for UG upgrade in IB
--------------------------------------------------------------------
-- ver  date        name             desc
-- 1.0  22/05/2011  Dalit A. Raviv   initial build
-- 1.1  12/06/2011  Dalit A. Raviv   Check Close SR only for HW.
-- 1.2  16/06/2011  Dalit A. Raviv   Add condition to procedure initiate_ib_update
--------------------------------------------------------------------
  
  TYPE t_log_rec IS RECORD 
     (transaction_id   number,
      record_status    varchar2(100),
      error_message    varchar2(2000));
  
  --------------------------------------------------------------------
  -- name:            ins_interface_row
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0 
  -- creation date:   30/05/2011 2:57:40 PM
  --------------------------------------------------------------------
  -- purpose :        insert row to interface table(xxcs_pz2oa_intf)
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  30/05/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  procedure ins_interface_row (p_system_sn         in  varchar2,
                               p_hasp_sn           in  varchar2,
                               p_transaction_date  in  date,
                               p_transaction_type  in  varchar2,
                               p_file_name         in  varchar2,
                               p_bpel_instance_id  in  number,
                               p_err_code          out varchar2,
                               p_err_msg           out varchar2);
  
  --------------------------------------------------------------------
  --  name:            process_pz2oa_request
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   29/05/2011
  --------------------------------------------------------------------
  --  purpose :        To be able to re run and correct data   
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  29/05/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  procedure process_pz2oa_request_conc(errbuf           out varchar2, 
                                       retcode          out number,
                                       p_transaction_id in  number);

  --------------------------------------------------------------------
  --  name:            call_bpel_process
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   22/05/2011
  --------------------------------------------------------------------
  --  purpose :        Call Bpell Process to start process  
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  22/05/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE call_bpel_process (errbuf OUT VARCHAR2, retcode OUT NUMBER);
  
  --------------------------------------------------------------------
  --  name:            initiate_IB_update
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   23/05/2011
  --------------------------------------------------------------------
  --  purpose :        Start process data  
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  23/05/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE initiate_ib_update (p_request_status  in  varchar2 default null,
                                p_serial_number   in  varchar2 default null,
                                x_return_status   in  out varchar2,
                                x_err_msg         in  out varchar2);
                                
  --------------------------------------------------------------------
  --  name:            initiate_IB_update_conc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   29/05/2011
  --------------------------------------------------------------------
  --  purpose :        To be able to re run and correct data
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  29/05/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  procedure initiate_ib_update_conc (errbuf            out varchar2, 
                                     retcode           out number,
                                     p_request_status  in  varchar2 default null,
                                     p_serial_number   in  varchar2 default null);                                

end XXCS_PZ2OA_INTF_PKG;
/

