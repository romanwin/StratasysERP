create or replace PACKAGE BODY      XXINV_K2_ITEM_OUTBOUND_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXINV_K2_ITEM_OUTBOUND_PKG.bdy
Author's Name:   Sandeep Akula
Date Written:    8-JULY-2014
Purpose:         Used in K2 Item Outbound Program
Program Style:   Stored Package Body
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
8-JULY-2014        1.0                  Sandeep Akula    Initial Version
---------------------------------------------------------------------------------------------------*/
PROCEDURE MAIN(errbuf OUT VARCHAR2,
               retcode OUT NUMBER,
               p_data_dir IN VARCHAR2,
               p_inv_org IN NUMBER,
               p_override_last_run_date IN VARCHAR2) IS


CURSOR c_items(cp_last_run_date IN DATE) IS
SELECT msi.segment1 item_number,
  msi.description,
  msi.lot_control_code,
  msi.serial_number_control_code,
  DECODE(msi.serial_number_control_code,'1','No','Yes') Serialized,
  DECODE(msi.lot_control_code,'1','No','Yes') lot_controlled,
  msi.unit_weight,
  msi.weight_uom_code,
  msi.unit_volume,
  msi.volume_uom_code,
  msi.unit_length,
  msi.unit_width,
  msi.unit_height,
  msi.dimension_uom_code,
  msi.hazard_class_id,
  msi.hazardous_material_flag,
  phc.hazard_class,
  phc.description hazard_class_descr,
  msi.inventory_item_id
FROM mtl_system_items_b msi,
     po_hazard_classes phc
WHERE msi.hazard_class_id = phc.hazard_class_id(+)
AND msi.organization_id   = p_inv_org
--and msi.creation_date > to_date(cp_last_run_date,'MM/DD/RRRR HH24:MI:SS');
and msi.creation_date > cp_last_run_date;


file_handle               UTL_FILE.FILE_TYPE;
l_instance_name   v$database.name%type;
l_directory       VARCHAR2(2000);
l_file_creation_date VARCHAR2(100);
l_count           NUMBER := '';
l_prg_exe_counter        NUMBER := '';
l_file_name              VARCHAR2(200) := '';
l_error_message          varchar2(32767) := '';
l_message                     VARCHAR2 (200);
l_mail_list VARCHAR2(500);
l_err_code  NUMBER;
l_err_msg   VARCHAR2(200);
l_last_run_date DATE;
l_request_id   NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
l_tbl_count    NUMBER;
l_serialized   VARCHAR2(10);
l_lot_controlled   VARCHAR2(10);
l_actual_last_run_date DATE;

BEGIN

FND_FILE.PUT_LINE(FND_FILE.LOG,'Inside Program');

 l_prg_exe_counter := '0';

                     -- Deriving the Instance Name

                      l_error_message := 'Instance Name could not be found';

                      SELECT NAME
                      INTO  l_INSTANCE_NAME
                      FROM V$DATABASE;


                      -- Deriving the Directory Path

                       l_error_message := 'Directory Path Could not be Found';

                        SELECT p_data_dir
                        INTO  l_DIRECTORY
                        FROM DUAL;

        l_prg_exe_counter := '1';

 l_tbl_count := '';
 begin
 select count(*)
 into l_tbl_count
 from XXINV_K2_ITEM_EXTRACT
 where extract_type = 'K2_ITEM_EXTRACT';
 exception
 when others then
 l_tbl_count := '0';
 end;

 IF l_tbl_count = '0' THEN

 INSERT INTO XXINV_K2_ITEM_EXTRACT(LAST_RUN_DATE,
                                   EXTRACT_TYPE,
                                   CREATION_DATE,
                                   LAST_UPDATE_DATE)
                          VALUES(to_date('01/01/1800 00:00:00','MM/DD/RRRR HH24:MI:SS'),
                                 'K2_ITEM_EXTRACT',
                                 SYSDATE,
                                 SYSDATE);
