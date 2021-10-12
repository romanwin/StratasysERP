create or replace package body XXOE_Cust_Rebate_Pkg is
--------------------------------------------------------------------
--  name:            XXOE_Cust_Rebate_Pkg 
--  Cust:            CUST275 - Calculate Customer Rebate
--  create by:       XXXX
--  Revision:        1.0 
--  creation date:   XX/XX/2009 2:22:33 PM
--------------------------------------------------------------------
--  purpose :        
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  XX/XX/2009  XXX               initial build
--  1.1  17/02/2010b Vitaly            add changes in logic
-------------------------------------------------------------------- 


Procedure calc_rebate (errbuf               Out Varchar2,
                       Retcode              Out Varchar2,
                       P_OrgID              In  number,
                       P_CustomerID         In  number,
                       P_FromDate           In  varchar2,
                       P_ToDate             In  varchar2,
                       P_CategSegment1      In  varchar2
                      )
Is
  v_user_id           fnd_user.user_id%type;
  v_login_id          fnd_logins.login_id%type;
  v_CategSetID        mtl_item_categories.category_set_id%type;
  v_Master_OrganID    hr_all_organization_units.organization_id%type;
  v_p_FromDate        date;
  v_p_ToDate          date;
  v_cust_Retcode      Char(1);
  v_Agree_PListID     oe_blanket_lines_all.price_list_id%type;
  v_AgreeNumber       oe_blanket_headers_all.order_number%type;
  v_cust_name         hz_parties.party_name%type;
  v_custNubmer        hz_parties.party_number%type;
  v_Gen_ListLineID    qp_list_lines.list_line_id%type;
  v_PlistName         qp_list_headers.name%type;
  v_PercentDiscount   qp_list_lines.operand%type;
  
  Cursor cr_ARInvoices (PC_OrgID in number, PC_CategSetID in number, PC_Master_OrganID in number, PC_CategSegment1 in varchar2,
                        PC_FromDate in date, PC_ToDate in date, PC_CustomerID in number)
  Is
    Select cta.sold_to_customer_id, sum(ctl.unit_selling_price * ctl.quantity_invoiced) As Total_Amount,
           sum(decode(nvl(UOM_CONVERT_TAB.conversion_rate,1),0,0,
                 ctl.quantity_invoiced/nvl(UOM_CONVERT_TAB.conversion_rate,1))) As Total_Quantity
      From ra_customer_trx_all       cta,
           ra_customer_trx_lines_all ctl,
           mtl_system_items_b        msi,
           mtl_item_categories       mic,
           mtl_categories_b          mc,
          (SELECT cc.inventory_item_id,
                  cc.from_uom_code,
                  cc.conversion_rate 
           FROM   MTL_UOM_CLASS_CONVERSIONS  cc
           WHERE  cc.to_uom_code ='KG'
           AND    cc.to_uom_class='WEIGHT')   UOM_CONVERT_TAB  --added 17-Feb-2010 by Vitaly
     Where mc.category_id = mic.category_id
       and mic.organization_id = msi.organization_id and mic.inventory_item_id = msi.inventory_item_id 
       and mic.category_set_id = PC_CategSetID
       and msi.organization_id = PC_Master_OrganID and msi.inventory_item_id = ctl.inventory_item_id
       and ctl.customer_trx_id = cta.customer_trx_id
       and (cta.sold_to_customer_id = PC_CustomerID or PC_CustomerID is null)
       and cta.org_id = PC_OrgID
       and cta.trx_date between PC_FromDate and PC_ToDate
       and mc.segment1 = PC_CategSegment1
       AND ctl.inventory_item_id=UOM_CONVERT_TAB.INVENTORY_ITEM_ID(+)
       AND ctl.uom_code         =UOM_CONVERT_TAB.FROM_UOM_CODE(+)
     Group by cta.sold_to_customer_id
    ;
   
