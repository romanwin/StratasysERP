CREATE OR REPLACE PACKAGE BODY xxar_multi_receipts_api IS
 PROCEDURE create_cash (p_currency_code      VARCHAR2,
                        p_amount             NUMBER,
                        p_cc_num             VARCHAR2,
                        p_receipt_date       DATE,
                        p_gl_date            DATE,
                        p_maturity_date      DATE,
                        p_cust_account_id    NUMBER,
                        p_bank_account_id    NUMBER,
                        p_site_use_id        NUMBER,
                        p_reference_num      NUMBER,
                        p_method_id          NUMBER,
                        p_comments           VARCHAR2,
                        p_cash_rcpt_id  OUT  NUMBER,
                        p_return_status OUT  VARCHAR2,
                        p_error_data    OUT  VARCHAR2) IS

  v_error_data        VARCHAR2(2500);
  l_msg_count         NUMBER;
  l_msg_data          VARCHAR2(240);
  --l_cash_receipt_id   NUMBER;

  BEGIN
/*
    apps.FND_GLOBAL.APPS_INITIALIZE(user_id      => -1,--fnd_global.user_id,--v_user_id,
                                    resp_id      => 50560,--20678,--fnd_global.resp_id,--v_resp_id,
                                    resp_appl_id => 222);--fnd_global.resp_appl_id);--v_resp_appl_id);
*/
   mo_global.init('AR');
   mo_global.set_policy_context('S', FND_GLOBAL.ORG_ID);

    AR_RECEIPT_API_PUB.create_cash(p_api_version                => 1.0,
                                   p_init_msg_list              => FND_API.G_TRUE,
                                   p_commit                     => FND_API.G_FALSE,
                                   p_validation_level           => FND_API.G_VALID_LEVEL_FULL,
                                   x_return_status              => p_return_status,
                                   x_msg_count                  => l_msg_count,
                                   x_msg_data                   => l_msg_data,
                                   p_currency_code              => p_currency_code,
                                   p_exchange_rate_type         => 'Corporate',
                                   p_amount                     => p_amount,
                                   p_receipt_number             => p_cc_num,
                                   p_receipt_date               => p_receipt_date,
                                   p_gl_date                    => p_gl_date,
                                   p_maturity_date              => p_maturity_date,
                                   p_customer_id                => p_cust_account_id,
                                   p_remittance_bank_account_id => p_bank_account_id,
                                   p_customer_site_use_id       => p_site_use_id,
                                   p_customer_receipt_reference => p_reference_num,
                                   p_receipt_method_id          => p_method_id,
                                   p_comments                   => p_comments,
                                   p_org_id                     => fnd_global.org_id,
                                   p_cr_id                      => p_cash_rcpt_id);

    IF p_return_status <> 'S' THEN
      IF (FND_MSG_PUB.count_msg > 0) THEN
          p_error_data := NULL;
        FOR j IN 1..FND_MSG_PUB.count_msg  LOOP
          p_error_data := p_error_data || ' ' || (to_char(j) || ' : ' || l_msg_data);
        END LOOP;
      END IF;
		END IF;


    EXCEPTION
        WHEN OTHERS THEN
          v_error_data := 'Exception:'||sqlerrm;
         -- insert into inna_test values('Create Cash',v_error_data);
         -- commit;
 END create_cash;
-----------------------------------------------------------------
 PROCEDURE apply_cash (p_cash_receipt_id    NUMBER,
                       p_receipt_number     VARCHAR2,
                       p_receipt_date       DATE,
                       p_customer_trx_id    NUMBER,
                       p_trx_number         VARCHAR2,
                       p_amount_applied     NUMBER,
                       p_apply_date         DATE DEFAULT SYSDATE,
                       p_gl_date            DATE DEFAULT SYSDATE,
                       p_return_status OUT  VARCHAR2,
                       p_error_data    OUT  VARCHAR2) IS

  v_error_data        VARCHAR2(2500);
  l_msg_count         NUMBER;
  l_msg_data          VARCHAR2(240);

  v_sch_id            NUMBER;


  BEGIN
