create or replace package body avataxo2c.avatax_o2c_connector_custom
AS
/*############################################################################################
*##                                                                                         ##
*##  Avalara, Inc.                                                                          ##
*##                                                                                         ##
*##  Confidentiality Information:                                                           ##
*##                                                                                         ##
*##  This program contains confidential and proprietary information                         ##
*##  of Avalara, Inc.                                                                       ##
*##                                                                                         ##
*##  Unless otherwise specified, this product is for your personal and non-commercial use.  ##
*##  You may not modify, copy, distribute, transmit, display, perform, reproduce, publish,  ##
*##  license, create derivative works from, transfer, or sell any information from this     ##
*##  product.                                                                               ##
*##                                                                                         ##
*##  Copyright ¿ 2015 Avalara, Inc. All rights reserved.                                    ##
*##                                                                                         ##
*##  Product       :   Avalara AvaTax Connector for Oracle R12 O2C                          ##
*##  Author        :   Avalara                                                              ##
*##                                                                                         ##
*#############################################################################################
*##            $Header: avatax_o2c_connector_custom_b.sql  v.1.2.0 $						##
*#############################################################################################
*/
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/08/2017  Erik Morgan       CHG0040036 - Upgrade Avalara interface to AvaTax Connectory for Oracle R12 O2C
  --------------------------------------------------------------------

/* This package body can be revised according to the business requirements */

/*======================================================================
                            Process AvaTax Call
======================================================================*/
/*Include custom logic in the function below to avoid the call to AvaTax for tax calculation*/
FUNCTION ProcessAvaTaxCall(
  TrxID     IN NUMBER,   -- EBS Transaction ID
  TrxType IN VARCHAR2)   -- EBS Transaction Type (refer event_class_code column of zx_evnt_cls_mappings table for list of values)
  RETURN BOOLEAN
IS
BEGIN
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'ProcessAvaTaxCall(+)');
  /*
  IF TrxType = 'INVOICE' THEN
  return false; -- TO AVOID CALL TO AVATAX
  END IF; */
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'ProcessAvaTaxCall(-)');
  RETURN TRUE;
EXCEPTION
WHEN OTHERS THEN
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: EXCEPTION => '||SQLERRM);
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'ProcessAvaTaxCall(-)');
  RETURN false;
END ProcessAvaTaxCall;

/*======================================================================
                            Tax Code
======================================================================*/
FUNCTION SetTaxCode(
    EBSParams IN OUT NOCOPY AVATAX_GEN_PKG.EBSParams,
    AvaTaxDocParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxDocParams,
    AvaTaxLineParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxLineParams)
    RETURN VARCHAR2
IS
  l_TaxCode VARCHAR2(30);
BEGIN
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetTaxCode(+)');
  l_TaxCode := avatax_connector_utility_pkg.g_default_custom_var;
  --BEGIN
  --Custom Logic: Assign l_TaxCode value here.
  --END;
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetTaxCode(-)');
  RETURN l_TaxCode;
EXCEPTION
WHEN OTHERS THEN
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: EXCEPTION => '||SQLERRM);
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetTaxCode(-)');
  RETURN NULL;
END SetTaxCode;

/*======================================================================
                        Entity Use Code
======================================================================*/
FUNCTION SetEntityUseCode(
    EBSParams IN OUT NOCOPY AVATAX_GEN_PKG.EBSParams,
    AvaTaxDocParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxDocParams,
    AvaTaxLineParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxLineParams)
    RETURN VARCHAR2
IS
  l_entity_use_code VARCHAR2(30);
BEGIN
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetEntityUseCode(+)');
  l_entity_use_code := avatax_connector_utility_pkg.g_default_custom_var;
  --BEGIN
  --Custom Logic: Assign l_entity_use_code value here.
  --END;
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetEntityUseCode(-)');
  RETURN l_entity_use_code;
EXCEPTION
WHEN OTHERS THEN
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: EXCEPTION => '||SQLERRM);
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetEntityUseCode(-)');
  RETURN NULL;
END SetEntityUseCode;

/*======================================================================
                            Origin Address
======================================================================*/
PROCEDURE SetLineOriginAddress(
    Country OUT NOCOPY   VARCHAR2,
    Region OUT NOCOPY     VARCHAR2,
    City OUT NOCOPY      VARCHAR2,
    PostalCode OUT NOCOPY       VARCHAR2,
    Line1 OUT NOCOPY  VARCHAR2,
    Line2 OUT NOCOPY  VARCHAR2,
    Line3 OUT NOCOPY  VARCHAR2,
    TaxRegionId OUT NOCOPY NUMBER,
    AddressCode OUT NOCOPY     VARCHAR2,
    EBSParams IN OUT NOCOPY AVATAX_GEN_PKG.EBSParams,
    AvaTaxDocParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxDocParams,
    AvaTaxLineParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxLineParams)
