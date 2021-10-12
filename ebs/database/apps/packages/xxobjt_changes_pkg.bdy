CREATE OR REPLACE PACKAGE BODY xxobjt_changes_pkg IS

  --------------------------------------------------------------------
  --  name:            XXOBJT_CHANGES_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.2 
  --  creation date:   19/11/2012 10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        SOX
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/11/2012  Dalit A. Raviv    initial build
  --  1.1  03/12/2012  Dalit A. Raviv    add procedure get_request_message_clob
  --  1.2  07/01/2013  Dalit A. Raviv    add procedure insert_history
  --------------------------------------------------------------------   

  --------------------------------------------------------------------
  --  name:            check_change_exists
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   20/11/2012
  --------------------------------------------------------------------
  --  purpose :        return N - not exists
  --                          Y - exist
  --                          M - exist as duplicate (many rows with the same type and number  
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/11/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION check_change_exists(p_change_type   IN VARCHAR2,
                               p_change_number IN NUMBER,
                               p_change_track  IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_exists VARCHAR2(1) := 'N';
  BEGIN
    SELECT 'Y'
      INTO l_exists
      FROM xxobjt_changes_h h
     WHERE h.change_type = p_change_type
       AND h.change_number = p_change_number
       AND h.change_track = p_change_track;
  
    RETURN l_exists;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN too_many_rows THEN
      RETURN 'M';
    WHEN OTHERS THEN
      RETURN 'N';
  END check_change_exists;

  --------------------------------------------------------------------
  --  name:            get_programmer_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   19/11/2012
  --------------------------------------------------------------------
  --  purpose :        by name return the HR person_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/11/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION get_programmer_id(p_name IN VARCHAR2) RETURN NUMBER IS
  
  BEGIN
  
    IF p_name IN ('Yuval', 'yuval') THEN
      RETURN 1961;
    ELSIF p_name = 'Dalit' THEN
      RETURN 861;
    ELSIF p_name = 'Yoram' THEN
      RETURN 1042;
    ELSIF p_name = 'Ofer' THEN
      RETURN 2262;
    ELSIF p_name = 'Adi' THEN
      RETURN 5921;
    ELSIF p_name = 'Yaniv' THEN
      RETURN 961;
    ELSIF p_name = 'Roman' THEN
      RETURN 257;
    ELSE
      RETURN NULL;
    END IF;
  
  END get_programmer_id;

  --------------------------------------------------------------------
  --  name:            get_implementer_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   19/11/2012
  --------------------------------------------------------------------
  --  purpose :        by name return the HR person_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/11/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  FUNCTION get_implementer_id(p_name IN VARCHAR2) RETURN NUMBER IS
  
  BEGIN
    IF p_name = 'Adi' THEN
      RETURN 5921;
    ELSIF p_name = 'Dalit' THEN
      RETURN 861;
    ELSIF p_name = 'Dovik' THEN
      RETURN 3101;
    ELSIF p_name = 'Ofer' THEN
      RETURN 2262;
    ELSIF p_name = 'Dror' THEN
      RETURN 5923;
    ELSIF p_name IN ('Yaniv', 'Hod/Yaniv') THEN
      RETURN 961;
    ELSIF p_name = 'Roman' THEN
      RETURN 257;
    ELSIF p_name = 'Michael' THEN
      RETURN 259;
    ELSIF p_name = 'Saar' THEN
      RETURN 3281;
    ELSIF p_name IN ('Yoram', 'YoraM') THEN
      RETURN 1042;
    ELSIF p_name = 'Yuval' THEN
      RETURN 1961;
    ELSIF p_name = 'Nechemia' THEN
      RETURN 258;
    ELSIF p_name = 'Idan' THEN
      RETURN 7001;
    ELSIF p_name = 'Oded' THEN
      RETURN 6941;
    ELSIF p_name = 'Orit' THEN
      RETURN 7521;
    ELSIF p_name = 'Nehemia' THEN
      RETURN 258;
    ELSIF p_name = 'Keren' THEN
      RETURN 1043;
    ELSIF p_name = 'Moshe' THEN
      RETURN 1041;
    ELSIF p_name = 'Shirly' THEN
      RETURN 6921;
    ELSE
      RETURN NULL;
    END IF;
  
  END get_implementer_id;

  --------------------------------------------------------------------
  --  name:            upload_change_detial
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   19/11/2012
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/11/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE upload_change_detial(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
  
    CURSOR get_pop_c IS
      SELECT t.*,
             CASE
               WHEN substr(cust_num, 1, 1) = 'C' THEN
                'CUST'
               WHEN substr(cust_num, 1, 1) = 'R' THEN
                'REP'
             END case_type,
             CASE
               WHEN substr(cust_num, 1, 1) = 'C' THEN
                substr(cust_num, 5)
               WHEN substr(cust_num, 1, 1) = 'R' THEN
                substr(cust_num, 4)
             END case_num,
             CASE
               WHEN cr_num = 'BUGFIX' THEN
                'BUGFIX'
               WHEN cr_num = 'No CR' OR cr_num IS NULL THEN
                'NoCR'
               ELSE
                'CR'
             END request_type,
             CASE
               WHEN cr_num = 'BUGFIX' OR cr_num = 'No CR' OR cr_num IS NULL THEN
                NULL
               ELSE
                substr(cr_num, 4)
             END request_number,
             ROWID row_id
        FROM xxobjt_changes_temp t
       WHERE log_code IS NULL;
    --and    rownum < 100;
  
    l_exists     VARCHAR2(2);
    l_change_id  NUMBER;
    l_request_id NUMBER;
    l_impl_id    NUMBER;
    l_prog_id    NUMBER;
    l_message    VARCHAR2(500);
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    FOR get_pop_r IN get_pop_c LOOP
      dbms_output.put_line('------ C type ' || get_pop_r.case_type ||
                           ' C Number ' || get_pop_r.case_num);
      --l_exists     := null;
      l_change_id  := NULL;
      l_request_id := NULL;
      l_impl_id    := NULL;
      l_prog_id    := NULL;
      l_message    := NULL;
    
      l_exists := check_change_exists(get_pop_r.case_type,
                                      get_pop_r.case_num,
                                      get_pop_r.track);
      IF l_exists = 'N' THEN
        UPDATE xxobjt_changes_temp t
           SET t.log_code    = 'E',
               t.log_message = 'Change type ' || get_pop_r.case_type ||
                               ' Change Number ' || get_pop_r.case_num ||
                               ' Do not exists'
         WHERE t.rowid = get_pop_r.row_id;
      
        dbms_output.put_line('C type ' || get_pop_r.case_type ||
                             ' C Number ' || get_pop_r.case_num ||
                             ' Do not exists');
      
      ELSIF l_exists = 'M' THEN
        UPDATE xxobjt_changes_temp t
           SET t.log_code    = 'E',
               t.log_message = 'Change type ' || get_pop_r.case_type ||
                               ' Change Number ' || get_pop_r.case_num ||
                               ' Exists several times (Duplicate)'
         WHERE t.rowid = get_pop_r.row_id;
      
        dbms_output.put_line('C type ' || get_pop_r.case_type ||
                             ' C Number ' || get_pop_r.case_num ||
                             ' Exists several times (Duplicate)');
      
        -- exists = Y 
      ELSE
        BEGIN
          UPDATE xxobjt_changes_h
             SET change_module = get_pop_r.module
           WHERE change_type = get_pop_r.case_type
             AND change_number = get_pop_r.case_num
             AND change_track = get_pop_r.track;
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
        BEGIN
          SELECT change_id
            INTO l_change_id
            FROM xxobjt_changes_h
           WHERE change_type = get_pop_r.case_type
             AND change_number = get_pop_r.case_num
             AND change_track = get_pop_r.track;
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
      
        IF l_change_id IS NOT NULL THEN
          SELECT xxobjt_changes_l_s.nextval INTO l_request_id FROM dual;
        
          l_impl_id := get_implementer_id(get_pop_r.implementer);
          l_prog_id := get_programmer_id(get_pop_r.programmer);
          BEGIN
            INSERT INTO xxobjt_changes_l
              (request_id,
               change_id,
               call_number,
               request_type,
               request_number,
               request_title,
               request_description,
               request_benefits,
               request_affected_area,
               request_by,
               implementer_id,
               programmer_id,
               request_status,
               request_status_date,
               request_priority,
               request_design_time,
               request_code_time,
               request_qa_time,
               request_remarks,
               last_update_date,
               last_updated_by,
               last_update_login,
               creation_date,
               created_by)
            VALUES
              (l_request_id,
               l_change_id,
               NULL,
               get_pop_r.request_type,
               get_pop_r.request_number,
               get_pop_r.cust_name,
               NULL,
               NULL,
               NULL,
               NULL,
               l_impl_id,
               l_prog_id,
               get_pop_r.status,
               to_date(get_pop_r.status_date, 'DD/mm/YYYY'),
               --fnd_date.canonical_to_date( get_pop_r.status_date ),
               NULL,
               NULL,
               NULL,
               NULL,
               get_pop_r.comments || 'CR YN - ' || get_pop_r.cr_yn ||
               ' CR Date - ' || get_pop_r.cr_date,
               SYSDATE,
               2470,
               -1,
               SYSDATE,
               2470);
            UPDATE xxobjt_changes_temp t
               SET t.log_code = 'S'
             WHERE t.rowid = get_pop_r.row_id;
          
            COMMIT;
          
            dbms_output.put_line('S');
          EXCEPTION
            WHEN OTHERS THEN
              l_message := substr(SQLERRM, 1, 240);
              UPDATE xxobjt_changes_temp t
                 SET t.log_code = 'E', t.log_message = l_message
               WHERE t.rowid = get_pop_r.row_id;
              dbms_output.put_line('E - ' || l_message);
          END;
        END IF;
      END IF;
      COMMIT;
    END LOOP;
  
  END upload_change_detial;
  
  --------------------------------------------------------------------
  --  name:            get_request_message_clob
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/12/2012
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/12/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_request_message_clob(document_id   VARCHAR2,
                                     display_type  VARCHAR2,
                                     document      IN OUT NOCOPY CLOB,
                                     document_type IN OUT NOCOPY VARCHAR2) IS
  
    CURSOR get_pop_c(p_doc_instance_id IN NUMBER) IS
      SELECT h.change_type,
             h.change_number,
             h.change_track,
             h.change_module,
             h.change_name,
             h.change_remarks,
             l.call_number,
             l.request_type,
             l.request_number,
             l.request_title,
             l.request_description,
             l.request_benefits,
             l.request_affected_area,
             l.request_by,
             pap.full_name           request_by_name,
             l.implementer_id,
             pap1.full_name          implementer_name,
             l.programmer_id,
             pap2.full_name          programmer_name,
             l.request_priority,
             l.request_design_time,
             l.request_code_time,
             l.request_qa_time,
             l.request_tot_time,
             l.request_remarks
        FROM xxobjt_changes_h        h,
             xxobjt_changes_l        l,
             per_all_people_f        pap,
             per_all_people_f        pap1,
             (select pap2.full_name,
                     pap2.person_id
              from   per_all_people_f pap2
              where  trunc(SYSDATE)   BETWEEN pap2.effective_start_date AND  pap2.effective_end_date) pap2
       WHERE h.change_id             = l.change_id
            --and    l.request_status  = 'In Prod'
            --and    l.request_status_date like sysdate - 1
            --and    h.change_number  = 534
         AND trunc(SYSDATE)          BETWEEN pap.effective_start_date AND   pap.effective_end_date
         AND trunc(SYSDATE)          BETWEEN pap1.effective_start_date AND  pap1.effective_end_date
         --AND trunc(SYSDATE)   BETWEEN pap2.effective_start_date AND  pap2.effective_end_date
         AND pap.person_id           = l.request_by
         AND pap1.person_id          = l.implementer_id
         AND pap2.person_id (+)      = l.programmer_id
         AND l.doc_instance_id       = p_doc_instance_id;
  
    l_req_type     VARCHAR2(150) := NULL;
    l_total        NUMBER := 0;
    l_history_clob CLOB;
  BEGIN
    document_type := 'text/html';
    --if display_type = 'text/html' then
  
    --document := '<html> <hr style="color: darkblue ; height: 2; text-align:LEFT; width:100%"/> <body>';
    -- Task Details
    document := ' ';
    dbms_lob.append(document,
                    '<p> <font face="Verdana" style="color:darkblue" size="3"> <strong>Change Request Details</strong> </font> </p>');
    dbms_lob.append(document,
                    '<div align="left"><TABLE BORDER=1 cellPadding=2>');
  
    FOR get_pop_r IN get_pop_c(document_id) LOOP
      dbms_lob.append(document,
                      '<tr> <td><b> Change : </b></td> <td>' ||
                      get_pop_r.change_type || '-' ||get_pop_r.change_number || ' - ' ||get_pop_r.change_name || ' (' ||
                      get_pop_r.change_track || '-' ||get_pop_r.change_module || ') ' ||'</td> </tr>');
    
      IF get_pop_r.request_number IS NULL THEN
        l_req_type := get_pop_r.request_type;
      ELSE
        l_req_type := get_pop_r.request_type || '-' ||get_pop_r.request_number;
      END IF;
      dbms_lob.append(document,
                      '<tr> <td><b> Request: </b></td> <td> ' || nvl(l_req_type, '&nbsp') ||'</td> </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> Title: </b></td> <td>' ||htf.escape_sc(REPLACE(get_pop_r.request_title, chr(10),'<BR>'))||'</td> </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> Submitted By: </b></td> <td>' ||get_pop_r.implementer_name ||'</td> </tr>');
      ---------------------- 
      dbms_lob.append(document,
                      '<tr> <td><b> Requested by: </b></td> <td>' ||get_pop_r.request_by_name ||'</td> </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> Affected Area: </b></td> <td>' ||REPLACE(htf.escape_sc(get_pop_r.request_affected_area), chr(10),'<BR>') ||'</td> </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> Priority: </b></td> <td>' ||get_pop_r.request_priority || '</td> </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> Description: </b></td> <td>' ||REPLACE(htf.escape_sc(get_pop_r.request_description),chr(10),'<BR>') ||'</td> </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> Benefits: </b></td> <td>' ||nvl(REPLACE(htf.escape_sc(get_pop_r.request_benefits), chr(10), '<BR>'),'&nbsp') ||'</td>  </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> Request Remarks: </b></td> <td>' ||
                      nvl(REPLACE(htf.escape_sc(get_pop_r.request_remarks), chr(10),'<BR>'), '&nbsp') ||'</td>  </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> Design time: </b></td> <td>' ||get_pop_r.request_design_time || '</td> </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> Code time: </b></td> <td>' || get_pop_r.request_code_time ||'</td> </tr>');
    
      dbms_lob.append(document,
                      '<tr> <td><b> Integration tiem: </b></td> <td>' ||get_pop_r.request_qa_time ||'</td> </tr>');
      l_total := get_pop_r.request_design_time + get_pop_r.request_code_time + get_pop_r.request_qa_time;
      dbms_lob.append(document,
                      '<tr> <td><b> Total Estimate time: </b></td> <td>' ||l_total || '</td> </tr>');
    
      dbms_lob.append(document, '</table> </div>');
    
    END LOOP;
    -- add history
    l_history_clob := NULL;
    dbms_lob.append(document,
                    '</br> </br><p> <font face="Verdana" style="color:darkblue" size="3"> <strong>Action History</strong> </font> </p>');
    xxobjt_wf_doc_rg.get_history_wf(document_id   => document_id,
                                    display_type  => '',
                                    document      => l_history_clob,
                                    document_type => document_type);
  
    --
  
    dbms_lob.append(document, l_history_clob);
  
  END get_request_message_clob;
  
  --------------------------------------------------------------------
  --  name:            insert_history
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   07/01/2013 
  --------------------------------------------------------------------
  --  purpose :        insert new row to history table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/01/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                                 
  Procedure insert_history (p_request_id          in  number,
                           	p_change_id           in  number,
                            p_request_status      in  varchar2,
                            p_request_status_date in  date,
                            p_status_changed_by   in  number,
                            p_last_updated_by     in  number,
                            p_errbuf              out varchar2, 
                            p_retcode             out number ) is
                            
  --  PRAGMA AUTONOMOUS_TRANSACTION; 
    
  --  l_history_id number := 0;  
                   
  begin
  
/*    select XXOBJT_CHANGES_L_HIST_S.Nextval
    into   l_history_id
    from   dual;*/  
    
    insert into XXOBJT_CHANGES_L_HIST (REQUEST_ID, CHANGE_ID, HISTORY_ID, REQUEST_STATUS, 
                                       REQUEST_STATUS_DATE, STATUS_CHANGED_BY, LAST_UPDATE_DATE, 
                                       LAST_UPDATED_BY, LAST_UPDATE_LOGIN, CREATION_DATE, CREATED_BY)
    values                            (p_request_id, p_change_id, XXOBJT_CHANGES_L_HIST_S.Nextval, p_request_status,
                                       p_request_status_date, p_status_changed_by, sysdate,
                                       p_last_updated_by, -1,sysdate, p_last_updated_by ) ;                                      
    commit;
    
  exception
    when others then
      p_errbuf  := 'Procedure insert_history failed '||substr(sqlerrm,1,240);
      p_retcode := 1;
  end insert_history;                            
  
  
  
/*
  --------------------------------------------------------------------
  --  name:            get_request_message
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   03/12/2012
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/12/2012  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE get_request_message_test(errbuf  OUT VARCHAR2,
                                     retcode OUT NUMBER ,
                                     --document_id   varchar2,
                                     --display_type  varchar2,
                                     --document      in out nocopy varchar2, -- document := l_message
                                     --document_type in out nocopy varchar2
                                     ) IS
    
    CURSOR get_pop_c IS
      SELECT h.change_type,
             h.change_number,
             h.change_track,
             h.change_module,
             h.change_name,
             h.change_remarks,
             l.call_number,
             l.request_type,
             l.request_number,
             l.request_title,
             l.request_description,
             l.request_benefits,
             l.request_affected_area,
             l.request_by,
             pap.full_name           request_by_name,
             l.implementer_id,
             pap1.full_name          implementer_name,
             l.programmer_id,
             pap2.full_name          programmer_name,
             l.request_priority,
             l.request_design_time,
             l.request_code_time,
             l.request_qa_time,
             l.request_tot_time,
             l.request_remarks
        FROM xxobjt_changes_h h,
             xxobjt_changes_l l,
             per_all_people_f pap,
             per_all_people_f pap1,
             per_all_people_f pap2
       WHERE h.change_id = l.change_id
         AND l.request_status = 'In Prod'
         AND l.request_status_date LIKE SYSDATE - 1
         AND h.change_number = 534
         AND trunc(SYSDATE) BETWEEN pap.effective_start_date AND
             pap.effective_end_date
         AND trunc(SYSDATE) BETWEEN pap1.effective_start_date AND
             pap1.effective_end_date
         AND trunc(SYSDATE) BETWEEN pap2.effective_start_date AND
             pap2.effective_end_date
         AND pap.person_id = l.request_by
         AND pap1.person_id = l.implementer_id
         AND pap2.person_id = l.programmer_id;
    --and    l.doc_instance_id = p_doc_instance_id;
  
    l_file_handler utl_file.file_type;
    --l_message   varchar2(32000);
    l_out_dir   VARCHAR2(100) := '/usr/tmp/YES';
    l_file_name VARCHAR2(100) := 'Dalit Test.html';
    l_open_mode VARCHAR2(5) := 'w';
    l_req_type  VARCHAR2(150) := NULL;
    l_total     NUMBER := 0;
  
    general_exception EXCEPTION;
  BEGIN
    --errbuf  := null;
    --retcode := 0;
  
    --l_resource_id := to_number(substr(document_id, 1, instr(document_id, '-', 1, 1) - 1));
    --l_resource_type := substr(document_id, instr(document_id, '-', 1, 1) + 1, instr(document_id, '-', 1, 2) - instr(document_id, '-', 1, 1) - 1);
    --l_task_asgn_id := to_number(substr(document_id, instr(document_id, '-', 1, 2) + 1));
  
    -- open new file with the SR number as name
    --    if display_type = 'text/html' then
  
    l_file_handler := utl_file.fopen(location  => l_out_dir,
                                     filename  => l_file_name,
                                     open_mode => l_open_mode);
  
    utl_file.put_line(file   => l_file_handler,
                      buffer => '<html> <hr style="color: darkblue ; height: 2; text-align:LEFT; width:100%"/>
                                  <body>');
  
    utl_file.put_line(file   => l_file_handler,
                      buffer => '<p> <font face="Verdana" style="color:darkblue" size="3">
                                  <strong>Change Request Details</strong> </font>
                                  </p>');
  
    utl_file.put_line(file   => l_file_handler,
                      buffer => '<div align="left"><TABLE BORDER=1 cellPadding=2>');
  
    FOR get_pop_r IN get_pop_c LOOP
      BEGIN
              
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Change : </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    get_pop_r.change_type || '-' ||
                                    get_pop_r.change_number || ' - ' ||
                                    get_pop_r.change_name || ' (' ||
                                    get_pop_r.change_track || '-' ||
                                    get_pop_r.change_module || ') ' ||
                                    '</font></small></td>
                                      </tr>');
      
        IF get_pop_r.request_number IS NULL THEN
          l_req_type := get_pop_r.request_type;
        ELSE
          l_req_type := get_pop_r.request_type || '-' ||
                        get_pop_r.request_number;
        END IF;
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Request: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    nvl(l_req_type, '&nbsp') ||
                                    '</font></small></td>
                                      </tr>');
      
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Title: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    htf.escape_sc(REPLACE(get_pop_r.request_title,
                                                          chr(10),
                                                          '<BR>')) ||
                                    '</font></small></td>
                                      </tr>');
        ----------------------
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Submitted By: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    get_pop_r.implementer_name ||
                                    '</font></small></td> 
                                      </tr>');
        ---------------------- 
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Requested by: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    get_pop_r.request_by_name ||
                                    '</font></small></td>
                                      </tr>');
      
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Affected Area: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    htf.escape_sc(REPLACE(get_pop_r.request_affected_area,
                                                          chr(10),
                                                          '<BR>')) ||
                                    '</font></small></td>
                                      </tr>');
      
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Priority: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    get_pop_r.request_priority ||
                                    '</font></small></td>
                                      </tr>');
      
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Description: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    htf.escape_sc(REPLACE(get_pop_r.request_description,
                                                          chr(10),
                                                          '<BR>')) ||
                                    '</font></small></td>
                                      </tr>');
      
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Benefits: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    nvl(htf.escape_sc(REPLACE(get_pop_r.request_benefits,
                                                              chr(10),
                                                              '<BR>')),
                                        '&nbsp') ||
                                    '</font></small></td>
                                      </tr>');
      
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Request Remarks: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    nvl(htf.escape_sc(REPLACE(get_pop_r.request_remarks,
                                                              chr(10),
                                                              '<BR>')),
                                        '&nbsp') ||
                                    '</font></small></td>
                                      </tr>');
      
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Design time: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    get_pop_r.request_design_time ||
                                    '</font></small></td>
                                      </tr>');
      
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Code time: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    get_pop_r.request_code_time ||
                                    '</font></small></td>
                                      </tr>');
      
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Integration tiem: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    get_pop_r.request_qa_time ||
                                    '</font></small></td>
                                      </tr>');
        l_total := get_pop_r.request_design_time +
                   get_pop_r.request_code_time + get_pop_r.request_qa_time;
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<tr>
                                      <td><small><font face="Verdana"><b> Total Estimate time: </b></font></small></td>
                                      <td><small><font face="Verdana">' ||
                                    l_total ||
                                    '</font></small></td>
                                      </tr>');
      
        utl_file.put_line(file   => l_file_handler,
                          buffer => '</table>
                                      </div>');
      
        -- Handle fnd_file exceptions
      EXCEPTION
        WHEN utl_file.invalid_mode THEN
          fnd_file.put_line(fnd_file.log,
                            'The open_mode parameter in FOPEN is invalid');
          dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_path THEN
          fnd_file.put_line(fnd_file.log,
                            'Specified path does not exist or is not visible to Oracle');
          dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_filehandle THEN
          fnd_file.put_line(fnd_file.log, 'File handle does not exist');
          dbms_output.put_line('File handle does not exist');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.internal_error THEN
          fnd_file.put_line(fnd_file.log,
                            'Unhandled internal error in the UTL_FILE package');
          dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.file_open THEN
          fnd_file.put_line(fnd_file.log, 'File is already open');
          dbms_output.put_line('File is already open');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_maxlinesize THEN
          fnd_file.put_line(fnd_file.log,
                            'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
          dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_operation THEN
          fnd_file.put_line(fnd_file.log,
                            'File could not be opened or operated on as requested');
          dbms_output.put_line('File could not be opened or operated on as requested');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.write_error THEN
          fnd_file.put_line(fnd_file.log, 'Unable to write to file');
          dbms_output.put_line('Unable to write to file');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.access_denied THEN
          fnd_file.put_line(fnd_file.log,
                            'Access to the file has been denied by the operating system');
          dbms_output.put_line('Access to the file has been denied by the operating system');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log, 'Unknown UTL_FILE Error');
          dbms_output.put_line('Unknown UTL_FILE Error - ' || SQLERRM);
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
      END;
    
    END LOOP;
  
    utl_file.put_line(file   => l_file_handler,
                      buffer => '<br>
                                  <hr style="color:darkblue ; height: 2; text-align: LEFT ; width: 100% "/>
                                  <p style="color:darkblue">Regards,<br>
                                  Oracle Admin <br><br>
                                  </p>
                                  </body></html>');
  
    utl_file.put_line(file   => l_file_handler,
                      buffer => '</body>
                                  </html> ');
    -- close the created file           
    utl_file.fclose(file => l_file_handler);
  
  EXCEPTION
    WHEN general_exception THEN
      NULL;
    WHEN OTHERS THEN
      errbuf  := 2;
      retcode := 'GEN Error - ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'GEN Error - ' || SQLERRM);
      dbms_output.put_line('GEN Error - ' || SQLERRM);
    
  END get_request_message_test;
*/
/*                          
  create table XXOBJT.XXOBJT_CHANGES_TEMP
 (CUST_NUM                 varchar2(100),
  Ver                      varchar2(50),
  CR_Num                   varchar2(50),        
  Track                    varchar2(50),
  Module                   varchar2(50),
  Cust_Name                varchar2(1000),
  Cust_Type                varchar2(500),
  Priority                 varchar2(50),                
  Est_Days                 varchar2(50),
  Status                   varchar2(50),
  Status_date              varchar2(50),
  implementer              varchar2(250),
  Programmer               varchar2(250),
  Comments                 varchar2(1500),
  CR_YN                    varchar2(50),
  CR_Date                  varchar2(50),
  BUGFIX_DATE              varchar2(500),
  LOG_CODE                 varchar2(10),
  LOG_MESSAGE              varchar2(500),
  LAST_UPDATE_DATE         DATE,
  LAST_UPDATED_BY          NUMBER,
  LAST_UPDATE_LOGIN        NUMBER,
  CREATION_DATE            DATE,
  CREATED_BY               NUMBER);
  
-- APPS
-- drop synonym apps.XXOBJT_CHANGES_H
Create or replace synonym apps.XXOBJT_CHANGES_TEMP  for xxobjt.XXOBJT_CHANGES_TEMP;   
*/
END xxobjt_changes_pkg;
/
