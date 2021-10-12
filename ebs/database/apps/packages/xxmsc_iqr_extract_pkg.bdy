CREATE OR REPLACE PACKAGE BODY xxmsc_iqr_extract_pkg AS

--------------------------------------------------------------------
--  name:            xxmsc_iqr_extract_pkg
--  create by:       Mike Mazanet
--  Revision:        1.1
--  creation date:   04/01/2015
--------------------------------------------------------------------
--  purpose : Package to handle IQR extract
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  04/01/2015  MMAZANET    Initial Creation for CHG0034833.
--------------------------------------------------------------------
  g_log           VARCHAR2(1)   := fnd_profile.value('AFLOG_ENABLED');
  g_log_module    VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
  g_program_unit  VARCHAR2(30);
  g_request_id    NUMBER   := TO_NUMBER(fnd_global.conc_request_id);
  g_user_id       NUMBER   := TO_NUMBER(fnd_profile.value('USER_ID')); 
  g_login_id      NUMBER   := TO_NUMBER(fnd_profile.value('LOGIN_ID')); 
  g_count         NUMBER   := 0;
  g_date          DATE;

  TYPE g_requirements_rec IS RECORD(
    requirements_next_month         NUMBER,
    requirements_next_2_months      NUMBER,
    requirements_next_3_months      NUMBER,
    requirements_next_6_months      NUMBER,
    requirements_next_12_months     NUMBER,
    requirements_next_13_24_months  NUMBER, 
    requirements_next_7_days        NUMBER,
    requirements_next_14_days       NUMBER,
    requirements_next_21_days       NUMBER,
    requirements_next_28_days       NUMBER,
    safety_stock                    NUMBER
  );

  TYPE g_usage_rec IS RECORD(
    last_transaction_date    DATE,
    usage_last_month         NUMBER,
    usage_last_2_months      NUMBER,
    usage_last_3_months      NUMBER,
    usage_last_6_months      NUMBER,
    usage_last_12_months     NUMBER,
    usage_last_24_months     NUMBER 
  );
  
  TYPE g_orders_rec IS RECORD(
    total_open_orders       NUMBER,
    total_open_orders_value NUMBER,
    order_1_number          VARCHAR2(100),
    order_1_type            VARCHAR2(1),
    order_1_quantity        NUMBER,
    order_1_due_date        DATE,
    order_2_number          VARCHAR2(100),
    order_2_type            VARCHAR2(1),
    order_2_quantity        NUMBER,
    order_2_due_date        DATE, 
    order_3_number          VARCHAR2(100),
    order_3_type            VARCHAR2(1),
    order_3_quantity        NUMBER,
    order_3_due_date        DATE,    
    order_4_number          VARCHAR2(100),
    order_4_type            VARCHAR2(1),
    order_4_quantity        NUMBER,
    order_4_due_date        DATE
  );
  
  TYPE g_items_rec IS RECORD(
    organization_id               NUMBER,
    plan_id                       NUMBER,
    inventory_item_id             NUMBER,
    planning_inventory_item_id    NUMBER,
    unit_cost                     NUMBER
  );
  
-- --------------------------------------------------------------------------------------------
-- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/01/2015  MMAZANET    Initial Creation for CHG0034833.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg  VARCHAR2)
  IS 
  BEGIN
     IF g_log = 'Y' AND 'xxmsc.iqr_extract.xxmsc_iqr_extract_pkg.'||g_program_unit LIKE LOWER(g_log_module) THEN
        fnd_file.put_line(fnd_file.log,TO_CHAR(SYSDATE,'HH:MI:SS')||' - '||p_msg); 
     END IF;
  END write_log; 

-- --------------------------------------------------------------------------------------------
-- Purpose: Write Error output
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/01/2015  MMAZANET    Initial Creation for CHG0034833.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE write_error(
    p_item_number     IN VARCHAR2,
    p_org_id          IN NUMBER,
    p_msg             IN VARCHAR2)
  IS 
  BEGIN
    fnd_file.put_line(fnd_file.output,RPAD(p_item_number,19,' ')||RPAD(p_org_id,5,' ')||p_msg);
  END write_error; 

-- --------------------------------------------------------------------------------------------
-- Purpose: Generates IQR File
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/01/2015  MMAZANET    Initial Creation for CHG0034833.
-- ---------------------------------------------------------------------------------------------  
  PROCEDURE generate_file(
    p_batch_name        IN  VARCHAR2,
    p_file_location     IN  VARCHAR2,
    p_file_name         IN  VARCHAR2,
    p_delimiter         IN  VARCHAR2  DEFAULT '|',
    x_return_status     OUT VARCHAR2,
    x_return_msg        OUT VARCHAR2
  )
  IS
    CURSOR c_rec 
    IS
      SELECT *
      FROM xxmsc_iqr_extract
      WHERE batch_name = p_batch_name
      ORDER BY 
        plant_id,
        part_number;
  
    l_file_type   UTL_FILE.FILE_TYPE;
    l_buffer      VARCHAR2(4000);    
  BEGIN
    g_program_unit := 'GENERATE_FILE';
    write_log('START '||g_program_unit); 

    EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY XXMSC_IQR_EXTRACT AS '||''''||p_file_location||'''';

    write_log('p_file_name: '||p_file_name);
    
    l_file_type := utl_file.fopen('XXMSC_IQR_EXTRACT',p_file_name,'W',32767);

    FOR rec IN c_rec LOOP
      l_buffer :=   NULL||p_delimiter  
                    ||rec.part_number||p_delimiter
                    ||rec.description||p_delimiter
                    ||rec.balance_on_hand||p_delimiter
                    ||rec.purchase_manufacture||p_delimiter
                    ||rec.stock_type||p_delimiter
                    ||rec.product_line||p_delimiter
                    ||rec.account_number||p_delimiter
                    ||rec.storeroom||p_delimiter
                    ||rec.new_item_code||p_delimiter
                    ||rec.planner_code||p_delimiter
                    ||rec.order_policy_code||p_delimiter 
                    ||rec.safety_stock||p_delimiter
                    ||rec.order_policy_quantity||p_delimiter
                    ||rec.minimum_order_quantity||p_delimiter
                    ||rec.order_multiple_quantity||p_delimiter
                    ||rec.lead_time||p_delimiter
                    ||rec.unit_of_measure||p_delimiter
                    ||rec.unit_cost||p_delimiter
                    ||rec.date_last_used||p_delimiter
                    ||rec.usage_past_month||p_delimiter
                    ||rec.usage_past_2_months||p_delimiter
                    ||rec.usage_past_3_months||p_delimiter
                    ||rec.usage_past_6_months||p_delimiter
                    ||rec.usage_past_12_months||p_delimiter
                    ||rec.usage_past_13_24_months||p_delimiter   
                    ||rec.requirements_next_month||p_delimiter
                    ||rec.requirements_next_2_months||p_delimiter
                    ||rec.requirements_next_3_months||p_delimiter
                    ||rec.requirements_next_6_months||p_delimiter
                    ||rec.requirements_next_12_months||p_delimiter
                    ||rec.requirements_next_13_24_months||p_delimiter
                    ||rec.open_order_#1_number||p_delimiter
                    ||rec.open_order_#1_type||p_delimiter  
                    ||rec.open_order_#1_quantity||p_delimiter  
                    ||rec.open_order_#1_due_date||p_delimiter  
                    ||rec.total_number_of_open_orders||p_delimiter  
                    ||rec.mrp_classification||p_delimiter
                    ||rec.total_value_of_all_open_orders||p_delimiter
                    ||rec.special_code||p_delimiter
                    ||rec.plant_id||p_delimiter
                    ||rec.vendor_code||p_delimiter
                    ||rec.buyer_code||p_delimiter          
                    ||rec.user_defined_1||p_delimiter
                    ||rec.user_defined_2||p_delimiter
                    ||rec.user_defined_3||p_delimiter
                    ||rec.user_defined_4||p_delimiter
                    ||rec.requirements_next_7_days||p_delimiter
                    ||rec.requirements_next_14_days||p_delimiter
                    ||rec.requirements_next_21_days||p_delimiter
                    ||rec.requirements_next_28_days||p_delimiter
                    ||rec.open_order_#2_number||p_delimiter
                    ||rec.open_order_#2_type||p_delimiter  
                    ||rec.open_order_#2_quantity||p_delimiter  
                    ||rec.open_order_#2_due_date||p_delimiter
                    ||rec.open_order_#3_number||p_delimiter
                    ||rec.open_order_#3_type||p_delimiter  
                    ||rec.open_order_#3_quantity||p_delimiter  
                    ||rec.open_order_#3_due_date||p_delimiter
                    ||rec.open_order_#4_number||p_delimiter
                    ||rec.open_order_#4_type||p_delimiter  
                    ||rec.open_order_#4_quantity||p_delimiter  
                    ||rec.open_order_#4_due_date;     
    
      utl_file.put_line(l_file_type,l_buffer);
    END LOOP;
 
    utl_file.fclose(l_file_type);
    x_return_status := 'S';
    write_log('END '||g_program_unit);
  EXCEPTION 
    WHEN OTHERS THEN
      utl_file.fclose(l_file_type);
      x_return_status := 'E';
      x_return_msg    := 'Unexpected error in generate_file: '||DBMS_UTILITY.FORMAT_ERROR_STACK;      
  END generate_file;