COMMIT;
END IF;


 -- Extracting Last Run Date
 l_last_run_date := '';
 begin
 select last_run_date
 into l_last_run_date
 from XXINV_K2_ITEM_EXTRACT
 where extract_type = 'K2_ITEM_EXTRACT';
 exception
 when others then
 l_last_run_date := '';
 end;

 l_prg_exe_counter := '2';
 FND_FILE.PUT_LINE(FND_FILE.LOG,'l_last_run_date :'||l_last_run_date);

 l_error_message := ' Error Occured while checking condition for parameter p_override_last_run_date';
 IF p_override_last_run_date IS NULL THEN
     l_actual_last_run_date := l_last_run_date;
 ELSE
     l_actual_last_run_date := to_date(p_override_last_run_date,'RRRR/MM/DD HH24:MI:SS');
 END IF;

 l_prg_exe_counter := '2.1';
l_file_name:= '';
l_error_message := ' Error Occured while Deriving l_file_name';
l_file_name := 'K2ITEM'||'_'||to_char(sysdate,'MMDDRRRRHH24MISS')||'.txt';
l_prg_exe_counter := '3';

 -- File Handle for Outbound File
 l_error_message := 'Error Occured in UTL_FILE.FOPEN (FILE_HANDLE)';
FILE_HANDLE  := UTL_FILE.FOPEN(l_DIRECTORY,l_file_name,'W',32767);
l_prg_exe_counter := '4';
l_error_message   := 'Error Occured in UTL_FILE.PUT_LINE (FILE_HANDLE)';
UTL_FILE.PUT_LINE(FILE_HANDLE,'ITEM'||'^'||
                              'DESCRIPTION'||'^'||
                              'HAZARDOUS_MATERIAL_FLAG'||'^'||
                              'LOT_CONTROL'||'^'||
                              'SERIALIZED'||'^'||
                              'UNIT_WEIGHT'||'^'||
                              'WEIGHT_UOM_CODE'||'^'||
                              'UNIT_VOLUME'||'^'||
                              'VOLUME_UOM_CODE'||'^'||
                              'UNIT_LENGTH'||'^'||
                              'UNIT_WIDTH'||'^'||
                              'UNIT_HEIGHT'||'^'||
                              'DIMENSION_UOM_CODE');

l_prg_exe_counter := '5';
l_count := '0';
l_error_message := 'Error Occured While Opening Cursor c_items';
for c_1 in c_items(l_actual_last_run_date) loop
l_prg_exe_counter := '6';
-- Deriving Serialized and Lot Controlled Flags from OMA Org
 l_serialized := '';
 l_lot_controlled := '';
 begin
 select DECODE(msi.serial_number_control_code,'1','No','Yes'),
        DECODE(msi.lot_control_code,'1','No','Yes')
 into l_serialized,l_lot_controlled
 from mtl_system_items msi
 where inventory_item_id = c_1.inventory_item_id and
       organization_id = '91'; -- OMA Org
 exception
 when others then
 l_serialized := '';
 l_lot_controlled := '';
 end;

l_prg_exe_counter := '6.1';
l_error_message   := 'Error Occured in UTL_FILE.PUT_LINE (FILE_HANDLE)';
UTL_FILE.PUT_LINE(FILE_HANDLE,c_1.item_number||'|'|| -- item_number
c_1.description||'|'||                               -- description
c_1.hazardous_material_flag||'|'||                   -- hazardous_material_flag
--c_1.lot_controlled||'|'||                               -- Lot Control
--c_1.Serialized||'|'||                                   -- Serialized
l_lot_controlled||'|'||                              -- Lot Control
l_serialized||'|'||                                  -- Serialized
c_1.unit_weight||'|'||                               -- Unit Weight
c_1.weight_uom_code||'|'||                           -- Weight UOM Code
c_1.unit_volume||'|'||                               -- Unit Volume
c_1.volume_uom_code||'|'||                           -- Volume UOM Code
c_1.unit_length||'|'||                               -- Unit Length
c_1.unit_width||'|'||                                -- Unit Width
c_1.unit_height||'|'||                               -- Unit Height
c_1.dimension_uom_code                               -- Dimension UOM Code
);

