create or replace trigger XXMTL_CROSS_REFERENCE_AIR_TRG1 
  after insert on MTL_CROSS_REFERENCES_B
  for each row
  
 
when ( NEW.cross_reference_type = 'SF' and NEW.cross_reference = 'Y' and new.created_by!=4290)
DECLARE
  -- l_source_id_exist VARCHAR2(5) := 'N';
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;
BEGIN
  --------------------------------------------------------------------
  --  name:            XXMTL_CROSS_REFERENCE_AIR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   18/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each insert of item cross reference
  --                   when cross_reference_type = 'SF' and cross_reference = 'Y'
  --                   1) check if source exist in interface table XXOBJT_OA2SF_INTERFACE
  --                   2) if no enter new row to interface 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/10/2010  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 

  l_oa2sf_rec.status      := 'NEW';
  l_oa2sf_rec.source_id   := :new.inventory_item_id;
  l_oa2sf_rec.source_name := 'PRODUCT';
  l_oa2sf_rec.sf_id       := NULL;
  xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                   p_err_code => l_err_code, -- o v
                                                   p_err_msg => l_err_desc); -- o v

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxmtl_cross_reference_air_trg1;
/
