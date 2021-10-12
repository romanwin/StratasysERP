create or replace PACKAGE  apps.XXAR_RECEIPTS_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXAR_RECEIPTS_PKG.spc
Author's Name:   Sandeep Akula
Date Written:    12-JAN-2015
Purpose:         Submits Program "Process Lockboxes (SRS)" to process Bank LockBox File
                 Programs Called:
                 1. Process Lockboxes (SRS) --> Custom Program calls this 
                 2. Process Lockboxes (Process Lockboxes) --> Program "Process Lockboxes (SRS)" calls this which eventually creates receipts in AR
Program Style:   Stored Package SPECIFICATION
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
12-JAN-2015        1.0                  Sandeep Akula    Initial Version -- CHG0033827
---------------------------------------------------------------------------------------------------*/
PROCEDURE MAIN(errbuf OUT VARCHAR2,
               retcode OUT NUMBER,
               p_bpel_instance_id IN NUMBER,
               p_file_name IN VARCHAR2,
               p_file_path IN VARCHAR2,
               p_transmission_format_id IN NUMBER,
               p_control_file IN VARCHAR2,
               p_lockbox_id IN NUMBER);
               
END XXAR_RECEIPTS_PKG;
/
