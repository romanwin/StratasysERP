CREATE OR REPLACE PACKAGE xxhz_duplicates AS
--------------------------------------------------------------------
--  name:            XXHZ_DUPLICATES
--  create by:       Diptasurjya Chatterjee
--  Revision:        1.1
--  creation date:   10/01/2014 
--------------------------------------------------------------------
--  purpose : Packaged used for dealing with duplicate in the HZ 
--            customer module
--
--------------------------------------------------------------------
--  ver  date        name                      desc
--  1.0  10/01/2015  Diptasurjya Chatterjee    CHG0034258.  initial build
--------------------------------------------------------------------
  FUNCTION dup_cust_site_wrapper (p_address1                  IN VARCHAR2,
                                  p_address2                  IN VARCHAR2,
                                  p_address3                  IN VARCHAR2,
                                  p_address4                  IN VARCHAR2,
                                  p_city                      IN VARCHAR2,
                                  p_state                     IN VARCHAR2,
                                  p_province                  IN VARCHAR2,
                                  p_postal_code               IN VARCHAR2,
                                  p_country                   IN VARCHAR2,
                                  p_location_id               IN NUMBER,
                                  p_cust_account_id           IN NUMBER) return varchar2;
END xxhz_duplicates; 
/
