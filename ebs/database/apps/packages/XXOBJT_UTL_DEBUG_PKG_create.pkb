CREATE OR REPLACE PACKAGE BODY xxobjt_utl_debug_pkg AS
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
    10-AUG-2014 1.1      MMAZANET           CHG0031576 - See code comment
***********************************************************************************************************************/

   g_logging_flag              BOOLEAN;
   g_logging_level             NUMBER  := 1;
   g_debug_flag                BOOLEAN := TRUE;
   g_message_header_id         xxobjt_utl_debug.message_header_id%TYPE;
   g_log_type                  VARCHAR2(50) DEFAULT 'DATABASE';
   g_program_name              VARCHAR2(250);
   g_program_subroutine_name   VARCHAR2(250);
   g_program_subroutine_string VARCHAR2(4000);

   -- ---------------------------------------------------------------------
   -- Debugging procedure to dbg this package.  This uses piping to make
   -- messages available in a different session.  
   -- ---------------------------------------------------------------------
   PROCEDURE dbg (p_msg VARCHAR2)
   IS
      l_pipe_name   VARCHAR2 (25) := 'XXOBJT_UTL_DEBUG';
      l_status      NUMBER;
   BEGIN
      -- Internal debugging uses the pipemon program
      IF g_debug_flag THEN
        DBMS_PIPE.pack_message (SYSDATE);
        DBMS_PIPE.pack_message (p_msg);
        l_status := DBMS_PIPE.send_message (l_pipe_name, 0);

        IF (l_status = 1) THEN
          DBMS_PIPE.PURGE (l_pipe_name);
          l_status := DBMS_PIPE.send_message (l_pipe_name, 0);
        END IF;
      END IF;
   END dbg;

   
   -- -------------------------------------------------------------------
   -- insert header level message for xxobjt_utl_debug
   -- -------------------------------------------------------------------
   PROCEDURE insert_message_header
   IS PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      INSERT INTO xxobjt_utl_debug(
         message_header_id 
      ,  program         
      ,  session_id        
      ,  request_id        
      ,  fnd_user_id       
      ,  creation_date         
      )
      VALUES(
         g_message_header_id
      ,  g_program_name
      ,  userenv('SESSIONID')
      ,  fnd_global.conc_request_id
      ,  fnd_global.user_id
      ,  SYSDATE
      );
      
      COMMIT;  
   EXCEPTION
      WHEN OTHERS THEN
         dbg('Error in insert_message_line: '||SQLERRM);         
   END insert_message_header;

   -- -------------------------------------------------------------------
   -- insert line level message for xxobjt_utl_debug
   -- -------------------------------------------------------------------
   PROCEDURE insert_message_line(
      p_msg VARCHAR2
   ,  p_key VARCHAR2
   )
   IS PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      INSERT INTO xxobjt_utl_debug_lines(
         message_line_id    
      ,  message_header_id            
      ,  program_sub_routine
      ,  key
      ,  message
      ,  creation_date      
      )
      VALUES(
         xxobjt_utl_debug_lines_s.NEXTVAL    
      ,  g_message_header_id           
      ,  g_program_subroutine_name
      ,  p_key
      ,  p_msg           
      ,  SYSDATE  
      );
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         dbg('Error in insert_message_line: '||SQLERRM);   
   END insert_message_line;

   -- -------------------------------------------------------------------
   -- Checks lookup_type = XXOBJT_DEBUG lookup_code = <p_prog_name>. 
   -- meaning holds value of Y or N to turn debug on or off.  attribute1
   -- holds the debug level if one exists.
   -- ------------------------------------------------------------------
   PROCEDURE is_logging_enabled(
      p_prog_name   IN  VARCHAR2
   ,  x_debug_flag  OUT VARCHAR2
   ,  x_debug_level OUT NUMBER
   )
   IS
   BEGIN
      dbg('p_prog_name: '||p_prog_name);
      
      SELECT 
         NVL(enabled_flag,'N')
      ,  attribute1
      INTO 
         x_debug_flag
      ,  x_debug_level
      FROM  
         FND_LOOKUP_VALUES_VL   ffvv
      WHERE ffvv.lookup_type  = 'XXOBJT_DEBUG'
      AND   ffvv.lookup_code  = p_prog_name
      AND   TRUNC(SYSDATE)    BETWEEN NVL(start_date_active,'01-JAN-1951')
                                 AND NVL(end_date_active, '31-DEC-4999');
   EXCEPTION
      WHEN OTHERS THEN
         x_debug_flag := 'N';
         dbg('Error in is_logging_enabled: '||SQLERRM);
   END is_logging_enabled;

   -- -------------------------------------------------------------------
   -- Initialize logging 
   -- -------------------------------------------------------------------   
   PROCEDURE initialize_logging(
      p_prog_name  IN VARCHAR2
   ,  p_log_type   IN VARCHAR2 DEFAULT 'DATABASE'
   ,  p_delete_key IN VARCHAR2 DEFAULT 'X'
   )
   IS 
      l_logging_flag  VARCHAR2(1);
      l_debug_flag    VARCHAR2(1);
      x_errbuff       VARCHAR2(4000);
      x_retcode       NUMBER;
   BEGIN
      -- Checking for lookup for debug of this program.  This is done with piping
      is_logging_enabled(
         p_prog_name   => 'XXOBJT_UTL_DEBUG'
      ,  x_debug_flag  => l_logging_flag 
      ,  x_debug_level => l_debug_flag
      );
          
      IF l_logging_flag = 'Y' THEN
         g_debug_flag := TRUE;
      END IF;
      
      -- If we want to delete out existing messages for a paticular key value in debug tables
      IF p_delete_key <> 'X' THEN
         clean_dbg_message_tables(
            errbuff     => x_errbuff
         ,  retcode     => x_retcode
         ,  p_key       => p_delete_key);
      END IF;
      
      -- Looking for lookup_type = XXOBJT_DEBUG lookup_code = <p_prog_name>   
      is_logging_enabled(
         p_prog_name   => p_prog_name
      ,  x_debug_flag  => l_logging_flag 
      ,  x_debug_level => g_logging_level
      );      
      
      dbg('l_logging_flag ['||l_logging_flag||']');
      dbg('g_logging_level ['||g_logging_level||']');
      
      IF l_logging_flag = 'Y' THEN
         g_logging_flag := TRUE;
         g_program_name := SUBSTR(p_prog_name,1,250);
         dbg('g_program_name ['||g_program_name||']');
      ELSE 
         g_logging_flag := FALSE;
      END IF;
      
      -- If level not set, logging level set to show all messages
      IF g_logging_level IS NULL THEN
         g_logging_level := 1;
      END IF;
      
      IF g_logging_flag THEN
         
         g_log_type := p_log_type;
         dbg('g_program_name ['||g_log_type||']');
         
         IF g_log_type = 'DATABASE' THEN
            
            SELECT xxobjt_utl_debug_s.NEXTVAL
            INTO g_message_header_id
            FROM DUAL;
            
            dbg('Calling insert_message_header for message_header_id ['||g_message_header_id||']');
            insert_message_header;
         
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN 
          RAISE_APPLICATION_ERROR(-20000,'Error xxobjt_utl_debug '||SQLERRM);
   END initialize_logging;

   -- -----------------------------------------------------------------------
   -- Stops logging
   -- -----------------------------------------------------------------------
   PROCEDURE end_logging
   IS 
   BEGIN
      g_logging_flag              := FALSE;
      g_logging_level             := TO_NUMBER(NULL);
      g_debug_flag                := FALSE;
      g_message_header_id         := TO_NUMBER(NULL);
      g_log_type                  := NULL;
      g_program_name              := NULL;
      g_program_subroutine_name   := NULL;   
   END end_logging;

   -- -------------------------------------------------------------------
   -- Log message if logging is enabled and p_log_level >= user profile's
   -- log level
   -- -------------------------------------------------------------------   
   PROCEDURE log_msg(
      p_key       VARCHAR2 
   ,  p_msg       VARCHAR2
   ,  p_log_level NUMBER   DEFAULT 1
   )
   IS
   BEGIN
   dbg('g_program_name ['||g_program_name||']');
      IF g_logging_flag 
         AND p_log_level >= g_logging_level 
      THEN
         IF g_log_type = 'DATABASE' THEN
            insert_message_line(p_msg,p_key);
         ELSIF g_log_type = 'CONCURRENT' THEN
            fnd_file.put_line(fnd_file.log,p_msg);
         END IF;
      END IF;
   END log_msg;

   -- -------------------------------------------------------------------
   -- Adds sub_routine and message beginning sub-routine 
   -- -------------------------------------------------------------------   
   PROCEDURE start_proc(
      p_proc_name VARCHAR2
   ,  p_key       VARCHAR2 DEFAULT NULL
   ,  p_log_level NUMBER DEFAULT 1
   )
   IS
   BEGIN
      dbg('start_proc for p_proc_name ['||p_proc_name||']');
      dbg('g_program_subroutine_string ['||g_program_subroutine_string||']');
      dbg('g_program_subroutine_name ['||g_program_subroutine_name||']');      
      
      -- CHG0031576 - Added to check logging flag before proceeding
      IF g_logging_flag THEN
         -- Strings together subroutine string.  Let's say we have the following scenario:
         -- w calls x calls y calls z.  These will get strung together as follows:
         -- z~y~x~w.  We always pick off the first value before the '~'.  This is the 
         -- current code block we are in.  When we leave that code block, we call end_proc
         -- with will chop that block off the string.  So, for example, when we're done 
         -- with z, the g_program_subroutine_string will be y~x~w with g_program_subroutine_name
         -- set to y.
         g_program_subroutine_string   := p_proc_name||'~'||g_program_subroutine_string;
         g_program_subroutine_name     := p_proc_name;     

         dbg('g_program_subroutine_string ['||g_program_subroutine_string||']');
         dbg('g_program_subroutine_name ['||g_program_subroutine_name||']');
         
         log_msg(
            p_msg       => '--- Start '||g_program_subroutine_name||' ---'
         ,  p_key       => p_key
         ,  p_log_level => p_log_level
         );
      END IF;
   END start_proc;

   -- -------------------------------------------------------------------
   -- Adds message ending sub-routine and initializes g_program_subroutine_name
   -- -------------------------------------------------------------------   
   PROCEDURE end_proc(
      p_key       VARCHAR2 DEFAULT NULL
   ,  p_log_level NUMBER DEFAULT 1
   )
   IS
   BEGIN
      -- CHG0031576 - Added to check logging flag before proceeding
      IF g_logging_flag THEN
         log_msg(
            p_key       => p_key
         ,  p_msg       => '--- End '||g_program_subroutine_name||' ---'
         ,  p_log_level => p_log_level
         );

         -- Cuts the first code block off the g_program_subroutine_string (everthing to the first '~').  This is to 
         -- get us the correct g_program_subroutine_name in case we are levels deep in the code.  See comments in
         -- start_proc for full explanation
         g_program_subroutine_string   := TRIM(LEADING '~' FROM REGEXP_SUBSTR(g_program_subroutine_string, '~.*')); 
         g_program_subroutine_name     := SUBSTR(g_program_subroutine_string,1,INSTR(g_program_subroutine_string,'~')-1);
      END IF;
   END end_proc;

   -- -------------------------------------------------------------------
   -- Log message if logging is enabled and p_log_level >= user profile's
   -- log level
   -- -------------------------------------------------------------------   
   PROCEDURE log_err(
      p_key       VARCHAR2 
   ,  p_msg       VARCHAR2
   ,  p_log_level NUMBER DEFAULT 1
   )
   IS
   BEGIN
      log_msg(
         p_key       => p_key
      ,  p_msg       => '** Error ** '||p_msg
      ,  p_log_level => p_log_level);
      
      end_proc;
   END log_err;
  
   -- -------------------------------------------------------------------
   -- Clean up routine for message debug tables xxobjt_utl_debug and 
   -- xxobjt_utl_debug_lines.  This will be called from a concurrent
   -- program.
   -- -------------------------------------------------------------------   
   PROCEDURE clean_dbg_message_tables(
      errbuff     OUT VARCHAR2
   ,  retcode     OUT NUMBER
   ,  p_truncate  IN  VARCHAR2  DEFAULT 'N'
   ,  p_program   IN  VARCHAR2  DEFAULT NULL
   ,  p_user_id   IN  NUMBER    DEFAULT TO_NUMBER(NULL)
   ,  p_key       IN  VARCHAR2  DEFAULT NULL
   ,  p_from_date IN  DATE      DEFAULT TO_DATE(NULL)
   ,  p_to_date   IN  DATE      DEFAULT TO_DATE(NULL)
   )
   IS
      l_total_headers  NUMBER := 0;
      l_total_lines    NUMBER := 0;
      
      CURSOR c_delete_header
      IS
         SELECT message_header_id
         FROM xxobjt_utl_debug  xud
         WHERE program        = NVL(p_program,program)
         AND   fnd_user_id    = NVL(p_user_id,fnd_user_id)
         AND   creation_date  BETWEEN NVL(p_from_date,TO_DATE('01011951','MMDDYYYY'))
                                 AND NVL(p_to_date,TO_DATE('12314712','MMDDYYYY'))
         AND   EXISTS         (SELECT null
                               FROM xxobjt_utl_debug_lines  xudl
                               WHERE xud.message_header_id = xudl.message_header_id
                               AND   NVL(xudl.key,'X')     = NVL(p_key,NVL(key,'X')))
         FOR UPDATE OF message_header_id NOWAIT;
                                 
      CURSOR c_delete_line(p_message_header_id NUMBER)
      IS
         SELECT message_line_id
         FROM xxobjt_utl_debug_lines
         WHERE message_header_id = p_message_header_id
         FOR UPDATE OF message_line_id NOWAIT;
   BEGIN
      IF       NVL(p_truncate,'N')  = 'N'
         AND   p_program            IS NULL
         AND   p_user_id            IS NULL
         AND   p_key                IS NULL
         AND   p_to_date            IS NULL
         AND   p_from_date          IS NULL
      THEN
         fnd_file.put_line(fnd_file.output,'One of the parameters must be populated in order to proceed with record deletes');     
      ELSE
         IF p_truncate = 'Y' THEN
            EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxobjt_utl_debug_lines';
            EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxobjt_utl_debug';
            fnd_file.put_line(fnd_file.output,'All Logging Records Successfully Deleted');
         ELSE
            IF (p_to_date IS NOT NULL AND p_from_date IS NULL)
               OR (p_to_date IS NULL AND p_from_date IS NOT NULL) 
            THEN
               fnd_file.put_line(fnd_file.output,'To Date and From Date is a date range only one can NOT be populated');     
            ELSE
               -- Delete header and line records
               FOR header_rec IN c_delete_header LOOP
                  FOR line_rec IN c_delete_line(header_rec.message_header_id) LOOP
                     DELETE FROM xxobjt_utl_debug_lines
                     WHERE current of c_delete_line;
                     l_total_lines := l_total_lines + 1;
                  END LOOP;

                  DELETE FROM xxobjt_utl_debug
                  WHERE current of c_delete_header;
                  l_total_headers := l_total_headers + 1;
               END LOOP;
            END IF;
            
            fnd_file.put_line(fnd_file.output,'Total Logging Records Deleted');
            fnd_file.put_line(fnd_file.output,'******************************');
            fnd_file.put_line(fnd_file.output,'Header Records Deleted : '||l_total_headers);
            fnd_file.put_line(fnd_file.output,'Line Records Deleted   : '||l_total_lines);
         END IF;        
      END IF;
   EXCEPTION 
      WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.output,'The following error occurred while trying to delete log records: '||SQLERRM);
   END clean_dbg_message_tables;
   
END xxobjt_utl_debug_pkg;
/

GRANT EXECUTE ON xxobjt_utl_debug_pkg TO PUBLIC
/

SHOW ERRORS