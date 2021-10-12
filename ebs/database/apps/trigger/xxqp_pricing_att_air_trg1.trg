create or replace trigger XXQP_PRICING_ATT_AIR_TRG1
  after insert on QP_PRICING_ATTRIBUTES 
  for each row
DECLARE

  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;

  l_header_realte_to_sf VARCHAR2(1) := 'N';

BEGIN
  --------------------------------------------------------------------
  --  name:            XXQP_LIST_LINES_AIR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   07/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each insert of new price list line
  --                   will check: 
  --                   1) line relate to price list header that have valu at att5 (SF Price Book ID)
  --                      if yes check that item from line relate to catalog that relate to SF
  --                   2) is source id exist at interface tbl XXOBJT_OA2SF_INTERFACE
  --                      if not insert row to interface tbl XXOBJT_OA2SF_INTERFACE
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/10/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  -- check price list header have value at att6 ='Y' (SF Price Book ID)

  l_header_realte_to_sf := xxobjt_oa2sf_interface_pkg.get_price_list_header_is_sf(:new.list_line_id);
  IF l_header_realte_to_sf = 'Y' THEN
  
    l_oa2sf_rec.status      := 'NEW';
    l_oa2sf_rec.source_id   := :new.list_line_id;
    l_oa2sf_rec.source_name := 'PRICE_ENTRY';
    l_oa2sf_rec.sf_id       := NULL;
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code  => l_err_code, -- o v
                                                     p_err_msg   => l_err_desc); -- o v
  
  END IF; -- l_header_realte_to_sf
  --EXCEPTION
  -- WHEN OTHERS THEN
  --   NULL;
END xxqp_pricing_att_air_trg1;
/