-- --------------------------------------------------------------------------------------------
-- Purpose: Gets item usage at various increments going back 2 years
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/01/2015  MMAZANET    Initial Creation for CHG0034833.
-- ---------------------------------------------------------------------------------------------  
  PROCEDURE get_usage(
    p_items_rec         IN  g_items_rec,
    x_usage_rec         OUT g_usage_rec,
    x_return_status     OUT VARCHAR2,
    x_return_msg        OUT VARCHAR2
  )
  IS   
    l_item_id       VARCHAR2(100);
    e_error         EXCEPTION;
  BEGIN
    g_program_unit := 'GET_USAGE';
    write_log('START '||g_program_unit);          
    
    -- Get usage for the following time increments
    -- Last 30,60,90,180,365,730 days.
    -- Multiplying by -1 shows the numbers in a more meaningful way to the users
    SELECT 
      -- Get last used date
      MAX(transaction_date)                           last_transaction_date,
      SUM(CASE 
        WHEN TRUNC(transaction_date) >= TRUNC(g_date) - 30 THEN NVL(transaction_quantity,0) * -1
        ELSE 0
      END
      )                                               usage_last_month,
      SUM(CASE 
        WHEN TRUNC(transaction_date) >= TRUNC(g_date) - 60 THEN NVL(transaction_quantity,0) * -1
        ELSE 0
      END
      )                                               usage_last_2_months,
      SUM(CASE 
        WHEN TRUNC(transaction_date) >= TRUNC(g_date) - 90 THEN NVL(transaction_quantity,0) * -1
        ELSE 0
      END
      )                                               usage_last_3_months,
      SUM(CASE 
        WHEN TRUNC(transaction_date) >= TRUNC(g_date) - 180 THEN NVL(transaction_quantity,0) * -1
        ELSE 0
      END
      )                                               usage_last_6_months,
      SUM(CASE 
        WHEN TRUNC(transaction_date) >= TRUNC(g_date) - 365 THEN NVL(transaction_quantity,0) * -1
        ELSE 0
      END
      )                                               usage_last_12_months,
      SUM(CASE 
        WHEN TRUNC(transaction_date) >= TRUNC(g_date) - 730 THEN NVL(transaction_quantity,0) * -1
        ELSE 0
      END
      )                                               usage_last_24_months 
    INTO 
      x_usage_rec.last_transaction_date,
      x_usage_rec.usage_last_month,
      x_usage_rec.usage_last_2_months,
      x_usage_rec.usage_last_3_months,
      x_usage_rec.usage_last_6_months,
      x_usage_rec.usage_last_12_months,
      x_usage_rec.usage_last_24_months
    FROM 
      mtl_material_transactions   mmt,
      mtl_transaction_types       mtt,
      fnd_lookup_values           flv
    WHERE mmt.transaction_type_id       = mtt.transaction_type_id   
    AND   mtt.transaction_type_name     = flv.description
    AND   flv.lookup_type               = 'XXSSYS_IQR_MTL_TRX_TYPES'
    AND   flv.language                  = USERENV('LANG')
    AND   mmt.inventory_item_id         = p_items_rec.inventory_item_id
    AND   mmt.organization_id           = p_items_rec.organization_id
    -- Get two years worth of data
    AND   TRUNC(mmt.transaction_date)   >= TRUNC(g_date) - 730;
 
    x_return_status := 'S';
    write_log('END '||g_program_unit);
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status := 'E';
      x_return_msg    := 'Unexpected error in get_usage: '||DBMS_UTILITY.FORMAT_ERROR_STACK;  
  END get_usage;

