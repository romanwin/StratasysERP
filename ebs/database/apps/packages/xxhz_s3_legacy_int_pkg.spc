CREATE OR REPLACE PACKAGE xxhz_s3_legacy_int_pkg IS
  ----------------------------------------------------------------------------
  --  name:            xxhz_s3_legacy_int_pkg
  --  create by:       TCS
  --  $Revision:       1.0
  --  creation date:   17/08/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package containing procedure to pull all the customer information(Account,Contact Point,Contact,Relationship)
  --                   from S3 and loading those information to Legacy environment
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  17/08/2016  TCS                    Initial build
  ----------------------------------------------------------------------------

  PROCEDURE pull_account(p_errbuf     OUT VARCHAR2,
                         p_retcode    OUT NUMBER,
                         p_batch_size IN NUMBER);

  PROCEDURE pull_contact_point(p_errbuf     OUT VARCHAR2,
                               p_retcode    OUT NUMBER,
                               p_batch_size IN NUMBER);

  PROCEDURE pull_contact(p_errbuf     OUT VARCHAR2,
                         p_retcode    OUT NUMBER,
                         p_batch_size IN NUMBER);

  PROCEDURE pull_relationship(p_errbuf     OUT VARCHAR2,
                              p_retcode    OUT NUMBER,
                              p_batch_size IN NUMBER);

  PROCEDURE pull_acc_relationship(p_errbuf     OUT VARCHAR2,
                                  p_retcode    OUT NUMBER,
                                  p_batch_size IN NUMBER);

  PROCEDURE pull_acct_site(p_errbuf     OUT VARCHAR2,
                           p_retcode    OUT NUMBER,
                           p_batch_size IN NUMBER);

  PROCEDURE pull_acct_site_use(p_errbuf     OUT VARCHAR2,
                               p_retcode    OUT NUMBER,
                               p_batch_size IN NUMBER);
END xxhz_s3_legacy_int_pkg;
/