IS
BEGIN
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetLineOriginAddress(+)');
  --BEGIN
  --Assign SHIP FROM address to the OUT parameters and comment code below
  AddressCode := avatax_connector_utility_pkg.g_default_custom_var;
  --END;
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetLineOriginAddress(-)');
EXCEPTION
WHEN OTHERS THEN
  avatax_connector_utility_pkg.printout('AvaTax O2C: EXCEPTION => '||sqlerrm);
  AddressCode := 'ERROR';
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetLineOriginAddress(-)');
END SetLineOriginAddress;

/*======================================================================
                            Destination Address
======================================================================*/
FUNCTION SetLineDestSiteUseID(
    EBSParams IN OUT NOCOPY AVATAX_GEN_PKG.EBSParams,
    AvaTaxDocParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxDocParams,
    AvaTaxLineParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxLineParams)
    RETURN NUMBER
IS
  l_siteuseid NUMBER;
BEGIN
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetLineDestSiteUseID(+)');
  l_siteuseid := avatax_connector_utility_pkg.g_default_custom_var;
  --BEGIN
  --Assign any Site use id to l_siteuseid
  --l_siteuseid := 1002;
  --END;
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetLineDestSiteUseID(-)');
  RETURN l_siteuseid;
EXCEPTION
WHEN OTHERS THEN
  avatax_connector_utility_pkg.printout('AvaTax O2C: EXCEPTION => '||sqlerrm);
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetLineDestSiteUseID(-)');
  RETURN NULL;
END SetLineDestSiteUseID;

/*====================================================================
                        AvaTax Company Code
======================================================================*/
------------------------------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  22/08/2017  Erik Morgan       CHG0040036 - Upgrade Avalara interface to AvaTax Connectory for Oracle R12 O2C
------------------------------------------------------------------------------------------
-- In Generic O2C Connector, the AvaTax company code value is retrieved from
-- Add'l Org. Unit Details DFF. Any value can be passed based on business logic through this Function

FUNCTION SetCompanyCode(
    EBSParams IN OUT NOCOPY AVATAX_GEN_PKG.EBSParams,
    AvaTaxDocParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxDocParams,
    AvaTaxLineParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxLineParams)
    RETURN VARCHAR2
IS
  l_company_code VARCHAR2(200);

  --V1.0 22 Aug2017 - CHG0040036 Custom Code added for SSYS  - start
  l_env          varchar2(20)  := apps.xxobjt_general_utils_pkg.am_i_in_production; -- return Y if Production
  --V1.0 22 Aug2017 - CHG0040036 End of SSYS custom code
  
BEGIN
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetCompanyCode(+)');
  l_company_code := avatax_connector_utility_pkg.g_default_custom_var;

  --V1.0 22 Aug2017 - CHG0040036 Custom Code added for SSYS  - start
  --Assign company code value for non-production.
  BEGIN
       If nvl(l_env, 'N') = 'N' then
        l_company_code := 'TEST-SSYS';
        avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'Not Production - Override Tax Company');
        avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'Test Company Code: '||l_company_code);
     End If; 
  END;
  --V1.0 22 Aug2017 - CHG0040036 End of SSYS custom code
  
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetCompanyCode(-)');
  RETURN l_company_code;
EXCEPTION
WHEN OTHERS THEN
  avatax_connector_utility_pkg.printout('AvaTax O2C: EXCEPTION => '||sqlerrm);
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetCompanyCode(-)');
  RETURN NULL;
END SetCompanyCode;

/*====================================================================
                    ItemCode / GoodsServiceCode
======================================================================*/
FUNCTION SetItemCode(
    EBSParams IN OUT NOCOPY AVATAX_GEN_PKG.EBSParams,
    AvaTaxDocParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxDocParams,
    AvaTaxLineParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxLineParams)
    RETURN VARCHAR2
IS
  l_item_code VARCHAR2(40);
BEGIN
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetItemCode(+)');
  l_item_code := avatax_connector_utility_pkg.g_default_custom_var;
  --BEGIN
  --Assign the ItemCode to l_item_code
  --END;
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetItemCode(-)');
  RETURN l_item_code;
