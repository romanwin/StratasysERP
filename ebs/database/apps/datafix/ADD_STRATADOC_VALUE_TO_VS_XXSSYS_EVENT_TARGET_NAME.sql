DECLARE
----------------------------------------------------------------------------------------------
-- Ver       Who         When          Description
-- --------  ----------  ------------  -------------------------------------------------------
-- 1.1       01-05-2018  Roman.W       CHG0042545-Vendors interface from Oracle to Stratadoc
--                                     Add value to VS : XXSSYS_EVENT_TARGET_NAME
--                                                       XXSSYS_EVENT_ENTITY_NAME
--                                     for interface monitoring form
----------------------------------------------------------------------------------------------
   l_independent_out          VARCHAR2(200);
   l_dependent_out            VARCHAR2(200);
   l_msg                      VARCHAR2(2000);
BEGIN

   ----------------- Create Value in Independent VS -----------------
   FND_FLEX_VAL_API.create_independent_vset_value(p_flex_value_set_name           => 'XXSSYS_EVENT_TARGET_NAME'
                                                    ,p_flex_value                 => 'STRATADOC'
                                                    ,p_description                => 'Stratadoc'
                                                    ,p_enabled_flag               => 'Y'
                                                    ,p_start_date_active          => NULL
                                                    ,p_end_date_active            => NULL
                                                    ,p_summary_flag               => 'N'
                                                    ,p_structured_hierarchy_level => NULL
                                                    ,p_hierarchy_level            => NULL
                                                    ,x_storage_value              => l_independent_out
                                                    );

   DBMS_OUTPUT.put_line(' l_independent_out :' || l_independent_out);
   
   fnd_flex_loader_apis.up_value_set_value(
                     p_upload_phase               => 'BEGIN',
                     p_upload_mode                => NULL,
                     p_custom_mode                => 'FORCE',
                     p_flex_value_set_name        => 'XXSSYS_EVENT_ENTITY_NAME',
                     p_parent_flex_value_low      => 'STRATADOC',
                     p_flex_value                 => 'VENDORSITE',
                     p_owner                      => NULL,
                     p_last_update_date           => TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS'),
                     p_enabled_flag               => 'Y',
                     p_summary_flag               => 'N',
                     p_start_date_active          => NULL,
                     p_end_date_active            => NULL,
                     p_parent_flex_value_high     => NULL,
                     p_rollup_flex_value_set_name => NULL,
                     p_rollup_hierarchy_code      => NULL,
                     p_hierarchy_level            => NULL,
                     p_compiled_value_attributes  => NULL,
                     p_value_category             => 'XXSSYS_EVENT_ENTITY_NAME',
                     p_attribute1                 => '.', --'xxhz_ecomm_message_pkg.generate_account_data(:EVENT_ID, :ENTITY_ID, :ATTRIBUTE1, :ACTIVE_FLAG)',
                     p_attribute2                 => NULL,
                     p_attribute3                 => NULL,
                     p_attribute4                 => NULL,
                     p_attribute5                 => NULL,
                     p_attribute6                 => NULL,
                     p_attribute7                 => NULL,
                     p_attribute8                 => NULL,
                     p_attribute9                 => NULL,
                     p_attribute10                => NULL,
                     p_attribute11                => NULL,
                     p_attribute12                => NULL,
                     p_attribute13                => NULL,
                     p_attribute14                => NULL,
                     p_attribute15                => NULL,
                     p_attribute16                => NULL,
                     p_attribute17                => NULL,
                     p_attribute18                => NULL,
                     p_attribute19                => NULL,
                     p_attribute20                => NULL,
                     p_attribute21                => NULL,
                     p_attribute22                => NULL,
                     p_attribute23                => NULL,
                     p_attribute24                => NULL,
                     p_attribute25                => NULL,
                     p_attribute26                => NULL,
                     p_attribute27                => NULL,
                     p_attribute28                => NULL,
                     p_attribute29                => NULL,
                     p_attribute30                => NULL,
                     p_attribute31                => NULL,
                     p_attribute32                => NULL,
                     p_attribute33                => NULL,
                     p_attribute34                => NULL,
                     p_attribute35                => NULL,
                     p_attribute36                => NULL,
                     p_attribute37                => NULL,
                     p_attribute38                => NULL,
                     p_attribute39                => NULL,
                     p_attribute40                => NULL,
                     p_attribute41                => NULL,
                     p_attribute42                => NULL,
                     p_attribute43                => NULL,
                     p_attribute44                => NULL,
                     p_attribute45                => NULL,
                     p_attribute46                => NULL,
                     p_attribute47                => NULL,
                     p_attribute48                => NULL,
                     p_attribute49                => NULL,
                     P_ATTRIBUTE50                => NULL,
                     p_flex_value_meaning         => 'VENDORSITE',
                     p_description                => 'Vendor Site'
                     );   
      
      COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    l_msg:=fnd_flex_val_api.message;
    dbms_output.put_line('--------------- message --------------');
    DBMS_OUTPUT.PUT_LINE(l_msg);
    dbms_output.put_line('--------------- SQLERRM --------------');
    DBMS_OUTPUT.PUT_LINE('Error is ' || SUBSTR (SQLERRM, 1, 1000));  
END;
/
