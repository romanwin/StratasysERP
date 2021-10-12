create or replace package body xxom_order_header_wf AS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    xxom_order_header_wf.bdy
  Author's Name:   Sandeep Akula
  Date Written:    02-MARCH-2015
  Purpose:         Order Header Workflow Customizations
  Program Style:   Stored Package BODY
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-MARCH-2015        1.0                  Sandeep Akula    Initial Version (CHG0034606)
  14-AUG-2015          1.1                  Sandeep Akula    Modified Procedure retry_om_header_activity (CHG0036214)
  09-AUG-2018          1.2                  Bellona(TCS)     Modified Procedure get_wait_time (CHG0043684)
  ---------------------------------------------------------------------------------------------------*/



--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_wait_time
  Author's Name:   Sandeep Akula
  Date Written:    02-MARCH-2015
  Purpose:         Derives the value for profile XXOM_ORDER_HEADER_WF_WAIT_TIME and updates the corresponding workflow Attribute
  Program Style:   Procedure Definition
  Called From:     Called in OEOH Workflow (Process: XX: Order Flow - Generic)
  Workflow Usage Details:
                     Item Type: OM Order Header
                     Process Internal Name: XX_R_STANDARD_HEADER
                     Process Display Name: XX: Order Flow - Generic
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034606
  09-AUG-2018          1.2                  Bellona(TCS)      CHG0043684 - Added logic to fetch wait time based on order transaction type
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE get_wait_time(itemtype  IN VARCHAR2,
                        itemkey   IN VARCHAR2,
                        actid     IN NUMBER,
                        funcmode  IN VARCHAR2,
                        resultout OUT NOCOPY VARCHAR2) IS

l_wait_time NUMBER := '';
l_order NUMBER := ''; --CHG0043684  
l_org NUMBER := ''; --CHG0043684

 BEGIN

 --CHG0043684 code change start 
   l_order :=wf_engine.GetItemAttrnumber( itemtype,
                                itemkey,
                                'ORDER_NUMBER' );
                                
   l_org :=wf_engine.GetItemAttrnumber( itemtype,
                                itemkey,
                                'ORG_ID' ); 
                                
   BEGIN
   --Fetching wait time based on order transaction type from DFF segment - 'Header Closure Time Delay'  
    SELECT to_number(otta_dfv.header_closure_time_delay) 
	into l_wait_time
	FROM   oe_order_headers_all         ooha,
		   oe_transaction_types_all     otta,
		   oe_transaction_types_all_dfv otta_dfv
	WHERE  ooha.order_number = l_order --1192172
	AND    ooha.org_id = l_org
	AND    ooha.order_type_id = otta.transaction_type_id
	AND    otta_dfv.row_id = otta.rowid;                                                               
   
   EXCEPTION
   WHEN NO_DATA_FOUND THEN                            
   l_wait_time := NVL(fnd_profile.value('XXOM_ORDER_HEADER_WF_WAIT_TIME'),'0');
   WHEN OTHERS THEN
   l_wait_time := NVL(fnd_profile.value('XXOM_ORDER_HEADER_WF_WAIT_TIME'),'0');
   END;
   
 --CHG0043684 code change end   
    wf_engine.setitemattrnumber(itemtype,
                                itemkey,
                                'XXWAIT_TIME',
                                l_wait_time);

    resultout := wf_engine.eng_completed || ':' || 'l_wait_time '||l_wait_time;

EXCEPTION
WHEN OTHERS THEN
wf_engine.setitemattrnumber(itemtype,
                            itemkey,
                            'XXWAIT_TIME',
                            '0');
resultout := wf_engine.eng_completed || ':' || 'EXCP l_wait_time '||l_wait_time||':0';
END get_wait_time;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:  retry_om_header_activity
  Author's Name:   Sandeep Akula
  Date Written:    22-APRIL-2015
  Purpose:         Retry the Wait Activity in OEOH WOrkflow
  Program Style:   Procedure Definition
  Called From:     Concurrent Program "XX: OM Retry Header Workflow Activity"
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034606
  14-AUG-2015          1.1                  Sandeep Akula     Added Cursor c_cancelled_orders -- CHG0036214
                                                              Added Code to close Order with all Lines in Cancelled status -- CHG0036214
                                                              Added Code to close Order with few Lines in Cancelled status and others in Closed status -- CHG0036214
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE retry_om_header_activity(errbuf OUT VARCHAR2,
                                   retcode OUT NUMBER,
                                   p_itemtype IN VARCHAR2,
                                   p_activity IN VARCHAR2,
                                   p_command IN VARCHAR2,
                                   p_start_date IN VARCHAR2,
                                   p_end_date IN VARCHAR2) IS

