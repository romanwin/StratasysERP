CREATE OR REPLACE TRIGGER xxinv_item_cat_aiudr_trg4
--------------------------------------------------------------------
  --  name:            xxinv_item_cat_aiudr_trg4
  --  create by:       L.Sarangi
  --  Revision:        1.0
  --  creation date:   29.01.18
  --------------------------------------------------------------------
  --  purpose :        CHG0042203 - New 'System' item setup interface design
  --------------------------------------------------------------------
  --Version  Date       Developer          Comments
  --------------------------------------------------------------------
  --1.0      29.01.18   L.Sarangi          CHG0042203 - New 'System' item setup interface
  --1.1      14.05.18   L.Sarangi          CHG0042203 - 'BDL-Systems' added to the Condition 
  --1.2      21.-5.18   L.Sarangi          CHG0042204 - CTASK0036714 - Quote expiration on discontinued item
  --                                       Generate 'QUOTE_LINE' when ActivityAnalysis in ("Systems (net)", "Systems-Used", "BDL-Systems")
  --1.3      09.Jul.18  L.Sarangi          CHG0042204- CTASK0037417 - Bug Fixed     
  --1.4      05.Dec.18  L.Sarangi          CHG0044537 - Change Criteria on Quote Expiration on discontinued items                                              
  --------------------------------------------------------------------

  FOR INSERT OR UPDATE OR DELETE ON "INV"."MTL_ITEM_CATEGORIES"
  COMPOUND TRIGGER

  l_salespricebookexists   NUMBER := 0;
  l_activityanalysisexists NUMBER := 0;
  l_salespricebookid       NUMBER;
  l_activityanalysisid     NUMBER;
  l_intuseonlyid           NUMBER;

  TYPE t_inv_cat_tab IS TABLE OF NUMBER INDEX BY BINARY_INTEGER; --CTASK0037417
  l_inv_cat_tab t_inv_cat_tab;
  l_inv_item_id NUMBER;

  --CHG0042204 - CTASK0036714
  TYPE t_inv_cat_tab1 IS TABLE OF NUMBER INDEX BY BINARY_INTEGER; --CTASK0037417
  l_inv_cat_tab1 t_inv_cat_tab1;
  l_inv_item_id1 NUMBER;

  l_new_act_analysis VARCHAR2(1);
  l_old_act_analysis VARCHAR2(1);
  l_item_status_code VARCHAR2(240);
  l_internaluseonly  VARCHAR2(1);
  l_item_code        VARCHAR2(240);

  l_xxssys_event_rec xxssys_events%ROWTYPE;

  BEFORE STATEMENT IS
  BEGIN
    SELECT category_set_id
    INTO   l_salespricebookid
    FROM   mtl_category_sets
    WHERE  category_set_name = 'SALES Price Book Product Type';
  
    SELECT category_set_id
    INTO   l_activityanalysisid
    FROM   mtl_category_sets
    WHERE  category_set_name = 'Activity Analysis';
  
    --CHG0042204 - CTASK0036714 -
    --Get the 'Internal use only' Category Set ID
    SELECT category_set_id
    INTO   l_intuseonlyid
    FROM   mtl_category_sets
    WHERE  category_set_name = 'Internal use only';
  EXCEPTION
    WHEN no_data_found THEN
      l_salespricebookid   := NULL;
      l_activityanalysisid := NULL;
      l_intuseonlyid       := NULL;
  END BEFORE STATEMENT;

  --Executed before each row change- :NEW, :OLD are available
  BEFORE EACH ROW IS
  BEGIN
  
    IF nvl(:new.organization_id, :old.organization_id) = 91 THEN
      IF nvl(:new.category_set_id, :old.category_set_id) IN
         (l_salespricebookid, l_activityanalysisid) THEN
        l_inv_item_id := nvl(:new.inventory_item_id, :old.inventory_item_id);
        l_inv_cat_tab(l_inv_item_id) := l_inv_item_id;
      END IF;
    
      --Begin CHG0042204 - CTASK0036714 - Quote expiration on discontinued item
      l_new_act_analysis := 'N';
      l_old_act_analysis := 'N';
    
      --Is the new category set is "Activity Analysis"
      IF nvl(:new.category_set_id, -1) = l_activityanalysisid THEN
      
        BEGIN
          -- Is the  "Activity Analysis" Category Set NEW Value is one of the three
          SELECT 'Y'
          INTO   l_new_act_analysis
          FROM   mtl_categories_b mcb
          WHERE  mcb.category_id = nvl(:new.category_id, -1)
          AND    mcb.segment1 IN
	     ('Systems (net)', 'Systems-Used', 'BDL-Systems');
        
          BEGIN
            -- Is the  "Activity Analysis" Category Set OLD Value is one of the three
            SELECT 'Y'
            INTO   l_old_act_analysis
            FROM   mtl_categories_b mcb
            WHERE  mcb.category_id = nvl(:old.category_id, -1)
            AND    mcb.segment1 IN
                   ('Systems (net)', 'Systems-Used', 'BDL-Systems');
                  EXCEPTION
          WHEN no_data_found THEN
            l_old_act_analysis := 'N';
          END;
        
          --Category Set Value 
          -->If the OLD value is not one of the three value and the NEW value is one of the three
          -->consider the item for 'QUOTE LINE' event generation 
          IF l_new_act_analysis = 'Y' AND l_old_act_analysis = 'N' THEN
	         l_inv_item_id1 := nvl(:new.inventory_item_id,
		                     :old.inventory_item_id);
	         l_inv_cat_tab1(l_inv_item_id1) := l_inv_item_id1;
          END IF;
        
        EXCEPTION
          WHEN no_data_found THEN
            -- if the NEW category set value is not belongs on of three value, NO ACTION REQUIRED.
            l_new_act_analysis := 'N';
        END;
        --If the "Internal use only" category Set Value Added / Changed
      ELSIF nvl(:new.category_set_id, -1) = l_intuseonlyid AND
	        nvl(:new.category_id, -1) <> nvl(:old.category_id, -1) THEN
        --Check the New Value is 'Y'
        BEGIN
          SELECT 'Y'
          INTO   l_internaluseonly
          FROM   mtl_categories_b mcb
          WHERE  mcb.category_id = nvl(:new.category_id, -1)
          AND    mcb.segment1 = 'Y';
        
          IF --If the 'Activity Analysis' field value is valid , then only consider for Event Creation
           xxssys_oa2sf_util_pkg.get_category_value('Activity Analysis',
				    (nvl(:new.inventory_item_id,
				         :old.inventory_item_id))) IN
           ('Systems (net)', 'Systems-Used', 'BDL-Systems') THEN
	       l_inv_item_id1 := nvl(:new.inventory_item_id,
		          :old.inventory_item_id);
	       l_inv_cat_tab1(l_inv_item_id1) := l_inv_item_id1;
          END IF;
        
        EXCEPTION
          WHEN no_data_found THEN
	       l_internaluseonly := 'N';
        END;
      END IF;
      --End CHG0042204 - CTASK0036714 - Quote expiration on discontinued item 
    END IF;
  END BEFORE EACH ROW;

  ----------------------------------------
  -- AFTER STATEMENT Section:
  ----Executed after DML statement
  ----------------------------------------
  AFTER STATEMENT IS
  BEGIN
  
    IF l_inv_cat_tab.count() > 0 THEN
      l_inv_item_id := l_inv_cat_tab.first;
    
      WHILE (l_inv_item_id IS NOT NULL) LOOP
        --Any Record available for Category Set : 'SALES Price Book Product Type'
        SELECT COUNT(1)
        INTO   l_salespricebookexists
        FROM   mtl_item_categories
        WHERE  inventory_item_id = l_inv_item_id
        AND    category_set_id = l_salespricebookid
        AND    organization_id = 91
        AND    rownum = 1;
      
        IF l_salespricebookexists > 0 THEN
        
          SELECT COUNT(1)
          INTO   l_activityanalysisexists
          FROM   mtl_category_sets   mcs,
	     mtl_categories_b    mcb,
	     mtl_item_categories mic
          WHERE  mcs.structure_id = mcb.structure_id
          AND    mic.organization_id = 91
          AND    mic.category_set_id = mcs.category_set_id
          AND    mic.category_id = mcb.category_id
          AND    mic.inventory_item_id = l_inv_item_id
          AND    mcs.category_set_id = l_activityanalysisid
          AND    mcb.segment1 IN
	     ('Systems (net)', 'Systems-Used', 'BDL-Systems')
          AND    rownum = 1;
        
          IF l_activityanalysisexists > 0 THEN
            l_xxssys_event_rec                 := NULL;
            l_xxssys_event_rec.target_name     := 'STRATAFORCE';
            l_xxssys_event_rec.entity_name     := 'SYSTEM_SETUP';
            l_xxssys_event_rec.entity_id       := l_inv_item_id;
            l_xxssys_event_rec.entity_code     := xxinv_utils_pkg.get_item_segment(l_inv_item_id,
                                           91);
            l_xxssys_event_rec.last_updated_by := fnd_profile.value('USER_ID');
            l_xxssys_event_rec.created_by      := fnd_profile.value('USER_ID');
            l_xxssys_event_rec.event_name      := 'XXINV_ITEM_CAT_AIUDR_TRG4';
                  
            xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
          END IF;
        END IF;
      
        l_inv_item_id := l_inv_cat_tab.next(l_inv_item_id);
      
      END LOOP;
    END IF;
  
    --Begin CHG0042204 - CTASK0036714 - Quote expiration on discontinued item
    -- Loop all the Items and generate 'QUOTE LINE' event
    IF l_inv_cat_tab1.count() > 0 THEN
      l_inv_item_id1 := l_inv_cat_tab1.first;
      WHILE (l_inv_item_id1 IS NOT NULL) LOOP
      
        --fetch Item Status Code and Item Code for the Invetory Item Id  
        SELECT segment1,
	           inventory_item_status_code
        INTO   l_item_code,
	           l_item_status_code
        FROM   mtl_system_items_b
        WHERE  inventory_item_id = l_inv_item_id1
        AND    organization_id = 91;
       
      --CHG0044537 Added on 5Dec18 , If Statment Added for Restricting Event Generation
       IF l_item_status_code in ('XX_DISCONT', 'Obsolete') OR
          NVL(xxssys_oa2sf_util_pkg.get_category_value('Internal use only' ,l_inv_item_id1),'N') = 'Y'  
       THEN
       
        l_xxssys_event_rec                 := NULL;
        l_xxssys_event_rec.target_name     := 'STRATAFORCE';
        l_xxssys_event_rec.entity_name     := 'QUOTE_LINE';
        l_xxssys_event_rec.entity_id       := l_inv_item_id1;
        l_xxssys_event_rec.entity_code     := l_item_code;
        l_xxssys_event_rec.last_updated_by := fnd_profile.value('USER_ID');
        l_xxssys_event_rec.created_by      := fnd_profile.value('USER_ID');
        l_xxssys_event_rec.event_name      := 'XXINV_ITEM_CAT_AIUDR_TRG4';
        l_xxssys_event_rec.attribute2      := l_item_status_code; -- Item Status Code
        --If "Activity Analysis" Category Set value is one of ('Systems (net)' , 'Systems-Used' , 'BDL-Systems')
        --set Attribute3 Value as True
        l_xxssys_event_rec.attribute3 := 'True'; --
      
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
       
       END IF;
       
        l_inv_item_id1 := l_inv_cat_tab1.next(l_inv_item_id1); --Fetch the Next Item
      END LOOP;
    END IF;
    --End CHG0042204 - CTASK0036714 - Quote expiration on discontinued item
  
  END AFTER STATEMENT;

END xxinv_item_cat_aiudr_trg4;
/
