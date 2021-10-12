create or replace view xxar_pay_term_dtl_v as
Select
----------------------------------------------------------------------------------------------------------------
--  name:           XXAR_PAY_TERM_DTL_V
--  Description:    Payment Term  Strataforce Sync
--
----------------------------------------------------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   9.11.17       yuval tal       CHG0041763 - strataforce  project payment terms Interface initial build
--  1.1   22.06.18      Lingaraj        CHG0041763- CTASK0037212 -- Added 2 New fields JA and CN description
--  1.2   13.01.19      yuval tal       CHG0044881 -  add service_contract_terms
----------------------------------------------------------------------------------------------------------------
       te.term_id,
       tl.description,
        (select rtt.description
              from ra_terms_tl rtt
              where rtt.source_lang ='JA'
              and rtt.term_id = te.term_id
        )description_ja,
       (select rtt.description
              from ra_terms_tl rtt
              where rtt.source_lang  ='ZHS'
              and rtt.term_id = te.term_id
        )description_cn,
        null description_ko, --Korean Language
       tl.name ,
       te.start_date_active,
       te.end_date_active,
       te.attribute1,
       (CASE
            When    TRUNC(SYSDATE) >= te.start_date_active
                and TRUNC(SYSDATE) <= NVL(te.end_date_active ,TRUNC(SYSDATE))
            Then 'True'
            Else 'Flase'
        End) IsActive,
        dfv.visible_to_resellers,     
        decode (dfv.service_contract_terms,'Y','True','False') service_contract_terms -- CHG0044881
From
      ra_terms_b te ,
      ra_terms_tl tl,
      ra_terms_b_dfv dfv
Where tl.language='US'
and te.term_id = tl.term_id
and dfv.row_id=te.rowid
;
