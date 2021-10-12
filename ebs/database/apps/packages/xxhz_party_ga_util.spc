CREATE OR REPLACE PACKAGE xxhz_party_ga_util AS
  --------------------------------------------------------------------
  -- $Header: http://sv-glo-tools01p.stratasys.dmn/svn/ERP/ebs/database/apps/packages/xxhz_party_ga_util.spc 3431 2017-06-05 08:38:19Z yuval.tal $
  --------------------------------------------------------------------
  --  name:            XXHZ_PARTY_GA_UTIL
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   26.12.10
  --------------------------------------------------------------------
  --  purpose :        global account pricing
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  26.12.10    yuval tal       initial build
  --  1.1  2.1.2011    yuval tal       add p_agreement to chk_sys_agreement_ga_interval+get_ga_system_agreement_cnt
  --                                   get_ga_system_agreement_cnt add logic
  --  1.2  05/07/2011  Dalit A. Raviv  add functions: get_primary_party_id
  --                                                  get_secondary_party_id
  --                                                  get_party_is_vested
  --  1.3  03/11/2011  yuval tal       add get_party_name4account to spec
  --  1.4  02/10/2011  Dalit A. Raviv  add function get_constant_discount
  --  1.5  19/01/2012  Dalit A. RAviv  add function is_vip
  --                                   Procedure update_vip_ga_party
  --  1.6  12/09/2013  Adi Safin       add function is_vip_without_ga
  --  1.7  09/07/2014  Gary Altman     CHG0032654 - check attributes value for SAM customers
  --------------------------------------------------------------------

  FUNCTION get_party_name4account(p_cust_account_id NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  FUNCTION get_parent_party_id(p_party_id NUMBER) RETURN NUMBER;
  --------------------------------------------------------------------
  FUNCTION get_parent_party_id4cust(p_cust_account_id NUMBER) RETURN NUMBER;
  --------------------------------------------------------------------
  FUNCTION get_party_name(p_party_id   NUMBER,
		  p_party_type VARCHAR2 DEFAULT 'ORGANIZATION')
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  FUNCTION get_ga_resin_kg_sold2party(p_party_id NUMBER) RETURN NUMBER;
  --------------------------------------------------------------------
  FUNCTION get_ga_resin_kg_sold2account(p_cust_account_id NUMBER)
    RETURN NUMBER;
  --------------------------------------------------------------------
  FUNCTION is_account_ga(p_cust_account_id NUMBER,
		 p_to_date         DATE DEFAULT SYSDATE)
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  FUNCTION is_party_ga(p_party_id NUMBER,
	           p_to_date  DATE DEFAULT SYSDATE) RETURN VARCHAR2;
  --------------------------------------------------------------------
  FUNCTION is_resin_item(p_item_id NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  FUNCTION is_system_item(p_item_id NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  FUNCTION get_line_weight_or_volume(p_uom_class          IN VARCHAR2,
			 p_inventory_item_id  IN NUMBER,
			 p_ordered_quantity   IN NUMBER,
			 p_order_quantity_uom IN VARCHAR2,
			 p_sold_to_org_id     IN NUMBER,
			 p_header_id          IN NUMBER)
    RETURN NUMBER;
  --------------------------------------------------------------------
  FUNCTION get_line_ga_system_count(p_inventory_item_id NUMBER,
			p_ordered_quantity  IN NUMBER,
			p_sold_to_org_id    IN NUMBER,
			p_header_id         IN NUMBER)
    RETURN NUMBER;
  --------------------------------------------------------------------
  FUNCTION get_line_ga_system_count2( /*p_inventory_item_id NUMBER,*/p_sold_to_org_id IN NUMBER,
			 p_header_id      IN NUMBER,
			 p_line_number    NUMBER) RETURN NUMBER;
  --------------------------------------------------------------------
  FUNCTION get_resin_lines4order(p_header_id NUMBER) RETURN NUMBER;
  --------------------------------------------------------------------
  FUNCTION get_party_id(p_cust_account_id NUMBER) RETURN NUMBER;
  --------------------------------------------------------------------
  FUNCTION get_system_ga_ib4acc(p_cust_account_id NUMBER /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                p_inventory_item_id NUMBER*/)
    RETURN NUMBER;
  --------------------------------------------------------------------
  FUNCTION get_ga_system_count_string(p_cust_account_id NUMBER)
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  FUNCTION get_ga_system_agreement_cnt(p_cust_account_id NUMBER,
			   p_agreement_id    NUMBER)
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  FUNCTION get_system_ga4related_orders( /*p_inventory_item_id NUMBER,*/p_sold_to_org_id IN NUMBER,
			    p_header_id      IN NUMBER)
    RETURN NUMBER;
  --------------------------------------------------------------------
  FUNCTION chk_sys_agreement_ga_interval(p_cust_account_id NUMBER,
			     p_min             NUMBER,
			     p_max             NUMBER,
			     p_agreement_id    NUMBER)
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            get_ga_average_discount
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   xx/xx/2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2011  Yuval Tal       initial build
  --  1.1  21/07/2011  Yuval Tal       correct calculation
  --  1.2  02/10/2011  Dalit A. Raviv  Add parameter p_party_id
  --------------------------------------------------------------------
  --------------------------------------------------------------------
  FUNCTION get_ga_average_discount(p_amount   NUMBER,
		           p_date     DATE,
		           p_party_id NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_ga_discount_steps
  --  create by:       Adi Safin
  --  Revision:        1.0
  --  creation date:   13/12/2012
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  13/12/2012  Adi Safin       initial build
  --------------------------------------------------------------------
  FUNCTION get_ga_discount_steps(p_amount   NUMBER,
		         p_date     DATE,
		         p_party_id NUMBER) RETURN NUMBER;
  --------------------------------------------------------------------
  FUNCTION get_system_ib4party(p_party_id NUMBER /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     p_inventory_item_id NUMBER*/)
    RETURN NUMBER;
  --------------------------------------------------------------------
  --  name:            get_party_is_vested
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/07/2011
  --------------------------------------------------------------------
  --  purpose :        Vested = ‘Y’ – should consider the following:
  --                   1) GA Creation Date < GA Program Date
  --                   2) 2 systems were already bought by the GA (after GA Program Date)
  --                   3) The GA has no Active Primary Dealer Party Relationship
  --                   Vested = ‘N’ – if do not answear to any of the abouve case
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  05/07/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_party_is_vested(p_party_id IN NUMBER,
		       p_order_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_party_is_vested
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/07/2011
  --------------------------------------------------------------------
  --  purpose :        Get GA party id and return the primary party id that connect to it
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  05/07/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_primary_party_id(p_party_id        IN NUMBER,
		        p_cust_account_id IN NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_party_is_vested
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/07/2011
  --------------------------------------------------------------------
  --  purpose :        Get GA party id and return the secondary party id that connect to it
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  05/07/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_secondary_party_id(p_party_id        IN NUMBER,
		          p_cust_account_id IN NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            get_parent_ga_start_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/07/2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  05/07/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_parent_ga_start_date(p_party_id IN NUMBER) RETURN DATE;

  --------------------------------------------------------------------
  --  name:            get_party_is_vested_resin
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/07/2011
  --------------------------------------------------------------------
  --  purpose :        Vested = ‘Y’ – should consider the following:
  --                   1) GA Creation Date < GA Program Date
  --                   2) For the first & second deals (sold systems after GA Program Date) –
  --                      in order to be consider ‘Resin Vested’,  2 years should passed since
  --                      last Sales Order fulfillment date
  --                   3)The GA has no Active Primary Dealer Party Relationship
  --                   Vested = ‘N’ – if do not answear to any of the abouve case
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  13/07/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_party_is_vested_resin(p_party_id         IN NUMBER,
			 p_fullfilment_date IN DATE)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            get_constant_discount
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   02/10/2011
  --------------------------------------------------------------------
  --  purpose :        get constant discount for party
  --                   if do not have constant discount return 0.
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  02/10/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_constant_discount(p_party_id IN NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            is_vip
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/01/2012
  --------------------------------------------------------------------
  --  purpose :        check party if it is VIP
  --                   Return Y / N
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  19/01/2012  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION is_vip(p_party_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            is_vip_without_ga
  --  create by:       Adi Safin
  --  Revision:        1.0
  --  creation date:   12/09/2013
  --------------------------------------------------------------------
  --  purpose :        check party if it is VIP
  --                   Return Y / N
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  12/09/2013  Adi Safin      initial build
  --------------------------------------------------------------------
  FUNCTION is_vip_without_ga(p_party_id NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            update_vip_ga_party
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/01/2012
  --------------------------------------------------------------------
  --  purpose :        once a day run on all GA parties check that attribute7
  --                   is null -> check if GA party. If Yes update attribute7 with Y
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  29/01/2012  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE update_vip_ga_party(errbuf  OUT VARCHAR2,
		        retcode OUT VARCHAR2);
  -----------------Gary Altman  CHG0032654  ver 1.7 ------------------
  FUNCTION check_sam_attribute(p_party_id NUMBER) RETURN VARCHAR2;

END xxhz_party_ga_util;
/