Begin
  fnd_profile.GET('USER_ID', v_user_id);
  fnd_profile.GET('LOGIN_ID', v_login_id);
  -- Get Objet Main Category Set ID
  Begin
    Select mcs.category_set_id Into v_CategSetID
      From mtl_category_sets_tl mcs
     where mcs.category_set_name = 'Main Category Set'
       and mcs.language = userenv('LANG');
  Exception
    When others then
         Retcode := '2';
         errbuf  := 'Wrong Category Set';
  End;
  -- Get Objet Master Organization ID
  Begin
    Select ou.organization_id Into v_Master_OrganID
      From hr_all_organization_units ou
     Where ou.name = 'OMA - Objet Master (IO)';
  Exception
    When others then
         Retcode := '2';
         errbuf  := 'Wrong Master Organization ID';
  End;
         
  -- Check The Date Formats
  Begin
    Select trunc(To_Date(P_FromDate, 'YYYY/MM/DD HH24:MI:SS')) + 1 Into v_p_FromDate From Dual;
    Select trunc(To_Date(P_ToDate, 'YYYY/MM/DD HH24:MI:SS')) + 1   Into v_p_ToDate From Dual;
  Exception
    When others then
         Retcode := '2';
         errbuf  := 'Wrong Date Format';
  End;
  -- Delete Previous Running For Customer + Range
  Delete From xxobjt.xxobjt_Customer_Rebate cr   
   Where cr.org_id= P_OrgID                ----added by Vitaly 17-feb-2010
   AND  (cr.customer_id = P_CustomerID or P_CustomerID is null);
     ---and cr.calc_from_date = v_p_FromDate and cr.calc_to_date = v_p_ToDate; --closed by Vitaly 17-feb-2010

  -- Main Cursor Loop
  If nvl(Retcode, '0') != '2' then
    For ArInv in cr_ARInvoices (P_OrgID, v_CategSetID, v_Master_OrganID, P_CategSegment1, 
                                v_p_FromDate, v_p_ToDate, P_CustomerID) Loop
        v_cust_Retcode := '0';
        -- Get Customer Name & Number
        Begin
          Select hp.party_number, hp.party_name
            Into v_custNubmer, v_cust_name
            From hz_cust_accounts ca, hz_parties hp
           Where hp.party_id = ca.party_id
             and ca.cust_account_id = ArInv.Sold_To_Customer_Id;
        Exception
          When others then
           v_cust_Retcode := '2';
           fnd_file.put_line (fnd_file.log, 'Wrong Party For ID '||ArInv.Sold_To_Customer_Id);
        End;
        -- Get Price List From Agreement
        Begin
          Select bl.price_list_id, bh.order_number
            Into v_Agree_PListID, v_AgreeNumber
            From oe_blanket_headers_all bh,
                 oe_blanket_headers_ext be,
                 oe_blanket_lines_all   bl
           Where be.order_number = bh.order_number
             and bl.header_id = bh.header_id
             and bl.item_identifier_type = 'ALL'
             and bh.order_category_code = 'ORDER'
             and bh.sold_to_org_id = ArInv.Sold_To_Customer_Id
             and sysdate between be.start_date_active and be.end_date_active;
        Exception
          When too_many_rows then
           v_cust_Retcode := '2';
           fnd_file.put_line (fnd_file.log, 'More than 1 Line Agreement Is Active For Customer '||v_cust_name);
          When no_data_found then
           v_cust_Retcode := '1';
           fnd_file.put_line (fnd_file.log, 'No Active Line Agreement For Customer '||v_cust_name);
        End;
        If v_cust_Retcode = '0' then
          -- Get The "All Items" List Line, For Viewing Price Breaks
          Begin
            Select qpl.list_line_id, qph.NAME
              Into v_Gen_ListLineID, v_PlistName
              From qp_list_headers_all qph,
                   qp_list_lines_v       qpl
             Where qpl.list_header_id = qph.list_header_id
               and qpl.product_attribute_context = 'ITEM'
               and qpl.product_attribute = 'PRICING_ATTRIBUTE3'
               and qpl.product_attr_value = 'ALL'
               and qph.list_header_id = v_Agree_PListID;
          Exception
            When too_many_rows then
             v_cust_Retcode := '2';
             fnd_file.put_line (fnd_file.log, 'More than 1 Line General Price List Line For Agreement '||v_AgreeNumber);
            When no_data_found then
             v_cust_Retcode := '2';
             fnd_file.put_line (fnd_file.log, 'No General Price List Line For Agreement '||v_AgreeNumber);
          End;
          -- Get The Price Breaks
          If v_cust_Retcode = '0' then
            Begin
              Select qpl.operand Into v_PercentDiscount
                From qp_price_breaks_v  qpl
               where qpl.product_attribute_context = 'ITEM'
                 and qpl.product_attribute = 'PRICING_ATTRIBUTE3'
                 and qpl.product_attr_value = 'ALL'
                 and (qpl.pricing_attribute = 'PRICING_ATTRIBUTE7' and  ArInv.Total_Amount between qpl.pricing_attr_value_from and qpl.pricing_attr_value_to -- For Sales Agreement Line Amount
                      OR
                      qpl.pricing_attribute = 'PRICING_ATTRIBUTE8' and ArInv.Total_Quantity between qpl.pricing_attr_value_from and qpl.pricing_attr_value_to -- For Sales Agreement Line Quantity
                 )
                and parent_list_line_id = v_Gen_ListLineID;
            Exception
              When too_many_rows then
               v_cust_Retcode := '2';
               fnd_file.put_line (fnd_file.log, 'More than 1 Price Break Found For Price List '||v_PlistName||', Amount '||ArInv.Total_Amount||', Quantity '||ArInv.Total_Quantity);
              When no_data_found then
               v_cust_Retcode := '2';
               fnd_file.put_line (fnd_file.log, 'No Price Break Found For Price List '||v_PlistName||', Amount '||ArInv.Total_Amount||', Quantity '||ArInv.Total_Quantity);
            End;
            If v_cust_Retcode = '0' then
               Insert into xxobjt.xxobjt_Customer_Rebate
               (org_id, customer_id, customer_number, customer_name, total_period_amount, total_period_quantity, agreement, discount_percentage, 
                calc_from_date, calc_to_date, calculation_date, 
                creation_date, created_by, last_update_date, last_updated_by, last_update_login)
               Values
               (P_OrgID, ArInv.sold_to_customer_id, v_custNubmer, v_cust_name, ArInv.Total_Amount, ArInv.Total_Quantity, v_AgreeNumber, v_PercentDiscount,
                v_p_FromDate, v_p_ToDate, sysdate,
                sysdate, v_user_id, sysdate, v_user_id, v_login_id);
            End if;
         End if; -- Of Price Break
        End if; -- Of General Price List ID
        If v_cust_Retcode = '2' then
           Retcode := '2';
        End if;
    End loop;
  End if;
End calc_rebate;

end XXOE_Cust_Rebate_Pkg;
/

