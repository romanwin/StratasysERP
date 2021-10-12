CREATE OR REPLACE PACKAGE xxoe_dflt_rules_pkg
-- ----------------------------------------------------------------------------------------
--  Name        : xxoe_dflt_rules_pkg
--  Created By  : mmazanet
--
--  Purpose     : Package to hold defaulting rules for OM.
--
--  Ver Date        Name          Description
-- -----------------------------------------------------------------------------------------
--  1.0 12/01/2015  mmazanet      CHG0033020. Initial Creation
--  1.1 11/09/2015  Diptasurjya   CHG0036423 - New funtion added for shipping method defaulting
--                  Chatterjee                 for dangerous items - ship_method_default_rule
--  1.2 13/08/2015  Michal Tzvik  CHG0035224 - New fuctions: default_political_warehouse, default_political_subinventory
--  1.3 22-NOV-2015 Sandeep Akula CHG0037039 - Added New Function freight_terms_default_rule
--  1.4 05-Apr-2017 Rimpi         CHG0040568: Default  a value in Intermediate ship to field at order header line in order to create separate deliveries for DG items--  1.0  22.10.17       YUval tal            CHG0040750
--  1.5  22.10.17   Yuval tal     CHG0040750 add default_ou_functional_currency
-- -----------------------------------------------------------------------------------------
 AS
  FUNCTION default_us_warehouse(p_database_object_name IN VARCHAR2,
		        p_attribute_code       IN VARCHAR2)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:              default_political_warehouse
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     28/07/2015
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  28/07/2015    Michal Tzvik        CHG0035224 - initial build
  --------------------------------------------------------------------
  FUNCTION default_political_warehouse(p_database_object_name IN VARCHAR2,
			   p_attribute_code       IN VARCHAR2)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:              default_political_subinventory
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     13/08/2015
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  13/08/2015    Michal Tzvik     CHG0035224 - initial build
  --------------------------------------------------------------------
  FUNCTION default_political_subinventory(p_database_object_name IN VARCHAR2,
			      p_attribute_code       IN VARCHAR2)
    RETURN VARCHAR2;

  -- ----------------------------------------------------------------------------------------
  --  Purpose : Defaults the shipping_method_code on the order line depending on the item_ordered
  --            If item is hazardous material, the Shipping Method is to be set with the value from
  --            profile option XXOM_DEFAULT_SM_FOR_DANGEROUS_ITEM
  --  ----------------------------------------------------------------------------------------
  --  Ver Date        Name          Description
  -- -----------------------------------------------------------------------------------------
  --  1.0 09/10/2015  Diptasurjya   CHG0036423 - Initial Build
  --                  Chatterjee
  -- -----------------------------------------------------------------------------------------
  FUNCTION ship_method_default_rule(p_database_object_name IN VARCHAR2,
			p_attribute_code       IN VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    freight_terms_default_rule
  Author's Name:   Sandeep Akula
  Date Written:    22-NOV-2015
  Purpose:         This Function defaults the freight terms on the order line depending on the Item Ordered.
                   If the Item is Dangerous good and WareHosue is USE and if Order type is listed in Lookup XXOE_DG_ITEM_FREIGHT_TERM then freight terms is
                   derived from the Lookup code description else it defaults to the value from profile option XXOE_DEFAULT_FT_FOR_DANGEROUS_ITEM
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  22-NOV-2015        1.0                  Sandeep Akula     Initial Version -- CHG0037039
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION freight_terms_default_rule(p_database_object_name IN VARCHAR2,
			  p_attribute_code       IN VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    salesperson_default_rule
  Author's Name:   Diptasurjya Chatterjee
  Date Written:    03-DEC-2015
  Purpose:         This Function defaults the Salesrep on the order header depending on the Order Type
                   If Order Type is not listed in the Lookup XXOE_SALESREP_ORDER_TYPE then function
                   defaults salesrep with attribute1 value from lookup otherwise it will return null
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version            Name            Remarks
  -----------    ----------------   -------------   ------------------
  03-DEC-2015    1.0                Diptasurjya     Initial Version -- CHG0037039
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION salesperson_default_rule(p_database_object_name IN VARCHAR2,
			p_attribute_code       IN VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            default_inter_loc_DG_item
  --  create by:       Rimpi
  --  Revision:        1.0
  --  creation date:   01-Mar-2016
  --------------------------------------------------------------------
  --  ver  date              name              desc
  --  1.0  05-Apr-2017 Rimpi               CHG0040568: Default  a value in Intermediate ship to field at order header line in order to create separate deliveries for DG items
  --------------------------------------------------------------------

  FUNCTION default_inter_loc_dg_item(p_database_object_name IN VARCHAR2,
			 p_attribute_code       IN VARCHAR2)
    RETURN NUMBER;

  FUNCTION default_ou_functional_currency(p_database_object_name IN VARCHAR2,
			      p_attribute_code       IN VARCHAR2)
    RETURN VARCHAR2;

END xxoe_dflt_rules_pkg;
/
