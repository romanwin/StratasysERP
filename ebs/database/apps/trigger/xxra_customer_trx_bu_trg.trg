CREATE OR REPLACE TRIGGER XXRA_CUSTOMER_TRX_BU_TRG
  --------------------------------------------------------------------
  --  name:            XXRA_CUSTOMER_TRX_BU_TRG
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   10/09/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032802 - SOD-Credit Memo Approval Workflow
  --                   Clear attribute5 which indicates approval status
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/09/2014  Michal Tzvik      initial build
  --------------------------------------------------------------------
BEFORE UPDATE ON ra_customer_trx_all 
FOR EACH ROW
  WHEN (old.complete_flag = 'Y' and
        new.complete_flag = 'N' and
        new.attribute5 is not null)
BEGIN
  :new.attribute5 := '';
  
EXCEPTION
   WHEN OTHERS THEN
     NULL;
END;
/
