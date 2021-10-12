CREATE OR REPLACE PACKAGE XXQP_GET_ITEM_AVG_DIS_pkg AUTHID CURRENT_USER IS
  /************************************************************************************************
  * Copyright (C) 2013  TCS, India                                                               *
  * All rights Reserved                                                                          *
  * Program Name: XXQP_GET_ITEM_AVG_DIS_pkg.pkb                                                    *
  * Parameters  : None                                                                           *
  * Description : Package contains the procedures and function to derive the Get Item price and  *
  *                average discount in the invoice                                               *
  *
  *                                                                                              *
  * Notes       : None
  * History     :                                                                                *
  * Creation Date : 19-May-2016
  * Created/Updated By  : TCS                                                                    *
  * Version: 1.0
  **********************************************************************************************/
  --
  -- Private variable declarations


 FUNCTION is_get_item_line (P_LINE_ID IN NUMBER ) RETURN VARCHAR2;

 FUNCTION get_default_values(p_lookup_code VARCHAR2) RETURN VARCHAR2;

 FUNCTION get_price(p_item_id NUMBER,
                    p_price_list_id NUMBER,
                    p_price_date DATE,
                    p_line_id NUMBER default null) RETURN NUMBER;

END XXQP_GET_ITEM_AVG_DIS_pkg;
/
