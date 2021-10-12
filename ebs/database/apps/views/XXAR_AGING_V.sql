/*
  Program          :  Create view of AR Open Invoice Aging
  Filename         :  XXAR_AGING_V.SQL

  Purpose          :  Display information about OPEN AR Invoices to be use for 
                   :  OBIEE reporting.   
                    
  Change History   :
  ............................................................
 --  ver  date               name                             desc
 --  1.0  11/04/2014    John Hendrickson           CHG0031451 initial build

  ............................................................
*/
create or replace view XXBI.xxar_aging_v
as
SELECT trx.transaction_type_name
,      trx.party_id
,      trx.customer_name
,      trx.customer_number
,      trx.bill_to_party_id
,      trx.bill_to_customer_name
,      trx.bill_to_customer_number
,      trx.bill_to_location_id
,      trx.bill_to_site_use_id
,      trx.bill_to_country_code2
,      trx.ship_to_party_id
,      trx.ship_to_customer_name
,      trx.ship_to_customer_number
,      trx.ship_to_location_id
,      trx.ship_to_site_use_id
,      trx.ship_to_country_code
,      trx.ship_to_country_code2
,      trx.ar_payment_schedule_id
,      trx.invoice_id
,      trx.invoice_number
,      trx.due_date
,      trx.currency_code
,      trx.exchange_rate
,      (trunc(dates.as_of_date) - trunc(trx.due_date))                     days_old
,      CASE WHEN trx.due_date >= dates.as_of_date
            THEN trx.remaining_balance
            ELSE 0
       END                                                   bucket_current
,      CASE WHEN dates.as_of_date - trx.due_date >= 1
             AND dates.as_of_date - trx.due_date <= 30
            THEN trx.remaining_balance
            ELSE 0
       END                                                   bucket_1_to_30_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 31
             AND dates.as_of_date - trx.due_date <= 60
            THEN trx.remaining_balance
            ELSE 0
       END                                                   bucket_31_to_60_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 61
             AND dates.as_of_date - trx.due_date <= 90
            THEN trx.remaining_balance
            ELSE 0
       END                                                   bucket_61_to_90_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 91
             AND dates.as_of_date - trx.due_date <= 120
            THEN trx.remaining_balance
            ELSE 0
       END                                                   bucket_91_to_120_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 121
             AND dates.as_of_date - trx.due_date <= 180
            THEN trx.remaining_balance
            ELSE 0
       END                                                   bucket_121_to_180_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 181
             AND dates.as_of_date - trx.due_date <= 270
            THEN trx.remaining_balance
            ELSE 0
       END                                                   bucket_181_to_270_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 271
             AND dates.as_of_date - trx.due_date <= 360
            THEN trx.remaining_balance
            ELSE 0
       END                                                   bucket_271_to_360_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 361
            THEN trx.remaining_balance
            ELSE 0
       END                                                   bucket_361_plus_days
,      SUM(trx.remaining_balance)
       OVER (PARTITION BY trx.party_id
             ,            trx.invoice_id
             ,            trx.invoice_number
             ,            trx.due_date
             ,            dates.as_of_date
             ,            trx.amount_due_original
             ,            trx.amount_due_remaining
             )                                               bucket_remaining
,      trx.salesrep_name
,      trx.collector_name
,      trx.org_id
,      trx.gl_date
,      trx.operating_unit_name
,      trx.original_transaction_amount
,      trx.purchase_order
,      trx.ct_reference                                      REFERENCE
,      dates.as_of_date
,      trx.amount_due_original
,      trx.amount_due_remaining
,      CASE WHEN trx.due_date >= dates.as_of_date
            THEN trx.amount_due_remaining
            ELSE 0
       END                                                   trx_bucket_current
,      CASE WHEN dates.as_of_date - trx.due_date >= 1
             AND dates.as_of_date - trx.due_date <= 30
            THEN trx.amount_due_remaining
            ELSE 0
       END                                                   trx_bucket_1_to_30_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 31
             AND dates.as_of_date - trx.due_date <= 60
            THEN trx.amount_due_remaining
            ELSE 0
       END                                                   trx_bucket_31_to_60_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 61
             AND dates.as_of_date - trx.due_date <= 90
            THEN trx.amount_due_remaining
            ELSE 0
       END                                                   trx_bucket_61_to_90_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 91
             AND dates.as_of_date - trx.due_date <= 120
            THEN trx.amount_due_remaining
            ELSE 0
       END                                                   trx_bucket_91_to_120_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 121
             AND dates.as_of_date - trx.due_date <= 180
            THEN trx.amount_due_remaining
            ELSE 0
       END                                                   trx_bucket_121_to_180_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 181
             AND dates.as_of_date - trx.due_date <= 270
            THEN trx.amount_due_remaining
            ELSE 0
       END                                                   trx_bucket_181_to_270_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 271
             AND dates.as_of_date - trx.due_date <= 360
            THEN trx.amount_due_remaining
            ELSE 0
       END                                                   trx_bucket_271_to_360_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 361
            THEN trx.amount_due_remaining
            ELSE 0
       END                                                   trx_bucket_361_plus_days
