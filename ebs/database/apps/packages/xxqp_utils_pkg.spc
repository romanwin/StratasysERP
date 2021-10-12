CREATE OR REPLACE PACKAGE xxqp_utils_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: http://sv-glo-tools01p.stratasys.dmn/svn/ERP/ebs/database/apps/packages/xxqp_utils_pkg.spc 4567 2020-04-24 16:40:30Z dchatterjee $
  ---------------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               XXQP_UTILS_PKG
  --  create by:          AVIH
  --  $Revision: 4567 $
  --  creation date:      05/07/2009
  --  Purpose :           QP generic functions + price list uploading
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05/07/2009    AVIH            initial build
  --  2.0   13.2.2011     yuval tal       bug fix at price_list_fnd_util
  --  3.0   10.10.11      yuval tal       add massive pl update
  --  3.1   19/08/2014    Yuval tal       CHG0032089 - Adjust Price List Mass Update form and program to support CS requirements
  --                                      add handle_item,get_target_price,main_process_pl
  --                                      modify update_pl,add_price_list_lines,update_item_price
  --  3.2   15/01/2015    Michal Tzvik    CHG0034284 - Fix price list upload program
  --                                      -- Remove parameter from price_list_fnd_util
  --  4.0   13-APR-2017   Diptasurjya     CHG0040166 - Modify pricelist update and simulation functionality to incorporate
  --                                      usage of multiple rule grouping conditions (major change)
  --                                      Add new feature to close PL lines
  --                                      Also functionality to send PL update log automatically to specified email ID has been
  --                                      incorporated
  --  5.0   12-JUL-2019   Diptasurjya     CHG0045880 - Handle simulation approval WF
  --  5.1   18-FEB-2020   Diptasurjya     CHG0047324 - PL Upload program should not consider PL rule header table.
  --                                      Because PL rule header might have been changed by user between simulation and PL update
  -----------------------------------------------------------------------
  
  -- CHG0047324 added below record type
  TYPE xxqp_pl_upd_data_rec IS RECORD(
    rid              VARCHAR2(50),
    list_line_id     number,
    err_code         VARCHAR2(30),
    err_message      VARCHAR2(4000));

  -- CHG0047324 added below table of record type
  TYPE xxqp_pl_upd_data_tab IS TABLE OF xxqp_pl_upd_data_rec INDEX BY BINARY_INTEGER;
  
  PROCEDURE log(p_string VARCHAR2);
  FUNCTION get_target_price(p_rule_id           NUMBER,
        p_inventory_item_id NUMBER) RETURN NUMBER;
  --------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               price_list_fnd_util
  --  create by:          AVIH
  --  $Revision: 4567 $
  --  creation date:      05/07/2009
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05/07/2009    AVIH            initial build
  -----------------------------------------------------------------------
  PROCEDURE price_list_fnd_util(errbuf            OUT VARCHAR2,
            retcode           OUT VARCHAR2,
            p_masterorganizid IN NUMBER,
            p_location        IN VARCHAR2,
            p_file_name       IN VARCHAR2,
            p_list_header_id  IN NUMBER,
            p_effective_date  IN VARCHAR2,
            p_close_lines     IN VARCHAR2
            --p_end_date        IN VARCHAR2 --> CHG0034284 Michal Tzvik 15.01.2015: Remove parameter
            );

  --------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               price_list_fnd_util
  --  create by:          Vitaly K.
  --  $Revision: 4567 $
  --  creation date:      07/08/2012
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/08/2012    Vitaly K.       initial build
  -----------------------------------------------------------------------
  PROCEDURE price_list_fnd_util2(errbuf              OUT VARCHAR2,
             retcode             OUT VARCHAR2,
             p_master_organiz_id IN NUMBER,
             p_location          IN VARCHAR2,
             p_file_name         IN VARCHAR2,
             p_list_header_id    IN NUMBER,
             p_effective_date    IN VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               get_custom_price
  --  create by:          AVIH
  --  $Revision: 4567 $
  --  creation date:      05/07/2009
  --  Description:        This procedure called from QP_CUSTOM package.
  --                      The Get Custom Price API is a customizable function to which the user may add
  --                      custom code.  The API is called by the pricing engine while evaluating a
  --                      formula that contains a formula line (step) of type Function.  One or more
  --                      formulas may be set up to contain a formula line of type Function and the
  --                      same API is called each time.  So the user must code the logic in the API
  --                      based on the price_formula_id that is passed as an input parameter to the API.
  --
  --  In param            p_price_formula_id the formula ID
  --                      p_list_price the list price when the formula step type is 'List Price'
  --                      p_price_effective_date the date the price is effective
  --                      p_req_line_attrs_tbl the input line attributes
  --
  --  return              the calculated price
  --
  --  rep:                displayname Get Custom Price
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05/07/2009    AVIH            initial build
  -----------------------------------------------------------------------
  FUNCTION get_custom_price(p_price_formula_id     IN NUMBER,
        p_list_price           IN NUMBER,
        p_price_effective_date IN DATE,
        p_req_line_attrs_tbl   IN qp_formula_price_calc_pvt.req_line_attrs_tbl)
    RETURN NUMBER;

  --------------------------------------------------------------------
  --  Name      :        handle_exclusion
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     04/12/2017
  --------------------------------------------------------------------
  --  Purpose :          CHG0040166 - This procedure will be used to
  --                     check if the passed inventory item is valid
  --                     based on all defined exclusion conditions for the Pricelist
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  04/12/2017    Diptasurjya Chatterjee       Initial Build
  --------------------------------------------------------------------
  PROCEDURE handle_exclusion(p_inventory_item_id NUMBER,
    p_rule_id           NUMBER,
    x_out_item_valid    OUT NUMBER,
    x_out_actual_factor OUT NUMBER,
    x_out_traget_price  OUT NUMBER,
    x_out_new_price     OUT NUMBER,
    x_excl_exists       OUT VARCHAR2,
    x_exclude           OUT varchar2,
    x_err_code          OUT NUMBER,
    x_err_msg           OUT VARCHAR2);

  -------------------------------
  ---- Update Price List And BPA-
  PROCEDURE update_price(errbuf  OUT VARCHAR2,
     retcode OUT VARCHAR2);

  ------------------------------
  -- update_pl
  -------------------------------
  /*PROCEDURE update_pl(errbuf           OUT VARCHAR2,
            retcode          OUT VARCHAR2,
            --p_test_mode      VARCHAR2 DEFAULT 'Y',  -- CHG0045880 commented
            p_source         VARCHAR2,
            p_list_header_id NUMBER,
            p_item_code      VARCHAR2,
            --p_effective_date VARCHAR2,  -- CHG0045880 commented
            p_simulation_id  NUMBER);*/
  ------------------------------
  -- get_price_list_name
  -------------------------------
  FUNCTION get_price_list_name(p_list_header_id NUMBER) RETURN VARCHAR2;
  ------------------------------
  -- handle_item
  -------------------------------

  PROCEDURE handle_item(p_inventory_item_id NUMBER,
    p_rule_id           NUMBER,
    p_curr_price        NUMBER,
    x_out_item_valid    OUT NUMBER,
    x_out_actual_factor OUT NUMBER,
    x_out_traget_price  OUT NUMBER,
    x_out_new_price     OUT NUMBER,
    x_err_code          OUT NUMBER,
    x_err_msg           OUT VARCHAR2);
  ------------------------------
  -- rollback_price_list
  ------------------------------
  --  1.2  29-JUL-2019   Diptasurjya     CHG0045880 - obsoleted
  -------------------------------
  /*PROCEDURE rollback_price_list(errbuf       OUT VARCHAR2,
            retcode      OUT VARCHAR2,
            p_request_id NUMBER);*/

  ------------------------------
  -- add_price_list_lines
  -------------------------------
  /*PROCEDURE add_price_list_lines(errbuf           OUT VARCHAR2,
             retcode          OUT VARCHAR2,
             --p_test_mode      VARCHAR2 DEFAULT 'Y',  -- CHG0045880 commented
             p_source         VARCHAR2,
             p_list_header_id NUMBER,
             p_item_code      VARCHAR2,
             --p_effective_date VARCHAR2,  -- CHG0045880 commented
             p_simulation_id  NUMBER);*/

  --------------------------------------------------------------
  PROCEDURE delete_item_price(p_err_code       OUT NUMBER,
          p_err_message    OUT VARCHAR2,
          p_list_header_id NUMBER,
          p_list_line_id   NUMBER);

  -------------------------------------------
  -- main_process_pl
  -------------------------------------------
  --  ver   date          name            desc
  --  1.0   19.8.14      yuval tal        CHG0032089 - called from concurrent XX PL Mass Update submitted by form
  --                                      XX Price List Change Rules
  --                                      p_source CS / MRKT
  --                                      p_insert_update I - Insert U Update  B both (I,U)
  --                                      p_test_mode Y/N
  --  1.1   04/12/2017   Diptasurjya      CHG0040166 - new parameters added
  --                                      p_pl_end_date - PL Line end date for close functionality
  --                                      p_close_exclude - Only excluded items will be closed
  --                                      p_send_log_to - Send output simulation log to this email
  --                                      p_effective_date - Effective start date for PL lines to be added/updated
  --
  --                                      Parameter p_insert_update can accept a value of C
  --                                      which will close a PL line. Corresponding call to procedure close_pricelist_lines
  --                                      added.
  --                                      Also procedure send_log_mail is being called if p_send_log_to is not null
  --  1.2   07/12/2019   Diptasurjya      CHG0045880 - Add new parameter for simulation ID
  -------------------------------------------
  PROCEDURE main_process_pl(errbuf           OUT VARCHAR2,
        retcode          OUT VARCHAR2,
        p_test_mode      VARCHAR2 DEFAULT 'Y',
        p_source         VARCHAR2,
        p_insert_update  VARCHAR2, -- I - Insert U Update  B both
        p_list_header_id NUMBER,
        p_item_code      VARCHAR2,
        p_pl_end_date    VARCHAR2,
        p_close_exclude  VARCHAR2,
        p_send_log_to    VARCHAR2,
        p_effective_date varchar2,
        p_simulation_id  number);  -- CHG0045880 new parameter

  /*PROCEDURE update_item_price(p_err_code          OUT NUMBER,
          p_err_message       OUT VARCHAR2,
          p_list_header_id    NUMBER,
          p_list_line_id      NUMBER,
          p_inventory_item_id NUMBER,
          p_new_price         NUMBER,
          p_end_date_active   DATE DEFAULT SYSDATE,
          p_correction_mode   VARCHAR2,
          p_effective_date    VARCHAR2,
          p_primary_uom_flag  VARCHAR2,
          p_uom_code          VARCHAR2,
          p_precedence        number,
          x_list_line_id      OUT NUMBER);*/

  PROCEDURE check_simulation_done(errbuf           OUT VARCHAR2,
              retcode          OUT VARCHAR2,
              p_source         VARCHAR2,
              p_list_header_id NUMBER,
              p_item_code      VARCHAR2);

  --------------------------------------------------------------------
  --  Name      :        handle_audit_insert
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     04/12/2017
  --------------------------------------------------------------------
  --  Purpose :          CHG0040166 - This procedure will be used to
  --                     insert audit information into custom audit table
  --                     for every change in record of the setup tables
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  04/12/2017    Diptasurjya Chatterjee       Initial Build
  --------------------------------------------------------------------
  procedure handle_audit_insert(p_table_name IN varchar2,
                                p_id IN number);

  --------------------------------------------------------------------
  --  Name      :        upload_exclusions_pivot
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     04/12/2017
  --------------------------------------------------------------------
  --  Purpose :          CHG0040166 - This procedure will be used to
  --                     upload pricelist upload exclusions from a flat file
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  04/12/2017    Diptasurjya Chatterjee       Initial Build
  --------------------------------------------------------------------
  PROCEDURE upload_exclusions_pivot(errbuf           OUT VARCHAR2,
                              retcode          OUT VARCHAR2,
                              p_directory      IN VARCHAR2,
                              p_file_name      IN VARCHAR2);

  --------------------------------------------------------------------------------------------
  -- Object Name:  get_notification_body
  -- Type       :  Procedure
  -- Create By  :  Diptasurjya Chatterjee
  -- Creation Date: 18-Jul-2019
  -- Purpose    :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  PROCEDURE get_notification_body(document_id   IN VARCHAR2,
		          display_type  IN VARCHAR2,
		          document      IN OUT NOCOPY CLOB,
		          document_type IN OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------------------------------
  -- Object Name   : get_approver
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  PROCEDURE get_approver(x_err_code        OUT NUMBER,
		 x_err_message     OUT VARCHAR2,
		 p_doc_instance_id IN NUMBER,
		 p_entity          IN VARCHAR2,
		 x_role_name       OUT VARCHAR2);

  --------------------------------------------------------------------------------------------
  -- Object Name   : mail_simulation_error
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  procedure mail_simulation_error(errbuf OUT varchar2,
                                  retcode OUT number,
                                  p_simulation_id IN number);

   --------------------------------------------------------------------------------------------
  -- Object Name   : initiate_approval
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  PROCEDURE initiate_approval(errbuf        OUT VARCHAR2,
		      retcode       OUT NUMBER,
		      p_simulation_id NUMBER);

  --------------------------------------------------------------------------------------------
  -- Object Name   : submit_not_attch_report
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  PROCEDURE submit_not_attch_report(p_doc_instance_id IN NUMBER,
		  p_err_code        OUT NUMBER,
		  p_err_message     OUT VARCHAR2);


  --------------------------------------------------------------------------------------------
  -- Object Name   : get_notification_attachment
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  PROCEDURE get_notification_attachment(document_id   IN VARCHAR2,
			    display_type  IN VARCHAR2,
			    document      IN OUT BLOB,
			    document_type IN OUT VARCHAR2);


  --------------------------------------------------------------------------------------------
  -- Object Name   : abort_approval
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  procedure abort_approval(errbuf OUT varchar2,
                           retcode OUT number,
                           p_simulation_id IN number);

  --------------------------------------------------------------------------------------------
  -- Object Name   : post_wf_action
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  procedure post_wf_action(p_doc_instance_id IN number,
                           p_action IN varchar2,
                           errbuf OUT varchar2,
                           retcode OUT number);

  -------------------------------------------------
  -- get_master_uom
  -------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05/24/2017    Diptasurjya     CHG0040166 : get the primary_uom in
  --                      Chatterjee      master price list for a given rule ID
  --                                      and active price line
  --  1.1   01/23/2020    Diptasurjya     CHG0047324 - master PL ID will be passed as parameter
  --                                      Do not derive from Rule Header as rule header might have changed
  --                                      between simulation and upload
  -------------------------------------------------

  FUNCTION get_master_uom(--p_rule_id           NUMBER,  -- CHG0047324 comment
                          p_master_list_header_id NUMBER,  -- CHG0047324 add
                          p_inventory_item_id NUMBER)
    RETURN VARCHAR2;

  -------------------------------------------------
  -- get_master_prim_uom
  -------------------------------------------------
  --  ver   date          name            desc
  --  1.0   05/24/2017    Diptasurjya     CHG0040166 : get the primary_uom_flag in
  --                      Chatterjee      master price list for a given rule ID
  --                                      and active price line
  --  1.1   01/23/2020    Diptasurjya     CHG0047324 - master PL ID will be passed as parameter
  --                                      Do not derive from Rule Header as rule header might have changed
  --                                      between simulation and upload
  -------------------------------------------------

  FUNCTION get_master_prim_uom(--p_rule_id           NUMBER,  -- CHG0047324 comment
                               p_master_list_header_id NUMBER,  -- CHG0047324 add
                               p_inventory_item_id NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------------------------------
  -- Object Name   : simulation_expiration
  -- Type          : Procedure
  -- Create By     : Diptasurjya Chatterjee
  -- Creation Date : 18-Jul-2019
  -- Purpose       :
  --------------------------------------------------------------------------------------------
  --  Ver    Date         Name              Change Desc
  --------------------------------------------------------------------------------------------
  --  1.0    18-Jul-2019  Diptasurjya       CHG0045880 - PL WF Approval - Initial Build
  --------------------------------------------------------------------------------------------
  procedure simulation_expiration(errbuf OUT varchar2,
                           retcode OUT number);
END xxqp_utils_pkg;
/
