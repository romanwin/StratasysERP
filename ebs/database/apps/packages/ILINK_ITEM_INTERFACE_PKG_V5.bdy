create or replace package body ILINK_ITEM_INTERFACE_PKG as
/*
REM +============================================================================================+
REM |Filename         :  BLD_ITEM_INTERFACE_PKG.pkb                                              |
REM |                                                                                            |
REM |Copyright        : 2010-2014 KPIT - All Rights Reserved                                     |
REM |                   All rights reserved:  This software/documentation contains proprietary   |
REM |                   information of KPIT; it is provided under a license agreement            |
REM |                   containing restrictions on use and disclosure and is also protected      |
REM |                   by copyright law.  Reverse engineering of the software is prohibited.    |
REM |                                                                                            |
REM |Description      : Package Body for processing Items contains the following program Units   |
REM |                    ILINK_ITEM_INT_MAIN  (Main process)                                     |
REM |                    ILINK_ITEM_COPY_ALL_ORG (Populate Records for all Organizations)        |
REM |                    ILINK_ITEM_PRE_VALIDATE  (Validate data on Temporary tables)            |
REM |                    ILINK_ITEM_INSERT_INT  (Insert validated records into Interface Tables) |
REM |                    ILINK_INV_OPEN_INTERFACE (Call Item Import Open Interface)              |
REM |                    ILINK_POST_ITEM_INTERFACE  (Review and update status after item import) |       
REM |                                                                                            |
REM |                                                                                            |
REM |Calling Program  : Concurrent Executable name is ILINKINVINT                                |
REM |                                                                                            |
REM |Pre-requisites   : None                                                                     |
REM |                                                                                            |
REM |                                                                                            |
REM |Post Processing  :                                                                          |
REM |                                                                                            |
REM |                                                                                            |
REM |                                                                                            |
REM |Code Based On iLink Release: 7.6.5                                                          |
REM |                                                                                            |
REM |                                                                                            |
REM |Customer:    Stratasys 12-NOV-14                                                            |
REM |                                                                                            |
REM |Customer Change History:                                                                    |
REM |------------------------                                                                    |
REM |Version  Date       Author         Remarks                                                  |
REM |-------  --------- --------------  ---------------------------------------------------------|
REM |1.0      12-NOV-14 K Gangisetty    First draft Version for Customer branched from iLink,    |
REM |                                   code base 7.6.0                                          |
REM |1.1      04-FEB-15 K Gangisetty    Added Code to check Item Type of Agile template vs       |
REM |                                   EBS item type For IL Items                               |
REM |         09-FEB-15 K Gangisetty    Added code to process additional template/orgs for       |
REM |                                    EP items                                                |
REM |1.2      14-MAR-18 KPIT            Added the code for Pending Item Status and Added the     |
REM |                                   Extra Debug messages for exception                       |
REM |                                                                                            |
REM |1.3      23-APR-18 KPIT            Commented the "and c_items.attribute3 = 'IL'" Condition  |
REM |                                   Modified the Item copy all org procedure                 |
REM |                                                                                            |
REM |1.4      16-AUG-19 KPIT            Added code to process ATP Rule as per the Ticket# ICI-188|
REM |                                   I-Link - Matrix (Collection Plan)                        |
REM |                                                                                            |
REM |1.5      24-JUN-20 Birlasoft       Commented the code to process Buyer,Planner,Make_Buy,    |
REM |                                   Receipt Routing,ATP Rule as per the Ticket# ICI-280      |
REM |                                                                                            |
REM |                                                                                            |
REM |                                                                                            |
REM | Be sure to update the version number below with the latest version number reference above. |
REM |                                                                                            |
REM +============================================================================================+

/* Declare Global Variables to hold values used across multiple procedures */

v_cust_cat1_set_name    Varchar2(30) := ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Category Set Name','Custom Category Set1',NULL,NULL,NULL);
v_cust_cat2_set_name    Varchar2(30) := ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Category Set Name','Custom Category Set2',NULL,NULL,NULL);
v_cust_cat3_set_name    Varchar2(30) := ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Category Set Name','Custom Category Set3',NULL,NULL,NULL);
v_cust_cat4_set_name    Varchar2(30) := ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Category Set Name','Custom Category Set4',NULL,NULL,NULL);
v_cust_cat5_set_name    Varchar2(30) := ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Category Set Name','Custom Category Set5',NULL,NULL,NULL);  -- Added by KPIT on 23-APR-2018

v_user_id         Number := FND_GLOBAL.USER_ID();


Procedure ILINK_ITEM_INT_MAIN(x_retcode OUT VARCHAR2,
                               x_errbuff OUT VARCHAR2) is


/* Define a Cursor to fetch the value for Master Organization */

Cursor get_master_org is
Select mpp.organization_id,
       mpp.organization_code
From MTL_PARAMETERS mpp,
     ILINK_DATA_XREF ref
Where mpp.organization_id = mpp.master_organization_id and
      ref.data_input1 = 'Master Org Code' and
      mpp.organization_code = ref.data_output1;

/* Define a Cursor to verify if validated records exist in temp table */

Cursor get_validated_records is
Select count (*)
From ILINK_MTL_ITEMS_INT_TEMP
Where record_status = 'Validated';

/* Define a Cursor to verify if unprocessed records exist in item interface table */

Cursor get_item_intf_count is
Select count (*)
From mtl_system_items_interface
Where transaction_type in ('CREATE','UPDATE') and
      process_flag = 1 and
      set_process_id in (0,1,2,3);    -- set_process_id in (0,1,2);    -- Modified on 02/09/2015

/* Define a Cursor to verify if unprocessed records exist in category interface table */

Cursor get_cat_intf_count is
Select count (*)
From mtl_item_categories_interface
Where transaction_type in ('CREATE','UPDATE','DELETE') and
      process_flag = 1 and
      set_process_id in (0,1,2,3);    -- set_process_id in (0,1,2);    -- Modified on 02/09/2015


v_count_temp_records       Number := 0;
v_count_item_intf          Number := 0;
v_count_cat_intf           Number := 0;

v_master_org_id            Number;
v_master_org_code    Varchar2(3);

v_req_id1        Number;
v_req_id2        Number;


