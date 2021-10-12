CREATE OR REPLACE PACKAGE xxont_s3_legacy_int_pkg IS
  ----------------------------------------------------------------------------
  --  name:            xxont_s3_legacy_int_pkg
  --  create by:       TCS
  --  $Revision:       1.0
  --  creation date:   22/08/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package containing procedure to pull all the ASN information
  --                   from S3 and loading those information to Legacy environment
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  17/08/2016  TCS                    Initial build
  --  1.1  02/12/2016  Rohit                  Defect-635 -- Actual shipment date added
  --                                          Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments
  --  1.2  07/12/2016  Rohit                  Defect-635 -- ship_to_org_code is fetched from db_link
  --  1.3  13/12/2016  Rohit                  Defect-699
  --                                          1. line_location_id added to fetch unique records.
  --                                          2. Cursor added to fetch the error messages.
  --                                          3. Transit time to be considered in Drop Shipment case as well
  --                                          4. Serial Number Validation added for Issued out of stores
  ----------------------------------------------------------------------------

  PROCEDURE pull_asn(p_errbuf  OUT VARCHAR2,
                     p_retcode OUT NUMBER --,
                     --p_batch_size IN NUMBER
                     );

END xxont_s3_legacy_int_pkg;
/

