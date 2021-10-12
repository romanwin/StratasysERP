create or replace package xxwsh_delivery_info_pkg IS

  --------------------------------------------------------------------
  --  name:            XXWSH_DELIVERY_INFO_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/03/2015 14:11:28
  --------------------------------------------------------------------
  --  purpose :        CHG0034230 - Commercial Invoice modifications
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/03/2015  Dalit A. Raviv    initial build
  --  1.2  18/Jun/2015 Dalit A. Raviv    CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --                                     new functions: get_customs_price, get_price_list_distribution,
  --                                     get_parent_line_id, get_parent_line_price
  --                                     Update functions: get_line_unit_price, get_line_discount_percent
  --  1.3  06-Sep-2015 Dalit A. Raviv    CHG0036018 - Commercial invoice modifications
  --                                     add function - get_country_of_origion
  --  1.4  26-Sep-2019 Bellona(TCS)      CHG0046167 - Packing List Reports
  --									 add functions - get_gross_weight, get_chargeable_weight
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               show_in_doc
  --  create by:          Dalit A. Raviv
  --  creation date:      24/03/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   24/03/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION show_parent_in_doc(p_line_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               show_in_doc
  --  create by:          Dalit A. Raviv
  --  creation date:      24/03/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   24/03/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION show_child_in_doc(p_line_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_parent_item
  --  create by:          Dalit A. Raviv
  --  creation date:      29/03/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/03/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_parent_item(p_line_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_parent_line_discount
  --  create by:          Dalit A. Raviv
  --  creation date:      29/03/2015
  --  In param:           p_entity - BUNDLE/ PTO
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/03/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_parent_line_discount(p_entity  IN VARCHAR2,
			p_line_id IN NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_parent_item
  --  create by:          Dalit A. Raviv
  --  creation date:      29/03/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/03/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_line_discount_percent(p_line_id IN NUMBER,
			 p_index   IN NUMBER DEFAULT 0)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_line_unit_price
  --  create by:          Dalit A. Raviv
  --  creation date:      29/03/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   29/03/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_line_unit_price(p_line_id IN NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_delivery_total_amount
  --  create by:          Dalit A. Raviv
  --  creation date:      16/04/2015
  --  Purpose :           CHG0034736 GTMS - Carriers
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16/04/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  PROCEDURE get_delivery_total_amount(p_delivery_id      IN NUMBER,
			  p_curr_code        OUT VARCHAR2,
			  p_delivery_tot_amt OUT NUMBER);

  --------------------------------------------------------------------
  --  customization code: CHG0034230
  --  name:               get_collect_shipping_account
  --  create by:          Dalit A. Raviv
  --  creation date:      16/04/2015
  --  Purpose :           CHG0034736 GTMS - Carriers
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16/04/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_collect_shipping_account(p_delivery_id IN NUMBER)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --  name:               get_customs_price
  --  create by:          Dalit A. Raviv
  --  creation date:      18/06/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/06/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_customs_price(p_line_id IN NUMBER) RETURN NUMBER; -- return the list price

  --------------------------------------------------------------------
  --  customization code: CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --  name:               get_price_list_distribution
  --  create by:          Dalit A. Raviv
  --  creation date:      18/06/2015
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/06/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_price_list_distribution(p_so_line_id IN NUMBER,
			   p_entity     IN VARCHAR2)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  customization code: CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --  name:               get_parent_line_id
  --  create by:          Dalit A. Raviv
  --  creation date:      18/06/2015
  --  Purpose :           get om line id and return parent line id
  --                      Applied only if the Item is a PTO Option or a Bundle Component.
  --                      p_entity - PTO/BUNDLE
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/06/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_parent_line_id(p_line_id IN NUMBER,
		      p_entity  IN VARCHAR2) RETURN NUMBER;

  --------------------------------------------------------------------
  --  customization code: CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --  name:               get_parent_line_price
  --  create by:          Dalit A. Raviv
  --  creation date:      23/06/2015
  --  Purpose :           get om line id and return parent line id price
  --                      Applied only if the Item is a PTO Option or a Bundle Component.
  --                      p_entity - PTO/BUNDLE
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/06/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_parent_line_price(p_line_id IN NUMBER,
		         p_entity  IN VARCHAR2) RETURN NUMBER;

  --------------------------------------------------------------------
  --  customization code: CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --  name:               is_pto_component
  --  create by:          Dalit A. Raviv
  --  creation date:      06/07/2015
  --  Purpose :           get om line id and return if item is a PTO component (but not option class)
  --                      return Y/N
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/06/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION is_pto_component(p_line_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0035672 - Commercial Invoice Pricing and Discount change Logic
  --  name:               is_pto_component
  --  create by:          Dalit A. Raviv
  --  creation date:      06/07/2015
  --  Purpose :           get om line id and return if item is a PTO parent
  --                      return Y/N
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/06/2015    Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION is_pto_parent(p_line_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0036018 - Commercial invoice modifications
  --  name:               get_country_of_origin
  --  create by:          Dalit A. Raviv
  --  creation date:      06-Sep-2015
  --  Purpose :           Change logic for the source of Country of Origion COO
  --                      Delivery Country of Origin COO is not null -> COO = Delivery COO
  --                      Delivery COO is null  -> is item lot control -> Y COO = lot COO (nvl to item COO)
  --                                            -> if item lot control -> N COO = Item COO
  --                      Delivery COO = wsh_delivery_details.attribute1
  --                      Lot COO      = mtl_lot_numbers.attribute1
  --                      Item COO     = mtl_system_items_b.attribute2
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06-Sep-2015   Dalit A. Raviv  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_country_of_origin(p_wdd_coo           IN VARCHAR2,
		         p_inventory_item_id IN NUMBER,
		         p_organization_id   IN NUMBER,
		         p_lot_number        IN VARCHAR2,
		         p_msi_coo           IN VARCHAR2)
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  customization code: CHG0046167 - Packing list report - logic to calculate chargeable weight
  --  name:               get_chargeable_weight
  --  create by:          Bellona(TCS)
  --  creation date:      25/09/2019
  --  Purpose :           calculate chargeable weight based on weight and length measurement
  --                      units.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/09/2019    Bellona(TCS)  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_chargeable_weight(p_weight_uom IN VARCHAR2,
                                 p_attribute2 IN VARCHAR2,
                                 p_attribute3 IN VARCHAR2,
                                 p_attribute4 IN VARCHAR2,
                                 p_attribute5 IN VARCHAR2,
                                 p_net_weight IN NUMBER,
                                 p_count      IN NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  customization code: CHG0046167 - Packing list report - logic to calculate gross weight
  --  name:               get_gross_weight
  --  create by:          Bellona(TCS)
  --  creation date:      25/09/2019
  --  Purpose :           calculate gross weight, based on comparison with net weight
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/09/2019    Bellona(TCS)  Initial Build
  ----------------------------------------------------------------------
  FUNCTION get_gross_weight(p_net_weight IN NUMBER,
                            p_gross_weight IN NUMBER) RETURN NUMBER;

END xxwsh_delivery_info_pkg;
/