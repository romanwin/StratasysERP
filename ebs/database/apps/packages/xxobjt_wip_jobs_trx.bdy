create or replace package body XXOBJT_WIP_JOBS_TRX is
g_user_id    fnd_user.user_id%type;

Procedure Call_Bpel_Process(P_Status Out varchar2,P_Message Out varchar2) Is

service_               sys.utl_dbws.SERVICE;
call_                  sys.utl_dbws.CALL;
service_qname          sys.utl_dbws.QNAME;
response               sys.XMLTYPE;
request                sys.XMLTYPE;
V_STRING_TYPE_QNAME    sys.UTL_DBWS.QNAME;  
v_error                varchar2(1000);

Begin

   Begin
    service_qname := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxGetSimplicityFile','xxGetSimplicityFile');
    v_string_type_qname :=sys.UTL_DBWS.TO_QNAME ('http://www.w3.org/2001/XMLSchema','string');
    service_ := sys.utl_dbws.create_service(service_qname);
    call_ := sys.utl_dbws.create_call(service_);
    sys.utl_dbws.set_target_endpoint_address(call_,  'http://soaprodapps.2objet.com:7777/orabpel/default/xxGetSimplicityFile/1.0/xxGetSimplicityFile?wsdl');  
    sys.utl_dbws.set_property(call_,'SOAPACTION_USE','TRUE');  
    sys.utl_dbws.set_property(call_,'SOAPACTION_URI','process');  
    sys.utl_dbws.set_property(call_,'OPERATION_STYLE','document');
    sys.utl_dbws.set_property(call_, 'ENCODINGSTYLE_URI', 'http://schemas.xmlsoap.org/soap/encoding/');
    sys.utl_dbws.add_parameter(call_, 'input', v_string_type_qname, 'ParameterMode.IN');
    sys.utl_dbws.set_return_type (call_, v_string_type_qname);
    
    -- Set the input
    request := sys.XMLTYPE('<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body xmlns:ns1="http://xmlns.oracle.com/xxGetSimplicityFile">
        <ns1:xxGetSimplicityFileProcessRequest>
            <ns1:input></ns1:input>
        </ns1:xxGetSimplicityFileProcessRequest>
     </soap:Body>
    </soap:Envelope>');

                              
    response := sys.utl_dbws.invoke(call_, request);
     sys.utl_dbws.release_call(call_);
     sys.utl_dbws.release_service(service_);
    --dbms_output.put_line(response.getstringval()); 
   Exception
    when Others Then
     dbms_output.put_line(substr(sqlerrm,1,250)); 
     v_error := substr(sqlerrm,1,250);
     P_Status := 'S';
     P_Message := 'Error Run Bpel Interface: '||v_error;
     sys.utl_dbws.release_call(call_);
     sys.utl_dbws.release_service(service_);  
   End;

End Call_Bpel_Process;
Procedure Process_Wip_Interface(p_object_id In Number,p_parent_object_id In Number,P_Status Out varchar2,P_Message Out varchar2) Is

l_return_status	 varchar2(1);
l_msg_data		   varchar2(2000);
l_msg_count		   number;
v_func           number;
v_trans_count   number;
Begin
fnd_global.apps_initialize (g_user_id, 50606, 660);
fnd_msg_pub.INITIALIZE;

  
  inv_genealogy_pub.insert_genealogy(p_api_version => 1,
                                     p_object_type => 1,
                                     p_parent_object_type => 1,
                                     p_object_id => p_object_id,
                                     p_parent_object_id => p_parent_object_id,
                                     p_origin_txn_id => 999,
                                     x_return_status => l_return_status,
                                     x_msg_count => l_msg_count,
                                     x_msg_data => l_msg_data);
                                                                            
  P_Status := l_return_status;
  P_Message := l_return_status;
DBMS_OUTPUT.put_line ('v_func = ' || v_func);
DBMS_OUTPUT.put_line (SUBSTR ('x_returnstatus = ' || l_return_status, 1, 255));
DBMS_OUTPUT.put_line (SUBSTR ('x_errormsg = ' || l_msg_data, 1, 255));
End Process_Wip_Interface;


Procedure Process_Interface(errbuf            out varchar2,
                            retcode           out varchar2,
                            P_Job_Number      In  Varchar2) Is
Cursor Cr_Wip_Jobs Is
Select *
From XXOBJT_WIP_JOB_TRX w
Where w.error_message Is Null
  And w.job_number = P_Job_Number;

v_assembly_item_id        Number;
v_component_item_id       Number;
v_wip_entity_id           Number;
v_lot_number              varchar2(80);
v_qty_oh                  Number;
v_trx_interface_id        Number;
l_return_status	          varchar2(1);
l_msg_data		            varchar2(2000);
l_msg_count		            number;
v_func                    number;
v_trans_count             number;
v_gen_exist               varchar2(1);
v_parent_object_id        number;
v_object_id               number;
v_uom                     varchar2(10);
v_operation_seq_num       number;
Begin

  
    Begin
      select user_id
        into g_user_id
        from fnd_user
       where user_name = 'CONVERSION';
    Exception
      when no_data_found then
        g_user_id := null;
    End;

  fnd_global.apps_initialize (g_user_id, 50606, 660);
  
  retcode := '0';
 --Call BPEL Process
 -- Call_Bpel_Process(l_return_status,l_msg_data); 
 
  --If l_return_status = 'S' Then
   --Wait 20 SEC before continue
  -- dbms_lock.sleep(seconds => 20);
     For i In Cr_Wip_Jobs Loop
      
      If i.lot Is not Null Then
       v_uom := 'KG';
      Else
       v_uom := 'EA';
      End If;
       
      If retcode = '0' Then--If there is problem with 1 component -> don't update the job
    
        Begin
          Select msi.inventory_item_id
            into v_assembly_item_id
            From mtl_system_items_b msi
           Where msi.organization_id = 85 and
                 msi.segment1 = i.assembly_item_number;
        Exception
          When no_data_found then
            v_assembly_item_id   := null;
            retcode := '2';
            If errbuf is Null Then
             errbuf  := 'Assembly Item: ' || i.assembly_item_number ||' Not Exists In The System';
            Else
             errbuf  := errbuf||chr(10)||'Assembly Item: ' || i.assembly_item_number ||' Not Exists In The System';
            End If;
        End; 
        Begin
          Select msi.inventory_item_id
            into v_component_item_id
            From mtl_system_items_b msi
           Where msi.organization_id = 85 and
                 msi.segment1 = i.component;
        Exception
          When no_data_found then
            v_component_item_id   := null;
            retcode := '2';
            If errbuf is Null Then
             errbuf  := 'Component Item: ' || i.component ||' Not Exists In The System';
            Else
             errbuf  := errbuf||chr(10)||'Component Item: ' || i.component ||' Not Exists In The System';
            End If;
        End;  
        Begin
          Select we.wip_entity_id
            into v_wip_entity_id
            From wip_entities we
           Where we.organization_id = 85
             And we.wip_entity_name = i.job_number;
        Exception
          When no_data_found then
            v_wip_entity_id   := null;
            retcode := '2';
            If errbuf is Null Then
             errbuf  := 'job: ' || i.job_number ||' Not Exists In The System';
            Else
             errbuf  := errbuf||chr(10)||'job : ' || i.job_number ||' Not Exists In The System';
            End If;
        End;  
        
        If i.lot Is Not Null Then
          Begin
            Select ml.lot_number
              into v_lot_number
              From mtl_lot_numbers ml
             Where ml.organization_id = 85
               And ml.lot_number = i.lot;
          Exception
            When no_data_found then
              v_lot_number   := null;
              retcode := '2';
              If errbuf is Null Then
               errbuf  := 'Lot: ' || i.lot ||' Not Exists In The System';
              Else
               errbuf  := errbuf||chr(10)||'lot: ' || i.lot ||' Not Exists In The System';
              End If;
          End; 
         End If;           
        Begin      
         Select sum(mo.transaction_quantity)
         Into v_qty_oh
         From mtl_onhand_quantities_detail mo
          Where mo.inventory_item_id = v_component_item_id
            And mo.organization_id = 85
            And mo.subinventory_code = '1014'
            And decode(i.lot,null,'a',mo.lot_number) = nvl(i.lot,'a'); --according to what?? also locator
        Exception
         When No_Data_Found Then
          v_qty_oh := 0;
        End; 

        Begin
          Select wr.operation_seq_num
            into v_operation_seq_num
            From wip_requirement_operations_v wr
           Where wr.organization_id = 85
             And wr.inventory_item_id = v_component_item_id
             And wr.wip_entity_id = v_wip_entity_id;
        Exception
          When no_data_found then
            v_operation_seq_num   := null;
            retcode := '2';
            If errbuf is Null Then
             errbuf  := 'Problem With Operation Seq Num';
            Else
             errbuf  := errbuf||chr(10)||'Problem With Operation Seq Num';
            End If;
        End;
         
        If v_qty_oh < i.weight Then
          retcode := '2';
          If errbuf is Null Then
           errbuf  := 'No OH QTY For Component: ' || i.component;
          Else
           errbuf  := errbuf||chr(10)||'No OH QTY For Component: ' || i.component;
          End If;    
        End If;
         If retcode = '0' Then 
         
          Select mtl_material_transactions_s.nextval Into v_trx_interface_id From Dual;  
            insert into mtl_transactions_interface
              (inventory_item_id,
               transaction_header_id, 
               transaction_interface_id,
               source_code,
               transaction_type_id,
               transaction_uom,
               transaction_quantity,
               transaction_date,
              -- transaction_reference,
               organization_id,
               distribution_account_id,
               last_update_date,
               source_header_id,
               created_by,
               flow_schedule,
               process_flag,
               transaction_mode,
               creation_date,
               subinventory_code,
               scheduled_flag,
               substitution_item_id,
               substitution_type_id,
               last_updated_by,
               locator_id,
               source_line_id,
               revision,
               transaction_cost,
               new_average_cost,
               final_completion_flag,
               wip_entity_type,
               transaction_source_id,
               operation_seq_num)
            values
              (v_component_item_id,
               999,
               v_trx_interface_id,
               'Wip',
               35 /*WIP Issue*/,
               v_uom,
               i.weight*-1,
               Sysdate,
              -- 'Empty SubInv',
               85,
               null,
               sysdate,
               v_trx_interface_id,
               g_user_id,
               'N',
               '1',
               '3',--'3',
               Sysdate,
               '1014',--Check
               '2',
               '0',
               '0',
               g_user_id,
               null,
               v_trx_interface_id,
               null,
               null,
               null,
               null,--'Y',
               1,
               v_wip_entity_id,
               v_operation_seq_num);
          If i.lot Is Not Null Then 
           Insert into mtl_transaction_lots_interface
             (TRANSACTION_INTERFACE_ID,
              LAST_UPDATE_DATE,
              LAST_UPDATED_BY,
              CREATION_DATE,
              CREATED_BY,
              LAST_UPDATE_LOGIN,
              LOT_NUMBER,
              TRANSACTION_QUANTITY,
              PRIMARY_QUANTITY,
              PRODUCT_CODE,
              PRODUCT_TRANSACTION_ID) --link to rcv_transactions_interface
           VALUES
             (v_trx_interface_id,
              sysdate,
              1,
              sysdate,
              1,
              1,
              i.lot,
              i.weight*-1,
              1,
              'RCV',
              RCV_TRANSACTIONS_INTERFACE_S.Nextval);
           End If;
           
               
          Update xxobjt_wip_job_trx w
          Set w.error_code = 'S'
          Where w.job_number = i.job_number
            And w.assembly_item_number = i.assembly_item_number
            And w.component = i.component
            And w.error_code Is Null;
         End If;
         
    
      
      Else
        DBMS_OUTPUT.put_line ('first error = ');
          Rollback;
          
          retcode := '2';
          errbuf := 'Error When Trying To Run Material Interface(records NOT exist in the interface): '||errbuf;
          
          Update xxobjt_wip_job_trx w
          Set w.error_code = 'E',
              w.error_message = errbuf
          Where w.job_number = i.job_number
            And w.error_code Is Null;
           Commit;
           Exit;--Exit the loop     
      End If;
     End Loop;
 
--Run API to launch the interface
     If retcode = '0' Then 
      Commit;
      fnd_msg_pub.INITIALIZE;
    
      v_func := inv_txn_manager_pub.process_Transactions(p_api_version => '1.0',
                                                         p_header_id => 999,
                                                         p_commit => fnd_api.G_FALSE,
                                                         x_return_status => l_return_status,
                                                         x_msg_count => l_msg_count,
                                                         x_msg_data => l_msg_data,
                                                         x_trans_count => v_trans_count);                                     
    
        DBMS_OUTPUT.put_line ('v_func = ' || v_func);
        DBMS_OUTPUT.put_line (SUBSTR ('x_returnstatus = ' || l_return_status, 1, 255));
        DBMS_OUTPUT.put_line (SUBSTR ('x_errormsg = ' || l_msg_data, 1, 255));
        
        
        If l_return_status = 'S' Then
         Commit;
          For i In Cr_Wip_Jobs Loop
            If i.lot Is not null Then
              --Check if the combination of parent lot(JOB) and lot (come with component) exist. If not -> create the combination
               Begin
                Select ml.gen_object_id
                Into v_object_id
                From mtl_lot_numbers ml
                Where ml.lot_number = i.lot
                  And ml.organization_id = 85;
               Exception 
                When No_Data_Found Then
                 v_object_id := Null;
               End;
               
               Begin
                Select ml.gen_object_id
                Into v_parent_object_id
                From mtl_lot_numbers ml
                Where ml.lot_number = i.job_number
                  And ml.organization_id = 85;
               Exception 
                When No_Data_Found Then
                 v_parent_object_id := Null;
               End;      
        
               If v_parent_object_id Is Not Null And v_object_id Is Not Null Then
                DBMS_OUTPUT.put_line ('before comb');
                 Begin
                  Select 'Y'
                  Into v_gen_exist
                  From mtl_object_genealogy mo
                  Where mo.object_id = v_object_id
                    And mo.parent_object_id = v_parent_object_id;
                 Exception 
                  When No_Data_Found Then
                  DBMS_OUTPUT.put_line ('comb');
                   --Call API To Generate Combination
                   l_return_status := Null;
                   l_msg_data      := Null;
                   Process_Wip_Interface(v_object_id,v_parent_object_id,l_return_status,l_msg_data);
                   If l_return_status <> 'S' Then
                     retcode := '1';
                     If errbuf Is Null Then
                      errbuf := 'Error When Trying To Create Genealogy (Lot: '||i.lot||', Parent Lot: '||i.job_number||'): '||l_msg_data;
                     Else
                      errbuf := errbuf||chr(10)||'Error When Trying To Create Genealogy (Lot: '||i.lot||', Parent Lot: '||i.job_number||'): '||l_msg_data;
                     End If;
                   End If;
                 End;
               End If;
            End If;   
          End Loop;
        
        Else
         retcode := '2';
         errbuf := 'Error When Trying To Run Material Interface(records exist in the interface): '||l_msg_data;
         
          Update xxobjt_wip_job_trx w
          Set w.error_code = 'E',
              w.error_message = 'Error When Trying To Run Material Interface: '||l_msg_data
          Where w.job_number = P_Job_Number
            And w.error_code Is Null;
           Commit;  
         
        End If;
     End If;
/*  Else--Error Calling BPEL
     retcode := '2';
     errbuf := l_msg_data;
  End If;*/
End Process_Interface;

end XXOBJT_WIP_JOBS_TRX;
/

