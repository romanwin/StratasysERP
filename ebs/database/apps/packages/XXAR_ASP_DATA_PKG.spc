CREATE OR REPLACE PACKAGE "APPS"."XXAR_ASP_DATA_PKG" IS

  -- Author  : YUVAL.TAL
  -- Created : 10/14/2020 10:50:38 AM
  -- Purpose : 
  /*
  • ASP for HW is calculated today on Q basis mostly for QBR and Q close purposes and done outside the system
  • ASP for HW is calculated today on Q basis mostly for QBR and Q close purposes and done outside the system
  • ASP is basically the actual selling price (list price less the deal Avg discount) divided by the qty of HW sold.
  • The ASP is not maintained today anywhere in the systems
  • The ASP need to reflect the channel, currency, region or in other words to be calculated per price list.
  
  */

  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   14/10/2020      yuval tal            CHG0048628 - initial 
  --------------------------------------------------------------------

  PROCEDURE populate_date(err_buff OUT VARCHAR2,
		  err_code OUT VARCHAR2);
END xxar_asp_data_pkg;

/