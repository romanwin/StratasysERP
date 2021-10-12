CREATE OR REPLACE PACKAGE "XXIBE_EU_FREIGHT_CALC_PKG" IS
  /*=======================================================================
  FILE NAME:   XXIBE_EU_FREIGHT_CALC_PKG
  VERSION:     1.3
  OBJECT NAME: XXIBE_EU_FREIGHT_CALC_PKG
  OBJECT TYPE: Public Package
  DESCRIPTION: 1. this package contains the function to calculate the freight charges for istore
               2. This also includes the Tax calculated on the freight terms.
  PARAMETERS:  None
  RETURNS:     None
  DATE:        12-AUG-2012
  AUTHOR :     APPSASSOCIATES
  =====================================================================*/
  FUNCTION xxibe_eu_freight_fun(ip_quote_header_id IN NUMBER) RETURN NUMBER;
END xxibe_eu_freight_calc_pkg;
/
