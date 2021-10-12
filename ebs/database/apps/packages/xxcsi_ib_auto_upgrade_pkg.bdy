create or replace package body xxcsi_ib_auto_upgrade_pkg IS

  --------------------------------------------------------------------
  --  name:            XXCSI_IB_AUTO_UPGRADE_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/03/2011 10:42:40 AM
  --------------------------------------------------------------------
  --  purpose :        program that perform upgrade in Install Base
  --                   accourding to upgrade rules.
  --                   Currently printers upgrade process in IB performed manualy.
  --                   CUST398 - CRM - Automated upgrade in IB
  --                   CUST419 - PZ2Oracle interface for UG upgrade in IB will call this package
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/03/2011  Dalit A. Raviv    initial build
  --  1.1  23/05/2011  Dalit A. Raviv    add logic changes to support cust419
  --  1.2  17/07/2011  Dalit A. Raviv    Roman found that instead of doing create new ii, close old ii,
  --                                     create new relationship etc, we can use the update ii API
  --                                     with transaction type 205 (Item Number and or Serial Number Change)
  --                                     this type give the ability to update item instance with new inventory_item_id.
  --                                     create new procedure main (the old one changed to main_old).
  --  1.3  04/10/2011  Dalit A. Raviv    Objet company changed the logic of the upgrade today upgrade item can change
  --                                     only to one printer the new logic is that the same upgrade can create
  --                                     different printers. view xxcs_sales_ug_items_v hold all the logic of the upgrade.
  --  1.4  29/01/2012  Dalit A. Raviv    Procedure get_upgrade_type - change select logic
  --  1.5  20/03/2012  Dalit A. Raviv    change logic of upgrade.
  --                                     new procedure get_sales_ug_items_details
  --                                     update procedure get_HASP_after_upgrade
  --                                                      update_item_instance_new
  --                                                      main
  --  1.6  17/04/2012  Dalit A. Raviv    CUST419 1.4 - add ability to reverse upgrade
  --                                     new procedure reverse_upgrade_item
  --  1.7  28/06/2012  Dalit A. Raviv    procedure get_upgrade_type - handle of multiple upgrades for the same machine.
  --  1.8  22/07/2012  Dalit A. Raviv    Procedure get_upgrade_type - add condition
  --  1.9  24/10/2012  Adi Safin         procedure get_upgrade_type - add condition and too_many_rows exception get_upgrade_type
  --  2.0  24/04/2014  Adi Safin         procedure get_HASP_after_upgrade-  BUGFIX CHG0032033 - get only BOMs from IPK organization
  --  2.1  15/03/2015  Adi Safin         CHG0034735 - change source table from csi_item_instances to xxsf_csi_item_instances
  --                                     Modify procedure create_item_instance Assign NULL to attribute 12,16 when createing the HASP IB
  --  2.2  16/07/2015  Michal Tzvik      CHG0035439 -  change source table from xxsf_csi_item_instances to csi_item_instances
  --                                     initiate g_master_organization_id in declaration area and replace hard code with it.
  --  2.3  08-Aug-2016 Lingaraj Sarangi  CHG0037320 - Objet studio SW update
  --------------------------------------------------------------------
  g_master_organization_id NUMBER := xxinv_utils_pkg.get_master_organization_id; -- Michal Tzvik 21.07.2015 : Add initial value here instead of in procedure main in order to be available always;
  g_user_id                NUMBER;
  g_parent_organization_id NUMBER;
  g_user_name              VARCHAR2(150);
  g_hasp_sn                VARCHAR2(30);
  -- Dalit A. Raviv 06/10/2011
  g_from_sw             VARCHAR2(150);
  g_before_upgrade_item NUMBER;
  g_sw_hw               VARCHAR2(20);    
  
  --------------------------------------------------------------------
  --  name:            print_message
  --  create by:       L.Sarangi
  --  Revision:        1.0
  --  creation date:   24/08/2016
  --------------------------------------------------------------------
  --  purpose :        print_message  will print log messages to Concurrent log File or DBMS output
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/08/2016  L.Sarangi         initial build
  --------------------------------------------------------------------
  PROCEDURE print_message(p_msg         VARCHAR2,
		                      p_destination VARCHAR2 DEFAULT fnd_file.log) IS
  BEGIN
    IF fnd_global.conc_request_id = '-1' THEN
      dbms_output.put_line(p_msg);
    ELSE
      fnd_file.put_line(p_destination, p_msg);
    END IF;
  END print_message;
  
  --------------------------------------------------------------------
  --  name:            handle_log
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/03/2011 10:42:40 AM
  --------------------------------------------------------------------
  --  purpose :        Handle write to log tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/03/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_log(p_log_rec  IN t_log_rec,
                       p_err_code OUT VARCHAR2,
                       p_err_msg  OUT VARCHAR2) IS

    PRAGMA AUTONOMOUS_TRANSACTION;
    l_entity_id NUMBER := NULL;
  BEGIN    
    p_err_code := 0;
    p_err_msg  := NULL;

    -- get entity id
    SELECT xxcs_ib_auto_upgrade_log_s.nextval
    INTO   l_entity_id
    FROM   dual;

    INSERT INTO xxcs_ib_auto_upgrade_log_tbl
      (entity_id,
       status,
       instance_id_old,
       serial_number_old,
       upgrade_type, -- inventory_item_id from map tbl
       instance_id_new,
       hasp_instance_id_new,
       msg_code,
       msg_desc,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by)
    VALUES
      (l_entity_id,
       p_log_rec.status,
       p_log_rec.instance_id_old,
       p_log_rec.serial_number_old,
       p_log_rec.upgrade_type,
       p_log_rec.instance_id_new,
       p_log_rec.hasp_instance_id_new,
       p_log_rec.msg_code,
       p_log_rec.msg_desc,
       SYSDATE,
       g_user_id,
       SYSDATE,
       g_user_id);

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'GEN EXC - insert_log - ' || substr(SQLERRM, 1, 240);
  END handle_log;

  --------------------------------------------------------------
  PROCEDURE close_contract(p_err_code OUT VARCHAR2,
                           p_err_desc OUT VARCHAR2) IS

    l_ovn                         VARCHAR2(9) := NULL;
    l_init_msg_lst                VARCHAR2(500);
    l_return_status               VARCHAR2(2000);
    l_msg_count                   NUMBER;
    l_msg_data                    VARCHAR2(2500);
    l_msg_index_out               NUMBER;
    l_end_date                    DATE;
    l_terminate_in_parameters_rec okc_terminate_pvt.terminate_in_parameters_rec;
    l_contract_number_modifier    okc_k_headers_v.contract_number_modifier%TYPE;

  BEGIN    
    l_return_status := NULL;
    l_msg_count     := NULL;
    l_init_msg_lst  := NULL;
    l_msg_index_out := NULL;
    l_msg_data      := NULL;
    l_ovn           := NULL;
    l_end_date      := NULL;

    /*
    DE300009S
    1800000
    22-MAR-2011
    Machine Upgraded
    XXUG
    Type terminate_in_parameters_rec is RECORD (
                 p_Contract_id              number ,
                 p_contract_number          okc_k_headers_v.contract_number%type,
                 p_contract_modifier        okc_k_headers_v.contract_number_modifier%type,
                 p_orig_end_date            date ,
                 p_contract_version         varchar2(9),
                 p_termination_date         date ,
                 p_termination_reason       fnd_lookups.lookup_code%type );
    */

    --OKC_TERMINATE_PUB
    --OKC_TERMINATE_PVT
    --OKC_CONTRACT_PUB
    fnd_global.apps_initialize(user_id => 1308, resp_id => 21708, resp_appl_id => 515, security_group_id => 0);

    /*SELECT h.object_version_number
    into   l_ovn
    FROM   okc_k_headers_all_b h
    where  h.id = 1800000;*/
    /*select t.major_version||'.'||t.minor_version
    into   l_ovn
    from   okc.okc_k_vers_numbers t
    where  t.chr_id = 1800000 ;--1772000*/

    SELECT b.contract_number_modifier, -- b.contract_number,
           --b.date_terminated,
           --b.trn_code,
           --b.start_date,
           b.end_date,
           t.major_version || '.' || t.minor_version
    --b.object_version_number
    INTO   l_contract_number_modifier,
           l_end_date,
           l_ovn
    FROM   okc_k_headers_all_b    b,
           okc.okc_k_vers_numbers t
    WHERE  b.id = 1800000
    AND    b.id = t.chr_id;

    /*

    OKC_CONTRACT_PUB.lock_contract_header(
    p_api_version       => 1.0, -- i n
    p_init_msg_list     => l_init_msg_lst, -- i v
    x_return_status     => l_return_status, -- o v
    x_msg_count         => l_msg_count,     -- o n
    x_msg_data          => l_msg_data,      -- o v
    p_chrv_tbl          => l_chrv_tbl);
    */
    l_terminate_in_parameters_rec.p_contract_id        := 1800000;
    l_terminate_in_parameters_rec.p_contract_number    := 'DE300009S';
    l_terminate_in_parameters_rec.p_contract_modifier  := l_contract_number_modifier;
    l_terminate_in_parameters_rec.p_orig_end_date      := l_end_date;
    l_terminate_in_parameters_rec.p_contract_version   := l_ovn;
    l_terminate_in_parameters_rec.p_termination_date   := trunc(SYSDATE);
    l_terminate_in_parameters_rec.p_termination_reason := 'XXUG';

    okc_terminate_pub.terminate_chr(p_api_version => 1, -- i n
                                    p_init_msg_list => l_init_msg_lst, -- i v DEFAULT OKC_API.G_FALSE,
                                    x_return_status => l_return_status, -- o v
                                    x_msg_count => l_msg_count, -- o n
                                    x_msg_data => l_msg_data, -- o v
                                    p_terminate_in_parameters_rec => l_terminate_in_parameters_rec, -- i
                                    p_do_commit => okc_api.g_false -- i vOKC_API.G_FALSE
                                    );
    IF (l_return_status <> 'S') THEN
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index => -1, p_encoded => 'F', p_data => l_msg_data, p_msg_index_out => l_msg_index_out);
        dbms_output.put_line('Err: ' || substr(l_msg_data, 1, 240));
      END LOOP;
      ROLLBACK;
      p_err_code := 1;
      p_err_desc := 'Err: ' || l_msg_data;
    ELSE
      dbms_output.put_line('Success');
      COMMIT;
      p_err_code := 0;
      p_err_desc := NULL;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_desc := 'GEN EXC - ' || substr(SQLERRM, 1, 240);
  END close_contract;

  --------------------------------------------------------------------
  -- name:            get_sales_ug_items_details
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   20/03/2012
  --------------------------------------------------------------------
  -- purpose :        Get upgrade item details from lookup
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  20/03/2012  Dalit A. Raviv   initial build
  -- 1.1  16/07/2015  Michal Tzvik     CHG0035439 - change source table from xxsf_csi_item_instances to csi_item_instances
  --------------------------------------------------------------------
  PROCEDURE get_sales_ug_items_details(p_upgrade_item_id     IN NUMBER,
                                       p_before_upgrade_item IN NUMBER,
                                       p_before_upgrade_hasp IN NUMBER,
                                       p_entity              IN VARCHAR2 DEFAULT 'DR',
                                       x_after_upgrade_item  OUT NUMBER,
                                       x_after_upgrade_hasp  OUT NUMBER,
                                       x_from_sw_version     OUT VARCHAR2,
                                       p_err_code            OUT VARCHAR2,
                                       p_err_desc            OUT VARCHAR2) IS
  BEGIN   
    fnd_file.put_line(fnd_file.log, 'get_sales_ug_items_details parameters:');
    fnd_file.put_line(fnd_file.log, 'p_upgrade_item_id:' ||
                       p_upgrade_item_id ||
                       ',p_before_upgrade_item:' ||
                       p_before_upgrade_item ||
                       ',p_before_upgrade_hasp:' ||
                       p_before_upgrade_hasp || ',p_entity:' ||
                       p_entity);
    p_err_code := 0;
    p_err_desc := NULL;
    IF p_entity = 'NEW' AND g_sw_hw = 'HW' THEN
      SELECT v.after_upgrade_item,
             v.after_upgrade_hasp,
             v.sw_version
      INTO   x_after_upgrade_item,
             x_after_upgrade_hasp,
             x_from_sw_version
      FROM   xxcs_sales_ug_items_v v
      WHERE  v.upgrade_item_id = p_upgrade_item_id -- 633005  -- <p_instance_rec.upgrade_kit the upgrade item (new item)>
      AND    v.before_upgrade_item =
             nvl(p_before_upgrade_item, v.before_upgrade_item) -- 104028  -- <item that connect to old instance before upgrade>
      AND    v.after_upgrade_item =
             nvl(p_before_upgrade_hasp, v.after_upgrade_item); -- 144012  -- <Item that connect to hasp before upgrade>
    ELSE

      SELECT v.after_upgrade_item,
             v.after_upgrade_hasp,
             v.sw_version
      INTO   x_after_upgrade_item,
             x_after_upgrade_hasp,
             x_from_sw_version
      FROM   xxcs_sales_ug_items_v v
      WHERE  v.upgrade_item_id = p_upgrade_item_id -- 633005  -- <p_instance_rec.upgrade_kit the upgrade item (new item)>
      AND    v.before_upgrade_item =
             nvl(p_before_upgrade_item, v.before_upgrade_item) -- 104028  -- <item that connect to old instance before upgrade>
      AND    (v.before_upgrade_hasp =
            nvl(p_before_upgrade_hasp, v.before_upgrade_hasp)); -- 144012  -- <Item that connect to hasp before upgrade>
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_after_upgrade_item := NULL;
      x_after_upgrade_hasp := NULL;
      x_from_sw_version    := NULL;
      p_err_code           := 1;
      p_err_desc           := 'Err - * Get Inventory Item id details ' ||
                              substr(SQLERRM, 1, 240);

  END get_sales_ug_items_details;

  --------------------------------------------------------------------
  -- name:            get_SW_HASP_exist
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   25/05/2011 2:57:40 PM
  --------------------------------------------------------------------
  -- purpose :        Get detail of the HASP item that is now connect to
  --                  the printer (before upgrade)
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  25/05/2011  Dalit A. Raviv   initial build
  -- 1.1  15/03/2015  Adi Safin        CHG0034735 - change source table
  --                                   from csi_item_instances to xxsf_csi_item_instances
  -- 1.2  16/07/2015  Michal Tzvik     CHG0035439 - change source table from xxsf_csi_item_instances to csi_item_instances
  --------------------------------------------------------------------
  PROCEDURE get_sw_hasp_exist(p_old_instance_id        IN NUMBER,
                              p_hasp_instance_id       OUT NUMBER,
                              p_hasp_inventory_item_id OUT NUMBER,
                              p_error_code             OUT VARCHAR2,
                              p_error_desc             OUT VARCHAR2) IS

  BEGIN  
    p_error_code := 0;
    p_error_desc := NULL;

    SELECT child.instance_id,
           child.inventory_item_id
    INTO   p_hasp_instance_id,
           p_hasp_inventory_item_id
    FROM   csi_ii_relationships cir, -- 1.2  16/07/2015  Michal Tzvik
           csi_item_instances   cii, -- 1.2  16/07/2015  Michal Tzvik
           csi_item_instances   child,
           mtl_system_items_b   msib
    WHERE  msib.inventory_item_id = child.inventory_item_id
    AND    msib.organization_id = g_master_organization_id -- 1.2  21/07/2015  Michal Tzvik: replace hard code (91)
    AND    msib.segment1 LIKE 'CMP%'
    AND    msib.description LIKE 'HASP%'
    AND    cir.subject_id = child.instance_id
    AND    cir.active_end_date IS NULL
    AND    cir.object_id = cii.instance_id
    AND    cir.object_id = p_old_instance_id
          --and    cii.serial_number      = p_system_sn
    AND    child.serial_number IS NOT NULL;

  EXCEPTION
    WHEN too_many_rows THEN
      p_hasp_instance_id       := NULL;
      p_hasp_inventory_item_id := NULL;
      p_error_code             := 1;
      p_error_desc             := 'Err get_SW_HASP_exist - System SN Have more then one HASP items relate';
    WHEN no_data_found THEN
      p_hasp_instance_id       := NULL;
      p_hasp_inventory_item_id := NULL;
      p_error_code             := 0;
      p_error_desc             := 'Err get_SW_HASP_exist - System SN Have no HASP items relate';
    WHEN OTHERS THEN
      p_hasp_instance_id       := NULL;
      p_hasp_inventory_item_id := NULL;
      p_error_code             := 1;
      p_error_desc             := 'Err get_SW_HASP_exist - General - ' ||
                                  substr(SQLERRM, 1, 240);

  END get_sw_hasp_exist;

  --------------------------------------------------------------------
  -- name:            get_HASP_after_upgrade
  -- create by:       Dalit A. Raviv
  -- Revision:        1.0
  -- creation date:   25/05/2011 2:57:40 PM
  --------------------------------------------------------------------
  -- purpose :        Get detail of the new HASP item that is upgrade to
  --                  the printer (after upgrade)
  --------------------------------------------------------------------
  -- ver  date        name             desc
  -- 1.0  25/05/2011  Dalit A. Raviv   initial build
  -- 1.1  20/03/2012  Dalit A. Raviv   change logic to support new upgrade logic.
  -- 1.2  24/04/2014  Adi Safin        BUGFIX CHG0032033 - get only BOMs from IPK organization
  -- 1.3  21/07/2015  Michal Tzvik     CHG0035439 - replace hard code (91) with global variable
  --------------------------------------------------------------------
  PROCEDURE get_hasp_after_upgrade(p_upgrade_kit               IN NUMBER,
                                   p_old_instance_item_id      IN NUMBER,
                                   p_old_instance_hasp_item_id IN NUMBER,
                                   p_entity                    IN VARCHAR2 DEFAULT 'DR',
                                   p_new_hasp_item_id          OUT NUMBER,
                                   p_err_code                  OUT VARCHAR2,
                                   p_err_desc                  OUT VARCHAR2) IS

    l_after_upgrade_item NUMBER;
    l_after_upgrade_hasp NUMBER;
    l_from_sw_version    VARCHAR2(150) := NULL;
    l_err_code           VARCHAR2(10) := NULL;
    l_err_desc           VARCHAR2(2500) := NULL;

  BEGIN                                                              
    p_err_code := 0;
    p_err_desc := NULL;
    -- 1.1  20/03/2012  Dalit A. Raviv
    -- 1) look at the BOM of the upgrade kit (item) and bring information from there.
    -- 2) if do not find at BOM look at  xxcs_sales_ug_items_v (lookup - XXCSI_UPGRADE_TYPE)
    --    this lookup handle all logic of upgrade.
    SELECT msib.attribute9 -- inv_item_id of hasp item with -s
    INTO   p_new_hasp_item_id
    FROM   bom_inventory_components_v bic,
           bom_bill_of_materials_v    bbo,
           mtl_system_items_b         msib,
           mtl_system_items_b         msib1,
           mtl_item_revisions_b       mir
    WHERE  bbo.bill_sequence_id = bic.bill_sequence_id
    AND    msib.inventory_item_id = bbo.assembly_item_id
    AND    msib.organization_id = g_master_organization_id -- 1.3  21/07/2015  Michal Tzvik: replace hard code (91)
    AND    msib.segment1 LIKE 'CMP%'           
    AND    msib.description LIKE 'HASP%'
    AND    bic.component_item_id =
           (SELECT msib.inventory_item_id
             FROM   bom_inventory_components_v bic,
                    bom_bill_of_materials_v    bbo,
                    mtl_system_items_b         msib
             WHERE  bbo.bill_sequence_id = bic.bill_sequence_id
             AND    bbo.assembly_item_id = p_upgrade_kit -- <upgrade kit>
             AND    msib.segment1 LIKE 'KEY%'
             AND    msib.inventory_item_id = bic.component_item_id
             AND    msib.organization_id = g_master_organization_id -- 1.3  21/07/2015  Michal Tzvik: replace hard code (91)
             AND    rownum = 1)
    AND    msib1.inventory_item_id = msib.attribute9
    AND    msib1.organization_id = g_master_organization_id -- 1.3  21/07/2015  Michal Tzvik: replace hard code (91)
    AND    msib1.inventory_item_id = mir.inventory_item_id
    AND    msib1.organization_id = mir.organization_id
    AND    bbo.organization_id = 735 -- BUGFIX CHG0032033 24/04/2014 Adi Safin - get only BOMs from IPK organization
    AND    mir.effectivity_date =
           (SELECT MAX(mir1.effectivity_date)
             FROM   mtl_item_revisions_b mir1
             WHERE  mir1.inventory_item_id = mir.inventory_item_id
             AND    mir1.organization_id = mir.organization_id);
  EXCEPTION
    WHEN no_data_found THEN
      -- 1.1  20/03/2012 Dalit A. Raviv
      -- at the new logic there is no hasp connect to the upgrade item.
      get_sales_ug_items_details(p_upgrade_item_id => p_upgrade_kit, -- i n
                                 p_before_upgrade_item => p_old_instance_item_id, -- i n
                                 p_before_upgrade_hasp => p_old_instance_hasp_item_id, -- i n
                                 p_entity => p_entity, -- i v
                                 x_after_upgrade_item => l_after_upgrade_item, -- o n
                                 x_after_upgrade_hasp => l_after_upgrade_hasp, -- o n
                                 x_from_sw_version => l_from_sw_version, -- o v
                                 p_err_code => l_err_code, -- o v
                                 p_err_desc => l_err_desc); -- o v

      p_new_hasp_item_id := l_after_upgrade_hasp;

      IF nvl(l_err_code, 0) = 0 THEN
        NULL;
        /*select msi.inventory_item_id
        into   p_NEW_HASP_item_id
        from   xxcs_sales_ug_items_v       map_tbl,
               mtl_system_items_b          msi,
               mtl_item_revisions_b        mir
        where  1 = 1
        --and    nvl(map_tbl.from_sw_version,'DR') = nvl(l_from_sw,nvl(map_tbl.from_sw_version,'DR'))
        and    map_tbl.before_upgrade_item = p_old_instance_item_id      -- <Parameter>
        and    map_tbl.before_upgrade_hasp = p_old_instance_hasp_item_id -- <Parameter>
        and    map_tbl.upgrade_item_id     = p_upgrade_kit               -- <Parameter>
        and    msi.inventory_item_id       = map_tbl.after_upgrade_hasp
        and    msi.organization_id         = 91                          -- (master organization)
        and    mir.inventory_item_id       = msi.inventory_item_id
        and    mir.organization_id         = msi.organization_id
        and    mir.effectivity_date        = (select max(mir1.effectivity_date)
                                              from   mtl_item_revisions_b   mir1
                                              where  mir1.inventory_item_id = mir.inventory_item_id
                                              and    mir1.organization_id   = mir.organization_id
                                             );*/
      ELSE
        dbms_output.put_line('Err1 - Get Inventory Item id details');
        fnd_file.put_line(fnd_file.log, 'Err1 - Get Inventory Item id details:' ||
                           l_err_desc);
        p_new_hasp_item_id := NULL;
        p_err_code         := 1;
        p_err_desc         := 'Err1 - Get Inventory Item id details';
      END IF;

    WHEN too_many_rows THEN
      p_new_hasp_item_id := NULL;
      p_err_code         := 1;
      p_err_desc         := 'Err3 get_HASP_after_upgrade - Upgrade Kit Have more then one items relate';
    WHEN OTHERS THEN
      p_new_hasp_item_id := NULL;
      p_err_code         := 1;
      p_err_desc         := 'Err3 get_HASP_after_upgrade - General - ' ||
                            substr(SQLERRM, 1, 240);
  END get_hasp_after_upgrade;

  --------------------------------------------------------------------
  --  name:            get_upgrade_type
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   23/05/2011
  --------------------------------------------------------------------
  --  purpose :        function that find upgrade kit according to
  --                   system_sn of the printer from the interface table.
  --  Return:          varchar2 -> HW (Hard ware) or SW (Soft Ware)
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  23/05/2011  Dalit A. Raviv  initial build
  --  1.1  29/01/2012  Dalit A. Raviv  change select
  --  1.2  28/06/2012  Dalit A. Raviv  correct select -
  --                                   support multiple upgrades for the same machine.
  --                                   when printer had past 2 upgrades the select return
  --                                   too_many_rows error because there is 2 or more
  --                                   different orders for it.
  --                                   this correction will bring the last shipment
  --                                   for this machine (1 row).
  --  1.3  22/07/2012  Dalit A. Raviv  add condition
  --  1.4  24/10/2012  Adi Safin       add condition and too_many_rows exception
  --  1.5  15/03/2015  Adi Safin       CHG0034735 - change source table
  --                                   from csi_item_instances to xxsf_csi_item_instances
  --------------------------------------------------------------------
  PROCEDURE get_upgrade_type(p_serial_number   IN VARCHAR2, -- is_HW_SW_upgrade
                             p_upgrade_type    OUT VARCHAR2,
                             p_upgrade_kit     OUT NUMBER,
                             p_old_instance_id OUT NUMBER) IS

    l_upgrade_kit     NUMBER := NULL;
    l_old_instance_id NUMBER := NULL;
    l_upgrade_type    VARCHAR2(20) := NULL;
    l_max_ship_date   DATE := NULL;

  BEGIN  
    IF p_serial_number IS NOT NULL THEN
      BEGIN
        -- Get upgrade kit by serial number
        /*select msib.inventory_item_id upgrade_kit, cii.instance_id old_instance_id,
               max(oola.actual_shipment_date) max_ship_date
        into   l_upgrade_kit, l_old_instance_id, l_max_ship_date
        from   oe_order_lines_all   oola,
               mtl_system_items_b   msib,
               mtl_item_categories  mic,
               wsh_delivery_details wdd,
               xxsf_csi_item_instances   cii
        where  oola.inventory_item_id = msib.inventory_item_id
        and    msib.organization_id   = 91
        and    msib.inventory_item_id = mic.inventory_item_id
        and    mic.organization_id    = 91
        and    mic.category_id        = 36123
        and    mic.category_set_id    = 1100000041
        and    oola.line_id           = wdd.source_line_id
        and    oola.flow_status_code  != 'CANCELLED'
        and    wdd.released_status    = 'C'
        and    oola.attribute1        = cii.instance_id
        and    cii.serial_number      = p_serial_number
        group by msib.inventory_item_id, cii.instance_id;*/
        SELECT DISTINCT u.upgrade_item_id upgrade_kit,
                        cii.instance_id   old_instance_id,
                        --max(oola.actual_shipment_date) max_ship_date
                        oola.actual_shipment_date max_ship_date
        INTO   l_upgrade_kit,
               l_old_instance_id,
               l_max_ship_date
        FROM   oe_order_lines_all    oola,
               wsh_delivery_details  wdd,
               csi_item_instances    cii, -- 1.2  16/07/2015  Michal Tzvik
               xxcs_sales_ug_items_v u
        WHERE  oola.inventory_item_id = u.upgrade_item_id
        AND    oola.line_id = wdd.source_line_id
              --  1.4  24/10/2012  Adi Safin       add condition
        AND    oola.header_id = wdd.source_header_id
              -- end 1.4
        AND    oola.flow_status_code != 'CANCELLED'
        AND    wdd.released_status = 'C'
        AND    oola.attribute1 = cii.instance_id
        AND    cii.serial_number = p_serial_number
        AND    cii.inventory_item_id = u.before_upgrade_item
              -- 1.3  22/07/2012  Dalit A. Raviv
              --and    nvl(u.from_sw_version,0)      = nvl(cii.attribute4,nvl(u.from_sw_version,0))
        AND    nvl(nvl(u.from_sw_version, cii.attribute4), 0) =
               nvl(cii.attribute4, nvl(u.from_sw_version, 0))
              -- 1.2 28/06/2012 Dalit A. Raviv
              --group by u.upgrade_item_id,   cii.instance_id;
        AND    oola.actual_shipment_date =
               (SELECT MAX(oola1.actual_shipment_date)
                 FROM   oe_order_lines_all    oola1,
                        wsh_delivery_details  wdd1,
                        csi_item_instances    cii1, -- 1.2  16/07/2015  Michal Tzvik
                        xxcs_sales_ug_items_v u1
                 WHERE  oola1.inventory_item_id = u1.upgrade_item_id
                 AND    oola1.line_id = wdd1.source_line_id
                 AND    oola1.header_id = wdd1.source_header_id --  1.4  24/10/2012  Adi Safin  add condition
                 AND    oola1.flow_status_code != 'CANCELLED'
                 AND    wdd1.released_status = 'C'
                 AND    oola1.attribute1 = cii1.instance_id
                 AND    cii1.serial_number = p_serial_number
                 AND    cii1.inventory_item_id = u1.before_upgrade_item);
        -- end 1.2 28/06/2012

      EXCEPTION
        --  1.4  24/10/2012  Adi Safin       add condition
        WHEN too_many_rows THEN
          SELECT u.upgrade_item_id         upgrade_kit,
                 cii.instance_id           old_instance_id,
                 oola.actual_shipment_date max_ship_date
          INTO   l_upgrade_kit,
                 l_old_instance_id,
                 l_max_ship_date
          FROM   oe_order_lines_all    oola,
                 wsh_delivery_details  wdd,
                 csi_item_instances    cii, -- 1.2  16/07/2015  Michal Tzvik
                 xxcs_sales_ug_items_v u
          WHERE  oola.inventory_item_id = u.upgrade_item_id
          AND    oola.line_id = wdd.source_line_id
          AND    oola.header_id = wdd.source_header_id
          AND    oola.flow_status_code != 'CANCELLED'
          AND    wdd.released_status = 'C'
          AND    oola.attribute1 = cii.instance_id
          AND    cii.serial_number = p_serial_number
          AND    cii.inventory_item_id = u.before_upgrade_item
          AND    nvl(nvl(u.from_sw_version, cii.attribute4), 0) =
                 nvl(cii.attribute4, nvl(u.from_sw_version, 0))
          AND    oola.actual_shipment_date =
                 (SELECT MAX(oola1.actual_shipment_date)
                   FROM   oe_order_lines_all    oola1,
                          wsh_delivery_details  wdd1,
                          csi_item_instances    cii1, -- 1.2  16/07/2015  Michal Tzvik
                          xxcs_sales_ug_items_v u1
                   WHERE  oola1.inventory_item_id = u1.upgrade_item_id
                   AND    oola1.line_id = wdd1.source_line_id
                   AND    oola1.header_id = wdd1.source_header_id
                   AND    oola1.flow_status_code != 'CANCELLED'
                   AND    wdd1.released_status = 'C'
                   AND    oola1.attribute1 = cii1.instance_id
                   AND    cii1.serial_number = p_serial_number
                   AND    cii1.inventory_item_id = u1.before_upgrade_item)
          AND    rownum = 1;
          -- end 1.4 24/10/2012
        WHEN OTHERS THEN
          p_upgrade_type    := 'ERR1 - Serial number is missing no data found';
          p_old_instance_id := NULL;
          p_upgrade_kit     := NULL;
          RETURN;
      END;
      -- get upgrade type
      BEGIN
        SELECT v.upgrade_type
        INTO   l_upgrade_type
        FROM   xxcs_sales_ug_items_v v
        WHERE  v.upgrade_item_id = l_upgrade_kit
        AND    rownum = 1; -- 04/10/2011 Dalir A. Raviv

        p_upgrade_type    := l_upgrade_type;
        p_upgrade_kit     := l_upgrade_kit;
        p_old_instance_id := l_old_instance_id;

      EXCEPTION
        WHEN OTHERS THEN
          p_upgrade_type    := 'ERR2 - Upgrade Kit is missing at view';
          p_old_instance_id := NULL;
          p_upgrade_kit     := NULL;
          RETURN;
      END;
    ELSE
      p_upgrade_type    := 'ERR3 - Serial number is null';
      p_old_instance_id := NULL;
      p_upgrade_kit     := NULL;
      RETURN;
    END IF;

  END get_upgrade_type;

  --------------------------------------------------------------------
  --  name:            create_item_instance
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/03/2011 10:42:40 AM
  --------------------------------------------------------------------
  --  purpose :        Procedure create item instance
  --                   Get data from old instance and copy all details to
  --                   the new instance with the new item_id.
  --                   Attributes and from item instance will copy to the new
  --                   Extended attributes that relate to old instance will
  --                   relate to the new instance.
  --
  --                   when calling create_item_instance for HASP need to populate param p_instance_rec
  --                   with HASP data
  --                   l_instance_rec.old_instance_id
  --                   l_instance_rec.upgrade_kit
  --                   l_instance_rec.close_date
  --                   p_hasp_item need to get Y value
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/03/2011  Dalit A. Raviv    initial build
  --  1.1  23/05/2011  Dalit A. Raviv    xxcs_sales_ug_items_v view field names changed
  --                                     add case of NEW hasp item -> param p_hasp_item Y, N, NEW
  --  1.2  04/10/2011  Dalit A. Raviv    add modifications according to the new logic of upgrade
  --  1.3  22/03/2012  Dalit A. Raviv    add modifications according to new upgrade logic
  --  1.4  15/03/2015  Adi Safin         CHG0034735 - change source table
  --                                     from csi_item_instances to xxsf_csi_item_instances.
  --                                     Assign NULL to attribute 12,16 when createing the HASP IB
  --  1.5  16/07/2015  Michal Tzvik      CHG0035439 - change source table from xxsf_csi_item_instances to csi_item_instances
  --------------------------------------------------------------------
  PROCEDURE create_item_instance(p_instance_rec    IN t_instance_rec,
                                 p_hasp_item       IN VARCHAR2 DEFAULT 'N',
                                 p_old_instance_id OUT NUMBER,
                                 p_old_item_id     OUT NUMBER,
                                 p_old_serial      OUT VARCHAR2,
                                 p_new_instance_id OUT NUMBER,
                                 p_new_item_id     OUT NUMBER,
                                 p_err_code        OUT VARCHAR2,
                                 p_err_msg         OUT VARCHAR2) IS

    -- get extended attributes from old instance to copy to new instance
    CURSOR ext_attributes_c(p_inctance_id IN NUMBER) IS
      SELECT civ.attribute_id,
             civ.attribute_value,
             code.attribute_code,
             civ.active_start_date,
             code.attribute_level
      FROM   csi_iea_values         civ,
             csi_i_extended_attribs code
      WHERE  civ.instance_id = p_inctance_id
      AND    code.attribute_id = civ.attribute_id
      AND    trunc(SYSDATE) BETWEEN civ.active_start_date AND
             nvl(civ.active_end_date, SYSDATE + 1);

    CURSOR org_ass_c(p_inctance_id IN NUMBER) IS
      SELECT org.*
      FROM   csi_i_org_assignments org
      WHERE  org.instance_id = p_inctance_id
      AND    active_end_date IS NULL;

    CURSOR party_c(p_inctance_id IN NUMBER) IS
      SELECT cip.*
      FROM   csi_i_parties      cip,
             csi_item_instances cii -- 1.5  16/07/2015  Michal Tzvik
      WHERE  cip.instance_id = cii.instance_id
      AND    cip.instance_id = p_inctance_id
      AND    cip.contact_flag = 'N'
      ORDER  BY decode(cip.relationship_type_code, 'OWNER', 1, 2);

    CURSOR account_c(p_inctance_id IN NUMBER) IS
      SELECT cia.*
      FROM   csi_ip_accounts    cia,
             csi_i_parties      cip,
             csi_item_instances cii -- 1.5  16/07/2015  Michal Tzvik
      WHERE  cia.instance_party_id = cip.instance_party_id
      AND    cip.instance_id = p_inctance_id
      AND    cip.instance_id = cii.instance_id
      AND    cia.relationship_type_code = 'OWNER';

    l_csi_item_rec          csi_item_instances%ROWTYPE;
    l_party_ind             NUMBER;
    l_api                   VARCHAR2(5) := 'Y';
    l_new_inventory_item_id NUMBER := NULL;
    l_item_number           VARCHAR2(40) := NULL;
    l_new_item_description  VARCHAR2(240) := NULL;
    l_new_item_revision     VARCHAR2(3) := NULL;
    l_new_instance_id       NUMBER := NULL;
    l_new_instance_party_id NUMBER := NULL;
    l_new_ip_account_id     NUMBER := NULL;

    l_ext_attribute_value_id NUMBER;
    l_ext_attr_ind           NUMBER;
    l_return_status          VARCHAR2(2000) := NULL;
    l_msg_count              NUMBER := NULL;
    l_msg_data               VARCHAR2(2500) := NULL;
    l_msg_index_out          NUMBER := NULL;
    l_init_msg_lst           VARCHAR2(500) := NULL;
    l_validation_level       NUMBER := NULL;

    l_instance_rec         csi_datastructures_pub.instance_rec;
    l_party_tbl            csi_datastructures_pub.party_tbl;
    l_account_tbl          csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl   csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl  csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec              csi_datastructures_pub.transaction_rec;
    l_ext_attrib_values    csi_datastructures_pub.extend_attrib_values_tbl;
    l_attribute_id         NUMBER;
    l_attribute_value      VARCHAR2(240) := NULL;
    l_ext_att_instance_id  NUMBER;
    l_instance_ou_id       NUMBER;

    l_err_code VARCHAR2(100) := 0;
    l_err_msg  VARCHAR2(2500) := NULL;

  BEGIN  
    p_err_code := 0;
    p_err_msg  := NULL;
    dbms_output.put_line('-------------------------------' ||
                         p_instance_rec.old_instance_id);
    fnd_file.put_line(fnd_file.log, '-------------------------------' ||
                       p_instance_rec.old_instance_id);
    -- Initialize variables
    l_api                   := 'Y';
    l_csi_item_rec          := NULL;
    l_new_inventory_item_id := NULL;
    l_new_item_description  := NULL;
    l_new_item_revision     := NULL;
    l_new_instance_id       := NULL;
    l_new_instance_party_id := NULL;
    l_new_ip_account_id     := NULL;
    l_item_number           := NULL;
    l_attribute_id          := NULL;
    l_instance_ou_id        := NULL;

    -- Get Old instance id details
    -- 1.1  23/05/2011  Dalit A. Raviv add case p_hasp_item = 'NEW'
                           
    IF p_hasp_item = 'N' OR p_hasp_item = 'NEW' THEN

      BEGIN
        SELECT cii.*
        INTO   l_csi_item_rec
        FROM   csi_item_instances cii
        WHERE  cii.instance_id = p_instance_rec.old_instance_id;

        IF p_hasp_item = 'NEW' THEN
          IF g_hasp_sn IS NOT NULL THEN
            l_csi_item_rec.serial_number := g_hasp_sn;
          ELSE
            dbms_output.put_line('Err - NEW HASP missing serial number.');
            fnd_file.put_line(fnd_file.log, 'Err - NEW HASP missing serial number. instance id: ' ||
                               p_instance_rec.old_instance_id);
            p_err_code := 1;
            p_err_msg  := 'Err - NEW HASP missing serial number. instance id: ' ||
                          p_instance_rec.old_instance_id;
            l_api      := 'N';
          END IF;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          dbms_output.put_line('Err - Old instance id');
          fnd_file.put_line(fnd_file.log, 'Err - Old instance id: ' ||
                             p_instance_rec.old_instance_id);
          p_err_code := 1;
          p_err_msg  := 'Err - Old instance id: ' ||
                        p_instance_rec.old_instance_id;
          l_api      := 'N';
      END;
    ELSE
      BEGIN
        -- Get old HASP instance is (item HASP) details
        SELECT cii_child.*
        INTO   l_csi_item_rec
        FROM   csi_item_instances    cii,
               csi_ii_relationships  cir,
               csi_item_instances    cii_child,
               csi_instance_statuses cis
        WHERE  cir.object_id = cii.instance_id
        AND    cir.relationship_type_code = 'COMPONENT-OF'
        AND    cir.active_end_date IS NULL
        AND    cii_child.instance_id = cir.subject_id
        AND    cii_child.inventory_item_id IN
               (SELECT msib.inventory_item_id
                 FROM   mtl_system_items_b msib
                 WHERE  msib.description LIKE 'HASP%'
                 AND    msib.segment1 LIKE 'CMP%-S'
                 AND    msib.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91)
                 )
        AND    cii_child.instance_status_id = cis.instance_status_id
        AND    cis.terminated_flag = 'N'
        AND    cii.instance_id = p_instance_rec.old_instance_id; --- old hasp instance

        IF l_csi_item_rec.serial_number <> g_hasp_sn AND
           g_hasp_sn IS NOT NULL THEN
          dbms_output.put_line('Err - Old HASP instance id');
          fnd_file.put_line(fnd_file.log, 'Err - Old HASP instance id: ' ||
                             p_old_instance_id ||
                             ' HASP Serial Number Constraint');
          p_err_code := 1;
          p_err_msg  := 'Err - Old HASP instance id: ' || p_old_instance_id ||
                        ' HASP Serial Number Constraint';
          l_api      := 'N';
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          dbms_output.put_line('Err - Old HASP instance id');
          fnd_file.put_line(fnd_file.log, 'Err - Old HASP instance id: ' ||
                             p_old_instance_id);
          p_err_code := 1;
          p_err_msg  := 'Err - Old HASP instance id: ' || p_old_instance_id;
          l_api      := 'N';
      END;
    END IF; -- item is HASP

    -- Get new Item id details
    IF p_hasp_item = 'N' THEN
      BEGIN
        -- 23/05/2011 1.1 Dalit A. Raviv
        -- 04/10/2011 Dalit A. Raviv add condition by the new upgrade logic
        SELECT msi.inventory_item_id, -- map_tbl.to_printer,  -- new_item_id
               msi.segment1,
               msi.description,
               mir.revision
        INTO   l_new_inventory_item_id,
               l_item_number,
               l_new_item_description,
               l_new_item_revision
        FROM   xxcs_sales_ug_items_v map_tbl,
               mtl_system_items_b    msi,
               mtl_item_revisions_b  mir
        WHERE  map_tbl.upgrade_item_id = p_instance_rec.upgrade_kit -- old item_id
        AND    map_tbl.before_upgrade_item =
               l_csi_item_rec.inventory_item_id -- 04/10/2011 Dalit A. Raviv
              --     23/05/2011 1.1 Dalit A. Raviv
        AND    msi.inventory_item_id = map_tbl.after_upgrade_item -- .to_printer
        AND    msi.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91) --(master organization)
        AND    mir.inventory_item_id = msi.inventory_item_id
        AND    mir.organization_id = msi.organization_id
        AND    mir.effectivity_date =
               (SELECT MAX(mir1.effectivity_date)
                 FROM   mtl_item_revisions_b mir1
                 WHERE  mir1.inventory_item_id = mir.inventory_item_id
                 AND    mir1.organization_id = mir.organization_id);
      EXCEPTION
        WHEN OTHERS THEN
          dbms_output.put_line('Err - New Item id');
          fnd_file.put_line(fnd_file.log, 'Err - New item id');
          p_err_code := 1;
          p_err_msg  := 'Err - New item id';
          l_api      := 'N';
      END;
    ELSIF p_hasp_item = 'Y' THEN
      -- hasp details
      BEGIN
        SELECT msib.attribute9, --inv_item_id of hasp item with -s
               msib1.segment1,
               msib1.description,
               mir.revision
        INTO   l_new_inventory_item_id,
               l_item_number,
               l_new_item_description,
               l_new_item_revision
        FROM   bom_inventory_components_v bic,
               bom_bill_of_materials_v    bbo,
               mtl_system_items_b         msib,
               mtl_system_items_b         msib1,
               mtl_item_revisions_b       mir
        WHERE  bbo.bill_sequence_id = bic.bill_sequence_id
        AND    msib.inventory_item_id = bbo.assembly_item_id
        AND    msib.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91)
        AND    msib.segment1 LIKE 'CMP%'
        AND    msib.description LIKE 'HASP%'
        AND    bic.component_item_id =
               (SELECT msib.inventory_item_id
                 FROM   bom_inventory_components_v bic,
                        bom_bill_of_materials_v    bbo,
                        mtl_system_items_b         msib
                 WHERE  bbo.bill_sequence_id = bic.bill_sequence_id
                 AND    bbo.assembly_item_id = p_instance_rec.upgrade_kit -- <upgrade kit>
                 AND    msib.segment1 LIKE 'KEY%'
                 AND    msib.inventory_item_id = bic.component_item_id
                 AND    msib.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91)
                 )
        AND    msib1.inventory_item_id = msib.attribute9
        AND    msib1.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91)
        AND    msib1.inventory_item_id = mir.inventory_item_id
        AND    msib1.organization_id = mir.organization_id
        AND    mir.effectivity_date =
               (SELECT MAX(mir1.effectivity_date)
                 FROM   mtl_item_revisions_b mir1
                 WHERE  mir1.inventory_item_id = mir.inventory_item_id
                 AND    mir1.organization_id = mir.organization_id);

        dbms_output.put_line('HASP new item id - ' ||
                             l_new_inventory_item_id);
        fnd_file.put_line(fnd_file.log, 'HASP new item id - ' ||
                           l_new_inventory_item_id);

      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
            -- Dalit A. Raviv 06/10/2011
            -- at the new logic there is no hasp connect to the upgrade item.
            SELECT msi.inventory_item_id,
                   msi.segment1,
                   msi.description,
                   mir.revision
            INTO   l_new_inventory_item_id,
                   l_item_number,
                   l_new_item_description,
                   l_new_item_revision
            FROM   xxcs_sales_ug_items_v map_tbl,
                   mtl_system_items_b    msi,
                   mtl_item_revisions_b  mir
            WHERE  nvl(map_tbl.from_sw_version, 'DR') =
                   nvl(g_from_sw, nvl(map_tbl.from_sw_version, 'DR'))
            AND    map_tbl.before_upgrade_item = g_before_upgrade_item
            AND    map_tbl.upgrade_item_id = p_instance_rec.upgrade_kit
            AND    msi.inventory_item_id = map_tbl.after_upgrade_hasp
            AND    msi.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91) -- (master organization)
            AND    mir.inventory_item_id = msi.inventory_item_id
            AND    mir.organization_id = msi.organization_id
            AND    mir.effectivity_date =
                   (SELECT MAX(mir1.effectivity_date)
                     FROM   mtl_item_revisions_b mir1
                     WHERE  mir1.inventory_item_id = mir.inventory_item_id
                     AND    mir1.organization_id = mir.organization_id);
          EXCEPTION
            WHEN OTHERS THEN
              dbms_output.put_line('Err - HASP New Item id');
              fnd_file.put_line(fnd_file.log, 'Err - HASP New item id');
              p_err_code := 1;
              p_err_msg  := 'Err - HASP New item id';
              l_api      := 'N';
          END;
      END;
      -- 1.1  23/05/2011  Dalit A. Raviv add case p_hasp_item = 'NEW'
    ELSIF p_hasp_item = 'NEW' THEN
      --  1.3  22/03/2012  Dalit A. Raviv
      l_err_code := 0;
      l_err_msg  := NULL;      
      get_hasp_after_upgrade(p_upgrade_kit => p_instance_rec.upgrade_kit, -- i n
                             p_old_instance_item_id => g_before_upgrade_item, -- i n
                             p_old_instance_hasp_item_id => l_csi_item_rec.inventory_item_id, -- i n
                             p_entity => 'NEW', p_new_hasp_item_id => l_new_inventory_item_id, -- o n
                             p_err_code => l_err_code, -- o v
                             p_err_desc => l_err_msg); -- o v

      IF l_err_code <> 0 THEN

        dbms_output.put_line('Err - NEW HASP new Item id');
        fnd_file.put_line(fnd_file.log, 'Err - NEW HASP new item id');
        p_err_code := 1;
        p_err_msg  := 'Err - NEW HASP new item id';
        l_api      := 'N';
      ELSE
        BEGIN
          SELECT msi.segment1,
                 msi.description,
                 mir.revision
          INTO   l_item_number,
                 l_new_item_description,
                 l_new_item_revision
          FROM   mtl_system_items_b   msi,
                 mtl_item_revisions_b mir
          WHERE  msi.inventory_item_id = l_new_inventory_item_id -- from procedure
          AND    msi.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91) -- (master organization)
          AND    mir.inventory_item_id = msi.inventory_item_id
          AND    mir.organization_id = msi.organization_id
          AND    mir.effectivity_date =
                 (SELECT MAX(mir1.effectivity_date)
                   FROM   mtl_item_revisions_b mir1
                   WHERE  mir1.inventory_item_id = mir.inventory_item_id
                   AND    mir1.organization_id = mir.organization_id);
        EXCEPTION
          WHEN OTHERS THEN
            dbms_output.put_line('Err6 - Get HASP Inventory Item id details');
            fnd_file.put_line(fnd_file.log, 'Err6 - Get HASP Inventory Item id details. l_new_inventory_item_id:' ||
                               l_new_inventory_item_id);
            p_err_code := 1;
            p_err_msg  := 'Err6 - Get HASP Inventory Item id details';
            l_api      := 'N';
        END;
      END IF;
      -- end 1.3 22/03/2012

    END IF; -- Is item Hasp

    IF l_api = 'Y' THEN
      ------ Get sequences values
      SELECT csi_item_instances_s.nextval
      INTO   l_new_instance_id
      FROM   dual;

      dbms_output.put_line('HASP new instance id - ' || l_new_instance_id);
      fnd_file.put_line(fnd_file.log, 'HASP new instance id - ' ||
                         l_new_instance_id);

      -- Handle return params
      -- 1.1  23/05/2011  Dalit A. Raviv add case p_hasp_item = 'NEW'
      IF p_hasp_item = 'N' THEN
        p_old_instance_id := p_instance_rec.old_instance_id;
        p_old_item_id     := p_instance_rec.upgrade_kit;
        p_old_serial      := l_csi_item_rec.serial_number;
        p_new_instance_id := l_new_instance_id;
        p_new_item_id     := l_new_inventory_item_id;
      ELSIF p_hasp_item = 'Y' THEN
        p_old_instance_id := l_csi_item_rec.instance_id;
        p_old_item_id     := p_instance_rec.upgrade_kit;
        p_old_serial      := l_csi_item_rec.serial_number;
        p_new_instance_id := l_new_instance_id;
        p_new_item_id     := l_new_inventory_item_id;
      ELSIF p_hasp_item = 'NEW' THEN
        p_old_instance_id := NULL;
        p_old_item_id     := NULL;
        p_old_serial      := NULL;
        p_new_instance_id := l_new_instance_id;
        p_new_item_id     := l_new_inventory_item_id;
      END IF; -- is item HASP

      ------ INSTANCE details
      -- 1.1  23/05/2011  Dalit A. Raviv add case p_hasp_item = 'NEW'
      IF p_hasp_item = 'N' OR p_hasp_item = 'NEW' THEN
        l_instance_rec.vld_organization_id := l_csi_item_rec.last_vld_organization_id;
      ELSIF p_hasp_item = 'Y' THEN
        l_instance_rec.vld_organization_id := g_parent_organization_id;
      ELSE
        NULL;
      END IF;

      l_instance_rec.instance_id                := l_new_instance_id;
      l_instance_rec.install_date               := l_csi_item_rec.install_date; --
      l_instance_rec.last_wip_job_id            := l_csi_item_rec.last_wip_job_id; --
      l_instance_rec.sales_unit_price           := l_csi_item_rec.sales_unit_price; --
      l_instance_rec.sales_currency_code        := l_csi_item_rec.sales_currency_code; --
      l_instance_rec.instance_number            := l_new_instance_id;
      l_instance_rec.external_reference         := l_csi_item_rec.external_reference;
      l_instance_rec.inventory_item_id          := l_new_inventory_item_id;
      l_instance_rec.inv_master_organization_id := g_master_organization_id;
      l_instance_rec.serial_number              := l_csi_item_rec.serial_number;
      l_instance_rec.inventory_revision         := l_new_item_revision;
      l_instance_rec.quantity                   := l_csi_item_rec.quantity;
      l_instance_rec.unit_of_measure            := l_csi_item_rec.unit_of_measure;
      l_instance_rec.accounting_class_code      := l_csi_item_rec.accounting_class_code;
      l_instance_rec.instance_condition_id      := l_csi_item_rec.instance_condition_id;
      l_instance_rec.instance_status_id         := l_csi_item_rec.instance_status_id;
      l_instance_rec.last_oe_order_line_id      := l_csi_item_rec.last_oe_order_line_id;
      l_instance_rec.customer_view_flag         := l_csi_item_rec.customer_view_flag;
      l_instance_rec.merchant_view_flag         := l_csi_item_rec.merchant_view_flag;
      l_instance_rec.sellable_flag              := l_csi_item_rec.sellable_flag;
      l_instance_rec.system_id                  := l_csi_item_rec.system_id;
      l_instance_rec.instance_type_code         := l_csi_item_rec.instance_type_code;
      l_instance_rec.active_start_date          := SYSDATE;
      l_instance_rec.active_end_date            := NULL;
      l_instance_rec.location_type_code         := l_csi_item_rec.location_type_code; --'HZ_PARTY_SITES';
      l_instance_rec.location_id                := l_csi_item_rec.location_id;
      l_instance_rec.manually_created_flag      := l_csi_item_rec.manually_created_flag;
      l_instance_rec.creation_complete_flag     := l_csi_item_rec.creation_complete_flag;
      l_instance_rec.install_location_type_code := l_csi_item_rec.install_location_type_code;
      l_instance_rec.install_location_id        := l_csi_item_rec.install_location_id;
      l_instance_rec.context                    := l_csi_item_rec.context;
      l_instance_rec.call_contracts             := fnd_api.g_true;
      l_instance_rec.grp_call_contracts         := fnd_api.g_true;
      l_instance_rec.attribute1                 := l_csi_item_rec.attribute1;
      l_instance_rec.attribute2                 := l_csi_item_rec.attribute2;
      l_instance_rec.attribute3                 := l_csi_item_rec.attribute3;
      l_instance_rec.attribute4                 := l_csi_item_rec.attribute4;
      l_instance_rec.attribute5                 := l_csi_item_rec.attribute5;
      l_instance_rec.attribute6                 := l_csi_item_rec.attribute6;
      l_instance_rec.attribute7                 := l_csi_item_rec.attribute7;
      l_instance_rec.attribute8                 := l_csi_item_rec.attribute8;
      l_instance_rec.attribute9                 := l_csi_item_rec.attribute9;
      l_instance_rec.attribute10                := l_csi_item_rec.attribute10;
      l_instance_rec.attribute11                := l_csi_item_rec.attribute11;
      l_instance_rec.attribute12                := NULL; --  2.1  15/03/2015  Adi Safin         CHG0034735
      l_instance_rec.attribute13                := l_csi_item_rec.attribute13;
      l_instance_rec.attribute14                := l_csi_item_rec.attribute14;
      l_instance_rec.attribute15                := l_csi_item_rec.attribute15;
      l_instance_rec.attribute16                := NULL; --  2.1  15/03/2015  Adi Safin         CHG0034735
      l_instance_rec.attribute17                := l_csi_item_rec.attribute17;
      l_instance_rec.attribute18                := l_csi_item_rec.attribute18;
      l_instance_rec.attribute19                := l_csi_item_rec.attribute19;
      l_instance_rec.attribute20                := l_csi_item_rec.attribute20;
      l_instance_rec.attribute21                := l_csi_item_rec.attribute21;
      l_instance_rec.attribute22                := l_csi_item_rec.attribute22;
      l_instance_rec.attribute23                := l_csi_item_rec.attribute23;
      l_instance_rec.attribute24                := l_csi_item_rec.attribute24;
      l_instance_rec.attribute25                := l_csi_item_rec.attribute25;
      l_instance_rec.attribute26                := l_csi_item_rec.attribute26;
      l_instance_rec.attribute27                := l_csi_item_rec.attribute27;
      l_instance_rec.attribute28                := l_csi_item_rec.attribute28;
      l_instance_rec.attribute29                := l_csi_item_rec.attribute29;
      l_instance_rec.attribute30                := l_csi_item_rec.attribute30;

      ------ PARTY Details
      l_party_ind := 0;
      --l_contact_ip_id := null;
      FOR party_r IN party_c(l_csi_item_rec.instance_id) LOOP
        SELECT csi_i_parties_s.nextval
        INTO   l_new_instance_party_id
        FROM   dual;

        l_party_ind := l_party_ind + 1;

        l_party_tbl(l_party_ind).instance_party_id := l_new_instance_party_id; --l_party_acct_rec.instance_party_id;--
        l_party_tbl(l_party_ind).instance_id := l_new_instance_id;
        l_party_tbl(l_party_ind).party_source_table := party_r.party_source_table; --'HZ_PARTIES';
        l_party_tbl(l_party_ind).party_id := party_r.party_id; --l_csi_item_rec.owner_party_id;/*party_r.party_id;*/
        l_party_tbl(l_party_ind).relationship_type_code := party_r.relationship_type_code; --'OWNER';

        l_party_tbl(l_party_ind).active_start_date := SYSDATE;
        l_party_tbl(l_party_ind).active_end_date := NULL;
        l_party_tbl(l_party_ind).object_version_number := 1;
        l_party_tbl(l_party_ind).primary_flag := party_r.primary_flag;
        l_party_tbl(l_party_ind).preferred_flag := party_r.preferred_flag;
        l_party_tbl(l_party_ind).call_contracts := fnd_api.g_true;

        l_party_tbl(l_party_ind).contact_flag := 'N';
        l_party_tbl(l_party_ind).contact_ip_id := NULL; --party_r.contact_ip_id;

      END LOOP; -- external_attributes

      ------ ACCOUNTS Details
      l_party_ind := 0;
      FOR account_r IN account_c(l_csi_item_rec.instance_id) LOOP
        SELECT csi_ip_accounts_s.nextval
        INTO   l_new_ip_account_id
        FROM   dual;

        l_party_ind := l_party_ind + 1;

        l_account_tbl(l_party_ind).ip_account_id := l_new_ip_account_id; --l_party_acct_rec.ip_account_id;
        l_account_tbl(l_party_ind).parent_tbl_index := 1;
        l_account_tbl(l_party_ind).instance_party_id := l_new_instance_party_id; --l_party_acct_rec.instance_party_id;
        l_account_tbl(l_party_ind).party_account_id := account_r.party_account_id;
        l_account_tbl(l_party_ind).relationship_type_code := account_r.relationship_type_code; --'OWNER';
        l_account_tbl(l_party_ind).bill_to_address := account_r.bill_to_address;
        l_account_tbl(l_party_ind).ship_to_address := account_r.ship_to_address;
        l_account_tbl(l_party_ind).active_start_date := SYSDATE;
        l_account_tbl(l_party_ind).active_end_date := NULL;
        l_account_tbl(l_party_ind).object_version_number := 1;
        l_account_tbl(l_party_ind).call_contracts := fnd_api.g_true;
        l_account_tbl(l_party_ind).grp_call_contracts := fnd_api.g_true;
        l_account_tbl(l_party_ind).vld_organization_id := l_csi_item_rec.last_vld_organization_id;

      END LOOP; -- external_attributes

      ------ TXN Details
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
      ------ External Attributes Details
      l_ext_attrib_values.delete;
      l_ext_attr_ind        := 0;
      l_ext_att_instance_id := NULL;
      l_attribute_id        := NULL;
      --
      -- 1.1  23/05/2011  Dalit A. Raviv add case p_hasp_item = 'NEW'
      IF p_hasp_item = 'N' OR p_hasp_item = 'NEW' THEN
        l_ext_att_instance_id := p_instance_rec.old_instance_id;
      ELSE
        l_ext_att_instance_id := l_csi_item_rec.instance_id;
      END IF;

      IF p_hasp_item IN ('N', 'Y') THEN
        FOR ext_attributes_r IN ext_attributes_c(l_ext_att_instance_id) LOOP
          -- to send hasp new_instance id
          SELECT csi_iea_values_s.nextval
          INTO   l_ext_attribute_value_id
          FROM   dual;

          l_ext_attr_ind := l_ext_attr_ind + 1;

          IF ext_attributes_r.attribute_level = 'ITEM' THEN
            --l_new_inventory_item_id
            BEGIN
              SELECT code.attribute_id
              INTO   l_attribute_id
              FROM   csi_i_extended_attribs code
              WHERE  code.attribute_code = ext_attributes_r.attribute_code
              AND    code.inventory_item_id = l_new_inventory_item_id;
            EXCEPTION
              WHEN OTHERS THEN
                l_attribute_id := NULL;
            END;
          ELSIF ext_attributes_r.attribute_level = 'CATEGORY' THEN
            --
            BEGIN
              SELECT code.attribute_id
              INTO   l_attribute_id
              FROM   csi_i_extended_attribs code,
                     mtl_item_categories_v  cat
              WHERE  attribute_level = 'CATEGORY'
              AND    code.attribute_code = ext_attributes_r.attribute_code
              AND    code.item_category_id = cat.category_id
              AND    cat.category_set_id = 1100000041 -- Main Category Set
              AND    cat.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91)
              AND    cat.inventory_item_id = l_new_inventory_item_id;
            EXCEPTION
              WHEN OTHERS THEN
                l_attribute_id := NULL;
            END;
          ELSE
            l_attribute_id := ext_attributes_r.attribute_id;
          END IF;
          IF l_attribute_id IS NOT NULL THEN
            l_ext_attrib_values(l_ext_attr_ind).attribute_value_id := l_ext_attribute_value_id;
            l_ext_attrib_values(l_ext_attr_ind).instance_id := l_new_instance_id;
            l_ext_attrib_values(l_ext_attr_ind).attribute_id := l_attribute_id;
            l_ext_attrib_values(l_ext_attr_ind).attribute_code := ext_attributes_r.attribute_code;
            l_ext_attrib_values(l_ext_attr_ind).attribute_value := ext_attributes_r.attribute_value;
            l_ext_attrib_values(l_ext_attr_ind).active_start_date := SYSDATE;
          END IF;
        END LOOP; -- external_attributes
        -- 1.1  23/05/2011  Dalit A. Raviv add case p_hasp_item = 'NEW'
        -- handle NEW HASP ext attributes
      ELSE
        --Ext attribute1:
        BEGIN
          SELECT cie.attribute_id
          INTO   l_attribute_id
          FROM   csi_i_extended_attribs cie
          WHERE  cie.attribute_code = 'OBJ_HASP_EXP'
          AND    cie.inventory_item_id = l_new_inventory_item_id; --&inv_item_id of the new hasp
        EXCEPTION
          WHEN OTHERS THEN
            l_attribute_id := NULL;
            fnd_file.put_line(fnd_file.log, 'Err - create NEW HASP ext attributes - failed find attribute id1');
        END;

        IF l_attribute_id IS NOT NULL THEN
          l_ext_attrib_values(1).attribute_value_id := l_ext_attribute_value_id;
          l_ext_attrib_values(1).instance_id := l_new_instance_id;
          l_ext_attrib_values(1).attribute_id := l_attribute_id;
          l_ext_attrib_values(1).attribute_code := 'OBJ_HASP_EXP';
          l_ext_attrib_values(1).attribute_value := 'Forever';
          l_ext_attrib_values(1).active_start_date := SYSDATE;
        END IF;

        --Ext attribute2:
        l_attribute_id := NULL;
        BEGIN
          SELECT cie.attribute_id
          INTO   l_attribute_id
          FROM   csi_i_extended_attribs cie
          WHERE  cie.attribute_code = 'OBJ_HASP_SV'
          AND    cie.inventory_item_id = l_new_inventory_item_id; -- &inv_item_id of the new hasp
        EXCEPTION
          WHEN OTHERS THEN
            l_attribute_id := NULL;
            fnd_file.put_line(fnd_file.log, 'Err - create NEW HASP ext attributes - failed find attribute id2');
        END;

        l_attribute_value := NULL;

        IF l_attribute_id IS NOT NULL THEN
          BEGIN
            --attribute_value:
            -- Dalit A. Raviv 04/10/2011
            -- ???????  l_csi_item_rec will take attribute4 of the HASP is this correct???????
            SELECT v.sw_version
            INTO   l_attribute_value
            FROM   xxcs_sales_ug_items_v v
            WHERE  v.upgrade_item_id = p_instance_rec.upgrade_kit --&Upgrade inv_item_id
            AND    nvl(v.from_sw_version, 'DR') =
                   nvl(g_from_sw, nvl(v.from_sw_version, 'DR'))
            AND    v.before_upgrade_item = g_before_upgrade_item; -- Dalit A. Raviv 04/10/2011

          EXCEPTION
            WHEN OTHERS THEN
              l_attribute_value := NULL;
              fnd_file.put_line(fnd_file.log, 'Err - create NEW HASP ext attributes - failed find attribute value');
          END;
          l_ext_attrib_values(2).attribute_value_id := l_ext_attribute_value_id;
          l_ext_attrib_values(2).instance_id := l_new_instance_id;
          l_ext_attrib_values(2).attribute_id := l_attribute_id;
          l_ext_attrib_values(2).attribute_code := 'OBJ_HASP_SV';
          l_ext_attrib_values(2).attribute_value := l_attribute_value;
          l_ext_attrib_values(2).active_start_date := SYSDATE;
        END IF;

      END IF; -- hasp y/n
    END IF;
    -- Org assignment
    l_ext_attr_ind := 0;
    -- this part need only for upgade instance (not for HASP)
    IF p_hasp_item = 'N' THEN
      FOR org_ass_r IN org_ass_c(p_instance_rec.old_instance_id) LOOP
        SELECT csi_i_org_assignments_s.nextval
        INTO   l_instance_ou_id
        FROM   dual;

        l_ext_attr_ind := l_ext_attr_ind + 1;
        l_org_assignments_tbl(l_ext_attr_ind).instance_ou_id := l_instance_ou_id;
        l_org_assignments_tbl(l_ext_attr_ind).instance_id := l_new_instance_id;
        l_org_assignments_tbl(l_ext_attr_ind).operating_unit_id := org_ass_r.operating_unit_id;
        l_org_assignments_tbl(l_ext_attr_ind).relationship_type_code := org_ass_r.relationship_type_code;
        l_org_assignments_tbl(l_ext_attr_ind).active_start_date := SYSDATE;

      END LOOP;
    END IF;
    --
    ------ CALL API
    IF l_api = 'Y' THEN
      l_msg_data     := NULL;
      l_init_msg_lst := NULL;
      fnd_msg_pub.initialize;
      --Create The Instance
      csi_item_instance_pub.create_item_instance(p_api_version => 1, p_commit => fnd_api.g_false, p_init_msg_list => l_init_msg_lst, p_validation_level => l_validation_level, p_instance_rec => l_instance_rec, p_ext_attrib_values_tbl => l_ext_attrib_values, p_party_tbl => l_party_tbl, p_account_tbl => l_account_tbl, p_pricing_attrib_tbl => l_pricing_attrib_tbl, p_org_assignments_tbl => l_org_assignments_tbl, p_asset_assignment_tbl => l_asset_assignment_tbl, p_txn_rec => l_txn_rec, x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data);

      IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
        fnd_msg_pub.get(p_msg_index => -1, p_encoded => 'F', p_data => l_msg_data, p_msg_index_out => l_msg_index_out);

        IF p_hasp_item = 'N' THEN
          dbms_output.put_line('Err - create instance - Component: ' ||
                               l_item_number || ' : ' ||
                               substr(l_msg_data, 1, 240));
          fnd_file.put_line(fnd_file.log, 'Err - create instance - Component: ' ||
                             l_item_number || ' : ' ||
                             l_msg_data);

          p_err_code := 1;
          p_err_msg  := 'Err - create instance - Component: ' ||
                        l_item_number || ' : ' ||
                        substr(l_msg_data, 1, 240);
        ELSIF p_hasp_item = 'Y' THEN
          dbms_output.put_line('Err - create HASP instance - Component: ' ||
                               l_item_number || ' : ' ||
                               substr(l_msg_data, 1, 240));
          fnd_file.put_line(fnd_file.log, 'Err - create HASP instance - Component: ' ||
                             l_item_number || ' : ' ||
                             l_msg_data);

          p_err_code := 1;
          p_err_msg  := 'Err - create HASP instance - Component: ' ||
                        l_item_number || ' : ' ||
                        substr(l_msg_data, 1, 240);
        ELSIF p_hasp_item = 'NEW' THEN
          dbms_output.put_line('Err - create NEW HASP instance - Component: ' ||
                               l_item_number || ' : ' ||
                               substr(l_msg_data, 1, 240));
          fnd_file.put_line(fnd_file.log, 'Err - create NEW HASP instance - Component: ' ||
                             l_item_number || ' : ' ||
                             l_msg_data);

          p_err_code := 1;
          p_err_msg  := 'Err - create NEW HASP instance - Component: ' ||
                        l_item_number || ' : ' ||
                        substr(l_msg_data, 1, 240);
        END IF; -- is item HASP
      ELSE
        p_err_code := 0;
        p_err_msg  := NULL;
      END IF;

    END IF; -- api = Y
  EXCEPTION
    WHEN OTHERS THEN
      IF p_hasp_item = 'N' THEN
        p_err_code := 1;
        p_err_msg  := 'GEN EXC - create_item_instance - ' ||
                      substr(SQLERRM, 1, 240);
      ELSIF p_hasp_item = 'Y' THEN
        p_err_code := 1;
        p_err_msg  := 'GEN EXC - create_item_instance HASP - ' ||
                      substr(SQLERRM, 1, 240);
      ELSIF p_hasp_item = 'NEW' THEN
        p_err_code := 1;
        p_err_msg  := 'GEN EXC - create_item_instance NEW HASP - ' ||
                      substr(SQLERRM, 1, 240);
      END IF;
  END create_item_instance;

  --------------------------------------------------------------------
  --  name:            update_item_instance
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/03/2011 10:42:40 AM
  --------------------------------------------------------------------
  --  purpose :        Procedure update item instance
  --                   For association of the instance we need to do it by update.
  --
  --  In param:        p_old_instance_id
  --                   p_new_instance_id
  --  Out Param:       p_err_code
  --                   p_err_msg
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/03/2011  Dalit A. Raviv    initial build
  --  1.1  06/08/2012  Dalit A. raviv    add handle of update embeded_sw_version to attribute4
  --  1.2  15/03/2015  Adi Safin         CHG0034735 - change source table
  --                                     from csi_item_instances to xxsf_csi_item_instances
  --  1.3  16/07/2015  Michal Tzvik      CHG0035439 - change source table from xxsf_csi_item_instances to csi_item_instances
  --------------------------------------------------------------------
  PROCEDURE update_item_instance(p_old_instance_id  IN NUMBER,
                                 p_new_instance_id  IN NUMBER,
                                 p_hasp_instance_id IN NUMBER,
                                 p_new_hasp_item_id IN NUMBER,
                                 p_upgrade_kit      IN NUMBER,
                                 p_sw_hw            IN VARCHAR2,
                                 p_err_code         OUT VARCHAR2,
                                 p_err_msg          OUT VARCHAR2) IS

    CURSOR party_c(p_inctance_id IN NUMBER) IS
      SELECT cip.*
      FROM   csi_i_parties      cip,
             csi_item_instances cii --1.3  16/07/2015  Michal Tzvik
      WHERE  cip.instance_id = cii.instance_id
      AND    cip.instance_id = p_inctance_id
      AND    cip.contact_flag = 'Y'
      AND    cip.active_end_date IS NULL
      AND    cip.relationship_type_code NOT IN ('OWNER', 'SOLD_TO');

    l_instance_rec          csi_datastructures_pub.instance_rec;
    l_ext_attrib_values_tbl csi_datastructures_pub.extend_attrib_values_tbl;
    l_party_tbl             csi_datastructures_pub.party_tbl;
    l_account_tbl           csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl    csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl   csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl  csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec               csi_datastructures_pub.transaction_rec;
    l_instance_id_lst       csi_datastructures_pub.id_tbl;
    l_return_status         VARCHAR2(2000);
    l_msg_count             NUMBER;
    l_msg_data              VARCHAR2(2000);
    l_msg_index_out         NUMBER;

    l_attribute_id           NUMBER;
    l_attribute_value        VARCHAR2(240) := NULL;
    l_ext_attribute_value_id NUMBER := NULL;
    l_ovn                    NUMBER := NULL;

    l_instance_party_id NUMBER;
    l_party_ind         NUMBER;
    -- 1.1 06/08/2012 Dalit A. Raviv
    l_new_item_number VARCHAR2(150) := NULL;
    l_embedded_sw_ver VARCHAR2(150) := NULL;
    l_sw_flag         VARCHAR2(5) := 'N';
    l_err_code2       VARCHAR2(100) := 0;
    l_err_msg2        VARCHAR2(1000) := NULL;
    l_ovn1            NUMBER;

  BEGIN  
    IF p_sw_hw = 'HW' THEN
      l_party_ind := 0;

      BEGIN
        SELECT cip.instance_party_id
        INTO   l_instance_party_id
        FROM   csi_i_parties      cip,
               csi_item_instances cii --1.3  16/07/2015  Michal Tzvik
        WHERE  cip.instance_id = cii.instance_id
        AND    cip.instance_id = p_new_instance_id
        AND    cip.relationship_type_code = ('OWNER');
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      FOR party_r IN party_c(p_old_instance_id) LOOP
        -- old instance
        l_party_ind := l_party_ind + 1;

        l_party_tbl(l_party_ind).instance_party_id := NULL; -- new instance
        l_party_tbl(l_party_ind).instance_id := p_new_instance_id; -- pass the instance_id created from (1)
        l_party_tbl(l_party_ind).party_source_table := party_r.party_source_table;
        l_party_tbl(l_party_ind).party_id := party_r.party_id; -- pass the employee number
        l_party_tbl(l_party_ind).relationship_type_code := party_r.relationship_type_code;
        l_party_tbl(l_party_ind).contact_flag := 'Y'; -- pass it as 'Y' since this is a contact
        l_party_tbl(l_party_ind).contact_ip_id := l_instance_party_id; -- pass the instance_party_id of the party for
        -- which you are going to create the contact.
        l_party_tbl(l_party_ind).primary_flag := party_r.primary_flag;
        l_party_tbl(l_party_ind).preferred_flag := party_r.preferred_flag;
      END LOOP;
      -- 1.2 06/08/2012 Dalit A. Raviv  add if case
    ELSIF p_sw_hw = 'EMB_SW_VER' THEN
      -----------------------------------------------------------
      -- 1.2 06/08/2012 Dalit A. Raviv
      BEGIN
        SELECT msi.segment1
        INTO   l_new_item_number
        FROM   mtl_system_items_b msi
        WHERE  msi.organization_id = g_master_organization_id -- 1.3  21/07/2015  Michal Tzvik: replace hard code (91)
        AND    msi.inventory_item_id = p_upgrade_kit;
      EXCEPTION
        WHEN OTHERS THEN
          l_new_item_number := NULL;
      END;
      BEGIN
        SELECT cii.object_version_number
        INTO   l_ovn1
        FROM   csi_item_instances cii
        WHERE  cii.instance_id = p_old_instance_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_ovn1 := NULL;
      END;

      get_embedded_sw_version(p_old_inventory_item_id => g_before_upgrade_item, -- i n
                              p_upgrade_kit_desc => l_new_item_number, -- i v
                              p_hasp_item_id => NULL, -- i n
                              p_old_embeded_sw_ver => NULL, -- i v
                              p_embedded_sw_ver => l_embedded_sw_ver, -- o v
                              p_err_code => l_err_code2, -- o v
                              p_err_desc => l_err_msg2); -- o v
      IF l_err_code2 = 0 THEN
        l_instance_rec.attribute4            := l_embedded_sw_ver;
        l_instance_rec.instance_id           := p_old_instance_id;
        l_instance_rec.object_version_number := l_ovn1;
      ELSE
        l_sw_flag := 'Y';
      END IF;

      -- end 1.2 06/08/2012
      -----------------------------------------------------------

    ELSE
      --Ext attribute2:
      l_attribute_id := NULL;
      BEGIN
        SELECT cie.attribute_id
        INTO   l_attribute_id
        FROM   csi_i_extended_attribs cie
        WHERE  cie.attribute_code = 'OBJ_HASP_SV'
        AND    cie.inventory_item_id = p_new_hasp_item_id; -- &inv_item_id of the new hasp
      EXCEPTION
        WHEN OTHERS THEN
          l_attribute_id := NULL;
          fnd_file.put_line(fnd_file.log, 'ERR5 - create NEW HASP ext attributes - failed find attribute id2');
      END;

      l_attribute_value := NULL;

      IF l_attribute_id IS NOT NULL THEN
        BEGIN
          -- attribute_value:
          SELECT v.sw_version
          INTO   l_attribute_value
          FROM   xxcs_sales_ug_items_v v
          WHERE  v.upgrade_item_id = p_upgrade_kit;
        EXCEPTION
          WHEN OTHERS THEN
            l_attribute_value := NULL;
            fnd_file.put_line(fnd_file.log, 'ERR6 - create NEW HASP ext attributes - failed find attribute value');
        END;

        BEGIN
          -- case extended attribute exists
          SELECT cia.attribute_value_id,
                 cia.object_version_number
          INTO   l_ext_attribute_value_id,
                 l_ovn
          FROM   csi_iea_values cia
          WHERE  cia.instance_id = p_hasp_instance_id --3440000
          AND    cia.attribute_id = l_attribute_id; --15007

          l_ext_attrib_values_tbl(1).object_version_number := l_ovn;
        EXCEPTION
          WHEN OTHERS THEN
            -- case no extended attribute exists
            SELECT csi_iea_values_s.nextval
            INTO   l_ext_attribute_value_id
            FROM   dual;

            l_ext_attrib_values_tbl(1).active_start_date := SYSDATE;
        END;

        l_ext_attrib_values_tbl(1).attribute_value_id := l_ext_attribute_value_id;
        l_ext_attrib_values_tbl(1).instance_id := p_hasp_instance_id;
        l_ext_attrib_values_tbl(1).attribute_id := l_attribute_id;
        l_ext_attrib_values_tbl(1).attribute_code := 'OBJ_HASP_SV';
        l_ext_attrib_values_tbl(1).attribute_value := l_attribute_value;

      END IF;

      -----------------------------------------------------------
      -- 1.2 06/08/2012 Dalit A. Raviv
      BEGIN
        SELECT msi.segment1
        INTO   l_new_item_number
        FROM   mtl_system_items_b msi
        WHERE  msi.organization_id = g_master_organization_id -- 1.3  21/07/2015  Michal Tzvik: replace hard code (91)
        AND    msi.inventory_item_id = p_upgrade_kit;
      EXCEPTION
        WHEN OTHERS THEN
          l_new_item_number := NULL;
      END;
      BEGIN
        SELECT cii.object_version_number
        INTO   l_ovn1
        FROM   csi_item_instances cii
        WHERE  cii.instance_id = p_old_instance_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_ovn1 := NULL;
      END;

      get_embedded_sw_version(p_old_inventory_item_id => g_before_upgrade_item, -- i n
                              p_upgrade_kit_desc => l_new_item_number, -- i v
                              p_hasp_item_id => NULL, -- i n
                              p_old_embeded_sw_ver => NULL, -- i v
                              p_embedded_sw_ver => l_embedded_sw_ver, -- o v
                              p_err_code => l_err_code2, -- o v
                              p_err_desc => l_err_msg2); -- o v
      IF l_err_code2 = 0 THEN
        l_instance_rec.attribute4            := l_embedded_sw_ver;
        l_instance_rec.instance_id           := p_old_instance_id;
        l_instance_rec.object_version_number := l_ovn1;
      ELSE
        l_sw_flag := 'Y';
      END IF;

      -- end 1.2 06/08/2012
      -----------------------------------------------------------
    END IF; -- p_sw_hw
    l_txn_rec.transaction_id          := NULL;
    l_txn_rec.transaction_date        := SYSDATE;
    l_txn_rec.source_transaction_date := SYSDATE;
    l_txn_rec.transaction_type_id     := 1;

    -- Now call the stored program
    csi_item_instance_pub.update_item_instance(1.0, 'F', 'F', 1, l_instance_rec, l_ext_attrib_values_tbl, l_party_tbl, l_account_tbl, l_pricing_attrib_tbl, l_org_assignments_tbl, l_asset_assignment_tbl, l_txn_rec, l_instance_id_lst, l_return_status, l_msg_count, l_msg_data);

    IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
      fnd_msg_pub.get(p_msg_index => -1, p_encoded => 'F', p_data => l_msg_data, p_msg_index_out => l_msg_index_out);

      dbms_output.put_line('Err - update_item_instance - : ' ||
                           substr(l_msg_data, 1, 240));
      fnd_file.put_line(fnd_file.log, 'Err - update_item_instance - : ' ||
                         l_msg_data);

      p_err_code := 1;
      p_err_msg  := 'Err - update_item_instance - : ' ||
                    substr(l_msg_data, 1, 240);

    ELSE
      p_err_code := 0;
      p_err_msg  := NULL;
    END IF;

    IF l_sw_flag = 'Y' THEN
      p_err_msg := p_err_msg || ' ' || l_err_msg2;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'GEN EXC - update_item_instance - ' ||
                    substr(SQLERRM, 1, 240);

  END update_item_instance;

  --------------------------------------------------------------------
  --  name:            update_item_instance_new
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/07/2011
  --------------------------------------------------------------------
  --  purpose :        handle update of item instance with
  --                   the new inventory item id and revision.
  --  out params:      p_msg_desc  - null success others failrd
  --                   p_msg_code  - 0    success 1 failed
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/07/2011  Dalit A. Raviv    initial build
  --  1.1  04/10/2011  Dalit A. Raviv    add modifications according to the new logic of upgrade
  --  1.2  20/03/2012  Dalit A. Raviv    change logic to support new upgrade logic.
  --  1.3  06/08/2012  Dalit A. Raviv    add support to update Embeded_SW_version for the instance (attribute4)
  --  1.4  15/03/2015  Adi Safin         CHG0034735 - change source table
  --                                     from csi_item_instances to xxsf_csi_item_instances
  --  1.5  16.07.2015  Michal Tzvik      CHG0035439 - change source table from xxsf_csi_item_instances to csi_item_instances
  --------------------------------------------------------------------
  PROCEDURE update_item_instance_new(p_instance_rec       IN t_instance_rec,
                                     p_hasp_item          IN VARCHAR2,
                                     p_hasp_instance_id   OUT NUMBER,
                                     p_inventory_item_id  OUT NUMBER,
                                     p_inventory_revision OUT VARCHAR2,
                                     p_err_code           OUT VARCHAR2,
                                     p_err_msg            OUT VARCHAR2) IS

    -- get extended attributes from old instance to copy to new instance
    CURSOR ext_attributes_c(p_inctance_id IN NUMBER) IS
      SELECT civ.attribute_id,
             civ.attribute_value,
             code.attribute_code,
             civ.active_start_date,
             civ.object_version_number,
             civ.attribute_value_id,
             code.attribute_level
      FROM   csi_iea_values         civ,
             csi_i_extended_attribs code
      WHERE  civ.instance_id = p_inctance_id
      AND    code.attribute_id = civ.attribute_id
      AND    civ.attribute_value IS NOT NULL
      AND    SYSDATE BETWEEN civ.active_start_date AND
             nvl(civ.active_end_date, SYSDATE + 1);

    l_instance_rec          csi_datastructures_pub.instance_rec;
    l_party_tbl             csi_datastructures_pub.party_tbl;
    l_account_tbl           csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl    csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl   csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl  csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec               csi_datastructures_pub.transaction_rec;
    l_ext_attrib_values_tbl csi_datastructures_pub.extend_attrib_values_tbl;
    l_return_status         VARCHAR2(2000) := NULL;
    l_msg_count             NUMBER := NULL;
    l_msg_data              VARCHAR2(2000) := NULL;
    l_msg_index_out         NUMBER;
    l_instance_id_lst       csi_datastructures_pub.id_tbl;
    l_validation_level      NUMBER := NULL;
    l_ovn                   NUMBER := NULL;

    l_attribute_value VARCHAR2(30) := NULL;

    l_csi_item_rec          csi_item_instances%ROWTYPE;
    l_new_inventory_item_id NUMBER := NULL;
    --l_parent_item_id           number         := null;
    l_new_item_number      VARCHAR2(40) := NULL;
    l_new_item_description VARCHAR2(240) := NULL;
    l_new_item_revision    VARCHAR2(3) := NULL;
    l_api                  VARCHAR2(2) := 'Y';

    l_attribute_id        NUMBER;
    l_ext_att_instance_id NUMBER;
    l_ext_attr_ind        NUMBER;

    -- 1.1 04/10/2011 Dalit A. Raviv
    l_before_upgrade_printer NUMBER;
    l_from_sw                VARCHAR2(150);
    l_err_code               VARCHAR2(10);
    l_err_msg                VARCHAR2(2500);

    l_after_upgrade_item NUMBER;
    l_after_upgrade_hasp NUMBER;
    l_old_hasp_item_id   NUMBER;
    -- 1.3 06/08/2012 Dalit A. Raviv
    l_embedded_sw_ver     VARCHAR2(150) := NULL;
    l_studio_sw_ver       VARCHAR2(150) := NULL;--Added on 23 Aug 2016 CHG0037320 - L.Sarangi
    l_err_code2           VARCHAR2(10);
    l_err_msg2            VARCHAR2(2500);
    l_sw_flag             VARCHAR2(5) := 'N';
    l_upd_kit_item_number VARCHAR2(100) := NULL;

  BEGIN    
    dbms_output.put_line('-------------' || p_instance_rec.old_instance_id ||
                         ' HASP - ' || p_hasp_item);
    fnd_file.put_line(fnd_file.log, '-------------' ||
                       p_instance_rec.old_instance_id ||
                       ' HASP - ' || p_hasp_item);

    -- 1) Get Object version number of the old instance
    SELECT --max(cii.object_version_number),
     cii.object_version_number,
     cii.inventory_item_id,
     cii.attribute4
    INTO   l_ovn,
           l_before_upgrade_printer,
           l_from_sw
    FROM   csi_item_instances cii
    WHERE  cii.instance_id = p_instance_rec.old_instance_id; -- 2217001

    -- 2) Get Inventory_item_id details
    -- Case Item instance itself
    -- Dalit A. Raviv 04/10/2011 add condition to look at IB for the before upg printer
    IF p_hasp_item = 'N' THEN
      BEGIN
        -- 22/03/2012 Dalit A. Raviv
        SELECT --cii_child.instance_id old_ii_hasp,
         cii_child.inventory_item_id
        INTO   l_old_hasp_item_id
        FROM   csi_item_instances    cii, --1.3  16/07/2015  Michal Tzvik
               csi_ii_relationships  cir,
               csi_item_instances    cii_child, --1.3  16/07/2015  Michal Tzvik
               csi_instance_statuses cis
        WHERE  cir.object_id = cii.instance_id
        AND    cir.relationship_type_code = 'COMPONENT-OF'
        AND    cir.active_end_date IS NULL
        AND    cii_child.instance_id = cir.subject_id
        AND    cii_child.inventory_item_id IN
               (SELECT msib.inventory_item_id
                 FROM   mtl_system_items_b msib
                 WHERE  msib.description LIKE 'HASP%'
                 AND    msib.segment1 LIKE 'CMP%-S'
                 AND    msib.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91)
                 )
        AND    cii_child.instance_status_id = cis.instance_status_id
        AND    cis.terminated_flag = 'N'
        AND    cii.instance_id = p_instance_rec.old_instance_id; --- old hasp instance
      EXCEPTION
        WHEN OTHERS THEN
          l_old_hasp_item_id := NULL;
          --l_hasp_instance_id := null;
      END;
      BEGIN

        SELECT msi.inventory_item_id,
               msi.segment1,
               msi.description,
               mir.revision
        INTO   l_new_inventory_item_id,
               l_new_item_number,
               l_new_item_description,
               l_new_item_revision
        FROM   xxcs_sales_ug_items_v map_tbl,
               mtl_system_items_b    msi,
               mtl_item_revisions_b  mir
        WHERE  map_tbl.upgrade_item_id = p_instance_rec.upgrade_kit -- old item_id
        AND    map_tbl.before_upgrade_item = g_before_upgrade_item -- g_before_upgrade_printer   -- 04/10/2011 Dalit A. Raviv
        AND    (map_tbl.before_upgrade_hasp IS NULL OR -- 1.5 Michal Tzvik 16.07.2015
              map_tbl.before_upgrade_hasp =
              nvl(to_char(l_old_hasp_item_id), map_tbl.before_upgrade_hasp))
        AND    msi.inventory_item_id = map_tbl.after_upgrade_item -- to_printer
        AND    msi.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91) -- (master organization)
        AND    mir.inventory_item_id = msi.inventory_item_id
        AND    mir.organization_id = msi.organization_id
        AND    mir.effectivity_date =
               (SELECT MAX(mir1.effectivity_date)
                 FROM   mtl_item_revisions_b mir1
                 WHERE  mir1.inventory_item_id = mir.inventory_item_id
                 AND    mir1.organization_id = mir.organization_id);

        dbms_output.put_line('Inventory item id - ' ||
                             l_new_inventory_item_id || ' Rev - ' ||
                             l_new_item_revision);
        fnd_file.put_line(fnd_file.log, 'Inventory item id - ' ||
                           l_new_inventory_item_id ||
                           ' Rev - ' || l_new_item_revision);

      EXCEPTION
        WHEN OTHERS THEN
          dbms_output.put_line('Err - Get Inventory Item id details');
          fnd_file.put_line(fnd_file.log, 'Err - Get Inventory Item id details. p_instance_rec.upgrade_kit=' ||
                             p_instance_rec.upgrade_kit ||
                             ', g_before_upgrade_item=' ||
                             g_before_upgrade_item ||
                             ', l_old_hasp_item_id=' ||
                             l_old_hasp_item_id);
          p_err_code := 1;
          p_err_msg  := 'Err - Get Inventory Item id details';
          l_api      := 'N';
      END;

      BEGIN
        SELECT msi.segment1
        INTO   l_upd_kit_item_number
        FROM   mtl_system_items_b msi
        WHERE  msi.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91)
        AND    msi.inventory_item_id = p_instance_rec.upgrade_kit;

      END;
      -- Case HASP Item
    ELSIF p_hasp_item = 'Y' THEN

      BEGIN
        -- Get old HASP instance is (item HASP) details
        SELECT --cii_child.instance_id old_ii_hasp,
         cii_child.*
        INTO   l_csi_item_rec
        FROM   csi_item_instances    cii,
               csi_ii_relationships  cir,
               csi_item_instances    cii_child,
               csi_instance_statuses cis
        WHERE  cir.object_id = cii.instance_id
        AND    cir.relationship_type_code = 'COMPONENT-OF'
        AND    cir.active_end_date IS NULL
        AND    cii_child.instance_id = cir.subject_id
        AND    cii_child.inventory_item_id IN
               (SELECT msib.inventory_item_id
                 FROM   mtl_system_items_b msib
                 WHERE  msib.description LIKE 'HASP%'
                 AND    msib.segment1 LIKE 'CMP%-S'                         
                 AND    msib.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91)
                 )
        AND    cii_child.instance_status_id = cis.instance_status_id
        AND    cis.terminated_flag = 'N'
        AND    cii.instance_id = p_instance_rec.old_instance_id; --- old hasp instance

        dbms_output.put_line('Old HASP instance id - ' ||
                             l_csi_item_rec.instance_id);
        fnd_file.put_line(fnd_file.log, 'Old HASP instance id - ' ||
                           l_csi_item_rec.instance_id);
      EXCEPTION
        WHEN OTHERS THEN
          dbms_output.put_line('Err - Old HASP instance id');
          fnd_file.put_line(fnd_file.log, 'Err - Old HASP instance id: ');
          p_err_code := 1;
          p_err_msg  := 'Err - Old HASP instance id: ';
          l_api      := 'N';
      END;

      -- 1.2 Dalit A. Raviv
      l_err_code := 0;
      l_err_msg  := NULL;                 
      get_hasp_after_upgrade(p_upgrade_kit => p_instance_rec.upgrade_kit, -- i n
                             p_old_instance_item_id => g_before_upgrade_item, -- i n
                             p_old_instance_hasp_item_id => l_csi_item_rec.inventory_item_id, -- i n
                             p_new_hasp_item_id => l_new_inventory_item_id, -- o n
                             p_err_code => l_err_code, -- o v
                             p_err_desc => l_err_msg); -- o v

      IF l_err_code <> 0 THEN
        dbms_output.put_line('Err5 - Get HASP Inventory Item id details');
        fnd_file.put_line(fnd_file.log, 'Err5 - Get HASP Inventory Item id details');
        p_err_code := 1;
        p_err_msg  := 'Err5 - Get HASP Inventory Item id details';
        l_api      := 'N';
      ELSE
        BEGIN
          SELECT msi.segment1,
                 msi.description,
                 mir.revision
          INTO   l_new_item_number,
                 l_new_item_description,
                 l_new_item_revision
          FROM   mtl_system_items_b   msi,
                 mtl_item_revisions_b mir
          WHERE  msi.inventory_item_id = l_new_inventory_item_id -- from procedure
          AND    msi.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91) -- (master organization)
          AND    mir.inventory_item_id = msi.inventory_item_id
          AND    mir.organization_id = msi.organization_id
          AND    mir.effectivity_date =
                 (SELECT MAX(mir1.effectivity_date)
                   FROM   mtl_item_revisions_b mir1
                   WHERE  mir1.inventory_item_id = mir.inventory_item_id
                   AND    mir1.organization_id = mir.organization_id);
        EXCEPTION
          WHEN OTHERS THEN
            dbms_output.put_line('Err6 - Get HASP Inventory Item id details');
            fnd_file.put_line(fnd_file.log, 'Err6 - Get HASP Inventory Item id details');
            p_err_code := 1;
            p_err_msg  := 'Err6 - Get HASP Inventory Item id details';
            l_api      := 'N';
        END;
      END IF;
      -- end 1.2 20/03/2012
    END IF; -- Is item Hasp

    -- 4) Call Update API
    IF l_api = 'Y' THEN  
      -- get_studio_sw_version Called -Added 23 Aug 2016 L.Sarangi  CHG0037320
      Begin
       get_studio_sw_version(p_old_inventory_item_id => g_before_upgrade_item, -- i n
                              p_upgrade_kit_desc => l_upd_kit_item_number, -- i v
                              p_hasp_item_id => l_old_hasp_item_id, -- i n
                              p_old_studio_sw_ver => null, -- i v
                              p_studio_sw_ver => l_studio_sw_ver, -- o v
                              p_err_code => l_err_code2, -- o v
                              p_err_desc => l_err_msg2);  
       
       IF l_err_code2 = 0 THEN
         l_instance_rec.attribute5 := l_studio_sw_ver;
       End if;  
      Print_message('l_studio_sw_ver :'||l_studio_sw_ver);                            
      Exception
      when Others Then 
         Print_message('get_studio_sw_version Proc Call Error :'||SQLERRM);  
      END;   
      l_err_code2 := Null; --Added 23 Aug 2016 L.Sarangi  CHG0037320
      l_err_msg2  := Null; --Added 23 Aug 2016 L.Sarangi  CHG0037320        
      -- Set Out Param
      IF p_hasp_item = 'N' THEN
        p_hasp_instance_id                   := NULL;
        l_instance_rec.instance_id           := p_instance_rec.old_instance_id; -- 2217001
        l_instance_rec.object_version_number := l_ovn;
        -- 1.3 06/08/2012 Dalit A. Raviv        
        get_embedded_sw_version(p_old_inventory_item_id => g_before_upgrade_item, -- i n
                                p_upgrade_kit_desc => l_upd_kit_item_number, -- i v
                                p_hasp_item_id => l_old_hasp_item_id, -- i n
                                p_old_embeded_sw_ver => g_from_sw, -- i v
                                p_embedded_sw_ver => l_embedded_sw_ver, -- o v
                                p_err_code => l_err_code2, -- o v
                                p_err_desc => l_err_msg2); -- o v
        IF l_err_code2 = 0 THEN
          l_instance_rec.attribute4 := l_embedded_sw_ver;
        ELSE
          l_sw_flag := 'Y';
        END IF;        
        -- end 1.3 06/08/2012
        -- Case HASP Item
      ELSE
        p_hasp_instance_id                   := l_csi_item_rec.instance_id;
        l_instance_rec.instance_id           := l_csi_item_rec.instance_id;
        l_instance_rec.object_version_number := l_csi_item_rec.object_version_number;
      END IF;
      p_inventory_item_id  := l_new_inventory_item_id;
      p_inventory_revision := l_new_item_revision;

      l_instance_rec.inventory_item_id  := l_new_inventory_item_id; -- 298002;
      l_instance_rec.inventory_revision := l_new_item_revision; -- 'A';

      -- Dalit A. Raviv 18/07/2011
      -- Handle Extended Attributes -
      -- copy ext att from old instance with old item id to
      -- old instance with new item id
      ---------------------------------
      ------ External Attributes Details
      l_ext_attrib_values_tbl.delete;
      l_ext_attr_ind := 0;
      l_attribute_id := NULL;
      --l_ext_att_instance_id  := p_instance_rec.old_instance_id;

      IF p_hasp_item = 'N' THEN
        l_ext_att_instance_id := p_instance_rec.old_instance_id; -- 2217001

        -- case HASP item
      ELSE
        l_ext_att_instance_id := l_csi_item_rec.instance_id;
      END IF;
      --l_ext_att_instance_id           := p_instance_rec.old_instance_id; -- 2217001
      --
      FOR ext_attributes_r IN ext_attributes_c(l_ext_att_instance_id) LOOP
        -- to send hasp new_instance id
        l_ext_attr_ind := l_ext_attr_ind + 1;

        IF ext_attributes_r.attribute_level = 'ITEM' THEN
          --l_new_inventory_item_id
          BEGIN
            SELECT code.attribute_id
            INTO   l_attribute_id
            FROM   csi_i_extended_attribs code
            WHERE  code.attribute_code = ext_attributes_r.attribute_code
            AND    code.inventory_item_id = l_new_inventory_item_id;
          EXCEPTION
            WHEN OTHERS THEN
              l_attribute_id := NULL;
          END;
        ELSIF ext_attributes_r.attribute_level = 'CATEGORY' THEN
          --
          BEGIN
            SELECT code.attribute_id
            INTO   l_attribute_id
            FROM   csi_i_extended_attribs code,
                   mtl_item_categories_v  cat
            WHERE  attribute_level = 'CATEGORY'
            AND    code.attribute_code = ext_attributes_r.attribute_code
            AND    code.item_category_id = cat.category_id
            AND    cat.category_set_id = 1100000041 -- Main Category Set
            AND    cat.organization_id = g_master_organization_id -- 1.5  21/07/2015  Michal Tzvik: replace hard code (91)
            AND    cat.inventory_item_id = l_new_inventory_item_id;
          EXCEPTION
            WHEN OTHERS THEN
              l_attribute_id := NULL;
          END;
        ELSE
          l_attribute_id := ext_attributes_r.attribute_id;
        END IF;

        IF l_attribute_id IS NOT NULL THEN
          IF ext_attributes_r.attribute_code = 'OBJ_HASP_SV' THEN
            -- begin
            -- 1.2 20/03/2012 Dalit A. RAviv
            -- attribute_value
            l_err_code := 0;
            l_err_msg  := NULL;
            get_sales_ug_items_details(p_upgrade_item_id => p_instance_rec.upgrade_kit, -- i n
                                       p_before_upgrade_item => g_before_upgrade_item, -- i n
                                       p_before_upgrade_hasp => l_csi_item_rec.inventory_item_id, -- i n
                                       x_after_upgrade_item => l_after_upgrade_item, -- o n
                                       x_after_upgrade_hasp => l_after_upgrade_hasp, -- o n
                                       x_from_sw_version => l_attribute_value, -- o v
                                       p_err_code => l_err_code, -- o v
                                       p_err_desc => l_err_msg); -- o v

            IF l_err_code <> 0 THEN
              l_attribute_value := NULL;
              fnd_file.put_line(fnd_file.log, 'ERR6 - create NEW HASP ext attributes - failed find attribute value');
            END IF;
            /*-- attribute_value:
              -- Dalit A. Raviv 04/10/2011
              select v.sw_version
              into   l_attribute_value
              from   xxcs_sales_ug_items_v v
              where  v.upgrade_item_id = p_instance_rec.upgrade_kit-- p_upgrade_kit; --&Upgrade inv_item_id
              --and    v.from_sw_version = l_from_sw; -- Dalit A. Raviv 04/10/2011
              and    nvl(v.from_sw_version,'DR') = nvl(g_from_sw,nvl(v.from_sw_version,'DR'));
              --and    v.before_upgrade_item       = g_before_upgrade_item;
            exception
              when others then
                l_attribute_value := null;
                fnd_file.put_line(fnd_file.log,'ERR6 - create NEW HASP ext attributes - failed find attribute value');
            end;*/
          ELSE
            l_attribute_value := ext_attributes_r.attribute_value;
          END IF;
          l_ext_attrib_values_tbl(l_ext_attr_ind).attribute_value_id := ext_attributes_r.attribute_value_id;
          l_ext_attrib_values_tbl(l_ext_attr_ind).instance_id := l_ext_att_instance_id; --p_instance_rec.old_instance_id;
          l_ext_attrib_values_tbl(l_ext_attr_ind).attribute_id := l_attribute_id;
          l_ext_attrib_values_tbl(l_ext_attr_ind).attribute_code := ext_attributes_r.attribute_code;
          l_ext_attrib_values_tbl(l_ext_attr_ind).attribute_value := l_attribute_value; /*ext_attributes_r.attribute_value;*/
          l_ext_attrib_values_tbl(l_ext_attr_ind).object_version_number := ext_attributes_r.object_version_number;
        END IF;
      END LOOP; -- external_attributes
      ---------------------------------
      l_txn_rec.transaction_date        := SYSDATE;
      l_txn_rec.source_transaction_date := SYSDATE;
      l_txn_rec.transaction_type_id     := 205; -- Item Number and or Serial Number Change
      l_txn_rec.object_version_number   := 1;

      csi_item_instance_pub.update_item_instance(p_api_version => 1, p_commit => 'F', p_init_msg_list => 'T', p_validation_level => l_validation_level, p_instance_rec => l_instance_rec, p_ext_attrib_values_tbl => l_ext_attrib_values_tbl, p_party_tbl => l_party_tbl, p_account_tbl => l_account_tbl, p_pricing_attrib_tbl => l_pricing_attrib_tbl, p_org_assignments_tbl => l_org_assignments_tbl, p_asset_assignment_tbl => l_asset_assignment_tbl, p_txn_rec => l_txn_rec, x_instance_id_lst => l_instance_id_lst, x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data);
      IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
        -- 'S'
        fnd_msg_pub.get(p_msg_index => -1, p_encoded => 'F', p_data => l_msg_data, p_msg_index_out => l_msg_index_out);

        dbms_output.put_line('Err update old instance - ' ||
                             p_instance_rec.old_instance_id || '. Error: ' ||
                             substr(l_msg_data, 1, 240));
        fnd_file.put_line(fnd_file.log, 'Err update old instance - : ' ||
                           l_msg_data);
        p_err_code := 1;
        p_err_msg  := 'Err update old instance - ' ||
                      p_instance_rec.old_instance_id || '. Error: ' ||
                      substr(l_msg_data, 1, 240);
      ELSE
        dbms_output.put_line('Success update old instance - ' ||
                             p_instance_rec.old_instance_id);
        fnd_file.put_line(fnd_file.log, 'Success update old instance - ' ||
                           p_instance_rec.old_instance_id);
        p_err_code := 0;
        p_err_msg  := 'Success update old instance - ' ||
                      p_instance_rec.old_instance_id;
      END IF;
      IF l_sw_flag = 'Y' THEN
        p_err_code := 0;
        p_err_msg  := p_err_msg || ' ' || l_err_msg2;
      END IF;

    ELSE
      p_inventory_item_id  := NULL;
      p_inventory_revision := NULL;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('GEN Err update old instance - ' ||
                           p_instance_rec.old_instance_id || '. Err: ' ||
                           substr(l_msg_data, 1, 240));
      fnd_file.put_line(fnd_file.log, 'GEN Err update old instance - : ' ||
                         l_msg_data);
      p_err_code := 1;
      p_err_msg  := 'GEN Err update old instance - ' ||
                    p_instance_rec.old_instance_id || '. Error: ' ||
                    substr(l_msg_data, 1, 240);
  END update_item_instance_new;

  --------------------------------------------------------------------
  --  name:            close_old_relationship
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/03/2011
  --------------------------------------------------------------------
  --  purpose :        handle close old relation of old instance id
  --  out params:      p_msg_desc  - null success others failrd
  --                   p_msg_code  - 0    success 1 failed
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/03/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE close_old_relationship(p_old_instance_id IN NUMBER,
                                   p_relationship_id IN NUMBER,
                                   p_ovn             IN NUMBER,
                                   p_msg_desc        OUT VARCHAR2,
                                   p_msg_code        OUT VARCHAR2) IS

    --PRAGMA AUTONOMOUS_TRANSACTION;

    l_relationship_tbl csi_datastructures_pub.ii_relationship_tbl;
    l_txn_rec          csi_datastructures_pub.transaction_rec;
    l_return_status    VARCHAR2(2000);
    l_msg_count        NUMBER;
    l_msg_data         VARCHAR2(2500);
    l_msg_index_out    NUMBER;
    l_init_msg_lst     VARCHAR2(500);
    l_validation_level NUMBER;
    l_ovn              NUMBER;

  BEGIN    
    p_msg_desc         := NULL;
    p_msg_code         := 0;
    l_return_status    := NULL;
    l_msg_count        := NULL;
    l_init_msg_lst     := NULL;
    l_msg_index_out    := NULL;
    l_validation_level := NULL;
    l_msg_data         := NULL;
    l_ovn              := NULL;

    SELECT MAX(trxv.object_version_number)
    INTO   l_ovn
    FROM   csi_inst_transactions_v trxv
    WHERE  trxv.instance_id = p_old_instance_id;

    -- Relationship
    l_relationship_tbl(1).relationship_id := p_relationship_id;
    --l_relationship_tbl(1).relationship_type_code := 'COMPONENT-OF';
    l_relationship_tbl(1).object_version_number := p_ovn;
    l_relationship_tbl(1).active_end_date := SYSDATE - 1 / 60 / 24; -- one min less
    -- TXN
    l_txn_rec.transaction_date        := SYSDATE - 1 / 60 / 24;
    l_txn_rec.source_transaction_date := SYSDATE - 1 / 60 / 24;
    l_txn_rec.transaction_type_id     := 1;
    l_txn_rec.object_version_number   := l_ovn;

    csi_ii_relationships_pub.update_relationship(p_api_version => 1, p_commit => fnd_api.g_false, p_init_msg_list => l_init_msg_lst, p_validation_level => l_validation_level, p_relationship_tbl => l_relationship_tbl, -- i/o tbl
                                                 p_txn_rec => l_txn_rec, -- i/o rec
                                                 x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data);

    IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
      fnd_msg_pub.get(p_msg_index => -1, p_encoded => 'F', p_data => l_msg_data, p_msg_index_out => l_msg_index_out);

      dbms_output.put_line('Err Close Relation for instance id - ' ||
                           p_old_instance_id || ' Relation ' ||
                           p_relationship_id || '. Error: ' ||
                           substr(l_msg_data, 1, 240));

      fnd_file.put_line(fnd_file.log, 'Err Close Relation for instance id ' ||
                         p_old_instance_id || ' Relation ' ||
                         p_relationship_id || '. Error: ' ||
                         substr(l_msg_data, 1, 240));

      p_msg_desc := 'Err Close Relation for instance id - ' ||
                    p_old_instance_id || ' Relation ' || p_relationship_id ||
                    '. Error: ' || substr(l_msg_data, 1, 240);

      p_msg_code := 1;
      ROLLBACK;
    ELSE
      p_msg_desc := NULL;
      p_msg_code := 0;
    END IF; -- return status rel API

  EXCEPTION
    WHEN OTHERS THEN
      p_msg_desc := 'GEN EXC - Close_old_relationship - ' ||
                    substr(SQLERRM, 1, 240);
      p_msg_code := 1;
  END close_old_relationship;

  --------------------------------------------------------------------
  --  name:            create_new_relationship
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/03/2011
  --------------------------------------------------------------------
  --  purpose :        handle create new relation of new instance id
  --  out params:      p_msg_desc  - null success others failrd
  --                   p_msg_code  - 0    success 1 failed
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/03/2011  Dalit A. Raviv    initial build
  --  1.1  15/03/2015  Adi Safin         CHG0034735 - change source table
  --                                     from csi_item_instances to xxsf_csi_item_instances
  --  1.2  16/07/2015  Michal Tzvik      CHG0035439 - change source table from xxsf_csi_item_instances to csi_item_instances
  --------------------------------------------------------------------
  PROCEDURE create_new_relationship(p_object_id              IN NUMBER, -- p_new_instance_id
                                    p_relationship_type_code IN VARCHAR2,
                                    p_subject_id             IN NUMBER,
                                    p_position_reference     IN VARCHAR2,
                                    p_display_order          IN NUMBER,
                                    p_mandatory_flag         IN VARCHAR2,
                                    p_msg_desc               OUT VARCHAR2,
                                    p_msg_code               OUT VARCHAR2) IS

    --PRAGMA AUTONOMOUS_TRANSACTION;

    l_relationship_tbl  csi_datastructures_pub.ii_relationship_tbl;
    l_txn_rec           csi_datastructures_pub.transaction_rec;
    l_return_status     VARCHAR2(2000) := NULL;
    l_msg_count         NUMBER := NULL;
    l_msg_data          VARCHAR2(2500) := NULL;
    l_msg_index_out     NUMBER := NULL;
    l_init_msg_lst      VARCHAR2(500) := NULL;
    l_validation_level  NUMBER := NULL;
    l_relationship_id   NUMBER := NULL;
    l_count             NUMBER := NULL;
    l_subject_has_child VARCHAR2(5) := 'N';

  BEGIN  
    p_msg_desc          := NULL;
    p_msg_code          := 0;
    l_return_status     := NULL;
    l_msg_count         := NULL;
    l_init_msg_lst      := NULL;
    l_msg_index_out     := NULL;
    l_validation_level  := NULL;
    l_msg_data          := NULL;
    l_subject_has_child := 'N';
    l_count             := 0;

    -- Get if subject have childs
    SELECT COUNT(1)
    INTO   l_count
    FROM   csi_item_instances   cii, --1.3  16/07/2015  Michal Tzvik
           csi_ii_relationships cir
    WHERE  cir.object_id = cii.instance_id
    AND    cir.relationship_type_code = 'COMPONENT-OF'
    AND    cir.active_end_date IS NULL
    AND    cii.instance_id = p_subject_id;

    IF l_count = 0 THEN
      l_subject_has_child := 'N';
    ELSE
      l_subject_has_child := 'Y';
    END IF;

    SELECT csi_ii_relationships_s.nextval
    INTO   l_relationship_id
    FROM   dual;

    l_relationship_tbl(1).relationship_id := l_relationship_id;
    l_relationship_tbl(1).relationship_type_code := p_relationship_type_code; -- 'COMPONENT-OF'
    l_relationship_tbl(1).object_id := p_object_id; -- new_instance_id
    l_relationship_tbl(1).subject_id := p_subject_id;
    l_relationship_tbl(1).subject_has_child := l_subject_has_child;
    l_relationship_tbl(1).position_reference := p_position_reference;
    l_relationship_tbl(1).active_start_date := SYSDATE;
    l_relationship_tbl(1).active_end_date := NULL;
    l_relationship_tbl(1).display_order := p_display_order;
    l_relationship_tbl(1).mandatory_flag := p_mandatory_flag;
    l_relationship_tbl(1).object_version_number := 1;

    l_txn_rec.transaction_date        := trunc(SYSDATE);
    l_txn_rec.source_transaction_date := trunc(SYSDATE);
    l_txn_rec.transaction_type_id     := 1;
    l_txn_rec.object_version_number   := 1;

    csi_ii_relationships_pub.create_relationship(p_api_version => 1, p_commit => fnd_api.g_false, p_init_msg_list => l_init_msg_lst, p_validation_level => l_validation_level, p_relationship_tbl => l_relationship_tbl, p_txn_rec => l_txn_rec, x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data);

    IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
      fnd_msg_pub.get(p_msg_index => -1, p_encoded => 'F', p_data => l_msg_data, p_msg_index_out => l_msg_index_out);

      dbms_output.put_line('Err New Relation for instance id - ' ||
                           p_object_id || '. Error: ' ||
                           substr(l_msg_data, 1, 240));

      fnd_file.put_line(fnd_file.log, 'Err New Relation for instance id ' ||
                         p_object_id || '. Error: ' ||
                         substr(l_msg_data, 1, 240));

      p_msg_desc := 'Err New Relation for instance id - ' || p_object_id ||
                    '. Error: ' || substr(l_msg_data, 1, 240);
      p_msg_code := 1;
      ROLLBACK;
    ELSE
      p_msg_desc := NULL;
      p_msg_code := 0;

    END IF; -- return status rel API

  EXCEPTION
    WHEN OTHERS THEN
      p_msg_desc := 'GEN EXC - Create_new_relationship - ' ||
                    substr(SQLERRM, 1, 240);
      p_msg_code := 1;
  END create_new_relationship;

  --------------------------------------------------------------------
  --  name:            handle_relationship
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/03/2011
  --------------------------------------------------------------------
  --  purpose :        handle relationship - close old relation and create new
  --                   for the new instance-id
  --  out params:      p_msg_desc  - null success others failrd
  --                   p_msg_code  - 0    success 1 failed
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/03/2011  Dalit A. Raviv    initial build
  --  1.1  24/05/2011  dalit A. Raviv    1) Handle of New HASP need to create new New relation
  --                                     2) terminate old relation Items that have no serial number
  --                                     3) handle user PZ_INTF
  --  1.2  15/03/2015  Adi Safin         CHG0034735 - change source table
  --                                     from csi_item_instances to xxsf_csi_item_instances
  --  1.3  16/07/2015  Michal Tzvik      CHG0035439 - change source table from xxsf_csi_item_instances to csi_item_instances
  --------------------------------------------------------------------
  PROCEDURE handle_relationship(p_old_instance_id IN NUMBER,
                                p_old_serial      IN VARCHAR2,
                                p_old_item_id     IN NUMBER,
                                p_new_instance_id IN NUMBER,
                                p_new_hasp_ii     IN NUMBER,
                                p_user_name       IN VARCHAR2,
                                p_msg_desc        OUT VARCHAR2,
                                p_msg_code        OUT VARCHAR2) IS
    -- relationship
    CURSOR rel_pop_c IS
      SELECT xxcsi_ib_auto_upgrade_pkg.check_is_item_hasp_rel(cir.subject_id) is_hasp,
             cir.*,
             cii_child.serial_number
      FROM   csi_item_instances   cii, --1.3  16/07/2015  Michal Tzvik
             csi_item_instances   cii_child, --1.3  16/07/2015  Michal Tzvik
             csi_ii_relationships cir
      WHERE  to_char(cir.object_id) = cii.instance_id
      AND    cir.relationship_type_code = 'COMPONENT-OF'
      AND    cir.active_end_date IS NULL
      AND    cir.subject_id = cii_child.instance_id
      AND    cii.instance_id = p_old_instance_id;

    l_log_rec    t_log_rec;
    l_err_code   VARCHAR2(10);
    l_err_msg    VARCHAR2(1000);
    l_count      NUMBER;
    l_hasp_exist VARCHAR2(5) := 'N';

  BEGIN   
    p_msg_desc   := NULL;
    p_msg_code   := 0;
    l_hasp_exist := 'N';
    FOR rel_pop_r IN rel_pop_c LOOP

      l_count    := NULL;
      l_err_code := 0;
      l_err_msg  := NULL;
      -- 1) closed old relation
      close_old_relationship(p_old_instance_id => p_old_instance_id, -- i n
                             p_relationship_id => rel_pop_r.relationship_id, -- i n
                             p_ovn => rel_pop_r.object_version_number, -- i n
                             p_msg_desc => l_err_msg, -- o v
                             p_msg_code => l_err_code); -- o v
      IF l_err_code = 1 THEN
        IF p_user_name <> 'PZ_INTF' THEN
          l_log_rec.status               := 'ERROR';
          l_log_rec.instance_id_old      := p_old_instance_id;
          l_log_rec.serial_number_old    := p_old_serial;
          l_log_rec.upgrade_type         := p_old_item_id;
          l_log_rec.instance_id_new      := NULL;
          l_log_rec.hasp_instance_id_new := NULL;
          l_log_rec.msg_code             := 1;
          l_log_rec.msg_desc             := l_err_msg;

          handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                     p_err_code => l_err_code, -- o v
                     p_err_msg => l_err_msg); -- o v
        END IF;
        --rollback; --
        IF p_msg_desc IS NULL THEN
          p_msg_desc := 'Err - Close old relationship';
        ELSE
          p_msg_desc := p_msg_desc || chr(10) ||
                        'Err - Close old relationship';
        END IF;
        p_msg_code := 1;
      END IF;
      -- 2) create new relation
      SELECT COUNT(1)
      INTO   l_count
      FROM   csi_item_instances cii
      WHERE  cii.instance_id = rel_pop_r.subject_id --2112003
      AND    active_end_date IS NULL;
      IF l_count > 0 THEN
        l_err_code := 0;
        l_err_msg  := NULL;
        IF rel_pop_r.is_hasp = 'ITEM' THEN
          -- 23/05/2011 Dalit A. Raviv
          IF rel_pop_r.serial_number IS NOT NULL THEN
            create_new_relationship(p_object_id => p_new_instance_id, -- i n
                                    p_relationship_type_code => rel_pop_r.relationship_type_code, -- i v
                                    p_subject_id => rel_pop_r.subject_id, -- i n
                                    p_position_reference => rel_pop_r.position_reference, -- i v
                                    p_display_order => rel_pop_r.display_order, -- i n
                                    p_mandatory_flag => rel_pop_r.mandatory_flag, -- i v
                                    p_msg_desc => l_err_msg, -- o v
                                    p_msg_code => l_err_code); -- o v

            IF l_err_code = 1 THEN
              IF p_user_name <> 'PZ_INTF' THEN
                l_log_rec.status               := 'ERROR';
                l_log_rec.instance_id_old      := p_old_instance_id;
                l_log_rec.serial_number_old    := p_old_serial;
                l_log_rec.upgrade_type         := p_old_item_id;
                l_log_rec.instance_id_new      := p_new_instance_id;
                l_log_rec.hasp_instance_id_new := NULL;
                l_log_rec.msg_code             := 1;
                l_log_rec.msg_desc             := l_err_msg;

                handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                           p_err_code => l_err_code, -- o v
                           p_err_msg => l_err_msg); -- o v
              END IF;

              IF p_msg_desc IS NULL THEN
                p_msg_desc := 'Err - Create new relationship';
              ELSE
                p_msg_desc := p_msg_desc || chr(10) ||
                              'Err - Create new relationship';
              END IF;
              p_msg_code := 1;
            END IF; -- l_err_code
          ELSE
            -- 1.1 Dalit A. Raviv 24/05/2011 close(TERMINATE)
            -- old relation items that have no serial numbers
            l_err_code := 0;
            l_err_msg  := NULL;
            -- handle close of old upgrade instance
            handle_close_old_instance(p_old_instance_id => rel_pop_r.subject_id, -- i n
                                      p_old_close_date => NULL, -- i d
                                      p_upgrade_kit => NULL, -- i n
                                      p_source => 'REL', -- i v
                                      p_msg_desc => l_err_msg, -- o v
                                      p_msg_code => l_err_code); -- o v

            IF l_err_code = 1 THEN
              IF p_msg_desc IS NULL THEN
                p_msg_desc := 'Failed Termination of child ' ||
                              rel_pop_r.subject_id;
              ELSE
                p_msg_desc := p_msg_desc || chr(10) ||
                              'Failed Termination of child ' ||
                              rel_pop_r.subject_id;
              END IF;
              p_msg_code := 1;
              IF p_user_name <> 'PZ_INTF' THEN
                l_log_rec.status               := 'ERROR';
                l_log_rec.instance_id_old      := p_old_instance_id;
                l_log_rec.serial_number_old    := p_old_serial;
                l_log_rec.upgrade_type         := p_old_item_id;
                l_log_rec.instance_id_new      := p_new_instance_id;
                l_log_rec.hasp_instance_id_new := p_new_hasp_ii;
                l_log_rec.msg_code             := 1;
                l_log_rec.msg_desc             := l_err_msg;
                handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                           p_err_code => l_err_code, -- o v
                           p_err_msg => l_err_msg); -- o v
              END IF;
            END IF;
          END IF;
        ELSE
          -- HASP
          l_hasp_exist := 'Y';
          create_new_relationship(p_object_id => p_new_instance_id, -- i n
                                  p_relationship_type_code => rel_pop_r.relationship_type_code, -- i v
                                  p_subject_id => p_new_hasp_ii, -- i n
                                  p_position_reference => rel_pop_r.position_reference, -- i v
                                  p_display_order => rel_pop_r.display_order, -- i n
                                  p_mandatory_flag => rel_pop_r.mandatory_flag, -- i v
                                  p_msg_desc => l_err_msg, -- o v
                                  p_msg_code => l_err_code); -- o v

          IF l_err_code = 1 THEN
            IF p_user_name <> 'PZ_INTF' THEN
              l_log_rec.status               := 'ERROR';
              l_log_rec.instance_id_old      := p_old_instance_id;
              l_log_rec.serial_number_old    := p_old_serial;
              l_log_rec.upgrade_type         := p_old_item_id;
              l_log_rec.instance_id_new      := p_new_instance_id;
              l_log_rec.hasp_instance_id_new := p_new_hasp_ii;
              l_log_rec.msg_code             := 1;
              l_log_rec.msg_desc             := l_err_msg;

              handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                         p_err_code => l_err_code, -- o v
                         p_err_msg => l_err_msg); -- o v
            END IF;

            IF p_msg_desc IS NULL THEN
              p_msg_desc := 'Err - Create new HASP relationship';
            ELSE
              p_msg_desc := p_msg_desc || chr(10) ||
                            'Err - Create new HASP relationship';
            END IF;
            p_msg_code := 1;
          END IF; -- l_err_code
        END IF; -- is hasp
      END IF; -- l_count
    END LOOP;
    -- if there is no hasp item attach to the instance
    IF l_hasp_exist = 'N' THEN
      create_new_relationship(p_object_id => p_new_instance_id, -- i n
                              p_relationship_type_code => 'COMPONENT-OF', -- i v
                              p_subject_id => p_new_hasp_ii, -- i n
                              p_position_reference => NULL, -- i v
                              p_display_order => NULL, -- i n
                              p_mandatory_flag => 'N', -- i v
                              p_msg_desc => l_err_msg, -- o v
                              p_msg_code => l_err_code); -- o v

      IF l_err_code = 1 THEN
        IF p_user_name <> 'PZ_INTF' THEN
          l_log_rec.status               := 'ERROR';
          l_log_rec.instance_id_old      := p_old_instance_id;
          l_log_rec.serial_number_old    := p_old_serial;
          l_log_rec.upgrade_type         := p_old_item_id;
          l_log_rec.instance_id_new      := p_new_instance_id;
          l_log_rec.hasp_instance_id_new := NULL;
          l_log_rec.msg_code             := 1;
          l_log_rec.msg_desc             := l_err_msg;

          handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                     p_err_code => l_err_code, -- o v
                     p_err_msg => l_err_msg); -- o v
        END IF;

        IF p_msg_desc IS NULL THEN
          p_msg_desc := 'Err - Create new relationship for NEW HASP';
        ELSE
          p_msg_desc := p_msg_desc || chr(10) ||
                        'Err - Create new relationship for NEW HASP';
        END IF;
        p_msg_code := 1;
      END IF; -- l_err_code
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_msg_desc := 'GEN EXC - handle_relationship - ' ||
                    substr(SQLERRM, 1, 240);
      p_msg_code := 2;
  END handle_relationship;

  --------------------------------------------------------------------
  --  name:            check_is_item_hasp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/03/2011
  --------------------------------------------------------------------
  --  purpose :        Check if the item is HASP item
  --
  --  return:          HASP - item is HASP
  --                   ITEM - item is not
  --                   DUP  - if there is more then one HASP relate to the instance
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/03/2011  Dalit A. Raviv    initial build
  --  1.1  15/03/2015  Adi Safin         CHG0034735 - change source table
  --                                     from csi_item_instances to xxsf_csi_item_instances
  --  1.2  16/07/2015  Michal Tzvik      CHG0035439 - change source table from xxsf_csi_item_instances to csi_item_instances
  --------------------------------------------------------------------
  FUNCTION check_is_item_hasp(p_instance_id IN NUMBER) RETURN VARCHAR2 IS

    l_count NUMBER := 0;
  BEGIN    
    SELECT COUNT(cii.instance_id)
    INTO   l_count
    FROM   csi_item_instances    cii, --1.2  16/07/2015  Michal Tzvik
           csi_ii_relationships  cir,
           csi_item_instances    cii_child, --1.2  16/07/2015  Michal Tzvik
           csi_instance_statuses cis
    WHERE  to_char(cir.object_id) = cii.instance_id
    AND    cir.relationship_type_code = 'COMPONENT-OF'
    AND    cir.active_end_date IS NULL
    AND    cii_child.instance_id = cir.subject_id
    AND    cii_child.instance_status_id = cis.instance_status_id
    AND    cis.terminated_flag = 'N'
    AND    cii_child.inventory_item_id IN
           (SELECT msib.inventory_item_id
             FROM   mtl_system_items_b msib
             WHERE  msib.description LIKE 'HASP%'
             AND    msib.segment1 LIKE 'CMP%-S'                
             AND    msib.organization_id = g_master_organization_id -- 1.2  21/07/2015  Michal Tzvik: replace hard code (91)
             )
    AND    cii.instance_id = p_instance_id; --1217000

    IF l_count = 0 THEN
      RETURN 'ITEM';
    ELSIF l_count = 1 THEN
      RETURN 'HASP';
    ELSE
      RETURN 'DUP';
    END IF;
  END check_is_item_hasp;

  --------------------------------------------------------------------
  --  name:            check_is_item_hasp_rel
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   23/03/2011
  --------------------------------------------------------------------
  --  purpose :        Check if the instance is HASP item
  --                   i will call this function from the handle relationship
  --                   at the select each row will return if this is item or hasp
  --                   then Hasp item the new relationship has diffrent handling.
  --
  --  return:          HASP - item is HASP
  --                   ITEM - item is not
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/03/2011  Dalit A. Raviv    initial build
  --  1.1  15/03/2015  Adi Safin         CHG0034735 - change source table
  --                                     from csi_item_instances to xxsf_csi_item_instances
  --  1.2  16/07/2015  Michal Tzvik      CHG0035439 - change source table from xxsf_csi_item_instances to csi_item_instances
  --------------------------------------------------------------------
  FUNCTION check_is_item_hasp_rel(p_instance_id IN NUMBER) RETURN VARCHAR2 IS
    l_count NUMBER;
  BEGIN
    SELECT COUNT(1)
    INTO   l_count
    FROM   csi_item_instances cii --1.2  16/07/2015  Michal Tzvik
    WHERE  cii.instance_id = p_instance_id --2112002 --p_subject_id --
    AND    cii.inventory_item_id IN
           (SELECT msib.inventory_item_id
             FROM   mtl_system_items_b msib
             WHERE  msib.description LIKE 'HASP%'
             AND    msib.segment1 LIKE 'CMP%-S'
             AND    msib.organization_id = g_master_organization_id -- 1.2  21/07/2015  Michal Tzvik: replace hard code (91)
             );

    IF l_count = 1 THEN
      RETURN 'HASP';
    ELSE
      RETURN 'ITEM';
    END IF;

  END check_is_item_hasp_rel;

  --------------------------------------------------------------------
  --  name:            handle_close_old_instance
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/03/2011
  --------------------------------------------------------------------
  --  purpose :        handle close old instance
  --
  --  in param:        p_source    - 'MAIN' / 'REL'
  --  out params:      p_msg_desc  - null success others failrd
  --                   p_msg_code  - 0    success 1 failed
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/03/2011  Dalit A. Raviv  initial build
  --  1.1  24/05/2011  Dalit A. Raviv  Add p_source param and code to support.
  --                                   need to close old relation items with no serial number
  --------------------------------------------------------------------
  PROCEDURE handle_close_old_instance(p_old_instance_id IN NUMBER,
                                      p_old_close_date  IN DATE,
                                      p_upgrade_kit     IN NUMBER,
                                      p_source          IN VARCHAR2,
                                      p_msg_desc        OUT VARCHAR2,
                                      p_msg_code        OUT VARCHAR2) IS

    l_instance_rec         csi_datastructures_pub.instance_rec;
    l_party_tbl            csi_datastructures_pub.party_tbl;
    l_account_tbl          csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl   csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl  csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec              csi_datastructures_pub.transaction_rec;
    l_ext_attrib_values    csi_datastructures_pub.extend_attrib_values_tbl;
    l_return_status        VARCHAR2(2000) := NULL;
    l_msg_count            NUMBER := NULL;
    l_msg_data             VARCHAR2(2000) := NULL;
    l_msg_index_out        NUMBER;
    l_instance_id_lst      csi_datastructures_pub.id_tbl;
    l_validation_level     NUMBER := NULL;
    l_ovn                  NUMBER := NULL;

  BEGIN  
    p_msg_desc := NULL;
    p_msg_code := 0;

    SELECT MAX(cii.object_version_number)
    INTO   l_ovn
    FROM   csi_item_instances cii
    WHERE  cii.instance_id = p_old_instance_id;

    -- 1.1 Dalit A. Raviv 24/05/2011
    -- add p_source = REL
    IF p_source = 'MAIN' THEN
      l_instance_rec.instance_id           := p_old_instance_id;
      l_instance_rec.instance_status_id    := 10040; -- 'U/G - Not Active'
      l_instance_rec.object_version_number := l_ovn;
      l_instance_rec.active_end_date       := SYSDATE;
      IF p_upgrade_kit IS NOT NULL THEN
        l_instance_rec.attribute14 := p_upgrade_kit;
      END IF;
      IF p_old_close_date IS NOT NULL THEN
        l_instance_rec.attribute13 := to_char(p_old_close_date, 'YYYY/MM/DD HH24:MI:SS');
      END IF;
    ELSIF p_source = 'REL' THEN
      l_instance_rec.instance_id           := p_old_instance_id;
      l_instance_rec.instance_status_id    := 5; -- 'Terminated'
      l_instance_rec.object_version_number := l_ovn;
      l_instance_rec.active_end_date       := SYSDATE;
    END IF;
    l_txn_rec.transaction_date        := SYSDATE;
    l_txn_rec.source_transaction_date := SYSDATE;
    l_txn_rec.transaction_type_id     := 1;
    l_txn_rec.object_version_number   := 1;

    csi_item_instance_pub.update_item_instance(p_api_version => 1, p_commit => 'F', p_init_msg_list => 'T', p_validation_level => l_validation_level, p_instance_rec => l_instance_rec, p_ext_attrib_values_tbl => l_ext_attrib_values, p_party_tbl => l_party_tbl, p_account_tbl => l_account_tbl, p_pricing_attrib_tbl => l_pricing_attrib_tbl, p_org_assignments_tbl => l_org_assignments_tbl, p_asset_assignment_tbl => l_asset_assignment_tbl, p_txn_rec => l_txn_rec, x_instance_id_lst => l_instance_id_lst, x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data);
    IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
      -- 'S'
      fnd_msg_pub.get(p_msg_index => -1, p_encoded => 'F', p_data => l_msg_data, p_msg_index_out => l_msg_index_out);

      IF p_source = 'MAIN' THEN
        dbms_output.put_line('Error Close old instance - ' ||
                             p_old_instance_id || '. Error: ' ||
                             substr(l_msg_data, 1, 240));

        fnd_file.put_line(fnd_file.log, 'Error Close old instance ' ||
                           p_old_instance_id || '. Error: ' ||
                           substr(l_msg_data, 1, 240));

        p_msg_desc := 'Error Close old instance - ' || p_old_instance_id ||
                      '. Error: ' || substr(l_msg_data, 1, 240);
        p_msg_code := 1;
      ELSIF p_source = 'REL' THEN
        dbms_output.put_line('Error Close REL old instance - ' ||
                             p_old_instance_id || '. Error: ' ||
                             substr(l_msg_data, 1, 240));

        fnd_file.put_line(fnd_file.log, 'Error Close REL old instance ' ||
                           p_old_instance_id || '. Error: ' ||
                           substr(l_msg_data, 1, 240));

        p_msg_desc := 'Error Close REL old instance - ' ||
                      p_old_instance_id || '. Error: ' ||
                      substr(l_msg_data, 1, 240);
        p_msg_code := 1;
      END IF;
    ELSE
      p_msg_desc := NULL;
      p_msg_code := 0;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_msg_desc := 'GEN EXC - handle_close_old_instance - ' ||
                    substr(SQLERRM, 1, 240);
      p_msg_code := 1;
  END handle_close_old_instance;

  --------------------------------------------------------------------
  --  name:            handle_new_ext_attributes
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/07/2011
  --------------------------------------------------------------------
  --  purpose :        Handle create extended attribute for the upgraded old item instance
  --
  --  in param:        p_instance_rec - Hold old_instance_id + upgrade kit
  --  out params:      p_err_msg      - null success others failrd
  --                   p_err_code     - 0    success 1 failed
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  17/07/2011  Dalit A. Raviv  initial build
  --  1.2  21/07/2015  Michal Tzvik    CHG0035439 - replace hard code- 91 - with global variable
  --------------------------------------------------------------------
  PROCEDURE handle_new_ext_attributes(p_instance_rec      IN t_instance_rec,
                                      p_inventory_item_id IN NUMBER,
                                      p_err_code          OUT VARCHAR2,
                                      p_err_msg           OUT VARCHAR2) IS

    x_return_status          VARCHAR2(2000) := NULL;
    x_msg_count              NUMBER := NULL;
    x_msg_data               VARCHAR2(2000) := NULL;
    l_msg_index              NUMBER := 0;
    l_msg_count              NUMBER := 0;
    l_validation_level       NUMBER := NULL;
    l_ext_attrib_values_tbl  csi_datastructures_pub.extend_attrib_values_tbl;
    l_txn_rec                csi_datastructures_pub.transaction_rec;
    l_attribute_id           NUMBER := NULL;
    l_attribute_code         VARCHAR2(30) := NULL;
    l_ext_attribute_value_id NUMBER := NULL;
    ext_att_exception EXCEPTION;

  BEGIN    
    -- 3) Handle extended attributes values - only for the Old instance itself.
    -- get attribute id
    BEGIN
      SELECT cie.attribute_id,
             cie.attribute_code
      INTO   l_attribute_id,
             l_attribute_code
      FROM   csi_i_extended_attribs cie,
             fnd_lookup_values      flv,
             mtl_item_categories_v  cat
      WHERE  cie.attribute_code = flv.lookup_code
      AND    flv.language = 'US'
      AND    flv.attribute1 = to_char(p_instance_rec.upgrade_kit) --'377010'--'225021'
      AND    flv.enabled_flag = 'Y'
      AND    cie.attribute_level = 'CATEGORY'
      AND    cie.item_category_id = cat.category_id
      AND    cat.category_set_id = 1100000041 -- Main Category Set
      AND    cat.organization_id = g_master_organization_id -- 1.2  21/07/2015  Michal Tzvik: replace hard code (91)
      AND    cat.inventory_item_id = p_inventory_item_id --397001;--
      AND    nvl(flv.end_date_active, SYSDATE + 1) > SYSDATE
      AND    nvl(cie.active_end_date, SYSDATE + 1) > SYSDATE;

    EXCEPTION
      WHEN no_data_found THEN
        BEGIN

          SELECT cie.attribute_id,
                 cie.attribute_code
          INTO   l_attribute_id,
                 l_attribute_code
          FROM   csi_i_extended_attribs cie,
                 fnd_lookup_values      flv,
                 mtl_system_items_b     msi
          WHERE  cie.attribute_code = flv.lookup_code
          AND    flv.language = 'US'
          AND    flv.attribute1 = to_char(p_instance_rec.upgrade_kit) --'377010'--'225021'
          AND    flv.enabled_flag = 'Y'
          AND    cie.attribute_level = 'ITEM'
          AND    cie.inventory_item_id = msi.inventory_item_id --cie.item_category_id   = cat.category_id
          AND    msi.organization_id = g_master_organization_id -- 1.2  21/07/2015  Michal Tzvik: replace hard code (91)
          AND    msi.inventory_item_id = p_inventory_item_id --397001;--
          AND    nvl(flv.end_date_active, SYSDATE + 1) > SYSDATE
          AND    nvl(cie.active_end_date, SYSDATE + 1) > SYSDATE;
        EXCEPTION
          WHEN OTHERS THEN
            RAISE ext_att_exception;
        END;
      WHEN OTHERS THEN
        l_attribute_id := NULL;
        fnd_file.put_line(fnd_file.log, 'Err - create old item instance ext attributes - failed find attribute id');
    END;

    -- case no extended attribute exists
    SELECT csi_iea_values_s.nextval
    INTO   l_ext_attribute_value_id
    FROM   dual;

    l_ext_attrib_values_tbl(1).active_start_date := SYSDATE;

    l_ext_attrib_values_tbl(1).attribute_value_id := l_ext_attribute_value_id;
    l_ext_attrib_values_tbl(1).instance_id := p_instance_rec.old_instance_id;
    l_ext_attrib_values_tbl(1).attribute_code := l_attribute_code;
    l_ext_attrib_values_tbl(1).attribute_id := l_attribute_id;
    l_ext_attrib_values_tbl(1).attribute_value := to_char(SYSDATE, 'DD-MON-RRRR'); -- dd-MON-yyyy

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

    -- call to API
    csi_item_instance_pub.create_extended_attrib_values -- update_extended_attrib_values --
    (p_api_version => 1, p_commit => fnd_api.g_false, -- 'F'
     p_init_msg_list => 'T', p_validation_level => l_validation_level, p_ext_attrib_tbl => l_ext_attrib_values_tbl, p_txn_rec => l_txn_rec, x_return_status => x_return_status, x_msg_count => x_msg_count, x_msg_data => x_msg_data);
    IF NOT (x_return_status = fnd_api.g_ret_sts_success) THEN
      -- <> 'S'
      l_msg_index := 1;
      l_msg_count := x_msg_count;
      WHILE l_msg_count > 0 LOOP
        x_msg_data := fnd_msg_pub.get(l_msg_count, fnd_api.g_false);
        fnd_file.put_line(fnd_file.log, 'Failed create Extended attribute ' ||
                           chr(10) || ' Instance      ' ||
                           p_instance_rec.old_instance_id ||
                           chr(10) || ' Atribute      ' ||
                           l_attribute_id || chr(10) ||
                           ' Error Message ' || x_msg_data ||
                           chr(10));
        l_msg_index := l_msg_index + 1;
        l_msg_count := l_msg_count - 1;
      END LOOP;
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Err - create Extended attribute - ' ||
                    substr(x_msg_data, 1, 500);

    ELSE
      fnd_file.put_line(fnd_file.log, 'Success create Extended attribute' ||
                         ' Instance ' ||
                         p_instance_rec.old_instance_id ||
                         chr(10) || ' Atribute ' ||
                         l_attribute_id || chr(10));
      COMMIT;  
      p_err_code := 0;
      p_err_msg  := NULL;
    END IF;
  EXCEPTION
    WHEN ext_att_exception THEN
      p_err_code := 0;
      p_err_msg  := NULL;
    WHEN OTHERS THEN

      p_err_code := 1;
      p_err_msg  := 'GEN EXC - handle_HW_ext_attributes - ' ||
                    substr(SQLERRM, 1, 240);
  END handle_new_ext_attributes;

  --------------------------------------------------------------------
  --  name:            get_embedded_sw_version
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   02/04/2012
  --------------------------------------------------------------------
  --  purpose :        find the new embedded SW version of the upgrade printer.
  --  In Params:       p_old_inventory_item_id
  --                   p_upgrade_kit_desc
  --                   p_hasp_instance_id
  --                   p_old_embeded_sw_ver
  --  out params:      p_embedded_sw_ver
  --                   p_err_desc  - null success others failrd
  --                   p_err_code  - 0    success 1 failed
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/04/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_embedded_sw_version(p_old_inventory_item_id IN NUMBER,
                                    p_upgrade_kit_desc      IN VARCHAR2,
                                    p_hasp_item_id          IN NUMBER,
                                    p_old_embeded_sw_ver    IN VARCHAR2,
                                    p_embedded_sw_ver       OUT VARCHAR2,
                                    p_err_code              OUT VARCHAR2,
                                    p_err_desc              OUT VARCHAR2) IS

    l_embedded_sw_ver VARCHAR2(150) := NULL;
  BEGIN  
    p_err_code := 0;
    p_err_desc := NULL;

    SELECT attribute5
    INTO   l_embedded_sw_ver
    FROM   fnd_lookup_values_vl fl
    WHERE  fl.lookup_type = 'XXCSI_UPGRADE_TYPE'
    AND    fl.enabled_flag = 'Y'
    AND    attribute1 = p_old_inventory_item_id -- <old item id> att1 = From Printer;
    AND    description = p_upgrade_kit_desc -- <desc of the upgare kit > p_inventory_item_id upgrade_kit to get the segemnt1 from msi
    AND    attribute3 = p_hasp_item_id -- <old hasp item id>        can be null, att3 = From HASP id
    AND    attribute7 = p_old_embeded_sw_ver; -- <old attribute4 from old printer> -- can be null att7 = From Embedded SW ver

    p_embedded_sw_ver := l_embedded_sw_ver;
  EXCEPTION
    WHEN no_data_found THEN
      BEGIN
        SELECT attribute5
        INTO   l_embedded_sw_ver
        FROM   fnd_lookup_values_vl fl
        WHERE  fl.lookup_type = 'XXCSI_UPGRADE_TYPE'
        AND    fl.enabled_flag = 'Y'
        AND    attribute1 = p_old_inventory_item_id -- <old item id> att1 = From Printer;
        AND    description = p_upgrade_kit_desc -- <desc of the upgare kit > p_inventory_item_id upgrade_kit to get the segemnt1 from msi
        AND    attribute3 = p_hasp_item_id; -- <old hasp item id> can be null, att3 = From HASP id

        p_embedded_sw_ver := l_embedded_sw_ver;
      EXCEPTION
        WHEN no_data_found THEN
          BEGIN
            SELECT attribute5
            INTO   l_embedded_sw_ver
            FROM   fnd_lookup_values_vl fl
            WHERE  fl.lookup_type = 'XXCSI_UPGRADE_TYPE'
            AND    fl.enabled_flag = 'Y'
            AND    attribute1 = p_old_inventory_item_id -- <old item id> att1 = From Printer;
            AND    description = p_upgrade_kit_desc; -- <desc of the upgare kit > p_inventory_item_id upgrade_kit to get the segemnt1 from msi

            p_embedded_sw_ver := l_embedded_sw_ver;
          EXCEPTION
            WHEN OTHERS THEN
              p_embedded_sw_ver := NULL;
              p_err_code        := 1;
              p_err_desc        := '* Did not found Embeded SW version.';
          END;
      END;
    WHEN OTHERS THEN
      p_embedded_sw_ver := NULL;
      p_err_code        := 1;
      p_err_desc        := '** Did not found Embeded SW version.';
  END get_embedded_sw_version;
  
  --------------------------------------------------------------------
  --  name:            get_Studio_sw_version
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   04/08/2016
  --------------------------------------------------------------------
  --  purpose :        find the new embedded SW version of the upgrade printer.
  --  In Params:       p_old_inventory_item_id
  --                   p_upgrade_kit_desc
  --                   p_hasp_instance_id
  --                   p_old_studio_sw_ver
  --  out params:      p_studio_sw_ver
  --                   p_err_desc  - null success others failrd
  --                   p_err_code  - 0    success 1 failed
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  04/08/2016  Lingaraj Sarangi  CHG0037320 - Objet studio SW update
  --------------------------------------------------------------------
  PROCEDURE get_studio_sw_version(p_old_inventory_item_id IN NUMBER,
                                  p_upgrade_kit_desc      IN VARCHAR2,
                                  p_hasp_item_id          IN NUMBER,
                                  p_old_studio_sw_ver     IN VARCHAR2,
                                  p_studio_sw_ver         OUT VARCHAR2,
                                  p_err_code              OUT VARCHAR2,
                                  p_err_desc              OUT VARCHAR2) IS

    Cursor c_get_sw_ver(p_attribute1 Varchar2,
                        p_desc       Varchar2,
                        p_attribute3 Varchar2, 
                        p_attribute7 Varchar2
                       ) 
    IS
    Select attribute11    --To studio Version
    From   fnd_lookup_values_vl fl
    Where  fl.lookup_type  = 'XXCSI_UPGRADE_TYPE'
    And    fl.enabled_flag = 'Y'
    And    attribute1      = p_attribute1 -- <old item id> att1 = From Printer;
    And    description     = p_desc       -- <desc of the upgare kit > p_inventory_item_id upgrade_kit to get the segemnt1 from msi
    And    Nvl(attribute3,'-9999') = Nvl(p_attribute3,(Nvl(attribute3,'-9999')))  -- <old hasp item id>        can be null, att3 = From HASP id
    And    Nvl(attribute7,'-9999') = Nvl(p_attribute7,(Nvl(attribute7,'-9999'))); -- can be null att10 = From Studio SW ver
                                  
    l_studio_sw_ver Varchar2(150) := NULL;
  BEGIN 
    p_err_code := 0;
    p_err_desc := NULL;

    ----Check with 4 Param
    OPEN c_get_sw_ver(p_old_inventory_item_id ,p_upgrade_kit_desc,p_hasp_item_id ,p_old_studio_sw_ver );
    FETCH c_get_sw_ver INTO l_studio_sw_ver;   
    CLOSE c_get_sw_ver;
    ----Check with 3 Param
    If l_studio_sw_ver Is Null Then
      OPEN c_get_sw_ver(p_old_inventory_item_id ,p_upgrade_kit_desc,p_hasp_item_id ,NULL );
      FETCH c_get_sw_ver INTO l_studio_sw_ver;   
      CLOSE c_get_sw_ver;
          
    END If;  
    ----Check with 2 Param
    If l_studio_sw_ver Is Null Then
      OPEN c_get_sw_ver(p_old_inventory_item_id ,p_upgrade_kit_desc,NULL ,NULL );
      FETCH c_get_sw_ver INTO l_studio_sw_ver;   
            
      If c_get_sw_ver%notfound Then
        l_studio_sw_ver := Null;
      End If; 
            
      CLOSE c_get_sw_ver;
    END If;  
    ----  
    If l_studio_sw_ver Is Not Null Then
       p_studio_sw_ver := l_studio_sw_ver;
    Else
        p_studio_sw_ver := NULL;
        p_err_code        := 1;
        p_err_desc        := '* Did not found studio SW version.';  
    End If;
    ----   
  EXCEPTION    
    WHEN OTHERS THEN
      p_studio_sw_ver := NULL;
      p_err_code        := 1;
      p_err_desc        := '** Did not found studio SW version.';
      Print_Message('get_studio_sw_version Error :'||SQLERRM);
  END get_studio_sw_version;        

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/03/2011
  --------------------------------------------------------------------
  --  purpose :        Main process
  --  out params:      errbuf  - null success others failrd
  --                   retcode - 0    success 1 failed
  --  In Params:       p_instance_id
  --                   p_inventory_item_id
  --                   p_entity    - 'AUTO'   Automatic program
  --                               - 'MANUAL' Run Manual
  --                   p_hasp_sn
  --                   p_System_sn
  --                   p_user_name - fnd_user or PZ_INTF
  --                   p_SW_HW     - HW / SW
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/03/2011  Dalit A. Raviv    initial build
  --  1.1  23/05/2011  Dalit A. Raviv    xxcs_sales_ug_items_v view field names changed
  --                                     add parameter user name , p_hasp_sn, p_SW_HW
  --                                     change select of the close SR
  --  1.2  17/07/2011  Dalit A. Raviv    Roman found that instead of doing create new ii, close old ii,
  --                                     create new relationship etc, we can use the update ii API
  --                                     with transaction type 205 (Item Number and or Serial Number Change)
  --                                     this type give the ability to update item instance with new inventory_item_id.
  --                                     create new procedure main (the old one changed to main_old).
  --  1.3  04/10/2011  Dalit A. Raviv    add modifications according to the new logic of upgrade
  --  1.4  20/03/2012  Dalit A. Raviv    change logic to support new upgrade logic.
  --  1.5  15/03/2015  Adi Safin         CHG0034735 - change source table
  --                                     from csi_item_instances to xxsf_csi_item_instances
  --  1.6  16/07/2015  Michal Tzvik      CHG0035439 - change source table from xxsf_csi_item_instances to csi_item_instances
  --  1.7  08/05/2016  Lingaraj Sarangi  CHG0037320 - Objet studio SW update
  --------------------------------------------------------------------
  PROCEDURE main(errbuf              OUT VARCHAR2,
                 retcode             OUT VARCHAR2,
                 p_entity            IN VARCHAR2, -- AUTO / MANUAL
                 p_instance_id       IN NUMBER,
                 p_inventory_item_id IN NUMBER,
                 p_hasp_sn           IN VARCHAR2 DEFAULT NULL,
                 p_user_name         IN VARCHAR2 DEFAULT NULL,
                 p_sw_hw             IN VARCHAR2 DEFAULT 'HW') IS
    -- HW / SW

    CURSOR get_old_instance_c IS
      SELECT p_instance_id old_instance_id,
             p_inventory_item_id upgrade_kit,
             trunc(SYSDATE) close_date
      FROM   dual
      WHERE  p_entity = 'MANUAL';

    l_instance_rec     get_old_instance_c%ROWTYPE;
    l_err_code         VARCHAR2(1000);
    l_err_msg          VARCHAR2(2500);
    l_new_item_id      NUMBER;
    l_new_item_rev     VARCHAR2(3);
    l_old_item_id      NUMBER;
    l_old_serial       VARCHAR2(100);
    l_log_rec          t_log_rec;
    l_item_is_hasp     VARCHAR2(20);
    l_old_hasp_ii      NUMBER;
    l_new_hasp_ii      NUMBER;
    l_new_hasp_item_id NUMBER;
    l_parent_item_id   NUMBER;

    l_hasp_instance_id       NUMBER;
    l_hasp_inventory_item_id NUMBER;

    l_upgrade_kit          NUMBER;
    l_parent_serial_number VARCHAR2(30) := NULL;
    -- 04/10/2011 Dalit A. Raviv
    l_from_sw VARCHAR2(150);
    --
    l_subject_id      NUMBER;
    l_relationship_id NUMBER;
    l_ovn             NUMBER;
    l_is_fdm_item     Varchar2(1) := 'N';  --1.7 5-Aug-2016 CHG0037320 - Objet studio SW update
    --

    instance_exception EXCEPTION;
    general_exception  EXCEPTION;
    
  BEGIN    
    errbuf    := '';
    retcode   := 0;
    g_hasp_sn := p_hasp_sn;
    g_sw_hw   := p_sw_hw;
    
    -- g_master_organization_id := xxinv_utils_pkg.get_master_organization_id; -- 1.6 Michal Tzvik 21.07.2015 : move this code to declaration area in order to be available always
    IF p_user_name IS NOT NULL THEN
      SELECT user_id
      INTO   g_user_id
      FROM   fnd_user
      WHERE  user_name = p_user_name; -- 'PZ_INTF'

      g_user_name := p_user_name;

      IF p_user_name = 'PZ_INTF' THEN
        fnd_global.apps_initialize(user_id => g_user_id, resp_id => 51137, resp_appl_id => 514);
      END IF;
      -- to run from data base
      -- fnd_global.APPS_INITIALIZE(user_id => g_user_id, resp_id => 51137 ,resp_appl_id => 514);
    ELSE
      g_user_id := fnd_profile.value('USER_ID');
    END IF;         
    IF p_sw_hw = 'HW' THEN
      retcode := 0;
      errbuf  := NULL;      
      FOR get_old_instance_r IN get_old_instance_c LOOP
        BEGIN
          -- 1) close contract (terminate)
          -------------------------------
          -- 2) Update item instance with the new inventory item id
          l_err_code            := NULL;
          l_err_msg             := NULL;
          l_new_item_id         := NULL;
          l_instance_rec        := get_old_instance_r;
          l_item_is_hasp        := NULL;
          g_from_sw             := NULL;
          g_before_upgrade_item := NULL;

          SELECT (SELECT cii_oa.last_vld_organization_id
                  FROM   csi_item_instances cii_oa
                  WHERE  cii_oa.instance_id =
                         get_old_instance_r.old_instance_id) last_vld_organization_id,
                 cii.attribute4,
                 cii.inventory_item_id
          INTO   g_parent_organization_id,
                 g_from_sw,
                 g_before_upgrade_item
          FROM   csi_item_instances cii -- 1.6  16/07/2015  Michal Tzvik
          WHERE  cii.instance_id = get_old_instance_r.old_instance_id; -- p_instance_id
          /*
          select cii.attribute4, cii.inventory_item_id
          into   g_from_sw, g_before_upgrade_item
          from   csi_item_instances cii
          where  cii.instance_id    = get_old_instance_r.old_instance_id;*/
                    
          update_item_instance_new(p_instance_rec => l_instance_rec, -- i t_instance_rec,
                                   p_hasp_item => 'N', -- i v
                                   p_hasp_instance_id => l_hasp_instance_id, -- o n
                                   p_inventory_item_id => l_new_item_id, -- o n
                                   p_inventory_revision => l_new_item_rev, -- o v
                                   p_err_code => l_err_code, -- o v
                                   p_err_msg => l_err_msg); -- o v

          l_parent_item_id := l_new_item_id;
          IF l_err_code = 1 THEN
            ROLLBACK;  
            IF errbuf IS NULL THEN
              errbuf := l_err_msg;
            ELSE
              errbuf := errbuf || ', ' || l_err_msg;
            END IF; 
            retcode := 1;
            IF p_user_name <> 'PZ_INTF' THEN
              l_log_rec.status               := 'ERROR';
              l_log_rec.instance_id_old      := get_old_instance_r.old_instance_id;
              l_log_rec.serial_number_old    := NULL;
              l_log_rec.upgrade_type         := get_old_instance_r.upgrade_kit;
              l_log_rec.instance_id_new      := NULL;
              l_log_rec.hasp_instance_id_new := NULL;
              l_log_rec.msg_code             := 1;
              l_log_rec.msg_desc             := l_err_msg;
              handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                         p_err_code => l_err_code, -- o v
                         p_err_msg => l_err_msg); -- o v
            END IF;
            RAISE instance_exception;
          END IF;

          -------------------------------
          -- 3) Handle item HASP
          -- cases: 1) upgrade instance have more then one HASP item at the relationship
          --           in this case function return DUP and finish with error
          --        2) upgrade instance have one HASP item at the relationship
          --           in this case function return HASP and create new instance for the
          --           HASP item.
          --        3) upgrade instance have no HASP item at the relationship
          --           in this case function return ITEM and we do not need to creat
          --           instance for HASP, only for the upgrade instance
          l_item_is_hasp := check_is_item_hasp(p_instance_id => l_instance_rec.old_instance_id);
          --1.7 5-Aug-2016 CHG0037320 - Objet studio SW update
          l_is_fdm_item := xxinv_item_classification.is_item_fdm(p_inventory_item_id);          
        IF Nvl(l_is_fdm_item,'N') = 'N' Then  --1.7 5-Aug-2016 CHG0037320  
         --Hasp Part will be bypassed for FDM Technology Item      
          IF l_item_is_hasp = 'DUP' THEN
            IF errbuf IS NULL THEN
              errbuf := 'Item Instance Have more then one HASP items relate to';
            ELSE
              errbuf := errbuf || ', ' ||
                        'Item Instance Have more then one HASP items relate to';
            END IF;
            retcode := 1;
            IF p_user_name <> 'PZ_INTF' THEN
              l_log_rec.status               := 'ERROR';
              l_log_rec.instance_id_old      := get_old_instance_r.old_instance_id;
              l_log_rec.serial_number_old    := NULL;
              l_log_rec.upgrade_type         := get_old_instance_r.upgrade_kit;
              l_log_rec.instance_id_new      := NULL;
              l_log_rec.hasp_instance_id_new := NULL;
              l_log_rec.msg_code             := 1;
              l_log_rec.msg_desc             := 'Item Instance Have more then one HASP items relate to';
              handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                         p_err_code => l_err_code, -- o v
                         p_err_msg => l_err_msg); -- o v
            END IF;
            ROLLBACK;
            RAISE instance_exception;
          ELSIF l_item_is_hasp = 'HASP' THEN
            -- 2) create new item instance
            l_err_code         := NULL;
            l_err_msg          := NULL;
            l_new_hasp_ii      := NULL;
            l_new_hasp_item_id := NULL;
            l_old_hasp_ii      := NULL;
            l_old_item_id      := NULL;
            l_old_serial       := NULL;
            l_instance_rec     := get_old_instance_r;
            l_item_is_hasp     := NULL;

            update_item_instance_new(p_instance_rec => l_instance_rec, -- i t_instance_rec,
                                     p_hasp_item => 'Y', -- i v
                                     p_hasp_instance_id => l_hasp_instance_id, -- o n
                                     p_inventory_item_id => l_new_item_id, -- o n
                                     p_inventory_revision => l_new_item_rev, -- o v
                                     p_err_code => l_err_code, -- o v
                                     p_err_msg => l_err_msg); -- o v

            IF l_err_code = 1 THEN
              ROLLBACK;
              IF errbuf IS NULL THEN
                errbuf := l_err_msg;
              ELSE
                errbuf := errbuf || ', ' || l_err_msg;
              END IF;
              retcode := 1;
              IF p_user_name <> 'PZ_INTF' THEN
                l_log_rec.status               := 'ERROR';
                l_log_rec.instance_id_old      := get_old_instance_r.old_instance_id;
                l_log_rec.serial_number_old    := NULL;
                l_log_rec.upgrade_type         := get_old_instance_r.upgrade_kit;
                l_log_rec.instance_id_new      := NULL;
                l_log_rec.hasp_instance_id_new := NULL;
                l_log_rec.msg_code             := 1;
                l_log_rec.msg_desc             := l_err_msg;
                handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                           p_err_code => l_err_code, -- o v
                           p_err_msg => l_err_msg); -- o v
              END IF;
              RAISE instance_exception;
            END IF;

          ELSIF l_item_is_hasp = 'ITEM' THEN
            -- 2) create new item instance
            -- in this case there is no HASP item so i need to create new HASP item
            -- to the upgrade instance, and create new relationship between the
            -- new HASP ii to the old ii (parent)
            l_err_code         := NULL;
            l_err_msg          := NULL;
            l_new_hasp_ii      := NULL;
            l_new_hasp_item_id := NULL;
            l_old_hasp_ii      := NULL;
            l_old_item_id      := NULL;
            l_old_serial       := NULL;
            l_instance_rec     := get_old_instance_r;
            l_item_is_hasp     := NULL;

            create_item_instance(p_instance_rec => l_instance_rec, -- i t_instance_rec,
                                 p_hasp_item => 'NEW', -- i v
                                 p_old_instance_id => l_old_hasp_ii, -- o n  -- this is the old hasp instance
                                 p_old_item_id => l_old_item_id, -- o n  -- this is the old hasp item
                                 p_old_serial => l_old_serial, -- o v
                                 p_new_instance_id => l_new_hasp_ii, -- o n  -- this is the new hasp instance
                                 p_new_item_id => l_new_hasp_item_id, -- o n  -- this is the new hasp item
                                 p_err_code => l_err_code, -- o v
                                 p_err_msg => l_err_msg); -- o v

            IF l_err_code = 1 THEN
              ROLLBACK;
              IF errbuf IS NULL THEN
                errbuf := l_err_msg;
              ELSE
                errbuf := errbuf || ', ' || l_err_msg;
              END IF;
              retcode := 1;
              IF p_user_name <> 'PZ_INTF' THEN
                l_log_rec.status               := 'ERROR';
                l_log_rec.instance_id_old      := get_old_instance_r.old_instance_id;
                l_log_rec.serial_number_old    := NULL;
                l_log_rec.upgrade_type         := get_old_instance_r.upgrade_kit;
                l_log_rec.instance_id_new      := NULL;
                l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
                l_log_rec.msg_code             := 1;
                l_log_rec.msg_desc             := l_err_msg;
                handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                           p_err_code => l_err_code, -- o v
                           p_err_msg => l_err_msg); -- o v
              END IF;
              RAISE instance_exception;
            END IF;

            create_new_relationship(p_object_id => get_old_instance_r.old_instance_id, -- i n
                                    p_relationship_type_code => 'COMPONENT-OF', -- i v
                                    p_subject_id => l_new_hasp_ii, -- i n
                                    p_position_reference => NULL, -- i v
                                    p_display_order => NULL, -- i n
                                    p_mandatory_flag => 'N', -- i v
                                    p_msg_desc => l_err_msg, -- o v
                                    p_msg_code => l_err_code); -- o v

            IF l_err_code = 1 THEN
              ROLLBACK;
              IF p_user_name <> 'PZ_INTF' THEN
                l_log_rec.status               := 'ERROR';
                l_log_rec.instance_id_old      := get_old_instance_r.old_instance_id;
                l_log_rec.serial_number_old    := NULL;
                l_log_rec.upgrade_type         := get_old_instance_r.upgrade_kit;
                l_log_rec.instance_id_new      := NULL;
                l_log_rec.hasp_instance_id_new := NULL;
                l_log_rec.msg_code             := 1;
                l_log_rec.msg_desc             := l_err_msg;

                handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                           p_err_code => l_err_code, -- o v
                           p_err_msg => l_err_msg); -- o v
              END IF;

              IF l_err_msg IS NULL THEN
                errbuf := 'Err - Create new relationship for NEW HASP';
              ELSE
                errbuf := l_err_msg || chr(10) ||
                          'Err - Create new relationship for NEW HASP';
              END IF;
              retcode := 1;
            ELSE
              COMMIT;
            END IF; -- l_err_code

            -- 24/11/2011 Dalit A. Raviv
            -- add relationship between HASP and it's BARZEL
            -----------------------------------
            BEGIN
              l_subject_id := NULL;

              SELECT cii_child.instance_id, -- instance of the "barzel"
                     cir.relationship_id,
                     cir.object_version_number
              INTO   l_subject_id,
                     l_relationship_id,
                     l_ovn
              FROM   csi_item_instances    cii, --1.6  16/07/2015  Michal Tzvik
                     csi_ii_relationships  cir,
                     csi_item_instances    cii_child, --1.6  16/07/2015  Michal Tzvik
                     csi_instance_statuses cis
              WHERE  to_char(cir.object_id) = cii.instance_id
              AND    cir.relationship_type_code = 'COMPONENT-OF'
              AND    cir.active_end_date IS NULL
              AND    cii_child.instance_id = cir.subject_id
              AND    cii_child.inventory_item_id IN
                     (SELECT msib.inventory_item_id
                       FROM   mtl_system_items_b msib
                       WHERE  msib.segment1 = 'MSC-01023-S'
                       AND    msib.organization_id =
                              g_master_organization_id -- 1.6  21/07/2015  Michal Tzvik: replace hard code (91)
                       )
              AND    cii_child.instance_status_id = cis.instance_status_id
              AND    cis.terminated_flag = 'N'
              AND    cii.instance_id = get_old_instance_r.old_instance_id;
            EXCEPTION
              WHEN OTHERS THEN
                l_subject_id := NULL;
            END;
            IF l_subject_id IS NOT NULL THEN
              l_err_msg  := NULL;
              l_err_code := 0;
              --l_relationship_id := null;
              --l_ovn             := null;
              close_old_relationship(p_old_instance_id => get_old_instance_r.old_instance_id, -- i n
                                     p_relationship_id => l_relationship_id, -- i n
                                     p_ovn => l_ovn, -- i n
                                     p_msg_desc => l_err_msg, -- o v
                                     p_msg_code => l_err_code); -- o v

              IF l_err_code = 1 THEN
                ROLLBACK;
                IF p_user_name <> 'PZ_INTF' THEN
                  l_log_rec.status               := 'ERROR';
                  l_log_rec.instance_id_old      := p_instance_id;
                  l_log_rec.serial_number_old    := NULL;
                  l_log_rec.upgrade_type         := p_inventory_item_id;
                  l_log_rec.instance_id_new      := NULL;
                  l_log_rec.hasp_instance_id_new := l_hasp_instance_id;
                  l_log_rec.msg_code             := 1;
                  l_log_rec.msg_desc             := l_err_msg;

                  handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                             p_err_code => l_err_code, -- o v
                             p_err_msg => l_err_msg); -- o v
                END IF;

                IF l_err_msg IS NULL THEN
                  errbuf := 'Err - SW Create new relationship between NEW HASP and BARZEL';
                ELSE
                  errbuf := l_err_msg || chr(10) ||
                            'Err - SW Create new relationship between NEW HASP and BARZEL';
                END IF;
                retcode := 1;
              ELSE
                COMMIT;
                -----------------------------------
                create_new_relationship(p_object_id => l_new_hasp_ii, -- i n
                                        p_relationship_type_code => 'COMPONENT-OF', -- i v
                                        p_subject_id => l_subject_id, -- i n
                                        p_position_reference => NULL, -- i v
                                        p_display_order => NULL, -- i n
                                        p_mandatory_flag => 'N', -- i v
                                        p_msg_desc => l_err_msg, -- o v
                                        p_msg_code => l_err_code); -- o v

                IF l_err_code = 1 THEN
                  ROLLBACK;
                  IF p_user_name <> 'PZ_INTF' THEN
                    l_log_rec.status               := 'ERROR';
                    l_log_rec.instance_id_old      := get_old_instance_r.old_instance_id;
                    l_log_rec.serial_number_old    := NULL;
                    l_log_rec.upgrade_type         := get_old_instance_r.upgrade_kit;
                    l_log_rec.instance_id_new      := NULL;
                    l_log_rec.hasp_instance_id_new := NULL;
                    l_log_rec.msg_code             := 1;
                    l_log_rec.msg_desc             := l_err_msg;

                    handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                               p_err_code => l_err_code, -- o v
                               p_err_msg => l_err_msg); -- o v
                  END IF;

                  IF l_err_msg IS NULL THEN
                    errbuf := 'Err - HW Create new relationship between NEW HASP and BARZEL';
                  ELSE
                    errbuf := l_err_msg || chr(10) ||
                              'Err - HW Create new relationship between NEW HASP and BARZEL';
                  END IF;
                  retcode := 1;
                ELSE
                  COMMIT;
                END IF; -- l_err_code
              END IF; -- l_err_code
              -----------------------------------
            END IF;
            -----------------------------------
          END IF; -- l_item_is_hasp 
        END IF; --l_is_fdm_item = 'N', Skip For FDM Item  1.7 5-Aug-2016 CHG0037320
          -- 4) Handle Old instance id create extended attributes
          handle_new_ext_attributes(p_instance_rec => l_instance_rec, -- i t_instance_rec,
                                    p_inventory_item_id => l_parent_item_id, -- i n
                                    p_err_code => l_err_code, -- o v
                                    p_err_msg => l_err_msg); -- o v

          IF l_err_code = 1 THEN
            ROLLBACK;
            IF errbuf IS NULL THEN
              errbuf := l_err_msg;
            ELSE
              errbuf := errbuf || ', ' || l_err_msg;
            END IF;
            retcode := 1;
            IF p_user_name <> 'PZ_INTF' THEN
              l_log_rec.status               := 'ERROR';
              l_log_rec.instance_id_old      := get_old_instance_r.old_instance_id;
              l_log_rec.serial_number_old    := NULL;
              l_log_rec.upgrade_type         := get_old_instance_r.upgrade_kit;
              l_log_rec.instance_id_new      := NULL;
              l_log_rec.hasp_instance_id_new := NULL;
              l_log_rec.msg_code             := 1;
              l_log_rec.msg_desc             := l_err_msg;
              handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                         p_err_code => l_err_code, -- o v
                         p_err_msg => l_err_msg); -- o v
            END IF;
            RAISE instance_exception;
          END IF;

        EXCEPTION
          WHEN instance_exception THEN
            NULL;
        END;
      END LOOP;

    ELSIF p_sw_hw = 'SW' THEN
      -- By the parent serial number look if there is an HASP item.
      -- Return the HASP instance id and Item Id if exists
      l_err_code       := 0;
      l_err_msg        := NULL;
      l_parent_item_id := NULL;
      BEGIN
        -- Get parent printer serial number
        -- 04/10/2011 Dalit A. Raviv
        SELECT cii.serial_number,
               cii.inventory_item_id,
               attribute4
        INTO   l_parent_serial_number,
               l_parent_item_id,
               l_from_sw
        FROM   csi_item_instances cii -- 1.6  16/07/2015  Michal Tzvik
        WHERE  cii.instance_id = p_instance_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_parent_serial_number := NULL;
      END;

      g_before_upgrade_item := l_parent_item_id;

      -- get hasp details
      get_sw_hasp_exist(p_old_instance_id => p_instance_id, -- i n
                        p_hasp_instance_id => l_hasp_instance_id, -- o n
                        p_hasp_inventory_item_id => l_hasp_inventory_item_id, -- o n
                        p_error_code => l_err_code, -- o v
                        p_error_desc => l_err_msg); -- o v

      IF l_err_code <> 0 THEN
        errbuf  := l_err_msg;
        retcode := 1;
        RAISE general_exception;
      END IF;

      l_err_code := 0;
      l_err_msg  := NULL;
      -- By the parent serial number get the upgrade kit(item id) that can change.
      -- Return the HASP Item Id if exists
      /*get_HASP_after_upgrade (p_upgrade_kit      => p_inventory_item_id,--i n  this is the upgrade kit
      p_NEW_HASP_item_id => l_NEW_HASP_item_id, --o n
      p_errr_code        => l_err_code,         --o v
      p_errr_desc        => l_err_msg);        --o v*/
      --  1.4  20/03/2012  Dalit A. Raviv
      get_hasp_after_upgrade(p_upgrade_kit => p_inventory_item_id, -- i n
                             p_old_instance_item_id => l_parent_item_id, -- i n
                             p_old_instance_hasp_item_id => l_hasp_inventory_item_id, -- i n
                             p_new_hasp_item_id => l_new_hasp_item_id, -- o n
                             p_err_code => l_err_code, -- o v
                             p_err_desc => l_err_msg); -- o v

      IF l_err_code <> 0 THEN
        retcode := 1;
        errbuf  := l_err_msg;
        RAISE general_exception;
      END IF;

      -- If Hasp item id (that found attach to old printer) equal to hasp item id from the upgrade kit
      -- only need to update the external attributes
      -- if not equal need to create new hasp to the upgrade printer.
      -- Upgrade of exists HASP
      IF l_hasp_inventory_item_id = l_new_hasp_item_id THEN
        l_err_code := 0;
        l_err_msg  := NULL;
        -- procedure that only update item instance and update the extnded attributes.
        update_item_instance(p_old_instance_id => p_instance_id, -- i n           -- 06/08/2012 Dalit A. Raviv (send value instead of null
                             p_new_instance_id => NULL, -- i n
                             p_hasp_instance_id => l_hasp_instance_id, -- i n -> Hasp instance id
                             p_new_hasp_item_id => l_new_hasp_item_id, -- i n -> Hasp item id
                             p_upgrade_kit => p_inventory_item_id, -- i n -> this is parent upgrade kit
                             p_sw_hw => 'SW_UPG', -- i v
                             p_err_code => l_err_code, -- o v
                             p_err_msg => l_err_msg); -- o v

        IF l_err_code = 1 THEN
          errbuf  := l_err_msg;
          retcode := 1;
          ROLLBACK;
          IF p_user_name <> 'PZ_INTF' THEN
            l_log_rec.status               := 'ERROR';
            l_log_rec.instance_id_old      := p_instance_id;
            l_log_rec.serial_number_old    := l_parent_serial_number;
            l_log_rec.upgrade_type         := l_upgrade_kit;
            l_log_rec.instance_id_new      := NULL;
            l_log_rec.hasp_instance_id_new := p_instance_id;
            l_log_rec.msg_code             := 1;
            l_log_rec.msg_desc             := l_err_msg;
            handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                       p_err_code => l_err_code, -- o v
                       p_err_msg => l_err_msg); -- o v
          END IF;
          RAISE general_exception;
        ELSE
          COMMIT;
          errbuf  := 'Success1 update_item_instance with new external attributes';
          retcode := 0;

          -----------------
          -- 24/11/2011 Dalit A. Raviv
          -- add relationship between HASP and it's BARZEL
          -----------------------------------
          BEGIN
            l_subject_id := NULL;

            SELECT cii_child.instance_id, -- instance of the "barzel"
                   cir.relationship_id,
                   cir.object_version_number
            INTO   l_subject_id,
                   l_relationship_id,
                   l_ovn
            FROM   csi_item_instances    cii, -- 1.6  16/07/2015  Michal Tzvik
                   csi_ii_relationships  cir,
                   csi_item_instances    cii_child, -- 1.6  16/07/2015  Michal Tzvik
                   csi_instance_statuses cis
            WHERE  cir.object_id = cii.instance_id
            AND    cir.relationship_type_code = 'COMPONENT-OF'
            AND    cir.active_end_date IS NULL
            AND    cii_child.instance_id = cir.subject_id
            AND    cii_child.inventory_item_id IN
                   (SELECT msib.inventory_item_id
                     FROM   mtl_system_items_b msib
                     WHERE  msib.segment1 = 'MSC-01023-S'
                     AND    msib.organization_id = g_master_organization_id -- 1.6  21/07/2015  Michal Tzvik: replace hard code (91)
                     )
            AND    cii_child.instance_status_id = cis.instance_status_id
            AND    cis.terminated_flag = 'N'
            AND    cii.instance_id = p_instance_id; -- old_instance_id
          EXCEPTION
            WHEN OTHERS THEN
              l_subject_id := NULL;
          END;

          IF l_subject_id IS NOT NULL THEN
            l_err_msg  := NULL;
            l_err_code := 0;
            --l_relationship_id := null;
            --l_ovn             := null;
            close_old_relationship(p_old_instance_id => p_instance_id, -- i n
                                   p_relationship_id => l_relationship_id, -- i n
                                   p_ovn => l_ovn, -- i n
                                   p_msg_desc => l_err_msg, -- o v
                                   p_msg_code => l_err_code); -- o v

            IF l_err_code = 1 THEN
              ROLLBACK;
              IF p_user_name <> 'PZ_INTF' THEN
                l_log_rec.status               := 'ERROR';
                l_log_rec.instance_id_old      := p_instance_id;
                l_log_rec.serial_number_old    := NULL;
                l_log_rec.upgrade_type         := p_inventory_item_id;
                l_log_rec.instance_id_new      := NULL;
                l_log_rec.hasp_instance_id_new := l_hasp_instance_id;
                l_log_rec.msg_code             := 1;
                l_log_rec.msg_desc             := l_err_msg;

                handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                           p_err_code => l_err_code, -- o v
                           p_err_msg => l_err_msg); -- o v
              END IF;

              IF l_err_msg IS NULL THEN
                errbuf := 'Err - SW close_old_relationship';
              ELSE
                errbuf := l_err_msg || chr(10) ||
                          'Err - SW close_old_relationship';
              END IF;
              retcode := 1;
            ELSE
              COMMIT;
              create_new_relationship(p_object_id => l_hasp_instance_id, -- i n
                                      p_relationship_type_code => 'COMPONENT-OF', -- i v
                                      p_subject_id => l_subject_id, -- i n
                                      p_position_reference => NULL, -- i v
                                      p_display_order => NULL, -- i n
                                      p_mandatory_flag => 'N', -- i v
                                      p_msg_desc => l_err_msg, -- o v
                                      p_msg_code => l_err_code); -- o v

              IF l_err_code = 1 THEN
                ROLLBACK;
                IF p_user_name <> 'PZ_INTF' THEN
                  l_log_rec.status               := 'ERROR';
                  l_log_rec.instance_id_old      := p_instance_id;
                  l_log_rec.serial_number_old    := NULL;
                  l_log_rec.upgrade_type         := p_inventory_item_id;
                  l_log_rec.instance_id_new      := NULL;
                  l_log_rec.hasp_instance_id_new := l_hasp_instance_id;
                  l_log_rec.msg_code             := 1;
                  l_log_rec.msg_desc             := l_err_msg;

                  handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                             p_err_code => l_err_code, -- o v
                             p_err_msg => l_err_msg); -- o v
                END IF;

                IF l_err_msg IS NULL THEN
                  errbuf := 'Err - SW Create new relationship between NEW HASP and BARZEL';
                ELSE
                  errbuf := l_err_msg || chr(10) ||
                            'Err - SW Create new relationship between NEW HASP and BARZEL';
                END IF;
                retcode := 1;
              ELSE
                COMMIT;
              END IF; -- l_err_code
            END IF; -- l_err_code
          END IF;
          -----------------------------------

          -----------------
          -- Handle new extended attributes
          l_instance_rec.old_instance_id := p_instance_id;
          l_instance_rec.upgrade_kit     := p_inventory_item_id;
          l_instance_rec.close_date      := NULL;
          handle_new_ext_attributes(p_instance_rec => l_instance_rec, -- i t_instance_rec,
                                    p_inventory_item_id => l_parent_item_id, -- i n
                                    p_err_code => l_err_code, -- o v
                                    p_err_msg => l_err_msg); -- o v

          IF l_err_code = 1 THEN
            ROLLBACK;
            errbuf  := 'Error2 update_item_instance with new external attributes';
            retcode := 1;
          ELSE
            COMMIT;
            errbuf  := 'Success2 update_item_instance with new external attributes';
            retcode := 0;
          END IF;
        END IF; -- error handle
      ELSE
        -- need to create new Hasp and new relationship
        l_instance_rec.old_instance_id := p_instance_id;
        l_instance_rec.upgrade_kit     := p_inventory_item_id;
        l_instance_rec.close_date      := NULL;

        -- set g_parent_organization_id
        SELECT (SELECT cii_oa.last_vld_organization_id
                FROM   csi_item_instances cii_oa
                WHERE  cii_oa.instance_id = p_instance_id) last_vld_organization_id,
               cii.inventory_item_id
        INTO   g_parent_organization_id,
               l_parent_item_id
        FROM   csi_item_instances cii -- 1.6  16/07/2015  Michal Tzvik
        WHERE  cii.instance_id = p_instance_id;

        -- get new HASP instance id
        create_item_instance(p_instance_rec => l_instance_rec, -- i t_instance_rec,
                             p_hasp_item => 'NEW', -- i v
                             p_old_instance_id => l_old_hasp_ii, -- o n  -- this is the old hasp instance
                             p_old_item_id => l_old_item_id, -- o n  -- this is the old hasp item
                             p_old_serial => l_old_serial, -- o v
                             p_new_instance_id => l_new_hasp_ii, -- o n  -- this is the new hasp instance
                             p_new_item_id => l_new_hasp_item_id, -- o n  -- this is the new hasp item
                             p_err_code => l_err_code, -- o v
                             p_err_msg => l_err_msg); -- o v

        IF l_err_code = 1 THEN
          ROLLBACK;
          errbuf  := l_err_msg;
          retcode := 1;
          IF p_user_name <> 'PZ_INTF' THEN
            l_log_rec.status               := 'ERROR';
            l_log_rec.instance_id_old      := p_instance_id;
            l_log_rec.serial_number_old    := l_old_serial;
            l_log_rec.upgrade_type         := p_inventory_item_id;
            l_log_rec.instance_id_new      := NULL;
            l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
            l_log_rec.msg_code             := 1;
            l_log_rec.msg_desc             := l_err_msg;
            handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                       p_err_code => l_err_code, -- o v
                       p_err_msg => l_err_msg); -- o v
          END IF;
          RAISE general_exception;
        ELSE
          -- create new relation between the parent printer(old)
          -- and the new HASP item.
          create_new_relationship(p_object_id => p_instance_id, -- i n
                                  p_relationship_type_code => 'COMPONENT-OF', -- i v
                                  p_subject_id => l_new_hasp_ii, -- i n
                                  p_position_reference => NULL, -- i v
                                  p_display_order => NULL, -- i n
                                  p_mandatory_flag => 'N', -- i v
                                  p_msg_desc => l_err_msg, -- o v
                                  p_msg_code => l_err_code); -- o v

          IF l_err_code = 1 THEN
            errbuf  := l_err_msg;
            retcode := 1;
            ROLLBACK;
            IF p_user_name <> 'PZ_INTF' THEN
              l_log_rec.status               := 'ERROR';
              l_log_rec.instance_id_old      := p_instance_id;
              l_log_rec.serial_number_old    := l_parent_serial_number;
              l_log_rec.upgrade_type         := p_inventory_item_id;
              l_log_rec.instance_id_new      := NULL;
              l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
              l_log_rec.msg_code             := 1;
              l_log_rec.msg_desc             := l_err_msg;

              handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                         p_err_code => l_err_code, -- o v
                         p_err_msg => l_err_msg); -- o v
            END IF;
          ELSE
            COMMIT;
            errbuf  := 'SUCCESS';
            retcode := 0;
            IF p_user_name <> 'PZ_INTF' THEN
              l_log_rec.status               := 'SUCCESS';
              l_log_rec.instance_id_old      := p_instance_id;
              l_log_rec.serial_number_old    := l_parent_serial_number;
              l_log_rec.upgrade_type         := p_inventory_item_id;
              l_log_rec.instance_id_new      := NULL;
              l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
              l_log_rec.msg_code             := 1;
              l_log_rec.msg_desc             := l_err_msg;
              handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                         p_err_code => l_err_code, -- o v
                         p_err_msg => l_err_msg); -- o v
            END IF;

            -- 24/11/2011 Dalit A. Raviv
            -- add relationship between HASP and it's BARZEL
            -----------------------------------
            BEGIN
              l_subject_id := NULL;

              SELECT cii_child.instance_id, -- instance of the "barzel"
                     cir.relationship_id,
                     cir.object_version_number
              INTO   l_subject_id,
                     l_relationship_id,
                     l_ovn
              FROM   csi_item_instances    cii, -- 1.6  16/07/2015  Michal Tzvik
                     csi_ii_relationships  cir,
                     csi_item_instances    cii_child, -- 1.6  16/07/2015  Michal Tzvik
                     csi_instance_statuses cis
              WHERE  cir.object_id = cii.instance_id
              AND    cir.relationship_type_code = 'COMPONENT-OF'
              AND    cir.active_end_date IS NULL
              AND    cii_child.instance_id = cir.subject_id
              AND    cii_child.inventory_item_id IN
                     (SELECT msib.inventory_item_id
                       FROM   mtl_system_items_b msib
                       WHERE  msib.segment1 = 'MSC-01023-S'
                       AND    msib.organization_id =
                              g_master_organization_id -- 1.6  21/07/2015  Michal Tzvik: replace hard code (91)
                       )
              AND    cii_child.instance_status_id = cis.instance_status_id
              AND    cis.terminated_flag = 'N'
              AND    cii.instance_id = p_instance_id; -- old_instance_id
            EXCEPTION
              WHEN OTHERS THEN
                l_subject_id := NULL;
            END;

            IF l_subject_id IS NOT NULL THEN
              l_err_msg  := NULL;
              l_err_code := 0;
              close_old_relationship(p_old_instance_id => p_instance_id, -- i n
                                     p_relationship_id => l_relationship_id, -- i n
                                     p_ovn => l_ovn, -- i n
                                     p_msg_desc => l_err_msg, -- o v
                                     p_msg_code => l_err_code); -- o v

              IF l_err_code = 1 THEN
                ROLLBACK;
                IF p_user_name <> 'PZ_INTF' THEN
                  l_log_rec.status               := 'ERROR';
                  l_log_rec.instance_id_old      := p_instance_id;
                  l_log_rec.serial_number_old    := NULL;
                  l_log_rec.upgrade_type         := p_inventory_item_id;
                  l_log_rec.instance_id_new      := NULL;
                  l_log_rec.hasp_instance_id_new := l_hasp_instance_id;
                  l_log_rec.msg_code             := 1;
                  l_log_rec.msg_desc             := l_err_msg;

                  handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                             p_err_code => l_err_code, -- o v
                             p_err_msg => l_err_msg); -- o v
                END IF;

                IF l_err_msg IS NULL THEN
                  errbuf := 'Err - SW Create new relationship between NEW HASP and BARZEL';
                ELSE
                  errbuf := l_err_msg || chr(10) ||
                            'Err - SW Create new relationship between NEW HASP and BARZEL';
                END IF;
                retcode := 1;
              ELSE
                COMMIT;
                create_new_relationship(p_object_id => l_new_hasp_ii, -- i n
                                        p_relationship_type_code => 'COMPONENT-OF', -- i v
                                        p_subject_id => l_subject_id, -- i n
                                        p_position_reference => NULL, -- i v
                                        p_display_order => NULL, -- i n
                                        p_mandatory_flag => 'N', -- i v
                                        p_msg_desc => l_err_msg, -- o v
                                        p_msg_code => l_err_code); -- o v

                IF l_err_code = 1 THEN
                  ROLLBACK;
                  IF p_user_name <> 'PZ_INTF' THEN
                    l_log_rec.status               := 'ERROR';
                    l_log_rec.instance_id_old      := p_instance_id;
                    l_log_rec.serial_number_old    := NULL;
                    l_log_rec.upgrade_type         := p_inventory_item_id;
                    l_log_rec.instance_id_new      := NULL;
                    l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
                    l_log_rec.msg_code             := 1;
                    l_log_rec.msg_desc             := l_err_msg;

                    handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                               p_err_code => l_err_code, -- o v
                               p_err_msg => l_err_msg); -- o v
                  END IF;

                  IF l_err_msg IS NULL THEN
                    errbuf := 'Err - SW Create new relationship between NEW HASP and BARZEL';
                  ELSE
                    errbuf := l_err_msg || chr(10) ||
                              'Err - SW Create new relationship between NEW HASP and BARZEL';
                  END IF;
                  retcode := 1;
                ELSE
                  COMMIT;
                END IF; -- l_err_code
              END IF;
            END IF;
            -----------------------------------

            -- Handle new extended attributes
            handle_new_ext_attributes(p_instance_rec => l_instance_rec, -- i t_instance_rec,
                                      p_inventory_item_id => l_parent_item_id, -- i n
                                      p_err_code => l_err_code, -- o v
                                      p_err_msg => l_err_msg); -- o v

            IF l_err_code = 1 THEN
              l_err_msg := substr(l_err_msg, 1, 240);
              errbuf    := 'Error3 update_item_instance with new external attributes ' ||
                           l_err_msg;
              retcode   := 1;
            ELSE
              errbuf  := 'SUCCESS';
              retcode := 0;
            END IF;

          END IF; -- l_err_code
        END IF;
        -- 06/08/2012 Dalit A. Raviv
        -- handle embeded_sw_version update to attribute4 at instance level
        -- procedure that only update item instance and update the extnded attributes.
        l_err_code := 0;
        l_err_msg  := NULL;

        --p_new_instance_id => l_new_hasp_ii,     -- o n  -- this is the new hasp instance
        --p_new_item_id     => l_new_hasp_item_id,-- o n  -- this is the new hasp item

        update_item_instance(p_old_instance_id => p_instance_id, -- i n           -- 06/08/2012 Dalit A. Raviv (send value instead of null
                             p_new_instance_id => NULL, -- i n
                             p_hasp_instance_id => l_new_hasp_ii, -- i n -> Hasp instance id
                             p_new_hasp_item_id => l_new_hasp_item_id, -- i n -> Hasp item id
                             p_upgrade_kit => p_inventory_item_id, -- i n -> this is parent upgrade kit
                             p_sw_hw => 'EMB_SW_VER', -- i v
                             p_err_code => l_err_code, -- o v
                             p_err_msg => l_err_msg); -- o v

        IF l_err_code = 1 THEN
          errbuf  := l_err_msg;
          retcode := 1;
          ROLLBACK;
          IF p_user_name <> 'PZ_INTF' THEN
            l_log_rec.status               := 'ERROR';
            l_log_rec.instance_id_old      := p_instance_id;
            l_log_rec.serial_number_old    := l_parent_serial_number;
            l_log_rec.upgrade_type         := l_upgrade_kit;
            l_log_rec.instance_id_new      := NULL;
            l_log_rec.hasp_instance_id_new := p_instance_id;
            l_log_rec.msg_code             := 1;
            l_log_rec.msg_desc             := l_err_msg;
            handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                       p_err_code => l_err_code, -- o v
                       p_err_msg => l_err_msg); -- o v
          END IF;
          RAISE general_exception;
        ELSE
          COMMIT;
          errbuf  := 'Success update_item_instance with Embeded SW version (attribute4)';
          retcode := 0;
        END IF;
      END IF; -- 'SW_UPG'
    END IF; -- p_SW_HW = 'SW'

  EXCEPTION
    WHEN general_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'GEN EXC - main - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
      dbms_output.put_line('GEN EXC - main - ' || substr(SQLERRM, 1, 240));
  END main;

  --------------------------------------------------------------------
  --  name:            get_item_catagory
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/03/2011
  --------------------------------------------------------------------
  --  purpose :        handle reverse instance to item before upgrade
  --
  --  in param:        p_inventory_item_id
  --  return:          category of the item (string to check)
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  17/04/2012  Dalit A. Raviv  Initial ver.
  --  1.1  21/07/2015  Michal Tzvik    CHG0035439 - replace hard code- 91 - with global variable
  --------------------------------------------------------------------
  FUNCTION get_item_catagory(p_inventory_item_id IN NUMBER) RETURN VARCHAR2 IS

    l_category_to_check VARCHAR2(100) := NULL;
  BEGIN
    SELECT mcb.segment1 || '.' || substr(mcb.segment2, 1, 2) string_to_check
    INTO   l_category_to_check
    FROM   mtl_system_items_b  msib,
           mtl_item_categories mic,
           mtl_categories_b    mcb
    WHERE  msib.organization_id = g_master_organization_id -- 1.1  21/07/2015  Michal Tzvik: replace hard code (91)
    AND    mic.inventory_item_id = msib.inventory_item_id
    AND    msib.organization_id = mic.organization_id
    AND    mic.category_id = mcb.category_id
    AND    msib.inventory_item_id = p_inventory_item_id
    AND    mic.category_set_id = 1100000041; -- Main Category sets

    RETURN l_category_to_check;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            reverse_item_instance_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/04/2012
  --------------------------------------------------------------------
  --  purpose :        handle update of item instance with
  --                   the new inventory item id and revision.
  --  out params:      p_msg_desc  - null success others failrd
  --                   p_msg_code  - 0    success 1 failed
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/04/2012  Dalit A. Raviv    initial build
  --  1.1  21/07/2015  Michal Tzvik      CHG0035439 - replace hard code- 91 - with global variable
  --------------------------------------------------------------------
  PROCEDURE reverse_item_instance_api(p_instance_id       IN NUMBER,
                                      p_inventory_item_id IN NUMBER,
                                      p_item_revision     IN VARCHAR2,
                                      p_ovn               IN NUMBER,
                                      p_err_code          OUT VARCHAR2,
                                      p_err_msg           OUT VARCHAR2) IS

    -- get extended attributes from instance to set null values. (attribute_value = null)
    CURSOR ext_attributes_c(p_inctance_id IN NUMBER) IS
      SELECT civ.attribute_id,
             civ.attribute_value,
             code.attribute_code,
             civ.active_start_date,
             civ.object_version_number,
             civ.attribute_value_id,
             code.attribute_level
      FROM   csi_iea_values         civ,
             csi_i_extended_attribs code
      WHERE  civ.instance_id = p_inctance_id
      AND    code.attribute_id = civ.attribute_id
      AND    civ.attribute_value IS NOT NULL
      AND    SYSDATE BETWEEN civ.active_start_date AND
             nvl(civ.active_end_date, SYSDATE + 1);

    l_instance_rec          csi_datastructures_pub.instance_rec;
    l_party_tbl             csi_datastructures_pub.party_tbl;
    l_account_tbl           csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl    csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl   csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl  csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec               csi_datastructures_pub.transaction_rec;
    l_ext_attrib_values_tbl csi_datastructures_pub.extend_attrib_values_tbl;
    l_return_status         VARCHAR2(2000) := NULL;
    l_msg_count             NUMBER := NULL;
    l_msg_data              VARCHAR2(2000) := NULL;
    l_msg_index_out         NUMBER;
    l_instance_id_lst       csi_datastructures_pub.id_tbl;
    l_validation_level      NUMBER := NULL;
    l_attribute_value       VARCHAR2(30) := NULL;

    l_attribute_id        NUMBER;
    l_ext_att_instance_id NUMBER;
    l_ext_attr_ind        NUMBER;

  BEGIN
    dbms_output.put_line('-------------' || p_instance_id || p_instance_id);
    fnd_file.put_line(fnd_file.log, '-------------' || p_instance_id ||
                       p_instance_id);

    l_instance_rec.instance_id           := p_instance_id;
    l_instance_rec.object_version_number := p_ovn;
    l_instance_rec.inventory_item_id     := p_inventory_item_id;
    l_instance_rec.inventory_revision    := p_item_revision;

    -- Handle Extended Attributes -
    -- copy ext att from instance with item before reverse upgrade
    -- to instance with item after reverse upgrade
    -- External Attributes Details
    l_ext_attrib_values_tbl.delete;
    l_ext_attr_ind        := 0;
    l_attribute_id        := NULL;
    l_ext_att_instance_id := p_instance_id;

    FOR ext_attributes_r IN ext_attributes_c(l_ext_att_instance_id) LOOP
      l_ext_attr_ind := l_ext_attr_ind + 1;
      IF ext_attributes_r.attribute_level = 'ITEM' THEN
        --l_new_inventory_item_id
        BEGIN
          SELECT code.attribute_id
          INTO   l_attribute_id
          FROM   csi_i_extended_attribs code
          WHERE  code.attribute_code = ext_attributes_r.attribute_code
          AND    code.inventory_item_id = p_inventory_item_id;
        EXCEPTION
          WHEN OTHERS THEN
            l_attribute_id := NULL;
        END;
      ELSIF ext_attributes_r.attribute_level = 'CATEGORY' THEN
        --
        BEGIN
          SELECT code.attribute_id
          INTO   l_attribute_id
          FROM   csi_i_extended_attribs code,
                 mtl_item_categories_v  cat
          WHERE  attribute_level = 'CATEGORY'
          AND    code.attribute_code = ext_attributes_r.attribute_code
          AND    code.item_category_id = cat.category_id
          AND    cat.category_set_id = 1100000041 -- Main Category Set
          AND    cat.organization_id = g_master_organization_id -- 1.1  21/07/2015  Michal Tzvik: replace hard code (91)
          AND    cat.inventory_item_id = p_inventory_item_id;
        EXCEPTION
          WHEN OTHERS THEN
            l_attribute_id := NULL;
        END;
      ELSE
        l_attribute_id := ext_attributes_r.attribute_id;
      END IF;
      IF l_attribute_id IS NOT NULL THEN
        l_attribute_value := NULL;
        l_ext_attrib_values_tbl(l_ext_attr_ind).attribute_value_id := ext_attributes_r.attribute_value_id;
        l_ext_attrib_values_tbl(l_ext_attr_ind).instance_id := l_ext_att_instance_id;
        l_ext_attrib_values_tbl(l_ext_attr_ind).attribute_id := l_attribute_id;
        l_ext_attrib_values_tbl(l_ext_attr_ind).attribute_code := ext_attributes_r.attribute_code;
        l_ext_attrib_values_tbl(l_ext_attr_ind).attribute_value := l_attribute_value;
        l_ext_attrib_values_tbl(l_ext_attr_ind).object_version_number := ext_attributes_r.object_version_number;
      END IF;
    END LOOP; -- external_attributes
    ---------------------------------
    l_txn_rec.transaction_date        := SYSDATE;
    l_txn_rec.source_transaction_date := SYSDATE;
    l_txn_rec.transaction_type_id     := 205; -- Item Number and or Serial Number Change
    l_txn_rec.object_version_number   := 1;

    csi_item_instance_pub.update_item_instance(p_api_version => 1, p_commit => 'F', p_init_msg_list => 'T', p_validation_level => l_validation_level, p_instance_rec => l_instance_rec, p_ext_attrib_values_tbl => l_ext_attrib_values_tbl, p_party_tbl => l_party_tbl, p_account_tbl => l_account_tbl, p_pricing_attrib_tbl => l_pricing_attrib_tbl, p_org_assignments_tbl => l_org_assignments_tbl, p_asset_assignment_tbl => l_asset_assignment_tbl, p_txn_rec => l_txn_rec, x_instance_id_lst => l_instance_id_lst, x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data);
    IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
      -- 'S'
      fnd_msg_pub.get(p_msg_index => -1, p_encoded => 'F', p_data => l_msg_data, p_msg_index_out => l_msg_index_out);

      dbms_output.put_line('Err update instance - ' || p_instance_id ||
                           '. Error: ' || substr(l_msg_data, 1, 240));
      fnd_file.put_line(fnd_file.log, 'Err update old instance - : ' ||
                         l_msg_data);
      p_err_code := 1;
      p_err_msg  := 'Err update old instance - ' || p_instance_id ||
                    '. Error: ' || substr(l_msg_data, 1, 240);
    ELSE
      dbms_output.put_line('Success update instance - ' || p_instance_id);
      fnd_file.put_line(fnd_file.log, 'Success update instance - ' ||
                         p_instance_id);
      p_err_code := 0;
      p_err_msg  := 'Success update instance - ' || p_instance_id;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      l_msg_data := substr(SQLERRM, 1, 240);
      dbms_output.put_line('GEN Err update instance - ' || p_instance_id ||
                           '. Err: ' || substr(l_msg_data, 1, 240));
      fnd_file.put_line(fnd_file.log, 'GEN Err update instance - : ' ||
                         l_msg_data);
      p_err_code := 1;
      p_err_msg  := 'GEN Err update instance - ' || p_instance_id ||
                    '. Error: ' || substr(l_msg_data, 1, 240);
  END reverse_item_instance_api;

  --------------------------------------------------------------------
  --  name:            reverse_upgrade_item
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   17/04/2012
  --------------------------------------------------------------------
  --  purpose :        handle reverse instance to item before upgrade
  --                   This concurrent is needed for allowing the user to change item in the IB.
  --                   it allow the user to update an instance in the IB with deferent part number.
  --                   It will not affect any other parameters in the IB except the PN of the instance.
  --
  --  in param:        p_instance_id       - the instance to reverse upgrade
  --                   p_serial_number     - not allways exists
  --                   p_inventory_item_id - To Part number
  --
  --  out params:      errbuf              - null success others failed
  --                   retcode             - 0    success 1 failed
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  17/04/2012  Dalit A. Raviv  initial build
  --  1.1  21/07/2015  Michal Tzvik    CHG0035439 - replace hard code- 91 - with global variable
  --------------------------------------------------------------------
  PROCEDURE reverse_upgrade_item(errbuf              OUT VARCHAR2,
                                 retcode             OUT VARCHAR2,
                                 p_instance_id       IN NUMBER,
                                 p_serial_number     IN VARCHAR2,
                                 p_inventory_item_id IN NUMBER) IS
    -- To Part number

    l_sn_outside_store VARCHAR2(5) := 'N';
    l_serial_number    VARCHAR2(30) := NULL;
    l_exist_item_id    NUMBER := NULL;
    l_ovn              NUMBER := NULL;
    l_orig_item_cat    VARCHAR2(100) := NULL;
    l_reverse_item_cat VARCHAR2(100) := NULL;
    l_err_code         VARCHAR2(100) := 0;
    l_err_msg          VARCHAR2(2500) := NULL;
    l_item_revision    VARCHAR2(50) := NULL;

    general_exception EXCEPTION;
  BEGIN
    /*
    fnd_global.apps_initialize(user_id      => 2470,
                               resp_id      => 51137,
                               resp_appl_id => 514);
    */
    -- Validation
    -- 1) check serial number
    --    If the instance number is serial item (serial number is not null in the IB table),
    --    it should check if the serial number entered as parameter fits to the instance
    BEGIN
      SELECT cii.serial_number,
             cii.inventory_item_id,
             cii.object_version_number
      INTO   l_serial_number,
             l_exist_item_id,
             l_ovn
      FROM   csi_item_instances cii
      WHERE  cii.instance_id = p_instance_id;
    EXCEPTION
      WHEN OTHERS THEN
        fnd_message.set_name('XXOBJT', 'XXCSIB_INSTANCE_NOT_FOUND');
        errbuf  := fnd_message.get; --'did not find instance';
        retcode := 2;
        RAISE general_exception;
    END;

    IF (l_serial_number IS NOT NULL AND p_serial_number IS NULL) OR
       (l_serial_number IS NOT NULL AND p_serial_number <> l_serial_number) THEN

      fnd_message.set_name('XXOBJT', 'XXCSIB_SN_NOT_MATCH_INSTANCE');
      errbuf  := fnd_message.get;
      retcode := 2;
      RAISE general_exception;
    END IF;

    -- 2)  Check that the serial number is outside from store.
    IF p_serial_number IS NOT NULL THEN
      BEGIN
        /*       select 'Y'
        into   l_sn_outside_store
        from   mtl_serial_numbers msn
        where  msn.serial_number  = p_serial_number
        and    msn.current_status = 4;*/
        SELECT 'Y'
        INTO   l_sn_outside_store
        FROM   csi_item_instances cii
        WHERE  cii.serial_number = p_serial_number
        AND    cii.instance_id = p_instance_id
        AND    cii.accounting_class_code = 'CUST_PROD';

      EXCEPTION
        WHEN OTHERS THEN
          fnd_message.set_name('XXOBJT', 'XXCSIB_SN_NOT_OUTSIDE_STORE');
          errbuf  := fnd_message.get;
          retcode := 2;
          RAISE general_exception;
      END;
    END IF;

    -- 3) Check if the source item and the target item have the same category
    --    (printer to printer, water jet to water jet, hasp to hasp, head to head, part to part).
    --    need to check that the strings from source and target are the same.
    IF fnd_profile.value('XXCSIB_VALIDATE_UPDATE_ITEM') = 'Y' THEN
      l_orig_item_cat    := get_item_catagory(l_exist_item_id);
      l_reverse_item_cat := get_item_catagory(p_inventory_item_id);

      IF l_orig_item_cat <> l_reverse_item_cat THEN
        fnd_message.set_name('XXOBJT', 'XXCSIB_ITEM_CAT_NOT_MATCH');
        errbuf  := fnd_message.get;
        retcode := 2;
        RAISE general_exception;
      END IF;
    END IF;

    -- CAll APi to reverse item instance .

    l_item_revision := xxinv_utils_pkg.get_current_revision(p_inventory_item_id, g_master_organization_id); -- 1.1  21/07/2015  Michal Tzvik: replace hard code (91)
    reverse_item_instance_api(p_instance_id => p_instance_id, -- i n
                              p_inventory_item_id => p_inventory_item_id, -- i n
                              p_item_revision => l_item_revision, -- i v
                              p_ovn => l_ovn, -- i n
                              p_err_code => l_err_code, -- o v
                              p_err_msg => l_err_msg); -- o v

    IF l_err_code <> 0 THEN
      errbuf  := l_err_msg;
      retcode := 2;
      ROLLBACK;
      RAISE general_exception;
    ELSE
      errbuf  := l_err_msg;
      retcode := 0;
      COMMIT;
    END IF;

  EXCEPTION
    WHEN general_exception THEN
      NULL;
    WHEN OTHERS THEN
      NULL;
  END reverse_upgrade_item;

  --------------------------------------------------------------------
  --  name:            main_old
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/03/2011
  --------------------------------------------------------------------
  --  purpose :        Main process
  --  out params:      errbuf  - null success others failrd
  --                   retcode - 0    success 1 failed
  --  In Params:       p_instance_id
  --                   p_inventory_item_id
  --                   p_entity    - 'AUTO'   Automatic program
  --                               - 'MANUAL' Run Manual
  --                   p_hasp_sn
  --                   p_System_sn
  --                   p_user_name - fnd_user or PZ_INTF
  --                   p_SW_HW     - HW / SW_UPG / SW_NEW
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/03/2011  Dalit A. Raviv    initial build
  --  1.1  23/05/2011  Dalit A. Raviv    xxcs_sales_ug_items_v view field names changed
  --                                     add parameter user name , p_hasp_sn, p_SW_HW
  --                                     change select of the close SR
  --  1.2  15/03/2015  Adi Safin         CHG0034735 - change source table
  --                                     from csi_item_instances to xxsf_csi_item_instances
  --  1.3  16/07/2015  Michal Tzvik      CHG0035439 - change source table from xxsf_csi_item_instances to csi_item_instances
  --------------------------------------------------------------------
  PROCEDURE main_old(errbuf              OUT VARCHAR2,
                     retcode             OUT VARCHAR2,
                     p_entity            IN VARCHAR2, -- AUTO / MANUAL
                     p_instance_id       IN NUMBER,
                     p_inventory_item_id IN NUMBER,
                     p_hasp_sn           IN VARCHAR2 DEFAULT NULL,
                     --p_System_sn         in  varchar2 default null, -- to take off
                     p_user_name IN VARCHAR2 DEFAULT NULL,
                     p_sw_hw     IN VARCHAR2 DEFAULT 'HW') IS
    -- HW / SW_UPG / SW_NEW

    CURSOR get_old_instance_c IS
      SELECT ciab.customer_product_id old_instance_id,
             -- 23/05/2011 1.1 Dalit A. Raviv
             ug.upgrade_item_id upgrade_kit, -- old item_id to mapping table
             --
             ciab.close_date
      FROM   cs_incidents_all_b      ciab,
             cs_incident_statuses_tl cist,
             cs_incident_types_tl    citt,
             xxcs_sales_ug_items_v   ug,
             csi_item_instances      cii, --1.3  16/07/2015  Michal Tzvik:
             csi_instance_statuses   cis
      WHERE  ciab.incident_status_id = cist.incident_status_id
      AND    cist.language = 'US'
      AND    cist.name = 'Complete'
      AND    ciab.incident_type_id = citt.incident_type_id
      AND    citt.language = 'US'
      AND    citt.name = 'Upgrade'
            -- 23/05/2011 1.1 Dalit A. Raviv
      AND    ciab.external_attribute_8 = ug.upgrade_item_id --ug.inventory_item_id
            --
      AND    ciab.customer_product_id = cii.instance_id
      AND    cii.instance_status_id = cis.instance_status_id
            -- 23/05/2011 1.1 Dalit A. Raviv
      AND    ug.upgrade_item_id <> -999
      AND    NOT EXISTS
       (SELECT 1
              FROM   cs_incidents_all_b     cia,
                     cs_incident_statuses_b cis
              WHERE  cia.incident_status_id = cis.incident_status_id
              AND    cis.close_flag = 'N'
              AND    cia.customer_product_id = cii.instance_id --parent_old_instance_id
              )
            --and  ciab.customer_product_id   = 1763002 --1554000 --1432002
      AND    p_entity = 'AUTO'
      UNION
      SELECT p_instance_id old_instance_id,
             p_inventory_item_id upgrade_kit,
             trunc(SYSDATE) close_date
      FROM   dual
      WHERE  p_entity = 'MANUAL'
      AND    NOT EXISTS
       (SELECT 1
              FROM   cs_incidents_all_b     cia,
                     cs_incident_statuses_b cis
              WHERE  cia.incident_status_id = cis.incident_status_id
              AND    cis.close_flag = 'N'
              AND    cia.customer_product_id = p_instance_id --parent_old_instance_id
              );

    l_instance_rec     get_old_instance_c%ROWTYPE;
    l_err_code         VARCHAR2(1000);
    l_err_msg          VARCHAR2(2500);
    l_new_instance_id  NUMBER;
    l_new_item_id      NUMBER;
    l_old_instance_id  NUMBER;
    l_old_item_id      NUMBER;
    l_old_serial       VARCHAR2(100);
    l_log_rec          t_log_rec;
    l_item_is_hasp     VARCHAR2(20);
    l_old_hasp_ii      NUMBER;
    l_new_hasp_ii      NUMBER;
    l_new_hasp_item_id NUMBER;

    l_hasp_instance_id       NUMBER;
    l_hasp_inventory_item_id NUMBER;

    --l_upgrade_type     varchar2(100);
    l_upgrade_kit NUMBER;
    --l_old_hasp_instance_id number;
    l_parent_serial_number VARCHAR2(30) := NULL;

    instance_exception EXCEPTION;
    general_exception  EXCEPTION;

  BEGIN
  
    errbuf    := '';
    retcode   := 0;
    g_hasp_sn := p_hasp_sn;

    g_master_organization_id := xxinv_utils_pkg.get_master_organization_id;
    IF p_user_name IS NOT NULL THEN
      SELECT user_id
      INTO   g_user_id
      FROM   fnd_user
      WHERE  user_name = p_user_name; -- 'PZ_INTF'

      g_user_name := p_user_name;

      IF p_user_name = 'PZ_INTF' THEN
        fnd_global.apps_initialize(user_id => g_user_id, resp_id => 51137, resp_appl_id => 514);
      END IF;
    ELSE
      g_user_id := fnd_profile.value('USER_ID');
    END IF;
    IF p_sw_hw = 'HW' THEN
      FOR get_old_instance_r IN get_old_instance_c LOOP
        BEGIN
          -- 1) close contract (terminate)
          -------------------------------
          -- 2) create new item instance

          l_err_code        := NULL;
          l_err_msg         := NULL;
          l_new_instance_id := NULL;
          l_new_item_id     := NULL;
          l_old_instance_id := NULL;
          l_old_item_id     := NULL;
          l_old_serial      := NULL;
          l_instance_rec    := get_old_instance_r;
          l_item_is_hasp    := NULL;

          SELECT cii.last_vld_organization_id
          INTO   g_parent_organization_id
          FROM   csi_item_instances cii
          WHERE  cii.instance_id = get_old_instance_r.old_instance_id; -- p_instance_id

          create_item_instance(p_instance_rec => l_instance_rec, -- i t_instance_rec,
                               p_hasp_item => 'N', -- i v
                               p_old_instance_id => l_old_instance_id, -- o n this is the old upgrade instance
                               p_old_item_id => l_old_item_id, -- o n this is the old upgrade item
                               p_old_serial => l_old_serial, -- o v
                               p_new_instance_id => l_new_instance_id, -- o n this is the new upgrade instance
                               p_new_item_id => l_new_item_id, -- o n this is the new upgrade item
                               p_err_code => l_err_code, -- o v
                               p_err_msg => l_err_msg); -- o v

          IF l_err_code = 1 THEN
            IF errbuf IS NULL THEN
              errbuf := l_err_msg;
            ELSE
              errbuf := errbuf || ', ' || l_err_msg;
            END IF;
            retcode := 1;
            IF p_user_name <> 'PZ_INTF' THEN
              l_log_rec.status               := 'ERROR';
              l_log_rec.instance_id_old      := l_old_instance_id;
              l_log_rec.serial_number_old    := l_old_serial;
              l_log_rec.upgrade_type         := l_old_item_id;
              l_log_rec.instance_id_new      := l_new_instance_id;
              l_log_rec.hasp_instance_id_new := NULL;
              l_log_rec.msg_code             := 1;
              l_log_rec.msg_desc             := l_err_msg;
              handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                         p_err_code => l_err_code, -- o v
                         p_err_msg => l_err_msg); -- o v
            END IF;
            ROLLBACK;
            RAISE instance_exception;
          END IF;
          -- handle update instance for association
          update_item_instance(p_old_instance_id => l_old_instance_id, -- i n
                               p_new_instance_id => l_new_instance_id, -- I n
                               p_hasp_instance_id => NULL, -- i n
                               p_new_hasp_item_id => NULL, -- i n
                               p_upgrade_kit => NULL, -- i n
                               p_sw_hw => 'HW', -- i v
                               p_err_code => l_err_code, -- o v
                               p_err_msg => l_err_msg); -- o v

          IF l_err_code = 1 THEN
            IF errbuf IS NULL THEN
              errbuf := l_err_msg;
            ELSE
              errbuf := errbuf || ', ' || l_err_msg;
            END IF;
            retcode := 1;
            IF p_user_name <> 'PZ_INTF' THEN
              l_log_rec.status               := 'ERROR';
              l_log_rec.instance_id_old      := l_old_instance_id;
              l_log_rec.serial_number_old    := l_old_serial;
              l_log_rec.upgrade_type         := l_old_item_id;
              l_log_rec.instance_id_new      := l_new_instance_id;
              l_log_rec.hasp_instance_id_new := NULL;
              l_log_rec.msg_code             := 1;
              l_log_rec.msg_desc             := l_err_msg;
              handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                         p_err_code => l_err_code, -- o v
                         p_err_msg => l_err_msg); -- o v
            END IF;
          END IF;

          -- update ii bill_to and ship to
          -------------------------------
          -- 3) Handle item HASP
          -- cases: 1) upgrade instance have more then one HASP item at the relationship
          --           in this case function return DUP and finish with error
          --        2) upgrade instance have one HASP item at the relationship
          --           in this case function return HASP and create new instance for the
          --           HASP item.
          --        3) upgrade instance have no HASP item at the relationship
          --           in this case function return ITEM and we do not need to creat
          --           instance for HASP, only for the upgrade instance
          l_item_is_hasp := check_is_item_hasp(p_instance_id => l_instance_rec.old_instance_id);
          IF l_item_is_hasp = 'DUP' THEN
            IF errbuf IS NULL THEN
              errbuf := 'Item Instance Have more then one HASP items relate to';
            ELSE
              errbuf := errbuf || ', ' ||
                        'Item Instance Have more then one HASP items relate to';
            END IF;
            --errbuf  := 'Item Instance Have more then one HASP items relate to';
            retcode := 1;
            IF p_user_name <> 'PZ_INTF' THEN
              l_log_rec.status               := 'ERROR';
              l_log_rec.instance_id_old      := l_old_instance_id;
              l_log_rec.serial_number_old    := l_old_serial;
              l_log_rec.upgrade_type         := l_old_item_id;
              l_log_rec.instance_id_new      := l_new_instance_id;
              l_log_rec.hasp_instance_id_new := NULL;
              l_log_rec.msg_code             := 1;
              l_log_rec.msg_desc             := 'Item Instance Have more then one HASP items relate to';
              handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                         p_err_code => l_err_code, -- o v
                         p_err_msg => l_err_msg); -- o v
            END IF;
            ROLLBACK;
            RAISE instance_exception;
          ELSIF l_item_is_hasp = 'HASP' THEN
            -- 2) create new item instance
            l_err_code         := NULL;
            l_err_msg          := NULL;
            l_new_hasp_ii      := NULL;
            l_new_hasp_item_id := NULL;
            l_old_hasp_ii      := NULL;
            l_old_item_id      := NULL;
            l_old_serial       := NULL;
            l_instance_rec     := get_old_instance_r;
            l_item_is_hasp     := NULL;

            create_item_instance(p_instance_rec => l_instance_rec, -- i t_instance_rec,
                                 p_hasp_item => 'Y', -- i v
                                 p_old_instance_id => l_old_hasp_ii, -- o n  -- this is the old hasp instance
                                 p_old_item_id => l_old_item_id, -- o n  -- this is the old hasp item
                                 p_old_serial => l_old_serial, -- o v
                                 p_new_instance_id => l_new_hasp_ii, -- o n  -- this is the new hasp instance
                                 p_new_item_id => l_new_hasp_item_id, -- o n  -- this is the new hasp item
                                 p_err_code => l_err_code, -- o v
                                 p_err_msg => l_err_msg); -- o v

            IF l_err_code = 1 THEN
              errbuf  := l_err_msg;
              retcode := 1;
              IF p_user_name <> 'PZ_INTF' THEN
                l_log_rec.status               := 'ERROR';
                l_log_rec.instance_id_old      := l_old_instance_id;
                l_log_rec.serial_number_old    := l_old_serial;
                l_log_rec.upgrade_type         := l_old_item_id;
                l_log_rec.instance_id_new      := l_new_instance_id;
                l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
                l_log_rec.msg_code             := 1;
                l_log_rec.msg_desc             := l_err_msg;
                handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                           p_err_code => l_err_code, -- o v
                           p_err_msg => l_err_msg); -- o v
              END IF;
              ROLLBACK;
              RAISE instance_exception;
            END IF;

          ELSIF l_item_is_hasp = 'ITEM' THEN
            -- 2) create new item instance
            -- in this case there is no HASP item so i need to create new HASP item to the upgrade instance
            l_err_code         := NULL;
            l_err_msg          := NULL;
            l_new_hasp_ii      := NULL;
            l_new_hasp_item_id := NULL;
            l_old_hasp_ii      := NULL;
            l_old_item_id      := NULL;
            l_old_serial       := NULL;
            l_instance_rec     := get_old_instance_r;
            l_item_is_hasp     := NULL;

            create_item_instance(p_instance_rec => l_instance_rec, -- i t_instance_rec,
                                 p_hasp_item => 'NEW', -- i v
                                 p_old_instance_id => l_old_hasp_ii, -- o n  -- this is the old hasp instance
                                 p_old_item_id => l_old_item_id, -- o n  -- this is the old hasp item
                                 p_old_serial => l_old_serial, -- o v
                                 p_new_instance_id => l_new_hasp_ii, -- o n  -- this is the new hasp instance
                                 p_new_item_id => l_new_hasp_item_id, -- o n  -- this is the new hasp item
                                 p_err_code => l_err_code, -- o v
                                 p_err_msg => l_err_msg); -- o v

            IF l_err_code = 1 THEN
              errbuf  := l_err_msg;
              retcode := 1;
              IF p_user_name <> 'PZ_INTF' THEN
                l_log_rec.status               := 'ERROR';
                l_log_rec.instance_id_old      := l_old_instance_id;
                l_log_rec.serial_number_old    := l_old_serial;
                l_log_rec.upgrade_type         := l_old_item_id;
                l_log_rec.instance_id_new      := l_new_instance_id;
                l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
                l_log_rec.msg_code             := 1;
                l_log_rec.msg_desc             := l_err_msg;
                handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                           p_err_code => l_err_code, -- o v
                           p_err_msg => l_err_msg); -- o v
              END IF;
              ROLLBACK;
              RAISE instance_exception;
            END IF;
            -- to add handle of the return
            -- to remember to ask before create new relation if this is hasp
            -- so subject id will be new_hasp_ii_id
          END IF;
          -- 3) handle relationship -> close old one and create new realtionship for the new instance
          handle_relationship(p_old_instance_id => l_old_instance_id, -- i n
                              p_old_serial => l_old_serial, -- i v
                              p_old_item_id => l_old_item_id, -- i n
                              p_new_instance_id => l_new_instance_id, -- i n
                              p_new_hasp_ii => l_new_hasp_ii, -- i n
                              p_user_name => p_user_name, -- i v
                              p_msg_desc => l_err_msg, -- o v
                              p_msg_code => l_err_code); -- o v
          -- we do not want to stop program when relatioship have error

          -- i already enter row to log, and handle the rollback in the procedure
          -- 4)terminate old instance
          l_err_code := 0;
          l_err_msg  := NULL;
          -- handle close of old upgrade instance
          handle_close_old_instance(p_old_instance_id => l_old_instance_id, -- i n
                                    p_old_close_date => get_old_instance_r.close_date, -- i d
                                    p_upgrade_kit => get_old_instance_r.upgrade_kit, -- i n
                                    p_source => 'MAIN', -- i v
                                    p_msg_desc => l_err_msg, -- o v
                                    p_msg_code => l_err_code); -- o v

          IF l_err_code = 1 THEN
            ROLLBACK;
            errbuf  := l_err_msg;
            retcode := 1;
            IF p_user_name <> 'PZ_INTF' THEN
              l_log_rec.status               := 'ERROR';
              l_log_rec.instance_id_old      := l_old_instance_id;
              l_log_rec.serial_number_old    := l_old_serial;
              l_log_rec.upgrade_type         := l_old_item_id;
              l_log_rec.instance_id_new      := l_new_instance_id;
              l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
              l_log_rec.msg_code             := 1;
              l_log_rec.msg_desc             := l_err_msg;
              handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                         p_err_code => l_err_code, -- o v
                         p_err_msg => l_err_msg); -- o v
            END IF;
            RAISE instance_exception;
          END IF;

          -- Handle close of HASP instance
          IF l_old_hasp_ii IS NOT NULL THEN
            l_err_code := 0;
            l_err_msg  := NULL;
            -- handle close of old upgrade instance
            handle_close_old_instance(p_old_instance_id => l_old_hasp_ii, -- i n
                                      p_old_close_date => NULL, -- i d
                                      p_upgrade_kit => NULL, -- i n
                                      p_source => 'MAIN', -- i v
                                      p_msg_desc => l_err_msg, -- o v
                                      p_msg_code => l_err_code); -- o v
            IF l_err_code = 0 THEN
              COMMIT;
              errbuf  := 'SUCCESS';
              retcode := 0;
              IF p_user_name <> 'PZ_INTF' THEN
                l_log_rec.status               := 'SUCCESS';
                l_log_rec.instance_id_old      := l_old_instance_id;
                l_log_rec.serial_number_old    := l_old_serial;
                l_log_rec.upgrade_type         := l_old_item_id;
                l_log_rec.instance_id_new      := l_new_instance_id;
                l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
                l_log_rec.msg_code             := 1;
                l_log_rec.msg_desc             := l_err_msg;
                handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                           p_err_code => l_err_code, -- o v
                           p_err_msg => l_err_msg); -- o v
              END IF;
            ELSE
              ROLLBACK;
              errbuf  := l_err_msg;
              retcode := 1;
              IF p_user_name <> 'PZ_INTF' THEN
                l_log_rec.status               := 'ERROR';
                l_log_rec.instance_id_old      := l_old_instance_id;
                l_log_rec.serial_number_old    := l_old_serial;
                l_log_rec.upgrade_type         := l_old_item_id;
                l_log_rec.instance_id_new      := l_new_instance_id;
                l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
                l_log_rec.msg_code             := 1;
                l_log_rec.msg_desc             := 'HASP - old hasp ii - ' ||
                                                  l_old_hasp_ii || ', ' ||
                                                  l_err_msg;
                handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                           p_err_code => l_err_code, -- o v
                           p_err_msg => l_err_msg); -- o v
              END IF;
            END IF; -- api close old instance
          END IF; -- hasp close
        EXCEPTION
          WHEN instance_exception THEN
            NULL;
        END;
      END LOOP;
      --if retcode = 1 then
      --  errbuf := l_err_msg; --'At Least one instance did not create';
      --end if;
    ELSIF p_sw_hw = 'SW' THEN
      -- By the parent serial number look if there is an HASP item.
      -- Return the HASP instance id and Item Id if exists
      l_err_code := 0;
      l_err_msg  := NULL;
      BEGIN
        -- Get parent printer serial number
        SELECT cii.serial_number
        INTO   l_parent_serial_number
        FROM   csi_item_instances cii --1.3  16/07/2015  Michal Tzvik
        WHERE  cii.instance_id = p_instance_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_parent_serial_number := NULL;
      END;
      -- get hasp details
      get_sw_hasp_exist(p_old_instance_id => p_instance_id, -- i n
                        p_hasp_instance_id => l_hasp_instance_id, -- o n
                        p_hasp_inventory_item_id => l_hasp_inventory_item_id, -- o n
                        p_error_code => l_err_code, -- o v
                        p_error_desc => l_err_msg); -- o v

      IF l_err_code <> 0 THEN
        errbuf  := l_err_msg;
        retcode := 1;
        RAISE general_exception;
      END IF;

      l_err_code := 0;
      l_err_msg  := NULL;
      -- By the parent serial number get the upgrade kit(item id) that can change.
      -- Return the HASP Item Id if exists
      /*get_HASP_after_upgrade (p_upgrade_kit      => p_inventory_item_id,--i n  this is the upgrade kit
                              p_NEW_HASP_item_id => l_NEW_HASP_item_id, --o n
                              p_errr_code        => l_err_code,         --o v
                              p_errr_desc        => l_err_msg);        --o v
      */
      get_hasp_after_upgrade(p_upgrade_kit => p_inventory_item_id, -- i n
                             --p_old_instance_id           => p_instance_id,            -- i n
                             p_old_instance_item_id => l_old_item_id, -- i n
                             p_old_instance_hasp_item_id => l_hasp_inventory_item_id, -- i n
                             p_new_hasp_item_id => l_new_hasp_item_id, -- o n
                             p_err_code => l_err_code, -- o v
                             p_err_desc => l_err_msg); -- o v

      IF l_err_code <> 0 THEN
        retcode := 1;
        errbuf  := l_err_msg;
        RAISE general_exception;
      END IF;

      -- If Hasp item id that found attach to the old printer
      -- equal to the hasp item id from the upgrade kit
      -- only need to update the external attributes
      -- if not equal need to create new hasp to the upgrade printer.
      -- Upgrade of exists HASP
      IF l_hasp_inventory_item_id = l_new_hasp_item_id THEN
        l_err_code := 0;
        l_err_msg  := NULL;
        -- procedure that only update item instance and update the extnded attributes.
        update_item_instance(p_old_instance_id => NULL, -- i n
                             p_new_instance_id => NULL, -- i n
                             p_hasp_instance_id => l_hasp_instance_id, -- i n -> Hasp instance id
                             p_new_hasp_item_id => l_new_hasp_item_id, -- i n -> Hasp item id
                             p_upgrade_kit => p_inventory_item_id, -- i n -> this is parent upgrade kit
                             p_sw_hw => 'SW_UPG', -- i v
                             p_err_code => l_err_code, -- o v
                             p_err_msg => l_err_msg); -- o v

        IF l_err_code = 1 THEN
          errbuf  := l_err_msg;
          retcode := 1;
          IF p_user_name <> 'PZ_INTF' THEN
            l_log_rec.status               := 'ERROR';
            l_log_rec.instance_id_old      := p_instance_id;
            l_log_rec.serial_number_old    := l_parent_serial_number;
            l_log_rec.upgrade_type         := l_upgrade_kit;
            l_log_rec.instance_id_new      := NULL;
            l_log_rec.hasp_instance_id_new := p_instance_id;
            l_log_rec.msg_code             := 1;
            l_log_rec.msg_desc             := l_err_msg;
            handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                       p_err_code => l_err_code, -- o v
                       p_err_msg => l_err_msg); -- o v
          END IF;

          ROLLBACK;
          RAISE general_exception;
        ELSE
          COMMIT;
          errbuf  := 'Success update_item_instance with new external attributes';
          retcode := 0;
        END IF; -- error handle
      ELSE
        -- need to create new Hasp and new relationship
        l_instance_rec.old_instance_id := p_instance_id;
        l_instance_rec.upgrade_kit     := p_inventory_item_id;
        l_instance_rec.close_date      := NULL;

        -- set g_parent_organization_id
        SELECT cii.last_vld_organization_id
        INTO   g_parent_organization_id
        FROM   csi_item_instances cii
        WHERE  cii.instance_id = p_instance_id;

        -- get new HASP instance id
        create_item_instance(p_instance_rec => l_instance_rec, -- i t_instance_rec,
                             p_hasp_item => 'NEW', -- i v
                             p_old_instance_id => l_old_hasp_ii, -- o n  -- this is the old hasp instance
                             p_old_item_id => l_old_item_id, -- o n  -- this is the old hasp item
                             p_old_serial => l_old_serial, -- o v
                             p_new_instance_id => l_new_hasp_ii, -- o n  -- this is the new hasp instance
                             p_new_item_id => l_new_hasp_item_id, -- o n  -- this is the new hasp item
                             p_err_code => l_err_code, -- o v
                             p_err_msg => l_err_msg); -- o v

        IF l_err_code = 1 THEN
          errbuf  := l_err_msg;
          retcode := 1;
          IF p_user_name <> 'PZ_INTF' THEN
            l_log_rec.status               := 'ERROR';
            l_log_rec.instance_id_old      := p_instance_id;
            l_log_rec.serial_number_old    := l_old_serial;
            l_log_rec.upgrade_type         := p_inventory_item_id;
            l_log_rec.instance_id_new      := NULL;
            l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
            l_log_rec.msg_code             := 1;
            l_log_rec.msg_desc             := l_err_msg;
            handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                       p_err_code => l_err_code, -- o v
                       p_err_msg => l_err_msg); -- o v
          END IF;

          ROLLBACK;
          RAISE general_exception;
        ELSE
          -- create new relation between the parent printer(old)
          -- and the new HASP item.
          create_new_relationship(p_object_id => p_instance_id, -- i n
                                  p_relationship_type_code => 'COMPONENT-OF', -- i v
                                  p_subject_id => l_new_hasp_ii, -- i n
                                  p_position_reference => NULL, -- i v
                                  p_display_order => NULL, -- i n
                                  p_mandatory_flag => 'N', -- i v
                                  p_msg_desc => l_err_msg, -- o v
                                  p_msg_code => l_err_code); -- o v

          IF l_err_code = 1 THEN
            errbuf  := l_err_msg;
            retcode := 1;
            ROLLBACK;
            IF p_user_name <> 'PZ_INTF' THEN
              l_log_rec.status               := 'ERROR';
              l_log_rec.instance_id_old      := p_instance_id;
              l_log_rec.serial_number_old    := l_parent_serial_number;
              l_log_rec.upgrade_type         := p_inventory_item_id;
              l_log_rec.instance_id_new      := NULL;
              l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
              l_log_rec.msg_code             := 1;
              l_log_rec.msg_desc             := l_err_msg;

              handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                         p_err_code => l_err_code, -- o v
                         p_err_msg => l_err_msg); -- o v
            END IF;
          ELSE
            COMMIT;
            errbuf  := 'SUCCESS';
            retcode := 0;
            IF p_user_name <> 'PZ_INTF' THEN
              l_log_rec.status               := 'SUCCESS';
              l_log_rec.instance_id_old      := p_instance_id;
              l_log_rec.serial_number_old    := l_parent_serial_number;
              l_log_rec.upgrade_type         := p_inventory_item_id;
              l_log_rec.instance_id_new      := NULL;
              l_log_rec.hasp_instance_id_new := l_new_hasp_ii;
              l_log_rec.msg_code             := 1;
              l_log_rec.msg_desc             := l_err_msg;
              handle_log(p_log_rec => l_log_rec, -- i t_log_rec
                         p_err_code => l_err_code, -- o v
                         p_err_msg => l_err_msg); -- o v
            END IF;
          END IF; -- l_err_code
        END IF;
      END IF; -- 'SW_UPG'
    END IF; -- p_SW_HW = 'SW'

  EXCEPTION
    WHEN general_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 'GEN EXC - main - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
      dbms_output.put_line('GEN EXC - main - ' || substr(SQLERRM, 1, 240));
  END main_old;

  -----------------------------------------------------------------------------
  PROCEDURE test(p_instance_id        IN NUMBER,
                 p_inventory_item_id  IN NUMBER,
                 p_inventory_revision IN VARCHAR2,
                 p_err_code           OUT VARCHAR2,
                 p_err_msg            OUT VARCHAR2) IS

    l_instance_rec         csi_datastructures_pub.instance_rec;
    l_party_tbl            csi_datastructures_pub.party_tbl;
    l_account_tbl          csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl   csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl  csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl csi_datastructures_pub.instance_asset_tbl;
    l_txn_rec              csi_datastructures_pub.transaction_rec;
    l_ext_attrib_values    csi_datastructures_pub.extend_attrib_values_tbl;
    l_return_status        VARCHAR2(2000) := NULL;
    l_msg_count            NUMBER := NULL;
    l_msg_data             VARCHAR2(2000) := NULL;
    l_msg_index_out        NUMBER;
    l_instance_id_lst      csi_datastructures_pub.id_tbl;
    l_validation_level     NUMBER := NULL;
    l_ovn                  NUMBER := NULL;

  BEGIN
    SELECT MAX(cii.object_version_number)
    INTO   l_ovn
    FROM   csi_item_instances cii
    WHERE  cii.instance_id = p_instance_id; -- 2217001

    l_instance_rec.instance_id           := p_instance_id; -- 2217001
    l_instance_rec.object_version_number := l_ovn;

    l_instance_rec.inventory_item_id  := p_inventory_item_id; -- 298002;
    l_instance_rec.inventory_revision := p_inventory_revision; -- 'A';

    l_txn_rec.transaction_date        := SYSDATE;
    l_txn_rec.source_transaction_date := SYSDATE;
    l_txn_rec.transaction_type_id     := 205; --1;
    l_txn_rec.object_version_number   := 1;

    csi_item_instance_pub.update_item_instance(p_api_version => 1, p_commit => 'F', p_init_msg_list => 'T', p_validation_level => l_validation_level, p_instance_rec => l_instance_rec, p_ext_attrib_values_tbl => l_ext_attrib_values, p_party_tbl => l_party_tbl, p_account_tbl => l_account_tbl, p_pricing_attrib_tbl => l_pricing_attrib_tbl, p_org_assignments_tbl => l_org_assignments_tbl, p_asset_assignment_tbl => l_asset_assignment_tbl, p_txn_rec => l_txn_rec, x_instance_id_lst => l_instance_id_lst, x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data);
    IF l_return_status != apps.fnd_api.g_ret_sts_success THEN
      -- 'S'
      fnd_msg_pub.get(p_msg_index => -1, p_encoded => 'F', p_data => l_msg_data, p_msg_index_out => l_msg_index_out);

      dbms_output.put_line('Error Close old instance - ' || p_instance_id ||
                           '. Error: ' || substr(l_msg_data, 1, 240));
      p_err_code := 1;
      p_err_msg  := 'Error Close old instance - ' || p_instance_id ||
                    '. Error: ' || substr(l_msg_data, 1, 240);
    ELSE
      dbms_output.put_line('Success Close old instance - ' ||
                           p_instance_id);
      p_err_code := 0;
      p_err_msg  := 'Success Close old instance - ' || p_instance_id;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('GEN Error Close old instance - ' ||
                           p_instance_id || '. Error: ' ||
                           substr(l_msg_data, 1, 240));
      p_err_code := 1;
      p_err_msg  := 'GEN Error Close old instance - ' || p_instance_id ||
                    '. Error: ' || substr(l_msg_data, 1, 240);
  END;

END xxcsi_ib_auto_upgrade_pkg;
/