-- --------------------------------------------------------------------------------------------
-- Purpose: Horizontal plan is part of Advanced Supply Chain Planning.  Essentially, there is
--          a form which can be accessed via Inventory Planning responsibility with the following
--          navigation - Supply Chain Plan -> Workbench -> MRPplan -> Supply and Demand ->
--                       Supply and Demand
--          You can then search for an item and right click on it, which will give you the option
--          to see the Horizontal Plan.
--
--          Oracle generates this plan by calling the msc_horizontal_plan_sc.populate_horizontal_plan
--          procedure which populates the msc_material_plans temp table with 360 rows and various
--          attribute and quantity columns.  In our case, we're concerned with quantity19 (safety
--          stock) and quantity8 (requirements).
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/01/2015  MMAZANET    Initial Creation for CHG0034833.
-- ---------------------------------------------------------------------------------------------  
  PROCEDURE get_horizontal_plan_values(
    p_query_id          IN  NUMBER,
    p_items_rec         IN  g_items_rec,
    x_requirements_rec  OUT g_requirements_rec,
    x_return_status     OUT VARCHAR2,
    x_return_msg        OUT VARCHAR2
  )
  IS
    l_item_id       VARCHAR2(100);
  BEGIN
    g_program_unit := 'GET_HORIZONTAL_PLAN_VALUES';
    write_log('START '||g_program_unit);

    -- Clear tables for every calculation.  These are temp tables, so they are session
    -- specific, so there will not be issues truncating.
    EXECUTE IMMEDIATE 'TRUNCATE TABLE msc.msc_form_query';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE msc.msc_material_plans';

    write_log('After TRUNCATES');

    l_item_id := ''''||TO_CHAR(p_items_rec.planning_inventory_item_id)||'''';
    write_log(l_item_id);

    -- Populates msc_form_query table.  The row with this l_query_id
    -- is used in the populate_horizontal_plan to populate the msc_material_plans
    -- table.  These next two procedures populate the temp tables behind the
    -- Horizontal Planning Form.  We need this data to get rolling requirements.
    msc_horizontal_plan_sc.query_list(
      p_agg_hzp           => 0,
      p_query_id          => p_query_id,
      p_plan_id           => p_items_rec.plan_id,
      p_instance_id       => 0,
      p_org_list          => ''''||'(1,'||p_items_rec.organization_id||')'||'''',
      p_pf                => NULL,
      p_item_list         => ''||TO_CHAR(p_items_rec.planning_inventory_item_id)||''
    );        

    write_log('After query_list');

    msc_horizontal_plan_sc.populate_horizontal_plan (
      p_agg_hzp                 => 0,
      item_list_id              => p_query_id,
      arg_query_id              => p_query_id,
      arg_plan_id               => p_items_rec.plan_id,
      arg_plan_organization_id  => p_items_rec.organization_id,
      arg_plan_instance_id      => 1,
      arg_bucket_type           => 1,
      arg_cutoff_date           => g_date + 360
    );            
    
    write_log('After populate_horizontal_plan');

    -- Get requirements for the following time increments
    -- Next 7,14,21,28,30,60,90,180,360 days.
    SELECT 
      -- For safety stock, we want to get the MAX value for the week ahead.
      MAX(CASE 
            WHEN TRUNC(bucket_date) BETWEEN TRUNC(g_date) AND TRUNC(g_date) + 7 THEN NVL(quantity19,0)
            ELSE 0
          END
      )                 safety_stock,
      SUM(CASE 
            WHEN TRUNC(bucket_date) BETWEEN TRUNC(g_date) AND TRUNC(g_date) + 7 THEN NVL(quantity8,0)
            ELSE 0
          END
      )                 requirements_next_7_days,
      SUM(CASE 
            WHEN TRUNC(bucket_date) BETWEEN TRUNC(g_date) AND TRUNC(g_date) + 14 THEN NVL(quantity8,0)
            ELSE 0
          END
      )                 requirements_next_14_days,
      SUM(CASE 
            WHEN TRUNC(bucket_date) BETWEEN TRUNC(g_date) AND TRUNC(g_date) + 21 THEN NVL(quantity8,0)
            ELSE 0
          END
      )                 requirements_next_21_days,
      SUM(CASE 
            WHEN TRUNC(bucket_date) BETWEEN TRUNC(g_date) AND TRUNC(g_date) + 28 THEN NVL(quantity8,0)
            ELSE 0
          END
      )                 requirements_next_28_days,
      SUM(CASE 
            WHEN TRUNC(bucket_date) BETWEEN TRUNC(g_date) AND TRUNC(g_date) + 30 THEN NVL(quantity8,0)
            ELSE 0
          END
      )                 requirements_next_month,
      SUM(CASE 
            WHEN TRUNC(bucket_date) BETWEEN TRUNC(g_date) AND TRUNC(g_date) + 60 THEN NVL(quantity8,0)
            ELSE 0
          END
      )                 requirements_next_2_months,
      SUM(CASE 
            WHEN TRUNC(bucket_date) BETWEEN TRUNC(g_date) AND TRUNC(g_date) + 90 THEN NVL(quantity8,0)
            ELSE 0
          END
      )                 requirements_next_3_months,
      SUM(CASE 
            WHEN TRUNC(bucket_date) BETWEEN TRUNC(g_date) AND TRUNC(g_date) + 180 THEN NVL(quantity8,0)
            ELSE 0
          END
      )                 requirements_next_6_months,
      SUM(CASE 
            WHEN TRUNC(bucket_date) BETWEEN TRUNC(g_date) AND TRUNC(g_date) + 360 THEN NVL(quantity8,0)
            ELSE 0
          END
      )                 requirements_next_12_months
    INTO 
      x_requirements_rec.safety_stock,
      x_requirements_rec.requirements_next_7_days,
      x_requirements_rec.requirements_next_14_days,
      x_requirements_rec.requirements_next_21_days,
      x_requirements_rec.requirements_next_28_days,
      x_requirements_rec.requirements_next_month,
      x_requirements_rec.requirements_next_2_months,
      x_requirements_rec.requirements_next_3_months,
      x_requirements_rec.requirements_next_6_months,
      x_requirements_rec.requirements_next_12_months
    FROM msc_material_plans
    WHERE query_id              = p_query_id
    AND   inventory_item_id     = p_items_rec.planning_inventory_item_id
    AND   plan_id               = p_items_rec.plan_id
    AND   plan_organization_id  = p_items_rec.organization_id;
 
    x_return_status := 'S';
    write_log('END '||g_program_unit);
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status := 'E';
      x_return_msg    := 'Unexpected error in get_horizontal_plan_values: '||DBMS_UTILITY.FORMAT_ERROR_STACK;  
  END get_horizontal_plan_values;

