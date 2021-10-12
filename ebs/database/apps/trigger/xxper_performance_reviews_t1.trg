CREATE OR REPLACE TRIGGER xxper_performance_reviews_t1
  INSTEAD OF INSERT ON XXPER_PERFORMANCE_REVIEWS_v
  FOR EACH ROW
DECLARE

BEGIN
  --------------------------------------------------------------------
  --  name:            XXPER_PERFORMANCE_REVIEWS_t1
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   XX/XX/201X 
  --------------------------------------------------------------------
  --  purpose :        HR encrypt
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/201X  Yuval Tal         initial build
  --  1.1  08/05/2013  Dalit A. Raviv    due to the upgrade to 12.1.3 
  --                                     when user did not use the security token to open the encrypt data
  --                                     it will return -1, in this caes need to do nothing.
  --------------------------------------------------------------------  
  if :NEW.performance_rating <> -1 then 
    INSERT INTO hr.per_performance_reviews
    (performance_review_id,
     person_id,
     event_id,
     review_date,
     performance_rating,
     next_perf_review_date,
     attribute_category,
     attribute1,
     attribute2,
     attribute3,
     attribute4,
     attribute5,
     attribute6,
     attribute7,
     attribute8,
     attribute9,
     attribute10,
     attribute11,
     attribute12,
     attribute13,
     attribute14,
     attribute15,
     attribute16,
     attribute17,
     attribute18,
     attribute19,
     attribute20,
     attribute21,
     attribute22,
     attribute23,
     attribute24,
     attribute25,
     attribute26,
     attribute27,
     attribute28,
     attribute29,
     attribute30,
     object_version_number,
     last_update_date,
     last_updated_by,
     last_update_login,
     created_by,
     creation_date)
  VALUES
    (:NEW.performance_review_id,
     :NEW.person_id,
     :NEW.event_id,
     :NEW.review_date,
     xxobjt_sec.encrypt(:NEW.performance_rating),
     :NEW.next_perf_review_date,
     :NEW.attribute_category,
     :NEW.attribute1,
     :NEW.attribute2,
     :NEW.attribute3,
     :NEW.attribute4,
     :NEW.attribute5,
     :NEW.attribute6,
     :NEW.attribute7,
     :NEW.attribute8,
     :NEW.attribute9,
     :NEW.attribute10,
     :NEW.attribute11,
     :NEW.attribute12,
     :NEW.attribute13,
     :NEW.attribute14,
     :NEW.attribute15,
     :NEW.attribute16,
     :NEW.attribute17,
     :NEW.attribute18,
     :NEW.attribute19,
     :NEW.attribute20,
     :NEW.attribute21,
     :NEW.attribute22,
     :NEW.attribute23,
     :NEW.attribute24,
     :NEW.attribute25,
     :NEW.attribute26,
     :NEW.attribute27,
     :NEW.attribute28,
     :NEW.attribute29,
     :NEW.attribute30,
     :NEW.object_version_number,
     :NEW.last_update_date,
     :NEW.last_updated_by,
     :NEW.last_update_login,
     :NEW.created_by,
     :NEW.creation_date);

  end if;
exception
  when others then
    null;
END;
/
