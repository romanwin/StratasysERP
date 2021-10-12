CREATE OR REPLACE PACKAGE xxconv_initialize_inv_pkg IS

   -- Author  : DMN_SARIF
   -- Created : 15/08/2007 13:22:19
   -- Purpose : Objet Initialize
   --------------------------------------------------
   -----------------------------------------------------------
   PROCEDURE misc_receive_int(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
   ------------------------------------------------------------

   PROCEDURE upload_locators(errbuf OUT VARCHAR2, retcode OUT NUMBER);

   PROCEDURE upload_items_cost(errbuf           OUT VARCHAR2,
                               retcode          OUT VARCHAR2,
                               p_operating_unit IN NUMBER);
                               
   PROCEDURE update_items_cost(errbuf           OUT VARCHAR2,
                               retcode          OUT VARCHAR2,
                               trx_date         IN VARCHAR2,
                               account_num      IN VARCHAR2,
                               p_operating_unit IN NUMBER);
                               
END xxconv_initialize_inv_pkg;
/

