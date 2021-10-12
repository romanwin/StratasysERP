CREATE OR REPLACE PACKAGE BODY xxqp_upd_price_alert_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUST527
  --  name:               xxqp_upd_price_alert_pkg
  --  create by:          Vitaly K
  --  $Revision:          1.0 $
  --  creation date:      07/11/2012
  --  Purpose :           
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/11/2012    Vitaly K        initial build
  ----------------------------------------------------------------------- 
  
  
  --------------------------------------------------------------------
  --  name:               prepare_notification_body
  --  create by:          Vitaly K
  --  $Revision:          1.0 $
  --  creation date:      07/11/2012
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the CLOB string to attach to
  --                   the mail body that send
  --  In  Params:      p_document_id   - send mail code 'P'
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date           name            desc
  --  1.0   07/11/2012    Vitaly K        initial build
  --------------------------------------------------------------------
  PROCEDURE prepare_notification_body(p_document_id   in varchar2,
                                      p_display_type  in varchar2,
                                      p_document      in out clob,
                                      p_document_type in out varchar2) is

    cursor get_summary_data is
      select nvl(sum(1),0)                          num_of_rec_processed,
             nvl(sum(decode(a.status,'S',1,0)),0)   num_of_rec_succeeded,
             nvl(sum(decode(a.status,'E',1,0)),0)   num_of_rec_error
      from   xxqp_update_price  a
      where  a.last_update_date >= to_date(p_document_id, 'ddmmyyyy hh24:mi');

    cursor get_errors_data is
      select ROW_NUMBER() OVER (PARTITION BY 'stam' ORDER BY a.item_code,a.price_list_name)  line_num,
             a.batch_id,
             a.item_code,
             a.price,
             a.price_list_name,
             a.error_message
      from   xxqp_update_price  a
      where  a.status='E' ---error
      and    a.last_update_date >= to_date(p_document_id, 'ddmmyyyy hh24:mi')
      order by a.item_code,
               a.price_list_name;



v_num_of_rec_processed      number:=0;
v_num_of_rec_succeeded      number:=0;
v_num_of_rec_error          number:=0;  

      
  begin
    
  open  get_summary_data;
  fetch get_summary_data into v_num_of_rec_processed, v_num_of_rec_succeeded, v_num_of_rec_error;
  close get_summary_data; 
  
    -- concatenate start message
    dbms_lob.append(p_document,'<HTML>'||
                               '<BODY><FONT color=blue face="Verdana">'||
                               '<P> Update Price List And BPA</P>'|| '<P> </P>' ||
                                '<P> Summary Report</P>' || '<P> </P>' ||
                                '<div align="left"><TABLE style="COLOR: blue" border=1 cellpadding=8 >' ||
                                '<TR>' || '<TH>' || ' Processed ' || '</TH>' || '<TH>' ||
                                ' Success ' || '</TH>' || '<TH>' || ' Error ' ||
                                '</TH>' || '</TR>' || '<TR align="center">' || '<TD>' ||
                                v_num_of_rec_processed || '</TD>' ||
                                '<TD><font color="green">' || v_num_of_rec_succeeded ||
                                '</font></TD>' || '<TD><font color="red">' ||
                                v_num_of_rec_error || '</font></TD>' || '</TR>' ||
                                '</TABLE> </div>');
          

                               
    if v_num_of_rec_error>0 then                               
            -- concatenate table prompts
            dbms_lob.append(p_document,
                            '<P> </P>'||
                            '<P> Errors details</P>'||
                            '<div align="left"><TABLE style="COLOR: blue" border=1 cellpadding=8>');
            dbms_lob.append(p_document, '<TR align="left">'||
                                           '<TH> N                 </TH>'||
                                           '<TH> Item              </TH>'||
                                           '<TH> Price             </TH>'||
                                           '<TH> Price List        </TH>'||
                                           '<TH> Error Message     </TH>'||
                                           ---'<TH> Batch Id          </TH>'||
                                        '</TR>');

            -- concatenate table values by loop
            FOR error_rec IN get_errors_data LOOP

              -- Put value to HTML table
              dbms_lob.append(p_document,
                              '<TR>'||
                                 '<TD>'||error_rec.line_num       ||'</TD>'||
                                 '<TD>'||error_rec.item_code      ||'</TD>'||
                                 '<TD>'||error_rec.price          ||'</TD>'||
                                 '<TD>'||error_rec.price_list_name||'</TD>'||
                                 '<TD>'||nvl(error_rec.error_message,'&nbsp')||'</TD>'||
                                 ---'<TD>'||error_rec.batch_id       ||'</TD>'||
                              '</TR>');
            END LOOP;
            -- concatenate close table
            dbms_lob.append(p_document, '</TABLE> </div>');
    end if;  ---if v_num_of_rec_error>0 then
    
    
    -- concatenate close tags
    dbms_lob.append(p_document,'<P>Regards,</P>'||
                               '<P>Oracle Admin</P></FONT>'||
                               '</BODY></HTML>');

    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  exception
    when others then
      wf_core.CONTEXT('XXQP_UPD_PRICE_ALERT_PKG',
                      'XXQP_UPD_PRICE_ALERT_PKG.prepare_notification_body',
                      p_document_id,
                      p_display_type);
      raise;

  end prepare_notification_body;
  ------------------------------------------------------------
END xxqp_upd_price_alert_pkg;
/
