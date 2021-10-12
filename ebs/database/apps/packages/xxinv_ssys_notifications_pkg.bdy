CREATE OR REPLACE PACKAGE BODY xxinv_ssys_notifications_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUST540
  --  name:               xxinv_ssys_notifications_pkg
  --  create by:          Vitaly K
  --  $Revision:          1.0 $
  --  creation date:      07/11/2012
  --  Purpose :           
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/11/2012    Vitaly K        initial build
  ----------------------------------------------------------------------- 

  --------------------------------------------------------------------
  --  name:               create_items_notification
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
  PROCEDURE create_items_notification(p_document_id   IN VARCHAR2,
                                      p_display_type  IN VARCHAR2,
                                      p_document      IN OUT CLOB,
                                      p_document_type IN OUT VARCHAR2) IS
  
    CURSOR get_summary_data IS
      SELECT nvl(SUM(1), 0) num_of_rec_processed,
             nvl(SUM(decode(a.status, 'S', 1, 0)), 0) num_of_rec_succeeded,
             nvl(SUM(decode(a.status, 'E', 1, 0)), 0) num_of_rec_error
        FROM xxinv_ssys_items a
       WHERE a.last_update_date >=
             to_date(p_document_id, 'ddmmyyyy hh24:mi');
  
    CURSOR get_errors_data IS
      SELECT row_number() over(PARTITION BY 'stam' ORDER BY a.item_code) line_num,
             a.batch_id,
             a.item_code,
             a.item_desc,
             a.message,
             a.error_message,
             a.creation_date,
             a.line_id,
             a.file_name
        FROM xxinv_ssys_items a
       WHERE (a.status = 'E' ---error
             OR a.message IS NOT NULL)
         AND a.last_update_date >=
             to_date(p_document_id, 'ddmmyyyy hh24:mi')
       ORDER BY a.item_code;
  
    v_num_of_rec_processed NUMBER := 0;
    v_num_of_rec_succeeded NUMBER := 0;
    v_num_of_rec_error     NUMBER := 0;
  
  BEGIN
  
    OPEN get_summary_data;
    FETCH get_summary_data
      INTO v_num_of_rec_processed,
           v_num_of_rec_succeeded,
           v_num_of_rec_error;
    CLOSE get_summary_data;
  
    -- concatenate start message
    dbms_lob.append(p_document,
                    '<HTML>' || '<BODY><FONT color=blue face="Verdana">' ||
                    '<P> Create New SSYS Items</P>' || '<P> </P>' ||
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
  
    IF v_num_of_rec_error > 0 THEN
      -- concatenate table prompts
      dbms_lob.append(p_document,
                      '<P> </P>' || '<P> Errors details</P>' ||
                      '<div align="left"><TABLE style="COLOR: blue" border=1 cellpadding=8>');
      dbms_lob.append(p_document,
                      '<TR align="left">' || '<TH> N </TH>' ||
                      '<TH> Item  </TH>' || '<TH> Description </TH>' ||
                      '<TH> Non Failure Error Message </TH>' ||
                      '<TH> Failure Error Message </TH>' ||
                      '<TH> Creation date  </TH>' ||
                      '<TH> File Name  </TH>' || '<TH> Line Id </TH>' ||
                      '</TR>');
    
      -- concatenate table values by loop
      FOR error_rec IN get_errors_data LOOP
      
        -- Put value to HTML table
        dbms_lob.append(p_document,
                        '<TR>' || '<TD>' || error_rec.line_num || '</TD>' ||
                        '<TD>' || error_rec.item_code || '</TD>' || '<TD>' ||
                        error_rec.item_desc || '</TD>' || '<TD>' ||
                        error_rec.message || '</TD>' || '<TD>' ||
                        nvl(error_rec.error_message, '&nbsp') || '</TD>' ||
                        '<TD>' || error_rec.creation_date || '</TD>' ||
                        '<TD>' || error_rec.file_name || '</TD>' || '<TD>' ||
                        error_rec.line_id || '</TD>' || '</TR>');
      END LOOP;
      -- concatenate close table
      dbms_lob.append(p_document, '</TABLE> </div>');
    END IF; ---if v_num_of_rec_error>0 then
  
    -- concatenate close tags
    dbms_lob.append(p_document,
                    '<P>Regards,</P>' || '<P>Oracle Admin</P></FONT>' ||
                    '</BODY></HTML>');
  
    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXINV_SSYS_NOTIFICATIONS_PKG',
                      'XXINV_SSYS_NOTIFICATIONS_PKG.create_items_notification',
                      p_document_id,
                      p_display_type);
      RAISE;
    
  END create_items_notification;
  --------------------------------------------------------------------
  --  name:               upd_items_min_max_notification
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
  PROCEDURE upd_items_min_max_notification(p_document_id   IN VARCHAR2,
                                           p_display_type  IN VARCHAR2,
                                           p_document      IN OUT CLOB,
                                           p_document_type IN OUT VARCHAR2) IS
  
    CURSOR get_summary_data IS
      SELECT nvl(SUM(1), 0) num_of_rec_processed,
             nvl(SUM(decode(a.status, 'S', 1, 0)), 0) num_of_rec_succeeded,
             nvl(SUM(decode(a.status, 'E', 1, 0)), 0) num_of_rec_error
        FROM xxinv_ssys_min_max a
       WHERE a.last_update_date >=
             to_date(p_document_id, 'ddmmyyyy hh24:mi');
  
    CURSOR get_errors_data IS
      SELECT row_number() over(PARTITION BY 'stam' ORDER BY a.item_code, a.organization_code) line_num,
             a.batch_id,
             a.item_code,
             a.organization_code,
             a.message,
             a.error_message,
             a.status,
             
             a.creation_date,
             a.line_id,
             a.file_name
        FROM xxinv_ssys_min_max a
       WHERE (a.status = 'E' ---error
             OR a.message IS NOT NULL)
         AND a.last_update_date >=
             to_date(p_document_id, 'ddmmyyyy hh24:mi')
       ORDER BY a.item_code, a.organization_code;
  
    v_num_of_rec_processed NUMBER := 0;
    v_num_of_rec_succeeded NUMBER := 0;
    v_num_of_rec_error     NUMBER := 0;
  
  BEGIN
  
    OPEN get_summary_data;
    FETCH get_summary_data
      INTO v_num_of_rec_processed,
           v_num_of_rec_succeeded,
           v_num_of_rec_error;
    CLOSE get_summary_data;
  
    -- concatenate start message
    dbms_lob.append(p_document,
                    '<HTML>' || '<BODY><FONT color=blue face="Verdana">' ||
                    '<P> Update SSYS Items Min-Max</P>' || '<P> </P>' ||
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
  
    IF v_num_of_rec_error > 0 THEN
      -- concatenate table prompts
      dbms_lob.append(p_document,
                      '<P> </P>' || '<P> Errors details</P>' ||
                      '<div align="left"><TABLE style="COLOR: blue" border=1 cellpadding=8>');
      dbms_lob.append(p_document,
                      '<TR align="left">' || '<TH> N                 </TH>' ||
                      '<TH> Item              </TH>' ||
                      '<TH> Organization      </TH>' ||
                      '<TH> Non Failure Error Message  </TH>' ||
                      '<TH> Failure Error Message   </TH>' ||
                      '<TH> Creation date  </TH>' ||
                      '<TH> File Name  </TH>' || '<TH> Line Id </TH>' ||
                      '</TR>');
    
      -- concatenate table values by loop
      FOR error_rec IN get_errors_data LOOP
      
        -- Put value to HTML table
        dbms_lob.append(p_document,
                        '<TR>' || '<TD>' || error_rec.line_num || '</TD>' ||
                        '<TD>' || error_rec.item_code || '</TD>' || '<TD>' ||
                        error_rec.organization_code || '</TD>' || '<TD>' ||
                        error_rec.message || '</TD>' || '<TD>' ||
                        nvl(error_rec.error_message, '&nbsp') || '</TD>' ||
                        '<TD>' || error_rec.creation_date || '</TD>' ||
                        '<TD>' || error_rec.file_name || '</TD>' || '<TD>' ||
                        error_rec.line_id || '</TD>' || '</TR>');
      END LOOP;
      -- concatenate close table
      dbms_lob.append(p_document, '</TABLE> </div>');
    END IF; ---if v_num_of_rec_error>0 then
  
    -- concatenate close tags
    dbms_lob.append(p_document,
                    '<P>Regards,</P>' || '<P>Oracle Admin</P></FONT>' ||
                    '</BODY></HTML>');
  
    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXINV_SSYS_NOTIFICATIONS_PKG',
                      'XXINV_SSYS_NOTIFICATIONS_PKG.upd_items_min_max_notification',
                      p_document_id,
                      p_display_type);
      RAISE;
    
  END upd_items_min_max_notification;
  --------------------------------------------------------------------
  --  name:               add_lines_to_bpa_notification
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
  PROCEDURE add_lines_to_bpa_notification(p_document_id   IN VARCHAR2,
                                          p_display_type  IN VARCHAR2,
                                          p_document      IN OUT CLOB,
                                          p_document_type IN OUT VARCHAR2) IS
  
    CURSOR get_summary_data IS
      SELECT nvl(SUM(1), 0) num_of_rec_processed,
             nvl(SUM(decode(a.status, 'S', 1, 0)), 0) num_of_rec_succeeded,
             nvl(SUM(decode(a.status, 'E', 1, 0)), 0) num_of_rec_error
        FROM xxinv_ssys_blanket_lines a
       WHERE a.last_update_date >=
             to_date(p_document_id, 'ddmmyyyy hh24:mi');
  
    CURSOR get_errors_data IS
      SELECT row_number() over(PARTITION BY 'stam' ORDER BY a.operating_unit, a.item_code) line_num,
             a.batch_id,
             a.operating_unit,
             a.item_code,
             a.transfer_price,
             a.message,
             a.error_message,
             a.creation_date,
             a.line_id,
             a.file_name
        FROM xxinv_ssys_blanket_lines a
       WHERE (a.status = 'E' ---error
             OR a.message IS NOT NULL)
         AND a.last_update_date >=
             to_date(p_document_id, 'ddmmyyyy hh24:mi')
       ORDER BY a.operating_unit, a.item_code;
  
    v_num_of_rec_processed NUMBER := 0;
    v_num_of_rec_succeeded NUMBER := 0;
    v_num_of_rec_error     NUMBER := 0;
  
  BEGIN
  
    OPEN get_summary_data;
    FETCH get_summary_data
      INTO v_num_of_rec_processed,
           v_num_of_rec_succeeded,
           v_num_of_rec_error;
    CLOSE get_summary_data;
  
    -- concatenate start message
    dbms_lob.append(p_document,
                    '<HTML>' || '<BODY><FONT color=blue face="Verdana">' ||
                    '<P> Add Lines To Blanket PO</P>' || '<P> </P>' ||
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
  
    IF v_num_of_rec_error > 0 THEN
      -- concatenate table prompts
      dbms_lob.append(p_document,
                      '<P> </P>' || '<P> Errors details</P>' ||
                      '<div align="left"><TABLE style="COLOR: blue" border=1 cellpadding=8>');
      dbms_lob.append(p_document,
                      '<TR align="left">' || '<TH> N          </TH>' ||
                      '<TH> Operating Unit    </TH>' ||
                      '<TH> Item              </TH>' ||
                      '<TH> Transfer Price    </TH>' ||
                      '<TH> Non Failure Error Message </TH>' ||
                      '<TH> Failure Error Message     </TH>' ||
                      '<TH> Creation date  </TH>' ||
                      '<TH> File Name  </TH>' || '<TH> Line Id </TH>' ||
                      '</TR>');
    
      -- concatenate table values by loop
      FOR error_rec IN get_errors_data LOOP
      
        -- Put value to HTML table
        dbms_lob.append(p_document,
                        '<TR>' || '<TD>' || error_rec.line_num || '</TD>' ||
                        '<TD>' || error_rec.operating_unit || '</TD>' ||
                        '<TD>' || error_rec.item_code || '</TD>' || '<TD>' ||
                        error_rec.transfer_price || '</TD>' || '<TD>' ||
                        error_rec.message || '</TD>' || '<TD>' ||
                        nvl(error_rec.error_message, '&nbsp') || '</TD>' ||
                        '<TD>' || error_rec.creation_date || '</TD>' ||
                        '<TD>' || error_rec.file_name || '</TD>' || '<TD>' ||
                        error_rec.line_id || '</TD>' || '</TR>');
      END LOOP;
      -- concatenate close table
      dbms_lob.append(p_document, '</TABLE> </div>');
    END IF; ---if v_num_of_rec_error>0 then
  
    -- concatenate close tags
    dbms_lob.append(p_document,
                    '<P>Regards,</P>' || '<P>Oracle Admin</P></FONT>' ||
                    '</BODY></HTML>');
  
    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXINV_SSYS_NOTIFICATIONS_PKG',
                      'XXINV_SSYS_NOTIFICATIONS_PKG.add_lines_to_bpa_notification',
                      p_document_id,
                      p_display_type);
      RAISE;
    
  END add_lines_to_bpa_notification;
  --------------------------------------------------------------------
  --  name:               add_ssys_item_cost_notificat
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
  PROCEDURE add_ssys_item_cost_notificat(p_document_id   IN VARCHAR2,
                                         p_display_type  IN VARCHAR2,
                                         p_document      IN OUT CLOB,
                                         p_document_type IN OUT VARCHAR2) IS
  
    CURSOR get_summary_data IS
      SELECT nvl(SUM(1), 0) num_of_rec_processed,
             nvl(SUM(decode(a.status, 'S', 1, 0)), 0) num_of_rec_succeeded,
             nvl(SUM(decode(a.status, 'E', 1, 0)), 0) num_of_rec_error
        FROM xxinv_ssys_item_cost a
       WHERE a.last_update_date >=
             to_date(p_document_id, 'ddmmyyyy hh24:mi');
  
    CURSOR get_errors_data IS
      SELECT row_number() over(PARTITION BY 'stam' ORDER BY a.item_code, a.organization_code) line_num,
             a.batch_id,
             a.organization_code,
             a.item_code,
             a.item_cost,
             a.message,
             a.error_message,
             a.creation_date,
             a.line_id,
             a.file_name
        FROM xxinv_ssys_item_cost a
       WHERE (a.status = 'E' ---error
             OR a.message IS NOT NULL)
         AND a.last_update_date >=
             to_date(p_document_id, 'ddmmyyyy hh24:mi')
       ORDER BY a.item_code, a.organization_code;
  
    v_num_of_rec_processed NUMBER := 0;
    v_num_of_rec_succeeded NUMBER := 0;
    v_num_of_rec_error     NUMBER := 0;
  
  BEGIN
    -- xxobjt_debug_proc(p_message1 => 
    OPEN get_summary_data;
    FETCH get_summary_data
      INTO v_num_of_rec_processed,
           v_num_of_rec_succeeded,
           v_num_of_rec_error;
    CLOSE get_summary_data;
  
    -- concatenate start message
    dbms_lob.append(p_document,
                    '<HTML>' || '<BODY><FONT color=blue face="Verdana">' ||
                    '<P> Add SSYS Item Cost</P>' || '<P> </P>' ||
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
  
    IF v_num_of_rec_error > 0 THEN
      -- concatenate table prompts
      dbms_lob.append(p_document,
                      '<P> </P>' || '<P> Errors details</P>' ||
                      '<div align="left"><TABLE style="COLOR: blue" border=1 cellpadding=8>');
      dbms_lob.append(p_document,
                      '<TR align="left">' || '<TH> N                 </TH>' ||
                      '<TH> Organization      </TH>' ||
                      '<TH> Item              </TH>' ||
                      '<TH> Item Cost         </TH>' ||
                      '<TH> Non Failure Error Message </TH>' ||
                      '<TH> Failure Error Message     </TH>' ||
                      '<TH> Creation date  </TH>' ||
                      '<TH> File Name  </TH>' || '<TH> Line Id </TH>' ||
                      '</TR>');
    
      -- concatenate table values by loop
      FOR error_rec IN get_errors_data LOOP
      
        -- Put value to HTML table
        dbms_lob.append(p_document,
                        '<TR>' || '<TD>' || error_rec.line_num || '</TD>' ||
                        '<TD>' || error_rec.organization_code || '</TD>' ||
                        '<TD>' || error_rec.item_code || '</TD>' || '<TD>' ||
                        error_rec.item_cost || '</TD>' || '<TD>' ||
                        error_rec.message || '</TD>' || '<TD>' ||
                        nvl(error_rec.error_message, '&nbsp') || '</TD>' ||
                        '<TD>' || error_rec.creation_date || '</TD>' ||
                        '<TD>' || error_rec.file_name || '</TD>' || '<TD>' ||
                        error_rec.line_id || '</TD>' || '</TR>');
      END LOOP;
      -- concatenate close table
      dbms_lob.append(p_document, '</TABLE> </div>');
    END IF; ---if v_num_of_rec_error>0 then
  
    -- concatenate close tags
    dbms_lob.append(p_document,
                    '<P>Regards,</P>' || '<P>Oracle Admin</P></FONT>' ||
                    '</BODY></HTML>');
  
    p_document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
    -- dbms_lob.copy(document, bdoc, dbms_lob.getlength(bdoc));
  EXCEPTION
    WHEN OTHERS THEN
      wf_core.context('XXINV_SSYS_NOTIFICATIONS_PKG',
                      'XXINV_SSYS_NOTIFICATIONS_PKG.add_ssys_item_cost_notificat',
                      p_document_id,
                      p_display_type);
      RAISE;
    
  END add_ssys_item_cost_notificat;
  ------------------------------------------------------------

END xxinv_ssys_notifications_pkg;
/
