create or replace package body xxobjt_reprocess_contracts_pkg is

--------------------------------------------------------------------
--  name:            XXOBJT_REPROCESS_CONTRACTS_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.3
--  creation date:   08/01/2012 17:01:32
--------------------------------------------------------------------
--  purpose :        CUST475 - Reprocess Contracts
--                   During the SO shipment in Objet, the installation date of
--                   the printer is not known, therefore impossible to predict
--                   the start date of the second year contract that customer
--                   purchases in initial sales order together with the printer.
--
--                   Required to perform several system changes in order to enable
--                   creation of second year contract that will be aligned with
--                   installation date of the printer and its warranty period.
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  08/01/2012  Dalit A. Raviv    initial build
--  1.1  29/04/2012  Roman V.          add contracts to the main select of cursor so_pop_c
--  1.2  28/05/2012  Adi S.            change main cursor to support warranty contracts created manually by users
--  1.3  11/03/2013  Dalit A. Raviv    Handle closed warrenty, Handle so with several contracts
--------------------------------------------------------------------
  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/10/2011 1:45:30 PM
  --------------------------------------------------------------------
  --  purpose :        CUST475 - Reprocess Contracts
  --
  --                   Procedure will call from concurrent program and will run once a day.
  --                   1) Update service item in sales order line.
  --                      For service item will be updated Service_start_date and
  --                      Service_end_date in oe_order_lines_all table
  --                   2) Update oks_reprocessing table – change the success_flag = ‘N’
  --                   3)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/01/2012  Dalit A. Raviv    initial build
  --  1.1  29/04/2012  Roman V.          add contracts to the main select of cursor so_pop_c
  --  1.2  28/05/2012  Adi S.            change main cursor to support warranty contracts created manually by users
  --  1.3  11/03/2013  Dalit A. Raviv    Handle closed warrenty, Handle so with several contracts
  --------------------------------------------------------------------
  procedure main(errbuf         out varchar2,
                 retcode        out number,
                 p_so_number    in  number,
                 p_so_line_id   in  number,
                 p_warr_to_cont in  varchar2) is

    cursor so_pop_c (p_so_number in number) IS

    -- 1.2 28/05/2012 Adi S.
