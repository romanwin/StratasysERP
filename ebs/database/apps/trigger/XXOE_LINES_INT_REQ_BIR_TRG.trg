CREATE OR REPLACE TRIGGER XXOE_LINES_INT_REQ_BIR_TRG
   ---------------------------------------------------------------------------
   -- $Header: XXOE_LINES_INT_REQ_BIR_TRG 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: XXOE_LINES_INT_REQ_BIR_TRG
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: Update Oe_Order_Lines_all oe_order_headers_all.Attribute11 with 
   --              po_requisition_lines_all.Attribute4 from 
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   -- 1.0      25/00/18                  CHG0043850 - IR/ISO - Air shipments - reason (justification)
   ---------------------------------------------------------------------------
BEFORE INSERT ON OE_ORDER_LINES_ALL
  FOR EACH ROW  
 when(NEW.order_source_id = 10)
DECLARE
  CURSOR c_ir_order_type IS
    SELECT ottt.name order_type
    FROM oe_order_headers_all oh,
         oe_transaction_types_tl ottt
    where oh.header_id  = :NEW.HEADER_ID
    and   ottt.transaction_type_id = oh.order_type_id
    and   ottt.language  = USERENV('LANG')
    and   ottt.name  in ('Internal Order, IL','Internal Order, SSUS');
    
  CURSOR c_req_lines IS
    SELECT req.attribute4    
      FROM po_requisition_lines_all     req
    Where req.requisition_line_id = :new.source_document_line_id;
 
  l_IR_order_type    VARCHAR2(240) := null; 
  l_ir_attribute4    VARCHAR2(240);

BEGIN

  IF nvl(fnd_profile.VALUE('XXPO_ENABLE_INTER_REQ_PRICE'), 'N') = 'Y' THEN   
  
    OPEN c_ir_order_type;
    FETCH c_ir_order_type
      INTO l_IR_order_type;
    CLOSE c_ir_order_type;
  
    IF l_IR_order_type is not null THEN
       
      OPEN c_req_lines;
      FETCH c_req_lines
        INTO l_ir_attribute4;
      CLOSE c_req_lines;
     
      If l_ir_attribute4 is not null Then
        :NEW.ATTRIBUTE11 :=    l_ir_attribute4;    
        :NEW.CONTEXT     :=    l_IR_order_type;
      End If;
    END IF;
  END IF;

END XXOE_LINES_INT_REQ_BIR_TRG;
/