-- --------------------------------------------------------------------------------------------
-- Purpose: Calls Oracle standard procedure to get total line balance due at the PO line level.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/01/2015  MMAZANET    Initial Creation for CHG0034833.
-- ---------------------------------------------------------------------------------------------  
  FUNCTION get_po_qty_due(p_po_line_location_id  IN NUMBER)
  RETURN NUMBER
  IS
    x_quantity_due            NUMBER;
    x_tolerable_quantity      NUMBER;
    x_unit_of_measure         VARCHAR2(100);

  BEGIN
    g_program_unit := 'GET_PO_QTY_DUE';
    write_log('START '||g_program_unit);
    write_log('p_po_line_location_id: '||p_po_line_location_id);
    
    x_quantity_due := 0;
    
    rcv_quantities_s.get_available_quantity(
      p_transaction_type          => 'RECEIVE',
      p_parent_id                 => p_po_line_location_id,
      p_receipt_source_code       => 'VENDOR',
      p_parent_transaction_type   => NULL,
      p_grand_parent_id           => NULL,
      p_correction_type           => NULL,
      p_available_quantity        => x_quantity_due,
      p_tolerable_quantity        => x_tolerable_quantity,
      p_unit_of_measure           => x_unit_of_measure
    );    
    
    write_log('x_quantity_due: '||x_quantity_due);
    
    RETURN x_quantity_due;
    write_log('END '||g_program_unit);  
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
      write_log('Unexpected error in get_horizontal_plan_values: '||DBMS_UTILITY.FORMAT_ERROR_STACK);    
  END get_po_qty_due;

-- --------------------------------------------------------------------------------------------
-- Purpose: Open orders consist of WIP jobs, Blanket Agreements, Purchase Orders, and Purchase 
--          Requisitions.  We combine all these below and get the total order quantity as well 
--          as various fields for orders.  IQR has room for details from 4 orders, which we can 
--          get from the c_orders CURSOR.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/01/2015  MMAZANET    Initial Creation for CHG0034833.
-- ---------------------------------------------------------------------------------------------  
  PROCEDURE get_open_orders(
    p_items_rec         IN  g_items_rec,
    x_orders_rec        OUT g_orders_rec,
    x_return_status     OUT VARCHAR2,
    x_return_msg        OUT VARCHAR2
  )
  IS
    CURSOR c_orders 
    IS
      SELECT 
        order_number,
        order_qty,
        order_date,
        order_type,
        order_item_id,
        -- Used to get details for four orders
        ROW_NUMBER() OVER(PARTITION BY order_item_id
                            ORDER BY order_date)
                                    rn,
        COUNT(*) OVER (PARTITION BY order_item_id)
                                    ct,
        -- Get total order quantity
        SUM(order_qty) OVER (PARTITION BY order_item_id)
                                    total_order_qty
      FROM
      /* all_orders... */
        -- Get WIP jobs
       (SELECT 
          we.wip_entity_name                        order_number,
          (wdj.start_quantity - wdj.quantity_completed - wdj.quantity_scrapped)
                                                    order_qty,
          wdj.scheduled_completion_date             order_date,
          'W'                                       order_type,
          we.primary_item_id                        order_item_id
        FROM   
          wip_discrete_jobs wdj,
          wip_entities      we
        WHERE wdj.wip_entity_id   = we.wip_entity_id
        AND   we.primary_item_id  = p_items_rec.inventory_item_id
        AND   we.organization_id  = p_items_rec.organization_id
        AND   we.organization_id  = wdj.organization_id
        AND   wdj.status_type     IN (1,3)
        AND   (wdj.start_quantity - wdj.quantity_completed - wdj.quantity_scrapped)  > 0
        UNION ALL
        -- Get purchase orders and Blanket Agreements.  Both may show up in multiple orgs in the case
        -- where the line is shipped to multiple warehouses.
        SELECT 
          poh.segment1                  order_number,
          NVL(xxmsc_iqr_extract_pkg.get_po_qty_due(plla.line_location_id),0)
                                        order_qty,
          NVL(plla.promised_date,plla.need_by_date)
                                        order_date,
          DECODE(poh.type_lookup_code,'STANDARD','P','R')
                                        order_type,
          pla.item_id                   order_item_id
        FROM   
          po_headers_all                  poh,
          po_lines_all                    pla,
          po_line_locations_all           plla
        WHERE pla.item_id                   = p_items_rec.inventory_item_id 
        AND   poh.po_header_id              = pla.po_header_id
        AND   poh.type_lookup_code         IN ('STANDARD','BLANKET')
        AND   pla.po_line_id                = plla.po_line_id               
        AND   plla.ship_to_organization_id  = p_items_rec.organization_id 
        UNION ALL
        -- Get purchase requisitions which are not yet purchase orders
        SELECT 
          prh.segment1              order_number,
          quantity                  order_qty,
          expected_delivery_date    order_date,
          'P'                       order_type,
          ms.item_id                order_item_id
        FROM   
          mtl_supply                  ms,
          po_requisition_headers_all  prh
        WHERE ms.item_id                = p_items_rec.inventory_item_id 
        AND   ms.to_organization_id     = p_items_rec.organization_id   
        AND   ms.supply_type_code       = 'REQ'
        AND   ms.destination_type_code  != 'SHOP FLOOR'
        AND   ms.req_header_id          = prh.requisition_header_id
        AND   ms.quantity               > 0
        AND   NOT EXISTS (SELECT NULL -- Exclude reqs that have POs
                          FROM 
                            po_requisition_lines_all  prla
                          , po_line_locations_all     plla
                          , po_lines_all              pla
                          WHERE prla.requisition_header_id  = prh.requisition_header_id
                          AND   prla.line_location_id       = plla.line_location_id
                          AND   plla.po_line_id             = pla.po_line_id 
                          AND   prla.closed_code            IS NULL
                          AND  (prla.cancel_flag            = 'N'
                          OR    prla.cancel_flag            IS NULL)
                         )
       )
      /* ...all_orders */      
      WHERE order_date  IS NOT NULL
      AND   order_qty   > 0  
      ORDER BY order_item_id;
    
  BEGIN
    g_program_unit := 'GET_OPEN_ORDERS';
    write_log('START '||g_program_unit);

    FOR rec IN c_orders LOOP
      -- Look at rn to get the separate order details.  rn=1 will get the total open orders,
      -- and total open orders value
      IF rec.rn = 1 THEN
        x_orders_rec.total_open_orders        := rec.ct;
        x_orders_rec.total_open_orders_value  := rec.total_order_qty * NVL(p_items_rec.unit_cost,0);  
        x_orders_rec.order_1_number           := rec.order_number;
        x_orders_rec.order_1_due_date         := rec.order_date;
        x_orders_rec.order_1_type             := rec.order_type;         
        x_orders_rec.order_1_quantity         := rec.order_qty;      
      ELSIF rec.rn = 2 THEN
        x_orders_rec.order_2_number           := rec.order_number;
        x_orders_rec.order_2_due_date         := rec.order_date;
        x_orders_rec.order_2_type             := rec.order_type;         
        x_orders_rec.order_2_quantity         := rec.order_qty;      
      ELSIF rec.rn = 3 THEN
        x_orders_rec.order_3_number           := rec.order_number;
        x_orders_rec.order_3_due_date         := rec.order_date;
        x_orders_rec.order_3_type             := rec.order_type;         
        x_orders_rec.order_3_quantity         := rec.order_qty;      
      ELSIF rec.rn = 4 THEN
        x_orders_rec.order_4_number           := rec.order_number;
        x_orders_rec.order_4_due_date         := rec.order_date;
        x_orders_rec.order_4_type             := rec.order_type;         
        x_orders_rec.order_4_quantity         := rec.order_qty;      
      END IF;
    END LOOP;
    
    x_return_status := 'S';
    write_log('END '||g_program_unit);
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status := 'E';
      x_return_msg    := 'Unexpected error in get_open_order_values: '||DBMS_UTILITY.FORMAT_ERROR_STACK;  
  END get_open_orders;

