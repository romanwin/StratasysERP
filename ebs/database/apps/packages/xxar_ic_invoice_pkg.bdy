create or replace package body xxar_ic_invoice_pkg is
  ----------  --------    --------------  -------------------------------------
  -- $Header: xxar_ic_invoices 120.0.0  4JUL2017  $
  ----------  --------    --------------  -------------------------------------
  -- Package: xxar_ic_invoices
  -- Created: Ofer Suad <Ofer.Suad@stratasys.com>
  -- Author : Ofer Suad <Ofer.Suad@stratasys.com>
  ----------  --------    --------------  -------------------------------------
  -- Perpose:
  ----------  --------    --------------  -------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -------------------------------------
  --     1.0  04/07/2017  Ofer Suad       CHG0040750  - Initial Build
  -----------------------------------------------------------------------------

  -- *************************************************************************************
  -- PROCEDURE : write_log_message
  --
  -- Purpose:
  --
  -- Revision History
  -- Version   Date            Performer          Comments
  --**************************************************************************************
  --   1.0     04/07/2017      Lingaraj S         CHG0040750  - Initial Build
  --
  -- *************************************************************************************
  PROCEDURE write_log_message(p_msg IN VARCHAR2) IS
  BEGIN
    --fnd_file.put_line(fnd_file.log, chr(10));
    IF fnd_global.conc_request_id = -1 THEN
      dbms_output.put_line(p_msg);
    ELSE
      fnd_file.put_line(fnd_file.log, p_msg);
    END IF;
  END write_log_message;

  -- *************************************************************************************
  -- PROCEDURE : write_Program_Log
  --
  -- Purpose:    Write the IC Records Log, in a Formated Manner
  --
  -- Revision History
  -- Version   Date            Performer          Comments
  --**************************************************************************************
  --   1.0     04/07/2017      Lingaraj S         CHG0040750  - Initial Build
  --
  -- *************************************************************************************
  PROCEDURE write_program_log(p_ic_inv_err_dtl_tbl IN IC_INV_ERR_DTL_TBL,
                              p_err_type           IN VARCHAR2,
                              p_msg                IN VARCHAR2 DEFAULT NULL) IS
  BEGIN

    For k in 1 .. p_ic_inv_err_dtl_tbl.COUNT Loop
      write_log_message('-------------------------------------------------------------------------');
      If p_err_type = 'AR' Then
        write_log_message('Item Code :' || p_ic_inv_err_dtl_tbl(k)
                          .ITEM_CODE);
        write_log_message('Item Desc :' || p_ic_inv_err_dtl_tbl(k)
                          .ITEM_DESC);
        write_log_message('INTERFACE_LINE_CONTEXT :' || p_ic_inv_err_dtl_tbl(k)
                          .INTERFACE_LINE_CONTEXT);
        write_log_message('INTERFACE_LINE_ATTRIBUTE1 :' || p_ic_inv_err_dtl_tbl(k)
                          .INTERFACE_LINE_ATTRIBUTE1);
        write_log_message('BATCH_SOURCE_NAME :' || p_ic_inv_err_dtl_tbl(k)
                          .BATCH_SOURCE_NAME);
        write_log_message('CURRENCY_CODE :' || p_ic_inv_err_dtl_tbl(k)
                          .CURRENCY_CODE);
        write_log_message('CONVERSION_TYPE :' || p_ic_inv_err_dtl_tbl(k)
                          .CONVERSION_TYPE);
        write_log_message('AMOUNT :' || p_ic_inv_err_dtl_tbl(k).AMOUNT);
        write_log_message('SALES_ORDER_SOURCE :' || p_ic_inv_err_dtl_tbl(k)
                          .SALES_ORDER_SOURCE);
        write_log_message('SALES_ORDER :' || p_ic_inv_err_dtl_tbl(k)
                          .SALES_ORDER);
        --write_log_message('RECORD_STATUS :'||p_ic_inv_err_dtl_tbl(k).RECORD_STATUS);
        write_log_message('First Invoice Created :' || p_ic_inv_err_dtl_tbl(k)
                          .FIRST_AR_INV_CREATED);
        write_log_message('Second Invoice Created :' || p_ic_inv_err_dtl_tbl(k)
                          .SECOND_AR_INV_CREATED);
        write_log_message('ERROR_MSG :' || p_ic_inv_err_dtl_tbl(k)
                          .ERROR_MSG);
      Else
        write_log_message('Org ID :' || p_ic_inv_err_dtl_tbl(k).org_id);
        write_log_message('customer_trx_id :' || p_ic_inv_err_dtl_tbl(k)
                          .customer_trx_id);
        write_log_message('INTERFACE_LINE_ATTRIBUTE4 :' || p_ic_inv_err_dtl_tbl(k)
                          .INTERFACE_LINE_ATTRIBUTE4);
        write_log_message('trx_number :' || p_ic_inv_err_dtl_tbl(k)
                          .trx_number);
        write_log_message('AP_INV_CREATED :' || p_ic_inv_err_dtl_tbl(k)
                          .AP_INV_CREATED);
        write_log_message('ERROR_MSG :' || p_ic_inv_err_dtl_tbl(k)
                          .ERROR_MSG);
      End If;

    End Loop;

    write_log_message('**' || p_msg);

    --fnd_file.put_line(fnd_file.log, chr(10));

  END write_program_log;

  FUNCTION get_setofBooks_Id(p_org_id IN NUMBER) Return NUMBER IS
    l_set_of_books_id NUMBER;
  BEGIN
    Select hu.set_of_books_id
      into l_set_of_books_id
      From hr_operating_units hu
     where hu.organization_id = p_org_id;

    Return l_set_of_books_id;
  Exception
    When No_Data_Found Then
      Return Null;
  END get_setofBooks_Id;
  PROCEDURE get_IC_customer_info(p_ic_item_id           IN NUMBER,
                                 p_sell_organization_id IN NUMBER,
                                 p_inv_type             IN VARCHAR2,
                                 x_ip_org_id            OUT NUMBER,
                                 x_ip_customer_id       OUT NUMBER,
                                 x_ip_address_id        OUT NUMBER,
                                 x_ip_site_use_id       OUT NUMBER,
                                 x_ip_cust_trx_type_id  OUT NUMBER,
                                 x_ip_CM_trx_type_id    OUT NUMBER,
                                 x_inv_curr             OUT VARCHAR2,
                                 x_err_msg              OUT VARCHAR2,
                                 x_err_code             OUT NUMBER) IS
    l_msg VARCHAR2(100) := (Case p_inv_type
                             When '1' Then
                              '1st'
                              When '2' Then
                                '2nd'
                             Else
                              '3rd'
                           End);
  BEGIN
    x_err_code := 0;
    If p_inv_type = '1' Then
      -- 1st Invoice
      SELECT mtfv.SELL_ORGANIZATION_ID,
             mtfv.CUSTOMER_ID,
             mtfv.ADDRESS_ID,
             mtfv.CUSTOMER_SITE_ID,
             mtfv.CUST_TRX_TYPE_ID,
             rctt.credit_memo_type_id,
             pvs.invoice_currency_code
        into x_ip_org_id,
             x_ip_customer_id,
             x_ip_address_id,
             x_ip_site_use_id,
             x_ip_cust_trx_type_id,
             x_ip_CM_trx_type_id,
             x_inv_curr
        FROM mtl_item_categories_v         mc,
             mtl_category_sets             mts,
             MTL_INTERCOMPANY_PARAMETERS_V mtfv,
             hz_cust_site_uses_all         hcsu,
             ra_cust_trx_types_all         rctt,
             po_vendor_sites_all           pvs
       where mc.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         and mc.inventory_item_id = p_ic_item_id --Parameter
         and mts.CATEGORY_SET_ID = mc.Category_Set_Id
         and mts.CATEGORY_SET_NAME = 'XX IP Operating Units'
         and to_char(mtfv.SHIP_ORGANIZATION_ID) = mc.SEGMENT1
         and to_char(mtfv.SELL_ORGANIZATION_ID) = mc.SEGMENT2
         and hcsu.site_use_id = mtfv.CUSTOMER_SITE_Id
         and rctt.cust_trx_type_id = mtfv.CUST_TRX_TYPE_ID
         and pvs.VENDOR_SITE_ID = mtfv.VENDOR_SITE_ID;

    ElsIf p_inv_type = '2' Then
      -- 2nd Invoice
      SELECT mtfv.SHIP_ORGANIZATION_ID,
             mtfv.CUSTOMER_ID,
             mtfv.ADDRESS_ID,
             mtfv.CUSTOMER_SITE_ID,
             mtfv.CUST_TRX_TYPE_ID,
             rctt.credit_memo_type_id,
              pvs.invoice_currency_code
        into x_ip_org_id,
             x_ip_customer_id,
             x_ip_address_id,
             x_ip_site_use_id,
             x_ip_cust_trx_type_id,
             x_ip_CM_trx_type_id,
             x_inv_curr
        FROM mtl_item_categories_v         mc,
             mtl_category_sets             mts,
             MTL_INTERCOMPANY_PARAMETERS_V mtfv,
             hz_cust_site_uses_all         hcsu,
             ra_cust_trx_types_all         rctt,
             po_vendor_sites_all           pvs
       where mc.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         and mc.inventory_item_id = p_ic_item_id --Parameter
         and mts.CATEGORY_SET_ID = mc.Category_Set_Id
         and mts.CATEGORY_SET_NAME = 'XX IP Operating Units'
         and to_char(mtfv.SHIP_ORGANIZATION_ID) = mc.SEGMENT2
         and to_char(mtfv.SELL_ORGANIZATION_ID) = p_sell_organization_id -- Paramater
         and hcsu.site_use_id = mtfv.CUSTOMER_SITE_Id
         and rctt.cust_trx_type_id = mtfv.CUST_TRX_TYPE_ID
         and pvs.VENDOR_SITE_ID = mtfv.VENDOR_SITE_ID;

         ElsIf p_inv_type = '3' Then
          SELECT mtfv.SELL_ORGANIZATION_ID,
             mtfv.CUSTOMER_ID,
             mtfv.ADDRESS_ID,
             mtfv.CUSTOMER_SITE_ID,
             mtfv.CUST_TRX_TYPE_ID,
             rctt.credit_memo_type_id,
              pvs.invoice_currency_code
        into x_ip_org_id,
             x_ip_customer_id,
             x_ip_address_id,
             x_ip_site_use_id,
             x_ip_cust_trx_type_id,
             x_ip_CM_trx_type_id,
             x_inv_curr
        FROM mtl_item_categories_v         mc,
             mtl_category_sets             mts,
             MTL_INTERCOMPANY_PARAMETERS_V mtfv,
             hz_cust_site_uses_all         hcsu,
             ra_cust_trx_types_all         rctt,
             po_vendor_sites_all           pvs
       where mc.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         and mc.inventory_item_id = p_ic_item_id --Parameter
         and mts.CATEGORY_SET_ID = mc.Category_Set_Id
         and mts.CATEGORY_SET_NAME = 'XX IP Operating Units'
         and to_char(mtfv.SHIP_ORGANIZATION_ID) = p_sell_organization_id -- Paramater
         and to_char(mtfv.SELL_ORGANIZATION_ID) =mc.SEGMENT2
         and hcsu.site_use_id = mtfv.CUSTOMER_SITE_Id
         and rctt.cust_trx_type_id = mtfv.CUST_TRX_TYPE_ID
         and pvs.VENDOR_SITE_ID = mtfv.VENDOR_SITE_ID;
    End If;

  Exception
    When NO_DATA_FOUND Then
      x_err_msg  := 'Customer or Vendor Information not found for Creating ' ||
                    l_msg || ' AR Invoice';
      x_err_code := 1;
    When TOO_MANY_ROWS Then
      x_err_msg  := 'Multiple Customer or Vendor Information found for Creating ' ||
                    l_msg || ' AR Invoice';
      x_err_code := 1;
    When Others Then
      x_err_msg  := 'Error occured during ' || l_msg ||
                    ' AR Invoice Creation.Error:' || sqlerrm;
      x_err_code := 1;
  End get_IC_customer_info;
  --
  -- *************************************************************************************
  -- PROCEDURE : repalce_ar_invoice
  --
  -- Purpose:
  --
  -- Revision History
  -- Version   Date            Performer          Comments
  --**************************************************************************************
  --   1.0     04/07/2017      Ofer Suad          CHG0040750  - Initial Build
  --
  -- *************************************************************************************
  Procedure repalce_ar_invoice(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) is

    l_invoice_id          number;
    l_amount              number;
    l_cos_account         number;
    l_cost                number;
    l_inv_curr            varchar2(15);
    l_ip_org_id           number;
    l_ip_customer_id      number;
    l_ip_address_id       number;
    l_ip_site_use_id      number;
    l_ip_cust_trx_type_id number;
    l_ip_CM_trx_type_id   number;
    l_set_of_books_id     number;
    l_sob_id              number;
    l_ic_cm_source        varchar2(25);
    l_request_id          NUMBER;
    l_err_msg             VARCHAR2(1000);
    l_err_code            NUMBER;
    p_bool               boolean;
    l_inv_type           number;
    l_SELL_ORGANIZATION_ID number;


    cursor c_lines is
    --??
      SELECT ril.*,
             ril.rowid,
             to_number(ril.interface_line_attribute4) SELL_ORGANIZATION_ID,
             misb.segment1 item_code,
             decode(mc.SEGMENT1 ,ril.interface_line_attribute4,'Return','Invoice') Is_Return_line
        FROM ra_interface_lines_all ril,
             mtl_item_categories_v  mc,
             mtl_category_sets      mts,
             mtl_system_items_b     misb,
             oe_order_lines_all ol,
             oe_order_headers_all oh
       where ril.interface_line_context = 'INTERCOMPANY'
         and mc.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         and misb.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         and misb.inventory_item_id = ril.inventory_item_id
         and mc.inventory_item_id = ril.inventory_item_id
         and (mc.SEGMENT1 = to_char(ril.org_id)  and mc.SEGMENT2 <> ril.interface_line_attribute4
         or mc.SEGMENT1 =ril.interface_line_attribute4   and mc.SEGMENT2 <> to_char(ril.org_id))
         and mts.CATEGORY_SET_ID = mc.Category_Set_Id
         and mts.CATEGORY_SET_NAME = 'XX IP Operating Units'
         and nvl(ril.request_id, 0) not in (-999, -998)
         and ol.line_id=ril.interface_line_attribute6
         and ol.header_id=oh.header_id
          AND    ril.org_id = ol.org_id
         and oh.creation_date>fnd_profile.value('XXAR_ENABLE_IP_REV_ALLOCATION')

     /* UNION ALL
      --??
      SELECT ril.*,
             ril.rowid,
             mip.SELL_ORGANIZATION_ID,
             misb.segment1 item_code,
             'Return'
        FROM ra_interface_lines_all        ril,
             mtl_item_categories_v         mc,
             mtl_category_sets             mts,
             MTL_INTERCOMPANY_PARAMETERS_V mip,
             mtl_system_items_b            misb,
             oe_order_lines_all ol,
             oe_order_headers_all oh

       where  ril.interface_line_context != 'INTERCOMPANY'
       and mc.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         and misb.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         and misb.inventory_item_id = ril.inventory_item_id
         and mc.inventory_item_id = ril.inventory_item_id
         and mc.SEGMENT1 = to_char(ril.org_id)
         and mip.SHIP_ORGANIZATION_ID = ril.org_id
         and ril.orig_system_bill_customer_id = mip.CUSTOMER_ID
         and ril.orig_system_bill_address_id = mip.ADDRESS_ID
         and mc.SEGMENT2 <> mip.SELL_ORGANIZATION_ID
         and mts.CATEGORY_SET_ID = mc.Category_Set_Id
         and mts.CATEGORY_SET_NAME = 'XX IP Operating Units'
         and nvl(ril.request_id, 0) not in (-999, -998)
         and ol.line_id=ril.interface_line_attribute6
         and ol.header_id=oh.header_id
         and oh.creation_date>fnd_profile.value('XXAR_ENABLE_IP_REV_ALLOCATION')*/;

    l_inv_err_rec IC_INV_ERR_DTL_REC;
    l_inv_err_tab IC_INV_ERR_DTL_TBL;
    ex_custom EXCEPTION;
    l_continue_next_step BOOLEAN;
    l_rec_err_msg        VARCHAR2(4000);
    l_index              NUMBER := 0;
    l_ar_cust_percent    NUMBER := fnd_profile.VALUE('XXAR_COST_PLUS_PERCENT');
  Begin
    write_log_message('xxar_ic_invoice_pkg.repalce_ar_invoice Package Execution Start.');
    l_amount := 0;

    If nvl(l_ar_cust_percent, 0) = 0 Then
      retcode := '2';
      errbuf  := 'No Value Defined for Profile : XXAR_COST_PLUS_PERCENT';
      p_bool := fnd_concurrent.set_completion_status('ERROR',
                                                         'See error log for failing list ');
      write_log_message(errbuf);
      Return;
    End If;

    FOR inv_tab_ip IN c_lines LOOP
      l_cost                := NULL;
      l_ip_org_id           := NULL;
      l_ip_customer_id      := NULL;
      l_ip_address_id       := NULL;
      l_ip_site_use_id      := NULL;
      l_ip_cust_trx_type_id := NULL;
      l_ip_CM_trx_type_id   := NULL;
      l_inv_curr            := NULL;
      l_inv_err_rec         := NULL; -- Record Type
      l_rec_err_msg         := NULL;
      l_continue_next_step  := TRUE;
      l_index               := l_index + 1;
      l_err_msg             := NULL;
      l_err_code            := 0;

      --Assign the Record Deatils to Error Record
      ------------------------------------------------------------------------
      l_inv_err_rec.INVOICE_ROWID             := inv_tab_ip.rowid;
      l_inv_err_rec.ITEM_CODE                 := inv_tab_ip.item_code;
      l_inv_err_rec.ITEM_DESC                 := inv_tab_ip.DESCRIPTION;
      l_inv_err_rec.INTERFACE_LINE_CONTEXT    := inv_tab_ip.INTERFACE_LINE_CONTEXT;
      l_inv_err_rec.INTERFACE_LINE_ATTRIBUTE1 := inv_tab_ip.INTERFACE_LINE_ATTRIBUTE1;
      l_inv_err_rec.BATCH_SOURCE_NAME         := inv_tab_ip.BATCH_SOURCE_NAME;
      l_inv_err_rec.CURRENCY_CODE             := inv_tab_ip.CURRENCY_CODE;
      l_inv_err_rec.CONVERSION_TYPE           := inv_tab_ip.CONVERSION_TYPE;
      l_inv_err_rec.AMOUNT                    := inv_tab_ip.AMOUNT;
      l_inv_err_rec.SALES_ORDER               := inv_tab_ip.SALES_ORDER;
      ------------------------------------------------------------------------
      if  inv_tab_ip.is_return_line='Invoice' then
      l_inv_type:=1;
      l_SELL_ORGANIZATION_ID:=Inv_tab_ip.sell_organization_id;
      else
      l_inv_type:=3;
      l_SELL_ORGANIZATION_ID:=Inv_tab_ip.org_id;
      end if;
      --Fetch Inter Company ??????????
      get_IC_customer_info(p_ic_item_id           => Inv_tab_ip.inventory_item_id,
                           p_sell_organization_id => l_SELL_ORGANIZATION_ID,
                           p_inv_type             => l_inv_type,
                           x_ip_org_id            => l_ip_org_id,
                           x_ip_customer_id       => l_ip_customer_id,
                           x_ip_address_id        => l_ip_address_id,
                           x_ip_site_use_id       => l_ip_site_use_id,
                           x_ip_cust_trx_type_id  => l_ip_cust_trx_type_id,
                           x_ip_CM_trx_type_id    => l_ip_CM_trx_type_id,
                           x_inv_curr             => l_inv_curr,
                           x_err_msg              => l_err_msg,
                           x_err_code             => l_err_code);
      --Failed to Retrive IC Customer Info
      If l_err_code = 1 Then
        l_rec_err_msg        := l_err_msg;
        l_continue_next_step := FALSE;
      End If;

      If l_continue_next_step = TRUE Then
        -- Need to add if item cost = 0 raise  exception here
        l_cost := xxcst_ratam_pkg.get_il_std_cost(81, -- Org ID of IL
                                                  Inv_tab_ip.ship_date_actual,
                                                  Inv_tab_ip.inventory_item_id);
        If l_cost is null or l_cost = 0 Then
          l_continue_next_step := FALSE;
          l_rec_err_msg        := 'Item Cost for Item ' ||
                                  inv_tab_ip.item_code || ' is :' || l_cost;

        End If;
      End If;

      If l_continue_next_step = TRUE Then
        Begin
          Inv_tab_ip.Interface_Line_Id := null;


          if Inv_tab_ip.interface_line_context != 'INTERCOMPANY' then
            Inv_tab_ip.cust_trx_type_id  := l_ip_CM_trx_type_id;
            Inv_tab_ip.Batch_Source_Name := xxobjt_general_utils_pkg.get_profile_value('XXAR_IC_CM_SOURCE_NAME',
                                                                                       'ORG',
                                                                                       Inv_tab_ip.Org_Id);

          end if;
          if inv_tab_ip.Is_Return_line='Invoice' then
          Inv_tab_ip.amount                       := Inv_tab_ip.quantity *
                                                           round(l_cost * (1 +
                                                           l_ar_cust_percent / 100),2);
          Inv_tab_ip.unit_selling_price  := round(l_cost * (1 +
                                                  l_ar_cust_percent / 100),2);
          Inv_tab_ip.unit_standard_price := round(l_cost * (1 +
                                                  l_ar_cust_percent / 100),2);
          Inv_tab_ip.currency_code     := l_inv_curr;
          Inv_tab_ip.cust_trx_type_id          := l_ip_cust_trx_type_id;

          end if;
          Inv_tab_ip.interface_line_attribute4 := l_ip_org_id;
          Inv_tab_ip.orig_system_bill_customer_id := l_ip_customer_id;
          Inv_tab_ip.orig_system_bill_address_id  := l_ip_address_id;
          Inv_tab_ip.orig_system_sold_customer_id := l_ip_customer_id;

          Inv_tab_ip.Orig_System_Bill_Contact_Id  := null;
          Inv_tab_ip.Orig_System_Ship_Customer_Id := null;
          Inv_tab_ip.Orig_System_Ship_Address_Id  := null;
          Inv_tab_ip.Orig_System_Ship_Contact_Id  := null;


          Inv_tab_ip.paying_customer_id  := l_ip_org_id;
          Inv_tab_ip.paying_site_use_id  := l_ip_site_use_id;
          Inv_tab_ip.request_id:=null;
          insert into ra_interface_lines_all
            (interface_line_id,
             interface_line_context,
             interface_line_attribute1,
             interface_line_attribute2,
             interface_line_attribute3,
             interface_line_attribute4,
             interface_line_attribute5,
             interface_line_attribute6,
             interface_line_attribute7,
             interface_line_attribute8,
             batch_source_name,
             set_of_books_id,
             line_type,
             description,
             currency_code,
             amount,
             cust_trx_type_name,
             cust_trx_type_id,
             term_name,
             term_id,
             orig_system_batch_name,
             orig_system_bill_customer_ref,
             orig_system_bill_customer_id,
             orig_system_bill_address_ref,
             orig_system_bill_address_id,
             orig_system_bill_contact_ref,
             orig_system_bill_contact_id,
             orig_system_ship_customer_ref,
             orig_system_ship_customer_id,
             orig_system_ship_address_ref,
             orig_system_ship_address_id,
             orig_system_ship_contact_ref,
             orig_system_ship_contact_id,
             orig_system_sold_customer_ref,
             orig_system_sold_customer_id,
             link_to_line_id,
             link_to_line_context,
             link_to_line_attribute1,
             link_to_line_attribute2,
             link_to_line_attribute3,
             link_to_line_attribute4,
             link_to_line_attribute5,
             link_to_line_attribute6,
             link_to_line_attribute7,
             receipt_method_name,
             receipt_method_id,
             conversion_type,
             conversion_date,
             conversion_rate,
             customer_trx_id,
             trx_date,
             gl_date,
             document_number,
             trx_number,
             line_number,
             quantity,
             quantity_ordered,
             unit_selling_price,
             unit_standard_price,
             printing_option,
             interface_status,
             request_id,
             related_batch_source_name,
             related_trx_number,
             related_customer_trx_id,
             previous_customer_trx_id,
             credit_method_for_acct_rule,
             credit_method_for_installments,
             reason_code,
             tax_rate,
             tax_code,
             tax_precedence,
             exception_id,
             exemption_id,
             ship_date_actual,
             fob_point,
             ship_via,
             waybill_number,
             invoicing_rule_name,
             invoicing_rule_id,
             accounting_rule_name,
             accounting_rule_id,
             accounting_rule_duration,
             rule_start_date,
             primary_salesrep_number,
             primary_salesrep_id,
             sales_order,
             sales_order_line,
             sales_order_date,
             sales_order_source,
             sales_order_revision,
             purchase_order,
             purchase_order_revision,
             purchase_order_date,
             agreement_name,
             agreement_id,
             memo_line_name,
             memo_line_id,
             inventory_item_id,
             mtl_system_items_seg1,
             mtl_system_items_seg2,
             mtl_system_items_seg3,
             mtl_system_items_seg4,
             mtl_system_items_seg5,
             mtl_system_items_seg6,
             mtl_system_items_seg7,
             mtl_system_items_seg8,
             mtl_system_items_seg9,
             mtl_system_items_seg10,
             mtl_system_items_seg11,
             mtl_system_items_seg12,
             mtl_system_items_seg13,
             mtl_system_items_seg14,
             mtl_system_items_seg15,
             mtl_system_items_seg16,
             mtl_system_items_seg17,
             mtl_system_items_seg18,
             mtl_system_items_seg19,
             mtl_system_items_seg20,
             reference_line_id,
             reference_line_context,
             reference_line_attribute1,
             reference_line_attribute2,
             reference_line_attribute3,
             reference_line_attribute4,
             reference_line_attribute5,
             reference_line_attribute6,
             reference_line_attribute7,
             territory_id,
             territory_segment1,
             territory_segment2,
             territory_segment3,
             territory_segment4,
             territory_segment5,
             territory_segment6,
             territory_segment7,
             territory_segment8,
             territory_segment9,
             territory_segment10,
             territory_segment11,
             territory_segment12,
             territory_segment13,
             territory_segment14,
             territory_segment15,
             territory_segment16,
             territory_segment17,
             territory_segment18,
             territory_segment19,
             territory_segment20,
             attribute_category,
             attribute1,
             attribute2,
             attribute3,
             attribute4,
             attribute5,
             attribute6,
             attribute7,
             attribute8,
             attribute9,
             attribute10,
             attribute11,
             attribute12,
             attribute13,
             attribute14,
             attribute15,
             header_attribute_category,
             header_attribute1,
             header_attribute2,
             header_attribute3,
             header_attribute4,
             header_attribute5,
             header_attribute6,
             header_attribute7,
             header_attribute8,
             header_attribute9,
             header_attribute10,
             header_attribute11,
             header_attribute12,
             header_attribute13,
             header_attribute14,
             header_attribute15,
             comments,
             internal_notes,
             initial_customer_trx_id,
             ussgl_transaction_code_context,
             ussgl_transaction_code,
             acctd_amount,
             customer_bank_account_id,
             customer_bank_account_name,
             uom_code,
             uom_name,
             document_number_sequence_id,
             link_to_line_attribute10,
             link_to_line_attribute11,
             link_to_line_attribute12,
             link_to_line_attribute13,
             link_to_line_attribute14,
             link_to_line_attribute15,
             link_to_line_attribute8,
             link_to_line_attribute9,
             reference_line_attribute10,
             reference_line_attribute11,
             reference_line_attribute12,
             reference_line_attribute13,
             reference_line_attribute14,
             reference_line_attribute15,
             reference_line_attribute8,
             reference_line_attribute9,
             interface_line_attribute10,
             interface_line_attribute11,
             interface_line_attribute12,
             interface_line_attribute13,
             interface_line_attribute14,
             interface_line_attribute15,
             interface_line_attribute9,
             vat_tax_id,
             reason_code_meaning,
             last_period_to_credit,
             paying_customer_id,
             paying_site_use_id,
             tax_exempt_flag,
             tax_exempt_reason_code,
             tax_exempt_reason_code_meaning,
             tax_exempt_number,
             sales_tax_id,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date,
             last_update_login,
             location_segment_id,
             movement_id,
             org_id,
             amount_includes_tax_flag,
             header_gdf_attr_category,
             header_gdf_attribute1,
             header_gdf_attribute2,
             header_gdf_attribute3,
             header_gdf_attribute4,
             header_gdf_attribute5,
             header_gdf_attribute6,
             header_gdf_attribute7,
             header_gdf_attribute8,
             header_gdf_attribute9,
             header_gdf_attribute10,
             header_gdf_attribute11,
             header_gdf_attribute12,
             header_gdf_attribute13,
             header_gdf_attribute14,
             header_gdf_attribute15,
             header_gdf_attribute16,
             header_gdf_attribute17,
             header_gdf_attribute18,
             header_gdf_attribute19,
             header_gdf_attribute20,
             header_gdf_attribute21,
             header_gdf_attribute22,
             header_gdf_attribute23,
             header_gdf_attribute24,
             header_gdf_attribute25,
             header_gdf_attribute26,
             header_gdf_attribute27,
             header_gdf_attribute28,
             header_gdf_attribute29,
             header_gdf_attribute30,
             line_gdf_attr_category,
             line_gdf_attribute1,
             line_gdf_attribute2,
             line_gdf_attribute3,
             line_gdf_attribute4,
             line_gdf_attribute5,
             line_gdf_attribute6,
             line_gdf_attribute7,
             line_gdf_attribute8,
             line_gdf_attribute9,
             line_gdf_attribute10,
             line_gdf_attribute11,
             line_gdf_attribute12,
             line_gdf_attribute13,
             line_gdf_attribute14,
             line_gdf_attribute15,
             line_gdf_attribute16,
             line_gdf_attribute17,
             line_gdf_attribute18,
             line_gdf_attribute19,
             line_gdf_attribute20,
             reset_trx_date_flag,
             payment_server_order_num,
             approval_code,
             address_verification_code,
             warehouse_id,
             translated_description,
             cons_billing_number,
             promised_commitment_amount,
             payment_set_id,
             original_gl_date,
             contract_line_id,
             contract_id,
             source_data_key1,
             source_data_key2,
             source_data_key3,
             source_data_key4,
             source_data_key5,
             invoiced_line_acctg_level,
             override_auto_accounting_flag,
             source_application_id,
             source_event_class_code,
             source_entity_code,
             source_trx_id,
             source_trx_line_id,
             source_trx_line_type,
             source_trx_detail_tax_line_id,
             historical_flag,
             tax_regime_code,
             tax,
             tax_status_code,
             tax_rate_code,
             tax_jurisdiction_code,
             taxable_amount,
             taxable_flag,
             legal_entity_id,
             parent_line_id,
             deferral_exclusion_flag,
             payment_trxn_extension_id,
             rule_end_date,
             payment_attributes,
             application_id,
             billing_date,
             trx_business_category,
             product_fisc_classification,
             product_category,
             product_type,
             line_intended_use,
             assessable_value,
             user_defined_fisc_class,
             taxed_upstream_flag,
             document_sub_type,
             default_taxation_country,
             tax_invoice_date,
             tax_invoice_number,
             payment_type_code,
             mandate_last_trx_flag,
             rev_rec_application,
             document_type_id,
             document_creation_date,
             doc_line_id_int_1,
             doc_line_id_int_2,
             doc_line_id_int_3,
             doc_line_id_int_4,
             doc_line_id_int_5,
             doc_line_id_char_1,
             doc_line_id_char_2,
             doc_line_id_char_3,
             doc_line_id_char_4,
             doc_line_id_char_5)
          values
            (Inv_tab_ip.interface_line_id,
             Inv_tab_ip.interface_line_context,
             Inv_tab_ip.interface_line_attribute1,
             Inv_tab_ip.interface_line_attribute2,
             Inv_tab_ip.interface_line_attribute3,
             Inv_tab_ip.interface_line_attribute4,
             Inv_tab_ip.interface_line_attribute5,
             Inv_tab_ip.interface_line_attribute6,
             Inv_tab_ip.interface_line_attribute7,
             Inv_tab_ip.interface_line_attribute8,
             Inv_tab_ip.batch_source_name,
             Inv_tab_ip.set_of_books_id,
             Inv_tab_ip.line_type,
             Inv_tab_ip.description,
             Inv_tab_ip.currency_code,
             Inv_tab_ip.amount,
             Inv_tab_ip.cust_trx_type_name,
             Inv_tab_ip.cust_trx_type_id,
             Inv_tab_ip.term_name,
             Inv_tab_ip.term_id,
             Inv_tab_ip.orig_system_batch_name,
             Inv_tab_ip.orig_system_bill_customer_ref,
             Inv_tab_ip.orig_system_bill_customer_id,
             Inv_tab_ip.orig_system_bill_address_ref,
             Inv_tab_ip.orig_system_bill_address_id,
             Inv_tab_ip.orig_system_bill_contact_ref,
             Inv_tab_ip.orig_system_bill_contact_id,
             Inv_tab_ip.orig_system_ship_customer_ref,
             Inv_tab_ip.orig_system_ship_customer_id,
             Inv_tab_ip.orig_system_ship_address_ref,
             Inv_tab_ip.orig_system_ship_address_id,
             Inv_tab_ip.orig_system_ship_contact_ref,
             Inv_tab_ip.orig_system_ship_contact_id,
             Inv_tab_ip.orig_system_sold_customer_ref,
             Inv_tab_ip.orig_system_sold_customer_id,
             Inv_tab_ip.link_to_line_id,
             Inv_tab_ip.link_to_line_context,
             Inv_tab_ip.link_to_line_attribute1,
             Inv_tab_ip.link_to_line_attribute2,
             Inv_tab_ip.link_to_line_attribute3,
             Inv_tab_ip.link_to_line_attribute4,
             Inv_tab_ip.link_to_line_attribute5,
             Inv_tab_ip.link_to_line_attribute6,
             Inv_tab_ip.link_to_line_attribute7,
             Inv_tab_ip.receipt_method_name,
             Inv_tab_ip.receipt_method_id,
             Inv_tab_ip.conversion_type,
             Inv_tab_ip.conversion_date,
             Inv_tab_ip.conversion_rate,
             Inv_tab_ip.customer_trx_id,
             Inv_tab_ip.trx_date,
             Inv_tab_ip.gl_date,
             Inv_tab_ip.document_number,
             Inv_tab_ip.trx_number,
             Inv_tab_ip.line_number,
             Inv_tab_ip.quantity,
             Inv_tab_ip.quantity_ordered,
             Inv_tab_ip.unit_selling_price,
             Inv_tab_ip.unit_standard_price,
             Inv_tab_ip.printing_option,
             Inv_tab_ip.interface_status,
             Inv_tab_ip.request_id,
             Inv_tab_ip.related_batch_source_name,
             Inv_tab_ip.related_trx_number,
             Inv_tab_ip.related_customer_trx_id,
             Inv_tab_ip.previous_customer_trx_id,
             Inv_tab_ip.credit_method_for_acct_rule,
             Inv_tab_ip.credit_method_for_installments,
             Inv_tab_ip.reason_code,
             Inv_tab_ip.tax_rate,
             Inv_tab_ip.tax_code,
             Inv_tab_ip.tax_precedence,
             Inv_tab_ip.exception_id,
             Inv_tab_ip.exemption_id,
             Inv_tab_ip.ship_date_actual,
             Inv_tab_ip.fob_point,
             Inv_tab_ip.ship_via,
             Inv_tab_ip.waybill_number,
             Inv_tab_ip.invoicing_rule_name,
             Inv_tab_ip.invoicing_rule_id,
             Inv_tab_ip.accounting_rule_name,
             Inv_tab_ip.accounting_rule_id,
             Inv_tab_ip.accounting_rule_duration,
             Inv_tab_ip.rule_start_date,
             Inv_tab_ip.primary_salesrep_number,
             Inv_tab_ip.primary_salesrep_id,
             Inv_tab_ip.sales_order,
             Inv_tab_ip.sales_order_line,
             Inv_tab_ip.sales_order_date,
             Inv_tab_ip.sales_order_source,
             Inv_tab_ip.sales_order_revision,
             Inv_tab_ip.purchase_order,
             Inv_tab_ip.purchase_order_revision,
             Inv_tab_ip.purchase_order_date,
             Inv_tab_ip.agreement_name,
             Inv_tab_ip.agreement_id,
             Inv_tab_ip.memo_line_name,
             Inv_tab_ip.memo_line_id,
             Inv_tab_ip.inventory_item_id,
             Inv_tab_ip.mtl_system_items_seg1,
             Inv_tab_ip.mtl_system_items_seg2,
             Inv_tab_ip.mtl_system_items_seg3,
             Inv_tab_ip.mtl_system_items_seg4,
             Inv_tab_ip.mtl_system_items_seg5,
             Inv_tab_ip.mtl_system_items_seg6,
             Inv_tab_ip.mtl_system_items_seg7,
             Inv_tab_ip.mtl_system_items_seg8,
             Inv_tab_ip.mtl_system_items_seg9,
             Inv_tab_ip.mtl_system_items_seg10,
             Inv_tab_ip.mtl_system_items_seg11,
             Inv_tab_ip.mtl_system_items_seg12,
             Inv_tab_ip.mtl_system_items_seg13,
             Inv_tab_ip.mtl_system_items_seg14,
             Inv_tab_ip.mtl_system_items_seg15,
             Inv_tab_ip.mtl_system_items_seg16,
             Inv_tab_ip.mtl_system_items_seg17,
             Inv_tab_ip.mtl_system_items_seg18,
             Inv_tab_ip.mtl_system_items_seg19,
             Inv_tab_ip.mtl_system_items_seg20,
             Inv_tab_ip.reference_line_id,
             Inv_tab_ip.reference_line_context,
             Inv_tab_ip.reference_line_attribute1,
             Inv_tab_ip.reference_line_attribute2,
             Inv_tab_ip.reference_line_attribute3,
             Inv_tab_ip.reference_line_attribute4,
             Inv_tab_ip.reference_line_attribute5,
             Inv_tab_ip.reference_line_attribute6,
             Inv_tab_ip.reference_line_attribute7,
             Inv_tab_ip.territory_id,
             Inv_tab_ip.territory_segment1,
             Inv_tab_ip.territory_segment2,
             Inv_tab_ip.territory_segment3,
             Inv_tab_ip.territory_segment4,
             Inv_tab_ip.territory_segment5,
             Inv_tab_ip.territory_segment6,
             Inv_tab_ip.territory_segment7,
             Inv_tab_ip.territory_segment8,
             Inv_tab_ip.territory_segment9,
             Inv_tab_ip.territory_segment10,
             Inv_tab_ip.territory_segment11,
             Inv_tab_ip.territory_segment12,
             Inv_tab_ip.territory_segment13,
             Inv_tab_ip.territory_segment14,
             Inv_tab_ip.territory_segment15,
             Inv_tab_ip.territory_segment16,
             Inv_tab_ip.territory_segment17,
             Inv_tab_ip.territory_segment18,
             Inv_tab_ip.territory_segment19,
             Inv_tab_ip.territory_segment20,
             Inv_tab_ip.attribute_category,
             Inv_tab_ip.attribute1,
             Inv_tab_ip.attribute2,
             Inv_tab_ip.attribute3,
             Inv_tab_ip.attribute4,
             Inv_tab_ip.attribute5,
             Inv_tab_ip.attribute6,
             Inv_tab_ip.attribute7,
             Inv_tab_ip.attribute8,
             Inv_tab_ip.attribute9,
             Inv_tab_ip.attribute10,
             Inv_tab_ip.attribute11,
             Inv_tab_ip.attribute12,
             Inv_tab_ip.attribute13,
             Inv_tab_ip.attribute14,
             Inv_tab_ip.attribute15,
             Inv_tab_ip.header_attribute_category,
             Inv_tab_ip.header_attribute1,
             Inv_tab_ip.header_attribute2,
             Inv_tab_ip.header_attribute3,
             Inv_tab_ip.header_attribute4,
             Inv_tab_ip.header_attribute5,
             Inv_tab_ip.header_attribute6,
             Inv_tab_ip.header_attribute7,
             Inv_tab_ip.header_attribute8,
             Inv_tab_ip.header_attribute9,
             Inv_tab_ip.header_attribute10,
             Inv_tab_ip.header_attribute11,
             Inv_tab_ip.header_attribute12,
             Inv_tab_ip.header_attribute13,
             Inv_tab_ip.header_attribute14,
             Inv_tab_ip.header_attribute15,
             Inv_tab_ip.comments,
             Inv_tab_ip.internal_notes,
             Inv_tab_ip.initial_customer_trx_id,
             Inv_tab_ip.ussgl_transaction_code_context,
             Inv_tab_ip.ussgl_transaction_code,
             Inv_tab_ip.acctd_amount,
             Inv_tab_ip.customer_bank_account_id,
             Inv_tab_ip.customer_bank_account_name,
             Inv_tab_ip.uom_code,
             Inv_tab_ip.uom_name,
             Inv_tab_ip.document_number_sequence_id,
             Inv_tab_ip.link_to_line_attribute10,
             Inv_tab_ip.link_to_line_attribute11,
             Inv_tab_ip.link_to_line_attribute12,
             Inv_tab_ip.link_to_line_attribute13,
             Inv_tab_ip.link_to_line_attribute14,
             Inv_tab_ip.link_to_line_attribute15,
             Inv_tab_ip.link_to_line_attribute8,
             Inv_tab_ip.link_to_line_attribute9,
             Inv_tab_ip.reference_line_attribute10,
             Inv_tab_ip.reference_line_attribute11,
             Inv_tab_ip.reference_line_attribute12,
             Inv_tab_ip.reference_line_attribute13,
             Inv_tab_ip.reference_line_attribute14,
             Inv_tab_ip.reference_line_attribute15,
             Inv_tab_ip.reference_line_attribute8,
             Inv_tab_ip.reference_line_attribute9,
             Inv_tab_ip.interface_line_attribute10,
             Inv_tab_ip.interface_line_attribute11,
             Inv_tab_ip.interface_line_attribute12,
             Inv_tab_ip.interface_line_attribute13,
             Inv_tab_ip.interface_line_attribute14,
             Inv_tab_ip.interface_line_attribute15,
             Inv_tab_ip.interface_line_attribute9,
             Inv_tab_ip.vat_tax_id,
             Inv_tab_ip.reason_code_meaning,
             Inv_tab_ip.last_period_to_credit,
             Inv_tab_ip.paying_customer_id,
             Inv_tab_ip.paying_site_use_id,
             Inv_tab_ip.tax_exempt_flag,
             Inv_tab_ip.tax_exempt_reason_code,
             Inv_tab_ip.tax_exempt_reason_code_meaning,
             Inv_tab_ip.tax_exempt_number,
             Inv_tab_ip.sales_tax_id,
             Inv_tab_ip.created_by,
             Inv_tab_ip.creation_date,
             Inv_tab_ip.last_updated_by,
             Inv_tab_ip.last_update_date,
             Inv_tab_ip.last_update_login,
             Inv_tab_ip.location_segment_id,
             Inv_tab_ip.movement_id,
             Inv_tab_ip.org_id,
             Inv_tab_ip.amount_includes_tax_flag,
             Inv_tab_ip.header_gdf_attr_category,
             Inv_tab_ip.header_gdf_attribute1,
             Inv_tab_ip.header_gdf_attribute2,
             Inv_tab_ip.header_gdf_attribute3,
             Inv_tab_ip.header_gdf_attribute4,
             Inv_tab_ip.header_gdf_attribute5,
             Inv_tab_ip.header_gdf_attribute6,
             Inv_tab_ip.header_gdf_attribute7,
             Inv_tab_ip.header_gdf_attribute8,
             Inv_tab_ip.header_gdf_attribute9,
             Inv_tab_ip.header_gdf_attribute10,
             Inv_tab_ip.header_gdf_attribute11,
             Inv_tab_ip.header_gdf_attribute12,
             Inv_tab_ip.header_gdf_attribute13,
             Inv_tab_ip.header_gdf_attribute14,
             Inv_tab_ip.header_gdf_attribute15,
             Inv_tab_ip.header_gdf_attribute16,
             Inv_tab_ip.header_gdf_attribute17,
             Inv_tab_ip.header_gdf_attribute18,
             Inv_tab_ip.header_gdf_attribute19,
             Inv_tab_ip.header_gdf_attribute20,
             Inv_tab_ip.header_gdf_attribute21,
             Inv_tab_ip.header_gdf_attribute22,
             Inv_tab_ip.header_gdf_attribute23,
             Inv_tab_ip.header_gdf_attribute24,
             Inv_tab_ip.header_gdf_attribute25,
             Inv_tab_ip.header_gdf_attribute26,
             Inv_tab_ip.header_gdf_attribute27,
             Inv_tab_ip.header_gdf_attribute28,
             Inv_tab_ip.header_gdf_attribute29,
             Inv_tab_ip.header_gdf_attribute30,
             Inv_tab_ip.line_gdf_attr_category,
             Inv_tab_ip.line_gdf_attribute1,
             Inv_tab_ip.line_gdf_attribute2,
             Inv_tab_ip.line_gdf_attribute3,
             Inv_tab_ip.line_gdf_attribute4,
             Inv_tab_ip.line_gdf_attribute5,
             Inv_tab_ip.line_gdf_attribute6,
             Inv_tab_ip.line_gdf_attribute7,
             Inv_tab_ip.line_gdf_attribute8,
             Inv_tab_ip.line_gdf_attribute9,
             Inv_tab_ip.line_gdf_attribute10,
             Inv_tab_ip.line_gdf_attribute11,
             Inv_tab_ip.line_gdf_attribute12,
             Inv_tab_ip.line_gdf_attribute13,
             Inv_tab_ip.line_gdf_attribute14,
             Inv_tab_ip.line_gdf_attribute15,
             Inv_tab_ip.line_gdf_attribute16,
             Inv_tab_ip.line_gdf_attribute17,
             Inv_tab_ip.line_gdf_attribute18,
             Inv_tab_ip.line_gdf_attribute19,
             Inv_tab_ip.line_gdf_attribute20,
             Inv_tab_ip.reset_trx_date_flag,
             Inv_tab_ip.payment_server_order_num,
             Inv_tab_ip.approval_code,
             Inv_tab_ip.address_verification_code,
             Inv_tab_ip.warehouse_id,
             Inv_tab_ip.translated_description,
             Inv_tab_ip.cons_billing_number,
             Inv_tab_ip.promised_commitment_amount,
             Inv_tab_ip.payment_set_id,
             Inv_tab_ip.original_gl_date,
             Inv_tab_ip.contract_line_id,
             Inv_tab_ip.contract_id,
             Inv_tab_ip.source_data_key1,
             Inv_tab_ip.source_data_key2,
             Inv_tab_ip.source_data_key3,
             Inv_tab_ip.source_data_key4,
             Inv_tab_ip.source_data_key5,
             Inv_tab_ip.invoiced_line_acctg_level,
             Inv_tab_ip.override_auto_accounting_flag,
             Inv_tab_ip.source_application_id,
             Inv_tab_ip.source_event_class_code,
             Inv_tab_ip.source_entity_code,
             Inv_tab_ip.source_trx_id,
             Inv_tab_ip.source_trx_line_id,
             Inv_tab_ip.source_trx_line_type,
             Inv_tab_ip.source_trx_detail_tax_line_id,
             Inv_tab_ip.historical_flag,
             Inv_tab_ip.tax_regime_code,
             Inv_tab_ip.tax,
             Inv_tab_ip.tax_status_code,
             Inv_tab_ip.tax_rate_code,
             Inv_tab_ip.tax_jurisdiction_code,
             Inv_tab_ip.taxable_amount,
             Inv_tab_ip.taxable_flag,
             Inv_tab_ip.legal_entity_id,
             Inv_tab_ip.parent_line_id,
             Inv_tab_ip.deferral_exclusion_flag,
             Inv_tab_ip.payment_trxn_extension_id,
             Inv_tab_ip.rule_end_date,
             Inv_tab_ip.payment_attributes,
             Inv_tab_ip.application_id,
             Inv_tab_ip.billing_date,
             Inv_tab_ip.trx_business_category,
             Inv_tab_ip.product_fisc_classification,
             Inv_tab_ip.product_category,
             Inv_tab_ip.product_type,
             Inv_tab_ip.line_intended_use,
             Inv_tab_ip.assessable_value,
             Inv_tab_ip.user_defined_fisc_class,
             Inv_tab_ip.taxed_upstream_flag,
             Inv_tab_ip.document_sub_type,
             Inv_tab_ip.default_taxation_country,
             Inv_tab_ip.tax_invoice_date,
             Inv_tab_ip.tax_invoice_number,
             Inv_tab_ip.payment_type_code,
             Inv_tab_ip.mandate_last_trx_flag,
             Inv_tab_ip.rev_rec_application,
             Inv_tab_ip.document_type_id,
             Inv_tab_ip.document_creation_date,
             Inv_tab_ip.doc_line_id_int_1,
             Inv_tab_ip.doc_line_id_int_2,
             Inv_tab_ip.doc_line_id_int_3,
             Inv_tab_ip.doc_line_id_int_4,
             Inv_tab_ip.doc_line_id_int_5,
             Inv_tab_ip.doc_line_id_char_1,
             Inv_tab_ip.doc_line_id_char_2,
             Inv_tab_ip.doc_line_id_char_3,
             Inv_tab_ip.doc_line_id_char_4,
             Inv_tab_ip.doc_line_id_char_5);

        Exception
          When Others Then
            l_rec_err_msg        := sqlerrm;
            l_continue_next_step := FALSE;
        End;
      End If;

      If l_continue_next_step = FALSE THEN
         p_bool := fnd_concurrent.set_completion_status('ERROR',
                                                         'See error log for failing list ');
        l_inv_err_rec.FIRST_AR_INV_CREATED := 'No';
        l_inv_err_rec.ERROR_MSG            := l_rec_err_msg;
      Elsif l_continue_next_step = TRUE THEN
        l_inv_err_rec.FIRST_AR_INV_CREATED := 'Yes';
      End If;

      l_inv_err_tab(l_index) := l_inv_err_rec;

    end loop;

    l_amount := 0;
    l_index  := 0;

    ---------Second AR Invoice
    FOR Inv_tab_ship IN c_lines LOOP
      l_rec_err_msg        := Null;
      l_index              := l_index + 1;
      l_continue_next_step := TRUE;
      l_set_of_books_id    := NULL;

      For j in 1 .. l_inv_err_tab.count Loop
        If l_inv_err_tab(j).INVOICE_ROWID = Inv_tab_ship.rowid Then
          If l_inv_err_tab(j).FIRST_AR_INV_CREATED = 'No' Then
            l_continue_next_step := FALSE;
          End If;
          Exit;
        End If;
      End Loop;

      -- Need to add exception here  too many rows and no data found
      --Fetch Inter Company ??????????
      If l_continue_next_step = TRUE Then
        get_IC_customer_info(p_ic_item_id           => inv_tab_ship.inventory_item_id,
                             p_sell_organization_id => inv_tab_ship.sell_organization_id,
                             p_inv_type             => '2',
                             x_ip_org_id            => l_ip_org_id,
                             x_ip_customer_id       => l_ip_customer_id,
                             x_ip_address_id        => l_ip_address_id,
                             x_ip_site_use_id       => l_ip_site_use_id,
                             x_ip_cust_trx_type_id  => l_ip_cust_trx_type_id,
                             x_ip_CM_trx_type_id    => l_ip_CM_trx_type_id,
                             x_inv_curr             => l_inv_curr,
                             x_err_msg              => l_err_msg,
                             x_err_code             => l_err_code);
        --Failed to Retrive IC Customer Info
        If l_err_code = 1 Then
          l_rec_err_msg        := l_err_msg;
          l_continue_next_step := FALSE;
        End If;
      End If;

      IF l_continue_next_step = TRUE Then
        l_set_of_books_id := get_setofBooks_Id(l_ip_org_id);
        If l_set_of_books_id is null Then
          l_rec_err_msg        := l_rec_err_msg ||
                                  'Set Of Books Id Not Found.';
          l_continue_next_step := FALSE;
        End If;
      End If;

      IF l_continue_next_step = TRUE Then
        Begin
          Inv_tab_ship.Interface_Line_Id := null;
          -- Inv_tab_ship.interface_line_attribute3    := null;
          Inv_tab_ship.org_id := l_ip_org_id;

          Inv_tab_ship.set_of_books_id := l_set_of_books_id;

          if Inv_tab_ship.interface_line_context = 'INTERCOMPANY' then
            Inv_tab_ship.interface_line_attribute5 := l_ip_org_id;
           -- Inv_tab_ship.interface_line_attribute8 := l_ip_org_id;
            Inv_tab_ship.cust_trx_type_id          := l_ip_cust_trx_type_id;
          else
            Inv_tab_ship.cust_trx_type_id  := l_ip_CM_trx_type_id;
            Inv_tab_ship.Batch_Source_Name := xxobjt_general_utils_pkg.get_profile_value('XXAR_IC_CM_SOURCE_NAME',
                                                                                         'ORG',
                                                                                         l_ip_org_id);

          end if;
          Inv_tab_ship.orig_system_bill_customer_id := l_ip_customer_id;
          Inv_tab_ship.orig_system_bill_address_id  := l_ip_address_id;
          Inv_tab_ship.Orig_System_Bill_Contact_Id  := null;
          Inv_tab_ship.Orig_System_Ship_Customer_Id := null;
          Inv_tab_ship.Orig_System_Ship_Address_Id  := null;
          Inv_tab_ship.Orig_System_Ship_Contact_Id  := null;

          Inv_tab_ship.paying_site_use_id := l_ip_site_use_id;
          Inv_tab_ship.request_id:=null;

          if Inv_tab_ship.Is_Return_line='Return' then
          Inv_tab_ship.amount                       := Inv_tab_ship.quantity *
                                                           round(l_cost * (1 +
                                                           l_ar_cust_percent / 100),2);
          Inv_tab_ship.unit_selling_price  := round(l_cost * (1 +
                                                  l_ar_cust_percent / 100),2);
          Inv_tab_ship.unit_standard_price := round(l_cost * (1 +
                                                  l_ar_cust_percent / 100),2);
           Inv_tab_ship.currency_code     := l_inv_curr;

          end if;

          insert into ra_interface_lines_all
            (interface_line_id,
             interface_line_context,
             interface_line_attribute1,
             interface_line_attribute2,
             interface_line_attribute3,
             interface_line_attribute4,
             interface_line_attribute5,
             interface_line_attribute6,
             interface_line_attribute7,
             interface_line_attribute8,
             batch_source_name,
             set_of_books_id,
             line_type,
             description,
             currency_code,
             amount,
             cust_trx_type_name,
             cust_trx_type_id,
             term_name,
             term_id,
             orig_system_batch_name,
             orig_system_bill_customer_ref,
             orig_system_bill_customer_id,
             orig_system_bill_address_ref,
             orig_system_bill_address_id,
             orig_system_bill_contact_ref,
             orig_system_bill_contact_id,
             orig_system_ship_customer_ref,
             orig_system_ship_customer_id,
             orig_system_ship_address_ref,
             orig_system_ship_address_id,
             orig_system_ship_contact_ref,
             orig_system_ship_contact_id,
             orig_system_sold_customer_ref,
             orig_system_sold_customer_id,
             link_to_line_id,
             link_to_line_context,
             link_to_line_attribute1,
             link_to_line_attribute2,
             link_to_line_attribute3,
             link_to_line_attribute4,
             link_to_line_attribute5,
             link_to_line_attribute6,
             link_to_line_attribute7,
             receipt_method_name,
             receipt_method_id,
             conversion_type,
             conversion_date,
             conversion_rate,
             customer_trx_id,
             trx_date,
             gl_date,
             document_number,
             trx_number,
             line_number,
             quantity,
             quantity_ordered,
             unit_selling_price,
             unit_standard_price,
             printing_option,
             interface_status,
             request_id,
             related_batch_source_name,
             related_trx_number,
             related_customer_trx_id,
             previous_customer_trx_id,
             credit_method_for_acct_rule,
             credit_method_for_installments,
             reason_code,
             tax_rate,
             tax_code,
             tax_precedence,
             exception_id,
             exemption_id,
             ship_date_actual,
             fob_point,
             ship_via,
             waybill_number,
             invoicing_rule_name,
             invoicing_rule_id,
             accounting_rule_name,
             accounting_rule_id,
             accounting_rule_duration,
             rule_start_date,
             primary_salesrep_number,
             primary_salesrep_id,
             sales_order,
             sales_order_line,
             sales_order_date,
             sales_order_source,
             sales_order_revision,
             purchase_order,
             purchase_order_revision,
             purchase_order_date,
             agreement_name,
             agreement_id,
             memo_line_name,
             memo_line_id,
             inventory_item_id,
             mtl_system_items_seg1,
             mtl_system_items_seg2,
             mtl_system_items_seg3,
             mtl_system_items_seg4,
             mtl_system_items_seg5,
             mtl_system_items_seg6,
             mtl_system_items_seg7,
             mtl_system_items_seg8,
             mtl_system_items_seg9,
             mtl_system_items_seg10,
             mtl_system_items_seg11,
             mtl_system_items_seg12,
             mtl_system_items_seg13,
             mtl_system_items_seg14,
             mtl_system_items_seg15,
             mtl_system_items_seg16,
             mtl_system_items_seg17,
             mtl_system_items_seg18,
             mtl_system_items_seg19,
             mtl_system_items_seg20,
             reference_line_id,
             reference_line_context,
             reference_line_attribute1,
             reference_line_attribute2,
             reference_line_attribute3,
             reference_line_attribute4,
             reference_line_attribute5,
             reference_line_attribute6,
             reference_line_attribute7,
             territory_id,
             territory_segment1,
             territory_segment2,
             territory_segment3,
             territory_segment4,
             territory_segment5,
             territory_segment6,
             territory_segment7,
             territory_segment8,
             territory_segment9,
             territory_segment10,
             territory_segment11,
             territory_segment12,
             territory_segment13,
             territory_segment14,
             territory_segment15,
             territory_segment16,
             territory_segment17,
             territory_segment18,
             territory_segment19,
             territory_segment20,
             attribute_category,
             attribute1,
             attribute2,
             attribute3,
             attribute4,
             attribute5,
             attribute6,
             attribute7,
             attribute8,
             attribute9,
             attribute10,
             attribute11,
             attribute12,
             attribute13,
             attribute14,
             attribute15,
             header_attribute_category,
             header_attribute1,
             header_attribute2,
             header_attribute3,
             header_attribute4,
             header_attribute5,
             header_attribute6,
             header_attribute7,
             header_attribute8,
             header_attribute9,
             header_attribute10,
             header_attribute11,
             header_attribute12,
             header_attribute13,
             header_attribute14,
             header_attribute15,
             comments,
             internal_notes,
             initial_customer_trx_id,
             ussgl_transaction_code_context,
             ussgl_transaction_code,
             acctd_amount,
             customer_bank_account_id,
             customer_bank_account_name,
             uom_code,
             uom_name,
             document_number_sequence_id,
             link_to_line_attribute10,
             link_to_line_attribute11,
             link_to_line_attribute12,
             link_to_line_attribute13,
             link_to_line_attribute14,
             link_to_line_attribute15,
             link_to_line_attribute8,
             link_to_line_attribute9,
             reference_line_attribute10,
             reference_line_attribute11,
             reference_line_attribute12,
             reference_line_attribute13,
             reference_line_attribute14,
             reference_line_attribute15,
             reference_line_attribute8,
             reference_line_attribute9,
             interface_line_attribute10,
             interface_line_attribute11,
             interface_line_attribute12,
             interface_line_attribute13,
             interface_line_attribute14,
             interface_line_attribute15,
             interface_line_attribute9,
             vat_tax_id,
             reason_code_meaning,
             last_period_to_credit,
             paying_customer_id,
             paying_site_use_id,
             tax_exempt_flag,
             tax_exempt_reason_code,
             tax_exempt_reason_code_meaning,
             tax_exempt_number,
             sales_tax_id,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date,
             last_update_login,
             location_segment_id,
             movement_id,
             org_id,
             amount_includes_tax_flag,
             header_gdf_attr_category,
             header_gdf_attribute1,
             header_gdf_attribute2,
             header_gdf_attribute3,
             header_gdf_attribute4,
             header_gdf_attribute5,
             header_gdf_attribute6,
             header_gdf_attribute7,
             header_gdf_attribute8,
             header_gdf_attribute9,
             header_gdf_attribute10,
             header_gdf_attribute11,
             header_gdf_attribute12,
             header_gdf_attribute13,
             header_gdf_attribute14,
             header_gdf_attribute15,
             header_gdf_attribute16,
             header_gdf_attribute17,
             header_gdf_attribute18,
             header_gdf_attribute19,
             header_gdf_attribute20,
             header_gdf_attribute21,
             header_gdf_attribute22,
             header_gdf_attribute23,
             header_gdf_attribute24,
             header_gdf_attribute25,
             header_gdf_attribute26,
             header_gdf_attribute27,
             header_gdf_attribute28,
             header_gdf_attribute29,
             header_gdf_attribute30,
             line_gdf_attr_category,
             line_gdf_attribute1,
             line_gdf_attribute2,
             line_gdf_attribute3,
             line_gdf_attribute4,
             line_gdf_attribute5,
             line_gdf_attribute6,
             line_gdf_attribute7,
             line_gdf_attribute8,
             line_gdf_attribute9,
             line_gdf_attribute10,
             line_gdf_attribute11,
             line_gdf_attribute12,
             line_gdf_attribute13,
             line_gdf_attribute14,
             line_gdf_attribute15,
             line_gdf_attribute16,
             line_gdf_attribute17,
             line_gdf_attribute18,
             line_gdf_attribute19,
             line_gdf_attribute20,
             reset_trx_date_flag,
             payment_server_order_num,
             approval_code,
             address_verification_code,
             warehouse_id,
             translated_description,
             cons_billing_number,
             promised_commitment_amount,
             payment_set_id,
             original_gl_date,
             contract_line_id,
             contract_id,
             source_data_key1,
             source_data_key2,
             source_data_key3,
             source_data_key4,
             source_data_key5,
             invoiced_line_acctg_level,
             override_auto_accounting_flag,
             source_application_id,
             source_event_class_code,
             source_entity_code,
             source_trx_id,
             source_trx_line_id,
             source_trx_line_type,
             source_trx_detail_tax_line_id,
             historical_flag,
             tax_regime_code,
             tax,
             tax_status_code,
             tax_rate_code,
             tax_jurisdiction_code,
             taxable_amount,
             taxable_flag,
             legal_entity_id,
             parent_line_id,
             deferral_exclusion_flag,
             payment_trxn_extension_id,
             rule_end_date,
             payment_attributes,
             application_id,
             billing_date,
             trx_business_category,
             product_fisc_classification,
             product_category,
             product_type,
             line_intended_use,
             assessable_value,
             user_defined_fisc_class,
             taxed_upstream_flag,
             document_sub_type,
             default_taxation_country,
             tax_invoice_date,
             tax_invoice_number,
             payment_type_code,
             mandate_last_trx_flag,
             rev_rec_application,
             document_type_id,
             document_creation_date,
             doc_line_id_int_1,
             doc_line_id_int_2,
             doc_line_id_int_3,
             doc_line_id_int_4,
             doc_line_id_int_5,
             doc_line_id_char_1,
             doc_line_id_char_2,
             doc_line_id_char_3,
             doc_line_id_char_4,
             doc_line_id_char_5)
          values
            (Inv_tab_ship.interface_line_id,
             Inv_tab_ship.interface_line_context,
             Inv_tab_ship.interface_line_attribute1,
             Inv_tab_ship.interface_line_attribute2,
             Inv_tab_ship.interface_line_attribute3,
             Inv_tab_ship.interface_line_attribute4,
             Inv_tab_ship.interface_line_attribute5,
             Inv_tab_ship.interface_line_attribute6,
             Inv_tab_ship.interface_line_attribute7,
             Inv_tab_ship.interface_line_attribute8,
             Inv_tab_ship.batch_source_name,
             Inv_tab_ship.set_of_books_id,
             Inv_tab_ship.line_type,
             Inv_tab_ship.description,
             Inv_tab_ship.currency_code,
             Inv_tab_ship.amount,
             Inv_tab_ship.cust_trx_type_name,
             Inv_tab_ship.cust_trx_type_id,
             Inv_tab_ship.term_name,
             Inv_tab_ship.term_id,
             Inv_tab_ship.orig_system_batch_name,
             Inv_tab_ship.orig_system_bill_customer_ref,
             Inv_tab_ship.orig_system_bill_customer_id,
             Inv_tab_ship.orig_system_bill_address_ref,
             Inv_tab_ship.orig_system_bill_address_id,
             Inv_tab_ship.orig_system_bill_contact_ref,
             Inv_tab_ship.orig_system_bill_contact_id,
             Inv_tab_ship.orig_system_ship_customer_ref,
             Inv_tab_ship.orig_system_ship_customer_id,
             Inv_tab_ship.orig_system_ship_address_ref,
             Inv_tab_ship.orig_system_ship_address_id,
             Inv_tab_ship.orig_system_ship_contact_ref,
             Inv_tab_ship.orig_system_ship_contact_id,
             Inv_tab_ship.orig_system_sold_customer_ref,
             Inv_tab_ship.orig_system_sold_customer_id,
             Inv_tab_ship.link_to_line_id,
             Inv_tab_ship.link_to_line_context,
             Inv_tab_ship.link_to_line_attribute1,
             Inv_tab_ship.link_to_line_attribute2,
             Inv_tab_ship.link_to_line_attribute3,
             Inv_tab_ship.link_to_line_attribute4,
             Inv_tab_ship.link_to_line_attribute5,
             Inv_tab_ship.link_to_line_attribute6,
             Inv_tab_ship.link_to_line_attribute7,
             Inv_tab_ship.receipt_method_name,
             Inv_tab_ship.receipt_method_id,
             Inv_tab_ship.conversion_type,
             Inv_tab_ship.conversion_date,
             Inv_tab_ship.conversion_rate,
             Inv_tab_ship.customer_trx_id,
             Inv_tab_ship.trx_date,
             Inv_tab_ship.gl_date,
             Inv_tab_ship.document_number,
             Inv_tab_ship.trx_number,
             Inv_tab_ship.line_number,
             Inv_tab_ship.quantity,
             Inv_tab_ship.quantity_ordered,
             Inv_tab_ship.unit_selling_price,
             Inv_tab_ship.unit_standard_price,
             Inv_tab_ship.printing_option,
             Inv_tab_ship.interface_status,
             Inv_tab_ship.request_id,
             Inv_tab_ship.related_batch_source_name,
             Inv_tab_ship.related_trx_number,
             Inv_tab_ship.related_customer_trx_id,
             Inv_tab_ship.previous_customer_trx_id,
             Inv_tab_ship.credit_method_for_acct_rule,
             Inv_tab_ship.credit_method_for_installments,
             Inv_tab_ship.reason_code,
             Inv_tab_ship.tax_rate,
             Inv_tab_ship.tax_code,
             Inv_tab_ship.tax_precedence,
             Inv_tab_ship.exception_id,
             Inv_tab_ship.exemption_id,
             Inv_tab_ship.ship_date_actual,
             Inv_tab_ship.fob_point,
             Inv_tab_ship.ship_via,
             Inv_tab_ship.waybill_number,
             Inv_tab_ship.invoicing_rule_name,
             Inv_tab_ship.invoicing_rule_id,
             Inv_tab_ship.accounting_rule_name,
             Inv_tab_ship.accounting_rule_id,
             Inv_tab_ship.accounting_rule_duration,
             Inv_tab_ship.rule_start_date,
             Inv_tab_ship.primary_salesrep_number,
             Inv_tab_ship.primary_salesrep_id,
             Inv_tab_ship.sales_order,
             Inv_tab_ship.sales_order_line,
             Inv_tab_ship.sales_order_date,
             Inv_tab_ship.sales_order_source,
             Inv_tab_ship.sales_order_revision,
             Inv_tab_ship.purchase_order,
             Inv_tab_ship.purchase_order_revision,
             Inv_tab_ship.purchase_order_date,
             Inv_tab_ship.agreement_name,
             Inv_tab_ship.agreement_id,
             Inv_tab_ship.memo_line_name,
             Inv_tab_ship.memo_line_id,
             Inv_tab_ship.inventory_item_id,
             Inv_tab_ship.mtl_system_items_seg1,
             Inv_tab_ship.mtl_system_items_seg2,
             Inv_tab_ship.mtl_system_items_seg3,
             Inv_tab_ship.mtl_system_items_seg4,
             Inv_tab_ship.mtl_system_items_seg5,
             Inv_tab_ship.mtl_system_items_seg6,
             Inv_tab_ship.mtl_system_items_seg7,
             Inv_tab_ship.mtl_system_items_seg8,
             Inv_tab_ship.mtl_system_items_seg9,
             Inv_tab_ship.mtl_system_items_seg10,
             Inv_tab_ship.mtl_system_items_seg11,
             Inv_tab_ship.mtl_system_items_seg12,
             Inv_tab_ship.mtl_system_items_seg13,
             Inv_tab_ship.mtl_system_items_seg14,
             Inv_tab_ship.mtl_system_items_seg15,
             Inv_tab_ship.mtl_system_items_seg16,
             Inv_tab_ship.mtl_system_items_seg17,
             Inv_tab_ship.mtl_system_items_seg18,
             Inv_tab_ship.mtl_system_items_seg19,
             Inv_tab_ship.mtl_system_items_seg20,
             Inv_tab_ship.reference_line_id,
             Inv_tab_ship.reference_line_context,
             Inv_tab_ship.reference_line_attribute1,
             Inv_tab_ship.reference_line_attribute2,
             Inv_tab_ship.reference_line_attribute3,
             Inv_tab_ship.reference_line_attribute4,
             Inv_tab_ship.reference_line_attribute5,
             Inv_tab_ship.reference_line_attribute6,
             Inv_tab_ship.reference_line_attribute7,
             Inv_tab_ship.territory_id,
             Inv_tab_ship.territory_segment1,
             Inv_tab_ship.territory_segment2,
             Inv_tab_ship.territory_segment3,
             Inv_tab_ship.territory_segment4,
             Inv_tab_ship.territory_segment5,
             Inv_tab_ship.territory_segment6,
             Inv_tab_ship.territory_segment7,
             Inv_tab_ship.territory_segment8,
             Inv_tab_ship.territory_segment9,
             Inv_tab_ship.territory_segment10,
             Inv_tab_ship.territory_segment11,
             Inv_tab_ship.territory_segment12,
             Inv_tab_ship.territory_segment13,
             Inv_tab_ship.territory_segment14,
             Inv_tab_ship.territory_segment15,
             Inv_tab_ship.territory_segment16,
             Inv_tab_ship.territory_segment17,
             Inv_tab_ship.territory_segment18,
             Inv_tab_ship.territory_segment19,
             Inv_tab_ship.territory_segment20,
             Inv_tab_ship.attribute_category,
             Inv_tab_ship.attribute1,
             Inv_tab_ship.attribute2,
             Inv_tab_ship.attribute3,
             Inv_tab_ship.attribute4,
             Inv_tab_ship.attribute5,
             Inv_tab_ship.attribute6,
             Inv_tab_ship.attribute7,
             Inv_tab_ship.attribute8,
             Inv_tab_ship.attribute9,
             Inv_tab_ship.attribute10,
             Inv_tab_ship.attribute11,
             Inv_tab_ship.attribute12,
             Inv_tab_ship.attribute13,
             Inv_tab_ship.attribute14,
             Inv_tab_ship.attribute15,
             Inv_tab_ship.header_attribute_category,
             Inv_tab_ship.header_attribute1,
             Inv_tab_ship.header_attribute2,
             Inv_tab_ship.header_attribute3,
             Inv_tab_ship.header_attribute4,
             Inv_tab_ship.header_attribute5,
             Inv_tab_ship.header_attribute6,
             Inv_tab_ship.header_attribute7,
             Inv_tab_ship.header_attribute8,
             Inv_tab_ship.header_attribute9,
             Inv_tab_ship.header_attribute10,
             Inv_tab_ship.header_attribute11,
             Inv_tab_ship.header_attribute12,
             Inv_tab_ship.header_attribute13,
             Inv_tab_ship.header_attribute14,
             Inv_tab_ship.header_attribute15,
             Inv_tab_ship.comments,
             Inv_tab_ship.internal_notes,
             Inv_tab_ship.initial_customer_trx_id,
             Inv_tab_ship.ussgl_transaction_code_context,
             Inv_tab_ship.ussgl_transaction_code,
             Inv_tab_ship.acctd_amount,
             Inv_tab_ship.customer_bank_account_id,
             Inv_tab_ship.customer_bank_account_name,
             Inv_tab_ship.uom_code,
             Inv_tab_ship.uom_name,
             Inv_tab_ship.document_number_sequence_id,
             Inv_tab_ship.link_to_line_attribute10,
             Inv_tab_ship.link_to_line_attribute11,
             Inv_tab_ship.link_to_line_attribute12,
             Inv_tab_ship.link_to_line_attribute13,
             Inv_tab_ship.link_to_line_attribute14,
             Inv_tab_ship.link_to_line_attribute15,
             Inv_tab_ship.link_to_line_attribute8,
             Inv_tab_ship.link_to_line_attribute9,
             Inv_tab_ship.reference_line_attribute10,
             Inv_tab_ship.reference_line_attribute11,
             Inv_tab_ship.reference_line_attribute12,
             Inv_tab_ship.reference_line_attribute13,
             Inv_tab_ship.reference_line_attribute14,
             Inv_tab_ship.reference_line_attribute15,
             Inv_tab_ship.reference_line_attribute8,
             Inv_tab_ship.reference_line_attribute9,
             Inv_tab_ship.interface_line_attribute10,
             Inv_tab_ship.interface_line_attribute11,
             Inv_tab_ship.interface_line_attribute12,
             Inv_tab_ship.interface_line_attribute13,
             Inv_tab_ship.interface_line_attribute14,
             Inv_tab_ship.interface_line_attribute15,
             Inv_tab_ship.interface_line_attribute9,
             Inv_tab_ship.vat_tax_id,
             Inv_tab_ship.reason_code_meaning,
             Inv_tab_ship.last_period_to_credit,
             Inv_tab_ship.paying_customer_id,
             Inv_tab_ship.paying_site_use_id,
             Inv_tab_ship.tax_exempt_flag,
             Inv_tab_ship.tax_exempt_reason_code,
             Inv_tab_ship.tax_exempt_reason_code_meaning,
             Inv_tab_ship.tax_exempt_number,
             Inv_tab_ship.sales_tax_id,
             Inv_tab_ship.created_by,
             Inv_tab_ship.creation_date,
             Inv_tab_ship.last_updated_by,
             Inv_tab_ship.last_update_date,
             Inv_tab_ship.last_update_login,
             Inv_tab_ship.location_segment_id,
             Inv_tab_ship.movement_id,
             Inv_tab_ship.org_id,
             Inv_tab_ship.amount_includes_tax_flag,
             Inv_tab_ship.header_gdf_attr_category,
             Inv_tab_ship.header_gdf_attribute1,
             Inv_tab_ship.header_gdf_attribute2,
             Inv_tab_ship.header_gdf_attribute3,
             Inv_tab_ship.header_gdf_attribute4,
             Inv_tab_ship.header_gdf_attribute5,
             Inv_tab_ship.header_gdf_attribute6,
             Inv_tab_ship.header_gdf_attribute7,
             Inv_tab_ship.header_gdf_attribute8,
             Inv_tab_ship.header_gdf_attribute9,
             Inv_tab_ship.header_gdf_attribute10,
             Inv_tab_ship.header_gdf_attribute11,
             Inv_tab_ship.header_gdf_attribute12,
             Inv_tab_ship.header_gdf_attribute13,
             Inv_tab_ship.header_gdf_attribute14,
             Inv_tab_ship.header_gdf_attribute15,
             Inv_tab_ship.header_gdf_attribute16,
             Inv_tab_ship.header_gdf_attribute17,
             Inv_tab_ship.header_gdf_attribute18,
             Inv_tab_ship.header_gdf_attribute19,
             Inv_tab_ship.header_gdf_attribute20,
             Inv_tab_ship.header_gdf_attribute21,
             Inv_tab_ship.header_gdf_attribute22,
             Inv_tab_ship.header_gdf_attribute23,
             Inv_tab_ship.header_gdf_attribute24,
             Inv_tab_ship.header_gdf_attribute25,
             Inv_tab_ship.header_gdf_attribute26,
             Inv_tab_ship.header_gdf_attribute27,
             Inv_tab_ship.header_gdf_attribute28,
             Inv_tab_ship.header_gdf_attribute29,
             Inv_tab_ship.header_gdf_attribute30,
             Inv_tab_ship.line_gdf_attr_category,
             Inv_tab_ship.line_gdf_attribute1,
             Inv_tab_ship.line_gdf_attribute2,
             Inv_tab_ship.line_gdf_attribute3,
             Inv_tab_ship.line_gdf_attribute4,
             Inv_tab_ship.line_gdf_attribute5,
             Inv_tab_ship.line_gdf_attribute6,
             Inv_tab_ship.line_gdf_attribute7,
             Inv_tab_ship.line_gdf_attribute8,
             Inv_tab_ship.line_gdf_attribute9,
             Inv_tab_ship.line_gdf_attribute10,
             Inv_tab_ship.line_gdf_attribute11,
             Inv_tab_ship.line_gdf_attribute12,
             Inv_tab_ship.line_gdf_attribute13,
             Inv_tab_ship.line_gdf_attribute14,
             Inv_tab_ship.line_gdf_attribute15,
             Inv_tab_ship.line_gdf_attribute16,
             Inv_tab_ship.line_gdf_attribute17,
             Inv_tab_ship.line_gdf_attribute18,
             Inv_tab_ship.line_gdf_attribute19,
             Inv_tab_ship.line_gdf_attribute20,
             Inv_tab_ship.reset_trx_date_flag,
             Inv_tab_ship.payment_server_order_num,
             Inv_tab_ship.approval_code,
             Inv_tab_ship.address_verification_code,
             Inv_tab_ship.warehouse_id,
             Inv_tab_ship.translated_description,
             Inv_tab_ship.cons_billing_number,
             Inv_tab_ship.promised_commitment_amount,
             Inv_tab_ship.payment_set_id,
             Inv_tab_ship.original_gl_date,
             Inv_tab_ship.contract_line_id,
             Inv_tab_ship.contract_id,
             Inv_tab_ship.source_data_key1,
             Inv_tab_ship.source_data_key2,
             Inv_tab_ship.source_data_key3,
             Inv_tab_ship.source_data_key4,
             Inv_tab_ship.source_data_key5,
             Inv_tab_ship.invoiced_line_acctg_level,
             Inv_tab_ship.override_auto_accounting_flag,
             Inv_tab_ship.source_application_id,
             Inv_tab_ship.source_event_class_code,
             Inv_tab_ship.source_entity_code,
             Inv_tab_ship.source_trx_id,
             Inv_tab_ship.source_trx_line_id,
             Inv_tab_ship.source_trx_line_type,
             Inv_tab_ship.source_trx_detail_tax_line_id,
             Inv_tab_ship.historical_flag,
             Inv_tab_ship.tax_regime_code,
             Inv_tab_ship.tax,
             Inv_tab_ship.tax_status_code,
             Inv_tab_ship.tax_rate_code,
             Inv_tab_ship.tax_jurisdiction_code,
             Inv_tab_ship.taxable_amount,
             Inv_tab_ship.taxable_flag,
             Inv_tab_ship.legal_entity_id,
             Inv_tab_ship.parent_line_id,
             Inv_tab_ship.deferral_exclusion_flag,
             Inv_tab_ship.payment_trxn_extension_id,
             Inv_tab_ship.rule_end_date,
             Inv_tab_ship.payment_attributes,
             Inv_tab_ship.application_id,
             Inv_tab_ship.billing_date,
             Inv_tab_ship.trx_business_category,
             Inv_tab_ship.product_fisc_classification,
             Inv_tab_ship.product_category,
             Inv_tab_ship.product_type,
             Inv_tab_ship.line_intended_use,
             Inv_tab_ship.assessable_value,
             Inv_tab_ship.user_defined_fisc_class,
             Inv_tab_ship.taxed_upstream_flag,
             Inv_tab_ship.document_sub_type,
             Inv_tab_ship.default_taxation_country,
             Inv_tab_ship.tax_invoice_date,
             Inv_tab_ship.tax_invoice_number,
             Inv_tab_ship.payment_type_code,
             Inv_tab_ship.mandate_last_trx_flag,
             Inv_tab_ship.rev_rec_application,
             Inv_tab_ship.document_type_id,
             Inv_tab_ship.document_creation_date,
             Inv_tab_ship.doc_line_id_int_1,
             Inv_tab_ship.doc_line_id_int_2,
             Inv_tab_ship.doc_line_id_int_3,
             Inv_tab_ship.doc_line_id_int_4,
             Inv_tab_ship.doc_line_id_int_5,
             Inv_tab_ship.doc_line_id_char_1,
             Inv_tab_ship.doc_line_id_char_2,
             Inv_tab_ship.doc_line_id_char_3,
             Inv_tab_ship.doc_line_id_char_4,
             Inv_tab_ship.doc_line_id_char_5);

          if Inv_tab_ship.interface_line_context <> 'INTERCOMPANY' then
            update ra_interface_lines_all ril
               set ril.request_id = -999
             where rowid = Inv_tab_ship.rowid;
          Else
            update ra_interface_lines_all ril
               set ril.request_id = -998
             where rowid = Inv_tab_ship.rowid;
          end if;

        Exception
          When Others Then
            l_rec_err_msg        := l_rec_err_msg || sqlerrm;
            l_continue_next_step := FALSE;
        End;
      End If;

      If l_continue_next_step = FALSE THEN
         p_bool := fnd_concurrent.set_completion_status('ERROR',
                                                         'See error log for failing list ');
        l_inv_err_tab(l_index).SECOND_AR_INV_CREATED := 'No';
        l_inv_err_tab(l_index).ERROR_MSG := l_inv_err_tab(l_index)
                                            .ERROR_MSG || l_rec_err_msg;
      Else
        l_inv_err_tab(l_index).SECOND_AR_INV_CREATED := 'Yes';
      End If;

    --commit;
    end loop;
    -- Write the Concurrent Log with Processed Record Status
    write_Program_Log(l_inv_err_tab, 'AR');
    commit;
    --- Trigger AP Concurrent Program
   /* l_request_id := FND_REQUEST.SUBMIT_REQUEST(application => 'XXOBJT',
                                               program     => 'XXARICAPINV',
                                               description => 'XX AP I/C Payables Invoices',
                                               start_time  => SYSDATE,
                                               sub_request => NULL);*/
    Commit;
    write_log_message('XX AR I/C Payables Invoices Program Submitted , Request Id :' ||
                      l_request_id);
    retcode := '0';
    write_log_message('xxar_ic_invoice_pkg.repalce_ar_invoice Package Execution Complete.');
  Exception
    When Others Then
      errbuf := 'Program Exited with Error : ' || sqlerrm ||
                '.All Sucessfull Records are rolled back.';
      write_log_message(errbuf);
      retcode := '2';
      Rollback;
      -- Write the Concurrent Log with Processed Record Status
      write_Program_Log(l_inv_err_tab, 'AR', errbuf);
  end repalce_ar_invoice;

  -- *************************************************************************************
  -- PROCEDURE : repalce_ap_inv
  --
  -- Purpose:
  --
  -- Revision History
  -- Version   Date            Performer          Comments
  --**************************************************************************************
  --   1.0     04/07/2017      Ofer Suad          CHG0040750  - Initial Build
  --
  -- *************************************************************************************
  Procedure repalce_ap_invoice(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) is
    cursor c_headers is
      SELECT distinct rt.trx_number,
                      rt.customer_trx_id,
                      rt.org_id,
                      ril.interface_line_attribute4,
                       ril.org_id orig_org_id
        FROM ra_interface_lines_all    ril,
             ra_customer_trx_lines_all rtl,
             ra_customer_trx_all       rt
       where ril.interface_line_context = 'INTERCOMPANY'
         and ril.request_id = -998
         and ril.interface_line_attribute6 = rtl.interface_line_attribute6
         and ril.org_id <> rtl.org_id
         and rt.customer_trx_id = rtl.customer_trx_id
       order by rt.trx_number;

    cursor c_lines(l_Trx_Number varchar2, l_org_id number) is
      SELECT ril.rowid, ril.*
        FROM ra_interface_lines_all    ril,
             ra_customer_trx_lines_all rtl,
             ra_customer_trx_all       rt
       where ril.request_id = -998
         and ril.interface_line_attribute6 = rtl.interface_line_attribute6
         and ril.org_id <> rtl.org_id
         and rt.customer_trx_id = rtl.customer_trx_id
         and rt.trx_number = l_Trx_Number
         and rt.org_id = l_org_id;

    indx                number;
    l_cost_account       number;
    l_cost_account_id       number;
    l_invoice_id        number;
    l_amount            number;
    l_vendor_id         number;
    l_vendor_site_id    number;
    l_inv_currency_code po_vendor_sites_all.INVOICE_CURRENCY_CODE%type;
    l_gl_date           date;
    l_inv_err_rec       IC_INV_ERR_DTL_REC;
    l_inv_err_tab       IC_INV_ERR_DTL_TBL;

    l_continue_next_step BOOLEAN;
    l_rec_err_msg        VARCHAR2(4000);
    l_index              NUMBER := 0;
    ex_ap_accrual_account Exception;
    l_flex_seg        fnd_flex_ext.segmentarray;
    l_ok              BOOLEAN;
    l_chart_of_acc_id NUMBER;
    l_app_short_name  fnd_application.application_short_name%TYPE;
    num_segments      INTEGER;
    l_ic_seg_num         NUMBER;
    l_seg_delimiter     VARCHAR2(1) := NULL;
    l_conc_seg gl_code_combinationsle_kfv.concatenated_segments%type;
    x_return_code        VARCHAR2(250);
    x_err_msg            VARCHAR2(250);
     p_bool               boolean;

  begin
    write_log_message('xxar_ic_invoice_pkg.repalce_ap_invoice Package Execution Start.');

    for l_head in c_headers loop
      indx                 := 0;
      l_amount             := 0;
      l_continue_next_step := TRUE;
      l_rec_err_msg        := NULL;
      l_inv_err_rec        := NULL;
      l_index              := l_index + 1;
      --Assign the Record Deatils to Error Record
      ------------------------------------------------------------------------
      l_inv_err_rec.INTERFACE_LINE_ATTRIBUTE4 := l_head.INTERFACE_LINE_ATTRIBUTE4;
      l_inv_err_rec.customer_trx_id           := l_head.customer_trx_id;
      l_inv_err_rec.org_id                    := l_head.org_id;
      l_inv_err_rec.trx_number                := l_head.trx_number;
      Begin
        select gl_date
          into l_gl_date
          from ra_cust_trx_line_gl_dist_all gd
         where gd.customer_trx_id = l_head.customer_trx_id -- Cur Param
           AND gd.account_class = 'REC';
      Exception
        When Others Then
          l_rec_err_msg        := 'Error In Getting GL Date for customer_trx_id  :' ||
                                  l_head.customer_trx_id;
          l_continue_next_step := FALSE;
      End;

      -- Need to add exception here  too many rows and no data found
      If l_continue_next_step = TRUE Then
        Begin
          SELECT mpv.VENDOR_ID, mpv.VENDOR_SITE_ID, INVOICE_CURRENCY_CODE
            into l_VENDOR_ID, l_VENDOR_SITE_ID, l_inv_currency_code
            FROM MTL_INTERCOMPANY_PARAMETERS_V mpv, po_vendor_sites_all pvs
           where mpv.SELL_ORGANIZATION_ID =
                 l_head.interface_line_attribute4
             and mpv.SHIP_ORGANIZATION_ID = l_head.org_id
             and pvs.VENDOR_SITE_ID = mpv.VENDOR_SITE_ID;
        Exception
          When NO_DATA_FOUND Then
            l_rec_err_msg := 'Vendor Information not found.';
          When TOO_MANY_ROWS Then
            l_rec_err_msg := 'Multiple Vendor Information not found.';
          When Others Then
            l_rec_err_msg := sqlerrm;
        End;
      End If;

      If l_rec_err_msg is not Null Then
        l_continue_next_step := FALSE;
      End If;

      If l_continue_next_step = TRUE Then
        Begin
          FOR Inv_tab_ship IN c_lines(l_head.trx_number, l_head.org_id) LOOP

            indx := indx + 1;
            if indx = 1 then
              select ap_invoices_interface_s.nextval
                into l_invoice_id
                from dual;
            end if;

            Begin
              SELECT mp.ap_accrual_account
                into l_cost_account
                FROM mtl_material_transactions mmt, MTL_PARAMETERS mp
               where transaction_id =
                     Inv_tab_ship.interface_line_attribute7
                 and mp.organization_id = mmt.transfer_organization_id;

              select gcc.chart_of_accounts_id
                into l_chart_of_acc_id
                from gl_code_combinations gcc
               where gcc.code_combination_id = l_cost_account;

              SELECT fap.application_short_name,concatenated_segment_delimiter
                INTO l_app_short_name,l_seg_delimiter
                FROM fnd_application        fap,
                     fnd_id_flexs           fif,
                     fnd_id_flex_structures fifs
               WHERE fif.application_id = fap.application_id
                 AND fif.id_flex_code = 'GL#'
                 AND fifs.application_id = fif.application_id
                 AND fifs.id_flex_code = fif.id_flex_code
                 AND fifs.id_flex_num = l_chart_of_acc_id;

              l_ok := fnd_flex_ext.get_segments(l_app_short_name,
                                                'GL#',
                                                l_chart_of_acc_id,
                                                l_cost_account,
                                                num_segments,
                                                l_flex_seg);


             SELECT fif.segment_num
    INTO   l_ic_seg_num
    FROM   fnd_id_flex_segments_vl fif
    WHERE  fif.application_id = 101
    AND    fif.id_flex_num = l_chart_of_acc_id
    AND    fif.id_flex_code = 'GL#'
    AND    upper(fif.segment_name) = 'INTERCOMPANY';


    sELECT CONSTANT
      INTO   l_flex_seg(l_ic_seg_num)
      FROM    ra_account_defaults_all     rad,
   ra_account_default_segments rads
      WHERE  rad.gl_default_id = rads.gl_default_id
      AND    rad.org_id = l_head.orig_org_id
      AND    TYPE = 'REV'
      AND    segment_num = 1;

      l_conc_seg:=l_seg_delimiter;
       for i in 1..num_segments-1 loop
         l_conc_seg:=l_conc_seg||l_flex_seg(i)||l_seg_delimiter;

       end loop;
       l_conc_seg:=l_conc_seg||l_flex_seg(num_segments) ;

        write_log_message('l_conc_seg '||l_conc_seg);

       select gcc.code_combination_id
       into l_cost_account_id
       from  gl_code_combinationsle_kfv gcc

       where   concatenated_segments=  l_conc_seg;

       write_log_message('l_cost_account_id '||l_cost_account_id);

            Exception
              When Others Then
                l_rec_err_msg := l_rec_err_msg ||
                                 ' Exception During getting of ap_accrual_account.';
                Raise ex_ap_accrual_account;
            End;


            insert into ap_invoice_lines_interface
              (invoice_id, --
               invoice_line_id, --
               line_type_lookup_code, --
               amount, --
               accounting_date, --
               item_description, --
               dist_code_combination_id, --
               last_updated_by, --
               last_update_date, --
               created_by, --
               creation_date, --
               org_id, --
               reference_1, --
               source_application_id, --
               source_entity_code, --
               source_event_class_code)
            values
              (l_invoice_id,
               ap_invoice_lines_interface_s.nextval,
               'ITEM',
               Inv_tab_ship.amount,
               sysdate,
               Inv_tab_ship.description,
               l_cost_account_id,
               fnd_global.USER_ID,
               sysdate,
               fnd_global.USER_ID,
               sysdate,
               Inv_tab_ship.interface_line_attribute4,
               Inv_tab_ship.interface_line_attribute1,
               222,
               'TRANSACTIONS',
               'INTERCOMPANY_TRX');

            l_amount := l_amount + Inv_tab_ship.amount;

            update ra_interface_lines_all ril
               set ril.request_id = -999
             where rowid = Inv_tab_ship.rowid;

          End Loop;

          ------------------------------------------------

          insert into ap_invoices_interface
            (invoice_id, --
             invoice_num, --
             invoice_date, --
             vendor_id,
             vendor_site_id,
             invoice_amount,
             invoice_currency_code,
             --exchange_rate_type,
             --exchange_date,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             source,
             gl_date,
             --accts_pay_code_combination_id,
             org_id)
          values
            (l_invoice_id,
             l_head.trx_number || '-' || l_head.org_id,
             sysdate,
             l_vendor_id,
             l_vendor_site_id,
             l_amount,
             l_inv_currency_code,
             sysdate,
             fnd_global.USER_ID,
             sysdate,
             fnd_global.USER_ID,
             'Intercompany',
             l_gl_date,
             l_head.interface_line_attribute4

             );
          --  end if;
          --Commit;
          l_inv_err_rec.AP_INV_CREATED := 'Yes';
        Exception
          When Others Then
            l_inv_err_rec.AP_INV_CREATED := 'No';
        End;
        l_inv_err_rec.ERROR_MSG := l_rec_err_msg;
        l_inv_err_tab(l_index) := l_inv_err_rec;
      End If;
    end loop;

    write_Program_Log(l_inv_err_tab, 'AP');

    commit;
    retcode := '0';
    write_log_message('xxar_ic_invoice_pkg.repalce_ap_invoice Package Execution Complete.');
  Exception
    When Others Then
       p_bool := fnd_concurrent.set_completion_status('ERROR',
                                                         'See error log for failing list ');
      errbuf := 'Program Exited with Error : ' || sqlerrm ||
                '.All Sucessfull Records are rolled back.';
      write_log_message(errbuf);
      retcode := '2';
      Rollback;
      -- Write the Concurrent Log with Processed Record Status
      write_Program_Log(l_inv_err_tab, 'AP', errbuf);
  end repalce_ap_invoice;

end xxar_ic_invoice_pkg;
/
