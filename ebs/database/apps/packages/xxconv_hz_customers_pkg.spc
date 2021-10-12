CREATE OR REPLACE PACKAGE xxconv_hz_customers_pkg IS

  ---------------------------------------------------------------------------------
  -- Entity Name: xxconv_hz_customers_pkg
  -- Purpose    : CREATING CUSTOMERS
  -- Author     : Evgeniy Braiman
  -- Version    : 1.0
  ---------------------------------------------------------------------------------
  -- Version    Date       Author         Description
  ---------------------------------------------------------------------------------
  -- 1.0       28.6.05     Evgeniy         Initial Build
  -- 1.1       08/03/2010  Dalit A. Raviv  add procedure upd_cust_site_use
  -- 1.2       11/03/2010  Dalit A. Raviv  add procedure upd_party_site_att
  --                                                     upd_entity_id_for_prog
  -- 1.3       20/10/2010  Dalit A. Raviv  add procedure create_sf_contact,
  --                                                     upload_contact_point
  -- 1.4       15/11/2011  Dalit A. raviv  add procedure upload_cti_contact_phones
  ---------------------------------------------------------------------------------
  -- 2.0       20/08/2013  Venu Kandi      Modified for US data migrations
  ---------------------------------------------------------------------------------

  PROCEDURE main(errbuf  OUT VARCHAR2,
	     errcode OUT VARCHAR2);

  -- Dalit A. Raviv 08/03/2010
  PROCEDURE upd_cust_site_use(errbuf  OUT VARCHAR2,
		      retcode OUT VARCHAR2);

  -- Dalit A. Raviv 11/03/2010
  PROCEDURE upd_party_site_att(errbuf  OUT VARCHAR2,
		       retcode OUT VARCHAR2);

  -- Dalit A. Raviv 11/03/2010
  PROCEDURE upd_entity_id_for_prog;

  -- Dalit A. Raviv 20/10/2010
  PROCEDURE create_sf_contact(errbuf  OUT VARCHAR2,
		      retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            upload_contact_point
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/10/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        upload from excel email address for contacts.
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  20/10/2010  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE upload_contact_point(errbuf  OUT VARCHAR2,
		         retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            upload_cti_contact_phones
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/11/2011
  --------------------------------------------------------------------
  --  purpose :        upload from excel contacts phones for CTI project
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  15/11/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE upload_cti_contact_phones(errbuf     OUT VARCHAR2,
			  retcode    OUT VARCHAR2,
			  p_location IN VARCHAR2, -- /UtlFiles/HR
			  p_filename IN VARCHAR2);

  PROCEDURE create_profile(p_cust_account_id    IN NUMBER,
		   p_customer_name      IN VARCHAR2,
		   p_party_id           IN NUMBER,
		   p_bill_site_use_id   IN NUMBER DEFAULT NULL,
		   p_prof_class         IN VARCHAR2 DEFAULT 'DEFAULT',
		   p_collector          IN VARCHAR2,
		   p_credit_check       IN VARCHAR2,
		   p_credit_hold        IN VARCHAR2,
		   p_currency           IN VARCHAR2,
		   p_credit_limit       IN NUMBER,
		   p_order_credit_limit IN NUMBER,
		   p_return_status      OUT VARCHAR2,
		   p_err_msg            OUT VARCHAR2);

END xxconv_hz_customers_pkg;
/
