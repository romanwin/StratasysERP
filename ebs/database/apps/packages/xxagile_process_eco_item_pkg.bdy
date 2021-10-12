CREATE OR REPLACE PACKAGE BODY xxagile_process_eco_item_pkg IS
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08.08.13     yuval tal         cr811 : modify process_eco_item

  /********************************************************************************************
   AudioCodes LTd.
   Package Name : XXAGILE_PROCESS_ECO_ITEM_PKG
   Description : Wrapper package containing all ECO item record creation / modification
   Written by : Vinay Chappidi
   Date : 26-Dec-2007
  
   Change History
   ==============
   Date         Name              Ver       Change Description
   -----        ---------------   --------  ----------------------------------
   26-Dec-2007  Vinay Chappidi    DRAFT1A   Created this package, Initial Version
  ********************************************************************************************/

  -- package body level fndlog variable for getting the current runtime level
  gn_debug_level CONSTANT NUMBER := fnd_log.g_current_runtime_level;
  gv_module_name CONSTANT VARCHAR2(50) := 'Process_Item_Interface';
  gv_pkg_name    CONSTANT VARCHAR2(50) := 'XXAGILE_PROCESS_ECO_ITEM_PKG';
  gv_level       CONSTANT VARCHAR2(240) := fnd_log.level_statement;
  gv_error_text VARCHAR2(2000);

  /********************************************************************************************
  AudioCodes LTd.
  Procedure Name : write_to_log
  Description : procedure will log messages to fnd_log_messages table when logging is enabled
  Written by : Vinay Chappidi
  Date : 05-Dec-2007
  ********************************************************************************************/
  PROCEDURE write_to_log(p_module IN VARCHAR2, p_msg IN VARCHAR2) IS
  BEGIN
    IF (gv_level >= gn_debug_level) THEN
      fnd_log.string(gv_level, gv_module_name || '.' || p_module, p_msg);
    END IF;
  END write_to_log;

  /********************************************************************************************
  AudioCodes LTd.
  Procedure Name : add_error_text
  Description : procedure will
  Written by : Vinay Chappidi
  Date : 05-Dec-2007
  ********************************************************************************************/
  PROCEDURE add_error_text(p_error_text IN VARCHAR2) IS
    n_gerror_length NUMBER;
    n_error_length  NUMBER;
  BEGIN
    n_gerror_length := nvl(length(gv_error_text), 0);
    n_error_length  := nvl(length(p_error_text), 0);
  
    IF (n_gerror_length < 2000) THEN
      IF (((2000 - n_gerror_length) - 1) >= n_error_length) THEN
        IF (gv_error_text IS NULL) THEN
          gv_error_text := p_error_text;
        ELSE
          gv_error_text := gv_error_text || ' ' || p_error_text;
        END IF;
      
      ELSE
        gv_error_text := gv_error_text || ' ' ||
                         substr(p_error_text,
                                1,
                                (2000 - n_gerror_length) - 1);
      END IF;
    END IF;
    --      --autonomous_proc.dump_temp('Returning Error Message: '||gv_error_text);
  END add_error_text;

  /********************************************************************************************
  AudioCodes LTd.
  Procedure Name : process_eco_item
  Description : procedure will create or update Engineering Change Order
  Written by : Vinay Chappidi
  Date : 26-Dec-2007
  ********************************************************************************************/
  /* procedure process_eco_item(p_eco_number           IN varchar2, -- varchar2(10)
                               p_change_type_code     IN varchar2, -- varchar2(30)
                               p_assembly             IN varchar2, -- varchar2(240)
                               p_new_assembly_itm_rev IN varchar2, -- varchar2(3)
                               p_old_assembly_itm_rev IN varchar2, -- varchar2(3)
                               p_effective_date       IN date, -- effective date for the revised item and components
                               p_old_effective_date   IN date, -- needed for update or delete
                               p_components_tbl       IN ltab_components_type,
                               p_requestor            IN varchar2, -- (Shay: not used, replaced by v_requestor)
                               p_owner_organization   IN varchar2, -- varchar2(240)
                               p_creation_dt          IN date,
                               p_created_by           IN number,
                               p_last_updated_dt      IN date,
                               p_last_update_by       IN number,
                               x_return_status        OUT NOCOPY varchar2,
                               x_error_code           OUT NOCOPY number,
                               x_msg_count            OUT NOCOPY number,
                               x_msg_data             OUT NOCOPY varchar2,
                               p_ecn_initiation_date  IN date) is
  
      cursor lcu_get_inv_orgs(cp_org_id IN number, cp_org_context IN varchar2) is
        select '1' order_by_col,
               hoi.org_information3 operating_unit_id,
               haou.organization_id inventory_org_id,
               mp.organization_code inventory_org_code,
               mp.master_organization_id master_organization_id,
               haou.name inventory_organization_name,
             '' operating_unit_name
          from hr_organization_information hoi,
               hr_all_organization_units   haou,
               mtl_parameters              mp
         where haou.organization_id = hoi.organization_id
           and hoi.org_information_context = cp_org_context --'Accounting Information'
           and sysdate between haou.date_from and nvl(haou.date_to, sysdate)
           and mp.organization_id = haou.organization_id
           and exists
         (select 'x'
                  from mtl_parameters
                 where organization_id = haou.organization_id
                   and organization_id = master_organization_id);
      -- start Union all remove by amir 20/1/08 for common bill logic
      \*UNION ALL
      select '2' order_by_col,
       hoi.org_information3 operating_unit_id,
             haou.organization_id inventory_org_id,
             mp.organization_code inventory_org_code,
             mp.master_organization_id master_organization_id,
             haou.name inventory_organization_name,
             haou1.name operating_unit_name
      from hr_organization_information hoi,
           hr_all_organization_units   haou,
           mtl_parameters              mp,
           hr_all_organization_units   haou1
      where haou.organization_id = hoi.organization_id
      and hoi.org_information_context = cp_org_context -- 'Accounting Information'
      and sysdate between haou.date_from and nvl(haou.date_to, sysdate)
      and mp.organization_id = haou.organization_id
      and haou1.organization_id = hoi.org_information3
      and ((haou1.organization_id = cp_org_id and cp_org_id is not null)
           or (cp_org_id is null))
      and haou.organization_id <> mp.master_organization_id -- not selecting the master inventory org from this loop
      order by order_by_col;*\
      --end remove
      lr_get_inv_orgs lcu_get_inv_orgs%ROWTYPE;
  
      -- get the opetaing unit id for the provided operating unit name
      cursor lcu_get_org_id(cp_org_name IN varchar2) is
        select organization_id operating_unit_id
          from hr_all_organization_units
         where name = cp_org_name;
      n_org_id number;
  
      cursor lr_get_inv_id is
      select distinct msib.inventory_item_id from mtl_system_items_b msib
      where segment1 = p_assembly;
  
      cursor lr_get_bom_item_type (l_assembly IN varchar2, l_organization_id  IN number) is
      select  msib.bom_item_type from mtl_system_items_b msib
      where segment1 = l_assembly
      and msib.organization_id=l_organization_id;
  
      l_bom_item_type number;
      -- get user name of requestor
      cursor lr_get_requestor_user_name (cp_user_id IN number) is
      select user_name
      from fnd_user
      where user_id = cp_user_id;
  
  
      -- cursor to get the old effective date of the revised item from the
      -- latest ECO
      cursor lcu_old_eff_dt(cp_revised_item IN varchar2, cp_organization_id IN number, cp_status_type IN number) is
        select MAX(eri.scheduled_date)
          from eng_revised_items eri, mtl_system_items msi
         where eri.revised_item_id = msi.inventory_item_id
           and eri.organization_id = msi.organization_id
           and msi.segment1 = cp_revised_item
           and eri.organization_id = cp_organization_id
           and eri.status_type > cp_status_type;
  
  \*  cursor lcu_comp_old_eff_dt(cp_comp_name in varchar2, cp_revised_item IN varchar2, cp_organization_id IN number, cp_status_type IN number) is
        select max(ercv.effectivity_date), max(ercv.operation_sequence_num)
        from ENG_REVISED_COMPONENTS ercv ,mtl_system_items_b msi2
        where ercv.component_item_id = msi2.inventory_item_id
          and msi2.segment1 =  cp_comp_name
           and msi2.organization_id = cp_organization_id
          and ercv.revised_item_sequence_id = (
            select max(eri1.revised_item_sequence_id)
            from  eng_revised_items eri1, mtl_system_items msi1
            where eri1.revised_item_id = msi1.inventory_item_id
              and eri1.organization_id = msi1.organization_id
              and msi1.segment1 = cp_revised_item
              and eri1.organization_id = cp_organization_id
               and eri1.status_type > cp_status_type
              );  *\
  
         cursor lcu_comp_old_eff_dt(cp_comp_name in varchar2, cp_revised_item IN varchar2, cp_organization_id IN number, cp_status_type IN number) is
                SELECT bic.effectivity_date, bic.OPERATION_SEQ_NUM
                FROM   bom_bill_of_materials       bbom,
                       bom_inventory_components    bic,
                       mtl_system_items_b          msi_as,
                       mtl_system_items_b          msi_co
                WHERE  msi_as.segment1 = cp_revised_item  --msi_as.inventory_item_id=9606
                AND  msi_co.segment1 = cp_comp_name
                AND  bic.bill_sequence_id = bbom.bill_sequence_id
                AND   bbom.organization_id=cp_organization_id
                AND    msi_as.inventory_item_id = bbom.assembly_item_id
                AND    msi_as.organization_id = cp_organization_id
                AND    msi_co.inventory_item_id = bic.component_item_id
                AND    msi_co.organization_id = cp_organization_id
                AND    nvl(bic.disable_date,SYSDATE+1) >SYSDATE
                and msi_as.attribute14='Y'
                and bic.IMPLEMENTATION_DATE is not null  -- Need to verify this condition doesnt return records
                and  bbom.ALTERNATE_BOM_DESIGNATOR is  null;  --There are 2 alternate bom in the system
  
  
  \*     select max(ercv.effectivity_date), max(ercv.component_sequence_id)
        from eng_revised_components_v ercv ,mtl_system_items_b msi2
        where ercv.component_item_id = msi2.inventory_item_id
          and msi2.segment1 = cp_comp_name
          and msi2.organization_id = cp_organization_id
          and ercv.revised_item_sequence_id = (
            select eri1.revised_item_sequence_id
            from  eng_revised_items eri1, mtl_system_items msi1
            where eri1.revised_item_id = msi1.inventory_item_id
              and eri1.organization_id = msi1.organization_id
              and msi1.segment1 = cp_revised_item
              and eri1.organization_id = cp_organization_id
              and eri1.status_type > cp_status_type
              and eri1.scheduled_date=(
                select MAX(eri.scheduled_date)
                from eng_revised_items eri, mtl_system_items msi
                  where eri.revised_item_id = msi.inventory_item_id
                    and eri.organization_id = msi.organization_id
                    and msi.segment1 = cp_revised_item
                    and eri.organization_id = cp_organization_id
                    and eri.status_type > cp_status_type));*\
         --amirt 30/01/08
  
          cursor lcu_comp_old_ref_desg( cp_revised_item IN varchar2, cp_organization_id IN number,cp_comp_name in varchar2) is
                SELECT brd.component_reference_designator,bic.effectivity_date, bic.OPERATION_SEQ_NUM,
                brd.acd_type, bbom.ALTERNATE_BOM_DESIGNATOR
                FROM   bom_bill_of_materials       bbom,
                       bom_inventory_components    bic,
                       BOM_REFERENCE_DESIGNATORS brd,
                       mtl_system_items_b          msi_as,
                       mtl_system_items_b          msi_co
                WHERE  msi_as.segment1 = cp_revised_item  --msi_as.inventory_item_id=9606
                AND  msi_co.segment1 = cp_comp_name
                AND  bic.bill_sequence_id = bbom.bill_sequence_id
                AND   bbom.organization_id=cp_organization_id
                AND    msi_as.inventory_item_id = bbom.assembly_item_id
                AND    msi_as.organization_id = cp_organization_id
                AND    msi_co.inventory_item_id = bic.component_item_id
                AND    msi_co.organization_id = cp_organization_id
                AND    nvl(bic.disable_date,SYSDATE+1) >SYSDATE
                and bic.component_sequence_id =BRD.Component_Sequence_Id
                and msi_as.attribute14='Y'
                and bic.IMPLEMENTATION_DATE is not null  -- Need to verify this condition doesnt return records
                and  bbom.ALTERNATE_BOM_DESIGNATOR is  null;  --There are 2 alternate bom in the system
  \*
         select  brd.component_reference_designator,ercv.operation_sequence_num,ercv.effectivity_date
        from ENG_REVISED_COMPONENTS ercv ,mtl_system_items_b msi2, BOM_REFERENCE_DESIGNATORS BRD
        where ercv.component_item_id = msi2.inventory_item_id
          and msi2.segment1 =  cp_comp_name
          and msi2.organization_id = cp_organization_id
          and brd.acd_type <>3
          and brd.change_notice = cp_eco_name
          and ercv.component_sequence_id =BRD.Component_Sequence_Id;
      *\
      d_ref_diseg varchar2(15);
      d_schedule_dt date;
      d_comp_seq_num number;
  
      v_item_org_assign_profile fnd_profile_option_values.profile_option_value%TYPE;
      n_api_input_org_id        number;
  
      n_api_version    number := 1.0;
      b_init_msg       boolean := true;
      v_return_status  varchar2(10);
      n_msg_count      number := 0;
      v_bo_identifier  varchar2(10) := 'ECO';
      v_debug          varchar2(1) := 'Y';
      v_output_dir     varchar2(240) := '/usr/tmp';
      v_debug_filename varchar2(80) := 'a2o_eco_debug_1.log';
  
      v_transaction_type varchar2(10) := 'CREATE';
  
      -- variable for requestor user name
      v_requestor varchar2(100);
  
      lr_eco_rec       ENG_ECO_PUB.eco_rec_type;
      xr_eco_rec       ENG_ECO_PUB.eco_rec_type;
      lr_eco_dummy_rec ENG_ECO_PUB.eco_rec_type;
  
      lt_eco_rev_tbl       ENG_ECO_PUB.eco_revision_tbl_type;
      xt_eco_rev_tbl       ENG_ECO_PUB.eco_revision_tbl_type;
      lt_eco_rev_dummy_tbl ENG_ECO_PUB.eco_revision_tbl_type;
  
      lt_revised_item_tbl       ENG_ECO_PUB.revised_item_tbl_type;
      xt_revised_item_tbl       ENG_ECO_PUB.revised_item_tbl_type;
      lt_revised_item_dummy_tbl ENG_ECO_PUB.revised_item_tbl_type;
  
      lt_rev_component_tbl       BOM_BO_PUB.rev_component_tbl_type;
      xt_rev_component_tbl       BOM_BO_PUB.rev_component_tbl_type;
      lt_rev_component_dummy_tbl BOM_BO_PUB.rev_component_tbl_type;
  
      lt_ref_designator_tbl       BOM_BO_PUB.ref_designator_tbl_type;
      lt_bom_ref_designator_tbl       BOM_BO_PUB.Bom_Ref_Designator_Tbl_type;
      xt_ref_designator_tbl       BOM_BO_PUB.ref_designator_tbl_type;
      lt_ref_designator_dummy_tbl BOM_BO_PUB.ref_designator_tbl_type;
  
      lt_sub_component_tbl       BOM_BO_PUB.sub_component_tbl_type;
      xt_sub_component_tbl       BOM_BO_PUB.sub_component_tbl_type;
      lt_sub_component_dummy_tbl BOM_BO_PUB.sub_component_tbl_type;
  
      lt_rev_operation_tbl       BOM_RTG_PUB.rev_operation_tbl_type;
      xt_rev_operation_tbl       BOM_RTG_PUB.rev_operation_tbl_type;
      lt_rev_operation_dummy_tbl BOM_RTG_PUB.rev_operation_tbl_type;
  
      lt_rev_op_resource_tbl       BOM_RTG_PUB.rev_op_resource_tbl_type;
      xt_rev_op_resource_tbl       BOM_RTG_PUB.rev_op_resource_tbl_type;
      lt_rev_op_resource_dummy_tbl BOM_RTG_PUB.rev_op_resource_tbl_type;
  
      lt_rev_sub_resource_tbl       BOM_RTG_PUB.rev_sub_resource_tbl_type;
      xt_rev_sub_resource_tbl       BOM_RTG_PUB.rev_sub_resource_tbl_type;
      lt_rev_sub_resource_dummy_tbl BOM_RTG_PUB.rev_sub_resource_tbl_type;
  
      n_des_count          number := 1;
      n_del_des_count          number := 1;
      n_user_id            number := 0;
      tbl_error_type       ERROR_HANDLER.error_tbl_type;
      tbl_error_type_dummy ERROR_HANDLER.error_tbl_type;
  
      l_exception exception;
      l_item_creation_exception exception;
  
      d_effective_date date;
      --add by amir 22/1/08
      l_str       varchar2(15);
      l_seperator varchar2(1) := ',';
      l_len       number := 0;
      l_comma_cnt number := 0;
      l_pos       number;
      p_str       varchar2(4000);
  
  
      p_bom_header_tbl        Bom_Bo_Pub.Bom_Header_Tbl_Type :=  Bom_Bo_PUB.G_MISS_BOM_HEADER_TBL;
      p_bom_revision_tbl        Bom_Bo_PUB.Bom_Revision_Tbl_Type  := Bom_Bo_PUB.G_MISS_BOM_REVISION_TBL;
      p_bom_component_tbl        Bom_Bo_Pub.Bom_Comps_Tbl_Type := Bom_Bo_PUB.G_MISS_BOM_COMPONENT_TBL ;
      p_bom_sub_component_tbl    Bom_Bo_Pub.Bom_Sub_Component_Tbl_Type := Bom_Bo_PUB.G_MISS_BOM_SUB_COMPONENT_TBL;
      p_bom_comp_ops_tbl        Bom_Bo_Pub.Bom_Comp_Ops_Tbl_Type :=  Bom_Bo_PUB.G_MISS_BOM_COMP_OPS_TBL;
  
     x_bom_header_tbl             Bom_Bo_Pub.Bom_Header_Tbl_Type ;
     x_bom_revision_tbl            Bom_Bo_PUB.Bom_Revision_Tbl_Type;
     x_bom_component_tbl          Bom_Bo_Pub.Bom_Comps_Tbl_Type;
     x_bom_ref_designator_tbl     Bom_Bo_Pub.Bom_Ref_Designator_Tbl_Type;
     x_bom_sub_component_tbl       Bom_Bo_Pub.Bom_Sub_Component_Tbl_Type;
     x_bom_comp_ops_tbl           Bom_Bo_Pub.Bom_Comp_Ops_Tbl_Type;
  
     is_desig_del boolean :=false;
    begin
  
  
    --  execute immediate  'alter session set events=''10046 trace name context forever, level  12''';
  
  --dbms_support.start_trace(waits=>true, binds=>true);
      -- initialize this package level variable it will comtain previous error messages when this is not initialized
      gv_error_text := null;
  
      -- check if this procedure is invoked for new item creation or modification
      -- change the user accordingly
      n_user_id := nvl(p_created_by, nvl(p_last_update_by, 0));
  
      write_to_log('process_eco', 'User ID :' || n_user_id);
      --autonomous_proc.dump_temp('User ID :' || n_user_id);
  
      -- set the apps context for the user
      --        FND_GLOBAL.apps_initialize(n_user_id,0,0);
  
      --
  
      open lr_get_requestor_user_name (n_user_id);
      fetch lr_get_requestor_user_name
      into v_requestor;
      close lr_get_requestor_user_name;
  
      open lcu_get_org_id(p_owner_organization);
      fetch lcu_get_org_id
        INTO n_org_id;
      close lcu_get_org_id;
  
      --autonomous_proc.dump_temp('Operating Unit ID :' || n_org_id);
  
      -- check if the operating unit id could be determined
      -- incase it is null then assign error message to the out parameter and
      -- raise exception
      if (n_org_id is null) then
        fnd_message.set_name('ACCST', 'AC_CST_A2O_INVALID_OU');
        fnd_message.set_token('OU_NAME', p_owner_organization);
        raise l_exception;
      end if;
  
      -- get the value of the system profile ACCST_AGILE_ITEM_ORG_ASSIG
      -- this profile value is set at the org level, 10006 is hardcoded to get the value at the Org level
  
      v_item_org_assign_profile := FND_PROFILE.value_specific(org_id => n_org_id,
                                                              name   => 'AC_AGILE_ITEM_ORG_ASSIG');
  
      write_to_log('process_item',
                   'Profile Value :' || v_item_org_assign_profile ||
                   ' is set for Organization ID:' || n_org_id);
  
      --autonomous_proc.dump_temp('Profile Value :' ||
                                v_item_org_assign_profile ||
                                ' is set for Organization ID:' || n_org_id);
  
      -- check the profile value, if it is null then the current item will be assigned to
      -- all inventory organizations.
      --begin delete by amir 20/01/08
      \* if (nvl(v_item_org_assign_profile,'ALL') = 'OU') then
          n_api_input_org_id := n_org_id;
      else
          n_api_input_org_id := null;
      end if;*\
      --end
      --begin add by amir 20/01/08
      n_api_input_org_id := n_org_id;
      --end
      --autonomous_proc.dump_temp('1 , n_api_input_org_id: ' ||
                                n_api_input_org_id);
  
      open lcu_get_inv_orgs(n_api_input_org_id, 'Accounting Information');
      loop
        fetch lcu_get_inv_orgs
          into lr_get_inv_orgs;
        exit when lcu_get_inv_orgs%NOTFOUND;
  
        -- initialize loop variables
        lr_eco_rec := lr_eco_dummy_rec;
        xr_eco_rec := lr_eco_dummy_rec;
  
        lt_eco_rev_tbl := lt_eco_rev_dummy_tbl;
        xt_eco_rev_tbl := lt_eco_rev_dummy_tbl;
  
        lt_revised_item_tbl := lt_revised_item_dummy_tbl;
        xt_revised_item_tbl := lt_revised_item_dummy_tbl;
  
        lt_rev_component_tbl := lt_rev_component_dummy_tbl;
        xt_rev_component_tbl := lt_rev_component_dummy_tbl;
  
        lt_ref_designator_tbl := lt_ref_designator_dummy_tbl;
        xt_ref_designator_tbl := lt_ref_designator_dummy_tbl;
  
        lt_sub_component_tbl := lt_sub_component_dummy_tbl;
        xt_sub_component_tbl := lt_sub_component_dummy_tbl;
  
        lt_rev_operation_tbl := lt_rev_operation_dummy_tbl;
        xt_rev_operation_tbl := lt_rev_operation_dummy_tbl;
  
        lt_rev_op_resource_tbl := lt_rev_op_resource_dummy_tbl;
        xt_rev_op_resource_tbl := lt_rev_op_resource_dummy_tbl;
  
        lt_rev_sub_resource_tbl := lt_rev_sub_resource_dummy_tbl;
        xt_rev_sub_resource_tbl := lt_rev_sub_resource_dummy_tbl;
        n_des_count             := 1;
  
        if (p_effective_date is null or p_effective_date < sysdate) then
          d_effective_date := sysdate;
        else
          d_effective_date := p_effective_date; -- this is for future dated effectivity
        end if;
  
        --autonomous_proc.dump_temp('2');
        -- assigning the eco rec type details
        lr_eco_rec.eco_name             := p_eco_number;
        lr_eco_rec.requestor            := v_requestor; -- should be employee number
        lr_eco_rec.organization_code    := lr_get_inv_orgs.inventory_org_code;
        lr_eco_rec.transaction_type     := v_transaction_type;
        lr_eco_rec.change_type_code     := p_change_type_code;
        lr_eco_rec.approval_status_name := 'Approved'; -- check this value
        lr_eco_rec.status_name          := 'Scheduled';
        lr_eco_rec.plm_or_erp_change    := 'PLM';
        --autonomous_proc.dump_temp('3');
  
        -- from the api documentation
        -- The New_Revised_Item_Revision is not updateable for revised items since it is part of the unique key
        -- which uniquely identifies a record. So, updates to it have to be made by entering the new revision
        -- into Updated_Revised_Item_Revision. After the record is retrieved using the unique key, its revision is overwritten by the new value.
        -- Just like New_Revised_Item_Revision, Start_Effective_Date is a unique index column. So changes to it have to be made by entering
        -- the new value into New_Effective_Date.
  
        lt_revised_item_tbl(1).eco_name := p_eco_number;
        lt_revised_item_tbl(1).organization_code := lr_get_inv_orgs.inventory_org_code;
        lt_revised_item_tbl(1).revised_item_name := p_assembly;
        lt_revised_item_tbl(1).new_revised_item_revision := substr(p_new_assembly_itm_rev,
                                                                   1,
                                                                   3);
  
        lt_revised_item_tbl(1).start_effective_date := d_effective_date;
  
        lt_revised_item_tbl(1).requestor := v_requestor;
        lt_revised_item_tbl(1).transaction_type := v_transaction_type;
        lt_revised_item_tbl(1).create_bom_in_local_org := 'N'; -- check this value
        lt_revised_item_tbl(1).change_management_type := 'CHANGE_ORDER'; -- this is the default value
  
        lt_revised_item_tbl(1).status_type := 4; -- to make it into scheduled state for auto implement
  
        --autonomous_proc.dump_temp('4');
        if (p_components_tbl.EXISTS(p_components_tbl.first)) then
          for cnt in p_components_tbl.first .. p_components_tbl.last loop
  
            open lr_get_bom_item_type (p_assembly,lr_get_inv_orgs.master_organization_id);
            fetch lr_get_bom_item_type into l_bom_item_type;
            close lr_get_bom_item_type;
  
            --autonomous_proc.dump_temp(' l_bom_item_type='||l_bom_item_type);
            --autonomous_proc.dump_temp(' p_assembly='||p_assembly);
            --autonomous_proc.dump_temp(' n_org_id='||n_org_id);
  
            if l_bom_item_type in (2,1) then
              lt_rev_component_tbl(cnt).Optional :=1;
            end if;
  
  \*  IF p_components_tbl(cnt).p_acd_flag = 2 THEN
      v_transaction_type := 'UPDATE';
    END IF;
            *\
            --autonomous_proc.dump_temp('Adding Component');
  
            -- assigning component details
            lt_rev_component_tbl(cnt).eco_name := p_eco_number;
            lt_rev_component_tbl(cnt).organization_code := lr_get_inv_orgs.inventory_org_code;
            lt_rev_component_tbl(cnt).revised_item_name := p_assembly;
            lt_rev_component_tbl(cnt).new_revised_item_revision := substr(p_new_assembly_itm_rev,
                                                                          1,
                                                                          3);
  
            -- in this case revised item which is created with earlier could not be found
            lt_rev_component_tbl(cnt).start_effective_date := d_effective_date;
            lt_rev_component_tbl(cnt).new_effectivity_date := d_effective_date;
            lt_rev_component_tbl(cnt).component_item_name := p_components_tbl(cnt)
                                                            .p_component;
  
            --autonomous_proc.dump_temp(cnt || ' p_component_seq_num='||p_components_tbl(cnt)
                                                 .p_component_seq_num);
            --autonomous_proc.dump_temp(cnt || ' p_component='||p_components_tbl(cnt)
                                                 .p_component);
            --autonomous_proc.dump_temp(cnt || ' p_component_qty='||p_components_tbl(cnt)
                                                 .p_component_qty);
  
            --autonomous_proc.dump_temp(cnt || ' p_balloon='||p_components_tbl(cnt)
                                                 .p_balloon);
            --autonomous_proc.dump_temp(cnt || ' p_comments='||p_components_tbl(cnt)
                                                 .p_comments);
            --autonomous_proc.dump_temp(cnt || ' p_acd_flag='||p_components_tbl(cnt)
                                                 .p_acd_flag);
            --autonomous_proc.dump_temp(cnt || ' p_disable_date='||p_components_tbl(cnt)
                                                 .p_disable_date);
  
  
            lt_rev_component_tbl(cnt).acd_type := p_components_tbl(cnt)
                                                 .p_acd_flag;
  
            if (lt_rev_component_tbl(cnt).acd_type <> 1) then
  
              d_schedule_dt := null;
              d_comp_seq_num := null;
  
              -- get the old effective date from the database
              \*open lcu_old_eff_dt(p_assembly,
                                  lr_get_inv_orgs.inventory_org_id,
                                  4); -- 4 is for scheduled status
              fetch lcu_old_eff_dt
                into d_schedule_dt;
              close lcu_old_eff_dt;*\
  
              open lcu_comp_old_eff_dt (p_components_tbl(cnt).p_component, p_assembly, lr_get_inv_orgs.inventory_org_id, 4);
  
              fetch lcu_comp_old_eff_dt
              into d_schedule_dt, d_comp_seq_num;
  
              close lcu_comp_old_eff_dt;
  
              if (d_schedule_dt is null) then
                d_schedule_dt := d_effective_date;
              end if;
  
              lt_rev_component_tbl(cnt).old_effectivity_date := d_schedule_dt;
              lt_rev_component_tbl(cnt).old_operation_sequence_number := d_comp_seq_num;
            end if;
  
  
            lt_rev_component_tbl(cnt).transaction_type := v_transaction_type;
  
            lt_rev_component_tbl(cnt).item_sequence_number := p_components_tbl(cnt)
                                                             .p_component_seq_num;
            lt_rev_component_tbl(cnt).quantity_per_assembly := p_components_tbl(cnt)
                                                              .p_component_qty;
            lt_rev_component_tbl(cnt).comments := p_components_tbl(cnt)
                                                 .p_comments;
            lt_rev_component_tbl(cnt).operation_sequence_number := 1; -- check this value should be passed as parameter
  
            --begin change by amir 22/1/08
            \*
                            if (p_ref_designator is not null and nvl(lt_rev_component_tbl(cnt).acd_type,-1) in (1,3)) then
                                -- assigning reference designator details
                                lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
                                lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
                                lt_ref_designator_tbl(n_des_count).revised_item_name := p_assembly;
                                lt_ref_designator_tbl(n_des_count).start_effective_date := d_effective_date;
                                lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_new_assembly_itm_rev,1,3);
                                lt_ref_designator_tbl(n_des_count).component_item_name := p_components_tbl(cnt).p_component;
                                lt_ref_designator_tbl(n_des_count).reference_designator_name := p_ref_designator;
                                lt_ref_designator_tbl(n_des_count).acd_type := p_components_tbl(cnt).p_acd_flag;
                                lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
                    lt_ref_designator_tbl(n_des_count).operation_sequence_number := 1;
                                n_des_count := n_des_count + 1;
                            end if;
  
                if (p_balloon is not null and nvl(lt_rev_component_tbl(cnt).acd_type,-1) in (1,3)) then
                                -- assigning reference designator details
                                lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
                                lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
                                lt_ref_designator_tbl(n_des_count).revised_item_name := p_assembly;
                                lt_ref_designator_tbl(n_des_count).start_effective_date := d_effective_date;
                                lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_new_assembly_itm_rev,1,3);
                                lt_ref_designator_tbl(n_des_count).component_item_name := p_components_tbl(cnt).p_component;
                                lt_ref_designator_tbl(n_des_count).reference_designator_name := p_balloon;
                                lt_ref_designator_tbl(n_des_count).acd_type := p_components_tbl(cnt).p_acd_flag;
                                lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
                    lt_ref_designator_tbl(n_des_count).operation_sequence_number := 1;
                    n_des_count := n_des_count + 1;
                            end if;
  
  
            if (p_components_tbl(cnt)
               .p_ref_designator is not null and
                nvl(lt_rev_component_tbl(cnt).acd_type, -1) in (1, 3)) then
              p_str := p_components_tbl(cnt).p_ref_designator;
              l_len := length(p_str);
              for i in 1 .. l_len loop
                if substr(p_str, i, 1) = ',' then
                  l_comma_cnt := l_comma_cnt + 1;
                end if;
              end loop;
              for i in 1 .. l_comma_cnt + 1 loop
                select decode(substr(trim(p_str),
                                     1,
                                     instr(trim(p_str), l_seperator, 1, 1) - 1),
                              null,
                              decode(substr(trim(p_str), 1, 1),
                                     l_seperator,
                                     null,
                                     trim(p_str)),
                              substr(trim(p_str),
                                     1,
                                     instr(trim(p_str), l_seperator, 1, 1) - 1))
                  into l_str
                  from dual;
  
                l_pos := nvl(Length(l_str), 0) + 2;
                p_str := substr(p_str, l_pos, length(p_str));
                -- assigning reference designator details
                lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
                lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
                lt_ref_designator_tbl(n_des_count).revised_item_name := p_assembly;
                lt_ref_designator_tbl(n_des_count).start_effective_date := d_effective_date;
                lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_new_assembly_itm_rev,
                                                                                       1,
                                                                                       3);
                lt_ref_designator_tbl(n_des_count).component_item_name := p_components_tbl(cnt)
                                                                         .p_component;
                lt_ref_designator_tbl(n_des_count).reference_designator_name := l_str;
                lt_ref_designator_tbl(n_des_count).acd_type := p_components_tbl(cnt)
                                                              .p_acd_flag;
                lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
                lt_ref_designator_tbl(n_des_count).operation_sequence_number := 1;
                n_des_count := n_des_count + 1;
              end loop;
  
            end if;
  
            if (p_components_tbl(cnt)
               .p_balloon is not null and
                nvl(lt_rev_component_tbl(cnt).acd_type, -1) in (1, 3)) then
              -- assigning reference designator details
              lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
              lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
              lt_ref_designator_tbl(n_des_count).revised_item_name := p_assembly;
              lt_ref_designator_tbl(n_des_count).start_effective_date := d_effective_date;
              lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_new_assembly_itm_rev,
                                                                                     1,
                                                                                     3);
              lt_ref_designator_tbl(n_des_count).component_item_name := p_components_tbl(cnt)
                                                                       .p_component;
              lt_ref_designator_tbl(n_des_count).reference_designator_name := p_components_tbl(cnt)
                                                                             .p_balloon;
              lt_ref_designator_tbl(n_des_count).acd_type := p_components_tbl(cnt)
                                                            .p_acd_flag;
              lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
              lt_ref_designator_tbl(n_des_count).operation_sequence_number := 1;
              n_des_count := n_des_count + 1;
            end if;*\
  
  
  
           --added for multiple comps. bom
           --n_des_count :=1;
  
           --create or delete action
           if (p_components_tbl(cnt).p_ref_designator.EXISTS(p_components_tbl(cnt).p_ref_designator.FIRST)  and nvl(lt_rev_component_tbl(cnt).acd_type,-1) in (1,3)) then
                for i in p_components_tbl(cnt).p_ref_designator.FIRST .. p_components_tbl(cnt).p_ref_designator.LAST loop
                          --autonomous_proc.dump_temp(cnt ||' '||i||' '||'p_ref_designator='||p_components_tbl(cnt).p_ref_designator(i).p_ref_designator);
                            -- assigning reference designator details
                                lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
                                lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
                                lt_ref_designator_tbl(n_des_count).revised_item_name := p_assembly;
                                lt_ref_designator_tbl(n_des_count).start_effective_date := d_effective_date;
                                lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_new_assembly_itm_rev,1,3);
                                lt_ref_designator_tbl(n_des_count).component_item_name := p_components_tbl(cnt).p_component;
                                lt_ref_designator_tbl(n_des_count).reference_designator_name := p_components_tbl(cnt).p_ref_designator(i).p_ref_designator;
                                lt_ref_designator_tbl(n_des_count).acd_type := p_components_tbl(cnt).p_acd_flag;
                                lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
                                lt_ref_designator_tbl(n_des_count).operation_sequence_number := 1;
                                n_des_count := n_des_count + 1;
                end loop;
              end if;
            --autonomous_proc.dump_temp(cnt||'amirt p_components_tbl(cnt).p_balloon  :' || p_components_tbl(cnt).p_balloon);
            --autonomous_proc.dump_temp(cnt||'amirt lt_rev_component_tbl(cnt).acd_type  :' || lt_rev_component_tbl(cnt).acd_type);
                if (p_components_tbl(cnt).p_balloon is not null and nvl(lt_rev_component_tbl(cnt).acd_type,-1) in (1,3)) then
             --autonomous_proc.dump_temp(cnt||'amirt in if ballon');                   -- assigning reference designator details
             \*
                    lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
                                lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
                                lt_ref_designator_tbl(n_des_count).revised_item_name := p_assembly;
                                lt_ref_designator_tbl(n_des_count).start_effective_date := d_effective_date;
                                lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_new_assembly_itm_rev,1,3);
                                lt_ref_designator_tbl(n_des_count).component_item_name := p_components_tbl(cnt).p_component;
                                lt_ref_designator_tbl(n_des_count).reference_designator_name := p_components_tbl(cnt).p_balloon;
                                lt_ref_designator_tbl(n_des_count).acd_type := p_components_tbl(cnt).p_acd_flag;
                                lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
                                lt_ref_designator_tbl(n_des_count).operation_sequence_number := 1;
                                n_des_count := n_des_count + 1;
                  *\
                     --7/02/2008 baloon moved to component level dff
                     lt_rev_component_tbl(cnt).attribute5 := p_components_tbl(cnt).p_balloon;
                end if;
  
        --update action
        if (p_components_tbl(cnt).p_ref_designator.EXISTS(p_components_tbl(cnt).p_ref_designator.FIRST)  and nvl(lt_rev_component_tbl(cnt).acd_type,-1) in (2)) then
  
  
             -- create all rows that coming from agile system
              for i in p_components_tbl(cnt).p_ref_designator.FIRST .. p_components_tbl(cnt).p_ref_designator.LAST loop
                          --autonomous_proc.dump_temp(cnt ||' '||n_des_count||' '||'p_ref_designator='||p_components_tbl(cnt).p_ref_designator(i).p_ref_designator);
                            -- assigning reference designator details
                                lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
                                lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
                                lt_ref_designator_tbl(n_des_count).revised_item_name := p_assembly;
                                lt_ref_designator_tbl(n_des_count).start_effective_date := d_effective_date;
                                lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_new_assembly_itm_rev,1,3);
                                lt_ref_designator_tbl(n_des_count).component_item_name := p_components_tbl(cnt).p_component;
                                lt_ref_designator_tbl(n_des_count).reference_designator_name := p_components_tbl(cnt).p_ref_designator(i).p_ref_designator;
                                lt_ref_designator_tbl(n_des_count).acd_type := 1;
                                lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
                                lt_ref_designator_tbl(n_des_count).operation_sequence_number := 1;
                                n_des_count := n_des_count + 1;
                end loop;
  
  
        --delete all existing rows
             for lcu_comp_old_ref_desg_curr in lcu_comp_old_ref_desg (p_assembly,lr_get_inv_orgs.inventory_org_id,p_components_tbl(cnt).p_component )
              loop
               --autonomous_proc.dump_temp (cnt ||' '||n_des_count||' '||'from delete cursor  ref_designator='||lcu_comp_old_ref_desg_curr.component_reference_designator);
  
                                lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
                                lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
                                lt_ref_designator_tbl(n_des_count).revised_item_name := p_assembly;
                                lt_ref_designator_tbl(n_des_count).start_effective_date :=  d_effective_date; --nvl(lcu_comp_old_ref_desg_curr.effectivity_date,sysdate);
                                lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_new_assembly_itm_rev,1,3);
                                lt_ref_designator_tbl(n_des_count).component_item_name := p_components_tbl(cnt).p_component;
                                lt_ref_designator_tbl(n_des_count).Alternate_Bom_Code := lcu_comp_old_ref_desg_curr.ALTERNATE_BOM_DESIGNATOR;
                                lt_ref_designator_tbl(n_des_count).reference_designator_name := lcu_comp_old_ref_desg_curr.component_reference_designator;
                                lt_ref_designator_tbl(n_des_count).acd_type := 3;--lcu_comp_old_ref_desg_curr.acd_type;
                                lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
                                lt_ref_designator_tbl(n_des_count).operation_sequence_number := lcu_comp_old_ref_desg_curr.OPERATION_SEQ_NUM;
                                n_des_count := n_des_count + 1;
  
              end loop;
  
          end if;
  
  
            --autonomous_proc.dump_temp(cnt||'amirt p_components_tbl(cnt).p_balloon  :' || p_components_tbl(cnt).p_balloon);
            --autonomous_proc.dump_temp(cnt||'amirt lt_rev_component_tbl(cnt).acd_type  :' || lt_rev_component_tbl(cnt).acd_type);
                if (p_components_tbl(cnt).p_balloon is not null and nvl(lt_rev_component_tbl(cnt).acd_type,-1) in (2)) then
          \*
            --autonomous_proc.dump_temp(cnt||'amirt in if ballon');                   -- assigning reference designator details
                                lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
                                lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
                                lt_ref_designator_tbl(n_des_count).revised_item_name := p_assembly;
                                lt_ref_designator_tbl(n_des_count).start_effective_date := d_effective_date;
                                lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_new_assembly_itm_rev,1,3);
                                lt_ref_designator_tbl(n_des_count).component_item_name := p_components_tbl(cnt).p_component;
                                lt_ref_designator_tbl(n_des_count).reference_designator_name := p_components_tbl(cnt).p_balloon;
                                lt_ref_designator_tbl(n_des_count).acd_type := 1;
                                lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
                                lt_ref_designator_tbl(n_des_count).operation_sequence_number := 1;
                                n_des_count := n_des_count + 1;
                                *\
                     lt_rev_component_tbl(cnt).attribute5 := p_components_tbl(cnt).p_balloon;
                end if;
  
  
          end loop;
        end if;
        --end change by amir 22/1/08
        --autonomous_proc.dump_temp('Before process_eco');
  
     --try to delete the designator
  
  
        ENG_ECO_PUB.process_eco(p_api_version_number   => n_api_version,
                                p_init_msg_list        => b_init_msg,
                                p_bo_identifier        => v_bo_identifier,
                                p_eco_rec              => lr_eco_rec,
                                p_eco_revision_tbl     => lt_eco_rev_tbl,
                                p_revised_item_tbl     => lt_revised_item_tbl,
                                p_rev_component_tbl    => lt_rev_component_tbl,
                                p_ref_designator_tbl   => lt_ref_designator_tbl,
                                p_sub_component_tbl    => lt_sub_component_tbl,
                                p_rev_operation_tbl    => lt_rev_operation_tbl,
                                p_rev_op_resource_tbl  => lt_rev_op_resource_tbl,
                                p_rev_sub_resource_tbl => lt_rev_sub_resource_tbl,
                                p_debug                => 'N',
                                p_output_dir           => v_output_dir,
                                p_debug_filename       => v_debug_filename,
                                x_return_status        => v_return_status,
                                x_msg_count            => n_msg_count,
                                x_eco_rec              => xr_eco_rec,
                                x_eco_revision_tbl     => xt_eco_rev_tbl,
                                x_revised_item_tbl     => xt_revised_item_tbl,
                                x_rev_component_tbl    => xt_rev_component_tbl,
                                x_ref_designator_tbl   => xt_ref_designator_tbl,
                                x_sub_component_tbl    => xt_sub_component_tbl,
                                x_rev_operation_tbl    => xt_rev_operation_tbl,
                                x_rev_op_resource_tbl  => xt_rev_op_resource_tbl,
                                x_rev_sub_resource_tbl => xt_rev_sub_resource_tbl);
        --autonomous_proc.dump_temp('After process_eco, return status:' ||
                                  v_return_status || ', n_msg_count :' ||
                                  n_msg_count);
  
        if (n_msg_count <> 0) then
          tbl_error_type := tbl_error_type_dummy;
          ERROR_HANDLER.get_message_list(x_message_list => tbl_error_type);
          for i in 1 .. tbl_error_type.count loop
            add_error_text('Entity ID:' || tbl_error_type(i)
                           .entity_id || ', Error:' || tbl_error_type(i)
                           .message_text);
            --autonomous_proc.dump_temp('Entity ID:' || tbl_error_type(i)
                                      .entity_id || ', Error:' ||
                                      tbl_error_type(i).message_text);
          end loop;
        end if;
        if (NVL(v_return_status, 'S') <> FND_API.g_ret_sts_success) then
          raise l_item_creation_exception;
        else
          -- this is required since we need to put the eco into scheduled status effective as on the d_effective_date
          update eng_revised_items
             set status_type = 4, auto_implement_date = d_effective_date
           where change_notice = p_eco_number
             and status_code <> 6;
  
          update eng_engineering_changes
             set status_type = 4
           where change_notice = p_eco_number
             and status_code <> 6;
  
         for lr_get_inv_id_rec in lr_get_inv_id  loop
          update MTL_ITEM_REVISIONS_B mirb
          set   mirb.change_notice = p_eco_number, ecn_initiation_date = p_ecn_initiation_date
          where  mirb.inventory_item_id = lr_get_inv_id_rec.inventory_item_id
          and mirb.revision_id in ( select max(b.revision_id)
                                    from MTL_ITEM_REVISIONS_B b
                                    where  b.inventory_item_id=lr_get_inv_id_rec.inventory_item_id
                                    group by b.organization_id) ;
          end loop;
        end if;
  
      end loop;
      close lcu_get_inv_orgs;
  
      x_return_status := EGO_ITEM_PUB.g_ret_sts_success;
      x_error_code    := 0;
      x_msg_count     := 0;
      x_msg_data      := gv_error_text; -- this is set in the loop for error messages
  
  --   execute immediate  'ALTER SESSION SET SQL_TRACE = TRUE';
  --    execute immediate  'alter session set events=''10046 trace name context off''';
  --dbms_support.stop_trace();
    exception
      when l_item_creation_exception then
        --autonomous_proc.dump_temp('From l_item_creation_exception :' ||
                                  gv_error_text);
        x_return_status := EGO_ITEM_PUB.g_ret_sts_error;
        x_error_code    := sqlcode;
        x_msg_count     := n_msg_count;
        x_msg_data      := gv_error_text || ' Oracle DB Error:' ||sqlerrm; -- this is set in the loop for error messages
  
        --rollback; -- remove this line
      when others then
        fnd_message.set_name('INV', 'INV_ITEM_UNEXPECTED_ERROR');
        fnd_message.set_token('PACKAGE_NAME', 'XXAGILE_PROCESS_ECO_ITEM_PKG');
        fnd_message.set_token('PROCEDURE_NAME', 'PROCESS_ECO_ITEM');
        fnd_message.set_token('ERROR_TEXT', 'SQLERRM: ' || sqlerrm);
        x_msg_data      := fnd_message.get || ' Oracle DB Error:' ||sqlerrm;
        x_return_status := EGO_ITEM_PUB.g_ret_sts_unexp_error;
        x_error_code    := sqlcode;
        x_msg_count     := n_msg_count;
        --autonomous_proc.dump_temp('From others: ' || x_msg_data);
       -- rollback; -- remove this line
  
    end process_eco_item;
  */

  FUNCTION is_replaced(p_current_value IN VARCHAR2,
                       p_del_comp      OUT VARCHAR2,
                       p_cre_comp      OUT VARCHAR2) RETURN BOOLEAN IS
    l_temp VARCHAR2(4000) := REPLACE(p_current_value, '~!RM!~', '~');
  BEGIN
  
    IF length(p_current_value) - length(REPLACE(p_current_value, '~!RM!~')) = 6 THEN
      p_del_comp := substr(l_temp, 1, instr(l_temp, '~') - 1);
      p_cre_comp := substr(l_temp, instr(l_temp, '~') + 1, length(l_temp));
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN FALSE;
  END;

  -----------------------------------------------
  -- process_eco_item
  ------------------------------------------------
  --  ver  date        name              desc
  --  1.x  08.08.13    yuval tal         cr811 : modify CURSOR lcu_get_org_id (receive org_code instead of name)

  -----------------------------------------------
  PROCEDURE process_eco_item(p_eco_number          IN VARCHAR2, -- varchar2(10)
                             p_change_type_code    IN VARCHAR2, -- varchar2(30)
                             p_ecn_initiation_date IN DATE,
                             p_revised_items       IN xxagile_proc_eco_item_pkg12,
                             p_creation_dt         IN DATE,
                             p_created_by          IN NUMBER,
                             p_last_updated_dt     IN DATE,
                             p_last_update_by      IN NUMBER,
                             x_return_status       OUT NOCOPY VARCHAR2,
                             x_error_code          OUT NOCOPY NUMBER,
                             x_msg_count           OUT NOCOPY NUMBER,
                             x_msg_data            OUT NOCOPY VARCHAR2) IS
  
    CURSOR lcu_get_inv_orgs(cp_org_id      IN NUMBER,
                            cp_org_context IN VARCHAR2) IS
      SELECT '1' order_by_col,
             hoi.org_information3 operating_unit_id,
             haou.organization_id inventory_org_id,
             mp.organization_code inventory_org_code,
             mp.master_organization_id master_organization_id,
             haou.name inventory_organization_name,
             '' operating_unit_name
        FROM hr_organization_information hoi,
             hr_all_organization_units   haou,
             mtl_parameters              mp
       WHERE haou.organization_id = hoi.organization_id
         AND hoi.org_information_context = cp_org_context --'Accounting Information'
         AND SYSDATE BETWEEN haou.date_from AND nvl(haou.date_to, SYSDATE)
         AND mp.organization_id = haou.organization_id
         AND haou.organization_id = cp_org_id
      /*and exists
      (select 'x'
               from mtl_parameters
              where organization_id = haou.organization_id
                and organization_id = master_organization_id)*/
      ;
    -- start Union all remove by amir 20/1/08 for common bill logic
  
    --end remove
    lr_get_inv_orgs lcu_get_inv_orgs%ROWTYPE;
  
    -- get the opetaing unit id for the provided operating unit name
    /*   CURSOR lcu_get_org_id(cp_org_name IN VARCHAR2) IS
    SELECT organization_id operating_unit_id
      FROM hr_all_organization_units t
     WHERE NAME = cp_org_name;*/
  
    -- CR 811 --
    CURSOR lcu_get_org_id(cp_org_code IN VARCHAR2) IS
      SELECT organization_id operating_unit_id
        FROM xxobjt_org_organization_def_v t
       WHERE t.organization_code = cp_org_code;
    -- END CR 811 --
    n_org_id NUMBER;
  
    CURSOR lr_get_inv_id(p_assembly IN VARCHAR2) IS
      SELECT msib.inventory_item_id
        FROM mtl_system_items_b msib
       WHERE segment1 = p_assembly
         AND msib.organization_id IN
             (SELECT master_organization_id
                FROM mtl_parameters
               WHERE organization_id = master_organization_id);
  
    CURSOR lr_get_bom_item_type(l_assembly        IN VARCHAR2,
                                l_organization_id IN NUMBER) IS
      SELECT msib.bom_item_type
        FROM mtl_system_items_b msib
       WHERE segment1 = l_assembly
         AND msib.organization_id = l_organization_id;
  
    l_bom_item_type NUMBER;
    -- get user name of requestor
    CURSOR lr_get_requestor_user_name(cp_user_id IN NUMBER) IS
      SELECT user_name FROM fnd_user WHERE user_id = cp_user_id;
  
    -- cursor to get the old effective date of the revised item from the
    -- latest ECO
    CURSOR lcu_old_eff_dt(cp_revised_item    IN VARCHAR2,
                          cp_organization_id IN NUMBER,
                          cp_status_type     IN NUMBER) IS
      SELECT MAX(eri.scheduled_date)
        FROM eng_revised_items eri, mtl_system_items msi
       WHERE eri.revised_item_id = msi.inventory_item_id
         AND eri.organization_id = msi.organization_id
         AND msi.segment1 = cp_revised_item
         AND eri.organization_id = cp_organization_id
         AND eri.status_type > cp_status_type;
  
    CURSOR lcu_comp_old_eff_dt(cp_comp_name       IN VARCHAR2,
                               cp_revised_item    IN VARCHAR2,
                               cp_organization_id IN NUMBER,
                               cp_status_type     IN NUMBER) IS
      SELECT bic.effectivity_date, bic.operation_seq_num
        FROM bom_bill_of_materials    bbom,
             bom_inventory_components bic,
             mtl_system_items_b       msi_as,
             mtl_system_items_b       msi_co
       WHERE msi_as.segment1 = cp_revised_item --msi_as.inventory_item_id=9606
         AND msi_co.segment1 = cp_comp_name
         AND bic.bill_sequence_id = bbom.bill_sequence_id
         AND bbom.organization_id = cp_organization_id
         AND msi_as.inventory_item_id = bbom.assembly_item_id
         AND msi_as.organization_id = cp_organization_id
         AND msi_co.inventory_item_id = bic.component_item_id
         AND msi_co.organization_id = cp_organization_id
         AND nvl(bic.disable_date, SYSDATE + 1) > SYSDATE
            -- and msi_as.attribute14='Y'
         AND bic.implementation_date IS NOT NULL -- Need to verify this condition doesnt return records
         AND bbom.alternate_bom_designator IS NULL; --There are 2 alternate bom in the system
  
    CURSOR lcu_comp_old_ref_desg(cp_revised_item    IN VARCHAR2,
                                 cp_organization_id IN NUMBER,
                                 cp_comp_name       IN VARCHAR2) IS
      SELECT brd.component_reference_designator,
             bic.effectivity_date,
             bic.operation_seq_num,
             brd.acd_type,
             bbom.alternate_bom_designator
        FROM bom_bill_of_materials     bbom,
             bom_inventory_components  bic,
             bom_reference_designators brd,
             mtl_system_items_b        msi_as,
             mtl_system_items_b        msi_co
       WHERE msi_as.segment1 = cp_revised_item --msi_as.inventory_item_id=9606
         AND msi_co.segment1 = cp_comp_name
         AND bic.bill_sequence_id = bbom.bill_sequence_id
         AND bbom.organization_id = cp_organization_id
         AND msi_as.inventory_item_id = bbom.assembly_item_id
         AND msi_as.organization_id = cp_organization_id
         AND msi_co.inventory_item_id = bic.component_item_id
         AND msi_co.organization_id = cp_organization_id
         AND nvl(bic.disable_date, SYSDATE + 1) > SYSDATE
         AND bic.component_sequence_id = brd.component_sequence_id
            --and msi_as.attribute14='Y'
         AND bic.implementation_date IS NOT NULL -- Need to verify this condition doesnt return records
         AND bbom.alternate_bom_designator IS NULL; --There are 2 alternate bom in the system
  
    d_ref_diseg    VARCHAR2(15);
    d_schedule_dt  DATE;
    d_comp_seq_num NUMBER;
  
    v_item_org_assign_profile fnd_profile_option_values.profile_option_value%TYPE;
    n_api_input_org_id        NUMBER;
  
    n_api_version    NUMBER := 1.0;
    b_init_msg       BOOLEAN := TRUE;
    v_return_status  VARCHAR2(10);
    n_msg_count      NUMBER := 0;
    v_bo_identifier  VARCHAR2(10) := 'ECO';
    v_debug          VARCHAR2(1) := 'Y';
    v_output_dir     VARCHAR2(240) := '/usr/tmp/PROD';
    v_debug_filename VARCHAR2(80) := 'a2o_eco_debug_1.log';
  
    v_transaction_type VARCHAR2(10) := 'CREATE';
  
    -- variable for requestor user name
    v_requestor VARCHAR2(100);
  
    lr_eco_rec       eng_eco_pub.eco_rec_type;
    xr_eco_rec       eng_eco_pub.eco_rec_type;
    lr_eco_dummy_rec eng_eco_pub.eco_rec_type;
  
    lt_eco_rev_tbl       eng_eco_pub.eco_revision_tbl_type;
    xt_eco_rev_tbl       eng_eco_pub.eco_revision_tbl_type;
    lt_eco_rev_dummy_tbl eng_eco_pub.eco_revision_tbl_type;
  
    lt_revised_item_tbl       eng_eco_pub.revised_item_tbl_type;
    xt_revised_item_tbl       eng_eco_pub.revised_item_tbl_type;
    lt_revised_item_dummy_tbl eng_eco_pub.revised_item_tbl_type;
  
    lt_rev_component_tbl       bom_bo_pub.rev_component_tbl_type;
    xt_rev_component_tbl       bom_bo_pub.rev_component_tbl_type;
    lt_rev_component_dummy_tbl bom_bo_pub.rev_component_tbl_type;
  
    lt_ref_designator_tbl       bom_bo_pub.ref_designator_tbl_type;
    lt_bom_ref_designator_tbl   bom_bo_pub.bom_ref_designator_tbl_type;
    xt_ref_designator_tbl       bom_bo_pub.ref_designator_tbl_type;
    lt_ref_designator_dummy_tbl bom_bo_pub.ref_designator_tbl_type;
  
    lt_sub_component_tbl       bom_bo_pub.sub_component_tbl_type;
    xt_sub_component_tbl       bom_bo_pub.sub_component_tbl_type;
    lt_sub_component_dummy_tbl bom_bo_pub.sub_component_tbl_type;
  
    lt_rev_operation_tbl       bom_rtg_pub.rev_operation_tbl_type;
    xt_rev_operation_tbl       bom_rtg_pub.rev_operation_tbl_type;
    lt_rev_operation_dummy_tbl bom_rtg_pub.rev_operation_tbl_type;
  
    lt_rev_op_resource_tbl       bom_rtg_pub.rev_op_resource_tbl_type;
    xt_rev_op_resource_tbl       bom_rtg_pub.rev_op_resource_tbl_type;
    lt_rev_op_resource_dummy_tbl bom_rtg_pub.rev_op_resource_tbl_type;
  
    lt_rev_sub_resource_tbl       bom_rtg_pub.rev_sub_resource_tbl_type;
    xt_rev_sub_resource_tbl       bom_rtg_pub.rev_sub_resource_tbl_type;
    lt_rev_sub_resource_dummy_tbl bom_rtg_pub.rev_sub_resource_tbl_type;
  
    n_des_count          NUMBER := 1;
    n_del_des_count      NUMBER := 1;
    n_user_id            NUMBER := 0;
    tbl_error_type       error_handler.error_tbl_type;
    tbl_error_type_dummy error_handler.error_tbl_type;
    cnt_item             NUMBER := 1;
  
    l_exception               EXCEPTION;
    l_item_creation_exception EXCEPTION;
  
    d_effective_date DATE;
    --add by amir 22/1/08
    l_str       VARCHAR2(15);
    l_seperator VARCHAR2(1) := ',';
    l_len       NUMBER := 0;
    l_comma_cnt NUMBER := 0;
    l_pos       NUMBER;
    p_str       VARCHAR2(4000);
    v_revision  VARCHAR2(3);
  
    v_wip_supply_type     NUMBER;
    v_supply_subinventory NUMBER;
    v_supply_locator_id   NUMBER;
  
    p_bom_header_tbl        bom_bo_pub.bom_header_tbl_type := bom_bo_pub.g_miss_bom_header_tbl;
    p_bom_revision_tbl      bom_bo_pub.bom_revision_tbl_type := bom_bo_pub.g_miss_bom_revision_tbl;
    p_bom_component_tbl     bom_bo_pub.bom_comps_tbl_type := bom_bo_pub.g_miss_bom_component_tbl;
    p_bom_sub_component_tbl bom_bo_pub.bom_sub_component_tbl_type := bom_bo_pub.g_miss_bom_sub_component_tbl;
    p_bom_comp_ops_tbl      bom_bo_pub.bom_comp_ops_tbl_type := bom_bo_pub.g_miss_bom_comp_ops_tbl;
  
    x_bom_header_tbl         bom_bo_pub.bom_header_tbl_type;
    x_bom_revision_tbl       bom_bo_pub.bom_revision_tbl_type;
    x_bom_component_tbl      bom_bo_pub.bom_comps_tbl_type;
    x_bom_ref_designator_tbl bom_bo_pub.bom_ref_designator_tbl_type;
    x_bom_sub_component_tbl  bom_bo_pub.bom_sub_component_tbl_type;
    x_bom_comp_ops_tbl       bom_bo_pub.bom_comp_ops_tbl_type;
  
    is_desig_del BOOLEAN := FALSE;
  
    l_del_comp       mtl_system_items_b.segment1%TYPE;
    l_new_comp       mtl_system_items_b.segment1%TYPE;
    is_replace_exist BOOLEAN := FALSE;
    --add by amirt 21/04/08
    l_ecn_initiation_date DATE := p_ecn_initiation_date + 3 / 24;
  
    v_message           VARCHAR2(1000);
    v_phase             VARCHAR2(30);
    v_status            VARCHAR2(10);
    v_dev_phase         VARCHAR2(100);
    v_dev_status        VARCHAR2(10);
    v_request_finish    BOOLEAN;
    b_print_options     BOOLEAN;
    v_request_id        NUMBER;
    v_printer           VARCHAR2(30);
    v_item_num          NUMBER;
    v_operation_seq_num NUMBER;
    v_ef_date           DATE;
    v_old_eff_date      DATE;
    v_replaced_comp     VARCHAR2(50);
    v_assembly_id       NUMBER;
    v_bill_sequence_id  NUMBER;
    v_locator           VARCHAR2(80);
    v_cgroup            VARCHAR2(30);
    v_trx_id            NUMBER;
    l_upd_supply_type   VARCHAR2(1);
  BEGIN
  
    /*execute immediate 'alter session set timed_statistics = true';
    execute immediate 'alter session set statistics_level=all';
    execute immediate 'alter session set max_dump_file_size = unlimited';
    execute  immediate 'alter session set events ''10046 trace name context forever, level 12''';
    execute  immediate 'ALTER SESSION SET tracefile_identifier = ''Arik_API_TEST''';*/
  
    -- initialize this package level variable it will comtain previous error messages when this is not initialized
    gv_error_text := NULL;
  
    -- check if this procedure is invoked for new item creation or modification
    -- change the user accordingly
    n_user_id := 1650; --1113;--nvl(p_created_by, nvl(p_last_update_by, 0));
  
    write_to_log('process_eco', 'User ID :' || n_user_id);
    --autonomous_proc.dump_temp('User ID :' || n_user_id);
  
    OPEN lr_get_requestor_user_name(n_user_id);
    FETCH lr_get_requestor_user_name
      INTO v_requestor;
    CLOSE lr_get_requestor_user_name;
  
    -- initialize loop variables
    lr_eco_rec := lr_eco_dummy_rec;
    xr_eco_rec := lr_eco_dummy_rec;
  
    lt_eco_rev_tbl := lt_eco_rev_dummy_tbl;
    xt_eco_rev_tbl := lt_eco_rev_dummy_tbl;
  
    lt_revised_item_tbl := lt_revised_item_dummy_tbl;
    xt_revised_item_tbl := lt_revised_item_dummy_tbl;
  
    lt_rev_component_tbl := lt_rev_component_dummy_tbl;
    xt_rev_component_tbl := lt_rev_component_dummy_tbl;
  
    lt_ref_designator_tbl := lt_ref_designator_dummy_tbl;
    xt_ref_designator_tbl := lt_ref_designator_dummy_tbl;
  
    lt_sub_component_tbl := lt_sub_component_dummy_tbl;
    xt_sub_component_tbl := lt_sub_component_dummy_tbl;
  
    lt_rev_operation_tbl := lt_rev_operation_dummy_tbl;
    xt_rev_operation_tbl := lt_rev_operation_dummy_tbl;
  
    lt_rev_op_resource_tbl := lt_rev_op_resource_dummy_tbl;
    xt_rev_op_resource_tbl := lt_rev_op_resource_dummy_tbl;
  
    lt_rev_sub_resource_tbl := lt_rev_sub_resource_dummy_tbl;
    xt_rev_sub_resource_tbl := lt_rev_sub_resource_dummy_tbl;
  
    --autonomous_proc.dump_temp('2');
    -- assigning the eco rec type details
    lr_eco_rec.eco_name := p_eco_number;
    --autonomous_proc.dump_temp('eco_name :' || p_eco_number);
    lr_eco_rec.requestor            := v_requestor; -- should be employee number
    lr_eco_rec.transaction_type     := v_transaction_type;
    lr_eco_rec.change_type_code     := 'Agile'; --p_change_type_code;
    lr_eco_rec.approval_status_name := 'Approved'; -- check this value
    lr_eco_rec.status_name          := 'Scheduled';
    lr_eco_rec.plm_or_erp_change    := 'ERP';
    --autonomous_proc.dump_temp('3');
  
    -- from the api documentation
    -- The New_Revised_Item_Revision is not updateable for revised items since it is part of the unique key
    -- which uniquely identifies a record. So, updates to it have to be made by entering the new revision
    -- into Updated_Revised_Item_Revision. After the record is retrieved using the unique key, its revision is overwritten by the new value.
    -- Just like New_Revised_Item_Revision, Start_Effective_Date is a unique index column. So changes to it have to be made by entering
    -- the new value into New_Effective_Date.
  
    IF (p_revised_items.exists(p_revised_items.first)) THEN
      FOR cnt_rev IN p_revised_items.first .. p_revised_items.last LOOP
        --autonomous_proc.dump_temp('From process_eco_item 2: ' || p_revised_items(cnt_rev).p_assembly);
      
        --autonomous_proc.dump_temp('p_owner_organization :' || p_revised_items(cnt_rev).p_owner_organization);
      
        /*    Begin
        Select 
        From mtl_system_items_b msi,
             mtl_item_categories mic,
             mtl_categories_b mc
        Where msi.inventory_item_id = mic.inventory_item_id
          And msi.organization_id = mic.organization_id
          And mic.category_id = mc.category_id
          And msi.segment1 = p_revised_items(cnt_rev).p_assembly
          And mc.segment1 = 'Resin'*/
      
        BEGIN
          SELECT MAX(xx.transaction_id), xx.cgroup
            INTO v_trx_id, v_cgroup
            FROM xxobjt_agile_items xx
           WHERE xx.item_number = p_revised_items(cnt_rev).p_assembly
           GROUP BY cgroup;
        EXCEPTION
          WHEN no_data_found THEN
            v_cgroup := NULL;
        END;
      
        OPEN lcu_get_org_id(xxinv_utils_pkg.get_bom_organization(v_cgroup) /*p_revised_items(cnt_rev).p_owner_organization*/);
        FETCH lcu_get_org_id
          INTO n_org_id;
        CLOSE lcu_get_org_id;
      
        --autonomous_proc.dump_temp('Operating Unit ID :' || n_org_id);
      
        -- check if the operating unit id could be determined
        -- incase it is null then assign error message to the out parameter and
        -- raise exception
        IF (n_org_id IS NULL) THEN
          fnd_message.set_name('ACCST', 'AC_CST_A2O_INVALID_OU');
          fnd_message.set_token('OU_NAME',
                                'WPI - WW Printers Israel (IO)' /*p_revised_items(cnt_rev).p_owner_organization*/);
          RAISE l_exception;
        END IF;
      
        -- get the value of the system profile ACCST_AGILE_ITEM_ORG_ASSIG
        -- this profile value is set at the org level, 10006 is hardcoded to get the value at the Org level
      
        /*   v_item_org_assign_profile := FND_PROFILE.value_specific(org_id => n_org_id,
        name   => 'AC_AGILE_ITEM_ORG_ASSIG');*/
      
        write_to_log('process_item',
                     'Profile Value :' || v_item_org_assign_profile ||
                     ' is set for Organization ID:' || n_org_id);
      
        --autonomous_proc.dump_temp('Profile Value :' ||
        --                          v_item_org_assign_profile ||
        --                         ' is set for Organization ID:' || n_org_id);
      
        -- check the profile value, if it is null then the current item will be assigned to
        -- all inventory organizations.
        --begin delete by amir 20/01/08
        /* if (nvl(v_item_org_assign_profile,'ALL') = 'OU') then
            n_api_input_org_id := n_org_id;
        else
            n_api_input_org_id := null;
        end if;*/
        --end
        --begin add by amir 20/01/08
        n_api_input_org_id := n_org_id;
        --end
        --autonomous_proc.dump_temp('1 , n_api_input_org_id: ' ||
        --                          n_api_input_org_id);
      
        OPEN lcu_get_inv_orgs(n_api_input_org_id, 'Accounting Information');
        --loop
        FETCH lcu_get_inv_orgs
          INTO lr_get_inv_orgs;
        EXIT WHEN lcu_get_inv_orgs%NOTFOUND;
        CLOSE lcu_get_inv_orgs;
      
        /*      Begin 
         Select to_date(max(x.effectivedate),'DD/MM/YYYY HH24:MI:SS')+1
         Into d_effective_date
         From xxobjt_agile_bom x
         Where x.eco = p_eco_number
           And x.assembly = p_revised_items(cnt_rev).p_assembly;
        Exception
         When Others Then
          d_effective_date := Null;
        End; */
      
        BEGIN
          SELECT MAX(m.effectivity_date)
            INTO d_effective_date
            FROM mtl_item_revisions_b m, mtl_system_items_b ms
           WHERE ms.organization_id = m.organization_id
             AND ms.inventory_item_id = m.inventory_item_id
             AND ms.segment1 = p_revised_items(cnt_rev).p_assembly;
        EXCEPTION
          WHEN OTHERS THEN
            d_effective_date := NULL;
        END;
        -- if (p_revised_items(cnt_rev).p_effective_date is null or p_revised_items(cnt_rev).p_effective_date < sysdate) then
        -- d_effective_date := sysdate;
        /*else
        d_effective_date := p_revised_items(cnt_rev).p_effective_date;*/ -- this is for future dated effectivity
        --end if;
        IF d_effective_date < SYSDATE THEN
          d_effective_date := SYSDATE;
        END IF;
      
        lr_eco_rec.organization_code := lr_get_inv_orgs.inventory_org_code;
        lt_revised_item_tbl(cnt_rev).eco_name := p_eco_number;
        lt_revised_item_tbl(cnt_rev).organization_code := lr_get_inv_orgs.inventory_org_code;
        lt_revised_item_tbl(cnt_rev).revised_item_name := p_revised_items(cnt_rev)
                                                          .p_assembly;
        /*lt_revised_item_tbl(cnt_rev).new_revised_item_revision := v_revision;substr(p_revised_items(cnt_rev).p_new_assembly_itm_rev,
        1,
        3);*/ --Arik
      
        lt_revised_item_tbl(cnt_rev).start_effective_date := d_effective_date;
      
        lt_revised_item_tbl(cnt_rev).requestor := v_requestor;
        lt_revised_item_tbl(cnt_rev).transaction_type := v_transaction_type;
        lt_revised_item_tbl(cnt_rev).create_bom_in_local_org := 'N'; -- check this value
        lt_revised_item_tbl(cnt_rev).change_management_type := 'CHANGE_ORDER'; -- this is the default value
        lt_revised_item_tbl(cnt_rev).update_wip := 1;
        lt_revised_item_tbl(cnt_rev).status_type := 4; -- to make it into scheduled state for auto implement
        --   lt_revised_item_tbl(cnt_rev).wip_supply_type:=1;-------!!!!!!!!!!!!!!!!!!!!!!------------
        --autonomous_proc.dump_temp(' befor comp loop=');
      
        IF (p_revised_items(cnt_rev)
           .p_components_tbl.exists(p_revised_items(cnt_rev)
                                    .p_components_tbl.first)) THEN
          FOR cnt IN p_revised_items(cnt_rev).p_components_tbl.first .. p_revised_items(cnt_rev)
                                                                        .p_components_tbl.last LOOP
          
            --Arik
            /*        Begin    
              Select max(mir.REVISION)
              Into v_revision
              From mtl_item_revisions mir,
                   mtl_system_items_b msi
              Where mir.INVENTORY_ITEM_ID = msi.inventory_item_id
                And mir.ORGANIZATION_ID = msi.organization_id
                And msi.organization_id = lr_get_inv_orgs.inventory_org_id
                And msi.segment1 = p_revised_items(cnt_rev).p_components_tbl(cnt).p_component;
            Exception
             When Others Then
              v_revision := Null;
            End;*/
          
            BEGIN
            
              v_wip_supply_type := NULL;
            
              SELECT nvl(t.connectiontype, 'N')
                INTO l_upd_supply_type
                FROM xxobjt_agile_bom t
               WHERE t.eco = p_eco_number
                 AND t.assembly = p_revised_items(cnt_rev).p_assembly
                 AND t.component = p_revised_items(cnt_rev).p_components_tbl(cnt)
                    .p_component;
            
              IF l_upd_supply_type = 'Y' THEN
              
                SELECT lookup_code
                  INTO v_wip_supply_type
                  FROM mfg_lookups
                 WHERE lookup_type = 'WIP_SUPPLY'
                   AND meaning = 'Supplier';
              
              END IF;
            
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          
            --check if replace exist
            IF is_replaced(p_revised_items(cnt_rev).p_components_tbl(cnt)
                           .p_component,
                           l_del_comp,
                           l_new_comp) THEN
            
              IF l_del_comp IS NOT NULL AND l_new_comp IS NOT NULL THEN
                is_replace_exist := TRUE;
              
                --delete del_comp
                lt_rev_component_tbl(cnt_item).eco_name := p_eco_number;
                lt_rev_component_tbl(cnt_item).organization_code := lr_get_inv_orgs.inventory_org_code;
                lt_rev_component_tbl(cnt_item).revised_item_name := p_revised_items(cnt_rev)
                                                                    .p_assembly;
                -- lt_rev_component_tbl(cnt_item).new_revised_item_revision := v_revision;--substr(p_revised_items(cnt_rev).p_new_assembly_itm_rev,1,3);
              
                -- in this case revised item which is created with earlier could not be found
                lt_rev_component_tbl(cnt_item).start_effective_date := d_effective_date;
                lt_rev_component_tbl(cnt_item).new_effectivity_date := d_effective_date;
                lt_rev_component_tbl(cnt_item).component_item_name := l_del_comp;
                lt_rev_component_tbl(cnt_item).acd_type := 3;
              
                d_schedule_dt  := NULL;
                d_comp_seq_num := NULL;
              
                OPEN lcu_comp_old_eff_dt(l_del_comp,
                                         p_revised_items(cnt_rev).p_assembly,
                                         lr_get_inv_orgs.inventory_org_id,
                                         4);
                FETCH lcu_comp_old_eff_dt
                  INTO d_schedule_dt, d_comp_seq_num;
                CLOSE lcu_comp_old_eff_dt;
              
                IF (d_schedule_dt IS NULL) THEN
                  d_schedule_dt := d_effective_date;
                END IF;
              
                lt_rev_component_tbl(cnt_item).old_effectivity_date := d_schedule_dt;
                lt_rev_component_tbl(cnt_item).old_operation_sequence_number := d_comp_seq_num;
              
                lt_rev_component_tbl(cnt_item).transaction_type := v_transaction_type;
                --lt_rev_component_tbl(cnt_item).item_sequence_number := v_item_num;--p_revised_items(cnt_rev).p_components_tbl(cnt).p_component_seq_num;
                lt_rev_component_tbl(cnt_item).quantity_per_assembly := p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                                        .p_component_qty;
                --lt_rev_component_tbl(cnt_item).comments := p_revised_items(cnt_rev).p_components_tbl(cnt).p_comments;
                lt_rev_component_tbl(cnt_item).operation_sequence_number := 1; -- check this value should be passed as parameter
              
                cnt_item := cnt_item + 1;
              
                --create new item
                OPEN lr_get_bom_item_type(p_revised_items(cnt_rev)
                                          .p_assembly,
                                          lr_get_inv_orgs.master_organization_id);
                FETCH lr_get_bom_item_type
                  INTO l_bom_item_type;
                CLOSE lr_get_bom_item_type;
              
                IF l_bom_item_type IN (2, 1) THEN
                  lt_rev_component_tbl(cnt_item).optional := 1;
                END IF;
              
                --bug 09/03/2008 ref-desig-quantity
                lt_rev_component_tbl(cnt_item).quantity_related := 2;
              
                -- assigning component details
                lt_rev_component_tbl(cnt_item).eco_name := p_eco_number;
                lt_rev_component_tbl(cnt_item).organization_code := lr_get_inv_orgs.inventory_org_code;
                lt_rev_component_tbl(cnt_item).revised_item_name := p_revised_items(cnt_rev)
                                                                    .p_assembly;
                --  lt_rev_component_tbl(cnt_item).new_revised_item_revision := v_revision;--substr(p_revised_items(cnt_rev).p_new_assembly_itm_rev,1,3);
              
                -- in this case revised item which is created with earlier could not be found
                lt_rev_component_tbl(cnt_item).start_effective_date := d_effective_date;
                lt_rev_component_tbl(cnt_item).new_effectivity_date := d_effective_date;
                lt_rev_component_tbl(cnt_item).component_item_name := l_new_comp;
                lt_rev_component_tbl(cnt_item).acd_type := 1;
                IF v_wip_supply_type IS NOT NULL THEN
                  lt_rev_component_tbl(cnt_item).wip_supply_type := v_wip_supply_type;
                END IF;
                lt_rev_component_tbl(cnt_item).transaction_type := v_transaction_type;
                --lt_rev_component_tbl(cnt_item).item_sequence_number := v_item_num;--p_revised_items(cnt_rev).p_components_tbl(cnt).p_component_seq_num;
                lt_rev_component_tbl(cnt_item).quantity_per_assembly := p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                                        .p_component_qty;
                --lt_rev_component_tbl(cnt_item).comments := p_revised_items(cnt_rev).p_components_tbl(cnt).p_comments;
                lt_rev_component_tbl(cnt_item).operation_sequence_number := 1; -- check this value should be passed as parameter
                --lt_rev_component_tbl(cnt_item).attribute5 := p_revised_items(cnt_rev).p_components_tbl(cnt).p_balloon;
              
                --create or delete action
                IF (p_revised_items(cnt_rev).p_components_tbl(cnt)
                   .p_ref_designator.exists(p_revised_items(cnt_rev).p_components_tbl(cnt)
                                            .p_ref_designator.first) AND
                    nvl(lt_rev_component_tbl(cnt_item).acd_type, -1) IN
                    (1, 3)) THEN
                  FOR i IN p_revised_items(cnt_rev).p_components_tbl(cnt)
                           .p_ref_designator.first .. p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                      .p_ref_designator.last LOOP
                    --autonomous_proc.dump_temp(cnt ||' '||i||' '||'p_ref_designator='||p_revised_items(cnt_rev).p_components_tbl(cnt).p_ref_designator(i).p_ref_designator);
                    -- assigning reference designator details
                    lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
                    lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
                    lt_ref_designator_tbl(n_des_count).revised_item_name := p_revised_items(cnt_rev)
                                                                            .p_assembly;
                    lt_ref_designator_tbl(n_des_count).start_effective_date := d_effective_date;
                    --lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_revised_items(cnt_rev).p_new_assembly_itm_rev,1,3);
                    lt_ref_designator_tbl(n_des_count).component_item_name := l_new_comp;
                    lt_ref_designator_tbl(n_des_count).reference_designator_name := p_revised_items(cnt_rev).p_components_tbl(cnt).p_ref_designator(i)
                                                                                    .p_ref_designator;
                    lt_ref_designator_tbl(n_des_count).acd_type := 1;
                    lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
                    lt_ref_designator_tbl(n_des_count).operation_sequence_number := 1;
                    n_des_count := n_des_count + 1;
                  END LOOP;
                END IF;
              
                cnt_item := cnt_item + 1;
              
              END IF;
            
            ELSE
              v_replaced_comp := NULL;
              --normal process
              OPEN lr_get_bom_item_type(p_revised_items(cnt_rev).p_assembly,
                                        lr_get_inv_orgs.master_organization_id);
              FETCH lr_get_bom_item_type
                INTO l_bom_item_type;
              CLOSE lr_get_bom_item_type;
            
              IF l_bom_item_type IN (2, 1) THEN
                lt_rev_component_tbl(cnt_item).optional := 1;
              END IF;
              --autonomous_proc.dump_temp('Adding Component');
            
              --bug 09/04/2008 ref-desig-quantity
              lt_rev_component_tbl(cnt_item).quantity_related := 2;
            
              -- assigning component details
              lt_rev_component_tbl(cnt_item).eco_name := p_eco_number;
              lt_rev_component_tbl(cnt_item).organization_code := lr_get_inv_orgs.inventory_org_code;
              lt_rev_component_tbl(cnt_item).revised_item_name := p_revised_items(cnt_rev)
                                                                  .p_assembly;
              -- lt_rev_component_tbl(cnt_item).new_revised_item_revision := v_revision;--substr(p_revised_items(cnt_rev).p_new_assembly_itm_rev,1,3);
            
              -- in this case revised item which is created with earlier could not be found
              lt_rev_component_tbl(cnt_item).start_effective_date :=  /*sysdate;--*/
               d_effective_date;
            
              IF (lt_rev_component_tbl(cnt_item).acd_type = 3) THEN
                lt_rev_component_tbl(cnt_item).start_effective_date := SYSDATE; --d_effective_date;
              END IF;
            
              IF (lt_rev_component_tbl(cnt_item).acd_type = 1) THEN
                lt_rev_component_tbl(cnt_item).new_effectivity_date := SYSDATE; --d_effective_date;
              END IF;
            
              lt_rev_component_tbl(cnt_item).component_item_name := p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                                    .p_component;
              lt_rev_component_tbl(cnt_item).acd_type := p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                         .p_acd_flag;
            
              --need to pass values to change component. Take the values from the deleted into new 
            
              BEGIN
                SELECT msi.inventory_item_id
                  INTO v_assembly_id
                  FROM mtl_system_items_b msi
                 WHERE msi.segment1 = p_revised_items(cnt_rev).p_assembly
                   AND rownum = 1;
              EXCEPTION
                WHEN OTHERS THEN
                  v_assembly_id := NULL;
              END;
            
              BEGIN
                SELECT bbo.bill_sequence_id
                  INTO v_bill_sequence_id
                  FROM bom_bill_of_materials bbo
                 WHERE bbo.assembly_item_id = v_assembly_id
                   AND bbo.organization_id = n_org_id;
              EXCEPTION
                WHEN OTHERS THEN
                  v_bill_sequence_id := NULL;
              END;
            
              BEGIN
                SELECT nvl(v_wip_supply_type, bi.wip_supply_type),
                       bi.supply_subinventory,
                       bi.supply_locator_id
                  INTO v_wip_supply_type,
                       v_supply_subinventory,
                       v_supply_locator_id
                  FROM bom_inventory_components bi, mtl_system_items_b msi
                 WHERE bi.component_item_id = msi.inventory_item_id
                   AND msi.organization_id = n_org_id
                   AND msi.segment1 = p_revised_items(cnt_rev).p_components_tbl(cnt)
                      .p_component
                   AND bi.bill_sequence_id = v_bill_sequence_id
                   AND rownum = 1;
              EXCEPTION
                WHEN OTHERS THEN
                  v_supply_subinventory := NULL;
                  v_supply_locator_id   := NULL;
              END;
            
              v_locator := NULL;
            
              IF v_supply_locator_id IS NOT NULL THEN
                BEGIN
                  SELECT mi.concatenated_segments
                    INTO v_locator
                    FROM mtl_item_locations_kfv mi
                   WHERE mi.organization_id = n_org_id
                     AND mi.inventory_location_id = v_supply_locator_id;
                EXCEPTION
                  WHEN OTHERS THEN
                    v_locator := NULL;
                END;
              END IF;
            
              lt_rev_component_tbl(cnt_item).wip_supply_type := v_wip_supply_type; --Arik
              lt_rev_component_tbl(cnt_item).supply_subinventory := v_supply_subinventory; --Arik
              lt_rev_component_tbl(cnt_item).location_name := v_locator; --Arik
            
              IF (lt_rev_component_tbl(cnt_item).acd_type <> 1) THEN
              
                v_item_num := NULL;
              
                BEGIN
                  SELECT bi.item_num,
                         bi.operation_seq_num,
                         to_date(to_char(effectivity_date,
                                         'dd/mm/yyyy hh24:mi:ss'),
                                 'dd/mm/yyyy hh24:mi:ss')
                    INTO v_item_num, v_operation_seq_num, v_old_eff_date
                    FROM mtl_system_items_b         msi,
                         bom_inventory_components_v bi
                   WHERE msi.segment1 = p_revised_items(cnt_rev).p_components_tbl(cnt)
                        .p_component
                     AND msi.organization_id = n_org_id
                     AND msi.inventory_item_id = bi.component_item_id
                     AND bi.disable_date IS NULL
                     AND bi.bill_sequence_id = v_bill_sequence_id -- This to know what assembly is it.
                     AND bi.implementation_date =
                         (SELECT MAX(bi2.implementation_date)
                            FROM bom_inventory_components_v bi2
                           WHERE bi2.component_item_id =
                                 bi.component_item_id
                             AND bi2.bill_sequence_id = v_bill_sequence_id
                             AND bi2.disable_date IS NULL);
                EXCEPTION
                  WHEN OTHERS THEN
                    v_item_num          := NULL;
                    v_operation_seq_num := NULL;
                END;
              
                d_schedule_dt  := NULL;
                d_comp_seq_num := v_operation_seq_num; --ARIK null
              
                OPEN lcu_comp_old_eff_dt(p_revised_items                 (cnt_rev).p_components_tbl(cnt)
                                         .p_component,
                                         p_revised_items                 (cnt_rev)
                                         .p_assembly,
                                         lr_get_inv_orgs.inventory_org_id,
                                         4);
                FETCH lcu_comp_old_eff_dt
                  INTO d_schedule_dt, d_comp_seq_num;
                CLOSE lcu_comp_old_eff_dt;
              
                IF (d_schedule_dt IS NULL) THEN
                  d_schedule_dt := SYSDATE; --ARIK   d_effective_date;
                END IF;
              
                /*If v_old_eff_date < d_schedule_dt Then
                 v_old_eff_date := d_schedule_dt;
                End If;*/
                /*if (lt_rev_component_tbl(cnt_item).acd_type = 2) then
                 lt_rev_component_tbl(cnt_item).old_effectivity_date := v_old_eff_date;
                End If;*/
              
                lt_rev_component_tbl(cnt_item).old_effectivity_date := v_old_eff_date; --d_schedule_dt;
              
                lt_rev_component_tbl(cnt_item).old_operation_sequence_number := d_comp_seq_num;
                lt_rev_component_tbl(cnt_item).item_sequence_number := v_item_num; --Arik
              
              END IF;
            
              lt_rev_component_tbl(cnt_item).transaction_type := v_transaction_type;
              --lt_rev_component_tbl(cnt_item).item_sequence_number := v_item_num;--p_revised_items(cnt_rev).p_components_tbl(cnt).p_component_seq_num;
              lt_rev_component_tbl(cnt_item).quantity_per_assembly := p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                                      .p_component_qty;
              --lt_rev_component_tbl(cnt_item).comments := p_revised_items(cnt_rev).p_components_tbl(cnt).p_comments;
              /*** Changed by Ella - to take oracle defaults 
              If acd_type = 1 should be by routing or 1 if routing not exists
              if acd_type = 2,3 should be old  operation_sequence_number ***/
              --lt_rev_component_tbl(cnt_item).operation_sequence_number := d_comp_seq_num; --add by amirt 23/04/08 1; -- check this value should be passed as parameter
            
              --create or delete action
              IF (p_revised_items(cnt_rev).p_components_tbl(cnt)
                 .p_ref_designator.exists(p_revised_items(cnt_rev).p_components_tbl(cnt)
                                          .p_ref_designator.first) AND
                  nvl(lt_rev_component_tbl(cnt_item).acd_type, -1) IN (1, 3)) THEN
                FOR i IN p_revised_items(cnt_rev).p_components_tbl(cnt)
                         .p_ref_designator.first .. p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                    .p_ref_designator.last LOOP
                  --autonomous_proc.dump_temp(cnt ||' '||i||' '||'p_ref_designator='||p_revised_items(cnt_rev).p_components_tbl(cnt).p_ref_designator(i).p_ref_designator);
                  -- assigning reference designator details
                  lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
                  lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
                  lt_ref_designator_tbl(n_des_count).revised_item_name := p_revised_items(cnt_rev)
                                                                          .p_assembly;
                  lt_ref_designator_tbl(n_des_count).start_effective_date := d_effective_date;
                  --lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_revised_items(cnt_rev).p_new_assembly_itm_rev,1,3);
                  lt_ref_designator_tbl(n_des_count).component_item_name := p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                                            .p_component;
                  lt_ref_designator_tbl(n_des_count).reference_designator_name := p_revised_items(cnt_rev).p_components_tbl(cnt).p_ref_designator(i)
                                                                                  .p_ref_designator;
                  lt_ref_designator_tbl(n_des_count).acd_type := p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                                 .p_acd_flag;
                  lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
                  lt_ref_designator_tbl(n_des_count).operation_sequence_number := 1;
                  n_des_count := n_des_count + 1;
                END LOOP;
              END IF;
            
              IF (p_revised_items(cnt_rev).p_components_tbl(cnt)
                 .p_balloon IS NOT NULL AND
                  nvl(lt_rev_component_tbl(cnt_item).acd_type, -1) IN (1, 3)) THEN
                --7/02/2008 baloon moved to component level dff
                lt_rev_component_tbl(cnt_item).attribute5 := p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                             .p_balloon;
              END IF;
            
              --update action
              IF (p_revised_items(cnt_rev).p_components_tbl(cnt)
                 .p_ref_designator.exists(p_revised_items(cnt_rev).p_components_tbl(cnt)
                                          .p_ref_designator.first) AND
                  nvl(lt_rev_component_tbl(cnt_item).acd_type, -1) IN (2)) THEN
                -- create all rows that coming from agile system
                FOR i IN p_revised_items(cnt_rev).p_components_tbl(cnt)
                         .p_ref_designator.first .. p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                    .p_ref_designator.last LOOP
                  --autonomous_proc.dump_temp(cnt ||' '||n_des_count||' '||'p_ref_designator='||p_revised_items(cnt_rev).p_components_tbl(cnt).p_ref_designator(i).p_ref_designator);
                  -- assigning reference designator details
                  lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
                  lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
                  lt_ref_designator_tbl(n_des_count).revised_item_name := p_revised_items(cnt_rev)
                                                                          .p_assembly;
                  lt_ref_designator_tbl(n_des_count).start_effective_date := d_effective_date;
                  --lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_revised_items(cnt_rev).p_new_assembly_itm_rev,1,3);
                  lt_ref_designator_tbl(n_des_count).component_item_name := p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                                            .p_component;
                  lt_ref_designator_tbl(n_des_count).reference_designator_name := p_revised_items(cnt_rev).p_components_tbl(cnt).p_ref_designator(i)
                                                                                  .p_ref_designator;
                  lt_ref_designator_tbl(n_des_count).acd_type := 1;
                  lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
                  lt_ref_designator_tbl(n_des_count).operation_sequence_number := 1;
                  n_des_count := n_des_count + 1;
                END LOOP;
              
                --delete all existing rows
                FOR lcu_comp_old_ref_desg_curr IN lcu_comp_old_ref_desg(p_revised_items                 (cnt_rev)
                                                                        .p_assembly,
                                                                        lr_get_inv_orgs.inventory_org_id,
                                                                        p_revised_items                 (cnt_rev).p_components_tbl(cnt)
                                                                        .p_component) LOOP
                  --autonomous_proc.dump_temp (cnt ||' '||n_des_count||' '||'from delete cursor  ref_designator='||lcu_comp_old_ref_desg_curr.component_reference_designator);
                
                  lt_ref_designator_tbl(n_des_count).eco_name := p_eco_number;
                  lt_ref_designator_tbl(n_des_count).organization_code := lr_get_inv_orgs.inventory_org_code;
                  lt_ref_designator_tbl(n_des_count).revised_item_name := p_revised_items(cnt_rev)
                                                                          .p_assembly;
                  lt_ref_designator_tbl(n_des_count).start_effective_date := d_effective_date; --nvl(lcu_comp_old_ref_desg_curr.effectivity_date,sysdate);
                  --lt_ref_designator_tbl(n_des_count).new_revised_item_revision := substr(p_revised_items(cnt_rev).p_new_assembly_itm_rev,1,3);
                  lt_ref_designator_tbl(n_des_count).component_item_name := p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                                            .p_component;
                  lt_ref_designator_tbl(n_des_count).alternate_bom_code := lcu_comp_old_ref_desg_curr.alternate_bom_designator;
                  lt_ref_designator_tbl(n_des_count).reference_designator_name := lcu_comp_old_ref_desg_curr.component_reference_designator;
                  lt_ref_designator_tbl(n_des_count).acd_type := 3; --lcu_comp_old_ref_desg_curr.acd_type;
                  lt_ref_designator_tbl(n_des_count).transaction_type := 'CREATE';
                  lt_ref_designator_tbl(n_des_count).operation_sequence_number := lcu_comp_old_ref_desg_curr.operation_seq_num;
                  n_des_count := n_des_count + 1;
                
                END LOOP;
              END IF;
            
              IF (p_revised_items(cnt_rev).p_components_tbl(cnt)
                 .p_balloon IS NOT NULL AND
                  nvl(lt_rev_component_tbl(cnt_item).acd_type, -1) IN (2)) THEN
                lt_rev_component_tbl(cnt_item).attribute5 := p_revised_items(cnt_rev).p_components_tbl(cnt)
                                                             .p_balloon;
              END IF;
            
              cnt_item := cnt_item + 1;
            
            END IF;
          
          END LOOP;
        
        END IF;
      END LOOP;
    END IF;
    --end change by amir 22/1/08
    --autonomous_proc.dump_temp('Before process_eco');
  
    --try to delete the designator
    tbl_error_type.delete;
    eng_eco_pub.process_eco(p_api_version_number   => n_api_version,
                            p_init_msg_list        => b_init_msg,
                            p_bo_identifier        => v_bo_identifier,
                            p_eco_rec              => lr_eco_rec,
                            p_eco_revision_tbl     => lt_eco_rev_tbl,
                            p_revised_item_tbl     => lt_revised_item_tbl,
                            p_rev_component_tbl    => lt_rev_component_tbl,
                            p_ref_designator_tbl   => lt_ref_designator_tbl,
                            p_sub_component_tbl    => lt_sub_component_tbl,
                            p_rev_operation_tbl    => lt_rev_operation_tbl,
                            p_rev_op_resource_tbl  => lt_rev_op_resource_tbl,
                            p_rev_sub_resource_tbl => lt_rev_sub_resource_tbl,
                            p_debug                => 'Y',
                            p_output_dir           => v_output_dir,
                            p_debug_filename       => v_debug_filename,
                            x_return_status        => v_return_status,
                            x_msg_count            => n_msg_count,
                            x_eco_rec              => xr_eco_rec,
                            x_eco_revision_tbl     => xt_eco_rev_tbl,
                            x_revised_item_tbl     => xt_revised_item_tbl,
                            x_rev_component_tbl    => xt_rev_component_tbl,
                            x_ref_designator_tbl   => xt_ref_designator_tbl,
                            x_sub_component_tbl    => xt_sub_component_tbl,
                            x_rev_operation_tbl    => xt_rev_operation_tbl,
                            x_rev_op_resource_tbl  => xt_rev_op_resource_tbl,
                            x_rev_sub_resource_tbl => xt_rev_sub_resource_tbl);
    --autonomous_proc.dump_temp('After process_eco, return status:' ||
    --                           v_return_status || ', n_msg_count :' ||
    --                          n_msg_count);
  
    IF (n_msg_count <> 0) THEN
      tbl_error_type := tbl_error_type_dummy;
      error_handler.get_message_list(x_message_list => tbl_error_type);
      FOR i IN 1 .. tbl_error_type.count LOOP
        add_error_text('Entity ID:' || tbl_error_type(i).entity_id ||
                       ', Error:' || tbl_error_type(i).message_text);
        --autonomous_proc.dump_temp('Entity ID:' || tbl_error_type(i)
      --                           .entity_id || ', Error:' ||
      --                          tbl_error_type(i).message_text);
      END LOOP;
    END IF;
    IF (nvl(v_return_status, 'S') <> fnd_api.g_ret_sts_success) THEN
      ROLLBACK;
      RAISE l_item_creation_exception;
    ELSE
      -- this is required since we need to put the eco into scheduled status effective as on the d_effective_date
      UPDATE eng_revised_items
         SET status_type = 4, auto_implement_date = d_effective_date
       WHERE change_notice = p_eco_number
         AND status_code <> 6;
    
      UPDATE eng_engineering_changes
         SET status_type = 4
       WHERE change_notice = p_eco_number
         AND status_code <> 6;
    
      IF (p_revised_items.exists(p_revised_items.first)) THEN
        FOR cnt_rev1 IN p_revised_items.first .. p_revised_items.last LOOP
          FOR lr_get_inv_id_rec IN lr_get_inv_id(p_revised_items(cnt_rev1)
                                                 .p_assembly) LOOP
            UPDATE mtl_item_revisions_b mirb
               SET mirb.change_notice  = p_eco_number,
                   ecn_initiation_date = l_ecn_initiation_date
             WHERE mirb.inventory_item_id =
                   lr_get_inv_id_rec.inventory_item_id
               AND mirb.revision_id IN
                   (SELECT MAX(b.revision_id)
                      FROM mtl_item_revisions_b b
                     WHERE b.inventory_item_id =
                           lr_get_inv_id_rec.inventory_item_id
                     GROUP BY b.organization_id)
                  --bug ->21/02/2008<- make changes only for the revision without eco name on it
               AND mirb.change_notice IS NULL;
          END LOOP;
        END LOOP;
      END IF;
    END IF;
  
    x_return_status := ego_item_pub.g_ret_sts_success;
    x_error_code    := 0;
    x_msg_count     := 0;
    x_msg_data      := gv_error_text; -- this is set in the loop for error messages
  
    --Run Concurrent: Engineering Change Order Implementation
    fnd_global.apps_initialize(n_user_id, 50623, 660); --ask resp + user
    fnd_profile.get(NAME => 'PRINTER', val => v_printer);
    b_print_options := fnd_request.set_print_options(printer        => v_printer,
                                                     style          => NULL,
                                                     copies         => 0,
                                                     save_output    => TRUE,
                                                     print_together => NULL);
    v_request_id    := fnd_request.submit_request(application => 'ENG',
                                                  program     => 'ENCACN',
                                                  description => NULL,
                                                  start_time  => NULL,
                                                  sub_request => FALSE,
                                                  argument1   => n_org_id,
                                                  argument2   => 2,
                                                  argument3   => NULL,
                                                  argument4   => p_eco_number,
                                                  argument5   => NULL);
  
    COMMIT;
  
    v_request_finish := fnd_concurrent.wait_for_request(request_id => v_request_id,
                                                        INTERVAL   => 5,
                                                        max_wait   => 600,
                                                        phase      => v_phase,
                                                        status     => v_status,
                                                        dev_phase  => v_dev_phase,
                                                        dev_status => v_dev_status,
                                                        message    => v_message);
  
    IF nvl(v_request_id, 0) = 0 THEN
      x_return_status := 'T'; --This will indicates the bpel to Trminate the program. (Problem with pending Conc')
    END IF;
    --execute immediate 'alter session set events ''10046 trace name context off''';                                             
    --   execute immediate  'ALTER SESSION SET SQL_TRACE = TRUE';
    --    execute immediate  'alter session set events=''10046 trace name context off''';
    --dbms_support.stop_trace();
  EXCEPTION
    WHEN l_item_creation_exception THEN
      --autonomous_proc.dump_temp('From l_item_creation_exception :' ||
      --                          gv_error_text);
      x_return_status := ego_item_pub.g_ret_sts_error;
      x_error_code    := SQLCODE;
      x_msg_count     := n_msg_count;
      x_msg_data      := gv_error_text ||
                         ' Oracle DB Error (item_creation_exception):' ||
                         SQLERRM; -- this is set in the loop for error messages
  
    --rollback; -- remove this line
    WHEN OTHERS THEN
      fnd_message.set_name('INV', 'INV_ITEM_UNEXPECTED_ERROR');
      fnd_message.set_token('PACKAGE_NAME', 'XXAGILE_PROCESS_ECO_ITEM_PKG');
      fnd_message.set_token('PROCEDURE_NAME', 'PROCESS_ECO_ITEM');
      fnd_message.set_token('ERROR_TEXT', 'SQLERRM: ' || SQLERRM);
      x_msg_data      := fnd_message.get || ' Oracle DB Error: ' || SQLERRM;
      x_return_status := ego_item_pub.g_ret_sts_unexp_error;
      x_error_code    := SQLCODE;
      x_msg_count     := n_msg_count;
      --autonomous_proc.dump_temp('From others: ' || x_msg_data);
    -- rollback; -- remove this line
  
  END process_eco_item;

END xxagile_process_eco_item_pkg;
/
