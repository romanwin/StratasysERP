CREATE OR REPLACE PACKAGE xxssus_cogs_expense_reclass AS

P_TRXN_DATE_FROM VARCHAR2(30);
P_TRXN_DATE_TO   VARCHAR2(30);
P_MTL_TRXN_ID    NUMBER;
P_DRAFT_MODE     VARCHAR2( 3);

P_RUN_DATE       VARCHAR2(30) := to_char(sysdate,'YYYY/MM/DD HH24:MI');
P_BATCH_NAME     VARCHAR2(80) := 'COGS Expense Reclassification'  || ' ' || P_RUN_DATE;
p_BATCH_DESC     VARCHAR2(80) := P_BATCH_NAME ;

g_data_access_set_id NUMBER;
g_ledger_id          NUMBER;
g_je_source_name     VARCHAR2(30) := 'Inventory';



G_group_id     NUMBER := NULL;
g_interface_id NUMBER := NULL;
g_accounts     VARCHAR2(2000);
FUNCTION before_report_trigger RETURN BOOLEAN;
FUNCTION after_report_trigger  RETURN BOOLEAN;
FUNCTION insert_into_gl_intf
( p_ledger_id              NUMBER
, p_currency_code          VARCHAR2
, p_segment1               VARCHAR2
, p_segment2               VARCHAR2
, p_segment3               VARCHAR2
, p_segment5               VARCHAR2
, p_segment5_rev           VARCHAR2
, p_segment6               VARCHAR2
, p_segment7               VARCHAR2
, p_segment10              VARCHAR2
, p_segment9               VARCHAR2
, p_trxn_value             NUMBER
, p_je_ref     /* reference10 journal entry line description */             VARCHAR2
, p_mtl_trxn_id            NUMBER
, p_acct_date              VARCHAR2
) RETURN BOOLEAN;
--
--

END;
/
show errors
quit
