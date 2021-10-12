CREATE OR REPLACE PACKAGE BODY xxcs_hasp_mail_pkg AS
  ---------------------------------------------------------------------------
  -- $Header: xxcs_hasp_mail_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxcs_hasp_mail_pkg
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: support hasp interface process cust419
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  04.06.12   yuval tal      Initial Build
  --     1.1  07.08.12   yuval tal      CR 467 : generate_success_alert_msg_wf/generate_error_alert_msg_wf
  --                                            add line id to receive info from view xxcs_hasp_upgrade_v
  --     1.2  31.07. 14  michal tzvik   CHG0032163: Unified platform V2C HASP Process.
  --                                    Update procedures generate_success_alert_msg_wf, generate_error_alert_msg_wf                                  
  ------------------------------------------------------
  -- get_last_err_log_message
  --------------------------------------------------------
  G_html_header VARCHAR2(4000);
  G_html_footer VARCHAR2(4000);
  
  FUNCTION get_last_err_log_message(p_hasp_interface_id VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_err_desc xxcs_hasp_log.description%TYPE;
  BEGIN
    SELECT t.description
      INTO l_err_desc
      FROM xxcs_hasp_log t
     WHERE t.hasp_interface_id = p_hasp_interface_id
       AND t.log_code = 'E'
       AND t.open_flag = 'Y'
       AND t.creation_date =
           (SELECT MAX(creation_date)
              FROM xxcs_hasp_log t1
             WHERE t1.hasp_interface_id = t.hasp_interface_id
               AND t1.log_code = t.log_code)
       AND rownum = 1;
  
    RETURN l_err_desc;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

 --------------------------------------------------------------------
  --  customization code: 
  --  name:               generate_success_alert_MSG_wf
  --  create by:          
  --  Revision:           
  --  creation date:      
  --  Purpose :           Generate success message for wf
  ----------------------------------------------------------------------
  --  ver   date          name            desc  
  --  1.1   23.06.14      Michal Tzvik    CHG0032163: Add logic for ‘Installation’ – for the new process related to Order Management
  -------------------------------
  PROCEDURE generate_success_alert_msg_wf(document_id   IN VARCHAR2,
                                          display_type  IN VARCHAR2,
                                          document      IN OUT NOCOPY CLOB,
                                          document_type IN OUT NOCOPY VARCHAR2) IS
    l_order_number VARCHAR2(50);
    l_group_number VARCHAR2(50);
    l_document     VARCHAR2(2000);
    l_line_id      NUMBER;
    
    CURSOR c IS
      SELECT *
        FROM xxcs_hasp_upgrade_v tt
       WHERE tt.order_number = l_order_number
         AND tt.line_id = l_line_id
         AND rownum = 1;
         
    CURSOR c_inst(p_document_id  number) IS --  1.1  23.06.14  Michal Tzvik
    SELECT h.order_number,
           tt.printer_desc,
           nvl(tt.owner, hp.party_name) owner,
           tt.printer_sn,
           tt.user_name,
           tt.printer_item,
           tt.cmp,
           tt.hasp,
           tt.dongle_sn,
           h.group_number
      FROM xxom_hasp_installation_v tt,
           xxcs_hasp_headers        h,
           csi_item_instances       cii,
           hz_parties               hp
     WHERE h.hasp_interface_id = p_document_id
       and tt.instance_id      = h.instance_id
       and cii.owner_party_id  = hp.party_id
       and cii.instance_id     = h.instance_id
       AND rownum = 1;
  
  BEGIN
    SELECT t.order_number, t.group_number, t.order_line_id
      INTO l_order_number, l_group_number, l_line_id
      FROM xxcs_hasp_headers t
     WHERE t.hasp_interface_id = document_id;
  
    --
  
    FOR i IN c LOOP
      fnd_message.clear;
      fnd_message.set_name('XXOBJT', 'XXCS_HASP_ALERT_SUCCESS');
      fnd_message.set_token('ORDER', i.order_number);
      fnd_message.set_token('DESCRIPTION', i.description);
      fnd_message.set_token('OWNER', i.owner);
      fnd_message.set_token('EDU', i.edu);
      fnd_message.set_token('OLD_PRINTER', i.old_printer);
      fnd_message.set_token('OLD_PRINTER_DESCRIPTION',
                            i.old_printer_description);
      fnd_message.set_token('SERIAL_NUMBER', i.serial_number);
      fnd_message.set_token('CS_REGION', i.cs_region);
      fnd_message.set_token('USER', i.user_name);
      fnd_message.set_token('SEGMENT1', i.segment1);
      fnd_message.set_token('CMP', i.cmp);
      fnd_message.set_token('HASP', i.hasp);
      fnd_message.set_token('DONGLE_SN', i.dongle_sn);
      fnd_message.set_token('MSC', i.msc);
      fnd_message.set_token('GROUP_NUMBER', l_group_number);
      document := G_html_header || ' ' || fnd_message.get || ' ' ||
                  G_html_footer;
    END LOOP;

    -- 1.1 23.06.2014 Michal Tzvik: Start
   FOR i IN c_inst(document_id) LOOP
      fnd_message.clear;
      fnd_message.set_name('XXOBJT', 'XXCS_HASP_INST_ALERT_SUCCESS');
      fnd_message.set_token('ORDER', i.order_number);
      fnd_message.set_token('DESCRIPTION', i.printer_desc);
      fnd_message.set_token('OWNER', i.owner);
      fnd_message.set_token('SERIAL_NUMBER', i.printer_sn);
      fnd_message.set_token('USER', i.user_name);
      fnd_message.set_token('SEGMENT1', i.printer_item);
      fnd_message.set_token('CMP', i.cmp);
      fnd_message.set_token('MSC', i.hasp);
      fnd_message.set_token('DONGLE_SN', i.dongle_sn);
      fnd_message.set_token('GROUP_NUMBER', i.group_number);
      document := G_html_header || ' ' || fnd_message.get || ' ' ||
                  G_html_footer;
    END LOOP;
    -- 1.1 23.06.2014 Michal Tzvik: End
  
  EXCEPTION
    WHEN OTHERS THEN
      document := 'Error :' || SQLERRM;
  END;
 --------------------------------------------------------------------
  --  customization code: 
  --  name:               generate_error_alert_msg_wf
  --  create by:          
  --  Revision:           
  --  creation date:      
  --  Purpose :           Generate error message for wf
  ----------------------------------------------------------------------
  --  ver   date          name            desc  
  --  1.1   23.06.14      Michal Tzvik    CHG0032163: Add logic for ‘Installation’ – for the new process related to Order Management
  -------------------------------
  PROCEDURE generate_error_alert_msg_wf(document_id   IN VARCHAR2,
                                        display_type  IN VARCHAR2,
                                        document      IN OUT NOCOPY CLOB,
                                        document_type IN OUT NOCOPY VARCHAR2) IS
    l_order_number VARCHAR2(50);
  
    l_document VARCHAR2(2000);
    l_rec      xxcs_hasp_headers%ROWTYPE;
    l_err_desc xxcs_hasp_log.description%TYPE;
    CURSOR c IS
      SELECT *
        FROM xxcs_hasp_upgrade_v tt
       WHERE tt.order_number = l_rec.order_number
         AND tt.line_id = l_rec.order_line_id
         AND rownum = 1;
  
    CURSOR c_inst(p_document_id  number) IS --  1.1  23.06.14  Michal Tzvik
    SELECT h.order_number,
           tt.printer_desc,
           nvl(tt.owner, hp.party_name) owner,
           tt.printer_sn,
           tt.user_name,
           tt.printer_item,
           tt.cmp,
           tt.hasp,
           tt.dongle_sn,
           h.group_number
      FROM xxom_hasp_installation_v tt,
           xxcs_hasp_headers        h,
           csi_item_instances       cii,
           hz_parties               hp
     WHERE h.hasp_interface_id = p_document_id
       and tt.instance_id      = h.instance_id
       and cii.owner_party_id  = hp.party_id
       and cii.instance_id     = h.instance_id
       AND rownum = 1;         
  
  BEGIN
    SELECT *
      INTO l_rec
      FROM xxcs_hasp_headers t
     WHERE t.hasp_interface_id = document_id;
  
    --
    l_err_desc := get_last_err_log_message(document_id);
    FOR i IN c LOOP
      fnd_message.clear;
      fnd_message.set_name('XXOBJT', 'XXCS_HASP_ALERT_ERROR');
      fnd_message.set_token('ERR_DESC', substr(l_err_desc, 1, 150));
      fnd_message.set_token('FLOW_CODE',
                            xxobjt_general_utils_pkg.get_valueset_desc('XXCS_HASP_FLOW_CODE',
                                                                       l_rec.flow_code));
      fnd_message.set_token('HASP_INTERFACE_ID', l_rec.hasp_interface_id);
      fnd_message.set_token('ORDER', i.order_number);
      fnd_message.set_token('DESCRIPTION', i.description);
      fnd_message.set_token('OWNER', i.owner);
      fnd_message.set_token('EDU', i.edu);
      fnd_message.set_token('OLD_PRINTER', i.old_printer);
      fnd_message.set_token('OLD_PRINTER_DESCRIPTION',
                            i.old_printer_description);
      fnd_message.set_token('SERIAL_NUMBER', i.serial_number);
      fnd_message.set_token('CS_REGION', i.cs_region);
      fnd_message.set_token('USER', i.user_name);
      fnd_message.set_token('SEGMENT1', i.segment1);
      fnd_message.set_token('CMP', i.cmp);
      fnd_message.set_token('HASP', i.hasp);
      fnd_message.set_token('DONGLE_SN', i.dongle_sn);
      fnd_message.set_token('MSC', i.msc);
      fnd_message.set_token('GROUP_NUMBER', l_rec.group_number);
      document := G_html_header || ' ' || fnd_message.get || ' ' ||
                  G_html_footer;
    END LOOP;
    
    -- 1.1 23.06.2014 Michal Tzvik: Start
    FOR i IN c_inst(document_id) LOOP
      fnd_message.clear;
      fnd_message.set_name('XXOBJT', 'XXCS_HASP_INST_ALERT_ERROR');
      fnd_message.set_token('ERR_DESC', substr(l_err_desc, 1, 150));
      fnd_message.set_token('FLOW_CODE',
                            xxobjt_general_utils_pkg.get_valueset_desc('XXCS_HASP_FLOW_CODE',
                                                                       l_rec.flow_code));
      fnd_message.set_token('HASP_INTERFACE_ID', l_rec.hasp_interface_id);
      fnd_message.set_token('ORDER', i.order_number);
      fnd_message.set_token('DESCRIPTION', i.printer_desc);
      fnd_message.set_token('OWNER', i.owner);
      fnd_message.set_token('SERIAL_NUMBER', i.printer_sn);
      fnd_message.set_token('USER', i.user_name);
      fnd_message.set_token('SEGMENT1', i.printer_item);
      fnd_message.set_token('CMP', i.cmp);
      fnd_message.set_token('MSC', i.hasp);
      fnd_message.set_token('DONGLE_SN', i.dongle_sn);
      fnd_message.set_token('GROUP_NUMBER', l_rec.group_number);
      document := G_html_header || ' ' || fnd_message.get || ' ' ||
                  G_html_footer;
    END LOOP;
     
    -- 1.1 23.06.2014 Michal Tzvik: End
  
  EXCEPTION
    WHEN OTHERS THEN
      document := 'Error :' || SQLERRM;
  END;

BEGIN
  G_html_header :=  XXOBJT_WF_MAIL_SUPPORT.GET_HEADER_HTML ('INTERNAL');
  G_html_footer :=  XXOBJT_WF_MAIL_SUPPORT.GET_FOOTER_HTML ;
END;
/
