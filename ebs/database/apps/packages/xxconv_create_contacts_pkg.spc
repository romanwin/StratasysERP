CREATE OR REPLACE PACKAGE xxconv_create_contacts_pkg IS

   PROCEDURE create_party_person(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
   Procedure Split_First_Last_Name;
   
END xxconv_create_contacts_pkg;
/

