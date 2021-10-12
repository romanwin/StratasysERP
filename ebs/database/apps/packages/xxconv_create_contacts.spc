CREATE OR REPLACE PACKAGE xxconv_create_contacts IS

  PROCEDURE create_party_person(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

END xxconv_create_contacts;
/
