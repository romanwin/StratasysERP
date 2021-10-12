create or replace PACKAGE qp_custom AS
  --------------------------------------------------------------------
  --  name:            QP_CUSTOM
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   01/05/2011
  --------------------------------------------------------------------
  --  purpose :        Advance Pricing Util
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/05/2011  Yuval Tal         initial build
  --  1.1  21/06/2011  Roman V.
  -- 1.2   19.7.11     yuval tal        change logic for getting operand in XXPACK_OF formula
  --------------------------------------------------------------------

  /* $Header: QPXCUSTS.pls 120.0 2005/06/02 01:12:22 appldev noship $ */
  /*#
  * This package contains the specification for the GET_CUSTOM_PRICE API.  The
  * package body/function body is not shipped with Oracle Advanced Pricing.  The
  * user must create the Package Body for QP_CUSTOM containing the function body
  * for GET_CUSTOM_PRICE which must adhere to the Function specification provided
  * in the QP_CUSTOM package specification.
  *
  * @rep:scope public
  * @rep:product QP
  * @rep:displayname Custom Pricing
  * @rep:category BUSINESS_ENTITY QP_PRICE_FORMULA
  */

  --GLOBAL Constant holding the package name

  g_pkg_name CONSTANT VARCHAR2(30) := 'QP_CUSTOM';

  /*Customizable Public Function*/

  /*#
  * The Get Custom Price API is a customizable function to which the user may add
  * custom code.  The API is called by the pricing engine while evaluating a
  * formula that contains a formula line (step) of type Function.  One or more
  * formulas may be set up to contain a formula line of type Function and the
  * same API is called each time.  So the user must code the logic in the API
  * based on the price_formula_id that is passed as an input parameter to the
  * API.
  *
  * @param p_price_formula_id the formula ID
  * @param p_list_price the list price when the formula step type is 'List Price'
  * @param p_price_effective_date the date the price is effective
  * @param p_req_line_attrs_tbl the input line attributes
  *
  * @return the calculated price
  *
  * @rep:displayname Get Custom Price
  */
  FUNCTION get_custom_price(p_price_formula_id     IN NUMBER,
                            p_list_price           IN NUMBER,
                            p_price_effective_date IN DATE,
                            p_req_line_attrs_tbl   IN qp_formula_price_calc_pvt.req_line_attrs_tbl)
    RETURN NUMBER;

END qp_custom;
/