Begin

    /* Fetch the value for Master Organization id  */

        open get_master_org;
         fetch get_master_org into v_master_org_id,v_master_org_code;
         close get_master_org;


       /* Call the Procedure to Populate the Item records in temp table for all organizations */

        ILINK_item_copy_all_org(v_master_org_id,v_master_org_code);
        commit;

        /* Call the procedure to validate all the records before inserting into Interface tables */

        ILINK_item_pre_validate(v_master_org_id,v_master_org_code);
        commit;

        /* Call the procedure to insert records into Interface tables if "Validated" records exist in temp table */

    open get_validated_records;
        fetch get_validated_records into v_count_temp_records;
    close get_validated_records;

        If v_count_temp_records != 0  then

            ILINK_item_insert_int(v_master_org_id,v_master_org_code);
            commit;

          /* Call the procedure to run the Item Import if records exist in the Interface tables */

          open get_item_intf_count;
          fetch get_item_intf_count into v_count_item_intf;
          close get_item_intf_count;

              open get_cat_intf_count;
          fetch get_cat_intf_count into v_count_cat_intf;
          close get_cat_intf_count;

              If (v_count_item_intf != 0) OR (v_count_cat_intf != 0) Then

                v_req_id1 := NULL;
                v_req_id2 := NULL;

                ILINK_inv_open_interface(v_master_org_id,v_req_id1,v_req_id2);
                commit;

                /* call the procedure to review and report the errors from Item Import Interface */

                ILINK_post_item_interface (v_req_id1,v_req_id2);
                commit;

             End if;

          /* Call the procedure to insert pending status records */ --Added on 14-MAR-2018

         ILINK_ITEM_PENDING_STATUS(v_master_org_id);
        
     commit;
        
        End if;


 Exception
  When Others then
   FND_FILE.PUT_LINE(FND_FILE.LOG,'Error in Procedure ILINK_ITEM_INT_MAIN is '||SQLERRM);
   FND_FILE.PUT_LINE(FND_FILE.LOG,DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
End ILINK_ITEM_INT_MAIN;


Procedure  ILINK_ITEM_COPY_ALL_ORG(p_master_org_id In Number,p_master_org_code In Varchar2) is


/* Define a Cursor to fetch all items that need to be Inserted in Child Organizations */

Cursor get_items is
Select  eco_number,
    record_id,
    item_number,
    item_status_code_agile,
    description,
    revision,
    part_type,
    primary_uom_code,
    -- template_name_il,      -- Commented by KPIT on 23-APR-2018
    -- template_name_ep,      -- Commented by KPIT on 23-APR-2018
    template_name,            -- Added by KPIT on 23-APR-2018
    make_buy_flag_str,        -- Added by KPIT on 23-APR-2018
    custom_category_code1,
    custom_category_code2,
    custom_category_code3,
    custom_category_code4,
    custom_category_code5,   -- Added by KPIT on 23-APR-2018
    attribute1,
    attribute2,
    attribute3,
    attribute4,
    attribute5,
    attribute6,
    buyer_code,
    planner_code_str,
    eco_orig_date,
    eco_rel_date,
    organization_code,
    record_status,
    process_flag,
    creation_date,
    created_by,
    last_update_date,
    last_updated_by,
    effective_date_from  --Added on 14-MAR-2018
From ILINK_MTL_ITEMS_INT_TEMP
Where organization_code = 'ZZZ';

 --Start Commented by KPIT on 23-APR-2018 
/* Define a cursor to fetch Item and BOM Orgs from Template Definition * /

Cursor get_orgs (p_template In Varchar2) is
Select attribute1 item_orgs,
       attribute2 boms_orgs
From MTL_ITEM_TEMPLATES_ALL_V
Where template_name = p_template;

/* Define a cursor to fetch First Set Of Orgs for EP Template * /

Cursor get_map_orgs1(p_template_name In Varchar2) is
Select data_output1,
       data_output2
From ILINK_DATA_XREF
Where data_input1 = 'Item Template EP1' and
      data_input2 = p_template_name;

/* Define a cursor to fetch Second Set Of Orgs for EP Template * /

Cursor get_map_orgs2(p_template_name In Varchar2) is
Select data_output1,
       data_output2
From ILINK_DATA_XREF
Where data_input1 = 'Item Template EP2' and
      data_input2 = p_template_name;

-- Added the below cursor on 02/09/2015

/* Define a cursor to fetch Second Set Of Orgs for EP Template * /

Cursor get_map_orgs3(p_template_name In Varchar2) is
Select data_output1,
       data_output2
From ILINK_DATA_XREF
Where data_input1 = 'Item Template EP3' and
      data_input2 = p_template_name;                      -- End 02/09/2015
      
      
 --End of Commented by KPIT on 23-APR-2018       

/* Define a cursor to fecth Org ID */

Cursor get_org_id(p_org_code In Varchar2) is
Select organization_id,
       cost_of_sales_account,
       sales_account,
       encumbrance_account,
       expense_account
From MTL_PARAMETERS
Where organization_code = p_org_code;

 --Start Commented by KPIT on 23-APR-2018 
 
/* Define a cursor to fetch planner Flag * /

Cursor get_planner_flag(p_bom_org In Varchar2,p_org_code In Varchar2) is
Select 'Y'
From ILINK_DATA_XREF
Where data_input1 = 'Planner By BOM Org' and
      p_bom_org like '%'||data_input2||'%' and
      (data_output1 = p_org_code or data_output1 = 'ALL');

/* Define a cursor to fetch Default Planner Code * /

Cursor get_default_planner(p_bom_org In Varchar2) is
Select data_output1
From ILINK_DATA_XREF
Where data_input1 = 'Default Planner Code' and
      p_bom_org like '%'||data_input2||'%';

/* Define a cursor to fetch buyer Flag * /

Cursor get_buyer_flag(p_bom_org In Varchar2,p_org_code In Varchar2) is
Select 'Y'
From ILINK_DATA_XREF
Where data_input1 = 'Buyer By BOM Org' and
      p_bom_org like '%'||data_input2||'%' and
      data_output1 = p_org_code;

--Start Commented by KPIT on 23-APR-2018  */


/* Define a cursor to fetch Item Orgs,Common BOM Org(s) ,Planner,Buyer ,Make/Buy and Receipt Routing from view Definition for product family is blank */

Cursor get_orgs (p_design_location In Varchar2,p_template In Varchar2,p_item_type In Varchar2,p_line_of_business In Varchar2,p_technology In Varchar2,p_product_family In Varchar2) is
select xx_organization_code organization_code ,
       yes_or_no common_bom_flag,
       xx_planner_code view_planner,
       xx_buyer view_buyer,
       xx_make_buy view_make_buy,
       xx_receipt_routing receipt_routing,
	   xx_atp_rule           atp_rule                          -- Added by Birlasoft on 08/16/2019
from q_xx_ilink_v
where xx_design_control_location = p_design_location
  and xx_item_template  = p_template 
  and xx_item_type_ph   = p_item_type
  and xx_line_of_business_ph = p_line_of_business
  and xx_technology_ph = p_technology
  and xx_product_family_ph is null;
  
/* Define a cursor to fetch Item Orgs,Common BOM Org(s) ,Planner,Buyer ,Make/Buy and Receipt Routing from view Definition for product family is not blank*/

Cursor get_orgs1 (p_design_location In Varchar2,p_template In Varchar2,p_item_type In Varchar2,p_line_of_business In Varchar2,p_technology In Varchar2,p_product_family In Varchar2) is
select xx_organization_code organization_code ,
       yes_or_no common_bom_flag,
       xx_planner_code view_planner,
       xx_buyer view_buyer,
       xx_make_buy view_make_buy,
       xx_receipt_routing receipt_routing,
	   xx_atp_rule           atp_rule                          -- Added by Birlasoft on 08/16/2019
from q_xx_ilink_v
where xx_design_control_location = p_design_location
  and xx_item_template  = p_template 
  and xx_item_type_ph   = p_item_type
  and xx_line_of_business_ph = p_line_of_business
  and xx_technology_ph = p_technology
  and xx_product_family_ph = p_product_family
  and xx_product_family_ph is not null;
  
/* Define a cursor to fetch BOM Org */

--Cursor get_bom_exists(p_assy_number In varchar2,p_org_id In number) is
Cursor get_bom_exists(p_assy_number In varchar2) is
Select mp.organization_code
From BOM_BILL_OF_MATERIALS bbm,
     MTL_SYSTEM_ITEMS_b msi,
     mtl_parameters mp
Where -- msi.organization_id = p_org_id and
      msi.segment1 = p_assy_number and
      bbm.organization_id = msi.organization_id and
      bbm.assembly_item_id = msi.inventory_item_id and
      mp.organization_id = msi.organization_id and
      mp.organization_id = bbm.organization_id and
      nvl(mp.attribute10,0) = 1 and
      bbm.alternate_bom_designator is NULL and
      bbm.COMMON_ORGANIZATION_ID is null and
      bill_sequence_id = common_bill_sequence_id and
      exists (Select 'x' From MTL_ORGANIZATIONS mto
              Where mto.organization_id = mp.organization_id);

v_rec_date    Date := SYSDATE;
v_org_id    Number;
v_template    Varchar2(30);
v_item_orgs    Varchar2(240);
v_bom_orgs    Varchar2(240);
v_tablen     BINARY_INTEGER;
v_table     DBMS_UTILITY.UNCL_ARRAY;
v_cogs_account    Number;
v_sales_account    Number;
v_enc_account    Number;
v_exp_account    Number;
v_planner_flag    Varchar2(1);
v_buyer_flag    Varchar2(1);
v_planner    Varchar2(100);
v_buyer        Varchar2(100);

v_item_type        Varchar2(250);         -- Added by KPIT on 23-APR-2018
v_line_of_business Varchar2(250);         -- Added by KPIT on 23-APR-2018
v_technology       Varchar2(250);         -- Added by KPIT on 23-APR-2018
v_product_family   Varchar2(250);         -- Added by KPIT on 23-APR-2018

Begin

    For c_items in get_items Loop

      --Start Commented by KPIT on 23-APR-2018 
      
     /* populate Item records for IL Orgs * /

     If c_items.attribute3 = 'IL' Then

      -- Fetch Item Orgs and BOM Orgs From EBS Template Definition

      v_item_orgs := NULL;
      v_bom_orgs := NULL;

      open get_orgs(c_items.template_name_il);
      fetch get_orgs into v_item_orgs,v_bom_orgs;
      close get_orgs;

      If v_item_orgs is NOT NULL Then

       DBMS_UTILITY.COMMA_TO_TABLE(v_item_orgs,v_tablen,v_table);

       For i in 1..v_table.count Loop

        If v_table(i) is NOT NULL Then

         v_org_id := NULL;
         v_cogs_account    := NULL;
     v_sales_account := NULL;
     v_enc_account := NULL;
     v_exp_account := NULL;
         open get_org_id(trim(v_table(i)));
         fetch get_org_id into v_org_id,v_cogs_account,v_sales_account,v_enc_account,v_exp_account;
         close get_org_id;

         If v_org_id is NOT NULL Then

          /* Fetch Planner and Buyer * /

          v_planner_flag := NULL;
          v_planner     := NULL;
          v_buyer     := NULL;

          open get_planner_flag(v_bom_orgs,trim(v_table(i)));
          fetch get_planner_flag into v_planner_flag;
          close get_planner_flag;

          If nvl(v_planner_flag,'N') = 'Y' Then
           v_planner := c_items.planner_code_str;
          Elsif nvl(v_planner_flag,'N') = 'N' Then
           open get_default_planner(v_bom_orgs);
           fetch get_default_planner into v_planner;
           close get_default_planner;
          End If;

      open get_buyer_flag(v_bom_orgs,trim(v_table(i)));
          fetch get_buyer_flag into v_buyer_flag;
          close get_buyer_flag;

          If nvl(v_buyer_flag,'N') = 'Y' Then
           v_buyer := c_items.buyer_code;
          Elsif nvl(v_buyer_flag,'N') = 'N' Then
           v_buyer := NULL;
          End If;

      Insert Into ILINK_MTL_ITEMS_INT_TEMP
        (eco_number,
        record_id,
        item_number,
        item_status_code_agile,
        description,
        revision,
        part_type,
        primary_uom_code,
        template_name_il,
        template_name_ep,
        template_name,
        item_orgs,
        bom_orgs,
        custom_category_code1,
        custom_category_code2,
        custom_category_code3,
        custom_category_code4,
        attribute1,
        attribute2,
        attribute3,
        attribute4,
        attribute5,
        attribute6,
        buyer_code,
        planner_code_str,
        cost_of_sales_acct_id,
        sales_account_id,
        encumbrance_acct_id,
        expense_account_id,
        eco_orig_date,
        eco_rel_date,
        organization_code,
        organization_id,
        set_process_id,
        record_status,
        process_flag,
        creation_date,
        created_by,
        last_update_date,
        last_updated_by,
        effective_date_from     -- Added on 14-MAR-2018
        )
      Values
           (c_items.eco_number,
        c_items.record_id,
        c_items.item_number,
        c_items.item_status_code_agile,
        c_items.description,
        c_items.revision,
        c_items.part_type,
        c_items.primary_uom_code,
        c_items.template_name_il,
        c_items.template_name_ep,
        c_items.template_name_il,
        v_item_orgs,
        v_bom_orgs,
        c_items.custom_category_code1,
        c_items.custom_category_code2,
        c_items.custom_category_code3,
        c_items.custom_category_code4,
        c_items.attribute1,
        c_items.attribute2,
        c_items.attribute3,
        c_items.attribute4,
        c_items.attribute5,
        c_items.attribute6,
        v_buyer,        -- c_items.buyer_code,
        v_planner,        -- c_items.planner_code_str,
        v_cogs_account,
        v_sales_account,
        v_enc_account,
        v_exp_account,
        c_items.eco_orig_date,
        c_items.eco_rel_date,
        trim(v_table(i)),
        v_org_id,
        0,
        c_items.record_status,
        c_items.process_flag,
        v_rec_date,
        v_user_id,
        v_rec_date,
        v_user_id,
        c_items.effective_date_from     -- Added on 14-MAR-2018
        );

          End If;        -- v_org_id is NOT NULL

       End If;        -- v_table(i) is NOT NULL

      End Loop;         -- i in 1..v_table.count

     End If;        -- item_orgs is NOT NULL

    Elsif c_items.attribute3 = 'EP' Then

      -- Fetch Item Orgs and BOM Orgs From EBS Template Definition

      v_item_orgs := NULL;
      v_bom_orgs := NULL;

      open get_orgs(c_items.template_name_ep);
      fetch get_orgs into v_item_orgs,v_bom_orgs;
      close get_orgs;

      If v_item_orgs is NOT NULL Then

       DBMS_UTILITY.COMMA_TO_TABLE(v_item_orgs,v_tablen,v_table);

       For i in 1..v_table.count Loop

        If v_table(i) is NOT NULL Then

         v_org_id := NULL;
     v_cogs_account    := NULL;
     v_sales_account := NULL;
     v_enc_account := NULL;
     v_exp_account := NULL;
         open get_org_id(trim(v_table(i)));
         fetch get_org_id into v_org_id,v_cogs_account,v_sales_account,v_enc_account,v_exp_account;
         close get_org_id;

         If v_org_id is NOT NULL Then

      Insert Into ILINK_MTL_ITEMS_INT_TEMP
        (eco_number,
        record_id,
        item_number,
        item_status_code_agile,
        description,
        revision,
        part_type,
        primary_uom_code,
        template_name_il,
        template_name_ep,
        template_name,
        item_orgs,
        bom_orgs,
        custom_category_code1,
        custom_category_code2,
        custom_category_code3,
        custom_category_code4,
        attribute1,
        attribute2,
        attribute3,
        attribute4,
        attribute5,
        attribute6,
        buyer_code,
        planner_code_str,
        cost_of_sales_acct_id,
        sales_account_id,
        encumbrance_acct_id,
        expense_account_id,
        eco_orig_date,
        eco_rel_date,
        organization_code,
        organization_id,
        set_process_id,
        record_status,
        process_flag,
        creation_date,
        created_by,
        last_update_date,
        last_updated_by,
        effective_date_from     -- Added on 14-MAR-2018
        )
      Values
           (c_items.eco_number,
        c_items.record_id,
        c_items.item_number,
        c_items.item_status_code_agile,
        c_items.description,
        c_items.revision,
        c_items.part_type,
        c_items.primary_uom_code,
        c_items.template_name_il,
        c_items.template_name_ep,
        c_items.template_name_ep,
        v_item_orgs,
        v_bom_orgs,
        c_items.custom_category_code1,
        c_items.custom_category_code2,
        c_items.custom_category_code3,
        c_items.custom_category_code4,
        c_items.attribute1,
        c_items.attribute2,
        c_items.attribute3,
        c_items.attribute4,
        c_items.attribute5,
        c_items.attribute6,
        c_items.buyer_code,
        c_items.planner_code_str,
        v_cogs_account,
        v_sales_account,
        v_enc_account,
        v_exp_account,
        c_items.eco_orig_date,
        c_items.eco_rel_date,
        trim(v_table(i)),
        v_org_id,
        0,
        c_items.record_status,
        c_items.process_flag,
        v_rec_date,
        v_user_id,
        v_rec_date,
        v_user_id,
        c_items.effective_date_from     -- Added on 14-MAR-2018
        );

          End If;        -- v_org_id is NOT NULL

       End If;        -- v_table(i) is NOT NULL

      End Loop;         -- i in 1..v_table.count

     End If;        -- item_orgs is NOT NULL

     -- Fetch First Set of Item Orgs From Mapping Table

      v_item_orgs := NULL;
      v_template := NULL;

      open get_map_orgs1(c_items.template_name_ep);
      fetch get_map_orgs1 into v_item_orgs,v_template;
      close get_map_orgs1;

      If v_item_orgs is NOT NULL Then

       DBMS_UTILITY.COMMA_TO_TABLE(v_item_orgs,v_tablen,v_table);

       For i in 1..v_table.count Loop

        If v_table(i) is NOT NULL Then

         v_org_id := NULL;
     v_cogs_account    := NULL;
     v_sales_account := NULL;
     v_enc_account := NULL;
     v_exp_account := NULL;
         open get_org_id(trim(v_table(i)));
         fetch get_org_id into v_org_id,v_cogs_account,v_sales_account,v_enc_account,v_exp_account;
         close get_org_id;

         If v_org_id is NOT NULL Then

      Insert Into ILINK_MTL_ITEMS_INT_TEMP
        (eco_number,
        record_id,
        item_number,
        item_status_code_agile,
        description,
        revision,
        part_type,
        primary_uom_code,
        template_name_il,
        template_name_ep,
        template_name,
        item_orgs,
        bom_orgs,
        custom_category_code1,
        custom_category_code2,
        custom_category_code3,
        custom_category_code4,
        attribute1,
        attribute2,
        attribute3,
        attribute4,
        attribute5,
        attribute6,
        buyer_code,
        planner_code_str,
        cost_of_sales_acct_id,
        sales_account_id,
        encumbrance_acct_id,
        expense_account_id,
        eco_orig_date,
        eco_rel_date,
        organization_code,
        organization_id,
        set_process_id,
        record_status,
        process_flag,
        creation_date,
        created_by,
        last_update_date,
        last_updated_by,
        effective_date_from     -- Added on 14-MAR-2018
        )
      Values
           (c_items.eco_number,
        c_items.record_id,
        c_items.item_number,
        c_items.item_status_code_agile,
        c_items.description,
        c_items.revision,
        c_items.part_type,
        c_items.primary_uom_code,
        c_items.template_name_il,
        c_items.template_name_ep,
        v_template,
        v_item_orgs,
        NULL,
        c_items.custom_category_code1,
        c_items.custom_category_code2,
        c_items.custom_category_code3,
        c_items.custom_category_code4,
        c_items.attribute1,
        c_items.attribute2,
        c_items.attribute3,
        c_items.attribute4,
        c_items.attribute5,
        c_items.attribute6,
        c_items.buyer_code,
        c_items.planner_code_str,
        v_cogs_account,
        v_sales_account,
        v_enc_account,
        v_exp_account,
        c_items.eco_orig_date,
        c_items.eco_rel_date,
        trim(v_table(i)),
        v_org_id,
        1,
        c_items.record_status,
        c_items.process_flag,
        v_rec_date,
        v_user_id,
        v_rec_date,
        v_user_id,
        c_items.effective_date_from     -- Added on 14-MAR-2018
        );

          End If;        -- v_org_id is NOT NULL

       End If;        -- v_table(i) is NOT NULL

      End Loop;         -- i in 1..v_table.count

     End If;        -- item_orgs is NOT NULL

     -- Fetch Second Set of Item Orgs From Mapping Table

      v_item_orgs := NULL;
      v_template := NULL;

      open get_map_orgs2(c_items.template_name_ep);
      fetch get_map_orgs2 into v_item_orgs,v_template;
      close get_map_orgs2;

      If v_item_orgs is NOT NULL Then

       DBMS_UTILITY.COMMA_TO_TABLE(v_item_orgs,v_tablen,v_table);

       For i in 1..v_table.count Loop

        If v_table(i) is NOT NULL Then

         v_org_id := NULL;
     v_cogs_account    := NULL;
     v_sales_account := NULL;
     v_enc_account := NULL;
     v_exp_account := NULL;
         open get_org_id(trim(v_table(i)));
         fetch get_org_id into v_org_id,v_cogs_account,v_sales_account,v_enc_account,v_exp_account;
         close get_org_id;

         If v_org_id is NOT NULL Then

      Insert Into ILINK_MTL_ITEMS_INT_TEMP
        (eco_number,
        record_id,
        item_number,
        item_status_code_agile,
        description,
        revision,
        part_type,
        primary_uom_code,
        template_name_il,
        template_name_ep,
        template_name,
        item_orgs,
        bom_orgs,
        custom_category_code1,
        custom_category_code2,
        custom_category_code3,
        custom_category_code4,
        attribute1,
        attribute2,
        attribute3,
        attribute4,
        attribute5,
        attribute6,
        buyer_code,
        planner_code_str,
        cost_of_sales_acct_id,
        sales_account_id,
        encumbrance_acct_id,
        expense_account_id,
        eco_orig_date,
        eco_rel_date,
        organization_code,
        organization_id,
        set_process_id,
        record_status,
        process_flag,
        creation_date,
        created_by,
        last_update_date,
        last_updated_by,
        effective_date_from     -- Added on 14-MAR-2018
        )
      Values
           (c_items.eco_number,
        c_items.record_id,
        c_items.item_number,
        c_items.item_status_code_agile,
        c_items.description,
        c_items.revision,
        c_items.part_type,
        c_items.primary_uom_code,
        c_items.template_name_il,
        c_items.template_name_ep,
        v_template,
        v_item_orgs,
        NULL,
        c_items.custom_category_code1,
        c_items.custom_category_code2,
        c_items.custom_category_code3,
        c_items.custom_category_code4,
        c_items.attribute1,
        c_items.attribute2,
        c_items.attribute3,
        c_items.attribute4,
        c_items.attribute5,
        c_items.attribute6,
        c_items.buyer_code,
        c_items.planner_code_str,
        v_cogs_account,
        v_sales_account,
        v_enc_account,
        v_exp_account,
        c_items.eco_orig_date,
        c_items.eco_rel_date,
        trim(v_table(i)),
        v_org_id,
        2,
        c_items.record_status,
        c_items.process_flag,
        v_rec_date,
        v_user_id,
        v_rec_date,
        v_user_id,
        c_items.effective_date_from     -- Added on 14-MAR-2018
        );

          End If;        -- v_org_id is NOT NULL

       End If;        -- v_table(i) is NOT NULL

      End Loop;         -- i in 1..v_table.count

     End If;        -- item_orgs is NOT NULL


     -- Added the below on 02/09/2015

     -- Fetch Third Set of Item Orgs From Mapping Table

      v_item_orgs := NULL;
      v_template := NULL;

      open get_map_orgs3(c_items.template_name_ep);
      fetch get_map_orgs3 into v_item_orgs,v_template;
      close get_map_orgs3;

      If v_item_orgs is NOT NULL Then

       DBMS_UTILITY.COMMA_TO_TABLE(v_item_orgs,v_tablen,v_table);

       For i in 1..v_table.count Loop

        If v_table(i) is NOT NULL Then

         v_org_id := NULL;
     v_cogs_account    := NULL;
     v_sales_account := NULL;
     v_enc_account := NULL;
     v_exp_account := NULL;
         open get_org_id(trim(v_table(i)));
         fetch get_org_id into v_org_id,v_cogs_account,v_sales_account,v_enc_account,v_exp_account;
         close get_org_id;

         If v_org_id is NOT NULL Then

      Insert Into ILINK_MTL_ITEMS_INT_TEMP
        (eco_number,
        record_id,
        item_number,
        item_status_code_agile,
        description,
        revision,
        part_type,
        primary_uom_code,
        template_name_il,
        template_name_ep,
        template_name,
        item_orgs,
        bom_orgs,
        custom_category_code1,
        custom_category_code2,
        custom_category_code3,
        custom_category_code4,
        attribute1,
        attribute2,
        attribute3,
        attribute4,
        attribute5,
        attribute6,
        buyer_code,
        planner_code_str,
        cost_of_sales_acct_id,
        sales_account_id,
        encumbrance_acct_id,
        expense_account_id,
        eco_orig_date,
        eco_rel_date,
        organization_code,
        organization_id,
        set_process_id,
        record_status,
        process_flag,
        creation_date,
        created_by,
        last_update_date,
        last_updated_by,
        effective_date_from     -- Added on 14-MAR-2018
        )
      Values
           (c_items.eco_number,
        c_items.record_id,
        c_items.item_number,
        c_items.item_status_code_agile,
        c_items.description,
        c_items.revision,
        c_items.part_type,
        c_items.primary_uom_code,
        c_items.template_name_il,
        c_items.template_name_ep,
        v_template,
        v_item_orgs,
        NULL,
        c_items.custom_category_code1,
        c_items.custom_category_code2,
        c_items.custom_category_code3,
        c_items.custom_category_code4,
        c_items.attribute1,
        c_items.attribute2,
        c_items.attribute3,
        c_items.attribute4,
        c_items.attribute5,
        c_items.attribute6,
        c_items.buyer_code,
        c_items.planner_code_str,
        v_cogs_account,
        v_sales_account,
        v_enc_account,
        v_exp_account,
        c_items.eco_orig_date,
        c_items.eco_rel_date,
        trim(v_table(i)),
        v_org_id,
        3,
        c_items.record_status,
        c_items.process_flag,
        v_rec_date,
        v_user_id,
        v_rec_date,
        v_user_id,
        c_items.effective_date_from     -- Added on 14-MAR-2018
        );

          End If;        -- v_org_id is NOT NULL

       End If;        -- v_table(i) is NOT NULL

      End Loop;         -- i in 1..v_table.count

     End If;        -- item_orgs is NOT NULL               -- End 02/09/2015

    End If;        -- c_items.attribute3 = 'IL'
    
     --End of Commented by KPIT on 23-APR-2018   */
     
SELECT SUBSTR (c_items.custom_category_code2,
               INSTR (c_items.custom_category_code2, '.', 1, 6) + 1
              ) item_type                                          -- Segment7
                         ,
       SUBSTR (c_items.custom_category_code2,
               1,
               INSTR (c_items.custom_category_code2, '.', 1, 1) - 1
              ) line_of_business                                   -- Segment1
                                ,
       SUBSTR (c_items.custom_category_code2,
               INSTR (c_items.custom_category_code2, '.', 1, 5) + 1,
                 (INSTR (c_items.custom_category_code2, '.', 1, 6) - 1
                 )
               - (INSTR (c_items.custom_category_code2, '.', 1, 5))
              ) technology                                         -- Segment6
                          ,
       SUBSTR (c_items.custom_category_code2,
               INSTR (c_items.custom_category_code2, '.', 1, 2) + 1,
                 (INSTR (c_items.custom_category_code2, '.', 1, 3) - 1
                 )
               - (INSTR (c_items.custom_category_code2, '.', 1, 2))
              ) product_family                                     -- Segment3
  INTO v_item_type,
       v_line_of_business,
       v_technology,
       v_product_family
  FROM DUAL;
  
         v_bom_orgs       := NULL;
           
           open get_bom_exists (c_items.item_number);
         fetch get_bom_exists into v_bom_orgs;
         close get_bom_exists;
     
    -- Added by KPIT on 23-APR-2018
    
    for c_org  in get_orgs(c_items.attribute3,c_items.template_name,v_item_type,v_line_of_business,v_technology,v_product_family)  loop
    
        v_org_id         := NULL;
        v_cogs_account     := NULL;
        v_sales_account  := NULL;
        v_enc_account    := NULL;
        v_exp_account    := NULL;
        --v_bom_orgs       := NULL;
        
       open get_org_id(trim(c_org.organization_code));
         fetch get_org_id into v_org_id,v_cogs_account,v_sales_account,v_enc_account,v_exp_account;
         close get_org_id;
         

         
         /*  
         open get_bom_exists (c_items.item_number,v_org_id);
         fetch get_bom_exists into v_bom_orgs;
         close get_bom_exists;
         
              */
    
          Insert Into ILINK_MTL_ITEMS_INT_TEMP
        (eco_number,
        record_id,
        item_number,
        item_status_code_agile,
        description,
        revision,
        part_type,
        primary_uom_code,
        -- template_name_il,
        -- template_name_ep,
        template_name,
        make_buy_flag_str,        -- Added by KPIT on 23-APR-2018
        item_orgs,
        bom_orgs,
        custom_category_code1,
        custom_category_code2,
        custom_category_code3,
        custom_category_code4,
        custom_category_code5,   -- Added by KPIT on 23-APR-2018
        attribute1,
        attribute2,
        attribute3,
        attribute4,
        attribute5,
        attribute6,
        buyer_code,
        planner_code_str,
        cost_of_sales_acct_id,
        sales_account_id,
        encumbrance_acct_id,
        expense_account_id,
        eco_orig_date,
        eco_rel_date,
        organization_code,
        organization_id,
        set_process_id,
        record_status,
        process_flag,
        creation_date,
        created_by,
        last_update_date,
        last_updated_by,
        common_bom_flag ,          -- Added by KPIT on 23-APR-2018
        view_planner,              -- Added by KPIT on 23-APR-2018
        view_buyer,                -- Added by KPIT on 23-APR-2018
        view_make_buy,             -- Added by KPIT on 23-APR-2018
        receipt_routing,           -- Added by KPIT on 23-APR-2018
		atp_rule,                  -- Added by Birlasoft on 16-AUG-2019
        effective_date_from     -- Added on 14-MAR-2018
        )
      Values
           (c_items.eco_number,
        c_items.record_id,
        c_items.item_number,
        c_items.item_status_code_agile,
        c_items.description,
        c_items.revision,
        c_items.part_type,
        c_items.primary_uom_code,
        -- c_items.template_name_il,
        -- c_items.template_name_ep,
        c_items.template_name,
        c_items.make_buy_flag_str,        -- Added by KPIT on 23-APR-2018
        v_item_orgs,
        NVL(v_bom_orgs,p_master_org_code), 
        c_items.custom_category_code1,
        c_items.custom_category_code2,
        c_items.custom_category_code3,
        c_items.custom_category_code4,
        c_items.custom_category_code5,   -- Added by KPIT on 23-APR-2018
        c_items.attribute1,
        c_items.attribute2,
        c_items.attribute3,
        c_items.attribute4,
        c_items.attribute5,
        c_items.attribute6,
        --c_items.buyer_code,                  -- Commented by KPIT on 23-APR-2018
        --c_items.planner_code_str,            -- Commented by KPIT on 23-APR-2018
        NVL(c_org.view_buyer,c_items.buyer_code),                  -- Added the NVL function by KPIT on 23-APR-2018
        NVL(c_org.view_planner,c_items.planner_code_str),          -- Added by NVL  function by  KPIT on 23-APR-2018
        v_cogs_account,
        v_sales_account,
        v_enc_account,
        v_exp_account,
        c_items.eco_orig_date,
        c_items.eco_rel_date,
        trim(c_org.organization_code),
        v_org_id,
        0,
        c_items.record_status,
        c_items.process_flag,
        v_rec_date,
        v_user_id,
        v_rec_date,
        v_user_id,
        c_org.common_bom_flag ,          -- Added by KPIT on 23-APR-2018
        c_org.view_planner,              -- Added by KPIT on 23-APR-2018
        c_org.view_buyer,                -- Added by KPIT on 23-APR-2018
        c_org.view_make_buy,             -- Added by KPIT on 23-APR-2018
        c_org.receipt_routing,           -- Added by KPIT on 23-APR-2018
		c_org.atp_rule,                  -- Added by Birlasoft on 16-AUG-2019
        c_items.effective_date_from     -- Added on 14-MAR-2018
        );
    
    end loop;   --c_org
    
    
    for c_org  in get_orgs1(c_items.attribute3,c_items.template_name,v_item_type,v_line_of_business,v_technology,v_product_family)  loop
    
        v_org_id         := NULL;
        v_cogs_account     := NULL;
        v_sales_account  := NULL;
        v_enc_account    := NULL;
        v_exp_account    := NULL;
        --v_bom_orgs       := NULL;
        
         open get_org_id(trim(c_org.organization_code));
         fetch get_org_id into v_org_id,v_cogs_account,v_sales_account,v_enc_account,v_exp_account;
         close get_org_id;
         
        /* 
         open get_bom_exists (c_items.item_number,v_org_id);
         fetch get_bom_exists into v_bom_orgs;
         close get_bom_exists;
         
         */
    
          Insert Into ILINK_MTL_ITEMS_INT_TEMP
        (eco_number,
        record_id,
        item_number,
        item_status_code_agile,
        description,
        revision,
        part_type,
        primary_uom_code,
        -- template_name_il,
        -- template_name_ep,
        template_name,
        make_buy_flag_str,        -- Added by KPIT on 23-APR-2018
        item_orgs,
        bom_orgs,
        custom_category_code1,
        custom_category_code2,
        custom_category_code3,
        custom_category_code4,
        custom_category_code5,   -- Added by KPIT on 23-APR-2018
        attribute1,
        attribute2,
        attribute3,
        attribute4,
        attribute5,
        attribute6,
        buyer_code,
        planner_code_str,
        cost_of_sales_acct_id,
        sales_account_id,
        encumbrance_acct_id,
        expense_account_id,
        eco_orig_date,
        eco_rel_date,
        organization_code,
        organization_id,
        set_process_id,
        record_status,
        process_flag,
        creation_date,
        created_by,
        last_update_date,
        last_updated_by,
        common_bom_flag ,          -- Added by KPIT on 23-APR-2018
        view_planner,              -- Added by KPIT on 23-APR-2018
        view_buyer,                -- Added by KPIT on 23-APR-2018
        view_make_buy,             -- Added by KPIT on 23-APR-2018
        receipt_routing,           -- Added by KPIT on 23-APR-2018
		atp_rule,                  -- Added by Birlasoft on 16-AUG-2019
        effective_date_from     -- Added on 14-MAR-2018
        )
     -- Values
        select 
        c_items.eco_number,
        c_items.record_id,
        c_items.item_number,
        c_items.item_status_code_agile,
        c_items.description,
        c_items.revision,
        c_items.part_type,
        c_items.primary_uom_code,
        -- c_items.template_name_il,
        -- c_items.template_name_ep,
        c_items.template_name,
        c_items.make_buy_flag_str,        -- Added by KPIT on 23-APR-2018
        v_item_orgs,
        NVL(v_bom_orgs,p_master_org_code), 
        c_items.custom_category_code1,
        c_items.custom_category_code2,
        c_items.custom_category_code3,
        c_items.custom_category_code4,
        c_items.custom_category_code5,   -- Added by KPIT on 23-APR-2018
        c_items.attribute1,
        c_items.attribute2,
        c_items.attribute3,
        c_items.attribute4,
        c_items.attribute5,
        c_items.attribute6,
        --c_items.buyer_code,                  -- Commented by KPIT on 23-APR-2018
        --c_items.planner_code_str,            -- Commented by KPIT on 23-APR-2018
        NVL(c_org.view_buyer,c_items.buyer_code),                  -- Added the NVL function by KPIT on 23-APR-2018
        NVL(c_org.view_planner,c_items.planner_code_str),          -- Added by NVL  function by  KPIT on 23-APR-2018
        v_cogs_account,
        v_sales_account,
        v_enc_account,
        v_exp_account,
        c_items.eco_orig_date,
        c_items.eco_rel_date,
        trim(c_org.organization_code),
        v_org_id,
        0,
        c_items.record_status,
        c_items.process_flag,
        v_rec_date,
        v_user_id,
        v_rec_date,
        v_user_id,
        c_org.common_bom_flag ,          -- Added by KPIT on 23-APR-2018
        c_org.view_planner,              -- Added by KPIT on 23-APR-2018
        c_org.view_buyer,                -- Added by KPIT on 23-APR-2018
        c_org.view_make_buy,             -- Added by KPIT on 23-APR-2018
        c_org.receipt_routing,           -- Added by KPIT on 23-APR-2018
		c_org.atp_rule,                  -- Added by Birlasoft on 16-AUG-2019
        c_items.effective_date_from      -- Added on 14-MAR-2018
        
        from dual
        where not exists (select 'Y' from ILINK_MTL_ITEMS_INT_TEMP itm
                          where itm.item_number = c_items.item_number
                          and itm.organization_code = trim(c_org.organization_code)
                          and itm.eco_number = c_items.eco_number);
    
    end loop;   --c_org
    

   End Loop;        -- c_items



   /* Update the organization value as master organization for each Item record in temp table along with WHO information */

     v_cogs_account := NULL;
     v_sales_account := NULL;
     v_enc_account := NULL;
     v_exp_account := NULL;
     
     open get_org_id(p_master_org_code);
     fetch get_org_id into v_org_id,v_cogs_account,v_sales_account,v_enc_account,v_exp_account;
     close get_org_id;

     Update ILINK_MTL_ITEMS_INT_TEMP a
     Set organization_code = p_master_org_code,
     organization_id = p_master_org_id,
     created_by = v_user_id,
     creation_date = v_rec_date,
     last_updated_by = v_user_id,
     last_update_date = v_rec_date,
     set_process_id = 0,
    -- template_name = Decode(attribute3,'EP',template_name_ep,'IL',template_name_il,NULL), -- Commented by  KPIT on 23-APR-2018
     cost_of_sales_acct_id = v_cogs_account,
     sales_account_id = v_sales_account,
     encumbrance_acct_id = v_enc_account,
     expense_account_id = v_exp_account,
     planner_code_str = NULL,
     buyer_code = NULL
     Where organization_code = 'ZZZ'
     and exists ( select 1 from ILINK_MTL_ITEMS_INT_TEMP b     -- Added the Exists clause(Condition) by KPIT on 23-APR-2018
                   where b.eco_number = a.eco_number and
                   b.organization_code != 'ZZZ' and
                   b.item_number = a.item_number)
     ;


   /* Update Item Master Record With BOM Orgs */

    Update ILINK_MTL_ITEMS_INT_TEMP a
    Set bom_orgs = (Select bom_orgs
                    From ILINK_MTL_ITEMS_INT_TEMP b
                    Where b.organization_code != p_master_org_code and
                          b.eco_number = a.eco_number and
                          b.item_number = a.item_number and
                          b.bom_orgs is NOT NULL and
                          rownum < 2)
    Where organization_code = p_master_org_code and
          bom_orgs is NULL;


   /* Update Planners and Buyers For Non UME and IPK */  -- Commented the below update statement by KPIT on 23-APR-2018
  /*
   Update ILINK_MTL_ITEMS_INT_TEMP
   Set planner_code_str = NULL,
       buyer_code = NULL
   Where -- organization_code not in ('IPK','UME');
       organization_code != 'UME' and
       attribute3 = 'EP'; */

       -- End of comment Commented the above update statement by KPIT on 23-APR-2018
       
   /* Delete the master org records

     Delete From ILINK_MTL_ITEMS_INT_TEMP
     Where organization_code = 'ZZZ';        */
     
     -- Added the below update statement by KPIT on 23-APR-2018
     
    update ilink_mtl_items_int_temp  a
    set common_bom_orgs = (
    select  listagg(organization_code, ' ') 
        within group (order by item_number,organization_code) as list 
    from ilink_mtl_items_int_temp b
    where common_bom_flag ='Yes'
     and a.item_number = b.item_number
       and a.eco_number  = b.eco_number
    group by item_number,eco_number);

     -- End of Added the above update statement by KPIT on 23-APR-2018

  Exception
   When Others then
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Error in Procedure ILINK_ITEM_COPY_ALL_ORG is '||SQLERRM);
    FND_FILE.PUT_LINE(FND_FILE.LOG,DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
End ILINK_ITEM_COPY_ALL_ORG;



Procedure  ILINK_ITEM_PRE_VALIDATE(p_master_org_id In Number,p_master_org_code In Varchar2) is

/* Define a Cursor to validate Item records from temp table */

Cursor get_items is
Select record_id,
       item_number,
       description,
       item_status_code_agile item_status_code,
       template_name,
       primary_uom_code,
       attribute5,
       custom_category_code1,
       custom_category_code2,
       custom_category_code3,
       custom_category_code4,
       custom_category_code5,
       custom_category_code6,
       planner_code_str,
       buyer_code,
       make_buy_flag_str,               -- Added by KPIT on 23-APR-18
       view_make_buy,                   -- Added by KPIT on 23-APR-18
       receipt_routing,                 -- Added by KPIT on 23-APR-18
	   atp_rule,                        -- Added by Birlasoft on 16-AUG-2019
       cost_of_sales_acct_id,
       sales_account_id,
       encumbrance_acct_id,
       expense_account_id,
       organization_code,
       organization_id,
       eco_number,
       eco_rel_date,
       attribute3        -- Added on 02/04/2015
From ILINK_MTL_ITEMS_INT_TEMP
Where nvl(process_flag,'N') = 'N'
Order by eco_rel_date,eco_number,record_id,item_number,organization_id;

/* Define a Cursor to Verify if the item exists in Oracle */

Cursor item_exists_oracle(p_item_number IN Varchar2,p_organization_id IN Number) is
Select inventory_item_id,
       primary_uom_code,
       item_type        -- Added on 02/04/2015
From ILINK_MTL_SYSTEM_ITEMS_VIEW
Where item_number = p_item_number and
      organization_id = p_organization_id;

/* Define a Cursor to Verify if a record for the item exists in interface table */

Cursor item_exists_intf_table(p_item_number IN Varchar2,p_organization_code IN Varchar2) is
Select item_number
From MTL_SYSTEM_ITEMS_INTERFACE
Where item_number = p_item_number and
      organization_code = p_organization_code and
      transaction_type = 'CREATE' and
      set_process_id = 0;

/* Define a Cursor to Verify if category values exist in Oracle */

Cursor valid_category_value(p_category_Set_name IN Varchar2,p_category_value IN Varchar2) is
Select mic.category_concat_segs category_value
From MTL_CATEGORY_SETS MCS,
     MTL_CATEGORIES_V MIC
Where mcs.category_set_name = p_category_Set_name and
      mcs.structure_id = mic.structure_id and
      category_concat_segs = p_category_value and
      mic.enabled_flag='Y' and
      (mic.disable_date > SYSDATE or mic.disable_date is NULL) and
      ((mcs.validate_flag = 'Y' and exists (Select 'x' From MTL_CATEGORY_SET_VALID_CATS_V mcv
                        Where mcs.category_set_id = mcv.category_set_id and
                          mic.category_concat_segs = mcv.category_concat_segments)) OR
    mcs.validate_flag = 'N');


/* Define a Cursor to Verify if Template exists in Oracle */

Cursor valid_template(p_template_name IN Varchar2) is
Select template_name
From MTL_ITEM_TEMPLATES
Where  template_name = p_template_name;

/* Define a Cursor to Verify if UOM code exists in Oracle */

Cursor valid_uom_code(p_uom_code IN Varchar2) is
Select uom_code
From MTL_UNITS_OF_MEASURE
Where (upper(uom_code) = upper(p_uom_code) or upper(unit_of_measure) = upper(p_uom_code)) and
      (disable_date is NULL or disable_date > SYSDATE);

/* Define a Cursor to Verify if Item Status exists in Oracle */

Cursor valid_item_status(p_item_status IN Varchar2) is
Select inventory_item_status_code
From MTL_ITEM_STATUS
Where (inventory_item_status_code = p_item_status OR inventory_item_status_code_tl = p_item_status) and
      (disable_date is NULL or disable_date > SYSDATE);

/* Define a Cursor to Verify if Planner Code exists in Oracle          */

Cursor valid_planner_code(p_planner_code IN Varchar2,p_org_id In Number) is
Select planner_code
From MTL_PLANNERS
Where planner_code = upper(p_planner_code) and
      organization_id = p_org_id and
      (disable_date is NULL or disable_date > SYSDATE);

/* Define a Cursor to Verify if Planner Code exists in Oracle

Cursor valid_planner_code(p_planner_code IN Varchar2,p_org_id In Number) is
Select planner_code
From MTL_PLANNERS a,
     PER_ALL_PEOPLE_F b
Where upper(b.order_name) = upper(p_planner_code) and
      a.employee_id = b.person_id and
      a.organization_id = p_org_id and
      (disable_date is NULL or disable_date > SYSDATE);        */

/* Define Cursor to Verify if Buyer code exists in Oracle */

 Cursor valid_buyer_code(p_buyer_code IN varchar2,p_organization_id IN number) is
 select poa.agent_id
 from PO_AGENTS poa,
      PER_ALL_PEOPLE_F pap,
      HR_ALL_ORGANIZATION_UNITS hao
 where -- upper(pap.last_name||pap.first_name) = Replace(Replace(upper(p_buyer_code),' '),',') and
       upper(pap.full_name) = upper(p_buyer_code) and
       poa.agent_id = pap.person_id and
       pap.business_group_id = hao.business_group_id and
       hao.organization_id = p_organization_id and
       (poa.end_date_active is null or poa.end_date_active > SYSDATE);

/* Define a cursor to verify if an item exists on earlier released ECOs */

Cursor item_prior_eco(p_item_no In Varchar2,p_eco_no In Varchar2,p_eco_rel_date In Date) is
Select eco_number
From ILINK_MTL_ITEMS_INT_TEMP
Where item_number = p_item_no and
      eco_number != p_eco_no and
      eco_rel_date < p_eco_rel_date;

/* Define a Cursor to fetch the vlaue set for descriptive flexfield segment */

Cursor get_dff_value_set (p_col_name In Varchar2) is
Select fdc.flex_value_set_id
From FND_DESCR_FLEX_COL_USAGE_VL fdc
Where fdc.descriptive_flexfield_name = 'MTL_SYSTEM_ITEMS' and
      fdc.application_column_name = p_col_name;

/* Define a Cursor to fetch the descriptive flexfield segment LOV values */

Cursor get_dff_value (p_flex_set_id In Number,p_value In Varchar2) is
Select ffl.flex_value
From FND_FLEX_VALUES ffl
Where ffl.flex_value_set_id = p_flex_set_id and
      upper(ffl.flex_value) = upper(p_value);

/* Define a Cursor to fetch Account ID */
Cursor get_acct_id (p_prd_line In Varchar2,p_account_id In Number) is
Select b.code_combination_id
From GL_CODE_COMBINATIONS a,
     GL_CODE_COMBINATIONS b
Where a.code_combination_id = p_account_id and
      a.segment1 = b.segment1 and
      a.segment2 = b.segment2 and
      a.segment3 = b.segment3 and
      a.segment4 = b.segment4 and
      b.segment5 = p_prd_line and
      a.segment6 = b.segment6 and
      a.segment7 = b.segment7 and
      a.segment8 = b.segment8 and
      a.segment9 = b.segment9;

-- Added the below cursor on 02/04/2015 to fetch item type of a template
Cursor get_template_item_type(p_template_name In Varchar2) is
Select a.attribute_value
From MTL_ITEM_TEMPL_ATTRIBUTES a,
     MTL_ITEM_TEMPLATES b
Where b.template_name = p_template_name and
      a.template_id = b.template_id and
      a.attribute_name = 'MTL_SYSTEM_ITEMS.ITEM_TYPE';
      
-- Added the below cursor on 23/04/2018 to fetch Planning make by code
Cursor get_make_buy_code(p_meaning In Varchar2) is
select lookup_code from fnd_lookup_values a 
where meaning = p_meaning
and lookup_type ='MTL_PLANNING_MAKE_BUY'
and language ='US'
and enabled_flag ='Y';

-- Added the below cursor on 23/04/2018 to fetch Planning make by code

Cursor get_receipt_routing(p_meaning In Varchar2) is
select lookup_code from fnd_lookup_values a 
where meaning = p_meaning
and lookup_type ='EGO_EF_ReceiptRoutVS_TYPE'
and language ='US'
and enabled_flag ='Y';

-- Added the below cursor on 16/08/2019 to fetch ATP Rule
/* Define a Cursor to Verify if ATP Rule exists in Oracle */
Cursor get_atp_rule(p_rule_name IN Varchar2) is
select rule_id from mtl_atp_rules
where (rule_name = p_rule_name or description = p_rule_name );

v_item_id               Number;
v_item_number           Varchar2(40);
v_uom_code              Varchar2(10);
v_item_status           Varchar2(10);
v_template_name         Varchar2(150);
v_status_flag           Varchar2(1);
v_error_text            Varchar2(4000);
v_warning_text          Varchar2(4000);
v_transaction_type      Varchar2(10);
v_old_uom                Varchar2(10);
v_prior_eco                Varchar2(10);
v_planner_code            Varchar2(100);
v_buyer_id                Number;
v_planning_make_buy     Number;            -- Added by KPIT on 23-APR-2018
v_custom_cat1        Varchar2(260);
v_custom_cat2        Varchar2(260);
v_custom_cat3        Varchar2(260);
v_custom_cat4        Varchar2(260);
v_custom_cat5        Varchar2(260);
v_custom_cat6        Varchar2(260);
v_sales_account        Number;
v_cogs_account        Number;
v_enc_account        Number;
v_exp_account        Number;
v_ebs_item_type        Varchar2(30);    -- Added on 02/04/2015
v_templ_item_type    Varchar2(30);    -- Added on 02/04/2015
v_receipt_routing_id   Number;         -- Added on 23/APR/2018
v_atp_rule_id          Number;         -- Added on 16/AUG/2019

Begin

    /* Begin Processing all the records from the temp table */

    For c_items in get_items Loop

        v_error_text         := NULL;
        v_warning_text        := NULL;
        v_status_flag         := 'S';
        v_transaction_type     := NULL;

        v_uom_code         := NULL;
        v_template_name     := NULL;
        v_item_id         := NULL;
        v_item_status         := NULL;
    v_old_uom         := NULL;
    v_custom_cat1        := NULL;
    v_custom_cat2        := NULL;
    v_custom_cat3        := NULL;
    v_custom_cat4        := NULL;
    v_custom_cat5        := NULL;
    v_custom_cat6        := NULL;
    v_planner_code        := NULL;
    v_buyer_id            := NULL;
    v_planning_make_buy := NULL;   -- Added by KPIT on 23-APR-2018
    v_sales_account        := NULL;
    v_cogs_account        := NULL;
    v_enc_account        := NULL;
    v_exp_account        := NULL;
    v_ebs_item_type        := NULL;    -- Added on 02/04/2015
    v_templ_item_type    := NULL;      -- Added on 02/04/2015
    v_receipt_routing_id := NULL;      -- Added on 23/APR/2018
	v_atp_rule_id        := NULL;      -- Added on 16/AUG/2019
    
    
    --Added by KPIT on 23-APR-2018
    
    If c_items.organization_code = 'ZZZ' then
    
    v_status_flag := 'E';
    
    Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Missing the Org Combination(s) in the View ' into v_error_text From DUAL;
    
    END If;
    
   -- End of --Added by KPIT on 23-APR-2018
   
        /*  Verify if Item exists in Oracle or if Item Exists in Interface table */

        open item_exists_oracle(c_items.item_number,c_items.organization_id);
        fetch item_exists_oracle into v_item_id,v_old_uom,v_ebs_item_type;        -- Added v_ebs_item_type on 02/04/2015;
        If item_exists_oracle%NOTFOUND Then
          open item_exists_intf_table(c_items.item_number,c_items.organization_code);
          fetch item_exists_intf_table into v_item_number;

          /* Item not found in Oracle or Interface table so transaction type is "CREATE" (create a new item in Oracle) */

          If item_exists_intf_table%notfound Then
            v_transaction_type := 'CREATE';
          Else  /* A record exists in Interface table with transaction Type "CREATE" so transaction type is "UPDATE" */
            v_transaction_type := 'UPDATE';
          End If;
          close item_exists_intf_table;
        Else    /* Item exists in Oracle so transaction type is "UPDATE" */
          v_transaction_type := 'UPDATE';
        End If;
        close item_exists_oracle;


        /*  Validate UOM code */

    -- If c_items.primary_uom_code is NOT NULL then
        open valid_uom_code(c_items.primary_uom_code);
        fetch valid_uom_code into v_uom_code;
        If valid_uom_code%NOTFOUND Then
          If v_transaction_type = 'UPDATE' Then
           v_status_flag := 'W';
          Select decode(v_warning_text,NULL,'',v_warning_text||' , ')||'UOM:Cannot Update Unit Of Measure' into v_warning_text From DUAL;
          Else
       v_status_flag := 'E';
           Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Unit Of Measure' into v_error_text From DUAL;
          End If;
        Elsif (valid_uom_code%FOUND) and (v_transaction_type = 'UPDATE') and (upper(v_uom_code) != upper(v_old_uom)) Then
          v_status_flag := 'W';
      Select decode(v_warning_text,NULL,'',v_warning_text||' , ')||'UOM:Cannot Update Unit Of Measure' into v_warning_text From DUAL;
        End If;
        close valid_uom_code;
        -- End If;


        /* Validate Item Status */

        open valid_item_status(c_items.item_status_code);
        fetch valid_item_status into v_item_status;
        If valid_item_status%NOTFOUND Then
          v_status_flag := 'E';
          Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Item Status Code - '||c_items.item_status_code into v_error_text From DUAL;
        End If;
        close valid_item_status;


        /* Validate Template */

        If v_transaction_type = 'CREATE' Then
     open valid_template(c_items.template_name);
         fetch valid_template into v_template_name;
         If valid_template%NOTFOUND then
          v_status_flag := 'E';
          Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Template - '||c_items.template_name into v_error_text From DUAL;
         End If;
         close valid_template;
        End If;


    /* Validate Planner */

        If c_items.planner_code_str is NOT NULL and v_transaction_type = 'CREATE' Then
     open valid_planner_code(c_items.planner_code_str,c_items.organization_id);
         fetch valid_planner_code into v_planner_code;
         If valid_planner_code%NOTFOUND then
          v_status_flag := 'E';
          Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Planner Code - '||c_items.planner_code_str into v_error_text From DUAL;
         End If;
         close valid_planner_code;
        End If;


    /* Validate Buyer */

        If c_items.buyer_code is NOT NULL and v_transaction_type = 'CREATE' Then
     open valid_buyer_code(c_items.buyer_code,c_items.organization_id);
         fetch valid_buyer_code into v_buyer_id;
         If valid_buyer_code%NOTFOUND then
          v_status_flag := 'E';
          Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Buyer Code - '||c_items.buyer_code into v_error_text From DUAL;
         End If;
         close valid_buyer_code;
        End If;
        
    /* Validate Planning make Buy */ -- Added the below validation on 23_APR-2018

        If (c_items.make_buy_flag_str is NOT NULL or c_items.view_make_buy is not null)  and v_transaction_type = 'CREATE' Then
         open get_make_buy_code(NVL(c_items.view_make_buy,c_items.make_buy_flag_str));
         fetch get_make_buy_code into v_planning_make_buy;
         If get_make_buy_code%NOTFOUND then
          v_status_flag := 'E';
          Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Planning Make/Buy Code - '||NVL(c_items.view_make_buy,c_items.make_buy_flag_str) into v_error_text From DUAL;
         End If;
         close get_make_buy_code;
        End If;        
        
        -- Added the below validation on 23_APR-2018
        
        If c_items.make_buy_flag_str is NOT NULL   and v_transaction_type = 'UPDATE' Then
         open get_make_buy_code(c_items.make_buy_flag_str);
         fetch get_make_buy_code into v_planning_make_buy;
         If get_make_buy_code%NOTFOUND then
          v_status_flag := 'E';
          Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Planning Make/Buy Code - '||c_items.make_buy_flag_str into v_error_text From DUAL;
         End If;
         close get_make_buy_code;
        End If;        

        
        -- Added the below validation on 23_APR-2018
        
        If c_items.receipt_routing is NOT NULL  Then
         open get_receipt_routing(c_items.receipt_routing);
         fetch get_receipt_routing into v_receipt_routing_id;
         If get_receipt_routing%NOTFOUND then
          v_status_flag := 'E';
          Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Receipt Routing - '||c_items.receipt_routing into v_error_text From DUAL;
         End If;
         close get_receipt_routing;
        End If;            
		
        -- Added the below validation on 16_AUG-2019
        
        If c_items.atp_rule is NOT NULL  Then
         open get_atp_rule(c_items.atp_rule);
         fetch get_atp_rule into v_atp_rule_id;
         If get_atp_rule%NOTFOUND then
          v_status_flag := 'E';
          Select decode(v_error_text,NULL,'',v_error_text||' , ')||'ATP Rule - '||c_items.atp_rule into v_error_text From DUAL;
         End If;
         close get_atp_rule;
        End If;   		

        /* Validate And Derive Accounts */

        If v_transaction_type = 'CREATE' and c_items.organization_id = p_master_org_id Then

         -- Sales Account

         open get_acct_id(c_items.attribute5,c_items.sales_account_id);
         fetch get_acct_id into v_sales_account;
         If get_acct_id%NOTFOUND Then
          v_sales_account := c_items.sales_account_id;
         End If;
         close get_acct_id;

     -- Cost Of Sales Account

         open get_acct_id(c_items.attribute5,c_items.cost_of_sales_acct_id);
         fetch get_acct_id into v_cogs_account;
         If get_acct_id%NOTFOUND Then
          v_cogs_account := c_items.cost_of_sales_acct_id;
         End If;
         close get_acct_id;

        /* -- Encumbrance Account

         open get_acct_id(c_items.attribute5,c_items.encumbrance_acct_id);
         fetch get_acct_id into v_enc_account;
         If get_acct_id%NOTFOUND Then
          v_enc_account := c_items.encumbrance_acct_id;
         End If;
         close get_acct_id;

    -- Expense Account

         open get_acct_id(c_items.attribute5,c_items.expense_account_id);
         fetch get_acct_id into v_exp_account;
         If get_acct_id%NOTFOUND Then
          v_exp_account := c_items.expense_account_id;
         End If;
         close get_acct_id;             */

        End If;    -- Vaidate Accounts


    /* Validate Custom Category Code1  */

    If c_items.custom_category_code1 is NOT NULL and v_transaction_type = 'CREATE' Then

    open valid_category_value(v_cust_cat1_set_name,c_items.custom_category_code1);
    fetch valid_category_value into v_custom_cat1;
    If valid_category_value%NOTFOUND then
      v_status_flag := 'W';
      Select decode(v_warning_text,NULL,'',v_warning_text||' , ')||'Category Code:'||ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Category Set Name','Custom Category Set1',NULL,NULL,NULL)||' - '||c_items.custom_category_code1 into v_warning_text From DUAL;
      v_custom_cat1 := ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Default Category Value','Custom Category Set1',NULL,NULL,NULL);
    End If;
    close valid_category_value;

    End If;


    /* Validate Custom Category Code2  */

    If c_items.custom_category_code2 is NOT NULL and v_transaction_type = 'CREATE' Then

    open valid_category_value(v_cust_cat2_set_name,c_items.custom_category_code2);
    fetch valid_category_value into v_custom_cat2;
    If valid_category_value%NOTFOUND then
      v_status_flag := 'W';
      Select decode(v_warning_text,NULL,'',v_warning_text||' , ')||'Category Code:'||ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Category Set Name','Custom Category Set2',NULL,NULL,NULL)||' - '||c_items.custom_category_code2 into v_warning_text From DUAL;
      v_custom_cat2 := ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Default Category Value','Custom Category Set2',NULL,NULL,NULL);
    End If;
    close valid_category_value;

    End If;


    /* Validate Custom Category Code3  */

    If c_items.custom_category_code3 is NOT NULL and v_transaction_type = 'CREATE' Then

    open valid_category_value(v_cust_cat3_set_name,c_items.custom_category_code3);
    fetch valid_category_value into v_custom_cat3;
    If valid_category_value%NOTFOUND then
      v_status_flag := 'W';
      Select decode(v_warning_text,NULL,'',v_warning_text||' , ')||'Category Code:'||ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Category Set Name','Custom Category Set3',NULL,NULL,NULL)||' - '||c_items.custom_category_code3 into v_warning_text From DUAL;
      -- v_custom_cat3 := ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Default Category Value','Custom Category Set3',NULL,NULL,NULL);
    End If;
    close valid_category_value;

    End If;


    /* Validate Custom Category Code4  */

    If c_items.custom_category_code4 is NOT NULL and v_transaction_type = 'CREATE' Then

    open valid_category_value(v_cust_cat4_set_name,c_items.custom_category_code4);
    fetch valid_category_value into v_custom_cat4;
    If valid_category_value%NOTFOUND then
      v_status_flag := 'E';
      Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Category Code:'||ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Category Set Name','Custom Category Set4',NULL,NULL,NULL)||' - '||c_items.custom_category_code4 into v_error_text From DUAL;
    End If;
    close valid_category_value;

    End If;
    
    /* Validate Custom Category Code5 */   -- Added by KPIT on 23-APR-2018

    If c_items.custom_category_code5 is NOT NULL and v_transaction_type = 'CREATE' Then

    open valid_category_value(v_cust_cat5_set_name,c_items.custom_category_code5);
    fetch valid_category_value into v_custom_cat5;
    If valid_category_value%NOTFOUND then
      v_status_flag := 'E';
      Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Category Code:'||ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Category Set Name','Custom Category Set5',NULL,NULL,NULL)||' - '||c_items.custom_category_code5 into v_error_text From DUAL;
    End If;
    close valid_category_value;

    End If;          -- End of Added by KPIT on 23-APR-2018


    /* Validate Custom Category Code6

    If c_items.custom_category_code6 is NOT NULL Then

    open valid_category_value(v_cust_cat6_set_name,c_items.custom_category_code6);
    fetch valid_category_value into v_custom_cat6;
    If valid_category_value%NOTFOUND then
      v_status_flag := 'E';
      Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Category Code:'||ILINK_XML_INTERFACE_PKG.ILINK_DATA_XREF('Category Set Name','Custom Category Set6',NULL,NULL,NULL)||' - '||c_items.custom_category_code6 into v_error_text From DUAL;
    End If;
    close valid_category_value;

    End If;     */


       /* Verify if an item exists on earlier released ECOs */

    v_prior_eco := NULL;
    open item_prior_eco(c_items.item_number,c_items.eco_number,c_items.eco_rel_date);
    fetch item_prior_eco into v_prior_eco;
    If item_prior_eco%FOUND Then
     v_status_flag := 'E';
     Select decode(v_error_text,NULL,'',v_error_text||' , ')||'Item Exists on an Earlier Released ECO '||v_prior_eco into v_error_text From DUAL;
        End If;
        close item_prior_eco;

    -- Added the below on 02/04/2015 to verify item type of Agile's template vs EBS

    If v_transaction_type = 'UPDATE' and c_items.template_name is NOT NULL and
        --c_items.organization_id = p_master_org_id and c_items.attribute3 = 'IL' Then  -- Commented By KPIT on 23-APR-2018
        c_items.organization_id = p_master_org_id  Then                                 -- Added By KPIT on 23-APR-2018
     open get_template_item_type(c_items.template_name);
     fetch get_template_item_type into v_templ_item_type;
     close get_template_item_type;
     If nvl(v_templ_item_type,'!') != nvl(v_ebs_item_type,'!') Then
      v_status_flag := 'W';
      Select decode(v_warning_text,NULL,'',v_warning_text||' , ')||'EBS Item Type '||v_ebs_item_type||' does not match with Item Type '||v_templ_item_type
          ||' of Agile template '||c_items.template_name into v_warning_text From DUAL;
     End If;
    End If;        -- End 02/04/2015


      /* If all the validations succeeded then mark the record as "Validated" */

        If v_status_flag in ('S','W') Then

          Update ILINK_MTL_ITEMS_INT_TEMP
          Set -- primary_uom_code = v_uom_code,
              planner_code = v_planner_code,
              buyer_id = v_buyer_id,
              custom_category_code1 = v_custom_cat1,
              custom_category_code2 = v_custom_cat2,
              custom_category_code3 = v_custom_cat3,
               cost_of_sales_acct_id = v_cogs_account,
              sales_account_id = v_sales_account,
                 encumbrance_acct_id = v_enc_account,
                 expense_account_id = v_exp_account,
                 item_status_code_agile = v_item_status,
              make_buy_flag          = v_planning_make_buy,    -- Added by KPIT on 23-APR-2018
              receipt_routing_id     = v_receipt_routing_id,   -- Added by KPIT on 23-APR-2018
			  atp_rule_id            = v_atp_rule_id,          -- Added by Birlasoft on 16-AUG-2019
              record_status = 'Validated',
          process_flag = 'Y',
          processed_date = SYSDATE,
              inventory_item_id = v_item_id,
          validation_date = SYSDATE,
              warning_message = decode(v_warning_text,NULL,NULL,'WARNING: Check Field(s) :'||v_warning_text)
          Where eco_number = c_items.eco_number and
                item_number = c_items.item_number and
                organization_id = c_items.organization_id;

      /* If any of the validations failed then mark the record as "Error" */

        Elsif v_status_flag = 'E' Then

          Update ILINK_MTL_ITEMS_INT_TEMP
          Set record_status = 'Error',
          process_flag = 'Y',
          processed_date = SYSDATE,
              error_message = error_message||'Error: Invalid value in field(s):'||v_error_text,
          warning_message = decode(v_warning_text,NULL,NULL,'Warning: Check Field(s) :'||v_warning_text)
      Where eco_number = c_items.eco_number and
            item_number = c_items.item_number and
                organization_code = c_items.organization_code;

        End If;        -- v_status_flag = 'E'

    End Loop;

        -- Mark item records as Error when it fais at Master Org

        Update ILINK_MTL_ITEMS_INT_TEMP a
        Set record_status = 'Error'
        Where a.record_status = 'Validated' and
              a.organization_id != p_master_org_id and
              exists (Select 'x' From ILINK_MTL_ITEMS_INT_TEMP b
                        Where a.eco_number = b.eco_number and
                              a.item_number = b.item_number and
                              b.organization_id = p_master_org_id and
                              b.record_status = 'Error');

  Exception
   When Others then
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Error in Procedure ILINK_ITEM_PRE_VALIDATE is '||SQLERRM);
    FND_FILE.PUT_LINE(FND_FILE.LOG,DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);

