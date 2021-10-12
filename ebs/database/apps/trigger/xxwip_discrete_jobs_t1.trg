create or replace trigger XXWIP_DISCRETE_JOBS_T1
  after insert or    UPDATE OF attribute10,attribute11 ON WIP_DISCRETE_JOBS
  FOR EACH ROW
--------------------------------------------------------------------
--  name:            XXWIP_DISCRETE_JOBS_T1
--  create by:        yuval tal
--  Revision:        1.0
--  creation date:   18.3.14
--------------------------------------------------------------------
--  purpose :     
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  18.3.14     yuval tal        CHG0031557 Canceling OSP job  changes PO status from 'Approved' to  'Requires Reapproval'  
--                                    add condition (NVL(NEW.attribute10,'-1')!=NVL(OLD.attribute10,'-1') OR NVL(NEW.attribute11,'-1')!=NVL(OLD.attribute11,'-1' )))
--------------------------------------------------------------------
when (NEW.class_code='RFR' AND (NVL(NEW.attribute10,'-1')!=NVL(OLD.attribute10,'-1') OR NVL(NEW.attribute11,'-1')!=NVL(OLD.attribute11,'-1' )))
DECLARE
  --l_po_header_id NUMBER;
  CURSOR c IS
    SELECT DISTINCT pol.po_line_id
    
      FROM po_lines_all pol, po_distributions_all poda
     WHERE poda.po_line_id = pol.po_line_id
       AND poda.wip_entity_id = nvl(:new.wip_entity_id, :old.wip_entity_id);
  --  AND rownum = 1;
BEGIN

  /* SELECT pol.po_header_id
   INTO l_po_header_id
   FROM po_lines_all pol, po_distributions_all poda
  WHERE poda.po_line_id = pol.po_line_id
    AND poda.wip_entity_id = nvl(:NEW.wip_entity_id, :OLD.wip_entity_id)
    AND rownum = 1;*/

  FOR i IN c LOOP
  
    UPDATE po_lines_all
       SET attribute4 = :new.attribute10, attribute5 = :new.attribute11
     WHERE po_line_id = i.po_line_id;
  
  END LOOP;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
  
END xxwip_discrete_jobs_t1;
/
