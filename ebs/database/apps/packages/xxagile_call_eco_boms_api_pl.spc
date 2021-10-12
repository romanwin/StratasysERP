CREATE OR REPLACE PACKAGE xxagile_call_eco_boms_api_pl AS
   ---------------------------------------------------------------------------
   -- $Header: xxagile_call_eco_boms_api_pl 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Package: xxagile_call_eco_boms_api_pl
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: Agile procedures
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------

   -- Declare the conversion functions the PL/SQL type AC_A2O_PROC_ECO_ITEM_PKG.LREC_REF_DESEG_TYPE
   FUNCTION pl_to_sql12(aplsqlitem xxagile_process_eco_item_pkg.lrec_ref_deseg_type)
      RETURN xxagile_proc_eco_item_pkg17;
   FUNCTION sql_to_pl13(asqlitem xxagile_proc_eco_item_pkg17)
      RETURN xxagile_process_eco_item_pkg.lrec_ref_deseg_type;
   -- Declare the conversion functions the PL/SQL type XXAGILE_PROCESS_ECO_ITEM_PKG.LTAB_REF_DESEG_TYPE
   FUNCTION pl_to_sql13(aplsqlitem xxagile_process_eco_item_pkg.ltab_ref_deseg_type)
      RETURN xxagileprocecoitempkg15_ltab;
   FUNCTION sql_to_pl14(asqlitem xxagileprocecoitempkg15_ltab)
      RETURN xxagile_process_eco_item_pkg.ltab_ref_deseg_type;
   -- Declare the conversion functions the PL/SQL type XXAGILE_PROCESS_ECO_ITEM_PKG.LREC_COMPONENTS_TYPE
   FUNCTION pl_to_sql14(aplsqlitem xxagile_process_eco_item_pkg.lrec_components_type)
      RETURN xxagile_proc_eco_item_pkg15;
   FUNCTION sql_to_pl15(asqlitem xxagile_proc_eco_item_pkg15)
      RETURN xxagile_process_eco_item_pkg.lrec_components_type;
   -- Declare the conversion functions the PL/SQL type XXAGILE_PROCESS_ECO_ITEM_PKG.LTAB_COMPONENTS_TYPE
   FUNCTION pl_to_sql15(aplsqlitem xxagile_process_eco_item_pkg.ltab_components_type)
      RETURN xxagileprocecoitempkg13_ltab;
   FUNCTION sql_to_pl16(asqlitem xxagileprocecoitempkg13_ltab)
      RETURN xxagile_process_eco_item_pkg.ltab_components_type;
   -- Declare the conversion functions the PL/SQL type XXAGILE_PROCESS_ECO_ITEM_PKG.LREC_REVISED_ITEMS_TYPE
   FUNCTION pl_to_sql16(aplsqlitem xxagile_process_eco_item_pkg.lrec_revised_items_type)
      RETURN xxagile_proc_eco_item_pkg13;
   FUNCTION sql_to_pl17(asqlitem xxagile_proc_eco_item_pkg13)
      RETURN xxagile_process_eco_item_pkg.lrec_revised_items_type;
   -- Declare the conversion functions the PL/SQL type XXAGILE_PROCESS_ECO_ITEM_PKG.LTAB_REVISED_ITEMS_TYPE
   FUNCTION pl_to_sql17(aplsqlitem xxagile_process_eco_item_pkg.ltab_revised_items_type)
      RETURN xxagile_proc_eco_item_pkg12;
   FUNCTION sql_to_pl12(asqlitem xxagile_proc_eco_item_pkg12)
      RETURN xxagile_process_eco_item_pkg.ltab_revised_items_type;
   PROCEDURE xxagile_process_eco_item_pkg$p(p_eco_number          VARCHAR2,
                                            p_change_type_code    VARCHAR2,
                                            p_ecn_initiation_date DATE,
                                            p_revised_items       xxagile_proc_eco_item_pkg12,
                                            p_creation_dt         DATE,
                                            p_created_by          NUMBER,
                                            p_last_updated_dt     DATE,
                                            p_last_update_by      NUMBER,
                                            x_return_status       OUT VARCHAR2,
                                            x_error_code          OUT NUMBER,
                                            x_msg_count           OUT NUMBER,
                                            x_msg_data            OUT VARCHAR2);
END xxagile_call_eco_boms_api_pl;
/