End ILINK_ITEM_PRE_VALIDATE;


Procedure  ILINK_ITEM_INSERT_INT(p_master_org_id In Number,p_master_org_code In Varchar2) is

/* Define a Cursor to fetch "Validated" records From temp table */

Cursor get_valid_items is
Select  item_number,
    eco_number,
        description,
        primary_uom_code,
        template_name,
        item_status_code_agile,
        organization_code,
        organization_id,
        inventory_item_id,
        attribute1,
        attribute2,
        Decode(attribute6,NULL,NULL,'Y') hazard_flag,
        custom_category_code1,
        custom_category_code2,
        custom_category_code3,
    custom_category_code4,
    custom_category_code5,
    custom_category_code6,
    planner_code,
    buyer_id,
    cost_of_sales_acct_id,
    sales_account_id,
    encumbrance_acct_id,
    expense_account_id,
    make_buy_flag,                  -- Added by KPIT on 23-APR-2018
    common_bom_flag,                -- Added by KPIT on 23-APR-2018
    receipt_routing_id,             -- Added by KPIT on 23-APR-2018
	atp_rule_id,                    -- Added by Birlasoft on 16-AUG-2019
    set_process_id,
        transaction_type,
        record_id,
    creation_date,
    validation_date,
    effective_date_from      -- Added on 14-MAR-2018
