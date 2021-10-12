CREATE OR REPLACE PACKAGE BODY xxmsc_horizontal_plan_pkg IS

   g_num_mask CONSTANT VARCHAR2(50) := 'FM999999999999999999999.99999999999999999999';

   PROCEDURE customized_plan(p_query_id NUMBER) IS
   
      CURSOR item_c IS
         SELECT number1, -- real item id
                number2, -- org id
                number3, -- inst id
                number4, -- plan id
                number5, -- displayed item id
                number6 -- displayed org id
           FROM msc_form_query
          WHERE query_id = p_query_id AND
                number7 = 0; -- regular item node  .
   
      l_item_id         NUMBER;
      l_org_id          NUMBER;
      l_display_item_id NUMBER;
      l_display_org_id  NUMBER;
      l_inst_id         NUMBER;
      l_plan_id         NUMBER;
      l_date            DATE;
      l_qty             NUMBER;
      l_weight          NUMBER;
      l_volume          NUMBER;
   
      CURSOR date_bkt_c IS
         SELECT bucket_date
           FROM msc_material_plans
          WHERE query_id = p_query_id AND
                inventory_item_id = l_display_item_id AND
                organization_id = l_display_org_id AND
                sr_instance_id = l_inst_id AND
                horizontal_plan_type = 1 /*AND
                row_type = 20*/
          ORDER BY bucket_date;
   
      CURSOR data_c IS
         SELECT safety_stock_quantity
           FROM msc_safety_stocks
          WHERE inventory_item_id = l_item_id AND
                organization_id = l_org_id AND
                sr_instance_id = l_inst_id AND
                plan_id = l_plan_id AND
                period_start_date = l_date;
   
      l_plan_start_date DATE;
   
   BEGIN
      -- if you view more than one item at one time in HP, you need
      -- to know which item to update
      OPEN item_c;
      LOOP
         FETCH item_c
            INTO l_item_id, l_org_id, l_inst_id, l_plan_id, l_display_item_id, l_display_org_id;
      
         EXIT WHEN item_c%NOTFOUND;
         /* use p_item_id and p_org_id to find additional data for your
         item, you might need to join to msc_system_items to get
         the sr_inventory_item_id which is the item_id used in
         source instance */
      
         /*** update projected on hand ***/
         SELECT curr_start_date
           INTO l_plan_start_date
           FROM msc_plans
          WHERE plan_id = l_plan_id;
      
         UPDATE msc_material_plans q18
            SET quantity18 = (SELECT quantity17
                                FROM msc_material_plans q17
                               WHERE query_id = p_query_id AND
                                     inventory_item_id = l_display_item_id AND
                                     organization_id = l_display_org_id AND
                                     horizontal_plan_type = 1 AND
                                     trunc(bucket_date) =
                                     trunc(l_plan_start_date))
          WHERE query_id = p_query_id AND
                inventory_item_id = l_display_item_id AND
                organization_id = l_display_org_id AND
                horizontal_plan_type = 1 AND
                trunc(bucket_date) = trunc(l_plan_start_date - 1);
      
         /*** update internal order quantities (user defined) ***/
         UPDATE msc_material_plans q45
            SET quantity45 = (SELECT SUM(md.using_requirement_quantity)
                                FROM msc_demands md
                               WHERE plan_id = q45.plan_id AND
                                     md.origination_type = 30 AND /* Order */
                                     demand_class IS NULL AND
                                     md.inventory_item_id =
                                     q45.inventory_item_id AND
                                     md.organization_id = q45.organization_id AND
                                     trunc(md.using_assembly_demand_date) =
                                     trunc(q45.bucket_date))
          WHERE query_id = p_query_id AND
                inventory_item_id = l_display_item_id AND
                organization_id = l_display_org_id AND
                horizontal_plan_type = 1;
      
      END LOOP;
      CLOSE item_c;
   
   END customized_plan;

   PROCEDURE add_new_row(p_query_id NUMBER) IS
      CURSOR item_c IS
         SELECT number1, -- real item id 
                number2, -- org id 
                number3, -- inst id 
                number4, -- plan id 
                number5, -- displayed item id  
                number6 -- displayed org id  
           FROM msc_form_query
          WHERE query_id = p_query_id AND
                number7 = 0; -- regular item node
   
      p_item_id         NUMBER;
      p_org_id          NUMBER;
      p_display_item_id NUMBER;
      p_display_org_id  NUMBER;
      p_inst_id         NUMBER;
      p_plan_id         NUMBER;
      p_date            DATE;
      p_qty             NUMBER;
      p_weight          NUMBER;
      p_volume          NUMBER;
   
      CURSOR date_bkt_c IS
         SELECT bucket_date
           FROM msc_drp_hori_plans
          WHERE query_id = p_query_id AND
                inventory_item_id = p_display_item_id AND
                organization_id = p_display_org_id AND
                sr_instance_id = p_inst_id AND
                horizontal_plan_type = 1 AND
                row_type = 20
          ORDER BY bucket_date;
   
      CURSOR data_c IS
         SELECT safety_stock_quantity
           FROM msc_safety_stocks
          WHERE inventory_item_id = p_item_id AND
                organization_id = p_org_id AND
                sr_instance_id = p_inst_id AND
                plan_id = p_plan_id AND
                period_start_date = p_date;
   BEGIN
      -- if you view more than one item at one time in HP, you need 
      -- to know which item to update @             OPEN item_c; 
      LOOP
      
         FETCH item_c
            INTO p_item_id, p_org_id, p_inst_id, p_plan_id, p_display_item_id, p_display_org_id;
         EXIT WHEN item_c%NOTFOUND;
      
         /* use p_item_id and p_org_id to find additional data for your 
         item, you might need to join to msc_system_items to get 
         the sr_inventory_item_id which is the item_id used in 
         source instance */
         OPEN date_bkt_c;
      
         LOOP
         
            FETCH date_bkt_c
               INTO p_date;
            EXIT WHEN date_bkt_c%NOTFOUND;
         
            IF p_qty IS NULL THEN
               OPEN data_c;
               FETCH data_c
                  INTO p_qty;
               CLOSE data_c;
            END IF;
         
            INSERT INTO msc_drp_hori_plans
               (query_id,
                organization_id,
                sr_instance_id,
                inventory_item_id,
                row_type,
                sub_org_id,
                horizontal_plan_type,
                bucket_date,
                last_update_date,
                last_updated_by,
                creation_date,
                created_by,
                quantity,
                weight,
                volume)
            VALUES
               (p_query_id,
                p_display_org_id,
                p_inst_id,
                p_display_item_id,
                500, -- row_type 
                -1, -- sub org id 
                1, -- non enterprise view 
                p_date,
                SYSDATE,
                -1,
                SYSDATE,
                -1,
                p_qty,
                
                p_weight,
                p_volume);
         
         END LOOP;
      
         CLOSE date_bkt_c;
      
      END LOOP;
   
      CLOSE item_c;
   
   END add_new_row;

END xxmsc_horizontal_plan_pkg; -- /        commit;         exit;
/

