CREATE OR REPLACE PACKAGE xxcs_price_list_chg_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: XXCS_PRICE_LIST_CHG_PKG 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: XXCS_PRICE_LIST_CHG_PKG
  -- Created: 07/02/2010
  -- Author  : Ella
  -- Version : 1.0
  --------------------------------------------------------------------------
  -- Perpose: Purchasing approval WF modifications
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  ----------  --------------  -------------------------------------
  --     1.0  07/02/2010                  Initial Build
  ---------------------------------------------------------------------------

  FUNCTION get_price_list_id(p_business_process_id NUMBER,
                             p_instance_id         NUMBER) RETURN NUMBER;

  FUNCTION get_price_list_details(p_list_header_id  NUMBER,
                                  x_price_list_name OUT VARCHAR2,
                                  x_currency_code   OUT VARCHAR2)
    RETURN NUMBER;

  PROCEDURE chg_charges_price_list(errbuf        OUT VARCHAR2,
                                   retcode       OUT VARCHAR2,
                                   p_incident_id NUMBER DEFAULT NULL);

  PROCEDURE change_warranty_coverage(errbuf  OUT VARCHAR2,
                                     retcode OUT VARCHAR2);

END xxcs_price_list_chg_pkg;
/
