create or replace PACKAGE BODY XXOE_AR_INTF_UPDATE_WF AS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    xxoe_ar_intf_update_wf.bdy
  Author's Name:   Sandeep Akula
  Date Written:    21-JULY-2015
  Purpose:         Order Line Workflow Customizations 
  Program Style:   Stored Package BODY
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  21-JULY-2015        1.0                  Sandeep Akula    Initial Version (CHG0036062)
  ---------------------------------------------------------------------------------------------------*/
c_debug_module CONSTANT VARCHAR2(100) := 'xxoe.order_line_approval.xxoe_ar_intf_update_wf.';
--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    initialize_attributes
  Author's Name:   Sandeep Akula
  Date Written:    21-JULY-2015
  Purpose:         Initializes all Item Attributes used in process XX: AR Interface Updates
  Program Style:   Procedure Definition
  Called From:     Called in OEOL Workflow (Process: XX: AR Interface Updates)
  Workflow Usage Details:
                     Item Type: OM Order Line
                     Process Internal Name: XXAR_INTERFACE_UPDATES
                     Process Display Name: XX: AR Interface Updates
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0036062
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE initialize_attributes(itemtype  IN VARCHAR2,
                                itemkey   IN VARCHAR2,
                                actid     IN NUMBER,
                                funcmode  IN VARCHAR2,
                                resultout OUT NOCOPY VARCHAR2) IS
l_line_id          NUMBER;
l_to_role          fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXOE_AR_INTF_UPDATE_FAILURE_ROLE');
l_cc_list          fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXOE_AR_INTF_UPDATE_FAILURE_CC_LIST');

BEGIN

     -- Debug Message 
    fnd_log.string(log_level => fnd_log.level_event,
	                 module    => c_debug_module ||'initialize_attributes',
	                 message   => 'Start of Procedure initialize_attributes');

l_line_id := to_number(itemkey); 

wf_engine.setitemattrnumber(itemtype,
                            itemkey,
                            'ORDER_LINE_ID',
                            l_line_id);

wf_engine.setitemattrtext(itemtype,
                          itemkey,
                          'XX_AR_FAILURE_ROLE',
                          l_to_role);
                          
wf_engine.setitemattrtext(itemtype,
                          itemkey,
                          'XX_AR_UPDATE_CC_MAIL',
                          l_cc_list);
                          
  -- Debug Message 
    fnd_log.string(log_level => fnd_log.level_event,
	                 module    => c_debug_module ||'initialize_attributes',
	                 message   => 'End of Procedure initialize_attributes'||
                                'l_line_id :'||l_line_id||
                                'l_to_role :'||l_to_role||
                                'l_cc_list :'||l_cc_list);                          

END initialize_attributes;
--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    is_line_eligible
  Author's Name:   Sandeep Akula
  Date Written:    21-JULY-2015
  Purpose:         Checks if the Order Line is eligible for updating the corresponding record in the ar interface table 
  Program Style:   Procedure Definition
  Called From:     Called in OEOL Workflow (Process: XX: AR Interface Updates)
  Workflow Usage Details:
                     Item Type: OM Order Line
                     Process Internal Name: XXAR_INTERFACE_UPDATES
                     Process Display Name: XX: AR Interface Updates
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0036062
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE is_line_eligible(itemtype  IN VARCHAR2,
                           itemkey   IN VARCHAR2,
                           actid     IN NUMBER,
                           funcmode  IN VARCHAR2,
                           resultout OUT NOCOPY VARCHAR2) IS
l_line_id          NUMBER;
l_cnt NUMBER;
l_order_type oe_transaction_types_tl.name%type;
BEGIN

     -- Debug Message 
    fnd_log.string(log_level => fnd_log.level_event,
	                 module    => c_debug_module ||'is_line_eligible',
	                 message   => 'Start of Procedure is_line_eligible');

l_line_id := to_number(itemkey);  

begin
select ott.name
into l_order_type
from oe_order_lines_all ool,
     oe_order_headers_all ooh,
     oe_transaction_types_tl ott
