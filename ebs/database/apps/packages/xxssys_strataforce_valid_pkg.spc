create or replace package xxssys_strataforce_valid_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            xxssys_strataforce_valid_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   11/20/2017
  ----------------------------------------------------------------------------
  --  purpose :        CHG0041829 - Generic package to handle all interface
  --                   event generation funtions/procedures for new Salesforce platform
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  11/20/2017  Diptasurjya Chatterjee(TCS)  CHG0041829 - initial build
  --  1.1  23/05/2018  Lingaraj (TCS)               CHG0042874 - Field Service Usage interface from salesforce to Oracle
  --  1.2  24/06/2019  Bellona (TCS)                CHG0045786 - Extending Field Service Usage interface from salesforce 
  --                                                to Oracle to handle serial control items 
  ----------------------------------------------------------------------------

  /* Global Variable declaration for Logging unit*/
  g_log              VARCHAR2(1) := fnd_profile.value('AFLOG_ENABLED');
  g_log_module       VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
  g_request_id       NUMBER := fnd_profile.value('CONC_REQUEST_ID');
  g_api_name         VARCHAR2(30) := 'xxssys_strataforce_valid_pkg';
  g_log_program_unit VARCHAR2(100);
  /* End - Global Variable Declaration */

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  26/10/2015  Diptasurjya     Initial Creation for CHG0036886.
  --                  Chatterjee
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function will be used to perform all required validation for items being interfaced
  --          to Strataforce
  -- --------------------------------------------------------------------------------------------
  -- Usage: DFF ATTRIBUTE2 for Valueset XXSSYS_EVENT_ENTITY_NAME against target STRATAFORCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee(TCS)   Initial Build
  -- --------------------------------------------------------------------------------------------
  function validate_item(P_OLD_ITEM_REC mtl_system_items_b%ROWTYPE,
                         P_NEW_ITEM_REC mtl_system_items_b%ROWTYPE)
    return varchar2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function will be used to perform all required validation for Customer accounts
  --          being interfaced to Strataforce
  -- --------------------------------------------------------------------------------------------
  -- Usage: DFF ATTRIBUTE2 for Valueset XXSSYS_EVENT_ENTITY_NAME against target STRATAFORCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee(TCS)   Initial Build
  -- --------------------------------------------------------------------------------------------
  function validate_account(p_sub_entity_code varchar2,
                            p_entity_id       number,
                            p_entity_code     varchar2) return varchar2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0041829
  --          This function will be used to perform all required validation for Customer contacts
  --          being interfaced to Strataforce
  -- --------------------------------------------------------------------------------------------
  -- Usage: DFF ATTRIBUTE2 for Valueset XXSSYS_EVENT_ENTITY_NAME against target STRATAFORCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee(TCS)   Initial Build
  -- --------------------------------------------------------------------------------------------
  function validate_contact(P_SUB_ENTITY_CODE varchar2,
                            P_ENTITY_ID       number,
                            P_ENTITY_CODE     varchar2) return varchar2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE -
  --
  --       validate_product_option
  -- --------------------------------------------------------------------------------------------
  -- Usage:
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/20/2017  Diptasurjya Chatterjee(TCS)   Initial Build
  -- --------------------------------------------------------------------------------------------
  function validate_product_option(P_INVENTORY_ITEM_ID NUMBER)
    Return Varchar2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0045786 - Field Service Usage interface from salesforce to Oracle
  -- Procedure: get_serial_num_list
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Called from get_material_trx_info to get list of serial numbers
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  20/06/2019  Bellona(TCS)                 CHG0045786-Initial Build
  -- --------------------------------------------------------------------------------------------  
  procedure get_serial_num_list(p_qty_trx in number,
                              p_inventory_item_id in number,
                              p_item_code in varchar2,
                              p_org_id in number,
                              p_subinventory_code in varchar2,
                              p_rev in varchar2,
                              p_list out XXOBJT.XXSSYS_SERIAL_NUM_TAB_TYPE,
                              p_error_code out varchar2,
                              p_error_desc out varchar2
                              );
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0045786 - Field Service Usage interface from salesforce to Oracle
  -- Procedure: is_item_serial_controlled
  --
  -- --------------------------------------------------------------------------------------------
  -- Usage: Called from validate_material_trx_info to check whether item is serial controlled or not.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  20/06/2019  Bellona(TCS)                 CHG0045786-Initial Build
  -- --------------------------------------------------------------------------------------------  

  Procedure is_item_serial_controlled (p_item_code     in   varchar2,
                                      p_org_id        in   number,
                                      p_item_serial_controlled out varchar2, -- Y/N
                                      p_error_code    out varchar2,  
                                      p_error_message out varchar2
                                     );
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042874 - Field Service Usage interface from salesforce to Oracle
  --          This Procedure will be Call By SOA
  --  Composite Name :
  --  InterFace Type : SFDC to Oracle
  -- --------------------------------------------------------------------------------------------
  -- Usage:
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  23/05/2018  Lingaraj(TCS)                 CHG0042874-Initial Build
  -- --------------------------------------------------------------------------------------------
  Procedure get_material_trx_info(p_source      in  varchar2,
                                  p_tab         in out   xxobjt.xxssys_material_tab_type,
                                  p_out_err_code    out varchar2,  --S/E
                                  p_out_err_message out varchar2
                                 );

END xxssys_strataforce_valid_pkg;
/