CREATE OR REPLACE PACKAGE BODY XXMSC_GENERAL_PKG IS

   -- Author  : Bellona.B
   -- Created : 21/11/2019
   -- Purpose :
  --------------------------------------------------------------------
  --  ver   date         name            desc
  --  1.0   21/11/2019  Bellona(TCS)   CHG0046573- SP-IR -  recommendation
  --                                    qty according to Planning custom logic.
  --  1.1   06/01/2020  Bellona(TCS)   CHG0047106 - change cursor query.
  --------------------------------------------------------------------
  PROCEDURE message(p_msg IN VARCHAR2) IS
    -----------------------------
    --   Local Definition
    -----------------------------
    l_msg VARCHAR2(2000);
    -----------------------------
    --     Code Section
    -----------------------------
  BEGIN
    l_msg := to_char(SYSDATE, 'YYYY-MM-DD HH24:MI:DD') || ' : ' || p_msg;

    IF fnd_global.conc_request_id > 0 THEN
      fnd_file.put_line(fnd_file.log, l_msg);
    ELSE
      dbms_output.put_line(l_msg);
    END IF;

  END message;
  --------------------------------------------------------------------
  --  ver   date         name            desc
  --  1.0   21/11/2019  Bellona(TCS)   CHG0046573- initial build.
  --  1.1   06/01/2020  Bellona(TCS)   CHG0047106 - change cursor query, added new parameter
  --------------------------------------------------------------------
 PROCEDURE msc_sp_recomm_ir_qty(errbuf                 OUT VARCHAR2,
                               retcode                 OUT VARCHAR2,
                               p_plan_name             IN VARCHAR2,
                               p_source_org            IN VARCHAR2,
                               p_dest_org              IN VARCHAR2,
                               p_source_subinv         IN VARCHAR2,
                               p_source_loc            IN VARCHAR2,
                               p_period_days           IN NUMBER,
                               p_load_ir               IN VARCHAR2,
                               p_directory_name        IN VARCHAR2,
                               p_submit_approval       IN VARCHAR2) IS --CHG0047106

  ----------------------
  --Cursor declaration
  ----------------------
  CURSOR c_get_data(c_plan_name             VARCHAR2,
                    c_source_org            VARCHAR2,
                    c_dest_org              VARCHAR2,
                    c_source_subinv         VARCHAR2,
                    c_source_loc            VARCHAR2,
                    c_period_days                NUMBER
                    ) IS
  select b.item
         ,b.QTY_FOR_IR
         ,b.free_qty
         ,b.Need_by_date
         ,b.operating_unit
         ,b.dest_loc
         ,b.uom_code
         ,b.full_name
         /*,b.requestor_last_name
         ,b.requestor_first_name*/   from
  (Select a.item
      ,case
         when a.total_qoh-nvl(a.ipk_2w_demand,0) < 0 then 0
         else least(a.total_qoh-nvl(a.ipk_2w_demand,0), nvl(a.ita_2w_demand,0))
       end QTY_FOR_IR
      ,a.total_qoh-nvl(a.ipk_2w_demand,0) free_qty
      ,to_char(SYSDATE,'DD-Mon-YY') Need_by_date
      ,(select h.name
        from hr_operating_units h, inv_organization_info_v io
        where h.organization_id = io.OPERATING_UNIT
        and   io.organization_id = c_dest_org) operating_unit
      ,(select ho.location_code
          from HR_ORGANIZATION_UNITS_V  ho
         where ho.organization_id = c_dest_org) dest_loc
      ,a.uom_code
      ,(select hr_general.DECODE_PERSON_NAME(mp.employee_id)
          from mtl_system_items_b msib,mtl_planners mp
         where  msib.inventory_item_id = a.SR_INVENTORY_ITEM_ID--1314695 -- sr_inventory_item_id
           and  msib.organization_id = c_dest_org--736 --Dest_org
           and  msib.planner_code = mp.planner_code
           and  msib.organization_id = mp.organization_id) full_name
      /*,(select pp.LAST_NAME
         from  mtl_system_items_b msib,mtl_planners mp, per_people_f pp
        where  msib.inventory_item_id = a.SR_INVENTORY_ITEM_ID--1314695 -- sr_inventory_item_id
          and  msib.organization_id = c_dest_org--736 --Dest_org
          and  msib.planner_code = mp.planner_code
          and  msib.organization_id = mp.organization_id
          and  mp.employee_id = pp.PERSON_ID
          and  pp.EFFECTIVE_END_DATE > trunc(sysdate)) requestor_last_name
      ,(select pp.first_NAME
          from mtl_system_items_b msib,mtl_planners mp, per_people_f pp
         where  msib.inventory_item_id = a.SR_INVENTORY_ITEM_ID--1314695 -- sr_inventory_item_id
           and  msib.organization_id = c_dest_org--736 --Dest_org
           and  msib.planner_code = mp.planner_code
           and  msib.organization_id = mp.organization_id
           and  mp.employee_id = pp.PERSON_ID
           and  pp.EFFECTIVE_END_DATE > trunc(sysdate)) requestor_first_name*/
    from (select msi.item_name item,
                       mo.TOTAL_QOH,
              msi.inventory_item_id,
                       msi.uom_code,
           msi.sr_inventory_item_id,
           (select sum(md.using_requirement_quantity) from msc.msc_demands md
            where msi.inventory_item_id =md.inventory_item_id
            and   msi.organization_id = md.organization_id
            and   md.plan_id = c_plan_name--2029  --parameter is plan name (MSC_PLANS)
            and   md.sr_instance_id = msi.sr_instance_id
			-- CHG0047106 start
            --and   md.source_organization_id  in (-23453,md.organization_id)
			and   ((md.source_organization_id  in (-23453,md.organization_id)
					and md.origination_type <>30) or  md.origination_type = 30 )
			-- CHG0047106 end
            and   md.unbucketed_demand_date  <= trunc(sysdate) + c_period_days)--14 Parameter is period) --added '=' CHG0047106
                      IPK_2W_DEMAND,
            (select sum(md.using_requirement_quantity) from msc.msc_demands md
            where msi.inventory_item_id =md.inventory_item_id
            and   msi.organization_id = md.organization_id
            and   md.plan_id = c_plan_name--2029 -- parameter is plan name
            and   md.sr_instance_id = msi.sr_instance_id
            and   md.source_organization_id = c_dest_org--736 -- the parameter is Dest_ORG_Code
            and   md.demand_type =1
            and   md.origination_type = 1         -- CHG0047106
            and   md.unbucketed_demand_date  <= trunc(sysdate) + c_period_days)--14  Parameter is period) --added '='CHG0047106
                      ITA_2W_DEMAND
           --,msi.inventory_item_id--, md1.*
           from   apps.mtl_onhand_locator_v mo, msc.msc_system_items msi
          where   mo.ORGANIZATION_ID = c_source_org--:org_id -- the parameter is ORG_Code --  735
            and   mo.SUBINVENTORY_CODE = c_source_subinv--'14' -- the parameter is Subinventory
            and   mo.LOCATOR_ID = c_source_loc--63174 -- the parameter is locator_name
            and   mo.INVENTORY_ITEM_ID = msi.sr_inventory_item_id
            and   mo.organization_id = msi.organization_id
            and   msi.plan_id = -1) a
     )b
     where b.QTY_FOR_IR > 0 ;

   ----------------------
   --Variable declaration
   ----------------------
    l_error_code  VARCHAR2(30);
    l_error_desc  VARCHAR2(2000);
    l_update_flag VARCHAR2(10);
    l_request_id  NUMBER;
    l_cnt         NUMBER :=0 ;
    l_source_org_code VARCHAR2(100);
    l_dest_org_code  VARCHAR2(100);
    l_report_clob CLOB;
    l_report_row  VARCHAR2(32000);

    x_phase      VARCHAR2(100);
    x_status     VARCHAR2(100);
    x_dev_phase  VARCHAR2(100);
    x_dev_status VARCHAR2(100);
    l_bool       BOOLEAN;
    p_request_id NUMBER;
    x_message    VARCHAR2(500);

  BEGIN
    errbuf  := null;
    retcode := '0';

    --Print input parameters in log
    message('----------Input Parameters------------');
    message('p_plan_name: '||p_plan_name);
    message('p_source_org: '|| p_source_org);
    message('p_dest_org: '||p_dest_org);
    message('p_source_subinv: '||p_source_subinv);
    message('p_source_loc: '||p_source_loc);
    message('p_period_days: '||p_period_days);
    message('p_load_ir: '||p_load_ir);
    message('p_directory_name: '||p_directory_name);

    BEGIN
          SELECT  mp.organization_code
            INTO  l_dest_org_code
            FROM  mtl_parameters mp
           WHERE  mp.organization_id = p_dest_org;
    EXCEPTION
     WHEN no_data_found THEN
          errbuf:= 'Wrong input for - destination org -'||p_dest_org;
          message(errbuf);
          retcode := 1;
     END;

    BEGIN
          SELECT  mp.organization_code
            INTO  l_source_org_code
            FROM  mtl_parameters mp
           WHERE  mp.organization_id = p_source_org;
    EXCEPTION
     WHEN no_data_found THEN
          errbuf:= 'Wrong input for - source org -'||p_source_org;
          message(errbuf);
          retcode := 1;
     END;

    l_request_id  := fnd_global.conc_request_id;
    l_report_clob := 'Item'|| ',' ||
                     'Qty'||',' ||
                     'Need By Date'|| ','||
                     'Operating Unit' ||','||
                     'Destination Organization'|| ',' ||
                     'Source Organization'||','||
                     'Dest. Location' ||','||
                     'UOM' ||','||
                     'Destination Subinv.' ||','||
                     'Source Subinv.' ||','||
                     'Requestor Last Name' ||','||
                     'Requestor First Name' || chr(10);

    --XML header tag  <G_HEADER>
    fnd_file.put_line(fnd_file.output,'<G_HEADER>');

    FOR get_data_ind IN c_get_data(p_plan_name,
                                   p_source_org,
                                   p_dest_org,
                                   p_source_subinv,
                                   p_source_loc,
                                   p_period_days)
    LOOP

        --Excel file input
        --XML row tag  <G_DATA>
           fnd_file.put_line( fnd_file.output,'<G_DATA>');
           fnd_file.put_line( fnd_file.output,'<item>' ||get_data_ind.item ||'</item>');
           fnd_file.put_line( fnd_file.output,'<qty>' ||get_data_ind.QTY_FOR_IR ||'</qty>');
           fnd_file.put_line( fnd_file.output,'<need_by_date>' ||to_char(SYSDATE,'DD-Mon-YY') ||'</need_by_date>');
           fnd_file.put_line( fnd_file.output,'<ou>' ||get_data_ind.operating_unit ||'</ou>');
           fnd_file.put_line( fnd_file.output,'<dest_org>' ||l_dest_org_code ||'</dest_org>');
           fnd_file.put_line( fnd_file.output,'<source_org>' ||l_source_org_code ||'</source_org>');
           fnd_file.put_line( fnd_file.output,'<dest_loc>' ||get_data_ind.dest_loc ||'</dest_loc>');
           fnd_file.put_line( fnd_file.output,'<uom>' ||get_data_ind.uom_code ||'</uom>');
           fnd_file.put_line( fnd_file.output,'<dest_subinv>' ||'' ||'</dest_subinv>');
           fnd_file.put_line( fnd_file.output,'<source_subinv>' ||p_source_subinv ||'</source_subinv>');
           fnd_file.put_line( fnd_file.output,'<req_last_name>' ||substr(get_data_ind.full_name,1,INSTR(get_data_ind.full_name,',')-1) ||'</req_last_name>');
           fnd_file.put_line( fnd_file.output,'<req_first_name>' ||substr(get_data_ind.full_name,INSTR(get_data_ind.full_name,',')+1) ||'</req_first_name>');
           fnd_file.put_line( fnd_file.output,'</G_DATA>');

          --printing CSV file input to log
           message(get_data_ind.item || ',' ||                   --OBJ-04069
                         get_data_ind.QTY_FOR_IR || ',' ||             --3
                         to_char(SYSDATE,'DD-Mon-YY') || ',' ||                    --7-Aug-16
                         get_data_ind.operating_unit || ',' ||         --OBJET HK (OU)
                         l_dest_org_code || ',' ||                          --ATH
                         l_source_org_code || ',' ||                        --ITA
                         get_data_ind.dest_loc || ',' ||               --ATH - Asia Pacific Objet TPL (IO)
                         get_data_ind.uom_code || ',' ||               --EA
                         p_source_subinv || ',' ||                     --2200
                         p_source_subinv || ',' ||                     --
                         substr(get_data_ind.full_name,1,INSTR(get_data_ind.full_name,',')-1) || ',' ||    --Landesberg
                         substr(get_data_ind.full_name,INSTR(get_data_ind.full_name,',')+1)      --Uri
                         );

        IF p_load_ir = 'Y' THEN
            --generating CSV file rows
            l_report_row :=  get_data_ind.item || ',' ||                   --OBJ-04069
                             get_data_ind.QTY_FOR_IR || ',' ||             --3
                             to_char(SYSDATE,'DD-Mon-YY') || ',' ||                    --7-Aug-16
                             get_data_ind.operating_unit || ',' ||         --OBJET HK (OU)
                             l_dest_org_code || ',' ||                          --ATH
                             l_source_org_code || ',' ||                        --ITA
                             get_data_ind.dest_loc || ',' ||                   --ATH - Asia Pacific Objet TPL (IO)
                             get_data_ind.uom_code || ',' ||                   --EA
                             '' || ',' ||                                  --2200
                             p_source_subinv || ',' ||                     --
                             substr(get_data_ind.full_name,1,INSTR(get_data_ind.full_name,',')-1) || ',' ||                   --Landesberg
                             substr(get_data_ind.full_name,INSTR(get_data_ind.full_name,',')+1) || chr(10);                 --Uri

            dbms_lob.append(l_report_clob, l_report_row);
            l_cnt := l_cnt + 1;
         END IF;

     END LOOP;
     fnd_file.put_line( fnd_file.output,'</G_HEADER>');


     IF p_load_ir = 'Y' THEN
     --Uploading file to directory path
     xxssys_file_util_pkg.save_clob_to_file(p_directory_name => p_directory_name,
                                            p_file_name => 'XX_SP_RECOMMENDETION_IR_QTY_'||l_request_id||'.csv',
                                            p_clob => l_report_clob);

     message('File XX_SP_RECOMMENDETION_IR_QTY_'||l_request_id||'.csv created at '||
                   p_directory_name||' with '||l_cnt||' rows.');

     message('Submitting XX: Upload Internal Requisitions');

         p_request_id := fnd_request.submit_request(application => 'XXOBJT',
                       program     => 'XXPO_UPLOAD_INTERNAL_REQ', --'XX: Upload Internal Requisitions',
                       argument1   => p_directory_name,                --p_location
                       argument2   => 'XX_SP_RECOMMENDETION_IR_QTY_'||l_request_id||'.csv', --p_filename
                       argument3   => 'Y',                       --p_ignore_first_headers_line
                       argument4   => 'INS_INTERFACE_TABLE',     --p_mode
                       argument5   => 'Y'                        --p_launch_import_requisition
                       ,argument6   => p_submit_approval         --CHG0047106
                   );
         COMMIT;


        IF p_request_id > 0 THEN
          message('Submitted XX: Upload Internal Requisitions with request id: '||p_request_id);
          --wait for program
          l_bool := fnd_concurrent.wait_for_request(p_request_id,
                           5, --- interval 5 seconds
                           1200, ---- max wait
                           x_phase,
                           x_status,
                           x_dev_phase,
                           x_dev_status,
                           x_message);

          IF upper(x_dev_phase) = 'COMPLETE' AND
             upper(x_dev_status) = 'WARNING' THEN
            errbuf := 'Concurrent ''XX: Upload Internal Requisitions'' completed in ' ||
             upper(x_dev_status);
            message(errbuf);
            retcode := '1';

          ELSIF upper(x_dev_phase) = 'COMPLETE' AND
        upper(x_dev_status) = 'NORMAL' THEN
            -- report generated
            errbuf := 'Concurrent XX: Upload Internal Requisitions completed ';
            retcode    := '0';
            message(errbuf);
          ELSE
            -- error
            errbuf := 'Concurrent XX: Upload Internal Requisitions failed ';
            retcode    := '2';
            message(errbuf);

          END IF;
        ELSE
          -- submit program failed
          errbuf := 'failed TO submit Concurrent XX SSUS: Commercial Invoice PDF Output ' ||
                   fnd_message.get();
          message(errbuf);
          retcode := '2';
        END IF;
     END IF;
  EXCEPTION
  WHEN OTHERS THEN
      errbuf  := 'EXCEPTION_OTHERS XXMSC_GENERAL_PKG.msc_sp_recomm_ir_qty - (' || SQLERRM || ')';
      retcode := '2';
  END  msc_sp_recomm_ir_qty;

END XXMSC_GENERAL_PKG;
/