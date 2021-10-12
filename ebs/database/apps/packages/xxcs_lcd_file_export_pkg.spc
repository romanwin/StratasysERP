CREATE OR REPLACE PACKAGE xxcs_lcd_file_export_pkg IS

   ---------------------------------------------------------------------------
   -- $Header: xxagile_file_export_pkg 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Package: xxagile_call_eco_boms_api_pl
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: Agile output interface
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------

   PROCEDURE call_lcd_bpel_proc(errbuf OUT VARCHAR2, retcode OUT NUMBER);
END xxcs_lcd_file_export_pkg;
/

