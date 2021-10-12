CREATE OR REPLACE PACKAGE xxar_invoice_kr_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               XXAR_INVOICE_KR_PKG
  --  create by:          YUVAL TAL
  --  $Revision:          1.0 $
  --  creation date:      9.8.10
  --  Purpose :           support xmlp XXINVRESINREP  data source
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0    9.8.10       YUVAL TAL            initial build
  ----------------------------------------------------------------------- 

  -- global var for xfter report params

  p_from_trx_date VARCHAR2(500);
  p_to_trx_date   VARCHAR2(500);
  p_directory     VARCHAR2(500);
  p_file_prefix   VARCHAR2(500);
  p_mail_list     VARCHAR2(500);

  FUNCTION after_report /*(p_mail_recipients VARCHAR2)*/
   RETURN BOOLEAN;

END xxar_invoice_kr_pkg;
/
