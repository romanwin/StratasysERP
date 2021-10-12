CREATE OR REPLACE PACKAGE xxcs_fsr_interface_pkg IS

  -- Author  : ELLA.MALCHI
  -- Created : 07-Dec-09 11:43:18
  -- Purpose : Service FSR Interface
  -- Version : 1.0

  --------------------------------------------------------------------
  -- name:            XXCS_FSR_INTERFACE_PKG
  -- create by:       Ella malchi
  -- Revision:        1.0 
  -- creation date:   xx/xx/2010 
  --------------------------------------------------------------------
  -- purpose :        process_fsr_request
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  xx/xx/2010  Ella malchi      initial build
  -- 1.1  09/01/2011  Dalit A. Raviv   procedure process_fsr_request
  --                                   change logic of select at  line 1343
  --                                   serial number use to be uniqe number
  --                                   now serial number can be none uniqe number
  --                                   but just one will be active.
  -- 1.2  10.01.2011  yuval tal        add process_attachments +
  --                                   change process_fsr_request (call process_attachments)
  -- 1.3  30/01/2011  Dalit A. Raviv   add validation on procedure: 
  --                                   add incident date validation - can not be grather then current date 
  -- 1.4  15/05/2011  Dalit A. Raviv   Procedure get_price_list_header_id add  logic
  -- 1.5  22/05/2011  Dalit A. Raviv   Procedure create_fsr_request:
  --                                   add Project_Number in SR creation API 
  -- 1.6  29/05/2011  Dalit A. Raviv   change message in procedure process_fsr_request
  --                                   change logic of BILL_TO/SHIP_TO at procedure create_fsr_request
  --                                   create_fsr_note x_err_msg - return null and not note count
  -- 1.7  28/05/2012  Dalit A. Raviv   Some SR that created have closed date of year 01/01/4712
  --                                   This is oncorrect. The solution is to add procedure (that will 
  --                                   call immidiate after SR creation) that will update SR status
  --                                   to closed and set closed_date to sysdate. 
  --------------------------------------------------------------------

  PROCEDURE process_fsr_interface(p_request_status IN VARCHAR2,
                                  p_fsr_file_name  IN VARCHAR2 DEFAULT NULL,
                                  x_return_status  IN OUT VARCHAR2,
                                  x_err_msg        IN OUT VARCHAR2);

  PROCEDURE process_fsr_interface_conc(errbuf           OUT VARCHAR2,
                                       retcode          OUT VARCHAR2,
                                       p_request_status IN VARCHAR2);

  PROCEDURE update_addnl_params(p_bpel_instance_id IN NUMBER);

  --------------------------------------------------------------------
  --  name:            update_addnl_params_conc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   15/05/2010 
  --------------------------------------------------------------------
  --  purpose :        Concurrent that will give the ability to 
  --                   update additional params at table  
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  15/05/2011  Dalit A. Raviv  initial build
  --  1.1  27/11/2011  Dalit A. raviv  change all logic
  --  1.2  28/11/2011  Dalit A. Raviv  add parameter org id
  --------------------------------------------------------------------
  PROCEDURE update_addnl_params_conc(errbuf             OUT VARCHAR2,
                                     retcode            OUT NUMBER,
                                     p_bpel_instance_id IN NUMBER,
                                     p_org_id           IN NUMBER);

  --------------------------------------------------------------------
  --  name:            initiate_process
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2010  Ella Malchi     initial build
  --------------------------------------------------------------------
  PROCEDURE initiate_process(errbuf OUT VARCHAR2, retcode OUT NUMBER);

  --------------------------------------------------------------------
  --  name:            process_attachments
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   10/01/2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name          desc
  --  1.0  10/01/2011  Yuval Tal     initial build
  --------------------------------------------------------------------
  PROCEDURE process_attachments(errbuf    OUT VARCHAR2,
                                retcode   OUT NUMBER,
                                p_bpel_id NUMBER DEFAULT NULL);

  --------------------------------------------------------------------
  --  name:            update_incident_status
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/05/2012
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  28/05/2012  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE update_incident_status(p_incident_id        IN NUMBER,
                                   p_incident_status_id IN NUMBER,
                                   x_return_status      OUT VARCHAR2,
                                   x_err_msg            OUT VARCHAR2);

  PROCEDURE process_fsr_request(p_fsr_id            IN NUMBER,
                                p_registration_code IN NUMBER,
                                x_return_status     IN OUT VARCHAR2,
                                x_err_msg           IN OUT VARCHAR2);
END xxcs_fsr_interface_pkg;
/
