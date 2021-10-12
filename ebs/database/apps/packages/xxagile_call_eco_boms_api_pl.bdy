CREATE OR REPLACE PACKAGE BODY xxagile_call_eco_boms_api_pl IS
   FUNCTION pl_to_sql12(aplsqlitem xxagile_process_eco_item_pkg.lrec_ref_deseg_type)
      RETURN xxagile_proc_eco_item_pkg17 IS
      asqlitem xxagile_proc_eco_item_pkg17;
   BEGIN
      -- initialize the object
      asqlitem                  := xxagile_proc_eco_item_pkg17(NULL);
      asqlitem.p_ref_designator := aplsqlitem.p_ref_designator;
      RETURN asqlitem;
   END pl_to_sql12;
   FUNCTION sql_to_pl13(asqlitem xxagile_proc_eco_item_pkg17)
      RETURN xxagile_process_eco_item_pkg.lrec_ref_deseg_type IS
      aplsqlitem xxagile_process_eco_item_pkg.lrec_ref_deseg_type;
   BEGIN
      aplsqlitem.p_ref_designator := asqlitem.p_ref_designator;
      RETURN aplsqlitem;
   END sql_to_pl13;
   FUNCTION pl_to_sql13(aplsqlitem xxagile_process_eco_item_pkg.ltab_ref_deseg_type)
      RETURN xxagileprocecoitempkg15_ltab IS
      asqlitem xxagileprocecoitempkg15_ltab;
   BEGIN
      -- initialize the table
      asqlitem := xxagileprocecoitempkg15_ltab();
      asqlitem.EXTEND(aplsqlitem.COUNT);
      FOR i IN aplsqlitem.FIRST .. aplsqlitem.LAST LOOP
         asqlitem(i + 1 - aplsqlitem.FIRST) := pl_to_sql12(aplsqlitem(i));
      END LOOP;
      RETURN asqlitem;
   END pl_to_sql13;
   FUNCTION sql_to_pl14(asqlitem xxagileprocecoitempkg15_ltab)
      RETURN xxagile_process_eco_item_pkg.ltab_ref_deseg_type IS
      aplsqlitem xxagile_process_eco_item_pkg.ltab_ref_deseg_type;
   BEGIN
      FOR i IN 1 .. asqlitem.COUNT LOOP
         aplsqlitem(i) := sql_to_pl13(asqlitem(i));
      END LOOP;
      RETURN aplsqlitem;
   END sql_to_pl14;
   FUNCTION pl_to_sql14(aplsqlitem xxagile_process_eco_item_pkg.lrec_components_type)
      RETURN xxagile_proc_eco_item_pkg15 IS
      asqlitem xxagile_proc_eco_item_pkg15;
   BEGIN
      -- initialize the object
      asqlitem                     := xxagile_proc_eco_item_pkg15(NULL,
                                                                  NULL,
                                                                  NULL,
                                                                  NULL,
                                                                  NULL,
                                                                  NULL,
                                                                  NULL,
                                                                  NULL);
      asqlitem.p_component_seq_num := aplsqlitem.p_component_seq_num;
      asqlitem.p_component         := aplsqlitem.p_component;
      asqlitem.p_component_qty     := aplsqlitem.p_component_qty;
      asqlitem.p_ref_designator    := pl_to_sql13(aplsqlitem.p_ref_designator);
      asqlitem.p_balloon           := aplsqlitem.p_balloon;
      asqlitem.p_comments          := aplsqlitem.p_comments;
      asqlitem.p_acd_flag          := aplsqlitem.p_acd_flag;
      asqlitem.p_disable_date      := aplsqlitem.p_disable_date;
      RETURN asqlitem;
   END pl_to_sql14;
   FUNCTION sql_to_pl15(asqlitem xxagile_proc_eco_item_pkg15)
      RETURN xxagile_process_eco_item_pkg.lrec_components_type IS
      aplsqlitem xxagile_process_eco_item_pkg.lrec_components_type;
   BEGIN
      aplsqlitem.p_component_seq_num := asqlitem.p_component_seq_num;
      aplsqlitem.p_component         := asqlitem.p_component;
      aplsqlitem.p_component_qty     := asqlitem.p_component_qty;
      aplsqlitem.p_ref_designator    := sql_to_pl14(asqlitem.p_ref_designator);
      aplsqlitem.p_balloon           := asqlitem.p_balloon;
      aplsqlitem.p_comments          := asqlitem.p_comments;
      aplsqlitem.p_acd_flag          := asqlitem.p_acd_flag;
      aplsqlitem.p_disable_date      := asqlitem.p_disable_date;
      RETURN aplsqlitem;
   END sql_to_pl15;
   FUNCTION pl_to_sql15(aplsqlitem xxagile_process_eco_item_pkg.ltab_components_type)
      RETURN xxagileprocecoitempkg13_ltab IS
      asqlitem xxagileprocecoitempkg13_ltab;
   BEGIN
      -- initialize the table
      asqlitem := xxagileprocecoitempkg13_ltab();
      asqlitem.EXTEND(aplsqlitem.COUNT);
      FOR i IN aplsqlitem.FIRST .. aplsqlitem.LAST LOOP
         asqlitem(i + 1 - aplsqlitem.FIRST) := pl_to_sql14(aplsqlitem(i));
      END LOOP;
      RETURN asqlitem;
   END pl_to_sql15;
   FUNCTION sql_to_pl16(asqlitem xxagileprocecoitempkg13_ltab)
      RETURN xxagile_process_eco_item_pkg.ltab_components_type IS
      aplsqlitem xxagile_process_eco_item_pkg.ltab_components_type;
   BEGIN
      FOR i IN 1 .. asqlitem.COUNT LOOP
         aplsqlitem(i) := sql_to_pl15(asqlitem(i));
      END LOOP;
      RETURN aplsqlitem;
   END sql_to_pl16;
   FUNCTION pl_to_sql16(aplsqlitem xxagile_process_eco_item_pkg.lrec_revised_items_type)
      RETURN xxagile_proc_eco_item_pkg13 IS
      asqlitem xxagile_proc_eco_item_pkg13;
   BEGIN
      -- initialize the object
      asqlitem                        := xxagile_proc_eco_item_pkg13(NULL,
                                                                     NULL,
                                                                     NULL,
                                                                     NULL,
                                                                     NULL,
                                                                     NULL,
                                                                     NULL);
      asqlitem.p_assembly             := aplsqlitem.p_assembly;
      asqlitem.p_new_assembly_itm_rev := aplsqlitem.p_new_assembly_itm_rev;
      asqlitem.p_old_assembly_itm_rev := aplsqlitem.p_old_assembly_itm_rev;
      asqlitem.p_effective_date       := aplsqlitem.p_effective_date;
      asqlitem.p_old_effective_date   := aplsqlitem.p_old_effective_date;
      asqlitem.p_components_tbl       := pl_to_sql15(aplsqlitem.p_components_tbl);
      asqlitem.p_owner_organization   := aplsqlitem.p_owner_organization;
      RETURN asqlitem;
   END pl_to_sql16;
   FUNCTION sql_to_pl17(asqlitem xxagile_proc_eco_item_pkg13)
      RETURN xxagile_process_eco_item_pkg.lrec_revised_items_type IS
      aplsqlitem xxagile_process_eco_item_pkg.lrec_revised_items_type;
   BEGIN
      aplsqlitem.p_assembly             := asqlitem.p_assembly;
      aplsqlitem.p_new_assembly_itm_rev := asqlitem.p_new_assembly_itm_rev;
      aplsqlitem.p_old_assembly_itm_rev := asqlitem.p_old_assembly_itm_rev;
      aplsqlitem.p_effective_date       := asqlitem.p_effective_date;
      aplsqlitem.p_old_effective_date   := asqlitem.p_old_effective_date;
      aplsqlitem.p_components_tbl       := sql_to_pl16(asqlitem.p_components_tbl);
      aplsqlitem.p_owner_organization   := asqlitem.p_owner_organization;
      RETURN aplsqlitem;
   END sql_to_pl17;
   FUNCTION pl_to_sql17(aplsqlitem xxagile_process_eco_item_pkg.ltab_revised_items_type)
      RETURN xxagile_proc_eco_item_pkg12 IS
      asqlitem xxagile_proc_eco_item_pkg12;
   BEGIN
      -- initialize the table
      asqlitem := xxagile_proc_eco_item_pkg12();
      asqlitem.EXTEND(aplsqlitem.COUNT);
      FOR i IN aplsqlitem.FIRST .. aplsqlitem.LAST LOOP
         asqlitem(i + 1 - aplsqlitem.FIRST) := pl_to_sql16(aplsqlitem(i));
      END LOOP;
      RETURN asqlitem;
   END pl_to_sql17;
   FUNCTION sql_to_pl12(asqlitem xxagile_proc_eco_item_pkg12)
      RETURN xxagile_process_eco_item_pkg.ltab_revised_items_type IS
      aplsqlitem xxagile_process_eco_item_pkg.ltab_revised_items_type;
   BEGIN
      FOR i IN 1 .. asqlitem.COUNT LOOP
         aplsqlitem(i) := sql_to_pl17(asqlitem(i));
      END LOOP;
      RETURN aplsqlitem;
   END sql_to_pl12;

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
                                            x_msg_data            OUT VARCHAR2) IS
      p_revised_items_ apps.xxagile_process_eco_item_pkg.ltab_revised_items_type;
   BEGIN
      p_revised_items_ := xxagile_call_eco_boms_api_pl.sql_to_pl12(p_revised_items);
      --Arik changed parameter P_REVISED_ITEMS_ ==> P_REVISED_ITEMS
      apps.xxagile_process_eco_item_pkg.process_eco_item(p_eco_number,
                                                         p_change_type_code,
                                                         p_ecn_initiation_date,
                                                         p_revised_items /*_*/,
                                                         p_creation_dt,
                                                         p_created_by,
                                                         p_last_updated_dt,
                                                         p_last_update_by,
                                                         x_return_status,
                                                         x_error_code,
                                                         x_msg_count,
                                                         x_msg_data);
   END xxagile_process_eco_item_pkg$p;

END xxagile_call_eco_boms_api_pl;
/

