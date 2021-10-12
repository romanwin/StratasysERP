CREATE OR REPLACE PACKAGE XXOE_DEFAULTING_RULE_PKG AS
/* $Header: OEXVDEFS.pls 120.1 2005/09/20 07:32:49 ksurendr noship $ */

-----------------------------------------------------------------------
--  customization code: 
--  name:               XXOE_DEFAULTING_RULE_PKG
--  create by:          Dalit A. Raviv
--  $Revision:          1.0 $
--  creation date:      07/06/2010
--  Purpose :           General Package for Defaulting Rule at OM .
-----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   07/06/2010    Dalit A. Raviv  initial build
----------------------------------------------------------------------- 

  -----------------------------------------------------------------------
  -- DEFAULTING FUNCTIONS TO BE USED FOR ATTRIBUTES ON ORDER HEADER
  -----------------------------------------------------------------------

  --

  -----------------------------------------------------------------------
  -- DEFAULTING FUNCTIONS FOR ATTRIBUTES ON ORDER LINE
  -----------------------------------------------------------------------
  -----------------------------------------------------------------------
  --  customization code: CUST329 - Default the Tax Class in DE SO lines for service orders
  --  name:               XXOE_DEFAULTING_RULE_PKG
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      07/06/2010
  --  Purpose :           General Package for Defaulting Rule at OM .
  --                      Om At Line level - Default Rule that check 
  --                      if OU is DE and oe_transction_type att8 = Y 
  --                      mean that this trx type relate to Service
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/06/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  FUNCTION Get_Tax_Classification_Code (p_database_object_name IN  VARCHAR2,
                                        p_attribute_code       IN  VARCHAR2)
  RETURN VARCHAR2;

END XXOE_DEFAULTING_RULE_PKG;
/

