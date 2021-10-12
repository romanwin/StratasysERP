CREATE OR REPLACE PACKAGE xxhz_util AS
  --------------------------------------------------------------------
  --  name:            XXHZ_UTIL
  --  create by:       XXX
  --  Revision:        1.2
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :        global account pricing
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    17.01.11    yuval tal        Initial Build
  --  1.1    23.4.13     yuval tal        add get_operating_unit_name,get_ou_lang
  --  1.2    10/12/2013  Dalit A. Raviv   add functions: get_customer_email and Get_customer_mail_ar_letter
  --  1.3    16/11/2014  Michal Tzvik     Add functions: get_parent_customer_location, get_so_parent_cust_location
  --  1.4    07.01.2015  Michal Tzvik     CHG0034052: Add function get_party_id_of_site_use_id
  --  1.7    15.06.2015  Diptasurjya      CHG0035560: Add function get_account_id_of_site_use_id
  --                     Chatterjee
  --  1.8    29.06.2015  Diptasurjya      CHG0035652: Add function is_ecomm_customer, which
  --                     Chatterjee                   returns TRUE for accounts which have at least
  --                                                  1 contact with eCommerce flag marked 'Y', else FALSE is returned
  --  1.9    05.08.2015  Diptasurjya      CHG0034981: New function added check_education_customer. Returns TRUE is site_use_id
  --                     Chatterjee                   belongs to education classification enabled customer
  --  2.0    08-MAR-2021 Diptasurjya      CHG0049516 - Add new function get_customer_subindustry
  --  2.1    12.5.21     yuval tal        CHG0049822 add get_account_num_of_site_use_id
  --------------------------------------------------------------------

  FUNCTION get_phone(p_party_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_fax(p_party_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_ou_lang(p_org_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_operating_unit_name(p_org_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_party_name_tl(p_party_id NUMBER,
		     p_org_id   NUMBER) RETURN VARCHAR2;
  FUNCTION get_inv_org_ou(p_organization_id NUMBER) RETURN NUMBER;
  FUNCTION get_territory_tl(p_territory_code VARCHAR2,
		    p_org_id         NUMBER) RETURN VARCHAR2;
  FUNCTION get_customer_industry(p_party_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  purpose :        CHG0049822  Interface initial build  used in view XXOM_GC_ACC_FEATURE_SOA_V
  --------------------------------------------------------------------
  --  ver    date        name       desc
  --  1.0    12.5.21  yuval tal     CHG0049822 Initial Build
  --------------------------------------------------------------------
  FUNCTION get_account_num_of_site_use_id(p_site_use_id NUMBER)
    RETURN VARCHAR2;

  -------------------------------------------
  -- get_customer_sub_industry
  --------------------------------------------------------------------
  --  ver    date          name             desc
  --  1.0    02-MAR-2021   Diptasurjya      CHG0049516 - intial build
  -------------------------------------------
  FUNCTION get_customer_subindustry(l_cust_account_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_customer_email
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   10/12/2013
  --------------------------------------------------------------------
  --  purpose :        general function to get by table level Customer email
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    10/12/2013  Dalit A. Raviv   Initial Build
  --------------------------------------------------------------------
  FUNCTION get_customer_email(p_owner_table_name IN VARCHAR2,
		      p_owner_table_id   IN NUMBER,
		      p_primary          IN VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            Get_customer_mail_ar_letter
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   10/12/2013
  --------------------------------------------------------------------
  --  purpose :        CR1022 Customer balance report
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    10/12/2013  Dalit A. Raviv   Initial Build
  --------------------------------------------------------------------
  FUNCTION get_customer_mail_ar_letter(p_account_number IN VARCHAR2)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_parent_customer_location
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0033422   Sales Discount Bucket Program
  --                   get parent customer location from value sets
  --                   'XXGL_COMPANY_SEG', 'XXGL_LOCATION_SEG'
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build
  --------------------------------------------------------------------
  FUNCTION get_parent_customer_location(p_site_use_id NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            get_so_parent_cust_location
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0033422   Sales Discount Bucket Program
  --                   get parent customer location from value sets
  --                   'XXGL_COMPANY_SEG', 'XXGL_LOCATION_SEG'
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build
  --------------------------------------------------------------------
  FUNCTION get_so_parent_cust_location(p_header_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            is_permission_by_org
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   04/12/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0033422   Sales Discount Bucket Program
  --                   get value of dff 'permission_by_org' from value sets
  --                   'XXGL_COMPANY_SEG'
  --                   In order to allow restrict population by org_id and
  --                   not just by parent location.
  --
  -- return Y/ N
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    04/12/2014  Michal Tzvik     Initial Build
  --------------------------------------------------------------------
  FUNCTION is_permission_by_org(p_org_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_party_name_of_site_use_id
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   07/01/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034052  New personalization to support EMEA Resin pilot
  --                   get party name of current site use id
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    07/01/2015  Michal Tzvik     Initial Build
  --------------------------------------------------------------------
  FUNCTION get_party_id_of_site_use_id(p_site_use_id NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_account_id_of_site_use_id
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   07/01/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035560  New customization to get account_id
  --                   from current site use id
  --------------------------------------------------------------------
  --  ver    date        name                       desc
  --  1.0    07/01/2015  Diptasurjya Chatterjee     Initial Build
  --------------------------------------------------------------------
  FUNCTION get_account_id_of_site_use_id(p_site_use_id NUMBER) RETURN NUMBER;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function checks whether customer is eCommerce customer or not.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  29/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION is_ecomm_customer(p_cust_account_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_account_id_of_site_use_id
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   08/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034981  New customization to check if site use id
  --                   belongs to Education customer.
  --------------------------------------------------------------------
  --  ver    date        name                       desc
  --  1.0    08/05/2015  Diptasurjya Chatterjee     Initial Build
  --------------------------------------------------------------------
  FUNCTION check_education_customer(p_site_use_id     NUMBER,
			p_cust_account_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            is_LATAM_customer
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/02/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034518 - by customer site get if this customer relate to LATAM
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    05/02/2015  Dalit A. Raviv   Initial Build
  --------------------------------------------------------------------
  FUNCTION is_latam_customer(p_site_use_id IN NUMBER,
		     p_site_id     IN NUMBER,
		     p_customer_id IN NUMBER) RETURN VARCHAR2;

END;
/
