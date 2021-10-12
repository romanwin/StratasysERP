CREATE OR REPLACE PACKAGE xxom_upgrade_assist_pkg IS

  --------------------------------------------------------------------
  --  customization code: CUST415
  --  name:               CRM - Upgrade Assistance Functionality form
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      12/04/2011 10:26:31 AM
  --  Purpose :
  --  New functionality that will assist users to verify the required
  --  items for upgrade before placing an order for upgrade.
  --
  --  Objet launched a line of various system upgrades that
  --  sold customer. The upgrade components are subject to
  --  IB definitions of existing printers and also additional
  --  rules that eventually determine the required compound of upgrade kit.
  --
  --  Required to create an functionality that will assist users
  --  during placement of a new upgrade order.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/04/2011    Dalit A. Raviv  initial build
  --  1.1   06.4.14       yuval tal       CR 1215 : add get_rule_advisor for bpel ws cs_getRuleAdvisor
  --  1.2   22/12/2014    Dalit A. Raviv  add procedure check_sql
  --  1.3   21.11.17      yuval tal       CHG0041884 - add get_rule_advisor_tab
  -----------------------------------------------------------------------
  TYPE t_upg_assist_rec IS RECORD(
    upgrade_id    NUMBER,
    upgrade_type  NUMBER,
    serial_number VARCHAR2(50),
    instance_id   NUMBER,
    assist_result VARCHAR2(2000),
    assist_param  VARCHAR2(2500) DEFAULT NULL);

  TYPE t_upg_param_rec IS RECORD(
    parameter_name  VARCHAR2(240), -- upgrade          serial
    parameter_value VARCHAR2(240), -- upgrade_type     serial_number
    parameter_id    NUMBER, -- upgrade_id       instance_id
    parameter_code  VARCHAR2(240) -- A                B
    );

  TYPE t_upg_param_tbl IS TABLE OF t_upg_param_rec INDEX BY BINARY_INTEGER;

  --------------------------------------------------------------------
  --  customization code: CUST415
  --  name:               ins_upgrade_assist_tbl
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      12/04/2011
  --  Purpose :           insert row to table xxom_upgrade_assist.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/04/2011    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  PROCEDURE ins_upgrade_assist_tbl(p_upg_assist IN t_upg_assist_rec,
		           p_err_code   OUT VARCHAR2,
		           p_err_msg    OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CUST448 Upgrade In Oracle - Phase2
  --  name:               init_insert_upg_rule_tbl
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      08/09/2011
  --  Purpose :           initiate insert rows to xxom_upgrade_rules table
  --                      this table holds the rules for the selects of upgrade assist.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   08/09/2011    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  PROCEDURE init_insert_upg_rule_tbl(p_error_code OUT VARCHAR2,
			 p_error_desc OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CUST448 Upgrade In Oracle - Phase2
  --  name:               check_init_insert
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      08/09/2011
  --  Purpose :           check that the select exqute corret
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   08/09/2011    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  PROCEDURE check_init_insert;

  --------------------------------------------------------------------
  --  customization code: CUST448 Upgrade In Oracle - Phase2
  --  name:               insert_upg_rule_tbl
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      08/09/2011
  --  Purpose :           Insert rows to xxom_upgrade_rules table
  --                      this table holds the rules for the selects of upgrade assist.
  --                      This procedure give the implementer the ability to handle
  --                      data at xxom_upgrade_rules for new rules
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   08/09/2011    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  PROCEDURE insert_upg_rule_tbl(errbuf         OUT VARCHAR2,
		        retcode        OUT NUMBER,
		        p_rule_name    IN VARCHAR2,
		        p_rule_sql     IN VARCHAR2,
		        p_message_name IN VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CUST415
  --  name:               get_upgrade_assist
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      26/04/2011
  --  Purpose :           get upgarde assistance string by upgrade id and
  --                      serial number
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/04/2011    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  PROCEDURE get_upgrade_assist(p_upgrade_id    IN NUMBER,
		       p_serial_number IN VARCHAR2,
		       p_upg_assist    OUT VARCHAR2,
		       p_err_code      OUT VARCHAR2,
		       p_err_msg       OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CUST448
  --  name:               Upgrade In Oracle - Phase2
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      06/09/2011
  --  Purpose :           get upgarde assistance string by new dinamic logic
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06/09/2011    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  PROCEDURE get_upgrade_param_assist(p_upg_param_tbl t_upg_param_tbl,
			 p_upg_assist    OUT VARCHAR2,
			 p_err_code      OUT VARCHAR2,
			 p_err_msg       OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CR1215
  --  name:               get_rule_advisor
  --  create by:          yuval tal
  ------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06.4.14       yuval tal       CR 1215 : add get_rule_advisor for bpel ws cs_getRuleAdvisor
  PROCEDURE get_rule_advisor(p_inventory_item_id NUMBER,
		     p_instance_id       NUMBER,
		     p_text              VARCHAR2,
		     p_ruleadvisor_text  OUT VARCHAR2,
		     p_err_code          OUT VARCHAR2,
		     p_err_msg           OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            check_sql
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/12/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0034072 - Upgrade rules form
  --                   Call from set up form - check that dynamic sql is valid
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/12/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE check_sql(p_sql_text IN VARCHAR2,
	          p_param1   IN NUMBER,
	          p_param2   IN NUMBER,
	          p_param3   IN VARCHAR2,
	          p_param4   IN NUMBER,
	          p_param5   IN NUMBER,
	          p_log_msg  OUT VARCHAR2,
	          p_log_code OUT VARCHAR2);
  --------------------------------------------------------------------
  --  customization code: CHG0041884 - Upgrade Advisor
  --  name:               get_rule_advisor - used by soa 
  --  create by:          yuval tal
  ------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06.4.14       yuval tal       CHG0041884 - Upgrade Advisor

  PROCEDURE get_rule_advisor_tab(p_advisor_tab IN OUT xxobjt.xxcs_rule_advisor_tab,
		         p_err_code    OUT VARCHAR2,
		         p_err_msg     OUT VARCHAR2);
END xxom_upgrade_assist_pkg;
/