-- Cursor to get all Orders whose Lines have One flow status code
CURSOR c_orders IS
select ooh1.*
from oe_order_headers_all ooh1,
     oe_transaction_types_vl ott
where ooh1.flow_status_code = 'BOOKED' and
      ooh1.order_type_id = ott.transaction_type_id and
      UPPER(ott.name) NOT IN (select upper(lookup_code)
                              from oe_lookups
                              where lookup_type = 'XXOE_OEOH_WF_RETRY_EXCLUSION'
                                AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(start_date_active,SYSDATE)) AND TRUNC(NVL(end_date_active,SYSDATE))) and
      exists (select lines.header_id,lines.org_id,count(*)
              from ( select ool.header_id,ool.org_id,ool.flow_status_code
                     from oe_order_lines_all ool
                     group by ool.header_id,ool.org_id,ool.flow_status_code) lines
              where lines.header_id = ooh1.header_id and
                    lines.org_id = ooh1.org_id and
                    lines.flow_status_code NOT IN ('CANCELLED') -- Added condition SAkula 07/16/2015 CHG0036214
              group by lines.header_id,lines.org_id
              having count(*) = 1) and
      ooh1.ordered_date BETWEEN NVL(fnd_date.canonical_to_date(p_start_date),ooh1.ordered_date) AND NVL(fnd_date.canonical_to_date(p_end_date),ooh1.ordered_date);

-- Added SAkula 07/16/2015 CHG0036214
-- Cursor to get all Orders whose Lines are Cancelled
CURSOR c_cancelled_orders IS
select ooh1.*
from oe_order_headers_all ooh1,
     oe_transaction_types_vl ott
where ooh1.flow_status_code = 'BOOKED' and
      ooh1.order_type_id = ott.transaction_type_id and
      UPPER(ott.name) NOT IN (select upper(lookup_code)
                              from oe_lookups
                              where lookup_type = 'XXOE_OEOH_WF_RETRY_EXCLUSION'
                                AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(start_date_active,SYSDATE)) AND TRUNC(NVL(end_date_active,SYSDATE))) and
      exists (select lines.header_id,lines.org_id,count(*)
              from ( select ool.header_id,ool.org_id,ool.flow_status_code
                     from oe_order_lines_all ool
                     group by ool.header_id,ool.org_id,ool.flow_status_code) lines
              where lines.header_id = ooh1.header_id and
                    lines.org_id = ooh1.org_id and
                    lines.flow_status_code NOT IN ('CLOSED')
              group by lines.header_id,lines.org_id
              having count(*) = 1) and
      ooh1.ordered_date BETWEEN NVL(fnd_date.canonical_to_date(p_start_date),ooh1.ordered_date) AND NVL(fnd_date.canonical_to_date(p_end_date),ooh1.ordered_date);

TYPE s_orders IS TABLE OF oe_order_headers_all%ROWTYPE
INDEX BY PLS_INTEGER;
l_s_orders s_orders;

l_cnt NUMBER;
l_cnt2 NUMBER;
l_code varchar2(250);

BEGIN

FND_FILE.PUT_LINE(FND_FILE.LOG,'Start Time:'||to_char(SYSDATE,'MM/DD/RRRR HH24:MI:SS'));

/****************************************************************************************************************/
-- Processing Closed Orders
/****************************************************************************************************************/

OPEN c_orders;
LOOP

--FETCH c_orders BULK COLLECT INTO l_s_orders LIMIT 100;
FETCH c_orders BULK COLLECT INTO l_s_orders;
EXIT WHEN l_s_orders.COUNT = 0;
l_cnt := '0';
l_cnt2 := '0';
FOR indx IN 1 .. l_s_orders.COUNT
LOOP
l_cnt := l_cnt + 1;
begin