EXCEPTION
WHEN OTHERS THEN
  avatax_connector_utility_pkg.printout('AvaTax O2C: EXCEPTION => '||sqlerrm);
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetItemCode(-)');
  RETURN NULL;
END SetItemCode;

/*======================================================================
                            GL Account
======================================================================*/
FUNCTION SetGLAccount(
    EBSParams IN OUT NOCOPY AVATAX_GEN_PKG.EBSParams,
    AvaTaxDocParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxDocParams,
    AvaTaxLineParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxLineParams)
    RETURN VARCHAR2
IS
  l_GLAcct VARCHAR2(30);
BEGIN
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetGLAccount(+)');
  l_GLAcct := avatax_connector_utility_pkg.g_default_custom_var;
  --BEGIN
  --Assign l_GLAcct value here.
  --END;
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetGLAccount(-)');
  RETURN l_GLAcct;
EXCEPTION
WHEN OTHERS THEN
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: EXCEPTION => '||SQLERRM);
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'SetGLAccount(-)');
  RETURN NULL;
END SetGLAccount;

/*=======================================================================================
 Any customization can be done to the AvaTax input parameters before call to AvaTax APIs
========================================================================================*/
------------------------------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  22/08/2017  Erik Morgan       CHG0040036 - Upgrade Avalara interface to AvaTax Connectory for Oracle R12 O2C
------------------------------------------------------------------------------------------
PROCEDURE PreAvaTaxCall(
    EBSParams IN OUT NOCOPY AVATAX_GEN_PKG.EBSParams,
    AvaTaxDocParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxDocParams,
    AvaTaxLineParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxLineParams)
IS

BEGIN
  -- Include Any Custom Logic Code.
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'PreAvaTaxCall(+)');
  --NULL;

  --V1.0 22 Aug2017 - CHG0040036 Custom Code added for SSYS  - start
  If (EBSParams.ApplicationCode = 'AR')
     Then
        --Change value used for Document Code in AvaTax to ra_customer_trx_all.customer_trx_id
        AvaTaxDocParams.doccode := EBSParams.TrxID;
        avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'Set DocCode as TrxId');
        
        --Set Reference Number as Sales Order Number
        Select CT_REFERENCE
          Into AvaTaxDocParams.ReferenceCode
          From apps.ra_customer_trx_all
         Where Customer_Trx_Id = EBSParams.TrxID;
           
        avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'ReferenceCode as Sales Order');
        
/*Remove custom code for sending PO, SmartERP patch should resolve issue with connector
        --Use Purchase Order number from AR transaction
        Select ctx.Purchase_order
          Into AvaTaxDocParams.PurchaseOrderNo
          From ra_customer_trx_all ctx
         Where ctx.customer_trx_id = EBSParams.TrxID;

   ELSIF (EBSParams.ApplicationCode = 'ONT')
     Then
        --Use Purchase Order number from Sales Order
        Select Oeh.Cust_Po_Number
          Into AvaTaxDocParams.PurchaseOrderNo
          From ONT.Oe_Order_Headers_AlL oeh
         Where oeh.header_id = EBSParams.TrxID;
*/
  
  End if;  

  --V1.0 22 Aug2017 - CHG0040036 End of SSYS custom code

  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'PreAvaTaxCall(-)');
EXCEPTION
WHEN OTHERS THEN
  avatax_connector_utility_pkg.printout('AvaTax O2C: EXCEPTION => '||sqlerrm);
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'PreAvaTaxCall(-)');
END PreAvaTaxCall;

/*===========================================================================================================
 Any customization can be done to the AvaTax output parameters after the results are returned from AvaTax
============================================================================================================*/
PROCEDURE PostAvaTaxCall(
    EBSParams IN OUT NOCOPY AVATAX_GEN_PKG.EBSParams,
    AvaTaxDocParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxDocParams,
    AvaTaxLineParams IN OUT NOCOPY AVATAX_GEN_PKG.AvaTaxLineParams)
IS
BEGIN
  -- Include Any Custom Logic Code.
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'PostAvaTaxCall(+)');
  NULL;
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'PostAvaTaxCall(-)');
EXCEPTION
WHEN OTHERS THEN
  avatax_connector_utility_pkg.printout('AvaTax O2C: EXCEPTION => '||sqlerrm);
  avatax_connector_utility_pkg.PrintOut('AvaTax O2C: '||g_package_name||':'||'PostAvaTaxCall(-)');
END PostAvaTaxCall;

END avatax_o2c_connector_custom;
/
