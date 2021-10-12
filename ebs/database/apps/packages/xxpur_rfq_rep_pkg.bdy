create or replace package body XXPUR_RFQ_REP_PKG is

  Procedure PRINT_RFQ(errbuf           out varchar2,
                      retcode          out number,
                      P_report_type    in varchar2,
                      P_agent_name_num in number,
                      P_rfq_num_from   in number,
                      P_rfq_num_to     in number,
                      P_test_flag      in varchar2,
                      P_sortby         in varchar2,
                      P_user_id        in number,
                      P_supplier       in varchar2) is
  
    v_request_id number := fnd_global.conc_request_id;
    v_result     boolean;
  
    cursor vendor_cur(v_rfq_num number) is
    
      select distinct vend.vendor_name
        from po.po_rfq_vendors pov, po_headers_all poh, po_vendors vend
       where pov.vendor_id = vend.vendor_id
         and poh.po_header_id = pov.po_header_id
         and poh.segment1 = to_char(v_rfq_num); -- 'Or Mechanics (G.M.)Ltd.';
    /*and pov.rfq_num >= 100200003  
    and pov.rfq_num <= 100200004; 
    and poh.vendor_name like P_supplier*/
  
    vendor_rec vendor_cur%rowtype;
  
  Begin
  
    For rfq_num in P_rfq_num_from .. P_rfq_num_to loop
    
      For vendor_rec in vendor_cur(to_char(rfq_num)) loop
      
        fnd_file.put_line(FND_FILE.LOG,
                          'Request Submited: ' || to_char(v_Request_id));
      
        v_result := fnd_request.add_layout('XXOBJT',
                                           'XXPO_ Request_for_Quotation',
                                           'en',
                                           'US',
                                           'PDF');
      
        v_Request_id := fnd_request.Submit_Request(application => 'XXOBJT',
                                                   program     => 'XXINVREFQU',
                                                   argument1   => P_report_type,
                                                   argument2   => P_agent_name_num,
                                                   argument3   => rfq_num,
                                                   argument4   => rfq_num,
                                                   argument5   => P_test_flag,
                                                   argument6   => P_sortby,
                                                   argument7   => P_user_id,
                                                   argument8   => vendor_rec.vendor_name);
        fnd_file.put_line(fnd_file.log, ' Submitting Request');
        commit;
        fnd_file.put_line(FND_FILE.LOG, 'submit_request: ' || v_Request_id);
      
      End loop;
    
    End loop;
  
  End PRINT_RFQ;

End XXPUR_RFQ_REP_PKG;
/

