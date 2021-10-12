CREATE OR REPLACE PACKAGE BODY xxom_upgrade_assist_pkg IS

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
  --  1.3   21.11.17      yuval tal       CHG0041884 add get_rule_advisor_tab
  -----------------------------------------------------------------------
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
               p_err_msg    OUT VARCHAR2) IS
    l_user_id NUMBER;

  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
    l_user_id  := fnd_profile.value('USER_ID');

    INSERT INTO xxom_upgrade_assist
      (upgrade_id,
       upgrade_type,
       serial_number,
       instance_id,
       assist_result,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       assist_param)
    VALUES
      (p_upg_assist.upgrade_id,
       p_upg_assist.upgrade_type,
       p_upg_assist.serial_number,
       p_upg_assist.instance_id,
       p_upg_assist.assist_result,
       SYSDATE,
       l_user_id,
       SYSDATE,
       l_user_id,
       p_upg_assist.assist_param);
    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'GEN EXC - ins_upgrade_assist_tbl - ' ||
          substr(SQLERRM, 1, 240);
  END ins_upgrade_assist_tbl;

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
       p_error_desc OUT VARCHAR2) IS

  BEGIN
    -- :1 = p_upgrade_id :2 = p_serial_number

    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by)
    VALUES
      (1,
       'Validate 1gb memory for C500 upgrade',
       'SELECT ''Y''' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b ib ' ||
       ' WHERE ug.inventory_item_id = 226010 ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = ib.inventory_item_id ' ||
       ' AND cii.instance_id = :2 ' || ' AND ib.inventory_item_id = 19037 ' ||
       ' AND ib.organization_id = 91 ' || ' AND cii.attribute2 = ''Y''  ' ||
       ' AND :3 <> ''DD'' ' || ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG1',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by) -- :1 = p_upgrade_id :2 = p_serial_number
    VALUES
      (2,
       'Validate HASP item existance',
       'SELECT ''Y'' ' || ' FROM csi_item_instances cii ' ||
       ' WHERE :1 > 0 ' || ' AND   cii.instance_id = :2 ' ||
       ' AND NOT EXISTS (SELECT 1 ' ||
       ' FROM csi_ii_relationships cir, csi_item_instances child, mtl_system_items_b msib ' ||
       ' WHERE msib.inventory_item_id = child.inventory_item_id ' ||
       ' AND msib.organization_id = 91 ' ||
       ' AND msib.segment1 LIKE ''CMP%'' ' ||
       ' AND cir.subject_id = child.instance_id ' ||
       ' AND cir.object_id = cii.instance_id ' ||
       ' AND child.serial_number IS NOT NULL ' ||
       ' AND cir.active_end_date IS NULL)' || ' AND :3 <> ''DD'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG2',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by) -- :1 = p_upgrade_id :2 = p_serial_number
    VALUES
      (3,
       'Optimax verification for E500V S/N BETWEEN ''5155'' AND ''5221''',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b ib ' ||
       ' WHERE ug.inventory_item_id IN (226002) ' ||
       ' AND lpad(cii.serial_number,4) BETWEEN ''5155'' AND ''5221'' ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = ib.inventory_item_id ' ||
       ' AND cii.instance_id = :2 ' ||
       ' AND ib.inventory_item_id IN (18905, 18906) ' ||
       ' AND ib.organization_id = 91 ' ||
       ' AND NOT EXISTS (SELECT 1 FROM csi_iea_values civ ' ||
       ' WHERE civ.attribute_id = 10000 ' ||
       ' AND civ.instance_id = cii.instance_id ' ||
       ' AND civ.attribute_value IS NOT NULL)' || ' AND :3 <> ''DD'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG3',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by) -- :1 = p_upgrade_id :2 = p_serial_number
    VALUES
      (4,
       'Optimax verification for E500V S/N BETWEEN ''5050'' AND ''5154''',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b ib ' ||
       ' WHERE ug.inventory_item_id IN (226002) ' ||
       ' AND lpad(cii.serial_number,4) BETWEEN ''5050'' AND ''5154'' ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = ib.inventory_item_id ' ||
       ' AND cii.instance_id = :2 ' ||
       ' AND ib.inventory_item_id IN (18905, 18906) ' ||
       ' AND ib.organization_id = 91 ' ||
       ' AND NOT EXISTS (SELECT 1 FROM csi_iea_values civ ' ||
       'WHERE civ.attribute_id = 10000 ' ||
       'AND civ.instance_id = cii.instance_id ' ||
       'AND civ.attribute_value IS NOT NULL)' || ' AND :3 <> ''DD'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG4',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by) -- :1 = p_upgrade_id :2 = p_serial_number
    VALUES
      (5,
       'Optimax verification for E500V S/N BETWEEN ''5001'' AND ''5049'' ',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b ib ' ||
       ' WHERE ug.inventory_item_id IN (226002) ' ||
       ' AND lpad(cii.serial_number,4) BETWEEN ''5001'' AND ''5049'' ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = ib.inventory_item_id ' ||
       ' AND cii.instance_id = :2 ' ||
       ' AND ib.inventory_item_id IN (18905, 18906) ' ||
       ' AND ib.organization_id = 91 ' ||
       ' AND NOT EXISTS (SELECT 1 FROM csi_iea_values civ ' ||
       ' WHERE civ.attribute_id = 10000 ' ||
       ' AND civ.instance_id = cii.instance_id ' ||
       ' AND civ.attribute_value IS NOT NULL)' || ' AND :3 <> ''DD'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG5',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by) -- :1 = p_upgrade_id :2 = p_serial_number
    VALUES
      (6,
       'Optimax verification for E350V -- S/N 3593 BETWEEN ''3593'' AND ''3656'' ',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b ib ' ||
       ' WHERE ug.inventory_item_id = 226015 ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND ug.organization_id = 91 ' ||
       ' AND lpad(cii.serial_number,4) BETWEEN ''3593'' AND ''3656'' ' ||
       ' AND cii.inventory_item_id = ib.inventory_item_id ' ||
       ' AND cii.instance_id = :2 ' ||
       ' AND ib.inventory_item_id IN (19026, 19027) ' ||
       ' AND ib.organization_id = 91 ' ||
       ' AND NOT EXISTS (SELECT 1 FROM csi_iea_values civ ' ||
       ' WHERE civ.attribute_id = 10000 ' ||
       ' AND civ.instance_id = cii.instance_id ' ||
       ' AND civ.attribute_value IS NOT NULL)' || ' AND :3 <> ''DD'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG6',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by) -- :1 = p_upgrade_id :2 = p_serial_number
    VALUES
      (7,
       'Optimax verification for E350V -- S/N ''3592'' and down ',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b ib ' ||
       ' WHERE ug.inventory_item_id = 226015 ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND ug.organization_id = 91 ' ||
       ' AND lpad(cii.serial_number,4) < ''3593'' ' ||
       ' AND cii.inventory_item_id = ib.inventory_item_id ' ||
       ' AND cii.instance_id = :2 ' ||
       ' AND ib.inventory_item_id IN (19026, 19027) ' ||
       ' AND ib.organization_id = 91 ' ||
       ' AND NOT EXISTS (SELECT 1 FROM csi_iea_values civ ' ||
       ' WHERE civ.attribute_id = 10000 ' ||
       ' AND civ.instance_id = cii.instance_id ' ||
       ' AND civ.attribute_value IS NOT NULL)' || ' AND :3 <> ''DD'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG7',
       SYSDATE,
       2470,
       SYSDATE,
       2470);

    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by)
    VALUES
      (8,
       'OBJ-13080 - E500v to Objet500 Connex U SW Version 50.3.0.6268 S/N > 99999',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b msib ' ||
       ' WHERE ug.inventory_item_id = 390002 ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND cii.instance_id = :2 ' ||
       ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = msib.inventory_item_id ' ||
       ' AND cii.serial_number > ''99999'' ' ||
       ' AND msib.inventory_item_id = 18905 ' ||
       ' AND msib.organization_id = 91 ' || ' AND :3 = ''50.3.0.6268'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG8',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by)
    VALUES
      (9,
       'OBJ-13080 - E500v to Objet500 Connex U SW Version 50.3.0.6268 S/N < 99999',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b msib ' ||
       ' WHERE ug.inventory_item_id = 390002 ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND cii.instance_id = :2 ' ||
       ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = msib.inventory_item_id ' ||
       ' AND cii.serial_number < ''99999'' ' ||
       ' AND msib.inventory_item_id = 18905 ' ||
       ' AND msib.organization_id = 91 ' || ' AND :3  = ''50.3.0.6268'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG9',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by)
    VALUES
      (10,
       'OBJ-13080 - E500v to Objet500 Connex U SW Version 50.0.1.14',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b msib ' ||
       ' WHERE ug.inventory_item_id = 390002 ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND cii.instance_id = :2 ' ||
       ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = msib.inventory_item_id ' ||
       ' AND cii.serial_number < ''99999'' ' ||
       ' AND msib.inventory_item_id = 18905 ' ||
       ' AND msib.organization_id = 91 ' || ' AND :3  = ''50.0.1.14'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG10',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by)
    VALUES
      (11,
       'OBJ-13080 - E500v to Objet500 Connex U SW Version 50.0.0.1',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b msib ' ||
       ' WHERE ug.inventory_item_id = 390002 ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND cii.instance_id = :2 ' ||
       ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = msib.inventory_item_id ' ||
       ' AND cii.serial_number < ''99999'' ' ||
       ' AND msib.inventory_item_id = 18905 ' ||
       ' AND msib.organization_id = 91 ' || ' AND :3  = ''50.0.0.1'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG11',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by)
    VALUES
      (12,
       'OBJ-13580 - E350v to Objet350 Connex U SW Version 36.3.0.6693 S/N > 99999',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b msib ' ||
       ' WHERE ug.inventory_item_id = 390002 ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND cii.instance_id = :2 ' ||
       ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = msib.inventory_item_id ' ||
       ' AND cii.serial_number > ''99999'' ' ||
       ' AND msib.inventory_item_id = 19026 ' ||
       ' AND msib.organization_id = 91 ' || ' AND :3 = ''36.3.0.6693'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG12',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by)
    VALUES
      (13,
       'OBJ-13580 - E350v to Objet350 Connex U SW Version 36.3.0.6693 S/N > 99999',
       ' SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b msib ' ||
       ' WHERE ug.inventory_item_id = 390002 ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND cii.instance_id = :2 ' ||
       ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = msib.inventory_item_id ' ||
       ' AND cii.serial_number < ''99999'' ' ||
       ' AND msib.inventory_item_id = 19026 ' ||
       ' AND msib.organization_id = 91 ' || ' AND :3 = ''36.3.0.6693'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG13',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by)
    VALUES
      (14,
       'OBJ-13580 - E350v to Objet350 Connex U SW Version 36.0.1.14',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b msib ' ||
       ' WHERE ug.inventory_item_id = 390002 ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND cii.instance_id = :2 ' ||
       ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = msib.inventory_item_id ' ||
       ' AND cii.serial_number < ''99999'' ' ||
       ' AND msib.inventory_item_id = 19026 ' ||
       ' AND msib.organization_id = 91 ' || ' AND :3 = ''36.0.1.14'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG14',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by)
    VALUES
      (15,
       'OBJ-13580 - E350v to Objet350 Connex U SW Version 36.0.0.1',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b msib ' ||
       ' WHERE ug.inventory_item_id = 390002 ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND cii.instance_id = :2 ' ||
       ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = msib.inventory_item_id ' ||
       ' AND cii.serial_number < ''99999'' ' ||
       ' AND msib.inventory_item_id = 19026 ' ||
       ' AND msib.organization_id = 91 ' || ' AND :3 = ''36.0.0.1'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG15',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by)
    VALUES
      (16,
       'OBJ-33070 - E260v to Objet260Connex U Upgrade',
       'SELECT ''Y'' ' ||
       ' FROM mtl_system_items_b ug, csi_item_instances cii, mtl_system_items_b msib ' ||
       ' WHERE ug.inventory_item_id = 390002 ' ||
       ' AND ug.inventory_item_id = :1 ' || ' AND cii.instance_id = :2 ' ||
       ' AND ug.organization_id = 91 ' ||
       ' AND cii.inventory_item_id = msib.inventory_item_id ' ||
       ' AND cii.serial_number < ''99999'' ' ||
       ' AND msib.inventory_item_id = 19062 ' ||
       ' AND msib.organization_id = 91 ' || ' AND :3 <> ''DD'' ' ||
       ' AND :4 > 0 ' || ' AND :5 > 0 ',
       'XXOM_UPGRADE_ASSIST_MSG16',
       SYSDATE,
       2470,
       SYSDATE,
       2470);
    --------------------------------------------

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_desc := 'insert_upg_rule_tbl - ' || substr(SQLERRM, 1, 240);
  END init_insert_upg_rule_tbl;

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
  PROCEDURE check_init_insert IS

    CURSOR c IS
      SELECT r.upg_rule_id,
   r.rule_sql,
   r.message_name
      FROM   xxom_upgrade_rules r;
    l_temp VARCHAR2(10);
  BEGIN

    FOR r IN c LOOP
      IF r.upg_rule_id = 1 THEN
        EXECUTE IMMEDIATE r.rule_sql
          INTO l_temp
          USING 226010, 10853, 1, 1, 1;
        dbms_output.put_line('l_temp 1 ' || l_temp);
      ELSIF r.upg_rule_id = 2 THEN
        EXECUTE IMMEDIATE r.rule_sql
          INTO l_temp
          USING 1, 10520, 1, 1, 1;
        dbms_output.put_line('l_temp 2 ' || l_temp);
      ELSIF r.upg_rule_id = 3 THEN
        EXECUTE IMMEDIATE r.rule_sql
          INTO l_temp
          USING 226002, 10655, 1, 1, 1;
        dbms_output.put_line('l_temp 3 ' || l_temp);
      ELSIF r.upg_rule_id = 4 THEN
        EXECUTE IMMEDIATE r.rule_sql
          INTO l_temp
          USING 226002, 10849, 1, 1, 1;
        dbms_output.put_line('l_temp 4 ' || l_temp);
      ELSIF r.upg_rule_id = 5 THEN
        EXECUTE IMMEDIATE r.rule_sql
          INTO l_temp
          USING 226002, 10861, 1, 1, 1;
        dbms_output.put_line('l_temp 5 ' || l_temp);
      ELSIF r.upg_rule_id = 6 THEN
        EXECUTE IMMEDIATE r.rule_sql
          INTO l_temp
          USING 226015, 10643, 1, 1, 1;
        dbms_output.put_line('l_temp 6 ' || l_temp);
      ELSIF r.upg_rule_id = 7 THEN
        EXECUTE IMMEDIATE r.rule_sql
          INTO l_temp
          USING 226015, 10860, 1, 1, 1;
        dbms_output.put_line('l_temp 7 ' || l_temp);
      END IF;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('EXCEPTION ' || substr(SQLERRM, 1, 240));
      dbms_output.put_line('l_temp ' || l_temp);
  END check_init_insert;

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
            p_message_name IN VARCHAR2) IS
    l_upg_rule_id NUMBER;
    l_user_id     NUMBER;
  BEGIN
    BEGIN
      SELECT MAX(upg_rule_id) + 1
      INTO   l_upg_rule_id
      FROM   xxom_upgrade_rules;
    END;

    l_user_id := fnd_profile.value('USER_ID');
    -- in p_rule_sql -> :1 = p_upgrade_id :2 = p_serial_number :3,:4,:5 are future vars
    INSERT INTO xxom_upgrade_rules
      (upg_rule_id,
       rule_name,
       rule_sql,
       message_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by)
    VALUES
      (l_upg_rule_id,
       p_rule_name,
       p_rule_sql,
       p_message_name,
       SYSDATE,
       l_user_id,
       SYSDATE,
       l_user_id);

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'insert_upg_rule_tbl - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END insert_upg_rule_tbl;

  --------------------------------------------------------------------
  --  customization code: CUST415
  --  name:               get_upgrade_assist
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.1
  --  creation date:      26/04/2011
  --  Purpose :           get upgarde assistance string by upgrade id and
  --                      serial number
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/04/2011    Dalit A. Raviv  initial build
  --  1.1   18/05/2011    Roman           Added validations
  --  1.2   24/05/2011    Roman           modified Optimax validation
  -----------------------------------------------------------------------
  PROCEDURE get_upgrade_assist(p_upgrade_id    IN NUMBER,
           p_serial_number IN VARCHAR2,
           p_upg_assist    OUT VARCHAR2,
           p_err_code      OUT VARCHAR2,
           p_err_msg       OUT VARCHAR2) IS

    CURSOR get_upg_assist_c IS
    -- 1. Validate 1gb memory for C500 upgrade
      SELECT --'* Item CMP-00048-S (MEMORY,  1GB, 400Mhz) should be added to the Sales Order - FOC' advise
       msg.message_text advise
      FROM   mtl_system_items_b ug,
   csi_item_instances cii,
   mtl_system_items_b ib,
   fnd_new_messages   msg
      WHERE  ug.inventory_item_id = 226010
      AND    ug.inventory_item_id = p_upgrade_id -- &ug_param
      AND    ug.organization_id = 91
      AND    cii.inventory_item_id = ib.inventory_item_id
      AND    cii.serial_number = p_serial_number -- &sn_param --'50056'
      AND    ib.inventory_item_id = 19037 -- constant connex500
      AND    ib.organization_id = 91
      AND    cii.attribute2 = 'Y'
      AND    msg.message_name = 'XXOM_UPGRADE_ASSIST_MSG1'
      AND    msg.application_id = 20003
      UNION
      -- 2. Validate HASP item existance
      SELECT --'* Item MSC-01023 (HASP DONGLE) should be added to the Sales Order - FOC' advise
       msg.message_text advise
      FROM   csi_item_instances cii,
   fnd_new_messages   msg
      WHERE  cii.serial_number = p_serial_number -- &sn_param --'50056'
      AND    NOT EXISTS
       (SELECT 1
    FROM   csi_ii_relationships cir,
           csi_item_instances   child,
           mtl_system_items_b   msib
    WHERE  msib.inventory_item_id = child.inventory_item_id
    AND    msib.organization_id = 91
    AND    msib.segment1 LIKE 'CMP%'
    AND    cir.subject_id = child.instance_id
    AND    cir.object_id = cii.instance_id
    AND    child.serial_number IS NOT NULL
    AND    cir.active_end_date IS NULL)
      AND    msg.message_name = 'XXOM_UPGRADE_ASSIST_MSG2'
      AND    msg.application_id = 20003
      UNION
      --3. Optimax verification for E500V S/N BETWEEN '5155' AND '5221'
      SELECT --'* Please verify with customer/dealer that the printer software version is 50.0.0.1. If so, add item KIT-03020-S (KIT, Optimax READY UPGRADE) to the Sales Order ?FOC' advise
       msg.message_text advise
      FROM   mtl_system_items_b ug,
   csi_item_instances cii,
   mtl_system_items_b ib,
   fnd_new_messages   msg
      WHERE  ug.inventory_item_id IN (226002)
      AND    lpad(cii.serial_number, 4) BETWEEN '5155' AND '5221'
      AND    ug.inventory_item_id = p_upgrade_id -- &ug_param
      AND    ug.organization_id = 91
      AND    cii.inventory_item_id = ib.inventory_item_id
      AND    cii.serial_number = p_serial_number -- &sn_param -- '50056'
      AND    ib.inventory_item_id IN (18905, 18906) -- constant eden500v
      AND    ib.organization_id = 91
      AND    NOT EXISTS (SELECT 1
    FROM   csi_iea_values civ
    WHERE  civ.attribute_id = 10000
    AND    civ.instance_id = cii.instance_id
    AND    civ.attribute_value IS NOT NULL)
      AND    msg.message_name = 'XXOM_UPGRADE_ASSIST_MSG3'
      AND    msg.application_id = 20003
      UNION
      --4. Optimax verification for E500V S/N BETWEEN '5050' AND '5154'
      SELECT --'* Please verify with customer/dealer that the printer software version is 50.0.0.1. If so, add item KIT-03025-S (KIT, Optimax READY UPGRADE) to the Sales Order ?FOC' advise
       msg.message_text advise
      FROM   mtl_system_items_b ug,
   csi_item_instances cii,
   mtl_system_items_b ib,
   fnd_new_messages   msg
      WHERE  ug.inventory_item_id IN (226002)
      AND    lpad(cii.serial_number, 4) BETWEEN '5050' AND '5154'
      AND    ug.inventory_item_id = p_upgrade_id -- &ug_param
      AND    ug.organization_id = 91
      AND    cii.inventory_item_id = ib.inventory_item_id
      AND    cii.serial_number = p_serial_number -- &sn_param -- '50056'
      AND    ib.inventory_item_id IN (18905, 18906) -- constant eden500v
      AND    ib.organization_id = 91
      AND    NOT EXISTS (SELECT 1
    FROM   csi_iea_values civ
    WHERE  civ.attribute_id = 10000
    AND    civ.instance_id = cii.instance_id
    AND    civ.attribute_value IS NOT NULL)
      AND    msg.message_name = 'XXOM_UPGRADE_ASSIST_MSG4'
      AND    msg.application_id = 20003
      UNION
      --5. Optimax verification for E500V S/N BETWEEN '5001' AND '5049'
      SELECT --'* Please verify with customer/dealer that the printer software version is 50.0.0.1. If so, add item KIT-03025-S (KIT, Optimax READY UPGRADE) to the Sales Order ?FOC' advise
       msg.message_text advise
      FROM   mtl_system_items_b ug,
   csi_item_instances cii,
   mtl_system_items_b ib,
   fnd_new_messages   msg
      WHERE  ug.inventory_item_id IN (226002)
      AND    lpad(cii.serial_number, 4) BETWEEN '5001' AND '5049'
      AND    ug.inventory_item_id = p_upgrade_id -- &ug_param
      AND    ug.organization_id = 91
      AND    cii.inventory_item_id = ib.inventory_item_id
      AND    cii.serial_number = p_serial_number -- &sn_param -- '50056'
      AND    ib.inventory_item_id IN (18905, 18906) -- constant eden500v
      AND    ib.organization_id = 91
      AND    NOT EXISTS (SELECT 1
    FROM   csi_iea_values civ
    WHERE  civ.attribute_id = 10000
    AND    civ.instance_id = cii.instance_id
    AND    civ.attribute_value IS NOT NULL)
      AND    msg.message_name = 'XXOM_UPGRADE_ASSIST_MSG5'
      AND    msg.application_id = 20003
      UNION
      --6. Optimax verification for E350V -- S/N 3593 BETWEEN '3593' AND '3656'
      SELECT --'* Please verify with customer/dealer that the printer software version is 36.0.0.1. If so, add item KIT-03020-S (KIT, Optimax READY UPGRADE) to the Sales Order ?FOC' advise
       msg.message_text advise
      FROM   mtl_system_items_b ug,
   csi_item_instances cii,
   mtl_system_items_b ib,
   fnd_new_messages   msg
      WHERE  ug.inventory_item_id = 226015
      AND    ug.inventory_item_id = p_upgrade_id -- &ug_param
      AND    ug.organization_id = 91
      AND    lpad(cii.serial_number, 4) BETWEEN '3593' AND '3656'
      AND    cii.inventory_item_id = ib.inventory_item_id
      AND    cii.serial_number = p_serial_number -- &sn_param --'50056'
      AND    ib.inventory_item_id IN (19026, 19027) -- constant eden350v
      AND    ib.organization_id = 91
      AND    NOT EXISTS (SELECT 1
    FROM   csi_iea_values civ
    WHERE  civ.attribute_id = 10000
    AND    civ.instance_id = cii.instance_id
    AND    civ.attribute_value IS NOT NULL)
      AND    msg.message_name = 'XXOM_UPGRADE_ASSIST_MSG6'
      AND    msg.application_id = 20003
      UNION
      --7. Optimax verification for E350V -- S/N 3592 and down
      SELECT --'* Please verify with customer/dealer that the printer software version is 36.0.0.1. If so, add item KIT-03025-S (KIT, Optimax READY UPGRADE) to the Sales Order ?FOC' advise
       msg.message_text advise
      FROM   mtl_system_items_b ug,
   csi_item_instances cii,
   mtl_system_items_b ib,
   fnd_new_messages   msg
      WHERE  ug.inventory_item_id = 226015
      AND    ug.inventory_item_id = p_upgrade_id -- &ug_param
      AND    ug.organization_id = 91
      AND    lpad(cii.serial_number, 4) < '3593'
      AND    cii.inventory_item_id = ib.inventory_item_id
      AND    cii.serial_number = p_serial_number -- &sn_param --'50056'
      AND    ib.inventory_item_id IN (19026, 19027) -- constant eden350v
      AND    ib.organization_id = 91
      AND    NOT EXISTS (SELECT 1
    FROM   csi_iea_values civ
    WHERE  civ.attribute_id = 10000
    AND    civ.instance_id = cii.instance_id
    AND    civ.attribute_value IS NOT NULL)
      AND    msg.message_name = 'XXOM_UPGRADE_ASSIST_MSG7'
      AND    msg.application_id = 20003;

    l_upg_assist VARCHAR2(2000);
    l_count      NUMBER;

  BEGIN
    p_err_code   := 0;
    p_err_msg    := NULL;
    l_upg_assist := NULL;
    l_count      := 1;
    FOR get_upg_assist_r IN get_upg_assist_c LOOP
      IF l_upg_assist IS NULL THEN
        l_upg_assist := l_count || '. ' || get_upg_assist_r.advise ||
    chr(10) || chr(10);
      ELSE
        l_upg_assist := l_upg_assist || l_count || '. ' ||
    get_upg_assist_r.advise || chr(10) || chr(10);
      END IF;
      l_count := l_count + 1;
    END LOOP;

    IF l_upg_assist IS NULL THEN
      fnd_message.set_name('XXOBJT', 'XXOM_UPGRAD_NO_ASSIST');
      l_upg_assist := fnd_message.get;
    END IF;

    p_upg_assist := l_upg_assist;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'GEN EXC - get_upgrade_assist - ' ||
          substr(SQLERRM, 1, 240);
  END get_upgrade_assist;

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
       p_err_msg       OUT VARCHAR2) IS

    CURSOR get_upgrade_rules_c IS
      SELECT *
      FROM   xxom_upgrade_rules;

    l_upg_kit_id  NUMBER := NULL;
    l_instance_id VARCHAR2(30) := NULL;
    --l_upg_type        varchar2(150)  := null;
    l_serial_number  VARCHAR2(150) := NULL;
    l_temp3          VARCHAR2(150) := NULL;
    l_temp4          VARCHAR2(150) := NULL;
    l_temp5          VARCHAR2(150) := NULL;
    l_sql_value      VARCHAR2(10) := NULL;
    l_assist_msg     VARCHAR2(2500) := NULL;
    l_message        VARCHAR2(2500) := NULL;
    l_count          NUMBER := 0;
    l_upg_assist_rec xxom_upgrade_assist_pkg.t_upg_assist_rec;
    l_err_code       VARCHAR2(150) := NULL;
    l_err_msg        VARCHAR2(500) := NULL;
    l_upgrade_id     NUMBER := NULL;
    l_assist_params  VARCHAR2(2500) := NULL;

  BEGIN
    /* p_upg_param_tbl structure
    PARAMETER_NAME      varchar2(240),-- upgrade          serial
    PARAMETER_VALUE     varchar2(240),-- upgrade_type     serial_number
    PARAMETER_ID        number,       -- upgrade_id       instance_id
    PARAMETER_CODE      varchar2      -- A                B
    */
    -- Get parameters values
    l_upg_kit_id  := NULL;
    l_instance_id := NULL;
    l_sql_value   := NULL;
    --l_upg_type      := null;
    l_serial_number := NULL;
    FOR i IN p_upg_param_tbl.first .. p_upg_param_tbl.last LOOP
      -- in the future l_temp3 can be null in this case when i will enter code
      -- for case C i need to ask if parameter is null then l_temp3 := 1;
      -- at the dinamic select i must send value greter then 0.
      l_temp3 := 'RR';
      l_temp4 := 1;
      l_temp5 := 1;

      -- at this part if there is a new parameter code i need to enter case code
      IF p_upg_param_tbl(i).parameter_code = 'A' THEN
        l_upg_kit_id := p_upg_param_tbl(i).parameter_id;
        --l_upg_type     := p_upg_param_tbl(i).PARAMETER_VALUE;
      END IF;
      IF p_upg_param_tbl(i).parameter_code = 'B' THEN
        -- instance_id that connect to a serial
        l_instance_id   := p_upg_param_tbl(i).parameter_id;
        l_serial_number := p_upg_param_tbl(i).parameter_value;
      END IF;

      IF p_upg_param_tbl(i).parameter_code = 'C' THEN
        -- instance_id that connect to a serial
        l_temp3 := p_upg_param_tbl(i).parameter_value;
      END IF;

      IF l_assist_params IS NULL THEN
        l_assist_params := p_upg_param_tbl(i)
       .parameter_code || ': ' || 'Name: ' || p_upg_param_tbl(i)
       .parameter_name || ', ' || 'Value: ' || p_upg_param_tbl(i)
       .parameter_value || ', ' || 'Id: ' || p_upg_param_tbl(i)
       .parameter_id;

      ELSE
        l_assist_params := l_assist_params || chr(10) || p_upg_param_tbl(i)
      .parameter_code || ': ' || 'Name: ' || p_upg_param_tbl(i)
      .parameter_name || ', ' || 'Value: ' || p_upg_param_tbl(i)
      .parameter_value || ', ' || 'Id: ' || p_upg_param_tbl(i)
      .parameter_id;
      END IF;

    END LOOP;
    -- Get assist message
    l_count      := 1;
    l_assist_msg := NULL;

    FOR get_upgrade_rules_r IN get_upgrade_rules_c LOOP
      l_message   := NULL;
      l_sql_value := NULL;
      BEGIN
        EXECUTE IMMEDIATE get_upgrade_rules_r.rule_sql
          INTO l_sql_value
          USING l_upg_kit_id, l_instance_id, l_temp3, l_temp4, l_temp5;
      EXCEPTION
        WHEN OTHERS THEN
          l_sql_value := NULL;
      END;

      IF nvl(l_sql_value, 'N') = 'Y' THEN
        -- get message that attach to the sql exquted
        BEGIN
          SELECT msg.message_text
          INTO   l_message
          FROM   fnd_new_messages msg
          WHERE  msg.message_name = get_upgrade_rules_r.message_name
          AND    application_id = 20003;

          IF l_assist_msg IS NULL THEN
  l_assist_msg := l_count || '. ' || l_message || chr(10) ||
        chr(10);
          ELSE
  l_assist_msg := l_assist_msg || l_count || '. ' || l_message ||
        chr(10) || chr(10);
          END IF;

        EXCEPTION
          WHEN OTHERS THEN
  NULL;
        END;
        --l_assist_msg

        l_count := l_count + 1;
      END IF; -- l_sql_value = Y

    END LOOP;
    -- Parameters found No Additional recommendations.
    IF l_assist_msg IS NULL THEN
      fnd_message.set_name('XXOBJT', 'XXOM_UPGRAD_NO_ASSIST');
      l_assist_msg := fnd_message.get;
    END IF;

    p_upg_assist := l_assist_msg;
    p_err_code   := 0;
    p_err_msg    := NULL;

    -- insert row to log table
    SELECT xxom_upgrade_assist_seq.nextval
    INTO   l_upgrade_id
    FROM   dual;

    l_upg_assist_rec.upgrade_id    := l_upgrade_id; -- n
    l_upg_assist_rec.upgrade_type  := l_upg_kit_id; -- n
    l_upg_assist_rec.serial_number := l_serial_number; -- v
    l_upg_assist_rec.instance_id   := l_instance_id; -- n
    l_upg_assist_rec.assist_result := l_assist_msg; -- v
    l_upg_assist_rec.assist_param  := l_assist_params; -- v

    l_err_code := 0;
    l_err_msg  := NULL;
    xxom_upgrade_assist_pkg.ins_upgrade_assist_tbl(p_upg_assist => l_upg_assist_rec, -- in t_upg_assist_rec
           p_err_code   => l_err_code, -- o v
           p_err_msg    => l_err_msg); -- o  v

    IF l_err_code <> 0 THEN
      p_upg_assist := l_assist_msg || chr(10) || l_err_msg;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_upg_assist := 'General problem to find any assistance - ' ||
            substr(SQLERRM, 1, 240);
      p_err_code   := 1;
      p_err_msg    := substr(SQLERRM, 1, 240);
  END get_upgrade_param_assist;

  --------------------------------------------------------------------
  --  customization code: CR1215
  --  name:               get_rule_advisor
  --  create by:          yuval tal
  ------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06.4.14       yuval tal       CR 1215 : add get_rule_advisor for bpel ws cs_getRuleAdvisor
  --                                      wrap get_upgrade_param_assist

  PROCEDURE get_rule_advisor(p_inventory_item_id NUMBER,
         p_instance_id       NUMBER,
         p_text              VARCHAR2,
         p_ruleadvisor_text  OUT VARCHAR2,
         p_err_code          OUT VARCHAR2,
         p_err_msg           OUT VARCHAR2)

   IS
    --
    l_upg_param_tbl t_upg_param_tbl;

  BEGIN

    -- check required
    IF p_inventory_item_id IS NULL THEN
      p_err_code := 1;
      fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
      fnd_message.set_token('FIELD', 'inventory_item_id');
      p_ruleadvisor_text := fnd_message.get;
      p_err_msg          := p_ruleadvisor_text;
      RETURN;
    END IF;

    IF p_instance_id IS NULL THEN
      p_err_code := 1;
      fnd_message.set_name('XXOBJT', 'XXOM_SF2OA_REQUIRED_HDR_FIELD');
      fnd_message.set_token('FIELD', 'instance_id');
      p_ruleadvisor_text := fnd_message.get;
      p_err_msg          := p_ruleadvisor_text;

      RETURN;
    END IF;

    p_err_code := 0;
    l_upg_param_tbl.delete;
    l_upg_param_tbl(1).parameter_name := 'Upgrade Type Description'; -- v240
    l_upg_param_tbl(1).parameter_value := NULL; --:xxom_upgrade_param_blk.parameter_value; -- v240
    l_upg_param_tbl(1).parameter_id := p_inventory_item_id; -- n
    l_upg_param_tbl(1).parameter_code := 'A'; -- v2450

    l_upg_param_tbl(2).parameter_name := 'Serial Number'; -- v240
    l_upg_param_tbl(2).parameter_value := NULL;
    l_upg_param_tbl(2).parameter_id := p_instance_id; -- n
    l_upg_param_tbl(2).parameter_code := 'B'; -- v2450

    IF p_text IS NOT NULL THEN
      l_upg_param_tbl(3).parameter_name := 'Embedded SW Version'; -- v240
      l_upg_param_tbl(3).parameter_value := p_text; --:xxom_upgrade_param_blk.parameter_value; -- v240
      l_upg_param_tbl(3).parameter_id := NULL; -- n
      l_upg_param_tbl(3).parameter_code := 'C'; -- v2450
    END IF;
    get_upgrade_param_assist(l_upg_param_tbl,
         p_ruleadvisor_text,
         p_err_code,
         p_err_msg);

    IF p_ruleadvisor_text IS NULL THEN
      fnd_message.set_name('XXOBJT', 'XXOM_UPGRAD_NO_ASSIST');
      p_ruleadvisor_text := fnd_message.get;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := SQLERRM;

  END;

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
            p_log_code OUT VARCHAR2) IS

    l_temp VARCHAR2(4000);

  BEGIN
    p_log_msg  := NULL;
    p_log_code := 0;

    EXECUTE IMMEDIATE p_sql_text
      INTO l_temp
      USING p_param1, p_param2, p_param3, p_param4, p_param5;
  EXCEPTION
    WHEN no_data_found THEN
      p_log_msg  := 'NO_DATA_FOUND';
      p_log_code := 0;
    WHEN too_many_rows THEN
      p_log_msg  := 'TOO_MANY_ROWS';
      p_log_code := 0;
    WHEN OTHERS THEN
      p_log_msg  := 'Error: ' || substr(SQLERRM, 1, 240);
      p_log_code := 1;
  END check_sql;

  --------------------------------------------------------------------
  --  customization code: CHG0041884 - Upgrade Advisor
  --  name:               get_rule_advisor - used by soa
  --  create by:          yuval tal
  ------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06.4.14       yuval tal       CHG0041884 - Upgrade Advisor

  PROCEDURE get_rule_advisor_tab(p_advisor_tab IN OUT xxobjt.xxcs_rule_advisor_tab,
             p_err_code    OUT VARCHAR2,
             p_err_msg     OUT VARCHAR2) IS
    l_systems_valid  varchar2(1);
  BEGIN

    p_err_code := 0;

    FOR i IN 1 .. p_advisor_tab.count LOOP

      -- get inventory_item id
      IF p_advisor_tab(i).inventory_item_id IS NULL THEN
        -- get inventory_item id
        IF p_advisor_tab(i).upgrade_product_code IS NOT NULL THEN
          -- get id
          p_advisor_tab(i).inventory_item_id := xxinv_utils_pkg.get_item_id(p_advisor_tab(i)
                .upgrade_product_code);
        ELSE
          p_advisor_tab(i).err_code := 1;
          p_advisor_tab(i).err_msg := 'Upgrade item is missing';
          CONTINUE;
        END IF;
      END IF;

      IF p_advisor_tab(i).inventory_item_id IS NULL THEN

        p_advisor_tab(i).err_code := 1;
        p_advisor_tab(i).err_msg := 'Upgrade item is missing';
        CONTINUE;
      END IF;

      -- get instance id

      IF p_advisor_tab(i).instance_id IS NULL THEN
        BEGIN
          SELECT instance_id
          INTO   p_advisor_tab(i).instance_id

          FROM   csi_item_instances
          WHERE  serial_number = p_advisor_tab(i).system_serial_number
          AND    inventory_item_id =
       xxinv_utils_pkg.get_item_id(p_advisor_tab(i)
                .system_product_code);

        EXCEPTION
          WHEN too_many_rows THEN

  p_advisor_tab(i).err_code := 1;
  p_advisor_tab(i).err_msg := 'more than 1 record return for product and serial';
  CONTINUE;
          WHEN no_data_found THEN

  p_advisor_tab(i).err_code := 1;
  p_advisor_tab(i).err_msg := 'related system not found';
  CONTINUE;
        END;

      END IF;
      
      -- Dipta - Start upgrade serial validation
      if p_advisor_tab(i).inventory_item_id IS NOT NULL
        and p_advisor_tab(i).system_product_code is not null then
        begin
          select 'Y'
            into l_systems_valid
            from fnd_lookup_values_vl flv
           where lookup_type = 'XXCSI_UPGRADE_TYPE'
             and enabled_flag = 'Y'
             and flv.DESCRIPTION = (select segment1
                                      from mtl_system_items_b msib1
                                     where msib1.organization_id = xxinv_utils_pkg.get_master_organization_id
                                       and msib1.inventory_item_id = p_advisor_tab(i).inventory_item_id)
             and flv.ATTRIBUTE1 = (select inventory_item_id
                                     from mtl_system_items_b msib2
                                    where msib2.organization_id = xxinv_utils_pkg.get_master_organization_id
                                      and msib2.segment1 = p_advisor_tab(i).system_product_code)
             and sysdate between nvl(start_date_active, sysdate - 1) and
                 nvl(end_date_active, sysdate + 1);
        exception when no_data_found then
          l_systems_valid := 'N';
        end;

        if l_systems_valid = 'N' then
          p_advisor_tab(i).err_code := 1;
          p_advisor_tab(i).err_msg := 'Upgrade and system product item combination not valid';
          p_advisor_tab(i).rule_advisor_text := 'The Selected Upgrade product cannot be performed on the selected printer. Please revise your selection and try again';
          CONTINUE;
        end if;
      end if;
      -- Dipta end

      get_rule_advisor(p_advisor_tab(i).inventory_item_id,
             p_advisor_tab(i).instance_id,
             p_advisor_tab(i).embedded_name,
             p_advisor_tab(i).rule_advisor_text, -- out
             p_advisor_tab(i).err_code,
             p_advisor_tab(i).err_msg);

    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Error extracting data ' || substr(SQLERRM, 1, 100);
  END;

END xxom_upgrade_assist_pkg;
/
