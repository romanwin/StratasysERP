CREATE OR REPLACE PACKAGE XXCS_CLEAN_RMA_IB_ERRORS_PKG IS

   -- Author  : Vitaly K.
   -- Created : 05/01/2010
   -- Purpose : For concurrent XXClean RMA Fulfillment IB Errors 

   PROCEDURE clean_rma_ib_errors(ERRBUF   OUT VARCHAR2,
                                 ERRCODE  OUT VARCHAR2);

END XXCS_CLEAN_RMA_IB_ERRORS_PKG;
/

