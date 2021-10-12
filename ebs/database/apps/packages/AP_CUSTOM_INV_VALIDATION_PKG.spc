create or replace PACKAGE AP_CUSTOM_INV_VALIDATION_PKG AUTHID CURRENT_USER AS
/*$Header: apcsvals.pls 120.0.12000000.1 2009/02/10 09:53:02 subehera noship $*/

PROCEDURE AP_Custom_Validation_Hook(
   P_Invoice_ID                     IN   NUMBER,
   P_Calling_Sequence               IN   VARCHAR2);

END AP_CUSTOM_INV_VALIDATION_PKG;
/



 