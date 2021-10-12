CREATE OR REPLACE PACKAGE BODY XXHZ_SF_BUSINESS_EVENTS_PKG is
--------------------------------------------------------------------
--  customization code: CHG0034741 - New Interface OA2SF for Account relationships
--  name:               XXHZ_SF_BUSINESS_EVENTS_PKG
--  create by:          Dalit A. Raviv
--  $Revision:          1.0
--  creation date:      17/05/2015 11:44:06
--  Description:        General package that handle all HZ business events for SF
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   17/05/2015    Dalit A. Raviv  initial build
--  1.1   26-Oct-2015   Dalit A. Raviv  CHG0036771 - Business event on merge table to execute SFDC merge process
--                                      add function CustAcctMerge that will be called from business event
--                                      oracle.apps.ar.hz.CustAccount.merge
-- 1.2   04.03.19     Lingaraj          INC0148774 - remove all call s to  xxobjt_oa2sf_interface_pkg.insert_into_interface
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  customization code: CHG0034741 - New Interface OA2SF for Account relationships
  --  name:               CustAcctRelate
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/05/2015 11:44:06
  --  Description:        Procedure that will handle create and update of
  --                      relationship between account.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/05/2015    Dalit A. Raviv  initial build  
  --  1.1   04.03.19     Lingaraj          INC0148774 - remove all call s to  xxobjt_oa2sf_interface_pkg.insert_into_interface
  --------------------------------------------------------------------
  function custacctrelate(p_subscription_guid in raw,
                          p_event             in out wf_event_t) return varchar2 is

    l_plist             wf_parameter_list_t := p_event.getparameterlist();
    l_account_id        number;
    l_relate_account_id number;
    l_user_id           number;
    l_oa2sf_rec         xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
    l_err_code          varchar2(10)   := 0;
    l_err_desc          varchar2(2500) := null;

    -- cust_account_id and related_cust_account_id are not a unique identifier
    -- therefore this cursor will retrieve all records for the combination that
    -- changed at the last 2 hr, and get the unique cust_acct_relate_id
    cursor c_pop (p_cust_account_id in number,
                  p_related_cust_account_id in number) is
      select cust_acct_relate_id
      from   hz_cust_acct_relate_all     rel
      where  rel.cust_account_id         = p_cust_account_id
      and    rel.related_cust_account_id = p_related_cust_account_id
      and    rel.last_update_date        > sysdate -2/24;

  begin
    -- get values from xml parameters
    l_account_id        := wf_event.getvalueforparameter('CUST_ACCOUNT_ID', l_plist);
    l_relate_account_id := wf_event.getvalueforparameter('RELATED_CUST_ACCOUNT_ID', l_plist);
    l_user_id           := wf_event.getvalueforparameter('USER_ID', l_plist);
    /* INC0148774 Comment Start
    -- check user is not SF - do not want to enter record if the user that did the change is SF.
    if l_user_id <> 4290 then
      for r_pop in c_pop (l_account_id, l_relate_account_id) loop
        l_oa2sf_rec.source_id   := r_pop.cust_acct_relate_id;
        l_oa2sf_rec.source_name := 'ACC_RELATE';
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                         p_err_code  => l_err_code,  -- o v
                                                         p_err_msg   => l_err_desc); -- o v

      end loop;
    end if;
    */ --INC0148774 Comment End
    return 'SUCCESS';
  exception
    when others then
      wf_core.context('XXHZ_SF_BUSINESS_EVENTS_PKG',
                      'CustAcctRelate'||' '||SQLERRM,
                      p_event.geteventname(),
                      p_subscription_guid);
      wf_event.seterrorinfo(p_event, 'ERROR');

      return 'ERROR';
  end CustAcctRelate;

  --------------------------------------------------------------------
  --  customization code: CHG0036771 - Business event on merge table to execute SFDC merge process
  --  name:               CustAcctMerge
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/05/2015 11:44:06
  --  Description:        Procedure that will handle customer account merge
  --                      this function will be called from business event
