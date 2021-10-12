CREATE OR REPLACE PACKAGE xxinv_pronto_message_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            xxinv_ecomm_message_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   26/10/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0036886 - Generic container package to handle all
  --                   inventory module related message generation where target is PRONTO,
  --                   against events recorded by API xxinv_ecomm_event_pkg
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  26/10/2015  Diptasurjya Chatterjee(TCS)  CHG0036886 - add pronto item message creation and
  --                                                and pronto item onhand message creation functions
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function generate and return product data for a given event_id
  --          for PRONTO integration
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  26/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_item_data(p_event_id  NUMBER,
		      p_entity_id NUMBER)
    RETURN xxinv_pronto_product_rec_type;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function generate and return item onhand data for a given event_id
  --          for PRONTO integration
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_onhand_data(p_event_id NUMBER)
    RETURN xxinv_item_onhand_rec_type;

  -- --------------------------------------------------------------------------------------------
  -- Name:              generate_product_messages
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     27/10/2015
  -- Calling Entity:    BPEL Process: http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessProductDetailsCmp/productdetailsprocessbpel_client_ep?wsdl
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This procedure is used to fetch product details as per NEW events recorded in event
  --          table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE generate_product_messages(x_errbuf           OUT VARCHAR2,
			  x_retcode          OUT NUMBER,
			  p_no_of_record     IN NUMBER,
			  p_bpel_instance_id IN NUMBER,
			  p_event_id_tab     IN xxobjt.xxssys_interface_event_tab,
			  x_products         OUT xxobjt.xxinv_pronto_product_tab_type);

  -- --------------------------------------------------------------------------------------------
  -- Name:              generate_onhand_messages
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     27/10/2015
  -- Calling Entity:    BPEL Process: http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessProductDetailsCmp/productdetailsprocessbpel_client_ep?wsdl
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This procedure is used to fetch item onhand details as per NEW events recorded in event
  --          table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE generate_onhand_messages(x_errbuf           OUT VARCHAR2,
			 x_retcode          OUT NUMBER,
			 p_no_of_record     IN NUMBER,
			 p_bpel_instance_id IN NUMBER,
			 p_event_id_tab     IN xxobjt.xxssys_interface_event_tab,
			 x_onhand           OUT xxobjt.xxinv_item_onhand_tab_type);
END xxinv_pronto_message_pkg;
/
