CREATE OR REPLACE PACKAGE xxhz_ecomm_message_pkg AUTHID CURRENT_USER AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035650
  --          This function generate and return customer-Printer data for a given cust_account_id
  --          and inventory_item_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  07/07/2015  Kundan Bhagat                  Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_printer_data(p_event_id        IN NUMBER,
		         p_cust_account_id IN NUMBER,
		         p_item_id         IN NUMBER,
		         p_status          IN VARCHAR2)
    RETURN xxhz_customer_printer_rec;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function generate and return customer account data for a given cust_account_id
  --          and org_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_account_data(p_event_id        IN NUMBER,
		         p_cust_account_id IN NUMBER,
		         --p_rltd_cust_accnt_id IN NUMBER,
		         p_org_id IN NUMBER,
		         p_status IN VARCHAR2)
    RETURN xxhz_customer_account_rec;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function generate and return customer site data for a given cust_account_id,
  --          site_id and org_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_site_data(p_event_id           IN NUMBER,
		      p_cust_account_id    IN NUMBER,
		      p_rltd_cust_accnt_id IN NUMBER,
		      p_cust_site_use_id   IN NUMBER,
		      p_status             IN VARCHAR2)
    RETURN xxhz_customer_site_rec;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function generate and return customer contact data for a given cust_account_id,
  --          contact_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  18/06/2015  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION generate_contact_data(p_event_id           IN NUMBER,
		         p_cust_account_id    IN NUMBER,
		         p_rltd_cust_accnt_id IN NUMBER,
		         p_cust_contact_id    IN NUMBER,
		         p_status             IN VARCHAR2)
    RETURN xxhz_customer_contact_rec;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to validate the customer details
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  17/06/2015  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE validate_data(p_cust_account_id IN NUMBER,
		  --p_bpel_instance_id IN NUMBER,
		  l_final_cust_flag OUT VARCHAR2,
		  l_status_message  OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This procedure is used to fetch customer account,site,contacts and relation details   -- CHG0036450 : Tagore
  --  BPEL process:Account- http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessCustomerDataCmp/customeraccountprocessbpel_client_ep?wsdl
  --              Contact - http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessCustomerDataCmp/customercontactprocessbpel_client_ep?WSDL
  --              Site - http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessCustomerDataCmp/customersiteprocessbpel_client_ep?WSDL
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  17/06/2015  Debarati Banerjee         Initial Build
  -- 1.1  10/08/2016  Tagore Sathuluri              CHG0036450 : Reseller changes.Add out variable for account relation
  -- --------------------------------------------------------------------------------------------

  PROCEDURE generate_customer_messages(p_max_records      IN NUMBER,
			   p_entity_name      IN VARCHAR2,
			   p_bpel_instance_id IN NUMBER,
			   p_event_id_tab     IN xxobjt.xxssys_interface_event_tab,
			   x_errbuf           OUT VARCHAR2,
			   x_retcode          OUT NUMBER,
			   x_accounts         OUT xxecom.xxhz_customer_account_tab,
			   x_sites            OUT xxecom.xxhz_customer_site_tab,
			   x_contacts         OUT xxecom.xxhz_customer_contact_tab,
			   x_relation         OUT xxecom.xxhz_customer_acct_rel_tab); -- CHG0036450 : Tagore

  --------------------------------------------------------------------
  --  name:           generate_cust_printer_messages
  --  create by:      Kundan Bhagat
  --  Revision:       1.0
  --  creation date:  07/07/2015
  --  BPEL process:   http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessPrinterDetailsCmp/customerprinterprocessbpel_client_ep?wsdl
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035650
  --          This procedure is used to fetch customer-Printer details
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  07/07/2015  Kundan Bhagat                  Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE generate_cust_printer_messages(p_max_records      IN NUMBER,
			       p_bpel_instance_id IN NUMBER,
			       p_event_id_tab     IN xxobjt.xxssys_interface_event_tab,
			       x_errbuf           OUT VARCHAR2,
			       x_retcode          OUT NUMBER,
			       x_cust_printers    OUT xxecom.xxhz_customer_printer_tab);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036450
  --          This function generate and return Customer-Relationship data for a given cust_account_id
  --          and related_cust_account_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  10/08/2016  Tagore Sathuluri                   Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_relationship_data(p_event_id           IN NUMBER,
			  p_cust_account_id    IN NUMBER,
			  p_rltd_cust_accnt_id IN NUMBER,
			  p_org_id             IN NUMBER,
			  p_status             IN VARCHAR2)
    RETURN xxhz_customer_acct_rel_rec;

END xxhz_ecomm_message_pkg;
/
