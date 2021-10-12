CREATE OR REPLACE PACKAGE xxcs_ib_item_creation IS
  --------------------------------------------------------------------
  --  customization code: CUST016 - IB Item Creation
  --  name:               XXCS_IB_ITEM_CREATION
  --  create by:          XXX
  --  Revision:           1.8
  --  creation date:      31/08/2009
  --  Purpose :           Create IB configuration
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/08/2010    XXX             initial build
  --  1.1   25/02/2010    Dalit A. Raviv  change v_context size
  --  1.2   03/03/2010    Dalit A. Raviv  Handle concurrent finished with error -
  --                                      errbuf value to small . add fnd_file and substr
  --  1.3   07/06/2010    Dalit A. Raviv  1) add commit when success relationship API
  --                                         there was no commit when success to create relationship
  --                                         so the last serial at the loop do not do commit and we do
  --                                         not see the relationship create.
  --                                      2) add l_api_success mark - not to do update
  --                                         if did not act API's.
  --  1.4   16/06/2010    Dalit A. Raviv  all logs will be save to log table. XXCS_IB_ITEM_CREATION_LOG
  --  1.5   12/08/2010    Dalit A. Raviv  add procedure to - External Program for IB Instance Creation
  --  1.6   05/04/2011    Roman           Added validation of inv_item_id due to SN management policy change
  --  1.7   02/05/2001    Dalit A. Raviv  Procedure create_instance - change item revision from '0' to item max revision
  --  1.8   16/01/2012    Dalit A. raviv  add procedure upd_item_att9
  --  1.9   10/20/2015    Diptasurjya     CHG0036464 - Add procedure to sync missing IB references with SFDC
  --                      Chatterjee
  --  1.15   10-APR-2018   Dan M.          CHG0042574 - Sync Salesforce install base data to Oracle install base

  -----------------------------------------------------------------------
  PROCEDURE create_instance(errbuf            OUT VARCHAR2,
                            retcode           OUT VARCHAR2,
                            p_instance_number IN NUMBER DEFAULT NULL,
                            p_item_status     IN VARCHAR2 DEFAULT NULL);

  --------------------------------------------------------------------
  --  customization code: CUST345 - External Program for IB Instance Creation
  --  name:               create_instance_ext
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      12/08/2010
  --  Purpose :           Create IB configuration
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/08/2010    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  PROCEDURE create_instance_ext(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CUST016 - 1.4 - Update Related -S items
  --  name:               upd_item_s_att9
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      16/01/2012
  --  Purpose :           Objet would like to automate the process that
  --                      serves for 'SN Reporting' Quality plan which
  --                      currently should be done by human intervention.
  --
  --                      Install Base components are created by a customization
  --                      that retrieves information from Quality plan 'SN Reporting'.
  --                      This plan is dependent (among other things) on Item Setup –
  --                      updates in Attribute 9.
  --                      The purpose of this customization is to save the human
  --                      intervention by updating the Item Attribute 9 with its
  --                      corresponding Install Base item automatically.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/08/2010    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  PROCEDURE upd_item_att9(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036464
  --          This procedure will create new item instances if it does not exist for serial number
  --          and part number or update existing instances with SF ID. This porcedure will be called
  --          from a consurrent program
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  15/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE create_missing_instance(errbuf  OUT VARCHAR2,
                                    retcode OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036464
  --          This function returns the primary site for give cust account and org id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  15/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_primary_party_site_id(p_cust_account_id IN NUMBER,
                                     p_org_id          IN NUMBER,
                                     p_site_use_code   IN varchar2,
                                     p_mode            IN varchar2)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  Procedure name : sfdc2oracle
  --  create by:          Dan Melamed
  --  Revision:           1.0
  --  creation date:      08-Apr-2018
  --  Purpose :           Change - CHG0042574 : procedure to invoke SFDC to Oracle Interface
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  3.0   08-Apr-2018    Dan Melamed   invoke SFDC to Oracle Interface : Initial Version
  --  3.1   18-Jul-2018    Dan Melamed   CHG0042574-V2 Correct prod errors - remove savepoints and rollbacks, work against Table of Rec.
  --  3.2   25-Jul-2018    Dan Melamed   CHG0042574 CTASK0037631: Add spcific Instance ID Parameter  
  -----------------------------------------------------------------------

  procedure sync_ib_sfdc2oracle(  errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_instance_ID varchar2) ;
--  function sync_ib_terminate_sc(P_INSTANCE_ID nvarchar2)return number;

END xxcs_ib_item_creation;
/
