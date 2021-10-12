CREATE OR REPLACE PACKAGE BODY xxinv_item_org_assign_pkg AS
  --------------------------------------------------------------------
  --  customization code:
  --  name:               XXINV_ITEM_ORG_ASSIGN_PKG
  --  create by:
  --  $Revision:          1.0
  --  creation date:
  --  Purpose:
  --------------------------------------------------------------------
  --  ver   date          name             desc
  --  1.0   18.08.2013    Vitaly           CR 870 std cost - change hard-coded organization
  --                                       modify get_org_assign_account : support new chart of account
  --  1.1   09.03.14      yuval tal        CHG0031399 - process_org_assignments - Bug in Org Assignment Procedure
  --                                       values from master were overide by inner assignment in loop
  --------------------------------------------------------------------
  g_tax_code_control_level   NUMBER;
  g_p_tax_code_control_level NUMBER;
  --Building record from master org.
  PROCEDURE build_item_record(p_item_rec      IN OUT NOCOPY inv_item_api.item_rec_type,
                              p_master_org_id IN NUMBER,
                              x_master_status OUT NOCOPY mtl_system_items_b.approval_status%TYPE);

  -----------------------------------------------------------------------
  -- get_org_assign_account
  --------------------------------------------------------------------
  --  ver   date          name             desc
  --  1.0   18.08.2013    yuval tal      CR 870 modify get_org_assign_account : support new chart of account
  --------------------------------------------------------------------
  FUNCTION get_org_assign_account(p_organization_id NUMBER,
                                  p_param_account   NUMBER,
                                  p_item_account    NUMBER,
                                  p_return_status   OUT VARCHAR2,
                                  p_err_msg         OUT VARCHAR2)
    RETURN NUMBER IS
  
    segments               fnd_flex_ext.segmentarray;
    l_coa_id               NUMBER;
    l_org_id               NUMBER;
    l_org_account          NUMBER;
    l_coa_name             VARCHAR2(50);
    v_new_concatenated_seg VARCHAR2(500);
  BEGIN
  
    SELECT segment1,
           segment2,
           segment3,
           segment4,
           --------
           segment6,
           segment7,
           segment8,
           segment9,
           segment10
      INTO segments(1),
           segments(2),
           segments(3),
           segments(4),
           ----------
           segments(6),
           segments(7),
           segments(8),
           segments(9),
           segments(10)
      FROM gl_code_combinations
     WHERE code_combination_id = p_param_account;
  
    SELECT segment5
      INTO segments(5)
      FROM gl_code_combinations
     WHERE code_combination_id = p_item_account;
  
    BEGIN
    
      SELECT code_combination_id
        INTO l_org_account
        FROM gl_code_combinations
       WHERE segment1 = segments(1)
         AND segment2 = segments(2)
         AND segment3 = segments(3)
         AND nvl(segment4, '-1') = nvl(segments(4), '-1')
         AND segment5 = segments(5)
         AND segment6 = segments(6)
         AND segment7 = segments(7)
         AND nvl(segment8, '-1') = nvl(segments(8), '-1')
         AND segment9 = segments(9)
         AND nvl(segment10, '-1') = nvl(segments(10), '-1');
    
    EXCEPTION
      WHEN no_data_found THEN
      
        l_coa_id   := xxgl_utils_pkg.get_coa_id_from_inv_org(p_organization_id,
                                                             l_org_id);
        l_coa_name := xxinv_upd_org_item_pkg.get_coa_name(l_coa_id);
        IF l_coa_name = 'XX_STRATASYS_USD' THEN
          v_new_concatenated_seg :=  -----item_rec.org_cost_of_sales_segment1 || '.' ||
           segments(1) || '.' || segments(2) || '.' ||
                                    segments(3) || '.' || segments(5) || '.' ||
                                    segments(6) || '.' || segments(7) || '.' ||
                                    '000' || '.' || '0000';
        
        ELSE
          v_new_concatenated_seg :=  -----item_rec.org_cost_of_sales_segment1 || '.' ||
           segments(1) || '.' || segments(2) || '.' ||
                                    segments(3) || '.' || segments(4) || '.' ||
                                    segments(5) || '.' || segments(6) || '.' ||
                                    segments(7) || '.' || segments(8) || '.' ||
                                    segments(9);
        
        END IF;
      
        xxgl_utils_pkg.get_and_create_account(p_concat_segment      => v_new_concatenated_seg,
                                              p_coa_id              => l_coa_id,
                                              x_code_combination_id => l_org_account,
                                              x_return_code         => p_return_status,
                                              x_err_msg             => p_err_msg);
      
    END;
  
    RETURN l_org_account;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN p_param_account;
  END get_org_assign_account;

  --Procedure to org specific validations.
  --Bug: 5438006 Added parameter base_item_id
  PROCEDURE item_org_validations(p_org_code                   IN VARCHAR2,
                                 p_organization_id            IN NUMBER,
                                 p_tracking_quantity_ind      IN VARCHAR2,
                                 p_bom_enabled_flag           IN VARCHAR2,
                                 p_bom_item_type              IN NUMBER,
                                 p_outsourced_assembly        IN NUMBER,
                                 p_release_time_fence_code    IN NUMBER,
                                 p_subcontracting_component   IN NUMBER,
                                 x_return_status              OUT NOCOPY VARCHAR2,
                                 x_msg_count                  OUT NOCOPY NUMBER,
                                 p_context                    IN VARCHAR2 DEFAULT NULL,
                                 x_error_code                 OUT NOCOPY VARCHAR2,
                                 p_secondary_uom_code         IN VARCHAR2,
                                 p_secondary_default_ind      IN VARCHAR2,
                                 p_ont_pricing_qty_source     IN VARCHAR2,
                                 p_dual_uom_deviation_high    IN NUMBER,
                                 p_dual_uom_deviation_low     IN NUMBER,
                                 p_serial_number_control_code IN NUMBER,
                                 p_tax_code                   IN VARCHAR2,
                                 p_master_status              IN VARCHAR2,
                                 p_base_item_id               IN NUMBER DEFAULT NULL,
                                 p_pur_tax_code               IN VARCHAR2) IS
  
    CURSOR org_parameters(cp_organization_id IN NUMBER) IS
      SELECT nvl(primary_cost_method, 0),
             nvl(process_enabled_flag, 'N'),
             nvl(wms_enabled_flag, 'N'),
             nvl(eam_enabled_flag, 'N'),
             nvl(trading_partner_org_flag, 'N')
        FROM mtl_parameters
       WHERE organization_id = cp_organization_id;
  
    l_error_table inv_item_grp.error_tbl_type;
    l_error_index BINARY_INTEGER := 1;
    l_ret_sts_error       CONSTANT VARCHAR2(1) := fnd_api.g_ret_sts_error; --'E'
    l_ret_sts_unexp_error CONSTANT VARCHAR2(1) := fnd_api.g_ret_sts_unexp_error; --'U'
    l_eam_enabled_flag         VARCHAR2(1) := 'N';
    l_wms_enabled_flag         VARCHAR2(1) := 'N';
    l_process_enabled_flag     VARCHAR2(1) := 'N';
    l_primary_cost_method      NUMBER := 0;
    l_trading_partner_org_flag VARCHAR2(1) := 'N';
    l_exists                   NUMBER;
  BEGIN
    x_return_status := fnd_api.g_ret_sts_success;
    x_msg_count     := 0;
  
    IF p_master_status <> 'A' THEN
      x_msg_count := x_msg_count + 1;
      fnd_message.set_name('INV', 'INV_IOI_UNAPPROVED_ITEM_ORG');
      IF nvl(p_context, 'N') = 'N' THEN
        ego_item_msg.add_error_text(x_msg_count,
                                    p_org_code || ' : ' || fnd_message.get);
      END IF;
      RAISE fnd_api.g_exc_error;
    END IF;
  
    OPEN org_parameters(p_organization_id);
    FETCH org_parameters
      INTO l_primary_cost_method,
           l_process_enabled_flag,
           l_wms_enabled_flag,
           l_eam_enabled_flag,
           l_trading_partner_org_flag;
    CLOSE org_parameters;
  
    -- Organization specific validations for Tracking UOM Indicator
    IF (l_process_enabled_flag = 'N' AND p_tracking_quantity_ind = 'PS' AND
       (p_bom_enabled_flag = 'Y' OR p_bom_item_type IN (1, 2))) THEN
      x_msg_count := x_msg_count + 1;
      fnd_message.set_name('INV', 'INV_TRACKING_OPM_BOM_ATTR');
      IF nvl(p_context, 'N') = 'N' THEN
        ego_item_msg.add_error_text(x_msg_count,
                                    p_org_code || ' : ' || fnd_message.get);
      END IF;
      RAISE fnd_api.g_exc_error;
    END IF;
  
    -- Organization specific validations for Outsourced Assembly
    IF (p_outsourced_assembly = 1) THEN
      IF (NOT (l_eam_enabled_flag = 'N' AND l_wms_enabled_flag = 'N' AND
          l_process_enabled_flag = 'N')) THEN
        x_msg_count := x_msg_count + 1;
        fnd_message.set_name('INV', 'INV_OS_ASMBLY_INVALID_ORG');
        IF nvl(p_context, 'N') = 'N' THEN
          ego_item_msg.add_error_text(x_msg_count,
                                      p_org_code || ' : ' ||
                                      fnd_message.get);
        END IF;
        RAISE fnd_api.g_exc_error;
      ELSIF (l_trading_partner_org_flag = 'Y' AND
            nvl(p_release_time_fence_code, -999999) <> 7) THEN
        x_msg_count := x_msg_count + 1;
        fnd_message.set_name('INV', 'INV_OS_ASMBLY_TP_TIME_FENSE');
        IF nvl(p_context, 'N') = 'N' THEN
          ego_item_msg.add_error_text(x_msg_count,
                                      p_org_code || ' : ' ||
                                      fnd_message.get);
        END IF;
        RAISE fnd_api.g_exc_error;
      ELSIF (l_primary_cost_method <> 1) THEN
        x_msg_count := x_msg_count + 1;
        fnd_message.set_name('INV', 'INV_OS_ASMBLY_STD_COST_ORG');
        IF nvl(p_context, 'N') = 'N' THEN
          ego_item_msg.add_error_text(x_msg_count,
                                      p_org_code || ' : ' ||
                                      fnd_message.get);
        END IF;
        RAISE fnd_api.g_exc_error;
      END IF;
    END IF;
  
    -- Organization specific validations for subcontracting component.
    IF (p_subcontracting_component IS NOT NULL) THEN
      IF (NOT (l_eam_enabled_flag = 'N' AND l_wms_enabled_flag = 'N' AND
          l_process_enabled_flag = 'N')) THEN
        x_msg_count := x_msg_count + 1;
        fnd_message.set_name('INV', 'INV_OS_ASMBLY_INVALID_ORG');
        IF nvl(p_context, 'N') = 'N' THEN
          ego_item_msg.add_error_text(x_msg_count,
                                      p_org_code || ' : ' ||
                                      fnd_message.get);
        END IF;
        RAISE fnd_api.g_exc_error;
      ELSIF (l_primary_cost_method <> 1) THEN
        x_msg_count := x_msg_count + 1;
        fnd_message.set_name('INV', 'INV_OS_ASMBLY_STD_COST_ORG');
        IF nvl(p_context, 'N') = 'N' THEN
          ego_item_msg.add_error_text(x_msg_count,
                                      p_org_code || ' : ' ||
                                      fnd_message.get);
        END IF;
        RAISE fnd_api.g_exc_error;
      END IF;
    END IF;
  
    -- Bug: 5017578 Org Specific Validations
    IF (p_tracking_quantity_ind = 'P' AND p_ont_pricing_qty_source = 'P') THEN
    
      IF p_secondary_default_ind IS NOT NULL THEN
        x_msg_count := x_msg_count + 1;
        fnd_message.set_name('INV', 'INV_SEC_DEFAULT_NOT_NULL');
        IF nvl(p_context, 'N') = 'N' THEN
          ego_item_msg.add_error_text(x_msg_count,
                                      p_org_code || ' : ' ||
                                      fnd_message.get);
        END IF;
        RAISE fnd_api.g_exc_error;
      END IF;
    
      IF p_secondary_uom_code IS NOT NULL THEN
        x_msg_count := x_msg_count + 1;
        fnd_message.set_name('INV', 'INV_SEC_UOM_IS_NOT_NULL');
        IF nvl(p_context, 'N') = 'N' THEN
          ego_item_msg.add_error_text(x_msg_count,
                                      p_org_code || ' : ' ||
                                      fnd_message.get);
        END IF;
        RAISE fnd_api.g_exc_error;
      END IF;
    
      IF (p_dual_uom_deviation_high <> 0 OR p_dual_uom_deviation_low <> 0) THEN
        x_msg_count := x_msg_count + 1;
        fnd_message.set_name('INV', 'INV_UOM_DEV_IS_NOT_ZERO');
        IF nvl(p_context, 'N') = 'N' THEN
          ego_item_msg.add_error_text(x_msg_count,
                                      p_org_code || ' : ' ||
                                      fnd_message.get);
        END IF;
        RAISE fnd_api.g_exc_error;
      END IF;
    END IF;
  
    IF ((p_tracking_quantity_ind = 'PS' OR p_ont_pricing_qty_source = 'S') AND
       (p_secondary_default_ind IS NULL OR p_secondary_uom_code IS NULL)) THEN
      x_msg_count := x_msg_count + 1;
      fnd_message.set_name('INV', 'INV_REQUIRED_FIELDS');
      IF nvl(p_context, 'N') = 'N' THEN
        ego_item_msg.add_error_text(x_msg_count,
                                    p_org_code || ' : ' || fnd_message.get);
      END IF;
      RAISE fnd_api.g_exc_error;
    END IF;
  
    IF (p_tracking_quantity_ind = 'PS') THEN
      IF (p_bom_item_type IN (1, 2) OR p_bom_enabled_flag = 'Y') THEN
        x_msg_count := x_msg_count + 1;
        fnd_message.set_name('INV', 'INV_TRACKING_OPM_BOM_ATTR');
        IF nvl(p_context, 'N') = 'N' THEN
          ego_item_msg.add_error_text(x_msg_count,
                                      p_org_code || ' : ' ||
                                      fnd_message.get);
        END IF;
        RAISE fnd_api.g_exc_error;
      END IF;
    
      IF p_serial_number_control_code > 1 THEN
        x_msg_count := x_msg_count + 1;
        fnd_message.set_name('INV', 'INV_INVALID_TRACKING_QTY_IND');
        IF nvl(p_context, 'N') = 'N' THEN
          ego_item_msg.add_error_text(x_msg_count,
                                      p_org_code || ' : ' ||
                                      fnd_message.get);
        END IF;
        RAISE fnd_api.g_exc_error;
      END IF;
    END IF;
  
    IF (p_tracking_quantity_ind = 'P' AND
       p_secondary_default_ind NOT IN ('D', 'N')) THEN
    
      x_msg_count := x_msg_count + 1;
      fnd_message.set_name('INV', 'INV_SEC_DEFULT_IS_FIXED');
      IF nvl(p_context, 'N') = 'N' THEN
        ego_item_msg.add_error_text(x_msg_count,
                                    p_org_code || ' : ' || fnd_message.get);
      END IF;
      RAISE fnd_api.g_exc_error;
    END IF;
  
    --Bug 5330093 Begin
    -- Confirming if "Positive Deviation" and "Negative Deviation" are 0
    -- when "Defaulting" is neither "Default" nor "Not Default"
    IF (p_secondary_default_ind NOT IN ('D', 'N')) THEN
      --{
      IF (p_dual_uom_deviation_high <> 0 OR p_dual_uom_deviation_low <> 0) THEN
        --{
        x_msg_count := x_msg_count + 1;
        fnd_message.set_name('INV', 'INV_UOM_DEV_IS_NOT_ZERO');
        IF nvl(p_context, 'N') = 'N' THEN
          --{
          ego_item_msg.add_error_text(x_msg_count,
                                      p_org_code || ' : ' ||
                                      fnd_message.get);
          --}
        END IF;
        RAISE fnd_api.g_exc_error;
        --}
      END IF;
      --}
    END IF;
    --Bug 5330093 End
  
    /* Bug 5207014 - Validating Output Tax Classification Code */
    IF (p_tax_code IS NOT NULL AND g_tax_code_control_level = 1) THEN
      BEGIN
        SELECT 1
          INTO l_exists
          FROM zx_output_classifications_v
         WHERE lookup_code = p_tax_code
           AND enabled_flag = 'Y'
           AND SYSDATE BETWEEN nvl(start_date_active, SYSDATE) AND
               nvl(end_date_active, SYSDATE)
           AND org_id IN (p_organization_id, -99)
           AND rownum = 1;
      EXCEPTION
        WHEN no_data_found THEN
          x_msg_count := x_msg_count + 1;
          fnd_message.set_name('INV', 'INV_IOI_INVALID_TAX_CODE_ORG');
          IF nvl(p_context, 'N') = 'N' THEN
            ego_item_msg.add_error_text(x_msg_count,
                                        p_org_code || ' : ' ||
                                        fnd_message.get);
          END IF;
          RAISE fnd_api.g_exc_error;
      END;
    END IF;
  
    --Bug 5662813
    IF (p_pur_tax_code IS NOT NULL AND g_p_tax_code_control_level = 1) THEN
      BEGIN
        SELECT 1
          INTO l_exists
          FROM zx_input_classifications_v
         WHERE tax_type NOT IN ('AWT', 'OFFSET')
           AND enabled_flag = 'Y'
           AND SYSDATE BETWEEN start_date_active AND
               nvl(end_date_active, SYSDATE)
           AND lookup_code = p_pur_tax_code
           AND org_id IN (p_organization_id, -99)
           AND rownum = 1;
      EXCEPTION
        WHEN no_data_found THEN
          x_msg_count := x_msg_count + 1;
          fnd_message.set_name('INV', 'INV_IOI_PUR_TAX_CODE');
          IF nvl(p_context, 'N') = 'N' THEN
            ego_item_msg.add_error_text(x_msg_count,
                                        p_org_code || ' : ' ||
                                        fnd_message.get);
          END IF;
          RAISE fnd_api.g_exc_error;
      END;
    END IF;
  
    --Bug: 5438006 Adding validation for base item
    IF (p_base_item_id IS NOT NULL) THEN
      BEGIN
        SELECT 1
          INTO l_exists
          FROM mtl_system_items_b
         WHERE inventory_item_id = p_base_item_id
           AND organization_id = p_organization_id;
      EXCEPTION
        WHEN no_data_found THEN
          x_msg_count := x_msg_count + 1;
          fnd_message.set_name('INV', 'INV_IOI_BASE_ITEM_ID');
          IF nvl(p_context, 'N') = 'N' THEN
            ego_item_msg.add_error_text(x_msg_count,
                                        p_org_code || ' : ' ||
                                        fnd_message.get);
          END IF;
          RAISE fnd_api.g_exc_error;
      END;
    END IF;
  
  EXCEPTION
    WHEN fnd_api.g_exc_error THEN
      x_return_status := l_ret_sts_error;
      IF nvl(p_context, 'N') = 'BOM' THEN
        x_error_code := fnd_message.get;
      END IF;
    WHEN OTHERS THEN
      x_return_status := l_ret_sts_unexp_error;
      x_msg_count     := x_msg_count + 1;
      ego_item_msg.add_error_message(x_msg_count,
                                     'INV',
                                     'EGO_ITEM_UNEXPECTED_ERROR',
                                     'PACKAGE_NAME',
                                     'EGO_ITEM_ORG_ASSIGN_PVT',
                                     FALSE,
                                     'PROCEDURE_NAME',
                                     'PROCESS_ORG_ASSIGNMENTS',
                                     FALSE,
                                     'ERROR_TEXT',
                                     SQLERRM,
                                     FALSE);
  END item_org_validations;

  --API called from PLM HTML UI org assignment.

  --------------------------------------------------------------------
  --  customization code:
  --  name:               process_org_assignments
  --  create by:
  --  $Revision:          1.0
  --  creation date:
  --  Purpose:
  --------------------------------------------------------------------
  --  ver   date          name             desc
  --  1.x   09.03.14      yuval tal        CHG0031399 Bug in Org Assignment Procedure
  --                                       values from master were overide by inner assignment in loop
  --------------------------------------------------------------------

  --
  PROCEDURE process_org_assignments(p_item_org_assign_tab IN OUT NOCOPY system.ego_item_org_assign_table,
                                    p_commit              IN VARCHAR2,
                                    p_context             IN VARCHAR2 DEFAULT NULL,
                                    x_return_status       OUT NOCOPY VARCHAR,
                                    x_msg_count           OUT NOCOPY NUMBER) IS
    l_item_rec      inv_item_api.item_rec_type := NULL;
    l_return_status VARCHAR2(1) := fnd_api.g_ret_sts_success;
    l_sysdate       DATE := SYSDATE;
    l_rowid         ROWID := NULL;
    l_inv_id        NUMBER := inv_item_util.g_appl_inst.inv;
    l_error_table   inv_item_grp.error_tbl_type;
    l_error_index   BINARY_INTEGER := 1;
    l_ret_sts_error       CONSTANT VARCHAR2(1) := fnd_api.g_ret_sts_error; --'E'
    l_ret_sts_unexp_error CONSTANT VARCHAR2(1) := fnd_api.g_ret_sts_unexp_error; --'U'
    l_item_org_valid  VARCHAR2(1);
    l_org_valid_count NUMBER;
    l_item_id         NUMBER;
    l_master_status   mtl_system_items_b.approval_status%TYPE;
  
    l_param_encumbrance_account   NUMBER;
    l_param_expense_account       NUMBER;
    l_param_sales_account         NUMBER;
    l_param_cost_of_sales_account NUMBER;
    l_item_encumbrance_account    NUMBER;
    l_item_expense_account        NUMBER;
    l_item_sales_account          NUMBER;
    l_item_cost_of_sales_account  NUMBER;
    l_revision                    VARCHAR2(30);
    l_msg_count                   NUMBER;
    l_msg_data                    VARCHAR2(500);
    l_default_receiving_subinv    mtl_item_sub_inventories.secondary_inventory%TYPE;
    l_make_buy_value              NUMBER;
    l_make_buy_value_orig         NUMBER;
    l_shelf_life_code_orig        NUMBER;
    /*
    Bug 4964874
    In Multi Create Copy flow
    Different Inventory_ID might come if we are creating multiple items and they have organization
    assignments. We will buuild record every time the inventory_item_id changes and for the same
    we are ordering the rows in the sql table by inventory_item_id
    */
    CURSOR org_assign_recs IS
      SELECT a.master_organization_id  master_organization_id,
             a.organization_id         organization_id,
             a.organization_code       organization_code,
             a.primary_uom_code        primary_uom_code,
             a.inventory_item_id       inventory_item_id,
             a.status                  status,
             a.error_code              ERROR_CODE,
             a.secondary_uom_code      secondary_uom_code,
             a.tracking_quantity_ind   tracking_quantity_ind,
             a.secondary_default_ind   secondary_default_ind,
             a.ont_pricing_qty_source  ont_pricing_qty_source,
             a.dual_uom_deviation_high dual_uom_deviation_high,
             a.dual_uom_deviation_low  dual_uom_deviation_low
        FROM THE (SELECT CAST(p_item_org_assign_tab AS
                              "SYSTEM".ego_item_org_assign_table)
                    FROM dual) a
       ORDER BY inventory_item_id;
  
    l_error_code VARCHAR2(2000);
    l_status     VARCHAR2(1);
  
    l_record_first NUMBER;
    l_record_last  NUMBER;
    l_exists       NUMBER;
  
    -- Bug 5357161
    CURSOR rev_creates_for_org_item(c_inventory_item_id NUMBER,
                                    c_organization_id   NUMBER) IS
      SELECT inventory_item_id, organization_id, revision_id
        FROM mtl_item_revisions_b mir
       WHERE inventory_item_id = c_inventory_item_id
         AND organization_id = c_organization_id
         AND mir.revision =
             (SELECT MAX(revision)
                FROM mtl_item_revisions_b mir
               WHERE inventory_item_id = c_inventory_item_id
                 AND organization_id = c_organization_id)
       ORDER BY mir.revision;
  
    CURSOR cat_assigns_for_org_item(c_inventory_item_id NUMBER,
                                    c_organization_id   NUMBER) IS
      SELECT inventory_item_id,
             organization_id,
             category_set_id,
             category_id
        FROM mtl_item_categories
       WHERE inventory_item_id = c_inventory_item_id
         AND organization_id = c_organization_id;
    -- Bug 5357161
  
    CURSOR tax_control_level IS
      SELECT SUM(decode(attribute_name,
                        'MTL_SYSTEM_ITEMS.TAX_CODE',
                        control_level,
                        0)),
             SUM(decode(attribute_name,
                        'MTL_SYSTEM_ITEMS.PURCHASING_TAX_CODE',
                        control_level,
                        0))
        FROM mtl_item_attributes
       WHERE attribute_name IN
             ('MTL_SYSTEM_ITEMS.PURCHASING_TAX_CODE',
              'MTL_SYSTEM_ITEMS.TAX_CODE');
  BEGIN
  
    OPEN tax_control_level;
    FETCH tax_control_level
      INTO g_tax_code_control_level, g_p_tax_code_control_level;
    CLOSE tax_control_level;
  
    x_return_status := l_return_status;
    x_msg_count     := 0;
  
    l_record_first := p_item_org_assign_tab.first;
    l_record_last  := p_item_org_assign_tab.last;
  
    FOR org_assign_rec IN org_assign_recs LOOP
      l_item_rec.inventory_item_id := org_assign_rec.inventory_item_id;
      --Populate the columns from master record.
      --The "If" condition prohibits from building record multiple times.
      --For multiple org assignemts of a single item, build record will be called only once.
      IF nvl(l_item_id, -1) <> org_assign_rec.inventory_item_id THEN
        l_item_id := org_assign_rec.inventory_item_id;
        build_item_record(p_item_rec      => l_item_rec,
                          p_master_org_id => org_assign_rec.master_organization_id,
                          x_master_status => l_master_status);
        -- bugfix CHG0031399 
        -- save values since they are changing by org in inner loop
        l_make_buy_value_orig  := l_item_rec.planning_make_buy_code;
        l_shelf_life_code_orig := l_item_rec.shelf_life_code;
      END IF;
    
      l_item_rec.planning_make_buy_code := l_make_buy_value_orig;
      l_item_rec.shelf_life_code        := l_shelf_life_code_orig;
      --Populate org specific variable
      l_item_rec.organization_id  := org_assign_rec.organization_id;
      l_item_rec.primary_uom_code := org_assign_rec.primary_uom_code;
      l_item_rec.creation_date    := l_sysdate;
      l_item_rec.last_update_date := l_sysdate;
      -- Bug: 5017578
      l_item_rec.secondary_uom_code      := org_assign_rec.secondary_uom_code;
      l_item_rec.tracking_quantity_ind   := org_assign_rec.tracking_quantity_ind;
      l_item_rec.secondary_default_ind   := org_assign_rec.secondary_default_ind;
      l_item_rec.ont_pricing_qty_source  := org_assign_rec.ont_pricing_qty_source;
      l_item_rec.dual_uom_deviation_high := nvl(org_assign_rec.dual_uom_deviation_high,
                                                0);
      l_item_rec.dual_uom_deviation_low  := nvl(org_assign_rec.dual_uom_deviation_low,
                                                0);
    
      l_item_rec.last_updated_by := fnd_global.user_id;
      l_item_rec.created_by      := fnd_global.user_id;
    
      --Bug 5622813 NULL out tax codes if INVALID for current org and the control level is ORG
      BEGIN
        IF l_item_rec.tax_code IS NOT NULL THEN
          SELECT 1
            INTO l_exists
            FROM zx_output_classifications_v
           WHERE lookup_code = l_item_rec.tax_code
             AND enabled_flag = 'Y'
             AND SYSDATE BETWEEN nvl(start_date_active, SYSDATE) AND
                 nvl(end_date_active, SYSDATE)
             AND org_id IN (l_item_rec.organization_id, -99)
             AND rownum = 1;
        END IF;
      
      EXCEPTION
        WHEN no_data_found THEN
          IF g_tax_code_control_level = 2 THEN
            l_item_rec.tax_code := NULL;
          END IF;
      END;
    
      BEGIN
        IF l_item_rec.purchasing_tax_code IS NOT NULL THEN
          SELECT 1
            INTO l_exists
            FROM zx_input_classifications_v
           WHERE lookup_code = l_item_rec.purchasing_tax_code
             AND tax_type NOT IN ('AWT', 'OFFSET')
             AND enabled_flag = 'Y'
             AND SYSDATE BETWEEN nvl(start_date_active, SYSDATE) AND
                 nvl(end_date_active, SYSDATE)
             AND org_id IN (l_item_rec.organization_id, -99)
             AND rownum = 1;
        END IF;
      
      EXCEPTION
        WHEN no_data_found THEN
          IF g_p_tax_code_control_level = 2 THEN
            l_item_rec.purchasing_tax_code := NULL;
          END IF;
      END;
    
      -----------------------------------------------------------------------------------------------------------
      -- create organization item accounts: company segment from mtl_parameters and the rest from master item
      SELECT encumbrance_account,
             expense_account,
             sales_account,
             cost_of_sales_account
        INTO l_param_encumbrance_account,
             l_param_expense_account,
             l_param_sales_account,
             l_param_cost_of_sales_account
        FROM mtl_parameters
       WHERE organization_id = org_assign_rec.organization_id;
    
      SELECT encumbrance_account,
             expense_account,
             sales_account,
             cost_of_sales_account
        INTO l_item_encumbrance_account,
             l_item_expense_account,
             l_item_sales_account,
             l_item_cost_of_sales_account
        FROM mtl_system_items_b
       WHERE inventory_item_id = org_assign_rec.inventory_item_id
         AND organization_id = org_assign_rec.master_organization_id;
    
      l_item_rec.encumbrance_account   := get_org_assign_account(org_assign_rec.organization_id,
                                                                 l_param_encumbrance_account,
                                                                 l_item_encumbrance_account,
                                                                 x_return_status,
                                                                 x_msg_count);
      l_item_rec.expense_account       := get_org_assign_account(org_assign_rec.organization_id,
                                                                 l_param_expense_account,
                                                                 l_item_expense_account,
                                                                 x_return_status,
                                                                 x_msg_count);
      l_item_rec.sales_account         := get_org_assign_account(org_assign_rec.organization_id,
                                                                 l_param_sales_account,
                                                                 l_item_sales_account,
                                                                 x_return_status,
                                                                 x_msg_count);
      l_item_rec.cost_of_sales_account := get_org_assign_account(org_assign_rec.organization_id,
                                                                 l_param_cost_of_sales_account,
                                                                 l_item_cost_of_sales_account,
                                                                 x_return_status,
                                                                 x_msg_count);
    
      l_default_receiving_subinv := NULL;
      dbms_output.put_line('org_assign_rec.organization_code=' ||
                           org_assign_rec.organization_code);
      dbms_output.put_line('1 -- l_item_rec.planning_make_buy_code=' ||
                           l_item_rec.planning_make_buy_code);
    
      IF org_assign_rec.organization_code NOT IN
         ('IPK' /*'WPI'*/, 'IRK' /*'WRI'*/) THEN
      
        SELECT lookup_code
          INTO l_make_buy_value
          FROM fnd_lookup_values_vl
         WHERE lookup_type = 'MTL_PLANNING_MAKE_BUY'
           AND meaning = 'Buy';
      
        l_item_rec.planning_make_buy_code := l_make_buy_value;
      
        IF org_assign_rec.organization_code != 'ISK' /*WSI*/
         THEN
        
          -- Set Shelf Life Code
          IF nvl(l_item_rec.shelf_life_days, 0) > 0 THEN
          
            l_item_rec.shelf_life_code := 4;
          
          END IF;
        
        END IF;
      
      END IF;
    
      dbms_output.put_line(' 2 -- l_item_rec.planning_make_buy_code' ||
                           l_item_rec.planning_make_buy_code);
    
      -----------------------------------------------------------------------------------------------------------
    
      ------------------------------------------------------------------------------------------------------
      BEGIN
        -- Calling validation API to validate
        -- 1.Tracking UOM Indicator
        -- 2.Outsourced Assembly
        -- 3.Subcontracting component.
        -- Only above fields have validations against org params.
        l_org_valid_count := 0;
        item_org_validations(p_org_code                   => org_assign_rec.organization_code,
                             p_organization_id            => org_assign_rec.organization_id,
                             p_tracking_quantity_ind      => l_item_rec.tracking_quantity_ind,
                             p_bom_enabled_flag           => l_item_rec.bom_enabled_flag,
                             p_bom_item_type              => l_item_rec.bom_item_type,
                             p_outsourced_assembly        => l_item_rec.outsourced_assembly,
                             p_release_time_fence_code    => l_item_rec.release_time_fence_code,
                             p_subcontracting_component   => l_item_rec.subcontracting_component,
                             x_return_status              => l_item_org_valid,
                             x_msg_count                  => l_org_valid_count,
                             p_context                    => p_context,
                             x_error_code                 => l_error_code,
                             p_secondary_uom_code         => l_item_rec.secondary_uom_code,
                             p_secondary_default_ind      => l_item_rec.secondary_default_ind,
                             p_ont_pricing_qty_source     => l_item_rec.ont_pricing_qty_source,
                             p_dual_uom_deviation_high    => l_item_rec.dual_uom_deviation_high,
                             p_dual_uom_deviation_low     => l_item_rec.dual_uom_deviation_low,
                             p_serial_number_control_code => l_item_rec.serial_number_control_code,
                             p_tax_code                   => l_item_rec.tax_code,
                             p_master_status              => l_master_status,
                             p_base_item_id               => l_item_rec.base_item_id --Bug: 5438006 Added base_item_id
                            ,
                             p_pur_tax_code               => l_item_rec.purchasing_tax_code);
      
        --Bug: 4997732
        FOR i IN l_record_first .. l_record_last LOOP
          IF (p_item_org_assign_tab(i)
             .inventory_item_id = org_assign_rec.inventory_item_id) AND
             (p_item_org_assign_tab(i)
             .organization_id = org_assign_rec.organization_id) THEN
            p_item_org_assign_tab(i).error_code := l_error_code;
            p_item_org_assign_tab(i).status := l_item_org_valid;
          END IF;
        END LOOP;
      
        IF l_item_org_valid = fnd_api.g_ret_sts_success THEN
        
          inv_item_pvt.create_item(p_item_rec                   => l_item_rec,
                                   p_item_category_struct_id    => NULL,
                                   p_inv_install                => l_inv_id,
                                   p_master_org_id              => org_assign_rec.master_organization_id,
                                   p_category_set_id            => NULL,
                                   p_item_category_id           => NULL,
                                   p_event                      => 'ORG_ASSIGN',
                                   x_row_id                     => l_rowid,
                                   p_default_move_order_sub_inv => NULL,
                                   p_default_receiving_sub_inv  => NULL, --l_default_receiving_subinv,
                                   p_default_shipping_sub_inv   => NULL);
        
          IF org_assign_rec.organization_code = 'ISK' /*WSI*/
           THEN
          
            l_default_receiving_subinv := 'INTRAN-SUB';
          
            inv_item_sub_default_pkg.insert_upd_item_sub_defaults(p_organization_id   => l_item_rec.organization_id,
                                                                  p_inventory_item_id => l_item_rec.inventory_item_id,
                                                                  p_subinventory_code => l_default_receiving_subinv,
                                                                  p_default_type      => 2,
                                                                  p_creation_date     => SYSDATE,
                                                                  p_created_by        => fnd_global.user_id,
                                                                  p_last_update_date  => SYSDATE,
                                                                  p_last_updated_by   => fnd_global.user_id,
                                                                  p_process_code      => 'SYNC',
                                                                  p_commit            => fnd_api.g_false,
                                                                  x_return_status     => x_return_status,
                                                                  x_msg_count         => x_msg_count,
                                                                  x_msg_data          => l_msg_data);
          
          END IF;
        
          -- Bug 5357161
          -- INV_ITEM_PVT.CREATE_ITEM raises business events for Create Item.
          -- We need to raise for Category Assignment and Revision Create.
          -- Raising for revisions
          FOR revs IN rev_creates_for_org_item(l_item_rec.inventory_item_id,
                                               org_assign_rec.master_organization_id) LOOP
            inv_item_events_pvt.raise_events(p_inventory_item_id => revs.inventory_item_id,
                                             p_organization_id   => l_item_rec.organization_id,
                                             p_revision_id       => revs.revision_id,
                                             p_event_name        => 'EGO_WF_WRAPPER_PVT.G_REV_CHANGE_EVENT',
                                             p_dml_type          => 'CREATE');
          END LOOP;
        
          -- Raising for category_assignments
          FOR cats IN cat_assigns_for_org_item(l_item_rec.inventory_item_id,
                                               l_item_rec.organization_id) LOOP
            inv_item_events_pvt.raise_events(p_inventory_item_id => cats.inventory_item_id,
                                             p_organization_id   => cats.organization_id,
                                             p_category_set_id   => cats.category_set_id,
                                             p_category_id       => cats.category_id,
                                             p_event_name        => 'EGO_WF_WRAPPER_PVT.G_ITEM_CAT_ASSIGN_EVENT',
                                             p_dml_type          => 'CREATE');
          END LOOP;
          -- Bug 5357161
        
        ELSE
          x_msg_count := x_msg_count + l_org_valid_count;
          IF l_return_status <> l_ret_sts_unexp_error THEN
            l_return_status := l_item_org_valid;
          END IF;
        END IF;
      
      EXCEPTION
        WHEN fnd_api.g_exc_unexpected_error THEN
          x_msg_count := x_msg_count + 1;
          ego_item_msg.add_error_text(x_msg_count,
                                      org_assign_rec.organization_code ||
                                      ' : ' || fnd_message.get);
          IF l_return_status <> l_ret_sts_unexp_error THEN
            l_return_status := l_ret_sts_error;
          END IF;
        WHEN OTHERS THEN
          x_msg_count := x_msg_count + 1;
          ego_item_msg.add_error_message(x_msg_count,
                                         'INV',
                                         'INV_ITEM_UNEXPECTED_ERROR',
                                         'PACKAGE_NAME',
                                         'INV_ITEM_PVT',
                                         FALSE,
                                         'PROCEDURE_NAME',
                                         'CREATE_ITEM',
                                         FALSE,
                                         'ERROR_TEXT',
                                         org_assign_rec.organization_code ||
                                         ' : ' || SQLERRM,
                                         FALSE);
          x_return_status := l_ret_sts_unexp_error;
      END;
    END LOOP;
  
    x_return_status := l_return_status;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_msg_count     := x_msg_count + 1;
      x_return_status := l_ret_sts_unexp_error;
      ego_item_msg.add_error_message(x_msg_count,
                                     'INV',
                                     'EGO_ITEM_UNEXPECTED_ERROR',
                                     'PACKAGE_NAME',
                                     'EGO_ITEM_ORG_ASSIGN_PVT',
                                     FALSE,
                                     'PROCEDURE_NAME',
                                     'PROCESS_ORG_ASSIGNMENTS',
                                     FALSE,
                                     'ERROR_TEXT',
                                     SQLERRM,
                                     FALSE);
  END process_org_assignments;

  PROCEDURE build_item_record(p_item_rec      IN OUT NOCOPY inv_item_api.item_rec_type,
                              p_master_org_id IN NUMBER,
                              x_master_status OUT NOCOPY mtl_system_items_b.approval_status%TYPE) IS
  BEGIN
    SELECT b.inventory_item_id,
           t.description,
           t.long_description,
           b.primary_uom_code,
           b.allowed_units_lookup_code,
           b.overcompletion_tolerance_type,
           b.overcompletion_tolerance_value,
           b.effectivity_control,
           b.check_shortages_flag,
           b.full_lead_time,
           b.order_cost,
           b.mrp_safety_stock_percent,
           b.mrp_safety_stock_code,
           b.min_minmax_quantity,
           b.max_minmax_quantity,
           b.minimum_order_quantity,
           b.fixed_order_quantity,
           b.fixed_days_supply,
           b.maximum_order_quantity,
           b.atp_rule_id,
           b.picking_rule_id,
           b.reservable_type,
           b.positive_measurement_error,
           b.negative_measurement_error,
           b.engineering_ecn_code,
           b.engineering_item_id,
           b.engineering_date,
           b.service_starting_delay,
           b.serviceable_component_flag,
           b.serviceable_product_flag,
           b.payment_terms_id,
           b.preventive_maintenance_flag,
           b.material_billable_flag,
           b.prorate_service_flag,
           b.coverage_schedule_id,
           b.service_duration_period_code,
           b.service_duration,
           b.invoiceable_item_flag,
           b.tax_code,
           b.invoice_enabled_flag,
           b.must_use_approved_vendor_flag,
           b.outside_operation_flag,
           b.outside_operation_uom_type,
           b.safety_stock_bucket_days,
           b.auto_reduce_mps,
           b.costing_enabled_flag,
           b.auto_created_config_flag,
           b.cycle_count_enabled_flag,
           b.item_type,
           b.model_config_clause_name,
           b.ship_model_complete_flag,
           b.mrp_planning_code,
           b.return_inspection_requirement,
           b.ato_forecast_control,
           b.release_time_fence_code,
           b.release_time_fence_days,
           b.container_item_flag,
           b.vehicle_item_flag,
           b.maximum_load_weight,
           b.minimum_fill_percent,
           b.container_type_code,
           b.internal_volume,
           b.global_attribute_category,
           b.global_attribute1,
           b.global_attribute2,
           b.global_attribute3,
           b.global_attribute4,
           b.global_attribute5,
           b.global_attribute6,
           b.global_attribute7,
           b.global_attribute8,
           b.global_attribute9,
           b.global_attribute10,
           b.purchasing_tax_code,
           b.attribute6,
           b.attribute7,
           b.attribute8,
           b.attribute9,
           b.attribute10,
           b.attribute11,
           b.attribute12,
           b.attribute13,
           b.attribute14,
           b.attribute15,
           b.purchasing_item_flag,
           b.shippable_item_flag,
           b.customer_order_flag,
           b.internal_order_flag,
           b.inventory_item_flag,
           b.eng_item_flag,
           b.inventory_asset_flag,
           b.purchasing_enabled_flag,
           b.customer_order_enabled_flag,
           b.internal_order_enabled_flag,
           b.so_transactions_flag,
           b.mtl_transactions_enabled_flag,
           b.stock_enabled_flag,
           b.bom_enabled_flag,
           b.build_in_wip_flag,
           b.revision_qty_control_code,
           b.item_catalog_group_id,
           b.catalog_status_flag,
           b.returnable_flag,
           b.default_shipping_org,
           b.collateral_flag,
           b.taxable_flag,
           b.qty_rcv_exception_code,
           b.allow_item_desc_update_flag,
           b.inspection_required_flag,
           b.receipt_required_flag,
           b.market_price,
           b.hazard_class_id,
           b.rfq_required_flag,
           b.qty_rcv_tolerance,
           b.list_price_per_unit,
           b.un_number_id,
           b.price_tolerance_percent,
           b.asset_category_id,
           b.rounding_factor,
           b.unit_of_issue,
           b.enforce_ship_to_location_code,
           b.allow_substitute_receipts_flag,
           b.allow_unordered_receipts_flag,
           b.allow_express_delivery_flag,
           b.days_early_receipt_allowed,
           b.days_late_receipt_allowed,
           b.receipt_days_exception_code,
           b.receiving_routing_id,
           b.invoice_close_tolerance,
           b.receive_close_tolerance,
           b.auto_lot_alpha_prefix,
           b.start_auto_lot_number,
           b.lot_control_code,
           b.shelf_life_code,
           b.shelf_life_days,
           b.serial_number_control_code,
           b.start_auto_serial_number,
           b.auto_serial_alpha_prefix,
           b.source_type,
           b.source_organization_id,
           b.source_subinventory,
           b.expense_account,
           b.encumbrance_account,
           b.restrict_subinventories_code,
           b.unit_weight,
           b.weight_uom_code,
           b.volume_uom_code,
           b.unit_volume,
           b.restrict_locators_code,
           b.location_control_code,
           b.shrinkage_rate,
           b.acceptable_early_days,
           b.planning_time_fence_code,
           b.demand_time_fence_code,
           b.lead_time_lot_size,
           b.std_lot_size,
           b.cum_manufacturing_lead_time,
           b.overrun_percentage,
           b.mrp_calculate_atp_flag,
           b.acceptable_rate_increase,
           b.acceptable_rate_decrease,
           b.cumulative_total_lead_time,
           b.planning_time_fence_days,
           b.demand_time_fence_days,
           b.end_assembly_pegging_flag,
           b.repetitive_planning_flag,
           b.planning_exception_set,
           b.bom_item_type,
           b.pick_components_flag,
           b.replenish_to_order_flag,
           b.base_item_id,
           b.atp_components_flag,
           b.atp_flag,
           b.fixed_lead_time,
           b.variable_lead_time,
           b.wip_supply_locator_id,
           b.wip_supply_type,
           b.wip_supply_subinventory,
           b.cost_of_sales_account,
           b.sales_account,
           b.default_include_in_rollup_flag,
           b.inventory_item_status_code,
           b.inventory_planning_code,
           b.planner_code,
           b.planning_make_buy_code,
           b.fixed_lot_multiplier,
           b.rounding_control_type,
           b.carrying_cost,
           b.postprocessing_lead_time,
           b.preprocessing_lead_time,
           b.summary_flag,
           b.enabled_flag,
           b.start_date_active,
           b.end_date_active,
           b.buyer_id,
           b.accounting_rule_id,
           b.invoicing_rule_id,
           b.over_shipment_tolerance,
           b.under_shipment_tolerance,
           b.over_return_tolerance,
           b.under_return_tolerance,
           b.equipment_type,
           b.recovered_part_disp_code,
           b.defect_tracking_on_flag,
           b.event_flag,
           b.electronic_flag,
           b.downloadable_flag,
           b.vol_discount_exempt_flag,
           b.coupon_exempt_flag,
           b.comms_nl_trackable_flag,
           b.asset_creation_code,
           b.comms_activation_reqd_flag,
           b.orderable_on_web_flag,
           b.back_orderable_flag,
           b.web_status,
           b.indivisible_flag,
           b.dimension_uom_code,
           b.unit_length,
           b.unit_width,
           b.unit_height,
           b.bulk_picked_flag,
           b.lot_status_enabled,
           b.default_lot_status_id,
           b.serial_status_enabled,
           b.default_serial_status_id,
           b.lot_split_enabled,
           b.lot_merge_enabled,
           b.inventory_carry_penalty,
           b.operation_slack_penalty,
           b.financing_allowed_flag,
           b.eam_item_type,
           b.eam_activity_type_code,
           b.eam_activity_cause_code,
           b.eam_act_notification_flag,
           b.eam_act_shutdown_status,
           b.dual_uom_control,
           b.secondary_uom_code,
           b.dual_uom_deviation_high,
           b.dual_uom_deviation_low,
           b.contract_item_type_code,
           b.subscription_depend_flag,
           b.serv_req_enabled_code,
           b.serv_billing_enabled_flag,
           b.serv_importance_level,
           b.planned_inv_point_flag,
           b.lot_translate_enabled,
           b.default_so_source_type,
           b.create_supply_flag,
           b.substitution_window_code,
           b.substitution_window_days,
           b.ib_item_instance_class,
           b.config_model_type,
           b.lot_substitution_enabled,
           b.minimum_license_quantity,
           b.eam_activity_source_code,
           b.tracking_quantity_ind,
           b.ont_pricing_qty_source,
           b.secondary_default_ind,
           b.option_specific_sourced,
           b.config_orgs,
           b.config_match,
           b.segment1,
           b.segment2,
           b.segment3,
           b.segment4,
           b.segment5,
           b.segment6,
           b.segment7,
           b.segment8,
           b.segment9,
           b.segment10,
           b.segment11,
           b.segment12,
           b.segment13,
           b.segment14,
           b.segment15,
           b.segment16,
           b.segment17,
           b.segment18,
           b.segment19,
           b.segment20,
           b.attribute_category,
           b.attribute1,
           b.attribute2,
           b.attribute3,
           b.attribute4,
           b.attribute5,
           b.created_by,
           b.last_updated_by,
           b.last_update_login,
           b.lifecycle_id,
           b.current_phase_id,
           b.vmi_minimum_units,
           b.vmi_minimum_days,
           b.vmi_maximum_units,
           b.vmi_maximum_days,
           b.vmi_fixed_order_quantity,
           b.so_authorization_flag,
           b.consigned_flag,
           b.asn_autoexpire_flag,
           b.vmi_forecast_type,
           b.forecast_horizon,
           b.exclude_from_budget_flag,
           b.critical_component_flag,
           b.continous_transfer,
           b.convergence,
           b.divergence,
           b.drp_planned_flag,
           b.days_tgt_inv_supply,
           b.days_tgt_inv_window,
           b.days_max_inv_supply,
           b.days_max_inv_window,
           b.lot_divisible_flag,
           b.grade_control_flag,
           b.default_grade,
           b.child_lot_flag,
           b.parent_child_generation_flag,
           b.child_lot_prefix,
           b.child_lot_starting_number,
           b.child_lot_validation_flag,
           b.copy_lot_attribute_flag,
           b.process_execution_enabled_flag,
           b.process_costing_enabled_flag,
           b.retest_interval,
           b.expiration_action_interval,
           b.expiration_action_code,
           b.maturity_days,
           b.hold_days,
           b.process_quality_enabled_flag,
           b.recipe_enabled_flag,
           b.process_supply_subinventory,
           b.process_supply_locator_id,
           b.process_yield_subinventory,
           b.process_yield_locator_id,
           b.hazardous_material_flag,
           b.cas_number,
           b.attribute16,
           b.attribute17,
           b.attribute18,
           b.attribute19,
           b.attribute20,
           b.attribute21,
           b.attribute22,
           b.attribute23,
           b.attribute24,
           b.attribute25,
           b.attribute26,
           b.attribute27,
           b.attribute28,
           b.attribute29,
           b.attribute30,
           b.repair_leadtime,
           b.repair_yield,
           b.repair_program,
           b.preposition_point,
           b.charge_periodicity_code,
           b.outsourced_assembly,
           b.subcontracting_component,
           nvl(b.approval_status, 'A')
      INTO p_item_rec.inventory_item_id,
           p_item_rec.description,
           p_item_rec.long_description,
           p_item_rec.primary_uom_code,
           p_item_rec.allowed_units_lookup_code,
           p_item_rec.overcompletion_tolerance_type,
           p_item_rec.overcompletion_tolerance_value,
           p_item_rec.effectivity_control,
           p_item_rec.check_shortages_flag,
           p_item_rec.full_lead_time,
           p_item_rec.order_cost,
           p_item_rec.mrp_safety_stock_percent,
           p_item_rec.mrp_safety_stock_code,
           p_item_rec.min_minmax_quantity,
           p_item_rec.max_minmax_quantity,
           p_item_rec.minimum_order_quantity,
           p_item_rec.fixed_order_quantity,
           p_item_rec.fixed_days_supply,
           p_item_rec.maximum_order_quantity,
           p_item_rec.atp_rule_id,
           p_item_rec.picking_rule_id,
           p_item_rec.reservable_type,
           p_item_rec.positive_measurement_error,
           p_item_rec.negative_measurement_error,
           p_item_rec.engineering_ecn_code,
           p_item_rec.engineering_item_id,
           p_item_rec.engineering_date,
           p_item_rec.service_starting_delay,
           p_item_rec.serviceable_component_flag,
           p_item_rec.serviceable_product_flag,
           p_item_rec.payment_terms_id,
           p_item_rec.preventive_maintenance_flag,
           p_item_rec.material_billable_flag,
           p_item_rec.prorate_service_flag,
           p_item_rec.coverage_schedule_id,
           p_item_rec.service_duration_period_code,
           p_item_rec.service_duration,
           p_item_rec.invoiceable_item_flag,
           p_item_rec.tax_code,
           p_item_rec.invoice_enabled_flag,
           p_item_rec.must_use_approved_vendor_flag,
           p_item_rec.outside_operation_flag,
           p_item_rec.outside_operation_uom_type,
           p_item_rec.safety_stock_bucket_days,
           p_item_rec.auto_reduce_mps,
           p_item_rec.costing_enabled_flag,
           p_item_rec.auto_created_config_flag,
           p_item_rec.cycle_count_enabled_flag,
           p_item_rec.item_type,
           p_item_rec.model_config_clause_name,
           p_item_rec.ship_model_complete_flag,
           p_item_rec.mrp_planning_code,
           p_item_rec.return_inspection_requirement,
           p_item_rec.ato_forecast_control,
           p_item_rec.release_time_fence_code,
           p_item_rec.release_time_fence_days,
           p_item_rec.container_item_flag,
           p_item_rec.vehicle_item_flag,
           p_item_rec.maximum_load_weight,
           p_item_rec.minimum_fill_percent,
           p_item_rec.container_type_code,
           p_item_rec.internal_volume,
           p_item_rec.global_attribute_category,
           p_item_rec.global_attribute1,
           p_item_rec.global_attribute2,
           p_item_rec.global_attribute3,
           p_item_rec.global_attribute4,
           p_item_rec.global_attribute5,
           p_item_rec.global_attribute6,
           p_item_rec.global_attribute7,
           p_item_rec.global_attribute8,
           p_item_rec.global_attribute9,
           p_item_rec.global_attribute10,
           p_item_rec.purchasing_tax_code,
           p_item_rec.attribute6,
           p_item_rec.attribute7,
           p_item_rec.attribute8,
           p_item_rec.attribute9,
           p_item_rec.attribute10,
           p_item_rec.attribute11,
           p_item_rec.attribute12,
           p_item_rec.attribute13,
           p_item_rec.attribute14,
           p_item_rec.attribute15,
           p_item_rec.purchasing_item_flag,
           p_item_rec.shippable_item_flag,
           p_item_rec.customer_order_flag,
           p_item_rec.internal_order_flag,
           p_item_rec.inventory_item_flag,
           p_item_rec.eng_item_flag,
           p_item_rec.inventory_asset_flag,
           p_item_rec.purchasing_enabled_flag,
           p_item_rec.customer_order_enabled_flag,
           p_item_rec.internal_order_enabled_flag,
           p_item_rec.so_transactions_flag,
           p_item_rec.mtl_transactions_enabled_flag,
           p_item_rec.stock_enabled_flag,
           p_item_rec.bom_enabled_flag,
           p_item_rec.build_in_wip_flag,
           p_item_rec.revision_qty_control_code,
           p_item_rec.item_catalog_group_id,
           p_item_rec.catalog_status_flag,
           p_item_rec.returnable_flag,
           p_item_rec.default_shipping_org,
           p_item_rec.collateral_flag,
           p_item_rec.taxable_flag,
           p_item_rec.qty_rcv_exception_code,
           p_item_rec.allow_item_desc_update_flag,
           p_item_rec.inspection_required_flag,
           p_item_rec.receipt_required_flag,
           p_item_rec.market_price,
           p_item_rec.hazard_class_id,
           p_item_rec.rfq_required_flag,
           p_item_rec.qty_rcv_tolerance,
           p_item_rec.list_price_per_unit,
           p_item_rec.un_number_id,
           p_item_rec.price_tolerance_percent,
           p_item_rec.asset_category_id,
           p_item_rec.rounding_factor,
           p_item_rec.unit_of_issue,
           p_item_rec.enforce_ship_to_location_code,
           p_item_rec.allow_substitute_receipts_flag,
           p_item_rec.allow_unordered_receipts_flag,
           p_item_rec.allow_express_delivery_flag,
           p_item_rec.days_early_receipt_allowed,
           p_item_rec.days_late_receipt_allowed,
           p_item_rec.receipt_days_exception_code,
           p_item_rec.receiving_routing_id,
           p_item_rec.invoice_close_tolerance,
           p_item_rec.receive_close_tolerance,
           p_item_rec.auto_lot_alpha_prefix,
           p_item_rec.start_auto_lot_number,
           p_item_rec.lot_control_code,
           p_item_rec.shelf_life_code,
           p_item_rec.shelf_life_days,
           p_item_rec.serial_number_control_code,
           p_item_rec.start_auto_serial_number,
           p_item_rec.auto_serial_alpha_prefix,
           p_item_rec.source_type,
           p_item_rec.source_organization_id,
           p_item_rec.source_subinventory,
           p_item_rec.expense_account,
           p_item_rec.encumbrance_account,
           p_item_rec.restrict_subinventories_code,
           p_item_rec.unit_weight,
           p_item_rec.weight_uom_code,
           p_item_rec.volume_uom_code,
           p_item_rec.unit_volume,
           p_item_rec.restrict_locators_code,
           p_item_rec.location_control_code,
           p_item_rec.shrinkage_rate,
           p_item_rec.acceptable_early_days,
           p_item_rec.planning_time_fence_code,
           p_item_rec.demand_time_fence_code,
           p_item_rec.lead_time_lot_size,
           p_item_rec.std_lot_size,
           p_item_rec.cum_manufacturing_lead_time,
           p_item_rec.overrun_percentage,
           p_item_rec.mrp_calculate_atp_flag,
           p_item_rec.acceptable_rate_increase,
           p_item_rec.acceptable_rate_decrease,
           p_item_rec.cumulative_total_lead_time,
           p_item_rec.planning_time_fence_days,
           p_item_rec.demand_time_fence_days,
           p_item_rec.end_assembly_pegging_flag,
           p_item_rec.repetitive_planning_flag,
           p_item_rec.planning_exception_set,
           p_item_rec.bom_item_type,
           p_item_rec.pick_components_flag,
           p_item_rec.replenish_to_order_flag,
           p_item_rec.base_item_id,
           p_item_rec.atp_components_flag,
           p_item_rec.atp_flag,
           p_item_rec.fixed_lead_time,
           p_item_rec.variable_lead_time,
           p_item_rec.wip_supply_locator_id,
           p_item_rec.wip_supply_type,
           p_item_rec.wip_supply_subinventory,
           p_item_rec.cost_of_sales_account,
           p_item_rec.sales_account,
           p_item_rec.default_include_in_rollup_flag,
           p_item_rec.inventory_item_status_code,
           p_item_rec.inventory_planning_code,
           p_item_rec.planner_code,
           p_item_rec.planning_make_buy_code,
           p_item_rec.fixed_lot_multiplier,
           p_item_rec.rounding_control_type,
           p_item_rec.carrying_cost,
           p_item_rec.postprocessing_lead_time,
           p_item_rec.preprocessing_lead_time,
           p_item_rec.summary_flag,
           p_item_rec.enabled_flag,
           p_item_rec.start_date_active,
           p_item_rec.end_date_active,
           p_item_rec.buyer_id,
           p_item_rec.accounting_rule_id,
           p_item_rec.invoicing_rule_id,
           p_item_rec.over_shipment_tolerance,
           p_item_rec.under_shipment_tolerance,
           p_item_rec.over_return_tolerance,
           p_item_rec.under_return_tolerance,
           p_item_rec.equipment_type,
           p_item_rec.recovered_part_disp_code,
           p_item_rec.defect_tracking_on_flag,
           p_item_rec.event_flag,
           p_item_rec.electronic_flag,
           p_item_rec.downloadable_flag,
           p_item_rec.vol_discount_exempt_flag,
           p_item_rec.coupon_exempt_flag,
           p_item_rec.comms_nl_trackable_flag,
           p_item_rec.asset_creation_code,
           p_item_rec.comms_activation_reqd_flag,
           p_item_rec.orderable_on_web_flag,
           p_item_rec.back_orderable_flag,
           p_item_rec.web_status,
           p_item_rec.indivisible_flag,
           p_item_rec.dimension_uom_code,
           p_item_rec.unit_length,
           p_item_rec.unit_width,
           p_item_rec.unit_height,
           p_item_rec.bulk_picked_flag,
           p_item_rec.lot_status_enabled,
           p_item_rec.default_lot_status_id,
           p_item_rec.serial_status_enabled,
           p_item_rec.default_serial_status_id,
           p_item_rec.lot_split_enabled,
           p_item_rec.lot_merge_enabled,
           p_item_rec.inventory_carry_penalty,
           p_item_rec.operation_slack_penalty,
           p_item_rec.financing_allowed_flag,
           p_item_rec.eam_item_type,
           p_item_rec.eam_activity_type_code,
           p_item_rec.eam_activity_cause_code,
           p_item_rec.eam_act_notification_flag,
           p_item_rec.eam_act_shutdown_status,
           p_item_rec.dual_uom_control,
           p_item_rec.secondary_uom_code,
           p_item_rec.dual_uom_deviation_high,
           p_item_rec.dual_uom_deviation_low,
           p_item_rec.contract_item_type_code,
           p_item_rec.subscription_depend_flag,
           p_item_rec.serv_req_enabled_code,
           p_item_rec.serv_billing_enabled_flag,
           p_item_rec.serv_importance_level,
           p_item_rec.planned_inv_point_flag,
           p_item_rec.lot_translate_enabled,
           p_item_rec.default_so_source_type,
           p_item_rec.create_supply_flag,
           p_item_rec.substitution_window_code,
           p_item_rec.substitution_window_days,
           p_item_rec.ib_item_instance_class,
           p_item_rec.config_model_type,
           p_item_rec.lot_substitution_enabled,
           p_item_rec.minimum_license_quantity,
           p_item_rec.eam_activity_source_code,
           p_item_rec.tracking_quantity_ind,
           p_item_rec.ont_pricing_qty_source,
           p_item_rec.secondary_default_ind,
           p_item_rec.option_specific_sourced,
           p_item_rec.config_orgs,
           p_item_rec.config_match,
           p_item_rec.segment1,
           p_item_rec.segment2,
           p_item_rec.segment3,
           p_item_rec.segment4,
           p_item_rec.segment5,
           p_item_rec.segment6,
           p_item_rec.segment7,
           p_item_rec.segment8,
           p_item_rec.segment9,
           p_item_rec.segment10,
           p_item_rec.segment11,
           p_item_rec.segment12,
           p_item_rec.segment13,
           p_item_rec.segment14,
           p_item_rec.segment15,
           p_item_rec.segment16,
           p_item_rec.segment17,
           p_item_rec.segment18,
           p_item_rec.segment19,
           p_item_rec.segment20,
           p_item_rec.attribute_category,
           p_item_rec.attribute1,
           p_item_rec.attribute2,
           p_item_rec.attribute3,
           p_item_rec.attribute4,
           p_item_rec.attribute5,
           p_item_rec.created_by,
           p_item_rec.last_updated_by,
           p_item_rec.last_update_login,
           p_item_rec.lifecycle_id,
           p_item_rec.current_phase_id,
           p_item_rec.vmi_minimum_units,
           p_item_rec.vmi_minimum_days,
           p_item_rec.vmi_maximum_units,
           p_item_rec.vmi_maximum_days,
           p_item_rec.vmi_fixed_order_quantity,
           p_item_rec.so_authorization_flag,
           p_item_rec.consigned_flag,
           p_item_rec.asn_autoexpire_flag,
           p_item_rec.vmi_forecast_type,
           p_item_rec.forecast_horizon,
           p_item_rec.exclude_from_budget_flag,
           p_item_rec.critical_component_flag,
           p_item_rec.continous_transfer,
           p_item_rec.convergence,
           p_item_rec.divergence,
           p_item_rec.drp_planned_flag,
           p_item_rec.days_tgt_inv_supply,
           p_item_rec.days_tgt_inv_window,
           p_item_rec.days_max_inv_supply,
           p_item_rec.days_max_inv_window,
           p_item_rec.lot_divisible_flag,
           p_item_rec.grade_control_flag,
           p_item_rec.default_grade,
           p_item_rec.child_lot_flag,
           p_item_rec.parent_child_generation_flag,
           p_item_rec.child_lot_prefix,
           p_item_rec.child_lot_starting_number,
           p_item_rec.child_lot_validation_flag,
           p_item_rec.copy_lot_attribute_flag,
           p_item_rec.process_execution_enabled_flag,
           p_item_rec.process_costing_enabled_flag,
           p_item_rec.retest_interval,
           p_item_rec.expiration_action_interval,
           p_item_rec.expiration_action_code,
           p_item_rec.maturity_days,
           p_item_rec.hold_days,
           p_item_rec.process_quality_enabled_flag,
           p_item_rec.recipe_enabled_flag,
           p_item_rec.process_supply_subinventory,
           p_item_rec.process_supply_locator_id,
           p_item_rec.process_yield_subinventory,
           p_item_rec.process_yield_locator_id,
           p_item_rec.hazardous_material_flag,
           p_item_rec.cas_number,
           p_item_rec.attribute16,
           p_item_rec.attribute17,
           p_item_rec.attribute18,
           p_item_rec.attribute19,
           p_item_rec.attribute20,
           p_item_rec.attribute21,
           p_item_rec.attribute22,
           p_item_rec.attribute23,
           p_item_rec.attribute24,
           p_item_rec.attribute25,
           p_item_rec.attribute26,
           p_item_rec.attribute27,
           p_item_rec.attribute28,
           p_item_rec.attribute29,
           p_item_rec.attribute30,
           p_item_rec.repair_leadtime,
           p_item_rec.repair_yield,
           p_item_rec.repair_program,
           p_item_rec.preposition_point,
           p_item_rec.charge_periodicity_code,
           p_item_rec.outsourced_assembly,
           p_item_rec.subcontracting_component,
           x_master_status
      FROM mtl_system_items_b b, mtl_system_items_tl t
     WHERE b.inventory_item_id = t.inventory_item_id
       AND b.organization_id = t.organization_id
       AND b.inventory_item_id = p_item_rec.inventory_item_id
       AND b.organization_id = p_master_org_id
       AND t.language = userenv('LANG');
  
    SELECT decode(p_item_rec.tracking_quantity_ind,
                  'P',
                  1,
                  decode(nvl(p_item_rec.secondary_default_ind, 'X'),
                         'F',
                         2,
                         'D',
                         3,
                         4))
      INTO p_item_rec.dual_uom_control
      FROM dual;
  
    p_item_rec.process_supply_subinventory := NULL;
    p_item_rec.process_supply_locator_id   := NULL;
    p_item_rec.process_yield_subinventory  := NULL;
    p_item_rec.process_yield_locator_id    := NULL;
    p_item_rec.wip_supply_locator_id       := NULL;
    p_item_rec.wip_supply_subinventory     := NULL;
    p_item_rec.base_warranty_service_id    := NULL;
    p_item_rec.planner_code                := NULL;
    p_item_rec.planning_exception_set      := NULL;
    p_item_rec.product_family_item_id      := NULL;
  
  END build_item_record;

END xxinv_item_org_assign_pkg;
/
