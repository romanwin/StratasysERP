CREATE OR REPLACE PACKAGE xxwip_chem_lot_genealogy IS

   -- Author  : ERAN.BARAM
   -- Created : 13/09/2009 10:40:49
   -- Purpose : Maintain tracking of lots genealogy for finished goods.

   -- Public function and procedure declarations
   PROCEDURE xxwip_match_lots(errbuf      OUT VARCHAR2,
                              retcode     OUT VARCHAR2,
                              p_job       VARCHAR2,
                              p_child_lot VARCHAR2,
                              p_org_id    NUMBER,
                              p_trx_id    NUMBER);

END xxwip_chem_lot_genealogy;
/

