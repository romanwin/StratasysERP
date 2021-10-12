CREATE OR REPLACE PACKAGE XXMSC_GENERAL_PKG IS

   -- Author  : Bellona.B
   -- Created : 21/11/2019
   -- Purpose :
  --------------------------------------------------------------------
  --  ver   date         name            desc
  --  1.0   21/11/2019  Bellona(TCS)   CHG0046573- SP-IR -  recommendation
  --                                    qty according to Planning custom logic.
  --  1.1   06/01/2020  Bellona(TCS)   CHG0047106 - added new parameter
  --------------------------------------------------------------------
PROCEDURE msc_sp_recomm_ir_qty(errbuf                 OUT VARCHAR2,
                               retcode                OUT VARCHAR2,
                               p_plan_name            IN VARCHAR2,
                               p_source_org           IN VARCHAR2,
                               p_dest_org             IN VARCHAR2,
                               p_source_subinv        IN VARCHAR2,
                               p_source_loc           IN VARCHAR2,
                               p_period_days          IN NUMBER,
                               p_load_ir              IN VARCHAR2,
                               p_directory_name       IN VARCHAR2
                               ,p_submit_approval       IN VARCHAR2);  --CHG0047106


END XXMSC_GENERAL_PKG;
/
