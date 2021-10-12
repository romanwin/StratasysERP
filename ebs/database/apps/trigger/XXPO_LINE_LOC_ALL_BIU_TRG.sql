create or replace trigger XXPO_LINE_LOC_ALL_BIU_TRG
before insert or  UPDATE of attribute8 ON "PO"."PO_LINE_LOCATIONS_ALL"
  FOR EACH ROW
   
DECLARE

  --------------------------------------------------------------------
  --  name:              XXPO_LINE_LOC_ALL_BIU_TRG
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     8.6.17
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date         name           desc
  --  1.0  23-Apr-2017  yuval tal     CHG0040670 Tracking Hold Acceptences : insert data into audit table 

  --------------------------------------------------------------------
BEGIN

  IF inserting OR (updating AND ((nvl(:new.attribute8, '-1') !=
     nvl(:old.attribute8, '-1')))) THEN
  
    INSERT INTO xxssys_table_audit
      (table_name,
       table_key,
       column_name,
       old_value,
       new_value,
       creation_date,
       created_by)
    VALUES
      ('PO_LINE_LOCATIONS_ALL',
       nvl(:new.line_location_id, :old.line_location_id),
       'ATTRIBUTE8',
       :old.attribute8,
       :new.attribute8,
       SYSDATE,
       fnd_global.user_id);
  
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
/
