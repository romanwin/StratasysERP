CREATE OR REPLACE PACKAGE xxconv_purchasing_entities_pkg IS

   -- Author  : ELLA.MALCHI
   -- Created : 14/6/2009 17:00:14
   -- Purpose : Purchasing entities conversions

   -- Public type declarations
   PROCEDURE load_quotations(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

   /*Generate FROM PO_CREATE_SR_ASL.CREATE_ASL*/
   PROCEDURE load_asl(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

   /*Generate FROM PO_CREATE_SR_ASL.Create_Sourcing_Rule*/
   PROCEDURE load_sourcing_rule(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
   
   PROCEDURE load_po_blanket_lines(errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_po_segment1 IN VARCHAR2);
   
   PROCEDURE load_fdm_category_assignments(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

END xxconv_purchasing_entities_pkg;
/