From ILINK_MTL_ITEMS_INT_TEMP
Where record_status = 'Validated'
Order by eco_rel_date,eco_number,record_id,item_number,organization_id;

/* Define a Cursor to determine if any unprocessed records exist in Interface table From previous RUN */

Cursor get_record_count(p_item_number IN Varchar2,p_organization_code IN Varchar2,p_transaction_type IN Varchar2) is
Select count (*)
From MTL_SYSTEM_ITEMS_INTERFACE
Where item_number = p_item_number and
      organization_code = p_organization_code and
      transaction_type = p_transaction_type and
      set_process_id = 0;


/* Define a Cursor to retreive current item attributes to determine if an UPDATE is necessary */

Cursor get_item_attributes(p_item_number IN Varchar2,p_organization_id IN Number) is
Select description,
       inventory_item_status_code,
       attribute2,
       buyer_id,
       planner_code,
       hazardous_material_flag,
       planning_make_buy_code,     -- Added by KPIT on 23-APR-2018
       receiving_routing_id,        -- Added by KPIT on 23-APR-2018
	   atp_rule_id                  -- Added by Birlasoft on 16-AUG-2019
From ILINK_MTL_SYSTEM_ITEMS_VIEW
Where organization_id = p_organization_id and
      item_number = p_item_number;