,      trx.usd_amount_due_original
,      trx.usd_amount_due_remaining
--Amounts converted to Functional Currency of the Operating unit
,      trx.func_amount_due_original
,      trx.func_amount_due_remaining
,      CASE WHEN trx.due_date >= dates.as_of_date
            THEN trx.func_amount_due_remaining
            ELSE 0
       END                                                   func_bucket_current
,      CASE WHEN dates.as_of_date - trx.due_date >= 1
             AND dates.as_of_date - trx.due_date <= 30
            THEN trx.func_amount_due_remaining
            ELSE 0
       END                                                   func_bucket_1_to_30_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 31
             AND dates.as_of_date - trx.due_date <= 60
            THEN trx.func_amount_due_remaining
            ELSE 0
       END                                                   func_bucket_31_to_60_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 61
             AND dates.as_of_date - trx.due_date <= 90
            THEN trx.func_amount_due_remaining
            ELSE 0
       END                                                   func_bucket_61_to_90_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 91
             AND dates.as_of_date - trx.due_date <= 120
            THEN trx.func_amount_due_remaining
            ELSE 0
       END                                                   func_bucket_91_to_120_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 121
             AND dates.as_of_date - trx.due_date <= 180
            THEN trx.func_amount_due_remaining
            ELSE 0
       END                                                   func_bucket_121_to_180_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 181
             AND dates.as_of_date - trx.due_date <= 270
            THEN trx.func_amount_due_remaining
            ELSE 0
       END                                                   func_bucket_181_to_270_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 271
             AND dates.as_of_date - trx.due_date <= 360
            THEN trx.func_amount_due_remaining
            ELSE 0
       END                                                   func_bucket_271_to_360_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 361
            THEN trx.func_amount_due_remaining
            ELSE 0
       END                                                   func_bucket_361_plus_days
--USD Converted amounts
,      CASE WHEN trx.due_date >= dates.as_of_date
            THEN trx.usd_amount_due_remaining
            ELSE 0
       END                                                   usd_bucket_current
,      CASE WHEN dates.as_of_date - trx.due_date >= 1
             AND dates.as_of_date - trx.due_date <= 30
            THEN trx.usd_amount_due_remaining
            ELSE 0
       END                                                   usd_bucket_1_to_30_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 31
             AND dates.as_of_date - trx.due_date <= 60
            THEN trx.usd_amount_due_remaining
            ELSE 0
       END                                                   usd_bucket_31_to_60_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 61
             AND dates.as_of_date - trx.due_date <= 90
            THEN trx.usd_amount_due_remaining
            ELSE 0
       END                                                   usd_bucket_61_to_90_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 91
             AND dates.as_of_date - trx.due_date <= 120
            THEN trx.usd_amount_due_remaining
            ELSE 0
       END                                                   usd_bucket_91_to_120_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 121
             AND dates.as_of_date - trx.due_date <= 180
            THEN trx.usd_amount_due_remaining
            ELSE 0
       END                                                   usd_bucket_121_to_180_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 181
             AND dates.as_of_date - trx.due_date <= 270
            THEN trx.usd_amount_due_remaining
            ELSE 0
       END                                                   usd_bucket_181_to_270_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 271
             AND dates.as_of_date - trx.due_date <= 360
            THEN trx.usd_amount_due_remaining
            ELSE 0
       END                                                   usd_bucket_271_to_360_days
,      CASE WHEN dates.as_of_date - trx.due_date >= 361
            THEN trx.usd_amount_due_remaining
            ELSE 0
       END                                                   usd_bucket_361_plus_days
