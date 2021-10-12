create or replace package body XXCS_BI_SERVICE_PKG is
-- 5-10-2009 -- update upper to functions
-- 20-10-2009 -- Update function get_Curr_ledger_id
  -- Function and procedure implementations get_param_.....
  function get_param_date_value(P_bi_param_code in varchar2,
                                P_bi_param_sec  varchar2 DEFAULT null)
    return date is
    v_return date;
  begin
    select value_date
      into v_return
      from xxobjt_cs_param t
     where upper(t.bi_param_code) = upper(P_bi_param_code)
       and (upper(t.bi_param_sec) = upper(P_bi_param_sec) or
            P_bi_param_sec is null);
    return(v_return);
  EXCEPTION
    WHEN OTHERS THEN
      return(NULL);
  END get_param_date_value;

  function get_param_char_value(P_bi_param_code in varchar2,
                                P_bi_param_sec  in varchar2 DEFAULT null)
    return varchar2 is
    v_return varchar2(100);
  begin
    select value_char
      into v_return
      from xxobjt_cs_param t
     where upper(t.bi_param_code) = upper(P_bi_param_code)
       and (upper(t.bi_param_sec) = upper(P_bi_param_sec) or
            P_bi_param_sec is null);
    return(v_return);
  EXCEPTION
    WHEN OTHERS THEN
      return(NULL);
  END get_param_char_value;

  function get_param_number_value(P_bi_param_code in varchar2,
                                  P_bi_param_sec  varchar2 DEFAULT null)
    return number is
    v_return number;
  begin
    select value_number
      into v_return
      from xxobjt_cs_param t
     where upper(t.bi_param_code) = upper(P_bi_param_code)
       and (upper(t.bi_param_sec) = upper(P_bi_param_sec) or
            P_bi_param_sec is null);
    return(v_return);
  EXCEPTION
    WHEN OTHERS THEN
      return(NULL);
  END get_param_number_value;

  function get_Curr_ledger_id return number is
    v_ledger_id number;
  begin
    --Get the Primary ledger id
    select t.set_of_books_id
    into v_ledger_id
    from hr_operating_units t
    where t.organization_id = fnd_global.ORG_ID;
    return(v_ledger_id);
  EXCEPTION
    WHEN OTHERS THEN
      return(null);
  END get_Curr_ledger_id;

  function get_Curr_Currency_code return varchar2 is
    V_Currency_code varchar(15);
  begin
    select currency_code
      into V_Currency_code
      from gl_ledgers l
     where l.ledger_id = xxcs_bi_service_pkg.get_Curr_ledger_id;
    return(V_Currency_code);
  EXCEPTION
    WHEN OTHERS THEN
      return('USD');
  end get_Curr_Currency_code;
  -- objet function
  PROCEDURE query_quantities(p_inventory_item_id   NUMBER,
                             p_organization_id     NUMBER,
                             p_subinventory        VARCHAR2 DEFAULT NULL,
                             p_locator_id          NUMBER DEFAULT NULL,
                             p_is_revision_control NUMBER DEFAULT NULL,
                             p_is_lot_control      NUMBER DEFAULT NULL,
                             p_is_serial_control   NUMBER DEFAULT NULL,
                             p_revision            VARCHAR2 DEFAULT NULL,
                             p_lot_number          VARCHAR2 DEFAULT NULL,
                             p_tree_mode           INTEGER DEFAULT 1,
                             x_qoh                 OUT NUMBER,
                             x_rqoh                OUT NUMBER,
                             x_qr                  OUT NUMBER,
                             x_qs                  OUT NUMBER,
                             x_att                 OUT NUMBER,
                             x_atr                 OUT NUMBER) IS

    l_on_hand_qty   NUMBER := 0;
    l_avail_qty     NUMBER := 0;
    l_rqoh          NUMBER := 0;
    l_qr            NUMBER := 0;
    l_qs            NUMBER := 0;
    l_atr           NUMBER := 0;
    l_return_status VARCHAR2(1);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(200);

  BEGIN
    -- tree level constants
    --g_item_level           CONSTANT INTEGER := 1;
    --g_revision_level       CONSTANT INTEGER := 2;
    --g_lot_level            CONSTANT INTEGER := 3;
    --g_sub_level            CONSTANT INTEGER := 4;
    --g_locator_level        CONSTANT INTEGER := 5;
    --g_lpn_level            CONSTANT INTEGER := 6;
    --g_cost_group_level     CONSTANT INTEGER := 7;
    -----------------------------------------------
    -- synonyms used in this program
    --     qoh          quantity on hand
    --     rqoh         reservable quantity on hand
    --     qr           quantity reserved
    --     att          available to transact
    --     atr          available to reserve
    -- invConv changes begin
    --    sqoh          secondary quantity on hand
    --    srqoh         secondary reservable quantity on hand
    --    sqr           secondary quantity reserved
    --    satt          secondary available to transact
    --    satr          secondary available to reserve
    -- invConv changes end

    --   SELECT FROM mtl_system_items_b msi

    --revision

    --lot

    --

    inv_quantity_tree_pub.clear_quantity_cache;
    inv_quantity_tree_pub.query_quantities(p_api_version_number  => 1.0,
                                           x_return_status       => l_return_status,
                                           x_msg_count           => l_msg_count,
                                           x_msg_data            => l_msg_data,
                                           p_organization_id     => p_organization_id,
                                           p_inventory_item_id   => p_inventory_item_id,
                                           p_tree_mode           => p_tree_mode,
                                           p_is_revision_control => NULL,
                                           p_is_lot_control      => NULL,
                                           p_is_serial_control   => NULL,
                                           p_revision            => NULL,
                                           p_lot_number          => NULL,
                                           p_subinventory_code   => p_subinventory,
                                           p_locator_id          => p_locator_id,
                                           x_qoh                 => l_on_hand_qty,
                                           x_rqoh                => l_rqoh,
                                           x_qr                  => l_qr,
                                           x_qs                  => l_qs,
                                           x_att                 => l_avail_qty,
                                           x_atr                 => l_atr);

    x_qoh  := l_on_hand_qty;
    x_rqoh := l_rqoh;
    x_qr   := l_qr;
    x_qs   := l_qs;
    x_att  := l_avail_qty;
    x_atr  := l_atr;

  END query_quantities;

  FUNCTION get_lookup_meaning(p_lookup_type         VARCHAR2,
                              p_lookup_code         VARCHAR2,
                              p_view_application_id number DEFAULT Null)
    RETURN VARCHAR2 IS
    l_meaning fnd_lookup_values.meaning%TYPE;
  BEGIN

    SELECT meaning
      INTO l_meaning
      FROM fnd_lookup_values flv
     WHERE flv.lookup_type = p_lookup_type
       AND flv.lookup_code = p_lookup_code
       AND flv.LANGUAGE = userenv('LANG')
       and (flv.view_application_id = p_view_application_id
        or p_view_application_id is null);

    RETURN l_meaning;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_lookup_meaning;

  FUNCTION get_avail_to_reserve(p_inventory_item_id NUMBER,
                                p_organization_id   NUMBER) RETURN NUMBER IS

    l_on_hand_qty NUMBER := 0;
    l_avail_qty   NUMBER := 0;
    l_rqoh        NUMBER := 0;
    l_qr          NUMBER := 0;
    l_qs          NUMBER := 0;
    l_atr         NUMBER := 0;

  BEGIN

    query_quantities(p_inventory_item_id => p_inventory_item_id,
                     p_organization_id   => p_organization_id,
                     p_tree_mode         => 1,
                     x_qoh               => l_on_hand_qty,
                     x_rqoh              => l_rqoh,
                     x_qr                => l_qr,
                     x_qs                => l_qs,
                     x_att               => l_avail_qty,
                     x_atr               => l_atr);

    RETURN l_atr;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_avail_to_reserve;

  FUNCTION get_conversion_rate(p_from_currency VARCHAR2,
                               p_to_currency VARCHAR2,
                               p_conv_date DATE,
                               p_conv_type VARCHAR2 default 'Corporate') RETURN NUMBER IS

    v_conv_rate NUMBER;

  BEGIN
    if p_from_currency = p_to_currency then
     return 1;
    end if;

    select gdr.conversion_rate
    into v_conv_rate
    from gl_daily_rates gdr
    where gdr.from_currency = p_from_currency
    and gdr.to_currency = p_to_currency
    and gdr.conversion_date = p_conv_date
    and gdr.conversion_type = p_conv_type;

    RETURN v_conv_rate;

  EXCEPTION
    WHEN OTHERS THEN
     begin
      select gdr.conversion_rate
      into v_conv_rate
      from gl_daily_rates gdr
      where gdr.from_currency = p_from_currency
      and gdr.to_currency = p_to_currency
      and gdr.conversion_date = (select max(g.conversion_date)
                                 from gl_daily_rates g
                                 where g.from_currency = p_from_currency
                                 and g.to_currency = p_to_currency
                                 and g.conversion_type = p_conv_type)
      and gdr.conversion_type = p_conv_type;
      RETURN v_conv_rate;
     exception
      when others then
       return null;
     end;
  END get_conversion_rate;

  FUNCTION get_primary_currency(P_ORG_ID number) RETURN VARCHAR2 IS

    v_primary_cur varchar2(15);

  BEGIN

    select gl.currency_code
    into v_primary_cur
    from gl_ledgers gl, hr_operating_units hou
    where gl.ledger_id = hou.set_of_books_id
    and hou.organization_id = P_ORG_ID;

    RETURN v_primary_cur;

  EXCEPTION
    WHEN OTHERS THEN
       return null;

  END get_primary_currency;

begin
  -- Initialization
  null; -- <Statement>;
end XXCS_BI_SERVICE_PKG;
/

