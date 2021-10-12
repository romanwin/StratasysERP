CREATE OR REPLACE PACKAGE BODY ZX_AVALARA_TAX_SERVICE_PKG as

--==========================================================================
-- Program Name         -       ZX_AVALARA_TAX_SERVICE_PKG
-- Source File          -       ZX_AVALARA_TAX_SERVICE_PKG.sql
-- Description          -       Procedures/Functions used for transmitting transaction information and
--                              getting tax amounts from Avalara Tax system
--===========================================================================
--      Modification History
--===========================================================================
-- Date         Version         Who           Description
--3-Oct-13      2               TT(OAC)      Invoice Num update on Auto Invoice
--29-Oct-13		3				TT(OAC)		 restrict customer code text to 50 chars 
--16-Dec-13		4				TT			 handle no lines in lines cursor (free clob)
--21-Dec-13		4				TT			 handle null line qty (default to 1 if null)
--14-Mar-14		7				TT			 handle for contracts, set DFF value to N
--===========================================================================


/* ======================================================================*
 | FND Logging infrastructure                                           |
 * ======================================================================*/
G_PKG_NAME               CONSTANT VARCHAR2(30) := 'ZX_AVALARA_TAX_SERVICE_PKG';
G_CURRENT_RUNTIME_LEVEL  CONSTANT NUMBER       := FND_LOG.G_CURRENT_RUNTIME_LEVEL;
G_LEVEL_UNEXPECTED       CONSTANT NUMBER       := FND_LOG.LEVEL_UNEXPECTED;
G_LEVEL_ERROR            CONSTANT NUMBER       := FND_LOG.LEVEL_ERROR;
G_LEVEL_EXCEPTION        CONSTANT NUMBER       := FND_LOG.LEVEL_EXCEPTION;
G_LEVEL_EVENT            CONSTANT NUMBER       := FND_LOG.LEVEL_EVENT;
G_LEVEL_PROCEDURE        CONSTANT NUMBER       := FND_LOG.LEVEL_PROCEDURE;
G_LEVEL_STATEMENT        CONSTANT NUMBER       := FND_LOG.LEVEL_STATEMENT;
G_MODULE_NAME            CONSTANT VARCHAR2(80) := 'AVALARA.PLSQL.ZX_AVALARA_TAX_SERVICE_PKG.';


/*------------------------------------------------
|         Global Variables                        |
 ------------------------------------------------*/
  C_LINES_PER_COMMIT CONSTANT NUMBER := 1000;
  I Number;
  H number;
  L number;

  l_line_level_action varchar2(20);
  l_document_type zx_lines_det_factors.event_class_code%type;

  g_string       VARCHAR2(2500);
  g_docment_type_id  NUMBER;
  g_trasaction_id  NUMBER;
  g_tax_regime_code  varchar2(80);
  g_transaction_line_id  NUMBER;
  g_trx_level_type       varchar2(20);


/* ======================================================================*
 | Data Type Definitions                                                 |
 * ======================================================================*/

  type char_tab is table of char           index by binary_integer;
  type num_tab  is table of NUMBER(15)     index by binary_integer;
  type num1_tab is table of NUMBER         index by binary_integer;
  type date_tab is table of DATE           index by binary_integer;
  type var1_tab is table of VARCHAR2(1)    index by binary_integer;
  type var2_tab is table of VARCHAR2(80)   index by binary_integer;
  type var3_tab is table of VARCHAR2(2000) index by binary_integer;
  type var4_tab is table of VARCHAR2(150)  index by binary_integer;
  type var5_tab is table of VARCHAR2(240)  index by binary_integer;


  /*Private Procedures*/
  PROCEDURE PERFORM_VALIDATE(x_return_status OUT NOCOPY VARCHAR2) ;


  PROCEDURE SET_DOCUMENT_TYPE (
    p_document_type     IN OUT NOCOPY VARCHAR2,
    p_adj_doc_trx_id    IN NUMBER,
    p_line_amount       IN NUMBER,
    p_line_level_action IN VARCHAR2,
    x_return_status     OUT NOCOPY VARCHAR2);



  PROCEDURE TAX_RESULTS_PROCESSING (
    p_tax_lines_tbl IN OUT NOCOPY apps.ZX_TAX_PARTNER_PKG.tax_lines_tbl_type,
    p_currency_tab  IN OUT NOCOPY apps.ZX_TAX_PARTNER_PKG.tax_currencies_tbl_type,
    x_return_status    OUT NOCOPY VARCHAR2);

  PROCEDURE ERROR_EXCEPTION_HANDLE(str  VARCHAR2);

----- log messages
    PROCEDURE P_LOG (p_text    IN VARCHAR2 );
-----------------
-- xml request and response
PROCEDURE xml_request_response   (p_request_body IN CLOB, -- xml request body
                                 p_mode IN VARCHAR2 default 'GET',
                                 p_return_status OUT NOCOPY VARCHAR2,
                                 p_trans_id IN NUMBER DEFAULT NULL
                                 );