where ool.header_id = ooh.header_id and
      ool.org_id = ooh.org_id and
      ooh.order_type_id = ott.transaction_type_id and
      ott.language = 'US' and
      ool.line_id = l_line_id;
exception
when others then
l_order_type := NULL;
end;

    -- Debug Message 
    fnd_log.string(log_level => fnd_log.level_event,
	                 module    => c_debug_module ||'is_line_eligible',
	                 message   => 'l_order_type :'||l_order_type);
                   

IF l_order_type IS NULL THEN
resultout := wf_engine.eng_completed || ':' || 'N';
ELSE

select count(*)
into l_cnt
from oe_lookups
where lookup_type = 'XXOE_AR_INTF_UPDATE_ORDER_TYPE' and
      enabled_flag = 'Y' and
      TRUNC(SYSDATE) BETWEEN TRUNC(START_DATE_ACTIVE) AND NVL(END_DATE_ACTIVE,TRUNC(SYSDATE)) AND
      UPPER(lookup_code) = UPPER(l_order_type);
      
      -- Debug Message 
    fnd_log.string(log_level => fnd_log.level_event,
	                 module    => c_debug_module ||'is_line_eligible',
	                 message   => 'l_cnt :'||l_cnt);
         
      
if  l_cnt > '0' then
resultout := wf_engine.eng_completed || ':' || 'Y';
else
resultout := wf_engine.eng_completed || ':' || 'N';
end if;
      
END IF;  

      -- Debug Message 
    fnd_log.string(log_level => fnd_log.level_event,
	                 module    => c_debug_module ||'is_line_eligible',
	                 message   => 'End of Procedure is_line_eligible');
 
END is_line_eligible;

-------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    update_ar_interface
  Author's Name:   Sandeep Akula
  Date Written:    21-JULY-2015
  Purpose:         Updates trx_Date column in ra_interface_lines_all table 
  Program Style:   Procedure Definition
  Called From:     Called in OEOL Workflow (Process: XX: AR Interface Updates)
  Workflow Usage Details:
                     Item Type: OM Order Line
                     Process Internal Name: XXAR_INTERFACE_UPDATES
                     Process Display Name: XX: AR Interface Updates
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0036062
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE update_ar_interface(itemtype  IN VARCHAR2,
                              itemkey   IN VARCHAR2,
                              actid     IN NUMBER,
                              funcmode  IN VARCHAR2,
                              resultout OUT NOCOPY VARCHAR2) IS

BEGIN

     -- Debug Message 
    fnd_log.string(log_level => fnd_log.level_event,
	                 module    => c_debug_module ||'update_ar_interface',
	                 message   => 'Start of Procedure update_ar_interface');
                   
 -- Debug Message 
    fnd_log.string(log_level => fnd_log.level_event,
	                 module    => c_debug_module ||'update_ar_interface',
	                 message   => 'Line ID :'||itemkey);

update ra_interface_lines_all a
set a.trx_date = sysdate
where a.INTERFACE_LINE_ATTRIBUTE6 = itemkey;
--commit;  -- Commented Commit as Workflow does an Auto Commit 

resultout := wf_engine.eng_completed || ':' || 'SUCCESS';

  -- Debug Message 
    fnd_log.string(log_level => fnd_log.level_event,
	                 module    => c_debug_module ||'update_ar_interface',
	                 message   => 'End of Procedure update_ar_interface');

EXCEPTION
WHEN OTHERS THEN
--resultout := wf_engine.eng_completed || ':' || 'SQL ERROR :'||SQLERRM;
resultout := wf_engine.eng_completed || ':' || 'FAIL';
 -- Debug Message 
    fnd_log.string(log_level => fnd_log.level_event,
	                 module    => c_debug_module ||'update_ar_interface',
	                 message   => 'SQL Error :'||SQLERRM);
END update_ar_interface;
END XXOE_AR_INTF_UPDATE_WF;  
/


