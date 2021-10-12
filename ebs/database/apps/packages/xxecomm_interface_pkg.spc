CREATE OR REPLACE PACKAGE xxecomm_interface_pkg IS
  --------------------------------------------------------------------
  --  name:            XXECOMM_INTERFACE_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2013 14:46:24
  --------------------------------------------------------------------
  --  purpose :        CUST674 - eCommerce Integration
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            set_env_param
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2013 14:46:24
  --------------------------------------------------------------------
  --  purpose :        CUST674 - eCommerce Integration
  --                   from profile set the environment parameters to send to BPEL
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE set_env_param;

  --------------------------------------------------------------------
  --  name:            submit_Ecomm_bpel
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2013 14:46:24
  --------------------------------------------------------------------
  --  purpose :        CUST674 - eCommerce Integration
  --                   from profile set the environment parameters to send to BPEL
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE submit_ecomm_bpel(errbuf  OUT VARCHAR2,
                              retcode OUT VARCHAR2,
                              p_type  IN VARCHAR2,
                              --p_fetch_size     in  number,
                              p_days_back IN VARCHAR2,
                              p_active_yn IN VARCHAR2,
                              p_ou_id     IN NUMBER,
                              p_from_seq  IN NUMBER,
                              p_to_seq    IN NUMBER);

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/06/2013 14:46:24
  --------------------------------------------------------------------
  --  purpose :        CUST674 - eCommerce Integration
  --                   main program that by loop will call to BPEL.
  --                   otherwise we get memory problem.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf       OUT VARCHAR2,
                 retcode      OUT VARCHAR2,
                 p_type       IN VARCHAR2,
                 p_fetch_size IN NUMBER,
                 p_days_back  IN VARCHAR2,
                 p_active_yn  IN VARCHAR2,
                 p_ou_id      IN NUMBER);

--FUNCTION is_ship_site_exists(p_cust_number VARCHAR2) RETURN VARCHAR2;

END xxecomm_interface_pkg;
/
