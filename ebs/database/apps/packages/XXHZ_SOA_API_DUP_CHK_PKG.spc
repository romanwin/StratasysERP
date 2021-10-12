CREATE OR REPLACE PACKAGE xxhz_soa_api_dup_chk_pkg IS
  --------------------------------------------------------------------
  --  name:               xxinv_item_classification
  --  create by:          yuval tal
  --  Revision:           1.0
  --  creation date:      1.4.20
  --------------------------------------------------------------------
  --  purpose:      XXHZ_SOA_API_DUP_CHK_PKG  methods
  --------------------------------------------------------------------
  --  ver   date        name         desc
  --  ----  ----------  ----------   ---------------------------------
  --  1.0   1.4.20      yuval tal    CHG0047624 initial build
  --  1.1   21/04/2020  Roman W.     CHG0047750 - check account duplications
  --                                         added procedure : upsert_account_dup_chk
  --  1.2   06/05/2020  Roman W.     CHG0047750 - added C_CHECK_DUPLICATE
  --  1.3   10/12/2020  Roman W.     CHG0047450 - added procedure : update_to_error_trx 
  --------------------------------------------------------------------

  PROCEDURE purge(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

  PROCEDURE insert_trx(p_rec IN OUT xxhz_soa_api_dup_chk%ROWTYPE);

  ----------------------------------------------------------------------------
  -- Ver    When         Who        Descr 
  -- -----  -----------  ---------  ------------------------------------------
  -- 1.0    10/12/2020   Roman W.   CHG0047450
  ----------------------------------------------------------------------------
  procedure update_to_error_trx(p_rec IN xxhz_soa_api_dup_chk%ROWTYPE);

  PROCEDURE update_trx(p_rec IN xxhz_soa_api_dup_chk%ROWTYPE);

END xxhz_soa_api_dup_chk_pkg;
/
