CREATE OR REPLACE PACKAGE BODY xxagile_asl_pkg IS
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX.XX.XXXX                    initial revision
  --  1.1  18.08.2013  Vitaly            CR 870 std cost - change hard-coded organization
  --------------------------------------------------------------------

  -------------------------------------------
  --  get_vendor_id
  -------------------------------------------

  FUNCTION get_vendor_id(p_vandor_name VARCHAR2) RETURN NUMBER IS
    l_vendor_id NUMBER;
  BEGIN
  
    SELECT vendor_id
      INTO l_vendor_id
      FROM po_vendors v
     WHERE v.vendor_name = p_vandor_name;
  
    RETURN l_vendor_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  -------------------------------------------
  --  get_asl_status_id
  -------------------------------------------

  FUNCTION get_asl_status_id(p_asl_status_name VARCHAR2) RETURN NUMBER IS
    l_asl_status_id po_asl_statuses.status_id%TYPE;
  
  BEGIN
  
    SELECT v.status_id
      INTO l_asl_status_id
      FROM po_asl_statuses v
     WHERE v.status = p_asl_status_name;
    RETURN l_asl_status_id;
    RETURN l_asl_status_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  -------------------------------------------
  --  get_asl_status_id
  -------------------------------------------

  PROCEDURE get_item_id(p_item_code               VARCHAR2,
                        p_item_id                 OUT NUMBER,
                        p_primary_unit_of_measure OUT VARCHAR2) IS
  BEGIN
  
    SELECT mm.inventory_item_id, mm.primary_unit_of_measure
      INTO p_item_id, p_primary_unit_of_measure
      FROM mtl_system_items_b mm
     WHERE mm.segment1 = p_item_code
       AND mm.organization_id = xxinv_utils_pkg.get_master_organization_id;
  EXCEPTION
    WHEN OTHERS THEN
      p_item_id                 := NULL;
      p_primary_unit_of_measure := NULL;
  END;
  -------------------------------------------
  --  handle_asl
  --
  -- ITEM_IND : reminder for the indications for ASL are:

  --D – DELETE

  --A – ADD

  --U – UNCHANGED

  --C – CHANGED (comes in 2 rows: 1 with C, 1 with A).

  -------------------------------------------

  PROCEDURE handle_asl(p_seq_id      NUMBER,
                       p_err_code    OUT NUMBER,
                       p_err_message OUT VARCHAR2) IS
  
    asl_exception EXCEPTION;
  
    CURSOR c_rec IS
      SELECT t.*, decode(item_ind, 'D', 'Y', 'N') disable_flag
        FROM xxagile_asl_interface t
       WHERE t.seq_id = p_seq_id;
    l_vendor_id               NUMBER;
    l_asl_status_id           NUMBER;
    l_item_id                 NUMBER;
    l_vendor_site_id          NUMBER;
    l_primary_unit_of_measure VARCHAR2(50);
    l_record_unique           BOOLEAN;
    CURSOR c_vendor(c_vendor_id NUMBER) IS
      SELECT t.vendor_site_id
        FROM po_vendor_sites_all t
       WHERE t.vendor_id = c_vendor_id
         AND SYSDATE < nvl(t.inactive_date, SYSDATE + 1);
    --
    l_row_id VARCHAR2(100);
    l_asl_id NUMBER;
  BEGIN
    p_err_code    := 0;
    p_err_message := NULL;
  
    FOR i IN c_rec LOOP
    
      BEGIN
        -- in C no need to do update because there is another record in ITEM_IND='A'
        IF i.item_ind = 'C' THEN
          RETURN;
        END IF;
      
        -- validate values 
      
        l_asl_status_id := get_asl_status_id(i.asl_status);
        IF l_asl_status_id IS NULL AND i.item_ind != 'D' THEN
          p_err_message := 'ASL Status: id not found for value =' ||
                           i.asl_status || chr(13);
        
        END IF;
      
        l_vendor_id := get_vendor_id(i.vendor_name);
      
        IF l_vendor_id IS NULL THEN
          p_err_message := p_err_message ||
                           'Vendor id not found for value =' ||
                           i.vendor_name || chr(13);
        
        END IF;
      
        get_item_id(i.item_code, l_item_id, l_primary_unit_of_measure);
      
        IF l_item_id IS NULL THEN
          p_err_message := p_err_message || 'Item id not found for value =' ||
                           i.item_code;
        
        END IF;
      
        IF p_err_message IS NOT NULL THEN
          RAISE asl_exception;
        
        END IF;
      
        -- end validation
      
        -- start api
      
        FOR j IN c_vendor(l_vendor_id) LOOP
        
          l_asl_id         := NULL;
          l_vendor_site_id := j.vendor_site_id;
        
          -- check 
        
          l_record_unique := po_asl_sv.check_record_unique(x_manufacturer_id       => NULL,
                                                           x_vendor_id             => l_vendor_id,
                                                           x_vendor_site_id        => j.vendor_site_id,
                                                           x_item_id               => l_item_id,
                                                           x_category_id           => NULL,
                                                           x_using_organization_id => 735 /*IPK*/); ---90---WPI
        
          IF l_record_unique THEN
            po_asl_ths.insert_row(x_row_id                 => l_row_id, --  IN OUT NOCOPY  VARCHAR2,
                                  x_asl_id                 => l_asl_id, --   IN OUT  NOCOPY NUMBER,
                                  x_using_organization_id  => 735 /*IPK*/, ---90---WPI
                                  x_owning_organization_id => 735 /*IPK*/, ---90---WPI
                                  x_vendor_business_type   => 'DIRECT', --    VARCHAR2,
                                  x_asl_status_id          => l_asl_status_id, -- NUMBER,
                                  x_last_update_date       => SYSDATE, --    DATE,
                                  x_last_updated_by        => nvl(fnd_global.user_id,
                                                                  1650), --NUMBER,, --  NUMBER,
                                  x_creation_date          => SYSDATE, -- DATE,
                                  x_created_by             => nvl(fnd_global.user_id,
                                                                  1650), --NUMBER,
                                  x_manufacturer_id        => NULL, --  NUMBER,
                                  x_vendor_id              => l_vendor_id, --NUMBER,
                                  x_item_id                => l_item_id, --NUMBER,
                                  x_category_id            => NULL, -- NUMBER,
                                  x_vendor_site_id         => j.vendor_site_id, --NUMBER,
                                  x_primary_vendor_item    => NULL, --  VARCHAR2,
                                  x_manufacturer_asl_id    => NULL, -- NUMBER,
                                  x_comments               => NULL, --  VARCHAR2,
                                  x_review_by_date         => NULL, -- DATE,
                                  x_attribute_category     => NULL, -- VARCHAR2,
                                  x_attribute1             => NULL, --  VARCHAR2,
                                  x_attribute2             => NULL, --VARCHAR2,
                                  x_attribute3             => NULL, --  VARCHAR2,
                                  x_attribute4             => NULL, --  VARCHAR2,
                                  x_attribute5             => NULL, --  VARCHAR2,
                                  x_attribute6             => NULL, --  VARCHAR2,
                                  x_attribute7             => NULL, --  VARCHAR2,
                                  x_attribute8             => NULL, --  VARCHAR2,
                                  x_attribute9             => NULL, --  VARCHAR2,
                                  x_attribute10            => NULL, -- VARCHAR2,
                                  x_attribute11            => NULL, -- VARCHAR2,
                                  x_attribute12            => NULL, -- VARCHAR2,
                                  x_attribute13            => NULL, -- VARCHAR2,
                                  x_attribute14            => NULL, -- VARCHAR2,
                                  x_attribute15            => NULL, -- VARCHAR2,
                                  x_last_update_login      => NULL, --   NUMBER,
                                  x_disable_flag           => i.disable_flag --                         VARCHAR2
                                  );
            l_row_id := NULL;
          
            po_asl_attributes_ths.insert_row(x_row_id                     => l_row_id, --IN OUT NOCOPY   VARCHAR2,
                                             x_asl_id                     => l_asl_id, -- NUMBER,
                                             x_using_organization_id      => 735 /*IPK*/, ---90---WPI
                                             x_last_update_date           => SYSDATE, --   DATE,
                                             x_last_updated_by            => nvl(fnd_global.user_id,
                                                                                 1650), --NUMBER,, --     NUMBER,
                                             x_creation_date              => SYSDATE, -- DATE,
                                             x_created_by                 => nvl(fnd_global.user_id,
                                                                                 1650), -- NUMBER,
                                             x_document_sourcing_method   => 'ASL', --  VARCHAR2,
                                             x_release_generation_method  => NULL, --VARCHAR2,
                                             x_purchasing_unit_of_measure => l_primary_unit_of_measure, -- VARCHAR2,
                                             x_enable_plan_schedule_flag  => 'N', --VARCHAR2,
                                             x_enable_ship_schedule_flag  => 'N', --  VARCHAR2,
                                             x_plan_schedule_type         => NULL, --VARCHAR2,
                                             x_ship_schedule_type         => NULL, --  VARCHAR2,
                                             x_plan_bucket_pattern_id     => NULL, -- NUMBER,
                                             x_ship_bucket_pattern_id     => NULL, -- NUMBER,
                                             x_enable_autoschedule_flag   => NULL, -- VARCHAR2,
                                             x_scheduler_id               => NULL, -- NUMBER,
                                             x_enable_authorizations_flag => NULL, --    VARCHAR2,
                                             x_vendor_id                  => l_vendor_id, --NUMBER,
                                             x_vendor_site_id             => j.vendor_site_id, --  NUMBER,
                                             x_item_id                    => l_item_id, --  NUMBER,
                                             x_category_id                => NULL, --  NUMBER,
                                             x_attribute_category         => NULL, --  VARCHAR2,
                                             x_attribute1                 => NULL, -- VARCHAR2,
                                             x_attribute2                 => NULL, --    VARCHAR2,
                                             x_attribute3                 => NULL, --    VARCHAR2,
                                             x_attribute4                 => NULL, -- VARCHAR2,
                                             x_attribute5                 => NULL, -- VARCHAR2,
                                             x_attribute6                 => NULL, --    VARCHAR2,
                                             x_attribute7                 => NULL, -- VARCHAR2,
                                             x_attribute8                 => NULL, --    VARCHAR2,
                                             x_attribute9                 => NULL, --    VARCHAR2,
                                             x_attribute10                => NULL, --  VARCHAR2,
                                             x_attribute11                => NULL, --   VARCHAR2,
                                             x_attribute12                => NULL, --   VARCHAR2,
                                             x_attribute13                => NULL, --   VARCHAR2,
                                             x_attribute14                => NULL, --  VARCHAR2,
                                             x_attribute15                => NULL, --  VARCHAR2,
                                             x_last_update_login          => NULL, -- NUMBER,
                                             x_price_update_tolerance     => NULL, --           NUMBER,
                                             x_processing_lead_time       => NULL, --             NUMBER,
                                             x_delivery_calendar          => NULL, --           VARCHAR2,
                                             x_min_order_qty              => NULL, --             NUMBER,
                                             x_fixed_lot_multiple         => NULL, --             NUMBER,
                                             x_country_of_origin_code     => NULL, --             VARCHAR2,
                                             --  \* VMI FPH START *\
                                             x_enable_vmi_flag            => NULL, --                VARCHAR2,
                                             x_vmi_min_qty                => NULL, --                 NUMBER,
                                             x_vmi_max_qty                => NULL, --                  NUMBER,
                                             x_enable_vmi_auto_repl_flag  => NULL, --          VARCHAR2,
                                             x_vmi_replenishment_approval => NULL, --          VARCHAR2,
                                             --\* VMI FPH END *\
                                             --\* CONSSUP FPI START *\
                                             x_consigned_from_supplier_flag => NULL, --        VARCHAR2,
                                             x_consigned_billing_cycle      => NULL, --         NUMBER ,
                                             x_last_billing_date            => NULL, --              DATE,
                                             --\* CONSSUP FPI END *\
                                             --  \*FPJ START*\
                                             x_replenishment_method  => NULL, --               NUMBER,
                                             x_vmi_min_days          => NULL, --               NUMBER,
                                             x_vmi_max_days          => NULL, --                NUMBER,
                                             x_fixed_order_quantity  => NULL, --               NUMBER,
                                             x_forecast_horizon      => NULL, --              NUMBER,
                                             x_consume_on_aging_flag => NULL, --             VARCHAR2,
                                             x_aging_period          => NULL --                NUMBER
                                             
                                             );
          
          ELSE
            -- update mode
            UPDATE po_approved_supplier_list t
               SET t.asl_status_id    = nvl(l_asl_status_id, asl_status_id),
                   t.disable_flag     = i.disable_flag, --decode(i.item_ind, 'D', 'Y', 'N'),
                   t.last_update_date = SYSDATE
             WHERE t.vendor_id = l_vendor_id
               AND t.item_id = l_item_id
               AND t.vendor_site_id = j.vendor_site_id;
          END IF;
        
          COMMIT;
        
        END LOOP;
      
        -- end api
      
      EXCEPTION
        WHEN asl_exception THEN
          ROLLBACK;
          p_err_code := 1;
        
        WHEN OTHERS THEN
          ROLLBACK;
          p_err_code    := 1;
          p_err_message := 'seq_id=' || i.seq_id || ' ' ||
                           'l_asl_status_id=' ||
                          
                           l_asl_status_id || ' l_item_id=' || l_item_id ||
                           ' l_vendor_id=' || l_vendor_id ||
                           ' l_vendor_site_id=' || l_vendor_site_id || ' ' ||
                           SQLERRM;
      END;
    END LOOP;
  
  END;
  -------------------------------------------
  -- process_agile_asl_interface
  --
  -- cal byu bpel process xxAgileAslInterface
  -- take all lines from xxagile_asl_interface in api_status NEW 
  -- create or update as needed
  -- on error  : api_status='ERROR'

  -- re-run line : change to NEW from any status
  -------------------------------------------
  PROCEDURE process_agile_asl_interface(errbuf             OUT VARCHAR2,
                                        retcode            OUT NUMBER,
                                        p_bpel_instance_id NUMBER) IS
  
    CURSOR c_rec IS
      SELECT *
        FROM xxagile_asl_interface t
       WHERE t.api_status = 'IN_PROCESS'
         AND t.bpel_instance_id = p_bpel_instance_id;
  
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(2000);
  BEGIN
    retcode := 0;
    errbuf  := NULL;
  
    -- change to in process
    UPDATE xxagile_asl_interface t
       SET t.api_status = 'IN_PROCESS'
     WHERE t.api_status IN ('NEW', 'ERROR')
       AND t.bpel_instance_id = p_bpel_instance_id;
    COMMIT;
  
    -- deal with new lines
    FOR i IN c_rec LOOP
    
      handle_asl(i.seq_id, l_err_code, l_err_msg);
    
      UPDATE xxagile_asl_interface tt
         SET tt.api_status = decode(l_err_code, 1, 'ERROR', 'SUCCESS'),
             tt.note       = l_err_msg
      
       WHERE tt.seq_id = i.seq_id;
      COMMIT;
    
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'xxagile_asl_pkg.xxagile_asl_interface' || ' ' || SQLERRM;
  END;

  ----------------------------------------------------
  -- insert_row
  ----------------------------------------------------

  PROCEDURE insert_row(p_item_ind         VARCHAR2,
                       p_item_code        VARCHAR2,
                       p_vendor_name      VARCHAR2,
                       p_asl_status       VARCHAR2,
                       p_api_status       VARCHAR2,
                       p_note             VARCHAR2,
                       p_bpel_instance_id VARCHAR2,
                       p_file_name        VARCHAR2) AS
  BEGIN
  
    INSERT INTO xxagile_asl_interface
      (seq_id,
       item_ind,
       vendor_name,
       item_code,
       asl_status,
       api_status,
       -- status,
       note,
       bpel_instance_id,
       file_name)
    VALUES
      (xxagile_asl_interface_seq.nextval,
       p_item_ind,
       p_vendor_name,
       p_item_code,
       p_asl_status,
       p_api_status,
       -- p_status,
       substr(p_note, 1, 2000),
       p_bpel_instance_id,
       p_file_name);
    COMMIT;
  
  END;

END xxagile_asl_pkg;
/