/* Define a Cursor to Verify if the item exists in Oracle */

Cursor item_exists_oracle(p_item_number IN Varchar2,p_organization_id IN Number) is
Select inventory_item_id
From ILINK_MTL_SYSTEM_ITEMS_VIEW
Where item_number = p_item_number and
      organization_id = p_organization_id;

/* Define a Cursor to Verify if a record for the item exists in interface table */

Cursor item_exists_intf_table(p_item_number IN Varchar2,p_organization_code IN Varchar2) is
Select item_number
From MTL_SYSTEM_ITEMS_INTERFACE
Where item_number = p_item_number and
      organization_code = p_organization_code and
      transaction_type = 'CREATE' and
      set_process_id = 0;

/* Define a Cursor to fetch and verify category value */

Cursor get_category_code (p_category_set_name IN Varchar2,p_organization_id IN Number,
                p_inventory_item_id IN Number,p_cat_value In Varchar2) is
Select mc.category_concat_segs category_value
From MTL_CATEGORY_SETS MCS,
     MTL_CATEGORIES_V MC,
     MTL_ITEM_CATEGORIES MIC
Where mcs.category_set_name = p_category_set_name and
      mic.organization_id = p_organization_id and
      mic.inventory_item_id = p_inventory_item_id and
      mcs.category_set_id = mic.category_set_id and
      mic.category_id = mc.category_id and
      (mc.category_concat_segs = p_cat_value OR p_cat_value is NULL);

/* Define a Cursor to detemine if a category value is controlled at master org or indvidual org level */

Cursor get_category_control_level (p_category_set_name IN Varchar2) is
Select control_level
From MTL_CATEGORY_SETS
Where category_set_name = p_category_set_name;


v_error_message         Varchar2(4000);
v_warning_message    Varchar2(4000);
v_count_records         Number;
v_description           Varchar2(240);
v_item_status           Varchar2(30);
v_update_flag        Varchar2(1);
v_cat_update_flag    Varchar2(1);
v_item_number        Varchar2(40);
v_transaction_type    Varchar2(20);
v_item_id        Number;
v_txn_type        Varchar2(10);
v_cust1_category    Varchar2(260);
v_cust2_category    Varchar2(260);
v_cust3_category    Varchar2(260);
v_cust4_category    Varchar2(260);
v_cust5_category    Varchar2(260);
v_cust6_category    Varchar2(260);
v_cust1ctl_level        Number;
v_cust2ctl_level        Number;
v_cust3ctl_level        Number;
v_cust4ctl_level        Number;
v_cust5ctl_level        Number;
v_cust6ctl_level        Number;
v_attribute2        Varchar2(240);
v_buyer_id        Number;
v_planner_code        Varchar2(30);
v_hazard_flag        Varchar2(30);
v_itm_pen_status        Varchar2(1);       -- Added on 14-Mar-2018
v_planning_make_buy_code Number;           -- Added on 23-APR-2018
v_receiving_routing_id   Number;        -- Added by KPIT on 23-APR-2018
v_atp_rule_id            Number;        -- Added by Birlasoft on 16-AUG-2019