-- --------------------------------------------------------------------------------------------
-- Purpose: Gets unreleased Agreement quantity.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/01/2015  MMAZANET    Initial Creation for CHG0034833.
-- ---------------------------------------------------------------------------------------------  
  FUNCTION get_unreleased_qty(p_items_rec IN g_items_rec)
  RETURN NUMBER
  IS l_unreleased_qty NUMBER := 0;
  BEGIN 
    g_program_unit := 'GET_UNRELEASED_QTY';
    write_log('START '||g_program_unit);
    
    SELECT SUM(unreleased_qty)
    INTO l_unreleased_qty
    FROM
     (SELECT
        pl.quantity_committed
        -- sum line location quantity and subtract from line quantity committed
        - SUM(plla.quantity) OVER (PARTITION BY plla.po_line_id)
                                                      unreleased_qty,
        -- Use to get one line per line level
        ROW_NUMBER() OVER(PARTITION BY pl.po_line_id
                          ORDER BY ph.creation_date)  rn
      FROM 
        po_headers_all        ph,
        po_lines_all          pl,
        po_line_locations_all plla
      WHERE pl.po_header_id               = ph.po_header_id
      AND   plla.po_header_id             = ph.po_header_id
      AND   plla.po_line_id               = pl.po_line_id
      AND   ph.type_lookup_code           = 'BLANKET'
      -- Check for at least one open line on blanket
      AND   EXISTS (SELECT null
                    FROM
                      po_lines_all          pl1,
                      po_line_locations_all plla1              
                    WHERE pl1.cancel_date              IS NULL
                    AND   plla1.cancel_date            IS NULL
                    AND   plla1.closed_code            = 'OPEN'
                    AND   pl1.po_line_id              = plla1.po_line_id
                    AND   pl1.po_header_id            = ph.po_header_id)
      AND   plla.ship_to_organization_id  = p_items_rec.organization_id
      AND   pl.item_id                    = p_items_rec.inventory_item_id
     )
    WHERE rn              = 1
    AND   unreleased_qty  > 0;

    write_log('END '||g_program_unit);    
    RETURN l_unreleased_qty;
  EXCEPTION
    WHEN OTHERS THEN 
      write_log('Unexpected error in get_unreleased_qty: '||DBMS_UTILITY.FORMAT_ERROR_STACK);  
      RETURN 0;
  END get_unreleased_qty;

