CREATE OR REPLACE PACKAGE BODY XXOE_DEFAULTING_RULE_PKG AS
-----------------------------------------------------------------------
--  customization code: 
--  name:               XXOE_DEFAULTING_RULE_PKG
--  create by:          Dalit A. Raviv
--  $Revision:          1.0 $
--  creation date:      07/06/2010
--  Purpose :           General Package for Defaulting Rule at OM .
-----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   07/06/2010    Dalit A. Raviv  initial build
----------------------------------------------------------------------- 

  --  Global constant holding the package name
  G_PKG_NAME                    CONSTANT VARCHAR2(30) := 'XXOE_DEFAULTING_RULE_PKG';

  -----------------------------------------------------------------------
  -- DEFAULTING FUNCTIONS TO BE USED FOR ATTRIBUTES ON ORDER HEADER
  -----------------------------------------------------------------------

  --

  -----------------------------------------------------------------------
  -- DEFAULTING FUNCTIONS FOR ATTRIBUTES ON ORDER LINE
  -----------------------------------------------------------------------
  -----------------------------------------------------------------------
  --  customization code: CUST329 - Default the Tax Class in DE SO lines for service orders
  --  name:               XXOE_DEFAULTING_RULE_PKG
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      07/06/2010
  --  Purpose :           General Package for Defaulting Rule at OM .
  --                      Om At Line level - Default Rule that check 
  --                      if OU is DE and oe_transction_type att8 = Y 
  --                      mean that this trx type relate to Service
  --
  --  In Params:          p_database_object_name
  --                      p_attribute_code
  --                      Both in params must be declare (instruction in user guid)
  --                      DO NOT ERASE even that they gets null.
  --
  --                      FOR DEBUG - need to change the value for
  --                      profile - FND_PROFILE.VALUE('ONT_DEBUG_LEVEL') 
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/06/2010    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  function Get_Tax_Classification_Code (p_database_object_name in  varchar2,
                                        p_attribute_code       in  varchar2) return varchar2 is
    --
    l_debug_level CONSTANT number := oe_debug_pub.g_debug_level;
    --
    l_att8        varchar2(150)   := null;
  begin

    -- Start   
    if l_debug_level  > 0 then
      oe_debug_pub.add('ENTERING XXOE_DEFAULTING_RULE_PKG.GET_TAX_CLASSIFICATION_CODE' , 1 ) ;
      oe_debug_pub.add('line id : '  ||ONT_LINE_DEF_HDLR.g_record.line_id);
      oe_debug_pub.add('Header id : '||ONT_LINE_DEF_HDLR.g_record.header_id);
    end if;
    
    --l_line_rec  := ONT_LINE_DEF_HDLR.g_record;
    --l_header_id := l_line_rec.header_id;
    begin
      select 'Y'
      into   l_att8
      from   oe_transaction_types_all otta,
             oe_order_headers_all     ooh
      where  otta.transaction_type_id = ooh.order_type_id
      and    ooh.header_id            = ONT_LINE_DEF_HDLR.g_record.header_id--l_line_rec.header_id
      and    nvl(otta.attribute8,'N') = 'Y';
    exception
      when others then
        l_att8 := 'N' ;
    end;
    
    if l_debug_level > 0 then
      oe_debug_pub.add('Is transaction_types - service? : '|| l_att8);
    end if;
    
    if l_att8 = 'Y' then
      return 'DE SERVICE';
    end if;
    
    if l_debug_level  > 0 then
      oe_debug_pub.add(  'EXITING XXOE_DEFAULTING_RULE_PKG.GET_TAX_CLASSIFICATION_CODE' , 1 ) ;
    end if;
    return null;
  exception
    when no_data_found then
      return null;
      dbms_output.put_line('p_database_object_name - '||p_database_object_name); 
      dbms_output.put_line('p_attribute_code - '||p_attribute_code);
    when others then
    	if oe_msg_pub.check_msg_level (oe_msg_pub.G_MSG_LVL_UNEXP_ERROR) then
    	  oe_msg_pub.add_exc_msg(G_PKG_NAME,'GET_TAX_CLASSIFICATION_CODE');
    	end if;

	    raise fnd_api.G_EXC_UNEXPECTED_ERROR;  
  end GET_TAX_CLASSIFICATION_CODE;

END XXOE_DEFAULTING_RULE_PKG;
/