l_code := '';
select flow_status_code
into l_code
from oe_order_lines_all
where header_id = l_s_orders(indx).header_id and
      org_id = l_s_orders(indx).org_id and
      flow_status_code NOT IN ('CANCELLED')
group by flow_status_code;

IF l_code = 'CLOSED' THEN
l_cnt2 := l_cnt2 + 1;
-- Retry Wait Activity for Orders whose all Lines are Closed
WF_ENGINE.HANDLEERROR(ITEMTYPE => p_itemtype,
                      ITEMKEY  => l_s_orders(indx).header_id,
                      ACTIVITY => p_activity,
                      COMMAND  => p_command);
END IF;



exception
when others then
FND_FILE.PUT_LINE(FND_FILE.LOG,'Others Exception for Order :'||l_s_orders(indx).order_number);
FND_FILE.PUT_LINE(FND_FILE.LOG,'Sql error is :'||sqlerrm);
end;

end loop; -- PL/SQL Collection Loop

END LOOP;  -- Main Cursor Loop

FND_FILE.PUT_LINE(FND_FILE.LOG,'Processing Orders with all lines closed OR Lines which have been Cancelled/Closed');
FND_FILE.PUT_LINE(FND_FILE.LOG,'Total Record Count :'||l_cnt);
FND_FILE.PUT_LINE(FND_FILE.LOG,'Open Orders that were processed Count :'||l_cnt2);

-- Added SAkula 07/16/2015 CHG0036214
/****************************************************************************************************************/
-- Processing Cancelled Orders
/****************************************************************************************************************/

OPEN c_cancelled_orders;
LOOP

--FETCH c_orders BULK COLLECT INTO l_s_orders LIMIT 100;
FETCH c_cancelled_orders BULK COLLECT INTO l_s_orders;
EXIT WHEN l_s_orders.COUNT = 0;
l_cnt := '0';
l_cnt2 := '0';
FOR indx IN 1 .. l_s_orders.COUNT
LOOP
l_cnt := l_cnt + 1;
begin

l_code := '';
select flow_status_code
into l_code
from oe_order_lines_all
where header_id = l_s_orders(indx).header_id and
      org_id = l_s_orders(indx).org_id and
      flow_status_code NOT IN ('CLOSED')
group by flow_status_code;

IF l_code = 'CANCELLED' THEN
l_cnt2 := l_cnt2 + 1;
-- Retry Wait Activity for Orders whose all Lines are Closed
WF_ENGINE.HANDLEERROR(ITEMTYPE => p_itemtype,
                      ITEMKEY  => l_s_orders(indx).header_id,
                      ACTIVITY => p_activity,
                      COMMAND  => p_command);
END IF;



exception
when others then
FND_FILE.PUT_LINE(FND_FILE.LOG,'Others Exception for Order :'||l_s_orders(indx).order_number);
FND_FILE.PUT_LINE(FND_FILE.LOG,'Sql error is :'||sqlerrm);
end;

end loop; -- PL/SQL Collection Loop

END LOOP;  -- Main Cursor Loop

FND_FILE.PUT_LINE(FND_FILE.LOG,'Processing Orders with all lines Cancelled');
FND_FILE.PUT_LINE(FND_FILE.LOG,'Total Record Count :'||l_cnt);
FND_FILE.PUT_LINE(FND_FILE.LOG,'Open Orders that were processed Count :'||l_cnt2);
FND_FILE.PUT_LINE(FND_FILE.LOG,'Completed Sucessfully');
FND_FILE.PUT_LINE(FND_FILE.LOG,'End Time:'||to_char(SYSDATE,'MM/DD/RRRR HH24:MI:SS'));

COMMIT;

EXCEPTION
WHEN OTHERS THEN
FND_FILE.PUT_LINE(FND_FILE.LOG,'Sql error is :'||sqlerrm);
retcode := '2';
errbuf := 'Sql error is :'||sqlerrm;
END retry_om_header_activity;
END xxom_order_header_wf;
/
