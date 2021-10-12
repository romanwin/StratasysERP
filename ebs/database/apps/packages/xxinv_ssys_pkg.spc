CREATE OR REPLACE PACKAGE xxinv_ssys_pkg IS

  --------------------------------------------------------------------
  --  customization code: CUST540 - FDM Items Creation Program
  --  name:               XXINV_SSYS_PKG
  --                            
  --  create by:          vitaly
  --  $Revision:          1.0 
  --  creation date:      8.11.12
  --  Purpose:            FDM Items Creation Program
  --------------------------------------------------------------------
  --  ver   date          name             desc
  --  1.0   8.11.12       vitaly           initial build  

  -------------------------------------------------------------------- 

  PROCEDURE create_new_ssys_items(errbuf  OUT VARCHAR2,
                                  retcode OUT VARCHAR2);

  PROCEDURE update_ssys_items_min_max(errbuf  OUT VARCHAR2,
                                      retcode OUT VARCHAR2);

  PROCEDURE add_lines_to_blanket_po(errbuf  OUT VARCHAR2,
                                    retcode OUT VARCHAR2);

  PROCEDURE add_ssys_item_cost(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

END xxinv_ssys_pkg;
/
