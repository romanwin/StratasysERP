CREATE OR REPLACE PACKAGE BODY oe_dependencies_extn AS
  /* $Header: OEXEDEPB.pls 130.1 2006/04/03 11:33:12 chhung noship $ */

  --  Global constant holding the package name

  g_pkg_name CONSTANT VARCHAR2(30) := 'OE_Dependencies_Extn';

  -- ----------------------------------------------------------------------------------------
  --  Name        : OE_Dependencies_Extn
  --  Created By  : Diptasurjya Chatterjee
  --
  --  Purpose     : Standard Extensible package for defining extra source and destination attribute
  --                mapping at Header or LINE level
  --  Ver Date        Name          Description
  -- -----------------------------------------------------------------------------------------
  --  1.0 11/09/2015  Diptasurjya   CHG0036423 - The source destination relation for G_INVENTORY_ITEM
  --                  Chatterjee                 and G_SHIPPING_METHOD has been enabled. Also the version of
  --                                             this package has been increased to 130.1 from 120.1 to
  --                                             prevent future patches from overwriting this change
  --  1.1 11/23/2015  Sandeep Akula CHG0037039 - Added Dependency between G_FREIGHT_TERMS AND G_INVENTORY_ITEM
  --  1.2 12/03/2015  Diptasurjya   CHG0037039 - Added Header Dependency between G_ORDER_TYPE and G_SALESREP
  --   1.3 24-Apr-17   Rimpi        CHG0040568 -  Added Dependency between G_INVENTORY_ITEM AND G_INTERMED_SHIP_TO_ORG
  --  1.4  16.5.17     yuval tal    CHG0040763 -  Ship To Contact and Bill To Contact defaulting change
  -- 1.5 2.10.17       yuval tal    CHG0041582  - add dep item and line type 
  -- -----------------------------------------------------------------------------------------
  PROCEDURE load_entity_attributes(p_entity_code  IN VARCHAR2,
		           x_extn_dep_tbl OUT NOCOPY dep_tbl_type)
  
   IS
    l_index NUMBER;
    --
    l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    --
  BEGIN
  
    -- In order to start using the package:
    -- 1)Increase the version number in the header line to a high value
    -- => Header: OEXEDEPB.pls 115.1000. This would prevent patches
    -- from over-writing this package in the future.
    -- 2)Included are some examples on how to enable/disable dependencies
    -- Please use these guidelines to edit dependencies as per your
    -- defaulting rules. Please note that:
    --     i) List of attributes is restricted to those in the earlier
    --        comments in this file.
    --     ii) Source attribute and dependent attribute should belong
    --        to the same entity!
    --        This API does not support dependencies across entities i.e.
    --        changing an attribute on order header will not result in
    --        a change to attributes on order line.
    -- 3)Uncomment this code and compile.
  
    oe_debug_pub.add('Enter OE_Dependencies_Extn.LOAD_ENTITY_ATTRIBUTES',
	         1);
  
    -- Initializing index value for pl/sql table. Ensure that the index
    -- value is incremented after setting each dependency record.
    l_index := 1;
  
    -- Dependencies for Order Header Entity
    IF p_entity_code = oe_globals.g_entity_header THEN
    
      NULL;
      -- CHG0040763
      x_extn_dep_tbl(l_index).source_attribute := oe_header_util.g_invoice_to_org;
      x_extn_dep_tbl(l_index).dependent_attribute := oe_header_util.g_invoice_to_contact;
      x_extn_dep_tbl(l_index).enabled_flag := 'N';
      l_index := l_index + 1;
    
      --end CHG0040763
      -- Sample Code for Disabling dependency of Invoice To on Ship To
      -- x_extn_dep_tbl(l_index).source_attribute := OE_HEADER_UTIL.G_SHIP_TO_ORG;
      -- x_extn_dep_tbl(l_index).dependent_attribute := OE_HEADER_UTIL.G_INVOICE_TO_ORG;
      -- x_extn_dep_tbl(l_index).enabled_flag := 'N';
      -- l_index := l_index + 1;
      /* CHG0037039 - Diptasurjya */
      x_extn_dep_tbl(l_index).source_attribute := oe_header_util.g_order_type;
      x_extn_dep_tbl(l_index).dependent_attribute := oe_header_util.g_salesrep;
      x_extn_dep_tbl(l_index).enabled_flag := 'Y';
      l_index := l_index + 1;
      /* CHG0037039 - Diptasurjya */
      -- Dependencies for Order Line Entity
    ELSIF p_entity_code = oe_globals.g_entity_line THEN
    
      x_extn_dep_tbl(l_index).source_attribute := oe_line_util.g_inventory_item;
      x_extn_dep_tbl(l_index).dependent_attribute := oe_line_util.g_shipping_method;
      x_extn_dep_tbl(l_index).enabled_flag := 'Y';
      l_index := l_index + 1;
    
      -- Added depency for Freight Term 11/23/2015 SAkula CHG0037039
      x_extn_dep_tbl(l_index).source_attribute := oe_line_util.g_inventory_item;
      x_extn_dep_tbl(l_index).dependent_attribute := oe_line_util.g_freight_terms;
      x_extn_dep_tbl(l_index).enabled_flag := 'Y';
      l_index := l_index + 1;
    
      -- Added for CHG0040568  --Rimpi
      x_extn_dep_tbl(l_index).source_attribute := oe_line_util.g_inventory_item;
      x_extn_dep_tbl(l_index).dependent_attribute := oe_line_util.g_intermed_ship_to_org;
      x_extn_dep_tbl(l_index).enabled_flag := 'Y';
      l_index := l_index + 1;
    
      -- CHG0041582
      x_extn_dep_tbl(l_index).source_attribute := oe_line_util.g_inventory_item;
      x_extn_dep_tbl(l_index).dependent_attribute := oe_line_util.g_line_type;
      x_extn_dep_tbl(l_index).enabled_flag := 'Y';
      l_index := l_index + 1;
    
    END IF;
  
    oe_debug_pub.add('Exit OE_Dependencies_Extn.LOAD_ENTITY_ATTRIBUTES', 1);
  
  EXCEPTION
    WHEN OTHERS THEN
      IF oe_msg_pub.check_msg_level(oe_msg_pub.g_msg_lvl_unexp_error) THEN
        oe_msg_pub.add_exc_msg(g_pkg_name, 'Load_Entity_Attributes');
      END IF;
      RAISE fnd_api.g_exc_unexpected_error;
  END load_entity_attributes;

END oe_dependencies_extn;
/
