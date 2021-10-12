create or replace trigger xxqp_list_headers_bur_trg1
  before update on QP_LIST_HEADERS_B  
  for each row 
 
when (((NEW.list_type_code = 'PRL')  and (NEW.last_updated_by <> 4290) and (NEW.attribute5 is not null)) and 
      ((NEW.active_flag <> OLD.active_flag) or
       (NEW.global_flag <> OLD.global_flag) or
       (nvl(NEW.attribute6,'DAR')  <> nvl(OLD.attribute6,'DAR') )  or
       (nvl(NEW.attribute10,'DAR') <> nvl(OLD.attribute10,'DAR')) or -- gam_price_list_flag
       (nvl(NEW.attribute12,'DAR') <> nvl(OLD.attribute12,'DAR')) or -- contract_type
       (NEW.currency_code <> OLD.currency_code)))
DECLARE
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;

  CURSOR pop_c(p_list_header_id IN NUMBER) IS
    SELECT list_line_id source_id, 'PRICE_ENTRY' source_name
      FROM qp_list_lines
     WHERE list_header_id = p_list_header_id;
BEGIN
  --------------------------------------------------------------------
  --  name:            XXQP_LIST_HEADERS_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1 
  --  creation date:   10/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire after update of price list header
  --                   when attribute6 (Transfer to SF) = 'Y'
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/09/2010  Dalit A. Raviv    initial build
  --  1.1  19/01/2014  Dalit A. Raviv    change logic according to CUST776 - Customer support SF-OA interfaces CR 1215
  --                                     last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------  
  -- 1) enter row for the header
  l_oa2sf_rec.source_id   := :new.list_header_id;
  l_oa2sf_rec.source_name := 'PRICE_BOOK';
  xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                   p_err_code  => l_err_code, -- o v
                                                   p_err_msg   => l_err_desc); -- o v

  -- 2) for all lines relate to this header enter rows too.
  FOR pop_r IN pop_c(:new.list_header_id) LOOP
    l_oa2sf_rec.source_id   := pop_r.source_id;
    l_oa2sf_rec.source_name := pop_r.source_name;
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code  => l_err_code, -- o v
                                                     p_err_msg   => l_err_desc); -- o v
  END LOOP;

END xxqp_list_headers_aur_trg1;
/
