create or replace trigger xxqp_list_lines_bur_trg1
  before update on QP_LIST_LINES
  for each row

when ((NEW.last_updated_by <> 4290) and
       ((nvl(OLD.operand,-999) <> NEW.operand) or
        (nvl(OLD.end_date_active,sysdate - 1000) <> NEW.end_date_active) or
        (nvl(OLD.start_date_active ,sysdate - 1000) <> NEW.start_date_active )
       )
     )
DECLARE
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;
  l_is_relate VARCHAR2(10) := NULL;
BEGIN
  --------------------------------------------------------------------
  --  name:            XXQP_LIST_LINES_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   07/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire befor update price list line
  --                   when attribute1 (SF Price entry id) is not null
  --                   and operand or end active date changed.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/09/2010  Dalit A. Raviv    initial build
  --  1.1  19/01/2014  Dalit A. Raviv    CUST776 - Customer support SF-OA interfaces CR 1215
  --                                     last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------
  -- check header is relate to SF
  BEGIN
    SELECT 'Y'
      INTO l_is_relate
      FROM qp_list_headers_b
     WHERE list_header_id = :new.list_header_id
       AND attribute6 = 'Y'; -- IS NOT NULL;
  EXCEPTION
    WHEN OTHERS THEN
      l_is_relate := 'N';
  END;
  -- if relate enter row to interface
  IF l_is_relate = 'Y' THEN
  
    l_oa2sf_rec.source_id   := :new.list_line_id;
    l_oa2sf_rec.source_name := 'PRICE_ENTRY';
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code  => l_err_code, -- o v
                                                     p_err_msg   => l_err_desc); -- o v
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxqp_list_lines_bur_trg1;
/