Begin


 /* Check if Custom Category code1 is controlled at Master org or at Indvidual Org level */

   open get_category_control_level (v_cust_cat1_set_name);
   fetch get_category_control_level into v_cust1ctl_level;
   close get_category_control_level;

  /* Check if Custom Category code2 is controlled at Master org or at Indvidual Org level */

   open get_category_control_level (v_cust_cat2_set_name);
   fetch get_category_control_level into v_cust2ctl_level;
   close get_category_control_level;

  /* Check if Custom Category code3 is controlled at Master org or at Indvidual Org level */

   open get_category_control_level (v_cust_cat3_set_name);
   fetch get_category_control_level into v_cust3ctl_level;
   close get_category_control_level;

  /* Check if Custom Category code4 is controlled at Master org or at Indvidual Org level */

   open get_category_control_level (v_cust_cat4_set_name);
   fetch get_category_control_level into v_cust4ctl_level;
   close get_category_control_level;

  /* Check if Custom Category code5 is controlled at Master org or at Indvidual Org level */

   open get_category_control_level (v_cust_cat5_set_name);
   fetch get_category_control_level into v_cust5ctl_level;
   close get_category_control_level;                  

  /* Check if Custom Category code6 is controlled at Master org or at Indvidual Org level

   open get_category_control_level (v_cust_cat6_set_name);
   fetch get_category_control_level into v_cust6ctl_level;
   close get_category_control_level;                  */

  /* Begin processing of "Validated" records from temp table */

  For c_valid_items in get_valid_items Loop

        /*  Verify if Item exists in Oracle or if Item Exists in Interface table */

    v_item_id := NULL;
        open item_exists_oracle(c_valid_items.item_number,C_valid_items.organization_id);
        fetch item_exists_oracle into v_item_id;
        If item_exists_oracle%NOTFOUND Then
          open item_exists_intf_table(c_valid_items.item_number,C_valid_items.organization_code);
          fetch item_exists_intf_table into v_item_number;

          /* Item not found in Oracle or Interface table so set transaction type as "CREATE" (create a new item in Oracle) */

          If item_exists_intf_table%notfound Then
            v_transaction_type := 'CREATE';
          Else  /* A record exists in Interface table with transaction Type "CREATE" so set transaction type as "UPDATE" */
            v_transaction_type := 'UPDATE';
          End If;
          close item_exists_intf_table;
        Else    /* Item exists in Oracle so set transaction type as "UPDATE" */
          v_transaction_type := 'UPDATE';
        End If;
        close item_exists_oracle;


        /* Perform checks for transaction type as CREATE (new item) */

        If v_transaction_type = 'CREATE' Then

          v_count_records :=0;
          open get_record_count(c_valid_items.item_number,c_valid_items.organization_code,'CREATE');
          fetch get_record_count into v_count_records;
          close get_record_count;

          If v_count_records = 0 Then   /* No CREATE record exists for item in Interface table */

           /* Insert item Record into Item Interface table as CREATE (New Item) */

             Insert into MTL_SYSTEM_ITEMS_INTERFACE
                (transaction_type,
        item_number,
        organization_code,
        organization_id,
        description,
        inventory_item_status_code,
        primary_uom_code,
        template_name,
        attribute2,
        buyer_id,
        planner_code,
        hazardous_material_flag,
        cost_of_sales_account,
               sales_account,
               encumbrance_account,
               expense_account,
            planning_make_buy_code,                  -- Added by KPIT on 23-APR-2018
            receiving_routing_id ,                   -- Added by KPIT on 23-APR-2018
			atp_rule_id,                             -- Added by Birlasoft on 16-AUG-2019
        set_process_id,
        created_by,
        creation_date,
        process_flag
        )
             Values
                ('CREATE',
        c_valid_items.item_number,
        c_valid_items.organization_code,
        c_valid_items.organization_id,
        Decode(c_valid_items.organization_id,p_master_org_id,c_valid_items.description,NULL),
        c_valid_items.item_status_code_agile,
        c_valid_items.primary_uom_code,
                c_valid_items.template_name,
        c_valid_items.attribute2,
        c_valid_items.buyer_id,
        c_valid_items.planner_code,
        c_valid_items.hazard_flag,
        Decode(c_valid_items.organization_id,p_master_org_id,c_valid_items.cost_of_sales_acct_id,NULL),
        Decode(c_valid_items.organization_id,p_master_org_id,c_valid_items.sales_account_id,NULL),
        NULL,    -- c_valid_items.encumbrance_acct_id,
        NULL,    -- c_valid_items.expense_account_id,
        c_valid_items.make_buy_flag,                     -- Added by KPIT on 23-APR-2018
        c_valid_items.receipt_routing_id,                -- Added by KPIT on 23-APR-2018
		c_valid_items.atp_rule_id,                    -- Added by Birlasoft on 16-AUG-2019
        c_valid_items.set_process_id,
        v_user_id,
        nvl(c_valid_items.validation_date,c_valid_items.creation_date),
        1
        );


        If c_valid_items.custom_category_code1 is NOT NULL then

            If v_cust1ctl_level = 2 or (v_cust1ctl_level = 1 and c_valid_items.organization_id = p_master_org_id) Then
               Insert into MTL_ITEM_CATEGORIES_INTERFACE
                (item_number,
                organization_code,
                organization_id,
                category_set_name,
                category_name,
                created_by,
                creation_date,
                set_process_id,
                transaction_type,
                process_flag)
               Values
                (c_valid_items.item_number,
                c_valid_items.organization_code,
                c_valid_items.organization_id,
                v_cust_cat1_set_name,
                c_valid_items.custom_category_code1,
                v_user_id,
                nvl(c_valid_items.validation_date,c_valid_items.creation_date),
                c_valid_items.set_process_id,
                'CREATE',
                1);
            End If;

        End If;


        If c_valid_items.custom_category_code2 is NOT NULL then

            If v_cust2ctl_level = 2 or (v_cust2ctl_level = 1 and c_valid_items.organization_id = p_master_org_id) Then
               Insert into MTL_ITEM_CATEGORIES_INTERFACE
                (item_number,
                organization_code,
                organization_id,
                category_set_name,
                category_name,
                created_by,
                creation_date,
                set_process_id,
                transaction_type,
                process_flag)
               Values
                (c_valid_items.item_number,
                c_valid_items.organization_code,
                c_valid_items.organization_id,
                v_cust_cat2_set_name,
                c_valid_items.custom_category_code2,
                v_user_id,
                nvl(c_valid_items.validation_date,c_valid_items.creation_date),
                c_valid_items.set_process_id,
                'CREATE',
                1);
            End If;

        End If;

        If c_valid_items.custom_category_code3 is NOT NULL then

            If v_cust3ctl_level = 2 or (v_cust3ctl_level = 1 and c_valid_items.organization_id = p_master_org_id) Then
               Insert into MTL_ITEM_CATEGORIES_INTERFACE
                (item_number,
                organization_code,
                organization_id,
                category_set_name,
                category_name,
                created_by,
                creation_date,
                set_process_id,
                transaction_type,
                process_flag)
               Values
                (c_valid_items.item_number,
                c_valid_items.organization_code,
                c_valid_items.organization_id,
                v_cust_cat3_set_name,
                c_valid_items.custom_category_code3,
                v_user_id,
                nvl(c_valid_items.validation_date,c_valid_items.creation_date),
                c_valid_items.set_process_id,
                'CREATE',
                1);
            End If;

        End If;

        If c_valid_items.custom_category_code4 is NOT NULL then

            If v_cust4ctl_level = 2 or (v_cust4ctl_level = 1 and c_valid_items.organization_id = p_master_org_id) Then
               Insert into MTL_ITEM_CATEGORIES_INTERFACE
                (item_number,
                organization_code,
                organization_id,
                category_set_name,
                category_name,
                created_by,
                creation_date,
                set_process_id,
                transaction_type,
                process_flag)
               Values
                (c_valid_items.item_number,
                c_valid_items.organization_code,
                c_valid_items.organization_id,
                v_cust_cat4_set_name,
                c_valid_items.custom_category_code4,
                v_user_id,
                nvl(c_valid_items.validation_date,c_valid_items.creation_date),
                c_valid_items.set_process_id,
                'CREATE',
                1);
            End If;

        End If;

        /* Added by KPIT on 23-APR-2018 */ 
        
          If c_valid_items.custom_category_code5 is NOT NULL then

            If v_cust5ctl_level = 2 or (v_cust5ctl_level = 1 and c_valid_items.organization_id = p_master_org_id) Then
               Insert into MTL_ITEM_CATEGORIES_INTERFACE
                (item_number,
                organization_code,
                organization_id,
                category_set_name,
                category_name,
                created_by,
                creation_date,
                set_process_id,
                transaction_type,
                process_flag)
               Values
                (c_valid_items.item_number,
                c_valid_items.organization_code,
                c_valid_items.organization_id,
                v_cust_cat5_set_name,
                c_valid_items.custom_category_code5,
                v_user_id,
                nvl(c_valid_items.validation_date,c_valid_items.creation_date),
                c_valid_items.set_process_id,
                'CREATE',
                1);
            End If;

        End If;        
        
        /* End of Added by KPIT on 23-APR-2018 */ 

        /* If c_valid_items.custom_category_code6 is NOT NULL then

            If v_cust6ctl_level = 2 or (v_cust6ctl_level = 1 and c_valid_items.organization_id = p_master_org_id) Then
               Insert into MTL_ITEM_CATEGORIES_INTERFACE
                (item_number,
                organization_code,
                organization_id,
                category_set_name,
                category_name,
                created_by,
                creation_date,
                set_process_id,
                transaction_type,
                process_flag)
               Values
                (c_valid_items.item_number,
                c_valid_items.organization_code,
                c_valid_items.organization_id,
                v_cust_cat6_set_name,
                c_valid_items.custom_category_code6,
                v_user_id,
                nvl(c_valid_items.validation_date,c_valid_items.creation_date),
                c_valid_items.set_process_id,
                'CREATE',
                1);
            End If;

        End If;        */

           End If;

        /* Perform checks for transaction type as UPDATE  */

      Elsif v_count_records != 0  or v_transaction_type = 'UPDATE' Then

        /* Determine if an UPDATE is necessary by comparing Item attributes in Oracle to attributes in Agile */

    v_description         := NULL;
    v_item_status         := NULL;
    v_cust1_category    := NULL;
    v_cust2_category    := NULL;
    v_cust3_category    := NULL;
    v_cust4_category    := NULL;
    v_cust5_category    := NULL;
    v_cust6_category    := NULL;
    v_attribute2        := NULL;
    v_buyer_id            := NULL;
    v_planner_code        := NULL;
    v_hazard_flag        := NULL;
    v_planning_make_buy_code := null;   -- Added by KPIT on 23-APR-2018
    v_receiving_routing_id   := null;   -- Added by KPIT on 23-APR-2018
    v_atp_rule_id            := null;   -- Added by Birlasoft on 16-AUG-2019
        open get_item_attributes(c_valid_items.item_number,c_valid_items.organization_id);
        fetch get_item_attributes into v_description,v_item_status,v_attribute2,v_buyer_id,v_planner_code,v_hazard_flag
        ,v_planning_make_buy_code ,v_receiving_routing_id                   -- Added by KPIT on 23-APR-2018
		,v_atp_rule_id                                                     -- Added by Birlasoft on 16-AUG-2019
        ;
        close get_item_attributes;

    v_update_flag := 'N';
    v_itm_pen_status := 'N';      -- Added on 14-Mar-2018

         If c_valid_items.description = v_description Then
      v_description := NULL;
     Else
      v_update_flag := 'Y';
      v_description := c_valid_items.description;
     End If;

    /* Commented on 14-Mar-2018
     If c_valid_items.item_status_code_agile = v_item_status Then
      v_item_status := NULL;
     Else
      v_update_flag := 'Y';
      v_item_status := c_valid_items.item_status_code_agile;
     End If;    */    -- End 14-Mar-2018
     
         /* Added the below condition block on 14-Mar-2018 */
    
     If c_valid_items.item_status_code_agile = v_item_status Then
      v_item_status := NULL;
     ElSIF c_valid_items.item_status_code_agile <> v_item_status and c_valid_items.effective_date_from <= sysdate THEN
      v_update_flag := 'Y';
      v_item_status := c_valid_items.item_status_code_agile;
     ElSIF c_valid_items.item_status_code_agile <> v_item_status and c_valid_items.effective_date_from > sysdate THEN
      v_itm_pen_status := 'Y';
      v_item_status := NULL;
     End If;            -- End 14-Mar-2018

     /* If c_valid_items.attribute2 is NOT NULL Then
      If c_valid_items.attribute2 = nvl(v_attribute2,'!') Then
       v_attribute2 := NULL;
      Else
       v_update_flag := 'Y';
       v_attribute2 := c_valid_items.attribute2;
      End If;
     End If; */

      If c_valid_items.hazard_flag is NOT NULL Then
      If c_valid_items.hazard_flag = nvl(v_hazard_flag,'!') Then
       v_hazard_flag := NULL;
      Else
       v_update_flag := 'Y';
       v_hazard_flag := c_valid_items.hazard_flag;
      End If;
     End If;

     -- Added the below validation on 23-APR-2018 
    /* Commneted on 06/24/2020 as per Ticket ICI-280
     if c_valid_items.make_buy_flag is NOT NULL and (c_valid_items.organization_code = p_master_org_code or c_valid_items.common_bom_flag = 'Yes') Then
     
      if c_valid_items.make_buy_flag =  nvl(v_planning_make_buy_code,0) THEN
         v_planning_make_buy_code := null;
      Else
       v_update_flag := 'Y';
       v_planning_make_buy_code := c_valid_items.make_buy_flag;         
      End If;
     End If;     
     
     -- Added the below validation on 23-APR-2018 
     
     if c_valid_items.receipt_routing_id is NOT NULL  Then
     
      if c_valid_items.receipt_routing_id =  nvl(v_receiving_routing_id,0) THEN
         v_receiving_routing_id := null;
      Else
       v_update_flag := 'Y';
       v_receiving_routing_id := c_valid_items.receipt_routing_id;         
      End If;
     End If;         
	 
     -- Added by Birlasoft on 16-AUG-2019
     
     if c_valid_items.atp_rule_id is NOT NULL  Then
     
      if c_valid_items.atp_rule_id =  nvl(v_atp_rule_id,0) THEN
         v_atp_rule_id := null;
      Else
       v_update_flag := 'Y';
       v_atp_rule_id := c_valid_items.atp_rule_id;         
      End If;
     End If;  	 
	 
    /* End of Commneted on 06/24/2020 as per Ticket ICI-280              */
     
    /* If c_valid_items.buyer_id is NOT NULL Then
     If c_valid_items.buyer_id = nvl(v_buyer_id,-999) Then
      v_buyer_id := NULL;
     Else
      v_update_flag := 'Y';
      v_buyer_id := c_valid_items.buyer_id;
     End If;
    End If;

    If c_valid_items.planner_code is NOT NULL Then
     If c_valid_items.planner_code = nvl(v_planner_code,'!') Then
      v_planner_code := NULL;
     Else
      v_update_flag := 'Y';
      v_planner_code := c_valid_items.planner_code;
     End If;
    End If;    */


    v_cat_update_flag := 'N';

    /* Determine If Custom Category Codes are different

    If v_cust1ctl_level = 2 or (v_cust1ctl_level = 1 and c_valid_items.organization_id = p_master_org_id) then
     open get_category_code(v_cust_cat1_set_name,c_valid_items.organization_id,c_valid_items.inventory_item_id,NULL);
     fetch get_category_code into v_cust1_category;
     close get_category_code;

     If nvl(c_valid_items.custom_category_code1,'NA') != nvl(v_cust1_category,'NA') and c_valid_items.custom_category_code1 is NOT NULL Then
      v_cat_update_flag := 'Y';
     End If;
        End If;

    If v_cust2ctl_level = 2 or (v_cust2ctl_level = 1 and c_valid_items.organization_id = p_master_org_id) then
     open get_category_code(v_cust_cat2_set_name,c_valid_items.organization_id,c_valid_items.inventory_item_id,NULL);
     fetch get_category_code into v_cust2_category;
     close get_category_code;

     If nvl(c_valid_items.custom_category_code2,'NA') != nvl(v_cust2_category,'NA') and c_valid_items.custom_category_code2 is NOT NULL Then
      v_cat_update_flag := 'Y';
     End If;
        End If;

    If v_cust3ctl_level = 2 or (v_cust3ctl_level = 1 and c_valid_items.organization_id = p_master_org_id) then
     open get_category_code(v_cust_cat3_set_name,c_valid_items.organization_id,c_valid_items.inventory_item_id,NULL);
     fetch get_category_code into v_cust3_category;
     close get_category_code;

     If nvl(c_valid_items.custom_category_code3,'NA') != nvl(v_cust3_category,'NA') and c_valid_items.custom_category_code3 is NOT NULL Then
      v_cat_update_flag := 'Y';
     End If;
        End If;

    If v_cust4ctl_level = 2 or (v_cust4ctl_level = 1 and c_valid_items.organization_id = p_master_org_id) then
     open get_category_code(v_cust_cat4_set_name,c_valid_items.organization_id,c_valid_items.inventory_item_id,NULL);
     fetch get_category_code into v_cust4_category;
     close get_category_code;

     If nvl(c_valid_items.custom_category_code4,'NA') != nvl(v_cust4_category,'NA') and c_valid_items.custom_category_code4 is NOT NULL Then
      v_cat_update_flag := 'Y';
     End If;
        End If;   */

    /* If v_cust5ctl_level = 2 or (v_cust5ctl_level = 1 and c_valid_items.organization_id = p_master_org_id) then
     open get_category_code(v_cust_cat5_set_name,c_valid_items.organization_id,c_valid_items.inventory_item_id,NULL);
     fetch get_category_code into v_cust5_category;
     close get_category_code;

     If nvl(c_valid_items.custom_category_code5,'NA') != nvl(v_cust5_category,'NA') and c_valid_items.custom_category_code5 is NOT NULL Then
      v_cat_update_flag := 'Y';
     End If;
        End If;

    If v_cust6ctl_level = 2 or (v_cust6ctl_level = 1 and c_valid_items.organization_id = p_master_org_id) then
     open get_category_code(v_cust_cat6_set_name,c_valid_items.organization_id,c_valid_items.inventory_item_id,NULL);
     fetch get_category_code into v_cust6_category;
     close get_category_code;

     If nvl(c_valid_items.custom_category_code6,'NA') != nvl(v_cust6_category,'NA') and c_valid_items.custom_category_code6 is NOT NULL Then
      v_cat_update_flag := 'Y';
     End If;
        End If;          */

        If v_update_flag = 'N' and (v_cat_update_flag = 'N') Then    -- Item record does not require an UPDATE

         /* Mark the record as Processed and issue a warning that the record does not require an UPDATE
                since all the attributes in Oracle match with the attributes in Agile */

         Update ILINK_MTL_ITEMS_INT_TEMP
         Set process_flag = 'Y',
         processed_date = SYSDATE,
         transfer_to_oracle = 'No',
         attribute7 = v_itm_pen_status,      -- Added on 14-MAR-2018
             -- warning_message = warning_message||' WARNING : Item does not need an UPDATE since all the attributes in Oracle match those in Agile',
             record_status = 'Succeeded'
         Where record_id = c_valid_items.record_id and
              item_number = c_valid_items.item_number and
              organization_id = c_valid_items.organization_id;

        Elsif v_update_flag = 'Y' Then -- OR (v_cat_update_flag = 'Y') Then    /* Item record requires an UPDATE */

         v_count_records :=0;
         open get_record_count(c_valid_items.item_number,c_valid_items.organization_code,'UPDATE');
         fetch get_record_count into v_count_records;
         close get_record_count;

         If v_count_records = 0 and v_update_flag = 'Y' Then    /* No UPDATE records exist for item in Interface table */

        /* Insert Record into Item Interface as UPDATE */

             Insert into MTL_SYSTEM_ITEMS_INTERFACE
                (transaction_type,
        item_number,
        inventory_item_id,
        organization_code,
        organization_id,
        description,
        inventory_item_status_code,
        attribute2,
        hazardous_material_flag,
		/*Commneted on 06/24/2020 as per Ticket ICI-280 */
       -- planning_make_buy_code,                     -- Added by KPIT on 23-APR-2018
       -- receiving_routing_id,                       -- Added by KPIT on 23-APR-2018
	   -- atp_rule_id,                                -- Added by Birlasoft on 16-AUG-2019
	   /* End of Commneted on 06/24/2020 as per Ticket ICI-280 */
        set_process_id,
        created_by,
        creation_date,
        process_flag,
        last_updated_by,
        last_update_date
        )
             Values
                ('UPDATE',
        c_valid_items.item_number,
        c_valid_items.inventory_item_id,
        c_valid_items.organization_code,
        c_valid_items.organization_id,
        v_description,
        v_item_status,
        NULL,    -- v_attribute2,
        v_hazard_flag,
		/* Commneted on 06/24/2020 as per Ticket ICI-280 */
       -- v_planning_make_buy_code,                  -- Added by KPIT on 23-APR-2018
       -- v_receiving_routing_id,                    -- Added by KPIT on 23-APR-2018
	   -- v_atp_rule_id,                             -- Added by Birlasoft on 16-AUG-2019
	   /* End of Commneted on 06/24/2020 as per Ticket ICI-280 */
        0,
        v_user_id,
        nvl(c_valid_items.validation_date,c_valid_items.creation_date),
        1,
        v_user_id,
        nvl(c_valid_items.validation_date,c_valid_items.creation_date));

      End If;  -- UPDATE record in item interface table

    /* If v_cat_update_flag = 'Y' Then

        -- Update Custom Category code1

        If (nvl(v_cust1_category,'NA') != nvl(c_valid_items.custom_category_code1,'NA')) and
              (v_cust1ctl_level = 2 or (v_cust1ctl_level = 1 and c_valid_items.organization_id = p_master_org_id)) then

            v_txn_type := NULL;
            If nvl(c_valid_items.custom_category_code1,'NA') = 'NA' Then
             v_txn_type := 'DELETE';
            Elsif nvl(v_cust1_category,'NA') = 'NA' Then
             v_txn_type := 'CREATE';
            Else
             v_txn_type := 'UPDATE';
            End If;

            If v_txn_type in ('CREATE','UPDATE') Then
               Insert into MTL_ITEM_CATEGORIES_INTERFACE
                (item_number,
                organization_code,
                organization_id,
                inventory_item_id,
                category_set_name,
                category_name,
                old_category_name,
                transaction_type,
                created_by,
                creation_date,
                set_process_id,
                process_flag)
               Values
                (c_valid_items.item_number,
                c_valid_items.organization_code,
                c_valid_items.organization_id,
                c_valid_items.inventory_item_id,
                v_cust_cat1_set_name,
                nvl(c_valid_items.custom_category_code1,v_cust1_category),
                v_cust1_category,
                v_txn_type,
                v_user_id,
                nvl(c_valid_items.validation_date,c_valid_items.creation_date),
                0,
                1);
            End If;

        End If; -- Custom Category Code1


        -- Update Custom Category code2

         If (nvl(v_cust2_category,'NA') != nvl(c_valid_items.custom_category_code2,'NA')) and
              (v_cust2ctl_level = 2 or (v_cust2ctl_level = 1 and c_valid_items.organization_id = p_master_org_id)) then

            v_txn_type := NULL;
            If nvl(c_valid_items.custom_category_code2,'NA') = 'NA' Then
             v_txn_type := 'DELETE';
            Elsif nvl(v_cust2_category,'NA') = 'NA' Then
             v_txn_type := 'CREATE';
            Else
             v_txn_type := 'UPDATE';
            End If;
            If v_txn_type in ('CREATE','UPDATE') Then
               Insert into MTL_ITEM_CATEGORIES_INTERFACE
                (item_number,
                organization_code,
                organization_id,
                inventory_item_id,
                category_set_name,
                category_name,
                old_category_name,
                transaction_type,
                created_by,
                creation_date,
                set_process_id,
                process_flag)
               Values
                (c_valid_items.item_number,
                c_valid_items.organization_code,
                c_valid_items.organization_id,
                c_valid_items.inventory_item_id,
                v_cust_cat2_set_name,
                nvl(c_valid_items.custom_category_code2,v_cust2_category),
                v_cust2_category,
                v_txn_type,
                v_user_id,
                nvl(c_valid_items.validation_date,c_valid_items.creation_date),
                0,
                1);
            End If;

        End If; -- Custom Category Code2

        -- Update Custom Category code3

        If (nvl(v_cust3_category,'NA') != nvl(c_valid_items.custom_category_code3,'NA')) and
              (v_cust3ctl_level = 2 or (v_cust3ctl_level = 1 and c_valid_items.organization_id = p_master_org_id)) then

            v_txn_type := NULL;
            If nvl(c_valid_items.custom_category_code3,'NA') = 'NA' Then
             v_txn_type := 'DELETE';
            Elsif nvl(v_cust3_category,'NA') = 'NA' Then
             v_txn_type := 'CREATE';
            Else
             v_txn_type := 'UPDATE';
            End If;

            If v_txn_type in ('CREATE','UPDATE') Then
               Insert into MTL_ITEM_CATEGORIES_INTERFACE
                (item_number,
                organization_code,
                organization_id,
                inventory_item_id,
                category_set_name,
                category_name,
                old_category_name,
                transaction_type,
                created_by,
                creation_date,
                set_process_id,
                process_flag)
               Values
                (c_valid_items.item_number,
                c_valid_items.organization_code,
                c_valid_items.organization_id,
                c_valid_items.inventory_item_id,
                v_cust_cat3_set_name,
                nvl(c_valid_items.custom_category_code3,v_cust3_category),
                v_cust3_category,
                v_txn_type,
                v_user_id,
                nvl(c_valid_items.validation_date,c_valid_items.creation_date),
                0,
                1);
            End If;

        End If; -- Custom Category Code3

        -- Update Custom Category code4

        If (nvl(v_cust4_category,'NA') != nvl(c_valid_items.custom_category_code4,'NA')) and
              (v_cust4ctl_level = 2 or (v_cust4ctl_level = 1 and c_valid_items.organization_id = p_master_org_id)) then

            v_txn_type := NULL;
            If nvl(c_valid_items.custom_category_code4,'NA') = 'NA' Then
             v_txn_type := 'DELETE';
            Elsif nvl(v_cust4_category,'NA') = 'NA' Then
             v_txn_type := 'CREATE';
            Else
             v_txn_type := 'UPDATE';
            End If;

            If v_txn_type in ('CREATE','UPDATE') Then
               Insert into MTL_ITEM_CATEGORIES_INTERFACE
                (item_number,
                organization_code,
                organization_id,
                inventory_item_id,
                category_set_name,
                category_name,
                old_category_name,
                transaction_type,
                created_by,
                creation_date,
                set_process_id,
                process_flag)
               Values
                (c_valid_items.item_number,
                c_valid_items.organization_code,
                c_valid_items.organization_id,
                c_valid_items.inventory_item_id,
                v_cust_cat4_set_name,
                nvl(c_valid_items.custom_category_code4,v_cust4_category),
                v_cust4_category,
                v_txn_type,
                v_user_id,
                nvl(c_valid_items.validation_date,c_valid_items.creation_date),
                0,
                1);
            End If;

        End If; -- Custom Category Code4

        -- Update Custom Category code5

        If (nvl(v_cust5_category,'NA') != nvl(c_valid_items.custom_category_code5,'NA')) and
              (v_cust5ctl_level = 2 or (v_cust5ctl_level = 1 and c_valid_items.organization_id = p_master_org_id)) then

            v_txn_type := NULL;
            If nvl(c_valid_items.custom_category_code5,'NA') = 'NA' Then
             v_txn_type := 'DELETE';
            Elsif nvl(v_cust5_category,'NA') = 'NA' Then
             v_txn_type := 'CREATE';
            Else
             v_txn_type := 'UPDATE';
            End If;

            If v_txn_type in ('CREATE','UPDATE') Then
               Insert into MTL_ITEM_CATEGORIES_INTERFACE
                (item_number,
                organization_code,
                organization_id,
                inventory_item_id,
                category_set_name,
                category_name,
                old_category_name,
                transaction_type,
                created_by,
                creation_date,
                set_process_id,
                process_flag)
               Values
                (c_valid_items.item_number,
                c_valid_items.organization_code,
                c_valid_items.organization_id,
                c_valid_items.inventory_item_id,
                v_cust_cat5_set_name,
                nvl(c_valid_items.custom_category_code5,v_cust5_category),
                v_cust5_category,
                v_txn_type,
                v_user_id,
                nvl(c_valid_items.validation_date,c_valid_items.creation_date),
                0,
                1);
            End If;

        End If; -- Custom Category Code5

        -- Update Custom Category code6

        If (nvl(v_cust6_category,'NA') != nvl(c_valid_items.custom_category_code6,'NA')) and
              (v_cust6ctl_level = 2 or (v_cust6ctl_level = 1 and c_valid_items.organization_id = p_master_org_id)) then

            v_txn_type := NULL;
            If nvl(c_valid_items.custom_category_code6,'NA') = 'NA' Then
             v_txn_type := 'DELETE';
            Elsif nvl(v_cust6_category,'NA') = 'NA' Then
             v_txn_type := 'CREATE';
            Else
             v_txn_type := 'UPDATE';
            End If;

            If v_txn_type in ('CREATE','UPDATE') Then
               Insert into MTL_ITEM_CATEGORIES_INTERFACE
                (item_number,
                organization_code,
                organization_id,
                inventory_item_id,
                category_set_name,
                category_name,
                old_category_name,
                transaction_type,
                created_by,
                creation_date,
                set_process_id,
                process_flag)
               Values
                (c_valid_items.item_number,
                c_valid_items.organization_code,
                c_valid_items.organization_id,
                c_valid_items.inventory_item_id,
                v_cust_cat6_set_name,
                nvl(c_valid_items.custom_category_code6,v_cust6_category),
                v_cust6_category,
                v_txn_type,
                v_user_id,
                nvl(c_valid_items.validation_date,c_valid_items.creation_date),
                0,
                1);
            End If;

        End If; -- Custom Category Code6

    End If; -- UPDATE Record in category interface table     */


         End If;  -- Item record requires UPDATE

        End If;      -- Transaction Type

       /* Mark the record as Processed indicating the record is inserted into the Interface table */

       Update ILINK_MTL_ITEMS_INT_TEMP
       Set process_flag = 'Y',
           processed_date = SYSDATE,
           attribute7 = v_itm_pen_status,     -- Added on 14-MAR-2018
       transaction_type = v_transaction_type
       Where record_id = c_valid_items.record_id and
             item_number = c_valid_items.item_number and
             organization_id = c_valid_items.organization_id;


   End Loop;

 Exception
  When Others then
   FND_FILE.PUT_LINE(FND_FILE.LOG,'Error in Procedure ILINK_ITEM_INSERT_INT is '||SQLERRM);
   FND_FILE.PUT_LINE(FND_FILE.LOG,DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
End ILINK_ITEM_INSERT_INT;


Procedure ILINK_INV_OPEN_INTERFACE(p_master_org_id In Number,p_req_id1 Out Number,p_req_id2 Out Number)  is

/* Define a Cursor to verify if records exist in the Interface table */

Cursor get_intf_table_count0(p_transaction_type IN Varchar2) is
Select count (*)
From MTL_SYSTEM_ITEMS_INTERFACE
Where transaction_type = p_transaction_type and
      process_flag = 1 and
      set_process_id = 0;

Cursor get_intf_table_count1(p_transaction_type IN Varchar2) is
Select count (*)
From MTL_SYSTEM_ITEMS_INTERFACE
Where transaction_type = p_transaction_type and
      process_flag = 1 and
      set_process_id = 1;

Cursor get_intf_table_count2(p_transaction_type IN Varchar2) is
Select count (*)
From MTL_SYSTEM_ITEMS_INTERFACE
Where transaction_type = p_transaction_type and
      process_flag = 1 and
      set_process_id = 2;

-- Added the below cursor on 02/09/2015

Cursor get_intf_table_count3(p_transaction_type IN Varchar2) is
Select count (*)
From MTL_SYSTEM_ITEMS_INTERFACE
Where transaction_type = p_transaction_type and
      process_flag = 1 and
      set_process_id = 3;                      -- End 02/09/2015

Cursor get_cat_table_count is
Select count (*)
From MTL_ITEM_CATEGORIES_INTERFACE
Where process_flag = 1 and
      set_process_id = 0;


v_ret               Number;
call_status         boolean;
rphase              Varchar2(30);
rstatus             Varchar2(30);
dphase              Varchar2(30);
dstatus             Varchar2(30);
message             Varchar2(240);
v_count_records     Number;
v_count_records1    Number;
v_org_id            Number;


Begin

    v_count_records := 0;

       /* Determine if records with transaction type "CREATE" exist in the Item Interface table */

       open get_intf_table_count0('CREATE');
       fetch get_intf_table_count0 into v_count_records;
       close get_intf_table_count0;


      If V_count_Records > 0 Then

       /* Records with transaction type "CREATE" exist in the Interface table so call Item Import in CREATE mode */

       v_ret := fnd_request.submit_request
        ('INV',
         'INCOIN',
         'Import Items',
         to_char(SYSDATE,'DD-MON-RR HH24:MI:SS'),
         FALSE,
         p_master_org_id,    -- org id
         1, -- 'Yes', -- all org flag
         1, -- 'Yes', -- Validate Item Flag
         1, -- 'Yes', -- Process Item Flag
         2, -- 'No'   -- Delete Imported Records Flag
         0,           -- set Process ID
         1  -- 'CREATE' -- Transaction Type
         );

         p_req_id1 := v_ret;

         If v_ret = 0 Then  /* Item Import failed */
           raise_application_error(-20020,'Error in Item Import Interface');
         Else
          commit;       /* Item Import succeeded */

          /* Exit out when the concurrent request for Item Import completes */
          Loop
             call_status := fnd_concurrent.get_request_status(v_ret,'','',rphase,rstatus,dphase,dstatus,message);
             If(dphase = 'COMPLETE' and dstatus = 'NORMAL') or
            (dphase = 'COMPLETE' and dstatus = 'ERROR') or
            (dphase = 'COMPLETE' and dstatus = 'TERMINATED')or
              (dphase = 'COMPLETE' and dstatus = 'WARNING') then

              exit;
             End If;
           End Loop;

         End If;
       End If;


    v_count_records := 0;

       /* Determine if records with transaction type "CREATE" exist in the Item Interface table */

       open get_intf_table_count1('CREATE');
       fetch get_intf_table_count1 into v_count_records;
       close get_intf_table_count1;


      If V_count_Records > 0 Then

       /* Records with transaction type "CREATE" exist in the Interface table so call Item Import in CREATE mode */

       v_ret := fnd_request.submit_request
        ('INV',
         'INCOIN',
         'Import Items',
         to_char(SYSDATE,'DD-MON-RR HH24:MI:SS'),
         FALSE,
         p_master_org_id,    -- org id
         1, -- 'Yes', -- all org flag
         1, -- 'Yes', -- Validate Item Flag
         1, -- 'Yes', -- Process Item Flag
         2, -- 'No'   -- Delete Imported Records Flag
         1,           -- set Process ID
         1  -- 'CREATE' -- Transaction Type
         );

         p_req_id1 := v_ret;

         If v_ret = 0 Then  /* Item Import failed */
           raise_application_error(-20020,'Error in Item Import Interface');
         Else
          commit;       /* Item Import succeeded */

          /* Exit out when the concurrent request for Item Import completes */
          Loop
             call_status := fnd_concurrent.get_request_status(v_ret,'','',rphase,rstatus,dphase,dstatus,message);
             If(dphase = 'COMPLETE' and dstatus = 'NORMAL') or
            (dphase = 'COMPLETE' and dstatus = 'ERROR') or
            (dphase = 'COMPLETE' and dstatus = 'TERMINATED')or
              (dphase = 'COMPLETE' and dstatus = 'WARNING') then

              exit;
             End If;
           End Loop;

         End If;
       End If;


    v_count_records := 0;

       /* Determine if records with transaction type "CREATE" exist in the Item Interface table */

       open get_intf_table_count2('CREATE');
       fetch get_intf_table_count2 into v_count_records;
       close get_intf_table_count2;


      If V_count_Records > 0 Then

       /* Records with transaction type "CREATE" exist in the Interface table so call Item Import in CREATE mode */

       v_ret := fnd_request.submit_request
        ('INV',
         'INCOIN',
         'Import Items',
         to_char(SYSDATE,'DD-MON-RR HH24:MI:SS'),
         FALSE,
         p_master_org_id,    -- org id
         1, -- 'Yes', -- all org flag
         1, -- 'Yes', -- Validate Item Flag
         1, -- 'Yes', -- Process Item Flag
         2, -- 'No'   -- Delete Imported Records Flag
         2,           -- set Process ID
         1  -- 'CREATE' -- Transaction Type
         );

         p_req_id1 := v_ret;

         If v_ret = 0 Then  /* Item Import failed */
           raise_application_error(-20020,'Error in Item Import Interface');
         Else
          commit;       /* Item Import succeeded */

          /* Exit out when the concurrent request for Item Import completes */
          Loop
             call_status := fnd_concurrent.get_request_status(v_ret,'','',rphase,rstatus,dphase,dstatus,message);
             If(dphase = 'COMPLETE' and dstatus = 'NORMAL') or
            (dphase = 'COMPLETE' and dstatus = 'ERROR') or
            (dphase = 'COMPLETE' and dstatus = 'TERMINATED')or
              (dphase = 'COMPLETE' and dstatus = 'WARNING') then

              exit;
             End If;
           End Loop;

         End If;
       End If;


       -- Added the below on 02/09/2015

       v_count_records := 0;

       /* Determine if records with transaction type "CREATE" exist in the Item Interface table */

       open get_intf_table_count3('CREATE');
       fetch get_intf_table_count3 into v_count_records;
       close get_intf_table_count3;


      If V_count_Records > 0 Then

       /* Records with transaction type "CREATE" exist in the Interface table so call Item Import in CREATE mode */

       v_ret := fnd_request.submit_request
        ('INV',
         'INCOIN',
         'Import Items',
         to_char(SYSDATE,'DD-MON-RR HH24:MI:SS'),
         FALSE,
         p_master_org_id,    -- org id
         1, -- 'Yes', -- all org flag
         1, -- 'Yes', -- Validate Item Flag
         1, -- 'Yes', -- Process Item Flag
         2, -- 'No'   -- Delete Imported Records Flag
         3,           -- set Process ID
         1  -- 'CREATE' -- Transaction Type
         );

         p_req_id1 := v_ret;

         If v_ret = 0 Then  /* Item Import failed */
           raise_application_error(-20020,'Error in Item Import Interface');
         Else
          commit;       /* Item Import succeeded */

          /* Exit out when the concurrent request for Item Import completes */
          Loop
             call_status := fnd_concurrent.get_request_status(v_ret,'','',rphase,rstatus,dphase,dstatus,message);
             If(dphase = 'COMPLETE' and dstatus = 'NORMAL') or
            (dphase = 'COMPLETE' and dstatus = 'ERROR') or
            (dphase = 'COMPLETE' and dstatus = 'TERMINATED')or
              (dphase = 'COMPLETE' and dstatus = 'WARNING') then

              exit;
             End If;
           End Loop;

         End If;
       End If;               -- End 02/09/2015


      v_count_records := 0;
      v_count_records1 := 0;

      /* Determine if records with transaction type "UPDATE" exist in the Item Interface table */

       open get_intf_table_count0('UPDATE');
       fetch get_intf_table_count0 into v_count_records;
       close get_intf_table_count0;

      /* Determine if records with exist in the Categories Interface table */

       open get_cat_table_count;
       fetch get_cat_table_count into v_count_records1;
       close get_cat_table_count;

       If v_count_Records > 0 OR v_count_records1 > 0 then

       /* Records with transaction type "UPDATE" exist in the Interface table so call Item Import in UPDATE mode */

       v_ret := fnd_request.submit_request
        ('INV',
         'INCOIN',
         'Import Items',
         to_char(sysdate,'DD-MON-RR HH24:MI:SS'),
         FALSE,
         p_master_org_id,    -- org id
         1, --'Yes',  -- all org flag
         1, -- 'Yes', -- Validate Item Flag
         1, -- 'Yes', -- Process Item Flag
         2, -- 'No'   -- Delete Imported Records Flag
         0,           -- set Process ID
         2  -- 'UPDATE' -- Transaction Type
         );

         p_req_id2 := v_ret;

         If v_ret = 0 Then  /* Item Import failed */
            raise_application_error(-20020,'Error in Item Import Interface');
         Else
          commit;       /* Item Import succeeded */
        /* Exit out when the concurrent request for Item Import completes */
           loop
           call_status := fnd_concurrent.get_request_status(v_ret,'','',rphase,rstatus,dphase,dstatus,message);
           If(dphase = 'COMPLETE' and dstatus = 'NORMAL') or
              (dphase = 'COMPLETE' and dstatus = 'ERROR') or
              (dphase = 'COMPLETE' and dstatus = 'TERMINATED') or
              (dphase = 'COMPLETE' and dstatus = 'WARNING') then
            exit;
           End If;
           End Loop;

         End If;
       End If;

     Exception
      When Others then
   FND_FILE.PUT_LINE(FND_FILE.LOG,'Error in Procedure ILINK_INV_OPEN_INTERFACE is '||SQLERRM);
   FND_FILE.PUT_LINE(FND_FILE.LOG,DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
End ILINK_INV_OPEN_INTERFACE;


Procedure ILINK_POST_ITEM_INTERFACE(p_req_id1 In Number,p_req_id2 In Number) is

/* Define a Cursor to retreive errors from Item Interface table */

Cursor item_errors is
Select msie.error_message,
       msii.process_flag,
       msii.creation_date,
       msii.item_number,
       msii.organization_id,
       msii.transaction_type
From MTL_SYSTEM_ITEMS_INTERFACE msii,
     MTL_INTERFACE_ERRORS msie
Where msii.set_process_id in (0,1,2,3) and    -- msii.set_process_id in (0,1,2) and    -- Modified on 02/09/2015
      msii.transaction_id = msie.transaction_id (+)
Order by item_number;


/* Define a Cursor to retreive errors from Item Categories Interface table */

Cursor category_errors is
Select msie.error_message,
       mici.process_flag,
       mici.item_number,
       mici.creation_date,
       mici.organization_id
From MTL_ITEM_CATEGORIES_INTERFACE mici,
     MTL_INTERFACE_ERRORS msie
Where mici.set_process_id = 0 and
      mici.transaction_id = msie.transaction_id (+)
Order by item_number;


Begin

    /* Fetch record status from Item interface and update corresponding records in temp table */

    For c_item_errors in item_errors Loop

        Update ILINK_MTL_ITEMS_INT_TEMP
        Set error_message = error_message||' '||c_item_errors.error_message,
            record_status = decode(c_item_errors.process_flag,7,'Succeeded',NULL,'Succeeded','Error'),
        processed_date = SYSDATE
        Where organization_id = c_item_errors.organization_id and
              item_number = c_item_errors.item_number and
              transaction_type = c_item_errors.transaction_type and
          record_status = 'Validated'; --and nvl(validation_date,creation_date) = c_item_errors.creation_date;

     End Loop;

   /* Fetch record status from Item Categories interface and update corresponding records in temp table */

    For c_cat_errors in category_errors Loop

        Update ILINK_MTL_ITEMS_INT_TEMP
        Set   error_message = error_message||' '||c_cat_errors.error_message,
              record_status = decode(c_cat_errors.process_flag,7,'Succeeded',NULL,'Succeeded','Error'),
          processed_date = SYSDATE
        Where organization_id = c_cat_errors.organization_id and
              item_number = c_cat_errors.item_number and
          record_status = 'Validated'; -- and nvl(validation_date,creation_date) = c_cat_errors.creation_date;
    End Loop;

    /* Delete records from Interface tables */

     Delete From MTL_INTERFACE_ERRORS mie
     Where exists (Select 'x' From MTL_SYSTEM_ITEMS_INTERFACE msi
                            Where msi.transaction_id = mie.transaction_id and
                      msi.set_process_id in (0,1,2,3)) OR        -- msi.set_process_id in (0,1,2)) OR    -- Modified on 02/09/2015
           request_id in (p_req_id1,p_req_id2);

        Delete From MTL_INTERFACE_ERRORS mie
    Where exists (Select 'x' From MTL_ITEM_CATEGORIES_INTERFACE mic
                            Where mic.transaction_id = mie.transaction_id and
                          mic.set_process_id in (0,1,2,3)) OR        -- mic.set_process_id in (0,1,2)) OR    -- Modified on 02/09/2015
          request_id in (p_req_id1,p_req_id2);

         Delete From MTL_SYSTEM_ITEMS_INTERFACE
         Where set_process_id in (0,1,2,3) OR        -- set_process_id in (0,1,2) OR    -- Modified on 02/09/2015
           request_id in (p_req_id1,p_req_id2);

     Delete From MTL_ITEM_REVISIONS_INTERFACE
     Where set_process_id in (0,1,2,3) OR        -- set_process_id in (0,1,2) OR    -- Modified on 02/09/2015
           request_id in (p_req_id1,p_req_id2);

         Delete From MTL_ITEM_CATEGORIES_INTERFACE
         Where set_process_id in (0,1,2,3) OR        -- set_process_id in (0,1,2) OR    -- Modified on 02/09/2015
           request_id in (p_req_id1,p_req_id2);

    /* Update Successfully processed records in temp table */

    Update ILINK_MTL_ITEMS_INT_TEMP
    Set transfer_to_oracle = Decode(transfer_to_oracle,NULL,'YES',transfer_to_oracle)
    Where process_flag = 'Y' and
          record_status = 'Succeeded';


   Exception
    When Others then
     FND_FILE.PUT_LINE(FND_FILE.LOG,'Error in Procedure ILINK_POST_ITEM_INTERFACE is '||SQLERRM);
     FND_FILE.PUT_LINE(FND_FILE.LOG,DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
End ILINK_POST_ITEM_INTERFACE;


-- Added the below procedure on 14-Mar-2018

Procedure ILINK_ITEM_PENDING_STATUS(p_master_org_id In Number) is

/* Define Cursor to fetch Successful Item Record with Pending Status */

Cursor get_items is
Select imi.organization_id,
       imi.item_status_code_agile,
       imi.effective_date_from,      
       msi.inventory_item_id
From ILINK_MTL_ITEMS_INT_TEMP imi,
     ILINK_MTL_SYSTEM_ITEMS_VIEW msi
Where imi.record_status = 'Succeeded' and
      imi.item_number = msi.item_number and
      imi.organization_id = msi.organization_id and
      msi.organization_id = p_master_org_id and        
      imi.transaction_type = 'UPDATE' and
      imi.attribute7 = 'Y'      
Order by imi.eco_rel_date,eco_number,organization_code;

Begin

 /* Insert Records for Items with Statuses in the Future */

   For c_items in get_items Loop

    Insert into MTL_PENDING_ITEM_STATUS
     (inventory_item_id,
      organization_id,
      status_code,
      effective_date,
      pending_flag,
      last_update_date,
      last_updated_by,
      creation_date,
      created_by)
     Select
      c_items.inventory_item_id,
      c_items.organization_id,
      c_items.item_status_code_agile,
      c_items.effective_date_from,
      'Y',
      SYSDATE,
      v_user_id,
      SYSDATE,
      v_user_id
     From Dual
     Where not exists (Select 'x' From MTL_PENDING_ITEM_STATUS mpi
                    Where mpi.inventory_item_id = c_items.inventory_item_id and
                          mpi.organization_id = c_items.organization_id and
                          mpi.status_code = c_items.item_status_code_agile and
                       -- mpi.effective_date = c_items.effective_date_from and
                       mpi.pending_flag = 'Y');

   End Loop;

 Exception
   When Others then
   FND_FILE.PUT_LINE(FND_FILE.LOG,'Error in Procedure ILINK_ITEM_PENDING_STATUS is '||SQLERRM);
   FND_FILE.PUT_LINE(FND_FILE.LOG,DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
End ILINK_ITEM_PENDING_STATUS;

End ILINK_ITEM_INTERFACE_PKG;
/
/
