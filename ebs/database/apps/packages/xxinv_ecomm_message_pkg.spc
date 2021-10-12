CREATE OR REPLACE PACKAGE xxinv_ecomm_message_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            xxinv_ecomm_message_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   24/06/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0035652 - Generic container package to handle all
  --                   inventory module related message generation, against 
  --                   events recorded by API xxinv_ecomm_event_pkg
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  24/06/2015  Diptasurjya Chatterjee(TCS)  CHG0035652 - initial build
  --  1.1  29/06/2015  Diptasurjya Chatterjee(TCS)  CHG0035700 - generate printer-flavor message
  ----------------------------------------------------------------------------


  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function converts dimension UOM code to Inches
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  function get_dimensions_uom_conv_code(p_unit_code         IN VARCHAR2,
                                        p_inventory_item_id IN NUMBER) return varchar2;
  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function converts weight UOM code to LBS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------                                      
  function get_weight_uom_conv_code(p_unit_code         IN VARCHAR2,
                                    p_inventory_item_id IN NUMBER) return varchar2;
  
  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function converts item dimensions to Inches
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------                                  
  function get_dimensions_conv_value(p_unit_value        IN NUMBER,
                                     p_inventory_item_id IN NUMBER,
                                     p_uom_code          IN VARCHAR2) return number;
  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function converts item weight to LBS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------                                   
  function get_weight_conv_value(p_unit_value IN NUMBER,
                                p_inventory_item_id IN NUMBER,
                                p_uom_code IN VARCHAR2) return number;
                                

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function generate and return product data for a given inventory_item_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  function generate_item_data(p_event_id  NUMBER,
                              p_entity_id NUMBER) return xxinv_product_rec_type;
                              
                              
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035700
  --          This function generates and returns printer flavor relationship data
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  29/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  function generate_prnt_flavor_data(p_event_id IN number,
                                     p_entity_id IN number,
                                     p_attribute1 IN varchar2) return xxinv_product_rec_type;

  -- --------------------------------------------------------------------------------------------
  -- Name:              generate_product_messages
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     24/06/2015
  -- Calling Entity:    BPEL Process: http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessProductDetailsCmp/productdetailsprocessbpel_client_ep?wsdl
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This procedure is used to fetch product details as per NEW events recorded in event 
  --          table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE generate_product_messages(x_errbuf           OUT VARCHAR2,
                                      x_retcode          OUT NUMBER,
                                      p_no_of_record     IN NUMBER,
                                      --p_entity_name      IN VARCHAR2,
                                      p_bpel_instance_id IN NUMBER,
                                      p_event_id_tab     IN xxobjt.xxssys_interface_event_tab,
                                      x_products         OUT xxecom.xxinv_product_tab_type);


  -- --------------------------------------------------------------------------------------------
  -- Name:              generate_prnt_flavor_messages
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     29/06/2015
  -- Calling Entity:    BPEL Process: http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessPrinterDetailsCmp/processprinterflavorbpel_client_ep?wsdl
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035700
  --          This procedure is used to fetch printer-flavor details as per NEW events recorded in event 
  --          table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  29/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE generate_prnt_flavor_messages(x_errbuf           OUT VARCHAR2,
                                          x_retcode          OUT NUMBER,
                                          p_no_of_record     IN NUMBER,
                                          --p_entity_name      IN VARCHAR2,
                                          p_bpel_instance_id IN NUMBER,
                                          p_event_id_tab     IN xxobjt.xxssys_interface_event_tab,
                                          x_printer_flavor   OUT xxecom.xxinv_product_tab_type);                                      
END xxinv_ecomm_message_pkg;
/
