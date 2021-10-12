CREATE OR REPLACE PACKAGE BODY xxagile_file_export_pkg IS

  PROCEDURE call_xxagile_bpel_proc(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
  
    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.call;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    v_string_type_qname sys.utl_dbws.qname;
    v_error             VARCHAR2(1000);
  
  BEGIN
  
    BEGIN
      service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/XXAgileExportFiles',
                                                   'XXAgileExportFiles');
      v_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
                                                   'string');
      service_            := sys.utl_dbws.create_service(service_qname);
      call_               := sys.utl_dbws.create_call(service_);
      sys.utl_dbws.set_target_endpoint_address(call_,
                                               'http://soaprodapps.2objet.com:7777/orabpel/' ||
                                               xxagile_util_pkg.get_bpel_domain ||
                                               '/XXAgileExportFiles/1.0');
    
      sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
      sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
      sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
      sys.utl_dbws.set_property(call_,
                                'ENCODINGSTYLE_URI',
                                'http://schemas.xmlsoap.org/soap/encoding/');
    
      sys.utl_dbws.set_return_type(call_, v_string_type_qname);
    
      -- Set the input
    
      request := sys.xmltype('<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body xmlns:ns1="http://xmlns.oracle.com/XXAgileExportFiles">
        <ns1:XXAgileExportFilesProcessRequest>
            <ns1:input></ns1:input>
        </ns1:XXAgileExportFilesProcessRequest>
    </soap:Body>
</soap:Envelope>

');
    
      response := sys.utl_dbws.invoke(call_, request);
      sys.utl_dbws.release_call(call_);
      sys.utl_dbws.release_service(service_);
      v_error := response.getstringval();
      IF response.getstringval() LIKE '%Error%' THEN
        retcode := 2;
        errbuf  := REPLACE(REPLACE(substr(v_error,
                                          instr(v_error, 'instance') + 10,
                                          length(v_error)),
                                   '</OutPut>',
                                   NULL),
                           '</processResponse>',
                           NULL);
      END IF;
      --dbms_output.put_line(response.getstringval()); 
    EXCEPTION
      WHEN OTHERS THEN
        v_error := substr(SQLERRM, 1, 250);
        retcode := '2';
        errbuf  := 'Error Run Bpel Interface: ' || v_error;
        sys.utl_dbws.release_call(call_);
        sys.utl_dbws.release_service(service_);
    END;
  
  END call_xxagile_bpel_proc;
  ---------------------------------------------------
  -- Function and procedure implementations
  --
  -- 2.4.11 yuval tal add WSI
  -- 2.5     18.08.2013  Vitaly     CR 870 std cost - change hard-coded organization 
  --------------------------------------------------

  FUNCTION get_item_onhand_qty(p_item_id NUMBER) RETURN NUMBER IS
    q_onhand NUMBER;
  BEGIN
  
    SELECT SUM(moqd.transaction_quantity)
      INTO q_onhand
      FROM mtl_onhand_quantities_detail moqd, mtl_parameters mp
     WHERE moqd.inventory_item_id = p_item_id
       AND mp.organization_id = moqd.organization_id
       AND mp.organization_code IN
           ('ISK' /*WSI*/, 'IRK' /*WRI*/, 'IPK' /*WPI*/, 'ITA'); ------('WSI', 'WRI', 'WPI');
  
    RETURN(q_onhand);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_item_onhand_qty;

  FUNCTION get_item_open_po(p_item_id NUMBER) RETURN NUMBER IS
    q_open_po NUMBER;
  BEGIN
  
    SELECT COUNT(DISTINCT ms.po_header_id)
      INTO q_open_po
      FROM mtl_supply ms
     WHERE ms.supply_type_code = 'PO'
       AND ms.item_id = p_item_id;
  
    RETURN(q_open_po);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_item_open_po;

  FUNCTION get_item_last_price(p_item_id NUMBER) RETURN NUMBER IS
    q_last_unit_price NUMBER;
  BEGIN
  
    SELECT unit_price
      INTO q_last_unit_price
      FROM (SELECT pol.unit_price, poh.currency_code
              FROM po_lines_all pol, po_headers_all poh
             WHERE poh.po_header_id = pol.po_header_id
               AND pol.item_id = p_item_id
             ORDER BY pol.creation_date DESC)
     WHERE rownum = 1;
  
    RETURN(q_last_unit_price);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_item_last_price;

  FUNCTION get_item_last_currency(p_item_id NUMBER) RETURN VARCHAR2 IS
    q_last_unit_curr VARCHAR2(20);
  BEGIN
  
    SELECT currency_code
      INTO q_last_unit_curr
      FROM (SELECT pol.unit_price, poh.currency_code
              FROM po_lines_all pol, po_headers_all poh
             WHERE poh.po_header_id = pol.po_header_id
               AND pol.item_id = p_item_id
             ORDER BY pol.creation_date DESC)
     WHERE rownum = 1;
  
    RETURN(q_last_unit_curr);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_item_last_currency;

END xxagile_file_export_pkg;
/
