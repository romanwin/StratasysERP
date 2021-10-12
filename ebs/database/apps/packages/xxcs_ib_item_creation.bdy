create or replace package body xxcs_ib_item_creation IS
  --------------------------------------------------------------------
  --  customization code: CUST016 - IB Item Creation
  --  name:               XXCS_IB_ITEM_CREATION
  --  create by:          XXX
  --  Revision:           1.6
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
  --  1.8   16/01/2012    Dalit A. Raviv  add procedure upd_item_att9
  --  1.9   21/03/2012    Dalit A. Raviv  procedure upd_item_att9 - Support -P items upd_item_att9
  --  1.10  28/03/2012    Dalit A. Raviv  procedure upd_item_att9 - add profile of creation date
  --  1.11  13/11/2013    Vitaly          create_istance proc: CUST695- CR 870  modify view due to changes in view  q_sn_reporting_v
  --                                      HASP_SW_VERSION --- > HASP_ENABLED_FOR_SW_VERSION
  --  1.12  09/04/2014    Adi Safin       CHG0031898 - BugFix - Check if machine produce before 2014 in old SN reporting plan
  --  1.13  10/20/2015    Diptasurjya     CHG0036464 - Add procedure to sync missing IB references with SFDC
  --                      Chatterjee
  --  1.14  09-Nov-2015   Dalit A. Raviv  CHG0036942 handle_log_tbl - Change p_job datatype from number to varchar
  --  1.15  10-APR-2018   Dan M.          CHG0042574 - Sync Salesforce install base data to Oracle install base
  --  1.16  08-Jul-2018   Dan M.          CHG0042574-V2 hotfix - commit/rollback errors
  --  1.17  25-Jul-2018   Dan M.          CHG0042574 CTASK0037631: Add spcific Instance ID Parameter, add attribute17, change site logic for installed/current sites
  --  1.18  02-Sep-2018   Dan M.          CHG0043858 - Add termination date (status change date), correct instance attribute 6/7 formats
  --  1.2   27/01/2019    Roman W.        INC0145202
  --  1.3   17/11/2019    Adi Safin       INC0175066 - INC0175066 - Fix in get_instance_id procedure to get only active relationships IB's
  --  1.4   09/01/2020    Bellona.B       CHG0047219 - Comment IB create instance as suggested by Adi Safin.
  -----------------------------------------------------------------------
  PROCEDURE sf2ora_update_log(p_log_information VARCHAR2,
		      p_log_prefix      VARCHAR2 DEFAULT NULL);
  -- 1.4 16/06/2010 Dalit A. Raviv
  g_user_id      NUMBER := fnd_profile.value('USER_ID');
  g_login_id     NUMBER := nvl(fnd_profile.value('LOGIN_ID'), -1);
  g_message_desc VARCHAR2(2000) := NULL;
  g_run_state    VARCHAR2(255) := 'CONCURRENT';
  TYPE tp_data_rec_type IS RECORD(
    instance_id             NVARCHAR2(4000),
    serial_number           NVARCHAR2(80),
    instance_status_id      NUMBER,
    owner_account_id        NVARCHAR2(1300),
    quantity                NUMBER,
    unit_of_measure         CHAR(2),
    inventory_item_id       NVARCHAR2(255),
    inventory_revision      NVARCHAR2(50),
    attribute12             NVARCHAR2(1300),
    attribute4              NVARCHAR2(255),
    attribute8              NVARCHAR2(4000),
    attribute5              NVARCHAR2(255),
    attribute7              VARCHAR2(255),
    attribute3              VARCHAR2(1),
    attribute17             NVARCHAR2(1300), -- Version 1.2  - CTASK0037631 : Add attribute17 to Sync
    owner_party_account_id  NVARCHAR2(255),
    account_end_customer_id NVARCHAR2(255),
    owner_party_id          NUMBER(15),
    install_date            VARCHAR2(17),
    attribute6              VARCHAR2(255),
    current_site_id         VARCHAR2(4000),
    install_site_id         VARCHAR2(4000),
    bill_to_site_id         VARCHAR2(4000),
    ship_to_site_id         VARCHAR2(4000),
    ship_to_ou_id           VARCHAR2(4000),
    terminate_contracts     VARCHAR2(255),
    status_change_date      DATE -- Dan M, 02-Sep-2018, Version 1.18, CHG0043858 - Add termination date (status change date)
    );

  -- danremove
  /*  TYPE t_account_IDs IS TABLE OF varchar2(4000) INDEX BY BINARY_INTEGER;
    g_accounr_IDs t_account_IDs;
  */ --------------------------------------------------------------------
  --  customization code: CUST016 - IB Item Creation
  --  name:               handle_log_tbl
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      16/06/2010
  --  Purpose :           procedure that handle insert or update to log tbl
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16/06/2010    Dalit A. Raviv  initial build
  --  1.1   09-Nov-2015   Dalit A. Raviv  CHG0036942 Change p_job datatype from number to varchar
  -----------------------------------------------------------------------
  PROCEDURE handle_log_tbl(p_parent_instance_id      IN NUMBER,
		   p_parent_cust1            IN VARCHAR2,
		   p_child_instance_id       IN NUMBER,
		   p_component_item          IN VARCHAR2,
		   p_component_serial_number IN VARCHAR2,
		   p_creation_status         IN VARCHAR2,
		   p_creation_err_msg        IN VARCHAR2,
		   p_relation_staus          IN VARCHAR2,
		   p_relation_err_msg        IN VARCHAR2,
		   p_job                     IN VARCHAR2,
		   p_error_code              OUT NUMBER,
		   p_error_desc              OUT VARCHAR2) IS

    PRAGMA AUTONOMOUS_TRANSACTION;

    l_entity_id NUMBER;
    l_count     NUMBER := 0;
  BEGIN
    -- check if exists row at log tbl
    SELECT COUNT(1)
    INTO   l_count
    FROM   xxcs_ib_item_creation_log log
    WHERE  parent_instance_id = p_parent_instance_id
    AND    child_instance_id = p_child_instance_id
    AND    component_item = p_component_item
    AND    component_serial_number = p_component_serial_number;

    -- if not exists insert
    IF l_count = 0 THEN
      -- get entity id
      SELECT xxcs_ib_item_creation_log_sq.nextval
      INTO   l_entity_id
      FROM   dual;

      INSERT INTO xxcs_ib_item_creation_log
        (entity_id,
         parent_instance_id,
         parent_cust1,
         child_instance_id,
         component_item,
         component_serial_number,
         creation_status,
         creation_err_msg,
         relation_staus,
         relation_err_msg,
         job,
         last_update_date,
         last_updated_by,
         last_update_login,
         creation_date,
         created_by)
      VALUES
        (l_entity_id,
         p_parent_instance_id,
         p_parent_cust1,
         p_child_instance_id,
         p_component_item,
         p_component_serial_number,
         p_creation_status,
         p_creation_err_msg,
         p_relation_staus,
         p_relation_err_msg,
         p_job,
         SYSDATE,
         g_user_id,
         g_login_id,
         SYSDATE,
         g_user_id);
      -- if exists update
    ELSE
      UPDATE xxcs_ib_item_creation_log
      SET    creation_status  = nvl(creation_status, p_creation_status),
	 creation_err_msg = nvl(creation_err_msg, p_creation_err_msg),
	 relation_staus   = nvl(relation_staus, p_relation_staus),
	 relation_err_msg = nvl(relation_err_msg, p_relation_err_msg)
      WHERE  parent_instance_id = p_parent_instance_id
      AND    child_instance_id = p_child_instance_id
      AND    component_item = p_component_item
      AND    component_serial_number = p_component_serial_number;

    END IF;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_desc := 'Procedure handle_log_tbl Failed - ' ||
	          substr(SQLERRM, 1, 200);
  END handle_log_tbl;

  --------------------------------------------------------------------
  --  customization code: CUST345
  --  name:               handle_ext_tbl
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      12/08/2010
  --  Purpose :           procedure that handle update to ext tbl
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/08/2010    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  PROCEDURE handle_ext_tbl(p_message_code IN VARCHAR2,
		   p_message_desc IN VARCHAR2,
		   p_row_id       IN VARCHAR2) IS

    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    UPDATE xxcs_ib_item_creation_ext_tbl ext
    SET    ext.message_code = p_message_code, --'WARNING',
           ext.message_desc = decode(nvl(g_message_desc, 'DD'),
			 'DD',
			 p_message_desc,
			 p_message_desc || ' - ' ||
			 g_message_desc)
    WHERE  ROWID = p_row_id;

    COMMIT;

    g_message_desc := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      dbms_output.put_line('Error Handle ext tbl - ' || SQLERRM);
  END;

  --------------------------------------------------------------------
  --  customization code: CUST016 - IB Item Creation
  --  name:               create_instance
  --  create by:          XXX
  --  Revision:           1.0
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
  --  1.5   02/05/2001    Dalit A. Raviv  change item revision from '0' to item max revision
  --  1.6   11/04/2013    Adi Safin       Change main cursor to support only printers that there is configuration data
  --                                      in the SN reporting.
  --  1.7   13/11/2013    Vitaly          CUST695- CR 870  modify view due to changes in view  q_sn_reporting_v
  --                                      HASP_SW_VERSION --- > HASP_ENABLED_FOR_SW_VERSION
  --  1.8  09/04/2014    Adi Safin        BugFix - Check if machine produce before 2014 in old SN reporting plan
  --  1.9  19/06/2014    Adi Safin        CHG0032521 - Bugfix Polyjet IB Configuration Creation. too many rows error
  --  2.0  14/02/2016    Adi Safin        CHG00XXXX - Fix validtion for compomnents, validate SN and PN and not just SN under IB confiiguration.
  -----------------------------------------------------------------------
  PROCEDURE create_instance(errbuf            OUT VARCHAR2,
		    retcode           OUT VARCHAR2,
		    p_instance_number IN NUMBER DEFAULT NULL,
		    p_item_status     IN VARCHAR2 DEFAULT NULL /*, P_Job_Number In Varchar2 Default Null*/) IS

    CURSOR cr_find_instances IS
    --  1.6   11/04/2013    Adi Safin
      SELECT csi.serial_number,
	 csi.attribute1,
	 csi.inventory_item_id
      FROM   csi_item_instances    csi,
	 xxcs_items_printers_v pr
      WHERE  pr.inventory_item_id = csi.inventory_item_id
      AND    pr.item_type = 'PRINTER'
      AND    (csi.instance_id = p_instance_number OR
	p_instance_number IS NULL) --      vl(p_instance_number, csi.instance_id)
      AND    nvl(csi.attribute1, 'Null') =
	 nvl(p_item_status,
	      decode(csi.attribute1,
		 'No Job Found',
		 'No Job Found',
		 NULL,
		 'Null',
		 NULL))
      AND    csi.accounting_class_code = 'CUST_PROD'
      AND    csi.serial_number IS NOT NULL
      AND    EXISTS (SELECT 1
	  FROM   q_sn_reporting_v v
	  WHERE  v.job = csi.serial_number
	  UNION
	  SELECT 1
	  FROM   q_old_sn_reporting_v os
	  WHERE  os.job = csi.serial_number); --  1.8  09/04/2014    Adi Safin
    -- FOR update
    --  NOWAIT;

    /* SELECT csi.serial_number, attribute1, csi.inventory_item_id
    FROM   csi_item_instances      csi
    WHERE  csi.instance_id         = nvl(p_instance_number, csi.instance_id)
    AND    nvl(attribute1, 'Null') = nvl(p_item_status, decode(attribute1,'No Job Found','No Job Found',
                                                                          NULL,'Null',NULL))
    AND    accounting_class_code   = 'CUST_PROD'
    AND    serial_number           IS NOT NULL;*/

    -- End 1.6   11/04/2013    Adi Safin

    CURSOR cr_get_qa(cp_serial_number IN VARCHAR2,
	         p_type           VARCHAR2) IS
      SELECT v.plan_id,
	 v.collection_id,
	 v.job parent_serial_number,
	 v.obj_serial_number component_serial_number,
	 v.serial_component_item component_item,
	 1 component_qty,
	 v.job job,
	 v.hasp_enabled_for_sw_version, ---added by Vitaly 14-Mar-2010, modified by Roman 01-May-2010
	 MAX(v.creation_date)
      FROM   q_sn_reporting_v v
      WHERE  v.job = cp_serial_number
      AND    p_type = 'REPORTING'
      GROUP  BY v.plan_id,
	    v.collection_id,
	    v.job,
	    v.obj_serial_number,
	    v.serial_component_item,
	    v.job,
	    v.hasp_enabled_for_sw_version
      UNION ALL
      SELECT h.plan_id,
	 h.collection_id,
	 h.obj_machine_serial_number parent_serial_number,
	 h.obj_serial_number component_serial_number,
	 h.component_item component_item,
	 1 component_qty,
	 h.obj_machine_serial_number job,
	 '' enabled_for_software_version, ---added by Vitaly 14-Mar-2010
	 MAX(h.creation_date)
      FROM   q_historical_sn_reporting_v h
      WHERE  h.obj_machine_serial_number = cp_serial_number
      AND    p_type = 'HISTORICAL'
      GROUP  BY h.plan_id,
	    h.collection_id,
	    h.obj_machine_serial_number,
	    h.obj_serial_number,
	    h.component_item,
	    h.obj_machine_serial_number
      UNION ALL --  1.8  09/04/2014    Adi Safin
      SELECT os.plan_id,
	 os.collection_id,
	 os.job parent_serial_number,
	 os.obj_serial_number component_serial_number,
	 os.serial_component_item component_item,
	 1 component_qty,
	 os.job job,
	 '' enabled_for_software_version, ---added by Vitaly 14-Mar-2010
	 MAX(os.creation_date)
      FROM   q_old_sn_reporting_v os
      WHERE  os.job = cp_serial_number
      AND    p_type = 'OLDSN'
      GROUP  BY os.plan_id,
	    os.collection_id,
	    os.job,
	    os.obj_serial_number,
	    os.serial_component_item,
	    os.job;

    l_return_status VARCHAR2(2000) := NULL;
    l_msg_count     NUMBER := NULL;
    l_msg_data      VARCHAR2(2500) := NULL;
    l_msg_index_out NUMBER := NULL;
    l_init_msg_lst  VARCHAR2(500) := NULL;
    --l_commit                     VARCHAR2(5);
    l_validation_level           NUMBER := NULL;
    v_system_id                  NUMBER(10);
    v_component_id               NUMBER(10);
    v_master_organization_id     NUMBER(10);
    v_instance_type_code         VARCHAR2(50);
    v_accounting_class_code      VARCHAR2(50);
    v_operational_status_code    VARCHAR2(50);
    v_instance_status_id         NUMBER;
    v_ship_date                  DATE;
    v_party_source_table         VARCHAR2(50);
    v_party_id                   NUMBER;
    v_cust_account_id            NUMBER;
    v_install_location_id        NUMBER;
    v_install_location_type_code VARCHAR2(50);
    v_organization_id            NUMBER;
    v_instance_condition_id      NUMBER;
    v_location_id                NUMBER;
    v_context                    VARCHAR2(30); -- Dalit A. Raviv 03/03/2010
    v_instance_id                NUMBER;
    v_parent_instance_id         NUMBER;
    v_instance_party_id          NUMBER;
    v_ip_account_id              NUMBER;
    v_primary_uom_code           VARCHAR2(20);
    v_relationship_id            NUMBER;
    v_last_oe_order_line_id      NUMBER;
    v_serial_number_control_code NUMBER;
    v_serial_number              VARCHAR2(50);
    v_external_ref               VARCHAR2(2500);
    v_revision                   VARCHAR2(3);
    v_new_item                   VARCHAR2(40); -- Dalit A. Raviv 25/02/2010
    v_job_name                   VARCHAR2(30);
    v_instance_exist             VARCHAR2(1);
    v_error                      VARCHAR2(2500);
    l_plan_type                  VARCHAR2(20) := NULL;
    l_ext_attribute_value_id     NUMBER;
    v_attribute_id               NUMBER;
    v_ext_attr_ind               NUMBER;
    l_master_organization_id     NUMBER;
    l_instance_rec               csi_datastructures_pub.instance_rec;
    l_party_tbl                  csi_datastructures_pub.party_tbl;
    l_account_tbl                csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl         csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl        csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl       csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec                    csi_datastructures_pub.transaction_rec;
    l_txn_rec_chi                csi_datastructures_pub.transaction_rec;
    l_ext_attrib_values          csi_datastructures_pub.extend_attrib_values_tbl;
    l_relationship_tbl           csi_datastructures_pub.ii_relationship_tbl;

    -- 1.3 07/06/2010 Dalit A. Raviv
    l_api_mark VARCHAR2(1) := 'Y';
    -- 1.4 16/06/2010 Dalit A. Raviv
    l_error_code NUMBER := 0;
    l_error_desc VARCHAR2(2000) := NULL;
  BEGIN
    l_master_organization_id := xxinv_utils_pkg.get_master_organization_id;

    fnd_file.put_line(fnd_file.log,
	          ' ----------------- 1 -----------------' ||
	          to_char(SYSDATE, 'hh24:mi:ss'));
    FOR t IN cr_find_instances LOOP

      fnd_file.put_line(fnd_file.log,
		' ----------------- in loop 2 -----------------' ||
		to_char(SYSDATE, 'hh24:mi:ss'));
      l_api_mark := 'Y';

      l_return_status := NULL;
      l_msg_count     := NULL;
      l_msg_data      := NULL;
      l_msg_index_out := NULL;
      v_serial_number := NULL;
      v_job_name      := NULL;
      ------
      BEGIN
        SELECT cii.system_id,
	   cii.inv_master_organization_id,
	   cii.instance_type_code,
	   cii.accounting_class_code,
	   cii.operational_status_code,
	   cii.instance_status_id,
	   cii.install_location_id,
	   cii.install_location_type_code,
	   cii.last_vld_organization_id,
	   cii.instance_condition_id,
	   cii.location_id,
	   cii.context,
	   cii.instance_id,
	   cii.last_oe_order_line_id
        INTO   v_system_id,
	   v_master_organization_id,
	   v_instance_type_code,
	   v_accounting_class_code,
	   v_operational_status_code,
	   v_instance_status_id,
	   v_install_location_id,
	   v_install_location_type_code,
	   v_organization_id,
	   v_instance_condition_id,
	   v_location_id,
	   v_context,
	   v_parent_instance_id,
	   v_last_oe_order_line_id
        FROM   csi_item_instances cii,
	   csi_systems_tl     cst
        WHERE  cii.serial_number = t.serial_number
        AND    cii.inventory_item_id = t.inventory_item_id
        AND    cst.system_id(+) = cii.system_id
        AND    cst.language(+) = 'US';

      EXCEPTION
        WHEN no_data_found THEN
          v_system_id := NULL;
      END;
      ------
      BEGIN
        SELECT ms.ship_date
        INTO   v_ship_date
        FROM   mtl_serial_numbers ms
        WHERE  ms.serial_number = t.serial_number
        AND    ms.inventory_item_id = t.inventory_item_id;
      EXCEPTION
        WHEN no_data_found THEN
          v_ship_date := NULL;
      END;
      ------
      BEGIN
        --  1.9  19/06/2014    Adi Safin        CHG0032521 - Bugfix Polyjet IB Configuration Creation. too many rows error
        -- add owner_party_account_id to the sql query
        SELECT p.party_source_table,
	   hp.party_id,
	   i.owner_party_account_id
        INTO   v_party_source_table,
	   v_party_id,
	   v_cust_account_id
        FROM   csi_item_instances i,
	   csi_i_parties      p,
	   hz_parties         hp
        WHERE  i.serial_number = t.serial_number
        AND    i.inventory_item_id = t.inventory_item_id
        AND    i.instance_id = p.instance_id
        AND    p.party_id = hp.party_id
        AND    p.relationship_type_code = 'OWNER';
      EXCEPTION
        WHEN no_data_found THEN
          v_party_source_table := NULL;
      END;
      ------
      --  1.9  19/06/2014    Adi Safin        CHG0032521 - Bugfix Polyjet IB Configuration Creation. too many rows error
      -- Remark the sql query
      /* BEGIN
        SELECT hc.cust_account_id
          INTO v_cust_account_id
          FROM hz_cust_accounts hc
         WHERE hc.party_id = v_party_id
           AND hc.status = 'A';
      EXCEPTION
        WHEN no_data_found THEN
          v_cust_account_id := NULL;
      END;*/
      ------
      BEGIN
        SELECT 'REPORTING'
        INTO   l_plan_type
        FROM   q_sn_reporting_v v
        WHERE  v.job = t.serial_number
        AND    rownum < 2;
      EXCEPTION
        WHEN no_data_found THEN
          BEGIN
	--  1.8  09/04/2014    Adi Safin
	SELECT 'OLDSN'
	INTO   l_plan_type
	FROM   q_old_sn_reporting_v v
	WHERE  v.job = t.serial_number
	AND    rownum < 2;
          EXCEPTION
	WHEN no_data_found THEN
	  l_plan_type := 'HISTORICAL';
          END;
      END;
      ------
      FOR i IN cr_get_qa(t.serial_number, l_plan_type) LOOP
        -- Dalit A. Raviv 03/03/2010
        IF v_error IS NOT NULL THEN
          v_error := 'E - '; -- it only a remark fot the finish with error
        END IF;
        v_job_name       := i.job;
        v_instance_exist := NULL;
        v_component_id   := NULL;
        ------
        BEGIN
          SELECT msi_s.inventory_item_id,
	     msi_s.primary_uom_code,
	     msi_s.serial_number_control_code,
	     msi_s.segment1
          INTO   v_component_id,
	     v_primary_uom_code,
	     v_serial_number_control_code,
	     v_new_item
          FROM   mtl_system_items_b msi,
	     mtl_system_items_b msi_s
          WHERE  msi.segment1 = i.component_item
          AND    msi.organization_id = l_master_organization_id
          AND    msi_s.organization_id = l_master_organization_id
          AND    msi_s.inventory_item_id = to_number(msi.attribute9);
        EXCEPTION
          WHEN no_data_found THEN
	v_component_id := NULL;
        END;
        ------
        BEGIN
          SELECT MAX(mi.revision)
          INTO   v_revision
          FROM   mtl_item_revisions_b mi
          WHERE  mi.inventory_item_id = v_component_id
          AND    mi.organization_id = l_master_organization_id;
        EXCEPTION
          WHEN no_data_found THEN
	v_revision := NULL;
        END;
        ------
        --Check if the component has already instance     show error     to parent
        BEGIN
          SELECT 'Y'
          INTO   v_instance_exist
          FROM   csi_ii_relationships cir,
	     csi_item_instances   cii
          WHERE  cir.subject_id = cii.instance_id
          AND    cii.inventory_item_id = v_component_id -- Adi Safin 14-02-2016
          AND    SYSDATE BETWEEN nvl(cir.active_start_date, SYSDATE) AND
	     nvl(cir.active_end_date, SYSDATE)
          AND    nvl(cii.external_reference, cii.serial_number) =
	     i.component_serial_number;
        EXCEPTION
          WHEN no_data_found THEN
	v_instance_exist := NULL;
        END;
        ------
        /*-- for debug
        Fnd_File.Put_Line(Fnd_File.Log,'---------- DEBUG ---------- '||
                                       ' Serial_number -    '||t.serial_number||
                                       ' v_component_id -   '||v_component_id||
                                       ' v_instance_exist - '||v_instance_exist);*/
        --
        IF v_component_id IS NOT NULL AND v_instance_exist IS NULL THEN
          --If component is serial then put value in relevant field
          IF v_serial_number_control_code <> 1 THEN
	v_serial_number := i.component_serial_number;
	v_external_ref  := NULL;
          ELSE
	v_serial_number := NULL;
	v_external_ref  := i.component_serial_number;
          END IF;
          ------ Get sequences values
          SELECT csi_item_instances_s.nextval
          INTO   v_instance_id
          FROM   dual;

          SELECT csi_i_parties_s.nextval
          INTO   v_instance_party_id
          FROM   dual;

          SELECT csi_ip_accounts_s.nextval
          INTO   v_ip_account_id
          FROM   dual;
          ------
          l_instance_rec.instance_id         := v_instance_id;
          l_instance_rec.instance_number     := v_instance_id;
          l_instance_rec.external_reference  := substr(v_external_ref,
				       1,
				       30);
          l_instance_rec.inventory_item_id   := v_component_id;
          l_instance_rec.vld_organization_id := v_organization_id;
          -- l_instance_rec.INV_ORGANIZATION_ID             := v_organization_id;
          l_instance_rec.inv_master_organization_id := v_master_organization_id;
          l_instance_rec.serial_number              := v_serial_number;
          l_instance_rec.inventory_revision         := v_revision; --'0'; -- 1.5 02/05/2001 Dalit A. Raviv
          l_instance_rec.quantity                   := i.component_qty;
          l_instance_rec.unit_of_measure            := v_primary_uom_code;
          l_instance_rec.accounting_class_code      := v_accounting_class_code;
          l_instance_rec.instance_condition_id      := v_instance_condition_id;
          l_instance_rec.instance_status_id         := v_instance_status_id;
          l_instance_rec.last_oe_order_line_id      := v_last_oe_order_line_id;
          l_instance_rec.customer_view_flag         := 'N';
          l_instance_rec.merchant_view_flag         := 'Y';
          l_instance_rec.sellable_flag              := 'N';
          l_instance_rec.system_id                  := v_system_id;
          l_instance_rec.instance_type_code         := v_instance_type_code;
          l_instance_rec.active_start_date          := SYSDATE;
          l_instance_rec.active_end_date            := NULL;
          l_instance_rec.location_type_code         := 'HZ_PARTY_SITES';
          l_instance_rec.location_id                := v_location_id;
          -- l_instance_rec.install_date               := SYSDATE;
          l_instance_rec.manually_created_flag      := 'Y';
          l_instance_rec.creation_complete_flag     := 'Y';
          l_instance_rec.install_location_type_code := v_install_location_type_code;
          l_instance_rec.install_location_id        := v_install_location_id;
          l_instance_rec.context                    := v_context;
          l_instance_rec.call_contracts             := fnd_api.g_true;
          l_instance_rec.grp_call_contracts         := fnd_api.g_true;
          l_instance_rec.attribute1                 := nvl(v_job_name,
				           'No Job Found');
          --PARTY
          l_party_tbl(1).instance_party_id := v_instance_party_id;
          l_party_tbl(1).instance_id := v_instance_id;
          l_party_tbl(1).party_source_table := 'HZ_PARTIES';
          l_party_tbl(1).party_id := v_party_id;
          l_party_tbl(1).relationship_type_code := 'OWNER';
          l_party_tbl(1).contact_flag := 'N';
          l_party_tbl(1).contact_ip_id := NULL;
          l_party_tbl(1).active_start_date := SYSDATE;
          l_party_tbl(1).active_end_date := NULL;
          l_party_tbl(1).object_version_number := 1;
          l_party_tbl(1).primary_flag := NULL;
          l_party_tbl(1).preferred_flag := 'N';
          l_party_tbl(1).call_contracts := fnd_api.g_true;
          --ACCOUNTS
          l_account_tbl(1).ip_account_id := v_ip_account_id;
          l_account_tbl(1).parent_tbl_index := 1;
          l_account_tbl(1).instance_party_id := v_instance_party_id;
          l_account_tbl(1).party_account_id := v_cust_account_id;
          l_account_tbl(1).relationship_type_code := 'OWNER';
          l_account_tbl(1).active_start_date := SYSDATE;
          l_account_tbl(1).active_end_date := NULL;
          l_account_tbl(1).object_version_number := 1;
          l_account_tbl(1).call_contracts := fnd_api.g_true;
          l_account_tbl(1).grp_call_contracts := fnd_api.g_true;
          l_account_tbl(1).vld_organization_id := v_organization_id;
          --TXN
          l_txn_rec.transaction_id              := NULL;
          l_txn_rec.transaction_date            := trunc(SYSDATE);
          l_txn_rec.source_transaction_date     := trunc(SYSDATE);
          l_txn_rec.transaction_type_id         := 1;
          l_txn_rec.txn_sub_type_id             := NULL;
          l_txn_rec.source_group_ref_id         := NULL;
          l_txn_rec.source_group_ref            := '';
          l_txn_rec.source_header_ref_id        := NULL;
          l_txn_rec.source_header_ref           := '';
          l_txn_rec.source_line_ref_id          := NULL;
          l_txn_rec.source_line_ref             := '';
          l_txn_rec.source_dist_ref_id1         := NULL;
          l_txn_rec.source_dist_ref_id2         := NULL;
          l_txn_rec.inv_material_transaction_id := NULL;
          l_txn_rec.transaction_quantity        := NULL;
          l_txn_rec.transaction_uom_code        := '';
          l_txn_rec.transacted_by               := NULL;
          l_txn_rec.transaction_status_code     := '';
          l_txn_rec.transaction_action_code     := '';
          l_txn_rec.message_id                  := NULL;
          l_txn_rec.object_version_number       := '';
          l_txn_rec.split_reason_code           := '';
          ------------------------------ Add External Attributes ------------------------------
          l_ext_attrib_values.delete;
          v_ext_attr_ind := 0;
          ------
          BEGIN
	SELECT cie.attribute_id
	INTO   v_attribute_id
	FROM   csi_i_extended_attribs cie,
	       mtl_system_items_b     msib
	WHERE  cie.attribute_code = 'OBJ_HASP_EXP'
	AND    cie.inventory_item_id = msib.attribute9
	AND    msib.organization_id = 91
	AND    SYSDATE BETWEEN nvl(cie.active_end_date, SYSDATE - 1) AND
	       SYSDATE
	AND    msib.segment1 = i.component_item; ---'CMP-04015'

	SELECT csi_iea_values_s.nextval
	INTO   l_ext_attribute_value_id
	FROM   dual;

	v_ext_attr_ind := v_ext_attr_ind + 1;

	fnd_file.put_line(fnd_file.log,
		      '---------- Add External Attribute: External Attribute ''OBJ_HASP_EXP'' for Component Item ''' ||
		      i.component_item ||
		      ''' will be added with ext_attribute_value_id=' ||
		      l_ext_attribute_value_id);

	l_ext_attrib_values(v_ext_attr_ind).attribute_value_id := l_ext_attribute_value_id;
	l_ext_attrib_values(v_ext_attr_ind).instance_id := v_instance_id;
	l_ext_attrib_values(v_ext_attr_ind).attribute_id := v_attribute_id;
	l_ext_attrib_values(v_ext_attr_ind).attribute_code := 'OBJ_HASP_EXP';
	l_ext_attrib_values(v_ext_attr_ind).attribute_value := 'Forever';
	l_ext_attrib_values(v_ext_attr_ind).active_start_date := SYSDATE;

          EXCEPTION
	WHEN OTHERS THEN
	  fnd_file.put_line(fnd_file.log,
		        '---------- Add External Attribute: Component Item ''' ||
		        i.component_item ||
		        ''' is out of scope for ''OBJ_HASP_EXP''');
          END;
          ------
          IF i.hasp_enabled_for_sw_version IS NOT NULL THEN
	------
	BEGIN
	  SELECT cie.attribute_id
	  INTO   v_attribute_id
	  FROM   csi_i_extended_attribs cie,
	         mtl_system_items_b     msib
	  WHERE  cie.attribute_code = 'OBJ_HASP_SV'
	  AND    cie.inventory_item_id = msib.attribute9
	  AND    msib.organization_id = 91
	  AND    SYSDATE BETWEEN nvl(cie.active_end_date, SYSDATE - 1) AND
	         SYSDATE
	  AND    msib.segment1 = i.component_item; ---'CMP-04015'

	  SELECT csi_iea_values_s.nextval
	  INTO   l_ext_attribute_value_id
	  FROM   dual;

	  v_ext_attr_ind := v_ext_attr_ind + 1;

	  fnd_file.put_line(fnd_file.log,
		        '---------- Add External Attribute: External Attribute ''OBJ_HASP_SV'' for Component Item ''' ||
		        i.component_item ||
		        ''' will be added with ext_attribute_value_id=' ||
		        l_ext_attribute_value_id || ' , value=''' ||
		        i.hasp_enabled_for_sw_version || '''');

	  l_ext_attrib_values(v_ext_attr_ind).attribute_value_id := l_ext_attribute_value_id;
	  l_ext_attrib_values(v_ext_attr_ind).instance_id := v_instance_id;
	  l_ext_attrib_values(v_ext_attr_ind).attribute_id := v_attribute_id;
	  l_ext_attrib_values(v_ext_attr_ind).attribute_code := 'OBJ_HASP_SV';
	  l_ext_attrib_values(v_ext_attr_ind).attribute_value := i.hasp_enabled_for_sw_version;
	  l_ext_attrib_values(v_ext_attr_ind).active_start_date := SYSDATE;

	EXCEPTION
	  WHEN OTHERS THEN
	    fnd_file.put_line(fnd_file.log,
		          '---------- Add External Attribute: Component Item ''' ||
		          i.component_item ||
		          ''' is out of scope for ''OBJ_HASP_SV''');
	END;
          END IF; -- i.hasp_sw_version is not null

          --CALL API
          l_msg_data     := NULL;
          l_init_msg_lst := NULL;
          fnd_msg_pub.initialize;
          --Create The Instance
          csi_item_instance_pub.create_item_instance(p_api_version           => 1,
				     p_commit                => fnd_api.g_false,
				     p_init_msg_list         => l_init_msg_lst,
				     p_validation_level      => l_validation_level,
				     p_instance_rec          => l_instance_rec,
				     p_ext_attrib_values_tbl => l_ext_attrib_values,
				     p_party_tbl             => l_party_tbl,
				     p_account_tbl           => l_account_tbl,
				     p_pricing_attrib_tbl    => l_pricing_attrib_tbl,
				     p_org_assignments_tbl   => l_org_assignments_tbl,
				     p_asset_assignment_tbl  => l_asset_assignment_tbl,
				     p_txn_rec               => l_txn_rec,
				     x_return_status         => l_return_status,
				     x_msg_count             => l_msg_count,
				     x_msg_data              => l_msg_data);

          IF l_return_status != apps.fnd_api.g_ret_sts_success THEN

	l_api_mark := 'N';

	fnd_msg_pub.get(p_msg_index     => -1,
		    p_encoded       => 'F',
		    p_data          => l_msg_data,
		    p_msg_index_out => l_msg_index_out);

	-- Dalit A. Raviv 03/03/2010 add fnd_file and substr
	fnd_file.put_line(fnd_file.log,
		      'Got error when trying to create instance for COMPONENT: ' ||
		      v_new_item || ' : ' || l_msg_data);

	--dbms_output.put_line('1: ' || l_return_status || ' ' ||l_msg_data);
	retcode := '1';
	IF v_error IS NULL THEN
	  v_error := 'Job ' || i.job ||
		 ' got error when trying to create instance for COMPONENT: ' ||
		 v_new_item || ' :' || substr(l_msg_data, 1, 500) ||
		 chr(10);
	END IF;
	-- 1.4 16/06/2010 Dalit A. Raviv
	handle_log_tbl(p_parent_instance_id      => v_parent_instance_id, -- i n
		   p_parent_cust1            => t.attribute1, -- i v
		   p_child_instance_id       => v_instance_id, -- i n
		   p_component_item          => v_new_item, -- i v
		   p_component_serial_number => i.component_serial_number, -- i v
		   p_creation_status         => l_return_status, -- i v
		   p_creation_err_msg        => 'Got error when trying to create instance for COMPONENT: ' ||
				        v_new_item || ' : ' ||
				        l_msg_data, -- i v
		   p_relation_staus          => NULL, -- i v
		   p_relation_err_msg        => NULL, -- i v
		   p_job                     => i.job, -- i n
		   p_error_code              => l_error_code, -- o n
		   p_error_desc              => l_error_desc); -- o v
	-- end 1.4
	-- Dalit A. Raviv 07/06/2010
	ROLLBACK;
	--
          ELSE
	-- Create the relationship between Parent Instance and Child
	l_return_status    := NULL;
	l_msg_count        := NULL;
	l_init_msg_lst     := NULL;
	l_msg_index_out    := NULL;
	l_validation_level := NULL;
	-- Dalit A. Raviv  03/03/2010
	l_msg_data := NULL;
	--

	SELECT csi_ii_relationships_s.nextval
	INTO   v_relationship_id
	FROM   dual;

	l_relationship_tbl(1).relationship_id := v_relationship_id;
	l_relationship_tbl(1).relationship_type_code := 'COMPONENT-OF';
	l_relationship_tbl(1).object_id := v_parent_instance_id;
	l_relationship_tbl(1).subject_id := v_instance_id;
	l_relationship_tbl(1).subject_has_child := 'N';
	l_relationship_tbl(1).position_reference := NULL;
	l_relationship_tbl(1).active_start_date := SYSDATE;
	l_relationship_tbl(1).active_end_date := NULL;
	l_relationship_tbl(1).display_order := NULL;
	l_relationship_tbl(1).mandatory_flag := 'N';
	l_relationship_tbl(1).object_version_number := 1;

	l_txn_rec_chi.transaction_date        := trunc(SYSDATE);
	l_txn_rec_chi.source_transaction_date := trunc(SYSDATE);
	l_txn_rec_chi.transaction_type_id     := 1;
	l_txn_rec_chi.object_version_number   := 1;

	csi_ii_relationships_pub.create_relationship(p_api_version      => 1,
				         p_commit           => fnd_api.g_false,
				         p_init_msg_list    => l_init_msg_lst,
				         p_validation_level => l_validation_level,
				         p_relationship_tbl => l_relationship_tbl,
				         p_txn_rec          => l_txn_rec_chi,
				         x_return_status    => l_return_status,
				         x_msg_count        => l_msg_count,
				         x_msg_data         => l_msg_data);

	IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
	  l_api_mark := 'N';
	  fnd_msg_pub.get(p_msg_index     => -1,
		      p_encoded       => 'F',
		      p_data          => l_msg_data,
		      p_msg_index_out => l_msg_index_out);

	  fnd_file.put_line(fnd_file.log,
		        'Error Create Relation Between Parent Instance ' ||
		        v_parent_instance_id ||
		        ' And Child Instance (item: ' || v_new_item ||
		        '): ' || v_instance_id || '. Error: ' ||
		        l_msg_data);

	  retcode := 1;
	  IF v_error IS NULL THEN
	    v_error := 'Job ' || i.job ||
		   ' got error when trying to assign instance ' ||
		   v_instance_id || ' to current configuration:' ||
		   substr(l_msg_data, 1, 500) || chr(10);
	  END IF;

	  -- 1.4 16/06/2010 Dalit A. Raviv
	  handle_log_tbl(p_parent_instance_id      => v_parent_instance_id, -- i n
		     p_parent_cust1            => t.attribute1, -- i v
		     p_child_instance_id       => v_instance_id, -- i n
		     p_component_item          => v_new_item, -- i v
		     p_component_serial_number => i.component_serial_number, -- i v
		     p_creation_status         => 'E', -- i v
		     p_creation_err_msg        => NULL, -- i v
		     p_relation_staus          => l_return_status, -- i v
		     p_relation_err_msg        => 'Error Create Relation Between Parent Instance ' ||
				          v_parent_instance_id ||
				          ' And Child Instance (item: ' ||
				          v_new_item ||
				          '): ' ||
				          v_instance_id ||
				          '. Error: ' ||
				          substr(l_msg_data,
					     1,
					     500), -- i v
		     p_job                     => i.job, -- i n
		     p_error_code              => l_error_code, -- o n
		     p_error_desc              => l_error_desc); -- o v
	  -- end 1.4

	  -- Dalit A. Raviv 07/06/2010
	  ROLLBACK;
	  --
	  -- Dalit A. Raviv 07/06/2010 there was no commit when success to create relationship
	  -- so the last serial at the loop do not do commit and we do not see the relationship
	  -- create.
	ELSE
	  -- 1.3 07/06/2010 Dalit A. Raviv
	  -- Add mark if APUI did not work (did not enter to this part of IF) then do not do UPDATE
	  l_api_mark := 'Y';
	  -- 1.3
	  COMMIT;
	  -- 1.4 16/06/2010 Dalit A. Raviv
	  handle_log_tbl(p_parent_instance_id      => v_parent_instance_id, -- i n
		     p_parent_cust1            => t.attribute1, -- i v
		     p_child_instance_id       => v_instance_id, -- i n
		     p_component_item          => v_new_item, -- i v
		     p_component_serial_number => i.component_serial_number, -- i v
		     p_creation_status         => 'S', -- i v
		     p_creation_err_msg        => NULL, -- i v
		     p_relation_staus          => l_return_status, -- i v
		     p_relation_err_msg        => NULL, -- i v
		     p_job                     => i.job, -- i n
		     p_error_code              => l_error_code, -- o n
		     p_error_desc              => l_error_desc); -- o v
	  -- end 1.4
	  --
	END IF; -- return status rel API
          END IF; -- return status instance API
          -- 1.3 07/06/2010 Dalit A. Raviv
          -- Add mark if API did not work (did not enter to this part of IF) then do not do UPDATE
          --l_api_mark := 'Y';
          -- 1.3
        ELSE
          -- 1.3 07/06/2010 Dalit A. Raviv
          -- Add mark if APUI did not work (did not enter to this part of IF) then do not do UPDATE
          l_api_mark := 'Y';
          -- 1.3
          fnd_file.put_line(fnd_file.log,
		    'Error - parent instance' ||
		    to_char(v_parent_instance_id) ||
		    ' And Child Instance (item: ' || v_new_item ||
		    '): The component already process ' || chr(10));

          IF v_error IS NULL THEN
	v_error := 'Error - parent instance ' ||
	           to_char(v_parent_instance_id) ||
	           ' And Child Instance (item: ' || v_new_item ||
	           '): The component already process' || chr(10);
          END IF; -- v_error
        END IF; -- v_component_id IS NOT NULL AND v_instance_exist IS NULL
      END LOOP; -- inner loop
      -- 1.3 07/06/2010 Dalit A. Raviv
      IF l_api_mark = 'Y' THEN
        UPDATE csi_item_instances ci
        SET    attribute1 = nvl(v_job_name, 'No Job Found')
        WHERE  ci.serial_number = t.serial_number;
        COMMIT;
      END IF;
      -- 1.3
    END LOOP; -- outer loop

    fnd_file.put_line(fnd_file.log,
	          ' ----------------- out loop 3 -----------------' ||
	          to_char(SYSDATE, 'hh24:mi:ss'));
    ------
    IF v_error IS NOT NULL THEN
      -- Dalit A. Raviv 25/02/2010      add fnd_file and substr
      -- change return errbuf to string
      errbuf  := 'Error Create Relation Between Parent Instance'; --substr(v_error,1,500);
      retcode := '1';
    END IF;

  END create_instance;

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
  PROCEDURE create_instance_ext(errbuf  OUT VARCHAR2,
		        retcode OUT VARCHAR2) IS
    -- Get population from xxcs_ib_item_creation_ext_tbl table
    CURSOR hasp_cur IS
      SELECT xiic.entity_id,
	 xiic.job,
	 xiic.comp_item,
	 xiic.comp_serial_number,
	 xiic.com_qty,
	 xiic.hasp_sw_version,
	 xiic.message_code,
	 xiic.message_desc,
	 xiic.last_update_date,
	 xiic.last_updated_by,
	 xiic.creation_date,
	 xiic.created_by,
	 ROWID row_id
      FROM   xxcs_ib_item_creation_ext_tbl xiic
      WHERE  xiic.message_code IS NULL;
    --and    rownum                        < 20;   -- for debug

    l_return_status              VARCHAR2(2000) := NULL;
    l_msg_count                  NUMBER := NULL;
    l_msg_data                   VARCHAR2(2500) := NULL;
    l_msg_index_out              NUMBER := NULL;
    l_init_msg_lst               VARCHAR2(500) := NULL;
    l_validation_level           NUMBER := NULL;
    l_system_id                  NUMBER(10);
    l_component_id               NUMBER(10);
    l_master_organization_id     NUMBER(10);
    l_instance_type_code         VARCHAR2(50);
    l_accounting_class_code      VARCHAR2(50);
    l_instance_status_id         NUMBER;
    l_party_id                   NUMBER;
    l_cust_account_id            NUMBER;
    l_install_location_id        NUMBER;
    l_install_location_type_code VARCHAR2(50);
    l_organization_id            NUMBER;
    l_instance_condition_id      NUMBER;
    l_location_id                NUMBER;
    l_context                    VARCHAR2(30);
    l_instance_id                NUMBER;
    l_parent_instance_id         NUMBER;
    l_instance_party_id          NUMBER;
    l_ip_account_id              NUMBER;
    l_primary_uom_code           VARCHAR2(20);
    l_relationship_id            NUMBER;
    l_last_oe_order_line_id      NUMBER;
    l_serial_number_control_code NUMBER;
    l_serial_number              VARCHAR2(50);
    l_external_ref               VARCHAR2(50);
    l_new_item                   VARCHAR2(40);
    l_instance_exist             VARCHAR2(1);
    l_error                      VARCHAR2(2500);
    l_ext_attribute_value_id     NUMBER;
    l_attribute_id               NUMBER;
    l_ext_attr_ind               NUMBER;
    v_master_organization_id     NUMBER;
    l_instance_rec               csi_datastructures_pub.instance_rec;
    l_party_tbl                  csi_datastructures_pub.party_tbl;
    l_account_tbl                csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl         csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl        csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl       csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec                    csi_datastructures_pub.transaction_rec;
    l_txn_rec_chi                csi_datastructures_pub.transaction_rec;
    l_ext_attrib_values          csi_datastructures_pub.extend_attrib_values_tbl;
    l_relationship_tbl           csi_datastructures_pub.ii_relationship_tbl;

    l_api_mark VARCHAR2(1) := 'Y';

  BEGIN
    -- this procedure will run from Pl/sql.
    -- To be able to run API from DB i Need to do app_initialize.
    fnd_global.apps_initialize(user_id      => 1308,
		       resp_id      => 51137,
		       resp_appl_id => 514);
    l_master_organization_id := xxinv_utils_pkg.get_master_organization_id;

    FOR hasp_rec IN hasp_cur LOOP
      -- Init variables
      l_api_mark      := 'Y';
      l_return_status := NULL;
      l_msg_count     := NULL;
      l_msg_data      := NULL;
      l_msg_index_out := NULL;
      l_serial_number := NULL;
      l_party_id      := NULL;

      IF l_error IS NOT NULL THEN
        l_error := 'E - '; -- it only a remark fot the finish with error
      END IF;

      -- Get install base data
      BEGIN
        SELECT cii.system_id,
	   cii.inv_master_organization_id,
	   cii.instance_type_code,
	   cii.accounting_class_code,
	   cii.instance_status_id,
	   cii.install_location_id,
	   cii.install_location_type_code,
	   cii.last_vld_organization_id,
	   cii.instance_condition_id,
	   cii.location_id,
	   cii.context,
	   cii.instance_id,
	   cii.last_oe_order_line_id
        INTO   l_system_id,
	   v_master_organization_id,
	   l_instance_type_code,
	   l_accounting_class_code,
	   l_instance_status_id,
	   l_install_location_id,
	   l_install_location_type_code,
	   l_organization_id,
	   l_instance_condition_id,
	   l_location_id,
	   l_context,
	   l_parent_instance_id,
	   l_last_oe_order_line_id
        FROM   csi_item_instances cii,
	   csi_systems_tl     cst
        WHERE  cii.serial_number = hasp_rec.job -- hasp_rec.comp_serial_number --t.serial_number
        AND    cst.system_id(+) = cii.system_id
        AND    cst.language(+) = 'US';

      EXCEPTION
        WHEN no_data_found THEN
          l_system_id := NULL;
      END;
      ------ Get serial party information
      BEGIN
        SELECT hp.party_id
        INTO   l_party_id
        FROM   csi_item_instances i,
	   csi_i_parties      p,
	   hz_parties         hp
        WHERE  i.serial_number = hasp_rec.job -- hasp_rec.comp_serial_number --t.serial_number
        AND    i.instance_id = p.instance_id
        AND    p.party_id = hp.party_id
        AND    p.relationship_type_code = 'OWNER';
      EXCEPTION
        WHEN no_data_found THEN
          l_party_id := NULL;
      END;
      ------ Get cust account
      BEGIN
        SELECT hc.cust_account_id
        INTO   l_cust_account_id
        FROM   hz_cust_accounts hc
        WHERE  hc.party_id = l_party_id
        AND    hc.status = 'A';
      EXCEPTION
        WHEN no_data_found THEN
          l_cust_account_id := NULL;
      END;
      ------
      l_instance_exist := NULL;
      l_component_id   := NULL;
      ------ Get Component Item details
      BEGIN
        SELECT msi_s.inventory_item_id,
	   msi_s.primary_uom_code,
	   msi_s.serial_number_control_code,
	   msi_s.segment1
        INTO   l_component_id,
	   l_primary_uom_code,
	   l_serial_number_control_code,
	   l_new_item
        FROM   mtl_system_items_b msi,
	   mtl_system_items_b msi_s
        WHERE  msi.segment1 = hasp_rec.comp_item -- i.component_item
        AND    msi.organization_id = l_master_organization_id
        AND    msi_s.organization_id = l_master_organization_id
        AND    msi_s.inventory_item_id = to_number(msi.attribute9);
      EXCEPTION
        WHEN no_data_found THEN
          l_component_id := NULL;
      END;
      ------ Check if the component has already instance     exit SQL.SQLCODE to parent
      BEGIN
        SELECT 'Y'
        INTO   l_instance_exist
        FROM   csi_ii_relationships cir,
	   csi_item_instances   cii
        WHERE  cir.subject_id = cii.instance_id
        AND    SYSDATE BETWEEN nvl(cir.active_start_date, SYSDATE) AND
	   nvl(cir.active_end_date, SYSDATE)
        AND    nvl(cii.external_reference, cii.serial_number) =
	   hasp_rec.comp_serial_number; --i.component_serial_number;
      EXCEPTION
        WHEN no_data_found THEN
          l_instance_exist := NULL;
      END;

      -----------------------------------------------------------------------------
      IF l_component_id IS NOT NULL AND l_instance_exist IS NULL THEN
        ------ If component is serial then put value in relevant field
        IF l_serial_number_control_code <> 1 THEN
          l_serial_number := hasp_rec.comp_serial_number;
          l_external_ref  := NULL;
        ELSE
          l_serial_number := NULL;
          l_external_ref  := hasp_rec.comp_serial_number;
        END IF;
        ------ Get sequences values
        SELECT csi_item_instances_s.nextval
        INTO   l_instance_id
        FROM   dual;

        SELECT csi_i_parties_s.nextval
        INTO   l_instance_party_id
        FROM   dual;

        SELECT csi_ip_accounts_s.nextval
        INTO   l_ip_account_id
        FROM   dual;
        ------
        l_instance_rec.instance_id                := l_instance_id;
        l_instance_rec.instance_number            := l_instance_id;
        l_instance_rec.external_reference         := l_external_ref;
        l_instance_rec.inventory_item_id          := l_component_id;
        l_instance_rec.vld_organization_id        := l_organization_id;
        l_instance_rec.inv_master_organization_id := l_master_organization_id;
        l_instance_rec.serial_number              := l_serial_number;
        l_instance_rec.inventory_revision         := '0'; --l_revision;
        l_instance_rec.quantity                   := hasp_rec.com_qty; --i.component_qty;
        l_instance_rec.unit_of_measure            := l_primary_uom_code;
        l_instance_rec.accounting_class_code      := l_accounting_class_code;
        l_instance_rec.instance_condition_id      := l_instance_condition_id;
        l_instance_rec.instance_status_id         := l_instance_status_id;
        l_instance_rec.last_oe_order_line_id      := l_last_oe_order_line_id;
        l_instance_rec.customer_view_flag         := 'N';
        l_instance_rec.merchant_view_flag         := 'Y';
        l_instance_rec.sellable_flag              := 'N';
        l_instance_rec.system_id                  := l_system_id;
        l_instance_rec.instance_type_code         := l_instance_type_code;
        l_instance_rec.active_start_date          := SYSDATE;
        l_instance_rec.active_end_date            := NULL;
        l_instance_rec.location_type_code         := 'HZ_PARTY_SITES';
        l_instance_rec.location_id                := l_location_id;
        l_instance_rec.manually_created_flag      := 'Y';
        l_instance_rec.creation_complete_flag     := 'Y';
        l_instance_rec.install_location_type_code := l_install_location_type_code;
        l_instance_rec.install_location_id        := l_install_location_id;
        l_instance_rec.context                    := l_context;
        l_instance_rec.call_contracts             := fnd_api.g_true;
        l_instance_rec.grp_call_contracts         := fnd_api.g_true;
        l_instance_rec.attribute1                 := hasp_rec.job; --nvl(l_job_name, 'No Job Found');
        --PARTY
        l_party_tbl(1).instance_party_id := l_instance_party_id;
        l_party_tbl(1).instance_id := l_instance_id;
        l_party_tbl(1).party_source_table := 'HZ_PARTIES';
        l_party_tbl(1).party_id := l_party_id;
        l_party_tbl(1).relationship_type_code := 'OWNER';
        l_party_tbl(1).contact_flag := 'N';
        l_party_tbl(1).contact_ip_id := NULL;
        l_party_tbl(1).active_start_date := SYSDATE;
        l_party_tbl(1).active_end_date := NULL;
        l_party_tbl(1).object_version_number := 1;
        l_party_tbl(1).primary_flag := NULL;
        l_party_tbl(1).preferred_flag := 'N';
        l_party_tbl(1).call_contracts := fnd_api.g_true;
        --ACCOUNTS
        l_account_tbl(1).ip_account_id := l_ip_account_id;
        l_account_tbl(1).parent_tbl_index := 1;
        l_account_tbl(1).instance_party_id := l_instance_party_id;
        l_account_tbl(1).party_account_id := l_cust_account_id;
        l_account_tbl(1).relationship_type_code := 'OWNER';
        l_account_tbl(1).active_start_date := SYSDATE;
        l_account_tbl(1).active_end_date := NULL;
        l_account_tbl(1).object_version_number := 1;
        l_account_tbl(1).call_contracts := fnd_api.g_true;
        l_account_tbl(1).grp_call_contracts := fnd_api.g_true;
        l_account_tbl(1).vld_organization_id := l_organization_id;
        --TXN
        l_txn_rec.transaction_id              := NULL;
        l_txn_rec.transaction_date            := trunc(SYSDATE);
        l_txn_rec.source_transaction_date     := trunc(SYSDATE);
        l_txn_rec.transaction_type_id         := 1;
        l_txn_rec.txn_sub_type_id             := NULL;
        l_txn_rec.source_group_ref_id         := NULL;
        l_txn_rec.source_group_ref            := '';
        l_txn_rec.source_header_ref_id        := NULL;
        l_txn_rec.source_header_ref           := '';
        l_txn_rec.source_line_ref_id          := NULL;
        l_txn_rec.source_line_ref             := '';
        l_txn_rec.source_dist_ref_id1         := NULL;
        l_txn_rec.source_dist_ref_id2         := NULL;
        l_txn_rec.inv_material_transaction_id := NULL;
        l_txn_rec.transaction_quantity        := NULL;
        l_txn_rec.transaction_uom_code        := '';
        l_txn_rec.transacted_by               := NULL;
        l_txn_rec.transaction_status_code     := '';
        l_txn_rec.transaction_action_code     := '';
        l_txn_rec.message_id                  := NULL;
        l_txn_rec.object_version_number       := '';
        l_txn_rec.split_reason_code           := '';
        ------------------------------ Add External Attributes ------------------------------
        l_ext_attrib_values.delete;
        l_ext_attr_ind := 0;
        ------ get and set external attributes values
        BEGIN
          SELECT cie.attribute_id
          INTO   l_attribute_id
          FROM   csi_i_extended_attribs cie,
	     mtl_system_items_b     msib
          WHERE  cie.attribute_code = 'OBJ_HASP_EXP'
          AND    cie.inventory_item_id = msib.attribute9
          AND    msib.organization_id = 91
          AND    SYSDATE BETWEEN nvl(cie.active_end_date, SYSDATE - 1) AND
	     SYSDATE
          AND    msib.segment1 = hasp_rec.comp_item; ---'CMP-04015'

          SELECT csi_iea_values_s.nextval
          INTO   l_ext_attribute_value_id
          FROM   dual;

          l_ext_attr_ind := l_ext_attr_ind + 1;

          l_ext_attrib_values(l_ext_attr_ind).attribute_value_id := l_ext_attribute_value_id;
          l_ext_attrib_values(l_ext_attr_ind).instance_id := l_instance_id;
          l_ext_attrib_values(l_ext_attr_ind).attribute_id := l_attribute_id;
          l_ext_attrib_values(l_ext_attr_ind).attribute_code := 'OBJ_HASP_EXP';
          l_ext_attrib_values(l_ext_attr_ind).attribute_value := 'Forever';
          l_ext_attrib_values(l_ext_attr_ind).active_start_date := SYSDATE;

        EXCEPTION
          WHEN OTHERS THEN

	dbms_output.put_line('-- Add External Attribute: Component Item ' ||
		         hasp_rec.comp_item || -- i.component_item
		         ' is out of scope for OBJ_HASP_EXP ');
	/*
            Fnd_File.Put_Line(Fnd_File.Log, '-- Add External Attribute: Component Item '
                                            ||hasp_rec.comp_item|| -- i.component_item
                                            ' is out of scope for OBJ_HASP_EXP');
            */
        END;
        ------ get and set external attributes values for HASP
        IF hasp_rec.hasp_sw_version /*i.hasp_sw_version*/
           IS NOT NULL THEN
          ------
          BEGIN
	SELECT cie.attribute_id
	INTO   l_attribute_id
	FROM   csi_i_extended_attribs cie,
	       mtl_system_items_b     msib
	WHERE  cie.attribute_code = 'OBJ_HASP_SV'
	AND    cie.inventory_item_id = msib.attribute9
	AND    msib.organization_id = 91
	AND    SYSDATE BETWEEN nvl(cie.active_end_date, SYSDATE - 1) AND
	       SYSDATE
	AND    msib.segment1 = hasp_rec.comp_item; --i.component_item; ---'CMP-04015'

	SELECT csi_iea_values_s.nextval
	INTO   l_ext_attribute_value_id
	FROM   dual;

	l_ext_attr_ind := l_ext_attr_ind + 1;

	l_ext_attrib_values(l_ext_attr_ind).attribute_value_id := l_ext_attribute_value_id;
	l_ext_attrib_values(l_ext_attr_ind).instance_id := l_instance_id;
	l_ext_attrib_values(l_ext_attr_ind).attribute_id := l_attribute_id;
	l_ext_attrib_values(l_ext_attr_ind).attribute_code := 'OBJ_HASP_SV';
	l_ext_attrib_values(l_ext_attr_ind).attribute_value := hasp_rec.hasp_sw_version; --i.HASP_SW_VERSION;
	l_ext_attrib_values(l_ext_attr_ind).active_start_date := SYSDATE;

          EXCEPTION
	WHEN OTHERS THEN

	  dbms_output.put_line('-- Add External Attribute: Component Item ' ||
		           hasp_rec.comp_item || -- i.component_item
		           ' is out of scope for OBJ_HASP_SV ');
	  /*
              Fnd_File.Put_Line(Fnd_File.Log, '-- Add External Attribute: Component Item '
                                              ||hasp_rec.comp_item|| -- i.component_item
                                              ' is out of scope for OBJ_HASP_SV ');
              */
          END;
        END IF; -- i.hasp_sw_version is not null

        ------ CALL API
        l_msg_data     := NULL;
        l_init_msg_lst := NULL;
        fnd_msg_pub.initialize;
        --Create The Instance
        csi_item_instance_pub.create_item_instance(p_api_version           => 1,
				   p_commit                => fnd_api.g_false,
				   p_init_msg_list         => l_init_msg_lst,
				   p_validation_level      => l_validation_level,
				   p_instance_rec          => l_instance_rec,
				   p_ext_attrib_values_tbl => l_ext_attrib_values,
				   p_party_tbl             => l_party_tbl,
				   p_account_tbl           => l_account_tbl,
				   p_pricing_attrib_tbl    => l_pricing_attrib_tbl,
				   p_org_assignments_tbl   => l_org_assignments_tbl,
				   p_asset_assignment_tbl  => l_asset_assignment_tbl,
				   p_txn_rec               => l_txn_rec,
				   x_return_status         => l_return_status,
				   x_msg_count             => l_msg_count,
				   x_msg_data              => l_msg_data);

        IF l_return_status != apps.fnd_api.g_ret_sts_success THEN

          l_api_mark := 'N';
          fnd_msg_pub.get(p_msg_index     => -1,
		  p_encoded       => 'F',
		  p_data          => l_msg_data,
		  p_msg_index_out => l_msg_index_out);

          dbms_output.put_line('Error - create instance - COMPONENT: ' ||
		       l_new_item || ' : ' ||
		       substr(l_msg_data, 1, 1000));
          /*
          Fnd_File.Put_Line(Fnd_File.Log,
                               'Error - create instance - COMPONENT: '||l_new_item||
                               ' : '||l_msg_data);
          */
          retcode := '1';
          IF l_error IS NULL THEN
	l_error := 'Job ' || hasp_rec.job || --i.job
	           ' Error - create instance - COMPONENT: ' ||
	           l_new_item || ' :' || substr(l_msg_data, 1, 500);
          END IF;
          -- Update xxcs_ib_item_creation_ext_tbl tbl with error
          g_message_desc := substr(l_msg_data, 1, 1000);

          handle_ext_tbl('ERROR',
		 'Error - create instance - COMPONENT: ' ||
		 l_new_item,
		 hasp_rec.row_id);
          ROLLBACK;
          --
        ELSE
          -- Create the relationship between Parent Instance and Child
          l_return_status    := NULL;
          l_msg_count        := NULL;
          l_init_msg_lst     := NULL;
          l_msg_index_out    := NULL;
          l_validation_level := NULL;
          l_msg_data         := NULL;
          --

          SELECT csi_ii_relationships_s.nextval
          INTO   l_relationship_id
          FROM   dual;

          l_relationship_tbl(1).relationship_id := l_relationship_id;
          l_relationship_tbl(1).relationship_type_code := 'COMPONENT-OF';
          l_relationship_tbl(1).object_id := l_parent_instance_id;
          l_relationship_tbl(1).subject_id := l_instance_id;
          l_relationship_tbl(1).subject_has_child := 'N';
          l_relationship_tbl(1).position_reference := NULL;
          l_relationship_tbl(1).active_start_date := SYSDATE;
          l_relationship_tbl(1).active_end_date := NULL;
          l_relationship_tbl(1).display_order := NULL;
          l_relationship_tbl(1).mandatory_flag := 'N';
          l_relationship_tbl(1).object_version_number := 1;

          l_txn_rec_chi.transaction_date        := trunc(SYSDATE);
          l_txn_rec_chi.source_transaction_date := trunc(SYSDATE);
          l_txn_rec_chi.transaction_type_id     := 1;
          l_txn_rec_chi.object_version_number   := 1;

          csi_ii_relationships_pub.create_relationship(p_api_version      => 1,
				       p_commit           => fnd_api.g_false,
				       p_init_msg_list    => l_init_msg_lst,
				       p_validation_level => l_validation_level,
				       p_relationship_tbl => l_relationship_tbl,
				       p_txn_rec          => l_txn_rec_chi,
				       x_return_status    => l_return_status,
				       x_msg_count        => l_msg_count,
				       x_msg_data         => l_msg_data);

          IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
	l_api_mark := 'N';
	fnd_msg_pub.get(p_msg_index     => -1,
		    p_encoded       => 'F',
		    p_data          => l_msg_data,
		    p_msg_index_out => l_msg_index_out);

	dbms_output.put_line('Error Create Relation Between Parent Instance ' ||
		         l_parent_instance_id ||
		         ' And Child Instance (item: ' ||
		         l_new_item || '): ' || l_instance_id ||
		         '. Error: ' || l_msg_data);
	/*
            fnd_file.put_line(fnd_file.log,
                              'Error Create Relation Between Parent Instance ' || l_parent_instance_id ||
                              ' And Child Instance (item: ' || l_new_item || '): ' || l_instance_id ||
                              '. Error: ' || l_msg_data);
            */
	retcode := 1;
	IF l_error IS NULL THEN
	  l_error := 'Job ' || hasp_rec.job || --i.job
		 ' Error - Assign instance ' || l_instance_id ||
		 ' to current configuration:' ||
		 substr(l_msg_data, 1, 500);
	END IF;

	g_message_desc := substr(l_msg_data, 1, 1000);
	-- Update xxcs_ib_item_creation_ext_tbl tbl with error
	handle_ext_tbl('ERROR',
		   'Error Create Relation Between Parent Instance ' ||
		   l_parent_instance_id ||
		   ' And Child Instance (item: ' || l_new_item ||
		   '): ' || l_instance_id || '. Error: ',
		   hasp_rec.row_id);
	ROLLBACK;
	--
	-- There was no commit when success to create relationship
	-- so the last serial at the loop do not do commit and we do not see the relationship
	-- create.
          ELSE
	-- Add mark if APUI did not work (did not enter to this part of IF) then do not do UPDATE
	l_api_mark := 'Y';
	COMMIT;
	g_message_desc := NULL;
	-- Update xxcs_ib_item_creation_ext_tbl tbl with error
	handle_ext_tbl('SUCCESS', NULL, hasp_rec.row_id);

          END IF; -- return status rel API
        END IF; -- return status instance API
      ELSE
        -- Add mark if API did not work (did not enter to this part of IF) then do not do UPDATE
        l_api_mark := 'Y';
        /*
        dbms_output.put_line('Error - parent instance' || to_char(l_parent_instance_id)  ||
                             ' And Child Instance (item: ' ||l_new_item ||'): The component already process ');

        fnd_file.put_line(fnd_file.log,
                  'Error - parent instance' || to_char(l_parent_instance_id)  ||
                  ' And Child Instance (item: ' ||l_new_item ||'): The component already process ' || chr(10));
        */
        IF l_error IS NULL THEN
          l_error := 'Error - parent instance ' ||
	         to_char(l_parent_instance_id) ||
	         ' And Child Instance (item: ' || l_new_item ||
	         '): The component already process';
        END IF; -- l_error

        g_message_desc := NULL;
        -- Update xxcs_ib_item_creation_ext_tbl tbl with error
        handle_ext_tbl('WARNING',
	           'Error - parent instance' ||
	           to_char(l_parent_instance_id) ||
	           ' And Child Instance (item: ' || l_new_item ||
	           '): The component already process ',
	           hasp_rec.row_id);
      END IF; -- l_component_id IS NOT NULL AND l_instance_exist IS NULL
    END LOOP;
    ------
    IF l_error IS NOT NULL THEN
      -- change return errbuf to string
      errbuf  := 'Error Create Relation Between Parent Instance';
      retcode := '1';
    END IF;
  END create_instance_ext;

  --------------------------------------------------------------------
  --  customization code: CUST016 - 1.4 - Update Related -S items
  --  name:               upd_item_att9
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      16/01/2012
  --  Purpose :           Objet would like to automate the process that
  --                      serves for 'SN Reporting' Quality plan which
  --                      currently should be done by human intervention.
  --
  --                      Install Base components are created by a customization
  --                      that retrieves information from Quality plan 'SN Reporting'.
  --                      This plan is dependent (among other things) on Item Setup ?
  --                      updates in Attribute 9.
  --                      The purpose of this customization is to save the human
  --                      intervention by updating the Item Attribute 9 with its
  --                      corresponding Install Base item automatically.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/08/2010    Dalit A. Raviv  initial build
  --  1.1   21/03/2012    Dalit A. Raviv  Support -P items
  --  1.2   28/03/2012    Dalit A. Raviv  add profile that will hold date
  --                                      we will allways look at the creation date
  --                                      of the item that is bigger then the value at the profile.
  -----------------------------------------------------------------------
  PROCEDURE upd_item_att9(errbuf  OUT VARCHAR2,
		  retcode OUT VARCHAR2) IS
    CURSOR item_to_upd_pop_c IS
    -- for now all organizations that item exist in - the update will occur
    -- all items that have install base trackable -s items and attribute9 is null
    -- this items need to update attribute9 with id of -s item.
      SELECT msi.segment1             item,
	 msi.inventory_item_id    item_id,
	 msi.organization_id      organization_id,
	 msi.attribute9,
	 item_s.segment1          sitem,
	 item_s.inventory_item_id sitem_id,
	 item_s.organization_id   sorganization_id
      FROM   mtl_system_items_b msi,
	 ( -- all items -s that are install base trackable
	  SELECT msib.segment1,
	          msib.inventory_item_id,
	          msib.organization_id
	  FROM   mtl_system_items_b msib
	  WHERE  msib.organization_id = 91
	  AND    msib.segment1 LIKE '%-S'
	  AND    msib.comms_nl_trackable_flag = 'Y') item_s,
	 (SELECT fnd_profile.value('XXCS_RELATED_S_ITEMS_CREATION_DATE') item_c_date -- 1.2 28/03/2012 Dalit A. Raviv
	  FROM   dual) item_c_date
      WHERE  msi.organization_id = 91
      AND    msi.creation_date >
	 to_date(item_c_date.item_c_date, 'dd/mm/yyyy') -- 1.2 28/03/2012 Dalit A. Raviv
      AND    msi.segment1 || '-S' = item_s.segment1
      AND    msi.organization_id = item_s.organization_id
      AND    msi.attribute9 IS NULL
      UNION
      -- In order to support items with -P relations to item -S
      SELECT msi.segment1             item,
	 msi.inventory_item_id    item_id,
	 msi.organization_id      organization_id,
	 msi.attribute9,
	 item_s.segment1          sitem,
	 item_s.inventory_item_id sitem_id,
	 item_s.organization_id   sorganization_id
      FROM   mtl_system_items_b msi,
	 ( -- all items -s that are install base trackable
	  SELECT msib.segment1,
	          msib.inventory_item_id,
	          msib.organization_id
	  FROM   mtl_system_items_b msib
	  WHERE  msib.organization_id = 91
	  AND    msib.segment1 LIKE '%-S'
	  AND    msib.comms_nl_trackable_flag = 'Y') item_s,
	 (SELECT fnd_profile.value('XXCS_RELATED_S_ITEMS_CREATION_DATE') item_c_date -- 1.2 28/03/2012 Dalit A. Raviv
	  FROM   dual) item_c_date
      WHERE  msi.organization_id = 91
      AND    msi.creation_date >
	 to_date(item_c_date.item_c_date, 'dd/mm/yyyy') -- 1.2 28/03/2012 Dalit A. Raviv
      AND    msi.segment1 LIKE '%-P'
      AND    substr(msi.segment1, 1, length(msi.segment1) - 2) =
	 substr(item_s.segment1, 1, length(item_s.segment1) - 2)
      AND    msi.organization_id = item_s.organization_id
      AND    msi.attribute9 IS NULL;

  BEGIN
    errbuf  := NULL;
    retcode := 0;

    --fnd_global.apps_initialize(3850,50623,660);
    FOR item_to_upd_pop_r IN item_to_upd_pop_c LOOP
      fnd_file.put_line(fnd_file.log, '------------------------------');
      fnd_file.put_line(fnd_file.log,
		'Item: ' || item_to_upd_pop_r.item || ', Id; ' ||
		item_to_upd_pop_r.item_id || ', Organization: ' ||
		item_to_upd_pop_r.organization_id);
      BEGIN
        UPDATE mtl_system_items_b msi
        SET    attribute9 = item_to_upd_pop_r.sitem_id
        WHERE  inventory_item_id = item_to_upd_pop_r.item_id
        AND    msi.organization_id = item_to_upd_pop_r.organization_id;

        COMMIT;
        dbms_output.put_line('SUCCESS');
        fnd_file.put_line(fnd_file.log, 'SUCCESS');
      EXCEPTION
        WHEN OTHERS THEN
          dbms_output.put_line('ERROR: Failed to update item' ||
		       substr(SQLERRM, 1, 240));
          fnd_file.put_line(fnd_file.log,
		    'ERROR: Failed to update item' ||
		    substr(SQLERRM, 1, 240));
      END;
      /*ego_item_pub.process_item(p_api_version            => 1.0,
                                p_init_msg_list          => fnd_api.G_TRUE,
                                p_commit                 => fnd_api.G_FALSE,
                                p_transaction_type       => 'UPDATE', -- EGO_ITEM_PUB.G_TTYPE_UPDATE, --
                                p_inventory_item_id      => item_to_upd_pop_r.item_id,
                                p_organization_id        => item_to_upd_pop_r.organization_id,
                                --p_master_organization_id =>91,
                                --p_attribute_category
                                p_attribute9             => to_char(item_to_upd_pop_r.Sitem_id),
                                x_inventory_item_id      => x_inventory_item_id,
                                x_organization_id        => x_organization_id,
                                x_return_status          => x_return_status,
                                x_msg_count              => x_msg_count,
                                x_msg_data               => x_msg_data);

      if x_return_status != 'S' then
        retcode := 1;
        errbuf  := 'Not All Items were updated , show log.';

        for i in 1 .. x_msg_count loop
          l_count := i;
          error_handler.get_message(x_msg_data,
                                    l_count,
                                    l_entity_id,
                                    l_entity_type);

          dbms_output.put_line('ERROR: '||x_return_status || ' ' || x_msg_data);
          fnd_file.put_line(fnd_file.log, 'ERROR: '||x_return_status || ' ' || x_msg_data);
          rollback;
        end loop;
      else
        dbms_output.put_line('SUCCESS');
        fnd_file.put_line(fnd_file.log, 'SUCCESS');
        commit;
      end if;  -- return status  */
    END LOOP;
  END upd_item_att9;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036464
  --          This function returns the primary site for give cust account and org id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  15/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_primary_party_site_id(p_cust_account_id IN NUMBER,
			 p_org_id          IN NUMBER,
			 p_site_use_code   IN VARCHAR2,
			 p_mode            IN VARCHAR2)
    RETURN NUMBER IS
    l_cust_acct_site_id NUMBER;
  BEGIN
    SELECT decode(p_mode,
	      'PARTY_SITE',
	      hps.party_site_id,
	      'SITE_USE',
	      hcsua.site_use_id)
    INTO   l_cust_acct_site_id
    FROM   hz_cust_acct_sites_all hcasa,
           hz_cust_site_uses_all  hcsua,
           hz_party_sites         hps
    WHERE  hcasa.cust_account_id = p_cust_account_id
    AND    hcasa.org_id = nvl(p_org_id, hcasa.org_id)
    AND    hcasa.org_id = hcsua.org_id
    AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
    AND    hcsua.site_use_code = p_site_use_code
    AND    hcasa.party_site_id = hps.party_site_id
    AND    hcsua.primary_flag = 'Y'
    AND    hcasa.status = 'A'
    AND    hcsua.status = 'A'
    AND    hps.status = 'A';

    RETURN l_cust_acct_site_id;
  END get_primary_party_site_id;

  --------------------------------------------------------------------------------------------
  -- Purpose: Change - CHG0042574
  --          This procedure will create new item instances in IB. (based on create_missing_instance)
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  12-Apr-2018  Dan M.          Initial Build
  -- 1.1  03-Sep-2018  Dan M.          CHG0043858 : Update active end date for terminated machines, correct attribute 6/7 formats
  -- 1.2  09/01/2020   Bellona.B       CHG0047219 - Comment IB create instance as suggested by Adi Safin.
  -- --------------------------------------------------------------------------------------------
  PROCEDURE create_missing_instance_single(p_data_rec           tp_data_rec_type,
			       p_instance_id        NUMBER,
			       p_parent_instance_id NUMBER,
			       p_action_done        OUT VARCHAR2,
			       p_error_code         OUT NUMBER,
			       p_error_desc         OUT VARCHAR2) IS

    l_return_status             VARCHAR2(2000);
    l_msg_count                 NUMBER;
    l_msg_data                  VARCHAR2(2500);
    l_msg_index_out             NUMBER;
    l_init_msg_lst              VARCHAR2(500);
    l_trackable_flag            VARCHAR2(1);
    l_serial_control            NUMBER;
    l_item_segment              VARCHAR2(240);
    l_instance_exist            VARCHAR2(1);
    l_serial_number             VARCHAR2(50);
    l_instance_id               NUMBER;
    l_instance_number           VARCHAR2(30);
    l_object_version_number     NUMBER;
    l_instance_party_id         NUMBER;
    l_ip_account_id             NUMBER;
    l_primary_ship_site         NUMBER;
    l_install_site_id           NUMBER;
    l_current_site_id           NUMBER;
    l_bill_site_id              NUMBER;
    l_ship_site_id              NUMBER;
    l_attribute12               VARCHAR2(240);
    l_validation_level          NUMBER := NULL;
    l_master_organization_id    NUMBER;
    l_instance_rec              csi_datastructures_pub.instance_rec;
    l_instance_rec_null         csi_datastructures_pub.instance_rec;
    l_party_tbl                 csi_datastructures_pub.party_tbl;
    l_party_tbl_null            csi_datastructures_pub.party_tbl;
    l_account_tbl               csi_datastructures_pub.party_account_tbl;
    l_account_tbl_null          csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl        csi_datastructures_pub.pricing_attribs_tbl;
    l_pricing_attrib_tbl_null   csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl       csi_datastructures_pub.organization_units_tbl;
    l_org_assignments_tbl_null  csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl      csi_datastructures_pub.instance_asset_tbl;
    l_asset_assignment_tbl_null csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec                   csi_datastructures_pub.transaction_rec;
    l_txn_rec_null              csi_datastructures_pub.transaction_rec;
    l_txn_rec_chi               csi_datastructures_pub.transaction_rec;
    l_txn_rec_chi_null          csi_datastructures_pub.transaction_rec;
    l_ext_attrib_values         csi_datastructures_pub.extend_attrib_values_tbl;
    l_ext_attrib_values_null    csi_datastructures_pub.extend_attrib_values_tbl;
    l_relationship_tbl          csi_datastructures_pub.ii_relationship_tbl;
    l_relationship_tbl_null     csi_datastructures_pub.ii_relationship_tbl;
    l_instance_id_lst           csi_datastructures_pub.id_tbl;
    l_instance_id_lst_null      csi_datastructures_pub.id_tbl;
    l_ip_account_ovn            NUMBER;
    l_instance_party_ovn        NUMBER;
    l_primary_bill_site         NUMBER;
    l_parent_instance_id        NUMBER;
    l_max_trs_time              DATE; -- CHG0043858 : Get max transaction timestamp
    l_item_status               VARCHAR2(255); -- CHG0043858 : For getting item status
    l_product_code              mtl_system_items_b.segment1%TYPE; -- CHG0047219 : For getting product code
  BEGIN
    p_error_code := 0; -- Initialize error code
    p_error_desc := NULL;

    l_master_organization_id := xxinv_utils_pkg.get_master_organization_id;

    -- Start - Initialize all variables
    l_instance_rec         := l_instance_rec_null;
    l_txn_rec              := l_txn_rec_null;
    l_party_tbl            := l_party_tbl_null;
    l_account_tbl          := l_account_tbl_null;
    l_pricing_attrib_tbl   := l_pricing_attrib_tbl_null;
    l_org_assignments_tbl  := l_org_assignments_tbl_null;
    l_asset_assignment_tbl := l_asset_assignment_tbl_null;
    l_txn_rec_chi          := l_txn_rec_chi_null; -- used by API
    l_ext_attrib_values    := l_ext_attrib_values_null; -- used by API
    l_relationship_tbl     := l_relationship_tbl_null; -- used by API
    l_instance_id_lst      := l_instance_id_lst_null; -- used by API

    l_return_status         := NULL;
    l_msg_count             := NULL;
    l_msg_data              := NULL;
    l_msg_index_out         := NULL;
    l_trackable_flag        := NULL;
    l_item_segment          := NULL;
    l_instance_exist        := NULL;
    l_serial_number         := NULL;
    l_instance_id           := NULL;
    l_instance_number       := NULL;
    l_object_version_number := NULL;
    l_attribute12           := NULL;
    l_primary_ship_site     := NULL;
    l_install_site_id       := NULL;
    l_current_site_id       := NULL;
    l_bill_site_id          := NULL;
    l_ship_site_id          := NULL;
    l_serial_control        := NULL;

    -- End Variable Initialization
    -----
    --
    -----

    /* Get IB_Trackable Indication, SERIAL_NUMBER_CONTROL_CODE, model # of Item*/
    BEGIN
      SELECT nvl(comms_nl_trackable_flag, 'N'),
	 serial_number_control_code,
	 segment1 -- used for messaging
      INTO   l_trackable_flag,
	 l_serial_control,
	 l_item_segment
      FROM   mtl_system_items_b
      WHERE  inventory_item_id = p_data_rec.inventory_item_id
      AND    organization_id = l_master_organization_id;

    EXCEPTION
      WHEN no_data_found THEN
        p_error_desc := 'Inventory Item ID: ' ||
		p_data_rec.inventory_item_id ||
		' not found in Oracle EBS. Record skipped';
        p_error_code := -1;
        RETURN;
      WHEN OTHERS THEN

        p_error_desc := 'Unexpected error while fetching IB Trackable flag for Item ID: ' ||
		p_data_rec.inventory_item_id || '. Record skipped.' ||
		chr(10) || '  ERROR:' || SQLERRM;
        p_error_code := -1;
        RETURN;
    END;

    -- CHG0043858 : Get status description by ID
    BEGIN
      SELECT cis.name
      INTO   l_item_status
      FROM   csi_instance_statuses cis
      WHERE  p_data_rec.instance_status_id = cis.instance_status_id;
    EXCEPTION
      WHEN OTHERS THEN
        p_error_desc := 'Unexpected error while fetching status for instance: ' ||
		p_data_rec.instance_status_id ||
		' error. Record skipped.';
        p_error_code := -1;
        RETURN;
    END;

    /* End checking IB trackable flag of item and master org combination */

    -- sites exist - already validated
    BEGIN

      /* -- current site. already validated (before)

      begin

      if p_data_rec.current_site_id is not null then
        select hps.party_site_id
          into l_current_site_id
          from hz_cust_acct_sites_all hcasa, hz_party_sites hps
         where hcasa.cust_acct_site_id = p_data_rec.current_site_id
           and hcasa.party_site_id = hps.party_site_id
           and hcasa.status = 'A'
           and hps.status = 'A';
       else
          l_current_site_id := null;
       end if;

      exception
        when no_data_found then
          fnd_file.put_line(fnd_file.log,
                            'EXCEPTION_NO_DATA_FOUND_2 : p_data_rec.current_site_id = ' ||
                            p_data_rec.current_site_id);
      end;*/

      -- Install site

      BEGIN

        IF p_data_rec.install_site_id IS NOT NULL THEN
          SELECT hps.party_site_id
          INTO   l_install_site_id
          FROM   hz_cust_acct_sites_all hcasa,
	     hz_party_sites         hps
          WHERE  hcasa.cust_acct_site_id = p_data_rec.install_site_id
          AND    hcasa.party_site_id = hps.party_site_id
          AND    hcasa.status = 'A'
          AND    hps.status = 'A';
        ELSE
          l_install_site_id := NULL;
        END IF;

      EXCEPTION
        WHEN no_data_found THEN
          fnd_file.put_line(fnd_file.log,
		    'EXCEPTION_NO_DATA_FOUND_3 : p_data_rec.install_site_id = ' ||
		    p_data_rec.install_site_id);
      END;

      -- Ship to site
      IF p_data_rec.ship_to_site_id IS NULL THEN
        l_ship_site_id := get_primary_party_site_id(p_data_rec.owner_account_id,
				    p_data_rec.ship_to_ou_id,
				    'SHIP_TO',
				    'SITE_USE');
      ELSE

        BEGIN

          SELECT hcsua.site_use_id
          INTO   l_ship_site_id
          FROM   hz_cust_acct_sites_all hcasa,
	     hz_cust_site_uses_all  hcsua
          WHERE  hcasa.cust_acct_site_id = p_data_rec.ship_to_site_id
          AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
          AND    hcsua.site_use_code = 'SHIP_TO'
          AND    hcasa.status = 'A'
          AND    hcsua.status = 'A';

        EXCEPTION
          WHEN no_data_found THEN
	fnd_file.put_line(fnd_file.log,
		      'EXCEPTION_NO_DATA_FOUND_4 : p_data_rec.ship_to_site_id = ' ||
		      p_data_rec.ship_to_site_id);
        END;
      END IF;

      IF l_ship_site_id IS NULL THEN
        p_error_desc := 'Ship To Site ID is not valid';
        p_error_code := -1;
        RETURN;
      END IF;

      -- Bill to site.

      IF p_data_rec.bill_to_site_id IS NULL THEN
        l_bill_site_id := get_primary_party_site_id(p_data_rec.owner_account_id,
				    p_data_rec.ship_to_ou_id,
				    'BILL_TO',
				    'SITE_USE');
      ELSE

        BEGIN

          SELECT hcsua.site_use_id
          INTO   l_bill_site_id
          FROM   hz_cust_acct_sites_all hcasa,
	     hz_cust_site_uses_all  hcsua
          WHERE  hcasa.cust_acct_site_id = p_data_rec.bill_to_site_id
          AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
          AND    hcsua.site_use_code = 'BILL_TO'
          AND    hcasa.status = 'A'
          AND    hcsua.status = 'A';

        EXCEPTION
          WHEN no_data_found THEN
	fnd_file.put_line(fnd_file.log,
		      'EXCEPTION_NO_DATA_FOUND_5 : p_data_rec.bill_to_site_id = ' ||
		      p_data_rec.bill_to_site_id);

        END;
      END IF;

      IF l_bill_site_id IS NULL THEN
        p_error_desc := 'Bill to  Site ID is not valid';
        p_error_code := -1;
        RETURN;
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        p_error_desc := 'Inventory Item ID: ' ||
		p_data_rec.inventory_item_id ||
		' Error getting site IDs - skipping';
        p_error_code := -1;
        RETURN;
    END;
    -- get item instance information (if exists)

    l_current_site_id := l_install_site_id;
    IF l_serial_control <> 1 THEN
      /* Get SN, Object Version number (and oracle IB Existance)*/
      BEGIN

        SELECT aa.serial_number,
	   aa.instance_number,
	   aa.object_version_number,
	   aa.attribute12,
	   'Y'
        INTO   l_serial_number,
	   l_instance_number,
	   l_object_version_number,
	   l_attribute12,
	   l_instance_exist -- Initialize value : if item exists. else will be set to 'N'
        FROM   (SELECT cii.serial_number,
	           cii.instance_id,
	           cii.instance_number,
	           cii.object_version_number,
	           cii.attribute12
	    FROM   csi_item_instances cii
	    WHERE  cii.instance_id = p_instance_id) aa
        WHERE  rownum = 1;

      EXCEPTION
        WHEN no_data_found THEN
          l_instance_exist := 'N'; -- does not exist in Oracle IB, create item will be called.
        WHEN OTHERS THEN

          p_error_desc := 'Unexpected error while checking if instance exists for Item ID: ' ||
		  p_data_rec.inventory_item_id || ' and serial ' ||
		  p_data_rec.serial_number || '. Record skipped.' ||
		  chr(10) || '  ERROR:' || SQLERRM;
          p_error_code := -1;
          RETURN;
      END;

      l_instance_id := p_instance_id;

      IF l_instance_exist = 'Y' THEN

        /* get max transaction date */

        BEGIN

          SELECT MAX(creation_date) + 0.0007 -- Advance by 1 minute from actual creation date
          INTO   l_max_trs_time
          FROM   csi_item_instances_h cih
          WHERE  cih.instance_id = l_instance_id;

        EXCEPTION
          WHEN OTHERS THEN
	l_max_trs_time := SYSDATE;
        END;

        p_action_done := 'UPDATED';
        -- call Update existing Oracle IB API with SF Information

        -- Update specific item

        l_instance_rec.instance_id           := l_instance_id;
        l_instance_rec.instance_number       := l_instance_number;
        l_instance_rec.object_version_number := l_object_version_number;

        /* Missing attributes on update ! CTASK0037631!! */

        l_instance_rec.attribute3  := p_data_rec.attribute3;
        l_instance_rec.attribute6  := p_data_rec.attribute6; -- CHG0043858 : Change attribute 6/7 format
        l_instance_rec.attribute7  := p_data_rec.attribute7; -- CHG0043858 : Change attribute 6/7 format
        l_instance_rec.attribute8  := p_data_rec.attribute8;
        l_instance_rec.attribute17 := p_data_rec.attribute17; -- Version 1.2  - CTASK0037631 : Add Attribute17 to sync

        l_instance_rec.instance_status_id := p_data_rec.instance_status_id;

        l_instance_rec.location_type_code         := 'HZ_PARTY_SITES';
        l_instance_rec.location_id                := l_current_site_id;
        l_instance_rec.install_location_type_code := 'HZ_PARTY_SITES';
        l_instance_rec.install_location_id        := l_install_site_id;

        l_instance_rec.install_location_id := l_install_site_id;
        l_instance_rec.location_id         := l_install_site_id;
        l_instance_rec.install_date        := p_data_rec.install_date;
        /* end of addd update section */

        --TXN
        l_txn_rec.transaction_id              := NULL;
        l_txn_rec.transaction_date            := trunc(SYSDATE);
        l_txn_rec.source_transaction_date     := trunc(SYSDATE);
        l_txn_rec.transaction_type_id         := 1;
        l_txn_rec.txn_sub_type_id             := NULL;
        l_txn_rec.source_group_ref_id         := NULL;
        l_txn_rec.source_group_ref            := '';
        l_txn_rec.source_header_ref_id        := NULL;
        l_txn_rec.source_header_ref           := '';
        l_txn_rec.source_line_ref_id          := NULL;
        l_txn_rec.source_line_ref             := '';
        l_txn_rec.source_dist_ref_id1         := NULL;
        l_txn_rec.source_dist_ref_id2         := NULL;
        l_txn_rec.inv_material_transaction_id := NULL;
        l_txn_rec.transaction_quantity        := NULL;
        l_txn_rec.transaction_uom_code        := '';
        l_txn_rec.transacted_by               := NULL;
        l_txn_rec.transaction_status_code     := '';
        l_txn_rec.transaction_action_code     := '';
        l_txn_rec.message_id                  := NULL;
        l_txn_rec.object_version_number       := '';
        l_txn_rec.split_reason_code           := '';

        -- update location only if does not have parent
        IF l_parent_instance_id IS NULL THEN
          l_instance_rec.location_type_code         := 'HZ_PARTY_SITES';
          l_instance_rec.location_id                := l_current_site_id;
          l_instance_rec.install_location_type_code := 'HZ_PARTY_SITES';
          l_instance_rec.install_location_id        := l_install_site_id;
        END IF;

        l_instance_rec.install_date := p_data_rec.install_date;

        SELECT cipdv.instance_party_id,
	   cipdv.object_version_number
        INTO   l_instance_party_id,
	   l_instance_party_ovn
        FROM   csi_inst_party_details_v cipdv
        WHERE  cipdv.instance_id = l_instance_id
        AND    cipdv.relationship_type_code = 'OWNER';

        --PARTY
        l_party_tbl(1).instance_party_id := l_instance_party_id;
        l_party_tbl(1).instance_id := l_instance_id;
        l_party_tbl(1).party_source_table := 'HZ_PARTIES';
        l_party_tbl(1).party_id := p_data_rec.owner_party_id;
        l_party_tbl(1).relationship_type_code := 'OWNER';
        l_party_tbl(1).contact_flag := 'N';
        l_party_tbl(1).contact_ip_id := NULL;
        l_party_tbl(1).active_end_date := NULL;
        l_party_tbl(1).object_version_number := l_instance_party_ovn;
        l_party_tbl(1).primary_flag := NULL;
        l_party_tbl(1).preferred_flag := 'N';

        --ACCOUNTS

        BEGIN
          SELECT cpadv.ip_account_id,
	     cpadv.object_version_number
          INTO   l_ip_account_id,
	     l_ip_account_ovn
          FROM   csi_party_acct_details_v cpadv
          WHERE  1 = 1
          AND    cpadv.instance_party_id IN
	     (SELECT cipd.instance_party_id
	       FROM   csi_inst_party_details_v cipd
	       WHERE  cipd.instance_id = l_instance_id
	       AND    cipd.relationship_type_code = 'OWNER');
        EXCEPTION
          WHEN OTHERS THEN
	-- Missing account, create
	l_ip_account_id := csi_ip_accounts_s.nextval;
	/*
            SELECT csi_ip_accounts_s.nextval
              INTO l_ip_account_id
              FROM dual;
            */
	l_ip_account_ovn := 1;
        END;

        l_account_tbl(1).ip_account_id := l_ip_account_id;
        l_account_tbl(1).parent_tbl_index := 1;
        l_account_tbl(1).instance_party_id := l_instance_party_id;
        l_account_tbl(1).party_account_id := p_data_rec.owner_party_account_id;
        l_account_tbl(1).relationship_type_code := 'OWNER';
        l_account_tbl(1).active_end_date := NULL;
        l_account_tbl(1).bill_to_address := l_bill_site_id;
        l_account_tbl(1).ship_to_address := l_ship_site_id;
        l_account_tbl(1).object_version_number := l_ip_account_ovn;

        -- transaction
        l_txn_rec.transaction_id              := NULL;
        l_txn_rec.transaction_date            := trunc(SYSDATE);
        l_txn_rec.source_transaction_date     := trunc(SYSDATE);
        l_txn_rec.transaction_type_id         := 1;
        l_txn_rec.txn_sub_type_id             := NULL;
        l_txn_rec.source_group_ref_id         := NULL;
        l_txn_rec.source_group_ref            := '';
        l_txn_rec.source_header_ref_id        := NULL;
        l_txn_rec.source_header_ref           := '';
        l_txn_rec.source_line_ref_id          := NULL;
        l_txn_rec.source_line_ref             := '';
        l_txn_rec.source_dist_ref_id1         := NULL;
        l_txn_rec.source_dist_ref_id2         := NULL;
        l_txn_rec.inv_material_transaction_id := NULL;
        l_txn_rec.transaction_quantity        := NULL;
        l_txn_rec.transaction_uom_code        := '';
        l_txn_rec.transacted_by               := NULL;
        l_txn_rec.transaction_status_code     := '';
        l_txn_rec.transaction_action_code     := '';
        l_txn_rec.message_id                  := NULL;
        l_txn_rec.object_version_number       := '';
        l_txn_rec.split_reason_code           := '';

        l_msg_data     := NULL;
        l_init_msg_lst := NULL;
        fnd_msg_pub.initialize;

        IF upper(l_item_status) = 'TERMINATED' THEN
          l_instance_rec.active_end_date := greatest(p_data_rec.status_change_date,
				     l_max_trs_time); -- CHG0043858 : Set active end date on TERMINATED Machines.
          csi_item_instance_pub.expire_item_instance(p_api_version     => 1,
				     p_commit          => fnd_api.g_false,
				     p_expire_children => fnd_api.g_true, -- Expire also the children
				     p_instance_rec    => l_instance_rec,
				     p_txn_rec         => l_txn_rec,
				     x_instance_id_lst => l_instance_id_lst,
				     x_return_status   => l_return_status,
				     x_msg_count       => l_msg_count,
				     x_msg_data        => l_msg_data);

        ELSE

          csi_item_instance_pub.update_item_instance(p_api_version           => 1,
				     p_commit                => fnd_api.g_false,
				     p_init_msg_list         => l_init_msg_lst,
				     p_validation_level      => l_validation_level,
				     p_instance_rec          => l_instance_rec,
				     p_ext_attrib_values_tbl => l_ext_attrib_values,
				     p_party_tbl             => l_party_tbl,
				     p_account_tbl           => l_account_tbl,
				     p_pricing_attrib_tbl    => l_pricing_attrib_tbl,
				     p_org_assignments_tbl   => l_org_assignments_tbl,
				     p_asset_assignment_tbl  => l_asset_assignment_tbl,
				     p_txn_rec               => l_txn_rec,
				     x_instance_id_lst       => l_instance_id_lst,
				     x_return_status         => l_return_status,
				     x_msg_count             => l_msg_count,
				     x_msg_data              => l_msg_data);

        END IF;

        IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
          -- Oracle IB update API error
          --l_error_data_counter := l_error_data_counter + 1;
          fnd_msg_pub.get(p_msg_index     => -1,
		  p_encoded       => 'F',
		  p_data          => l_msg_data,
		  p_msg_index_out => l_msg_index_out);

          p_error_desc := 'Unexpected error while updating IB (1): ' ||
		  substr(l_msg_data, 1, 200);
          p_error_code := -1;
          -- rollback;  --CHG0042574 hotfix - commit/rollback
        ELSE
          p_error_code := 0;

          -- commit; --CHG0042574 hotfix - commit/rollback
        END IF;

      ELSE
      --CHG0047219 start
       select m.segment1 into l_product_code
         from mtl_system_items_b m
        where m.inventory_item_id = p_data_rec.inventory_item_id
          and m.organization_id = l_master_organization_id;
            
        fnd_file.put_line(fnd_file.log,
                  'ASSET SN# : p_data_rec.serial_number = ' ||
                  p_data_rec.serial_number||
                  '. PRODUCT CODE : l_product_code = '||
                  l_product_code);      
      /*
        p_action_done := 'CREATED';
        -- Create new Oracle IB Instance

        --            l_primary_ship_site := p_data_rec.SHIP_TO_SITE_ID;

        \* Site information received directly from SF  - -- DANME 16-apr-2018*\

        --            l_current_site_id := p_data_rec.CURRENT_SITE_ID;
        --            l_install_site_id := p_data_rec.INSTALL_SITE_ID;

        \*
        SELECT csi_item_instances_s.nextval
          INTO l_instance_id FROM dual;
        *\
        l_instance_id     := csi_item_instances_s.nextval;
        l_instance_number := l_instance_id;

        \* SELECT csi_i_parties_s.nextval INTO l_instance_party_id FROM dual; *\
        l_instance_party_id := csi_i_parties_s.nextval;

        \* SELECT csi_ip_accounts_s.nextval INTO l_ip_account_id FROM dual; *\
        l_ip_account_id := csi_ip_accounts_s.nextval;

        l_instance_rec.instance_id                := l_instance_id;
        l_instance_rec.instance_number            := l_instance_number;
        l_instance_rec.serial_number              := p_data_rec.serial_number;
        l_instance_rec.instance_status_id         := p_data_rec.instance_status_id;
        l_instance_rec.inv_master_organization_id := l_master_organization_id;

        l_instance_rec.inventory_item_id := p_data_rec.inventory_item_id;

        l_instance_rec.quantity           := p_data_rec.quantity;
        l_instance_rec.unit_of_measure    := p_data_rec.unit_of_measure;
        l_instance_rec.inventory_revision := p_data_rec.inventory_revision;

        l_instance_rec.attribute3  := p_data_rec.attribute3;
        l_instance_rec.attribute4  := p_data_rec.attribute4;
        l_instance_rec.attribute5  := p_data_rec.attribute5;
        l_instance_rec.attribute6  := p_data_rec.attribute6; -- CHG0043858 : Change attribute 6/7 format
        l_instance_rec.attribute7  := p_data_rec.attribute7; -- CHG0043858 : Change attribute 6/7 format
        l_instance_rec.attribute8  := p_data_rec.attribute8;
        l_instance_rec.attribute12 := p_data_rec.attribute12;
        l_instance_rec.attribute17 := p_data_rec.attribute17; -- Version 1.2  - CTASK0037631 : Add Attribute17 to sync

        IF upper(l_item_status) = 'TERMINATED' THEN
          l_instance_rec.active_end_date := greatest(p_data_rec.status_change_date,
				     l_max_trs_time); -- CHG0043858 : Set active end date on TERMINATED Machines.; -- CHG0043858 : Set active end date on TERMINATED Machines.
        END IF;

        l_instance_rec.customer_view_flag := 'N';
        l_instance_rec.merchant_view_flag := 'Y';
        l_instance_rec.sellable_flag      := 'N';

        l_instance_rec.location_type_code         := 'HZ_PARTY_SITES';
        l_instance_rec.location_id                := l_current_site_id;
        l_instance_rec.install_location_type_code := 'HZ_PARTY_SITES'; -- '';
        l_instance_rec.install_location_id        := l_install_site_id;

        l_instance_rec.manually_created_flag  := 'Y';
        l_instance_rec.creation_complete_flag := 'Y';

        l_instance_rec.install_location_id := l_install_site_id; -- p_data_rec.INSTALL_SITE_ID;
        l_instance_rec.location_id         := l_install_site_id; ---p_data_rec.INSTALL_SITE_ID;
        l_instance_rec.install_date        := p_data_rec.install_date;

        --PARTY
        l_party_tbl(1).instance_party_id := l_instance_party_id;
        l_party_tbl(1).instance_id := l_instance_id;
        l_party_tbl(1).party_source_table := 'HZ_PARTIES';
        l_party_tbl(1).party_id := p_data_rec.owner_party_id;
        l_party_tbl(1).relationship_type_code := 'OWNER';
        l_party_tbl(1).contact_flag := 'N';
        l_party_tbl(1).contact_ip_id := NULL;
        l_party_tbl(1).active_end_date := NULL;
        l_party_tbl(1).object_version_number := 1;
        l_party_tbl(1).primary_flag := NULL;
        l_party_tbl(1).preferred_flag := 'N';

        --ACCOUNTS
        l_account_tbl(1).ip_account_id := l_ip_account_id;
        l_account_tbl(1).parent_tbl_index := 1;
        l_account_tbl(1).instance_party_id := l_instance_party_id;
        l_account_tbl(1).party_account_id := p_data_rec.owner_party_account_id;
        l_account_tbl(1).relationship_type_code := 'OWNER';
        l_account_tbl(1).active_end_date := NULL;
        l_account_tbl(1).bill_to_address := l_bill_site_id;
        l_account_tbl(1).ship_to_address := l_ship_site_id;
        l_account_tbl(1).object_version_number := 1;

        --TXN
        l_txn_rec.transaction_id              := NULL;
        l_txn_rec.transaction_date            := trunc(SYSDATE);
        l_txn_rec.source_transaction_date     := trunc(SYSDATE);
        l_txn_rec.transaction_type_id         := 1;
        l_txn_rec.txn_sub_type_id             := NULL;
        l_txn_rec.source_group_ref_id         := NULL;
        l_txn_rec.source_group_ref            := '';
        l_txn_rec.source_header_ref_id        := NULL;
        l_txn_rec.source_header_ref           := '';
        l_txn_rec.source_line_ref_id          := NULL;
        l_txn_rec.source_line_ref             := '';
        l_txn_rec.source_dist_ref_id1         := NULL;
        l_txn_rec.source_dist_ref_id2         := NULL;
        l_txn_rec.inv_material_transaction_id := NULL;
        l_txn_rec.transaction_quantity        := NULL;
        l_txn_rec.transaction_uom_code        := '';
        l_txn_rec.transacted_by               := NULL;
        l_txn_rec.transaction_status_code     := '';
        l_txn_rec.transaction_action_code     := '';
        l_txn_rec.message_id                  := NULL;
        l_txn_rec.object_version_number       := '';
        l_txn_rec.split_reason_code           := '';

        csi_item_instance_pub.create_item_instance(p_api_version           => 1,
				   p_commit                => fnd_api.g_false,
				   p_init_msg_list         => l_init_msg_lst,
				   p_validation_level      => l_validation_level,
				   p_instance_rec          => l_instance_rec,
				   p_ext_attrib_values_tbl => l_ext_attrib_values,
				   p_party_tbl             => l_party_tbl,
				   p_account_tbl           => l_account_tbl,
				   p_pricing_attrib_tbl    => l_pricing_attrib_tbl,
				   p_org_assignments_tbl   => l_org_assignments_tbl,
				   p_asset_assignment_tbl  => l_asset_assignment_tbl,
				   p_txn_rec               => l_txn_rec,
				   x_return_status         => l_return_status,
				   x_msg_count             => l_msg_count,
				   x_msg_data              => l_msg_data);

        IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
          -- Oracle IB create API error
          --l_error_data_counter := l_error_data_counter + 1;

          fnd_msg_pub.get(p_msg_index     => -1,
		  p_encoded       => 'F',
		  p_data          => l_msg_data,
		  p_msg_index_out => l_msg_index_out);

          -- rollback; --CHG0042574 hotfix - commit/rollback
          p_error_desc := 'Unexpected error while creating item in IB (2): ' ||
		  substr(l_msg_data, 1, 200);
          p_error_code := -1;
          RETURN;

        ELSE
          -- Oracle IB create API success
          -- commit;
          p_error_code := 0; --CHG0042574 hotfix - commit/rollback
          --exit;
        END IF;*/
      --CHG0047219 end  
      END IF;
    END IF;
    ------

  EXCEPTION
    WHEN OTHERS THEN
      p_error_desc := 'General Unexpected Error ' || SQLERRM;
      p_error_code := -1;
  END create_missing_instance_single;

  --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036464
  --          This procedure will create new item instances if it does not exist for serial number
  --          and part number or update existing instances with SF ID. This porcedure will be called
  --          from a consurrent program
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                    Description
  -- 1.0  15/10/2015  Diptasurjya Chatterjee  Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE create_missing_instance(errbuf  OUT VARCHAR2,
			retcode OUT VARCHAR2) IS

    CURSOR sf_missing_instances IS
      SELECT cii.*
      FROM   xxsf_csi_item_instances cii
      WHERE  cii.instance_id IS NULL;

    l_return_status  VARCHAR2(2000) := NULL;
    l_msg_count      NUMBER := NULL;
    l_msg_data       VARCHAR2(2500) := NULL;
    l_msg_index_out  NUMBER := NULL;
    l_init_msg_lst   VARCHAR2(500) := NULL;
    l_trackable_flag VARCHAR2(1) := NULL;
    l_serial_control NUMBER := NULL;
    l_item_segment   VARCHAR2(240) := NULL;
    l_instance_exist VARCHAR2(1) := 'N';

    l_serial_number         VARCHAR2(50);
    l_instance_id           NUMBER;
    l_instance_number       VARCHAR2(30);
    l_object_version_number NUMBER;
    l_instance_party_id     NUMBER;
    l_ip_account_id         NUMBER;
    l_primary_ship_site     NUMBER;
    l_install_site_id       NUMBER;
    l_current_site_id       NUMBER;
    l_bill_site_id          NUMBER;
    l_ship_site_id          NUMBER;
    l_attribute12           VARCHAR2(240);

    l_total_data_counter   NUMBER := 0;
    l_success_data_counter NUMBER := 0;
    l_error_data_counter   NUMBER := 0;

    l_no_account_id_counter      NUMBER := 0;
    l_skip_sf_id_present_counter NUMBER := 0;
    l_non_trackable_counter      NUMBER := 0;
    l_non_serial_counter         NUMBER := 0;
    l_non_serial_track_counter   NUMBER := 0;
    l_no_bill_ship_counter       NUMBER := 0;

    l_created_counter  NUMBER := 0;
    l_updated_counter  NUMBER := 0;
    l_validation_level NUMBER := NULL;

    l_master_organization_id    NUMBER;
    l_instance_rec              csi_datastructures_pub.instance_rec;
    l_instance_rec_null         csi_datastructures_pub.instance_rec;
    l_party_tbl                 csi_datastructures_pub.party_tbl;
    l_party_tbl_null            csi_datastructures_pub.party_tbl;
    l_account_tbl               csi_datastructures_pub.party_account_tbl;
    l_account_tbl_null          csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl        csi_datastructures_pub.pricing_attribs_tbl;
    l_pricing_attrib_tbl_null   csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl       csi_datastructures_pub.organization_units_tbl;
    l_org_assignments_tbl_null  csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl      csi_datastructures_pub.instance_asset_tbl;
    l_asset_assignment_tbl_null csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec                   csi_datastructures_pub.transaction_rec;
    l_txn_rec_null              csi_datastructures_pub.transaction_rec;
    l_txn_rec_chi               csi_datastructures_pub.transaction_rec;
    l_txn_rec_chi_null          csi_datastructures_pub.transaction_rec;
    l_ext_attrib_values         csi_datastructures_pub.extend_attrib_values_tbl;
    l_ext_attrib_values_null    csi_datastructures_pub.extend_attrib_values_tbl;
    l_relationship_tbl          csi_datastructures_pub.ii_relationship_tbl;
    l_relationship_tbl_null     csi_datastructures_pub.ii_relationship_tbl;
    l_instance_id_lst           csi_datastructures_pub.id_tbl;
    l_instance_id_lst_null      csi_datastructures_pub.id_tbl;

    l_error_code NUMBER := 0;
    l_error_desc VARCHAR2(2000) := NULL;
  BEGIN
    l_master_organization_id := xxinv_utils_pkg.get_master_organization_id;

    fnd_file.put_line(fnd_file.log,
	          ' ----------------- 1 -----------------' ||
	          to_char(SYSDATE, 'hh24:mi:ss'));
    FOR t IN sf_missing_instances LOOP
      l_total_data_counter := l_total_data_counter + 1;

      -- Start - Initialize all variables
      l_instance_rec         := l_instance_rec_null;
      l_txn_rec              := l_txn_rec_null;
      l_party_tbl            := l_party_tbl_null;
      l_account_tbl          := l_account_tbl_null;
      l_pricing_attrib_tbl   := l_pricing_attrib_tbl_null;
      l_org_assignments_tbl  := l_org_assignments_tbl_null;
      l_asset_assignment_tbl := l_asset_assignment_tbl_null;
      l_txn_rec_chi          := l_txn_rec_chi_null;
      l_ext_attrib_values    := l_ext_attrib_values_null;
      l_relationship_tbl     := l_relationship_tbl_null;
      l_instance_id_lst      := l_instance_id_lst_null;

      l_return_status         := NULL;
      l_msg_count             := NULL;
      l_msg_data              := NULL;
      l_msg_index_out         := NULL;
      l_trackable_flag        := NULL;
      l_item_segment          := NULL;
      l_instance_exist        := NULL;
      l_serial_number         := NULL;
      l_instance_id           := NULL;
      l_instance_number       := NULL;
      l_object_version_number := NULL;
      l_attribute12           := NULL;
      l_primary_ship_site     := NULL;
      l_install_site_id       := NULL;
      l_current_site_id       := NULL;
      l_bill_site_id          := NULL;
      l_ship_site_id          := NULL;
      l_serial_control        := NULL;
      -- End Variable Initialization
      -----
      --
      IF t.ship_to_ou_id IS NULL THEN
        l_no_account_id_counter := l_no_account_id_counter + 1;
        l_error_data_counter    := l_error_data_counter + 1;

        fnd_file.put_line(fnd_file.log,
		  'Owner account ID and Operating Unit not present in SFDC:: Item ID:' ||
		  t.inventory_item_id || ' Serial No:' ||
		  t.serial_number);

        CONTINUE;
      END IF;
      -----
      /* Start checking IB trackable flag of item and master org combination */
      BEGIN
        SELECT nvl(comms_nl_trackable_flag, 'N'),
	   serial_number_control_code,
	   segment1
        INTO   l_trackable_flag,
	   l_serial_control,
	   l_item_segment
        FROM   mtl_system_items_b
        WHERE  inventory_item_id = t.inventory_item_id
        AND    organization_id = l_master_organization_id;

      EXCEPTION
        WHEN no_data_found THEN
          fnd_file.put_line(fnd_file.log,
		    'Inventory Item ID: ' || t.inventory_item_id ||
		    ' not found in Oracle EBS. Record skipped');
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,
		    'Unexpected error while fetching IB Trackable flag for Item ID: ' ||
		    t.inventory_item_id || '. Record skipped.' ||
		    chr(10) || '  ERROR:' || SQLERRM);
      END;
      /* End checking IB trackable flag of item and master org combination */

      IF l_trackable_flag = 'Y' AND l_serial_control <> 1 THEN
        /* Start checking if Oracle IB exist */
        BEGIN
          SELECT aa.serial_number,
	     aa.instance_id,
	     aa.instance_number,
	     aa.object_version_number,
	     aa.attribute12
          INTO   l_serial_number,
	     l_instance_id,
	     l_instance_number,
	     l_object_version_number,
	     l_attribute12
          FROM   (SELECT cii.serial_number,
		 cii.instance_id,
		 cii.instance_number,
		 cii.object_version_number,
		 cii.attribute12
	      FROM   csi_item_instances cii
	      WHERE  cii.inventory_item_id = t.inventory_item_id
	      AND    (cii.serial_number = t.serial_number OR
		substr(cii.serial_number,
		         1,
		         instr(cii.serial_number, '-') - 1) =
		t.serial_number)
	      ORDER  BY cii.serial_number) aa
          WHERE  rownum = 1;

        EXCEPTION
          WHEN no_data_found THEN
	l_instance_exist := 'N';
          WHEN OTHERS THEN
	fnd_file.put_line(fnd_file.log,
		      'Unexpected error while checking if instance exists for Item ID: ' ||
		      t.inventory_item_id || ' and serial ' ||
		      t.serial_number || '. Record skipped.' ||
		      chr(10) || '  ERROR:' || SQLERRM);
        END;

        IF l_serial_number IS NULL THEN
          l_serial_number  := t.serial_number;
          l_instance_exist := 'N';
        ELSE
          l_instance_exist := 'Y';
        END IF;

        IF l_instance_exist = 'Y' THEN
          -- Update existing Oracle IB Instance with SFDC ID
          IF l_attribute12 IS NULL THEN
	-- SF_ID is not present in Oracle IB
	l_instance_rec.instance_id     := l_instance_id;
	l_instance_rec.instance_number := l_instance_number;
	l_instance_rec.attribute12     := t.attribute12;
	l_instance_rec.attribute1      := 'Migrated from SFDC';
	--l_instance_rec.inv_master_organization_id := FND_API.G_MISS_NUM;
	--l_instance_rec.vld_organization_id        := FND_API.G_MISS_NUM;
	l_instance_rec.object_version_number := l_object_version_number;

	l_txn_rec.transaction_id              := NULL;
	l_txn_rec.transaction_date            := trunc(SYSDATE);
	l_txn_rec.source_transaction_date     := trunc(SYSDATE);
	l_txn_rec.transaction_type_id         := 1;
	l_txn_rec.txn_sub_type_id             := NULL;
	l_txn_rec.source_group_ref_id         := NULL;
	l_txn_rec.source_group_ref            := '';
	l_txn_rec.source_header_ref_id        := NULL;
	l_txn_rec.source_header_ref           := '';
	l_txn_rec.source_line_ref_id          := NULL;
	l_txn_rec.source_line_ref             := '';
	l_txn_rec.source_dist_ref_id1         := NULL;
	l_txn_rec.source_dist_ref_id2         := NULL;
	l_txn_rec.inv_material_transaction_id := NULL;
	l_txn_rec.transaction_quantity        := NULL;
	l_txn_rec.transaction_uom_code        := '';
	l_txn_rec.transacted_by               := NULL;
	l_txn_rec.transaction_status_code     := '';
	l_txn_rec.transaction_action_code     := '';
	l_txn_rec.message_id                  := NULL;
	l_txn_rec.object_version_number       := '';
	l_txn_rec.split_reason_code           := '';

	l_msg_data     := NULL;
	l_init_msg_lst := NULL;
	fnd_msg_pub.initialize;

	csi_item_instance_pub.update_item_instance(p_api_version           => 1,
				       p_commit                => fnd_api.g_false,
				       p_init_msg_list         => l_init_msg_lst,
				       p_validation_level      => l_validation_level,
				       p_instance_rec          => l_instance_rec,
				       p_ext_attrib_values_tbl => l_ext_attrib_values,
				       p_party_tbl             => l_party_tbl,
				       p_account_tbl           => l_account_tbl,
				       p_pricing_attrib_tbl    => l_pricing_attrib_tbl,
				       p_org_assignments_tbl   => l_org_assignments_tbl,
				       p_asset_assignment_tbl  => l_asset_assignment_tbl,
				       p_txn_rec               => l_txn_rec,
				       x_instance_id_lst       => l_instance_id_lst,
				       x_return_status         => l_return_status,
				       x_msg_count             => l_msg_count,
				       x_msg_data              => l_msg_data);

	IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
	  -- Oracle IB update API error
	  l_error_data_counter := l_error_data_counter + 1;

	  fnd_msg_pub.get(p_msg_index     => -1,
		      p_encoded       => 'F',
		      p_data          => l_msg_data,
		      p_msg_index_out => l_msg_index_out);

	  fnd_file.put_line(fnd_file.log,
		        'API ERROR: while updating Oracle IB with SF_ID for Item : ' ||
		        l_item_segment || '(' ||
		        t.inventory_item_id || ') and serial ' ||
		        l_serial_number || '. Record skipped.' ||
		        chr(10) || '  ERROR:' || l_msg_data);

	  fnd_file.put_line(fnd_file.output,
		        'API ERROR: while updating Oracle IB with SF_ID for Item : ' ||
		        l_item_segment || '(' ||
		        t.inventory_item_id || ') and serial ' ||
		        l_serial_number || '. Record skipped.' ||
		        chr(10) || '  ERROR:' || l_msg_data);

	  ROLLBACK;

	  handle_log_tbl(p_parent_instance_id      => NULL, -- i n
		     p_parent_cust1            => NULL, -- i v
		     p_child_instance_id       => l_instance_id, -- i n
		     p_component_item          => l_item_segment, -- i v
		     p_component_serial_number => t.serial_number, -- i v
		     p_creation_status         => l_return_status, -- i v
		     p_creation_err_msg        => 'Got error when trying to update instance for COMPONENT: ' ||
				          l_item_segment ||
				          ' : ' ||
				          l_msg_data, -- i v
		     p_relation_staus          => NULL, -- i v
		     p_relation_err_msg        => NULL, -- i v
		     p_job                     => NULL, -- i n
		     p_error_code              => l_error_code, -- o n
		     p_error_desc              => l_error_desc);

	  --exit;
	  --
	ELSE
	  -- Oracle IB Update API success
	  l_success_data_counter := l_success_data_counter + 1;
	  l_updated_counter      := l_updated_counter + 1;
	  fnd_file.put_line(fnd_file.log,
		        'Successfully Updated Oracle IB with SF_ID. Details:: Item : ' ||
		        l_item_segment || '(ID = ' ||
		        t.inventory_item_id || ') and Serial No: ' ||
		        l_serial_number || ' Instance Number: ' ||
		        l_instance_number || ' SF ID: ' ||
		        t.attribute12);

	  handle_log_tbl(p_parent_instance_id      => NULL, -- i n
		     p_parent_cust1            => NULL, -- i v
		     p_child_instance_id       => l_instance_id, -- i n
		     p_component_item          => l_item_segment, -- i v
		     p_component_serial_number => t.serial_number, -- i v
		     p_creation_status         => 'S', -- i v
		     p_creation_err_msg        => 'Migrated from SFDC', -- i v
		     p_relation_staus          => NULL, -- i v
		     p_relation_err_msg        => NULL, -- i v
		     p_job                     => NULL, -- i n
		     p_error_code              => l_error_code, -- o n
		     p_error_desc              => l_error_desc);

	  COMMIT;

	  --exit;
	END IF;
          ELSE
	l_success_data_counter       := l_success_data_counter + 1;
	l_skip_sf_id_present_counter := l_skip_sf_id_present_counter + 1;
          END IF;
        ELSE
          -- Create new Oracle IB Instance
          BEGIN
	l_primary_ship_site := get_primary_party_site_id(t.owner_account_id,
					 t.ship_to_ou_id,
					 'SHIP_TO',
					 'PARTY_SITE');
          EXCEPTION
	WHEN no_data_found THEN
	  NULL;
          END;

          BEGIN
	SELECT nvl((SELECT hps.party_site_id
	           FROM   hz_cust_acct_sites_all hcasa,
		      hz_party_sites         hps
	           WHERE  hcasa.cust_acct_site_id = t.current_site_id
	           AND    hcasa.party_site_id = hps.party_site_id
	           AND    hcasa.status = 'A'
	           AND    hps.status = 'A'),
	           l_primary_ship_site)
	INTO   l_current_site_id
	FROM   dual;

          EXCEPTION
	WHEN no_data_found THEN
	  fnd_file.put_line(fnd_file.log,
		        'ERROR: Current Site ID is not valid : IB SF ID: ' ||
		        t.attribute12 || ' ' || SQLERRM);
	  l_error_data_counter := l_error_data_counter + 1;
	  CONTINUE;
          END;

          BEGIN
	SELECT nvl((SELECT hps.party_site_id
	           FROM   hz_cust_acct_sites_all hcasa,
		      hz_party_sites         hps
	           WHERE  hcasa.cust_acct_site_id = t.install_site_id
	           AND    hcasa.party_site_id = hps.party_site_id
	           AND    hcasa.status = 'A'
	           AND    hps.status = 'A'),
	           l_primary_ship_site)
	INTO   l_install_site_id
	FROM   dual;
          EXCEPTION
	WHEN no_data_found THEN
	  fnd_file.put_line(fnd_file.log,
		        'ERROR: Install Site ID is not valid : IB SF ID: ' ||
		        t.attribute12 || ' ' || SQLERRM);
	  l_error_data_counter := l_error_data_counter + 1;
	  CONTINUE;
          END;

          BEGIN
	SELECT nvl((SELECT hcsua.site_use_id
	           FROM   hz_cust_acct_sites_all hcasa,
		      hz_cust_site_uses_all  hcsua
	           WHERE  hcasa.cust_acct_site_id = t.ship_to_site_id
	           AND    hcasa.cust_acct_site_id =
		      hcsua.cust_acct_site_id
	           AND    hcsua.site_use_code = 'SHIP_TO'
	           AND    hcasa.status = 'A'
	           AND    hcsua.status = 'A'),
	           get_primary_party_site_id(t.owner_account_id,
				 t.ship_to_ou_id,
				 'SHIP_TO',
				 'SITE_USE'))
	INTO   l_ship_site_id
	FROM   dual;
          EXCEPTION
	WHEN no_data_found THEN
	  fnd_file.put_line(fnd_file.log,
		        'ERROR: Ship-To Site ID is not valid  : IB SF ID: ' ||
		        t.attribute12 || ' ' || SQLERRM);
	  l_error_data_counter := l_error_data_counter + 1;
	  CONTINUE;
          END;

          BEGIN
	SELECT nvl((SELECT hcsua.site_use_id
	           FROM   hz_cust_acct_sites_all hcasa,
		      hz_cust_site_uses_all  hcsua
	           WHERE  hcasa.cust_acct_site_id = t.bill_to_site_id
	           AND    hcasa.cust_acct_site_id =
		      hcsua.cust_acct_site_id
	           AND    hcsua.site_use_code = 'BILL_TO'
	           AND    hcasa.status = 'A'
	           AND    hcsua.status = 'A'),
	           get_primary_party_site_id(t.owner_account_id,
				 t.ship_to_ou_id,
				 'BILL_TO',
				 'SITE_USE'))
	INTO   l_bill_site_id
	FROM   dual;
          EXCEPTION
	WHEN no_data_found THEN
	  fnd_file.put_line(fnd_file.log,
		        'ERROR: Bill-To Site ID is not valid : IB SF ID: ' ||
		        t.attribute12 || ' ' || SQLERRM);
	  l_error_data_counter := l_error_data_counter + 1;
	  CONTINUE;
          END;

          IF l_ship_site_id IS NULL OR l_bill_site_id IS NULL THEN
	fnd_file.put_line(fnd_file.log,
		      'Bill-To and Ship-To site could not be determined for : ' ||
		      l_item_segment || '(' || t.inventory_item_id ||
		      ') and serial ' || l_serial_number ||
		      '. Record skipped');

	l_no_bill_ship_counter := l_no_bill_ship_counter + 1;

	CONTINUE;
          END IF;

          SELECT csi_item_instances_s.nextval
          INTO   l_instance_id
          FROM   dual;
          l_instance_number := l_instance_id;

          SELECT csi_i_parties_s.nextval
          INTO   l_instance_party_id
          FROM   dual;

          SELECT csi_ip_accounts_s.nextval
          INTO   l_ip_account_id
          FROM   dual;

          l_instance_rec.instance_id       := l_instance_id;
          l_instance_rec.instance_number   := l_instance_number;
          l_instance_rec.inventory_item_id := t.inventory_item_id;
          --l_instance_rec.vld_organization_id := 729;
          -- l_instance_rec.INV_ORGANIZATION_ID             := v_organization_id;
          l_instance_rec.inv_master_organization_id := l_master_organization_id;
          l_instance_rec.serial_number              := l_serial_number;
          l_instance_rec.inventory_revision         := t.inventory_revision;
          l_instance_rec.quantity                   := t.quantity;
          l_instance_rec.unit_of_measure            := t.unit_of_measure;
          l_instance_rec.instance_status_id         := t.instance_status_id;
          l_instance_rec.owner_party_id             := t.owner_party_id;
          l_instance_rec.customer_view_flag         := 'N';
          l_instance_rec.merchant_view_flag         := 'Y';
          l_instance_rec.sellable_flag              := 'N';
          l_instance_rec.location_type_code         := 'HZ_PARTY_SITES';
          l_instance_rec.location_id                := l_current_site_id;
          l_instance_rec.install_location_type_code := 'HZ_PARTY_SITES';
          l_instance_rec.install_location_id        := l_install_site_id;
          l_instance_rec.install_date               := nvl(t.install_date,
				           t.shippment_date);
          l_instance_rec.active_start_date          := nvl(t.install_date,
				           t.shippment_date);
          l_instance_rec.active_end_date            := NULL;
          l_instance_rec.manually_created_flag      := 'Y';
          l_instance_rec.creation_complete_flag     := 'Y';
          l_instance_rec.attribute1                 := 'Migrated from SFDC';
          l_instance_rec.attribute12                := t.attribute12;
          l_instance_rec.attribute4                 := t.attribute4;
          l_instance_rec.attribute8                 := t.attribute8;
          l_instance_rec.attribute5                 := t.attribute5;
          l_instance_rec.attribute7                 := t.attribute7;
          l_instance_rec.attribute3                 := t.attribute3;
          l_instance_rec.attribute6                 := t.attribute6;
          --PARTY
          l_party_tbl(1).instance_party_id := l_instance_party_id;
          l_party_tbl(1).instance_id := l_instance_id;
          l_party_tbl(1).party_source_table := 'HZ_PARTIES';
          l_party_tbl(1).party_id := t.owner_party_id;
          l_party_tbl(1).relationship_type_code := 'OWNER';
          l_party_tbl(1).contact_flag := 'N';
          l_party_tbl(1).contact_ip_id := NULL;
          l_party_tbl(1).active_start_date := nvl(t.install_date,
				  t.shippment_date);
          l_party_tbl(1).active_end_date := NULL;
          l_party_tbl(1).object_version_number := 1;
          l_party_tbl(1).primary_flag := NULL;
          l_party_tbl(1).preferred_flag := 'N';
          --ACCOUNTS
          l_account_tbl(1).ip_account_id := l_ip_account_id;
          l_account_tbl(1).parent_tbl_index := 1;
          l_account_tbl(1).instance_party_id := l_instance_party_id;
          l_account_tbl(1).party_account_id := t.owner_account_id;
          l_account_tbl(1).relationship_type_code := 'OWNER';
          l_account_tbl(1).active_start_date := nvl(t.install_date,
				    t.shippment_date);
          l_account_tbl(1).active_end_date := NULL;
          l_account_tbl(1).bill_to_address := l_bill_site_id;
          l_account_tbl(1).ship_to_address := l_ship_site_id;
          l_account_tbl(1).object_version_number := 1;

          --TXN
          l_txn_rec.transaction_id              := NULL;
          l_txn_rec.transaction_date            := trunc(SYSDATE);
          l_txn_rec.source_transaction_date     := trunc(SYSDATE);
          l_txn_rec.transaction_type_id         := 1;
          l_txn_rec.txn_sub_type_id             := NULL;
          l_txn_rec.source_group_ref_id         := NULL;
          l_txn_rec.source_group_ref            := '';
          l_txn_rec.source_header_ref_id        := NULL;
          l_txn_rec.source_header_ref           := '';
          l_txn_rec.source_line_ref_id          := NULL;
          l_txn_rec.source_line_ref             := '';
          l_txn_rec.source_dist_ref_id1         := NULL;
          l_txn_rec.source_dist_ref_id2         := NULL;
          l_txn_rec.inv_material_transaction_id := NULL;
          l_txn_rec.transaction_quantity        := NULL;
          l_txn_rec.transaction_uom_code        := '';
          l_txn_rec.transacted_by               := NULL;
          l_txn_rec.transaction_status_code     := '';
          l_txn_rec.transaction_action_code     := '';
          l_txn_rec.message_id                  := NULL;
          l_txn_rec.object_version_number       := '';
          l_txn_rec.split_reason_code           := '';

          csi_item_instance_pub.create_item_instance(p_api_version           => 1,
				     p_commit                => fnd_api.g_false,
				     p_init_msg_list         => l_init_msg_lst,
				     p_validation_level      => l_validation_level,
				     p_instance_rec          => l_instance_rec,
				     p_ext_attrib_values_tbl => l_ext_attrib_values,
				     p_party_tbl             => l_party_tbl,
				     p_account_tbl           => l_account_tbl,
				     p_pricing_attrib_tbl    => l_pricing_attrib_tbl,
				     p_org_assignments_tbl   => l_org_assignments_tbl,
				     p_asset_assignment_tbl  => l_asset_assignment_tbl,
				     p_txn_rec               => l_txn_rec,
				     x_return_status         => l_return_status,
				     x_msg_count             => l_msg_count,
				     x_msg_data              => l_msg_data);

          IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
	-- Oracle IB create API error
	l_error_data_counter := l_error_data_counter + 1;

	fnd_msg_pub.get(p_msg_index     => -1,
		    p_encoded       => 'F',
		    p_data          => l_msg_data,
		    p_msg_index_out => l_msg_index_out);

	fnd_file.put_line(fnd_file.log,
		      'API ERROR: while creating Oracle IB instance with SF_ID for Item : ' ||
		      l_item_segment || '(' || t.inventory_item_id ||
		      ') and serial ' || l_serial_number ||
		      '. Record skipped.' || chr(10) || '  ERROR:' ||
		      l_msg_data);

	fnd_file.put_line(fnd_file.output,
		      'API ERROR: while creating Oracle IB instance with SF_ID for Item : ' ||
		      l_item_segment || '(' || t.inventory_item_id ||
		      ') and serial ' || l_serial_number ||
		      '. Record skipped.' || chr(10) || '  ERROR:' ||
		      l_msg_data);

	ROLLBACK;

	handle_log_tbl(p_parent_instance_id      => NULL, -- i n
		   p_parent_cust1            => NULL, -- i v
		   p_child_instance_id       => l_instance_id, -- i n
		   p_component_item          => l_item_segment, -- i v
		   p_component_serial_number => t.serial_number, -- i v
		   p_creation_status         => l_return_status, -- i v
		   p_creation_err_msg        => 'Got error when trying to create instance for COMPONENT: ' ||
				        l_item_segment ||
				        ' : ' || l_msg_data, -- i v
		   p_relation_staus          => NULL, -- i v
		   p_relation_err_msg        => NULL, -- i v
		   p_job                     => NULL, -- i n
		   p_error_code              => l_error_code, -- o n
		   p_error_desc              => l_error_desc);

	--exit;
	--
          ELSE
	-- Oracle IB create API success
	l_success_data_counter := l_success_data_counter + 1;
	l_created_counter      := l_created_counter + 1;

	fnd_file.put_line(fnd_file.log,
		      'Successfully Created Oracle IB with SF_ID. Details:: Item : ' ||
		      l_item_segment || '(ID = ' ||
		      t.inventory_item_id || ') and Serial No: ' ||
		      l_serial_number || ' Instance Number: ' ||
		      l_instance_number || ' SF ID: ' ||
		      t.attribute12);

	handle_log_tbl(p_parent_instance_id      => NULL, -- i n
		   p_parent_cust1            => NULL, -- i v
		   p_child_instance_id       => l_instance_id, -- i n
		   p_component_item          => l_item_segment, -- i v
		   p_component_serial_number => t.serial_number, -- i v
		   p_creation_status         => 'S', -- i v
		   p_creation_err_msg        => 'Migrated from SFDC', -- i v
		   p_relation_staus          => NULL, -- i v
		   p_relation_err_msg        => NULL, -- i v
		   p_job                     => NULL, -- i n
		   p_error_code              => l_error_code, -- o n
		   p_error_desc              => l_error_desc);

	COMMIT;

	--exit;
          END IF;
        END IF;
      ELSE
        IF l_serial_control = 1 AND l_trackable_flag = 'Y' THEN
          l_non_serial_counter := l_non_serial_counter + 1;
          fnd_file.put_line(fnd_file.log,
		    'Inventory Item: ' || l_item_segment || '(' ||
		    t.inventory_item_id || ')' ||
		    ' is not Serial controlled. Record skipped.');
        ELSIF l_serial_control <> 1 AND l_trackable_flag = 'N' THEN
          l_non_trackable_counter := l_non_trackable_counter + 1;
          fnd_file.put_line(fnd_file.log,
		    'Inventory Item: ' || l_item_segment || '(' ||
		    t.inventory_item_id || ')' ||
		    ' is not IB trackable. Record skipped.');
        ELSE
          l_non_serial_track_counter := l_non_serial_track_counter + 1;
          fnd_file.put_line(fnd_file.log,
		    'Inventory Item: ' || l_item_segment || '(' ||
		    t.inventory_item_id || ')' ||
		    ' is not IB trackable and not Serial controlled. Record skipped.');
        END IF;

        l_error_data_counter := l_error_data_counter + 1;

      END IF;
      ------
    END LOOP; -- end loop

    fnd_file.put_line(fnd_file.output,
	          '                ***Oracle IB Up-To-Date summary***               ');
    fnd_file.put_line(fnd_file.output,
	          '-----------------------------------------------------------------');
    fnd_file.put_line(fnd_file.output,
	          'Total SFDC Records considered :                           ' ||
	          l_total_data_counter);
    fnd_file.put_line(fnd_file.output,
	          'Total Oracle Instances created:                           ' ||
	          l_created_counter);
    fnd_file.put_line(fnd_file.output,
	          'Total Oracle Instances updated:                           ' ||
	          l_updated_counter);
    fnd_file.put_line(fnd_file.output,
	          'Skipped- No Account ID present:                           ' ||
	          l_no_account_id_counter);
    fnd_file.put_line(fnd_file.output,
	          'Skipped- Instance SF ID exists:                           ' ||
	          l_skip_sf_id_present_counter);
    fnd_file.put_line(fnd_file.output,
	          'Skipped- Item not IB trackable:                           ' ||
	          l_non_trackable_counter);
    fnd_file.put_line(fnd_file.output,
	          'Skipped- Item not serial controlled:                      ' ||
	          l_non_serial_counter);
    fnd_file.put_line(fnd_file.output,
	          'Skipped- Bill-To / Ship-To site could not be determined:  ' ||
	          l_no_bill_ship_counter);
    fnd_file.put_line(fnd_file.output,
	          'Skipped- Item neither serial controlled nor IB trackable: ' ||
	          l_non_serial_track_counter);
    fnd_file.put_line(fnd_file.output,
	          'Total records with errors     :                           ' ||
	          (l_error_data_counter - l_non_trackable_counter -
	          l_no_account_id_counter - l_non_serial_counter -
	          l_non_serial_track_counter));
    fnd_file.put_line(fnd_file.output,
	          '--------------------------------------------');

    IF l_total_data_counter = l_success_data_counter THEN
      errbuf  := 'SUCCESS';
      retcode := 0;
    ELSIF l_error_data_counter > 0 AND l_success_data_counter > 0 THEN
      errbuf  := 'WARNING';
      retcode := 1;
    ELSE
      errbuf  := 'ERROR';
      retcode := 2;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'ERROR';
      retcode := 2;

      fnd_file.put_line(fnd_file.log, 'Unexpected Error: ' || SQLERRM);
  END create_missing_instance;

  --------------------------------------------------------------------------------------------
  -- Purpose: Change - CHG0042574
  --          Initialize applicative user (for WHO Tables)
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                    Description
  -- 1.0  12-Apr-2018  Dan M.                  Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION sf2ora_initialize(p_user_name      VARCHAR2,
		     p_responsibility VARCHAR2,
		     p_appication     VARCHAR2) RETURN VARCHAR2 IS
    l_user_id NUMBER;
    l_resp_id NUMBER;
    l_app_id  NUMBER;
  BEGIN
    BEGIN

      SELECT fndappl.application_id
      INTO   l_app_id
      FROM   fnd_application fndappl
      WHERE  fndappl.application_short_name = p_appication;

      SELECT fndresp.responsibility_id
      INTO   l_resp_id
      FROM   fnd_responsibility_tl fndresp
      WHERE  fndresp.responsibility_name = p_responsibility -- 'Service Contracts Manager'
      AND    fndresp.language = 'US'
      AND    fndresp.application_id = l_app_id;

      SELECT fnd.user_id
      INTO   l_user_id
      FROM   fnd_user fnd
      WHERE  fnd.user_name = p_user_name;

      fnd_global.apps_initialize(user_id      => l_user_id,
		         resp_id      => l_resp_id,
		         resp_appl_id => l_app_id);

      mo_global.init(p_appication);

      RETURN 'Y';
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 'X';
    END;

  END sf2ora_initialize;

  --------------------------------------------------------------------
  --  name:               sf2ora_update_log
  --  create by:          Dan Melamed
  --  creation date:      10-Apr-2018
  --  Purpose :           Change - CHG0042574 : Update run log
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-Apr-2018   Dan Melamed initial build
  -----------------------------------------------------------------------

  PROCEDURE sf2ora_update_log(p_log_information VARCHAR2,
		      p_log_prefix      VARCHAR2 DEFAULT NULL) IS
    l_prefix   VARCHAR2(255);
    l_log_text VARCHAR2(2055);
  BEGIN
    -- Data rec here used as 'preperation for AC' -- maybe in the future will be used to filter out some logging ..

    IF p_log_prefix IS NULL THEN
      l_log_text := p_log_information;
    ELSE
      l_log_text := p_log_prefix || ': ' || p_log_information;
    END IF;

    IF g_run_state = 'CONCURRENT' THEN

      fnd_file.put_line(fnd_file.log, l_log_text); -- as running through concurrent
    ELSE
      dbms_output.put_line(l_log_text); -- as running locally (not concurrent)
    END IF;

    -- end if;
  END sf2ora_update_log;

  --------------------------------------------------------------------
  --  name:               sf2ora_location_exists_in_ora
  --  create by:          Dan Melamed
  --  creation date:      10-Apr-2018
  --  Purpose :           Change - CHG0042574 :Check if location exists in oracle.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-Apr-2018   Dan Melamed initial build
  -----------------------------------------------------------------------
  PROCEDURE sf2ora_site_exists_in_ora(p_location_id    VARCHAR2,
			  p_location_which VARCHAR2,
			  p_out_val        OUT VARCHAR2,
			  p_error_code     OUT NUMBER,
			  p_error_desc     OUT VARCHAR2) IS
    l_ca_id           NUMBER;
    l_location_status VARCHAR2(1);
  BEGIN
    p_error_code := 0;

    IF p_location_id IS NULL THEN
      p_out_val := 'Y'; -- defaults will be used if null
    ELSE
      SELECT hcasa.status,
	 hca.cust_account_id
      INTO   l_location_status,
	 l_ca_id
      FROM   hz_cust_acct_sites_all hcasa,
	 hz_cust_accounts       hca
      WHERE  1 = 1
      AND    hcasa.cust_acct_site_id = p_location_id
      AND    hcasa.cust_account_id = hca.cust_account_id;

      IF l_location_status = 'I' THEN
        p_out_val    := 'N';
        p_error_code := -1;
        fnd_message.clear;
        fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_SITE_NOT_EXIST');
        fnd_message.set_token('SITE_ID', p_location_id);
        fnd_message.set_token('SITE_TYPE', p_location_which);
        p_error_desc := fnd_message.get;

      ELSIF l_location_status = 'A' THEN
        p_out_val := 'Y';
      ELSE
        p_error_code := -1;
        fnd_message.clear;
        fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_API_ERR');
        fnd_message.set_token('API_ERR',
		      'Invalid status for Site : ' || p_location_id);
        p_error_desc := fnd_message.get;
      END IF;

    END IF;

  EXCEPTION

    WHEN no_data_found THEN

      p_error_code := -1;
      fnd_message.clear;
      fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_SITE_NOT_EXIST');
      fnd_message.set_token('SITE_TYPE', p_location_which);
      fnd_message.set_token('SITE_ID', p_location_id);
      p_error_desc := fnd_message.get;

    WHEN OTHERS THEN
      p_error_code := -1;
      fnd_message.clear;
      fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_API_ERR');
      fnd_message.set_token('API_ERR',
		    'Error validating site ID : ' || p_location_id);
      p_error_desc := fnd_message.get;

  END sf2ora_site_exists_in_ora;

  --------------------------------------------------------------------
  --  name:               sf2ora_location_exists_in_ora
  --  create by:          Dan Melamed
  --  creation date:      10-Apr-2018
  --  Purpose :           Change - CHG0042574 : Check if location exists in oracle.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-Apr-2018   Dan Melamed initial build
  -----------------------------------------------------------------------
  PROCEDURE sf2ora_site_account_belong(p_location_id             VARCHAR2,
			   p_location_which          VARCHAR2,
			   p_account_end_customer_id VARCHAR2,
			   p_owner_party_account_id  VARCHAR2,
			   p_out_val                 OUT VARCHAR2,
			   p_error_code              OUT NUMBER,
			   p_error_desc              OUT VARCHAR2) IS

    l_party_id        NUMBER;
    l_location_status VARCHAR2(1);
    l_ca_id           NUMBER;
  BEGIN
    p_error_code := 0;

    IF p_location_id IS NULL THEN
      p_out_val := 'Y'; -- defaults will be used if null
    ELSE
      SELECT hcasa.status,
	 hca.cust_account_id
      INTO   l_location_status,
	 l_ca_id
      FROM   hz_cust_acct_sites_all hcasa,
	 hz_cust_accounts       hca
      WHERE  1 = 1
      AND    hcasa.cust_acct_site_id = p_location_id
      AND    hcasa.cust_account_id = hca.cust_account_id;

      IF l_party_id NOT IN
         (p_owner_party_account_id, p_account_end_customer_id) THEN
        p_out_val := 'N';

        p_error_code := -1;
        fnd_message.clear;
        fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_SITE_NOT_RT_ACCT');
        fnd_message.set_token('SITE_ID', p_location_id);
        fnd_message.set_token('SITE_TYPE', p_location_which);
        p_error_desc := fnd_message.get;

      END IF;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := -1;
      fnd_message.clear;
      fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_API_ERR');
      fnd_message.set_token('API_ERR',
		    'Error validating site/account for site ' ||
		    p_location_id || '(' || p_location_which || ')');
      p_error_desc := fnd_message.get;

  END sf2ora_site_account_belong;

  --------------------------------------------------------------------
  --  name:               sf2ora_Account_Exist_in_ora
  --  create by:          Dan Melamed
  --  creation date:      10-Apr-2018
  --  Purpose :           Change - CHG0042574 : Check if acount exists in Oracle.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-Apr-2018   Dan Melamed initial build
  -----------------------------------------------------------------------

  PROCEDURE sf2ora_account_exist_in_ora(p_owner_party_account_id NVARCHAR2,
			    p_out_val                OUT VARCHAR2,
			    p_account_name           OUT VARCHAR2,
			    p_error_code             OUT NUMBER,
			    p_error_desc             OUT VARCHAR2) IS
  BEGIN
    p_error_code := 0;

    BEGIN
      IF (p_owner_party_account_id IS NULL) THEN
        p_error_code := -1;
        p_error_desc := 'Owner party accound is null';
        RETURN;
      ELSE
        SELECT decode(hza.status, 'I', 'N', 'A', 'Y', 'X'),
	   hza.account_name
        INTO   p_out_val,
	   p_account_name
        FROM   hz_cust_accounts hza
        WHERE  hza.cust_account_id = p_owner_party_account_id;
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        p_error_code := -1;
        p_error_desc := 'Owner party account ID ' ||
		p_owner_party_account_id ||
		' does not exist in Oracle';

      WHEN OTHERS THEN
        p_error_code := -1;
        p_error_desc := 'Error validating Owner party account in Oracle for ID ' ||
		p_owner_party_account_id || ' : ' || SQLERRM;

    END;

  END sf2ora_account_exist_in_ora;

  --------------------------------------------------------------------
  --  name:               sf2ora_end_cust_exist_in_ora
  --  create by:          Dan Melamed
  --  creation date:      10-Apr-2018
  --  Purpose :           Change - CHG0042574 : Check if end customer exists in Oracle
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-Apr-2018   Dan Melamed initial build
  -----------------------------------------------------------------------

  PROCEDURE sf2ora_end_cust_exist_in_ora(p_account_end_customer_id NVARCHAR2,
			     p_out_val                 OUT VARCHAR2,
			     p_account_name            OUT VARCHAR2,
			     p_error_code              OUT NUMBER,
			     p_error_desc              OUT VARCHAR2)

   IS
  BEGIN

    p_error_code := 0;

    IF p_account_end_customer_id IS NULL THEN
      p_out_val := 'Y'; -- if account end customer ID is null, pass validation
    ELSE
      BEGIN

        SELECT decode(hza.status, 'I', 'N', 'A', 'Y', 'N'),
	   hza.account_name
        INTO   p_out_val,
	   p_account_name
        FROM   hz_cust_accounts hza
        WHERE  hza.cust_account_id = p_account_end_customer_id;

      EXCEPTION

        WHEN no_data_found THEN
          p_error_code := -1;
          p_error_desc := 'End Customer account ID ' ||
		  p_account_end_customer_id ||
		  ' does not exist in Oracle';

        WHEN OTHERS THEN
          p_error_code := -1;
          p_error_desc := 'Error validating end Customer account in Oracle for ID ' ||
		  p_account_end_customer_id || ' : ' || SQLERRM;

      END;
    END IF;
  END sf2ora_end_cust_exist_in_ora;

  --------------------------------------------------------------------
  --  name:               sf2ora_itemtrackable
  --  create by:          Dan Melamed
  --  creation date:      10-Apr-2018
  --  Purpose :           Change - CHG0042574 : Check if item is trackable for oracle IB
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-Apr-2018   Dan Melamed initial build
  -----------------------------------------------------------------------

  PROCEDURE sf2ora_itemtrackable(p_inventory_item_id NVARCHAR2,
		         p_out_val           OUT VARCHAR2,
		         p_error_code        OUT NUMBER,
		         p_error_desc        OUT VARCHAR2) IS
    l_master_organization_id NUMBER := xxinv_utils_pkg.get_master_organization_id;
  BEGIN
    BEGIN
      p_error_code := 0;

      SELECT nvl(comms_nl_trackable_flag, 'N')
      INTO   p_out_val
      FROM   mtl_system_items_b
      WHERE  inventory_item_id = p_inventory_item_id
      AND    organization_id = l_master_organization_id;

    EXCEPTION

      WHEN no_data_found THEN
        p_out_val    := 'N';
        p_error_desc := 'Item not found in master items table';
        p_error_code := -1;

      WHEN OTHERS THEN
        p_out_val    := 'N';
        p_error_desc := substr(SQLERRM, 1, 100);
        p_error_code := -1;
    END;
  END sf2ora_itemtrackable;

  --------------------------------------------------------------------
  --  name:               sf2ora_ib_exist_in_ora
  --  create by:          Dan Melamed
  --  creation date:      10-Apr-2018
  --  Purpose :           Change - CHG0042574 : Check if item exists in ORACLE ib
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-Apr-2018   Dan Melamed initial build
  -----------------------------------------------------------------------
  PROCEDURE sf2ora_ib_exist_in_ora(p_intentory_item_id  NVARCHAR2,
		           p_serial_number      NVARCHAR2,
		           p_exist_in_ib_ind    OUT VARCHAR2,
		           p_location_type_code OUT VARCHAR2,
		           p_error_code         OUT NUMBER,
		           p_error_desc         OUT VARCHAR2) IS

  BEGIN
    p_error_code := 0;

    BEGIN

      SELECT 'Y',
	 cii.location_type_code
      INTO   p_exist_in_ib_ind,
	 p_location_type_code
      FROM   csi_item_instances cii
      WHERE  cii.inventory_item_id = p_intentory_item_id
      AND    (cii.serial_number = p_serial_number OR
	substr(cii.serial_number,
	         1,
	         instr(cii.serial_number, '-') - 1) =
	p_serial_number);

    EXCEPTION
      WHEN no_data_found THEN
        p_exist_in_ib_ind := 'N'; -- not an error - simply not exist in Installbase, to be treated as Insert
    END;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := -1;
      p_error_desc := 'Error locating Item in IB ' ||
	          substr(SQLERRM, 0, 150);
  END sf2ora_ib_exist_in_ora;

  --------------------------------------------------------------------
  --  name:               sf2ora_check_sites_exist
  --  create by:          Dan Melamed
  --  creation date:      10-Apr-2018
  --  Purpose :            Change - CHG0042574 : Check if all four sites exist (if not null) in ORA.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-Apr-2018   Dan Melamed initial build
  -----------------------------------------------------------------------

  PROCEDURE sf2ora_check_all_sites_exist(p_install_site_id    VARCHAR2,
			     p_ship_to_site_id    VARCHAR2,
			     p_bill_to_site_id    VARCHAR2,
			     p_instance_status_id NUMBER,
			     p_out_val            OUT VARCHAR2,
			     p_error_code         OUT NUMBER,
			     p_error_desc         OUT VARCHAR2) IS

    l_item_status VARCHAR2(255);
  BEGIN

    BEGIN

      SELECT cis.name
      INTO   l_item_status
      FROM   csi_instance_statuses cis
      WHERE  p_instance_status_id = cis.instance_status_id;

    EXCEPTION
      WHEN no_data_found THEN
        p_error_code := -1;
        p_error_desc := 'Item status could not be identified';
        RETURN;
    END;

    IF upper(l_item_status) = 'INSTALLED' AND p_install_site_id IS NULL THEN
      p_error_code := -1;
      p_error_desc := 'Installed site must be available for installed items';
      RETURN;
    END IF;

    /* sf2ora_site_exists_in_ora(p_CURRENT_SITE_ID,
                              'CURRENT',
                              p_out_val,
                              p_error_code,
                              p_error_desc);

    if (p_error_code = -1 or p_out_val = 'N') then
      p_error_desc := nvl(p_error_desc, 'Error validating Site for CURRENT');
      return;
    end if;*/

    sf2ora_site_exists_in_ora(p_bill_to_site_id,
		      'BILL_TO',
		      p_out_val,
		      p_error_code,
		      p_error_desc);

    IF (p_error_code = -1 OR p_out_val = 'N') THEN
      p_error_desc := nvl(p_error_desc, 'Error validating Site for BILL_TO');
      RETURN;
    END IF;

    sf2ora_site_exists_in_ora(p_ship_to_site_id,
		      'SHIP_TO',
		      p_out_val,
		      p_error_code,
		      p_error_desc);

    IF (p_error_code = -1 OR p_out_val = 'N') THEN
      p_error_desc := nvl(p_error_desc, 'Error validating Site for SHIP_TO');
      RETURN;
    END IF;

    sf2ora_site_exists_in_ora(p_install_site_id,
		      'INSTALL',
		      p_out_val,
		      p_error_code,
		      p_error_desc);

    IF (p_error_code = -1 OR p_out_val = 'N') THEN
      p_error_desc := nvl(p_error_desc, 'Error validating Site for INSTALL');
      RETURN;
    END IF;

    p_out_val := 'Y';

  END sf2ora_check_all_sites_exist;

  --------------------------------------------------------------------
  --  name:               sf2ora_check_all_sites_belong
  --  create by:          Dan Melamed
  --  creation date:      10-Apr-2018
  --  Purpose :           Change - CHG0042574 : Check if all four sites belong to one of two accounts : owner or end customer.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10-Apr-2018   Dan Melamed initial build
  -----------------------------------------------------------------------

  PROCEDURE sf2ora_check_all_sites_belong(p_install_site_id         VARCHAR2,
			      p_ship_to_site_id         VARCHAR2,
			      p_bill_to_site_id         VARCHAR2,
			      p_account_end_customer_id NVARCHAR2,
			      p_owner_party_account_id  NVARCHAR2,
			      p_out_val                 OUT VARCHAR2,
			      p_error_code              OUT NUMBER,
			      p_error_desc              OUT VARCHAR2) IS

  BEGIN

    /*sf2ora_site_account_belong(p_CURRENT_SITE_ID,
                               'CURRENT',
                               p_account_end_customer_id,
                               p_owner_party_account_id,
                               p_out_Val,
                               p_error_code,
                               p_error_desc);

    if (p_error_code = -1 or p_out_val = 'N') then
      p_error_desc := nvl(p_error_desc,
                          'Error validating Site/account for CURRENT');
      return;
    end if;*/

    sf2ora_site_account_belong(p_bill_to_site_id,
		       'BILL_TO',
		       p_account_end_customer_id,
		       p_owner_party_account_id,
		       p_out_val,
		       p_error_code,
		       p_error_desc);

    IF (p_error_code = -1 OR p_out_val = 'N') THEN
      p_error_desc := nvl(p_error_desc,
		  'Error validating Site/account for BILL_TO');

      RETURN;
    END IF;

    sf2ora_site_account_belong(p_ship_to_site_id,
		       'SHIP_TO',
		       p_account_end_customer_id,
		       p_owner_party_account_id,
		       p_out_val,
		       p_error_code,
		       p_error_desc);

    IF (p_error_code = -1 OR p_out_val = 'N') THEN
      p_error_desc := nvl(p_error_desc,
		  'Error validating Site/account for SHIP_TO');

      RETURN;
    END IF;

    sf2ora_site_account_belong(p_install_site_id,
		       'INSTALL',
		       p_account_end_customer_id,
		       p_owner_party_account_id,
		       p_out_val,
		       p_error_code,
		       p_error_desc);

    IF (p_error_code = -1 OR p_out_val = 'N') THEN
      p_error_desc := nvl(p_error_desc,
		  'Error validating Site/account for INSTALL');

      RETURN;
    END IF;

    p_out_val := 'Y';

  END sf2ora_check_all_sites_belong;

  FUNCTION sync_ib_terminate_sc(p_instance_id NVARCHAR2) RETURN NUMBER IS

    CURSOR active_contracts IS
      SELECT h.contract_number contract_number,
	 h.id cnt_header_id,
	 h.end_date h_end_date,
	 h.contract_number_modifier h_contract_number_modifier,
	 l1.id subline_id,
	 l1.cle_id subline_cle,
	 l1.line_number subline_num,
	 l1.dnz_chr_id subline_dnz,
	 l1.sts_code subline_sts,
	 l1.date_terminated subline_terminated,
	 l1.end_date subline_orig_ed,
	 l2.sts_code line_status,
	 hca.account_number,
	 hca.account_name,
	 to_char(l1.id) externalkey,
	 cii.serial_number asset_sn,
	 cii.instance_id asset_external_key,
	 msib.segment1 "Service Contract Product",
	 l1.sts_code,
	 osv.meaning status,
	 l1.start_date,
	 l1.end_date,
	 cii.serial_number,
	 cii.instance_id,
	 msib.segment1,
	 msib.description,
	 l1.upg_orig_system_ref "Contract Source",
	 l1.upg_orig_system_ref_id "Order Line Id"

      FROM   okc_k_headers_all_b h, -- headers
	 okc_k_lines_b       l1, -- sub lines (which are also by themselvs lines)
	 okc_k_lines_b       l2, -- lines
	 okc_k_items         oki1, --IB
	 okc_k_items         oki2, --Contract
	 csi_item_instances  cii,
	 mtl_system_items_b  msib,
	 okc_statuses_v      osv,
	 hz_cust_accounts    hca
      WHERE  h.id = l1.dnz_chr_id
      AND    oki1.object1_id1 = cii.instance_id
      AND    oki1.cle_id = l1.id
      AND    oki1.object1_id1 = cii.instance_id
      AND    oki2.cle_id = l2.id
      AND    l2.chr_id = h.id
      AND    osv.default_yn = 'Y'
      AND    osv.ste_code = l1.sts_code
      AND    l2.cust_acct_id = hca.cust_account_id
      AND    msib.inventory_item_id = oki2.object1_id1
      AND    msib.organization_id = 91
      AND    h.sts_code IN ('ACTIVE', 'SIGNED', 'HOLD') -- headrs are active.
	--   AND l1.sts_code NOT IN ('ENTERED','HOLD', 'TERMINATED') -- sublines are active
	--   AND l2.sts_code NOT IN ('ENTERED','HOLD', 'TERMINATED') -- lines are active
      AND    cii.instance_id = p_instance_id;

    l_return_status VARCHAR2(4000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(4000);
    l_cnt_header    okc_terminate_pub.terminate_in_parameters_rec;
    l_cnt_line      okc_terminate_pub.terminate_in_cle_rec;

    l_clev_rec_type okc_cle_pvt.clev_rec_type;
    l_out_clev_rec  okc_cle_pvt.clev_rec_type;

    l_active_sublines NUMBER;
    l_subline_line    NUMBER;
    l_line_status     VARCHAR2(255);
    l_init_user       VARCHAR2(1);
  BEGIN

    -- Terminate contract sublines, lines and headers

    FOR contract_rec IN active_contracts LOOP

      IF contract_rec.sts_code IN ('ACTIVE', 'SIGNED', 'HOLD') THEN
        -- terminate subline (specific instance ID Contract)
        l_return_status          := NULL;
        l_msg_count              := 0;
        l_msg_data               := NULL;
        l_clev_rec_type.sts_code := 'TERMINATED';
        l_clev_rec_type.id       := contract_rec.subline_id;

        okc_contract_pub.update_contract_line(p_api_version       => 1.0,
			          p_init_msg_list     => fnd_api.g_true,
			          x_return_status     => l_return_status,
			          x_msg_count         => l_msg_count,
			          x_msg_data          => l_msg_data,
			          p_restricted_update => fnd_api.g_false,
			          p_clev_rec          => l_clev_rec_type,
			          x_clev_rec          => l_out_clev_rec);

        IF (l_return_status <> fnd_api.g_ret_sts_success) THEN
          RETURN - 1;
        END IF;
      END IF;

      -- check if any other non terminated sublines under same line .
      -- the specific one I entered for should be already terminated.
      -- hence not excuding it.
      SELECT COUNT(1)
      INTO   l_active_sublines
      FROM   okc_k_lines_b cnt_lines
      WHERE  cnt_lines.cle_id = contract_rec.subline_cle
      AND    cnt_lines.sts_code IN ('ACTIVE', 'SIGNED', 'HOLD'); -- Active contracts

      IF l_active_sublines > 0 THEN
        RETURN 0; -- return, closed the line, return ok (other sublines still open)

      ELSE
        -- need to close the line itself

        l_return_status          := NULL;
        l_msg_count              := 0;
        l_msg_data               := NULL;
        l_clev_rec_type.sts_code := 'TERMINATED';
        l_clev_rec_type.id       := contract_rec.subline_cle;

        okc_contract_pub.update_contract_line(p_api_version       => 1.0,
			          p_init_msg_list     => fnd_api.g_true,
			          x_return_status     => l_return_status,
			          x_msg_count         => l_msg_count,
			          x_msg_data          => l_msg_data,
			          p_restricted_update => fnd_api.g_false,
			          p_clev_rec          => l_clev_rec_type,
			          x_clev_rec          => l_out_clev_rec);

        IF (l_return_status <> fnd_api.g_ret_sts_success) THEN
          RETURN - 1;
        END IF;

      END IF;

      -- check if all lines for contract header are closed
      SELECT COUNT(1)
      INTO   l_active_sublines
      FROM   okc_k_lines_b cnt_lines
      WHERE  cnt_lines.chr_id = contract_rec.cnt_header_id
      AND    cnt_lines.sts_code IN ('ACTIVE', 'SIGNED', 'HOLD'); -- Active contracts

      IF l_active_sublines = 0 THEN
        -- need to close the main contract header
        l_cnt_header.p_contract_id       := contract_rec.cnt_header_id;
        l_cnt_header.p_contract_number   := contract_rec.contract_number;
        l_cnt_header.p_contract_modifier := contract_rec.h_contract_number_modifier;
        l_cnt_header.p_orig_end_date     := contract_rec.h_end_date;
        l_cnt_header.p_termination_date  := trunc(SYSDATE);
        l_cnt_header.p_contract_version  := NULL;

        okc_terminate_pub.terminate_chr(p_api_version                 => 1.0,
			    p_init_msg_list               => okc_api.g_true,
			    x_return_status               => l_return_status,
			    x_msg_count                   => l_msg_count,
			    x_msg_data                    => l_msg_data,
			    p_terminate_in_parameters_rec => l_cnt_header,
			    p_do_commit                   => okc_api.g_false);

        IF l_return_status <> fnd_api.g_ret_sts_success THEN
          -- 'S' then
          RETURN - 1;
        END IF;

      END IF;

    END LOOP; -- end loop for setting lines status to Terminated

    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN - 1;
  END sync_ib_terminate_sc;

  PROCEDURE get_instance_id(p_data_rec           tp_data_rec_type,
		    p_instance_id        OUT NUMBER,
		    p_parent_instance_id OUT NUMBER) IS
  BEGIN
    BEGIN
      SELECT aa.instance_id
      INTO   p_instance_id
      FROM   (SELECT cii.serial_number,
	         cii.instance_id,
	         cii.instance_number,
	         cii.object_version_number,
	         cii.attribute12
	  FROM   csi_item_instances cii
	  WHERE  cii.inventory_item_id = p_data_rec.inventory_item_id
	  AND    (cii.serial_number = p_data_rec.serial_number OR
	        substr(cii.serial_number,
		     1,
		     instr(cii.serial_number, '-') - 1) =
	        p_data_rec.serial_number)
	  ORDER  BY cii.serial_number) aa
      WHERE  rownum = 1;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN;
    END;

    BEGIN

      SELECT cir.object_id --- Instance id of the parent
      INTO   p_parent_instance_id
      FROM   csi_ii_relationships cir
      WHERE  cir.subject_id = p_instance_id
      AND    cir.active_end_date IS NULL;  -- INC0175066

    EXCEPTION
      WHEN OTHERS THEN
        p_parent_instance_id := NULL;
    END;

  END get_instance_id;

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
  --  3.2   25-Jul-2018    Dan Melamed   CHG0042574 CTASK0037631: Add spcific Instance ID Parameter, Add instance status for site validations
  --  3.3   27/01/2019     Roman W.      INC0145202
  --  3.4   17/11/2019     Adi Safin     INC0175066 - Fix in get_instance_id procedure to get only active relationships IB's
  -----------------------------------------------------------------------
  PROCEDURE sync_ib_sfdc2oracle(errbuf        OUT VARCHAR2,
		        retcode       OUT VARCHAR2,
		        p_instance_id VARCHAR2) IS
    TYPE c_ref_cur IS REF CURSOR;
    c_processcur     c_ref_cur;
    c_processcur_itm c_ref_cur;

    l_r_data_rec       tp_data_rec_type;
    l_last_run_date_vc VARCHAR2(255);
    l_exclude_updateby VARCHAR2(255);
    l_interim_solution VARCHAR2(255) := fnd_profile.value('XXCSI_INTERIM_SOLUTION_PERIOD');
    l_item_cnt         NUMBER := 0;
    l_use_select       VARCHAR2(4000);

    l_apps_init   VARCHAR2(1);
    l_exist_in_ib VARCHAR2(1);

    l_item_trackable_val           VARCHAR2(1);
    l_account_exist_in_oracle_val  VARCHAR2(1);
    l_end_cust_exist_in_oracle_val VARCHAR2(1);

    l_item_site_exists  VARCHAR2(1);
    l_item_site_belongs VARCHAR2(1);

    l_tmp_date       DATE;
    l_interface_user VARCHAR2(255) := 'BPEL_INTF';

    l_ex_validation_err EXCEPTION;
    l_ex_process_err    EXCEPTION;

    l_val_err_code NUMBER;
    l_val_err_desc VARCHAR2(255);

    l_log_text   VARCHAR2(4000);
    l_log_prefix VARCHAR2(4000);

    l_master_organization_id NUMBER := xxinv_utils_pkg.get_master_organization_id;
    l_item_segment           VARCHAR2(200);

    l_account_name     VARCHAR2(255);
    l_action_done      VARCHAR2(255);
    l_status_code      VARCHAR(255);
    l_ib_location_type VARCHAR2(255);
    l_lb               BOOLEAN;
    l_start_run_time   DATE := SYSDATE;

    l_xxssys_event_rec     xxssys_events%ROWTYPE;
    l_xxssys_new_event_rec xxssys_events%ROWTYPE;

    l_target_name VARCHAR2(255) := 'EBS';
    l_entity_name VARCHAR2(255) := 'ASSET';

    l_event_select       VARCHAR2(2000);
    l_other_event_exists NUMBER;

    l_parent_instance_id NUMBER;
    l_instance_id        NUMBER;

    -- Danm CHG0042574-V2
    itemrec xxobjt.xxssys_events_rec;
    itemtab xxobjt.xxssys_events_tab;

  BEGIN

    retcode := 0;

    IF fnd_global.conc_request_id < 1 THEN
      g_run_state      := 'LOCAL';
      l_interface_user := 'ADI.SAFIN'; -- Default user set as Adi Safin
    ELSE
      l_interface_user := fnd_global.user_name;
    END IF;
    l_apps_init := sf2ora_initialize(l_interface_user,
			 'Service Contracts Manager',
			 'OKS'); -- initialize only if running locally.
    -- init the OKS  ('Oracle Installed Base User', 'CSI' for now,  are IB Responsibilities, not needed for the APIs, hence initializing for SC only)

    IF l_apps_init = 'X' THEN
      errbuf  := 'Unable to initialize into Interface User : ';
      retcode := 2;
      -- general error: exit doing nothing at all.
      RETURN;
    END IF;

    l_last_run_date_vc := fnd_profile.value('XXCSI_LAST_RUNING_DATE');

    -- CTASK0037631 Danm 25-Jul-2018 : If running on specific instance ID set date to be used as last update to the past (using hr_general here)
    IF p_instance_id IS NOT NULL THEN
      l_last_run_date_vc := to_char(hr_general.start_of_time,
			'DD-MON-YYYY HH24:MI:SS');
    END IF;

    -- validate date parameter (in profile) is filled and is valid
    IF l_last_run_date_vc IS NULL THEN
      errbuf  := 'Last run date missing : please update the profile XXCSI_LAST_RUNING_DATE';
      retcode := 2;
      -- general error : exit doing nothing at all.
      RETURN;
    ELSE
      BEGIN

        l_tmp_date         := to_date(l_last_run_date_vc,
			  'DD-MON-YYYY HH24:MI:SS');
        l_last_run_date_vc := to_char(l_tmp_date, 'DD-MON-YYYY HH24:MI:SS');

        IF p_instance_id IS NULL THEN
          sf2ora_update_log(' Running interface with date as : ' ||
		    l_last_run_date_vc);
        ELSE
          sf2ora_update_log(' Running interface for instance ID : ' ||
		    p_instance_id);
        END IF;

      EXCEPTION
        WHEN OTHERS THEN
          errbuf  := 'Invalid date format set in profile XXCSI_LAST_RUNING_DATE : Please use DD-MON-YYYY HH24:MI:SS)';
          retcode := 2;
          -- general error : exit doing nothing at all.
          RETURN;
      END;
    END IF;

    -- List of values for the profile to ignore(for not infinite loop of updates and re-updates invoked by those updates) --

    SELECT listagg(ffvl.flex_value, ''',''') within GROUP(ORDER BY ffvl.flex_value_set_id)
    INTO   l_exclude_updateby
    FROM   fnd_flex_values_vl  ffvl,
           fnd_flex_value_sets ffvs
    WHERE  1 = 1
    AND    ffvs.flex_value_set_name = 'XXCS_IB_SYNC_EXCLUDE_UPDT_BY'
    AND    ffvl.flex_value_set_id = ffvs.flex_value_set_id
    AND    ffvl.enabled_flag = 'Y';

    l_exclude_updateby := '''' || nvl(l_exclude_updateby, 'NULL') || ''''; -- as we must pass some parameter to the message.

    -- get Query and update query params - date cutoff and users to ignore in updated_by
    IF upper(l_interim_solution) IN ('Y', 'YES') THEN
      fnd_message.clear;
      fnd_message.set_name('XXOBJT', 'XXCS_SF_CS_QRY_INTERIM');
      fnd_message.set_token('WHERE_DATE',
		    'to_Date(''' || l_last_run_date_vc ||
		    ''', ''DD-MON-YYYY HH24:MI:SS'')');
      fnd_message.set_token('INSTANCE_ID', nvl(p_instance_id, 'NULL'));
      fnd_message.set_token('WHERE_BY', l_exclude_updateby);
      l_use_select := fnd_message.get;
    ELSE
      fnd_message.clear;
      fnd_message.set_name('XXOBJT', 'XXCS_SF_CS_QRY_PERM');
      fnd_message.set_token('WHERE_DATE',
		    'to_Date(''' || l_last_run_date_vc ||
		    ''', ''DD-MON-YYYY HH24:MI:SS'')');
      fnd_message.set_token('INSTANCE_ID', nvl(p_instance_id, 'NULL'));
      fnd_message.set_token('WHERE_BY', l_exclude_updateby);
      l_use_select := fnd_message.get;
    END IF;

    sf2ora_update_log(l_use_select);
    sf2ora_update_log('============================================');
    sf2ora_update_log('============================================');

    -- Insert into XXSSYS_events table section
    OPEN c_processcur FOR l_use_select;
    LOOP
      FETCH c_processcur
        INTO l_r_data_rec;
      EXIT WHEN c_processcur%NOTFOUND;

      l_xxssys_event_rec := NULL;

      l_xxssys_event_rec.target_name     := l_target_name;
      l_xxssys_event_rec.entity_name     := l_entity_name;
      l_xxssys_event_rec.active_flag     := 'Y';
      l_xxssys_event_rec.entity_id       := l_r_data_rec.instance_id;
      l_xxssys_event_rec.last_updated_by := g_user_id;
      l_xxssys_event_rec.created_by      := g_user_id;

      xxssys_event_pkg.insert_event(p_xxssys_event_rec => l_xxssys_event_rec,
			p_db_trigger_mode  => 'Y'); -- Danm CHG0042574-V2

    END LOOP;

    COMMIT;

    CLOSE c_processcur;

    -- CHG0042574-V2 : Dan M - Working with Table of rec instead of directly on the xxssys events
    -- Take only relevant items in record.
    SELECT xxobjt.xxssys_events_rec(event_id         => xxevt.event_id,
			bpel_instance_id => NULL,
			active_flag      => NULL,
			status           => NULL,
			request_messgae  => NULL,
			err_message      => NULL,
			attribute1       => NULL,
			attribute2       => NULL,
			attribute3       => NULL,
			attribute4       => NULL,
			attribute5       => NULL,
			api_message      => NULL,
			external_id      => xxevt.entity_id)
    BULK   COLLECT
    INTO   itemtab
    FROM   xxssys_events xxevt
    WHERE  xxevt.target_name = l_target_name
    AND    xxevt.entity_name = l_entity_name
    AND    xxevt.status = 'NEW'
    AND    xxevt.entity_id = nvl(p_instance_id, xxevt.entity_id); -- INC0145202

    -- CHG0042574-V2 : Dan M - Working with Table of rec instead of directly on the xxssys events

    FOR itemrec IN (SELECT *
	        FROM   TABLE(itemtab)) LOOP

      BEGIN
        -- main process exception keeper

        l_log_prefix := NULL; -- reset
        l_log_text   := NULL; -- reset

        -- get Query and update query params - date cutoff and users to ignore in updated_by
        IF upper(l_interim_solution) IN ('Y', 'YES') THEN
          fnd_message.clear;
          fnd_message.set_name('XXOBJT', 'XXCS_SF_CS_QRY_INTERIM');
          fnd_message.set_token('WHERE_DATE',
		        'to_Date(''' || l_last_run_date_vc ||
		        ''', ''DD-MON-YYYY HH24:MI:SS'')');
          fnd_message.set_token('INSTANCE_ID', itemrec.external_id);
          fnd_message.set_token('WHERE_BY', l_exclude_updateby);
          l_use_select := fnd_message.get;
        ELSE
          fnd_message.clear;
          fnd_message.set_name('XXOBJT', 'XXCS_SF_CS_QRY_PERM');
          fnd_message.set_token('WHERE_DATE',
		        'to_Date(''' || l_last_run_date_vc ||
		        ''', ''DD-MON-YYYY HH24:MI:SS'')');
          fnd_message.set_token('INSTANCE_ID', itemrec.external_id);
          fnd_message.set_token('WHERE_BY', l_exclude_updateby);
          l_use_select := fnd_message.get;
        END IF;

        OPEN c_processcur_itm FOR l_use_select;
        FETCH c_processcur_itm
          INTO l_r_data_rec;

        IF c_processcur_itm%NOTFOUND THEN
          xxssys_event_pkg.update_error(p_event_id    => itemrec.event_id,
			    p_err_message => 'Item not found in view');
          RAISE l_ex_process_err;
        END IF;

        -- All the checks to be done here.

        l_val_err_code                 := 0;
        l_val_err_desc                 := NULL;
        l_exist_in_ib                  := NULL;
        l_item_trackable_val           := NULL;
        l_account_exist_in_oracle_val  := NULL;
        l_end_cust_exist_in_oracle_val := NULL;
        l_item_site_exists             := NULL;
        l_item_site_belongs            := NULL;
        l_item_cnt                     := l_item_cnt + 1;

        l_parent_instance_id := NULL;
        l_instance_id        := NULL;
        -- IB Exist in ORACLE --
        sf2ora_ib_exist_in_ora(l_r_data_rec.inventory_item_id,
		       l_r_data_rec.serial_number,
		       l_exist_in_ib,
		       l_ib_location_type,
		       l_val_err_code,
		       l_val_err_desc);

        IF l_val_err_code = -1 THEN
          retcode := 1;
          fnd_message.clear;
          fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_API_ERR');
          fnd_message.set_token('API_ERR', l_val_err_desc);
          l_log_text := fnd_message.get;
          RAISE l_ex_validation_err;
        ELSE

          /* get ITEM NR (for messaging throughout interface) */
          BEGIN

	SELECT segment1 -- used for messaging/Logging
	INTO   l_item_segment
	FROM   mtl_system_items_b
	WHERE  inventory_item_id = l_r_data_rec.inventory_item_id
	AND    organization_id = l_master_organization_id;

          EXCEPTION
	WHEN OTHERS THEN
	  retcode := 1;
	  fnd_message.clear;
	  fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_API_ERR');
	  fnd_message.set_token('API_ERR',
			'Error getting item number from mtl_system_items_b for inventory Item ID ' ||
			l_r_data_rec.inventory_item_id);
	  l_log_text := fnd_message.get;
	  RAISE l_ex_validation_err;
          END;

          -- get prefix for forthcoming messages.
          fnd_message.clear;
          fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_PREFIX');
          fnd_message.set_token('INSTANCE_NUMBER',
		        l_r_data_rec.serial_number || '(' ||
		        l_item_segment || ')');
          l_log_prefix := rpad(fnd_message.get, 50, ' ');

          IF nvl(l_exist_in_ib, 'Y') = 'N' THEN
	-- If (and only if) Item not in IB, check if item is trackable.
	sf2ora_itemtrackable(l_r_data_rec.inventory_item_id,
		         l_item_trackable_val,
		         l_val_err_code,
		         l_val_err_desc);

	IF l_val_err_code = -1 THEN
	  retcode := 1;
	  fnd_message.clear;
	  fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_API_ERR');
	  fnd_message.set_token('API_ERR', l_val_err_desc);
	  l_log_text := fnd_message.get;
	  RAISE l_ex_validation_err;

	ELSIF nvl(l_item_trackable_val, 'N') = 'N' THEN
	  -- item is not trackable - exit
	  retcode := 1;
	  fnd_message.clear;
	  fnd_message.set_name('XXOBJT',
		           'XXCS_IB_SYNC_PN_NOT_TRACKABLE');
	  fnd_message.set_token('PART_NUMBER', l_item_segment);
	  l_log_text := fnd_message.get;
	  RAISE l_ex_validation_err;
	END IF;
          END IF;
        END IF;

        BEGIN

          -- get item status for validation : if Inventory than error out.
          SELECT cis.name
          INTO   l_status_code
          FROM   csi_instance_statuses cis
          WHERE  cis.instance_status_id = l_r_data_rec.instance_status_id;

        EXCEPTION
          WHEN OTHERS THEN
	l_status_code := NULL;
        END;

        IF l_ib_location_type = 'INVENTORY' THEN
          retcode := 1;
          fnd_message.clear;
          fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_LOCATION_TYPE');
          fnd_message.set_token('LOCATION_TYPE', l_ib_location_type);
          l_log_text := fnd_message.get;
          RAISE l_ex_validation_err;
        END IF;

        -- validate account exists : (Null will return error)
        sf2ora_account_exist_in_ora(l_r_data_rec.owner_party_account_id,
			l_account_exist_in_oracle_val,
			l_account_name,
			l_val_err_code,
			l_val_err_desc);
        IF l_val_err_code = -1 THEN
          retcode := 1;
          fnd_message.clear;
          fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_API_ERR');
          fnd_message.set_token('API_ERR', l_val_err_desc);
          l_log_text := fnd_message.get;
          RAISE l_ex_validation_err;

        ELSIF l_account_exist_in_oracle_val = 'N' THEN
          retcode := 1;
          fnd_message.clear;
          fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_ACCOUNT_NOT_ACTIV');
          fnd_message.set_token('ACCOUNT_NAME', l_account_name);
          l_log_text := fnd_message.get;
          RAISE l_ex_validation_err;

        END IF;

        -- Validate End Customer exists in oracle. Null will NOT return error.
        sf2ora_end_cust_exist_in_ora(l_r_data_rec.account_end_customer_id,
			 l_end_cust_exist_in_oracle_val,
			 l_account_name,
			 l_val_err_code,
			 l_val_err_desc);

        IF l_val_err_code = -1 THEN
          retcode := 1;
          fnd_message.clear;
          fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_API_ERR');
          fnd_message.set_token('API_ERR', l_val_err_desc);
          l_log_text := fnd_message.get;
          RAISE l_ex_validation_err;

        ELSIF l_end_cust_exist_in_oracle_val = 'N' THEN
          retcode := 1;
          fnd_message.clear;
          fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_EC_ACCT_NOT_ACTIV');
          fnd_message.set_token('ACCOUNT_NAME', l_account_name);
          l_log_text := fnd_message.get;
          RAISE l_ex_validation_err;

        END IF;

        -- Validation : Check sites exist in Oracle.
        sf2ora_check_all_sites_exist(l_r_data_rec.install_site_id,
			 l_r_data_rec.ship_to_site_id,
			 l_r_data_rec.bill_to_site_id,
			 l_r_data_rec.instance_status_id, -- CHG0042574 CTASK0037631: Add spcific Instance ID Parameter, Add instance status for site validations
			 l_item_site_exists,
			 l_val_err_code,
			 l_val_err_desc);

        IF l_val_err_code = -1 THEN
          retcode := 1;
          -- sf2ora_update_log( l_val_err_desc,l_log_prefix ); -- Remove duplicate errror
          l_log_text := l_val_err_desc;
          RAISE l_ex_validation_err;
        ELSIF l_item_site_exists = 'N' THEN
          retcode := 1;

          l_log_text := l_val_err_desc;
          RAISE l_ex_validation_err;
        END IF;

        -- Validation : Check sites belong to correct account(s)
        sf2ora_check_all_sites_belong(l_r_data_rec.install_site_id,
			  l_r_data_rec.ship_to_site_id,
			  l_r_data_rec.bill_to_site_id,
			  l_r_data_rec.account_end_customer_id,
			  l_r_data_rec.owner_party_account_id,
			  l_item_site_belongs,
			  l_val_err_code,
			  l_val_err_desc);

        IF l_val_err_code = -1 THEN
          retcode := 1;
          --sf2ora_update_log( l_val_err_desc,l_log_prefix); -- Remove duplicate errror
          l_log_text := l_val_err_desc;
          RAISE l_ex_validation_err;
        ELSIF l_item_site_belongs = 'N' THEN
          retcode    := 1;
          l_log_text := l_val_err_desc;
          RAISE l_ex_validation_err;
        END IF;

        -- All validations passed

        -- Terminate contracts (if needed)
        IF upper(l_r_data_rec.terminate_contracts) = 'YES' THEN
          l_val_err_code := sync_ib_terminate_sc(l_r_data_rec.instance_id);
          IF l_val_err_code = 0 THEN
	NULL; -- all is ok (from contract prepective)
	COMMIT; -- commit the contract part;
          ELSE
	retcode := 1;
	-- error
	fnd_message.clear;
	fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_API_ERR');
	fnd_message.set_token('API_ERR', 'Error Terminating Contracts');
	l_log_text := fnd_message.get;
	RAISE l_ex_process_err;
          END IF;
        END IF;
        --continue with creating (or updating) item.

        get_instance_id(l_r_data_rec, l_instance_id, l_parent_instance_id);
        IF l_parent_instance_id IS NOT NULL AND
           l_parent_instance_id <> l_instance_id THEN
          -- has parent : update the parent
          create_missing_instance_single(l_r_data_rec,
			     l_parent_instance_id,
			     NULL,
			     l_action_done,
			     l_val_err_code,
			     l_val_err_desc);
        END IF;

        IF l_val_err_code = 0 THEN
          create_missing_instance_single(l_r_data_rec,
			     l_instance_id,
			     l_parent_instance_id,
			     l_action_done,
			     l_val_err_code,
			     l_val_err_desc);
        END IF;

        IF l_val_err_code = 0 THEN
          -- success
          COMMIT; --CHG0042574 hotfix
          fnd_message.clear;
          fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_SUCCESS');
          --             fnd_message.set_token('ACTION_TYPE', l_action_done);
          l_log_text := fnd_message.get;
          sf2ora_update_log(l_log_text, l_log_prefix);
          xxssys_event_pkg.update_success(p_event_id => itemrec.event_id);

          IF l_interim_solution IN ('Y', 'YES') THEN
	l_xxssys_new_event_rec := NULL;

	l_xxssys_new_event_rec.target_name     := 'STRATAFORCE';
	l_xxssys_new_event_rec.entity_name     := 'ASSET';
	l_xxssys_new_event_rec.event_name      := 'INSTALL_BASE_SHIP';
	l_xxssys_new_event_rec.attribute1      := 'INSTALL_BASE_SHIP';
	l_xxssys_new_event_rec.active_flag     := 'Y';
	l_xxssys_new_event_rec.entity_id       := l_r_data_rec.instance_id;
	l_xxssys_new_event_rec.last_updated_by := g_user_id;
	l_xxssys_new_event_rec.created_by      := g_user_id;

	xxssys_event_pkg.insert_event(p_xxssys_event_rec => l_xxssys_new_event_rec,
			      p_db_trigger_mode  => 'Y'); -- Danm CHG0042574-V2

          END IF;

        ELSE
          retcode := 1;
          -- error
          fnd_message.clear;
          fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_API_ERR');
          fnd_message.set_token('API_ERR', l_val_err_desc);
          l_log_text := fnd_message.get;
          RAISE l_ex_process_err;
          /*
                       sf2ora_update_log( l_log_text,l_log_prefix );
                       xxssys_event_pkg.update_error(p_event_id => itemrec.event_id, p_err_message => l_log_text);
          */
        END IF;

      EXCEPTION
        WHEN l_ex_validation_err THEN

          retcode := 1;
          sf2ora_update_log(l_log_text, l_log_prefix);
          xxssys_event_pkg.update_error(p_event_id    => itemrec.event_id,
			    p_err_message => substr(l_log_text,
					    1,
					    150));

        WHEN l_ex_process_err THEN

          retcode := 1;
          sf2ora_update_log(l_log_text, l_log_prefix);
          xxssys_event_pkg.update_error(p_event_id    => itemrec.event_id,
			    p_err_message => substr(l_log_text,
					    1,
					    150));

        WHEN OTHERS THEN

          retcode    := 1;
          l_log_text := substr(SQLERRM, 1, 250);
          sf2ora_update_log(l_log_text);
          xxssys_event_pkg.update_error(p_event_id    => itemrec.event_id,
			    p_err_message => substr(l_log_text,
					    1,
					    150));
      END;

      CLOSE c_processcur_itm;

    END LOOP;

    -- CTASK0037631 Danm 25-Jul-2018 : update last run profile only if NOT running on specific ID.
    IF p_instance_id IS NULL THEN

      -- update profile with current date at the run start time. (run can take time)
      l_lb := fnd_profile.save(x_name       => 'XXCSI_LAST_RUNING_DATE',
		       x_value      => to_char(l_start_run_time,
				       'DD-MON-YYYY HH24:MI:SS'),
		       x_level_name => 'SITE');
      COMMIT;

    END IF;

    IF l_lb = FALSE THEN
      retcode := 2;
      fnd_message.clear;
      fnd_message.set_name('XXOBJT', 'XXCS_IB_SYNC_API_ERR');
      fnd_message.set_token('API_ERR',
		    'Could not update profile for last run performed');
      l_log_text := fnd_message.get;
      sf2ora_update_log(l_log_text);
    END IF;
  END sync_ib_sfdc2oracle;

END xxcs_ib_item_creation;
/
