CREATE OR REPLACE PACKAGE BODY XXOM_UTIL_PKG IS

--------------------------------------------------------------------
  --  customization code: CUSTxxx
  --  name:               XXOM_UTIL_PKG
  --  create by:          Rimpi
  --  $Revision:          1.0
  --  creation date:       30-Mar-2017
  --  Purpose :           CHG0040391: Package to cancel the Sales Order from Conc prog: XXSSYS Order/Line Cancellation Program
  ----------------------------------------------------------------------
  --  ver   date                 name            desc
  --  1.0   30-Mar-2017    Rimpi            CHG0040391: initial build
  --  1.1   30-Aug-2017    Lingaraj         INC0100407 - Line Cancellation Not working When Split Line
  --  2.0   10-Nov-2017    Diptasurjya      CHG0041821: Script to close order header workflow where all lines
  --                                                    are in closed or cancelled state
  --                                            added procedure : close_order           
  -----------------------------------------------------------------------

  Function get_header_or_line_status(p_id NUMBER, p_type Varchar2)
           Return Varchar2
  IS
  p_return_status                         VARCHAR2(50);
  Begin

     If p_type = 'H' Then
        select flow_status_code into p_return_status from
        oe_order_headers_all where header_id = p_id;
     ElsIf p_type = 'L' Then
        select flow_status_code into p_return_status from
        oe_order_lines_all where line_id = p_id;
     End If;
     fnd_file.put_line(fnd_file.LOG,'Type :'|| p_type ||' Status :'|| p_return_status);
     Return  p_return_status;
  Exception
  When No_Data_Found Then
     Return '';
  End get_header_or_line_status;

  --------------------------------------------------------------------
  --  name:             cancel_order_header
  --  create by:        Rimpi
  --  Revision:         1.0
  --  creation date:    30-Mar-2017
  --------------------------------------------------------------------
  --  purpose :         CHG0040391: Called from Procedure: cancel_order to cancel the Sales Order-HEADER
  ----------------------------------------------------------------------
  --  ver   date                 name            desc
  --  1.0   30-Mar-2017    Rimpi            CHG0040391: initial build
  --  1.1   30-Aug-2017    Lingaraj         INC0100407 - Line Cancellation Not working When Split Line
  -----------------------------------------------------------------------

  PROCEDURE cancel_order_header (p_header_id IN NUMBER,
                                 p_org_id    IN NUMBER,
                                 x_return_status OUT VARCHAR2,
                                 x_error         OUT VARCHAR2
                                 )
  IS

   l_msg_count          NUMBER;
   l_msg_index_out      NUMBER;
   l_msg_data           VARCHAR2(3000);
   l_cancel_reason_code VARCHAR2(20) := 'Not provided';
    -- IN Variables --
   l_header_rec         oe_order_pub.header_rec_type;
   l_line_tbl           oe_order_pub.line_tbl_type;
   l_action_request_tbl oe_order_pub.request_tbl_type;
   l_line_adj_tbl       oe_order_pub.line_adj_tbl_type;

   -- OUT Variables --
   l_header_rec_out             oe_order_pub.header_rec_type;
   l_header_val_rec_out         oe_order_pub.header_val_rec_type;
   l_header_adj_tbl_out         oe_order_pub.header_adj_tbl_type;
   l_header_adj_val_tbl_out     oe_order_pub.header_adj_val_tbl_type;
   l_header_price_att_tbl_out   oe_order_pub.header_price_att_tbl_type;
   l_header_adj_att_tbl_out     oe_order_pub.header_adj_att_tbl_type;
   l_header_adj_assoc_tbl_out   oe_order_pub.header_adj_assoc_tbl_type;
   l_header_scredit_tbl_out     oe_order_pub.header_scredit_tbl_type;
   l_header_scredit_val_tbl_out oe_order_pub.header_scredit_val_tbl_type;
   l_line_tbl_out               oe_order_pub.line_tbl_type;
   l_line_val_tbl_out           oe_order_pub.line_val_tbl_type;
   l_line_adj_tbl_out           oe_order_pub.line_adj_tbl_type;
   l_line_adj_val_tbl_out       oe_order_pub.line_adj_val_tbl_type;
   l_line_price_att_tbl_out     oe_order_pub.line_price_att_tbl_type;
   l_line_adj_att_tbl_out       oe_order_pub.line_adj_att_tbl_type;
   l_line_adj_assoc_tbl_out     oe_order_pub.line_adj_assoc_tbl_type;
   l_line_scredit_tbl_out       oe_order_pub.line_scredit_tbl_type;
   l_line_scredit_val_tbl_out   oe_order_pub.line_scredit_val_tbl_type;
   l_lot_serial_tbl_out         oe_order_pub.lot_serial_tbl_type;
   l_lot_serial_val_tbl_out     oe_order_pub.lot_serial_val_tbl_type;
   l_action_request_tbl_out     oe_order_pub.request_tbl_type;

 BEGIN
  x_return_status := fnd_api.g_ret_sts_success;
  fnd_file.put_line(fnd_file.LOG,'Inside Package - cancel_order_header - Full Order Cancellation');
  fnd_file.put_line(fnd_file.LOG,'+----------------------------------------------------------------------------------------------------+');

  IF p_header_id  IS NOT NULL Then
   -- CANCEL HEADER --
     l_header_rec                := oe_order_pub.g_miss_header_rec;
     l_header_rec.operation      := oe_globals.g_opr_update;
     l_header_rec.header_id      := p_header_id;
     l_header_rec.cancelled_flag := 'Y';
     l_header_rec.change_reason  := l_cancel_reason_code;

    -- CALLING THE API TO CANCEL AN ORDER --
    oe_order_pub.process_order(p_api_version_number => 1.0,
                              p_header_rec         => l_header_rec,
                              p_org_id             => p_org_id,
                              p_line_tbl           => l_line_tbl,
                              p_action_request_tbl => l_action_request_tbl,
                              p_line_adj_tbl       => l_line_adj_tbl,
                              p_init_msg_list      => fnd_api.g_false,
                              p_return_values      => fnd_api.g_false,
                              p_action_commit      => fnd_api.g_false,
                              -- OUT variables
                              x_header_rec             => l_header_rec_out,
                              x_header_val_rec         => l_header_val_rec_out,
                              x_header_adj_tbl         => l_header_adj_tbl_out,
                              x_header_adj_val_tbl     => l_header_adj_val_tbl_out,
                              x_header_price_att_tbl   => l_header_price_att_tbl_out,
                              x_header_adj_att_tbl     => l_header_adj_att_tbl_out,
                              x_header_adj_assoc_tbl   => l_header_adj_assoc_tbl_out,
                              x_header_scredit_tbl     => l_header_scredit_tbl_out,
                              x_header_scredit_val_tbl => l_header_scredit_val_tbl_out,
                              x_line_tbl               => l_line_tbl_out,
                              x_line_val_tbl           => l_line_val_tbl_out,
                              x_line_adj_tbl           => l_line_adj_tbl_out,
                              x_line_adj_val_tbl       => l_line_adj_val_tbl_out,
                              x_line_price_att_tbl     => l_line_price_att_tbl_out,
                              x_line_adj_att_tbl       => l_line_adj_att_tbl_out,
                              x_line_adj_assoc_tbl     => l_line_adj_assoc_tbl_out,
                              x_line_scredit_tbl       => l_line_scredit_tbl_out,
                              x_line_scredit_val_tbl   => l_line_scredit_val_tbl_out,
                              x_lot_serial_tbl         => l_lot_serial_tbl_out,
                              x_lot_serial_val_tbl     => l_lot_serial_val_tbl_out,
                              x_action_request_tbl     => l_action_request_tbl_out,
                              x_return_status          => x_return_status,
                              x_msg_count              => l_msg_count,
                              x_msg_data               => x_error);

       fnd_file.put_line(fnd_file.LOG,'Completion of oe_order_pub.process_order API ,'
                                                  ||'Return Status :'||x_return_status
                                                  ||', Message Count :'||l_msg_count
                                                  ||',Error :'||x_error
                                                  );

       --IF x_return_status != fnd_api.g_ret_sts_success Then
          FOR i IN 1 .. l_msg_count LOOP
             Oe_Msg_Pub.get( p_msg_index => i
                           , p_encoded => Fnd_Api.G_FALSE
                           , p_data => l_msg_data
                           , p_msg_index_out => l_msg_index_out
                          );
             x_error := x_error || '['||l_msg_index_out||']'||l_msg_data;

          END LOOP;
       --END IF;
         fnd_file.put_line(fnd_file.LOG,x_error);
  END IF;
 fnd_file.put_line(fnd_file.LOG,'+----------------------------------------------------------------------------------------------------+');
 Exception
 When Others Then
  x_return_status := fnd_api.g_ret_sts_error;
  x_error := sqlerrm;