-- --------------------------------------------------------------------------------------------
-- Purpose: This is the main procedure to populate the xxmsc_iqr_extract and create the IQR file.
--          The c_items CURSOR does the work of finding most of the item data, however, we need to 
--          call several of the above procedures to get additional data for the extract.
--
--          This runs by p_org_id and p_plan_id.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/01/2015  MMAZANET    Initial Creation for CHG0034833.
-- ---------------------------------------------------------------------------------------------  
  PROCEDURE populate_table(
    p_org_id        IN  NUMBER,
    p_plan_id       IN  NUMBER,
    p_batch_name    IN  VARCHAR2,
    x_return_status OUT VARCHAR2,
    x_return_msg    OUT VARCHAR2
  )
  IS
    CURSOR c_items
    IS 
      SELECT 
        msib.inventory_item_id                      inventory_item_id,
        msib.organization_id                        organization_id,
        msib.segment1                               part_number,
        -- Remove carriage returns, line breaks, and other special characters
        REGEXP_REPLACE(REPLACE(REPLACE(msib.description,CHR(10),' '),CHR(13),' '), '[[:cntrl:]]', null)
                                                    description,
        on_hand_qty.sum_transaction_qty             balance_on_hand,
        CASE
          WHEN ood.organization_code = 'USE'
            AND make_use.inventory_item_id IS NOT NULL 
          THEN 'M'
          WHEN ood.organization_code = 'USE'
            AND make_use.inventory_item_id IS NULL
          THEN 'D'
          WHEN flv_make.meaning = 'Make' 
          THEN 'M'
          WHEN flv_make.meaning = 'Buy' 
          THEN 'P'
          ELSE NULL
        END                                         purchase_manufacture,
        SUBSTR(micv.segment7,1,4)                   stock_type,
        SUBSTR(flv_type.meaning,5,13)               product_line,
        NULL                                        storeroom,
        on_hand_qty.subinventory_code               user_defined_1,
        -- Created within the last 6 months should show 'N' here
        CASE 
          WHEN ADD_MONTHS(g_date,-6) < msib.creation_date THEN 'N' 
          ELSE NULL
        END                                         new_item_code,
        msib.planner_code                           planner_code,
        SUBSTR(flv_mrp.meaning,1,3)                 order_policy_code, 
        msi.inventory_item_id                       planning_inventory_item_id,
        msib.minimum_order_quantity                 minimum_order_quantity,
        msib.fixed_lot_multiplier                   order_multiple_quantity,
        msib.fixed_days_supply                      order_policy_qty,
        DECODE(flv_make.meaning
        , 'Make', NVL(msib.full_lead_time,0)
        , NVL(msib.full_lead_time,0) + NVL(msib.postprocessing_lead_time,0) + NVL(msib.preprocessing_lead_time,0)
        )                                           lead_time,
        msib.primary_unit_of_measure                unit_of_measure,
        cictv.item_cost                             unit_cost,
        SUBSTR(mis.inventory_item_status_code_tl,1,1)
                                                    special_code,
        maav.abc_class_name                         mrp_classification,
        ood.organization_code                       plant_id,
        approved_supplier.processing_lead_time      vendor_code,
        vendor.vendor_code                          user_defined_2,
        micv.segment1                               user_defined_3,
        flv_gp.meaning                              user_defined_4,
        SUBSTR(pav.agent_name,1,8)                  buyer_code
      FROM
        mtl_system_items_b          msib,
        mtl_item_status             mis,
        msc_system_items            msi,
        org_organization_definitions  
                                    ood,
        mtl_item_categories_v       micv,
        fnd_lookup_values           flv_type,
        fnd_lookup_values           flv_make,
        fnd_lookup_values           flv_mrp,
        fnd_lookup_values           flv_gp,
        cst_item_cost_type_v        cictv,
        mtl_abc_assignments_v       maav,
        po_agents_v                 pav,
      /* approved_supplier... */
       (SELECT 
          pasl.item_id,
          pasl.owning_organization_id,
          paa.processing_lead_time,
          -- We may get multiple rows per item.  If this is the case, we 
          -- want the 
          ROW_NUMBER() OVER (PARTITION BY pasl.item_id
                         ORDER BY paa.processing_lead_time DESC,
                                  paa.last_update_date DESC)    rn
        FROM 
          po_approved_supplier_list       pasl,
          po_asl_attributes               paa
        WHERE NVL(pasl.disable_flag,'N')      = 'N'
        AND   pasl.asl_id                     = paa.asl_id
        AND   pasl.owning_organization_id     = p_org_id
        AND   pasl.using_organization_id      = paa.using_organization_id
        AND   paa.processing_lead_time        IS NOT NULL
       )                            approved_supplier,
      /* ...approved_supplier */
      /* vendor... */
       (SELECT 
          msav.inventory_item_id,
          msav.organization_id,
          msav.sourcing_rule_name     vendor_code
        FROM 
          mrp_sr_assignments_v        msav,
          mrp_assignment_sets         mas
        WHERE msav.assignment_set_id    = mas.assignment_set_id 
        AND   'SSYS Global Assignment'  = mas.assignment_set_name        
       )                            vendor,
      /* ...vendor */
      /* on_hand_qty... */
       (SELECT 
          inventory_item_id,
          organization_id,
          subinventory_code,
          sum_transaction_qty
        FROM
         (SELECT 
            moq.inventory_item_id,
            moq.organization_id,
            moq.subinventory_code,
            -- Get transaction_quantity total for item/org
            SUM(NVL(moq.transaction_quantity,0)) OVER (PARTITION BY
                                                        moq.inventory_item_id,
                                                        moq.organization_id)
                                                                    sum_transaction_qty,
            -- This is used to get the subinventory_code with the MAX transaction_quantity
            ROW_NUMBER()  OVER (PARTITION BY  
                                  moq.inventory_item_id,
                                  moq.organization_id
                                ORDER BY moq.transaction_quantity DESC)  rn
          FROM 
            mtl_secondary_inventories     msi,
            mtl_material_statuses_tl      mmst,
            mtl_onhand_quantities         moq,
            fnd_lookup_values             flv
          WHERE msi.status_id                     = mmst.status_id
          and   mmst.language                     = userenv('LANG')
          AND   mmst.status_code                  = flv.description
          AND   'XXSSYS_IQR_MSC_STATUSES'         = flv.lookup_type
          AND   'Y'                               = flv.enabled_flag
          AND   userenv('LANG')                   = flv.language
          AND   msi.secondary_inventory_name      = moq.subinventory_code
          AND   msi.organization_id               = moq.organization_id
          AND   moq.organization_id               = p_org_id
         )
        -- Get subinventory with MAX transaction_quantity
        WHERE rn = 1 
       )                            on_hand_qty,
      /* ...on_hand_qty */      
      /* blanket_total... */
      /*
      (SELECT
          SUM(poh.blanket_total_amount)
          inventory_item_id
        FROM   
          po_headers_all                  poh,
          po_lines_all                    pla,
          po_line_locations_all           plla
        WHERE pla.item_id                   = p_items_rec.inventory_item_id 
        AND   poh.po_header_id              = pla.po_header_id
        AND   poh.type_lookup_code         IN ('STANDARD','BLANKET')
        AND   pla.po_line_id                = plla.po_line_id               
        AND   plla.ship_to_organization_id  = p_org_id
       )                             blanket_total,      
      */
      /* ...blanket_total */
      /* make_use... */
       (SELECT inventory_item_id
        FROM mrp_sr_assignments_v
        WHERE sourcing_rule_name  = 'MAKE_USE'
        AND   organization_id     = p_org_id
       )                             make_use
      /* ...make_use */
      WHERE msib.organization_id              = p_org_id
      -- Get planning items
      AND   p_plan_id                         = msi.plan_id (+)
      AND   msib.inventory_item_id            = msi.sr_inventory_item_id (+)
      AND   msib.organization_id              = msi.organization_id (+)
      -- Get category
      AND   msib.inventory_item_id            = micv.inventory_item_id (+)
      AND   msib.organization_id              = micv.organization_id (+)
      AND   'Product Hierarchy'               = micv.category_set_name (+)
      -- Get item status
      AND   msib.inventory_item_status_code   = mis.inventory_item_status_code
      -- Get org info
      AND   msib.organization_id              = ood.organization_id
      -- Get lookup values
      AND   msib.item_type                    = flv_type.lookup_code
      AND   'ITEM_TYPE'                       = flv_type.lookup_type
      AND   USERENV('LANG')                   = flv_type.language
      AND   msib.planning_make_buy_code       = flv_make.lookup_code (+)
      AND   'MTL_PLANNING_MAKE_BUY'           = flv_make.lookup_type (+)
      AND   USERENV('LANG')                   = flv_make.language (+)
      AND   msib.mrp_planning_code            = flv_mrp.lookup_code (+)
      AND   'MRP_PLANNING_CODE'               = flv_mrp.lookup_type (+)
      AND   USERENV('LANG')                   = flv_mrp.language (+)
      AND   msib.inventory_planning_code      = flv_gp.lookup_code (+)
      AND   'EGO_INVENTORY_PLANNING_CODE'     = flv_gp.lookup_type (+)
      AND   USERENV('LANG')                   = flv_gp.language (+)      
      -- Get Frozen Cost
      AND   msib.inventory_item_id            = cictv.inventory_item_id (+)
      AND   msib.organization_id              = cictv.organization_id (+)             
      AND   'Frozen'                          = cictv.cost_type (+)      
      -- Get abc class
      AND   msib.inventory_item_id            = maav.inventory_item_id (+)
      AND   msib.organization_id              = maav.organization_id (+)
      AND   'UME Assignment'                  = maav.assignment_group_name (+)      
      -- Get processing lead time from Approved Supplier List
      AND   msib.inventory_item_id            = approved_supplier.item_id (+)
      AND   msib.organization_id              = approved_supplier.owning_organization_id (+)
      AND   1                                 = approved_supplier.rn (+)          
      -- Get vendor code
      AND   msib.inventory_item_id            = vendor.inventory_item_id (+)
      AND   msib.organization_id              = vendor.organization_id (+)
      -- Get buyer
      AND   msib.buyer_id                     = pav.agent_id (+)
      -- Get on-hand qty
      AND   msib.inventory_item_id            = on_hand_qty.inventory_item_id (+)
      AND   msib.organization_id              = on_hand_qty.organization_id (+)
      -- Check for MAKE USE
      AND   msib.inventory_item_id            = make_use.inventory_item_id (+)  
      ;
      
      l_requirements_rec      g_requirements_rec;
      l_usage_rec             g_usage_rec;
      l_orders_rec            g_orders_rec;
      l_items_rec             g_items_rec;
      l_query_id              NUMBER;
      l_unreleased_qty        NUMBER := 0;
      
      l_error_flag            VARCHAR2(1) := 'N';
      
      e_error                 EXCEPTION;
      
      l_success_records       NUMBER := 0;
      l_error_records         NUMBER := 0;
  BEGIN
    g_program_unit := 'POPULATE_TABLE';
    write_log('START '||g_program_unit);

    g_date  := SYSDATE;
    write_log('g_date: '||TO_CHAR(g_date,'DD-MON-YYYY HH24:MI:SS'));

    fnd_file.put_line(fnd_file.output,'    Item Number      Org ID  Message');
    fnd_file.put_line(fnd_file.output,'-------------------  ------ '||RPAD('-',100,'-'));

    -- Get sequence number to use for calculating in get_horizontal_plan_values
    SELECT msc_form_query_s.nextval
    INTO l_query_id
    FROM DUAL;  

    write_log('l_query_id: '||l_query_id);
    
    --EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxmsc_iqr_extract';
  
    FOR rec IN c_items LOOP
      BEGIN
        write_log('*** Beginning processing for inventory_item_id '||rec.inventory_item_id||' ***');
        l_requirements_rec  := NULL;
        l_usage_rec         := NULL;
        l_orders_rec        := NULL;
        l_items_rec         := NULL;
        
        l_items_rec.organization_id               := rec.organization_id;
        l_items_rec.plan_id                       := p_plan_id;
        l_items_rec.inventory_item_id             := rec.inventory_item_id;
        l_items_rec.planning_inventory_item_id    := rec.planning_inventory_item_id;
        l_items_rec.unit_cost                     := rec.unit_cost;
        
        get_horizontal_plan_values(
          p_query_id          => l_query_id,
          p_items_rec         => l_items_rec,
          x_requirements_rec  => l_requirements_rec,
          x_return_status     => x_return_status,
          x_return_msg        => x_return_msg
        );
        
        write_log('Return status for get_horizontal_plan_values '||x_return_status);
        
        IF x_return_status <> 'S' THEN
          RAISE e_error;
        END IF;

        get_usage(
          p_items_rec       => l_items_rec,
          x_usage_rec       => l_usage_rec,
          x_return_status   => x_return_status,
          x_return_msg      => x_return_msg
        );

        write_log('Return status for get_usage '||x_return_status);
        
        IF x_return_status <> 'S' THEN
          RAISE e_error;
        END IF;

        get_open_orders(
          p_items_rec       => l_items_rec,
          x_orders_rec      => l_orders_rec,
          x_return_status   => x_return_status,
          x_return_msg      => x_return_msg
        );

        write_log('Return status for get_open_orders '||x_return_status);
        
        IF x_return_status <> 'S' THEN
          RAISE e_error;
        END IF;

        l_unreleased_qty := get_unreleased_qty(l_items_rec);
        write_log('l_unreleased_qty: '||l_unreleased_qty);
        
        write_log('Inserting into xxmsc_iqr_extract');
        
        INSERT INTO xxmsc_iqr_extract(
          batch_name,
          request_id,
          part_number,
          description,
          balance_on_hand,
          purchase_manufacture,
          stock_type,
          product_line,
          account_number,
          storeroom,
          new_item_code,
          planner_code,
          order_policy_code, 
          safety_stock,
          order_policy_quantity,
          minimum_order_quantity,
          order_multiple_quantity,
          lead_time,
          unit_of_measure,
          unit_cost,
          date_last_used,
          usage_past_month,
          usage_past_2_months,
          usage_past_3_months,
          usage_past_6_months,
          usage_past_12_months,
          usage_past_13_24_months,   
          requirements_next_month,
          requirements_next_2_months,
          requirements_next_3_months,
          requirements_next_6_months,
          requirements_next_12_months,
          requirements_next_13_24_months,
          open_order_#1_number,
          open_order_#1_type,  
          open_order_#1_quantity,  
          open_order_#1_due_date,  
          total_number_of_open_orders,  
          mrp_classification,
          total_value_of_all_open_orders,
          special_code,
          plant_id,
          vendor_code,
          buyer_code,          
          user_defined_1,
          user_defined_2,
          user_defined_3,
          user_defined_4,
          requirements_next_7_days,
          requirements_next_14_days,
          requirements_next_21_days,
          requirements_next_28_days,
          open_order_#2_number,
          open_order_#2_type,  
          open_order_#2_quantity,  
          open_order_#2_due_date,
          open_order_#3_number,
          open_order_#3_type,  
          open_order_#3_quantity,  
          open_order_#3_due_date,
          open_order_#4_number,
          open_order_#4_type,  
          open_order_#4_quantity,  
          open_order_#4_due_date          
        )
        VALUES(
          p_batch_name,                                                 -- batch_name
          g_request_id,                                                 -- request_id
          rec.part_number,                                              -- part_number          
          rec.description,                                              -- description          
          rec.balance_on_hand,                                          -- balance_on_hand          
          rec.purchase_manufacture,                                     -- purchase_manufacture          
          rec.stock_type,                                               -- stock_type          
          rec.product_line,                                             -- product_line          
          l_unreleased_qty,                                             -- account_number (unreleased quantity)          
          rec.storeroom,                                                -- storeroom
          rec.new_item_code,                                            -- new_item_code          
          rec.planner_code,                                             -- planner_code          
          rec.order_policy_code,                                        -- order_policy_code            
          l_requirements_rec.safety_stock,                              -- safety_stock           
          rec.order_policy_qty,                                         -- order_policy_quantity                
          rec.minimum_order_quantity,                                   -- minimum_order_quantity          
          rec.order_multiple_quantity,                                  -- order_multiple_quantity          
          rec.lead_time,                                                -- lead_time          
          rec.unit_of_measure,                                          -- unit_of_measure          
          rec.unit_cost,                                                -- unit_cost          
          TO_CHAR(l_usage_rec.last_transaction_date,'YYYYMMDD'),        -- date_last_used                              
          l_usage_rec.usage_last_month,                                 -- usage_past_month          
          l_usage_rec.usage_last_2_months,                              -- usage_past_2_months          
          l_usage_rec.usage_last_3_months,                              -- usage_past_3_months          
          l_usage_rec.usage_last_6_months,                              -- usage_past_6_months          
          l_usage_rec.usage_last_12_months,                             -- usage_past_12_months          
          l_usage_rec.usage_last_24_months,                             -- usage_past_13_24_months                                                                                                                                    
          l_requirements_rec.requirements_next_month,                   -- requirements_next_month          
          l_requirements_rec.requirements_next_2_months,                -- requirements_next_2_months          
          l_requirements_rec.requirements_next_3_months,                -- requirements_next_3_months          
          l_requirements_rec.requirements_next_6_months,                -- requirements_next_6_months          
          l_requirements_rec.requirements_next_12_months,               -- requirements_next_12_months          
          TO_NUMBER(NULL),                                              -- requirements_next_13_24_months
          l_orders_rec.order_1_number,                                  -- open_order_#1_number
          l_orders_rec.order_1_type,                                    -- open_order_#1_type  
          l_orders_rec.order_1_quantity,                                -- open_order_#1_quantity  
          TO_CHAR(l_orders_rec.order_1_due_date,'YYYYMMDD'),            -- open_order_#1_due_date  
          l_orders_rec.total_open_orders,                               -- total_number_of_open_orders  
          rec.mrp_classification,                                       -- mrp_classification
          l_orders_rec.total_open_orders_value,                         -- total_value_of_all_open_orders
          rec.special_code,                                             -- special_code
          rec.plant_id,                                                 -- plant_id
          rec.vendor_code,                                              -- vendor_code
          rec.buyer_code,                                               -- buyer_code          
          rec.user_defined_1,                                           -- user_defined_1                        
          rec.user_defined_2,                                           -- user_defined_2                        
          rec.user_defined_3,                                           -- user_defined_3          
          rec.user_defined_4,                                           -- user_defined_4           
          l_requirements_rec.requirements_next_7_days,                  -- requirements_next_7_days          
          l_requirements_rec.requirements_next_14_days,                 -- requirements_next_14_days          
          l_requirements_rec.requirements_next_21_days,                 -- requirements_next_21_days          
          l_requirements_rec.requirements_next_28_days,                 -- requirements_next_28_days
          l_orders_rec.order_2_number,                                  -- open_order_#2_number
          l_orders_rec.order_2_type,                                    -- open_order_#2_type  
          l_orders_rec.order_2_quantity,                                -- open_order_#2_quantity  
          TO_CHAR(l_orders_rec.order_2_due_date,'YYYYMMDD'),            -- open_order_#2_due_date
          l_orders_rec.order_3_number,                                  -- open_order_#3_number
          l_orders_rec.order_3_type,                                    -- open_order_#3_type  
          l_orders_rec.order_3_quantity,                                -- open_order_#3_quantity  
          TO_CHAR(l_orders_rec.order_3_due_date,'YYYYMMDD'),            -- open_order_#3_due_date
          l_orders_rec.order_4_number,                                  -- open_order_#4_number
          l_orders_rec.order_4_type,                                    -- open_order_#4_type  
          l_orders_rec.order_4_quantity,                                -- open_order_#4_quantity  
          TO_CHAR(l_orders_rec.order_4_due_date,'YYYYMMDD')             -- open_order_#4_due_date          
        );
        
        x_return_status := 'S';
      EXCEPTION  
        WHEN e_error THEN
          x_return_status := 'E';
        WHEN OTHERS THEN
          x_return_status := 'E';
          x_return_msg    := 'Unexpected error in populate_table: '||DBMS_UTILITY.FORMAT_ERROR_STACK;          
      END;
      IF x_return_status <> 'S' THEN
        write_error(rec.part_number,rec.plant_id,x_return_msg);
        l_error_records := l_error_records + 1;
        l_error_flag    := 'Y';
      ELSE
        l_success_records := l_success_records + 1;
      END IF;
    END LOOP;
  
    IF l_error_flag = 'Y' THEN
      x_return_status := 'E'; 
    ELSE
      x_return_status := 'S';   
    END IF;
  
    fnd_file.put_line(fnd_file.output,'Record Totals'); 
    fnd_file.put_line(fnd_file.output,'********************************');
    fnd_file.put_line(fnd_file.output,'Success Total: '||l_success_records);
    fnd_file.put_line(fnd_file.output,'Error Total  : '||l_error_records);
  
    write_log('END '||g_program_unit);
  EXCEPTION
    WHEN e_error THEN
      x_return_status := 'E';
    WHEN OTHERS THEN
      x_return_status := 'E';
      x_return_msg    := 'Unexpected error in populate_table: '||DBMS_UTILITY.FORMAT_ERROR_STACK;  
  END populate_table;

