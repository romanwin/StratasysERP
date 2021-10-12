CREATE OR REPLACE PACKAGE xx_cst_recon_util IS

  PROCEDURE nullify_cst_recon_tables(x_return_code OUT VARCHAR2,
                                     x_err_msg     OUT VARCHAR2);

END xx_cst_recon_util;
/

