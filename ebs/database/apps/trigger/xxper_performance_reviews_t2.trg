CREATE OR REPLACE TRIGGER xxper_performance_reviews_t2
  INSTEAD OF UPDATE ON XXPER_PERFORMANCE_REVIEWS_v
  FOR EACH ROW
DECLARE

BEGIN
  --------------------------------------------------------------------
  --  name:            XXPER_PERFORMANCE_REVIEWS_t2
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   XX/XX/201X 
  --------------------------------------------------------------------
  --  purpose :        HR encrypt
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/201X  Yuval Tal         initial build
  --  1.1  008/05/2013 Dalit A. Raviv    due to the upgrade to 12.1.3 
  --                                     when user did not use the security token to open the encrypt data
  --                                     it will return -1, in this caes need to do nothing.
  --------------------------------------------------------------------
  if :NEW.performance_rating <> -1 then
    UPDATE hr.per_performance_reviews t
     SET person_id             = :NEW.person_id,
         event_id              = :NEW.event_id,
         review_date           = :NEW.review_date,
         performance_rating    = xxobjt_sec.encrypt(:NEW.performance_rating),
         next_perf_review_date = :NEW.next_perf_review_date,
         attribute_category    = :NEW.attribute_category,
         attribute1            = :NEW.attribute1,
         attribute2            = :NEW.attribute2,
         attribute3            = :NEW.attribute3,
         attribute4            = :NEW.attribute4,
         attribute5            = :NEW.attribute5,
         attribute6            = :NEW.attribute6,
         attribute7            = :NEW.attribute7,
         attribute8            = :NEW.attribute8,
         attribute9            = :NEW.attribute9,
         attribute10           = :NEW.attribute10,
         attribute11           = :NEW.attribute11,
         attribute12           = :NEW.attribute12,
         attribute13           = :NEW.attribute13,
         attribute14           = :NEW.attribute14,
         attribute15           = :NEW.attribute15,
         attribute16           = :NEW.attribute16,
         attribute17           = :NEW.attribute17,
         attribute18           = :NEW.attribute18,
         attribute19           = :NEW.attribute19,
         attribute20           = :NEW.attribute20,
         attribute21           = :NEW.attribute21,
         attribute22           = :NEW.attribute22,
         attribute23           = :NEW.attribute23,
         attribute24           = :NEW.attribute24,
         attribute25           = :NEW.attribute25,
         attribute26           = :NEW.attribute26,
         attribute27           = :NEW.attribute27,
         attribute28           = :NEW.attribute28,
         attribute29           = :NEW.attribute29,
         attribute30           = :NEW.attribute30,
         object_version_number = :NEW.object_version_number,
         last_update_date      = :NEW.last_update_date,
         last_updated_by       = :NEW.last_updated_by,
         last_update_login     = :NEW.last_update_login,
         created_by            = :NEW.created_by,
         creation_date         = :NEW.creation_date

     WHERE performance_review_id = :OLD.performance_review_id;

   end if;
exception
  when others then
    null;

END;
/
