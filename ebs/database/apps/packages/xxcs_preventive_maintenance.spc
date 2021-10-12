CREATE OR REPLACE PACKAGE xxcs_preventive_maintenance IS
  --------------------------------------------------------------------
  -- name:            XXCS_PREVENTIVE_MAINTENANCE
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   12/03/2012 11:39:03
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  Customization should support different PM plans per 
  --                  different Printers and different counters readings.
  --                  screen xxce_sr_pm call to this package
  --                  Once the user select the relevant lines at the screen, 
  --                  She/he will press GENERATE button in order for the 
  --                  customization to create SRs of PM Type per each selected line.              
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  12/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  TYPE t_sr_pm_rec IS RECORD(
    entity_id         NUMBER,
    instance_id       NUMBER,
    serial_number     VARCHAR2(30),
    inventory_item_id NUMBER,
    party_id          NUMBER,
    org_id            NUMBER,
    cs_region         VARCHAR2(240),
    active_contract   VARCHAR2(240),
    counter_change    NUMBER,
    last_counter      NUMBER,
    template_id       NUMBER,
    incident_number   VARCHAR2(100),
    incident_id       NUMBER,
    log_code          VARCHAR2(10),
    log_message       VARCHAR2(2500));

  TYPE t_sr_pm_tbl IS TABLE OF t_sr_pm_rec INDEX BY BINARY_INTEGER;

  --------------------------------------------------------------------
  -- name:            create_pm_service_request
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   12/03/2012 11:39:03
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  procedure that call from create SR preventive maintenance
  --                  screen. Procedure create SR by the parameters that pass.
  --                            
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  12/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE create_pm_service_request(errbuf            OUT VARCHAR2,
                                      retcode           OUT VARCHAR2,
                                      p_instance_id     IN NUMBER,
                                      p_serial_number   IN VARCHAR2,
                                      p_party_id        IN NUMBER,
                                      p_org_id          IN NUMBER,
                                      p_cs_region       IN VARCHAR2,
                                      p_incident_number OUT VARCHAR2,
                                      p_incident_id     OUT NUMBER,
                                      p_item_id         OUT NUMBER,
                                      p_location_id     OUT NUMBER);

  PROCEDURE create_sr_pm_by_batch(errbuf     OUT VARCHAR2,
                                  retcode    OUT VARCHAR2,
                                  p_batch_id IN NUMBER);

  --------------------------------------------------------------------
  -- name:            create_pm_task
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   26/03/2012 
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  create task according to the template recomended from screen.
  --                          
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  26/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE create_pm_task(errbuf        OUT VARCHAR2,
                           retcode       OUT VARCHAR2,
                           p_template_id IN NUMBER,
                           p_incident_id IN NUMBER,
                           p_location_id IN NUMBER,
                           p_task_id     OUT NUMBER);
  --------------------------------------------------------------------
  -- name:            get_sr_number
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   21/03/2012 
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  function that get incident_date, serial number and
  --                  item_id and return SR number.
  --                  use at screen to know the last pm sr number 
  --                          
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  18/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  FUNCTION get_sr_number(p_incident_date     IN DATE,
                         p_instance_id       IN NUMBER,
                         p_inventory_item_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  -- name:            get_task_template_id
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   03/04/2012 
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  function that get inventory item id and counter change
  --                  return the task_template id        
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  03/04/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  FUNCTION get_task_template_id(p_inventory_item_id IN NUMBER,
                                p_counter_change    IN NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_counter_reading
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/04/2012
  --------------------------------------------------------------------
  --  purpose:         Bring counter reading from IB by specific date
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  04/04/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  FUNCTION get_counter_reading(p_date                  IN DATE,
                               p_printer_serial_number IN VARCHAR2,
                               p_inventory_item_id     IN NUMBER DEFAULT NULL)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_last_counter_reading
  --  create by:       Yoram Zamir / Vitaly K.
  --  Revision:        1.0
  --  creation date:   xx/xx/20xx
  --------------------------------------------------------------------
  --  purpose :        Disco Report
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  xx/xx/20xx  Yoram / Vitaly   initial build
  --  1.1  15/03/2012  Dalit A. Raviv   add parameter inventory_item_id
  --------------------------------------------------------------------
  FUNCTION get_last_counter_reading(p_printer_serial_number IN VARCHAR2,
                                    p_inventory_item_id     IN NUMBER DEFAULT NULL)
    RETURN NUMBER;

  --------------------------------------------------------------------
  -- name:            refresh_material_view
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   22/04/2012 
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  refresh material view      
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  22/04/2012  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
  PROCEDURE refresh_material_view(errbuf  OUT VARCHAR2,
                                  retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  -- name:            get_instance_staus_id
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   24/05/2012 
  --------------------------------------------------------------------
  -- purpose :        get instance_id and return its status.                    
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  24/05/2012  Dalit A. Raviv   initial build
  -------------------------------------------------------------------- 
  function get_instance_staus_id (p_instance_id in number) return number;
  
  --------------------------------------------------------------------
  -- name:            main
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   18/03/2012 
  --------------------------------------------------------------------
  -- purpose :        Cust- 484 -> SR Preventive Maintenance Auto Creation
  --                  procedure that will handle 
  --                  1) by loop from all rows that arrvied from screen
  --                     create SR PM
  --                  2) enter to log table.          
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  18/03/2012  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf      OUT VARCHAR2,
                 retcode     OUT VARCHAR2,
                 p_sr_pm_tbl t_sr_pm_tbl);

END xxcs_preventive_maintenance;
/
