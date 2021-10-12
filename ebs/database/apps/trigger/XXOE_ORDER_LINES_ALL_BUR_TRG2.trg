create or replace trigger XXOE_ORDER_LINES_ALL_BUR_TRG2
--------------------------------------------------------------------
--  customization code: CHG0032648
--  name:               XXOE_ORDER_LINES_ALL_BUR_TRG2
--  create by:          Gary Altman
--  Revision:           1.0
--  creation date:      25.08.2014
--------------------------------------------------------------------
--  purpose :           Populate DFF of component SO line with PTO data
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   25.08.2014    Gary Altman     CHG0032648 - initial version
--  1.1   04/05/2015    Dalit A. Raviv  CHG0034234 - Update PTO Validation Setup
--  1.2   28.1.16       yuval tal       CHG0036068  adjust call to get_resin_credit_amount
--  1.3   25.8.16       L.Sarangi       CHG0038670 - The resin credit amount that is booked in Oracle is not the amount showing up on
--                                      user_item_description for Resin Credit logic Commented
--------------------------------------------------------------------

  before update of flow_status_code on OE_ORDER_LINES_ALL
  for each row

when (NEW.flow_status_code = 'BOOKED' and OLD.flow_status_code != 'BOOKED' and NEW.link_to_line_id is not null)
DECLARE
  l_parent_item_id  NUMBER;
  l_attr4           NUMBER;
  --l_desc            VARCHAR2(1000); -- Commented CHG0038670
  l_check_cs        NUMBER;
  l_order_type_id   NUMBER;
  l_context         VARCHAR2(30);
  l_order_date      DATE;
  l_order_curr_code oe_order_headers_all.transactional_curr_code%TYPE;
BEGIN

  l_parent_item_id := xx_om_pto_so_line_attr_pkg.get_parent_item_id(:new.header_id,
					        :new.top_model_line_id);
  -- Check item is resin credit
  IF xxoe_utils_pkg.is_item_resin_credit(:new.inventory_item_id) = 'Y' THEN
    -- CHG0036068
    SELECT h.ordered_date,
           h.transactional_curr_code
    INTO   l_order_date,
           l_order_curr_code
    FROM   oe_order_headers_all h
    WHERE  h.header_id = :new.header_id;

    l_attr4         := xx_om_pto_so_line_attr_pkg.get_resin_credit_amount(p_pto_item_id      => l_parent_item_id,
						  p_price_list_id    => :new.price_list_id,
						  p_to_currency_code => l_order_curr_code, --CHG0036068
						  p_conversion_date  => l_order_date); --CHG0036068
    :new.attribute4 := l_attr4;
    /* --  This Part is commented for CHG0038670 -The resin credit amount that is booked in Oracle is not the amount showing up on
       -- Commented on 25th aug 2016 
    BEGIN
      SELECT ((SELECT ooha.transactional_curr_code
	   FROM   oe_order_headers_all ooha
	   WHERE  ooha.header_id = :new.header_id) || ' ' || l_attr4 || ' ' ||
	 (SELECT t.description
	   FROM   mtl_system_items_tl t
	   WHERE  t.inventory_item_id = :new.inventory_item_id
	   AND    organization_id = :new.ship_from_org_id
	   AND    t.language = 'US'))
      INTO   l_desc
      FROM   dual;

      :new.user_item_description := l_desc;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;*/
  END IF; -- is_item_resin_credit

  -- check item relate to customer support
  BEGIN
    SELECT nvl(1, 0)
    INTO   l_check_cs
    FROM   mtl_item_categories_v         mic_sc,
           mtl_system_items_b            msi,
           xx_om_pto_so_lines_attributes pto
    WHERE  msi.inventory_item_id = :new.inventory_item_id
    AND    mic_sc.inventory_item_id = msi.inventory_item_id
    AND    mic_sc.organization_id = msi.organization_id
    AND    msi.organization_id = 91
    AND    mic_sc.category_set_name = 'Activity Analysis'
    AND    mic_sc.segment1 = 'Contracts'
    AND    msi.inventory_item_status_code NOT IN
           ('XX_DISCONT', 'Inactive', 'Obsolete')
    AND    msi.coverage_schedule_id IS NULL
    AND    msi.primary_uom_code != 'EA'
    AND    pto.pto_item = l_parent_item_id
    AND    pto.price_list = :new.price_list_id
    AND    pto.service_contract_item = :new.inventory_item_id;
  EXCEPTION
    WHEN OTHERS THEN
      l_check_cs := 0;
  END;

  IF l_check_cs = 1 THEN

    -- 1.1 04/05/2015 Dalit A. Raviv CHG0034234 - Update PTO Validation Setup ('BDL-SC')
    IF xx_om_pto_so_line_attr_pkg.get_pto_parent_category(:new.line_id) = 'N' THEN
      -- CHG0035139 Michal T. 25/05/2015
      /*:new.attribute12 := xx_om_pto_so_line_attr_pkg.get_maintenance_start_date
                                     (p_pto_item_id       => l_parent_item_id,
                                      p_price_list_id     => :new.price_list_id,
                                      p_inventory_item_id => :new.inventory_item_id);

      :new.attribute13 := xx_om_pto_so_line_attr_pkg.get_maintenance_end_date
                                     (p_pto_item_id       => l_parent_item_id,
                                      p_price_list_id     => :new.price_list_id,
                                      p_inventory_item_id => :new.inventory_item_id);      */

      :new.attribute15 := xx_om_pto_so_line_attr_pkg.get_line_id(:new.header_id,
					     :new.top_model_line_id);

    ELSE
      NULL; -- new logic for a ('BDL-SC') category
      xx_om_pto_so_line_attr_pkg.get_bdl_sc_dates(p_serial_number     => :new.attribute14, -- i v
				  p_so_line_id        => :new.line_id, -- i n
				  p_entity            => 'TRIGGER', -- i v
				  p_pto_item_id       => l_parent_item_id, -- i n
				  p_price_list_id     => :new.price_list_id, -- i n
				  p_inventory_item_id => :new.inventory_item_id, -- i n
				  p_start_date        => :new.attribute12, -- o d
				  p_end_date          => :new.attribute13); -- o d
    END IF;

    IF :new.attribute12 IS NOT NULL OR :new.attribute13 IS NOT NULL OR
       :new.attribute15 IS NOT NULL THEN
      BEGIN
        SELECT oh.order_type_id
        INTO   l_order_type_id
        FROM   oe_order_headers_all oh
        WHERE  oh.header_id = :new.header_id;

        SELECT t.name
        INTO   l_context
        FROM   oe_transaction_types_tl t
        WHERE  t.transaction_type_id = l_order_type_id
        AND    t.language = 'US';

        :new.context := l_context;

      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;
    -- End CHG0034234
  END IF; -- item relate to CS

END xxoe_order_lines_all_bur_trg2;
/
