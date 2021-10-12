create or replace package body xxom_recycle_util_pkg is
  ----------------------------------------------------------------------------
  --  name:            xxom_recycle_util_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   08/07/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0035852 - Recycling application utilities container package
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  08/07/2015  Diptasurjya Chatterjee(TCS)  CHG0035852 - initial build
  ----------------------------------------------------------------------------

  function partion_table_by_region (obj_schema VARCHAR2,
                                    obj_name   VARCHAR2) return varchar2 is
    l_region  varchar2(20) := NULL;
  begin
    fnd_profile.get('XXOM_RECYCLE_USER_REGION', l_region);

    return 'region_name='''||nvl(l_region,'null')||'''';
  end;
  
  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035852 - Send mail containing recycle request details
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  08/07/2015  Diptasurjya Chatterjee (TCS)    CHG0035852 - Initial Build
  -- --------------------------------------------------------------------------------------------
  procedure send_mail(p_request_rec IN xx_om_recyclereq_all%rowtype) is
    l_mail_to varchar2(200);
    l_mail_cc varchar2(200);
    l_mail_str varchar2(4000):='';
    l_header_html varchar2(1000);
    l_footer_html varchar2(1000);
    l_err_code varchar2(1000);
    l_err_msg varchar2(1000);
  begin
    --l_header_html := xxobjt_wf_mail_support.get_header_html('INTERNAL');
    --l_footer_html := xxobjt_wf_mail_support.get_footer_html;
    
    l_mail_str := xxobjt_wf_mail_support.get_header_html('INTERNAL')||'<p> 
*** NEW RECYCLING REQUEST *** 
<br>
<br>
&nbsp;&nbsp;&nbsp;&nbsp;Request Details are:
<br>
</p>
<TABLE BORDER=1 cellPadding=2>
<TR>
<TD>First Name</TD>
<TD>'||p_request_rec.First_Name||'</TD>
</TR>
<TR>
<TD>Last Name</TD>
<TD> '||p_request_rec.Last_Name||'</TD>
</TR>
<TR> 
<TD>Company Name</TD> 
<TD> '||p_request_rec.company_name||'</TD> 
</TR>
<TR> 
<TD>Title</TD> 
<TD></TD> 
</TR>
<TR> 
<TD>Email</TD> 
<TD> '||p_request_rec.email_address||'</TD> 
</TR>
<TR> 
<TD>Phone</TD> 
<TD> '||p_request_rec.phone||'</TD> 
</TR>
<TR> 
<TD>Street</TD> 
<TD> '||p_request_rec.address_line1||'</TD> 
</TR>
<TR> 
<TD>City</TD> 
<TD> '||p_request_rec.CITY||'</TD> 
</TR>
<TR>
<TD>State</TD> 
<TD> '||p_request_rec.State_Prov||'</TD> 
</TR>
<TR> 
<TD>Postal Code</TD> 
<TD> '||p_request_rec.Postal_Code||'</TD> 
</TR>
<TR> 
<TD>Country</TD> 
<TD> '||p_request_rec.Country||'</TD> 
</TR>
<TR> 
<TD>Source Info</TD> 
<TD> </TD> 
</TR>
<TR> 
<TD>Creation Date/Time</TD> 
<TD> '||p_request_rec.request_date_timezone||'</TD> 
</TR>
<TR> 
<TD>Contents</TD> 
<TD> '||p_request_rec.code_ref_material_type_qty||'</TD> 
</TR>
<TR> 
<TD>Canisters</TD> 
<TD> '||p_request_rec.Canisters_Qty||'</TD> 
</TR>
<TR> 
<TD>Cartridge</TD> 
<TD> '||p_request_rec.Cartridges_Qty||'</TD> 
</TR>
<TR> 
<TD>Spool</TD> 
<TD> '||p_request_rec.Spools_Qty||'</TD> 
</TR>
<TR> 
<TD>Total Packages</TD> 
<TD> '||p_request_rec.Total_Packages||'</TD> 
</TR>
<TR> 
<TD>Record ID</TD> 
<TD> '||p_request_rec.RECORD_ID||'</TD> 
</TR>
</TABLE>'||xxobjt_wf_mail_support.get_footer_html;
    
    l_mail_to := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                             p_program_short_name => 'XXOM_RECYCLE_APP_TO');
                                                             
    l_mail_cc := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                             p_program_short_name => 'XXOM_RECYCLE_APP_CC');
    
    if l_mail_to is not null then
      xxobjt_wf_mail.send_mail_html(p_to_role     => l_mail_to,
                                    p_cc_mail     => l_mail_cc,
                                    p_subject     => 'Recycling Request for Europe - '||p_request_rec.company_name,
                                    p_body_html   => l_mail_str,
                                    p_err_code    => l_err_code,
                                    p_err_message => l_err_msg);
    end if;
  end send_mail;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035852 - Insert record into recycle request table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  08/07/2015  Diptasurjya Chatterjee (TCS)    CHG0035852 - Initial Build
  -- --------------------------------------------------------------------------------------------

  procedure insert_recycle_request (p_recycle_request    IN xxobjt.xx_om_recyclereq_tab,
                                    x_status             OUT varchar2,
                                    x_status_message     OUT varchar2) IS
    l_recycle_request_tab  xxobjt.xx_om_recyclereq_tab;
    l_recycle_request_rec  xxobjt.xx_om_recyclereq_rec;
    l_recycle_request      xxobjt.XX_OM_RECYCLEREQ_ALL%ROWTYPE;
    
    l_request_date         date;
    l_recycle_req_user     varchar2(200);
    
    e_invalid_country      EXCEPTION;
    e_user_not_found       EXCEPTION;
  begin
    l_recycle_request_tab := p_recycle_request;
    
    begin
       fnd_profile.GET('XXOM_RECYCLE_WEB_REQUEST_USER', l_recycle_req_user);

       if l_recycle_req_user is null then
         raise e_user_not_found;
       end if;
    exception 
    when others then
      raise e_user_not_found;
    end;
    

    if l_recycle_request_tab is not null then
      for i in 1..l_recycle_request_tab.count
      loop
        l_recycle_request_rec := l_recycle_request_tab(i);

        l_recycle_request.FIRST_NAME :=  l_recycle_request_rec.FIRST_NAME;
        l_recycle_request.LAST_NAME :=  l_recycle_request_rec.LAST_NAME;
        l_recycle_request.EMAIL_ADDRESS :=  l_recycle_request_rec.EMAIL_ADDRESS;
        l_recycle_request.COMPANY_NAME :=  l_recycle_request_rec.COMPANY_NAME;
        l_recycle_request.ADDRESS_LINE1 :=  l_recycle_request_rec.ADDRESS_LINE1;
        l_recycle_request.ADDRESS_LINE2 :=  l_recycle_request_rec.ADDRESS_LINE2;
        l_recycle_request.CITY :=  l_recycle_request_rec.CITY;
        l_recycle_request.STATE_PROV :=  l_recycle_request_rec.STATE_PROV;
        l_recycle_request.COUNTRY :=  l_recycle_request_rec.COUNTRY;
        l_recycle_request.POSTAL_CODE :=  l_recycle_request_rec.POSTAL_CODE;
        l_recycle_request.PHONE :=  l_recycle_request_rec.PHONE;
        l_recycle_request.CARTRIDGES_QTY :=  l_recycle_request_rec.CARTRIDGES_QTY;
        l_recycle_request.CANISTERS_QTY :=  l_recycle_request_rec.CANISTERS_QTY;
        l_recycle_request.SPOOLS_QTY :=  l_recycle_request_rec.SPOOLS_QTY;
        l_recycle_request.PRINT_ENGINES_QTY :=  l_recycle_request_rec.PRINT_ENGINES_QTY;
        l_recycle_request.EDEN_CONNEX_QTY :=  l_recycle_request_rec.EDEN_CONNEX_QTY;
        l_recycle_request.DESKTOP_QTY :=  l_recycle_request_rec.DESKTOP_QTY;
        l_recycle_request.WASTE_CONTAINERS_QTY :=  l_recycle_request_rec.WASTE_CONTAINERS_QTY;
        l_recycle_request.CODE_REF_MATERIAL_TYPE_QTY :=  l_recycle_request_rec.CODE_REF_MATERIAL_TYPE_QTY;
        l_recycle_request.UPS_REFERENCE_1 := l_recycle_request_rec.UPS_REFERENCE_1;
        
        if l_recycle_request_rec.REQUEST_DATE is not null and 
           l_recycle_request_rec.REQUEST_DATE <> '0001-01-01T00:00:00' then
           
          l_request_date := to_date(TO_char(to_timestamp_tz(l_recycle_request_rec.REQUEST_DATE,'rrrr-mm-dd"T"hh24:mi:ss.FFTZH:TZM') at time zone fnd_timezones.get_server_timezone_code,
               'dd-MON-rrrr hh24:mi:ss'),'dd-MON-rrrr hh24:mi:ss');

          l_recycle_request.REQUEST_DATE := l_request_date;
          l_recycle_request.REQUEST_DATE_TIMEZONE := to_timestamp_tz(l_recycle_request_rec.REQUEST_DATE,'rrrr-mm-dd"T"hh24:mi:ss.FFTZH:TZM');
        else
          l_recycle_request.REQUEST_DATE := null;
          l_recycle_request.REQUEST_DATE_TIMEZONE := null;
        end if;   
        
        l_recycle_request.SHIPPING_METHOD :=  l_recycle_request_rec.SHIPPING_METHOD;
        l_recycle_request.TOTAL_PACKAGES :=  l_recycle_request_rec.TOTAL_PACKAGES;
        l_recycle_request.HISTORICAL_DATA_FLAG :=  'N';
        l_recycle_request.SFDC_CONVERSION_ID :=  null;

        select decode(upper(l_recycle_request_rec.DANGEROUS_GOODS_FLAG),'TRUE','Y','N')
          into l_recycle_request.DANGEROUS_GOODS_FLAG
          from dual;
          
        select decode(upper(l_recycle_request_rec.SIZE_WEIGHT_VERIFY_FLAG),'TRUE','Y','N')
          into l_recycle_request.SIZE_WEIGHT_VERIFY_FLAG
          from dual;
          
        l_recycle_request.UPS_PACKAGE_ID := l_recycle_request_rec.UPS_PACKAGE_ID;
        l_recycle_request.TRACKING_NUMBER := l_recycle_request_rec.TRACKING_NUMBER;
        l_recycle_request.STATUS :=  l_recycle_request_rec.STATUS;
        l_recycle_request.COMMENTS :=  l_recycle_request_rec.COMMENTS;
        l_recycle_request.RECORD_OWNER :=  l_recycle_request_rec.RECORD_OWNER;
        l_recycle_request.ORACLE_CUSTOMER_ID :=  l_recycle_request_rec.ORACLE_CUSTOMER_ID;
        l_recycle_request.ORACLE_CUSTOMER_NAME :=  l_recycle_request_rec.ORACLE_CUSTOMER_NAME;

        l_recycle_request.SHIPMENT_NON_COMPLIANT := 'N';
        l_recycle_request.record_id := XX_OM_RECYCLEREQ_ALL_SEQ.nextval;
        l_recycle_request.creation_date := sysdate;
        l_recycle_request.last_update_date := sysdate;
        l_recycle_request.CREATED_BY :=  l_recycle_req_user;
        l_recycle_request.LAST_UPDATED_BY :=  l_recycle_req_user;
        l_recycle_request.LAST_UPDATE_LOGIN := -1;
        l_recycle_request.webpage_guid := l_recycle_request_rec.webpage_guid;
        
        begin
          select parent_flex_value_low
            into l_recycle_request.region_name
            from fnd_flex_values ffv,
                 fnd_flex_value_sets ffvs
           where ffvs.flex_value_set_name = 'XXOM_RECYCLE_COUNTRY'
             and ffv.flex_value_set_id = ffvs.flex_value_set_id
             and ffv.flex_value = l_recycle_request.country;
        exception
        when no_data_found then
          raise e_invalid_country;
        end;
        insert into XX_OM_RECYCLEREQ_ALL
             values l_recycle_request;
        
        if l_recycle_request.region_name = 'EMEA' then   
          send_mail(l_recycle_request);
        end if;
      end loop;
    end if;

    commit;

    x_status := 'SUCCESS';
    x_status_message := 'Data Inserted Successfully';
  exception
  when e_user_not_found then
    rollback;
    x_status := 'ERROR';
    x_status_message := 'The recycling request creation user could not be determined. Please set profile XX Recycle Application Web Request Creation user with valid user'||sqlerrm;
  when e_invalid_country then
    rollback;
    x_status := 'ERROR';
    x_status_message := 'The country information provided does not exist in Recycling Application repository';
  when others then
    rollback;
    x_status := 'ERROR';
    x_status_message := 'ERROR: '||sqlerrm;
  end insert_recycle_request;

end xxom_recycle_util_pkg;
/