-- --------------------------------------------------------------------------------------------
-- Purpose: Main procedure called from XXMSC_IQR_EXTRACT concurrent executable.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/01/2015  MMAZANET    Initial Creation for CHG0034833.
-- ---------------------------------------------------------------------------------------------  
  PROCEDURE main(
    errbuff           OUT VARCHAR2,
    retcode           OUT NUMBER,
    p_action          IN  VARCHAR2,
    p_batch_name      IN  VARCHAR2,
    p_file_location   IN  VARCHAR2,
    p_file_name       IN  VARCHAR2,
    p_delimiter       IN  VARCHAR2,
    p_org_id          IN  NUMBER,
    p_plan_id         IN  NUMBER
  )
  IS
    l_return_status   VARCHAR2(1);   
    l_return_msg      VARCHAR2(1000);
    l_batch_name      VARCHAR2(100);
    
    e_error           EXCEPTION;
  BEGIN
    g_program_unit := 'MAIN';
    write_log('START '||g_program_unit);
    write_log('p_action: '||p_action);
    write_log('p_batch_name: '||p_batch_name);
    write_log('p_file_location: '||p_file_location);
    write_log('p_file_name: '||p_file_name);
    write_log('p_org_id: '||p_org_id);
    write_log('p_plan_id: '||p_plan_id);

    IF p_action = 'TRUNCATE' THEN 
      EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxmsc_iqr_extract';
      
    ELSIF p_action = 'POPULATE' THEN
      populate_table(
        p_org_id        => p_org_id,
        p_plan_id       => p_plan_id, 
        p_batch_name    => p_batch_name,
        x_return_status => l_return_status,
        x_return_msg    => l_return_msg
      );  

      write_log('Return status for populate_table '||l_return_status);

      IF l_return_status <> 'S' THEN
        RAISE e_error;
      END IF;

    ELSIF p_action = 'GENERATE' THEN 
      generate_file(
        p_batch_name    => p_batch_name,
        p_file_location => p_file_location,
        p_file_name     => p_file_name,
        p_delimiter     => p_delimiter,
        x_return_status => l_return_status,
        x_return_msg    => l_return_msg      
      );

      IF l_return_status <> 'S' THEN
        RAISE e_error;
      END IF;
    END IF;
 
    write_log('END '||g_program_unit);
  EXCEPTION
    WHEN e_error THEN
      retcode := 2; 
      fnd_file.put_line(fnd_file.output,l_return_msg);
    WHEN OTHERS THEN
      retcode := 2;
      fnd_file.put_line(fnd_file.output,'Unexpected error in MAIN routine: '||DBMS_UTILITY.FORMAT_ERROR_STACK);  
  END main;

END xxmsc_iqr_extract_pkg;

/
SHOW ERRORS