CREATE OR REPLACE PACKAGE XXONT_S3_LEGACY_ROI_API_PKG AUTHID CURRENT_USER IS

  -- Author  : TCS
  -- Created : 08/23/2016
  -- Purpose :

  -- Author  : TCS
  -- Created : 08/23/2016
  -- Purpose : ASN Creation
  /******************************************************************************************************************************************
  * Type                : Package                                                                                                          *
  * Conversion Name     : ASN Creation                                                                                                     *
  * Name                : xxont_s3_legacy_rcvng_trxn_api_pkg                                                                                           *
  * Script Name         : xxont_s3_legacy_rcvng_trxn_api_pkg.pks                                                                                       *
  * Procedures          :                                                                                 *
                                                                                                                                           *
                                                                                                                                           *
  * Purpose             : This script is used to create Package "xxont_s3_legacy_rcvng_trxn_api_pkg" in APPS schema,                                   *
                                                                                *
  * HISTORY                                                                                                                                *
  * =======                                                                                                                                *
  * VERSION  DATE         AUTHOR(S)           DESCRIPTION                                                                                       *
  * -------  -----------  ---------------     ---------------------                                                              *
  *1.00      08/23/2016   TCS                  Draft version                                                                                        *
  ******************************************************************************************************************************************/

  --- Global Varialbe Declaration .

  PROCEDURE call_receivingtransaction(p_grp_id IN NUMBER,p_request_status out varchar2);
PROCEDURE create_lot(p_org_id     IN NUMBER,
                       p_item_id    IN NUMBER,
                       p_lot_number IN VARCHAR2,
                       p_status     OUT VARCHAR2);
END xxont_s3_legacy_roi_api_pkg;
/

