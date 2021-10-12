CREATE OR REPLACE PACKAGE xxconv_hz_relationship_pkg IS

   PROCEDURE create_cust_acct_rel(errbuf  out varchar2,
                                  retcode out varchar2);
   PROCEDURE create_end_customer_rel(errbuf  out varchar2,
                                  retcode out varchar2);
   PROCEDURE Mark_Duplicates (P_relation_type in Varchar2);

END xxconv_hz_relationship_pkg;
/