l_count := l_count + 1;  -- Count of Records

end loop;

l_prg_exe_counter := '7';



               l_error_message := 'Error Occured while Updating LAST_RUN_DATE in XXINV_K2_ITEM_EXTRACT Table';
                        ---- UPDATING Last Run Date
                          UPDATE XXINV_K2_ITEM_EXTRACT
                          SET  LAST_RUN_DATE = SYSDATE,
                               LAST_UPDATE_DATE = SYSDATE
                          WHERE extract_type = 'K2_ITEM_EXTRACT';

       l_prg_exe_counter := '8';

       -- Output File

        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'------------------------------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'=========================  LOADING SUMMARY  ======================');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'-------------------------------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Request ID: ' || l_REQUEST_ID) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Instance Name: ' ||l_INSTANCE_NAME) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Directory Path is : ' ||l_DIRECTORY) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+======================  Parameters  ============================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'p_data_dir   :'||p_data_dir);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'p_inv_org   :'||p_inv_org);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================== End Of Parameters  ============================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'The File Name is : '||l_file_name);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Record Count is : '||(l_count));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'----------------------------------------------');
        l_prg_exe_counter := '9';

   l_error_message := 'Error Occured in Closing the FILE_HANDLE (file_handle)';
        UTL_FILE.FCLOSE(file_handle);
        l_prg_exe_counter := '10';

        IF l_count = '0' THEN
            l_prg_exe_counter := '11';
              BEGIN
                  UTL_FILE.fremove (l_DIRECTORY,l_file_name);
              EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                   l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : ZERO_RECORD_CNT - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                   retcode := '2';
                   errbuf := l_error_message;
                   FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                  l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : ZERO_RECORD_CNT - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                  FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                  retcode := '2';
                  errbuf := l_error_message;
              END;

        END IF;


l_prg_exe_counter := '12';
l_error_message := '';
COMMIT;
l_prg_exe_counter := '13';

EXCEPTION
WHEN NO_DATA_FOUND THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : NO_DATA_FOUND - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : NO_DATA_FOUND - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXINVK2ITEMOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN',
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'K2 Item Outbound failure - '||l_request_id,
                              p_body_text   => 'K2 Item Outbound Request Id :'||l_request_id||chr(10)||
                                                'Error Message :' ||l_error_message,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN UTL_FILE.INVALID_PATH THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.INVALID_PATH - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.INVALID_PATH - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXINVK2ITEMOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN',
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'K2 Item Outbound failure - '||l_request_id,
                              p_body_text   => 'K2 Item Outbound Request Id :'||l_request_id||chr(10)||
                                                'Error Message :' ||l_error_message,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN UTL_FILE.READ_ERROR THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.READ_ERROR - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.READ_ERROR - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXINVK2ITEMOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN',
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'K2 Item Outbound failure - '||l_request_id,
                              p_body_text   => 'K2 Item Outbound Request Id :'||l_request_id||chr(10)||
                                                'Error Message :' ||l_error_message,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN UTL_FILE.WRITE_ERROR THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.WRITE_ERROR - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.WRITE_ERROR - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXINVK2ITEMOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN',
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'K2 Item Outbound failure - '||l_request_id,
                              p_body_text   => 'K2 Item Outbound Request Id :'||l_request_id||chr(10)||
                                                'Error Message :' ||l_error_message,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN OTHERS THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : OTHERS - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : OTHERS - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXINVK2ITEMOUT');
xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN',
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'K2 Item Outbound failure - '||l_request_id,
                              p_body_text   => 'K2 Item Outbound Request Id :'||l_request_id||chr(10)||
                                                'Error Message :' ||l_error_message,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
END MAIN;
END XXINV_K2_ITEM_OUTBOUND_PKG;