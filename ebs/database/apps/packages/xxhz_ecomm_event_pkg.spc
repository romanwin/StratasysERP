CREATE OR REPLACE PACKAGE xxhz_ecomm_event_pkg AUTHID CURRENT_USER AS
  --------------------------------------------------------------------------------------------------------
  --  name:            xxhz_ecomm_event_pkg
  --  create by:       Debarati Banerjee
  --  Revision:        1.0
  --  creation date:   11/06/2015
  --------------------------------------------------------------------------------------------------------
  --  purpose :  This package is used to generate events for customer and customer printer interface
  ---------------------------------------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  11/06/2015  Debarati Banerjee            CHG0035649 - initial build
  --       07/07/2015  Kundan Bhagat                CHG0035650 - Initial Build
  --  1.1  28/10/2015  Debarati banerjee            CHG0036659 - Adjust Ecommerce customer master interface
  --                                                Updated Function - is_ecomm_contact
  --                                                Updated Procedure - handle_contact
  --  1.2  26/11/2015  Kundan Bhagat                CHG0036749 -Adjust Ecommerce customer printer interface
  --                                                to send end customer printers
  --                                                Updated Procedure - customer_printer_process
  ---------------------------------------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036450
  --          This function is used to check if an account exists in relationship
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Diptasurjya Chatterjee             Initial Build
  -- -----------------------------------------------------------------------------
  FUNCTION is_account_related_to_ecom(p_cust_account_id NUMBER)
    RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function will be used as Rule function for all activated business events
  --          for customer creation or update
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/06/2015  Debarati Banerjee             Initial Build
  -- 1.1  28/10/2015  Debarati banerjee             CHG0036659 : Added logic to identify an
  --                                                ecommerce contact based on current DFF setup
  -- --------------------------------------------------------------------------------------------

  FUNCTION customer_event_process(p_subscription_guid IN RAW,
		          p_event             IN OUT NOCOPY wf_event_t)
    RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to insert records in xxssys_event table.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  07/07/2015  Kundan Bhagat                      CHG0035650 - Initial Build
  -- 1.1  26/11/2015  Kundan Bhagat                      CHG0036749 -Adjust Ecommerce customer printer interface
  --                                                     to send end customer printers
  -- --------------------------------------------------------------------------------------------
  PROCEDURE customer_printer_process(x_errbuf  OUT VARCHAR2,
			 x_retcode OUT NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to handle the Contact information.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Debarati Banerjee                  Initial Build
  -- 1.1  25/10/2015  Debarati Banerjee                  CHG0036659 - Modified cursor cur_site to include
  --                                                     only ship_to and bill_to sites
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_contact(p_contact_id IN NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035649
  --          This function is used to check if contact is ecom contact.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/06/2015  Debarati Banerjee                  Initial Build
  -- 1.1  28/10/2015  Debarati banerjee                  CHG0036659 : Added logic to identify an
  --                                                     ecommerce contact based on current DFF setup
  -- -----------------------------------------------------------------------------------------------
  FUNCTION is_ecomm_contact(p_contact_id NUMBER) RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036450
  --          Definition to resolve dependency between handle_contact and handle_acct_relationship
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  09/25/2015  Diptasurjya Chatterjee        CHG0036450 : Reseller changes
  -- 1.1  19/08/2016  Tagore Sathuluri              CHG0036450 : Reseller changes
  -- --------------------------------------------------------------------------------------------
  PROCEDURE handle_acct_relationship(p_cust_account_id       IN NUMBER,
			 p_reltd_cust_account_id IN NUMBER,
			 p_org_id                IN NUMBER);

END xxhz_ecomm_event_pkg;
/
