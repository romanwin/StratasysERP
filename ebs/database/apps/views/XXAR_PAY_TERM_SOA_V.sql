CREATE OR REPLACE VIEW XXAR_PAY_TERM_SOA_V AS
SELECT
----------------------------------------------------------------------------------------------------------------
--  name:            XXAR_PAY_TERM_SOA_V
--  Description:     Payment Term SOA View
--                   This View be get Called by SOA , to fetch the Payment Term Records in NEW Status
----------------------------------------------------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   9.11.17       yuval tal       CHG0041763 - strataforce  project payment terms Interface initial build
--  1.1   22.06.18      Lingaraj        CHG0041763- CTASK0037212 -- Added 2 New fields JA and CN description
--  1.2   13.01.19      yuval tal       CHG0044881 -  add service_contract_terms
----------------------------------------------------------------------------------------------------------------
           event_id,
           status,
           term_id,
           description,
           name ,
           attribute1,
           isactive,
           visible_to_resellers,
           description_ja Payment_Term_Japanese__c,
           description_cn Payment_Term_Chinese__c,
           description_ko Payment_Term_Korean__c,
            service_contract_terms -- CHG0044881
from
(Select ROW_NUMBER() OVER (PARTITION BY term_id ORDER BY event_id ) term_sequence,
           event_id,
           status,
           term_id,
           description,
           name ,
           attribute1,
           isactive,
           decode (visible_to_resellers,'Y','True','False') visible_to_resellers,
           description_ja,
           description_cn,
           description_ko,
           service_contract_terms -- CHG0044881
From (
    Select
           e.event_id,
           e.status,
           d.term_id,
           d.description,
           d.name ,
           d.attribute1,
           d.isactive,
           d.visible_to_resellers,
           d.description_ja,
           d.description_cn,
           d.description_ko,
           d.service_contract_terms --CHG0044881
    from
         xxssys_events e,
         XXAR_PAY_TERM_DTL_V d
    where e.entity_name  = 'PAY_TERM'
      and e.entity_id    =  d.term_id
      and e.status       = 'NEW'
      and TARGET_name    = 'STRATAFORCE'
      and Trunc(Sysdate) >= to_date(e.attribute1) -- attribute1 holds Effective Start Date
   UNION ALL
   Select
           e.event_id,
           e.status,
           d.term_id,
           d.description,
           d.name ,
           d.attribute1,
           d.isactive,
           d.visible_to_resellers,
           d.description_ja,
           d.description_cn,
           d.description_ko,
           d.service_contract_terms
    from
         xxssys_events e,
         xxar_pay_term_dtl_v d
    where e.entity_name   = 'PAY_TERM'
      and e.entity_id     = d.term_id
      and e.status        = 'NEW'
      and TARGET_name     = 'STRATAFORCE'
      and Trunc(Sysdate)  > to_date(e.attribute2) -- attribute2 holds Effective End Date
   ))
Where term_sequence = 1
;