--==========================
-- build xml header msg
--=====================================
PROCEDURE build_xml_header (p_mode IN VARCHAR2 default 'GET' );
--==========================
-- build xml lines msg
--=====================================
PROCEDURE build_xml_lines ;
--==========================
-- build xml lines tag (start, end)
--=====================================
PROCEDURE build_xml_lines_tag (p_tag IN VARCHAR2) ;
------------
-- get profile vales
--=====================================
FUNCTION get_profile (p_profile IN VARCHAR2, p_org_id in NUMBER)
RETURN VARCHAR2;
------------

  /*Structure to hold the transaction information*/
  pg_internal_org_id_tab         num1_tab;
  pg_doc_type_id_tab             num1_tab;
  pg_trx_id_tab                  num1_tab;
  pg_appli_code_tab              var2_tab;
  pg_doc_level_action_tab        var2_tab;
  pg_trx_date_tab                date_tab;
  pg_trx_curr_code_tab           var2_tab;
  pg_legal_entity_num_tab        var2_tab;
  pg_esta_name_tab               var3_tab;
  pg_Trx_number_tab              var4_tab;
  pg_Trx_desc_tab                var3_tab;
  pg_doc_sequence_value_tab      var3_tab;
  pg_Trx_due_date_tab            date_tab;
  pg_Allow_Tax_Calc_tab          var1_tab;
  pg_trx_line_id_tab             num1_tab;
  pg_trx_level_type_tab          var2_tab;
  pg_line_level_action_tab       var2_tab;
  pg_line_class_tab              var2_tab;
  pg_trx_shipping_date_tab       date_tab;
  pg_trx_receipt_date_tab        date_tab;
  pg_trx_line_type_tab           var2_tab;
  pg_trx_line_date_tab           date_tab;
  pg_prv_tax_det_date_tab        date_tab;
  pg_trx_business_cat_tab        var3_tab;
  pg_line_intended_use_tab       var3_tab;
  pg_line_amt_incl_tax_flag_tab  var1_tab;
  pg_line_amount_tab             num1_tab;
  pg_other_incl_tax_amt_tab      num1_tab;
  pg_trx_line_qty_tab            num1_tab;
  pg_unit_price_tab              num1_tab;
  pg_cash_discount_tab           num1_tab;
  pg_volume_discount_tab         num1_tab;
  pg_trading_discount_tab        num1_tab;
  pg_trans_charge_tab            num1_tab;
  pg_ins_charge_tab              num1_tab;
  pg_other_charge_tab            num1_tab;
  pg_prod_id_tab                 num1_tab;
  pg_uom_code_tab                var2_tab;
  pg_prod_type_tab               var3_tab;
  pg_prod_code_tab               var2_tab;
  pg_fob_point_tab               var2_tab;
  pg_ship_to_pty_numr_tab        var2_tab;
  pg_ship_to_pty_name_tab        var3_tab;
  pg_ship_from_pty_num_tab       var2_tab;
  pg_ship_from_pty_name_tab      var3_tab;
  pg_ship_to_loc_id_tab          num1_tab;
  pg_ship_to_grphy_type1_tab     var5_tab;
  pg_ship_to_grphy_value1_tab    var5_tab;
  pg_ship_to_grphy_type2_tab     var5_tab;
  pg_ship_to_grphy_value2_tab    var5_tab;
  pg_ship_to_grphy_type3_tab     var5_tab;
  pg_ship_to_grphy_value3_tab    var5_tab;
  pg_ship_to_grphy_type4_tab     var5_tab;
  pg_ship_to_grphy_value4_tab    var5_tab;
  pg_ship_to_grphy_type5_tab     var5_tab;
  pg_ship_to_grphy_value5_tab    var5_tab;
  pg_ship_to_grphy_type6_tab     var5_tab;
  pg_ship_to_grphy_value6_tab    var5_tab;
  pg_ship_to_grphy_type7_tab     var5_tab;
  pg_ship_to_grphy_value7_tab    var5_tab;
  pg_ship_to_grphy_type8_tab     var5_tab;
  pg_ship_to_grphy_value8_tab    var5_tab;
  pg_ship_to_grphy_type9_tab     var5_tab;
  pg_ship_to_grphy_value9_tab    var5_tab;
  pg_ship_to_grphy_type10_tab    var5_tab;
  pg_ship_to_grphy_value10_tab   var5_tab;
  pg_ship_fr_loc_id_tab          num1_tab;
  pg_ship_fr_grphy_type1_tab     var5_tab;
  pg_ship_fr_grphy_value1_tab    var5_tab;
  pg_ship_fr_grphy_type2_tab     var5_tab;
  pg_ship_fr_grphy_value2_tab    var5_tab;
  pg_ship_fr_grphy_type3_tab     var5_tab;
  pg_ship_fr_grphy_value3_tab    var5_tab;
  pg_ship_fr_grphy_type4_tab     var5_tab;
  pg_ship_fr_grphy_value4_tab    var5_tab;
  pg_ship_fr_grphy_type5_tab     var5_tab;
  pg_ship_fr_grphy_value5_tab    var5_tab;
  pg_ship_fr_grphy_type6_tab     var5_tab;
  pg_ship_fr_grphy_value6_tab    var5_tab;
  pg_ship_fr_grphy_type7_tab     var5_tab;
  pg_ship_fr_grphy_value7_tab    var5_tab;
  pg_ship_fr_grphy_type8_tab     var5_tab;
  pg_ship_fr_grphy_value8_tab    var5_tab;
  pg_ship_fr_grphy_type9_tab     var5_tab;
  pg_ship_fr_grphy_value9_tab    var5_tab;
  pg_ship_fr_grphy_type10_tab    var5_tab;
  pg_ship_fr_grphy_value10_tab   var5_tab;
  pg_poa_loc_id_tab              num1_tab;
  pg_poa_grphy_type1_tab         var5_tab;
  pg_poa_grphy_value1_tab        var5_tab;
  pg_poa_grphy_type2_tab         var5_tab;
  pg_poa_grphy_value2_tab        var5_tab;
  pg_poa_grphy_type3_tab         var5_tab;
  pg_poa_grphy_value3_tab        var5_tab;
  pg_poa_grphy_type4_tab         var5_tab;
  pg_poa_grphy_value4_tab        var5_tab;
  pg_poa_grphy_type5_tab         var5_tab;
  pg_poa_grphy_value5_tab        var5_tab;
  pg_poa_grphy_type6_tab         var5_tab;
  pg_poa_grphy_value6_tab        var5_tab;
  pg_poa_grphy_type7_tab         var5_tab;
  pg_poa_grphy_value7_tab        var5_tab;
  pg_poa_grphy_type8_tab         var5_tab;
  pg_poa_grphy_value8_tab        var5_tab;
  pg_poa_grphy_type9_tab         var5_tab;
  pg_poa_grphy_value9_tab        var5_tab;
  pg_poa_grphy_type10_tab        var5_tab;
  pg_poa_grphy_value10_tab       var5_tab;
  pg_poo_loc_id_tab              num1_tab;
  pg_poo_grphy_type1_tab         var5_tab;
  pg_poo_grphy_value1_tab        var5_tab;
  pg_poo_grphy_type2_tab         var5_tab;
  pg_poo_grphy_value2_tab        var5_tab;
  pg_poo_grphy_type3_tab         var5_tab;
  pg_poo_grphy_value3_tab        var5_tab;
  pg_poo_grphy_type4_tab         var5_tab;
  pg_poo_grphy_value4_tab        var5_tab;
  pg_poo_grphy_type5_tab         var5_tab;
  pg_poo_grphy_value5_tab        var5_tab;
  pg_poo_grphy_type6_tab         var5_tab;
  pg_poo_grphy_value6_tab        var5_tab;
  pg_poo_grphy_type7_tab         var5_tab;
  pg_poo_grphy_value7_tab        var5_tab;
  pg_poo_grphy_type8_tab         var5_tab;
  pg_poo_grphy_value8_tab        var5_tab;
  pg_poo_grphy_type9_tab         var5_tab;
  pg_poo_grphy_value9_tab        var5_tab;
  pg_poo_grphy_type10_tab        var5_tab;
  pg_poo_grphy_value10_tab       var5_tab;
  pg_bill_to_pty_num_tab         var2_tab;
  pg_bill_to_pty_name_tab        var3_tab;
  pg_bill_from_pty_num_tab       var2_tab;
  pg_bill_from_pty_name_tab      var3_tab;
  pg_bill_to_loc_id_tab          num1_tab;
  pg_bill_to_grphy_type1_tab     var5_tab;
  pg_bill_to_grphy_value1_tab    var5_tab;
  pg_bill_to_grphy_type2_tab     var5_tab;
  pg_bill_to_grphy_value2_tab    var5_tab;
  pg_bill_to_grphy_type3_tab     var5_tab;
  pg_bill_to_grphy_value3_tab    var5_tab;
  pg_bill_to_grphy_type4_tab     var5_tab;
  pg_bill_to_grphy_value4_tab    var5_tab;
  pg_bill_to_grphy_type5_tab     var5_tab;
  pg_bill_to_grphy_value5_tab    var5_tab;
  pg_bill_to_grphy_type6_tab     var5_tab;
  pg_bill_to_grphy_value6_tab    var5_tab;
  pg_bill_to_grphy_type7_tab     var5_tab;
  pg_bill_to_grphy_value7_tab    var5_tab;
  pg_bill_to_grphy_type8_tab     var5_tab;
  pg_bill_to_grphy_value8_tab    var5_tab;
  pg_bill_to_grphy_type9_tab     var5_tab;
  pg_bill_to_grphy_value9_tab    var5_tab;
  pg_bill_to_grphy_type10_tab    var5_tab;
  pg_bill_to_grphy_value10_tab   var5_tab;
  pg_bill_fr_loc_id_tab          num1_tab;
  pg_bill_fr_grphy_type1_tab     var5_tab;
  pg_bill_fr_grphy_value1_tab    var5_tab;
  pg_bill_fr_grphy_type2_tab     var5_tab;
  pg_bill_fr_grphy_value2_tab    var5_tab;
  pg_bill_fr_grphy_type3_tab     var5_tab;
  pg_bill_fr_grphy_value3_tab    var5_tab;
  pg_bill_fr_grphy_type4_tab     var5_tab;
  pg_bill_fr_grphy_value4_tab    var5_tab;
  pg_bill_fr_grphy_type5_tab     var5_tab;
  pg_bill_fr_grphy_value5_tab    var5_tab;
  pg_bill_fr_grphy_type6_tab     var5_tab;
  pg_bill_fr_grphy_value6_tab    var5_tab;
  pg_bill_fr_grphy_type7_tab     var5_tab;
  pg_bill_fr_grphy_value7_tab    var5_tab;
  pg_bill_fr_grphy_type8_tab     var5_tab;
  pg_bill_fr_grphy_value8_tab    var5_tab;
  pg_bill_fr_grphy_type9_tab     var5_tab;
  pg_bill_fr_grphy_value9_tab    var5_tab;
  pg_bill_fr_grphy_type10_tab    var5_tab;
  pg_bill_fr_grphy_value10_tab   var5_tab;
  pg_account_ccid_tab            num1_tab;
  pg_appl_fr_doc_type_id_tab     num1_tab;
  pg_appl_from_trx_id_tab        num1_tab;
  pg_appl_from_line_id_tab       num1_tab;
  pg_appl_fr_trx_lev_type_tab    var2_tab;
  pg_appl_from_doc_num_tab       var2_tab;
  pg_adj_doc_doc_type_id_tab     num1_tab;
  pg_adj_doc_trx_id_tab          num1_tab;
  pg_adj_doc_line_id_tab         num1_tab;
  pg_adj_doc_number_tab          var2_tab;
  pg_ADJ_doc_trx_lev_type_tab    var2_tab;
  pg_adj_doc_date_tab            date_tab;
  pg_assess_value_tab            num1_tab;
  pg_trx_line_number_tab         num1_tab;
  pg_trx_line_desc_tab           var3_tab;
  pg_prod_desc_tab               var3_tab;
  pg_header_char1_tab            var4_tab;
  pg_header_char2_tab            var4_tab;
  pg_header_char3_tab            var4_tab;
  pg_header_char4_tab            var4_tab;
  pg_header_char5_tab            var4_tab;
  pg_header_char6_tab            var4_tab;
  pg_header_char7_tab            var4_tab;
  pg_header_char8_tab            var4_tab;
  pg_header_char9_tab            var4_tab;
  pg_header_char10_tab           var4_tab;
  pg_header_char11_tab           var4_tab;
  pg_header_char12_tab           var4_tab;
  pg_header_char13_tab           var4_tab;
  pg_header_char14_tab           var4_tab;
  pg_header_char15_tab           var4_tab;
  pg_header_numeric1_tab         num1_tab;
  pg_header_numeric2_tab         num1_tab;
  pg_header_numeric3_tab         num1_tab;
  pg_header_numeric4_tab         num1_tab;
  pg_header_numeric5_tab         num1_tab;
  pg_header_numeric6_tab         num1_tab;
  pg_header_numeric7_tab         num1_tab;
  pg_header_numeric8_tab         num1_tab;
  pg_header_numeric9_tab         num1_tab;
  pg_header_numeric10_tab        num1_tab;
  pg_header_date1_tab            date_tab;
  pg_header_date2_tab            date_tab;
  pg_header_date3_tab            date_tab;
  pg_header_date4_tab            date_tab;
  pg_header_date5_tab            date_tab;
  pg_line_char1_tab              var4_tab;
  pg_line_char2_tab              var4_tab;
  pg_line_char3_tab              var4_tab;
  pg_line_char4_tab              var4_tab;
  pg_line_char5_tab              var4_tab;
  pg_line_char6_tab              var4_tab;
  pg_line_char7_tab              var4_tab;
  pg_line_char8_tab              var4_tab;
  pg_line_char9_tab              var4_tab;
  pg_line_char10_tab             var4_tab;
  pg_line_char11_tab             var4_tab;
  pg_line_char12_tab             var4_tab;
  pg_line_char13_tab             var4_tab;
  pg_line_char14_tab             var4_tab;
  pg_line_char15_tab             var4_tab;
  pg_line_numeric1_tab           num1_tab;
  pg_line_numeric2_tab           num1_tab;
  pg_line_numeric3_tab           num1_tab;
  pg_line_numeric4_tab           num1_tab;
  pg_line_numeric5_tab           num1_tab;
  pg_line_numeric6_tab           num1_tab;
  pg_line_numeric7_tab           num1_tab;
  pg_line_numeric8_tab           num1_tab;
  pg_line_numeric9_tab           num1_tab;
  pg_line_numeric10_tab          num1_tab;
  pg_line_date1_tab              date_tab;
  pg_line_date2_tab              date_tab;
  pg_line_date3_tab              date_tab;
  pg_line_date4_tab              date_tab;
  pg_line_date5_tab              date_tab;
  pg_exempt_certi_numb_tab       var2_tab;
  pg_exempt_reason_tab           var3_tab;
  pg_exempt_cont_flag_tab        var2_tab;
  pg_ugraded_inv_flag_tab        var1_tab;
  -- for tax response
  pg_resp_tax_curr_code           var2_tab;
  pg_resp_state                   var2_tab;
  pg_resp_county                  var2_tab;
  pg_resp_city                    var2_tab;
  pg_resp_tax                     var2_tab;
  pg_resp_tax_amt                 num1_tab;
  pg_resp_unround_tax_amt         num1_tab;
  pg_resp_curr_tax_amt            num1_tab;
  pg_resp_tax_rate_percentage     num1_tab;
  pg_resp_taxable_amount          num1_tab;
  pg_resp_exempt_amt                num1_tab;
  pg_resp_exempt_reason             var5_tab;
  pg_resp_exempt_reason_code        var2_tab;
  pg_resp_exempt_rate_modifier      num1_tab;
  pg_resp_exempt_certificate_num    var2_tab;
  pg_resp_TAX_EXEMPTION_ID          num1_tab;
  pg_resp_TAX_DATE                  date_tab;
  pg_resp_TAX_DETERMINE_DATE        date_tab;
  pg_resp_trx_line_id_tab           num1_tab;
  pg_resp_trx_level_type_tab        var2_tab;


  pg_resp_ga_category           var2_tab;
  pg_resp_ga2           var4_tab;
  pg_resp_ga4           var4_tab;
  pg_resp_ga6           var4_tab;



 v_tax_request_doc varchar2 (32766);
 v_clob clob;
 v_clob_created boolean := false;
 v_clob_length number;

 response_body   CLOB;
 l_regime_code ZX_REGIMES_B.tax_regime_code%type;

   -------------------------------------------------------------------------------------------
   --   Function clears string from characters like ampersand quotes etc.
   --   It is done to comply with XML standard
   -------------------------------------------------------------------------------------------
   function cl (
      in_string varchar2
   )
      return varchar2 is
      v_out_string varchar2 (1000);
   begin

      -- replace ampersand character with ampersand || amp;.
      v_out_string := replace (in_string,
                               chr (38),
                               chr (38) || 'amp;'
                              );
      -- replace "greater than" character with ampersand || gt;.
      v_out_string := replace (v_out_string,
                               '>',
                               chr (38) || 'gt;'
                              );
      -- replace "less than" character with ampersand || gt;.
      v_out_string := replace (v_out_string,
                               '<',
                               chr (38) || 'lt;'
                              );
      -- replace apostrophe character with ampersand || apos;.
      v_out_string := replace (v_out_string,
                               '''',
                               chr (38) || 'apos;'
                              );
      -- replace quote character with ampersand || quot;.
      v_out_string := replace (v_out_string,
                               '"',
                               chr (38) || 'quot;'
                              );
      return v_out_string;
   exception
      when others then
         p_log('Exception when others in CL function - ' || sqlerrm);
   end cl;
--===========================
PROCEDURE CALCULATE_TAX_API (
  p_currency_tab     IN OUT NOCOPY ZX_TAX_PARTNER_PKG.tax_currencies_tbl_type,
  x_tax_lines_tbl       OUT NOCOPY ZX_TAX_PARTNER_PKG.tax_lines_tbl_type,
  x_error_status        OUT NOCOPY VARCHAR2,
  x_messages_tbl        OUT NOCOPY ZX_TAX_PARTNER_PKG.messages_tbl_type)is

  Cursor item_lines_to_be_processed (cv_trans_id number)
  is
     SELECT
  transaction_line_id                    ,
  trx_level_type                         ,
  line_level_action                      ,
  line_class                             ,
  transaction_shipping_date              ,
  transaction_receipt_date               ,
  transaction_line_type                  ,
  transaction_line_date                  ,
  trx_business_category                  ,
  line_intended_use                      ,
  line_amt_includes_tax_flag             ,
  line_amount                            ,
  other_inclusive_tax_amount             ,
  nvl(transaction_line_quantity,1)       ,
  unit_price                             ,
  cash_discount                          ,
  volume_discount                        ,
  trading_discount                       ,
  transportation_charge                  ,
  insurance_charge                       ,
  other_charge                           ,
  product_id                             ,
  uom_code                               ,
  product_type                           ,
  product_code                           ,
  fob_point                              ,
  ship_to_party_number                   ,
  ship_to_party_name                     ,
  ship_from_party_number                 ,
  ship_from_party_name                   ,
  ship_to_loc_id                         ,
  ship_to_geography_type1                ,
  ship_to_geography_value1               ,
  ship_to_geography_type2                ,
  ship_to_geography_value2               ,
  ship_to_geography_type3                ,
  ship_to_geography_value3               ,
  ship_to_geography_type4                ,
  ship_to_geography_value4               ,
  ship_to_geography_type5                ,
  ship_to_geography_value5               ,
  ship_to_geography_type6                ,
  ship_to_geography_value6               ,
  ship_to_geography_type7                ,
  ship_to_geography_value7               ,
  ship_to_geography_type8                ,
  ship_to_geography_value8               ,
  ship_to_geography_type9                ,
  ship_to_geography_value9               ,
  ship_to_geography_type10               ,
  ship_to_geography_value10              ,
  ship_from_loc_id                       ,
  ship_from_geography_type1              ,
  ship_from_geography_value1             ,
  ship_from_geography_type2              ,
  ship_from_geography_value2             ,
  ship_from_geography_type3              ,
  ship_from_geography_value3             ,
  ship_from_geography_type4              ,
  ship_from_geography_value4             ,
  ship_from_geography_type5              ,
  ship_from_geography_value5             ,
  ship_from_geography_type6              ,
  ship_from_geography_value6             ,
  ship_from_geography_type7              ,
  ship_from_geography_value7             ,
  ship_from_geography_type8              ,
  ship_from_geography_value8             ,
  ship_from_geography_type9              ,
  ship_from_geography_value9             ,
  ship_from_geography_type10             ,
  ship_from_geography_value10            ,
  poa_loc_id                             ,
  poa_geography_type1                    ,
  poa_geography_value1                   ,
  poa_geography_type2                    ,
  poa_geography_value2                   ,
  poa_geography_type3                    ,
  poa_geography_value3                   ,
  poa_geography_type4                    ,
  poa_geography_value4                   ,
  poa_geography_type5                    ,
  poa_geography_value5                   ,
  poa_geography_type6                    ,
  poa_geography_value6                   ,
  poa_geography_type7                    ,
  poa_geography_value7                   ,
  poa_geography_type8                    ,
  poa_geography_value8                   ,
  poa_geography_type9                    ,
  poa_geography_value9                   ,
  poa_geography_type10                   ,
  poa_geography_value10                  ,
  poo_loc_id                             ,
  poo_geography_type1                    ,
  poo_geography_value1                   ,
  poo_geography_type2                    ,
  poo_geography_value2                   ,
  poo_geography_type3                    ,
  poo_geography_value3                   ,
  poo_geography_type4                    ,
  poo_geography_value4                   ,
  poo_geography_type5                    ,
  poo_geography_value5                   ,
  poo_geography_type6                    ,
  poo_geography_value6                   ,
  poo_geography_type7                    ,
  poo_geography_value7                   ,
  poo_geography_type8                    ,
  poo_geography_value8                   ,
  poo_geography_type9                    ,
  poo_geography_value9                   ,
  poo_geography_type10                   ,
  poo_geography_value10                  ,
  bill_to_party_number                   ,
  bill_to_party_name                     ,
  bill_from_party_number                 ,
  bill_from_party_name                   ,
  bill_to_loc_id                         ,
  bill_to_geography_type1                ,
  bill_to_geography_value1               ,
  bill_to_geography_type2                ,
  bill_to_geography_value2               ,
  bill_to_geography_type3                ,
  bill_to_geography_value3               ,
  bill_to_geography_type4                ,
  bill_to_geography_value4               ,
  bill_to_geography_type5                ,
  bill_to_geography_value5               ,
  bill_to_geography_type6                ,
  bill_to_geography_value6               ,
  bill_to_geography_type7                ,
  bill_to_geography_value7               ,
  bill_to_geography_type8                ,
  bill_to_geography_value8               ,
  bill_to_geography_type9                ,
  bill_to_geography_value9               ,
  bill_to_geography_type10               ,
  bill_to_geography_value10              ,
  bill_from_loc_id                       ,
  bill_from_geography_type1              ,
  bill_from_geography_value1             ,
  bill_from_geography_type2              ,
  bill_from_geography_value2             ,
  bill_from_geography_type3              ,
  bill_from_geography_value3             ,
  bill_from_geography_type4              ,
  bill_from_geography_value4             ,
  bill_from_geography_type5              ,
  bill_from_geography_value5             ,
  bill_from_geography_type6              ,
  bill_from_geography_value6             ,
  bill_from_geography_type7              ,
  bill_from_geography_value7             ,
  bill_from_geography_type8              ,
  bill_from_geography_value8             ,
  bill_from_geography_type9              ,
  bill_from_geography_value9             ,
  bill_from_geography_type10             ,
  bill_from_geography_value10            ,
  account_ccid                           ,
  applied_from_transaction_id            ,
  applied_from_line_id                   ,
  applied_from_trx_level_type,
  applied_from_doc_number                ,
  adjusted_doc_document_type_id          ,
  adjusted_doc_transaction_id            ,
  adjusted_doc_line_id                   ,
  adjusted_doc_number                    ,
  adjusted_doc_trx_level_type,
  adjusted_doc_date                      ,
  assessable_value                       ,
  --- line number on sales quote
  decode(line_level_action,'QUOTE', (select line_number from apps.oe_order_lines_all where line_id = transaction_line_id),
        trx_line_number)    trx_line_number                    ,
  trx_line_description                   ,
  product_description                    ,
  line_char1                             ,
  line_char2                             ,
  line_char3                             ,
  line_char4                             ,
  line_char5                             ,
  line_char6                             ,
  line_char7                             ,
  line_char8                             ,
  line_char9                             ,
  line_char10                            ,
  line_char11                            ,
  line_char12                            ,
  line_char13                            ,
  line_char14                            ,
  line_char15                            ,
  line_numeric1                          ,
  line_numeric2                          ,
  line_numeric3                          ,
  line_numeric4                          ,
  line_numeric5                          ,
  line_numeric6                          ,
  line_numeric7                          ,
  line_numeric8                          ,
  line_numeric9                          ,
  line_numeric10                         ,
  line_date1                             ,
  line_date2                             ,
  line_date3                             ,
  line_date4                             ,
  line_date5                             ,
  exempt_certificate_number              ,
  exempt_reason                          ,
  exemption_control_flag
     From ZX_O2C_CALC_TXN_INPUT_V
     where transaction_id = cv_trans_id
     order by trx_line_number;

 cursor c_transaction_header
 is
    select distinct
    INTERNAL_ORGANIZATION_ID
    ,DOCUMENT_TYPE_ID
    ,TRANSACTION_ID
    ,APPLICATION_CODE
    ,DOCUMENT_LEVEL_ACTION
    ,TRX_DATE
    ,TRX_CURRENCY_CODE
    ,LEGAL_ENTITY_NUMBER
    ,ESTABLISHMENT_NUMBER
    ,TRANSACTION_NUMBER
    ,TRANSACTION_DESCRIPTION
    ,DOCUMENT_SEQUENCE_VALUE
    ,NVL(TRANSACTION_DUE_DATE, TRX_DATE) TRANSACTION_DUE_DATE -- handle null for project invoices
    ,ALLOW_TAX_CALCULATION
    ,HEADER_CHAR1
    ,HEADER_CHAR2
    ,HEADER_CHAR3
    ,HEADER_CHAR4
    ,HEADER_CHAR5
    ,HEADER_CHAR6
    ,HEADER_CHAR7
    ,HEADER_CHAR8
    ,HEADER_CHAR9
    ,HEADER_CHAR10
    ,HEADER_NUMERIC1
    ,HEADER_NUMERIC2
    ,HEADER_NUMERIC3
    ,HEADER_NUMERIC4
    ,HEADER_NUMERIC5
    ,HEADER_NUMERIC6
    ,HEADER_NUMERIC7
    ,HEADER_NUMERIC8
    ,HEADER_NUMERIC9
    ,HEADER_NUMERIC10
    ,HEADER_DATE1
    ,HEADER_DATE2
    ,HEADER_DATE3
    ,HEADER_DATE4
    ,HEADER_DATE5
  From ZX_O2C_CALC_TXN_INPUT_V
  order by transaction_id;

 cursor c_inv_trans_lines (cp_trans_id number)
 is
    -- invoice lines
    select trx_line_id,
    trx_level_type,
    line_level_action,
    EVENT_CLASS_CODE,
    TRX_SHIPPING_DATE,
    TRX_RECEIPT_DATE,
    TRX_LINE_TYPE,
    trx_line_date,
    TRX_LINE_NUMBER,
    TRX_LINE_DESCRIPTION,
    PROVNL_TAX_DETERMINATION_DATE,
    TRX_BUSINESS_CATEGORY,
    LINE_INTENDED_USE,
    LINE_AMT_INCLUDES_TAX_FLAG,
    LINE_AMT,
    null OTHER_INCLUSIVE_TAX_AMOUNT,
    nvl(TRX_LINE_QUANTITY,1),
    UNIT_PRICE,
    CASH_DISCOUNT,
    VOLUME_DISCOUNT,
    TRADING_DISCOUNT,
    TRANSPORTATION_CHARGE,
    INSURANCE_CHARGE,
    OTHER_CHARGE,
    PRODUCT_ID,
    UOM_CODE,
    PRODUCT_TYPE,
    PRODUCT_CODE,
    FOB_POINT,
    ASSESSABLE_VALUE,
    PRODUCT_DESCRIPTION,
    ACCOUNT_CCID,
    EXEMPT_CERTIFICATE_NUMBER,
    EXEMPT_REASON_CODE,
    EXEMPTION_CONTROL_FLAG,
    SHIP_FROM_LOCATION_ID,
    SHIP_TO_LOCATION_ID,
    BILL_FROM_LOCATION_ID,
    BILL_TO_LOCATION_ID,
    POA_LOCATION_ID,
    POO_LOCATION_ID,
    APPLIED_FROM_TRX_ID,
    APPLIED_FROM_LINE_ID,
    APPLIED_FROM_TRX_LEVEL_TYPE,
    APPLIED_FROM_TRX_NUMBER,
    ADJUSTED_DOC_TRX_ID,
    ADJUSTED_DOC_LINE_ID,
    ADJUSTED_DOC_TRX_LEVEL_TYPE,
    ADJUSTED_DOC_NUMBER,
    ADJUSTED_DOC_DATE,
    CHAR1,
    CHAR2,
    CHAR3,
    CHAR4,
    CHAR5,
    CHAR6,
    CHAR7,
    CHAR8,
    CHAR9,
    CHAR10,
    NUMERIC1,
    NUMERIC2,
    NUMERIC3,
    NUMERIC4,
    NUMERIC5,
    NUMERIC6,
    NUMERIC7,
    NUMERIC8,
    NUMERIC9,
    NUMERIC10,
    DATE1,
    DATE2,
    DATE3,
    DATE4,
    DATE5
   from apps.zx_lines_det_factors
   where trx_id = cp_trans_id
   order by TRX_LINE_NUMBER;


  l_api_name             CONSTANT VARCHAR2(30) := 'CALCULATE_TAX_API';
  l_return_status        VARCHAR2(30);
  ptr                    NUMBER;
  hdr                    NUMBER;
  lns                    NUMBER;

  v_cnt number := 0;
  v_complete_flag        apps.RA_CUSTOMER_TRX_all.complete_flag%TYPE;
  v_request_id number := NULL;

  v_attr_col1 VARCHAR2(30) := NULL;
  v_sql_stmt  VARCHAR2(200) := NULL;
  v_country   VARCHAR2(30) := NULL;
  v_ava_call  RA_CUST_TRX_TYPES_ALL.ATTRIBUTE1%TYPE := NULL;
  v_zero_ava_call RA_CUST_TRX_TYPES_ALL.ATTRIBUTE1%TYPE := NULL;
  v_txn_value number := NULL;
  v_HEADER_ID NUMBER;
  v_SUBTOTAL  NUMBER;
  v_DISCOUNT  NUMBER;
  v_CHARGES   NUMBER;
  v_TAX       NUMBER;
 v_attr_col3        VARCHAR2(40);
 v_attr_col4        VARCHAR2(40);
 v_attr_cols        VARCHAR2(100);
 v_sql_stmt3        VARCHAR2(2500);

l_proc_rec ZX_O2C_CALC_TXN_INPUT_V%rowtype;

BEGIN

  x_error_status := FND_API.G_RET_STS_SUCCESS;
  err_count      := 0;

 P_LOG ('BEGIN - ' ||G_PKG_NAME||': '||l_api_name||'(+)');

 P_LOG (' zx_tax_partner_pkg.G_BUSINESS_FLOW = ' || zx_tax_partner_pkg.G_BUSINESS_FLOW);

  IF zx_tax_partner_pkg.G_BUSINESS_FLOW <> 'O2C' THEN
    --Release 12 Old tax partner integration does not support P2P products;
    x_error_status := FND_API.G_RET_STS_UNEXP_ERROR;
    g_string :='Tax partner integration does not support P2P products';
    P_LOG (g_string);
    error_exception_handle(g_string);
    x_messages_tbl:=g_messages_tbl;
    return;
  END IF;

  v_clob_created := false;

    -- open transaction headers to process
    open c_transaction_header;
    fetch c_transaction_header
     bulk collect into
     pg_internal_org_id_tab ,
     pg_doc_type_id_tab,
     pg_trx_id_tab,
     pg_appli_code_tab,
     pg_doc_level_action_tab,
     pg_trx_date_tab,
     pg_trx_curr_code_tab,
     pg_legal_entity_num_tab,
     pg_esta_name_tab,
     pg_trx_number_tab,
     pg_trx_desc_tab,
     pg_doc_sequence_value_tab,
     pg_trx_due_date_tab,
     pg_allow_tax_calc_tab,
     pg_header_char1_tab,
     pg_header_char2_tab,
     pg_header_char3_tab,
     pg_header_char4_tab,
     pg_header_char5_tab,
     pg_header_char6_tab,
     pg_header_char7_tab,
     pg_header_char8_tab,
     pg_header_char9_tab,
     pg_header_char10_tab,
     pg_header_NUMERIC1_tab,
     pg_header_NUMERIC2_tab,
     pg_header_NUMERIC3_tab,
     pg_header_NUMERIC4_tab,
     pg_header_NUMERIC5_tab,
     pg_header_NUMERIC6_tab,
     pg_header_NUMERIC7_tab,
     pg_header_NUMERIC8_tab,
     pg_header_NUMERIC9_tab,
     pg_header_NUMERIC10_tab,
     pg_header_date1_tab,
     pg_header_date2_tab,
     pg_header_date3_tab,
     pg_header_date4_tab,
     pg_header_date5_tab
     limit C_LINES_PER_COMMIT; -- limit the fetch for performance

    -- check if any to process
    IF (nvl(pg_trx_id_tab.last,0) = 0) Then
        x_error_status := FND_API.G_RET_STS_UNEXP_ERROR;
        g_string :='No Transactions exist to whom tax need to be processed';
        P_LOG (g_string);
        error_exception_handle(g_string);
        x_messages_tbl:=g_messages_tbl;
        return;

    ELSE -- header cursor returned some rows that can be processed

        P_LOG (  ' Header records in ZX_O2C_CALC_TXN_INPUT_V = '||pg_trx_id_tab.last);

            -- copy view data into tmp table for analysis as view only store data during processing
            -- this is temp and can be removed later
            begin
             insert into AVALARA.AVLR_TMP_ZX_O2C_CALC_TXN_INPUT (select * from apps.ZX_O2C_CALC_TXN_INPUT_V);
            --========
             P_LOG ('insert into  AVALARA.AVLR_TMP_ZX_O2C_CALC_TXN_INPUT');
            --===============
            exception when others then
             P_LOG ('Error inserting into  AVALARA.AVLR_TMP_ZX_O2C_CALC_TXN_INPUT - '||sqlerrm);
            end;
            ------------
            ---------------

           -- loop through header records
           For hdr in 1..nvl(pg_trx_id_tab.last, 0)
           loop

             H := hdr;
               --g_trx_level_type  :=  pg_trx_level_type_tab(h);
               g_docment_type_id  :=  pg_doc_type_id_tab(h);
               g_trasaction_id  :=  pg_trx_id_tab(h);
               g_tax_regime_code  :=  apps.zx_tax_partner_pkg.g_tax_regime_code;

                P_LOG (  'g_docment_type_id : ' ||g_docment_type_id);
                P_LOG (  'g_trasaction_id : ' ||g_trasaction_id);
                P_LOG (  'g_tax_regime_code : ' ||g_docment_type_id);

                    
                    -- check Transaction type DFFs to prevent Avalara Call
                            -- check for DFF value
                            -- get attribute column used for this DFF
                                  BEGIN

                                    -- DFF on trx type to prevent avalara call
                                    SELECT t1.APPLICATION_COLUMN_NAME col1, t2.APPLICATION_COLUMN_NAME col2  
                                    INTO v_attr_col3, v_attr_col4
                                    FROM FND_DESCR_FLEX_COL_USAGE_VL t1, FND_DESCR_FLEX_COL_USAGE_VL t2 
                                    WHERE (t1.APPLICATION_ID=222) and 
                                    (t1.DESCRIPTIVE_FLEXFIELD_NAME LIKE 'RA_CUST_TRX_TYPES') and 
                                    (t1.DESCRIPTIVE_FLEX_CONTEXT_CODE='Global Data Elements')
                                    and t1.DESCRIPTIVE_FLEX_CONTEXT_CODE = t2.DESCRIPTIVE_FLEX_CONTEXT_CODE
                                    and t1.DESCRIPTIVE_FLEXFIELD_NAME = t2.DESCRIPTIVE_FLEXFIELD_NAME
                                    and t1.APPLICATION_ID = t2.APPLICATION_ID
                                    and upper(t1.END_USER_COLUMN_NAME) = 'AVA_TAX_CALL'
                                    and upper(t2.END_USER_COLUMN_NAME) = 'AVA_ZERO_TAX_CALL';
                                  EXCEPTION WHEN OTHERS THEN
                                   v_attr_col3 := NULL;
                                   v_attr_col4 := NULL;
                                   p_log ('Error selecting DFF column at line level - '||sqlerrm);
                                  END;
                             p_log ('v_attr_col3 = '||v_attr_col3);
                             p_log ('v_attr_col4 = '||v_attr_col4);

                                if v_attr_col3 is not null OR v_attr_col4 is not null-- get value of DFF
                                then
                                    -- prepare cols for sql stmt
                                    select decode(v_attr_col3,NULL,'x','rctt.'||v_attr_col3)||' , '||decode(v_attr_col4,NULL,'x','rctt.'||v_attr_col4)
                                    into v_attr_cols 
                                    from dual; 
                                   
                                    v_sql_stmt3 := NULL; -- reset

                                      IF(g_docment_type_id<>0)
                                      then -- Invoice
                                         -- build sql stmt
                                         v_sql_stmt3 := 'select '||v_attr_cols||
                                                        ' from RA_CUSTOMER_TRX_all rct, RA_CUST_TRX_TYPES_ALL rctt 
                                                            where rct.CUST_TRX_TYPE_ID = rctt.CUST_TRX_TYPE_ID 
                                                            and rct.org_id = rctt.org_id 
                                                            and rct.customer_trx_id = '||g_trasaction_id;
                                         --- get DFF attribute column with transaction id value
                                         p_log ('v_sql_stmt3 = '||v_sql_stmt3);
										 begin
                                           EXECUTE IMMEDIATE v_sql_stmt3 INTO v_ava_call, v_zero_ava_call;
										 exception
											when others then
											  p_log ('Failed to get DFF values, defauling DFF to N, ERROR = '||sqlerrm);
											  v_ava_call := 'N';
											  v_zero_ava_call := 'N';
									     end;
                                      else -- sales quote
                                         -- build sql stmt
                                         v_sql_stmt3 := 'select '||v_attr_cols||
                                                        ' from oe_order_headers_all oeh , oe_transaction_types_all ott, RA_CUST_TRX_TYPES_ALL rctt
                                                            where oeh.ORDER_TYPE_ID = ott.transaction_type_id  
                                                            and oeh.org_id = ott.org_id 
                                                            and ott.org_id = rctt.org_id 
                                                            and ott.CUST_TRX_TYPE_ID = rctt.CUST_TRX_TYPE_ID 
                                                            and oeh.header_id = '||g_trasaction_id;
                                         --- get DFF attribute column with transaction id value
                                         p_log ('v_sql_stmt3 = '||v_sql_stmt3);
										 begin
											EXECUTE IMMEDIATE v_sql_stmt3 INTO v_ava_call, v_zero_ava_call;
										 exception
											when others then
											  p_log ('Failed to get DFF values, defauling DFF to N, ERROR = '||sqlerrm);
											  v_ava_call := 'N';
											  v_zero_ava_call := 'N';
									     end;
                                      end if;
                                         p_log ('v_ava_call = '||v_ava_call);
                                         p_log ('v_zero_ava_call = '||v_zero_ava_call);
                                end if;     
                    
                    P_LOG ('Make call to Avalara, v_ava_call = '||v_ava_call);
                    P_LOG ('Make call to Avalara for ZERO txn value, v_zero_ava_call = '||v_zero_ava_call);
                    
                    -- check DFF to call Avalara
                    if NVL(v_ava_call,'X') = 'N' -- dont call Avalara
                    then
                       P_LOG ('DFF set to prevent call to Avalara, skipping transaction... ');
                       continue; -- skip
                    end if;   

                    -- check DFF to call Avalara ZERO value txn
                    if NVL(v_zero_ava_call,'X') = 'N' -- dont call Avalara if ZERO value
                    then
                      v_txn_value := null;
                      -----------
                      IF(g_docment_type_id<>0)
                      then -- Invoice
                          --- check txn value
                            select nvl(sum (EXTENDED_AMOUNT),0) total_amt 
                            into v_txn_value
                            from RA_CUSTOMER_TRX_LINES_all
                            where CUSTOMER_TRX_ID=g_trasaction_id 
                            and LINE_TYPE = 'LINE';
                      else -- sales quote
                       -- call API to get order amounts
                         v_HEADER_ID := g_trasaction_id;
                         v_SUBTOTAL := NULL;
                          OE_OE_TOTALS_SUMMARY.ORDER_TOTALS(
                            P_HEADER_ID  => v_HEADER_ID,
                            P_SUBTOTAL   => v_SUBTOTAL,
                            P_DISCOUNT   => v_DISCOUNT,
                            P_CHARGES    => v_CHARGES,
                            P_TAX        => V_TAX
                          );
                          p_log('SUBTOTAL = ' || v_SUBTOTAL);
                          p_log('DISCOUNT = ' || v_DISCOUNT);
                          p_log('CHARGES  = ' || v_CHARGES);
                          p_log('TAX      = ' || v_TAX);
                         
                         v_txn_value :=  v_SUBTOTAL ; 
                      end if;      
                      --------------
                            p_log ('v_txn_value = '||v_txn_value);
                            
                        if v_txn_value = 0 -- dont call Avalara for zero value txn
                        then 
                          P_LOG ('DFF set to prevent call to Avalara for ZERO value txn, skipping transaction... ');
                          continue; -- skip
                        end if;  
                    end if;   
                    
                
                    -- START international ship to / bill to check
                          P_LOG ('International ship to/bill to check');
                              v_country := NULL;
                              -- get ship_to country using su site id
                            IF(g_docment_type_id<>0)
                            then -- Invoice

                              begin
                                select loc.COUNTRY into v_country
                                from
                                apps.HZ_PARTY_SITES hps,
                                apps.hz_cust_acct_sites_all site,
                                apps.HZ_CUST_SITE_USES_all su,
                                apps.RA_CUSTOMER_TRX_all rac,
                                apps.hz_locations loc
                                where rac.customer_trx_id = g_trasaction_id
                                and rac.SHIP_TO_SITE_USE_ID = su.site_use_id -- SHIP TO
                                and su.CUST_ACCT_SITE_ID = site.CUST_ACCT_SITE_ID
                                and site.PARTY_SITE_ID = hps.PARTY_SITE_ID
                                and hps.location_id = loc.location_id;
                              exception
                                 when others then
                                        v_country := NULL;
                              end;

                              if v_country is NULL
                              then
                                  -- get bill_to country
                                  begin
                                    select loc.COUNTRY into v_country
                                    from
                                    apps.HZ_PARTY_SITES hps,
                                    apps.hz_cust_acct_sites_all site,
                                    apps.HZ_CUST_SITE_USES_all su,
                                    apps.RA_CUSTOMER_TRX_all rac,
                                    apps.hz_locations loc
                                    where rac.customer_trx_id = g_trasaction_id
                                    and rac.BILL_TO_SITE_USE_ID = su.site_use_id -- BILL TO
                                    and su.CUST_ACCT_SITE_ID = site.CUST_ACCT_SITE_ID
                                    and site.PARTY_SITE_ID = hps.PARTY_SITE_ID
                                    and hps.location_id = loc.location_id;
                                  exception
                                     when others then
                                            v_country := NULL;
                                  end;
                              end if;
                            else -- Sale Order Quote
                              begin
                                select loc.COUNTRY into v_country
                                from
                                apps.HZ_PARTY_SITES hps,
                                apps.hz_cust_acct_sites_all site,
                                apps.HZ_CUST_SITE_USES_all su,
                                apps.oe_order_headers_all rac,
                                apps.hz_locations loc
                                where rac.header_id = g_trasaction_id
                                and rac.SHIP_TO_ORG_ID = su.site_use_id -- SHIP TO
                                and su.CUST_ACCT_SITE_ID = site.CUST_ACCT_SITE_ID
                                and site.PARTY_SITE_ID = hps.PARTY_SITE_ID
                                and hps.location_id = loc.location_id;
                              exception
                                 when others then
                                        v_country := NULL;
                              end;

                              if v_country is NULL
                              then
                                  -- get bill_to country
                                  begin
                                    select loc.COUNTRY into v_country
                                    from
                                    apps.HZ_PARTY_SITES hps,
                                    apps.hz_cust_acct_sites_all site,
                                    apps.HZ_CUST_SITE_USES_all su,
                                    apps.oe_order_headers_all  rac,
                                    apps.hz_locations loc
                                    where rac.header_id = g_trasaction_id
                                    and rac.INVOICE_TO_ORG_ID = su.site_use_id -- BILL TO
                                    and su.CUST_ACCT_SITE_ID = site.CUST_ACCT_SITE_ID
                                    and site.PARTY_SITE_ID = hps.PARTY_SITE_ID
                                    and hps.location_id = loc.location_id;
                                  exception
                                     when others then
                                            v_country := NULL;
                                  end;
                              end if;

                             end if; -- g_docment_type_id <> 0

                              P_LOG ('v_country = '||v_country);

                              if NVL(v_country,'X') <> 'US'
                              then
                                P_LOG ('NON-US country, skipping record... ');
                                 continue; -- skip if international
                              end if;
                    -- END international ship to / bill to check
                IF(pg_doc_type_id_tab(h)<>0)
                then
                   Begin
                     select  event_class_code
                     into    l_document_type
                     from    apps.zx_evnt_cls_mappings
                     where   event_class_mapping_id = pg_doc_type_id_tab(h);
                    Exception
                      When no_data_found then
                        P_LOG (SQLERRM);
                        x_error_status := FND_API.G_RET_STS_UNEXP_ERROR;
                        g_string :='No document type exist for provided event_class_mapping_id ';
                        P_LOG (g_string);
                        error_exception_handle(g_string);
                        x_messages_tbl:=g_messages_tbl;
                        return;
                    End;

                ELSE /*"Sales Transaction Quote*/
                    l_document_type := 'SALES_QUOTE';
                END IF;

                P_LOG (   ' DOCUMENT_TYPE  '||l_document_type);

               P_LOG (' Value of Variable H is :'||H);

               -- build XML msg structure for header record
               build_xml_header (p_mode => 'GET');

               --- get transaction lines to process

               if l_document_type <> 'SALES_QUOTE'
               then -- open invoice lines

                    open c_inv_trans_lines (pg_trx_id_tab(h));
                    fetch c_inv_trans_lines
                     bulk collect into
                        pg_trx_line_id_tab
                        ,pg_trx_level_type_tab
                        ,pg_line_level_action_tab
                        ,pg_line_class_tab
                        ,pg_trx_shipping_date_tab
                        ,pg_trx_receipt_date_tab
                        ,pg_trx_line_type_tab
                        ,pg_trx_line_date_tab
                        ,pg_trx_line_number_tab
                        ,pg_trx_line_desc_tab
                        ,pg_prv_tax_det_date_tab
                        ,pg_trx_business_cat_tab
                        ,pg_line_intended_use_tab
                        ,pg_line_amt_incl_tax_flag_tab
                        ,pg_line_amount_tab
                        ,pg_other_incl_tax_amt_tab
                        ,pg_trx_line_qty_tab
                        ,pg_unit_price_tab
                        ,pg_cash_discount_tab
                        ,pg_volume_discount_tab
                        ,pg_trading_discount_tab
                        ,pg_trans_charge_tab
                        ,pg_ins_charge_tab
                        ,pg_other_charge_tab
                        ,pg_prod_id_tab
                        ,pg_uom_code_tab
                        ,pg_prod_type_tab
                        ,pg_prod_code_tab
                        ,pg_fob_point_tab
                        ,pg_assess_value_tab
                        ,pg_prod_desc_tab
                        ,pg_account_ccid_tab
                        ,pg_exempt_certi_numb_tab
                        ,pg_exempt_reason_tab
                        ,pg_exempt_cont_flag_tab
                        ,pg_ship_fr_loc_id_tab
                        ,pg_ship_to_loc_id_tab
                        ,pg_bill_fr_loc_id_tab
                        ,pg_bill_to_loc_id_tab
                        ,pg_poa_loc_id_tab
                        ,pg_poo_loc_id_tab
                        ,pg_appl_from_trx_id_tab
                        ,pg_appl_from_line_id_tab
                        ,pg_appl_fr_trx_lev_type_tab
                        ,pg_appl_from_doc_num_tab
                        ,pg_adj_doc_trx_id_tab
                        ,pg_adj_doc_line_id_tab
                        ,pg_adj_doc_trx_lev_type_tab
                        ,pg_adj_doc_number_tab
                        ,pg_adj_doc_date_tab
                        ,pg_line_char1_tab
                        ,pg_line_char2_tab
                        ,pg_line_char3_tab
                        ,pg_line_char4_tab
                        ,pg_line_char5_tab
                        ,pg_line_char6_tab
                        ,pg_line_char7_tab
                        ,pg_line_char8_tab
                        ,pg_line_char9_tab
                        ,pg_line_char10_tab
                        ,pg_line_NUMERIC1_tab
                        ,pg_line_NUMERIC2_tab
                        ,pg_line_NUMERIC3_tab
                        ,pg_line_NUMERIC4_tab
                        ,pg_line_NUMERIC5_tab
                        ,pg_line_NUMERIC6_tab
                        ,pg_line_NUMERIC7_tab
                        ,pg_line_NUMERIC8_tab
                        ,pg_line_NUMERIC9_tab
                        ,pg_line_NUMERIC10_tab
                        ,pg_line_date1_tab
                        ,pg_line_date2_tab
                        ,pg_line_date3_tab
                        ,pg_line_date4_tab
                        ,pg_line_date5_tab
                        limit C_LINES_PER_COMMIT; -- limit the fetch

               else -- SO quote, open std view

                        open item_lines_to_be_processed (pg_trx_id_tab(h));
                        fetch item_lines_to_be_processed
                         bulk collect into
                        pg_trx_line_id_tab    ,
                        pg_trx_level_type_tab    ,
                        pg_line_level_action_tab  ,
                        pg_line_class_tab    ,
                        pg_trx_shipping_date_tab  ,
                        pg_trx_receipt_date_tab    ,
                        pg_trx_line_type_tab    ,
                        pg_trx_line_date_tab    ,
                        pg_trx_business_cat_tab    ,
                        pg_line_intended_use_tab  ,
                        pg_line_amt_incl_tax_flag_tab  ,
                        pg_line_amount_tab    ,
                        pg_other_incl_tax_amt_tab  ,
                        pg_trx_line_qty_tab    ,
                        pg_unit_price_tab    ,
                        pg_cash_discount_tab    ,
                        pg_volume_discount_tab    ,
                        pg_trading_discount_tab    ,
                        pg_trans_charge_tab    ,
                        pg_ins_charge_tab    ,
                        pg_other_charge_tab    ,
                        pg_prod_id_tab      ,
                        pg_uom_code_tab      ,
                        pg_prod_type_tab    ,
                        pg_prod_code_tab    ,
                        pg_fob_point_tab    ,
                        pg_ship_to_pty_numr_tab    ,
                        pg_ship_to_pty_name_tab    ,
                        pg_ship_from_pty_num_tab  ,
                        pg_ship_from_pty_name_tab  ,
                        pg_ship_to_loc_id_tab           ,
                        pg_ship_to_grphy_type1_tab      ,
                        pg_ship_to_grphy_value1_tab     ,
                        pg_ship_to_grphy_type2_tab      ,
                        pg_ship_to_grphy_value2_tab     ,
                        pg_ship_to_grphy_type3_tab      ,
                        pg_ship_to_grphy_value3_tab     ,
                        pg_ship_to_grphy_type4_tab      ,
                        pg_ship_to_grphy_value4_tab     ,
                        pg_ship_to_grphy_type5_tab      ,
                        pg_ship_to_grphy_value5_tab     ,
                        pg_ship_to_grphy_type6_tab      ,
                        pg_ship_to_grphy_value6_tab     ,
                        pg_ship_to_grphy_type7_tab      ,
                        pg_ship_to_grphy_value7_tab     ,
                        pg_ship_to_grphy_type8_tab      ,
                        pg_ship_to_grphy_value8_tab     ,
                        pg_ship_to_grphy_type9_tab      ,
                        pg_ship_to_grphy_value9_tab     ,
                        pg_ship_to_grphy_type10_tab     ,
                        pg_ship_to_grphy_value10_tab    ,
                        pg_ship_fr_loc_id_tab           ,
                        pg_ship_fr_grphy_type1_tab      ,
                        pg_ship_fr_grphy_value1_tab     ,
                        pg_ship_fr_grphy_type2_tab      ,
                        pg_ship_fr_grphy_value2_tab     ,
                        pg_ship_fr_grphy_type3_tab      ,
                        pg_ship_fr_grphy_value3_tab     ,
                        pg_ship_fr_grphy_type4_tab      ,
                        pg_ship_fr_grphy_value4_tab     ,
                        pg_ship_fr_grphy_type5_tab      ,
                        pg_ship_fr_grphy_value5_tab     ,
                        pg_ship_fr_grphy_type6_tab      ,
                        pg_ship_fr_grphy_value6_tab     ,
                        pg_ship_fr_grphy_type7_tab      ,
                        pg_ship_fr_grphy_value7_tab     ,
                        pg_ship_fr_grphy_type8_tab      ,
                        pg_ship_fr_grphy_value8_tab     ,
                        pg_ship_fr_grphy_type9_tab      ,
                        pg_ship_fr_grphy_value9_tab     ,
                        pg_ship_fr_grphy_type10_tab     ,
                        pg_ship_fr_grphy_value10_tab    ,
                        pg_poa_loc_id_tab               ,
                        pg_poa_grphy_type1_tab          ,
                        pg_poa_grphy_value1_tab         ,
                        pg_poa_grphy_type2_tab          ,
                        pg_poa_grphy_value2_tab         ,
                        pg_poa_grphy_type3_tab          ,
                        pg_poa_grphy_value3_tab         ,
                        pg_poa_grphy_type4_tab          ,
                        pg_poa_grphy_value4_tab         ,
                        pg_poa_grphy_type5_tab          ,
                        pg_poa_grphy_value5_tab         ,
                        pg_poa_grphy_type6_tab          ,
                        pg_poa_grphy_value6_tab         ,
                        pg_poa_grphy_type7_tab          ,
                        pg_poa_grphy_value7_tab         ,
                        pg_poa_grphy_type8_tab          ,
                        pg_poa_grphy_value8_tab         ,
                        pg_poa_grphy_type9_tab          ,
                        pg_poa_grphy_value9_tab         ,
                        pg_poa_grphy_type10_tab         ,
                        pg_poa_grphy_value10_tab        ,
                        pg_poo_loc_id_tab               ,
                        pg_poo_grphy_type1_tab          ,
                        pg_poo_grphy_value1_tab         ,
                        pg_poo_grphy_type2_tab          ,
                        pg_poo_grphy_value2_tab         ,
                        pg_poo_grphy_type3_tab          ,
                        pg_poo_grphy_value3_tab         ,
                        pg_poo_grphy_type4_tab          ,
                        pg_poo_grphy_value4_tab         ,
                        pg_poo_grphy_type5_tab          ,
                        pg_poo_grphy_value5_tab         ,
                        pg_poo_grphy_type6_tab          ,
                        pg_poo_grphy_value6_tab         ,
                        pg_poo_grphy_type7_tab          ,
                        pg_poo_grphy_value7_tab         ,
                        pg_poo_grphy_type8_tab          ,
                        pg_poo_grphy_value8_tab         ,
                        pg_poo_grphy_type9_tab          ,
                        pg_poo_grphy_value9_tab         ,
                        pg_poo_grphy_type10_tab         ,
                        pg_poo_grphy_value10_tab        ,
                        pg_bill_to_pty_num_tab    ,
                        pg_bill_to_pty_name_tab    ,
                        pg_bill_from_pty_num_tab  ,
                        pg_bill_from_pty_name_tab  ,
                        pg_bill_to_loc_id_tab           ,
                        pg_bill_to_grphy_type1_tab      ,
                        pg_bill_to_grphy_value1_tab     ,
                        pg_bill_to_grphy_type2_tab      ,
                        pg_bill_to_grphy_value2_tab     ,
                        pg_bill_to_grphy_type3_tab      ,
                        pg_bill_to_grphy_value3_tab     ,
                        pg_bill_to_grphy_type4_tab      ,
                        pg_bill_to_grphy_value4_tab     ,
                        pg_bill_to_grphy_type5_tab      ,
                        pg_bill_to_grphy_value5_tab     ,
                        pg_bill_to_grphy_type6_tab      ,
                        pg_bill_to_grphy_value6_tab     ,
                        pg_bill_to_grphy_type7_tab      ,
                        pg_bill_to_grphy_value7_tab     ,
                        pg_bill_to_grphy_type8_tab      ,
                        pg_bill_to_grphy_value8_tab     ,
                        pg_bill_to_grphy_type9_tab      ,
                        pg_bill_to_grphy_value9_tab     ,
                        pg_bill_to_grphy_type10_tab     ,
                        pg_bill_to_grphy_value10_tab    ,
                        pg_bill_fr_loc_id_tab           ,
                        pg_bill_fr_grphy_type1_tab      ,
                        pg_bill_fr_grphy_value1_tab     ,
                        pg_bill_fr_grphy_type2_tab      ,
                        pg_bill_fr_grphy_value2_tab     ,
                        pg_bill_fr_grphy_type3_tab      ,
                        pg_bill_fr_grphy_value3_tab     ,
                        pg_bill_fr_grphy_type4_tab      ,
                        pg_bill_fr_grphy_value4_tab     ,
                        pg_bill_fr_grphy_type5_tab      ,
                        pg_bill_fr_grphy_value5_tab     ,
                        pg_bill_fr_grphy_type6_tab      ,
                        pg_bill_fr_grphy_value6_tab     ,
                        pg_bill_fr_grphy_type7_tab      ,
                        pg_bill_fr_grphy_value7_tab     ,
                        pg_bill_fr_grphy_type8_tab      ,
                        pg_bill_fr_grphy_value8_tab     ,
                        pg_bill_fr_grphy_type9_tab      ,
                        pg_bill_fr_grphy_value9_tab     ,
                        pg_bill_fr_grphy_type10_tab     ,
                        pg_bill_fr_grphy_value10_tab    ,
                        pg_account_ccid_tab    ,
                        pg_appl_from_trx_id_tab    ,
                        pg_appl_from_line_id_tab  ,
                        pg_appl_fr_trx_lev_type_tab  ,
                        pg_appl_from_doc_num_tab  ,
                        pg_adj_doc_doc_type_id_tab  ,
                        pg_adj_doc_trx_id_tab    ,
                        pg_adj_doc_line_id_tab    ,
                        pg_adj_doc_number_tab    ,
                        pg_adj_doc_trx_lev_type_tab  ,
                        pg_adj_doc_date_tab    ,
                        pg_assess_value_tab    ,
                        pg_trx_line_number_tab    ,
                        pg_trx_line_desc_tab    ,
                        pg_prod_desc_tab    ,
                        pg_line_char1_tab    ,
                        pg_line_char2_tab    ,
                        pg_line_char3_tab    ,
                        pg_line_char4_tab    ,
                        pg_line_char5_tab    ,
                        pg_line_char6_tab    ,
                        pg_line_char7_tab    ,
                        pg_line_char8_tab    ,
                        pg_line_char9_tab    ,
                        pg_line_char10_tab    ,
                        pg_line_char11_tab    ,
                        pg_line_char12_tab    ,
                        pg_line_char13_tab    ,
                        pg_line_char14_tab    ,
                        pg_line_char15_tab    ,
                        pg_line_numeric1_tab    ,
                        pg_line_numeric2_tab    ,
                        pg_line_numeric3_tab    ,
                        pg_line_numeric4_tab    ,
                        pg_line_numeric5_tab    ,
                        pg_line_numeric6_tab    ,
                        pg_line_numeric7_tab    ,
                        pg_line_numeric8_tab    ,
                        pg_line_numeric9_tab    ,
                        pg_line_numeric10_tab    ,
                        pg_line_date1_tab    ,
                        pg_line_date2_tab    ,
                        pg_line_date3_tab    ,
                        pg_line_date4_tab    ,
                        pg_line_date5_tab    ,
                        pg_exempt_certi_numb_tab  ,
                        pg_exempt_reason_tab    ,
                        pg_exempt_cont_flag_tab
                       limit C_LINES_PER_COMMIT; -- limit the fetch
               end if;

                IF (nvl(pg_trx_line_id_tab.last,0) = 0)
                Then
                  x_error_status := FND_API.G_RET_STS_UNEXP_ERROR;
                  g_string :='No lines exist for Transaction id -'|| pg_trx_id_tab(h);
                  P_LOG (g_string);
                  error_exception_handle(g_string);
                  x_messages_tbl:=g_messages_tbl;
                  return;
                ELSE --lines cursor has returned some rows that can be processed
                 ---build XML tag for lines
                 build_xml_lines_tag ('START');

                -- loop through trans lines
                   For lns in 1..nvl(pg_trx_line_id_tab.last, 0)
                   loop

                     L := lns;
                       g_transaction_line_id  :=  pg_trx_line_id_tab(l);

                       -- validate action levels
                       Perform_validate(l_return_status);

                      IF l_return_status <> FND_API.G_RET_STS_SUCCESS
                      THEN
                         P_LOG (SQLERRM);
                         x_error_status := FND_API.G_RET_STS_UNEXP_ERROR;
                         g_string :='Header ,line level actions are incompaitable';
                          P_LOG (g_string);
                         error_exception_handle(g_string);
                         x_messages_tbl:=g_messages_tbl;
                         return;
                      END IF;

                      -- all good, build lines xml structure
                      build_xml_lines;

                   end loop; -- trans lines
                  -- close lines tag
                  build_xml_lines_tag ('END');

                 END IF; -- trans_line_count

                     --post XML Request to Avalara
                        xml_request_response  ( v_clob,'GET',l_return_status );

                         IF l_return_status <> FND_API.G_RET_STS_SUCCESS THEN
                             if v_clob_created then
                                dbms_lob.freetemporary (lob_loc => v_clob);
                                v_clob_created := false;
                             end if;
                                x_error_status := FND_API.G_RET_STS_UNEXP_ERROR;
                                g_string := g_string ||'-'||'Failed in GetTax Request to Avalara';
                                P_LOG (g_string);
                                error_exception_handle(g_string);
                                x_messages_tbl:=g_messages_tbl;
                                return;
                         END IF;

                         --response success, read the values and post tax to trans lines
                         tax_results_processing(x_tax_lines_tbl,p_currency_tab,l_return_status);

                                   IF l_return_status <> FND_API.G_RET_STS_SUCCESS THEN
                                     P_LOG(SQLERRM);
                                     x_error_status := FND_API.G_RET_STS_UNEXP_ERROR;
                                     g_string := g_string ||'-'||'Failed in TAX_RESULTS_PROCESSING procedure';
                                     P_LOG (g_string);
                                     error_exception_handle(g_string);
                                     x_messages_tbl:=g_messages_tbl;
                                     return;
                                   END IF;

                     p_log ('checking complete flag of trans id - '||pg_trx_id_tab(h));

                     -- commit; -- cannot commit as it gives post-form exception on UI

                       if l_document_type <> 'SALES_QUOTE'
                       then -- check only for invoice
                            -- check if Invoice transaction flagged COMPLETE
                            v_complete_flag := NULL;
                            v_request_id := NULL;
                            begin  --use request id to check auto-invoice, dont post for auto invoice as it will be done later
                              select request_id, decode(request_id,NULL,complete_flag,'N')
                                into v_request_id, v_complete_flag
                              from apps.RA_CUSTOMER_TRX_all
                               where CUSTOMER_TRX_ID = pg_trx_id_tab(h);
                            exception
                              when others then
                                p_log ('others exp getting complete flag');
                                p_log ('error - '|| sqlerrm);
                                v_complete_flag := NULL;
                                v_request_id := NULL;
                            end;

                            p_log ('v_complete_flag = '||v_complete_flag);
                            p_log ('v_request_id = '||v_request_id);

                            if v_request_id is NOT NULL -- auto invoice
                            then
                             -- only update for auto-invoice transactions as they skip FP
                            -- update DFF on header with Transaction id 3-may-13
                            -- get attribute column used for this DFF
                               if v_attr_col1 is null
                               then
                                  BEGIN
                                    SELECT APPLICATION_COLUMN_NAME
                                    INTO v_attr_col1
                                    FROM FND_DESCR_FLEX_COL_USAGE_VL
                                    WHERE (APPLICATION_ID=222) and
                                    (DESCRIPTIVE_FLEXFIELD_NAME LIKE 'RA_CUSTOMER_TRX') and
                                    (DESCRIPTIVE_FLEX_CONTEXT_CODE='Global Data Elements')
                                    and upper(END_USER_COLUMN_NAME) = 'TRANSACTION ID';
                                  EXCEPTION WHEN OTHERS THEN
                                   v_attr_col1 := NULL;
                                   p_log ('Error selecting DFF column at header level - '||sqlerrm);
                                  END;
                                end if;
                             p_log ('v_attr_col1 = '||v_attr_col1);

                                if v_attr_col1 is not null
                                then
                                    v_sql_stmt := null;
                                     -- build sql stmt
                                     v_sql_stmt := 'update RA_CUSTOMER_TRX_ALL set '||v_attr_col1||' = '||pg_trx_id_tab(h)
                                                    ||' where CUSTOMER_TRX_ID = '||pg_trx_id_tab(h)
                                                    ||' and NVL('||v_attr_col1||',0) <> '||pg_trx_id_tab(h);
                                     --- update DFF attribute column with transaction id value
                                     EXECUTE IMMEDIATE v_sql_stmt;
                                     p_log ('v_sql_stmt = '||v_sql_stmt);
                                end if;
								
								-- set flag in AVA temp table to process POST transactions for Auto Invoice after tax run
								update AVALARA.AVLR_TMP_ZX_O2C_CALC_TXN_INPUT
								set HEADER_CHAR29 = 'Y'
								where transaction_id = pg_trx_id_tab(h);
                            end if;--- v_reuest_id not null

                            if NVL(v_complete_flag,'N') = 'Y'
                            then
                              -- transaction is complete, send post-commit to Avalara
                              -- build XML msg structure for header record
                                build_xml_header (p_mode => 'POST');

                              --post XML Request to Avalara
                                xml_request_response  ( v_clob,'POST',l_return_status );

                                p_log ('l_return_status = '||l_return_status);


                                 IF l_return_status <> FND_API.G_RET_STS_SUCCESS THEN
                                     if v_clob_created then
                                        dbms_lob.freetemporary (lob_loc => v_clob);
                                        v_clob_created := false;
                                     end if;
                                        x_error_status := FND_API.G_RET_STS_ERROR;
                                        g_string := g_string ||'-'||'Failed in PostCommit Request to Avalara';
                                        P_LOG (g_string);
                                        error_exception_handle(g_string);
                                        x_messages_tbl:=g_messages_tbl;
                                        return;
                                 END IF;
                            end if;--- v_complete_flag

                       end if; -- l_document_type <> 'SALES_QUOTE'

           end loop; -- trans header

    end if; -- pg_trx_id_tab.last

 P_LOG (  'END - '||G_PKG_NAME||': '||l_api_name||'(-)');

EXCEPTION
 when others then
     P_LOG (SQLERRM);
     x_error_status := FND_API.G_RET_STS_UNEXP_ERROR;
     g_string :='Unhandled Exception Error in CALCULATE_TAX_API';
     P_LOG (g_string);
     error_exception_handle(g_string);
     x_messages_tbl:=g_messages_tbl;

         if v_clob_created then
            dbms_lob.freetemporary (lob_loc => v_clob);
            v_clob_created := false;
         end if;

     return;
END CALCULATE_TAX_API;

PROCEDURE SET_DOCUMENT_TYPE( P_DOCUMENT_TYPE  IN OUT NOCOPY VARCHAR2,
           P_ADJ_DOC_TRX_ID IN NUMBER,
           P_LINE_AMOUNT    IN NUMBER,
           p_LINE_LEVEL_ACTION IN VARCHAR2,
           x_return_status  OUT NOCOPY VARCHAR2)IS
l_api_name           CONSTANT VARCHAR2(30) := 'SET_DOCUMENT_TYPE';
BEGIN
   x_return_status := FND_API.G_RET_STS_SUCCESS;

     P_LOG ('BEGIN - '||G_PKG_NAME||': '||l_api_name||'(+)');
     P_LOG('P_DOCUMENT_TYPE : '||P_DOCUMENT_TYPE );
     P_LOG('P_ADJ_DOC_TRX_ID : '||P_ADJ_DOC_TRX_ID);
     P_LOG('P_LINE_LEVEL_ACTION : '||p_line_level_action);
     P_LOG('P_LINE_AMOUNT : '||P_LINE_AMOUNT);

   IF (p_document_type = 'CREDIT_MEMO') THEN
      IF (p_adj_doc_trx_id is not null) THEN
         IF p_line_amount = 0 THEN
            p_document_type :='TAX_ONLY_CREDIT_MEMO';
         ELSIF p_line_level_action = 'RECORD_WITH_NO_TAX' THEN
         --ELSIF (pg_allow_tax_calc_tab(I) ='N') THEN
            p_document_type :='LINE_ONLY_CREDIT_MEMO';
         ELSE
            p_document_type :='APPLIED_CREDIT_MEMO';
         END IF;     /*LINE_AMOUNT*/
      ELSE
        p_document_type :='ON_ACCT_CREDIT_MEMO';
      END IF;     /*ADJ_DOC_TRX_ID*/
   END IF;     /*'CREDIT_MEMO*/

   IF (p_document_type = 'INVOICE') THEN
      IF (p_line_amount = 0 AND p_line_level_action = 'LINE_INFO_TAX_ONLY') THEN
         p_document_type :='TAX_ONLY_INVOICE';
      END IF;
   END IF;/*INVOICE*/

   IF (p_document_type = 'INVOICE_ADJUSTMENT') THEN
      IF (p_line_amount = 0) THEN
         p_document_type := 'TAX_ONLY_ADJUSTMENT';
      END IF;
   END IF;     /*INVOICE_ADJUSTMENT*/

   P_LOG('END - '||G_PKG_NAME||': '||l_api_name||'(-)' );

End SET_DOCUMENT_TYPE;

PROCEDURE PERFORM_VALIDATE(x_return_status OUT NOCOPY VARCHAR2) is
l_api_name           CONSTANT VARCHAR2(30) := 'PERFORM_VALIDATE';

Begin
  x_return_status := FND_API.G_RET_STS_SUCCESS;

     P_LOG('BEGIN - '||G_PKG_NAME||': '||l_api_name||'(+)');

       P_LOG('PG_DOC_LEVEL_ACTION_TAB(i)  :  '||pg_doc_level_action_tab(h));
       P_LOG('PG_LINE_LEVEL_ACTION_TAB(i) : '||pg_line_level_action_tab(l));

      if(pg_doc_level_action_tab(h) = 'CREATE') Then
         if(pg_line_level_action_tab(l) NOT IN ('CREATE', 'QUOTE','SYNCHRONIZE','RECORD_WITH_NO_TAX')) Then
               P_LOG('Unknown line level action');
            x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
         end if;
      elsif(pg_doc_level_action_tab(h) = 'QUOTE') Then
         if(pg_line_level_action_tab(l) NOT IN ('QUOTE')) Then
               P_LOG('Unknown line level action');
            x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
         end if;
      elsif(pg_doc_level_action_tab(h) = 'UPDATE') Then
          if(pg_line_level_action_tab(l) NOT IN ('CREATE', 'UPDATE', 'QUOTE', 'CANCEL', 'DELETE', 'SYNCHRONIZE','RECORD_WITH_NO_TAX')) Then
               P_LOG('Unknown line level action');
            x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
          end if;
      else
               P_LOG('Unknown header level action');
      x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
    end if;

     P_LOG('END - '||G_PKG_NAME||': '||l_api_name||'(-)');
End PERFORM_VALIDATE;


--==========================
-- xml request and response
--=====================================
PROCEDURE xml_request_response   (p_request_body IN CLOB, -- xml request body
                                 p_mode IN VARCHAR2 default 'GET',
                                 p_return_status OUT NOCOPY VARCHAR2,
                                 p_trans_id IN NUMBER DEFAULT NULL
                                 )
AS
   utl_req         UTL_HTTP.req;
   utl_resp        UTL_HTTP.resp;
   req_length      binary_integer;
   response_doc    xmldom.domdocument;
   v_request_doc   xmldom.domdocument;
   resp_length     binary_integer;
   buffer          varchar2 (2000);
   amount          pls_integer := 2000;
   offset          pls_integer := 1;
   v_request       clob;
   v_response_status varchar2 (60);
   V_XML_SEQ number;
   V_RXML_SEQ number;
   v_trans_id number;

   ow_loc          FND_PROFILE_OPTION_VALUES.profile_option_value%TYPE := NULL;
   ow_pswd         FND_PROFILE_OPTION_VALUES.profile_option_value%TYPE := NULL;
   v_ava_url       FND_PROFILE_OPTION_VALUES.profile_option_value%TYPE := NULL;
   v_user          FND_PROFILE_OPTION_VALUES.profile_option_value%TYPE := NULL;
   v_get_url       varchar2(100) := NULL;
   v_post_url      varchar2(100) := NULL;
   v_void_url      varchar2(100) := NULL;
   v_ping_url      varchar2(100) := NULL;
   v_addrv_url      varchar2(100) := NULL;
   v_url           varchar2(100) := NULL;
   ----------

   -- static values
   v_mode_get_st_tag VARCHAR2 (150) := NULL;
   v_mode_get_en_tag VARCHAR2 (60) := NULL;
   -----
   v_mode_post_st_tag VARCHAR2 (150) := NULL;
   v_mode_post_en_tag VARCHAR2 (60) := NULL;
   ----
   v_mode_void_st_tag VARCHAR2 (150) := NULL;
   v_mode_void_en_tag VARCHAR2 (60) := NULL;
   ----
   v_mode_ping_st_tag VARCHAR2 (150) := NULL;
   v_mode_ping_en_tag VARCHAR2 (60) := NULL;
   -----
   v_mode_addrv_st_tag VARCHAR2 (150) := NULL;
   v_mode_addrv_en_tag VARCHAR2 (60) := NULL;
   ----
   ------------

  l_api_name       CONSTANT VARCHAR2(30) := 'xml_request_response';

BEGIN
 P_LOG ('BEGIN - ' ||G_PKG_NAME||': '||l_api_name||'(+)');

 p_return_status := FND_API.G_RET_STS_SUCCESS;
 response_body := NULL;

 --- get profile values
   ow_loc    := get_profile ('AVA_OWM_WALLET_FILE_LOC', NULL);
   ow_pswd   := get_profile('AVA_OWM_WALLET_PSWRD', NULL);
   v_ava_url := get_profile('AVA_CONNECT_ACCOUNT_URL', NULL);
   v_user    := get_profile('AVA_CONNECT_ACCOUNT_USER', NULL);
   -- set URL values
   v_get_url        := v_ava_url||'getTax';
   v_post_url       := v_ava_url||'postAndCommitTax';
   v_void_url       := v_ava_url||'cancelTax';
   v_ping_url       := v_ava_url||'ping';
   v_addrv_url      := v_ava_url||'validateAddress';

   -- static values
   v_mode_get_st_tag  := '<?xml version="1.0"?><AVALARA_TAX_TRANSACTION><USER_ID>' ||v_user|| '</USER_ID>';
   v_mode_get_en_tag  := '</AVALARA_TAX_TRANSACTION>';
   -----
   v_mode_post_st_tag := '<?xml version="1.0"?><AVALARA_POST_AND_COMMIT_TAX_REQUEST><USER_ID>' ||v_user|| '</USER_ID>';
   v_mode_post_en_tag := '</AVALARA_POST_AND_COMMIT_TAX_REQUEST>';
   ----
   v_mode_void_st_tag := '<?xml version="1.0"?><AVALARA_CANCEL_TAX_REQUEST><USER_ID>' ||v_user|| '</USER_ID>';
   v_mode_void_en_tag := '</AVALARA_CANCEL_TAX_REQUEST>';
   ----
   v_mode_ping_st_tag := '<?xml version="1.0"?><AVALARA_PING_REQUEST><USER_ID>' ||v_user|| '</USER_ID>';
   v_mode_ping_en_tag := '</AVALARA_PING_REQUEST>';
   ----
   v_mode_addrv_st_tag := '<?xml version="1.0"?><LocationService><USER_ID>' ||v_user|| '</USER_ID>';
   v_mode_addrv_en_tag := '</LocationService>';
   ------------

 if ow_loc is null OR
    ow_pswd is null OR
    v_get_url is null OR
    v_post_url is null OR
    v_void_url is null OR
    v_addrv_url is null OR
    v_user is null
 then
    p_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
    g_string :='Mandatory lookup values missing to establish connection with Avalara.';
    return;
 end if;

 if p_request_body is null
 then
    p_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
    g_string :='Request is NULL, No XML Request to post.';
    return;
 end if;
 
   --- check request mode and tag as per request
   if p_mode = 'GET'
   then
     v_request := v_mode_get_st_tag ||p_request_body||v_mode_get_en_tag;
     v_url := v_get_url;
     v_trans_id := pg_trx_id_tab(h);
   elsif p_mode = 'POST'
   then
     v_request := v_mode_post_st_tag ||p_request_body||v_mode_post_en_tag;
     v_url := v_post_url;
     v_trans_id := pg_trx_id_tab(h);
   elsif p_mode = 'VOID'
   then
     v_request := v_mode_void_st_tag ||p_request_body||v_mode_void_en_tag;
     v_url := v_void_url;
     v_trans_id := pg_trx_id_tab(h);
   elsif p_mode = 'PING'
   then
     v_request := v_mode_ping_st_tag ||v_mode_ping_en_tag;
     v_url := v_ping_url;
     v_trans_id := nvl(p_trans_id,0);
   elsif p_mode = 'ADDRV'
   then
     v_request := v_mode_addrv_st_tag ||p_request_body||v_mode_addrv_en_tag;
     v_url := v_addrv_url;
     v_trans_id := nvl(p_trans_id,0);
   end if;

   utl_http.set_wallet(ow_loc,ow_pswd);
   P_LOG ('Oracle Wallet setup complete');

   P_LOG ('establishing connection ...');
   P_LOG ('v_url = '||v_url);

   utl_req := UTL_HTTP.begin_request (v_url, 'POST', 'HTTP/1.1');
   UTL_HTTP.set_header (utl_req, 'Content-Type', 'text/xml');

   P_LOG ('connection established to post XML');


    -- write XML to table
     p_log('XML generated and assigned to LOB.  Now write to table');

     -- get new seq_no
     begin
        select avalara.AVLR_TAX_XML_SEQ.nextval
        into   v_xml_seq
        from   dual;
            p_log ('v_xml_seq = '||v_xml_seq);
     exception when others then
           p_log('Exception when others while getting next sequence number from AVLR_TAX_XML_SEQ - ' || sqlerrm);
     end;

     -- Insert into AVLR_TAX_XML
      avalara.AVLR_WRITE_TAX_XML ( in_mode => 'INSERT',
                                   in_seqno => v_xml_seq,
                                   in_trans_id => v_trans_id,
                                   in_status => NULL,
                                   in_xml => v_request
                                 );

      -- parse clob into XML document
       p_log('Parsing XML request message');
       v_request_doc := xml.parse (v_request);

       if not xmldom.isnull (v_request_doc)
       then
          -- parsed successfully
           p_log( 'Parsing complete. Posting XML');

           req_length := DBMS_LOB.getlength (v_request);

           P_LOG ( 'XML req_length = ' || req_length );

           --- If Message data under 32kb limit
           if req_length <= 32767
           then

               UTL_HTTP.set_header (utl_req, 'Content-Length', req_length);
               UTL_HTTP.write_text (utl_req, v_request);

           --If Message data more than 32kb
           elsif req_length>32767
           then
            UTL_HTTP.set_header (utl_req, 'Transfer-Encoding', 'chunked');

               WHILE (offset < req_length)
               LOOP
                  DBMS_LOB.read (v_request,
                                 amount,
                                 offset,
                                 buffer);

                  p_log( 'buffer = ' || buffer );

                  UTL_HTTP.write_text (utl_req, buffer);
                  offset := offset + amount;

                  p_log ( 'offset = ' || offset );

               END LOOP;
           end if;

           utl_resp := UTL_HTTP.get_response (utl_req);
           UTL_HTTP.read_text (utl_resp, response_body);
           UTL_HTTP.end_response (utl_resp);

            if response_body is not null
            then
                 -- write XML to table
                  p_log('XML response received, now write to table');

                  -- get new seq_no
                  begin
                     select avalara.AVLR_TAX_XML_SEQ.nextval
                     into   v_rxml_seq
                     from   dual;
                     p_log ('v_rxml_seq = '||v_rxml_seq);
                  exception when others then
                     p_log('Exception when others while getting next sequence number from AVLR_TAX_XML_SEQ - ' || sqlerrm);
                  end;

                  -- Insert into AVLR_TAX_XML
                  avalara.AVLR_WRITE_TAX_XML ( in_mode => 'INSERT',
                                               in_seqno => v_rxml_seq,
                                               in_trans_id => v_trans_id,
                                               in_status => 'Response from Avalara on seq_no - '||v_xml_seq,
                                               in_xml => response_body
                                             );

                   -- now parse into xml doc and return
                   begin
                     response_doc := xml.parse (response_body);
                   exception
                     when others then
                        p_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
                        g_string :='Error parsing XML response -  '|| sqlerrm;
                        P_LOG ( g_string );
                        response_doc := NULL;
                   end;


                   if not xmldom.isnull (response_doc)
                   then
                           p_log( 'Response received, now reading status from response doc');

                       if p_mode = 'GET'
                       then
                         v_response_status := xpath.valueof (response_doc, '/AVALARA_GET_TAX_RESPONSE/RESPONSE_STATUS');
                       elsif p_mode = 'POST'
                       then
                         v_response_status := xpath.valueof (response_doc, '/AVALARA_POST_AND_COMMIT_TAX_RESPONSE/RESPONSE_STATUS');
                       elsif p_mode = 'VOID'
                       then
                         v_response_status := xpath.valueof (response_doc, '/AVALARA_CANCEL_TAX_RESPONSE/RESPONSE_STATUS');
                       elsif p_mode = 'PING'
                       then
                         v_response_status := xpath.valueof (response_doc, '/AVALARA_PING_RESPONSE/RESPONSE_STATUS');
                       end if;

                       p_log('Update response status in Tax XML Table');
                       -- update status AVLR_TAX_XML
                       avalara.AVLR_WRITE_TAX_XML ( in_mode => 'UPDATE',
                                                     in_seqno => v_xml_seq,
                                                     in_trans_id => null,
                                                     in_status => v_response_status,
                                                     in_xml => null
                                                  ) ;

                                if nvl(v_response_status,'SUCCESS') <> 'SUCCESS' -- handle for ADDRV
                                then
                                  -- read error desc
                                   if p_mode = 'GET'
                                   then
                                        g_string :='Failure in AVALARA Tax Response: '||xpath.valueof (response_doc, '/AVALARA_GET_TAX_RESPONSE/ERROR_CODE')
                                                                                    ||'-'||xpath.valueof (response_doc, '/AVALARA_GET_TAX_RESPONSE/ERROR_DESCRIPTION');
                                   elsif p_mode = 'POST'
                                   then
                                        g_string :='Failure in AVALARA Tax Response: '||xpath.valueof (response_doc, '/AVALARA_POST_AND_COMMIT_TAX_RESPONSE/ERROR_CODE')
                                                                                    ||'-'||xpath.valueof (response_doc, '/AVALARA_POST_AND_COMMIT_TAX_RESPONSE/ERROR_DESCRIPTION');
                                   elsif p_mode = 'VOID'
                                   then
                                        g_string :='Failure in AVALARA Tax Response: '||xpath.valueof (response_doc, '/AVALARA_CANCEL_TAX_RESPONSE/ERROR_CODE')
                                                                                    ||'-'||xpath.valueof (response_doc, '/AVALARA_CANCEL_TAX_RESPONSE/ERROR_DESCRIPTION');
                                   elsif p_mode = 'PING'
                                   then
                                        g_string :='Failure in AVALARA Tax Response: '||xpath.valueof (response_doc, '/AVALARA_PING_RESPONSE/ERROR_CODE')
                                                                                    ||'-'||xpath.valueof (response_doc, '/AVALARA_PING_RESPONSE/ERROR_DESCRIPTION');

                                   end if;
                                    P_LOG (g_string );
                                    p_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
                                    --return;
                                end if;

                   end if;
            else
                  p_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
                  g_string := 'Response XML Doc is NULL, Failure Generating Avalara Response.';
                  P_LOG (g_string);
                  --return;
            end if;
       else
          p_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
          g_string := 'Request XML Doc is NULL, Failure Generating Avalara Request.';
          P_LOG (g_string);
          --return;
       end if;

      --- free temp clob from memory
      if v_clob_created then
         dbms_lob.freetemporary (lob_loc => v_clob);
         v_clob_created := false;
      end if;

 P_LOG ('END - ' ||G_PKG_NAME||': '||l_api_name||'(-)');

exception
 when others then
    p_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
    g_string :='Others Exception in '||G_PKG_NAME||': '||l_api_name ||' = '|| sqlerrm;
    P_LOG ( g_string );
END xml_request_response;
--========================

--==========================
-- build xml header msg
--=====================================
PROCEDURE build_xml_header (p_mode IN VARCHAR2 default 'GET' )
IS

v_total_amt number;
v_total_tax number;

BEGIN
                v_tax_request_doc :='';

                -- check if lob session created
                if not v_clob_created
                then
                   -- create a temp lob session to store clob value
                  dbms_lob.createtemporary (lob_loc => v_clob,
                                            cache => true,
                                            dur => dbms_lob.session
                                            );
                  -- Set flag (it will be use in others excetion to recognize if CLOB memory has to be released.
                  v_clob_created := true;
                end if;

                  -- CLOB created
                  -- Start adding information to XML
                  p_log('CLOB created.  Start adding XML');

   --- check request mode and build xml as per request
   if p_mode = 'GET'
   then

                  v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_HEADER>';
                      -- org_id
                      v_tax_request_doc := v_tax_request_doc || '<INTERNAL_ORGANIZATION_ID>'||pg_internal_org_id_tab(h)||'</INTERNAL_ORGANIZATION_ID>';
                      -- document_type
                      v_tax_request_doc := v_tax_request_doc || '<DOCUMENT_TYPE_ID>'||pg_doc_type_id_tab(h)||'</DOCUMENT_TYPE_ID>';
                      -- trans id
                      v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_ID>'||pg_trx_id_tab(h)||'</TRANSACTION_ID>';
                      -- appl code
                      v_tax_request_doc := v_tax_request_doc || '<APPLICATION_CODE>'||cl(pg_appli_code_tab(h))||'</APPLICATION_CODE>';
                      -- action
                      v_tax_request_doc := v_tax_request_doc || '<DOCUMENT_LEVEL_ACTION>'||cl(pg_doc_level_action_tab(h))||'</DOCUMENT_LEVEL_ACTION>';
                      -- transaction date
                      v_tax_request_doc := v_tax_request_doc || '<TRX_DATE>'||to_char (pg_trx_date_tab(h), 'DD-MON-RR')||'</TRX_DATE>';
                      -- currency code
                      v_tax_request_doc := v_tax_request_doc || '<TRX_CURRENCY_CODE>'||cl (pg_trx_curr_code_tab(h))||'</TRX_CURRENCY_CODE>';
                      --legal entity
                      v_tax_request_doc := v_tax_request_doc || '<LEGAL_ENTITY_NUMBER>'||cl(pg_legal_entity_num_tab(h))||'</LEGAL_ENTITY_NUMBER>';
                      --establishment_number
                      v_tax_request_doc := v_tax_request_doc || '<ESTABLISHMENT_NUMBER>'||cl(pg_esta_name_tab(h))||'</ESTABLISHMENT_NUMBER>';
                      --TRANSACTION_NUMBER
                      -- using txn_id to resolve auto invoice null txn number issue
                      v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_NUMBER>'||pg_trx_id_tab(h)||'</TRANSACTION_NUMBER>';
                      --v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_NUMBER>'||pg_trx_number_tab(h)||'</TRANSACTION_NUMBER>';
                      --TRANSACTION_DESCRIPTION
                      v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_DESCRIPTION>'||cl(pg_trx_desc_tab(h))||'</TRANSACTION_DESCRIPTION>';
                      --DOCUMENT_SEQUENCE_VALUE
                      v_tax_request_doc := v_tax_request_doc || '<DOCUMENT_SEQUENCE_VALUE>'||pg_doc_sequence_value_tab(h)||'</DOCUMENT_SEQUENCE_VALUE>';
                      --TRANSACTION_DUE_DATE
                      v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_DUE_DATE>'||to_char (pg_trx_due_date_tab(h), 'DD-MON-RR')||'</TRANSACTION_DUE_DATE>';
                      --ALLOW_TAX_CALCULATION
                      v_tax_request_doc := v_tax_request_doc || '<ALLOW_TAX_CALCULATION>'||cl(pg_allow_tax_calc_tab(h))||'</ALLOW_TAX_CALCULATION>';
                      --HEADER_ATTRIBUTES
                      v_tax_request_doc := v_tax_request_doc || '<HEADER_ATTRIBUTES>';
                       -- chars

                        -- pass invoice number in CHAR1
                         pg_header_char1_tab(h) := pg_trx_number_tab(h);
                        --------

                        v_tax_request_doc := v_tax_request_doc || '<CHAR1>'||cl(pg_header_char1_tab(h))||'</CHAR1>';
                        v_tax_request_doc := v_tax_request_doc || '<CHAR2>'||cl(pg_header_char2_tab(h))||'</CHAR2>';
                        v_tax_request_doc := v_tax_request_doc || '<CHAR3>'||cl(pg_header_char3_tab(h))||'</CHAR3>';
                        v_tax_request_doc := v_tax_request_doc || '<CHAR4>'||cl(pg_header_char4_tab(h))||'</CHAR4>';
                        v_tax_request_doc := v_tax_request_doc || '<CHAR5>'||cl(pg_header_char5_tab(h))||'</CHAR5>';
                        v_tax_request_doc := v_tax_request_doc || '<CHAR6>'||cl(pg_header_char6_tab(h))||'</CHAR6>';
                        v_tax_request_doc := v_tax_request_doc || '<CHAR7>'||cl(pg_header_char7_tab(h))||'</CHAR7>';
                        v_tax_request_doc := v_tax_request_doc || '<CHAR8>'||cl(pg_header_char8_tab(h))||'</CHAR8>';
                        v_tax_request_doc := v_tax_request_doc || '<CHAR9>'||cl(pg_header_char9_tab(h))||'</CHAR9>';
                        v_tax_request_doc := v_tax_request_doc || '<CHAR10>'||cl(pg_header_char10_tab(h))||'</CHAR10>';
                       --numbers
                        v_tax_request_doc := v_tax_request_doc || '<NUMERIC1>'||pg_header_NUMERIC1_tab(h)||'</NUMERIC1>';
                        v_tax_request_doc := v_tax_request_doc || '<NUMERIC2>'||pg_header_NUMERIC2_tab(h)||'</NUMERIC2>';
                        v_tax_request_doc := v_tax_request_doc || '<NUMERIC3>'||pg_header_NUMERIC3_tab(h)||'</NUMERIC3>';
                        v_tax_request_doc := v_tax_request_doc || '<NUMERIC4>'||pg_header_NUMERIC4_tab(h)||'</NUMERIC4>';
                        v_tax_request_doc := v_tax_request_doc || '<NUMERIC5>'||pg_header_NUMERIC5_tab(h)||'</NUMERIC5>';
                        v_tax_request_doc := v_tax_request_doc || '<NUMERIC6>'||pg_header_NUMERIC6_tab(h)||'</NUMERIC6>';
                        v_tax_request_doc := v_tax_request_doc || '<NUMERIC7>'||pg_header_NUMERIC7_tab(h)||'</NUMERIC7>';
                        v_tax_request_doc := v_tax_request_doc || '<NUMERIC8>'||pg_header_NUMERIC8_tab(h)||'</NUMERIC8>';
                        v_tax_request_doc := v_tax_request_doc || '<NUMERIC9>'||pg_header_NUMERIC9_tab(h)||'</NUMERIC9>';
                        v_tax_request_doc := v_tax_request_doc || '<NUMERIC10>'||pg_header_NUMERIC10_tab(h)||'</NUMERIC10>';
                        -- dates
                        v_tax_request_doc := v_tax_request_doc || '<DATE1>'||to_char (pg_header_date1_tab(h), 'DD-MON-RR')||'</DATE1>';
                        v_tax_request_doc := v_tax_request_doc || '<DATE2>'||to_char (pg_header_date2_tab(h), 'DD-MON-RR')||'</DATE2>';
                        v_tax_request_doc := v_tax_request_doc || '<DATE3>'||to_char (pg_header_date3_tab(h), 'DD-MON-RR')||'</DATE3>';
                        v_tax_request_doc := v_tax_request_doc || '<DATE4>'||to_char (pg_header_date4_tab(h), 'DD-MON-RR')||'</DATE4>';
                        v_tax_request_doc := v_tax_request_doc || '<DATE5>'||to_char (pg_header_date5_tab(h), 'DD-MON-RR')||'</DATE5>';
                      v_tax_request_doc := v_tax_request_doc || '</HEADER_ATTRIBUTES>';
                  v_tax_request_doc := v_tax_request_doc || '</TRANSACTION_HEADER>';

   elsif p_mode = 'POST'
   then
        -- get total values.... getting from response, as trans has not committed yet
        --- so cannot get from core tabs
             select sum (TAX_AMOUNT)
             into  v_total_tax
             from
                            (
                                select EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/LINE_NUMBER') LINE_NUMBER ,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/TAX_AMOUNT') TAX_AMOUNT,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/TAX_DATE') TAX_DATE,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/UNROUNDED_TAX_AMOUNT') UNROUNDED_TAX_AMOUNT,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/TAX_CURR_TAX_AMOUNT') TAX_CURR_TAX_AMOUNT,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/TAX_RATE_PERCENTAGE') TAX_RATE_PERCENTAGE,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/TAXABLE_AMOUNT') TAXABLE_AMOUNT,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/EXEMPT_AMT') EXEMPT_AMT
                                FROM TABLE(XMLSEQUENCE(EXTRACT(XMLType(response_body), 'AVALARA_GET_TAX_RESPONSE/TAX_LINES/TAX_LINE'))) xml_list
                            ) xml_resp;

        p_log ('v_total_tax = '||v_total_tax);


        select nvl(sum (LINE_AMOUNT),0) into v_total_amt
        from apps.ZX_O2C_CALC_TXN_INPUT_V
        where TRANSACTION_ID= pg_trx_id_tab(h)
        and TRX_LEVEL_TYPE = 'LINE';
        
        if (v_total_amt = 0) 
        then
            select nvl(sum (EXTENDED_AMOUNT),0) into v_total_amt 
            from RA_CUSTOMER_TRX_LINES_all
            where CUSTOMER_TRX_ID=pg_trx_id_tab(h)
            and LINE_TYPE = 'LINE' ;
        end if;    

        p_log ('v_total_amt = '||v_total_amt);

/*        select nvl(sum (NET_EXTENDED_AMOUNT),0) into v_total_tax
        from apps.RA_CUSTOMER_TRX_LINES_V
        where CUSTOMER_TRX_ID= pg_trx_id_tab(h)
        and LINE_TYPE = 'TAX';

        p_log ('v_total_tax = '||v_total_tax);
*/
                      -- document_type
                      v_tax_request_doc := v_tax_request_doc || '<DOCUMENT_TYPE_ID>'||pg_doc_type_id_tab(h)||'</DOCUMENT_TYPE_ID>';
                      --TRANSACTION_NUMBER
                      -- replace with txn id
                      v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_NUMBER>'||pg_trx_id_tab(h)||'</TRANSACTION_NUMBER>';
                      --v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_NUMBER>'||pg_trx_number_tab(h)||'</TRANSACTION_NUMBER>';
                      -- transaction date
                      v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_DATE>'||to_char (pg_trx_date_tab(h), 'DD-MON-RR')||'</TRANSACTION_DATE>';
                      --TRANSACTION_NUMBER
                      v_tax_request_doc := v_tax_request_doc || '<TOTAL_AMOUNT>'||v_total_amt||'</TOTAL_AMOUNT>';
                      --TRANSACTION_NUMBER
                      v_tax_request_doc := v_tax_request_doc || '<TOTAL_TAX>'||v_total_tax||'</TOTAL_TAX>';

   elsif p_mode = 'VOID'
   then
                      -- document_type
                      v_tax_request_doc := v_tax_request_doc || '<DOCUMENT_TYPE_ID>'||pg_doc_type_id_tab(h)||'</DOCUMENT_TYPE_ID>';
                      --TRANSACTION_NUMBER
                      v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_NUMBER>'||pg_trx_id_tab(h)||'</TRANSACTION_NUMBER>';
   end if;

                  -- write XML to clob and reset v_tax_request_doc
                  -- get CLOB length
                  v_clob_length := dbms_lob.getlength (lob_loc => v_clob);
                  -- add string at the end of the CLOB
                  dbms_lob.write (lob_loc => v_clob,
                                  amount => length (v_tax_request_doc),
                                  offset => v_clob_length + 1,
                                  buffer => v_tax_request_doc);
                  -- reset string
                  v_tax_request_doc := '';

END build_xml_header;
--======================

--==========================
-- build xml lines msg
--=====================================
PROCEDURE build_xml_lines
IS
 v_segment1 VARCHAR2(40);
 v_attr_col2 VARCHAR2(40);
 v_attr_col2_val ra_customer_trx_lines_all.ATTRIBUTE1%TYPE;
 v_sql_stmt2 VARCHAR2(500);
 v_ava_cust_code VARCHAR2(150);
BEGIN
 v_segment1 := NULL;
                      -- init string
                      v_tax_request_doc := '';

                    --- start building XML msg on transaction lines
                      -- Line
                      v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_LINE>';

                          v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_LINE_ID>'||pg_trx_line_id_tab(l)||'</TRANSACTION_LINE_ID>';
                          v_tax_request_doc := v_tax_request_doc || '<TRX_LEVEL_TYPE>'||pg_trx_level_type_tab(l)||'</TRX_LEVEL_TYPE>';
                          v_tax_request_doc := v_tax_request_doc || '<LINE_LEVEL_ACTION>'||pg_line_level_action_tab(l)||'</LINE_LEVEL_ACTION>';
                          v_tax_request_doc := v_tax_request_doc || '<LINE_CLASS>'||pg_line_class_tab(l)||'</LINE_CLASS>';
                          v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_SHIPPING_DATE>'||to_char (pg_trx_shipping_date_tab(l),'DD-MON-RR')||'</TRANSACTION_SHIPPING_DATE>';
                          v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_RECEIPT_DATE>'||to_char (pg_trx_receipt_date_tab(l),'DD-MON-RR')||'</TRANSACTION_RECEIPT_DATE>';
                          v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_LINE_TYPE>'||pg_trx_line_type_tab(l)||'</TRANSACTION_LINE_TYPE>';
                          v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_LINE_DATE>'||to_char (pg_trx_line_date_tab(l),'DD-MON-RR')||'</TRANSACTION_LINE_DATE>';
                          v_tax_request_doc := v_tax_request_doc || '<TRX_LINE_NUMBER>'||pg_trx_line_number_tab(l)||'</TRX_LINE_NUMBER>';
                          v_tax_request_doc := v_tax_request_doc || '<TRX_LINE_DESCRIPTION>'||cl(pg_trx_line_desc_tab(l))||'</TRX_LINE_DESCRIPTION>';
                          v_tax_request_doc := v_tax_request_doc || '<PROVNL_TAX_DETERMINATION_DATE>'||NULL||'</PROVNL_TAX_DETERMINATION_DATE>';
                          v_tax_request_doc := v_tax_request_doc || '<TRX_BUSINESS_CATEGORY>'||cl(pg_trx_business_cat_tab(l))||'</TRX_BUSINESS_CATEGORY>';
                          v_tax_request_doc := v_tax_request_doc || '<LINE_INTENDED_USE>'||cl(pg_line_intended_use_tab(l))||'</LINE_INTENDED_USE>';
                          v_tax_request_doc := v_tax_request_doc || '<LINE_AMT_INCLUDES_TAX_FLAG>'||pg_line_amt_incl_tax_flag_tab(l)||'</LINE_AMT_INCLUDES_TAX_FLAG>';
                          v_tax_request_doc := v_tax_request_doc || '<LINE_AMOUNT>'||pg_line_amount_tab(l)||'</LINE_AMOUNT>';
                          v_tax_request_doc := v_tax_request_doc || '<OTHER_INCLUSIVE_TAX_AMOUNT>'||pg_other_incl_tax_amt_tab(l)||'</OTHER_INCLUSIVE_TAX_AMOUNT>';
                          v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_LINE_QUANTITY>'||pg_trx_line_qty_tab(l)||'</TRANSACTION_LINE_QUANTITY>';
                          v_tax_request_doc := v_tax_request_doc || '<UNIT_PRICE>'||pg_unit_price_tab(l)||'</UNIT_PRICE>';
                          v_tax_request_doc := v_tax_request_doc || '<CASH_DISCOUNT>'||pg_cash_discount_tab(l)||'</CASH_DISCOUNT>';
                          v_tax_request_doc := v_tax_request_doc || '<VOLUME_DISCOUNT>'||pg_volume_discount_tab(l)||'</VOLUME_DISCOUNT>';
                          v_tax_request_doc := v_tax_request_doc || '<TRADING_DISCOUNT>'||pg_trading_discount_tab(l)||'</TRADING_DISCOUNT>';
                          v_tax_request_doc := v_tax_request_doc || '<TRANSPORTATION_CHARGE>'||pg_trans_charge_tab(l)||'</TRANSPORTATION_CHARGE>';
                          v_tax_request_doc := v_tax_request_doc || '<INSURANCE_CHARGE>'||pg_ins_charge_tab(l)||'</INSURANCE_CHARGE>';
                          v_tax_request_doc := v_tax_request_doc || '<OTHER_CHARGE>'||pg_other_charge_tab(l)||'</OTHER_CHARGE>';

                          -- check and use Avalara Tax Category if found
                          if pg_prod_id_tab(l) is not null
                          then -- item used on line, check and assign Ava tax category
                            v_segment1 := pg_prod_code_tab(l); -- this is segment1 value from MSI
                              begin
							   pg_prod_code_tab(l) := NULL;
								   if l_document_type <> 'SALES_QUOTE' -- 10/23/13 added below to get tax code on so line item
								   then							   
										select mic.CATEGORY_CONCAT_SEGS into pg_prod_code_tab(l)
										from MTL_ITEM_CATEGORIES_V mic, zx_lines_det_factors zldf
										WHERE mic.inventory_item_id = zldf.PRODUCT_ID
										and mic.organization_id = zldf.PRODUCT_ORG_ID
										and mic.CATEGORY_SET_NAME = 'AVA_TAX_CODE'
										and zldf.TRX_LINE_ID= pg_trx_line_id_tab(l);
								   else -- sales order line
										select mic.CATEGORY_CONCAT_SEGS into pg_prod_code_tab(l)
										from MTL_ITEM_CATEGORIES_V mic, oe_order_lines_all zldf
										WHERE mic.inventory_item_id = zldf.inventory_item_id
										and mic.organization_id = zldf.SHIP_FROM_ORG_ID
										and mic.CATEGORY_SET_NAME = 'AVA_TAX_CODE'
										and zldf.LINE_ID= pg_trx_line_id_tab(l);
								   end if;							   
                                p_log ('Avalara Item Tax Code - '||pg_prod_code_tab(l));
                              exception
                                when others then
                                   pg_prod_code_tab(l) := NULL;
                              end;
                          else -- check for DFF value
                            -- get attribute column used for this DFF
                                  BEGIN
                                    SELECT APPLICATION_COLUMN_NAME
                                    INTO v_attr_col2
                                    FROM FND_DESCR_FLEX_COL_USAGE_VL
                                    WHERE --(APPLICATION_ID=222) and
                                    (DESCRIPTIVE_FLEXFIELD_NAME LIKE 'RA_CUSTOMER_TRX_LINES') and
                                    (DESCRIPTIVE_FLEX_CONTEXT_CODE='Global Data Elements')
                                    and upper(END_USER_COLUMN_NAME) = 'AVALARA TAX CODE';
                                  EXCEPTION WHEN OTHERS THEN
                                   v_attr_col2 := NULL;
                                   p_log ('Error selecting DFF column at line level - '||sqlerrm);
                                  END;
                             p_log ('v_attr_col2 = '||v_attr_col2);

                                if v_attr_col2 is not null -- get value of DFF
                                then
                                    v_sql_stmt2 := null;
                                     -- build sql stmt
                                     v_sql_stmt2 := 'select '||v_attr_col2||' from RA_CUSTOMER_TRX_LINES_ALL where CUSTOMER_TRX_LINE_ID = '||pg_trx_line_id_tab(l);
                                     --- update DFF attribute column with transaction id value
                                     p_log ('v_sql_stmt2 = '||v_sql_stmt2);
                                     EXECUTE IMMEDIATE v_sql_stmt2 INTO v_attr_col2_val;
                                     p_log ('v_attr_col2_val = '||v_attr_col2_val);
                                end if;
                                if v_attr_col2_val is not null ---assign DFF value to product code
                                then
                                  pg_prod_code_tab(l) := v_attr_col2_val;
                                end if;
                          end if;
                          --------------------------
                          v_tax_request_doc := v_tax_request_doc || '<PRODUCT_ID>'||cl(v_segment1)||'</PRODUCT_ID>';
                          v_tax_request_doc := v_tax_request_doc || '<UOM_CODE>'||pg_uom_code_tab(l)||'</UOM_CODE>';
                          v_tax_request_doc := v_tax_request_doc || '<PRODUCT_TYPE>'||cl(pg_prod_type_tab(l))||'</PRODUCT_TYPE>';
                          v_tax_request_doc := v_tax_request_doc || '<PRODUCT_CODE>'||cl(pg_prod_code_tab(l))||'</PRODUCT_CODE>';
                          ---------------------------
                          v_tax_request_doc := v_tax_request_doc || '<FOB_POINT>'||cl(pg_fob_point_tab(l))||'</FOB_POINT>';
                          v_tax_request_doc := v_tax_request_doc || '<ASSESSABLE_VALUE>'||pg_assess_value_tab(l)||'</ASSESSABLE_VALUE>';
                          v_tax_request_doc := v_tax_request_doc || '<PRODUCT_DESCRIPTION>'||cl(pg_prod_desc_tab(l))||'</PRODUCT_DESCRIPTION>';
                          v_tax_request_doc := v_tax_request_doc || '<ACCOUNT_CCID>'||cl(pg_account_ccid_tab(l))||'</ACCOUNT_CCID>';

                          -- check Exception populate reason and cert if null, as Avalara is using these fields
                          if nvl(pg_exempt_cont_flag_tab(l),'X') = 'E' -- Exempt
                          then
                             pg_exempt_certi_numb_tab(l)    := NVL(pg_exempt_certi_numb_tab(l),'0');
                             pg_exempt_reason_tab(l)        := NVL(pg_exempt_reason_tab(l),'Line is set as Exempt');
                          else
                            -- check if customer is exempt
                            begin
                                select 'E',
                                       nvl(ze.exempt_certificate_number,'0'),
                                       nvl(ze.exempt_reason_code,'Customer Exempt')||'.'||ze.exemption_type_code
                                into
                                        pg_exempt_cont_flag_tab(l),
                                        pg_exempt_certi_numb_tab(l),
                                        pg_exempt_reason_tab(l)
                                from
                                    apps.hz_parties hp,
                                    apps.HZ_PARTY_SITES hps,
                                    apps.hz_cust_acct_sites_all site,
                                    apps.HZ_CUST_SITE_USES su,
                                    apps.RA_CUSTOMER_TRX_all rct,
                                    apps.ZX_PARTY_TAX_PROFILE ZP,
                                    apps.zx_exemptions ze
                                where rct.CUSTOMER_TRX_ID = pg_trx_id_tab(h)
                                and rct.bill_to_site_use_id = su.site_use_id
                                and su.CUST_ACCT_SITE_ID = site.CUST_ACCT_SITE_ID
                                and site.PARTY_SITE_ID = hps.PARTY_SITE_ID
                                and hps.party_id = hp.party_id
                                and ZP.PARTY_TAX_PROFILE_ID = ze.PARTY_TAX_PROFILE_ID
                                and (HPS.PARTY_SITE_ID = ZP.PARTY_ID OR HP.PARTY_ID = ZP.PARTY_ID)
                                and sysdate between nvl(ze.EFFECTIVE_FROM,sysdate-1) and nvl(ze.EFFECTIVE_TO,sysdate+1);
                            exception
                             when others then
                                        pg_exempt_certi_numb_tab(l) := null;
                                        pg_exempt_reason_tab(l) := null;
                            end;
                          end if;
                          --------------------------

                          v_tax_request_doc := v_tax_request_doc || '<EXEMPT_CERTIFICATE_NUMBER>'||cl(pg_exempt_certi_numb_tab(l))||'</EXEMPT_CERTIFICATE_NUMBER>';
                          v_tax_request_doc := v_tax_request_doc || '<EXEMPT_REASON>'||cl(pg_exempt_reason_tab(l))||'</EXEMPT_REASON>';
                          v_tax_request_doc := v_tax_request_doc || '<EXEMPTION_CONTROL_FLAG>'||pg_exempt_cont_flag_tab(l)||'</EXEMPTION_CONTROL_FLAG>';


                              -- get bill_to location address
                              begin
                                select ADDRESS1, ADDRESS2, ADDRESS3, ADDRESS4, city, county, state, postal_code, country
                                into    pg_bill_to_grphy_value6_tab(l),
                                        pg_bill_to_grphy_value7_tab(l),
                                        pg_bill_to_grphy_value8_tab(l),
                                        pg_bill_to_grphy_value9_tab(l),
                                        pg_bill_to_grphy_value4_tab(l),
                                        pg_bill_to_grphy_value3_tab(l),
                                        pg_bill_to_grphy_value2_tab(l),
                                        pg_bill_to_grphy_value5_tab(l),
                                        pg_bill_to_grphy_value1_tab(l)
                                from apps.hz_locations
                                where location_id = pg_bill_to_loc_id_tab(l);
                              exception
                                 when others then
                                        pg_bill_to_grphy_value6_tab(l):= NULL;
                                        pg_bill_to_grphy_value7_tab(l):= NULL;
                                        pg_bill_to_grphy_value8_tab(l):= NULL;
                                        pg_bill_to_grphy_value9_tab(l):= NULL;
                                        pg_bill_to_grphy_value4_tab(l):= NULL;
                                        pg_bill_to_grphy_value3_tab(l):= NULL;
                                        pg_bill_to_grphy_value2_tab(l):= NULL;
                                        pg_bill_to_grphy_value5_tab(l):= NULL;
                                        pg_bill_to_grphy_value1_tab(l):= NULL;
                              end;

                              -- get ship_to location address
                              begin
                                select ADDRESS1, ADDRESS2, ADDRESS3, ADDRESS4, city, county, state, postal_code, country
                                into    pg_ship_to_grphy_value6_tab(l),
                                        pg_ship_to_grphy_value7_tab(l),
                                        pg_ship_to_grphy_value8_tab(l),
                                        pg_ship_to_grphy_value9_tab(l),
                                        pg_ship_to_grphy_value4_tab(l),
                                        pg_ship_to_grphy_value3_tab(l),
                                        pg_ship_to_grphy_value2_tab(l),
                                        pg_ship_to_grphy_value5_tab(l),
                                        pg_ship_to_grphy_value1_tab(l)
                                from apps.hz_locations
                                where location_id = pg_ship_to_loc_id_tab(l);
                              exception
                                 when others then
                                        pg_ship_to_grphy_value6_tab(l):= NULL;
                                        pg_ship_to_grphy_value7_tab(l):= NULL;
                                        pg_ship_to_grphy_value8_tab(l):= NULL;
                                        pg_ship_to_grphy_value9_tab(l):= NULL;
                                        pg_ship_to_grphy_value4_tab(l):= NULL;
                                        pg_ship_to_grphy_value3_tab(l):= NULL;
                                        pg_ship_to_grphy_value2_tab(l):= NULL;
                                        pg_ship_to_grphy_value5_tab(l):= NULL;
                                        pg_ship_to_grphy_value1_tab(l):= NULL;
                              end;

                          if l_document_type <> 'SALES_QUOTE'
                          then
                            -- get bill to address from line
                              begin
                                select hp.party_name,hca.account_number
                                --hp.PARTY_NUMBER
                                into pg_bill_to_pty_name_tab(l), pg_bill_to_pty_num_tab(l)
                                from
                                    apps.hz_parties hp,
                                    apps.hz_cust_accounts_all hca,
                                    apps.HZ_PARTY_SITES hps,
                                    apps.hz_cust_acct_sites_all site,
                                    apps.HZ_CUST_SITE_USES su,
                                    apps.zx_lines_det_factors zldf
                                where TRX_LINE_ID = pg_trx_line_id_tab(l)
                                and zldf.BILL_TO_CUST_ACCT_SITE_USE_ID = su.site_use_id
                                and su.CUST_ACCT_SITE_ID = site.CUST_ACCT_SITE_ID
                                and site.PARTY_SITE_ID = hps.PARTY_SITE_ID
                                and hca.party_id = hp.party_id
                                and hca.cust_account_id = site.cust_account_id      -- MBA added to get specific hca row
                                and hps.party_id = hp.party_id;
                              exception
                                 when others then
                                   pg_bill_to_pty_name_tab(l):= NULL;
                                   pg_bill_to_pty_num_tab(l) := NULL;
                              end;

                            -- get ship to address from line
                              begin
                                select hp.party_name, hca.account_number
                                --hp.PARTY_NUMBER
                                into pg_ship_to_pty_name_tab(l), pg_ship_to_pty_numr_tab(l)
                                from
                                    apps.hz_parties hp,
                                    apps.hz_cust_accounts_all hca,
                                    apps.HZ_PARTY_SITES hps,
                                    apps.hz_cust_acct_sites_all site,
                                    apps.HZ_CUST_SITE_USES su,
                                    apps.zx_lines_det_factors zldf
                                where TRX_LINE_ID = pg_trx_line_id_tab(l)
                                and zldf.SHIP_TO_CUST_ACCT_SITE_USE_ID = su.site_use_id
                                and su.CUST_ACCT_SITE_ID = site.CUST_ACCT_SITE_ID
                                and hca.party_id = hp.party_id
                                and hca.cust_account_id = site.cust_account_id      -- MBA added to get specific hca row
                                and site.PARTY_SITE_ID = hps.PARTY_SITE_ID
                                and hps.party_id = hp.party_id;
                              exception
                                 when others then
                                   pg_ship_to_pty_name_tab(l) := NULL;
                                   pg_ship_to_pty_numr_tab(l) := NULL;

                              end;

                            if pg_ship_to_pty_numr_tab(l) is NULL -- no ship to
                            then
                              -- use bill_to values
                                        pg_ship_to_pty_name_tab(l)           :=    pg_bill_to_pty_name_tab(l)  ;
                                        pg_ship_to_pty_numr_tab(l)           :=    pg_bill_to_pty_num_tab(l)   ;
                                        pg_ship_to_loc_id_tab(l)            :=     pg_bill_to_loc_id_tab(l);
                                        pg_ship_to_grphy_value6_tab(l)      :=     pg_bill_to_grphy_value6_tab(l) ;
                                        pg_ship_to_grphy_value7_tab(l)     :=      pg_bill_to_grphy_value7_tab(l);
                                        pg_ship_to_grphy_value8_tab(l)     :=      pg_bill_to_grphy_value8_tab(l) ;
                                        pg_ship_to_grphy_value9_tab(l)     :=      pg_bill_to_grphy_value9_tab(l) ;
                                        pg_ship_to_grphy_value4_tab(l)     :=      pg_bill_to_grphy_value4_tab(l) ;
                                        pg_ship_to_grphy_value3_tab(l)     :=      pg_bill_to_grphy_value3_tab(l) ;
                                        pg_ship_to_grphy_value2_tab(l)     :=      pg_bill_to_grphy_value2_tab(l) ;
                                        pg_ship_to_grphy_value5_tab(l)     :=      pg_bill_to_grphy_value5_tab(l) ;
                                        pg_ship_to_grphy_value1_tab(l)    :=       pg_bill_to_grphy_value1_tab(l);

                            end if;

                            -- set null tab values as its part of xml request msg currently

                            pg_bill_from_pty_num_tab(l):=NULL;
                            pg_bill_from_pty_name_tab(l):=NULL;
                            pg_bill_fr_grphy_value1_tab(l):=NULL;
                            pg_bill_fr_grphy_value2_tab(l):=NULL;
                            pg_bill_fr_grphy_value3_tab(l):=NULL;
                            pg_bill_fr_grphy_value4_tab(l):=NULL;
                            pg_bill_fr_grphy_value5_tab(l):=NULL;
                            pg_bill_fr_grphy_value6_tab(l):=NULL;
                            pg_bill_fr_grphy_value7_tab(l):=NULL;
                            pg_bill_fr_grphy_value8_tab(l):=NULL;
                            pg_bill_fr_grphy_value9_tab(l):=NULL;
                            pg_bill_fr_grphy_value10_tab(l):=NULL;

                                pg_poo_grphy_value1_tab(l):=NULL;
                                pg_poo_grphy_value2_tab(l):=NULL;
                                pg_poo_grphy_value3_tab(l):=NULL;
                                pg_poo_grphy_value4_tab(l):=NULL;
                                pg_poo_grphy_value5_tab(l):=NULL;
                                pg_poo_grphy_value6_tab(l):=NULL;
                                pg_poo_grphy_value7_tab(l):=NULL;
                                pg_poo_grphy_value8_tab(l):=NULL;
                                pg_poo_grphy_value9_tab(l):=NULL;
                                pg_poo_grphy_value10_tab(l):=NULL;

                                pg_poa_grphy_value1_tab(l):=NULL;
                                pg_poa_grphy_value2_tab(l):=NULL;
                                pg_poa_grphy_value3_tab(l):=NULL;
                                pg_poa_grphy_value4_tab(l):=NULL;
                                pg_poa_grphy_value5_tab(l):=NULL;
                                pg_poa_grphy_value6_tab(l):=NULL;
                                pg_poa_grphy_value7_tab(l):=NULL;
                                pg_poa_grphy_value8_tab(l):=NULL;
                                pg_poa_grphy_value9_tab(l):=NULL;
                                pg_poa_grphy_value10_tab(l):=NULL;

                          else -- its sales quote, added to get values from oe_lines
                            -- get bill to address from line
                              begin
                                select hp.party_name,hca.account_number
                                --hp.PARTY_NUMBER
                                into pg_bill_to_pty_name_tab(l), pg_bill_to_pty_num_tab(l)
                                from
                                    apps.hz_parties hp,
                                    apps.hz_cust_accounts_all hca,
                                    apps.HZ_PARTY_SITES hps,
                                    apps.hz_cust_acct_sites_all site,
                                    apps.HZ_CUST_SITE_USES su,
                                    apps.oe_order_lines_all oel
                                where oel.LINE_ID = pg_trx_line_id_tab(l)
                                and oel.INVOICE_TO_ORG_ID = su.site_use_id
                                and su.CUST_ACCT_SITE_ID = site.CUST_ACCT_SITE_ID
                                and site.PARTY_SITE_ID = hps.PARTY_SITE_ID
                                and hca.party_id = hp.party_id
                                and hca.cust_account_id = site.cust_account_id      -- MBA added to get specific hca row
                                and hps.party_id = hp.party_id;
                              exception
                                 when others then
                                   pg_bill_to_pty_name_tab(l):= NULL;
                                   pg_bill_to_pty_num_tab(l) := NULL;
                              end;

                            -- get ship to address from line
                              begin
                                select hp.party_name, hca.account_number
                                --hp.PARTY_NUMBER
                                into pg_ship_to_pty_name_tab(l), pg_ship_to_pty_numr_tab(l)
                                from
                                    apps.hz_parties hp,
                                    apps.hz_cust_accounts_all hca,
                                    apps.HZ_PARTY_SITES hps,
                                    apps.hz_cust_acct_sites_all site,
                                    apps.HZ_CUST_SITE_USES su,
                                    apps.oe_order_lines_all oel
                                where oel.LINE_ID = pg_trx_line_id_tab(l)
                                and oel.SHIP_TO_ORG_ID = su.site_use_id
                                and su.CUST_ACCT_SITE_ID = site.CUST_ACCT_SITE_ID
                                and hca.party_id = hp.party_id
                                and hca.cust_account_id = site.cust_account_id      -- MBA added to get specific hca row
                                and site.PARTY_SITE_ID = hps.PARTY_SITE_ID
                                and hps.party_id = hp.party_id;
                              exception
                                 when others then
                                   pg_ship_to_pty_name_tab(l) := NULL;
                                   pg_ship_to_pty_numr_tab(l) := NULL;

                              end;

                            if pg_ship_to_pty_numr_tab(l) is NULL -- no ship to
                            then
                              -- use bill_to values
                                        pg_ship_to_pty_name_tab(l)           :=    pg_bill_to_pty_name_tab(l)  ;
                                        pg_ship_to_pty_numr_tab(l)           :=    pg_bill_to_pty_num_tab(l)   ;
                                        pg_ship_to_loc_id_tab(l)            :=     pg_bill_to_loc_id_tab(l);
                                        pg_ship_to_grphy_value6_tab(l)      :=     pg_bill_to_grphy_value6_tab(l) ;
                                        pg_ship_to_grphy_value7_tab(l)     :=      pg_bill_to_grphy_value7_tab(l);
                                        pg_ship_to_grphy_value8_tab(l)     :=      pg_bill_to_grphy_value8_tab(l) ;
                                        pg_ship_to_grphy_value9_tab(l)     :=      pg_bill_to_grphy_value9_tab(l) ;
                                        pg_ship_to_grphy_value4_tab(l)     :=      pg_bill_to_grphy_value4_tab(l) ;
                                        pg_ship_to_grphy_value3_tab(l)     :=      pg_bill_to_grphy_value3_tab(l) ;
                                        pg_ship_to_grphy_value2_tab(l)     :=      pg_bill_to_grphy_value2_tab(l) ;
                                        pg_ship_to_grphy_value5_tab(l)     :=      pg_bill_to_grphy_value5_tab(l) ;
                                        pg_ship_to_grphy_value1_tab(l)    :=       pg_bill_to_grphy_value1_tab(l);

                            end if;
                            

                          end if; -- SALES_QUOTE


                          -- addresses
                          v_tax_request_doc := v_tax_request_doc || '<SHIP_TO>';
                            v_tax_request_doc := v_tax_request_doc || '<PARTY_NUMBER>'||pg_ship_to_pty_numr_tab(l)||'</PARTY_NUMBER>';
                            v_tax_request_doc := v_tax_request_doc || '<PARTY_NAME>'||cl(pg_ship_to_pty_name_tab(l))||'</PARTY_NAME>';
                            v_tax_request_doc := v_tax_request_doc || '<LOC_ID>'||pg_ship_to_loc_id_tab(l)||'</LOC_ID>';
                            v_tax_request_doc := v_tax_request_doc || '<ADDRESS>';
                                v_tax_request_doc := v_tax_request_doc || '<COUNTRY>'||cl(pg_ship_to_grphy_value1_tab(l))||'</COUNTRY>';
                                v_tax_request_doc := v_tax_request_doc || '<STATE>'||cl(pg_ship_to_grphy_value2_tab(l))||'</STATE>';
                                v_tax_request_doc := v_tax_request_doc || '<COUNTY>'||cl(pg_ship_to_grphy_value3_tab(l))||'</COUNTY>';
                                v_tax_request_doc := v_tax_request_doc || '<CITY>'||cl(pg_ship_to_grphy_value4_tab(l))||'</CITY>';
                                v_tax_request_doc := v_tax_request_doc || '<POSTAL_CODE>'||cl(pg_ship_to_grphy_value5_tab(l))||'</POSTAL_CODE>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS1>'||cl(pg_ship_to_grphy_value6_tab(l))||'</ADDRESS1>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS2>'||cl(pg_ship_to_grphy_value7_tab(l))||'</ADDRESS2>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS3>'||cl(pg_ship_to_grphy_value8_tab(l))||'</ADDRESS3>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS4>'||cl(pg_ship_to_grphy_value9_tab(l))||'</ADDRESS4>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS5>'||NULL||'</ADDRESS5>';
                            v_tax_request_doc := v_tax_request_doc || '</ADDRESS>';
                          v_tax_request_doc := v_tax_request_doc || '</SHIP_TO>';


                          v_tax_request_doc := v_tax_request_doc || '<BILL_TO>';
                            v_tax_request_doc := v_tax_request_doc || '<PARTY_NUMBER>'||pg_bill_to_pty_num_tab(l)||'</PARTY_NUMBER>';
                            v_tax_request_doc := v_tax_request_doc || '<PARTY_NAME>'||cl(pg_bill_to_pty_name_tab(l))||'</PARTY_NAME>';
                            v_tax_request_doc := v_tax_request_doc || '<LOC_ID>'||pg_bill_to_loc_id_tab(l)||'</LOC_ID>';
                            v_tax_request_doc := v_tax_request_doc || '<ADDRESS>';
                                v_tax_request_doc := v_tax_request_doc || '<COUNTRY>'||cl(pg_bill_to_grphy_value1_tab(l))||'</COUNTRY>';
                                v_tax_request_doc := v_tax_request_doc || '<STATE>'||cl(pg_bill_to_grphy_value2_tab(l))||'</STATE>';
                                v_tax_request_doc := v_tax_request_doc || '<COUNTY>'||cl(pg_bill_to_grphy_value3_tab(l))||'</COUNTY>';
                                v_tax_request_doc := v_tax_request_doc || '<CITY>'||cl(pg_bill_to_grphy_value4_tab(l))||'</CITY>';
                                v_tax_request_doc := v_tax_request_doc || '<POSTAL_CODE>'||cl(pg_bill_to_grphy_value5_tab(l))||'</POSTAL_CODE>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS1>'||cl(pg_bill_to_grphy_value6_tab(l))||'</ADDRESS1>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS2>'||cl(pg_bill_to_grphy_value7_tab(l))||'</ADDRESS2>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS3>'||cl(pg_bill_to_grphy_value8_tab(l))||'</ADDRESS3>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS4>'||cl(pg_bill_to_grphy_value9_tab(l))||'</ADDRESS4>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS5>'||NULL||'</ADDRESS5>';
                            v_tax_request_doc := v_tax_request_doc || '</ADDRESS>';
                          v_tax_request_doc := v_tax_request_doc || '</BILL_TO>';


                      -- write XML to clob and reset v_tax_request_doc due to char limit
                      -- get CLOB length
                      v_clob_length := dbms_lob.getlength (lob_loc => v_clob);
                      -- add string at the end of the CLOB
                      dbms_lob.write (lob_loc => v_clob,
                                      amount => length (v_tax_request_doc),
                                      offset => v_clob_length + 1,
                                      buffer => v_tax_request_doc);
                      -- reset string
                      v_tax_request_doc := '';
                      -- continue with XML generation

                      ---
                      ---- defaulting ship from values for Mulesoft testing - remove later after testing
                      /*
                          pg_ship_from_pty_num_tab(l) := 1263;
                          pg_ship_from_pty_name_tab(l) := 'Victor Test Supplier';
                          pg_ship_fr_loc_id_tab(l) := 126;
                          pg_ship_fr_grphy_value1_tab(l) := 'United States';
                          pg_ship_fr_grphy_value2_tab(l) := 'CA';
                          pg_ship_fr_grphy_value3_tab(l) := 'Santa Clara';
                          pg_ship_fr_grphy_value4_tab(l) := 'San Jose';
                          pg_ship_fr_grphy_value5_tab(l) := '95135';
                          pg_ship_fr_grphy_value6_tab(l) := '102 Main Street';
                          pg_ship_fr_grphy_value7_tab(l) := null;
                          pg_ship_fr_grphy_value8_tab(l) := null;
                          pg_ship_fr_grphy_value9_tab(l) := null;
                          pg_ship_fr_grphy_value10_tab(l) := null;
                     */

                      ------------------------

                      -- get ship from info
                      begin
                        select warehouse_id into pg_ship_from_pty_num_tab(l)
                        from apps.RA_CUSTOMER_TRX_LINES_V
                        where CUSTOMER_TRX_line_ID=pg_trx_line_id_tab(l);
                      exception
                        when others then
                        p_log('others exp - whs '||sqlerrm);
                        pg_ship_from_pty_num_tab(l) := NULL;
                      end;


                      if pg_ship_from_pty_num_tab(l) is not null -- ship from whs
                      then
                         -- get whs location
                       begin
                        select LOCATION_ID, location_code||' - '||name,COUNTRY,REGION_2,REGION_1, TOWN_OR_CITY,POSTAL_CODE,
                         ADDRESS_LINE_1, ADDRESS_LINE_2, ADDRESS_LINE_3, null ADDRESS_LINE_4, null ADDRESS_LINE_5
                        into
                          pg_ship_fr_loc_id_tab(l) ,
                          pg_ship_from_pty_name_tab(l) ,
                          pg_ship_fr_grphy_value1_tab(l),
                          pg_ship_fr_grphy_value2_tab(l) ,
                          pg_ship_fr_grphy_value3_tab(l),
                          pg_ship_fr_grphy_value4_tab(l),
                          pg_ship_fr_grphy_value5_tab(l),
                          pg_ship_fr_grphy_value6_tab(l),
                          pg_ship_fr_grphy_value7_tab(l) ,
                          pg_ship_fr_grphy_value8_tab(l),
                          pg_ship_fr_grphy_value9_tab(l) ,
                          pg_ship_fr_grphy_value10_tab(l)
                        from apps.HR_ORGANIZATION_UNITS_V
                        where organization_id = pg_ship_from_pty_num_tab(l);
                       exception
                        when others then
                          pg_ship_fr_loc_id_tab(l) := NULL;
                          pg_ship_from_pty_name_tab(l) := NULL;
                          pg_ship_fr_grphy_value1_tab(l):= NULL;
                          pg_ship_fr_grphy_value2_tab(l):= NULL;
                          pg_ship_fr_grphy_value3_tab(l):= NULL;
                          pg_ship_fr_grphy_value4_tab(l):= NULL;
                          pg_ship_fr_grphy_value5_tab(l):= NULL;
                          pg_ship_fr_grphy_value6_tab(l):= NULL;
                          pg_ship_fr_grphy_value7_tab(l) := NULL;
                          pg_ship_fr_grphy_value8_tab(l):= NULL;
                          pg_ship_fr_grphy_value9_tab(l) := NULL;
                          pg_ship_fr_grphy_value10_tab(l):= NULL;
                       end;
                      else
                        -- use OU as ship from
                       begin
                        select LOCATION_ID, LOCATION_ID,location_code||' - '||name,COUNTRY,REGION_2,REGION_1, TOWN_OR_CITY,POSTAL_CODE,
                         ADDRESS_LINE_1, ADDRESS_LINE_2, ADDRESS_LINE_3, null ADDRESS_LINE_4, null ADDRESS_LINE_5
                        into
                          pg_ship_fr_loc_id_tab(l) , pg_ship_from_pty_num_tab(l),
                          pg_ship_from_pty_name_tab(l) ,
                          pg_ship_fr_grphy_value1_tab(l),
                          pg_ship_fr_grphy_value2_tab(l) ,
                          pg_ship_fr_grphy_value3_tab(l),
                          pg_ship_fr_grphy_value4_tab(l),
                          pg_ship_fr_grphy_value5_tab(l),
                          pg_ship_fr_grphy_value6_tab(l),
                          pg_ship_fr_grphy_value7_tab(l) ,
                          pg_ship_fr_grphy_value8_tab(l),
                          pg_ship_fr_grphy_value9_tab(l) ,
                          pg_ship_fr_grphy_value10_tab(l)
                        from apps.HR_ORGANIZATION_UNITS_V
                        where organization_id = pg_internal_org_id_tab(h);
                       exception
                        when others then
                          pg_ship_fr_loc_id_tab(l) := NULL;
                          pg_ship_from_pty_num_tab(l):= NULL;
                          pg_ship_from_pty_name_tab(l) := NULL;
                          pg_ship_fr_grphy_value1_tab(l):= NULL;
                          pg_ship_fr_grphy_value2_tab(l) := NULL;
                          pg_ship_fr_grphy_value3_tab(l):= NULL;
                          pg_ship_fr_grphy_value4_tab(l):= NULL;
                          pg_ship_fr_grphy_value5_tab(l):= NULL;
                          pg_ship_fr_grphy_value6_tab(l):= NULL;
                          pg_ship_fr_grphy_value7_tab(l) := NULL;
                          pg_ship_fr_grphy_value8_tab(l):= NULL;
                          pg_ship_fr_grphy_value9_tab(l) := NULL;
                          pg_ship_fr_grphy_value10_tab(l) := NULL;
                       end;
                      end if;

p_log ('pg_ship_fr_loc_id_tab(l) = '||pg_ship_fr_loc_id_tab(l));
p_log ('pg_ship_from_pty_num_tab(l) = '||pg_ship_from_pty_num_tab(l));



                          v_tax_request_doc := v_tax_request_doc || '<SHIP_FROM>';
                            v_tax_request_doc := v_tax_request_doc || '<PARTY_NUMBER>'||pg_ship_from_pty_num_tab(l)||'</PARTY_NUMBER>';
                            v_tax_request_doc := v_tax_request_doc || '<PARTY_NAME>'||cl(pg_ship_from_pty_name_tab(l))||'</PARTY_NAME>';
                            v_tax_request_doc := v_tax_request_doc || '<LOC_ID>'||pg_ship_fr_loc_id_tab(l)||'</LOC_ID>';
                            v_tax_request_doc := v_tax_request_doc || '<ADDRESS>';
                                v_tax_request_doc := v_tax_request_doc || '<COUNTRY>'||cl(pg_ship_fr_grphy_value1_tab(l))||'</COUNTRY>';
                                v_tax_request_doc := v_tax_request_doc || '<STATE>'||cl(pg_ship_fr_grphy_value2_tab(l))||'</STATE>';
                                v_tax_request_doc := v_tax_request_doc || '<COUNTY>'||cl(pg_ship_fr_grphy_value3_tab(l))||'</COUNTY>';
                                v_tax_request_doc := v_tax_request_doc || '<CITY>'||cl(pg_ship_fr_grphy_value4_tab(l))||'</CITY>';
                                v_tax_request_doc := v_tax_request_doc || '<POSTAL_CODE>'||cl(pg_ship_fr_grphy_value5_tab(l))||'</POSTAL_CODE>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS1>'||cl(pg_ship_fr_grphy_value6_tab(l))||'</ADDRESS1>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS2>'||cl(pg_ship_fr_grphy_value7_tab(l))||'</ADDRESS2>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS3>'||cl(pg_ship_fr_grphy_value8_tab(l))||'</ADDRESS3>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS4>'||cl(pg_ship_fr_grphy_value9_tab(l))||'</ADDRESS4>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS5>'||cl(pg_ship_fr_grphy_value10_tab(l))||'</ADDRESS5>';
                            v_tax_request_doc := v_tax_request_doc || '</ADDRESS>';
                          v_tax_request_doc := v_tax_request_doc || '</SHIP_FROM>';


                          v_tax_request_doc := v_tax_request_doc || '<BILL_FROM>';
                            v_tax_request_doc := v_tax_request_doc || '<PARTY_NUMBER>'||pg_bill_from_pty_num_tab(l)||'</PARTY_NUMBER>';
                            v_tax_request_doc := v_tax_request_doc || '<PARTY_NAME>'||cl(pg_bill_from_pty_name_tab(l))||'</PARTY_NAME>';
                            v_tax_request_doc := v_tax_request_doc || '<LOC_ID>'||pg_bill_fr_loc_id_tab(l)||'</LOC_ID>';
                            v_tax_request_doc := v_tax_request_doc || '<ADDRESS>';
                                v_tax_request_doc := v_tax_request_doc || '<COUNTRY>'||cl(pg_bill_fr_grphy_value1_tab(l))||'</COUNTRY>';
                                v_tax_request_doc := v_tax_request_doc || '<STATE>'||cl(pg_bill_fr_grphy_value2_tab(l))||'</STATE>';
                                v_tax_request_doc := v_tax_request_doc || '<COUNTY>'||cl(pg_bill_fr_grphy_value3_tab(l))||'</COUNTY>';
                                v_tax_request_doc := v_tax_request_doc || '<CITY>'||cl(pg_bill_fr_grphy_value4_tab(l))||'</CITY>';
                                v_tax_request_doc := v_tax_request_doc || '<POSTAL_CODE>'||cl(pg_bill_fr_grphy_value5_tab(l))||'</POSTAL_CODE>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS1>'||cl(pg_bill_fr_grphy_value6_tab(l))||'</ADDRESS1>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS2>'||cl(pg_bill_fr_grphy_value7_tab(l))||'</ADDRESS2>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS3>'||cl(pg_bill_fr_grphy_value8_tab(l))||'</ADDRESS3>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS4>'||cl(pg_bill_fr_grphy_value9_tab(l))||'</ADDRESS4>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS5>'||cl(pg_bill_fr_grphy_value10_tab(l))||'</ADDRESS5>';
                            v_tax_request_doc := v_tax_request_doc || '</ADDRESS>';
                          v_tax_request_doc := v_tax_request_doc || '</BILL_FROM>';


                          v_tax_request_doc := v_tax_request_doc || '<POO>';
                            v_tax_request_doc := v_tax_request_doc || '<LOC_ID>'||pg_poo_loc_id_tab(l)||'</LOC_ID>';
                            v_tax_request_doc := v_tax_request_doc || '<ADDRESS>';
                                v_tax_request_doc := v_tax_request_doc || '<COUNTRY>'||cl(pg_poo_grphy_value1_tab(l))||'</COUNTRY>';
                                v_tax_request_doc := v_tax_request_doc || '<STATE>'||cl(pg_poo_grphy_value2_tab(l))||'</STATE>';
                                v_tax_request_doc := v_tax_request_doc || '<COUNTY>'||cl(pg_poo_grphy_value3_tab(l))||'</COUNTY>';
                                v_tax_request_doc := v_tax_request_doc || '<CITY>'||cl(pg_poo_grphy_value4_tab(l))||'</CITY>';
                                v_tax_request_doc := v_tax_request_doc || '<POSTAL_CODE>'||cl(pg_poo_grphy_value5_tab(l))||'</POSTAL_CODE>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS1>'||cl(pg_poo_grphy_value6_tab(l))||'</ADDRESS1>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS2>'||cl(pg_poo_grphy_value7_tab(l))||'</ADDRESS2>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS3>'||cl(pg_poo_grphy_value8_tab(l))||'</ADDRESS3>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS4>'||cl(pg_poo_grphy_value9_tab(l))||'</ADDRESS4>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS5>'||cl(pg_poo_grphy_value10_tab(l))||'</ADDRESS5>';
                            v_tax_request_doc := v_tax_request_doc || '</ADDRESS>';
                          v_tax_request_doc := v_tax_request_doc || '</POO>';


                          v_tax_request_doc := v_tax_request_doc || '<POA>';
                            v_tax_request_doc := v_tax_request_doc || '<LOC_ID>'||pg_poa_loc_id_tab(l)||'</LOC_ID>';
                            v_tax_request_doc := v_tax_request_doc || '<ADDRESS>';
                                v_tax_request_doc := v_tax_request_doc || '<COUNTRY>'||cl(pg_poa_grphy_value1_tab(l))||'</COUNTRY>';
                                v_tax_request_doc := v_tax_request_doc || '<STATE>'||cl(pg_poa_grphy_value2_tab(l))||'</STATE>';
                                v_tax_request_doc := v_tax_request_doc || '<COUNTY>'||cl(pg_poa_grphy_value3_tab(l))||'</COUNTY>';
                                v_tax_request_doc := v_tax_request_doc || '<CITY>'||cl(pg_poa_grphy_value4_tab(l))||'</CITY>';
                                v_tax_request_doc := v_tax_request_doc || '<POSTAL_CODE>'||cl(pg_poa_grphy_value5_tab(l))||'</POSTAL_CODE>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS1>'||cl(pg_poa_grphy_value6_tab(l))||'</ADDRESS1>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS2>'||cl(pg_poa_grphy_value7_tab(l))||'</ADDRESS2>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS3>'||cl(pg_poa_grphy_value8_tab(l))||'</ADDRESS3>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS4>'||cl(pg_poa_grphy_value9_tab(l))||'</ADDRESS4>';
                                v_tax_request_doc := v_tax_request_doc || '<ADDRESS5>'||cl(pg_poa_grphy_value10_tab(l))||'</ADDRESS5>';
                            v_tax_request_doc := v_tax_request_doc || '</ADDRESS>';
                          v_tax_request_doc := v_tax_request_doc || '</POA>';


                      -- write XML to clob and reset v_tax_request_doc due to char limit
                      -- get CLOB length
                      v_clob_length := dbms_lob.getlength (lob_loc => v_clob);
                      -- add string at the end of the CLOB
                      dbms_lob.write (lob_loc => v_clob,
                                      amount => length (v_tax_request_doc),
                                      offset => v_clob_length + 1,
                                      buffer => v_tax_request_doc);
                      -- reset string
                      v_tax_request_doc := '';
                      -- continue with XML generation


                           v_tax_request_doc := v_tax_request_doc || '<APPLIED_FROM>';
                                v_tax_request_doc := v_tax_request_doc || '<DOCUMENT_TYPE_ID>'||NULL||'</DOCUMENT_TYPE_ID>';
                                v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_ID>'||pg_appl_from_trx_id_tab(l)||'</TRANSACTION_ID>';
                                v_tax_request_doc := v_tax_request_doc || '<LINE_ID>'||pg_appl_from_line_id_tab(l)||'</LINE_ID>';
                                v_tax_request_doc := v_tax_request_doc || '<TRX_LEVEL_TYPE>'||pg_appl_fr_trx_lev_type_tab(l)||'</TRX_LEVEL_TYPE>';
                                v_tax_request_doc := v_tax_request_doc || '<DOC_NUMBER>'||pg_appl_from_doc_num_tab(l)||'</DOC_NUMBER>';
                           v_tax_request_doc := v_tax_request_doc || '</APPLIED_FROM>';

                           v_tax_request_doc := v_tax_request_doc || '<ADJUSTED_DOC>';
                                v_tax_request_doc := v_tax_request_doc || '<DOCUMENT_TYPE_ID>'||NULL||'</DOCUMENT_TYPE_ID>';
                                v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_ID>'||pg_adj_doc_trx_id_tab(l)||'</TRANSACTION_ID>';
                                v_tax_request_doc := v_tax_request_doc || '<LINE_ID>'||pg_adj_doc_line_id_tab(l)||'</LINE_ID>';
                                v_tax_request_doc := v_tax_request_doc || '<TRX_LEVEL_TYPE>'||pg_adj_doc_trx_lev_type_tab(l)||'</TRX_LEVEL_TYPE>';
                                v_tax_request_doc := v_tax_request_doc || '<DOC_NUMBER>'||pg_adj_doc_number_tab(l)||'</DOC_NUMBER>';
                                v_tax_request_doc := v_tax_request_doc || '<DOC_DATE>'||to_char (pg_adj_doc_date_tab(l), 'DD-MON-RR')||'</DOC_DATE>';
                           v_tax_request_doc := v_tax_request_doc || '</ADJUSTED_DOC>';


                           v_tax_request_doc := v_tax_request_doc || '<LINE_ATTRIBUTES>';
                           
                               -- get AVALARA CUSTOMER CODE profile value needed for Customer Excemption
                               v_ava_cust_code := upper(rtrim(ltrim(get_profile ('AVALARA CUSTOMER CODE', NULL))));
                               p_log ('v_ava_cust_code = '||v_ava_cust_code);
                               ----
                               if v_ava_cust_code = 'BILLTO(NAME)'
                               then
                                 ----assign values to char tags
                                 pg_line_char1_tab(l) := pg_bill_to_pty_name_tab(l);
                                 pg_line_char2_tab(l) := pg_ship_to_pty_name_tab(l);
                                 -----
                               elsif  v_ava_cust_code = 'BILLTO(NAME-NUMBER)'
                               then
                                 ----assign values to char tags
                                 pg_line_char1_tab(l) := pg_bill_to_pty_name_tab(l)||'-'||pg_bill_to_pty_num_tab(l);
                                 pg_line_char2_tab(l) := pg_ship_to_pty_name_tab(l)||'-'||pg_ship_to_pty_numr_tab(l);
                                 -----
                               elsif  v_ava_cust_code = 'BILLTO(NUMBER)'
                               then
                                 ----assign values to char tags
                                 pg_line_char1_tab(l) := pg_bill_to_pty_num_tab(l);
                                 pg_line_char2_tab(l) := pg_ship_to_pty_numr_tab(l);
                                 -----
                               elsif v_ava_cust_code = 'SHIPTO(NAME)'
                               then
                                 ----assign values to char tags
                                 pg_line_char2_tab(l) := pg_bill_to_pty_name_tab(l);
                                 pg_line_char1_tab(l) := pg_ship_to_pty_name_tab(l);
                                 -----
                               elsif  v_ava_cust_code = 'SHIPTO(NAME-NUMBER)'
                               then
                                 ----assign values to char tags
                                 pg_line_char2_tab(l) := pg_bill_to_pty_name_tab(l)||'-'||pg_bill_to_pty_num_tab(l);
                                 pg_line_char1_tab(l) := pg_ship_to_pty_name_tab(l)||'-'||pg_ship_to_pty_numr_tab(l);
                                 -----
                               elsif  v_ava_cust_code = 'SHIPTO(NUMBER)'
                               then
                                 ----assign values to char tags
                                 pg_line_char2_tab(l) := pg_bill_to_pty_num_tab(l);
                                 pg_line_char1_tab(l) := pg_ship_to_pty_numr_tab(l);
                                 -----
                               end if;
                               p_log ('pg_line_char1_tab(l) = '||pg_line_char1_tab(l));  
                               p_log ('pg_line_char2_tab(l) = '||pg_line_char2_tab(l));  
                           
                               -- chars
							   --- restricting CustomerCode to 50 chars
                                v_tax_request_doc := v_tax_request_doc || '<CHAR1>'||cl(substr(pg_line_char1_tab(l),1,50))||'</CHAR1>';
                                v_tax_request_doc := v_tax_request_doc || '<CHAR2>'||cl(substr(pg_line_char2_tab(l),1,50))||'</CHAR2>';
							   ---
                                v_tax_request_doc := v_tax_request_doc || '<CHAR3>'||cl(pg_line_char3_tab(l))||'</CHAR3>';
                                v_tax_request_doc := v_tax_request_doc || '<CHAR4>'||cl(pg_line_char4_tab(l))||'</CHAR4>';
                                v_tax_request_doc := v_tax_request_doc || '<CHAR5>'||cl(pg_line_char5_tab(l))||'</CHAR5>';
                                v_tax_request_doc := v_tax_request_doc || '<CHAR6>'||cl(pg_line_char6_tab(l))||'</CHAR6>';
                                v_tax_request_doc := v_tax_request_doc || '<CHAR7>'||cl(pg_line_char7_tab(l))||'</CHAR7>';
                                v_tax_request_doc := v_tax_request_doc || '<CHAR8>'||cl(pg_line_char8_tab(l))||'</CHAR8>';
                                v_tax_request_doc := v_tax_request_doc || '<CHAR9>'||cl(pg_line_char9_tab(l))||'</CHAR9>';
                                v_tax_request_doc := v_tax_request_doc || '<CHAR10>'||cl(pg_line_char10_tab(l))||'</CHAR10>';

                               --numbers
                                v_tax_request_doc := v_tax_request_doc || '<NUMERIC1>'||pg_line_NUMERIC1_tab(l)||'</NUMERIC1>';
                                v_tax_request_doc := v_tax_request_doc || '<NUMERIC2>'||pg_line_NUMERIC2_tab(l)||'</NUMERIC2>';
                                v_tax_request_doc := v_tax_request_doc || '<NUMERIC3>'||pg_line_NUMERIC3_tab(l)||'</NUMERIC3>';
                                v_tax_request_doc := v_tax_request_doc || '<NUMERIC4>'||pg_line_NUMERIC4_tab(l)||'</NUMERIC4>';
                                v_tax_request_doc := v_tax_request_doc || '<NUMERIC5>'||pg_line_NUMERIC5_tab(l)||'</NUMERIC5>';
                                v_tax_request_doc := v_tax_request_doc || '<NUMERIC6>'||pg_line_NUMERIC6_tab(l)||'</NUMERIC6>';
                                v_tax_request_doc := v_tax_request_doc || '<NUMERIC7>'||pg_line_NUMERIC7_tab(l)||'</NUMERIC7>';
                                v_tax_request_doc := v_tax_request_doc || '<NUMERIC8>'||pg_line_NUMERIC8_tab(l)||'</NUMERIC8>';
                                v_tax_request_doc := v_tax_request_doc || '<NUMERIC9>'||pg_line_NUMERIC9_tab(l)||'</NUMERIC9>';
                                v_tax_request_doc := v_tax_request_doc || '<NUMERIC10>'||pg_line_NUMERIC10_tab(l)||'</NUMERIC10>';
                                -- dates
                                v_tax_request_doc := v_tax_request_doc || '<DATE1>'||to_char (pg_line_date1_tab(l), 'DD-MON-RR')||'</DATE1>';
                                v_tax_request_doc := v_tax_request_doc || '<DATE2>'||to_char (pg_line_date2_tab(l), 'DD-MON-RR')||'</DATE2>';
                                v_tax_request_doc := v_tax_request_doc || '<DATE3>'||to_char (pg_line_date3_tab(l), 'DD-MON-RR')||'</DATE3>';
                                v_tax_request_doc := v_tax_request_doc || '<DATE4>'||to_char (pg_line_date4_tab(l), 'DD-MON-RR')||'</DATE4>';
                                v_tax_request_doc := v_tax_request_doc || '<DATE5>'||to_char (pg_line_date5_tab(l), 'DD-MON-RR')||'</DATE5>';
                           v_tax_request_doc := v_tax_request_doc || '</LINE_ATTRIBUTES>';

                      v_tax_request_doc := v_tax_request_doc || '</TRANSACTION_LINE>';

                      -- End of XML, write to clob
                      -- get CLOB length
                      v_clob_length := dbms_lob.getlength (lob_loc => v_clob);
                      -- add string at the end of the CLOB
                      dbms_lob.write (lob_loc => v_clob,
                                      amount => length (v_tax_request_doc),
                                      offset => v_clob_length + 1,
                                      buffer => v_tax_request_doc);
                      -- reset string
                      v_tax_request_doc := '';

END build_xml_lines;

--==========================
-- build xml lines tag (start, end)
--=====================================
PROCEDURE build_xml_lines_tag (p_tag IN VARCHAR2)
IS
BEGIN
                      -- init string
                      v_tax_request_doc := '';

   if p_tag = 'START'
   then
                  v_tax_request_doc := v_tax_request_doc || '<TRANSACTION_LINES>';

   elsif p_tag = 'END'
   THEN
                  v_tax_request_doc := v_tax_request_doc || '</TRANSACTION_LINES>';
   end if;

                      -- End of XML, write to clob
                      -- get CLOB length
                      v_clob_length := dbms_lob.getlength (lob_loc => v_clob);
                      -- add string at the end of the CLOB
                      dbms_lob.write (lob_loc => v_clob,
                                      amount => length (v_tax_request_doc),
                                      offset => v_clob_length + 1,
                                      buffer => v_tax_request_doc);
                      -- reset string
                      v_tax_request_doc := '';

END build_xml_lines_tag;
---=======================
PROCEDURE TAX_RESULTS_PROCESSING(
    p_tax_lines_tbl IN OUT NOCOPY apps.ZX_TAX_PARTNER_PKG.tax_lines_tbl_type,
    p_currency_tab  IN OUT NOCOPY apps.ZX_TAX_PARTNER_PKG.tax_currencies_tbl_type,
    x_return_status    OUT NOCOPY VARCHAR2)
IS

  l_situs                 VARCHAR2(20);

  l_api_name           CONSTANT VARCHAR2(30) := 'TAX_RESULTS_PROCESSING';
  l_return_status         VARCHAR2(30);
  l_xml_source      XMLType;

Begin
  x_return_status := FND_API.G_RET_STS_SUCCESS;

 P_LOG ('BEGIN - '||G_PKG_NAME||': '||l_api_name||'(+)');

    p_currency_tab(1).tax_currency_precision      := 2;
    l_situs := 'SHIP_TO';
    l_regime_code      := zx_tax_partner_pkg.g_tax_regime_code;
    l_xml_source :=  XMLType(response_body);

                           begin
                            select zldf.transaction_line_id,
                                zldf.trx_level_type,
                                --zldf.TRX_LINE_NUMBER,
                                xml_resp.TAX_AMOUNT,
                                to_date(xml_resp.TAX_DATE,'DD-MON-RRRR') TAX_DATE,
                                xml_resp.UNROUNDED_TAX_AMOUNT,
                                xml_resp.TAX_CURR_TAX_AMOUNT,
                                xml_resp.TAX_RATE_PERCENTAGE,
                                xml_resp.TAXABLE_AMOUNT,
                                xml_resp.EXEMPT_AMT,
                                hl.state, hl.county, hl.city, zt.tax
                            bulk collect into
                                pg_resp_trx_line_id_tab,
                                pg_resp_trx_level_type_tab,
                                pg_resp_tax_amt,
                                pg_resp_TAX_DATE,
                                pg_resp_unround_tax_amt,
                                pg_resp_curr_tax_amt,
                                pg_resp_tax_rate_percentage,
                                pg_resp_taxable_amount,
                                pg_resp_exempt_amt,
                                pg_resp_state,
                                pg_resp_county,
                                pg_resp_city,
                                pg_resp_tax
                            from apps.ZX_O2C_CALC_TXN_INPUT_V zldf, apps.hz_locations hl, apps.ZX_TAXES_B zt,
                            (
                                select EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/LINE_NUMBER') LINE_NUMBER ,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/TRANSACTION_LINE_ID') TRANSACTION_LINE_ID,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/TAX_AMOUNT') TAX_AMOUNT,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/TAX_DATE') TAX_DATE,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/UNROUNDED_TAX_AMOUNT') UNROUNDED_TAX_AMOUNT,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/TAX_CURR_TAX_AMOUNT') TAX_CURR_TAX_AMOUNT,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/TAX_RATE_PERCENTAGE') TAX_RATE_PERCENTAGE,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/TAXABLE_AMOUNT') TAXABLE_AMOUNT,
                                          EXTRACTVALUE(VALUE(xml_list),'TAX_LINE/EXEMPT_AMT') EXEMPT_AMT
                                FROM TABLE(XMLSEQUENCE(EXTRACT(l_xml_source, 'AVALARA_GET_TAX_RESPONSE/TAX_LINES/TAX_LINE'))) xml_list
                            ) xml_resp
                            where zldf.transaction_id = pg_trx_id_tab(h)
                            and xml_resp.TRANSACTION_LINE_ID = zldf.TRANSACTION_LINE_ID
                            and NVL(zldf.SHIP_TO_LOC_ID,zldf.BILL_TO_LOC_ID) = hl.LOCATION_ID
                            and zt.TAX_REGIME_CODE = l_regime_code;
                          exception
                           when others then
                             x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
                             g_string :='Exception others Error on Response bulk collect for Transaction id -'|| pg_trx_id_tab(h);
                             P_LOG (g_string);
                             P_LOG (  'Error -'|| sqlerrm);
                             return;
                          end;

                          p_log ('pg_resp_trx_line_id_tab count = ' ||pg_resp_trx_line_id_tab.count);

                            IF nvl(pg_resp_trx_line_id_tab.count,0) = 0
                            Then
                                x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
                                g_string := 'No Response lines exist for Transaction id -'|| pg_trx_id_tab(h);
                                P_LOG (g_string);
                                return;
                            ELSE -- returned rows that can be processed below
                               -- loop through trans lines
                               I := 0;
                              For resp in 1..nvl(pg_resp_trx_line_id_tab.last, 0)
                              loop
                                   I := resp;

                                      --========
                                     P_LOG ('Displaying for the response transaction line : '||i);
                                    --===============
                                                          --- global attrs
                                                          pg_resp_ga_category(i)                := 'AVALARA';
                                                          pg_resp_ga2(i)                        := NULL;
                                                          pg_resp_ga4(i)                        := NULL;
                                                          pg_resp_ga6(i)                        := NULL;

                                                          --exempt
                                                          pg_resp_exempt_reason(i)              := NULL;
                                                          pg_resp_exempt_rate_modifier(i)       := NULL;
                                                          pg_resp_exempt_certificate_num(i)     := NULL;


                                            p_tax_lines_tbl.document_type_id(i)           := pg_doc_type_id_tab(h);
                                            p_tax_lines_tbl.transaction_id(i)             := pg_trx_id_tab(h);
                                            p_tax_lines_tbl.transaction_line_id(i)        := pg_resp_trx_line_id_tab(i);
                                            p_tax_lines_tbl.trx_level_type(i)             := pg_resp_trx_level_type_tab(i);
                                            p_tax_lines_tbl.country_code(i)               := l_regime_code ;
                                            p_tax_lines_tbl.situs(i)                      := l_situs;
                                            p_tax_lines_tbl.tax_currency_code(i)          := pg_trx_curr_code_tab(h);
                                            p_tax_lines_tbl.Inclusive_tax_line_flag(i)    := 'N';
                                            p_tax_lines_tbl.Line_amt_includes_tax_flag(i) := 'N';
                                            p_tax_lines_tbl.use_tax_flag(i)               := 'N';
                                            p_tax_lines_tbl.User_override_flag(i)         := 'N';
                                            p_tax_lines_tbl.last_manual_entry(i)          := NULL;
                                            p_tax_lines_tbl.manually_entered_flag(i)      := 'N';
                                            p_tax_lines_tbl.registration_party_type(i)    := NULL;
                                            p_tax_lines_tbl.party_tax_reg_number(i)       := NULL;
                                            p_tax_lines_tbl.third_party_tax_reg_number(i) := NULL;
                                            p_tax_lines_tbl.threshold_indicator_flag(i)   := Null;
                                            p_tax_lines_tbl.State(i)                      := pg_resp_state (i);
                                            p_tax_lines_tbl.County(i)                     := pg_resp_county(i);
                                            p_tax_lines_tbl.City(i)                       := pg_resp_city(i);
                                            p_tax_lines_tbl.tax_only_line_flag(i)         := 'Y';
                                            p_tax_lines_tbl.Tax(i)                        := pg_resp_tax(i);
                                            p_tax_lines_tbl.tax_amount(i)                 := pg_resp_tax_amt(i);
                                            p_tax_lines_tbl.unrounded_tax_amount(i)       := pg_resp_unround_tax_amt(i);
                                            p_tax_lines_tbl.tax_curr_tax_amount(i)       := pg_resp_curr_tax_amt(i);
                                            p_tax_lines_tbl.tax_rate_percentage(i)       := pg_resp_tax_rate_percentage(i);
                                            p_tax_lines_tbl.taxable_amount(i)              := pg_resp_taxable_amount(i);
                                            p_tax_lines_tbl.tax_jurisdiction(i) := NULL;

                                            p_tax_lines_tbl.global_attribute_category(i) := pg_resp_ga_category(i);
                                            p_tax_lines_tbl.global_attribute2(i) := pg_resp_ga2(i);
                                            p_tax_lines_tbl.global_attribute4(i) := pg_resp_ga4(i);
                                            p_tax_lines_tbl.global_attribute6(i) := pg_resp_ga6(i) ;


                                            p_tax_lines_tbl.exempt_reason(i) :=pg_resp_exempt_reason(i);

                                            p_tax_lines_tbl.exempt_rate_modifier(i) := pg_resp_exempt_rate_modifier(i);
                                            p_tax_lines_tbl.exempt_certificate_number(i) := pg_resp_exempt_certificate_num(i);



                                         P_LOG ('tax line output ');


                                               P_LOG ('p_tax_lines_tbl.document_type_id('||i||') = '|| to_char(p_tax_lines_tbl.document_type_id(i)));
                                               P_LOG ('p_tax_lines_tbl.transaction_id('||i||') = '|| to_char(p_tax_lines_tbl.transaction_id(i)));
                                               P_LOG ('p_tax_lines_tbl.transaction_line_id('||i||') = '||
                                                    to_char(p_tax_lines_tbl.transaction_line_id(i)));
                                               P_LOG ('p_tax_lines_tbl.trx_level_type('||i||') = '||
                                                    p_tax_lines_tbl.trx_level_type(i));
                                               P_LOG ('p_tax_lines_tbl.country_code('||i||') = '|| p_tax_lines_tbl.country_code(i));
                                               P_LOG ('p_tax_lines_tbl.Tax('||i||') = '|| p_tax_lines_tbl.Tax(i));
                                               P_LOG ('p_tax_lines_tbl.situs('||i||') = '|| p_tax_lines_tbl.situs(i));
                                               P_LOG (' p_tax_lines_tbl.tax_jurisdiction('||i||') = '||
                                        p_tax_lines_tbl.tax_jurisdiction(i));
                                               P_LOG ('p_tax_lines_tbl.tax_currency_code('||i||') = '|| p_tax_lines_tbl.tax_currency_code(i));
                                               P_LOG (' p_tax_lines_tbl.TAX_CURR_TAX_AMOUNT('||i||')  = '||
                                        to_char(p_tax_lines_tbl.TAX_CURR_TAX_AMOUNT(i)));
                                               P_LOG (' p_tax_lines_tbl.tax_amount('||i||') = '|| to_char(p_tax_lines_tbl.tax_amount(i)));
                                               P_LOG (' p_tax_lines_tbl.tax_rate_percentage('||i||') = '||
                                        to_char(p_tax_lines_tbl.tax_rate_percentage(i)));
                                               P_LOG (' p_tax_lines_tbl.taxable_amount('||i||') = '||
                                        to_char(p_tax_lines_tbl.taxable_amount(i)));
                                               P_LOG ('p_tax_lines_tbl.State('||i||') = '|| p_tax_lines_tbl.State(i));
                                               P_LOG ('p_tax_lines_tbl.County('||i||') = '|| p_tax_lines_tbl.County(i));
                                               P_LOG ('p_tax_lines_tbl.City('||i||') = '|| p_tax_lines_tbl.City(i));
                                               P_LOG (' p_tax_lines_tbl.unrounded_tax_amount('||i||') = '||
                                        to_char(p_tax_lines_tbl.unrounded_tax_amount(i)));
                                               P_LOG (' p_tax_lines_tbl.exempt_certificate_number('||i||') = '||
                                                    p_tax_lines_tbl.exempt_certificate_number(i));

                                               P_LOG ('p_tax_lines_tbl.global_attribute_category('||i||') = '|| p_tax_lines_tbl.global_attribute_category(i));
                                               P_LOG ('p_tax_lines_tbl.global_attribute2('||i||') = '|| p_tax_lines_tbl.global_attribute2(i));
                                               P_LOG ('p_tax_lines_tbl.global_attribute4('||i||') = '|| p_tax_lines_tbl.global_attribute4(i));
                                               P_LOG ('p_tax_lines_tbl.global_attribute6('||i||') = '|| p_tax_lines_tbl.global_attribute6(i));


                                            --- for XML structure, save line tab in temp table for analysis
                                            --- can be removed later on
                                          begin
                                            insert into AVALARA.AVLR_TMP_TAX_LINES_TBL
                                            (
                                            document_type_id,
                                            transaction_id,
                                            transaction_line_id,
                                            trx_level_type,
                                            country_code,
                                            situs,
                                            tax_currency_code,
                                            Inclusive_tax_line_flag,
                                            Line_amt_includes_tax_flag,
                                            use_tax_flag,
                                            User_override_flag,
                                            manually_entered_flag,
                                            State,
                                            County,
                                            City,
                                            tax_only_line_flag,
                                            Tax,
                                            tax_amount,
                                            unrounded_tax_amount,
                                            tax_curr_tax_amount,
                                            tax_rate_percentage,
                                            taxable_amount,
                                            global_attribute_category,
                                            global_attribute2,
                                            global_attribute4,
                                            global_attribute6,
                                            exempt_reason,
                                            exempt_rate_modifier,
                                            exempt_certificate_number
                                            )
                                            values
                                            (
                                            p_tax_lines_tbl.document_type_id(i),
                                            p_tax_lines_tbl.transaction_id(i),
                                            p_tax_lines_tbl.transaction_line_id(i),
                                            p_tax_lines_tbl.trx_level_type(i),
                                            p_tax_lines_tbl.country_code(i),
                                            p_tax_lines_tbl.situs(i),
                                            p_tax_lines_tbl.tax_currency_code(i),
                                            p_tax_lines_tbl.Inclusive_tax_line_flag(i),
                                            p_tax_lines_tbl.Line_amt_includes_tax_flag(i),
                                            p_tax_lines_tbl.use_tax_flag(i),
                                            p_tax_lines_tbl.User_override_flag(i),
                                            p_tax_lines_tbl.manually_entered_flag(i),
                                            p_tax_lines_tbl.State(i),
                                            p_tax_lines_tbl.County(i),
                                            p_tax_lines_tbl.City(i),
                                            p_tax_lines_tbl.tax_only_line_flag(i),
                                            p_tax_lines_tbl.Tax(i),
                                            p_tax_lines_tbl.tax_amount(i),
                                            p_tax_lines_tbl.unrounded_tax_amount(i),
                                            p_tax_lines_tbl.tax_curr_tax_amount(i),
                                            p_tax_lines_tbl.tax_rate_percentage(i),
                                            p_tax_lines_tbl.taxable_amount(i),
                                            p_tax_lines_tbl.global_attribute_category(i),
                                            p_tax_lines_tbl.global_attribute2(i),
                                            p_tax_lines_tbl.global_attribute4(i),
                                            p_tax_lines_tbl.global_attribute6(i),
                                            p_tax_lines_tbl.exempt_reason(i),
                                            p_tax_lines_tbl.exempt_rate_modifier(i),
                                            p_tax_lines_tbl.exempt_certificate_number(i)
                                            );
                                          exception when others then
                                              P_LOG (' Error inserting tt_tmp_tax_lines_tbl - '|| sqlerrm);
                                          end;
                                            ------------
                                            ------------
                              end loop;
                            END IF; -- pg_resp_trx_line_id_tab.count
      --========
     P_LOG ('.END '||G_PKG_NAME||': '||l_api_name||'(-)');
    --===============

exception when others then

 --========
 P_LOG (G_PKG_NAME||': '||l_api_name||' others Error = '|| sqlerrm);
 --===============

  x_return_status :=FND_API.G_RET_STS_UNEXP_ERROR;

END TAX_RESULTS_PROCESSING;
--======================
PROCEDURE ERROR_EXCEPTION_HANDLE(str  VARCHAR2) is

CURSOR error_exception_cursor IS
SELECT  EVNT_CLS_MAPPING_ID,
  TRX_ID,
  TAX_REGIME_CODE
FROM    apps.ZX_TRX_PRE_PROC_OPTIONS_GT;

BEGIN
   IF (g_docment_type_id is null) THEN
      OPEN  error_exception_cursor;
      FETCH error_exception_cursor
       INTO g_docment_type_id,
            g_trasaction_id,
            g_tax_regime_code;
      CLOSE error_exception_cursor;
   END IF;

   err_count := nvl(err_count,0)+1;
   G_MESSAGES_TBL.DOCUMENT_TYPE_ID(err_count)     := g_docment_type_id;
   G_MESSAGES_TBL.TRANSACTION_ID(err_count)       := g_trasaction_id;
   G_MESSAGES_TBL.COUNTRY_CODE(err_count)         := g_tax_regime_code;
   G_MESSAGES_TBL.TRANSACTION_LINE_ID(err_count)  := g_transaction_line_id;
   G_MESSAGES_TBL.TRX_LEVEL_TYPE(err_count)       := g_trx_level_type;
   G_MESSAGES_TBL.ERROR_MESSAGE_TYPE(err_count)   := 'ERROR';
   G_MESSAGES_TBL.ERROR_MESSAGE_STRING(err_count) := str;

END ERROR_EXCEPTION_HANDLE;

-----
    PROCEDURE P_LOG
( p_text    IN VARCHAR2 )
-- =====================================================================
-- DESCRIPTION   : log message in log table
--
-- PARAMETERS:
--   p_text    (in)     data to be written to log
-- =====================================================================
IS
  l_out_msg   VARCHAR2(1500);

BEGIN
-- IF g_debug = 'Y'
-- THEN
 IF LENGTH(p_text) > 0
 THEN
   l_out_msg  := SUBSTR(p_text,1,1450);
      --- log message in log table
      AVALARA.AVLR_WRITE_PKG_LOG (G_MODULE_NAME||'-'||l_out_msg);
      ------------
 END IF;
-- END IF;
END P_LOG;
-----------------------
-----
    PROCEDURE TEST_CONNECTION ( errbuf    OUT NOCOPY   VARCHAR2,
                                retcode OUT NOCOPY   VARCHAR2 )
-- =====================================================================
-- DESCRIPTION   : Test Avalara-Mulesoft URL connection
--
-- PARAMETERS:
--  std oracle concurrent program params
-- =====================================================================
IS
  v_errbuf VARCHAR2(1) := FND_API.G_RET_STS_SUCCESS;
  v_retcode VARCHAR2(5) := '0';

  l_api_name       CONSTANT VARCHAR2(30) := 'test_connection';
------
BEGIN
 P_LOG ('BEGIN - ' ||G_PKG_NAME||': '||l_api_name||'(+)');
                          --submit xml for ping request
                            xml_request_response  ( 'PING','PING',v_errbuf );

                            fnd_file.put_line(fnd_file.LOG,'v_errbuf = '||v_errbuf);
                            fnd_file.put_line(fnd_file.OUTPUT,'v_errbuf = '||v_errbuf);
                            p_log ('v_errbuf = '||v_errbuf);

                             IF v_errbuf <> FND_API.G_RET_STS_SUCCESS THEN
                                 if v_clob_created then
                                    dbms_lob.freetemporary (lob_loc => v_clob);
                                    v_clob_created := false;
                                 end if;
                                    v_errbuf := FND_API.G_RET_STS_ERROR;
                                    v_retcode := '-1';
                                    g_string := g_string ||'-'||'Failed to make connection to Avalara';
                                fnd_file.put_line(fnd_file.LOG,g_string);
                                fnd_file.put_line(fnd_file.OUTPUT,g_string);
                                p_log (g_string);
                             else
                                fnd_file.put_line(fnd_file.LOG,'Avalara Connection Successful');
                                fnd_file.put_line(fnd_file.OUTPUT,'Avalara Connection Successful');
                                p_log ('Avalara Connection Successful');
                             END IF;

   errbuf := v_errbuf;
   retcode := v_retcode;

END TEST_CONNECTION;
-----------------------
-- get profile vales
--=====================================
FUNCTION get_profile (p_profile IN VARCHAR2, p_org_id in NUMBER)
RETURN VARCHAR2
-- =====================================================================
-- DESCRIPTION   : return system profile value
--
-- PARAMETERS:
--  profile name
-- org id
-- =====================================================================
IS
 v_profile_value FND_PROFILE_OPTION_VALUES.profile_option_value%TYPE := NULL;
 v_upper_profile FND_PROFILE_OPTIONS_VL.profile_option_name%TYPE := UPPER(p_profile);
 -- check org_id value
 v_org_id NUMBER := NVL(p_org_id,FND_PROFILE.VALUE('ORG_ID'));

 cursor cur_org_profile is
    select fpv.PROFILE_OPTION_VALUE
    from apps.fnd_profile_options_vl fp, apps.FND_PROFILE_OPTION_VALUES fpv
    where upper(profile_option_name) = v_upper_profile
    and  fp.PROFILE_OPTION_ID = fpv.PROFILE_OPTION_ID
    and fpv.LEVEL_VALUE = v_org_id;

  l_api_name       CONSTANT VARCHAR2(30) := 'get_profile';
------
BEGIN
 P_LOG ('BEGIN - ' ||G_PKG_NAME||': '||l_api_name||'(+)');
 P_LOG ('=== PARAMETER VALUES ===');
 P_LOG ('p_profile = '||p_profile);
 P_LOG ('p_org_id = '||p_org_id);
 P_LOG ('v_org_id = '||v_org_id);
 P_LOG ('========================');

 -- check if org level values available
 open cur_org_profile;
 fetch cur_org_profile into v_profile_value;
 close cur_org_profile;

 if v_profile_value is null -- no org level value
 then
  -- get site level value
  v_profile_value := FND_PROFILE.VALUE(v_upper_profile);
 end if;
     p_log ('Profile Name - '||v_upper_profile );
     p_log ('Profile Value - '||v_profile_value );

 P_LOG ('END - ' ||G_PKG_NAME||': '||l_api_name||'(-)');
 ------------
 RETURN v_profile_value;
 ----------
EXCEPTION
 WHEN OTHERS THEN
    g_string :='Others Exception in '||G_PKG_NAME||': '||l_api_name ||' = '|| sqlerrm;
    P_LOG ( g_string );
END get_profile;
------------
-----
PROCEDURE ADDRESS_VALIDATION (   p_addrval_doc IN OUT NOCOPY NCLOB,
                                 p_loc_id IN NUMBER,
                                 x_return_status OUT NOCOPY VARCHAR2
                             )
-- =====================================================================
-- DESCRIPTION   : get Address validation response from Avalara
--
-- =====================================================================
IS
  v_errbuf VARCHAR2(1) := FND_API.G_RET_STS_SUCCESS;
  v_retcode VARCHAR2(5) := '0';

  l_api_name       CONSTANT VARCHAR2(30) := 'ADDRESS VALIDATION';
------
BEGIN
 P_LOG ('BEGIN - ' ||G_PKG_NAME||': '||l_api_name||'(+)');
 P_LOG ('=== PARAMETER VALUES ===');
 P_LOG ('p_loc_id = '||p_loc_id);
 P_LOG ('========================');

                          --submit xml
                            xml_request_response  ( p_addrval_doc,'ADDRV',v_errbuf,p_loc_id );

                            

                             IF v_errbuf <> FND_API.G_RET_STS_SUCCESS THEN
                                 if v_clob_created then
                                    dbms_lob.freetemporary (lob_loc => v_clob);
                                    v_clob_created := false;
                                 end if;
                                    v_errbuf := FND_API.G_RET_STS_ERROR;
                                    p_log ('Avalara Address Validation request failed...');
                                    p_addrval_doc := NULL;
                             else
                                P_LOG('Avalara Address Validation request successful, return response xml');
                                p_addrval_doc := response_body;
                             END IF;
 P_LOG ('END - ' ||G_PKG_NAME||': '||l_api_name||'(-)');
EXCEPTION
 WHEN OTHERS THEN
    g_string :='Others Exception in '||G_PKG_NAME||': '||l_api_name ||' = '|| sqlerrm;
    P_LOG ( g_string );
END ADDRESS_VALIDATION;
-- Auto Invoice resubmit with Invoice Num
PROCEDURE AUTO_INV_RESUB_INVNUM ( errbuf    OUT NOCOPY   VARCHAR2,
                                retcode OUT NOCOPY   VARCHAR2 )
IS
 cursor c_transaction_header
 is
    select distinct
    INTERNAL_ORGANIZATION_ID
    ,DOCUMENT_TYPE_ID
    ,TRANSACTION_ID
    ,APPLICATION_CODE
    ,DOCUMENT_LEVEL_ACTION
    ,TRX_DATE
    ,TRX_CURRENCY_CODE
    ,LEGAL_ENTITY_NUMBER
    ,ESTABLISHMENT_NUMBER
    ,(select TRX_NUMBER from RA_CUSTOMER_TRX_all where customer_trx_id = a.transaction_id and rownum = 1) TRANSACTION_NUMBER
    ,TRANSACTION_DESCRIPTION
    ,DOCUMENT_SEQUENCE_VALUE
    ,NVL(TRANSACTION_DUE_DATE, TRX_DATE) TRANSACTION_DUE_DATE -- handle null for project invoices
    ,ALLOW_TAX_CALCULATION
    ,HEADER_CHAR1
    ,HEADER_CHAR2
    ,HEADER_CHAR3
    ,HEADER_CHAR4
    ,HEADER_CHAR5
    ,HEADER_CHAR6
    ,HEADER_CHAR7
    ,HEADER_CHAR8
    ,HEADER_CHAR9
    ,HEADER_CHAR10
    ,HEADER_NUMERIC1
    ,HEADER_NUMERIC2
    ,HEADER_NUMERIC3
    ,HEADER_NUMERIC4
    ,HEADER_NUMERIC5
    ,HEADER_NUMERIC6
    ,HEADER_NUMERIC7
    ,HEADER_NUMERIC8
    ,HEADER_NUMERIC9
    ,HEADER_NUMERIC10
    ,HEADER_DATE1
    ,HEADER_DATE2
    ,HEADER_DATE3
    ,HEADER_DATE4
    ,HEADER_DATE5
  From AVALARA.AVLR_TMP_ZX_O2C_CALC_TXN_INPUT a
  where HEADER_CHAR29 = 'Y' -- Auto invoice rerun
  and DOCUMENT_LEVEL_ACTION = 'CREATE'
  order by transaction_id;

 cursor c_inv_trans_lines (cp_trans_id number)
 is
    -- invoice lines
    select trx_line_id,
    trx_level_type,
    line_level_action,
    EVENT_CLASS_CODE,
    TRX_SHIPPING_DATE,
    TRX_RECEIPT_DATE,
    TRX_LINE_TYPE,
    trx_line_date,
    TRX_LINE_NUMBER,
    TRX_LINE_DESCRIPTION,
    PROVNL_TAX_DETERMINATION_DATE,
    TRX_BUSINESS_CATEGORY,
    LINE_INTENDED_USE,
    LINE_AMT_INCLUDES_TAX_FLAG,
    LINE_AMT,
    null OTHER_INCLUSIVE_TAX_AMOUNT,
    nvl(TRX_LINE_QUANTITY,1),
    UNIT_PRICE,
    CASH_DISCOUNT,
    VOLUME_DISCOUNT,
    TRADING_DISCOUNT,
    TRANSPORTATION_CHARGE,
    INSURANCE_CHARGE,
    OTHER_CHARGE,
    PRODUCT_ID,
    UOM_CODE,
    PRODUCT_TYPE,
    PRODUCT_CODE,
    FOB_POINT,
    ASSESSABLE_VALUE,
    PRODUCT_DESCRIPTION,
    ACCOUNT_CCID,
    EXEMPT_CERTIFICATE_NUMBER,
    EXEMPT_REASON_CODE,
    EXEMPTION_CONTROL_FLAG,
    SHIP_FROM_LOCATION_ID,
    SHIP_TO_LOCATION_ID,
    BILL_FROM_LOCATION_ID,
    BILL_TO_LOCATION_ID,
    POA_LOCATION_ID,
    POO_LOCATION_ID,
    APPLIED_FROM_TRX_ID,
    APPLIED_FROM_LINE_ID,
    APPLIED_FROM_TRX_LEVEL_TYPE,
    APPLIED_FROM_TRX_NUMBER,
    ADJUSTED_DOC_TRX_ID,
    ADJUSTED_DOC_LINE_ID,
    ADJUSTED_DOC_TRX_LEVEL_TYPE,
    ADJUSTED_DOC_NUMBER,
    ADJUSTED_DOC_DATE,
    CHAR1,
    CHAR2,
    CHAR3,
    CHAR4,
    CHAR5,
    CHAR6,
    CHAR7,
    CHAR8,
    CHAR9,
    CHAR10,
    NUMERIC1,
    NUMERIC2,
    NUMERIC3,
    NUMERIC4,
    NUMERIC5,
    NUMERIC6,
    NUMERIC7,
    NUMERIC8,
    NUMERIC9,
    NUMERIC10,
    DATE1,
    DATE2,
    DATE3,
    DATE4,
    DATE5
   from apps.zx_lines_det_factors
   where trx_id = cp_trans_id
   order by TRX_LINE_NUMBER;


  l_api_name       CONSTANT VARCHAR2(30) := 'AUTO_INV_RESUB_INVNUM';
  l_return_status        VARCHAR2(30);
  ptr                    NUMBER;
  hdr                    NUMBER;
  lns                    NUMBER;

  v_cnt number := 0;
  v_complete_flag        apps.RA_CUSTOMER_TRX_all.complete_flag%TYPE;
  v_request_id number := NULL;

  v_attr_col1 VARCHAR2(30) := NULL;
  v_sql_stmt  VARCHAR2(200) := NULL;
  v_country   VARCHAR2(30) := NULL;
  v_ava_call  RA_CUST_TRX_TYPES_ALL.ATTRIBUTE1%TYPE := NULL;
  v_zero_ava_call RA_CUST_TRX_TYPES_ALL.ATTRIBUTE1%TYPE := NULL;
  v_txn_value number := NULL;
  v_HEADER_ID NUMBER;
  v_SUBTOTAL  NUMBER;
  v_DISCOUNT  NUMBER;
  v_CHARGES   NUMBER;
  v_TAX       NUMBER;
 v_attr_col3        VARCHAR2(40);
 v_attr_col4        VARCHAR2(40);
 v_attr_cols        VARCHAR2(100);
 v_sql_stmt3        VARCHAR2(2500);

 l_proc_rec ZX_O2C_CALC_TXN_INPUT_V%rowtype;

 exp_skip_trans exception;

BEGIN

  err_count      := 0;

 P_LOG ('BEGIN - ' ||G_PKG_NAME||': '||l_api_name||'(+)');
  v_clob_created := false;

    -- open transaction headers to process
    open c_transaction_header;
    fetch c_transaction_header
     bulk collect into
     pg_internal_org_id_tab ,
     pg_doc_type_id_tab,
     pg_trx_id_tab,
     pg_appli_code_tab,
     pg_doc_level_action_tab,
     pg_trx_date_tab,
     pg_trx_curr_code_tab,
     pg_legal_entity_num_tab,
     pg_esta_name_tab,
     pg_trx_number_tab,
     pg_trx_desc_tab,
     pg_doc_sequence_value_tab,
     pg_trx_due_date_tab,
     pg_allow_tax_calc_tab,
     pg_header_char1_tab,
     pg_header_char2_tab,
     pg_header_char3_tab,
     pg_header_char4_tab,
     pg_header_char5_tab,
     pg_header_char6_tab,
     pg_header_char7_tab,
     pg_header_char8_tab,
     pg_header_char9_tab,
     pg_header_char10_tab,
     pg_header_NUMERIC1_tab,
     pg_header_NUMERIC2_tab,
     pg_header_NUMERIC3_tab,
     pg_header_NUMERIC4_tab,
     pg_header_NUMERIC5_tab,
     pg_header_NUMERIC6_tab,
     pg_header_NUMERIC7_tab,
     pg_header_NUMERIC8_tab,
     pg_header_NUMERIC9_tab,
     pg_header_NUMERIC10_tab,
     pg_header_date1_tab,
     pg_header_date2_tab,
     pg_header_date3_tab,
     pg_header_date4_tab,
     pg_header_date5_tab
     limit C_LINES_PER_COMMIT; -- limit the fetch for performance
    close c_transaction_header;
    -- check if any to process
    IF (nvl(pg_trx_id_tab.last,0) = 0) Then
        g_string :='No Auto Invoice Transactions to reprocess';
        P_LOG (g_string);
        fnd_file.put_line(fnd_file.LOG,g_string);
    ELSE -- header cursor returned some rows that can be processed
        P_LOG (  ' Header records in ZX_O2C_CALC_TXN_INPUT_V = '||pg_trx_id_tab.last);
        fnd_file.put_line(fnd_file.LOG,' Header records in ZX_O2C_CALC_TXN_INPUT_V = '||pg_trx_id_tab.last);
           -- loop through header records
           For hdr in 1..nvl(pg_trx_id_tab.last, 0)
           loop
		    BEGIN
             H := hdr;
               --g_trx_level_type  :=  pg_trx_level_type_tab(h);
               g_docment_type_id  :=  pg_doc_type_id_tab(h);
               g_trasaction_id  :=  pg_trx_id_tab(h);
               g_tax_regime_code  :=  apps.zx_tax_partner_pkg.g_tax_regime_code;

                P_LOG (  'g_docment_type_id : ' ||g_docment_type_id);
                P_LOG (  'g_trasaction_id : ' ||g_trasaction_id);
                P_LOG (  'g_tax_regime_code : ' ||g_docment_type_id);
                   
                fnd_file.put_line(fnd_file.LOG,  'g_docment_type_id : ' ||g_docment_type_id);
                fnd_file.put_line(fnd_file.LOG,  'g_trasaction_id : ' ||g_trasaction_id);
                fnd_file.put_line(fnd_file.LOG,  'g_tax_regime_code : ' ||g_docment_type_id);

                                 -- reset flag in AVA temp table to process POST transactions for Auto Invoice after tax run
                                update AVALARA.AVLR_TMP_ZX_O2C_CALC_TXN_INPUT
                                set HEADER_CHAR29 = 'N'
                                where transaction_id = pg_trx_id_tab(h)
								 and HEADER_CHAR29 = 'Y'
								 and DOCUMENT_LEVEL_ACTION = 'CREATE';

				Begin
                     select  event_class_code
                     into    l_document_type
                     from    apps.zx_evnt_cls_mappings
                     where   event_class_mapping_id = pg_doc_type_id_tab(h);
                    Exception
                      When no_data_found then
                        P_LOG (SQLERRM);
                        g_string :='No document type exist for provided event_class_mapping_id ';
                        P_LOG (g_string);
                        fnd_file.put_line(fnd_file.LOG,g_string);
                        raise exp_skip_trans;
                    End;
                P_LOG (   ' DOCUMENT_TYPE  '||l_document_type);
               P_LOG (' Value of Variable H is :'||H);

                fnd_file.put_line(fnd_file.LOG,  ' DOCUMENT_TYPE  '||l_document_type);
               fnd_file.put_line(fnd_file.LOG,' Value of Variable H is :'||H);

               -- build XML msg structure for header record
               build_xml_header (p_mode => 'GET');
               --- get transaction lines to process
				-- open invoice lines
                    open c_inv_trans_lines (pg_trx_id_tab(h));
                    fetch c_inv_trans_lines
                     bulk collect into
                        pg_trx_line_id_tab
                        ,pg_trx_level_type_tab
                        ,pg_line_level_action_tab
                        ,pg_line_class_tab
                        ,pg_trx_shipping_date_tab
                        ,pg_trx_receipt_date_tab
                        ,pg_trx_line_type_tab
                        ,pg_trx_line_date_tab
                        ,pg_trx_line_number_tab
                        ,pg_trx_line_desc_tab
                        ,pg_prv_tax_det_date_tab
                        ,pg_trx_business_cat_tab
                        ,pg_line_intended_use_tab
                        ,pg_line_amt_incl_tax_flag_tab
                        ,pg_line_amount_tab
                        ,pg_other_incl_tax_amt_tab
                        ,pg_trx_line_qty_tab
                        ,pg_unit_price_tab
                        ,pg_cash_discount_tab
                        ,pg_volume_discount_tab
                        ,pg_trading_discount_tab
                        ,pg_trans_charge_tab
                        ,pg_ins_charge_tab
                        ,pg_other_charge_tab
                        ,pg_prod_id_tab
                        ,pg_uom_code_tab
                        ,pg_prod_type_tab
                        ,pg_prod_code_tab
                        ,pg_fob_point_tab
                        ,pg_assess_value_tab
                        ,pg_prod_desc_tab
                        ,pg_account_ccid_tab
                        ,pg_exempt_certi_numb_tab
                        ,pg_exempt_reason_tab
                        ,pg_exempt_cont_flag_tab
                        ,pg_ship_fr_loc_id_tab
                        ,pg_ship_to_loc_id_tab
                        ,pg_bill_fr_loc_id_tab
                        ,pg_bill_to_loc_id_tab
                        ,pg_poa_loc_id_tab
                        ,pg_poo_loc_id_tab
                        ,pg_appl_from_trx_id_tab
                        ,pg_appl_from_line_id_tab
                        ,pg_appl_fr_trx_lev_type_tab
                        ,pg_appl_from_doc_num_tab
                        ,pg_adj_doc_trx_id_tab
                        ,pg_adj_doc_line_id_tab
                        ,pg_adj_doc_trx_lev_type_tab
                        ,pg_adj_doc_number_tab
                        ,pg_adj_doc_date_tab
                        ,pg_line_char1_tab
                        ,pg_line_char2_tab
                        ,pg_line_char3_tab
                        ,pg_line_char4_tab
                        ,pg_line_char5_tab
                        ,pg_line_char6_tab
                        ,pg_line_char7_tab
                        ,pg_line_char8_tab
                        ,pg_line_char9_tab
                        ,pg_line_char10_tab
                        ,pg_line_NUMERIC1_tab
                        ,pg_line_NUMERIC2_tab
                        ,pg_line_NUMERIC3_tab
                        ,pg_line_NUMERIC4_tab
                        ,pg_line_NUMERIC5_tab
                        ,pg_line_NUMERIC6_tab
                        ,pg_line_NUMERIC7_tab
                        ,pg_line_NUMERIC8_tab
                        ,pg_line_NUMERIC9_tab
                        ,pg_line_NUMERIC10_tab
                        ,pg_line_date1_tab
                        ,pg_line_date2_tab
                        ,pg_line_date3_tab
                        ,pg_line_date4_tab
                        ,pg_line_date5_tab
                        limit C_LINES_PER_COMMIT; -- limit the fetch
					close c_inv_trans_lines;				
                IF (nvl(pg_trx_line_id_tab.last,0) = 0)
                Then
                  g_string :='No lines exist for Transaction id -'|| pg_trx_id_tab(h);
                  P_LOG (g_string);
                  fnd_file.put_line(fnd_file.LOG,g_string);
				  -- handle no lines scenario
				  --- free temp clob from memory
				  if v_clob_created then
					 dbms_lob.freetemporary (lob_loc => v_clob);
					 v_clob_created := false;
				  end if;
                  raise exp_skip_trans;
                ELSE --lines cursor has returned some rows that can be processed
                 ---build XML tag for lines
                 build_xml_lines_tag ('START');
                -- loop through trans lines
                   For lns in 1..nvl(pg_trx_line_id_tab.last, 0)
                   loop
                     L := lns;
                       g_transaction_line_id  :=  pg_trx_line_id_tab(l);
                      -- all good, build lines xml structure
                      build_xml_lines;
                   end loop; -- trans lines
                  -- close lines tag
                  build_xml_lines_tag ('END');
                 END IF; -- trans_line_count
                     --post XML Request to Avalara
                        xml_request_response  ( v_clob,'GET',l_return_status );

                         IF l_return_status <> FND_API.G_RET_STS_SUCCESS THEN
                             if v_clob_created then
                                dbms_lob.freetemporary (lob_loc => v_clob);
                                v_clob_created := false;
                             end if;
                                g_string := g_string ||'-'||'Failed in GetTax Request to Avalara';
                                P_LOG (g_string);
                                fnd_file.put_line(fnd_file.LOG,g_string);
                                raise exp_skip_trans;
                         END IF;

                     p_log ('checking complete flag of trans id - '||pg_trx_id_tab(h));
                     fnd_file.put_line(fnd_file.LOG,'checking complete flag of trans id - '||pg_trx_id_tab(h));

                            -- check if Invoice transaction flagged COMPLETE
                            v_complete_flag := NULL;
                            v_request_id := NULL;
                            begin
                              select request_id, decode(request_id,NULL,complete_flag,'Y') --use request id to check auto-invoice
                                into v_request_id, v_complete_flag
                              from apps.RA_CUSTOMER_TRX_all
                               where CUSTOMER_TRX_ID = pg_trx_id_tab(h);
                            exception
                              when others then
                                p_log ('others exp getting complete flag');
                                p_log ('error - '|| sqlerrm);
                                v_complete_flag := NULL;
                                v_request_id := NULL;
                            end;

                            p_log ('v_complete_flag = '||v_complete_flag);
                            p_log ('v_request_id = '||v_request_id);

                            fnd_file.put_line(fnd_file.LOG,'v_complete_flag = '||v_complete_flag);
                            fnd_file.put_line(fnd_file.LOG,'v_request_id = '||v_request_id);

                            if NVL(v_complete_flag,'N') = 'Y'
                            then
                              -- transaction is complete, send post-commit to Avalara
                              -- build XML msg structure for header record
                                build_xml_header (p_mode => 'POST');

                              --post XML Request to Avalara
                                xml_request_response  ( v_clob,'POST',l_return_status );

                                p_log ('l_return_status = '||l_return_status);
                                fnd_file.put_line(fnd_file.LOG,'l_return_status = '||l_return_status);


                                 IF l_return_status <> FND_API.G_RET_STS_SUCCESS THEN
                                     if v_clob_created then
                                        dbms_lob.freetemporary (lob_loc => v_clob);
                                        v_clob_created := false;
                                     end if;
                                        g_string := g_string ||'-'||'Failed in PostCommit Request to Avalara';
                                        P_LOG (g_string);
                                        fnd_file.put_line(fnd_file.LOG, g_string);
                                        raise exp_skip_trans;
                                 END IF;
                            end if;--- v_complete_flag

				exception
					when exp_skip_trans then
					   null; -- do nothing, skip
                end;				
			 commit; -- commit here				
           end loop; -- trans header
    end if; -- pg_trx_id_tab.last
 P_LOG (  'END - '||G_PKG_NAME||': '||l_api_name||'(-)');
EXCEPTION
 WHEN OTHERS THEN
    g_string :='Others Exception in '||G_PKG_NAME||': '||l_api_name ||' = '|| sqlerrm;
    P_LOG ( g_string );
    fnd_file.put_line(fnd_file.LOG, g_string);
         if v_clob_created then
            dbms_lob.freetemporary (lob_loc => v_clob);
            v_clob_created := false;
         end if;
END AUTO_INV_RESUB_INVNUM;
---============================
-----------------------
END ZX_AVALARA_TAX_SERVICE_PKG;
/
show err

