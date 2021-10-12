create or replace trigger xxhz_cust_accounts_bur_trg2
  before update of attribute4 on HZ_CUST_ACCOUNTS
  for each row

when ((new.attribute4 is not null) and (nvl(new.attribute5,'N') = 'N'))
DECLARE

BEGIN
  --------------------------------------------------------------------
  --  name:            XXHZ_CUST_ACCOUNTS_BUR_TRG2
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1 
  --  creation date:   20/02/2014
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each update of status or sales channel or account number
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/02/2014  Dalit A. Raviv    initial build CUST776 - Customer support SF-OA interfaces CR 1215
  --                                     mark the cust account as valid to SF
  --------------------------------------------------------------------       

  :new.attribute5 := 'Y';

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxhz_cust_accounts_bur_trg2;
/
