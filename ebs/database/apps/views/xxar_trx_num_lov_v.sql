CREATE OR REPLACE VIEW XXAR_TRX_NUM_LOV_V AS
SELECT a.customer_trx_id, a.trx_number Transaction_No,
       b.customer_name, b.customer_number, customer_name||' - '||customer_number Con_Customer, a.org_id,
       a.COMPLETE_FLAG, a.printing_option,
       a.printing_pending,
       --added by daniel katz
       aps.terms_sequence_number, aps.attribute10, a.batch_source_id
from RA_CUSTOMER_TRX_ALL  a, ar_customers  b,
     ar_payment_schedules_all aps --added by daniel katz.
where a.bill_to_customer_id = b.customer_id
  and a.customer_trx_id=aps.customer_trx_id(+) --added by daniel katz.
--The value set that uses this view has additional condition that limits transaction for particular terms_sequence_number (installment number).;

