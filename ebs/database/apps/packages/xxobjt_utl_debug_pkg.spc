CREATE OR REPLACE PACKAGE xxobjt_utl_debug_pkg AS
/**********************************************************************************************************************
    DESCRIPTION: Generic logging package.  Initial version has capability to log messages in database.  This could be 
                 expanded have additional g_log_type logging capabilities, such as writing to a file.  In order for 
                 logging to be turned on, the user must enter a lookup with the program name under the XXOBJT_DEBUG
                 lookup_type, if it's not already there.  Enable the lookup code to turn debug on.  Disable the lookup 
                 code to turn debug off.
                 
                 To use inside code
                 1. call initialize_logging.  
                 2. Call start_proc at the beginning of program units
                 3. Call log_msg to log messages
                 4. Call end_proc at the end to see beginning/ending messages for individual program units
                 5. Call log_err in exceptions (this also will call end_proc)
                 6. Call end_logging when complete
                 
                 Query XXOBJT_UTL_DEBUG_V to find your messages.
                 
    Install As:  apps
    
    Change History:
    Date        Ver      Name               Description
    ----------- ------   ------------------ -------------------------------------------
    28-JUN-2013 1.0      MMAZANET           CHG0031493 - Initial Creation.
***********************************************************************************************************************/

   PROCEDURE initialize_logging(
      p_prog_name  IN VARCHAR2
   ,  p_log_type   IN VARCHAR2 DEFAULT 'DATABASE'
   ,  p_delete_key IN VARCHAR2 DEFAULT 'X'
   );

   PROCEDURE end_logging;
   
   PROCEDURE log_msg(
      p_key       VARCHAR2 
   ,  p_msg       VARCHAR2
   ,  p_log_level NUMBER DEFAULT 1
   );
   
   PROCEDURE start_proc(
      p_proc_name VARCHAR2
   ,  p_key       VARCHAR2 DEFAULT NULL
   ,  p_log_level NUMBER DEFAULT 1
   );

   PROCEDURE end_proc(
      p_key       VARCHAR2 DEFAULT NULL
   ,  p_log_level NUMBER DEFAULT 1
   );
   
   PROCEDURE log_err(
      p_key       VARCHAR2 
   ,  p_msg       VARCHAR2
   ,  p_log_level NUMBER DEFAULT 1
   );
   
   PROCEDURE clean_dbg_message_tables(
      errbuff     OUT VARCHAR2
   ,  retcode     OUT NUMBER
   ,  p_truncate  IN  VARCHAR2  DEFAULT 'N'
   ,  p_program   IN  VARCHAR2  DEFAULT NULL
   ,  p_user_id   IN  NUMBER    DEFAULT TO_NUMBER(NULL)
   ,  p_key       IN  VARCHAR2  DEFAULT NULL
   ,  p_from_date IN  DATE      DEFAULT TO_DATE(NULL)
   ,  p_to_date   IN  DATE      DEFAULT TO_DATE(NULL)
   );
   
END xxobjt_utl_debug_pkg;
/

SHOW ERRORS
