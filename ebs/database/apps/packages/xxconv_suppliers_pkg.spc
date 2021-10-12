create or replace PACKAGE xxconv_suppliers_pkg IS
-------------------------------------------------------------------
--       Owner : Stratasys Inc
-- Application : Stratasys (Objet) Customizations
--   File Name : XXCONV_SUPPLIERS_PKG.pks
--        Date : 08-AUG-13
--      Author : Venu Kandi
-- Description : Package to load Syteline suppliers to Oracle
--
--   Called By : sqlplus
--      Output : standard out
--
-- Table and View  Table Name                Sel  Ins  Upd  Del
-- Usage:          ~~~~~~~~~~                ~~~  ~~~  ~~~  ~~~
--                xxobjt_conv_suppliers       X    X    X
--                xxobjt_conv_supp_contacts   X    X    X
--                xxobjt_conv_suppliers_comm  X    X    X
--                ap_suppliers_int            X    X
--                ap_supplier_sites_int       X    X
--                ap_suppliers                X         X
--                ap_supplier_sites_all       X         X
--
-- Modification History :
-- Who          Date         Reason
-- ~~~~~~~~~~~~ ~~~~~~~~~~   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- v.kandi        08-AUG-13    Created by IL. Adopted by US for loading
--                           Syteline Suppliers to Oracle
-- Mandar-Eric H  30-APR-21  CHG0049229 Added Parameters for create_supplier_contact
---------------------------------------------------------------------------------------

   PROCEDURE xxconv_create_supplier_api(errbuf  OUT VARCHAR2,
                                        retcode OUT VARCHAR2);

   PROCEDURE create_bank_api(errbuf  OUT VARCHAR2,
   			                 retcode OUT VARCHAR2);

   PROCEDURE update_taxpayer_id;

   PROCEDURE create_supplier_contact(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);--CHG0049229 -added parameters

   PROCEDURE upload_fax;

   PROCEDURE vendor_notif_method(errbuf  OUT VARCHAR2,
                                 retcode OUT VARCHAR2);

   PROCEDURE Fix_Cust_Oper_Unit_Attribute(errbuf  OUT VARCHAR2,
                                          retcode OUT VARCHAR2);

   PROCEDURE Upd_LegSuppName;

   PROCEDURE Fix_hold_flags;

END xxconv_suppliers_pkg;
/