/*      select oola.org_id,
             ooha.order_number,
             okr.order_line_id,              --service_line_id
             oola.service_reference_line_id, --ref_line_id
             cii.instance_id,                --instance_id
             (trunc(l.end_date) + 1) service_start_date_new,
             case
               when oola.service_period = 'MTH' then
                add_months(trunc(l.end_date), oola.service_duration)
               when oola.service_period = 'YR' then
                add_months(trunc(l.end_date), oola.service_duration * 12)
             end service_end_date_new
      from   oks_reprocessing          okr,
             csi_item_instances        cii,
             csi_instance_statuses     cis,
             oe_order_lines_all        oola,
             oe_order_headers_all      ooha,
             okc_k_headers_all_b       h,
             okc_k_lines_b             l,
             okc_k_items               oki -- 1.1 29/04/2012 Roman V.
      where  okr.success_flag          = 'S'
      and    okr.contract_id           is null
      and    ooha.header_id            = oola.header_id
      and    cii.last_oe_order_line_id = oola.service_reference_line_id
      and    oola.line_id              = okr.order_line_id
      and    cii.instance_status_id    = cis.instance_status_id
      and    cis.terminated_flag       = 'N'
      and    cii.serial_number         is not null
      and    cii.manually_created_flag is null
      and    h.id                      = l.dnz_chr_id
      and    l.upg_orig_system_ref_id  = oola.service_reference_line_id --ref_line_id
      and    h.scs_code                = 'WARRANTY'
      and    cii.install_date          > okr.creation_date
      and    ooha.order_number         = nvl(p_so_number,ooha.order_number)
      -- 1.1 29/04/2012 Roman V.
      and    oki.cle_id                = l.id
      and    oki.object1_id1           = cii.instance_id
      --
      order by oola.org_id;*/

    select
    -- WARRANTY related to SO --
           oola.org_id,
           ooha.order_number,
           okr.order_line_id,              -- service_line_id
           oola.service_reference_line_id, -- ref_line_id
           cii.instance_id,                -- instance_id
           (trunc(l.end_date) + 1) service_start_date_new,
           case
             when oola.service_period = 'MTH' then
              add_months(trunc(l.end_date), oola.service_duration)
             when oola.service_period = 'YR' then
              add_months(trunc(l.end_date), oola.service_duration * 12)
           end service_end_date_new
    from   oks_reprocessing      okr,
           csi_item_instances    cii,
           csi_instance_statuses cis,
           oe_order_lines_all    oola,
           oe_order_headers_all  ooha,
           okc_k_headers_all_b   h,
           okc_k_lines_b         l,
           okc_k_items           oki         -- 1.1 29/04/2012 Roman V.
    where  okr.success_flag = 'S'
    and    okr.contract_id is null
    and    ooha.header_id = oola.header_id
    and    cii.last_oe_order_line_id = oola.service_reference_line_id
    and    oola.line_id = okr.order_line_id
    and    cii.instance_status_id = cis.instance_status_id
    and    cis.terminated_flag = 'N'
    and    cii.serial_number is not null
    and    cii.manually_created_flag is null
    and    h.id = l.dnz_chr_id
    and    l.upg_orig_system_ref_id = oola.service_reference_line_id -- ref_line_id
    and    h.scs_code = 'WARRANTY'
    and    (l.sts_code = 'ACTIVE' or p_warr_to_cont = 'Y')  -- Dalit A. Raviv 11/03/2013
    and    cii.install_date > okr.creation_date
    --and    ooha.order_number = nvl(p_so_number, ooha.order_number)
    and    ooha.header_id    = nvl(p_so_number, ooha.header_id)
    and    oola.line_id      = nvl(p_so_line_id, oola.line_id )-- Dalit A. Raviv 11/03/2013
    --     1.1 29/04/2012 Roman V.
    and    oki.cle_id = l.id
    and    oki.object1_id1 = cii.instance_id
    union all
    select
    -- WARRANTY not related to SO, created manually --
           oola.org_id,
           ooha.order_number,
           okr.order_line_id,              -- service_line_id
           oola.service_reference_line_id, -- ref_line_id
           cii.instance_id,                -- instance_id
           (trunc(l.end_date) + 1) service_start_date_new,
           case
             when oola.service_period = 'MTH' then
              add_months(trunc(l.end_date), oola.service_duration)
             when oola.service_period = 'YR' then
              add_months(trunc(l.end_date), oola.service_duration * 12)
           end service_end_date_new
    from   oks_reprocessing      okr,
           csi_item_instances    cii,
           csi_instance_statuses cis,
           oe_order_lines_all    oola,
           oe_order_headers_all  ooha,
           okc_k_headers_all_b   h,
           okc_k_lines_b         l,
           okc_k_items           oki        -- 1.1 29/04/2012 Roman V.
    where  okr.success_flag = 'S'
    and    okr.contract_id is null
    and    ooha.header_id = oola.header_id
    and    cii.last_oe_order_line_id = oola.service_reference_line_id
    and    oola.line_id = okr.order_line_id
    and    cii.instance_status_id = cis.instance_status_id
    and    cis.terminated_flag = 'N'
    and    cii.serial_number is not null
    and    cii.manually_created_flag is null
    and    h.id = l.dnz_chr_id
    and    h.scs_code = 'WARRANTY'
    and    l.sts_code = 'ACTIVE' 
    and    cii.install_date > okr.creation_date
    --and    ooha.order_number = nvl(p_so_number, ooha.order_number)
    and    ooha.header_id    = nvl(p_so_number, ooha.header_id)
    and    oola.line_id      = nvl(p_so_line_id, oola.line_id )-- Dalit A. Raviv 11/03/2013
    --     1.1 29/04/2012 Roman V.
    and    oki.cle_id = l.id
    and    oki.object1_id1 = cii.instance_id
    order by 1,7 desc;

    -- End 1.2 28/05/2012 Adi S.

    l_header_rec                 OE_ORDER_PUB.Header_Rec_Type;
    l_line_tbl                   OE_ORDER_PUB.Line_Tbl_Type;
    l_line_tbl_out               OE_ORDER_PUB.Line_Tbl_Type;
    l_action_request_tbl         OE_ORDER_PUB.Request_Tbl_Type;
    l_action_request_tbl_out     OE_ORDER_PUB.Request_Tbl_Type;
    l_return_status              VARCHAR2(1000);
    l_msg_count                  NUMBER;
    l_msg_data                   VARCHAR2(1000);
    x_header_val_rec             OE_ORDER_PUB.Header_Val_Rec_Type;
    x_Header_Adj_tbl             OE_ORDER_PUB.Header_Adj_Tbl_Type;
    x_Header_Adj_val_tbl         OE_ORDER_PUB.Header_Adj_Val_Tbl_Type;
    x_Header_price_Att_tbl       OE_ORDER_PUB.Header_Price_Att_Tbl_Type;
    x_Header_Adj_Att_tbl         OE_ORDER_PUB.Header_Adj_Att_Tbl_Type;
    x_Header_Adj_Assoc_tbl       OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type;
    x_Header_Scredit_tbl         OE_ORDER_PUB.Header_Scredit_Tbl_Type;
    x_Header_Scredit_val_tbl     OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type;
    x_line_val_tbl               OE_ORDER_PUB.Line_Val_Tbl_Type;
    x_Line_Adj_tbl               OE_ORDER_PUB.Line_Adj_Tbl_Type;
    x_Line_Adj_val_tbl           OE_ORDER_PUB.Line_Adj_Val_Tbl_Type;
    x_Line_price_Att_tbl         OE_ORDER_PUB.Line_Price_Att_Tbl_Type;
    x_Line_Adj_Att_tbl           OE_ORDER_PUB.Line_Adj_Att_Tbl_Type;
    x_Line_Adj_Assoc_tbl         OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type;
    x_Line_Scredit_tbl           OE_ORDER_PUB.Line_Scredit_Tbl_Type;
    x_Line_Scredit_val_tbl       OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type;
    x_Lot_Serial_tbl             OE_ORDER_PUB.Lot_Serial_Tbl_Type;
    x_Lot_Serial_val_tbl         OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type;
    --x_debug_file                 VARCHAR2(100);
    l_line_tbl_index             NUMBER;
    l_msg_index_out              NUMBER(10);
    l_count                      number      := 0;
    --l_org_id                     number      := null;
    l_success                    varchar2(5);
    l_user_id                    number      := null;
    gen_exc                      exception;
  begin
    errbuf  := 'Success';
    retcode := 0;

    if p_warr_to_cont = 'Y' and p_so_number is null then
      raise gen_exc;
    end if;
    --
    begin
      select user_id
      into   l_user_id
      from   fnd_user
      where  user_name = 'SCHEDULER';
    exception
      when others then
        l_user_id := fnd_profile.VALUE('USER_ID');
    end;

    -- Running from Pl/Sql - remark when transfer to prod
    dbms_output.enable(1000000);
    --fnd_global.apps_initialize(1308,51137,514);
    --oe_debug_pub.initialize;
    --x_debug_file := oe_debug_pub.set_debug_Mode('FILE');
    --oe_debug_pub.SetDebugLevel(5); -- Use 5 for the most debuging output, I warn  you its a lot of data
    -- do not remark
    MO_GLOBAL.INIT('ONT');
    --
    for so_pop_r in so_pop_c (p_so_number) loop
      l_count   := l_count + 1;
      l_success := null;
      -- 1) use API to update SO line
      -- first time set_org_contex from the first line retrieve
      -- only if org_id change we need to change set_org_contex
      /*if l_count = 1 then
        MO_GLOBAL.SET_POLICY_CONTEXT('S', so_pop_r.org_id); -- Required for R12
        mo_global.set_org_context(p_org_id_char     => so_pop_r.org_id,
                                  p_sp_id_char      => NULL,
                                  p_appl_short_name => 'ONT');
        l_org_id :=  so_pop_r.org_id;
      else
        if l_org_id <>  so_pop_r.org_id then
          MO_GLOBAL.SET_POLICY_CONTEXT('S', so_pop_r.org_id); -- Required for R12
          mo_global.set_org_context(p_org_id_char     => so_pop_r.org_id,
                                    p_sp_id_char      => NULL,
                                    p_appl_short_name => 'ONT');
          l_org_id :=  so_pop_r.org_id;
        end if;
      end if;
      */
      dbms_output.put_line('START OF NEW DEBUG');
      --This is to UPDATE order line
      l_line_tbl_index := 1;
      -- Changed attributes
      l_line_tbl(l_line_tbl_index)                    := OE_ORDER_PUB.G_MISS_LINE_REC;
      l_line_tbl_out(l_line_tbl_index)                := OE_ORDER_PUB.G_MISS_LINE_REC;
      -- Primary key of the entity i.e. the order line
      l_line_tbl(l_line_tbl_index).line_id            := so_pop_r.order_line_id;
      l_line_tbl(l_line_tbl_index).service_start_date := so_pop_r.service_start_date_new;
      l_line_tbl(l_line_tbl_index).service_end_date   := so_pop_r.service_end_date_new;
      -- Indicates to process order that this is an update operation
      l_line_tbl(l_line_tbl_index).operation          := OE_GLOBALS.G_OPR_UPDATE;
      l_line_tbl(l_line_tbl_index).change_reason      := 'Not provided';

      -- p_validate_desc_flex =>
      OE_ORDER_PUB.process_order(p_api_version_number     => 1.0,
                                 --p_init_msg_list          => fnd_api.g_false,
                                 --p_return_values          => fnd_api.g_false,
                                 --p_action_commit          => fnd_api.g_false,
                                 x_return_status          => l_return_status,
                                 x_msg_count              => l_msg_count,
                                 x_msg_data               => l_msg_data,
                                 p_org_id                 => so_pop_r.org_id,---------------
                                 --p_header_rec             => l_header_rec,
                                 p_line_tbl               => l_line_tbl,
                                 p_action_request_tbl     => l_action_request_tbl,
                                 -- OUT PARAMETERS
                                 x_header_rec             => l_header_rec,
                                 x_header_val_rec         => x_header_val_rec,
                                 x_Header_Adj_tbl         => x_Header_Adj_tbl,
                                 x_Header_Adj_val_tbl     => x_Header_Adj_val_tbl,
                                 x_Header_price_Att_tbl   => x_Header_price_Att_tbl,
                                 x_Header_Adj_Att_tbl     => x_Header_Adj_Att_tbl,
                                 x_Header_Adj_Assoc_tbl   => x_Header_Adj_Assoc_tbl,
                                 x_Header_Scredit_tbl     => x_Header_Scredit_tbl,
                                 x_Header_Scredit_val_tbl => x_Header_Scredit_val_tbl,
                                 x_line_tbl               => l_line_tbl_out,
                                 x_line_val_tbl           => x_line_val_tbl,
                                 x_Line_Adj_tbl           => x_Line_Adj_tbl,
                                 x_Line_Adj_val_tbl       => x_Line_Adj_val_tbl,
                                 x_Line_price_Att_tbl     => x_Line_price_Att_tbl,
                                 x_Line_Adj_Att_tbl       => x_Line_Adj_Att_tbl,
                                 x_Line_Adj_Assoc_tbl     => x_Line_Adj_Assoc_tbl,
                                 x_Line_Scredit_tbl       => x_Line_Scredit_tbl,
                                 x_Line_Scredit_val_tbl   => x_Line_Scredit_val_tbl,
                                 x_Lot_Serial_tbl         => x_Lot_Serial_tbl,
                                 x_Lot_Serial_val_tbl     => x_Lot_Serial_val_tbl,
                                 x_action_request_tbl     => l_action_request_tbl_out
                                );
      dbms_output.put_line('OM Debug file: ' ||oe_debug_pub.G_DIR||'/'||oe_debug_pub.G_FILE);
      -- Check the return status
      fnd_file.put_line(fnd_file.log,'----------------------- ');
      fnd_file.put_line(fnd_file.log,'So Num: '||so_pop_r.order_number||' Line id: '||so_pop_r.order_line_id);
      if l_return_status = FND_API.G_RET_STS_SUCCESS then
        fnd_file.put_line(fnd_file.log,'Success');
        dbms_output.put_line('Success Update So Line, So Num: '||so_pop_r.order_number||' Line id: '||so_pop_r.order_line_id);
        commit;
        l_success := 'Y';
      else
        fnd_file.put_line(fnd_file.log,'Failed!!!');
        dbms_output.put_line('Failed Update So Line, So Num: '||so_pop_r.order_number||' Line id: '||so_pop_r.order_line_id);
        -- Retrieve messages
        for i in 1 .. l_msg_count loop
          oe_msg_pub.get( p_msg_index     => i,
                         p_encoded       => Fnd_Api.G_FALSE,
                         p_data          => l_msg_data,
                         p_msg_index_out => l_msg_index_out);
          dbms_output.put_line('message is: ' || l_msg_data);
          dbms_output.put_line('message index is: ' || l_msg_index_out);
          fnd_file.put_line(fnd_file.log, l_msg_index_out||' - Message is: ' || l_msg_data);
        end loop;
        rollback;
        errbuf    := 'Failed';
        retcode   := 1;
        l_success := 'N';
      end if;
      -- 2) update oks_reprocessing
      if l_success = 'Y' then
        begin
          Update oks_reprocessing      oksr
          set    oksr.success_flag     = 'N',
                 oksr.last_update_date = sysdate,
                 oksr.last_updated_by  = l_user_id
          where  oksr.order_line_id    = so_pop_r.order_line_id;
          commit;
        exception
          when others then
            fnd_file.put_line(fnd_file.log,'Failed!!! update oks_reprocessing');
            dbms_output.put_line('Failed!!! update oks_reprocessing');
        end;
      end if;
    end loop;
  exception
    when gen_exc then
      fnd_file.put_line(fnd_file.log,'When you choose Create Contract To none Active Warranty = Y then order number is mandatory.');
      dbms_output.put_line('When you choose Create Contract To none Active Warranty = Y then order number is mandatory.');
      errbuf  := 'When you choose Create Contract To none Active Warranty = Y then order number is mandatory.';
      retcode := 1;
    when others then
      fnd_file.put_line(fnd_file.log,'General Exception - '||substr(sqlerrm,1,240));
      dbms_output.put_line('General Exception - '||substr(sqlerrm,1,240));
      errbuf  := 'General Exception - '||substr(sqlerrm,1,240);
      retcode := 1;
  end main;
end XXOBJT_REPROCESS_CONTRACTS_PKG;
/
