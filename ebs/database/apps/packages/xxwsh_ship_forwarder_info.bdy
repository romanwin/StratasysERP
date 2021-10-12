create or replace package body XXWSH_SHIP_FORWARDER_INFO is

--------------------------------------------------------------------
--  customization code: CUST283
--  name:               XXWSH_SHIP_FORWARDER_INFO
--  create by:          Dalit A. Raviv
--  $Revision:          1.0 $
--  creation date:      09/03/2010
--  Purpose :           The customization will be comprise of two parts, 
--                      one as a development of a personalized screen, 
--                      and the other of an upload program to populate 
--                      the screen with the relevant information from 
--                      an excel file. 
----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   09/03/2010    Dalit A. Raviv  initial build
----------------------------------------------------------------------- 
  
  --g_delivery_data_tbl_type delivery_data_tbl_type;  

  --------------------------------------------------------------------
  --  customization code: CUST283
  --  name:               ins_xxwsh_shipping_details
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      09/03/2010
  --  Purpose :           insert row to xxwsh_shipping_details table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   09/03/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  procedure ins_xxwsh_shipping_details (p_shipping_details_rec in  shipping_details_rec_type,
                                        p_error_code           out number,
                                        p_error_desc           out varchar2) is
    l_user_id number := null;
  begin
    l_user_id := fnd_global.USER_ID;
    insert into XXWSH_SHIPPING_DETAILS (ENTITY_ID,           -- n
                                        DELIVERY_NAME,       -- v 30
                                        CARRIER_NAME,        -- v 360
                                        FREIGHT_TERMS_CODE,  -- v 30
                                        SHIP_METHOD_MEANING, -- v 80
                                        TERRITORY_SHORT_NAME,-- v 80
                                        AWB,                 -- v 150
                                        MAWB,                -- v 150
                                        PICK_UP_DATE,        -- d
                                        FLIGHT_1_NUMBER,     -- v 150
                                        FLIGHT_1_DATE,       -- d
                                        FLIGHT_2_NUMBER,     -- v 150
                                        FLIGHT_2_DATE,       -- d
                                        POD_DATE,            -- d
                                        POD_NAME,            -- v 150
                                        INVOICE_NUMBER,      -- v 150
                                        INVOICE_DATE,        -- d
                                        LOCAL_CHARGES,       -- n
                                        LOCAL_CHARGES_ORIG,  -- n 
                                        FLIGHT_CHARGES,      -- n
                                        FLIGHT_CHARGES_ORIG, -- n 
                                        FHD_COST,            -- n
                                        FHD_COST_ORIG,       -- n
                                        OTHER,               -- n
                                        OTHER_ORIG ,         -- n
                                        TOTAL_INVOICE,       -- n
                                        TOTAL_INVOICE_ORIG,  -- n 
                                        RESHIMON_NUMBER,     -- n
                                        RESHIMON_DATE,       -- d
                                        SHIP_FROM_ORG,       -- n
                                        DELIVERY_CHARGE_WEIGHT, -- n
                                        INVOICE_TOT_WEIGHT,  -- n
                                        ATTRIBUTE1,          -- v
                                        ATTRIBUTE2,          -- v
                                        ATTRIBUTE3,          -- v
                                        ATTRIBUTE4,          -- v
                                        ATTRIBUTE5,          -- v
                                        STATUS,              -- v 150
                                        LAST_UPDATE_DATE,    -- d
                                        LAST_UPDATED_BY,     -- n
                                        LAST_UPDATE_LOGIN,   -- n
                                        CREATION_DATE,       -- d
                                        CREATED_BY           -- n
                                       )
    values                             (p_shipping_details_rec.entity_id,
                                        p_shipping_details_rec.delivery_name,
                                        p_shipping_details_rec.carrier_name,
                                        p_shipping_details_rec.freight_terms_code,
                                        p_shipping_details_rec.ship_method_meaning,
                                        p_shipping_details_rec.territory_short_name,
                                        p_shipping_details_rec.awb,
                                        p_shipping_details_rec.mawb,
                                        p_shipping_details_rec.pick_up_date,
                                        p_shipping_details_rec.flight_1_number,
                                        p_shipping_details_rec.flight_1_date,
                                        p_shipping_details_rec.flight_2_number,
                                        p_shipping_details_rec.flight_2_date,
                                        p_shipping_details_rec.pod_date,
                                        p_shipping_details_rec.pod_name,
                                        p_shipping_details_rec.invoice_number,
                                        p_shipping_details_rec.invoice_date,
                                        p_shipping_details_rec.local_charges,
                                        p_shipping_details_rec.local_charges_orig,
                                        p_shipping_details_rec.flight_charges,
                                        p_shipping_details_rec.flight_charges_orig,
                                        p_shipping_details_rec.fhd_cost,
                                        p_shipping_details_rec.fhd_cost_orig,
                                        p_shipping_details_rec.other,
                                        p_shipping_details_rec.other_orig,
                                        p_shipping_details_rec.total_invoice,
                                        p_shipping_details_rec.total_invoice_orig,
                                        p_shipping_details_rec.reshimon_number,
                                        p_shipping_details_rec.reshimon_date,
                                        p_shipping_details_rec.ship_from_org,
                                        p_shipping_details_rec.delivery_charge_weight,
                                        p_shipping_details_rec.invoice_tot_weight,
                                        p_shipping_details_rec.attribute1,
                                        p_shipping_details_rec.attribute2,
                                        p_shipping_details_rec.attribute3,
                                        p_shipping_details_rec.attribute4,
                                        p_shipping_details_rec.attribute5,
                                        null,
                                        sysdate,
                                        l_user_id,
                                        1,
                                        sysdate,
                                        l_user_id);
    commit;
    p_error_code := 0;
    p_error_desc := null;
  exception
    when others then
      rollback;
      p_error_code := 1;
      p_error_desc := 'Can Not insert row - '||substr(sqlerrm,1,240);
      
  end;
  
  --------------------------------------------------------------------
  --  customization code: CUST283
  --  name:               parse_line
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      09/03/2010
  --  Purpose :           get string of concatenated delivery numbers deliminate by
  --                      ':' (111:222:333) 
  --                      return delivery (111) to enter
  --                      and out param of the "left string" - (222:333) 
  --                          out param of the place found                                             
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   09/03/2010    Dalit A. Raviv  initial build
  --  1.1   02/06/2010    Dalit A. Raviv  correct return. if it is the last 
  --                                      parse delivery there is no : in the str
  --                                      in this case return the str that send to proc.
  ----------------------------------------------------------------------- 
  function parse_line (p_string    in  varchar2,
                       p_new_str   out varchar2,
                       p_place     out number) return varchar2 is -- delivery 
    
    --l_place number := 0;
    --l_delivery varchar2(150) := null;
    --l_new_str  varchar2(150) := null;
    
  begin

    --l_place    := instr(p_string,':');
    --l_new_str  := p_string;
    --l_delivery := substr(p_string,1, instr(p_string,':')-1 );
    --l_new_str  := substr(p_string,instr(p_string,':')+1 );
    
    p_new_str  := substr(p_string,instr(p_string,':')+1 );
    p_place    := instr(p_string,':');
    
    if instr(p_string,':') = 0 then
      return p_string;
    else
      return substr(p_string,1, instr(p_string,':')-1 );
    end if;
  
  end;                       
  
  --------------------------------------------------------------------
  --  customization code: CUST283
  --  name:               populate_table
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      09/03/2010
  --  Purpose :           Upload program - Using by BPEL
  --                      * If no data exist for the given Invoice_number - update 
  --                        that line to the Table
  --                      * If the is information for a given delivery but there is 
  --                        a different invoice_number then add the line to the table 
  --                      * If an invoice_number already exist in the table then stop  
  --                        the upload with the error indicating the invoice_number
  --                      * If a field does not pass validation, stop the upload with
  --                        the error indicating the non validated field.      
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   09/03/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
/*  Procedure populate_table  is
  
    cursor get_population_c is
      select  entity_id,
              delivery_name,
              carrier_name,
              freight_terms_code,
              ship_method_meaning,
              territory_short_name,
              awb,
              mawb,
              pick_up_date, --v
              flight_1_number,
              flight_1_date, --v
              flight_2_number,
              flight_2_date, --v
              pod_date, --v
              pod_name,
              invoice_number,
              invoice_date, --v
              local_charges,
              flight_charges,
              fhd_cost,
              other,
              total_invoice,
              reshimon_number,
              reshimon_date,
              attribute1,
              attribute2,
              attribute3,
              attribute4,
              attribute5,
              err_code,
              err_message,
              last_update_date,
              last_updated_by,
              last_update_login,
              creation_date,
              created_by 
      from    xxwsh_shipping_details_temp
      where   entity_id is not null
      and     err_code  is null; -- each row that i will work on i will mark - 0 sucess 1 Failure 
      
    cursor get_entity_c is
      select  entity_id,
              rowid row_id
      from    xxwsh_shipping_details_temp
      where   err_code  is null  
      and     entity_id is null;
    
    l_delivery              wsh_new_deliveries.name%type;
    l_shipping_details_rec  shipping_details_rec_type;
    l_delivery_name         wsh_new_deliveries.name%type;
    l_error_code            number        := 0;
    l_error_desc            varchar2(2000):= null;
    l_new_string            varchar2(240) := null;
    l_place                 number        := 1;
    l_string                varchar2(240) := null;
    --l_entity_id             number        := null;
    l_exist                 varchar2(1)   := 'N';
    l_entity_id_t           number        := null;
  begin
    -- populate temp table with entity_id
    for get_entity_r in get_entity_c loop  
      begin
        select xxwsh_shipping_details_tmp_s.Nextval
        into   l_entity_id_t
        from   dual;
        
        update xxwsh_shipping_details_temp xx_t
        set    xx_t.entity_id = l_entity_id_t
        where  rowid          = get_entity_r.row_id;
        commit;
      exception
        when others then 
          rollback;
      end; -- update
    end loop;
    
    -- start move rows from temp table to permanent table.
    for get_population_r in get_population_c loop
      -- init var each row
      l_exist := 'N';
      l_delivery := null;
      -- check invoice exists already in the table
      begin
        select 'Y'
        into   l_exist
        from   xxwsh_shipping_details xx
        where  xx.invoice_number      = get_population_r.invoice_number;
          
      exception
        when others then
          l_exist := 'N';
      end; -- invoice number
      -- if exists update temp table withh error
      -- if not do other validations
      if l_exist = 'Y' then
        begin
          update xxwsh_shipping_details_temp xx_t
          set    xx_t.err_code               = 1,
                 xx_t.err_message            = 'Invoice Number already exists in table',
                 xx_t.last_update_date       = sysdate,
                 xx_t.creation_date          = sysdate
          where  xx_t.entity_id              = get_population_r.entity_id;
          commit;
        exception
          when others then null;
        end; -- update
      else
        -- the delivery come by concatenate string of many deliveries
        -- parse_line return each loop one delivery 
        l_delivery_name := null;
        l_new_string    := null;
        l_place         := 1;
         
        l_string        := get_population_r.delivery_name;
        while l_place <> 0 loop
          
          -- get delivery_name
          l_delivery_name := parse_line( p_string  => l_string,
                                         p_new_str => l_new_string,
                                         p_place   => l_place);
          l_string := l_new_string;
          -- check delivery exist in oracle
          begin
            select wnd.name
            into   l_delivery
            from   wsh_new_deliveries wnd
            where  wnd.name           = nvl(l_delivery_name,l_new_string) ;
          exception
            when others then
              l_delivery := null;
              begin
                update xxwsh_shipping_details_temp xx_t
                set    xx_t.err_code               = 1,
                       xx_t.err_message            = xx_t.err_message||'. Delivery not exists in Oracle '||nvl(l_delivery_name,l_new_string),
                       xx_t.last_update_date       = sysdate,
                       xx_t.creation_date          = sysdate
                where  xx_t.entity_id              = get_population_r.entity_id;
                commit;
              exception
                when others then null;
              end; -- update
          end; -- delivery
          if l_delivery is not null then
            l_shipping_details_rec := null;
            
            --select XXWSH_SHIPPING_DETAILS_S.Nextval
            --into   l_entity_id
            --from   dual;
            
            l_shipping_details_rec.entity_id            := get_population_r.entity_id; 
            l_shipping_details_rec.delivery_name        := l_delivery;
            l_shipping_details_rec.carrier_name         := get_population_r.carrier_name;
            l_shipping_details_rec.freight_terms_code   := get_population_r.freight_terms_code;
            l_shipping_details_rec.ship_method_meaning  := get_population_r.ship_method_meaning;
            l_shipping_details_rec.territory_short_name := get_population_r.territory_short_name;
            l_shipping_details_rec.awb                  := get_population_r.awb;
            l_shipping_details_rec.mawb                 := get_population_r.mawb;
            l_shipping_details_rec.pick_up_date         := to_date(get_population_r.pick_up_date,'mm/dd/RRRR'); 
            l_shipping_details_rec.flight_1_number      := get_population_r.flight_1_number;
            l_shipping_details_rec.flight_1_date        := to_date(get_population_r.flight_1_date,'mm/dd/RRRR'); 
            l_shipping_details_rec.flight_2_number      := get_population_r.flight_2_number;
            l_shipping_details_rec.flight_2_date        := to_date(get_population_r.flight_2_date,'mm/dd/RRRR');
            l_shipping_details_rec.pod_date             := to_date(get_population_r.pod_date,'mm/dd/RRRR'); 
            l_shipping_details_rec.pod_name             := get_population_r.pod_name;
            l_shipping_details_rec.invoice_number       := get_population_r.invoice_number;
            l_shipping_details_rec.invoice_date         := to_date(get_population_r.invoice_date,'mm/dd/RRRR'); 
            l_shipping_details_rec.local_charges        := get_population_r.local_charges;
            l_shipping_details_rec.flight_charges       := get_population_r.flight_charges;
            l_shipping_details_rec.fhd_cost             := get_population_r.fhd_cost;
            l_shipping_details_rec.other                := get_population_r.other;
            l_shipping_details_rec.total_invoice        := get_population_r.total_invoice;
            l_shipping_details_rec.reshimon_number      := get_population_r.reshimon_number; 
            l_shipping_details_rec.attribute1           := get_population_r.attribute1;
            l_shipping_details_rec.attribute2           := get_population_r.attribute2; 
            l_shipping_details_rec.attribute3           := get_population_r.attribute3; 
            l_shipping_details_rec.attribute4           := get_population_r.attribute4; 
            l_shipping_details_rec.attribute5           := get_population_r.attribute5;                                  
              
            ins_xxwsh_shipping_details (p_shipping_details_rec => l_shipping_details_rec, --  i shipping_details_rec_type
                                        p_error_code           => l_error_code, -- o n 
                                        p_error_desc           => l_error_desc);-- o v 
            if l_error_code = 0 then
              begin
                update xxwsh_shipping_details_temp xx_t
                set    xx_t.err_code               = 0,
                       xx_t.err_message            = xx_t.err_message||'. SUCCESS '||l_delivery,
                       xx_t.last_update_date       = sysdate,
                       xx_t.creation_date          = sysdate
                where  xx_t.entity_id              = get_population_r.entity_id;
                commit;
              exception
                when others then null;
              end; -- update
              ------------ to enter update of sucess
            else
              begin
                rollback;
                update xxwsh_shipping_details_temp xx_t
                set    xx_t.err_code               = 2,
                       xx_t.err_message            = xx_t.err_message||'. ERROR delivery - '||l_delivery||'-'||substr(l_error_desc,1,100),
                       xx_t.last_update_date       = sysdate,
                       xx_t.creation_date          = sysdate
                where  xx_t.entity_id              = get_population_r.entity_id;
                commit;
              exception
                when others then null;
              end; -- update
                
            end if; -- l_error_code
          end if;-- l_delivery not null
          if l_place = 0 then 
            exit;
          end if;
        end loop; -- while (parse delivery
      end if; -- l_exist 
    end loop; -- cursor
  end populate_table;
*/  
  --------------------------------------------------------------------
  --  customization code: CUST283
  --  name:               Call_Bpel_Process
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      16/03/2010
  --  Purpose :           procedure that will call from concurrent program
  --                      and will start BPEL process - XXWSHForwarderProcessRequest
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   09/03/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  Procedure Call_Bpel_Process(errbuf   out varchar2,
                              retcode  out varchar2) is
   
    service_             sys.utl_dbws.SERVICE;
    call_                sys.utl_dbws.CALL;
    service_qname        sys.utl_dbws.QNAME;
    response             sys.XMLTYPE;
    request              sys.XMLTYPE;
    v_string_type_qname  sys.UTL_DBWS.QNAME;  
    
                           
  begin
    service_qname := sys.utl_dbws.to_qname('http://xmlns.oracle.com/XXWSHForwarder','XXWSHForwarder');
    v_string_type_qname :=sys.UTL_DBWS.TO_QNAME ('http://www.w3.org/2001/XMLSchema','string');
    service_ := sys.utl_dbws.create_service(service_qname);
    call_ := sys.utl_dbws.create_call(service_);
    --sys.utl_dbws.set_target_endpoint_address(call_,  'http://soaprodapps.2objet.com:7777/orabpel/default/XXWSHForwarder/1.0/XXWSHForwarder?wsdl');  
    sys.utl_dbws.set_target_endpoint_address(call_,
                                             'http://soaprodapps.2objet.com:7777/orabpel/'||xxagile_util_pkg.get_bpel_domain||'/XXWSHForwarder/1.0/client?wsdl');
    sys.utl_dbws.set_property(call_,'SOAPACTION_USE','TRUE');  
    sys.utl_dbws.set_property(call_,'SOAPACTION_URI','process');  
    sys.utl_dbws.set_property(call_,'OPERATION_STYLE','document');
    sys.utl_dbws.set_property(call_, 'ENCODINGSTYLE_URI', 'http://schemas.xmlsoap.org/soap/encoding/');
    sys.utl_dbws.add_parameter(call_, 'input', v_string_type_qname, 'ParameterMode.IN');
    sys.utl_dbws.set_return_type (call_, v_string_type_qname);
    
    -- Set the input
    request := sys.XMLTYPE('<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
                              <soap:Body xmlns:ns1="http://xmlns.oracle.com/XXWSHForwarder">
                                  <ns1:XXWSHForwarderProcessRequest>
                                      <ns1:input></ns1:input>
                                  </ns1:XXWSHForwarderProcessRequest>
                              </soap:Body>
                            </soap:Envelope>');
     
    response := sys.utl_dbws.invoke(call_, request);
    sys.utl_dbws.release_call(call_);
    sys.utl_dbws.release_service(service_);
    dbms_output.put_line(response.getstringval()); 
    fnd_file.put_line(fnd_file.log, 'BPEl response - '||response.getstringval());
    
    errbuf   := 'Success';
    retcode  := 0;
  Exception
    when Others Then
     dbms_output.put_line(substr(sqlerrm,1,250)); 
     --v_error := substr(sqlerrm,1,250);
     --P_Status := 'S';
     --P_Message := 'Error Run Bpel Interface: '||v_error;
     errbuf   := 'Error Run Bpel Interface: '||substr(sqlerrm,1,250);
     retcode  := 1;
     
     sys.utl_dbws.release_call(call_);
     sys.utl_dbws.release_service(service_);  

  end Call_Bpel_Process; 
  
  --------------------------------------------------------------------
  --  customization code: CUST283
  --  name:               get_invoice_tot_weight
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      18/03/2010
  --  Purpose :           function that get string of deliveries 111:2222:333 
  --                      will parse it and return the total weight of all 
  --                      deliveries from the invoice
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/03/2010    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------                             
  function  get_invoice_tot_weight (p_delivery_str in  varchar2,
                                    p_error_code   out number,
                                    p_error_desc   out varchar2 ) return number is 
                                  
    --l_delivery               wsh_new_deliveries.name%type;
    l_string                 varchar2(500);
    l_new_string             varchar2(500);
    l_place                  number := 1;
    l_delivery_name          wsh_new_deliveries.name%type;
    l_chargable_weight       number := 0;
    l_tot_inv_weight         number := 0;
    l_error_desc             varchar2(1000) := null;
    l_exists                 varchar2(2)    := 'Y';
    
  begin
    l_string        := p_delivery_str;
    
    while l_place <> 0 loop
      -- get delivery_name
      l_delivery_name := XXWSH_SHIP_FORWARDER_INFO.parse_line( p_string  => l_string,
                                                               p_new_str => l_new_string,
                                                               p_place   => l_place);
      -- check delivery exists in oracle
      -- if one delivery of the invoice do not exists in oracle the chargable weight 
      -- calculation will not be corect. because we can not do the correct factor for the invoice.
      -- if the delivery do not exist in oracle - the program will put all invoice to error.
      begin
        select 'Y'
        into   l_exists           
        from   wsh_new_deliveries wnd
        where  wnd.name           = nvl(l_delivery_name,l_new_string);
        
      exception
        when others then
          l_exists     := 'N';
          p_error_code := 1;
          if l_error_desc is null then
            l_error_desc := l_delivery_name;
          else
            l_error_desc := l_error_desc||', '||l_delivery_name;
          end if;
      end;
      -- if delivery exists calculate chargable weight, and total
      if l_exists = 'Y' then
        l_string           := l_new_string;  
        l_chargable_weight := get_chargable_weight (nvl(l_delivery_name,l_string));
        l_tot_inv_weight   := l_tot_inv_weight + l_chargable_weight; 
      else
        --if l_delivery_name is null then -- this was the last delivery parse
          l_string           := l_new_string; 
         -- l_chargable_weight := get_chargable_weight (nvl(l_delivery_name,l_string));
        --  l_tot_inv_weight   := l_tot_inv_weight + l_chargable_weight; 
        --end if; 
      end if; -- l_exists 
      if l_place = 0 then 
        exit;
      end if;  
    end loop; -- parse line
    -- Set return values
    if l_error_desc is not null then
      p_error_desc := l_error_desc;
      p_error_code := 1;
    else
      p_error_desc := null;
      p_error_code := 0;
    end if;
    return l_tot_inv_weight;
        
  exception
    when others then 
      return  -1;
      
  end get_invoice_tot_weight;                                  
   
  --------------------------------------------------------------------
  --  customization code: CUST283
  --  name:               get_chargable_weight
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      21/03/2010
  --  Purpose :           Function that calculate chargable weight per delivery
  --                      reference Packing list report (field chargable weight)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/03/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  function get_chargable_weight (P_delivery_name in varchar2) return number is
    l_charge_weight number := 0;
  begin
    select sum( (wdd1.attribute2 * wdd1.attribute3 * wdd1.attribute4)/6000 ) chargeble_weight
    into   l_charge_weight           
    from   wsh_new_deliveries       wnd,
           wsh_delivery_assignments wda,
           wsh_delivery_details     wdd1 -- Container
    where  wda.delivery_id          = wnd.delivery_id
    and    wda.delivery_detail_id   = wdd1.delivery_detail_id
    and    wdd1.container_flag      = 'Y'
    and    wnd.name                 = P_delivery_name; --in ( '305034','305036','305037','305042','305064','305160','305221','305237','305241')
    
    return nvl(l_charge_weight,0);
  exception
    when others then 
      return 0;
  end get_chargable_weight;                           
  
end XXWSH_SHIP_FORWARDER_INFO;
/