,      trx.trx_date                                          trx_date
,      trx.payment_term                                      payment_term
FROM
/* trx... */
       (SELECT DECODE(apsa.CLASS
              ,      'PMT', 'Receipt'
              ,      'DEP', 'Deposit'
              ,      rctta.NAME)                                    transaction_type_name
       ,      hp.party_id                                           party_id
       ,      hp.party_name                                         customer_name
       ,      hca.account_number                                    customer_number
       ,      bill_to_hp.party_id                                   bill_to_party_id
       ,      bill_to_hp.party_name                                 bill_to_customer_name
       ,      bill_to_hca.account_number                            bill_to_customer_number
       ,      bill_to_hps.location_id                               bill_to_location_id
       ,      bill_to_hcsua.site_use_id                             bill_to_site_use_id
       ,      bill_to_loc.country
              || DECODE(bill_to_loc.country
                 ,      'US', bill_to_loc.state)                    bill_to_country_code2
       ,      ship_to_hp.party_id                                   ship_to_party_id
       ,      ship_to_hp.party_name                                 ship_to_customer_name
       ,      ship_to_hca.account_number                            ship_to_customer_number
       ,      ship_to_hps.location_id                               ship_to_location_id
       ,      ship_to_hcsua.site_use_id                             ship_to_site_use_id
       ,      ship_to_loc.country                                   ship_to_country_code
       ,      ship_to_loc.country
              || DECODE(ship_to_loc.country
                 ,      'US', ship_to_loc.state)                    ship_to_country_code2
       ,      apsa.payment_schedule_id                              ar_payment_schedule_id
       ,      apsa.customer_trx_id                                  invoice_id
       ,      apsa.trx_number                                       invoice_number
       ,      apsa.due_date                                         due_date
       ,      apsa.invoice_currency_code                            currency_code
       ,      apsa.exchange_rate                                    exchange_rate
       ,      apsa.amount_due_remaining
              *
              NVL(apsa.exchange_rate
              ,   1)                                                remaining_balance
       ,      rsa.NAME                                              salesrep_name
       ,      rcta.attribute10                                      crm
       ,      ac.NAME                                               collector_name
       ,      apsa.payment_schedule_id                              payment_schedule_id
       ,      apsa.org_id                                           org_id
       ,      apsa.gl_date                                          gl_date
      
       ,      haou_op.NAME                                          operating_unit_name
       ,      apsa.amount_due_original
              *
              NVL(apsa.exchange_rate
              ,   1)                                                original_transaction_amount
       ,      rcta.purchase_order                                   purchase_order
       ,      apsa.amount_due_original                              amount_due_original
       ,      apsa.amount_due_remaining                             amount_due_remaining
        ,      apsa.amount_due_original
              *
              NVL(apsa.exchange_rate,1)                             func_amount_due_original
       ,      apsa.amount_due_remaining
              *
              NVL(apsa.exchange_rate,1)                             func_amount_due_remaining
       ,      apsa.amount_due_original
              *
              NVL(gltr.conversion_rate,1)                           usd_amount_due_original
       ,      apsa.amount_due_remaining
              *
              NVL(gltr.conversion_rate,1)                           usd_amount_due_remaining
       ,      rcta.ct_reference                                     ct_reference
       ,      apsa.trx_date                                         trx_date
       ,      rat.name                                              payment_term
       FROM   ar_payment_schedules_all                apsa
       ,      ra_cust_trx_types_all                   rctta
       ,      hz_cust_accounts                        hca
       ,      hz_parties                              hp
       ,      hz_parties                              bill_to_hp
       ,      hz_parties                              ship_to_hp
       ,      hz_cust_accounts                        bill_to_hca
       ,      hz_cust_accounts                        ship_to_hca
       ,      hz_cust_site_uses_all                   bill_to_hcsua
       ,      hz_cust_site_uses_all                   ship_to_hcsua
       ,      hz_cust_acct_sites_all                  bill_to_hcasa
       ,      hz_cust_acct_sites_all                  ship_to_hcasa
       ,      hz_party_sites                          bill_to_hps
       ,      hz_party_sites                          ship_to_hps
       ,      hz_locations                            bill_to_loc
       ,      hz_locations                            ship_to_loc
       ,      hz_customer_profiles                    hcp
       ,      ar_collectors                           ac
       ,      ra_customer_trx_all                     rcta
       ,      ra_terms                                rat
       ,      ra_salesreps_all                        rsa
       ,      hr_all_organization_units               haou_op
       /* gltr...*/
       , (SELECT current_and_past_rates.from_currency functional_currency
           ,     current_and_past_rates.conversion_rate conversion_rate
           FROM  (SELECT gdrv.from_currency
                 ,       gdrv.to_currency
                 ,       gdrv.conversion_rate
                 ,       ROW_NUMBER()
                         OVER (PARTITION BY gdrv.from_currency
                               ORDER BY     gdrv.conversion_date DESC) r
                    FROM gl_daily_rates_v gdrv
                   WHERE gdrv.user_conversion_type = 'Corporate'     
                     AND gdrv.from_currency <> 'USD'
                     AND gdrv.to_currency    = 'USD'
                     AND gdrv.conversion_date <= TRUNC(SYSDATE)
                 ) current_and_past_rates
          WHERE current_and_past_rates.r = 1
          UNION ALL
          SELECT gdr.from_currency        functional_currency
          ,      gdr.conversion_rate
          FROM   gl_daily_rates  gdr
          WHERE  gdr.from_currency NOT IN (SELECT gdrv2.from_currency
                                           FROM   gl_daily_rates_v gdrv2
                                           WHERE  gdrv2.conversion_date <= TRUNC(SYSDATE)
                                             AND  gdrv2.user_conversion_type = 'Corporate')
          AND    gdr.to_currency     = 'USD'
          AND    gdr.conversion_type = 'Corporate'
          -- Get the daily rate on the last day of the currently open GL period
          AND    gdr.conversion_date = (SELECT MAX(gps.end_date)
                                        FROM   gl_period_statuses gps
                                        WHERE  gps.set_of_books_id = 1
                                        AND    gps.application_id = 101
                                        AND    gps.closing_status = 'O' -- Open
                                        )
          ) gltr
       /*... gltr*/
       WHERE  apsa.status                     <> 'CL'
       AND    NVL(apsa.receipt_confirmed_flag
              ,   'Y')                         = 'Y'
       AND    apsa.cust_trx_type_id            = rctta.cust_trx_type_id (+)
       AND    apsa.org_id                      = rctta.org_id (+)
       AND    (
                 (rctta.NAME <> 'Projects Invoice')
                  OR
                 (rctta.NAME IS NULL)
              )
       AND    apsa.customer_trx_id             = rcta.customer_trx_id (+)
       AND    (
                 (apsa.customer_site_use_id = hcp.site_use_id)
                  OR
                 (hcp.site_use_id IS NULL
                  AND
                  NOT EXISTS (SELECT NULL
                              FROM   hz_customer_profiles hcp1
                              WHERE  hcp1.cust_account_id = apsa.customer_id
                              AND    hcp1.site_use_id = apsa.customer_site_use_id)
                 )
              )
       AND    hcp.cust_account_id              = hca.cust_account_id
       AND    apsa.customer_id                 = hca.cust_account_id
       AND    hca.party_id                     = hp.party_id
       AND    rcta.bill_to_site_use_id         = bill_to_hcsua.site_use_id (+)
       AND    bill_to_hcsua.cust_acct_site_id  = bill_to_hcasa.cust_acct_site_id (+)
       AND    bill_to_hcasa.party_site_id      = bill_to_hps.party_site_id (+)
       AND    bill_to_hps.location_id          = bill_to_loc.location_id (+)
       AND    rcta.ship_to_site_use_id         = ship_to_hcsua.site_use_id (+)
       AND    ship_to_hcsua.cust_acct_site_id  = ship_to_hcasa.cust_acct_site_id (+)
       AND    ship_to_hcasa.party_site_id      = ship_to_hps.party_site_id (+)
       AND    ship_to_hps.location_id          = ship_to_loc.location_id (+)
       AND    hcp.collector_id                 = ac.collector_id (+)
       AND    rcta.primary_salesrep_id         = rsa.salesrep_id (+)
       AND    apsa.org_id                      = rcta.org_id (+)
       AND    rcta.org_id                      = rsa.org_id (+)
       AND    apsa.term_id                     = rat.term_id (+)
       AND    apsa.org_id                      = haou_op.organization_id
       AND    rcta.bill_to_customer_id         = bill_to_hca.cust_account_id (+)
       AND    bill_to_hca.party_id             = bill_to_hp.party_id (+)
       AND    rcta.ship_to_customer_id         = ship_to_hca.cust_account_id (+)
       AND    ship_to_hca.party_id             = ship_to_hp.party_id (+)
       AND    apsa.invoice_currency_code       = gltr.functional_currency(+)
       ) trx
/* ...trx */
/* dates... */
,   (select sysdate as as_of_date
    from dual) dates
WHERE  trunc(trx.trx_date) <= trunc(dates.as_of_date)
/


