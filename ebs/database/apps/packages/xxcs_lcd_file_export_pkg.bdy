CREATE OR REPLACE PACKAGE BODY xxcs_lcd_file_export_pkg IS

   PROCEDURE call_lcd_bpel_proc(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
   
      service_            sys.utl_dbws.service;
      call_               sys.utl_dbws.CALL;
      service_qname       sys.utl_dbws.qname;
      response            sys.xmltype;
      request             sys.xmltype;
      v_string_type_qname sys.utl_dbws.qname;
      v_error             VARCHAR2(1000);
   
   BEGIN
   
      BEGIN
         service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxCsLcdFilesExport',
                                                      'xxCsLcdFilesExport');
         v_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
                                                      'string');
         service_            := sys.utl_dbws.create_service(service_qname);
         call_               := sys.utl_dbws.create_call(service_);
         sys.utl_dbws.set_target_endpoint_address(call_,
                                                  'http://soaprodapps.2objet.com:7777/orabpel/'||xxagile_util_pkg.get_bpel_domain||'/xxCsLcdFilesExport/1.0');
      
         sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
         sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
         sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
         sys.utl_dbws.set_property(call_,
                                   'ENCODINGSTYLE_URI',
                                   'http://schemas.xmlsoap.org/soap/encoding/');
      
         sys.utl_dbws.set_return_type(call_, v_string_type_qname);
      
         -- Set the input
      
         request := sys.xmltype('<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body xmlns:ns1="http://xmlns.oracle.com/xxCsLcdFilesExport">
        <ns1:xxCsLcdFilesExportProcessRequest>
            <ns1:input></ns1:input>
        </ns1:xxCsLcdFilesExportProcessRequest>
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
   
   END call_lcd_bpel_proc;

END xxcs_lcd_file_export_pkg;
/