/*
    apps.FND_GLOBAL.APPS_INITIALIZE(user_id      => -1,--fnd_global.user_id,--v_user_id,
                                    resp_id      => 50560,--20678,--fnd_global.resp_id,--v_resp_id,
                                    resp_appl_id => 222);--fnd_global.resp_appl_id);--v_resp_appl_id);
*/
   mo_global.init('AR');
   mo_global.set_policy_context('S', fnd_global.org_id);

   select d.payment_schedule_id
   into v_sch_id
   from ar_payment_schedules_all d
   where d.cash_receipt_id = p_cash_receipt_id;

   ar_receipt_api_pub.apply (p_api_version         => 1.0,
                             p_init_msg_list       => FND_API.G_TRUE,
                             p_commit              => FND_API.G_FALSE,
                             p_validation_level    => FND_API.G_VALID_LEVEL_FULL,
                             x_return_status       => p_return_status,
                             x_msg_count           => l_msg_count,
                             x_msg_data            => l_msg_data,
                             p_cash_receipt_id     => p_cash_receipt_id,
                             p_receipt_number      => p_receipt_number,
                             p_customer_trx_id     => p_customer_trx_id,
                             p_trx_number          => p_trx_number,
                             p_amount_applied      => p_amount_applied,
                             p_apply_date          => p_apply_date,
                             p_apply_gl_date       => p_gl_date,
                             p_org_id              => fnd_global.ORG_ID);

   IF p_return_status <> 'S' THEN
      IF (FND_MSG_PUB.count_msg > 0) THEN
          p_error_data := NULL;
        FOR j IN 1..FND_MSG_PUB.count_msg  LOOP
          p_error_data := p_error_data || ' ' || (to_char(j) || ' : ' || l_msg_data);
        END LOOP;
      END IF;
	  END IF;


    EXCEPTION
        WHEN OTHERS THEN
          v_error_data := 'Exception:'||sqlerrm;

  END apply_cash;

 PROCEDURE reverse_cash (p_reference          NUMBER,
                         p_doc_num            NUMBER,
                         p_rev_gl_date        DATE DEFAULT SYSDATE,
                         p_category_code      VARCHAR2,
                         p_reason_code        VARCHAR2,
                         p_return_status OUT  VARCHAR2,
                         p_error_data    OUT  VARCHAR2) IS

  CURSOR cash_receipts_cur IS SELECT *
                              FROM ar_cash_receipts_all
                              WHERE org_id = fnd_global.ORG_ID and
                                    (p_reference IS NOT NULL AND
                                     customer_receipt_reference = to_char(p_reference) AND
                                     p_doc_num IS NULL)
                                 OR (p_doc_num IS NOT NULL AND
                                     receipt_number >= to_char(p_doc_num) AND
                                     customer_receipt_reference = (SELECT customer_receipt_reference
                                                                   FROM ar_cash_receipts_all
                                                                   WHERE org_id = fnd_global.ORG_ID
                                                                     AND receipt_number = to_char(p_doc_num)
                                                                     AND customer_receipt_reference = to_char(p_reference)
                                                                     AND p_doc_num IS NOT NULL));

  l_msg_count         NUMBER;
  l_msg_data          VARCHAR2(240);

  BEGIN
/*
    apps.FND_GLOBAL.APPS_INITIALIZE(user_id      => -1,--fnd_global.user_id,--v_user_id,
                                    resp_id      => 50560,--20678,--fnd_global.resp_id,--v_resp_id,
                                    resp_appl_id => 222);--fnd_global.resp_appl_id);--v_resp_appl_id);
*/
    mo_global.init('AR');
    mo_global.set_policy_context('S', FND_GLOBAL.ORG_ID);
    
    FOR rec IN cash_receipts_cur LOOP
      AR_RECEIPT_API_PUB.Reverse (p_api_version             => 1.0,
                                  p_init_msg_list           => FND_API.G_TRUE,
                                  x_return_status           => p_return_status,
                                  x_msg_count               => l_msg_count,
                                  x_msg_data                => l_msg_data,
                                  p_cash_receipt_id         => rec.cash_receipt_id,
                                  p_reversal_category_code  => p_category_code,
                                  p_reversal_gl_date        => p_rev_gl_date,
                                  p_reversal_date           => trunc(sysdate),
                                  p_reversal_reason_code    => p_reason_code,
                                  p_org_id                  => FND_GLOBAL.ORG_ID);


      IF p_return_status <> 'S' THEN
        IF (FND_MSG_PUB.count_msg > 0) THEN
            p_error_data := NULL;
          FOR j IN 1..FND_MSG_PUB.count_msg  LOOP
            p_error_data := p_error_data || ' ' || (to_char(j) || ' : ' || l_msg_data);
          END LOOP;
        END IF;
		  END IF;
    END LOOP;
  
    EXCEPTION
      WHEN OTHERS THEN
        p_error_data := 'Exception:'||sqlerrm;
  END reverse_cash;


END xxar_multi_receipts_api;
/

