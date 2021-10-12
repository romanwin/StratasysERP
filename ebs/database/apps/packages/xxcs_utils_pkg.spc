CREATE OR REPLACE PACKAGE xxcs_utils_pkg IS

  -----------------------------------------------------------------------
  --  customization code: GENERAL
  --  name:               XXCS_UTILS_PKG
  --  create by:          XXX
  --  $Revision:          1.0
  --  creation date:      31/08/09
  --  Purpose :           Service generic package
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/08/09      XXX             initial build
  --  1.1   07/03/2010    Dalit A. Raviv  add function - get_resource_name_by_id
  --                                      for commission report
  --  1.2   07/06/2010    Vitaly          add function - check_security_by_oper_unit
  --                                      for security at Service disco reports
  --  1.3   10/08/2011    Dalit A. Raviv  new function get_SR_is_repeated
  --  1.4   14/06/2012    Adi Safin       add function: get_SUB_for_order_line
  --  1.6   30/07/2013    Dalit Raviv     add new function get_SR_is_repeated_new
  --  1.7   22/02/2017    Adi Safin       CHG0040155 - add new function get_contract_entitlement
  --  1.8   19/06/2017    Lingaraj(TCS)   CHG0040890 - updated the upgrade advisor to support selling an upgrade in an initial sale
  --                                      Adding a New Procedure which will Update (Item + Serial Number) Instance id to Attribute1
  --                                      Upgrade Sales Order line.
  --                                      Procedure Name : Update_upg_instance_id
  --  2.0  13/08/2017     Adi Safin       CHG0040196 - add parameter to get_contract_entitlement  Support features lookup (like Voxel) and update salesforce interface in update_upg_instance_id procedure
  -----------------------------------------------------------------------

  FUNCTION get_last_assignee(p_incident_id NUMBER,
		     p_source_name VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_sr_related_orders_message(p_incident_id NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_region_by_ou(p_operating_unit_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            XXOE_COMMISSION
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/03/2010
  --------------------------------------------------------------------
  --  purpose :        Function that get salesperson_id and return
  --                   resource name
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  07/03/2010  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_resource_name_by_id(p_resource_id IN NUMBER) RETURN VARCHAR2;

  -----------------------------------------------------------------------
  --  customization code:
  --  name:               check_security_by_oper_unit
  --  create by:          Vitaly
  --  $Revision:          1.0
  --  creation date:      07/06/2010
  --  Purpose :           Check the privilege of seeing the information according to the profile :
  --                      "XX: VPD Security Enabled" (profile short name 'XXCS_VPD_SECURITY_ENABLED')
  --                      The function gets the ORG_ID, PARTY_ID and four additional parameters (for future use)
  --                      ORG_ID --> For the VPD
  --                      PARTY_ID --> For the exceptions parties
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/06/2010    Vitaly          initial build
  -----------------------------------------------------------------------
  FUNCTION check_security_by_oper_unit(p_org_id     IN NUMBER,
			   p_party_id   IN NUMBER DEFAULT NULL,
			   p_add_param1 IN VARCHAR2 DEFAULT NULL,
			   p_add_param2 IN VARCHAR2 DEFAULT NULL,
			   p_add_param3 IN VARCHAR2 DEFAULT NULL,
			   p_add_param4 IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            upd_external_att_in_sr
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/04/2011
  --------------------------------------------------------------------
  --  purpose :        Procedute taht update SR external_attribute1
  --                   by specific logic
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/04/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE upd_external_att_in_sr(errbuf  OUT VARCHAR2,
		           retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            get_SR_is_repeated
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/08/2011
  --------------------------------------------------------------------
  --  purpose :        function that check if SR is repeate:
  --                   check that type is reactive if yes check 30 days back
  --                   if there is SR for the same customer_product_id(instance)
  --                   if yes check that the SR is reactive if Yes -> return Y
  --                   else return N
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/08/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_sr_is_repeated(p_incident_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            XXCS_GET_SUB_FOR_ORDER_LINE
  --  create by:       Adi Safin
  --  Revision:        1.0
  --  creation date:   14/06/2012
  --------------------------------------------------------------------
  --  purpose :        function that get the subinventory for each order line.
  --                   if it from stock to customer. get the subinventory before Stage subinventory
  --                   if it a recieving line it will get the subinventory where the part will be "sit".
  --                   This function is been used in view XXCS_SHIPPING_REPORT_V
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/06/2012  Adi Safin         initial build
  --------------------------------------------------------------------

  FUNCTION get_sub_for_order_line(p_org_id            IN NUMBER,
		          p_inventory_item_id IN NUMBER,
		          p_line_id           IN NUMBER,
		          p_line_type         IN VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            Update_TM_PL_in_IB
  --  create by:       Adi Safin
  --  Revision:        1.0
  --  creation date:   27/12/2012
  --------------------------------------------------------------------
  --  purpose :        Procedure that update T&M price list in the IB
  --                   it checks the following logic
  --                   for each instance if it has PL defined in the IB
  --                   if the machine move from one CS region to another
  --                   if the machine is not under china location
  --                   Concurrent name : XX: Update IB TM Price list
  --                   Responsibility name : CRM Service super user.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/12/2012  Adi Safin         initial build
  --------------------------------------------------------------------
  PROCEDURE update_tm_pl_in_ib(errbuf  OUT VARCHAR2,
		       retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            get_SR_is_repeated
  --  create by:       Dalit Raviv
  --  Revision:        1.0
  --  creation date:   30/06/2013
  --------------------------------------------------------------------
  --  purpose :        function that check if SR is repeate:
  --                   check that type is reactive and it has more the 1 SR on speicfic SN
  --                   in required period.
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/06/2013  Dalit Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_sr_is_repeated_new(p_serial    IN VARCHAR2,
		          p_from_date IN DATE,
		          p_to_date   IN DATE) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_contract_entitlement
  --  create by:       Adi Safin
  --  Revision:        1.0
  --  creation date:   22/02/2017
  --------------------------------------------------------------------
  --  purpose :        function that check IB is under service contract or warranty
  --                   CHG0040155 - Used for service contract entitlement
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/02/2017  Adi Safin         CHG0040155 - initial build
  --  1.1  14/08/2017  Adi Safin         CHG0040196 - Add validation of technology between printer in order line
  --                                                  If technology is not the same - Discount won't given
  --------------------------------------------------------------------
  FUNCTION get_contract_entitlement(p_instance_id VARCHAR2,
			p_ol_item_id  IN NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            update_upg_instance_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   19/06/2017
  --------------------------------------------------------------------
  --  purpose :        This will be called from XXCS_HASP_PKG and XXCS_UPGRADE_IB_UPON_SHIPP_PKG
  --                   This procedure will help to update the Instance id of the Printer
  --                   in the Upgrade Line(Update Sales Order Line.Attribute1 of Upgrade Item line)
  --                   Instance id will fetched based on the Attribute15 of the Upgrade Item SO line
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/12/2012  Adi Safin         CHG0040890 - updated the upgrade advisor to support selling an upgrade in an initial sale
  --  1.1  13/08/2017  Adi Safin         CHG0040196 - Support features lookup (like Voxel) and update salesforce interface with new information
  --------------------------------------------------------------------
  PROCEDURE update_upg_instance_id(errbuf  OUT VARCHAR2,
		           retcode OUT VARCHAR2);
END xxcs_utils_pkg;
/