--                        oracle.apps.ar.hz.CustAccount.merge and will enter record
--                        to oA2SF interface table.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/05/2015    Dalit A. Raviv  initial build          
  --  1.1   04.03.19     Lingaraj          INC0148774 - remove all call s to  xxobjt_oa2sf_interface_pkg.insert_into_interface
  --------------------------------------------------------------------
  function Cust_Acct_Merge (p_subscription_guid in raw,
	                          p_event             in out wf_event_t) return varchar2 is

    l_plist       wf_parameter_list_t := p_event.getparameterlist();
    l_oa2sf_rec   xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
    l_err_code    varchar2(10)   := 0;
    l_err_desc    varchar2(2500) := null;
    l_customer_merge_header_id   number;

  begin 
    /* INC0148774 Comment Start
    -- get values from xml parameters
    l_customer_merge_header_id := wf_event.getvalueforparameter('customer_merge_header_id', l_plist);

    l_oa2sf_rec.source_id   := l_customer_merge_header_id;
    l_oa2sf_rec.source_name := 'ACC_MERGE';
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code  => l_err_code,  -- o v
                                                     p_err_msg   => l_err_desc); -- o v

    */ --INC0148774 Comment End
    return 'SUCCESS';
  exception
    when others then
      wf_core.context('XXHZ_SF_BUSINESS_EVENTS_PKG',
                      'Cust_Acct_Merge'||' '||SQLERRM,
                      p_event.geteventname(),
                      p_subscription_guid);
      wf_event.seterrorinfo(p_event, 'ERROR');

      return 'ERROR';

  end Cust_Acct_Merge;

  --------------------------------------------------------------------
  --  customization code: CHG0034741 - New Interface OA2SF for Account relationships
  --  name:               get_business_events_params
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      17/05/2015 11:44:06
  --  Description:        function that can help to know what are the parameters
  --                      of the xml. for the use of developers only.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/05/2015    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  function get_business_events_params (p_subscription_guid in raw,
                                       p_event             in out wf_event_t) return varchar2 is

    l_plist                      wf_parameter_list_t := p_event.getparameterlist();
    n_current_parameter_position number := 1;
    n_total_number_of_parameters integer;
    l_parameter_name             varchar2(30);
    l_parameter_value            varchar2(4000);
  begin
    n_total_number_of_parameters := l_plist.COUNT();
    dbms_output.put_line('Name of the event is '||p_event.geteventname());
    dbms_output.put_line('Key of the event is '||p_event.geteventkey());
    dbms_output.put_line('Event Data is '||p_event.EVENT_DATA);
    dbms_output.put_line('Total number of parameters passed to event are '||n_total_number_of_parameters);
    --xxobjt_debug_proc('Name of the event is', p_event.geteventname());
    --xxobjt_debug_proc('Key of the event is', p_event.geteventkey());
    --xxobjt_debug_proc('Event Data is', p_event.EVENT_DATA);
    --xxobjt_debug_proc('Total number of parameters passed to event are', n_total_number_of_parameters);

    WHILE (n_current_parameter_position <= n_total_number_of_parameters) LOOP
      l_parameter_name  := l_plist(n_current_parameter_position).getname();
      l_parameter_value := l_plist(n_current_parameter_position).getvalue();
      dbms_output.put_line('Parameter Name => '||l_parameter_name||' has value => ' || l_parameter_value);
      --xxobjt_debug_proc('Parameter Name => ' || l_parameter_name , ' has value => ' || l_parameter_value);
      n_current_parameter_position := n_current_parameter_position + 1;
    END LOOP;

    /*
    --Use the below SQL to get insight into the business events from the deferred queue itself.
    SELECT wd.user_data.event_name,
           sender_name,
           sender_address,
           sender_protocol,
           wd.user_data.event_key,
           rank() over(PARTITION BY wd.user_data.event_name, wd.user_data.event_key ORDER BY n.NAME) AS serial_no,
           n.NAME parameter_name,
           n.VALUE parameter_value,
           decode(state,
                  0,'0 = Ready',
                  1,'1 = Delayed',
                  2,'2 = Retained',
                  3,'3 = Exception',
                  4,'4 = Wait',
                  to_char(state)) state,
           wd.user_data.send_date,
           wd.user_data.error_message,
           wd.user_data.error_stack,
           wd.msgid,
           wd.delay
    FROM   apps.wf_deferred wd, TABLE(wd.user_data.parameter_list) n
    WHERE  wd.user_data.send_date > SYSDATE - .1
    AND    wd.user_data.event_name LIKE '%'
    ORDER BY wd.user_data.send_date DESC, wd.user_data.event_name, wd.user_data.event_key, n.name
    */

    return 'SUCCESS';
  exception
    when others then
      wf_core.context('XXHZ_SF_BUSINESS_EVENTS_PKG',
	          'get_business_events_params' || ' ' || SQLERRM,
	          p_event.geteventname(),
	          p_subscription_guid);
      wf_event.seterrorinfo(p_event, 'ERROR');

      return 'ERROR';
  end get_business_events_params;

end XXHZ_SF_BUSINESS_EVENTS_PKG;
/