END cancel_order_header;

    --------------------------------------------------------------------
  --  name:             cancel_order_line_datafix
  --  create by:        Rimpi
  --  Revision:         1.0
  --  creation date:    30-Mar-2017
  --------------------------------------------------------------------
  --  purpose :         CHG0040391: Called from Procedure: main to cancel the Sales Order-LINES
  ----------------------------------------------------------------------
  --  ver   date                 name            desc
  --  1.0   30-Mar-2017    Rimpi            CHG0040391: initial build
  --  1.1   30-Aug-2017    Lingaraj         INC0100407 - Line Cancellation Not working When Split Line
  -----------------------------------------------------------------------
  PROCEDURE cancel_order_line_datafix (p_header_id IN NUMBER,
                                       p_line_id   IN NUMBER,
                                       x_return_status OUT VARCHAR2,
                                       x_error         OUT VARCHAR2
                                      )
  IS

  l_lin_key       varchar2(30) := to_char(p_line_id);

  l_ordered_qty   number;
  l_flow_exists   varchar2(1);
  l_user_id       number;
  l_resp_id       number;
  l_resp_appl_id  number;
  l_ln_wf_enddate DATE;

  --------------------

  l_line_check        NUMBER;
  l_oe_interfaced     NUMBER;
  l_wms_org           VARCHAR2(1);
  l_otm_enabled_count NUMBER := 0;
  l_otm_enabled       VARCHAR2(1);
  l_cursor            INTEGER;
  l_stmt              VARCHAR2(4000);
  l_up_cursor         INTEGER;
  l_up_stmt           VARCHAR2(4000);
  l_ignore            NUMBER;
  l_ship_from_org_id  NUMBER;
  l_opm_enabled       BOOLEAN;
  l_fm_serial         VARCHAR2(30);
  l_to_serial         VARCHAR2(30);
  l_count             NUMBER := 0;
  l_is_del_empty      BOOLEAN := FALSE;
  l_interface_flag_tab  WSH_UTIL_CORE.COLUMN_TAB_TYPE;
  l_delivery_id_tab     WSH_UTIL_CORE.ID_TAB_TYPE;

  Line_Cannot_Be_Updated EXCEPTION;

  l_heading       varchar2(1) := 'N';


  ----cursor-----

  cursor line_check is
  select line_id
  from   oe_order_lines_all
  where  line_id = p_line_id
  and     ( open_flag = 'N'
            or nvl(invoiced_quantity,0) > 0
            or INVOICE_INTERFACE_STATUS_CODE = 'YES' ) ;
  cursor service_check is
  select count(*)
  from   oe_order_lines_all
  where  service_reference_type_code = 'ORDER'
  and    service_reference_line_id = p_line_id
  and    open_flag = 'Y';

  /* Cursors to fetch details and their Serial Number(s) */
  cursor wdd is
  select delivery_detail_id, transaction_temp_id, serial_number, inventory_item_id, to_serial_number
  from   wsh_delivery_details
  where  source_line_id = p_line_id
  and    source_code = 'OE'
  and    released_status in ('Y','C');

  cursor msnt(txn_temp_id number) is
  select fm_serial_number, to_serial_number
  from   mtl_serial_numbers_temp
  where  transaction_temp_id = txn_temp_id;


 cursor wsh_ifaced
  is
  select
    substr(wdd.source_line_number, 1, 15) line_num
  , substr(wdd.item_description, 1, 30) item_name
  , wdd.shipped_quantity
  , wdd.source_line_id line_id
  from  wsh_delivery_details wdd, oe_order_lines_all oel
  where wdd.inv_interfaced_flag     = 'Y'
  and   nvl(wdd.shipped_quantity,0) > 0
  and   oel.line_id                 = wdd.source_line_id
  and   oel.open_flag               = 'N'
  and   oel.ordered_quantity        = 0
  and   wdd.source_code             = 'OE'
  and   oel.line_id                 = p_line_id
  and   exists
      ( select 'x'
        from  mtl_material_transactions mmt
        where wdd.delivery_detail_id   = mmt.picking_line_id
        and   mmt.trx_source_line_id   = wdd.source_line_id
        and   mmt.transaction_source_type_id in ( 2,8 ));

 CURSOR c_detail_planning_cur (p_order_line_id IN NUMBER)
 IS
 SELECT NVL(wdd.ignore_for_planning,'N') ignore_for_planning
      , wda.delivery_id
      , wdd.delivery_detail_id
   FROM wsh_delivery_details wdd
      , wsh_delivery_assignments wda
  WHERE wdd.source_line_id = p_order_line_id
    AND wda.delivery_detail_id = wdd.delivery_detail_id
    AND wdd.source_code ='OE'
    AND wdd.released_status <> 'D';

 CURSOR c_delivery_detail_count(p_delivery_id IN NUMBER)
 IS
 SELECT 1
   FROM wsh_delivery_assignments wda
      , wsh_delivery_details wdd
  WHERE wda.delivery_id = p_delivery_id
    AND wda.delivery_detail_id = wdd.delivery_detail_id
    AND wdd.container_flag = 'N';


 begin
  x_return_status := 'S';
  /* Check if line can be canceled  */
  open line_check ;
  fetch line_check into l_line_check ;
  if line_check%found then
     close line_check;
     fnd_file.put_line(fnd_file.LOG,'Line is closed or Invoiced');
     raise Line_Cannot_Be_Updated;
  end if;
  close line_check;
  open service_check ;
  fetch service_check into l_line_check ;
  if l_line_check > 0 then
     close service_check;
     fnd_file.put_line(fnd_file.LOG,'There exist open service lines referencing this order line.');
     raise Line_Cannot_Be_Updated;
  end if;
  close service_check;

  /* Check if line belongs to WMS Org */
  begin
    select WSH_UTIL_VALIDATE.CHECK_WMS_ORG(ship_from_org_id), ship_from_org_id
    into   l_wms_org, l_ship_from_org_id
    from   oe_order_lines_all
    where  line_id = p_line_id;
  exception
    when no_data_found then
         fnd_file.put_line(fnd_file.LOG,'Unable to get the Organization');
         raise Line_Cannot_Be_Updated;
  end;
  if l_wms_org = 'Y' then
     /* Disallow cancellation if and only if there exist open delivery detail(s) for line
      under consideration. (Bug 6196723)*/
     DECLARE
       l_exist_count number := -1;
     BEGIN
        SELECT  Count(*)
            INTO l_exist_count
          FROM    wsh_delivery_details wdd, oe_order_lines_all line
          WHERE   line.line_id     = wdd.source_line_id
          AND     wdd.source_code  =  'OE'
          AND     line.line_id     = p_line_id
          AND     Nvl(wdd.released_status, 'N') <> 'D'
        ;
        IF ( l_exist_count > 0 ) THEN
          fnd_file.put_line(fnd_file.LOG,'This line belongs to a WMS Organization');
          fnd_file.put_line(fnd_file.LOG,'Please review the Metalink Note 416276.1 ');
          fnd_file.put_line(fnd_file.LOG,'to see how an order line belonging to a WMS Organization can be cancelled');
          raise Line_Cannot_Be_Updated;
        END IF;
     END;
  end if;


  l_flow_exists := 'Y';

  update oe_order_lines_all
  set    flow_status_code    = 'CANCELLED'
  ,      open_flag           = 'N'
  ,      cancelled_flag      = 'Y'
  ,      ordered_quantity    = 0
  ,      ordered_quantity2   = decode(ordered_quantity2,NULL,NULL,0)
  ,      schedule_ship_date        = NULL
  ,      schedule_arrival_date     = NULL
  ,      schedule_status_code      = NULL
  ,      shipping_quantity         = 0
  ,      shipping_quantity2        = decode(shipping_quantity2,NULL,NULL,0)
  ,      shipped_quantity          = 0
  ,      shipped_quantity2         = decode(shipped_quantity2,NULL,NULL,0)
  ,      actual_shipment_date      = NULL
  ,      fulfilled_flag            = NULL
  ,      fulfilled_quantity        = 0
  ,      fulfilled_quantity2       = decode(fulfilled_quantity2,NULL,NULL,0)
  ,      actual_fulfillment_date   = NULL
  ,      cancelled_quantity        = ordered_quantity + nvl(cancelled_quantity,0)
  ,      cancelled_quantity2       = Decode(ordered_quantity2, NULL, NULL, ordered_quantity2 + nvl(cancelled_quantity2, 0))
  ,      visible_demand_flag       = NULL
  ,      last_updated_by     = fnd_global.user_id  ---6156992
  ,      last_update_date    = sysdate
  where  line_id             = p_line_id;

  /* Added for bug 8532859 */
  delete from oe_line_sets
  where  line_id = p_line_id;

  Begin
    SELECT end_date
    INTO   l_ln_wf_enddate
    FROM   wf_items
    WHERE  item_type = 'OEOL'
    and    item_key  = l_lin_key
    AND    end_date IS NULL;

    select number_value
    into   l_user_id
    from   wf_item_attribute_values
    where  item_type = 'OEOL'
    and    item_key  = l_lin_key
    and    name      = 'USER_ID';

    select number_value
    into   l_resp_id
    from   wf_item_attribute_values
    where  item_type = 'OEOL'
    and    item_key  = l_lin_key
    and    name      = 'RESPONSIBILITY_ID';

    select number_value
    into   l_resp_appl_id
    from   wf_item_attribute_values
    where  item_type = 'OEOL'
    and    item_key  = l_lin_key
    and    name      = 'APPLICATION_ID';

    Exception
      When No_Data_Found Then
        l_flow_exists := 'N';
  End;

  if l_flow_exists = 'Y' then

    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);

    wf_engine.handleerror( OE_Globals.G_WFI_LIN
                         , l_lin_key
                         , 'CLOSE_LINE'
                         , 'RETRY'
                         , 'CANCEL'
                         );
  end if;

 for wsh_ifaced_rec in wsh_ifaced loop
    if l_heading = 'N' then
      fnd_file.put_line(fnd_file.LOG,' ');
      fnd_file.put_line(fnd_file.LOG,'Following Cancelled Lines have already been Interfaced to Inventory.');
      fnd_file.put_line(fnd_file.LOG,'Onhand Qty must be manually adjusted for these Items and Quantities.');
      fnd_file.put_line(fnd_file.LOG,' ');
      fnd_file.put_line(fnd_file.LOG,'+---------------+------------------------------+---------------+---------------+');
      fnd_file.put_line(fnd_file.LOG,'|Line No.       |Item Name                     |    Shipped Qty|        Line Id|');
      fnd_file.put_line(fnd_file.LOG,'+---------------+------------------------------+---------------+---------------+');
      l_heading := 'Y';
    end if;
    fnd_file.put_line(fnd_file.LOG,'|'||rpad(wsh_ifaced_rec.line_num, 15)||
                         '|'||rpad(wsh_ifaced_rec.item_name, 30)||
                         '|'||lpad(to_char(wsh_ifaced_rec.shipped_quantity), 15)||
                           '|'||lpad(to_char(wsh_ifaced_rec.line_id), 15)||'|');
  end loop;

  SELECT count(1)
   INTO l_otm_enabled_count
   FROM wsh_delivery_details wdd
      , oe_order_lines_all oel
  WHERE wdd.source_line_id   = oel.line_id
    and wdd.source_code = 'OE'
    and oel.cancelled_flag = 'Y'
    and wdd.ignore_for_planning = 'N'
    and oel.line_id = p_line_id
    and released_status <> 'D';

 IF l_otm_enabled_count > 0
 THEN
    FOR wdd_rec IN c_detail_planning_cur(p_line_id)
    LOOP
       IF wdd_rec.delivery_id IS NOT NULL
       THEN
          UPDATE wsh_delivery_assignments wda
             SET wda.delivery_id = NULL
               , wda.parent_delivery_detail_id = NULL
               , wda.last_updated_by           = -1
               , wda.last_update_date          = SYSDATE
           WHERE delivery_detail_id = wdd_rec.delivery_detail_id;

          IF wdd_rec.ignore_for_planning = 'N'
          THEN
             /*check if delivery is empty */
             l_count := 0;
             l_is_del_empty := FALSE;
             OPEN c_delivery_detail_count(wdd_rec.delivery_id);
                FETCH c_delivery_detail_count
                 INTO l_count;

                IF c_delivery_detail_count%FOUND THEN -- not empty
                   l_is_del_empty := FALSE;
                ELSE  -- empty
                   l_is_del_empty := TRUE;
                END IF;
             CLOSE c_delivery_detail_count;

             l_delivery_id_tab(1) := wdd_rec.delivery_id;
             IF l_is_del_empty THEN
                l_interface_flag_tab(1) := WSH_NEW_DELIVERIES_PVT.C_TMS_DELETE_REQUIRED;
             ELSE
                l_interface_flag_tab(1) := NULL;
             END IF;
             x_return_status := 'S';
             wsh_new_deliveries_pvt.update_tms_interface_flag(
                                    p_delivery_id_tab        => l_delivery_id_tab
                                  , p_tms_interface_flag_tab => l_interface_flag_tab
                                  , x_return_status          => x_return_status);
             IF x_return_status <> 'S' THEN
                raise_application_error(-20000, 'Error while updating tms_interface_flag');
             END IF;
          END IF;
       END IF;
    END LOOP;
 ELSE
   UPDATE wsh_delivery_assignments wda
       SET wda.delivery_id               = NULL
         , wda.parent_delivery_detail_id = NULL
         , wda.last_updated_by           = -1
         , wda.last_update_date          = SYSDATE
     WHERE EXISTS ( SELECT 1
                      FROM wsh_delivery_details wdd
                         , oe_order_lines_all oel
                     WHERE wdd.source_line_id   = oel.line_id
                       AND wdd.delivery_detail_id = wda.delivery_detail_id
                       AND wdd.source_code      = 'OE'
                       AND oel.cancelled_flag   = 'Y'
                       AND oel.line_id          = p_line_id
                       AND wdd.released_status  <> 'D');


  END IF;

  /* Check if Org is an OPM or Inventory Org */
  l_opm_enabled := INV_GMI_RSV_BRANCH.PROCESS_BRANCH(p_organization_id => l_ship_from_org_id);

  if not l_opm_enabled then
    /*
      Inventory Org
      Updating Move Order lines for Released To Warehouse details as 'Cancelled by Source' */
     update mtl_txn_request_lines
     set    line_status = 9
     where  line_id in ( select move_order_line_id
                         from   wsh_delivery_details
                         where  source_line_id = p_line_id
                         and    released_status = 'S'
                         and    source_code = 'OE' );

     /* Removing Serial Number(s) and Unmarking them */
     for rec in wdd loop

         if rec.serial_number is not null then
            update mtl_serial_numbers
            set    group_mark_id = null,
                   line_mark_id = null,
                   lot_line_mark_id = null
            where  inventory_item_id = rec.inventory_item_id
            and    serial_number  between rec.serial_number and NVL(rec.to_serial_number, rec.serial_number);
         elsif rec.transaction_temp_id is not null then

            for msnt_rec in msnt(rec.transaction_temp_id) loop
                update mtl_serial_numbers
                set    group_mark_id = null,
                       line_mark_id = null,
                       lot_line_mark_id = null
                where  inventory_item_id = rec.inventory_item_id
                and    serial_number  between msnt_rec.fm_serial_number and NVL(msnt_rec.to_serial_number, msnt_rec.fm_serial_number);
            end loop;
            delete from mtl_serial_numbers_temp
            where  transaction_temp_id = rec.transaction_temp_id;
            begin

              l_cursor := dbms_sql.open_cursor;
              l_stmt   := 'select fm_serial_number, to_serial_number '||
                          'from   wsh_serial_numbers '||
                          'where  delivery_detail_id = :delivery_detail_id ';
              dbms_sql.parse(l_cursor, l_stmt, dbms_sql.v7);
              dbms_sql.define_column(l_cursor, 1, l_fm_serial, 1);
              dbms_sql.define_column(l_cursor, 2, l_to_serial, 1);
              dbms_sql.bind_variable(l_cursor, ':delivery_detail_id', rec.delivery_detail_id);
              l_ignore := dbms_sql.execute(l_cursor);
              loop
                if dbms_sql.fetch_rows(l_cursor) > 0 then
                   dbms_sql.column_value(l_cursor, 1, l_fm_serial);
                   dbms_sql.column_value(l_cursor, 2, l_to_serial);
                   l_up_cursor := dbms_sql.open_cursor;
                   l_up_stmt   := 'update mtl_serial_numbers msn '||
                                  'set    msn.group_mark_id    = null,  '||
                                  '       msn.line_mark_id     = null,  '||
                                  '       msn.lot_line_mark_id = null   '||
                                  'where  msn.inventory_item_id = :inventory_item_id '||
                                  'and    msn.serial_number between :fm_serial and :to_serial ';
                   dbms_sql.parse(l_up_cursor, l_up_stmt, dbms_sql.v7);
                   dbms_sql.bind_variable(l_up_cursor, ':inventory_item_id', rec.inventory_item_id);
                   dbms_sql.bind_variable(l_up_cursor, ':fm_serial', l_fm_serial);
                   dbms_sql.bind_variable(l_up_cursor, ':to_serial', NVL(l_to_serial, l_fm_serial));
                   l_ignore := dbms_sql.execute(l_up_cursor);
                   dbms_sql.close_cursor(l_up_cursor);
                else
                  exit;
                end if;
              end loop;
              dbms_sql.close_cursor(l_cursor);
              l_cursor := dbms_sql.open_cursor;
              l_stmt   := 'delete from wsh_serial_numbers '||
                          'where delivery_detail_id = :delivery_detail_id ';
              dbms_sql.parse(l_cursor, l_stmt, dbms_sql.v7);
              dbms_sql.bind_variable(l_cursor, ':delivery_detail_id', rec.delivery_detail_id);
              l_ignore := dbms_sql.execute(l_cursor);
              dbms_sql.close_cursor(l_cursor);
            exception
              when others then
                if dbms_sql.is_open(l_up_cursor) then
                   dbms_sql.close_cursor(l_up_cursor);
                end if;
                if dbms_sql.is_open(l_cursor) then
                   dbms_sql.close_cursor(l_cursor);
                end if;

            end;

         end if;

     end loop;

  else

     /* OPM Org  */
     update ic_txn_request_lines
     set    line_status = 9
     where  line_id in ( select move_order_line_id
                         from   wsh_delivery_details
                         where  source_line_id  = p_line_id
                         and    released_status = 'S'
                         and    source_code     = 'OE' );

     update ic_tran_pnd
     set    delete_mark   = 1
     where  line_id       = p_line_id
     and    doc_type      = 'OMSO'
     and    trans_qty     < 0
     and    delete_mark   = 0
     and    completed_ind = 0;

  end if;

  update wsh_delivery_details
  set    released_status         = 'D'
  ,      src_requested_quantity  = 0
  ,      src_requested_quantity2 = decode(src_requested_quantity2,NULL,NULL,0)
  ,      requested_quantity      = 0
  ,      requested_quantity2     = decode(requested_quantity2,NULL,NULL,0)
  ,      shipped_quantity        = 0
  ,      shipped_quantity2       = decode(shipped_quantity2,NULL,NULL,0)
  ,      picked_quantity         = 0
  ,      picked_quantity2        = decode(picked_quantity2,NULL,NULL,0)
  ,      cycle_count_quantity    = 0
  ,      cycle_count_quantity2   = decode(src_requested_quantity2,NULL,NULL,0)
  ,      cancelled_quantity      = decode(requested_quantity,0,cancelled_quantity,requested_quantity)
  ,      cancelled_quantity2     = decode(requested_quantity2,NULL,NULL,0,cancelled_quantity2,requested_quantity2)
  ,      subinventory            = null
  ,      locator_id              = null
  ,      lot_number              = null
  ,      serial_number           = null
  ,      to_serial_number        = null
  ,      transaction_temp_id     = null
  ,      revision                = null
  ,      ship_set_id             = null
  ,      inv_interfaced_flag     = 'X'
  ,      oe_interfaced_flag      = 'X'
  ,      last_updated_by         = -1
  ,      last_update_date        = sysdate
  where source_line_id   = p_line_id
  and   source_code      = 'OE'
  and   released_status  <> 'D'
  and   exists
       (select 'x'
        from   oe_order_lines_all oel
        where  source_line_id       = oel.line_id
        and    oel.cancelled_flag   = 'Y');

  Exception
    when Line_Cannot_Be_Updated then
      rollback;
      x_return_status := 'E';
      x_error := sqlerrm;
      fnd_file.put_line(fnd_file.LOG,'This script cannot cancel this Order Line, please contact Oracle Support');
    when others then
      rollback;
      x_return_status := 'E';
      x_error := sqlerrm;
      fnd_file.put_line(fnd_file.LOG,substr(sqlerrm, 1, 240));
 END cancel_order_line_datafix;

  --------------------------------------------------------------------
  --  name:             cancel_order_line
  --  create by:        Rimpi
  --  Revision:         1.0
  --  creation date:    30-Mar-2017
  --------------------------------------------------------------------
  --  purpose :         CHG0040391: Called from Procedure: main to cancel the Sales Order-LINES
  ----------------------------------------------------------------------
  --  ver   date                 name            desc
  --  1.0   30-Mar-2017          Rimpi           CHG0040391: initial build
  -----------------------------------------------------------------------
  PROCEDURE cancel_order_line ( p_header_id IN NUMBER,
                                p_line_id   IN NUMBER,
                                p_org_id    IN NUMBER,
                                x_return_status OUT VARCHAR2,
                                x_error         OUT VARCHAR2
                               )
  IS

    l_msg_count          NUMBER;
    l_cancel_reason_code VARCHAR2(20) := 'Not provided';
    -- IN Variables --
    l_header_rec                   oe_order_pub.header_rec_type;
    l_line_tbl                     oe_order_pub.line_tbl_type;
    l_action_request_tbl           oe_order_pub.request_tbl_type;
    l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;

    -- OUT Variables --
    l_header_rec_out               oe_order_pub.header_rec_type;
    l_header_val_rec_out           oe_order_pub.header_val_rec_type;
    l_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
    l_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
    l_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
    l_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
    l_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
    l_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
    l_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
    l_line_tbl_out                 oe_order_pub.line_tbl_type;
    l_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
    l_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
    l_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
    l_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
    l_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
    l_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
    l_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
    l_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
    l_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
    l_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
    l_action_request_tbl_out       oe_order_pub.request_tbl_type;

  BEGIN
   x_return_status := 'S';
   fnd_file.put_line(fnd_file.LOG,'');
   fnd_file.put_line(fnd_file.LOG,' START XXOM_UTIL_PKG.Cancel_order_line Procedure');

    If p_header_id is not null and p_line_id is not null Then
      l_action_request_tbl (1) := oe_order_pub.g_miss_request_rec;
      -- Cancel a Line Record --
      l_line_tbl (1)                  := oe_order_pub.g_miss_line_rec;
      l_line_tbl (1).operation        := OE_GLOBALS.G_OPR_UPDATE;
      l_line_tbl (1).header_id        := p_header_id ;
      l_line_tbl (1).line_id          := p_line_id;
      l_line_tbl (1).ordered_quantity := 0;
      l_line_tbl (1).cancelled_flag   := 'Y';
      l_line_tbl (1).change_reason    := l_cancel_reason_code;

    -- Calling the API to cancel a line from an Existing Order --

        OE_ORDER_PUB.PROCESS_ORDER (
                       p_api_version_number           => 1.0
                      , p_org_id                      => p_org_id
                      , p_header_rec                  => l_header_rec
                      , p_line_tbl                    => l_line_tbl
                      , p_action_request_tbl          => l_action_request_tbl
                      , p_line_adj_tbl                => l_line_adj_tbl
                      , p_init_msg_list               => fnd_api.g_false
                      , p_return_values               => fnd_api.g_false
                      , p_action_commit               => fnd_api.g_false
                      -- OUT variables
                      , x_header_rec                  => l_header_rec_out
                      , x_header_val_rec              => l_header_val_rec_out
                      , x_header_adj_tbl              => l_header_adj_tbl_out
                      , x_header_adj_val_tbl          => l_header_adj_val_tbl_out
                      , x_header_price_att_tbl        => l_header_price_att_tbl_out
                      , x_header_adj_att_tbl          => l_header_adj_att_tbl_out
                      , x_header_adj_assoc_tbl        => l_header_adj_assoc_tbl_out
                      , x_header_scredit_tbl          => l_header_scredit_tbl_out
                      , x_header_scredit_val_tbl      => l_header_scredit_val_tbl_out
                      , x_line_tbl                    => l_line_tbl_out
                      , x_line_val_tbl                => l_line_val_tbl_out
                      , x_line_adj_tbl                => l_line_adj_tbl_out
                      , x_line_adj_val_tbl            => l_line_adj_val_tbl_out
                      , x_line_price_att_tbl          => l_line_price_att_tbl_out
                      , x_line_adj_att_tbl            => l_line_adj_att_tbl_out
                      , x_line_adj_assoc_tbl          => l_line_adj_assoc_tbl_out
                      , x_line_scredit_tbl            => l_line_scredit_tbl_out
                      , x_line_scredit_val_tbl        => l_line_scredit_val_tbl_out
                      , x_lot_serial_tbl              => l_lot_serial_tbl_out
                      , x_lot_serial_val_tbl          => l_lot_serial_val_tbl_out
                      , x_action_request_tbl          => l_action_request_tbl_out
                      , x_return_status               => x_return_status
                      , x_msg_count                   => l_msg_count
                      , x_msg_data                    => x_error
                      );

            fnd_file.put_line(fnd_file.LOG,'Completion of Line API :'||x_return_status/*
                                                       ||', ERROR :'||substr(x_error,1,100)*/);

        IF (x_return_status = fnd_api.g_ret_sts_success)
          OR (get_header_or_line_status(p_line_id , 'L') = 'CANCELLED')
        THEN
          fnd_file.put_line(fnd_file.log,'Line Cancelation in Existing Order is Success ');
          x_return_status := fnd_api.g_ret_sts_success;
        ELSE
            fnd_file.put_line(fnd_file.LOG,'Line Cancelation in Existing Order failed.');
            FOR i IN 1 .. l_msg_count
            LOOP
              x_error := x_error ||'.('||i||')' ||oe_msg_pub.get( p_msg_index => i, p_encoded => 'F');
            END LOOP;
            --fnd_file.put_line(fnd_file.LOG,'Error :'||x_error);
            x_return_status := fnd_api.g_ret_sts_error;
        End If;

    END IF;


    -- Try Line Cancellation By Datafix
    If p_header_id is not null
      and p_line_id is not null
      and x_return_status != fnd_api.g_ret_sts_success
    Then
       fnd_file.put_line(fnd_file.LOG,'Calling Cancel Order Line Datafix');
       cancel_order_line_datafix ( p_line_id       => p_line_id,
                                   p_header_id     => p_header_id,
                                   x_return_status => x_return_status,
                                   x_error         => x_error
                                  );
       Commit;
       IF (x_return_status = fnd_api.g_ret_sts_success) OR
          (get_header_or_line_status(p_line_id , 'L') = 'CANCELLED')
       THEN
          fnd_file.put_line(fnd_file.log,'Line Cancelation in Existing Order is Success ');
          x_return_status := fnd_api.g_ret_sts_success;
       ELSE
         fnd_file.put_line(fnd_file.LOG,'Line Cancelation in Existing Order failed.');
         fnd_file.put_line(fnd_file.LOG,'Error :'||x_error);
         x_return_status := fnd_api.g_ret_sts_error;
       END IF;
    End If;

  Exception
  When Others Then
     x_return_status := 'E';
     x_error := sqlerrm;
     fnd_file.put_line(fnd_file.LOG,'Order Line Cancellation Failed with Error :'||x_error);
  END cancel_order_line;
  --------------------------------------------------------------------
  --  name:             main
  --  create by:        Rimpi
  --  Revision:         1.0
  --  creation date:    30-Mar-2017
  --------------------------------------------------------------------
  --  purpose :         CHG0040391: Called from Conc prog: XXSSYS Order/Line Cancellation Program to cancel the Sales Order
  ----------------------------------------------------------------------
  --  ver   date                 name            desc
  --  1.0   30-Mar-2017    Rimpi            CHG0040391: initial build
  --  1.1   30-Aug-2017    Lingaraj         INC0100407 - Line Cancellation Not working When Split Line
  -----------------------------------------------------------------------
 PROCEDURE cancel_order( errbuf OUT VARCHAR2,
                         retcode OUT VARCHAR2,
                         p_header_id IN NUMBER,
                         p_cancel_header_line IN VARCHAR2,
                         p_dummy              IN VARCHAR2, -- not for use
                         p_line_id            IN NUMBER ,
                         p_debug              IN VARCHAR2
                         )
 IS
  CURSOR c_get_oe_lines IS
  SELECT line_id , (line_number||'.'||shipment_number) line_num
  FROM oe_order_lines_all
  WHERE header_id = p_header_id
  AND flow_status_code not in( 'CLOSED' , 'CANCELLED');

  l_line_count   NUMBER;
  l_line_Record  OE_ORDER_LINES_ALL%ROWTYPE;
  l_Order_Number NUMBER;
  l_org_id       NUMBER;
  l_order_status VARCHAR2(50);
  l_line_status  VARCHAR2(50);
  l_line_num     VARCHAR2(10);
  l_ret_status   VARCHAR2(1) := fnd_api.g_ret_sts_success;
  l_error        VARCHAR2(4000);

 BEGIN
   retcode := 0;
   fnd_file.put_line(fnd_file.LOG,'***************************************** ');
   fnd_file.put_line(fnd_file.LOG,'Start of MAIN Procedure XXOM_UTIL_PKG.cancel_order');
   fnd_file.put_line(fnd_file.LOG,'p_header_id          :'||p_header_id);
   fnd_file.put_line(fnd_file.LOG,'p_cancel_header_line(Cancel Order or Line) :'||p_cancel_header_line);
   fnd_file.put_line(fnd_file.LOG,'p_line_id            :'||p_line_id);
   fnd_file.put_line(fnd_file.LOG,'p_debug(oe_debug_pub.SetDebugLevel(5)): '||p_debug);
   fnd_file.put_line(fnd_file.LOG,'***************************************** ');

   MO_GLOBAL.INIT('ONT');
   oe_msg_pub.initialize;
   oe_debug_pub.initialize;
   If p_debug = 'Y' Then
     oe_debug_pub.SetDebugLevel(5);
   End If;

   --Get Order Number
   Select Order_Number , flow_status_code,org_id
   Into l_Order_Number ,l_order_status, l_org_id
    from Oe_Order_Headers_All
   Where header_id = p_header_id ;
   fnd_file.put_line(fnd_file.LOG,'Order Number : '||l_Order_Number);
   fnd_file.put_line(fnd_file.LOG,'Order Status : '||l_order_status);

   --Get Line Details
   If p_line_id is Not Null Then
    Begin
     SELECT *
      INTO l_line_Record
      FROM oe_order_lines_all ol
      WHERE
          ol.header_id  = p_header_id
      AND ol.line_id    = p_line_id;

      fnd_file.put_line(fnd_file.LOG,'Line Number :'||l_line_Record.line_number||'.'||l_line_Record.shipment_number);
      fnd_file.put_line(fnd_file.LOG,'Line Status :'||l_line_Record.Flow_Status_Code);
    Exception
    When NO_DATA_FOUND Then
       fnd_file.put_line(fnd_file.LOG,'For Order Number : '||l_Order_Number
                         ||' , Line Id :'||p_line_id ||'  Not Found.');
       retcode := 2;
       Return;
    End;
   End If;

  --Cancel Full Sales Order
  IF p_header_id  IS NOT NULL AND p_cancel_header_line = 'Header' Then

   If l_order_status != 'ENTERED' Then

     SELECT COUNT(*)
      INTO l_line_count
      FROM oe_order_lines_all
      WHERE header_id      = p_header_id
      AND flow_status_code = 'CLOSED';

     If   l_line_count > 0 Then
        fnd_file.put_line(fnd_file.log,' No Of Lines Found Closed in the Order :'||l_line_count);
        fnd_file.put_line(fnd_file.log,' Cannnot Cancel Full Order. Because Some of lines found Sucessfully Processed/Interfaced.');
         retcode := 2;
         errbuf  := 'Order Cannot be Cancelled';
         Return;
     End If;

     SELECT COUNT(*)
      INTO l_line_count
      FROM oe_order_lines_all
      WHERE header_id = p_header_id
      AND flow_status_code not in ('CLOSED', 'CANCELLED');

     fnd_file.put_line(fnd_file.LOG,' No Of Lines Found in the Order Which is not Closed :'||l_line_count);

     IF   l_line_count > 0 THEN
      -- Cancel Each Line of The Order
      FOR i IN c_get_oe_lines LOOP
          Select flow_status_code , (line_number||'.'||shipment_number)
          into l_line_status  , l_line_num
          From oe_order_lines_all where line_id = i.line_id;

          fnd_file.put_line(fnd_file.LOG,'+------------------------------------------------+');
          fnd_file.put_line(fnd_file.LOG,'Cancel Line Number :'||l_line_num);

          cancel_order_line ( p_line_id       => i.line_id,
                              p_header_id     => p_header_id,
                              p_org_id        => l_org_id,
                              x_return_status => l_ret_status,
                              x_error         => l_error
                            );
         fnd_file.put_line(fnd_file.LOG,'Line Cancellation Return Status :'||l_ret_status);
         Commit;
         If l_ret_status != fnd_api.g_ret_sts_success Then
            fnd_file.put_line(fnd_file.LOG,'Line Number :'||l_line_num||' having status :'|| l_line_status
                                            ||' Failed to Cancel, With Error :'||l_error);
         Else
             fnd_file.put_line(fnd_file.log,'Line Number :'||i.line_num ||' Cancelled Sucessfully.' );
         End If;
         fnd_file.put_line(fnd_file.LOG,'+------------------------------------------------+');
      END LOOP;
    END IF;

   End If;


    l_ret_status := '';
    l_error      := '';
    If get_header_or_line_status(p_header_id , 'H') not in ('CANCELLED', 'CLOSED') Then
      -- Cancel the Order Header
      cancel_order_header(p_header_id     => p_header_id,
                          p_org_id        => l_org_id,
                          x_return_status => l_ret_status,
                          x_error         => l_error
                          );
      fnd_file.put_line(fnd_file.log,'Order Cancellation Status :'||l_ret_status);
      If  (l_ret_status = fnd_api.g_ret_sts_success)
       Or (get_header_or_line_status(p_header_id , 'H') IN ('CANCELLED', 'CLOSED'))
      Then
         fnd_file.put_line(fnd_file.log,'Order Number :'|| l_Order_Number
                                      ||' Cancelled successfully.');
         Commit;
      Else
         fnd_file.put_line(fnd_file.log,'Order Number :'|| l_Order_Number
                                      ||' Cancellation Failed.'||l_error);
         Rollback;
         retcode := 1;
         errbuf  := 'Order Number :'|| l_Order_Number ||' Cancellation Failed.';
      End If;
      Return;
    End If;
  Else
    fnd_file.put_line(fnd_file.log,'Sales Order is already Closed or Cancelled');
  END IF;

  l_line_count := 0;

  --Cancel Sales Order Line
  fnd_file.put_line(fnd_file.log,'Before Cancel Order Line');
  IF   p_header_id  IS NOT NULL
   AND p_line_id    IS NOT NULL
   And p_cancel_header_line = 'Lines'
  THEN
    cancel_order_line ( p_header_id => p_header_id,
                        p_line_id   => p_line_id,
                        p_org_id        => l_org_id,
                        x_return_status => l_ret_status,
                        x_error         => l_error
                       );
     fnd_file.put_line(fnd_file.log,'cancel_order_line Return STATUS :'||l_ret_status);

    If  l_ret_status = fnd_api.g_ret_sts_success Then
       fnd_file.put_line(fnd_file.log,'Order Line Cancelled successfully.');
       Commit;
    Else
      retcode := 1;
      errbuf  := 'Order Line Cancellation Failed';
      fnd_file.put_line(fnd_file.log,'Order Line Cancellation Failed, Error :'||l_error);
    End If;
  END IF;

  Exception
  When Others Then
    retcode := 2;
    errbuf  := sqlerrm;
    fnd_file.put_line(fnd_file.log,'Exception occurred in XXOM_UTIL_PKG.cancel_order , With Error :'||
                                                           errbuf );
  END cancel_order;
  
  --------------------------------------------------------------------
  --  name:             close_order
  --  create by:        Diptasurjya
  --  Revision:         1.0
  --  creation date:    10-Nov-2017
  --------------------------------------------------------------------
  --  purpose :         CHG0041821: Script to close order header workflow where all lines
  --                    are in closed or cancelled state
  ----------------------------------------------------------------------
  --  ver   date           name             desc
  --  1.0   10-Nov-2017    Diptasurjya      CHG0041821: initial build
  -----------------------------------------------------------------------
  PROCEDURE close_order( errbuf OUT VARCHAR2,
                         retcode OUT VARCHAR2,
                         p_header_id IN NUMBER,
                         p_report_only     IN VARCHAR2,
                         p_debug IN varchar2 default 'N'
                         )
  IS
    l_line_id NUMBER;
    l_result VARCHAR2(30);
    l_file_name VARCHAR2(500);
    l_workflow_status varchar2(20);

    CURSOR lines IS
    select hou.name operating_unit,
           oh.order_number,
           oh.flow_status_code order_status,
           ott.name order_type,
           TO_CHAR(ol.line_number)|| 
           DECODE(ol.shipment_number, NULL, NULL, '.'|| TO_CHAR(ol.shipment_number)) || 
           DECODE(ol.option_number, NULL, NULL, '.' || TO_CHAR(ol.option_number)) || 
           DECODE(ol.component_number, NULL, NULL, DECODE(ol.option_number, NULL, '.',NULL) || '.' ||TO_CHAR(ol.component_number)) || 
           DECODE(ol.service_number,NULL,NULL, DECODE(ol.component_number, NULL, '.' , NULL) || DECODE(ol.option_number, NULL, '.', NULL ) || '.' || TO_CHAR(ol.service_number)) line_number,
           ol.flow_status_code line_status,
           'ACTIVE' line_workflow_status,
           ol.line_id
      from oe_order_lines_all ol,
           oe_order_headers_all oh,
           oe_transaction_types_tl ott,
           hr_operating_units hou
     where ol.flow_status_code     IN( 'AWAITING_SHIPPING' ,'CANCELLED')
       and ol.ordered_quantity     = 0
       and ol.open_flag            = 'Y'
       and ol.cancelled_quantity   > 0
       and ol.cancelled_flag       = 'Y'
       and oh.header_id = nvl(p_header_id,oh.header_id)
       and ol.header_id = oh.header_id
       and oh.order_type_id = ott.transaction_type_id
       and ott.language = 'US'
       and hou.organization_id = oh.org_id
       and exists (  select 1
                       from wf_items wi
                      where wi.item_type = 'OEOL'
                        and wi.item_key = to_char(ol.line_id)
                        and wi.end_date is null) ;


  BEGIN
    retcode := 0;
    fnd_file.put_line(fnd_file.LOG,'***************************************** ');
    fnd_file.put_line(fnd_file.LOG,'Start of Procedure XXOM_UTIL_PKG.close_order');
    fnd_file.put_line(fnd_file.LOG,'p_header_id          :'||p_header_id);
    fnd_file.put_line(fnd_file.LOG,'p_report_only        :'||p_report_only);
    fnd_file.put_line(fnd_file.LOG,'p_debug(oe_debug_pub.SetDebugLevel(5)): '||p_debug);
    fnd_file.put_line(fnd_file.LOG,'***************************************** ');
 
    MO_GLOBAL.INIT('ONT');
    oe_msg_pub.initialize;
    oe_debug_pub.initialize;
    If p_debug = 'Y' Then
      Oe_debug_pub.debug_ON;
      oe_debug_pub.SetDebugLevel(5);
      
      l_file_name := Oe_debug_pub.set_debug_mode('FILE');
      fnd_file.put_line(fnd_file.LOG,'OE Debug file: '||l_file_name);
    End If;

   
   
    Oe_debug_pub.ADD ('Checking Line information');
   
    fnd_file.put_line(fnd_file.OUTPUT,'***************************************** ');
    fnd_file.put_line(fnd_file.OUTPUT,'*********Close Orders Report************ ');
    fnd_file.put_line(fnd_file.OUTPUT,'***************************************** ');
    fnd_file.put_line(fnd_file.OUTPUT, RPAD('-',20,'-')||
                         RPAD('-',15,'-')||
                         RPAD('-',20,'-')||
                         RPAD('-',30,'-')||
                         RPAD('-',15,'-')||
                         RPAD('-',20,'-')||
                         RPAD('-',20,'-')||
                         RPAD('-',16,'-'));
    fnd_file.put_line(fnd_file.OUTPUT, RPAD('Operating Unit',20,' ')||
                         RPAD('Order Number',15,' ')||
                         RPAD('Order Status',20,' ')||
                         RPAD('Order Type',30,' ')||
                         RPAD('Line Number',15,' ')||
                         RPAD('Line Status',20,' ')||
                         RPAD('Workflow Status',20,' ')||
                         RPAD('Line ID',16,' '));
    fnd_file.put_line(fnd_file.OUTPUT, RPAD('-',20,'-')||
                         RPAD('-',15,'-')||
                         RPAD('-',20,'-')||
                         RPAD('-',30,'-')||
                         RPAD('-',15,'-')||
                         RPAD('-',20,'-')||
                         RPAD('-',20,'-')||
                         RPAD('-',16,'-')); 
   
   
    FOR c IN lines LOOP
      l_workflow_status := null;
      l_line_id := c.line_id;
     
      if nvl(p_report_only,'Y') = 'N' then
        DELETE FROM oe_line_sets WHERE line_id = l_line_id;

        Oe_debug_pub.ADD('Closing line '||l_line_id );

        BEGIN
          OE_Standard_WF.OEOL_SELECTOR
              (p_itemtype => 'OEOL'
              ,p_itemkey => TO_CHAR(l_line_id)
              ,p_actid => 12345
              ,p_funcmode => 'SET_CTX'
              ,p_result => l_result);

          Oe_debug_pub.ADD('Result: '||l_result);

          wf_engine.handleError('OEOL', to_char(l_line_id), 'CLOSE_LINE', 'RETRY', 'NULL');
         
          l_workflow_status := 'CLOSED SUCCESSFULLY';
        EXCEPTION
        WHEN Others THEN
          Oe_debug_pub.ADD('Error inside loop: '|| SQLERRM);
          raise;
        END;
      end if;
    
      fnd_file.put_line(fnd_file.OUTPUT, RPAD(c.operating_unit,20,' ')||
                      RPAD(to_char(c.order_number),15,' ')||
                      RPAD(c.order_status,20,' ')||
                      RPAD(c.order_type,30,' ')||
                      RPAD(c.line_number,15,' ')||
                      RPAD(c.line_status,20,' ')||
                      RPAD(nvl(l_workflow_status,c.line_workflow_status),20,' ')||
                      RPAD(to_char(c.line_id),16,' '));
     
    END LOOP;
   
    fnd_file.put_line(fnd_file.LOG,'***************************************** ');
   
    Oe_debug_pub.debug_OFF;
  Exception
  When Others Then
    retcode := 2;
    errbuf  := sqlerrm;
    
    rollback;
    fnd_file.put_line(fnd_file.log,'Exception occurred in XXOM_UTIL_PKG.close_order , With Error :'||
                                               errbuf );
  END close_order;

END XXOM_UTIL_PKG;
/
